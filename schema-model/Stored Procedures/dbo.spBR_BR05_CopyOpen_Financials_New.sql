SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_CopyOpen_Financials_New]
	@UserID int = NULL, -- -10, --temporary hardcoded
	@InstanceID int = NULL, -- 527, --temporary hardcoded
	@VersionID int = NULL, -- 1055, --temporary hardcoded

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@Source_DataClassID int = NULL,
	@EntityGroupID int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
	@JournalTable nvarchar(100) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@ConsolidationGroup nvarchar(50) = NULL, --Mandatory if @EntityGroupID is not set
	@FiscalYear int = NULL, --Mandatory if not called
	@Entity_MemberKey nvarchar(50) = NULL, --Optional filter mainly for debugging purposes
	@Filter nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000823,
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
EXEC [spBR_BR05_CopyOpen_Financials_New] 
	@UserID=-10, 	
	@InstanceID = 527,
	@VersionID = 1055,
	@FiscalYear = 2021,
	@ConsolidationGroup = 'Group',
	@Filter = 'BusinessProcess=CYNI_B_REV_SP',
	@DebugBM = 3

EXEC [spBR_BR05_CopyOpen_Financials_New] 
	@UserID=-10, 	
	@InstanceID = 527,
	@VersionID = 1055,
	@FiscalYear = 2021,
	@ConsolidationGroup = 'Group',
	@Scenario = 'BUDGET',
	@Filter = 'Account=Financials_',
	@DebugBM = 3

EXEC [spBR_BR05_CopyOpen_Financials] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
--	@Entity VARCHAR(30)='1004', -- source
--	@Time VARCHAR(30)='202103', -- source for selected conso year
	@Account VARCHAR(30)='CYNI_B_REVAL', -- Configurable as filter?
--	@Currency VARCHAR(30)='CAD', -- Selectable - Either Group Currency or BusinessRule='NONE'
	@Currency_Group nchar(3) = 'CAD',
--	@FiscalYear int = 2021,
	@DataClassID int,
	@SQLFilter nvarchar(max),
	@SQLStatement nvarchar(max),
	@RuleType nvarchar(50),
	@RuleID int,
	@DimensionFilter nvarchar(4000),
	@DimensionFilterLeafLevel nvarchar(max),
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
	@Version nvarchar(50) = '2.1.1.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Sub routine for [spBR_BR05_CopyOpen]. Insert rows from FACT_Financials.',
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
			@CallistoDatabase = ISNULL(@CallistoDatabase, [DestinationDatabase])
		FROM
			pcINTEGRATOR_Data..[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		SELECT
			@EntityGroupID = ISNULL(@EntityGroupID, EntityID),
			@ConsolidationGroup = ISNULL(@ConsolidationGroup, MemberKey)
		FROM
			pcINTEGRATOR_Data..[Entity]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			([MemberKey] = @ConsolidationGroup OR [EntityID] = @EntityGroupID) AND
			[EntityTypeID] = 0

		SELECT
			@DataClassID = [DataClassID]
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassName = 'Financials' AND
			SelectYN <> 0 AND
			DeletedID IS NULL

		IF @DebugBM & 2 > 0
			SELECT 
				[@DataClassID] = @DataClassID


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
					E.DeletedID IS NULL
				ORDER BY
					E.MemberKey,
					EB.Book

				UPDATE EB
				SET
					[Account_RE] = EPV.[EntityPropertyValue]
				FROM
					#EntityBook EB
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV ON EPV.[InstanceID] = @InstanceID AND EPV.[VersionID] = @VersionID AND EPV.[EntityID] = EB.[EntityID] AND EPV.[EntityPropertyTypeID] = -10 AND EPV.[SelectYN] <> 0			
			END

		IF @DebugBM & 2 > 0
			SELECT * FROM #EntityBook

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

	SET @Step = 'Create #FilterTable'
		IF OBJECT_ID(N'TempDB.dbo.#FilterTable', N'U') IS NULL
			CREATE TABLE #FilterTable
				(
				[StepReference] nvarchar(20) COLLATE DATABASE_DEFAULT,
				[TupleNo] int,
				[DimensionID] int,
				[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[DimensionTypeID] int,
				[StorageTypeBM] int,
				[MultiDimIncludedYN] bit DEFAULT 0,
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

		EXEC pcINTEGRATOR.dbo.[spGet_FilterTable]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DataClassID = @DataClassID,
			@PipeString = @Filter,
			@DatabaseName = @CallistoDatabase, --Mandatory
			@StorageTypeBM_DataClass = 3, --3 returns _MemberKey, 4 returns _MemberId
			@StorageTypeBM = NULL, --Mandatory
			@StepReference = 'CO_Financials',
			@SQLFilter = @SQLFilter OUT,
			@Debug = @DebugSub


			SET @SQLFilter = ''
					SELECT
						@SQLFilter = @SQLFilter + 
							CASE WHEN ISNULL(FT.[LeafLevelFilter], '') <> '' AND ISNULL(FT.[PropertyName], '') = ''
							THEN
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'V.[' + FT.[DimensionName] + '] IN (' + FT.[LeafLevelFilter] + ') AND'
							ELSE
								''
							END
						--@SQL_Join = @SQL_Join +
						--	CASE WHEN ISNULL(FT.[PropertyName], '') <> '' AND ISNULL(FT.[Filter], '') <> ''
						--	THEN 
						--		CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_' + FT.[DimensionName] + '] [' + FT.[DimensionName]  + '] ON [' + FT.[DimensionName] + '].[MemberId] = DC.[' + FT.[DimensionName] + '_MemberId] AND [' + FT.[DimensionName] + '].[' + FT.[PropertyName] + '] = ''' + FT.[Filter] + ''''
						--	ELSE
						--		''
						--	END
					FROM

						#FilterTable FT
					WHERE
						FT.[StepReference] = 'CO_Financials' 

				IF LEN(@SQLFilter) > 0
					SET @SQLFilter = LEFT(@SQLFilter, LEN(@SQLFilter) - 4)

		IF @DebugBM & 2 > 0 
			BEGIN
				SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = 'CO_Financials' ORDER BY [TupleNo], [SortOrder], [DimensionName]
				SELECT [@SQLFilter] = @SQLFilter
			END

	SET @Step = 'Create and fill temp table #BalanceAccount'
		CREATE TABLE #BalanceAccount
			(
			[Account_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[BalanceYN] bit
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
				[RNodeType] = ''L'' AND
				[TimeBalance] <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#BalanceAccount', * FROM #BalanceAccount ORDER BY [Account_MemberKey]

	SET @Step = 'Import data into #JournalBase'
		SET @SQLStatement = '
			INSERT INTO #JournalBase
				(
				[ReferenceNo],
				[ConsolidationMethodBM],
				[InstanceID],
				[Entity], 
				[Book],
				[FiscalYear],
				[FiscalPeriod],
				[JournalSequence],
				[JournalNo],
				[JournalLine],
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
				[JournalDate],
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
				[ReferenceNo] = 13000000 + ROW_NUMBER() OVER(ORDER BY V.[Entity], EB.[Book], V.[Time] / 100, V.[Time] % 100, V.[Account]),
				[ConsolidationMethodBM] = MAX(EB.[ConsolidationMethodBM]),
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[Entity] = V.[Entity], 
				[Book] = EB.Book,
				[FiscalYear] = V.[Time] / 100,
				[FiscalPeriod] = V.[Time] % 100,
				[JournalSequence] = ''FACT_Financials'',
				[JournalNo] = 23000000 + ROW_NUMBER() OVER(PARTITION BY V.[Entity], EB.[Book], V.[Time] / 100 ORDER BY V.[Time] % 100),
				[JournalLine] = 1,
				[YearMonth] = V.[Time],
				[BalanceYN] = MAX(CONVERT(int, ISNULL(BA.[BalanceYN], 0))),
				[Account] = V.[Account],
				[Segment01] = V.[GL_Department],
				[Segment02] = V.[GL_Division],
				[Segment03] = '''',
				[Segment04] = '''',
				[Segment05] = '''',
				[Segment06] = '''',
				[Segment07] = '''',
				[Segment08] = '''',
				[Segment09] = '''',
				[Segment10] = '''',
				[Segment11] = '''',
				[Segment12] = '''',
				[Segment13] = '''',
				[Segment14] = '''',
				[Segment15] = '''',
				[Segment16] = '''',
				[Segment17] = '''',
				[Segment18] = '''',
				[Segment19] = '''',
				[Segment20] = '''',
				[JournalDate] = CONVERT(date, DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), V.[Time] / 100) + ''-'' + CONVERT(NVARCHAR(15), V.[Time] % 100) + ''-1''))),
				[TransactionDate] = CONVERT(date, DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), V.[Time] / 100) + ''-'' + CONVERT(NVARCHAR(15), V.[Time] % 100) + ''-1''))),
				[PostedDate] = CONVERT(date, GetDate()),
				[Source] = ''FACT'',
				[Flow] = V.[Flow],
				[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
				[InterCompanyEntity] = V.[InterCompany],
				[Scenario] = V.[Scenario],
				[Customer] = V.[Customer],
				[Supplier] = V.[Supplier],
				[Description_Head] = ''Loaded from FACT_Financials'',
				[Description_Line] = '''',
				[Currency_Book] = EB.[Currency],
				[Value_Book] = ROUND(SUM(CASE WHEN V.[Currency] = EB.[Currency] AND V.[Group] = ''NONE'' THEN V.[Financials_Value] ELSE 0 END), 4),
				[Currency_Group] = ''' + @Currency_Group + ''',
				[Value_Group] = ROUND(SUM(CASE WHEN V.[Currency] = ''' + @Currency_Group + ''' AND V.[Group] = ''' + @ConsolidationGroup + ''' THEN V.[Financials_Value] ELSE 0 END), 4),
				[SourceModule] = ''FACT'',
				[SourceModuleReference] = NULL
			FROM
				[pcDATA_E2IP].[dbo].[FACT_Financials_View] V
				INNER JOIN #EntityBook EB ON EB.MemberKey = V.[Entity] AND EB.[BookTypeBM] & 3 = 3 AND EB.[SelectYN] <> 0
				LEFT JOIN #BalanceAccount BA ON BA.[Account_MemberKey] = V.[Account]
			WHERE
				V.[Time] BETWEEN CONVERT(nvarchar(15), ' + CONVERT(nvarchar(15), @FiscalYear) + ' * 100) AND CONVERT(nvarchar(15), ' + CONVERT(nvarchar(15), @FiscalYear) + ' * 100 + 99) AND
				V.[Scenario] = ''' + @Scenario + '''' + CASE WHEN LEN(@SQLFilter) > 0 THEN ' AND' + @SQLFilter ELSE '' END + ' AND
				V.[BusinessRule] = ''NONE'' AND
				V.[Group] = ''NONE''
			GROUP BY
				EB.Book,
				V.[Account],
				V.[GL_Department],
				V.[GL_Division],
				EB.[Currency],
				V.[Entity],
				V.[Flow],
				V.[Group],
				V.InterCompany,
				V.Scenario,
				V.[Customer],
				V.[Supplier],
				V.[Time]
			HAVING
				ROUND(SUM(CASE WHEN V.[Currency] = EB.[Currency] AND V.[Group] = ''NONE'' THEN V.[Financials_Value] ELSE 0 END), 4) <> 0 OR
				ROUND(SUM(CASE WHEN V.[Currency] = ''' + @Currency_Group + ''' AND V.[Group] = ''' + @ConsolidationGroup + ''' THEN V.[Financials_Value] ELSE 0 END), 4) <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
	
		IF @DebugBM & 2 > 0 
			BEGIN	
				SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY YearMonth

				SELECT
					Entity,
					YearMonth,
					[Currency_Book],
					[Value_Book] = ROUND(SUM(Value_Book), 2),
					[Value_Group] = ROUND(SUM(Value_Group), 2)
				FROM
					#JournalBase
				GROUP BY
					Entity,
					YearMonth,
					[Currency_Book]
			END

---------------

		IF @DebugBM & 8 > 0 SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY InterCompanyEntity, Entity, Book, Account, Segment01, Segment02, Segment03, Segment04, Segment05, FiscalYear, FiscalPeriod, YearMonth
/*
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
*/

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
						@StepReference = 'BR05_FIN_' + CONVERT(nvarchar(15), @RuleID)
											
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
						@DimensionFilterLeafLevel = @DimensionFilterLeafLevel + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'JB.[' + DimensionName + '] IN (' + LeafLevelFilter + ') AND'
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

------------------


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
