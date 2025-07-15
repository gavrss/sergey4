SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_Consolidation]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@EntityGroupID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000761,
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
EXEC [spBR_BR05_Consolidation] @UserID=-10, @InstanceID=576, @VersionID=1082, @BusinessRuleID = 2717, @DebugBM=3

EXEC [spBR_BR05_Consolidation] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF
--Temporary test
-- SET @DebugBM = 11

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@DimensionFilterLeafLevel nvarchar(max) = '',
	@RULE_ConsolidationID int,
	@RULE_ConsolidationName nvarchar(50),
	@JournalSequence nvarchar(50),
	@DimensionFilter nvarchar(4000),
	@ConsolidationMethodBM int,
	@ModifierID int,
	@OnlyInterCompanyInGroupYN bit,
	@UsePreviousStepYN bit,
	@MovementYN bit,
	@CallistoDatabase nvarchar(100),
	@StepReference nvarchar(20),

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
			@ProcedureDescription = 'Running business rule BR05, Consolidation rules.',
			@MandatoryParameter = 'ConsolidationGroup' --Without @, separated by |

		IF @Version = '2.1.1.2169' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle HistRate.'
		IF @Version = '2.1.1.2172' SET @Description = 'Handle Intercompany = UNSPECIFIED. Catch BalanceYN from Account dim table.'
		IF @Version = '2.1.2.2179' SET @Description = 'Made generic.'
		IF @Version = '2.1.2.2183' SET @Description = 'Upgraded version of temp table #FilterTable'

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
			@CallistoDatabase = DestinationDatabase
		FROM
			pcINTEGRATOR_Data..[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

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

	SET @Step = 'CREATE TABLE #JournalBasePrev'
		CREATE TABLE #JournalBasePrev
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT, 
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] int,
			[FiscalPeriod] int,
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
			[Flow] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[InterCompanyEntity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Customer] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Supplier] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Currency_Book] nchar(3) COLLATE DATABASE_DEFAULT,
			[Value_Book] float,
			[Currency_Group] nchar(3) COLLATE DATABASE_DEFAULT,
			[Value_Group] float,
			)

	SET @Step = 'Extra debug to temp table'
		IF @DebugBM & 8 > 0
			BEGIN
				IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_JournalBase', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_JournalBase
				SELECT * INTO pcINTEGRATOR_Log..tmp_JournalBase FROM #JournalBase
			END

	SET @Step = 'CREATE TABLE #InterCompany'
		CREATE TABLE #InterCompany
			(
			[InterCompanyEntity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			)

		INSERT INTO #InterCompany
			(
			[InterCompanyEntity]
			)
		SELECT DISTINCT
			[InterCompanyEntity] = E.[MemberKey]
		FROM
			pcINTEGRATOR_Data..EntityHierarchy EH
			INNER JOIN pcINTEGRATOR_Data..Entity E ON E.InstanceID = EH.InstanceID AND E.VersionID = EH.VersionID AND E.EntityID = EH.EntityID AND E.[SelectYN] <> 0 AND E.[DeletedID] IS NULL
		WHERE
			EH.InstanceID = @InstanceID AND
			EH.VersionID = @VersionID AND
			EH.EntityGroupID = @EntityGroupID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#InterCompany', * FROM #InterCompany ORDER BY [InterCompanyEntity]

/*
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
*/
	SET @Step = 'CREATE TABLE #RULE_Consolidation_Cursor_Table'
		CREATE TABLE #RULE_Consolidation_Cursor_Table
			(
			[RULE_ConsolidationID] int,
			[RULE_ConsolidationName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[JournalSequence] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[ConsolidationMethodBM] int,
			[ModifierID] int,
			[OnlyInterCompanyInGroupYN] bit,
			[FunctionalCurrencyYN] bit,
			[UsePreviousStepYN] bit,
			[MovementYN] bit,
			[SortOrder] int
			)

		INSERT INTO #RULE_Consolidation_Cursor_Table
			(
			[RULE_ConsolidationID],
			[RULE_ConsolidationName],
			[JournalSequence],
			[DimensionFilter],
			[ConsolidationMethodBM],
			[ModifierID],
			[OnlyInterCompanyInGroupYN],
			[FunctionalCurrencyYN],
			[UsePreviousStepYN],
			[MovementYN],
			[SortOrder]
			)
		SELECT DISTINCT
			[RULE_ConsolidationID],
			[RULE_ConsolidationName] = RC.[RULE_ConsolidationName],
			[JournalSequence],
			[DimensionFilter],
			[ConsolidationMethodBM],
			[ModifierID],
			[OnlyInterCompanyInGroupYN],
			[FunctionalCurrencyYN],
			[UsePreviousStepYN],
			[MovementYN],
			[SortOrder]
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation] RC
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID AND
			[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#RULE_Consolidation_Cursor_Table', * FROM #RULE_Consolidation_Cursor_Table ORDER BY [FunctionalCurrencyYN], [SortOrder]

	SET @Step = 'CREATE TABLE #Consolidation_Row'
		CREATE TABLE #Consolidation_Row
			(
			[Rule_Consolidation_RowID] [int],
			[DestinationEntity] [nvarchar](20),
			[Account] [nvarchar](50),
			[BalanceYN] [bit],
			[Flow] [nvarchar](50),
			[Sign] [int],
			[FormulaAmount] [nvarchar](255),
			[NaturalAccountOnlyYN] bit
			)

	SET @Step = 'Run RULE_Consolidation_Cursor'
		IF CURSOR_STATUS('global','RULE_Consolidation_Cursor') >= -1 DEALLOCATE RULE_Consolidation_Cursor
		DECLARE RULE_Consolidation_Cursor CURSOR FOR
			SELECT 
				[RULE_ConsolidationID],
				[RULE_ConsolidationName],
				[JournalSequence],
				[DimensionFilter],
				[ConsolidationMethodBM],
				[ModifierID],
				[OnlyInterCompanyInGroupYN],
				[UsePreviousStepYN],
				[MovementYN]
			FROM
				#RULE_Consolidation_Cursor_Table
			WHERE
				[FunctionalCurrencyYN] = 0
			ORDER BY
				[SortOrder]

			OPEN RULE_Consolidation_Cursor
			FETCH NEXT FROM RULE_Consolidation_Cursor INTO @RULE_ConsolidationID, @RULE_ConsolidationName, @JournalSequence, @DimensionFilter, @ConsolidationMethodBM, @ModifierID, @OnlyInterCompanyInGroupYN, @UsePreviousStepYN, @MovementYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 
						SELECT
							[@RULE_ConsolidationID]=@RULE_ConsolidationID,
							[@RULE_ConsolidationName]=@RULE_ConsolidationName,
							[@JournalSequence]=@JournalSequence,
							[@DimensionFilter]=@DimensionFilter,
							[@ConsolidationMethodBM]=@ConsolidationMethodBM,
							[@ModifierID]=@ModifierID,
							[@OnlyInterCompanyInGroupYN]=@OnlyInterCompanyInGroupYN,
							[@UsePreviousStepYN]=@UsePreviousStepYN,
							[@MovementYN] = @MovementYN

					--Set @DimensionFilterLeafLevel'
					--TRUNCATE TABLE #FilterTable
/*
					SELECT
						@DimensionFilterLeafLevel = '',
						@StepReference = 'BR05_Cons_' + CONVERT(nvarchar(15), @RULE_ConsolidationID)
											
					EXEC pcINTEGRATOR..spGet_FilterTable
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@StepReference = @StepReference,
						@PipeString = @DimensionFilter,
						@StorageTypeBM_DataClass = 2, --@StorageTypeBM_DataClass,
						@StorageTypeBM = 4, --@StorageTypeBM,
						@JobID = @JobID,
						@Debug = @DebugSub

					IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable
					
					SELECT
						@DimensionFilterLeafLevel = @DimensionFilterLeafLevel + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'JB.[' + DimensionName + '] ' + [EqualityString] + ' (' + LeafLevelFilter + ') AND'
					FROM
						#FilterTable
					WHERE
						[StepReference] = @StepReference

					IF @DebugBM & 2 > 0 PRINT '@DimensionFilterLeafLevel: ' + @DimensionFilterLeafLevel
*/
					--Fill table #Consolidation_Row
					TRUNCATE TABLE #Consolidation_Row

					SET @SQLStatement = '
						INSERT INTO #Consolidation_Row
							(
							[Rule_Consolidation_RowID],
							[DestinationEntity],
							[Account],
							[BalanceYN],
							[Flow],
							[Sign],
							[FormulaAmount],
							[NaturalAccountOnlyYN]
							)
						SELECT
							[Rule_Consolidation_RowID],
							[DestinationEntity],
							[Account],
							[BalanceYN] = A.[TimeBalance],
							[Flow],
							[Sign] = RCR.[Sign],
							[FormulaAmount],
							[NaturalAccountOnlyYN]
						FROM
							pcINTEGRATOR_Data..BR05_Rule_Consolidation_Row RCR
							INNER JOIN [pcINTEGRATOR].[dbo].[BR05_FormulaAmount] AF ON AF.[InstanceID] IN (0, RCR.[InstanceID]) AND AF.[VersionID] IN (0, RCR.[VersionID]) AND AF.[FormulaAmountID] = RCR.[FormulaAmountID]
							LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Account] A ON A.[Label] = RCR.[Account]
						WHERE
							RCR.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							RCR.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							RCR.[BusinessRuleID] = ' + CONVERT(nvarchar(15), @BusinessRuleID) + ' AND
							RCR.[Rule_ConsolidationID] = ' + CONVERT(nvarchar(15), @RULE_ConsolidationID) + ' AND
							RCR.[SelectYN] <> 0'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 SELECT TempTable = '#Consolidation_Row', * FROM #Consolidation_Row

					--Fill table #JournalBasePrev
					TRUNCATE TABLE #JournalBasePrev

					IF @ModifierID = 70
						BEGIN
							INSERT INTO #JournalBasePrev
								(
								[Entity], 
								[Book],
								[FiscalYear],
								[FiscalPeriod],
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
								[Flow],
								[InterCompanyEntity],
								[Scenario],
								[Customer],
								[Supplier],
								[Currency_Book],
								[Value_Book],
								[Currency_Group],
								[Value_Group]
								)
							SELECT
								[Entity] = JB.[Entity], 
								[Book] = JB.[Book],
								[FiscalYear] = JB.[FiscalYear],
								[FiscalPeriod] = JB.[FiscalPeriod],
								[Account] = JB.[Account],
								[Segment01] = JB.[Segment01],
								[Segment02] = JB.[Segment02],
								[Segment03] = JB.[Segment03],
								[Segment04] = JB.[Segment04],
								[Segment05] = JB.[Segment05],
								[Segment06] = JB.[Segment06],
								[Segment07] = JB.[Segment07],
								[Segment08] = JB.[Segment08],
								[Segment09] = JB.[Segment09],
								[Segment10] = JB.[Segment10],
								[Segment11] = JB.[Segment11],
								[Segment12] = JB.[Segment12],
								[Segment13] = JB.[Segment13],
								[Segment14] = JB.[Segment14],
								[Segment15] = JB.[Segment15],
								[Segment16] = JB.[Segment16],
								[Segment17] = JB.[Segment17],
								[Segment18] = JB.[Segment18],
								[Segment19] = JB.[Segment19],
								[Segment20] = JB.[Segment20],
								[Flow] = JB.[Flow],
								[InterCompanyEntity] = JB.[InterCompanyEntity],
								[Scenario] = JB.[Scenario],
								[Customer] = JB.[Customer],
								[Supplier] = JB.[Supplier],
								[Currency_Book] = JB.[Currency_Book],
								[Value_Book] = JB.[Value_Book],
								[Currency_Group] = JB.[Currency_Group],
								[Value_Group] = JB.[Value_Group]
							FROM
								#JournalBase JB
								LEFT JOIN #InterCompany IC ON IC.[InterCompanyEntity] = JB.[InterCompanyEntity]
							WHERE 
								JB.[ConsolidationMethodBM] & @ConsolidationMethodBM > 0 AND
								JB.[RULE_ConsolidationID] = @RULE_ConsolidationID AND
								(@OnlyInterCompanyInGroupYN = 0 OR IC.[InterCompanyEntity] IS NOT NULL OR JB.[InterCompanyEntity] = 'UNSPECIFIED')
						END

					INSERT INTO #JournalBase
						(
						[ReferenceNo],
						[RULE_ConsolidationID],
						[RULE_FXID],
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
						[Currency_Book],
						[Value_Book],
						[Currency_Group],
						[Value_Group],
						[SourceModule],
						[SourceModuleReference]
						)
					SELECT
						[ReferenceNo] =JB.[ReferenceNo],
						[RULE_ConsolidationID] = JB.[RULE_ConsolidationID],
						[RULE_FXID] = JB.[RULE_FXID],
						[ConsolidationMethodBM] = JB.[ConsolidationMethodBM],
						[InstanceID] = JB.[InstanceID],
						[Entity] = JB.[Entity], 
						[Book] = JB.[Book],
						[FiscalYear] = JB.[FiscalYear],
						[FiscalPeriod] = JB.[FiscalPeriod],
						[JournalSequence] = @JournalSequence,
						[JournalNo] = 400000000 + JB.[Counter],
						[YearMonth] = JB.[YearMonth],
						[TransactionTypeBM] = CASE WHEN @MovementYN = 0 THEN 8 ELSE 32 END,
						[BalanceYN] = ISNULL(CR.[BalanceYN], JB.[BalanceYN]),
						[Account] = ISNULL(CR.[Account], JB.[Account]),
						[Segment01] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment01] ELSE '' END,
						[Segment02] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment02] ELSE '' END,
						[Segment03] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment03] ELSE '' END,
						[Segment04] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment04] ELSE '' END,
						[Segment05] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment05] ELSE '' END,
						[Segment06] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment06] ELSE '' END,
						[Segment07] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment07] ELSE '' END,
						[Segment08] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment08] ELSE '' END,
						[Segment09] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment09] ELSE '' END,
						[Segment10] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment10] ELSE '' END,
						[Segment11] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment11] ELSE '' END,
						[Segment12] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment12] ELSE '' END,
						[Segment13] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment13] ELSE '' END,
						[Segment14] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment14] ELSE '' END,
						[Segment15] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment15] ELSE '' END,
						[Segment16] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment16] ELSE '' END,
						[Segment17] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment17] ELSE '' END,
						[Segment18] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment18] ELSE '' END,
						[Segment19] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment19] ELSE '' END,
						[Segment20] = CASE WHEN CR.[NaturalAccountOnlyYN] = 0 THEN JB.[Segment20] ELSE '' END,
						[TransactionDate] = NULL,
						[PostedDate] = GetDate(),
						[Source] = 'CRULE',
						[Flow] = ISNULL(CR.[Flow], JB.[Flow]),
						[ConsolidationGroup] = JB.[ConsolidationGroup],
						[InterCompanyEntity] = JB.[InterCompanyEntity],
						[Scenario] = JB.[Scenario],
						[Customer] = JB.[Customer],
						[Supplier] = JB.[Supplier],
						[Description_Head] = 'C rule: ' + @RULE_ConsolidationName,
						[Description_Line] = '',
--						[Description_Line] = ''Formula: ' + @FormulaFX + ', FlowFilter: '' + FXRow.[FlowFilter] + '', ResultValueFilter: '' + FXRow.[ResultValueFilter] + '', Sign: '' + FXRow.[Sign],
						[Currency_Book] = JB.[Currency_Book],
						[Value_Book] = CR.[Sign] * (JB.[Value_Book] - ISNULL(JBP.[Value_Book], 0)),
						[Currency_Group] = JB.[Currency_Group],
						[Value_Group] = CR.[Sign] * (JB.[Value_Group] - ISNULL(JBP.[Value_Group], 0)),
						[SourceModule] = 'CRULE',
						[SourceModuleReference] = CONVERT(nvarchar(15), JB.[RULE_ConsolidationID]) + ' - ' + CONVERT(nvarchar(15), CR.[Rule_Consolidation_RowID])
					FROM
						#JournalBase JB
						INNER JOIN #Consolidation_Row CR ON 1 = 1
						LEFT JOIN #InterCompany IC ON IC.[InterCompanyEntity] = JB.[InterCompanyEntity]
						LEFT JOIN #JournalBasePrev JBP ON
							JBP.[Entity] = JB.[Entity] AND 
							JBP.[Book] = JB.[Book] AND
							JBP.[FiscalYear] = JB.[FiscalYear] AND
							JBP.[FiscalPeriod] = JB.[FiscalPeriod] - 1 AND
							JBP.[Account] = JB.[Account] AND
							JBP.[Segment01] = JB.[Segment01] AND
							JBP.[Segment02] = JB.[Segment02] AND
							JBP.[Segment03] = JB.[Segment03] AND
							JBP.[Segment04] = JB.[Segment04] AND
							JBP.[Segment05] = JB.[Segment05] AND
							JBP.[Segment06] = JB.[Segment06] AND
							JBP.[Segment07] = JB.[Segment07] AND
							JBP.[Segment08] = JB.[Segment08] AND
							JBP.[Segment09] = JB.[Segment09] AND
							JBP.[Segment10] = JB.[Segment10] AND
							JBP.[Segment11] = JB.[Segment11] AND
							JBP.[Segment12] = JB.[Segment12] AND
							JBP.[Segment13] = JB.[Segment13] AND
							JBP.[Segment14] = JB.[Segment14] AND
							JBP.[Segment15] = JB.[Segment15] AND
							JBP.[Segment16] = JB.[Segment16] AND
							JBP.[Segment17] = JB.[Segment17] AND
							JBP.[Segment18] = JB.[Segment18] AND
							JBP.[Segment19] = JB.[Segment19] AND
							JBP.[Segment20] = JB.[Segment20] AND
							JBP.[Flow] = JB.[Flow] AND
							ISNULL(JBP.[InterCompanyEntity], '') = ISNULL(JB.[InterCompanyEntity], '') AND
							ISNULL(JBP.[Scenario], '') = ISNULL(JB.[Scenario], '') AND
							ISNULL(JBP.[Customer], '') = ISNULL(JB.[Customer], '') AND
							ISNULL(JBP.[Supplier], '') = ISNULL(JB.[Supplier], '') AND
							ISNULL(JBP.[Currency_Book], '') = ISNULL(JB.[Currency_Book], '') AND
							ISNULL(JBP.[Currency_Group], '') = ISNULL(JB.[Currency_Group], '')
					WHERE 
						JB.[ConsolidationMethodBM] & @ConsolidationMethodBM > 0 AND
						JB.[RULE_ConsolidationID] = @RULE_ConsolidationID AND
						(@OnlyInterCompanyInGroupYN = 0 OR IC.[InterCompanyEntity] IS NOT NULL OR JB.[InterCompanyEntity] = 'UNSPECIFIED')

					SET @Selected = @Selected + @@ROWCOUNT
										
					IF @DebugBM & 8 > 0 
						SELECT TempTable = '#JournalBase', *--, [@ConsolidationGroup] = @ConsolidationGroup
						FROM #JournalBase 
						WHERE RULE_ConsolidationID = @RULE_ConsolidationID AND ConsolidationMethodBM & @ConsolidationMethodBM > 0
						ORDER BY Entity, Book, JournalNo, JournalLine, FiscalYear, FiscalPeriod, YearMonth, Account, Segment01, Segment02, Segment03, Segment04, Segment05, InterCompanyEntity

					FETCH NEXT FROM RULE_Consolidation_Cursor INTO @RULE_ConsolidationID, @RULE_ConsolidationName, @JournalSequence, @DimensionFilter, @ConsolidationMethodBM, @ModifierID, @OnlyInterCompanyInGroupYN, @UsePreviousStepYN, @MovementYN
				END

			CLOSE RULE_Consolidation_Cursor
			DEALLOCATE RULE_Consolidation_Cursor

		IF @DebugBM & 8 > 0 
			SELECT TempTable = '#JournalBase', *
			FROM #JournalBase 
			ORDER BY Entity, Book, JournalNo, JournalLine, FiscalYear, FiscalPeriod, YearMonth, Account, Segment01, Segment02, Segment03, Segment04, Segment05, InterCompanyEntity

	SET @Step = 'Drop temp tables'
		DROP TABLE #RULE_Consolidation_Cursor_Table
		DROP TABLE #Consolidation_Row
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #JournalBase
			END

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
