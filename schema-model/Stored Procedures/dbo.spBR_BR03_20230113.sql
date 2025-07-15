SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR03_20230113]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@FromTime int = NULL,
	@ToTime int = NULL,
	@Rule_AllocationID int = NULL, --Optional parameter

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
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202001, @ToTime=202012, @Rule_AllocationID = 2001, @DebugBM=3
EXEC [spBR_BR03] @UserID=-10, @InstanceID=515, @VersionID=1064, @BusinessRuleID=2414, @FromTime=202101, @ToTime=202101, @Rule_AllocationID = 2003, @DebugBM=3

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
	--@Rule_AllocationID int,
	@Rule_Allocation_RowID int,
	@MultiDimSetting nvarchar(4000),
	@Rule_AllocationName nvarchar(50),
	@JournalSequence nvarchar(50),
	@Source_DataClassID int,
	@Source_DimensionFilter nvarchar(4000),
	@Across_DataClassID int,
	@Across_DataClassName nvarchar(50),
	@Across_Member nvarchar(4000),
	@Across_WithinDim nvarchar(4000),
	@Across_Basis nvarchar(4000),
	@ModifierID int,
	@Parameter float,
	@DimensionName nvarchar(100),
	@JournalTable nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@Comment nvarchar(255),
    @BeginTime int, 
    @EndTime int,

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
			@ProcedureDescription = 'Running business rule BR03, Allocation rules.',
			@MandatoryParameter = 'AllocationGroup' --Without @, separated by |

		IF @Version = '2.1.1.2171' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added optional parameter @Rule_AllocationID'
		IF @Version = '2.1.1.2173' SET @Description = 'Updated version of temp table #FilterTable.'
        IF @Version = '2.1.2.2191' SET @Description = 'Handle different time validity.'

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

	SET @Step = 'CREATE TABLE #JournalBase'
		IF OBJECT_ID(N'TempDB.dbo.#JournalBase', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0
				CREATE TABLE #JournalBase
					(
					[Rule_AllocationID] int,
					[BaseYN] bit,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT, 
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] int,
					[FiscalPeriod] int,
					[JournalSequence] [nvarchar](50),
					[JournalNo] [nvarchar](50),
					[JournalLine] [int],
					[YearMonth] int,
					[TransactionTypeBM] [int],
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
					[JournalDate] [date],
					[TransactionDate] [date],
					[PostedDate] [date],
					[PostedStatus] [bit],
					[PostedBy] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Description_Head] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Currency_Book] [nchar](3) COLLATE DATABASE_DEFAULT,
					[Value_Book] [float]
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

	SET @Step = 'CREATE TABLE #AcrossGroupBy'
		CREATE TABLE #AcrossGroupBy
			(
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[JournalColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[WithInYN] bit
			)

	SET @Step = 'CREATE TABLE #AcrossFilter'
		CREATE TABLE #AcrossFilter
			(
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'CREATE TABLE #RULE_Allocation_Cursor_Table'
		CREATE TABLE #RULE_Allocation_Cursor_Table
			(
			[Rule_AllocationID] int,
			[Rule_AllocationName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[JournalSequence] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Source_DataClassID] int,
			[Source_DimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[Across_DataClassID] int,
			[Across_Member] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[Across_WithinDim] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[Across_Basis] nvarchar(4000) COLLATE DATABASE_DEFAULT,
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

		IF @DebugBM & 2 > 0 SELECT TempTable = '#RULE_Allocation_Cursor_Table', * FROM #RULE_Allocation_Cursor_Table ORDER BY [SortOrder]

	SET @Step = 'Create and fill temp table #Allocation_Row'
		CREATE TABLE #Allocation_Row
			(
			[Rule_AllocationID] [int],
			[Rule_Allocation_RowID] [int],
			[MultiDimSetting] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[CrossEntityYN] bit,
			[FormulaID] int,
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
			[FormulaID],
			[Factor],
			[Sign],
			[SortOrder]
			)
		SELECT
			[Rule_AllocationID],
			[Rule_Allocation_RowID],
			[MultiDimSetting],
			[CrossEntityYN],
			[FormulaID],
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
					IF @DebugBM & 2 > 0 SELECT [@Rule_AllocationID]=@Rule_AllocationID, [@Rule_Allocation_RowID]=@Rule_Allocation_RowID, [@MultiDimSetting]=@MultiDimSetting
					
					TRUNCATE TABLE #DimensionValue

					INSERT INTO #DimensionValue
						(
						[DimensionValue]
						)
					SELECT
						[DimensionValue] = [Value]
					FROM
						STRING_SPLIT(@MultiDimSetting, '|')

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
						[Segment20]
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
						[Segment20] = MAX(CASE WHEN JSN.SegmentNo = 20 THEN SUBSTRING(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])+1, LEN(DV.[DimensionValue])) END)
					FROM
						#DimensionValue DV
						INNER JOIN pcINTEGRATOR..Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = LEFT(DV.[DimensionValue], CHARINDEX ('=', DV.[DimensionValue])-1)
						INNER JOIN pcINTEGRATOR_Data..Journal_SegmentNo JSN ON JSN.InstanceID = @InstanceID AND JSN.VersionID = @VersionID AND JSN.DimensionID = D.DimensionID
					
					FETCH NEXT FROM MultiDimSetting_Cursor INTO @Rule_AllocationID, @Rule_Allocation_RowID, @MultiDimSetting
				END

		CLOSE MultiDimSetting_Cursor
		DEALLOCATE MultiDimSetting_Cursor

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Allocation_Row_Dim_Setting', * FROM #Allocation_Row_Dim_Setting ORDER BY [Rule_AllocationID], [Rule_Allocation_RowID]

	SET @Step = 'Run RULE_Allocation_Cursor'
		IF CURSOR_STATUS('global','RULE_Allocation_Cursor') >= -1 DEALLOCATE RULE_Allocation_Cursor
		DECLARE RULE_Allocation_Cursor CURSOR FOR
			SELECT 
				[Rule_AllocationID],
				[Rule_AllocationName],
				[JournalSequence],
				[Source_DataClassID],
				[Source_DimensionFilter],
				[Across_DataClassID],
				[Across_Member],
				[Across_WithinDim],
				[Across_Basis],
				[ModifierID],
				[Parameter],
                [BeginTime] = [StartTime],
                [EndTime]
			FROM
				#RULE_Allocation_Cursor_Table
			ORDER BY
				[SortOrder]

			OPEN RULE_Allocation_Cursor
			FETCH NEXT FROM RULE_Allocation_Cursor INTO @Rule_AllocationID, @Rule_AllocationName, @JournalSequence, @Source_DataClassID, @Source_DimensionFilter, @Across_DataClassID, @Across_Member, @Across_WithinDim, @Across_Basis, @ModifierID, @Parameter, @BeginTime, @EndTime

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@Rule_AllocationID] = @Rule_AllocationID, [@Rule_AllocationName] = @Rule_AllocationName, [@JournalSequence] = @JournalSequence, [@Source_DataClassID] = @Source_DataClassID, [@Source_DimensionFilter] = @Source_DimensionFilter, [@Across_DataClassID] = @Across_DataClassID, [@Across_Member] = @Across_Member, [@Across_WithinDim] = @Across_WithinDim, [@Across_Basis] = @Across_Basis, [@ModifierID] = @ModifierID, [@Parameter] = @Parameter, [@BeginTime] = @BeginTime, [@EndTime] = @EndTime

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
							[@Rule_AllocationID]=@Rule_AllocationID,
							[@Rule_AllocationName]=@Rule_AllocationName,
							[@JournalSequence]=@JournalSequence,
							[@Source_DataClassID] = @Source_DataClassID,
							[@Source_DimensionFilter] = @Source_DimensionFilter,
							[@Across_DataClassID] = @Across_DataClassID,
							[@Across_DataClassName] = @Across_DataClassName,
							[@Across_Member] = @Across_Member,
							[@Across_WithinDim] = @Across_WithinDim,
							[@Across_Basis] = @Across_Basis,
							[@ModifierID] = @ModifierID,
							[@Parameter] = @Parameter

					--Set @Source_DimensionFilter'
					IF LEN(@Source_DimensionFilter) > 0
						BEGIN
							TRUNCATE TABLE #FilterTable
							SELECT @Source_DimensionFilter_LeafLevel = '', @PropertyFilter = ''
											
							EXEC pcINTEGRATOR..spGet_FilterTable
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepReference = 'BR03_01',
								@PipeString = @Source_DimensionFilter,
								@StorageTypeBM_DataClass = 1, --@StorageTypeBM_DataClass,
								@StorageTypeBM = 4, --@StorageTypeBM,
								@Debug = @DebugSub

							SELECT
								@Source_DimensionFilter_LeafLevel = @Source_DimensionFilter_LeafLevel + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'J.[' + [JournalColumn] + '] IN (' + [LeafLevelFilter] + ') AND'
							FROM
								#FilterTable
							WHERE
								[StepReference] = 'BR03_01' AND
								[LeafLevelFilter] IS NOT NULL

							SELECT
								@PropertyFilter = @PropertyFilter + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + REPLACE(FT.[PropertyFilter], '= V.[' + FT.[DimensionName] + ']', '= J.[' + FT.[JournalColumn] + ']')
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
								END
						END

					--Set Across Properties'
					IF @Across_DataClassID IS NOT NULL
						BEGIN
							--@Across_DataClassID
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

							--@Across_Member
							--TRUNCATE TABLE #FilterTable
											
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
							SELECT DISTINCT
								[DimensionName],
								[WithInYN] = 0
							FROM
								#FilterTable

							INSERT INTO #AcrossFilter
								(
								[DimensionName],
								[LeafLevelFilter]
								)
							SELECT
								[DimensionName],
								[LeafLevelFilter]
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
SELECT 'Arne0'
							--@Across_WithinDim
							--TRUNCATE TABLE #FilterTable
											
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

							IF @DebugBM & 2 > 0 
								BEGIN
									SELECT TempTable = '#FilterTable', [Phase] = '@Across_WithinDim', * FROM #FilterTable WHERE [StepReference] = 'BR03_03'
									SELECT TempTable = '#AcrossGroupBy', [Phase] = '@Across_WithinDim', * FROM #AcrossGroupBy
								END

							--@Across_Basis
							--TRUNCATE TABLE #FilterTable
											
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
								[LeafLevelFilter]
								)
							SELECT
								[DimensionName],
								[LeafLevelFilter]
							FROM
								#FilterTable
							WHERE
								[StepReference] = 'BR03_04'

							IF @DebugBM & 2 > 0 
								BEGIN
									SELECT TempTable = '#FilterTable', [Phase] = '@Across_Basis', * FROM #FilterTable WHERE [StepReference] = 'BR03_04'
									SELECT TempTable = '#AcrossFilter', [Phase] = '@Across_Basis', * FROM #AcrossFilter
								END
SELECT 'Arne01'
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
								SELECT DISTINCT
									[DimensionName]
								FROM
									#AcrossGroupBy
								--WHERE
								--	[WithInYN] <> 0
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
SELECT 'Arne10'
							IF @DebugBM & 2 > 0 SELECT [TempTable:#AllocateAcross]= '#AllocateAcross', * FROM #AllocateAcross

SELECT 'Arne11'
							SELECT DISTINCT
								DimensionName
							FROM
								#AcrossGroupBy
							--WHERE
							--	[WithInYN] <> 0
							--ORDER BY
							--	DimensionName

							SELECT 
								@SQLInsert = '',
								@SQLSelect = '',
								@SQLJoin = '',
								@SQLGroupBy = '',
								@SQLWhere = ''

							SELECT
								@SQLInsert = @SQLInsert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [DimensionName] + '],',
								@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [DimensionName] + '] = MAX([' + [DimensionName] + '].[Label]),',
								@SQLJoin = @SQLJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + [DimensionName] + '] [' + [DimensionName] + '] ON [' + [DimensionName] + '].[MemberId] = AA.[' + [DimensionName] + '_MemberId]',
								@SQLGroupBy = @SQLGroupBy + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [DimensionName] + '_MemberId],'
							FROM
								(
								SELECT DISTINCT
									DimensionName
								FROM
									#AcrossGroupBy
								) sub
							--WHERE
							--	[WithInYN] <> 0
							--ORDER BY
							--	DimensionName

							SELECT 
								@SQLWhere = @SQLWhere + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [DimensionName] + '_MemberID] IN (' + [LeafLevelFilter] + ') AND'
							FROM
								#AcrossFilter
							ORDER BY
								DimensionName

							SELECT
								@SQLWhere = LEFT(@SQLWhere, LEN(@SQLWhere) - 3),
								@SQLGroupBy = LEFT(@SQLGroupBy, LEN(@SQLGroupBy) - 1)

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
								WHERE' + @SQLWhere + '
									' + CASE WHEN @FromTime IS NOT NULL THEN 'AND AA.Time_MemberId >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END + '
									' + CASE WHEN @ToTime IS NOT NULL THEN 'AND AA.Time_MemberId <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END + '
								GROUP BY' + @SQLGroupBy

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							IF @DebugBM & 2 > 0 SELECT [TempTable:#AllocateAcross] = '#AllocateAcross', * FROM #AllocateAcross

							
							SELECT
								@SQLJoin = '',
								@SQLGroupBy = ''
							
							SELECT DISTINCT
								@SQLJoin = @SQLJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ' sub.[' + [DimensionName] + '] = AA.[' + [DimensionName] + '] AND',
								@SQLGroupBy = @SQLGroupBy + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [DimensionName] + '],'
							FROM
								#AcrossGroupBy
							--WHERE
							--	[WithInYN] <> 0
							--ORDER BY
							--	DimensionName

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
							IF @DebugBM & 2 > 0 SELECT [TempTable:#AllocateAcross] = '#AllocateAcross', * FROM #AllocateAcross
						END

					IF @DebugBM & 2 > 0
						SELECT
							[@Rule_AllocationID] = @Rule_AllocationID,
							[@JournalTable] = @JournalTable,
							[@InstanceID] = @InstanceID,
							[@Source_DimensionFilter_LeafLevel] = @Source_DimensionFilter_LeafLevel,
							[@FromTime] = @FromTime,
							[@ToTime] = @ToTime

					SET @SQLStatement = '
						INSERT INTO #JournalBase
							(
							[Rule_AllocationID],
							[BaseYN],
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
							[Scenario],
							[Currency_Book],
							[Value_Book]
							)'

					SET @SQLStatement = @SQLStatement + '
						SELECT
							[Rule_AllocationID] = ' + CONVERT(nvarchar(15), @Rule_AllocationID) + ',
							[BaseYN] = 1,
							[Entity],
							[Book],
							[FiscalYear],
							[FiscalPeriod],
							[YearMonth],
							[BalanceYN] = MAX(CONVERT(int, J.[BalanceYN])),
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
							[Scenario],
							[Currency_Book],
							[Value_Book] = ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4)'

					SET @SQLStatement = @SQLStatement + '
						FROM
							' + @JournalTable + ' J
							' + ISNULL(@PropertyFilter, '') + '
						WHERE
							J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							J.[TransactionTypeBM] & 3 > 0' + CASE WHEN @Source_DimensionFilter_LeafLevel IS NOT NULL THEN ' AND ' + @Source_DimensionFilter_LeafLevel ELSE '' END + '
							' + CASE WHEN @FromTime IS NOT NULL THEN 'AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END + '
							' + CASE WHEN @ToTime IS NOT NULL THEN 'AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END

					SET @SQLStatement = @SQLStatement + '
						GROUP BY
							[Entity],
							[Book],
							[FiscalYear],
							[FiscalPeriod],
							[YearMonth],
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
							[Scenario],
							[Currency_Book]
						HAVING
							ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4) <> 0.0'

					IF @DebugBM & 2 > 0 
						BEGIN
							IF LEN(@SQLStatement) > 4000 
								BEGIN
									PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; BR03, Insert into #JournalBase; @Rule_AllocationID = ' + CONVERT(nvarchar(15), @Rule_AllocationID) + '.'
									SET @Comment = 'BR03, Insert into #JournalBase; @Rule_AllocationID = ' + CONVERT(nvarchar(15), @Rule_AllocationID)
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
					IF @DebugBM & 2 > 0 
						BEGIN
							SELECT TempTable = '#Allocation_Row', * FROM #Allocation_Row WHERE [Rule_AllocationID] = @Rule_AllocationID
							SELECT TempTable = '#Allocation_Row_Dim_Setting', * FROM #Allocation_Row_Dim_Setting WHERE [Rule_AllocationID] = @Rule_AllocationID
							SELECT TempTable = '#JournalBase', * FROM #JournalBase WHERE [BaseYN] <> 0 AND [Rule_AllocationID] = @Rule_AllocationID ORDER BY YearMonth, Account, Segment01, Segment02, Segment03
						END

					IF @Across_DataClassID IS NULL
						BEGIN
							INSERT INTO #JournalBase
								(
								[Rule_AllocationID],
								[BaseYN],
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
								[Scenario],
								[Description_Head],
								[Description_Line],
								[Currency_Book],
								[Value_Book]
								)
							SELECT
								[Rule_AllocationID] = @Rule_AllocationID,
								[BaseYN] = 0,
								[Entity] = JB.[Entity], 
								[Book] = JB.[Book],
								[FiscalYear] = JB.[FiscalYear],
								[FiscalPeriod] = JB.[FiscalPeriod],
								[JournalSequence] = @JournalSequence,
								[JournalNo] = '1',
								[JournalLine] = AR.[Rule_Allocation_RowID],
								[YearMonth] = JB.[YearMonth],
								[BalanceYN] = MAX(CONVERT(int, JB.[BalanceYN])),
								[Account] = ISNULL(ARDS.[Account], JB.[Account]),
								[Segment01] = ISNULL(ARDS.[Segment01], JB.[Segment01]),
								[Segment02] = ISNULL(ARDS.[Segment02], JB.[Segment02]),
								[Segment03] = ISNULL(ARDS.[Segment03], JB.[Segment03]),
								[Segment04] = ISNULL(ARDS.[Segment04], JB.[Segment04]),
								[Segment05] = ISNULL(ARDS.[Segment05], JB.[Segment05]),
								[Segment06] = ISNULL(ARDS.[Segment06], JB.[Segment06]),
								[Segment07] = ISNULL(ARDS.[Segment07], JB.[Segment07]),
								[Segment08] = ISNULL(ARDS.[Segment08], JB.[Segment08]),
								[Segment09] = ISNULL(ARDS.[Segment09], JB.[Segment09]),
								[Segment10] = ISNULL(ARDS.[Segment10], JB.[Segment10]),
								[Segment11] = ISNULL(ARDS.[Segment11], JB.[Segment11]),
								[Segment12] = ISNULL(ARDS.[Segment12], JB.[Segment12]),
								[Segment13] = ISNULL(ARDS.[Segment13], JB.[Segment13]),
								[Segment14] = ISNULL(ARDS.[Segment14], JB.[Segment14]),
								[Segment15] = ISNULL(ARDS.[Segment15], JB.[Segment15]),
								[Segment16] = ISNULL(ARDS.[Segment16], JB.[Segment16]),
								[Segment17] = ISNULL(ARDS.[Segment17], JB.[Segment17]),
								[Segment18] = ISNULL(ARDS.[Segment18], JB.[Segment18]),
								[Segment19] = ISNULL(ARDS.[Segment19], JB.[Segment19]),
								[Segment20] = ISNULL(ARDS.[Segment20], JB.[Segment20]),
								[Scenario] = JB.[Scenario],
								[Description_Head] = '[Rule_AllocationName] = ' + @Rule_AllocationName,
								[Description_Line] = '[Rule_Allocation_RowID] = ' + CONVERT(nvarchar(15), AR.[Rule_Allocation_RowID]),
								[Currency_Book] = JB.[Currency_Book],
								[Value_Book] = ROUND(SUM(AR.[Sign] * JB.[Value_Book] * AR.[Factor]), 4)
							FROM
								#JournalBase JB
								INNER JOIN #Allocation_Row AR ON AR.[Rule_AllocationID] = JB.[Rule_AllocationID]
								LEFT JOIN #Allocation_Row_Dim_Setting ARDS ON ARDS.[Rule_AllocationID] = AR.[Rule_AllocationID] AND ARDS.[Rule_Allocation_RowID] = AR.[Rule_Allocation_RowID]
							WHERE
								JB.[Rule_AllocationID] = @Rule_AllocationID AND
								JB.[BaseYN] <> 0
							GROUP BY
								JB.[Entity], 
								JB.[Book],
								JB.[FiscalYear],
								JB.[FiscalPeriod],
								JB.[YearMonth],
								ISNULL(ARDS.[Account], JB.[Account]),
								ISNULL(ARDS.[Segment01], JB.[Segment01]),
								ISNULL(ARDS.[Segment02], JB.[Segment02]),
								ISNULL(ARDS.[Segment03], JB.[Segment03]),
								ISNULL(ARDS.[Segment04], JB.[Segment04]),
								ISNULL(ARDS.[Segment05], JB.[Segment05]),
								ISNULL(ARDS.[Segment06], JB.[Segment06]),
								ISNULL(ARDS.[Segment07], JB.[Segment07]),
								ISNULL(ARDS.[Segment08], JB.[Segment08]),
								ISNULL(ARDS.[Segment09], JB.[Segment09]),
								ISNULL(ARDS.[Segment10], JB.[Segment10]),
								ISNULL(ARDS.[Segment11], JB.[Segment11]),
								ISNULL(ARDS.[Segment12], JB.[Segment12]),
								ISNULL(ARDS.[Segment13], JB.[Segment13]),
								ISNULL(ARDS.[Segment14], JB.[Segment14]),
								ISNULL(ARDS.[Segment15], JB.[Segment15]),
								ISNULL(ARDS.[Segment16], JB.[Segment16]),
								ISNULL(ARDS.[Segment17], JB.[Segment17]),
								ISNULL(ARDS.[Segment18], JB.[Segment18]),
								ISNULL(ARDS.[Segment19], JB.[Segment19]),
								ISNULL(ARDS.[Segment20], JB.[Segment20]),
								JB.[Scenario],
								JB.[Currency_Book],
								AR.[Rule_Allocation_RowID]
							HAVING
								ROUND(SUM(AR.[Sign] * JB.[Value_Book] * AR.[Factor]), 4) <> 0.0
						END
					ELSE
						BEGIN
							UPDATE AGB
							SET
								[JournalColumn] = CASE WHEN D.DimensionTypeID = -1 THEN 'Segment' + CASE WHEN JSN.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.SegmentNo) ELSE REPLACE(AGB.[DimensionName], 'Time', 'YearMonth') END
							FROM
								#AcrossGroupBy AGB
								INNER JOIN pcINTEGRATOR..Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = AGB.DimensionName
								LEFT JOIN pcINTEGRATOR_Data..Journal_SegmentNo JSN ON JSN.InstanceID = @InstanceID AND JSN.VersionID = @VersionID AND JSN.DimensionID = D.DimensionID

							IF @DebugBM & 2 > 0 SELECT TempTable = '#AcrossGroupBy', * FROM #AcrossGroupBy
							
							SET @SQLJoin = ''
							
							SELECT
								@SQLJoin = @SQLJoin + ' AA.[' + [DimensionName] + '] = JB.[' + [JournalColumn] + '] AND'
							FROM
								#AcrossGroupBy
							WHERE
								[WithInYN] <> 0
							ORDER BY
								DimensionName

							SELECT
								@SQLJoin = LEFT(@SQLJoin, LEN(@SQLJoin) - 3)

							IF @DebugBM & 2 > 0 SELECT [@SQLJoin] = @SQLJoin

							SET @SQLStatement = '
								INSERT INTO #JournalBase
									(
									[Rule_AllocationID],
									[BaseYN],
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
									[Scenario],
									[Description_Head],
									[Description_Line],
									[Currency_Book],
									[Value_Book]
									)'

							SET @SQLStatement = @SQLStatement + '
								SELECT
									[Rule_AllocationID] = ' + CONVERT(nvarchar(15), @Rule_AllocationID) + ',
									[BaseYN] = 0,
									[Entity] = JB.[Entity], 
									[Book] = JB.[Book],
									[FiscalYear] = JB.[FiscalYear],
									[FiscalPeriod] = JB.[FiscalPeriod],
									[JournalSequence] = ''' + @JournalSequence + ''',
									[JournalNo] = ''1'',
									[JournalLine] = AR.[Rule_Allocation_RowID],
									[YearMonth] = JB.[YearMonth],
									[BalanceYN] = MAX(CONVERT(int, JB.[BalanceYN])),
									[Account] = ISNULL(ARDS.[Account], JB.[Account]),
									[Segment01] = ISNULL(ARDS.[Segment01], JB.[Segment01]),
									[Segment02] = ISNULL(ARDS.[Segment02], JB.[Segment02]),
									[Segment03] = ISNULL(ARDS.[Segment03], JB.[Segment03]),
									[Segment04] = ISNULL(ARDS.[Segment04], JB.[Segment04]),
									[Segment05] = ISNULL(ARDS.[Segment05], JB.[Segment05]),
									[Segment06] = ISNULL(ARDS.[Segment06], JB.[Segment06]),
									[Segment07] = ISNULL(ARDS.[Segment07], JB.[Segment07]),
									[Segment08] = ISNULL(ARDS.[Segment08], JB.[Segment08]),
									[Segment09] = ISNULL(ARDS.[Segment09], JB.[Segment09]),
									[Segment10] = ISNULL(ARDS.[Segment10], JB.[Segment10]),
									[Segment11] = ISNULL(ARDS.[Segment11], JB.[Segment11]),
									[Segment12] = ISNULL(ARDS.[Segment12], JB.[Segment12]),
									[Segment13] = ISNULL(ARDS.[Segment13], JB.[Segment13]),
									[Segment14] = ISNULL(ARDS.[Segment14], JB.[Segment14]),
									[Segment15] = ISNULL(ARDS.[Segment15], JB.[Segment15]),
									[Segment16] = ISNULL(ARDS.[Segment16], JB.[Segment16]),
									[Segment17] = ISNULL(ARDS.[Segment17], JB.[Segment17]),
									[Segment18] = ISNULL(ARDS.[Segment18], JB.[Segment18]),
									[Segment19] = ISNULL(ARDS.[Segment19], JB.[Segment19]),
									[Segment20] = ISNULL(ARDS.[Segment20], JB.[Segment20]),
									[Scenario] = JB.[Scenario],
									[Description_Head] = ''[Rule_AllocationName] = ' + @Rule_AllocationName + ''',
									[Description_Line] = ''[Rule_Allocation_RowID] = '' + CONVERT(nvarchar(15), AR.[Rule_Allocation_RowID]),
									[Currency_Book] = JB.[Currency_Book],
									[Value_Book] = ROUND(SUM(AR.[Sign] * JB.[Value_Book] * AR.[Factor] * AA.[Value]), 4)'

							SET @SQLStatement = @SQLStatement + '
								FROM
									#JournalBase JB
									INNER JOIN #Allocation_Row AR ON AR.[Rule_AllocationID] = JB.[Rule_AllocationID]
									INNER JOIN #AllocateAcross AA ON' + @SQLJoin + '
									LEFT JOIN #Allocation_Row_Dim_Setting ARDS ON ARDS.[Rule_AllocationID] = AR.[Rule_AllocationID] AND ARDS.[Rule_Allocation_RowID] = AR.[Rule_Allocation_RowID]
								WHERE
									JB.[Rule_AllocationID] = ' + CONVERT(nvarchar(15), @Rule_AllocationID) + ' AND
									JB.[BaseYN] <> 0
								GROUP BY
									JB.[Entity], 
									JB.[Book],
									JB.[FiscalYear],
									JB.[FiscalPeriod],
									JB.[YearMonth],
									ISNULL(ARDS.[Account], JB.[Account]),
									ISNULL(ARDS.[Segment01], JB.[Segment01]),
									ISNULL(ARDS.[Segment02], JB.[Segment02]),
									ISNULL(ARDS.[Segment03], JB.[Segment03]),
									ISNULL(ARDS.[Segment04], JB.[Segment04]),
									ISNULL(ARDS.[Segment05], JB.[Segment05]),
									ISNULL(ARDS.[Segment06], JB.[Segment06]),
									ISNULL(ARDS.[Segment07], JB.[Segment07]),
									ISNULL(ARDS.[Segment08], JB.[Segment08]),
									ISNULL(ARDS.[Segment09], JB.[Segment09]),
									ISNULL(ARDS.[Segment10], JB.[Segment10]),
									ISNULL(ARDS.[Segment11], JB.[Segment11]),
									ISNULL(ARDS.[Segment12], JB.[Segment12]),
									ISNULL(ARDS.[Segment13], JB.[Segment13]),
									ISNULL(ARDS.[Segment14], JB.[Segment14]),
									ISNULL(ARDS.[Segment15], JB.[Segment15]),
									ISNULL(ARDS.[Segment16], JB.[Segment16]),
									ISNULL(ARDS.[Segment17], JB.[Segment17]),
									ISNULL(ARDS.[Segment18], JB.[Segment18]),
									ISNULL(ARDS.[Segment19], JB.[Segment19]),
									ISNULL(ARDS.[Segment20], JB.[Segment20]),
									JB.[Scenario],
									JB.[Currency_Book],
									AR.[Rule_Allocation_RowID]
								HAVING
									ROUND(SUM(AR.[Sign] * JB.[Value_Book] * AR.[Factor]), 4) <> 0.0'
									
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

					IF @DebugBM & 2 > 0 SELECT TempTable = '#JournalBase', * FROM #JournalBase WHERE [BaseYN] = 0 AND [Rule_AllocationID] = @Rule_AllocationID ORDER BY YearMonth, Account, Segment01, Segment02, Segment03
					IF @DebugBM & 16 > 0 SELECT [Step] = 'After Insert rows into #JournalBase for [Rule_AllocationID] = ' + CONVERT(nvarchar(15), @Rule_AllocationID), [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
					
					FETCH NEXT FROM RULE_Allocation_Cursor INTO @Rule_AllocationID, @Rule_AllocationName, @JournalSequence, @Source_DataClassID, @Source_DimensionFilter, @Across_DataClassID, @Across_Member, @Across_WithinDim, @Across_Basis, @ModifierID, @Parameter, @BeginTime, @EndTime
				END

			CLOSE RULE_Allocation_Cursor
			DEALLOCATE RULE_Allocation_Cursor

		IF @DebugBM & 8 > 0 
			SELECT
				TempTable = '#JournalBase', *
			FROM
				#JournalBase 
			WHERE
				[BaseYN] = 0
			ORDER BY
				Rule_AllocationID, Entity, Book, JournalNo, JournalLine, FiscalYear, FiscalPeriod, YearMonth, Account, Segment01, Segment02, Segment03, Segment04, Segment05

RETURN

	SET @Step = 'Delete already existing rows from [Journal]'
		SET @SQLStatement = '
			DELETE J
			FROM
				' + @JournalTable + ' J
			WHERE
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				[SourceModule] = ''ALLOC'' AND
				[SourceModuleReference] = ''' + CONVERT(nvarchar(15), @BusinessRuleID) + '''
				' + CASE WHEN @FromTime IS NOT NULL THEN 'AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END + '
				' + CASE WHEN @ToTime IS NOT NULL THEN 'AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Fill Journal table'
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
				[TransactionTypeBM] = 2,
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
				[PostedDate] = GetDate(),
				[PostedStatus] = 1,
				[PostedBy] = ''' + @UserName + ''',
				[Source] = ''ALLOC'',
				[Scenario],
				[Customer] = NULL,
				[Supplier] = NULL,
				[Description_Head],
				[Description_Line],
				[Currency_Book],
				[ValueDebit_Book] = CASE WHEN [Value_Book] > 0 THEN [Value_Book] ELSE 0 END,
				[ValueCredit_Book] = CASE WHEN [Value_Book] < 0 THEN [Value_Book] * -1.0 ELSE 0 END,
				[SourceModule] = ''ALLOC'',
				[SourceModuleReference] = ' + CONVERT(nvarchar(15), @BusinessRuleID) + ',
				[SourceCounter] = NULL,
				[SourceGUID] = NULL,
				[Inserted] = GetDate(),
				[InsertedBy] = suser_name()
			FROM
				#JournalBase
			WHERE
				[BaseYN] = 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After Insert rows into Journal', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Fill FACT_Financials'
--		IF @SequenceBM & 48 = 48
--			BEGIN
				EXEC [spIU_Dim_BusinessProcess_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID=@JobID

				EXEC [spIU_DC_Financials_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @Debug=@DebugSub

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After Insert rows into FACT_Financials', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
--			END

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
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
