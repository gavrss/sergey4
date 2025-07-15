SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spPortalGet_Workflow_Assignment_List]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ActingAs int = NULL, --Optional (OrganizationPositionID)
	@WorkflowID int = NULL, --Optional
	@AssignmentID int = NULL, --Optional
	@ResultTypeBM int = 3, --1 = AssignmentList, 2 = AssignmentRow, 4 = Valid assignments per user

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000160,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalGet_Workflow_Assignment_List',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC spPortalGet_Workflow_Assignment_List @UserID = 2016, @InstanceID = 304, @VersionID = 1001
EXEC [spPortalGet_Workflow_Assignment_List] @UserID='2120', @InstanceID='114', @VersionID = 1004

EXEC spPortalGet_Workflow_Assignment_List @InstanceID = 304, @UserID = 2063
EXEC spPortalGet_Workflow_Assignment_List @UserID = -1046, @InstanceID = -1089, @VersionID = -1027, @Debug = 1
EXEC spPortalGet_Workflow_Assignment_List @InstanceID = 304, @UserID = 2063, @Debug = 1
EXEC spPortalGet_Workflow_Assignment_List @InstanceID = 304, @UserID = 2072, @Debug = 1
EXEC spPortalGet_Workflow_Assignment_List @InstanceID = 304, @UserID = 2051, @VersionID = 1013, @Debug = 1

EXEC spPortalGet_Workflow_Assignment_List @UserID = 2120, @InstanceID = 114, @VersionID = 1004, @Debug = 1

EXEC spPortalGet_Workflow_Assignment_List @InstanceID='-1125',@ResultTypeBM='1',@UserID='7273',@VersionID='-1125'
--,@ProcedureID=880000160,@StartTime='2019-07-09 11:05:01.357', @Debug = 1

EXEC spPortalGet_Workflow_Assignment_List @InstanceID = 454, @UserID = 7564, @VersionID = 1021, @AssignmentID = 12402, @ResultTypeBM = 1, @Debug = 1
EXEC spPortalGet_Workflow_Assignment_List @InstanceID = 454, @UserID = 7564, @VersionID = 1021, @WorkflowID = 4469, @ResultTypeBM = 1, @Debug = 1
EXEC spPortalGet_Workflow_Assignment_List @InstanceID = 454, @UserID = 7564, @VersionID = 1021, @AssignmentID = 12453, @ResultTypeBM = 4

EXEC [spPortalGet_Workflow_Assignment_List] @GetVersion = 1
*/

/*
OrganizationPositionID = Which role of the current person is this assigment assigned to.
OrganizationPostionName = ID of that role
OrganizationPositionDescription = Description of that role
DelegateYN = 0 if the person is the main owner/ accountable, 1 if the person has this as a delegation
WriteYN = 0 if there are no cells that can be changed at this point in time by this user in this assignment, 1 if there are cells that can be changed
WorkflowActionYN = 0 if there are not allowed workflow state changes for the current user in this assignment, 1 if there are allowed changes that can  be performed
GridID = a pointer to the default Form/ Grid/ Report/ Input schedule to use to display/ open this assignment.
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
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return list of Assignments',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2145' SET @Description = 'Added extra joins on @ResultTypeBM = 1 on InstanceID and VersionID to filter rows pointing to wrong InstanceID.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-105: Not include dimensions where ReportOnlyYN = 1'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-126: Added ResultTypeBM = 4 and optional parameters @WorkflowID and @AssignmentID. DB-127: ResultTypeBM = 1, Exclude inactive and deleted rows.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-422: Added rows to ResultTypeBM = 1. DB-440: Added compareScenarioID to ResultypeBM = 1.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added parameter @ActingAs.'
		IF @Version = '2.1.0.2164' SET @Description = 'DB-603: Modified INSERT query of #MissingDimension table.'
		IF @Version = '2.1.2.2179' SET @Description = 'Filter temp table #MissingDimension with Dimension properties SelectYN <> 0 AND DeletedID IS NULL'
		IF @Version = '2.1.2.2182' SET @Description = 'DB-1263: Added [OrganizationLevelNo] column in the ResultTypeBM 1 resultset.'
		IF @Version = '2.1.2.2190' SET @Description = 'Updated to latest [sp_template] version. Added @JobID parameter in the [spGet_AssignmentRow] sub-routine.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added hierarchy columns to temp table #AssignmentRow.'
		IF @Version = '2.1.2.2199' SET @Description = 'Fixed: deleted users were in output for ResultTypeBM=1'

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

	SET @Step = 'Create temp tables'
		CREATE TABLE #AssignmentRow
			(
			[Source] nvarchar(50),
			[WorkflowID] int,
			[AssignmentID] int,
			[OrganizationPositionID] int,
			[DimensionID] int,
			[DimensionName] nvarchar(100),
			[HierarchyNo] int,
			[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Dimension_MemberKey] nvarchar(100),
			[CogentYN] bit
			)

		CREATE TABLE #MissingDimension (AssignmentID int, DimensionID int)

	SET @Step = 'Calculate Assignments'
		IF @ResultTypeBM & 11 > 0
			BEGIN
				EXEC spGet_AssignmentRow @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @WorkflowID = @WorkflowID, @AssignmentID = @AssignmentID, @UserDependentYN = 1, @JobID = @JobID, @Debug = @DebugSub

				IF @Debug <> 0 SELECT TempTable = '#AssignmentRow', * FROM #AssignmentRow
			END

	SET @Step = 'Calculate #MissingDimension'
		IF @ResultTypeBM & 9 > 0
			BEGIN
				INSERT INTO #MissingDimension (AssignmentID, DimensionID)
				SELECT DISTINCT
					A.AssignmentID,
					DCD.DimensionID
				FROM
					(SELECT DISTINCT AssignmentID FROM #AssignmentRow) AR
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.AssignmentID = AR.AssignmentID
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] W ON W.WorkflowID = A.WorkflowID AND W.SelectYN <> 0
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD ON DCD.DataClassID = A.DataClassID
					INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.ReportOnlyYN = 0 AND D.SelectYN <> 0 AND D.DeletedID IS NULL
				WHERE
					NOT EXISTS (SELECT 1 FROM (
									SELECT DISTINCT
										AssignmentID,
										DimensionID = -63 --WorkflowState
									FROM
										#AssignmentRow AR

									UNION SELECT DISTINCT
										AssignmentID,
										DimensionID
									FROM
										#AssignmentRow AR
										INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] W ON W.WorkflowID = AR.WorkflowID AND W.SelectYN <> 0

									UNION SELECT DISTINCT
										AssignmentID,
										DimensionID
									FROM
										#AssignmentRow
									WHERE
										[Source] IN ('Dimension', 'System')

									UNION SELECT DISTINCT
										A.AssignmentID,
										GD.DimensionID
									FROM
										[pcINTEGRATOR_Data].[dbo].[Assignment] A
										INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] W ON W.WorkflowID = A.WorkflowID AND W.SelectYN <> 0
										INNER JOIN [pcINTEGRATOR_Data].[dbo].[Grid_Dimension] GD ON GD.InstanceID = @InstanceID AND GD.GridID = A.GridID
									) sub
								WHERE (sub.AssignmentID = A.AssignmentID OR sub.AssignmentID IS NULL) AND sub.DimensionID = DCD.DimensionID)
								--WHERE sub.AssignmentID = A.AssignmentID AND sub.DimensionID = DCD.DimensionID)

				IF @Debug <> 0 SELECT TempTable = '#MissingDimension', * FROM #MissingDimension
			END
		
	SET @Step = '@ResultTypeBM & 1, AssignedTo (all assigned-to’s and delegates)'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 1,
					A.WorkflowID,
					W.WorkflowName,
					W.InitialWorkflowStateId,
					W.RefreshActualsInitialWorkflowStateId,
					W.CompareScenarioID,
					TimeFrom = CASE WHEN ST.LiveYN <> 0 THEN NULL ELSE W.TimeFrom END,
					TimeTo = CASE WHEN ST.LiveYN <> 0 THEN NULL ELSE W.TimeTo END,
					A.AssignmentID,
					A.AssignmentName,
					A.DataClassID,
					A.OrganizationPositionID,
					OP.OrganizationPositionName,
					OP.OrganizationPositionDescription,
					OP.OrganizationLevelNo,
					OH.LinkedDimensionID,
					OP.LinkedDimension_MemberKey,
					ActionDescription = ISNULL(AOL.ActionDescription, WFOL.ActionDescription),
					OPAssignedUserID = OPUR.UserID,
					OPAssignedUserNameDisplay = UR.UserNameDisplay, 
					GridID = ISNULL(AOL.GridID, A.GridID),
					ValidYN = CASE WHEN sub.AssignmentID IS NULL THEN 1 ELSE 0 END
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment] A
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] W ON W.InstanceID = A.InstanceID AND W.VersionID = A.VersionID AND W.WorkflowID = A.WorkflowID AND W.SelectYN <> 0 AND W.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL ON AOL.InstanceID = A.InstanceID AND AOL.VersionID = A.VersionID AND AOL.AssignmentID = A.AssignmentID AND AOL.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow_OrganizationLevel] WFOL ON WFOL.InstanceID = A.InstanceID AND WFOL.VersionID = A.VersionID AND WFOL.WorkflowID = A.WorkflowID AND WFOL.OrganizationLevelNo = AOL.OrganizationLevelNo
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.InstanceID = A.InstanceID AND OP.VersionID = A.VersionID AND OP.OrganizationPositionID = AOL.OrganizationPositionID AND OP.OrganizationLevelNo = AOL.OrganizationLevelNo AND OP.DeletedID IS NULL AND (OP.OrganizationPositionID = @ActingAs OR @ActingAs IS NULL)
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OH ON OH.InstanceID = A.InstanceID AND OH.VersionID = A.VersionID AND OH.OrganizationHierarchyID = OP.OrganizationHierarchyID AND OH.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.InstanceID = A.InstanceID AND OPU.VersionID = A.VersionID AND OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.UserID = @UserID AND OPU.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Scenario] S ON S.InstanceID = A.InstanceID AND S.VersionID = A.VersionID AND S.ScenarioID = W.ScenarioID AND S.SelectYN <> 0 AND S.DeletedID IS NULL
					INNER JOIN [ScenarioType] ST ON ST.ScenarioTypeID = S.ScenarioTypeID
					LEFT JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPUR ON OPUR.InstanceID = A.InstanceID AND OPUR.VersionID = A.VersionID AND OPUR.OrganizationPositionID = OP.OrganizationPositionID AND OPUR.DelegateYN = 0
					LEFT JOIN [User] UR ON UR.UserID = OPUR.UserID-- AND UR.DeletedID IS NULL
					LEFT JOIN (SELECT DISTINCT AssignmentID FROM #MissingDimension) sub ON sub.AssignmentID = A.AssignmentID
				WHERE
					A.InstanceID = @InstanceID AND
					A.VersionID = @VersionID AND
					(A.WorkflowID = @WorkflowID OR @WorkflowID IS NULL) AND
					(A.AssignmentID = @AssignmentID OR @AssignmentID IS NULL) AND
					A.SelectYN <> 0 AND
					A.DeletedID IS NULL AND
					ISNULL(AOL.LevelInWorkflowYN, WFOL.LevelInWorkflowYN) <> 0 AND
					UR.DeletedID IS NULL
				ORDER BY
					A.AssignmentID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 2, AssignmentRow'
		IF @ResultTypeBM & 2 > 0  --AssignmentRow
			BEGIN
				--Return rows
				SELECT DISTINCT
					ResultTypeBM = 2,
					[AssignmentID],
					[DimensionID],
					[DimensionName],
					[DimensionMemberKey] = [Dimension_MemberKey]
				FROM
					#AssignmentRow AR
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] W ON W.WorkflowID = AR.WorkflowID AND W.SelectYN <> 0 AND W.DeletedID IS NULL
				ORDER BY
					[AssignmentID],
					[DimensionID]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 4, Valid assignments per user'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 4,
					A.AssignmentID,
					A.AssignmentName,
					A.OrganizationPositionID,
					OP.OrganizationPositionName,
					OP.OrganizationLevelNo,
					OPU.UserID,
					OPU.DelegateYN
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment] A
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL ON AOL.InstanceID = A.InstanceID AND AOL.VersionID = A.VersionID AND AOL.AssignmentID = A.AssignmentID AND AOL.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.InstanceID = A.InstanceID AND OP.VersionID = A.VersionID AND OP.OrganizationPositionID = AOL.OrganizationPositionID AND OP.OrganizationLevelNo = AOL.OrganizationLevelNo AND OP.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.InstanceID = A.InstanceID AND OPU.VersionID = A.VersionID AND OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.UserID = @UserID AND OPU.DeletedID IS NULL
				WHERE
					A.InstanceID = @InstanceID AND
					A.VersionID = @VersionID AND
					A.SelectYN <> 0 AND
					A.DeletedID IS NULL AND
					(A.[WorkflowID] = @WorkflowID OR @WorkflowID IS NULL) AND
					(A.[AssignmentID] = @AssignmentID OR @AssignmentID IS NULL)
				ORDER BY
					A.AssignmentID,
					OP.OrganizationLevelNo DESC,
					OPU.DelegateYN

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 8, Old design of ResultTypeBM = 1. AssignedTo (all assigned-to’s and delegates)'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 8,
					A.WorkflowID,
					W.WorkflowName,
					W.InitialWorkflowStateID,
					A.AssignmentID,
					A.AssignmentName,
					A.OrganizationPositionID,
					OP.OrganizationPositionName,
					OP.OrganizationPositionDescription,
					OP.OrganizationLevelNo,
					OL.OrganizationLevelName,
					OH.LinkedDimensionID,
					LinkedDimensionName = D.DimensionName,
					OP.LinkedDimension_MemberKey,
					ExpectedDate = ISNULL(AOL.ExpectedDate, WFOL.ExpectedDate),
					ExpectedDateInheritedYN = CASE WHEN AOL.ExpectedDate IS NULL THEN 1 ELSE 0 END,
					ActionDescription = ISNULL(AOL.ActionDescription, WFOL.ActionDescription),
					ActionDescriptionInheritedYN = CASE WHEN AOL.ActionDescription IS NULL THEN 1 ELSE 0 END,
					OPU.UserID,
					U.UserNameDisplay,
					OPU.DelegateYN,
					OPAssignedUserID = OPUR.UserID,
					OPAssignedUserNameDisplay = UR.UserNameDisplay, 

					WriteYN = CONVERT(bit, 1), -- Should be implemented "Are there any fact table cells that are open for input?"
					-- Assignment - Fact - WorkflowID - WorkflowAccess... - Level - Current user
					WorkflowActionYN = CONVERT(bit, 1), -- should be implemented "Are there any workflow state changes that could be executed?"
					-- Store in OrganizationAssignmentLevel?
					GridID = ISNULL(AOL.GridID, A.GridID),
					A.DataClassID,
					S.ClosedMonth,
					ST.LiveYN,
					TimeFrom = CASE WHEN ST.LiveYN <> 0 THEN NULL ELSE W.TimeFrom END,
					TimeTo = CASE WHEN ST.LiveYN <> 0 THEN NULL ELSE W.TimeTo END,
					TimeOffsetFrom = CASE WHEN ST.LiveYN <> 0 THEN W.TimeOffsetFrom ELSE NULL END,
					TimeOffsetTo = CASE WHEN ST.LiveYN <> 0 THEN W.TimeOffsetTo ELSE NULL END,
					Time_MemberKey = [dbo].[GetTime_MemberKey] (ST.LiveYN, S.ClosedMonth, W.TimeFrom, W.TimeTo, W.TimeOffsetFrom, W.TimeOffsetTo),
					ValidYN = CASE WHEN sub.AssignmentID IS NULL THEN 1 ELSE 0 END
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment] A
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] W ON W.InstanceID = A.InstanceID AND W.VersionID = A.VersionID AND W.WorkflowID = A.WorkflowID AND W.SelectYN <> 0 AND W.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL ON AOL.InstanceID = A.InstanceID AND AOL.VersionID = A.VersionID AND AOL.AssignmentID = A.AssignmentID AND AOL.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow_OrganizationLevel] WFOL ON WFOL.InstanceID = A.InstanceID AND WFOL.VersionID = A.VersionID AND WFOL.WorkflowID = A.WorkflowID AND WFOL.OrganizationLevelNo = AOL.OrganizationLevelNo
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.InstanceID = A.InstanceID AND OP.VersionID = A.VersionID AND OP.OrganizationPositionID = AOL.OrganizationPositionID AND OP.OrganizationLevelNo = AOL.OrganizationLevelNo AND OP.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OH ON OH.InstanceID = A.InstanceID AND OH.VersionID = A.VersionID AND OH.OrganizationHierarchyID = OP.OrganizationHierarchyID AND OH.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.InstanceID = A.InstanceID AND OPU.VersionID = A.VersionID AND OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.UserID = @UserID AND OPU.DeletedID IS NULL
					INNER JOIN [User] U ON U.UserID = OPU.UserID AND U.SelectYN <> 0 AND U.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Scenario] S ON S.InstanceID = A.InstanceID AND S.VersionID = A.VersionID AND S.ScenarioID = W.ScenarioID AND S.SelectYN <> 0 AND S.DeletedID IS NULL
					INNER JOIN [ScenarioType] ST ON ST.ScenarioTypeID = S.ScenarioTypeID
					LEFT JOIN [Dimension] D ON D.InstanceID IN (0, A.InstanceID) AND D.DimensionID = OH.LinkedDimensionID
					LEFT JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationLevel] OL ON OL.InstanceID = A.InstanceID AND OL.VersionID = A.VersionID AND OL.OrganizationHierarchyID = OP.OrganizationHierarchyID AND OL.OrganizationLevelNo = AOL.OrganizationLevelNo --OP.OrganizationLevelNo
					LEFT JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPUR ON OPUR.InstanceID = A.InstanceID AND OPUR.VersionID = A.VersionID AND OPUR.OrganizationPositionID = OP.OrganizationPositionID AND OPUR.DelegateYN = 0
					LEFT JOIN [User] UR ON UR.UserID = OPUR.UserID AND UR.DeletedID IS NULL
					LEFT JOIN (SELECT DISTINCT AssignmentID FROM #MissingDimension) sub ON sub.AssignmentID = A.AssignmentID
				WHERE
					A.InstanceID = @InstanceID AND
					A.VersionID = @VersionID AND
					(A.WorkflowID = @WorkflowID OR @WorkflowID IS NULL) AND
					(A.AssignmentID = @AssignmentID OR @AssignmentID IS NULL) AND
					A.SelectYN <> 0 AND
					A.DeletedID IS NULL AND
					ISNULL(AOL.LevelInWorkflowYN, WFOL.LevelInWorkflowYN) <> 0
				ORDER BY
					A.AssignmentID,
					OP.OrganizationLevelNo DESC,
					OPU.DelegateYN

				SET @Selected = @Selected + @@ROWCOUNT
			END


	SET @Step = 'Drop temp tables'
		DROP TABLE #AssignmentRow
		DROP TABLE #MissingDimension

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
