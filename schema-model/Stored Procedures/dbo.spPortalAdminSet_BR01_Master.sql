SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_BR01_Master]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@BR_Name nvarchar(50) = NULL,
    @BR_Description nvarchar(255) = NULL,
	@Comment nvarchar(1024) = NULL,
	@DataClassID int = NULL,
	@BaseObject nvarchar(50) = NULL,
	@BeforeFxYN bit = NULL,
	@DimensionSetting nvarchar(4000) = NULL,
	@DimensionFilter nvarchar(4000) = NULL,
	@DeleteYN bit = 0,

	@JSON_table nvarchar(MAX) = NULL,

--	@BR_ID int = NULL, --Should be deleted, replaced by @BusinessRuleID

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000354,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_BR01_Master',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminSet_BR01_Master] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_BR01_Master',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "424"},
		{"TKey" : "VersionID",  "TValue": "1012"},
		{"TKey" : "BusinessRuleID",  "TValue": "1004"},
		{"TKey" : "BR_Name",  "TValue": "Test 3"},
		{"TKey" : "BR_Description",  "TValue": "Test 3"},
		{"TKey" : "Comment",  "TValue": "Test 3"},
		{"TKey" : "DataClassID",  "TValue": "4909"},
		{"TKey" : "BaseObject",  "TValue": "Account"},
		{"TKey" : "BeforeFxYN",  "TValue": "1"},
		{"TKey" : "Debug",  "TValue": "1"}
		]',
	@JSON_table = '
		[
		{"BR01_StepID": "1", "SortOrder" : "10"},
		{"BR01_StepID": "2", "SortOrder" : "20"},
		{"BR01_StepID": "3", "SortOrder" : "30"}
		]'

EXEC [spPortalAdminSet_BR01_Master] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,
	@BR_TypeID int = 1,
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
			@ProcedureDescription = 'Maintain BR01_Master',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Added DimensionFilter.'
		IF @Version = '2.1.0.2159' SET @Description = 'Added @AuthenticatedUserID parameter. Change call to sub routine from [spPortalAdminSet_BR_List] to [spPortalAdminSet_BusinessRule]. DB-540: @BusinessRuleID is stored locally before calling sub routine. Return @BusinessRuleID before calling [spPortalAdminSet_BusinessRule].'

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

	SET @Step = 'Check parameters'
		IF @DeleteYN = 0
			IF @Comment IS NULL OR @DataClassID IS NULL OR @BaseObject IS NULL OR @BeforeFxYN IS NULL
				BEGIN
					SET @Message = 'To insert a new or update an existing member parameter @Comment, @DataClassID, @BaseObject AND @BeforeFxYN must be set'
					SET @Severity = 16
					GOTO EXITPOINT
				END

	SET @Step = 'Set_BusinessRule'
		IF @BusinessRuleID IS NOT NULL
			SELECT [@BusinessRuleID] = @BusinessRuleID

		SET @Local_BusinessRuleID = @BusinessRuleID

		--EXEC [spPortalAdminSet_BR_List]
		EXEC [spPortalAdminSet_BusinessRule]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,

			@BR_TypeID = @BR_TypeID,
			@BusinessRuleID = @BusinessRuleID OUT,
			@BR_Name = @BR_Name,
			@BR_Description = @BR_Description,
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
					[BaseObject] = @BaseObject,
					[BeforeFxYN] = @BeforeFxYN,
					[DimensionSetting] = @DimensionSetting,
					[DimensionFilter] = @DimensionFilter
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Master] BRM
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
				EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'BR01_Master', @DeletedID = @DeletedID OUT

				UPDATE BRM
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Master] BRM
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
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR01_Master]
			(
			[InstanceID],
			[VersionID],
			[BusinessRuleID],
			[Comment],
			[DataClassID],
			[BaseObject],
			[BeforeFxYN],
			[DimensionSetting],
			[DimensionFilter]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[BusinessRuleID] = @BusinessRuleID,
			[Comment] = @Comment,
			[DataClassID] = @DataClassID,
			[BaseObject] = @BaseObject,
			[BeforeFxYN] = @BeforeFxYN,
			[DimensionSetting] = @DimensionSetting,
			[DimensionFilter] = @DimensionFilter
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR01_Master] BM WHERE BM.BusinessRuleID = @BusinessRuleID)

		SELECT
			@Inserted = @Inserted + @@ROWCOUNT

		IF @Inserted > 0
			SET @Message = 'The new member is added.' 
		ELSE
			SET @Message = 'No member is added.' 
		SET @Severity = 0

	SET @Step = 'Set SortOrder'
		IF @JSON_table IS NOT NULL	
			BEGIN
				CREATE TABLE #BR01_Step_SortOrder
					(
					[BR01_StepID] int,
					[SortOrder] int
					)	

				INSERT INTO #BR01_Step_SortOrder
					(
					[BR01_StepID],
					[SortOrder]
					)
				SELECT
					[BR01_StepID],
					[SortOrder]
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[BR01_StepID] int,
					[SortOrder] int
					)

				UPDATE BSSO
				SET
					SortOrder = J.SortOrder
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Step_SortOrder] BSSO
					INNER JOIN #BR01_Step_SortOrder J ON J.[BR01_StepID] = BSSO.[BR01_StepID]
				WHERE
					BSSO.[InstanceID] = @InstanceID AND
					BSSO.[VersionID] = @VersionID AND
					BSSO.[BusinessRuleID] = @BusinessRuleID

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR01_Step_SortOrder]
					(
					[InstanceID],
					[VersionID],
					[BusinessRuleID],
					[BR01_StepID],
					[SortOrder]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[BusinessRuleID] = @BusinessRuleID,
					[BR01_StepID],
					[SortOrder]
				FROM
					#BR01_Step_SortOrder J
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR01_Step_SortOrder] BSSO WHERE BSSO.[InstanceID] = @InstanceID AND BSSO.[VersionID] = @VersionID AND BSSO.[BusinessRuleID] = @BusinessRuleID AND BSSO.[BR01_StepID] = J.[BR01_StepID])

				DROP TABLE #BR01_Step_SortOrder
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
