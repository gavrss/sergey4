SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Assignment]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignmentID int = NULL OUT, --If NULL, add a new member
	@AssignmentName NVARCHAR(50) = NULL,
	@Comment NVARCHAR(255) = NULL,
	@OrganizationPositionID int = NULL,
	@DataClassID int = NULL,
	@WorkflowID int = NULL,
	@GridID int = NULL,
	@LiveFcstNextFlowID int = NULL,
	@Priority int = NULL,
	@SelectYN bit = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000112,
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
--UPDATE
EXEC [spPortalAdminSet_Assignment]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@AssignmentID = 1002,
	@AssignmentName = '01_1204 by Customer',
	@Comment = '01_1204 by Customer',
	@OrganizationPositionID = 1057,
	@DataClassID = 1001,
	@WorkflowID = 1001,
	@GridID = 1003,
	@Priority = 200,
	@SelectYN = 1

--DELETE
EXEC [spPortalAdminSet_Assignment]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@AssignmentID = 1002,
	@DeleteYN = 1

--INSERT
EXEC [spPortalAdminSet_Assignment]
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

#CBN
EXEC [spPortalAdminSet_Assignment]
	@UserID = 2147,
	@InstanceID = 413,
	@VersionID = 1008,
	@AssignmentID = 4275,
	@AssignmentName = 'Simple input form',
	@Comment = NULL,
	@OrganizationPositionID = 1136,
	@DataClassID = 1028,
	@WorkflowID = 2174,
	@GridID = 1101,
	@Priority = 100,
	@SelectYN = 1

EXEC [spPortalAdminSet_Assignment] @GetVersion = 1
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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Save changes to Assignment',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2141' SET @Description = 'Parameter @LiveFcstNextFlowID added.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data]'
		IF @Version = '2.0.2.2146' SET @Description = 'Set DeletedID to all children when the parent is set.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-176: Return ID for new Assignment.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'

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
		IF @AssignmentID IS NOT NULL AND @DeleteYN = 0
			BEGIN
				UPDATE A
				SET
					[AssignmentName] = ISNULL(@AssignmentName, A.[AssignmentName]),
					[Comment] = ISNULL(@Comment, A.[Comment]),
					[OrganizationPositionID] = ISNULL(@OrganizationPositionID, A.[OrganizationPositionID]),
					[DataClassID] = ISNULL(@DataClassID, A.[DataClassID]),
					[WorkflowID] = ISNULL(@WorkflowID, A.[WorkflowID]),
					[GridID] = ISNULL(@GridID, A.[GridID]),
					[LiveFcstNextFlowID] = COALESCE(@LiveFcstNextFlowID, A.[LiveFcstNextFlowID], 1),
					[Priority] = ISNULL(@Priority, A.[Priority]),
					[SelectYN] = ISNULL(@SelectYN, A.[SelectYN])
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment] A
				WHERE
					A.[InstanceID] = @InstanceID AND
					A.[AssignmentID] = @AssignmentID AND
					A.[VersionID] = @VersionID

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
				EXEC [dbo].[spGet_DeletedItem] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'Assignment', @DeletedID = @DeletedID OUT

				UPDATE A
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment] A
				WHERE
					A.[InstanceID] = @InstanceID AND
					A.[VersionID] = @VersionID AND
					A.[AssignmentID] = @AssignmentID

				SET @Deleted = @Deleted + @@ROWCOUNT

				UPDATE AOL
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL
				WHERE
					AOL.[InstanceID] = @InstanceID AND
					AOL.[VersionID] = @VersionID AND
					AOL.[AssignmentID] = @AssignmentID

				SET @Deleted = @Deleted + @@ROWCOUNT

				UPDATE AR
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[AssignmentRow] AR
				WHERE
					AR.[InstanceID] = @InstanceID AND
					AR.[VersionID] = @VersionID AND
					AR.[AssignmentID] = @AssignmentID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 
				ELSE
					SET @Message = 'No member is deleted.' 
				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @AssignmentID IS NULL
			BEGIN
				IF @AssignmentName IS NULL OR @OrganizationPositionID IS NULL OR @DataClassID IS NULL OR @WorkflowID IS NULL OR @Priority IS NULL OR @SelectYN IS NULL
					BEGIN
						SET @Message = 'To add a new member parameter @AssignmentName, @OrganizationPositionID, @DataClassID, @WorkflowID, @Priority AND @SelectYN must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Assignment]
					(
					[InstanceID],
					[VersionID],
					[AssignmentName],
					[Comment],
					[OrganizationPositionID],
					[DataClassID],
					[WorkflowID],
					[GridID],
					[LiveFcstNextFlowID],
					[Priority],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[AssignmentName] = @AssignmentName,
					[Comment] = @Comment,
					[OrganizationPositionID] = @OrganizationPositionID,
					[DataClassID] = @DataClassID,
					[WorkflowID] = @WorkflowID,
					[GridID] = @GridID,
					[LiveFcstNextFlowID] = ISNULL(@LiveFcstNextFlowID, 1),
					[Priority] = @Priority,
					[SelectYN] = @SelectYN

				SELECT
					@AssignmentID = @@IDENTITY,
					@Inserted = @Inserted + @@ROWCOUNT

				IF @Inserted > 0
					SET @Message = 'The new member is added.' 
				ELSE
					SET @Message = 'No member is added.' 
				SET @Severity = 0
			END

	SET @Step = 'Update Assignment_OrganizationLevel'
		EXEC spPortalAdminSet_Assignment_OrganizationLevel 	@UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @WorkflowID = @WorkflowID

	SET @Step = 'Return @AssignmentID'
		SELECT [@AssignmentID] = @AssignmentID

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
