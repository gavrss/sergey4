SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_pcEXTENSION]

	@JobID int = 0,
	@ApplicationID int = NULL,
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_pcEXTENSION] @ApplicationID = 400, @Debug = true
--EXEC [spCreate_pcEXTENSION] @GetVersion = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@ExtensionName nvarchar(100), 
	@Command nvarchar(500),
	@InstanceID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2116'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2113' SET @Description = 'Procedure created.'
		IF @Version = '1.3.2116' SET @Description = '@Version added to JobLog handling.'

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

		SELECT @InstanceID = A.InstanceID FROM [Application] A WHERE A.ApplicationID = @ApplicationID

		SET @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Create Extension_Cursor'
		DECLARE Extension_Cursor CURSOR FOR
			SELECT
				E.ExtensionName, 
				ET.Command
			FROM
				Extension E
				INNER JOIN ExtensionType ET ON ET.ExtensionTypeID = E.ExtensionTypeID AND ET.SelectYN <> 0
			WHERE
				E.ApplicationID = @ApplicationID AND
				E.SelectYN <> 0

			OPEN Extension_Cursor
			FETCH NEXT FROM Extension_Cursor INTO @ExtensionName, @Command

			WHILE @@FETCH_STATUS = 0
				BEGIN

					IF @Debug <> 0 SELECT ExtensionName = @ExtensionName, Command = @Command

					SET @Command = REPLACE(@Command, '@ApplicationID_Replace', @ApplicationID)
					SET @Command = REPLACE(@Command, '@ExtensionName_Replace', '''' + @ExtensionName + '''')
					SET @Command = 'EXEC ' + @Command + ', @Debug = ' + CONVERT(nvarchar(10), CONVERT(int, @Debug))

					IF @Debug <> 0 SELECT Command = @Command

					EXEC (@Command)

					FETCH NEXT FROM Extension_Cursor INTO @ExtensionName, @Command
				END

		CLOSE Extension_Cursor
		DEALLOCATE Extension_Cursor		

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
