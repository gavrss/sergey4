SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR00]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@EventTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000605,
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
EXEC [spBR_BR00] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID = 5065, @JobID = 556, @Debug=1
EXEC [spBR_BR00] @UserID='7707',@InstanceID='454',@VersionID='1021',@BusinessRuleID='2372'

EXEC [spBR_BR00] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@BusinessRule_SubID int,
	@spBusinessRule nvarchar(100),
	@JSON nvarchar(max),
	@CalledYN bit = 1,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.1.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Calculate all BusinessRules for selected Group',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'DB-627, DB-628: Added JSON parameter [BusinessRuleID] in BR00_Cursor.'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle JobID.'
		IF @Version = '2.1.1.2199' SET @Description = 'Change BR00_Cursor from global to LOCAL'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy = @ModifiedBy, @JobID = @ProcedureID
		RETURN
	END

SET NOCOUNT ON

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
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

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			EXEC [spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=1,
				@CheckCount = 0,
				@JobID=@JobID OUT

	SET @Step = 'Create temp table #GroupParameter'
		IF OBJECT_ID(N'TempDB.dbo.#GroupParameter', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #GroupParameter
					(
					[ParameterName] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[ParameterValue] nvarchar(50) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Fill table #BR00_Cursor'
		SELECT DISTINCT
			[BusinessRule_SubID] = BRS.[BusinessRule_SubID],
			[spBusinessRule] = 'spBR_' + BRT.[BR_TypeCode],
			[SortOrder] = BRS.[SortOrder]
		INTO
			#BR00_Cursor
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR00_Step] BRS
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRule] BR ON BR.[InstanceID] = BRS.[InstanceID] AND BR.[VersionID] = BRS.[VersionID] AND BR.[BusinessRuleID] = BRS.[BusinessRule_SubID] AND BR.[SelectYN] <> 0 AND BR.[DeletedID] IS NULL
			INNER JOIN [pcINTEGRATOR].[dbo].[BR_Type] BRT ON BRT.[InstanceID] IN (0, BRS.[InstanceID]) AND BRT.[VersionID] IN (0, BRS.[VersionID]) AND BRT.[BR_TypeID] = BR.[BR_TypeID]
		 WHERE
			BRS.[InstanceID] = @InstanceID AND
			BRS.[VersionID] = @VersionID AND
			BRS.[BusinessRuleID] = @BusinessRuleID AND
			BRS.[SelectYN] <> 0
		ORDER BY
			[SortOrder]

		IF @Debug <> 0 SELECT TempTable = '#BR00_Cursor', * FROM #BR00_Cursor ORDER BY [SortOrder]

	SET @Step = 'Run BR00_Cursor'
		IF CURSOR_STATUS('LOCAL','BR00_Cursor') >= -1 DEALLOCATE BR00_Cursor
		DECLARE BR00_Cursor CURSOR LOCAL FOR

		SELECT
			[BusinessRule_SubID],
			[spBusinessRule]
		FROM
			#BR00_Cursor
		ORDER BY
			[SortOrder]

		OPEN BR00_Cursor

		FETCH NEXT FROM BR00_Cursor INTO @BusinessRule_SubID, @spBusinessRule

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@BusinessRule_SubID] = @BusinessRule_SubID, [@spBusinessRule] = @spBusinessRule

				TRUNCATE TABLE #GroupParameter

				SET @JSON = '
					[
					{"TKey" : "UserID", "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
					{"TKey" : "InstanceID", "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
					{"TKey" : "VersionID", "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
					{"TKey" : "BusinessRuleID", "TValue": "' + CONVERT(nvarchar(15), @BusinessRule_SubID) + '"},
					{"TKey" : "EventTypeID", "TValue": "0"},
					{"TKey" : "JobID", "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
					{"TKey" : "Debug", "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}'

				INSERT INTO #GroupParameter
					(
					[ParameterName],
					[ParameterValue]
					)
				SELECT DISTINCT
					[ParameterName] = BRP.[ParameterName],
					[ParameterValue] = BRP.[ParameterValue]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR00_Parameter] BRP
					INNER JOIN sys.procedures [proc] ON [proc].[name] = @spBusinessRule
					INNER JOIN sys.parameters [par] ON [par].[object_id] = [proc].[object_id] AND [par].[name] = BRP.[ParameterName]
				WHERE
					BRP.[InstanceID] = @InstanceID AND
					BRP.[VersionID] = @VersionID AND
					BRP.[BusinessRuleID] = @BusinessRuleID
				ORDER BY
					BRP.[ParameterName]

				SELECT
					@JSON = @JSON + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "' + REPLACE([ParameterName], '@', '') + '",  "TValue": "' + CONVERT(nvarchar(100), [ParameterValue]) + '"}'
				FROM
					#GroupParameter
				ORDER BY
					[ParameterName]

				SET @JSON = @JSON + ']'

				IF @DebugBM & 2 > 0 PRINT @JSON

				EXEC spRun_Procedure_KeyValuePair
					@ProcedureName = @spBusinessRule,
					@JSON = @JSON

				FETCH NEXT FROM BR00_Cursor INTO @BusinessRule_SubID, @spBusinessRule
			END

		CLOSE BR00_Cursor
		DEALLOCATE BR00_Cursor

	SET @Step = 'Drop temp table'
		IF @CalledYN = 0 DROP TABLE #GroupParameter
		DROP TABLE #BR00_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

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
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
