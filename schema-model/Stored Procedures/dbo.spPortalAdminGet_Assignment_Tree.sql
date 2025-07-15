SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Assignment_Tree]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@WorkflowID int = NULL,
	@ResultTypeBM int = 3,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000100,
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
-- not valid
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"Debug","TValue":"1"},
{"TKey":"InstanceID","TValue":"638"},{"TKey":"UserID","TValue":"10382"},
{"TKey":"VersionID","TValue":"1093"},{"TKey":"WorkflowID","TValue":"4955"}
]', @ProcedureName='spPortalAdminGet_Assignment_Tree'


EXEC [spPortalAdminGet_Assignment_Tree] @InstanceID = 304, @UserID = 1004, @WorkFlowID = 1001
EXEC [spPortalAdminGet_Assignment_Tree] @UserID = 2120, @InstanceID = 114, @VersionID = 1004, @WorkFlowID = 1019

Assignments (from [spPortalAdminGet_Assignment_Tree])
- SP will return 2 result sets
  - Assignment list - list of all assignments within workflow
  - AssignedTo - lists all AssignedTo's by assignment - meant to be leaves in tree

EXEC [spPortalAdminGet_Assignment_Tree] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@OrganizationLevelNo int,

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
	@Version nvarchar(50) = '2.1.2.2197'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return Assignment tree',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'New template. DB-105: Not include dimensions where ReportOnlyYN = 1'
		IF @Version = '2.0.3.2151' SET @Description = 'DB-285: @UserDependentYN in sub call changed from true to false'
		IF @Version = '2.1.0.2164' SET @Description = 'DB-603: Modified INSERT query of #MissingDimension table.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added hierarchy columns to temp table #AssignmentRow.'
		IF @Version = '2.1.2.2197' SET @Description = 'DB-1403: Added [Dimension].[SelectYN] and [Dimension].[DeletedID] filters when INSERTing INTO #MissingDimension table. Updated SP to new template.'
		
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

		IF @VersionID IS NULL
			SELECT @VersionID = MAX(VersionID) FROM [Application] WHERE InstanceID = @InstanceID

	SET @Step = 'Get Assignment list'
		IF @ResultTypeBM & 1 > 0 --Assignment list
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

				EXEC spGet_AssignmentRow @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @UserDependentYN = 0

				IF @Debug <> 0 SELECT TempTable = '#AssignmentRow', * FROM #AssignmentRow

				CREATE TABLE #MissingDimension (AssignmentID int, DimensionID int)

				INSERT INTO #MissingDimension (AssignmentID, DimensionID)
				SELECT DISTINCT
					A.AssignmentID,
					DCD.DimensionID
				FROM
					Assignment A
					INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = A.DataClassID
					INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.ReportOnlyYN = 0 AND D.SelectYN <> 0 AND D.DeletedID IS NULL
				WHERE
					A.WorkflowID = @WorkflowID AND
					NOT EXISTS (SELECT 1 FROM (
									SELECT DISTINCT
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
										INNER JOIN Grid_Dimension GD ON GD.InstanceID = @InstanceID AND GD.GridID = A.GridID
									WHERE
										A.WorkflowID = @WorkflowID) sub
								WHERE (sub.AssignmentID = A.AssignmentID OR sub.AssignmentID IS NULL) AND sub.DimensionID = DCD.DimensionID)
								--WHERE sub.AssignmentID = A.AssignmentID AND sub.DimensionID = DCD.DimensionID)

				IF @Debug <> 0 SELECT TempTable = '#MissingDimension', * FROM #MissingDimension

				SELECT
					ResultTypeBM = 1,
					A.AssignmentID,
					A.AssignmentName,
					A.DataClassID,
					DC.DataClassName,
					OP.OrganizationHierarchyID,
					OH.OrganizationHierarchyName,
					A.[Priority],
					ValidYN = CASE WHEN sub.AssignmentID IS NULL THEN 1 ELSE 0 END
				FROM 
					Assignment A
					INNER JOIN DataClass DC ON DC.DataClassID = A.DataClassID AND DC.DeletedID IS NULL
					INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NULL
					INNER JOIN OrganizationHierarchy OH ON OH.OrganizationHierarchyID = OP.OrganizationHierarchyID AND OH.DeletedID IS NULL
					LEFT JOIN (SELECT DISTINCT AssignmentID FROM #MissingDimension) sub ON sub.AssignmentID = A.AssignmentID
				WHERE
					A.InstanceID = @InstanceID AND
					A.VersionID = @VersionID AND
					A.WorkflowID = @WorkflowID AND
					A.DeletedID IS NULL
				ORDER BY
					A.[Priority],
					A.AssignmentID,
					OP.OrganizationLevelNo DESC

				DROP TABLE #AssignmentRow
				DROP TABLE #MissingDimension
			END

	SET @Step = 'Loop to fill a temp table with assignments on all levels'
		IF @ResultTypeBM & 2 > 0 --Loop to fill a temp table with assignments on all levels
			BEGIN
				SELECT 
					A.AssignmentID,
					OP.OrganizationPositionID,
					OP.OrganizationLevelNo,
					OP.ParentOrganizationPositionID
				INTO
					#OP_AssignmentTree
				FROM
					Assignment A
					INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NULL
				WHERE
					A.InstanceID = @InstanceID AND
					A.VersionID = @VersionID AND
					A.WorkflowID = @WorkflowID AND
					A.DeletedID IS NULL

				SET @OrganizationLevelNo = (SELECT MAX(OrganizationLevelNo) FROM #OP_AssignmentTree)
				IF @Debug <> 0 SELECT OrganizationLevelNo = @OrganizationLevelNo
				WHILE @OrganizationLevelNo > 1
					BEGIN
						IF @Debug <> 0 
							SELECT 
								OPAT.AssignmentID,
								OP.OrganizationPositionID,
								OP.OrganizationLevelNo,
								OP.ParentOrganizationPositionID 
							FROM
								#OP_AssignmentTree OPAT
								INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = OPAT.ParentOrganizationPositionID AND OP.DeletedID IS NULL
							WHERE
								OPAT.OrganizationLevelNo = @OrganizationLevelNo

						INSERT INTO #OP_AssignmentTree
							(
							AssignmentID,
							OrganizationPositionID,
							OrganizationLevelNo,
							ParentOrganizationPositionID
							)
						SELECT 
							OPAT.AssignmentID,
							OP.OrganizationPositionID,
							OP.OrganizationLevelNo,
							OP.ParentOrganizationPositionID 
						FROM
							#OP_AssignmentTree OPAT
							INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = OPAT.ParentOrganizationPositionID AND OP.DeletedID IS NULL
						WHERE
							OPAT.OrganizationLevelNo = @OrganizationLevelNo

						SET @OrganizationLevelNo = @OrganizationLevelNo - 1
						IF @Debug <> 0 SELECT OrganizationLevelNo = @OrganizationLevelNo
					END

					IF @Debug <> 0 SELECT * FROM #OP_AssignmentTree ORDER BY OrganizationLevelNo, AssignmentID

				--AssignedTo (all assigned-to’s and delegates)
				SELECT 
					ResultTypeBM = 2,
					A.AssignmentID,
					A.OrganizationPositionID,
					OP.OrganizationPositionName,
					OP.OrganizationPositionDescription,

					OP.OrganizationLevelNo,
					--OrganizationLevelNo = ISNULL(AOL.OrganizationLevelNo, WFOL.OrganizationLevelNo),
					OL.OrganizationLevelName,
	
				--	LevelInWorkflowYN = ISNULL(AOL.LevelInWorkflowYN, WFOL.LevelInWorkflowYN),
					ExpectedDate = ISNULL(AOL.ExpectedDate, WFOL.ExpectedDate),
					ExpectedDate_InheritedYN = CASE WHEN AOL.ExpectedDate IS NULL THEN 1 ELSE 0 END,
					ActionDescription = ISNULL(AOL.ActionDescription, WFOL.ActionDescription),
					ActionDescription_InheritedYN = CASE WHEN AOL.ActionDescription IS NULL THEN 1 ELSE 0 END,
					OPU.UserID,
					U.UserNameDisplay,
					OPU.DelegateYN,
					A.[Priority]
				FROM
					Assignment A
	
					INNER JOIN Workflow_OrganizationLevel WFOL ON WFOL.WorkflowID = A.WorkflowID
					LEFT JOIN Assignment_OrganizationLevel AOL ON AOL.AssignmentID = A.AssignmentID AND AOL.OrganizationLevelNo = WFOL.OrganizationLevelNo
				--	INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NULL
					INNER JOIN #OP_AssignmentTree OPAT ON OPAT.AssignmentID = A.AssignmentID AND OPAT.OrganizationLevelNo = ISNULL(AOL.OrganizationLevelNo, WFOL.OrganizationLevelNo)
					INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = OPAT.OrganizationPositionID AND OP.OrganizationLevelNo = ISNULL(AOL.OrganizationLevelNo, WFOL.OrganizationLevelNo) AND OP.DeletedID IS NULL
					LEFT JOIN OrganizationPosition_User OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID --AND OPU.DelegateYN <> 0
					LEFT JOIN [User] U ON U.UserID = OPU.UserID AND U.DeletedID IS NULL
	
					LEFT JOIN OrganizationLevel OL ON OL.OrganizationLevelNo = ISNULL(AOL.OrganizationLevelNo, WFOL.OrganizationLevelNo) --OP.OrganizationLevelNo
				WHERE
					A.InstanceID = @InstanceID AND
					A.VersionID = @VersionID AND
					A.WorkflowID = @WorkflowID AND
					A.DeletedID IS NULL AND
					ISNULL(AOL.LevelInWorkflowYN, WFOL.LevelInWorkflowYN) <> 0
				ORDER BY
					A.[Priority],
					A.AssignmentID,
					OP.OrganizationLevelNo DESC,
					OPU.DelegateYN

				DROP TABLE #OP_AssignmentTree
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
