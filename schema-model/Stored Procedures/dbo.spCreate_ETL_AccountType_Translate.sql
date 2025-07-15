SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_ETL_AccountType_Translate] 

	@SourceID int = NULL,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC spCreate_ETL_AccountType_Translate @SourceID = 107, @Debug = true --E9 Financials Linked
--EXEC spCreate_ETL_AccountType_Translate @SourceID = 307, @Debug = true --iScala Financials
--EXEC spCreate_ETL_AccountType_Translate @SourceID = 907, @Debug = true --Axapta Financials
--EXEC spCreate_ETL_AccountType_Translate @SourceID = 1227, @Debug = true --ENT Financials
--EXEC spCreate_ETL_AccountType_Translate @SourceID = -1055, @Debug = true --E10 cloud demo

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SQLSourceStatement nvarchar(max),
	@Action nvarchar(10),
	@InstanceID int,
	@SourceType nvarchar(50),
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(50),
	@SourceID_varchar nvarchar(10),
	@ViewName nvarchar(50),
	@EntityCode nvarchar(50),
	@TableName nvarchar(255),
	@FiscalYear int,
	@Union nvarchar(50),
	@ProcedureName nvarchar(100),
	@SourceTypeFamilyID int,
	@SourceTypeID int,
	@StartYear int,
	@Owner nvarchar(50),
	@SourceDBTypeID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2068' SET @Description = 'SET ANSI_WARNINGS OFF.'
		IF @Version = '1.3.2070' SET @Description = 'SET ANSI_WARNINGS ON if needed.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption. Updated logic for iScala.'
		IF @Version = '1.3.2101' SET @Description = 'Enhanced handling of ANSI_WARNINGS.'
		IF @Version = '1.3.2104' SET @Description = 'Added Axapta.'
		IF @Version = '1.3.2106' SET @Description = 'Test on SelectYN when catching variables.'
		IF @Version = '1.3.2107' SET @Description = 'Test on SourceTypeID.'
		IF @Version = '1.4.0.2135' SET @Description = 'Added statistical accounts for Epicor ERP.'
		IF @Version = '1.4.0.2137' SET @Description = 'Check Entity prio-order for Epicor ERP.'
		IF @Version = '1.4.0.2138' SET @Description = 'Fix collation problem for Epicor ERP.'
		IF @Version = '1.4.0.2139' SET @Description = 'Fix missing field for Axapta. Brackets around view name.'
		IF @Version = '2.0.1.2143' SET @Description = 'Changed Intervals for Enterprise.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID IS NULL 
	BEGIN
		PRINT 'Parameter @SourceID must be set'
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

		SET @SourceID_varchar = CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID))

		SELECT
			@InstanceID = A.InstanceID,
			@SourceTypeID = S.SourceTypeID,
			@SourceType = ST.SourceTypeName,
			@SourceDBTypeID = ST.SourceDBTypeID,
			@SourceTypeFamilyID = ST.SourceTypeFamilyID,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@StartYear = S.StartYear,
			@ETLDatabase = A.ETLDatabase
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SelectYN <> 0
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.SelectYN <> 0
		WHERE
			S.SourceID = @SourceID AND
			S.SelectYN <> 0

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		EXEC [spGet_Owner] @SourceTypeID, @Owner OUTPUT

		IF @SourceTypeID = 6 RETURN

	SET @Step = 'Create temp table'
		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

	IF @SourceTypeFamilyID = 1	--IF @SourceType IN ('E9', 'E10', 'AFR')
	  BEGIN
		SET @Step = 'Create View name'

			SET @ViewName = 'vw_' + @SourceID_varchar + '_ETL_AccountType_Translate'

			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ViewName + '''' + ', ' + '''V''' 
			INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
			SELECT @Action = [Action] FROM #Action
			TRUNCATE TABLE #Action


			SET @SQLStatement = '
	SELECT
		[SourceTypeName] = ''''' + @SourceType + ''''',
		[CategoryID] = COA.CategoryID,
		[Description] = MAX(COA.[Description]),
		[AccountType] = CASE WHEN MAX(COA.[Type]) = ''''I'''' AND MAX(COA.[NormalBalance]) = ''''D'''' THEN ''''Expense'''' ELSE 
						CASE WHEN MAX(COA.[Type]) = ''''I'''' AND MAX(COA.[NormalBalance]) = ''''C'''' THEN ''''Income'''' ELSE 
						CASE WHEN MAX(COA.[Type]) = ''''B'''' AND MAX(COA.[NormalBalance]) = ''''D'''' THEN ''''Asset'''' ELSE 
						CASE WHEN MAX(COA.[Type]) = ''''B'''' AND MAX(COA.[NormalBalance]) = ''''C'''' THEN 
							CASE WHEN COA.CategoryID LIKE ''''%EQUIT%'''' OR MAX(COA.[Description]) LIKE ''''%EQUIT%'''' THEN ''''Equity'''' ELSE ''''Liability'''' END ELSE
						NULL END END END END
	FROM
		' + @SourceDatabase + '.[' + @Owner + '].[COAActCat] COA
		INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COA.Company AND GLB.COACode = COA.COACode
		INNER JOIN Entity E ON E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND E.Par01 = COA.Company COLLATE DATABASE_DEFAULT AND E.Par03 = COA.COACode COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
		INNER JOIN (
			SELECT COA.CategoryID, EntityPriority = MIN(ISNULL(EntityPriority, 99999999)) 
			FROM 
				Entity E 
				INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COAActCat] COA ON COA.Company COLLATE DATABASE_DEFAULT = E.Par01 AND COA.COACode COLLATE DATABASE_DEFAULT = E.Par03 
			WHERE
				E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
				E.SelectYN <> 0 
			GROUP BY 
				COA.CategoryID
				) Prio ON Prio.CategoryID = COA.CategoryID AND Prio.EntityPriority = ISNULL(E.EntityPriority, 99999999)
	GROUP BY
		COA.CategoryID

	UNION
	SELECT
		[SourceTypeName] = ''''' + @SourceType + ''''',
		[CategoryID] = ''''ST_'''' + COA.CategoryID,
		[Description] = MAX(COA.[Description]),
		[AccountType] = ''''Income''''
	FROM
		' + @SourceDatabase + '.[' + @Owner + '].[COAActCat] COA
		INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COA.Company AND GLB.COACode = COA.COACode
		INNER JOIN Entity E ON E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND E.Par01 = COA.Company COLLATE DATABASE_DEFAULT AND E.Par03 = COA.COACode COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
		INNER JOIN (SELECT DISTINCT Category FROM ' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV WHERE Statistical <> 0) ST ON ST.Category = COA.CategoryID
	GROUP BY
		COA.CategoryID'

			SET @Step = 'Create View'
				SET @SQLStatement = @Action + ' VIEW [dbo].[' + @ViewName + '] 
	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
	AS ' + @SQLStatement

			IF @Debug <> 0 PRINT @SQLStatement
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
			
			EXEC (@SQLStatement)

			IF @Debug <> 0
			  BEGIN
				--PRINT @SQLStatement
				EXEC ('SELECT * FROM [' + @ETLDatabase + '].[dbo].[' + @ViewName + ']')
			  END

			SET @Step = 'Create Source statement for procedure'

				SET @SQLSourceStatement = '

	SET @Step = ''''Update table AccountType_Translate''''
		UPDATE ATT
		SET
			Description = ISNULL(ATT.Description, V.Description),
			AccountType = ISNULL(ATT.AccountType, V.AccountType)
		FROM
			AccountType_Translate ATT
			INNER JOIN [' + @ViewName + '] V ON ATT.SourceTypeName = V.SourceTypeName AND ATT.CategoryID = V.CategoryID COLLATE DATABASE_DEFAULT 

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = ''''Insert into table AccountType_Translate''''
		INSERT INTO AccountType_Translate
			(
			[SourceTypeName],
			CategoryID,
			Description,
			AccountType
			)
		SELECT
			[SourceTypeName],
			CategoryID,
			Description,
			AccountType
		FROM
			[' + @ViewName + '] V
		WHERE
			NOT EXISTS (SELECT 1 FROM AccountType_Translate ATT WHERE ATT.SourceTypeName = V.SourceTypeName AND ATT.CategoryID = V.CategoryID COLLATE DATABASE_DEFAULT )

		SET @Inserted = @Inserted + @@ROWCOUNT
		
		SET ANSI_WARNINGS OFF'

	  END  --End of Epicor ERP
  
	ELSE IF @SourceTypeFamilyID = 2	--IF @SourceType IN ('iScala')
	  BEGIN
	  		SET @SQLSourceStatement = '  

	SET @Step = ''''Create and fill temp tables''''
		CREATE TABLE #iScalaCursor
			(
			EntityCode nvarchar(50) COLLATE DATABASE_DEFAULT,
			TableName nvarchar(255) COLLATE DATABASE_DEFAULT,
			FiscalYear int,
			SortOrder int
			)
  
		SET @SQLStatement = ''''
			INSERT INTO #iScalaCursor
				(
				EntityCode,
				TableName,
				FiscalYear,
				SortOrder
				)
			SELECT
				wST.EntityCode,
				TableName,
				FiscalYear,
				SortOrder = ISNULL(E.EntityPriority, 99999999)
			FROM
				wrk_SourceTable wST
				INNER JOIN Entity E ON E.SourceID = wST.SourceID AND E.EntityCode = wST.EntityCode AND E.SelectYN <> 0
			WHERE
				wST.SourceID = '''' + CONVERT(nvarchar(10), @SourceID) + '''' AND
				TableCode = ''''''''GL53''''''''''''

		EXEC (@SQLStatement)

		CREATE TABLE #iScalaCategory
			(
			[CategoryID] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[iScala_Type] int
			)

	SET @Step = ''''Loop and fill data into temp table from GL53''''
  		SET @SQLStatement = ''''''''
  	
		DECLARE iScala_AccountType_Translate_Cursor CURSOR FOR

		SELECT EntityCode, TableName, FiscalYear FROM #iScalaCursor ORDER BY SortOrder, FiscalYear DESC

		OPEN iScala_AccountType_Translate_Cursor
		FETCH NEXT FROM iScala_AccountType_Translate_Cursor INTO @EntityCode, @TableName, @FiscalYear

		WHILE @@FETCH_STATUS = 0
		  BEGIN
	  		SET @SQLStatement = ''''INSERT INTO #iScalaCategory
					(
					[CategoryID],
					[Description],
					[iScala_Type]
					)
				SELECT 
					[CategoryID] = SUBSTRING(GL53001, 1, 2),
					[Description] = MAX(SUBSTRING(GL53001, 1, 2)),
					[iScala_Type] = MAX(GL53003)
				FROM
					'''' + @TableName + '''' ST
				WHERE
					NOT EXISTS (SELECT 1 FROM #iScalaCategory iSC WHERE iSC.[CategoryID] = SUBSTRING(ST.GL53001, 1, 2) COLLATE DATABASE_DEFAULT)
				GROUP BY
					SUBSTRING(GL53001, 1, 2)''''

			EXEC (@SQLStatement)'

SET @SQLSourceStatement = @SQLSourceStatement + ' 

			IF @Debug <> 0
				SELECT 
					TableName = @TableName,
					[CategoryID],
					[Description],
					[iScala_Type]
				FROM
					#iScalaCategory
				ORDER BY
					[CategoryID]

			FETCH NEXT FROM iScala_AccountType_Translate_Cursor INTO @EntityCode, @TableName, @FiscalYear
		  END

		CLOSE iScala_AccountType_Translate_Cursor
		DEALLOCATE iScala_AccountType_Translate_Cursor

	SET @Step = ''''Collect information from GL12''''
		TRUNCATE TABLE #iScalaCursor

		SET @SQLStatement = ''''
			INSERT INTO #iScalaCursor
				(
				EntityCode,
				TableName,
				FiscalYear,
				SortOrder
				)
			SELECT
				wST.EntityCode,
				TableName,
				FiscalYear,
				SortOrder = ISNULL(E.EntityPriority, 99999999)
			FROM
				wrk_SourceTable wST
				INNER JOIN Entity E ON E.SourceID = wST.SourceID AND E.EntityCode = wST.EntityCode AND E.SelectYN <> 0
			WHERE
				wST.SourceID = '''' + CONVERT(nvarchar(10), @SourceID) + '''' AND
				TableCode = ''''''''GL12''''''''''''

		EXEC (@SQLStatement)

	SET @Step = ''''Add specific members to temp table''''

		DECLARE iScala_AccountType_Hierarchy_Cursor CURSOR FOR

		SELECT EntityCode, TableName, FiscalYear FROM #iScalaCursor ORDER BY SortOrder, FiscalYear DESC

		OPEN iScala_AccountType_Hierarchy_Cursor
		FETCH NEXT FROM iScala_AccountType_Hierarchy_Cursor INTO @EntityCode, @TableName, @FiscalYear

		WHILE @@FETCH_STATUS = 0
		  BEGIN
	  		SET @SQLStatement = ''''
				INSERT INTO #iScalaCategory
					(
					[CategoryID],
					[Description],
					[iScala_Type]
					)
				SELECT 
					[CategoryID] = ST.GL12001,
					[Description] = MAX(ST.GL12002),
					[iScala_Type] = MAX(ST.GL12004)
				FROM
					'''' + @TableName + '''' ST
				WHERE
					NOT EXISTS (SELECT 1 FROM #iScalaCategory iSC WHERE iSC.[CategoryID] = ST.GL12001 COLLATE DATABASE_DEFAULT)
				GROUP BY
					ST.GL12001''''

			EXEC (@SQLStatement)'

SET @SQLSourceStatement = @SQLSourceStatement + ' 

			IF @Debug <> 0 
				BEGIN
					PRINT @SQLStatement
					SELECT * FROM #iScalaCategory
					SET @SQLStatement = ''''
						SELECT iSC.*
						FROM
							#iScalaCategory iSC
							INNER JOIN '''' + @TableName + '''' ST ON ST.GL12001 COLLATE DATABASE_DEFAULT = iSC.CategoryID''''

					EXEC (@SQLStatement)

				END

			FETCH NEXT FROM iScala_AccountType_Hierarchy_Cursor INTO @EntityCode, @TableName, @FiscalYear
		  END

		CLOSE iScala_AccountType_Hierarchy_Cursor
		DEALLOCATE iScala_AccountType_Hierarchy_Cursor

	SET @Step = ''''Update Description in temp table''''

		DECLARE iScala_AccountType_Description_Cursor CURSOR FOR

		SELECT EntityCode, TableName, FiscalYear FROM #iScalaCursor ORDER BY SortOrder DESC, FiscalYear

		OPEN iScala_AccountType_Description_Cursor
		FETCH NEXT FROM iScala_AccountType_Description_Cursor INTO @EntityCode, @TableName, @FiscalYear

		WHILE @@FETCH_STATUS = 0
		  BEGIN
	  		SET @SQLStatement = ''''
				UPDATE iSC
				SET 
					[Description] = ST.GL12002
				FROM
					#iScalaCategory iSC
					INNER JOIN '''' + @TableName + '''' ST ON ST.GL12001 COLLATE DATABASE_DEFAULT = iSC.CategoryID''''

			EXEC (@SQLStatement)

			IF @Debug <> 0 
				BEGIN
					PRINT @SQLStatement
					SELECT * FROM #iScalaCategory
					SET @SQLStatement = ''''
						SELECT iSC.*
						FROM
							#iScalaCategory iSC
							INNER JOIN '''' + @TableName + '''' ST ON ST.GL12001 COLLATE DATABASE_DEFAULT = iSC.CategoryID''''

					EXEC (@SQLStatement)

				END

			FETCH NEXT FROM iScala_AccountType_Description_Cursor INTO @EntityCode, @TableName, @FiscalYear
		  END

		CLOSE iScala_AccountType_Description_Cursor
		DEALLOCATE iScala_AccountType_Description_Cursor'

SET @SQLSourceStatement = @SQLSourceStatement + ' 

	SET @Step = ''''Insert into table AccountType_Translate from temp table''''
		SET @SQLStatement = ''''
			INSERT INTO AccountType_Translate
				(
				[SourceTypeName],
				CategoryID,
				Description,
				AccountType
				)
			SELECT TOP 10000
				[SourceTypeName] = '''''''''''' + @SourceType + '''''''''''',
				CategoryID = iSC.CategoryID,
				[Description] = MAX(iSC.[Description]),
				AccountType = CASE MAX(iSC.[iScala_Type]) 
								WHEN ''''''''0'''''''' THEN CASE WHEN SUBSTRING(iSC.CategoryID, 1, 1) = ''''''''3'''''''' THEN ''''''''Income'''''''' ELSE ''''''''Expense'''''''' END
								WHEN ''''''''1'''''''' THEN CASE WHEN SUBSTRING(iSC.CategoryID, 1, 1) = ''''''''2'''''''' THEN CASE WHEN SUBSTRING(iSC.CategoryID, 1, 2) IN (''''''''25'''''''', ''''''''26'''''''') THEN ''''''''Liability'''''''' ELSE ''''''''Equity'''''''' END ELSE ''''''''Asset'''''''' END
								WHEN ''''''''2'''''''' THEN ''''''''Expense''''''''
								ELSE  NULL
							END
			FROM
				#iScalaCategory iSC
			WHERE
				NOT EXISTS (SELECT 1 FROM AccountType_Translate AT WHERE AT.[SourceTypeName] = '''''''''''' + @SourceType + '''''''''''' AND AT.CategoryID = iSC.CategoryID COLLATE DATABASE_DEFAULT)
			GROUP BY
				iSC.CategoryID
			ORDER BY
				iSC.CategoryID''''

			EXEC (@SQLStatement)

			SET @Inserted = @Inserted + @@ROWCOUNT'

	  END  --End of iScala

	ELSE IF @SourceTypeFamilyID = 3	--ELSE IF @SourceType IN ('ENT')
	  BEGIN
		SET @SQLSourceStatement = ' 
		
	SET @Step = ''''Create temp tables''''		 
		CREATE TABLE #CursorTable
			(
			EntityCode nvarchar(100),
			SourceDatabase nvarchar(100),
			SortOrder int
			)

		CREATE TABLE #ATT
			(
			CategoryID nvarchar(10),
			[Description] nvarchar(255)
			)

		SET @SQLStatement = ''''
			INSERT INTO #CursorTable
				(
				EntityCode,
				SourceDatabase,
				SortOrder
				)
			SELECT
				EntityCode,
				SourceDatabase = Par01,
				SortOrder = ISNULL(EntityPriority, 99999999) 
			FROM
				Entity 
			WHERE
				SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND
				SelectYN <> 0''''

		EXEC (@SQLStatement)

  		SET @SQLStatement = ''''''''

	SET @Step = ''''CREATE Ent_AccountType_Translate_Cursor''''  	
		DECLARE Ent_AccountType_Translate_Cursor CURSOR FOR

		SELECT EntityCode, SourceDatabase FROM #CursorTable ORDER BY SortOrder

		OPEN Ent_AccountType_Translate_Cursor
		FETCH NEXT FROM Ent_AccountType_Translate_Cursor INTO @EntityCode, @SourceDatabase

		WHILE @@FETCH_STATUS = 0
		  BEGIN
			
	  		SET @SQLStatement = ''''
			INSERT INTO #ATT
				(
				CategoryID,
				[Description]
				)		
			SELECT DISTINCT
				CategoryID = gt.type_code,
				[Description] = gt.type_description
			FROM
				'''' + @SourceDatabase + ''''.[dbo].[glactype] gt
			WHERE
				NOT EXISTS (SELECT 1 FROM #ATT A WHERE A.CategoryID = gt.type_code)''''

			EXEC (@SQLStatement)

			FETCH NEXT FROM Ent_AccountType_Translate_Cursor INTO @EntityCode, @SourceDatabase
		  END

		CLOSE Ent_AccountType_Translate_Cursor
		DEALLOCATE Ent_AccountType_Translate_Cursor

	SET @Step = ''''Update table AccountType_Translate''''
		UPDATE AT
		SET
			[Description] = #ATT.[Description],
			AccountType = CASE 
					WHEN #ATT.CategoryID BETWEEN 100 AND 199 THEN ''''Asset''''
					WHEN #ATT.CategoryID BETWEEN 200 AND 299 THEN ''''Liability''''
					WHEN #ATT.CategoryID BETWEEN 300 AND 399 THEN ''''Equity''''
					WHEN #ATT.CategoryID BETWEEN 400 AND 449 THEN ''''Income''''
					WHEN #ATT.CategoryID BETWEEN 450 AND 599 THEN ''''Expense''''
					ELSE ''''Expense''''
				END
		FROM
			AccountType_Translate AT
			INNER JOIN #ATT ON AT.SourceTypeName = @SourceType AND AT.CategoryID = #ATT.CategoryID COLLATE DATABASE_DEFAULT

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = ''''Insert into table AccountType_Translate''''
		INSERT INTO AccountType_Translate
			(
			[SourceTypeName],
			CategoryID,
			Description,
			AccountType
			)
		SELECT
			[SourceTypeName] = @SourceType,
			CategoryID,
			[Description],
			AccountType = CASE 
					WHEN CategoryID BETWEEN 100 AND 199 THEN ''''Asset''''
					WHEN CategoryID BETWEEN 200 AND 299 THEN ''''Liability''''
					WHEN CategoryID BETWEEN 300 AND 399 THEN ''''Equity''''
					WHEN CategoryID BETWEEN 400 AND 449 THEN ''''Income''''
					WHEN CategoryID BETWEEN 450 AND 599 THEN ''''Expense''''
					ELSE ''''Expense''''
				END
		FROM
			#ATT
		WHERE
			NOT EXISTS (SELECT 1 FROM AccountType_Translate AT WHERE AT.[SourceTypeName] = @SourceType AND AT.CategoryID = #ATT.CategoryID COLLATE DATABASE_DEFAULT)

		SET @Inserted = @Inserted + @@ROWCOUNT'

	  END --End of Enterprise

	ELSE IF @SourceTypeFamilyID = 4	--Axapta
	  BEGIN
		SET @SQLSourceStatement = ' 
		
	SET @Step = ''''Fill temp tables''''		 
		SELECT 
			[Type] = AE.ENUMITEMVALUE,
			[AccountType] = ISNULL(AT.AccountType, AE.ENUMITEMLABEL),
			[Priority] = CASE WHEN AT.AccountType IS NULL THEN 0 ELSE 1 END
		INTO
			#Type
		FROM
			' + @SourceDatabase + '.[dbo].SRSAnalysisEnums AE
			LEFT JOIN AccountType AT ON AT.AccountType = REPLACE(AE.ENUMITEMLABEL, ''''Revenue'''', ''''Income'''') COLLATE DATABASE_DEFAULT
		WHERE
			AE.ENUMNAME = ''''DimensionLedgerAccountType'''' AND AE.LANGUAGEID LIKE ''''en-gb''''

		IF @Debug <> 0 SELECT TempTable = ''''#Type'''', * FROM #Type

		SELECT DISTINCT
			[Account] = MA.[MAINACCOUNTID]
		INTO
			#Account 
		FROM
			' + @SourceDatabase + '.[dbo].MAINACCOUNT MA
			INNER JOIN ' + @SourceDatabase + '.[dbo].[MAINACCOUNTCATEGORY] MAC ON MAC.ACCOUNTCATEGORYREF = MA.ACCOUNTCATEGORYREF AND MAC.[PARTITION] = MA.[PARTITION]
			INNER JOIN ' + @SourceDatabase + '.[dbo].DIMENSIONATTRIBUTEVALUECOMBINATION DAVC ON DAVC.MainAccount = MA.RECID AND DAVC.[PARTITION] = MA.[PARTITION]
			INNER JOIN ' + @SourceDatabase + '.[dbo].GENERALJOURNALACCOUNTENTRY GJAE ON GJAE.LEDGERDIMENSION = DAVC.RECID AND GJAE.[PARTITION] = MA.[PARTITION]
			INNER JOIN ' + @SourceDatabase + '.[dbo].GENERALJOURNALENTRY GJE ON GJE.Recid = GJAE.GENERALJOURNALENTRY AND GJE.[PARTITION] = GJAE.[PARTITION]
			INNER JOIN ' + @ETLDatabase + '.dbo.Entity E ON E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND E.Par01 = CONVERT(nvarchar(20), GJE.LEDGER) AND E.Par02 = CONVERT(nvarchar(20), GJE.[PARTITION]) AND E.SelectYN <> 0
			INNER JOIN ' + @SourceDatabase + '.[dbo].[FISCALCALENDARPERIOD] FCP ON FCP.RECID = GJE.FISCALCALENDARPERIOD AND FCP.[PARTITION] = GJE.[PARTITION] AND YEAR(DATEADD(day, DATEDIFF(day, FCP.STARTDATE, FCP.ENDDATE) / 2, FCP.STARTDATE)) >= ' + CONVERT(nvarchar(10), @StartYear) + '

		IF @Debug <> 0 SELECT TempTable = ''''#Account'''', * FROM #Account

		SELECT 
			[CategoryID] = MAC.[ACCOUNTCATEGORY],
			[Description] = MAX(MAC.[DESCRIPTION]),
			[Type] = T.[Type],
			[AccountType] = T.[AccountType],
			[Priority] = T.[Priority]
		INTO
			#AT
		FROM 
			' + @SourceDatabase + '.[dbo].MAINACCOUNT MA
			INNER JOIN ' + @SourceDatabase + '.[dbo].[MAINACCOUNTCATEGORY] MAC ON MAC.ACCOUNTCATEGORYREF = MA.ACCOUNTCATEGORYREF AND MAC.[PARTITION] = MA.[PARTITION]
			INNER JOIN #Account A ON A.Account = MA.MAINACCOUNTID
			INNER JOIN #Type T ON T.[Type] = MA.[TYPE]
		GROUP BY
			MAC.ACCOUNTCATEGORY,
			T.[Type],
			T.AccountType,
			T.[Priority]

		IF @Debug <> 0 SELECT TempTable = ''''#AT'''', * FROM #AT

		SELECT 
			[CategoryID] = MAC.[ACCOUNTCATEGORY],
			[Priority] = MAX(T.[Priority])
		INTO
			#ATP
		FROM 
			' + @SourceDatabase + '.[dbo].MAINACCOUNT MA
			INNER JOIN ' + @SourceDatabase + '.[dbo].[MAINACCOUNTCATEGORY] MAC ON MAC.ACCOUNTCATEGORYREF = MA.ACCOUNTCATEGORYREF AND MAC.[PARTITION] = MA.[PARTITION]
			INNER JOIN #Account A ON A.Account = MA.MAINACCOUNTID
			INNER JOIN #Type T ON T.[Type] = MA.[TYPE]
		GROUP BY
			MAC.ACCOUNTCATEGORY'

			SET @SQLSourceStatement = @SQLSourceStatement + ' 

		IF @Debug <> 0 SELECT TempTable = ''''#ATP'''', * FROM #ATP

		SELECT
			[SourceTypeName] = @SourceType,
			[CategoryID] = AT.[CategoryID] + ''''_'''' + CONVERT(nvarchar(10), AT.[Type]),
			[Description] = AT.[Description],
			[Hint] = CASE WHEN AT.[Priority] = 0 THEN AT.[AccountType] ELSE NULL END,
			[AccountType] = CASE WHEN AT.[Priority] = 1 THEN AT.[AccountType] ELSE NULL END
		INTO
			#ATT
		FROM
			#AT AT 
			INNER JOIN #ATP ATP ON ATP.CategoryID = AT.CategoryID AND ATP.[Priority] = AT.[Priority]

		IF @Debug <> 0 SELECT TempTable = ''''#ATT'''', * FROM #ATT

	SET @Step = ''''Update table AccountType_Translate''''
		UPDATE ATT
		SET
			[Description] = #ATT.[Description],
			[Hint] = #ATT.[Hint],
			[AccountType] = #ATT.[AccountType]
		FROM
			AccountType_Translate ATT
			INNER JOIN #ATT ON ATT.SourceTypeName = #ATT.SourceTypeName AND ATT.CategoryID = #ATT.CategoryID COLLATE DATABASE_DEFAULT

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = ''''Insert into table AccountType_Translate''''
		INSERT INTO AccountType_Translate
			(
			[SourceTypeName],
			[CategoryID],
			[Description],
			[Hint],
			[AccountType]
			)
		SELECT
			[SourceTypeName] = @SourceType,
			[CategoryID],
			[Description],
			[Hint],
			[AccountType]
		FROM
			#ATT
		WHERE
			NOT EXISTS (SELECT 1 FROM AccountType_Translate ATT WHERE ATT.[SourceTypeName] = #ATT.SourceTypeName AND ATT.CategoryID = #ATT.CategoryID COLLATE DATABASE_DEFAULT)

		SET @Inserted = @Inserted + @@ROWCOUNT
			
	SET @Step = ''''Drop temp tables''''			
		DROP TABLE #Type
		DROP TABLE #Account
		DROP TABLE #AT
		DROP TABLE #ATP
		DROP TABLE #ATT'

	  END --End of Axapta

	SET @Step = 'CREATE PROCEDURE'
		SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_ETL_AccountType_Translate'

		--Determine CREATE or ALTER
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
		SELECT @Action = [Action] FROM #Action
		DROP TABLE #Action

		SET @SQLStatement = '
SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SourceType nvarchar(50),
	@SQLStatement nvarchar(max),
	@EntityCode nvarchar(50),
	@SourceDatabase nvarchar(255),
	@TableName nvarchar(255),
	@FiscalYear int,
	@Union nvarchar(50),
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

		SELECT 
			@SourceType = ST.[SourceTypeName]
		FROM
			pcINTEGRATOR.dbo.Source S
			INNER JOIN pcINTEGRATOR.dbo.SourceType ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			S.SourceID = @SourceID

	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON' + @SQLSourceStatement + '

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
		SET @ProcedureName = '[' + @ProcedureName + ']'
		SET @SQLStatement = @Action + ' PROCEDURE [dbo].' + @ProcedureName + '

	@JobID int = 0,
	@SourceID int = ''''' + CONVERT(nvarchar, @SourceID) + ''''',
	@Rows int = NULL,
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

	AS' + CHAR(13) + CHAR(10) + @SQLStatement

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of Procedure', [SQLStatement] = @SQLStatement

		--IF @Debug <> 0 PRINT @SQLStatement

		EXEC (@SQLStatement)

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
