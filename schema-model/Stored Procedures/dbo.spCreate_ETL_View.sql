SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_ETL_View]

	@ApplicationID int = NULL,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

SET NOCOUNT ON

--EXEC [spCreate_ETL_View] @ApplicationID = 400, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@ActionStatement nvarchar(1000),
	@InstanceID int,
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@ObjectName nvarchar(100),
	@LanguageID int,
	@Action nvarchar(10),
	@Counter int = 0,
 	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2095'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2095' SET @Description = 'Procedure created'

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
			@ETLDatabase = A.ETLDatabase,
			@DestinationDatabase = A.DestinationDatabase,
			@LanguageID = A.LanguageID
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Create temp table'
		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Start loop'
		WHILE @Counter < 3
			BEGIN
				SET @Counter = @Counter + 1
				IF @Counter = 1
					BEGIN
						SET @Step = 'Create View Time'
							SET @ObjectName = 'Time'
							SET @SQLStatement = '

	SELECT
		*
	FROM
		' + @DestinationDatabase + '..S_DS_€£Time£€'

					END

				ELSE IF @Counter = 2
					BEGIN
						SET @Step = 'Create View Account_TimeBalance'
							SET @ObjectName = 'Account_TimeBalance'
							SET @SQLStatement = '

	SELECT
		[Account] = [Label],
		[TimeBalance] = [TimeBalance]
	FROM
		' + @DestinationDatabase + '..S_DS_€£Account£€'

					END

				ELSE IF @Counter = 3
					BEGIN
						SET @Step = 'Create View Scenario'
							SET @ObjectName = 'Scenario'
							SET @SQLStatement = '

	SELECT
		*
	FROM
		' + @DestinationDatabase + '..S_DS_€£Scenario£€'

					END
 
				SET @Step = 'Replace codeword'
					IF @Debug <> 0
						BEGIN
							PRINT @SQLStatement
							SELECT ApplicationID = @ApplicationID, ObjectTypeBM = 2, TranslatedLanguageID = @LanguageID, StringIn = @SQLStatement
						END
					EXEC spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 2, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
					IF @Debug <> 0 PRINT @SQLStatement
                                             
				SET @Step = 'Determine CREATE or ALTER'
					SET @ActionStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''V''' 
					INSERT INTO #Action ([Action]) EXEC (@ActionStatement)
					SELECT @Action = [Action] FROM #Action
                                                             
				SET @Step = 'Make Creation statement'
					IF @Debug <> 0 
						SELECT
							[Action] = @Action,
							ObjectName = @ObjectName,
							SQLStatement = @SQLStatement

					SET @SQLStatement = @Action + ' VIEW [dbo].' + @ObjectName + '
	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
	AS' + CHAR(13) + CHAR(10) + @SQLStatement

                    SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

                    IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of View', [SQLStatement] = @SQLStatement

                    EXEC (@SQLStatement)
		END

	SET @Step = 'Drop temp tables'
		DROP TABLE #Action

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
