SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_AssignmentLevel]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignmentID int = NULL OUT,
	@OrganizationLevelNo int = NULL,
	@LevelInWorkflowYN bit = NULL,
	@ExpectedDate date = NULL,
	@ActionDescription nvarchar(50) = NULL,
	@GridID int = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000115,
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
	@ProcedureName = 'spPortalAdminSet_AssignmentLevel',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

--UPDATE
EXEC [spPortalAdminSet_AssignmentLevel]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@AssignmentID = 1002,
	@OrganizationLevelNo = 1,
	@LevelInWorkflowYN = 0,
	@ExpectedDate = '2017-12-13',
	@ActionDescription = 'Test',
	@GridID = 1003

--DELETE
EXEC [spPortalAdminSet_AssignmentLevel]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@AssignmentID = 1002,
	@DeleteYN = 1

--INSERT
EXEC [spPortalAdminSet_AssignmentLevel]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@AssignmentID = NULL,
	@AssignmentName = 'Test2',
	@Comment = 'Test2',
	@OrganizationPositionID = 1057,
	@DataClassID = 1001,
	@WorkflowID = 1001,
	@GridID = 1003,
	@Priority = 200,
	@SelectYN = 1

EXEC [spPortalAdminSet_AssignmentLevel] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@OrganizationPositionID int,
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
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Template for creating SPs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'

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

		SELECT 
			@OrganizationPositionID = OrganizationPositionID
		FROM
			[pcINTEGRATOR_Data].[dbo].[Assignment]
		WHERE
			AssignmentID = @AssignmentID

	SET @Step = 'Update existing member'
		IF @DeleteYN = 0
			BEGIN
				IF @AssignmentID IS NULL OR @OrganizationLevelNo IS NULL
					BEGIN
						SET @Message = 'To update an existing member parameter @AssignmentID and @OrganizationLevelNo must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				UPDATE AOL
				SET
					OrganizationPositionID = @OrganizationPositionID,
					LevelInWorkflowYN = @LevelInWorkflowYN,
					ExpectedDate = @ExpectedDate,
					ActionDescription = @ActionDescription,
					GridID = @GridID
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL
				WHERE
					AOL.[InstanceID] = @InstanceID AND
					AOL.[AssignmentID] = @AssignmentID AND
					AOL.OrganizationLevelNo = @OrganizationLevelNo

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
				DELETE
					AOL
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL
				WHERE
					AOL.[InstanceID] = @InstanceID AND
					AOL.[AssignmentID] = @AssignmentID AND
					AOL.OrganizationLevelNo = @OrganizationLevelNo

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 
				ELSE
					SET @Message = 'No member is deleted.' 
				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @Updated = 0
			BEGIN
				IF @AssignmentID IS NULL OR @OrganizationLevelNo IS NULL
					BEGIN
						SET @Message = 'To add a new member parameter @AssignmentID and @OrganizationLevelNo must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel]
					(
					[InstanceID],
					[AssignmentID],
					[OrganizationLevelNo],
					[OrganizationPositionID],
					[LevelInWorkflowYN],
					[ExpectedDate],
					[ActionDescription],
					[GridID]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[AssignmentID] = @AssignmentID,
					[OrganizationLevelNo] = @OrganizationLevelNo,
					[OrganizationPositionID] = @OrganizationPositionID,
					[LevelInWorkflowYN] = @LevelInWorkflowYN,
					[ExpectedDate] = @ExpectedDate,
					[ActionDescription] = @ActionDescription,
					[GridID] = @GridID

				SELECT
					@AssignmentID = @@IDENTITY,
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
