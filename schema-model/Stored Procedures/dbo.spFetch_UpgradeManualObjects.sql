SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFetch_UpgradeManualObjects]

	@JobID int = 0,
	@DataBaseBM int = 3, --1 = pcETL, 2 = pcDATA, 3 = All databases
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--

AS

--MISSING? pcINTEGRATOR, Add additional rows in SQL Metadata

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@pcINTEGRATOR_Old nvarchar(100),
	@ETLDatabase_Old nvarchar(100),
	@ETLDatabase_New nvarchar(100),
	@DestinationDatabase_Old nvarchar(100),
	@DestinationDatabase_New nvarchar(100),
	@name nvarchar(100),
	@definition nvarchar(max),

	@TableName nvarchar(100),
	@IdColumn nvarchar(100),
	@StartValue int,
	@WhereClause nvarchar(1000),
	@MandatoryColumn1 nvarchar(100),
	@MandatoryValue1 nvarchar(255),
	@MandatoryColumn2 nvarchar(100),
	@MandatoryValue2 nvarchar(255),
	@ManualCheckYN bit,
	@FieldList nvarchar(max),
	@InsertCheck nvarchar(max),
	@VersionYN bit,

	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2126'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.1.2121' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2126' SET @Description = 'Check @DatabaseBM.'

		SELECT [Version] =  @Version, [Description] = @Description
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

		SELECT @pcINTEGRATOR_Old = SourceDatabase FROM Source WHERE SourceID = 0

		IF @Debug <> 0 SELECT pcINTEGRATOR_Old = @pcINTEGRATOR_Old

	SET @Step = 'Create temp tables'	
		CREATE TABLE #Object ([name] nvarchar(100), [definition] nvarchar(max))
		CREATE TABLE #Count ([Counter] int)

	SET @Step = 'Create DB_Cursor'	
		DECLARE DB_Cursor CURSOR FOR

			SELECT
				ETLDatabase_Old = A_S.ETLDatabase,
				ETLDatabase_New = A.ETLDatabase,
				DestinationDatabase_Old = A_S.DestinationDatabase,
				DestinationDatabase_New = A.DestinationDatabase
			FROM 
				pcINTEGRATOR..[Application] A 
				INNER JOIN pcINTEGRATOR..[Application] A_S ON A_S.ApplicationID = A.InheritedFrom
			WHERE
				A.ApplicationID > 0 AND 
				A.InheritedFrom IS NOT NULL AND 
				A.SelectYN <> 0

			OPEN DB_Cursor
			FETCH NEXT FROM DB_Cursor INTO @ETLDatabase_Old, @ETLDatabase_New, @DestinationDatabase_Old, @DestinationDatabase_New

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0
						SELECT
							ETLDatabase_Old = @ETLDatabase_Old,
							ETLDatabase_New = @ETLDatabase_New,
							DestinationDatabase_Old = @DestinationDatabase_Old,
							DestinationDatabase_New = @DestinationDatabase_New

			SET @Step = 'pcETL, Add HC-procedures and Views'
				IF @DataBaseBM & 1 > 0
					BEGIN
						TRUNCATE TABLE #Object

						SET @SQLStatement = '
							INSERT INTO #Object
								(
								[name],
								[definition]
								)
							SELECT
								P.name,
								SM.definition
							FROM
								' + @ETLDatabase_Old + '.sys.sql_modules SM
								INNER JOIN ' + @ETLDatabase_Old + '.sys.procedures P ON P.object_id = SM.object_id AND P.name LIKE ''%_HC''
							
							UNION	
						
							SELECT
								V.name,
								SM.definition
							FROM
								' + @ETLDatabase_Old + '.sys.sql_modules SM
								INNER JOIN ' + @ETLDatabase_Old + '.sys.views V ON V.object_id = SM.object_id AND V.name LIKE ''%_HC'''							

						EXEC (@SQLStatement)

						IF @Debug <> 0 SELECT TempTable = '#Object', * FROM #Object

						DECLARE pcETL_Object_Cursor CURSOR FOR

							SELECT 
								[name],
								[definition]
							FROM
								#Object

							OPEN pcETL_Object_Cursor
							FETCH NEXT FROM pcETL_Object_Cursor INTO @name, @definition

							WHILE @@FETCH_STATUS = 0
								BEGIN

									IF @Debug <> 0 SELECT name = @name
									TRUNCATE TABLE #Count

									SET @SQLStatement = 'INSERT INTO #Count ([Counter]) SELECT [Counter] = COUNT(1) FROM ' + @ETLDatabase_New + '.dbo.sysobjects WHERE name = ''' + @name + ''''
									EXEC (@SQLStatement)
									IF @Debug <> 0 SELECT TempTable = '#Count', * FROM #Count

									IF (SELECT [Counter] FROM #Count) = 0
										BEGIN
											SET @SQLStatement = 'EXEC ' + @ETLDatabase_New + '.dbo.sp_executesql N''' + REPLACE(@definition, '''', '''''') + ''''
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									FETCH NEXT FROM pcETL_Object_Cursor INTO @name, @definition
								END

						CLOSE pcETL_Object_Cursor
						DEALLOCATE pcETL_Object_Cursor
					END

			SET @Step = 'pcETL, Add HC rows in Load'
				IF @DataBaseBM & 1 > 0
					BEGIN
						TRUNCATE TABLE #Count

						SET @SQLStatement = '
						INSERT INTO #Count ([Counter]) SELECT [Counter] = COUNT(1) FROM ' + @ETLDatabase_Old + '.sys.tables WHERE name = ''Load'''
						EXEC (@SQLStatement)

						IF (SELECT [Counter] FROM #Count) > 0
							BEGIN

								SET @SQLStatement = '
								INSERT INTO ' + @ETLDatabase_New + '..Load (LoadTypeBM, Command, SortOrder, FrequencyBM, SelectYN) SELECT LoadTypeBM, Command, SortOrder, FrequencyBM, SelectYN = 0 FROM ' + @ETLDatabase_Old + '..Load OL
								WHERE OL.Command LIKE ''%_HC'' AND OL.SelectYN <> 0 AND NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase_New + '..Load L WHERE L.Command = OL.Command)'
								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @Inserted = @Inserted + @@ROWCOUNT
							END
					END

			SET @Step = 'pcDATA, Add manually added views and procedures'
				IF @DataBaseBM & 2 > 0
					BEGIN
						TRUNCATE TABLE #Object

						SET @SQLStatement = '
							INSERT INTO #Object
								(
								[name],
								[definition]
								)
							SELECT
								P.name,
								SM.definition
							FROM
								' + @DestinationDatabase_Old + '.sys.sql_modules SM
								INNER JOIN ' + @DestinationDatabase_Old + '.sys.procedures P ON P.object_id = SM.object_id
							WHERE
								NOT EXISTS (SELECT 1 FROM ' + @DestinationDatabase_New + '.sys.procedures PN WHERE PN.name = P.name)
							
							UNION	
						
							SELECT
								V.name,
								SM.definition
							FROM
								' + @DestinationDatabase_Old + '.sys.sql_modules SM
								INNER JOIN ' + @DestinationDatabase_Old + '.sys.views V ON V.object_id = SM.object_id
							WHERE
								NOT EXISTS (SELECT 1 FROM ' + @DestinationDatabase_New + '.sys.views VN WHERE VN.name = V.name)'							

						EXEC (@SQLStatement)

						IF @Debug <> 0 SELECT TempTable = '#Object', * FROM #Object

						DECLARE pcDATA_Object_Cursor CURSOR FOR

							SELECT 
								[name],
								[definition]
							FROM
								#Object

							OPEN pcDATA_Object_Cursor
							FETCH NEXT FROM pcDATA_Object_Cursor INTO @name, @definition

							WHILE @@FETCH_STATUS = 0
								BEGIN

									IF @Debug <> 0 SELECT name = @name
									TRUNCATE TABLE #Count

									SET @SQLStatement = 'INSERT INTO #Count ([Counter]) SELECT [Counter] = COUNT(1) FROM ' + @DestinationDatabase_New + '.dbo.sysobjects WHERE name = ''' + @name + ''''
									EXEC (@SQLStatement)
									IF @Debug <> 0 SELECT TempTable = '#Count', * FROM #Count

									IF (SELECT [Counter] FROM #Count) = 0
										BEGIN
											SET @SQLStatement = 'EXEC ' + @DestinationDatabase_New + '.dbo.sp_executesql N''' + REPLACE(@definition, '''', '''''') + ''''
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									FETCH NEXT FROM pcDATA_Object_Cursor INTO @name, @definition
								END

						CLOSE pcDATA_Object_Cursor
						DEALLOCATE pcDATA_Object_Cursor	
---------------------------
					SET @Step = 'Create temp tables'	
						CREATE TABLE #TableList
							(
							TableName nvarchar(100) COLLATE DATABASE_DEFAULT,
							IdColumn nvarchar(100) COLLATE DATABASE_DEFAULT,
							StartValue int,
							SortOrder int,
							WhereClause nvarchar(1000) COLLATE DATABASE_DEFAULT,
							MandatoryColumn1 nvarchar(100) COLLATE DATABASE_DEFAULT,
							MandatoryValue1 nvarchar(255) COLLATE DATABASE_DEFAULT,
							MandatoryColumn2 nvarchar(100) COLLATE DATABASE_DEFAULT,
							MandatoryValue2 nvarchar(255) COLLATE DATABASE_DEFAULT,
							ManualCheckYN bit
							)

						INSERT INTO #TableList
							(
							TableName,
							IdColumn,
							StartValue,
							SortOrder,
							WhereClause,
							MandatoryColumn1,
							MandatoryValue1,
							MandatoryColumn2,
							MandatoryValue2,
							ManualCheckYN
							)
						SELECT
							TableName,
							IdColumn,
							StartValue,
							SortOrder,
							WhereClause,
							MandatoryColumn1,
							MandatoryValue1,
							MandatoryColumn2,
							MandatoryValue2,
							ManualCheckYN
						FROM
							(
									SELECT TableName = 'Canvas_AsumptionAccount',			IdColumn = NULL,			StartValue = NULL,	SortOrder = 10,	WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Menu_Users',					IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 20, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Profit_Dimensions',			IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 30, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Profit_DimensionsMembers',	IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 40, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0

							UNION	SELECT TableName = 'Canvas_Users',						IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 110, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Workflow',					IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 120, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Workflow_Detail',			IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 130, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_WorkFlow_Driver1',			IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 140, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Workflow_HideDetail',		IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 150, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0

							UNION	SELECT TableName = 'Canvas_Workflow_Name',				IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 210, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Workflow_ReForecast',		IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 220, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Workflow_Schedule',			IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 230, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Workflow_Schedule_Template',	IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 240, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Workflow_Segment',			IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 250, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							UNION	SELECT TableName = 'Canvas_Workflow_StoreNames',		IdColumn = 'RecordId',		StartValue = 1,		SortOrder = 260, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
							) sub

						IF @Debug <> 0 SELECT TempTable = '#TableList', * FROM #TableList ORDER BY SortOrder

						CREATE TABLE #ColumnList
							(
							ColumnName nvarchar(100) COLLATE DATABASE_DEFAULT,
							SortOrder int,
							PK bit
							)

						CREATE TABLE #Application
							(
							ApplicationID int
							)

						CREATE TABLE #Counter
							(
							[Counter] int
							)

					SET @Step = 'Create Table_Cursor'	
						DECLARE Table_Cursor CURSOR FOR

							SELECT
								TableName,
								IdColumn,
								StartValue,
								WhereClause,
								MandatoryColumn1,
								MandatoryValue1,
								MandatoryColumn2,
								MandatoryValue2,
								ManualCheckYN
							FROM
								#TableList
							ORDER BY
								SortOrder

							OPEN Table_Cursor
							FETCH NEXT FROM Table_Cursor INTO @TableName, @IdColumn, @StartValue, @WhereClause, @MandatoryColumn1, @MandatoryValue1, @MandatoryColumn2, @MandatoryValue2, @ManualCheckYN

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @Debug <> 0 SELECT TableName = @TableName, IdColumn = @IdColumn, StartValue = @StartValue
					
									TRUNCATE TABLE #ColumnList

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
												' + @DestinationDatabase_Old + '.sys.columns c
												INNER JOIN ' + @DestinationDatabase_Old + '.sys.tables t ON t.object_id = c.object_id AND t.name = ''' + @TableName + '''

											UNION SELECT
												ColumnName = c.name,
												SortOrder = c.column_id,
												PK = CASE WHEN ic.object_id IS NULL THEN 0 ELSE 1 END 
											FROM
												' + @DestinationDatabase_New + '.sys.columns c
												INNER JOIN ' + @DestinationDatabase_New + '.sys.tables t ON t.object_id = c.object_id AND t.name = ''' + @TableName + '''
												LEFT JOIN ' + @DestinationDatabase_New + '.sys.indexes i ON i.object_id = c.object_id AND i.is_primary_key <> 0
												LEFT JOIN ' + @DestinationDatabase_New + '.sys.index_columns ic ON ic.object_id = c.object_id and ic.index_id = i.index_id AND ic.column_id = c.column_id
											) sub
										' + CASE WHEN @MandatoryColumn1 IS NOT NULL THEN 'WHERE ColumnName <> ''' + @MandatoryColumn1 + '''' ELSE '' END + '
										' + CASE WHEN @MandatoryColumn2 IS NOT NULL THEN 'AND ColumnName <> ''' + @MandatoryColumn2 + '''' ELSE '' END + '
										GROUP BY
											ColumnName
										HAVING
											COUNT(1) = 2
										ORDER BY
											MAX(SortOrder)'

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									IF @Debug <> 0 SELECT TempTable = '#ColumnList', TableName = @TableName, * FROM #ColumnList ORDER BY SortOrder

									SELECT @FieldList = NULL, @InsertCheck = NULL

									SELECT @FieldList = ISNULL(@FieldList, '') + '[' + ColumnName + '], ' FROM #ColumnList ORDER BY SortOrder
									SELECT @InsertCheck = ISNULL(@InsertCheck, '') + 'D.[' + ColumnName + '] = S.[' + ColumnName + '] AND ' FROM #ColumnList WHERE PK <> 0 ORDER BY SortOrder

									SET @FieldList = SUBSTRING(@FieldList, 1, LEN(@FieldList) - 1)
									SET @InsertCheck = SUBSTRING(@InsertCheck, 1, LEN(@InsertCheck) - 4)

									IF (SELECT COUNT(1) FROM #ColumnList WHERE ColumnName = 'Version') > 0
										SET @VersionYN = 1
									ELSE
										SET @VersionYN = 0

									IF @IdColumn IS NOT NULL
										SET @SQLStatement = '
											SET IDENTITY_INSERT [' +@DestinationDatabase_New + ']..[' + @TableName + '] ON'
									ELSE
										SET @SQLStatement = ''

									SET @SQLStatement = @SQLStatement + '
											INSERT INTO ' +@DestinationDatabase_New + '..[' + @TableName + '] (' + @FieldList + CASE WHEN @MandatoryColumn1 IS NOT NULL THEN ', [' + @MandatoryColumn1 + ']' ELSE '' END + CASE WHEN @MandatoryColumn2 IS NOT NULL THEN ', [' + @MandatoryColumn2 + ']' ELSE '' END + ') 
											SELECT ' + @FieldList + CASE WHEN @MandatoryColumn1 IS NOT NULL THEN ', [' + @MandatoryColumn1 + '] = ' + @MandatoryValue1 ELSE '' END + CASE WHEN @MandatoryColumn2 IS NOT NULL THEN ', [' + @MandatoryColumn2 + '] = ' + @MandatoryValue2 ELSE '' END + ' FROM ' + @DestinationDatabase_Old + '..[' + @TableName + '] S
											WHERE NOT EXISTS (SELECT 1 FROM ' +@DestinationDatabase_New + '..[' + @TableName + '] D WHERE ' + @InsertCheck + ')' + 
											CASE WHEN @VersionYN <> 0 THEN ' AND [Version] LIKE ''%CUSTOM%''' ELSE '' END +
											CASE WHEN @IdColumn IS NOT NULL THEN ' AND [' + @IdColumn + '] >= ' + CONVERT(nvarchar(10), @StartValue) ELSE '' END +
											ISNULL(@WhereClause, '')

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SET @Inserted = @Inserted + @@ROWCOUNT

									IF @IdColumn IS NOT NULL
										BEGIN
											SET @SQLStatement = '
												SET IDENTITY_INSERT ' +@DestinationDatabase_New + '..[' + @TableName + '] OFF'
											EXEC (@SQLStatement)
										END

									IF @ManualCheckYN <> 0
										BEGIN
											TRUNCATE TABLE #Counter
											SET @SQLStatement = '
												INSERT INTO #Counter ([Counter])
												SELECT [Counter] = COUNT(1) FROM ' + @DestinationDatabase_Old + '..[' + @TableName + '] S
												WHERE ' +
												CASE WHEN @VersionYN <> 0 THEN ' [Version] LIKE ''%CUSTOM%''' ELSE '' END +
												CASE WHEN @IdColumn IS NOT NULL THEN ' AND [' + @IdColumn + '] >= ' + CONVERT(nvarchar(10), @StartValue) ELSE '' END +
												ISNULL(@WhereClause, '')

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											IF (SELECT [Counter] FROM #Counter) > 0
												BEGIN
													SET @SQLStatement =
														'--Run this query to see manually edited metadata rows that are not automatically transferred:' + CHAR(13) + CHAR(10) +
														'SELECT' + CHAR(13) + CHAR(10) + CHAR(9) + '*' + CHAR(13) + CHAR(10) + 'FROM' + CHAR(13) + CHAR(10) + CHAR(9) + '[' +@DestinationDatabase_New + '].[dbo].[' + @TableName + '] S' + CHAR(13) + CHAR(10) +
														'WHERE' + CHAR(13) + CHAR(10) + CHAR(9) + '[Variance] = ''ManualCheck'''

													INSERT INTO [dbo].[UpgradeManualCheck] ([ObjectType], [ObjectName], [Info])
													SELECT [ObjectType] = 'MetaData', [ObjectName] = @DestinationDatabase_Old + '..[' + @TableName + ']', [Info] = @SQLStatement
												END
										END

									FETCH NEXT FROM Table_Cursor INTO  @TableName, @IdColumn, @StartValue, @WhereClause, @MandatoryColumn1, @MandatoryValue1, @MandatoryColumn2, @MandatoryValue2, @ManualCheckYN
								END

						CLOSE Table_Cursor
						DEALLOCATE Table_Cursor	

						DROP TABLE #TableList
-----------------------------
						FETCH NEXT FROM DB_Cursor INTO @ETLDatabase_Old, @ETLDatabase_New, @DestinationDatabase_Old, @DestinationDatabase_New
					END
				END

		CLOSE DB_Cursor
		DEALLOCATE DB_Cursor

	SET @Step = 'Drop temp tables'	
		DROP TABLE #Object
		DROP TABLE #Count

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
