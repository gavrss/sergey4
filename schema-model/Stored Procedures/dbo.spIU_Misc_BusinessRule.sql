SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Misc_BusinessRule]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@EventTypeID int = NULL,
	@JobStepTypeBM int = NULL,
	@JobStepID int = NULL,
	@FromTime int = NULL,
	@ToTime int = NULL,
	@Filter nvarchar(4000) = NULL,
	@CallistoRefreshYN bit = 1,
	@CallistoRefreshAsynchronousYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000683,
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
EXEC [pcINTEGRATOR].[dbo].[spIU_Misc_BusinessRule] @Debug='0',@EventTypeID='-10',@InstanceID='578',@UserID='-10',@VersionID='1081',@DebugBM=15
EXEC [spIU_Misc_BusinessRule] @UserID=-10, @InstanceID=572, @VersionID=1080, @EventTypeID = -10, @DebugBM=3

EXEC [spIU_Misc_BusinessRule] @UserID=-10, @InstanceID=572, @VersionID=1080, @EventTypeID = -10, @CallistoRefreshYN=1, @DebugBM=3

EXEC [spIU_Misc_BusinessRule] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@BusinessRuleID int,
	@BR_TypeCode nvarchar(6),
	@spBusinessRule nvarchar(100),
	@SQLStatement nvarchar(max),
	@BusinessRuleValue int,
	@BusinessRuleEventID int,
	@JSON nvarchar(max),
	@ParameterName nvarchar(50),
	@ParameterValue nvarchar(4000) = '',
	@DataClassName nvarchar(50),
	@EnhancedStorageYN bit,

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2193'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Calculate all BusinessRules for selected EventType',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-494: Added parameter handling for @spBusinessRule = spBR_BR02.'
		IF @Version = '2.1.0.2158' SET @Description = 'DB-535: Added parameter @BusinessRuleID when calling [spBR_BR0*].'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine [spSet_Job].'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.1.2171' SET @Description = 'Handled [BusinessRuleEvent_Parameter].[ParameterName] with or without @ symbol. Changed temp table name #EventParameter to #EventParameter to avoid conflicts.'
		IF @Version = '2.1.1.2174' SET @Description = 'Added parameters @CallistoRefreshYN and @CallistoRefreshAsynchronousYN defaulted to 1. Added generic parameters.'
		IF @Version = '2.1.2.2181' SET @Description = 'DB-1216: Disable Callisto Refresh during BusinessRule_Cursor execution; only run Callisto Refresh at the end of all business rules execution.'
		IF @Version = '2.1.2.2185' SET @Description = 'Only run Callisto Refresh if there are existing BusinessRules.'
		IF @Version = '2.1.2.2187' SET @Description = 'Handle AutoEventTypeID.'
		IF @Version = '2.1.2.2193' SET @Description = 'Handle @CallistoRefreshYN and @EnhancedStorageYN.'

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

		IF @EventTypeID IS NULL
			SELECT @EventTypeID = CASE WHEN @JobStepTypeBM & 16 > 0 THEN -10 ELSE CASE WHEN @JobStepTypeBM & 32 > 0 THEN -20 END END

		SELECT
			@EnhancedStorageYN = A.[EnhancedStorageYN]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@EventTypeID] = @EventTypeID,
				[@CallistoRefreshYN] = @CallistoRefreshYN,
				[@CallistoRefreshAsynchronousYN] = @CallistoRefreshAsynchronousYN,
				[@EnhancedStorageYN] = @EnhancedStorageYN

	SET @Step = 'Check @EventTypeID is set'
		IF @EventTypeID IS NULL
			BEGIN
				SET @Message = '@EventTypeID must be set.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			EXEC [spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=0,
				@JobID=@JobID OUT

	SET @Step = 'Create temp table #EventParameter'
		CREATE TABLE #EventParameter
			(
			[ParameterName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[ParameterValue] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

	SET @Step = 'Fill table #BusinessRule_Cursor'
		SELECT DISTINCT
			[BusinessRuleEventID] = BRE.[BusinessRuleEventID],
			[BusinessRuleID] = BRE.[BusinessRuleID],
			[spBusinessRule] = 'spBR_' + BRT.[BR_TypeCode],
			[SortOrder] = BRE.[SortOrder]
		INTO
			#BusinessRule_Cursor
		FROM
			[pcINTEGRATOR].[dbo].[EventType] ET
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent] BRE ON BRE.[InstanceID] = @InstanceID AND BRE.[VersionID] = @VersionID AND BRE.[EventTypeID] = ET.[EventTypeID] AND BRE.[SelectYN] <> 0 AND BRE.[DeletedID] IS NULL
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRule] BR ON BR.[InstanceID] = BRE.[InstanceID] AND BR.[VersionID] = BRE.[VersionID] AND BR.[BusinessRuleID] = BRE.[BusinessRuleID] AND BR.[SelectYN] <> 0 AND BR.[DeletedID] IS NULL
			INNER JOIN [pcINTEGRATOR].[dbo].[BR_Type] BRT ON BRT.[InstanceID] IN (0, BRE.[InstanceID]) AND BRT.[VersionID] IN (0, BRE.[VersionID]) AND BRT.[BR_TypeID] = BR.[BR_TypeID]
		 WHERE
			ET.[InstanceID] IN (0, @InstanceID) AND
			ISNULL(ET.[AutoEventTypeID], ET.[EventTypeID]) = @EventTypeID AND
			ET.[SelectYN] <> 0
		ORDER BY
			BRE.[SortOrder]

		IF @Debug <> 0 SELECT TempTable = '#BusinessRule_Cursor', * FROM #BusinessRule_Cursor ORDER BY [SortOrder]

	SET @Step = 'Run BusinessRule_Cursor'
		IF CURSOR_STATUS('global','BusinessRule_Cursor') >= -1 DEALLOCATE BusinessRule_Cursor
		DECLARE BusinessRule_Cursor CURSOR FOR

		SELECT
			[BusinessRuleEventID],
			[BusinessRuleID],
			[spBusinessRule]
		FROM
			#BusinessRule_Cursor
		ORDER BY
			[SortOrder]
		
		OPEN BusinessRule_Cursor

		FETCH NEXT FROM BusinessRule_Cursor INTO @BusinessRuleEventID, @BusinessRuleID, @spBusinessRule
	
		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@BusinessRuleEventID] = @BusinessRuleEventID, [@BusinessRuleID] = @BusinessRuleID, [@spBusinessRule] = @spBusinessRule

				TRUNCATE TABLE #EventParameter

				INSERT INTO #EventParameter
					(
					[ParameterName],
					[SortOrder]
					)
				SELECT DISTINCT
					[ParameterName] = [par].[name],
					[SortOrder] = [par].[parameter_id]
				FROM
					[pcINTEGRATOR].[sys].[procedures] [proc]
					INNER JOIN [pcINTEGRATOR].[sys].[parameters] [par] ON [par].[object_id] = [proc].[object_id] AND [par].[name] NOT IN ('@JobLogID','@SetJobLogYN','@Rows','@ProcedureID','@StartTime','@Duration','@Deleted','@Inserted','@Updated','@Selected','@GetVersion','@Debug','@DebugBM')
				WHERE
					[proc].[name] = @spBusinessRule

				IF @DebugBM & 2 > 0 SELECT TempTable = '#EventParameter_1', * FROM #EventParameter ORDER BY [SortOrder]

				IF CURSOR_STATUS('global','EventParameter_Cursor') >= -1 DEALLOCATE EventParameter_Cursor
				DECLARE EventParameter_Cursor CURSOR FOR
			
					SELECT 
						[ParameterName]
					FROM
						#EventParameter
					ORDER BY
						[SortOrder]

					OPEN EventParameter_Cursor
					FETCH NEXT FROM EventParameter_Cursor INTO @ParameterName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@ParameterName] = @ParameterName

							IF @ParameterName = '@UserID' UPDATE #EventParameter SET [ParameterValue] = @UserID WHERE [ParameterName] = '@UserID' 
							ELSE IF @ParameterName = '@InstanceID' UPDATE #EventParameter SET [ParameterValue] = @InstanceID WHERE [ParameterName] = '@InstanceID' 
							ELSE IF @ParameterName = '@VersionID' UPDATE #EventParameter SET [ParameterValue] = @VersionID WHERE [ParameterName] = '@VersionID' 
							ELSE IF @ParameterName = '@EventTypeID' UPDATE #EventParameter SET [ParameterValue] = @EventTypeID WHERE [ParameterName] = '@EventTypeID' 
							ELSE IF @ParameterName = '@BusinessRuleID' UPDATE #EventParameter SET [ParameterValue] = @BusinessRuleID WHERE [ParameterName] = '@BusinessRuleID' 
							ELSE IF @ParameterName = '@JobStepTypeBM' UPDATE #EventParameter SET [ParameterValue] = @JobStepTypeBM WHERE [ParameterName] = '@JobStepTypeBM' 
							ELSE IF @ParameterName = '@JobStepID' UPDATE #EventParameter SET [ParameterValue] = @JobStepID WHERE [ParameterName] = '@JobStepID' 
							ELSE IF @ParameterName = '@FromTime' UPDATE #EventParameter SET [ParameterValue] = @FromTime WHERE [ParameterName] = '@FromTime' 
							ELSE IF @ParameterName = '@ToTime' UPDATE #EventParameter SET [ParameterValue] = @ToTime WHERE [ParameterName] = '@ToTime' 
							ELSE IF @ParameterName = '@Filter' UPDATE #EventParameter SET [ParameterValue] = @Filter WHERE [ParameterName] = '@Filter' 
							ELSE IF @ParameterName = '@CallistoRefreshYN' UPDATE #EventParameter SET [ParameterValue] = '0' WHERE [ParameterName] = '@CallistoRefreshYN' 
							ELSE IF @ParameterName = '@CallistoRefreshAsynchronousYN' UPDATE #EventParameter SET [ParameterValue] = @CallistoRefreshAsynchronousYN WHERE [ParameterName] = '@CallistoRefreshAsynchronousYN' 
							ELSE IF @ParameterName = '@JobID' UPDATE #EventParameter SET [ParameterValue] = @JobID WHERE [ParameterName] = '@JobID' 
							ELSE IF @ParameterName = '@AuthenticatedUserID' UPDATE #EventParameter SET [ParameterValue] = @AuthenticatedUserID WHERE [ParameterName] = '@AuthenticatedUserID' 							

							FETCH NEXT FROM EventParameter_Cursor INTO @ParameterName
						END

				CLOSE EventParameter_Cursor
				DEALLOCATE EventParameter_Cursor

				UPDATE EP
				SET
					[ParameterValue] = BREP.[ParameterValue]
				FROM
					#EventParameter EP
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent_Parameter] BREP ON (BREP.[ParameterName] = EP.ParameterName OR '@' + BREP.[ParameterName] = EP.ParameterName)
				WHERE
					EP.[ParameterValue] IS NULL AND
					BREP.[InstanceID] = @InstanceID AND
					BREP.[VersionID] = @VersionID AND
					BREP.[BusinessRuleEventID] = @BusinessRuleEventID

				IF @DebugBM & 2 > 0 SELECT TempTable = '#EventParameter_2', * FROM #EventParameter ORDER BY [SortOrder]

				SET @JSON = '['
				SELECT
					@JSON = @JSON + CHAR(13) + CHAR(10) + '{"TKey" : "' + SUBSTRING([ParameterName], 2, 100) + '", "TValue": "' + [ParameterValue] + '"},'
				FROM
					#EventParameter
				WHERE
					[ParameterValue] IS NOT NULL
				ORDER BY
					[SortOrder]

				SET @JSON = LEFT(@JSON, LEN(@JSON) - 1) + CHAR(13) + CHAR(10) + ']'

				IF @DebugBM & 2 > 0 PRINT @JSON

				EXEC spRun_Procedure_KeyValuePair
					@ProcedureName = @spBusinessRule,
					@JobStepID = @JobStepID,
					@JSON = @JSON

				FETCH NEXT FROM BusinessRule_Cursor INTO @BusinessRuleEventID, @BusinessRuleID, @spBusinessRule
			END

		CLOSE BusinessRule_Cursor
		DEALLOCATE BusinessRule_Cursor

	SET @Step = 'Run Callisto Refresh on all DataClasses'
		IF @CallistoRefreshYN <> 0 AND @EnhancedStorageYN = 0 AND (SELECT COUNT(1) FROM #BusinessRule_Cursor) > 0
			BEGIN
				IF CURSOR_STATUS('global','DataClass_Cursor') >= -1 DEALLOCATE DataClass_Cursor
				DECLARE DataClass_Cursor CURSOR FOR

				SELECT
					[DataClassName]
				FROM
					[pcINTEGRATOR].[dbo].[DataClass]
				WHERE 
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND 
					[StorageTypeBM] & 4 > 0 AND 
					[SelectYN] <> 0
		
				OPEN DataClass_Cursor

				FETCH NEXT FROM DataClass_Cursor INTO @DataClassName
	
				WHILE @@FETCH_STATUS = 0
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@DataClassName] = @DataClassName

						EXEC [spRun_Job_Callisto_Generic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StepName = 'Refresh', @ModelName = @DataClassName, @AsynchronousYN = @CallistoRefreshAsynchronousYN, @JobID = @JobID

						FETCH NEXT FROM DataClass_Cursor INTO @DataClassName
					END

				CLOSE DataClass_Cursor
				DEALLOCATE DataClass_Cursor
			END

	SET @Step = 'Drop temp table'
		DROP TABLE #EventParameter
		DROP TABLE #BusinessRule_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
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
	EXEC [pcINTEGRATOR].[dbo].[spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
