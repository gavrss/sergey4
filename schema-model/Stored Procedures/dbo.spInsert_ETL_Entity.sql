SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_ETL_Entity] 

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

--EXEC [spInsert_ETL_Entity] @ApplicationID = -1005, @Debug = true
--EXEC [spInsert_ETL_Entity] @ApplicationID = 601, @Debug = true
--EXEC [spInsert_ETL_Entity] @ApplicationID = 1324, @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@InstanceID int,
	@SourceID_varchar nvarchar(10),
	@SQLStatement nvarchar(max),
	@ETLDatabase nvarchar(100),
	@Application_InheritedFrom int,
	@ETLDatabase_InheritedFrom nvarchar(100),
	@FieldList nvarchar(max),
	@InsertCheck nvarchar(max),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2054' SET @Description = 'Set JobID for initial load during setup to 1 instead of 0.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2065' SET @Description = 'Handle SourceTypeID = 6, pcEXCHANGE.'
		IF @Version = '1.2.2066' SET @Description = 'Added parameter @Rows = 10000 when running the initial insert.'
		IF @Version = '1.2.2072' SET @Description = 'Show inserted content of the Entity table.'
		IF @Version = '1.3.2107' SET @Description = 'Changed handling for pcEXCHANGE.'
		IF @Version = '1.3.1.2120' SET @Description = 'Changed handling for Upgrade.'
		IF @Version = '1.4.0.2139' SET @Description = 'Brackets around procedurename.'

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
			@ETLDatabase = ETLDatabase,
			@Application_InheritedFrom = InheritedFrom
		FROM
			[Application] A
		WHERE
			ApplicationID = @ApplicationID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		SELECT @ETLDatabase_InheritedFrom = ETLDatabase FROM [Application] WHERE ApplicationID = @Application_InheritedFrom

	SET @Step = 'Insert members from upgraded database'
		IF @ETLDatabase_InheritedFrom IS NOT NULL
			BEGIN

				CREATE TABLE #ColumnList
					(
					ColumnName nvarchar(100) COLLATE DATABASE_DEFAULT,
					SortOrder int,
					PK bit
					)

				SET @SQLStatement = '
					INSERT INTO #ColumnList
						(
						ColumnName,
						SortOrder,
						PK
						)
					SELECT
						ColumnName,
						SortOrder = MAX(SortOrder),
						PK = MAX(PK)
					FROM
						(
						SELECT
							ColumnName = c.name,
							SortOrder = 0,
							PK = 0
						FROM
							' + @ETLDatabase_InheritedFrom + '.sys.columns c
							INNER JOIN ' + @ETLDatabase_InheritedFrom + '.sys.tables t ON t.object_id = c.object_id AND t.name = ''Entity''

						UNION SELECT
							ColumnName = c.name,
							SortOrder = c.column_id,
							PK = CASE WHEN ic.object_id IS NULL THEN 0 ELSE 1 END 
						FROM
							' + @ETLDatabase + '.sys.columns c
							INNER JOIN ' + @ETLDatabase + '.sys.tables t ON t.object_id = c.object_id AND t.name = ''Entity''
							LEFT JOIN ' + @ETLDatabase + '.sys.indexes i ON i.object_id = c.object_id AND i.is_primary_key <> 0
							LEFT JOIN ' + @ETLDatabase + '.sys.index_columns ic ON ic.object_id = c.object_id and ic.index_id = i.index_id AND ic.column_id = c.column_id
						) sub
					GROUP BY
						ColumnName
					HAVING
						COUNT(1) = 2
					ORDER BY
						MAX(SortOrder)'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @Debug <> 0 SELECT TempTable = '#ColumnList', * FROM #ColumnList ORDER BY SortOrder

					SELECT @FieldList = ISNULL(@FieldList, '') + '[' + ColumnName + '], ' FROM #ColumnList ORDER BY SortOrder
					SELECT @InsertCheck = ISNULL(@InsertCheck, '') + 'D.[' + ColumnName + '] = S.[' + ColumnName + '] AND ' FROM #ColumnList WHERE PK <> 0 ORDER BY SortOrder

					SET @FieldList = SUBSTRING(@FieldList, 1, LEN(@FieldList) - 1)
					SET @InsertCheck = SUBSTRING(@InsertCheck, 1, LEN(@InsertCheck) - 4)

					SET @SQLStatement = '
						INSERT INTO ' + @ETLDatabase + '..[Entity] (' + @FieldList + ') 
						SELECT ' + @FieldList + ' FROM ' + @ETLDatabase_InheritedFrom + '..[Entity] S
						WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '..[Entity] D WHERE ' + @InsertCheck + ')'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Inserted = @Inserted + @@ROWCOUNT
		
					DROP TABLE #ColumnList
				END

	SET @Step = 'Create the ETL_Entity procedure'
		EXEC [dbo].[spCreate_ETL_Entity] @ApplicationID = @ApplicationID, @Debug = @Debug

	SET @Step = 'Fill Cursor table'
		CREATE TABLE #Entity_Insert
			(
			SourceID_varchar nvarchar(10),
			ETLDatabase nvarchar(100)
			)

		SET @SQLStatement = '
		INSERT INTO #Entity_Insert
			(
			SourceID_varchar,
			ETLDatabase
			)
		SELECT
			SourceID_varchar = CASE WHEN ABS(S.SourceID) <= 9 THEN ''000'' ELSE CASE WHEN ABS(S.SourceID) <= 99 THEN ''00'' ELSE CASE WHEN ABS(S.SourceID) <= 999 THEN ''0'' ELSE '''' END END END + CONVERT(nvarchar, ABS(S.SourceID)),
			ETLDatabase = A.ETLDatabase
		FROM
			Source S
			INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SelectYN <> 0
			INNER JOIN [Model] M ON M.ModelID = S.ModelID AND M.ApplicationID = ' + CONVERT(nvarchar(10), @ApplicationID) + ' AND M.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
			INNER JOIN ' + @ETLDatabase + '.[sys].[procedures] P ON P.name = ''spIU_'' + CASE WHEN ABS(S.SourceID) <= 9 THEN ''000'' ELSE CASE WHEN ABS(S.SourceID) <= 99 THEN ''00'' ELSE CASE WHEN ABS(S.SourceID) <= 999 THEN ''0'' ELSE '''' END END END + CONVERT(nvarchar, ABS(S.SourceID)) + ''_ETL_Entity''
		WHERE
			S.SelectYN <> 0'

		IF @Debug <> 0 PRINT @SQLStatement

		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#Entity_Insert', * FROM #Entity_Insert ORDER BY SourceID_varchar

	SET @Step = 'Create Entity_Insert_Cursor'
		DECLARE Entity_Insert_Cursor CURSOR FOR

		SELECT
			SourceID_varchar,
			ETLDatabase
		FROM
			#Entity_Insert
		ORDER BY
			SourceID_varchar

		OPEN Entity_Insert_Cursor

		FETCH NEXT FROM Entity_Insert_Cursor INTO @SourceID_varchar, @ETLDatabase

		WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @SQLStatement =  'EXEC ' + @ETLDatabase + '.[dbo].[spIU_' + @SourceID_varchar + '_ETL_Entity] @JobID = 1, @Rows = 10000'

				IF @Debug <> 0
				  SELECT 
					SourceID_varchar = @SourceID_varchar,
					ETLDatabase = @ETLDatabase,
					SQLStatement = @SQLStatement

				EXEC (@SQLStatement)

				FETCH NEXT FROM Entity_Insert_Cursor INTO @SourceID_varchar, @ETLDatabase
			END

		CLOSE Entity_Insert_Cursor
		DEALLOCATE Entity_Insert_Cursor

	SET @Step = 'Show inserted content in the Entity table'
		SET @SQLStatement =
			'SELECT * FROM ' + @ETLDatabase + '.[dbo].Entity'
		EXEC (@SQLStatement)

	SET @Step = 'Drop temp tables'	
		DROP TABLE #Entity_Insert

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
