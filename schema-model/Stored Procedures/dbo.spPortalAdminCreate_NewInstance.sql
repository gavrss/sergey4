SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminCreate_NewInstance]
	@UserID int = NULL OUT,
	@InstanceID int = NULL OUT,
	@VersionID int = NULL OUT,

	--SP-specific parameters
	@DemoYN bit = 1,
	@ProductKey nvarchar(17) = NULL, 
	@Email nvarchar(100) = NULL,
	@UserNameAD nvarchar(100) = NULL,
	@UserNameDisplay nvarchar(100) = NULL,
	@CustomerName nvarchar(50) = NULL,
	@ApplicationName nvarchar(100) = NULL,
	@LocaleID int = -41,
	@StartYear int = NULL, 
	@AddYear int = NULL,
	@FiscalYearStartMonth int = 1,
	@FiscalYearNaming int = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000233,
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
	@ProcedureName = 'spPortalAdminCreate_NewInstance',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminCreate_NewInstance] 
	@UserID = NULL,
	@InstanceID = NULL,
	@VersionID = NULL,
	@DemoYN = 1,
	@ProductKey = 'Z1K1K-2P10C-90114', 
	@Email = 'jan.wogel@dspanel.com',
	@UserNameDisplay = 'Jan Wogel',
	@CustomerName = 'TestJaWo1',
	@ApplicationName = 'TestJaWo1',
	@Debug = 1

EXEC [spPortalAdminCreate_NewInstance] 
	@UserID = NULL,
	@InstanceID = NULL,
	@VersionID = NULL,
	@DemoYN = 1,
	@ProductKey = 'EPICOR_INSIGHTS', 
	@Email = 'tuf@efp.cloud',
	@UserNameDisplay = 'tuf',
	@CustomerName = 'Tuffaloy',
	@ApplicationName = 'TUF',
	@Debug = 1

EXEC [spPortalAdminCreate_NewInstance] 
	@UserID = NULL,
	@InstanceID = 424,
	@VersionID = 1012,
	@DemoYN = 0,
	@ProductKey = 'Z1K1K-2P10C-90114', 
	@Email = 'jan.morath@dspanel.com',
	@UserNameDisplay = 'Jan Morath',
	@CustomerName = 'Heartland',
	@ApplicationName = 'Heartland',
	@Debug = 1

EXEC [spPortalAdminCreate_NewInstance] 
	@UserID = -100,
	@InstanceID = 442,
	@VersionID = 1014,
	@DemoYN = 0,
	@ProductKey = 'E1TV0-5A10A-E0511', 
	@Email = 'jan.wogel@dspanel.com',
	@UserNameDisplay = 'Jan Wogel',
	@CustomerName = 'Satco',
	@ApplicationName = 'Satco',
	@Debug = 1

EXEC [spPortalAdminCreate_NewInstance]
	@ApplicationName='DBD03',
	@CustomerName='DBDEMO03',
	@DemoYN='1',
	@Email='dbd03@efp.cloud',
	@ProductKey='EPICOR_INSIGHTS',
	@UserNameAD='dev\dbd03.dbd03',
	@UserNameDisplay='dbd03',
	@Debug = 1

EXEC [spPortalAdminCreate_NewInstance] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@CompanyTypeID int,
	@CustomerID int,
	@ApplicationID int,
	@ModelID_Financials int,
	@ModelID_Financials_Detail int,
	@ModelID_FxRate int,	
--	@AdminGroupID int,
--	@FullAccessGroupID int,
	--@ReportAccessGroupID int,
	@AdminUserID int,
	@AdminRoleID int = -1,
	@FullAccessRoleID int = -2,
	--@ReportAccessRoleID int,
	@ObjectID_pcPortal int,
	@ObjectID_Callisto int,
	@ObjectID_Application int,
	@SQLStatement nvarchar(max),

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create New Instance',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2145' SET @Description = 'Remove all references of ReportAccess Group and Instance-specific Security Roles.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-313: Added parameters related to Calendar and Time Logic settings.'
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
			@Selected = ISNULL(@Selected, 0),
			@UserID = ISNULL(@UserID, -100),
			@InstanceID = ISNULL(@InstanceID, -100),
			@VersionID = ISNULL(@VersionID, -100)

		SET @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@StartYear = ISNULL(@StartYear,YEAR(GETDATE()) - 5),
			@AddYear = ISNULL(@AddYear, 2)


	SET @Step = 'Check if Instance name is already used.'
		IF ISNULL(@InstanceID, -100) = -100
			IF (SELECT COUNT(1) FROM [Instance] WHERE InstanceName = @CustomerName) > 0
				BEGIN
					SET @Message = 'The Instance name ' + @CustomerName + ' is already in use. Choose another Instance name.'
					SET @Severity = 16
					GOTO EXITPOINT
				END

	SET @Step = 'Check if Application name is already used.'
		IF ISNULL(@InstanceID, -100) = -100
			IF (SELECT COUNT(1) FROM [Application] WHERE ApplicationName = @ApplicationName) > 0
				BEGIN
					SET @Message = 'The Application name ' + @ApplicationName + ' is already in use. Choose another Application name.'
					SET @Severity = 16
					GOTO EXITPOINT
				END

	SET @Step = 'Check if VersionID already exists for selected InstanceID.'
		IF (SELECT COUNT(1) FROM [Version] WHERE InstanceID = @InstanceID) > 0
			BEGIN
				SET @Message = 'The selected Instance is already set up. Choose another Instance.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create Customer'
		IF @DemoYN = 0 AND @InstanceID IS NOT NULL
			BEGIN
				SELECT 
					@CustomerID = I.[CustomerID],
					@CustomerName = ISNULL(@CustomerName, C.[CustomerName]),
					@CompanyTypeID = C.[CompanyTypeID]
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.Instance I
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.Customer C ON C.CustomerID = I.CustomerID
				WHERE
					InstanceID = @InstanceID
			END
		ELSE IF ISNULL(@InstanceID, -100) = -100
			BEGIN
				SELECT @CustomerID = MIN(CustomerID) - 1 FROM Customer WHERE CustomerID < -1000
				SELECT
					@CustomerID = ISNULL(@CustomerID, -1001),
					@CompanyTypeID = 3 --Trial
			END

		SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] ON
		
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Customer]
			(
			[CustomerID],
			[CustomerName],
			[CustomerDescription],
			[CompanyTypeID]
			)
		SELECT
			[CustomerID] = @CustomerID,
			[CustomerName] = @CustomerName,
			[CustomerDescription] = @CustomerName,
			[CompanyTypeID] = @CompanyTypeID
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Customer] C WHERE C.CustomerID = @CustomerID)

		SET @Inserted = @Inserted + @@ROWCOUNT

		SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] OFF

	SET @Step = 'Create Instance'
		IF ISNULL(@InstanceID, -100) = -100
			BEGIN
				SELECT @InstanceID = MIN(InstanceID) - 1 FROM Instance WHERE InstanceID < -1000
				SET @InstanceID = ISNULL(@InstanceID, -1001)
			END

			SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] ON
		
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Instance]
				(
				[InstanceID],
				[InstanceName],
				[InstanceDescription],
				[CustomerID],
				[StartYear],
				[AddYear],
				[FiscalYearStartMonth],
				[FiscalYearNaming],
				[ProductKey],
				[pcPortal_URL],
				[Mail_ProfileName],
				[Rows],
				[Nyc],
				[Nyu]
				)
			SELECT
				[InstanceID] = @InstanceID,
				[InstanceName] = @CustomerName,
				[InstanceDescription] = @CustomerName,
				[CustomerID] = @CustomerID,
				[StartYear] = @StartYear,
				[AddYear] = @AddYear,
				[FiscalYearStartMonth] = @FiscalYearStartMonth,
				[FiscalYearNaming] = 0,
				[ProductKey] = @ProductKey,
				[pcPortal_URL] = 'my.performancecanvas.com',
				[Mail_ProfileName] = 'Mailgun',
				[Rows] = 10000,
				[Nyc] = 8256,
				[Nyu] = '86|0|-516|-172'
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Instance] I WHERE I.InstanceID = @InstanceID)

			SET @Inserted = @Inserted + @@ROWCOUNT

			SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] OFF

	SET @Step = 'Create Version'
		IF @Debug <> 0 SELECT [@DemoYN] = @DemoYN, [@VersionID] = @VersionID
		IF @DemoYN <> 0 AND ISNULL(@VersionID, -100) = -100
			BEGIN
				SELECT @VersionID = MIN(VersionID) - 1 FROM [Version] WHERE VersionID < -1000
				SET @VersionID = ISNULL(@VersionID, -1001)

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Version] ON
		
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Version]
					(
					[InstanceID],
					[VersionID],
					[VersionName],
					[VersionDescription],
					[EnvironmentLevelID],
					[ErasableYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[VersionName] = 'Production',
					[VersionDescription] = 'Production',
					[EnvironmentLevelID] = 0,
					[ErasableYN] = 1

				SET @Inserted = @Inserted + @@ROWCOUNT
		
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Version] OFF
			END
		ELSE IF ISNULL(@VersionID, -100) = -100
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Version]
					(
					[InstanceID],
					[VersionName],
					[VersionDescription],
					[EnvironmentLevelID],
					[ErasableYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionName] = 'Production',
					[VersionDescription] = 'Production',
					[EnvironmentLevelID] = 0,
					[ErasableYN] = 0

				SET @Inserted = @Inserted + @@ROWCOUNT
				
				SELECT @VersionID = MAX(VersionID) FROM [pcINTEGRATOR_Data].[dbo].[Version] WHERE [InstanceID] = @InstanceID
			END

	SET @Step = 'Create Application'
		IF (SELECT COUNT(1) FROM [Application] WHERE InstanceID = @InstanceID AND VersionID = @VersionID) > 0
			SELECT @ApplicationID = MAX(ApplicationID) FROM [Application] WHERE InstanceID = @InstanceID AND VersionID = @VersionID
		ELSE IF @DemoYN <> 0
			BEGIN
				SELECT @ApplicationID = MIN(ApplicationID) - 1 FROM [Application] WHERE ApplicationID < -1000
				SET @ApplicationID = ISNULL(@ApplicationID, -1001)

				IF @Debug <> 0
					SELECT
						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[ApplicationID] = @ApplicationID

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Application] ON
		
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Application]
					(
					[ApplicationID],
					[ApplicationName],
					[ApplicationDescription],
					[ApplicationServer],
					[InstanceID],
					[VersionID],
					[ETLDatabase],
					[DestinationDatabase],
					[AdminUser],
					[FiscalYearStartMonth],
					[LanguageID]
					)
				SELECT
					[ApplicationID] = @ApplicationID,
					[ApplicationName] = @ApplicationName,
					[ApplicationDescription] = @ApplicationName,
					[ApplicationServer] = 'localhost',
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ETLDatabase] = 'pcETL_' + @ApplicationName,
					[DestinationDatabase] = 'pcDATA_' + @ApplicationName,
					[AdminUser] = 'LIVE\' + @ApplicationName + '.' + @UserNameDisplay,
					[FiscalYearStartMonth] = @FiscalYearStartMonth,
					[LanguageID] = 1

				SET @Inserted = @Inserted + @@ROWCOUNT

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Application] OFF
			END
		ELSE
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Application]
					(
					[ApplicationName],
					[ApplicationDescription],
					[ApplicationServer],
					[InstanceID],
					[VersionID],
					[ETLDatabase],
					[DestinationDatabase],
					[AdminUser],
					[FiscalYearStartMonth],
					[LanguageID]
					)
				SELECT
					[ApplicationName] = @ApplicationName,
					[ApplicationDescription] = @ApplicationName,
					[ApplicationServer] = 'localhost',
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ETLDatabase] = 'pcETL_' + @ApplicationName,
					[DestinationDatabase] = 'pcDATA_' + @ApplicationName,
					[AdminUser] = 'LIVE\' + @ApplicationName + '.' + @UserNameDisplay,
					[FiscalYearStartMonth] = @FiscalYearStartMonth,
					[LanguageID] = 1

				SET @Inserted = @Inserted + @@ROWCOUNT
				
				SELECT @ApplicationID = MAX([ApplicationID]) FROM [pcINTEGRATOR_Data].[dbo].[Application] WHERE [InstanceID] = @InstanceID
			END

	SET @Step = 'Create Model'
		IF (SELECT COUNT(1) FROM [Model] WHERE ApplicationID = @ApplicationID) = 0
			BEGIN
				SELECT @ModelID_Financials = MIN(ModelID) - 1 FROM [Model] WHERE ModelID < -1000
				SET @ModelID_Financials = ISNULL(@ModelID_Financials, -1001)
				SET @ModelID_Financials_Detail = @ModelID_Financials - 1
				SET @ModelID_FxRate = @ModelID_Financials_Detail - 1

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Model] ON
		
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Model]
					(
					[InstanceID],
					[VersionID],
					[ModelID],
					[ModelName],
					[ModelDescription],
					[ApplicationID],
					[BaseModelID]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ModelID] = @ModelID_Financials,
					[ModelName] = ModelName,
					[ModelDescription] = ModelDescription,
					[ApplicationID] = @ApplicationID,
					[BaseModelID] = -7
				FROM
					[Model]
				WHERE
					ModelID = -7

				UNION
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ModelID] = @ModelID_Financials_Detail,
					[ModelName] = ModelName,
					[ModelDescription] = ModelDescription,
					[ApplicationID] = @ApplicationID,
					[BaseModelID] = -8
				FROM
					[Model]
				WHERE
					ModelID = -8

				UNION
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ModelID] = @ModelID_FxRate,
					[ModelName] = ModelName,
					[ModelDescription] = ModelDescription,
					[ApplicationID] = @ApplicationID,
					[BaseModelID] = -3
				FROM
					[Model]
				WHERE
					ModelID = -3

				SET @Inserted = @Inserted + @@ROWCOUNT
		
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Model] OFF
			END
		ELSE
			BEGIN
				SELECT @ModelID_Financials = ModelID FROM [Model] WHERE ApplicationID = @ApplicationID AND BaseModelID = -7
				SELECT @ModelID_Financials_Detail = ModelID FROM [Model] WHERE ApplicationID = @ApplicationID AND BaseModelID = -8
				SELECT @ModelID_FxRate = ModelID FROM [Model] WHERE ApplicationID = @ApplicationID AND BaseModelID = -3
			END

	--SET @Step = 'Insert Groups into table User'
	--	INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
	--		(
	--		[InstanceID],
	--		[UserName],
	--		[UserNameAD],
	--		[UserNameDisplay],
	--		[UserTypeID],
	--		[UserLicenseTypeID],
	--		[LocaleID],
	--		[LanguageID],
	--		[ObjectGuiBehaviorBM],
	--		[InheritedFrom]
	--		)
	--	SELECT
	--		[InstanceID] = @InstanceID,
	--		[UserName],
	--		[UserNameAD],
	--		[UserNameDisplay],
	--		[UserTypeID],
	--		[UserLicenseTypeID],
	--		[LocaleID],
	--		[LanguageID],
	--		[ObjectGuiBehaviorBM],
	--		[InheritedFrom] = [UserID]
	--	FROM
	--		[pcINTEGRATOR].[dbo].[@Template_User] TU
	--	WHERE
	--		TU.InstanceID = @SourceInstanceID AND
	--		NOT EXISTS (SELECT 1 FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.InheritedFrom = TU.UserID)

	--	SELECT @Inserted = @Inserted + @@ROWCOUNT

	--	SELECT @AdminGroupID = ISNULL(@AdminGroupID, U.UserID) FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.[InstanceID] = @InstanceID AND U.[InheritedFrom] = -1
	--	SELECT @FullAccessGroupID = ISNULL(@FullAccessGroupID, U.UserID) FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.[InstanceID] = @InstanceID AND U.[InheritedFrom] = -2

/*
	SET @Step = 'Insert Group into table User - AdminGroup'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
			(
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserNameDisplay],
			[UserTypeID],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserName] = @ApplicationName + ' - AdminGroup',
			[UserNameAD] = NULL,
			[UserNameDisplay] = @ApplicationName + ' - Admin Group',
			[UserTypeID] = -2, --Group
			[UserLicenseTypeID] = 1 
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - AdminGroup' AND U.[DeletedID] IS NULL)

		SELECT	@Inserted = @Inserted + @@ROWCOUNT
		SELECT @AdminGroupID = ISNULL(@AdminGroupID, U.UserID) FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - AdminGroup' AND U.[DeletedID] IS NULL

	SET @Step = 'Insert Group into table User - FullAccessGroup'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
			(
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserNameDisplay],
			[UserTypeID],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserName] = @ApplicationName + ' - FullAccessGroup',
			[UserNameAD] = NULL,
			[UserNameDisplay] = @ApplicationName + ' - Full Access Group',
			[UserTypeID] = -2, --Group
			[UserLicenseTypeID] = 1
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - FullAccessGroup' AND U.[DeletedID] IS NULL)

		SELECT @Inserted = @Inserted + @@ROWCOUNT
		SELECT @FullAccessGroupID = ISNULL(@FullAccessGroupID, U.UserID) FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - FullAccessGroup' AND U.[DeletedID] IS NULL
*/

	SET @Step = 'Create User'
		IF @Debug <> 0 SELECT UserID = @UserID
		IF @UserID = -100
			BEGIN
				IF @DemoYN = 0
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
							(
							[InstanceID],
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
							[UserName] = @Email,
							[UserNameAD] = @UserNameAD,
							[UserNameDisplay] = @UserNameDisplay,
							[UserTypeID] = -1,
							[UserLicenseTypeID] = -1,
							[LocaleID] = @LocaleID,
							[LanguageID] = 1,
							[ObjectGuiBehaviorBM] = 3
						WHERE
							NOT EXISTS (SELECT 1 FROM [User] U WHERE U.InstanceID = @InstanceID AND U.[UserName] = @Email)

						SET @UserID = @@IDENTITY

						IF @UserID <> (SELECT MAX(UserID) FROM [pcINTEGRATOR_Data].[dbo].[User])
							SELECT @UserID = MAX(UserID) FROM [pcINTEGRATOR_Data].[dbo].[User] 

						IF @Debug <> 0 SELECT UserID = @UserID

						IF @UserID = -100 SELECT @UserID = UserID FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.InstanceID = @InstanceID AND U.[UserName] = @Email
					END
				ELSE
					BEGIN
						SELECT @UserID = MIN(UserID) - 1 FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE UserID < -1000
						SET @UserID = ISNULL(@UserID, -1001)

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
							[UserID] = @UserID,
							[UserName] = @Email,
							[UserNameAD] = @UserNameAD,
							[UserNameDisplay] = @UserNameDisplay,
							[UserTypeID] = -1,
							[UserLicenseTypeID] = -1,
							[LocaleID] = @LocaleID,
							[LanguageID] = 1,
							[ObjectGuiBehaviorBM] = 3

						SET @Inserted = @Inserted + @@ROWCOUNT
		
						SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[User] OFF
					END
			END

		--Add email later

	SET @Step = 'Create AdminUser'
		IF @Debug <> 0 SELECT 
							UserID = @UserID--,
--							AdminGroupID = @AdminGroupID,
--							FullAccessGroupID = @FullAccessGroupID

		SET @AdminUserID = @UserID

/*
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
			(
			[InstanceID],
			[UserID_Group],
			[UserID_User]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserID_Group] = @AdminGroupID,
			[UserID_User] = @AdminUserID			
		WHERE
			NOT EXISTS (SELECT 1 FROM [UserMember] UM WHERE UM.[InstanceID] = @InstanceID AND UM.[UserID_Group] = @AdminGroupID AND UM.[UserID_User] = @AdminUserID)

		SET @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
			(
			[InstanceID],
			[UserID_Group],
			[UserID_User]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserID_Group] = @FullAccessGroupID,
			[UserID_User] = @AdminUserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [UserMember] UM WHERE UM.[InstanceID] = @InstanceID AND UM.[UserID_Group] = @FullAccessGroupID AND UM.[UserID_User] = @AdminUserID)

		SET @Inserted = @Inserted + @@ROWCOUNT
*/

	--SET @Step = 'Insert into SecurityRoleUser'
	--	INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
	--		(
	--		[InstanceID],
	--		[SecurityRoleID],
	--		[UserID]
	--		)
	--	SELECT
	--		[InstanceID] = @InstanceID,
	--		[SecurityRoleID] = @AdminRoleID,
	--		[UserID] = @AdminUserID
	--	WHERE
	--		NOT EXISTS (SELECT 1 FROM [SecurityRoleUser] SRU WHERE SRU.[InstanceID] = @InstanceID AND SRU.[SecurityRoleID] = @AdminRoleID AND SRU.[UserID] = @AdminUserID)

	SET @Step = 'Insert into SecurityRoleUser'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
			(
			[InstanceID],
			[SecurityRoleID],
			[UserID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @AdminRoleID,
--			[UserID] = @AdminGroupID
			[UserID] = @AdminUserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [SecurityRoleUser] SRU WHERE SRU.[InstanceID] = @InstanceID AND SRU.[SecurityRoleID] = @AdminRoleID AND SRU.[UserID] = @AdminUserID)

		SET @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
			(
			[InstanceID],
			[SecurityRoleID],
			[UserID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
--			[UserID] = @FullAccessGroupID
			[UserID] = @AdminUserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [SecurityRoleUser] SRU WHERE SRU.[InstanceID] = @InstanceID AND SRU.[SecurityRoleID] = @FullAccessRoleID AND SRU.[UserID] = @AdminUserID)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Object'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM] = 60
		FROM
			[Object] S
		WHERE
			S.[InstanceID] = 0 AND
			S.[ObjectID] = -1 AND --pcPortal
			NOT EXISTS (SELECT 1 FROM [Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = S.ObjectName AND O.[ObjectTypeBM] & S.ObjectTypeBM > 0)

		SELECT
			@ObjectID_pcPortal = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @ObjectID_pcPortal = ISNULL(@ObjectID_pcPortal, O.ObjectID)
		FROM [Object] O INNER JOIN [Object] S ON S.[InstanceID] = 0 AND S.ObjectID = -1 AND S.[ObjectName] = O.ObjectName AND S.[ObjectTypeBM] & O.ObjectTypeBM > 0
		WHERE O.[InstanceID] = @InstanceID
--
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID] = @ObjectID_pcPortal,
			[SecurityLevelBM] = 60
		FROM
			[Object] S
		WHERE
			S.[InstanceID] = 0 AND
			S.[ObjectID] = -2 AND --Callisto
			NOT EXISTS (SELECT 1 FROM [Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = S.ObjectName AND O.[ObjectTypeBM] & S.ObjectTypeBM > 0)

		SELECT
			@ObjectID_Callisto = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @ObjectID_Callisto = ISNULL(@ObjectID_Callisto, O.ObjectID)
		FROM [Object] O INNER JOIN [Object] S ON S.[InstanceID] = 0 AND S.ObjectID = -2 AND S.[ObjectName] = O.ObjectName AND S.[ObjectTypeBM] & O.ObjectTypeBM > 0
		WHERE O.[InstanceID] = @InstanceID
--
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName] = @ApplicationName, 
			[ObjectTypeBM] = 256,  --Application
			[ParentObjectID] = @ObjectID_Callisto,
			[SecurityLevelBM] = 60
		WHERE
			NOT EXISTS (SELECT 1 FROM [Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = @ApplicationName AND O.[ObjectTypeBM] & 256 > 0)

		SELECT
			@ObjectID_Application = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @ObjectID_Application = ISNULL(@ObjectID_Application, O.ObjectID)
		FROM [Object] O 
		WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = @ApplicationName AND O.[ObjectTypeBM] & 256 > 0

--
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName] = M.ModelName, 
			[ObjectTypeBM] = 1,  --Model
			[ParentObjectID] = @ObjectID_Application,
			[SecurityLevelBM] = 60
		FROM
			[Application] A
			INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
		WHERE
			A.InstanceID = @InstanceID AND
			A.ApplicationName = @ApplicationName AND
			A.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM [Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = M.ModelName AND O.[ObjectTypeBM] & 1 > 0)

		SELECT @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName] = 'Scenario', 
			[ObjectTypeBM] = 2,  --Scenario / Application / Read
			[ParentObjectID] = @ObjectID_Application,
			[SecurityLevelBM] = 32
		WHERE
			NOT EXISTS (SELECT 1 FROM [Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = 'Scenario' AND O.[ObjectTypeBM] & 2 > 0)

		SELECT @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName] = 'Scenario', 
			[ObjectTypeBM] = 2,  --Scenario / Model / Write
			[ParentObjectID] = S.ObjectID,
			[SecurityLevelBM] = 16
		FROM
			[Object] S
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[ObjectTypeBM] & 1 > 0 AND
			NOT EXISTS (SELECT 1 FROM [Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = 'Scenario' AND O.[ObjectTypeBM] & 2 > 0 AND O.[ParentObjectID] = S.ObjectID)

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into SecurityRoleObject'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID],
			[SecurityRoleID] = @AdminRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 60
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 448 > 0 AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.[SecurityRoleID] = @AdminRoleID AND SRO.[ObjectID] = O.[ObjectID])

	SET @Step = 'Insert into SecurityRoleObject (Features)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
		FROM
			[pcINTEGRATOR].[dbo].[@Template_SecurityRoleObject] TEMP
		WHERE
			TEMP.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.InstanceID = @InstanceID AND SRO.[SecurityRoleID] = TEMP.SecurityRoleID AND SRO.[ObjectID] = TEMP.ObjectID)

		SELECT @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 40
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 449 > 0 AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.InstanceID = @InstanceID AND SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 32
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 3 > 0 AND
			O.ParentObjectID = @ObjectID_Application AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.InstanceID = @InstanceID AND SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 16
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 2 > 0 AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.InstanceID = @InstanceID AND SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 1
		FROM
			[Object] O
		WHERE
			O.InstanceID = 0 AND
			O.ObjectTypeBM & 1024 > 0 AND
			O.ObjectID IN (-6, -7) AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.InstanceID = @InstanceID AND SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Scenario'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Scenario]
			(
			[InstanceID],
			[VersionID],
			[MemberKey],
			[ScenarioTypeID],
			[ScenarioName],
			[ScenarioDescription],
			[ActualOverwriteYN],
			[AutoRefreshYN],
			[InputAllowedYN],
			[AutoSaveOnCloseYN],
			[ClosedMonth],
			[SortOrder],
			[InheritedFrom],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[MemberKey],
			[ScenarioTypeID],
			[ScenarioName],
			[ScenarioDescription],
			[ActualOverwriteYN],
			[AutoRefreshYN],
			[InputAllowedYN],
			[AutoSaveOnCloseYN],
			[ClosedMonth],
			[SortOrder],
			[InheritedFrom] = S.ScenarioID,
			[SelectYN]
		FROM
			[Scenario] S
		WHERE
			[InstanceID] = @SourceInstanceID AND
			[VersionID] = @SourceVersionID AND
			[SelectYN] <> 0 AND
			NOT EXISTS (SELECT 1 FROM [Scenario] SD WHERE SD.[InstanceID] = @InstanceID AND SD.[VersionID] = @VersionID AND SD.[MemberKey] = S.[MemberKey])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Workflow'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow]
			(
			[InstanceID],
			[VersionID],
			[WorkflowName],
			[ProcessID],
			[ScenarioID],
			[CompareScenarioID],
			[TimeFrom],
			[TimeTo],
			[TimeOffsetFrom],
			[TimeOffsetTo],
			[InitialWorkflowStateID],
			[RefreshActualsInitialWorkflowStateID],
			[SpreadingKeyID],
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom],
			[SelectYN],
			[DeletedID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowName] = WF.[WorkflowName],
--			[ProcessID] = P.ProcessID,
			[ProcessID] = 0,
			[ScenarioID] = S.ScenarioID,
			[CompareScenarioID] = CS.ScenarioID,
			[TimeFrom] = WF.[TimeFrom],
			[TimeTo] = WF.[TimeTo],
			[TimeOffsetFrom] = WF.[TimeOffsetFrom],
			[TimeOffsetTo] = WF.[TimeOffsetTo],
			[InitialWorkflowStateID] = WF.[InitialWorkflowStateID],
			[RefreshActualsInitialWorkflowStateID] = WF.[RefreshActualsInitialWorkflowStateID],
			[SpreadingKeyID] = WF.[SpreadingKeyID],
			[ModelingStatusID] = WF.[ModelingStatusID],
			[ModelingComment] = WF.[ModelingComment],
			[InheritedFrom] = WF.WorkflowID,
			[SelectYN] = 1,
			[DeletedID] = NULL
		FROM
			[Workflow] WF
--			INNER JOIN [Process] P ON P.InstanceID = @InstanceID AND P.VersionID = @VersionID AND P.InheritedFrom = WF.[ProcessID]
			INNER JOIN [Scenario] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.InheritedFrom = WF.[ScenarioID]
			INNER JOIN [Scenario] CS ON CS.InstanceID = @InstanceID AND CS.VersionID = @VersionID AND CS.InheritedFrom = WF.[CompareScenarioID]
		WHERE
			WF.InstanceID = @SourceInstanceID AND
			WF.VersionID = @SourceVersionID AND
			NOT EXISTS (SELECT 1 FROM [Workflow] WFD WHERE WFD.InstanceID = @InstanceID AND WFD.VersionID = @VersionID AND WFD.ScenarioID = S.[ScenarioID])

	SET @Step = 'Insert into WorkflowState'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowState]
			(
			[InstanceID],
			[WorkflowID],
			[WorkflowStateName],
			[InheritedFrom]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[WorkflowID] = WF.WorkflowID,
			[WorkflowStateName] = WS.[WorkflowStateName],
			[InheritedFrom] = WS.[WorkflowStateId]
		FROM
			[WorkflowState] WS
			INNER JOIN [Workflow] WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WS.WorkflowID
		WHERE
			WS.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [WorkflowState] WSD WHERE WSD.InstanceID = @InstanceID AND WSD.[WorkflowID] = WF.WorkflowID AND WSD.[WorkflowStateName] = WS.[WorkflowStateName])
		ORDER BY
			WS.[WorkflowStateId] DESC

	SET @Step = 'UPDATE [Workflow].[InitialWorkflowStateID]'
		UPDATE WF
		SET
			[InitialWorkflowStateID] = WS.[WorkflowStateID],
			[RefreshActualsInitialWorkflowStateID] = RAWS.[WorkflowStateID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow] WF
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WS ON WS.InstanceID = @InstanceID AND WS.InheritedFrom = WF.[InitialWorkflowStateID]
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] RAWS ON RAWS.InstanceID = @InstanceID AND RAWS.InheritedFrom = WF.[RefreshActualsInitialWorkflowStateID]
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID

	SET @Step = 'INSERT INTO [OrganizationHierarchy]'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy]
			(
			[InstanceID],
			[VersionID],
			[OrganizationHierarchyName],
			[LinkedDimensionID],
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom],
			[DeletedID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[OrganizationHierarchyName],
			[LinkedDimensionID] = NULL,
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom] = OH.[OrganizationHierarchyID],
			[DeletedID]
		FROM
			[OrganizationHierarchy] OH
		WHERE
			InstanceID = @SourceInstanceID AND
			VersionID = @SourceVersionID AND
			NOT EXISTS (SELECT 1 FROM [OrganizationHierarchy] OHD WHERE OHD.InstanceID = @InstanceID AND OHD.VersionID = @VersionID AND OHD.[OrganizationHierarchyName] = OH.[OrganizationHierarchyName])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into OrganizationLevel'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationLevel]
			(
			[InstanceID],
			[VersionID],
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[OrganizationLevelName]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[OrganizationLevelNo] = OL.[OrganizationLevelNo],
			[OrganizationLevelName] = OL.[OrganizationLevelName]
		FROM
			[OrganizationLevel] OL
			INNER JOIN [OrganizationHierarchy] OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = OL.OrganizationHierarchyID
		WHERE
			OL.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [OrganizationLevel] OLD WHERE OLD.InstanceID = @InstanceID AND OLD.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND OLD.[OrganizationLevelNo] = OL.[OrganizationLevelNo])

	SET @Step = 'Insert into WorkflowStateChange'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[FromWorkflowStateID],
			[ToWorkflowStateID],
			[UserChangeableYN],
			[BRChangeableYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowID] = WF.WorkflowID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[OrganizationLevelNo] = WSC.[OrganizationLevelNo],
			[FromWorkflowStateID] = FWS.WorkflowStateID,
			[ToWorkflowStateID] = TWS.WorkflowStateID,
			[UserChangeableYN] = WSC.[UserChangeableYN],
			[BRChangeableYN] = WSC.[BRChangeableYN]
		FROM
			[WorkflowStateChange] WSC
			INNER JOIN [Workflow] WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WSC.WorkflowID
			INNER JOIN [OrganizationHierarchy] OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = WSC.OrganizationHierarchyID
			INNER JOIN [WorkflowState] FWS ON FWS.InstanceID = @InstanceID AND FWS.InheritedFrom = WSC.FromWorkflowStateid
			INNER JOIN [WorkflowState] TWS ON TWS.InstanceID = @InstanceID AND TWS.InheritedFrom = WSC.ToWorkflowStateid
		WHERE
			WSC.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [WorkflowStateChange] WSCD WHERE WSCD.[InstanceID] = @InstanceID AND WSCD.[WorkflowID] = WF.WorkflowID AND WSCD.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND WSCD.[OrganizationLevelNo] = WSC.[OrganizationLevelNo] AND WSCD.[FromWorkflowStateID] = FWS.WorkflowStateID AND WSCD.[ToWorkflowStateID] = TWS.WorkflowStateID)

	SET @Step = 'Insert into Workflow_OrganizationLevel'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow_OrganizationLevel]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[OrganizationLevelNo],
			[LevelInWorkflowYN],
			[ExpectedDate],
			[ActionDescription]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowID] = WF.WorkflowID,
			[OrganizationLevelNo] = WOL.[OrganizationLevelNo],
			[LevelInWorkflowYN] = WOL.[LevelInWorkflowYN],
			[ExpectedDate] = WOL.[ExpectedDate],
			[ActionDescription] = WOL.[ActionDescription]
		FROM
			[Workflow_OrganizationLevel] WOL
			INNER JOIN [Workflow] WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WOL.WorkflowID
		WHERE
			WOL.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [Workflow_OrganizationLevel] WOLD WHERE WOLD.[InstanceID] = @InstanceID AND WOLD.[WorkflowID] = WF.WorkflowID AND WOLD.[OrganizationLevelNo] = WOL.[OrganizationLevelNo])

	SET @Step = 'Insert into WorkflowAccessRight'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowAccessRight]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[WorkflowStateID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowID] = WF.WorkflowID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[OrganizationLevelNo] = WAR.[OrganizationLevelNo],
			[WorkflowStateID] = WS.[WorkflowStateID],
			[SecurityLevelBM] = WAR.[SecurityLevelBM]
		FROM
			[WorkflowAccessRight] WAR
			INNER JOIN [Workflow] WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WAR.WorkflowID
			INNER JOIN [OrganizationHierarchy] OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = WAR.OrganizationHierarchyID
			INNER JOIN [WorkflowState] WS ON WS.InstanceID = @InstanceID AND WS.InheritedFrom = WAR.WorkflowStateid
		WHERE
			WAR.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [WorkflowAccessRight] WARD WHERE WARD.[InstanceID] = @InstanceID AND WARD.[WorkflowID] = WF.WorkflowID AND WARD.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND WARD.[OrganizationLevelNo] = WAR.[OrganizationLevelNo] AND WARD.[WorkflowStateID] = WS.[WorkflowStateID])

	SET @Step = 'Insert into Workflow_LiveFcstNextFlow'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[LiveFcstNextFlowID],
			[WorkflowStateID]
			)
		SELECT
			WS.[InstanceID],
			[VersionID] = @VersionID,
			WS.[WorkflowID],
			[LiveFcstNextFlowID] = CASE WS.InheritedFrom WHEN -120 THEN 1 WHEN -121 THEN 2 WHEN -125 THEN 3 END,
			WS.[WorkflowStateID]
		FROM
			[WorkflowState] WS
		WHERE
			WS.InstanceID = @InstanceID AND
			WS.InheritedFrom IN (-120, -121, -125) AND
			NOT EXISTS (SELECT 1 FROM [Workflow_LiveFcstNextFlow] WLFNC WHERE WLFNC.WorkflowID = WS.WorkflowID AND WLFNC.[LiveFcstNextFlowID] = CASE WS.InheritedFrom WHEN -120 THEN 1 WHEN -121 THEN 2 WHEN -125 THEN 3 END)

	SET @Step = 'Return information'
		SELECT
			[@AssignedUserID] = @UserID,
			[@AssignedInstanceID] = @InstanceID,
			[@AssignedVersionID] = @VersionID

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
