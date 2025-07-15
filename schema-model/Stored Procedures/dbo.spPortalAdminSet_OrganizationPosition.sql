SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_OrganizationPosition]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	@OrganizationPositionID INT = NULL OUT, --If NULL, add a new member
	@OrganizationHierarchyID INT = NULL,
	@OrganizationPositionName NVARCHAR(50) = NULL,
	@OrganizationPositionDescription NVARCHAR(100) = NULL,
	@OrganizationPositionTypeID INT = NULL,
	@ParentOrganizationPositionID INT = NULL, --If NULL, check it is first member in the hierarchy
	@LinkedDimension_MemberKey NVARCHAR(100) = NULL,
	@HeldByUserID INT = NULL,
	@HeldByUserOrgComment NVARCHAR(100) = NULL,
	@DateFrom DATE = NULL,
	@DateTo DATE = NULL,
	@DeleteYN BIT = 0,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000118,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0

--#WITH ENCRYPTION#--

AS
/*
--EXEC [spPortalAdminSet_OrganizationPosition] @OrganizationPositionDescription='07 SalesPerson  (Oystein Backen)', @LinkedDimension_MemberKey='07_9145', @DeleteYN=0, @InstanceID=304, @OrganizationPositionName='07_9145', @OrganizationHierarchyID=1002, @OrganizationPositionID=1099, @UserID=2002, @ParentOrganizationPositionID=1026, @HeldByUserID=NULL, @HeldByUserOrgComment='Oystein B', @VersionID=1001

--UPDATE
EXEC [spPortalAdminSet_OrganizationPosition]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationPositionID = 1001, --If NULL, add a new member
	@OrganizationHierarchyID = 1002,
	@OrganizationPositionName = 'CEO 2',
	@OrganizationPositionDescription = 'CEO 2',
	@ParentOrganizationPositionID = NULL,
	@LinkedDimension_MemberKey = 'All_',
	@HeldByUserID = 2012,
	@HeldByUserOrgComment = 'CEO 2'

--DELETE
EXEC [spPortalAdminSet_OrganizationPosition]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationPositionID = 1001,
	@DeleteYN = 1

--INSERT
EXEC [spPortalAdminSet_OrganizationPosition]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationPositionID = NULL,
	@OrganizationHierarchyID = 1002,
	@OrganizationPositionName = 'CEO 2',
	@OrganizationPositionDescription = 'CEO 2',
	@ParentOrganizationPositionID = NULL,
	@LinkedDimension_MemberKey = 'All_',
	@HeldByUserID = 2012,
	@HeldByUserOrgComment = 'CEO 2'

EXEC [spPortalAdminSet_OrganizationPosition] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	@DeletedID int,

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
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.2.2187'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert, Update or Delete rows in table OrganizationPosition.',
			@MandatoryParameter = ''

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-171: Return @OrganizationPositionID when added new. DB-192: Insert fails, InstanceID IS NULL.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'
		IF @Version = '2.1.0.2163' SET @Description = 'Set correct @InstanceID and @VersionID parameter values when calling [spGet_DeletedItem].'
		IF @Version = '2.1.1.2171' SET @Description = 'Added new parameters; @OrganizationPositionTypeID, @DateFrom and @DateTo.'
		IF @Version = '2.1.2.2187' SET @Description = 'EA-740 FIX: spPortalAdminSet_OrganizationPosition Violation of PRIMARY KEY constraint ''PK_OrganizationPosition_User''. Cannot insert duplicate key in object ''dbo.OrganizationPosition_User'''
		
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

	SET @Step = 'Check @OrganizationPositionID <> @ParentOrganizationPositionID'
		IF @OrganizationPositionID = @ParentOrganizationPositionID
			BEGIN
				SET @Message = '@OrganizationPositionID can not have the same value as @ParentOrganizationPositionID. You can not have yourself as parent.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Update existing member'
		IF @OrganizationPositionID IS NOT NULL AND @DeleteYN = 0
			BEGIN
				IF @Debug <> 0 SELECT [@Step] = @Step
				IF @OrganizationHierarchyID IS NULL OR @OrganizationPositionName IS NULL OR @OrganizationPositionDescription IS NULL
					BEGIN
						SET @Message = 'To update an existing member parameter @OrganizationHierarchyID, @OrganizationPositionName AND @OrganizationPositionDescription must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END
--/*
				IF @ParentOrganizationPositionID IS NULL
					IF (SELECT COUNT(1) FROM OrganizationPosition OP WHERE [OrganizationHierarchyID] = @OrganizationHierarchyID AND [ParentOrganizationPositionID] IS NULL AND [OrganizationPositionID] <> @OrganizationPositionID) > 0
						BEGIN
							SET @Message = 'There is already a TopNode member for selected OrganizationHierarchy. A Parent must be selected.'
							SET @Severity = 16
							GOTO EXITPOINT
						END
--*/
				UPDATE OP
				SET
					[OrganizationPositionName] = @OrganizationPositionName,
					[OrganizationPositionDescription] = @OrganizationPositionDescription,
					[OrganizationPositionTypeID] = @OrganizationPositionTypeID, 
					[OrganizationHierarchyID] = @OrganizationHierarchyID,
					[ParentOrganizationPositionID] = @ParentOrganizationPositionID,
					[LinkedDimension_MemberKey] = @LinkedDimension_MemberKey
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
				WHERE
					OP.[InstanceID] = @InstanceID AND
					OP.OrganizationPositionID = @OrganizationPositionID AND
					OP.[VersionID] = @VersionID

				SET @Updated = @Updated + @@ROWCOUNT

/*
				UPDATE OP
				SET
					[OrganizationLevelNo] = [dbo].[GetOrganizationLevelNo] (@OrganizationPositionID)
				FROM
					[dbo].[OrganizationPosition] OP
				WHERE
					OP.[InstanceID] = @InstanceID AND
					OP.OrganizationPositionID = @OrganizationPositionID AND
					OP.[VersionID] = @VersionID
*/

				IF @HeldByUserID IS NOT NULL
					BEGIN
						-- Only one userID can be "owner" for OrganizationPositionID
						-- So steps:
						-- REM: point 1 is not implemented yet without approve from business: 
						--		1. If there is already another userID as the owner (with DelegateYN=0), we will  set DelegateYN=1 where (UserID <> @HeldByUserID and DelegateYN=0)
												
						------ 1 :
						--IF (SELECT COUNT(1) FROM OrganizationPosition_User WHERE OrganizationPositionID = @OrganizationPositionID AND DelegateYN = 0 and UserID <> @HeldByUserID) > 0
						--	BEGIN
						--		IF @Debug <> 0 SELECT [Update_User] = 'Update current owner(DelegateYN=0) to DelegateYN=1, when this owner is UserID <> @HeldByUserID'
						--		UPDATE OPU
						--		SET
						--			DelegateYN = 1
						--		FROM
						--			[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU
						--		WHERE
						--			InstanceID = @InstanceID AND
						--			VersionID = @VersionID AND
						--			OrganizationPositionID = @OrganizationPositionID AND
						--			UserID <> @HeldByUserID AND
						--			DelegateYN = 0

						--		SET @Updated = @Updated + @@ROWCOUNT
						--	END

						-- 2. Insert (or update existing UserID) @HeldByUserID as owner of OrganizationPositionID with DelegateYN=0
						IF (SELECT COUNT(1) FROM OrganizationPosition_User WHERE OrganizationPositionID = @OrganizationPositionID /*AND DelegateYN = 1*/ and UserID = @HeldByUserID) > 0
							BEGIN
								IF @Debug <> 0 SELECT [Update_User] = 'Update to owner (DelegateYN=0), when this user exists UserID = @HeldByUserID'
								UPDATE OPU
								SET
									Comment		= @HeldByUserOrgComment,
									DateFrom	= @DateFrom,
									DateTo		= @DateTo,
									DelegateYN	= 0
								FROM
									[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU
								WHERE
									InstanceID = @InstanceID AND
									VersionID = @VersionID AND
									OrganizationPositionID = @OrganizationPositionID AND
									UserID = @HeldByUserID --AND
									-- DelegateYN = 1

								SET @Updated = @Updated + @@ROWCOUNT
							END
							ELSE IF (SELECT COUNT(1) FROM OrganizationPosition_User WHERE OrganizationPositionID = @OrganizationPositionID and UserID = @HeldByUserID) = 0
								BEGIN
									IF @Debug <> 0 SELECT [Insert_User] = 'Insert new owner (DelegateYN=0)'
									INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User]
										(
										InstanceID,
										VersionID,
										Comment,
										OrganizationPositionID,
										UserID,
										DelegateYN,
										DateFrom,
										DateTo
										)
									SELECT
										InstanceID = @InstanceID,
										VersionID = @VersionID,
										Comment = @HeldByUserOrgComment,
										OrganizationPositionID = @OrganizationPositionID,
										UserID = @HeldByUserID,
										DelegateYN = 0,
										DateFrom = @DateFrom,
										DateTo = @DateTo

									SET @Inserted = @Inserted + @@ROWCOUNT
								END
                            
						
						--IF (SELECT COUNT(1) FROM OrganizationPosition_User WHERE OrganizationPositionID = @OrganizationPositionID AND DelegateYN = 0) > 0
						--	BEGIN
						--		IF @Debug <> 0 SELECT [Update _User] = 'Case 1'
						--		UPDATE OPU
						--		SET
						--			Comment = @HeldByUserOrgComment,
						--			UserID = @HeldByUserID,
						--			DateFrom = @DateFrom,
						--			DateTo = @DateTo
						--		FROM
						--			[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU
						--		WHERE
						--			InstanceID = @InstanceID AND
						--			VersionID = @VersionID AND
						--			OrganizationPositionID = @OrganizationPositionID AND
						--			DelegateYN = 0

						--		SET @Updated = @Updated + @@ROWCOUNT
						--	END
						--ELSE
						--	BEGIN
						--		IF @Debug <> 0 SELECT [Update _User] = 'Case 2'
						--		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User]
						--			(
						--			InstanceID,
						--			VersionID,
						--			Comment,
						--			OrganizationPositionID,
						--			UserID,
						--			DelegateYN,
						--			DateFrom,
						--			DateTo
						--			)
						--		SELECT
						--			InstanceID = @InstanceID,
						--			VersionID = @VersionID,
						--			Comment = @HeldByUserOrgComment,
						--			OrganizationPositionID = @OrganizationPositionID,
						--			UserID = @HeldByUserID,
						--			DelegateYN = 0,
						--			DateFrom = @DateFrom,
						--			DateTo = @DateTo

						--		SET @Inserted = @Inserted + @@ROWCOUNT
						--	END
						
					END
				ELSE
					DELETE OPU
					FROM
						[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU
					WHERE
						OPU.OrganizationPositionID = @OrganizationPositionID AND
						OPU.DelegateYN = 0


				IF @Updated > 0
					SET @Message = 'The member is updated.' 
				ELSE
					SET @Message = 'No member is updated.' 
				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				IF @Debug <> 0 SELECT [@Step] = @Step
				SELECT
					@ParentOrganizationPositionID = ISNULL(@ParentOrganizationPositionID, ParentOrganizationPositionID)
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
				WHERE
					OP.OrganizationPositionID = @OrganizationPositionID

				UPDATE OP
				SET
					ParentOrganizationPositionID = @ParentOrganizationPositionID
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
				WHERE
					ParentOrganizationPositionID = @OrganizationPositionID

				EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'OrganizationPosition', @DeletedID = @DeletedID OUT, @JobID = @JobID

				UPDATE OP
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
				WHERE
					OP.[InstanceID] = @InstanceID AND
					OP.OrganizationPositionID = @OrganizationPositionID AND
					OP.[VersionID] = @VersionID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 
				ELSE
					SET @Message = 'No member is deleted.' 
				SET @Severity = 0

				DELETE AR
				FROM
					[pcINTEGRATOR_Data].[dbo].[AssignmentRow] AR
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.AssignmentID = AR.AssignmentID
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NOT NULL
				WHERE
					A.OrganizationPositionID = @OrganizationPositionID

				DELETE AOL
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.AssignmentID = AOL.AssignmentID
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NOT NULL
				WHERE
					A.OrganizationPositionID = @OrganizationPositionID

				DELETE A
				FROM
					[pcINTEGRATOR_Data].[dbo].[Assignment] A
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NOT NULL
				WHERE
					A.OrganizationPositionID = @OrganizationPositionID
				
				SET @OrganizationPositionID = @ParentOrganizationPositionID
			END

	SET @Step = 'Insert new member'
		IF @OrganizationPositionID IS NULL AND @DeleteYN = 0
			BEGIN
				IF @Debug <> 0 SELECT [@Step] = @Step
				IF @OrganizationHierarchyID IS NULL OR @OrganizationPositionName IS NULL OR @OrganizationPositionDescription IS NULL
					BEGIN
						SET @Message = 'To add a new member parameter @OrganizationHierarchyID, @OrganizationPositionName AND @OrganizationPositionDescription must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END
--/*
				IF @ParentOrganizationPositionID IS NULL
					IF (SELECT COUNT(1) FROM OrganizationPosition OP WHERE OrganizationHierarchyID = @OrganizationHierarchyID) > 0
						BEGIN
							SET @Message = 'There is already a TopNode member for selected OrganizationHierarchy. A Parent must be selected.'
							SET @Severity = 16
							GOTO EXITPOINT
						END
--*/
		
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition]
					(
					[InstanceID],
					[VersionID],
					[OrganizationPositionName],
					[OrganizationPositionDescription],
					[OrganizationPositionTypeID],
					[OrganizationHierarchyID],
					[ParentOrganizationPositionID],
					[LinkedDimension_MemberKey]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[OrganizationPositionName] = @OrganizationPositionName,
					[OrganizationPositionDescription] = @OrganizationPositionDescription,
					[OrganizationPositionTypeID] = @OrganizationPositionTypeID,
					[OrganizationHierarchyID] = @OrganizationHierarchyID,
					[ParentOrganizationPositionID] = @ParentOrganizationPositionID,
					[LinkedDimension_MemberKey] = @LinkedDimension_MemberKey

				SELECT
					@OrganizationPositionID = @@IDENTITY,
					@Inserted = @Inserted + @@ROWCOUNT

/*
				UPDATE OP
				SET
					[OrganizationLevelNo] = [dbo].[GetOrganizationLevelNo] (@OrganizationPositionID)
				FROM
					[dbo].[OrganizationPosition] OP
				WHERE
					OP.[InstanceID] = @InstanceID AND
					OP.OrganizationPositionID = @OrganizationPositionID AND
					OP.[VersionID] = @VersionID
*/
				
				IF @HeldByUserID IS NOT NULL
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User]
							(
							[InstanceID],
							[VersionID],
							[Comment],
							[OrganizationPositionID],
							[UserID],
							[DelegateYN],
							DateFrom,
							DateTo
							)
						SELECT
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[Comment] = @HeldByUserOrgComment,
							[OrganizationPositionID] = @OrganizationPositionID,
							[UserID] = @HeldByUserID,
							[DelegateYN] = 0,
							DateFrom = @DateFrom,
							DateTo = @DateTo

						SET @Inserted = @Inserted + @@ROWCOUNT
					END

				IF @Inserted > 0
					BEGIN
						SELECT [@OrganizationPositionID] = @OrganizationPositionID
						SET @Message = 'The new member is added.' 
					END
				ELSE
					SET @Message = 'No member is added.' 
				SET @Severity = 0
			END

	SET @Step = 'Update OrganizationLevelNo'
		EXEC spSet_OrganizationLevelNo @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @OrganizationPositionID=@OrganizationPositionID

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
