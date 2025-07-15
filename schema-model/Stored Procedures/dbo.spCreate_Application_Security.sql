SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Application_Security] 

	@JobID int = 0,
	@ApplicationID int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

SET ANSI_WARNINGS OFF

--EXEC [spCreate_Application_Security] @ApplicationID = 400, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(MAX),
	@ETLDatabase nvarchar(100),
	@InstanceID int,
	@ApplicationName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.1.2124'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.1.2124' SET @Description = 'Procedure created'

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
			@ApplicationName = A.ApplicationName,
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A
		WHERE
			ApplicationID = @ApplicationID

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Truncate XT_tables'
		SET @SQLStatement = 'DELETE ' + @ETLDatabase + '.[dbo].[XT_UserDefinition]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE ' + @ETLDatabase + '.[dbo].[XT_SecurityUser]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT

		SET @SQLStatement = 'DELETE ' + @ETLDatabase + '.[dbo].[XT_SecurityRoleDefinition]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT

		SET @SQLStatement = 'DELETE ' + @ETLDatabase + '.[dbo].[XT_SecurityModelRuleAccess]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT

		SET @SQLStatement = 'DELETE ' + @ETLDatabase + '.[dbo].[XT_SecurityMemberAccess]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT

		SET @SQLStatement = 'DELETE ' + @ETLDatabase + '.[dbo].[XT_SecurityActionAccess]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = '[XT_UserDefinition]'
		SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_UserDefinition]
				(
				[Action],
				[WinUser],
				[Active],
				[Email],
				[UserId]
				)
			SELECT DISTINCT
				[Action] = NULL,
				[WinUser] = U.UserNameAD,
				[Active] = 1,
				[Email] = UPV.UserPropertyValue,
				[UserId] = U.UserID
			FROM
				[User] U
				LEFT JOIN UserPropertyValue UPV ON UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -3
				LEFT JOIN UserMember UM ON UM.UserID_User = U.UserID AND UM.SelectYN <> 0
				LEFT JOIN SecurityRoleUser SRU ON (SRU.UserID = U.UserID OR SRU.UserID = UM.UserID_Group) AND SRU.SelectYN <> 0
				LEFT JOIN SecurityRole SR ON SR.SecurityRoleID = SRU.SecurityRoleID AND SR.SelectYN <> 0
				LEFT JOIN SecurityRoleObject SRO ON SRO.SecurityRoleID = SR.SecurityRoleID AND SRO.SelectYN <> 0
				LEFT JOIN [Object] O ON O.ObjectID = SRO.ObjectID 
			WHERE
				U.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				U.UserNameAD IS NOT NULL AND
				U.UserTypeID = -1 AND
				U.SelectYN <> 0 AND
				O.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				O.ObjectName = ''' + @ApplicationName + ''' AND
				O.ObjectTypeBM & 256 > 0 AND
				O.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[XT_UserDefinition] XT_UD WHERE XT_UD.WinUser = U.UserNameAD)'
		
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[XT_SecurityUser]'
		SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityUser]
				(
				[Role],
				[WinUser],
				[WinGroup]
				)
			SELECT DISTINCT
				[Role] = SR.SecurityRoleName,
				[WinUser] = U.UserNameAD,
				[WinGroup] = NULL
			FROM
				[User] U
				LEFT JOIN UserMember UM ON UM.UserID_User = U.UserID AND UM.SelectYN <> 0
				LEFT JOIN SecurityRoleUser SRU ON (SRU.UserID = U.UserID OR SRU.UserID = UM.UserID_Group) AND SRU.SelectYN <> 0
				LEFT JOIN SecurityRole SR ON SR.SecurityRoleID = SRU.SecurityRoleID AND SR.SelectYN <> 0
				LEFT JOIN SecurityRoleObject SRO ON SRO.SecurityRoleID = SR.SecurityRoleID AND SRO.SelectYN <> 0
				LEFT JOIN [Object] O ON O.ObjectID = SRO.ObjectID 
			WHERE
				U.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				U.UserNameAD IS NOT NULL AND
				U.UserTypeID = -1 AND
				U.SelectYN <> 0 AND
				O.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				O.ObjectName = ''' + @ApplicationName + ''' AND
				O.ObjectTypeBM & 256 > 0 AND
				O.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityUser] XT_SU WHERE XT_SU.[Role] = SR.SecurityRoleName AND XT_SU.WinUser = U.UserNameAD)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[XT_SecurityRoleDefinition]'
		SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityRoleDefinition]
				(
				[Action],
				[Label],
				[Description],
				[LicenseUserType]
				)
			SELECT DISTINCT
				[Action] = NULL,
				[Label] = SR.SecurityRoleName,
				[Description] = SR.SecurityRoleName,
				[LicenseUserType] = ULT.CallistoRestriction
			FROM
				[SecurityRole] SR
				INNER JOIN [UserLicenseType] ULT ON ULT.UserLicenseTypeID = SR.UserLicenseTypeID
				INNER JOIN [SecurityRoleObject] SRO ON SRO.SecurityRoleID = SR.SecurityRoleID AND SRO.SelectYN <> 0
				INNER JOIN [Object] O ON O.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND O.ObjectID = SRO.ObjectID AND O.ObjectName = ''' + @ApplicationName + ''' AND O.ObjectTypeBM & 256 > 0 AND O.SelectYN <> 0
			WHERE
				SR.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				SR.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityRoleDefinition] XT_SRD WHERE XT_SRD.[Label] = SR.SecurityRoleName)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[XT_SecurityModelRuleAccess]'
		SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityModelRuleAccess]
				(
				[Role],
				[Model],
				[Rule],
				[AllRules]
				)
			SELECT DISTINCT
				[Role] = SR.SecurityRoleName,
				[Model] = MO.ObjectName,
				[Rule] = '''',
				[AllRules] = 1
			FROM
				[SecurityRole] SR
				INNER JOIN [SecurityRoleObject] SRO ON SRO.SecurityRoleID = SR.SecurityRoleID AND SRO.SelectYN <> 0
				INNER JOIN [Object] O ON O.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND O.ObjectID = SRO.ObjectID AND O.ObjectName = ''' + @ApplicationName + ''' AND O.ObjectTypeBM & 256 > 0 AND O.SelectYN <> 0
				INNER JOIN [SecurityRoleObject] MSRO ON MSRO.SecurityRoleID = SR.SecurityRoleID AND MSRO.SecurityLevelBM & 8 > 0 AND MSRO.SelectYN <> 0
				INNER JOIN [Object] MO ON MO.ParentObjectID = O.ObjectID AND MO.ObjectID = MSRO.ObjectID AND MO.ObjectTypeBM & 1 > 0 AND MO.SelectYN <> 0 
			WHERE
				SR.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				SR.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityModelRuleAccess] XT_MRA WHERE XT_MRA.[Role] = SR.SecurityRoleName AND XT_MRA.[Model] = MO.ObjectName)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[XT_SecurityMemberAccess]'
		SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityMemberAccess]
				(
				[Role],
				[Model],
				[Dimension],
				[Hierarchy],
				[Member],
				[AccessType]
				)
			SELECT DISTINCT
				[Role] = SR.SecurityRoleName,
				[Model] = MO.ObjectName,
				[Dimension] = DMO.ObjectName,
				[Hierarchy] = NULL,
				[Member] = NULL,
				[AccessType] = SL.CallistoAccessType
			FROM
				[SecurityRole] SR
				INNER JOIN SecurityRoleObject SRO ON SRO.SecurityRoleID = SR.SecurityRoleID AND SRO.SelectYN <> 0
				INNER JOIN [Object] O ON O.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND O.ObjectID = SRO.ObjectID AND O.ObjectName = ''' + @ApplicationName + ''' AND O.ObjectTypeBM & 256 > 0 AND 	O.SelectYN <> 0
				INNER JOIN [SecurityRoleObject] MSRO ON MSRO.SecurityRoleID = SR.SecurityRoleID AND MSRO.SecurityLevelBM & 32 > 0 AND MSRO.SelectYN <> 0
				INNER JOIN [Object] MO ON MO.ParentObjectID = O.ObjectID AND MO.ObjectID = MSRO.ObjectID AND MO.ObjectTypeBM & 1 > 0 AND MO.SelectYN <> 0 
				INNER JOIN [SecurityRoleObject] DMSRO ON DMSRO.SecurityRoleID = SR.SecurityRoleID AND DMSRO.SecurityLevelBM & 16 > 0 AND DMSRO.SelectYN <> 0
				INNER JOIN [Object] DMO ON DMO.ParentObjectID = MO.ObjectID AND DMO.ObjectID = DMSRO.ObjectID AND DMO.ObjectTypeBM & 2 > 0 AND DMO.SelectYN <> 0 
				INNER JOIN [SecurityLevel] SL ON SL.SecurityLevelBM & 16 > 0 
			WHERE
				SR.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				SR.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityMemberAccess] XT_SMA WHERE XT_SMA.[Role] = SR.SecurityRoleName AND XT_SMA.[Model] = MO.ObjectName AND XT_SMA.[Dimension] = DMO.ObjectName)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[XT_SecurityActionAccess]'
		SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityActionAccess]
				(
				[Role],
				[Label],
				[HideAction]
				)
			SELECT DISTINCT
				[Role] = SR.SecurityRoleName,
				[Label] = REPLACE(O.ObjectName, '' '', ''''),
				[HideAction] = CASE WHEN SRO.SecurityLevelBM & 1 > 0 THEN 1 ELSE 0 END
			FROM
				[SecurityRole] SR
				INNER JOIN [SecurityRoleObject] SRO ON SRO.SecurityRoleID = SR.SecurityRoleID AND SRO.SelectYN <> 0
				INNER JOIN [Object] O ON O.ObjectID = SRO.ObjectID AND O.ObjectTypeBM & 1024 > 0 AND O.SelectYN <> 0
			WHERE
				SR.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				SR.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityActionAccess] XT_SAA WHERE XT_SAA.[Role] = SR.SecurityRoleName AND XT_SAA.[Label] = REPLACE(O.ObjectName, '' '', ''''))'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Debug, show result'	
		IF @Debug <> 0
			BEGIN
				SET @SQLStatement = '
					SELECT TableName = ''XT_UserDefinition'', * FROM ' + @ETLDatabase + '.[dbo].[XT_UserDefinition]
					SELECT TableName = ''XT_SecurityUser'', * FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityUser]
					SELECT TableName = ''XT_SecurityRoleDefinition'', * FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityRoleDefinition]
					SELECT TableName = ''XT_SecurityModelRuleAccess'', * FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityModelRuleAccess]
					SELECT TableName = ''XT_SecurityMemberAccess'', * FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityMemberAccess]
					SELECT TableName = ''XT_SecurityActionAccess'', * FROM ' + @ETLDatabase + '.[dbo].[XT_SecurityActionAccess]'

				PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

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
