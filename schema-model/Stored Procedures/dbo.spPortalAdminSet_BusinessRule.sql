SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_BusinessRule]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JSON_table nvarchar(MAX) = NULL,
	@ResultTypeBM int = NULL, --1 = BusinessRule, 4 = BusinessRuleEvent, 8 = EventType, 16 = BusinessRuleEvent_Parameter
	@BusinessRuleID int = NULL OUT,
	@BusinessRuleEventID int = NULL OUT,
	@EventTypeID int = NULL OUT,
    @BR_TypeID int = NULL,
    @BR_Name nvarchar(50) = NULL,
    @BR_Description nvarchar(255) = NULL,
	@SortOrder int = NULL,
	@SelectYN bit = 1,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000606,
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
	{"ResultTypeBM" : "1", "BusinessRuleID": "2006", "BR_TypeID": "1", "BR_Name": "Testname", "BR_Description": "Test description", "SortOrder": "10"},
	{"ResultTypeBM" : "1", "BusinessRuleID": "2005", "DeleteYN": "1"},
	{"ResultTypeBM" : "1", "BR_TypeID": "1", "BR_Name": "New rule 2", "BR_Description": "New Test description", "SortOrder": "20"},
	{"ResultTypeBM" : "4", "BusinessRuleEventID": "1005", "BusinessRuleID": "5065", "EventTypeID": "-10", "SortOrder": "10"},
	{"ResultTypeBM" : "4", "BusinessRuleEventID": "1003", "DeleteYN": "1"},
	{"ResultTypeBM" : "4", "BusinessRuleID": "5065", "EventTypeID": "-10", "SortOrder": "20"},
	{"ResultTypeBM" : "8", "EventTypeID": "1001", "EventTypeName": "Test Event", "EventTypeDescription": "Test Event Description"},
	{"ResultTypeBM" : "8", "EventTypeID": "1001", "DeleteYN": "1"},
	{"ResultTypeBM" : "8", "EventTypeName": "New Test Event 2", "EventTypeDescription": "New Test Event Description"},
	{"ResultTypeBM" : "16", "BusinessRuleEventID": "1003", "ParameterName": "@FromTime", "ParameterValue": "202001"},
	{"ResultTypeBM" : "16", "BusinessRuleEventID": "1003", "ParameterName": "@ToTime", "ParameterValue": "202002"},
	{"ResultTypeBM" : "16", "BusinessRuleEventID": "1001", "ParameterName": "@ToTime", "DeleteYN": "1"}
	]'
			
EXEC [spPortalAdminSet_BusinessRule]
	@UserID=-10,
	@InstanceID=424,
	@VersionID=1017,
	@JSON_table = @JSON_table,
	@DebugBM=1

EXEC [spPortalAdminSet_BusinessRule] @GetVersion = 1
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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2159'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain table BusinessRule and corresponding Event tables',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Changed parameter @BR_ID to @BusinessRuleID.'
		IF @Version = '2.0.3.2151' SET @Description = 'Added @SortOrder.'
		IF @Version = '2.0.3.2154' SET @Description = 'Renamed from spPortalAdminSet_BR_List to spPortalAdminSet_BusinessRule. Added Event and @JSON table.'
		IF @Version = '2.1.0.2157' SET @Description = 'Added @SelectYN.'
		IF @Version = '2.1.0.2159' SET @Description = 'DB-540: Added DeletedID IS NULL in the NOT EXISTS filter when inserting to [BusinessRule] for @ResulTypeBM = 1.'

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
			[BusinessRuleID] int,
			[BR_TypeID] int,
			[BR_Name] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BR_Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[BusinessRuleEventID] int,
			[EventTypeID] int,
			[EventTypeName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[EventTypeDescription] nvarchar(255) COLLATE DATABASE_DEFAULT,
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
				[BusinessRuleID],
				[BR_TypeID],
				[BR_Name],
				[BR_Description],
				[BusinessRuleEventID],
				[EventTypeID],
				[EventTypeName],
				[EventTypeDescription],
				[ParameterName],
				[ParameterValue],
				[SortOrder],
				[SelectYN],
				[DeleteYN]
				)
			SELECT
				[ResultTypeBM],
				[BusinessRuleID],
				[BR_TypeID],
				[BR_Name],
				[BR_Description],
				[BusinessRuleEventID],
				[EventTypeID],
				[EventTypeName],
				[EventTypeDescription],
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
				[BusinessRuleID] int,
				[BR_TypeID] int,
				[BR_Name] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[BR_Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[BusinessRuleEventID] int,
				[EventTypeID] int,
				[EventTypeName] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[EventTypeDescription] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[ParameterName] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[ParameterValue] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[SortOrder] int,
				[SelectYN] bit,
				[DeleteYN] bit
				)
		ELSE
			INSERT INTO #BRList
				(
				[ResultTypeBM],
				[BusinessRuleID],
				[BR_TypeID],
				[BR_Name],
				[BR_Description],
				[SortOrder],
				[SelectYN],
				[DeleteYN]
				)
			SELECT
				[ResultTypeBM] = ISNULL(@ResultTypeBM, 1),
				[BusinessRuleID] = @BusinessRuleID,
				[BR_TypeID] = @BR_TypeID,
				[BR_Name] = @BR_Name,
				[BR_Description] = @BR_Description,
				[SortOrder] = @SortOrder,
				[SelectYN] = @SelectYN,
				[DeleteYN] = @DeleteYN

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#BRList', * FROM #BRList

	SET @Step = 'Update ResultTypeBM = 1 (BusinessRule)'
		UPDATE BR
		SET
			[BR_TypeID] = ISNULL(BRL.[BR_TypeID], BR.[BR_TypeID]),
			[BR_Name] = ISNULL(BRL.[BR_Name], BR.[BR_Name]),
			[BR_Description] = ISNULL(BRL.[BR_Description], BR.[BR_Description]),
			[SortOrder] = ISNULL(BRL.[SortOrder], BR.[SortOrder]) 
		FROM
			[pcINTEGRATOR_Data].[dbo].[BusinessRule] BR
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 1 AND BRL.DeleteYN = 0 AND BRL.[BusinessRuleID] = BR.[BusinessRuleID] 
		WHERE
			BR.[InstanceID] = @InstanceID AND
			BR.[VersionID] = @VersionID AND
			BR.[DeletedID] IS NULL

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update ResultTypeBM = 4 (BusinessRuleEvent)'
		UPDATE BRE
		SET
			[BusinessRuleID] = ISNULL(BRL.[BusinessRuleID], BRE.[BusinessRuleID]),
			[EventTypeID] = ISNULL(BRL.[EventTypeID], BRE.[EventTypeID]),
			[SortOrder] = ISNULL(BRL.[SortOrder], BRE.[SortOrder]),
			[SelectYN] = ISNULL(BRL.[SelectYN], BRE.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent] BRE
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 4 AND BRL.DeleteYN = 0 AND BRL.[BusinessRuleEventID] = BRE.[BusinessRuleEventID] 
		WHERE
			BRE.[InstanceID] = @InstanceID AND
			BRE.[VersionID] = @VersionID AND
			BRE.[DeletedID] IS NULL

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update ResultTypeBM = 8 (EventType)'
		UPDATE ET
		SET
			[EventTypeName] = ISNULL(BRL.[EventTypeName], ET.[EventTypeName]),
			[EventTypeDescription] = ISNULL(BRL.[EventTypeDescription], ET.[EventTypeDescription]),
			[SelectYN] = ISNULL(BRL.[SelectYN], ET.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[EventType] ET
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 8 AND BRL.DeleteYN = 0 AND BRL.[EventTypeID] = ET.[EventTypeID] 
		WHERE
			ET.[InstanceID] = @InstanceID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update ResultTypeBM = 16 (BusinessRuleEvent_Parameter)'
		UPDATE BREP
		SET
			[ParameterValue] = ISNULL(BRL.[ParameterValue], BREP.[ParameterValue])
		FROM
			[pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent_Parameter] BREP
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 16 AND BRL.DeleteYN = 0 AND BRL.[BusinessRuleEventID] = BREP.[BusinessRuleEventID] AND BRL.[ParameterName] = BREP.[ParameterName] 
		WHERE
			BREP.[InstanceID] = @InstanceID AND
			BREP.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Delete ResultTypeBM = 1 (BusinessRule)'
		IF CURSOR_STATUS('global','DeleteBusinessRule_Cursor') >= -1 DEALLOCATE DeleteBusinessRule_Cursor
		DECLARE DeleteBusinessRule_Cursor CURSOR FOR
			
			SELECT
				BusinessRuleID
			FROM
				#BRList
			WHERE
				ResultTypeBM = 1 AND
				DeleteYN <> 0 AND
				BusinessRuleID IS NOT NULL

			OPEN DeleteBusinessRule_Cursor
			FETCH NEXT FROM DeleteBusinessRule_Cursor INTO @BusinessRuleID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@BusinessRuleID] = @BusinessRuleID

					EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'BusinessRule', @DeletedID = @DeletedID OUT

					UPDATE BR
					SET
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[BusinessRule] BR
					WHERE
						BR.[InstanceID] = @InstanceID AND
						BR.[VersionID] = @VersionID AND
						BR.[BusinessRuleID] = @BusinessRuleID

					SET @Deleted = @Deleted + @@ROWCOUNT

					FETCH NEXT FROM DeleteBusinessRule_Cursor INTO @BusinessRuleID
				END

		CLOSE DeleteBusinessRule_Cursor
		DEALLOCATE DeleteBusinessRule_Cursor

	SET @Step = 'Delete ResultTypeBM = 4 (BusinessRuleEvent)'
		IF CURSOR_STATUS('global','DeleteBusinessRuleEvent_Cursor') >= -1 DEALLOCATE DeleteBusinessRuleEvent_Cursor
		DECLARE DeleteBusinessRuleEvent_Cursor CURSOR FOR
			
			SELECT
				BusinessRuleEventID
			FROM
				#BRList
			WHERE
				ResultTypeBM = 4 AND
				DeleteYN <> 0 AND
				BusinessRuleEventID IS NOT NULL

			OPEN DeleteBusinessRuleEvent_Cursor
			FETCH NEXT FROM DeleteBusinessRuleEvent_Cursor INTO @BusinessRuleEventID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@BusinessRuleEventID] = @BusinessRuleEventID

					EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'BusinessRuleEvent', @DeletedID = @DeletedID OUT

					UPDATE BRE
					SET
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent] BRE
					WHERE
						BRE.[InstanceID] = @InstanceID AND
						BRE.[VersionID] = @VersionID AND
						BRE.[BusinessRuleEventID] = @BusinessRuleEventID

					SET @Deleted = @Deleted + @@ROWCOUNT

					FETCH NEXT FROM DeleteBusinessRuleEvent_Cursor INTO @BusinessRuleEventID
				END

		CLOSE DeleteBusinessRuleEvent_Cursor
		DEALLOCATE DeleteBusinessRuleEvent_Cursor

	SET @Step = 'Delete ResultTypeBM = 8 (EventType)'
		DELETE ET
		FROM
			[pcINTEGRATOR_Data].[dbo].[EventType] ET
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 8 AND BRL.DeleteYN <> 0 AND BRL.EventTypeID = ET.EventTypeID
		WHERE
			ET.[InstanceID] = @InstanceID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete ResultTypeBM = 16 (BusinessRuleEvent_Parameter)'
		DELETE BREP
		FROM
			[pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent_Parameter] BREP
			INNER JOIN #BRList BRL ON BRL.ResultTypeBM = 16 AND BRL.DeleteYN <> 0 AND BRL.[BusinessRuleEventID] = BREP.[BusinessRuleEventID] AND BRL.[ParameterName] = BREP.[ParameterName]
		WHERE
			BREP.[InstanceID] = @InstanceID AND
			BREP.[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Insert new member ResultTypeBM = 1 (BusinessRule)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[BusinessRule]
			(
			[InstanceID],
			[VersionID],
			[BR_TypeID],
			[BR_Name],
			[BR_Description],
			[SortOrder],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[BR_TypeID] = BRL.[BR_TypeID],
			[BR_Name] = BRL.[BR_Name],
			[BR_Description] = BRL.[BR_Description],
			[SortOrder] = ISNULL(BRL.[SortOrder], 0),
			[SelectYN] = BRL.[SelectYN]
		FROM
			#BRList BRL
		WHERE
			BRL.[ResultTypeBM] = 1 AND
			BRL.[BusinessRuleID] IS NULL AND
			BRL.[DeleteYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BusinessRule] D WHERE D.[InstanceID] = @InstanceID AND D.[VersionID] = @VersionID AND D.[BR_TypeID] = BRL.[BR_TypeID] AND D.[BR_Name] = BRL.[BR_Name] AND D.DeletedID IS NULL)

		SET @Inserted_Local = @@ROWCOUNT
		IF @Inserted_Local = 0 
			SET @BusinessRuleID = NULL
		ELSE
			BEGIN
				SET @Inserted = @Inserted + @Inserted_Local
				SELECT @BusinessRuleID = MAX(BR.[BusinessRuleID]) FROM [pcINTEGRATOR_Data].[dbo].[BusinessRule] BR WHERE BR.[InstanceID] = @InstanceID AND BR.[VersionID] = @VersionID
			END

	SET @Step = 'Insert new member ResultTypeBM = 4 (BusinessRuleEvent)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent]
			(
			[InstanceID],
			[VersionID],
			[BusinessRuleID],
			[EventTypeID],
			[SortOrder],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[BusinessRuleID] = BRL.[BusinessRuleID],
			[EventTypeID] = BRL.[EventTypeID],
			[SortOrder] = ISNULL(BRL.[SortOrder], 0),
			[SelectYN] = BRL.[SelectYN]
		FROM
			#BRList BRL
		WHERE
			BRL.[ResultTypeBM] = 4 AND
			BRL.[BusinessRuleEventID] IS NULL AND
			BRL.[DeleteYN] = 0

		SET @Inserted_Local = @@ROWCOUNT
		IF @Inserted_Local = 0
			SET @BusinessRuleEventID = NULL
		ELSE
			BEGIN
				SET @Inserted = @Inserted + @Inserted_Local
				SELECT @BusinessRuleEventID = MAX(BRE.[BusinessRuleEventID]) FROM [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent] BRE WHERE BRE.[InstanceID] = @InstanceID AND BRE.[VersionID] = @VersionID
			END

	SET @Step = 'Insert new member ResultTypeBM = 8 (EventType)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[EventType]
			(
			[InstanceID],
			[EventTypeName],
			[EventTypeDescription],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[EventTypeName] = BRL.[EventTypeName],
			[EventTypeDescription] = BRL.[EventTypeDescription],
			[SelectYN] = BRL.[SelectYN]
		FROM
			#BRList BRL
		WHERE
			BRL.[ResultTypeBM] = 8 AND
			BRL.[EventTypeID] IS NULL AND
			BRL.[DeleteYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[EventType] D WHERE D.[InstanceID] = @InstanceID AND D.[EventTypeName] = BRL.[EventTypeName]) AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[@Template_EventType] S WHERE S.[InstanceID] = 0 AND S.[EventTypeName] = BRL.[EventTypeName])

		SET @Inserted_Local = @@ROWCOUNT
		IF @Inserted_Local = 0
			SET @EventTypeID = NULL
		ELSE
			BEGIN
				SET @Inserted = @Inserted + @Inserted_Local
				SELECT @EventTypeID = MAX(ET.[EventTypeID]) FROM [pcINTEGRATOR_Data].[dbo].[EventType] ET WHERE ET.[InstanceID] = @InstanceID
			END

	SET @Step = 'Insert new member ResultTypeBM = 16 (BusinessRuleEvent_Parameter)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent_Parameter]
			(
			[InstanceID],
			[VersionID],
			[BusinessRuleEventID],
			[ParameterName],
			[ParameterValue]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[BusinessRuleEventID] = BRL.[BusinessRuleEventID],
			[ParameterName] = BRL.[ParameterName],
			[ParameterValue] = BRL.[ParameterValue]
		FROM
			#BRList BRL
		WHERE
			BRL.[ResultTypeBM] = 16 AND
			BRL.[DeleteYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent_Parameter] D WHERE D.[BusinessRuleEventID] = BRL.[BusinessRuleEventID] AND D.[ParameterName] = BRL.[ParameterName])

		SELECT
			@Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return Rows'
		IF @DebugBM & 1 > 0
			BEGIN
				SELECT [Table] = 'BusinessRule', * FROM [pcINTEGRATOR_Data].[dbo].[BusinessRule] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID ORDER BY [BusinessRuleID]
				SELECT [Table] = 'BusinessRuleEvent', * FROM [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID ORDER BY [BusinessRuleEventID]
				SELECT [Table] = 'EventType', * FROM [pcINTEGRATOR_Data].[dbo].[EventType] WHERE [InstanceID] = @InstanceID ORDER BY [EventTypeID]
				SELECT [Table] = 'BusinessRuleEvent_Parameter', * FROM [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent_Parameter] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID ORDER BY [BusinessRuleEventID], [ParameterName]
			END

	SET @Step = 'Return new MemberIDs'
		SELECT
			[@BusinessRuleID] = @BusinessRuleID,
			[@BusinessRuleEventID] = @BusinessRuleEventID,
			[@EventTypeID] = @EventTypeID

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
