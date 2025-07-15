SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spPortalGet_DataClass_Data_20240530_nehatest]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@DataClassID INT = NULL,
	@CallistoDatabase NVARCHAR(100) = NULL,
	@Filter NVARCHAR(MAX) = NULL,
	@ResultTypeBM INT = NULL, --1 = Filter, 2 = Filter rows, 4 = Data - Leaf level, 8 = Changeable, 16 = Last Actor UserID, 32 = LineItem, 64 = Comment, 128=Add column LineItemYN to ResultTypeBM = 4, 256=List definition, 512=Hierarchy

	@GroupBy NVARCHAR(1024) = NULL,
	@Measure NVARCHAR(1024) = NULL,
	@Tuple NVARCHAR(MAX) = NULL,
	@RowList NVARCHAR(MAX) = NULL, --Only valid for @ResultTypeBM=4, 8, 256 and 512

/* Separators:
	#Tuple = ObjectReference, (TupleName)
	Semicolon ; (59) = Separator between different tuples
	Pipe | (124) = Separator between different objects
	Dot . (46) = After dot, reference to property
	Colon : (58) = After colon, reference to hierarchy, if numeric reference to HierarchyNo, else to HierarchyName
	Comma , (44) = Separator between different filter members of same object type
*/

	@PropertyList NVARCHAR(1024) = NULL,
	@DimensionList NVARCHAR(1024) = NULL,
	@Hierarchy NVARCHAR(1024) = NULL, --Only for backwards compatibility (not valid for tuples). Use colon in filterstring.
	@FilterLevel64 NVARCHAR(3) = NULL, --Valid for ResultTypeBM = 64 and 128; L=LeafLevel, P=Parent, LF=LevelFilter (not up or down), LLF=LevelFilter + all members below
	@OnlyDataClassDimMembersYN BIT = 1, --Valid for @ResultTypeBM = 2
	@Parent_MemberKey NVARCHAR(1024) = NULL, --Valid for @ResultTypeBM = 2, Sample: 'GL_Student_ID=All_' Separator=|

	@ActingAs INT = NULL, --Optional (OrganizationPositionID)
	@AssignmentID INT = NULL,
	@WorkFlowStateID INT = NULL,
	@OnlySecuredDimYN BIT = 0,
	@ShowAllMembersYN BIT = 0,
	@UseCacheYN BIT = 1,
	@FilterType NVARCHAR(10) = 'MemberKey',

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000209,
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

EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DataClass_Data_20240530_nehatest] @DebugBM=15, @DataClassID=N'6287',@Filter=N'Account=SalesAmount_|Scenario=ACTUAL|Time=2024'
,@GroupBy=N'TimeDay.TimeMonth',@InstanceID=N'741',@Measure=N'Sales',@ResultTypeBM=N'4',@UseCacheYN=N'true',@UserID=N'31099',@VersionID=N'1169'


*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement NVARCHAR(MAX),
	@DataClassName NVARCHAR(100),
	@DimensionID INT,
	@DimensionName NVARCHAR(100),
	@HierarchyName NVARCHAR(100),
	@EqualityString NVARCHAR(10),
	@LeafLevelFilter NVARCHAR(MAX),
	@MultiDimFilter NVARCHAR(MAX) = '',
	@StepReference NVARCHAR(20) = 'GetData',
	@SQLScript_Result NVARCHAR(MAX),
	@SQL_Select1_DECLARE NVARCHAR(1000) = '',
	@SQL_Select1_INSERT NVARCHAR(1000) = '',
	@SQL_Select1 NVARCHAR(1000) = '',
	@SQL_Select2 NVARCHAR(1000) = '',
	@SQL_Select64 NVARCHAR(1000) = '',
	@SQL_Join2 NVARCHAR(2000) = '',
	@SQL_Join64 NVARCHAR(2000) = '',
	@SQL_Join_RLC NVARCHAR(4000) = '',
	@SQL_GroupBy1 NVARCHAR(1000) = '',
	@SQL_GroupBy2 NVARCHAR(1000) = '',
	@SQL_GroupBy64 NVARCHAR(1000) = '',
	@SQL_Where NVARCHAR(MAX) = '',
	@SQL_Where_Tuple NVARCHAR(MAX) = '',
	@SQL_Where_Total NVARCHAR(MAX) = '',
	@SQL_Where_160 NVARCHAR(MAX) = '',
	@SQL_Where_64 NVARCHAR(MAX) = '',
	@SQL_MultiDimInsert NVARCHAR(1000) = '',
	@SQL_MultiDimSelect NVARCHAR(1000) = '',
	@SQL_MultiDimJoin NVARCHAR(4000) = '',
	@SQL_Tuple NVARCHAR(MAX) = '',
	@MultiDim_Leaf_MemberId_csv NVARCHAR(MAX) = NULL,
	@MultiDimIncludedYN BIT,

	@SQLSelect32 NVARCHAR(2000) = '',
	@SQLSelect32_LIT NVARCHAR(2000) = '',
	@SQLSelect32_S NVARCHAR(2000) = '',
	@SQLSelect32_DC NVARCHAR(2000) = '',
	@SQLSelect32_Sub NVARCHAR(2000) = '',
	@SQLSelect64 NVARCHAR(2000) = '',
	@SQLSelect128 NVARCHAR(2000) = '',
	@SQLJoin_LIT NVARCHAR(2000) = '',
	@SQLJoin_T NVARCHAR(2000) = '',
	@SQLJoin_128 NVARCHAR(2000) = '',
	@SQLGroupBy32_LIT NVARCHAR(2000) = '',
	@SQLJoin32_Sub NVARCHAR(2000) = '',
	@SQLJoin32_Callisto NVARCHAR(4000) = '',
	@LineItemBP BIGINT = 118,
	@LineItemExistsYN BIT,
	@TextTableExistsYN BIT,
	@TmpGlobalTable VARCHAR(100) = '[##DC_' + CONVERT(VARCHAR(36),NEWID()) +']',
	@TmpGlobalTable_2 VARCHAR(100) = '[##DC_' + CONVERT(VARCHAR(36),NEWID()) +'_2]',
	@TmpGlobalTable_32 VARCHAR(100) = '[##DC_' + CONVERT(VARCHAR(36),NEWID()) +'_32]',
	@TmpGlobalTable_128 VARCHAR(100) = '[##DC_' + CONVERT(VARCHAR(36),NEWID()) +'_128]',
	@TmpGlobalTable_Text VARCHAR(100) = '[##DC_' + CONVERT(VARCHAR(36),NEWID()) +'_Text]',
	@TupleNo INT,
	@TupleName NVARCHAR(100),
	@YearMonthColumn NVARCHAR(100),
	@MultiDimYN BIT = 0,
	@PipeString NVARCHAR(MAX),
	@TimeFilter NVARCHAR(MAX),
	@TimeFilterTuple NVARCHAR(MAX),
	@TimeFilterTupleString NVARCHAR(MAX),
	@TimeFilterString NVARCHAR(MAX),
	@TimeProperty NVARCHAR(50),
	@MinRowOrder INT,
	@MinTimeMemberId BIGINT,
	@TimePresentation NVARCHAR(1000),
	@TimePropertyName NVARCHAR(50),
	@DimensionTypeID INT,
	@StorageTypeBM INT,
	@PropertyName NVARCHAR(100),
	@RowListMemberKey NVARCHAR(100),
	@SortOrder INT,
	@HierarchyDimension NVARCHAR(100),
	@HierarchyHierarchy NVARCHAR(100),
	@HierarchyTopMember NVARCHAR(100),
	@HierarchyTopMemberId BIGINT,

	@RowList_DimensionID INT,
	@RowList_SupressZeroYN BIT = 1,
	@RowList_ShowLevel INT = 0, --0 shows all levels, otherwise show down to selected level
	@RowList_ExcludeStartNodeYN BIT = 0,
	@RowList_ExcludeSumMemberYN BIT = 0,
	@RowList_ParentSorting NVARCHAR(10) = 'Before', --'Before', 'After'

	@MemberId BIGINT,
	@Level INT,
	@AggregationSet NVARCHAR(MAX) = '',
	@AggregationSum NVARCHAR(MAX) = '',
	@SupressZeroString NVARCHAR(4000) = '',

	@CategoryYN BIT = 0,
	@LoopNo INT = 0,
	@TimeDimensionTypeID INT,
	@WorkflowStateYN BIT,
	@TimeView NVARCHAR(20),
	@TimeTableYN BIT,

	@MeasureName NVARCHAR(100),
	@SQLMeasureList_8 NVARCHAR(MAX) = '',
	@DataClassTypeID INT,
	@StorageTypeBM_DataClass INT,
	@AddScenarioYN BIT,
	@TimeType NVARCHAR(10),

	@PropertyNameFilter NVARCHAR(100),
	@PropertyNameGroupBy NVARCHAR(100),
	@FilterLevel NVARCHAR(2),
	@GroupByYN BIT,
	@GroupByLeafLevelYN BIT,

	@TableObject NVARCHAR(100),
	@InputAllowedYN BIT = 0,
    @MissingItems_OUT NVARCHAR(1000) = NULL,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@InfoMessage NVARCHAR(1000),
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
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return data for reports in different formats.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2179' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2180' SET @Description = 'Implement parameter @Tuple.'
		IF @Version = '2.1.2.2181' SET @Description = 'Implement readaccess'
		IF @Version = '2.1.2.2182' SET @Description = 'Modify query for setting [WorkflowStateID] in @ResultTypeBM 4. Handle Lineitem.'
		IF @Version = '2.1.2.2183' SET @Description = 'Modified handling of DimensionID -77 in ResultTypeBM=2. Added @SQL_Join2 when inserting into @TmpGlobalTable_2 in ResultTypeBM = 512.'
		IF @Version = '2.1.2.2187' SET @Description = 'Handle @ResultTypeBM=8 and other bugfixes. Improved handling of TimeDay. Fixed bug regarding WorkflowState in ResultTypeBM=8.'
		IF @Version = '2.1.2.2189' SET @Description = 'ResultTypeBM = 128 handled.'
		IF @Version = '2.1.2.2190' SET @Description = 'EA-2983: Exclude DimensionTypeID 27 in @ResultTypeBM = 64. EA-1249: Modified Time reference to [Time_MemberId] in @ResultTypeBM = 512. EA-3071: Added @LineItemExistsYN and @TextTableExistsYN. EA-3374: Set dataype size NVARCHAR(MAX) for variables @AggregationSum and @AggregationSet.'
		IF @Version = '2.1.2.2191' SET @Description = 'For @ResultTypeBM=8, allow user input (Changeable = 1) on open periods.'
		IF @Version = '2.1.2.2193' SET @Description = 'Removed call to [spGet_FilterTable_New3]. Added @GroupByLeafLevelYN variable and implemented grouping by leaf level. For @ResultTypeBM=8, modified statement for setting @SQLMeasureList_8; only add reference to WSS.[TimeFrom] and WSS.[TimeTo] if @WorkflowStateYN <> 0.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added option RECOMPILE for the queries reading from the DataClass. Exclude DimensionTypeID 27 when setting @SQLSelect128 and @SQLJoin_128 queries. Added table variable @Hierarchy_Table to increase performance for @ResultTypeBM=512.'
		IF @Version = '2.1.2.2197' SET @Description = 'Improved handling of Info Message. New @DC_Table script with generic of "CREATE..." based on existing temp table'
		IF @Version = '2.1.2.2198' SET @Description = '1. Use renamed sp: [spPortalGet_CreateTableScript] instead of [sp_Tool_Generate_CreateTable]. Handle hierarchy calculation for @ResultTypeBM = 512. Handle Scenario [InputAllowedYN] in @ResultTypeBM = 8. DB-1442: Update [MultiDimIncludedYN] = 1 for [DimensionTypeID] = 27 from #FilterTable. DB-1519: Handle NULL values for WS.[WorkflowStateID], WSS.[TimeFrom] and WSS.[TimeTo] when setting @SQLMeasureList_8. DB-1455: Handle different MultiDim filters in Tuple level. EA-7707: Handle MultiDim filter in @GroupBy even if it is not existing in @Filter level. DB-1565: Set correct @MultiDimFilter parameter to [spGet_MultiDimFilter]. Added @DataClassID on checking missing Measure. Checking existing Dimensions in DataClass after the filling temp tables #GroupBy, #WhereTotal. DB-1586: Increased @TupleName NVARCHAR size to 100.'
		IF @Version = '2.1.2.2199' SET @Description = 'DB-1631: Fix minor issue on @Tuple with only TimeView filter. DB-1638: In ResultypeBM = 8 (Changeable), return correct changeability value for WFS writeAccess state. FEA-8636: Refer to DC.[Time_MemberId] for @TImeType=TimeDay when setting @SQL_Tuple. FDB-1850: Commented warning "When using a MultiDim dimension (like ...". Handle a lot of values by "LIKE" instead of in "IN..." clause when [EqualityString] = IN. Drill down to MultiDim Filter/Tuple was empty - fixed. FDB-1915: In ResultypeBM = 8 (Changeable), modified @SQLMeasureList_8 to return changeability value 0 if WFS IS  NULL AND Time value is not within the Worflow Time setting.'

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

		IF @CallistoDatabase IS NULL
			SELECT
				@CallistoDatabase = [DestinationDatabase]
			FROM
				[pcINTEGRATOR_Data].[dbo].[Application]
			WHERE
				[InstanceID] = @InstanceID AND
				[VersionID] = @VersionID AND
				[SelectYN] <> 0

		SELECT
			@DataClassName = [DataClassName],
			@Measure = ISNULL(@Measure, [DataClassName]),
			@DataClassTypeID = [DataClassTypeID],
			@StorageTypeBM_DataClass = [StorageTypeBM]
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DataClassID] = @DataClassID AND
			[SelectYN] <> 0 AND
			[DeletedID] IS NULL

		IF @DataClassName IS NULL
			BEGIN
				SET @Message = '@DataClassID = ' + CONVERT(NVARCHAR(15), @DataClassID) + ' does not match @InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' and @VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + '.'
				SET @Severity = 0
				GOTO EXITPOINT
			END

		SELECT @TimeType = CASE WHEN (SELECT COUNT(1) FROM pcINTEGRATOR_Data..DataClass_Dimension WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [DataClassID] = @DataClassID AND [DimensionID] IN (-49)) > 0 THEN 'TimeDay' ELSE 'Time' END

		IF @DebugBM & 2 > 0 SELECT [@TimeType] = @TimeType

--Always set to false
		SET @OnlyDataClassDimMembersYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID]=@UserID,
				[@InstanceID]=@InstanceID,
				[@VersionID]=@VersionID,
				[@DataClassID]=@DataClassID,
				[@DataClassName] = @DataClassName,
				[@Measure] = @Measure,
				[@CallistoDatabase] = @CallistoDatabase,
				[@PropertyList]=@PropertyList,
				[@AssignmentID]=@AssignmentID,
				[@DimensionList]=@DimensionList,
				[@OnlySecuredDimYN]=@OnlySecuredDimYN,
				[@ShowAllMembersYN]=@ShowAllMembersYN,
				[@OnlyDataClassDimMembersYN]=@OnlyDataClassDimMembersYN,
				[@Parent_MemberKey]=@Parent_MemberKey,
				[@Selected]=@Selected,
				[@TmpGlobalTable] = @TmpGlobalTable,
				[@JobID]=@JobID,
				[@Debug]=@DebugSub

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After initial settings', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)

	SET @Step = 'SP-Specific check'
		IF (SELECT COUNT(1) FROM pcINTEGRATOR_Data..Measure WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND MeasureName = @Measure and DataClassID = @DataClassID) = 0
			BEGIN
				SET @InfoMessage = 'Report definition is not correct. Selected measure ''' + @Measure + ''' does not exist in DataClass ''' + @DataClassName + '''';
				THROW 51000, @InfoMessage, 2;
			END

	SET @Step = 'Create temp tables'
		IF OBJECT_ID(N'TempDB.dbo.#PipeStringSplit', N'U') IS NULL
			CREATE TABLE #PipeStringSplit
				(
				[TupleNo] int,
				[PipeObject] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
				[PipeFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
				)

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

		IF @Filter IS NOT NULL AND @Tuple IS NULL
			SET @PipeString = @Filter
		ELSE IF @Filter IS NOT NULL AND @Tuple IS NOT NULL
			SET @PipeString = @Filter + ';' + @Tuple
		ELSE IF @Filter IS NULL AND @Tuple IS NOT NULL
			SET @PipeString = @Tuple

		SET @PipeString = REPLACE(REPLACE(REPLACE(REPLACE(@PipeString, 'TimeView', 'TW12'), 'TimeDay', 'Time'), 'Time', @TimeType), 'TW12', 'TimeView')

		IF @DebugBM & 2 > 0 SELECT [@PipeString] = @PipeString

		EXEC pcINTEGRATOR.dbo.[spGet_FilterTable]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DataClassID = @DataClassID,
			@PipeString = @PipeString,
			@DatabaseName = @CallistoDatabase, --Mandatory
			@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
			@StorageTypeBM = NULL, --Mandatory
			@StepReference = @StepReference,
			@Hierarchy = @Hierarchy,
			@Debug = @DebugSub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable_1', * FROM #FilterTable WHERE [StepReference] = @StepReference ORDER BY [TupleNo], [SortOrder], [DimensionName]

		SELECT @LineItemExistsYN = COUNT(1) FROM #FilterTable WHERE DimensionID = -27 AND [StepReference] = @StepReference

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After Get FilterTable', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = '@ResultTypeBM & 768' --+ 32
		--IF @ResultTypeBM & 768 > 0
		IF @ResultTypeBM & 812 > 0
			BEGIN
				CREATE TABLE #RowListChildren
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[RowList_MemberID] bigint,
					[RowList_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[RowList_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Leaf_MemberId] bigint,
					[SortOrder] int
					)

				CREATE TABLE #FilterList
					(
					[SortOrder] int IDENTITY(1,1),
					[Filter] nvarchar(100),
					)

				EXEC pcINTEGRATOR.dbo.[spGet_FilterTable]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@DataClassID = NULL,
					@PipeString = @RowList,
					@DatabaseName = @CallistoDatabase, --Mandatory
					@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
					@StorageTypeBM = NULL, --Mandatory
					@StepReference = 'RowList',
					@Hierarchy = @Hierarchy,
					@Debug = @DebugSub

				IF @DebugBM & 2 > 0
					BEGIN
						SELECT
							TempTable = '#FilterTable (RowList)',
							*
						FROM
							#FilterTable
						WHERE
							[StepReference] = 'RowList'

						SELECT
							TempTable = '#FilterTable (Total)',
							*
						FROM
							#FilterTable
					END

				SELECT
					@RowList_DimensionID = MAX([DimensionID])
				FROM
					#FilterTable
				WHERE
					[StepReference] = 'RowList' AND
					[DimensionID] IS NOT NULL

				SELECT
					@RowList_SupressZeroYN = ISNULL(CASE [DimensionName] WHEN 'SupressZeroYN' THEN [Filter] END, @RowList_SupressZeroYN),
					@RowList_ShowLevel = ISNULL(CASE [DimensionName] WHEN 'ShowLevel' THEN [Filter] END, @RowList_ShowLevel),
					@RowList_ExcludeStartNodeYN = ISNULL(CASE [DimensionName] WHEN 'ExcludeStartNodeYN' THEN [Filter] END, @RowList_ExcludeStartNodeYN),
					@RowList_ExcludeSumMemberYN = ISNULL(CASE [DimensionName] WHEN 'ExcludeSumMemberYN' THEN [Filter] END, @RowList_ExcludeSumMemberYN),
					@RowList_ParentSorting = ISNULL(CASE [DimensionName] WHEN 'ParentSorting' THEN [Filter] END, @RowList_ParentSorting)
				FROM
					#FilterTable
				WHERE
					[StepReference] = 'RowList' AND
					[DimensionName] IN ('SupressZeroYN', 'ShowLevel', 'ExcludeStartNodeYN', 'ExcludeSumMemberYN', 'ParentSorting')

				DELETE #FilterTable WHERE [DimensionName] IN ('SupressZeroYN', 'ShowLevel', 'ExcludeStartNodeYN', 'ExcludeSumMemberYN', 'ParentSorting')

				IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = 'RowList'

				IF CURSOR_STATUS('global','RowList_Cursor') >= -1 DEALLOCATE RowList_Cursor
				DECLARE RowList_Cursor CURSOR FOR

					SELECT
						[DimensionID],
						[DimensionName],
						[DimensionTypeID],
						[StorageTypeBM],
						[HierarchyName],
						[PropertyName],
						[EqualityString],
						[Filter]
					FROM
						#FilterTable
					WHERE
						[StepReference] = 'RowList'
					ORDER BY
						[DimensionID]

					OPEN RowList_Cursor
					FETCH NEXT FROM RowList_Cursor INTO @DimensionID, @DimensionName, @DimensionTypeID, @StorageTypeBM, @HierarchyName, @PropertyName, @EqualityString, @Filter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID]=@DimensionID, [@DimensionName]=@DimensionName, [@DimensionTypeID]=@DimensionTypeID, [@StorageTypeBM]=@StorageTypeBM, [@HierarchyName]=@HierarchyName, [@PropertyName]=@PropertyName, [@EqualityString]=@EqualityString, [@Filter]=@Filter

							TRUNCATE TABLE #FilterList

							INSERT INTO #FilterList
								(
								[Filter]
								)
							SELECT
								[Filter] = [Value]
							FROM
								STRING_SPLIT(@Filter, ',')

							IF @DebugBM & 2 > 0 SELECT [TempTable] = '#FilterList', * FROM #FilterList ORDER BY [SortOrder]

							INSERT INTO #FilterTable
								(
								[StepReference],
								[TupleNo],
								[DimensionID],
								[DimensionName],
								[DimensionTypeID],
								[StorageTypeBM],
								[SortOrder],
								[HierarchyName],
								[PropertyName],
								[EqualityString],
								[Filter]
								)
							SELECT
								[StepReference] = 'RowList',
								[TupleNo] = 1,
								[DimensionID] = @DimensionID,
								[DimensionName] = @DimensionName,
								[DimensionTypeID] = @DimensionTypeID,
								[StorageTypeBM] = @StorageTypeBM,
								[SortOrder] = FL.[SortOrder],
								[HierarchyName] = @HierarchyName,
								[PropertyName] = @PropertyName,
								[EqualityString] = @EqualityString,
								[Filter] = FL.[Filter]
							FROM
								#FilterList FL

							FETCH NEXT FROM RowList_Cursor INTO @DimensionID, @DimensionName, @DimensionTypeID, @StorageTypeBM, @HierarchyName, @PropertyName, @EqualityString, @Filter
						END

				CLOSE RowList_Cursor
				DEALLOCATE RowList_Cursor

				IF CURSOR_STATUS('global','RowListFilter_Cursor') >= -1 DEALLOCATE RowListFilter_Cursor
				DECLARE RowListFilter_Cursor CURSOR FOR
					SELECT
						[DimensionID],
						[DimensionTypeID],
						[StorageTypeBM],
						[HierarchyName],
						[PropertyName],
						[EqualityString],
						[Filter]
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] = 'RowList' AND
						FT.[TupleNo] = 1
					ORDER BY
						FT.[SortOrder]

					OPEN RowListFilter_Cursor
					FETCH NEXT FROM RowListFilter_Cursor INTO @DimensionID, @DimensionTypeID, @StorageTypeBM, @HierarchyName, @PropertyName, @EqualityString, @Filter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionTypeID] = @DimensionTypeID, [@HierarchyName] = @HierarchyName, [@PropertyName] = @PropertyName, [@StorageTypeBM] = @StorageTypeBM, [@Filter] = @Filter
							IF @HierarchyName IS NOT NULL AND CASE WHEN LEN(@Filter) = 0 THEN NULL ELSE @Filter END IS NOT NULL
								BEGIN
									EXEC pcINTEGRATOR..spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @CallistoDatabase, @DimensionID = @DimensionID, @HierarchyName = @HierarchyName, @Filter = @Filter, @StorageTypeBM_DataClass = 4, @StorageTypeBM = @StorageTypeBM, @FilterLevel = 'L', @FilterType = 'MemberKey', @LeafLevelFilter = @LeafLevelFilter OUT, @Debug = @DebugSub

									UPDATE #FilterTable
									SET
										[LeafLevelFilter] = @LeafLevelFilter
									WHERE
										[StepReference] = 'RowList' AND
										[TupleNo] = 1 AND
										[DimensionID] = @DimensionID AND
										[HierarchyName] = @HierarchyName AND
										[EqualityString] LIKE '%IN%' AND
										[Filter] = @Filter
								END
							FETCH NEXT FROM RowListFilter_Cursor INTO @DimensionID, @DimensionTypeID, @StorageTypeBM, @HierarchyName, @PropertyName, @EqualityString, @Filter
						END

				CLOSE RowListFilter_Cursor
				DEALLOCATE RowListFilter_Cursor

				IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = 'RowList' ORDER BY [TupleNo], [SortOrder]
				IF @DebugBM & 16 > 0 SELECT [Step] = 'After Get RowList', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)

-- 			IF (SELECT COUNT(1) FROM #FilterTable WHERE [StepReference] = 'RowList' AND [DimensionTypeID] = 27 AND ISNULL([Filter], 'All_') = 'All_') > 0
-- 				BEGIN
-- 					SET @InfoMessage = 'When using a MultiDim dimension (like FullAccount) in the [Rows] report options, it is  not allowed to set/filter the dimension member to ''All_''.';
-- 					THROW 51000, @InfoMessage, 2;
-- 				END

			END

	SET @Step = 'Create temp table #GroupBy'
		CREATE TABLE #GroupBy
			(
			[SortOrder] int IDENTITY(1,1),
			[TupleNo] int DEFAULT 0,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[PropertyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[LoopNo] int
			)

		INSERT INTO #GroupBy
			(
			[DimensionName]
			)
		SELECT DISTINCT
			[DimensionName] = [Value]
		FROM
			STRING_SPLIT(@GroupBy, '|')

		INSERT INTO #GroupBy
			(
			[TupleNo],
			[DimensionName]
			)
		SELECT DISTINCT
			[TupleNo] = 1,
			[DimensionName] = FT.[DimensionName]
		FROM
			[#FilterTable] FT
		WHERE
			FT.[TupleNo] <> 0 AND
			FT.[DimensionName] <> '#Tuple' AND
			LEN(FT.[DimensionName]) > 0 AND
			NOT EXISTS (SELECT 1 FROM #GroupBy GB WHERE GB.[DimensionName] = FT.[DimensionName])

		UPDATE GB
		SET
			[DimensionName] = CASE WHEN CHARINDEX('.', GB.[DimensionName]) = 0 THEN GB.[DimensionName] ELSE LEFT(GB.[DimensionName], CHARINDEX('.', GB.[DimensionName]) - 1) END,
			[PropertyName] = CASE WHEN CHARINDEX('.', GB.[DimensionName]) = 0 THEN 'Label' ELSE SUBSTRING(GB.[DimensionName], CHARINDEX('.', GB.[DimensionName]) + 1, LEN(GB.[DimensionName]) - CHARINDEX('.', GB.[DimensionName])) END
		FROM
			#GroupBy GB

		DELETE #GroupBy
		WHERE [DimensionName] IN ('TimeView')

		INSERT INTO #GroupBy
			(
			[TupleNo],
			[DimensionName],
			[PropertyName]
			)
		SELECT
			[TupleNo] = -1, --=1
			[DimensionName] = @TimeType, --'Time',
			[PropertyName] = 'Label'
		WHERE
			NOT EXISTS (SELECT 1 FROM #GroupBy GB WHERE GB.[DimensionName] LIKE 'Time%')

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#GroupBy', * FROM #GroupBy ORDER BY [SortOrder], [DimensionName]

	SET @Step = 'Checking: Does #GroupBy have the Dimensions which don''t exist in DataClass'
        set @MissingItems_OUT = N'';
        select @MissingItems_OUT =  @MissingItems_OUT  + coalesce(N'''' + GB.[DimensionName], N'null')  + N''', '
        from  #GroupBy GB
     --   left join #DimensionInfo DI on DI.DimensionName = TI.[Item]
        left join (
                    SELECT D.DimensionName
                    FROM [pcINTEGRATOR]..[DataClass_Dimension] DCD
                    JOIN [pcINTEGRATOR]..[Dimension] D ON   D.[DimensionID] = DCD.[DimensionID]
                                                        and D.SelectYN <> 0
                    WHERE DCD.[InstanceID] = @InstanceID
                      AND DCD.[VersionID] = @VersionID
                      AND DCD.[DataClassID] = @DataClassID
                      AND DCD.SelectYN <> 0
                    ) DI on DI.DimensionName = GB.DimensionName
        where DI.DimensionName is null

		if @Debug <> 0 select [@MissingItems_OUT] = @MissingItems_OUT, [Len] = Len(@MissingItems_OUT)
        if Len(@MissingItems_OUT) > 1 set @MissingItems_OUT = left(@MissingItems_OUT, Len(@MissingItems_OUT) - 1)
        IF @MissingItems_OUT <> N''
        begin
            set @InfoMessage = 'Selected dimension(s) used for grouping (Rows/Columns): ' + @MissingItems_OUT + ' do(es) not exist in DataClass: ''' + @DataClassName + '''';
            THROW 51000, @InfoMessage, 2;
        end

	SET @Step = 'Create temp table #Time'
		CREATE TABLE #Time
			(
			[MemberId] [bigint] NULL,
			[Label] [nvarchar](255) NOT NULL,
			[Description] [nvarchar](512) NOT NULL,
			[HelpText] [nvarchar](1024) NULL,
			[Level] [nvarchar](50) NULL,
			[NumberOfDays] [int] NULL,
			[PeriodEndDate] [nvarchar](10) NULL,
			[PeriodStartDate] [nvarchar](10) NULL,
			[RNodeType] [nvarchar](2) NULL,
			[RowOrder] [int] NULL,
			[SBZ] [bit] NULL,
			[SendTo_MemberId] [bigint] NULL,
			[SendTo] [nvarchar](255) NULL,
			[TimeFiscalPeriod_MemberId] [bigint] NULL,
			[TimeFiscalPeriod] [nvarchar](255) NULL,
			[TimeFiscalQuarter_MemberId] [bigint] NULL,
			[TimeFiscalQuarter] [nvarchar](255) NULL,
			[TimeFiscalSemester_MemberId] [bigint] NULL,
			[TimeFiscalSemester] [nvarchar](255) NULL,
			[TimeFiscalTertial_MemberId] [bigint] NULL,
			[TimeFiscalTertial] [nvarchar](255) NULL,
			[TimeFiscalYear_MemberId] [bigint] NULL,
			[TimeFiscalYear] [nvarchar](255) NULL,
			[TimeMonth_MemberId] [bigint] NULL,
			[TimeMonth] [nvarchar](255) NULL,
			[TimeQuarter_MemberId] [bigint] NULL,
			[TimeQuarter] [nvarchar](255) NULL,
			[TimeSemester_MemberId] [bigint] NULL,
			[TimeSemester] [nvarchar](255) NULL,
			[TimeTertial_MemberId] [bigint] NULL,
			[TimeTertial] [nvarchar](255) NULL,
			[TimeYear_MemberId] [bigint] NULL,
			[TimeYear] [nvarchar](255) NULL,
			[PresentationYN] bit DEFAULT 0
			)

	SET @Step = 'Create temp table #TimeViewFilter'
		CREATE TABLE #TimeViewFilter
			(
			Member nvarchar(100)
			)

	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				EXEC [dbo].[spGet_DataClass_DimensionList]
					@UserID=@UserID,
					@InstanceID=@InstanceID,
					@VersionID=@VersionID,
					@DataClassID=@DataClassID,
					@OrganizationPositionID=@ActingAs,
					@AssignmentID=@AssignmentID,
					@DimensionList=@DimensionList,
					@ResultTypeBM=3,
					@JobID=@JobID,
					@Debug=@DebugSub
			END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				EXEC [spGet_DataClass_DimensionMember]
					@UserID=@UserID,
					@InstanceID=@InstanceID,
					@VersionID=@VersionID,
					@DataClassID=@DataClassID,
					@PropertyList=@PropertyList,
					@AssignmentID=@AssignmentID,
					@DimensionList=@DimensionList,
					@OnlySecuredDimYN=@OnlySecuredDimYN,
					@ShowAllMembersYN=@ShowAllMembersYN,
					@OnlyDataClassDimMembersYN=@OnlyDataClassDimMembersYN,
					@Parent_MemberKey=@Parent_MemberKey,
					@Selected=@Selected OUT,
					@JobID=@JobID,
					@Debug=@DebugSub

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After ResultTypeBM = 2', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)
			END
/*
	SET @Step = 'Update #FilterTable'
		IF (SELECT COUNT(1) FROM #FilterTable WHERE [StepReference] = 'RowList' AND [DimensionTypeID] = 27 AND ISNULL([Filter], 'All_') = 'All_') > 0
			BEGIN
				SET @InfoMessage = 'When using a MultiDim dimension (like FullAccount), it is  not allowed to set Filter = All_';
				THROW 51000, @InfoMessage, 2;
			END
*/
--SELECT TempTable = '#RowListChildren', * FROM #RowListChildren
--SELECT TempTable = '#GroupBy', * FROM #GroupBy

		IF OBJECT_ID(N'TempDB.dbo.#RowListChildren', N'U') IS NOT NULL
			UPDATE FT
			SET
				[MultiDimIncludedYN] = 1
			FROM
				#FilterTable FT
				INNER JOIN #RowListChildren RLC ON RLC.[DimensionName] = FT.[DimensionName]
			WHERE
				FT.[DimensionTypeID] = 27 AND
				--FT.[Filter] NOT IN ('All_') AND
				LEN(FT.[Filter]) > 0
				--LEN([LeafLevelFilter]) > 0

		UPDATE FT
		SET
			[MultiDimIncludedYN] = 1
		FROM
			#FilterTable FT
		WHERE
			FT.[DimensionTypeID] = 27 AND
			FT.[Filter] NOT IN ('All_') AND
			LEN(FT.[Filter]) > 0

		UPDATE FT
		SET
			[MultiDimIncludedYN] = 1
		FROM
			#FilterTable FT
			INNER JOIN #GroupBy GB ON GB.[DimensionName] = FT.[DimensionName]
		WHERE
			FT.[DimensionTypeID] = 27 AND
			--FT.[Filter] NOT IN ('All_') AND
			--LEN(FT.[Filter]) > 0
			NOT EXISTS (SELECT 1 FROM #FilterTable FTD WHERE FTD.DimensionID = FT.DimensionID AND FTD.[MultiDimIncludedYN] <> 0)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable_2', * FROM #FilterTable WHERE [StepReference] IN (@StepReference, 'RowList') ORDER BY [TupleNo], [SortOrder], [DimensionName]

	SET @Step = 'Time handling'
		IF @ResultTypeBM & 812 > 0
			BEGIN
				SET @TimeFilter = ''
				SELECT
					@TimeFilter = @TimeFilter + [LeafLevelFilter] + ','
				FROM
					(
					SELECT DISTINCT
						[LeafLevelFilter]
					FROM
						#FilterTable
					WHERE
						[DimensionID] IN (-49, -7) AND
						LEN([LeafLevelFilter]) > 0
					) sub

				IF @DebugBM & 2 > 0 SELECT [LEN(@TimeFilter)] =  LEN(@TimeFilter)

				IF LEN(@TimeFilter) > 0
					BEGIN
						SET @TimeFilter = LEFT(@TimeFilter, LEN(@TimeFilter) - 1)
						SET @TimeFilterString = '[MemberId] IN (' + @TimeFilter + ') OR'
					END

				IF CURSOR_STATUS('global','TimeView_Cursor') >= -1 DEALLOCATE TimeView_Cursor
				DECLARE TimeView_Cursor CURSOR FOR

					SELECT
						[TupleNo],
						[Filter]
					FROM
						#FilterTable
					WHERE
						TupleNo <> 0 AND
						DimensionID = -77
					ORDER BY
						[TupleNo]

					OPEN TimeView_Cursor
					FETCH NEXT FROM TimeView_Cursor INTO @TupleNo, @Filter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@TupleNo] = @TupleNo, [@Filter] = @Filter

							SET @TimeFilterTupleString = ''

							SELECT
								@TimeFilterTuple = [LeafLevelFilter]
							FROM
								#FilterTable
							WHERE
								TupleNo = @TupleNo AND
								DimensionID = -7

							SET @TimeFilterTuple = ISNULL(CASE WHEN @TimeFilterTuple = '' THEN NULL ELSE @TimeFilterTuple END, @TimeFilter)

							IF @DebugBM & 2 > 0 SELECT [@TimeFilterTuple] = @TimeFilterTuple

							IF @Filter IN ('YTD', 'FYTD')
								BEGIN
									SET @TimeProperty = CASE @Filter WHEN 'YTD' THEN 'TimeYear_MemberId' WHEN 'FYTD' THEN 'TimeFiscalYear_MemberId' END

									TRUNCATE TABLE #TimeViewFilter

									SET @SQLStatement = '
										INSERT INTO #TimeViewFilter
											(
											[Member]
											)
										SELECT DISTINCT
											[Member] = [' + @TimeProperty + ']
										FROM
											' + @CallistoDatabase + '..S_DS_Time
										WHERE
											MemberID IN (' + @TimeFilterTuple + ')'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SELECT
										@TimeFilterTupleString = @TimeFilterTupleString + [Member] + ','
									FROM
										#TimeViewFilter
									ORDER BY
										[Member]

									IF LEN(@TimeFilterTupleString) > 1
										BEGIN
											SET @TimeFilterTupleString = LEFT(@TimeFilterTupleString, LEN(@TimeFilterTupleString) - 1)
											SET @TimeFilterString = @TimeFilterString + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @TimeProperty + '] IN (' + @TimeFilterTupleString + ') OR'
										END
								END
							ELSE IF @Filter IN ('R12')
								BEGIN
									SET @SQLStatement = '
										SELECT
											@InternalVariable1 = MIN([RowOrder]),
											@InternalVariable2 = MIN([MemberId])
										FROM
											' + @CallistoDatabase + '..[S_DS_Time]
										WHERE
											MemberID IN (' + @TimeFilterTuple + ')'

									EXEC sp_executesql @SQLStatement, N'@InternalVariable1 int OUT, @InternalVariable2 bigint OUT', @InternalVariable1 = @MinRowOrder OUT, @InternalVariable2 = @MinTimeMemberId OUT

									IF @DebugBM & 2 > 0 SELECT [@MinRowOrder] = @MinRowOrder, [@MinTimeMemberId] = @MinTimeMemberId

									TRUNCATE TABLE #TimeViewFilter

									SET @SQLStatement = '
										INSERT INTO #TimeViewFilter
											(
											[Member]
											)
										SELECT DISTINCT
											[Member] = [MemberId]
										FROM
											' + @CallistoDatabase + '..S_DS_Time
										WHERE
											[RowOrder] BETWEEN ' + CONVERT(nvarchar(15), @MinRowOrder - 11) + ' AND ' + CONVERT(nvarchar(15), @MinRowOrder - 1)

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SELECT
										@TimeFilterTupleString = @TimeFilterTupleString + [Member] + ','
									FROM
										#TimeViewFilter
									ORDER BY
										[Member]

									IF LEN(@TimeFilterTupleString) > 1
										BEGIN
											SET @TimeFilterTupleString = LEFT(@TimeFilterTupleString, LEN(@TimeFilterTupleString) - 1)
											SET @TimeFilterString = @TimeFilterString + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[MemberId] IN (' + @TimeFilterTupleString + ') OR'
										END
								END
							ELSE
								BEGIN
									SET @Message = 'TimeView = ' + @Filter + ' is not implemented.'
									SET @Severity = 0
								END

							FETCH NEXT FROM TimeView_Cursor INTO @TupleNo, @Filter
						END

				CLOSE TimeView_Cursor
				DEALLOCATE TimeView_Cursor

				SELECT @TimeFilterString = LEFT(@TimeFilterString, LEN(@TimeFilterString) - 2)

		--		SELECT @TimeType = CASE WHEN (SELECT COUNT(1) FROM #FilterTable WHERE DimensionID IN (-49) AND LEN(LeafLevelFilter) > 0) > 0 THEN 'TimeDay' ELSE 'Time' END

				IF @DebugBM & 2 > 0 SELECT [@TimeFilterString] = @TimeFilterString

				SET @SQLStatement = '
					INSERT INTO #Time
						(
						[MemberId],
						[Label],
						[Description],
						[HelpText],
						[Level],
						[NumberOfDays],
						[PeriodEndDate],
						[PeriodStartDate],
						[RNodeType],
						' + CASE WHEN @TimeType = 'Time' THEN '[RowOrder],' ELSE '' END + '
						[SBZ],
						[SendTo_MemberId],
						[SendTo],
						[TimeFiscalPeriod_MemberId],
						[TimeFiscalPeriod],
						[TimeFiscalQuarter_MemberId],
						[TimeFiscalQuarter],
						[TimeFiscalSemester_MemberId],
						[TimeFiscalSemester],
						[TimeFiscalTertial_MemberId],
						[TimeFiscalTertial],
						[TimeFiscalYear_MemberId],
						[TimeFiscalYear],
						[TimeMonth_MemberId],
						[TimeMonth],
						[TimeQuarter_MemberId],
						[TimeQuarter],
						[TimeSemester_MemberId],
						[TimeSemester],
						[TimeTertial_MemberId],
						[TimeTertial],
						[TimeYear_MemberId],
						[TimeYear]
						)
					SELECT
						[MemberId],
						[Label],
						[Description],
						[HelpText],
						[Level],
						[NumberOfDays],
						[PeriodEndDate],
						[PeriodStartDate],
						[RNodeType],
						' + CASE WHEN @TimeType = 'Time' THEN '[RowOrder],' ELSE '' END + '
						[SBZ],
						[SendTo_MemberId],
						[SendTo],
						[TimeFiscalPeriod_MemberId],
						[TimeFiscalPeriod],
						[TimeFiscalQuarter_MemberId],
						[TimeFiscalQuarter],
						[TimeFiscalSemester_MemberId],
						[TimeFiscalSemester],
						[TimeFiscalTertial_MemberId],
						[TimeFiscalTertial],
						[TimeFiscalYear_MemberId],
						[TimeFiscalYear],
						[TimeMonth_MemberId],
						[TimeMonth],
						[TimeQuarter_MemberId],
						[TimeQuarter],
						[TimeSemester_MemberId],
						[TimeSemester],
						[TimeTertial_MemberId],
						[TimeTertial],
						[TimeYear_MemberId],
						[TimeYear]
					FROM
						[' + @CallistoDatabase + '].[dbo].[S_DS_' + @TimeType + ']
					WHERE
						[RNodeType] = ''L''' + CASE WHEN LEN(@TimeFilterString) > 0 THEN ' AND
						(
						' + @TimeFilterString + '
						)' ELSE '' END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF LEN(@TimeFilter) > 0
					BEGIN
						SET @SQLStatement = '
							UPDATE #Time
							SET [PresentationYN] = 1
							WHERE [MemberID] IN (' + @TimeFilter + ')'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END

				SELECT @TimeTableYN = CASE WHEN COUNT(1) = 0 THEN 0 ELSE 1 END FROM #Time

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Time', * FROM #Time

				SELECT @TimeDimensionTypeID = MAX(DimensionID) FROM #FilterTable WHERE TupleNo = 0 AND DimensionTypeID = 7

				IF @DebugBM & 2 > 0  SELECT [@TimeTableYN] = @TimeTableYN, [@TimeDimensionTypeID] = @TimeDimensionTypeID
			END

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After Time Handling', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Get temp table #MultiDim when needed'
		IF (SELECT COUNT(1) FROM #FilterTable WHERE [StepReference] = 'RowList' AND [MultiDimIncludedYN] <> 0 AND [Filter] = 'All_') > 0
			BEGIN
				SET @InfoMessage = 'When using a MultiDim dimension (like FullAccount), it is  not allowed to set Filter = All_';
				THROW 51000, @InfoMessage, 2;
			END

		IF @ResultTypeBM & 812 > 0 AND (SELECT COUNT(1) FROM #FilterTable WHERE [MultiDimIncludedYN] <> 0) > 0  --AND [Filter] <> 'All_') > 0
			BEGIN
				SET @MultiDimYN = 1

				CREATE TABLE #MultiDim
					(
					[MultiDim_Filter] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Category_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Category_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Leaf_MemberId] bigint,
					[Leaf_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Leaf_Description] nvarchar(100) COLLATE DATABASE_DEFAULT
					)

IF @DebugBM & 2 > 0
	BEGIN
/*
		SELECT DISTINCT
			DimensionID,
			DimensionName,
			HierarchyName,
			EqualityString = ISNULL(FT.EqualityString, 'IN'),
			[MultiDimFilter] = ISNULL(FT.[Filter], ''),
			LeafLevelFilter = ISNULL(FT.LeafLevelFilter, '')
		FROM
			#FilterTable FT
		WHERE
			FT.[StepReference] IN (@StepReference, 'RowList') AND
			FT.[TupleNo] = 0 AND
			FT.[MultiDimIncludedYN] <> 0
--			AND LEN(FT.[LeafLevelFilter]) > 0
		ORDER BY
			DimensionID
*/
		SELECT [Modified_MultiDim_Cursor] = '[Modified_MultiDim_Cursor]',
			DimensionID,
			DimensionName,
			HierarchyName,
			EqualityString,
			[MultiDimFilter] = MAX(COALESCE(sub.[MultiDimFilter] + ',' , '')),
			LeafLevelFilter
		FROM
			(
			SELECT DISTINCT
				DimensionID,
				DimensionName,
				HierarchyName,
				EqualityString = ISNULL(FT.EqualityString, 'IN'),
				[MultiDimFilter] = ISNULL(FT.[Filter], ''),
				LeafLevelFilter = ISNULL(FT.LeafLevelFilter, '')
			FROM
				#FilterTable FT
			WHERE
				FT.[StepReference] IN (@StepReference, 'RowList') AND
				FT.[TupleNo] = 0 AND
				FT.[MultiDimIncludedYN] <> 0
			) sub
		GROUP BY
			DimensionID,
			DimensionName,
			HierarchyName,
			EqualityString,
			LeafLevelFilter
		ORDER BY
			DimensionID

	END

				IF CURSOR_STATUS('global','MultiDim_Cursor') >= -1 DEALLOCATE MultiDim_Cursor
				DECLARE MultiDim_Cursor CURSOR FOR
					/*
					SELECT DISTINCT
						DimensionID,
						DimensionName,
						HierarchyName,
						EqualityString = ISNULL(FT.EqualityString, 'IN'),
						[MultiDimFilter] = ISNULL(FT.[Filter], ''),
						LeafLevelFilter = ISNULL(FT.LeafLevelFilter, '')
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] IN (@StepReference, 'RowList') AND
						FT.[TupleNo] = 0 AND
						FT.[MultiDimIncludedYN] <> 0
					ORDER BY
						DimensionID
					*/

					SELECT
						DimensionID,
						DimensionName,
						HierarchyName,
						EqualityString,
						[MultiDimFilter] = MAX(COALESCE(sub.[MultiDimFilter] + ',' , '')),
						LeafLevelFilter
					FROM
						(
						SELECT DISTINCT
							DimensionID,
							DimensionName,
							HierarchyName,
							EqualityString = ISNULL(FT.EqualityString, 'IN'),
							[MultiDimFilter] = ISNULL(FT.[Filter], ''),
							LeafLevelFilter = ISNULL(FT.LeafLevelFilter, '')
						FROM
							#FilterTable FT
						WHERE
							FT.[StepReference] IN (@StepReference, 'RowList') AND
							FT.[TupleNo] = 0 AND
							FT.[MultiDimIncludedYN] <> 0
						) sub
					GROUP BY
						DimensionID,
						DimensionName,
						HierarchyName,
						EqualityString,
						LeafLevelFilter
					ORDER BY
						DimensionID

					OPEN MultiDim_Cursor
					FETCH NEXT FROM MultiDim_Cursor INTO @DimensionID, @DimensionName, @HierarchyName, @EqualityString, @MultiDimFilter, @LeafLevelFilter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@HierarchyName] = @HierarchyName, [@EqualityString] = @EqualityString, [@MultiDimFilter] = @MultiDimFilter, [@LeafLevelFilter] = @LeafLevelFilter

							SELECT @MultiDimFilter = CASE WHEN RIGHT(@MultiDimFilter,1) = ',' THEN LEFT(@MultiDimFilter, LEN(@MultiDimFilter) -1)  ELSE @MultiDimFilter END
							IF @DebugBM & 2 > 0 SELECT [@MultiDimFilter] = @MultiDimFilter

							SET @LoopNo = @LoopNo + 1
							UPDATE GB
							SET
								[LoopNo] = @LoopNo
							FROM
								#GroupBy GB
							WHERE
								GB.DimensionName = @DimensionName

							SELECT
								@CategoryYN = CASE WHEN [HierarchyTypeID] = 2 THEN 1 ELSE 0 END
							FROM
								pcINTEGRATOR_Data..DimensionHierarchy
							WHERE
								[InstanceID] = @InstanceID AND
								[VersionID] = @VersionID AND
								[DimensionID] = @DimensionID AND
								[HierarchyName] = @HierarchyName

							--IF @ResultTypeBM & 768 > 0 SET @CategoryYN = 1

							IF @DebugBM & 2 > 0
								SELECT
									[@UserID] = @UserID,
									[@InstanceID] = @InstanceID,
									[@VersionID] = @VersionID,
									[@MultiDimensionID] = @DimensionID,
									[@MultiDimensionName] = @DimensionName,
									[@MultiHierarchyName] = @HierarchyName,
									[@MultiDimFilter] = @MultiDimFilter,
									[@LeafLevelFilter] = @LeafLevelFilter,
									[@EqualityString] = @EqualityString,
									[@CategoryYN] = @CategoryYN,
									[@JournalYN] = 0,
									[@CallistoDatabase] = @CallistoDatabase,
									[@SQL_MultiDimJoin] = @SQL_MultiDimJoin,
									[@JobID] = @JobID,
									[@Debug] = @DebugSub

							EXEC [dbo].[spGet_MultiDimFilter]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@MultiDimensionID = @DimensionID,
								@MultiDimensionName = @DimensionName,
								@MultiHierarchyName = @HierarchyName,
								@MultiDimFilter = @MultiDimFilter,
								@LeafLevelFilter = @LeafLevelFilter,
								@EqualityString = @EqualityString,
								@CategoryYN = @CategoryYN,
								@JournalYN = 0,
								@CallistoDatabase = @CallistoDatabase,
								@SQL_MultiDimJoin = @SQL_MultiDimJoin OUT,
								@JobID = @JobID,
								@Debug = @DebugSub

							IF @DebugBM & 2 > 0 SELECT [@SQL_MultiDimJoin] = @SQL_MultiDimJoin

							FETCH NEXT FROM MultiDim_Cursor INTO @DimensionID, @DimensionName, @HierarchyName, @EqualityString, @MultiDimFilter, @LeafLevelFilter
						END

				CLOSE MultiDim_Cursor
				DEALLOCATE MultiDim_Cursor

			IF @DebugBM & 2 > 0 SELECT TempTable = '#MultiDim', * FROM #MultiDim
		END

	SET @Step = 'Get ReadAccess'
		--IF @ResultTypeBM & 772 > 0
		IF @ResultTypeBM & 812 > 0
			BEGIN
				CREATE TABLE #ReadAccess
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[StorageTypeBM] int,
					[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[DataColumn] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[SelectYN] bit
					)

				EXEC [spGet_ReadAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, 	@ActingAs = @ActingAs, @StorageTypeBM_DataClass = 4, @JobID = @JobID, @Debug = @DebugSub

				IF @DebugBM & 2 > 0 SELECT TempTable = '#ReadAccess', * FROM #ReadAccess

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After Get ReadAccess', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)
			END

	SET @Step = 'Get WHERE clause'
		IF @ResultTypeBM & 812 > 0
			BEGIN
				CREATE TABLE #WhereTotal
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[SortOrder] int
					)

				INSERT INTO #WhereTotal
					(
					[DimensionID],
					[DimensionName],
					[EqualityString],
					[LeafLevelFilter],
					[SortOrder]
					)
				SELECT
					[DimensionID],
					[DimensionName],
					[EqualityString],
					[LeafLevelFilter],
					[SortOrder]
				FROM
					#FilterTable FT
				WHERE
					FT.[StepReference] = @StepReference AND
					FT.[TupleNo] = 0 AND
					LEN(FT.[LeafLevelFilter]) > 0 AND
					(FT.[DimensionTypeID] NOT IN (7) OR @ResultTypeBM & 32 > 0) AND
					FT.[DimensionTypeID] NOT IN (8, 27, 50)
				ORDER BY
					FT.[SortOrder]

				INSERT INTO #WhereTotal
					(
					[DimensionID],
					[DimensionName],
					[EqualityString],
					[LeafLevelFilter],
					[SortOrder]
					)
				SELECT
					[DimensionID],
					[DimensionName],
					[EqualityString] = 'IN',
					[LeafLevelFilter],
					[SortOrder] = 10000
				FROM
					#ReadAccess RA
				WHERE
					LEN(RA.[LeafLevelFilter]) > 0

				SET @Step = 'Checking: Does #WhereTotal have the Dimensions which don''t exist in DataClass'
                    set @MissingItems_OUT = N'';
                    select @MissingItems_OUT =  @MissingItems_OUT  + coalesce(N'''' + WT.[DimensionName], N'null')  + N''', '
                    from  #WhereTotal WT
                 --   left join #DimensionInfo DI on DI.DimensionName = TI.[Item]
                    left join (
                                SELECT D.DimensionName
                                FROM [pcINTEGRATOR]..[DataClass_Dimension] DCD
                                JOIN [pcINTEGRATOR]..[Dimension] D ON   D.[DimensionID] = DCD.[DimensionID]
                                                                    and D.SelectYN <> 0
                                WHERE DCD.[InstanceID] = @InstanceID
                                  AND DCD.[VersionID] = @VersionID
                                  AND DCD.[DataClassID] = @DataClassID
                                  AND DCD.SelectYN <> 0
                                ) DI on DI.DimensionName = WT.DimensionName
                    where DI.DimensionName is null

                    if @Debug <> 0 select [@MissingItems_OUT] = @MissingItems_OUT, [Len] = Len(@MissingItems_OUT)
                    if Len(@MissingItems_OUT) > 1 set @MissingItems_OUT = left(@MissingItems_OUT, Len(@MissingItems_OUT) - 1)
                    IF @MissingItems_OUT <> N''
                    begin
                        SET @InfoMessage = 'Selected dimension(s) used for filtering: ' + @MissingItems_OUT + ' do(es) not exist in DataClass: ''' + @DataClassName + '''';
                        THROW 51000, @InfoMessage, 2;
                    end

				SELECT @SQL_Where_Total = '', @SQL_Where_160 = ''

				SELECT
					@SQL_Where_Total = @SQL_Where_Total + 'DC.[' + WT.[DimensionName] + '_MemberID] ' + WT.[EqualityString] + ' (' + WT.[LeafLevelFilter] + ') AND ',
					@SQL_Where_160 = @SQL_Where_160 + 'DC.[' + WT.[DimensionName] + '_MemberID] ' + WT.[EqualityString] + ' (' + WT.[LeafLevelFilter] + CASE WHEN DimensionID = -2 AND @ResultTypeBM & 160 > 0 THEN ',' + CONVERT(nvarchar(15), @LineItemBP) ELSE '' END + ') AND '
				FROM
					#WhereTotal WT
				ORDER BY
					WT.[SortOrder],
					WT.[DimensionName]

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After Get WHERE-clause', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)
			END

	SET @Step = 'Get Tuple clause'
		IF @ResultTypeBM & 772 > 0 --4, 256, 512
			BEGIN
				IF CURSOR_STATUS('global','Tuple_Cursor') >= -1 DEALLOCATE Tuple_Cursor
				DECLARE Tuple_Cursor CURSOR FOR

					SELECT DISTINCT
						[TupleNo] = FT.[TupleNo],
						[TupleName] = 'T_' + ISNULL(MAX(FT.[ObjectReference]), 'Tuple_' + CONVERT(nvarchar(15), FT.[TupleNo])),
						[MultiDimIncludedYN] = MAX(CONVERT(int, FT.[MultiDimIncludedYN]))
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] = @StepReference AND
						FT.[TupleNo] > 0 AND
						(LEN(FT.[LeafLevelFilter]) > 0 OR LEN(FT.[ObjectReference]) > 0) --AND
						--ISNULL(FT.[DimensionTypeID], 0) NOT IN (27, 50)
						--ISNULL(FT.[DimensionTypeID], 0) NOT IN (50)
					GROUP BY
						FT.[TupleNo]
					ORDER BY
						FT.[TupleNo]

					OPEN Tuple_Cursor
					FETCH NEXT FROM Tuple_Cursor INTO @TupleNo, @TupleName, @MultiDimIncludedYN

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 32 > 0 SELECT [@TupleNo] = @TupleNo, [@TupleName] = @TupleName, [@SQL_Tuple] = @SQL_Tuple, [LEN_@SQL_Tuple] = LEN(@SQL_Tuple), [@MultiDimIncludedYN] = @MultiDimIncludedYN

							SET @MultiDim_Leaf_MemberId_csv = NULL
							SET @SQL_Tuple = @SQL_Tuple + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @TupleName +'] = ROUND(SUM(CASE WHEN '

							IF @DebugBM & 32 > 0
								SELECT
									[Step] = 'TupleLoop', *
								FROM
									#FilterTable FT
								WHERE
									FT.[StepReference] = @StepReference AND
									FT.[TupleNo] = @TupleNo AND
									(LEN(FT.[LeafLevelFilter]) > 0 OR (LEN(FT.[ObjectReference]) > 0 AND FT.DimensionTypeID = 27)) --AND
									--LEN(FT.[LeafLevelFilter]) > 0 --AND
									----FT.[DimensionTypeID] <> 50
								ORDER BY
									FT.[SortOrder]

							--IF	(
							--	SELECT COUNT(1)
							--	FROM #FilterTable FT
							--	WHERE
							--		FT.[StepReference] = @StepReference AND
							--		FT.[TupleNo] = @TupleNo AND
							--		FT.[DimensionTypeID] = 50 AND
							--		FT.[Filter] IN ('YTD', 'FYTD', 'R12')
							--	) > 0

								SET @TimeView = NULL

								SELECT
									@TimeView = [Filter]
								FROM
									#FilterTable FT
								WHERE
									FT.[StepReference] = @StepReference AND
									FT.[TupleNo] = @TupleNo AND
									FT.[DimensionTypeID] = 50 AND
									FT.[Filter] IN ('YTD', 'FYTD', 'R12')

								IF @TimeView IS NOT NULL
								BEGIN
									UPDATE FT
									SET
										[Method] = @TimeView
									FROM
										#FilterTable FT
									WHERE
										FT.[StepReference] = @StepReference AND
										FT.[TupleNo] = @TupleNo AND
										FT.[DimensionTypeID] = 7
								END

							SELECT
								--@SQL_Tuple = @SQL_Tuple + CASE WHEN [Method] IS NOT NULL THEN '[Time].[MemberId] ' ELSE 'DC.[' + FT.[DimensionName] + '_MemberID] ' END + FT.[EqualityString] + ' (' + FT.[LeafLevelFilter] + ') AND '
								@SQL_Tuple = @SQL_Tuple + CASE WHEN FT.[Method] IS NOT NULL THEN '[Time].[MemberId] ' ELSE CASE WHEN FT.[DimensionName] = @TimeType THEN 'DC.[Time_MemberID] ' ELSE 'DC.[' + FT.[DimensionName] + '_MemberID] ' END END + FT.[EqualityString] + ' (' + FT.[LeafLevelFilter] + ') AND '
							FROM
								#FilterTable FT
							WHERE
								FT.[StepReference] = @StepReference AND
								FT.[TupleNo] = @TupleNo AND
								LEN(FT.[LeafLevelFilter]) > 0 AND
								--FT.[DimensionTypeID] <> 50
								FT.[DimensionTypeID] NOT IN (27,50)
							ORDER BY
								FT.[SortOrder]

							SELECT
								@SQL_Tuple = @SQL_Tuple + CASE sub.[Filter]
									WHEN 'Periodic' THEN '[TimeView].[MemberId] = [Time].[MemberId] AND '
									WHEN 'YTD' THEN '[TimeView].[TimeYear_MemberID] = [Time].[TimeYear_MemberID] AND [TimeView].[MemberId] <= [Time].[MemberId] AND '
									WHEN 'FYTD' THEN '[TimeView].[TimeFiscalYear_MemberID] = [Time].[TimeFiscalYear_MemberID] AND [TimeView].[MemberId] <= [Time].[MemberId] AND '
									WHEN 'R12' THEN '[TimeView].[RowOrder] BETWEEN [Time].[RowOrder] - 11 AND [Time].[RowOrder] AND'
									ELSE '[TimeView].[MemberId] = [Time].[MemberId] AND ' END
							FROM
								(
								SELECT
									[Filter],
									[SortOrder]
								FROM
									#FilterTable FT
								WHERE
									FT.[StepReference] = @StepReference AND
									FT.[TupleNo] = @TupleNo AND
									FT.[DimensionTypeID] = 50
								UNION SELECT DISTINCT
									[Filter] = 'Periodic',
									[SortOrder] = 0
								FROM
									#FilterTable FT
								WHERE
									FT.[StepReference] = @StepReference AND
									FT.[TupleNo] = @TupleNo AND
									NOT EXISTS (SELECT 1 FROM #FilterTable CFT WHERE CFT.[StepReference] = @StepReference AND CFT.[TupleNo] = @TupleNo AND CFT.[DimensionTypeID] = 50)
								) sub
							ORDER BY
								sub.[SortOrder]


							--MultiDim Filter/Tuple
							IF @MultiDimIncludedYN <> 0
								BEGIN
									SELECT
										@MultiDim_Leaf_MemberId_csv = COALESCE(@MultiDim_Leaf_MemberId_csv + ',' , '') + CONVERT(NVARCHAR(15), M.[Leaf_MemberId])
									FROM
										#FilterTable FT
										INNER JOIN #MultiDim M ON M.[MultiDim_Filter] = FT.[Filter]
									WHERE
										FT.[StepReference] = @StepReference AND
										FT.[DimensionTypeID] = 27 AND
										FT.[TupleNo] = @TupleNo AND
										'T_' + ISNULL(FT.[ObjectReference], 'Tuple_' + CONVERT(nvarchar(15), FT.[TupleNo])) = @TupleName
									ORDER BY
										FT.[SortOrder]

									IF @DebugBM & 2 > 0 SELECT [@TupleName] = @TupleName, [@TupleNo] = @TupleNo, [@MultiDim_Leaf_MemberId_csv] = @MultiDim_Leaf_MemberId_csv

									SELECT
--  										@SQL_Tuple = @SQL_Tuple + 'DC.[' + FT.[DimensionName] + '_MemberID] ' + FT.[EqualityString] + ' (' + @MultiDim_Leaf_MemberId_csv + ') AND '
										@SQL_Tuple = case when FT.[EqualityString] = 'IN' then
                                                                @SQL_Tuple + ''',' + @MultiDim_Leaf_MemberId_csv + ','' LIKE N''%,'' + CAST(DC.[' + FT.[DimensionName] + '_MemberID] as NVARCHAR(MAX)) + N'',%'' AND '
                                                            else
                                                                @SQL_Tuple + 'DC.[' + FT.[DimensionName] + '_MemberID] ' + FT.[EqualityString] + ' (' + @MultiDim_Leaf_MemberId_csv + ') AND '
                                                            end
						            FROM
										#FilterTable FT
									WHERE
										FT.[DimensionName] IS NOT NULL AND
										FT.[EqualityString] IS NOT NULL AND
										FT.[StepReference] = @StepReference AND
										FT.[DimensionTypeID] = 27 AND
										FT.[TupleNo] = @TupleNo AND
										'T_' + ISNULL(FT.[ObjectReference], 'Tuple_' + CONVERT(nvarchar(15), FT.[TupleNo])) = @TupleName
									ORDER BY
										FT.[SortOrder]
								END

							SET @SQL_Tuple = LEFT(@SQL_Tuple, LEN(@SQL_Tuple) -4) + ' THEN ' + @Measure + '_Value ELSE 0 END), 4),'

							FETCH NEXT FROM Tuple_Cursor INTO @TupleNo, @TupleName, @MultiDimIncludedYN
						END

				CLOSE Tuple_Cursor
				DEALLOCATE Tuple_Cursor

				IF @DebugBM & 2 > 0 PRINT '>>>>>>>>> SET @SQL_Tuple = ' + @SQL_Tuple

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After get Tuple-clause', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)
			END

	SET @Step = 'Get string for Supress zero'
		IF @ResultTypeBM & 772 > 0 AND @RowList_SupressZeroYN <> 0
			BEGIN
				SELECT
					@SupressZeroString = @SupressZeroString + '[' + sub.[TupleName] + ']<>0 OR '
				FROM
					(
					SELECT DISTINCT
						[TupleNo] = FT.[TupleNo],
						[TupleName] = 'T_' + ISNULL(MAX(FT.[ObjectReference]), 'Tuple_' + CONVERT(nvarchar(15), FT.[TupleNo]))
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] = @StepReference AND
						FT.[TupleNo] > 0
					GROUP BY
						FT.[TupleNo]
					) sub
				ORDER BY
					sub.[TupleNo]

				IF @DebugBM & 2 > 0 SELECT [@SupressZeroString] = @SupressZeroString

				IF LEN(@SupressZeroString) > 0
					SET @SupressZeroString = ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '(' + LEFT(@SupressZeroString, LEN(@SupressZeroString) - 3) + ')'
				ELSE
					SET @SupressZeroString = ''
			END

	SET @Step = 'Get parts for SQL-statement'
		IF @ResultTypeBM & 812 > 0 --4, 8, 32, 64, 256, 512
			BEGIN
				IF @DebugBM & 2 > 0
					SELECT
						LoopQuery = 'SQL_SelectQuery_GrouBy',
						GB.*, FT.*
					FROM
						(
						SELECT
							[SortOrder] = MIN ([SortOrder]),
							[DimensionName],
							[TupleNo] = 0,
							[LoopNo] = MAX([LoopNo])
						FROM
							#GroupBy
						GROUP BY
							[DimensionName]
						) GB
						LEFT JOIN #FilterTable FT ON FT.[StepReference] = @StepReference AND (FT.[TupleNo] = GB.[TupleNo] OR GB.[TupleNo] = -1) AND FT.[DimensionName] = GB.[DimensionName]
					ORDER BY
						GB.[SortOrder]

				SELECT
					@SQL_Select1_DECLARE = @SQL_Select1_DECLARE + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN '[' + GB.[DimensionName] + '_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + GB.[DimensionName] + '_MemberId] bigint,' ELSE '[' + CASE WHEN GB.[DimensionName] = @TimeType THEN 'Time' ELSE GB.[DimensionName] END + '_MemberId] bigint,' END,
					@SQL_Select1_INSERT = @SQL_Select1_INSERT + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN '[' + GB.[DimensionName] + '_MemberKey],' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + GB.[DimensionName] + '_MemberId],' ELSE '[' + CASE WHEN GB.[DimensionName] = @TimeType THEN 'Time' ELSE GB.[DimensionName] END + '_MemberId],' END,

					@SQL_Select1 = @SQL_Select1 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN '[' + GB.[DimensionName] + '_MemberKey] = MAX(MD' + CONVERT(nvarchar(15), GB.[LoopNo]) + '.[Leaf_MemberKey]),' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + GB.[DimensionName] + '_MemberId] = MD' + CONVERT(nvarchar(15), GB.[LoopNo]) + '.[Leaf_MemberId],' ELSE '[' + CASE WHEN GB.[DimensionName] = @TimeType THEN 'Time' ELSE GB.[DimensionName] END + '_MemberId] = DC.[' + CASE WHEN GB.[DimensionName] = @TimeType THEN @TimeType ELSE GB.[DimensionName] END + '_MemberId],' END,
					@SQL_GroupBy1 = @SQL_GroupBy1 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN 'MD' + CONVERT(nvarchar(15), GB.[LoopNo]) + '.[Leaf_MemberID],' ELSE 'DC.[' + CASE WHEN GB.[DimensionName] = @TimeType THEN @TimeType ELSE GB.[DimensionName] END + '_MemberId],' END
				FROM
					(
					SELECT
						[SortOrder] = MIN ([SortOrder]),
						[DimensionName],
						[TupleNo] = 0,
						[LoopNo] = MAX([LoopNo])
					FROM
						#GroupBy
					GROUP BY
						[DimensionName]
					) GB
					LEFT JOIN #FilterTable FT ON FT.[StepReference] = @StepReference AND (FT.[TupleNo] = GB.[TupleNo] OR GB.[TupleNo] = -1) AND FT.[DimensionName] = GB.[DimensionName]
				ORDER BY
					GB.[SortOrder]

				SELECT
					@SQL_Select1_DECLARE = @SQL_Select1_DECLARE + '
					[' + @Measure + '_Value] float',
					@SQL_Select1_INSERT = @SQL_Select1_INSERT + '
					[' + @Measure + '_Value]'

				IF @DebugBM & 2 > 0 PRINT '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ' + @SQL_Select1_DECLARE + '
				' +@SQL_Select1_INSERT

				IF @DebugBM & 2 > 0
					BEGIN
					select [@StepReference] = @StepReference, [@TimeType] = @TimeType, [@RowList_DimensionID] = @RowList_DimensionID
					SELECT [Temp_#GroupBy] = '#GroupBy', * from #GroupBy ORDER BY SortOrder
					select [Temp_#FIlterTable] = '', [CASE_DimName] = CASE WHEN FT.[DimensionName] = @TimeType THEN 'Time' ELSE FT.[DimensionName] END , * from #FilterTable FT 
					where FT.[StepReference] = @StepReference AND
							FT.[TupleNo] = 0 AND
							FT.[DimensionID] <> ISNULL(@RowList_DimensionID, 0)

					SELECT
						[Query_@SQL_Select2 + @SQL_GroupBy2] = '@SQL_Select2 + @SQL_GroupBy2',
						GB.*
					FROM
						#GroupBy GB
						INNER JOIN #FilterTable FT ON
							FT.[StepReference] = @StepReference AND
							FT.[TupleNo] = 0 AND
							--FDB-2158 Fix
							CASE WHEN FT.[DimensionName] = @TimeType THEN 'Time' ELSE FT.[DimensionName] END = REPLACE(GB.[DimensionName], 'TimeDay', 'Time') AND
							--CASE WHEN FT.[DimensionName] = @TimeType THEN 'Time' ELSE FT.[DimensionName] END = GB.[DimensionName] AND 
							FT.[DimensionID] <> ISNULL(@RowList_DimensionID, 0)
					ORDER BY
						GB.[SortOrder]

					END

				SELECT
					@SQL_Select2 = @SQL_Select2 + CASE WHEN GB.[TupleNo] = 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN '[' + GB.[DimensionName] + '_MemberKey] = DC.[' + GB.[DimensionName] + '_MemberKey],' ELSE '[' + GB.[DimensionName] + '_' + REPLACE(GB.[PropertyName], 'Label', 'MemberKey') + '] = [' + REPLACE(GB.[DimensionName], 'TimeDay', 'Time') + '].[' + GB.[PropertyName] + '],' END ELSE '' END,
					@SQL_GroupBy2 = @SQL_GroupBy2 + CASE WHEN GB.[TupleNo] = 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN 'DC.[' + GB.[DimensionName] + '_MemberKey],' ELSE '[' + REPLACE(GB.[DimensionName], 'TimeDay', 'Time') + '].[' + GB.[PropertyName] + '],' END ELSE '' END
				FROM
					#GroupBy GB
					INNER JOIN #FilterTable FT ON
						FT.[StepReference] = @StepReference AND
						FT.[TupleNo] = 0 AND

						--FDB-2158 Fix
						CASE WHEN FT.[DimensionName] = @TimeType THEN 'Time' ELSE FT.[DimensionName] END = REPLACE(GB.[DimensionName], 'TimeDay', 'Time') AND
						--CASE WHEN FT.[DimensionName] = @TimeType THEN 'Time' ELSE FT.[DimensionName] END = GB.[DimensionName] AND 

						FT.[DimensionID] <> ISNULL(@RowList_DimensionID, 0)
				ORDER BY
					GB.[SortOrder]

				SELECT
					@SQLSelect128 = @SQLSelect128 + CASE WHEN GB.[TupleNo] = 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LI.[' + GB.[DimensionName] + '_MemberId],' ELSE '' END,
					@SQLJoin_128 = @SQLJoin_128 + CASE WHEN GB.[TupleNo] = 0 THEN ' LI.[' + GB.[DimensionName] + '_MemberId] = DC.[' + GB.[DimensionName] + '_MemberId] AND' ELSE '' END
				FROM
					#GroupBy GB
					INNER JOIN #FilterTable FT ON
						FT.[StepReference] = @StepReference AND
						FT.[TupleNo] = 0 AND
						--FT.[DimensionName] = GB.[DimensionName] AND
						CASE WHEN FT.[DimensionName] = @TimeType THEN 'Time' ELSE FT.[DimensionName] END = GB.[DimensionName] AND
						FT.[DimensionID] <> ISNULL(@RowList_DimensionID, 0)
						AND FT.[DimensionTypeID] <> 27	--Exclude MultiDim for LineItem queries
				ORDER BY
					GB.[SortOrder]

				SELECT
					@SQL_Join2 = @SQL_Join2 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] NOT IN (7, 27, 50) AND GB.[TupleNo] = 0 THEN 'LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + GB.[DimensionName] + '] [' + GB.[DimensionName] + '] ON [' + GB.[DimensionName] + '].MemberId = DC.[' + GB.[DimensionName] + '_MemberId]' ELSE '' END
				FROM
					(
					SELECT
						[SortOrder] = MIN ([SortOrder]),
						[DimensionName],
						[TupleNo] = 0
					FROM
						#GroupBy
					GROUP BY
						[DimensionName]
					) GB
					INNER JOIN #FilterTable FT ON FT.[StepReference] = @StepReference AND FT.[TupleNo] = 0 AND FT.[DimensionName] = GB.[DimensionName] AND FT.[DimensionID] <> ISNULL(@RowList_DimensionID, 0)
				--WHERE
				--	GB.[DimensionName] <> @HierarchyDimension OR @ResultTypeBM & 512 = 0
				ORDER BY
					GB.[SortOrder]

				IF LEN(@SQL_GroupBy1) > 1 SET @SQL_GroupBy1 = LEFT(@SQL_GroupBy1, LEN(@SQL_GroupBy1) - 1)
				IF LEN(@SQL_GroupBy2) > 1 SET @SQL_GroupBy2 = LEFT(@SQL_GroupBy2, LEN(@SQL_GroupBy2) - 1)

				IF @DebugBM & 2 > 0
					SELECT
						[@SQL_Select1] = @SQL_Select1,
						[@SQL_Select2] = @SQL_Select2,
						[@SQL_Tuple] = @SQL_Tuple,
						[@SQL_Join2] = @SQL_Join2,
						[@SQL_Where_Total] = @SQL_Where_Total,
						[@SQL_GroupBy1] = @SQL_GroupBy1,
						[@SQL_GroupBy2] = @SQL_GroupBy2
		END

	SET @Step = 'Set @TimePresentation'
		IF @ResultTypeBM & 772 > 0
			BEGIN
				SET @TimePresentation = ''
				IF (SELECT COUNT(1) FROM #GroupBy WHERE TupleNo = 0 AND DimensionName = 'Time' AND PropertyName = 'Label') > 0
					SET @TimePresentation = 'INNER JOIN #Time T ON T.[Label] = sub.[Time_MemberKey] AND T.[PresentationYN] <> 0'
				ELSE IF (SELECT COUNT(1) FROM #GroupBy WHERE TupleNo = 0 AND DimensionName = 'Time' AND PropertyName <> 'Label') > 0
					BEGIN
						SELECT @TimePropertyName =[PropertyName] FROM #GroupBy WHERE TupleNo = 0 AND DimensionName = 'Time' AND PropertyName <> 'Label'
						SET @TimePresentation = 'INNER JOIN #Time T ON T.[' + @TimePropertyName + '] = sub.[Time_' + @TimePropertyName + '] AND T.[PresentationYN] <> 0'
					END
			END

	SET @Step = '@ResultTypeBM & 12'
		IF @ResultTypeBM & 12 > 0
			BEGIN
				SELECT @WorkflowStateYN = COUNT(1) FROM #FilterTable WHERE TupleNo = 0 AND DimensionID = -63
				SELECT @AddScenarioYN = CASE WHEN (SELECT COUNT(1) FROM #GroupBy WHERE DimensionName = 'Scenario') = 0 AND (SELECT COUNT(1) FROM #FilterTable WHERE DimensionID = -6) > 0 AND @ResultTypeBM & 8 > 0 THEN 1 ELSE 0 END

				IF @DebugBM & 2 > 0
					SELECT
						[@WorkflowStateYN] = @WorkflowStateYN,
						[@AddScenarioYN] = @AddScenarioYN,
						[@SQL_Select1] = @SQL_Select1,
						[@Measure] = @Measure,
						[@SQL_Where_Total] = @SQL_Where_Total,
						[@SQL_MultiDimJoin] = @SQL_MultiDimJoin

				SET @SQLStatement = '
					SELECT' + @SQL_Select1 + CASE WHEN @AddScenarioYN <> 0 THEN '
						[Scenario_MemberID] = DC.[Scenario_MemberID],' ELSE '' END + '
						[' + @Measure + '_Value] = SUM(DC.[' + @Measure + '_Value])' + CASE WHEN @WorkflowStateYN <> 0 THEN ',
						[WorkflowStateID] = MAX(CONVERT(int, DC.[WorkFlowState_MemberId])),
						[Workflow_UpdatedBy_UserID] = 0' ELSE '' END + '
					INTO
						' + @TmpGlobalTable + '
					FROM
						[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC WITH (NOLOCK, INDEX([NCCSI_' + @DataClassName + ']))
						' + CASE WHEN LEN(@TimeFilterString) > 0 THEN 'INNER JOIN #Time T ON T.[MemberId] = ' + CASE WHEN @TimeDimensionTypeID = -49 THEN 'DC.[TimeDay_MemberId]' ELSE 'DC.[Time_MemberId]' END ELSE '' END + CASE WHEN @MultiDimYN <> 0 THEN @SQL_MultiDimJoin ELSE '' END + '
					WHERE
						' + @SQL_Where_Total + '
						1 = 1
					' + CASE WHEN LEN(@SQL_GroupBy1) > 0 THEN 'GROUP BY' + @SQL_GroupBy1 + CASE WHEN @AddScenarioYN <> 0 THEN ',
						DC.[Scenario_MemberID]' ELSE '' END ELSE '' END + '
					' + CASE WHEN LEN(@SQL_GroupBy1) > 0 AND @RowList_SupressZeroYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'HAVING
						SUM(DC.' + @Measure + '_Value) <> 0' ELSE '' END + '
					OPTION (RECOMPILE)'

					--OPTION (MAXDOP 1, RECOMPILE)'
					/*+ '
					HAVING
						SUM(DC.' + @Measure + '_Value) <> 0'*/

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0
					BEGIN
						SET @SQLStatement = 'SELECT TempTable = ''' + @TmpGlobalTable + ''', * FROM ' + @TmpGlobalTable
						EXEC (@SQLStatement)
					END

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After ResultTypeBM 12', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)
			END

	SET @Step = '@ResultTypeBM & 160'
		IF @ResultTypeBM & 160 > 0 AND @LineItemExistsYN <> 0--LineItem
			BEGIN
				IF @DebugBM & 2 > 0
					BEGIN
						SELECT [@ResultTypeBM] = 160, [@SQL_Where_160] = @SQL_Where_160
						PRINT @SQL_Where_160
					END

				SET @SQLStatement = '
					SELECT
						*
					INTO
						' + @TmpGlobalTable_32 + '
					FROM
						[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC WITH (NOLOCK, INDEX([NCCSI_' + @DataClassName + ']))
					WHERE
						' + @SQL_Where_160 + '
						1 = 1
					OPTION (RECOMPILE)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0
					BEGIN
						SET @SQLStatement = 'SELECT TempTable = ''' + @TmpGlobalTable_32 + ''', * FROM ' + @TmpGlobalTable_32

						PRINT @SQLStatement
						EXEC (@SQLStatement)
					END
			END

	SET @Step = '@ResultTypeBM & 4'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				IF @ResultTypeBM & 128 > 0 AND @LineItemExistsYN <> 0
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@ResultTypeBM] = 128
						SET @SQLStatement = '
							SELECT DISTINCT
								[Dummy] = 1, ' + LEFT(@SQLSelect128, LEN(@SQLSelect128) - 1) + '
							INTO
								' + @TmpGlobalTable_128 + '
							FROM
								' + @TmpGlobalTable_32 + ' LI
							WHERE
								[LI].[BusinessProcess_MemberId] = ' + CONVERT(nvarchar(10), @LineItemBP) + ' AND
								[LI].[LineItem_MemberId] <> -1'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
					END

				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 4,' + @SQL_Select2 + CASE WHEN @ResultTypeBM & 128 > 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN @LineItemExistsYN <> 0 THEN '[LineItemYN] = MAX(CASE WHEN LI.[Dummy] IS NOT NULL AND [TimeView].[MemberId] = [Time].[MemberId] THEN 1 ELSE 0 END),' ELSE '[LineItemYN] = 0,' END ELSE '' END + CASE WHEN @WorkflowStateYN <> 0 THEN '
						[WorkflowStateID] = ' + CASE WHEN LEN(@TimeFilterString) > 0 THEN 'MAX(CASE WHEN [TimeView].[MemberId] = [Time].[MemberId] THEN DC.WorkflowStateID ELSE -1 END)' ELSE 'MAX(DC.[WorkflowStateID])' END + ',
						[Workflow_UpdatedBy_UserID] = MAX(DC.[Workflow_UpdatedBy_UserID]),' ELSE '' END + @SQL_Tuple + '
						[' + @Measure + '_Value] = ' + CASE WHEN LEN(@TimeFilterString) > 0 THEN 'ROUND(SUM(CASE WHEN [TimeView].[MemberId] = [Time].[MemberId] THEN DC.[' + @Measure + '_Value] ELSE 0 END), 4)' ELSE 'ROUND(SUM(DC.[' + @Measure + '_Value]), 4)' END + '
					FROM
						' + @TmpGlobalTable + ' DC' + CASE WHEN LEN(@TimeFilterString) > 0 OR (SELECT COUNT(1) FROM #GroupBy WHERE DimensionName IN ('Time', 'TimeDay')) > 0 THEN '
						INNER JOIN #Time [TimeView] ON [TimeView].[MemberID] = DC.[Time_MemberId]
						INNER JOIN #Time [Time] ON 1 = 1' ELSE '' END + @SQL_Join2 + CASE WHEN @ResultTypeBM & 128 > 0 AND @LineItemExistsYN <> 0 THEN 'LEFT JOIN ' + @TmpGlobalTable_128 + ' [LI] ON' + LEFT(@SQLJoin_128, LEN(@SQLJoin_128) - 3) ELSE '' END + '
					' + CASE WHEN LEN(@SQL_GroupBy2) > 0 THEN 'GROUP BY' + @SQL_GroupBy2 + CASE WHEN @RowList_SupressZeroYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'HAVING
						' + CASE WHEN LEN(@TimeFilterString) > 0 THEN 'ROUND(SUM(CASE WHEN [TimeView].[MemberId] = [Time].[MemberId] THEN DC.[' + @Measure + '_Value] ELSE 0 END), 4)' ELSE 'ROUND(SUM(DC.[' + @Measure + '_Value]), 4)' END + ' <> 0' ELSE '' END ELSE '' END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 8'
		IF @ResultTypeBM & 8 > 0 --Changeable
			BEGIN
				SELECT
					@InputAllowedYN = S.[InputAllowedYN]
				FROM
					pcINTEGRATOR_Data.dbo.Scenario S
					INNER JOIN #FilterTable FT ON FT.DimensionID = -6 AND FT.TupleNo = 0 AND FT.[Filter] = S.MemberKey
				WHERE
					S.InstanceID = @InstanceID AND
                    S.VersionID = @VersionID AND
                    S.SelectYN <> 0

				IF @DebugBM & 2 > 0 SELECT [@InputAllowedYN] = @InputAllowedYN

				CREATE TABLE #WorkflowState
					(
					[WorkflowStateID] int,
					[Scenario_MemberKey] nvarchar(50),
					[Scenario_MemberId] bigint,
					[TimeFrom] int,
					[TimeTo] int
					)

				EXEC [spGet_WriteAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @AssignmentID = @AssignmentID, @DataClassID = @DataClassID

				SET @SQLStatement = '
					UPDATE WFS
					SET
						[Scenario_MemberId] = S.[MemberId]
					FROM
						#WorkflowState WFS
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Scenario] S ON S.[Label] = WFS.[Scenario_MemberKey]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#WorkflowState', * FROM #WorkflowState

				IF (SELECT COUNT(1) FROM #FilterTable FT WHERE FT.[StepReference] = @StepReference AND FT.[TupleNo] = 0 AND FT.[DimensionID] = -7) = 1
					SET @YearMonthColumn = 'DC.[Time_MemberId]'
				ELSE IF (SELECT COUNT(1) FROM #FilterTable FT WHERE FT.[StepReference] = @StepReference AND FT.[TupleNo] = 0 AND FT.[DimensionID] IN (-40, -11)) = 2
					SET @YearMonthColumn = 'DC.[TimeYear_MemberId] * 100 + DC.[TimeMonth_MemberId]'
				ELSE IF (SELECT COUNT(1) FROM #FilterTable FT WHERE FT.[StepReference] = @StepReference AND FT.[TupleNo] = 0 AND FT.[DimensionID] IN (-49)) = 1
					SET @YearMonthColumn = 'DC.[TimeDay_MemberId] / 100'

				CREATE TABLE [dbo].[#DC_Param]
					(
					[ParameterType] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[ParameterName] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Default_MemberID] [bigint],
					[Default_MemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Default_MemberDescription] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Visible] [bit],
					[Changeable] [bit],
					[Parameter] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[DataType] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FormatString] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Axis] [nvarchar](50),
					[Index] [int] IDENTITY(1,1)
					)

				INSERT INTO [#DC_Param]
					(
					[ParameterType],
					[ParameterName],
					[Default_MemberID],
					[Default_MemberKey],
					[Default_MemberDescription],
					[Visible],
					[Changeable],
					[Parameter],
					[DataType],
					[FormatString],
					[Axis]
					)
				SELECT
					ParameterType = 'Measure',
					ParameterName = @DataClassName,
					Default_MemberID = NULL,
					Default_MemberKey = NULL,
					Default_MemberDescription = M.MeasureDescription,
					Visible = 1,
					Changeable = 1,
					Parameter = @DataClassName,
					DataType = DT.DataTypePortal,
					FormatString = M.FormatString,
					Axis = 'Column'
				FROM
					Measure M
					INNER JOIN DataType DT ON DT.DataTypeID = M.DataTypeID
				WHERE
					M.DataClassID = @DataClassID AND
					M.SelectYN <> 0 AND
					M.DeletedID IS NULL
				ORDER BY
					M.SortOrder

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#DC_Param', * FROM #DC_Param

				DECLARE MeasureList_8_Cursor CURSOR FOR

					SELECT
						MeasureName = '[' + REPLACE([ParameterName], '_Value', '') + '_Value]'
					FROM
						#DC_Param
					WHERE
						ParameterType = 'Measure'
					ORDER BY
						[Index]

					OPEN MeasureList_8_Cursor
					FETCH NEXT FROM MeasureList_8_Cursor INTO @MeasureName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@MeasureName] = @MeasureName

							--SET @SQLMeasureList_8 = @SQLMeasureList_8 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)+ CHAR(9) + @MeasureName + ' = CASE WHEN MAX(WS.[WorkflowStateID]) IS NULL AND ' + CONVERT(nvarchar(15), @DataClassTypeID) + ' NOT IN (-6) THEN 0 ELSE 1 END,'
							--SET @SQLMeasureList_8 = @SQLMeasureList_8 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)+ CHAR(9) + @MeasureName + ' = CASE WHEN MAX(WS.[WorkflowStateID]) IS NULL AND ' + CASE WHEN LEN(@TimeFilterString) > 0 THEN 'MAX([Time].[MemberId]) NOT BETWEEN MAX(WSS.[TimeFrom]) AND MAX(WSS.[TimeTo]) AND ' ELSE '' END + CONVERT(nvarchar(15), @DataClassTypeID) + ' NOT IN (-6) THEN 0 ELSE 1 END,'
							--SET @SQLMeasureList_8 = @SQLMeasureList_8 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)+ CHAR(9) + @MeasureName + ' = CASE WHEN MAX(WS.[WorkflowStateID]) IS NULL AND ' + CASE WHEN @WorkflowStateYN <> 0 AND LEN(@TimeFilterString) > 0 THEN 'MAX([Time].[MemberId]) NOT BETWEEN MAX(WSS.[TimeFrom]) AND MAX(WSS.[TimeTo]) AND ' ELSE '' END + CONVERT(nvarchar(15), @DataClassTypeID) + ' NOT IN (-6) THEN 0 ELSE 1 END,'

							--SET @SQLMeasureList_8 = @SQLMeasureList_8 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)+ CHAR(9) + @MeasureName + ' = ' + CASE WHEN @InputAllowedYN = 0 THEN '0,' ELSE + 'CASE WHEN MAX(WS.[WorkflowStateID]) IS NULL AND ' + CASE WHEN @WorkflowStateYN <> 0 AND LEN(@TimeFilterString) > 0 THEN 'MAX([Time].[MemberId]) NOT BETWEEN MAX(ISNULL(WSS.[TimeFrom],-1)) AND MAX(ISNULL(WSS.[TimeTo],-1)) AND ' ELSE '' END + CONVERT(nvarchar(15), @DataClassTypeID) + ' NOT IN (-6) THEN 0 ELSE 1 END,' END
							SET @SQLMeasureList_8 = @SQLMeasureList_8 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)+ CHAR(9) + @MeasureName + ' = ' +
										CASE WHEN @InputAllowedYN = 0 THEN '0,'
										ELSE + 'CASE
												WHEN MAX(WS.[WorkflowStateID]) IS NULL ' +
														CASE WHEN @WorkflowStateYN <> 0 AND LEN(@TimeFilterString) > 0
														THEN 'AND MAX([Time].[MemberId]) NOT BETWEEN MAX(ISNULL(WSS.[TimeFrom],-1)) AND MAX(ISNULL(WSS.[TimeTo],-1)) '
														ELSE ''
														END +
													'AND ' + CONVERT(nvarchar(15), @DataClassTypeID) + ' NOT IN (-6)
												THEN 0
												ELSE ' +
													CASE WHEN @WorkflowStateYN <> 0 AND LEN(@TimeFilterString) > 0
													THEN 'CASE WHEN MAX(CASE WHEN [TimeView].[MemberId] = [Time].[MemberId] THEN DC.[WorkflowStateID] ELSE -1 END) BETWEEN MIN(WS.[WorkflowStateID]) AND MAX(WS.[WorkflowStateID]) OR MAX(CASE WHEN [TimeView].[MemberId] = [Time].[MemberId]
															THEN DC.[WorkflowStateID] ELSE -1 END) = -1 THEN 1  ELSE 0 END'
													ELSE '1'
													END + '
												END,'
										END

							FETCH NEXT FROM MeasureList_8_Cursor INTO @MeasureName
						END

				CLOSE MeasureList_8_Cursor
				DEALLOCATE MeasureList_8_Cursor

				SET @SQLMeasureList_8 = LEFT(@SQLMeasureList_8, LEN(@SQLMeasureList_8) - 1)

				IF @DebugBM & 2 > 0 SELECT [@SQLMeasureList_8] = @SQLMeasureList_8
/****
				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 8,' + @SQL_Select2 + CASE WHEN @WorkflowStateYN <> 0 THEN '
						[WorkflowStateID] = ' + CASE WHEN LEN(@TimeFilterString) > 0 THEN 'MAX(CASE WHEN [TimeView].[MemberId] = [Time].[MemberId] THEN DC.[WorkflowStateID] ELSE -1 END)' ELSE 'MAX(DC.[WorkflowStateID])' END + ',
						[Workflow_UpdatedBy_UserID] = MAX(DC.[Workflow_UpdatedBy_UserID]),' ELSE '' END + @SQL_Tuple + @SQLMeasureList_8 + '
					FROM
						' + @TmpGlobalTable + ' DC' + CASE WHEN LEN(@TimeFilterString) > 0 OR (SELECT COUNT(1) FROM #GroupBy WHERE DimensionName IN ('Time', 'TimeDay')) > 0 THEN '
						INNER JOIN #Time [TimeView] ON [TimeView].[MemberID] = DC.[Time_MemberId]
						INNER JOIN #Time [Time] ON 1 = 1' ELSE '' END + @SQL_Join2 + '
						' + CASE WHEN @WorkflowStateYN <> 0
							THEN '
						LEFT JOIN #WorkflowState WS ON WS.[WorkflowStateID] = DC.[WorkFlowStateID] AND [Time].[MemberID] BETWEEN WS.[TimeFrom] AND WS.[TimeTo] AND WS.[Scenario_MemberId] = DC.[Scenario_MemberId]
						LEFT JOIN #WorkflowState WSS ON WSS.[Scenario_MemberId] = DC.[Scenario_MemberId]'
							ELSE 'LEFT JOIN (SELECT [WorkFlowStateID]=1) WS ON 1 = 1'
							END + '
					' + CASE WHEN LEN(@SQL_GroupBy2) > 0 THEN 'GROUP BY' + @SQL_GroupBy2 + CASE WHEN @WorkflowStateYN <> 0 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[DC].[WorkflowStateID]' ELSE '' END + CASE WHEN @RowList_SupressZeroYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'HAVING
						' + CASE WHEN LEN(@TimeFilterString) > 0 THEN 'ROUND(SUM(CASE WHEN [TimeView].[MemberId] = [Time].[MemberId] THEN DC.[' + @Measure + '_Value] ELSE 0 END), 4)' ELSE 'ROUND(SUM(DC.[' + @Measure + '_Value]), 4)' END + ' <> 0' ELSE '' END ELSE '' END
*/

				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 8,' + @SQL_Select2 + CASE WHEN @WorkflowStateYN <> 0 THEN '
						[WorkflowStateID] = ' + CASE WHEN LEN(@TimeFilterString) > 0 THEN 'MAX(CASE WHEN [TimeView].[MemberId] = [Time].[MemberId] THEN DC.[WorkflowStateID] ELSE -1 END)' ELSE 'MAX(DC.[WorkflowStateID])' END + ',
						[Workflow_UpdatedBy_UserID] = MAX(DC.[Workflow_UpdatedBy_UserID]),' ELSE '' END + @SQL_Tuple + @SQLMeasureList_8 + '
					FROM
						' + @TmpGlobalTable + ' DC' + CASE WHEN LEN(@TimeFilterString) > 0 OR (SELECT COUNT(1) FROM #GroupBy WHERE DimensionName IN ('Time', 'TimeDay')) > 0 THEN '
						INNER JOIN #Time [TimeView] ON [TimeView].[MemberID] = DC.[Time_MemberId]
						INNER JOIN #Time [Time] ON 1 = 1' ELSE '' END + @SQL_Join2 + '
						' + CASE WHEN @WorkflowStateYN <> 0
							THEN '
						LEFT JOIN #WorkflowState WS ON WS.[WorkflowStateID] = DC.[WorkFlowStateID] AND [Time].[MemberID] BETWEEN WS.[TimeFrom] AND WS.[TimeTo] AND WS.[Scenario_MemberId] = DC.[Scenario_MemberId]
						LEFT JOIN #WorkflowState WSS ON WSS.[Scenario_MemberId] = DC.[Scenario_MemberId]'
							ELSE 'LEFT JOIN (SELECT [WorkFlowStateID]=1) WS ON 1 = 1'
							END + '
					' + CASE WHEN LEN(@SQL_GroupBy2) > 0 THEN 'GROUP BY' + @SQL_GroupBy2 + CASE WHEN @WorkflowStateYN <> 0 THEN CASE WHEN LEN(@TimeFilterString) > 0 THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[DC].[WorkflowStateID]' END ELSE '' END + CASE WHEN @RowList_SupressZeroYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'HAVING
						' + CASE WHEN LEN(@TimeFilterString) > 0 THEN 'ROUND(SUM(CASE WHEN [TimeView].[MemberId] = [Time].[MemberId] THEN DC.[' + @Measure + '_Value] ELSE 0 END), 4)' ELSE 'ROUND(SUM(DC.[' + @Measure + '_Value]), 4)' END + ' <> 0' ELSE '' END ELSE '' END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
		END

	SET @Step = '@ResultTypeBM & 32'
		IF @ResultTypeBM & 32 > 0 AND @LineItemExistsYN <> 0--LineItem
			BEGIN
				IF @DebugBM & 2 > 0
					BEGIN
						SELECT [@ResultTypeBM] = 32, [@SQL_Where_160] = @SQL_Where_160
						PRINT @SQL_Where_160
					END

				SET @SQLStatement = '
					SELECT
						*
					INTO
						' + @TmpGlobalTable_Text + '
					FROM
						[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_Text] DC
					WHERE
						' + @SQL_Where_160 + '
						1 = 1'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0
					BEGIN
						SET @SQLStatement = 'SELECT TempTable = ''' + @TmpGlobalTable_Text + ''', * FROM ' + @TmpGlobalTable_Text

						PRINT @SQLStatement
						EXEC (@SQLStatement)
					END

				SELECT
					@SQLSelect32 = @SQLSelect32 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + FT.[DimensionName] + '] = [' + FT.[DimensionName] + '].[Label],',
					@SQLSelect32_LIT = @SQLSelect32_LIT + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + FT.[DimensionName] + '_MemberId] = ' + CASE WHEN FT.[DimensionID] = -63 THEN 'MAX' ELSE '' END + '([sub1].[' + FT.[DimensionName] + '_MemberId]),',
					@SQLSelect32_S = @SQLSelect32_S + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + FT.[DimensionName] + '_MemberId] = [S].[' + FT.[DimensionName] + '_MemberId],',
					@SQLJoin_LIT = @SQLJoin_LIT + CASE WHEN FT.[DimensionID] NOT IN (-2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[LIT].[' + FT.[DimensionName] + '_MemberId] = [sub1].[' + FT.[DimensionName] + '_MemberId] AND' ELSE '' END,
					@SQLJoin_T = @SQLJoin_T + CASE WHEN FT.[DimensionID] NOT IN (-2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[T].[' + FT.[DimensionName] + '_MemberId] = [sub1].[' + FT.[DimensionName] + '_MemberId] AND' ELSE '' END,
					@SQLGroupBy32_LIT = @SQLGroupBy32_LIT + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionID] = -63 THEN '' ELSE '[sub1].[' + FT.[DimensionName] + '_MemberId],' END,
					@SQLSelect32_DC = @SQLSelect32_DC + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + FT.[DimensionName] + '_MemberId] = ' + CASE WHEN FT.[DimensionName] = 'LineItem' THEN '-1' ELSE '[DC].[' + FT.[DimensionName] + '_MemberId]' END + ',',
					@SQLSelect32_Sub = @SQLSelect32_Sub + CASE WHEN FT.[DimensionID] NOT IN (-27, -2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + FT.[DimensionName] + '_MemberId] = [LIT].[' + FT.[DimensionName] + '_MemberId],' ELSE '' END,
					@SQLJoin32_Sub = @SQLJoin32_Sub + CASE WHEN FT.[DimensionID] NOT IN (-27, -2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[LIT].[' + FT.[DimensionName] + '_MemberId] = [DC].[' + FT.[DimensionName] + '_MemberId] AND' ELSE '' END,
					@SQLJoin32_Callisto = @SQLJoin32_Callisto + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + FT.[DimensionName] + '] [' + FT.[DimensionName] + '] ON [' + FT.[DimensionName] + '].[MemberId] = sub.[' + FT.[DimensionName] + '_MemberId]'
				FROM
					#FilterTable FT
				WHERE
					FT.[StepReference] = @StepReference AND
					FT.[TupleNo] = 0 AND
					FT.[DimensionTypeID] NOT IN (27, 50)
				ORDER BY
					FT.[SortOrder]

				SELECT
					@SQLSelect32_S = LEFT(@SQLSelect32_S, LEN(@SQLSelect32_S) - 1),
					@SQLSelect32_Sub = LEFT(@SQLSelect32_Sub, LEN(@SQLSelect32_Sub) - 1),
					@SQLJoin_LIT = LEFT(@SQLJoin_LIT, LEN(@SQLJoin_LIT) - 4),
					@SQLJoin_T = LEFT(@SQLJoin_T, LEN(@SQLJoin_T) - 4),
					@SQLGroupBy32_LIT = LEFT(@SQLGroupBy32_LIT, LEN(@SQLGroupBy32_LIT) - 1),
					@SQLJoin32_Sub = LEFT(@SQLJoin32_Sub, LEN(@SQLJoin32_Sub) - 4)

				IF @DebugBM & 2 > 0 SELECT [@SQLSelect32] = @SQLSelect32, [@DataClassName] = @DataClassName

				SET @SQLStatement = '
	SELECT
		[ResultTypeBM] = 32,
		[Comment] = sub.[Comment],' + @SQLSelect32 + '
		[' + REPLACE(@DataClassName, '_Detail', '') + '_Value] = sub.[' + @DataClassName + '_Value],
		[UserID] = sub.[UserId],
		[ChangeDateTime] = sub.[ChangeDateTime]'

				SET @SQLStatement = @SQLStatement + '
	FROM
		(
		SELECT
			[Comment] = MAX([T].[' + @DataClassName + '_Text]),' + @SQLSelect32_LIT + '
			[' + @DataClassName + '_Value] = SUM([LIT].[' + @DataClassName + '_Value]),
			[UserID] = MAX(ISNULL([LIT].[UserId], [T].[UserId])),
			[ChangeDateTime] = MAX(ISNULL([LIT].[ChangeDateTime], [T].[ChangeDateTime]))'

				SET @SQLStatement = @SQLStatement + '
		FROM
			(
			SELECT DISTINCT' + @SQLSelect32_S + '
			FROM
				' + @TmpGlobalTable_32 + ' [S]

			UNION SELECT DISTINCT' + @SQLSelect32_S + '
			FROM
				' + @TmpGlobalTable_Text + ' [S]
			) [sub1]

			LEFT JOIN ' + @TmpGlobalTable_32 + ' [LIT] ON' + @SQLJoin_LIT + '

			LEFT JOIN ' + @TmpGlobalTable_Text + ' [T] ON' + @SQLJoin_T + '
		WHERE
			' + CASE WHEN @LineItemBP IS NOT NULL THEN '[sub1].BusinessProcess_MemberId = ' + CONVERT(nvarchar(10), @LineItemBP) + ' AND' ELSE '' END + '
			[sub1].[LineItem_MemberId] <> -1
		GROUP BY' + @SQLGroupBy32_LIT

				SET @SQLStatement = @SQLStatement + '

		UNION SELECT
			[Comment] = ''Master Row'',' + @SQLSelect32_DC + '
			[' + @DataClassName + '_Value] = [DC].[' + @DataClassName + '_Value],
			[UserID] = [DC].[UserId],
			[ChangeDateTime] = [DC].[ChangeDateTime]
		FROM
			' + @TmpGlobalTable_32 + ' [DC]'

				SET @SQLStatement = @SQLStatement + '

			INNER JOIN (
				SELECT DISTINCT' + @SQLSelect32_Sub + '
				FROM
					' + @TmpGlobalTable_32 + ' [LIT]
				WHERE
					' + CASE WHEN @LineItemBP IS NOT NULL THEN 'LIT.BusinessProcess_MemberId = ' + CONVERT(nvarchar(10), @LineItemBP) + ' AND' ELSE '' END + '
					LIT.[LineItem_MemberId] <> -1
				) LIT ON' + @SQLJoin32_Sub + CASE WHEN @LineItemBP IS NULL THEN '' ELSE '
		WHERE
			DC.LineItem_MemberId = -1' END

				SET @SQLStatement = @SQLStatement + '
		) sub' + @SQLJoin32_Callisto + '
	ORDER BY' + CASE WHEN @LineItemBP IS NULL THEN '' ELSE '
		[sub].[LineItem_MemberId]' END -- + @SQLOrderBy

				IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Return ResultTypeBM = 32'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Return ResultTypeBM = 32',
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement

				EXEC (@SQLStatement)
			END

	SET @Step = '@ResultTypeBM & 64, Comment'
		IF @ResultTypeBM & 64 > 0 AND @DataClassTypeID = -1
			BEGIN
				SET @SQLStatement = '
					SELECT @InternalVariable = COUNT(1) FROM ' + @CallistoDatabase + '.sys.tables WHERE [name] = ''FACT_' + @DataClassName + '_text'''

				EXEC sp_executesql @SQLStatement, N'@InternalVariable bit OUT', @InternalVariable = @TextTableExistsYN OUT

				IF @DebugBM & 2 > 0 SELECT [@TextTableExistsYN] = @TextTableExistsYN

				IF @TextTableExistsYN = 0 GOTO NoTextTable

				IF CURSOR_STATUS('global','RTBM64_Cursor') >= -1 DEALLOCATE RTBM64_Cursor
				DECLARE RTBM64_Cursor CURSOR FOR

					SELECT
						[DimensionID] = FT.[DimensionID],
						[DimensionName] = FT.[DimensionName],
						[HierarchyName] = FT.[HierarchyName],
						[PropertyNameFilter] = FT.[PropertyName],
						[PropertyNameGroupBY] = GB.[PropertyName],
						[Filter] = FT.[Filter],
						[EqualityString] = FT.[EqualityString],
						[StorageTypeBM] = FT.[StorageTypeBM],
--						[FilterLevel] = CASE WHEN FT.[PropertyName] IS NOT NULL THEN 'P' ELSE CASE WHEN GB.[DimensionName] IS NULL OR ISNULL(GB.[PropertyName], 'Label') <> 'Label' THEN 'LF' ELSE 'L' END END,
						[FilterLevel] = CASE WHEN GB.[DimensionName] IS NULL OR ISNULL(GB.[PropertyName], 'Label') <> 'Label' THEN 'LF' ELSE 'L' END,
						[GroupByYN] = CASE WHEN GB.[DimensionName] IS NOT NULL THEN 1 ELSE 0 END
					FROM
						#FilterTable FT
						LEFT JOIN #GroupBy GB ON GB.[DimensionName] = FT.[DimensionName] AND GB.[TupleNo] = FT.[TupleNo]
					WHERE
						FT.[DimensionTypeID] <> 27 AND
						--ISNULL(FT.[Filter], 'All_') <> 'All_' OR
						(FT.[Filter] IS NOT NULL OR
						GB.[DimensionName] IS NOT NULL)
					ORDER BY
						FT.[DimensionID]

					OPEN RTBM64_Cursor
					FETCH NEXT FROM RTBM64_Cursor INTO @DimensionID, @DimensionName, @HierarchyName, @PropertyNameFilter, @PropertyNameGroupBY, @Filter, @EqualityString, @StorageTypeBM, @FilterLevel, @GroupByYN

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID]=@DimensionID, [@DimensionName]=@DimensionName, [@HierarchyName]=@HierarchyName, [@PropertyNameFilter]=@PropertyNameFilter, [@PropertyNameGroupBY]=@PropertyNameGroupBY, [@Filter]=@Filter, [@EqualityString] = @EqualityString, [@StorageTypeBM]=@StorageTypeBM, [@FilterLevel]=@FilterLevel, [@GroupByYN]=@GroupByYN

							IF @Filter IS NOT NULL AND @PropertyNameFilter IS NULL
								BEGIN
									EXEC pcINTEGRATOR..spGet_LeafLevelFilter
										@UserID = @UserID,
										@InstanceID = @InstanceID,
										@VersionID = @VersionID,
										@DatabaseName = @CallistoDatabase,
										@DimensionID = @DimensionID,
										@HierarchyName = @HierarchyName,
										@Filter = @Filter,
										@StorageTypeBM_DataClass = @StorageTypeBM_DataClass,
										@StorageTypeBM = @StorageTypeBM,
										@FilterLevel = @FilterLevel,
										@FilterType = @FilterType,
										@LeafLevelFilter = @LeafLevelFilter OUT,
										@Debug = @DebugSub

									IF @DebugBM & 2 > 0 SELECT [@LeafLevelFilter] = @LeafLevelFilter

									IF LEN(@LeafLevelFilter) > 0
										SELECT @SQL_Where_64 = @SQL_Where_64 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.[' + @DimensionName + '_MemberId] ' + @EqualityString + ' (' + @LeafLevelFilter + ') AND'
								END

							IF @GroupByYN <> 0 OR @PropertyNameFilter IS NOT NULL
								BEGIN
									SELECT
										@SQL_Select64 = @SQL_Select64 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_' + CASE WHEN @PropertyNameGroupBY = 'Label' THEN @FilterType ELSE @PropertyNameGroupBY END + '] = ISNULL([' + @DimensionName + '].[' + @PropertyNameGroupBY + '],''NONE''),',
										@SQL_Join64 = @SQL_Join64 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN @PropertyNameFilter IS NOT NULL THEN 'INNER' ELSE 'LEFT' END + ' JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] ON [' + @DimensionName + '].MemberId = DC.[' + @DimensionName + '_MemberId]' + CASE WHEN @PropertyNameFilter IS NOT NULL THEN ' AND [' + @DimensionName + '].[' + @PropertyNameFilter + '] = ''' + @Filter + '''' ELSE '' END,
										@SQL_GroupBy64 = @SQL_GroupBy64 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'ISNULL([' + @DimensionName + '].[' + @PropertyNameGroupBY + '],''NONE''),'
								END


							FETCH NEXT FROM RTBM64_Cursor INTO @DimensionID, @DimensionName, @HierarchyName, @PropertyNameFilter, @PropertyNameGroupBY, @Filter, @EqualityString, @StorageTypeBM, @FilterLevel, @GroupByYN
						END

				CLOSE RTBM64_Cursor
				DEALLOCATE RTBM64_Cursor

				SET @SQL_GroupBy64 = LEFT(@SQL_GroupBy64, LEN(@SQL_GroupBy64) -1)

				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 64,' + @SQL_Select64 + '
						[Comment] = MAX([' + @DataClassName + '_Text])
					FROM
						' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_text] DC' + @SQL_Join64 + '
					WHERE' + @SQL_Where_64 + '
						DC.BusinessProcess_MemberId <> 118 AND
						LEN([' + @DataClassName + '_Text]) > 0
					' + CASE WHEN LEN(@SQL_GroupBy64) > 0 THEN 'GROUP BY' + @SQL_GroupBy64 ELSE '' END

				IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Return ResultTypeBM = 64'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Return ResultTypeBM = 64',
							@SQLStatement = @SQLStatement
					END

				ELSE IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Selected = @Selected + @@ROWCOUNT

				NoTextTable:
			END

	SET @Step = '@ResultTypeBM & 768 INTO @TmpGlobalTable'
		IF @ResultTypeBM & 768 > 0
			BEGIN
				IF @DebugBM & 2 > 0
					SELECT
						[@SQL_MultiDimJoin] = @SQL_MultiDimJoin

				IF @DebugBM & 64 > 0
					BEGIN
						SELECT [@MultiDimYN] = @MultiDimYN, [@SQL_MultiDimJoin] = @SQL_MultiDimJoin
						SELECT TempTable = '#Time', * FROM #Time
						SELECT TempTable = '#MultiDim', * FROM #MultiDim
						SET @SQLStatement = '
							SELECT
								' + @SQL_Select1 + '
								[' + @Measure + '_Value] = SUM(DC.[' + @Measure + '_Value])
							FROM
								[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC WITH (NOLOCK, INDEX([NCCSI_' + @DataClassName + ']))
								INNER JOIN #Time T ON T.[MemberId] = DC.[' + @TimeType + '_MemberId]' + CASE WHEN @MultiDimYN <> 0 THEN @SQL_MultiDimJoin ELSE '' END + '
							WHERE
								' + @SQL_Where_Total + '
								1 = 1
							GROUP BY
								' + @SQL_GroupBy1 + '
							HAVING
								ROUND(SUM(DC.' + @Measure + '_Value), 4) <> 0.0
							OPTION (RECOMPILE)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
							/*
							SELECT
						        [FullAccount_MemberKey] = MAX(MD1.[Leaf_MemberKey]),
						        [FullAccount_MemberId] = MD1.[Leaf_MemberId],
						        [Time_MemberId] = DC.[Time_MemberId],
								[Financials_Value] = SUM(DC.[Financials_Value])
							FROM
								[pcDATA_BRAD1].[dbo].[FACT_Financials_default_partition] DC WITH (NOLOCK, INDEX([NCCSI_Financials]))
								INNER JOIN #Time T ON T.[MemberId] = DC.[Time_MemberId]
						        INNER JOIN #MultiDim MD1 ON MD1.[DimensionName]='FullAccount'
							WHERE
								DC.[BusinessProcess_MemberID] IN (131,132,133,135,137,140,145,146,148,149,165,190,306,814,815,1001280,1001287,1002303,1002304,1002306,1002307,1002309,30000001,30000002,30000003,30000004,30000005,30000008,30000009,30000010,30000011,30000012,30000013,30000032,30000033,30000034,30000035,30000036,30000037,30000038,30000039,30000040,30000041,30000042,30000043,30000044,30000045,30000046,30000047,30000048,30000050,30000051,30000052,30000053,30000055,30000056,30000057,30000059,30000060,30000061,30000062,30000063,30000064,30000065,30000066,30000067,30000068,30000069,30000070,30000071,30000072,30000073,30000074,30000075,30000076,30000077,30000078,30000079,30000080,30000081,30000082) AND
                                DC.[Group_MemberID] IN (1001) AND
                                DC.[Currency_MemberID] IN (1016) AND
                                DC.[Entity_MemberID] IN (1062,1063,1064,1067,1068,1069,1070,1071,1072,1073,1074,1075,1076,1078,1079,1081,1082,1083,1084,1085,1086,1089,1094,1095,1096,1097,1098) AND
                                DC.[Scenario_MemberID] IN (110) AND
                                DC.[Version_MemberID] IN (-1) AND
								1 = 1
							GROUP BY
						        MD1.[Leaf_MemberID],
						        DC.[Time_MemberId]
							HAVING
								ROUND(SUM(DC.Financials_Value), 4) <> 0.0
							OPTION (RECOMPILE)
							*/
						RETURN
					END

				SET @SQLStatement = '
					SELECT
						' + @SQL_Select1 + '
						[' + @Measure + '_Value] = SUM(DC.[' + @Measure + '_Value])
					INTO
						' + @TmpGlobalTable + '
					FROM
						[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC WITH (NOLOCK, INDEX([NCCSI_' + @DataClassName + ']))
						INNER JOIN #Time T ON T.[MemberId] = DC.[' + @TimeType + '_MemberId]' + CASE WHEN @MultiDimYN <> 0 THEN @SQL_MultiDimJoin ELSE '' END + '
					WHERE
						' + @SQL_Where_Total + '
						1 = 1
					GROUP BY
						' + @SQL_GroupBy1 + '
					HAVING
						ROUND(SUM(DC.' + @Measure + '_Value), 4) <> 0.0
					OPTION (RECOMPILE)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				IF @DebugBM & 16 > 0 SELECT [Step] = 'Before insert to @TmpGlobalTable (256, 512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				EXEC (@SQLStatement)

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert to @TmpGlobalTable (256, 512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
				IF @DebugBM & 2 > 0 EXEC('SELECT TempTable = ''' + @TmpGlobalTable + ''', * FROM ' + @TmpGlobalTable)
			END

	SET @Step = '@ResultTypeBM & 256'
		IF @ResultTypeBM & 256 > 0
			BEGIN
				IF CURSOR_STATUS('global','RowListChildren_Cursor') >= -1 DEALLOCATE RowListChildren_Cursor
				DECLARE RowListChildren_Cursor CURSOR FOR
					SELECT
						[DimensionID],
						[DimensionName],
						[RowList_MemberKey] = [Filter],
						[LeafLevelFilter],
						[SortOrder]
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] = 'RowList' AND
						FT.[TupleNo] = 1 AND
						FT.[LeafLevelFilter] <> '-999'
					ORDER BY
						FT.[SortOrder]

					OPEN RowListChildren_Cursor
					FETCH NEXT FROM RowListChildren_Cursor INTO @DimensionID, @DimensionName, @RowListMemberKey, @LeafLevelFilter, @SortOrder

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@RowListMemberKey] = @RowListMemberKey, [@LeafLevelFilter] = @LeafLevelFilter, [@SortOrder] = @SortOrder

							TRUNCATE TABLE #FilterList

							INSERT INTO #FilterList
								(
								[Filter]
								)
							SELECT
								[Filter] = [Value]
							FROM
								STRING_SPLIT(@LeafLevelFilter, ',')

							IF @DebugBM & 2 > 0 SELECT [TempTable] = '#FilterList', * FROM #FilterList ORDER BY [SortOrder]

							SET @SQLStatement = '
								INSERT INTO #RowListChildren
									(
									[DimensionID],
									[DimensionName],
									[RowList_MemberID],
									[RowList_MemberKey],
									[RowList_Description],
									[Leaf_MemberId],
									[SortOrder]
									)
								SELECT
									[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID) + ',
									[DimensionName] = ''' + @DimensionName + ''',
									[RowList_MemberID] = S.[MemberId],
									[RowList_MemberKey] = ''' + @RowListMemberKey + ''',
									[RowList_Description] = S.[Description],
									[Leaf_MemberId] = FL.[Filter],
									[SortOrder] = ' + CONVERT(nvarchar(15), @SortOrder) + '
								FROM
									#FilterList FL
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] S ON S.[Label] = ''' + @RowListMemberKey + ''''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							FETCH NEXT FROM RowListChildren_Cursor INTO @DimensionID, @DimensionName, @RowListMemberKey, @LeafLevelFilter, @SortOrder
						END

				CLOSE RowListChildren_Cursor
				DEALLOCATE RowListChildren_Cursor

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#RowListChildren', * FROM #RowListChildren ORDER BY DimensionID, RowList_MemberId, Leaf_MemberId, [SortOrder]
				IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert to #RowListChildren (256)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				IF LEN(@SQL_Tuple) > 1 SET @SQL_Tuple = LEFT(@SQL_Tuple, LEN(@SQL_Tuple) -1)

				IF @DebugBM & 2 > 0 SELECT [@SQL_Tuple] = @SQL_Tuple

				SELECT @SQL_Join_RLC = @SQL_Join_RLC + '(RLC.[DimensionName]=''' + sub.[DimensionName] + ''' AND RLC.[Leaf_MemberID] = DC.[' + sub.[DimensionName] + '_MemberId]) OR'
				FROM
					(
					SELECT DISTINCT [DimensionName] FROM #RowListChildren
					) sub

				IF @DebugBM & 2 > 0 SELECT [@SQL_Join_RLC] = @SQL_Join_RLC

				IF LEN(@SQL_Join_RLC) >= 3
					SET @SQL_Join_RLC = LEFT(@SQL_Join_RLC, LEN(@SQL_Join_RLC) -3)

				IF @DebugBM & 32 > 0 SELECT [@SQL_Join_RLC] = @SQL_Join_RLC

				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 256,
						[RowList_MemberKey] = RLC.[RowList_MemberKey],
						[RowList_Description] = RLC.[RowList_Description]' + CASE WHEN LEN(@SQL_Select2) + LEN(@SQL_Tuple) = 0  THEN '' ELSE ', ' + @SQL_Select2 + @SQL_Tuple END + '
					FROM
						' + @TmpGlobalTable + ' DC
						INNER JOIN #RowListChildren RLC ON ' + CASE WHEN LEN(@SQL_Join_RLC) = 0 THEN '1=1' ELSE @SQL_Join_RLC END + '
						INNER JOIN #Time [TimeView] ON [TimeView].[MemberID] = DC.[' + @TimeType + '_MemberId]
						INNER JOIN #Time [Time] ON 1 = 1' + @SQL_Join2 + '
					GROUP BY
						RLC.[RowList_MemberKey],
						RLC.[RowList_Description]' + @SQL_GroupBy2 + '
					ORDER BY
						MAX(RLC.[SortOrder]),
						RLC.[RowList_MemberKey],
						RLC.[RowList_Description]' + @SQL_GroupBy2

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
				SET @Selected = @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 512'
		IF @ResultTypeBM & 512 > 0
			BEGIN
				CREATE TABLE #Hierarchy
					(
					[MemberId] bigint,
					[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[ParentMemberId] bigint,
					[Level] int,
					[NodeTypeBM] int,
					[Path] nvarchar(1000) COLLATE DATABASE_DEFAULT
					)

				TRUNCATE TABLE #PipeStringSplit

				EXEC [dbo].[spGet_PipeStringSplit]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@PipeString = @RowList

				IF @DebugBM & 2 > 0 SELECT TempTable = '#PipeStringSplit', * FROM #PipeStringSplit

				SELECT
					@HierarchyDimension = CASE WHEN CHARINDEX(':', [PipeObject]) = 0 THEN [PipeObject] ELSE LEFT([PipeObject], CHARINDEX(':', [PipeObject]) -1) END,
					@HierarchyHierarchy = CASE WHEN CHARINDEX(':', [PipeObject]) = 0 THEN [PipeObject] ELSE SUBSTRING([PipeObject], CHARINDEX(':', [PipeObject]) + 1, LEN([PipeObject])) END,
					@HierarchyTopMember = ISNULL([PipeFilter], 'All_')
				FROM
					#PipeStringSplit
				WHERE
					[PipeObject] NOT IN ('SupressZeroYN', 'ShowLevel', 'ExcludeStartNodeYN', 'ExcludeSumMemberYN', 'ParentSorting')

				IF @HierarchyHierarchy = '0' SET @HierarchyHierarchy = @HierarchyDimension

				IF ISNUMERIC(@HierarchyHierarchy) <> 0
					SELECT
						@HierarchyHierarchy = DH.[HierarchyName]
					FROM
						[pcINTEGRATOR].[dbo].[Dimension] D
						INNER JOIN [pcINTEGRATOR].[dbo].[DimensionHierarchy] DH ON DH.[InstanceID] = @InstanceID AND DH.[VersionID] = @VersionID AND DH.[DimensionID] = D.[DimensionID] AND CONVERT(nvarchar(15), DH.[HierarchyNo]) = @HierarchyHierarchy
					WHERE
						D.[InstanceID] IN (0, @InstanceID) AND
						D.[DimensionName] = @HierarchyDimension AND
						D.[SelectYN] <> 0 AND
						D.[DeletedID] IS NULL

				SELECT
					@GroupByLeafLevelYN = CASE WHEN COUNT(1) > 0 THEN 1 ELSE 0 END
				FROM
					#GroupBy
				WHERE
					[TupleNo] = 0 AND
					[DimensionName] <> @HierarchyDimension

				IF @DebugBM & 2 > 0
					SELECT
						[@HierarchyDimension] = @HierarchyDimension,
						[@HierarchyHierarchy] = @HierarchyHierarchy,
						[@HierarchyTopMember] = @HierarchyTopMember,
						[@RowList_SupressZeroYN] = @RowList_SupressZeroYN,
						[@RowList_ShowLevel] = @RowList_ShowLevel,
						[@RowList_ExcludeStartNodeYN] = @RowList_ExcludeStartNodeYN,
						[@RowList_ExcludeSumMemberYN] = @RowList_ExcludeSumMemberYN,
						[@RowList_ParentSorting] = @RowList_ParentSorting,
						[@GroupByLeafLevelYN] = @GroupByLeafLevelYN

				SET @SQLStatement = '
					SELECT
						@InternalVariable = d.[MemberId]
					FROM
						[' + @CallistoDatabase + '].[dbo].[S_DS_' + @HierarchyDimension + '] d
					WHERE
						d.[Label] = ''' + @HierarchyTopMember + ''''

				EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @HierarchyTopMemberId OUT

				SET @SQLStatement = '
					;WITH cte AS
					(
					SELECT
						[MemberId] = h.[MemberId],
						[ParentMemberId] = h.[ParentMemberId],
						[SortOrder] = h.[SequenceNumber],
						[Depth] = 0,
						[Path] = RIGHT(''0000'' + CONVERT(nvarchar(MAX), h.[SequenceNumber]), 5)
					FROM
						[' + @CallistoDatabase + '].[dbo].[S_HS_' + @HierarchyDimension + '_' + @HierarchyHierarchy + '] h
					WHERE
						h.[MemberId] = ' + CONVERT(nvarchar(20), @HierarchyTopMemberId) + '
					UNION ALL
					SELECT
						[MemberId] = h.[MemberId],
						[ParentMemberId] = h.[ParentMemberId],
						[SortOrder] = h.[SequenceNumber],
						[Depth] = c.[Depth] + 1,
						[Path] = c.[Path] + N''|'' + RIGHT(''0000'' + CONVERT(nvarchar(MAX), h.[SequenceNumber]), 5)
					FROM
						[' + @CallistoDatabase + '].[dbo].[S_HS_' + @HierarchyDimension + '_' + @HierarchyHierarchy + '] h
						INNER JOIN cte c on c.[MemberId] = h.[ParentMemberId]
					)
					INSERT INTO #Hierarchy
						(
						[MemberId],
						[MemberKey],
						[Description],
						[ParentMemberId],
						[Level],
						[NodeTypeBM],
						[Path]
						)
					SELECT
						[MemberId] = d.[MemberId],
						[MemberKey] = d.[Label],
						[Description] = d.[Description],
						[ParentMemberId] = c.[ParentMemberId],
						[Level] = c.[Depth],
						[NodeTypeBM] = CASE WHEN d.[RNodeType] LIKE ''%L%'' THEN 1 ELSE 2 END,
						[Path] = c.[Path]
					FROM
						[' + @CallistoDatabase + '].[dbo].[S_DS_' + @HierarchyDimension + '] d
						INNER JOIN cte c ON c.MemberId = d.MemberId'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				IF @DebugBM & 16 > 0 SELECT [Step] = 'Before CTE insert to #Hierarchy (512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				EXEC(@SQLStatement)

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After CTE insert to #Hierarchy (512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				IF @DebugBM & 2 > 0
					BEGIN
						SET @SQLStatement = 'SELECT TempTable = ''#Hierarchy'', * FROM #Hierarchy ORDER BY [Path] '
						EXEC(@SQLStatement)
						SET @SQLStatement = 'SELECT TempTable = ''#Hierarchy'', * FROM #Hierarchy ORDER BY [MemberId] '
						EXEC(@SQLStatement)

						PRINT '>>>>>>>>>>>>>@SQL_Tuple:		' + @SQL_Tuple
					END

				IF @GroupByLeafLevelYN <> 0
					BEGIN
						INSERT INTO #Hierarchy
							(
							[MemberId],
							[MemberKey],
							[Description],
							[ParentMemberId],
							[Level],
							[NodeTypeBM],
							[Path]
							)
						SELECT
							[MemberId],
							[MemberKey],
							[Description],
							[ParentMemberId],
							[Level],
							[NodeTypeBM] = 2,
							[Path]
						FROM
							#Hierarchy H
						WHERE
							NodeTypeBM = 1

						UPDATE H
						SET
							[Level] = H.[Level] + 1,
							[ParentMemberId] = H.[MemberId]
						FROM
							#Hierarchy H
						WHERE
							NodeTypeBM = 1

						IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Hierarchy_GroupByLeafLevel', * FROM #Hierarchy ORDER BY [MemberId]
					END

				EXEC [spPortalGet_CreateTableScript] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DBName = 'tempdb', @SchemaName = 'dbo', @TableName = @TmpGlobalTable, @SQLScript_OUT = @SQLScript_Result OUTPUT
				select @SQLScript_Result = 'DECLARE @DC_Table TABLE' + CHAR(13) + RIGHT(@SQLScript_Result, LEN(@SQLScript_Result) + 1 - CHARINDEX('(', @SQLScript_Result))

				SET @SQLStatement = '
					DECLARE @Hierarchy_Table TABLE
						(
						[MemberId] bigint,
						[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
						[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
						[ParentMemberId] bigint,
						[Level] int,
						[NodeTypeBM] int,
						[Path] nvarchar(1000) COLLATE DATABASE_DEFAULT
						)

					' + @SQLScript_Result + '

					INSERT INTO @Hierarchy_Table (
						[MemberId],
						[MemberKey],
						[Description],
						[ParentMemberId],
						[Level],
						[NodeTypeBM],
						[Path]
					)
					SELECT
						[MemberId],
						[MemberKey],
						[Description],
						[ParentMemberId],
						[Level],
						[NodeTypeBM],
						[Path]
					FROM
						#Hierarchy

					INSERT INTO @DC_Table(
						'
						+ @SQL_Select1_INSERT +
						'
						)
					SELECT
						'
						+ @SQL_Select1_INSERT +
						'
					FROM ' + @TmpGlobalTable + '

					-- add Leafs
					SELECT
						[RowList_MemberID] = H.[MemberID],
						[RowList_MemberKey] = MAX(H.[MemberKey]),
						[RowList_Description] = MAX(H.[Description]),'

				SET @SQLStatement =	@SQLStatement + @SQL_Select2

				SET @SQLStatement =	@SQLStatement + @SQL_Tuple

				SET @SQLStatement =	@SQLStatement + '
						[ParentMemberId] = MAX(H.[ParentMemberId]),
						[Level] = H.[Level],
						[NodeTypeBM] = H.[NodeTypeBM],
						[Path] = MAX(H.[Path])
					INTO ' + @TmpGlobalTable_2 + '
					FROM
						@Hierarchy_Table H
						LEFT JOIN @DC_Table DC ON DC.[' + @HierarchyDimension + '_MemberId] = H.MemberID
						LEFT JOIN #Time [TimeView] ON [TimeView].[MemberID] = DC.[Time_MemberId]
						LEFT JOIN #Time [Time] ON 1 = 1
						'  + @SQL_Join2 + '
					WHERE H.NodeTypeBM & 1 > 0
					GROUP BY
						H.[MemberID],
						H.[Level],
						H.[NodeTypeBM]' + CASE WHEN LEN(@SQL_GroupBy2) > 0 THEN ',' ELSE '' END + @SQL_GroupBy2 + '
					OPTION(RECOMPILE)

					-- add Parents
					INSERT INTO ' + @TmpGlobalTable_2 + '(
															[RowList_MemberID],
															[RowList_MemberKey],
															[RowList_Description],
															[ParentMemberId],
															[Level],
															[NodeTypeBM],
															[Path]
														)
					SELECT
						[RowList_MemberID] = H.[MemberID],
						[RowList_MemberKey] = MAX(H.[MemberKey]),
						[RowList_Description] = MAX(H.[Description]),
						[ParentMemberId] = MAX(H.[ParentMemberId]),
						[Level] = H.[Level],
						[NodeTypeBM] = H.[NodeTypeBM],
						[Path] = MAX(H.[Path])
					FROM
						@Hierarchy_Table H
						LEFT JOIN @DC_Table DC ON DC.[' + @HierarchyDimension + '_MemberId] = H.MemberID
						LEFT JOIN #Time [TimeView] ON [TimeView].[MemberID] = DC.[Time_MemberId]
						LEFT JOIN #Time [Time] ON 1 = 1
						'  + @SQL_Join2 + '
					WHERE H.NodeTypeBM & 2 > 0
					GROUP BY
						H.[MemberID],
						H.[Level],
						H.[NodeTypeBM]
					OPTION(RECOMPILE)'

--' + @SQL_Join2 + '

				IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; @ResultTypeBM = 512, INSERT INTO @TmpGlobalTable_2' + @TmpGlobalTable_2
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = '@ResultTypeBM = 512, INSERT INTO @TmpGlobalTable_2',
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement


				IF @DebugBM & 16 > 0 SELECT [Step] = 'Before insert to @TmpGlobalTable_2 (512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
				EXEC(@SQLStatement)
				IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert to @TmpGlobalTable_2 (512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				IF @DebugBM & 2 > 0 EXEC ('SELECT TempTable=''' + @TmpGlobalTable_2 + ''', Step=1, * FROM ' + @TmpGlobalTable_2)

				--'Aggregation_Cursor'
				CREATE TABLE #Aggregation_Cursor_Table
					(
					[Level] int,
					[MemberId] bigint
					)

				SET @SQLStatement = '
					INSERT INTO #Aggregation_Cursor_Table
						(
						[Level],
						[MemberId]
						)
					SELECT DISTINCT
						[Level],
						[MemberId] = [RowList_MemberId]
					FROM
						' + @TmpGlobalTable_2 + '
					WHERE
						NodeTypeBM & 2 > 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Aggregation_Cursor_Table', * FROM #Aggregation_Cursor_Table
				IF @DebugBM & 16 > 0 SELECT [Step] = 'After inserting into #Aggregation_Cursor_Table (512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				SELECT
					@AggregationSet = @AggregationSet + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + sub.[ObjectReference] + '] = sub.[' + sub.[ObjectReference] + '],',
					@AggregationSum = @AggregationSum + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + sub.[ObjectReference] + '] = SUM([' + sub.[ObjectReference] + ']),'
				FROM
					(
					SELECT
						[ObjectReference] = 'T_' + FT.[ObjectReference],
						[SortOrder] = MAX(FT.[TupleNo])
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] = @StepReference AND
						FT.[ObjectReference] IS NOT NULL
					GROUP BY
						FT.[ObjectReference]
					) sub
				ORDER BY
					sub.[SortOrder]

				SELECT
					@AggregationSet = CASE WHEN LEN(@AggregationSet) > 1 THEN LEFT(@AggregationSet, LEN(@AggregationSet) - 1) ELSE '' END,
					@AggregationSum = CASE WHEN LEN(@AggregationSum) > 1 THEN LEFT(@AggregationSum, LEN(@AggregationSum) - 1) ELSE '' END

				--IF @DebugBM & 16 > 0 SELECT [Step] = 'Before declare cursor Aggregation_Cursor (512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				--IF CURSOR_STATUS('global','Aggregation_Cursor') >= -1 DEALLOCATE Aggregation_Cursor
				--DECLARE Aggregation_Cursor CURSOR FOR

				--	SELECT DISTINCT
				--		[Level],
				--		[MemberId]
				--	FROM
				--		#Aggregation_Cursor_Table
				--	ORDER BY
				--		[Level] DESC,
				--		[MemberId]

				IF @DebugBM & 16 > 0 SELECT [Step] = 'Before created aggregations (512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)


			--SET @SQLStatement = 'SELECT * INTO _sega_CBN_TmpGlobalTable_2_before from ' + @TmpGlobalTable_2
 			--	EXEC(@sqlstatement)
 			--	SET @SQLStatement = 'SELECT * INTO _sega_CBN_Aggregation_Cursor_Table from #Aggregation_Cursor_Table'
 			--	EXEC(@sqlstatement)
				IF @DebugBM & 2 > 0 EXEC ('SELECT TempTable=''' + @TmpGlobalTable_2 + ''', Step=2, * FROM ' + @TmpGlobalTable_2)

				IF LEN(@AggregationSet) > 0
					BEGIN
						DECLARE @MaxLevel INT
						DECLARE @CurLevel INT
						SET @SQLStatement = 'SELECT @mx = MAX(Level) FROM ' + @TmpGlobalTable_2
						EXECUTE sp_executesql @SQLStatement, N'@mx int OUTPUT', @mx = @MaxLevel OUTPUT

						SET @CurLevel = COALESCE(@MaxLevel, -1)
						WHILE @CurLevel >=0
							BEGIN
								SET @SQLStatement = '
									UPDATE RS2
									SET
										' + @AggregationSet + '
									FROM
										' + @TmpGlobalTable_2 + ' RS2
									JOIN #Aggregation_Cursor_Table ACUR2 on ACUR2.[MemberId] = RS2.[RowList_MemberID]
									JOIN
											(
											SELECT
												[ParentMemberID],
												' + @AggregationSum + '
											FROM
												' + @TmpGlobalTable_2 + ' RS1
											JOIN #Aggregation_Cursor_Table ACUR1 on ACUR1.[MemberId] = RS1.[ParentMemberId]
											WHERE RS1.Level = ' + CAST(@CurLevel AS VARCHAR(255)) + '
											GROUP BY [ParentMemberId]) sub ON sub.[ParentMemberID] = RS2.[RowList_MemberID]
									WHERE
										RS2.[NodeTypeBM] <> 1
									OPTION(RECOMPILE)'

								IF @DebugBM & 32 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @CurLevel = @CurLevel - 1
							END
					END

				IF @DebugBM & 2 > 0 EXEC ('SELECT TempTable=''' + @TmpGlobalTable_2 + ''', Step=3, * FROM ' + @TmpGlobalTable_2)

				--IF @DebugBM & 16 > 0 SELECT [Step] = 'Before exec (512): ' + @SQLStatement, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				--	EXEC(@SQLStatement)

				--IF @DebugBM & 16 > 0 SELECT [Step] = 'Before open cursor into Aggregation_Cursor (512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				--	OPEN Aggregation_Cursor
				--	FETCH NEXT FROM Aggregation_Cursor INTO @Level, @MemberId

				--	WHILE @@FETCH_STATUS = 0
				--		BEGIN
				--			IF @DebugBM & 32 > 0 SELECT [@Level]=@Level, [@MemberId] = @MemberId

				--			IF LEN(@AggregationSet) > 0
				--				BEGIN
				--					SET @SQLStatement = '
				--						UPDATE RS
				--						SET
				--							' + @AggregationSet + '
				--						FROM
				--							' + @TmpGlobalTable_2 + ' RS
				--							INNER JOIN
				--								(
				--								SELECT
				--									' + @AggregationSum + '
				--								FROM
				--									' + @TmpGlobalTable_2 + '
				--								WHERE
				--									[ParentMemberID] = ' + CONVERT(nvarchar(15), @MemberID) + '
				--								) sub ON 1 = 1
				--						WHERE
				--							RS.[RowList_MemberID] = ' + CONVERT(nvarchar(15), @MemberID) + ' AND
				--							RS.[NodeTypeBM] <> 1
				--						OPTION(RECOMPILE)'

				--					IF @DebugBM & 32 > 0 PRINT @SQLStatement
				--					EXEC (@SQLStatement)
				--				END

				--			FETCH NEXT FROM Aggregation_Cursor INTO @Level, @MemberId
				--		END

				--CLOSE Aggregation_Cursor
				--DEALLOCATE Aggregation_Cursor

 				--SET @SQLStatement = 'SELECT * INTO _sega_CBN_TmpGlobalTable_2_after from ' + @TmpGlobalTable_2
 				--EXEC(@sqlstatement)

				IF @DebugBM & 16 > 0 SELECT [Step] = 'After created aggregations (512)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 512,
						sub.*
					FROM
						(
						SELECT DISTINCT
							T.*,
							[DESC] = CASE WHEN [Section].[ParentMemberId] = T.[ParentMemberId] THEN LEFT([Path], LEN([Path])-5) ELSE [Path] END,
							[Sequence] = RIGHT([Path], 5)
						FROM
							' + @TmpGlobalTable_2 + ' T
							LEFT JOIN
								(
								SELECT
									[ParentMemberId]
								FROM
									' + @TmpGlobalTable_2 + '
								GROUP BY
									[ParentMemberId]
								--HAVING
								--	COUNT(1) > 1
								) [Section] ON  [Section].[ParentMemberId] = T.[ParentMemberId] --IN (T.[ParentMemberId], T.[RowList_MemberID])
						WHERE
							([Level] <> 0 OR ' + CONVERT(nvarchar(15), CONVERT(int, @RowList_ExcludeStartNodeYN)) + ' = 0) AND
							([Level] <= ' + CONVERT(nvarchar(15), @RowList_ShowLevel) + ' OR ' + CONVERT(nvarchar(15), @RowList_ShowLevel) + ' = 0) AND
							([Level] = ' + CONVERT(nvarchar(15), @RowList_ShowLevel) + ' OR ([NodeTypeBM] & 1 > 0 AND [Level] < ' + CONVERT(nvarchar(15), @RowList_ShowLevel) + ') OR ' + CONVERT(nvarchar(15), CONVERT(int, @RowList_ExcludeSumMemberYN)) + ' = 0)' + @SupressZeroString + '
						) sub
					ORDER BY
						' + CASE WHEN @RowList_ParentSorting = 'After' THEN '[DESC] DESC, [Sequence] ASC' ELSE '[Path]' END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #FilterTable
		DROP TABLE #Time

		SET @TableObject = 'TempDB.dbo.' + @TmpGlobalTable
		IF OBJECT_ID(@TableObject, N'U') IS NOT NULL
			BEGIN
				SET @SQLStatement = 'DROP TABLE ' + @TmpGlobalTable EXEC (@SQLStatement)
			END

		SET @TableObject = 'TempDB.dbo.' + @TmpGlobalTable_2
		IF OBJECT_ID(@TableObject, N'U') IS NOT NULL
			BEGIN
				SET @SQLStatement = 'DROP TABLE ' + @TmpGlobalTable_2 EXEC (@SQLStatement)
			END

		SET @TableObject = 'TempDB.dbo.' + @TmpGlobalTable_32
		IF OBJECT_ID(@TableObject, N'U') IS NOT NULL
			BEGIN
				SET @SQLStatement = 'DROP TABLE ' + @TmpGlobalTable_32 EXEC (@SQLStatement)
			END

		SET @TableObject = 'TempDB.dbo.' + @TmpGlobalTable_128
		IF OBJECT_ID(@TableObject, N'U') IS NOT NULL
			BEGIN
				SET @SQLStatement = 'DROP TABLE ' + @TmpGlobalTable_128 EXEC (@SQLStatement)
			END

		SET @TableObject = 'TempDB.dbo.' + @TmpGlobalTable_Text
		IF OBJECT_ID(@TableObject, N'U') IS NOT NULL
			BEGIN
				SET @SQLStatement = 'DROP TABLE ' + @TmpGlobalTable_Text EXEC (@SQLStatement)
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GETDATE() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()

	IF @ErrorNumber = 308
		BEGIN
			SET @InfoMessage = 'Index is now recreating. Try to run the report in couple of minutes.';
			THROW 51000, @InfoMessage, 2;
		END

		--BEGIN
		--	SET @ErrorMessage = 'Index is now recreating. Try to run the report in couple of minutes.'
		--	SET @ErrorNumber = 51000
		--	SET @Severity = 16
		--	SET @ErrorState = 2
		--END

	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
