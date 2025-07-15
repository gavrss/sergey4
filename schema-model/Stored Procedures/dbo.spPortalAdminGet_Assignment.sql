SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Assignment]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignmentID int = NULL,
	@ResultTypeBM int = 31,
		-- 1 = Assignment definition
		-- 2 = Assignment Level definition (1 for each level in Organization hierarchy)
		-- 4 = Workflow rows
		-- 8 = Missing Dimensions connections
		--16 = DataClasses

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000099,
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
	@ProcedureName = 'spPortalAdminGet_Assignment',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "304"},
		{"TKey" : "VersionID",  "TValue": "1013"},
		{"TKey" : "AssignmentID",  "TValue": "9032"}
		]'

EXEC [spPortalAdminGet_Assignment] @UserID = -10, @InstanceID = 304, @VersionID = 1013, @AssignmentID = 9032
EXEC [spPortalAdminGet_Assignment] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @AssignmentID = 12402
EXEC [spPortalAdminGet_Assignment] @UserID = -10, @InstanceID = 304, @VersionID = 1013, @ResultTypeBM = 16

EXEC [spPortalAdminGet_Assignment] @GetVersion = 1
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
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows for Assignment form',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2141' SET @Description = 'Added ResultTypeBM 16.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-105: Not include dimensions where ReportOnlyYN = 1'
		IF @Version = '2.0.2.2150' SET @Description = 'DB-241: Include Assumption DataClasses in ResultTypeBM=16'
		IF @Version = '2.1.0.2157' SET @Description = 'Include FxRate DataClass in ResultTypeBM=16'
		IF @Version = '2.1.2.2179' SET @Description = 'Filter temp table #MissingDimension with Dimension properties SelectYN <> 0 AND DeletedID IS NULL'
		IF @Version = '2.1.2.2196' SET @Description = 'Added hierarchy columns to temp table #AssignmentRow.'

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

	SET @Step = 'Get relevant list of Assignment rows'
		IF @ResultTypeBM & 13 > 0 --Get Assignment rows
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

				EXEC spGet_AssignmentRow @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @AssignmentID = @AssignmentID, @UserDependentYN = 0, @Debug = @Debug

				IF @Debug <> 0 SELECT TempTable = '#AssignmentRow', * FROM #AssignmentRow

				CREATE TABLE #MissingDimension (DimensionID int)

				INSERT INTO #MissingDimension (DimensionID)
				SELECT DISTINCT
					DCD.DimensionID
				FROM
					Assignment A
					INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = A.DataClassID
					INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.ReportOnlyYN = 0 AND D.SelectYN <> 0 AND D.DeletedID IS NULL
				WHERE
					A.AssignmentID = @AssignmentID AND
					NOT EXISTS (SELECT 1 FROM (
									SELECT DISTINCT
										DimensionID = -63 --WorkflowState
									UNION SELECT DISTINCT
										DimensionID
									FROM
										#AssignmentRow
									UNION SELECT DISTINCT
										GD.DimensionID
									FROM
										Assignment A
										INNER JOIN Grid_Dimension GD ON GD.InstanceID = @InstanceID AND GD.GridID = A.GridID
									WHERE
										A.AssignmentID = @AssignmentID) sub
								WHERE sub.DimensionID = DCD.DimensionID)
			END

	SET @Step = 'Assignment definition'
		IF @ResultTypeBM & 1 > 0 --Assignment definition
			BEGIN
				IF @Debug <> 0 
					SELECT TempTable = '#MissingDimension', MD.*, D.DimensionName 
					FROM #MissingDimension MD LEFT JOIN Dimension D ON D.DimensionID = MD.DimensionID

				SELECT DISTINCT
					ResultTypeBM = 1,
					ReadOnlyYN = 0,
					ModelingLockedYN = CONVERT(bit, MAX(CONVERT(int, V.ModelingLockedYN))),
					A.AssignmentID,
					AssignmentName = MAX(A.AssignmentName),
					Comment = MAX(A.Comment),
					OrganizationHierarchyID = MAX(OP.OrganizationHierarchyID), 
					OrganizationHierarchyName = MAX(OH.OrganizationHierarchyName),
					OrganizationPositionID = MAX(OP.OrganizationPositionID),
					OrganizationPositionName = MAX(OP.OrganizationPositionName),
					UserID = MAX(OPU.UserID),
					UserNameDisplay = MAX(U.UserNameDisplay),
					DataClassID = MAX(A.DataClassID),
					VersionID = MAX(A.VersionID),
					WorkflowID = MAX(A.WorkflowID),
					GridID = MAX(A.GridID),
					[Priority] = MAX(A.[Priority]),
					NoOfLevels = MAX(OL.OrganizationLevelNo),
					ValidYN = CASE WHEN (SELECT COUNT(1) FROM #MissingDimension) > 0 THEN 0 ELSE 1 END
				FROM
					Assignment A
					INNER JOIN [Version] V ON V.VersionID = A.VersionID
					INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NULL
					INNER JOIN OrganizationHierarchy OH ON OH.OrganizationHierarchyID = OP.OrganizationHierarchyID
					LEFT JOIN OrganizationPosition_User OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.DelegateYN = 0
					LEFT JOIN [User] U ON U.UserID = OPU.UserID
					LEFT JOIN OrganizationLevel OL ON OL.OrganizationHierarchyID = OP.OrganizationHierarchyID
				WHERE
					A.[InstanceID] = @InstanceID AND
					A.[VersionID] = @VersionID AND
					A.[AssignmentID] = @AssignmentID AND
					A.[DeletedID] IS NULL
				GROUP BY
					A.AssignmentID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Assignment Level definition (1 for each level in Organization hierarchy)'
		IF @ResultTypeBM & 2 > 0 --Assignment Level definition (1 for each level in Organization hierarchy)
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 2,
					ReadOnlyYN = 0,
					OL.OrganizationLevelNo,
					OL.OrganizationLevelName,
					LevelInWorkflowYN = COALESCE(AOL.LevelInWorkflowYN, WFOL.LevelInWorkflowYN, 0),
					ExpectedDate = ISNULL(AOL.ExpectedDate, WFOL.ExpectedDate),
					ExpectedDate_InheritedYN = CASE WHEN AOL.ExpectedDate IS NULL THEN 1 ELSE 0 END,
					ActionDescription = ISNULL(AOL.ActionDescription, WFOL.ActionDescription),
					ActionDescription_InheritedYN = CASE WHEN AOL.ActionDescription IS NULL THEN 1 ELSE 0 END
				FROM
					Assignment A
					INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = A.OrganizationPositionID
					INNER JOIN OrganizationHierarchy OH ON OH.OrganizationHierarchyID = OP.OrganizationHierarchyID
					INNER JOIN OrganizationLevel OL ON OL.OrganizationHierarchyID = OP.OrganizationHierarchyID
					LEFT JOIN Workflow_OrganizationLevel WFOL ON WFOL.WorkflowID = A.WorkflowID AND WFOL.OrganizationLevelNo = OL.OrganizationLevelNo
					LEFT JOIN Assignment_OrganizationLevel AOL ON AOL.AssignmentID = A.AssignmentID AND AOL.OrganizationLevelNo = OL.OrganizationLevelNo
				WHERE
					A.[InstanceID] = @InstanceID AND
					A.[VersionID] = @VersionID AND
					A.[AssignmentID] = @AssignmentID AND
					A.[DeletedID] IS NULL
				ORDER BY
					OL.OrganizationLevelNo DESC

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Workflow rows'
		IF @ResultTypeBM & 4 > 0 --Workflow rows
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 4,
					ReadOnlyYN = 0,
					[DimensionID],
					[DimensionName],
					[Dimension_MemberKey],
					[CogentYN],
					Inherited_WorkflowRowYN = CASE WHEN [Source] = 'Assignment' THEN 0 ELSE 1 END,
					InheritedFrom = [Source]
				FROM
					#AssignmentRow

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Missing Dimensions'
		IF @ResultTypeBM & 8 > 0 --Missing Dimensions
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 8,
					D.DimensionID,
					D.DimensionName
				FROM
					Dimension D
					INNER JOIN #MissingDimension MD ON MD.DimensionID = D.DimensionID
				WHERE
					D.SelectYN <> 0 AND
					D.DeletedID IS NULL

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'DataClassCB'
		IF @ResultTypeBM & 16 > 0 --DataClassCB
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 16,
					DC.DataClassID,
					DataClassName,
					DataClassDescription
				FROM
					[DataClass] DC
				WHERE
					DC.[InstanceID] = @InstanceID AND
					DC.[VersionID] = @VersionID AND
					DC.[DataClassTypeID] IN (-1, -3, -6) AND
					DC.[SelectYN] <> 0
				ORDER BY
					DC.DataClassName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		IF @ResultTypeBM & 13 > 0 
			BEGIN
				DROP TABLE #AssignmentRow
				DROP TABLE #MissingDimension
			END

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
