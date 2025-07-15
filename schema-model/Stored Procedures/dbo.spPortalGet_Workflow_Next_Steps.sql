SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Workflow_Next_Steps]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID INT = NULL,
	@AssignmentID INT = NULL,
	@ActingAs INT = NULL, --Optional (OrganizationPositionID)

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000161,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

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

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2187'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Show next possible workflow states',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-349: Added parameter @AssignmentID.'
		IF @Version = '2.1.0.2155' SET @Description = 'Do not show illegal rows in table [WorkflowStateChange].'
		IF @Version = '2.1.0.2156' SET @Description = 'DB-504: Added filter for #LevelDiff ON WFSC.UserChangeableYN <> 0 to avoid disabled WorkflowStates set by User.'
		IF @Version = '2.1.2.2187' SET @Description = 'DB-1291: Added parameter @ActingAs; added temp table #Assignment_OL; modified query for #LevelDiff.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @DebugBM & 2 > 0 
			BEGIN
				SELECT [Table] = 'Assignment', * FROM [pcINTEGRATOR_Data].[dbo].[Assignment] WHERE AssignmentID = @AssignmentID

				SELECT [Table] = 'Assignment_OrganizationLevel', * FROM [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL WHERE AssignmentID = @AssignmentID

				SELECT 
					OP.OrganizationPositionID,
					OP.OrganizationLevelNo,
					OP.OrganizationHierarchyID
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
					LEFT JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID
				WHERE
					OP.InstanceID = @InstanceID AND
					(OPU.UserID = @UserID OR OP.OrganizationPositionID = @ActingAs)
			END

	SET @Step = 'Create temp table #Assignment_OL'
		SELECT DISTINCT
			A.AssignmentID,
			A.AssignmentName,
			AOL.OrganizationPositionID,
			AOL.OrganizationLevelNo,
			OP.OrganizationHierarchyID,
			A.WorkflowID
		INTO
			#Assignment_OL
		FROM
			[pcINTEGRATOR_Data].[dbo].[Assignment] A
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] WF ON WF.WorkflowID = A.WorkflowID AND WF.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL ON AOL.AssignmentID = A.AssignmentID AND (AOL.OrganizationPositionID = A.OrganizationPositionID OR AOL.OrganizationPositionID = @ActingAs)
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.OrganizationPositionID = AOL.OrganizationPositionID AND OP.OrganizationLevelNo = AOL.OrganizationLevelNo
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = AOL.OrganizationPositionID OR OPU.UserID = @UserID
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			(A.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
			(A.[AssignmentID] = @AssignmentID OR @AssignmentID IS NULL) AND
			A.[SelectYN] <> 0 AND
			A.[DeletedID] IS NULL

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Assignment_OL', * FROM #Assignment_OL

	SET @Step = 'Find next closest actor'
		SELECT 
			AOL.[AssignmentID],
			WFSC.FromWorkflowStateID,
			WFSC.ToWorkflowStateID,
			LevelDiff = MIN(ABS(AOL.OrganizationLevelNo - WFSC.OrganizationLevelNo))
		INTO
			#LevelDiff
		FROM
			#Assignment_OL AOL
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WFSC ON WFSC.WorkflowID = AOL.WorkflowID AND WFSC.OrganizationHierarchyID = AOL.OrganizationHierarchyID AND WFSC.OrganizationLevelNo = AOL.OrganizationLevelNo AND WFSC.UserChangeableYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WFSCT ON WFSCT.WorkflowID = AOL.WorkflowID AND WFSCT.OrganizationHierarchyID = AOL.OrganizationHierarchyID AND WFSCT.FromWorkflowStateID = WFSC.ToWorkflowStateID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WSTF ON WSTF.WorkflowID = AOL.WorkflowID AND WSTF.WorkflowStateId = WFSC.FromWorkflowStateID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WSTT ON WSTT.WorkflowID = AOL.WorkflowID AND WSTT.WorkflowStateId = WFSC.ToWorkflowStateID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOLT ON AOLT.AssignmentID = AOL.AssignmentID AND AOLT.OrganizationLevelNo = WFSCT.OrganizationLevelNo
		GROUP BY
			AOL.[AssignmentID],
			WFSC.[FromWorkflowStateID],
			WFSC.[ToWorkflowStateID]

		IF @Debug <> 0 SELECT TempTable = '#LevelDiff', * FROM #LevelDiff ORDER BY [AssignmentID], FromWorkflowStateID, ToWorkflowStateID

	SET @Step = 'Return rows'
		SELECT DISTINCT
			AOL.[AssignmentID],
			WFSC.FromWorkflowStateID,
			FromWorkflowStateName = WSF.WorkflowStateName,
			WFSC.ToWorkflowStateID,
			ToWorkflowStateName = WST.WorkflowStateName,
			AOL.AssignmentName,
			NextWorkflowUserID = CASE WHEN LD.LevelDiff = 0 THEN NULL ELSE UT.UserID END,
			NextWorkflowUserName = CASE WHEN LD.LevelDiff = 0 THEN NULL ELSE UT.UserNameDisplay END
		FROM
			#Assignment_OL AOL
			INNER JOIN #LevelDiff LD ON LD.AssignmentID = AOL.AssignmentID  			
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WFSC ON WFSC.WorkflowID = AOL.WorkflowID AND WFSC.OrganizationHierarchyID = AOL.OrganizationHierarchyID AND WFSC.OrganizationLevelNo = AOL.OrganizationLevelNo AND WFSC.FromWorkflowStateID = LD.FromWorkflowStateID AND  WFSC.ToWorkflowStateID = LD.ToWorkflowStateID AND WFSC.UserChangeableYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WSF ON WSF.WorkflowStateId = WFSC.FromWorkflowStateID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WST ON WST.WorkflowStateId = WFSC.ToWorkflowStateID
			LEFT JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPUT ON OPUT.OrganizationPositionID = AOL.OrganizationPositionID AND OPUT.DelegateYN = 0
			LEFT JOIN [pcINTEGRATOR_Data].[dbo].[User] UT ON UT.UserID = OPUT.UserID
		ORDER BY
			AOL.[AssignmentID],
			WFSC.[FromWorkflowStateID],
			WFSC.[ToWorkflowStateID]

	SET @Step = 'Drop temp tables'
		DROP TABLE #LevelDiff

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
