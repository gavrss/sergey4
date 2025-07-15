SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_AssignmentCreateCopy]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@FromAssignmentID int = NULL,
	@NewAssignmentID int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000114,
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
	@ProcedureName = 'spPortalAdminSet_AssignmentCreateCopy',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminSet_AssignmentCreateCopy] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spPortalAdminSet_AssignmentCreateCopy] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@WorkflowID int,
	@AssignmentName nvarchar(100),
	@Comment nvarchar(100),
	@OrganizationPositionID int,
	@DataClassID int,
	@GridID int,
	@Priority int,
	@InheritedFrom int,

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
			@ProcedureDescription = 'Copy Assignment',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-179: Added call to SP spPortalAdminSet_Assignment_OrganizationLevel. Handle VersionID in sub tables.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'

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

	SET @Step = 'Insert new data into table Assignment.'
		DECLARE WF_Assignment_Cursor CURSOR FOR

			SELECT 
				[AssignmentName],
				[Comment],
				[OrganizationPositionID],
				[DataClassID],
				[WorkflowID],
				[GridID],
				[Priority],
				[InheritedFrom] = [AssignmentID]
			FROM
				[pcINTEGRATOR_Data].[dbo].[Assignment] A
			WHERE
				A.[InstanceID] = @InstanceID AND
				A.[VersionID] = @VersionID AND
				A.[AssignmentID] = @FromAssignmentID AND
				A.SelectYN <> 0 AND
				A.DeletedID IS NULL	

			OPEN WF_Assignment_Cursor
			FETCH NEXT FROM WF_Assignment_Cursor INTO @AssignmentName, @Comment, @OrganizationPositionID, @DataClassID, @WorkflowID, @GridID, @Priority, @InheritedFrom

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT @AssignmentName, @Comment, @OrganizationPositionID, @DataClassID, @GridID, @Priority, @InheritedFrom

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Assignment]
						(
 						[InstanceID],
						[VersionID],
						[AssignmentName],
						[Comment],
						[OrganizationPositionID],
						[DataClassID],
						[WorkflowID],
						[GridID],
						[Priority],
						[InheritedFrom],
						[SelectYN]
						)
					SELECT
 						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[AssignmentName] = 'Copy of ' + @AssignmentName,
						[Comment] = @Comment,
						[OrganizationPositionID] = @OrganizationPositionID,
						[DataClassID] = @DataClassID,
						[WorkflowID] = @WorkflowID,
						[GridID] = @GridID,
						[Priority] = @Priority,
						[InheritedFrom] = @InheritedFrom,
						[SelectYN] = 1

					SET @NewAssignmentID = @@IDENTITY

					FETCH NEXT FROM WF_Assignment_Cursor INTO @AssignmentName, @Comment, @OrganizationPositionID, @DataClassID, @WorkflowID, @GridID, @Priority, @InheritedFrom
				END

		CLOSE WF_Assignment_Cursor
		DEALLOCATE WF_Assignment_Cursor	

	SET @Step = 'Insert new data into table AssignmentRow.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[AssignmentRow]
			(
			[InstanceID],
			[VersionID],
			[AssignmentID],
			[DimensionID],
			[Dimension_MemberKey]
			)
		SELECT 
			[InstanceID] = AR.[InstanceID],
			[VersionID] = AR.[VersionID],
			[AssignmentID] = @NewAssignmentID,
			[DimensionID] = AR.DimensionID,
			[Dimension_MemberKey] = AR.Dimension_MemberKey
		FROM
			[pcINTEGRATOR_Data].[dbo].[AssignmentRow] AR
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.InstanceID = AR.InstanceID AND A.AssignmentID = @NewAssignmentID AND A.InheritedFrom = AR.AssignmentID
		WHERE
			AR.[InstanceID] = @InstanceID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[AssignmentRow] ARS WHERE ARS.[AssignmentID] = A.AssignmentID AND ARS.[DimensionID] = AR.DimensionID AND ARS.[Dimension_MemberKey] = AR.Dimension_MemberKey)

	SET @Step = 'Insert new data into table Assignment_OrganizationLevel.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel]
			(
			[InstanceID],
			[VersionID],
			[AssignmentID],
			[OrganizationLevelNo],
			[OrganizationPositionID],
			[LevelInWorkflowYN],
			[ExpectedDate],
			[ActionDescription],
			[GridID]
			)
		SELECT 
			[InstanceID] = AOL.InstanceID,
			[VersionID] = AOL.[VersionID],
			[AssignmentID] = @NewAssignmentID,
			[OrganizationLevelNo],
			[OrganizationPositionID] = AOL.[OrganizationPositionID],
			[LevelInWorkflowYN],
			[ExpectedDate],
			[ActionDescription],
			[GridID] = AOL.GridID
		FROM
			[pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.InstanceID = AOL.InstanceID AND A.AssignmentID = @NewAssignmentID AND A.InheritedFrom = AOL.AssignmentID
		WHERE
			AOL.[InstanceID] = @InstanceID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOLS WHERE AOLS.[AssignmentID] = A.AssignmentID AND AOLS.OrganizationLevelNo = AOL.OrganizationLevelNo)

	SET @Step = 'Update Assignment_OrganizationLevel'
		EXEC spPortalAdminSet_Assignment_OrganizationLevel @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @WorkflowID = @WorkflowID

	SET @Step = 'Return value @NewAssignmentID.'
		SELECT [@NewAssignmentID] = @NewAssignmentID

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
