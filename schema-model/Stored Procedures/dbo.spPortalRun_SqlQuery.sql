SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalRun_SqlQuery]
(
	@UserID int = NULL,
	@SqlQueryID int = NULL,
	@ParameterString nvarchar(2000) = NULL,
	@JobID int = 0,
	@Debug		bit = 0,
	@GetVersion bit = 0
)

/*
	EXEC dbo.[spPortalRun_SqlQuery] @UserID = 1005, @SqlQueryID = 1007, @ParameterString = 	'@Entity = 1002, @Currency = 124, @Scenario = 110, @Year = 2013', @Debug = 1
	EXEC dbo.[spPortalRun_SqlQuery] @UserID = 1005, @SqlQueryID = 1008, @ParameterString = '@JobID = 3', @Debug = 1
	EXEC dbo.[spPortalRun_SqlQuery] @UserID = 1005, @SqlQueryID = 1009, @Debug = 1
	EXEC dbo.[spPortalRun_SqlQuery] @UserID = 1005, @SqlQueryID = 1010, @Debug = 1
	EXEC dbo.[spPortalRun_SqlQuery] @UserID = 1005, @Debug = 1
	EXEC dbo.[spPortalRun_SqlQuery] @GetVersion = 1
*/	

--#WITH ENCRYPTION#--

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SqlQueryName nvarchar(50),
	@SqlQueryDescription nvarchar(255),
	@SqlQuery nvarchar(max),
	@SqlDeclare nvarchar(max) = '',
	@SqlSetParam nvarchar(max) = '',
	@SQLStatement nvarchar(max),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @SqlQueryID IS NULL
	BEGIN
		PRINT 'Parameter @UserID and parameter @SqlQueryID must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		SELECT 
			@SqlQueryName = SqlQueryName,
			@SqlQueryDescription = SqlQueryDescription,
			@SqlQuery = SqlQuery
		FROM
			SqlQuery
		WHERE
			SqlQueryID = @SqlQueryID

		IF (SELECT COUNT(1) FROM SqlQueryParameter WHERE SqlQueryID = @SqlQueryID) > 0
			BEGIN
				--@SqlDeclare
				IF @Debug <> 0
					SELECT 
						SqlQueryParameter,
						DataType,
						Size,
						DefaultValue
					 FROM
						SqlQueryParameter
					WHERE
						SqlQueryID = @SqlQueryID 

				SET @SqlDeclare = 'DECLARE' 

				SELECT 
					@SqlDeclare = @SqlDeclare + CHAR(13) + CHAR(10) + SqlQueryParameter + ' ' + DataType + CASE WHEN Size = 0 THEN ' = ' + ISNULL(DefaultValue, 0) ELSE '(' + CONVERT(nvarchar(10), Size) + ') = ' + '''' + ISNULL(DefaultValue, 0) + '''' END + ','
				FROM
					SqlQueryParameter
				WHERE
					SqlQueryID = @SqlQueryID 

				SET @SqlDeclare = SUBSTRING(@SqlDeclare, 1, LEN(@SqlDeclare) - 1) + CHAR(13) + CHAR(10)

				IF @Debug <> 0 PRINT @SqlDeclare

				--@SqlSetParam
				IF @ParameterString IS NOT NULL
					BEGIN
						SET @SqlSetParam = 'SELECT ' + @ParameterString	+ CHAR(13) + CHAR(10)
					END

			END

		IF @Debug <> 0 SELECT SqlQueryName = @SqlQueryName, SqlQueryDescription = @SqlQueryDescription, SqlDeclare = @SqlDeclare, SqlSetParam = @SqlSetParam, SqlQuery = @SqlQuery

	SET @Step = 'EXEC @SQLStatement'
		SET @SQLStatement = @SqlDeclare + @SqlSetParam + 'SELECT [Name] = ''' + @SqlQueryName + '''' + ', [Description] = ''' + @SqlQueryDescription + '''' + CHAR(13) + CHAR(10) + @SqlQuery

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

GO
