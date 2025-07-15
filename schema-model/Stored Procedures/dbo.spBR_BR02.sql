SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR02]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@EventTypeID int = 0,
	@BusinessRuleID INT = NULL,
	@Filter NVARCHAR(4000) = NULL,
	@FromTime INT = NULL,
	@ToTime INT = NULL,
	@CallistoRefreshYN BIT = 1,
	@CallistoRefreshAsynchronousYN BIT = 1,
	@Parameter NVARCHAR(1000) = NULL, --Not used anywhere

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000442,
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

EXEC [pcINTEGRATOR].[dbo].[spBR_BR02] @BusinessRuleID=N'4799',@InstanceID=N'615',@Parameter=N'FiscalYear=FY2024',@UserID=N'13397',@VersionID=N'1102',@DebugBM=15

EXEC [pcINTEGRATOR].[dbo].[spBR_BR02] @BusinessRuleID='17339',@InstanceID='-1590',@Parameter='',@UserID='18518',@VersionID='-1590',@DebugBM=15

EXEC [pcINTEGRATOR].[dbo].[spBR_BR02] @BusinessRuleID='2633',@InstanceID='572',@Parameter='FiscalPeriod=4|FiscalYear=2022',@UserID='9863',@VersionID='1080',@DebugBM=7

EXEC [pcINTEGRATOR].[dbo].[spBR_BR02] @BusinessRuleID='2629',@CallistoRefreshAsynchronousYN='1',
@CallistoRefreshYN='0',@EventTypeID='-10',@InstanceID='572',@UserID='-10',@VersionID='1080',@DebugBM=3

EXEC [spBR_BR02] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID = 2004, @Filter='TimeFrom=201901|TimeTo=201903', @Debug=1
EXEC [spBR_BR02] @UserID=-10, @InstanceID=527, @VersionID=1043, @BusinessRuleID = 12315, @Filter='Time§FromTime=201901|Time§ToTime=201903|Entity=GGI01,GGI02', @DebugBM=7
EXEC [spBR_BR02] @UserID=-10, @InstanceID=454, @VersionID=1021, @BusinessRuleID = 2368, @Debug=1
EXEC [spBR_BR02] @UserID=-10, @InstanceID=-1590, @VersionID=-1590, @BusinessRuleID = 17339, @DebugBM=7

EXEC [spBR_BR02] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@StoredProcedure nvarchar(100),
	@Database nvarchar(100),
	@ExecParameter nvarchar(4000) = '',
	@JSON nvarchar(max),
	@JSONParameter nvarchar(4000) = '',

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2193'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Running business rule BR02.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-88: Mandatory parameters adjusted.'
		IF @Version = '2.1.1.2171' SET @Description = 'Updated template.'
		IF @Version = '2.1.1.2173' SET @Description = 'New parameters @FromTime and @ToTime. Use spRun_Procedure_KeyValuePair. Updated Statistics handling.'
		IF @Version = '2.1.2.2183' SET @Description = 'Handle parameters for BR02 StoredProcedure.'
		IF @Version = '2.1.2.2193' SET @Description = 'Handle @JSONParameter = NULL value.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			EXEC [pcINTEGRATOR].[dbo].[spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=1,
				@CheckCount = 0,
				@JobID=@JobID OUT

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1
		
	SET @Step = 'Create temp table #PipeStringSplit'
		CREATE TABLE #PipeStringSplit
			(
			[TupleNo] int,
			[PipeObject] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
 			[PipeFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Get BR02 parameters'
		SELECT 
			@Database = REPLACE(REPLACE([DatabaseName], '[', ''), ']', ''),
			@StoredProcedure = REPLACE(REPLACE([StoredProcedure], '[', ''), ']', ''),
			@FromTime = CASE WHEN @EventTypeID = 0 THEN @FromTime ELSE [FromTime] END,
			@ToTime = CASE WHEN @EventTypeID = 0 THEN @ToTime ELSE [ToTime] END,
			@Filter = CASE WHEN @EventTypeID = 0 THEN ISNULL(@Filter, @Parameter) ELSE [Filter] END
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR02_Master]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			BusinessRuleID = @BusinessRuleID AND
			DeletedID IS NULL

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@EventTypeID] = @EventTypeID,
				[@BusinessRuleID] = @BusinessRuleID,
				[@JobID] = @JobID,
				[@Debug] = @Debug,
				[@Database] = @Database,
				[@StoredProcedure] = @StoredProcedure,
				[@FromTime] = @FromTime,
				[@ToTime] = @ToTime,
				[@Filter] = @Filter

		EXEC [pcINTEGRATOR].[dbo].[spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @Filter
		IF @DebugBM & 2 > 0 SELECT TempTable = '#PipeStringSplit', * FROM #PipeStringSplit

		IF (SELECT COUNT(1) FROM #PipeStringSplit) > 0
			SELECT 
				@JSONParameter = @JSONParameter + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "' + [PipeObject] + '",  "TValue": "' + [PipeFilter] + '"}'
			FROM
				#PipeStringSplit
		IF @DebugBM & 2 > 0 SELECT [@JSONParameter] = @JSONParameter
		

	SET @Step = 'Run selected BusinessRule'
/*		
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
			{"TKey" : "EventTypeID",  "TValue": "' + CONVERT(nvarchar(10), @EventTypeID) + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}'
			+ CASE WHEN @AuthenticatedUserID IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "AuthenticatedUserID",  "TValue": "' + CONVERT(nvarchar(10), @AuthenticatedUserID) + '"}' ELSE '' END +
			+ CASE WHEN @FromTime IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "FromTime",  "TValue": "' + CONVERT(nvarchar(10), @FromTime) + '"}' ELSE '' END +
			+ CASE WHEN @ToTime IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "ToTime",  "TValue": "' + CONVERT(nvarchar(10), @FromTime) + '"}' ELSE '' END +
			+ CASE WHEN @Filter IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "Filter",  "TValue": "' + @Filter + '"}' ELSE '' END +
			']'
*/

		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}'
			+ CASE WHEN @AuthenticatedUserID IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "AuthenticatedUserID",  "TValue": "' + CONVERT(nvarchar(10), @AuthenticatedUserID) + '"}' ELSE '' END +
			+ CASE WHEN @FromTime IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "FromTime",  "TValue": "' + CONVERT(nvarchar(10), @FromTime) + '"}' ELSE '' END +
			+ CASE WHEN @ToTime IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "ToTime",  "TValue": "' + CONVERT(nvarchar(10), @FromTime) + '"}' ELSE '' END +
			+ CASE WHEN @JSONParameter IS NOT NULL THEN @JSONParameter ELSE '' END +
			']'
		IF @DebugBM & 2 > 0 PRINT @JSON

		EXEC [pcINTEGRATOR].[dbo].[spRun_Procedure_KeyValuePair]
			@DatabaseName = @Database,
			@ProcedureName = @StoredProcedure,
			@JSON = @JSON

	SET @Step = 'Drop temp table'
		DROP TABLE #PipeStringSplit

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Update statistics'
		EXEC [pcINTEGRATOR].[dbo].[spSet_ExpectedExecTime] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @BusinessRuleID=@BusinessRuleID, @Duration=@Duration, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	SET @Step = 'Set EndTime for the actual job'
		EXEC [pcINTEGRATOR].[dbo].[spSet_Job]
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
