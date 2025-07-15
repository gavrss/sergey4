SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_CopyOpen_Financials]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@Source_DataClassID int = NULL,
	@EntityGroupID int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
--	@JournalTable nvarchar(100) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@ConsolidationGroup nvarchar(50) = NULL, --Mandatory if @EntityGroupID is not set
	@FiscalYear int = NULL, --Mandatory if not called
	@Entity_MemberKey nvarchar(50) = NULL, --Optional filter mainly for debugging purposes
--	@Filter nvarchar(max) = NULL,

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
EXEC [spBR_BR05_CopyOpen_Financials] 
	@UserID=-10, 	
	@InstanceID = 527,
	@VersionID = 1055,
	@FiscalYear = 2021,
	@ConsolidationGroup = 'Group',
	@Filter = 'BusinessProcess=CYNI_B_REV_SP',
	@DebugBM = 3

EXEC [spBR_BR05_CopyOpen_Financials] 
	@UserID=-10, 	
	@InstanceID = 527,
	@VersionID = 1055,
	@FiscalYear = 2021,
	@ConsolidationGroup = 'Group',
	@Scenario = 'BUDGET',
	@Filter = 'Account=Financials_',
	@DebugBM = 3

EXEC [spBR_BR05_CopyOpen_Financials] 
	@UserID=-10, 	
	@InstanceID = 576,
	@VersionID = 1082,
	@BusinessRuleID = 2717,
	@FiscalYear = 2021,
	@ConsolidationGroup = 'G_AXYZ',
	@Scenario = 'ACTUAL',
	@Entity_MemberKey = 'JV_India',
	@DebugBM = 11

EXEC [spBR_BR05_CopyOpen_Financials] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@Currency_Group nchar(3),
	@Currency_Group_MemberId bigint,
	@Financials_DataClassID int,
	@SQLFilter nvarchar(max),
	@SQLStatement nvarchar(max),
	@RuleType nvarchar(50),
	@RuleID int,
	@DimensionFilter nvarchar(4000),
	@DimensionFilterLeafLevel nvarchar(max),
	@StepReference nvarchar(20),
	@SegmentString nvarchar(max) = NULL,
	@Scenario_MemberId bigint,
	@SegmentJoin nvarchar(max),
	@SegmentGroupBy nvarchar(max),
	@EntityGroupBook nvarchar(50),
	@ConsolidationGroup_MemberId bigint,
	@LoopNo int = 0,
	@Entity_MemberId int,
	@Filter nvarchar(max),
	@LeafLevelFilter nvarchar(max),
	@Book nvarchar(50),
	@Currency_Book nchar(3),
	@Currency_Book_MemberId bigint,
	@Entity nvarchar(50),
	@ConsolidationMethodBM int,

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Sub routine for [spBR_BR05_CopyOpen]. Insert rows from FACT_Financials.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2179' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2187' SET @Description = 'Made semi generic. Hardcoded for E2IP.'
		IF @Version = '2.1.2.2190' SET @Description = 'Made generic.'
		IF @Version = '2.1.2.2191' SET @Description = 'New structure where HistRate is not used anymore'

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
			@EntityGroupID = ISNULL(@EntityGroupID, E.[EntityID]),
			@ConsolidationGroup = ISNULL(@ConsolidationGroup, E.[MemberKey]),
			@Currency_Group = EB.[Currency]
		FROM
			pcINTEGRATOR_Data..[Entity] E
			INNER JOIN pcINTEGRATOR_Data..[Entity_Book] EB ON EB.[InstanceID] = E.InstanceID AND EB.[VersionID] = E.VersionID AND EB.[EntityID] = E.[EntityID] AND EB.[BookTypeBM] & 16 > 0 AND EB.[SelectYN] <> 0
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.[MemberKey] = @ConsolidationGroup OR E.[EntityID] = @EntityGroupID) AND
			E.[EntityTypeID] = 0

		SELECT 
			@EntityGroupBook = Book
		FROM
			pcINTEGRATOR_Data..Entity_Book
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			EntityID = @EntityGroupID AND
			BookTypeBM & 16 > 0

		SELECT
			@Financials_DataClassID = [DataClassID]
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DataClassName] = 'Financials' AND
			[ModelBM] & 64 > 0 AND
			[SelectYN] <> 0 AND
			[DeletedID] IS NULL

		EXEC [spGet_SegmentString] @UserID=@UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @OutPut = 'Journal', @SegmentString = @SegmentString OUT, @SegmentJoin = @SegmentJoin OUT, 	@SegmentGroupBy = @SegmentGroupBy OUT, @JobID = @JobID, @Debug = @DebugSub

		SET @SQLStatement = 'SELECT @InternalVariable = [MemberId] FROM [' + @CallistoDatabase + '].dbo.[S_DS_Scenario] WHERE [Label] = ''' + @Scenario + ''''
		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @Scenario_MemberId OUT

		SET @SQLStatement = 'SELECT @InternalVariable = [MemberId] FROM [' + @CallistoDatabase + '].dbo.[S_DS_Currency] WHERE [Label] = ''' + @Currency_Group + ''''
		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @Currency_Group_MemberId OUT

		SET @SQLStatement = 'SELECT @InternalVariable = [MemberId] FROM [' + @CallistoDatabase + '].dbo.[S_DS_Group] WHERE [Label] = ''' + @ConsolidationGroup + ''''
		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @ConsolidationGroup_MemberId OUT

		IF @DebugBM & 2 > 0
			SELECT 
				[@Financials_DataClassID] = @Financials_DataClassID,
				[@SegmentString] = @SegmentString,
				[@SegmentJoin] = @SegmentJoin,
				[@SegmentGroupBy] = @SegmentGroupBy,
				[@Currency_Group] = @Currency_Group,
				[@Currency_Group_MemberId] = @Currency_Group_MemberId,
				[@Scenario_MemberId] = @Scenario_MemberId,
				[@EntityGroupBook] = @EntityGroupBook,
				[@ConsolidationGroup_MemberId] = @ConsolidationGroup_MemberId


	SET @Step = 'CREATE TABLE #FiscalPeriod'
		IF OBJECT_ID(N'TempDB.dbo.#FiscalPeriod', N'U') IS NULL
			BEGIN
				CREATE TABLE #FiscalPeriod
					(
					FiscalYear int,
					FiscalPeriod int,
					YearMonth int
					)

				EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityGroupID, @Book = @EntityGroupBook, @FiscalYear = @FiscalYear, @FiscalPeriod0YN = 0, @FiscalPeriod13YN = 0, @JobID = @JobID
			END
		IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY [FiscalYear], [FiscalPeriod], [YearMonth]

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
					[Currency] nchar(3) COLLATE DATABASE_DEFAULT,
					[Currency_MemberId] bigint,
					[OwnershipConsolidation] float,
					[ConsolidationMethodBM] int,
					[Account_RE] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Account_OCI] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[SourceDataClassID] int,
					[Filter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
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

				UPDATE EB
				SET
					[SourceDataClassID] = ISNULL(ES.[DataClassID], DC.[DataClassID]),
					[Filter] = ES.[Filter]
				FROM
					#EntityBook EB
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = @InstanceID AND DC.[VersionID] = @VersionID AND DC.[DataClassTypeID] = -5 AND DC.[SelectYN] <> 0 AND DC.[DeletedID] IS NULL
					LEFT JOIN [pcINTEGRATOR_Data].[dbo].[BR05_EntitySource] ES ON ES.[InstanceID] = DC.[InstanceID] AND ES.[VersionID] = DC.[VersionID] AND ES.[BusinessRuleID] = @BusinessRuleID AND ES.[Entity]= EB.[MemberKey] AND ES.[Book] = EB.[Book] AND ES.[Scenario] = @Scenario
					
				SET @SQLStatement = '
					UPDATE EB
					SET
						[Entity_MemberId] = E.[MemberId]
					FROM
						#EntityBook EB
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Entity] E ON E.[Label] = EB.[MemberKey] AND E.[Book] = EB.[Book]'
							
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @SQLStatement = '
					UPDATE EB
					SET
						[Currency_MemberId] = C.[MemberId]
					FROM
						#EntityBook EB
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Currency] C ON C.[Label] = EB.[Currency]'
							
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

			END

		IF @DebugBM & 2 > 0
			SELECT TempTable = '#EntityBook', * FROM #EntityBook

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

	SET @Step = 'Run LeafFilter_Cursor'
		IF CURSOR_STATUS('global','LeafFilter_Cursor') >= -1 DEALLOCATE LeafFilter_Cursor
		DECLARE LeafFilter_Cursor CURSOR FOR

			SELECT DISTINCT
				[Filter]
			FROM
				#EntityBook
			WHERE
				[SelectYN] <> 0 AND
				[SourceDataClassID] = @Financials_DataClassID AND
				[Filter] IS NOT NULL

			OPEN LeafFilter_Cursor
			FETCH NEXT FROM LeafFilter_Cursor INTO @Filter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @LoopNo = @LoopNo + 1
					SET @StepReference = 'CO_Financials_' + CONVERT(nvarchar(15), @LoopNo)
					IF @DebugBM & 2 > 0 SELECT [@LoopNo] = @LoopNo, [@StepReference] = @StepReference, [@Filter] = @Filter

					EXEC pcINTEGRATOR.dbo.[spGet_FilterTable]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@DataClassID = @Financials_DataClassID,
						@PipeString = @Filter,
						@DatabaseName = @CallistoDatabase, --Mandatory
						@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
						@StorageTypeBM = NULL, --Mandatory
						@StepReference = @StepReference,
--						@SQLFilter = @SQLFilter OUT,
						@Debug = @DebugSub

					SET @SQLFilter = ''
					SELECT
						@SQLFilter = @SQLFilter + 
							CASE WHEN ISNULL(FT.[LeafLevelFilter], '') <> '' AND ISNULL(FT.[PropertyName], '') = ''
							THEN
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.[' + FT.[DimensionName] + '_MemberId] IN (' + FT.[LeafLevelFilter] + ') AND'
							ELSE
								''
							END
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] = @StepReference

					IF LEN(@SQLFilter) > 0
						SET @SQLFilter = LEFT(@SQLFilter, LEN(@SQLFilter) - 4)

					UPDATE #EntityBook
					SET
						[LeafLevelFilter] = @SQLFilter
					WHERE
						[SelectYN] <> 0 AND
						[SourceDataClassID] = @Financials_DataClassID AND
						[Filter] = @Filter

					FETCH NEXT FROM LeafFilter_Cursor INTO @Filter
				END

		CLOSE LeafFilter_Cursor
		DEALLOCATE LeafFilter_Cursor

		IF @DebugBM & 2 > 0
			SELECT TempTable = '#EntityBook', * FROM #EntityBook WHERE [SelectYN] <> 0 AND [SourceDataClassID] = @Financials_DataClassID

/*

		EXEC pcINTEGRATOR.dbo.[spGet_FilterTable]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DataClassID = @Financials_DataClassID,
			@PipeString = @Filter,
			@DatabaseName = @CallistoDatabase, --Mandatory
			@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
			@StorageTypeBM = NULL, --Mandatory
			@StepReference = 'CO_Financials',
			@SQLFilter = @SQLFilter OUT,
			@Debug = @DebugSub


			SET @SQLFilter = ''
					SELECT
						@SQLFilter = @SQLFilter + 
							CASE WHEN ISNULL(FT.[LeafLevelFilter], '') <> '' AND ISNULL(FT.[PropertyName], '') = ''
							THEN
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.[' + FT.[DimensionName] + '_MemberId] IN (' + FT.[LeafLevelFilter] + ') AND'
							ELSE
								''
							END
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
*/

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
		IF CURSOR_STATUS('global','JournalBase_Cursor') >= -1 DEALLOCATE JournalBase_Cursor
		DECLARE JournalBase_Cursor CURSOR FOR

			SELECT DISTINCT
				[Entity] = EB.[MemberKey],
				[Book] = EB.[Book],
				[Currency_Book] = EB.[Currency],
				[Currency_Book_MemberId] = EB.[Currency_MemberId],
				[Entity_MemberId] = EB.[Entity_MemberId],
				[LeafLevelFilter] = EB.[LeafLevelFilter],
				[ConsolidationMethodBM] = EB.[ConsolidationMethodBM]
			FROM
				#EntityBook EB
			WHERE
				EB.[BookTypeBM] & 3 = 3 AND
				EB.[SelectYN] <> 0 AND
				EB.[SourceDataClassID] = @Financials_DataClassID

			OPEN JournalBase_Cursor
			FETCH NEXT FROM JournalBase_Cursor INTO @Entity, @Book, @Currency_Book, @Currency_Book_MemberId, @Entity_MemberId, @LeafLevelFilter, @ConsolidationMethodBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@Book] = @Book, [@Currency_Book] = @Currency_Book, [@Currency_Book_MemberId] = @Currency_Book_MemberId, [@Entity_MemberId] = @Entity_MemberId, [@LeafLevelFilter] = @LeafLevelFilter, [@ConsolidationMethodBM] = @ConsolidationMethodBM

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
							)'

					SET @SQLStatement = @SQLStatement + '
						SELECT
							[ReferenceNo] = 13000000 + ROW_NUMBER() OVER(ORDER BY FP.[FiscalYear], FP.[FiscalPeriod], [Account].[Label]),
							[ConsolidationMethodBM] = ' + CONVERT(nvarchar(15), @ConsolidationMethodBM) + ',
							[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
							[Entity] = ''' + @Entity + ''', 
							[Book] = ''' + @Book + ''',
							[FiscalYear] = FP.[FiscalYear],
							[FiscalPeriod] = FP.[FiscalPeriod],
							[JournalSequence] = ''FACT_Financials'',
							[JournalNo] = 23000000 + ROW_NUMBER() OVER(PARTITION BY FP.[FiscalYear] ORDER BY FP.[FiscalPeriod]),
							[JournalLine] = 1,
							[YearMonth] = FP.[YearMonth],
							[BalanceYN] = MAX(CONVERT(int, ISNULL(BA.[BalanceYN], 0))),
							[Account] = [Account].[Label],' + @SegmentString + '
							[JournalDate] = CONVERT(date, DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), FP.[FiscalYear]) + ''-'' + CONVERT(NVARCHAR(15), FP.[FiscalPeriod]) + ''-1''))),
							[TransactionDate] = CONVERT(date, DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), FP.[FiscalYear]) + ''-'' + CONVERT(NVARCHAR(15), FP.[FiscalPeriod]) + ''-1''))),
							[PostedDate] = CONVERT(date, GetDate()),
							[Source] = ''FACT'',
							[Flow] = '''', --V.[Flow],
							[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
							[InterCompanyEntity] = '''', --V.[InterCompany],
							[Scenario] = ''' + @Scenario + ''',
							[Customer] = '''', --V.[Customer],
							[Supplier] = '''', --V.[Supplier],
							[Description_Head] = ''Loaded from FACT_Financials'',
							[Description_Line] = '''',
							[Currency_Book] = ''' + @Currency_Book + ''',
							[Value_Book] = ROUND(SUM(CASE WHEN DC.[Currency_MemberId] = ' + CONVERT(nvarchar(20), @Currency_Book_MemberId) + ' AND DC.[Group_MemberId] = -1 THEN DC.[Financials_Value] ELSE 0 END), 4),
							[Currency_Group] = ''' + @Currency_Group + ''',
							[Value_Group] = ROUND(SUM(CASE WHEN DC.[Currency_MemberId] = ' + CONVERT(nvarchar(20), @Currency_Group_MemberId) + ' AND DC.[Group_MemberId] = ' + CONVERT(nvarchar(20), @ConsolidationGroup_MemberId) + ' THEN DC.[Financials_Value] ELSE 0 END), 4),
							[SourceModule] = ''FACT'',
							[SourceModuleReference] = NULL'

					SET @SQLStatement = @SQLStatement + '
						FROM
							[' + @CallistoDatabase + '].[dbo].[FACT_Financials_default_partition] DC
							INNER JOIN #FiscalPeriod FP ON FP.[YearMonth] = DC.[Time_MemberID] AND FP.[FiscalPeriod] BETWEEN 1 AND 12
							INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Account] [Account] ON [Account].[MemberId] = DC.[Account_MemberId] AND [Account].[Label] NOT IN (''CYNI_B'', ''PYNI_B'')
							LEFT JOIN #BalanceAccount BA ON BA.[Account_MemberKey] = [Account].[Label]' + @SegmentJoin + '
						WHERE
							DC.[Entity_MemberId] = ' + CONVERT(nvarchar(15), @Entity_MemberId) + ' AND 
							DC.[Scenario_MemberId] = ' + CONVERT(nvarchar(20), @Scenario_MemberId) + CASE WHEN LEN(@LeafLevelFilter) > 0 THEN ' AND' + @LeafLevelFilter ELSE '' END + ' AND
							DC.[BusinessRule_MemberId] = -1 AND
							DC.[Group_MemberId] = -1'

					SET @SQLStatement = @SQLStatement + '
						GROUP BY
							[Account].[Label],' + @SegmentGroupBy + '
							FP.[FiscalYear],
							FP.[FiscalPeriod],
							FP.[YearMonth]'
						--HAVING
						--	ROUND(SUM(CASE WHEN V.[Currency] = EB.[Currency] AND V.[Group] = ''NONE'' THEN V.[Financials_Value] ELSE 0 END), 4) <> 0 OR
						--	ROUND(SUM(CASE WHEN V.[Currency] = ''' + @Currency_Group + ''' AND V.[Group] = ''' + @ConsolidationGroup + ''' THEN V.[Financials_Value] ELSE 0 END), 4) <> 0'

					IF @DebugBM & 2 > 0 
						BEGIN
							IF LEN(@SQLStatement) > 4000 
								BEGIN
									PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Import data into #JournalBase.'
									EXEC [dbo].[spSet_wrk_Debug]
										@UserID = @UserID,
										@InstanceID = @InstanceID,
										@VersionID = @VersionID,
										@DatabaseName = @DatabaseName,
										@CalledProcedureName = @ProcedureName,
										@Comment = 'Import data into #JournalBase', 
										@SQLStatement = @SQLStatement,
										@JobID = @JobID
								END
							ELSE
								PRINT @SQLStatement
						END

					EXEC (@SQLStatement)


					FETCH NEXT FROM JournalBase_Cursor INTO @Entity, @Book, @Currency_Book, @Currency_Book_MemberId, @Entity_MemberId, @LeafLevelFilter, @ConsolidationMethodBM
				END

		CLOSE JournalBase_Cursor
		DEALLOCATE JournalBase_Cursor


/*
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
				)'

		SET @SQLStatement = @SQLStatement + '
			SELECT
				[ReferenceNo] = 13000000 + ROW_NUMBER() OVER(ORDER BY EB.[MemberKey], EB.[Book], FP.[FiscalYear], FP.[FiscalPeriod], [Account].[Label]),
				[ConsolidationMethodBM] = MAX(EB.[ConsolidationMethodBM]),
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[Entity] = EB.[MemberKey], 
				[Book] = EB.[Book],
				[FiscalYear] = FP.[FiscalYear],
				[FiscalPeriod] = FP.[FiscalPeriod],
				[JournalSequence] = ''FACT_Financials'',
				[JournalNo] = 23000000 + ROW_NUMBER() OVER(PARTITION BY EB.[MemberKey], EB.[Book], FP.[FiscalYear] ORDER BY FP.[FiscalPeriod]),
				[JournalLine] = 1,
				[YearMonth] = FP.[YearMonth],
				[BalanceYN] = MAX(CONVERT(int, ISNULL(BA.[BalanceYN], 0))),
				[Account] = [Account].[Label],' + @SegmentString + '
				[JournalDate] = CONVERT(date, DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), FP.[FiscalYear]) + ''-'' + CONVERT(NVARCHAR(15), FP.[FiscalPeriod]) + ''-1''))),
				[TransactionDate] = CONVERT(date, DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), FP.[FiscalYear]) + ''-'' + CONVERT(NVARCHAR(15), FP.[FiscalPeriod]) + ''-1''))),
				[PostedDate] = CONVERT(date, GetDate()),
				[Source] = ''FACT'',
				[Flow] = '''', --V.[Flow],
				[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
				[InterCompanyEntity] = '''', --V.[InterCompany],
				[Scenario] = ''' + @Scenario + ''',
				[Customer] = '''', --V.[Customer],
				[Supplier] = '''', --V.[Supplier],
				[Description_Head] = ''Loaded from FACT_Financials'',
				[Description_Line] = '''',
				[Currency_Book] = EB.[Currency],
				[Value_Book] = ROUND(SUM(CASE WHEN DC.[Currency_MemberId] = EB.[Currency_MemberId] AND DC.[Group_MemberId] = -1 THEN DC.[Financials_Value] ELSE 0 END), 4),
				[Currency_Group] = ''' + @Currency_Group + ''',
				[Value_Group] = ROUND(SUM(CASE WHEN DC.[Currency_MemberId] = ' + CONVERT(nvarchar(20), @Currency_Group_MemberId) + ' AND DC.[Group_MemberId] = ' + CONVERT(nvarchar(20), @ConsolidationGroup_MemberId) + ' THEN DC.[Financials_Value] ELSE 0 END), 4),
				[SourceModule] = ''FACT'',
				[SourceModuleReference] = NULL'

		SET @SQLStatement = @SQLStatement + '
			FROM
				[' + @CallistoDatabase + '].[dbo].[FACT_Financials_default_partition] DC
				INNER JOIN #EntityBook EB ON EB.Entity_MemberId = DC.[Entity_MemberId] AND EB.[BookTypeBM] & 3 = 3 AND EB.[SourceDataClassID] = ' + CONVERT(nvarchar(15), @Financials_DataClassID) + ' AND EB.[SelectYN] <> 0
				INNER JOIN #FiscalPeriod FP ON FP.[YearMonth] = DC.[Time_MemberID] AND FP.[FiscalPeriod] BETWEEN 1 AND 12
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Account] [Account] ON [Account].[MemberId] = DC.[Account_MemberId]
				LEFT JOIN #BalanceAccount BA ON BA.[Account_MemberKey] = [Account].[Label]' + @SegmentJoin + '
			WHERE
				DC.[Scenario_MemberId] = ' + CONVERT(nvarchar(20), @Scenario_MemberId) + CASE WHEN LEN(@SQLFilter) > 0 THEN ' AND' + @SQLFilter ELSE '' END + ' AND
				DC.[BusinessRule_MemberId] = -1 AND
				DC.[Group_MemberId] = -1'

		SET @SQLStatement = @SQLStatement + '
			GROUP BY
				EB.Book,
				[Account].[Label],' + @SegmentGroupBy + '
				EB.[Currency],
				EB.[MemberKey], --[Entity],
				--V.[Flow],
				--V.[Group],
				--V.InterCompany,
				--V.Scenario,
				--V.[Customer],
				--V.[Supplier],
				FP.[FiscalYear],
				FP.[FiscalPeriod],
				FP.[YearMonth]'
			--HAVING
			--	ROUND(SUM(CASE WHEN V.[Currency] = EB.[Currency] AND V.[Group] = ''NONE'' THEN V.[Financials_Value] ELSE 0 END), 4) <> 0 OR
			--	ROUND(SUM(CASE WHEN V.[Currency] = ''' + @Currency_Group + ''' AND V.[Group] = ''' + @ConsolidationGroup + ''' THEN V.[Financials_Value] ELSE 0 END), 4) <> 0'

		IF @DebugBM & 2 > 0 
			BEGIN
				IF LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Import data into #JournalBase.'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Import data into #JournalBase', 
							@SQLStatement = @SQLStatement,
							@JobID = @JobID
					END
				ELSE
					PRINT @SQLStatement
			END

		EXEC (@SQLStatement)
*/	
		IF @DebugBM & 8 > 0 
			BEGIN	
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

				SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY InterCompanyEntity, Entity, Book, Account, Segment01, Segment02, Segment03, Segment04, Segment05, FiscalYear, FiscalPeriod, YearMonth
			END

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
