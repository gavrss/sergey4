SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_wrk_SourceTable] 

	@SourceID int = NULL,
	@TableCode nchar(4) = NULL,
	@Debug bit = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC spGet_iScalaTable @SourceID = 6, @TableCode = 'GL12', @Debug = true
--EXEC spGet_iScalaTable @SourceID = 7, @TableCode = 'GL12', @Debug = true
--EXEC spGet_iScalaTable @SourceID = 8, @TableCode = 'SL01', @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SourceTypeID int,
	@SourceType nvarchar(50),
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(50),
	@EntityCode nchar(2),
	@DatabaseName nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.2.2052'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID IS NULL OR @TableCode IS NULL
	BEGIN
		PRINT 'Parameter @SourceID and parameter @TableCode must be set'
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
			@SourceTypeID = ST.SourceTypeID,
			@SourceType = ST.SourceTypeName,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = A.ETLDatabase
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN Model M ON M.ModelID = S.ModelID
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
		WHERE
			SourceID = @SourceID
	
		IF @SourceTypeID <> 3 RETURN

	SET @Step = 'CleanUp'
		DELETE wrk_iScalaTable WHERE SourceID = @SourceID AND TableCode = @TableCode

SET @SQLStatement = 'SELECT EntityCode, DatabaseName = Par01 FROM ' + @ETLDatabase + '.dbo.Entity WHERE SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND SelectYN <> 0'

CREATE TABLE #Database
	(
    EntityCode nchar(2) COLLATE DATABASE_DEFAULT,
    DatabaseName nvarchar(255) COLLATE DATABASE_DEFAULT
    )

IF @Debug <> 0 PRINT @SQLStatement

INSERT INTO #Database (EntityCode, DatabaseName) EXEC (@SQLStatement)

DECLARE Database_Cursor CURSOR FOR

	SELECT 
	 EntityCode,
	 DatabaseName
	FROM
	 #Database

	OPEN Database_Cursor
	FETCH NEXT FROM Database_Cursor INTO @EntityCode, @DatabaseName

	WHILE @@FETCH_STATUS = 0
	  BEGIN
		SET @SQLStatement = '
			SELECT
			 SourceID = ' + CONVERT(nvarchar, @SourceID) + ',
			 TableCode = ''' + @TableCode + ''',
			 EntityCode = ''' + @EntityCode + ''',
			 TableName = E.Par01 + ''.[dbo].['' + st.name COLLATE DATABASE_DEFAULT + '']'',
			 FiscalYear = CASE WHEN CONVERT(int, SUBSTRING(st.name COLLATE DATABASE_DEFAULT, 7, 2)) < 25 THEN 2000 + CONVERT(int, SUBSTRING(st.name COLLATE DATABASE_DEFAULT, 7, 2)) ELSE 1900 + CONVERT(int, SUBSTRING(st.name COLLATE DATABASE_DEFAULT, 7, 2)) END
			FROM
			 [' + @ETLDatabase + '].dbo.Entity E
			 INNER JOIN ' + @DatabaseName + '.sys.tables st ON
			  st.name COLLATE DATABASE_DEFAULT LIKE ''' + @TableCode + '%' + ''' AND
			  SUBSTRING(st.name COLLATE DATABASE_DEFAULT, 5, 2) = E.EntityCode AND LEN(st.name) = 8
			WHERE
			 E.SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND
			 E.EntityCode = ''' + @EntityCode + ''' AND
			 E.SelectYN <> 0 AND
			 ISNUMERIC(SUBSTRING(st.name, 7,2)) <> 0
			ORDER BY
			 E.Par01,
			 st.name DESC'

		INSERT INTO wrk_iScalaTable (SourceID, TableCode, EntityCode, TableName, FiscalYear) EXEC (@SQLStatement)

		FETCH NEXT FROM Database_Cursor INTO @EntityCode, @DatabaseName
	  END

CLOSE Database_Cursor
DEALLOCATE Database_Cursor

IF @Debug <> 0 	SELECT * FROM wrk_iScalaTable WHERE SourceID = @SourceID AND TableCode = @TableCode ORDER BY EntityCode, FiscalYear DESC

DROP TABLE #Database

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH





GO
