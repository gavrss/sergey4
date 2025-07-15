SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_pcOBJECT]

	@JobID int = 0,
	@pcObject nvarchar(100) = NULL,
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_pcOBJECT] @Debug = 1
--EXEC [spCreate_pcOBJECT] @GetVersion = 1
--EXEC [spCreate_pcOBJECT] @pcObject = 'pcObject', @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@Collation nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2113'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.3.2098' SET @Description = 'Pick collation from spGet_Version.'
		IF @Version = '1.3.2113' SET @Description = 'Check existence and added @pcObject parameter.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @pcObject IS NULL
	BEGIN
		PRINT 'Parameter @pcObject must be set'
		RETURN 
	END

BEGIN TRY

	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @Collation = @Collation OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

	SET @Step = 'Check existence of pcObject database'
		IF EXISTS (SELECT 1 FROM sys.databases WHERE [name] = @pcObject)
			GOTO EXITPOINT
		ELSE
			SET @pcObject = '[' + REPLACE(REPLACE(REPLACE(@pcObject, '[', ''), ']', ''), '.', '].[') + ']'

	SET @Step = 'Create database pcOBJECT'
		SET @SQLStatement = 'CREATE DATABASE ' + @pcObject + ' COLLATE ' + @Collation + ' ALTER DATABASE ' + @pcObject + ' SET RECOVERY SIMPLE'
		IF @Debug <> 0 PRINT @SQLStatement 
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	---------------------------
	SET @Step = 'CREATE TABLES'
	---------------------------

	SET @Step = 'Create table WorkbookLibrary'
		IF (SELECT COUNT(1) FROM [pcOBJECT].sys.tables st WHERE [type] = 'U' AND name = 'WorkbookLibrary') = 0
		
			BEGIN
				SET @SQLStatement = '
					CREATE TABLE [pcOBJECT].[dbo].[WorkbookLibrary](
						[ReportID] [int] IDENTITY(1,1) NOT NULL,
						[AuthorType] nchar(1) NOT NULL,
						[Label] [nvarchar](255) NOT NULL,
						[Contents] [image] NOT NULL,
						[ChangeDatetime] [datetime] NOT NULL,
						[Userid] [nvarchar](100) NULL,
						[Sec] [nvarchar](max) NOT NULL,
						[Description] [nvarchar](255) NULL,
						[SelectYN] [bit] NOT NULL,
						CONSTRAINT [PK_WorkbookLibrary] PRIMARY KEY CLUSTERED 
					(
						[ReportID] ASC
					)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
					) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

					ALTER TABLE [pcOBJECT].[dbo].[WorkbookLibrary] ADD  CONSTRAINT [DF_WorkbookLibrary_AuthorType]  DEFAULT (''T'') FOR [AuthorType]
					ALTER TABLE [pcOBJECT].[dbo].[WorkbookLibrary] ADD  CONSTRAINT [DF_WorkbookLibrary_Sec]  DEFAULT ('''') FOR [Sec]
					ALTER TABLE [pcOBJECT].[dbo].[WorkbookLibrary] ADD  CONSTRAINT [DF_WorkbookLibrary_SelectYN]  DEFAULT ((1)) FOR [SelectYN]'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + 1

			END

	-------------------------------
	SET @Step = 'CREATE PROCEDURES'
	-------------------------------

	SET @Step = 'CREATE PROCEDURE spDel_pcREINSTALL'
		IF (SELECT COUNT(1) FROM [pcOBJECT].sys.procedures st WHERE [type] = 'P' AND name = 'spDel_pcREINSTALL') = 0
			BEGIN
				SET @SQLStatement = '
CREATE PROCEDURE [dbo].[spDel_pcREINSTALL] AS

DECLARE
	@ApplicationName nvarchar(100),
	@JobName nvarchar(100),
	@DataBaseName nvarchar(100),
	@SQLStatement nvarchar(max)

IF  EXISTS (SELECT name FROM sys.databases WHERE name = ''''pcINTEGRATOR'''')
	SELECT @ApplicationName = ApplicationName FROM [pcINTEGRATOR].[dbo].[Application] WHERE ApplicationID > 0
ELSE
	BEGIN
        SELECT [Message] = ''''Database pcINTEGRATOR does not exists on this server.''''
        RETURN
	END

DELETE [CallistoAppDictionary].[dbo].[Applications] WHERE [ApplicationLabel] = ''''pcDATA_'''' + @ApplicationName

SET @JobName = ''''pcDATA_'''' + @ApplicationName + ''''_Create''''
EXEC msdb..sp_delete_job @job_name = @JobName

SET @JobName = ''''pcDATA_'''' + @ApplicationName + ''''_Load''''
EXEC msdb..sp_delete_job @job_name = @JobName

SET @DatabaseName = ''''pcINTEGRATOR''''
	IF  EXISTS (SELECT name FROM sys.databases WHERE name = @DatabaseName)
		BEGIN
			SET @SQLStatement = ''''
			ALTER DATABASE '''' + @DatabaseName + '''' set single_user with rollback immediate
			DROP DATABASE '''' + @DatabaseName 

			EXEC (@SQLStatement)
		END

SET @DatabaseName = ''''pcETL_'''' + @ApplicationName
	IF  EXISTS (SELECT name FROM sys.databases WHERE name = @DatabaseName)
		BEGIN
			SET @SQLStatement = ''''
			ALTER DATABASE '''' + @DatabaseName + '''' set single_user with rollback immediate
			DROP DATABASE '''' + @DatabaseName 

			EXEC (@SQLStatement)
		END

SET @DatabaseName = ''''pcDATA_'''' + @ApplicationName
	IF  EXISTS (SELECT name FROM sys.databases WHERE name = @DatabaseName)
		BEGIN
			SET @SQLStatement = ''''
			ALTER DATABASE '''' + @DatabaseName + '''' set single_user with rollback immediate
			DROP DATABASE '''' + @DatabaseName 

			EXEC (@SQLStatement)
		END

SELECT [Message] = ''''Application '''' + @ApplicationName + '''' is deleted. It is now possible to reinstall pcINTEGRATOR.'''''

				SET @SQLStatement = 'EXEC pcOBJECT.dbo.sp_executesql N''' + @SQLStatement + ''''
				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + 1

			END

	SET @Step = 'CREATE PROCEDURE spRun_pcOBJECT'
		IF (SELECT COUNT(1) FROM [pcOBJECT].sys.procedures st WHERE [type] = 'P' AND name = 'spRun_pcOBJECT') = 0
			BEGIN
				SET @SQLStatement = '
CREATE PROCEDURE [dbo].[spRun_pcOBJECT] 

	@ApplicationName nvarchar(100) = '''''''',
	@ApplicationServer nvarchar(100) = '''''''',
	@DestinationDatabase nvarchar(100) = '''''''',
	@ETLDatabase nvarchar(100) = '''''''',
	@ModelName nvarchar(50) = '''''''',
	@BaseModelID int = 0,
	@SourceDatabase nvarchar(255) = '''''''',
	@SourceTypeID int = 0,
	@LoopNumber int = 1,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Debug bit = 0

AS

--EXEC [spRun_pcOBJECT] @ApplicationName = '''''''', @ApplicationServer = '''''''', @DestinationDatabase = '''''''', @ETLDatabase = '''''''', @ModelName = '''''''', @BaseModelID = 0, @SourceDatabase = '''''''', @SourceTypeID = 0, @LoopNumber = 1, @Debug = 1

DECLARE
	@Step nvarchar(255)

SET @Step = ''''LoopNumber check; @ModelName, @BaseModelID, @SourceDatabase and @SourceTypeID will differ between the different LoopNumbers''''
	IF @LoopNumber > 1
		RETURN

IF @Debug <> 0
	BEGIN
		SELECT
			ApplicationName = @ApplicationName,
			ApplicationServer = @ApplicationServer,
			DestinationDatabase = @DestinationDatabase,
			ETLDatabase = @ETLDatabase,
			ModelName = @ModelName,
			BaseModelID = @BaseModelID,
			SourceDatabase = @SourceDatabase,
			SourceTypeID = @SourceTypeID,
			LoopNumber = @LoopNumber
	END

SET @Step = ''''Add intended actions''''
	BEGIN

		SELECT Instruction = ''''Remove this line and do what you want''''

		SET @Deleted = @Deleted + @@ROWCOUNT	--Add this row below each DELETE statement you want counted in the log.
		SET @Inserted = @Inserted + @@ROWCOUNT	--Add this row below each INSERT statement you want counted in the log.
		SET @Updated = @Updated + @@ROWCOUNT	--Add this row below each UPDATE statement you want counted in the log.

	END'

			SET @SQLStatement = 'EXEC pcOBJECT.dbo.sp_executesql N''' + @SQLStatement + ''''
			IF @Debug <> 0 PRINT @SQLStatement 
			EXEC (@SQLStatement)
			SET @Inserted = @Inserted + 1

		END

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated
		RETURN 0

	SET @Step = 'EXITPOINT:'
		EXITPOINT:
		SET @Duration = GetDate() - @StartTime
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ErrorNumber = -1000, ErrorSeverity = 10, ErrorState = 0, ErrorLine = 0, ErrorProcedure = OBJECT_NAME(@@PROCID), @Step, ErrorMessage = 'The database ' + @pcObject + ' already exists. To get it replaced, delete the database manually and rerun the procedure.', @Version
		SET @JobLogID = @@IDENTITY
		SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
		SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
		RETURN @ErrorNumber
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH













GO
