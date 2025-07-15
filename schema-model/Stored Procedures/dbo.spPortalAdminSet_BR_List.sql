SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_BR_List]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL OUT,
    @BR_TypeID int = NULL,
    @BR_Name nvarchar(50) = NULL,
    @BR_Description nvarchar(255) = NULL,
	@SortOrder int = NULL,
	@DeleteYN bit = 0,

--  @BR_ID int = NULL OUT, --Should be deleted, replaced by @BusinessRuleID

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000353,
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
--**********************************************
--**********************************************
OBS! Replaced by [spPortalAdminSet_BusinessRule]
--**********************************************
--**********************************************

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_BR_List',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminSet_BR_List] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spPortalAdminSet_BR_List] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,

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
	@Version nvarchar(50) = '2.0.3.2151'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain table BusinessRule',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Changed parameter @BR_ID to @BusinessRuleID.'
		IF @Version = '2.0.3.2151' SET @Description = 'Added @SortOrder.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
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

--		SET @BusinessRuleID = ISNULL(@BusinessRuleID, @BR_ID)

	SET @Step = 'Check parameters'
		IF @DeleteYN = 0
			IF @BR_Name IS NULL OR @BR_Description IS NULL
				BEGIN
					SET @Message = 'To insert a new or update an existing member parameter @BR_Name AND @BR_Description must be set'
					SET @Severity = 16
					GOTO EXITPOINT
				END

	SET @Step = 'Update existing member'
		IF @BusinessRuleID IS NOT NULL AND @DeleteYN = 0
			BEGIN
				UPDATE BRL
				SET
					[BR_TypeID] = @BR_TypeID,
					[BR_Name] = @BR_Name,
					[BR_Description] = @BR_Description,
					[SortOrder] = ISNULL(@SortOrder, BRL.SortOrder) 
				FROM
					[pcINTEGRATOR_Data].[dbo].[BusinessRule] BRL
				WHERE
					BRL.[InstanceID] = @InstanceID AND
					BRL.[VersionID] = @VersionID AND
					BRL.[BusinessRuleID] = @BusinessRuleID

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
				EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'BusinessRule', @DeletedID = @DeletedID OUT

				UPDATE BRL
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[BusinessRule] BRL
				WHERE
					BRL.[InstanceID] = @InstanceID AND
					BRL.[VersionID] = @VersionID AND
					BRL.[BusinessRuleID] = @BusinessRuleID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 
				ELSE
					SET @Message = 'No member is deleted.' 
				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @BusinessRuleID IS NULL AND @DeleteYN = 0
			BEGIN	
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BusinessRule]
					(
					[InstanceID],
					[VersionID],
					[BR_TypeID],
					[BR_Name],
					[BR_Description],
					[SortOrder] 
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[BR_TypeID] = @BR_TypeID,
					[BR_Name] = @BR_Name,
					[BR_Description] = @BR_Description,
					[SortOrder] = ISNULL(@SortOrder, 0) 
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BusinessRule] D WHERE D.[InstanceID] = @InstanceID AND D.[VersionID] = @VersionID AND D.[BR_TypeID] = @BR_TypeID AND D.[BR_Name] = @BR_Name)

				SELECT
					@Inserted = @Inserted + @@ROWCOUNT

				IF @Inserted > 0
					SELECT
						@Message = 'The new member is added.',
						@BusinessRuleID = @@IDENTITY
				ELSE
					BEGIN
						SET @Message = 'No member is added.'
						SELECT @BusinessRuleID = ISNULL(@BusinessRuleID, BusinessRuleID) FROM [pcINTEGRATOR_Data].[dbo].[BusinessRule] D WHERE D.[InstanceID] = @InstanceID AND D.[VersionID] = @VersionID AND D.[BR_TypeID] = @BR_TypeID AND D.[BR_Name] = @BR_Name
					END

				SET @Severity = 0
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
