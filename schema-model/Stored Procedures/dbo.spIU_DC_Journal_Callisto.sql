SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_Callisto] 

	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SourceID int = NULL,
	@SequenceBM int = 3, --1 = Journal, 2 = FACT Financials, 4 = Currency conversion, 8 = Refresh Financials

--	@SourceTypeBM int = 1024, --Default = 1048575

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000641,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_Journal_Callisto',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"}
		]'

EXEC [spIU_DC_Journal_Callisto] @UserID=-10, @InstanceID=413, @VersionID=1008, @SequenceBM = 1, @Debug=1
EXEC [spIU_DC_Journal_Callisto] @UserID=-10, @InstanceID=413, @VersionID=1008, @SequenceBM = 2, @Debug=1

EXEC [spIU_DC_Journal_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SourceTypeID int,
	@JobUpdateYN bit,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Run incremental update of Journal and Callisto FACT table',
			@MandatoryParameter = 'SourceID' --Without @, separated by |

		IF @Version = '2.0.3.2152' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

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
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@SourceTypeID = SourceTypeID
		FROM
			pcINTEGRATOR_Data..[Source]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SourceID = @SourceID

		SET @JobUpdateYN = (SELECT COUNT(1) FROM [pcINTEGRATOR_Log].[dbo].[Job] WHERE [JobID] = @JobID AND [MasterCommand] = 'spIU_DC_Journal_Refresh_Start')

		IF @DebugBM & 2 > 0 SELECT [@SourceTypeID] = @SourceTypeID, [@JobUpdateYN] = @JobUpdateYN

	SET @Step = 'Load #Journal_Update'
		CREATE TABLE #Journal_Update
			(
			[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] [int],
			[FiscalPeriod] [int]
			)

		EXEC [spGet_Journal_Update] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Load Journal'
		IF @SequenceBM & 1 > 0
			BEGIN
				IF @JobUpdateYN <> 0 UPDATE [pcINTEGRATOR_Log].[dbo].[Job] SET [CurrentCommand] = 'spIU_DC_Journal', [CurrentCommand_StartTime] = GetDate() WHERE [JobID] = @JobID
				EXEC [pcINTEGRATOR].[dbo].[spIU_DC_Journal] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @SourceTypeID = @SourceTypeID, @JobID = @JobID, @Debug = @DebugSub
			END

	SET @Step = 'Load FACT Financials'
		IF @SequenceBM & 2 > 0
			BEGIN
				IF @JobUpdateYN <> 0 UPDATE [pcINTEGRATOR_Log].[dbo].[Job] SET [CurrentCommand] = 'spIU_BusinessProcess_Callisto', [CurrentCommand_StartTime] = GetDate() WHERE [JobID] = @JobID
				EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_BusinessProcess_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID
				
				IF @JobUpdateYN <> 0 UPDATE [pcINTEGRATOR_Log].[dbo].[Job] SET [CurrentCommand] = 'spIU_Scenario_Callisto', [CurrentCommand_StartTime] = GetDate() WHERE [JobID] = @JobID
				EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_Scenario_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID

				IF @JobUpdateYN <> 0 UPDATE [pcINTEGRATOR_Log].[dbo].[Job] SET [CurrentCommand] = 'spIU_DC_Journal_DataClass_Financials', [CurrentCommand_StartTime] = GetDate() WHERE [JobID] = @JobID
				EXEC [pcINTEGRATOR].[dbo].[spIU_DC_Financials] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Debug = @DebugSub
			END

/*
	SET @Step = 'Run Currency conversion'
		IF @SequenceBM & 4 > 0
			BEGIN
				IF (SELECT COUNT(1) FROM [pcDATA_CBN].[dbo].[S_DS_Currency] WHERE [Reporting] <> 0) > 0
					BEGIN
						SELECT DISTINCT
							[BusinessProcess_MemberId],
							[Entity_MemberId],
							[Scenario_MemberId],
							[Time_MemberId]
						INTO
							#FACT_Update
						FROM
							[pcDATA_CBN].[dbo].[FACT_Financials_Default_Partition]
--						WHERE
--							ChangeDateTime BETWEEN @Financials_StartTime AND GETDATE()
		
--						EXEC spIU_0000_FACT_FxTrans @JobID = @JobID, @ModelName = 'Financials', @BPType = 'ETL', @Debug = @Debug 

						DROP TABLE #FACT_Update
					END
			END
*/

	SET @Step = 'End Job'
		IF @JobUpdateYN <> 0
			UPDATE [pcINTEGRATOR_Log].[dbo].[Job]
			SET
				[EndTime] = GetDate(),
				[ClosedYN] = 1
			WHERE
				[JobID] = @JobID

	SET @Step = 'Set @Duration'
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
