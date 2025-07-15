SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_SourceDatabase]

@SourceDatabase nvarchar(255) = NULL,
@OkYN bit = NULL OUT,
@Message nvarchar(255) = NULL OUT,
@GetVersion bit = 0,
@Debug bit = 0,
@Duration time(7) = '00:00:00' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT

--#WITH ENCRYPTION#--

AS

/*
DECLARE @OkYN bit, @Message nvarchar(255)
EXEC spCheck_SourceDatabase @SourceDatabase = 'DSPDC7.pcETL_LINKED_DevTest32', @OkYN = @OkYN OUT, @Message = @Message OUT, @Debug = 1
SELECT OkYN = @OkYN, Message = @Message 

EXEC spCheck_SourceDatabase @SourceDatabase = 'DSPDC7.pcETL_LINKED_DevTest3'

EXEC spCheck_SourceDatabase @SourceDatabase = 'EVRY_DW'
EXEC spCheck_SourceDatabase @SourceDatabase = 'EVRY_D'
*/

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@JobID int = -1,
	@LinkedYN bit,
	@Server nvarchar(100),
	@Database nvarchar(100),
	@SQLStatement nvarchar(max),
	@Counter int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2083'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2082' SET @Description = 'Procedure created.'
		IF @Version = '1.3.2083' SET @Description = 'Handle odd signs in database names.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceDatabase IS NULL
	BEGIN
		PRINT 'Parameter @SourceDatabase must be set'
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

		SET @SourceDatabase = REPLACE(REPLACE(@SourceDatabase, '[', ''), ']', '')

	SET @Step = 'Check @LinkedYN'
		IF @SourceDatabase LIKE '%.%'
			BEGIN
				SELECT
					@LinkedYN = 1,
					@Server = SUBSTRING(@SourceDatabase, 1, CHARINDEX ('.', @SourceDatabase) - 1),
					@Database = SUBSTRING(@SourceDatabase, CHARINDEX ('.', @SourceDatabase) + 1, LEN(@SourceDatabase) - CHARINDEX ('.', @SourceDatabase))
			END
		ELSE
			BEGIN
				SELECT
					@LinkedYN = 0,
					@Server = '',
					@Database = @SourceDatabase
			END

		IF @Debug <> 0 SELECT LinkedYN = @LinkedYN, [Server] = @Server, [Database] = @Database

	SET @Step = '@LinkedYN = TRUE'
		IF @LinkedYN <> 0
			BEGIN
				SELECT @Counter = COUNT(1) FROM master..sysservers WHERE srvname = @Server
				IF @Counter > 0
					BEGIN
						SELECT @Counter = COUNT(1) FROM master..sysservers WHERE srvname = @Server AND rpcout <> 0
						IF @Counter > 0
							BEGIN
								SET @SQLStatement = 'SELECT @internalVariable = count(1) FROM [' + @Server + '].master.sys.databases WHERE name = ''' + @Database + ''''
								EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @Counter OUT
								IF @Counter > 0
									BEGIN
										--Kolla att mandatory tables finns i databasen blir nästa version
										SELECT
											@OkYN = 1,
											@Message = 'The source database ' + @SourceDatabase + ' seems to be OK.'
										GOTO EXITPOINT
									END
								ELSE
									BEGIN
										SELECT
											@OkYN = 0,
											@Message = 'The database ' + @Database + ' is not available on the server ' + @Server + '.'
										GOTO EXITPOINT
									END
							END
						ELSE
							BEGIN
								SELECT
									@OkYN = 0,
									@Message = 'RPC Out is not set to true on the linked server ' + @Server + '.'
								GOTO EXITPOINT
							END
					END
				ELSE
					BEGIN
						SELECT
							@OkYN = 0,
							@Message = 'There is no available linked server named ' + @Server + '.'
						GOTO EXITPOINT
					END
			END

	SET @Step = '@LinkedYN = FALSE'
		IF @LinkedYN = 0
			BEGIN
				SELECT @Counter = count(1) FROM master.sys.databases WHERE name = @Database
				IF @Counter > 0
					BEGIN
						--Kolla att mandatory tables finns i databasen blir nästa version
						SELECT
							@OkYN = 1,
							@Message = 'The source database ' + @SourceDatabase + ' seems to be OK.'
						GOTO EXITPOINT
					END
				ELSE
					BEGIN
						SELECT
							@OkYN = 0,
							@Message = 'The database ' + @Database + ' is not available on the local server.'
						GOTO EXITPOINT
					END
			END


	SET @Step = 'Define exit point'
		EXITPOINT:
		IF @OkYN = 0 SELECT [ErrorMessage] = @Message ELSE SELECT [ErrorMessage] = NULL
--		RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
--	RETURN @ErrorNumber
	SELECT @OkYN = 0, @Message = 'Unrecognized error, SQL-Error: ' + CONVERT(nvarchar(50), @ErrorNumber)
	SELECT [ErrorMessage] = @Message
END CATCH





GO
