SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Workflow]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowID int = NULL,
	@OrganizationHierarchyID int = NULL,
	@ResultTypeBM int = 63,
		-- 1 = Workflow definition
		-- 2 = Organization hierarchies that are part of workflow
		-- 4 = Workflow Level definition (1 for each level in Organization hierarchy)
		-- 8 = Workflow rows
		--16 = WorkflowAccessRights
		--32 = WorkflowStateChange

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000108,
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
	@ProcedureName = 'spPortalAdminGet_Workflow',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_Workflow] @UserID = -10, @InstanceID = -1089, @VersionID = -1027, @WorkflowID = 1023, @OrganizationHierarchyID = -1003, @ResultTypeBM = 2
EXEC [spPortalAdminGet_Workflow] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @WorkflowID = 1001, @OrganizationHierarchyID = 1002, @ResultTypeBM = 8
EXEC [spPortalAdminGet_Workflow] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @WorkflowID = 1001, @OrganizationHierarchyID = 1002, @ResultTypeBM = 4
EXEC [spPortalAdminGet_Workflow] @UserID='-10', @InstanceID='413', @VersionID='1008',  @WorkflowID='2174', @OrganizationHierarchyID='1074', @ResultTypeBM='63'

EXEC [spPortalAdminGet_Workflow] @GetVersion = 1
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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get data for workflow UI',
			@MandatoryParameter = 'WorkflowID|OrganizationHierarchyID' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'SP template.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-299: Handle VersionID.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'

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

	SET @Step = 'List all properties for a specific Workflow'
		IF @ResultTypeBM & 1 > 0 --Workflow definition
			SELECT 
				ResultTypeBM = 1,
				ReadOnlyYN = 0,
				V.ModelingLockedYN,
				WF.[WorkflowID],
				[WorkflowName],
				WF.[ProcessID],
				P.ProcessName,
				P.ProcessDescription,
				WF.[ScenarioID],
				S.ScenarioDescription,
				S.ScenarioTypeID,
				ST.ScenarioTypeName,
				[CompareScenarioID],
				CompareScenarioDescription = CS.ScenarioDescription,
				[TimeFrom],
				[TimeTo],
				[TimeOffsetFrom],
				[TimeOffsetTo],
				WF.[SelectYN],
				NoOfLevels = (SELECT MAX(OrganizationLevelNo) FROM OrganizationLevel WHERE OrganizationHierarchyID = @OrganizationHierarchyID),
				WF.[ModelingStatusID],
				MS.ModelingStatusDescription,
				WF.[ModelingComment],
				WF.InitialWorkflowStateID,
				InitialWorkflowStateName = WS.WorkflowStateName,
				WF.RefreshActualsInitialWorkflowStateID
			FROM
				[Workflow] WF
				INNER JOIN [Version] V ON V.VersionID = WF.VersionID
				INNER JOIN [ModelingStatus] MS ON MS.[ModelingStatusID] = WF.[ModelingStatusID]
				INNER JOIN [Process] P ON P.ProcessID = WF.ProcessID
				LEFT JOIN [Scenario] S ON S.[ScenarioID] = WF.[ScenarioID]
				LEFT JOIN [ScenarioType] ST ON ST.ScenarioTypeID = S.ScenarioTypeID
				LEFT JOIN [Scenario] CS ON CS.[ScenarioID] = WF.[CompareScenarioID]
				LEFT JOIN WorkflowState WS ON WS.WorkflowID = WF.WorkflowID AND WS.WorkflowStateId = WF.InitialWorkflowStateID
			WHERE
			--	@UserID int,
				WF.[InstanceID] = @InstanceID AND
				WF.[VersionID] = @VersionID AND
				WF.[WorkflowID] = @WorkflowID AND
				WF.[DeletedID] IS NULL
			--	@OrganizationHierarchyID int

	SET @Step = 'Organization hierarchies that are part of workflow'
		IF @ResultTypeBM & 2 > 0
			SELECT 
				ResultTypeBM = 2,
				ReadOnlyYN = 0,
				OH.OrganizationHierarchyID,
				OH.OrganizationHierarchyName
			FROM 
				[Workflow] WF
				INNER JOIN OrganizationHierarchy_Process OHP ON OHP.ProcessID = WF.ProcessID
				INNER JOIN OrganizationHierarchy OH ON OH.OrganizationHierarchyID = OHP.OrganizationHierarchyID AND OH.DeletedID IS NULL
			WHERE
				WF.[InstanceID] = @InstanceID AND
				WF.[VersionID] = @VersionID AND
				WF.[WorkflowID] = @WorkflowID AND
				WF.[DeletedID] IS NULL

	SET @Step = 'Workflow Level definition (1 for each level in Organization hierarchy)'
		IF @ResultTypeBM & 4 > 0
			SELECT DISTINCT
				ResultTypeBM = 4,
				ReadOnlyYN = 0,
				OH.OrganizationHierarchyID, 
				OH.OrganizationHierarchyName,
				WFOL.OrganizationLevelNo,
				OL.OrganizationLevelName,
				LevelInWorkflowYN = WFOL.LevelInWorkflowYN,
				ExpectedDate = WFOL.ExpectedDate,
				ActionDescription = WFOL.ActionDescription
			FROM
				OrganizationHierarchy OH
				INNER JOIN Workflow_OrganizationLevel WFOL ON WFOL.WorkFlowID = @WorkflowID
				LEFT JOIN OrganizationLevel OL ON OL.OrganizationHierarchyID = OH.OrganizationHierarchyID AND OL.OrganizationLevelNo = WFOL.OrganizationLevelNo
			WHERE
				OH.[InstanceID] = @InstanceID AND
				OH.OrganizationHierarchyID = @OrganizationHierarchyID AND
				OH.[VersionID] = @VersionID 
			ORDER BY
				OH.OrganizationHierarchyID,
				WFOL.OrganizationLevelNo DESC

	SET @Step = 'Workflow rows'
		IF @ResultTypeBM & 8 > 0 --Workflow rows
			SELECT 
				ResultTypeBM = 8,
				ReadOnlyYN = 0,
				WFR.[DimensionID],
				D.DimensionName,
				WFR.[Dimension_MemberKey],
				WFR.[CogentYN]
			FROM
				WorkflowRow WFR
				INNER JOIN Dimension D ON D.DimensionID = WFR.DimensionID
			WHERE
				WFR.WorkflowID = @WorkflowID

	SET @Step = 'Workflow Access Rights'
		IF @ResultTypeBM & 16 > 0
			SELECT 
				ResultTypeBM = 16,
				ReadOnlyYN = 0,
				OH.[OrganizationHierarchyID],
				OH.OrganizationHierarchyName,
				OL.[OrganizationLevelNo],
				OL.OrganizationLevelName,
				WFOL.LevelInWorkflowYN,
				WFAR.[WorkflowStateID],
				WFS.WorkflowStateName,
				WriteAccessYN = CASE WHEN WFAR.[SecurityLevelBM] & 16 > 0 THEN 1 ELSE 0 END
			FROM
				[OrganizationHierarchy] OH
				INNER JOIN OrganizationLevel OL ON OL.[InstanceID] = OH.InstanceID AND OL.[VersionID] = OH.[VersionID] AND OL.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID]
				LEFT JOIN Workflow_OrganizationLevel WFOL ON WFOL.[InstanceID] = OH.InstanceID AND WFOL.[VersionID] = OH.[VersionID] AND WFOL.WorkflowID = @WorkflowID AND WFOL.OrganizationLevelNo = OL.OrganizationLevelNo
				LEFT JOIN [WorkflowAccessRight] WFAR ON WFAR.[InstanceID] = OH.InstanceID AND WFAR.[VersionID] = OH.[VersionID] AND WFAR.WorkflowID = @WorkflowID AND WFAR.OrganizationHierarchyID = @OrganizationHierarchyID AND WFAR.OrganizationLevelNo = OL.OrganizationLevelNo
				LEFT JOIN WorkflowState WFS ON WFS.[InstanceID] = OH.InstanceID AND WFS.[VersionID] = OH.[VersionID] AND WFS.WorkflowStateID = WFAR.WorkflowStateID
			WHERE
				OH.[InstanceID] = @InstanceID AND
				OH.[VersionID] = @VersionID AND
				OH.[OrganizationHierarchyID] = @OrganizationHierarchyID
			ORDER BY
				OL.[OrganizationLevelNo] DESC,
				WFAR.[WorkflowStateID]
		
	SET @Step = 'WorkflowStateChange'
		IF @ResultTypeBM & 32 > 0
			SELECT 
				ResultTypeBM = 32,
				ReadOnlyYN = 0,
				OH.OrganizationHierarchyID,
				OH.OrganizationHierarchyName,
				OL.OrganizationLevelNo,
				OL.OrganizationLevelName,
				WFOL.LevelInWorkflowYN,
				WFSC.FromWorkflowStateID,
				FromWorkflowStateName = WFSF.WorkflowStateName,
				WFSC.ToWorkflowStateID,
				ToWorkflowStateName = WFST.WorkflowStateName,
				WFSC.UserChangeableYN,
				WFSC.BRChangeableYN
			FROM
				[OrganizationHierarchy] OH
				INNER JOIN OrganizationLevel OL ON OL.[InstanceID] = OH.InstanceID AND OL.[VersionID] = OH.[VersionID] AND OL.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID]
				LEFT JOIN Workflow_OrganizationLevel WFOL ON WFOL.[InstanceID] = OH.InstanceID AND WFOL.[VersionID] = OH.[VersionID] AND WFOL.[WorkflowID] = @WorkflowID AND WFOL.[OrganizationLevelNo] = OL.[OrganizationLevelNo]
				LEFT JOIN WorkflowStateChange WFSC ON WFSC.[InstanceID] = OH.InstanceID AND WFSC.[VersionID] = OH.[VersionID] AND WFSC.[WorkflowID] = @WorkflowID AND WFSC.[OrganizationHierarchyID] = @OrganizationHierarchyID AND WFSC.[OrganizationLevelNo] = OL.[OrganizationLevelNo]
				LEFT JOIN WorkflowState WFSF ON WFSF.[InstanceID] = OH.InstanceID AND WFSF.[VersionID] = OH.[VersionID] AND WFSF.[WorkflowStateID] = WFSC.FromWorkflowStateID
				LEFT JOIN WorkflowState WFST ON WFST.[InstanceID] = OH.InstanceID AND WFST.[VersionID] = OH.[VersionID] AND WFST.[WorkflowStateID] = WFSC.ToWorkflowStateID
			WHERE
				OH.[InstanceID] = @InstanceID AND
				OH.[VersionID] = @VersionID AND
				OH.[OrganizationHierarchyID] = @OrganizationHierarchyID
			ORDER BY
				OL.[OrganizationLevelNo] DESC,
				WFSC.[FromWorkflowStateID]

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
