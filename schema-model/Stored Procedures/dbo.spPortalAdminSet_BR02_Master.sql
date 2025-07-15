SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_BR02_Master]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@BR_Name nvarchar(50) = NULL,
    @BR_Description nvarchar(255) = NULL,
	@Comment nvarchar(1024) = NULL,
	@StoredProcedure nvarchar(100) = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000443,
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
EXEC [spRun_Procedure_KeyValuePair]
@ProcedureName='spPortalAdminSet_BR02_Master',
@JSON='[
	{"TKey":"Comment","TValue":"Precalc"},
	{"TKey":"InstanceID","TValue":"424"},
	{"TKey":"BR_Name","TValue":"Addback precalc (deleted at 2019-08-12 15:28:32)"},
	{"TKey":"StoredProcedure","TValue":"[pcETL_HD].[dbo].[spBR02_ST_AB_Denovo_Loss]"},
	{"TKey":"DeleteYN","TValue":"1"},
	{"TKey":"UserID","TValue":"3691"},
	{"TKey":"VersionID","TValue":"1017"},
	{"TKey":"BR_Description","TValue":"Addback precalc"},
	{"TKey":"Debug","TValue":"1"}
	]'

EXEC [spPortalAdminSet_BR02_Master] @UserID=-10, @InstanceID=424, @VersionID=1017, @BR_Name='Test1', @BR_Description='Test1', @Comment='Test1', @StoredProcedure='pcETL_HD.dbo.spTest', @Debug=1

EXEC [spPortalAdminSet_BR02_Master] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,
	@BR_TypeID int = 2,

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
	@Version nvarchar(50) = '2.0.2.2145'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain BR02_Master',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'

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

	SET @Step = 'Check parameters'
		IF @DeleteYN = 0
			IF @BR_Name IS NULL OR @BR_Description IS NULL OR @Comment IS NULL
				BEGIN
					SET @Message = 'To insert a new or update an existing member parameter @BR_Name, @BR_Description AND @Comment must be set'
					SET @Severity = 16
					GOTO EXITPOINT
				END

	SET @Step = 'Set_BusinessRule'
		EXEC [spPortalAdminSet_BR_List]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,

			@BR_TypeID = @BR_TypeID,
			@BusinessRuleID = @BusinessRuleID OUT,
			@BR_Name = @BR_Name,
			@BR_Description = @BR_Description,
			@DeleteYN = @DeleteYN,
			@Debug = @Debug

		IF @Debug <> 0 SELECT [@BusinessRuleID] = @BusinessRuleID

	SET @Step = 'Update existing member'
		IF @DeleteYN = 0
			BEGIN
				UPDATE BRM
				SET
					[Comment] = @Comment,
					[StoredProcedure] = @StoredProcedure
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR02_Master] BRM
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
				EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'BR02_Master', @DeletedID = @DeletedID OUT

				UPDATE BRM
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR02_Master] BRM
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
		IF @DeleteYN = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR02_Master]
					(
					[InstanceID],
					[VersionID],
					[BusinessRuleID],
					[Comment],
					[StoredProcedure]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[BusinessRuleID] = @BusinessRuleID,
					[Comment] = @Comment,
					[StoredProcedure] = @StoredProcedure
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR02_Master] BM WHERE BM.BusinessRuleID = @BusinessRuleID)

				SELECT
					@Inserted = @Inserted + @@ROWCOUNT

				IF @Inserted > 0
					SET @Message = 'The new member is added.' 
				ELSE
					SET @Message = 'No member is added.' 
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
