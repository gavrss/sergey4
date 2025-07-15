SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_ETL_Entity] 

	@ApplicationID int = NULL,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@SortOrder int = 0 OUT,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_ETL_Entity] @ApplicationID = 400, @Debug = true
--EXEC [spCreate_ETL_Entity] @ApplicationID = 600, @Debug = true
--EXEC [spCreate_ETL_Entity] @ApplicationID = 1317, @Debug = true
--EXEC [spCreate_ETL_Entity] @ApplicationID = 1324, @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SourceID int,
	@SourceID_varchar nvarchar(10),
	@ProcedureName nvarchar(100),
	@Action nvarchar(10),
	@BaseQuerySQLStatement nvarchar(max),
	@SQLStatement nvarchar(max),
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(50),
	@SourceType nvarchar(50),
	@Currency nchar(3),
	@FullDatabaseName nvarchar(100),
	@ServerName nvarchar(100),
	@DatabaseName nvarchar(100),
	@EntityCode nvarchar(50),
	@Count int,
	@CountString nvarchar(10),
	@SourceTypeFamilyID int,
	@SourceTypeID int,
	@SourceDBTypeID int,
	@Owner nvarchar(50),
	@FinanceAccountYN bit,
	@InstanceID int,
	@BaseModelID int,
	@TableName nvarchar(100),
	@DimensionName nvarchar(100),
	@CurrencyProperty nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.3.2151'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2065' SET @Description = 'Handle SourceTypeID = 6, pcEXCHANGE.'
		IF @Version = '1.2.2066' SET @Description = 'Regarding Enterprise; Default SelectYN to false when Currency is not set.'
		IF @Version = '1.2.2068' SET @Description = 'SET ANSI_WARNINGS OFF.'
		IF @Version = '1.3.2070' SET @Description = 'Collation problems fixed. SET ANSI_WARNINGS ON if needed.'
		IF @Version = '1.3.2076' SET @Description = 'Changed Description handling for Epicor ERP.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2101' SET @Description = 'Added Axapta.'
		IF @Version = '1.3.2107' SET @Description = 'Changed handling for pcEXCHANGE'
		IF @Version = '1.3.2110' SET @Description = 'Changed currency property handling for pcEXCHANGE'
		IF @Version = '1.3.2111' SET @Description = 'Added Navision. SelectYN defaulted to false for Fx models.'
		IF @Version = '1.3.2115' SET @Description = 'Changed default handling of SelectYN for Enterprise.'
		IF @Version = '1.3.0.2118' SET @Description = 'Changed default handling of SelectYN for pcExchange.'
		IF @Version = '1.3.1.2120' SET @Description = 'Changed default handling of FrequencyBM for pcExchange.'
		IF @Version = '1.4.0.2136' SET @Description = 'Changed BookID for Epicor ERP from ''Generic'' to '''' when N/A.'
		IF @Version = '2.0.2.2144' SET @Description = 'Handled Currency setting for ENT.'
		IF @Version = '2.0.2.2146' SET @Description = 'Set correct Par01 value (servername+dbname) for pcETL*..Entity.'
		IF @Version = '2.0.3.2151' SET @Description = 'Corrected Incorrect syntax, missing comma (,) near Par07.'

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

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Cursor on Sources'
		SELECT
			SourceID = S.SourceID,
			SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			SourceTypeID = S.SourceTypeID,
			SourceType = ST.SourceTypeName,
			SourceDBTypeID = ST.SourceDBTypeID,
			SourceTypeFamilyID = ST.SourceTypeFamilyID,
			ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			FinanceAccountYN = BM.FinanceAccountYN,
			BaseModelID = BM.BaseModelID
		INTO
			#Entity_Source
		FROM
			[Application] A 
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.SelectYN <> 0
			INNER JOIN Source S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			A.ApplicationID = @ApplicationID AND
			A.SelectYN <> 0

		IF @Debug <> 0 SELECT TempTable = '#Entity_Source', * FROM #Entity_Source

		DECLARE Entity_Source_Cursor CURSOR FOR

		SELECT
			SourceID,
			SourceDatabase,
			SourceTypeID,
			SourceType,
			SourceDBTypeID,
			SourceTypeFamilyID,
			ETLDatabase,
			FinanceAccountYN,
			BaseModelID
		FROM
			#Entity_Source
		ORDER BY
			SourceID

		OPEN Entity_Source_Cursor

		FETCH NEXT FROM Entity_Source_Cursor INTO @SourceID, @SourceDatabase, @SourceTypeID, @SourceType, @SourceDBTypeID, @SourceTypeFamilyID, @ETLDatabase, @FinanceAccountYN, @BaseModelID

		WHILE @@FETCH_STATUS = 0
			BEGIN

		IF @Debug <> 0
		  SELECT 
			SQLStatement = @SQLStatement,
			SourceDatabase = @SourceDatabase,
			SourceType = @SourceType,
			ETLDatabase = @ETLDatabase

		SET @SourceID_varchar = CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID))

		IF @SourceDBTypeID = 1 --Single
		  BEGIN

			IF @SourceTypeFamilyID = 1 --('E9', E10, 'AFR')
			  BEGIN
		  
				EXEC [spGet_Owner] @SourceTypeID, @Owner OUTPUT
			
				IF @FinanceAccountYN <> 0
					BEGIN
						SET @BaseQuerySQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.[dbo].[Entity]
			(
			SourceID,
			EntityCode,
			EntityName,
			Currency,
			SelectYN,
			Par01,
			Par02,
			Par03,
			Par04,
			Par05,
			Par06,
			Par07,
			Par08,
			Par09
			)
		SELECT
			SourceID = @SourceID,
			EntityCode = C.[Company] + ''''_'''' + GLB.[BookID],
			EntityName = C.[Name] + '''' - '''' + GLB.[BookID],
			Currency = UPPER(SUBSTRING(GLB.[CurrencyCode], 1, 3)),
			SelectYN = ' + CASE WHEN @BaseModelID = -3 THEN '0' ELSE 'CASE WHEN (SELECT COUNT(1) FROM Entity WHERE SourceID = @SourceID) = 0 THEN GLB.[MainBook] ELSE 0 END' END + ',
			Par01 = C.[Company],
			Par02 = GLB.[BookID],
			Par03 = GLB.COACode,
			Par04 = COAS.SegmentName,
			Par05 = ''''ACTUAL'''',
			Par06 = ''''BUDGET_ERP'''',
			Par07 = UPPER(SUBSTRING(GLB.[CurrencyCode], 1, 3)),
			Par08 = CONVERT(nvarchar, GLB.[MainBook]),
			Par09 = GLB.FiscalCalendarID
		FROM
			' + @SourceDatabase + '.[' + @Owner + '].[Company] C
			INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COA] COA ON COA.Company = C.Company
			INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = C.Company AND GLB.COACode = COA.COACode
			LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].COASegment COAS ON COAS.Company = C.Company AND COAS.COACode = COA.COACode AND COAS.SegmentNbr = 1
		WHERE
			(C.[Company] + ''''_'''' + GLB.[BookID] = @EntityCode OR @EntityCode = ''''-1'''') AND
			NOT EXISTS (SELECT 1 FROM [Entity] E WHERE E.SourceID = @SourceID AND E.EntityCode = C.[Company] + ''''_'''' + GLB.[BookID] COLLATE DATABASE_DEFAULT)

		SET @Inserted = @Inserted + @@ROWCOUNT'
					END
				ELSE
					BEGIN
						SET @BaseQuerySQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.[dbo].[Entity]
			(
			SourceID,
			EntityCode,
			EntityName,
			Currency,
			SelectYN,
			Par01,
			Par02,
			Par03,
			Par04,
			Par05,
			Par06,
			Par07,
			Par08
			)
		SELECT
			SourceID = @SourceID,
			EntityCode = C.[Company],
			EntityName = MAX(C.[Name]),
			Currency = MAX(UPPER(SUBSTRING(GLB.[CurrencyCode], 1, 3))),
			SelectYN = ' + CASE WHEN @BaseModelID = -3 THEN '0' ELSE '1' END + ',
			Par01 = C.[Company],
			Par02 = '''''''',
			Par03 = NULL,
			Par04 = NULL,
			Par05 = ''''ACTUAL'''',
			Par06 = ''''BUDGET_ERP'''',
			Par07 = MAX(UPPER(SUBSTRING(GLB.[CurrencyCode], 1, 3))),
			Par08 = 1
		FROM
			' + @SourceDatabase + '.[' + @Owner + '].[Company] C
			INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COA] COA ON COA.Company = C.Company
			INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = C.Company AND GLB.COACode = COA.COACode AND GLB.[MainBook] <> 0
		WHERE
			(C.[Company] = @EntityCode OR @EntityCode = ''''-1'''') AND
			NOT EXISTS (SELECT 1 FROM [Entity] E WHERE E.SourceID = @SourceID AND E.EntityCode = C.[Company] COLLATE DATABASE_DEFAULT)
		GROUP BY
			C.[Company]

		SET @Inserted = @Inserted + @@ROWCOUNT'

					END
			  END --End of @SourceTypeFamilyID = 1 ('E9', E10, 'AFR')

			ELSE IF @SourceTypeFamilyID = 4 --('AX')
			  BEGIN
				SET @BaseQuerySQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.[dbo].[Entity]
			(
			SourceID,
			EntityCode,
			EntityName,
			Currency,
			SelectYN,
			Par01,
			Par02,
			Par03,
			Par04,
			Par05,
			Par09
			)
		SELECT
			[SourceID] = @SourceID,
			[EntityCode] = L.[NAME] + CASE WHEN NC.[NAME] IS NULL THEN '''''''' ELSE ''''_'''' + CONVERT(nvarchar(20), L.[RECID]) END,
			[EntityName] = [DESCRIPTION],
			[Currency] = [ACCOUNTINGCURRENCY],
			[SelectYN] = ' + CASE WHEN @BaseModelID = -3 THEN '0' ELSE '1' END + ',
			[Par01] = [RECID],
			[Par02] = [PARTITION],
			[Par03] = [CHARTOFACCOUNTS],
			[Par04] = L.[NAME],
			[Par05] = ''''ACTUAL'''',
			[Par09] = [FISCALCALENDAR]
		FROM
			' + @SourceDatabase + '.[dbo].[LEDGER] L
			LEFT JOIN (SELECT NAME FROM ' + @SourceDatabase + '.[dbo].[LEDGER] GROUP BY NAME HAVING COUNT(1) > 1) NC ON NC.NAME = L.NAME
		WHERE
			(L.[NAME] = @EntityCode OR @EntityCode = ''''-1'''') AND
			NOT EXISTS (SELECT 1 FROM [Entity] E WHERE E.SourceID = @SourceID AND E.EntityCode = L.[NAME] COLLATE DATABASE_DEFAULT + CASE WHEN NC.[NAME] IS NULL THEN '''''''' ELSE ''''_'''' + CONVERT(nvarchar(20), L.[RECID]) END)
				
		SET @Inserted = @Inserted + @@ROWCOUNT'

			  END --End of @SourceTypeFamilyID = 4 ('AX')

			ELSE IF @SourceType IN ('EvryDW')
			  BEGIN

				SET @BaseQuerySQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.[dbo].[Entity]
			(
			SourceID,
			EntityCode,
			EntityName,
			Currency,
			SelectYN,
			Par01
			)
		SELECT
			[SourceID] = @SourceID,
			[EntityCode] = [CompanyCode],
			[EntityName] = [CompanyName],
			[Currency] = Currency.CurrencyCode,
			[SelectYN] = ' + CASE WHEN @BaseModelID = -3 THEN '0' ELSE 'CASE WHEN (SELECT COUNT(1) FROM Entity WHERE SourceID = @SourceID) = 0 THEN 1 ELSE 0 END' END + ',
			[Par01] = Country.CountryCode
		FROM
			' + @SourceDatabase + '.[dbo].[tblDimCompany] Company
			LEFT JOIN ' + @SourceDatabase + '.[dbo].[tblDimCountry] Country ON Country.CountryKey = Company.[CompanyCountryKey]
			LEFT JOIN ' + @SourceDatabase + '.[dbo].[tblDimCurrency] Currency ON Currency.CurrencyKey = Company.[CompanyCurrencyKey]
		WHERE
			NOT EXISTS (SELECT 1 FROM [Entity] E WHERE E.SourceID = @SourceID AND E.EntityCode = Company.[CompanyCode])

		SET @Inserted = @Inserted + @@ROWCOUNT'
	
			  END  --End of @SourceType = 'EvryDW'

			ELSE IF @SourceType IN ('pcEXCHANGE')
			  BEGIN

				SELECT @TableName = NULL, @DimensionName = NULL

				CREATE TABLE #TableName (TableName nvarchar(100))
				SET @SQLStatement = '
				INSERT INTO #TableName (TableName)
				SELECT
					TableName = ''[FactData_'' + SM.ModelName + '']''
				FROM
					[pcINTEGRATOR].[dbo].[Source] S
					INNER JOIN [pcINTEGRATOR].[dbo].[Model] M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
					INNER JOIN ' + @SourceDatabase + '.[dbo].[Model] SM ON SM.BaseModelID = M.BaseModelID
				WHERE
					S.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
					S.SelectYN <> 0'
				EXEC (@SQLStatement)
				SELECT @TableName = TableName FROM #TableName
				DROP TABLE #TableName

				CREATE TABLE #DimensionName (DimensionName nvarchar(100), CurrencyProperty nvarchar(100))
				SET @SQLStatement = '
				INSERT INTO #DimensionName (DimensionName, CurrencyProperty)
				SELECT
					DimensionName = D.DimensionName,
					CurrencyProperty = ''Property02''
				FROM
					' + @SourceDatabase + '.[dbo].[Dimension] D
				WHERE
					D.DimensionTypeID = 4'
				EXEC (@SQLStatement)

				CREATE TABLE #CountTable ([Count] int)

				SET @Count = 0
				WHILE @Count <= 20
					BEGIN
						SET @Count = @Count + 1
						SET @CountString = CASE WHEN @Count <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), @Count)

						TRUNCATE TABLE #CountTable
						SET @SQLStatement = '
							INSERT INTO #CountTable ([Count])
							SELECT
								[Count] = COUNT(1)
							FROM
								' + @SourceDatabase + '.[dbo].[Dimension] D
							WHERE
								D.DimensionTypeID = 4 AND
								D.PropertyName' + @CountString + ' = ''Currency'''

							EXEC(@SQLStatement)

							IF (SELECT [Count] FROM #CountTable) > 0
								BEGIN
									UPDATE #DimensionName
									SET CurrencyProperty = 'Property' + @CountString

									SET @Count = 21
								END
					END

				SELECT @DimensionName = DimensionName, @CurrencyProperty = CurrencyProperty FROM #DimensionName
				DROP TABLE #CountTable
				DROP TABLE #DimensionName
				
				IF @Debug <> 0 SELECT SourceID = @SourceID, SourceDatabase = @SourceDatabase, TableName = @TableName, DimensionName = @DimensionName

				SET @BaseQuerySQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.[dbo].[Entity]
			(
			SourceID,
			EntityCode,
			EntityName,
			Currency,
			SelectYN
			)
		SELECT DISTINCT
			[SourceID] = @SourceID,
			[EntityCode] = F.' + @DimensionName + ',
			[EntityName] = ISNULL(DD.[Description], F.' + @DimensionName + '),
			[Currency] = DD.' + @CurrencyProperty + ',
			[SelectYN] = CASE WHEN ' + CONVERT(nvarchar(10), @BaseModelID) + ' = -3 AND F.' + @DimensionName + ' <> ''''NONE'''' THEN 0 ELSE 1 END
		FROM
			' + @SourceDatabase + '.[dbo].' + @TableName + ' F
			LEFT JOIN ' + @SourceDatabase + '.[dbo].[DimensionData] DD ON DD.DimensionName = ''''' + @DimensionName + ''''' AND DD.Label = F.' + @DimensionName + '
		WHERE
			F.' + @DimensionName + ' IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[Entity] E WHERE E.SourceID = @SourceID AND E.EntityCode = F.' + @DimensionName + ')

		SET @Inserted = @Inserted + @@ROWCOUNT'

			  END  --End of @SourceType = 'pcEXCHANGE'

		  END  --End of @SourceDBTypeID = 1, Single

		ELSE IF @SourceDBTypeID = 2 --Multiple
		  BEGIN

			IF @SourceType = 'iScala'
			  BEGIN
				SET @BaseQuerySQLStatement = '
		SET @SelectedEntity = @EntityCode

		UPDATE E
		SET
			EntityName = CompanyName,
			Par01 = CASE WHEN ServerName = '''''''' + @@ServerName + '''''''' THEN ''''['''' + DBName + '''']'''' ELSE ''''['''' + ServerName + ''''].['''' + DBName + '''']'''' END,
			Par02 = ''''['''' + ServerName + '''']'''',
			Par03 = ''''['''' + DBName + '''']''''
		FROM
			' + @ETLDatabase + '.[dbo].[Entity] E
			INNER JOIN ' + @SourceDatabase + '.[dbo].ScaCompanies SC ON SC.CompanyCode COLLATE DATABASE_DEFAULT = E.EntityCode
		WHERE
			E.SourceID = @SourceID AND
			(E.EntityCode = @SelectedEntity OR @SelectedEntity = ''''-1'''')

		SET @Updated = @Updated + @@ROWCOUNT

		INSERT INTO ' + @ETLDatabase + '.[dbo].[Entity]
			(
			SourceID,
			EntityCode,
			EntityName,
			Currency,
			SelectYN,
			Par01,
			Par02,
			Par03,
			Par05,
			Par06
			)
		SELECT
			SourceID = @SourceID,
			EntityCode = CompanyCode,
			EntityName = CompanyName,
			Currency = '''''''', --Must be set
			SelectYN = ' + CASE WHEN @BaseModelID = -3 THEN '0' ELSE '1' END + ',
			Par01 = CASE WHEN ServerName = '''''''' + @@ServerName + '''''''' THEN ''''['''' + DBName + '''']'''' ELSE ''''['''' + ServerName + ''''].['''' + DBName + '''']'''' END,
			Par02 = ''''['''' + ServerName + '''']'''',
			Par03 = ''''['''' + DBName + '''']'''',
			Par05 = ''''ACTUAL'''',
			Par06 = ''''BUDGET_ERP''''
		FROM
			' +	@SourceDatabase + '.[dbo].ScaCompanies SC
		WHERE
			IsBlocked = 0 AND
			(SC.CompanyCode = @SelectedEntity OR @SelectedEntity = ''''-1'''') AND
			NOT EXISTS(SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[Entity] E WHERE E.SourceID = @SourceID AND E.EntityCode = SC.CompanyCode COLLATE DATABASE_DEFAULT)

		SET @Inserted = @Inserted + @@ROWCOUNT'
	
		SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

	SET @Step = ''''Cursor for handling non existence databases''''

		DECLARE Database_Existence_Cursor CURSOR FOR

		SELECT 
			EntityCode,
			ServerName = Par02,
			DBName = REPLACE(REPLACE(Par03, ''''['''', ''''''''), '''']'''', '''''''')
		FROM
			' + @ETLDatabase + '.[dbo].[Entity]
		WHERE
			SourceID = @SourceID AND 
			(EntityCode = @SelectedEntity OR @SelectedEntity = ''''-1'''') AND
			SelectYN <> 0

		OPEN Database_Existence_Cursor

		FETCH NEXT FROM Database_Existence_Cursor INTO @EntityCode, @ServerName, @DatabaseName'
	
		SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

		WHILE @@FETCH_STATUS = 0
			BEGIN

				SET @SQLStatement = ''''SELECT @internalVariable = COUNT(1) FROM '''' + @ServerName + ''''.master.sys.databases WHERE name = '''''''''''' + @DatabaseName + ''''''''''''''''
				EXEC sp_executesql @SQLStatement, N''''@internalVariable int OUT'''', @internalVariable = @Count OUT

				IF @Debug <> 0 SELECT SourceID = @SourceID, EntityCode = @EntityCode, ServerName = @ServerName, DatabaseName = @DatabaseName, [Count] = @Count
								
				IF @Count = 0
					BEGIN
						UPDATE [dbo].[Entity] 
						SET
							SelectYN = 0
						WHERE
							SourceID = @SourceID AND
							EntityCode = @EntityCode

						SET @Updated = @Updated + @@ROWCOUNT
					END

			FETCH NEXT FROM Database_Existence_Cursor INTO @EntityCode, @ServerName, @DatabaseName
			END

		CLOSE Database_Existence_Cursor
		DEALLOCATE Database_Existence_Cursor

SET @Step = ''''Cursor for setting Currency''''
	CREATE TABLE #CountExist
		(CountExist int)
	
	CREATE TABLE #Currency
		(Currency nchar(3) COLLATE DATABASE_DEFAULT)'
	
		SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

	DECLARE Currency_Cursor CURSOR FOR

	SELECT
		EntityCode,
		FullDatabaseName = Par01,
		ServerName = Par02,
		DatabaseName = Par03
	FROM
		[dbo].[Entity]
	WHERE
		SourceID = @SourceID AND
		(EntityCode = @SelectedEntity OR @SelectedEntity = ''''-1'''') AND
		SelectYN <> 0

	OPEN Currency_Cursor

	FETCH NEXT FROM Currency_Cursor INTO @EntityCode, @FullDatabaseName, @ServerName, @DatabaseName

	WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @SQLStatement = ''''SELECT CountExist = COUNT(1) FROM '''' + @ServerName + ''''.master.dbo.sysdatabases WHERE (''''''''['''''''' + name + '''''''']'''''''' = '''''''''''' + @DatabaseName + '''''''''''' OR name = '''''''''''' + @DatabaseName + '''''''''''')''''
			TRUNCATE TABLE #CountExist
			INSERT INTO #CountExist ([CountExist]) EXEC (@SQLStatement)

			IF (SELECT [CountExist] FROM #CountExist) > 0
				BEGIN
	  			SET @SQLStatement = ''''SELECT CountExist = COUNT(1) FROM '''' + @FullDatabaseName + ''''.sys.tables WHERE (''''''''['''''''' + name + '''''''']'''''''' = ''''''''ScaCompanyProperty'''''''' OR name = ''''''''ScaCompanyProperty'''''''')''''
				TRUNCATE TABLE #CountExist
				INSERT INTO #CountExist ([CountExist]) EXEC (@SQLStatement)

				IF (SELECT [CountExist] FROM #CountExist) > 0
					BEGIN
						IF @Debug <> 0 PRINT @EntityCode

						SET @SQLStatement = ''''
							SELECT Currency = P.[Value]
							FROM '''' + @FullDatabaseName + ''''.[dbo].ScaCompanyProperty P
							WHERE P.CompanyCode = '''''''''''' + @EntityCode + '''''''''''' AND P.PropertyID = 111''''

						INSERT INTO #Currency ([Currency]) EXEC (@SQLStatement)

						SELECT @Currency = Currency FROM #Currency
						TRUNCATE TABLE #Currency'
	
		SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

						UPDATE [dbo].[Entity]
						SET
							Currency = @Currency,
							Par07 = @Currency 
						WHERE
							SourceID = @SourceID AND 
							EntityCode = @EntityCode

						SET @Updated = @Updated + @@ROWCOUNT
					END
				ELSE
					BEGIN
						UPDATE [dbo].[Entity]
						SET
							SelectYN = 0
						WHERE
							SourceID = @SourceID AND 
							EntityCode = @EntityCode

						SET @Updated = @Updated + @@ROWCOUNT
					END
				END
			
		FETCH NEXT FROM Currency_Cursor INTO @EntityCode, @FullDatabaseName, @ServerName, @DatabaseName
		END

	CLOSE Currency_Cursor
	DEALLOCATE Currency_Cursor

	SET @Step = ''''Drop temp tables''''
		DROP TABLE #Currency
		DROP TABLE #CountExist'
	
			  END --End of @SourceType = 'iScala'

			ELSE IF @SourceType = 'ENT'
			  BEGIN
			  --SELECT * FROM [Ent_C74SP4].dbo.[smcomp] C;
				SET @BaseQuerySQLStatement = '
		SET @SelectedEntity = @EntityCode

		INSERT INTO ' + @ETLDatabase + '.[dbo].[Entity]
			(
			SourceID,
			EntityCode,
			EntityName,
			Currency,
			SelectYN,
			Par01,
			Par02,
			Par03,
			Par05,
			Par06
			)
		SELECT
			SourceID = @SourceID,
			EntityCode = smc.company_id,
			EntityName = smc.company_name,
			Currency = NULL, --Must be set
			SelectYN = ' + CASE WHEN @BaseModelID = -3 THEN '0' ELSE '1' END + ',
			Par01 = @@ServerName + ''''.'''' + db_name,
			Par02 = @@ServerName,
			Par03 = db_name,
			Par05 = ''''ACTUAL'''',
			Par06 = ''''BUDGET_ERP''''
		FROM
			' +	@SourceDatabase + '.[dbo].[smcomp] smc
		WHERE
			(smc.company_id = @SelectedEntity OR @SelectedEntity = ''''-1'''') AND
			NOT EXISTS(SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[Entity] E WHERE E.SourceID = @SourceID AND E.EntityCode = CONVERT(nvarchar, smc.company_id))

		SET @Inserted = @Inserted + @@ROWCOUNT
		'

		SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '
	SET @Step = ''''Cursor for setting Currency''''
		CREATE TABLE #CountExist
			(CountExist int)
	
		CREATE TABLE #Currency
			(Currency nchar(3) COLLATE DATABASE_DEFAULT)

		DECLARE Currency_Cursor CURSOR FOR

		SELECT
			EntityCode,
			FullDatabaseName = Par01,
			ServerName = Par02,
			DatabaseName = Par03
		FROM
			[dbo].[Entity]
		WHERE
			SourceID = @SourceID AND
			(EntityCode = @SelectedEntity OR @SelectedEntity = ''''-1'''')

		OPEN Currency_Cursor

		FETCH NEXT FROM Currency_Cursor INTO @EntityCode, @FullDatabaseName, @ServerName, @DatabaseName

		WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @SQLStatement = ''''SELECT CountExist = COUNT(1) FROM '''' + @ServerName + ''''.master.dbo.sysdatabases WHERE (''''''''['''''''' + name + '''''''']'''''''' = '''''''''''' + @DatabaseName + '''''''''''' OR name = '''''''''''' + @DatabaseName + '''''''''''')''''
				TRUNCATE TABLE #CountExist
				INSERT INTO #CountExist ([CountExist]) EXEC (@SQLStatement)

				IF (SELECT [CountExist] FROM #CountExist) > 0
					BEGIN
	  				SET @SQLStatement = ''''SELECT CountExist = COUNT(1) FROM '''' + @FullDatabaseName + ''''.sys.tables WHERE (''''''''['''''''' + name + '''''''']'''''''' = ''''''''glco'''''''' OR name = ''''''''glco'''''''')''''
					TRUNCATE TABLE #CountExist
					INSERT INTO #CountExist ([CountExist]) EXEC (@SQLStatement)

					IF (SELECT [CountExist] FROM #CountExist) > 0
						BEGIN
							IF @Debug <> 0 PRINT @EntityCode

							SET @SQLStatement = ''''
								SELECT Currency = UPPER(LEFT(P.home_currency, 3))
								FROM '''' + @FullDatabaseName + ''''.[dbo].glco P
								WHERE P.company_id = '''''''''''' + @EntityCode + ''''''''''''''''

							INSERT INTO #Currency ([Currency]) EXEC (@SQLStatement)

							SELECT @Currency = Currency FROM #Currency
							TRUNCATE TABLE #Currency'
	
			SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

							UPDATE E
							SET
								Currency = ISNULL(@Currency,E.Currency),
								Par07 = ISNULL(@Currency,E.Currency)
							FROM 
								[dbo].[Entity] E
							WHERE
								SourceID = @SourceID AND 
								EntityCode = @EntityCode

							SET @Updated = @Updated + @@ROWCOUNT
						END
					END
				ELSE
					BEGIN
						UPDATE [dbo].[Entity]
						SET
							SelectYN = 0 
						WHERE
							SourceID = @SourceID AND 
							EntityCode = @EntityCode

						SET @Updated = @Updated + @@ROWCOUNT
					END
			
			FETCH NEXT FROM Currency_Cursor INTO @EntityCode, @FullDatabaseName, @ServerName, @DatabaseName
			END

		CLOSE Currency_Cursor
		DEALLOCATE Currency_Cursor

		SET @Step = ''''Drop temp tables''''
			DROP TABLE #Currency
			DROP TABLE #CountExist'


			  END --End of @SourceType = 'ENT'

			ELSE IF @SourceType = 'NAV'
			  BEGIN
				SET @BaseQuerySQLStatement = '

		DECLARE
			@EntityCodeNum int,
			@EntityCodeEx nvarchar(50),
			@EntityName nvarchar(100)

		SELECT @EntityCodeNum = ISNULL(MAX(EntityCode), 800) FROM ' + @ETLDatabase + '.[dbo].[Entity] E WHERE E.SourceID = @SourceID

		DECLARE Entity_Cursor CURSOR FOR

			SELECT
				EntityName = C.[Name],
				EntityCodeEx = Ex.[EntityCode]
			FROM
				' + @SourceDatabase + '.[dbo].[Company] C
				LEFT JOIN (SELECT EntityName = E.Par01, EntityCode = MAX(E.EntityCode)  FROM ' + @ETLDatabase + '.[dbo].[Entity] E INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.SourceID = E.SourceID AND S.SourceTypeID = 8 GROUP BY E.Par01) Ex ON Ex.EntityName = C.Name COLLATE DATABASE_DEFAULT
			WHERE
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[Entity] E WHERE E.SourceID = @SourceID AND E.[Par01] = REPLACE(C.[Name] COLLATE DATABASE_DEFAULT, ''''.'''', ''''_'''') + ''''$'''')
			ORDER BY
				ISNULL(Ex.EntityCode, ''''ZZZZ''''),
				C.[Name]

			OPEN Entity_Cursor
			FETCH NEXT FROM Entity_Cursor INTO @EntityName, @EntityCodeEx

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @EntityCodeEx IS NULL
						BEGIN
							SET @EntityCodeNum = @EntityCodeNum + 1
							SET @EntityCodeEx = CONVERT(nvarchar(50), @EntityCodeNum)
						END

					INSERT INTO ' + @ETLDatabase + '.[dbo].[Entity]
						(
						SourceID,
						EntityCode,
						EntityName,
						Currency,
						SelectYN,
						Par01,
						Par02,
						Par03,
						Par05,
						Par06
						)
					SELECT
						SourceID = @SourceID,
						EntityCode = @EntityCodeEx,
						EntityName = @EntityName,
						Currency = '''''''', --Must be set
						SelectYN = ' + CASE WHEN @BaseModelID = -3 THEN '0' ELSE '1' END + ',
						Par01 = REPLACE(@EntityName, ''''.'''', ''''_'''') + ''''$'''',
						Par02 = NULL,
						Par03 = NULL,
						Par05 = NULL,
						Par06 = NULL
					WHERE
						NOT EXISTS(SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[Entity] E WHERE E.SourceID = @SourceID AND E.EntityCode = @EntityCode)

					SET @Inserted = @Inserted + @@ROWCOUNT

					FETCH NEXT FROM Entity_Cursor INTO @EntityName, @EntityCodeEx
				END
		CLOSE Entity_Cursor
		DEALLOCATE Entity_Cursor'



			  END --End of @SourceType = 'NAV'

		  END --End of @SourceDBTypeID = 2, Multiple

--End of source specific

	IF @Debug <> 0 PRINT @BaseQuerySQLStatement 

	IF @BaseQuerySQLStatement IS NULL
		GOTO NEXTROW

	SET @Step = 'CREATE PROCEDURE'

	SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_ETL_Entity'

	SET @Step = 'Determine CREATE or ALTER'
	CREATE TABLE #Action
		(
		[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
		)

	SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
	INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
	SELECT @Action = [Action] FROM #Action
	DROP TABLE #Action

	SET @Step = 'Set SQL statement for creating Procedure'

		SET @SQLStatement = '
SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@Count int,
	@FullDatabaseName nvarchar(100),
	@ServerName nvarchar(100),
	@DatabaseName nvarchar(100),
	@ETLDatabase nvarchar(50),
	@Currency nchar(3),
	@SelectedEntity nvarchar(50),
	@LinkedYN bit,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = ''''Insert into Entity table'''''

SET @SQLStatement = @SQLStatement + @BaseQuerySQLStatement + '
		SET ANSI_WARNINGS OFF

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'
	
SET @Step = 'Make Creation statement'

SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ProcedureName + ']

@JobID int = 0,
@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
@EntityCode nvarchar(50) = ''''-1'''',
@Rows int = NULL,
@GetVersion bit = 0,
@Duration time(7) = ''''00:00:00'''' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT,
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS' + CHAR(13) + CHAR(10) + @SQLStatement

			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

			IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE', [SQLStatement] = @SQLStatement

			EXEC (@SQLStatement)

			SET @SortOrder = @SortOrder + 10
			SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, FrequencyBM, SelectYN) SELECT LoadTypeBM = 1, Command = ''' + @ProcedureName + ''', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', FrequencyBM = ' + CASE WHEN @SourceTypeID = 6 THEN '1' ELSE '2' END + ', SelectYN = 1
			WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''' + @ProcedureName + ''')'
			EXEC (@SQLStatement)

			NEXTROW:

			FETCH NEXT FROM Entity_Source_Cursor INTO @SourceID, @SourceDatabase, @SourceTypeID, @SourceType, @SourceDBTypeID, @SourceTypeFamilyID, @ETLDatabase, @FinanceAccountYN, @BaseModelID
			END

		CLOSE Entity_Source_Cursor
		DEALLOCATE Entity_Source_Cursor

	SET @Step = 'Drop temp table'	
		DROP TABLE #Entity_Source

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + @SourceID_varchar + ')', @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + @SourceID_varchar + ')', GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH







GO
