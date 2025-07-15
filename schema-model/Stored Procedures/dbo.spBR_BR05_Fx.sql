SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_Fx]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@GroupCurrency nchar(3) = NULL,
	@FiscalYear int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
	@ConsolidationGroup nvarchar(50) = NULL, --Optional
	@Level nvarchar(10) = 'Month',
	@MultiplyYN int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000557,
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
EXEC [spBR_BR05_Fx] @UserID=-10, @InstanceID=529, @VersionID=1001, @Debug=1

EXEC [spBR_BR05_Fx] @UserID=-10, @InstanceID=527, @VersionID=1055, @Debug=1

EXEC [spBR_BR05_Fx] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spBR_BR05_Fx] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max) = NULL,
	@FiscalPeriod int,
	@YearMonth int,
	@CalledYN bit = 1,
	@RULE_FXID int,
	@RULE_FXName nvarchar(50),
	@RULE_FXRowID int,
	@JournalSequence nvarchar(50),
	@Action nvarchar(10),
	@FlowFilter nvarchar(100),
	@FlowFilterLeafLevel nvarchar(max),
	@FormulaFX nvarchar(255),
	@HistRateYN bit,
	@Modifier nvarchar(20),
	@StepReference nvarchar(20),
	@JournalTable nvarchar(100),
	@RuleType nvarchar(50),
	@RuleID int,
	@DimensionFilter nvarchar(4000),
	@DimensionFilterLeafLevel nvarchar(max),

	--Hardcoded
	@CTA_PL nvarchar(50) = 'CTA_PL',

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
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Calculate Fx for advanced consolidation',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2152' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Made generic.'
		IF @Version = '2.1.1.2170' SET @Description = 'Removed references to template tables.'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle HistRate. HistRate where FunctionalCurrency = GroupCurrency. Test on updated HistRates.'
		IF @Version = '2.1.1.2172' SET @Description = 'Add Prev2AvgRate. Test on setting Column [Rule_ConsolidationID] when adding rows. Catch BalanceYN from Account dim table. Handle VAR_HistRate.'
		IF @Version = '2.1.1.2177' SET @Description = 'Handle add rows for HistRate.'
		IF @Version = '2.1.1.2179' SET @Description = 'Handle when FXRow.[Account] is empty string as NULL.'
		IF @Version = '2.1.2.2180' SET @Description = 'Handle inverted Fx Rates.'
		IF @Version = '2.1.2.2182' SET @Description = 'Disable Histrate accounts moving down to 0'
		IF @Version = '2.1.2.2183' SET @Description = 'Upgraded version of temp table #FilterTable'
		IF @Version = '2.1.2.2191' SET @Description = 'New structure where HistRate is not used anymore'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY

	-- For testing
	-- SET @Debug = 1

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

		SELECT 
			@HistRateYN = CASE WHEN COUNT(1) > 0 THEN 1 ELSE 0 END
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX] FX
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX_Row] FXR ON FXR.[InstanceID] = FX.InstanceID AND FXR.[VersionID] = FX.VersionID AND FXR.[BusinessRuleID] = FX.[BusinessRuleID] AND FXR.[Rule_FXID] = FX.[Rule_FXID] AND FXR.[SelectYN] <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].[BR05_FormulaFX] FFX ON FFX.[InstanceID] IN (0, @InstanceID) AND FFX.[VersionID] IN (0, @VersionID) AND FFX.[FormulaFXID] = FXR.[FormulaFXID] AND [FormulaFX] LIKE '%HistRate%'
		WHERE
			FX.[InstanceID] = @InstanceID AND
			FX.[VersionID] = @VersionID AND
			(FX.[BusinessRuleID] = @BusinessRuleID OR @BusinessRuleID IS NULL) AND
			FX.[SelectYN] <> 0

		SELECT
			@MultiplyYN = COALESCE(@MultiplyYN, I.[MultiplyYN], 1)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Instance] I
		WHERE
			I.[InstanceID] = @InstanceID

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@HistRateYN] = @HistRateYN,
				[@MultiplyYN] = @MultiplyYN

	SET @Step = 'Update FX_HistRate'
		IF (SELECT MAX([YearMonth]) FROM [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX_HistRate] WHERE InstanceID = @InstanceID AND VersionID = @VersionID) < YEAR(GetDate()) * 100 + MONTH(GetDate())
			BEGIN
				EXEC [spBR_BR05_Fx_HistRate] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @Debug=@DebugSub
			END

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

	SET @Step = 'CREATE TABLE #Fx_Rate'
		CREATE TABLE #Fx_Rate
			(
			[YearMonth] int,
			[FromCurrency] nvarchar(3) COLLATE DATABASE_DEFAULT,
			[ToCurrency] nvarchar(3) COLLATE DATABASE_DEFAULT,
			[OpenRate] float,
			[OpenAvgRate] float,
			[CloseRate] float,
			[AvgRate] float,
			[PrevAvgRate] float,
			[Prev2AvgRate] float,
			[CloseAvgRate] float
			)

	SET @Step = 'Create and fill table #Hist_Rate'
		IF @HistRateYN <> 0
			BEGIN
				CREATE TABLE #Hist_Rate
					(
					[YearMonth] int,
					[FromCurrency] nvarchar(3) COLLATE DATABASE_DEFAULT,
					[ToCurrency] nvarchar(3) COLLATE DATABASE_DEFAULT,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[HistRateChange] float,
					[HistRate] float
					)

				INSERT INTO #Hist_Rate
					(
					[YearMonth],
					[FromCurrency],
					[ToCurrency],
					[Entity],
					[Account],
					[HistRateChange],
					[HistRate]
					)
				SELECT 
					[YearMonth],
					[FromCurrency] = [Currency_Book],
					[ToCurrency] = [Currency_Group],
					[Entity],
					[Account],
					[HistRateChange],
					[HistRate]
				FROM
					pcINTEGRATOR_Data..BR05_Rule_FX_HistRate
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID
			END

	SET @Step = 'CREATE TABLE #Time'
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

		IF @DebugBM & 1 > 0 SELECT [TempTable] = '#Time', * FROM #Time ORDER BY [RowOrder]

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

	SET @Step = '#Fx_Rate'
		SELECT
			[MinYearMonth] = MIN(JB.[YearMonth]),
			[MaxYearMonth] = MAX(JB.[YearMonth]),
			[FromCurrency] = JB.[Currency_Book]
		INTO
			#FromCurrency
		FROM
			#JournalBase JB
		GROUP BY
			JB.[Currency_Book]

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FromCurrency', * FROM #FromCurrency ORDER BY [FromCurrency]

		SET @SQLStatement = '
			INSERT INTO [#Fx_Rate]
				(
				[YearMonth],
				[FromCurrency],
				[ToCurrency],
				[OpenRate],
				[OpenAvgRate],
				[CloseRate],
				[AvgRate],
				[PrevAvgRate],
				[Prev2AvgRate],
				[CloseAvgRate]
				)
			SELECT DISTINCT
				[YearMonth],
				[FromCurrency],
				[ToCurrency],
				[OpenRate],
				[OpenAvgRate],
				[CloseRate],
				[AvgRate],
				[PrevAvgRate],
				[Prev2AvgRate],
				[CloseAvgRate]
			FROM
				(
				SELECT
					[YearMonth] = T0.[YearMonth],
					[FromCurrency] = FxR0.[Currency],
					[ToCurrency] = ''' + @GroupCurrency + ''',
					[OpenRate] = MAX(CASE WHEN FxR1.Rate = ''EOP'' THEN FxR1.[FxRate_Value] ELSE 0 END),
					[OpenAvgRate] = MAX(CASE WHEN FxR1.Rate = ''CloseAverage'' THEN FxR1.[FxRate_Value] ELSE 0 END),
					[CloseRate] = MAX(CASE WHEN FxR0.Rate = ''EOP'' THEN FxR0.[FxRate_Value] ELSE 0 END),
					[AvgRate] = MAX(CASE WHEN FxR0.Rate = ''Average'' THEN FxR0.[FxRate_Value] ELSE 0 END),
					[PrevAvgRate] = MAX(CASE WHEN FxR1.Rate = ''Average'' THEN FxR1.[FxRate_Value] ELSE 0 END),
					[Prev2AvgRate] = MAX(CASE WHEN FxR2.Rate = ''Average'' THEN FxR2.[FxRate_Value] ELSE 0 END),
					[CloseAvgRate] = MAX(CASE WHEN FxR0.Rate = ''CloseAverage'' THEN FxR0.[FxRate_Value] ELSE 0 END)
				FROM
					[' + @CallistoDatabase + '].[dbo].[FACT_FxRate_View] FxR0
					INNER JOIN #FromCurrency FC ON FC.[FromCurrency] = FxR0.[Currency]
					INNER JOIN #Time T0 ON CONVERT(nvarchar(15), T0.YearMonth) = FxR0.[Time] AND T0.[YearMonth] BETWEEN FC.[MinYearMonth] AND FC.[MaxYearMonth]
					INNER JOIN #Time T1 ON T1.RowOrder = T0.RowOrder -1
					INNER JOIN #Time T2 ON T2.RowOrder = T0.RowOrder -2
					INNER JOIN [' + @CallistoDatabase + '].[dbo].[FACT_FxRate_View] FxR1 ON FxR1.[Time] = CONVERT(nvarchar(15), T1.YearMonth) AND FxR1.Currency = FxR0.Currency AND FxR1.[Scenario] = FxR0.[Scenario]
					INNER JOIN [' + @CallistoDatabase + '].[dbo].[FACT_FxRate_View] FxR2 ON FxR2.[Time] = CONVERT(nvarchar(15), T2.YearMonth) AND FxR2.Currency = FxR0.Currency AND FxR2.[Scenario] = FxR0.[Scenario]
				WHERE
--					FxR0.Currency <> ''' + @GroupCurrency + ''' AND
					FxR0.[Scenario] = ''' + @Scenario + '''
				GROUP BY
					T0.[YearMonth],
					FxR0.[Currency]
				) sub
			WHERE
				NOT EXISTS (SELECT 1 FROM [#Fx_Rate] FxR WHERE FxR.[YearMonth] = sub.[YearMonth] AND FxR.[FromCurrency] = sub.[FromCurrency])'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF (SELECT COUNT(1) FROM [#Fx_Rate]) = 0
			BEGIN
				INSERT INTO [#Fx_Rate]
					(
					[YearMonth],
					[FromCurrency],
					[ToCurrency],
					[OpenRate],
					[OpenAvgRate],
					[CloseRate],
					[AvgRate],
					[PrevAvgRate],
					[Prev2AvgRate],
					[CloseAvgRate]
					)
				SELECT DISTINCT
					[YearMonth] = T0.[YearMonth],
					[FromCurrency] = @GroupCurrency,
					[ToCurrency] = @GroupCurrency,
					[OpenRate] = 1,
					[OpenAvgRate] = 1,
					[CloseRate] = 1,
					[AvgRate] = 1,
					[PrevAvgRate] = 1,
					[Prev2AvgRate] = 1,
					[CloseAvgRate] = 1
				FROM
					#FromCurrency FC
					INNER JOIN #Time T0 ON T0.[YearMonth] BETWEEN FC.[MinYearMonth] AND FC.[MaxYearMonth]
			END

		IF @MultiplyYN <> 0
			BEGIN
				UPDATE [#Fx_Rate]
				SET
					[OpenRate] = CASE WHEN [OpenRate] <> 0 THEN 1 / [OpenRate] ELSE [OpenRate] END,
					[OpenAvgRate] = CASE WHEN [OpenAvgRate] <> 0 THEN 1 / [OpenAvgRate] ELSE [OpenAvgRate] END,
					[CloseRate] = CASE WHEN [CloseRate] <> 0 THEN 1 / [CloseRate] ELSE [CloseRate] END,
					[AvgRate] = CASE WHEN [AvgRate] <> 0 THEN 1 / [AvgRate] ELSE [AvgRate] END,
					[PrevAvgRate] = CASE WHEN [PrevAvgRate] <> 0 THEN 1 / [PrevAvgRate] ELSE [PrevAvgRate] END,
					[Prev2AvgRate] = CASE WHEN [Prev2AvgRate] <> 0 THEN 1 / [Prev2AvgRate] ELSE [Prev2AvgRate] END,
					[CloseAvgRate] = CASE WHEN [CloseAvgRate] <> 0 THEN 1 / [CloseAvgRate] ELSE [CloseAvgRate] END
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Fx_Rate', [@ConsolidationGroup] = @ConsolidationGroup, * FROM [#Fx_Rate]

	SET @Step = '#RULE_Fx_Cursor_Table'
		CREATE TABLE  #RULE_Fx_Cursor_Table
			(
			[RULE_FXID] int,
			[RULE_FXName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[JournalSequence] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

		INSERT INTO #RULE_Fx_Cursor_Table
			(
			[RULE_FXID],
			[RULE_FXName],
			[JournalSequence],
			[SortOrder]
			)
		SELECT DISTINCT
			[RULE_FXID],
			[RULE_FXName],
			[JournalSequence],
			[SortOrder]
		FROM
			pcINTEGRATOR_Data..BR05_Rule_FX
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID AND
			[SelectYN] <> 0

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 1 > 0 SELECT TempTable = '#RULE_Fx_Cursor_Table', * FROM #RULE_Fx_Cursor_Table ORDER BY SortOrder

	SET @Step = '#FXR'
		CREATE TABLE [#FXR]
			(
			[Rule_FX_RowID] [int],
			[FlowFilter] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[Modifier] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[ResultValueFilter] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[Sign] [int],
			[FormulaFXID] [int],
			[FormulaFX] [nvarchar](255) COLLATE DATABASE_DEFAULT,
			[HistRateYN] bit,
			[Account] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[BalanceYN] bit,
			[Flow] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[NaturalAccountOnlyYN] bit,
			[Action] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'RULE_Fx_Cursor'
		IF CURSOR_STATUS('global','RULE_Fx_Cursor') >= -1 DEALLOCATE RULE_Fx_Cursor
		DECLARE RULE_Fx_Cursor CURSOR FOR
			
			SELECT
				[RULE_FXID],
				[RULE_FXName],
				[JournalSequence]
			FROM
				#RULE_Fx_Cursor_Table
			ORDER BY
				[SortOrder]

			OPEN RULE_Fx_Cursor
			FETCH NEXT FROM RULE_Fx_Cursor INTO @RULE_FXID, @RULE_FXName, @JournalSequence

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@RULE_FXID]=@RULE_FXID, [@RULE_FXName]=@RULE_FXName, [@JournalSequence]=@JournalSequence

					TRUNCATE TABLE [#FXR]
					SET @SQLStatement = '
						INSERT INTO [#FXR]
							(
							[Rule_FX_RowID],
							[FlowFilter],
							[Modifier],
							[ResultValueFilter],
							[Sign],
							[FormulaFXID],
							[FormulaFX],
							[HistRateYN],
							[Account],
							[BalanceYN],
							[Flow],
							[NaturalAccountOnlyYN],
							[Action]
							)
						SELECT
							[Rule_FX_RowID] = FXR.[Rule_FX_RowID],
							[FlowFilter] = ISNULL(''Flow='' + FXR.[FlowFilter],''''),
							[Modifier] = ISNULL(FXR.[Modifier], ''''),
							[ResultValueFilter] = FXR.[ResultValueFilter],
							[Sign] = FXR.[Sign],
							[FormulaFXID] = FXR.[FormulaFXID],
							[FormulaFX] = F.[FormulaFX],
							[HistRateYN] = CASE WHEN CHARINDEX(''HistRate'', F.[FormulaFX]) > 0 THEN 1 ELSE 0 END,
							[Account] = FXR.[Account],
							[BalanceYN] = A.[TimeBalance],
							[Flow] = FXR.[Flow],
							[NaturalAccountOnlyYN] = FXR.[NaturalAccountOnlyYN],
							[Action] = CASE WHEN LEN(ISNULL(FXR.[Account],''''))+LEN(ISNULL(FXR.[Flow],'''')) = 0 THEN ''UPD'' ELSE ''ADD'' END
						FROM
							pcINTEGRATOR_Data..BR05_Rule_FX_Row FXR
							INNER JOIN pcINTEGRATOR..[BR05_FormulaFX] F ON F.FormulaFXID = FXR.[FormulaFXID]
							LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Account] A ON A.[Label] = FXR.[Account]
						WHERE
							FXR.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							FXR.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							FXR.[BusinessRuleID] = ' + CONVERT(nvarchar(15), @BusinessRuleID) + ' AND
							FXR.[RULE_FXID] = ' + CONVERT(nvarchar(15), @RULE_FXID) + ' AND
							FXR.[SelectYN] <> 0'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 	
						SELECT DISTINCT
							TempTable = 'FXR_Cursor_Table',
							[Action],
							[FlowFilter],
							[Modifier],
							[FormulaFX],
							[HistRateYN],
							[RULE_FXRowID] = CASE WHEN [Action] = 'UPD' THEN [Rule_FX_RowID]  ELSE -1 END
						FROM
							#FXR
						ORDER BY
							[Action] DESC,
							[HistRateYN],
							[FormulaFX],
							[FlowFilter],
							[Modifier]
					
					IF CURSOR_STATUS('global','FXR_Cursor') >= -1 DEALLOCATE FXR_Cursor
					DECLARE FXR_Cursor CURSOR FOR
			
						SELECT DISTINCT
							[Action],
							[FlowFilter],
							[Modifier],
							[FormulaFX],
							[HistRateYN],
							[RULE_FXRowID] = CASE WHEN [Action] = 'UPD' THEN [Rule_FX_RowID]  ELSE -1 END
						FROM
							#FXR
						ORDER BY
							[Action] DESC,
							[HistRateYN],
							[FormulaFX],
							[FlowFilter],
							[Modifier]

						OPEN FXR_Cursor
						FETCH NEXT FROM FXR_Cursor INTO @Action, @FlowFilter, @Modifier, @FormulaFX, @HistRateYN, @RULE_FXRowID

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@Action] = @Action, [@FlowFilter] = @FlowFilter, [@Modifier] = @Modifier, [@FormulaFX] = @FormulaFX, [@HistRateYN] = @HistRateYN, [@RULE_FXRowID] = @RULE_FXRowID

								--TRUNCATE TABLE #FilterTable
								SELECT
									@FlowFilterLeafLevel = '',
									@StepReference = 'BR05_FX_' + CONVERT(nvarchar(15), @RULE_FXID) + '_' + CONVERT(nvarchar(15), @RULE_FXRowID)
											
								EXEC pcINTEGRATOR..spGet_FilterTable
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@StepReference = @StepReference,
									@PipeString = @FlowFilter,
									@StorageTypeBM_DataClass = 1, --@StorageTypeBM_DataClass,
									@StorageTypeBM = 4, --@StorageTypeBM,
									@JobID = @JobID,
									@Debug = @DebugSub

								SELECT
									@FlowFilterLeafLevel = @FlowFilterLeafLevel + ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'JB.[Flow] IN (' + LeafLevelFilter + ')'
								FROM
									#FilterTable
								WHERE
									[StepReference] = @StepReference

								IF @DebugBM & 2 > 0 SELECT [@FlowFilterLeafLevel] = @FlowFilterLeafLevel, [@FormulaFX] = @FormulaFX, [@HistRateYN] = @HistRateYN

								IF @Action = 'UPD'
									BEGIN
										IF @HistRateYN = 0
											BEGIN

												IF @Modifier = 'FYTD-1'
													BEGIN
														SET @SQLStatement = '
															UPDATE JB
															SET
																[Currency_Group] = FxR.[ToCurrency],
																[Value_Group] = sub.[Value_Group] * ' + @FormulaFX + ',
																[Description_Line] = [Description_Line] + CONVERT(nvarchar(15), ' + @FormulaFX + '),
																[SourceModuleReference] = ''' + CONVERT(nvarchar(15), @RULE_FXID) + ' - ' + CONVERT(nvarchar(15), @RULE_FXRowID) + ' (FXR)''
															FROM
																#JournalBase JB
																INNER JOIN (
																	SELECT 
																		JB.[InstanceID],
																		JB.[Entity],
																		JB.[Book],
																		JB.[FiscalYear],
																		JB.[FiscalPeriod],
																		JB.[YearMonth],
																		JB.[Account],
																		JB.[Segment01],
																		JB.[Segment02],
																		JB.[Segment03],
																		JB.[Segment04],
																		JB.[Segment05],
																		JB.[Segment06],
																		JB.[Segment07],
																		JB.[Segment08],
																		JB.[Segment09],
																		JB.[Segment10],
																		JB.[Segment11],
																		JB.[Segment12],
																		JB.[Segment13],
																		JB.[Segment14],
																		JB.[Segment15],
																		JB.[Segment16],
																		JB.[Segment17],
																		JB.[Segment18],
																		JB.[Segment19],
																		JB.[Segment20],
																		JB.[Currency_Book]
																		[Value_Group] = SUM(JBPrev.[Value_Book]),
																		[Description_Line] = MAX(CASE WHEN LEN(ISNULL(JB.[Description_Line], '''')) = 0 THEN '''' ELSE JB.[Description_Line] + '', '' END + ''FXRate: '')
																	FROM
																		#JournalBase JB
																		INNER JOIN #JournalBase JBPrev ON
																			JBPrev.[InstanceID] = JB.[InstanceID] AND
																			JBPrev.[Entity] = JB.[Entity] AND
																			JBPrev.[Book] = JB.[Book] AND
																			JBPrev.[FiscalYear] = JB.[FiscalYear] AND
																			JBPrev.[FiscalPeriod] < JB.[FiscalPeriod] AND
																			JBPrev.[Account] = JB.[Account] AND
																			JBPrev.[Segment01] = JB.[Segment01] AND
																			JBPrev.[Segment02] = JB.[Segment02] AND
																			JBPrev.[Segment03] = JB.[Segment03] AND
																			JBPrev.[Segment04] = JB.[Segment04] AND
																			JBPrev.[Segment05] = JB.[Segment05] AND
																			JBPrev.[Segment06] = JB.[Segment06] AND
																			JBPrev.[Segment07] = JB.[Segment07] AND
																			JBPrev.[Segment08] = JB.[Segment08] AND
																			JBPrev.[Segment09] = JB.[Segment09] AND
																			JBPrev.[Segment10] = JB.[Segment10] AND
																			JBPrev.[Segment11] = JB.[Segment11] AND
																			JBPrev.[Segment12] = JB.[Segment12] AND
																			JBPrev.[Segment13] = JB.[Segment13] AND
																			JBPrev.[Segment14] = JB.[Segment14] AND
																			JBPrev.[Segment15] = JB.[Segment15] AND
																			JBPrev.[Segment16] = JB.[Segment16] AND
																			JBPrev.[Segment17] = JB.[Segment17] AND
																			JBPrev.[Segment18] = JB.[Segment18] AND
																			JBPrev.[Segment19] = JB.[Segment19] AND
																			JBPrev.[Segment20] = JB.[Segment20]'

														SET @SQLStatement = @SQLStatement + '
																	WHERE
																		JB.[RULE_FXID] = ' + CONVERT(nvarchar(15), @RULE_FXID) + CASE WHEN LEN(@FlowFilterLeafLevel) > 0 THEN @FlowFilterLeafLevel ELSE '' END + ' AND
																		JB.[Account] NOT IN (''CYNI_B'', ''CYNI_I'')
																	GROUP BY
																		JB.[InstanceID],
																		JB.[Entity],
																		JB.[Book],
																		JB.[FiscalYear],
																		JB.[FiscalPeriod],
																		JB.[YearMonth],
																		JB.[Account],
																		JB.[Segment01],
																		JB.[Segment02],
																		JB.[Segment03],
																		JB.[Segment04],
																		JB.[Segment05],
																		JB.[Segment06],
																		JB.[Segment07],
																		JB.[Segment08],
																		JB.[Segment09],
																		JB.[Segment10],
																		JB.[Segment11],
																		JB.[Segment12],
																		JB.[Segment13],
																		JB.[Segment14],
																		JB.[Segment15],
																		JB.[Segment16],
																		JB.[Segment17],
																		JB.[Segment18],
																		JB.[Segment19],
																		JB.[Segment20],
																		JB.[Currency_Book]
																	) sub ON
																		sub.[InstanceID] = JB.[InstanceID] AND
																		sub.[Entity] = JB.[Entity] AND
																		sub.[Book] = JB.[Book] AND
																		sub.[FiscalYear] = JB.[FiscalYear] AND
																		sub.[FiscalPeriod] < JB.[FiscalPeriod] AND
																		sub.[Account] = JB.[Account] AND
																		sub.[Segment01] = JB.[Segment01] AND
																		sub.[Segment02] = JB.[Segment02] AND
																		sub.[Segment03] = JB.[Segment03] AND
																		sub.[Segment04] = JB.[Segment04] AND
																		sub.[Segment05] = JB.[Segment05] AND
																		sub.[Segment06] = JB.[Segment06] AND
																		sub.[Segment07] = JB.[Segment07] AND
																		sub.[Segment08] = JB.[Segment08] AND
																		sub.[Segment09] = JB.[Segment09] AND
																		sub.[Segment10] = JB.[Segment10] AND
																		sub.[Segment11] = JB.[Segment11] AND
																		sub.[Segment12] = JB.[Segment12] AND
																		sub.[Segment13] = JB.[Segment13] AND
																		sub.[Segment14] = JB.[Segment14] AND
																		sub.[Segment15] = JB.[Segment15] AND
																		sub.[Segment16] = JB.[Segment16] AND
																		sub.[Segment17] = JB.[Segment17] AND
																		sub.[Segment18] = JB.[Segment18] AND
																		sub.[Segment19] = JB.[Segment19] AND
																		sub.[Segment20] = JB.[Segment20]
																INNER JOIN #Fx_Rate FxR ON FxR.YearMonth = sub.YearMonth AND FxR.FromCurrency = sub.Currency_Book
															WHERE
																JB.[RULE_FXID] = ' + CONVERT(nvarchar(15), @RULE_FXID) + CASE WHEN LEN(@FlowFilterLeafLevel) > 0 THEN @FlowFilterLeafLevel ELSE '' END + ' AND
																JB.[Account] NOT IN (''CYNI_B'', ''CYNI_I'')'
													END
												ELSE
													BEGIN
														SET @SQLStatement = '
															UPDATE JB
															SET
																Currency_Group = FxR.ToCurrency,
																Value_Group = JB.Value_Book * ' + @FormulaFX + ',
																[Description_Line] = CASE WHEN LEN(ISNULL(JB.[Description_Line], '''')) = 0 THEN '''' ELSE JB.[Description_Line] + '', '' END + ''FXRate: '' + CONVERT(nvarchar(15), ' + @FormulaFX + '),
																[SourceModuleReference] = ''' + CONVERT(nvarchar(15), @RULE_FXID) + ' - ' + CONVERT(nvarchar(15), @RULE_FXRowID) + ' (FXR)''
															FROM
																#JournalBase JB
																INNER JOIN #Fx_Rate FxR ON FxR.YearMonth = JB.YearMonth AND FxR.FromCurrency = JB.Currency_Book
															WHERE
																JB.[RULE_FXID] = ' + CONVERT(nvarchar(15), @RULE_FXID) + CASE WHEN LEN(@FlowFilterLeafLevel) > 0 THEN @FlowFilterLeafLevel ELSE '' END + ' AND
																JB.[Account] NOT IN (''CYNI_B'', ''CYNI_I'')'
													END
												IF @DebugBM & 2 > 0 
													BEGIN
														IF @Modifier = 'FYTD-1' PRINT '@Modifier = FYTD-1'
														PRINT @SQLStatement
													END
												
												EXEC (@SQLStatement)
											END
										ELSE
											BEGIN 
												--HistRate
												SET @SQLStatement = '
													UPDATE JB
													SET
														Currency_Group = FxR.ToCurrency,
														Value_Group = JB.Value_Book * ' + @FormulaFX + ',
														[Description_Line] = CASE WHEN LEN(ISNULL(JB.[Description_Line], '''')) = 0 THEN '''' ELSE JB.[Description_Line] + '', '' END + ''FXRate: '' + CONVERT(nvarchar(15), ' + @FormulaFX + '),
														[SourceModuleReference] = ''' + CONVERT(nvarchar(15), @RULE_FXID) + ' - ' + CONVERT(nvarchar(15), @RULE_FXRowID) + ' (FXR)''
													FROM
														#JournalBase JB
														INNER JOIN #Fx_Rate FxR ON FxR.YearMonth = JB.YearMonth AND FxR.FromCurrency = JB.Currency_Book
														INNER JOIN #Hist_Rate FxH ON FxH.YearMonth = JB.YearMonth AND FxH.FromCurrency = JB.Currency_Book AND FxH.[Entity] = JB.[Entity] AND FxH.[Account] =JB.[Account]
													WHERE
														JB.[RULE_FXID] = ' + CONVERT(nvarchar(15), @RULE_FXID) + CASE WHEN LEN(@FlowFilterLeafLevel) > 0 THEN @FlowFilterLeafLevel ELSE '' END + '  AND
														JB.[Account] NOT IN (''CYNI_B'', ''CYNI_I'')'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)

												--HistRate where FunctionalCurrency = GroupCurrency
												SET @SQLStatement = '
													UPDATE JB
													SET
														[Currency_Group] = ''' + @GroupCurrency + ''',
														[Value_Group] = JB.[Value_Book],
														[Description_Line] = CASE WHEN LEN(ISNULL(JB.[Description_Line], '''')) = 0 THEN '''' ELSE JB.[Description_Line] + '', '' END + ''FXRate: 1'',
														[SourceModuleReference] = ''' + CONVERT(nvarchar(15), @RULE_FXID) + ' - ' + CONVERT(nvarchar(15), @RULE_FXRowID) + ' (FXR)''
													FROM
														#JournalBase JB
													WHERE
														JB.[Currency_Book] = ''' + @GroupCurrency + ''' AND
														JB.[Currency_Group] IS NULL AND
														JB.[RULE_FXID] = ' + CONVERT(nvarchar(15), @RULE_FXID) + CASE WHEN LEN(@FlowFilterLeafLevel) > 0 THEN @FlowFilterLeafLevel ELSE '' END + '  AND
														JB.[Account] NOT IN (''CYNI_B'', ''CYNI_I'')'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)
											END
									END

								IF @Action = 'ADD'
									BEGIN
										IF @DebugBM & 8 > 0
											BEGIN
												SELECT TempTable = '#Fx_Rate', * FROM #Fx_Rate ORDER BY FromCurrency, YearMonth
												SELECT TempTable = '#FXR', * FROM #FXR
											END

										IF @Modifier = 'FYTD-1'
											BEGIN
												IF @DebugBM & 2 > 0
													BEGIN
														IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_JournalBase', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_JournalBase
														IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_Fx_Rate', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_Fx_Rate
														IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_FXR', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_FXR
														IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_Time', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_Time
														SELECT * INTO pcINTEGRATOR_Log..tmp_JournalBase FROM #JournalBase
														SELECT * INTO pcINTEGRATOR_Log..tmp_Fx_Rate FROM #Fx_Rate
														SELECT * INTO pcINTEGRATOR_Log..tmp_FXR FROM #FXR
														SELECT * INTO pcINTEGRATOR_Log..tmp_Time FROM #Time
													END

												SET @SQLStatement = '
													INSERT INTO #JournalBase
														(
														[ReferenceNo],
														[Rule_ConsolidationID],
														[Rule_FXID],
														[ConsolidationMethodBM],
														[InstanceID],
														[Entity], 
														[Book],
														[FiscalYear],
														[FiscalPeriod],
														[JournalSequence],
														[JournalNo],
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
														[Currency_Group],
														[Value_Group],
														[SourceModule],
														[SourceModuleReference]
														)'
										
												SET @SQLStatement = @SQLStatement + '
													SELECT
														[ReferenceNo] = MAX(JB.[ReferenceNo]),
--														[Rule_ConsolidationID] = MAX(JB.Rule_ConsolidationID),
														[Rule_ConsolidationID] = CASE WHEN ISNULL(CASE WHEN FXRow.[Account] = '''' THEN NULL ELSE FXRow.[Account] END, JB.[Account]) = MAX(JB.[Account]) THEN MAX(JB.Rule_ConsolidationID) ELSE NULL END,
														[Rule_FXID] = MAX(JB.Rule_FXID),
														[ConsolidationMethodBM] = MAX(JB.ConsolidationMethodBM),
														[InstanceID] = JB.InstanceID,
														[Entity] = JB.Entity, 
														[Book] = JB.Book,
														[FiscalYear] = T.FiscalYear,
														[FiscalPeriod] = T.[FiscalPeriod],
														[JournalSequence] = ''' + @JournalSequence + ''',
														[JournalNo] = 300000000 + MAX(JB.[Counter]),
														[YearMonth] = T.[YearMonth],
														[TransactionTypeBM] = CASE WHEN ISNULL(CASE WHEN FXRow.[Account] = '''' THEN NULL ELSE FXRow.[Account] END, JB.[Account]) = MAX(JB.[Account]) THEN 8 ELSE 32 END,
														[BalanceYN] = MAX(CONVERT(int, ISNULL(FXRow.[BalanceYN], JB.[BalanceYN]))),
														[Account] = ISNULL(CASE WHEN FXRow.[Account] = '''' THEN NULL ELSE FXRow.[Account] END, JB.[Account]),
														[Segment01] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment01] ELSE '''' END,
														[Segment02] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment02] ELSE '''' END,
														[Segment03] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment03] ELSE '''' END,
														[Segment04] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment04] ELSE '''' END,
														[Segment05] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment05] ELSE '''' END,
														[Segment06] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment06] ELSE '''' END,
														[Segment07] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment07] ELSE '''' END,
														[Segment08] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment08] ELSE '''' END,
														[Segment09] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment09] ELSE '''' END,
														[Segment10] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment10] ELSE '''' END,
														[Segment11] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment11] ELSE '''' END,
														[Segment12] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment12] ELSE '''' END,
														[Segment13] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment13] ELSE '''' END,
														[Segment14] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment14] ELSE '''' END,
														[Segment15] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment15] ELSE '''' END,
														[Segment16] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment16] ELSE '''' END,
														[Segment17] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment17] ELSE '''' END,
														[Segment18] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment18] ELSE '''' END,
														[Segment19] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment19] ELSE '''' END,
														[Segment20] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment20] ELSE '''' END,
														[TransactionDate] = MAX(JB.[TransactionDate]),
														[PostedDate] = GetDate(),
														[Source] = ''CFX'',
														[Flow] = MAX(ISNULL(FXRow.[Flow], JB.[Flow])),
														[ConsolidationGroup] = MAX(JB.[ConsolidationGroup]),
														[InterCompanyEntity] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[InterCompanyEntity] ELSE '''' END,
														[Scenario] = MAX(JB.[Scenario]),
														[Customer] = MAX(JB.[Customer]),
														[Supplier] = MAX(JB.[Supplier]),
														[Description_Head] = ''CFX rule: ' + @RULE_FXName + '''+ '', Account: '' + MAX(JB.[Account]) + '', Value_Book: '' + CONVERT(nvarchar(15), SUM(JB.[Value_Book])),
														[Description_Line] = MAX(''FXFormula: ' + @FormulaFX + ', FXRate: '' + CONVERT(nvarchar(15), ' + @FormulaFX + ') + '', FlowFilter: '' + ISNULL(FXRow.[FlowFilter], ''NULL'') + '', ResultValueFilter: '' + ISNULL(FXRow.[ResultValueFilter], ''NULL'') + '', Sign: '' + CONVERT(nvarchar(15), FXRow.[Sign])),
														[Currency_Group] = MAX(FxR.ToCurrency),
														[Value_Group] = ROUND(SUM((CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' > 0 AND ISNULL(FXRow.[ResultValueFilter], ''pos'') = ''pos'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END) + (CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' < 0 AND ISNULL(FXRow.[ResultValueFilter], ''neg'') = ''neg'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END)), 4),
														[SourceModule] = ''CFX'',
														[SourceModuleReference] = MAX(''' + CONVERT(nvarchar(15), @RULE_FXID) + ' - '' + CONVERT(nvarchar(15), FXRow.[Rule_FX_RowID]))'
										
												SET @SQLStatement = @SQLStatement + '
													FROM
														#Time T
														INNER JOIN #JournalBase JB ON JB.[FiscalYear] = T.[FiscalYear] AND JB.[FiscalPeriod] < T.[FiscalPeriod] AND JB.[RULE_FXID] = ' + CONVERT(nvarchar(15), @RULE_FXID) + CASE WHEN LEN(@FlowFilterLeafLevel) > 0 THEN @FlowFilterLeafLevel ELSE '' END + ' AND JB.[Account] NOT IN (''CYNI_B'', ''CYNI_I'')
														INNER JOIN #Fx_Rate FxR ON FxR.YearMonth = T.[YearMonth] AND FxR.[FromCurrency] = JB.[Currency_Book]'

												IF @HistRateYN <> 0 SET @SQLStatement = @SQLStatement + '
														INNER JOIN #Hist_Rate FxH ON FxH.[YearMonth] = JB.[YearMonth] AND FxH.[FromCurrency] = JB.[Currency_Book] AND FxH.[Entity] = JB.[Entity] AND FxH.[Account] = JB.[Account]'
										
												SET @SQLStatement = @SQLStatement + '
														INNER JOIN #FXR FXRow ON FXRow.[Action] = ''' + @Action + ''' AND FXRow.[FlowFilter] = ''' + @FlowFilter + ''' AND FXRow.[Modifier] = ''' + @Modifier + ''' AND FXRow.[FormulaFX] = ''' + @FormulaFX + '''
													WHERE
														T.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + '
													GROUP BY
														JB.[InstanceID],
														JB.[Entity], 
														JB.[Book],
														T.[FiscalYear],
														T.[FiscalPeriod],
														T.[YearMonth],
														ISNULL(CASE WHEN FXRow.[Account] = '''' THEN NULL ELSE FXRow.[Account] END, JB.[Account]),
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment01] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment02] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment03] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment04] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment05] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment06] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment07] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment08] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment09] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment10] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment11] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment12] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment13] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment14] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment15] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment16] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment17] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment18] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment19] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment20] ELSE '''' END,
														CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[InterCompanyEntity] ELSE '''' END
													HAVING
														ROUND(SUM((CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' > 0 AND ISNULL(FXRow.[ResultValueFilter], ''pos'') = ''pos'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END) + (CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' < 0 AND ISNULL(FXRow.[ResultValueFilter], ''neg'') = ''neg'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END)), 4) <> 0'
											END

										ELSE
											BEGIN
												SET @SQLStatement = '
													INSERT INTO #JournalBase
														(
														[ReferenceNo],
														[Rule_ConsolidationID],
														[Rule_FXID],
														[ConsolidationMethodBM],
														[InstanceID],
														[Entity], 
														[Book],
														[FiscalYear],
														[FiscalPeriod],
														[JournalSequence],
														[JournalNo],
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
														[Currency_Group],
														[Value_Group],
														[SourceModule],
														[SourceModuleReference]
														)'
										
												SET @SQLStatement = @SQLStatement + '
													SELECT
														[ReferenceNo] = JB.[ReferenceNo],
--														[Rule_ConsolidationID] = JB.[Rule_ConsolidationID],
														[Rule_ConsolidationID] = CASE WHEN FXRow.[Account] IS NULL OR FXRow.[Account] = '''' THEN JB.Rule_ConsolidationID ELSE NULL END,
														[Rule_FXID] = JB.[Rule_FXID],
														[ConsolidationMethodBM] = JB.[ConsolidationMethodBM],
														[InstanceID] = JB.[InstanceID],
														[Entity] = JB.[Entity], 
														[Book] = JB.[Book],
														[FiscalYear] = JB.[FiscalYear],
														[FiscalPeriod] = JB.[FiscalPeriod],
														[JournalSequence] = ''' + @JournalSequence + ''',
														[JournalNo] = 300000000 + JB.[Counter],
														[YearMonth] = JB.[YearMonth],
														[TransactionTypeBM] = CASE WHEN FXRow.[Account] IS NULL OR FXRow.[Account] = '''' THEN 8 ELSE 32 END, --32,
														[BalanceYN] = ISNULL(FXRow.[BalanceYN], JB.[BalanceYN]),
														[Account] = ISNULL(CASE WHEN FXRow.[Account] = '''' THEN NULL ELSE FXRow.[Account] END, JB.[Account]),
														[Segment01] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment01] ELSE '''' END,
														[Segment02] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment02] ELSE '''' END,
														[Segment03] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment03] ELSE '''' END,
														[Segment04] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment04] ELSE '''' END,
														[Segment05] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment05] ELSE '''' END,
														[Segment06] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment06] ELSE '''' END,
														[Segment07] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment07] ELSE '''' END,
														[Segment08] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment08] ELSE '''' END,
														[Segment09] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment09] ELSE '''' END,
														[Segment10] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment10] ELSE '''' END,
														[Segment11] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment11] ELSE '''' END,
														[Segment12] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment12] ELSE '''' END,
														[Segment13] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment13] ELSE '''' END,
														[Segment14] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment14] ELSE '''' END,
														[Segment15] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment15] ELSE '''' END,
														[Segment16] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment16] ELSE '''' END,
														[Segment17] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment17] ELSE '''' END,
														[Segment18] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment18] ELSE '''' END,
														[Segment19] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment19] ELSE '''' END,
														[Segment20] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment20] ELSE '''' END,
														[TransactionDate] = JB.[TransactionDate],
														[PostedDate] = GetDate(),
														[Source] = ''CFX'',
														[Flow] = ISNULL(FXRow.[Flow], JB.[Flow]),
														[ConsolidationGroup] = JB.[ConsolidationGroup],
														[InterCompanyEntity] = CASE WHEN FXRow.[NaturalAccountOnlyYN] = 0 THEN JB.[InterCompanyEntity] ELSE '''' END,
													--	[InterCompanyEntity] = JB.[InterCompanyEntity],
														[Scenario] = JB.[Scenario],
														[Customer] = JB.[Customer],
														[Supplier] = JB.[Supplier],
													--	[Description_Head] = ''CFX rule: ' + @RULE_FXName + ''' + '', Value_Book: '' + CONVERT(nvarchar(15), JB.[Value_Book]) + '', Value_Group: '' + CONVERT(nvarchar(15), ROUND((CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' > 0 AND ISNULL(FXRow.[ResultValueFilter], ''pos'') = ''pos'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END) + (CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' < 0 AND ISNULL(FXRow.[ResultValueFilter], ''neg'') = ''neg'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END), 4)),
														[Description_Head] = ''CFX rule: ' + @RULE_FXName + '''+ '', Account: '' + JB.[Account] + '', Value_Book: '' + CONVERT(nvarchar(15), JB.[Value_Book]) + '', Value_Group: '' + CONVERT(nvarchar(15), ROUND((CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' > 0 AND ISNULL(FXRow.[ResultValueFilter], ''pos'') = ''pos'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END) + (CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' < 0 AND ISNULL(FXRow.[ResultValueFilter], ''neg'') = ''neg'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END), 4)),
														[Description_Line] = ''FXFormula: ' + @FormulaFX + ', FXRate: '' + CONVERT(nvarchar(15), ' + @FormulaFX + ') + '', FlowFilter: '' + ISNULL(FXRow.[FlowFilter], ''NULL'') + '', ResultValueFilter: '' + ISNULL(FXRow.[ResultValueFilter], ''NULL'') + '', Sign: '' + CONVERT(nvarchar(15), FXRow.[Sign]),
														[Currency_Group] = FxR.[ToCurrency],
														[Value_Group] = ROUND((CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' > 0 AND ISNULL(FXRow.[ResultValueFilter], ''pos'') = ''pos'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END) + (CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' < 0 AND ISNULL(FXRow.[ResultValueFilter], ''neg'') = ''neg'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END), 4),
														[SourceModule] = ''CFX'',
														[SourceModuleReference] = ''' + CONVERT(nvarchar(15), @RULE_FXID) + ' - '' + CONVERT(nvarchar(15), FXRow.[Rule_FX_RowID])'
										
												SET @SQLStatement = @SQLStatement + '
													FROM
														#JournalBase JB
														INNER JOIN #Fx_Rate FxR ON FxR.YearMonth = JB.YearMonth AND FxR.FromCurrency = JB.Currency_Book'

												IF @HistRateYN <> 0 SET @SQLStatement = @SQLStatement + '
														INNER JOIN #Hist_Rate FxH ON FxH.[YearMonth] = JB.[YearMonth] AND FxH.[FromCurrency] = JB.[Currency_Book] AND FxH.[Entity] = JB.[Entity] AND FxH.[Account] = JB.[Account]'
										
												SET @SQLStatement = @SQLStatement + '
														INNER JOIN #FXR FXRow ON FXRow.[Action] = ''' + @Action + ''' AND FXRow.[FlowFilter] = ''' + @FlowFilter + ''' AND FXRow.[Modifier] = ''' + @Modifier + ''' AND FXRow.[FormulaFX] = ''' + @FormulaFX + '''
													WHERE
														ROUND((CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' > 0 AND ISNULL(FXRow.[ResultValueFilter], ''pos'') = ''pos'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END) + (CASE WHEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' < 0 AND ISNULL(FXRow.[ResultValueFilter], ''neg'') = ''neg'' THEN JB.[Value_Book] * FXRow.[Sign] * ' + @FormulaFX + ' ELSE 0 END), 4) <> 0 AND
														JB.[RULE_FXID] = ' + CONVERT(nvarchar(15), @RULE_FXID) + CASE WHEN LEN(@FlowFilterLeafLevel) > 0 THEN @FlowFilterLeafLevel ELSE '' END + ' AND
														JB.[Account] NOT IN (''CYNI_B'', ''CYNI_I'')'
											END

										IF @DebugBM & 2 > 0 
											BEGIN
												IF LEN(@SQLStatement) > 4000 
													BEGIN
														PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR05_FX, Add row.'
														EXEC [dbo].[spSet_wrk_Debug]
															@UserID = @UserID,
															@InstanceID = @InstanceID,
															@VersionID = @VersionID,
															@DatabaseName = @DatabaseName,
															@CalledProcedureName = @ProcedureName,
															@Comment = 'BR05_FX, Add row', 
															@SQLStatement = @SQLStatement,
															@JobID = @JobID
													END
												ELSE
													PRINT @SQLStatement
											END
										EXEC (@SQLStatement)
										SET @Selected = @Selected + @@ROWCOUNT
									END
								FETCH NEXT FROM FXR_Cursor INTO @Action, @FlowFilter, @Modifier, @FormulaFX, @HistRateYN, @RULE_FXRowID
							END

						CLOSE FXR_Cursor
						DEALLOCATE FXR_Cursor
					FETCH NEXT FROM RULE_Fx_Cursor INTO @RULE_FXID, @RULE_FXName, @JournalSequence
				END

		CLOSE RULE_Fx_Cursor
		DEALLOCATE RULE_Fx_Cursor	

/*
	--Disable Histrate accounts moving down to 0, 20220713

	SET @Step = 'Handle Histrate accounts moving down to 0'	
		INSERT INTO #JournalBase
			(
			[ReferenceNo],
			[Rule_ConsolidationID],
			[Rule_FXID],
			[ConsolidationMethodBM],
			[InstanceID],
			[Entity], 
			[Book],
			[FiscalYear],
			[FiscalPeriod],
			[JournalSequence],
			[JournalNo],
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
			[Currency_Group],
			[Value_Group],
			[SourceModule],
			[SourceModuleReference]
			)
		SELECT
			[ReferenceNo] = '', --JB.[ReferenceNo],
			[Rule_ConsolidationID] = '', --CASE WHEN FXRow.[Account] IS NULL THEN JB.Rule_ConsolidationID ELSE NULL END,
			[Rule_FXID] = '', --JB.[Rule_FXID],
			[ConsolidationMethodBM] = '', --JB.[ConsolidationMethodBM],
			[InstanceID] = FHR.[InstanceID],
			[Entity] = FHR.[Entity], 
			[Book] = FHR.[Book],
			[FiscalYear] = FHR.[YearMonth] / 100, --FHR.[FiscalYear],
			[FiscalPeriod] = FHR.[YearMonth] % 100, --JB.[FiscalPeriod],
			[JournalSequence] = 'XXX', --''' + @JournalSequence + ''',
			[JournalNo] = '-10', --300000000 + JB.[Counter],
			[YearMonth] = FHR.[YearMonth],
			[TransactionTypeBM] = 8,
			[BalanceYN] = CASE WHEN A.[Account] = 'Same' THEN 1 ELSE 0 END,
			[Account] = CASE WHEN A.[Account] = 'Same' THEN FHR.Account ELSE A.[Account] END,
			[Segment01] = '',
			[Segment02] = '',
			[Segment03] = '',
			[Segment04] = '',
			[Segment05] = '',
			[Segment06] = '',
			[Segment07] = '',
			[Segment08] = '',
			[Segment09] = '',
			[Segment10] = '',
			[Segment11] = '',
			[Segment12] = '',
			[Segment13] = '',
			[Segment14] = '',
			[Segment15] = '',
			[Segment16] = '',
			[Segment17] = '',
			[Segment18] = '',
			[Segment19] = '',
			[Segment20] = '',
			[TransactionDate] = CONVERT(date, DATEADD(d, -1, DATEADD(m, 1, LEFT(FHR.[YearMonth], 4) + '-' + RIGHT(FHR.[YearMonth], 2) + '-01'))),
			[PostedDate] = GetDate(),
			[Source] = 'CFX',
			[Flow] = 'CTA_Flow',
			[ConsolidationGroup] = @ConsolidationGroup,
			[InterCompanyEntity] = '',
			[Scenario] = 'ACTUAL',
			[Customer] = '',
			[Supplier] = '',
			[Description_Head] = 'HistRate Account with closing amount in Functional currency = 0',
			[Description_Line] = '',
			[Currency_Group] = FHR.[Currency_Group],
			[Value_Group] = CASE WHEN A.[Account] = 'Same' THEN -1.0 ELSE 1.0 END * (FHR.[GroupAmount_Open] + FHR.[GroupAmount_Open_Adj] + FHR.[GroupAmount_Flow]),
			[SourceModule] = 'CFX',
			[SourceModuleReference] = 'XXX' --''' + CONVERT(nvarchar(15), @RULE_FXID) + ' - '' + CONVERT(nvarchar(15), FXRow.[Rule_FX_RowID])
		FROM
			pcINTEGRATOR_Data..BR05_Rule_FX_HistRate FHR
			INNER JOIN (SELECT Account = 'Same' UNION SELECT Account = @CTA_PL) A ON 1 = 1
		WHERE
			FHR.[InstanceID] = @InstanceID AND
			FHR.[VersionID] = @VersionID AND
			FHR.[Currency_Group] = @GroupCurrency AND
			FHR.VAR_HistRateYN = 0 AND
			FHR.FunctionalAmount_Open <> 0 AND
			(FHR.FunctionalAmount_Open + FHR.FunctionalAmount_Open_Adj + FHR.FunctionalAmount_Flow) = 0 AND
			(FHR.[YearMonth] / 100 = @FiscalYear OR @FiscalYear IS NULL)
*/
--SELECT TempTable = '#JournalBase', Step = '3', * FROM #JournalBase

	SET @Step = 'Run [spBR_BR05_Fx_Opening]'
		EXEC [dbo].[spBR_BR05_Fx_Opening]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@BusinessRuleID = @BusinessRuleID,
			@CallistoDatabase = @CallistoDatabase,
			@JournalTable = @JournalTable,
			@Currency_Group = @GroupCurrency,
			@FiscalYear = @FiscalYear,
			@Scenario = @Scenario,
			@ConsolidationGroup = @ConsolidationGroup,
			@HistoricYN = 1,
			@JobID = @JobID,
			@Debug = @DebugSub

--SELECT TempTable = '#JournalBase', Step = '4, @HistoricYN = 1', * FROM #JournalBase

	SET @Step = 'Fill temp table #CopyOpen_Rule_Cursor_Table'
		CREATE TABLE #CopyOpen_Rule_Cursor_Table
			(
			[RuleType] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[RuleID] int,
			[DimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

		INSERT INTO #CopyOpen_Rule_Cursor_Table
			(
			[RuleType],
			[RuleID],
			[DimensionFilter],
			[SortOrder]
			)
		SELECT
			[RuleType] = 'Rule_ConsolidationID',
			[RuleID] = Rule_ConsolidationID,
			[DimensionFilter],
			[SortOrder]
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID AND
			[SelectYN] <> 0

		INSERT INTO #CopyOpen_Rule_Cursor_Table
			(
			[RuleType],
			[RuleID],
			[DimensionFilter],
			[SortOrder]
			)
		SELECT
			[RuleType] = 'Rule_FXID',
			[RuleID] = Rule_FXID,
			[DimensionFilter],
			[SortOrder]
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID AND
			[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#CopyOpen_Rule_Cursor_Table', * FROM #CopyOpen_Rule_Cursor_Table ORDER BY [RuleType], [SortOrder]


	SET @Step = 'Set Rule_ConsolidationID and Rule_FXID'
		IF CURSOR_STATUS('global','CopyOpen_Rule_Cursor') >= -1 DEALLOCATE CopyOpen_Rule_Cursor
		DECLARE CopyOpen_Rule_Cursor CURSOR FOR
			
			SELECT
				[RuleType],
				[RuleID],
				[DimensionFilter]
			FROM
				#CopyOpen_Rule_Cursor_Table
			ORDER BY
				[RuleType],
				[SortOrder] DESC

			OPEN CopyOpen_Rule_Cursor
			FETCH NEXT FROM CopyOpen_Rule_Cursor INTO @RuleType, @RuleID, @DimensionFilter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@RuleType]=@RuleType, [@RuleID]=@RuleID, [@DimensionFilter]=@DimensionFilter

					--TRUNCATE TABLE #FilterTable
					SELECT
						@DimensionFilterLeafLevel = '',
						@StepReference = 'BR05_H_' + RIGHT(@RuleType, 4) + '_' + CONVERT(nvarchar(15), @RuleID)
											
					EXEC pcINTEGRATOR..spGet_FilterTable
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@StepReference = @StepReference,
						@PipeString = @DimensionFilter,
						@StorageTypeBM_DataClass = 1, --@StorageTypeBM_DataClass,
						@StorageTypeBM = 4, --@StorageTypeBM,
						@JobID = @JobID,
						@Debug = @DebugSub

					SELECT
						@DimensionFilterLeafLevel = @DimensionFilterLeafLevel + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'JB.[' + DimensionName + '] ' + [EqualityString] + ' (' + LeafLevelFilter + ') AND'
					FROM
						#FilterTable
					WHERE
						[StepReference] = @StepReference

					IF RIGHT(@DimensionFilterLeafLevel, 3) = 'AND'
						SET @DimensionFilterLeafLevel = LEFT(@DimensionFilterLeafLevel, LEN(@DimensionFilterLeafLevel) - 3)
					
					IF @DebugBM & 2 > 0
						BEGIN
							SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = @StepReference
							PRINT @DimensionFilterLeafLevel
						END

					SET @SQLStatement = '
						UPDATE JB
						SET
							[' + @RuleType + '] = ' + CONVERT(nvarchar(15), @RuleID) + '
						FROM
							#JournalBase JB
						WHERE
							[' + @RuleType + '] IS NULL
							' + CASE WHEN LEN(@DimensionFilterLeafLevel) > 0 THEN 'AND ' + @DimensionFilterLeafLevel ELSE '' END

					IF @DebugBM & 2 > 0 
						BEGIN
							IF LEN(@SQLStatement) > 4000 
								BEGIN
									PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR05_FX, Set RuleID.'
									EXEC [dbo].[spSet_wrk_Debug]
										@UserID = @UserID,
										@InstanceID = @InstanceID,
										@VersionID = @VersionID,
										@DatabaseName = @DatabaseName,
										@CalledProcedureName = @ProcedureName,
										@Comment = 'BR05_FX, Set RuleID', 
										@SQLStatement = @SQLStatement,
										@JobID = @JobID
								END
							ELSE
								PRINT @SQLStatement
						END

					EXEC (@SQLStatement)

					FETCH NEXT FROM CopyOpen_Rule_Cursor INTO @RuleType, @RuleID, @DimensionFilter
				END

		CLOSE CopyOpen_Rule_Cursor
		DEALLOCATE CopyOpen_Rule_Cursor

		IF @DebugBM & 8 > 0 SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY InterCompanyEntity, Entity, Book, Account, Segment01, Segment02, Segment03, Segment04, Segment05, FiscalYear, FiscalPeriod, YearMonth


	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #JournalBase
				DROP TABLE #FilterTable
			END
		DROP TABLE [#Fx_Rate]
		DROP TABLE [#FXR]
		DROP TABLE [#RULE_Fx_Cursor_Table]
--		DROP TABLE [#Time]
		
		IF OBJECT_ID(N'TempDB.dbo.#Hist_Rate', N'U') IS NOT NULL DROP TABLE [#Hist_Rate]

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
--	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
