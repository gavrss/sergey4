SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_pcSANDBOX]

	@JobID int = 0,
	@ApplicationID int = NULL,
	@SandBox nvarchar(100) = NULL,
	@Path nvarchar(100) = NULL,
	@DataSuffix nvarchar(50) = '',
	@LogSuffix nvarchar(50) = '_Log',
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_pcSANDBOX] @ApplicationID = 400, @SandBox = 'pcDATA_DevTest63_SandBox', @Debug = true
--EXEC [spCreate_pcSANDBOX] @GetVersion = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@DestinationDatabase nvarchar(100),
	@SqlDbServer nvarchar(100),
	@OlapDbServer nvarchar(100),
	@EnableAppLogon int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2113'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2113' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL OR @SandBox IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID and parameter @SandBox must be set'
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
			@DestinationDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			ApplicationID = @ApplicationID

		IF @Path IS NULL
			SELECT
				@Path = REPLACE(REPLACE(physical_name, @DestinationDatabase, ''), '.mdf', '')
			FROM
				sys.master_files mf
				INNER JOIN (SELECT database_id = MIN(database_id) FROM sys.master_files WHERE name = @DestinationDatabase) c ON c.database_id = mf.database_id
			WHERE
				name = @DestinationDatabase

		IF @Debug <> 0 SELECT DestinationDatabase = @DestinationDatabase, SandBox = @SandBox, [Path] = @Path, DataSuffix = @DataSuffix, LogSuffix = @LogSuffix

/*
	SET @Step = 'Check existence of SandBox database'
		IF EXISTS (SELECT 1 FROM sys.databases WHERE [name] = @SandBox)
			GOTO EXITPOINT
		ELSE
			SET @SandBox = '[' + REPLACE(REPLACE(REPLACE(@SandBox, '[', ''), ']', ''), '.', '].[') + ']'
*/

	SET @Step = 'Create BU of DestinationDatabase'
		SET @SQLStatement = '
			BACKUP DATABASE ' + @DestinationDatabase + '
			TO DISK = ''' + @Path + @DestinationDatabase + '.Bak''  
			WITH COPY_ONLY, FORMAT'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Drop existent SandBox'
		IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @SandBox)
			BEGIN
				SET @SQLStatement = 'ALTER DATABASE ' + @SandBox + ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE'
				SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + 'DROP DATABASE ' + @SandBox
/*
				WHILE EXISTS(select NULL from sys.databases where name = @SandBox)
					BEGIN
						SET @SQLStatement = NULL
						SELECT
							@SQLStatement = COALESCE(@SQLStatement,'') + 'Kill ' + Convert(varchar, SPId) + ';'
						FROM
							MASTER..SysProcesses
						WHERE
							DBId = DB_ID(@SandBox) AND SPId <> @@SPId
					
						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END
*/
--				SET @SQLStatement = 'DROP DATABASE ' + @SandBox
				
				IF @Debug <> 0 PRINT @SQLStatement	
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + 1
			END

	SET @Step = 'Restore DestinationDatabase as SandBox'
		SET @SQLStatement = '
			RESTORE DATABASE ' + @SandBox + '  
			   FROM DISK = ''' + @Path + @DestinationDatabase + '.Bak''
			   WITH 
			   MOVE ''' + @DestinationDatabase + @DataSuffix + ''' TO ''' + @Path + @SandBox + @DataSuffix + '.mdf'',  
			   MOVE ''' + @DestinationDatabase + @LogSuffix + ''' TO ''' + @Path + @SandBox + @LogSuffix + '.ldf'',
			   REPLACE, RECOVERY'

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

	SET @Step = 'Add row to [CallistoAppDictionary].[dbo].[Applications]'
		SELECT
			@SqlDbServer = [SqlDbServer],
			@OlapDbServer = [OlapDbServer],
			@EnableAppLogon = [EnableAppLogon]
		FROM
			[CallistoAppDictionary].[dbo].[Applications]
		WHERE
			[ApplicationLabel] = @DestinationDatabase

		INSERT INTO [CallistoAppDictionary].[dbo].[Applications]
			(
			[ApplicationLabel],
			[SqlDbName],
			[SqlDbServer],
			[OlapDbName],
			[OlapDbServer],
			[ApplicationType],
			[EnableAppLogon]
			)
		SELECT
			[ApplicationLabel] = @SandBox,
			[SqlDbName] = @SandBox,
			[SqlDbServer] = @SqlDbServer,
			[OlapDbName] = @SandBox,
			[OlapDbServer] = @OlapDbServer,
			[ApplicationType] = NULL,
			[EnableAppLogon] = @EnableAppLogon
		WHERE
			NOT EXISTS (SELECT 1 FROM [CallistoAppDictionary].[dbo].[Applications] WHERE [ApplicationLabel] = @SandBox)

	SET @Step = 'Deploy'
		EXEC pcINTEGRATOR..[spCreate_Job] @ApplicationID = @ApplicationID, @JobType = 'Load', @SandBox = @SandBox
		EXEC pcINTEGRATOR..[spStart_Job] @ApplicationID = @ApplicationID, @AsynchronousYN = 1, @SandBox = @SandBox, @StepName = 'Deploy'

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		RETURN 0

	SET @Step = 'EXITPOINT:'
		EXITPOINT:
		SET @Duration = GetDate() - @StartTime
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ErrorNumber = -1000, ErrorSeverity = 10, ErrorState = 0, ErrorLine = 0, ErrorProcedure = OBJECT_NAME(@@PROCID), @Step, ErrorMessage = 'The database ' + @SandBox + ' already exists. To get it replaced, delete the database manually and rerun the procedure.', @Version
		SET @JobLogID = @@IDENTITY
		SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
		SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
		RETURN @ErrorNumber

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH













GO
