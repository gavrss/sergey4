SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Tool_Copy_Database_ToAnotherServer]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SQLServerFrom nvarchar(4000),
	@SQLServerTo nvarchar(4000),
	@DatabaseList nvarchar(4000),
	@Path nvarchar(100) = '\\DSPBETA01\BackupTemp$',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000976,
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
EXEC [sp_Tool_Copy_Database_ToAnotherServer]
		@UserID=-10, @InstanceID=0, @VersionID=0,
		@SQLServerFrom = 'dspProd02',
		@SQLServerTo = 'dspBeta01',
		@DatabaseList = 'pcDATA_RDKP,pcETL_RDKP',
		@Path = '\\DSPBETA01\BackupTemp$',
		@DebugBM=1

EXEC [sp_Tool_Copy_Database_ToAnotherServer] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DatabaseName nvarchar(100),
	@SQLStatement nvarchar(max),
	@DynamicSQL NVARCHAR(MAX),
	@OutputMessage NVARCHAR(MAX),

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version NVARCHAR(50) = '2.1.2.2199'
IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Copy the database to another server',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	declare @BackupLog TABLE (
				LogMessage NVARCHAR(MAX)
				);

	SET @Step = 'Create #BU_Cursor_Table'
		CREATE TABLE #BU_Cursor_Table
			(
			DatabaseName nvarchar(100)
			)

		INSERT INTO #BU_Cursor_Table
			(
			DatabaseName
			)
		SELECT
			DatabaseName = value
		FROM STRING_SPLIT(@DatabaseList, ',')

		IF @DebugBM & 2 > 0 SELECT * FROM #BU_Cursor_Table ORDER BY DatabaseName

	if not @SQLServerTo in ('dspBeta01')
	    	RAISERROR ('@SQLServerTo must be: dspBeta01', -- Message text.
               16, -- Severity.
               1 -- State.
               );


	SET @Step = 'BU_Cursor'
		IF CURSOR_STATUS('global','BU_Cursor') >= -1 DEALLOCATE BU_Cursor
		DECLARE BU_Cursor CURSOR FOR

			SELECT
				DatabaseName
			FROM
				#BU_Cursor_Table
			ORDER BY
				DatabaseName

			OPEN BU_Cursor
			FETCH NEXT FROM BU_Cursor INTO @DatabaseName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DatabaseName] = @DatabaseName

					-- Command to delete the file
					--DECLARE @Command VARCHAR(500);
					--SET @Command = 'DEL /Q /F "' + @Path + '\' + @DatabaseName + '.Bak' + '"';
					--SET @Command = 'DEL /Q /F "E:\BackupTemp\' + @DatabaseName + '.Bak' + '"';
					--SET @Command = 'whoami';
			     	--EXEC xp_cmdshell @Command;

					SET @SQLStatement = '
BACKUP DATABASE [' + @DatabaseName + '] 
TO DISK = ''' + @Path + '\' + @DatabaseName + '.Bak'' 
WITH COPY_ONLY, FORMAT, COMPRESSION, INIT; '

					SET     @DynamicSQL     = N'EXEC(''' + REPLACE(@SQLStatement, '''', '''''') + N''') AT ' + QUOTENAME(@SQLServerFrom);
					IF @DebugBM & 1 > 0 PRINT @DynamicSQL

					declare @Text nvarchar(max) = 'Backup: [' + @SQLServerFrom + '].[' + @DatabaseName + '] starting...';
					print @Text
					EXEC pcINTEGRATOR..sp_Tool_send_slack @User = 'SeGa', @Text = @Text

					delete from @BackupLog;
					BEGIN TRY
						EXEC sp_executesql @DynamicSQL;
					END TRY
					BEGIN CATCH
						-- Capture errors in the main try-catch block
						INSERT INTO @BackupLog (LogMessage)
						VALUES (ERROR_MESSAGE());
						select * FROM @BackupLog;
					END CATCH;

					
					set @Text = 'Backup: [' + @SQLServerFrom + '].[' + @DatabaseName + '] finished'-- + char(10)+char(13)+ @OutputMessage;
					print @Text
					EXEC pcINTEGRATOR..sp_Tool_send_slack @User = 'SeGa', @Text = @Text



					DECLARE @DefaultDataPath NVARCHAR(255), @DefaultLogPath NVARCHAR(255);
					-- Retrieve the default data file path
					EXEC xp_instance_regread
						N'HKEY_LOCAL_MACHINE',
						N'Software\Microsoft\MSSQLServer\MSSQLServer',
						N'DefaultData',
						@DefaultDataPath OUTPUT;
					-- Retrieve the default log file path
					EXEC xp_instance_regread
						N'HKEY_LOCAL_MACHINE',
						N'Software\Microsoft\MSSQLServer\MSSQLServer',
						N'DefaultLog',
						@DefaultLogPath OUTPUT;

					print @DefaultDataPath
					print @DefaultLogPath

					if @DefaultDataPath is null
						begin
							-- Get default data path
							SELECT @DefaultDataPath = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)))
							FROM sys.master_files
							WHERE type = 0 AND database_id = 1; -- Type 0 indicates data file, database_id 1 is the master database

							-- Get default log path
							SELECT @DefaultLogPath = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)))
							FROM sys.master_files
							WHERE type = 1 AND database_id = 1; -- Type 1 indicates log file
						end
					-- Display the paths
					-- SELECT @DefaultDataPath AS DefaultDataPath, @DefaultLogPath AS DefaultLogPath;


					set @Text = 'Restore: [' + @SQLServerFrom + '].[' + @DatabaseName + '] starting...'-- + char(10)+char(13)+ @OutputMessage;
					print @Text
					EXEC pcINTEGRATOR..sp_Tool_send_slack @User = 'SeGa', @Text = @Text

					select @SQLStatement = '
					IF EXISTS (SELECT * FROM sys.databases WHERE name = N''' + @DatabaseName + ''')
					BEGIN
						ALTER DATABASE [' + @DatabaseName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
					END;
					RESTORE DATABASE [' + @DatabaseName + '] FROM DISK = N''' + @Path + '\' + @DatabaseName + '.Bak''
					WITH REPLACE,
						 MOVE N''' + @DatabaseName + ''' TO N''' + @DefaultDataPath + '\' + @DatabaseName + '.mdf'',
						 MOVE N''' + @DatabaseName + '_log'' TO N''' + @DefaultLogPath + '\' + @DatabaseName + '_log.ldf''
						 ;
					ALTER DATABASE [' + @DatabaseName + '] SET MULTI_USER;'
					print @SQLStatement
					EXEC sp_executesql @SQLStatement;


					set @Text = 'Restore: [' + @SQLServerFrom + '].[' + @DatabaseName + '] finished'-- + char(10)+char(13)+ @OutputMessage;
					print @Text
					EXEC pcINTEGRATOR..sp_Tool_send_slack @User = 'SeGa', @Text = @Text




					FETCH NEXT FROM BU_Cursor INTO @DatabaseName
				END

		CLOSE BU_Cursor
		DEALLOCATE BU_Cursor


	SET @Step = 'Set @Duration'
		DROP TABLE #BU_Cursor_Table

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
