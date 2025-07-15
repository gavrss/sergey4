SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdmin_LoadCallisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@JobStepTypeBM int = NULL, --1=Setup, 2=ETL preparation, 4=Dimensions, 8=Data (FACT tables), 16=Business Rules, 32=Other, 64=Check Sums, 127=Full nightly load
	@AsynchronousYN bit = 1,
	@JobStepGroupBM int = NULL,
	@JobListID int = NULL,
	@JobName nvarchar(255) = NULL,
	@StepName nvarchar(255) = NULL,
	@ModelName nvarchar(50) = NULL,
	@CallistoDeployYN bit = 0,
	@FullReloadYN bit = 0,
	@TimeOut time(7) = NULL,
	@JSON_table nvarchar(MAX) = NULL,  --Company nvarchar(8), BookID nvarchar(12), FiscalYear int, FiscalPeriod int

	@JobID int = NULL OUT,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000235,
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
EXEC spPortalAdmin_LoadCallisto @CallistoDeployYN='0',@FullReloadYN='0',@InstanceID='732',@UserID='-10',@VersionID='1165',@DebugBM=4

EXEC spPortalAdmin_LoadCallisto @InstanceID='476',@UserID='-10',@VersionID='1029',@DebugBM=7, @CallistoDeployYN=0

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdmin_LoadCallisto',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"},
		{"TKey" : "CallistoDeployYN",  "TValue": "1"},
		{"TKey" : "FullReloadYN",  "TValue": "0"}
		]'
	@JSON_table='
		[
		{"Company":"ADP","BookID":"MAIN","FiscalYear":"2020","FiscalPeriod":"6"},
		{"Company":"ADP","BookID":"MAIN","FiscalYear":"2020","FiscalPeriod":"7"}
		]'

EXEC [spPortalAdmin_LoadCallisto] @UserID=-10, @InstanceID=390, @VersionID=1011, @JobName='Test', @StepName='LogStartTime', @AsynchronousYN=1
EXEC [spPortalAdmin_LoadCallisto] @UserID=-10, @InstanceID=390, @VersionID=1011, @JobName='Test', @StepName='LogStartTime', @AsynchronousYN=0
EXEC [spPortalAdmin_LoadCallisto] @UserID=-10, @InstanceID=52, @VersionID=1035, @Debug=1
EXEC [spPortalAdmin_LoadCallisto] @UserID=-10, @InstanceID=454, @VersionID=1021, @Debug=1
EXEC [spPortalAdmin_LoadCallisto] @UserID=-10, @InstanceID=478, @VersionID=1030, @JobListID=1007, @Debug=1
EXEC [spPortalAdmin_LoadCallisto] @UserID=-10, @InstanceID=529, @VersionID=1001
EXEC [spPortalAdmin_LoadCallisto] @UserID=-10, @InstanceID=494, @VersionID=1037, @DebugBM = 3

EXEC [spPortalAdmin_LoadCallisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DateFirst int = 1,  --In EFP, Monday is always day no. 1
	@SourceTypeID int = 11, --E10
	@LoadTypeBM int = 31, --1=ETL tables, 2=Dimensions, 4=FactTables, 8=BusinessRules, 16=Checksums
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@JobTypeID int, --1=Referring to Load table in pcETL, 2=Referring to Job tables in pcINTEGRATOR
	@JobFrequencyBM int,
	@ProcessBM int,
	@JobStepGroupBM_Local int,

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
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.1.2181'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Start Callisto load job, only valid for EpicorERP',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-332: Added parameter @AsynchronousYN.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added parameter @JobListID.'
		IF @Version = '2.1.0.2157' SET @Description = 'Selection of @JobTypeID dependent of @JobListID'
		IF @Version = '2.1.0.2159' SET @Description = 'DB-539: Return parameter info. Use sub routine [spSet_Job].'
		IF @Version = '2.1.0.2161' SET @Description = 'Handle new parameters @CallistoDeployYN, @FullReloadYN and @JSON_table.'
		IF @Version = '2.1.0.2162' SET @Description = 'Modified query in @Step = Get @JobListID. Enhanced debug and error handling in Job table. Added @TimeOut handling. Test on @JobFrequencyBM when setting @JobListID.'
		IF @Version = '2.1.0.2163' SET @Description = 'Set @StepName = ETLData IF @JobStepGroupBM & 4 > 0.'
		IF @Version = '2.1.1.2168' SET @Description = 'Set ANSI_WARNINGS ON for @JobTypeID = 1. EXEC spStart_Job_Agent when @JobTypeID = 1. Enhanced Debugging. Correctly set @JobFrequencyBM.'
		IF @Version = '2.1.1.2170' SET @Description = 'Handle WeekendLoad JobList - set correct values for @JobFrequencyBM and @JobStepTypeBM.'
		IF @Version = '2.1.1.2181' SET @Description = 'Added @Step = ''Exclude Instances from ETL'''

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		--Special for Allied Aviation JaWo 2021-07-29
		IF @InstanceID = 476
			SET @FullReloadYN = 0
		--End of special for Allied Aviation JaWo 2021-07-29

		SET DATEFIRST @DateFirst 
		SELECT @JobFrequencyBM = CASE WHEN DATEPART(WEEKDAY, GetDate()) <= 5 THEN CASE WHEN @FullReloadYN <> 0 THEN 7 ELSE 6 END ELSE 8 END

		SELECT
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		--Check type of job
		IF OBJECT_ID (@ETLDatabase +'.[dbo].[Load]', N'U') IS NOT NULL AND @JobListID IS NULL
			SET @JobTypeID = 1
		ELSE
			SET @JobTypeID = 2

	SET @Step = 'Exclude Instances from ETL'
		if EXISTS (SELECT TOP 1 * FROM [JobExclude] WHERE InstanceID = @InstanceID AND VersionID = @VersionID)
			SET @JobTypeID = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@ETLDatabase] = @ETLDatabase,
				[@JobTypeID] = @JobTypeID,
				[@JobStepTypeBM] = @JobStepTypeBM,
				[@JobStepGroupBM] = @JobStepGroupBM,
				[@JobFrequencyBM] = @JobFrequencyBM,
				[@JobListID] = @JobListID,
				[@StepName] = @StepName,
				[@ModelName] = @ModelName,
				[@CallistoDeployYN] = @CallistoDeployYN,
				[@FullReloadYN] = @FullReloadYN,
				[@AsynchronousYN] = @AsynchronousYN

	SET @Step = '@JobTypeID = 1'
		IF @JobTypeID = 1
			BEGIN
				SET ANSI_WARNINGS ON

				SET @JobStepTypeBM = ISNULL(@JobStepTypeBM, 127)

				SET @LoadTypeBM = 0
				SET @LoadTypeBM = @LoadTypeBM + CASE WHEN @JobStepTypeBM &  2 > 0 THEN  1 ELSE 0 END
				SET @LoadTypeBM = @LoadTypeBM + CASE WHEN @JobStepTypeBM &  4 > 0 THEN  2 ELSE 0 END
				SET @LoadTypeBM = @LoadTypeBM + CASE WHEN @JobStepTypeBM &  8 > 0 THEN  4 ELSE 0 END
				SET @LoadTypeBM = @LoadTypeBM + CASE WHEN @JobStepTypeBM & 16 > 0 THEN  8 ELSE 0 END
				SET @LoadTypeBM = @LoadTypeBM + CASE WHEN @JobStepTypeBM & 64 > 0 THEN 16 ELSE 0 END

				SET	@StepName  = ISNULL(@StepName, 'Load')
				
				IF @DebugBM & 2 > 0 SELECT [@JobStepTypeBM] = @JobStepTypeBM, [@LoadTypeBM] = @LoadTypeBM, [@JobName] = @JobName, [@StepName] = @StepName

				IF @JobStepTypeBM & 127 > 0
					BEGIN
						EXEC [spStart_Job_Agent] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobName = @JobName, @StepName = @StepName, @AsynchronousYN = @AsynchronousYN
					END
				ELSE
					BEGIN
						SET @SQLStatement = 'EXEC [spIU_Load_All] @LoadTypeBM = ' + CONVERT(nvarchar(15), @LoadTypeBM)
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END

				GOTO JobDone
			END

	SET @Step = 'Get @JobStepGroupBM'
		IF @JobStepGroupBM IS NULL  
			BEGIN
				IF @JobListID IS NOT NULL
					SELECT
						@JobStepGroupBM = JobStepGroupBM
					FROM
						JobList
					WHERE
						[InstanceID] = @InstanceID AND
						[VersionID] = @VersionID AND
						[JobListID] = @JobListID AND
						[SelectYN] <> 0
				
				ELSE IF @FullReloadYN <> 0 SET @JobStepGroupBM = 10
				ELSE IF @CallistoDeployYN = 0 SET @JobStepGroupBM = 5
				ELSE IF @CallistoDeployYN <> 0 SET @JobStepGroupBM = 9

				ELSE IF @JobListID IS NULL AND @StepName IS NULL
					BEGIN
						IF @CallistoDeployYN = 0
							SET @JobStepGroupBM = 2
						ELSE
							SET @JobStepGroupBM = 1
					END
			END

		IF @DebugBM & 2 > 0 SELECT [@JobStepGroupBM] = @JobStepGroupBM

	SET @Step = 'Get @StepName'
		IF @StepName IS NULL
			BEGIN
				IF @JobStepGroupBM & 8 > 0
					SET @StepName = 'ETLFull'
				ELSE IF @JobStepGroupBM & 4 > 0
					SET @StepName = 'ETLData' --'ETLFull'
			END

		IF @DebugBM & 2 > 0 SELECT [@StepName] = @StepName

	SET @Step = 'Get @JobListID'
		IF @JobListID IS NULL
			BEGIN
				--IF @JobStepGroupBM & 1 > 0 
				--	SET @JobStepGroupBM_Local = @JobStepGroupBM - 1
				--ELSE 
				--	SET @JobStepGroupBM_Local = @JobStepGroupBM

				IF @JobFrequencyBM = 7 
					SET @JobStepGroupBM_Local = @JobStepGroupBM
				ELSE IF @JobFrequencyBM = 8
					SET @JobStepGroupBM_Local = 10
				ELSE
					SET @JobStepGroupBM_Local = @JobStepGroupBM - 1

				IF @DebugBM & 2 > 0 SELECT [JobStepGroupBM] = @JobStepGroupBM, [@JobStepGroupBM_Local] = @JobStepGroupBM_Local, [JobFrequencyBM] = @JobFrequencyBM

				SELECT
					@JobListID = MAX(JobListID)
				FROM
					[pcINTEGRATOR_Data].[dbo].[JobList]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[JobStepGroupBM] & @JobStepGroupBM_Local > 0 AND
					[JobFrequencyBM] & @JobFrequencyBM > 0 AND
					[SelectYN] <> 0
			END

		IF @DebugBM & 2 > 0 SELECT [@JobListID] = @JobListID

	SET @Step = 'Verify that @JobListID is set'
		IF @JobListID IS NULL
			BEGIN
				SET @Message = 'JobListID is not defined.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Get @ModelName'
		IF @StepName IN ('Refresh', 'ETLData') AND @ModelName IS NULL
			BEGIN
				SELECT @ProcessBM = ProcessBM FROM [pcINTEGRATOR_Data].[dbo].[JobList] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [JobListID] = @JobListID 
				
				IF @DebugBM & 2 > 0 SELECT [@ProcessBM] = @ProcessBM

				SELECT
					@ModelName = MAX(DC.DataClassName)
				FROM
					[pcINTEGRATOR_Data].[dbo].[Process] P
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass_Process] DCP ON DCP.[InstanceID] = P.[InstanceID] AND DCP.[VersionID] = P.[VersionID] AND DCP.[ProcessID] = P.[ProcessID]
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = DCP.[InstanceID] AND DC.[VersionID] = DCP.[VersionID] AND DC.[DataClassID] = DCP.[DataClassID] AND DC.[SelectYN] <> 0 AND DC.[DeletedID] IS NULL
				WHERE
					P.[InstanceID] = @InstanceID AND
					P.[VersionID] = @VersionID AND
					P.[ProcessBM] & @ProcessBM > 0 AND
					P.[SelectYN] <> 0

				SELECT @ModelName = ISNULL(@ModelName, 'Financials')

				IF @ModelName IS NULL
				BEGIN
					SET @Message = '@ModelName is not defined.'
					SET @Severity = 16
					EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
					GOTO EXITPOINT
				END
			END

		IF @DebugBM & 2 > 0
			SELECT 
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@StepName]  = @StepName,
				[@AsynchronousYN] = @AsynchronousYN,
				[@ModelName] = @ModelName,
				[@JobListID] = @JobListID,
				[@MasterCommand] = @ProcedureName,
				[@JobQueueYN] = 1,
				[@JobID] = @JobID,
				[@JobStepGroupBM] = @JobStepGroupBM

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			BEGIN
				SET @TimeOut = ISNULL(@TimeOut, CASE WHEN @FullReloadYN <> 0 THEN '06:00:00' ELSE '03:00:00' END)

				EXEC [spSet_Job]
					@UserID=@UserID,
					@InstanceID=@InstanceID,
					@VersionID=@VersionID,
					@ActionType='Start',
					@MasterCommand=@ProcedureName,
					@CurrentCommand=@ProcedureName,
					@JobListID = @JobListID,
					@JobQueueYN=1,
					@TimeOut = @TimeOut,
					@CheckCount = 0,
					@JobID=@JobID OUT
			END

	SET @Step = 'Fill table pcINTEGRATOR_Log..wrk_Journal_Update'
		IF @JSON_table IS NOT NULL
			BEGIN
				CREATE TABLE #JournalUpdate
					(
					[Company] nvarchar(8), 
					[BookID] nvarchar(12), 
					[FiscalYear] int, 
					[FiscalPeriod] int
					)
			
				INSERT INTO #JournalUpdate
					(
					[Company], 
					[BookID], 
					[FiscalYear], 
					[FiscalPeriod]
					)
				SELECT
					[Company], 
					[BookID], 
					[FiscalYear], 
					[FiscalPeriod]
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[Company] nvarchar(8), 
					[BookID] nvarchar(12), 
					[FiscalYear] int, 
					[FiscalPeriod] int
					)

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#JournalUpdate', * FROM #JournalUpdate

				INSERT INTO [pcINTEGRATOR_Log].[dbo].[wrk_Journal_Update]
					(
					[JobID],
					[InstanceID],
					[VersionID],
					[SourceTypeID],
					[Entity],
					[Book],
					[FiscalYear],
					[FiscalPeriod],
					[MaxSourceCounter],
					[Comparison]
					)
				SELECT
					[JobID] = @JobID,
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[SourceTypeID] = @SourceTypeID,
					[Entity] = [Company],
					[Book] = [BookID],
					[FiscalYear] = [FiscalYear],
					[FiscalPeriod] = [FiscalPeriod],
					[MaxSourceCounter] = NULL,
					[Comparison] = ''
				FROM
					#JournalUpdate

				DROP TABLE #JournalUpdate
			END

	SET @Step = 'EXEC [spRun_Job_Callisto_Generic]'
		EXEC [spRun_Job_Callisto_Generic]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@StepName  = @StepName,
			@AsynchronousYN = @AsynchronousYN,
			@ModelName = @ModelName,
			@JobListID = @JobListID,
			@MasterCommand = @ProcedureName,
			@JobQueueYN = 1,
			@JobID = @JobID,
			@Debug = @DebugSub

	SET @Step = 'Define JobDone'
		JobDone:
	
	SET @Step = 'Return parameters'
		IF @JobTypeID = 2
			SELECT
				[@JobID] = @JobID,
				[@StepName] = @StepName,
				[@JobStepGroupBM] = @JobStepGroupBM,
				[@ModelName] = @ModelName

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
