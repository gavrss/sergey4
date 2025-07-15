SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFetch_pcETL_BU] 

	@JobID int = 0,
	@Param_01 nvarchar(100) = NULL OUT, --@SourceDatabase, (old pcINTEGRATOR)
	@Param_02 nvarchar(100) = NULL OUT, --@InstanceID

	@DataBaseBM int = 3, --1 = pcETL, 2 = pcDATA, 3 = All databases

	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--

AS

--EXEC [spFetch_pcINTEGRATOR_BU] @Debug = 1
/*
DECLARE
	@Param_01 nvarchar(100),
	@Param_02 nvarchar(100)

EXEC [spFetch_pcINTEGRATOR_BU] @Param_01 = @Param_01 OUT, @Param_02 = @Param_02 OUT

SELECT Param_01 = @Param_01, Param_02 = @Param_02
*/

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@SQLStatement nvarchar(max),

	@ETLDatabase_Old nvarchar(100),
	@ETLDatabase_New nvarchar(100),
	@DestinationDatabase_Old nvarchar(100),
	@DestinationDatabase_New nvarchar(100),


	@SourceDatabase nvarchar(100),
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
	@InstanceID int,
	@ApplicationID_Old int,
	@ApplicationID int,
	@ModelID_Old int,
	@ModelID int,
	@ETLDatabase nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.1.2123'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.1.2120' SET @Description = 'Procedure created.'
		IF @Version = '1.3.1.2121' SET @Description = 'Deselect Applications where ApplicationName LIKE %Demo%.'
		IF @Version = '1.3.1.2123' SET @Description = 'Added @Param_02 (@InstanceID).'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

	SET @Step = 'Check for Sourcedatabase'
		UPDATE S SET SourceDatabase = ISNULL(@Param_01, S.SourceDatabase) FROM [Source] S WHERE SourceID = 0 
		SELECT @SourceDatabase = SourceDatabase FROM [Source] WHERE SourceID = 0

		IF @Debug <> 0 SELECT SourceDatabase = @SourceDatabase

		IF @SourceDatabase IS NULL OR @SourceDatabase = 'N/A'
			BEGIN
				SET @Message = 'There is no defined old pcINTEGRATOR database to read from. The upgrade will be interrupted.'
				SET @Severity = 16
				GOTO EXITPOINT
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
						SELECT DataBaseBM = @DataBaseBM
/*
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
*/
--					END

						FETCH NEXT FROM DB_Cursor INTO @ETLDatabase_Old, @ETLDatabase_New, @DestinationDatabase_Old, @DestinationDatabase_New
					END
				END

		CLOSE DB_Cursor
		DEALLOCATE DB_Cursor


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
					SELECT TableName = 'Customer',					IdColumn = 'CustomerID',			StartValue = 1,		SortOrder = 10,	WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'Instance',					IdColumn = 'InstanceID',			StartValue = 1,		SortOrder = 20, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'Application',				IdColumn = 'ApplicationID',			StartValue = 1,		SortOrder = 30, WhereClause = NULL, MandatoryColumn1 = 'SelectYN', MandatoryValue1 = '0', MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'Model',						IdColumn = 'ModelID',				StartValue = 1,		SortOrder = 40, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0

			UNION	SELECT TableName = 'SourceDBType',				IdColumn = 'SourceDBTypeID',		StartValue = 1001,	SortOrder = 110, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'SourceTypeFamily',			IdColumn = 'SourceTypeFamilyID',	StartValue = 1001,	SortOrder = 120, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'SourceType',				IdColumn = 'SourceTypeID',			StartValue = 1001,	SortOrder = 130, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'Source',					IdColumn = 'SourceID',				StartValue = 1,		SortOrder = 140, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0

			UNION	SELECT TableName = 'Language',					IdColumn = 'LanguageID',			StartValue = 1001,	SortOrder = 210, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'Application_Translation',	IdColumn = NULL,					StartValue = NULL,	SortOrder = 220, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'DimensionType',				IdColumn = 'DimensionTypeID',		StartValue = 1001,	SortOrder = 230, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'Dimension',					IdColumn = 'DimensionID',			StartValue = 1001,	SortOrder = 240, WhereClause = NULL, MandatoryColumn1 = 'SelectYN', MandatoryValue1 = 'CASE WHEN (SELECT COUNT(1) FROM Dimension D WHERE D.DimensionName = S.DimensionName) > 0 THEN 0 ELSE S.SelectYN END', MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'DataType',					IdColumn = 'DataTypeID',			StartValue = 1001,	SortOrder = 250, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'Property',					IdColumn = 'PropertyID',			StartValue = 1001,	SortOrder = 260, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'Table',						IdColumn = 'TableID',				StartValue = 1001,	SortOrder = 270, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0

			UNION	SELECT TableName = 'Model_Dimension',			IdColumn = NULL,					StartValue = NULL,	SortOrder = 310, WhereClause = NULL, MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0

			UNION	SELECT TableName = 'SqlSource_Dimension',		IdColumn = NULL,					StartValue = NULL,	SortOrder = 410, WhereClause = ' AND (DimensionID >= 1001 OR PropertyID >= 1001)', MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'SqlSource_Model_FACT',		IdColumn = NULL,					StartValue = NULL,	SortOrder = 420, WhereClause = ' AND DimensionID >= 1001', MandatoryColumn1 = NULL, MandatoryValue1 = NULL, MandatoryColumn2 = NULL, MandatoryValue2 = NULL, ManualCheckYN = 0
			UNION	SELECT TableName = 'SqlSource_Dimension',		IdColumn = NULL,					StartValue = NULL,	SortOrder = 510, WhereClause = ' AND DimensionID < 1001 AND PropertyID < 1001', MandatoryColumn1 = 'Variance', MandatoryValue1 = '''ManualCheck''', MandatoryColumn2 = 'SelectYN', MandatoryValue2 = 0, ManualCheckYN = 1
			UNION	SELECT TableName = 'SqlSource_Model_FACT',		IdColumn = NULL,					StartValue = NULL,	SortOrder = 520, WhereClause = ' AND DimensionID < 1001', MandatoryColumn1 = 'Variance', MandatoryValue1 = '''ManualCheck''', MandatoryColumn2 = 'SelectYN', MandatoryValue2 = 0, ManualCheckYN = 1
			) sub


/*
pcDATA tables to update:
-----------------------
Canvas_AsumptionAccount
Canvas_Menu_Users
Canvas_Profit_Dimensions
Canvas_Profit_DimensionsMembers
Canvas_Users
Canvas_Workflow
Canvas_Workflow_Detail
Canvas_WorkFlow_Driver1
Canvas_Workflow_HideDetail
Canvas_Workflow_Name
Canvas_Workflow_ReForecast
Canvas_Workflow_Schedule
Canvas_Workflow_Schedule_Template
Canvas_Workflow_Segment
Canvas_Workflow_StoreNames
*/


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
								' + @SourceDatabase + '.sys.columns c
								INNER JOIN ' + @SourceDatabase + '.sys.tables t ON t.object_id = c.object_id AND t.name = ''' + @TableName + '''

							UNION SELECT
								ColumnName = c.name,
								SortOrder = c.column_id,
								PK = CASE WHEN ic.object_id IS NULL THEN 0 ELSE 1 END 
							FROM
								pcINTEGRATOR.sys.columns c
								INNER JOIN pcINTEGRATOR.sys.tables t ON t.object_id = c.object_id AND t.name = ''' + @TableName + '''
								LEFT JOIN pcINTEGRATOR.sys.indexes i ON i.object_id = c.object_id AND i.is_primary_key <> 0
								LEFT JOIN pcINTEGRATOR.sys.index_columns ic ON ic.object_id = c.object_id and ic.index_id = i.index_id AND ic.column_id = c.column_id
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

--					IF @ManualCheckYN = 0
--						BEGIN

					IF @IdColumn IS NOT NULL
						SET @SQLStatement = '
							SET IDENTITY_INSERT pcINTEGRATOR..[' + @TableName + '] ON'
					ELSE
						SET @SQLStatement = ''

					SET @SQLStatement = @SQLStatement + '
							INSERT INTO pcINTEGRATOR..[' + @TableName + '] (' + @FieldList + CASE WHEN @MandatoryColumn1 IS NOT NULL THEN ', [' + @MandatoryColumn1 + ']' ELSE '' END + CASE WHEN @MandatoryColumn2 IS NOT NULL THEN ', [' + @MandatoryColumn2 + ']' ELSE '' END + ') 
							SELECT ' + @FieldList + CASE WHEN @MandatoryColumn1 IS NOT NULL THEN ', [' + @MandatoryColumn1 + '] = ' + @MandatoryValue1 ELSE '' END + CASE WHEN @MandatoryColumn2 IS NOT NULL THEN ', [' + @MandatoryColumn2 + '] = ' + @MandatoryValue2 ELSE '' END + ' FROM ' + @SourceDatabase + '..[' + @TableName + '] S
							WHERE NOT EXISTS (SELECT 1 FROM pcINTEGRATOR..[' + @TableName + '] D WHERE ' + @InsertCheck + ')' + 
							CASE WHEN @VersionYN <> 0 THEN ' AND [Version] LIKE ''%CUSTOM%''' ELSE '' END +
							CASE WHEN @IdColumn IS NOT NULL THEN ' AND [' + @IdColumn + '] >= ' + CONVERT(nvarchar(10), @StartValue) ELSE '' END +
							ISNULL(@WhereClause, '')

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Inserted = @Inserted + @@ROWCOUNT

					IF @IdColumn IS NOT NULL
						BEGIN
							SET @SQLStatement = '
								SET IDENTITY_INSERT pcINTEGRATOR..[' + @TableName + '] OFF'
							EXEC (@SQLStatement)
						END
--						END
--					ELSE
					IF @ManualCheckYN <> 0
						BEGIN
							TRUNCATE TABLE #Counter
							SET @SQLStatement = '
								INSERT INTO #Counter ([Counter])
								SELECT [Counter] = COUNT(1) FROM ' + @SourceDatabase + '..[' + @TableName + '] S
								WHERE ' +
								CASE WHEN @VersionYN <> 0 THEN ' [Version] LIKE ''%CUSTOM%''' ELSE '' END +
								CASE WHEN @IdColumn IS NOT NULL THEN ' AND [' + @IdColumn + '] >= ' + CONVERT(nvarchar(10), @StartValue) ELSE '' END +
								ISNULL(@WhereClause, '')

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF (SELECT [Counter] FROM #Counter) > 0
								BEGIN
/*
									SET @SQLStatement =
										'--Run this query to see manually edited metadata rows that are not automatically transferred:' + CHAR(13) + CHAR(10) +
										'SELECT' + CHAR(13) + CHAR(10) + CHAR(9) + '*' + CHAR(13) + CHAR(10) + 'FROM' + CHAR(13) + CHAR(10) + CHAR(9) + @SourceDatabase + '..[' + @TableName + '] S' + CHAR(13) + CHAR(10) +
										'WHERE' + CHAR(13) + CHAR(10) + CHAR(9) +
											CASE WHEN @VersionYN <> 0 THEN '[Version] LIKE ''%CUSTOM%''' ELSE '' END +
											CASE WHEN @IdColumn IS NOT NULL THEN ' AND [' + @IdColumn + '] >= ' + CONVERT(nvarchar(10), @StartValue) ELSE '' END +
											ISNULL(@WhereClause, '')
*/
									SET @SQLStatement =
										'--Run this query to see manually edited metadata rows that are not automatically transferred:' + CHAR(13) + CHAR(10) +
										'SELECT' + CHAR(13) + CHAR(10) + CHAR(9) + '*' + CHAR(13) + CHAR(10) + 'FROM' + CHAR(13) + CHAR(10) + CHAR(9) + '[pcINTEGRATOR].[dbo].[' + @TableName + '] S' + CHAR(13) + CHAR(10) +
										'WHERE' + CHAR(13) + CHAR(10) + CHAR(9) + '[Variance] = ''ManualCheck'''

									INSERT INTO [dbo].[UpgradeManualCheck] ([ObjectType], [ObjectName], [Info])
									SELECT [ObjectType] = 'MetaData', [ObjectName] = @SourceDatabase + '..[' + @TableName + ']', [Info] = @SQLStatement
								END
						END

					FETCH NEXT FROM Table_Cursor INTO  @TableName, @IdColumn, @StartValue, @WhereClause, @MandatoryColumn1, @MandatoryValue1, @MandatoryColumn2, @MandatoryValue2, @ManualCheckYN
				END

		CLOSE Table_Cursor
		DEALLOCATE Table_Cursor	

	SET @Step = 'Get @InstanceID'
		CREATE TABLE #Instance (InstanceID int)
		SET @SQLStatement = '
			INSERT INTO #Instance (InstanceID) SELECT InstanceID = MAX(InstanceID) FROM ' + @SourceDatabase + '..Instance WHERE InstanceID > 0'
		EXEC (@SQLStatement)
		SELECT @InstanceID = InstanceID FROM #Instance

	SET @Step = 'Create new Applications'	
		SET @SQLStatement = '
			INSERT INTO #Application
				(
				ApplicationID
				)
			SELECT
				A.ApplicationID
			FROM
				[Application] A
				INNER JOIN ' + @SourceDatabase + '..[Application] SA ON SA.ApplicationID = A.ApplicationID
			WHERE
				A.ApplicationID >= 1 AND
				NOT EXISTS (SELECT 1 FROM [Application] D WHERE D.ApplicationName = A.ApplicationName + ''_'' + ''' + REPLACE(@Version, '.', '_') + ''')'

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)
			IF @Debug <> 0 SELECT TempTable = 'Application', * FROM #Application

		DECLARE Application_Cursor CURSOR FOR

			SELECT 
				ApplicationID
			FROM
				#Application
			ORDER BY
				ApplicationID

			OPEN Application_Cursor
			FETCH NEXT FROM Application_Cursor INTO @ApplicationID_Old

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT ApplicationID_Old = @ApplicationID_Old

					INSERT INTO [Application]
						(
						ApplicationName,
						ApplicationDescription,
						ApplicationServer,
						InstanceID,
						ETLDatabase,
						DestinationDatabase,
						AdminUser,
						FiscalYearStartMonth,
						LanguageID,
						InheritedFrom,
						SelectYN
						)
					SELECT
						ApplicationName + '_' + REPLACE(@Version, '.', '_'),
						ApplicationDescription,
						ApplicationServer,
						InstanceID,
						ETLDatabase,
						DestinationDatabase,
						AdminUser,
						FiscalYearStartMonth,
						LanguageID,
						InheritedFrom = @ApplicationID_Old,
						SelectYN = CASE WHEN A.ApplicationName LIKE '%Demo%' THEN 0 ELSE 1 END
					FROM
						[Application] A
					WHERE
						A.ApplicationID = @ApplicationID_Old

					SET @ApplicationID = @@IDENTITY

					DECLARE Model_Cursor CURSOR FOR

						SELECT 
							[ModelID]
						FROM
							Model
						WHERE
							ApplicationID = @ApplicationID_Old
						ORDER BY
							ModelID

						OPEN Model_Cursor
						FETCH NEXT FROM Model_Cursor INTO @ModelID_Old

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @Debug <> 0 SELECT ModelID_Old = @ModelID_Old

								INSERT INTO Model
									( 
									[ModelName],
									[ModelDescription],
									[ApplicationID],
									[BaseModelID],
									[ModelBM],
									[ListSetBM],
									[TimeLevelID],
									[TimeTypeBM],
									[OptFinanceDimYN],
									[FinanceAccountYN],
									[TextSupportYN],
									[VirtualYN],
									[DynamicRule],
									[StartupWorkbook],
									[Introduced],
									[InheritedFrom],
									[SelectYN]
									)
								SELECT 
									[ModelName],
									[ModelDescription],
									[ApplicationID] = @ApplicationID,
									[BaseModelID],
									[ModelBM],
									[ListSetBM],
									[TimeLevelID],
									[TimeTypeBM],
									[OptFinanceDimYN],
									[FinanceAccountYN],
									[TextSupportYN],
									[VirtualYN],
									[DynamicRule],
									[StartupWorkbook],
									[Introduced],
									[InheritedFrom] = @ModelID_Old,
									[SelectYN] = 1
								FROM
									Model
								WHERE
									ModelID = @ModelID_Old

								SET @ModelID = @@IDENTITY
								
								INSERT INTO [Source]
									(
									[SourceName],
									[SourceDescription],
									[BusinessProcess],
									[ModelID],
									[SourceTypeID],
									[SourceDatabase],
									[ETLDatabase_Linked],
									[StartYear],
									[InheritedFrom],
									[SelectYN]
									)
								SELECT
									[SourceName],
									[SourceDescription],
									[BusinessProcess],
									[ModelID] = @ModelID,
									[SourceTypeID],
									[SourceDatabase],
									[ETLDatabase_Linked] = NULL,
									[StartYear],
									[InheritedFrom] = [SourceID],
									[SelectYN] = 1
								FROM
									[Source]
								WHERE
									ModelID = @ModelID_Old
								ORDER BY
									SourceID

								UPDATE S
								SET
									[BusinessProcess] = ST.SourceTypeName + '_' + CONVERT(nvarchar(10), S.[SourceID])
								FROM
									[Source] S
									INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
								WHERE
									[ModelID] = @ModelID

								FETCH NEXT FROM Model_Cursor INTO @ModelID_Old
							END

					CLOSE Model_Cursor
					DEALLOCATE Model_Cursor	

					FETCH NEXT FROM Application_Cursor INTO @ApplicationID_Old
				END

		CLOSE Application_Cursor
		DEALLOCATE Application_Cursor	
		
	SET @Step = 'Fill table UpgradeManualCheck'
		DECLARE Check_Cursor CURSOR FOR

			SELECT DISTINCT
				A.ETLDatabase 
			FROM
				[Application] A
				INNER JOIN #Application AA ON AA.ApplicationID = A.ApplicationID
			ORDER BY
				A.ETLDatabase

			OPEN Check_Cursor
			FETCH NEXT FROM Check_Cursor INTO @ETLDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT ETLDatabase = @ETLDatabase

					SET @SQLStatement = '
						INSERT INTO [dbo].[UpgradeManualCheck] ([ObjectType], [ObjectName], [Info])
						SELECT [ObjectType] = CASE xtype WHEN ''P'' THEN ''Procedure'' WHEN ''V'' THEN ''View'' ELSE xtype END, [ObjectName] = ''' + @ETLDatabase + '..'' + name, Info = ''Manually created object'' FROM ' + @ETLDatabase + '..sysobjects WHERE name LIKE ''%HC'''

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Check_Cursor INTO @ETLDatabase
				END

		CLOSE Check_Cursor
		DEALLOCATE Check_Cursor		

		IF @Debug <> 0 SELECT * FROM [UpgradeManualCheck]

	SET @Step = 'Drop temp tables'	
		DROP TABLE #TableList
		DROP TABLE #ColumnList
		DROP TABLE #Application
		DROP TABLE #Counter
		DROP TABLE #Instance

	SET @Step = 'Set @Param values'
		SET @Param_01 = @SourceDatabase
		SET @Param_02 = @InstanceID

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

SET @Step = 'EXITPOINT:'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100) WITH NOWAIT


GO
