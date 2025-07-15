SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCopy_ETL_Database]
	@UserID int = NULL,
	@InstanceID int = NULL, 
	@VersionID int = NULL, 

	@FromInstanceID int = NULL,
	@FromVersionID int = NULL,
	@ToInstanceID int = NULL,
	@ToVersionID int = NULL,
	@ToDomainName varchar (100) =  '',
	@FromDomainName varchar (100) =  '',

	@Path nvarchar(100) = NULL,
	@DataSuffix nvarchar(50) = '',
	@LogSuffix nvarchar(50) = '_Log',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000490,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spCopy_ETL_Database',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "ToInstanceID",  "TValue": "-1267"},
		{"TKey" : "ToVersionID",  "TValue": "-1205"},
		{"TKey" : "ToDomainName",  "TValue": "demo"},
		{"TKey" : "FromDomainName",  "TValue": "live"}
		]'

EXEC [spCopy_ETL_Database] @UserID=-10, @FromInstanceID=-1125, @FromVersionID=-1125, @ToInstanceID = -1186, @ToVersionID = -1186, @ToDomainName = 'demo', @FromDomainName = 'demo', @Debug=1

EXEC [spCopy_ETL_Database] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@FromETLDatabase nvarchar(100),
	@ToETLDatabase nvarchar(100),
	@FromApplicationName nvarchar(100),
	@ToApplicationName nvarchar(100),

	@SQLStatement nvarchar(max),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.3.2151'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create a copy of ETL database',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Set correct ProcedureID.'

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

		SELECT
			@FromETLDatabase = ETLDatabase,
			@FromApplicationName = LEFT(ApplicationName, 5)
		FROM
			[Application]
		WHERE
			InstanceID = @FromInstanceID AND
			VersionID = @FromVersionID

		SELECT
			@ToETLDatabase = ETLDatabase,
			@ToApplicationName = ApplicationName
		FROM
			[Application]
		WHERE
			InstanceID = @ToInstanceID AND
			VersionID = @ToVersionID

		IF @Path IS NULL
			SELECT
				@Path = REPLACE(REPLACE(physical_name, @FromETLDatabase, ''), '.mdf', '')
			FROM
				sys.master_files mf
				INNER JOIN (SELECT database_id = MIN(database_id) FROM sys.master_files WHERE name = @FromETLDatabase) c ON c.database_id = mf.database_id
			WHERE
				name = @FromETLDatabase

		IF @Debug <> 0 SELECT FromETLDatabase = @FromETLDatabase, ToETLDatabase = @ToETLDatabase, [Path] = @Path, DataSuffix = @DataSuffix, LogSuffix = @LogSuffix

	SET @Step = 'Check existence of ETL database'
		IF DB_ID(@FromETLDatabase) IS NULL
			BEGIN
				SET @Message = 'There is no source ETL database.'
				SET @Severity = 0
				GOTO EXITPOINT				
			END

	SET @Step = 'Create BU of @FromETLDatabase'
		SET @SQLStatement = '
			BACKUP DATABASE ' + @FromETLDatabase + '
			TO DISK = ''' + @Path + @FromETLDatabase + '.Bak''  
			WITH COPY_ONLY, FORMAT'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Drop existent @ToETLDatabase'
		IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @ToETLDatabase)
			BEGIN
				SET @SQLStatement = 'ALTER DATABASE ' + @ToETLDatabase + ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE'
				SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + 'DROP DATABASE ' + @ToETLDatabase
				
				IF @Debug <> 0 PRINT @SQLStatement	
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + 1
			END

	SET @Step = 'Restore @FromETLDatabase as @ToETLDatabase'
		SET @SQLStatement = '
			RESTORE DATABASE ' + @ToETLDatabase + '  
			   FROM DISK = ''' + @Path + @FromETLDatabase + '.Bak''
			   WITH 
			   MOVE ''' + @FromETLDatabase + @DataSuffix + ''' TO ''' + @Path + @ToETLDatabase + @DataSuffix + '.mdf'',  
			   MOVE ''' + @FromETLDatabase + @LogSuffix + ''' TO ''' + @Path + @ToETLDatabase + @LogSuffix + '.ldf'',
			   REPLACE, RECOVERY'

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

	SET @Step = 'Update logical file name'
		SET @SQLStatement = '
			ALTER DATABASE [' + @ToETLDatabase + '] MODIFY FILE (NAME = ' + @FromETLDatabase + ', NEWNAME = ' + @ToETLDatabase + ')
			ALTER DATABASE [' + @ToETLDatabase + '] MODIFY FILE (NAME = ' + @FromETLDatabase + '_log, NEWNAME = ' + @ToETLDatabase + '_log)'
		
			IF @Debug <> 0 PRINT @SQLStatement
			EXEC(@SQLStatement)

	SET @Step = 'Update Journal'
		SET @SQLStatement = '
			UPDATE J
			SET
				InstanceID = ' + CONVERT(nvarchar(15), @ToInstanceID) + '
			FROM
				' + @ToETLDatabase + '.dbo.Journal J
			WHERE
				InstanceID = ' + CONVERT(nvarchar(15), @FromInstanceID)

		EXEC (@SQLStatement)

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
