SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_DC_Journal_20250212]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@SourceTypeBM int = 1048575,
	@SequenceBM int = 7, --1 = GL transactions, 2 = Opening balances, 4 = Budget transactions
	@SourceTypeID int = NULL, --Mandatory for SIE4
	@SourceID INT = NULL,
	@StartFiscalYear int = NULL, --Mandatory for SIE4
	@FullReloadYN bit = 0,	--Only valid for @SequenceBM = 1 (GL transactions)
	@CyniYN bit = 1,
	@LoadGLJrnDtl_NotBalanceYN bit = 0, --1 = include loading of GLJrnDtl for FiscalPeriods not balancing
	@OB_ERP_InsertYN bit = NULL, -- 0 = do not insert OB_ERP, OB_ADJ not calculated; compute opening balances from last Fiscal Period's closing balance (OB_JRN);  1 or NULL = insert OB_ERP and OB_ADJ may be calculated

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000643,
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
EXEC [spIU_DC_Journal] @UserID = -10, @InstanceID = 548, @VersionID = 1061, @FullReloadYN=1,
@Entity_MemberKey='159491IP',@DebugBM = 15

EXEC [spIU_DC_Journal] @UserID = -10, @InstanceID = 478, @VersionID = 1030, @FullReloadYN = 1, @FiscalYear=2021,@DebugBM = 15
EXEC [spIU_DC_Journal] @UserID = -10, @InstanceID = 478, @VersionID = 1030, @FullReloadYN = 0, @DebugBM = 3
EXEC [spIU_DC_Journal] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @FullReloadYN = 1, @SequenceBM=4
EXEC [spIU_DC_Journal] @UserID = -10, @InstanceID = 515, @VersionID = 1064, @FullReloadYN = 1, @SequenceBM = 1, @Entity_MemberKey = 'REM', @Book = GL, @DebugBM = 7 --REMichel

EXEC [spIU_DC_Journal] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@JSON nvarchar(max),
	@FiscalYearLoop int,
	@JournalTable nvarchar(100),
	@Column nvarchar(50),
	@MappingTypeID int,
	@SQLStatement nvarchar(max),
	@EndFiscalYear int,
	@FiscalPeriodString nvarchar(1000) = '',
	@MaxSourceCounter bigint,
	@Entity_MemberKey_CYNI nvarchar(50) = NULL,
	@Book_CYNI nvarchar(50) = NULL,
	@FiscalYear_CYNI int = NULL,
	@FiscalPeriod_CYNI int = NULL,
	@MasterClosedYearMonth int,
	@MasterClosedYear int,
	@Called_SequenceBM int,
	@Called_FiscalYear int,
	@CallistoDatabase nvarchar(100),

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
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into #Journal from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Added pcSource. Enhanced structure, changed database to [pcINTEGRATOR_Data]. Implemented [spGet_JournalTable].'
		IF @Version = '2.0.2.2145' SET @Description = 'Moved Mapping Step moved from [spIU_DC_Journal_SIE4] to [spIU_DC_Journal] after @Step = Run Entity_Cursor'
		IF @Version = '2.0.2.2149' SET @Description = 'Load Budget data by default, @SequenceBM = 7.'
		IF @Version = '2.0.3.2151' SET @Description = 'Added call to [spIU_DC_Journal_Axapta] for SourceTypeID = 9. Updated datatypes in temp table #Journal.'
		IF @Version = '2.0.3.2152' SET @Description = 'Handle #Journal_Update.'
		IF @Version = '2.0.3.2153' SET @Description = 'Calculate @StartFiscalYear if more than 1 year to load.'
		IF @Version = '2.0.3.2154' SET @Description = 'Calculate @EndFiscalYear.'
		IF @Version = '2.1.0.2155' SET @Description = 'Call spGet_Journal_Update. Added variable @MaxSourceCounter.'
		IF @Version = '2.1.0.2156' SET @Description = 'Performance improvements.'
		IF @Version = '2.1.0.2157' SET @Description = 'Change datatype from int to bigint for #CursorTable.MaxSourceCounter'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine [spSet_Job].'
		IF @Version = '2.1.0.2161' SET @Description = 'Check for filters in [pcINTEGRATOR_Log].[dbo].[wrk_Journal_Update]. Changed prefix in the SP name.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added P21.'
		IF @Version = '2.1.0.2165' SET @Description = 'Added iScala.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added @SourceID parameter. Additional checking for #Journal_Update if not empty. Changed logic. Set @ProcedureName before @Step = Start Job.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added Entity_Cursor for @CyniYN <> 0. Test on BookTypeBM and removed specific entities when running incremental.'
		IF @Version = '2.1.1.2173' SET @Description = 'Make OpeningBalances independent from transactions. Use @FullReloadYN only for @SequenceBM = 1.'
		IF @Version = '2.1.1.2180' SET @Description = 'Added parameter @LoadGLJrnDtl_NotBalanceYN.'
		IF @Version = '2.1.2.2187' SET @Description = 'temp fix for SASAP (Saltwell) - SIE4 source (while SAP source is not yet finalized).'
		IF @Version = '2.1.2.2190' SET @Description = 'Upgraded to the actual SP template'
		IF @Version = '2.1.2.2198' SET @Description = 'Improved debugging. For Incremental load (FullReloadYN=0), set #MaxSourceCounter.[MaxSourceCounter] from posted (PostedStatus=1) Journal transactions only.'
		IF @Version = '2.1.2.2199' SET @Description = 'DB-1620: Added Parameter @OB_ERP_InsertYN and use for @SequenceBM = 2. If set to 0, OB_ERP is not inserted, OB_ADJ will not be calculated; opening balances are calculated based from closing balances from previous Fiscal Period (OB_JRN). Changed wild join on #FiscalYear when filling #CursorTable in @SequenceBM=2 to INNER JOIN #FiscalYear FY ON FY.[FiscalYear] >= EB.[StartFiscalYear] AND (FY.[FiscalYear] > @MasterClosedYear OR @MasterClosedYear IS NULL). Handle passing of @SourceID for SourceTypeID = 5 (P21). Not delete journal rows for advanced consolidation. Added filter on @SourceTypeID when inserting into #Entity_Book.'

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

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			EXEC [pcINTEGRATOR]..[spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=1,
				@JobID=@JobID OUT

		SELECT
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[pcINTEGRATOR_Data]..[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0
		
		SELECT
			@Called_SequenceBM = @SequenceBM,
			@Called_FiscalYear = @FiscalYear

--		SELECT
--			@StartFiscalYear = ISNULL(@StartFiscalYear, S.StartYear)
--		FROM
--			[Source] S
--			INNER JOIN [Model] M ON M.ModelID = S.ModelID AND M.BaseModelID = -7 AND M.SelectYN <> 0
--			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.InstanceID = @InstanceID AND A.VersionID = @VersionID AND A.SelectYN <> 0
--		WHERE
----			S.SourceTypeID = @SourceTypeID AND
--			S.SelectYN <> 0
			
		SELECT
			@EndFiscalYear = CASE WHEN FiscalYearStartMonth = 1 OR Month(GetDate()) < FiscalYearStartMonth THEN Year(GetDate()) ELSE Year(GetDate()) + 1 END
		FROM
			[pcINTEGRATOR_Data]..Instance
		WHERE
			InstanceID = @InstanceID

		EXEC [pcINTEGRATOR]..[spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 
		EXEC [pcINTEGRATOR]..[spGet_MasterClosedYear] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @MasterClosedYearMonth = @MasterClosedYearMonth OUT, @MasterClosedYear = @MasterClosedYear OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@Entity_MemberKey] = @Entity_MemberKey,
				[@Book] = @Book,
				[@FiscalYear] = @FiscalYear,
				[@FiscalPeriod] = @FiscalPeriod,
				[@SourceTypeBM] = @SourceTypeBM,
				[@Called_SequenceBM] = @Called_SequenceBM,
				[@SourceTypeID] = @SourceTypeID,
				[@StartFiscalYear] = @StartFiscalYear,
				[@FullReloadYN] = @FullReloadYN,
				[@SourceID] = @SourceID,
				[@JournalTable] = @JournalTable,
				[@CallistoDatabase] = @CallistoDatabase,
				[@MasterClosedYearMonth] = @MasterClosedYearMonth,
				[@EndFiscalYear] = @EndFiscalYear,
				[@JobID] = @JobID

	SET @Step = 'Create temp tables'
		CREATE TABLE #Entity_Book_FiscalYear
			(
			[Entity_MemberKey] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] [int],
			[StartFiscalYear] [int]
			)

		CREATE TABLE #Entity_Book_CYNI
			(
			[Entity_MemberKey_CYNI] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Book_CYNI] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[FiscalYear_CYNI] [int],
			[FiscalPeriod_CYNI] [int]
			)

		CREATE TABLE #Journal
			(
			[JobID] [int],
			[InstanceID] [int],
			[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] [int],
			[FiscalPeriod] [int],
			[JournalSequence] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[JournalNo] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[JournalLine] [int],
			[YearMonth] [int],
			[TransactionTypeBM] [int],
			[BalanceYN] [bit],
			[Account] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Segment01] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment02] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment03] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment04] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment05] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment06] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment07] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment08] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment09] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment10] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment11] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment12] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment13] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment14] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment15] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment16] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment17] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment18] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment19] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[Segment20] [nvarchar](50) COLLATE DATABASE_DEFAULT DEFAULT '',
			[JournalDate] [date],
			[TransactionDate] [date],
			[PostedDate] [date],
			[PostedStatus] [bit],
			[PostedBy] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Customer] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Supplier] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Description_Head] [nvarchar](255) COLLATE DATABASE_DEFAULT,
			[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
			[Currency_Book] [nchar](3) COLLATE DATABASE_DEFAULT,
			[ValueDebit_Book] [float],
			[ValueCredit_Book] [float],
			[Currency_Group] [nchar](3) COLLATE DATABASE_DEFAULT,
			[ValueDebit_Group] [float],
			[ValueCredit_Group] [float],
			[Currency_Transaction] [nchar](3) COLLATE DATABASE_DEFAULT,
			[ValueDebit_Transaction] [float],
			[ValueCredit_Transaction] [float],
			[SourceModule] [nvarchar](20) COLLATE DATABASE_DEFAULT,
			[SourceModuleReference] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[SourceCounter] [bigint],
			[SourceGUID] [uniqueidentifier]
			)

		CREATE TABLE #Entity_Book
			(
			[SourceTypeID] int,
			[SourceID] int,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[StartFiscalYear] [int]
			)

		CREATE TABLE #MaxSourceCounter
			(
			[SourceID] int,
			[MaxSourceCounter] bigint
			)

		CREATE TABLE #FiscalYear
			(
			FiscalYear int
			)

		CREATE TABLE #CursorTable
			(
			[SourceTypeID] int,
			[SourceID] int,
			[SequenceBM] int,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] int,
			[FiscalPeriodString] nvarchar(1000),
			--[FullReloadYN] bit,
			[MaxSourceCounter] bigint
			)

		CREATE TABLE #GLJrnDtl_NotBalance
			(
			[SourceID] [int],
			[Company] [nvarchar](8),
			[BookID] [nvarchar](12),
			[FiscalYear] [int],
			[FiscalPeriod] [int],
			[JournalCode] [nvarchar](4),
			[JournalNum] [int],
			[MinJournalLine] [int],
			[MaxJournalLine] [int],
			[PostedDate] [date],
			[MinSysRevID] [bigint],
			[MaxSysRevID] [bigint],
			[Rows] [int],
			[Amount] [float],
			[JournalRows] [int],
			[JournalAmount] [float]
			)

	SET @Step = 'Fill temp table #Entity_Book'
		INSERT INTO #Entity_Book
			(
			[SourceTypeID],
			[SourceID],
			[Entity],
			[Book],
			[StartFiscalYear]
			)
		SELECT
			--[SourceTypeID] = S.[SourceTypeID],
			[SourceTypeID] = CASE WHEN @SourceTypeID = 7 AND @Entity_MemberKey IS NOT NULL THEN @SourceTypeID ELSE S.[SourceTypeID] END,  --temp fix for SASAP (Saltwell) - SIE4 source (while SAP source is not yet finalized)
			[SourceID] = E.[SourceID],
			[Entity] = E.[MemberKey],
			[Book] = EB.[Book],
			[StartFiscalYear] = S.[StartYear]
		FROM
			pcINTEGRATOR_Data..Entity E
			INNER JOIN pcINTEGRATOR_Data..[Entity_Book] EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND BookTypeBM & 1 > 0 AND (EB.[Book] = @Book OR @Book IS NULL) AND EB.[SelectYN] <> 0
			INNER JOIN pcINTEGRATOR_Data..[Source] S ON S.[InstanceID] = E.[InstanceID] AND S.[VersionID] = E.[VersionID] AND S.[SourceID] = E.[SourceID] AND S.[SelectYN] <> 0 AND (S.[SourceTypeID] = @SourceTypeID OR @SourceTypeID IS NULL)
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.[SourceID] = @SourceID OR @SourceID IS NULL) AND
			(E.[MemberKey] = @Entity_MemberKey OR @Entity_MemberKey IS NULL) AND
			E.[SelectYN] <> 0 AND
			E.[DeletedID] IS NULL

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Entity_Book', * FROM #Entity_Book

	SET @Step = 'Fill temp table #CursorTable'
		IF @FullReloadYN = 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #MaxSourceCounter
						(
						[SourceID],
						[MaxSourceCounter]
						)
					SELECT
						[SourceID] = EB.[SourceID],
						[MaxSourceCounter] = MAX([SourceCounter])
					FROM
						#Entity_Book EB
						INNER JOIN ' + @JournalTable + ' J ON J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND J.[Entity] = EB.[Entity] AND J.[Book] = EB.[Book] AND J.[Scenario] = ''ACTUAL'' AND [TransactionTypeBM] & 1 > 0 AND J.PostedStatus = 1
					GROUP BY
						EB.[SourceID]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#MaxSourceCounter', * FROM #MaxSourceCounter

				INSERT INTO #CursorTable
					(
					[SourceTypeID],
					[SourceID],
					[SequenceBM],
					[Entity],
					[Book],
					--[FullReloadYN],
					[MaxSourceCounter]
					)
				SELECT DISTINCT
					[SourceTypeID],
					[SourceID] = EB.[SourceID],
					[SequenceBM] = 1,
					[Entity] = CASE WHEN EB.[SourceTypeID] IN (11) THEN 'Dummy' ELSE EB.[Entity] END,
					[Book] = CASE WHEN EB.[SourceTypeID] IN (11) THEN 'Dummy' ELSE EB.[Book] END,
					--[FullReloadYN] = @FullReloadYN,
					[MaxSourceCounter]
				FROM
					#Entity_Book EB
					INNER JOIN #MaxSourceCounter MSC ON MSC.[SourceID] = EB.[SourceID]
			END
		ELSE
			BEGIN
				SET @FiscalYearLoop = ISNULL(@StartFiscalYear, @FiscalYear)
		
				--IF @FiscalYearLoop IS NOT NULL
				--	BEGIN
				--		WHILE @FiscalYearLoop <= @EndFiscalYear
				--			BEGIN
				--				INSERT INTO #FiscalYear
				--					(
				--					FiscalYear
				--					)
				--				SELECT
				--					FiscalYear = @FiscalYearLoop

				--				SET @FiscalYearLoop = @FiscalYearLoop + 1
				--			END

				--	END

				SET @SQLStatement = '
					INSERT INTO #FiscalYear
						(
						[FiscalYear]
						)
					SELECT 
						[FiscalYear] = [MemberId]
					FROM	
						[' + @CallistoDatabase + '].[dbo].[S_DS_TimeFiscalYear]
					WHERE
						' + CASE WHEN @Called_FiscalYear IS NULL THEN '' ELSE '[MemberID] = ' + CONVERT(nvarchar(15), @Called_FiscalYear) + ' AND' END + '
						[MemberId] BETWEEN ' + CASE WHEN @StartFiscalYear IS NULL THEN '1900' ELSE CONVERT(nvarchar(15), @StartFiscalYear) END + ' AND ' + CONVERT(nvarchar(15), @EndFiscalYear)


				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT [TempTable_#FiscalYear] = '#FiscalYear', * FROM #FiscalYear
				IF @DebugBM & 2 > 0 SELECT [@FiscalYearLoop] = @FiscalYearLoop, [@StartFiscalYear] = @StartFiscalYear, [@FiscalYear] = @FiscalYear

				INSERT INTO #CursorTable
					(
					[SourceTypeID],
					[SourceID],
					[SequenceBM],
					[Entity],
					[Book],
					[FiscalYear],
					[FiscalPeriodString]
					--[FullReloadYN]
					)
				SELECT
					[SourceTypeID] = EB.[SourceTypeID],
					[SourceID] = EB.[SourceID],
					[SequenceBM] = 1,
					[Entity] = EB.[Entity],
					[Book] = EB.[Book],
					[FiscalYear],
					[FiscalPeriodString] = NULL
					--[FullReloadYN] = @FullReloadYN
				FROM
					#Entity_Book EB
					INNER JOIN #FiscalYear FY ON FY.[FiscalYear] >= EB.[StartFiscalYear] AND (FY.[FiscalYear] > @MasterClosedYear OR @MasterClosedYear IS NULL)
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#CursorTable', * FROM #CursorTable

	SET @Step = 'Run Entity_Cursor for Actual transactions'
		IF @Called_SequenceBM & 1 > 0
			BEGIN
				IF @DebugBM & 32 > 0 SELECT TempTable = '#Journal', Position = 'BeforeCursor, @Called_SequenceBM = 1', [Rows] = COUNT(1) FROM #Journal
				IF @LoadGLJrnDtl_NotBalanceYN = 0
					BEGIN
						--Fill table #GLJrnDtl_NotBalance
						IF CURSOR_STATUS('global','GLJrnDtl_NotBalance_Cursor') >= -1 DEALLOCATE GLJrnDtl_NotBalance_Cursor
						DECLARE GLJrnDtl_NotBalance_Cursor CURSOR FOR
			
							SELECT DISTINCT
								[SourceID]
							FROM
								#CursorTable
							WHERE
								[SourceTypeID] = 11

							OPEN GLJrnDtl_NotBalance_Cursor
							FETCH NEXT FROM GLJrnDtl_NotBalance_Cursor INTO @SourceID

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @DebugBM & 2 > 0 SELECT [@SourceID] = @SourceID

									EXEC [pcINTEGRATOR].[dbo].[spGet_GLJrnDtl_NotBalance]
										@UserID = @UserID,
										@InstanceID = @InstanceID,
										@VersionID = @VersionID,
										@SourceID  = @SourceID,
										@JournalTable = @JournalTable,
										@JobID = @JobID,
										@Debug = @DebugSub

									FETCH NEXT FROM GLJrnDtl_NotBalance_Cursor INTO @SourceID
								END

						CLOSE GLJrnDtl_NotBalance_Cursor
						DEALLOCATE GLJrnDtl_NotBalance_Cursor
					END

				IF @FullReloadYN = 0
					UPDATE CT
					SET
						[MaxSourceCounter] = CASE WHEN NB.[SourceCounter] IS NOT NULL AND NB.[SourceCounter] < CT.[MaxSourceCounter] THEN NB.[SourceCounter] ELSE CT.[MaxSourceCounter] END
					FROM
						#CursorTable CT
						LEFT JOIN (SELECT [SourceID], [SourceCounter] = MIN([MinSysRevID] - [MinJournalLine]) FROM #GLJrnDtl_NotBalance WHERE JournalAmount <> 0 GROUP BY [SourceID]) NB ON NB.[SourceID] = CT.[SourceID]

				--Fill table #Journal with normal transactions
				IF CURSOR_STATUS('global','Entity_Cursor') >= -1 DEALLOCATE Entity_Cursor
				DECLARE Entity_Cursor CURSOR FOR
					SELECT
						[SourceTypeID],
						[SourceID],
						[SequenceBM],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriodString],
						--[FullReloadYN],
						[MaxSourceCounter]
					FROM
						#CursorTable
					ORDER BY
						[SourceTypeID],
						[SourceID],
						[SequenceBM],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriodString],
						[MaxSourceCounter]

					OPEN Entity_Cursor
					FETCH NEXT FROM Entity_Cursor INTO @SourceTypeID, @SourceID, @SequenceBM, @Entity_MemberKey, @Book, @FiscalYear, @FiscalPeriodString, @MaxSourceCounter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0
								SELECT 
									[@UserID] = @UserID,
									[@InstanceID] = @InstanceID,
									[@VersionID] = @VersionID,
									[@SequenceBM] = @SequenceBM,
									[@JournalTable] = @JournalTable,
									[@JobID] = @JobID,
									[@DebugSub] = @DebugSub,
									[@SourceTypeID] = @SourceTypeID,
									[@SourceID] = @SourceID,
									[@MaxSourceCounter] = @MaxSourceCounter,
									[@Entity_MemberKey] = @Entity_MemberKey,
									[@Book] = @Book,
									[@FiscalYear] = @FiscalYear,
									[@FiscalPeriodString] = @FiscalPeriodString

							SET @JSON = '
								[
								{"TKey" : "UserID",  "TValue": "' + CONVERT(NVARCHAR(10), @UserID) + '"},
								{"TKey" : "InstanceID",  "TValue": "' + CONVERT(NVARCHAR(10), @InstanceID) + '"},
								{"TKey" : "VersionID",  "TValue": "' + CONVERT(NVARCHAR(10), @VersionID) + '"},
								{"TKey" : "SequenceBM",  "TValue": "' + CONVERT(NVARCHAR(10), @SequenceBM) + '"},
								{"TKey" : "JournalTable",  "TValue": "' + @JournalTable + '"},
								{"TKey" : "JobID",  "TValue": "' + CONVERT(NVARCHAR(10), @JobID) + '"},
								{"TKey" : "Debug",  "TValue": "' + CONVERT(NVARCHAR(10), @DebugSub) + '"},
								{"TKey" : "FullReloadYN",  "TValue": "' + CONVERT(NVARCHAR(10), @FullReloadYN) + '"}'
								+ CASE WHEN @SourceTypeID IN (1, 5, 11) AND @SourceID IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "SourceID",  "TValue": "' + CONVERT(NVARCHAR(10), @SourceID) + '"}' ELSE '' END +
								+ CASE WHEN @Entity_MemberKey IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity_MemberKey + '"}' END +
								+ CASE WHEN @Book IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "Book",  "TValue": "' + @Book + '"}' END +
								+ CASE WHEN @StartFiscalYear IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "StartFiscalYear",  "TValue": "' + CONVERT(NVARCHAR(10), @StartFiscalYear) + '"}' END +
								+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(NVARCHAR(10), @FiscalYear) + '"}' END +
								+ CASE WHEN @FiscalPeriodString IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "' + CASE WHEN @SourceTypeID IN (1, 11) THEN 'FiscalPeriodString' ELSE 'FiscalPeriod' END + '",  "TValue": "' + @FiscalPeriodString + '"}' END +
								+ CASE WHEN @MaxSourceCounter IS NULL OR @SourceTypeID NOT IN (1, 3, 11) THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "MaxSourceCounter",  "TValue": "' + CONVERT(NVARCHAR(20), @MaxSourceCounter) + '"}' END +
								']'

							IF @DebugBM & 2 > 0 PRINT @JSON

							IF @SourceTypeID = 1 --Epicor ERP
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_EpicorERP', @JSON = @JSON

							IF @SourceTypeID = 3 --iScala
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_iScala', @JSON = @JSON
					
							IF @SourceTypeID = 5 --P21
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_P21', @JSON = @JSON
					
							IF @SourceTypeID = 7 --SIE4
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_SIE4', @JSON = @JSON

							IF @SourceTypeID = 8 --Navision
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_Navision', @JSON = @JSON

							IF @SourceTypeID = 9 --Axapta
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_Axapta', @JSON = @JSON

							IF @SourceTypeID = 11 --Epicor ERP
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_EpicorERP', @JSON = @JSON
--								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_EpicorERP', @JSON = @JSON

							IF @SourceTypeID = 12 --Enterprise
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_Enterprise', @JSON = @JSON
		--						EXEC spIU_DC_Journal_Enterprise @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Entity_MemberKey = @Entity_MemberKey, @Book = @Book, @FiscalYear = @FiscalYear, @FiscalPeriod = @FiscalPeriod, @Debug = @Debug

							IF @SourceTypeID = 15 --pcSource
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_pcSource', @JSON = @JSON

							IF @DebugBM & 8 > 0 SELECT [SP] = 'spIU_DC_Journal; SequenceBM=1', [Table] = '#Journal', [RowCount] = COUNT(1) FROM #Journal
							
							FETCH NEXT FROM Entity_Cursor INTO @SourceTypeID, @SourceID, @SequenceBM, @Entity_MemberKey, @Book, @FiscalYear, @FiscalPeriodString, @MaxSourceCounter
						END
				CLOSE Entity_Cursor
				DEALLOCATE Entity_Cursor
				IF @DebugBM & 32 > 0 SELECT TempTable = '#Journal', Position = 'AfterCursor, @Called_SequenceBM = 1', [Rows] = COUNT(1) FROM #Journal
			END

	SET @Step = 'Run Entity_Cursor for Opening Balance'
		IF @Called_SequenceBM & 2 > 0
			BEGIN
				INSERT INTO #CursorTable
					(
					SourceTypeID,
					SourceID,
					SequenceBM,
					Entity,
					Book,
					FiscalYear,
					FiscalPeriodString,
					--FullReloadYN,
					MaxSourceCounter
					)
				SELECT DISTINCT
					[SourceTypeID] = EB.[SourceTypeID],
					[SourceID] = EB.[SourceID],
					[SequenceBM] = 2,
					[Entity] = EB.[Entity],
					[Book] = EB.[Book],
					[FiscalYear] = J.[FiscalYear],
					[FiscalPeriodString] = NULL,
					--[FullReloadYN] = 1,
					[MaxSourceCounter] = NULL
				FROM
					#Entity_Book EB
					INNER JOIN #Journal J ON J.[Entity] = EB.[Entity] AND J.[Book] = EB.[Book]
				WHERE
					J.FiscalPeriod = 1 
				ORDER BY
					[SourceTypeID],
					[SourceID],
					[SequenceBM],
					[Entity],
					[Book],
					[FiscalYear],
					[FiscalPeriodString],
					[MaxSourceCounter]

				IF @FullReloadYN <> 0
					BEGIN 
						INSERT INTO #CursorTable
							(
							SourceTypeID,
							SourceID,
							SequenceBM,
							Entity,
							Book,
							FiscalYear,
							FiscalPeriodString,
							--FullReloadYN,
							MaxSourceCounter
							)
						SELECT DISTINCT
							[SourceTypeID] = EB.[SourceTypeID],
							[SourceID] = EB.[SourceID],
							[SequenceBM] = 2,
							[Entity] = EB.[Entity],
							[Book] = EB.[Book],
							[FiscalYear] = FY.[FiscalYear],
							[FiscalPeriodString] = NULL,
							--[FullReloadYN] = 1,
							[MaxSourceCounter] = NULL
						FROM
							#Entity_Book EB
							--INNER JOIN #FiscalYear FY ON 1 = 1
							INNER JOIN #FiscalYear FY ON FY.[FiscalYear] >= EB.[StartFiscalYear] AND (FY.[FiscalYear] > @MasterClosedYear OR @MasterClosedYear IS NULL)
						WHERE
							NOT EXISTS 
							(
								SELECT 1 
								FROM 
									#CursorTable C 
								WHERE 
									C.[SourceTypeID] = EB.[SourceTypeID] AND
									C.[SourceID] = EB.[SourceID] AND
									C.[SequenceBM] = 2 AND
									C.[Entity] = EB.[Entity] AND
									C.[Book] = EB.[Book] AND
									C.[FiscalYear] = FY.[FiscalYear]
								)
					END

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#CursorTable' , * FROM #CursorTable WHERE SequenceBM & 2 > 0

				IF CURSOR_STATUS('global','Entity_Cursor') >= -1 DEALLOCATE Entity_Cursor
				DECLARE Entity_Cursor CURSOR FOR
					SELECT DISTINCT
						[SourceTypeID],
						[SourceID],
						[SequenceBM],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriodString],
						--[FullReloadYN] = 1,
						[MaxSourceCounter]
					FROM
						#CursorTable
					WHERE
						[SequenceBM] = 2
					ORDER BY
						[SourceTypeID],
						[SourceID],
						[SequenceBM],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriodString],
						[MaxSourceCounter]

					OPEN Entity_Cursor
					FETCH NEXT FROM Entity_Cursor INTO @SourceTypeID, @SourceID, @SequenceBM, @Entity_MemberKey, @Book, @FiscalYear, @FiscalPeriodString, @MaxSourceCounter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0
								SELECT 
									[@UserID] = @UserID,
									[@InstanceID] = @InstanceID,
									[@VersionID] = @VersionID,
									[@SequenceBM] = @SequenceBM,
									[@JournalTable] = @JournalTable,
									[@JobID] = @JobID,
									[@DebugSub] = @DebugSub,
									[@SourceTypeID] = @SourceTypeID,
									[@SourceID] = @SourceID,
									[@MaxSourceCounter] = @MaxSourceCounter,
									[@Entity_MemberKey] = @Entity_MemberKey,
									[@Book] = @Book,
									[@FiscalYear] = @FiscalYear,
									[@FiscalPeriodString] = @FiscalPeriodString

							SET @JSON = '
								[
								{"TKey" : "UserID",  "TValue": "' + CONVERT(NVARCHAR(10), @UserID) + '"},
								{"TKey" : "InstanceID",  "TValue": "' + CONVERT(NVARCHAR(10), @InstanceID) + '"},
								{"TKey" : "VersionID",  "TValue": "' + CONVERT(NVARCHAR(10), @VersionID) + '"},
								{"TKey" : "SequenceBM",  "TValue": "' + CONVERT(NVARCHAR(10), @SequenceBM) + '"},
								{"TKey" : "JournalTable",  "TValue": "' + @JournalTable + '"},
								{"TKey" : "JobID",  "TValue": "' + CONVERT(NVARCHAR(10), @JobID) + '"},
								{"TKey" : "Debug",  "TValue": "' + CONVERT(NVARCHAR(10), @DebugSub) + '"},
								{"TKey" : "FullReloadYN",  "TValue": "1"}'
								+ CASE WHEN @SourceTypeID IN (1, 5, 11) AND @SourceID IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "SourceID",  "TValue": "' + CONVERT(nvarchar(10), @SourceID) + '"}' ELSE '' END +
								+ CASE WHEN @Entity_MemberKey IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity_MemberKey + '"}' END +
								+ CASE WHEN @Book IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "Book",  "TValue": "' + @Book + '"}' END +
								+ CASE WHEN @StartFiscalYear IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "StartFiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @StartFiscalYear) + '"}' END +
								+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @FiscalYear) + '"}' END +
								+ CASE WHEN @FiscalPeriodString IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "' + CASE WHEN @SourceTypeID IN (1, 11) THEN 'FiscalPeriodString' ELSE 'FiscalPeriod' END + '",  "TValue": "' + @FiscalPeriodString + '"}' END +
								+ CASE WHEN @OB_ERP_InsertYN IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "OB_ERP_InsertYN",  "TValue": "' + CONVERT(nvarchar(10), @OB_ERP_InsertYN) + '"}' END +
								+ CASE WHEN @MaxSourceCounter IS NULL OR @SourceTypeID NOT IN (1, 3, 11) THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "MaxSourceCounter",  "TValue": "' + CONVERT(nvarchar(20), @MaxSourceCounter) + '"}' END +
								']'

							IF @DebugBM & 2 > 0 PRINT @JSON

							IF @SourceTypeID = 1 --Epicor ERP
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_EpicorERP', @JSON = @JSON

							IF @SourceTypeID = 3 --iScala
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_iScala', @JSON = @JSON
					
							IF @SourceTypeID = 5 --P21
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_P21', @JSON = @JSON
					
							IF @SourceTypeID = 7 --SIE4
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_SIE4', @JSON = @JSON

							IF @SourceTypeID = 8 --Navision
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_Navision', @JSON = @JSON

							IF @SourceTypeID = 9 --Axapta
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_Axapta', @JSON = @JSON

							IF @SourceTypeID = 11 --Epicor ERP
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_EpicorERP', @JSON = @JSON

							IF @SourceTypeID = 12 --Enterprise
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_Enterprise', @JSON = @JSON
		--						EXEC spIU_DC_Journal_Enterprise @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Entity_MemberKey = @Entity_MemberKey, @Book = @Book, @FiscalYear = @FiscalYear, @FiscalPeriod = @FiscalPeriod, @Debug = @Debug

							IF @SourceTypeID = 15 --pcSource
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_pcSource', @JSON = @JSON
						
							IF @DebugBM & 8 > 0 SELECT [SP] = 'spIU_DC_Journal; SequenceBM=2', [Table] = '#Journal', [RowCount] = COUNT(1) FROM #Journal

							FETCH NEXT FROM Entity_Cursor INTO @SourceTypeID, @SourceID, @SequenceBM, @Entity_MemberKey, @Book, @FiscalYear, @FiscalPeriodString, @MaxSourceCounter
						END
				CLOSE Entity_Cursor
				DEALLOCATE Entity_Cursor
			END	

	SET @Step = 'Run Entity_Cursor for Budget transactions'
		IF @Called_SequenceBM & 4 > 0
			BEGIN
				TRUNCATE TABLE #FiscalYear

				SET @SQLStatement = '
					INSERT INTO #FiscalYear
						(
						[FiscalYear]
						)
					SELECT 
						[FiscalYear] = [MemberId]
					FROM	
						[' + @CallistoDatabase + '].[dbo].[S_DS_TimeFiscalYear]
					WHERE
						' + CASE WHEN @Called_FiscalYear IS NULL THEN '[MemberId] BETWEEN YEAR(GetDate()) AND YEAR(GetDate()) + 10' ELSE '[MemberID] = ' + CONVERT(nvarchar(15), @Called_FiscalYear) END + '
						' + CASE WHEN @MasterClosedYear IS NULL THEN '' ELSE 'AND [MemberID] > ' + CONVERT(nvarchar(15), @MasterClosedYear) END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
		
				IF CURSOR_STATUS('global','Entity_Cursor') >= -1 DEALLOCATE Entity_Cursor
				DECLARE Entity_Cursor CURSOR FOR
					SELECT DISTINCT
						[SourceTypeID] = EB.[SourceTypeID],
						[SourceID] = EB.[SourceID],
						[SequenceBM] = 4,
						[Entity] = EB.[Entity],
						[Book] = EB.[Book],
						[FiscalYear] = FY.[FiscalYear],
						[FiscalPeriodString] = NULL,
						--[FullReloadYN] = 1,
						[MaxSourceCounter] = NULL
					FROM
						#Entity_Book EB
						INNER JOIN
							(
							SELECT DISTINCT
								Entity = E.MemberKey
							FROM
								[pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.EntityID = EPV.EntityID
							WHERE
								EPV.InstanceID = @InstanceID AND
								EPV.VersionID = @VersionID AND
								EPV.EntityPropertyTypeID = -7 AND
								EPV.SelectYN <> 0
							) B ON B.[Entity] = EB.[Entity]
						INNER JOIN #FiscalYear FY ON 1 = 1
					ORDER BY
						[SourceTypeID],
						[SourceID],
						[SequenceBM],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriodString],
						[MaxSourceCounter]

					OPEN Entity_Cursor
					FETCH NEXT FROM Entity_Cursor INTO @SourceTypeID, @SourceID, @SequenceBM, @Entity_MemberKey, @Book, @FiscalYear, @FiscalPeriodString, @MaxSourceCounter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0
								SELECT 
									[@UserID] = @UserID,
									[@InstanceID] = @InstanceID,
									[@VersionID] = @VersionID,
									[@SequenceBM] = @SequenceBM,
									[@JournalTable] = @JournalTable,
									[@JobID] = @JobID,
									[@DebugSub] = @DebugSub,
									[@SourceTypeID] = @SourceTypeID,
									[@SourceID] = @SourceID,
									[@MaxSourceCounter] = @MaxSourceCounter,
									[@Entity_MemberKey] = @Entity_MemberKey,
									[@Book] = @Book,
									[@FiscalYear] = @FiscalYear,
									[@FiscalPeriodString] = @FiscalPeriodString

							SET @JSON = '
								[
								{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
								{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
								{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
								{"TKey" : "SequenceBM",  "TValue": "' + CONVERT(nvarchar(10), @SequenceBM) + '"},
								{"TKey" : "JournalTable",  "TValue": "' + @JournalTable + '"},
								{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
								{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"},
								{"TKey" : "FullReloadYN",  "TValue": "1"}'
								+ CASE WHEN @SourceTypeID IN (1, 5, 11) AND @SourceID IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "SourceID",  "TValue": "' + CONVERT(nvarchar(10), @SourceID) + '"}' ELSE '' END +
								+ CASE WHEN @Entity_MemberKey IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity_MemberKey + '"}' END +
								+ CASE WHEN @Book IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "Book",  "TValue": "' + @Book + '"}' END +
								+ CASE WHEN @StartFiscalYear IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "StartFiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @StartFiscalYear) + '"}' END +
								+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @FiscalYear) + '"}' END +
								+ CASE WHEN @FiscalPeriodString IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "' + CASE WHEN @SourceTypeID IN (1, 11) THEN 'FiscalPeriodString' ELSE 'FiscalPeriod' END + '",  "TValue": "' + @FiscalPeriodString + '"}' END +
								+ CASE WHEN @MaxSourceCounter IS NULL OR @SourceTypeID NOT IN (1, 3, 11) THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "MaxSourceCounter",  "TValue": "' + CONVERT(nvarchar(20), @MaxSourceCounter) + '"}' END +
								']'

							IF @DebugBM & 2 > 0 PRINT @JSON

							IF @SourceTypeID = 1 --Epicor ERP
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_EpicorERP', @JSON = @JSON

							IF @SourceTypeID = 3 --iScala
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_iScala', @JSON = @JSON
					
							IF @SourceTypeID = 5 --P21
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_P21', @JSON = @JSON
					
							IF @SourceTypeID = 7 --SIE4
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_SIE4', @JSON = @JSON

							IF @SourceTypeID = 8 --Navision
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_Navision', @JSON = @JSON

							IF @SourceTypeID = 9 --Axapta
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_Axapta', @JSON = @JSON

							IF @SourceTypeID = 11 --Epicor ERP
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_EpicorERP', @JSON = @JSON

							IF @SourceTypeID = 12 --Enterprise
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_Enterprise', @JSON = @JSON
		--						EXEC spIU_DC_Journal_Enterprise @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Entity_MemberKey = @Entity_MemberKey, @Book = @Book, @FiscalYear = @FiscalYear, @FiscalPeriod = @FiscalPeriod, @Debug = @Debug

							IF @SourceTypeID = 15 --pcSource
								EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Journal_pcSource', @JSON = @JSON
							
							IF @DebugBM & 8 > 0 SELECT [SP] = 'spIU_DC_Journal; SequenceBM=4', [Table] = '#Journal', [RowCount] = COUNT(1) FROM #Journal
							
							FETCH NEXT FROM Entity_Cursor INTO @SourceTypeID, @SourceID, @SequenceBM, @Entity_MemberKey, @Book, @FiscalYear, @FiscalPeriodString, @MaxSourceCounter
						END
				CLOSE Entity_Cursor
				DEALLOCATE Entity_Cursor
			END

	SET @Step = 'Calculate CYNI'
		IF @CyniYN <> 0
			BEGIN		
				TRUNCATE TABLE #Entity_Book_CYNI
				INSERT INTO #Entity_Book_CYNI
					(
					[Entity_MemberKey_CYNI],
					[Book_CYNI],
					[FiscalYear_CYNI],
					[FiscalPeriod_CYNI]
					)
				SELECT DISTINCT
					[Entity_MemberKey_CYNI] = [Entity],
					[Book_CYNI] = [Book],
					[FiscalYear_CYNI] = [FiscalYear],
					[FiscalPeriod_CYNI] = [FiscalPeriod]
				FROM
					#Journal
				WHERE
					[FiscalPeriod] <> 0

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Entity_Book_CYNI', * FROM #Entity_Book_CYNI

				IF CURSOR_STATUS('global','CYNI_Cursor') >= -1 DEALLOCATE CYNI_Cursor
				DECLARE CYNI_Cursor CURSOR FOR
			
					SELECT
						[Entity_MemberKey_CYNI],
						[Book_CYNI],
						[FiscalYear_CYNI],
						[FiscalPeriod_CYNI]
					FROM
						#Entity_Book_CYNI
					ORDER BY
						[Entity_MemberKey_CYNI],
						[Book_CYNI],
						[FiscalYear_CYNI],
						[FiscalPeriod_CYNI]

					OPEN CYNI_Cursor
					FETCH NEXT FROM CYNI_Cursor INTO @Entity_MemberKey_CYNI, @Book_CYNI, @FiscalYear_CYNI, @FiscalPeriod_CYNI

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Entity_MemberKey_CYNI]=@Entity_MemberKey_CYNI, [@Book_CYNI]=@Book_CYNI, [@FiscalYear_CYNI]=@FiscalYear_CYNI, [@FiscalPeriod_CYNI]=@FiscalPeriod_CYNI

							SET @JSON = '
								[
								{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
								{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
								{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
								{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity_MemberKey_CYNI + '"},
								{"TKey" : "Book",  "TValue": "' + @Book_CYNI + '"},
								{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @FiscalYear_CYNI) + '"},
								{"TKey" : "FiscalPeriod",  "TValue": "' + CONVERT(nvarchar(10), @FiscalPeriod_CYNI) + '"},
								{"TKey" : "SequenceBM",  "TValue": "2"},
								{"TKey" : "JournalTable",  "TValue": "' + @JournalTable + '"},
								{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"}
								]'

							IF @DebugBM & 32 > 0 SELECT [@ProcedureName] = 'spIU_DC_Journal_CYNI', [@JSON] = @JSON
		
							EXEC [pcINTEGRATOR]..spRun_Procedure_KeyValuePair
								@ProcedureName = 'spIU_DC_Journal_CYNI',
								@JSON = @JSON

							FETCH NEXT FROM CYNI_Cursor INTO @Entity_MemberKey_CYNI, @Book_CYNI, @FiscalYear_CYNI, @FiscalPeriod_CYNI
						END

				CLOSE CYNI_Cursor
				DEALLOCATE CYNI_Cursor
			END
		
/*		
	SET @Step = 'Set Mapping'
		DECLARE Mapping_Cursor CURSOR FOR

			SELECT 
				[Column] = CASE WHEN JSN.SegmentNo = 0 THEN 'Account' ELSE 'Segment' + CASE WHEN JSN.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), JSN.SegmentNo) END,
				DR.MappingTypeID,
				[Entity_MemberKey] = E.MemberKey
			FROM
				[Journal_SegmentNo] JSN 
				INNER JOIN Entity E ON E.InstanceID = JSN.InstanceID AND E.VersionID = JSN.VersionID AND E.EntityID = JSN.EntityID 
				INNER JOIN Dimension_Rule DR ON DR.InstanceID = JSN.InstanceID AND DR.Entity_MemberKey = E.MemberKey AND DR.DimensionID = JSN.DimensionID AND DR.SelectYN <> 0
			WHERE
				JSN.InstanceID = @InstanceID AND
				JSN.VersionID = @VersionID

			OPEN Mapping_Cursor
			FETCH NEXT FROM Mapping_Cursor INTO @Column, @MappingTypeID, @Entity_MemberKey

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						UPDATE #Journal
						SET
							' + @Column + ' = CASE WHEN ' + CONVERT(nvarchar(10), @MappingTypeID) + ' = 1 THEN ''' + @Entity_MemberKey + '_'' ELSE '''' END + ' + @Column + ' + CASE WHEN ' + CONVERT(nvarchar(10), @MappingTypeID) + ' = 2 THEN ''_' + @Entity_MemberKey + ''' ELSE '''' END
						WHERE
							Entity = ''' + @Entity_MemberKey + ''''
					
					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Mapping_Cursor INTO @Column, @MappingTypeID, @Entity_MemberKey
				END

		CLOSE Mapping_Cursor
		DEALLOCATE Mapping_Cursor
*/

	SET @Step = 'Delete already existing rows from [Journal]'
		SET @SQLStatement = '
			DELETE J
			FROM
				' + @JournalTable + ' J
				INNER JOIN 
					(
					SELECT DISTINCT
						[InstanceID],
						[Entity],
						[Book],
						[JournalSequence],
						[FiscalYear],
						[FiscalPeriod]
					FROM
						#Journal
					) DJ ON 
						DJ.[InstanceID] = J.[InstanceID] AND 
						DJ.[Entity] = J.[Entity] AND 
						DJ.[Book] = J.[Book] AND
						(DJ.[JournalSequence] = J.[JournalSequence] OR J.[JournalSequence] = ''OB_ADJ'') AND 
						DJ.[FiscalYear] = J.[FiscalYear] AND 
						DJ.[FiscalPeriod] = J.[FiscalPeriod]
			WHERE 
				J.[TransactionTypeBM] NOT IN (8,32) AND 
				J.[ConsolidationGroup] IS NULL'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Fill Journal table'
		SET @SQLStatement = '
		INSERT INTO ' + @JournalTable + '
			(
			[JobID],
			[InstanceID],
			[Entity],
			[Book],
			[FiscalYear],
			[FiscalPeriod],
			[JournalSequence],
			[JournalNo],
			[JournalLine],
			[YearMonth],
			[TransactionTypeBM],
			[BalanceYN],
			[Account],
			[Segment01],
			[Segment02],
			[Segment03],
			[Segment04],
			[Segment05],
			[Segment06],
			[Segment07],
			[Segment08],
			[Segment09],
			[Segment10],
			[Segment11],
			[Segment12],
			[Segment13],
			[Segment14],
			[Segment15],
			[Segment16],
			[Segment17],
			[Segment18],
			[Segment19],
			[Segment20],
			[JournalDate],
			[TransactionDate],
			[PostedDate],
			[PostedStatus],
			[PostedBy],
			[Source],
			[Scenario],
			[Customer],
			[Supplier],
			[Description_Head],
			[Description_Line],
			[Currency_Book],
			[ValueDebit_Book],
			[ValueCredit_Book],
			[Currency_Group],
			[ValueDebit_Group],
			[ValueCredit_Group],
			[Currency_Transaction],
			[ValueDebit_Transaction],
			[ValueCredit_Transaction],
			[SourceModule],
			[SourceModuleReference],
			[SourceCounter],
			[SourceGUID],
			[Inserted],
			[InsertedBy]
			)
		SELECT
			[JobID],
			[InstanceID],
			[Entity],
			[Book],
			[FiscalYear],
			[FiscalPeriod],
			[JournalSequence],
			[JournalNo],
			[JournalLine],
			[YearMonth],
			[TransactionTypeBM] = ISNULL([TransactionTypeBM], 1),
			[BalanceYN] = ISNULL([BalanceYN], 0),
			[Account],
			[Segment01],
			[Segment02],
			[Segment03],
			[Segment04],
			[Segment05],
			[Segment06],
			[Segment07],
			[Segment08],
			[Segment09],
			[Segment10],
			[Segment11],
			[Segment12],
			[Segment13],
			[Segment14],
			[Segment15],
			[Segment16],
			[Segment17],
			[Segment18],
			[Segment19],
			[Segment20],
			[JournalDate],
			[TransactionDate],
			[PostedDate],
			[PostedStatus],
			[PostedBy],
			[Source],
			[Scenario],
			[Customer],
			[Supplier],
			[Description_Head],
			[Description_Line],
			[Currency_Book],
			[ValueDebit_Book],
			[ValueCredit_Book],
			[Currency_Group],
			[ValueDebit_Group],
			[ValueCredit_Group],
			[Currency_Transaction],
			[ValueDebit_Transaction],
			[ValueCredit_Transaction],
			[SourceModule],
			[SourceModuleReference],
			[SourceCounter],
			[SourceGUID],
			[Inserted] = GetDate(),
			[InsertedBy] = suser_name()
		FROM
			#Journal'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Journal
		DROP TABLE #CursorTable
		DROP TABLE #GLJrnDtl_NotBalance

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	SET @Step = 'Set EndTime for the actual job'
		EXEC [pcINTEGRATOR]..[spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	EXEC [pcINTEGRATOR]..[spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
