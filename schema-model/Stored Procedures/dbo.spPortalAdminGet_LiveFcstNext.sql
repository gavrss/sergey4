SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_LiveFcstNext]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowID int = NULL, --Optional
	@ResultTypeBM int = 15, 

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000329,
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
	@ProcedureName = 'spPortalAdminGet_LiveFcstNext',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_LiveFcstNext] @UserID=-10, @InstanceID=-1158, @VersionID=-1096, @WorkflowID = 1124, @Debug=1

EXEC [spPortalAdminGet_LiveFcstNext] @GetVersion = 1
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
	@Version nvarchar(50) = '2.0.0.2141'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows for LiveFcstNext settings',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2141' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description
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

	SET @Step = 'Create temp table'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				CREATE TABLE [#Month]
					(
					[Counter] [int] IDENTITY(1,1) NOT NULL,
					[Month] [int] NOT NULL
					)

				INSERT INTO [#Month]
					(
					[Month]
					)
				SELECT DISTINCT TOP 1000000
					[Month] = Y.Y * 100 + M.M
				FROM
					(
						SELECT
							[Y] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
						FROM
							Digit D1,
							Digit D2,
							Digit D3,
							Digit D4
						WHERE
							D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN YEAR(GetDate()) - 4 AND YEAR(GetDate()) + 3
					) Y,
					(
						SELECT
							[M] = D2.Number * 10 + D1.Number + 1 
						FROM
							Digit D1,
							Digit D2
						WHERE
							D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
					) M 
				ORDER BY
					Y.Y * 100 + M.M

				IF @Debug <> 0 SELECT TempTable = '#Month', * FROM [#Month]
			END

	SET @Step = 'LiveFcstNextFlow'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 1,
					WF.WorkflowID,
					WF.WorkflowName,
					[Scenario_MemberKey] = S.[MemberKey],
					S.AutoSaveOnCloseYN,
					S.[ClosedMonth],
					[TimeFrom] = MF.[Month],
					[TimeTo] = MT.[Month],
					WF.[LiveFcstNext_ClosedMonth],
					WF.[LiveFcstNext_TimeFrom],
					WF.[LiveFcstNext_TimeTo],
					WorkflowStateID_Free = LFNF1.WorkflowStateID,
					WorkflowStateID_Structured = LFNF2.WorkflowStateID,
					WorkflowStateID_Closed = LFNF3.WorkflowStateID
				FROM
					[Scenario] S
					INNER JOIN Workflow WF ON WF.InstanceID = S.InstanceID AND WF.VersionID = S.VersionID AND WF.ScenarioID = S.ScenarioID AND (WF.WorkflowID = @WorkflowID OR @WorkflowID IS NULL)
					INNER JOIN #Month M ON M.[Month] = S.[ClosedMonth]
					INNER JOIN #Month MF ON MF.[Counter] = M.[Counter] + WF.TimeOffsetFrom + 1
					INNER JOIN #Month MT ON MT.[Counter] = M.[Counter] + WF.TimeOffsetTo
					LEFT JOIN Workflow_LiveFcstNextFlow LFNF1 ON LFNF1.InstanceID = S.InstanceID AND LFNF1.WorkflowID = WF.WorkflowID AND LFNF1.LiveFcstNextFlowID = 1
					LEFT JOIN Workflow_LiveFcstNextFlow LFNF2 ON LFNF2.InstanceID = S.InstanceID AND LFNF2.WorkflowID = WF.WorkflowID AND LFNF2.LiveFcstNextFlowID = 2
					LEFT JOIN Workflow_LiveFcstNextFlow LFNF3 ON LFNF3.InstanceID = S.InstanceID AND LFNF3.WorkflowID = WF.WorkflowID AND LFNF3.LiveFcstNextFlowID = 3
				WHERE
					S.InstanceID = @InstanceID AND
					S.VersionID = @VersionID AND
					S.ScenarioTypeID = -3 AND
					S.[SelectYN] <> 0 AND
					S.[DeletedID] IS NULL

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Assignments'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 2,
					A.WorkflowID,
					A.AssignmentID,
					A.AssignmentName,
					A.LiveFcstNextFlowID
				FROM
					Assignment A
				WHERE
					A.InstanceID = @InstanceID AND
					A.VersionID = @VersionID AND
					(A.WorkflowID = @WorkflowID OR @WorkflowID IS NULL) AND
					A.[SelectYN] <> 0 AND
					A.[DeletedID] IS NULL

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'WorkflowState'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					[WorkflowStateId] = WS.[WorkflowStateId],
					[WorkflowStateName] = WS.[WorkflowStateName],
					[WorkflowStateDescription] = WS.[WorkflowStateName]
				FROM
					[WorkflowState] WS
				WHERE
					[InstanceID] = @InstanceID AND
					[WorkflowID] = @WorkflowID 
				ORDER BY
					WS.[WorkflowStateId]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'LiveFcstNextFlow'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 8,
					[LiveFcstNextFlowID],
					[LiveFcstNextFlowName],
					[LiveFcstNextFlowDescription]
				FROM
					[LiveFcstNextFlow]
				ORDER BY
					[LiveFcstNextFlowID]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		IF @ResultTypeBM & 1 > 0 DROP TABLE [#Month]

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
