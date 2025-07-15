SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_ETL_ClosedPeriod] 

	@SourceID int = NULL,
	@JobID int = 0,
	@RecalculateAfterClosing int = 2,
	@RecalculateNumberOfDays int = 100,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_ETL_ClosedPeriod] @SourceID = 307, @Debug = 1 --iScala Financials
--EXEC [spCreate_ETL_ClosedPeriod] @SourceID = 557, @Debug = 1 --E9 Financials Linked
--EXEC [spCreate_ETL_ClosedPeriod] @SourceID = 561, @Debug = 1 --E9 AR Linked
--EXEC [spCreate_ETL_ClosedPeriod] @SourceID = 807, @Debug = 1 --Evry Financials
--EXEC [spCreate_ETL_ClosedPeriod] @SourceID = 907, @Debug = 1 --Axapta Financials
--EXEC [spCreate_ETL_ClosedPeriod] @SourceID = 1104, @Debug = 1 --E10 Sales

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@BaseQuerySQLStatement nvarchar(max) = '',
	@InstanceID int,
	@ETLDatabase nvarchar(100),
	@SourceDatabase nvarchar(100),
	@SourceID_varchar nvarchar(10),
	@ProcedureName nvarchar(100),
	@Action nvarchar(10),
	@SourceTypeBM int,
	@SourceTypeCheck int,
	@StartYear int,
	@FinanceAccountYN bit,
	@SourceTypeFamilyID int,
	@SourceTypeID int,
	@SourceTypeName nvarchar(50),
	@Owner nvarchar(50),
	@Year int,
	@Month int,
	@EndYear int,
	@CalculationMethod int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2061' SET @Description = 'Added handling for FiscalPeriod = 0 regarding E9/E10'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2068' SET @Description = 'SET ANSI_WARNINGS OFF.'
		IF @Version = '1.3.2070' SET @Description = 'SET ANSI_WARNINGS ON if needed.'
		IF @Version = '1.3.2082' SET @Description = 'Test that TimeYear IS NOT NULL.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption. Changed StartDate handling for Epicor ERP'
		IF @Version = '1.3.2093' SET @Description = 'Fixed some Case sensitiv errors'
		IF @Version = '1.3.2101' SET @Description = 'Enhanced handling of ANSI_WARNINGS. Added Axapta.'
		IF @Version = '1.3.2110' SET @Description = 'Added parameters @RecalculateAfterClosing and @RecalculateNumberOfDays.'
		IF @Version = '1.4.0.2134' SET @Description = 'Changed setting of BusinessProcess.'

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

		SELECT
			@InstanceID = A.InstanceID,
			@ETLDatabase = A.ETLDatabase,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@SourceTypeBM = ST.SourceTypeBM,
			@StartYear = S.StartYear,
			@FinanceAccountYN = BM.FinanceAccountYN,
			@SourceTypeName = ST.SourceTypeName,
			@SourceTypeFamilyID = ST.SourceTypeFamilyID,
			@SourceTypeID = S.SourceTypeID
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
			INNER JOIN Source S ON S.SourceID = @SourceID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			M.SelectYN <> 0

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		EXEC [spGet_Owner] @SourceTypeID, @Owner OUTPUT

		SET @SourceID_varchar = CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID))

	SET @Step = 'Set @CalculationMethod'
		IF @SourceTypeFamilyID = 1 AND @FinanceAccountYN <> 0		--Epicor 9/10 Finance
			SET @CalculationMethod = 1
		ELSE IF @SourceTypeFamilyID = 2 AND @FinanceAccountYN <> 0	--iScala Finance
			SET @CalculationMethod = 2
		ELSE IF @SourceTypeFamilyID = 4 AND @FinanceAccountYN <> 0	--Axapta Finance
			SET @CalculationMethod = 3
		ELSE														--All other cases
			SET @CalculationMethod = 0

	IF @Debug <> 0 
		SELECT CalculationMethod =  @CalculationMethod, SourceDatabase = @SourceDatabase, [Owner] = @Owner, ETLDatabase = @ETLDatabase

	IF @CalculationMethod > 0
		SET @BaseQuerySQLStatement = '

	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON'

	SET @Step = 'Create Base Query SQL Statement'
		IF @CalculationMethod = 1 --Epicor 9/10 Finance
		BEGIN
		SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

	SET @Step = ''''Create Temp table''''
		CREATE TABLE #ClosedPeriod
			(
			SourceID int,
			EntityCode nvarchar(50) collate database_default,
			TimeFiscalYear int,
			TimeFiscalPeriod int,
			TimeYear int,
			TimeMonth int,
			BusinessProcess nvarchar(50),
			ClosedPeriod bit
			)

	SET @Step = ''''Insert all fiscal periods converted to calendar months from the FiscalPer table into #ClosedPeriod''''
		INSERT INTO #ClosedPeriod
			(
			SourceID,
			EntityCode,
			TimeFiscalYear,
			TimeFiscalPeriod,
			TimeYear,
			TimeMonth,
			BusinessProcess,
			ClosedPeriod
			)
		SELECT DISTINCT
			SourceID = @SourceID,
			EntityCode = E.EntityCode,
			TimeFiscalYear = fp.FiscalYear,
			TimeFiscalPeriod = fp.FiscalPeriod,
			TimeYear = YEAR(DATEADD(day, DATEDIFF(day, fp.StartDate, fp.EndDate) / 2, fp.StartDate)),
			TimeMonth = ISNULL(FPBP.TimeMonth, MONTH(DATEADD(day, DATEDIFF(day, fp.StartDate, fp.EndDate) / 2, fp.StartDate))),
			BusinessProcess = ISNULL(FPBP.BusinessProcess, @BusinessProcess),
			ClosedPeriod = 0
		FROM   
			' + @SourceDatabase + '.' + @Owner + '.[FiscalPer] fp
			INNER JOIN ' + @ETLDatabase + '.dbo.Entity E ON E.SourceID = @SourceID AND E.Par01 = fp.Company COLLATE DATABASE_DEFAULT AND E.Par09 = fp.FiscalCalendarID COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
			LEFT JOIN ' + @ETLDatabase + '.dbo.FiscalPeriod_BusinessProcess FPBP ON FPBP.TimeFiscalPeriod = fp.FiscalPeriod
		WHERE
			fp.FiscalYear >= @StartYear AND
			(E.EntityCode = @EntityCode OR @EntityCode = ''''-1'''') AND
			NOT EXISTS (SELECT 1 FROM #ClosedPeriod CP WHERE CP.SourceID = @SourceID AND CP.EntityCode = E.EntityCode AND CP.TimeFiscalYear = fp.FiscalYear AND CP.TimeFiscalPeriod = fp.FiscalPeriod)'
		SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

	SET @Step = ''''Update #ClosedPeriod.ClosedPeriod from the GLBookPer table''''
		UPDATE CP
		SET
			ClosedPeriod = bp.ClosedPeriod
		FROM   
			' + @SourceDatabase + '.' + @Owner + '.GLBookPer bp
			INNER JOIN ' + @ETLDatabase + '.dbo.Entity E ON
				E.SourceID = @SourceID AND 
				E.Par01 = bp.Company COLLATE DATABASE_DEFAULT AND 
				E.Par02 = bp.BookID COLLATE DATABASE_DEFAULT AND 
				E.Par09 = bp.FiscalCalendarID COLLATE DATABASE_DEFAULT AND
				E.SelectYN <> 0
			INNER JOIN #ClosedPeriod CP ON 
				CP.SourceID = @SourceID AND 
				CP.EntityCode = E.EntityCode AND 
				CP.TimeFiscalYear = bp.FiscalYear AND 
				CP.TimeFiscalPeriod = bp.FiscalPeriod
		WHERE
			bp.FiscalYear >= @StartYear AND
			(E.EntityCode = @EntityCode OR @EntityCode = ''''-1'''')'
		SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

	SET @Step = ''''Insert missing rows from the GLBookPer table into #ClosedPeriod''''
		INSERT INTO #ClosedPeriod
			(
			SourceID,
			EntityCode,
			TimeFiscalYear,
			TimeFiscalPeriod,
			TimeYear,
			TimeMonth,
			BusinessProcess,
			ClosedPeriod
			)
		SELECT DISTINCT
			SourceID = @SourceID,
			EntityCode = E.EntityCode,
			TimeFiscalYear = bp.FiscalYear,
			TimeFiscalPeriod = bp.FiscalPeriod,
			TimeYear = YEAR(DATEADD(day, DATEDIFF(day, bp.StartDate, bp.EndDate) / 2, bp.StartDate)),
			TimeMonth = ISNULL(FPBP.TimeMonth, MONTH(DATEADD(day, DATEDIFF(day, bp.StartDate, bp.EndDate) / 2, bp.StartDate))),
			BusinessProcess = ISNULL(FPBP.BusinessProcess, @BusinessProcess),
			ClosedPeriod = bp.ClosedPeriod
		FROM   
			' + @SourceDatabase + '.' + @Owner + '.GLBookPer bp
			INNER JOIN ' + @ETLDatabase + '.dbo.Entity E ON E.SourceID = @SourceID AND E.Par01 = bp.Company COLLATE DATABASE_DEFAULT AND E.Par02 = bp.BookID COLLATE DATABASE_DEFAULT AND E.Par09 = bp.FiscalCalendarID COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
			LEFT JOIN ' + @ETLDatabase + '.dbo.FiscalPeriod_BusinessProcess FPBP ON FPBP.TimeFiscalPeriod = bp.FiscalPeriod
		WHERE
			bp.FiscalYear >= @StartYear AND
			(E.EntityCode = @EntityCode OR @EntityCode = ''''-1'''') AND
			NOT EXISTS (SELECT 1 FROM #ClosedPeriod CP WHERE CP.SourceID = @SourceID AND CP.EntityCode = E.EntityCode AND CP.TimeFiscalYear = bp.FiscalYear AND CP.TimeFiscalPeriod = bp.FiscalPeriod)'
		SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '
			
	SET @Step = ''''Insert missing rows from the GLPeriodBal table into #ClosedPeriod''''
		INSERT INTO #ClosedPeriod
			(
			SourceID,
			EntityCode,
			TimeFiscalYear,
			TimeFiscalPeriod,
			TimeYear,
			TimeMonth,
			BusinessProcess,
			ClosedPeriod
			)
		SELECT DISTINCT
			SourceID = @SourceID,
			EntityCode = E.EntityCode,
			TimeFiscalYear = fp.FiscalYear,
			TimeFiscalPeriod = fp.FiscalPeriod,
			TimeYear = CASE WHEN FPBP.TimeMonth = 1 THEN fp.FiscalYear ELSE fp.FiscalYear - 1 END,
			TimeMonth = FPBP.TimeMonth,
			BusinessProcess = ISNULL(FPBP.BusinessProcess, @BusinessProcess),
			ClosedPeriod = 0
		FROM   
			' + @SourceDatabase + '.' + @Owner + '.[GLPeriodBal] fp
			INNER JOIN ' + @ETLDatabase + '.dbo.Entity E ON E.SourceID = @SourceID AND E.Par01 = fp.Company COLLATE DATABASE_DEFAULT AND E.Par09 = fp.FiscalCalendarID COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
			INNER JOIN ' + @ETLDatabase + '.dbo.FiscalPeriod_BusinessProcess FPBP ON FPBP.TimeFiscalPeriod = fp.FiscalPeriod AND FPBP.BusinessProcess = ''''FP0''''
		WHERE
			fp.FiscalYear >= @StartYear AND
			(E.EntityCode = @EntityCode OR @EntityCode = ''''-1'''') AND
			NOT EXISTS (SELECT 1 FROM #ClosedPeriod CP WHERE CP.SourceID = @SourceID AND CP.EntityCode = E.EntityCode AND CP.TimeFiscalYear = fp.FiscalYear AND CP.TimeFiscalPeriod = fp.FiscalPeriod)
		
		SET ANSI_WARNINGS OFF'

			END
		ELSE IF @CalculationMethod = 2 --iScala Finance
		  BEGIN
			SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

	SET @Step = ''''Create Temp table''''
		CREATE TABLE [#FirstOpen]
			(
			SourceID int,
			EntityCode nvarchar(50) collate database_default,
			TimeYear int,
			FirstOpen datetime
			)

	SET @Step = ''''Create FirstOpen cursor''''
		DECLARE FirstOpen_Cursor CURSOR FOR

		SELECT 
			EntityCode = iST.EntityCode,
			[TableName] = iST.[TableName],
			TimeYear = iST.FiscalYear 
		FROM
			[wrk_SourceTable] iST
		WHERE
			iST.SourceID = @SourceID AND
			iST.TableCode = ''''GL10'''' AND
			(iST.[EntityCode] = @EntityCode OR @EntityCode = ''''-1'''')
		ORDER BY
			iST.EntityCode,
			iST.FiscalYear 

			OPEN FirstOpen_Cursor
			FETCH NEXT FROM FirstOpen_Cursor INTO @EntityCode, @TableName, @TimeYear

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT SourceID = @SourceID, EntityCode = @EntityCode, TableName = @TableName, TimeYear = @TimeYear
						BEGIN
							SET @Step = ''''Insert into temp table''''

								SET @SQLStatement = ''''
									SELECT
										SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''',
										EntityCode = SUBSTRING(GL10001, 1, 2),
										TimeYear = (YEAR(GL10008) / 100) * 100 + CONVERT(int, SUBSTRING(GL10001, 3, 2)),
										FirstOpen = CASE GL10003 
													WHEN  1 THEN GL10008
													WHEN  2 THEN GL10010
													WHEN  3 THEN GL10012
													WHEN  4 THEN GL10014
													WHEN  5 THEN GL10016
													WHEN  6 THEN GL10018
													WHEN  7 THEN GL10020
													WHEN  8 THEN GL10022
													WHEN  9 THEN GL10024
													WHEN 10 THEN GL10026
													WHEN 11 THEN GL10028
													WHEN 12 THEN GL10030
													WHEN 13 THEN GL10032
													WHEN 14 THEN GL10034
													WHEN 15 THEN GL10036
													WHEN 16 THEN GL10038
													WHEN 17 THEN GL10040
													WHEN 18 THEN GL10042
													WHEN 19 THEN GL10045
													WHEN 20 THEN GL10047
													WHEN 21 THEN GL10049
													WHEN 22 THEN GL10051
													WHEN 23 THEN GL10053
													WHEN 24 THEN GL10055
													ELSE DATEADD(day, 1, GL10004)
												END
									FROM
										'''' + @TableName + '''' ST
									WHERE
										SUBSTRING(GL10001, 1, 2) = '''''''''''' + @EntityCode + '''''''''''' AND
										(YEAR(GL10008) / 100) * 100 + CONVERT(int, SUBSTRING(GL10001, 3, 2)) = '''' + CONVERT(nvarchar, @TimeYear)'
SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

								IF @Debug <> 0 PRINT @SQLStatement

								INSERT INTO [#FirstOpen] (SourceID, EntityCode, TimeYear, FirstOpen) EXEC (@SQLStatement)
						END
					
					FETCH NEXT FROM FirstOpen_Cursor INTO @EntityCode, @TableName, @TimeYear
				END

		CLOSE FirstOpen_Cursor
		DEALLOCATE FirstOpen_Cursor

	SET @Step = ''''Insert into #ClosedPeriod''''
		SELECT TOP 1000000
			SourceID = FO.SourceID,
			EntityCode = FO.EntityCode,
			TimeFiscalYear = FO.TimeYear,
			TimeFiscalPeriod = TM.TimeMonth,
			TimeYear = FO.TimeYear,
			TimeMonth = ISNULL(FPBP.TimeMonth, TM.TimeMonth),
			BusinessProcess = ISNULL(FPBP.BusinessProcess, @BusinessProcess),
			ClosedPeriod = CASE WHEN CONVERT(datetime, CONVERT(nvarchar, FO.TimeYear) + ''''-'''' + CASE WHEN LEN(CONVERT(nvarchar, TM.TimeMonth)) = 1 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, TM.TimeMonth) + ''''-01'''') < FO.FirstOpen THEN 1 ELSE 0 END
		INTO
			#ClosedPeriod
		FROM
			[#FirstOpen] FO
			INNER JOIN (
			SELECT
				TimeMonth = D2.Number * 10 + D1.Number + 1
			FROM
				Digit D1,
				Digit D2
			WHERE
				D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
			) TM ON 1 = 1
			LEFT JOIN ' + @ETLDatabase + '.dbo.FiscalPeriod_BusinessProcess FPBP ON FPBP.TimeFiscalPeriod = TM.TimeMonth
		ORDER BY
			FO.SourceID,
			FO.EntityCode,
			FO.TimeYear,
			TM.TimeMonth'
SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '
			
		INSERT INTO #ClosedPeriod
			(
			SourceID,
			EntityCode,
			TimeFiscalYear, 
			TimeFiscalPeriod,
			TimeYear,
			TimeMonth,
			BusinessProcess,
			ClosedPeriod
			)
		SELECT
			CP.SourceID,
			CP.EntityCode,
			CP.TimeFiscalYear, 
			FPBP.TimeFiscalPeriod,
			TimeYear = CASE WHEN A.FiscalYearStartMonth = 1 THEN CP.TimeFiscalYear ELSE CP.TimeFiscalYear - 1 END,
			FPBP.TimeMonth,
			FPBP.BusinessProcess,
			ClosedPeriod = CPFP.ClosedPeriod
		FROM
			' + @ETLDatabase + '.dbo.FiscalPeriod_BusinessProcess FPBP
			INNER JOIN (SELECT DISTINCT Period FROM ' + @ETLDatabase + '.dbo.TransactionType_iScala WHERE ISNUMERIC(Period) <> 0) TT ON TT.Period = FPBP.TimeFiscalPeriod
			INNER JOIN (SELECT DISTINCT SourceID, EntityCode, TimeFiscalYear FROM #ClosedPeriod) CP ON 1 = 1
			INNER JOIN (SELECT FiscalYearStartMonth FROM pcINTEGRATOR..[Application] A 
						INNER JOIN pcINTEGRATOR..Model M ON M.ApplicationID = A.ApplicationID
						INNER JOIN pcINTEGRATOR..[Source] S ON S.ModelID = M.ModelID AND S.SourceID = @SourceID) A ON 1 = 1
			INNER JOIN (SELECT DISTINCT
						CP.SourceID,
						CP.EntityCode,
						CP.TimeFiscalYear,
						CP.TimeFiscalPeriod,
						CP.ClosedPeriod
					FROM
						#ClosedPeriod CP 
						INNER JOIN (SELECT FPBP.TimeFiscalPeriod FROM ' + @ETLDatabase + '.dbo.FiscalPeriod_BusinessProcess FPBP INNER JOIN (SELECT DISTINCT Period FROM ' + @ETLDatabase + '.dbo.TransactionType_iScala WHERE ISNUMERIC(Period) <> 0) TT 
									ON TT.Period = FPBP.TimeFiscalPeriod) FPC ON FPC.TimeFiscalPeriod + 1 = CP.TimeFiscalPeriod) CPFP ON CPFP.SourceID = CP.SourceID AND CPFP.EntityCode = CP.EntityCode AND CPFP.TimeFiscalYear = CP.TimeFiscalYear
		WHERE
			NOT EXISTS (SELECT 1 FROM #ClosedPeriod D WHERE D.SourceID = CP.SourceID AND D.EntityCode = CP.EntityCode AND D.TimeFiscalYear = CP.TimeFiscalYear AND D.TimeFiscalPeriod = FPBP.TimeFiscalPeriod)'

		  END

		ELSE IF @CalculationMethod = 3 --Axapta Finance
		  BEGIN
			SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

	SET @Step = ''''Insert into #ClosedPeriod''''
		SELECT
			SourceID = E.SourceID,
			EntityCode = E.EntityCode,
			TimeFiscalYear = FCY.NAME,
			TimeFiscalPeriod = LTRIM(RIGHT(RTRIM(FCP.NAME), 2)),
			TimeYear = YEAR(DATEADD(day, DATEDIFF(day, FCP.STARTDATE, FCP.ENDDATE) / 2, FCP.STARTDATE)),
			TimeMonth = MONTH(DATEADD(day, DATEDIFF(day, FCP.STARTDATE, FCP.ENDDATE) / 2, FCP.STARTDATE)),
			BusinessProcess = ISNULL(FPBP.BusinessProcess, @BusinessProcess),
			ClosedPeriod = CASE WHEN LFCP.[STATUS] = 2 THEN 1 ELSE 0 END
		INTO
			#ClosedPeriod
		FROM
			' + @ETLDatabase + '.dbo.Entity E
			INNER JOIN ' + @SourceDatabase + '.[dbo].[FISCALCALENDARPERIOD] FCP ON CONVERT(nvarchar(20), FCP.[PARTITION]) = E.Par02 AND CONVERT(nvarchar(20), FCP.FISCALCALENDAR) = E.Par09
			INNER JOIN ' + @SourceDatabase + '.[dbo].[FISCALCALENDARYEAR] FCY ON FCY.FISCALCALENDAR = FCP.FISCALCALENDAR AND FCY.[PARTITION] = FCP.[PARTITION] AND FCY.RECID = FCP.FISCALCALENDARYEAR
			LEFT JOIN ' + @SourceDatabase + '.[dbo].[LEDGERFISCALCALENDARPERIOD] LFCP ON LFCP.FISCALCALENDARPERIOD = FCP.RECID AND LFCP.[LEDGER] = E.Par01 AND LFCP.[PARTITION] = FCP.[PARTITION]
			LEFT JOIN ' + @ETLDatabase + '.dbo.FiscalPeriod_BusinessProcess FPBP ON FPBP.TimeFiscalPeriod = LTRIM(RIGHT(RTRIM(FCP.NAME), 2))
		WHERE
			E.SourceID = @SourceID AND 
			E.SelectYN <> 0'

		  END

		ELSE IF @CalculationMethod = 0 --All other cases
		  BEGIN
			SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '

	SET @Step = ''''Insert into #ClosedPeriod''''
		SELECT TOP 1000000
			SourceID = E.SourceID,
			EntityCode = E.EntityCode,
			TimeFiscalYear = Y.TimeYear,
			TimeFiscalPeriod = TM.TimeMonth,
			TimeYear = Y.TimeYear,
			TimeMonth = ISNULL(FPBP.TimeMonth, TM.TimeMonth),
			BusinessProcess = ISNULL(FPBP.BusinessProcess, @BusinessProcess),
			ClosedPeriod = CASE WHEN GetDate() - CONVERT(datetime, CONVERT(nvarchar, Y.TimeYear) + ''''-'''' + CASE WHEN LEN(CONVERT(nvarchar, TM.TimeMonth)) = 1 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, TM.TimeMonth) + ''''-01'''') > @RecalculateNumberOfDays THEN 1 ELSE 0 END
		INTO
			#ClosedPeriod
		FROM
			Entity E
			INNER JOIN
				(
				SELECT
					[TimeYear] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2,
					Digit D3,
					Digit D4
				WHERE
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear AND YEAR(GetDate())
				) Y ON 1 = 1
			INNER JOIN
				(
				SELECT
					TimeMonth = D2.Number * 10 + D1.Number + 1
				FROM
					Digit D1,
					Digit D2
				WHERE
					D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
				) TM ON 1 = 1
			LEFT JOIN ' + @ETLDatabase + '.dbo.FiscalPeriod_BusinessProcess FPBP ON FPBP.TimeFiscalPeriod = TM.TimeMonth
		WHERE
			E.SourceID = @SourceID AND 
			E.SelectYN <> 0 AND
			(E.EntityCode = @EntityCode OR @EntityCode = ''''-1'''')
		ORDER BY
			E.SourceID,
			E.EntityCode,
			Y.TimeYear,
			TM.TimeMonth'

		END

	IF @Debug <> 0 PRINT @BaseQuerySQLStatement 
-------------
--	RETURN 0
-------------
	SET @Step = 'CREATE PROCEDURE'

	SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_ETL_ClosedPeriod'

	SET @Step = 'Determine CREATE or ALTER'
	CREATE TABLE #Action
		(
		[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
		)

	SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
	INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
	SELECT @Action = [Action] FROM #Action
	DROP TABLE #Action

IF @Debug <> 0 SELECT [Action] = @Action

	SET @Step = 'Create SQLStatement'

SET @SQLStatement = '
SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int' + CASE WHEN @CalculationMethod = 2 THEN ',
	@SQLStatement nvarchar(max),
	@TableName nvarchar(100),
	@TimeYear int' ELSE '' END + ',
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
			@Updated = ISNULL(@Updated, 0)'

SET @SQLStatement = @SQLStatement + @BaseQuerySQLStatement + '

	SET @Step = ''''Insert into ClosedPeriod''''
		INSERT INTO ClosedPeriod
			(
			SourceID,
			EntityCode,
			TimeFiscalYear,
			TimeFiscalPeriod,
			TimeYear,
			TimeMonth,
			BusinessProcess,
			ClosedPeriod
			)
		SELECT
			SourceID,
			EntityCode,
			TimeFiscalYear,
			TimeFiscalPeriod,
			TimeYear,
			TimeMonth,
			BusinessProcess,
			ClosedPeriod
		FROM
			#ClosedPeriod V
		WHERE
			V.TimeYear IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM ClosedPeriod CP
						WHERE CP.SourceID = V.SourceID AND CP.EntityCode = V.EntityCode AND
						CP.TimeFiscalYear = V.TimeFiscalYear AND CP.TimeFiscalPeriod = V.TimeFiscalPeriod)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @Rows IS NULL
			BEGIN
				UPDATE CP
				SET
					ClosedPeriod = V.ClosedPeriod,
					ClosedPeriod_Counter = CASE WHEN V.ClosedPeriod = 0 THEN 0 ELSE CP.ClosedPeriod_Counter + 1 END,
					Updated = GETDATE(),
					UpdatedBy = SUSER_NAME()
				FROM
					ClosedPeriod CP
					INNER JOIN #ClosedPeriod V ON	CP.SourceID = V.SourceID AND CP.EntityCode = V.EntityCode AND
													CP.TimeFiscalYear = V.TimeFiscalYear AND CP.TimeFiscalPeriod = V.TimeFiscalPeriod
				WHERE
					CP.SourceID = @SourceID
                      
				SET @Updated = @Updated + @@ROWCOUNT
				'
	SET @SQLStatement = @SQLStatement + '
				UPDATE CP
				SET
   					UpdateYN = CASE WHEN ClosedPeriod = 0 OR ClosedPeriod_Counter <= @RecalculateAfterClosing THEN 1 ELSE 0 END,
					Updated = GETDATE(),
					UpdatedBy = SUSER_NAME()
				FROM
					ClosedPeriod CP
				WHERE
					CP.SourceID = @SourceID
	
				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = ''''Drop the temp table''''
		DROP TABLE [#ClosedPeriod]

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
	
SET @ProcedureName = '[' + @ProcedureName + ']'

--Make Creation statement  
SET @SQLStatement = @Action + ' PROCEDURE [dbo].' + @ProcedureName + '

@JobID int = 0,
@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
@BusinessProcess nvarchar(50) = ''''' + @SourceTypeName + '_' + CONVERT(nvarchar, @SourceID) + ''''', --SourceTypeName + SourceID
@EntityCode nvarchar(50) = ''''-1'''', -- -1 = All Entities
@StartYear int = ' + CONVERT(nvarchar(10), @StartYear) + ',
@RecalculateAfterClosing int = ' + CONVERT(nvarchar(10), @RecalculateAfterClosing) + ', --Number of recalculations after a period is closed' + 
CASE WHEN @CalculationMethod = 0 THEN CHAR(13) + CHAR(10) + '@RecalculateNumberOfDays int = ' + CONVERT(nvarchar(10), @RecalculateNumberOfDays) + ', --Number of days passing before a period is closed' ELSE '' END + '
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

IF @Debug <> 0 PRINT @SQLStatement

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
