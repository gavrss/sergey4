SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_SqlQuery]

	@ApplicationID int = NULL,
	@Debug bit = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--EXEC [spInsert_SqlQuery] @ApplicationID = 400, @Debug = true

--#WITH ENCRYPTION#--
AS

DECLARE	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@InstanceID int,
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@ModelBM int,
	@SqlQueryID int,
	@SqlQueryID_New int,
	@Description nvarchar(255),
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2130' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2134' SET @Description = 'Handle SqlQueryParameter.'
		IF @Version = '1.4.0.2135' SET @Description = 'Check that ApplicationID is Selected.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'

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
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@DestinationDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A 
		WHERE
			 A.ApplicationID = @ApplicationID AND
			 A.SelectYN <> 0

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		SELECT 
			@ModelBM = SUM(sub.ModelBM)
		FROM
			(
			SELECT DISTINCT
				BM.ModelBM
			FROM
				Model M 
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
			WHERE
				M.ApplicationID = @ApplicationID AND
				M.SelectYN <> 0
			) sub

	SET @Step = 'Cursor for Insert into SqlQuery and into SqlQueryParameter'
		DECLARE SqlQuery_Cursor CURSOR FOR

			SELECT 
				SqlQueryID
			FROM
				SqlQuery SQ
			WHERE
				SQ.InstanceID = 0 AND
				SQ.SqlQueryID < 0 AND
				SQ.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM SqlQuery SQ1 WHERE SQ1.InstanceID = @InstanceID AND SQ1.SqlQueryName = SQ.SqlQueryName)

			OPEN SqlQuery_Cursor
			FETCH NEXT FROM SqlQuery_Cursor INTO @SqlQueryID

			WHILE @@FETCH_STATUS = 0
				BEGIN

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[SqlQuery]
						(
						InstanceID,
						SqlQueryName,
						SqlQueryDescription,
						SqlQuery,
						SqlQueryGroupID,
						RefID,
						SelectYN
						)
					SELECT 
						InstanceID = @InstanceID,
						SqlQueryName = SQ.SqlQueryName,
						SqlQueryDescription = SQ.SqlQueryDescription,
						SqlQuery = REPLACE(REPLACE(SQ.SqlQuery, '@ETLDatabase', @ETLDatabase), '@DestinationDatabase', @DestinationDatabase),
						SqlQueryGroupID = SQ.SqlQueryGroupID,
						RefID = SQ.SqlQueryID,
						SelectYN = 1
					FROM
						[SqlQuery] SQ
					WHERE
						SQ.SqlQueryID = @SqlQueryID

					SET @SqlQueryID_New = @@IDENTITY

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[SqlQueryParameter]
						(
						[InstanceID],
						[SqlQueryID],
						[SqlQueryParameter],
						[SqlQueryParameterName],
						[SqlQueryParameterDescription],
						[DataType],
						[Size],
						[DefaultValue],
						[SqlQueryParameterQuery],
						[SelectYN]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[SqlQueryID] = @SqlQueryID_New,
						[SqlQueryParameter],
						[SqlQueryParameterName],
						[SqlQueryParameterDescription],
						[DataType],
						[Size],
						[DefaultValue],
						[SqlQueryParameterQuery] = REPLACE(REPLACE(SQP.[SqlQueryParameterQuery], '@ETLDatabase', @ETLDatabase), '@DestinationDatabase', @DestinationDatabase),
						[SelectYN]
					FROM
						[SqlQueryParameter] SQP
					WHERE
						[SqlQueryID] = @SqlQueryID AND
						NOT EXISTS (SELECT 1 FROM [SqlQueryParameter] SQP1 WHERE SQP1.SqlQueryID = @SqlQueryID_New AND SQP1.[SqlQueryParameter] = SQP.[SqlQueryParameter])

					FETCH NEXT FROM SqlQuery_Cursor INTO @SqlQueryID
				END

		CLOSE SqlQuery_Cursor
		DEALLOCATE SqlQuery_Cursor	

		SET @Inserted = @Inserted + @@ROWCOUNT

		SELECT * FROM [pcINTEGRATOR_Data].[dbo].[SqlQuery] WHERE InstanceID = @InstanceID

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
