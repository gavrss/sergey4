SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_P21_20250303_DosaTest]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@Entity_MemberKey NVARCHAR(50) = NULL,
	@Book NVARCHAR(50) = NULL,
	@FiscalYear INT = NULL,
--	@FiscalPeriod int = NULL,
	@FiscalPeriodString NVARCHAR(1000) = NULL,
	@StartFiscalYear INT = NULL,
	@SequenceBM INT = 3, --1 = GL transactions, 2 = Opening balances
	@JournalTable NVARCHAR(100) = NULL,
	@FullReloadYN BIT = 1,
	@MaxSourceCounter BIGINT = NULL,
	@SourceID INT  = NULL,
	@LoadGLJrnDtl_NotBalanceYN BIT = 0,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000728,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*



EXEC [spIU_DC_Journal_P21_20250303_DosaTest] @Book=N'GL',@DebugBM=N'15',@Entity_MemberKey=N'2',@FullReloadYN=N'1',
@InstanceID=N'1003',@SequenceBM=N'1',@SourceID=N'2069',@UserID=N'-10',@VersionID=N'1398'


EXEC [spIU_DC_Journal_P21] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@JSON NVARCHAR(MAX),
	@CalledYN BIT = 1,
	@SourceDatabase NVARCHAR(100),
	@LinkedServer NVARCHAR(100),
	@Owner NVARCHAR(10),
	@EntityID INT,
	@Currency NCHAR(3),
	@SQLStatement NVARCHAR(MAX),
	@SQLSegment NVARCHAR(MAX),
	@SQLSegmentBal NVARCHAR(MAX),
	@SegmentNo INT = -1,
	@AccountSourceCodeBal NVARCHAR(50),
	@AccountSourceCode NVARCHAR(50),
	@AccountSegmentNo INT,
	@InvcHead_ExistsYN BIT,
	@Customer_ExistsYN BIT,
	@BalAcctDesc_ExistsYN BIT,
	@RevisionBM INT,
	@SourceTypeID INT,
	@SequenceOB INT,
	@SourceTypeName NVARCHAR(50),
	@InvoiceString NVARCHAR(MAX),
	@MaxSourceBudgetCounter BIGINT = NULL,
	@GLJrnHedExistsYN BIT,
	@BudgetCodeIDExistsYN BIT,
	@BudgetScenario NVARCHAR(100),
	@CallistoDatabase NVARCHAR(100),

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'Dosa',
	@Version NVARCHAR(50) = '2.1.2.2199'
    
IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into #Journal from source P21',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added ProductGroup.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added Customer, Supplier and Contact.'
		IF @Version = '2.1.1.2172' SET @Description = 'Set Segments default to empty string.'
		IF @Version = '2.1.1.2175' SET @Description = 'Add SSIS execute by SQLJob'
		IF @Version = '2.1.2.2191' SET @Description = 'Removed hardcoded Entity prefix for Segment01'
		IF @Version = '2.1.2.2198' SET @Description = 'Fixed doubled rows, test on @SequenceBM = 1 instead of 3.'
		IF @Version = '2.1.2.2199' SET @Description = 'Made Generic. Added OB_ERP rows to #Journal for @SequenceBM 2. Modified query for inserting into #BalanceAccount. FPA-348: Updated #BalanceAccount to correct [BalanceYN] value to be used when inserting into #MaxPeriod. Updated #BalanceAccount to handle B.[company_no] with the corresponding @Entity_MemberKey.'

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

		SELECT
			@EntityID = E.EntityID,
			@Currency = EB.Currency
		FROM
			[pcINTEGRATOR_Data].[dbo].Entity E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].Entity_Book EB ON EB.EntityID = E.EntityID AND EB.Book = @Book AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.MemberKey = @Entity_MemberKey AND
			E.SelectYN <> 0

		SELECT
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@Owner = ST.[Owner],
			@StartFiscalYear = ISNULL(@StartFiscalYear, S.StartYear),
			@SourceID = S.[SourceID],
			@SourceTypeID = S.[SourceTypeID],
			@SourceTypeName = ST.[SourceTypeName],
			@CallistoDatabase = A.DestinationDatabase
		FROM
			[pcINTEGRATOR].[dbo].[Application] A
			INNER JOIN [pcINTEGRATOR].[dbo].Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0 AND (S.SourceID = @SourceID OR @SourceID IS NULL)
			INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID 
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0 

		IF CHARINDEX('.', @SourceDatabase) <> 0
			SET @LinkedServer = REPLACE(REPLACE(LEFT(@SourceDatabase, CHARINDEX('.', @SourceDatabase) - 1), '[', ''), ']', '')

		IF @SourceTypeID = 11 
			EXEC [pcINTEGRATOR].[dbo].[spGet_Revision] @SourceID = @SourceID, @RevisionBM = @RevisionBM OUT
		ELSE
			SET @RevisionBM = 1

		IF @JournalTable IS NULL
			EXEC [pcINTEGRATOR].[dbo].[spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		IF @DebugBM & 2 > 0
			SELECT 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@CallistoDatabase] = @CallistoDatabase,
				[@Owner] = @Owner,
				[@SourceDatabase] = @SourceDatabase,
				[@Owner] = @Owner,
				[@StartFiscalYear] = @StartFiscalYear,
				[@SourceID] = @SourceID,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName,
				[@LinkedServer] = @LinkedServer,
				[@Currency] = @Currency,
				[@EntityID] = @EntityID,
				[@Book] = @Book,
				[@JournalTable] = @JournalTable,
				[@SequenceBM] = @SequenceBM

		IF @SequenceBM & 3 > 0 AND @LinkedServer IS NOT NULL
			EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer

		--IF @SequenceBM & 1 > 0 
		--	BEGIN
		--		EXEC [pcINTEGRATOR].[dbo].spGet_TableExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = 'erp.InvcHead', @ExistsYN = @InvcHead_ExistsYN OUT
		--		EXEC [pcINTEGRATOR].[dbo].spGet_TableExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = 'erp.Customer', @ExistsYN = @Customer_ExistsYN OUT

		--		SET @Customer_ExistsYN = CONVERT(int, @InvcHead_ExistsYN) * CONVERT(int, @Customer_ExistsYN)
		--	END

		--IF @SequenceBM & 2 > 0 
		--	EXEC [pcINTEGRATOR].[dbo].spGet_ColumnExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = 'erp.GLPeriodBal', @ColumnName = 'BalAcctDesc', @ExistsYN = @BalAcctDesc_ExistsYN OUT

		--IF @DebugBM & 2 > 0
		--	SELECT 
		--		[@Customer_ExistsYN] = @Customer_ExistsYN,
		--		[@BalAcctDesc_ExistsYN] = @BalAcctDesc_ExistsYN


	SET @Step = 'Create temp table #Callisto_Currency'
		CREATE TABLE #Callisto_Currency
			(
			Currency NVARCHAR(5) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #Segment'
		CREATE TABLE #Segment
			(
			SourceCode NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			SegmentNo INT,
			DimensionName NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			MaskPosition INT,
			MaskCharacters INT
			)

	SET @Step = 'Fill temp table #Segment'
		INSERT INTO #Segment
			(
			SourceCode,
			SegmentNo,
			DimensionName,
			MaskPosition,
			MaskCharacters
			)
		SELECT 
			JSN.SourceCode,
			JSN.SegmentNo,
			D.DimensionName,
			JSN.MaskPosition,
			JSN.MaskCharacters
		FROM
			[pcINTEGRATOR_Data].[dbo].Journal_SegmentNo JSN
			LEFT JOIN [pcINTEGRATOR].[dbo].Dimension D ON D.DimensionID = JSN.DimensionID
		WHERE
			JSN.EntityID = @EntityID AND
			JSN.Book = @Book AND
			JSN.SelectYN <> 0 AND
            JSN.MaskPosition IS NOT NULL AND JSN.MaskCharacters IS NOT NULL 

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment', * FROM #Segment ORDER BY SegmentNo

		WHILE @SegmentNo < 20
			BEGIN
				SET @SegmentNo = @SegmentNo + 1

				--IF @DebugBM & 2 > 0
				--	BEGIN
				--		SELECT [@SegmentNo] = @SegmentNo
				--		SELECT [SegmentNo] = @SegmentNo WHERE NOT EXISTS (SELECT 1 FROM #Segment SD WHERE SD.[SegmentNo] = @SegmentNo)
				--	END

				INSERT INTO #Segment ([SegmentNo]) SELECT [SegmentNo] = @SegmentNo WHERE NOT EXISTS (SELECT 1 FROM #Segment SD WHERE SD.[SegmentNo] = @SegmentNo)
				IF @SegmentNo = 0
					BEGIN
						SELECT @AccountSourceCode = MAX(CASE WHEN [SegmentNo] = @SegmentNo THEN 'SUBSTRING(GL.' + SourceCode + ', ' + CONVERT(NVARCHAR(15), MaskPosition) + ', ' + CONVERT(NVARCHAR(15), MaskCharacters) + ')' ELSE '''''' END) FROM #Segment
						SELECT @SQLSegment = '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN 'SUBSTRING(GL.' + SourceCode + ', ' + CONVERT(NVARCHAR(15), MaskPosition) + ', ' + CONVERT(NVARCHAR(15), MaskCharacters) + ')' ELSE '''''' END) + ',' FROM #Segment

						SELECT @AccountSourceCodeBal = MAX(CASE WHEN [SegmentNo] = @SegmentNo THEN 'SUBSTRING(B.[account_no], ' + CONVERT(NVARCHAR(15), MaskPosition) + ', ' + CONVERT(NVARCHAR(15), MaskCharacters) + ')' ELSE '''''' END) FROM #Segment
						SELECT @SQLSegmentBal = '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN 'SUBSTRING(B.[account_no], ' + CONVERT(NVARCHAR(15), MaskPosition) + ', ' + CONVERT(NVARCHAR(15), MaskCharacters) + ')' ELSE '''''' END) + ',' FROM #Segment
					END
				ELSE
					BEGIN
						SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(NVARCHAR(15), @SegmentNo) + '] = ' + CASE WHEN [DimensionName] IS NULL THEN '''''' ELSE 'LTRIM(RTRIM(SUBSTRING(GL.' + SourceCode + ', ' + CONVERT(NVARCHAR(15), MaskPosition) + ', ' + CONVERT(NVARCHAR(15), MaskCharacters) + ')))' END + ',' FROM #Segment WHERE SegmentNo = @SegmentNo
						SELECT @SQLSegmentBal = @SQLSegmentBal + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(NVARCHAR(15), @SegmentNo) + '] = ' + CASE WHEN [DimensionName] IS NULL THEN '''''' ELSE 'LTRIM(RTRIM(SUBSTRING(B.[account_no], ' + CONVERT(NVARCHAR(15), MaskPosition) + ', ' + CONVERT(NVARCHAR(15), MaskCharacters) + ')))' END + ',' FROM #Segment WHERE SegmentNo = @SegmentNo
					END
			END

		IF @DebugBM & 2 > 0 SELECT [@AccountSourceCode] = @AccountSourceCode,[@AccountSourceCodeBal] = @AccountSourceCodeBal
		IF @DebugBM & 2 > 0 SELECT [@SQLSegment] = @SQLSegment,[@SQLSegmentBal] = @SQLSegmentBal

	SET @Step = 'Create and fill temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear INT,
			FiscalPeriod INT,
			YearMonth INT
			)

		IF @DebugBM & 2 > 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@EntityID] = @EntityID, [@Book] = @Book, [@StartFiscalYear] = @StartFiscalYear, [@FiscalYear] = @FiscalYear, [@FiscalPeriodString] = @FiscalPeriodString
		
		EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriodString = @FiscalPeriodString, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @JobID = @JobID

		IF @DebugBM & 2 > 0 SELECT [@FiscalPeriodString] = @FiscalPeriodString
		IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod

	SET @Step = 'Create temp table #BalanceAccount'
		CREATE TABLE #BalanceAccount
			(
			Company NVARCHAR(8) COLLATE DATABASE_DEFAULT,
			COACode NVARCHAR(10) COLLATE DATABASE_DEFAULT,
			Account NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			BalanceYN BIT
			)

	SET @Step = 'Create temp table #MaxPeriod'
		CREATE TABLE #MaxPeriod
			(
			[account_no] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[year_for_period] INT,
			[period] INT
			)

	--SET @Step = 'Create temp table #Customer, #Invoice'
	--	IF @SequenceBM & 1 > 0
	--		BEGIN
	--			CREATE TABLE #Invoice
	--				(
	--				[Company] [NVARCHAR](8),
	--				[ARInvoiceNum] INT
	--				)

	--			CREATE TABLE #Customer
	--				(
	--				[Company] [NVARCHAR](8),
	--				[ARInvoiceNum] INT,
	--				[CustNum] INT,
	--				[CustID] NVARCHAR(10) COLLATE DATABASE_DEFAULT
	--				)
	--		END


	SET @Step = 'Create temp table #Entity_Book_FiscalYear'
		IF OBJECT_ID(N'TempDB.dbo.#Entity_Book_FiscalYear', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Entity_Book_FiscalYear
					(
					[Entity_MemberKey] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Book] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [INT],
					[StartFiscalYear] [INT]
					)
			END

	SET @Step = 'Create temp table #Journal'
		IF OBJECT_ID(N'TempDB.dbo.#Journal', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Journal
					(
					[JobID] [INT],
					[InstanceID] [INT],
					[Entity] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Book] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [INT],
					[FiscalPeriod] [INT],
					[JournalSequence] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[JournalNo] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[JournalLine] [INT],
					[YearMonth] [INT],
					[TransactionTypeBM] [INT],
					[BalanceYN] [BIT],
					[Account] [NVARCHAR](50) COLLATE DATABASE_DEFAULT, 
					[Segment01] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment02] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment03] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment04] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment05] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment06] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment07] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment08] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment09] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment10] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment11] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment12] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment13] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment14] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment15] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment16] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment17] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment18] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment19] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[Segment20] [NVARCHAR](50) COLLATE DATABASE_DEFAULT DEFAULT '',
					[JournalDate] [DATE],
					[TransactionDate] [DATE],
					[PostedDate] [DATE],
					[PostedStatus] [INT],
					[PostedBy] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
					[Source] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Scenario] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Customer] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Supplier] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Description_Head] [NVARCHAR](255) COLLATE DATABASE_DEFAULT,
					[Description_Line] [NVARCHAR](255) COLLATE DATABASE_DEFAULT,
					[Currency_Book] [NCHAR](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Book] [FLOAT],
					[ValueCredit_Book] [FLOAT],
					[Currency_Group] [NCHAR](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Group] [FLOAT],
					[ValueCredit_Group] [FLOAT],
					[Currency_Transaction] [NCHAR](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Transaction] [FLOAT],
					[ValueCredit_Transaction] [FLOAT],
					[SourceModule] [NVARCHAR](20) COLLATE DATABASE_DEFAULT,
					[SourceModuleReference] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
					[SourceCounter] [BIGINT],
					[SourceGUID] [UNIQUEIDENTIFIER]
					)
			END

	SET @Step = 'Fill temp table #BalanceAccount'
		--SET @SQLStatement = '
		--	INSERT INTO #BalanceAccount
		--		(
		--		[Account],
		--		[BalanceYN]
		--		)
		--	SELECT
		--		[Account] = [Label],
		--		[BalanceYN] = [TimeBalance]
		--	FROM
		--		[' + @CallistoDatabase + '].[dbo].[S_DS_Account]
		--	WHERE
		--		RNodeType = ''L'' 
		--		--AND TimeBalance <> 0'

		--SET @SQLStatement = '
		--	INSERT INTO #BalanceAccount
		--		(
		--		Company,
		--		COACode,
		--		Account,
		--		BalanceYN
		--		)
		--	SELECT DISTINCT 
		--		Company = COA.[company_no],
		--		COACode = NULL,
		--		Account = LEFT(COA.[account_no], 5),
		--		BalanceYN = CASE WHEN LEFT(COA.[account_no], 1) < 4 THEN 1 ELSE 0 END
		--	FROM
		--		' + @SourceDatabase + '.[' + @Owner + '].[chart_of_accts] COA'

		SET @SQLStatement = '
			INSERT INTO #BalanceAccount
				(
				Company,
				COACode,
				Account,
				BalanceYN
				)
			SELECT DISTINCT 
				Company = B.[company_no],
				COACode = NULL,
				Account = ' + @AccountSourceCodeBal + ',
				BalanceYN = CASE WHEN LEFT(' + @AccountSourceCodeBal + ', 1) < 4 THEN 1 ELSE 0 END
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[chart_of_accts] B'
				+ CASE WHEN @Entity_MemberKey IS NOT NULL THEN ' WHERE B.[company_no] = ''' + @Entity_MemberKey +'''' ELSE '' END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#BalanceAccount', * FROM #BalanceAccount ORDER BY [Account]

	SET @Step = 'Insert GL transactions into temp table #Journal'
		IF @SequenceBM & 1 > 0
			BEGIN
				SET @Step = 'Journal_Entity_Cursor'
					TRUNCATE TABLE #Entity_Book_FiscalYear

					INSERT INTO #Entity_Book_FiscalYear
						(
						[Entity_MemberKey],
						[Book],
						[FiscalYear],
						[StartFiscalYear]
						)
					SELECT DISTINCT
						[Entity_MemberKey] = @Entity_MemberKey,
						[Book] = @Book,
						[FiscalYear] = [FiscalYear],
						[StartFiscalYear] = MIN([FiscalYear])
					FROM
						#FiscalPeriod
					GROUP BY
						[FiscalYear]

					IF @DebugBM & 2 > 0 SELECT TempTable = '#Entity_Book_FiscalYear', * FROM #Entity_Book_FiscalYear
										
					IF CURSOR_STATUS('global','Journal_Entity_Cursor') >= -1 DEALLOCATE Journal_Entity_Cursor
					DECLARE Journal_Entity_Cursor CURSOR FOR
			
						SELECT DISTINCT
							[Entity_MemberKey],
							[Book],
							[FiscalYear],
							[StartFiscalYear]
						FROM
							#Entity_Book_FiscalYear
						ORDER BY
							[Entity_MemberKey],
							[Book],
							[FiscalYear]

						OPEN Journal_Entity_Cursor
						FETCH NEXT FROM Journal_Entity_Cursor INTO @Entity_MemberKey, @Book, @FiscalYear, @StartFiscalYear

						WHILE @@FETCH_STATUS = 0
							BEGIN
								SELECT
									@EntityID = E.EntityID,
									@Currency = EB.Currency
								FROM
									pcINTEGRATOR_Data.dbo.Entity E
									INNER JOIN pcINTEGRATOR_Data.dbo.Entity_Book EB ON EB.EntityID = E.EntityID AND EB.Book = @Book AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
								WHERE
									E.InstanceID = @InstanceID AND
									E.VersionID = @VersionID AND
									E.MemberKey = @Entity_MemberKey AND
									E.SelectYN <> 0

								IF @DebugBM & 2 > 0 SELECT [@EntityID] = @EntityID, [@Currency] = @Currency, [@Entity_MemberKey] = @Entity_MemberKey, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@StartFiscalYear] = @StartFiscalYear

								IF @DebugBM & 2 > 0 
									SELECT
										[@JobID] = @JobID,
										[@ProcedureID] = @ProcedureID,
										[@InstanceID] = @InstanceID,
										[@Entity_MemberKey] = @Entity_MemberKey,
										[@SQLSegment] = @SQLSegment,
										[@Currency] = @Currency,
										[@SourceDatabase] = @SourceDatabase,
										[@Owner] = @Owner,
										[@AccountSourceCode] = @AccountSourceCode,
										[@Entity_MemberKey] = @Entity_MemberKey,
										[@Book] = @Book,
										[@FiscalYear] = @FiscalYear

								IF @SequenceBM & 1 > 0
									BEGIN

										--Fill temp table #Journal
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
					SELECT DISTINCT
						[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
						[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
						[Entity] = ''' + @Entity_MemberKey + ''',
						[Book] = ''' + @Book + ''',
						[FiscalYear] = FP.[FiscalYear],
						[FiscalPeriod] = FP.[FiscalPeriod],
						[JournalSequence] = GL.[journal_id],
						[JournalNo] = CONVERT(nvarchar(50), GL.[transaction_number]),
						[JournalLine] = GL.[sequence_number],
						[YearMonth] = FP.[YearMonth],
						[TransactionTypeBM] = 1,
						[BalanceYN] = ISNULL(BA.BalanceYN, 0),
						' + @SQLSegment + '
						[JournalDate] = CONVERT(date, GL.[transaction_date]),
						[TransactionDate] = CONVERT(date, GL.[transaction_date]),
						[PostedDate] = CONVERT(date, GL.[date_last_modified]),
						[PostedStatus] = CASE WHEN GL.[approved] = ''Y'' THEN 1 ELSE 0 END,
						[PostedBy] = GL.[last_maintained_by],
						[Source] = ''' + @SourceTypeName + ''',
						[Scenario] = ''ACTUAL'',
						[Customer] = NULL,
						[Supplier] = NULL,
						[Description_Head] = NULL,
						[Description_Line] = GL.[description],
						[Currency_Book] = ''' + @Currency + ''',
						[ValueDebit_Book] = CASE WHEN GL.[amount] > 0 THEN GL.[amount] ELSE 0 END,
						[ValueCredit_Book] = CASE WHEN GL.[amount] < 0 THEN GL.[amount] * -1 ELSE 0 END,
						[Currency_Transaction] = NULL,
						[ValueDebit_Transaction] = NULL,
						[ValueCredit_Transaction] = NULL,
						[SourceModule] = GL.[journal_id],
						[SourceModuleReference] = GL.[source],
						[SourceCounter] = GL.[gl_uid],
						[SourceGUID] = NULL'
										SET @SQLStatement = @SQLStatement + '
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[gl] GL
						INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GL.[year_for_period] AND FP.[FiscalPeriod] = GL.[period]
						LEFT JOIN #BalanceAccount BA ON BA.Company = GL.[company_no] COLLATE DATABASE_DEFAULT AND BA.Account = ' + @AccountSourceCode + '
						--LEFT JOIN #BalanceAccount BA ON BA.Company = GL.[company_no] COLLATE DATABASE_DEFAULT AND BA.Account = SUBSTRING(GL.[account_number], 1, 5)
						--LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[invoice_hdr] AR ON GL.[journal_id] = ''SJ'' AND CONVERT(varchar(255), AR.[invoice_no]) = GL.[source]
						--LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[apinv_hdr] AP ON GL.[journal_id] = ''PJ'' AND CONVERT(varchar(255), AP.[voucher_no]) = GL.[source]
					WHERE
						GL.[company_no] = ''' + @Entity_MemberKey + ''' AND
						GL.[year_for_period] = ' + CONVERT(nvarchar(10), @FiscalYear) 


										IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
											BEGIN
												PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Insert GL transactions into temp table #Journal'
												EXEC [pcINTEGRATOR].[dbo].[spSet_wrk_Debug]
													@UserID = @UserID,
													@InstanceID = @InstanceID,
													@VersionID = @VersionID,
													@DatabaseName = @DatabaseName,
													@CalledProcedureName = @ProcedureName,
													@Comment = 'Insert GL transactions into temp table #Journal', 
													@SQLStatement = @SQLStatement
											END
										ELSE
											PRINT @SQLStatement

										IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
										EXEC (@SQLStatement)

										SET @Selected = @Selected + @@ROWCOUNT
					
									END

								FETCH NEXT FROM Journal_Entity_Cursor INTO @Entity_MemberKey, @Book, @FiscalYear, @StartFiscalYear
							END

					CLOSE Journal_Entity_Cursor
					DEALLOCATE Journal_Entity_Cursor
			END

	SET @Step = 'Temp step to fix the issue with wrong BalanceYN'		
		SET @SQLStatement = '
			UPDATE J
			SET
				BalanceYN = A.TimeBalance
			FROM
				#Journal J
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Account] A ON A.[Label] = J.[Account] AND A.TimeBalance <> J.BalanceYN'

		EXEC (@SQLStatement)

	SET @Step = 'Insert opening balances into temp table #Journal'
		IF @SequenceBM & 2 > 0 AND (SELECT COUNT(1) FROM #FiscalPeriod WHERE FiscalPeriod = 0) > 0 
				AND ((SELECT COUNT(1) FROM #Journal WHERE FiscalPeriod = 1) > 0 OR @FullReloadYN <> 0)
			BEGIN
			
				IF @DebugBM & 32 > 0 
					SELECT 
						[@SQLSegmentBal] = @SQLSegmentBal, [@Entity_MemberKey] = @Entity_MemberKey,[@BalAcctDesc_ExistsYN] = @BalAcctDesc_ExistsYN,
						[@Currency] = @Currency, [@SourceDatabase] = @SourceDatabase, [@Owner] = @Owner, [@Book] = @Book, [@EntityID] = @EntityID, 
						[@JobID] = @JobID, [@ProcedureID] = @ProcedureID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID																										
				
				--TODO: to be implemented for all Instances with P21 SourceType
				--temp fix for InstanceID=672 (AAHD), and 709 (EOHI)
				IF (@InstanceID IN (672, 709))
					BEGIN

						--Temp fix on wrong BalanceYN
						SET @SQLStatement = '
							UPDATE B
							SET
								BalanceYN = A.TimeBalance
							FROM
								#BalanceAccount B
								INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Account] A ON A.[Label] = B.[Account] AND A.TimeBalance <> B.BalanceYN'

						EXEC (@SQLStatement)
						IF @DebugBM & 2 > 0 SELECT [TempTable] = '#BalanceAccount_[BalanceYN]_Updated', * FROM #BalanceAccount ORDER BY [Account]

						SET @SQLStatement = '
							INSERT INTO #MaxPeriod
								(
								[account_no],
								[year_for_period],
								[period]
								)
							SELECT
								[account_no],
								[year_for_period] = [YearMonth] / 100,
								[period] =  [YearMonth] % 100
							FROM
								(
								SELECT
									B.[account_no],
									YearMonth = CONVERT(int, MAX(B.[year_for_period] * 100 + B.[period]))
								FROM
									' + @SourceDatabase + '.[' + @Owner + '].[Balances] B
									INNER JOIN #BalanceAccount BA ON BA.Account = ' + @AccountSourceCodeBal + ' AND BA.[BalanceYN] <> 0
								WHERE
									B.[company_no] = ''' + @Entity_MemberKey + ''' AND
									B.[year_for_period] * 100 + B.[period] <= ' + CONVERT(nvarchar(10), @FiscalYear) + ' * 100
								GROUP BY
									B.[account_no]
								) sub'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
						EXEC (@SQLStatement)

						IF @DebugBM & 16 > 0 SELECT [Step] = 'After fill temptable #MaxPeriod', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)

						IF @DebugBM & 2 > 0 SELECT TempTable = '#MaxPeriod', * FROM #MaxPeriod

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
								[Description_Head],
								[Description_Line],
								[Currency_Book],
								[ValueDebit_Book],
								[ValueCredit_Book]
								)
							SELECT
								[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
								[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
								[Entity] = B.[company_no],
								[Book] = ''' + @Book + ''',
								[FiscalYear] =  MAX(FP.[FiscalYear]),
								[FiscalPeriod] = 0,
								[JournalSequence] = ''OB_ERP'',
								[JournalNo] = ''0'',
								[JournalLine] = 0,
								[YearMonth] = MAX(FP.[YearMonth]),
								[TransactionTypeBM] = 4,
								[BalanceYN] = 1,
								' + @SQLSegmentBal + '
								[JournalDate] = MAX(CONVERT(datetime, CONVERT(nvarchar(10), FP.[YearMonth]) + ''01'', 112)),
								[TransactionDate] = MAX(CONVERT(datetime, CONVERT(nvarchar(10), FP.[YearMonth]) + ''01'', 112)),
								[PostedDate] = MAX(CONVERT(datetime, CONVERT(nvarchar(10), FP.[YearMonth]) + ''01'', 112)),
								[PostedStatus] = 1,
								[PostedBy] = '''',
								[Source] = ''P21'',
								[Scenario] = ''ACTUAL'',
								[Description_Head] = ''Opening balance'',
								[Description_Line] = NULL,
								[Currency_Book] = ''' + @Currency + ''',
								[ValueDebit_Book] = CASE WHEN MAX(B.[cumulative_balance]) > 0 THEN MAX(B.[cumulative_balance]) ELSE 0 END,
								[ValueCredit_Book] = CASE WHEN MAX(B.[cumulative_balance]) < 0 THEN MAX(B.[cumulative_balance]) * -1 ELSE 0 END
							FROM
								' + @SourceDatabase + '.[' + @Owner + '].[balances] B
								INNER JOIN #MaxPeriod MP ON MP.[account_no] = B.[account_no] AND MP.[year_for_period] = B.[year_for_period] AND MP.[Period] = B.[period]
								INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND FP.[FiscalPeriod] = 0
							WHERE
								B.[company_no] = ''' + @Entity_MemberKey + '''
								--B.[cumulative_balance] <> 0
							GROUP BY
								B.[company_no],
								B.[account_no]'

						IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
							BEGIN
								PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Insert opening balances into temp table #Journal'
								EXEC [pcINTEGRATOR].[dbo].[spSet_wrk_Debug]
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@DatabaseName = @DatabaseName,
									@CalledProcedureName = @ProcedureName,
									@Comment = 'Insert opening balances into temp table #Journal', 
									@SQLStatement = @SQLStatement
							END
						ELSE
							PRINT @SQLStatement

						IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
						EXEC (@SQLStatement)

						SET @Selected = @Selected + @@ROWCOUNT

						IF @DebugBM & 16 > 0 SELECT [Step] = 'After fill #Journal with Opening Balance (OB_ERP)', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)
					END
			

				--Opening balance
				SET @SequenceOB = CASE WHEN ISNULL(@StartFiscalYear, @FiscalYear) < (SELECT MIN(FiscalYear) FROM #FiscalPeriod) THEN 2 ELSE 0 END

				IF @DebugBM & 2 > 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@Entity_MemberKey] = @Entity_MemberKey, [@Book] = @Book, [@StartFiscalYear] = @StartFiscalYear, [@FiscalYear] = @FiscalYear, [@SequenceBM] = @SequenceOB, [@Debug] = @DebugSub

				SET @JSON = '
							[
							{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
							{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
							{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
							{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity_MemberKey + '"},
							{"TKey" : "Book",  "TValue": "' + @Book + '"},
							{"TKey" : "SequenceBM",  "TValue": "' + CONVERT(nvarchar(10), @SequenceOB) + '"},
							{"TKey" : "JournalTable",  "TValue": "' + @JournalTable + '"},
							{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
							{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}'
							+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @FiscalYear) + '"}' END +
							']'

				IF @DebugBM & 2 > 0 PRINT @JSON
		
				EXEC [pcINTEGRATOR].[dbo].[spRun_Procedure_KeyValuePair]
					@ProcedureName = 'spIU_DC_Journal_OpeningBalance',
					@JSON = @JSON

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After running [spIU_DC_Journal_OpeningBalance]', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)
			END

	SET @Step = 'Update Currency'
		SET @SQLStatement = '
			INSERT INTO #Callisto_Currency
				(
				Currency
				)
			SELECT 
				Currency = [Label]
			FROM 
				' + @CallistoDatabase + '.[dbo].[S_DS_Currency]
			WHERE 
				RNodeType = ''L'' AND MemberId <> -1'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Callisto_Currency', * FROM #Callisto_Currency

		UPDATE J
		SET 
			[Currency_Transaction] = J.Currency_Book
		FROM 
			#Journal J
		WHERE 
			J.ValueCredit_Transaction = J.ValueCredit_Book AND
            J.ValueDebit_Transaction = J.ValueDebit_Book AND 
			NOT EXISTS (SELECT 1 FROM #Callisto_Currency C WHERE C.Currency = J.Currency_Transaction)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = '#Journal', * FROM #Journal ORDER BY SourceCounter, FiscalYear, FiscalPeriod, Account, Segment01, Segment02
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Callisto_Currency
		DROP TABLE #FiscalPeriod
		DROP TABLE #Segment
		DROP TABLE #BalanceAccount
		DROP TABLE #MaxPeriod

		IF @CalledYN = 0
			BEGIN
				DROP TABLE #Journal
				DROP TABLE #Entity_Book_FiscalYear
			END
		--IF @SequenceBM & 1 > 0
		--	BEGIN
		--		DROP TABLE #GLJrnDtl
		--		DROP TABLE #Invoice
		--		DROP TABLE #Customer
		--	END
		--IF @SequenceBM & 4 > 0
		--	BEGIN
		--		DROP TABLE #GLBudgetDtl
		--		DROP TABLE #GLBD
		--		DROP TABLE #BudgetCode
		--	END

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
