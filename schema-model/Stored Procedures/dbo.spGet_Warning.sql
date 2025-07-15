SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spGet_Warning]

	@ApplicationID int = NULL,
	@StepTypeBM int = 2,
	@ManuallyYN bit = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

SET NOCOUNT ON

--EXEC [spGet_Warning] @ApplicationID = 400, @StepTypeBM = 2

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@Warning nvarchar(max) = '',
 	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2104'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2104' SET @Description = 'Procedure created'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL OR @StepTypeBM IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID and parameter @StepTypeBM must be set'
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
			@ETLDatabase = A.ETLDatabase,
			@DestinationDatabase = A.DestinationDatabase
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID 

	SET @Step = 'Create temp tables'
		CREATE TABLE #Warning ([Warning] nvarchar(max) COLLATE DATABASE_DEFAULT) 

	SET @Step = 'Set warning text'
		SELECT @Warning = @Warning + CHAR(13) + CHAR(10)  + CHAR(13) + CHAR(10) + REPLACE(Warning, '@StepID', CONVERT(nvarchar(10), StepID)) FROM StepXML WHERE Warning IS NOT NULL AND StepTypeBM & @StepTypeBM > 0 AND SelectYN <> 0

		SET @Warning = REPLACE(@Warning, '@ETLDatabase', @ETLDatabase)
		SET @Warning = REPLACE(@Warning, '@DestinationDatabase', @DestinationDatabase)

		INSERT INTO #Warning (Warning) SELECT Warning =  @Warning 
		PRINT @Warning

	SET @Step = 'Return Script'
		IF @ManuallyYN = 0 SELECT [Warning] FROM #Warning

	SET @Step = 'Define exit point'
		EXITPOINT:

	SET @Step = 'Drop temp tables'
		DROP TABLE #Warning

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
