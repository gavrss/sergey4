SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_OrganizationHierarchy]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@OrganizationHierarchyID int = NULL OUT, --If NULL, add a new member
	@OrganizationHierarchyName nvarchar(50) = NULL, 
	@LinkedDimensionID int = NULL,
	@ModelingStatusID int = NULL,
	@ModelingComment nvarchar(1024) = NULL,
	@ProcessID int = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000117,
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
--UPDATE
EXEC [spPortalAdminSet_OrganizationHierarchy]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationHierarchyID = 1004, --If NULL, add a new member
	@OrganizationHierarchyName = 'CEO 2',
	@LinkedDimensionID = NULL,
	@ModelingStatusID = -40,
	@ModelingComment = NULL,
	@ProcessID = 1001

--DELETE
EXEC [spPortalAdminSet_OrganizationHierarchy]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationHierarchyID = 1002,
	@DeleteYN = 1

--INSERT
EXEC [spPortalAdminSet_OrganizationHierarchy]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationHierarchyID = NULL,
	@OrganizationHierarchyName = 'CEO 2',
	@LinkedDimensionID = NULL,
	@ModelingStatusID = NULL,
	@ModelingComment = NULL,
	@ProcessID = 1002

EXEC [spPortalAdminSet_OrganizationHierarchy] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,
	@Prev_LinkedDimensionID int,

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
	@Version nvarchar(50) = '2.1.0.2163'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create new OrganizationHierarchy and bind to Process',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-452: Added UPDATE query on [OrganizationPosition] when LinkedDimensionID is changed.'
		IF @Version = '2.1.0.2163' SET @Description = 'Set correct @InstanceID and @VersionID parameter values when calling [spGet_DeletedItem].'

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

		SELECT 
			@Prev_LinkedDimensionID = LinkedDimensionID
		FROM
			[pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OH
		WHERE
			OH.[InstanceID] = @InstanceID AND
			OH.[OrganizationHierarchyID] = @OrganizationHierarchyID AND
			OH.[VersionID] = @VersionID

	SET @Step = 'Update existing member'
		IF @OrganizationHierarchyID IS NOT NULL AND @DeleteYN = 0
			BEGIN
				IF @OrganizationHierarchyID IS NULL OR @OrganizationHierarchyName IS NULL 
					BEGIN
						SET @Message = 'To update an existing member parameter @OrganizationHierarchyID AND @OrganizationHierarchyName must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				UPDATE OH
				SET
					[OrganizationHierarchyName] = @OrganizationHierarchyName,
					LinkedDimensionID = ISNULL(@LinkedDimensionID, OH.LinkedDimensionID),
					ModelingStatusID = ISNULL(@ModelingStatusID, OH.ModelingStatusID),
					ModelingComment = ISNULL(@ModelingComment, OH.ModelingComment)
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OH
				WHERE
					OH.[InstanceID] = @InstanceID AND
					OH.[OrganizationHierarchyID] = @OrganizationHierarchyID AND
					OH.[VersionID] = @VersionID

				SET @Updated = @Updated + @@ROWCOUNT

				IF @ProcessID IS NOT NULL
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process]
							(
							InstanceID,
							OrganizationHierarchyID,
							ProcessID
							)
						SELECT
							InstanceID = @InstanceID,
							OrganizationHierarchyID = @OrganizationHierarchyID,
							ProcessID = @ProcessID
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process] OHP WHERE OHP.OrganizationHierarchyID = @OrganizationHierarchyID AND OHP.ProcessID = @ProcessID)

						SET @Inserted = @Inserted + @@ROWCOUNT
					END

				IF @Updated > 0
					SET @Message = 'The member is updated.' 
				ELSE
					SET @Message = 'No member is updated.' 
				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'OrganizationHierarchy', @DeletedID = @DeletedID OUT, @JobID = @JobID

				UPDATE OH
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OH
				WHERE
					OH.[InstanceID] = @InstanceID AND
					OH.[OrganizationHierarchyID] = @OrganizationHierarchyID AND
					OH.[VersionID] = @VersionID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 
				ELSE
					SET @Message = 'No member is deleted.' 
				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @OrganizationHierarchyID IS NULL AND @DeleteYN = 0
			BEGIN
				IF @OrganizationHierarchyName IS NULL
					BEGIN
						SET @Message = 'To add a new member parameter @OrganizationHierarchyName must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy]
					(
					[InstanceID],
					[VersionID],
					[OrganizationHierarchyName],
					LinkedDimensionID,
					ModelingStatusID,
					ModelingComment
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[OrganizationHierarchyName] = @OrganizationHierarchyName,
					LinkedDimensionID = @LinkedDimensionID,
					ModelingStatusID = ISNULL(@ModelingStatusID, -40),
					ModelingComment = @ModelingComment

				SELECT
					@OrganizationHierarchyID = @@IDENTITY,
					@Inserted = @Inserted + @@ROWCOUNT

			
				IF @ProcessID IS NOT NULL
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process]
							(
							InstanceID,
							OrganizationHierarchyID,
							ProcessID
							)
						SELECT
							InstanceID = @InstanceID,
							OrganizationHierarchyID = @OrganizationHierarchyID,
							ProcessID = @ProcessID
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process] OHP WHERE OHP.OrganizationHierarchyID = @OrganizationHierarchyID AND OHP.ProcessID = @ProcessID)

						SET @Inserted = @Inserted + @@ROWCOUNT
					END

				IF @Inserted > 0
					SET @Message = 'The new member is added.' 
				ELSE
					SET @Message = 'No member is added.' 
				SET @Severity = 0
			END

	SET @Step = 'Update LinkedDimension_MemberKey'
		IF @LinkedDimensionID IS NOT NULL AND @Prev_LinkedDimensionID IS NOT NULL AND @LinkedDimensionID <> @Prev_LinkedDimensionID
			BEGIN
				UPDATE OP
				SET
					LinkedDimension_MemberKey = NULL
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID AND
					OP.OrganizationHierarchyID = @OrganizationHierarchyID

				SET @Updated = @Updated + @@ROWCOUNT
			END			

	SET @Step = 'Return @OrganizationHierarchyID'
		SELECT [@OrganizationHierarchyID] = @OrganizationHierarchyID

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
