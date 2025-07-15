SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_Fx_Opening_20241120]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@JournalTable nvarchar(100) = NULL,
	@Currency_Group nchar(3) = NULL,
	@FiscalYear int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
	@ConsolidationGroup nvarchar(50) = NULL, --Optional
	--@Level nvarchar(10) = 'Month',
	--@MultiplyYN int = NULL,
	@HistoricYN bit = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000850,
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
EXEC [spBR_BR05_Fx_Opening] @UserID=-10, @InstanceID=529, @VersionID=1001, @Debug=1

EXEC [spBR_BR05_Fx_Opening] @UserID=-10, @InstanceID=527, @VersionID=1055, @Debug=1

EXEC [spBR_BR05_Fx_Opening] @UserID=-10, @InstanceID=572, @VersionID=1080, @FiscalYear = 2019, @HistoricYN = 0, @Debug=1

EXEC [spBR_BR05_Fx_Opening] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

--Temporary test
-- SET @DebugBM = 2

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max) = NULL,
	--@FiscalPeriod int,
	--@YearMonth int,
	@CalledYN bit = 1,
	--@RULE_FXID int,
	--@RULE_FXName nvarchar(50),
	--@RULE_FXRowID int,
	--@JournalSequence nvarchar(50),
	--@Action nvarchar(10),
	--@FlowFilter nvarchar(100),
	--@FlowFilterLeafLevel nvarchar(max),
	--@FormulaFX nvarchar(255),
	--@HistRateYN bit,
	--@Modifier nvarchar(20),
	@StepReference nvarchar(20) = 'HistoricFilter',
	@Level nvarchar(10) = 'Month',
	@SQLFilter nvarchar(max),
	@DimensionFilter nvarchar(4000),
	@JournalFilter nvarchar(4000) = '',
	@JournalBaseFilter nvarchar(4000) = '',
	@RULE_FXID int,
	@Operator nvarchar(1),

	--Hardcoded
--	@CTA_PL nvarchar(50) = 'CTA_PL',

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2190'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Calculate Opening balances',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2190' SET @Description = 'Procedure created.'

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

		IF @CallistoDatabase IS NULL
			SELECT
				@CallistoDatabase = [DestinationDatabase]
			FROM
				pcINTEGRATOR_Data..[Application]
			WHERE
				InstanceID = @InstanceID AND
				VersionID = @VersionID AND
				SelectYN <> 0

		IF @JournalTable IS NULL	
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@JournalTable] = @JournalTable

	SET @Step = 'CREATE TABLE #CountedFiscalPeriods'
		IF OBJECT_ID(N'TempDB.dbo.#Time', N'U') IS NULL
			BEGIN
				CREATE TABLE #Time
					(
					[RowOrder] int,
					[YearMonth] int,
					[FiscalYear] int,
					[FiscalPeriod] int,
					[MemberId] int,
					[Level] nvarchar(10),
					[PrevYearMonth] int
					)

				SET @SQLStatement = '
					INSERT INTO #Time
						(
						[RowOrder],
						[YearMonth],
						[FiscalYear],
						[FiscalPeriod],
						[MemberId],
						[Level]
						)
					SELECT DISTINCT
						[RowOrder],
						[YearMonth] = [TimeYear] * 100 + [TimeMonth],
						[FiscalYear] = [TimeFiscalYear_MemberId],
						[FiscalPeriod] = [TimeFiscalPeriod_MemberId] % 100,
						[MemberId],
						[Level]
					FROM
						' + @CallistoDatabase + '..S_DS_Time D
					WHERE
						D.[Level] = ''' + @Level + '''
					ORDER BY
						RowOrder'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				UPDATE T
				SET
					[PrevYearMonth] = ISNULL(T1.[YearMonth], T.[YearMonth])
				FROM
					#Time T
					LEFT JOIN #Time T1 ON T1.RowOrder = T.RowOrder - 1
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Time', * FROM #Time ORDER BY [RowOrder], [FiscalYear], [FiscalPeriod], [YearMonth]

		SELECT
			[RowOrder],
			[FiscalYear],
			[FiscalPeriod],
			[YearMonth]
		INTO
			#CountedFiscalPeriods
		FROM 
			#Time
		WHERE
			FiscalYear = @FiscalYear OR (FiscalYear = @FiscalYear - 1 AND FiscalPeriod = 12)

		INSERT INTO #CountedFiscalPeriods
			(
			[RowOrder],
			[FiscalYear],
			[FiscalPeriod],
			[YearMonth]
			)
		SELECT
			[RowOrder] = CFP.[RowOrder],
			[FiscalYear] = CFP.[FiscalYear],
			[FiscalPeriod] = FP.FP,
			[YearMonth] = CFP.[YearMonth]
		FROM
			#CountedFiscalPeriods CFP
			INNER JOIN (SELECT FP=13 UNION SELECT FP=14 UNION SELECT FP=15) FP ON 1=1
		WHERE
			[FiscalYear] = @FiscalYear - 1 AND
			[FiscalPeriod] = 12

		INSERT INTO #CountedFiscalPeriods
			(
			[RowOrder],
			[FiscalYear],
			[FiscalPeriod],
			[YearMonth]
			)
		SELECT
			[RowOrder] = MIN ([RowOrder]),
			[FiscalYear] = @FiscalYear,
			[FiscalPeriod] = 0,
			[YearMonth] = MAX([YearMonth])
		FROM
			#CountedFiscalPeriods
		WHERE
			[FiscalYear] = @FiscalYear - 1 OR
			([FiscalYear] = @FiscalYear AND [FiscalPeriod] = 1)


		IF @DebugBM & 2 > 0 SELECT TempTable = '#CountedFiscalPeriods', * FROM #CountedFiscalPeriods ORDER BY [RowOrder]
		
	SET @Step = 'CREATE TABLE #EntityBook'
		IF OBJECT_ID(N'TempDB.dbo.#EntityBook', N'U') IS NULL
			BEGIN
				CREATE TABLE #EntityBook
					(
					[EntityID] int,
					[MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[BookTypeBM] int,
					[Currency] nchar(3),
					[OwnershipConsolidation] float,
					[ConsolidationMethodBM] int,
					[Account_RE] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Account_OCI] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[SelectYN] bit
					)
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#EntityBook', * FROM #EntityBook

	SET @Step = 'CREATE TABLE #JournalBase'
		IF OBJECT_ID(N'TempDB.dbo.#JournalBase', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0
				CREATE TABLE #JournalBase
					(
					[Counter] int IDENTITY(1,1),
					[ReferenceNo] int,
					[Rule_ConsolidationID] int,
					[Rule_FXID] int,
					[ConsolidationMethodBM] int,
					[TranSpecFxRateID] int,
					[TranSpecFxRate] float,
					[InstanceID] int,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT, 
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] int,
					[FiscalPeriod] int,
					[JournalSequence] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[JournalNo] int,
					[JournalLine] int,
					[YearMonth] int,
					[TransactionTypeBM] int,
					[BalanceYN] bit,
					[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment01] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment02] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment03] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment04] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment05] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment06] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment07] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment08] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment09] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment10] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment11] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment12] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment13] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment14] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment15] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment16] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment17] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment18] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment19] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment20] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[JournalDate] date,
					[TransactionDate] date,
					[PostedDate] date,
					[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Flow] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[ConsolidationGroup] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[InterCompanyEntity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Customer] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Supplier] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Description_Head] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[Description_Line] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[Currency_Book] nchar(3) COLLATE DATABASE_DEFAULT,
					[Value_Book] float,
					[Currency_Group] nchar(3) COLLATE DATABASE_DEFAULT,
					[Value_Group] float,
					[Currency_Transaction] nchar(3) COLLATE DATABASE_DEFAULT,
					[Value_Transaction] float,
					[SourceModule] nvarchar(20) COLLATE DATABASE_DEFAULT,
					[SourceModuleReference] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Inserted] datetime DEFAULT getdate()
					)
			END

		IF @DebugBM & 8 > 0 SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY [Rule_FXID], Account, FiscalPeriod

	SET @Step = 'CREATE TABLE #FilterTable'
		IF OBJECT_ID(N'TempDB.dbo.#FilterTable', N'U') IS NULL
			BEGIN
				CREATE TABLE #FilterTable
					(
					[StepReference] nvarchar(20) COLLATE DATABASE_DEFAULT,
					[TupleNo] int,
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[DimensionTypeID] int,
					[StorageTypeBM] int,
					[SortOrder] int,
					[ObjectReference] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[PropertyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[JournalColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
					[Filter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[PropertyFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[Segment] nvarchar(20) COLLATE DATABASE_DEFAULT,
					[Method] nvarchar(20) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Create temp table #HistoricCursor_Table'
		IF @HistoricYN <> 0
			BEGIN
				SELECT 
					Rule_FXID,
					DimensionFilter,
					SortOrder
				INTO
					#HistoricCursor_Table
				FROM
					pcINTEGRATOR_Data..BR05_Rule_FX
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					BusinessRuleID = @BusinessRuleID AND
					HistoricYN <> 0 AND
					SelectYN <> 0
				ORDER BY
					SortOrder

				IF @DebugBM & 2 > 0 SELECT TempTable = '#HistoricCursor_Table', * FROM #HistoricCursor_Table ORDER BY SortOrder
			END

	SET @Step = 'HistoricCursor'
		IF @HistoricYN <> 0
			BEGIN
				IF CURSOR_STATUS('global','HistoricCursor') >= -1 DEALLOCATE HistoricCursor
				DECLARE HistoricCursor CURSOR FOR
			
					SELECT
						[RULE_FXID],
						[DimensionFilter]
					FROM
						#HistoricCursor_Table
					ORDER BY
						[SortOrder]

					OPEN HistoricCursor
					FETCH NEXT FROM HistoricCursor INTO @RULE_FXID, @DimensionFilter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@RULE_FXID]=@RULE_FXID, [@DimensionFilter]=@DimensionFilter
											
							EXEC pcINTEGRATOR..spGet_FilterTable
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepReference = @StepReference,
								@PipeString = @DimensionFilter,
								@StorageTypeBM_DataClass = 2, --@StorageTypeBM_DataClass,
								@StorageTypeBM = 4, --@StorageTypeBM,
								@SQLFilter = @SQLFilter OUT,
								@JobID = @JobID,
								@Debug = @DebugSub

							IF @DebugBM & 2 > 0 SELECT [@SQLFilter]=@SQLFilter

							SELECT @JournalFilter = @JournalFilter + '(' + LTRIM(LEFT(@SQLFilter, LEN(@SQLFilter) - 4)) + ') OR '

							SELECT @JournalBaseFilter = @JournalBaseFilter + CONVERT(nvarchar(15), @RULE_FXID) + ','

							FETCH NEXT FROM HistoricCursor INTO @RULE_FXID, @DimensionFilter
						END

				CLOSE HistoricCursor
				DEALLOCATE HistoricCursor	

				SELECT
					@JournalFilter = '(' + LEFT(@JournalFilter, LEN(@JournalFilter) - 3) + ')',
					@JournalBaseFilter = '[Rule_FXID] IN (' + LEFT(@JournalBaseFilter, LEN(@JournalBaseFilter) - 1) + ')'

				IF @DebugBM & 2 > 0 SELECT [@JournalFilter] = @JournalFilter, [@JournalBaseFilter] = @JournalBaseFilter
			END

	SET @Step = 'Check for Accounts to exclude'
		SELECT DISTINCT
			[Account]
		INTO
			#ExcludedAccounts
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX_Row]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID AND
			[SelectYN] <> 0 AND
			[Account] IS NOT NULL

	SET @Step = 'Calculate FX'
/*
		CREATE TABLE #Selection
			(
			[Scenario_MemberId] bigint,
			[Time_MemberId] bigint
			)

		CREATE TABLE #Currency
			(
			Currency_MemberId bigint,
			Currency_MemberKey nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #FxRate
			(
			[BaseCurrency] nvarchar(10),
			[Currency] nvarchar(10), 
			[BaseCurrency_MemberId] bigint,
			[Currency_MemberId] bigint, 
			[Entity_MemberId] bigint,
			[Rate_MemberId] bigint, 
			[Scenario_MemberId] bigint, 
			[Time_MemberId] bigint,
			[FxRate] float
			)


					INSERT INTO #Selection
						(
						[Scenario_MemberId],
						[Time_MemberId]
						)
					SELECT DISTINCT
						[Scenario_MemberId] = 110,
						[Time_MemberId] = [YearMonth]
					FROM
						#CountedFiscalPeriods
					WHERE
						[FiscalPeriod] = 0

					IF @DebugBM & 2 > 0 SELECT TempTable = '#Selection', * FROM #Selection

					SET @SQLStatement = '
						INSERT INTO #Currency
							(
							Currency_MemberId,
							Currency_MemberKey
							)
						SELECT DISTINCT
							Currency_MemberId = [MemberId],
							Currency_MemberKey = [Label]
						FROM
							' + @JournalTable + ' J
							INNER JOIN ' + @CallistoDatabase + '..S_DS_Currency C ON C.[Label] IN (''' + @Currency_Group + ''', J.[Currency_Book])
						WHERE
							J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
							J.[TransactionTypeBM] & 2 > 0 AND
							J.[Scenario] = ''ACTUAL'''


					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 SELECT TempTable = '#Currency', * FROM #Currency

					EXEC pcINTEGRATOR..spBR_BR04 @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @CalledBy='MasterSP', @Operator=@Operator OUT, @JobID=@JobID, @Debug=@DebugSub

					DELETE #FxRate WHERE [Rate_MemberId] <> 101

					UPDATE FxR
					SET
						[BaseCurrency] = BC.[Currency_MemberKey],
						[Currency] = C.[Currency_MemberKey]
					FROM
						#FxRate FxR
						LEFT JOIN #Currency BC ON BC.Currency_MemberId = FxR.[BaseCurrency_MemberId]
						LEFT JOIN #Currency C ON C.Currency_MemberId = FxR.[Currency_MemberId]

					IF @DebugBM & 2 > 0 SELECT TempTable = '#FxRate', * FROM #FxRate ORDER BY Time_MemberId, Currency_MemberId, Rate_MemberId
*/

	SET @Step = 'Delete already created rows from #JournalBase'
		IF @HistoricYN <> 0
			BEGIN
				SET @SQLStatement = '
					DELETE #JournalBase
					WHERE 
						SourceModule = ''Fx_Opening'' AND
						' + @JournalFilter

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Insert new rows into #JournalBase, Historic'
		IF @HistoricYN <> 0
			BEGIN
				IF @DebugBM & 34 > 0
					BEGIN
						IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_JournalBase', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_JournalBase
						IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_CountedFiscalPeriods', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_CountedFiscalPeriods
						IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_EntityBook', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_EntityBook
						IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_ExcludedAccounts', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_ExcludedAccounts
						SELECT * INTO pcINTEGRATOR_Log..tmp_JournalBase FROM #JournalBase
						SELECT * INTO pcINTEGRATOR_Log..tmp_CountedFiscalPeriods FROM #CountedFiscalPeriods
						SELECT * INTO pcINTEGRATOR_Log..tmp_EntityBook FROM #EntityBook
						SELECT * INTO pcINTEGRATOR_Log..tmp_ExcludedAccounts FROM #ExcludedAccounts
					END			

				SET @SQLStatement = '
					INSERT INTO #JournalBase
						(
						[ReferenceNo],
						[ConsolidationMethodBM],
						[TranSpecFxRateID],
						[TranSpecFxRate],
						[InstanceID],
						[Entity], 
						[Book],
						[FiscalYear],
						[FiscalPeriod],
						[JournalSequence],
						[JournalNo],
						[YearMonth],
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
						[TransactionDate],
						[PostedDate],
						[Source],
						[Flow],
						[ConsolidationGroup],
						[InterCompanyEntity],
						[Scenario],
						[Customer],
						[Supplier],
						[Description_Head],
						[Description_Line],
						[Currency_Book],
						[Value_Book],
						[Currency_Group],
						[Value_Group],
						--[Currency_Transaction],
						--[Value_Transaction],
						[SourceModule],
						[SourceModuleReference]
						)'

				SET @SQLStatement = @SQLStatement + '
					SELECT
						[ReferenceNo] = 13000000 + ROW_NUMBER() OVER(ORDER BY sub.[Entity], sub.[Book], FP2.[FiscalYear], FP2.[FiscalPeriod], sub.[Account]),
						[ConsolidationMethodBM] = MAX(sub.[ConsolidationMethodBM]),
						[TranSpecFxRateID] = NULL,
						[TranSpecFxRate] = NULL,
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[Entity] = sub.[Entity], 
						[Book] = sub.[Book],
						[FiscalYear] = FP2.[FiscalYear],
						[FiscalPeriod] = FP2.[FiscalPeriod],
--						[JournalSequence] = CASE WHEN sub.[JournalSequence] IN (''G_ELIMADJ'', ''G_URPA'', ''G_GROUPADJ'') THEN sub.[JournalSequence] ELSE ''JRNL'' END,
						[JournalSequence] = CASE WHEN sub.[JournalSequence] IN (''G_ELIMADJ'', ''G_URPA'', ''G_GROUPADJ'', ''G_HISTRATEADJ'', ''HISTRATE_ELIM'') THEN sub.[JournalSequence] ELSE ''JRNL'' END,
						[JournalNo] = 23000000 + ROW_NUMBER() OVER(PARTITION BY sub.[Entity], sub.[Book], FP2.[FiscalYear] ORDER BY FP2.[FiscalPeriod]),
						[YearMonth] = FP2.[YearMonth],
						[BalanceYN] = 1,
						[Account] = sub.[Account],
						[Segment01] = sub.[Segment01],
						[Segment02] = sub.[Segment02],
						[Segment03] = sub.[Segment03],
						[Segment04] = sub.[Segment04],
						[Segment05] = sub.[Segment05],
						[Segment06] = sub.[Segment06],
						[Segment07] = sub.[Segment07],
						[Segment08] = sub.[Segment08],
						[Segment09] = sub.[Segment09],
						[Segment10] = sub.[Segment10],
						[Segment11] = sub.[Segment11],
						[Segment12] = sub.[Segment12],
						[Segment13] = sub.[Segment13],
						[Segment14] = sub.[Segment14],
						[Segment15] = sub.[Segment15],
						[Segment16] = sub.[Segment16],
						[Segment17] = sub.[Segment17],
						[Segment18] = sub.[Segment18],
						[Segment19] = sub.[Segment19],
						[Segment20] = sub.[Segment20],
						[TransactionDate] = MAX(CONVERT(date, LEFT(FP2.[YearMonth], 4) + ''-'' + RIGHT(FP2.[YearMonth], 2) + ''-01'')),
						[PostedDate] = GetDate(),
						[Source] = ''Fx_Opening'',
						[Flow] = sub.[Flow],
						[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
						[InterCompanyEntity] = sub.[InterCompanyEntity],
						[Scenario] = ''' + @Scenario + ''',
						[Customer] = '''', --J.[Customer],
						[Supplier] = '''', --J.[Supplier],
						[Description_Head] = ''Fx_Opening'',
						[Description_Line] = '''',
						[Currency_Book] = MAX(sub.[Currency_Book]),
						[Value_Book] = SUM(sub.[Value_Book]),
						[Currency_Group] = ''' + @Currency_Group + ''',
						[Value_Group] = SUM(sub.[Value_Group]),
						--[Currency_Transaction] = J.[Currency_Transaction],
						--[Value_Transaction] = ROUND(CASE WHEN F.[Flow] = ''OP_Opening'' AND FP.[FiscalPeriod] NOT IN (13, 14, 15) THEN SUM(CASE WHEN J.[FiscalPeriod] < FP.[FiscalPeriod] OR J.[FiscalPeriod] = 0 THEN J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction] ELSE 0 END) ELSE SUM(CASE WHEN F.[Flow] <> ''OP_Opening'' AND J.[FiscalPeriod] = FP.[FiscalPeriod] AND J.[FiscalPeriod] <> 0 THEN J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction] ELSE 0 END) END, 4),
						--[Value_Transaction] = SUM(J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction]),
						[SourceModule] = ''Fx_Opening'',
						[SourceModuleReference] = ''''
					FROM'
									
				SET @SQLStatement = @SQLStatement + '
						(
						--Prev year
						SELECT 
							[RowOrder] = FP1.[RowOrder],
							[ConsolidationMethodBM] = EB.[ConsolidationMethodBM],
							[Entity] = J.[Entity],
							[Book] = J.[Book],
							[FiscalYear] = FP1.[FiscalYear],
							[FiscalPeriod] = FP1.[FiscalPeriod],
							[JournalSequence] = J.[JournalSequence],
--Need a parameter			[Account] = CASE WHEN J.[Account] IN (EB.[Account_OCI], ''CYNI_B'') THEN EB.[Account_RE] ELSE J.[Account] END,
							[Account] = CASE WHEN J.[Account] IN (''CYNI_B'') THEN EB.[Account_RE] ELSE J.[Account] END,
							[Segment01] = J.[Segment01],
							[Segment02] = J.[Segment02],
							[Segment03] = J.[Segment03],
							[Segment04] = J.[Segment04],
							[Segment05] = J.[Segment05],
							[Segment06] = J.[Segment06],
							[Segment07] = J.[Segment07],
							[Segment08] = J.[Segment08],
							[Segment09] = J.[Segment09],
							[Segment10] = J.[Segment10],
							[Segment11] = J.[Segment11],
							[Segment12] = J.[Segment12],
							[Segment13] = J.[Segment13],
							[Segment14] = J.[Segment14],
							[Segment15] = J.[Segment15],
							[Segment16] = J.[Segment16],
							[Segment17] = J.[Segment17],
							[Segment18] = J.[Segment18],
							[Segment19] = J.[Segment19],
							[Segment20] = J.[Segment20],
							[Flow] = ''OP_OpenYear'',
							[InterCompanyEntity] = J.[InterCompanyEntity],
							[Currency_Book] = J.[Currency_Book],
							[Value_Book] = [ValueDebit_Book] - [ValueCredit_Book],
							[Value_Group] = [ValueDebit_Group] - [ValueCredit_Group]
						FROM
							' + @JournalTable + ' J
							INNER JOIN #CountedFiscalPeriods FP1 ON FP1.FiscalYear = J.FiscalYear AND FP1.FiscalPeriod = J.FiscalPeriod
							INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[SelectYN] <> 0
						WHERE
							J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear - 1) + ' AND
							J.[TransactionTypeBM] & 8 > 0 AND
--							J.[Account] NOT IN (''CYNI_B'') AND
							CASE WHEN J.[Account] = ''CYNI_B'' AND J.[Source] = ''CRULE'' THEN 0 ELSE 1 END <> 0 AND
							J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''' AND
							J.[Scenario] = ''' + @Scenario + ''' AND
							J.[BalanceYN] <> 0 AND
							J.[JournalSequence] NOT IN (''ELIM'', ''G_ELIMADJ'', ''DIVIDEND'') AND  --, ''G_HISTRATEADJ'', ''HISTRATE_ELIM''
							' + @JournalFilter
								
				SET @SQLStatement = @SQLStatement + '

						--Current year
						UNION ALL SELECT 
							[RowOrder] = FP1.[RowOrder],
							[ConsolidationMethodBM] = EB.[ConsolidationMethodBM],
							[Entity] = J.[Entity],
							[Book] = J.[Book],
							[FiscalYear] = FP1.[FiscalYear],
							[FiscalPeriod] = CASE WHEN FP1.[FiscalPeriod] = 0 THEN 1 ELSE FP1.[FiscalPeriod] END,
							[JournalSequence] = J.[JournalSequence],
							[Account] = J.[Account],
							[Segment01] = J.[Segment01],
							[Segment02] = J.[Segment02],
							[Segment03] = J.[Segment03],
							[Segment04] = J.[Segment04],
							[Segment05] = J.[Segment05],
							[Segment06] = J.[Segment06],
							[Segment07] = J.[Segment07],
							[Segment08] = J.[Segment08],
							[Segment09] = J.[Segment09],
							[Segment10] = J.[Segment10],
							[Segment11] = J.[Segment11],
							[Segment12] = J.[Segment12],
							[Segment13] = J.[Segment13],
							[Segment14] = J.[Segment14],
							[Segment15] = J.[Segment15],
							[Segment16] = J.[Segment16],
							[Segment17] = J.[Segment17],
							[Segment18] = J.[Segment18],
							[Segment19] = J.[Segment19],
							[Segment20] = J.[Segment20],
							[Flow] = ''OP_OpenYTD'',
							[InterCompanyEntity] = J.[InterCompanyEntity],
							[Currency_Book] = J.[Currency_Book],
							[Value_Book] = [Value_Book],
							[Value_Group] = [Value_Group]
						FROM
							#JournalBase J
							INNER JOIN #CountedFiscalPeriods FP1 ON FP1.FiscalYear = J.FiscalYear AND FP1.FiscalPeriod = J.FiscalPeriod
							INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[SelectYN] <> 0
						WHERE
							J.FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
							--J.[TransactionTypeBM] & 8 > 0 AND
							--J.[Account] NOT LIKE ''CTA_%'' AND
							J.ConsolidationGroup = ''' + @ConsolidationGroup + ''' AND
							J.Scenario = ''' + @Scenario + ''' AND
							J.[BalanceYN] <> 0 AND
							(ISNULL(J.[Flow], ''NONE'') NOT IN (''OP_Opening'') OR J.Account = ''PYNI_B'') AND
							' + @JournalFilter + ' AND
							NOT EXISTS (SELECT 1 FROM #ExcludedAccounts EA WHERE EA.[Account] = J.[Account])
						) sub
						INNER JOIN #CountedFiscalPeriods FP2 ON FP2.FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND FP2.[RowOrder] > sub.[RowOrder]
					GROUP BY
						FP2.[FiscalYear],
						FP2.[FiscalPeriod],
						FP2.[YearMonth],
						sub.[Entity],
						sub.[Book],
						sub.[Account],
						CASE WHEN sub.[JournalSequence] IN (''G_ELIMADJ'', ''G_URPA'', ''G_GROUPADJ'', ''G_HISTRATEADJ'', ''HISTRATE_ELIM'') THEN sub.[JournalSequence] ELSE ''JRNL'' END,
						sub.[Segment01],
						sub.[Segment02],
						sub.[Segment03],
						sub.[Segment04],
						sub.[Segment05],
						sub.[Segment06],
						sub.[Segment07],
						sub.[Segment08],
						sub.[Segment09],
						sub.[Segment10],
						sub.[Segment11],
						sub.[Segment12],
						sub.[Segment13],
						sub.[Segment14],
						sub.[Segment15],
						sub.[Segment16],
						sub.[Segment17],
						sub.[Segment18],
						sub.[Segment19],
						sub.[Segment20],
						sub.[Flow],
						sub.[InterCompanyEntity]'

				IF @DebugBM & 34 > 0 
					BEGIN
						IF LEN(@SQLStatement) > 4000 
							BEGIN
								PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR05_Fx_Opening, Historic Accounts.'
								EXEC [dbo].[spSet_wrk_Debug]
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@DatabaseName = @DatabaseName,
									@CalledProcedureName = @ProcedureName,
									@Comment = 'BR05_Fx_Opening, Historic Accounts', 
									@SQLStatement = @SQLStatement,
									@JobID = @JobID
							END
						ELSE
							PRINT @SQLStatement
					END
				EXEC (@SQLStatement)
				SET @Selected = @Selected + @@ROWCOUNT

				IF @DebugBM & 8 > 0 SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY InterCompanyEntity, Entity, Book, Account, Segment01, Segment02, Segment03, Segment04, Segment05, FiscalYear, FiscalPeriod, YearMonth

-- KeHa And JaWo working with PCX fixing....

				SELECT 		[Entity] = J.[Entity],
							[Book] = J.[Book],
							[FiscalYear] = J.[FiscalYear],
							[FiscalPeriod] = J.[FiscalPeriod],
							[JournalSequence] = 'OB_ADJ',
							[Account] = J.Account,
							[Segment01] = J.[Segment01],
							[Segment02] = J.[Segment02],
							[Segment03] = J.[Segment03],
							[Segment04] = J.[Segment04],
							[Segment05] = J.[Segment05],
							[Segment06] = J.[Segment06],
							[Segment07] = J.[Segment07],
							[Segment08] = J.[Segment08],
							[Segment09] = J.[Segment09],
							[Segment10] = J.[Segment10],
							[Segment11] = J.[Segment11],
							[Segment12] = J.[Segment12],
							[Segment13] = J.[Segment13],
							[Segment14] = J.[Segment14],
							[Segment15] = J.[Segment15],
							[Segment16] = J.[Segment16],
							[Segment17] = J.[Segment17],
							[Segment18] = J.[Segment18],
							[Segment19] = J.[Segment19],
							[Segment20] = J.[Segment20],
							[Flow] = 'OP_OpenYear',
							[InterCompanyEntity] = J.[InterCompanyEntity],
							[Currency_Book] = J.[Currency_Book],
							[Value_Book] = SUM([ValueDebit_Book] - [ValueCredit_Book]),
							[Value_Group] = SUM([ValueDebit_Group] - [ValueCredit_Group])
				FROM pcETL_PCX2..Journal J
				Inner Join #EntityBook EB ON EB.MemberKey = J.Entity AND EB.Book = J.Book AND EB.SelectYN <> 0 AND EB.Account_RE = J.Account
				WHERE FiscalYear = @FiscalYear AND FiscalPeriod = '0' AND JournalSequence = 'OB_ERP' AND TransactionTypeBM = 4
				GROUP BY  J.[Entity],
						  J.[Book],
						  J.[FiscalYear],
						  J.[FiscalPeriod],
						  J.[Account],
						  J.[Segment01],
						  J.[Segment02],
						  J.[Segment03],
						  J.[Segment04],
						  J.[Segment05],
						  J.[Segment06],
						  J.[Segment07],
						  J.[Segment08],
						  J.[Segment09],
						  J.[Segment10],
						  J.[Segment11],
						  J.[Segment12],
						  J.[Segment13],
						  J.[Segment14],
						  J.[Segment15],
						  J.[Segment16],
						  J.[Segment17],
						  J.[Segment18],
						  J.[Segment19],
						  J.[Segment20],
						  J.[InterCompanyEntity],
						  J.[Currency_Book]

				SELECT SUM(Value_Book) FROM #JournalBase 
				WHERE Account IN ('3300') AND SourceModule = 'Fx_Opening' AND Flow = 'OP_OpenYear' AND FiscalPeriod = '1'

			END

	SET @Step = 'Insert new rows into #JournalBase, Not historic'
		IF @HistoricYN = 0
			BEGIN
/**
				IF @DebugBM & 34 > 0
					BEGIN
						IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_JournalBase1', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_JournalBase1
						IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_CountedFiscalPeriods1', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_CountedFiscalPeriods1
						IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_EntityBook1', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_EntityBook1
						IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_ExcludedAccounts1', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_ExcludedAccounts1
						SELECT * INTO pcINTEGRATOR_Log..tmp_JournalBase1 FROM #JournalBase
						SELECT * INTO pcINTEGRATOR_Log..tmp_CountedFiscalPeriods1 FROM #CountedFiscalPeriods
						SELECT * INTO pcINTEGRATOR_Log..tmp_EntityBook1 FROM #EntityBook
						SELECT * INTO pcINTEGRATOR_Log..tmp_ExcludedAccounts1 FROM #ExcludedAccounts
					END		
**/
				SET @SQLStatement = '
					INSERT INTO #JournalBase
						(
						[ReferenceNo],
						[ConsolidationMethodBM],
						[TranSpecFxRateID],
						[TranSpecFxRate],
						[InstanceID],
						[Entity], 
						[Book],
						[FiscalYear],
						[FiscalPeriod],
						[JournalSequence],
						[JournalNo],
						[YearMonth],
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
						[TransactionDate],
						[PostedDate],
						[Source],
						[Flow],
						[ConsolidationGroup],
						[InterCompanyEntity],
						[Scenario],
						[Customer],
						[Supplier],
						[Description_Head],
						[Description_Line],
						[Currency_Book],
						[Value_Book],
						[Currency_Group],
						[Value_Group],
						--[Currency_Transaction],
						--[Value_Transaction],
						[SourceModule],
						[SourceModuleReference]
						)'

				SET @SQLStatement = @SQLStatement + '
					SELECT
						[ReferenceNo] = 13000000 + ROW_NUMBER() OVER(ORDER BY sub.[Entity], sub.[Book], FP2.[FiscalYear], FP2.[FiscalPeriod], sub.[Account]),
						[ConsolidationMethodBM] = MAX(sub.[ConsolidationMethodBM]),
						[TranSpecFxRateID] = NULL,
						[TranSpecFxRate] = NULL,
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[Entity] = sub.[Entity], 
						[Book] = sub.[Book],
						[FiscalYear] = FP2.[FiscalYear],
						[FiscalPeriod] = FP2.[FiscalPeriod],
--						[JournalSequence] = CASE WHEN sub.[JournalSequence] IN (''G_ELIMADJ'', ''G_URPA'', ''G_GROUPADJ'') THEN sub.[JournalSequence] ELSE ''JRNL'' END,
						[JournalSequence] = CASE WHEN sub.[JournalSequence] IN (''G_ELIMADJ'', ''G_URPA'', ''G_GROUPADJ'', ''G_HISTRATEADJ'', ''HISTRATE_ELIM'') THEN sub.[JournalSequence] ELSE ''JRNL'' END,
						[JournalNo] = 23000000 + ROW_NUMBER() OVER(PARTITION BY sub.[Entity], sub.[Book], FP2.[FiscalYear] ORDER BY FP2.[FiscalPeriod]),
						[YearMonth] = FP2.[YearMonth],
						[BalanceYN] = 1,
						[Account] = sub.[Account],
						[Segment01] = sub.[Segment01],
						[Segment02] = sub.[Segment02],
						[Segment03] = sub.[Segment03],
						[Segment04] = sub.[Segment04],
						[Segment05] = sub.[Segment05],
						[Segment06] = sub.[Segment06],
						[Segment07] = sub.[Segment07],
						[Segment08] = sub.[Segment08],
						[Segment09] = sub.[Segment09],
						[Segment10] = sub.[Segment10],
						[Segment11] = sub.[Segment11],
						[Segment12] = sub.[Segment12],
						[Segment13] = sub.[Segment13],
						[Segment14] = sub.[Segment14],
						[Segment15] = sub.[Segment15],
						[Segment16] = sub.[Segment16],
						[Segment17] = sub.[Segment17],
						[Segment18] = sub.[Segment18],
						[Segment19] = sub.[Segment19],
						[Segment20] = sub.[Segment20],
						[TransactionDate] = MAX(CONVERT(date, LEFT(FP2.[YearMonth], 4) + ''-'' + RIGHT(FP2.[YearMonth], 2) + ''-01'')),
						[PostedDate] = GetDate(),
						[Source] = ''Fx_Opening'',
						[Flow] = sub.[Flow],
						[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
						[InterCompanyEntity] = sub.[InterCompanyEntity],
						[Scenario] = ''' + @Scenario + ''',
						[Customer] = '''', --J.[Customer],
						[Supplier] = '''', --J.[Supplier],
						[Description_Head] = ''Fx_Opening'',
						[Description_Line] = '''',
						[Currency_Book] = MAX(sub.[Currency_Book]),
						[Value_Book] = SUM(sub.[Value_Book]),
						[Currency_Group] = ''' + @Currency_Group + ''',
						[Value_Group] = SUM(sub.[Value_Group]),
						--[Currency_Transaction] = J.[Currency_Transaction],
						--[Value_Transaction] = ROUND(CASE WHEN F.[Flow] = ''OP_Opening'' AND FP.[FiscalPeriod] NOT IN (13, 14, 15) THEN SUM(CASE WHEN J.[FiscalPeriod] < FP.[FiscalPeriod] OR J.[FiscalPeriod] = 0 THEN J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction] ELSE 0 END) ELSE SUM(CASE WHEN F.[Flow] <> ''OP_Opening'' AND J.[FiscalPeriod] = FP.[FiscalPeriod] AND J.[FiscalPeriod] <> 0 THEN J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction] ELSE 0 END) END, 4),
						--[Value_Transaction] = SUM(J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction]),
						[SourceModule] = ''Fx_Opening'',
						[SourceModuleReference] = ''''
					FROM'
									
				SET @SQLStatement = @SQLStatement + '
						(
						--Prev year
						SELECT 
							[RowOrder] = FP1.[RowOrder],
							[ConsolidationMethodBM] = EB.[ConsolidationMethodBM],
							[Entity] = J.[Entity],
							[Book] = J.[Book],
							[FiscalYear] = FP1.[FiscalYear],
							[FiscalPeriod] = FP1.[FiscalPeriod],
							[JournalSequence] = J.[JournalSequence],
							[Account] = J.[Account],
							[Segment01] = J.[Segment01],
							[Segment02] = J.[Segment02],
							[Segment03] = J.[Segment03],
							[Segment04] = J.[Segment04],
							[Segment05] = J.[Segment05],
							[Segment06] = J.[Segment06],
							[Segment07] = J.[Segment07],
							[Segment08] = J.[Segment08],
							[Segment09] = J.[Segment09],
							[Segment10] = J.[Segment10],
							[Segment11] = J.[Segment11],
							[Segment12] = J.[Segment12],
							[Segment13] = J.[Segment13],
							[Segment14] = J.[Segment14],
							[Segment15] = J.[Segment15],
							[Segment16] = J.[Segment16],
							[Segment17] = J.[Segment17],
							[Segment18] = J.[Segment18],
							[Segment19] = J.[Segment19],
							[Segment20] = J.[Segment20],
							[Flow] = ''OP_OpenYear'',
							[InterCompanyEntity] = J.[InterCompanyEntity],
							[Currency_Book] = J.[Currency_Book],
							[Value_Book] = [ValueDebit_Book] - [ValueCredit_Book],
							[Value_Group] = [ValueDebit_Group] - [ValueCredit_Group]
						FROM
							' + @JournalTable + ' J
							INNER JOIN #CountedFiscalPeriods FP1 ON FP1.FiscalYear = J.FiscalYear AND FP1.FiscalPeriod = J.FiscalPeriod
							INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[SelectYN] <> 0
						WHERE
							J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear - 1) + ' AND
							J.[TransactionTypeBM] & 8 > 0 AND
							J.[Account] NOT IN (''CYNI_B'', EB.[Account_OCI]) AND
							J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''' AND
							J.[Scenario] = ''' + @Scenario + ''' AND
							J.[BalanceYN] <> 0 AND
							J.[JournalSequence] NOT IN (''ELIM'', ''G_ELIMADJ'')'

				SET @SQLStatement = @SQLStatement + '

						--Current year
						UNION ALL SELECT 
							[RowOrder] = FP1.[RowOrder],
							[ConsolidationMethodBM] = EB.[ConsolidationMethodBM],
							[Entity] = J.[Entity],
							[Book] = J.[Book],
							[FiscalYear] = FP1.[FiscalYear],
							[FiscalPeriod] = FP1.[FiscalPeriod],
							[JournalSequence] = J.[JournalSequence],
							[Account] = J.[Account],
							[Segment01] = J.[Segment01],
							[Segment02] = J.[Segment02],
							[Segment03] = J.[Segment03],
							[Segment04] = J.[Segment04],
							[Segment05] = J.[Segment05],
							[Segment06] = J.[Segment06],
							[Segment07] = J.[Segment07],
							[Segment08] = J.[Segment08],
							[Segment09] = J.[Segment09],
							[Segment10] = J.[Segment10],
							[Segment11] = J.[Segment11],
							[Segment12] = J.[Segment12],
							[Segment13] = J.[Segment13],
							[Segment14] = J.[Segment14],
							[Segment15] = J.[Segment15],
							[Segment16] = J.[Segment16],
							[Segment17] = J.[Segment17],
							[Segment18] = J.[Segment18],
							[Segment19] = J.[Segment19],
							[Segment20] = J.[Segment20],
							[Flow] = ''OP_OpenYTD'',
							[InterCompanyEntity] = J.[InterCompanyEntity],
							[Currency_Book] = J.[Currency_Book],
							[Value_Book] = [Value_Book],
							[Value_Group] = [Value_Group]
						FROM
							#JournalBase J
							INNER JOIN #CountedFiscalPeriods FP1 ON FP1.FiscalYear = J.FiscalYear AND FP1.FiscalPeriod = J.FiscalPeriod --AND FP1.FiscalPeriod >= 1
							INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[SelectYN] <> 0
						WHERE
							J.FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
							--J.[TransactionTypeBM] & 8 > 0 AND
							--J.[Account] NOT LIKE ''CTA_%'' AND
							J.ConsolidationGroup = ''' + @ConsolidationGroup + ''' AND
							J.Scenario = ''' + @Scenario + ''' AND
							J.[BalanceYN] <> 0 AND
							(ISNULL(J.[Flow], ''NONE'') NOT IN (''OP_Opening'') OR J.Account = ''PYNI_B'') AND
							NOT EXISTS (SELECT 1 FROM #ExcludedAccounts EA WHERE EA.[Account] = J.[Account])
						) sub
						INNER JOIN #CountedFiscalPeriods FP2 ON FP2.FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND FP2.[RowOrder] > sub.[RowOrder]
					GROUP BY
						FP2.[FiscalYear],
						FP2.[FiscalPeriod],
						FP2.[YearMonth],
						sub.[Entity],
						sub.[Book],
						CASE WHEN sub.[JournalSequence] IN (''G_ELIMADJ'', ''G_URPA'', ''G_GROUPADJ'', ''G_HISTRATEADJ'', ''HISTRATE_ELIM'') THEN sub.[JournalSequence] ELSE ''JRNL'' END,
						sub.[Account],
						sub.[Segment01],
						sub.[Segment02],
						sub.[Segment03],
						sub.[Segment04],
						sub.[Segment05],
						sub.[Segment06],
						sub.[Segment07],
						sub.[Segment08],
						sub.[Segment09],
						sub.[Segment10],
						sub.[Segment11],
						sub.[Segment12],
						sub.[Segment13],
						sub.[Segment14],
						sub.[Segment15],
						sub.[Segment16],
						sub.[Segment17],
						sub.[Segment18],
						sub.[Segment19],
						sub.[Segment20],
						sub.[Flow],
						sub.[InterCompanyEntity]'

				IF @DebugBM & 2 > 0 
					BEGIN
						IF LEN(@SQLStatement) > 4000 
							BEGIN
								PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR05_Fx_Opening, Balance Accounts.'
								EXEC [dbo].[spSet_wrk_Debug]
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@DatabaseName = @DatabaseName,
									@CalledProcedureName = @ProcedureName,
									@Comment = 'BR05_Fx_Opening, Balance Accounts', 
									@SQLStatement = @SQLStatement,
									@JobID = @JobID
							END
						ELSE
							PRINT @SQLStatement
					END
				EXEC (@SQLStatement)
				SET @Selected = @Selected + @@ROWCOUNT
			END

		IF @DebugBM & 8 > 0 SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY InterCompanyEntity, Entity, Book, Account, Segment01, Segment02, Segment03, Segment04, Segment05, FiscalYear, FiscalPeriod, YearMonth

		IF @DebugBM & 64 > 0 SELECT TempTable = '#JournalBase', * FROM #JournalBase WHERE SourceModule = 'Fx_Opening' AND Account = '84248' ORDER BY InterCompanyEntity, Entity, Book, Account, Segment01, Segment02, Segment03, Segment04, Segment05, FiscalYear, FiscalPeriod, YearMonth 

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #JournalBase
				DROP TABLE #FilterTable
			END
		DROP TABLE [#Time]
		
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
