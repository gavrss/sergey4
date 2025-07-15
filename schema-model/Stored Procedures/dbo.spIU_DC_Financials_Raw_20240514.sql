SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Financials_Raw_20240514]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBM int = 3, --1 = P&L transactions, 2 = Balance Sheet transactions, 4 = Not differentiated by TimeBalance
	@FieldTypeBM int = 1, --1 = Book currency, 2 = Transaction Currency, 4 = Consolidation, 8 = PostedInfo, 16 = InsertedInfo
	@ConsolidationGroupYN bit = 0,
	@ConsolidationGroup nvarchar(50) = NULL, --Optional

	@Entity nvarchar(50) = NULL, --Mandatory
	@Book nvarchar(50) = NULL, --Mandatory
	@Scenario nvarchar(100) = NULL, --Mandatory
	@FiscalYear int = NULL, --Optional

	@MasterStartTime datetime = NULL,
	@JournalTable nvarchar(100) = NULL,
	@TempTable_ObjectID INT = NULL,
	@JobIDFilterYN bit = 0,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000632,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large temp tables

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spIU_DC_Financials_Raw] @Book='BRA2',@ConsolidationGroupYN='0',@Debug='0',@Entity='BRASIL',@FieldTypeBM='1',@FiscalYear='2018',
@InstanceID='584',@JournalTable='[pcETL_INVK].[dbo].[Journal]',@Scenario='ACTUAL',@SequenceBM='3',@UserID='-10',@VersionID='1086',@DebugBM=15

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_Financials_Raw',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"},
		{"TKey" : "Entity",  "TValue": "EPIC03"},
		{"TKey" : "Book",  "TValue": "MAIN"}
		]'

EXEC [spIU_DC_Financials_Raw] @UserID='-10',@InstanceID='470',@VersionID='1025',
@SequenceBM='3',@FieldTypeBM='1',@ConsolidationGroupYN='0',
@Entity='MNTCO',@Book='ACTUAL',@Scenario='ACTUAL',@FiscalYear='2020',
@JournalTable='[pcETL_SOCAN].[dbo].[Journal]',@DebugBM='7'

EXEC [spIU_DC_Financials_Raw] @UserID=-10, @InstanceID=390, @VersionID=1011, @Entity='EPIC03', @Book='MAIN', @SequenceBM=2, @Debug=1
EXEC [spIU_DC_Financials_Raw] @UserID=-10, @InstanceID=454, @VersionID=1021, @Entity='C010', @Book='MAIN', @FiscalYear = 2018, @Debug=1
EXEC [spIU_DC_Financials_Raw] @UserID=-10, @InstanceID=454, @VersionID=1021, @Entity='C010', @Book='MAIN', @FiscalYear = 2019, @Debug=1
EXEC [spIU_DC_Financials_Raw] @UserID=-10, @InstanceID=454, @VersionID=1021, @Entity='C010', @Book='MAIN', @SequenceBM=4, @Debug=1

EXEC [spIU_DC_Financials_Raw] @UserID=-10, @InstanceID=413, @VersionID=1008, @Entity='52982', @Book='CBN_Main', @FiscalYear = 2020, @SequenceBM = 2, @Debug=1
EXEC [spIU_DC_Financials_Raw] @UserID=-10, @InstanceID=413, @VersionID=1008, @Entity='52982', @Book='CBN_Main', @FiscalYear = 2019, @SequenceBM = 2, @Debug=1

EXEC spIU_DC_Financials_Raw @Book='CBN_Tax',@Entity='52982',@FiscalYear='2020',@InstanceID='413',@Scenario='ACTUAL',@SequenceBM='1',@UserID='-10',@VersionID='1008',@Debug=1
EXEC spIU_DC_Financials_Raw @Book='CBN_Tax',@Entity='52982',@FiscalYear='2019',@InstanceID='413',@Scenario='ACTUAL',@SequenceBM='2',@UserID='-10',@VersionID='1008'
EXEC spIU_DC_Financials_Raw @Book='ACTS_Main',@Entity='52982C',@FiscalYear='2020',@InstanceID='413',@Scenario='ACTUAL',@SequenceBM='3',@UserID='-10',@VersionID='1008', @Debug = 1
EXEC spIU_DC_Financials_Raw @Book='CBN_Main',@Entity='52982',@FiscalYear='2019',@InstanceID='413',@Scenario='ACTUAL',@SequenceBM='2',@UserID='-10',@VersionID='1008'

EXEC spIU_DC_Financials_Raw @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @Entity='CDHO', @Book='MAIN',@FiscalYear=2020, @Scenario='ACTUAL', @SequenceBM=4, @FieldTypeBM=2, @Debug=1
EXEC [spIU_DC_Financials_Raw] @UserID = -10, @InstanceID = 478, @VersionID = 1032, @Entity='AD-001', @Book='MAIN', @FiscalYear=2020, @SequenceBM='2', @Debug = 1
EXEC [spIU_DC_Financials_Raw] @UserID = -10, @InstanceID = 481, @VersionID = 1031, @Entity='SNI01', @Book='Principal', @FiscalYear=2016, @SequenceBM='1', @Debug = 1

EXEC [spIU_DC_Financials_Raw] @UserID = -10, @InstanceID = 515, @VersionID = 1064, @Scenario='ACTUAL', @Entity='REM', @Book='GL', @FiscalYear=2019, @SequenceBM = 2, @Debug = 1 --REM
EXEC [spIU_DC_Financials_Raw] @UserID = -10, @InstanceID = 523, @VersionID = 1051, @Scenario='ACTUAL', @Entity='EIL', @Book='MAIN', @FiscalYear=2019, @SequenceBM = 1, @Debug = 1 --SUFS
EXEC [spIU_DC_Financials_Raw] @UserID = -10, @InstanceID = 523, @VersionID = 1051, @Scenario='ACTUAL', @Entity='EIL', @Book='Main', @FiscalYear=2019, @SequenceBM = 2, @DebugBM=19
EXEC [spIU_DC_Financials_Raw] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @Scenario='ACTUAL', @Entity='GGI03', @Book='MOROCCO', @FiscalYear=2020, @SequenceBM = 4, @DebugBM=19
EXEC [spIU_DC_Financials_Raw] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Scenario='ACTUAL', @Entity='05', @Book='GL', @FiscalYear=2020, @SequenceBM = 2, @ConsolidationGroupYN = 1, @DebugBM=19

EXEC [spIU_DC_Financials_Raw] @UserID = -10, @InstanceID = 531, @VersionID = 1057, @Scenario='ACTUAL', @Entity='PCXNW', @Book='MAIN', @FiscalYear=2021, @SequenceBM = 2, @ConsolidationGroupYN = 0, @DebugBM=19

EXEC [spIU_DC_Financials_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataClassID int,
	@DataClassName nvarchar(100),
	@StorageTypeBM int, --1 = Internal, 2 = Table, 4 = Callisto
	@SQLStatement nvarchar(MAX),
	@SQLInsertInto nvarchar(4000) = '',
	@SQLSelect nvarchar(4000) = '',
	@SQLGroupBy nvarchar(4000) = '',
	@SQLSegmentDistinct nvarchar(2000) = '',
	@SQLSegmentJoin nvarchar(2000) = '',
	@SQLDimJoin nvarchar(4000) = '',
	@SQLDimSegmentJoin nvarchar(4000) = '',
	@CallistoDatabase nvarchar(100),
	@CurrencyType nvarchar(50),
	@ApplicationID int,
	@EntityID int,
	@Entity_CallistoLabel nvarchar(100),
	@FlowTable nvarchar(100),
	@GL_Posted_ExistYN bit,

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
			@ProcedureDescription = 'Prepare data from Journal to be inserted into FACT table',
			@MandatoryParameter = 'Entity|Book|Scenario' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data]. Implemented [spGet_JournalTable].'
		IF @Version = '2.0.2.2146' SET @Description = 'Added parameter @Scenario, defaulted to ACTUAL. DB-92: Added parameter @TempTable_ObjectID to distinguish different temp tables in a multi tenant environment. DB-102 Handle extra books, added variable @Entity_CallistoLabel.'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-129: Scenarios <> ACTUAL not correct handled for @SequenceBM = 1'
		IF @Version = '2.0.3.2151' SET @Description = 'Handle Consolidation properties (Flow, Group & Intercompany).'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-341: Changed filter for P&L accounts.'
		IF @Version = '2.0.3.2153' SET @Description = 'Check TransactionTypeBM = 8 for Consolidation rows and Transaction currency. Calculate balances for missing periods'
		IF @Version = '2.0.3.2154' SET @Description = 'Handle FiscalPeriod 13 - 15.'
		IF @Version = '2.1.0.2161' SET @Description = 'Handle MappingTypeID IN (1, 2) for Account and Segments. Changed prefix in the SP name.'
		IF @Version = '2.1.0.2162' SET @Description = 'Return 0-values. Needed for deletions. Handle Flow, Customer and Supplier.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added Flow OP_Adjust. Handle not selected Segments.'
		IF @Version = '2.1.0.2164' SET @Description = 'Added NumberHierarchy for segments.'
		IF @Version = '2.1.1.2168' SET @Description = 'Improved debugging. Handle empty @SQLSegmentDistinct and @SQLSegmentJoin.'
		IF @Version = '2.1.1.2169' SET @Description = 'Exclude dimensions of type AutoMultiDim (27). Exclude FiscalPeriod = 0 for P&L-accounts. Updated handling of BusinessProcess FP13-FP15. Set @CurrencyType=Group when @FieldTypeBM & 4 > 0 (Consolidation).'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle FiscalPeriod 13-15 for Balance Accounts. Exclude Currency_Book = Currency_Group when FieldTypeBM & 4 > 0. Added parameter @ConsolidationGroup and test on PostedStatus.'
		IF @Version = '2.1.1.2174' SET @Description = 'Handle Dimension Source and handle TransactionTypeBM = 16.'
		IF @Version = '2.1.1.2176' SET @Description = 'Handle Dimension FiscalPeriod. DB-697 Create SP for loading new dimension FiscalPeriod (generic)'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-722: Modified functionality for FieldTypeBM=2 (Jrn_Currency_Transaction).'
		IF @Version = '2.1.1.2179' SET @Description = 'DB-754: Added correct alias name for ambiguous column [FiscalPeriod]. Removed restrictions of FiscalPeriod in #YM.'
		IF @Version = '2.1.1.2180' SET @Description = 'Hadle @SQLStatement > 4000 of an insert query (INSERT INTO #DC_Financials_Raw) in @Step = @SequenceBM = 2, Balance Sheet.'
		IF @Version = '2.1.2.2181' SET @Description = 'Fixed cosmetic debug issue.'
		IF @Version = '2.1.2.2187' SET @Description = 'Handle MappingTypeID IN (1, 2) for Supplier.'
		IF @Version = '2.1.2.2191' SET @Description = 'Added parameter @JobIDFilterYN, enhanced debugging for @DebugBM =16'

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
			@DataClassID = MAX(DC.[DataClassID]),
			@DataClassName = MAX(DC.[DataClassName]),
			@StorageTypeBM = MAX(DC.[StorageTypeBM])
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass] DC
		WHERE
			DC.[InstanceID] = @InstanceID AND
			DC.[VersionID] = @VersionID AND
			DC.[ModelBM] & 64 > 0 AND
			DC.[SelectYN] <> 0 AND
			DC.[DeletedID] IS NULL

		SELECT
			@ApplicationID = MAX(A.[ApplicationID])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SELECT
			@EntityID = E.EntityID,
			@Entity_CallistoLabel = CASE WHEN EB.[BookTypeBM] & 2 > 0 THEN E.MemberKey ELSE E.MemberKey + '_' + EB.Book END
		FROM
			Entity E
			INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.Book = @Book AND EB.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.MemberKey = @Entity AND
			E.SelectYN <> 0 AND
			E.DeletedID IS NULL

		SELECT
			@CallistoDatabase = A.[DestinationDatabase]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.[ApplicationID] = @ApplicationID

		SET @CurrencyType = CASE WHEN @FieldTypeBM & 1 > 0 THEN 'Book' ELSE CASE WHEN @FieldTypeBM & 4 > 0 THEN 'Group' ELSE 'Transaction' END END

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT

		SET @Scenario = ISNULL(@Scenario, 'ACTUAL')

		IF @DebugBM & 2 > 0
			SELECT
				[@DataClassID] = @DataClassID,
				[@DataClassName] = @DataClassName,
				[@StorageTypeBM] = @StorageTypeBM,
				[@ApplicationID] = @ApplicationID,
				[@CallistoDatabase] = @CallistoDatabase,
				[@CurrencyType] = @CurrencyType,
				[@EntityID] = @EntityID,
				[@JournalTable] = @JournalTable,
				[@Entity_CallistoLabel] = @Entity_CallistoLabel

	SET @Step = 'Create temp table #Columns'
		SELECT
			ColumnType = CONVERT(nvarchar(50), 'Dimension') COLLATE DATABASE_DEFAULT,
			ObjectID = DCD.DimensionID,
			ColumnName = CONVERT(nvarchar(100), D.DimensionName + '_MemberKey') COLLATE DATABASE_DEFAULT,
			DataType = CONVERT(nvarchar(50), 'nvarchar(100)'),
			DimensionTypeID = D.DimensionTypeID,
			MappingTypeID = DST.MappingTypeID,
			NumberHierarchy = DST.NumberHierarchy,
			SortOrder = DCD.SortOrder
		INTO
			#Columns
		FROM
			DataClass_Dimension DCD
			INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.DimensionTypeID <> 27 AND D.SelectYN <> 0 AND D.DeletedID IS NULL
			INNER JOIN pcINTEGRATOR_Data..Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = DCD.DimensionID
		WHERE
			DCD.DataClassID = @DataClassID AND
			DCD.DimensionID NOT IN (-77)
		ORDER BY
			DCD.SortOrder

		INSERT INTO #Columns
			(
			ColumnType,
			ObjectID,
			ColumnName,
			DataType,
			DimensionTypeID,
			MappingTypeID,
			NumberHierarchy,
			SortOrder
			)
		SELECT
			ColumnType = 'Measure',
			ObjectID = MeasureID,
			ColumnName = MeasureName + '_Value',
			DataType = 'float',
			DimensionTypeID = -4,
			MappingTypeID = 0,
			NumberHierarchy = 0,
			SortOrder = 10000 + SortOrder
		FROM
			Measure
		WHERE
			DataClassID = @DataClassID AND
			VersionID = @VersionID AND
			SelectYN <> 0 AND
			DeletedID IS NULL
		ORDER BY
			SortOrder

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Columns', * FROM #Columns ORDER BY SortOrder

	SET @Step = 'Set variable @GL_Posted_ExistYN'
		SELECT
			@GL_Posted_ExistYN = COUNT(1)
		FROM
			#Columns
		WHERE
			DimensionTypeID = 45

		IF @DebugBM & 2 > 0 SELECT [@GL_Posted_ExistYN] = @GL_Posted_ExistYN

	SET @Step = 'Create temp table #Journal_SegmentNo'
		SELECT
			*
		INTO
			#Journal_SegmentNo
		FROM
			pcINTEGRATOR_Data..Journal_SegmentNo
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[EntityID] = @EntityID AND
			[Book] = @Book AND
			[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Journal_SegmentNo', * FROM #Journal_SegmentNo ORDER BY DimensionID

	SET @Step = 'Create temp table #DC_Financials_Raw'
		CREATE TABLE #DC_Financials_Raw
			(DataClassID int)

		SET @SQLStatement = 'ALTER TABLE #DC_Financials_Raw' + CHAR(13) + CHAR(10) + 'ADD'

		SELECT
			@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + ColumnName + ' ' + DataType + CASE WHEN ColumnType = 'Dimension' THEN ' COLLATE DATABASE_DEFAULT' ELSE '' END + ','
		FROM
			#Columns
		ORDER BY
			SortOrder

		SET @SQLStatement = LEFT(@SQLStatement, LEN(@SQLStatement) -1)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Create temp table #Flow'
		IF @SequenceBM & 3 > 0
			BEGIN
				CREATE TABLE #Flow
					(
					MemberID bigint,
					MemberKey nvarchar(50)
					)

				IF @StorageTypeBM & 4 > 0
					SET @FlowTable = @CallistoDatabase + '..S_DS_Flow'

				IF OBJECT_ID (@FlowTable, N'U') IS NULL
					INSERT INTO #Flow
						(
						[MemberID],
						[MemberKey]
						)
					SELECT
						[MemberID] = -1,
						[MemberKey] = 'NONE'
				ELSE
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #Flow
								(
								[MemberID],
								[MemberKey]
								)
							SELECT
								[MemberID],
								[MemberKey] = [Label]
							FROM
								' + @FlowTable + '
							WHERE
								[MemberID] IN (111, 114, 121, 122)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Flow', * FROM #Flow
			END

	SET @Step = 'Create period related temp tables'
		CREATE TABLE #FiscalPeriod
			(
			[FiscalYear] int,
			[FiscalPeriod] int,
			[YearMonth] int
			)

		CREATE TABLE #YM
			(
			[FiscalYear] int,
			[FiscalPeriod] int,
			[YearMonth] int,
			[BalancePeriod] int,
			[ClosingPeriodYN] bit
			)

		CREATE TABLE #BalancePeriod
			(
			[FiscalYear] int,
			[YearMonth] int,
			[BalancePeriod] int
			)

	SET @Step = 'Fill period related temp tables'
		IF @InstanceID = 603 AND @VersionID = 1095 AND @Entity = 'Honematic' AND @Book = 'GL' AND @FiscalYear = 2020
			INSERT INTO #FiscalPeriod
				(
				[FiscalYear],
				[FiscalPeriod],
				[YearMonth]
				)
			--SELECT [FiscalYear] = 2020, [FiscalPeriod] = 0, [YearMonth] = 201912
			--UNION
			SELECT [FiscalYear] = 2020, [FiscalPeriod] = 1, [YearMonth] = 201912
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 2, [YearMonth] = 202001
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 3, [YearMonth] = 202002
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 4, [YearMonth] = 202003
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 5, [YearMonth] = 202004
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 6, [YearMonth] = 202005
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 7, [YearMonth] = 202006
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 8, [YearMonth] = 202007
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 9, [YearMonth] = 202008
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 10, [YearMonth] = 202009
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 11, [YearMonth] = 202010
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 12, [YearMonth] = 202011
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 13, [YearMonth] = 202011
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 14, [YearMonth] = 202011
			UNION SELECT [FiscalYear] = 2020, [FiscalPeriod] = 15, [YearMonth] = 202011

		ELSE IF @InstanceID = 603 AND @VersionID = 1095 AND @Entity = 'Honematic' AND @Book = 'GL' AND @FiscalYear = 2021
			INSERT INTO #FiscalPeriod
				(
				[FiscalYear],
				[FiscalPeriod],
				[YearMonth]
				)
			--SELECT [FiscalYear] = 2021, [FiscalPeriod] = 0, [YearMonth] = 202012
			--UNION
			SELECT [FiscalYear] = 2021, [FiscalPeriod] = 1, [YearMonth] = 202012
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 2, [YearMonth] = 202101
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 3, [YearMonth] = 202102
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 4, [YearMonth] = 202103
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 5, [YearMonth] = 202104
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 6, [YearMonth] = 202105
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 7, [YearMonth] = 202106
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 8, [YearMonth] = 202107
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 9, [YearMonth] = 202108
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 10, [YearMonth] = 202109
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 11, [YearMonth] = 202110
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 12, [YearMonth] = 202111
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 13, [YearMonth] = 202111
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 14, [YearMonth] = 202111
			UNION SELECT [FiscalYear] = 2021, [FiscalPeriod] = 15, [YearMonth] = 202111

		ELSE IF @InstanceID = 603 AND @VersionID = 1095 AND @Entity = 'Honematic' AND @Book = 'GL' AND @FiscalYear = 2022
			INSERT INTO #FiscalPeriod
				(
				[FiscalYear],
				[FiscalPeriod],
				[YearMonth]
				)
			--SELECT [FiscalYear] = 2022, [FiscalPeriod] = 0, [YearMonth] = 202112
			--UNION
			SELECT [FiscalYear] = 2022, [FiscalPeriod] = 1, [YearMonth] = 202112
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 2, [YearMonth] = 202201
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 3, [YearMonth] = 202202
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 4, [YearMonth] = 202203
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 5, [YearMonth] = 202204
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 6, [YearMonth] = 202205
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 7, [YearMonth] = 202206
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 8, [YearMonth] = 202207
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 9, [YearMonth] = 202208
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 10, [YearMonth] = 202209
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 11, [YearMonth] = 202210
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 12, [YearMonth] = 202211
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 13, [YearMonth] = 202212
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 14, [YearMonth] = 202212
			UNION SELECT [FiscalYear] = 2022, [FiscalPeriod] = 15, [YearMonth] = 202212
		ELSE
			EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @FiscalYear = @FiscalYear, @FiscalPeriod13YN=1, @JobID = @JobID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY FiscalYear, FiscalPeriod

		INSERT INTO #YM
			(
			[FiscalYear],
			[FiscalPeriod],
			[YearMonth],
			[BalancePeriod],
			[ClosingPeriodYN]
			)
		SELECT DISTINCT
			[FiscalYear],
			[FiscalPeriod],
			[YearMonth],
			[BalancePeriod] = [FiscalPeriod],
			[ClosingPeriodYN] = 0
		FROM
			#FiscalPeriod

		INSERT INTO #BalancePeriod
			(
			[FiscalYear],
			[YearMonth],
			[BalancePeriod]
			)
		SELECT
			[FiscalYear],
			[YearMonth],
			[BalancePeriod] = MIN([FiscalPeriod])
		FROM
			#YM
		GROUP BY
			[FiscalYear],
			[YearMonth]
		HAVING
			COUNT(1) > 1

		UPDATE YM
		SET
			[BalancePeriod] = BP.[BalancePeriod]
		FROM
			#YM YM
			INNER JOIN #BalancePeriod BP ON BP.[FiscalYear] = YM.[FiscalYear] AND BP.[YearMonth] = YM.[YearMonth]

		UPDATE YM
		SET
			[ClosingPeriodYN] = CASE WHEN YM.[FiscalPeriod] > (SELECT MAX([BalancePeriod]) FROM #YM) THEN 1 ELSE 0 END
		FROM
			#YM YM

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After initial tables and variables', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#YM', * FROM #YM ORDER BY FiscalYear, FiscalPeriod

	SET @Step = '@SequenceBM = 1, P&L Values'
		IF @SequenceBM & 1 > 0 AND @FieldTypeBM & 1 > 0 AND @ConsolidationGroupYN = 0
			BEGIN
				IF @DebugBM & 2 > 0 PRINT '@SequenceBM = 1, INSERT P&L'

				SELECT
					@SQLInsertInto = @SQLInsertInto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + sub.ColumnName + '],',
					@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + '[' + sub.ColumnName + '] = ' + sub.SourceColumn + ',',
					@SQLGroupBy = @SQLGroupBy + CASE WHEN sub.GroupBy IS NULL THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + sub.GroupBy + ',' END
				FROM
					(
					SELECT
						#C.ColumnName,
						SourceColumn = CASE #C.DimensionTypeID
								WHEN 1 THEN CASE WHEN #C.MappingTypeID = 1 THEN 'CASE WHEN J.[JournalSequence] <> ''CYNI'' THEN ''' + @Entity_CallistoLabel + '_'' ELSE '''' END + ' ELSE '' END + 'J.[Account]' + CASE WHEN #C.MappingTypeID = 2 THEN ' + CASE WHEN J.[JournalSequence] <> ''CYNI'' THEN ''_' + @Entity_CallistoLabel + ''' ELSE '''' END' ELSE '' END
--								WHEN 2 THEN '''Jrn_''' + ' + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END'
--								WHEN 2 THEN 'CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_''' + ' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END'
								WHEN 2 THEN 'CASE WHEN YM.[ClosingPeriodYN] <> 0 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_''' + ' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END'
								WHEN 39 THEN '''NONE'''
								WHEN 3 THEN 'J.[Currency_' + @CurrencyType + ']'
								WHEN 4 THEN '''' + @Entity_CallistoLabel + ''''
								WHEN 6 THEN '''' + @Scenario + ''''
								WHEN 7 THEN 'J.[YearMonth]'
								WHEN 8 THEN '''RAWDATA'''
								WHEN 14 THEN 'F.[MemberKey]'
								WHEN 18 THEN '''NONE'''
								WHEN 19 THEN '''NONE'''
								WHEN 25 THEN '''FP''' + ' + CASE WHEN J.[FiscalPeriod] <= 9 THEN ''0'' ELSE '''' END' + ' + CONVERT(nvarchar(10), J.FiscalPeriod)'
								WHEN 28 THEN 'J.[Customer]'
								--WHEN 29 THEN 'J.[Supplier]'
								WHEN 29 THEN CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + 'J.[Supplier]' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END
								WHEN 45 THEN 'CASE WHEN J.[PostedStatus] <> 0 THEN ''TRUE'' ELSE ''FALSE'' END'
								WHEN 48 THEN 'J.[Source]'
								WHEN 49 THEN 'CONVERT(nvarchar(15), J.[FiscalYear] * 100 + J.[FiscalPeriod])'
								WHEN -1 THEN CASE WHEN JSN.[SegmentNo] IS NULL THEN '''NONE''' ELSE CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + CASE WHEN #C.NumberHierarchy = 0 THEN 'J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']' ELSE '[dbo].[f_GetNumberHierarchy] (J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + '],' + CONVERT(nvarchar(15), #C.NumberHierarchy) + ')' END + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END END
--								WHEN -1 THEN CASE WHEN JSN.[SegmentNo] IS NULL THEN '''NONE''' ELSE CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + '[dbo].[f_GetNumberHierarchy] (J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + '],' + CONVERT(nvarchar(15), #C.NumberHierarchy) + ')' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END END
--								[dbo].[f_GetNumberHierarchy] ('J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']', #C.NumberHierarchy)
--								WHEN -1 THEN CASE WHEN JSN.[SegmentNo] IS NULL THEN '''NONE''' ELSE CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + 'J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END END
								WHEN -4 THEN 'ROUND(SUM(CASE F.[MemberID]
			WHEN 121 THEN J.[ValueDebit_' + @CurrencyType + ']
			WHEN 122 THEN J.[ValueCredit_' + @CurrencyType + '] * -1
			ELSE J.[ValueDebit_' + @CurrencyType + '] - J.[ValueCredit_' + @CurrencyType + ']
			END), 4)'
								ELSE '''NONE'''
							END,
						GroupBy = CASE #C.DimensionTypeID
								WHEN 1 THEN CASE WHEN #C.MappingTypeID IN (1, 2) THEN 'J.[JournalSequence], ' ELSE '' END + 'J.[Account]'
--								WHEN 2 THEN '''Jrn_''' + ' + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END'
--								WHEN 2 THEN 'CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_''' + ' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END'
								WHEN 2 THEN 'CASE WHEN YM.[ClosingPeriodYN] <> 0 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_''' + ' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END'
								WHEN 3 THEN 'J.[Currency_' + @CurrencyType + ']'
								WHEN 7 THEN 'J.[YearMonth]'
								WHEN 14 THEN 'F.[MemberKey]'
								WHEN 25 THEN '''FP''' + ' + CASE WHEN J.[FiscalPeriod] <= 9 THEN ''0'' ELSE '''' END' + ' + CONVERT(nvarchar(10), J.[FiscalPeriod])'
								WHEN 28 THEN 'J.[Customer]'
								--WHEN 29 THEN 'J.[Supplier]'
								WHEN 29 THEN CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + 'J.[Supplier]' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END
								WHEN 45 THEN 'CASE WHEN J.[PostedStatus] <> 0 THEN ''TRUE'' ELSE ''FALSE'' END'
								WHEN 48 THEN 'J.[Source]'
								WHEN 49 THEN 'CONVERT(nvarchar(15), J.[FiscalYear] * 100 + J.[FiscalPeriod])'
								WHEN -1 THEN 'J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']'
							END,
						#C.SortOrder
					FROM
						#Columns #C
						LEFT JOIN #Journal_SegmentNo JSN ON JSN.DimensionID = #C.ObjectID AND #C.ColumnType = 'Dimension'
					) sub
				ORDER BY
					sub.SortOrder

				SELECT
					@SQLInsertInto = LEFT(@SQLInsertInto, LEN(@SQLInsertInto) - 1),
					@SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) - 1),
					@SQLGroupBy = LEFT(@SQLGroupBy, LEN(@SQLGroupBy) - 1)

				IF @DebugBM & 2 > 0
					SELECT
						[@SQLInsertInto] = @SQLInsertInto,
						[@DataClassID] = @DataClassID,
						[@SQLSelect] = @SQLSelect,
						[@JobID] = @JobID,
						[@InstanceID] = @InstanceID,
						[@Entity] = @Entity,
						[@Book] = @Book,
						[@FiscalYear] = @FiscalYear,
						[@Scenario] = @Scenario,
						[@SQLGroupBy] = @SQLGroupBy,
						[@CurrencyType] = @CurrencyType

				SET @SQLStatement = '
INSERT INTO #DC_Financials_Raw
	(
	[DataClassID],' + @SQLInsertInto + '
	)
SELECT
	[DataClassID] = ' + CONVERT(nvarchar(10), @DataClassID) + ',' + @SQLSelect + '
FROM
	' + @JournalTable + ' J
	INNER JOIN #Flow F ON F.[MemberID] IN (-1, 121, 122)
	INNER JOIN #YM YM ON YM.[FiscalYear] = J.[FiscalYear] AND YM.[FiscalPeriod] = J.[FiscalPeriod]
WHERE
	J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
	J.[Entity] = ''' + @Entity + ''' AND
	J.[Book] = ''' + @Book + ''' AND
	' + CASE WHEN @FiscalYear IS NOT NULL THEN 'J.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND' ELSE '' END + '
	J.[Scenario] = ''' + @Scenario + ''' AND
	J.[TransactionTypeBM] & 19 > 0 AND
	ISNULL(J.[ConsolidationGroup], '''') = '''' AND
	J.[BalanceYN] = 0 AND
--	J.FiscalPeriod <> 0 AND
	' + CASE WHEN @JobIDFilterYN <> 0 THEN 'J.[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ' AND' ELSE '' END + '
	(' + CONVERT(NVARCHAR(15), CONVERT(INT, @GL_Posted_ExistYN)) + ' <> 0 OR J.[PostedStatus] <> 0)
GROUP BY' + @SQLGroupBy

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert P&L accounts into #DC_Financials_Raw', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
			END

	SET @Step = '@SequenceBM = 2, Balance Sheet'
		IF @SequenceBM & 2 > 0 AND @FieldTypeBM & 1 > 0 AND @ConsolidationGroupYN = 0
			BEGIN
				IF @DebugBM & 2 > 0 PRINT '@SequenceBM = 2, INSERT Balance'

				IF @DebugBM & 16 > 0 SELECT [Duration] = CONVERT(time(7), GetDate() - @StartTime)

				SELECT
					@SQLInsertInto = '',
					@SQLSelect = '',
					@SQLGroupBy = ''

				SELECT
					@SQLInsertInto = @SQLInsertInto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + sub.ColumnName + '],',
					@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + '[' + sub.ColumnName + '] = ' + sub.SourceColumn + ',',
					@SQLGroupBy = @SQLGroupBy + CASE WHEN sub.GroupBy IS NULL THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + sub.GroupBy + ',' END,
					@SQLSegmentDistinct = @SQLSegmentDistinct + CASE WHEN sub.SegmentDistinct IS NULL THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + sub.SegmentDistinct END,
					@SQLSegmentJoin = @SQLSegmentJoin + CASE WHEN sub.SegmentJoin IS NULL THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + sub.SegmentJoin + ' AND' END
				FROM
					(
					SELECT
						#C.ColumnName,
						SourceColumn = CASE #C.DimensionTypeID
								WHEN 1 THEN CASE WHEN #C.MappingTypeID = 1 THEN 'CASE WHEN Comb.[Account] NOT IN (''CYNI_B'', ''PYNI_B'') THEN ''' + @Entity_CallistoLabel + '_'' ELSE '''' END + ' ELSE '' END + 'Comb.[Account]' + CASE WHEN #C.MappingTypeID = 2 THEN ' + CASE WHEN Comb.[Account] NOT IN (''CYNI_B'', ''PYNI_B'') THEN ''_' + @Entity_CallistoLabel + ''' ELSE '''' END' ELSE '' END
								--WHEN 2 THEN 'CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_BAL'' END'
								WHEN 2 THEN 'CASE WHEN YM.[ClosingPeriodYN] <> 0 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_BAL'' END'
								WHEN 39 THEN '''NONE'''
								WHEN 3 THEN 'Comb.[Currency_' + @CurrencyType + ']'
								WHEN 4 THEN '''' + @Entity_CallistoLabel + ''''
								WHEN 6 THEN '''' + @Scenario + ''''
								WHEN 7 THEN 'YM.[YearMonth]'
								WHEN 8 THEN '''RAWDATA'''
								WHEN 14 THEN 'F.[MemberKey]'
								WHEN 18 THEN '''NONE'''
								WHEN 19 THEN '''NONE'''
								WHEN 25 THEN '''FP''' + ' + CASE WHEN YM.[FiscalPeriod] <= 9 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(10), YM.[FiscalPeriod])'
								WHEN 28 THEN 'J.[Customer]'
								--WHEN 29 THEN 'J.[Supplier]'
								WHEN 29 THEN CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + 'J.[Supplier]' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END
								WHEN 45 THEN 'CASE WHEN Comb.[PostedStatus] <> 0 THEN ''TRUE'' ELSE ''FALSE'' END'
								WHEN 48 THEN 'J.[Source]'
								WHEN 49 THEN 'CONVERT(nvarchar(15), YM.[FiscalYear] * 100 + YM.[FiscalPeriod])'

--								CASE WHEN #C.NumberHierarchy = 0 THEN 'J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']' ELSE '[dbo].[f_GetNumberHierarchy] (J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + '],' + CONVERT(nvarchar(15), #C.NumberHierarchy) + ')' END
								WHEN -1 THEN CASE WHEN JSN.[SegmentNo] IS NULL THEN '''NONE''' ELSE CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + CASE WHEN #C.NumberHierarchy = 0 THEN 'Comb.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']' ELSE '[dbo].[f_GetNumberHierarchy] (Comb.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + '],' + CONVERT(nvarchar(15), #C.NumberHierarchy) + ')' END + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END END
--								WHEN -1 THEN CASE WHEN JSN.[SegmentNo] IS NULL THEN '''NONE''' ELSE CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + '[dbo].[f_GetNumberHierarchy] (Comb.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + '],' + CONVERT(nvarchar(15), #C.NumberHierarchy) + ')' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END END
								WHEN -4 THEN 'ROUND(SUM(CASE F.MemberID
			WHEN 111 THEN CASE WHEN J.[FiscalYear] = YM.[FiscalYear] AND J.[FiscalPeriod] < YM.[BalancePeriod] AND YM.[FiscalPeriod] = YM.[BalancePeriod] AND (J.[JournalSequence] <> ''OB_ADJ'' OR YM.[BalancePeriod] > 1) THEN J.[ValueDebit_' + @CurrencyType + '] - J.[ValueCredit_' + @CurrencyType + '] ELSE 0 END
			WHEN 114 THEN CASE WHEN J.[FiscalYear] = YM.[FiscalYear] AND J.[FiscalPeriod] < YM.[BalancePeriod] AND YM.[FiscalPeriod] = YM.[BalancePeriod] AND J.[JournalSequence] = ''OB_ADJ'' AND YM.[BalancePeriod] = 1 THEN J.[ValueDebit_' + @CurrencyType + '] - J.[ValueCredit_' + @CurrencyType + '] ELSE 0 END
			WHEN 121 THEN CASE WHEN J.[FiscalYear] = YM.[FiscalYear] AND J.[FiscalPeriod] = YM.[FiscalPeriod] THEN J.[ValueDebit_' + @CurrencyType + '] ELSE 0 END
			WHEN 122 THEN CASE WHEN J.[FiscalYear] = YM.[FiscalYear] AND J.[FiscalPeriod] = YM.[FiscalPeriod] THEN J.[ValueCredit_' + @CurrencyType + '] * -1 ELSE 0 END
			ELSE CASE WHEN J.[FiscalYear] = YM.[FiscalYear] AND J.[FiscalPeriod] <= YM.[FiscalPeriod] THEN J.[ValueDebit_' + @CurrencyType + '] - J.[ValueCredit_' + @CurrencyType + '] ELSE 0 END
			END), 4)'
								ELSE '''NONE'''
							END,
						GroupBy = CASE #C.DimensionTypeID
								WHEN 1 THEN 'Comb.[Account]'
								--WHEN 2 THEN 'CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_BAL'' END'
								WHEN 2 THEN 'CASE WHEN YM.[ClosingPeriodYN] <> 0 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_BAL'' END'
								WHEN 3 THEN 'Comb.Currency_' + @CurrencyType
								WHEN 7 THEN 'YM.[YearMonth]'
								WHEN 14 THEN 'F.[MemberKey]'
								WHEN 25 THEN '''FP''' + ' + CASE WHEN YM.[FiscalPeriod] <= 9 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(10), YM.[FiscalPeriod])'
								WHEN 99 THEN '''FP''' + ' + CASE WHEN CASE WHEN J.[FiscalPeriod] = 0 THEN YM.[YearMonth] % 100 ELSE J.[FiscalPeriod] END BETWEEN 1 AND 9 THEN ''0'' ELSE '''' END' + ' + CONVERT(nvarchar(10), CASE WHEN J.[FiscalPeriod] = 0 THEN YM.YearMonth % 100 ELSE J.[FiscalPeriod] END)'
								WHEN 28 THEN 'J.[Customer]'
								--WHEN 29 THEN 'J.[Supplier]'
								WHEN 29 THEN CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + 'J.[Supplier]' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END
								WHEN 45 THEN 'CASE WHEN Comb.[PostedStatus] <> 0 THEN ''TRUE'' ELSE ''FALSE'' END'
								WHEN 48 THEN 'J.[Source]'
								WHEN 49 THEN 'CONVERT(nvarchar(15), YM.[FiscalYear] * 100 + YM.[FiscalPeriod])'
								WHEN -1 THEN 'Comb.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']'
							END,
						SegmentDistinct = CASE WHEN #C.DimensionTypeID = -1 THEN 'J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']' ELSE NULL END,
						SegmentJoin = CASE #C.DimensionTypeID WHEN 28 THEN 'J.[Customer] = Comb.[Customer]' WHEN 29 THEN 'J.[Supplier] = Comb.[Supplier]' WHEN -1 THEN 'J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + '] = Comb.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']' END,
						#C.SortOrder
					FROM
						#Columns #C
						LEFT JOIN #Journal_SegmentNo JSN ON JSN.DimensionID = #C.ObjectID AND #C.ColumnType = 'Dimension'
					) sub
				ORDER BY
					sub.SortOrder

				IF @DebugBM & 2 > 0
					SELECT
						[@SQLInsertInto] = @SQLInsertInto,
						[@SQLSelect] = @SQLSelect,
						[@SQLGroupBy] = @SQLGroupBy,
						[@SQLSegmentDistinct] = @SQLSegmentDistinct,
						[@SQLSegmentJoin] = @SQLSegmentJoin

				SELECT
					@SQLInsertInto = LEFT(@SQLInsertInto, LEN(@SQLInsertInto) - 1),
					@SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) - 1),
					@SQLGroupBy = LEFT(@SQLGroupBy, LEN(@SQLGroupBy) - 1),
					@SQLSegmentJoin = CASE WHEN LEN(@SQLSegmentJoin) < 1 THEN '' ELSE LEFT(@SQLSegmentJoin, LEN(@SQLSegmentJoin) - 4) END

				CREATE TABLE #Comb
					(
					FiscalYear int,
					PostedStatus bit,
					Account nvarchar(50) COLLATE DATABASE_DEFAULT,
					Currency_Book nchar(3) COLLATE DATABASE_DEFAULT,
					Currency_Transaction nchar(3) COLLATE DATABASE_DEFAULT,
					Segment01 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment02 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment03 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment04 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment05 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment06 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment07 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment08 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment09 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment10 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment11 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment12 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment13 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment14 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment15 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment16 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment17 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment18 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment19 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment20 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Customer nvarchar(50) COLLATE DATABASE_DEFAULT,
					Supplier nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Source] nvarchar(50) COLLATE DATABASE_DEFAULT
					)

				CREATE TABLE #Journal
					(
					FiscalYear int,
					FiscalPeriod int,
					[JournalSequence] nvarchar(50) COLLATE DATABASE_DEFAULT,
					YearMonth int,
					PostedStatus bit,
					Account nvarchar(50) COLLATE DATABASE_DEFAULT,
					Currency_Book nchar(3) COLLATE DATABASE_DEFAULT,
					Currency_Transaction nchar(3) COLLATE DATABASE_DEFAULT,
					ValueDebit_Book float,
					ValueCredit_Book float,
					ValueDebit_Transaction float,
					ValueCredit_Transaction float,
					Segment01 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment02 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment03 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment04 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment05 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment06 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment07 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment08 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment09 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment10 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment11 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment12 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment13 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment14 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment15 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment16 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment17 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment18 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment19 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Segment20 nvarchar(50) COLLATE DATABASE_DEFAULT,
					Customer nvarchar(50) COLLATE DATABASE_DEFAULT,
					Supplier nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Source] nvarchar(50) COLLATE DATABASE_DEFAULT
					)

				CREATE TABLE #FiscalYear (FiscalYear int)
				SET @SQLStatement = '
					INSERT INTO #FiscalYear
						(
						[FiscalYear]
						)
					SELECT DISTINCT
						[FiscalYear]
					FROM
						' + @JournalTable + ' J
					WHERE
						[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
						[Entity] = ''' + @Entity + ''' AND
						[Book] = ''' + @Book + ''' AND
						[TransactionTypeBM] & 19 > 0' + CASE WHEN @FiscalYear IS NOT NULL THEN ' AND
						' + CASE WHEN @JobIDFilterYN <> 0 THEN 'J.[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ' AND' ELSE '' END + '
						[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) ELSE '' END

				EXEC (@SQLStatement)
				IF @DebugBM & 2 > 0 PRINT @SQLStatement

				IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalYear', * FROM #FiscalYear

				IF CURSOR_STATUS('global','FiscalYear_Cursor') >= -1 DEALLOCATE FiscalYear_Cursor
				DECLARE FiscalYear_Cursor CURSOR FOR

					SELECT
						FiscalYear
					FROM
						#FiscalYear
					ORDER BY
						FiscalYear

					OPEN FiscalYear_Cursor
					FETCH NEXT FROM FiscalYear_Cursor INTO @FiscalYear

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@FiscalYear] = @FiscalYear

							IF @InstanceID = 603 AND @VersionID = 1095 AND @Entity = 'Honematic' AND @Book = 'GL' AND @FiscalYear <= 2022
								SELECT 'Honematic'
							ELSE
								BEGIN
									TRUNCATE TABLE #FiscalPeriod
									EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @FiscalYear = @FiscalYear, @FiscalPeriod13YN=1, @JobID = @JobID
								END

							IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY FiscalYear, FiscalPeriod

							TRUNCATE TABLE #YM
							TRUNCATE TABLE #BalancePeriod

							SET @SQLStatement = '
								INSERT INTO #YM
									(
									[FiscalYear],
									[FiscalPeriod],
									[YearMonth],
									[BalancePeriod],
									[ClosingPeriodYN]
									)
								SELECT DISTINCT
									[FiscalYear],
									[FiscalPeriod],
									[YearMonth],
									[BalancePeriod] = [FiscalPeriod],
									[ClosingPeriodYN] = 0
								FROM
									#FiscalPeriod
								WHERE
									[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear)

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert Balance accounts into #YM', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

							INSERT INTO #BalancePeriod
								(
								[FiscalYear],
								[YearMonth],
								[BalancePeriod]
								)
							SELECT
								[FiscalYear],
								[YearMonth],
								[BalancePeriod] = MIN([FiscalPeriod])
							FROM
								#YM
							GROUP BY
								[FiscalYear],
								[YearMonth]
							HAVING
								COUNT(1) > 1

							UPDATE YM
							SET
								[BalancePeriod] = BP.[BalancePeriod]
							FROM
								#YM YM
								INNER JOIN #BalancePeriod BP ON BP.[FiscalYear] = YM.[FiscalYear] AND BP.[YearMonth] = YM.[YearMonth]

							UPDATE YM
							SET
								[ClosingPeriodYN] = CASE WHEN YM.[FiscalPeriod] > (SELECT MAX([BalancePeriod]) FROM #YM) THEN 1 ELSE 0 END
							FROM
								#YM YM

							IF @DebugBM & 16 > 0 SELECT [Duration] = CONVERT(time(7), GetDate() - @StartTime)
							IF @DebugBM & 2 > 0 SELECT TempTable = '#YM', * FROM #YM ORDER BY FiscalYear, FiscalPeriod

							TRUNCATE TABLE #Comb

							SET @SQLStatement = '
		INSERT INTO #Comb
			(
			[FiscalYear],
			[PostedStatus],
			[Account],
			[Currency_' + @CurrencyType + '],
			[Customer],
			[Supplier],
			[Source]' + REPLACE(@SQLSegmentDistinct, 'J.', '') + '
			)
		SELECT DISTINCT
			J.[FiscalYear],
			J.[PostedStatus],
			J.[Account],
			J.[Currency_' + @CurrencyType + '],
			[Customer] = ISNULL(J.[Customer], ''''),
			[Supplier] = ISNULL(J.[Supplier], ''''),
			[Source] = ISNULL(J.[Source], '''')' + @SQLSegmentDistinct + '
		FROM
			' + @JournalTable + ' J
		WHERE
			J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
			J.[Entity] = ''' + @Entity + ''' AND
			J.[Book] = ''' + @Book + ''' AND
			J.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
			J.[TransactionTypeBM] & 19 > 0 AND
			J.[BalanceYN] <> 0 AND
			J.[Scenario] = ''' + @Scenario + ''' AND
			ISNULL(J.[ConsolidationGroup], '''') = '''' AND
			' + CASE WHEN @JobIDFilterYN <> 0 THEN 'J.[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ' AND' ELSE '' END + '
			(' + CONVERT(nvarchar(15), CONVERT(int, @GL_Posted_ExistYN)) + ' <> 0 OR J.[PostedStatus] <> 0)'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert Balance accounts into #Comb', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
							IF @DebugBM & 8 > 0 SELECT TempTable = '#Comb', * FROM #Comb ORDER BY Account, Segment01, Segment02

							TRUNCATE TABLE #Journal

							SET @SQLStatement = '
		INSERT INTO #Journal
			(
			[FiscalYear],
			[FiscalPeriod],
			[JournalSequence],
			[YearMonth],
			[PostedStatus],
			[Account],
			[Currency_' + @CurrencyType + '],
			[ValueDebit_' + @CurrencyType + '],
			[ValueCredit_' + @CurrencyType + '],
			[Customer],
			[Supplier],
			[Source]' + REPLACE(@SQLSegmentDistinct, 'J.', '') + '
			)
		SELECT
			J.[FiscalYear],
			J.[FiscalPeriod],
			J.[JournalSequence],
			J.[YearMonth],
			J.[PostedStatus],
			J.[Account],
			J.[Currency_' + @CurrencyType + '],
			J.[ValueDebit_' + @CurrencyType + '],
			J.[ValueCredit_' + @CurrencyType + '],
			[Customer] = ISNULL(J.[Customer], ''''),
			[Supplier] = ISNULL(J.[Supplier], ''''),
			[Source] = ISNULL(J.[Source], '''')' + @SQLSegmentDistinct + '
		FROM
			' + @JournalTable + ' J
		WHERE
			J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
			J.[Entity] = ''' + @Entity + ''' AND
			J.[Book] = ''' + @Book + ''' AND
			J.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
			J.[TransactionTypeBM] & 19 > 0 AND
			J.[BalanceYN] <> 0 AND
			J.[Scenario] = ''' + @Scenario + ''' AND
			ISNULL(J.[ConsolidationGroup], '''') = '''' AND
			' + CASE WHEN @JobIDFilterYN <> 0 THEN 'J.[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ' AND' ELSE '' END + '
			(' + CONVERT(nvarchar(15), CONVERT(int, @GL_Posted_ExistYN)) + ' <> 0 OR J.[PostedStatus] <> 0)'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert Balance accounts into #Journal', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
							IF @DebugBM & 8 > 0 SELECT TempTable = '#Journal', * FROM #Journal ORDER BY [YearMonth], [Account]

							IF @DebugBM & 2 > 0
								SELECT
									[@SQLInsertInto] = @SQLInsertInto,
									[@DataClassID] = @DataClassID,
									[@SQLSelect] = @SQLSelect,
									[@CurrencyType] = @CurrencyType,
									[@SQLSegmentJoin] = @SQLSegmentJoin,
									[@SQLGroupBy] = @SQLGroupBy

							SET @SQLStatement = '
INSERT INTO #DC_Financials_Raw
	(
	[DataClassID],' + @SQLInsertInto + '
	)
SELECT
	[DataClassID] = ' + CONVERT(nvarchar(10), @DataClassID) + ',' + @SQLSelect + '
FROM
	#Comb Comb
	INNER JOIN #Journal J ON
		J.[FiscalYear] = Comb.[FiscalYear] AND
		J.[PostedStatus] = Comb.[PostedStatus] AND
		J.[Account] = Comb.[Account] AND
		J.[Currency_' + @CurrencyType + '] = Comb.[Currency_' + @CurrencyType + '] AND
		J.[Customer] = Comb.[Customer] AND
		J.[Supplier] = Comb.[Supplier] AND '
		SET @SQLStatement = @SQLStatement + '
		J.[Source] = Comb.[Source] ' +
		CASE WHEN LEN(@SQLSegmentJoin) > 0 THEN ' AND ' + @SQLSegmentJoin ELSE '' END + '
	INNER JOIN #YM YM ON YM.[FiscalYear] = Comb.[FiscalYear] AND YM.[FiscalPeriod] <> 0
	INNER JOIN #Flow F ON F.[MemberID] IN (-1, 111, 114, 121, 122)
GROUP BY' + @SQLGroupBy

							IF @DebugBM & 2 > 0
								BEGIN
									IF LEN(@SQLStatement) > 4000
										BEGIN
											PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; INSERT INTO #DC_Financials_Raw (@Step = @SequenceBM = 2, Balance Sheet)'
											EXEC [dbo].[spSet_wrk_Debug]
												@UserID = @UserID,
												@InstanceID = @InstanceID,
												@VersionID = @VersionID,
												@DatabaseName = @DatabaseName,
												@CalledProcedureName = @ProcedureName,
												@Comment = 'INSERT INTO #DC_Financials_Raw (@Step = @SequenceBM = 2, Balance Sheet)',
												@SQLStatement = @SQLStatement
										END
									ELSE
										PRINT @SQLStatement
								END
							EXEC (@SQLStatement)


							IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert Balance accounts into #DC_Financials_Raw', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
							IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_Financials_Raw', * FROM #DC_Financials_Raw

							FETCH NEXT FROM FiscalYear_Cursor INTO @FiscalYear
						END

				CLOSE FiscalYear_Cursor
				DEALLOCATE FiscalYear_Cursor

				DROP TABLE #FiscalYear
				DROP TABLE #YM
				DROP TABLE #Comb
			END

	SET @Step = '@SequenceBM = 4, Not differentiated by TimeBalance'
		IF @SequenceBM & 4 > 0 OR @ConsolidationGroupYN <> 0 OR @FieldTypeBM & 6 > 0
			BEGIN
				IF @DebugBM & 2 > 0 PRINT '@SequenceBM = 4, Not differentiated by TimeBalance'

				IF @ConsolidationGroupYN = 0 AND @FieldTypeBM & 2 > 0
					SET @CurrencyType = 'Transaction'

				SELECT
					@SQLInsertInto = '',
					@SQLSelect = '',
					@SQLGroupBy = ''

				SELECT
					@SQLInsertInto = @SQLInsertInto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + sub.ColumnName + '],',
					@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + '[' + sub.ColumnName + '] = ' + sub.SourceColumn + ',',
					@SQLGroupBy = @SQLGroupBy + CASE WHEN sub.GroupBy IS NULL THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + sub.GroupBy + ',' END
				FROM
					(
					SELECT
						#C.ColumnName,
						SourceColumn = CASE #C.DimensionTypeID
								WHEN 1 THEN CASE WHEN #C.MappingTypeID = 1 THEN 'CASE WHEN J.[JournalSequence] <> ''CYNI'' THEN ''' + @Entity_CallistoLabel + '_'' ELSE '''' END + ' ELSE '' END + 'J.[Account]' + CASE WHEN #C.MappingTypeID = 2 THEN ' + CASE WHEN J.[JournalSequence] <> ''CYNI'' THEN ''_' + @Entity_CallistoLabel + ''' ELSE '''' END' ELSE '' END
--								WHEN 2 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Jrn_Currency_Transaction''' ELSE '''Jrn_''' + ' + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END' END
--								WHEN 2 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Jrn_Currency_Transaction''' ELSE 'CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_''' + ' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END' END
--								WHEN 2 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Jrn_Currency_Transaction''' ELSE '''Jrn_''' + ' + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE '''' END +  CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence' END
								WHEN 2 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Jrn_Currency_Transaction''' ELSE '''Jrn_'' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + J.[JournalSequence] + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''_FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE '''' END' END
--								WHEN 39 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Currency_Transaction''' ELSE '''NONE''' END
								WHEN 39 THEN CASE WHEN @FieldTypeBM & 4 > 0 THEN '''Conversion''' ELSE CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Currency_Transaction''' ELSE '''NONE''' END END
								WHEN 3 THEN 'J.[Currency_' + @CurrencyType + ']'
								WHEN 4 THEN '''' + @Entity_CallistoLabel + ''''
								WHEN 6 THEN '''' + @Scenario + ''''
								WHEN 7 THEN 'J.[YearMonth]'
								WHEN 8 THEN '''RAWDATA'''
								WHEN 14 THEN 'J.[Flow]'
								WHEN 10 THEN 'J.[ConsolidationGroup]'
								WHEN 11 THEN 'J.[InterCompanyEntity]'
								WHEN 25 THEN '''FP''' + ' + CASE WHEN J.[FiscalPeriod] <= 9 THEN ''0'' ELSE '''' END' + ' + CONVERT(nvarchar(10), J.[FiscalPeriod])'
								WHEN 28 THEN 'J.[Customer]'
								--WHEN 29 THEN 'J.[Supplier]'
								WHEN 29 THEN CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + 'J.[Supplier]' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END
								WHEN 45 THEN 'CASE WHEN J.[PostedStatus] <> 0 THEN ''TRUE'' ELSE ''FALSE'' END'
								WHEN 48 THEN 'J.[Source]'
								WHEN 49 THEN 'CONVERT(nvarchar(15), J.[FiscalYear] * 100 + J.[FiscalPeriod])'
--								CASE WHEN #C.NumberHierarchy = 0 THEN 'J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']' ELSE '[dbo].[f_GetNumberHierarchy] (J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + '],' + CONVERT(nvarchar(15), #C.NumberHierarchy) + ')' END
								WHEN -1 THEN CASE WHEN JSN.[SegmentNo] IS NULL THEN '''NONE''' ELSE CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + CASE WHEN #C.NumberHierarchy = 0 THEN 'J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']' ELSE '[dbo].[f_GetNumberHierarchy] (J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + '],' + CONVERT(nvarchar(15), #C.NumberHierarchy) + ')' END + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END END
--								WHEN -1 THEN CASE WHEN JSN.[SegmentNo] IS NULL THEN '''NONE''' ELSE CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + '[dbo].[f_GetNumberHierarchy] (J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + '],' + CONVERT(nvarchar(15), #C.NumberHierarchy) + ')' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END END
								WHEN -4 THEN 'ROUND(SUM(J.[ValueDebit_' + @CurrencyType + '] - J.[ValueCredit_' + @CurrencyType + ']), 4)'
								ELSE '''NONE'''
							END,
						GroupBy = CASE #C.DimensionTypeID
								WHEN 1 THEN CASE WHEN #C.MappingTypeID IN (1, 2) THEN 'J.[JournalSequence], ' ELSE '' END + 'J.[Account]'
		--						WHEN 2 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Jrn_Currency_Transaction''' ELSE '''Jrn_''' + ' + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END' END
		--						WHEN 2 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Jrn_Currency_Transaction''' ELSE 'CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE ''Jrn_''' + ' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence END' END
		--						WHEN 2 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Jrn_Currency_Transaction''' ELSE '''Jrn_''' + ' + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE '''' END +  CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + JournalSequence' END
								--WHEN 2 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN '''Jrn_Currency_Transaction''' ELSE '''Jrn_'' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + J.[JournalSequence] + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''_FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE '''' END' END
								WHEN 2 THEN CASE WHEN @FieldTypeBM & 2 > 0 THEN NULL ELSE '''Jrn_'' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + J.[JournalSequence] + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''_FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE '''' END' END
								WHEN 3 THEN 'J.[Currency_' + @CurrencyType + ']'
								WHEN 7 THEN 'J.[YearMonth]'
								WHEN 14 THEN 'J.[Flow]'
								WHEN 10 THEN 'J.[ConsolidationGroup]'
								WHEN 11 THEN 'J.[InterCompanyEntity]'
								WHEN 25 THEN '''FP''' + ' + CASE WHEN J.[FiscalPeriod] <= 9 THEN ''0'' ELSE '''' END' + ' + CONVERT(nvarchar(10), J.[FiscalPeriod])'
								WHEN 28 THEN 'J.[Customer]'
								--WHEN 29 THEN 'J.[Supplier]'
								WHEN 29 THEN CASE WHEN #C.MappingTypeID = 1 THEN '''' + @Entity_CallistoLabel + '''' + ' + ' + '''_''' + ' + ' ELSE '' END + 'J.[Supplier]' + CASE WHEN #C.MappingTypeID = 2 THEN ' + ' + '''_''' + ' + ' + '''' + @Entity_CallistoLabel + '''' ELSE '' END
								WHEN 45 THEN 'CASE WHEN J.[PostedStatus] <> 0 THEN ''TRUE'' ELSE ''FALSE'' END'
								WHEN 48 THEN 'J.[Source]'
								WHEN 49 THEN 'CONVERT(nvarchar(15), J.[FiscalYear] * 100 + J.[FiscalPeriod])'
								WHEN -1 THEN 'J.[Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) + ']'
							END,
						#C.SortOrder
					FROM
						#Columns #C
						LEFT JOIN #Journal_SegmentNo JSN ON JSN.DimensionID = #C.ObjectID AND #C.ColumnType = 'Dimension'
					) sub
				ORDER BY
					sub.SortOrder

				SELECT
					@SQLInsertInto = LEFT(@SQLInsertInto, LEN(@SQLInsertInto) - 1),
					@SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) - 1),
					@SQLGroupBy = LEFT(@SQLGroupBy, LEN(@SQLGroupBy) - 1)

				IF @DebugBM & 2 > 0 SELECT [@SQLInsertInto] = @SQLInsertInto, [@SQLSelect] = @SQLSelect, [@SQLGroupBy] = @SQLGroupBy, [@DataClassID] = @DataClassID, [@FiscalYear] = @FiscalYear

				SET @SQLStatement = '
INSERT INTO #DC_Financials_Raw
	(
	[DataClassID],' + @SQLInsertInto + '
	)
SELECT
	[DataClassID] = ' + CONVERT(nvarchar(10), @DataClassID) + ',' + @SQLSelect + '
FROM
	' + @JournalTable + ' J
WHERE
	J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
	J.[Entity] = ''' + @Entity + ''' AND
	J.[Book] = ''' + @Book + ''' AND
	' + CASE WHEN @FiscalYear IS NULL THEN '' ELSE 'J.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND' END + '
	' + CASE WHEN @FieldTypeBM & 2 > 0 THEN 'ISNULL(J.[Currency_Book], '''') <> J.[Currency_Transaction] AND' ELSE '' END + '
	' + CASE WHEN @FieldTypeBM & 4 > 0 THEN 'ISNULL(J.[Currency_Book], '''') <> J.[Currency_Group] AND' ELSE '' END + '
	J.[Scenario] = ''' + @Scenario + ''' AND
	((J.[TransactionTypeBM] & 19 > 0 AND ' + CONVERT(nvarchar(15), CONVERT(int, @ConsolidationGroupYN)) + ' = 0) OR (J.[TransactionTypeBM] & 8 > 0 AND ' + CONVERT(nvarchar(15), CONVERT(int, @ConsolidationGroupYN)) + ' <> 0)) AND
	' + CASE WHEN @FieldTypeBM & 4 > 0 THEN '(' + CONVERT(nvarchar(15), @SequenceBM) + ' & 4 > 0 OR (' + CONVERT(nvarchar(15), CONVERT(int, @ConsolidationGroupYN)) + ' <> 0 AND LEN(J.[ConsolidationGroup]) > 0)) AND' ELSE '' END + '
	' + CASE WHEN @JobIDFilterYN <> 0 THEN 'J.[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ' AND' ELSE '' END + '
	(' + CONVERT(nvarchar(15), CONVERT(int, @GL_Posted_ExistYN)) + ' <> 0 OR J.[PostedStatus] <> 0)
	' + CASE WHEN @ConsolidationGroup IS NULL THEN '' ELSE ' AND J.[ConsolidationGroup] = ''' + @ConsolidationGroup + '''' END + '
GROUP BY' + @SQLGroupBy

				IF @DebugBM & 2 > 0
					BEGIN
						SELECT InsertIntoTempTable = '#DC_Financials_Raw', [@SQLStatement] = @SQLStatement
						PRINT @SQLStatement
					END
				EXEC (@SQLStatement)
				IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert @SequenceBM = 4 into #DC_Financials_Raw', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
				IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_Financials_Raw', * FROM #DC_Financials_Raw ORDER BY Time_MemberKey, Account_MemberKey
			END

	SET @Step = 'CBN Specific mapping'
		IF @InstanceID = 413 AND @VersionID = 1008
			BEGIN
				UPDATE JDFR
				SET
					[Account_MemberKey] = ISNULL(JMA.[To_MemberKey], JDFR.[Account_MemberKey]),
					[GL_Department_MemberKey] = ISNULL(JMD.[To_MemberKey], JDFR.[GL_Department_MemberKey])
				FROM
					[#DC_Financials_Raw] JDFR
					LEFT JOIN [pcETL_CBN].[dbo].[JournalMapping] JMA ON JMA.[Dimension] = 'Account' AND JMA.[Entity_MemberKey] = JDFR.[Entity_MemberKey] AND JMA.[From_MemberKey] = JDFR.[Account_MemberKey]
					LEFT JOIN [pcETL_CBN].[dbo].[JournalMapping] JMD ON JMD.[Dimension] = 'GL_Department' AND JMD.[Entity_MemberKey] = JDFR.[Entity_MemberKey] AND JMD.[From_MemberKey] = JDFR.[GL_Department_MemberKey]
			END

	SET @Step = 'Return rows'
		IF OBJECT_ID (N'tempdb..#DC_Financials', N'U') IS NULL
			BEGIN
				SELECT TempTable = '#DC_Financials_Raw', *
				FROM [#DC_Financials_Raw]
				WHERE Financials_Value <> 0
				ORDER BY DataClassID, Account_MemberKey, BusinessProcess_MemberKey, Time_MemberKey
				--SELECT TempTable = '#DC_Financials_Raw', * FROM [#DC_Financials_Raw]
				--WHERE Account_MemberKey='128150' AND GL_CostCenter_MemberKey = '3450' AND
				--	GL_Project_MemberKey = '19G13100' AND
				--	GL_CounterPart_MemberKey = '1110' AND
				--	GL_Site_MemberKey = '36102' AND
				--	Financials_Value <> 0
				--ORDER BY DataClassID, Account_MemberKey, Time_MemberKey, BusinessProcess_MemberKey DESC, Flow_MemberKey
			END
		ELSE
			BEGIN
				IF @DebugBM & 2 > 0 PRINT 'INSERT INTO #DC_Financials'

				SELECT
					@SQLInsertInto = '',
					@SQLSelect = '',
					@SQLDimJoin = '',
					@SQLDimSegmentJoin = ''

				IF @DebugBM & 2 > 0
					SELECT
						TempTable= 'sys.tables' , c.[name], t.create_date, [@MasterStartTime] = @MasterStartTime
					FROM
						tempDB.sys.tables t
						INNER JOIN tempDB.sys.columns c ON c.object_id = t.object_id
					WHERE
						t.[object_id] = @TempTable_ObjectID
					ORDER BY
						c.column_id

				SELECT
					@SQLInsertInto = @SQLInsertInto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + c.name + '],',
					@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + '[' + c.name + '] = ' + CASE WHEN c.name LIKE '%_MemberId' THEN 'ISNULL([' + REPLACE(c.name, '_MemberId', '') + '].[MemberId], -1),' ELSE '[Raw].[' + c.name + '],' END
					--,@SQLDimJoin = @SQLDimJoin + CHAR(13) + CHAR(10) + CHAR(9) + CASE WHEN c.name LIKE '%_MemberId' THEN 'LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + REPLACE(c.name, '_MemberId', '') + '] [' + REPLACE(c.name, '_MemberId', '') + '] ON [' + REPLACE(c.name, '_MemberId', '') + '].Label COLLATE DATABASE_DEFAULT = [Raw].[' + REPLACE(c.name, '_MemberId', '') + '_MemberKey]' ELSE '' END
				FROM
					tempDB.sys.tables t
					INNER JOIN tempdb.sys.columns c ON c.object_id = t.object_id
				WHERE
					t.[object_id] = @TempTable_ObjectID
				ORDER BY
					c.column_id

				--Non-Segment Dimensions (NOT LIKE 'GL_%_MemberId')
				SELECT
					@SQLDimJoin = @SQLDimJoin + CHAR(13) + CHAR(10) + CHAR(9) + CASE WHEN c.name LIKE '%_MemberId' THEN 'LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + REPLACE(c.name, '_MemberId', '') + '] [' + REPLACE(c.name, '_MemberId', '') + '] ON [' + REPLACE(c.name, '_MemberId', '') + '].Label COLLATE DATABASE_DEFAULT = [Raw].[' + REPLACE(c.name, '_MemberId', '') + '_MemberKey]' ELSE '' END
				FROM
					tempDB.sys.tables t
					INNER JOIN tempdb.sys.columns c ON c.object_id = t.object_id AND c.[name] NOT LIKE 'GL_%_MemberId'
				WHERE
					t.[object_id] = @TempTable_ObjectID
				ORDER BY
					c.column_id

				--Segment Dimensions (LIKE 'GL_%_MemberId')
				SELECT
					@SQLDimSegmentJoin = @SQLDimSegmentJoin + CHAR(13) + CHAR(10) + CHAR(9) + CASE WHEN c.name LIKE '%_MemberId' THEN 'LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + REPLACE(c.name, '_MemberId', '') + '] [' + REPLACE(c.name, '_MemberId', '') + '] ON [' + REPLACE(c.name, '_MemberId', '') + '].Label COLLATE DATABASE_DEFAULT = [Raw].[' + REPLACE(c.name, '_MemberId', '') + '_MemberKey]' ELSE '' END
				FROM
					tempDB.sys.tables t
					INNER JOIN tempdb.sys.columns c ON c.object_id = t.object_id AND c.[name] LIKE 'GL_%_MemberId'
				WHERE
					t.[object_id] = @TempTable_ObjectID
				ORDER BY
					c.column_id

				IF @DebugBM & 2 > 0
					BEGIN
						SELECT [@SQLInsertInto] = @SQLInsertInto
						SELECT [@SQLSelect] = @SQLSelect
						SELECT [@SQLDimJoin] = @SQLDimJoin
						SELECT [@SQLDimSegmentJoin] = @SQLDimSegmentJoin

						PRINT 'SQLInsertInto: ' + @SQLInsertInto
						PRINT 'SQLSelect: ' + @SQLSelect
						PRINT 'SQLDimJoin: ' + @SQLDimJoin
						PRINT 'SQLDimSegmentJoin: ' + @SQLDimSegmentJoin
					END

				SELECT
					@SQLInsertInto = LEFT(@SQLInsertInto, LEN(@SQLInsertInto) - 1),
					@SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) - 1)

				SET @SQLStatement = '
					INSERT INTO [#DC_Financials]
						(' + @SQLInsertInto + '
						)
					SELECT' + @SQLSelect + '
					FROM
						[#DC_Financials_Raw] [Raw]'

				SET @SQLStatement =	@SQLStatement + @SQLDimJoin + @SQLDimSegmentJoin

				IF @DebugBM & 2 > 0
					BEGIN
						IF LEN(@SQLStatement) > 4000
							BEGIN
								PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; INSERT INTO #DC_Financials (@Step = Return rows)'
								EXEC [dbo].[spSet_wrk_Debug]
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@DatabaseName = @DatabaseName,
									@CalledProcedureName = @ProcedureName,
									@Comment = 'INSERT INTO #DC_Financials (@Step = Return rows)',
									@SQLStatement = @SQLStatement
							END
						ELSE
							PRINT @SQLStatement
					END
				EXEC (@SQLStatement)

				SET @Selected = @@ROWCOUNT
				IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert into #DC_Financials', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE [#Columns]
		DROP TABLE [#Journal_SegmentNo]
		DROP TABLE [#DC_Financials_Raw]
		IF @SequenceBM & 3 > 0 DROP TABLE #Flow

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
