SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_OrganizationPosition_User]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@OrganizationPositionID int = NULL, 
	@OrganizationPositionUserID int = NULL,
	@Comment nvarchar(100) = NULL,
	@DelegateYN bit = 1,
	@DateFrom date = NULL,
	@DateTo date = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000119,
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
--UPDATE / INSERT
EXEC [spPortalAdminSet_OrganizationPosition_User]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationPositionID = 1001,
	@OrganizationPositionUserID = -10,
	@Comment = 'Test'

--DELETE
EXEC [spPortalAdminSet_OrganizationPosition_User]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationPositionID = 1001,
	@OrganizationPositionUserID = -10,
	@DeleteYN = 1

EXEC [spPortalAdminSet_OrganizationPosition_User] @GetVersion = 1
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
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set OrganizationPosition_User',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2144' SET @Description = 'Fixed bug when adding new rows, added InstanceID and VersionID.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added new parameters; @DelegateYN, @DateFrom and @DateTo..'

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

	SET @Step = 'Update existing member'
		IF @DeleteYN = 0
			BEGIN
				UPDATE OPU
				SET
					[Comment] = @Comment,
					[DelegateYN] = @DelegateYN,
					[DateFrom] = @DateFrom,
					[DateTo] = @DateTo
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU
				WHERE
					OPU.OrganizationPositionID = @OrganizationPositionID AND
					OPU.UserID = @OrganizationPositionUserID

				SET @Updated = @Updated + @@ROWCOUNT

				IF @Updated > 0
					SET @Message = 'The member is updated.' 

				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				DELETE OPU
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU
				WHERE
					OPU.OrganizationPositionID = @OrganizationPositionID AND
					OPU.UserID = @OrganizationPositionUserID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 

				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @DeleteYN = 0 AND @Updated = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User]
					(
					InstanceID,
					VersionID,
					Comment,
					OrganizationPositionID,
					UserID,
					[DelegateYN],
					[DateFrom],
					[DateTo]
					)
				SELECT
					InstanceID = @InstanceID,
					VersionID = @VersionID,
					Comment = @Comment,
					OrganizationPositionID = @OrganizationPositionID,
					UserID = @OrganizationPositionUserID,
					[DelegateYN] = @DelegateYN,
					[DateFrom] = @DateFrom,
					[DateTo] = @DateTo
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU WHERE OPU.OrganizationPositionID = @OrganizationPositionID AND OPU.UserID = @OrganizationPositionUserID)

				SET @Inserted = @Inserted + @@ROWCOUNT

				IF @Inserted > 0
					SET @Message = 'The new member is added.' 

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
