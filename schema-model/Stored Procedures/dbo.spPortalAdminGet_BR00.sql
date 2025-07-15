SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_BR00]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@ResultTypeBM int = 15, --1 = BR00_Step, 2 = Sub business rules, 4 = BR00_Parameter, 8 = Parameter
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000600,
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
EXEC [spPortalAdminGet_BR00] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID = 5065, @Debug=1
EXEC [spPortalAdminGet_BR00] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID = 7085, @ResultTypeBM = 8

EXEC [spPortalAdminGet_BR00] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(max),
	@Database nvarchar(100),
	@Parameter nvarchar(4000),
	@StoredProcedureName nvarchar(100),

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2155'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get parameter data for BR00, group of business rules',
			@MandatoryParameter = 'BusinessRuleID' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Added BR_TypeID and BR_TypeName in @ResultTypeBM = 2 resultset. DB-484 Added [DisplayName] and [DataType] in @ResultTypeBM = 8 resultset.'

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

	SET @Step = 'BR00_Step'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 1,
					[Comment],
					[BusinessRuleID],
					[BR00_StepID],
					[BusinessRule_SubID],
					[SortOrder],
					[SelectYN]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR00_Step]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[BusinessRuleID] = @BusinessRuleID
				ORDER BY
					[BusinessRuleID],
					[SortOrder],
					[BR00_StepID]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'BR00 available sub business rules'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 2,
					[BusinessRule_SubID] = BR.[BusinessRuleID],
					BR.[BR_Name],
					BR.[BR_Description],
					BR.[BR_TypeID],
					BRT.[BR_TypeName]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BusinessRule] BR
					INNER JOIN [pcINTEGRATOR].[dbo].[BR_Type] BRT ON BRT.BR_TypeID = BR.BR_TypeID
				WHERE
					BR.[InstanceID] = @InstanceID AND
					BR.[VersionID] = @VersionID AND
					BR.[BR_TypeID] <> 0 AND
					BR.[SelectYN] <> 0 AND
					BR.[DeletedID] IS NULL
	
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'BR00_Parameter'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					[BusinessRuleID],
					[ParameterName],
					[ParameterValue]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR00_Parameter]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					([BusinessRuleID] = @BusinessRuleID OR @BusinessRuleID IS NULL)
				ORDER BY
					[BusinessRuleID],
					[ParameterName]
				
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Parameter'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT DISTINCT
					[ResultTypeBM] = 8,
					[Parameter] = [par].[name],
					[DisplayName] = REPLACE([par].[name], '@', ''),
					[DataType] = MAX(ISNULL(DT.DataTypePortal, [type].[name])),
					[GuiObject] = MAX(ISNULL(DT.GuiObject, 'TextBox'))
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR00_Step] BRS
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRule] BR ON BR.[InstanceID] = BRS.[InstanceID] AND BR.[VersionID] = BRS.[VersionID] AND BR.[BusinessRuleID] = BRS.[BusinessRule_SubID] 
					INNER JOIN [BR_Type] BRT ON BRT.[InstanceID] IN (0, BR.[InstanceID]) AND BRT.[VersionID] IN (0, BR.[VersionID]) AND BRT.[BR_TypeID] = BR.[BR_TypeID]
					INNER JOIN sys.procedures [proc] ON [proc].[name] = 'spBR_' + BRT.[BR_TypeCode]
					INNER JOIN sys.parameters [par] ON [par].[object_id] = [proc].[object_id] AND [par].[name] NOT IN ('@BusinessRuleID')
					INNER JOIN sys.types [type] ON [type].user_type_id = [par].user_type_id
					LEFT JOIN [@Template_DataType] DT ON DT.DataTypeCode = [type].[name]
					INNER JOIN [Procedure] P ON P.[ProcedureName] = [proc].[name]
					INNER JOIN [ProcedureParameter] PP ON PP.ProcedureID = P.[ProcedureID] AND '@' + PP.[Parameter] = [par].[name]
				WHERE
					BRS.[InstanceID] = @InstanceID AND
					BRS.[VersionID] = @VersionID AND
					BRS.[BusinessRuleID] = @BusinessRuleID
				GROUP BY
					[par].[name]

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
