SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_User]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,
	
	@UserTypeID int = NULL,
	@AssignedInstanceID int = NULL,
	@AssignedUserID int = NULL OUT,
	@AssignedUserName nvarchar(100) = NULL,
	@DisplayName nvarchar(100) = NULL,
	@ActiveDirectoryName nvarchar(100) = NULL,
	@LicenseTypeID int = 1,
	@LocaleID int = -41,
	@LanguageID int = 1,
	@ObjectGuiBehaviorBM int = 3,
	@ExpiryDate DATE = NULL,
	@EnabledYN bit = 1,
	@DeleteYN bit = 0,

	@JSON_table nvarchar(max) = NULL, -- Dynamic Properties

	--@GivenName nvarchar(100) = NULL,
	--@FamilyName nvarchar(100) = NULL,
	--@Email nvarchar(100) = NULL,
	--@Phone nvarchar(100) = NULL,
	--@RecipientTypeCheckSumAlways nvarchar(100) = NULL,
	--@RecipientTypeCheckSumOnError nvarchar(100) = NULL,
	--@Title nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000435,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
--Add New User
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_User',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"2538"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"UserTypeID", "TValue":"-1"},
		{"TKey":"AssignedUserName", "TValue":"testS.user@dsp.com"},
		{"TKey":"DisplayName", "TValue":"TestSUser"},
		{"TKey":"ActiveDirectoryName", "TValue":"dev\\testS.user"}, -------Backslash should be replaced with \\
		{"TKey":"Debug", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"UserPropertyTypeID":"-1","UserPropertyValue":"TestGivenName","DeleteYN":"0"},
		{"UserPropertyTypeID":"-2","UserPropertyValue":"TestFamilyName","DeleteYN":"0"}
		]'

--Add New Group
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_User',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"2538"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"UserTypeID", "TValue":"-2"},
		{"TKey":"AssignedUserName", "TValue":"TestGroup"},
		{"TKey":"DisplayName", "TValue":"TestGroup"},
		{"TKey":"Debug", "TValue":"1"}
		]'

--Update User/Group
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_User',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"2538"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"AssignedUserID", "TValue":"6572"},
		{"TKey":"DisplayName", "TValue":"TestUserTest"},
		{"TKey":"EnabledYN", "TValue":"1"},
		{"TKey":"Debug", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"UserPropertyTypeID":"-1","UserPropertyValue":"GivenNameTest","DeleteYN":"0"},
		{"UserPropertyTypeID":"-2","UserPropertyValue":"FamilyNameTest","DeleteYN":"0"}
		]'

--Delete User/Group
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_User',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"2538"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"DeleteYN", "TValue":"1"},
		{"TKey":"AssignedUserID", "TValue":"6571"},
		{"TKey":"Debug", "TValue":"1"}
		]'

EXEC [spPortalAdminSet_User] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID=6572, @DisplayName='TestUsersss', @Debug=1

EXEC [spPortalAdminSet_User] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,
--	@AssignedInstanceID int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2163'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Add, Update and Delete User and User Properties',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-89: Added parameter @ObjectGuiBehaviorBM, DB-99: Changed not EXISTS test for updating DisplayName and UserName.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-178: Modified filter for inserting user dynamic properties. DB201: Added parameter @AssignedInstanceID.'
		IF @Version = '2.0.3.2151' SET @Description = 'Set Master database. Temporarily disabled call to [spSet_PartnerUser].'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-450: Set DeletedID = @DeletedID.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-474: Set correct @AssignedUserID using SCOPE_IDENTITY() when INSERTING INTO [User] table.'
		IF @Version = '2.1.0.2162' SET @Description = 'DB-186: Allow update of column [UserNameAD] in [User] table.'
		IF @Version = '2.1.0.2163' SET @Description = 'Enhanced debugging.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1
		
		SELECT 
			@UserTypeID = ISNULL(@UserTypeID, [UserTypeID]),
			@AssignedInstanceID = ISNULL(@AssignedInstanceID, [InstanceID])
		FROM 
			[pcINTEGRATOR_Data].[dbo].[User] 
		WHERE 
			[UserID] = @AssignedUserID			

		IF @DebugBM & 2 > 0
			SELECT [@AssignedInstanceID] = @AssignedInstanceID, [@AssignedUserID] = @AssignedUserID, [@UserTypeID] = @UserTypeID, [@EnabledYN] = @EnabledYN, [@DeleteYN] = @DeleteYN

	SET @Step = 'Create temp table #DynamicProperties'
		CREATE TABLE #DynamicProperties
			(
			InstanceID int,
			UserID int,
			UserPropertyTypeID int,
			UserPropertyValue nvarchar(100) COLLATE DATABASE_DEFAULT,
			DeleteYN bit
			)

	SET @Step = 'Get @AssignedUserID'
		IF @AssignedUserID IS NULL
			BEGIN
				SELECT
					@AssignedUserID = UserID
				FROM
					[User]
				WHERE
					[UserName] = @AssignedUserName AND
					[DeletedID] IS NULL
			END

	SET @Step = 'Insert New User'
		IF @DeleteYN = 0 AND @AssignedUserID IS NULL
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
					[InstanceID] = @AssignedInstanceID,
					[UserName] = @AssignedUserName,
					[UserNameAD] = @ActiveDirectoryName,
					[UserNameDisplay] = @DisplayName,
					[UserTypeID] = @UserTypeID,
					[UserLicenseTypeID] = @LicenseTypeID,
					[LocaleID] = @LocaleID,
					[LanguageID] = @LanguageID,
					[ObjectGuiBehaviorBM] = @ObjectGuiBehaviorBM
				WHERE 
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE UserID <> @AssignedUserID AND UserName = @AssignedUserName AND UserTypeID = -1 AND DeletedID IS NULL) AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE InstanceID = @AssignedInstanceID AND UserID <> @AssignedUserID AND UserNameDisplay = @DisplayName AND DeletedID IS NULL) AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE InstanceID = @AssignedInstanceID AND UserID <> @AssignedUserID AND UserName = @AssignedUserName AND DeletedID IS NULL)
				
				SELECT @AssignedUserID = SCOPE_IDENTITY(), @Inserted = @Inserted + @@ROWCOUNT

				IF @DebugBM & 2 > 0 SELECT [@AssignedUserID] = @AssignedUserID, [@Inserted] = @Inserted
			END

	SET @Step = 'Insert data into temp table #DynamicProperties'
		IF @JSON_table IS NOT NULL
			INSERT INTO #DynamicProperties
				(
				InstanceID,
				UserID,
				UserPropertyTypeID,
				UserPropertyValue,
				DeleteYN
				)
			SELECT
				InstanceID = @AssignedInstanceID,
				UserID = @AssignedUserID,
				UserPropertyTypeID,
				UserPropertyValue,
				DeleteYN = CASE WHEN UserPropertyValue = '' THEN 1 ELSE DeleteYN END
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				UserPropertyTypeID int,
				UserPropertyValue nvarchar(100) COLLATE DATABASE_DEFAULT,
				DeleteYN bit
				)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#DynamicProperties', * FROM #DynamicProperties

	SET @Step = 'Update Fixed User Properties / User Settings'
		IF @DeleteYN = 0 
			BEGIN
				IF @DebugBM & 2 > 0 
					SELECT [@DisplayName] = @DisplayName

				UPDATE U
				SET
					[UserNameDisplay] = ISNULL(@DisplayName, U.[UserNameDisplay]),
					[UserName] = ISNULL(@AssignedUserName, U.[UserName]),
					[UserNameAD] = ISNULL(@ActiveDirectoryName, U.[UserNameAD])
				FROM 
					[pcINTEGRATOR_Data].[dbo].[User] U
				WHERE
					U.InstanceID = @AssignedInstanceID AND
					U.[UserID] = @AssignedUserID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE UserID <> @AssignedUserID AND UserName = @AssignedUserName AND UserTypeID = -1 AND DeletedID IS NULL) AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE InstanceID = @AssignedInstanceID AND UserID <> @AssignedUserID AND UserNameDisplay = @DisplayName AND DeletedID IS NULL) AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE InstanceID = @AssignedInstanceID AND UserID <> @AssignedUserID AND UserName = @AssignedUserName AND DeletedID IS NULL)

				SET @Updated = @Updated + @@ROWCOUNT

				UPDATE U
				SET
					[UserLicenseTypeID] = ISNULL(@LicenseTypeID, U.[UserLicenseTypeID]),
					[LocaleID] =  ISNULL(@LocaleID, U.[LocaleID]),
					[LanguageID] =  ISNULL(@LanguageID, U.[LanguageID]),
					[SelectYN] =  ISNULL(@EnabledYN, [SelectYN]),
					[ObjectGuiBehaviorBM] = ISNULL(@ObjectGuiBehaviorBM, [ObjectGuiBehaviorBM])
				FROM 
					[pcINTEGRATOR_Data].[dbo].[User] U
				WHERE
					U.InstanceID = @AssignedInstanceID AND
					U.[UserID] = @AssignedUserID

				SET @Updated = @Updated + @@ROWCOUNT

				UPDATE UI
				SET
					[SelectYN] = @EnabledYN,
					[ExpiryDate] = @ExpiryDate
				FROM 
					[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
				WHERE
					UI.InstanceID = @AssignedInstanceID AND
					UI.[UserID] = @AssignedUserID

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Delete User'
		IF @DeleteYN <> 0
			BEGIN
				IF (SELECT COUNT(1) FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] WHERE [InstanceID] = @AssignedInstanceID AND [UserID] = @AssignedUserID) = 1
					BEGIN
						EXEC [spGet_DeletedItem] @UserID = @UserID, @InstanceID = @AssignedInstanceID, @VersionID = @VersionID, @TableName = 'User_Instance', @DeletedID = @DeletedID OUT, @JobID = @JobID, @Debug = @DebugSub
				
						UPDATE [pcINTEGRATOR_Data].[dbo].[User_Instance]
						SET
							DeletedID = @DeletedID
						WHERE
							[InstanceID] = @AssignedInstanceID AND
							[UserID] = @AssignedUserID

						SET @Deleted = @Deleted + @@ROWCOUNT
					END

				IF (SELECT COUNT(1) FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE [InstanceID] = @AssignedInstanceID AND [UserID] = @AssignedUserID) = 1
					BEGIN
						EXEC [spGet_DeletedItem] @UserID = @UserID, @InstanceID = @AssignedInstanceID, @VersionID = @VersionID, @TableName = 'User', @DeletedID = @DeletedID OUT, @Debug = @DebugSub
				
						UPDATE [pcINTEGRATOR_Data].[dbo].[User]
						SET
							DeletedID = @DeletedID
						WHERE
							[InstanceID] = @AssignedInstanceID AND
							[UserID] = @AssignedUserID

						SET @Deleted = @Deleted + @@ROWCOUNT
					END
				
				SET @Step = 'Delete Dynamic User Properties / User Settings' 
					BEGIN
						UPDATE UPV
						SET
							[SelectYN] = 0
						FROM
							[pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV
						WHERE
							UPV.[InstanceID] = @AssignedInstanceID AND
							UPV.[UserID] = @AssignedUserID

						SET @Deleted = @Deleted + @@ROWCOUNT
					END
			END

	SET @Step = 'Check InstanceID for Selected Users in UserPropertyValue table.'
		UPDATE UPV
		SET
			[InstanceID] = @AssignedInstanceID
		FROM
			[pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV
		WHERE
			UPV.InstanceID <> @AssignedInstanceID AND
			UPV.UserID = @AssignedUserID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update Dynamic User Properties / User Settings'
		IF @DeleteYN = 0 
			BEGIN
				UPDATE UPV
				SET
					[UserPropertyValue] = DP.UserPropertyValue,
					[SelectYN] = CASE WHEN DP.DeleteYN = 0 THEN 1 ELSE 0 END
				FROM
					[pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV
					INNER JOIN #DynamicProperties DP ON DP.UserID = UPV.UserID AND DP.UserPropertyTypeID = UPV.UserPropertyTypeID

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Insert Dynamic User Properties / User Settings'
		IF @DeleteYN = 0 AND @AssignedUserID IS NOT NULL
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
					(
					[InstanceID],
					[UserID],
					[UserPropertyTypeID],
					[UserPropertyValue],
					[SelectYN]
					)
				SELECT
					[InstanceID],
					[UserID],
					[UserPropertyTypeID],
					[UserPropertyValue],
					[SelectYN] = CASE WHEN DP.DeleteYN = 0 THEN 1 ELSE 0 END
				FROM
					#DynamicProperties DP 
				WHERE
					DP.DeleteYN = 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV WHERE UPV.UserID = DP.UserID AND UPV.UserPropertyTypeID = DP.UserPropertyTypeID)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Update master database'
		SET ANSI_NULLS ON; SET ANSI_WARNINGS ON; EXEC [spSet_PartnerUser] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @AssignedUserID = @AssignedUserID, @AssignedInstanceID = @AssignedInstanceID
		SET ANSI_WARNINGS OFF

	SET @Step = 'Delete temp table'
		DROP TABLE #DynamicProperties
	
	SET @Step = 'Return UserID'
		SELECT [@AssignedUserID] = @AssignedUserID

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

	RETURN @AssignedUserID
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
