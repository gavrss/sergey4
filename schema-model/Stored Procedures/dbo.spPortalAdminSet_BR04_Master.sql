SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_BR04_Master]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@BR_Name nvarchar(50) = NULL,
    @BR_Description nvarchar(255) = NULL,
	@Comment nvarchar(1024) = NULL,
	@DataClassID int = NULL,
	@Filter nvarchar(max) = NULL,
	@MultiplyYN bit = 1,
	@BaseCurrency int = NULL,
	@Parameter nvarchar(4000) = NULL,
	@DimensionFilter nvarchar(4000) = NULL,
	@SelectYN bit = 1,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000620,
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
EXEC [spPortalAdminSet_BR04_Master] @DataClassID='7736', @UserID='-10', @InstanceID='454', @VersionID='1021', @BR_Name = 'Fx Fin', @BR_Description = 'Fx Financials', @Comment = 'Fx Financials', @MultiplyYN=1, @DimensionFilter = 'Entity=C700|Scenario=ACTUAL|Time=202001'

EXEC [spPortalAdminSet_BR04_Master] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,
	@BR_TypeID int = 4,
	@Local_BusinessRuleID int,

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
			@ProcedureDescription = 'Maintain BR04_Master',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2157' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2159' SET @Description = 'DB-530: @BusinessRuleID is stored locally before calling sub routine. DB-541: Return @BusinessRuleID before calling [spPortalAdminSet_BusinessRule].'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Set_BusinessRule'
		IF @BusinessRuleID IS NOT NULL
			SELECT [@BusinessRuleID] = @BusinessRuleID

		SET @Local_BusinessRuleID = @BusinessRuleID

		EXEC [spPortalAdminSet_BusinessRule]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,

			@ResultTypeBM = 1,
			@BR_TypeID = @BR_TypeID,
			@BusinessRuleID = @BusinessRuleID OUT,
			@BR_Name = @BR_Name,
			@BR_Description = @BR_Description,
			@SelectYN = @SelectYN,
			@DeleteYN = @DeleteYN,
			@Debug = @DebugSub

		SET @BusinessRuleID = ISNULL(@BusinessRuleID, @Local_BusinessRuleID)
		
		IF @Debug <> 0 SELECT [@BusinessRuleID] = @BusinessRuleID

	SET @Step = 'Update existing member'
		IF @DeleteYN = 0
			BEGIN
				UPDATE BRM
				SET
					[Comment] = @Comment,
					[DataClassID] = @DataClassID,
					[DimensionFilter] = @DimensionFilter,
					[MultiplyYN] = @MultiplyYN,
					[BaseCurrency] = @BaseCurrency,
					[Parameter] = @Parameter
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR04_Master] BRM
				WHERE
					BRM.[InstanceID] = @InstanceID AND
					BRM.[VersionID] = @VersionID AND
					BRM.[BusinessRuleID] = @BusinessRuleID

				SET @Updated = @Updated + @@ROWCOUNT

				IF @Updated > 0
					SET @Message = 'The member is updated.' 
				ELSE
					SET @Message = 'No member is updated.' 
				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'BR04_Master', @DeletedID = @DeletedID OUT

				UPDATE BRM
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR04_Master] BRM
				WHERE
					BRM.[InstanceID] = @InstanceID AND
					BRM.[VersionID] = @VersionID AND
					BRM.[BusinessRuleID] = @BusinessRuleID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 
				ELSE
					SET @Message = 'No member is deleted.' 
				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR04_Master]
			(
			[InstanceID],
			[VersionID],
			[BusinessRuleID],
			[Comment],
			[DataClassID],
			[DimensionFilter],
			[MultiplyYN],
			[BaseCurrency],
			[Parameter]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[BusinessRuleID] = @BusinessRuleID,
			[Comment] = @Comment,
			[DataClassID] = @DataClassID,
			[DimensionFilter] = @DimensionFilter,
			[MultiplyYN] = @MultiplyYN,
			[BaseCurrency] = @BaseCurrency,
			[Parameter] = @Parameter
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR04_Master] BM WHERE BM.BusinessRuleID = @BusinessRuleID)

		SELECT
			@Inserted = @Inserted + @@ROWCOUNT

		IF @Inserted > 0
			SET @Message = 'The new member is added.'
		ELSE
			SET @Message = 'No member is added.' 
		SET @Severity = 0

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
