SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_OrganizationLevelNo]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@OrganizationPositionID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000313,
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
	@ProcedureName = 'spSet_OrganizationLevelNo',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "114"},
		{"TKey" : "VersionID",  "TValue": "1004"},
		{"TKey" : "OrganizationPositionID",  "TValue": "2278"}
		]'

EXEC [spSet_OrganizationLevelNo] @UserID=-10, @InstanceID=114, @VersionID=1004, @OrganizationPositionID=1113, @Debug=1
EXEC [spSet_OrganizationLevelNo] @UserID=-10, @InstanceID=114, @VersionID=1004, @OrganizationPositionID=2276, @Debug=1
EXEC [spSet_OrganizationLevelNo] @UserID=-10, @InstanceID=114, @VersionID=1004, @OrganizationPositionID=2278, @Debug=1
EXEC [spSet_OrganizationLevelNo] @UserID=2120, @InstanceID=114, @VersionID=1004, @OrganizationPositionID=2273, @Debug=1

EXEC [spSet_OrganizationLevelNo] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@OrganizationHierarchyID int,
	@ParentOrganizationPositionID int,
	@OrganizationLevelNo int,
	@DeletedID int,
	@DeleteInfo nvarchar(255),

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
	@Version nvarchar(50) = '2.0.3.2152'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set correct number of Organization levels, set correct OrganizationLevelNo for OrganizationPositions.',
			@MandatoryParameter = 'OrganizationPositionID'

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'Handle VersionID.'

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

		SELECT
			@OrganizationHierarchyID = OrganizationHierarchyID,
			@ParentOrganizationPositionID = ParentOrganizationPositionID,
			@DeletedID = DeletedID
		FROM
			OrganizationPosition
		WHERE
			OrganizationPositionID = @OrganizationPositionID

		IF @Debug <> 0
			SELECT
				UserID = @UserID,
				InstanceID = @InstanceID,
				VersionID = @VersionID,
				OrganizationPositionID = @OrganizationPositionID,
				OrganizationHierarchyID = @OrganizationHierarchyID,
				ParentOrganizationPositionID = @ParentOrganizationPositionID

	SET @Step = 'Check OrganizationPositionID is not deleted'
		IF @DeletedID IS NOT NULL
			BEGIN
				SELECT 
					@DeleteInfo = U.UserName + ', ' + CONVERT(nvarchar(50), DI.DeletedDateTime)
				FROM
					[DeletedItem] DI
					INNER JOIN [User] U ON U.UserID = DI.UserID

				SET @Message = 'OrganizationPositionID = ' + CONVERT(nvarchar(10), @OrganizationPositionID) + ' was deleted by ' + @DeleteInfo
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Check OrganizationPositionID <> ParentOrganizationPositionID'
		IF @OrganizationPositionID = @ParentOrganizationPositionID
			BEGIN
				SET @Message = 'ParentOrganizationPositionID can not be the same as OrganizationPositionID, (' + CONVERT(nvarchar(10), @OrganizationPositionID) + ').'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Get current @OrganizationLevelNo'
		SELECT @OrganizationLevelNo = [dbo].[GetOrganizationLevelNo] (@OrganizationPositionID)
		IF @Debug <> 0 SELECT OrganizationLevelNo = @OrganizationLevelNo

	SET @Step = 'Create temp table #OrganizationPosition'
		CREATE TABLE #OrganizationPosition
			(
			OrganizationPositionID int,
			OrganizationLevelNo int,
			CheckedYN bit
			)

		INSERT INTO #OrganizationPosition
			(
			OrganizationPositionID,
			OrganizationLevelNo,
			CheckedYN
			)
		SELECT
			OrganizationPositionID = @OrganizationPositionID,
			OrganizationLevelNo = @OrganizationLevelNo,
			CheckedYN = 0

	SET @Step = 'Loop and fill temp table #OrganizationPosition'
		WHILE (SELECT COUNT(1) FROM #OrganizationPosition WHERE CheckedYN = 0) > 0
			BEGIN
				SELECT
					@OrganizationPositionID = MIN(OrganizationPositionID)
				FROM
					#OrganizationPosition
				WHERE
					CheckedYN = 0

				SELECT
					@OrganizationLevelNo = OrganizationLevelNo
				FROM
					#OrganizationPosition
				WHERE
					OrganizationPositionID = @OrganizationPositionID

				INSERT INTO #OrganizationPosition
					(
					OrganizationPositionID,
					OrganizationLevelNo,
					CheckedYN
					)
				SELECT
					OrganizationPositionID = OrganizationPositionID,
					OrganizationLevelNo = @OrganizationLevelNo + 1,
					CheckedYN = 0
				FROM
					OrganizationPosition
				WHERE
					ParentOrganizationPositionID = @OrganizationPositionID AND
					OrganizationHierarchyID = @OrganizationHierarchyID AND
					DeletedID IS NULL

				UPDATE OP
				SET
					CheckedYN = 1
				FROM
					#OrganizationPosition OP
				WHERE
					OrganizationPositionID = @OrganizationPositionID
			END

		IF @Debug <> 0 SELECT TempTable = '#OrganizationPosition', * FROM #OrganizationPosition ORDER BY OrganizationLevelNo, OrganizationPositionID

	SET @Step = 'Insert new rows into table OrganizationLevel'
		IF	(SELECT MAX(OrganizationLevelNo) FROM OrganizationLevel WHERE OrganizationHierarchyID = @OrganizationHierarchyID) < (SELECT MAX(OrganizationLevelNo) FROM #OrganizationPosition) OR 
			(SELECT COUNT(1) FROM OrganizationLevel WHERE OrganizationHierarchyID = @OrganizationHierarchyID) = 0
			BEGIN
				INSERT INTO pcINTEGRATOR_Data..OrganizationLevel
					(
					InstanceID,
					VersionID,
					OrganizationHierarchyID,
					OrganizationLevelNo,
					OrganizationLevelName
					)
				SELECT DISTINCT
					InstanceID = @InstanceID,
					VersionID = @VersionID,
					OrganizationHierarchyID = @OrganizationHierarchyID,
					OrganizationLevelNo = OP.OrganizationLevelNo,
					OrganizationLevelName = 'Level ' + CONVERT(nvarchar(10), OrganizationLevelNo)
				FROM
					#OrganizationPosition OP
				WHERE
					NOT EXISTS (SELECT 1 FROM OrganizationLevel OL WHERE OL.OrganizationHierarchyID = @OrganizationHierarchyID AND OL.OrganizationLevelNo = OP.OrganizationLevelNo)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Update table OrganizationPosition'
		UPDATE OP
		SET
			OrganizationLevelNo = OP#.OrganizationLevelNo
		FROM
			pcINTEGRATOR_Data..OrganizationPosition OP
			INNER JOIN #OrganizationPosition OP# ON OP#.OrganizationPositionID = OP.OrganizationPositionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert new rows into Workflow_OrganizationLevel'
		INSERT INTO pcINTEGRATOR_Data..[Workflow_OrganizationLevel]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[OrganizationLevelNo],
			[LevelInWorkflowYN],
			[ExpectedDate],
			[ActionDescription]
			)
		SELECT DISTINCT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowID] = A.[WorkflowID],
			[OrganizationLevelNo] = OL.[OrganizationLevelNo],
			[LevelInWorkflowYN] = 0,
			[ExpectedDate] = GetDate(),
			[ActionDescription] = ''
		FROM
			pcINTEGRATOR_Data..OrganizationLevel OL
			INNER JOIN pcINTEGRATOR_Data..OrganizationPosition OP ON OP.OrganizationHierarchyID = OL.OrganizationHierarchyID
			INNER JOIN pcINTEGRATOR_Data..Assignment A ON A.OrganizationPositionID = OP.OrganizationPositionID
		WHERE
			OL.OrganizationHierarchyID = @OrganizationHierarchyID AND
			NOT EXISTS (SELECT 1 FROM [Workflow_OrganizationLevel] WOL WHERE WOL.WorkflowID = A.[WorkflowID] AND WOL.[OrganizationLevelNo] = OL.[OrganizationLevelNo])

		SET @Inserted = @Inserted + @@ROWCOUNT

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
