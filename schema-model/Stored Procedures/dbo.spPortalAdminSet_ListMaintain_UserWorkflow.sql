SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_ListMaintain_UserWorkflow]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DemoYN bit = 1,
	@Email nvarchar(100) = NULL,
	@GivenName nvarchar(50) = NULL,
	@FamilyName nvarchar(50) = NULL,
	@Title nvarchar(50) = NULL,
	@UserNameDisplay nvarchar(100) = NULL,
	@UserNameAD nvarchar(100) = NULL,
	@LicenseType nvarchar(100) = NULL,
	@ReportsTo nvarchar(100) = NULL,
	@OnBehalfOf	nvarchar(100) = NULL,
	@LinkedDimensionID int = NULL,
	@ResponsibleFor	nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000239,
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
EXEC [dbo].[spPortalAdminSet_ListMaintain_UserWorkflow]
	@UserID = -1039,
	@InstanceID = -1039,
	@VersionID = -1039,
	@DemoYN = 1,
	@Email = 'penny.jones@organization.com',
	@GivenName = 'Penny',
	@FamilyName = 'Jones',
	@Title = 'CEO',
	@UserNameDisplay = 'Penny Jones',
	@UserNameAD = 'LIVE\orgcom.penny.jones',
	@LicenseType = 'Budget user',
	@ReportsTo = 'charles.redkin@organization.com',
	@OnBehalfOf	= 'NULL',
	@LinkedDimensionID = NULL,
	@ResponsibleFor	= NULL,
	@Debug = 1

EXEC [dbo].[spPortalAdminSet_ListMaintain_UserWorkflow]
	@UserID = -1039,
	@InstanceID = -1039,
	@VersionID = -1039,
	@DemoYN = 1,
	@Email = 'paul.brown@organization.com',
	@GivenName = 'Paul',
	@FamilyName = 'Brown',
	@Title = 'Salesperson',
	@UserNameDisplay = 'Paul Brown',
	@UserNameAD = 'LIVE\orgcom.jack.jones',
	@LicenseType = 'Budget user',
	@ReportsTo = 'penny.jones@organization.com',
	@OnBehalfOf	= NULL,
	@LinkedDimensionID = NULL,
	@ResponsibleFor	= NULL,
	@Debug = 1

EXEC [dbo].[spPortalAdminSet_ListMaintain_UserWorkflow]
	@UserID = -1039,
	@InstanceID = -1089,
	@VersionID = -1027,
	@DemoYN = 1,
	@Email = 'jack.jones@organization.com',
	@GivenName = 'Jack',
	@FamilyName = 'Jones',
	@Title = 'Assistant',
	@UserNameDisplay = 'Jack Jones',
	@UserNameAD = 'LIVE\orgcom.jack.jones',
	@LicenseType = 'Budget user',
	@ReportsTo = 'paul.brown@organization.com',
	@OnBehalfOf	= 'penny.jones@organization.com',
	@LinkedDimensionID = 1128,
	@ResponsibleFor	= 'Arne',
	@Debug = 1

EXEC [dbo].[spPortalAdminSet_ListMaintain_UserWorkflow]
	@UserID = -2037,
	@InstanceID = 424,
	@VersionID = 1017,
	@Email = 'andrew.larsddsonn@xxxxx.xx',
	@GivenName = 'Andrew',
	@FamilyName = 'Larsson',
	@Title = 'CFO',
	@UserNameDisplay = 'Andrew Larsson',
	@UserNameAD = 'live\ef018.andrew.larsson',
	@LicenseType = 'Budget user',
	@ReportsTo = 'penny.jones@xxxx.xx',
	@OnBehalfOf	= '',
	@LinkedDimensionID = 1549,
	@ResponsibleFor	= '',
	@Debug = 1

EXEC [spPortalAdminSet_ListMaintain_UserWorkflow] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@PersonAdded int = 0,
	@IsLicensed int,
	@AdUser int,
	@Exists int = 0,

	@UserLicenseTypeID int,
	@LocaleID int = -41,
	@UserID_Person int,
	@UserID_Group int,
	@OrganizationHierarchyID int,
	@OrganizationPositionID int,
	@OrganizationPositionName nvarchar(50),
	@OrganizationPositionNameNumber int,
	@ParentOrganizationPositionID int,
	@BehalfOrganizationPositionID int,
	@ApplicationID int,
	@DimensionName nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@SortOrder int,
	@SQLStatement nvarchar(max),

	@UserID_BM int = 1,
	@InstanceID_BM int = 1,
	@VersionID_BM int = 1,
	@Email_BM int = 1,  --PersonAdded 2
	@GivenName_BM int = 1,
	@FamilyName_BM int = 1,
	@Title_BM int = 1,
	@UserNameDisplay_BM int = 1,
	@UserNameAD_BM int = 1, --Exists 2
	@LicenseType_BM int = 1, --IsLicensed 2, AdUser 4
	@ReportsTo_BM int = 1,
	@OnBehalfOf_BM int = 1,
	@LinkedDimensionID_BM int = 1,
	@ResponsibleFor_BM int = 1,

	@UserID_Msg nvarchar(255) = '',
	@InstanceID_Msg nvarchar(255) = '',
	@VersionID_Msg nvarchar(255) = '',
	@Email_Msg nvarchar(255) = '',
	@GivenName_Msg nvarchar(255) = '',
	@FamilyName_Msg nvarchar(255) = '',
	@Title_Msg nvarchar(255) = '',
	@UserNameDisplay_Msg nvarchar(255) = '',
	@UserNameAD_Msg nvarchar(255) = '',
	@LicenseType_Msg nvarchar(255) = '',
	@ReportsTo_Msg nvarchar(255) = '',
	@OnBehalfOf_Msg nvarchar(255) = '',
	@LinkedDimensionID_Msg nvarchar(255) = '',
	@ResponsibleFor_Msg nvarchar(255) = '',

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
			@ProcedureDescription = 'Maintain workflow from a list.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2144' SET @Description = 'DB-24 Fix: Added missing columns [InstanceID] and [VersionID] when inserting into [pcINTEGRATOR_Data] tables [UserPropertyValue], [UserMember], and [OrganizationPosition_User]; DB-25 Fix: Modified query to set [@BehalfOrganizationPositionID].'
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

		SELECT
			@ApplicationID = [ApplicationID],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		SELECT
			@DimensionName = [DimensionName]
		FROM
			[Dimension]
		WHERE
			[DimensionID] = @LinkedDimensionID


	SET @Step = 'Check if demo' IF @Debug <> 0 PRINT 'Step: ' + @Step
		IF @DemoYN = 0
			BEGIN
				SET @Message = 'This SP can only be used for demo purposes'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Update table ListMaintain_UserWorkflow' IF @Debug <> 0 PRINT 'Step: ' + @Step
		UPDATE [pcINTEGRATOR_Data].[dbo].[ListMaintain_UserWorkflow]
		SET
			UserID = @UserID,
			InstanceID = @InstanceID,
			VersionID = @VersionID,
			Email = @Email,
			GivenName = @GivenName,
			FamilyName = @FamilyName,
			Title = @Title,
			UserNameDisplay = @UserNameDisplay,
			UserNameAD = @UserNameAD,
			LicenseType = @LicenseType,
			ReportsTo = @ReportsTo,
			OnBehalfOf = @OnBehalfOf,
			LinkedDimensionID = @LinkedDimensionID,
			ResponsibleFor = @ResponsibleFor,
			UpdatedBy = @UserName
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			Email = @Email

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[ListMaintain_UserWorkflow]
			(
			UserID,
			InstanceID,
			VersionID,
			Email,
			GivenName,
			FamilyName,
			Title,
			UserNameDisplay,
			UserNameAD,
			LicenseType,
			ReportsTo,
			OnBehalfOf,
			LinkedDimensionID,
			ResponsibleFor,
			UpdatedBy
			)
		SELECT
			UserID = @UserID,
			InstanceID = @InstanceID,
			VersionID = @VersionID,
			Email = @Email,
			GivenName = @GivenName,
			FamilyName = @FamilyName,
			Title = @Title,
			UserNameDisplay = @UserNameDisplay,
			UserNameAD = @UserNameAD,
			LicenseType = @LicenseType,
			ReportsTo = @ReportsTo,
			OnBehalfOf = @OnBehalfOf,
			LinkedDimensionID = @LinkedDimensionID,
			ResponsibleFor = @ResponsibleFor,
			UpdatedBy = @UserName
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[ListMaintain_UserWorkflow] LMUW WHERE LMUW.InstanceID = @InstanceID AND LMUW.VersionID = @VersionID AND LMUW.Email = @Email)

	SET @Step = 'Check LicenseType' IF @Debug <> 0 PRINT 'Step: ' + @Step
		SELECT 
			@UserLicenseTypeID = UserLicenseTypeID,
			@IsLicensed = CASE WHEN ISNULL(UserLicenseTypeID, 0) <> 0 THEN 2 ELSE 0 END,
			@AdUser = CASE WHEN UserLicenseTypeID IN (-1, -2, -3) THEN 4 ELSE 0 END
		FROM
			UserLicenseType
		WHERE
			UserLicenseTypeName = @LicenseType

		SET @UserLicenseTypeID = ISNULL(@UserLicenseTypeID, 0)
		SET	@IsLicensed = ISNULL(@IsLicensed, 0)
		SET	@AdUser = ISNULL(@AdUser, 0)

	SET @Step = 'Create User' IF @Debug <> 0 PRINT 'Step: ' + @Step
		IF (SELECT COUNT(1) FROM [User] WHERE InstanceID = @InstanceID AND UserName = @Email) > 0
			BEGIN
				SET @Email_Msg = 'Person with email ' + @Email + ' already exists.'

				--UPDATE
			END
		ELSE
			BEGIN
				SET @PersonAdded = 2
				SELECT @UserID_Person = MIN(UserID) - 1 FROM [User] WHERE UserID < -1000
				SET @UserID_Person = ISNULL(@UserID_Person, -1001)

				IF @Debug <> 0 SELECT UserID_Person = @UserID_Person

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[User] ON
		
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
					(
					[InstanceID],
					[UserID],
					[UserName],
					[UserNameAD],
					[UserNameDisplay],
					[UserTypeID],
					[UserLicenseTypeID],
					[LocaleID],
					[LanguageID],
					[ObjectGuiBehaviorBM]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[UserID] = @UserID_Person,
					[UserName] = @Email,
					[UserNameAD] = CASE WHEN @AdUser = 4 THEN @UserNameAD ELSE NULL END,
					[UserNameDisplay] = @UserNameDisplay,
					[UserTypeID] = -1,
					[UserLicenseTypeID] = @UserLicenseTypeID,
					[LocaleID] = @LocaleID,
					[LanguageID] = 1,
					[ObjectGuiBehaviorBM] = 7

				SET @Inserted = @Inserted + @@ROWCOUNT
		
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[User] OFF
			END

			/*
			UserPropertyTypeID	UserPropertyTypeName
			-9	Title
			-3	E-mail
			-2	Family Name
			-1	Given Name
			*/

			SELECT @UserID_Person = UserID FROM [User] WHERE InstanceID = @InstanceID AND UserName = @Email

			INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
				(
				[InstanceID],
				[UserID],
				[UserPropertyTypeID],
				[UserPropertyValue],
				[SelectYN]
				)
			SELECT
				[InstanceID] = @InstanceID,
				[UserID] = @UserID_Person,
				[UserPropertyTypeID] = sub.[UserPropertyTypeID],
				[UserPropertyValue] = sub.[UserPropertyValue],
				[SelectYN] = 1
			FROM
				(
				SELECT 
					[UserPropertyTypeID] = -1,
					[UserPropertyValue] = @GivenName
				UNION
				SELECT 
					[UserPropertyTypeID] = -2,
					[UserPropertyValue] = @FamilyName
				UNION
				SELECT 
					[UserPropertyTypeID] = -3,
					[UserPropertyValue] = @Email
				UNION
				SELECT 
					[UserPropertyTypeID] = -9,
					[UserPropertyValue] = @Title
				) sub
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV WHERE UPV.[UserID] = @UserID_Person AND UPV.[UserPropertyTypeID] = sub.[UserPropertyTypeID])

	SET @Step = 'Insert into SecurityRole' IF @Debug <> 0 PRINT 'Step: ' + @Step
		IF @UserLicenseTypeID IS NOT NULL
			BEGIN
				SELECT
					@UserID_Group = MAX([UserID])
				FROM
					[pcINTEGRATOR].[dbo].[User]
				WHERE
					InstanceID = @InstanceID AND
					UserTypeID = -2 AND
					UserLicenseTypeID = @UserLicenseTypeID

				IF @UserID_Group IS NOT NULL
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
							(
							[InstanceID],
							[UserID_Group],
							[UserID_User], 
							[SelectYN]
							)
						SELECT
							[InstanceID] = @InstanceID,
							[UserID_Group] = @UserID_Group,
							[UserID_User] = @UserID_Person,
							[SelectYN] = 1
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserMember] UM WHERE UM.[UserID_Group] = @UserID_Group AND UM.[UserID_User] = @UserID_Person)
					END
			END

	SET @Step = 'Insert into OrganizationHierarchy' IF @Debug <> 0 PRINT 'Step: ' + @Step
		SELECT
			@OrganizationHierarchyID = MAX(OrganizationHierarchyID)
		FROM
			[OrganizationHierarchy] OH
			INNER JOIN
				(
				SELECT 
					OrganizationHierarchyName
				FROM
					[OrganizationHierarchy]
				WHERE
					InstanceID = -10 AND
					VersionID = -10
				) sub ON sub.OrganizationHierarchyName = OH.OrganizationHierarchyName
		WHERE
			OH.InstanceID = @InstanceID AND
			OH.VersionID = @VersionID

		IF @OrganizationHierarchyID IS NOT NULL
			BEGIN
				UPDATE OH
				SET
					[LinkedDimensionID] = @LinkedDimensionID
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OH
				WHERE
					OrganizationHierarchyID = @OrganizationHierarchyID

				SET @Updated = @Updated + @@ROWCOUNT
			END
		ELSE
			BEGIN
				SELECT @OrganizationHierarchyID = MIN(OrganizationHierarchyID) - 1 FROM [OrganizationHierarchy] WHERE OrganizationHierarchyID < -1000
				SET @OrganizationHierarchyID = ISNULL(@OrganizationHierarchyID, -1001)

				IF @Debug <> 0 PRINT '@OrganizationHierarchyID = ' + CONVERT(nvarchar(10), @OrganizationHierarchyID)

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] ON
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy]
				   (
				   [InstanceID],
				   [OrganizationHierarchyID],
				   [VersionID],
				   [OrganizationHierarchyName],
				   [LinkedDimensionID],
				   [ModelingStatusID],
				   [ModelingComment],
				   [DeletedID]
				   )
				SELECT
				   [InstanceID] = @InstanceID,
				   [OrganizationHierarchyID] = @OrganizationHierarchyID,
				   [VersionID] = @VersionID,
				   [OrganizationHierarchyName],
				   [LinkedDimensionID] = @LinkedDimensionID,
				   [ModelingStatusID],
				   [ModelingComment],
				   [DeletedID]
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OH
				WHERE
					InstanceID = -10 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OHD WHERE OHD.InstanceID = @InstanceID AND OHD.[OrganizationHierarchyName] = OH.[OrganizationHierarchyName])

				SET @Inserted = @Inserted + @@ROWCOUNT
				SET IDENTITY_INSERT [OrganizationHierarchy] OFF
			END

	SET @Step = 'Insert into OrganizationPosition' 
		IF @Debug <> 0 PRINT 'Step: ' + @Step
	
		SELECT
			@OrganizationPositionID = OP.OrganizationPositionID
		FROM
			[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.UserID = @UserID_Person
		WHERE
			OP.InstanceID = @InstanceID AND
			OP.VersionID = @VersionID

		IF @Debug <> 0 PRINT '@OrganizationPositionID = ' + CONVERT(nvarchar(10), @OrganizationPositionID)

		SELECT
			@ParentOrganizationPositionID = OP.OrganizationPositionID
		FROM
			[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID 
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.InstanceID = @InstanceID AND U.UserName = @ReportsTo AND U.UserID = OPU.UserID
		WHERE
			OP.InstanceID = @InstanceID AND
			OP.VersionID = @VersionID

		IF @Debug <> 0 PRINT '@ParentOrganizationPositionID = ' + CONVERT(nvarchar(10), @ParentOrganizationPositionID)

		IF @OrganizationPositionID IS NULL
			BEGIN
				SELECT @OrganizationPositionID = MIN(OrganizationPositionID) - 1 FROM [OrganizationPosition] WHERE OrganizationPositionID < -1000
				SET @OrganizationPositionID = ISNULL(@OrganizationPositionID, -1001)

				IF @Debug <> 0
					SELECT
						OP.OrganizationPositionName,
						Title = @Title,
						SortOrder = MAX(OP.SortOrder) + 10
					FROM
						[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
					WHERE
						OP.InstanceID = @InstanceID AND
						OP.VersionID = @VersionID AND
						--LEFT(OP.OrganizationPositionName, LEN(@Title)) = @Title AND
						ISNUMERIC(LTRIM(RTRIM(REPLACE(OP.OrganizationPositionName, @Title, '')))) <> 0
					GROUP BY
						OP.OrganizationPositionName
					
				SELECT
					@OrganizationPositionNameNumber = CONVERT(int, LTRIM(RTRIM(MAX(REPLACE(OP.OrganizationPositionName, @Title, ''))))) + 1,
					@SortOrder = MAX(OP.SortOrder) + 10
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID AND
--					LEFT(OP.OrganizationPositionName, LEN(@Title)) = @Title
					ISNUMERIC(LTRIM(RTRIM(REPLACE(OP.OrganizationPositionName, @Title, '')))) <> 0

				SELECT
					@OrganizationPositionName = @Title + CASE WHEN ISNULL(@OrganizationPositionNameNumber, 1) <= 9 THEN ' 0' ELSE ' ' END + CONVERT(nvarchar(10), ISNULL(@OrganizationPositionNameNumber, 1)),
					@SortOrder = ISNULL(@SortOrder, 10)

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] ON

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition]
					(
					[InstanceID],
					[OrganizationPositionID],
					[VersionID],
					[OrganizationPositionName],
					[OrganizationPositionDescription],
					[OrganizationHierarchyID],
					[ParentOrganizationPositionID],
					[OrganizationLevelNo],
					[LinkedDimension_MemberKey],
					[SortOrder]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[OrganizationPositionID] = @OrganizationPositionID,
					[VersionID] = @VersionID,
					[OrganizationPositionName] = @OrganizationPositionName,
					[OrganizationPositionDescription] = @OrganizationPositionName,
					[OrganizationHierarchyID] = @OrganizationHierarchyID,
					[ParentOrganizationPositionID] = @ParentOrganizationPositionID,
					[OrganizationLevelNo] = NULL,
					[LinkedDimension_MemberKey] = @ResponsibleFor,
					[SortOrder] = @SortOrder

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OFF
			END
		ELSE
			BEGIN
				IF @Debug <> 0 PRINT 'Start UPDATE OP.[ParentOrganizationPositionID] = @ParentOrganizationPositionID'
				UPDATE OP
				SET
					[ParentOrganizationPositionID] = @ParentOrganizationPositionID
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.UserID = @UserID_Person
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID
				IF @Debug <> 0 PRINT 'End UPDATE OP.[ParentOrganizationPositionID] = @ParentOrganizationPositionID'
			END

	SET @Step = 'Insert into OrganizationPosition_User' IF @Debug <> 0 PRINT 'Step: ' + @Step
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User]
			(
			[InstanceID],
			[VersionID],
			[Comment],
			[OrganizationPositionID],
			[UserID],
			[DelegateYN]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[Comment] = NULL,
			[OrganizationPositionID] = @OrganizationPositionID,
			[UserID] = @UserID_Person,
			[DelegateYN] = 0
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU WHERE OPU.[OrganizationPositionID] = @OrganizationPositionID AND OPU.[UserID] = @UserID_Person)

		--OnBehalfOf
		IF ISNULL(@OnBehalfOf, '') <> ''
			BEGIN
				/*
				SELECT
					@BehalfOrganizationPositionID = OP.OrganizationPositionID
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.[DelegateYN] = 0
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.InstanceID = @InstanceID AND U.UserName = @OnBehalfOf AND U.UserID = OPU.UserID
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID
				*/
				SELECT
					@BehalfOrganizationPositionID = OP.OrganizationPositionID
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.[DelegateYN] = 0
					INNER JOIN 
						(
						SELECT DISTINCT
							InstanceID,
							UserID,
							UserName
						FROM
							[pcINTEGRATOR_Data].[dbo].[User] U 
						WHERE	
							U.InstanceID = @InstanceID AND
							U.UserName = @OnBehalfOf 
						UNION 
						SELECT DISTINCT
							InstanceID = UI.InstanceID,
							UserID = U.UserID,
							UserName = U.UserName
						FROM 
							[pcINTEGRATOR_Data].[dbo].[User] U
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[User_Instance] UI ON UI.InstanceID = @InstanceID AND UI.UserID = U.UserID 
						WHERE
							U.UserName = @OnBehalfOf
						) AS sub ON sub.InstanceID = OP.InstanceID AND sub.UserID = OPU.UserID
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID

				IF @Debug <> 0 
					BEGIN
						SELECT BehalfOrganizationPositionID = @BehalfOrganizationPositionID, UserID_Person = @UserID_Person

						SELECT 
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[Comment] = NULL,
							[OrganizationPositionID] = @BehalfOrganizationPositionID,
							[UserID] = @UserID_Person,
							[DelegateYN] = 1
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU WHERE OPU.[OrganizationPositionID] = @BehalfOrganizationPositionID AND OPU.[UserID] = @UserID_Person)
					END

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User]
					(
					[InstanceID],
					[VersionID],
					[Comment],
					[OrganizationPositionID],
					[UserID],
					[DelegateYN]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[Comment] = NULL,
					[OrganizationPositionID] = @BehalfOrganizationPositionID,
					[UserID] = @UserID_Person,
					[DelegateYN] = 1
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU WHERE OPU.[OrganizationPositionID] = @BehalfOrganizationPositionID AND OPU.[UserID] = @UserID_Person)
			END

	SET @Step = 'Check ResponsibleFor' IF @Debug <> 0 PRINT 'Step: ' + @Step
		CREATE TABLE #Count ([Counter] int)
		SET @SQLStatement = '
			INSERT INTO #Count ([Counter])
			SELECT COUNT(1) FROM ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' WHERE Label = ''' + @ResponsibleFor + ''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SELECT
			@ResponsibleFor_BM = CASE WHEN [Counter] = 0 THEN 0 ELSE 1 END,
			@ResponsibleFor_Msg = CASE WHEN [Counter] = 0 THEN 'Member ' + @ResponsibleFor + ' does not exists in dimension ' + @DimensionName ELSE '' END
		FROM
			#Count

		DROP TABLE #Count

	SET @Step = 'Return information' IF @Debug <> 0 PRINT 'Step: ' + @Step
		SELECT
			ResultTypeBM = 1,
			UserID = CONVERT(nvarchar(255), @UserID),
			InstanceID = CONVERT(nvarchar(255), @InstanceID),
			VersionID = CONVERT(nvarchar(255), @VersionID),
			Email = CONVERT(nvarchar(255), @Email),
			GivenName = CONVERT(nvarchar(255), @GivenName),
			FamilyName = CONVERT(nvarchar(255), @FamilyName),
			Title = CONVERT(nvarchar(255), @Title),
			UserNameDisplay = CONVERT(nvarchar(255), @UserNameDisplay),
			UserNameAD = CONVERT(nvarchar(255), @UserNameAD),
			LicenseType = CONVERT(nvarchar(255), @LicenseType),
			ReportsTo = CONVERT(nvarchar(255), @ReportsTo),
			OnBehalfOf = CONVERT(nvarchar(255), @OnBehalfOf),
			LinkedDimensionID = CONVERT(nvarchar(255), @LinkedDimensionID),
			ResponsibleFor = CONVERT(nvarchar(255), @ResponsibleFor)

		UNION
		SELECT
			ResultTypeBM = 2,
			UserID = CONVERT(nvarchar(255), @UserID_BM),
			InstanceID = CONVERT(nvarchar(255), @InstanceID_BM),
			VersionID = CONVERT(nvarchar(255), @VersionID_BM),
			Email = CONVERT(nvarchar(255), @Email_BM + @PersonAdded),
			GivenName = CONVERT(nvarchar(255), @GivenName_BM),
			FamilyName = CONVERT(nvarchar(255), @FamilyName_BM),
			Title = CONVERT(nvarchar(255), @Title_BM),
			UserNameDisplay = CONVERT(nvarchar(255), @UserNameDisplay_BM),
			UserNameAD = CONVERT(nvarchar(255), @UserNameAD_BM + @Exists),
			LicenseType = CONVERT(nvarchar(255), @LicenseType_BM + @IsLicensed + @AdUser),
			ReportsTo = CONVERT(nvarchar(255), @ReportsTo_BM),
			OnBehalfOf = CONVERT(nvarchar(255), @OnBehalfOf_BM),
			LinkedDimensionID = CONVERT(nvarchar(255), @LinkedDimensionID_BM),
			ResponsibleFor = CONVERT(nvarchar(255), @ResponsibleFor_BM)

		UNION
		SELECT
			ResultTypeBM = 4,
			UserID = @UserID_Msg,
			InstanceID = @InstanceID_Msg,
			VersionID = @VersionID_Msg,
			Email = @Email_Msg,
			GivenName = @GivenName_Msg,
			FamilyName = @FamilyName_Msg,
			Title = @Title_Msg,
			UserNameDisplay = @UserNameDisplay_Msg,
			UserNameAD = @UserNameAD_Msg,
			LicenseType = @LicenseType_Msg,
			ReportsTo = @ReportsTo_Msg,
			OnBehalfOf = @OnBehalfOf_Msg,
			LinkedDimensionID = @LinkedDimensionID_Msg,
			ResponsibleFor = @ResponsibleFor_Msg

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
