SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spRun_Job]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@JobListID int = NULL,
	@EndOfSequenceYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000181,
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
EXEC [spRun_Job] @Debug = 1		--Run all procedures in debug mode						
EXEC [spRun_Job] @JobStepTypeBM =   0 --Out of scope (Selection by @JobStepList)
EXEC [spRun_Job] @JobStepTypeBM =   1 --Setup
EXEC [spRun_Job] @JobStepTypeBM =   2 --JobStep all ETL tables
EXEC [spRun_Job] @JobStepTypeBM =   4 --JobStep all dimension tables
EXEC [spRun_Job] @JobStepTypeBM =   8 --JobStep all fact tables
EXEC [spRun_Job] @JobStepTypeBM =  16 --Run all business rules
EXEC [spRun_Job] @JobStepTypeBM =  32 --Other
EXEC [spRun_Job] @JobStepTypeBM =  64 --Run all checksums
EXEC [spRun_Job] @JobStepTypeBM = 127 --Run all procedures (default)

EXEC [spRun_Job] @UserID = -10, @InstanceID = 52, @VersionID = 1035, @DebugBM = 3
EXEC [spRun_Job] @UserID = -10, @InstanceID = 15, @VersionID = 1039, @JobListID=2060, @JobID=168, @Debug=1
EXEC [spRun_Job] @UserID = -10, @InstanceID = 527, @VersionID = 1043, @JobListID=7238, @DebugBM=3

EXEC [spRun_Job] @GetVersion = 1
*/

SET ANSI_WARNINGS ON --Must be SET ON to handle heterogeneous queries

DECLARE
	--SP-specific variables
	@JobStepTypeBM int = 255, --1=Setup, 2=ETL tables, 4=Dimensions, 8=FactTables, 16=BusinessRules, 32=Other, 64=SQL Agent jobs, 128=Checksums
	@JobFrequencyBM int = 7, --1=On demand, 2=Working days, 4=Weekend
	@JobStepGroupBM int = NULL, --Defined per InstanceID, Parameter
	@ProcessBM int = NULL, --Defined per InstanceID, Parameter NULL is ignored
	@JobSetupStepBM int = NULL, --Parameter NULL is ignored
	@JobStep_List nvarchar(4000) = NULL, --Pipe separated list of JobStepID, Parameter NULL is ignored
	@Entity_List nvarchar(4000) = NULL, --Pipe separated list of Entities, Defined per InstanceID, Parameter NULL is ignored
	@JobStepID int,
	@Database nvarchar(100),
	@StoredProcedure nvarchar(100),
	@Parameter nvarchar(255),
	@JSON nvarchar(max),
	@Total decimal(5,2),
	@Counter decimal(5,2) = 0,
	@CounterString nvarchar(100),
	@PercentDone int,
	@SQLStatement nvarchar(max),

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
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Start and run job defined by @JobListID in Job tables',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'Procedure adjusted and simplified.'
		IF @Version = '2.1.0.2157' SET @Description = 'Modified @SQLStatement with correct single quotes.'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine spSet_Job.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added parameter @EndOfSequenceYN.'
		IF @Version = '2.1.1.2171' SET @Description = 'Increase length of variable @Parameter.'

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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Get @JobListID'
		IF @JobListID IS NULL
			BEGIN
				SELECT
					@JobListID = MAX(JobListID)
				FROM
					[pcINTEGRATOR_Data].[dbo].[JobList]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[JobStepGroupBM] & 1 > 0 AND
					[SelectYN] <> 0

				IF @JobListID IS NULL
				BEGIN
					SET @Message = 'JobListID is not defined.'
					SET @Severity = 16
					GOTO EXITPOINT
				END
			END

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			BEGIN
				EXEC [spSet_Job]
					@UserID=@UserID,
					@InstanceID=@InstanceID,
					@VersionID=@VersionID,
					@ActionType='Start',
					@MasterCommand=@ProcedureName,
					@CurrentCommand=@ProcedureName,
					@JobQueueYN=1,
					@JobListID=@JobListID,
					@JobID=@JobID OUT
			END

	SET @Step = 'Get filter variables'
		SELECT
			@JobStepTypeBM = JobStepTypeBM,
			@JobFrequencyBM = JobFrequencyBM,
			@JobStepGroupBM = JobStepGroupBM,
			@ProcessBM = ProcessBM,
			@JobSetupStepBM = JobSetupStepBM,
			@JobStep_List = JobStep_List,
			@Entity_List = Entity_List
		FROM
			[pcINTEGRATOR_Data].[dbo].[JobList]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[JobListID] = @JobListID

		IF @DebugBM & 2 > 0 SELECT [@JobID] = @JobID, [@JobListID] = @JobListID, [@JobStepTypeBM] = @JobStepTypeBM, [@JobFrequencyBM] = @JobFrequencyBM, [@JobStepGroupBM] = @JobStepGroupBM, [@ProcessBM] = @ProcessBM, [@JobSetupStepBM] = @JobSetupStepBM, [@JobStep_List] = @JobStep_List, [@Entity_List] = @Entity_List

	SET @Step = 'Fill #JobStep_List'
		SELECT [JobStepID] = CONVERT(int, LTRIM(RTRIM([Value]))) INTO #JobStep_List FROM STRING_SPLIT(@JobStep_List, '|')

		IF @DebugBM & 2 > 0 SELECT TempTable = '#JobStep_List', * FROM #JobStep_List ORDER BY [JobStepID]

	SET @Step = 'Fill #Entity_List'
		SELECT [Entity] = CONVERT(nvarchar(50), LTRIM(RTRIM([Value]))) INTO #Entity_List FROM STRING_SPLIT(@Entity_List, '|')

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Entity_List', * FROM #Entity_List ORDER BY [Entity]

	SET @Step = 'Fill #JobStep_Cursor_Table'
		SELECT
			[JobStepID],
			[JobStepTypeBM],
			[Database] = [DatabaseName],
			[StoredProcedure],
			[Parameter],
			[SortOrder]
		INTO
			#JobStep_Cursor_Table
		FROM
			[pcINTEGRATOR_Data].[dbo].[JobStep]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[JobStepTypeBM] & @JobStepTypeBM > 0 AND
			[JobFrequencyBM] & @JobFrequencyBM > 0 AND
			[JobStepGroupBM] & @JobStepGroupBM > 0 AND
			([ProcessBM] & @ProcessBM > 0 OR @ProcessBM IS NULL) AND
			([JobSetupStepBM] & @JobSetupStepBM > 0 OR @JobSetupStepBM IS NULL) AND
			[SelectYN] <> 0

		IF (SELECT COUNT(1) FROM #JobStep_List) > 0
			DELETE JSCT
			FROM
				#JobStep_Cursor_Table JSCT
			WHERE
				NOT EXISTS (SELECT 1 FROM #JobStep_List JSL WHERE JSL.JobStepID = JSCT.JobStepID)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#JobStep_Cursor_Table', * FROM #JobStep_Cursor_Table ORDER BY [JobStepTypeBM], [SortOrder]

	SET @Step = 'Count total number of commands to run'
		SELECT
			@Total = COUNT(1)
		FROM
			#JobStep_Cursor_Table

	SET @Step = 'JobStep_Cursor'
		IF CURSOR_STATUS('global','JobStep_Cursor') >= -1 DEALLOCATE JobStep_Cursor
		DECLARE JobStep_Cursor CURSOR FOR
			
			SELECT 
				[JobStepID],
				[Database],
				[StoredProcedure],
				[Parameter]
			FROM
				#JobStep_Cursor_Table
			ORDER BY
				[JobStepTypeBM],
				[SortOrder]

			OPEN JobStep_Cursor
			FETCH NEXT FROM JobStep_Cursor INTO @JobStepID, @Database, @StoredProcedure, @Parameter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@JobStepID] = @JobStepID, [@Database] = @Database, [@StoredProcedure] = @StoredProcedure, [@Parameter] = @Parameter

					SET @Database = ISNULL(@Database, DB_NAME())

					UPDATE [pcINTEGRATOR_Log].[dbo].[Job]
					SET
						CurrentCommand = @Database + '..' + @StoredProcedure + CASE WHEN LEN(@Parameter) > 0 THEN ' ' + @Parameter ELSE '' END,
						CurrentCommand_StartTime = GetDate()
					WHERE
						JobID = @JobID

					--IF @Database = DB_NAME()
					--	BEGIN
					--		SET @JSON = '
					--			[
					--			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
					--			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
					--			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
					--			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
					--			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
					--			]'

					--		EXEC spRun_Procedure_KeyValuePair
					--			@ProcedureName = @StoredProcedure,
					--			@OptParam = @Parameter,
					--			@JobStepID = @JobStepID,
					--			@JSON = @JSON
					--	END
					--ELSE
					--	BEGIN
					--		SET @SQLStatement = 'EXEC ' + @Database + '.dbo.sp_executesql N''' + @StoredProcedure + CASE WHEN LEN(@Parameter) > 0 THEN ' ' + @Parameter ELSE '' END + ''''
					--		IF @DebugBM & 2 > 0 PRINT @SQLStatement
					--		EXEC (@SQLStatement)
					--	END

					--IF @Database <> DB_NAME()
					--	SET	@StoredProcedure = @Database + '..' + @StoredProcedure

					SET @JSON = '
[
{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
]'

					EXEC spRun_Procedure_KeyValuePair
						@DatabaseName = @Database,
						@ProcedureName = @StoredProcedure,
						@OptParam = @Parameter,
						@JobStepID = @JobStepID,
						@JSON = @JSON

					SET @Counter = @Counter + 1
					SET @CounterString = CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed'
					SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

					RAISERROR (@CounterString, 0, @PercentDone) WITH NOWAIT

					FETCH NEXT FROM JobStep_Cursor INTO @JobStepID, @Database, @StoredProcedure, @Parameter
				END

		CLOSE JobStep_Cursor
		DEALLOCATE JobStep_Cursor

	--SET @Step = 'Check for severe error'
	--	SELECT @Command = SUBSTRING(CurrentCommand, CHARINDEX ('N''[', CurrentCommand, 1) + 3, CHARINDEX (']', CurrentCommand, CHARINDEX ('N''[', CurrentCommand, 1) + 3) - (CHARINDEX ('N''[', CurrentCommand, 1) + 3)) FROM Job WHERE JobID = @JobID
	
	--	IF (SELECT COUNT(1) FROM JobLog WHERE JobID = @JobID AND ProcedureName = @Command) = 0
	--		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, @Command, GetDate() - @StartTime, Deleted = 0, Inserted = 0, Updated = 0, ErrorNumber = 90000, ErrorSeverity = 16, ErrorState = 0, ErrorLine = 0, @Command, @Step, ErrorMessage = 'Severe error, system halted.', @Version

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

	SET @Step = 'Set EndTime for the actual job'
		IF @EndOfSequenceYN <> 0
			BEGIN
				EXEC [spSet_Job]
					@UserID=@UserID,
					@InstanceID=@InstanceID,
					@VersionID=@VersionID,
					@ActionType='End',
					@MasterCommand=@ProcedureName,
					@CurrentCommand=@ProcedureName,
					@JobID=@JobID
			END
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
