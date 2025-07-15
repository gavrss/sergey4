SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spRun_Job_AdvConso_20241217_New]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@Group nvarchar(50) = NULL, --If not set run for all groups
	@Entity nvarchar(50) = NULL, --Mandatory
	@Year int = NULL, --Mandatory
	@FxRate_Scenario nvarchar(50) = NULL, 
	@PrevYearsYN bit = 0,
	@Scenario nvarchar(50) = 'ACTUAL',
	@SequenceBM int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000778,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spRun_Job_AdvConso] @UserID=-10, @InstanceID=527, @VersionID=1043, @Group='Group', @Entity = 'GGI01', @Year = 2021, @Debug=1
EXEC [spRun_Job_AdvConso] @UserID=-10, @InstanceID=529, @VersionID=1001, @Group='A', @Entity = '02', @Year = 2021, @Debug=1
EXEC [spRun_Job_AdvConso] @UserID=-10, @InstanceID=529, @VersionID=1001, @Group='C', @Entity = '02', @Year = 2021, @Debug=1

EXEC [spRun_Job_AdvConso] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@Print int = 0,
	@JournalTable nvarchar(100),
	@SQLStatement nvarchar(max),
	@FiscalYear int,
	@JSON nvarchar(max),

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
	@ModifiedBy nvarchar(50) = 'KeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Start job for Advanced Consolidation Calculation',
			@MandatoryParameter = 'Year' --Without @, separated by |

		IF @Version = '2.1.1.2171' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2196' SET @Description = 'Handle parameter @PrevYearsYN'
		IF @Version = '2.1.2.2199' SET @Description = 'Run all groups when @group is set set to null'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Start Job'
		SET @ProcedureName = OBJECT_NAME(@@PROCID)

		IF @JobID IS NULL
			EXEC [spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=1,
				@JobID=@JobID OUT

			SELECT [@JobID] = @JobID 

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @BusinessRuleID IS NULL
			SELECT
				@BusinessRuleID = MAX(BusinessRuleID)
			FROM
				pcINTEGRATOR_Data..BR05_Master
			WHERE
				InstanceID = @InstanceID AND
				VersionID = @VersionID AND
				DeletedID IS NULL

		SET @FxRate_Scenario = ISNULL(@FxRate_Scenario, 'ACTUAL') 

		IF @DebugBM & 2 > 0
			SELECT
				[@BusinessRuleID] = @BusinessRuleID,
				[@Group] = @Group,
				[@Entity] = @Entity,
				[@Scenario] = @Scenario,
				[@FxRate_Scenario] = @FxRate_Scenario,
				[@Year] = @Year,
				[@PrevYearsYN] = @PrevYearsYN

	SET @Step = 'Calculate table #Year_CursorTable'
		CREATE TABLE #Year_CursorTable
			(
			[FiscalYear] int
			)

		IF @PrevYearsYN = 0
			INSERT INTO #Year_CursorTable
				(
				[FiscalYear]
				)
			SELECT
				[FiscalYear] = @Year
		ELSE
			BEGIN
				EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT 
				SET @SQLStatement = '
					INSERT INTO #Year_CursorTable
						(
						[FiscalYear]
						)
					SELECT DISTINCT
						[FiscalYear]
					FROM
						' + @JournalTable + '
					WHERE
						TransactionTypeBM & 8 > 0 AND
						ConsolidationGroup = ''' + @Group + ''' AND
						FiscalYear <= ' + CONVERT(nvarchar(15), @Year)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				IF @DebugBM & 2 > 0 SELECT TempTable = '#Year_CursorTable', * FROM #Year_CursorTable ORDER BY [FiscalYear]
			END

	SET @Step = 'Calculate Advanced Consolidation'
		IF CURSOR_STATUS('global','Year_Cursor') >= -1 DEALLOCATE Year_Cursor
		DECLARE Year_Cursor CURSOR FOR
			
			SELECT 
				[FiscalYear]
			FROM
				#Year_CursorTable
			ORDER BY
				[FiscalYear]

			OPEN Year_Cursor
			FETCH NEXT FROM Year_Cursor INTO @FiscalYear

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@FiscalYear] = @FiscalYear
					                         , [@UserID] = @UserID
											 , [@InstanceID] = @InstanceID
											 , [@VersionID] = @VersionID
											 , [@BusinessRuleID] = @BusinessRuleID
											 , [@SequenceBM] =@SequenceBM
											 , [@Group] = @Group 
											 , [@FxRate_Scenario] = @FxRate_Scenario
											 , [@Entity] = @Entity
											 , [@JobID] = @JobID
											 , [@DebugSub] = @DebugSub


					--Change to @JSON-call
					SET @JSON = '
						[
						{"TKey" : "UserID",  "TValue": "' + CONVERT(NVARCHAR(10), @UserID) + '"},
						{"TKey" : "InstanceID",  "TValue": "' + CONVERT(NVARCHAR(10), @InstanceID) + '"},
						{"TKey" : "VersionID",  "TValue": "' + CONVERT(NVARCHAR(10), @VersionID) + '"},
						{"TKey" : "BusinessRuleID",  "TValue": "' + CONVERT(NVARCHAR(10), @BusinessRuleID) + '"},
						' + CASE WHEN @SequenceBM IS NOT NULL THEN '{"TKey" : "SequenceBM",  "TValue": "' + CONVERT(NVARCHAR(10), @SequenceBM) + '"},' ELSE '' END + '
						{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(NVARCHAR(10), @FiscalYear) + '"},
						' + CASE WHEN @Group IS NOT NULL THEN '{"TKey" : "ConsolidationGroup",  "TValue": "' + @Group + '"},' ELSE '' END + '
						{"TKey" : "FxRate_Scenario",  "TValue": "' + @FxRate_Scenario + '"},'
						+ CASE WHEN @Entity = 'All_' OR @Entity IS NULL THEN '' ELSE '{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity + '"},' END + '
						{"TKey" : "Scenario",  "TValue": "' + @Scenario + '"},
						{"TKey" : "JobID",  "TValue": "' + CONVERT(NVARCHAR(10), @JobID) + '"},
						{"TKey" : "Debug",  "TValue": "' + CONVERT(NVARCHAR(10), @DebugSub) + '"}
						]'

					IF @DebugBM & 2 > 0 PRINT @JSON

					EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spBR_BR05', @JSON = @JSON
/*
					EXEC [pcINTEGRATOR].[dbo].[spBR_BR05]
						@UserID=@UserID,
						@InstanceID=@InstanceID,
						@VersionID=@VersionID,
						@BusinessRuleID = @BusinessRuleID,
						@SequenceBM = 125,
						@FiscalYear = @FiscalYear,
						@ConsolidationGroup = @Group,
						@FxRate_Scenario = @FxRate_Scenario, 
						@Entity_MemberKey = @Entity,
						@Scenario = @Scenario,
						@JobID = @JobID,
						@Debug=@DebugSub
*/
					FETCH NEXT FROM Year_Cursor INTO @FiscalYear
				END

		CLOSE Year_Cursor
		DEALLOCATE Year_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	SET @Step = 'Set EndTime for the actual job'
		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
--	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
