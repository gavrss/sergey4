SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_BusinessRule]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@BusinessRuleEventID int = NULL,
	@EventTypeID int = NULL,
	
	@ResultTypeBM int = 63, --1 = BusinessRule, 2 = BR_Type, 4 = BusinessRuleEvent, 8 = EventType, 16 = BusinessRuleEvent_Parameter, 32 = Parameter
	@DimensionID int = NULL, --Optional for @ResultTypeBM = 1
	@MemberKey nvarchar(100) = NULL, --Optional for @ResultTypeBM = 1

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000602,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_BusinessRule',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_BusinessRule] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleEventID = 1003, @Debug=1
EXEC [spPortalAdminGet_BusinessRule] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleEventID = 1003, @ResultTypeBM = 48, @Debug=1
EXEC [spPortalAdminGet_BusinessRule] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleEventID = 1004, @ResultTypeBM = 32, @Debug=1
EXEC [spPortalAdminGet_BusinessRule] @UserID=-10, @InstanceID=424, @VersionID=1017, @ResultTypeBM = 1, @DimensionID = -1, @MemberKey='ST_AB_Impair', @Debug=1

EXEC [spPortalAdminGet_BusinessRule] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DimensionName nvarchar(100),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2164'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get a list of available business rules',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Added SortOrder.'
		IF @Version = '2.0.3.2154' SET @Description = 'Renamed from spPortalAdminGet_BR_List to spPortalAdminGet_BusinessRule. Added ResultTypeBM 4, 8, 16.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-490: Modified query for @ResultTypeBM = 16.'
		IF @Version = '2.1.0.2164' SET @Description = 'Added optional parameters @DimensionID and @MemberKey valid for @ResultTypeBM = 1'

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

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Step = 'BusinessRule'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				IF @DimensionID IS NULL AND @MemberKey IS NULL
					BEGIN
						SELECT 
							[ResultTypeBM] = 1,
							[BR_TypeID],
							[BusinessRuleID],
							[BR_Name],
							[BR_Description],
							[SortOrder],
							[SelectYN]
						FROM
							[pcINTEGRATOR_Data].[dbo].[BusinessRule]
						WHERE
							[InstanceID] = @InstanceID AND
							[VersionID] = @VersionID AND
							([BusinessRuleID] = @BusinessRuleID OR @BusinessRuleID IS NULL) AND
							[DeletedID] IS NULL
						ORDER BY
							[SortOrder],
							[BusinessRuleID],
							[BR_TypeID],
							[BR_Name]

						SET @Selected = @Selected + @@ROWCOUNT
					END
				ELSE
					BEGIN
						SELECT
							@DimensionName = DimensionName
						FROM
							Dimension
						WHERE
							InstanceID IN (0, @InstanceID) AND
							DimensionID = @DimensionID

						IF @Debug <> 0 SELECT [@DimensionName] = @DimensionName

						SELECT 
							[ResultTypeBM] = 1,
							[BR_TypeID] = BR.[BR_TypeID],
							[BusinessRuleID] = BR.[BusinessRuleID],
							[BR_Name] = BR.[BR_Name],
							[BR_Description] = BR.[BR_Description],
							[BR01_StepID] = S.[BR01_StepID],
							[SortOrder] = BR.[SortOrder],
							[SelectYN] = BR.[SelectYN]
						FROM
							[pcINTEGRATOR_Data].[dbo].[BusinessRule] BR
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[BR01_Master] M ON M.[InstanceID]=BR.[InstanceID] AND M.[VersionID]=BR.[VersionID] AND M.[BusinessRuleID]=BR.[BusinessRuleID] AND M.[DeletedID] IS NULL AND (M.[BaseObject]=@DimensionName OR @DimensionID IS NULL)
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[BR01_Step] S ON S.[InstanceID]=BR.[InstanceID] AND S.[VersionID]=BR.[VersionID] AND S.[BusinessRuleID]=BR.[BusinessRuleID] AND S.[BR01_StepPartID]=-1 AND (S.[MemberKey]=@MemberKey OR @MemberKey IS NULL)
						WHERE
							BR.[InstanceID] = @InstanceID AND
							BR.[VersionID] = @VersionID AND
							(BR.[BusinessRuleID] = @BusinessRuleID OR @BusinessRuleID IS NULL) AND
							BR.[DeletedID] IS NULL
						ORDER BY
							BR.[SortOrder],
							BR.[BusinessRuleID],
							BR.[BR_TypeID],
							BR.[BR_Name]

						SET @Selected = @Selected + @@ROWCOUNT
					END
			END

	SET @Step = 'BR_Type'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 2,
					BR_TypeID,
					BR_TypeCode,
					BR_TypeName,
					BR_TypeDescription
				FROM
					BR_Type
				ORDER BY
					BR_TypeID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'BusinessRuleEvent'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 4,
					[BusinessRuleEventID],
					[BusinessRuleID],
					[EventTypeID],
					[SortOrder],
					[SelectYN]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					([BusinessRuleEventID] = @BusinessRuleEventID OR @BusinessRuleEventID IS NULL) AND
					([BusinessRuleID] = @BusinessRuleID OR @BusinessRuleID IS NULL) AND
					([EventTypeID] = @EventTypeID OR @EventTypeID IS NULL) AND
					[DeletedID] IS NULL
				ORDER BY
					[BusinessRuleEventID],
					[SortOrder],
					[EventTypeID],
					[BusinessRuleID]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'EventType'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 8,
					[EventTypeID],
					[EventTypeName],
					[EventTypeDescription]
				FROM
					EventType
				WHERE
					[InstanceID] IN (0, @InstanceID) AND
					[SelectYN] <> 0
				ORDER BY
					EventTypeName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'BusinessRuleEvent_Parameter'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 16,
					P.[BusinessRuleEventID],
					P.[ParameterName],
					P.[ParameterValue]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent_Parameter] P
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent] B ON B.BusinessRuleEventID = P.BusinessRuleEventID AND B.DeletedID IS NULL
				WHERE
					P.[InstanceID] = @InstanceID AND
					P.[VersionID] = @VersionID AND
					(P.[BusinessRuleEventID] = @BusinessRuleEventID OR @BusinessRuleEventID IS NULL)
				ORDER BY
					P.[BusinessRuleEventID],
					P.[ParameterName]
				
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Parameter'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				SELECT DISTINCT
					[ResultTypeBM] = 32,
					[EventTypeID] = BRE.[EventTypeID],
					[Parameter] = [par].[name]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent] BRE
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRule] BR ON BR.[InstanceID] = BRE.[InstanceID] AND BR.[VersionID] = BRE.[VersionID] AND BR.[BusinessRuleID] = BRE.[BusinessRuleID] 
					INNER JOIN [BR_Type] BRT ON BRT.[InstanceID] IN (0, BR.[InstanceID]) AND BRT.[VersionID] IN (0, BR.[VersionID]) AND BRT.[BR_TypeID] = BR.[BR_TypeID]
					INNER JOIN sys.procedures [proc] ON [proc].[name] = 'spBR_' + BRT.[BR_TypeCode]
					INNER JOIN sys.parameters [par] ON [par].[object_id] = [proc].[object_id] AND [par].[name] NOT IN ('@BusinessRuleID')
					INNER JOIN [Procedure] P ON P.[ProcedureName] = [proc].[name]
					INNER JOIN [ProcedureParameter] PP ON PP.ProcedureID = P.[ProcedureID] AND '@' + PP.[Parameter] = [par].[name]
				WHERE
					BRE.[InstanceID] = @InstanceID AND
					BRE.[VersionID] = @VersionID AND
					BRE.[BusinessRuleEventID] = @BusinessRuleEventID 

				SET @Selected = @Selected + @@ROWCOUNT
			END

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
