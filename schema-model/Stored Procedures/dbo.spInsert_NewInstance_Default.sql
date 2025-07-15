SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_NewInstance_Default]

	@UserID int = NULL,
	@InstanceID int = NULL, --New InstanceID
	@VersionID int = NULL,

	@BaseInstanceID int = -10, --InstanceID to copy from

	@JobID int = NULL, --Mandatory
	@Rows int = NULL,
	@ProcedureID INT = 880000193,
	@Parameter NVARCHAR(4000) = NULL,
	@StartTime DATETIME = NULL,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--EXEC [spInsert_Security_Default] @ApplicationID = 400, @Debug = true

--#WITH ENCRYPTION#--
AS

/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalSet_SIE4_Dimension',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "404"},
		{"TKey" : "VersionID",  "TValue": "1003"},
		{"TKey" : "JobID",  "TValue": "24416"}
		]'
EXEC [spInsert_NewInstance_Default] @UserID = -10, @InstanceID = 404, @VersionID = 1003, @Debug = 1
EXEC [spInsert_NewInstance_Default] @GetVersion = 1
*/
DECLARE
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'

		IF ISNULL((SELECT [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL), 0) <> @ProcedureID
			BEGIN
				SET @ProcedureID = NULL
				SELECT @ProcedureID = [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL
				IF @ProcedureID IS NULL
					SET @Message = 'SP ' + OBJECT_NAME(@@PROCID) + ' is not registered. Run SP spInsert_Procedure'
				ELSE
					SET @Message = 'ProcedureID mismatch, should be ' + CONVERT(nvarchar(10), @ProcedureID)
				SET @Severity = 16
				GOTO EXITPOINT
			END
		SELECT [Version] = @Version, [Description] = @Description, [ProcedureID] = @ProcedureID
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())
		
	SET @Step = 'Set procedure variables'
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SET @UserName = suser_name()

/*
	SET @Step = 'Insert into User'
		INSERT INTO [User]
			(
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserTypeID],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserName] = @ApplicationName + ' - AdminGroup',
			[UserNameAD] = NULL,
			[UserTypeID] = -2, --Group
			[UserLicenseTypeID] = -1 --AdminUser
		WHERE
			NOT EXISTS (SELECT 1 FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - AdminGroup')

		SELECT
			@AdminGroupID = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @AdminGroupID = ISNULL(@AdminGroupID, U.UserID) FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - AdminGroup'
--
		INSERT INTO [User]
			(
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserTypeID],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserName] = @ApplicationName + ' - FullAccessGroup',
			[UserNameAD] = NULL,
			[UserTypeID] = -2, --Group
			[UserLicenseTypeID] = -2 --BudgetUser
		WHERE
			NOT EXISTS (SELECT 1 FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - FullAccessGroup')

		SELECT
			@FullAccessGroupID = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @FullAccessGroupID = ISNULL(@FullAccessGroupID, U.UserID) FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - FullAccessGroup'
--
		INSERT INTO [User]
			(
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserTypeID],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserName] = @ApplicationName + ' - ReportAccessGroup',
			[UserNameAD] = NULL,
			[UserTypeID] = -2, --Group
			[UserLicenseTypeID] = -3 --ReportUser
		WHERE
			NOT EXISTS (SELECT 1 FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - ReportAccessGroup')

		SELECT
			@ReportAccessGroupID = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @ReportAccessGroupID = ISNULL(@ReportAccessGroupID, U.UserID) FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - ReportAccessGroup'
--
		INSERT INTO [User]
			(
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserTypeID],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserName] = A.[AdminUser],
			[UserNameAD] = A.[AdminUser],
			[UserTypeID] = -1, --User
			[UserLicenseTypeID] = -1 --AdminUser
		FROM
			[Application] A
		WHERE
			ApplicationID = @ApplicationID AND
			NOT EXISTS (SELECT 1 FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = A.AdminUser)

		SELECT
			@AdminUserID = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @AdminUserID = ISNULL(@AdminUserID, U.UserID) FROM [User] U INNER JOIN [Application] A ON A.ApplicationID = @ApplicationID AND A.AdminUser = U.[UserName] WHERE U.[InstanceID] = @InstanceID 
--
		INSERT INTO [UserMember]
			(
			[UserID_Group],
			[UserID_User]
			)
		SELECT
			[UserID_Group] = @AdminGroupID,
			[UserID_User] = @AdminUserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [UserMember] UM WHERE UM.[UserID_Group] = @AdminGroupID AND UM.[UserID_User] = @AdminUserID)

		SET @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [UserMember]
			(
			[UserID_Group],
			[UserID_User]
			)
		SELECT
			[UserID_Group] = @FullAccessGroupID,
			[UserID_User] = @AdminUserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [UserMember] UM WHERE UM.[UserID_Group] = @FullAccessGroupID AND UM.[UserID_User] = @AdminUserID)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into SecurityRole'
		INSERT INTO [SecurityRole]
			(
			[InstanceID],
			[SecurityRoleName],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleName] = 'Administrators', --@ApplicationName + ' - AdminRole',
			[UserLicenseTypeID] = -1 --AdminSecurityRole
		WHERE
			NOT EXISTS (SELECT 1 FROM [SecurityRole] SR WHERE SR.[InstanceID] = @InstanceID AND SR.[SecurityRoleName] = 'Administrators') --@ApplicationName + ' - AdminRole')

		SELECT
			@AdminRoleID = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @AdminRoleID = ISNULL(@AdminRoleID, SR.SecurityRoleID) FROM [SecurityRole] SR WHERE SR.[InstanceID] = @InstanceID AND SR.[SecurityRoleName] = 'Administrators' --@ApplicationName + ' - AdminRole'
--
		INSERT INTO [SecurityRole]
			(
			[InstanceID],
			[SecurityRoleName],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleName] = 'FullAccess', --@ApplicationName + ' - FullAccessRole',
			[UserLicenseTypeID] = -2 --BudgetSecurityRole
		WHERE
			NOT EXISTS (SELECT 1 FROM [SecurityRole] SR WHERE SR.[InstanceID] = @InstanceID AND SR.[SecurityRoleName] = 'FullAccess') --@ApplicationName + ' - FullAccessRole')

		SELECT
			@FullAccessRoleID = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @FullAccessRoleID = ISNULL(@FullAccessRoleID, SR.SecurityRoleID) FROM [SecurityRole] SR WHERE SR.[InstanceID] = @InstanceID AND SR.[SecurityRoleName] = 'FullAccess' --@ApplicationName + ' - FullAccessRole'
--
		INSERT INTO [SecurityRole]
			(
			[InstanceID],
			[SecurityRoleName],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleName] = 'ReportAccess', --@ApplicationName + ' - ReportAccessRole',
			[UserLicenseTypeID] = -3 --ReportSecurityRole
		WHERE
			NOT EXISTS (SELECT 1 FROM [SecurityRole] SR WHERE SR.[InstanceID] = @InstanceID AND SR.[SecurityRoleName] = 'ReportAccess') --@ApplicationName + ' - ReportAccessRole')

		SELECT
			@ReportAccessRoleID = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @ReportAccessRoleID = ISNULL(@ReportAccessRoleID, SR.SecurityRoleID) FROM [SecurityRole] SR WHERE SR.[InstanceID] = @InstanceID AND SR.[SecurityRoleName] = 'ReportAccess' --@ApplicationName + ' - ReportAccessRole'

	SET @Step = 'Insert into SecurityRoleUser'
		INSERT INTO [SecurityRoleUser]
			(
			[SecurityRoleID],
			[UserID]
			)
		SELECT
			[SecurityRoleID] = @AdminRoleID,
			[UserID] = @AdminGroupID
		WHERE
			NOT EXISTS (SELECT 1 FROM [SecurityRoleUser] SRU WHERE SRU.[SecurityRoleID] = @AdminRoleID AND SRU.[UserID] = @AdminGroupID)

		SET @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [SecurityRoleUser]
			(
			[SecurityRoleID],
			[UserID]
			)
		SELECT
			[SecurityRoleID] = @FullAccessRoleID,
			[UserID] = @FullAccessGroupID
		WHERE
			NOT EXISTS (SELECT 1 FROM [SecurityRoleUser] SRU WHERE SRU.[SecurityRoleID] = @FullAccessRoleID AND SRU.[UserID] = @FullAccessGroupID)

		SET @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [SecurityRoleUser]
			(
			[SecurityRoleID],
			[UserID]
			)
		SELECT
			[SecurityRoleID] = @ReportAccessRoleID,
			[UserID] = @ReportAccessGroupID
		WHERE
			NOT EXISTS (SELECT 1 FROM [SecurityRoleUser] SRU WHERE SRU.[SecurityRoleID] = @ReportAccessRoleID AND SRU.[UserID] = @ReportAccessGroupID)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Object'
		INSERT INTO [Object]
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
		INSERT INTO [Object]
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
		INSERT INTO [Object]
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
		INSERT INTO [Object]
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
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
		WHERE
			A.InstanceID = @InstanceID AND
			A.ApplicationName = @ApplicationName AND
			A.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM [Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = M.ModelName AND O.[ObjectTypeBM] & 1 > 0)

		SELECT @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [Object]
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
		INSERT INTO [Object]
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
		INSERT INTO [SecurityRoleObject]
			(
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[SecurityRoleID] = @AdminRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 60
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 448 > 0 AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.[SecurityRoleID] = @AdminRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [SecurityRoleObject]
			(
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 40
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 449 > 0 AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [SecurityRoleObject]
			(
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 32
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 3 > 0 AND
			O.ParentObjectID = @ObjectID_Application AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [SecurityRoleObject]
			(
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 16
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 2 > 0 AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [SecurityRoleObject]
			(
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 1
		FROM
			[Object] O
		WHERE
			O.InstanceID = 0 AND
			O.ObjectTypeBM & 1024 > 0 AND
			O.ObjectID IN (-6, -7) AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT
--
		INSERT INTO [SecurityRoleObject]
			(
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[SecurityRoleID] = @ReportAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 32
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 449 > 0 AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.[SecurityRoleID] = @ReportAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT
*/
	SET @Step = 'Drop temp tables'
--		DROP TABLE [#Dimension]

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
				
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
