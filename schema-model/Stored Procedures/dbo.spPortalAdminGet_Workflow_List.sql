SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Workflow_List]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000109,
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
	@ProcedureName = 'spPortalAdminGet_Workflow_List',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_Workflow_List] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spPortalAdminGet_Workflow_List] @UserID = 1004, @InstanceID = 304, @VersionID = 1013

EXEC [spPortalAdminGet_Workflow_List] @GetVersion = 1
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
			@ProcedureDescription = 'List of open workflows',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'

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

		IF @VersionID IS NULL
			SELECT @VersionID = MAX(VersionID) FROM [Application] WHERE InstanceID = @InstanceID

	SET @Step = 'Return rows'
		SELECT 
			WF.[WorkFlowID],
			[WorkFlowName] = MAX(WF.[WorkFlowName]),
			WF.[ProcessID],
			ProcessName = MAX(P.ProcessName),
			ProcessDescription = MAX(P.ProcessDescription),
			OHP.OrganizationHierarchyID,
			OrganizationHierarchyName = MAX(OH.OrganizationHierarchyName),
			NumberOfLevels = MAX(OrganizationLevelNo),
			WF.[SelectYN]
		FROM
			[Workflow] WF
			INNER JOIN Process P ON P.InstanceID = WF.InstanceID AND P.VersionID = WF.VersionID AND P.ProcessID = WF.ProcessID
			INNER JOIN OrganizationHierarchy_Process OHP ON OHP.InstanceID = WF.InstanceID AND OHP.ProcessID = P.ProcessID
			INNER JOIN OrganizationHierarchy OH ON OH.InstanceID = WF.InstanceID AND OH.VersionID = WF.VersionID AND OH.OrganizationHierarchyID = OHP.OrganizationHierarchyID AND OH.DeletedID IS NULL
			LEFT JOIN OrganizationLevel OL ON OL.InstanceID = WF.InstanceID AND OL.OrganizationHierarchyID = OHP.OrganizationHierarchyID
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID AND
			WF.DeletedID IS NULL
		GROUP BY
			WF.[WorkFlowID],
			WF.[ProcessID],
			OHP.OrganizationHierarchyID,
			WF.[SelectYN]

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
