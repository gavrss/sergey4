SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spAlter_ChangeDatetime]

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

--EXEC [spAlter_ChangeDatetime] @ApplicationID = 400, @Debug = true

DECLARE
    @StartTime datetime,
    @Step nvarchar(255),
    @JobLogID int,
    @ErrorNumber int,
    @DestinationDatabase nvarchar(100),
    @SQLStatement nvarchar(max),
	@TableName nvarchar(100),
	@InstanceID int, 
    @Description nvarchar(255),
    @Version nvarchar(50) = '1.3.2112'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2112' SET @Description = 'Procedure created.'

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
			@DestinationDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A
		WHERE
			ApplicationID = @ApplicationID

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Create cursor table'
		CREATE TABLE #FactTable (TableName nvarchar(100))

		SET @SQLStatement = '
			INSERT INTO #FactTable
				(
				TableName
				)
			SELECT 
				TableName = ''['' + T.[name] + '']''
			FROM
				' + @DestinationDatabase + '.[sys].[tables] T
				INNER JOIN ' + @DestinationDatabase + '.[dbo].[Models] M ON ''FACT_'' +  M.Label  + ''_default_partition'' = T.[name]'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @Debug <> 0 SELECT TempTable = '#FactTable', * FROM #FactTable ORDER BY TableName

	SET @Step = 'Create cursor'
		DECLARE ChangeDatetime_Cursor CURSOR FOR

			SELECT 
				TableName
			FROM
				#FactTable
			ORDER BY
				TableName

			OPEN ChangeDatetime_Cursor
			FETCH NEXT FROM ChangeDatetime_Cursor INTO @TableName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						ALTER TABLE ' + @DestinationDatabase + '.[dbo].' + @TableName + ' ALTER COLUMN [ChangeDatetime] nvarchar(100)'

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					FETCH NEXT FROM ChangeDatetime_Cursor INTO @TableName
				END

		CLOSE ChangeDatetime_Cursor
		DEALLOCATE ChangeDatetime_Cursor	

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
