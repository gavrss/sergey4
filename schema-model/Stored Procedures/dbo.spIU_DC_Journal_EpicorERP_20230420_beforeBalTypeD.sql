SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_EpicorERP_20230420_beforeBalTypeD]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
--	@FiscalPeriod int = NULL,
	@FiscalPeriodString nvarchar(1000) = NULL,
	@StartFiscalYear int = NULL,
	@SequenceBM int = 3, --1 = GL transactions, 2 = Opening balances, 4 = Budget transactions
	@JournalTable nvarchar(100) = NULL,
	@FullReloadYN bit = 0,
	@MaxSourceCounter bigint = NULL,
	@SourceID int  = NULL,
	@LoadGLJrnDtl_NotBalanceYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000638,
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
EXEC [pcINTEGRATOR].[dbo].[spIU_DC_Journal_EpicorERP] @Book='Master',@DebugBM='3',@Entity_MemberKey='PacJay', @FullReloadYN='1',
@InstanceID='603',@JournalTable='[pcETL_PCX2].[dbo].[Journal]',@SequenceBM='3',@SourceID='1346',@UserID='-10',@VersionID='1095'

EXEC [pcINTEGRATOR].[dbo].[spIU_DC_Journal_EpicorERP] @Book='CORP',@Debug='0',@Entity_MemberKey='HGC',@FiscalYear='2007',
@FullReloadYN='1',@InstanceID='570',@JournalTable='[pcETL_HGADV].[dbo].[Journal]',
@SequenceBM='2',@SourceID='1261',@UserID='-10',@VersionID='1078',@DebugBM=15

EXEC [pcINTEGRATOR].[dbo].[spIU_DC_Journal_EpicorERP] @Book='MAIN2',@DebugBM='7',@Entity_MemberKey='101',@FiscalYear='2021',
@FullReloadYN='1',@InstanceID='576',@JournalTable='[pcETL_AXYZ].[dbo].[Journal]',@SequenceBM='1',@SourceID='1281',@UserID='-10',@VersionID='1082'

EXEC spIU_DC_Journal_EpicorERP @Book='MAIN',@DebugBM='3',@Entity_MemberKey='DLL',@FiscalYear='2020',
@FullReloadYN='1',@InstanceID='561',@JobID='29627',@JournalTable='[pcETL_DNKLY].[dbo].[Journal]',
@SequenceBM='1',@SourceID='1246',@UserID='-10',@VersionID='1071'

EXEC spIU_DC_Journal_EpicorERP @InstanceID = 531, @VersionID = 1057,@FullReloadYN=1,@SourceID=1214, @DebugBM = 3,
@Book='MainBook',@Debug='1',@Entity_MemberKey='SM',@FiscalYear='2020',@JournalTable='[pcETL_PCX].[dbo].[Journal]',@SequenceBM='1'

EXEC spIU_DC_Journal_EpicorERP @Book='MAIN',@Debug='1',@Entity_MemberKey='DLL',@FiscalYear='2020',@FullReloadYN='1',
@InstanceID='531',@JobID='15353',@JournalTable='[pcETL_DNKLY].[dbo].[Journal]',@SequenceBM='1',@SourceID='1246',
@UserID='-10',@VersionID='1071'

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_Journal_EpicorERP',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "Entity_MemberKey",  "TValue": "52982"},
		{"TKey" : "Book",  "TValue": "CBN_Main"}
		]',
	@Debug = 1

EXEC spIU_DC_Journal_EpicorERP @Book='MAIN',@Debug='0',@Entity_MemberKey='WALL',@FiscalYear='2019',
@InstanceID='451',@JournalTable='[pcETL_UR].[dbo].[Journal]',@SequenceBM='4',
@StartFiscalYear='2011',@UserID='-10',@VersionID='1019',@DebugBM=7

EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = -1080, @VersionID = -1077, @Entity_MemberKey = 'EPIC06', @Book = 'Main', @FiscalYear = 2008, @SequenceBM = 4, @Debug = 1
EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '52982', @Book = 'CBN_Main', @Debug = 1
EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '52982C', @Book = 'ACTS_Main', @FiscalYear = 2020, @Debug = 1
EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 451, @VersionID = 1019, @Entity_MemberKey = 'ATL', @Book = 'MAIN', @SequenceBM = 4, @Debug = 1
EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @Entity_MemberKey = 'CHS', @Book = 'MAIN', @FiscalYear = 2020, @SequenceBM = 1, @Debug = 1
EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @Entity_MemberKey = 'BAXLEY', @Book = 'MAIN', @FiscalYear = 2020, @SequenceBM = 2, @Debug = 1
EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 478, @VersionID = 1030, @Entity_MemberKey = 'AD-001', @Book = 'MAIN', @FiscalYear = 2020, @SequenceBM = 2, @DebugBM = 3
EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 508, @VersionID = 1044, @Entity_MemberKey = 'SAINC', @Book = 'SAIBookMS', @FiscalYear = 2020, @SequenceBM = 3, @DebugBM = 3

EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 486, @VersionID = 1035, @Entity_MemberKey = '1001', @Book = 'MAIN', @FiscalYear = 2020, @SequenceBM = 4, @DebugBM = 2

EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 481, @VersionID = 1031, @SequenceBM = 1, @MaxSourceCounter = 364073737, @DebugBM = 2

EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @SequenceBM = 1, @Entity_MemberKey='GGI01', @Book='NewBook', @FiscalYear = 2021, @DebugBM = 3
EXEC [spIU_DC_Journal_EpicorERP] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @SequenceBM = 1, @MaxSourceCounter = 1834789825, @DebugBM = 2

EXEC [spIU_DC_Journal_EpicorERP] @UserID=-10, @InstanceID=478, @VersionID=1030, @Entity_MemberKey='AD-001', @Book='MAIN', @FiscalYear=2021, @FiscalPeriodString='6', @SequenceBM=1, @JobID=880000772, @DebugBM=11
EXEC [spIU_DC_Journal_EpicorERP] @UserID=-10, @InstanceID=580, @VersionID=1084, @Entity_MemberKey='AD-001', @Book='MAIN', @FiscalYear=2021, @FiscalPeriodString='6', @SequenceBM=1, @JobID=880000772, @DebugBM=11
InstanceID	VersionID
580	1084

EXEC [spIU_DC_Journal_EpicorERP] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@JSON nvarchar(max),
	@CalledYN bit = 1,
	@SourceDatabase nvarchar(100),
	@LinkedServer nvarchar(100),
	@Owner nvarchar(10),
	@EntityID int,
	@Currency nchar(3),
	@SQLStatement nvarchar(max),
	@SQLSegment nvarchar(max),
	@SegmentNo int = -1,
	@AccountSourceCode nvarchar(50),
	@AccountSegmentNo int,
	@InvcHead_ExistsYN bit,
	@Customer_ExistsYN bit,
	@BalAcctDesc_ExistsYN bit,
	@RevisionBM int,
	@SourceTypeID int,
	@SequenceOB int,
	@SourceTypeName nvarchar(50),
	@InvoiceString nvarchar(max),
	@MaxSourceBudgetCounter bigint = NULL,
	@GLJrnHedExistsYN bit,
	@BudgetCodeIDExistsYN bit,
	@BudgetScenario nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@TableName nVARCHAR(100),

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
	@ModifiedBy nvarchar(50) = 'Sega',
	@Version nvarchar(50) = '2.1.2.2192'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into #Journal from source Epicor ERP',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2144' SET @Description = 'Filter on BalanceType = D for opening balances and budget transactions.'
		IF @Version = '2.0.2.2148' SET @Description = 'Added COLLATE DATABASE_DEFAULT TO #BalanceAccount JOINS.'
		IF @Version = '2.0.2.2149' SET @Description = 'Handled Budget data for ERP9 and ERP10.1 by use of @RevisionBM.'
		IF @Version = '2.0.3.2151' SET @Description = 'Updated datatypes in temp table #Journal.'
		IF @Version = '2.0.3.2152' SET @Description = 'Changed to read BalanceType B instead of D for opening balances.'
		IF @Version = '2.0.3.2153' SET @Description = 'Read transaction Currency. Join BalanceType on Entity_Book'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-438: Check for empty BudgetCodeID, default to BUDGET_ERP. Set movements for budget balance accounts. Set JournalSequence to JournalCode instead of SourceModule. Enable FiscalPeriod 13-15. Read Description from GLJrnHed. Added BudgetCode selection.'
		IF @Version = '2.1.0.2155' SET @Description = 'Parameter @FiscalPeriod replaced by @FiscalPeriodString.'
		IF @Version = '2.1.0.2156' SET @Description = 'Added parameter @MaxSourceCounter.'
		IF @Version = '2.1.0.2157' SET @Description = 'Check existence of Customer tables. Use [spGet_Connection] to open linked server.'
		IF @Version = '2.1.0.2160' SET @Description = 'Reload full periods when use incremental.'
		IF @Version = '2.1.0.2161' SET @Description = 'Check @LinkedServer if NOT NULL before calling [spGet_Connection]. Changed prefix in the SP name.'
		IF @Version = '2.1.0.2162' SET @Description = 'Increased column length of Description in temp table #GLJrnDt from 45 to 255.'
		IF @Version = '2.1.0.2165' SET @Description = 'Added parameter @FullReloadYN, to allign with call to iScala. Right now not in use.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle old releases of Epicor ERP where column [BudgetCodeID] does not exists in source table [GLBudgetDtl]. Check Existence of GLJrnHed. Added parameter @FullReloadYN in the call [spGet_Entity_FiscalYear].'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle @FullReloadYN for @SequenceBM  = 4 (Budget). Added @SourceID parameter. Check for not balancing JournalNumbers.'
		IF @Version = '2.1.1.2172' SET @Description = 'Join on Scenario when calculate Movement for Budgets (GLBDprev.[Scenario] = GLBD.[Scenario]). Zerohandling for Budget movements modified. Added COLLATE DATABASE DEFAULT on #GLJrnDtl string fields.' 
		IF @Version = '2.1.1.2173' SET @Description = 'Enhanced debugging for @SQLStatement > 4000. Include schema name [erp] in @TableName parameter for [spGet_TableExistsYN] subroutine. Moved handling of @SequencBM=2 in a separate @Step.'
		IF @Version = '2.1.1.2174' SET @Description = 'When inserting into #Journal, added filter of NOT EXISTS on [SourceGUID] to prevent duplicate Journals. Optimized dynamic t-sql "INSERT INTO #Customer..." in @Step "Journal_Entity_Cursor".'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-731: Updated valid Currency in [Currency_Transaction] column.'
		IF @Version = '2.1.1.2179' SET @Description = 'DB-787: Added filter on [Posted] <> 0 when retrieving Customers from source table [InvcHead].'
		IF @Version = '2.1.1.2180' SET @Description = 'Added parameter @LoadGLJrnDtl_NotBalanceYN. '
		IF @Version = '2.1.1.2181' SET @Description = 'IF @GLJrnHedExistsYN <> 0 then use local temporal table for [GLJrnHed]'
		IF @Version = '2.1.2.2182' SET @Description = 'Modified query for setting @SequenceOB.'
		IF @Version = '2.1.2.2192' SET @Description = 'Add @TableName as variable and handle it'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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
			--@StartFiscalYear = ISNULL(@StartFiscalYear, S.StartYear),
			@SourceID = S.[SourceID],
			@SourceTypeID = S.[SourceTypeID],
			@SourceTypeName = ST.[SourceTypeName],
			@CallistoDatabase = A.DestinationDatabase
		FROM
			[pcINTEGRATOR].[dbo].[Application] A
			INNER JOIN [pcINTEGRATOR].[dbo].Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0 AND (S.SourceID = @SourceID OR @SourceID IS NULL)
			INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = 1
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
				[@Owner] = @Owner,
				[@SourceDatabase] = @SourceDatabase,
				[@LinkedServer] = @LinkedServer,
				[@Currency] = @Currency,
				[@EntityID] = @EntityID,
				[@Book] = @Book,
				[@JournalTable] = @JournalTable,
				[@SequenceBM] = @SequenceBM

		IF @SequenceBM & 3 > 0 AND @LinkedServer IS NOT NULL
			EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer

		IF @SequenceBM & 1 > 0 
			BEGIN
				SET @TableName = @Owner + '.InvcHead'
				EXEC [pcINTEGRATOR].[dbo].spGet_TableExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = @TableName, @ExistsYN = @InvcHead_ExistsYN OUT
				SET @TableName = @Owner + '.Customer'
				EXEC [pcINTEGRATOR].[dbo].spGet_TableExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = @TableName, @ExistsYN = @Customer_ExistsYN OUT

				SET @Customer_ExistsYN = CONVERT(int, @InvcHead_ExistsYN) * CONVERT(int, @Customer_ExistsYN)
			END

		IF @SequenceBM & 2 > 0 
			BEGIN
				SET @TableName = @Owner + '.GLPeriodBal'
				EXEC [pcINTEGRATOR].[dbo].spGet_ColumnExistsYN @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @DatabaseName = @SourceDatabase, @TableName = @TableName, @ColumnName = 'BalAcctDesc', @ExistsYN = @BalAcctDesc_ExistsYN OUT
			END

		IF @DebugBM & 2 > 0
			SELECT 
				[@Customer_ExistsYN] = @Customer_ExistsYN,
				[@BalAcctDesc_ExistsYN] = @BalAcctDesc_ExistsYN

		IF @DebugBM & 16 > 0 SELECT [Step] = 'Initial settings', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Fill table #GLJrnDtl_NotBalance'
		IF OBJECT_ID(N'TempDB.dbo.#GLJrnDtl_NotBalance', N'U') IS NULL
			BEGIN
				CREATE TABLE #GLJrnDtl_NotBalance
					(
					[SourceID] [int],
					[Company] [nvarchar](8),
					[BookID] [nvarchar](12),
					[FiscalYear] [int],
					[FiscalPeriod] [int],
					[JournalCode] [nvarchar](4),
					[JournalNum] [int],
					[MinJournalLine] [int],
					[MaxJournalLine] [int],
					[PostedDate] [date],
					[MinSysRevID] [bigint],
					[MaxSysRevID] [bigint],
					[Rows] [int],
					[Amount] [float],
					[JournalRows] [int],
					[JournalAmount] [float]
					)

				IF @LoadGLJrnDtl_NotBalanceYN = 0
					BEGIN
						EXEC [pcINTEGRATOR].[dbo].[spGet_GLJrnDtl_NotBalance]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@SourceID  = @SourceID,
							@JournalTable = @JournalTable,
							@JobID = @JobID,
							@Debug = @DebugSub
					END
			END

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Create temp table #Callisto_Currency'
		CREATE TABLE #Callisto_Currency
			(
			Currency nvarchar(5) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #Segment'
		CREATE TABLE #Segment
			(
			SourceCode NVARCHAR(50),
			SegmentNo INT,
			DimensionName NVARCHAR(50)
			)

	SET @Step = 'Fill temp table #Segment'
		INSERT INTO #Segment
			(
			SourceCode,
			SegmentNo,
			DimensionName
			)
		SELECT 
			JSN.SourceCode,
			JSN.SegmentNo,
			D.DimensionName
		FROM
			[pcINTEGRATOR].[dbo].Journal_SegmentNo JSN
			LEFT JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.DimensionID = JSN.DimensionID
		WHERE
			EntityID = @EntityID AND
			Book = @Book

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment', * FROM #Segment

		WHILE @SegmentNo < 20
			BEGIN
				SET @SegmentNo = @SegmentNo + 1
				IF @SegmentNo = 0
					SELECT @SQLSegment = '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN SourceCode ELSE '''''' END) + ',' FROM #Segment
				ELSE
					SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(NVARCHAR(10), @SegmentNo) + '] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN SourceCode ELSE '''''' END) + ',' FROM #Segment
			END

		IF @DebugBM & 2 > 0 PRINT @SQLSegment

	SET @Step = 'Get Segment for Account'
		SELECT
			@AccountSourceCode = SourceCode,
			@AccountSegmentNo = LEFT(STUFF(SourceCode, 1, PATINDEX('%[0-9]%', SourceCode)-1, ''), 1)
		FROM
			#Segment
		WHERE
			SegmentNo = 0
		IF @DebugBM & 2 > 0 SELECT AccountSourceCode = @AccountSourceCode, AccountSegmentNo = @AccountSegmentNo

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

	SET @Step = 'Create temp table #Customer, #Invoice'
		IF @SequenceBM & 1 > 0
			BEGIN
				CREATE TABLE #Invoice
					(
					[Company] [NVARCHAR](8),
					[ARInvoiceNum] INT
					)

				CREATE TABLE #Customer
					(
					[Company] [NVARCHAR](8),
					[ARInvoiceNum] INT,
					[CustNum] INT,
					[CustID] NVARCHAR(10) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Create temp table #GLJrnDtl.'
		IF @SequenceBM & 1 > 0
			BEGIN
				CREATE TABLE [dbo].[#GLJrnDtl]
					(
					[Company] [NVARCHAR](8) COLLATE DATABASE_DEFAULT,
					[BookID] [NVARCHAR](12) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [INT],
					[FiscalPeriod] [INT],
					[JournalCode] [NVARCHAR](4) COLLATE DATABASE_DEFAULT,
					[JournalNum] [INT],
					[JournalLine] [INT],
					[FiscalYearSuffix] [NVARCHAR](8) COLLATE DATABASE_DEFAULT,
					[COACode] [NVARCHAR](10) COLLATE DATABASE_DEFAULT,
					[SegValue1] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue2] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue3] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue4] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue5] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue6] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue7] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue8] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue9] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue10] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue11] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue12] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue13] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue14] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue15] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue16] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue17] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue18] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue19] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SegValue20] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[JEDate] [DATE],
					[PostedDate] [DATETIME],
					[Posted] [BIT],
					[PostedBy] [NVARCHAR](75) COLLATE DATABASE_DEFAULT,
					[Description] [NVARCHAR](255) COLLATE DATABASE_DEFAULT,
					[BookDebitAmount] [DECIMAL](18, 3),
					[BookCreditAmount] [DECIMAL](18, 3),
					[CurrencyCode] [NVARCHAR](4) COLLATE DATABASE_DEFAULT,
					[DebitAmount] [DECIMAL](18, 3),
					[CreditAmount] [DECIMAL](18, 3),
					[SourceModule] [NVARCHAR](5) COLLATE DATABASE_DEFAULT,
					[VendorNum] [INT],
					[ARInvoiceNum] [INT],
					[APInvoiceNum] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[SysRevID] [BIGINT],
					[SysRowID] [UNIQUEIDENTIFIER]
					) 
			END

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
					[Segment01] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment02] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment03] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment04] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment05] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment06] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment07] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment08] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment09] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment10] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment11] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment12] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment13] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment14] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment15] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment16] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment17] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment18] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment19] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
					[Segment20] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
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

	--SET @Step = 'Fill temptable #BalanceAccount'
	--	IF @SequenceBM & 5 > 0
	--		BEGIN
	--			SET @SQLStatement = '
	--				INSERT INTO #BalanceAccount
	--					(
	--					Company,
	--					COACode,
	--					Account,
	--					BalanceYN
	--					)
	--				SELECT DISTINCT
	--					COASV.Company,
	--					COASV.COACode,
	--					Account = COASV.SegmentCode,
	--					BalanceYN = CASE WHEN COA.[Type] = ''B'' THEN 1 ELSE 0 END
	--				FROM
	--					' + @SourceDatabase + '.[Erp].[COASegValues] COASV 
	--					INNER JOIN ' + @SourceDatabase + '.[Erp].[COAActCat] COA ON COA.Company = COASV.Company AND COA.CategoryID = COASV.Category
	--				WHERE
	--					COASV.SegmentNbr = ' + CONVERT(nvarchar(10), @AccountSegmentNo)

	--			IF @DebugBM & 2 > 0 PRINT @SQLStatement
	--			EXEC (@SQLStatement)
	--		END

		IF @DebugBM & 16 > 0 SELECT [Step] = 'Create temp tables', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Insert GL transactions into temp table #GLJrnDtl based on @MaxSourceCounter'
		IF @SequenceBM & 1 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO [dbo].[#GLJrnDtl]
						(
						[Company],
						[BookID],
						[FiscalYear],
						[FiscalPeriod],
						[JournalCode],
						[JournalNum],
						[JournalLine],
						[FiscalYearSuffix],
						[COACode],
						[SegValue1],
						[SegValue2],
						[SegValue3],
						[SegValue4],
						[SegValue5],
						[SegValue6],
						[SegValue7],
						[SegValue8],
						[SegValue9],
						[SegValue10],
						[SegValue11],
						[SegValue12],
						[SegValue13],
						[SegValue14],
						[SegValue15],
						[SegValue16],
						[SegValue17],
						[SegValue18],
						[SegValue19],
						[SegValue20],
						[JEDate],
						[PostedDate],
						[Posted],
						[PostedBy],
						[Description],
						[BookDebitAmount],
						[BookCreditAmount],
						[CurrencyCode],
						[DebitAmount],
						[CreditAmount],
						[SourceModule],
						[VendorNum],
						[ARInvoiceNum],
						[APInvoiceNum],
						[SysRevID],
						[SysRowID]
						) 
					SELECT
						GLD.[Company],
						GLD.[BookID],
						GLD.[FiscalYear],
						GLD.[FiscalPeriod],
						GLD.[JournalCode],
						GLD.[JournalNum],
						GLD.[JournalLine],
						GLD.[FiscalYearSuffix],
						GLD.[COACode],
						GLD.[SegValue1],
						GLD.[SegValue2],
						GLD.[SegValue3],
						GLD.[SegValue4],
						GLD.[SegValue5],
						GLD.[SegValue6],
						GLD.[SegValue7],
						GLD.[SegValue8],
						GLD.[SegValue9],
						GLD.[SegValue10],
						GLD.[SegValue11],
						GLD.[SegValue12],
						GLD.[SegValue13],
						GLD.[SegValue14],
						GLD.[SegValue15],
						GLD.[SegValue16],
						GLD.[SegValue17],
						GLD.[SegValue18],
						GLD.[SegValue19],
						GLD.[SegValue20],
						GLD.[JEDate],
						GLD.[PostedDate],
						GLD.[Posted],
						GLD.[PostedBy],
						GLD.[Description],
						GLD.[BookDebitAmount],
						GLD.[BookCreditAmount],
						GLD.[CurrencyCode],
						GLD.[DebitAmount],
						GLD.[CreditAmount],
						GLD.[SourceModule],
						GLD.[VendorNum],
						GLD.[ARInvoiceNum],
						GLD.[APInvoiceNum],
						[SysRevID] = CONVERT(bigint, GLD.[SysRevID]),
						GLD.[SysRowID]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[GLJrnDtl] GLD'

				IF @MaxSourceCounter IS NOT NULL
					BEGIN
						SET @SQLStatement = @SQLStatement + '
					WHERE
						CONVERT(bigint, GLD.[SysRevID]) > ' + CONVERT(NVARCHAR(20), @MaxSourceCounter)
					END
				ELSE IF @MaxSourceCounter IS NULL
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@Entity_MemberKey] = @Entity_MemberKey, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@FiscalPeriodString] = @FiscalPeriodString
						SET @SQLStatement = @SQLStatement + '
					WHERE
						GLD.[Company] = ''' + @Entity_MemberKey + ''' AND
						GLD.[BookID] = ''' + @Book + ''''
						+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'GLD.[FiscalYear] = ' + CONVERT(NVARCHAR(10), @FiscalYear) END
						+ CASE WHEN @FiscalPeriodString IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'GLD.[FiscalPeriod] IN (' + @FiscalPeriodString + ')' END
					END 

				SET @SQLStatement = @SQLStatement + ' AND
						NOT EXISTS (SELECT 1 FROM #GLJrnDtl_NotBalance NB
						WHERE
							NB.[SourceID] = ' + CONVERT(NVARCHAR(15), @SourceID) + ' AND
							NB.[Company] = GLD.[Company] COLLATE DATABASE_DEFAULT AND
							NB.[BookID] = GLD.[BookID] COLLATE DATABASE_DEFAULT AND
							NB.[FiscalYear] = GLD.[FiscalYear] AND
							NB.[FiscalPeriod] = GLD.[FiscalPeriod] AND
							NB.[JournalCode] = GLD.[JournalCode] COLLATE DATABASE_DEFAULT AND
							NB.[JournalNum] = GLD.[JournalNum])'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
				EXEC (@SQLStatement)

				IF @DebugBM & 8 > 0 SELECT TempTable = '#GLJrnDtl', * FROM [#GLJrnDtl] ORDER BY Company, BookID, FiscalYear, FiscalPeriod, [JournalCode], [JournalNum], [JournalLine]
				
				IF @DebugBM & 2 > 0
					BEGIN
						SELECT
							[CheckQuery] = '#GLJrnDtl, duplicates',
							[SysRevID],
							[SysRowID],
							COUNT(1)
						FROM
							[#GLJrnDtl]
						GROUP BY
							[SysRevID],
							[SysRowID]
						HAVING
							COUNT(1) > 1
					END
			END

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

--------------------
	SET @Step = 'Insert previously loaded GL transactions into temp table #Journal from Journal table'
		IF  @SequenceBM & 1 > 0 AND (@MaxSourceCounter IS NOT NULL OR (SELECT COUNT(1) FROM #GLJrnDtl_NotBalance WHERE [SourceID] = @SourceID AND [JournalAmount] = 0) > 0)
			BEGIN
				SELECT DISTINCT
					[Entity] = [Company],
					[Book] = [BookID],
					[FiscalYear] = [FiscalYear],
					[FiscalPeriod] = [FiscalPeriod]
				INTO
					#DistinctPeriods
				FROM
					[#GLJrnDtl]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#DistinctPeriods', * FROM #DistinctPeriods

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
						)
					SELECT
						[JobID] = J.[JobID],
						[InstanceID] = J.[InstanceID],
						[Entity] = J.[Entity],
						[Book] = J.[Book],
						[FiscalYear] = J.[FiscalYear],
						[FiscalPeriod] = J.[FiscalPeriod],
						[JournalSequence] = J.[JournalSequence],
						[JournalNo] = J.[JournalNo],
						[JournalLine] = J.[JournalLine],
						[YearMonth] = J.[YearMonth],
						[TransactionTypeBM] = J.[TransactionTypeBM],
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
						[JournalDate] = J.[JournalDate],
						[TransactionDate] = J.[TransactionDate],
						[PostedDate] = J.[PostedDate],
						[PostedStatus] = J.[PostedStatus],
						[PostedBy] = J.[PostedBy],
						[Source] = J.[Source],
						[Scenario] = J.[Scenario],
						[Customer] = J.[Customer],
						[Supplier] = J.[Supplier],
						[Description_Head] = J.[Description_Head],
						[Description_Line] = J.[Description_Line],
						[Currency_Book] = J.[Currency_Book],
						[ValueDebit_Book] = J.[ValueDebit_Book],
						[ValueCredit_Book] = J.[ValueCredit_Book],
						[Currency_Transaction] = J.[Currency_Transaction],
						[ValueDebit_Transaction] = J.[ValueDebit_Transaction],
						[ValueCredit_Transaction] = J.[ValueCredit_Transaction],
						[SourceModule] = J.[SourceModule],
						[SourceModuleReference] = J.[SourceModuleReference],
						[SourceCounter] = J.[SourceCounter],
						[SourceGUID] = J.[SourceGUID]
					FROM
						' + @JournalTable + ' J
						INNER JOIN #DistinctPeriods DP ON 
							DP.[Entity] = J.[Entity] AND
							DP.[Book] = J.[Book] AND
							DP.[FiscalYear] = J.[FiscalYear] AND
							DP.[FiscalPeriod] = J.[FiscalPeriod]
					WHERE
						J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.[TransactionTypeBM] = 1 AND
						J.[Source] = ''E10'' AND
						J.[Scenario] = ''ACTUAL'' AND
						NOT EXISTS (SELECT 1 FROM [#GLJrnDtl] GLD WHERE GLD.[SysRowID] = J.[SourceGUID])'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)	
				
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Journal_1', * FROM [#Journal] ORDER BY Entity, Book, FiscalYear, FiscalPeriod, [JournalSequence], [JournalNo], [JournalLine]
				IF @DebugBM & 2 > 0
					BEGIN
						
						SELECT
							[CheckQuery] = '#Journal, duplicates, Only previous load',
							[SourceCounter],
							[SourceGUID],
							COUNT(1)
						FROM
							[#Journal]
						GROUP BY
							[SourceCounter],
							[SourceGUID]
						HAVING
							COUNT(1) > 1
					END

			END

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
----------------------

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
					SELECT
						[Entity_MemberKey] = [Company],
						[Book] = [BookID],
						[FiscalYear] = [FiscalYear],
						[StartFiscalYear] = MIN([FiscalYear])
					FROM
						#GLJrnDtl
					GROUP BY
						[Company],
						[BookID],
						[FiscalYear]
					
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

								SET @FiscalPeriodString = ''
								SELECT
									@FiscalPeriodString = @FiscalPeriodString + CONVERT(nvarchar(15), [FiscalPeriod]) + ','
								FROM
									(
									SELECT DISTINCT
										FiscalPeriod
									FROM
										#GLJrnDtl
									WHERE
										[Company] = @Entity_MemberKey AND
										[BookID] = @Book AND
										[FiscalYear] = @FiscalYear
									) sub
								ORDER BY
									[FiscalPeriod]

								SET @FiscalPeriodString = LEFT(@FiscalPeriodString, LEN(@FiscalPeriodString) -1)
								
								IF @DebugBM & 2 > 0 SELECT [@Entity_MemberKey] = @Entity_MemberKey, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@StartFiscalYear] = @StartFiscalYear, [@FiscalPeriodString] = @FiscalPeriodString

								EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriodString = @FiscalPeriodString, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @FullReloadYN = 1, @JobID = @JobID

								IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth

								--Fill temp table #Segment
								TRUNCATE TABLE #Segment
								INSERT INTO #Segment
									(
									SourceCode,
									SegmentNo,
									DimensionName
									)
								SELECT 
									JSN.SourceCode,
									JSN.SegmentNo,
									D.DimensionName
								FROM
									pcINTEGRATOR_Data.dbo.Journal_SegmentNo JSN
									LEFT JOIN Dimension D ON D.DimensionID = JSN.DimensionID
								WHERE
									JSN.InstanceID = @InstanceID AND
									VersionID = @VersionID AND
									EntityID = @EntityID AND
									Book = @Book

								IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment', * FROM #Segment ORDER BY SegmentNo

								--Set variable @SQLSegment
								SELECT @SegmentNo = -1, @SQLSegment = ''
								WHILE @SegmentNo < 20
									BEGIN
										SET @SegmentNo = @SegmentNo + 1
										IF @SegmentNo = 0
											SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN 'GLD.[' + SourceCode + ']' ELSE '''''' END) + ',' FROM #Segment
										ELSE
											SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), @SegmentNo) + '] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN 'GLD.[' + SourceCode + ']' ELSE '''''' END) + ',' FROM #Segment
									END

								IF @DebugBM & 2 > 0 PRINT @SQLSegment

								--Set variables @AccountSourceCode, @AccountSegmentNo
								SELECT
									@AccountSourceCode = SourceCode,
									@AccountSegmentNo = LEFT(stuff(SourceCode, 1, patindex('%[0-9]%', SourceCode)-1, ''), 1)
								FROM
									#Segment
								WHERE
									SegmentNo = 0

								IF @DebugBM & 2 > 0 SELECT AccountSourceCode = @AccountSourceCode, AccountSegmentNo = @AccountSegmentNo

								--Fill temp table #BalanceAccount
								TRUNCATE TABLE #BalanceAccount
								SET @SQLStatement = '
									INSERT INTO #BalanceAccount
										(
										Company,
										COACode,
										Account,
										BalanceYN
										)
									SELECT DISTINCT
										COASV.Company,
										COASV.COACode,
										Account = COASV.SegmentCode,
										BalanceYN = CASE WHEN COA.[Type] = ''B'' THEN 1 ELSE 0 END
									FROM
										' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV 
										INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COAActCat] COA ON COA.Company = COASV.Company AND COA.CategoryID = COASV.Category
									WHERE
										COASV.SegmentNbr = ' + CONVERT(nvarchar(10), @AccountSegmentNo)

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
								EXEC (@SQLStatement)

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

								--Fill temp table #Customer
								TRUNCATE TABLE #Invoice
								TRUNCATE TABLE #Customer

								IF @SequenceBM & 1 > 0
									BEGIN
										EXEC [pcINTEGRATOR].[dbo].[spGet_TableExistsYN] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @SourceDatabase, @TableName = '[Erp].[GLJrnHed]', @ExistsYN = @GLJrnHedExistsYN OUT, @JobID = @JobID, @Debug = @DebugSub
										IF @DebugBM & 2 > 0 SELECT [@GLJrnHedExistsYN] = @GLJrnHedExistsYN

										IF @Customer_ExistsYN <> 0
											BEGIN
												INSERT INTO #Invoice
													(
													[Company],
													[ARInvoiceNum]
													)
												SELECT DISTINCT 
													[Company],
													[ARInvoiceNum]
												FROM
													#GLJrnDtl
												WHERE
													Company = @Entity_MemberKey AND
													BookID = @Book AND
													FiscalYear = @FiscalYear
								
												SET @InvoiceString = ''
												SELECT 
													@InvoiceString = @InvoiceString + CONVERT(nvarchar(15), [ARInvoiceNum]) + ','
												FROM
													#Invoice

												SET @InvoiceString = LEFT(@InvoiceString, LEN(@InvoiceString) -1)

												SET @SQLStatement = '
												INSERT INTO #Customer
													(
													[Company],
													[ARInvoiceNum],
													[CustNum]
													)
												SELECT
													IH.Company,
													IH.InvoiceNum,
													CustNum = MAX(IH.CustNum)
												FROM
													' + @SourceDatabase + '.[' + @Owner + '].[InvcHead] IH 
												JOIN #Invoice INV ON INV.[ARInvoiceNum] = IH.[InvoiceNum]
												WHERE
													IH.Posted <> 0 AND
													IH.Company = ''' + @Entity_MemberKey + '''
												GROUP BY
													IH.Company,
													IH.InvoiceNum'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
												EXEC (@SQLStatement)
												IF @DebugBM & 2 > 0 SELECT * FROM #Customer

												SET @SQLStatement = '
													UPDATE TC
													SET
														CustID = C.CustID
													FROM
														#Customer TC
														INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[Customer] C ON C.Company COLLATE DATABASE_DEFAULT = TC.Company AND C.CustNum = TC.CustNum'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)
												IF @DebugBM & 2 > 0 SELECT * FROM #Customer
											END
										-- If need - fill local temporal table for Headers
										IF @GLJrnHedExistsYN <> 0
											BEGIN 
											CREATE TABLE [dbo].[#GLJrnHed](
												[Company] [nvarchar](max) NOT NULL,
												[FiscalYear] [int] NOT NULL,
												[JournalNum] [int] NOT NULL,
												[Description] [nvarchar](max) NULL,
												[JournalCode] [nvarchar](max) NOT NULL,
												[CommentText] [nvarchar](max) NULL,
												[BookID] [nvarchar](max) NOT NULL,
												[FiscalYearSuffix] [nvarchar](max) NOT NULL
											) 
											SET @SQLStatement = '
					INSERT INTO [dbo].[#GLJrnHed]
								([Company]
								,[FiscalYear]
								,[JournalNum]
								,[Description]
								,[JournalCode]
								,[CommentText]
								,[BookID]
								,[FiscalYearSuffix])
					SELECT		[Company]
								,[FiscalYear]
								,[JournalNum]
								,[Description]
								,[JournalCode]
								,[CommentText]
								,[BookID]
								,isnull([FiscalYearSuffix], '''')
					FROM ' + @SourceDatabase + '.[' + @Owner + '].[GLJrnHed]'
											
											IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
											EXEC (@SQLStatement)
											CREATE CLUSTERED INDEX [GLJrnHed_NonClusteredIndex] ON [dbo].[#GLJrnHed]
											(
												[FiscalYear] ASC,
												[JournalNum] ASC
											)
											END
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
						[Book] = GLD.BookID,
						[FiscalYear] = GLD.[FiscalYear],
						[FiscalPeriod] = GLD.[FiscalPeriod],
						[JournalSequence] = GLD.[JournalCode],
						[JournalNo] = CONVERT(nvarchar(50), GLD.[JournalNum]),
						[JournalLine] = GLD.[JournalLine],
						[YearMonth] = FP.[YearMonth],
						[TransactionTypeBM] = 1,
						[BalanceYN] = ISNULL(B.BalanceYN, 0),' + @SQLSegment + '
						[JournalDate] = CONVERT(date, GLD.[JEDate]),
						[TransactionDate] = CONVERT(date, GLD.[PostedDate]),
						[PostedDate] = CONVERT(date, GLD.[PostedDate]),
						[PostedStatus] = GLD.[Posted],
						[PostedBy] = GLD.[PostedBy],
						[Source] = ''E10'',
						[Scenario] = ''ACTUAL'',
						[Customer] = C.[CustID],
						[Supplier] = GLD.[VendorNum],
						[Description_Head] = LEFT(' + CASE WHEN @GLJrnHedExistsYN = 0 THEN 'GLD.[Description]' ELSE 'ISNULL(GLH.[Description], '''') + CASE WHEN LEN(GLH.[Description]) > 0 AND LEN(GLH.[CommentText]) > 0 THEN '', '' + LEFT(ISNULL(GLH.[CommentText], ''''), 200) ELSE '''' END' END + ',255),
						[Description_Line] = GLD.[Description],
						[Currency_Book] = ''' + @Currency + ''',
						[ValueDebit_Book] = GLD.BookDebitAmount,
						[ValueCredit_Book] = GLD.BookCreditAmount,
						[Currency_Transaction] = LEFT(GLD.CurrencyCode, 3),
						[ValueDebit_Transaction] = GLD.DebitAmount,
						[ValueCredit_Transaction] = GLD.CreditAmount,
						[SourceModule] = GLD.SourceModule,
						[SourceModuleReference] = CASE GLD.SourceModule WHEN ''AR'' THEN CONVERT(nvarchar(100), GLD.ARInvoiceNum) WHEN ''AP'' THEN GLD.APInvoiceNum ELSE '''' END,
						[SourceCounter] = GLD.[SysRevID],
						[SourceGUID] = GLD.[SysRowID]'
										SET @SQLStatement = @SQLStatement + '
					FROM
						[#GLJrnDtl] GLD
						INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GLD.[FiscalYear] AND FP.[FiscalPeriod] = GLD.[FiscalPeriod]
						' + CASE WHEN @GLJrnHedExistsYN = 0 THEN '' ELSE 'LEFT JOIN [#GLJrnHed] GLH ON GLH.Company COLLATE DATABASE_DEFAULT = GLD.Company AND GLH.BookID COLLATE DATABASE_DEFAULT = GLD.BookID AND GLH.FiscalYear = GLD.FiscalYear AND GLH.JournalCode COLLATE DATABASE_DEFAULT = GLD.JournalCode AND GLH.JournalNum = GLD.JournalNum AND GLH.FiscalYearSuffix COLLATE DATABASE_DEFAULT = GLD.FiscalYearSuffix' END + '
						LEFT JOIN #BalanceAccount B on B.Company = GLD.Company COLLATE DATABASE_DEFAULT AND B.COACode = GLD.COACode COLLATE DATABASE_DEFAULT AND B.Account = GLD.' + @AccountSourceCode + ' COLLATE DATABASE_DEFAULT
						LEFT JOIN #Customer C ON C.Company = GLD.Company AND C.ARInvoiceNum = GLD.ARInvoiceNum
					WHERE
						GLD.[Company] = ''' + @Entity_MemberKey + ''' AND
						GLD.[BookID] = ''' + @Book + ''' AND
						GLD.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
						NOT EXISTS (SELECT 1 FROM [#Journal] J1 WHERE J1.[SourceGUID] = GLD.[SysRowID])'
					--					SET @SQLStatement = '
					--INSERT INTO #Journal
					--	(
					--	[JobID],
					--	[InstanceID],
					--	[Entity],
					--	[Book],
					--	[FiscalYear],
					--	[FiscalPeriod],
					--	[JournalSequence],
					--	[JournalNo],
					--	[JournalLine],
					--	[YearMonth],
					--	[TransactionTypeBM],
					--	[BalanceYN],
					--	[Account],
					--	[Segment01],
					--	[Segment02],
					--	[Segment03],
					--	[Segment04],
					--	[Segment05],
					--	[Segment06],
					--	[Segment07],
					--	[Segment08],
					--	[Segment09],
					--	[Segment10],
					--	[Segment11],
					--	[Segment12],
					--	[Segment13],
					--	[Segment14],
					--	[Segment15],
					--	[Segment16],
					--	[Segment17],
					--	[Segment18],
					--	[Segment19],
					--	[Segment20],
					--	[JournalDate],
					--	[TransactionDate],
					--	[PostedDate],
					--	[PostedStatus],
					--	[PostedBy],
					--	[Source],
					--	[Scenario],
					--	[Customer],
					--	[Supplier],
					--	[Description_Head],
					--	[Description_Line],
					--	[Currency_Book],
					--	[ValueDebit_Book],
					--	[ValueCredit_Book],
					--	[Currency_Transaction],
					--	[ValueDebit_Transaction],
					--	[ValueCredit_Transaction],
					--	[SourceModule],
					--	[SourceModuleReference],
					--	[SourceCounter],
					--	[SourceGUID]
					--	)'
					--					SET @SQLStatement = @SQLStatement + '
					--SELECT DISTINCT
					--	[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
					--	[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
					--	[Entity] = ''' + @Entity_MemberKey + ''',
					--	[Book] = GLD.BookID,
					--	[FiscalYear] = GLD.[FiscalYear],
					--	[FiscalPeriod] = GLD.[FiscalPeriod],
					--	[JournalSequence] = GLD.[JournalCode],
					--	[JournalNo] = CONVERT(nvarchar(50), GLD.[JournalNum]),
					--	[JournalLine] = GLD.[JournalLine],
					--	[YearMonth] = FP.[YearMonth],
					--	[TransactionTypeBM] = 1,
					--	[BalanceYN] = ISNULL(B.BalanceYN, 0),' + @SQLSegment + '
					--	[JournalDate] = CONVERT(date, GLD.[JEDate]),
					--	[TransactionDate] = CONVERT(date, GLD.[PostedDate]),
					--	[PostedDate] = CONVERT(date, GLD.[PostedDate]),
					--	[PostedStatus] = GLD.[Posted],
					--	[PostedBy] = GLD.[PostedBy],
					--	[Source] = ''E10'',
					--	[Scenario] = ''ACTUAL'',
					--	[Customer] = C.[CustID],
					--	[Supplier] = GLD.[VendorNum],
					--	[Description_Head] = LEFT(' + CASE WHEN @GLJrnHedExistsYN = 0 THEN 'GLD.[Description]' ELSE 'ISNULL(GLH.[Description], '''') + CASE WHEN LEN(GLH.[Description]) > 0 AND LEN(GLH.[CommentText]) > 0 THEN '', '' + LEFT(ISNULL(GLH.[CommentText], ''''), 200) ELSE '''' END' END + ',255),
					--	[Description_Line] = GLD.[Description],
					--	[Currency_Book] = ''' + @Currency + ''',
					--	[ValueDebit_Book] = GLD.BookDebitAmount,
					--	[ValueCredit_Book] = GLD.BookCreditAmount,
					--	[Currency_Transaction] = LEFT(GLD.CurrencyCode, 3),
					--	[ValueDebit_Transaction] = GLD.DebitAmount,
					--	[ValueCredit_Transaction] = GLD.CreditAmount,
					--	[SourceModule] = GLD.SourceModule,
					--	[SourceModuleReference] = CASE GLD.SourceModule WHEN ''AR'' THEN CONVERT(nvarchar(100), GLD.ARInvoiceNum) WHEN ''AP'' THEN GLD.APInvoiceNum ELSE '''' END,
					--	[SourceCounter] = GLD.[SysRevID],
					--	[SourceGUID] = GLD.[SysRowID]'
					--					SET @SQLStatement = @SQLStatement + '
					--FROM
					--	[#GLJrnDtl] GLD
					--	INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GLD.[FiscalYear] AND FP.[FiscalPeriod] = GLD.[FiscalPeriod]
					--	' + CASE WHEN @GLJrnHedExistsYN = 0 THEN '' ELSE 'LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLJrnHed] GLH ON GLH.Company COLLATE DATABASE_DEFAULT = GLD.Company AND GLH.BookID COLLATE DATABASE_DEFAULT = GLD.BookID AND GLH.FiscalYear = GLD.FiscalYear AND GLH.JournalCode COLLATE DATABASE_DEFAULT = GLD.JournalCode AND GLH.JournalNum = GLD.JournalNum AND GLH.FiscalYearSuffix COLLATE DATABASE_DEFAULT = GLD.FiscalYearSuffix' END + '
					--	LEFT JOIN #BalanceAccount B on B.Company = GLD.Company COLLATE DATABASE_DEFAULT AND B.COACode = GLD.COACode COLLATE DATABASE_DEFAULT AND B.Account = GLD.' + @AccountSourceCode + ' COLLATE DATABASE_DEFAULT
					--	LEFT JOIN #Customer C ON C.Company = GLD.Company AND C.ARInvoiceNum = GLD.ARInvoiceNum
					--WHERE
					--	GLD.[Company] = ''' + @Entity_MemberKey + ''' AND
					--	GLD.[BookID] = ''' + @Book + ''' AND
					--	GLD.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
					--	NOT EXISTS (SELECT 1 FROM [#Journal] J1 WHERE J1.[SourceGUID] = GLD.[SysRowID])'

	/*									IF @DebugBM & 2 > 0 
											BEGIN
												SET @SQLStatement = '
					SELECT 					
						[JobID] = MAX(LEN([JobID])),
						[InstanceID] = MAX(LEN([InstanceID])),
						[Entity] = MAX(LEN([Entity])),
						[Book] = MAX(LEN([Book])),
						[FiscalYear] = MAX(LEN([FiscalYear])),
						[FiscalPeriod] = MAX(LEN([FiscalPeriod])),
						[JournalSequence] = MAX(LEN([JournalSequence])),
						[JournalNo] = MAX(LEN([JournalNo])),
						[JournalLine] = MAX(LEN([JournalLine])),
						[YearMonth] = MAX(LEN([YearMonth])),
						[TransactionTypeBM] = MAX(LEN([TransactionTypeBM])),
						[BalanceYN] = MAX(LEN([BalanceYN])),
						[Account] = MAX(LEN([Account])),
						[Segment01] = MAX(LEN([Segment01])),
						[Segment02] = MAX(LEN([Segment02])),
						[Segment03] = MAX(LEN([Segment03])),
						[Segment04] = MAX(LEN([Segment04])),
						[Segment05] = MAX(LEN([Segment05])),
						[Segment06] = MAX(LEN([Segment06])),
						[Segment07] = MAX(LEN([Segment07])),
						[Segment08] = MAX(LEN([Segment08])),
						[Segment09] = MAX(LEN([Segment09])),
						[Segment10] = MAX(LEN([Segment10])),
						[Segment11] = MAX(LEN([Segment11])),
						[Segment12] = MAX(LEN([Segment12])),
						[Segment13] = MAX(LEN([Segment13])),
						[Segment14] = MAX(LEN([Segment14])),
						[Segment15] = MAX(LEN([Segment15])),
						[Segment16] = MAX(LEN([Segment16])),
						[Segment17] = MAX(LEN([Segment17])),
						[Segment18] = MAX(LEN([Segment18])),
						[Segment19] = MAX(LEN([Segment19])),
						[Segment20] = MAX(LEN([Segment20])),
						[JournalDate] = MAX(LEN([JournalDate])),
						[TransactionDate] = MAX(LEN([TransactionDate])),
						[PostedDate] = MAX(LEN([PostedDate])),
						[PostedStatus] = MAX(LEN([PostedStatus])),
						[PostedBy] = MAX(LEN([PostedBy])),
						[Source] = MAX(LEN([Source])),
						[Scenario] = MAX(LEN([Scenario])),
						[Customer] = MAX(LEN([Customer])),
						[Supplier] = MAX(LEN([Supplier])),
						[Description_Head] = MAX(LEN([Description_Head])),
						[Description_Line] = MAX(LEN([Description_Line])),
						[Currency_Book] = MAX(LEN([Currency_Book])),
						[ValueDebit_Book] = MAX(LEN([ValueDebit_Book])),
						[ValueCredit_Book] = MAX(LEN([ValueCredit_Book])),
						[Currency_Transaction] = MAX(LEN([Currency_Transaction])),
						[ValueDebit_Transaction] = MAX(LEN([ValueDebit_Transaction])),
						[ValueCredit_Transaction] = MAX(LEN([ValueCredit_Transaction])),
						[SourceModule] = MAX(LEN([SourceModule])),
						[SourceModuleReference] = MAX(LEN([SourceModuleReference])),
						[SourceCounter] = MAX(LEN([SourceCounter])),
						[SourceGUID] = MAX(LEN([SourceGUID]))
					FROM
						('
										SET @SQLStatement = @SQLStatement + '
					SELECT
						[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
						[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
						[Entity] = ''' + @Entity_MemberKey + ''',
						[Book] = GLD.BookID,
						[FiscalYear] = GLD.[FiscalYear],
						[FiscalPeriod] = GLD.[FiscalPeriod],
						[JournalSequence] = GLD.[JournalCode],
						[JournalNo] = CONVERT(nvarchar(50), GLD.[JournalNum]),
						[JournalLine] = GLD.[JournalLine],
						[YearMonth] = FP.[YearMonth],
						[TransactionTypeBM] = 1,
						[BalanceYN] = ISNULL(B.BalanceYN, 0),' + @SQLSegment + '
						[JournalDate] = CONVERT(date, GLD.[JEDate]),
						[TransactionDate] = CONVERT(date, GLD.[PostedDate]),
						[PostedDate] = CONVERT(date, GLD.[PostedDate]),
						[PostedStatus] = GLD.[Posted],
						[PostedBy] = GLD.[PostedBy],
						[Source] = ''E10'',
						[Scenario] = ''ACTUAL'',
						[Customer] = C.[CustID],
						[Supplier] = GLD.[VendorNum],
						[Description_Head] = ' + CASE WHEN @GLJrnHedExistsYN = 0 THEN 'GLD.[Description]' ELSE 'ISNULL(GLH.[Description], '''') + CASE WHEN LEN(GLH.[Description]) > 0 AND LEN(GLH.[CommentText]) > 0 THEN '', '' + LEFT(ISNULL(GLH.[CommentText], ''''), 200) ELSE '''' END' END + ',
						[Description_Line] = GLD.[Description],
						[Currency_Book] = ''' + @Currency + ''',
						[ValueDebit_Book] = GLD.BookDebitAmount,
						[ValueCredit_Book] = GLD.BookCreditAmount,
						[Currency_Transaction] = LEFT(GLD.CurrencyCode, 3),
						[ValueDebit_Transaction] = GLD.DebitAmount,
						[ValueCredit_Transaction] = GLD.CreditAmount,
						[SourceModule] = GLD.SourceModule,
						[SourceModuleReference] = CASE GLD.SourceModule WHEN ''AR'' THEN CONVERT(nvarchar(100), GLD.ARInvoiceNum) WHEN ''AP'' THEN GLD.APInvoiceNum ELSE '''' END,
						[SourceCounter] = GLD.[SysRevID],
						[SourceGUID] = GLD.[SysRowID]'
										SET @SQLStatement = @SQLStatement + '
					FROM
						[#GLJrnDtl] GLD
						INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GLD.[FiscalYear] AND FP.[FiscalPeriod] = GLD.[FiscalPeriod]
						' + CASE WHEN @GLJrnHedExistsYN = 0 THEN '' ELSE 'LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLJrnHed] GLH ON GLH.Company COLLATE DATABASE_DEFAULT = GLD.Company AND GLH.BookID COLLATE DATABASE_DEFAULT = GLD.BookID AND GLH.FiscalYear = GLD.FiscalYear AND GLH.JournalCode COLLATE DATABASE_DEFAULT = GLD.JournalCode AND GLH.JournalNum = GLD.JournalNum AND GLH.FiscalYearSuffix COLLATE DATABASE_DEFAULT = GLD.FiscalYearSuffix' END + '
						LEFT JOIN #BalanceAccount B on B.Company = GLD.Company COLLATE DATABASE_DEFAULT AND B.COACode = GLD.COACode COLLATE DATABASE_DEFAULT AND B.Account = GLD.' + @AccountSourceCode + ' COLLATE DATABASE_DEFAULT
						LEFT JOIN #Customer C ON C.Company = GLD.Company AND C.ARInvoiceNum = GLD.ARInvoiceNum
					WHERE
						GLD.[Company] = ''' + @Entity_MemberKey + ''' AND
						GLD.[BookID] = ''' + @Book + ''' AND
						GLD.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + '
					) sub'

											END 
*/
										IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
											BEGIN
												PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Insert GL transactions into temp table #Journal'
												EXEC [dbo].[spSet_wrk_Debug]
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
--IF (@DebugBM & 2 > 0 and @InstanceID = 472 and @FiscalYear = 2013) 
--	BEGIN 
--		DROP TABLE IF EXISTS [dbo].[sega_Journal];
--		DROP TABLE IF EXISTS [dbo].[sega_GLJrnDtl];
--		DROP TABLE IF EXISTS [dbo].[sega_FiscalPeriod];
--		DROP TABLE IF EXISTS [dbo].[sega_BalanceAccount];
--		DROP TABLE IF EXISTS [dbo].[sega_Customer];
--		SELECT * INTO [sega_Journal]		FROM [#Journal]
--		SELECT * INTO [sega_GLJrnDtl]		FROM [#GLJrnDtl];
--		SELECT * INTO [sega_FiscalPeriod]	FROM [#FiscalPeriod];
--		SELECT * INTO [sega_BalanceAccount]	FROM [#BalanceAccount];
--		SELECT * INTO [sega_Customer]		FROM [#Customer];
--		select 1/0;
--		RETURN 0;
--	END

										IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
										EXEC (@SQLStatement)

										SET @Selected = @Selected + @@ROWCOUNT

										DROP TABLE IF EXISTS [#GLJrnHed]

										IF @DebugBM & 2 > 0
											BEGIN
												--SELECT TempTable = '#GLJrnDtl', * FROM [#GLJrnDtl] ORDER BY Company
												SELECT
													[CheckQuery] = '#Journal, duplicates, new loads',
													[SourceCounter],
													[SourceGUID],
													COUNT(1)
												FROM
													[#Journal]
												GROUP BY
													[SourceCounter],
													[SourceGUID]
												HAVING
													COUNT(1) > 1
											END

									END

								FETCH NEXT FROM Journal_Entity_Cursor INTO @Entity_MemberKey, @Book, @FiscalYear, @StartFiscalYear
							END

					CLOSE Journal_Entity_Cursor
					DEALLOCATE Journal_Entity_Cursor
			END

	SET @Step = 'Insert opening balances into temp table #Journal'
		IF @SequenceBM & 2 > 0 AND (SELECT COUNT(1) FROM #FiscalPeriod WHERE FiscalPeriod = 0) > 0 
				AND ((SELECT COUNT(1) FROM #Journal WHERE FiscalPeriod = 1) > 0 OR @FullReloadYN <> 0)
			BEGIN
			
				IF @DebugBM & 32 > 0 
					SELECT 
						[@SQLSegment] = @SQLSegment, [@Entity_MemberKey] = @Entity_MemberKey,[@BalAcctDesc_ExistsYN] = @BalAcctDesc_ExistsYN,
						[@Currency] = @Currency, [@SourceDatabase] = @SourceDatabase, [@Owner] = @Owner, [@Book] = @Book, [@EntityID] = @EntityID, 
						[@JobID] = @JobID, [@ProcedureID] = @ProcedureID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID																										
								
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
						[Entity] = ''' + @Entity_MemberKey + ''',
						[Book] = GLD.BookID,
						[FiscalYear] = GLD.[FiscalYear],
						[FiscalPeriod] = GLD.[FiscalPeriod],
						[JournalSequence] = ''OB_ERP'',
						[JournalNo] = ''0'',
						[JournalLine] = 0,
						[YearMonth] = FP.[YearMonth],
						[TransactionTypeBM] = 4,
						[BalanceYN] = 1,' + @SQLSegment + '
						[JournalDate] = CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112),
						[TransactionDate] = CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112),
						[PostedDate] = CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112),
						[PostedStatus] = 1,
						[PostedBy] = '''',
						[Source] = ''E10'',
						[Scenario] = ''ACTUAL'',
						[Description_Head] = ''Opening balance'',
						[Description_Line] = ' + CASE WHEN @BalAcctDesc_ExistsYN <> 0 THEN 'GLD.[BalAcctDesc]' ELSE '''''' END + ',
						[Currency_Book] = ''' + @Currency + ''',
						[ValueDebit_Book] = CASE WHEN GLD.OpenBalance >= 0 THEN GLD.OpenBalance ELSE 0 END,
						[ValueCredit_Book] = CASE WHEN GLD.OpenBalance < 0 THEN -1 * GLD.OpenBalance ELSE 0 END
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[GLPeriodBal] GLD
						INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GLD.[FiscalYear] AND FP.[FiscalPeriod] = 1
						INNER JOIN pcINTEGRATOR_Data..[Entity_Book] EB ON EB.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND EB.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND EB.[EntityID] = ' + CONVERT(nvarchar(15), @EntityID) + ' AND EB.[Book] = ''' + @Book + ''' AND EB.[BalanceType] = GLD.[BalanceType] COLLATE DATABASE_DEFAULT
					WHERE
						GLD.[Company] = ''' + @Entity_MemberKey + ''' AND
						GLD.[BookID] = ''' + @Book + ''' AND
						GLD.[FiscalPeriod] = 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT


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
		
				EXEC [pcINTEGRATOR].[dbo].[spRun_Procedure_KeyValuePair]
					@ProcedureName = 'spIU_DC_Journal_OpeningBalance',
					@JSON = @JSON

--				EXEC [spIU_DC_Journal_OpeningBalance] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Entity_MemberKey = @Entity_MemberKey, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @SequenceBM = 2, @JournalTable = @JournalTable, @JobID = @JobID, @Debug = @Debug
--				EXEC [spIU_DC_Journal_OpeningBalance] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Entity_MemberKey = @Entity_MemberKey, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @SequenceBM = @SequenceOB, @JournalTable = @JournalTable, @JobID = @JobID, @Debug = @DebugSub
			END

	SET @Step = 'Insert financial budget into temp table #Journal'
		IF @SequenceBM & 4 > 0
			BEGIN
				EXEC [pcINTEGRATOR].[dbo].[spGet_ColumnExistsYN] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @SourceDatabase, @TableName = '[Erp].[GLBudgetDtl]', @ColumnName = 'BudgetCodeID', @ExistsYN = @BudgetCodeIDExistsYN OUT, @JobID = @JobID, @Debug = @DebugSub
				IF @DebugBM & 2 > 0 SELECT [@BudgetCodeIDExistsYN] = @BudgetCodeIDExistsYN

				IF @BudgetCodeIDExistsYN = 0
					SET @BudgetScenario = '''BUDGET_ERP'''
				ELSE
					SET @BudgetScenario = 'GLBD.[BudgetCodeID]'	

				CREATE TABLE #GLBudgetDtl
					(
					[Company] [nvarchar](8),
					[BookID] [nvarchar](12),
					[BalanceAcct] [nvarchar](200),
					[BalanceType] [nvarchar](1),
					[FiscalYear] [int],
					[FiscalYearSuffix] [nvarchar](8),
					[FiscalPeriod] [int],
					[FiscalCalendarID] [nvarchar](12),
					[BudgetCodeID] [nvarchar](16),
					[SegValue1] [nvarchar](50),
					[SegValue2] [nvarchar](50),
					[SegValue3] [nvarchar](50),
					[SegValue4] [nvarchar](50),
					[SegValue5] [nvarchar](50),
					[SegValue6] [nvarchar](50),
					[SegValue7] [nvarchar](50),
					[SegValue8] [nvarchar](50),
					[SegValue9] [nvarchar](50),
					[SegValue10] [nvarchar](50),
					[SegValue11] [nvarchar](50),
					[SegValue12] [nvarchar](50),
					[SegValue13] [nvarchar](50),
					[SegValue14] [nvarchar](50),
					[SegValue15] [nvarchar](50),
					[SegValue16] [nvarchar](50),
					[SegValue17] [nvarchar](50),
					[SegValue18] [nvarchar](50),
					[SegValue19] [nvarchar](50),
					[SegValue20] [nvarchar](50),
					[COACode] [nvarchar](10),
					[BudgetAmt] [decimal](18, 3),
					[SysRevID] [bigint],
					[SysRowID] [uniqueidentifier]
					)

				CREATE TABLE #GLBD
					(
					[FiscalYear] [int],
					[FiscalPeriod] [int],
					[YearMonth] [int],
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
					[Date] [date],
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[BudgetAmt] [float],
					[SourceCounter] [bigint],
					[SourceGUID] [uniqueidentifier]
					)

				SELECT DISTINCT
					[Entity] = E.[MemberKey],
					[BudgetCodeID] = EPV.[EntityPropertyValue]
				INTO
					#BudgetCode
				FROM
					pcINTEGRATOR_Data.dbo.EntityPropertyValue EPV
					INNER JOIN pcINTEGRATOR_Data.dbo.Entity E ON E.InstanceID = EPV.InstanceID AND E.VersionID = EPV.VersionID AND E.EntityID = EPV.EntityID AND E.SelectYN <> 0 AND E.DeletedID IS NULL
				WHERE
					EPV.InstanceID = @InstanceID AND
					EPV.VersionID = @VersionID AND
					EPV.EntityPropertyTypeID = -7 AND
					EPV.SelectYN <> 0

				IF @DebugBM & 2 > 0 SELECT [TempTable_#BudgetCode] = '#BudgetCode', * FROM #BudgetCode

				IF @MaxSourceCounter IS NOT NULL
					BEGIN
						SET @SQLStatement = '
							SELECT	
								@InternalVariable = MAX(SourceCounter)
							FROM
								' + @JournalTable + '
							WHERE
								[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
								[Source] = ''' + @SourceTypeName + ''' AND
								[JournalSequence] = ''Budget'''

						EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @MaxSourceBudgetCounter OUT
					END

				SET @SQLStatement = '
					INSERT INTO #GLBudgetDtl
						(
						[Company],
						[BookID],
						[BalanceAcct],
						[BalanceType],
						[FiscalYear],
						[FiscalYearSuffix],
						[FiscalPeriod],
						[FiscalCalendarID],
						[BudgetCodeID],
						[SegValue1],
						[SegValue2],
						[SegValue3],
						[SegValue4],
						[SegValue5],
						[SegValue6],
						[SegValue7],
						[SegValue8],
						[SegValue9],
						[SegValue10],
						[SegValue11],
						[SegValue12],
						[SegValue13],
						[SegValue14],
						[SegValue15],
						[SegValue16],
						[SegValue17],
						[SegValue18],
						[SegValue19],
						[SegValue20],
						[COACode],
						[BudgetAmt],
						[SysRevID],
						[SysRowID]
						)
					SELECT
						[Company],
						[BookID],
						[BalanceAcct],
						[BalanceType],
						[FiscalYear],
						[FiscalYearSuffix],
						[FiscalPeriod],
						[FiscalCalendarID],
						[BudgetCodeID] = ' + @BudgetScenario + ',
						[SegValue1],
						[SegValue2],
						[SegValue3],
						[SegValue4],
						[SegValue5],
						[SegValue6],
						[SegValue7],
						[SegValue8],
						[SegValue9],
						[SegValue10],
						[SegValue11],
						[SegValue12],
						[SegValue13],
						[SegValue14],
						[SegValue15],
						[SegValue16],
						[SegValue17],
						[SegValue18],
						[SegValue19],
						[SegValue20],
						[COACode],
						[BudgetAmt],
						[SysRevID] = CONVERT(bigint, GLBD.[SysRevID]),
						[SysRowID]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[GLBudgetDtl] GLBD
						INNER JOIN #BudgetCode BC ON BC.[Entity] = GLBD.[Company] COLLATE DATABASE_DEFAULT AND BC.[BudgetCodeID] = ' + @BudgetScenario + ' COLLATE DATABASE_DEFAULT
					WHERE
--						GLBD.[BudgetAmt] <> 0 AND
						GLBD.[BalanceType] = ''D'' AND'

				IF @MaxSourceBudgetCounter IS NOT NULL AND @FullReloadYN = 0
					BEGIN
						SET @SQLStatement = @SQLStatement + '
						CONVERT(bigint, GLBD.[SysRevID]) > ' + CONVERT(nvarchar(20), @MaxSourceBudgetCounter)
					END
				ELSE
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@Entity_MemberKey] = @Entity_MemberKey, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@FiscalPeriodString] = @FiscalPeriodString
						SET @SQLStatement = @SQLStatement + '
						GLBD.[Company] = ''' + @Entity_MemberKey + ''' AND
						GLBD.[BookID] = ''' + @Book + ''''
						+ CASE WHEN @FiscalYear IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'GLBD.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) END
						+ CASE WHEN @FiscalPeriodString IS NULL THEN '' ELSE ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'GLBD.[FiscalPeriod] IN (' + @FiscalPeriodString + ')' END
					END 

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#GLBudgetDtl', * FROM [#GLBudgetDtl] ORDER BY Company

				--SELECT
				--	Company,
				--	BookID, 
				--	BudgetCodeID,
				--	FiscalYear = MIN(FiscalYear) - 1,
				--	FiscalPeriod = 12
				--FROM
				--	#GLBudgetDtl
				--GROUP BY
				--	Company,
				--	BookID,
				--	BudgetCodeID

				SET @Step = 'Journal_Entity_Budget_Cursor'
					IF CURSOR_STATUS('global','Journal_Entity_Budget_Cursor') >= -1 DEALLOCATE Journal_Entity_Budget_Cursor
					DECLARE Journal_Entity_Budget_Cursor CURSOR FOR
			
						SELECT DISTINCT
							Entity_MemberKey = Company,
							Book = BookID,
							FiscalYear = FiscalYear,
							StartFiscalYear = MIN(FiscalYear)
						FROM
							#GLBudgetDtl
						GROUP BY
							Company,
							BookID,
							FiscalYear

						OPEN Journal_Entity_Budget_Cursor
						FETCH NEXT FROM Journal_Entity_Budget_Cursor INTO @Entity_MemberKey, @Book, @FiscalYear, @StartFiscalYear

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

								SET @FiscalPeriodString = ''
								SELECT
									@FiscalPeriodString = @FiscalPeriodString + CONVERT(nvarchar(15), [FiscalPeriod]) + ','
								FROM
									(
									SELECT DISTINCT
										FiscalPeriod
									FROM
										#GLBudgetDtl
									WHERE
										[Company] = @Entity_MemberKey AND
										[BookID] = @Book AND
										[FiscalYear] = @FiscalYear
									) sub
								ORDER BY
									[FiscalPeriod]

								SET @FiscalPeriodString = LEFT(@FiscalPeriodString, LEN(@FiscalPeriodString) -1)
								
								IF @DebugBM & 2 > 0 SELECT [@Entity_MemberKey] = @Entity_MemberKey, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@StartFiscalYear] = @StartFiscalYear, [@FiscalPeriodString] = @FiscalPeriodString

								EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriodString = @FiscalPeriodString, @FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @JobID = @JobID

								INSERT INTO #FiscalPeriod
									(
									FiscalYear,
									FiscalPeriod,
									YearMonth
									)
								SELECT
									FiscalYear = MIN(FiscalYear) - 1,
									FiscalPeriod = 12,
									YearMonth = 0
								FROM
									#FiscalPeriod

								IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth

								--Fill temp table #Segment
								TRUNCATE TABLE #Segment
								INSERT INTO #Segment
									(
									SourceCode,
									SegmentNo,
									DimensionName
									)
								SELECT 
									JSN.SourceCode,
									JSN.SegmentNo,
									D.DimensionName
								FROM
									pcINTEGRATOR_Data.dbo.Journal_SegmentNo JSN
									LEFT JOIN Dimension D ON D.DimensionID = JSN.DimensionID
								WHERE
									JSN.InstanceID = @InstanceID AND
									VersionID = @VersionID AND
									EntityID = @EntityID AND
									Book = @Book

								IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment', * FROM #Segment ORDER BY SegmentNo

								--Set variable @SQLSegment
								SELECT @SegmentNo = -1, @SQLSegment = ''
								WHILE @SegmentNo < 20
									BEGIN
										SET @SegmentNo = @SegmentNo + 1
										IF @SegmentNo = 0
											SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN 'GLBD.[' + SourceCode + ']' ELSE '''''' END) + ',' FROM #Segment
										ELSE
											SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), @SegmentNo) + '] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN 'GLBD.[' + SourceCode + ']' ELSE '''''' END) + ',' FROM #Segment
									END

								IF @DebugBM & 2 > 0 PRINT @SQLSegment

								--Set variables @AccountSourceCode, @AccountSegmentNo
								SELECT
									@AccountSourceCode = SourceCode,
									@AccountSegmentNo = LEFT(stuff(SourceCode, 1, patindex('%[0-9]%', SourceCode)-1, ''), 1)
								FROM
									#Segment
								WHERE
									SegmentNo = 0

								IF @DebugBM & 2 > 0 SELECT AccountSourceCode = @AccountSourceCode, AccountSegmentNo = @AccountSegmentNo

								--Fill temp table #BalanceAccount
								TRUNCATE TABLE #BalanceAccount
								SET @SQLStatement = '
									INSERT INTO #BalanceAccount
										(
										Company,
										COACode,
										Account,
										BalanceYN
										)
									SELECT DISTINCT
										COASV.Company,
										COASV.COACode,
										Account = COASV.SegmentCode,
										BalanceYN = CASE WHEN COA.[Type] = ''B'' THEN 1 ELSE 0 END
									FROM
										' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV 
										INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COAActCat] COA ON COA.Company = COASV.Company AND COA.CategoryID = COASV.Category
									WHERE
										COASV.SegmentNbr = ' + CONVERT(nvarchar(10), @AccountSegmentNo)

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								IF  @LinkedServer IS NOT NULL EXEC [pcINTEGRATOR].[dbo].[spGet_Connection] @LinkedServer = @LinkedServer
								EXEC (@SQLStatement)

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

				TRUNCATE TABLE #GLBD
				SET @SQLStatement = '
					INSERT INTO #GLBD
						(
						[FiscalYear],
						[FiscalPeriod],
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
						[Date],
						[Scenario],
						[BudgetAmt],
						[SourceCounter],
						[SourceGUID]
						)
					SELECT
						[FiscalYear] = GLBD.[FiscalYear],
						[FiscalPeriod] = GLBD.[FiscalPeriod],
						[YearMonth] = FP.[YearMonth],
						[BalanceYN] = B.BalanceYN,
						' + @SQLSegment + '
						[Date] = CASE WHEN FP.[YearMonth] <> 0 THEN DATEADD(Day, -1, DATEADD(Month, 1, CONVERT(date, CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + ''01'', 112)))) END,
						[Scenario] = GLBD.[BudgetCodeID],
						[BudgetAmt] = GLBD.[BudgetAmt],
						[SourceCounter] = GLBD.[SysRevID],
						[SourceGUID] = GLBD.[SysRowID]
					FROM 
						[#GLBudgetDtl] GLBD
						INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = GLBD.[FiscalYear] AND FP.[FiscalPeriod] = GLBD.[FiscalPeriod]
						INNER JOIN #BalanceAccount B on B.Company = GLBD.Company COLLATE DATABASE_DEFAULT AND B.COACode = GLBD.COACode COLLATE DATABASE_DEFAULT AND B.Account = GLBD.SegValue1 COLLATE DATABASE_DEFAULT
					WHERE
						GLBD.[Company] = ''' + @Entity_MemberKey + ''' AND
						GLBD.[BookID] = ''' + @Book + ''' AND
--						GLBD.[BudgetAmt] <> 0 AND
						GLBD.[BalanceType] = ''D'' AND
						(FP.[YearMonth] <> 0 OR B.BalanceYN <> 0)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#GLBD', * FROM #GLBD ORDER BY [Account], [YearMonth]

				--Budget opening balance
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
					[ValueCredit_Book],
					[SourceCounter],
					[SourceGUID]
					)
				SELECT
					[JobID] = ISNULL(@JobID, @ProcedureID),
					[InstanceID] = @InstanceID,
					[Entity] = @Entity_MemberKey,
					[Book] = @Book,
					[FiscalYear] = FP.[FiscalYear],
					[FiscalPeriod] = 0,
					[JournalSequence] = 'Budget',
					[JournalNo] = '0',
					[JournalLine] = 0,
					[YearMonth] = MAX(FP.[YearMonth]),
					[TransactionTypeBM] = 2,
					[BalanceYN] = 1,
					[Account] = GLBD.[Account],
					[Segment01] = GLBD.[Segment01],
					[Segment02] = GLBD.[Segment02],
					[Segment03] = GLBD.[Segment03],
					[Segment04] = GLBD.[Segment04],
					[Segment05] = GLBD.[Segment05],
					[Segment06] = GLBD.[Segment06],
					[Segment07] = GLBD.[Segment07],
					[Segment08] = GLBD.[Segment08],
					[Segment09] = GLBD.[Segment09],
					[Segment10] = GLBD.[Segment10],
					[Segment11] = GLBD.[Segment11],
					[Segment12] = GLBD.[Segment12],
					[Segment13] = GLBD.[Segment13],
					[Segment14] = GLBD.[Segment14],
					[Segment15] = GLBD.[Segment15],
					[Segment16] = GLBD.[Segment16],
					[Segment17] = GLBD.[Segment17],
					[Segment18] = GLBD.[Segment18],
					[Segment19] = GLBD.[Segment19],
					[Segment20] = GLBD.[Segment20],
					[JournalDate] = MAX(CONVERT(date, CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + '01', 112))),
					[TransactionDate] = MAX(CONVERT(date, CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + '01', 112))),
					[PostedDate] = MAX(CONVERT(date, CONVERT(datetime, CONVERT(nvarchar(6), FP.[YearMonth]) + '01', 112))),
					[PostedStatus] = 1,
					[PostedBy] = '',
					[Source] = @SourceTypeName,
					[Scenario] = GLBD.[Scenario],
					[Description_Head] = 'Budget, Opening balance',
					[Description_Line] = GLBD.[Scenario],
					[Currency_Book] = @Currency,
					[ValueDebit_Book] = ROUND(SUM(CASE WHEN GLBD.[BudgetAmt] >= 0 THEN GLBD.[BudgetAmt] ELSE 0 END), 4),
					[ValueCredit_Book] = ROUND(SUM(CASE WHEN GLBD.[BudgetAmt] < 0 THEN -1 * GLBD.[BudgetAmt] ELSE 0 END), 4),
					[SourceCounter] = MAX(GLBD.[SourceCounter]),
					[SourceGUID] = MAX(GLBD.[SourceGUID])
				FROM
					#GLBD GLBD
					INNER JOIN #FiscalPeriod FP ON FP.FiscalPeriod = 1 AND FP.[FiscalYear] - 1 = GLBD.[FiscalYear] AND FP.YearMonth <> 0
				WHERE
					GLBD.BalanceYN <> 0 AND
					GLBD.[FiscalPeriod] = 12
				GROUP BY
					FP.[FiscalYear],
					GLBD.[Scenario],
					GLBD.[Account],
					GLBD.[Segment01],
					GLBD.[Segment02],
					GLBD.[Segment03],
					GLBD.[Segment04],
					GLBD.[Segment05],
					GLBD.[Segment06],
					GLBD.[Segment07],
					GLBD.[Segment08],
					GLBD.[Segment09],
					GLBD.[Segment10],
					GLBD.[Segment11],
					GLBD.[Segment12],
					GLBD.[Segment13],
					GLBD.[Segment14],
					GLBD.[Segment15],
					GLBD.[Segment16],
					GLBD.[Segment17],
					GLBD.[Segment18],
					GLBD.[Segment19],
					GLBD.[Segment20]

				SET @Selected = @Selected + @@ROWCOUNT

				--Movement
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
					[ValueCredit_Book],
					[SourceCounter],
					[SourceGUID]
					)
				SELECT
					[JobID] = ISNULL(@JobID, @ProcedureID),
					[InstanceID] = @InstanceID,
					[Entity] = @Entity_MemberKey,
					[Book] = @Book,
					[FiscalYear] = GLBD.[FiscalYear],
					[FiscalPeriod] = GLBD.[FiscalPeriod],
					[JournalSequence] = 'Budget',
					[JournalNo] = '0',
					[JournalLine] = 0,
					[YearMonth] = GLBD.[YearMonth],
					[TransactionTypeBM] = 2,
					[BalanceYN] = GLBD.BalanceYN,
					[Account] = GLBD.[Account],
					[Segment01] = GLBD.[Segment01],
					[Segment02] = GLBD.[Segment02],
					[Segment03] = GLBD.[Segment03],
					[Segment04] = GLBD.[Segment04],
					[Segment05] = GLBD.[Segment05],
					[Segment06] = GLBD.[Segment06],
					[Segment07] = GLBD.[Segment07],
					[Segment08] = GLBD.[Segment08],
					[Segment09] = GLBD.[Segment09],
					[Segment10] = GLBD.[Segment10],
					[Segment11] = GLBD.[Segment11],
					[Segment12] = GLBD.[Segment12],
					[Segment13] = GLBD.[Segment13],
					[Segment14] = GLBD.[Segment14],
					[Segment15] = GLBD.[Segment15],
					[Segment16] = GLBD.[Segment16],
					[Segment17] = GLBD.[Segment17],
					[Segment18] = GLBD.[Segment18],
					[Segment19] = GLBD.[Segment19],
					[Segment20] = GLBD.[Segment20],
					[JournalDate] = GLBD.[Date],
					[TransactionDate] = GLBD.[Date],
					[PostedDate] = GLBD.[Date],
					[PostedStatus] = 1,
					[PostedBy] = '',
					[Source] = @SourceTypeName,
					[Scenario] = GLBD.[Scenario],
					[Description_Head] = 'Budget, balance movement',
					[Description_Line] = GLBD.[Scenario],
					[Currency_Book] = @Currency,
					[ValueDebit_Book] = ROUND(CASE WHEN GLBD.[BudgetAmt] - ISNULL(GLBDprev.[BudgetAmt], 0) >= 0 THEN GLBD.[BudgetAmt] - ISNULL(GLBDprev.[BudgetAmt], 0) ELSE 0 END, 4),
					[ValueCredit_Book] = ROUND(CASE WHEN GLBD.[BudgetAmt] - ISNULL(GLBDprev.[BudgetAmt], 0) < 0 THEN -1 * (GLBD.[BudgetAmt] - ISNULL(GLBDprev.[BudgetAmt], 0)) ELSE 0 END, 4),
					[SourceCounter] = GLBD.[SourceCounter],
					[SourceGUID] = GLBD.[SourceGUID]
				FROM
					#GLBD GLBD
					LEFT JOIN #GLBD GLBDprev ON
						(GLBDprev.[FiscalYear] = GLBD.[FiscalYear] OR (GLBDprev.[FiscalYear] = GLBD.[FiscalYear] - 1 AND GLBD.[FiscalPeriod] = 1)) AND
						(GLBDprev.[FiscalPeriod] = GLBD.[FiscalPeriod] - 1 OR (GLBDprev.[FiscalYear] = GLBD.[FiscalYear] - 1 AND GLBDprev.[FiscalPeriod] = 12)) AND
						GLBDprev.[Account] = GLBD.[Account] AND
						GLBDprev.[Segment01] = GLBD.[Segment01] AND
						GLBDprev.[Segment02] = GLBD.[Segment02] AND
						GLBDprev.[Segment03] = GLBD.[Segment03] AND
						GLBDprev.[Segment04] = GLBD.[Segment04] AND
						GLBDprev.[Segment05] = GLBD.[Segment05] AND
						GLBDprev.[Segment06] = GLBD.[Segment06] AND
						GLBDprev.[Segment07] = GLBD.[Segment07] AND
						GLBDprev.[Segment08] = GLBD.[Segment08] AND
						GLBDprev.[Segment09] = GLBD.[Segment09] AND
						GLBDprev.[Segment10] = GLBD.[Segment10] AND
						GLBDprev.[Segment11] = GLBD.[Segment11] AND
						GLBDprev.[Segment12] = GLBD.[Segment12] AND
						GLBDprev.[Segment13] = GLBD.[Segment13] AND
						GLBDprev.[Segment14] = GLBD.[Segment14] AND
						GLBDprev.[Segment15] = GLBD.[Segment15] AND
						GLBDprev.[Segment16] = GLBD.[Segment16] AND
						GLBDprev.[Segment17] = GLBD.[Segment17] AND
						GLBDprev.[Segment18] = GLBD.[Segment18] AND
						GLBDprev.[Segment19] = GLBD.[Segment19] AND
						GLBDprev.[Segment20] = GLBD.[Segment20] AND
						GLBDprev.[Scenario] = GLBD.[Scenario]
				WHERE
					GLBD.BalanceYN <> 0 AND
					GLBD.YearMonth <> 0 AND
					GLBD.FiscalPeriod <> 0 AND
					ROUND(GLBD.[BudgetAmt] - ISNULL(GLBDprev.[BudgetAmt], 0), 4) <> 0.0

				SET @Selected = @Selected + @@ROWCOUNT

								FETCH NEXT FROM Journal_Entity_Budget_Cursor INTO @Entity_MemberKey, @Book, @FiscalYear, @StartFiscalYear
							END

					CLOSE Journal_Entity_Budget_Cursor
					DEALLOCATE Journal_Entity_Budget_Cursor

--=======================================

				--Remove Opening balances that does not exists in current year
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
					[ValueCredit_Book],
					[SourceCounter],
					[SourceGUID]
					)
				SELECT
					[JobID],
					[InstanceID],
					[Entity],
					[Book],
					[FiscalYear],
					[FiscalPeriod] = 1,
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
					[ValueDebit_Book] = [ValueCredit_Book],
					[ValueCredit_Book] = [ValueDebit_Book],
					[SourceCounter] = [SourceCounter],
					[SourceGUID] = [SourceGUID]
				FROM
					#Journal J
				WHERE
					[JournalSequence] = 'Budget' AND
					[BalanceYN] <> 0 AND
					[FiscalPeriod] = 0 AND
					NOT EXISTS (SELECT 1 FROM #Journal DJ 
						WHERE
							DJ.[Entity] = J.[Entity] AND
							DJ.[Book] = J.[Book] AND
							DJ.[FiscalYear] = J.[FiscalYear] AND
							DJ.[FiscalPeriod] = 1 AND
							DJ.[JournalSequence] = J.[JournalSequence] AND
							DJ.[BalanceYN] = J.[BalanceYN] AND
							DJ.[Account] = J.[Account] AND
							DJ.[Segment01] = J.[Segment01] AND
							DJ.[Segment02] = J.[Segment02] AND
							DJ.[Segment03] = J.[Segment03] AND
							DJ.[Segment04] = J.[Segment04] AND
							DJ.[Segment05] = J.[Segment05] AND
							DJ.[Segment06] = J.[Segment06] AND
							DJ.[Segment07] = J.[Segment07] AND
							DJ.[Segment08] = J.[Segment08] AND
							DJ.[Segment09] = J.[Segment09] AND
							DJ.[Segment10] = J.[Segment10] AND
							DJ.[Segment11] = J.[Segment11] AND
							DJ.[Segment12] = J.[Segment12] AND
							DJ.[Segment13] = J.[Segment13] AND
							DJ.[Segment14] = J.[Segment14] AND
							DJ.[Segment15] = J.[Segment15] AND
							DJ.[Segment16] = J.[Segment16] AND
							DJ.[Segment17] = J.[Segment17] AND
							DJ.[Segment18] = J.[Segment18] AND
							DJ.[Segment19] = J.[Segment19] AND
							DJ.[Segment20] = J.[Segment20] AND
							DJ.[Scenario] = J.[Scenario]
							)

				SET @Selected = @Selected + @@ROWCOUNT

				DELETE #Journal
				WHERE
					[JournalSequence] = 'Budget' AND
					[BalanceYN] <> 0 AND
					ROUND([ValueDebit_Book] - [ValueCredit_Book], 4) = 0.0

				--P&L
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
					[ValueCredit_Book],
					[SourceCounter],
					[SourceGUID]
					)
				SELECT
					[JobID] = ISNULL(@JobID, @ProcedureID),
					[InstanceID] = @InstanceID,
					[Entity] = @Entity_MemberKey,
					[Book] = @Book,
					[FiscalYear] = GLBD.[FiscalYear],
					[FiscalPeriod] = GLBD.[FiscalPeriod],
					[JournalSequence] = 'Budget',
					[JournalNo] = '0',
					[JournalLine] = 0,
					[YearMonth] = GLBD.[YearMonth],
					[TransactionTypeBM] = 1,
					[BalanceYN] = GLBD.BalanceYN,
					[Account] = GLBD.[Account],
					[Segment01] = GLBD.[Segment01],
					[Segment02] = GLBD.[Segment02],
					[Segment03] = GLBD.[Segment03],
					[Segment04] = GLBD.[Segment04],
					[Segment05] = GLBD.[Segment05],
					[Segment06] = GLBD.[Segment06],
					[Segment07] = GLBD.[Segment07],
					[Segment08] = GLBD.[Segment08],
					[Segment09] = GLBD.[Segment09],
					[Segment10] = GLBD.[Segment10],
					[Segment11] = GLBD.[Segment11],
					[Segment12] = GLBD.[Segment12],
					[Segment13] = GLBD.[Segment13],
					[Segment14] = GLBD.[Segment14],
					[Segment15] = GLBD.[Segment15],
					[Segment16] = GLBD.[Segment16],
					[Segment17] = GLBD.[Segment17],
					[Segment18] = GLBD.[Segment18],
					[Segment19] = GLBD.[Segment19],
					[Segment20] = GLBD.[Segment20],
					[JournalDate] = GLBD.[Date],
					[TransactionDate] = GLBD.[Date],
					[PostedDate] = GLBD.[Date],
					[PostedStatus] = 1,
					[PostedBy] = '',
					[Source] = @SourceTypeName,
					[Scenario] = GLBD.[Scenario],
					[Description_Head] = 'Budget P&L accounts',
					[Description_Line] = GLBD.[Scenario],
					[Currency_Book] = @Currency,
					[ValueDebit_Book] = ROUND(CASE WHEN GLBD.[BudgetAmt] >= 0 THEN GLBD.[BudgetAmt] ELSE 0 END, 4),
					[ValueCredit_Book] = ROUND(CASE WHEN GLBD.[BudgetAmt] < 0 THEN -1 * GLBD.[BudgetAmt] ELSE 0 END, 4),
					[SourceCounter],
					[SourceGUID]
				FROM
					#GLBD GLBD
				WHERE
					GLBD.BalanceYN = 0 AND
					GLBD.YearMonth <> 0 AND
					GLBD.FiscalPeriod <> 0 AND
					ROUND(GLBD.[BudgetAmt], 4) <> 0.0

				SET @Selected = @Selected + @@ROWCOUNT

				IF @DebugBM & 8 > 0 SELECT TempTable = '#Journal', * FROM #Journal ORDER BY [Account], [YearMonth]
			END

		IF @DebugBM & 1 > 0 SELECT TempTable = '#Journal', * FROM #Journal ORDER BY JournalSequence, FiscalYear, FiscalPeriod, Account, Segment01, Segment02
		IF @DebugBM & 2 > 0
			BEGIN
				--SELECT TempTable = '#GLJrnDtl', * FROM [#GLJrnDtl] ORDER BY Company
				SELECT
					[CheckQuery] = '#Journal, duplicates',
					[SourceCounter],
					[SourceGUID],
					COUNT(1)
				FROM
					[#Journal]
				GROUP BY
					[SourceCounter],
					[SourceGUID]
				HAVING
					COUNT(1) > 1
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
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #Journal
				DROP TABLE #Entity_Book_FiscalYear
			END
		IF @SequenceBM & 1 > 0
			BEGIN
				DROP TABLE #GLJrnDtl
				DROP TABLE #Invoice
				DROP TABLE #Customer
			END
		IF @SequenceBM & 4 > 0
			BEGIN
				DROP TABLE #GLBudgetDtl
				DROP TABLE #GLBD
				DROP TABLE #BudgetCode
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
