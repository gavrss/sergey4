SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_TrialBalance_Financials] 
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBM int = 4,	--4 - Journal VS FACT_Financials (Movement);
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
	@ProcedureID int = 880000826,
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

DECLARE @CheckSumValue int,@CheckSumStatus10 int,@CheckSumStatus20 int,@CheckSumStatus30 int,@CheckSumStatus40 int
EXEC [spCheckSum_TrialBalance_Financials] @Debug=1, @UserID = -10, @InstanceID = 531, @VersionID = 1057, @CheckSumValue = @CheckSumValue OUT, @CheckSumStatus10 = @CheckSumStatus10 OUT, @CheckSumStatus20 = @CheckSumStatus20 OUT, @CheckSumStatus30 = @CheckSumStatus30 OUT, @CheckSumStatus40 = @CheckSumStatus40 OUT, @JobID = 34814
SELECT [@CheckSumValue] = @CheckSumValue,[@CheckSumStatus10] = @CheckSumStatus10,[@CheckSumStatus20] = @CheckSumStatus20,[@CheckSumStatus30] = @CheckSumStatus30,[@CheckSumStatus40] = @CheckSumStatus40 

EXEC [spCheckSum_TrialBalance_Financials] @UserID = -10, @InstanceID = 531, @VersionID = 1057, 
@ResultTypeBM = 4, @CheckSumStatusBM = 7, @DebugBM=3

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spCheckSum_TrialBalance_Financials',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spCheckSum_TrialBalance_Financials] @UserID=-10, @InstanceID=531, @VersionID=1057, @DebugBM=3,@SequenceBM=4,@ShowAllYN=0
,@ResultTypeBM=7,@Entity_MemberKey='PCXNW',@Entity_Book='MAIN',@FiscalYear=2021,@FiscalPeriod=1
,@Account='40000'

EXEC [spCheckSum_TrialBalance_Financials] @UserID=-10, @InstanceID=509, @VersionID=1045, @DebugBM=3
,@ResultTypeBM=7,@ShowAllYN=0
,@FiscalYear=2021

EXEC [spCheckSum_TrialBalance_Financials] @GetVersion = 1
*/

SET ANSI_WARNINGS ON


DECLARE
	--SP-specific variables
	@SQLStatement NVARCHAR(MAX),
	@CallistoDatabase NVARCHAR(100),
	@ETLDatabase NVARCHAR(100),
	@EntityID INT,
	@Entity NVARCHAR(50),
	@Book NVARCHAR(50),
	@SourceDatabase NVARCHAR(255),
	@BalanceType NVARCHAR(10),
	@Account_SegValue NVARCHAR(50),
	@StartFiscalYear INT,
	@FiscalPeriodDimExistsYN BIT = 0,
	@ReturnVariable INT,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.1.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Compare Journal data between EFP Journal AND FACT_Financials.',
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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ETLDatabase = A.ETLDatabase,
			@CallistoDatabase = A.DestinationDatabase
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SET @Step = 'Check if FiscalPeriod dimension exists in Financials'
		SET @SQLStatement = '
			SELECT @internalVariable = COUNT(1)
			FROM
				' + @CallistoDatabase + '.[sys].[tables] T
				INNER JOIN ' + @CallistoDatabase + '.[sys].[columns] C ON c.object_id = T.object_id AND C.[name] = ''FiscalPeriod_MemberId''
			WHERE
				T.[name] = ''FACT_Financials_default_partition'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @FiscalPeriodDimExistsYN OUT


		IF @DebugBM & 2 > 0 
			SELECT 
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@Entity_MemberKey] = @Entity_MemberKey,
				[@Entity_Book] = @Entity_Book, 
				[@FiscalYear] = @FiscalYear,
				[@FiscalPeriod] = @FiscalPeriod,
				[@Account] = @Account,
				[@SequenceBM] = @SequenceBM,
				[@ResultTypeBM] = @ResultTypeBM,
				[@CheckSumStatusBM] = @CheckSumStatusBM,
				[@ETLDatabase] = @ETLDatabase, 
				[@CallistoDatabase] = @CallistoDatabase,
				[@FiscalPeriodDimExistsYN] = @FiscalPeriodDimExistsYN
/*
	SET @Step = 'Execute generic TrialBalance checksum SP'
		EXEC [pcINTEGRATOR].[dbo].[spCheckSum_TrialBalance]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@SequenceBM = @SequenceBM,
			@Entity_MemberKey = @Entity_MemberKey,
			@Entity_Book = @Entity_Book,
			@FiscalYear = @FiscalYear,
			@FiscalPeriod = @FiscalPeriod,
			@Account = @Account,
			@ShowAllYN = @ShowAllYN,
			@ResultTypeBM = @ResultTypeBM,
			@CheckSumValue = @CheckSumValue OUT,
			@CheckSumStatus10 = @CheckSumStatus10 OUT,
			@CheckSumStatus20 = @CheckSumStatus20 OUT,
			@CheckSumStatus30 = @CheckSumStatus30 OUT,
			@CheckSumStatus40 = @CheckSumStatus40 OUT,
			@CheckSumStatusBM = @CheckSumStatusBM,
			@JobID = @JobID,
			@JobLogID = @JobLogID,
			@SetJobLogYN = @SetJobLogYN,
			@AuthenticatedUserID = @AuthenticatedUserID,
			@Rows = @Rows,
			@ProcedureID = @ProcedureID,
			--@StartTime = @StartTime,
			--@Duration = @Duration OUT,
			@Deleted = @Deleted OUT,
			@Inserted = @Inserted OUT,
			@Updated = @Updated OUT,
			@Selected = @Selected OUT,
			--@GetVersion = @GetVersion,
			@Debug = @Debug,
			@DebugBM = @DebugBM
*/

	SET @Step = 'Create temp table'
		CREATE TABLE #TrialBalance 
			(
			[Path] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[SourceTable] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Entity] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Book] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] INT,
			[FiscalPeriod] INT,
			[YearMonth] INT,
			[Account] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[CheckSum] FLOAT
			)

	SET @Step = 'Create and fill temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear INT,
			FiscalPeriod INT,
			YearMonth INT
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
			[BalanceType] = B.BalanceType,
			[Account_SegValue] = JS.SourceCode
		INTO
			#EB
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.VersionID AND B.EntityID = E.EntityID AND B.BookTypeBM & 3 > 0 AND B.SelectYN <> 0 AND (B.Book = @Entity_Book OR @Entity_Book IS NULL)
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JS ON JS.[InstanceID] = E.InstanceID AND JS.[VersionID] = E.VersionID AND JS.EntityID = E.EntityID AND JS.SelectYN <> 0 AND JS.DimensionID = -1 --Natural Account
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Source] S ON S.[InstanceID] = E.InstanceID AND S.[VersionID] = E.VersionID AND S.SourceID = E.SourceID AND S.SelectYN <> 0 AND S.SourceTypeID = 11 --ONLY applicable for E10 Source
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.MemberKey = @Entity_MemberKey OR @Entity_MemberKey IS NULL) AND
			E.[SelectYN] <> 0
		OPTION (MAXDOP 1)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#EB', * FROM #EB	

	SET @Step = 'Create and fill temp table #BalanceAccount'
		CREATE TABLE #BalanceAccount
			(
			[Account_MemberKey] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[BalanceYN] BIT
			)

		SET @SQLStatement = '
			INSERT INTO #BalanceAccount
				(
				[Account_MemberKey],
				[BalanceYN]
				)
			SELECT
				[Account_MemberKey] = [Label],
				[BalanceYN] = [TimeBalance]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Account]
			WHERE
				RNodeType = ''L'' AND
				TimeBalance <> 0
			OPTION (MAXDOP 1)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#BalanceAccount', * FROM #BalanceAccount ORDER BY [Account_MemberKey]

	SET @Step = 'Calculate #TrialBalance CheckSumValue'		
		IF CURSOR_STATUS('global','EB_Cursor') >= -1 DEALLOCATE EB_Cursor
		DECLARE EB_Cursor CURSOR FOR
			
			SELECT 
				[EntityID],
				[Entity],
				[Book],
				[SourceDatabase],
				[BalanceType],
				[Account_SegValue]
			FROM
				#EB				

			OPEN EB_Cursor
			FETCH NEXT FROM EB_Cursor INTO @EntityID, @Entity, @Book, @SourceDatabase, @BalanceType, @Account_SegValue

			WHILE @@FETCH_STATUS = 0
				BEGIN
					TRUNCATE TABLE #FiscalPeriod

					IF @DebugBM & 2 > 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@EntityID] = @EntityID, [@Entity] = @Entity, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@SourceDatabase] = @SourceDatabase, [@BalanceType] = @BalanceType, [@Account_SegValue] = @Account_SegValue
		
					EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @FiscalYear = @FiscalYear, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @JobID = @JobID, @Debug = @DebugSub
		 
					IF @DebugBM & 2 > 0 SELECT [TempTable] = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod

					SET @Step = 'Insert data from EFP source table Journal'
						SET @SQLStatement = '
							INSERT INTO #TrialBalance
								(
								[Path],
								[SourceTable],
								[Entity],
								[Book],
								[FiscalYear],
								[FiscalPeriod],
								[YearMonth],
								[Account],
								[CheckSum]
								)
							SELECT
								[Path] = ''' + @@SERVERNAME + '.' + @ETLDatabase + '.dbo.Journal'',
								[SourceTable] = ''Journal_excl_FP0'',
								[Entity] = J.[Entity],
								[Book] = J.[Book],
								[FiscalYear] = J.[FiscalYear],
								[FiscalPeriod] = J.[FiscalPeriod],
								[YearMonth] = J.[YearMonth],
								[Account] = J.[Account],
								[CheckSum] = ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4)
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
								J.TransactionTypeBM & 19 > 0 AND
								J.FiscalPeriod <> 0
							GROUP BY
								J.[Entity],
								J.[Book],
								J.[FiscalYear],
								J.[FiscalPeriod],
								J.[YearMonth],
								J.[Account]
							OPTION (MAXDOP 1)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC(@SQLStatement)

					SET @Step = 'Insert data from EFP source table FACT_Financials'
						SET @SQLStatement = '
							INSERT INTO #TrialBalance
								(
								[Path],
								[SourceTable],
								[Entity],
								[Book],
								[YearMonth],
								[Account],
								[CheckSum]
								)
							SELECT
								[Path] = ''' + @@SERVERNAME + '.' + @CallistoDatabase + '.dbo.FACT_Financials_View'',
								[SourceTable] = ''FACT_Financials_View_excl_OP_Opening'',
								[Entity] = V.[Entity],
								[Book] = ''' + @Book + ''',
								[YearMonth] = V.[Time],
								[Account] = V.Account,
								[CheckSum] = ROUND(SUM(V.Financials_Value), 4)
							FROM
								' + @CallistoDatabase + '.dbo.FACT_Financials_View V 
								INNER JOIN (SELECT DISTINCT YearMonth FROM #FiscalPeriod) FP ON CONVERT(nvarchar(15), FP.YearMonth) = V.[Time]
							WHERE
								V.Entity = ''' + @Entity + '''
								' + CASE WHEN @FiscalPeriodDimExistsYN <> 0 AND @FiscalYear IS NOT NULL AND @FiscalPeriod IS NOT NULL
										THEN 'AND V.FiscalPeriod = ''' + CONVERT(nvarchar(15), @FiscalYear * 100 + @FiscalPeriod) + ''''
										ELSE '' END + '
								'+ CASE WHEN  @Account IS NULL THEN '' ELSE 'AND V.Account = ''' + @Account + '''' END + ' AND 
								ISNUMERIC(V.Account) <> 0 AND
								V.Scenario = ''ACTUAL'' AND
								V.Flow NOT IN (''OP_Opening'', ''OP_Adjust'') AND
								V.BusinessRule <> ''Conversion''
							GROUP BY
								V.Entity,
								V.[Time],
								V.Account
							OPTION (MAXDOP 1)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC(@SQLStatement)

					FETCH NEXT FROM EB_Cursor INTO  @EntityID, @Entity, @Book, @SourceDatabase, @BalanceType, @Account_SegValue
				END

		CLOSE EB_Cursor
		DEALLOCATE EB_Cursor

		IF @DebugBM & 2 > 0	SELECT [TempTable] = '#TrialBalance', * FROM #TrialBalance ORDER BY Entity, Book, Account, FiscalYear, FiscalPeriod, YearMonth,SourceTable

	SET @Step = 'Create temp table #TrialBalance_CheckSum_ByYearMonth'
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[Entity],
			[Book],
			[YearMonth],
			[Account],
			[Journal] = ROUND(SUM(CASE WHEN [SourceTable] = 'Journal_excl_FP0' THEN [CheckSum] ELSE 0 END),4),
			[FACT_Financials_View] = ROUND(SUM(CASE WHEN [SourceTable] = 'FACT_Financials_View_excl_OP_Opening' THEN [CheckSum] ELSE 0 END),4)
		INTO
			#TrialBalance_CheckSum_ByYearMonth
			--#TrialBalance_CheckSum_SeqBM4
		FROM
			#TrialBalance
		WHERE
			[SourceTable] IN ('Journal_excl_FP0', 'FACT_Financials_View_excl_OP_Opening')
		GROUP BY
			[Entity],
			[Book],
			[YearMonth],
			[Account]
		ORDER BY 
			[Entity],
			[Book],
			[Account],
			[YearMonth]

		IF @DebugBM & 2 > 0	SELECT [TempTable] = '#TrialBalance_CheckSum_ByYearMonth', * FROM #TrialBalance_CheckSum_ByYearMonth ORDER BY Entity, Book, Account, YearMonth

	SET @Step = 'Set CheckSumRowLogID'
		IF @ResultTypeBM & 1 > 0
			BEGIN 
				INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
					(
					[InstanceID],
					[VersionID],
					[ProcedureID],
					[CheckSumRowKey]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ProcedureID] = @ProcedureID,
					[CheckSumRowKey] = sub.[Entity] + '_' + sub.[Book] + '_' + CONVERT(NVARCHAR(15), sub.[YearMonth]) + '_' + sub.[Account] + '_FACT_Financials_Diff_' +  CONVERT(NVARCHAR(20), ROUND(sub.[FACT_Financials_View] - sub.[Journal], 4))
				FROM
					#TrialBalance_CheckSum_ByYearMonth sub
				WHERE
					ROUND(sub.[FACT_Financials_View] - sub.[Journal], 4) <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = sub.[Entity] + '_' + sub.[Book] + '_' + CONVERT(NVARCHAR(15), sub.[YearMonth]) + '_' + sub.[Account] + '_FACT_Financials_Diff_' +  CONVERT(NVARCHAR(20), ROUND(sub.[FACT_Financials_View] - sub.[Journal], 4)) AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = @InstanceID AND CSRL.[VersionID] = @VersionID AND CSRL.[CheckSumStatusBM] & 12 = 0)
				ORDER BY 
					sub.Entity, sub.Book, sub.Account, sub.YearMonth

				SET @Inserted = @Inserted + @@ROWCOUNT

				UPDATE CSRL
				SET
					[CheckSumStatusBM] = 8,
					[UserID] = @UserID,
					[Comment] = 'Resolved automatically.',
					[Updated] = GetDate()
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND
					CSRL.[ProcedureID] = @ProcedureID AND
					CSRL.[CheckSumStatusBM] & 8 = 0 AND
					CSRL.[CheckSumRowKey] LIKE '%_FACT_Financials_Diff_%' AND
					NOT EXISTS (SELECT 1 FROM #TrialBalance_CheckSum_ByYearMonth TBC WHERE TBC.InstanceID = CSRL.[InstanceID] AND TBC.VersionID = CSRL.[VersionID] AND TBC.[Entity] + '_' + TBC.[Book] + '_' + CONVERT(NVARCHAR(15), TBC.[YearMonth]) + '_' + TBC.[Account] + '_FACT_Financials_Diff_' +  CONVERT(NVARCHAR(20), ROUND(TBC.[FACT_Financials_View] - TBC.[Journal], 4)) = CSRL.[CheckSumRowKey])

				SET @Updated = @Updated + @@ROWCOUNT

			END --OF @ResultTypeBM & 1 > 0

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
					--INNER JOIN #TrialBalance_CheckSum_ByFiscalPeriod TB ON TB.InstanceID = CSRL.[InstanceID] AND TB.VersionID = CSRL.[VersionID] AND CSRL.[CheckSumRowKey] LIKE '%_FACT_Financials_Diff_%'
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND
					CSRL.[ProcedureID] = @ProcedureID AND
					CSRL.[CheckSumRowKey] LIKE '%_FACT_Financials_Diff_%'

				IF @Debug <> 0 
					SELECT 
						[CheckSumRowKey] = 'FACT_Financials_Diff',
						[@CheckSumValue] = @CheckSumValue, 
						[@CheckSumStatus10] = @CheckSumStatus10, 
						[@CheckSumStatus20] = @CheckSumStatus20,
						[@CheckSumStatus30] = @CheckSumStatus30,
						[@CheckSumStatus40] = @CheckSumStatus40	
						
			END	--OF @ResultTypeBM & 3 > 0

	SET @Step = 'Get detailed info'
		SELECT  
			[ResultTypeBM] = 4,
			[CheckSumRowLogID] = CSRL.[CheckSumRowLogID],
			[FirstOccurrence] = CSRL.[Inserted],
			[CheckSumStatusBM] = CSS.[CheckSumStatusBM],
			[CurrentStatus] = CSS.[CheckSumStatusName],
			[Comment] = CSRL.[Comment],
			[Entity] = TB.Entity,
			[Book] = TB.Book,
			[Account] = TB.Account,
			[YearMonth] = TB.YearMonth,
			[Journal] = TB.Journal,
			[FACT_Financials_View] = TB.FACT_Financials_View,
			[FACT_Financials_View_Diff] = ROUND(TB.[FACT_Financials_View] - TB.[Journal], 4),
			[AuthenticatedUserID] = CSRL.UserID,
			[AuthenticatedUserName] = U.UserNameDisplay,
			[AuthenticatedUserOrganization] = I.InstanceName,
			[Updated] = CSRL.[Updated]
		FROM
			[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL 
			INNER JOIN #TrialBalance_CheckSum_ByYearMonth TB ON TB.InstanceID = CSRL.[InstanceID] AND TB.VersionID = CSRL.[VersionID] AND CSRL.[CheckSumRowKey] = TB.[Entity] + '_' + TB.[Book] + '_' + CONVERT(NVARCHAR(15), TB.[YearMonth]) + '_' + TB.[Account] + '_FACT_Financials_Diff_' +  CONVERT(NVARCHAR(20), ROUND(TB.[FACT_Financials_View] - TB.[Journal], 4))
			INNER JOIN [pcINTEGRATOR].[dbo].CheckSumStatus CSS ON CSS.CheckSumStatusBM = CSRL.CheckSumStatusBM
			LEFT JOIN [pcINTEGRATOR].[dbo].[User] U ON U.UserID = CSRL.UserID
			LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID 
		WHERE
			CSRL.InstanceID = @InstanceID AND
			CSRL.VersionID = @VersionID AND   
			CSRL.ProcedureID = @ProcedureID AND 
			CSRL.CheckSumStatusBM & @CheckSumStatusBM > 0 AND
			CSRL.CheckSumRowKey LIKE '%_FACT_Financials_Diff_%'
		ORDER BY
			CSRL.[Inserted] DESC,
			TB.Entity, 
			TB.Book, 
			TB.Account, 
			TB.YearMonth
		OPTION (MAXDOP 1)
		
		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
		DROP TABLE #TrialBalance
		DROP TABLE #TrialBalance_CheckSum_ByYearMonth
		DROP TABLE #EB
		DROP TABLE #FiscalPeriod
		DROP TABLE #BalanceAccount

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
