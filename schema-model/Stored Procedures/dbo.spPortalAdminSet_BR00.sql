SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_BR00]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JSON_table nvarchar(MAX) = NULL,
	@ResultTypeBM int = NULL, --1 = BR00_Step, 4 = BR00_Parameter

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000607,
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
DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "1", "Comment": "Test comment", "BusinessRuleID": "2006", "BR00_StepID": "1002", "BusinessRule_SubID": "2007", "SortOrder": "20"},
	{"ResultTypeBM" : "1", "BR00_StepID": "2005", "DeleteYN": "1"},
	{"ResultTypeBM" : "1", "Comment": "New Test comment", "BusinessRuleID": "2006", "BusinessRule_SubID": "1002", "SortOrder": "30"},
	{"ResultTypeBM" : "4", "BusinessRuleID": "5065", "ParameterName": "@FromTime", "ParameterValue": "201901"},
	{"ResultTypeBM" : "4", "BusinessRuleID": "1003", "ParameterName": "@ToTime", "ParameterValue": "202002"},
	{"ResultTypeBM" : "4", "BusinessRuleID": "1001", "ParameterName": "@ToTime", "DeleteYN": "1"}
	]'
			
EXEC [spPortalAdminSet_BR00]
	@UserID=-10,
	@InstanceID=424,
	@VersionID=1017,
	@JSON_table = @JSON_table,
	@DebugBM=1

EXEC [spPortalAdminSet_BR00] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,
	@Inserted_Local int,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain tables specific for BusinessRules of type BR00',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create and fill #BRList'
		CREATE TABLE #BRList
			(
			[ResultTypeBM] int,
			[Comment] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[BusinessRuleID] int,
			[BR00_StepID] int,
			[BusinessRule_SubID] int,
			[ParameterName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[ParameterValue] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SortOrder] int,
			[SelectYN] bit,
			[DeleteYN] bit
			)

		IF @JSON_table IS NOT NULL	
			INSERT INTO #BRList
				(
				[ResultTypeBM],
				[Comment],
				[BusinessRuleID],
				[BR00_StepID],
				[BusinessRule_SubID],
				[ParameterName],
				[ParameterValue],
				[SortOrder],
				[SelectYN],
				[DeleteYN]
				)
			SELECT
				[ResultTypeBM],
				[Comment],
				[BusinessRuleID],
				[BR00_StepID],
				[BusinessRule_SubID],
				[ParameterName],
				[ParameterValue],
				[SortOrder],
				[SelectYN] = ISNULL([SelectYN], 1),
				[DeleteYN] = ISNULL([DeleteYN], 0)
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				[ResultTypeBM] int,
				[Comment] nvarchar(1024) COLLATE DATABASE_DEFAULT,
				[BusinessRuleID] int,
				[BR00_StepID] int,
				[BusinessRule_SubID] int,
				[ParameterName] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[ParameterValue] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[SortOrder] int,
				[SelectYN] bit,
				[DeleteYN] bit
				)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#BRList', * FROM #BRList

	SET @Step = 'Update ResultTypeBM = 1 (BR00_Step)'
		UPDATE BRS
		SET
			[Comment] = ISNULL(BRL.[Comment], BRS.[Comment]),
			[BusinessRule_SubID] = ISNULL(BRL.[BusinessRule_SubID], BRS.[BusinessRule_SubID]),
			[SortOrder] = ISNULL(BRL.[SortOrder], BRS.[SortOrder]), 
			[SelectYN] = ISNULL(BRL.[SelectYN], BRS.[SelectYN]) 
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR00_Step] BRS
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 1 AND BRL.DeleteYN = 0 AND BRL.[BusinessRuleID] = BRS.[BusinessRuleID] AND BRL.[BR00_StepID] = BRS.[BR00_StepID] 
		WHERE
			BRS.[InstanceID] = @InstanceID AND
			BRS.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update ResultTypeBM = 4 (BR00_Parameter)'
		UPDATE BRP
		SET
			[ParameterValue] = ISNULL(BRL.[ParameterValue], BRP.[ParameterValue])
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR00_Parameter] BRP
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 4 AND BRL.DeleteYN = 0 AND BRL.[BusinessRuleID] = BRP.[BusinessRuleID] AND BRL.[ParameterName] = BRP.[ParameterName] 
		WHERE
			BRP.[InstanceID] = @InstanceID AND
			BRP.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Delete ResultTypeBM = 1 (BR00_Step)'
		DELETE BRS
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR00_Step] BRS
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 1 AND BRL.DeleteYN <> 0 AND BRL.[BusinessRuleID] = BRS.[BusinessRuleID] AND BRL.[BR00_StepID] = BRS.[BR00_StepID]
		WHERE
			BRS.[InstanceID] = @InstanceID AND
			BRS.[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete ResultTypeBM = 4 (BR00_Parameter)'
		DELETE BRP
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR00_Parameter] BRP
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 4 AND BRL.DeleteYN <> 0 AND BRL.[BusinessRuleID] = BRP.[BusinessRuleID] AND BRL.[ParameterName] = BRP.[ParameterName]
		WHERE
			BRP.[InstanceID] = @InstanceID AND
			BRP.[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Insert new member ResultTypeBM = 1 (BR00_Step)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR00_Step]
			(
			[Comment],
			[InstanceID],
			[VersionID],
			[BusinessRuleID],
			[BusinessRule_SubID],
			[SortOrder],
			[SelectYN]
			)
		SELECT
			[Comment],
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[BusinessRuleID],
			[BusinessRule_SubID],
			[SortOrder] = ISNULL(BRL.[SortOrder], 0),
			[SelectYN] = BRL.[SelectYN]
		FROM
			#BRList BRL
		WHERE
			BRL.[ResultTypeBM] = 1 AND
			BRL.[BR00_StepID] IS NULL AND
			BRL.[DeleteYN] = 0

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert new member ResultTypeBM = 4 (BR00_Parameter)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR00_Parameter]
			(
			[InstanceID],
			[VersionID],
			[BusinessRuleID],
			[ParameterName],
			[ParameterValue]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[BusinessRuleID] = BRL.[BusinessRuleID],
			[ParameterName] = BRL.[ParameterName],
			[ParameterValue] = BRL.[ParameterValue]
		FROM
			#BRList BRL
		WHERE
			BRL.[ResultTypeBM] = 4 AND
			BRL.[DeleteYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR00_Parameter] D WHERE D.[BusinessRuleID] = BRL.[BusinessRuleID] AND D.[ParameterName] = BRL.[ParameterName])

		SELECT
			@Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return Rows'
		IF @DebugBM & 1 > 0
			BEGIN
				SELECT [Table] = 'BR00_Step', * FROM [pcINTEGRATOR_Data].[dbo].[BR00_Step] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID ORDER BY [BusinessRuleID], [SortOrder]
				SELECT [Table] = 'BR00_Parameter', * FROM [pcINTEGRATOR_Data].[dbo].[BR00_Parameter] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID ORDER BY [BusinessRuleID], [ParameterName]
			END

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
