SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_Fx_HistRate_20220922]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ConsolidationGroup nvarchar(50) = NULL, --Mandatory
	@BusinessRuleID int = NULL, --Optional
	@SequenceBM int = 3, --1=Calculate opening, 2=Calculate following
	@Entity nvarchar(50) = NULL, --Optional filter mainly for debugging purposes
	@Book nvarchar(50) = NULL, --Optional filter mainly for debugging purposes
	@Account nvarchar(50) = NULL, --Optional filter mainly for debugging purposes

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000772,
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
EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=529, @VersionID=1001, @Debug=1

EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=527, @VersionID=1055, @SequenceBM = 3, @ConsolidationGroup = 'Group', @Entity = 'GGI02', @Account = '3560', @DebugBM=3

EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=527, @VersionID=1055, @SequenceBM = 3, @DebugBM=3
EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=527, @VersionID=1055, @SequenceBM = 3, @ConsolidationGroup = 'Group', @Entity = 'GGI02', @Account = '3560', @DebugBM=3
EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=527, @VersionID=1055, @SequenceBM = 2, @Entity = 'GGI02', @Account = '1730', @DebugBM=3
EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=527, @VersionID=1055, @SequenceBM = 2, @Entity = 'GGI03', @Account = '3006', @DebugBM=3
EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=527, @VersionID=1055, @SequenceBM = 2, @ConsolidationGroup = 'Group', @Entity = 'GGI03', @Account = '3560', @DebugBM=3
EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=572, @VersionID=1080, @SequenceBM = 1, @ConsolidationGroup = 'G_BRADKEN', @Entity = 'US01', @Account = '6925', @DebugBM=3
EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=572, @VersionID=1080, @SequenceBM = 2, @ConsolidationGroup = 'G_BRADKEN', @Entity = 'CA01', @Account = '5811', @DebugBM=3
EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=572, @VersionID=1080, @SequenceBM = 1, @ConsolidationGroup = 'G_BRADKEN', @DebugBM=3
EXEC [spBR_BR05_Fx_HistRate] @UserID=-10, @InstanceID=572, @VersionID=1080, @SequenceBM = 3, @ConsolidationGroup = 'G_BRADKEN', @DebugBM=3

EXEC [spBR_BR05_Fx_HistRate] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@EntityGroupID int,
	@Currency_Group nvarchar(10),
	@DimensionFilter nvarchar(4000),
	@SQLFilter nvarchar(max),
	@Operator nvarchar(1),
	@JournalTable nvarchar(100),
	@MinYearMonth int,
	@YearMonth int,
	@PrevYearMonth int,
	@FiscalYear int,
	@CalledYN bit = 1,
	@StepReference nvarchar(20) = 'HistRate',

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
	@Version nvarchar(50) = '2.1.2.2183'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Calculate Opening HistRate and HistRate for following periods.',
			@MandatoryParameter = 'ConsolidationGroup' --Without @, separated by |

		IF @Version = '2.1.1.2171' SET @Description = 'Procedure created. Journal into temp table.'
		IF @Version = '2.1.1.2172' SET @Description = 'Possibility to set HistRate manually.'
		IF @Version = '2.1.1.2173' SET @Description = 'Calculate HistRate with no roundings. Do not delete already added rows.'
		IF @Version = '2.1.1.2177' SET @Description = 'Automated setting of [HistRateTypeBM], [VAR_HistRateYN] and some other improvements.'
		IF @Version = '2.1.2.2179' SET @Description = 'Do not change VAR_HistRateYN when already set.'
		IF @Version = '2.1.2.2183' SET @Description = 'Optimized handling of #FilterTable.'

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
				[InstanceID] = @InstanceID AND
				[VersionID] = @VersionID AND
				[SelectYN] <> 0

		SELECT
			@EntityGroupID = E.EntityID,
			@Currency_Group = EB.[Currency]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND EB.[BookTypeBM] & 16 > 0 AND EB.[SelectYN] <> 0
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[MemberKey] = @ConsolidationGroup AND
			E.[EntityTypeID] = 0 AND
			E.[SelectYN] <> 0 AND
			E.[DeletedID] IS NULL

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

	SET @Step = 'Create temp tables'
		CREATE TABLE #HistRate
			(
			[YearMonth] int,
			[HistRateTypeBM] int,
			[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[ConsolidationGroup] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Currency_Book] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[Currency_Book_MemberId] bigint,
			[FunctionalAmount_Open] float,
			[FunctionalAmount_Open_Adj] float DEFAULT 0,
			[FunctionalAmount_Flow] float,
			[Currency_Group] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[Currency_Group_MemberId] bigint,
			[GroupAmount_Open] float,
			[GroupAmount_Open_Adj] float DEFAULT 0,
			[GroupAmount_Flow] float,
			[GroupAmount_Change] float DEFAULT 0,
			[GroupAmount_Jrn_Only] float DEFAULT 0,
			[GroupAmount_Jrn_Open] float DEFAULT 0,
			[GroupAmount_Jrn_Close] float DEFAULT 0,
			[HistRate] float,
			[HistRateChange] float DEFAULT 0,
			[SetHistRate] float,
			[AvgRate] float,
			[VAR_HistRateYN] bit DEFAULT 0
			)

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
			[BaseCurrency_MemberId] bigint,
			[Currency_MemberId] bigint, 
			[Entity_MemberId] bigint,
			[Rate_MemberId] bigint, 
			[Scenario_MemberId] bigint, 
			[Time_MemberId] bigint,
			[FxRate] float
			)

		CREATE TABLE #Journal
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Currency_Book] nchar(3) COLLATE DATABASE_DEFAULT,
			[Currency_Group] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[ConsolidationGroup] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Value_Book] float,
			[Value_Book_Open] float,
			[Value_Group_YearOpen] float,
			[Value_Group_Only] float,
			[Value_Group_Close] float
			)

		CREATE TABLE #ConsolidationGroup
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Currency_Book] nchar(3) COLLATE DATABASE_DEFAULT
			)

		IF OBJECT_ID(N'TempDB.dbo.#FilterTable', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

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

	SET @Step = 'Show variables.'
		EXEC pcINTEGRATOR..spBR_BR04 @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @CalledBy='MasterSP', @Operator=@Operator OUT, @JobID=@JobID, @Debug=@DebugSub

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@JournalTable] = @JournalTable,
				[@ConsolidationGroup] = @ConsolidationGroup,
				[@EntityGroupID] = @EntityGroupID,
				[@Currency_Group] = @Currency_Group,
				[@SequenceBM] = @SequenceBM,
				[@Operator]=@Operator

	SET @Step = 'Fill table #ConsolidationGroup.'
		IF OBJECT_ID(N'TempDB.dbo.#EntityBook', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				INSERT INTO #ConsolidationGroup
					(
					[Entity],
					[Book],
					[Currency_Book]
					)
				SELECT 
					[Entity] = E.[MemberKey],
					[Book] = EB.[Book],
					[Currency_Book] = EB.[Currency]
				FROM
					[pcINTEGRATOR_Data].[dbo].[EntityHierarchy] EH
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON 
						E.[InstanceID] = EH.[InstanceID] AND
						E.[VersionID] = EH.[VersionID] AND
						E.[EntityID] = EH.[EntityID] AND
						E.[EntityTypeID] = -1 AND
						E.[SelectYN] <> 0 AND
						E.[DeletedID] IS NULL AND
						(E.[MemberKey] = @Entity OR @Entity IS NULL)
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON
						EB.[InstanceID] = E.[InstanceID] AND
						EB.[VersionID] = E.[VersionID] AND
						EB.[EntityID] = E.[EntityID] AND
						EB.[BookTypeBM] & 3 = 3 AND
						EB.[SelectYN] <> 0 AND
						(EB.[Book] = @Book OR @Book IS NULL)
				WHERE
					EH.[InstanceID] = @InstanceID AND
					EH.[VersionID] = @VersionID AND
					EH.[EntityGroupID] = @EntityGroupID
			END
		ELSE
			BEGIN
				INSERT INTO #ConsolidationGroup
					(
					[Entity],
					[Book],
					[Currency_Book]
					)
				SELECT 
					[Entity] = EB.[MemberKey],
					[Book] = EB.[Book],
					[Currency_Book] = EB.[Currency]
				FROM
					#EntityBook EB
				WHERE
					EB.[BookTypeBM] & 3 = 3 AND
					EB.[SelectYN] <> 0
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ConsolidationGroup', * FROM #ConsolidationGroup ORDER BY [Entity]

	SET @Step = '@SequenceBM = 1, Create new opening rows.'
		IF @SequenceBM & 1 > 0
			BEGIN
				SET @Step = 'Create and fill table #FiscalYear'
					CREATE TABLE #FiscalYear
						(
						[InstanceID] int,	
						[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[FiscalYear] int,
						[YearMonth] int
						)
		
					SET @SQLStatement = '
						INSERT INTO #FiscalYear
							(
							[InstanceID],	
							[Entity],
							[Book],
							[Account],
							[FiscalYear],
							[YearMonth]
							)		
						SELECT
							[InstanceID] = J.[InstanceID],	
							[Entity] = J.[Entity],
							[Book] = J.[Book],
							[Account] = J.[Account],
							[FiscalYear] = MIN(J.[FiscalYear]),
							[YearMonth] = MIN(J.[YearMonth])
						FROM
							' + @JournalTable + ' J
							INNER JOIN #ConsolidationGroup CG ON CG.[Entity] = J.[Entity] AND CG.[Book] = J.[Book] AND CG.[Currency_Book] = J.[Currency_Book]
						WHERE
							J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							' + CASE WHEN @Account IS NOT NULL THEN 'J.[Account] = ''' + @Account + ''' AND' ELSE '' END + '
							[BalanceYN] <> 0 AND
							[Scenario] = ''ACTUAL''
						GROUP BY
							J.[InstanceID],
							J.[Entity],
							J.[Book],
							J.[Account]'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalYear', * FROM #FiscalYear

				SET @Step = 'AccountFilter_Cursor'
					CREATE TABLE #DimensionFilter_CursorTable
						(
						[FilterCounter] int IDENTITY(1001,1),
						[DimensionFilter] nvarchar(4000)
						)

					INSERT INTO #DimensionFilter_CursorTable
						(
						[DimensionFilter]
						)
					SELECT DISTINCT
						[DimensionFilter] = FX.[DimensionFilter]
					FROM
						[pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX] FX
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX_Row] FXR ON FXR.[InstanceID] = FX.InstanceID AND FXR.[VersionID] = FX.VersionID AND FXR.[BusinessRuleID] = FX.[BusinessRuleID] AND FXR.[Rule_FXID] = FX.[Rule_FXID] AND FXR.[SelectYN] <> 0
						INNER JOIN [pcINTEGRATOR].[dbo].[BR05_FormulaFX] FFX ON FFX.[InstanceID] IN (0, @InstanceID) AND FFX.[VersionID] IN (0, @VersionID) AND FFX.[FormulaFXID] = FXR.[FormulaFXID] AND [FormulaFX] LIKE '%HistRate%'
					WHERE
						FX.[InstanceID] = @InstanceID AND
						FX.[VersionID] = @VersionID AND
						(FX.[BusinessRuleID] = @BusinessRuleID OR @BusinessRuleID IS NULL) AND
						FX.[SelectYN] <> 0

					IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionFilter_CursorTable', * FROM #DimensionFilter_CursorTable ORDER BY [DimensionFilter]

					IF CURSOR_STATUS('global','AccountFilter_Cursor') >= -1 DEALLOCATE AccountFilter_Cursor
					DECLARE AccountFilter_Cursor CURSOR FOR
			
						SELECT
							[DimensionFilter],
							[StepReference] = @StepReference + '_' + CONVERT(nvarchar, [FilterCounter], 15)
						FROM
							#DimensionFilter_CursorTable
						ORDER BY
							[DimensionFilter]

						OPEN AccountFilter_Cursor
						FETCH NEXT FROM AccountFilter_Cursor INTO @DimensionFilter, @StepReference

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@DimensionFilter] = @DimensionFilter

								EXEC pcINTEGRATOR..spGet_FilterTable
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@PipeString = @DimensionFilter,
									@StorageTypeBM_DataClass = 1, --@StorageTypeBM_DataClass,
									@StorageTypeBM = 4, --@StorageTypeBM,
									@SQLFilter = @SQLFilter OUT,
									@StepReference = @StepReference,
									@Debug = 0

								IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable FT WHERE FT.StepReference = @StepReference

								SET @SQLFilter = ''
								SELECT
									@SQLFilter = @SQLFilter + 'J.[' + FT.[DimensionName] + '] IN (' + FT.[LeafLevelFilter] + ') AND '
								FROM
									#FilterTable FT
								WHERE 
									FT.StepReference = @StepReference
								ORDER BY
									FT.DimensionID

								IF @DebugBM & 2 > 0 SELECT [@SQLFilter] = @SQLFilter

								SET @SQLStatement = '
									INSERT INTO #HistRate
										(
										[Entity],
										[Book],
										[Account],
										[ConsolidationGroup],
										[Currency_Book],
										[YearMonth],
										[HistRateTypeBM],
										[FunctionalAmount_Open],
										[FunctionalAmount_Flow],
										[Currency_Group],
										[GroupAmount_Open],
										[SetHistRate]
										)
									SELECT 
										[Entity] = J.[Entity],
										[Book] = J.[Book],
										[Account] = J.[Account],
										[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
										[Currency_Book] = MAX(CG.[Currency_Book]),
										[YearMonth] = MIN(FY.[YearMonth]),
										[HistRateTypeBM] = 1,
										[FunctionalAmount_Open] = 0,
										[FunctionalAmount_Flow] = ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4),
										[Currency_Group] = ''' + @Currency_Group + ''',
										[GroupAmount_Open] = 0,
										[SetHistRate] = MAX(HR.[SetHistRate])
									FROM
										' + @JournalTable + ' J
										INNER JOIN #ConsolidationGroup CG ON CG.[Entity] = J.[Entity] AND CG.[Book] = J.[Book] AND CG.[Currency_Book] = J.[Currency_Book]
										INNER JOIN #FiscalYear FY ON FY.[InstanceID] = J.[InstanceID] AND FY.[Entity] = J.[Entity] AND FY.[Book] = J.[Book] AND FY.[YearMonth] = J.[YearMonth] AND FY.[Account] = J.[Account]
										LEFT JOIN [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX_HistRate] HR ON 
											HR.[InstanceID] = ''' + CONVERT(nvarchar(15), @InstanceID) + ''' AND
											HR.[VersionID] = ''' + CONVERT(nvarchar(15), @VersionID) + ''' AND
											HR.[Account] = J.[Account] AND
											HR.[Entity] = J.[Entity] AND
											HR.[Book] = J.[Book] AND
											HR.[Currency_Group] = ''' + @Currency_Group + ''' AND
											HR.[YearMonth] = FY.[YearMonth]											
									WHERE
										' + ISNULL(@SQLFilter, '') + '
										J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
										J.TransactionTypeBM & 19 > 0 AND
										J.[BalanceYN] <> 0 AND
										J.[Scenario] = ''ACTUAL'' AND
										J.[ConsolidationGroup] IS NULL AND
										J.[Currency_Book] <> ''' + @Currency_Group + ''' AND
										NOT EXISTS (SELECT 1 FROM #HistRate D WHERE D.[Entity] = J.[Entity] AND D.[Account] = J.[Account] AND D.[Currency_Group] = ''' + @Currency_Group + ''')
										' + CASE WHEN @Account IS NOT NULL THEN 'AND J.[Account] = ''' + @Account + '''' ELSE '' END + '
									GROUP BY
										J.[Entity],
										J.[Book],
										J.[Account]'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								FETCH NEXT FROM AccountFilter_Cursor INTO @DimensionFilter, @StepReference
							END

					CLOSE AccountFilter_Cursor
					DEALLOCATE AccountFilter_Cursor

				SET @Step = 'Set Currency_MemberId'
					SET @SQLStatement = '
						UPDATE HR
						SET
							[Currency_Book_MemberId] = C.[MemberId]
						FROM
							#HistRate HR
							INNER JOIN ' + @CallistoDatabase + '..S_DS_Currency C ON C.[Label] = HR.[Currency_Book]'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @SQLStatement = '
						UPDATE HR
						SET
							[Currency_Group_MemberId] = C.[MemberId]
						FROM
							#HistRate HR
							INNER JOIN ' + @CallistoDatabase + '..S_DS_Currency C ON C.[Label] = HR.[Currency_Group]'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 SELECT TempTable='#HistRate', * FROM #HistRate

				SET @Step = 'Calculate FX'
					INSERT INTO #Selection
						(
						[Scenario_MemberId],
						[Time_MemberId]
						)
					SELECT DISTINCT
						[Scenario_MemberId] = 110,
						[Time_MemberId] = [YearMonth]
					FROM
						#HistRate

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
							' + @CallistoDatabase + '..S_DS_Currency C
							INNER JOIN #HistRate SV ON C.[Label] IN (SV.[Currency_Group], SV.[Currency_Book])'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 SELECT TempTable = '#Currency', * FROM #Currency

					EXEC pcINTEGRATOR..spBR_BR04 @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @CalledBy='MasterSP', @Operator=@Operator OUT, @JobID=@JobID, @Debug=@DebugSub

					DELETE #FxRate WHERE [Rate_MemberId] <> 101

					IF @DebugBM & 2 > 0 SELECT TempTable = '#FxRate', * FROM #FxRate ORDER BY Time_MemberId, Currency_MemberId, Rate_MemberId

					UPDATE HR
					SET
						[GroupAmount_Flow] = ROUND(CASE WHEN @Operator = '*' THEN HR.FunctionalAmount_Flow * (FxD.[FxRate] / FxS.[FxRate]) ELSE HR.FunctionalAmount_Flow / (FxD.[FxRate] / FxS.[FxRate]) END, 4),
						[HistRate] = ISNULL(HR.[SetHistRate], CASE WHEN @Operator = '*' THEN FxD.[FxRate] / FxS.[FxRate] ELSE 1 / (FxD.[FxRate] / FxS.[FxRate]) END),
						[HistRateChange] = CASE WHEN HR.[SetHistRate] IS NULL THEN 0 ELSE HR.[SetHistRate] - CASE WHEN @Operator = '*' THEN FxD.[FxRate] / FxS.[FxRate] ELSE 1 / (FxD.[FxRate] / FxS.[FxRate]) END END,
						[AvgRate] = CASE WHEN @Operator = '*' THEN FxD.[FxRate] / FxS.[FxRate] ELSE 1 / (FxD.[FxRate] / FxS.[FxRate]) END
					FROM
						#HistRate HR
						INNER JOIN #FxRate FxD ON 
							FxD.[Currency_MemberId] = HR.[Currency_Group_MemberId] AND 
							FxD.[Rate_MemberId] = 101 AND --Average
							FxD.[Scenario_MemberId] = 110 AND --ACTUAL
							FxD.[Time_MemberId] = HR.[YearMonth]
						INNER JOIN #FxRate FxS ON
							FxS.[Currency_MemberId] = HR.[Currency_Book_MemberId] AND
							FxS.[Rate_MemberId] = FxD.[Rate_MemberId] AND
							FxS.[Scenario_MemberId] = FxD.[Scenario_MemberId] AND
							FxS.[Time_MemberId] = FxD.[Time_MemberId]

					IF @DebugBM & 2 > 0 SELECT TempTable='#HistRate', * FROM #HistRate

				SET @Step = 'Update initial rows in BR05_Rule_FX_HistRate'
					UPDATE HR
					SET
						[FunctionalAmount_Open] = ISNULL(#HR.[FunctionalAmount_Open], 0),
						[FunctionalAmount_Flow] = ISNULL(#HR.[FunctionalAmount_Flow], 0),
						[GroupAmount_Open] = ISNULL(#HR.[GroupAmount_Open], 0),
						[GroupAmount_Flow] = ISNULL(#HR.[GroupAmount_Flow], 0),
						[HistRate] = #HR.[HistRate],
						[HistRateChange] = #HR.[HistRateChange],
						[AvgRate] = #HR.[AvgRate]
					FROM
						pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate HR
						INNER JOIN #HistRate #HR ON
							#HR.[Account] = HR.[Account] AND
							#HR.[Entity] = HR.[Entity] AND
							#HR.[Book] = HR.[Book] AND
							#HR.[Currency_Group] = HR.[Currency_Group] AND
							#HR.[YearMonth] = HR.[YearMonth]	
					WHERE
						HR.[InstanceID] = @InstanceID AND
						HR.[VersionID] = @VersionID
				
				SET @Step = 'Insert new initial rows into BR05_Rule_FX_HistRate'
					INSERT INTO pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate
						(
						[InstanceID],
						[VersionID],
						[Account],
						[Entity],
						[Book],
						[Currency_Group],
						[ConsolidationGroup],
						[YearMonth],
						[HistRateTypeBM],
						[Currency_Book],
						[FunctionalAmount_Open],
						[FunctionalAmount_Flow],
						[GroupAmount_Open],
						[GroupAmount_Flow],
						[HistRate],
						[AvgRate]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[Account],
						[Entity],
						[Book],
						[Currency_Group],
						[ConsolidationGroup],
						[YearMonth],
						[HistRateTypeBM],
						[Currency_Book],
						[FunctionalAmount_Open] = ISNULL([FunctionalAmount_Open], 0),
						[FunctionalAmount_Flow] = ISNULL([FunctionalAmount_Flow], 0),
						[GroupAmount_Open] = ISNULL([GroupAmount_Open], 0),
						[GroupAmount_Flow] = ISNULL([GroupAmount_Flow], 0),
						[HistRate],
						[AvgRate]
					FROM
						#HistRate HR
					WHERE
						NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate D WHERE D.[InstanceID] = @InstanceID AND D.[VersionID] = @VersionID AND D.[Account] = HR.[Account] AND D.[Entity] = HR.[Entity] AND D.[Currency_Group] = HR.[Currency_Group] AND D.[YearMonth] = HR.[YearMonth])

				SET @Step = 'Return all inserted rows from BR05_Rule_FX_HistRate'
					IF @DebugBM & 1 > 0
						SELECT
							[Table] = 'pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate',
							*
						FROM
							pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate
						WHERE
							[InstanceID] = @InstanceID AND
							[VersionID] = @VersionID AND
							([Entity] = @Entity OR @Entity IS NULL) AND
							([Book] = @Book OR @Book IS NULL) AND
							([Account] = @Account OR @Account IS NULL) AND
							([ConsolidationGroup] = @ConsolidationGroup OR @ConsolidationGroup IS NULL) AND
							[HistRateTypeBM] & 1 > 0
						ORDER BY
							[Entity],
							[Book],
							[Account],
							[YearMonth]
			END

	SET @Step = '@SequenceBM = 2, Create following rows.'
		IF @SequenceBM & 2 > 0
			BEGIN
				SET @Step = 'Create Sequence specific temp tables.'
					CREATE TABLE #Time
						(
						[YearMonth] int,
						[RowOrder] int
						)

					CREATE TABLE #Jrn_FiscalYear
						(
						[FiscalYear] int,
						[YearMonth] int
						)

					CREATE TABLE #HistRate_Prev
						(
						[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[Currency_Book] nvarchar(10) COLLATE DATABASE_DEFAULT,
						[Currency_Group] nvarchar(10) COLLATE DATABASE_DEFAULT,
						[ConsolidationGroup] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[FiscalYear] int,
						[YearMonth] int,
						[SetHistRate] float,
						[FunctionalAmount_Open] float,
						[GroupAmount_Open] float,
						[FunctionalAmount_Open_Adj] float
						)
				
				SET @Step = 'Initial fill of table #HistRate.'
					TRUNCATE TABLE #HistRate
				
					INSERT INTO #HistRate
						(
						[YearMonth],
						[HistRateTypeBM],
						[Account],
						[Entity],
						[Book],
						[ConsolidationGroup],
						[Currency_Book],
						[FunctionalAmount_Open],
						[FunctionalAmount_Open_Adj],
						[FunctionalAmount_Flow],
						[Currency_Group],
						[GroupAmount_Open],
						[GroupAmount_Flow],
						[HistRate],
						[HistRateChange],
						[SetHistRate],
						[AvgRate],
						[VAR_HistRateYN]
						)
					SELECT
						[YearMonth],
						[HistRateTypeBM],
						[Account],
						HR.[Entity],
						HR.[Book],
						[ConsolidationGroup],
						HR.[Currency_Book],
						[FunctionalAmount_Open] = HR.[FunctionalAmount_Open],
						[FunctionalAmount_Open_Adj] = HR.[FunctionalAmount_Open_Adj],
						[FunctionalAmount_Flow] = HR.[FunctionalAmount_Flow],
						[Currency_Group],
						[GroupAmount_Open] = HR.[GroupAmount_Open],
						[GroupAmount_Flow] = HR.[GroupAmount_Flow],
						[HistRate],
						[HistRateChange],
						[SetHistRate],
						[AvgRate],
						[VAR_HistRateYN]
					FROM
						pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate HR
						INNER JOIN #ConsolidationGroup CG ON CG.[Entity] = HR.[Entity] AND CG.[Book] = HR.[Book] AND CG.[Currency_Book] = HR.[Currency_Book]
					WHERE
						[InstanceID] = @InstanceID AND
						[VersionID] = @VersionID AND
						[ConsolidationGroup] = @ConsolidationGroup AND
						([Account] = @Account OR @Account IS NULL)

					IF @DebugBM & 2 > 0 SELECT TempTable = '#HistRate_0', * FROM #HistRate

				SET @Step = 'Fill of table #Time.'
					SELECT
						@MinYearMonth = MIN(YearMonth)
					FROM
						#HistRate

					SET @SQLStatement = '
						INSERT INTO #Time
							(
							[YearMonth],
							[RowOrder]
							)
						SELECT
							[YearMonth] = [MemberId],
							[RowOrder]
						FROM
							' + @CallistoDatabase + '.[dbo].[S_DS_Time] T
						WHERE
							T.[MemberId] >= ' + CONVERT(nvarchar(15), @MinYearMonth) + ' AND 
							T.[MemberId] <= YEAR(GetDate()) * 100 + 12 AND
							T.[Level] = ''Month''
						ORDER BY
							T.MemberId'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 SELECT TempTable = '#Time', * FROM #Time ORDER BY [YearMonth]

				SET @Step = 'Calculate FX'
					TRUNCATE TABLE #Selection
					
					INSERT INTO #Selection
						(
						[Scenario_MemberId],
						[Time_MemberId]
						)
					SELECT DISTINCT
						[Scenario_MemberId] = 110,
						[Time_MemberId] = [YearMonth]
					FROM
						#Time

					IF @DebugBM & 2 > 0 SELECT TempTable = '#Selection', * FROM #Selection

					TRUNCATE TABLE #Currency
					
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
							' + @CallistoDatabase + '..S_DS_Currency C
							INNER JOIN #HistRate HR ON C.[Label] IN (HR.[Currency_Group], HR.[Currency_Book])'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 SELECT TempTable = '#Currency', * FROM #Currency

					TRUNCATE TABLE #FxRate
				
					EXEC pcINTEGRATOR..spBR_BR04 @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @CalledBy='MasterSP', @Operator=@Operator OUT, @JobID=@JobID, @Debug=@DebugSub

					DELETE #FxRate WHERE [Rate_MemberId] <> 101
					
					IF @DebugBM & 2 > 0 SELECT TempTable = '#FxRate', * FROM #FxRate ORDER BY Time_MemberId, Currency_MemberId, Rate_MemberId

				SET @Step = 'Fill of table #HistRate_CursorTable.'
					SET @SQLStatement = '
						INSERT INTO #Jrn_FiscalYear
							(
							[FiscalYear],
							[YearMonth]
							)
						SELECT
							[FiscalYear] = MIN([FiscalYear]),
							[YearMonth]
						FROM
							' + @JournalTable + ' J
						WHERE
							J.[YearMonth] >= ' + CONVERT(nvarchar(15), @MinYearMonth) + '
						GROUP BY
							[YearMonth]'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 SELECT TempTable='#Jrn_FiscalYear', * FROM #Jrn_FiscalYear ORDER BY [YearMonth]
					
					SELECT DISTINCT
						[YearMonth] = T.[YearMonth],
						[PrevYearMonth] = T1.[YearMonth],
						[FiscalYear] = JFY.[FiscalYear]
					INTO
						#HistRate_CursorTable
					FROM
						#Time T
						INNER JOIN #Jrn_FiscalYear JFY ON JFY.[YearMonth] = T.[YearMonth]
						LEFT JOIN #Time T1 ON T1.[RowOrder] = T.[RowOrder] -1
					WHERE
						T.[YearMonth] >= CONVERT(nvarchar(15), @MinYearMonth)
					ORDER BY
						T.[YearMonth]

					IF @DebugBM & 2 > 0 SELECT TempTable = '#HistRate_CursorTable', * FROM #HistRate_CursorTable ORDER BY [YearMonth]

				SET @Step = 'HistRate_Cursor'
					IF CURSOR_STATUS('global','HistRate_Cursor') >= -1 DEALLOCATE HistRate_Cursor
					DECLARE HistRate_Cursor CURSOR FOR
			
						SELECT
							[YearMonth],
							[PrevYearMonth],
							[FiscalYear]
						FROM
							#HistRate_CursorTable
						ORDER BY
							[YearMonth]

						OPEN HistRate_Cursor
						FETCH NEXT FROM HistRate_Cursor INTO @YearMonth, @PrevYearMonth, @FiscalYear

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@YearMonth] = @YearMonth, [@PrevYearMonth] = @PrevYearMonth, [@FiscalYear] = @FiscalYear

								TRUNCATE TABLE #Journal

								SET @SQLStatement = '
									INSERT INTO #Journal
										(
										[Entity],
										[Book],
										[Account],
										[Currency_Book],
										[Currency_Group],
										[ConsolidationGroup],
										[Value_Book],
										[Value_Book_Open],
										[Value_Group_YearOpen],
										[Value_Group_Only],
										[Value_Group_Close]
										)
									SELECT
										[Entity] = J.[Entity],
										[Book] = J.[Book],
										[Account] = J.[Account],
										[Currency_Book] = MAX(CG.[Currency_Book]),
										[Currency_Group] = ''' + @Currency_Group + ''',
										[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
										[Value_Book] = SUM(CASE WHEN J.[TransactionTypeBM] & 19 > 0 AND J.[YearMonth] = ' + CONVERT(nvarchar(15), @YearMonth) + ' AND J.[FiscalPeriod] <> 0 THEN J.[ValueDebit_Book] - J.[ValueCredit_Book] ELSE 0 END),
										[Value_Book_Open] = SUM(CASE WHEN J.[TransactionTypeBM] & 19 > 0 AND (J.[YearMonth] < ' + CONVERT(nvarchar(15), @YearMonth) + ' OR J.[FiscalPeriod] = 0) THEN J.[ValueDebit_Book] - J.[ValueCredit_Book] ELSE 0 END),
										[Value_Group_YearOpen] = SUM(CASE WHEN J.[TransactionTypeBM] & 4 > 0 AND J.[Flow] = ''OP_RE'' AND J.[YearMonth] = ' + CONVERT(nvarchar(15), @YearMonth) + ' THEN J.[ValueDebit_Group] - J.[ValueCredit_Group] ELSE 0 END),
										[Value_Group_Only] = SUM(CASE WHEN J.[TransactionTypeBM] & 8 > 0 AND J.[Flow] = ''OP_RE'' AND J.[YearMonth] = ' + CONVERT(nvarchar(15), @YearMonth) + ' THEN J.[ValueDebit_Group] - J.[ValueCredit_Group] ELSE 0 END),
										[Value_Group_Close] = SUM(CASE WHEN J.[TransactionTypeBM] & 8 > 0 AND J.[YearMonth] = ' + CONVERT(nvarchar(15), @YearMonth) + ' THEN J.[ValueDebit_Group] - J.[ValueCredit_Group] ELSE 0 END)
									FROM
										' + @JournalTable + ' J
										INNER JOIN #ConsolidationGroup CG ON CG.[Entity] = J.[Entity] AND CG.[Book] = J.[Book]
									WHERE
										J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
										J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
										J.[YearMonth] <= ' + CONVERT(nvarchar(15), @YearMonth) + ' AND
										(J.[ConsolidationGroup] IS NULL OR J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''') AND
										' + CASE WHEN @Account IS NOT NULL THEN 'J.[Account] = ''' + @Account + ''' AND' ELSE '' END + '
										J.[Scenario] = ''ACTUAL'' AND
										J.[TransactionTypeBM] & 31 > 0 AND
										J.[PostedStatus] <> 0
									GROUP BY
										J.[Entity],
										J.[Book],
										J.[Account]'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								IF @DebugBM & 2 > 0 SELECT TempTable = '#Journal', [@YearMonth] = @YearMonth, * FROM #Journal ORDER BY [Entity], [Book], [Account]

								--Update Columns for Initial rows ([HistRateTypeBM] = 1)
								UPDATE HR
								SET
									[HistRateTypeBM] = CASE WHEN HR.[SetHistRate] IS NULL THEN 1 ELSE 5 END,
									[HistRate] = CASE WHEN ISNULL(J.[Value_Book_Open], 0) = 0 OR ISNULL(J.[Value_Group_YearOpen], 0) = 0 THEN CASE WHEN HR.[SetHistRate] IS NULL THEN CASE WHEN @Operator = '*' THEN 1 / FxD.[FxRate] ELSE FxD.[FxRate] END ELSE HR.[SetHistRate] END ELSE J.[Value_Group_YearOpen] / J.[Value_Book_Open] END,
									[HistRateChange] = ROUND(CASE WHEN HR.[SetHistRate] IS NULL THEN 0 ELSE HR.[SetHistRate] - CASE WHEN ISNULL(J.[Value_Book_Open], 0) = 0 OR ISNULL(J.[Value_Group_YearOpen], 0) = 0 THEN CASE WHEN HR.[SetHistRate] IS NULL THEN FxD.[FxRate] ELSE HR.[SetHistRate] END ELSE J.[Value_Group_YearOpen] / J.[Value_Book_Open] END END, 8),
									[FunctionalAmount_Flow] = ISNULL(J.[Value_Book_Open], 0) + ISNULL(J.[Value_Book], 0),
									[GroupAmount_Flow] = (ISNULL(J.[Value_Book_Open], 0) + ISNULL(J.[Value_Book], 0)) * CASE WHEN ISNULL(J.[Value_Book_Open], 0) = 0 OR ISNULL(J.[Value_Group_YearOpen], 0) = 0 THEN CASE WHEN HR.[SetHistRate] IS NULL THEN CASE WHEN @Operator = '*' THEN 1 / FxD.[FxRate] ELSE FxD.[FxRate] END ELSE HR.[SetHistRate] END ELSE J.[Value_Group_YearOpen] / J.[Value_Book_Open] END,
--									[FunctionalAmount_Open] = ISNULL(J.[Value_Book_Open], 0),
--									[GroupAmount_Open] = ISNULL(J.[Value_Group_YearOpen], 0), --ISNULL(J.[Value_Book_Open], 0) * CASE WHEN HR.[SetHistRate] IS NULL THEN FxD.[FxRate] ELSE HR.[SetHistRate] END,
									[VAR_HistRateYN] = ISNULL(HR.[VAR_HistRateYN], 1)
								FROM
									#HistRate HR
									INNER JOIN #Currency CB ON CB.[Currency_MemberKey] = HR.[Currency_Book]
									LEFT JOIN #FxRate FxD ON 
										FxD.[Currency_MemberId] = CB.[Currency_MemberId] AND 
										FxD.[Rate_MemberId] = 101 AND --Average
										FxD.[Scenario_MemberId] = 110 AND --ACTUAL
										FxD.[Time_MemberId] = HR.[YearMonth]
									LEFT JOIN #Journal J ON
										J.[Entity] = HR.[Entity] AND
										J.[Book] = HR.[Book] AND
										J.[Account] = HR.[Account] AND
										J.[Currency_Book] = HR.[Currency_Book] AND
										J.[ConsolidationGroup] = HR.[ConsolidationGroup]
								WHERE
									HR.[YearMonth] = @YearMonth AND
									HR.[HistRateTypeBM] & 1 > 0

								IF @DebugBM & 2 > 0 
									SELECT TempTable = '#HistRate_1', * 
									FROM #HistRate 
									WHERE [YearMonth] <= @YearMonth
									ORDER BY YearMonth, Entity, Book, Account

								--Fill table #HistRate_Prev
								TRUNCATE TABLE #HistRate_Prev

								INSERT INTO #HistRate_Prev
									(
									[Entity],
									[Book],
									[Account],
									[Currency_Book],
									[Currency_Group],
									[ConsolidationGroup],
									[FiscalYear],
									[YearMonth],
									[SetHistRate],
									[FunctionalAmount_Open],
									[GroupAmount_Open],
									[FunctionalAmount_Open_Adj]
									)
								SELECT 
									[Entity] = HR.[Entity],
									[Book] = HR.[Book],
									[Account] = HR.[Account],
									[Currency_Book] = HR.[Currency_Book],
									[Currency_Group] = HR.[Currency_Group],
									[ConsolidationGroup] = HR.[ConsolidationGroup],
									[FiscalYear] = HRCT.[FiscalYear],
									[YearMonth] = @YearMonth,
									[SetHistRate] = HR.[SetHistRate],
--									[FunctionalAmount_Open] = ISNULL(HR.[FunctionalAmount_Open], 0) + ISNULL(HR.[FunctionalAmount_Open_Adj], 0) + ISNULL(HR.[FunctionalAmount_Flow], 0),
									[FunctionalAmount_Open] = ISNULL(HR.[FunctionalAmount_Open], 0) + ISNULL(HR.[FunctionalAmount_Flow], 0),
									[GroupAmount_Open] = ISNULL(HR.[GroupAmount_Open], 0) + ISNULL(HR.[GroupAmount_Open_Adj], 0) + ISNULL(HR.[GroupAmount_Flow], 0) + ISNULL(HR.[GroupAmount_Change], 0),
--									[FunctionalAmount_Open_Adj] = ROUND(ISNULL(J.[Value_Book_Open], 0) - (ISNULL(HR.[FunctionalAmount_Open], 0) + ISNULL(HR.[FunctionalAmount_Open_Adj], 0) + ISNULL(HR.[FunctionalAmount_Flow], 0)), 4)
									[FunctionalAmount_Open_Adj] = CASE WHEN ROUND(ISNULL(J.[Value_Book_Open], 0) - (ISNULL(HR.[FunctionalAmount_Open], 0) + ISNULL(HR.[FunctionalAmount_Flow], 0)), 4) <> 0 THEN ROUND(ISNULL(J.[Value_Book_Open], 0) - (ISNULL(HR.[FunctionalAmount_Open], 0) + ISNULL(HR.[FunctionalAmount_Open_Adj], 0) + ISNULL(HR.[FunctionalAmount_Flow], 0)), 4) ELSE 0 END
								FROM
									#HistRate HR
									INNER JOIN #HistRate_CursorTable HRCT ON HRCT.[YearMonth] = @PrevYearMonth
									LEFT JOIN #Journal J ON
										J.[Entity] = HR.[Entity] AND
										J.[Book] = HR.[Book] AND
										J.[Account] = HR.[Account] AND
										J.[Currency_Book] = HR.[Currency_Book] AND
										J.[ConsolidationGroup] = HR.[ConsolidationGroup]
								WHERE
									HR.[YearMonth] = @PrevYearMonth 

								IF @DebugBM & 2 > 0 SELECT TempTable = '#HistRate_Prev', * FROM #HistRate_Prev

								--Update Columns based on previous period for Continous rows ([HistRateTypeBM] = 2)
								UPDATE HR
								SET
									[HistRate] = ROUND(CASE WHEN HR1.[FunctionalAmount_Open] = 0 THEN ISNULL(HR1.[SetHistRate], 0) ELSE HR1.[GroupAmount_Open] / HR1.[FunctionalAmount_Open] END, 11),
--									[HistRate] = ROUND(CASE WHEN HR1.[FunctionalAmount_Open] = 0 THEN 47 ELSE HR1.[FunctionalAmount_Open] END, 11),
									[FunctionalAmount_Open] = HR1.[FunctionalAmount_Open],
									[GroupAmount_Open] = HR1.[GroupAmount_Open],
									[FunctionalAmount_Open_Adj] = HR1.[FunctionalAmount_Open_Adj],
									--[GroupAmount_Open_Adj] = CASE WHEN HR1.FiscalYear <> @FiscalYear THEN ISNULL(J.[Value_Group_YearOpen], 0) - HR1.[GroupAmount_Open] ELSE 0 END
									[GroupAmount_Open_Adj] = CASE WHEN HR1.FiscalYear <> @FiscalYear AND HR.Account = '3560' THEN ISNULL(J.[Value_Group_YearOpen], 0) - HR1.[GroupAmount_Open] ELSE 0 END
								FROM
									#HistRate HR
									INNER JOIN #HistRate_Prev HR1 ON 
										HR1.[Entity] = HR.[Entity] AND
										HR1.[Book] = HR.[Book] AND
										HR1.[Account] = HR.[Account] AND
										HR1.[Currency_Group] = HR.[Currency_Group] AND
										HR1.[ConsolidationGroup] = HR.[ConsolidationGroup] AND
										HR1.[YearMonth] = HR.YearMonth
									LEFT JOIN #Journal J ON
										J.[Entity] = HR.[Entity] AND
										J.[Book] = HR.[Book] AND
										J.[Account] = HR.[Account] AND
										J.[Currency_Book] = HR.[Currency_Book] AND
										J.[ConsolidationGroup] = HR.[ConsolidationGroup]
								WHERE
									HR.[YearMonth] = @YearMonth AND
									HR.[HistRateTypeBM] & 2 > 0

								IF @DebugBM & 2 > 0 
									SELECT TempTable = '#HistRate_2', * 
									FROM #HistRate 
									WHERE [YearMonth] <= @YearMonth
									ORDER BY YearMonth, Entity, Book, Account

								--Add new rows based on previous period for Continous rows ([HistRateTypeBM] = 2)
								INSERT INTO #HistRate
									(
									[Entity],
									[Book],
									[Account],
									[Currency_Book],
									[Currency_Group],
									[ConsolidationGroup],
									[YearMonth],
									[HistRateTypeBM],
									[HistRate],
									[FunctionalAmount_Open],
									[GroupAmount_Open],
									[FunctionalAmount_Open_Adj]
									)
								SELECT
									[Entity] = HR1.[Entity],
									[Book] = HR1.[Book],
									[Account] = HR1.[Account],
									[Currency_Book] = HR1.[Currency_Book],
									[Currency_Group] = HR1.[Currency_Group],
									[ConsolidationGroup] = HR1.[ConsolidationGroup],
									[YearMonth] = HR1.[YearMonth],
									[HistRateTypeBM] = 2,
									[HistRate] = CASE WHEN HR1.[FunctionalAmount_Open] = 0 THEN ISNULL(HR1.[SetHistRate], 0) ELSE HR1.[GroupAmount_Open] / HR1.[FunctionalAmount_Open] END,
									[FunctionalAmount_Open] = HR1.[FunctionalAmount_Open],
									[GroupAmount_Open] = HR1.[GroupAmount_Open],
									[FunctionalAmount_Open_Adj] = HR1.[FunctionalAmount_Open_Adj]
								FROM
									#HistRate_Prev HR1
								WHERE
									NOT EXISTS (SELECT 1 FROM #HistRate HR WHERE HR.[Entity] = HR1.[Entity] AND HR.[Book] = HR1.[Book] AND HR.[Account] = HR1.[Account] AND HR.[Currency_Group] = HR1.[Currency_Group] AND HR.[ConsolidationGroup] = HR1.[ConsolidationGroup] AND HR.[YearMonth] = HR1.[YearMonth])

								IF @DebugBM & 2 > 0 
									SELECT TempTable = '#HistRate_3', * 
									FROM #HistRate 
									WHERE [YearMonth] <= @YearMonth
									ORDER BY YearMonth, Entity, Book, Account
	
								--Update Columns based on same period
								UPDATE HR
								SET
									[HistRateTypeBM] = CASE WHEN HR.[HistRateTypeBM] & 1 > 0 THEN 1 ELSE 0 END + CASE WHEN HR.[HistRateTypeBM] & 2 > 0 THEN 2 ELSE 0 END + CASE WHEN HR.[SetHistRate] IS NOT NULL THEN 4 ELSE 0 END,
								--	[VAR_HistRateYN] = CASE WHEN HR.[HistRateTypeBM] & 5 > 0 OR HR.[VAR_HistRateYN] <> 0 OR HR.[SetHistRate] IS NOT NULL THEN 1 ELSE 0 END,
								--	[VAR_HistRateYN] = CASE WHEN HR.[HistRateTypeBM] & 5 > 0 OR HR.[VAR_HistRateYN] <> 0 THEN 1 ELSE 0 END,
								--	[VAR_HistRateYN] = CASE WHEN HR.[VAR_HistRateYN] <> 0 THEN 1 ELSE 0 END,
									[AvgRate] = CASE WHEN FxS.[FxRate] = 0 THEN 0 ELSE CASE WHEN @Operator = '*' THEN FxD.[FxRate] / FxS.[FxRate] ELSE 1 / (FxD.[FxRate] / FxS.[FxRate]) END END,
									[HistRate] = CASE WHEN ISNULL(J.[Value_Group_YearOpen], 0) <> 0 AND (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) <> 0 THEN J.[Value_Group_YearOpen] / (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) ELSE HR.[HistRate] END,
--									[HistRate] = CASE WHEN ISNULL(J.[Value_Group_YearOpen], 0) <> 0 AND (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) <> 0 THEN 42 ELSE HR.[HistRate] END,

--									[HistRate] = CASE WHEN ISNULL(J.[Value_Group_YearOpen], 0) <> 0 AND (HR.[FunctionalAmount_Open]) <> 0 THEN J.[Value_Group_YearOpen] / (HR.[FunctionalAmount_Open]) ELSE HR.[HistRate] END,
									[HistRateChange] = ROUND(CASE WHEN HR.[SetHistRate] IS NULL THEN 0 ELSE HR.[SetHistRate] - CASE WHEN ISNULL(J.[Value_Group_YearOpen], 0) <> 0 AND (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) <> 0 THEN J.[Value_Group_YearOpen] / (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) ELSE HR.[HistRate] END END, 8),
--									[HistRateChange] = ROUND(CASE WHEN HR.[SetHistRate] IS NULL THEN 0 ELSE HR.[SetHistRate] - CASE WHEN ISNULL(J.[Value_Group_YearOpen], 0) <> 0 AND (HR.[FunctionalAmount_Open]) <> 0 THEN J.[Value_Group_YearOpen] / (HR.[FunctionalAmount_Open]) ELSE HR.[HistRate] END END, 8),
									[FunctionalAmount_Open] = ISNULL(J.[Value_Book_Open], 0),
									[FunctionalAmount_Flow] = ISNULL(J.[Value_Book], 0),
								--	[GroupAmount_Open_Adj] = HR.[FunctionalAmount_Open_Adj] * HR.[HistRate],
									[GroupAmount_Flow] = CASE WHEN CASE WHEN HR.[HistRateTypeBM] & 5 > 0 OR HR.[VAR_HistRateYN] <> 0 OR HR.[SetHistRate] IS NOT NULL THEN 1 ELSE 0 END <> 0 THEN CASE WHEN ISNULL(J.[Value_Group_YearOpen], 0) <> 0 AND (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) <> 0 THEN J.[Value_Group_YearOpen] / (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) ELSE HR.[HistRate] END ELSE CASE WHEN FxS.[FxRate] = 0 THEN 0 ELSE CASE WHEN @Operator = '*' THEN FxD.[FxRate] / FxS.[FxRate] ELSE 1 / (FxD.[FxRate] / FxS.[FxRate]) END END END * ISNULL(J.[Value_Book], 0),
									[GroupAmount_Change] = CASE WHEN CASE WHEN HR.[HistRateTypeBM] & 5 > 0 OR HR.[VAR_HistRateYN] <> 0 OR HR.[SetHistRate] IS NOT NULL THEN 1 ELSE 0 END <> 0 
										THEN (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj] + ISNULL(J.[Value_Book], 0))
										ELSE (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) 
--										END * ROUND(CASE WHEN HR.[SetHistRate] IS NULL THEN 0 ELSE HR.[SetHistRate] - HR.[HistRate] END, 8),
										END * ROUND(CASE WHEN HR.[SetHistRate] IS NULL THEN 0 ELSE ROUND(CASE WHEN HR.[SetHistRate] IS NULL THEN 0 ELSE HR.[SetHistRate] - CASE WHEN ISNULL(J.[Value_Group_YearOpen], 0) <> 0 AND (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) <> 0 THEN J.[Value_Group_YearOpen] / (HR.[FunctionalAmount_Open] + HR.[FunctionalAmount_Open_Adj]) ELSE HR.[HistRate] END END, 8) END, 8),
									[GroupAmount_Jrn_Only] = ISNULL(J.[Value_Group_Only], 0),
									[GroupAmount_Jrn_Open] = ISNULL(J.[Value_Group_YearOpen], 0),
									[GroupAmount_Jrn_Close] = ISNULL(J.[Value_Group_Close], 0)
								FROM
									#HistRate HR
									INNER JOIN #Currency CB ON CB.[Currency_MemberKey] = HR.[Currency_Book]
									INNER JOIN #Currency CG ON CG.[Currency_MemberKey] = HR.[Currency_Group]
									LEFT JOIN #Journal J ON
										J.[Entity] = HR.[Entity] AND
										J.[Book] = HR.[Book] AND
										J.[Account] = HR.[Account] AND
										J.[Currency_Book] = HR.[Currency_Book] AND
										J.[ConsolidationGroup] = HR.[ConsolidationGroup]
									LEFT JOIN #FxRate FxD ON 
										FxD.[Currency_MemberId] = CG.[Currency_MemberId] AND 
										FxD.[Rate_MemberId] = 101 AND --Average
										FxD.[Scenario_MemberId] = 110 AND --ACTUAL
										FxD.[Time_MemberId] = HR.[YearMonth]
									LEFT JOIN #FxRate FxS ON
										FxS.[Currency_MemberId] = CB.[Currency_MemberId] AND
										FxS.[Rate_MemberId] = FxD.[Rate_MemberId] AND
										FxS.[Scenario_MemberId] = FxD.[Scenario_MemberId] AND
										FxS.[Time_MemberId] = FxD.[Time_MemberId]
								WHERE
									HR.[YearMonth] = @YearMonth AND
									HR.[HistRateTypeBM] & 2 > 0

								IF @DebugBM & 2 > 0 
									SELECT TempTable = '#HistRate_4', * 
									FROM #HistRate 
									WHERE [YearMonth] <= @YearMonth
									ORDER BY YearMonth, Entity, Book, Account

								FETCH NEXT FROM HistRate_Cursor INTO @YearMonth, @PrevYearMonth, @FiscalYear
							END

						CLOSE HistRate_Cursor
						DEALLOCATE HistRate_Cursor

				IF @DebugBM & 2 > 0			
					SELECT
						[TempTable] = '#HistRate',
						*
					FROM
						#HistRate HR
					ORDER BY
						[Entity],
						[Book],
						[Account],
						[YearMonth]
			
				SET @Step = 'Update BR05_Rule_FX_HistRate for all fixed HistRates'
					UPDATE FHR
					SET
						[HistRateTypeBM] = HR.[HistRateTypeBM],
						[Currency_Book] = HR.[Currency_Book],
						[FunctionalAmount_Open] = HR.[FunctionalAmount_Open],
						[FunctionalAmount_Open_Adj] = HR.[FunctionalAmount_Open_Adj],
						[FunctionalAmount_Flow] = HR.[FunctionalAmount_Flow],
						[GroupAmount_Open] = HR.[GroupAmount_Open],
						[GroupAmount_Open_Adj] = HR.[GroupAmount_Open_Adj],
						[GroupAmount_Flow] = HR.[GroupAmount_Flow],
						[GroupAmount_Change] = HR.[GroupAmount_Change],
						[GroupAmount_Jrn_Only] = HR.[GroupAmount_Jrn_Only],
						[GroupAmount_Jrn_Open] = HR.[GroupAmount_Jrn_Open],
						[GroupAmount_Jrn_Close] = HR.[GroupAmount_Jrn_Close],
						[HistRate] = HR.[HistRate],
						[HistRateChange] = HR.[HistRateChange],
						[SetHistRate] = HR.[SetHistRate],
						[AvgRate] = HR.[AvgRate],
						[VAR_HistRateYN] = HR.[VAR_HistRateYN]
					FROM
						pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate FHR
						INNER JOIN #HistRate HR ON
							HR.[Account] = FHR.[Account] AND
							HR.[Entity] = FHR.[Entity] AND
							HR.[Book] = FHR.[Book] AND
							HR.[Currency_Group] = FHR.[Currency_Group] AND
							HR.[ConsolidationGroup] = FHR.[ConsolidationGroup] AND
							HR.[YearMonth] = FHR.[YearMonth] AND
							HR.[Account] NOT IN ('CYNI_B')
					WHERE
						FHR.[InstanceID] = @InstanceID AND
						FHR.[VersionID] = @VersionID
--
--						FHR.[HistRateTypeBM] & 2 > 0
--
			
				SET @Step = 'Insert new rows into BR05_Rule_FX_HistRate'
					INSERT INTO pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate
						(
						[InstanceID],
						[VersionID],
						[Account],
						[Entity],
						[Book],
						[Currency_Group],
						[ConsolidationGroup],
						[YearMonth],
						[HistRateTypeBM],
						[Currency_Book],
						[FunctionalAmount_Open],
						[FunctionalAmount_Open_Adj],
						[FunctionalAmount_Flow],
						[GroupAmount_Open],
						[GroupAmount_Open_Adj],
						[GroupAmount_Flow],
						[GroupAmount_Change],
						[GroupAmount_Jrn_Only],
						[GroupAmount_Jrn_Open],
						[GroupAmount_Jrn_Close],
						[HistRate],
						[HistRateChange],
						[SetHistRate],
						[AvgRate],
						[VAR_HistRateYN]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[Account] = HR.[Account],
						[Entity] = HR.[Entity],
						[Book] = HR.[Book],
						[Currency_Group] = HR.[Currency_Group],
						[ConsolidationGroup] = HR.[ConsolidationGroup],
						[YearMonth] = HR.[YearMonth],
						[HistRateTypeBM] = HR.[HistRateTypeBM],
						[Currency_Book] = HR.[Currency_Book],
						[FunctionalAmount_Open] = HR.[FunctionalAmount_Open],
						[FunctionalAmount_Open_Adj] = HR.[FunctionalAmount_Open_Adj],
						[FunctionalAmount_Flow] = HR.[FunctionalAmount_Flow],
						[GroupAmount_Open] = HR.[GroupAmount_Open],
						[GroupAmount_Open_Adj] = HR.[GroupAmount_Open_Adj],
						[GroupAmount_Flow] = HR.[GroupAmount_Flow],
						[GroupAmount_Change] = HR.[GroupAmount_Change],
						[GroupAmount_Jrn_Only] = HR.[GroupAmount_Jrn_Only],
						[GroupAmount_Jrn_Open] = HR.[GroupAmount_Jrn_Open],
						[GroupAmount_Jrn_Close] = HR.[GroupAmount_Jrn_Close],
						[HistRate] = HR.[HistRate],
						[HistRateChange] = HR.[HistRateChange],
						[SetHistRate] = HR.[SetHistRate],
						[AvgRate] = HR.[AvgRate],
						[VAR_HistRateYN] = HR.[VAR_HistRateYN]
					FROM
						#HistRate HR
					WHERE
						HR.[Account] NOT IN ('CYNI_B') AND
						NOT EXISTS 
							(
							SELECT 1 
							FROM pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate D 
							WHERE 
								D.[InstanceID] = @InstanceID AND
								D.[VersionID] = @VersionID AND
								D.[Account] = HR.[Account] AND
								D.[Entity] = HR.[Entity] AND
								D.[Book] = HR.[Book] AND
								D.[Currency_Group] = HR.[Currency_Group] AND
								D.[ConsolidationGroup] = HR.[ConsolidationGroup] AND
								D.[YearMonth] = HR.[YearMonth]
							)

				SET @Step = 'Return all inserted rows from BR05_Rule_FX_HistRate'
					IF @DebugBM & 1 > 0				
						SELECT
							[Table] = ' pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate',
							FHR.*
						FROM
							pcINTEGRATOR_Data.dbo.BR05_Rule_FX_HistRate FHR
							INNER JOIN #ConsolidationGroup CG ON CG.[Entity] = FHR.[Entity] AND CG.[Book] = FHR.[Book]
						WHERE
							FHR.[InstanceID] = @InstanceID AND
							FHR.[VersionID] = @VersionID AND
							(FHR.[Account] = @Account OR @Account IS NULL)
						ORDER BY
							FHR.[Entity],
							FHR.[Book],
							FHR.[Account],
							FHR.[YearMonth]
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #HistRate
		DROP TABLE #Selection
		DROP TABLE #Currency
		DROP TABLE #FxRate
		DROP TABLE #Journal
		DROP TABLE #ConsolidationGroup

		IF @CalledYN = 0
			BEGIN
				DROP TABLE #FilterTable
			END

		IF @SequenceBM & 1 > 0
			BEGIN
				DROP TABLE #FiscalYear
			END

		IF @SequenceBM & 2 > 0
			BEGIN
				DROP TABLE #Time
				DROP TABLE #HistRate_CursorTable
				DROP TABLE #HistRate_Prev
			END

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
