SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_InterCompany_Matching_New3]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Currency nvarchar(3) = NULL,
	@Entity nvarchar(50) = NULL,
	@InterCompany nvarchar(50) = NULL,
	@Scenario nvarchar(50) = NULL,
	@RULE_Consolidation nvarchar(50) = NULL,
	--@Rule_ICmatchID int = NULL,
	--@Rule_ICmatchName nvarchar(50) = NULL,
--	@Flow nvarchar(50) = NULL,
	@Time nvarchar(50) = NULL,
	@Account nvarchar(50) = NULL,
--	@FiscalYear int = NULL,
--	@FiscalPeriod int = NULL,

--	@DimensionFilter nvarchar(max) = NULL, --(@MatchingCurrency, @Entity, @Scenario, @Time)
	@YtdYN bit = 1,
	
	@MaxDiff money = 0,
	@ResultTypeBM int = 3, --1 = Filter, 2 = Filter rows, 4 = Transactions from Journal, 8 = Detailed data on Intercompany/Account, 16 = Data on Entity/Rule, 32=Recalculate data
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000550,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_InterCompany_Matching] @Currency='AUD',@Debug='0',@InstanceID='572',@ResultTypeBM='32',@Scenario='ACTUAL',@Time='FY2022',@UserID='9863',@VersionID='1080',@DebugBM=15
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_InterCompany_Matching] @Currency='AUD',@Debug='0',@InstanceID='572',@ResultTypeBM='32',@Scenario='ACTUAL',@Time='202203',@UserID='9868',@VersionID='1080',@DebugBM=15

EXEC [spRun_Procedure_KeyValuePair] @JSON='[
{"TKey":"Account","TValue":"Income_Statement_"},{"TKey":"Entity","TValue":"GGI01"},
{"TKey":"InstanceID","TValue":"527"},{"TKey":"RULE_Consolidation","TValue":"BS AFFIL"},
{"TKey":"Currency","TValue":"CAD"},{"TKey":"UserID","TValue":"8042"},{"TKey":"InterCompany","TValue":"All_"},
{"TKey":"Time","TValue":"All_"},{"TKey":"VersionID","TValue":"1055"},{"TKey":"ResultTypeBM","TValue":"12"},
{"TKey":"Scenario","TValue":"ACTUAL"}]', @ProcedureName='spPortalGet_InterCompany_Matching'

EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=529, @VersionID=1001, @Currency = 'SEK', @Entity = '42', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202002, @DebugBM=3

EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202001, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202002, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202003, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202004, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202005, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202006, @DebugBM=1

EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202007, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202008, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202009, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202010, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202011, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202012, @DebugBM=3

EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202101, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202102, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202103, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202104, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202105, @DebugBM=1
EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=32, @Time=202106, @DebugBM=1

EXEC [spPortalGet_InterCompany_Matching] @UserID=-10, @InstanceID=527, @VersionID=1055, @Currency = 'CAD', @Scenario = 'ACTUAL', @ResultTypeBM=16, @Time=202106, @DebugBM=3

EXEC [spPortalGet_InterCompany_Matching] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@FiscalYear int = 2020,
	@FiscalPeriod int = 1,
	@YearMonth int = 202001,
	@PivotColumn NVARCHAR(MAX) = '',
	@SQLStatement nvarchar(max),
	@TransactionTypeBM int = 3,
	@DataClassID int,
	@CallistoDatabase nvarchar(100),
	@JournalTable nvarchar(100),
	@Book nvarchar(50),
	@JournalFilter nvarchar(4000),
	@Currency_Matching_MemberId bigint,
	@Scenario_MemberId bigint,
	@Operator nvarchar(1),
	@MatchingCurrency nvarchar(3),
	@Rule_ICmatchID int,
	@Rule_ICmatchName nvarchar(50),
	@DimensionFilter nvarchar(4000),
	@SQLFilter nvarchar(max),
	@FiscalYearNaming int,
	@FiscalYearStartMonth int,
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
	@Version nvarchar(50) = '2.1.2.2185'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return data for Intercompany matching.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2152' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2153' SET @Description = 'ResultTypeBM = 8 added.'
		IF @Version = '2.1.0.2158' SET @Description = 'Group by on Currency removed in ResultTypeBM = 24 removed for demo purposes.'
		IF @Version = '2.1.1.2170' SET @Description = 'Based on wrk table.'
		IF @Version = '2.1.1.2171' SET @Description = 'Adjusted FiscalPeriod filter for @ResultTypeBM=32 regarding Balance Accounts. For @ResultTypeBM=8, return 0 instead of NULL for columns [Net_Entity_Functional], [Net_Intercompany_Functional], [Net_Entity_Transaction] and [Net_Intercompany_Transaction]. Added parameter @JobID when calling spBR_BR04.'
		IF @Version = '2.1.1.2173' SET @Description = 'Added parameter @StepReference in call to spGet_FilterTable.'
		IF @Version = '2.1.2.2179' SET @Description = 'Handle empty FxRate table.'
		IF @Version = '2.1.2.2185' SET @Description = 'Handle non-numerical @Time parameter value (ex.FY2022).'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
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

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@DataClassID = DataClassID
		FROM
			pcINTEGRATOR_Data.dbo.DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			ModelBM & 64 > 0 AND
			SelectYN <> 0

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			pcINTEGRATOR_Data.dbo.[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

		SELECT
			@FiscalYearStartMonth = FiscalYearStartMonth,
			@FiscalYearNaming = FiscalYearNaming
		FROM
			pcIntegrator_Data.dbo.Instance
		WHERE
			InstanceID = @InstanceID AND
            SelectYN <> 0

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @JournalTable = @JournalTable OUT, @Debug = @DebugSub

		IF @Scenario ='All_'
			SET @Scenario='ACTUAL'

		IF @Time = 'All_'
			SET @Time = '202001'

		IF ISNUMERIC(@Time) = 0
			BEGIN
				SET @SQLStatement = '
					SELECT @InternalVariable = [TimeFiscalYear_MemberId] 
					FROM ' + @CallistoDatabase + '.dbo.S_DS_Time
					WHERE [Label] = ''' + @Time + ''''
            END
		ELSE
			BEGIN
				SET @SQLStatement = '
					SELECT @InternalVariable = [TimeFiscalYear_MemberId] 
					FROM ' + @CallistoDatabase + '.dbo.S_DS_Time
					WHERE [MemberId] = ' + @Time
            END

		EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ReturnVariable OUT

		SET @FiscalYear = @ReturnVariable
SET @YearMonth = @Time

	SET @Step = 'Create temp table #YearMonth'
		CREATE TABLE #YearMonth
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)
		SET @SQLStatement = '
			INSERT INTO #YearMonth
				(
				FiscalYear,
				FiscalPeriod,
				YearMonth
				) 
			SELECT
				FiscalYear = ' + CONVERT(NVARCHAR(15), @FiscalYear) + ',
				FiscalPeriod = TimeFiscalPeriod_MemberId - 100,
				YearMonth = [MemberId]
			FROM ' + @CallistoDatabase + '.dbo.S_DS_Time
			WHERE 
				TimeFiscalYear_MemberId = ' + CONVERT(NVARCHAR(15), @FiscalYear) + ' AND  
				[Level] = ''Month'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#YearMonth', * FROM #YearMonth ORDER BY YearMonth

		SELECT @FiscalPeriod = MAX(FiscalPeriod) FROM #YearMonth

		IF @DebugBM & 2 > 0 SELECT [@FiscalYearNaming] = @FiscalYearnaming, [@FiscalYearStartMonth] = @FiscalYearStartMonth, [@FiscalYear] = @FiscalYear, [@FiscalPeriod] = @FiscalPeriod, [@YearMonth] = @YearMonth

		--WHILE @FiscalYear * 100 + @FiscalPeriod <= @YearMonth
		--	BEGIN
		--		INSERT INTO #YearMonth
		--			(
		--			FiscalYear,
		--			FiscalPeriod,
		--			YearMonth
		--			)
		--		SELECT
		--			FiscalYear = @FiscalYear,
		--			FiscalPeriod = @FiscalPeriod,
		--			YearMonth = @FiscalYear * 100 + @FiscalPeriod

		--		SET @FiscalPeriod = @FiscalPeriod + 1
		--	END

		--IF @DebugBM & 2 > 0 SELECT TempTable = '#YearMonth', * FROM #YearMonth ORDER BY YearMonth


		--SELECT
		--	@FiscalYear = @Time / 100,
		--	@FiscalPeriod = @Time % 100,
		--	@YearMonth = @Time
/* To be changed to generic */	
		
		--IF @InstanceID = 476
		--	SELECT
		--		@FiscalYear = 2019,
		--		@FiscalPeriod = 12,
		--		@YearMonth = 201912

		--ELSE IF @InstanceID = -1335
		--	SELECT
		--		@FiscalYear = 2020,
		--		@FiscalPeriod = 1,
		--		@YearMonth = 202001

		SET @MatchingCurrency = @Currency

		CREATE TABLE #Currency
			(
			MemberId bigint,
			MemberKey nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = '
			INSERT INTO #Currency
				(
				MemberId,
				MemberKey
				)
			SELECT
				MemberId,
				MemberKey=[Label]
			FROM
				' + @CallistoDatabase + '..S_DS_Currency
			WHERE RNodeType = ''L'''

		EXEC (@SQLStatement)

		--Hardcoded
		SELECT @Scenario_MemberId = 110
		--HardCoded
		
		--SELECT @Scenario_MemberId = MemberId FROM pcDATA_TECA..S_DS_Scenario WHERE [Label] = @Scenario
		
		SELECT @Currency_Matching_MemberId = MemberId FROM #Currency WHERE [MemberKey] = @MatchingCurrency

		SET @Entity = CASE WHEN @Entity = 'All_' THEN NULL ELSE @Entity END
	
		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase, 
				[@JournalTable] = @JournalTable, 
				[@DataClassID] = @DataClassID, 
				[@FiscalYear] = @FiscalYear, 
				[@FiscalPeriod] = @FiscalPeriod, 
				[@YearMonth] = @YearMonth,
				[@Currency_Matching_MemberId] = @Currency_Matching_MemberId,
				[@MatchingCurrency] = @MatchingCurrency,
				[@Scenario] = @Scenario,
				[@Scenario_MemberId] = @Scenario_MemberId

	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				CREATE TABLE #DefaultValue
					(
					[DimensionID] int,
					[DefaultMemberID] int,
					[DefaultMemberKey] nvarchar(100),
					[DefaultMemberDescription] nvarchar(255)
					)

				SET @SQLStatement = '
					INSERT INTO #DefaultValue
						(
						[DimensionID],
						[DefaultMemberID],
						[DefaultMemberKey],
						[DefaultMemberDescription]
						)
					SELECT
						[DimensionID] = -6,
						[DefaultMemberID] = [MemberId],
						[DefaultMemberKey] = [Label],
						[DefaultMemberDescription] = [Description]
					FROM
						' + @CallistoDatabase + '..S_DS_Scenario
					WHERE
						[Label] = ''' + ISNULL(@Scenario, 'ACTUAL') + '''

					UNION SELECT
						[DimensionID] = -7,
						[DefaultMemberID] = T.[MemberId],
						[DefaultMemberKey] = T.[Label],
						[DefaultMemberDescription] = T.[Description]
					FROM
						pcINTEGRATOR_Data..Scenario S
						INNER JOIN ' + @CallistoDatabase + '..S_DS_Time T ON T.[MemberId] = S.[ClosedMonth]
					WHERE
						S.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						S.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
						S.[MemberKey] = ''' + ISNULL(@Scenario, 'ACTUAL') + ''' AND
						S.SelectYN <> 0

					UNION SELECT
						[DimensionID] = -3,
						[DefaultMemberID] = [MemberId],
						[DefaultMemberKey] = [Label],
						[DefaultMemberDescription] = [Description]
					FROM
						' + @CallistoDatabase + '..S_DS_Currency
					WHERE
						[Label] = ''' + CASE @InstanceID WHEN -1335 THEN 'CAD' ELSE 'USD' END + ''''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				EXEC [dbo].[spGet_DataClass_DimensionList] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DataClassID = @DataClassID, @ResultTypeBM = 1, @DimensionList = '-1|-3|-4|-6|-7|-31|-66', @VisibleNoList = '-1|-4|-31|-66', @Debug = @DebugSub

				DROP TABLE #DefaultValue
			END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
--				EXEC [dbo].[spGet_DataClass_DimensionMember] @UserID = @UserID,  @InstanceID = @InstanceID, @VersionID = @VersionID, @DataClassID = @DataClassID--, @PropertyList = @PropertyList, @DimensionList = @DimensionList, @OnlySecuredDimYN = @OnlySecuredDimYN, @ShowAllMembersYN = @ShowAllMembersYN, @Selected = @Selected OUT
				EXEC [dbo].[spGet_DataClass_DimensionMember] @UserID = @UserID,  @InstanceID = @InstanceID, @VersionID = @VersionID, @DataClassID = @DataClassID, @DimensionList = '-1|-3|-4|-6|-7|-31|-66', @ShowAllMembersYN = 1, @Debug = @DebugSub
			END

	SET @Step = '@ResultTypeBM & 4, Transaction level from Journal'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					@Book = EB.Book
				FROM
					pcINTEGRATOR_Data..Entity E
					INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 2 > 0 AND EB.SelectYN <> 0
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.MemberKey = @Entity AND
					E.SelectYN <> 0

				SET @JournalFilter = 'TimeDataView=YTD'
				IF @Scenario IS NOT NULL SET @JournalFilter = @JournalFilter + '|Scenario=' + @Scenario
				IF @Entity IS NOT NULL SET @JournalFilter = @JournalFilter + '|Entity=' + @Entity
				IF @Book IS NOT NULL SET @JournalFilter = @JournalFilter + '|Book=' + @Book
				IF @FiscalYear IS NOT NULL SET @JournalFilter = @JournalFilter + '|FiscalYear=' + CONVERT(nvarchar(15), @FiscalYear)
				IF @Account IS NOT NULL SET @JournalFilter = @JournalFilter + '|Account=' + @Account
				IF @YearMonth IS NOT NULL SET @JournalFilter = @JournalFilter + '|YearMonth=' + CONVERT(nvarchar(15), @YearMonth)

				IF @DebugBM & 2 > 0 SELECT [@Book] = @Book, [@JournalFilter]=@JournalFilter

				--EXEC [dbo].[spPortalGet_Journal] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @ResultTypeBM = 4, @FieldTypeBM = 3, @TransactionTypeBM = @TransactionTypeBM, @Filter=@JournalFilter, @Rows = @Rows, @Debug = @DebugSub
				--SELECT ResultTypeBM = 4, JournalFilter = @JournalFilter

				SELECT 
					[ResultTypeBM] = 4,
					[Dimension] = LEFT([Value], CHARINDEX('=', [Value]) - 1),
					[FilterString] = SUBSTRING([Value], CHARINDEX('=', [Value]) + 1, LEN([Value]) - CHARINDEX('=', [Value]))
				FROM
					STRING_SPLIT (@JournalFilter, '|') 
			END

	SET @Step = '@ResultTypeBM & 56'
		IF @ResultTypeBM & 56 > 0
			BEGIN
				CREATE TABLE #MatchingBase8
					(
					[Rule_ICmatchID] int,
					[FiscalYear] int,
					[FiscalPeriod] int,
					[YearMonth] int,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[InterCompany] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[BalanceYN] bit,
					[Rate_MemberId] bigint,
					[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Currency_Book] nchar(3) COLLATE DATABASE_DEFAULT,
					[Currency_Book_MemberId] bigint,
					[NetValue_Book] float,
					[Currency_Transaction] nchar(3) COLLATE DATABASE_DEFAULT,
					[NetValue_Transaction] float,
					[Currency_InterCompany] nchar(3) COLLATE DATABASE_DEFAULT,
					[Currency_InterCompany_MemberId] bigint,
					[NetValue_InterCompany] float,
					[Currency_Matching] nchar(3) COLLATE DATABASE_DEFAULT,
					[Currency_Matching_MemberId] bigint,
					[NetValue_Matching] float
					)
			END

	SET @Step = '@ResultTypeBM & 32, recalculate wrk-table'
		IF @ResultTypeBM & 32 > 0
			BEGIN
IF @Debug <> 0 SELECT 'Arne1'
				CREATE TABLE #Selection
					(
					[Scenario_MemberId] bigint,
					[Time_MemberId] bigint
					)

				CREATE TABLE #ReportingCurrency
					(
					Currency_MemberId bigint,
					Currency_MemberKey nvarchar(50) COLLATE DATABASE_DEFAULT
					)

				CREATE TABLE #FxRate
					(
					[BaseCurrency_MemberId] bigint,
					[Currency_MemberId] bigint, 
					[Entity_MemberId] bigint,
					[Rate_MemberId] bigint, 
					[Scenario_MemberId] bigint, 
					[Time_MemberId] bigint,
					[FxRate] float
					)

				IF CURSOR_STATUS('global','ICmatch_Cursor') >= -1 DEALLOCATE ICmatch_Cursor
				DECLARE ICmatch_Cursor CURSOR FOR
			
					SELECT 
						Rule_ICmatchID,
						Rule_ICmatchName,
						DimensionFilter
					FROM
						pcINTEGRATOR_Data..BR05_Rule_ICmatch
					WHERE
						InstanceID = @InstanceID AND
						VersionID = @VersionID AND
						SelectYN <> 0
					ORDER BY
						SortOrder

					OPEN ICmatch_Cursor
					FETCH NEXT FROM ICmatch_Cursor INTO @Rule_ICmatchID, @Rule_ICmatchName, @DimensionFilter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Rule_ICmatchID] = @Rule_ICmatchID, [@Rule_ICmatchName] = @Rule_ICmatchName, [@DimensionFilter] = @DimensionFilter

							EXEC [spGet_FilterTable]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepReference = 'InterCompany',
								@PipeString = @DimensionFilter,
								@DatabaseName = @CallistoDatabase,
								@StorageTypeBM_DataClass = 1,
								@StorageTypeBM = 4,
								@SQLFilter = @SQLFilter OUT,
								@JobID = @JobID,
								@Debug = @DebugSub

							SET @SQLFilter = ISNULL(@SQLFilter, '')
							
							IF @DebugBM & 2 > 0 SELECT [@SQLFilter] = @SQLFilter

							SET @SQLStatement = '
								INSERT INTO #MatchingBase8
									(
									[Rule_ICmatchID],
									[FiscalYear],
									[FiscalPeriod],
									[YearMonth],
									[Entity],
									[InterCompany],
									[Account],
									[BalanceYN],
									[Scenario],
									[Currency_Book],
									[NetValue_Book],
									[Currency_Transaction],
									[NetValue_Transaction],
									[Currency_Matching],
									[Currency_Matching_MemberId] 
									)
								SELECT
									[Rule_ICmatchID] = ' + CONVERT(nvarchar(15), @Rule_ICmatchID) + ',
									[FiscalYear] = MAX(J.[FiscalYear]),
									[FiscalPeriod] = MAX(J.[FiscalPeriod]),
									[YearMonth] = J.[YearMonth],
									[Entity] = J.[Entity],
									[InterCompany] = J.[InterCompanyEntity],
									[Account] = J.Account,
									[BalanceYN] = 0,
									[Scenario] = J.[Scenario],
									[Currency_Book],
									[NetValue_Book] = ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4),
									[Currency_Transaction] = ISNULL([Currency_Transaction], ''''),
									[NetValue_Transaction] = ROUND(SUM(J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction]), 4),
									[Currency_Matching] = ''' + @MatchingCurrency + ''',
									[Currency_Matching_MemberId] = ' + CONVERT(nvarchar(20), @Currency_Matching_MemberId) + '
								FROM 
									' + @JournalTable + ' J
								WHERE
									' + CASE WHEN LEN (@SQLFilter) <> 0 THEN @SQLFilter + ' AND ' ELSE '' END + '
									J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
									' + CASE WHEN @Entity IS NULL THEN '' ELSE '(J.[Entity] = ''' + @Entity + ''' OR J.[InterCompanyEntity] = ''' + @Entity + ''') AND' END + '
									J.[Scenario] = ''' + @Scenario + ''' AND
									J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
									J.[FiscalPeriod] <= ' + CONVERT(nvarchar(15), @FiscalPeriod) + ' AND
									J.[BalanceYN] = 0 AND
									J.[TransactionTypeBM] & 3 > 0 AND
									J.[ConsolidationGroup] IS NULL AND
									LEN(J.[InterCompanyEntity]) > 0 AND
									J.[InterCompanyEntity] <> ''NONE''
								GROUP BY
									J.[YearMonth],
									J.[Entity],
									J.[InterCompanyEntity],
									J.[Account],
									J.[Scenario],
									J.[Currency_Book],
									ISNULL([Currency_Transaction], '''')'

							SET @SQLStatement = @SQLStatement + '
								UNION
								SELECT
									[Rule_ICmatchID] = ' + CONVERT(nvarchar(15), @Rule_ICmatchID) + ',
									[FiscalYear] = MAX(YM.[FiscalYear]),
									[FiscalPeriod] = MAX(YM.[FiscalPeriod]),
									[YearMonth] = YM.[YearMonth],
									[Entity] = J.[Entity],
									[InterCompany] = J.[InterCompanyEntity],
									[Account] = J.Account,
									[BalanceYN] = 1,
									[Scenario] = J.[Scenario],
									[Currency_Book],
									[NetValue_Book] = ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4),
									[Currency_Transaction] = ISNULL([Currency_Transaction], ''''),
									[NetValue_Transaction] = ROUND(SUM(J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction]), 4),
									[Currency_Matching] = ''' + @MatchingCurrency + ''',
									[Currency_Matching_MemberId] = ' + CONVERT(nvarchar(20), @Currency_Matching_MemberId) + '
								FROM 
									#YearMonth YM
									INNER JOIN ' + @JournalTable + ' J ON J.[FiscalYear] = YM.[FiscalYear]
								WHERE
									' + CASE WHEN LEN (@SQLFilter) <> 0 THEN @SQLFilter + ' AND ' ELSE '' END + '
									J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
									' + CASE WHEN @Entity IS NULL THEN '' ELSE '(J.[Entity] = ''' + @Entity + ''' OR J.[InterCompanyEntity] = ''' + @Entity + ''') AND' END + '
									J.[Scenario] = ''' + @Scenario + ''' AND
									J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
--									J.[FiscalPeriod] <= ' + CONVERT(nvarchar(15), @FiscalPeriod) + ' AND
									J.[FiscalPeriod] <= YM.[FiscalPeriod] AND
									J.[BalanceYN] <> 0 AND
									J.[TransactionTypeBM] & 3 > 0 AND
									J.[ConsolidationGroup] IS NULL AND
									LEN(J.[InterCompanyEntity]) > 0 AND
									J.[InterCompanyEntity] <> ''NONE''
								GROUP BY
									YM.[YearMonth],
									J.[Entity],
									J.[InterCompanyEntity],
									J.[Account],
									J.[Scenario],
									J.[Currency_Book],
									ISNULL([Currency_Transaction], '''')'

							IF @DebugBM & 2 > 0 
								BEGIN
									IF LEN(@SQLStatement) > 4000 
										BEGIN
											PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR05_ICmatch, Add rows.'
											EXEC [dbo].[spSet_wrk_Debug]
												@UserID = @UserID,
												@InstanceID = @InstanceID,
												@VersionID = @VersionID,
												@DatabaseName = @DatabaseName,
												@CalledProcedureName = @ProcedureName,
												@Comment = 'BR05_ICmatch, Add rows', 
												@SQLStatement = @SQLStatement,
												@JobID = @JobID
										END
									ELSE
										PRINT @SQLStatement
								END
							
							EXEC (@SQLStatement)

							FETCH NEXT FROM ICmatch_Cursor INTO @Rule_ICmatchID, @Rule_ICmatchName, @DimensionFilter
						END

				CLOSE ICmatch_Cursor
				DEALLOCATE ICmatch_Cursor



				--FX-conversion

				UPDATE MB8
				SET
					Currency_InterCompany = EB.Currency
				FROM
					#MatchingBase8 MB8
					INNER JOIN pcINTEGRATOR_Data..Entity E ON E.InstanceID = @InstanceID AND E.VersionID = @VersionID AND E.MemberKey = MB8.InterCompany AND E.SelectYN <> 0 AND E.DeletedID IS NULL
					INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 3 = 3

				UPDATE MB8
				SET
					Currency_Book_MemberId = C.MemberId
				FROM
					#MatchingBase8 MB8
					INNER JOIN #Currency C ON C.MemberKey = MB8.Currency_Book

				UPDATE MB8
				SET
					Currency_InterCompany_MemberId = C.MemberId
				FROM
					#MatchingBase8 MB8
					INNER JOIN #Currency C ON C.MemberKey = MB8.Currency_InterCompany

				SET @SQLStatement = '
					UPDATE MB8
					SET
						Rate_MemberId = A.Rate_MemberId
					FROM
						#MatchingBase8 MB8
						INNER JOIN ' + @CallistoDatabase + '..S_DS_Account A ON A.[Label] = MB8.[Account]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				
				SET @SQLStatement = '
					INSERT INTO #Selection
						(
						[Scenario_MemberId],
						[Time_MemberId]
						)
					SELECT DISTINCT
						[Scenario_MemberId] = S.[MemberId],
						[Time_MemberId] = MB8.[YearMonth]
					FROM
						#MatchingBase8 MB8
						INNER JOIN ' + @CallistoDatabase + '..S_DS_Scenario S ON S.[Label] = ''' + @Scenario + ''''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Selection', * FROM #Selection
IF @Debug <> 0 SELECT 'Arne2'


				SET @SQLStatement = '
					INSERT INTO #ReportingCurrency
						(
						Currency_MemberId,
						Currency_MemberKey
						)
					SELECT
						Currency_MemberId = [MemberId],
						Currency_MemberKey = [Label]
					FROM
						' + @CallistoDatabase + '..S_DS_Currency C
					WHERE
						C.[Label] = ''' + @MatchingCurrency + ''''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#ReportingCurrency', * FROM #ReportingCurrency

				EXEC spBR_BR04 @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @CalledBy='MasterSP', @Operator=@Operator OUT, @JobID=@JobID, @Debug=@DebugSub

				IF (SELECT COUNT(1) FROM #FxRate) = 0
					BEGIN
						INSERT INTO #FxRate
							(
							[BaseCurrency_MemberId],
							[Currency_MemberId], 
							[Entity_MemberId],
							[Rate_MemberId], 
							[Scenario_MemberId], 
							[Time_MemberId],
							[FxRate]
							)
						SELECT DISTINCT
							[BaseCurrency_MemberId] = -1,
							[Currency_MemberId] = RC.[Currency_MemberId], 
							[Entity_MemberId] = -1,
							[Rate_MemberId] = MB8.[Rate_MemberId], 
							[Scenario_MemberId] = S.[Scenario_MemberId], 
							[Time_MemberId] = S.[Time_MemberId],
							[FxRate] = 1
						FROM
							#Selection S
							INNER JOIN #ReportingCurrency RC ON 1 = 1
							INNER JOIN (SELECT DISTINCT [Rate_MemberId] FROM #MatchingBase8) MB8 ON 1 = 1
					END
				
				IF @DebugBM & 2 > 0 SELECT TempTable = '#FxRate', * FROM #FxRate ORDER BY Currency_MemberId, Time_MemberId

				UPDATE MB8
				SET
					NetValue_InterCompany = CASE WHEN @Operator = '*' THEN MB8.NetValue_Book * (FxD.[FxRate] / FxS.[FxRate]) ELSE MB8.NetValue_Book / (FxD.[FxRate] / FxS.[FxRate]) END
				FROM
					#MatchingBase8 MB8
					INNER JOIN #FxRate FxD ON 
						FxD.[Currency_MemberId] = MB8.[Currency_InterCompany_MemberId] AND 
						FxD.[Rate_MemberId] = MB8.[Rate_MemberId] AND 
						FxD.[Scenario_MemberId] = @Scenario_MemberId AND 
						FxD.[Time_MemberId] = MB8.[YearMonth]
					INNER JOIN #FxRate FxS ON
						FxS.[Currency_MemberId] = MB8.[Currency_Book_MemberId] AND
						FxS.[Rate_MemberId] = FxD.[Rate_MemberId] AND
						FxS.[Scenario_MemberId] = FxD.[Scenario_MemberId] AND
						FxS.[Time_MemberId] = FxD.[Time_MemberId]

				UPDATE MB8
				SET
					NetValue_Matching = CASE WHEN @Operator = '*' THEN MB8.NetValue_Book * (FxD.[FxRate] / FxS.[FxRate]) ELSE MB8.NetValue_Book / (FxD.[FxRate] / FxS.[FxRate]) END
				FROM
					#MatchingBase8 MB8
					INNER JOIN #FxRate FxD ON 
						FxD.[Currency_MemberId] = MB8.[Currency_Matching_MemberId] AND 
						FxD.[Rate_MemberId] = MB8.[Rate_MemberId] AND 
						FxD.[Scenario_MemberId] = @Scenario_MemberId AND 
						FxD.[Time_MemberId] = MB8.[YearMonth]
					INNER JOIN #FxRate FxS ON
						FxS.[Currency_MemberId] = MB8.[Currency_Book_MemberId] AND
						FxS.[Rate_MemberId] = FxD.[Rate_MemberId] AND
						FxS.[Scenario_MemberId] = FxD.[Scenario_MemberId] AND
						FxS.[Time_MemberId] = FxD.[Time_MemberId]

				IF @DebugBM & 2 > 0 
					BEGIN
						SELECT TempTable = '#MatchingBase8', [Rule_ICmatchID],
							[YearMonth],
							[Entity],
							[InterCompany],
							[Account],
							[Scenario],
							[Currency_Matching],
							[Rows] = COUNT(1)
							FROM #MatchingBase8 
						GROUP BY
							[Rule_ICmatchID],
							[YearMonth],
							[Entity],
							[InterCompany],
							[Account],
							[Scenario],
							[Currency_Matching]
						HAVING COUNT(1) > 1
						ORDER BY
							[Rule_ICmatchID],
							[YearMonth],
							[Entity],
							[InterCompany],
							[Account],
							[Scenario],
							[Currency_Matching]

						SELECT TempTable = '#MatchingBase8', * FROM #MatchingBase8 
						ORDER BY
							[Rule_ICmatchID],
							[YearMonth],
							[Entity],
							[InterCompany],
							[Account],
							[Scenario],
							[Currency_Matching]
					END

--Update [pcINTEGRATOR_Log].[dbo].[wrk_InterCompany_Matching]
				DELETE ICM
				FROM
					[pcINTEGRATOR_Log].[dbo].[wrk_InterCompany_Matching] ICM
					INNER JOIN (
						SELECT DISTINCT
							Rule_ICmatchID,
							YearMonth,
							Entity,
							Scenario,
							Currency_Matching
						FROM
							#MatchingBase8) sub ON sub.Rule_ICmatchID = ICM.Rule_ICmatchID AND sub.YearMonth = ICM.YearMonth AND sub.Entity = ICM.Entity AND sub.Scenario = ICM.Scenario AND sub.Currency_Matching = ICM.Currency_Matching
				WHERE
					ICM.InstanceID = @InstanceID AND
					ICM.VersionID = @VersionID

				SET @Deleted = @Deleted + @@ROWCOUNT

				INSERT INTO [pcINTEGRATOR_Log].[dbo].[wrk_InterCompany_Matching]
					(
					[InstanceID],
					[VersionID],
					[Rule_ICmatchID],
					[FiscalYear],
					[FiscalPeriod],
					[YearMonth],
					[Entity],
					[InterCompany],
					[Account],
					[BalanceYN],
					[Scenario],
					[Currency_Book],
					[NetValue_Book],
					[Currency_Transaction],
					[NetValue_Transaction],
					[Currency_InterCompany],
					[NetValue_InterCompany],
					[Currency_Matching],
					[NetValue_Matching]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[Rule_ICmatchID],
					[FiscalYear],
					[FiscalPeriod],
					[YearMonth],
					[Entity],
					[InterCompany],
					[Account],
					[BalanceYN],
					[Scenario],
					[Currency_Book],
					[NetValue_Book],
					[Currency_Transaction],
					[NetValue_Transaction],
					[Currency_InterCompany],
					[NetValue_InterCompany],
					[Currency_Matching],
					[NetValue_Matching]
				FROM
					#MatchingBase8

			END

	SET @Step = 'Fill #MatchingBase8 from [pcINTEGRATOR_Log].[dbo].[wrk_InterCompany_Matching]'
		IF @ResultTypeBM & 24 > 0 AND @ResultTypeBM & 32 = 0
			BEGIN
				INSERT INTO #MatchingBase8
					(
					[Rule_ICmatchID],
					[YearMonth],
					[Entity],
					[InterCompany],
					[Account],
					[Scenario],
					[Currency_Book],
					[NetValue_Book],
					[Currency_Transaction],
					[NetValue_Transaction],
					[Currency_InterCompany],
					[NetValue_InterCompany],
					[Currency_Matching],
					[NetValue_Matching]
					)
				SELECT
					[Rule_ICmatchID] = MAX([Rule_ICmatchID]),
					[YearMonth] = @YearMonth,
					[Entity],
					[InterCompany],
					[Account],
					[Scenario],
					[Currency_Book],
					[NetValue_Book] = SUM([NetValue_Book]),
					[Currency_Transaction],
					[NetValue_Transaction] = SUM([NetValue_Transaction]),
					[Currency_InterCompany],
					[NetValue_InterCompany] = SUM([NetValue_InterCompany]),
					[Currency_Matching],
					[NetValue_Matching] = SUM([NetValue_Matching])
				FROM
					[pcINTEGRATOR_Log].[dbo].[wrk_InterCompany_Matching]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND						
					(Entity = @Entity OR InterCompany = @Entity OR @Entity IS NULL) AND
					Scenario = @Scenario AND
					Currency_Matching = @MatchingCurrency AND
					((BalanceYN <> 0 AND YearMonth = @YearMonth) OR
					(BalanceYN = 0 AND FiscalYear = @FiscalYear AND FiscalPeriod <= @FiscalPeriod))
				GROUP BY
					[Entity],
					[InterCompany],
					[Account],
					[Scenario],
					[Currency_Book],
					[Currency_Transaction],
					[Currency_InterCompany],
					[Currency_Matching]

				IF @Debug <> 0 SELECT TempTable = '#MatchingBase8', * FROM #MatchingBase8
			END

	SET @Step = '@ResultTypeBM & 8'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					@Rule_ICmatchID = [Rule_ICmatchID]
				FROM
					pcINTEGRATOR_Data..BR05_Rule_ICmatch
				WHERE
					[Rule_ICmatchName] = @RULE_Consolidation

				SELECT
					[Column] = [Column],
					[Currency] = [Currency_Matching],
					[Scenario] = [Scenario],
					[YearMonth] = [YearMonth],
					[Entity] = [Entity],
					[InterCompany] = [InterCompany],
					[Account] = [Account],
					[Net_Entity] = SUM(CASE WHEN [Column] = 'Entity' THEN [NetValue_Matching] ELSE 0 END),
					[Net_InterCompany] = SUM(CASE WHEN [Column] = 'InterCompany' THEN [NetValue_Matching] ELSE 0 END),
					[Currency_Functional] = MAX([Currency_Functional]),
					[Net_Entity_Functional] = SUM(CASE WHEN [Column] = 'Entity' THEN [Net_Entity_Functional] ELSE 0 END),
					[Net_InterCompany_Functional] = SUM(CASE WHEN [Column] = 'InterCompany' THEN [Net_InterCompany_Functional] ELSE 0 END),
					[Currency_Entity_Transaction] = MAX([Currency_Entity_Transaction]),
					[Net_Entity_Transaction] = SUM(CASE WHEN [Column] = 'Entity' THEN [Net_Entity_Transaction] ELSE 0 END),
					[Currency_InterCompany_Transaction] = MAX([Currency_InterCompany_Transaction]),
					[Net_InterCompany_Transaction] = SUM(CASE WHEN [Column] = 'InterCompany' THEN [Net_InterCompany_Transaction] ELSE 0 END)
				INTO
					#Matching8
				FROM
					(
					SELECT
						[Column] = 'Entity',
						[Currency_Matching] = [Currency_Matching],
						[Scenario] = [Scenario],
						[YearMonth] = [YearMonth],
						[Entity] = [Entity],
						[InterCompany] = [InterCompany],
						[Account] = [Account],
						[NetValue_Matching] = [NetValue_Matching],
						[Currency_Functional] = [Currency_Book],
						[Net_Entity_Functional] = [NetValue_Book],
						[Net_InterCompany_Functional] = 0,
						[Currency_Entity_Transaction] = [Currency_Transaction],
						[Net_Entity_Transaction] = [NetValue_Transaction],
						[Currency_InterCompany_Transaction] = NULL,
						[Net_InterCompany_Transaction] = 0
					FROM
						#MatchingBase8
					WHERE
--						[Rule_ICmatchID] = @Rule_ICmatchID AND
						[Entity] = @Entity OR @Entity IS NULL

					UNION SELECT
						[Column] = 'InterCompany',
						[Currency_Matching] = [Currency_Matching],
						[Scenario] = [Scenario],
						[YearMonth] = [YearMonth],
						[Entity] = [InterCompany],
						[InterCompany] = [Entity],
						[Account] = [Account],
						[NetValue_Matching] = [NetValue_Matching],
						[Currency_Functional] = [Currency_InterCompany],
						[Net_Entity_Functional] = 0,
						[Net_InterCompany_Functional] = [NetValue_InterCompany],
						[Currency_Entity_Transaction] = NULL,
						[Net_Entity_Transaction] = 0,
						[Currency_InterCompany_Transaction] = [Currency_Transaction],
						[Net_InterCompany_Transaction] = [NetValue_Transaction]
					FROM
						#MatchingBase8
					WHERE
--						[Rule_ICmatchID] = @Rule_ICmatchID AND
						[InterCompany] = @Entity OR @Entity IS NULL
					) sub
				GROUP BY
					sub.[Column],
					sub.[Currency_Matching],
					sub.[Scenario],
					sub.[YearMonth],
					sub.[Entity],
					sub.[InterCompany],
					sub.[Account]

				IF @Debug <> 0 SELECT TempTable = '#Matching8', * FROM #Matching8

				SELECT
					[ResultTypeBM] = 8,
					[Entity],
					[InterCompany],
					[Account],
					[Net_Entity] = SUM([Net_Entity]),
					[Net_InterCompany] = SUM([Net_InterCompany]),
					[Currency_Functional] = MAX([Currency_Functional]),
					[Net_Entity_Functional] = SUM(CASE WHEN [Net_Entity_Functional] IS NULL THEN 0 ELSE [Net_Entity_Functional] END),
					[Net_InterCompany_Functional] = SUM(CASE WHEN [Net_InterCompany_Functional] IS NULL THEN 0 ELSE [Net_InterCompany_Functional] END),
					[Currency_Entity_Transaction] = MAX([Currency_Entity_Transaction]),
					[Net_Entity_Transaction] = SUM(CASE WHEN [Net_Entity_Transaction] IS NULL THEN 0 ELSE [Net_Entity_Transaction] END),
					[Currency_InterCompany_Transaction] = MAX([Currency_InterCompany_Transaction]),
					[Net_InterCompany_Transaction] = SUM(CASE WHEN [Net_InterCompany_Transaction] IS NULL THEN 0 ELSE [Net_InterCompany_Transaction] END)
				FROM
					#Matching8
				GROUP BY
					[Entity],
					[InterCompany],
					[Account]
				HAVING
					SUM([Net_Entity]) <> 0 OR SUM([Net_InterCompany]) <> 0
				ORDER BY
					[Entity],
					[InterCompany],
					[Account]
			END

	SET @Step = '@ResultTypeBM & 16'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				CREATE TABLE #MatchingBase16
					(
					[Rule_ICmatchName] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[YearMonth] int,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[InterCompany] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[NetValue] float
					)


				INSERT INTO #MatchingBase16
					(
					[Rule_ICmatchName],
					[Scenario],
					[YearMonth],
					[Entity],
					[InterCompany],
					[NetValue]
					)
				SELECT
					RIC.[Rule_ICmatchName],
					MB8.[Scenario],
					MB8.[YearMonth],
					MB8.[Entity],
					MB8.[InterCompany],
					[NetValue] = ROUND(SUM(MB8.[NetValue_Matching]), 4)
				FROM 
					#MatchingBase8 MB8
					INNER JOIN pcINTEGRATOR_Data..BR05_Rule_ICmatch RIC ON RIC.[Rule_ICmatchID] = MB8.[Rule_ICmatchID]
				GROUP BY
					RIC.[Rule_ICmatchName],
					MB8.[Scenario],
					MB8.[YearMonth],
					MB8.[Entity],
					MB8.[InterCompany]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#MatchingBase16', * FROM #MatchingBase16 ORDER BY Entity, [Rule_ICmatchName], InterCompany

				IF (SELECT COUNT(1) FROM #MatchingBase16) = 0
					BEGIN
						SET @Message = 'The selected parameters does not match any data to look at.'
						SET @Severity = 0
						GOTO EXITPOINT
					END
				
				SELECT
					[Rule_ICmatchName] = [Rule_ICmatchName],
					[Scenario] = [Scenario],
					[YearMonth] = [YearMonth],
					[Entity] = [Entity],
					[InterCompany] = [InterCompany],
					[NetDiff] = SUM(CASE WHEN [Column] = 'Entity' THEN [NetValue] ELSE 0 END) + SUM(CASE WHEN [Column] = 'InterCompany' THEN [NetValue] ELSE 0 END),
					[Status] = CASE WHEN ABS(SUM(CASE WHEN [Column] = 'Entity' THEN [NetValue] ELSE 0 END) + SUM(CASE WHEN [Column] = 'InterCompany' THEN [NetValue] ELSE 0 END)) > @MaxDiff THEN 0 ELSE 1 END
				INTO
					#Matching16
				FROM
					(
					SELECT
						[Column] = 'Entity',
						[Rule_ICmatchName] = [Rule_ICmatchName],
						[Scenario] = [Scenario],
						[YearMonth] = [YearMonth],
						[Entity] = [Entity],
						[InterCompany] = [InterCompany],
						[NetValue] = [NetValue]
					FROM
						#MatchingBase16

					UNION SELECT
						[Column] = 'InterCompany',
						[Rule_ICmatchName] = [Rule_ICmatchName],
						[Scenario] = [Scenario],
						[YearMonth] = [YearMonth],
						[Entity] = [InterCompany],
						[InterCompany] = [Entity],
						[NetValue] = [NetValue]
					FROM
						#MatchingBase16
					) sub
				GROUP BY
					[Rule_ICmatchName],
					[Scenario],
					[YearMonth],
					[Entity],
					[InterCompany]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Matching16', * FROM #Matching16 ORDER BY Entity, InterCompany

				SELECT
					@PivotColumn += QUOTENAME([Rule_ICmatchName]) + ','
				FROM
					(
					SELECT DISTINCT
						[Rule_ICmatchName]
					FROM 
						#Matching16
					) sub
				ORDER BY 
					[Rule_ICmatchName] 

				SET @PivotColumn = LEFT(@PivotColumn, LEN(@PivotColumn) - 1);

				SET @SQLStatement = '
					SELECT * FROM (
					SELECT
						[Rule_ICmatchName],
						[Status],
						[ResultTypeBM] = 16,
						[Entity]
					FROM  
						#Matching16) t
					PIVOT  
					(  
						MIN([Status])  
					FOR   
						[Rule_ICmatchName] IN (' + @PivotColumn + ')  
					) AS [PivotTable]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

			END

	--SET @Step = 'Drop temp tables'
	--	IF @ResultTypeBM & 32 > 0 DROP TABLE #Selection

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
