SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_CopyOpen]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@EntityGroupID int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
	@JournalTable nvarchar(100) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@ConsolidationGroup nvarchar(50) = NULL, --Mandatory if @EntityGroupID is not set
	@FiscalYear int = NULL, --Mandatory if not called
	@Entity_MemberKey nvarchar(50) = NULL, --Optional filter mainly for debugging purposes
	@ByCustomerYN bit = NULL,
	@BySupplierYN bit = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000558,
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
EXEC [spBR_BR05_CopyOpen] @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @Scenario = 'ACTUAL', @JournalTable = '[pcETL_EPIC].[dbo].[Journal]', @ConsolidationGroup = 'G_INTERFOR', @FiscalYear = 2020, @Entity_MemberKey = 'GILCHRIS', @DebugBM=2
EXEC [spBR_BR05_CopyOpen] @UserID=-10, @InstanceID=529, @VersionID=1001, @Scenario = 'ACTUAL', @JournalTable = '[pcETL_TECA].[dbo].[Journal]', @ConsolidationGroup = 'A', @FiscalYear = 2020, @Entity_MemberKey = '05', @DebugBM=2

EXEC [spBR_BR05_CopyOpen] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

--Temporary test
-- SET @DebugBM = 3

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@DataClassID int,
	@Book nvarchar(50),
	@RuleType nvarchar(50),
	@RuleID int,
	@DimensionFilter nvarchar(4000),
	@DimensionFilterLeafLevel nvarchar(max),
	@StepReference nvarchar(20),
	@Currency_Group nchar(3),
	@Journal_DataClassID int,

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
	@Version nvarchar(50) = '2.1.2.2192'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Sub routine for [spBR_BR05]. Insert CopyOpen.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2153' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Made generic.'
		IF @Version = '2.1.1.2170' SET @Description = 'Rely on InterCompanyEntity in Journal table.'
		IF @Version = '2.1.1.2171' SET @Description = 'Split P&L accounts and Balance accounts into two different queries. Filter on PostedStatus <> 0.'
		IF @Version = '2.1.1.2172' SET @Description = 'Exclude PYNI_B, CYNI_B and CYNI_I.'
		IF @Version = '2.1.1.2174' SET @Description = 'Include TransactionTypeBM = 16.'
		IF @Version = '2.1.2.2179' SET @Description = 'Changed Flow setting for balance accounts.'
		IF @Version = '2.1.2.2183' SET @Description = 'Upgraded version of temp table #FilterTable'
		IF @Version = '2.1.2.2187' SET @Description = 'Added @RuleType to @StepReference to make it unique in CopyOpen_Rule_Cursor'
		IF @Version = '2.1.2.2191' SET @Description = 'New structure where HistRate is not used anymore'
		IF @Version = '2.1.2.2192' SET @Description = 'Added parameters @ByCustomerYN and @BySupplierYN'

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
			@EntityGroupID = ISNULL(@EntityGroupID, E.EntityID),
			@ConsolidationGroup = ISNULL(@ConsolidationGroup, E.MemberKey),
			@Currency_Group = EB.[Currency]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND EB.[BookTypeBM] & 16 > 0 AND EB.[SelectYN] <> 0
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.[MemberKey] = @ConsolidationGroup OR E.[EntityID] = @EntityGroupID) AND
			E.[EntityTypeID] = 0
		
		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		SELECT
			@DataClassID = DataClassID,
			@ByCustomerYN = ISNULL(@ByCustomerYN, [ByCustomerYN]),
			@BySupplierYN = ISNULL(@BySupplierYN, [BySupplierYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].BR05_Master
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID AND
			[DeletedID] IS NULL

		SELECT
			@Journal_DataClassID = DataClassID
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE 
			[InstanceID]=@InstanceID AND
			[VersionID]=@VersionID AND
			[DataClassTypeID] = -5 AND
			[SelectYN] <> 0 AND
			[DeletedID] IS NULL

		IF @DebugBM & 2 > 0 
			SELECT
				[@JournalTable] = @JournalTable,
				[@CallistoDatabase] = @CallistoDatabase,
				[@EntityGroupID] = @EntityGroupID,
				[@ConsolidationGroup] = @ConsolidationGroup,
				[@Journal_DataClassID] = @Journal_DataClassID,
				[@ByCustomerYN] = @ByCustomerYN,
				[@BySupplierYN] = @BySupplierYN

	SET @Step = 'Check @EntityGroupID is set.'
		IF @EntityGroupID IS NULL
			BEGIN
				SET @Message = '@EntityGroupID must be set.'
				SET @Severity = 16
				GOTO EXITPOINT
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

	SET @Step = 'CREATE TABLE #EntityBook'
		IF OBJECT_ID(N'TempDB.dbo.#EntityBook', N'U') IS NULL
			BEGIN
				CREATE TABLE #EntityBook
					(
					[EntityID] int,
					[MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Entity_MemberId] bigint,
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[BookTypeBM] int,
					[Currency] nchar(3),
					[Currency_MemberId] bigint,
					[OwnershipConsolidation] float,
					[ConsolidationMethodBM] int,
					[Account_RE] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Account_OCI] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[PYNI_B_YN] bit,
					[SourceDataClassID] int,
					[SelectYN] bit
					)

				INSERT INTO #EntityBook
					(
					[EntityID],
					[MemberKey],
					[Book],
					[BookTypeBM],
					[Currency],
					[OwnershipConsolidation],
					[ConsolidationMethodBM],
					[SelectYN]
					)
				SELECT 
					E.[EntityID],
					E.[MemberKey],
					EB.[Book],
					EB.[BookTypeBM],
					EB.[Currency],
					EH.[OwnershipConsolidation],
					EH.[ConsolidationMethodBM],
					[SelectYN] = CASE WHEN E.[MemberKey] = @Entity_MemberKey OR @Entity_MemberKey IS NULL THEN 1 ELSE 0 END
				FROM 
					Entity E
					INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 18 > 0 AND EB.SelectYN <> 0
					INNER JOIN EntityHierarchy EH ON EH.InstanceID = E.InstanceID AND EH.VersionID = E.VersionID AND EH.EntityGroupID = @EntityGroupID AND EH.EntityID = E.EntityID
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.SelectYN <> 0 AND
					E.DeletedID IS NULL AND
					(E.MemberKey = @Entity_MemberKey OR @Entity_MemberKey IS NULL)
				ORDER BY
					E.MemberKey,
					EB.Book

				IF @DebugBM & 2 > 0 SELECT TempTable = '#EntityBook', [@ConsolidationGroup] = @ConsolidationGroup, * FROM #EntityBook ORDER BY [ConsolidationMethodBM], [MemberKey]
			END

	SET @Step = 'CREATE TABLE #FiscalPeriod'
		IF OBJECT_ID(N'TempDB.dbo.#FiscalPeriod', N'U') IS NULL
			BEGIN
				CREATE TABLE #FiscalPeriod
					(
					FiscalYear int,
					FiscalPeriod int,
					YearMonth int
					)

				SELECT
					@Book = Book
				FROM
					pcINTEGRATOR_Data..Entity_Book
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					EntityID = @EntityGroupID AND
					BookTypeBM & 16 > 0 AND
					SelectYN <> 0
				
				--EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityGroupID, @Book = @Book, @StartFiscalYear = @FiscalYear, @EndFiscalYear = @FiscalYear, @FiscalPeriod0YN=1
				EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityGroupID, @Book = @Book, @StartFiscalYear = @FiscalYear, @EndFiscalYear = @FiscalYear, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @JobID = @JobID
				IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod
			END

	SET @Step = 'Insert CopyOpen rows into #JournalBase'
		IF @DebugBM & 2 > 0 
			BEGIN
				SELECT
					[@InstanceID] = @InstanceID,
					[@ConsolidationGroup] = @ConsolidationGroup,
					[@JournalTable] = @JournalTable,
					[@CallistoDatabase] = @CallistoDatabase,
					[@Scenario] = @Scenario

				SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod
			END

		--P&L accounts accounts into #JournalBase	
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
				[Currency_Transaction],
				[Value_Transaction],
				[SourceModule],
				[SourceModuleReference]
				)'
								
		SET @SQLStatement = @SQLStatement + '
			SELECT
				[ReferenceNo] = 11000000 + ROW_NUMBER() OVER(ORDER BY J.[Entity], J.[Book], FP.[FiscalYear], FP.[FiscalPeriod], J.[Account]),
				[ConsolidationMethodBM] = MAX(EB.ConsolidationMethodBM),
				[TranSpecFxRateID] = TSFXR.[TranSpecFxRateID],
				[TranSpecFxRate] = MAX(TSFXR.[TranSpecFxRate]),
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[Entity] = J.[Entity], 
				[Book] = J.[Book],
				[FiscalYear] = FP.[FiscalYear],
				[FiscalPeriod] = FP.[FiscalPeriod],
				[JournalSequence] = ''JRNL'',
				[JournalNo] = 21000000 + ROW_NUMBER() OVER(PARTITION BY J.[Entity], J.[Book], FP.[FiscalYear] ORDER BY FP.[FiscalPeriod]),
				[YearMonth] = FP.[YearMonth],
				[BalanceYN] = J.[BalanceYN],
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
				[TransactionDate] = J.[TransactionDate],
				[PostedDate] = ISNULL(J.[PostedDate], GetDate()),
				[Source] = ''COPEN'',
				[Flow] = CASE WHEN [ValueDebit_Book] <> 0 THEN ''VAR_Increase'' ELSE ''VAR_Decrease'' END,
				[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
				[InterCompanyEntity] = J.[InterCompanyEntity],
				[Scenario] = ''' + @Scenario + ''',
				[Customer] = ' + CASE WHEN @ByCustomerYN <> 0 THEN 'J.[Customer]' ELSE '''''' END + ',
				[Supplier] = ' + CASE WHEN @BySupplierYN <> 0 THEN 'J.[Supplier]' ELSE '''''' END + ',
				[Description_Head] = ''COPEN rule: CopyOpen'',
				[Description_Line] = '''',
				[Currency_Book] = J.[Currency_Book],
				[Value_Book] = ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4),
				[Currency_Transaction] = J.[Currency_Transaction],
				[Value_Transaction] = ROUND(SUM(J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction]), 4),
				[SourceModule] = ''COPEN'',
				[SourceModuleReference] = ''''
			FROM'
									
		SET @SQLStatement = @SQLStatement + '
				' + @JournalTable + ' J
				INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = J.[FiscalYear] AND FP.[FiscalPeriod] = J.[FiscalPeriod] AND FP.[FiscalPeriod] > 0
				INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[SourceDataClassID] = ' + CONVERT(nvarchar(15), @Journal_DataClassID) + ' AND EB.[SelectYN] <> 0
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[BR05_TranSpecFxRate] TSFXR ON
					TSFXR.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
					TSFXR.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
					TSFXR.[Entity] = J.[Entity] AND
					TSFXR.[Book] = J.[Book] AND
					TSFXR.[FiscalYear] = J.[FiscalYear] AND
					TSFXR.[FiscalPeriod] = J.[FiscalPeriod] AND
					TSFXR.[JournalSequence] = J.[JournalSequence] AND
					TSFXR.[JournalNo] = J.[JournalNo] AND
					TSFXR.[ConsolidationGroup] = ''' + @ConsolidationGroup + '''
			WHERE
				J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				J.[TransactionTypeBM] & 19 > 0 AND
				J.[BalanceYN] = 0 AND
				J.[Scenario] = ''' + @Scenario + ''' AND
				J.[ConsolidationGroup] IS NULL AND
				J.PostedStatus <> 0 AND
				J.Account NOT IN (''CYNI_I'')
			GROUP BY
				TSFXR.[TranSpecFxRateID],
				J.[Entity], 
				J.[Book],
				FP.[FiscalYear],
				FP.[FiscalPeriod],
				FP.[YearMonth],
				J.[BalanceYN],
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
				J.[TransactionDate],
				J.[PostedDate],
				' + CASE WHEN @ByCustomerYN <> 0 THEN 'J.[Customer],' ELSE '' END + '
				' + CASE WHEN @BySupplierYN <> 0 THEN 'J.[Supplier],' ELSE '' END + '
				J.[Currency_Book],
				J.[Currency_Transaction],
				CASE WHEN J.[ValueDebit_Book] <> 0 THEN ''VAR_Increase'' ELSE ''VAR_Decrease'' END,
				J.[InterCompanyEntity]'

		IF @DebugBM & 2 > 0 
			BEGIN
				IF LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR05_CopyOpen, P&L Accounts.'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'BR05_CopyOpen, P&L Accounts', 
							@SQLStatement = @SQLStatement,
							@JobID = @JobID
					END
				ELSE
					PRINT @SQLStatement
			END
		EXEC (@SQLStatement)
		SET @Selected = @Selected + @@ROWCOUNT

		--Balance accounts into #JournalBase

		CREATE TABLE #EntityFiscalYear
			(
			[Entity] nvarchar(50),
			[Book] nvarchar(50),
			[FiscalYear] int
			)
		
		SET @SQLStatement = '
			INSERT INTO #EntityFiscalYear
				(
				[Entity],
				[Book],
				[FiscalYear]
				)
			SELECT
				[Entity],
				[Book],
				[FiscalYear] = MIN(FiscalYear)
			FROM
				' + @JournalTable + '
			WHERE
				[TransactionTypeBM] & 17 > 0
			GROUP BY
				[Entity],
				[Book]'

		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0
			BEGIN
				IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_FiscalPeriod', N'U') IS NOT NULL
					DROP TABLE pcINTEGRATOR_Log.dbo.tmp_FiscalPeriod
				SELECT * INTO pcINTEGRATOR_Log.dbo.tmp_FiscalPeriod FROM #FiscalPeriod

				IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_EntityBook', N'U') IS NOT NULL
					DROP TABLE pcINTEGRATOR_Log.dbo.tmp_EntityBook
				SELECT * INTO pcINTEGRATOR_Log.dbo.tmp_EntityBook FROM #EntityBook

				IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_EntityFiscalYear', N'U') IS NOT NULL
					DROP TABLE pcINTEGRATOR_Log.dbo.tmp_EntityFiscalYear
				SELECT * INTO pcINTEGRATOR_Log.dbo.tmp_EntityFiscalYear FROM #EntityFiscalYear
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
				[Currency_Transaction],
				[Value_Transaction],
				[SourceModule],
				[SourceModuleReference]
				)'

		SET @SQLStatement = @SQLStatement + '
			SELECT
				[ReferenceNo] = 12000000 + ROW_NUMBER() OVER(ORDER BY J.[Entity], J.[Book], FP.[FiscalYear], CASE WHEN FP.[FiscalPeriod] = 0 THEN 1 ELSE FP.[FiscalPeriod] END, J.[Account]),
				[ConsolidationMethodBM] = MAX(EB.[ConsolidationMethodBM]),
				[TranSpecFxRateID] = TSFXR.[TranSpecFxRateID],
				[TranSpecFxRate] = MAX(TSFXR.[TranSpecFxRate]),
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[Entity] = J.[Entity], 
				[Book] = J.[Book],
				[FiscalYear] = FP.[FiscalYear],
				[FiscalPeriod] = CASE WHEN FP.[FiscalPeriod] = 0 THEN 1 ELSE FP.[FiscalPeriod] END,
				[JournalSequence] = ''JRNL'',
				[JournalNo] = 22000000 + ROW_NUMBER() OVER(PARTITION BY J.[Entity], J.[Book], FP.[FiscalYear] ORDER BY CASE WHEN FP.[FiscalPeriod] = 0 THEN 1 ELSE FP.[FiscalPeriod] END),
				[YearMonth] = FP.[YearMonth],
				[BalanceYN] = J.[BalanceYN],
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
--				[TransactionDate] = CASE WHEN F.[Flow] = ''OP_Opening'' THEN MAX(CONVERT(date, LEFT(FP.[YearMonth], 4) + ''-'' + RIGHT(FP.[YearMonth], 2) + ''-01'')) ELSE MAX(CONVERT(date, DATEADD(d, -1, DATEADD(m, 1, LEFT(FP.[YearMonth], 4) + ''-'' + RIGHT(FP.[YearMonth], 2) + ''-01'')))) END,
				[TransactionDate] = MAX(CASE WHEN J.[JournalSequence] IN (''OB_ADJ'', ''OB_JRN'') THEN CONVERT(date, LEFT(FP.[YearMonth], 4) + ''-'' + RIGHT(FP.[YearMonth], 2) + ''-01'') ELSE CONVERT(date, DATEADD(d, -1, DATEADD(m, 1, LEFT(FP.[YearMonth], 4) + ''-'' + RIGHT(FP.[YearMonth], 2) + ''-01''))) END),
				[PostedDate] = GetDate(),
				[Source] = ''COPEN'',
				[Flow] = 
					CASE WHEN J.[JournalSequence] IN (''OB_ADJ'', ''OB_JRN'')
						THEN
							CASE WHEN J.[JournalSequence] = ''OB_ADJ''
								THEN ''OP_AdjSrc'' 
								ELSE ''OP_Opening'' 
							END
						ELSE 
							CASE WHEN [ValueCredit_Book] = 0 
								THEN ''VAR_Increase'' 
								ELSE ''VAR_Decrease'' 
							END 
						END,
				[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
				[InterCompanyEntity] = J.[InterCompanyEntity],
				[Scenario] = ''' + @Scenario + ''',
				[Customer] = ' + CASE WHEN @ByCustomerYN <> 0 THEN 'J.[Customer]' ELSE '''''' END + ',
				[Supplier] = ' + CASE WHEN @BySupplierYN <> 0 THEN 'J.[Supplier]' ELSE '''''' END + ',
				[Description_Head] = ''COPEN rule: CopyOpen'',
				[Description_Line] = '''',
				[Currency_Book] = J.[Currency_Book],
--				[Value_Book] = ROUND(CASE WHEN F.[Flow] = ''OP_Opening'' AND FP.[FiscalPeriod] NOT IN (13, 14, 15) THEN SUM(CASE WHEN J.[FiscalPeriod] < FP.[FiscalPeriod] OR J.[FiscalPeriod] = 0 THEN J.[ValueDebit_Book] - J.[ValueCredit_Book] ELSE 0 END) ELSE SUM(CASE WHEN F.[Flow] <> ''OP_Opening'' AND J.[FiscalPeriod] = FP.[FiscalPeriod] AND J.[FiscalPeriod] <> 0 THEN J.[ValueDebit_Book] - J.[ValueCredit_Book] ELSE 0 END) END, 4),
				[Value_Book] =  SUM(CASE WHEN J.[Account] = EB.[Account_RE] AND J.[FiscalPeriod] = 0 AND J.[JournalSequence] = ''OB_ADJ'' AND J.[FiscalYear] > EFY.[FiscalYear] THEN 0 ELSE J.[ValueDebit_Book] - J.[ValueCredit_Book] END),
				[Currency_Transaction] = J.[Currency_Transaction],
--				[Value_Transaction] = ROUND(CASE WHEN F.[Flow] = ''OP_Opening'' AND FP.[FiscalPeriod] NOT IN (13, 14, 15) THEN SUM(CASE WHEN J.[FiscalPeriod] < FP.[FiscalPeriod] OR J.[FiscalPeriod] = 0 THEN J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction] ELSE 0 END) ELSE SUM(CASE WHEN F.[Flow] <> ''OP_Opening'' AND J.[FiscalPeriod] = FP.[FiscalPeriod] AND J.[FiscalPeriod] <> 0 THEN J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction] ELSE 0 END) END, 4),
				[Value_Transaction] = SUM(J.[ValueDebit_Transaction] - J.[ValueCredit_Transaction]),
				[SourceModule] = ''COPEN'',
				[SourceModuleReference] = ''''
			FROM'
									
		SET @SQLStatement = @SQLStatement + '
				' + @JournalTable + ' J
				INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = J.[FiscalYear] AND FP.[FiscalPeriod] = J.[FiscalPeriod]
				INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[SourceDataClassID] = ' + CONVERT(nvarchar(15), @Journal_DataClassID) + ' AND EB.[SelectYN] <> 0
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[BR05_TranSpecFxRate] TSFXR ON
					TSFXR.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
					TSFXR.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
					TSFXR.[Entity] = J.[Entity] AND
					TSFXR.[Book] = J.[Book] AND
					TSFXR.[FiscalYear] = J.[FiscalYear] AND
					TSFXR.[FiscalPeriod] = J.[FiscalPeriod] AND
					TSFXR.[JournalSequence] = J.[JournalSequence] AND
					TSFXR.[JournalNo] = J.[JournalNo] AND
					TSFXR.[ConsolidationGroup] = ''' + @ConsolidationGroup + '''
				LEFT JOIN #EntityFiscalYear EFY ON
					EFY.[Entity] =  J.[Entity] AND
					EFY.[Book] = J.[Book]
			WHERE
				J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				J.[TransactionTypeBM] & 19 > 0 AND
				J.[BalanceYN] <> 0 AND
				J.[Scenario] = ''' + @Scenario + ''' AND
				J.[ConsolidationGroup] IS NULL AND
				J.PostedStatus <> 0 AND
				--J.Account NOT IN (''CYNI_B'', ''PYNI_B'') AND
				J.Account NOT IN (''CYNI_B'') AND
				--J.[JournalSequence] NOT IN (''OB_JRN'', ''OB_MAN'', ''OB_MAN_RE'') AND
				J.[JournalSequence] NOT IN (''OB_MAN'', ''OB_MAN_RE'') AND
				((EB.[PYNI_B_YN] = 0 AND J.Account <> ''PYNI_B'') OR EB.[PYNI_B_YN] <> 0) AND
				((EB.[PYNI_B_YN] <> 0 AND J.Account = ''PYNI_B'') OR J.[JournalSequence] <> ''OB_JRN'' OR EB.[FirstFiscalYearYN] <> 0)
--AND J.FiscalPeriod <> 0
			GROUP BY
				TSFXR.[TranSpecFxRateID],
				J.[Entity], 
				J.[Book],
				FP.[FiscalYear],
				CASE WHEN FP.[FiscalPeriod] = 0 THEN 1 ELSE FP.[FiscalPeriod] END,
				FP.[YearMonth],
				J.[BalanceYN],
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
				' + CASE WHEN @ByCustomerYN <> 0 THEN 'J.[Customer],' ELSE '' END + '
				' + CASE WHEN @BySupplierYN <> 0 THEN 'J.[Supplier],' ELSE '' END + '
				J.[Currency_Book],
				J.[Currency_Transaction],
				CASE WHEN J.[JournalSequence] IN (''OB_ADJ'', ''OB_JRN'')
					THEN
						CASE WHEN J.[JournalSequence] = ''OB_ADJ''
							THEN ''OP_AdjSrc'' 
							ELSE ''OP_Opening'' 
						END
					ELSE 
						CASE WHEN [ValueCredit_Book] = 0 
							THEN ''VAR_Increase'' 
							ELSE ''VAR_Decrease'' 
						END 
					END,
				J.[InterCompanyEntity]
			HAVING
				SUM(CASE WHEN J.[Account] = EB.[Account_RE] AND J.[FiscalPeriod] = 0 AND J.[JournalSequence] = ''OB_ADJ'' AND J.[FiscalYear] > EFY.[FiscalYear] THEN 0 ELSE J.[ValueDebit_Book] - J.[ValueCredit_Book] END) <> 0
			--	CASE WHEN F.[Flow] = ''OP_Opening'' AND FP.[FiscalPeriod] NOT IN (13, 14, 15) THEN SUM(CASE WHEN J.[FiscalPeriod] < FP.[FiscalPeriod] OR J.[FiscalPeriod] = 0 THEN J.[ValueDebit_Book] ELSE 0 END) ELSE SUM(CASE WHEN J.[FiscalPeriod] = FP.[FiscalPeriod] AND J.[FiscalPeriod] <> 0 THEN J.[ValueDebit_Book] ELSE 0 END) END <> 0 OR
			--	CASE WHEN F.[Flow] = ''OP_Opening'' AND FP.[FiscalPeriod] NOT IN (13, 14, 15) THEN SUM(CASE WHEN J.[FiscalPeriod] < FP.[FiscalPeriod] OR J.[FiscalPeriod] = 0 THEN J.[ValueCredit_Book] ELSE 0 END) ELSE SUM(CASE WHEN J.[FiscalPeriod] = FP.[FiscalPeriod] AND J.[FiscalPeriod] <> 0 THEN J.[ValueCredit_Book] ELSE 0 END) END <> 0'

		IF @DebugBM & 2 > 0 
			BEGIN
				IF LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR05_CopyOpen, Balance Accounts.'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'BR05_CopyOpen, Balance Accounts', 
							@SQLStatement = @SQLStatement,
							@JobID = @JobID
					END
				ELSE
					PRINT @SQLStatement
			END
		EXEC (@SQLStatement)
		SET @Selected = @Selected + @@ROWCOUNT

		IF @DebugBM & 8 > 0 SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY InterCompanyEntity, Entity, Book, Account, Segment01, Segment02, Segment03, Segment04, Segment05, FiscalYear, FiscalPeriod, YearMonth

	SET @Step = 'Run [spBR_BR05_CopyOpen_Financials]'
		IF @InstanceID = 527 --Hardcoded version
			BEGIN
				EXEC [dbo].[spBR_BR05_CopyOpen_Financials_E2IP]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@BusinessRuleID = @BusinessRuleID,
					@EntityGroupID = @EntityGroupID,
					@Scenario = @Scenario,
					@JournalTable = @JournalTable,
					@CallistoDatabase = @CallistoDatabase,
					@ConsolidationGroup = @ConsolidationGroup,
					@FiscalYear = @FiscalYear,
					@Entity_MemberKey = @Entity_MemberKey,
					@JobID = @JobID,
					@Debug = @DebugSub
			END

--SELECT TempTable = '#JournalBase', Step = 1, * FROM #JournalBase

	SET @Step = 'Run [spBR_BR05_Fx_Opening]'
		EXEC [dbo].[spBR_BR05_Fx_Opening]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@BusinessRuleID = @BusinessRuleID,
			@CallistoDatabase = @CallistoDatabase,
			@JournalTable = @JournalTable,
			@Currency_Group = @Currency_Group,
			@FiscalYear = @FiscalYear,
			@Scenario = @Scenario,
			@ConsolidationGroup = @ConsolidationGroup,
			@HistoricYN = 0,
			@JobID = @JobID,
			@Debug = @DebugSub

--SELECT TempTable = '#JournalBase', Step = '2, @HistoricYN = 0', * FROM #JournalBase

	SET @Step = 'Update JournalLine'
		CREATE TABLE #JournalNo
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] int,
			[FiscalPeriod] int,
			[JournalSequence] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[JournalNo] int
			)

		INSERT INTO  #JournalNo
			(
			[Entity],
			[Book],
			[FiscalYear],
			[FiscalPeriod],
			[JournalSequence]
			)
		SELECT DISTINCT
			[Entity] = JB.[Entity],
			[Book] = JB.[Book], 
			[FiscalYear] = JB.[FiscalYear],
			[FiscalPeriod] = JB.[FiscalPeriod],
			[JournalSequence] = JB.[JournalSequence]
		FROM
			#JournalBase JB

		UPDATE JN
		SET
			[JournalNo] = sub.[JournalNo]
		FROM
			#JournalNo JN
			INNER JOIN
			(
			SELECT 
				[Entity] = [Entity],
				[Book] = [Book], 
				[FiscalYear] = [FiscalYear],
				[FiscalPeriod] = [FiscalPeriod],
				[JournalSequence] = [JournalSequence],
				[JournalNo] = 200000000 + ROW_NUMBER() OVER(ORDER BY [Entity], [Book], [FiscalYear], [FiscalPeriod], [JournalSequence])
			FROM
				#JournalNo
			) sub ON sub.[Entity] = JN.[Entity] AND sub.[Book] = JN.[Book] AND sub.[FiscalYear] = JN.[FiscalYear] AND sub.[FiscalPeriod] = JN.[FiscalPeriod] AND sub.[JournalSequence] = JN.[JournalSequence]

		UPDATE JB
		SET
			[JournalNo] = JN.[JournalNo]
		FROM
			#JournalBase JB 
			INNER JOIN #JournalNo JN ON JN.[Entity] = JB.[Entity] AND JN.[Book] = JB.[Book] AND JN.[FiscalYear] = JB.[FiscalYear] AND JN.[FiscalPeriod] = JB.[FiscalPeriod] AND JN.[JournalSequence] = JB.[JournalSequence]

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
						@StepReference = 'BR05_CO_' + RIGHT(@RuleType, 4) + '_' + CONVERT(nvarchar(15), @RuleID)
											
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
						@DimensionFilterLeafLevel = @DimensionFilterLeafLevel + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'JB.[' + [DimensionName] + '] ' + [EqualityString] + ' (' + [LeafLevelFilter] + ') AND'
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
		
	SET @Step = 'Return #JournalBase'
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = '#JournalBase', * FROM #JournalBase 
				--WHERE Account = '165100' AND Segment02 = '1410' AND [YearMonth] = '202012'
				ORDER BY Entity, Book, FiscalYear, YearMonth, FiscalPeriod, Account, Segment01, Segment02, Segment03, Segment04, Segment05, InterCompanyEntity
			END

	SET @Step = 'Extra debug to temp table'
		IF @DebugBM & 2 > 0
			BEGIN
				IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_JournalBase', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log..tmp_JournalBase
				SELECT * INTO pcINTEGRATOR_Log..tmp_JournalBase FROM #JournalBase
			END

	SET @Step = 'Drop the temp tables'
--		DROP TABLE #InterCompanySelection
		DROP TABLE #CopyOpen_Rule_Cursor_Table
		DROP TABLE #JournalNo
		IF @CalledYN = 0 
			BEGIN
				DROP TABLE #JournalBase
				DROP TABLE #EntityBook
				DROP TABLE #FiscalPeriod
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
