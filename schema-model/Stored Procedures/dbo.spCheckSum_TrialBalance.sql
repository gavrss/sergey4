SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_TrialBalance] 
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBM int = 7,	--1 - GLPeriodBal VS GLJrnDtl; 2 - GLJrnDtl VS Journal; 4 - Journal VS FACT_Financials;
	@Entity_MemberKey nvarchar(50) = NULL,
	@Entity_Book nvarchar(50) = NULL, 
	@FiscalYear int = NULL, --Default: go back 3 months
	@FiscalPeriod int = NULL,--Default: go back 3 months
	@Account nvarchar(50) = NULL,
	@ShowAllYN bit = 0,
	@ResultTypeBM int = 1, --1=generate new CheckSumStatus count, 2=get CheckSumStatus count, 4=Details (of @CheckSumStatusBM) 
	@CheckSumValue int = NULL OUT,
	@CheckSumStatus10 int = NULL OUT,
	@CheckSumStatus20 int = NULL OUT,
	@CheckSumStatus30 int = NULL OUT,
	@CheckSumStatus40 int = NULL OUT,
	@CheckSumStatusBM int = 7, -- 1=Open, 2=Investigating, 4=Ignored, 8=Solved

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000818,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spCheckSum_TrialBalance',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spCheckSum_TrialBalance] @UserID=-10, @InstanceID=531, @VersionID=1057, @DebugBM=3,@SequenceBM=7,@ShowAllYN=1
,@ResultTypeBM=7,@Entity_MemberKey='PCXNW',@Entity_Book='MAIN',@FiscalYear=2021,@FiscalPeriod=1
,@Account='40000'

EXEC [spCheckSum_TrialBalance] @UserID=-10, @InstanceID=509, @VersionID=1045, @DebugBM=3
,@ResultTypeBM=7,@ShowAllYN=0
,@FiscalYear=2021

EXEC [spCheckSum_TrialBalance] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF


DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@EntityID int,
	@Entity nvarchar(50),
	@Book nvarchar(50),
	@SourceDatabase nvarchar(255),
	@BalanceType nvarchar(10),
	@StartFiscalYear int,
	@FiscalPeriodDimExistsYN bit = 0,
	@ReturnVariable int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Compare differences between source tables Journal, FACT_Financials_View, GLJrnDtl and GLPeriodBal',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2179' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ETLDatabase = ETLDatabase,
			@CallistoDatabase = DestinationDatabase
		FROM
			[pcINTEGRATOR].[dbo].[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

	SET @Step = 'Check if FiscalPeriod dimension exists in Financials'
		IF @SequenceBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT @internalVariable = COUNT(1)
					FROM
						' + @CallistoDatabase + '.[sys].[tables] T
						INNER JOIN ' + @CallistoDatabase + '.[sys].[columns] C ON c.object_id = T.object_id AND C.[name] = ''FiscalPeriod_MemberId''
					WHERE
						T.[name] = ''FACT_Financials_default_partition''
					OPTION (MAXDOP 1)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @FiscalPeriodDimExistsYN OUT
			END

		IF @DebugBM & 2 > 0 
			SELECT 
				[@SequenceBM] = @SequenceBM,
				[@ETLDatabase] = @ETLDatabase, 
				[@CallistoDatabase] = @CallistoDatabase, 
				[@Entity_MemberKey] = @Entity_MemberKey,
				[@Entity_Book] = @Entity_Book,
				[@FiscalYear] = @FiscalYear,
				[@FiscalPeriod] = @FiscalPeriod,
				[@Account] = @Account,
				[@FiscalPeriodDimExistsYN] = @FiscalPeriodDimExistsYN

	SET @Step = 'Create temp table'
		CREATE TABLE #TrialBalance 
			(
			[Path] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SourceTable] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] int,
			[FiscalPeriod] int,
			[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[CheckSum] float
			)

	SET @Step = 'Create and fill temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)

	SET @Step = 'Create #EB (Entity/Book)'
		SELECT DISTINCT
			[EntityID] = E.[EntityID],
			[Entity] = E.[MemberKey],
			[EntityName] = E.[EntityName],
			[Book] = B.[Book],
			[SourceID] = E.[SourceID],
			[SourceTypeID] = S.[SourceTypeID],
			[SourceDatabase] = S.[SourceDatabase],
			[BalanceType] = B.BalanceType
		INTO
			#EB
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.VersionID AND B.EntityID = E.EntityID AND B.BookTypeBM & 3 > 0 AND B.SelectYN <> 0 AND (B.Book = @Entity_Book OR @Entity_Book IS NULL)
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Source] S ON S.[InstanceID] = E.InstanceID AND S.[VersionID] = E.VersionID AND S.SourceID = E.SourceID AND S.SelectYN <> 0 AND S.SourceTypeID = 11 --ONLY applicable for E10 Source
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.MemberKey = @Entity_MemberKey OR @Entity_MemberKey IS NULL) AND
			E.[SelectYN] <> 0
		OPTION (MAXDOP 1)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#EB', * FROM #EB

	SET @Step = 'EB_Cursor'
		IF CURSOR_STATUS('global','EB_Cursor') >= -1 DEALLOCATE EB_Cursor
		DECLARE EB_Cursor CURSOR FOR
			
			SELECT 
				[EntityID],
				[Entity],
				[Book],
				[SourceDatabase],
				[BalanceType]
			FROM
				#EB				

			OPEN EB_Cursor
			FETCH NEXT FROM EB_Cursor INTO @EntityID, @Entity, @Book, @SourceDatabase, @BalanceType

			WHILE @@FETCH_STATUS = 0
				BEGIN
					TRUNCATE TABLE #FiscalPeriod

					IF @DebugBM & 2 > 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@EntityID] = @EntityID, [@Entity] = @Entity, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@SourceDatabase] = @SourceDatabase, [@BalanceType] = @BalanceType
		
					EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @FiscalYear = @FiscalYear, @JobID = @JobID, @Debug = @DebugSub
		 
					IF @DebugBM & 2 > 0 SELECT [TempTable] = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod

					SET @Step = 'Insert data from ERP source table GLPeriodBal'
						IF @SequenceBM & 1 > 0
							BEGIN		
								SET @SQLStatement = '
									INSERT INTO #TrialBalance
										(
										[Path],
										[SourceTable],
										[Entity],
										[Book],
										[FiscalYear],
										[FiscalPeriod],
										[Account],
										[CheckSum]
										)
									SELECT
										[Path] = ''' + @SourceDatabase + '.erp.GLPeriodBal'',
										[SourceTable] = ''GLPeriodBal'',
										[Entity] = GL.[Company],
										[Book] = GL.[BookID],
										[FiscalYear] = GL.[FiscalYear],
										[FiscalPeriod] = GL.[FiscalPeriod],
										[Account] = GL.[SegValue1],
										[CheckSum] = ROUND(GL.[BalanceAmt], 2)
									FROM
										' + @SourceDatabase + '.[erp].[GLPeriodBal] GL
										INNER JOIN #FiscalPeriod FP ON FP.FiscalYear = GL.FiscalYear AND FP.FiscalPeriod = GL.FiscalPeriod
									WHERE
										GL.Company = ''' + @Entity + ''' AND
										GL.BookID = ''' + @Book + '''' 
										+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'GL.FiscalYear = ' + CONVERT(NVARCHAR(10), @FiscalYear) END
										+ CASE WHEN @FiscalPeriod IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'GL.FiscalPeriod = ' + CONVERT(NVARCHAR(10), @FiscalPeriod) END
										+ CASE WHEN  @Account IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'GL.SegValue1 = ''' + @Account + '''' END
										+ ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'GL.BalanceType = ''' + @BalanceType + '''' + '
									OPTION (MAXDOP 1)'	
										
								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC(@SQLStatement)

								IF @DebugBM & 2 > 0	SELECT [TempTable] = '#TrialBalance_GLPeriodBal', * FROM #TrialBalance WHERE [SourceTable] = 'GLPeriodBal' ORDER BY Entity, Book, Account, FiscalYear, FiscalPeriod, SourceTable

							END

					SET @Step = 'Insert data from ERP source table GLJrnDtl'
						IF @SequenceBM & 3 > 0
							BEGIN
								SET @SQLStatement = '
									INSERT INTO #TrialBalance
										(
										[Path],
										[SourceTable],
										[Entity],
										[Book],
										[FiscalYear],
										[FiscalPeriod],
										[Account],
										[CheckSum]
										)
									SELECT 
										[Path] = ''' + @SourceDatabase + '.erp.GLJrnDtl'',
										[SourceTable] = ''GLJrnDtl'',
										[Entity] = GL.[Company],
										[Book] = GL.[BookID],
										[FiscalYear] = GL.[FiscalYear],
										[FiscalPeriod] = GL.[FiscalPeriod],
										[Account] = GL.[SegValue1],
										[CheckSum] = ROUND(SUM(GL.[BookDebitAmount] - GL.[BookCreditAmount]), 2)
									FROM 
										' + @SourceDatabase + '.erp.GLJrnDtl GL
										INNER JOIN #FiscalPeriod FP ON FP.FiscalYear = GL.FiscalYear AND FP.FiscalPeriod = GL.FiscalPeriod
									WHERE
										GL.Company = ''' + @Entity + ''' AND
										GL.BookID = ''' + @Book + '''' 
										+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'GL.FiscalYear = ' + CONVERT(NVARCHAR(10), @FiscalYear) END
										+ CASE WHEN @FiscalPeriod IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'GL.FiscalPeriod = ' + CONVERT(NVARCHAR(10), @FiscalPeriod) END
										+ CASE WHEN  @Account IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'GL.SegValue1 = ''' + @Account + '''' END + '
									GROUP BY
										GL.[Company],
										GL.[BookID],
										GL.[FiscalYear],
										GL.[FiscalPeriod],
										GL.[SegValue1]
									OPTION (MAXDOP 1)'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC(@SQLStatement)
									
								IF @DebugBM & 2 > 0	SELECT [TempTable] = '#TrialBalance_GLJrnDtl', * FROM #TrialBalance WHERE [SourceTable] = 'GLJrnDtl' ORDER BY Entity, Book, Account, FiscalYear, FiscalPeriod, SourceTable
							END

					SET @Step = 'Insert data from EFP source table Journal'
						IF @SequenceBM & 6 > 0
							BEGIN
								SET @SQLStatement = '
									INSERT INTO #TrialBalance
										(
										[Path],
										[SourceTable],
										[Entity],
										[Book],
										[FiscalYear],
										[FiscalPeriod],
										[Account],
										[CheckSum]
										)
									SELECT
										[Path] = ''' + @@SERVERNAME + '.' + @ETLDatabase + '.dbo.Journal'',
										[SourceTable] = ''Journal'',
										[Entity] = J.[Entity],
										[Book] = J.[Book],
										[FiscalYear] = J.[FiscalYear],
										[FiscalPeriod] = J.[FiscalPeriod],
										[Account] = J.[Account],
										[CheckSum] = ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 2)
									FROM
										' + @ETLDatabase + '.dbo.Journal J
										INNER JOIN #FiscalPeriod FP ON FP.FiscalYear = J.FiscalYear AND FP.FiscalPeriod = J.FiscalPeriod
									WHERE
										J.Entity = ''' + @Entity + ''' AND
										J.Book = ''' + @Book + '''' 
										+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'J.FiscalYear = ' + CONVERT(NVARCHAR(10), @FiscalYear) END
										+ CASE WHEN @FiscalPeriod IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'J.FiscalPeriod = ' + CONVERT(NVARCHAR(10), @FiscalPeriod) END
										+ CASE WHEN  @Account IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'J.Account = ''' + @Account + '''' END + ' AND
										ISNUMERIC(J.Account) <> 0 AND
										J.Scenario = ''ACTUAL'' AND
										J.ConsolidationGroup IS NULL AND
										J.TransactionTypeBM & 3 > 0
									GROUP BY
										J.[Entity],
										J.[Book],
										J.[FiscalYear],
										J.[FiscalPeriod],
										J.[Account]
									OPTION (MAXDOP 1)'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC(@SQLStatement)

								IF @DebugBM & 2 > 0	SELECT [TempTable] = '#TrialBalance_Journal', * FROM #TrialBalance WHERE [SourceTable] = 'Journal' ORDER BY Entity, Book, Account, FiscalYear, FiscalPeriod, SourceTable
								
							END

					SET @Step = 'Insert data from EFP source table FACT_Financials'
						IF @SequenceBM & 4 > 0
							BEGIN
								SET @SQLStatement = '
									INSERT INTO #TrialBalance
										(
										[Path],
										[SourceTable],
										[Entity],
										[Book],
										[FiscalYear],
										[FiscalPeriod],
										[Account],
										[CheckSum]
										)
									SELECT
										[Path] = ''' + @@SERVERNAME + '.' + @CallistoDatabase + '.dbo.FACT_Financials_View'',
										[SourceTable] = ''FACT_Financials_View'',
										[Entity] = V.[Entity],
										[Book] = ''' + @Book + ''',
										[FiscalYear] = FP.FiscalYear,
										[FiscalPeriod] = FP.FiscalPeriod,
										[Account] = V.Account,
										[CheckSum] = ROUND(SUM(V.Financials_Value), 2)
									FROM
										' + @CallistoDatabase + '.dbo.FACT_Financials_View V
										INNER JOIN #FiscalPeriod FP ON CONVERT(nvarchar(15), FP.YearMonth) = V.[Time]'
											+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ' AND FP.FiscalYear = ' + CONVERT(NVARCHAR(10), @FiscalYear) END
											+ CASE WHEN @FiscalPeriod IS NULL THEN '' ELSE ' AND FP.FiscalPeriod = ' + CONVERT(NVARCHAR(10), @FiscalPeriod) END + '
									WHERE
										V.Entity = ''' + @Entity + '''
										' + CASE WHEN @FiscalPeriodDimExistsYN <> 0 AND @FiscalYear IS NOT NULL AND @FiscalPeriod IS NOT NULL
												THEN 'AND V.FiscalPeriod = ''' + CONVERT(nvarchar(15), @FiscalYear * 100 + @FiscalPeriod) + ''''
												ELSE '' END + '
										'+ CASE WHEN  @Account IS NULL THEN '' ELSE 'AND V.Account = ''' + @Account + '''' END + ' AND 
										ISNUMERIC(V.Account) <> 0 AND
										V.Scenario = ''ACTUAL'' AND
										V.Flow <> ''OP_Opening''
									GROUP BY
										V.Entity,
										FP.FiscalYear,
										FP.FiscalPeriod,
										V.Account
									OPTION (MAXDOP 1)'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC(@SQLStatement)

								IF @DebugBM & 2 > 0	SELECT [TempTable] = '#TrialBalance_FACT_Financials_View', * FROM #TrialBalance WHERE [SourceTable] = 'FACT_Financials_View' ORDER BY Entity, Book, Account, FiscalYear, FiscalPeriod, SourceTable
								

									/*
									INSERT INTO #TrialBalance
									(
									[Path],
									[SourceTable],
									[Entity],
									[Book],
									[FiscalYear],
									[FiscalPeriod],
									[Account],
									[CheckSum]
									)
								SELECT
									[Path] = 'DSPPROD02.pcDATA_PCX.dbo.FACT_Financials_View',
									[SourceTable] = 'FACT_Financials_View',
									[Entity] = [Entity],
									[Book] = 'MAIN',
									--[FiscalYear] = T.TimeFiscalYear_MemberID,
									--[FiscalPeriod] = T.TimeFiscalPeriod_MemberID - 100,
									[FiscalYear] = @FiscalYear,
									[FiscalPeriod] = @FiscalPeriod,
									[Account],
								--	*
									[CheckSum] = ROUND(SUM(Financials_Value), 2)
								FROM
									pcDATA_PCX..FACT_Financials_View V
								--	INNER JOIN pcDATA_PCX..S_DS_Time T ON T.[Label] = V.[Time]
								WHERE
									Entity = 'PCXNW' AND
								--	T.TimeFiscalYear_MemberID = @FiscalYear AND
								--	T.TimeFiscalPeriod_MemberID - 100 = @FiscalPeriod AND
								--(V.FiscalPeriod = CONVERT(nvarchar(15), @FiscalYear * 100 + @FiscalPeriod) OR (@FiscalYear IS NULL OR @FiscalPeriod IS NULL)) AND
									V.FiscalPeriod = CONVERT(nvarchar(15), @FiscalYear * 100 + @FiscalPeriod) AND
									[Scenario] = 'ACTUAL' AND
									ISNUMERIC([Account]) <> 0 AND
									Flow <> 'OP_Opening'
								GROUP BY
									[Entity],
									--T.TimeFiscalYear_MemberID,
									--T.TimeFiscalPeriod_MemberID,
									Account
									*/
							END

					FETCH NEXT FROM EB_Cursor INTO  @EntityID, @Entity, @Book, @SourceDatabase, @BalanceType
				END

		CLOSE EB_Cursor
		DEALLOCATE EB_Cursor

		IF @DebugBM & 2 > 0	SELECT [TempTable] = '#TrialBalance', * FROM #TrialBalance ORDER BY Entity, Book, Account, FiscalYear, FiscalPeriod, SourceTable


/*
	SET @Step = 'Calculate @CheckSumValue'
		IF @ResultTypeBM & 3 > 0
			BEGIN
				SELECT
					@CheckSumValue = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 3 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus10 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 1 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus20 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 2 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus30 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 4 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus40 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 8 > 0 THEN 1 ELSE 0 END), 0)
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
					LEFT JOIN pcINTEGRATOR_Log..wrk_CheckSum_FACT_Financials_Balance F ON F.InstanceID = CSRL.InstanceID AND F.VersionID = CSRL.VersionID AND F.CheckSumRowLogID = CSRL.CheckSumRowLogID 
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND
					CSRL.[ProcedureID] = @ProcedureID

				IF @Debug <> 0 
					SELECT 
						[@CheckSumValue] = @CheckSumValue, 
						[@CheckSumStatus10] = @CheckSumStatus10, 
						[@CheckSumStatus20] = @CheckSumStatus20,
						[@CheckSumStatus30] = @CheckSumStatus30,
						[@CheckSumStatus40] = @CheckSumStatus40
			END
*/
	SET @Step = 'Get detailed info'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod],
						[Account] '
						+ CASE WHEN @SequenceBM & 1 > 0 THEN ',[GLPeriodBal]' ELSE '' END 
						+ CASE WHEN @SequenceBM & 3 > 0 THEN ',[GLJrnDtl]' ELSE '' END 
						+ CASE WHEN @SequenceBM & 1 > 0 THEN ',[GLJrnDtl_Diff] = ROUND([GLJrnDtl] - [GLPeriodBal], 2)' ELSE '' END
						+ CASE WHEN @SequenceBM & 6 > 0 THEN ',[Journal]' ELSE '' END
						+ CASE WHEN @SequenceBM & 2 > 0 THEN ',[Journal_Diff] = ROUND([Journal] - [GLJrnDtl], 2)' ELSE '' END
						+ CASE WHEN @SequenceBM & 4 > 0 THEN ',[FACT_Financials_View]' ELSE '' END
						+ CASE WHEN @SequenceBM & 4 > 0 THEN ',[FACT_Financials_View_Diff] = ROUND([FACT_Financials_View] - [Journal], 2)' ELSE '' END + '
						--[GLPeriodBal],
						--[GLJrnDtl],
						--[GLJrnDtl_Diff] = ROUND([GLJrnDtl] - [GLPeriodBal], 2),
						--[Journal],
						--[Journal_Diff] = ROUND([Journal] - [GLJrnDtl], 2),
						--[FACT_Financials_View],
						--[FACT_Financials_View_Diff] = ROUND([FACT_Financials_View] - [Journal], 2)
					FROM
						(
						SELECT
							[Entity],
							[Book],
							[FiscalYear],
							[FiscalPeriod],
							[Account],
							[GLPeriodBal] = SUM(CASE WHEN [SourceTable] = ''GLPeriodBal'' THEN [CheckSum] ELSE 0 END),
							[GLJrnDtl] = SUM(CASE WHEN [SourceTable] = ''GLJrnDtl'' THEN [CheckSum] ELSE 0 END),
							[Journal] = SUM(CASE WHEN [SourceTable] = ''Journal'' THEN [CheckSum] ELSE 0 END),
							[FACT_Financials_View] = SUM(CASE WHEN [SourceTable] = ''FACT_Financials_View'' THEN [CheckSum] ELSE 0 END)
						FROM
							#TrialBalance
						GROUP BY
							[Entity],
							[Book],
							[FiscalYear],
							[FiscalPeriod],
							[Account]
						) sub
					WHERE
						--(
						' + CONVERT(NVARCHAR(15), @ShowAllYN) + ' <> ''0'' '
						+ CASE WHEN @SequenceBM & 1 > 0 THEN 'OR ROUND([GLJrnDtl] - [GLPeriodBal], 2) <> 0' ELSE '' END 
						+ CASE WHEN @SequenceBM & 2 > 0 THEN 'OR ROUND([Journal] - [GLJrnDtl], 2) <> 0' ELSE '' END 
						+ CASE WHEN @SequenceBM & 4 > 0 THEN 'OR ROUND([FACT_Financials_View] - [Journal], 2) <> 0' ELSE '' END + '
						--ROUND([GLJrnDtl] - [GLPeriodBal], 2) <> 0 OR
						--ROUND([Journal] - [GLJrnDtl], 2) <> 0 OR
						--ROUND([FACT_Financials_View] - [Journal], 2) <> 0
						--) OR
						--' + CONVERT(NVARCHAR(15), @ShowAllYN) + ' <> 0
					ORDER BY 
						Entity, Book, Account, FiscalYear, FiscalPeriod
					OPTION (MAXDOP 1)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT

			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #TrialBalance
		DROP TABLE #EB
		DROP TABLE #FiscalPeriod

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		--IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			--EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	--EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
