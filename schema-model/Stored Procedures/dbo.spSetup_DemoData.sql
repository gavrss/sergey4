SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_DemoData]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = -10,
	@DemoYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int =  880000790,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spSetup_DemoData] @UserID = -1174, @InstanceID = -1001, @VersionID = -1001, @DemoYN = 1, @Debug = 1

EXEC [spSetup_DemoData] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@SQLStatement nvarchar(max),	
	@ApplicationID int,
	@ApplicationName nvarchar(100),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup WorkflowRow and Demo Data',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2173' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ApplicationID = [ApplicationID],
			@ApplicationName = [ApplicationName],
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		IF @DebugBM & 2 > 0 
			SELECT 
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@ApplicationID] = @ApplicationID,
				[@ApplicationName] = @ApplicationName,
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase,
				[@JobID] = @JobID
	
	SET @Step = 'SourceTypeID = -10 Default setup; SourceTypeID = 11 EpicorERP'
		IF @SourceTypeID IN (-10, 11)
			BEGIN

				SET @Step = 'Only for @DemoYN = 1 and SourceDB = DSPSOURCE01.ERP10; Create default WorkflowRow and Demodata'
					IF @DemoYN <> 0 AND 
						(
						SELECT 
							MAX(S.SourceDatabase)
						FROM
							[Source] S
							INNER JOIN Model M ON M.ModelID = S.ModelID AND M.BaseModelID = -7
							INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.InstanceID = @InstanceID AND A.VersionID = @VersionID
						) = 'DSPSOURCE01.ERP10'

						BEGIN
							INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowRow]
								(
								[InstanceID],
								[VersionID],
								[WorkflowID],
								[DimensionID],
								[Dimension_MemberKey],
								[CogentYN]
								)
							SELECT 
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[WorkflowID] = WF.[WorkflowID],
								[DimensionID] = WFR.[DimensionID],
								[Dimension_MemberKey] = WFR.[Dimension_MemberKey],
								[CogentYN] = WFR.[CogentYN]
							FROM
								[WorkflowRow] WFR
								INNER JOIN [Workflow] WF ON WF.[InstanceID] = @InstanceID AND WF.[VersionID] = @VersionID AND WF.[InheritedFrom] = WFR.[WorkflowID]
							WHERE
								WFR.[InstanceID] = @SourceInstanceID AND
								WFR.[VersionID] = @SourceVersionID AND
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[WorkflowRow] WFRD WHERE WFRD.[WorkflowID] = WF.[WorkflowID] AND WFRD.[DimensionID] = WFR.[DimensionID] AND WFRD.[Dimension_MemberKey] = WFR.[Dimension_MemberKey])

							SELECT @Inserted = @Inserted + @@ROWCOUNT

							--Should be made more generic and renamed to spSetup_DemoData						
							EXEC [dbo].[spCreate_DemoData] 
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID
						END
			END
	
	SET @Step = 'Return information'
		IF @DebugBM & 1 > 0 
			SELECT [Table] = 'pcINTEGRATOR_Data..WorkflowRow', * FROM [pcINTEGRATOR_Data].[dbo].[WorkflowRow]	WHERE InstanceID = @InstanceID AND VersionID = @VersionID	

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
