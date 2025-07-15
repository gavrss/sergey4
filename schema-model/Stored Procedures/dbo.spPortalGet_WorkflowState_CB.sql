SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_WorkflowState_CB]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000300,
	@Parameter nvarchar(4000) = NULL,
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
	@ProcedureName = 'spPortalGet_WorkflowState_CB',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "304"},
		{"TKey" : "VersionID",  "TValue": "1001"},
		{"TKey" : "WorkflowID",  "TValue": "1002"}
		]'

EXEC [spPortalGet_WorkflowState_CB] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @WorkflowID = 1002
EXEC spPortalGet_WorkflowState_CB @InstanceID='515',@UserID='9632',@VersionID='1040',@WorkflowID='14940'

EXEC [spPortalGet_WorkflowState_CB] @GetVersion = 1
*/

DECLARE
	@TemplateWorkflowID int,

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
			@ProcedureDescription = 'Return rows for combobox WorkflowState.',
			@MandatoryParameter = 'WorkflowID'

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2171' SET @Description = 'Add WorkflowState if missing.'

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
		--EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT

	IF(SELECT COUNT(1) FROM pcINTEGRATOR_Data..[WorkflowState] WS WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [WorkflowID] = @WorkflowID) = 0
		BEGIN
			SELECT 
				@TemplateWorkflowID = CASE WHEN ST.ScenarioTypeID = -5 THEN -130 ELSE -120 END
			FROM
				Workflow WF
				INNER JOIN Scenario S ON S.ScenarioID = WF.ScenarioID
				INNER JOIN ScenarioType ST ON ST.ScenarioTypeID = S.ScenarioTypeID
			WHERE
				WF.InstanceID = @InstanceID AND
				WF.VersionID = @VersionID AND
				WF.WorkflowID = @WorkflowID

			INSERT INTO pcINTEGRATOR_Data..[WorkflowState]
				(
				[InstanceID],
				[VersionID],
				[WorkflowID],
				[WorkflowStateName],
				[InheritedFrom]
				)
			SELECT
				[InstanceID] = @InstanceID,
				[VersionID] = @VersionID,
				[WorkflowID] = @WorkflowID,
				[WorkflowStateName],
				[InheritedFrom] = [WorkflowStateID]
			FROM
				pcINTEGRATOR..[@Template_WorkflowState]
			WHERE
				[InstanceID] = -10 AND
				[VersionID] = -10 AND
				[WorkflowID] = @TemplateWorkflowID

			SET @Inserted = @Inserted + @@ROWCOUNT
		END

	SET @Step = 'Return rows'
		SELECT
			[WorkflowStateId] = WS.[WorkflowStateId],
			[WorkflowStateName] = WS.[WorkflowStateName],
			[WorkflowStateDescription] = WS.[WorkflowStateName]
		FROM
			[WorkflowState] WS
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[WorkflowID] = @WorkflowID 
		ORDER BY
			WS.[WorkflowStateId]

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @Parameter = @Parameter, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @Parameter = @Parameter, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
