SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_iScala_Test20230602]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL, --Not in use
	@FiscalPeriodString nvarchar(1000) = NULL, --Not in use
	@StartFiscalYear int = NULL, --Not in use
	@SequenceBM int = 3, --1 = GL transactions, 2 = Opening balances, 4 = Budget transactions
	@JournalTable nvarchar(100) = NULL,
	@FullReloadYN bit = 0,
	@MaxSourceCounter bigint = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000746,
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
EXEC [spIU_DC_Journal_iScala] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = '18', @Book = 'GL', @FiscalYear = 2020, @SequenceBM = 3, @DebugBM = 3
EXEC [spIU_DC_Journal_iScala] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = '42', @Book = 'GL', @FiscalYear = 2020, @SequenceBM = 3, @DebugBM = 3
EXEC [spIU_DC_Journal_iScala_Test20230602] @UserID = -10, @InstanceID = 621, @VersionID = 1105, @Entity_MemberKey = 'NC', @Book = 'GL', @FiscalYear = 2023, @SequenceBM = 3, @DebugBM = 3

EXEC [spIU_DC_Journal_iScala] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@JSON nvarchar(max),
	@CalledYN bit = 1,
	@SourceDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@SourceTable nvarchar(100),
	@CurrencyTable nvarchar(100),
	@LinkedServer nvarchar(100),
	@EntityID int,
	@Currency nchar(3),
	@SQLStatement nvarchar(max),
	@SQLSegment nvarchar(max),
	@SegmentNo int = -1,
	@AccountSourceCode nvarchar(50),
	@AccountSegmentNo int,
	@GL06_ExistsYN bit,
--	@BalAcctDesc_ExistsYN bit,
--	@RevisionBM int = 1,
	@SourceID int,
	@SourceTypeID int,
	@SequenceOB int,
	@SourceTypeName nvarchar(50),
	@FiscalYearStartMonth int,
	@FiscalYearStartMonthAdjust int,

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
	@Version nvarchar(50) = '2.1.1.2170'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into #Journal from source iScala',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2165' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Added LTRIM(RTRIM( on iScala Segment. Proper handling of Journal Number and Open Balance.'
		IF @Version = '2.1.1.2170' SET @Description = 'Handle Transaction currency.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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
			@EntityID = E.EntityID,
			@Currency = EB.Currency
		FROM
			Entity E
			INNER JOIN Entity_Book EB ON EB.EntityID = E.EntityID AND EB.Book = @Book AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.MemberKey = @Entity_MemberKey AND
			E.SelectYN <> 0

		SELECT
			@SourceID = S.[SourceID],
			@SourceTypeID = S.[SourceTypeID],
			@SourceTypeName = ST.[SourceTypeName],
			@CallistoDatabase = A.[DestinationDatabase],
			@FiscalYearStartMonth = A.[FiscalYearStartMonth]
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = 2
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SELECT
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(EPV.EntityPropertyValue, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			pcINTEGRATOR_Data..EntityPropertyValue EPV
		WHERE
			EPV.InstanceID = @InstanceID AND
			EPV.VersionID = @VersionID AND
			EPV.EntityID = @EntityID AND
			EPV.EntityPropertyTypeID = -1 AND
			EPV.SelectYN <> 0

		SET @SourceTable = 'GL06' + LEFT(@Entity_MemberKey, 2) + CONVERT(nvarchar(15), @FiscalYear % 100)
		SET @CurrencyTable = 'SYCD' + LEFT(@Entity_MemberKey, 2) + '00'
		

		EXEC spGet_TableExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = @SourceTable, @ExistsYN = @GL06_ExistsYN OUT

		SET @SourceTable = '[' + @SourceTable +']'

		IF CHARINDEX('.', @SourceDatabase) <> 0
			SET @LinkedServer = REPLACE(REPLACE(LEFT(@SourceDatabase, CHARINDEX('.', @SourceDatabase) - 1), '[', ''), ']', '')

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

--		SET @FiscalYearStartMonthAdjust = CASE WHEN @FiscalYearStartMonth = 1 THEN 0 ELSE  END
		
		IF @DebugBM & 2 > 0
			SELECT 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@CallistoDatabase] = @CallistoDatabase,
				[@SourceDatabase] = @SourceDatabase,
				[@SourceTable] = @SourceTable,
				[@GL06_ExistsYN] = @GL06_ExistsYN,
				[@LinkedServer] = @LinkedServer,
				[@Currency] = @Currency,
				[@EntityID] = @EntityID,
				[@Book] = @Book,
				[@JournalTable] = @JournalTable,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName,
				[@FiscalYearStartMonth] = @FiscalYearStartMonth

	SET @Step = 'Exit SP if @SourceTable does not exists'
		IF @GL06_ExistsYN = 0
			BEGIN
				SET @Message = 'Sourcetable ' + @SourceTable + ' does not exists.'
				SET @Severity = 0
				GOTO NoTable
			END

	SET @Step = 'Initialize connection to linked server'
		IF @SequenceBM & 3 > 0 AND @LinkedServer IS NOT NULL
			EXEC [spGet_Connection] @LinkedServer = @LinkedServer

		--IF @SequenceBM & 1 > 0 
		--	BEGIN
		--		EXEC spGet_TableExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = 'InvcHead', @ExistsYN = @InvcHead_ExistsYN OUT
		--		EXEC spGet_TableExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = 'Customer', @ExistsYN = @Customer_ExistsYN OUT

		--		SET @Customer_ExistsYN = CONVERT(int, @InvcHead_ExistsYN) * CONVERT(int, @Customer_ExistsYN)
		--	END

		--IF @SequenceBM & 2 > 0 
		--	EXEC spGet_ColumnExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = 'GLPeriodBal', @ColumnName = 'BalAcctDesc', @ExistsYN = @BalAcctDesc_ExistsYN OUT

		--IF @DebugBM & 2 > 0
		--	SELECT 
		--		[@Customer_ExistsYN] = @Customer_ExistsYN,
		--		[@BalAcctDesc_ExistsYN] = @BalAcctDesc_ExistsYN

	SET @Step = 'Create and fill temp table #TransactionType_iScala'
		CREATE TABLE [#TransactionType_iScala]
			(
			[Hex] [nchar](4),
			[Group] [nvarchar](50),
			[Period] [nvarchar](2),
			[Scenario] [nvarchar](50),
			[Symbol] [nchar](1),
			[Description] [nvarchar](100),
			[BusinessProcess] [nvarchar](50),
			[SelectYN] [bit]
			)

		INSERT INTO [#TransactionType_iScala]
			(
			[Hex],
			[Group],
			[Period],
			[Scenario],
			[Symbol],
			[Description],
			[BusinessProcess],
			[SelectYN]
			)
		SELECT
			[Hex],
			[Group],
			[Period],
			[Scenario],
			[Symbol],
			[Description],
			[BusinessProcess],
			[SelectYN]
		FROM
			pcINTEGRATOR_Data..[TransactionType_iScala]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		INSERT INTO [#TransactionType_iScala]
			(
			[Hex],
			[Group],
			[Period],
			[Scenario],
			[Symbol],
			[Description],
			[BusinessProcess],
			[SelectYN]
			)
		SELECT
			[Hex],
			[Group],
			[Period],
			[Scenario],
			[Symbol],
			[Description],
			[BusinessProcess],
			[SelectYN]
		FROM
			pcINTEGRATOR..[@Template_TransactionType_iScala] S
		WHERE
			[InstanceID] = 0 AND
			[VersionID] = 0 AND
			NOT EXISTS (SELECT 1 FROM [#TransactionType_iScala] D WHERE D.[Hex] = S.[Hex])

		IF @DebugBM & 2 > 0 SELECT TempTable = '[#TransactionType_iScala]', * FROM [#TransactionType_iScala] ORDER BY [Hex]

	SET @Step = 'Create and fill temp table #Segment'
		CREATE TABLE #Segment
			(
			SegmentNo int,
			DimensionName nvarchar(50) COLLATE DATABASE_DEFAULT,
			MaskPosition int,
			MaskCharacters int
			)

		INSERT INTO #Segment
			(
			SegmentNo,
			DimensionName,
			MaskPosition,
			MaskCharacters
			)
		SELECT 
			JSN.SegmentNo,
			D.DimensionName,
			JSN.MaskPosition,
			JSN.MaskCharacters
		FROM
			Journal_SegmentNo JSN
			LEFT JOIN Dimension D ON D.DimensionID = JSN.DimensionID
		WHERE
			JSN.EntityID = @EntityID AND
			JSN.Book = @Book AND
			JSN.SelectYN <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment', * FROM #Segment ORDER BY SegmentNo

	SET @Step = 'Set variable @SQLSegment'
		WHILE @SegmentNo < 20
			BEGIN
				SET @SegmentNo = @SegmentNo + 1
				INSERT INTO #Segment ([SegmentNo]) SELECT [SegmentNo] = @SegmentNo WHERE NOT EXISTS (SELECT 1 FROM #Segment SD WHERE SD.[SegmentNo] = @SegmentNo)
				IF @SegmentNo = 0
					BEGIN
						SELECT @AccountSourceCode = MAX(CASE WHEN [SegmentNo] = @SegmentNo THEN 'SUBSTRING(GL06.[GL06001], ' + CONVERT(nvarchar(15), MaskPosition) + ', ' + CONVERT(nvarchar(15), MaskCharacters) + ')' ELSE '''''' END) FROM #Segment
						SELECT @SQLSegment = '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN 'SUBSTRING(GL06.[GL06001], ' + CONVERT(nvarchar(15), MaskPosition) + ', ' + CONVERT(nvarchar(15), MaskCharacters) + ')' ELSE '''''' END) + ',' FROM #Segment
					END
				ELSE
					SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), @SegmentNo) + '] = ' + CASE WHEN [DimensionName] IS NULL THEN '''''' ELSE 'LTRIM(RTRIM(SUBSTRING(GL06.[GL06001], ' + CONVERT(nvarchar(15), MaskPosition) + ', ' + CONVERT(nvarchar(15), MaskCharacters) + ')))' END + ',' FROM #Segment WHERE SegmentNo = @SegmentNo
			END

		IF @DebugBM & 2 > 0 SELECT [@AccountSourceCode] = @AccountSourceCode
		IF @DebugBM & 2 > 0 PRINT @SQLSegment

	SET @Step = 'Create and fill temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)

		IF @DebugBM & 2 > 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@EntityID] = @EntityID, [@Book] = @Book, [@FiscalYear] = @FiscalYear
		
		EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @FiscalYear = @FiscalYear, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @JobID = @JobID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod

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
				RNodeType = ''L'' AND
				TimeBalance <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#BalanceAccount', * FROM #BalanceAccount ORDER BY [Account_MemberKey]

	SET @Step = 'Test step'
/*
			SELECT
				[JobID] = 880000746,
				[InstanceID] = 621,
				[Entity] = 'NC',
				[Book] = 'GL',
				TTiS.[Symbol],
				CONVERT(binary(1), TTiS.[Symbol]),
				GL06.[GL06012],
				GL06.[GL06003],

				[FiscalYear] = FP.[FiscalYear],
				[FiscalPeriod] = FP.[FiscalPeriod],
				[JournalSequence] = GL06.[GL06038],
				[JournalNo] = CASE WHEN FP.[FiscalPeriod] = 0 THEN '0' ELSE GL06.[GL06023] END,
				[JournalLine] = CASE WHEN FP.[FiscalPeriod] = 0 THEN 0 ELSE ROW_NUMBER() OVER (PARTITION BY GL06.[GL06023] ORDER BY GL06.[GL06016]) END,
				[YearMonth] = FP.[YearMonth],
				[TransactionTypeBM] = CASE WHEN LEFT(SUBSTRING(GL06.[GL06001], 1, 6), 1) = '9' OR (ISNULL(BA.[BalanceYN], 0) = 0 AND TTiS.[Period] = '0') THEN 32 ELSE 1 END,
				[BalanceYN] = ISNULL(BA.[BalanceYN], 0),
				[Account] = SUBSTRING(GL06.[GL06001], 1, 6),
				[Segment01] = LTRIM(RTRIM(SUBSTRING(GL06.[GL06001], 7, 6))),
				[Segment02] = LTRIM(RTRIM(SUBSTRING(GL06.[GL06001], 13, 6))),
				[Segment03] = LTRIM(RTRIM(SUBSTRING(GL06.[GL06001], 19, 10))),
				[JournalDate] = GL06.[GL06014],
				[TransactionDate] = CASE WHEN FP.[FiscalPeriod]=0 THEN LEFT(FP.[YearMonth], 4) + '-' + RIGHT(FP.[YearMonth], 2) + '-01' ELSE GL06.[GL06003] END,
				[PostedDate] = GL06.[GL06042],
				[PostedStatus] = 1,
				[PostedBy] = GL06.[GL06013],
				[Source] = 'iScala',
				[Scenario] = TTiS.[Scenario],
				[Customer] = CASE WHEN TTiS.[Symbol] IN ('3', '4') THEN GL06.[GL06006] ELSE NULL END,
				[Supplier] = CASE WHEN TTiS.[Symbol] IN ('5', '6') THEN GL06.[GL06006] ELSE NULL END,
				[Description_Head] = NULL,
				[Description_Line] = GL06.[GL06005],
				[Currency_Book] = 'GBP',
				[ValueDebit_Book] = CASE WHEN (CASE WHEN [GL06017]<>0 AND TTiS.[Symbol] NOT IN ('1', 'S') THEN -1 ELSE 1 END * GL06.[GL06004]) > 0 THEN (CASE WHEN [GL06017]<>0 AND TTiS.[Symbol] NOT IN ('1', 'S') THEN -1 ELSE 1 END * GL06.[GL06004]) ELSE 0 END,
				[ValueCredit_Book] = CASE WHEN (CASE WHEN [GL06017]<>0 AND TTiS.[Symbol] NOT IN ('1', 'S') THEN -1 ELSE 1 END * GL06.[GL06004]) < 0 THEN (CASE WHEN [GL06017]<>0 AND TTiS.[Symbol] NOT IN ('1', 'S') THEN -1 ELSE 1 END * GL06.[GL06004]) * -1 ELSE 0 END,

				[Currency_Transaction] = ISNULL(SYCD.[SYCD009], GL06.[GL06019]),
				[ValueDebit_Transaction] = CASE WHEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06018]) > 0 THEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06018]) ELSE 0 END,
				[ValueCredit_Transaction] = CASE WHEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06018]) < 0 THEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06018]) * -1 ELSE 0 END,
				[SourceModule] = GL06.[GL06038],
				[SourceModuleReference] = GL06.[GL06002],
				[SourceCounter] = GL06.[GL06016],
				[SourceGUID] = NULL
			FROM 
				[dspsource04].[PGL_ScaCompanyDB].[dbo].[GL06NC23] GL06
				INNER JOIN [#TransactionType_iScala] TTiS ON CONVERT(binary(1), TTiS.[Symbol]) = GL06.[GL06012] AND TTiS.[SelectYN] <> 0
				INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = 2023 AND FP.FiscalPeriod = CASE TTiS.[BusinessProcess] WHEN 'FP0' THEN 0 WHEN 'FP13' THEN 13 ELSE MONTH(GL06.[GL06003]) + CASE WHEN MONTH(GL06.[GL06003]) > 8 THEN - 8 ELSE 4 END END
				LEFT JOIN #BalanceAccount BA ON BA.Account_MemberKey = SUBSTRING(GL06.[GL06001], 1, 6) COLLATE DATABASE_DEFAULT
				LEFT JOIN [dspsource04].[PGL_ScaCompanyDB].[dbo].SYCDNC00 SYCD ON SYCD.[SYCD001] = GL06.[GL06019]
			WHERE
				--GL06.[GL06019] = 0 AND
				(GL06.[GL06016] > 0 OR 0 <> 0) AND
				CASE WHEN LEFT(SUBSTRING(GL06.[GL06001], 1, 6), 1) = '9' OR (ISNULL(BA.[BalanceYN], 0) = 0 AND TTiS.[Period] = '0') THEN 32 ELSE 1 END = 1 AND
				FP.[FiscalPeriod] <> 0 AND
				1 = 1
			ORDER BY
			FP.[FiscalPeriod],
				GL06.[GL06038],
				GL06.[GL06002],
				GL06.[GL06016]

		RETURN
*/
	SET @Step = 'Create temp table #Journal'
		IF OBJECT_ID(N'TempDB.dbo.#Journal', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

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
					[Segment01] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment02] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment03] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment04] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment05] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment06] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment07] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment08] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment09] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment10] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment11] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment12] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment13] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment14] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment15] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment16] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment17] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment18] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment19] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment20] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalDate] [date],
					[TransactionDate] [date],
					[PostedDate] [date],
					[PostedStatus] [int],
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
			END

	SET @Step = 'Insert GL06 transactions into temp table #Journal'
		SET @SQLStatement = '
			INSERT INTO #Journal
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
				[Currency_Transaction],
				[ValueDebit_Transaction],
				[ValueCredit_Transaction],
				[SourceModule],
				[SourceModuleReference],
				[SourceCounter],
				[SourceGUID]
				)'

		SET @SQLStatement = @SQLStatement + '
			SELECT
				[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[Entity] = ''' + @Entity_MemberKey + ''',
				[Book] = ''' + @Book + ''',
				[FiscalYear] = FP.[FiscalYear],
				[FiscalPeriod] = FP.[FiscalPeriod],
				[JournalSequence] = GL06.[GL06038],
				[JournalNo] = CASE WHEN FP.[FiscalPeriod] = 0 THEN ''0'' ELSE GL06.[GL06023] END,
				[JournalLine] = CASE WHEN FP.[FiscalPeriod] = 0 THEN 0 ELSE ROW_NUMBER() OVER (PARTITION BY GL06.[GL06023] ORDER BY GL06.[GL06016]) END,
				[YearMonth] = FP.[YearMonth],
				[TransactionTypeBM] = CASE WHEN LEFT(' + @AccountSourceCode + ', 1) = ''9'' OR (ISNULL(BA.[BalanceYN], 0) = 0 AND TTiS.[Period] = ''0'') THEN 32 ELSE 1 END,
				[BalanceYN] = ISNULL(BA.[BalanceYN], 0),
				' + @SQLSegment + '
				[JournalDate] = GL06.[GL06014],
				[TransactionDate] = CASE WHEN FP.[FiscalPeriod]=0 THEN LEFT(FP.[YearMonth], 4) + ''-'' + RIGHT(FP.[YearMonth], 2) + ''-01'' ELSE GL06.[GL06003] END,
				[PostedDate] = GL06.[GL06042],
				[PostedStatus] = 1,
				[PostedBy] = GL06.[GL06013],
				[Source] = ''' + @SourceTypeName + ''',
				[Scenario] = TTiS.[Scenario],
				[Customer] = CASE WHEN TTiS.[Symbol] IN (''3'', ''4'') THEN GL06.[GL06006] ELSE NULL END,
				[Supplier] = CASE WHEN TTiS.[Symbol] IN (''5'', ''6'') THEN GL06.[GL06006] ELSE NULL END,
				[Description_Head] = NULL,
				[Description_Line] = GL06.[GL06005],
				[Currency_Book] = ''' + @Currency + ''',
				--[ValueDebit_Book] = CASE WHEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06004]) > 0 THEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06004]) ELSE 0 END,
				--[ValueCredit_Book] = CASE WHEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06004]) < 0 THEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06004]) * -1 ELSE 0 END,

				--[ValueDebit_Book] = CASE WHEN (CASE WHEN [GL06017]=0 THEN 1 ELSE -1 END * CASE WHEN TTiS.[Symbol]=''1'' THEN -1 ELSE 1 END * GL06.[GL06004]) > 0 THEN (CASE WHEN [GL06017]=0 THEN 1 ELSE -1 END * CASE WHEN TTiS.[Symbol]=''1'' THEN -1 ELSE 1 END * GL06.[GL06004]) ELSE 0 END,
				--[ValueCredit_Book] = CASE WHEN (CASE WHEN [GL06017]=0 THEN 1 ELSE -1 END * CASE WHEN TTiS.[Symbol]=''1'' THEN -1 ELSE 1 END * GL06.[GL06004]) < 0 THEN (CASE WHEN [GL06017]=0 THEN 1 ELSE -1 END * CASE WHEN TTiS.[Symbol]=''1'' THEN -1 ELSE 1 END * GL06.[GL06004]) * -1 ELSE 0 END,

				[ValueDebit_Book] = CASE WHEN (CASE WHEN [GL06017]<>0 AND TTiS.[Symbol] NOT IN (''1'', ''S'') THEN -1 ELSE 1 END * GL06.[GL06004]) > 0 THEN (CASE WHEN [GL06017]<>0 AND TTiS.[Symbol] NOT IN (''1'', ''S'') THEN -1 ELSE 1 END * GL06.[GL06004]) ELSE 0 END,
				[ValueCredit_Book] = CASE WHEN (CASE WHEN [GL06017]<>0 AND TTiS.[Symbol] NOT IN (''1'', ''S'') THEN -1 ELSE 1 END * GL06.[GL06004]) < 0 THEN (CASE WHEN [GL06017]<>0 AND TTiS.[Symbol] NOT IN (''1'', ''S'') THEN -1 ELSE 1 END * GL06.[GL06004]) * -1 ELSE 0 END,

				[Currency_Transaction] = ISNULL(SYCD.[SYCD009], GL06.[GL06019]),
				[ValueDebit_Transaction] = CASE WHEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06018]) > 0 THEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06018]) ELSE 0 END,
				[ValueCredit_Transaction] = CASE WHEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06018]) < 0 THEN (CASE WHEN [GL06017] = 0 THEN 1 ELSE -1 END * GL06.[GL06018]) * -1 ELSE 0 END,
				[SourceModule] = GL06.[GL06038],
				[SourceModuleReference] = GL06.[GL06002],
				[SourceCounter] = GL06.[GL06016],
				[SourceGUID] = NULL
			FROM 
				' + @SourceDatabase + '.[dbo].' + @SourceTable + ' GL06
				INNER JOIN [#TransactionType_iScala] TTiS ON CONVERT(binary(1), TTiS.[Symbol]) = GL06.[GL06012] AND TTiS.[SelectYN] <> 0
				INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND FP.FiscalPeriod = CASE TTiS.[BusinessProcess] WHEN ''FP0'' THEN 0 WHEN ''FP13'' THEN 13 ELSE MONTH(GL06.[GL06003]) + CASE WHEN ' + CONVERT(nvarchar(15), @FiscalYearStartMonth) + ' = 1 THEN 0 ELSE CASE WHEN MONTH(GL06.[GL06003]) > (' + CONVERT(nvarchar(15), @FiscalYearStartMonth) + ' - 1) THEN - (' + CONVERT(nvarchar(15), @FiscalYearStartMonth) + ' - 1) ELSE 13 - ' + CONVERT(nvarchar(15), @FiscalYearStartMonth) + ' END END END
				LEFT JOIN #BalanceAccount BA ON BA.Account_MemberKey = ' + @AccountSourceCode + ' COLLATE DATABASE_DEFAULT
				LEFT JOIN ' + @SourceDatabase + '.[dbo].' + @CurrencyTable + ' SYCD ON SYCD.[SYCD001] = GL06.[GL06019]
			WHERE
				--GL06.[GL06019] = 0 AND
				(GL06.[GL06016] > ' + CONVERT(nvarchar(15), ISNULL(@MaxSourceCounter, 0)) + ' OR ' + CONVERT(nvarchar(15), CONVERT(int, @FullReloadYN)) + ' <> 0) AND
				CASE WHEN LEFT(' + @AccountSourceCode + ', 1) = ''9'' OR (ISNULL(BA.[BalanceYN], 0) = 0 AND TTiS.[Period] = ''0'') THEN 32 ELSE 1 END = 1 AND
				1 = 1
			ORDER BY
				GL06.[GL06038],
				GL06.[GL06002],
				GL06.[GL06016]'

		IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
			BEGIN
				PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Add basic rows to #Journal'
				EXEC [dbo].[spSet_wrk_Debug]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@DatabaseName = @DatabaseName,
					@CalledProcedureName = @ProcedureName,
					@Comment = 'Add basic rows to #Journal', 
					@SQLStatement = @SQLStatement
			END
		ELSE
			PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Selected = @Selected + @@ROWCOUNT

	--SET @Step = 'Opening balance'
	--	SET @SequenceOB = CASE WHEN @StartFiscalYear < (SELECT MIN(FiscalYear) FROM #FiscalPeriod) THEN 2 ELSE 0 END

	--	IF @DebugBM & 2 > 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@Entity_MemberKey] = @Entity_MemberKey, [@Book] = @Book, [@StartFiscalYear] = @StartFiscalYear, [@SequenceBM] = @SequenceOB, [@Debug] = @DebugSub

	--	SET @JSON = '
	--				[
	--				{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
	--				{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
	--				{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
	--				{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity_MemberKey + '"},
	--				{"TKey" : "Book",  "TValue": "' + @Book + '"},
	--				{"TKey" : "SequenceBM",  "TValue": "' + CONVERT(nvarchar(10), @SequenceOB) + '"},
	--				{"TKey" : "JournalTable",  "TValue": "' + @JournalTable + '"},
	--				{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
	--				{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}'
	--				+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @FiscalYear) + '"}' END +
	--				']'
		
	--	EXEC spRun_Procedure_KeyValuePair
	--		@ProcedureName = 'spIU_DC_Journal_OpeningBalance',
	--		@JSON = @JSON

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = '#Journal', * FROM #Journal ORDER BY FiscalPeriod, Account, Segment01, Segment02, Segment03, Segment04, [JournalNo], [JournalLine]
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #FiscalPeriod
		DROP TABLE #Segment
		DROP TABLE #BalanceAccount
		DROP TABLE [#TransactionType_iScala]
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #Journal
			END

	SET @Step = 'Table does not exists'
		NoTable:
		RAISERROR (@Message, @Severity, 100)

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
