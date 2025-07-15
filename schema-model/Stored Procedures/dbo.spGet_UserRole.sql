SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_UserRole]
(
	--Default parameter
	@JobID int = 0,
	@UserName	nvarchar(50) = NULL,
	@Debug		bit = 0,
	@GetVersion bit = 0
)

/*
	None = 0, Read = 1, Write = 2, PowerUser = 4, Admin = 8

	EXEC dbo.[spGet_UserRole] @UserName = 'dspepicor10\administrator', @Debug = 1
	EXEC dbo.[spGet_UserRole] @UserName = 'jaxit\bengt.jax', @Debug = 1
*/	

--#WITH ENCRYPTION#--

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@DestinationDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@ApplicationID int,
	@UserRole int,
	@FeatureBM int = 0,
	@ExtensionName nvarchar(100),
	@ExtensionTypeID int,
	@DatabaseBM int,
	@DatabaseBM_Total int = 0,
	@DrillPageDB nvarchar(100),
	@SIE4DB nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2113'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2112' SET @Description = 'Procedure created'
		IF @Version = '1.3.2113' SET @Description = 'Returns all needed parameters for DrillPage'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserName IS NULL
	BEGIN
		PRINT 'Parameter @UserName must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT

		SELECT TOP 1
			@ApplicationID = ApplicationID
		FROM
			[Application]
		WHERE
			ApplicationID > 0 AND
			SelectYN <> 0
		ORDER BY
			CASE WHEN ApplicationDescription LIKE '%Demo%' THEN 999999 ELSE 1 END

		SELECT TOP 1
			@DestinationDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			ApplicationID = @ApplicationID AND
			SelectYN <> 0
		ORDER BY
			CASE WHEN ApplicationDescription LIKE '%Demo%' THEN 999999 ELSE 1 END

		EXEC dbo.[spGet_Feature] @ApplicationID = @ApplicationID, @FeatureBM = @FeatureBM OUT

	SET @Step = 'Create DBName_Cursor'
		DECLARE DBName_Cursor CURSOR FOR

			SELECT
				E.ExtensionName,
				E.ExtensionTypeID,
				ET.DatabaseBM
			FROM
				Extension E
				INNER JOIN ExtensionType ET ON ET.ExtensionTypeID = E.ExtensionTypeID AND ET.FeatureBM & @FeatureBM > 0 AND ET.DatabaseBM <> 0 AND ET.SelectYN <> 0
			WHERE
				E.SelectYN <> 0
			ORDER BY
				E.ExtensionTypeID

			OPEN DBName_Cursor
			FETCH NEXT FROM DBName_Cursor INTO @ExtensionName, @ExtensionTypeID, @DatabaseBM

			WHILE @@FETCH_STATUS = 0
				BEGIN

					IF @ExtensionTypeID = 20 SET @SIE4DB = @ExtensionName
					ELSE IF @ExtensionTypeID = 50 SET @DrillPageDB = @ExtensionName

					IF EXISTS (SELECT 1 FROM sys.databases WHERE [name] = @ExtensionName) AND @DatabaseBM & @DatabaseBM_Total <= 0
						SET @DatabaseBM_Total = @DatabaseBM_Total + @DatabaseBM

					FETCH NEXT FROM DBName_Cursor INTO @ExtensionName, @ExtensionTypeID, @DatabaseBM
				END

		CLOSE DBName_Cursor
		DEALLOCATE DBName_Cursor		

	SET @Step = 'Get User Role'
		IF
		EXISTS (SELECT 1 FROM [CallistoAppDictionary].[dbo].[ApplicationUsers] WHERE [ApplicationLabel] = @DestinationDatabase AND [WinUser] = @UserName AND [LicenseUserType] = 'Administrator') OR
		EXISTS (SELECT 1 FROM [CallistoAppDictionary].[dbo].[SystemAdmins] WHERE [WinUser] = @UserName) OR
		EXISTS (SELECT 1 FROM [CallistoAppDictionary].[dbo].[ApplicationAdmins] WHERE [ApplicationLabel] = @DestinationDatabase AND [WinUser] = @UserName)
			SELECT @UserRole = CAST(15 as int)
		ELSE
			BEGIN
				CREATE TABLE #Count ([Count] int)
				SET @SQLStatement = '
					INSERT INTO #Count ([Count]) SELECT [Count] = COUNT(1) FROM ' + @DestinationDatabase + '.dbo.SecurityRoleMembers WHERE RoleLabel = ''FullAccess'' AND WinUser = ''' +  @UserName + ''''
				EXEC (@SQLStatement)
				
				IF (SELECT [Count] FROM #Count) > 0
					SELECT @UserRole = CAST(7 as int)
				ELSE
					SELECT @UserRole = CAST(1 as int)

				DROP TABLE #Count
			END

	SET @Step = 'Return user dependent parameters'
		SELECT
			UserName = @UserName,
			UserRole = @UserRole,
			FeatureBM = @FeatureBM,
			DatabaseBM = @DatabaseBM_Total,
			ApplicationID = @ApplicationID,
			DrillPageDB = @DrillPageDB,
			SIE4DB = @SIE4DB,
			MissingDB = 'Your license gives you the right to run the selected application, but the needed database is not yet installed. Run pcINTEGRATOR and select Extensions to install the database.'

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH


GO
