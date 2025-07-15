SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Assignment_AutoCreate]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowID int = NULL, --Optional, if NULL all existing workflows are used

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000247,
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
EXEC [dbo].[spPortalAdminSet_Assignment_AutoCreate] 
	@UserID = -1124,
	@InstanceID = -1138,
	@VersionID = -1076,
	@Debug = 1

EXEC [spPortalAdminSet_Assignment_AutoCreate]
	@InstanceID=-1194,
	@UserID=-1517,
	@VersionID=-1132,
	@Debug = 1

EXEC [spPortalAdminSet_Assignment_AutoCreate] @GetVersion = 1
*/
DECLARE
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@OrganizationPositionID int,

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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create default assignments based on InstanceID = -10',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'Changed structure.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data]'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

--SET NOCOUNT ON 

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

	SET @Step = 'Set OrganizationLevelNo'
		IF @Debug <> 0
			SELECT
				UserID = @UserID,
				InstanceID = @InstanceID,
				VersionID = @VersionID

		SELECT
			@OrganizationPositionID = OrganizationPositionID
		FROM
			[pcINTEGRATOR_Data].[dbo].[OrganizationPosition]
		WHERE
			InstanceID = @InstanceID AND VersionID = @VersionID AND ParentOrganizationPositionID IS NULL

		IF @OrganizationPositionID IS NULL
			BEGIN
				SET @Message = 'There is not any top node member in the OrganizationPosition tree.'
				SET @Severity = 0
				GOTO EXITPOINT
			END

		IF @Debug <> 0 SELECT OrganizationPositionID = @OrganizationPositionID

		EXEC [spSet_OrganizationLevelNo] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @OrganizationPositionID=@OrganizationPositionID

	SET @Step = 'Autocreate new instances'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Assignment]
			(
			[InstanceID],
			[VersionID],
			[AssignmentName],
			[Comment],
			[OrganizationPositionID],
			[DataClassID],
			[WorkflowID],
			[SpreadingKeyID],
			[GridID],
			[Priority],
			[InheritedFrom],
			[SelectYN]
			)
		SELECT 
			[InstanceID] = OP.InstanceID,
			[VersionID] = OP.VersionID,
			[AssignmentName] = D.DimensionName + ' ' + OP.LinkedDimension_MemberKey,
			[Comment] = D.DimensionName + ' ' + OP.LinkedDimension_MemberKey,
			[OrganizationPositionID] = OP.[OrganizationPositionID],
			[DataClassID] = G.DataClassID,
			[WorkflowID] = WF.[WorkflowID],
			[SpreadingKeyID] = WF.[SpreadingKeyID],
			[GridID] = G.GridID,
			[Priority] = 1,
			[InheritedFrom] = A.AssignmentID,
			[SelectYN] = 1
		FROM
			[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OH ON OH.OrganizationHierarchyID = OP.OrganizationHierarchyID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension] D ON D.DimensionID = OH.LinkedDimensionID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.InstanceID = @SourceInstanceID AND A.VersionID = @SourceVersionID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Workflow] WF ON WF.InstanceID = OP.InstanceID AND WF.VersionID = OP.VersionID AND WF.InheritedFrom = A.WorkflowID AND (WF.WorkflowID = @WorkflowID OR @WorkflowID IS NULL)
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Grid] G ON G.InstanceID = OP.InstanceID AND G.InheritedFrom = A.GridID
		WHERE
			OP.InstanceID = @InstanceID AND
			OP.VersionID = @VersionID AND
			ISNULL(OP.LinkedDimension_MemberKey, '') <> '' AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Assignment] A WHERE A.InstanceID = @InstanceID AND A.VersionID = @VersionID AND A.[DataClassID] = G.DataClassID AND A.[AssignmentName] = D.DimensionName + ' ' + OP.LinkedDimension_MemberKey)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Set Assignment_OrganizationLevel'
		EXEC spPortalAdminSet_Assignment_OrganizationLevel @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID

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
