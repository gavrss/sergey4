SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_WriteAccess]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@AssignmentID int = NULL,
	@DataClassID int = NULL,
	@Scenario_MemberKey nvarchar(50) = NULL OUT,
	@TimeFrom int = NULL OUT,
	@TimeTo int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000491,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
DECLARE @Scenario_MemberKey nvarchar(50), @TimeFrom int, @TimeTo int
EXEC [spGet_WriteAccess] @UserID = 11220, @InstanceID = -1287, @VersionID = -1287, @AssignmentID = 15533, @DataClassID = 9693, @Scenario_MemberKey = @Scenario_MemberKey OUT, @TimeFrom = @TimeFrom OUT, @TimeTo = @TimeTo OUT --, @Debug = 1
SELECT  [@Scenario_MemberKey] = @Scenario_MemberKey, [@TimeFrom] = @TimeFrom, [@TimeTo] = @TimeTo

EXEC [spGet_WriteAccess] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@OrganizationHierarchyID int,
	@WorkflowID int,
	@CalledYN bit = 1,
	@InputAllowedYN bit,

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
	@Version nvarchar(50) = '2.1.2.2198'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get write access',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-299: Handle VersionID.'
		IF @Version = '2.0.3.2153' SET @Description = 'Test on InputAllowedYN in Scenario.'
		IF @Version = '2.1.2.2198' SET @Description = 'Updated to latest SP template. DB-1519: Returns WorflowStates from Workflow-Levels WriteAccess Setup regardless of WorkflowState Transitions set in each Organization Level.'

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

		SELECT
			@Scenario_MemberKey = S.MemberKey,
			@InputAllowedYN = S.InputAllowedYN,
			@WorkflowID = A.WorkflowID,
			@OrganizationHierarchyID = OP.OrganizationHierarchyID,
			@TimeFrom = CASE WHEN WF.TimeFrom > S.ClosedMonth THEN WF.TimeFrom ELSE CASE WHEN S.ClosedMonth % 100 = 12 THEN (S.ClosedMonth / 100 + 1) * 100 + 1 ELSE S.ClosedMonth + 1 END END,
			@TimeTo = WF.TimeTo
		FROM
			Assignment A
			INNER JOIN Workflow WF ON WF.WorkflowID = A.WorkflowID AND WF.SelectYN <> 0 AND WF.DeletedID IS NULL
			INNER JOIN Scenario S ON S.ScenarioID = WF.ScenarioID AND S.InputAllowedYN <> 0 AND (S.ClosedMonth < WF.TimeTo OR S.ClosedMonth IS NULL) AND S.SelectYN <> 0 AND S.DeletedID IS NULL
			INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NULL
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.AssignmentID = @AssignmentID AND
			A.DataClassID = @DataClassID AND
			A.SelectYN <> 0 AND
			A.DeletedID IS NULL

		IF @Debug <> 0 SELECT [@Scenario_MemberKey] = @Scenario_MemberKey, [@InputAllowedYN] = @InputAllowedYN, [@WorkflowID] = @WorkflowID, [@OrganizationHierarchyID] = @OrganizationHierarchyID, [@TimeFrom] = @TimeFrom, [@TimeTo] = @TimeTo

	SET @Step = 'Create and fill temp table #OrganizationLevel'
		CREATE TABLE #OrganizationLevel
			(
			OrganizationLevelNo int
			)

		INSERT INTO #OrganizationLevel
			(
			OrganizationLevelNo
			)	
		SELECT DISTINCT
			OP.OrganizationLevelNo
		FROM
			[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.UserID = @UserID AND OPU.DeletedID IS NULL
		WHERE
			OP.InstanceID = @InstanceID AND
			OP.VersionID = @VersionID AND
			OP.OrganizationHierarchyID = @OrganizationHierarchyID AND
			OP.DeletedID IS NULL

		IF @Debug <> 0 SELECT TempTable = '#OrganizationLevel', * FROM #OrganizationLevel

	SET @Step = 'If not existing, create temp table #WorkflowState.'
		IF OBJECT_ID (N'tempdb..#WorkflowState', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #WorkflowState
					(
					[WorkflowStateID] int,
					[Scenario_MemberKey] nvarchar(50),
					[TimeFrom] int,
					[TimeTo] int
					)
			END

	SET @Step = 'Fill temp table #WorkflowState.'
		IF @InputAllowedYN <> 0
			INSERT INTO #WorkflowState
				(
				[WorkflowStateID],
				[Scenario_MemberKey],
				[TimeFrom],
				[TimeTo]
				)
			SELECT DISTINCT
				[WorkflowStateID] = WFAR.[WorkflowStateID],
				[Scenario_MemberKey] = @Scenario_MemberKey,
				[TimeFrom] = @TimeFrom,
				[TimeTo] = @TimeTo
			FROM
				[pcINTEGRATOR_Data].[dbo].[WorkflowAccessRight] WFAR
				INNER JOIN #OrganizationLevel OL ON OL.OrganizationLevelNo = WFAR.OrganizationLevelNo
				--INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WFSC ON
				--	WFSC.InstanceID = WFAR.InstanceID AND
				--	WFSC.VersionID = WFAR.VersionID AND
				--	WFSC.WorkFlowID = WFAR.WorkflowID AND
				--	WFSC.OrganizationHierarchyID = WFAR.OrganizationHierarchyID AND
				--	WFSC.OrganizationLevelNo = WFAR.OrganizationLevelNo AND
				--	WFSC.FromWorkflowStateID = WFAR.WorkflowStateID AND
				--	WFSC.UserChangeableYN <> 0
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WFS ON
					WFS.InstanceID = WFAR.InstanceID AND
					WFS.VersionID = WFAR.VersionID AND
					WFS.WorkFlowID = WFAR.WorkflowID AND
					WFS.WorkflowStateID = WFAR.WorkflowStateID 
			WHERE
  				WFAR.InstanceID = @InstanceID AND
				WFAR.VersionID = @VersionID AND
				WFAR.WorkFlowID = @WorkflowID AND
				WFAR.OrganizationHierarchyID = @OrganizationHierarchyID AND
				WFAR.SecurityLevelBM & 16 > 0

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = '#WorkflowState', * FROM #WorkflowState ORDER BY [WorkflowStateID]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp table'
		DROP TABLE #OrganizationLevel
		IF @CalledYN = 0 DROP TABLE #WorkflowState

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
