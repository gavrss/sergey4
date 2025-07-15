SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Workflow_Tree]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@OrganizationHierarchyID int = NULL,
	@WorkFlowID int = NULL,
	@ResultTypeBM int = 7,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000111,
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
	@ProcedureName = 'spPortalAdminGet_Workflow_Tree',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"Debug","TValue":"1"},
{"TKey":"InstanceID","TValue":"-1830"},{"TKey":"UserID","TValue":"-10"},{"TKey":"OrganizationHierarchyID","TValue":"15434"},
{"TKey":"VersionID","TValue":"-1830"}, {"TKey":"ResultTypeBM","TValue":"1"}]', @ProcedureName='spPortalAdminGet_Workflow_Tree'

EXEC [spPortalAdminGet_Workflow_Tree] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spPortalAdminGet_Workflow_Tree] @UserID = 2120, @InstanceID = 114, @VersionID = 1004,  @OrganizationHierarchyID = 1009, @WorkFlowID = 1019, @Debug = 1
EXEC [spPortalAdminGet_Workflow_Tree] @InstanceID='114', @WorkFlowID='1019', @OrganizationHierarchyID='1009', @UserID='2120', @VersionID='1004', @ResultTypeBM = 4, @Debug = 1

EXEC [spPortalAdminGet_Workflow_Tree] @InstanceID = -1125, @VersionID=-1125, @UserID = 7273, @OrganizationHierarchyID = 4330, @WorkFlowID = 4683, @Debug=1
EXEC [spPortalAdminGet_Workflow_Tree] @UserID='-1435', @InstanceID='-1184', @VersionID = -1122, @WorkFlowID='2179', @OrganizationHierarchyID='1077', @Debug = 1

/*
Returns 3 resultsets to construct Workflow tree.
The first resultset gives the basic organization tree.
Resultset 2 and 3 gives delegates and assignments to be placed into the tree.
*/

EXEC [spPortalAdminGet_Workflow_Tree] @GetVersion = 1
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
	@Version nvarchar(50) = '2.1.2.2198'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns 3 resultsets to construct Workflow tree',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Updated template. Added InstanceID and VersionID filtering on all JOINS.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-105: Not include dimensions where ReportOnlyYN = 1'
		IF @Version = '2.1.0.2164' SET @Description = 'DB-603: Modified INSERT query of #MissingDimension table.'
		IF @Version = '2.1.2.2179' SET @Description = 'Filter temp table #MissingDimension with Dimension properties SelectYN <> 0 AND DeletedID IS NULL'
		IF @Version = '2.1.2.2198' SET @Description = 'DB-1441: Added [LinkedDimension_MemberKey] column in @ResultTypeBM=1.'

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

	SET @Step = 'Basic organization tree'
		IF @ResultTypeBM & 1 > 0 --Basic organization tree
			BEGIN
				SELECT 
					ResultTypeBM = 1,
					OP.[OrganizationPositionID],
					[OrganizationPositionName],
					[OrganizationPositionDescription],
					[ParentOrganizationPositionID],
					[OrganizationLevelNo],
					[LinkedDimension_MemberKey],
					[SortOrder],
					UserID = MAX(OPU.UserID),
					UserNameDisplay = MAX(U.UserNameDisplay)
				FROM
					OrganizationPosition OP
					LEFT JOIN OrganizationPosition_User OPU ON OPU.InstanceID = OP.InstanceID AND OPU.VersionID = OP.VersionID AND OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.DelegateYN = 0
					LEFT JOIN [User] U ON U.UserID = OPU.UserID AND U.DeletedID IS NULL
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID AND
					OP.OrganizationHierarchyID = @OrganizationHierarchyID AND
					OP.DeletedID IS NULL
				GROUP BY
					OP.[OrganizationPositionID],
					[OrganizationPositionName],
					[OrganizationPositionDescription],
					[ParentOrganizationPositionID],
					[OrganizationLevelNo],
					[LinkedDimension_MemberKey],
					[SortOrder]
			END

	SET @Step = 'Delegated users'

		IF @ResultTypeBM & 2 > 0 --Delegated users
			BEGIN
				SELECT 
					ResultTypeBM = 2,
					OPU.[OrganizationPositionID],
					OPU.[UserID],
					U.UserNameDisplay
				FROM
					OrganizationPosition OP
					INNER JOIN OrganizationPosition_User OPU ON OPU.InstanceID = OP.InstanceID AND OPU.VersionID = OP.VersionID AND OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.DelegateYN <> 0
					INNER JOIN [User] U ON U.UserID = OPU.UserID AND U.DeletedID IS NULL
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID AND
					OP.OrganizationHierarchyID = @OrganizationHierarchyID AND
					OP.DeletedID IS NULL
			END

	SET @Step = 'Assignment'

		IF @ResultTypeBM & 4 > 0 --Assignment
			BEGIN
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

				IF @Debug <> 0 SELECT UserID = @UserID, InstanceID = @InstanceID, VersionID = @VersionID, WorkflowID = @WorkflowID

				EXEC spGet_AssignmentRow @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @WorkflowID = @WorkflowID, @UserDependentYN = 0

				IF @Debug <> 0 SELECT TempTable = '#AssignmentRow', * FROM #AssignmentRow

				IF @Debug <> 0
					BEGIN
						SELECT DISTINCT
							SourceType = 'DataClass',
							A.AssignmentID,
							DCD.DimensionID
						FROM
							Assignment A
							INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = A.InstanceID AND DCD.VersionID = A.VersionID AND DCD.DataClassID = A.DataClassID
						WHERE
							A.InstanceID = @InstanceID AND 
							A.VersionID = @VersionID AND 
							A.WorkflowID = @WorkflowID


						SELECT DISTINCT
							SourceType = 'Assignment',
							AssignmentID,
							DimensionID
						FROM
							#AssignmentRow
						WHERE
							WorkflowID = @WorkflowID

						SELECT DISTINCT
							SourceType = 'Grid',
							A.AssignmentID,
							GD.DimensionID
						FROM
							Assignment A
							INNER JOIN Grid_Dimension GD ON GD.InstanceID = A.InstanceID AND GD.GridID = A.GridID
						WHERE
							A.InstanceID = @InstanceID AND 
							A.VersionID = @VersionID AND
							A.WorkflowID = @WorkflowID
					END

				CREATE TABLE #MissingDimension (AssignmentID int, DimensionID int)

				INSERT INTO #MissingDimension (AssignmentID, DimensionID)
				SELECT DISTINCT
					A.AssignmentID,
					DCD.DimensionID
				FROM
					Assignment A
					INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = A.InstanceID AND DCD.VersionID = A.VersionID AND DCD.DataClassID = A.DataClassID
					INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.ReportOnlyYN = 0 AND D.SelectYN <> 0 AND D.DeletedID IS NULL
				WHERE
					A.InstanceID = @InstanceID AND 
					A.VersionID = @VersionID AND
					A.WorkflowID = @WorkflowID AND
					NOT EXISTS (SELECT 1 FROM (
									SELECT DISTINCT
										AssignmentID,
										DimensionID = -63 --WorkflowState
									FROM
										#AssignmentRow
									WHERE
										WorkflowID = @WorkflowID

									UNION SELECT DISTINCT
										AssignmentID,
										DimensionID
									FROM
										#AssignmentRow
									WHERE
										WorkflowID = @WorkflowID

									UNION SELECT DISTINCT
										AssignmentID,
										DimensionID
									FROM
										#AssignmentRow
									WHERE
										WorkflowID IS NULL AND
										[Source] IN ('Dimension', 'System')

									UNION SELECT DISTINCT
										A.AssignmentID,
										GD.DimensionID
									FROM
										Assignment A
										INNER JOIN Grid_Dimension GD ON GD.InstanceID = A.InstanceID AND GD.GridID = A.GridID
									WHERE
										A.InstanceID = @InstanceID AND 
										A.VersionID = @VersionID AND
										A.WorkflowID = @WorkflowID) sub
								WHERE (sub.AssignmentID = A.AssignmentID OR sub.AssignmentID IS NULL) AND sub.DimensionID = DCD.DimensionID)
								--WHERE sub.AssignmentID = A.AssignmentID AND sub.DimensionID = DCD.DimensionID)

				IF @Debug <> 0 SELECT TempTable = '#MissingDimension', * FROM #MissingDimension

				SELECT 
					ResultTypeBM = 4,
					AOL.[OrganizationPositionID],
					A.AssignmentID,
					A.AssignmentName,
					OrganizationLevelNo = ISNULL(AOL.OrganizationLevelNo, WFOL.OrganizationLevelNo),
					ExpectedDate = ISNULL(AOL.ExpectedDate, WFOL.ExpectedDate),
					ExpectedDate_InheritedYN = CASE WHEN AOL.ExpectedDate IS NULL THEN 1 ELSE 0 END,
					ActionDescription = ISNULL(AOL.ActionDescription, WFOL.ActionDescription),
					ActionDescription_InheritedYN = CASE WHEN AOL.ActionDescription IS NULL THEN 1 ELSE 0 END,
					ValidYN = CASE WHEN sub.AssignmentID IS NULL THEN 1 ELSE 0 END
				FROM
					Assignment A
					INNER JOIN OrganizationPosition OP ON OP.InstanceID = A.InstanceID AND OP.VersionID = A.VersionID AND OP.OrganizationPositionID = A.OrganizationPositionID AND OP.OrganizationHierarchyID = @OrganizationHierarchyID AND OP.DeletedID IS NULL
					INNER JOIN Workflow_OrganizationLevel WFOL ON WFOL.InstanceID = A.InstanceID AND WFOL.VersionID = A.VersionID AND WFOL.WorkflowID = A.WorkflowID
					INNER JOIN Assignment_OrganizationLevel AOL ON AOL.InstanceID = A.InstanceID AND AOL.VersionID = A.VersionID AND AOL.AssignmentID = A.AssignmentID AND AOL.OrganizationLevelNo = WFOL.OrganizationLevelNo --AND AOL.LevelInWorkflowYN <> 0
					LEFT JOIN (SELECT DISTINCT AssignmentID FROM #MissingDimension) sub ON sub.AssignmentID = A.AssignmentID
				WHERE
					A.InstanceID = @InstanceID AND
					A.VersionID = @VersionID AND
					A.WorkflowID = @WorkFlowID AND
					A.DeletedID IS NULL AND
					ISNULL(AOL.LevelInWorkflowYN, WFOL.LevelInWorkflowYN) <> 0
				ORDER BY
					A.[OrganizationPositionID],
					A.AssignmentID,
					ISNULL(AOL.OrganizationLevelNo, WFOL.OrganizationLevelNo)

			DROP TABLE #AssignmentRow
			DROP TABLE #MissingDimension
		END

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
