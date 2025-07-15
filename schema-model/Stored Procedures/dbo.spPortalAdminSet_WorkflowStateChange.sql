SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_WorkflowStateChange]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowID int = NULL,
	@OrganizationHierarchyID int = NULL,
	@OrganizationLevelNo int = NULL,
	@FromWorkflowStateID int = NULL,
	@ToWorkflowStateID int = NULL,
	@UserChangeableYN bit = NULL,
	@BRChangeableYN bit = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000134,
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
EXEC [spPortalAdminGet_Workflow] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @WorkflowID = 1001, @OrganizationHierarchyID = 1002, @ResultTypeBM = 32

--UPDATE
EXEC [spPortalAdminSet_WorkflowStateChange]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@WorkflowID = 1002,
	@OrganizationHierarchyID = 1002,
	@OrganizationLevelNo = 4,
	@FromWorkflowStateID = 1001,
	@ToWorkflowStateID = 1002,
	@UserChangeableYN = 1,
	@BRChangeableYN = 0

--INSERT
EXEC [spPortalAdminSet_WorkflowStateChange]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@WorkflowID = 1002,
	@OrganizationHierarchyID = 1002,
	@OrganizationLevelNo = 4,
	@FromWorkflowStateID = 1001,
	@ToWorkflowStateID = 1002,
	@UserChangeableYN = 1,
	@BRChangeableYN = 0

EXEC [spPortalAdminSet_WorkflowStateChange] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE

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
	@Version nvarchar(50) = '2.0.3.2152'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set WorkflowStateChange',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-299: Handle VersionID.'

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
		UPDATE WFSC
		SET
			[UserChangeableYN] = @UserChangeableYN,
			[BRChangeableYN] = @BRChangeableYN
		FROM
			[pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WFSC
		WHERE
			WFSC.[InstanceID] = @InstanceID AND
			WFSC.[VersionID] = @VersionID AND
			WFSC.[WorkflowID] = @WorkflowID AND
			WFSC.[OrganizationHierarchyID] = @OrganizationHierarchyID AND
			WFSC.[OrganizationLevelNo] = @OrganizationLevelNo AND
			WFSC.[FromWorkflowStateID] = @FromWorkflowStateID AND
			WFSC.[ToWorkflowStateID] = @ToWorkflowStateID 

		SET @Updated = @Updated + @@ROWCOUNT

		IF @Updated > 0
			SET @Message = 'The member is updated.' 
		ELSE
			SET @Message = 'No member is updated.' 
		SET @Severity = 0

	SET @Step = 'Insert new member'
		IF @Updated = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange]
					(
					[InstanceID],
					[VersionID],
					[WorkflowID],
					[OrganizationHierarchyID],
					[OrganizationLevelNo],
					[FromWorkflowStateID],
					[ToWorkflowStateID],
					[UserChangeableYN],
					[BRChangeableYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[WorkflowID] = @WorkflowID,
					[OrganizationHierarchyID] = @OrganizationHierarchyID,
					[OrganizationLevelNo] = @OrganizationLevelNo,
					[FromWorkflowStateID] = @FromWorkflowStateID,
					[ToWorkflowStateID] = @ToWorkflowStateID,
					[UserChangeableYN] = @UserChangeableYN,
					[BRChangeableYN] = @BRChangeableYN

				SET @Inserted = @Inserted + @@ROWCOUNT

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
