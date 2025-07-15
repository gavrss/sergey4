SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_User_Group]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignedUserID int = NULL,
	@AssignedInstanceID int = NULL,
	@ResultTypeBM int = 511,
		-- 1 = List of Users
		-- 2 = List of Groups
		-- 4 = List of Fixed User Properties / User Settings
		-- 8 = List of Dynamic User Properties / User Settings
		--16 = List of User/Group Members / Group Settings
		--32 = List of LicenseType
		--64 = List of Locale
		--128 = List of Language
		--256 = List of UserTypes

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000437,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_User_Group',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_User_Group] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM=3, @AssignedUserID = 6572
EXEC [spPortalAdminGet_User_Group] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM=511, @Debug=1 --ERP10
EXEC [spPortalAdminGet_User_Group] @UserID=-10, @InstanceID=413, @VersionID=1009, @ResultTypeBM=511, @Debug=1 --CBN
EXEC [spPortalAdminGet_User_Group] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM=511, @AssignedUserID = 6588, @Debug=1 --AdminGroup
EXEC [spPortalAdminGet_User_Group] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM=511, @AssignedUserID = 6572, @Debug=1 --User
EXEC spPortalAdminGet_User_Group @AssignedUserID='9784',@InstanceID='-1125',@ResultTypeBM='15',@UserID='7273',@VersionID='-1125'

EXEC [spPortalAdminGet_User_Group] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@UserTypeID int,
--	@AssignedInstanceID int = NULL,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns data for pcPortal Users and Groups.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-89: Added [HomeInstanceID], [ObjectGuiBehaviorBM] and [InstanceDescription]. DB-93: DEV: Rename to column *EnabledYN* on @ResultTypeBM=4. DB-96: Show both enabled and disabled User/Group, DB-99 Look for users in view instead of pcINTEGRATOR_Data.dbo.User'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-140: Added [LicenseType] and [InstanceName] for @ResulTypeBM = 1 and 2. Added @AssignedInstanceID and SelectYN for ResultTypeBM = 8. Email added.'
		IF @Version = '2.0.2.2149' SET @Description = 'DB-219: Added @AssignedInstanceID as a parameter.'
		IF @Version = '2.0.3.2151' SET @Description = 'Update User info for Partner Users. Temporarily disabled call to [spGet_PartnerUser].'
		IF @Version = '2.1.0.2158' SET @Description = 'Only show users from [User_Instance] with correct InstanceID. No test on UserID.'
		IF @Version = '2.1.0.2164' SET @Description = 'DB-561: Added [HomeInstanceYN] and [HomeInstanceID] columns in the resultset of @ResultTypeBM = 4.'
		IF @Version = '2.1.0.2166' SET @Description = 'Modified query for @ResultTypeBM = 16.'
		IF @Version = '2.1.2.2199' SET @Description = 'Updated to latest SP template. FDB-2801: Added [LocaleCode] in @ResultTypeBM & 64 resultset.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1
		
		SELECT @UserTypeID = [UserTypeID] FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE [UserID] = @AssignedUserID

		SELECT
			@AssignedInstanceID = ISNULL(@AssignedInstanceID, InstanceID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[User]
		WHERE
			UserID = @AssignedUserID

		SET @AssignedInstanceID = ISNULL(@AssignedInstanceID, @InstanceID)

		IF @Debug <> 0
			SELECT [@AssignedInstanceID] = @AssignedInstanceID, [@AssignedUserID] = @AssignedUserID, [@UserTypeID] = @UserTypeID

	SET @Step = 'Update user tables for partner users'
		SET ANSI_NULLS ON; SET ANSI_WARNINGS ON; EXEC [pcINTEGRATOR].[dbo].[spGet_PartnerUser] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID
		SET ANSI_WARNINGS OFF

	SET @Step = 'Create and Insert data into temp table #Users'
		IF @ResultTypeBM & 31 > 0
			BEGIN
				CREATE TABLE #Users
					(
					[InstanceID] int,
					[UserID] int,
					[UserName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserNameAD] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserNameDisplay] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Email] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserTypeID] int,
					[UserLicenseTypeID] int,
					[LocaleID] int,
					[LanguageID] int,
					[ObjectGuiBehaviorBM] int,
					[HomeInstanceYN] bit,
					[HomeInstanceID] int,
					[ExpiryDate] date,
					[SelectYN] bit,
					[DeletedID] int
					)

				INSERT INTO #Users
					(
					[InstanceID],
					[UserID],
					[UserName],
					[UserNameAD],
					[UserNameDisplay],
					[Email],
					[UserTypeID],
					[UserLicenseTypeID],
					[LocaleID],
					[LanguageID],
					[ObjectGuiBehaviorBM],
					[HomeInstanceYN],
					[HomeInstanceID],
					[ExpiryDate],
					[SelectYN],
					[DeletedID]
					)
				SELECT 
					U.[InstanceID],
					U.[UserID],
					[UserName],
					[UserNameAD],
					[UserNameDisplay],
					[Email] = ISNULL(UPV.UserPropertyValue, CASE WHEN CHARINDEX('@', U.[UserName]) = 0 THEN NULL ELSE U.[UserName] END),
					[UserTypeID],
					[UserLicenseTypeID] = CASE WHEN ISNULL([UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END,
					[LocaleID],
					[LanguageID],
					[ObjectGuiBehaviorBM],
					[HomeInstanceYN] = 1,
					[HomeInstanceID] = U.[InstanceID],
					[ExpiryDate] = NULL,
					U.[SelectYN],
					[DeletedID]
				FROM 
					[pcINTEGRATOR].[dbo].[User] U
					LEFT JOIN [UserPropertyValue] UPV ON UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -3 AND UPV.SelectYN <> 0
				WHERE 
					(U.[InstanceID] = @AssignedInstanceID OR U.[UserID] = @AssignedUserID) AND
					[DeletedID] IS NULL
				UNION
				SELECT 
					UI.[InstanceID],
					UI.[UserID],
					U.[UserName],
					U.[UserNameAD],
					U.[UserNameDisplay],
					[Email] = ISNULL(UPV.UserPropertyValue, CASE WHEN CHARINDEX('@', U.[UserName]) = 0 THEN NULL ELSE U.[UserName] END),
					U.[UserTypeID],
					[UserLicenseTypeID] = CASE WHEN ISNULL(U.[UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END,
					U.[LocaleID],
					U.[LanguageID],
					U.[ObjectGuiBehaviorBM],
					[HomeInstanceYN] = 0,
					[HomeInstanceID] = U.[InstanceID],
					UI.[ExpiryDate],
					UI.[SelectYN],
					UI.[DeletedID]
				FROM 
					[pcINTEGRATOR].[dbo].[User_Instance] UI
					INNER JOIN [pcINTEGRATOR].[dbo].[User] U ON U.[UserID] = UI.[UserID] AND U.[DeletedID] IS NULL
					LEFT JOIN [UserPropertyValue] UPV ON UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -3 AND UPV.SelectYN <> 0
				WHERE 
					(UI.[InstanceID] = @AssignedInstanceID  OR UI.[UserID] = @AssignedUserID) AND
--					UI.[InstanceID] = @AssignedInstanceID AND
					(UI.[ExpiryDate] > GETDATE() OR UI.[ExpiryDate] IS NULL) AND
					UI.[DeletedID] IS NULL

				IF @Debug <> 0
					SELECT [TempTable] = '#Users', * FROM #Users
			END

	SET @Step = 'List of Users'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 1,
					[InstanceID] = U.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[UserID] = U.[UserID],
					[DisplayName] = U.[UserNameDisplay],
					[UserName] = U.[UserName],
					[ActiveDirectoryName] = U.[UserNameAD],
					[Email] = U.[Email],
					[UserLicenseTypeID] = U.[UserLicenseTypeID],
					[LicenseType] = ULT.[UserLicenseTypeName],
					[EnabledYN] = U.[SelectYN],
					[HomeInstanceYN] = U.[HomeInstanceYN],
					[HomeInstanceID] = U.[HomeInstanceID],
					[ExpiryDate] = U.[ExpiryDate],
					[UserTypeID] = U.[UserTypeID]
				FROM 
					#Users U
					INNER JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID
					INNER JOIN [pcINTEGRATOR].[dbo].[UserLicenseType] ULT ON ULT.UserLicenseTypeID = U.UserLicenseTypeID
				WHERE 
					U.[UserTypeID] = -1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of Groups'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 2,
					[InstanceID] = U.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[UserID] = U.[UserID],
					[DisplayName] = U.[UserNameDisplay],
					[GroupName] = U.[UserName],
					[UserLicenseTypeID] = U.[UserLicenseTypeID],
					[LicenseType] = ULT.[UserLicenseTypeName],
					[EnabledYN] = U.[SelectYN],
					[HomeInstanceYN] = U.[HomeInstanceYN],
					[HomeInstanceID] = U.[HomeInstanceID],
					[ExpiryDate] = U.[ExpiryDate],
					[UserTypeID] = U.[UserTypeID]
				FROM 
					#Users U
					INNER JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID
					INNER JOIN [pcINTEGRATOR].[dbo].[UserLicenseType] ULT ON ULT.UserLicenseTypeID = U.UserLicenseTypeID
				WHERE 
					U.[UserTypeID] = -2 

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of Fixed User Properties / User Settings'
		IF @ResultTypeBM & 4 > 0 
			BEGIN
				SELECT 
					[ResultTypeBM] = 4,
					[InstanceID] = U.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[InstanceDescription] = I.[InstanceDescription],
					[UserID] = U.[UserID],
					[DisplayName] = U.[UserNameDisplay],
					[UserName] = U.[UserName],
					[ActiveDirectoryName] = U.[UserNameAD],
					[UserLicenseTypeID] = U.[UserLicenseTypeID],
					[LicenseType] = ULT.[UserLicenseTypeName],
					[LocaleID] = U.[LocaleID],
					[Locale] = LO.[LocaleName],
					[LanguageID] = U.[LanguageID],
					[Language] = LA.[LanguageName],
					[EnabledYN] = U.[SelectYN],
					[UserTypeID] = U.[UserTypeID],
					[UserTypeName] = UT.[UserTypeName],
					[ObjectGuiBehaviorBM] = U.[ObjectGuiBehaviorBM],
					[HomeInstanceYN] = U.[HomeInstanceYN],
					[HomeInstanceID] = U.[HomeInstanceID]
				FROM 
					#Users U
					INNER JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID
					INNER JOIN [pcINTEGRATOR].[dbo].[UserType] UT ON UT.UserTypeID = U.UserTypeID
					INNER JOIN [pcINTEGRATOR].[dbo].[UserLicenseType] ULT ON ULT.UserLicenseTypeID = U.UserLicenseTypeID
					INNER JOIN [pcINTEGRATOR].[dbo].[Locale] LO ON LO.LocaleID = U.LocaleID
					INNER JOIN [pcINTEGRATOR].[dbo].[Language] LA ON LA.LanguageID = U.LanguageID
				WHERE 
					U.UserID = @AssignedUserID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of Dynamic User Properties / User Settings'
		IF @ResultTypeBM & 8 > 0 
			BEGIN
				SELECT 
					[ResultTypeBM] = 8,
					[PropertyID] = UPT.[UserPropertyTypeID],
					[PropertyName] = UPT.[UserPropertyTypeName],
					[PropertyValue] = UPV.[UserPropertyValue],
					[SelectYN] = UPV.SelectYN
				FROM 
					[pcINTEGRATOR].[dbo].[UserPropertyType] UPT
					LEFT JOIN [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV ON UPV.InstanceID = @AssignedInstanceID AND UPV.UserID = @AssignedUserID AND UPV.UserPropertyTypeID = UPT.UserPropertyTypeID --AND UPV.SelectYN <> 0
				WHERE 
					UPT.InstanceID IN (0, @InstanceID, @AssignedInstanceID) AND
					UPT.SelectYN <> 0 AND
                    UPT.UserPropertyTypeID <> -1001
				ORDER BY
					UPT.[UserPropertyTypeName]

				SET @Selected = @Selected + @@ROWCOUNT
			END
	
	SET @Step = 'List of User/Group Members / Group Settings'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT DISTINCT
					[ResultTypeBM] = 16,
					[InstanceID] = UM.[InstanceID],
					[EnabledYN] = CASE WHEN UM.[SelectYN] <> 0 AND UG.[SelectYN] <> 0 AND UU.[SelectYN] <> 0 THEN 1 ELSE 0 END,
					[UserID_Group] = UM.UserID_Group,
					[DisplayName_Group] = UG.[UserNameDisplay],
					[UserName_Group] = UG.[UserName],
					[UserID_User] = UM.[UserID_User],
					[DisplayName_User] = UU.[UserNameDisplay],
					[UserName_User] = UU.[UserName]
				FROM 
					[pcINTEGRATOR_Data].[dbo].[UserMember] UM
					INNER JOIN #Users UG ON UG.UserID = UM.UserID_Group AND UG.UserTypeID = -2
					INNER JOIN #Users UU ON UU.UserID = UM.UserID_User AND UU.UserTypeID = -1
				WHERE 
					UM.InstanceID = @AssignedInstanceID AND
					((@UserTypeID = -2 AND UM.UserID_Group = @AssignedUserID) OR (@UserTypeID = -1 AND UM.UserID_User = @AssignedUserID))

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of User License Type'
		IF @ResultTypeBM & 32 > 0 
			BEGIN
				SELECT 
					[ResultTypeBM] = 32,
					[UserLicenseTypeID],
					[UserLicenseTypeName],
					[SecurityLevelBM],
					[CallistoRestriction]
				FROM
					[pcINTEGRATOR].[dbo].[UserLicenseType]
				WHERE
					[UserLicenseTypeID] >= 0
			END

	SET @Step = 'List of Locale'
		IF @ResultTypeBM & 64 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 64,
					--[InstanceID],
					[LocaleID],
					[LocaleCode],
					[LocaleName]--,
					--[LanguageID],
					--[CountryID]      
				FROM 
					[pcINTEGRATOR].[dbo].[Locale]
				WHERE 
					[SelectYN] <> 0

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of Language'
		IF @ResultTypeBM & 128 > 0 
			BEGIN
				SELECT
					[ResultTypeBM] = 128,
					[LanguageID],
					[LanguageCode],
					[LanguageName]
				FROM 
					[pcINTEGRATOR].[dbo].[Language]
				WHERE 
					[SelectYN] <> 0

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of UserTypes'
		IF @ResultTypeBM & 256 > 0 
			BEGIN
				SELECT
					[UserTypeID],
					[UserTypeName]
				FROM 
					[pcINTEGRATOR].[dbo].[UserType]	
			
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp table'
		IF @ResultTypeBM & 31 > 0 
			DROP TABLE #Users

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
