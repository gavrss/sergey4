SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_pcINTEGRATOR_BU]

	@JobID int = 0,
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

--EXEC [spCreate_pcINTEGRATOR_BU] @Debug = true
--EXEC [spCreate_pcINTEGRATOR_BU] @GetVersion = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@pcINTEGRATOR nvarchar(100) = 'pcINTEGRATOR',
	@Version_Old nvarchar(50),
	@pcINTEGRATOR_Restored nvarchar(100),
	@Message nvarchar(500),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.1.2121'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.1.2120' SET @Description = 'Procedure created.'
		IF @Version = '1.3.1.2121' SET @Description = 'Set SourceDatabase in [pcINTEGRATOR].dbo.[Source].'

		SELECT [Version] =  @Version, [Description] = @Description
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

		IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE [name] = @pcINTEGRATOR)
			BEGIN
				SET @Message = 'The database ' + @pcINTEGRATOR + ' does not exists. Maybe a database copy with new name is already created or it is not possible to run an upgrade.'
				RAISERROR (@Message, 0, 100) WITH NOWAIT
				GOTO EXITPOINT
			END

		IF	(
			SELECT
				COUNT(1)
			FROM
				pcINTEGRATOR.sys.parameters par
				INNER JOIN pcINTEGRATOR.sys.procedures sp ON sp.[object_id] = par.[object_id] AND sp.name = 'spGet_Version'
			WHERE
				par.name = '@Version' AND
				par.is_output <> 0
			) > 0
				BEGIN
					EXEC pcINTEGRATOR..spGet_Version @Version = @Version_Old OUTPUT
				END

		SELECT @Version_Old = ISNULL(@Version_Old, 'Old')
		
		SET @Version_Old = REPLACE(@Version_Old, '.', '_')

		SELECT
			@pcINTEGRATOR_Restored = @pcINTEGRATOR + '_' + @Version_Old

		IF @Path IS NULL
			SELECT
				@Path = REPLACE(REPLACE(physical_name, @pcINTEGRATOR, ''), '.mdf', '')
			FROM
				sys.master_files mf
				INNER JOIN (SELECT database_id = MIN(database_id) FROM sys.master_files WHERE name = @pcINTEGRATOR) c ON c.database_id = mf.database_id
			WHERE
				name = @pcINTEGRATOR

		IF @Debug <> 0 SELECT Version_Old = @Version_Old, pcINTEGRATOR_Restored = @pcINTEGRATOR_Restored, [Path] = @Path, DataSuffix = @DataSuffix, LogSuffix = @LogSuffix

	SET @Step = 'Check existence of @pcINTEGRATOR_Restored'
		IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @pcINTEGRATOR_Restored)
			BEGIN
				SET @Message = 'The database ' + @pcINTEGRATOR_Restored + ' already exists. To get it replaced, delete the database manually and rerun the procedure.'
				RAISERROR (@Message, 0, 100) WITH NOWAIT
				GOTO EXITPOINT
			END

	SET @Step = 'Create BU of pcINTEGRATOR'
		SET @SQLStatement = '
			BACKUP DATABASE ' + @pcINTEGRATOR + '
			TO DISK = ''' + @Path + @pcINTEGRATOR + '.Bak''  
			WITH COPY_ONLY, FORMAT'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Restore pcINTEGRATOR with new name.'
		SET @SQLStatement = '
			RESTORE DATABASE ' + @pcINTEGRATOR_Restored + '  
			   FROM DISK = ''' + @Path + @pcINTEGRATOR + '.Bak''
			   WITH 
			   MOVE ''' + @pcINTEGRATOR + @DataSuffix + ''' TO ''' + @Path + @pcINTEGRATOR_Restored + @DataSuffix + '.mdf'',  
			   MOVE ''' + @pcINTEGRATOR + @LogSuffix + ''' TO ''' + @Path + @pcINTEGRATOR_Restored + @LogSuffix + '.ldf'',
			   REPLACE, RECOVERY'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'Drop existent pcINTEGRATOR'
		IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @pcINTEGRATOR_Restored)
			BEGIN
				SET @SQLStatement = 'ALTER DATABASE ' + @pcINTEGRATOR + ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE'
				SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + 'DROP DATABASE ' + @pcINTEGRATOR
			
				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + 1

				UPDATE S SET SourceDatabase = @pcINTEGRATOR_Restored FROM [pcINTEGRATOR].dbo.[Source] S WHERE SourceID = 0
			END

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		RETURN 0

	SET @Step = 'EXITPOINT:'
		EXITPOINT:
		SET @Duration = GetDate() - @StartTime
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ErrorNumber = -1000, ErrorSeverity = 10, ErrorState = 0, ErrorLine = 0, ErrorProcedure = OBJECT_NAME(@@PROCID), @Step, ErrorMessage = @Message, @Version
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
