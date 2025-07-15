SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spRun_pcOBJECT] 

	@ApplicationID int = NULL,
	@Debug bit = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spRun_pcOBJECT] @ApplicationID = 400, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@InstanceID int,
	@ApplicationName nvarchar(100),
	@ApplicationServer nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@ModelName nvarchar(50),
	@BaseModelID int,
	@SourceDatabase nvarchar(255),
	@SourceTypeID int,
	@LoopNumber int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.1.2120'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.1.2120' SET @Description = 'Changed @Debug setting.'

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

	SET @Step = 'Run [pcOBJECT]..[spRun_pcOBJECT]'	
		IF OBJECT_ID (N'pcOBJECT..spRun_pcOBJECT', N'P') IS NOT NULL 
			BEGIN

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT
			@InstanceID = A.InstanceID,
			@ApplicationName = A.ApplicationName,
			@ApplicationServer = A.ApplicationServer,
			@DestinationDatabase = A.DestinationDatabase,
			@ETLDatabase = A.ETLDatabase
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID

		SET @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Run pcOBJECT_Cursor'

				SET @LoopNumber = 0

				DECLARE pcOBJECT_Cursor CURSOR FOR

					SELECT
						M.ModelName,
						M.BaseModelID,
						S.SourceDatabase,
						S.SourceTypeID
					FROM
						Model M
						INNER JOIN Source S ON S.ModelID = M.ModelID
					WHERE
						M.ApplicationID = @ApplicationID

					OPEN pcOBJECT_Cursor
					FETCH NEXT FROM pcOBJECT_Cursor INTO @ModelName, @BaseModelID, @SourceDatabase, @SourceTypeID

					WHILE @@FETCH_STATUS = 0
					  BEGIN
						SET @LoopNumber = @LoopNumber + 1

						EXEC [pcOBJECT]..[spRun_pcOBJECT] @ApplicationName = @ApplicationName, @ApplicationServer = @ApplicationServer, @DestinationDatabase = @DestinationDatabase, @ETLDatabase = @ETLDatabase, @ModelName = @ModelName, @BaseModelID = @BaseModelID, @SourceDatabase = @SourceDatabase, @SourceTypeID = @SourceTypeID, @LoopNumber = @LoopNumber, @Deleted = @Deleted OUT, @Inserted = @Inserted OUT, @Updated = @Updated OUT, @Debug = @Debug
						
						FETCH NEXT FROM pcOBJECT_Cursor INTO  @ModelName, @BaseModelID, @SourceDatabase, @SourceTypeID
					  END

				CLOSE pcOBJECT_Cursor
				DEALLOCATE pcOBJECT_Cursor	
				
				IF @Debug <> 0 SELECT Deleted = @Deleted, Inserted = @Inserted, Updated = @Updated
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
