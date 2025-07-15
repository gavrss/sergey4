SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_User] 
	@ApplicationID int = NULL,
	@Debug int = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--

AS

--EXEC spSet_User @ApplicationID = 1011, @Debug = 1

DECLARE
	@DestinationDatabase nvarchar(100),
	@AdminUser nvarchar(100),
	@SQLStatement nvarchar(max),
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@InstanceID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.2.2067'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2053' SET @Description = 'Admin user deleted after creation of DB, but before import of objects.'
		IF @Version = '1.2.2067' SET @Description = 'Check existence of CallistoAppDictionary.dbo.ApplicationUsers.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT
			@InstanceID = A.InstanceID,
			@DestinationDatabase = A.DestinationDatabase,
			@AdminUser = A.AdminUser
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Create table #Object'
		CREATE TABLE #Object
			(
			ObjectType nvarchar(100) COLLATE DATABASE_DEFAULT,
			ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
			DatabaseName nvarchar(100) COLLATE DATABASE_DEFAULT
			)


		SET @SQLStatement = 'SELECT ObjectType = ''Table'', ObjectName = st.name, DatabaseName = ''' + @DestinationDatabase + ''' FROM ' + @DestinationDatabase + '.sys.tables st'
		INSERT INTO #Object (ObjectType, ObjectName, DatabaseName) EXEC (@SQLStatement)

	SET @Step = 'Verify CallistoAppDictionary.dbo.ApplicationAdmins'
		DELETE
			CallistoAppDictionary.dbo.ApplicationAdmins
		WHERE
			ApplicationLabel = @DestinationDatabase AND
			WinUser <> @AdminUser

		SET @Deleted = @Deleted + @@ROWCOUNT

		INSERT INTO CallistoAppDictionary.dbo.ApplicationAdmins
			(
			ApplicationLabel,
			WinUser
			)
		SELECT
			ApplicationLabel = @DestinationDatabase,
			WinUser = @AdminUser
		WHERE
			NOT EXISTS (SELECT 1 FROM CallistoAppDictionary.dbo.ApplicationAdmins WHERE ApplicationLabel = @DestinationDatabase AND WinUser = @AdminUser)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = 'CallistoAppDictionary.dbo.ApplicationAdmins', * FROM CallistoAppDictionary.dbo.ApplicationAdmins WHERE ApplicationLabel = @DestinationDatabase

		RAISERROR ('20 percent', 0, 20) WITH NOWAIT

	SET @Step = 'Verify CallistoAppDictionary.dbo.ApplicationUsers'
		IF (SELECT COUNT(1) FROM CallistoAppDictionary.sys.tables st WHERE st.name = 'ApplicationUsers') = 0
			CREATE TABLE CallistoAppDictionary.[dbo].[ApplicationUsers](
				[ApplicationLabel] [nvarchar](100) NOT NULL,
				[WinUser] [nvarchar](255) NOT NULL,
				[LicenseUserType] [nvarchar](255) NOT NULL
			) ON [PRIMARY]

		DELETE
			CallistoAppDictionary.dbo.ApplicationUsers
		WHERE
			ApplicationLabel = @DestinationDatabase AND
			WinUser <> @AdminUser

		SET @Deleted = @Deleted + @@ROWCOUNT

		INSERT INTO CallistoAppDictionary.dbo.ApplicationUsers
			(
			ApplicationLabel,
			WinUser,
			LicenseUserType
			)
		SELECT
			ApplicationLabel = @DestinationDatabase,
			WinUser = @AdminUser,
			LicenseUserType = 'Unrestricted'
		WHERE
			NOT EXISTS (SELECT 1 FROM CallistoAppDictionary.dbo.ApplicationUsers WHERE ApplicationLabel = @DestinationDatabase AND WinUser = @AdminUser)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = 'CallistoAppDictionary.dbo.ApplicationUsers', * FROM CallistoAppDictionary.dbo.ApplicationUsers WHERE ApplicationLabel = @DestinationDatabase

		RAISERROR ('40 percent', 0, 40) WITH NOWAIT

	SET @Step = 'Verify CallistoAppDictionary.dbo.SystemAdmins'
		/*
		DELETE
			CallistoAppDictionary.dbo.SystemAdmins
		WHERE
			WinUser <> @AdminUser

		SET @Deleted = @Deleted + @@ROWCOUNT
		*/

		/*
		INSERT INTO CallistoAppDictionary.dbo.SystemAdmins
			(
			WinUser
			)
		SELECT
			WinUser = @AdminUser
		WHERE
			NOT EXISTS (SELECT 1 FROM CallistoAppDictionary.dbo.SystemAdmins WHERE WinUser = @AdminUser)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = 'CallistoAppDictionary.dbo.SystemAdmins', * FROM CallistoAppDictionary.dbo.SystemAdmins
		*/

		RAISERROR ('60 percent', 0, 60) WITH NOWAIT

	SET @Step = 'Verify pcDATA_??.dbo.[SecurityRoles]'
		SET @SQLStatement = '
		DELETE
			' + @DestinationDatabase + '.dbo.[SecurityRoles]'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Verify pcDATA_??.dbo.[SecurityRoleMembers]'
		SET @SQLStatement = '
		DELETE
			' + @DestinationDatabase + '.dbo.[SecurityRoleMembers]
		WHERE
			WinUser <> ''' + @AdminUser + ''''
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

		SET @SQLStatement = '
		INSERT INTO ' + @DestinationDatabase + '.dbo.[SecurityRoleMembers]
			(
			RoleLabel,
			WinUser
			)
		SELECT DISTINCT
			RoleLabel = SR.Label,
			WinUser = ''' + @AdminUser + '''
		FROM
			' + @DestinationDatabase + '.[dbo].[SecurityRoles] SR
		WHERE
			NOT EXISTS (SELECT 1 FROM ' + @DestinationDatabase + '.dbo.[SecurityRoleMembers] SRM WHERE SRM.RoleLabel = SR.Label AND SRM.WinUser = ''' + @AdminUser + ''')'
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 
			BEGIN
				SET @SQLStatement = '
				SELECT [Table] = ''' + @DestinationDatabase + '.dbo.SecurityRoleMembers'', * FROM ' + @DestinationDatabase + '.[dbo].[SecurityRoleMembers]'
				PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		RAISERROR ('80 percent', 0, 80) WITH NOWAIT

	SET @Step = 'Verify pcDATA_??.dbo.[Users]'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'Users' AND DatabaseName = @DestinationDatabase) > 0
			BEGIN
				SET @SQLStatement = '
				DELETE
					' + @DestinationDatabase + '.dbo.[Users]
				WHERE
					WinUser <> ''' + @AdminUser + ''''
				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Deleted = @Deleted + @@ROWCOUNT

				SET @SQLStatement = '
				INSERT INTO ' + @DestinationDatabase + '.dbo.[Users]
					(
					UserId,
					WinUser,
					Active 
					)
				SELECT DISTINCT
					UserId = ISNULL((SELECT MAX(UserId) + 1 FROM ' + @DestinationDatabase + '.dbo.[Users]), 1),
					WinUser = ''' + @AdminUser + ''',
					Active = 1
				WHERE
					NOT EXISTS (SELECT 1 FROM ' + @DestinationDatabase + '.dbo.[Users] U WHERE U.WinUser = ''' + @AdminUser + ''')'
				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Inserted = @Inserted + @@ROWCOUNT

				IF @Debug <> 0 
					BEGIN
						SET @SQLStatement = '
						SELECT [Table] = ''' + @DestinationDatabase + '.dbo.Users'', * FROM ' + @DestinationDatabase + '.[dbo].[Users]'
						PRINT @SQLStatement
						EXEC (@SQLStatement)
					END
			END
		RAISERROR ('100 percent', 0, 100) WITH NOWAIT

	SET @Step = 'Drop temp tables'
		DROP TABLE #Object

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH





GO
