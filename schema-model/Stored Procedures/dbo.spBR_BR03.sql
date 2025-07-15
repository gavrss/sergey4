SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR03]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@FromTime int = NULL,
	@ToTime int = NULL,
	@Rule_AllocationID int = NULL, --Optional parameter
	@SequenceBM int = 7, --1=Calculate #JournalBase, 2=Into Journal, 4=Into FACT_Financials

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000770,
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
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202001, @ToTime=202012, @SequenceBM = 7, @DebugBM=24
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202101, @ToTime=202112, @SequenceBM = 7, @DebugBM=24
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202201, @ToTime=202212, @SequenceBM = 7, @DebugBM=24

EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202001, @ToTime=202001, @Rule_AllocationID = 2001, @SequenceBM = 1, @DebugBM=27
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202006, @ToTime=202006, @Rule_AllocationID = 2002, @SequenceBM = 1, @DebugBM=27
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202006, @ToTime=202007, @Rule_AllocationID = 2003, @SequenceBM = 1, @DebugBM=27

EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202001, @ToTime=202001, @SequenceBM = 1, @DebugBM=24
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202001, @ToTime=202001, @SequenceBM = 1, @DebugBM=27

EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202301, @ToTime=202308, @Rule_AllocationID = 2135, @SequenceBM = 1, @DebugBM=27
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202301, @ToTime=202308, @Rule_AllocationID = 2136, @SequenceBM = 1, @DebugBM=27
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202301, @ToTime=202308, @Rule_AllocationID = 2137, @SequenceBM = 1, @DebugBM=27

EXEC [spBR_BR03] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@SQLInsert nvarchar(1000),
	@SQLSelect nvarchar(1000),
	@SQLJoin nvarchar(1000),
	@SQLGroupBy nvarchar(1000),
	@SQLWhere nvarchar(1000),
	@Source_DimensionFilter_LeafLevel nvarchar(max) = '',
	@PropertyFilter nvarchar(max) = '',
	@Rule_Allocation_RowID int,
	@MultiDimSetting nvarchar(4000),
	@Rule_AllocationName nvarchar(50),
	@JournalSequence nvarchar(50),
	@Source_DataClassID int,
	@Source_DataClassName nvarchar(50),
	@Source_DimensionFilter nvarchar(4000),
	@Across_DataClassID int,
	@Across_DataClassName nvarchar(50),
	@Across_Member nvarchar(4000),
	@Across_WithinDim nvarchar(4000),
	@Across_Basis nvarchar(4000),
	@Across_Member_Default nvarchar(1000),
	@JournalOnlyYN bit,
	@ModifierID int,
	@Parameter float,
	@DimensionName nvarchar(100),
	@JournalTable nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@Comment nvarchar(255),
	@JournalNo int,
	@AGB nvarchar(1000) = '',
	@BeginTime int, 
    @EndTime int,
	@Source_DataClassTypeID int,
	@StorageTypeBM_DataClass int,
	@StepReference nvarchar(20),

--	@PropertyFilter nvarchar(max),

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
	@ModifiedBy nvarchar(50) = 'AlGa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Running business rule BR03, Allocation rules.',
			@MandatoryParameter = 'AllocationGroup' --Without @, separated by |

		IF @Version = '2.1.1.2171' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added optional parameter @Rule_AllocationID'
		IF @Version = '2.1.1.2173' SET @Description = 'Updated version of temp table #FilterTable.'
		IF @Version = '2.1.2.2191' SET @Description = 'Made generic.'
		IF @Version = '2.1.2.2199' SET @Description = 'Truncate #FilterTable at the begining of cursor.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
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

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		IF @DebugBM & 2 > 0
			SELECT
				[@JournalTable] = @JournalTable,
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@UserName] = @UserName

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			EXEC [spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=1,
				@CheckCount = 0,
				@JobID=@JobID OUT

	SET @Step = 'CREATE TABLE #JournalAlloc'
		IF OBJECT_ID(N'TempDB.dbo.#JournalAlloc', N'U') IS NULL
			BEGIN
				CREATE TABLE #JournalAlloc
					(
					[BaseRow] nvarchar(10),
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT, 
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] int,
					[FiscalPeriod] int,
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
					[Customer] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Supplier] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Currency_Book] [nchar](3) COLLATE DATABASE_DEFAULT,
					[Value_Book] [float]
					)
			END

	SET @Step = 'CREATE TABLE #JournalBase'
		IF OBJECT_ID(N'TempDB.dbo.#JournalBase', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0
				CREATE TABLE [dbo].[#JournalBase]
					(
					[Entity] [nvarchar](50) NOT NULL,
					[Book] [nvarchar](50) NOT NULL,
					[FiscalYear] [int] NOT NULL,
					[FiscalPeriod] [int] NOT NULL,
					[JournalSequence] [nvarchar](50) NOT NULL,
					[JournalNo] [nvarchar](50) NOT NULL,
					[JournalLine] int IDENTITY(1,1),
					[YearMonth] [int] NULL,
					[TransactionTypeBM] int,
					[BalanceYN] [bit] NOT NULL,
					[Account] [nvarchar](50) NULL,
					[Segment01] [nvarchar](50) NULL,
					[Segment02] [nvarchar](50) NULL,
					[Segment03] [nvarchar](50) NULL,
					[Segment04] [nvarchar](50) NULL,
					[Segment05] [nvarchar](50) NULL,
					[Segment06] [nvarchar](50) NULL,
					[Segment07] [nvarchar](50) NULL,
					[Segment08] [nvarchar](50) NULL,
					[Segment09] [nvarchar](50) NULL,
					[Segment10] [nvarchar](50) NULL,
					[Segment11] [nvarchar](50) NULL,
					[Segment12] [nvarchar](50) NULL,
					[Segment13] [nvarchar](50) NULL,
					[Segment14] [nvarchar](50) NULL,
					[Segment15] [nvarchar](50) NULL,
					[Segment16] [nvarchar](50) NULL,
					[Segment17] [nvarchar](50) NULL,
					[Segment18] [nvarchar](50) NULL,
					[Segment19] [nvarchar](50) NULL,
					[Segment20] [nvarchar](50) NULL,
					[JournalDate] [date] NULL,
					[TransactionDate] [date] NULL,
					[PostedDate] [date] NULL,
					[PostedStatus] [bit] NULL,
					[PostedBy] [nvarchar](100) NULL,
					[Source] [nvarchar](50) NULL,
					[Flow] [nvarchar](50) NULL,
					[ConsolidationGroup] [nvarchar](50) NULL,
					[InterCompanyEntity] [nvarchar](50) NULL,
					[Scenario] [nvarchar](50) NULL,
					[Customer] [nvarchar](50) NULL,
					[Supplier] [nvarchar](50) NULL,
					[Description_Head] [nvarchar](255) NULL,
					[Description_Line] [nvarchar](255) NULL,
					[Currency_Book] [nchar](3) NULL,
					[Value_Book] [float] NULL,
					[SourceModule] [nvarchar](20) NULL,
					[SourceModuleReference] [nvarchar](100) NULL,
					[SourceCounter] [bigint] NULL,
					[SourceGUID] [uniqueidentifier] NULL
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
					[DimensionTypeID] int,
					[StorageTypeBM] int,
					[SortOrder] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
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

	SET @Step = 'CREATE TABLE #AcrossGroupBy'
		CREATE TABLE #AcrossGroupBy
			(
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[MappingTypeID] int,
			[JournalColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[WithInYN] bit
			)

	SET @Step = 'CREATE TABLE #AcrossFilter'
		CREATE TABLE #AcrossFilter
			(
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[PropertyFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'CREATE TABLE #RULE_Allocation_Cursor_Table'
		CREATE TABLE #RULE_Allocation_Cursor_Table
			(
			[JournalNo] int IDENTITY(1,1),
			[Rule_AllocationID] int,
			[Rule_AllocationName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[JournalSequence] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Source_DataClassID] int,
			[Source_DimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[Across_DataClassID] int,
			[Across_Member] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[Across_WithinDim] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[Across_Basis] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[Across_Member_Default] nvarchar(1000),
			[JournalOnlyYN] bit,
			[ModifierID] int,
			[Parameter] float,
			[StartTime] int,
            [EndTime] int,
			[SortOrder] int
			)

		INSERT INTO #RULE_Allocation_Cursor_Table
			(
			[Rule_AllocationID],
			[Rule_AllocationName],
			[JournalSequence],
			[Source_DataClassID],
			[Source_DimensionFilter],
			[Across_DataClassID],
			[Across_Member],
			[Across_WithinDim],
			[Across_Basis],
			[Across_Member_Default],
			[JournalOnlyYN],
			[ModifierID],
			[Parameter],
			[StartTime],
            [EndTime],
			[SortOrder]
			)
		SELECT DISTINCT
			[Rule_AllocationID],
			[Rule_AllocationName],
			[JournalSequence],
			[Source_DataClassID],
			[Source_DimensionFilter],
			[Across_DataClassID],
			[Across_Member],
			[Across_WithinDim],
			[Across_Basis],
			[Across_Member_Default],
			[JournalOnlyYN],
			[ModifierID],
			[Parameter],
			[StartTime],
            [EndTime],
			[SortOrder]
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR03_Rule_Allocation] RC
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID AND
			[SelectYN] <> 0 AND
			([Rule_AllocationID] = @Rule_AllocationID OR @Rule_AllocationID IS NULL)
		ORDER BY
			[SortOrder]

		IF @DebugBM & 2 > 0 SELECT TempTable = '#RULE_Allocation_Cursor_Table', * FROM #RULE_Allocation_Cursor_Table ORDER BY [SortOrder]

	SET @Step = 'Create and fill temp table #Allocation_Row'
		CREATE TABLE #Allocation_Row
			(
			[Rule_AllocationID] [int],
			[Rule_Allocation_RowID] [int],
			[MultiDimSetting] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[CrossEntityYN] bit,
			[BaseRow] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[Factor] float,
			[Sign] [decimal](19,4),
			[SortOrder] int
			)

		INSERT INTO #Allocation_Row
			(
			[Rule_AllocationID],
			[Rule_Allocation_RowID],
			[MultiDimSetting],
			[CrossEntityYN],
			[BaseRow],
			[Factor],
			[Sign],
			[SortOrder]
			)
		SELECT
			[Rule_AllocationID],
			[Rule_Allocation_RowID],
			[MultiDimSetting],
			[CrossEntityYN],
			[BaseRow],
			[Factor],
			[Sign],
			[SortOrder]
		FROM
			pcINTEGRATOR_Data..BR03_Rule_Allocation_Row RAR
		WHERE
			RAR.[InstanceID] = @InstanceID AND
			RAR.[VersionID] = @VersionID AND
			RAR.[BusinessRuleID] = @BusinessRuleID AND
			RAR.[SelectYN] <> 0 AND
			(RAR.[Rule_AllocationID] = @Rule_AllocationID OR @Rule_AllocationID IS NULL)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Allocation_Row', * FROM #Allocation_Row ORDER BY [Rule_AllocationID], [SortOrder], [Rule_Allocation_RowID]
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After initial tables and variables', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Create and fill temp table #Allocation_Row_Dim_Setting'
		CREATE TABLE #Allocation_Row_Dim_Setting
			(
			[Rule_AllocationID] [int],
			[Rule_Allocation_RowID] [int],
			[DimensionValue] nvarchar(1000) COLLATE DATABASE_DEFAULT,
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
			[Customer] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Supplier] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[JournalColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Value] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #DimensionValue
			(
			[DimensionValue] nvarchar(1000) COLLATE DATABASE_DEFAULT
			)

		IF CURSOR_STATUS('global','MultiDimSetting_Cursor') >= -1 DEALLOCATE MultiDimSetting_Cursor
		DECLARE MultiDimSetting_Cursor CURSOR FOR
			
			SELECT
				[Rule_AllocationID],
				[Rule_Allocation_RowID],
				[MultiDimSetting]
			FROM
				#Allocation_Row
			WHERE
				LEN(MultiDimSetting) > 0

			OPEN MultiDimSetting_Cursor
			FETCH NEXT FROM MultiDimSetting_Cursor INTO @Rule_AllocationID, @Rule_Allocation_RowID, @MultiDimSetting

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @StepReference = 'BR03_00_' + CONVERT(nvarchar(15), @Rule_Allocation_RowID)
					IF @DebugBM & 2 > 0 SELECT [@Rule_AllocationID]=@Rule_AllocationID, [@Rule_Allocation_RowID]=@Rule_Allocation_RowID, [@MultiDimSetting]=@MultiDimSetting, [@StepReference] = @StepReference
					
					TRUNCATE TABLE #FilterTable

					EXEC pcINTEGRATOR..spGet_FilterTable
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@StepReference = @StepReference,
						@PipeString = @MultiDimSetting,
						@StorageTypeBM_DataClass = 1, --@StorageTypeBM_DataClass,
						@StorageTypeBM = 4, --@StorageTypeBM,
						@Debug = @DebugSub

					IF @DebugBM & 2 > 0
						SELECT
							TempTable = '#FilterTable',
							*
						FROM
							#FilterTable
						WHERE
							[StepReference] = @StepReference AND
							[LeafLevelFilter] IS NOT NULL
					
					TRUNCATE TABLE #DimensionValue

					INSERT INTO #DimensionValue
						(
						[DimensionValue]
						)
					SELECT
						[DimensionValue] = [DimensionName] + '=' + REPLACE([LeafLevelFilter], '''', '')
					FROM
						#FilterTable
					WHERE
						StepReference = @StepReference
/*
					INSERT INTO #DimensionValue
						(
						[DimensionValue]
						)
					SELECT
						[DimensionValue] = [Value]
					FROM
						STRING_SPLIT(@MultiDimSetting, '|')
*/
					IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionValue', * FROM #DimensionValue

					INSERT INTO #Allocation_Row_Dim_Setting
						(
						[Rule_AllocationID],
						[Rule_Allocation_RowID],
						[DimensionValue],
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
						[Customer],
						[Supplier]
						)
					SELECT
						[Rule_AllocationID] = @Rule_AllocationID,
						[Rule_Allocation_RowID] = @Rule_Allocation_RowID,
						[DimensionValue] = @MultiDimSetting,
						[Account] = MAX(CASE WHEN D.DimensionTypeID = 1 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment01] = MAX(CASE WHEN JSN.SegmentNo =  1 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment02] = MAX(CASE WHEN JSN.SegmentNo =  2 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment03] = MAX(CASE WHEN JSN.SegmentNo =  3 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment04] = MAX(CASE WHEN JSN.SegmentNo =  4 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment05] = MAX(CASE WHEN JSN.SegmentNo =  5 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment06] = MAX(CASE WHEN JSN.SegmentNo =  6 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment07] = MAX(CASE WHEN JSN.SegmentNo =  7 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment08] = MAX(CASE WHEN JSN.SegmentNo =  8 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment09] = MAX(CASE WHEN JSN.SegmentNo =  9 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment10] = MAX(CASE WHEN JSN.SegmentNo = 10 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment11] = MAX(CASE WHEN JSN.SegmentNo = 11 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment12] = MAX(CASE WHEN JSN.SegmentNo = 12 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment13] = MAX(CASE WHEN JSN.SegmentNo = 13 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment14] = MAX(CASE WHEN JSN.SegmentNo = 14 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment15] = MAX(CASE WHEN JSN.SegmentNo = 15 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment16] = MAX(CASE WHEN JSN.SegmentNo = 16 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment17] = MAX(CASE WHEN JSN.SegmentNo = 17 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment18] = MAX(CASE WHEN JSN.SegmentNo = 18 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment19] = MAX(CASE WHEN JSN.SegmentNo = 19 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Segment20] = MAX(CASE WHEN JSN.SegmentNo = 20 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Customer] = MAX(CASE WHEN LEFT(DV.[DimensionValue], 8) = 'Customer' THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END),
						[Supplier] = MAX(CASE WHEN LEFT(DV.[DimensionValue], 8) = 'Supplier' THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END)
					FROM
						#DimensionValue DV
						INNER JOIN pcINTEGRATOR..Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = LEFT(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])-1)
						LEFT JOIN pcINTEGRATOR_Data..Journal_SegmentNo JSN ON JSN.InstanceID = @InstanceID AND JSN.VersionID = @VersionID AND JSN.DimensionID = D.DimensionID
					
					FETCH NEXT FROM MultiDimSetting_Cursor INTO @Rule_AllocationID, @Rule_Allocation_RowID, @MultiDimSetting
				END

		CLOSE MultiDimSetting_Cursor
		DEALLOCATE MultiDimSetting_Cursor

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Allocation_Row_Dim_Setting', * FROM #Allocation_Row_Dim_Setting ORDER BY [Rule_AllocationID], [Rule_Allocation_RowID]
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After calculating #Allocation_Row_Dim_Setting', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Run RULE_Allocation_Cursor'
		IF CURSOR_STATUS('global','RULE_Allocation_Cursor') >= -1 DEALLOCATE RULE_Allocation_Cursor
		DECLARE RULE_Allocation_Cursor CURSOR FOR
			SELECT
				[JournalNo],
				[Rule_AllocationID],
				[Rule_AllocationName],
				[JournalSequence],
				[Source_DataClassID],
				[Source_DimensionFilter],
				[Across_DataClassID],
				[Across_Member],
				[Across_WithinDim],
				[Across_Basis],
				[Across_Member_Default],
				[JournalOnlyYN],
				[ModifierID],
				[Parameter],
                [BeginTime] = [StartTime],
                [EndTime]
			FROM
				#RULE_Allocation_Cursor_Table
			ORDER BY
				[SortOrder]

			OPEN RULE_Allocation_Cursor
			FETCH NEXT FROM RULE_Allocation_Cursor INTO @JournalNo, @Rule_AllocationID, @Rule_AllocationName, @JournalSequence, @Source_DataClassID, @Source_DimensionFilter, @Across_DataClassID, @Across_Member, @Across_WithinDim, @Across_Basis, @Across_Member_Default, @JournalOnlyYN, @ModifierID, @Parameter, @BeginTime, @EndTime

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT
						@Source_DataClassName = [DataClassName],
						@Source_DataClassTypeID = [DataClassTypeID]
					FROM
						pcINTEGRATOR_Data..DataClass
					WHERE
						[InstanceID] = @InstanceID AND
						[VersionID] = @VersionID AND
						[DataClassID] = @Source_DataClassID AND
						[SelectYN] <> 0 AND
						[DeletedID] IS NULL

					SELECT
						@Across_DataClassName = [DataClassName]
					FROM
						pcINTEGRATOR_Data..DataClass
					WHERE
						[InstanceID] = @InstanceID AND
						[VersionID] = @VersionID AND
						[DataClassID] = @Across_DataClassID AND
						[SelectYN] <> 0 AND
						[DeletedID] IS NULL
					
					IF @DebugBM & 2 > 0 
						SELECT
							[@JournalNo] = @JournalNo,
							[@Rule_AllocationID]=@Rule_AllocationID,
							[@Rule_AllocationName]=@Rule_AllocationName,
							[@JournalSequence]=@JournalSequence,
							[@Source_DataClassID] = @Source_DataClassID,
							[@Source_DataClassName] = @Source_DataClassName,
							[@Source_DataClassTypeID] = @Source_DataClassTypeID,
							[@Source_DimensionFilter] = @Source_DimensionFilter,
							[@Across_DataClassID] = @Across_DataClassID,
							[@Across_DataClassName] = @Across_DataClassName,
							[@Across_Member] = @Across_Member,
							[@Across_WithinDim] = @Across_WithinDim,
							[@Across_Basis] = @Across_Basis,
							[@Across_Member_Default] = @Across_Member_Default,
							[@JournalOnlyYN] = @JournalOnlyYN,
							[@ModifierID] = @ModifierID,
							[@Parameter] = @Parameter,
							[@BeginTime] = @BeginTime,
							[@EndTime] = @EndTime

					--Set @Source_DimensionFilter'
					IF LEN(@Source_DimensionFilter) > 0
						BEGIN
							TRUNCATE TABLE #JournalAlloc
							TRUNCATE TABLE #FilterTable
							TRUNCATE TABLE #AcrossGroupBy
							TRUNCATE TABLE #AcrossFilter
							SELECT @Source_DimensionFilter_LeafLevel = '', @PropertyFilter = ''

							SET @StorageTypeBM_DataClass = CASE WHEN @Source_DataClassTypeID = -5 THEN 1 ELSE 2 END
											
							EXEC pcINTEGRATOR..spGet_FilterTable
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepReference = 'BR03_01',
								@PipeString = @Source_DimensionFilter,
								@StorageTypeBM_DataClass = @StorageTypeBM_DataClass,
								@StorageTypeBM = 4, --@StorageTypeBM,
								@Debug = @DebugSub

							SELECT
								@Source_DimensionFilter_LeafLevel = @Source_DimensionFilter_LeafLevel + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 
									CASE @StorageTypeBM_DataClass 
										WHEN 1 THEN  + 'J.[' + [JournalColumn] + '] IN (' + [LeafLevelFilter] + ') AND'
										WHEN 2 THEN  + 'V.[' + [DimensionName] + '] IN (' + [LeafLevelFilter] + ') AND'
									END
							FROM
								#FilterTable
							WHERE
								[StepReference] = 'BR03_01' AND
								[LeafLevelFilter] IS NOT NULL

							SELECT
								@PropertyFilter = @PropertyFilter + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + FT.[PropertyFilter]
						--		REPLACE(FT.[PropertyFilter], '= V.[' + FT.[DimensionName] + ']', '= J.[' + FT.[JournalColumn] + ']')
							FROM
								#FilterTable FT
							WHERE
								FT.[StepReference] = 'BR03_01' AND
								FT.[PropertyFilter] IS NOT NULL

							SET @Source_DimensionFilter_LeafLevel = LEFT(@Source_DimensionFilter_LeafLevel, LEN(@Source_DimensionFilter_LeafLevel) - 3)

							IF @DebugBM & 2 > 0 
								BEGIN
									PRINT '@Source_DimensionFilter_LeafLevel: ' + @Source_DimensionFilter_LeafLevel
									SELECT TempTable = '#FilterTable', [Phase] = '@Source_DimensionFilter', * FROM #FilterTable WHERE [StepReference] = 'BR03_01'
									SELECT [@Source_DimensionFilter_LeafLevel] = @Source_DimensionFilter_LeafLevel, [@PropertyFilter] = @PropertyFilter
								END
						END

--JournalAlloc --Source/Base
					IF @DebugBM & 2 > 0
						SELECT
							[@Rule_AllocationID] = @Rule_AllocationID,
							[@JournalTable] = @JournalTable,
							[@InstanceID] = @InstanceID,
							[@Source_DimensionFilter_LeafLevel] = @Source_DimensionFilter_LeafLevel,
							[@PropertyFilter] = @PropertyFilter,
							[@FromTime] = @FromTime,
							[@ToTime] = @ToTime

					--Insert base amount into #JournalAlloc
					--SELECT
					--	@Source_DataClassTypeID = DataClassTypeID
					--FROM
					--	pcINTEGRATOR_Data..DataClass
					--WHERE
					--	InstanceID = @InstanceID AND
					--	VersionID = @VersionID AND
					--	DataClassID = @Source_DataClassID 

					--IF @DebugBM & 2 > 0 SELECT [@Source_DataClassTypeID] = @Source_DataClassTypeID

					IF @Source_DataClassTypeID = -5
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@PropertyFilter] = @PropertyFilter
							--IF @Rule_AllocationID = 2136
							--	SET @PropertyFilter = 'INNER JOIN [pcDATA_REM].[dbo].[S_DS_GL_Branch] [GL_Branch] ON [GL_Branch].[MemberKeyBase] = J.[Segment01] AND [GL_Branch].[GLB_Type] IN (''Branch'')'
							IF @DebugBM & 2 > 0 SELECT [@PropertyFilter] = @PropertyFilter

							SET @SQLStatement = '
								INSERT INTO #JournalAlloc
									(
									[BaseRow],
									[Entity],
									[Book],
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
									[Customer],
									[Supplier],
									[Scenario],
									[Currency_Book],
									[Value_Book]
									)'

							SET @SQLStatement = @SQLStatement + '
								SELECT
									[BaseRow] = ''BASE'',
									[Entity] = J.[Entity],
									[Book] = J.[Book],
									[FiscalYear] = J.[FiscalYear],
									[FiscalPeriod] = J.[FiscalPeriod],
									[YearMonth] = J.[YearMonth],
									[BalanceYN] = MAX(CONVERT(int, J.[BalanceYN])),
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
									[Customer] = J.[Customer],
									[Supplier] = J.[Supplier],
									[Scenario] = J.[Scenario],
									[Currency_Book] = J.[Currency_Book],
									[Value_Book] = ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4)'

							SET @SQLStatement = @SQLStatement + '
								FROM
									' + @JournalTable + ' J
									' + ISNULL(@PropertyFilter, '') + '
								WHERE
									J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
									J.[TransactionTypeBM] & 3 > 0' + CASE WHEN @Source_DimensionFilter_LeafLevel IS NOT NULL THEN ' AND ' + @Source_DimensionFilter_LeafLevel ELSE '' END + ' AND
									J.[SourceModuleReference] <> ''' + CONVERT(nvarchar(15), @BusinessRuleID) + '_' + CONVERT(nvarchar(15), @Rule_AllocationID) + '''
									' + CASE WHEN @FromTime IS NOT NULL THEN 'AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END + '
									' + CASE WHEN @ToTime IS NOT NULL THEN 'AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END + '
									' + CASE WHEN @BeginTime IS NOT NULL THEN 'AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @BeginTime) ELSE '' END + '
									' + CASE WHEN @EndTime IS NOT NULL THEN 'AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @EndTime) ELSE '' END

							SET @SQLStatement = @SQLStatement + '
								GROUP BY
									J.[Entity],
									J.[Book],
									J.[FiscalYear],
									J.[FiscalPeriod],
									J.[YearMonth],
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
									J.[Customer],
									J.[Supplier],
									J.[Scenario],
									J.[Currency_Book]
								HAVING
									ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4) <> 0.0'

						END
					ELSE IF @Source_DataClassTypeID IN (-1)
						BEGIN
							SET @SQLStatement = '
								INSERT INTO #JournalAlloc
									(
									[BaseRow],
									[Entity],
									[Book],
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
									[Customer],
									[Supplier],
									[Scenario],
									[Currency_Book],
									[Value_Book]
									)'

							IF @Rule_AllocationID BETWEEN 2150 AND 2170
								BEGIN
									SET @SQLStatement = @SQLStatement + '
										SELECT
											[BaseRow] = ''BASE'',
											[Entity] = ''REM'',
											[Book] = ''GL'',
											[FiscalYear] = LEFT(V.[Time], 4),
											[FiscalPeriod] = V.[Time] % 100,
											[YearMonth] = V.[Time],
											[BalanceYN] = 0, --MAX(CONVERT(int, V.[BalanceYN])),
											[Account] = MAX(V.[Account]),
											[Segment01] = '''',
											[Segment02] = '''',
											[Segment03] = [GL_Contact].[RegionNo],
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
											[Customer] = '''',
											[Supplier] = '''',
											[Scenario] = ''ACTUAL'',
											[Currency_Book] = ''USD'',
											[Value_Book] = SUM(V.[AllocBaseData_Value])'

									SET @SQLStatement = @SQLStatement + '
										FROM
											pcDATA_REM..FACT_AllocBaseData_View V' + @PropertyFilter + '
										WHERE
											1 = 1
											' + CASE WHEN @Source_DimensionFilter_LeafLevel IS NOT NULL THEN 'AND ' + @Source_DimensionFilter_LeafLevel ELSE '' END + '
											' + CASE WHEN @FromTime IS NOT NULL THEN 'AND V.[Time] >= ''' + CONVERT(nvarchar(15), @FromTime) + '''' ELSE '' END + '
											' + CASE WHEN @ToTime IS NOT NULL THEN 'AND V.[Time] <= ''' + CONVERT(nvarchar(15), @ToTime) + '''' ELSE '' END + '
											' + CASE WHEN @BeginTime IS NOT NULL THEN 'AND V.[Time] >= ''' + CONVERT(nvarchar(15), @BeginTime) + '''' ELSE '' END + '
											' + CASE WHEN @EndTime IS NOT NULL THEN 'AND V.[Time] <= ''' + CONVERT(nvarchar(15), @EndTime) + '''' ELSE '' END + '
										GROUP BY
											V.[Time],
											[GL_Contact].RegionNo'

								END
							ELSE
								BEGIN
									SET @SQLStatement = @SQLStatement + '
										SELECT
											[BaseRow] = ''BASE'',
											[Entity] = ''REM'',
											[Book] = ''GL'',
											[FiscalYear] = LEFT(V.[Time], 4),
											[FiscalPeriod] = V.[Time] % 100,
											[YearMonth] = V.[Time],
											[BalanceYN] = 0, --MAX(CONVERT(int, V.[BalanceYN])),
											[Account] = V.[Account],
											[Segment01] = [GL_Branch].[MemberKeyBase],
											[Segment02] = '''',
											[Segment03] = V.[GL_Contact],
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
											[Customer] = '''',
											[Supplier] = '''',
											[Scenario] = ''ACTUAL'',
											[Currency_Book] = ''USD'',
											[Value_Book] = V.[AllocBaseData_Value]'

									SET @SQLStatement = @SQLStatement + '
										FROM
											pcDATA_REM..FACT_AllocBaseData_View V
											' + CASE WHEN @Rule_AllocationID = 2135 THEN 'INNER JOIN [pcDATA_REM].[dbo].[S_DS_GL_Branch] [GL_Branch] ON [GL_Branch].[Label] = V.[GL_Branch] AND [GL_Branch].[GLB_Type] IN (''Branch'')' ELSE 'INNER JOIN [pcDATA_REM].[dbo].[S_DS_GL_Branch] [GL_Branch] ON [GL_Branch].[Label] = V.[GL_Branch]' + @PropertyFilter END + '
										WHERE
											1 = 1
											' + CASE WHEN @Source_DimensionFilter_LeafLevel IS NOT NULL THEN 'AND ' + @Source_DimensionFilter_LeafLevel ELSE '' END + '
											' + CASE WHEN @FromTime IS NOT NULL THEN 'AND V.[Time] >= ''' + CONVERT(nvarchar(15), @FromTime) + '''' ELSE '' END + '
											' + CASE WHEN @ToTime IS NOT NULL THEN 'AND V.[Time] <= ''' + CONVERT(nvarchar(15), @ToTime) + '''' ELSE '' END + '
											' + CASE WHEN @BeginTime IS NOT NULL THEN 'AND V.[Time] >= ''' + CONVERT(nvarchar(15), @BeginTime) + '''' ELSE '' END + '
											' + CASE WHEN @EndTime IS NOT NULL THEN 'AND V.[Time] <= ''' + CONVERT(nvarchar(15), @EndTime) + '''' ELSE '' END
									END
/*
							IF @Rule_AllocationID = 2135
							
							SET @SQLStatement = @SQLStatement + '
								FROM
									pcDATA_REM..FACT_AllocBaseData_View J
									INNER JOIN [pcDATA_REM].[dbo].[S_DS_GL_Branch] [GL_Branch] ON [GL_Branch].[Label] = J.[GL_Branch] AND [GL_Branch].[GLB_Type] IN (''Branch'')
								WHERE
									J.[Account] = ''ST_AB_DirectShip5000'''

							ELSE IF @Rule_AllocationID BETWEEN 2137 AND 2170
							
							SET @SQLStatement = @SQLStatement + '
								FROM
									pcDATA_REM..FACT_AllocBaseData_View J
									INNER JOIN [pcDATA_REM].[dbo].[S_DS_GL_Branch] [GL_Branch] ON [GL_Branch].[Label] = J.[GL_Branch] AND [GL_Branch].[GLB_Type] IN (''Branch'')
								WHERE
									J.[Account] = ''1200-7000'''
*/
/*
								WHERE
									J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
									J.[TransactionTypeBM] & 3 > 0' + CASE WHEN @Source_DimensionFilter_LeafLevel IS NOT NULL THEN ' AND ' + @Source_DimensionFilter_LeafLevel ELSE '' END + ' AND
									J.[SourceModuleReference] <> ''' + CONVERT(nvarchar(15), @BusinessRuleID) + '_' + CONVERT(nvarchar(15), @Rule_AllocationID) + '''
									' + CASE WHEN @FromTime IS NOT NULL THEN 'AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END + '
									' + CASE WHEN @ToTime IS NOT NULL THEN 'AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END + '
									' + CASE WHEN @BeginTime IS NOT NULL THEN 'AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @BeginTime) ELSE '' END + '
									' + CASE WHEN @EndTime IS NOT NULL THEN 'AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @EndTime) ELSE '' END
*/
/*
							SET @SQLStatement = @SQLStatement + '
								GROUP BY
									J.[Entity],
									J.[Book],
									J.[FiscalYear],
									J.[FiscalPeriod],
									J.[YearMonth],
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
									J.[Customer],
									J.[Supplier],
									J.[Scenario],
									J.[Currency_Book]
								HAVING
									ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4) <> 0.0'
*/
						END


					IF @DebugBM & 2 > 0 
						BEGIN
							IF LEN(@SQLStatement) > 4000 
								BEGIN
									PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR03, Insert into #JournalAlloc; @Rule_AllocationID = ' + CONVERT(nvarchar(15), @Rule_AllocationID) + '.'
									SET @Comment = 'BR03, Insert into #JournalAlloc; @Rule_AllocationID = ' + CONVERT(nvarchar(15), @Rule_AllocationID)
									EXEC [dbo].[spSet_wrk_Debug]
										@UserID = @UserID,
										@InstanceID = @InstanceID,
										@VersionID = @VersionID,
										@DatabaseName = @DatabaseName,
										@CalledProcedureName = @ProcedureName,
										@Comment = @Comment, 
										@SQLStatement = @SQLStatement,
										@JobID = @JobID
								END
							ELSE
								PRINT @SQLStatement
						END
					EXEC (@SQLStatement)

					IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert BASE into #JournalAlloc, [@Rule_AllocationID] = ' + CONVERT(nvarchar(15), @Rule_AllocationID), [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
					IF @DebugBM & 2 > 0 
						BEGIN
							SELECT TempTable = '#Allocation_Row', * FROM #Allocation_Row WHERE [Rule_AllocationID] = @Rule_AllocationID
							SELECT TempTable = '#Allocation_Row_Dim_Setting', * FROM #Allocation_Row_Dim_Setting WHERE [Rule_AllocationID] = @Rule_AllocationID
							SELECT TempTable = '#JournalAlloc (Source)', [@Rule_AllocationID] = @Rule_AllocationID, * FROM #JournalAlloc WHERE [BaseRow] = 'BASE' ORDER BY YearMonth, Account, Segment01, Segment02, Segment03
						END




					--Set Across Properties'
					IF @Across_DataClassID IS NOT NULL
						BEGIN
							--@Across_DataClassID
							IF @DebugBM & 2 > 0
								SELECT
									[DataClassName],
									[StorageTypeBM]
								FROM
									pcINTEGRATOR_Data..DataClass
								WHERE
									[InstanceID] = @InstanceID AND
									[VersionID] = @VersionID AND
									[DataClassID] = @Across_DataClassID AND
									[SelectYN] <> 0 AND
									[DeletedID] IS NULL
											
							EXEC pcINTEGRATOR..spGet_FilterTable
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepReference = 'BR03_02',
								@PipeString = @Across_Member,
								@StorageTypeBM_DataClass = 4, --@StorageTypeBM_DataClass,
								@StorageTypeBM = 4, --@StorageTypeBM,
								@Debug = @DebugSub

							INSERT INTO #AcrossGroupBy
								(
								[DimensionName],
								[WithInYN]
								)
							SELECT
								[DimensionName],
								[WithInYN] = 0
							FROM
								#FilterTable
							WHERE
								[StepReference] = 'BR03_02'

							INSERT INTO #AcrossFilter
								(
								[DimensionName],
								[LeafLevelFilter],
								[PropertyFilter]
								)
							SELECT
								[DimensionName],
								[LeafLevelFilter],
								[PropertyFilter]
							FROM
								#FilterTable
							WHERE
								[StepReference] = 'BR03_02'

							IF @DebugBM & 2 > 0 
								BEGIN
									SELECT TempTable = '#FilterTable', [Phase] = '@Across_Member', * FROM #FilterTable WHERE [StepReference] = 'BR03_02'
									SELECT TempTable = '#AcrossGroupBy', [Phase] = '@Across_Member', * FROM #AcrossGroupBy
									SELECT TempTable = '#AcrossFilter', [Phase] = '@Across_Member', * FROM #AcrossFilter
								END
											
							EXEC pcINTEGRATOR..spGet_FilterTable
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepReference = 'BR03_03',
								@PipeString = @Across_WithinDim,
								@StorageTypeBM_DataClass = 4, --@StorageTypeBM_DataClass,
								@StorageTypeBM = 4, --@StorageTypeBM,
								@Debug = @DebugSub

							INSERT INTO #AcrossGroupBy
								(
								[DimensionName],
								[WithInYN]
								)
							SELECT
								[DimensionName],
								[WithInYN] = 1
							FROM
								#FilterTable
							WHERE
								[StepReference] = 'BR03_03'

							UPDATE AGB
							SET
								[MappingTypeID] = DST.[MappingTypeID],
								[JournalColumn] = CASE WHEN D.[DimensionTypeID] = -1 THEN 'Segment' + CASE WHEN JSN.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo]) ELSE REPLACE(AGB.[DimensionName], 'Time', 'YearMonth') END
							FROM
								#AcrossGroupBy AGB
								INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.[InstanceID] IN (0, @InstanceID) AND D.DimensionName = AGB.DimensionName
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST ON DST.[InstanceID] = @InstanceID AND DST.[VersionID] = @VersionID AND DST.[DimensionID] = D.[DimensionID]
								LEFT JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.[InstanceID] = @InstanceID AND JSN.[VersionID] = @VersionID AND JSN.[DimensionID] = D.[DimensionID]

							--IF @DebugBM & 2 > 0 SELECT TempTable = '#AcrossGroupBy', * FROM #AcrossGroupBy

							IF @DebugBM & 2 > 0 
								BEGIN
									SELECT TempTable = '#FilterTable', [Phase] = '@Across_WithinDim', * FROM #FilterTable WHERE [StepReference] = 'BR03_03'
									SELECT TempTable = '#AcrossGroupBy', [Phase] = '@Across_WithinDim', * FROM #AcrossGroupBy
								END

							EXEC pcINTEGRATOR..spGet_FilterTable
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepReference = 'BR03_04',
								@PipeString = @Across_Basis,
								@StorageTypeBM_DataClass = 4, --@StorageTypeBM_DataClass,
								@StorageTypeBM = 4, --@StorageTypeBM,
								@Debug = @DebugSub

							INSERT INTO #AcrossFilter
								(
								[DimensionName],
								[LeafLevelFilter],
								[PropertyFilter]
								)
							SELECT
								[DimensionName],
								[LeafLevelFilter],
								[PropertyFilter]
							FROM
								#FilterTable
							WHERE
								[StepReference] = 'BR03_04'

							IF @DebugBM & 2 > 0 
								BEGIN
									SELECT TempTable = '#FilterTable', [Phase] = '@Across_Basis', * FROM #FilterTable WHERE [StepReference] = 'BR03_04'
									SELECT TempTable = '#AcrossFilter', [Phase] = '@Across_Basis', * FROM #AcrossFilter
								END

							--#AllocateAcross
							CREATE TABLE #AllocateAcross 
								(
								[Numerator] float,
								[Denominator] float,
								[Value] float
								)

							--Run cursor for adding columns to temp tables for data'
							IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
							DECLARE AddColumn_Cursor CURSOR FOR
								SELECT 
									[DimensionName]
								FROM
									#AcrossGroupBy
								ORDER BY
									[DimensionName]

								OPEN AddColumn_Cursor
								FETCH NEXT FROM AddColumn_Cursor INTO @DimensionName

								WHILE @@FETCH_STATUS = 0
									BEGIN
										SET @SQLStatement = '
											ALTER TABLE #AllocateAcross ADD [' + @DimensionName + '] nvarchar(50)'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

										FETCH NEXT FROM AddColumn_Cursor INTO @DimensionName
									END

							CLOSE AddColumn_Cursor
							DEALLOCATE AddColumn_Cursor	

							IF @DebugBM & 2 > 0 SELECT TempTable= '#AllocateAcross', * FROM #AllocateAcross

							SELECT 
								@SQLInsert = '',
								@SQLSelect = '',
								@SQLJoin = '',
								@SQLGroupBy = '',
								@SQLWhere = ''

							SELECT 
								@SQLInsert = @SQLInsert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + AGB.[DimensionName] + '],',
								@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + AGB.[DimensionName] + '] = MAX([' + AGB.[DimensionName] + '].[' + CASE WHEN [MappingTypeID] = 0 THEN 'Label' ELSE 'MemberKeyBase' END + ']),',
								@SQLJoin = @SQLJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + AGB.[DimensionName] + '] [' + AGB.[DimensionName] + '] ON [' + AGB.[DimensionName] + '].[MemberId] = AA.[' + AGB.[DimensionName] + '_MemberId]' + CASE WHEN AF.[PropertyFilter] IS NOT NULL THEN ' AND [GL_Branch].[GLB_Type]=''Branch''' ELSE '' END,
								@SQLGroupBy = @SQLGroupBy + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'AA.[' + AGB.[DimensionName] + '_MemberId],'
							FROM
								#AcrossGroupBy AGB
								LEFT JOIN #AcrossFilter AF ON AF.[DimensionName] = AGB.[DimensionName] AND AF.[PropertyFilter] IS NOT NULL
							ORDER BY
								AGB.DimensionName

							SELECT 
								@SQLWhere = @SQLWhere + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [DimensionName] + '_MemberID] IN (' + [LeafLevelFilter] + ') AND',
								@PropertyFilter = [PropertyFilter]
							FROM
								#AcrossFilter
							ORDER BY
								DimensionName

							SELECT
								@SQLWhere = LEFT(@SQLWhere, LEN(@SQLWhere) - 3),
								@SQLGroupBy = LEFT(@SQLGroupBy, LEN(@SQLGroupBy) - 1)

							IF @DebugBM & 2 > 0
								SELECT
									[@SQLInsert] = @SQLInsert,
									[@SQLSelect] = @SQLSelect,
									[@Across_DataClassName] = @Across_DataClassName,
									[@CallistoDatabase] = @CallistoDatabase,
									[@SQLJoin] = @SQLJoin,
									[@SQLWhere] = @SQLWhere,
									[@PropertyFilter] = @PropertyFilter,
									[@SQLGroupBy] = @SQLGroupBy

							IF @Rule_AllocationID BETWEEN 2150 AND 2170
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #AllocateAcross
											(' + @SQLInsert + '
											[Numerator],
											[Denominator],
											[Value]
											)
										SELECT
											[GL_Branch] = MAX([GL_Branch].[MemberKeyBase]),
											[RegionNo] = CONVERT(int, RIGHT([Region].[Label], 2)),
											[Time] = MAX([Time].[Label]),
											[Numerator] = CONVERT(float, SUM([AllocBaseData_Value])),
											[Denominator] = CONVERT(float, 0),
											[Value] = CONVERT(float, 0)
										FROM
											[pcDATA_REM].[dbo].[FACT_AllocBaseData_default_partition] AA
											INNER JOIN [pcDATA_REM].[dbo].[S_DS_GL_Branch] [GL_Branch] ON [GL_Branch].[MemberId] = AA.[GL_Branch_MemberId] AND [GL_Branch].[GLB_Type]=''Branch''
											INNER JOIN [pcDATA_REM].[dbo].[S_HS_GL_Branch_GL_Branch] P ON [P].[MemberId] = GL_Branch.[MemberId]
											INNER JOIN [pcDATA_REM].[dbo].[S_DS_GL_Branch] [Region] ON [Region].[MemberId] = P.[ParentMemberId] AND ISNUMERIC(RIGHT([Region].[Label], 2)) <> 0
											INNER JOIN [pcDATA_REM].[dbo].[S_DS_Time] [Time] ON [Time].[MemberId] = AA.[Time_MemberId]
										WHERE
											1 = 1
											' + CASE WHEN @SQLWhere IS NOT NULL THEN 'AND ' + @SQLWhere ELSE '' END + '
											' + CASE WHEN @FromTime IS NOT NULL THEN 'AND AA.Time_MemberId >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END + '
											' + CASE WHEN @ToTime IS NOT NULL THEN 'AND AA.Time_MemberId <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END + '
											' + CASE WHEN @BeginTime IS NOT NULL THEN 'AND AA.Time_MemberId >= ' + CONVERT(nvarchar(15), @BeginTime) ELSE '' END + '
											' + CASE WHEN @EndTime IS NOT NULL THEN 'AND AA.Time_MemberId <= ' + CONVERT(nvarchar(15), @EndTime) ELSE '' END + '
										GROUP BY
											AA.[GL_Branch_MemberId],
											[Region].[Label],
											AA.[Time_MemberId]'
								END
							ELSE
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #AllocateAcross
											(' + @SQLInsert + '
											[Numerator],
											[Denominator],
											[Value]
											)
										SELECT' + @SQLSelect + '
											[Numerator] = SUM([' + @Across_DataClassName + '_Value]),
											[Denominator] = 0,
											[Value] = 0
										FROM
											' + @CallistoDatabase + '.[dbo].[FACT_' + @Across_DataClassName + '_default_partition] AA' + @SQLJoin + '
										WHERE
											1 = 1
											' + CASE WHEN @SQLWhere IS NOT NULL THEN 'AND ' + @SQLWhere ELSE '' END + '
											' + CASE WHEN @FromTime IS NOT NULL THEN 'AND AA.Time_MemberId >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END + '
											' + CASE WHEN @ToTime IS NOT NULL THEN 'AND AA.Time_MemberId <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END + '
											' + CASE WHEN @BeginTime IS NOT NULL THEN 'AND AA.Time_MemberId >= ' + CONVERT(nvarchar(15), @BeginTime) ELSE '' END + '
											' + CASE WHEN @EndTime IS NOT NULL THEN 'AND AA.Time_MemberId <= ' + CONVERT(nvarchar(15), @EndTime) ELSE '' END + '
										GROUP BY' + @SQLGroupBy
									END

--							' + CASE WHEN @PropertyFilter  IS NOT NULL THEN + @PropertyFilter ELSE '' END + '

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							IF @DebugBM & 2 > 0 SELECT TempTable = '#AllocateAcross', * FROM #AllocateAcross

							
							SELECT 
								@SQLJoin = '',
								@SQLGroupBy = ''
							
							SELECT
								@SQLJoin = @SQLJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ' sub.[' + [DimensionName] + '] = AA.[' + [DimensionName] + '] AND',
								@SQLGroupBy = @SQLGroupBy + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [DimensionName] + '],'
							FROM
								#AcrossGroupBy
							WHERE
								[WithInYN] <> 0
							ORDER BY
								DimensionName

							SELECT
								@SQLJoin = LEFT(@SQLJoin, LEN(@SQLJoin) - 3),
								@SQLGroupBy = LEFT(@SQLGroupBy, LEN(@SQLGroupBy) - 1)

							SET @SQLStatement = '
								UPDATE AA
								SET
									[Denominator] = sub.[Denominator],
									[Value] = AA.[Numerator] / sub.[Denominator]
								FROM
									#AllocateAcross AA
									INNER JOIN
										(
										SELECT 
											[Denominator] = SUM([Numerator]),' + @SQLGroupBy + '
										FROM
											#AllocateAcross
										GROUP BY' + @SQLGroupBy + '
										HAVING
											SUM([Numerator]) <> 0
										) sub ON' + @SQLJoin

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							IF @DebugBM & 2 > 0 SELECT TempTable = '#AllocateAcross', * FROM #AllocateAcross
						END


					IF @Across_DataClassID IS NULL
						BEGIN
							INSERT INTO #JournalAlloc
								(
								[BaseRow],
								[Entity],
								[Book],
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
								[Customer],
								[Supplier],
								[Scenario],
								[Currency_Book],
								[Value_Book]
								)
							SELECT
								[BaseRow] = 'ALLOC',
								[Entity] = JB.[Entity], 
								[Book] = JB.[Book],
								[FiscalYear] = JB.[FiscalYear],
								[FiscalPeriod] = JB.[FiscalPeriod],
								[YearMonth] = JB.[YearMonth],
								[BalanceYN] = MAX(CONVERT(int, JB.[BalanceYN])),
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
								[Customer] = JB.[Customer],
								[Supplier] = JB.[Supplier],
								[Scenario] = JB.[Scenario],
								[Currency_Book] = JB.[Currency_Book],
								[Value_Book] = SUM(JB.[Value_Book])
							FROM
								#JournalAlloc JB
							WHERE
								JB.[BaseRow] = 'BASE'
							GROUP BY
								JB.[Entity], 
								JB.[Book],
								JB.[FiscalYear],
								JB.[FiscalPeriod],
								JB.[YearMonth],
								JB.[Account],
								JB.[Segment01],
								JB.[Segment02],
								JB.[Segment03],
								JB.[Segment04],
								JB.[Segment05],
								JB.[Segment06],
								JB.[Segment07],
								JB.[Segment08],
								JB.[Segment09],
								JB.[Segment10],
								JB.[Segment11],
								JB.[Segment12],
								JB.[Segment13],
								JB.[Segment14],
								JB.[Segment15],
								JB.[Segment16],
								JB.[Segment17],
								JB.[Segment18],
								JB.[Segment19],
								JB.[Segment20],
								JB.[Customer],
								JB.[Supplier],
								JB.[Scenario],
								JB.[Currency_Book]
							HAVING
								SUM(JB.[Value_Book]) <> 0.0
						END
					ELSE
						BEGIN
							
							SET @SQLJoin = ''
							
							SELECT
								@SQLJoin = @SQLJoin + ' AA.[' + [DimensionName] + '] = JB.[' + [JournalColumn] + '] AND'
							FROM
								#AcrossGroupBy
							WHERE
								WithInYN <> 0
							ORDER BY
								DimensionName

							SELECT
								@SQLJoin = LEFT(@SQLJoin, LEN(@SQLJoin) - 3)

							SELECT
								@AGB = @AGB + [JournalColumn] + '=' + [DimensionName] + '|'
							FROM
								#AcrossGroupBy
							WHERE
								WithInYN = 0
							ORDER BY
								JournalColumn

							IF @DebugBM & 2 > 0 SELECT [@SQLJoin] = @SQLJoin, [@AGB] = @AGB

							SET @SQLStatement = '
								INSERT INTO #JournalAlloc
									(
									[BaseRow],
									[Entity],
									[Book],
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
									[Customer],
									[Supplier],
									[Scenario],
									[Currency_Book],
									[Value_Book]
									)'

					IF @Rule_AllocationID BETWEEN 2136 AND 2170
						BEGIN
							SET @SQLStatement = @SQLStatement + '
								SELECT
									[BaseRow] = ''ALLOC'',
									[Entity] = JB.[Entity], 
									[Book] = JB.[Book],
									[FiscalYear] = JB.[FiscalYear],
									[FiscalPeriod] = JB.[FiscalPeriod],
									[YearMonth] = JB.[YearMonth],
									[BalanceYN] = MAX(CONVERT(int, JB.[BalanceYN])),
									[Account] = JB.[Account],
									[Segment01] = ISNULL(AA.[GL_Branch], REPLACE(Def.[GL_Branch], ''REM_'', '''')),
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
									[Customer] = JB.[Customer],
									[Supplier] = JB.[Supplier],
									[Scenario] = JB.[Scenario],
									[Currency_Book] = JB.[Currency_Book],
									[Value_Book] = SUM(JB.[Value_Book] * ISNULL(AA.[Value], 1))
								FROM
									#JournalAlloc JB
									LEFT JOIN pcDATA_REM..S_DS_GL_Contact Def ON Def.[Label] = JB.Segment03
									LEFT JOIN #AllocateAcross AA ON AA.[Time] = JB.[YearMonth]' + CASE WHEN @Rule_AllocationID <> 2136 THEN ' AND AA.[GL_Contact] = JB.[Segment03]' ELSE '' END + '
								WHERE
									JB.[BaseRow] = ''BASE''
								GROUP BY
									JB.[Entity], 
									JB.[Book],
									JB.[FiscalYear],
									JB.[FiscalPeriod],
									JB.[YearMonth],
									JB.[Account],
									ISNULL(AA.[GL_Branch], REPLACE(Def.[GL_Branch], ''REM_'', '''')),
									JB.[Segment02],
									JB.[Segment03],
									JB.[Segment04],
									JB.[Segment05],
									JB.[Segment06],
									JB.[Segment07],
									JB.[Segment08],
									JB.[Segment09],
									JB.[Segment10],
									JB.[Segment11],
									JB.[Segment12],
									JB.[Segment13],
									JB.[Segment14],
									JB.[Segment15],
									JB.[Segment16],
									JB.[Segment17],
									JB.[Segment18],
									JB.[Segment19],
									JB.[Segment20],
									JB.[Customer],
									JB.[Supplier],
									JB.[Scenario],
									JB.[Currency_Book]
								HAVING
									SUM(JB.[Value_Book] * ISNULL(AA.[Value], 1)) <> 0.0'
							END
					ELSE
						BEGIN
							SET @SQLStatement = @SQLStatement + '
								SELECT
									[BaseRow] = ''ALLOC'',
									[Entity] = JB.[Entity], 
									[Book] = JB.[Book],
									[FiscalYear] = JB.[FiscalYear],
									[FiscalPeriod] = JB.[FiscalPeriod],
									[YearMonth] = JB.[YearMonth],
									[BalanceYN] = MAX(CONVERT(int, JB.[BalanceYN])),
									[Account] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Account', 'JB', 'AA') + ',
									[Segment01] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment01', 'JB', 'AA') + ',
									[Segment02] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment02', 'JB', 'AA') + ',
									[Segment03] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment03', 'JB', 'AA') + ',
									[Segment04] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment04', 'JB', 'AA') + ',
									[Segment05] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment05', 'JB', 'AA') + ',
									[Segment06] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment06', 'JB', 'AA') + ',
									[Segment07] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment07', 'JB', 'AA') + ',
									[Segment08] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment08', 'JB', 'AA') + ',
									[Segment09] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment09', 'JB', 'AA') + ',
									[Segment10] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment10', 'JB', 'AA') + ',
									[Segment11] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment11', 'JB', 'AA') + ',
									[Segment12] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment12', 'JB', 'AA') + ',
									[Segment13] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment13', 'JB', 'AA') + ',
									[Segment14] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment14', 'JB', 'AA') + ',
									[Segment15] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment15', 'JB', 'AA') + ',
									[Segment16] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment16', 'JB', 'AA') + ',
									[Segment17] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment17', 'JB', 'AA') + ',
									[Segment18] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment18', 'JB', 'AA') + ',
									[Segment19] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment19', 'JB', 'AA') + ',
									[Segment20] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment20', 'JB', 'AA') + ',
									[Customer] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Customer', 'JB', 'AA') + ',
									[Supplier] = ' + [dbo].[f_ReturnSecondString] (@AGB, 'Supplier', 'JB', 'AA') + ',
									[Scenario] = JB.[Scenario],
									[Currency_Book] = JB.[Currency_Book],
									[Value_Book] = SUM(JB.[Value_Book] * AA.[Value])'

							SET @SQLStatement = @SQLStatement + '
								FROM
									#JournalAlloc JB
									INNER JOIN #AllocateAcross AA ON ' + @SQLJoin + '
								WHERE
									JB.[BaseRow] = ''BASE''
								GROUP BY
									JB.[Entity], 
									JB.[Book],
									JB.[FiscalYear],
									JB.[FiscalPeriod],
									JB.[YearMonth],
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Account', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment01', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment02', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment03', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment04', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment05', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment06', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment07', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment08', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment09', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment10', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment11', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment12', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment13', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment14', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment15', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment16', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment17', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment18', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment19', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Segment20', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Customer', 'JB', 'AA') + ',
									' + [dbo].[f_ReturnSecondString] (@AGB, 'Supplier', 'JB', 'AA') + ',
									JB.[Scenario],
									JB.[Currency_Book]
								HAVING
									SUM(JB.[Value_Book] * AA.[Value]) <> 0.0'
							END
									
							IF @DebugBM & 2 > 0 
								BEGIN
									IF LEN(@SQLStatement) > 4000 
										BEGIN
											PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR03, Allocate Across.'
											EXEC [dbo].[spSet_wrk_Debug]
												@UserID = @UserID,
												@InstanceID = @InstanceID,
												@VersionID = @VersionID,
												@DatabaseName = @DatabaseName,
												@CalledProcedureName = @ProcedureName,
												@Comment = 'BR03, Allocate Across', 
												@SQLStatement = @SQLStatement,
												@JobID = @JobID
										END
									ELSE
										PRINT @SQLStatement
								END

							EXEC (@SQLStatement)
							DROP TABLE #AllocateAcross
						END
					
					IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert ALLOC into #JournalAlloc, [@Rule_AllocationID] = ' + CONVERT(nvarchar(15), @Rule_AllocationID), [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
					IF @DebugBM & 2 > 0 SELECT TempTable = '#JournalAlloc (Alloc)', [@Rule_AllocationID] = @Rule_AllocationID, * FROM #JournalAlloc WHERE [BaseRow] = 'ALLOC' ORDER BY YearMonth, Account, Segment01, Segment02, Segment03

					INSERT INTO #JournalBase
						(
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
						[Value_Book],
						[SourceModule],
						[SourceModuleReference]
						)
					SELECT
						[Entity] = JA.[Entity],
						[Book] = JA.[Book],
						[FiscalYear] = JA.[FiscalYear],
						[FiscalPeriod] = JA.[FiscalPeriod],
						[JournalSequence] = @JournalSequence,
						[JournalNo] = @JournalNo,
						[YearMonth] = JA.[YearMonth],
						[TransactionTypeBM] = CASE @JournalOnlyYN WHEN 0 THEN 2 ELSE 4 END,
						[BalanceYN] = MAX(CONVERT(int, JA.[BalanceYN])),
						[Account] = ISNULL(ARDS.[Account], JA.[Account]),
						[Segment01] = ISNULL(ARDS.[Segment01], JA.[Segment01]),
						[Segment02] = ISNULL(ARDS.[Segment02], JA.[Segment02]),
						[Segment03] = ISNULL(ARDS.[Segment03], JA.[Segment03]),
						[Segment04] = ISNULL(ARDS.[Segment04], JA.[Segment04]),
						[Segment05] = ISNULL(ARDS.[Segment05], JA.[Segment05]),
						[Segment06] = ISNULL(ARDS.[Segment06], JA.[Segment06]),
						[Segment07] = ISNULL(ARDS.[Segment07], JA.[Segment07]),
						[Segment08] = ISNULL(ARDS.[Segment08], JA.[Segment08]),
						[Segment09] = ISNULL(ARDS.[Segment09], JA.[Segment09]),
						[Segment10] = ISNULL(ARDS.[Segment10], JA.[Segment10]),
						[Segment11] = ISNULL(ARDS.[Segment11], JA.[Segment11]),
						[Segment12] = ISNULL(ARDS.[Segment12], JA.[Segment12]),
						[Segment13] = ISNULL(ARDS.[Segment13], JA.[Segment13]),
						[Segment14] = ISNULL(ARDS.[Segment14], JA.[Segment14]),
						[Segment15] = ISNULL(ARDS.[Segment15], JA.[Segment15]),
						[Segment16] = ISNULL(ARDS.[Segment16], JA.[Segment16]),
						[Segment17] = ISNULL(ARDS.[Segment17], JA.[Segment17]),
						[Segment18] = ISNULL(ARDS.[Segment18], JA.[Segment18]),
						[Segment19] = ISNULL(ARDS.[Segment19], JA.[Segment19]),
						[Segment20] = ISNULL(ARDS.[Segment20], JA.[Segment20]),
						[JournalDate] = DATEADD(day, -1, DATEADD(month, 1, CONVERT(datetime, CONVERT(nvarchar(10), JA.[YearMonth]) + '01', 112))),
						[TransactionDate] = DATEADD(day, -1, DATEADD(month, 1, CONVERT(datetime, CONVERT(nvarchar(10), JA.[YearMonth]) + '01', 112))),
						[PostedDate] = GetDate(),
						[PostedStatus] = 1,
						[PostedBy] = @UserName,
						[Source] = 'ALLOC',
						[Scenario] = JA.[Scenario],
						[Customer] = ISNULL(ARDS.[Customer], JA.[Customer]),
						[Supplier] = ISNULL(ARDS.[Supplier], JA.[Supplier]),
						[Description_Head] = '[Rule_AllocationName] = ' + @Rule_AllocationName,
						[Description_Line] = '[Rule_Allocation_RowID] = ' + CONVERT(nvarchar(15), AR.[Rule_Allocation_RowID]) + ', [BaseRow] = ' + MAX(AR.[BaseRow]),
						[Currency_Book] = JA.[Currency_Book],
						[Value_Book] = ROUND(SUM(JA.[Value_Book] * AR.[Sign] * AR.[Factor]), 4),
						[SourceModule] = 'ALLOC',
						[SourceModuleReference] = CONVERT(nvarchar(15), @BusinessRuleID) + '_' + CONVERT(nvarchar(15), @Rule_AllocationID)
					FROM
						#JournalAlloc JA
						INNER JOIN #Allocation_Row AR ON AR.[Rule_AllocationID] = @Rule_AllocationID AND AR.[BaseRow] = JA.[BaseRow]
						LEFT JOIN #Allocation_Row_Dim_Setting ARDS ON ARDS.[Rule_AllocationID] = AR.[Rule_AllocationID] AND ARDS.[Rule_Allocation_RowID] = AR.[Rule_Allocation_RowID]
					GROUP BY
						AR.[Rule_Allocation_RowID],
						JA.[Entity], 
						JA.[Book],
						JA.[FiscalYear],
						JA.[FiscalPeriod],
						JA.[YearMonth],
						ISNULL(ARDS.[Account], JA.[Account]),
						ISNULL(ARDS.[Segment01], JA.[Segment01]),
						ISNULL(ARDS.[Segment02], JA.[Segment02]),
						ISNULL(ARDS.[Segment03], JA.[Segment03]),
						ISNULL(ARDS.[Segment04], JA.[Segment04]),
						ISNULL(ARDS.[Segment05], JA.[Segment05]),
						ISNULL(ARDS.[Segment06], JA.[Segment06]),
						ISNULL(ARDS.[Segment07], JA.[Segment07]),
						ISNULL(ARDS.[Segment08], JA.[Segment08]),
						ISNULL(ARDS.[Segment09], JA.[Segment09]),
						ISNULL(ARDS.[Segment10], JA.[Segment10]),
						ISNULL(ARDS.[Segment11], JA.[Segment11]),
						ISNULL(ARDS.[Segment12], JA.[Segment12]),
						ISNULL(ARDS.[Segment13], JA.[Segment13]),
						ISNULL(ARDS.[Segment14], JA.[Segment14]),
						ISNULL(ARDS.[Segment15], JA.[Segment15]),
						ISNULL(ARDS.[Segment16], JA.[Segment16]),
						ISNULL(ARDS.[Segment17], JA.[Segment17]),
						ISNULL(ARDS.[Segment18], JA.[Segment18]),
						ISNULL(ARDS.[Segment19], JA.[Segment19]),
						ISNULL(ARDS.[Segment20], JA.[Segment20]),
						ISNULL(ARDS.[Customer], JA.[Customer]),
						ISNULL(ARDS.[Supplier], JA.[Supplier]),
						JA.[Scenario],
						JA.[Currency_Book]
					HAVING
						ROUND(SUM(JA.[Value_Book] * AR.[Sign] * AR.[Factor]), 4) <> 0.0
					ORDER BY
						Account, [Segment01], YearMonth

					IF @DebugBM & 16 > 0 SELECT [Step] = 'After Insert rows into #JournalBase, [Rule_AllocationID] = ' + CONVERT(nvarchar(15), @Rule_AllocationID), [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
					IF @DebugBM & 8 > 0 SELECT [TempTable] = '#JournalBase', * FROM #JournalBase WHERE [SourceModuleReference] = CONVERT(nvarchar(15), @BusinessRuleID) + '_' + CONVERT(nvarchar(15), @Rule_AllocationID)

					FETCH NEXT FROM RULE_Allocation_Cursor INTO @JournalNo, @Rule_AllocationID, @Rule_AllocationName, @JournalSequence, @Source_DataClassID, @Source_DimensionFilter, @Across_DataClassID, @Across_Member, @Across_WithinDim, @Across_Basis, @Across_Member_Default, @JournalOnlyYN, @ModifierID, @Parameter, @BeginTime, @EndTime
				END

			CLOSE RULE_Allocation_Cursor
			DEALLOCATE RULE_Allocation_Cursor

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After calculating #JournalBase', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
		IF @DebugBM & 8 > 0 
			SELECT
				TempTable = '#JournalBase', *
			FROM
				#JournalBase 
			ORDER BY
				SourceModuleReference, Entity, Book, JournalNo, JournalLine, FiscalYear, FiscalPeriod, YearMonth, Account, Segment01, Segment02, Segment03, Segment04, Segment05

	SET @Step = 'Delete already existing rows from [Journal]'
		IF @SequenceBM & 2 > 0
			BEGIN
				SET @SQLStatement = '
					DELETE J
					FROM
						' + @JournalTable + ' J
						INNER JOIN (SELECT DISTINCT [SourceModuleReference] = ''' + CONVERT(nvarchar(15), @BusinessRuleID) + ''' + ''_'' + CONVERT(nvarchar(15), [RULE_AllocationID]) FROM #RULE_Allocation_Cursor_Table) RAID ON RAID.[SourceModuleReference] = J.[SourceModuleReference]
					WHERE
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						[SourceModule] = ''ALLOC''
						' + CASE WHEN @FromTime IS NOT NULL THEN 'AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END + '
						' + CASE WHEN @ToTime IS NOT NULL THEN 'AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After deleting existing rows in Journal', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
			END

	SET @Step = 'Fill Journal table'
		IF @SequenceBM & 2 > 0
			BEGIN
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
						[Scenario],
						[Customer],
						[Supplier],
						[Description_Head],
						[Description_Line],
						[Currency_Book],
						[ValueDebit_Book],
						[ValueCredit_Book],
						[SourceModule],
						[SourceModuleReference],
						[SourceCounter],
						[SourceGUID],
						[Inserted],
						[InsertedBy]
						)
					SELECT
						[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
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
						[Segment01] = ISNULL(JB.[Segment01], ''''),
						[Segment02] = ISNULL(JB.[Segment02], ''''),
						[Segment03] = ISNULL(JB.[Segment03], ''''),
						[Segment04] = ISNULL(JB.[Segment04], ''''),
						[Segment05] = ISNULL(JB.[Segment05], ''''),
						[Segment06] = ISNULL(JB.[Segment06], ''''),
						[Segment07] = ISNULL(JB.[Segment07], ''''),
						[Segment08] = ISNULL(JB.[Segment08], ''''),
						[Segment09] = ISNULL(JB.[Segment09], ''''),
						[Segment10] = ISNULL(JB.[Segment10], ''''),
						[Segment11] = ISNULL(JB.[Segment11], ''''),
						[Segment12] = ISNULL(JB.[Segment12], ''''),
						[Segment13] = ISNULL(JB.[Segment13], ''''),
						[Segment14] = ISNULL(JB.[Segment14], ''''),
						[Segment15] = ISNULL(JB.[Segment15], ''''),
						[Segment16] = ISNULL(JB.[Segment16], ''''),
						[Segment17] = ISNULL(JB.[Segment17], ''''),
						[Segment18] = ISNULL(JB.[Segment18], ''''),
						[Segment19] = ISNULL(JB.[Segment19], ''''),
						[Segment20] = ISNULL(JB.[Segment20], ''''),
						[JournalDate],
						[TransactionDate],
						[PostedDate],
						[PostedStatus],
						[PostedBy],
						[Source],
						[Scenario],
						[Customer] = ISNULL(JB.[Customer], ''''),
						[Supplier] = ISNULL(JB.[Supplier], ''''),
						[Description_Head],
						[Description_Line],
						[Currency_Book],
						[ValueDebit_Book] = CASE WHEN JB.[Value_Book] > 0 THEN JB.[Value_Book] ELSE 0 END,
						[ValueCredit_Book] = CASE WHEN JB.[Value_Book] < 0 THEN JB.[Value_Book] * -1.0 ELSE 0 END,
						[SourceModule],
						[SourceModuleReference] = JB.[SourceModuleReference],
						[SourceCounter] = NULL,
						[SourceGUID] = NULL,
						[Inserted] = GetDate(),
						[InsertedBy] = suser_name()
					FROM
						#JournalBase JB'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Inserted = @Inserted + @@ROWCOUNT

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After Insert rows into Journal', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
		END

	SET @Step = 'Fill FACT_Financials'
		IF @SequenceBM & 4 > 0
			BEGIN
				EXEC [spIU_Dim_BusinessProcess_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID=@JobID

				EXEC [spIU_DC_Financials_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @JobIDFilterYN = 1, @Debug=@DebugSub

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After Insert rows into FACT_Financials', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #RULE_Allocation_Cursor_Table
		DROP TABLE #Allocation_Row
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #JournalBase
				DROP TABLE #FilterTable
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

	SET @Step = 'Set EndTime for the actual job'
		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID
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
