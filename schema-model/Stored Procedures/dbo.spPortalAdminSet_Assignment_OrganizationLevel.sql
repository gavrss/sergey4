SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Assignment_OrganizationLevel]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000113,
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
	@ProcedureName = 'spPortalAdminSet_Assignment_OrganizationLevel',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

--EXEC spPortalAdminSet_Assignment_OrganizationLevel 	@UserID = -10, @InstanceID = -1089, @VersionID = -1027
--EXEC spPortalAdminSet_Assignment_OrganizationLevel 	@UserID = -10, @InstanceID = 304, @VersionID = 1001, @WorkflowID = 1001, @Debug = 1
--EXEC spPortalAdminSet_Assignment_OrganizationLevel 	@UserID = -10, @InstanceID = 304, @VersionID = 1001, @WorkflowID = 1002, @Debug = 1
--EXEC spPortalAdminSet_Assignment_OrganizationLevel 	@UserID = -10, @InstanceID = 114, @VersionID = 1004, @WorkflowID = 1017, @Debug = 1
--EXEC spPortalAdminSet_Assignment_OrganizationLevel 	@UserID = -10, @InstanceID = 114, @VersionID = 1004, @WorkflowID = 1018, @Debug = 1
--EXEC spPortalAdminSet_Assignment_OrganizationLevel	@UserID = -10, @InstanceID = -1138, @VersionID = -1076, @Debug = 1 --@WorkFlowID = 1083,
--EXEC [spPortalAdminSet_Assignment_OrganizationLevel]  @UserID = 2120, @InstanceID = 114, @VersionID = 1004, @WorkflowID = 1019, @Debug = 1
--EXEC [spPortalAdminSet_Assignment_OrganizationLevel]  @UserID = 2147, @InstanceID = 413, @VersionID = 1008, @WorkflowID = 2174, @Debug = 1
--EXEC [spPortalAdminSet_Assignment_OrganizationLevel]  @UserID ='-1506', @InstanceID = '-1192', @VersionID = '-1130', @Debug = 1

EXEC [spPortalAdminSet_Assignment_OrganizationLevel] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@AssignmentId int,
	@OrganizationLevelNo int,
	@OrganizationPositionID int,
	@ParentOrganizationPositionID int,
	@OrganizationHierarchyID int,

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2172'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set Assignment_OrganizationLevel',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.1.0.2159' SET @Description = 'DB-320: Deallocate Assignment_Cursor if existing.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added filter to exclude deleted Assignments in Assignment_Cursor.'

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

	SET @Step = 'Create OP_Cursor'
		DECLARE OP_Cursor CURSOR FOR
			SELECT DISTINCT
				OrganizationHierarchyID
			FROM
				[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.OrganizationPositionID = OP.OrganizationPositionID AND A.WorkflowID = @WorkflowID
			WHERE
				OP.InstanceID = @InstanceID AND
				OP.VersionID = @VersionID AND
				OP.DeletedID IS NULL

			OPEN OP_Cursor
			FETCH NEXT FROM OP_Cursor INTO @OrganizationHierarchyID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT OrganizationHierarchyID = @OrganizationHierarchyID

					SELECT
						@OrganizationPositionID = OP.[OrganizationPositionID]
					FROM
						[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
					WHERE
						OP.[InstanceID] = @InstanceID AND
						OP.[VersionID] = @VersionID AND
						OP.[OrganizationHierarchyID] = @OrganizationHierarchyID AND
						OP.[ParentOrganizationPositionID] IS NULL AND
						OP.[DeletedID] IS NULL

					EXEC [spSet_OrganizationLevelNo] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @OrganizationPositionID=@OrganizationPositionID

					FETCH NEXT FROM OP_Cursor INTO @OrganizationHierarchyID
				END
		CLOSE OP_Cursor
		DEALLOCATE OP_Cursor


	SET @Step = 'Create OP_Cursor'
		DELETE AOL
		FROM
			[pcINTEGRATOR_Data].[dbo].[Assignment] A
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.OrganizationLevelNo IS NOT NULL
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL ON AOL.AssignmentID = A.AssignmentID
		WHERE
			A.InstanceID = @InstanceID AND
			(A.WorkflowID = @WorkflowID OR @WorkflowID IS NULL)

	SET @Step = 'Create Assignment_Cursor'
		IF CURSOR_STATUS('global','Assignment_Cursor') >= -1 DEALLOCATE Assignment_Cursor
		DECLARE Assignment_Cursor CURSOR FOR

			SELECT 
				A.AssignmentId,
				OP.OrganizationLevelNo,
				A.OrganizationPositionID,
				OP.ParentOrganizationPositionID
			FROM
				[pcINTEGRATOR_Data].[dbo].[Assignment] A
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.OrganizationLevelNo IS NOT NULL AND OP.DeletedID IS NULL
			WHERE
				A.InstanceID = @InstanceID AND
				A.VersionID = @VersionID AND 
				(A.WorkflowID = @WorkflowID OR @WorkflowID IS NULL) AND
                A.DeletedID IS NULL
			ORDER BY
				AssignmentId

			OPEN Assignment_Cursor
			FETCH NEXT FROM Assignment_Cursor INTO @AssignmentId, @OrganizationLevelNo, @OrganizationPositionID, @ParentOrganizationPositionID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT AssignmentId = @AssignmentId, OrganizationLevelNo = @OrganizationLevelNo, OrganizationPositionID = @OrganizationPositionID, ParentOrganizationPositionID = @ParentOrganizationPositionID

					-----------------Temp
					UPDATE [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel]
					SET
						[OrganizationPositionID] = @OrganizationPositionID
					WHERE
						[AssignmentID] = @AssignmentId AND
						[OrganizationLevelNo] = @OrganizationLevelNo
					-----------------

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel]
						(
						[InstanceID],
						[VersionID],
						[AssignmentID],
						[OrganizationLevelNo],
						[OrganizationPositionID],
						[LevelInWorkflowYN]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[AssignmentID] = @AssignmentId,
						[OrganizationLevelNo] = @OrganizationLevelNo,
						[OrganizationPositionID] = @OrganizationPositionID,
						[LevelInWorkflowYN] = 1
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL WHERE AOL.AssignmentID = @AssignmentId AND AOL.OrganizationLevelNo = @OrganizationLevelNo)


					WHILE @ParentOrganizationPositionID IS NOT NULL
						BEGIN
							SELECT 
								@OrganizationLevelNo = [OrganizationLevelNo],
								@OrganizationPositionID = [OrganizationPositionID],
								@ParentOrganizationPositionID = [ParentOrganizationPositionID]
							FROM
								[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
							WHERE
								OP.OrganizationPositionID = @ParentOrganizationPositionID AND
								OP.DeletedID IS NULL

							IF @@ROWCOUNT = 0 SET @ParentOrganizationPositionID = NULL

							-----------------Temp
							UPDATE [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel]
							SET
								[OrganizationPositionID] = @OrganizationPositionID
							WHERE
								[AssignmentID] = @AssignmentId AND
								[OrganizationLevelNo] = @OrganizationLevelNo
							-----------------

							INSERT INTO [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel]
								(
								[InstanceID],
								[VersionID],
								[AssignmentID],
								[OrganizationLevelNo],
								[OrganizationPositionID],
								[LevelInWorkflowYN]
								)
							SELECT
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[AssignmentID] = @AssignmentId,
								[OrganizationLevelNo] = @OrganizationLevelNo,
								[OrganizationPositionID] = @OrganizationPositionID,
								[LevelInWorkflowYN] = 1
							WHERE
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL WHERE AOL.AssignmentID = @AssignmentId AND AOL.OrganizationLevelNo = @OrganizationLevelNo)

						END
					FETCH NEXT FROM Assignment_Cursor INTO @AssignmentId, @OrganizationLevelNo, @OrganizationPositionID, @ParentOrganizationPositionID
				END

		CLOSE Assignment_Cursor
		DEALLOCATE Assignment_Cursor	

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
