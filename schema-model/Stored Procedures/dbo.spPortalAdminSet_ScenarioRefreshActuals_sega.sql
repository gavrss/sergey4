SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_ScenarioRefreshActuals_sega]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL, --Optional, default NULL = all dataclasses
	@ScenarioID int = NULL,
	@SimplifyDimensionYN bit = NULL, --Default from Scenario table

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000123,
	@StartTime datetime = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spPortalAdminSet_ScenarioRefreshActuals] @InstanceID='572',@ScenarioID='4703',@UserID='9863',@VersionID='1080',@DebugBM=15

Comments:
Fetch from Scenario ActualOverwriteYN and ClosedMonth
If ActualOverwriteYN <> 0
	Copy FromTime=Beginning of Time, ToTime=ClosedMonth
	From Scenario Actual to selected Scenario
	YearOffset = 0 and SequenceBM=12

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_ScenarioRefreshActuals',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminSet_ScenarioRefreshActuals] @UserID=-10, @InstanceID = 454, @VersionID = 1021, @ScenarioID = 3896, @Debug=1

EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"572"},{"TKey":"ScenarioID","TValue":"4626"},{"TKey":"UserID","TValue":"9863"},
{"TKey":"VersionID","TValue":"1080"},{"TKey":"DebugBM","TValue":"7"}]', @ProcedureName='spPortalAdminSet_ScenarioRefreshActuals'

EXEC [spPortalAdminSet_ScenarioRefreshActuals] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ActualOverwriteYN BIT = 0,
	@StartMonth INT,
	@ClosedMonth INT,
	@CallistoDatabase NVARCHAR(100),
	@SQLStatement NVARCHAR(MAX),
	@Scenario_MemberKey NVARCHAR(50),
	@Scenario_MemberId BIGINT,
	@TimeDimID INT,
	@FromScenarioID INT,
	@JSON NVARCHAR(MAX),

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@InfoMessage NVARCHAR(1000),
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000),
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'SeGa',
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Replace data with actuals for selected Scenario until ClosedMonth',
			@MandatoryParameter = 'ScenarioID' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-109: Made generic.'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-109: Test on BusinessRules. Automatic refresh'
		IF @Version = '2.0.2.2148' SET @Description = 'Change RefreshActuals_MemberKey to Conversion_MemberKey.'
		IF @Version = '2.1.1.2172' SET @Description = 'Rework to use [spPortalAdminSet_ScenarioCopy] with @SequenceBM = 12.'
		IF @Version = '2.1.2.2182' SET @Description = 'Enhanced debugging; Updated to latest SP template. Use [spPortalAdminSet_ScenarioCopy] with parameter @RefreshActualsYN = 1.'
		IF @Version = '2.1.2.2199' SET @Description = 'Handle info message.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1


		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SELECT
			@ActualOverwriteYN = [ActualOverwriteYN],
			@Scenario_MemberKey = [MemberKey]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Scenario]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			ScenarioID = @ScenarioID AND
			SelectYN <> 0

		SELECT
			@FromScenarioID = ScenarioID
		FROM
			[pcINTEGRATOR_Data].[dbo].[Scenario]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			MemberKey = 'ACTUAL' AND
			SelectYN <> 0

		SELECT
			@ClosedMonth = MIN(ClosedMonth)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Scenario]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			MemberKey IN ('ACTUAL', @Scenario_MemberKey) AND
			SelectYN <> 0

	SET @Step = 'Check Actual Owerwrite'
		IF @ActualOverwriteYN = 0
			BEGIN
-- 				SET @Message = 'It is not allowed to Refresh to Actuals for selected Scenario.'
-- 				SET @Severity = 16
-- 				GOTO EXITPOINT
                SET @InfoMessage = 'It is not allowed to Refresh to Actuals for selected Scenario.';
                THROW 51000, @InfoMessage, 2;
			END

	SET @Step = 'Check Closed Month'
		IF @ClosedMonth IS NULL
			BEGIN
-- 				SET @Message = 'parameter ClosedMonth is not set for any valid Actual scenario.'
-- 				SET @Severity = 16
-- 				GOTO EXITPOINT
                SET @InfoMessage = 'parameter ClosedMonth is not set for any valid Actual scenario.';
                THROW 51000, @InfoMessage, 2;
			END

	SET @Step = 'Set time frame'
		SET @SQLStatement = '
			SELECT
				@InternalVariable = MIN(MemberId)
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Time]
			WHERE
				TimeFiscalYear_MemberId = (SELECT TimeFiscalYear_MemberId = MAX(TimeFiscalYear_MemberId) FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Time] WHERE MemberId = ' + CONVERT(nvarchar(15), @ClosedMonth) + ' AND [Level] = ''Month'') AND
				[Level] = ''Month'''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @StartMonth OUT

	SET @Step = 'Get @Scenario_MemberId'
		SET @SQLStatement = '
			SELECT
				@InternalVariable = S.MemberId
			FROM
				' + @CallistoDatabase + '.dbo.S_DS_Scenario S
			WHERE
				S.Label = ''' + @Scenario_MemberKey + ''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @Scenario_MemberId OUT

	SET @Step = 'Copy data'
		IF @DebugBM & 2 > 0 SELECT [@DataClassID] = @DataClassID, [@FromScenarioID] = @FromScenarioID, [@ToScenarioID] = @ScenarioID, [@FromTime] = @StartMonth, [@ToTime] = @ClosedMonth

		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
			{"TKey" : "SequenceBM",  "TValue": "12"},
			{"TKey" : "FromScenarioID",  "TValue": "' + CONVERT(nvarchar(10), @FromScenarioID) + '"},
			{"TKey" : "ToScenarioID",  "TValue": "' + CONVERT(nvarchar(10), @ScenarioID) + '"},
			{"TKey" : "FromTime",  "TValue": "' + CONVERT(nvarchar(10), @StartMonth) + '"},
			{"TKey" : "ToTime",  "TValue": "' + CONVERT(nvarchar(10), @ClosedMonth) + '"},
			{"TKey" : "RefreshActualsYN",  "TValue": "1"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}'
			+ CASE WHEN @SimplifyDimensionYN IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "SimplifyDimensionYN",  "TValue": "' + CONVERT(nvarchar(10), @SimplifyDimensionYN) + '"}' END +
			+ CASE WHEN @DataClassID IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "DataClassID",  "TValue": "' + CONVERT(nvarchar(10), @DataClassID) + '"}' END +
			']'

		IF @DebugBM & 2 > 0 PRINT @JSON

		EXEC [pcINTEGRATOR].[dbo].[spRun_Procedure_KeyValuePair] @ProcedureName = 'spPortalAdminSet_ScenarioCopy', @JSON = @JSON

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [ErrorNumber] = @ErrorNumber, [ErrorSeverity] = @ErrorSeverity, [ErrorState] = @ErrorState, [ErrorProcedure] = @ErrorProcedure, [ErrorStep] = @Step, [ErrorLine] = @ErrorLine, [ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
