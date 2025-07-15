SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Workflow_Next_Steps_New]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,
	@AssignmentID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000161,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
Purpose of this is to be able to show next possible workflow states for a range of cells with same WorkflowStateID and AssignmentID

EXEC [spRun_Procedure_KeyValuePair] 
@JSON='[{"TKey":"InstanceID","TValue":"413"},{"TKey":"UserID","TValue":"2151"},{"TKey":"VersionID","TValue":"1008"},{"TKey":"AssignmentID","TValue":"13792"}]', 
@ProcedureName='spPortalGet_Workflow_Next_Steps'

EXEC [spPortalGet_Workflow_Next_Steps] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spPortalGet_Workflow_Next_Steps] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2156'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Show next possible workflow states',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-349: Added parameter @AssignmentID.'
		IF @Version = '2.1.0.2155' SET @Description = 'Do not show illegal rows in table [WorkflowStateChange].'
		IF @Version = '2.1.0.2156' SET @Description = 'DB-504: Added filter for #LevelDiff ON WFSC.UserChangeableYN <> 0 to avoid disabled WorkflowStates set by User.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Find next closest actor'
		SELECT 
			A.[AssignmentID],
			WFSC.FromWorkflowStateID,
			WFSC.ToWorkflowStateID,
			LevelDiff = MIN(ABS(OP.OrganizationLevelNo - WFSCT.OrganizationLevelNo))
		INTO
			#LevelDiff
		FROM
			[pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.OrganizationPositionID = AOL.OrganizationPositionID AND OP.OrganizationLevelNo = AOL.OrganizationLevelNo
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = AOL.OrganizationPositionID AND OPU.UserID = @UserID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.AssignmentID = AOL.AssignmentID AND (A.DataClassID = @DataClassID OR @DataClassID IS NULL)
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] WF ON WF.WorkflowID = A.WorkflowID AND WF.SelectYN <> 0

-- Filter ON WFSC.UserChangeableYN <> 0 added to avoid disabled WorkflowStates set by User (by neha 20200730)
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WFSC ON WFSC.WorkflowID = A.WorkflowID AND WFSC.OrganizationHierarchyID = OP.OrganizationHierarchyID AND WFSC.OrganizationLevelNo = AOL.OrganizationLevelNo AND WFSC.UserChangeableYN <> 0
--			
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WFSCT ON WFSCT.WorkflowID = A.WorkflowID AND WFSCT.OrganizationHierarchyID = OP.OrganizationHierarchyID AND WFSCT.FromWorkflowStateID = WFSC.ToWorkflowStateID

-- Filter added 20200708 to avoid illegal rows in table [WorkflowStateChange]
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WSTF ON WSTF.WorkflowID = A.WorkflowID AND WSTF.WorkflowStateId = WFSC.FromWorkflowStateID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WSTT ON WSTT.WorkflowID = A.WorkflowID AND WSTT.WorkflowStateId = WFSC.ToWorkflowStateID
--
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOLT ON AOLT.AssignmentID = A.AssignmentID AND AOLT.OrganizationLevelNo = WFSCT.OrganizationLevelNo
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPUT ON OPUT.OrganizationPositionID = AOLT.OrganizationPositionID AND OPUT.DelegateYN = 0
		WHERE
			AOL.[InstanceID] = @InstanceID AND
			AOL.[VersionID] = @VersionID AND
			(AOL.[AssignmentID] = @AssignmentID OR @AssignmentID IS NULL)
		GROUP BY
			A.[AssignmentID],
			WFSC.[FromWorkflowStateID],
			WFSC.[ToWorkflowStateID]

			IF @Debug <> 0 SELECT TempTable = '#LevelDiff', * FROM #LevelDiff ORDER BY [AssignmentID], FromWorkflowStateID, ToWorkflowStateID

	SET @Step = 'Return rows'
		SELECT DISTINCT
			A.[AssignmentID],
			WFSC.FromWorkflowStateID,
			FromWorkflowStateName = WSF.WorkflowStateName,
			WFSC.ToWorkflowStateID,
			ToWorkflowStateName = WST.WorkflowStateName,
			A.AssignmentName,
			NextWorkflowUserID = CASE WHEN LD.LevelDiff = 0 THEN NULL ELSE UT.UserID END,
			NextWorkflowUserName = CASE WHEN LD.LevelDiff = 0 THEN NULL ELSE UT.UserNameDisplay END
		FROM
			[pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.OrganizationPositionID = AOL.OrganizationPositionID AND OP.OrganizationLevelNo = AOL.OrganizationLevelNo
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = AOL.OrganizationPositionID AND OPU.UserID = @UserID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.AssignmentID = AOL.AssignmentID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] WF ON WF.WorkflowID = A.WorkflowID AND WF.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WFSC ON WFSC.WorkflowID = A.WorkflowID AND WFSC.OrganizationHierarchyID = OP.OrganizationHierarchyID AND WFSC.OrganizationLevelNo = AOL.OrganizationLevelNo
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WSF ON WSF.WorkflowStateId = WFSC.FromWorkflowStateID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WFSCT ON WFSCT.WorkflowID = A.WorkflowID AND WFSCT.OrganizationHierarchyID = OP.OrganizationHierarchyID AND WFSCT.FromWorkflowStateID = WFSC.ToWorkflowStateID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WST ON WST.WorkflowStateId = WFSCT.FromWorkflowStateID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOLT ON AOLT.AssignmentID = A.AssignmentID AND AOLT.OrganizationLevelNo = WFSCT.OrganizationLevelNo
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPUT ON OPUT.OrganizationPositionID = AOLT.OrganizationPositionID AND OPUT.DelegateYN = 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] UT ON UT.UserID = OPUT.UserID
			INNER JOIN #LevelDiff LD ON LD.AssignmentID = A.AssignmentID AND LD.FromWorkflowStateID = WFSC.FromWorkflowStateID AND LD.ToWorkflowStateID = WFSC.ToWorkflowStateID AND LD.LevelDiff = ABS(OP.OrganizationLevelNo - WFSCT.OrganizationLevelNo)
		WHERE
			AOL.[InstanceID] = @InstanceID AND
			AOL.[VersionID] = @VersionID
		ORDER BY
			A.[AssignmentID],
			WFSC.[FromWorkflowStateID],
			WFSC.[ToWorkflowStateID]

	SET @Step = 'Drop temp tables'
		DROP TABLE #LevelDiff

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
