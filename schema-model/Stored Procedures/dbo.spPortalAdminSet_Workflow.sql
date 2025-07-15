SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Workflow]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowID int = NULL OUT, --If NULL, add a new member
	@WorkflowName NVARCHAR(50) = NULL,
	@ProcessID INT = NULL,
	@ScenarioID INT = NULL,
	@CompareScenarioID INT = NULL,
	@TimeFrom INT = NULL,
	@TimeTo INT = NULL,
	@TimeOffsetFrom INT = NULL,
	@TimeOffsetTo INT = NULL,
	@InitialWorkflowStateID INT = NULL,
	@RefreshActualsInitialWorkflowStateID INT = NULL,
	@ModelingStatusID INT = NULL,
	@ModelingComment NVARCHAR(1024) = NULL,
	@SelectYN bit = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000128,
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
EXEC [spPortalAdminSet_Workflow]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@WorkflowID = 1001,
	@WorkflowName = 'Forecast1',
	@ProcessID = 1001,
	@ScenarioID = 1007,
	@CompareScenarioID = 1001,
	@TimeFrom = 201701,
	@TimeTo = 201712,
	@TimeOffsetFrom = NULL,
	@TimeOffsetTo = NULL,
	@InitialWorkflowStateID = 1002,
	@RefreshActualsInitialWorkflowStateID = 1017,
	@ModelingStatusID = -40,
	@ModelingComment = NULL,
	@SelectYN = 1

--DELETE
EXEC [spPortalAdminSet_Workflow]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@WorkflowID = 1001,
	@DeleteYN = 1

--INSERT
EXEC [spPortalAdminSet_Workflow]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@WorkflowID = NULL,
	@WorkflowName = 'Forecast3',
	@ProcessID = 1001,
	@ScenarioID = 1007,
	@CompareScenarioID = 1001,
	@TimeFrom = 201701,
	@TimeTo = 201712,
	@TimeOffsetFrom = NULL,
	@TimeOffsetTo = NULL,
	@InitialWorkflowStateID = 1002,
	@RefreshActualsInitialWorkflowStateID = 1017,
	@ModelingStatusID = -40,
	@ModelingComment = NULL,
	@SelectYN = 1

EXEC [spPortalAdminSet_Workflow] @GetVersion = 1
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
			@ProcedureDescription = 'Set_Workflow',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-299: Handle VersionID.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'
		IF @Version = '2.1.1.2171' SET @Description = 'Removed some mandatory parameters.'

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
		IF @WorkflowID IS NOT NULL AND @DeleteYN = 0
			BEGIN
				IF @WorkflowName IS NULL OR @ProcessID IS NULL OR @ModelingStatusID IS NULL OR @SelectYN IS NULL

					BEGIN
						SET @Message = 'To update an existing member parameter @WorkflowName, @ProcessID, @ModelingStatusID AND @SelectYN must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				UPDATE WF
				SET
					[WorkflowName] = @WorkflowName,
					[ProcessID] = @ProcessID,
					[ScenarioID] = @ScenarioID,
					[CompareScenarioID] = @CompareScenarioID,
					[TimeFrom] = @TimeFrom,
					[TimeTo] = @TimeTo,
					[TimeOffsetFrom] = @TimeOffsetFrom,
					[TimeOffsetTo] = @TimeOffsetTo,
					[InitialWorkflowStateID] = ISNULL(@InitialWorkflowStateID, WF.[InitialWorkflowStateID]),
					[RefreshActualsInitialWorkflowStateID] = ISNULL(@RefreshActualsInitialWorkflowStateID, WF.[RefreshActualsInitialWorkflowStateID]),
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[SelectYN] = @SelectYN
				FROM
					[pcINTEGRATOR_Data].[dbo].[Workflow] WF
				WHERE
					WF.[InstanceID] = @InstanceID AND
					WF.[VersionID] = @VersionID AND
					WF.[WorkflowID] = @WorkflowID

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
				EXEC [dbo].[spGet_DeletedItem] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'Workflow', @DeletedID = @DeletedID OUT

				UPDATE WF
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[Workflow] WF
				WHERE
					WF.[InstanceID] = @InstanceID AND
					WF.[VersionID] = @VersionID AND
					WF.[WorkflowID] = @WorkflowID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 
				ELSE
					SET @Message = 'No member is deleted.' 
				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @WorkflowID IS NULL
			BEGIN
				IF @WorkflowName IS NULL OR @ProcessID IS NULL OR @InitialWorkflowStateID IS NULL OR @RefreshActualsInitialWorkflowStateID IS NULL OR @ModelingStatusID IS NULL OR @SelectYN IS NULL
					BEGIN
						SET @Message = 'To add a new member parameter @WorkflowName, @ProcessID, @InitialWorkflowStateID, @RefreshActualsInitialWorkflowStateID, @ModelingStatusID AND @SelectYN must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow]
					(
					[InstanceID],
					[VersionID],
					[WorkflowName],
					[ProcessID],
					[ScenarioID],
					[CompareScenarioID],
					[TimeFrom],
					[TimeTo],
					[TimeOffsetFrom],
					[TimeOffsetTo],
					[InitialWorkflowStateID],
					[RefreshActualsInitialWorkflowStateID],
					[ModelingStatusID],
					[ModelingComment],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[WorkflowName] = @WorkflowName,
					[ProcessID] = @ProcessID,
					[ScenarioID] = @ScenarioID,
					[CompareScenarioID] = @CompareScenarioID,
					[TimeFrom] = @TimeFrom,
					[TimeTo] = @TimeTo,
					[TimeOffsetFrom] = @TimeOffsetFrom,
					[TimeOffsetTo] = @TimeOffsetTo,
					[InitialWorkflowStateID] = @InitialWorkflowStateID,
					[RefreshActualsInitialWorkflowStateID] = @RefreshActualsInitialWorkflowStateID,
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[SelectYN] = @SelectYN

				SELECT
					@WorkflowID = @@IDENTITY,
					@Inserted = @Inserted + @@ROWCOUNT

				IF @Inserted > 0
					SET @Message = 'The new member is added.' 
				ELSE
					SET @Message = 'No member is added.' 
				SET @Severity = 0
			END

	SET @Step = 'Return value'
		SELECT WorkflowID = @WorkflowID	
		RAISERROR (@Message, @Severity, 100)		
		RETURN @WorkflowID

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
