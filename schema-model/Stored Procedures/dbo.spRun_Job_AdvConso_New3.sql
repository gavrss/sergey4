SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spRun_Job_AdvConso_New3]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@Group nvarchar(50) = NULL, --Optional
	@Entity nvarchar(50) = NULL, --Optional
	@FiscalYear int = NULL, --Mandatory
	@Scenario nvarchar(50) = 'ACTUAL',
	@FxRate_Scenario nvarchar(50) = NULL, 
	@PrevYearsYN bit = 0,
	@SequenceBM int = 511,

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
EXEC [spRun_Job_AdvConso] @UserID=-10, @InstanceID=527, @VersionID=1043, @Group='Group', @Entity = 'GGI01', @FiscalYear = 2021, @Debug=1
EXEC [spRun_Job_AdvConso] @UserID=-10, @InstanceID=529, @VersionID=1001, @Group='A', @Entity = '02', @FiscalYear = 2021, @Debug=1
EXEC [spRun_Job_AdvConso] @UserID=-10, @InstanceID=529, @VersionID=1001, @Group='C', @Entity = '02', @FiscalYear = 2021, @Debug=1
EXEC [spRun_Job_AdvConso] @UserID=-10, @InstanceID=576, @VersionID=1082, @Group = 'G_AXYZ', @Debug=1

EXEC [spRun_Job_AdvConso] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@Print int = 0,
	@MasterClosedFiscalYear int,
	@StartFiscalYear int,
	@EndFiscalYear int,
	@JournalTable nvarchar(100),
	@SQLStatement nvarchar(max),
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2190'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Start job for Advanced Consolidation Calculation',
			@MandatoryParameter = 'FiscalYear' --Without @, separated by |

		IF @Version = '2.1.1.2171' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2190' SET @Description = 'Handle Entity and Group as optional parameters.'

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

		SET @FxRate_Scenario = ISNULL(@FxRate_Scenario, @Scenario) 

		IF @FiscalYear IS NOT NULL SET @EndFiscalYear = @FiscalYear
		
		IF @PrevYearsYN <> 0
			BEGIN
				EXEC [pcINTEGRATOR].[dbo].[spGet_MasterClosedYear]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@MasterClosedFiscalYear = @MasterClosedFiscalYear OUT,
					@JobID = @JobID

				SET @StartFiscalYear = @MasterClosedFiscalYear + 1

				IF @StartFiscalYear IS NULL
					BEGIN
						EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT

						SET @SQLStatement = '
							SELECT @InternalVariable = MIN([FiscalYear]) FROM ' + @JournalTable + ' WHERE [Scenario] = ''' + @Scenario + ''''

						EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @StartFiscalYear OUT
					END
			END

		IF @DebugBM & 2 > 0
			SELECT
				[@BusinessRuleID] = @BusinessRuleID,
				[@Group] = @Group,
				[@Entity] = @Entity,
				[@FiscalYear] = @FiscalYear,
				[@FxRate_Scenario] = @FxRate_Scenario,
				[@MasterClosedFiscalYear] = @MasterClosedFiscalYear,
				[@StartFiscalYear] = @StartFiscalYear

	SET @Step = 'Calculate Advanced Consolidation'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
			{"TKey" : "BusinessRuleID",  "TValue": "' + CONVERT(nvarchar(10), @BusinessRuleID) + '"},
			{"TKey" : "SequenceBM",  "TValue": "' + CONVERT(nvarchar(10), @SequenceBM) + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}'
			+ CASE WHEN @StartFiscalYear IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "StartFiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @StartFiscalYear) + '"}' ELSE '' END +
			+ CASE WHEN @EndFiscalYear IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "EndFiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @EndFiscalYear) + '"}' ELSE '' END +
			+ CASE WHEN @FiscalYear IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @FiscalYear) + '"}' ELSE '' END +
			+ CASE WHEN @Group IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "ConsolidationGroup",  "TValue": "' + @Group + '"}' END +
			+ CASE WHEN @FxRate_Scenario IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "FxRate_Scenario",  "TValue": "' + @FxRate_Scenario + '"}' END +
			+ CASE WHEN @Entity IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity + '"}' END +
			']'

		IF @DebugBM & 2 > 0 PRINT @JSON

		EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spBR_BR05_New3', @JSON = @JSON

/*

		EXEC [pcINTEGRATOR].[dbo].[spBR_BR05_New3]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@BusinessRuleID = @BusinessRuleID,
			@SequenceBM = 125,
			@StartFiscalYear = @StartFiscalYear,
			@FiscalYear = @FiscalYear,
			@ConsolidationGroup = @Group,
			@FxRate_Scenario = @FxRate_Scenario, 
			@Entity_MemberKey = @Entity,
			@JobID = @JobID,
--			@Debug=@DebugSub,
			@DebugBM=19
*/
	--SET @Step = 'Refresh Cube'
	--	EXEC [pcINTEGRATOR].[dbo].[spRun_Job_Callisto_Generic]
	--		@UserID = @UserID,
	--		@InstanceID = @InstanceID,
	--		@VersionID = @VersionID,
	--		@StepName = 'Refresh',
	--		@AsynchronousYN = 1,
	--		@ModelName = 'Financials',
	--		@JobQueueStatusID = 1,
	--		@MasterCommand = @ProcedureName,
	--		@JobQueueYN = 1,
	--		@JobID = @JobID

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
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
