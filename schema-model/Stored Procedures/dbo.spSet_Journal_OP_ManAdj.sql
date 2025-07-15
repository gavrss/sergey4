SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_Journal_OP_ManAdj]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
	@JournalTable nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000798,
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
EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @Debug=1
EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear=2018
EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear=2019
EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear=2020
EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear=2021
EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear=2022
EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear=2023

EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @Entity = 'GGI03', @Book = 'MOROCCO', @FiscalYear=2020, @Debug=1

EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=531, @VersionID=1057, @FiscalYear=2020
EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=531, @VersionID=1057, @FiscalYear=2021, @Debug=1
EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=572, @VersionID=1080, @FiscalYear=2019, @Debug=1

EXEC [spSet_Journal_OP_ManAdj] @UserID=-10, @InstanceID=572, @VersionID=1080, @FiscalYear=2022, @Debug=1

EXEC [spSet_Journal_OP_ManAdj] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
--	@Account_RE nvarchar(50) = '3560',
	@SQLStatement nvarchar(max),
	@CalledYN bit = 1,
	@StartMonth int,
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2187'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Add carry forward of manually entered balance rows.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2174' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2176' SET @Description = 'Adjusted sign for Credit rows.'
		IF @Version = '2.1.1.2177' SET @Description = 'Distinguish by Segments.'
		IF @Version = '2.1.2.2179' SET @Description = 'Made generic.'
		IF @Version = '2.1.2.2187' SET @Description = 'Made generic dates.'

--		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		IF @JournalTable IS NULL EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT, @JobID = @JobID

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SET @SQLStatement = '
			SELECT @InternalVariable = MIN(MemberID) FROM [' + @CallistoDatabase +'].[dbo].[S_DS_Time] WHERE [Level] = ''Month'' AND [TimeFiscalYear_MemberID] = ' + CONVERT(nvarchar(15), @FiscalYear)

		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @StartMonth OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@JournalTable] = @JournalTable,
				[@CallistoDatabase] = @CallistoDatabase,
				[@StartMonth] = @StartMonth

	SET @Step = 'Create temp and fill temp table #EntityBook'
		IF OBJECT_ID(N'TempDB.dbo.#EntityBook', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

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
			
				INSERT INTO #EntityBook
					(
					[EntityID],
					[MemberKey],
					[Book],
					[BookTypeBM],
					[Currency],
					[SelectYN]
					)
				SELECT 
					[EntityID] = E.[EntityID],
					[MemberKey] = E.[MemberKey],
					[Book] = EB.[Book],
					[BookTypeBM] = EB.[BookTypeBM],
					[Currency] = EB.[Currency],
					[SelectYN] = CASE WHEN E.[MemberKey] = @Entity OR @Entity IS NULL THEN 1 ELSE 0 END
				FROM 
					Entity E
					INNER JOIN Entity_Book EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND (EB.[Book] = @Book OR @Book IS NULL) AND EB.[BookTypeBM] & 18 > 0 AND EB.[SelectYN] <> 0
				WHERE
					E.[InstanceID] = @InstanceID AND
					E.[VersionID] = @VersionID AND
					E.[SelectYN] <> 0 AND
					E.[DeletedID] IS NULL
				ORDER BY
					E.[MemberKey],
					EB.[Book]

				UPDATE EB
				SET
					[Account_RE] = LTRIM(RTRIM(EPV.[EntityPropertyValue]))
				FROM
					#EntityBook EB
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV ON EPV.[InstanceID] = @InstanceID AND EPV.[VersionID] = @VersionID AND EPV.[EntityID] = EB.[EntityID] AND EPV.[EntityPropertyTypeID] = -10 AND EPV.[SelectYN] <> 0
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#EntityBook', * FROM #EntityBook

	SET @Step = 'Insert into #JournalValues'
		CREATE TABLE #JournalValues
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] int,
			[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Account_RE] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment01] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment02] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment03] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment04] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment05] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment06] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment07] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment08] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment09] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment10] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment11] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment12] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment13] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment14] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment15] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment16] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment17] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment18] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment19] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Segment20] nvarchar(50) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[Currency_Book] nchar(3) COLLATE DATABASE_DEFAULT,
			[Value_Book] float
			)

		SET @SQLStatement = '
			INSERT INTO #JournalValues
				(
				[Entity],
				[Book],
				[FiscalYear],
				[Account],
				[Account_RE],
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
				[Currency_Book],
				[Value_Book]
				)
			SELECT 
				[Entity] = J.[Entity],
				[Book] = J.[Book],
				[FiscalYear] = J.[FiscalYear],
				[Account] = J.[Account],
				[Account_RE] = MAX(EB.[Account_RE]),
				[Segment01] = ISNULL(J.[Segment01],''NONE''),
				[Segment02] = ISNULL(J.[Segment02],''NONE''),
				[Segment03] = ISNULL(J.[Segment03],''NONE''),
				[Segment04] = ISNULL(J.[Segment04],''NONE''),
				[Segment05] = ISNULL(J.[Segment05],''NONE''),
				[Segment06] = ISNULL(J.[Segment06],''NONE''),
				[Segment07] = ISNULL(J.[Segment07],''NONE''),
				[Segment08] = ISNULL(J.[Segment08],''NONE''),
				[Segment09] = ISNULL(J.[Segment09],''NONE''),
				[Segment10] = ISNULL(J.[Segment10],''NONE''),
				[Segment11] = ISNULL(J.[Segment11],''NONE''),
				[Segment12] = ISNULL(J.[Segment12],''NONE''),
				[Segment13] = ISNULL(J.[Segment13],''NONE''),
				[Segment14] = ISNULL(J.[Segment14],''NONE''),
				[Segment15] = ISNULL(J.[Segment15],''NONE''),
				[Segment16] = ISNULL(J.[Segment16],''NONE''),
				[Segment17] = ISNULL(J.[Segment17],''NONE''),
				[Segment18] = ISNULL(J.[Segment18],''NONE''),
				[Segment19] = ISNULL(J.[Segment19],''NONE''),
				[Segment20] = ISNULL(J.[Segment20],''NONE''),
				[Currency_Book] = J.[Currency_Book],
				[Value_Book] = ROUND(SUM(J.[ValueDebit_Book]-J.[ValueCredit_Book]), 4)
			FROM
				' + @JournalTable + ' J
				INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[BookTypeBM] & 1 > 0 AND EB.[Account_RE] IS NOT NULL AND EB.[SelectYN] <> 0
			WHERE
				' + CASE WHEN @FiscalYear IS NOT NULL THEN 'J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' - 1 AND' ELSE '' END + '
				J.[Scenario] = ''' + @Scenario + ''' AND 
				J.[TransactionTypeBM] & 16 > 0 AND
				J.[PostedStatus] <> 0 AND
				J.[ConsolidationGroup] IS NULL AND
				J.[BalanceYN] <> 0 AND
				J.[SourceModule] = ''MANUAL''
			GROUP BY
				J.[Entity],
				J.[Book],
				J.[FiscalYear],
				J.[Account],
				ISNULL(J.[Segment01],''NONE''),
				ISNULL(J.[Segment02],''NONE''),
				ISNULL(J.[Segment03],''NONE''),
				ISNULL(J.[Segment04],''NONE''),
				ISNULL(J.[Segment05],''NONE''),
				ISNULL(J.[Segment06],''NONE''),
				ISNULL(J.[Segment07],''NONE''),
				ISNULL(J.[Segment08],''NONE''),
				ISNULL(J.[Segment09],''NONE''),
				ISNULL(J.[Segment10],''NONE''),
				ISNULL(J.[Segment11],''NONE''),
				ISNULL(J.[Segment12],''NONE''),
				ISNULL(J.[Segment13],''NONE''),
				ISNULL(J.[Segment14],''NONE''),
				ISNULL(J.[Segment15],''NONE''),
				ISNULL(J.[Segment16],''NONE''),
				ISNULL(J.[Segment17],''NONE''),
				ISNULL(J.[Segment18],''NONE''),
				ISNULL(J.[Segment19],''NONE''),
				ISNULL(J.[Segment20],''NONE''),
				J.[Currency_Book]
			HAVING
				ROUND(SUM(J.[ValueDebit_Book]-J.[ValueCredit_Book]), 4) <> 0.0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#JournalValues_1', * FROM #JournalValues ORDER BY [Entity], [Book], [FiscalYear], [Account]

	SET @Step = 'Delete previous calculated rows from Journal'
		SET @SQLStatement = '
			DELETE J
			FROM
				' + @JournalTable + ' J
				INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[BookTypeBM] & 1 > 0 AND EB.[Account_RE] IS NOT NULL AND EB.[SelectYN] <> 0
			WHERE
				' + CASE WHEN @FiscalYear IS NOT NULL THEN 'J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND' ELSE '' END + '
				J.[FiscalPeriod] = 0 AND
				J.[Scenario] = ''' + @Scenario + ''' AND 
				J.[TransactionTypeBM] & 16 > 0 AND
				J.[ConsolidationGroup] IS NULL AND
				J.[SourceModule] = ''MANUAL'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

		IF @DebugBM & 2 > 0 SELECT [@Deleted] = @Deleted

	SET @Step = 'Insert into Journal'
		IF @DebugBM & 2 > 0
			SELECT
				[TempTable] = '#JournalValues_2',
				[Entity],
				[Book],
				[FiscalYear],
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
				[Currency_Book],
				[Value_Book]
			FROM
				(
				SELECT 
					[Entity],
					[Book],
					[FiscalYear] = [FiscalYear] + 1,
					[BalanceYN] = 1,
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
					[Currency_Book],
					[Value_Book] = SUM([Value_Book])
				FROM
					#JournalValues JV
				GROUP BY
					[Entity],
					[Book],
					[FiscalYear],
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
					[Currency_Book]
				
				UNION SELECT 
					[Entity],
					[Book],
					[FiscalYear] = [FiscalYear] + 1,
					[BalanceYN] = 1,
					[Account] = [Account_RE],
					[Segment01] = 'NONE',
					[Segment02] = 'NONE',
					[Segment03] = 'NONE',
					[Segment04] = 'NONE',
					[Segment05] = 'NONE',
					[Segment06] = 'NONE',
					[Segment07] = 'NONE',
					[Segment08] = 'NONE',
					[Segment09] = 'NONE',
					[Segment10] = 'NONE',
					[Segment11] = 'NONE',
					[Segment12] = 'NONE',
					[Segment13] = 'NONE',
					[Segment14] = 'NONE',
					[Segment15] = 'NONE',
					[Segment16] = 'NONE',
					[Segment17] = 'NONE',
					[Segment18] = 'NONE',
					[Segment19] = 'NONE',
					[Segment20] = 'NONE',
					[Currency_Book],
					[Value_Book] = SUM([Value_Book]) * -1
				FROM
					#JournalValues JV
				GROUP BY
					[Account_RE],
					[Entity],
					[Book],
					[FiscalYear],
					[Currency_Book]
				
				HAVING
					ROUND(SUM([Value_Book]), 4) <> 0.0
				) sub
			ORDER BY
				[Entity],
				[Book],
				[FiscalYear],
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
				[Segment20]

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
				[Flow],
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
				)'

		SET @SQLStatement = @SQLStatement + '
			SELECT
				[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[Entity],
				[Book],
				[FiscalYear],
				[FiscalPeriod] = 0,
				[JournalSequence] = sub.[JournalSequence],
				[JournalNo] = 0,
				[JournalLine] = 0,
				[YearMonth] = ' + CONVERT(nvarchar(15), @StartMonth) + ',
				[TransactionTypeBM] = 16,
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
				[JournalDate] = ''' + CONVERT(nvarchar(15), @StartMonth / 100) + '-' + CONVERT(nvarchar(15), @StartMonth % 100) + '-01' + ''',
				[TransactionDate] = ''' + CONVERT(nvarchar(15), @StartMonth / 100) + '-' + CONVERT(nvarchar(15), @StartMonth % 100) + '-01' + ''',
				[PostedDate] = GetDate(),
				[PostedStatus] = 1,
				[PostedBy] = ''' + @UserName + ''',
				[Source] = ''MANUAL'',
				[Flow] = ''OP_Opening'',
				[Scenario] = ''' + @Scenario + ''',
				[Customer] = '''',
				[Supplier] = '''',
				[Description_Head] = ''Carry forward manual entries'',
				[Description_Line] = NULL,
				[Currency_Book],
				[ValueDebit_Book] = CASE WHEN [Value_Book] > 0 THEN [Value_Book] ELSE 0 END,
				[ValueCredit_Book] = CASE WHEN [Value_Book] < 0 THEN [Value_Book] * -1 ELSE 0 END,
				[Currency_Group] = NULL,
				[ValueDebit_Group] = NULL,
				[ValueCredit_Group] = NULL,
				[Currency_Transaction] = NULL,
				[ValueDebit_Transaction] = NULL,
				[ValueCredit_Transaction] = NULL,
				[SourceModule] = ''MANUAL'',
				[SourceModuleReference] = NULL,
				[SourceCounter] = NULL,
				[SourceGUID] = NULL,
				[Inserted] = GetDate(),
				[InsertedBy] = suser_name()'

		SET @SQLStatement = @SQLStatement + '
			FROM
				(
				SELECT 
					[Entity],
					[Book],
					[FiscalYear] = [FiscalYear] + 1,
					[JournalSequence] = ''OB_MAN'',
					[BalanceYN] = 1,
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
					[Currency_Book],
					[Value_Book] = SUM([Value_Book])
				FROM
					#JournalValues JV
				GROUP BY
					[Entity],
					[Book],
					[FiscalYear],
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
					[Currency_Book]

				UNION SELECT 
					[Entity],
					[Book],
					[FiscalYear] = [FiscalYear] + 1,
					[JournalSequence] = ''OB_MAN_RE'',
					[BalanceYN] = 1,
					[Account] = [Account_RE],
					[Segment01] = ''NONE'',
					[Segment02] = ''NONE'',
					[Segment03] = ''NONE'',
					[Segment04] = ''NONE'',
					[Segment05] = ''NONE'',
					[Segment06] = ''NONE'',
					[Segment07] = ''NONE'',
					[Segment08] = ''NONE'',
					[Segment09] = ''NONE'',
					[Segment10] = ''NONE'',
					[Segment11] = ''NONE'',
					[Segment12] = ''NONE'',
					[Segment13] = ''NONE'',
					[Segment14] = ''NONE'',
					[Segment15] = ''NONE'',
					[Segment16] = ''NONE'',
					[Segment17] = ''NONE'',
					[Segment18] = ''NONE'',
					[Segment19] = ''NONE'',
					[Segment20] = ''NONE'',
					[Currency_Book],
					[Value_Book] = SUM([Value_Book]) * -1
				FROM
					#JournalValues JV
				GROUP BY
					[Entity],
					[Book],
					[FiscalYear],
					[Account_RE],
					[Currency_Book]
				HAVING
					ROUND(SUM([Value_Book]), 4) <> 0.0
				) sub'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @DebugBM & 2 > 0 SELECT [@Inserted] = @Inserted

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
