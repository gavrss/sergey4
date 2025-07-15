SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_SqlQuery]
(
	@UserID int = NULL,
	@InstanceID int = NULL,
	@SqlQueryID int = NULL,
	@JobID int = 0,
	@Debug		bit = 0,
	@GetVersion bit = 0
)

/*
	EXEC dbo.[spPortalGet_SqlQuery] @UserID = 1005, @InstanceID = 400, @SqlQueryID = 1007, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQuery] @UserID = 1005, @SqlQueryID = 1008, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQuery] @UserID = 1005, @SqlQueryID = 1009, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQuery] @UserID = 1005, @SqlQueryID = 1010, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQuery] @UserID = 1005, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQuery] @GetVersion = 1
*/	

--#WITH ENCRYPTION#--

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@ParameterName nvarchar(50),
	@SortOrder int = 0,
	@Parameters int,
	@SQLStatement nvarchar(max),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL OR @SqlQueryID IS NULL
	BEGIN
		PRINT 'Parameter @UserID, @InstanceID and @SqlQueryID must be set.'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Create temp tables'
		CREATE TABLE #SqlQuery
			(
			ParameterName nvarchar(50) COLLATE DATABASE_DEFAULT,
			DefaultParameterValue nvarchar(50) COLLATE DATABASE_DEFAULT,
			DefaultParameterDescription  nvarchar(255) COLLATE DATABASE_DEFAULT,
			Parameter nvarchar(50) COLLATE DATABASE_DEFAULT,
			NumericYN bit
			)

		CREATE TABLE #Rows
			(
			ParameterValue nvarchar(50) COLLATE DATABASE_DEFAULT,
			ParameterDescription nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #ParameterRows
			(
			SortOrder int,
			ParameterName nvarchar(50) COLLATE DATABASE_DEFAULT,
			ParameterValue nvarchar(50) COLLATE DATABASE_DEFAULT,
			ParameterDescription nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Return Name and description'
		SELECT 
			[Name] = SqlQueryName,
			[Description] = SqlQueryDescription
		FROM
			SqlQuery
		WHERE
			SqlQueryID = @SqlQueryID



		DECLARE SqlQueryParameter_Cursor CURSOR FOR

			SELECT
				ParameterName = SqlQueryParameterName
			FROM
				SqlQueryParameter SQP
			WHERE
				SQP.SqlQueryID = @SqlQueryID
			ORDER BY
				SqlQueryParameterName

			OPEN SqlQueryParameter_Cursor
			FETCH NEXT FROM SqlQueryParameter_Cursor INTO @ParameterName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SortOrder = @SortOrder + 1

					TRUNCATE TABLE #Rows

					SELECT 
						@SQLStatement = SqlQueryParameterQuery
					FROM
						SqlQueryParameter SQP
					WHERE
						SQP.SqlQueryID = @SqlQueryID AND
						SQP.SqlQueryParameterName = @ParameterName

					INSERT INTO #Rows EXEC (@SQLStatement)
					INSERT INTO #ParameterRows
						(
						SortOrder,
						ParameterName,
						ParameterValue,
						ParameterDescription
						)
					SELECT
						SortOrder = @SortOrder,
						ParameterName = @ParameterName,
						ParameterValue,
						ParameterDescription
					FROM
						#Rows

					FETCH NEXT FROM SqlQueryParameter_Cursor INTO @ParameterName
				END

		CLOSE SqlQueryParameter_Cursor
		DEALLOCATE SqlQueryParameter_Cursor	

		INSERT INTO #SqlQuery
			(
			ParameterName,
			DefaultParameterValue,
			DefaultParameterDescription,
			Parameter,
			NumericYN
			)

		SELECT 
			ParameterName = SQP.SqlQueryParameterName,
			DefaultParameterValue = MAX(ISNULL(SQP.DefaultValue, par.DefaultParameterValue)),
			DefaultParameterDescription = NULL,
			Parameter = MAX(SQP.SqlQueryParameter),
			NumericYN = MAX(CASE WHEN SQP.Size = 0 THEN 1 ELSE 0 END)
		FROM
			SqlQueryParameter SQP
			LEFT JOIN 
				(
				SELECT
					PR.ParameterName,
					DefaultParameterValue = sub.DefaultValue,
					DefaultParameterDescription = PR.ParameterDescription
				FROM
					#ParameterRows PR
					INNER JOIN 
						(
						SELECT
							ParameterName,
							DefaultValue = MAX(ParameterValue)
						FROM
							#ParameterRows
						GROUP BY
							ParameterName
						) sub ON sub.ParameterName = PR.ParameterName
				) Par ON Par.ParameterName = SQP.SqlQueryParameterName
		WHERE
			SQP.SqlQueryID = @SqlQueryID
		GROUP BY
			SQP.SqlQueryParameterName

		UPDATE SQ
		SET
			DefaultParameterDescription = PR.ParameterDescription
		FROM
			#SqlQuery SQ
			INNER JOIN #ParameterRows PR ON PR.ParameterName = SQ.ParameterName AND PR.ParameterValue = SQ.DefaultParameterValue

		SELECT * FROM #SqlQuery ORDER BY ParameterName


		SELECT
			@Parameters = @SortOrder,
			@SortOrder = 0

		WHILE @SortOrder < @Parameters
			BEGIN
				SET @SortOrder = @SortOrder + 1

				SELECT
					ParameterName,
					ParameterValue,
					ParameterDescription
				FROM
					#ParameterRows
				WHERE
					SortOrder = @SortOrder
				ORDER BY
					ParameterDescription

			END




--SELECT * FROM SqlQueryParameter SQP

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

GO
