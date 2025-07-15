SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_LiveFcstNext]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowID int = NULL, 
	@AutoSaveOnCloseYN bit = NULL,
	@LiveFcstNext_ClosedMonth int = NULL,
	@LiveFcstNext_TimeFrom int = NULL,
	@LiveFcstNext_TimeTo int = NULL,
	@WorkflowStateID_Free int = NULL,
	@WorkflowStateID_Structured int = NULL,
	@WorkflowStateID_Closed int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000330,
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
	@ProcedureName = 'spPortalAdminSet_LiveFcstNext',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminSet_LiveFcstNext] @UserID=-10, @InstanceID=-1158, @VersionID=-1096, @WorkflowID = 1124, @Debug=1

EXEC [spPortalAdminSet_LiveFcstNext] @GetVersion = 1
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
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Change settings for LiveFcstNext',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2141' SET @Description = 'Procedure created.'
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

	SET @Step = 'Change settings in Scenario'
		UPDATE S
		SET
			AutoSaveOnCloseYN = ISNULL(@AutoSaveOnCloseYN, S.AutoSaveOnCloseYN)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Scenario] S
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] WF ON WF.InstanceID = S.InstanceID AND WF.VersionID = S.VersionID AND WF.ScenarioID = S.ScenarioID AND WF.WorkflowID = @WorkflowID
		WHERE
			S.InstanceID = @InstanceID AND
			S.VersionID = @VersionID AND
			S.ScenarioTypeID = -3 AND
			S.[SelectYN] <> 0 AND
			S.[DeletedID] IS NULL

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Change settings in Workflow'
		UPDATE WF
		SET
			LiveFcstNext_ClosedMonth = ISNULL(@LiveFcstNext_ClosedMonth, WF.LiveFcstNext_ClosedMonth),
			LiveFcstNext_TimeFrom = ISNULL(@LiveFcstNext_TimeFrom, WF.LiveFcstNext_TimeFrom),
			LiveFcstNext_TimeTo = ISNULL(@LiveFcstNext_TimeTo, WF.LiveFcstNext_TimeTo)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow] WF
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID AND
			WF.WorkflowID = @WorkflowID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Change settings in Workflow_LiveFcstNextFlow'
		--Free
		UPDATE LFNF
		SET
			WorkflowStateID = ISNULL(@WorkflowStateID_Free, LFNF.WorkflowStateID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow] LFNF
		WHERE
			LFNF.InstanceID = @InstanceID AND
			LFNF.WorkflowID = @WorkflowID AND
			LFNF.LiveFcstNextFlowID = 1

		SET @Updated = @Updated + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow]
			(
			InstanceID,
			WorkflowID,
			LiveFcstNextFlowID,
			WorkflowStateID
			)
		SELECT
			InstanceID = @InstanceID,
			WorkflowID = @WorkflowID,
			LiveFcstNextFlowID = 1,
			WorkflowStateID = @WorkflowStateID_Free
		WHERE NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow] LFNF WHERE LFNF.WorkflowID = @WorkflowID AND LFNF.LiveFcstNextFlowID = 1)

		SET @Inserted = @Inserted + @@ROWCOUNT

		--Structured
		UPDATE LFNF
		SET
			WorkflowStateID = ISNULL(@WorkflowStateID_Structured, LFNF.WorkflowStateID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow] LFNF
		WHERE
			LFNF.InstanceID = @InstanceID AND
			LFNF.WorkflowID = @WorkflowID AND
			LFNF.LiveFcstNextFlowID = 2

		SET @Updated = @Updated + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow]
			(
			InstanceID,
			WorkflowID,
			LiveFcstNextFlowID,
			WorkflowStateID
			)
		SELECT
			InstanceID = @InstanceID,
			WorkflowID = @WorkflowID,
			LiveFcstNextFlowID = 2,
			WorkflowStateID = @WorkflowStateID_Structured
		WHERE NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow] LFNF WHERE LFNF.WorkflowID = @WorkflowID AND LFNF.LiveFcstNextFlowID = 2)

		SET @Inserted = @Inserted + @@ROWCOUNT

		--Closed
		UPDATE LFNF
		SET
			WorkflowStateID = ISNULL(@WorkflowStateID_Closed, LFNF.WorkflowStateID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow] LFNF
		WHERE
			LFNF.InstanceID = @InstanceID AND
			LFNF.WorkflowID = @WorkflowID AND
			LFNF.LiveFcstNextFlowID = 3

		SET @Updated = @Updated + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow]
			(
			InstanceID,
			WorkflowID,
			LiveFcstNextFlowID,
			WorkflowStateID
			)
		SELECT
			InstanceID = @InstanceID,
			WorkflowID = @WorkflowID,
			LiveFcstNextFlowID = 3,
			WorkflowStateID = @WorkflowStateID_Closed
		WHERE NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow] LFNF WHERE LFNF.WorkflowID = @WorkflowID AND LFNF.LiveFcstNextFlowID = 3)

		SET @Inserted = @Inserted + @@ROWCOUNT

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
