SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_DataClass_Data_Tuple]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@Filter nvarchar(max) = NULL,
	@ResultTypeBM int = NULL, --1 = Filter, 2 = Filter rows, 4 = Data - Leaf level, 8 = Changeable, 16 = Last Actor UserID, 32 = LineItem, 64 = Comment, 128=Add column LineItemYN to ResultTypeBM = 4, 256=Category, 512=Hierarchy

--	@MasterDataClassID int = NULL, --If set @DataClassID is of type SpreadingKey

	@GroupBy nvarchar(1024) = NULL,
	@Measure nvarchar(1024) = NULL,
	@PropertyList nvarchar(1024) = NULL,
	@DimensionList nvarchar(1024) = NULL,
	@Hierarchy nvarchar(1024) = NULL, --Only for backwards compatibility (not valid for tuples). Use colon in filterstring.
	@FilterLevel64 nvarchar(3) = NULL, --Valid for ResultTypeBM = 64 and 128; L=LeafLevel, P=Parent, LF=LevelFilter (not up or down), LLF=LevelFilter + all members below
	@OnlyDataClassDimMembersYN bit = 1, --Valid for @ResultTypeBM = 2
	@Parent_MemberKey nvarchar(1024) = NULL, --Valid for @ResultTypeBM = 2, Sample: 'GL_Student_ID=All_' Separator=|

	@ActingAs int = NULL, --Optional (OrganizationPositionID)
	@AssignmentID int = NULL,
	@WorkFlowStateID int = NULL,
	@OnlySecuredDimYN bit = 0,
	@ShowAllMembersYN bit = 0,
	@UseCacheYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000464,
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
EXEC [spPortalGet_DataClass_Data_Tuple]
	@UserID = -10,
	@InstanceID = 561,
	@VersionID = 1044,
	@DataClassID = 13956,
	@CallistoDatabase = 'pcDATA_DNKLY',
	@GroupBy='FullAccount',
	@Hierarchy='Version=1',
	@Filter = 'FullAccount:Department=All_|Version=NONE;§Actual 202102|Scenario=ACTUAL|Time=202102;§Budget 202202|Scenario=BUDGET|Time=202202;§Budget 2022|Scenario=BUDGET|Time=FY2022',
	@DebugBM = 3,
	@ResultTypeBM = 256 --256 --4=leaf level, 256=Category, 512=Hierarchy

EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DataClass_Data_Tuple]
	@UserID='26881',
	@InstanceID='574',
	@VersionID='1045',
	@ActingAs='11247',
	@DataClassID='13964',
	@Filter='Account=All_|Flow=All_|BusinessProcess=CONSOLIDATED|BusinessRule=All_|Currency=USD|Entity=All_|Scenario=ACTUAL|Time=2021|Version=NONE|GL_Department=All_|GL_Entity=All_|GL_Interco=All_|GL_Organization=All_|FullAccount=I_',
	@GroupBy='Time|FullAccount',
	@Measure='Financials',
	@ResultTypeBM=4,
	@UseCacheYN='true',
	@Debug=3

EXEC [spPortalGet_DataClass_Data_Tuple] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@DataClassName nvarchar(100),
	@DimensionID int,
	@DimensionName nvarchar(100),
	@HierarchyName nvarchar(100),
	@EqualityString nvarchar(10),
	@LeafLevelFilter nvarchar(max),
	@StepReference nvarchar(20) = 'GetData',
	@SQL_Select1 nvarchar(1000) = '',
	@SQL_Select2 nvarchar(1000) = '',
	@SQL_Join2 nvarchar(2000) = '',
	@SQL_GroupBy1 nvarchar(1000) = '',
	@SQL_GroupBy2 nvarchar(1000) = '',
	@SQL_Where nvarchar(max) = '',
	@SQL_Where_Tuple nvarchar(max) = '',
	@SQL_Where_Total nvarchar(max) = '',
	@SQL_MultiDimInsert nvarchar(1000) = '',
	@SQL_MultiDimSelect nvarchar(1000) = '',
	@SQL_MultiDimJoin nvarchar(1000) = '',
	@SQL_Tuple nvarchar(max) = '',
	@TmpGlobalTable varchar(100) = '[##DC_' + convert(varchar(36),NEWID()) +']',
	@TmpGlobalTable_2 varchar(100) = '[##DC_' + convert(varchar(36),NEWID()) +'_2]',
	@TupleNo int,
	@TupleName nvarchar(50),
	@YearMonthColumn nvarchar(100),
	@MultiDimYN bit = 0,

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
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return data for reports in different formats.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2179' SET @Description = 'Procedure created.'

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
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		SELECT
			@DataClassName = [DataClassName],
			@Measure = ISNULL(@Measure, [DataClassName])
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DataClassID] = @DataClassID AND
			[SelectYN] <> 0 AND
			[DeletedID] IS NULL

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
				[@JobID]=@JobID,
				[@Debug]=@DebugSub


	SET @Step = 'Create temp tables'
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
			@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
			@StorageTypeBM = 4, --Mandatory
			@StepReference = @StepReference,
			@Hierarchy = @Hierarchy,
			@Debug = @DebugSub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable_1', * FROM #FilterTable WHERE [StepReference] = @StepReference ORDER BY [TupleNo], [SortOrder], [DimensionName]

	SET @Step = 'Create temp table #GroupBy'
		CREATE TABLE #GroupBy
			(
			[SortOrder] int IDENTITY(1,1),
			[TupleNo] int DEFAULT 0,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[PropertyName] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #GroupBy
			(
			[DimensionName]
			)
		SELECT
			[DimensionName] = [Value] FROM STRING_SPLIT(@GroupBy, '|')

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
			[TupleNo] <> 0 AND
			LEN(FT.[DimensionName]) > 0 AND
			NOT EXISTS (SELECT 1 FROM #GroupBy GB WHERE GB.[DimensionName] = FT.[DimensionName])

		UPDATE GB
		SET
			[DimensionName] = CASE WHEN CHARINDEX('.', GB.[DimensionName]) = 0 THEN GB.[DimensionName] ELSE LEFT(GB.[DimensionName], CHARINDEX('.', GB.[DimensionName]) - 1) END,
			[PropertyName] = CASE WHEN CHARINDEX('.', GB.[DimensionName]) = 0 THEN 'Label' ELSE SUBSTRING(GB.[DimensionName], CHARINDEX('.', GB.[DimensionName]) + 1, LEN(GB.[DimensionName]) - CHARINDEX('.', GB.[DimensionName])) END
		FROM
			#GroupBy GB

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#GroupBy', * FROM #GroupBy ORDER BY [SortOrder], [DimensionName]

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
			END
		
		IF @DebugBM & 16 > 0 SELECT Step = 40, StartTime = @StartTime, CurrentTime = SYSUTCDATETIME(), [Time] = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME())

	SET @Step = 'Get temp table #MultiDim when needed'
		UPDATE FT
		SET
			[MultiDimIncludedYN] = 1
		FROM
			#FilterTable FT
		WHERE
			DimensionTypeID = 27 AND
			LEN([LeafLevelFilter]) > 0

		UPDATE FT
		SET
			[MultiDimIncludedYN] = 1
		FROM
			#FilterTable FT
			INNER JOIN #GroupBy GB ON GB.[DimensionName] = FT.[DimensionName]
		WHERE
			FT.[DimensionTypeID] = 27

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable_2', * FROM #FilterTable WHERE [StepReference] = @StepReference ORDER BY [TupleNo], [SortOrder], [DimensionName]

	SET @Step = 'Get temp table #MultiDim when needed'
		IF @ResultTypeBM & 772 > 0 AND (SELECT COUNT(1) FROM #FilterTable WHERE [MultiDimIncludedYN] <> 0) > 0
			BEGIN
				SET @MultiDimYN = 1

				CREATE TABLE #MultiDim
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Leaf_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Leaf_Description] nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				IF @ResultTypeBM & 256 > 0
					BEGIN
						ALTER TABLE #MultiDim ADD [Category_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT
						ALTER TABLE #MultiDim ADD [Category_Description] nvarchar(100) COLLATE DATABASE_DEFAULT
					END

				--Run cursor for adding columns to temp tables for MultiDim members
				SET @SQL_MultiDimJoin = 'INNER JOIN #MultiDim MD ON'

				IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
				DECLARE AddColumn_Cursor CURSOR FOR
					SELECT
						D.[DimensionName]
					FROM
						#FilterTable FT
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP ON 
							DP.[InstanceID] = @InstanceID AND
							DP.[VersionID] = @VersionID AND
							DP.MultiDimYN <> 0 AND
							DP.DimensionID = FT.DimensionID
						INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.[InstanceID] IN (0, DP.[InstanceID]) AND P.PropertyID = DP.PropertyID AND P.[SelectYN] <> 0
						INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON P.[InstanceID] IN (0, DP.[InstanceID]) AND D.DimensionID = P.[DependentDimensionID] AND D.[SelectYN] <> 0 AND D.[DeletedID] IS NULL
					WHERE
						FT.[StepReference] = @StepReference AND
						FT.[MultiDimIncludedYN] <> 0
					ORDER BY
						DP.[SortOrder]

					OPEN AddColumn_Cursor
					FETCH NEXT FROM AddColumn_Cursor INTO @DimensionName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName
							SET @SQLStatement = '
								ALTER TABLE #MultiDim ADD [' + @DimensionName + '_MemberId] bigint'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

							SELECT
								@SQL_MultiDimInsert = @SQL_MultiDimInsert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberID],',
								@SQL_MultiDimSelect = @SQL_MultiDimSelect + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberID] = M.[' + @DimensionName + '_MemberID],',
								@SQL_MultiDimJoin = @SQL_MultiDimJoin + ' MD.[' + @DimensionName + '_MemberId] = DC.[' + @DimensionName + '_MemberId] AND'

							FETCH NEXT FROM AddColumn_Cursor INTO @DimensionName
						END

				CLOSE AddColumn_Cursor
				DEALLOCATE AddColumn_Cursor	

				IF LEN(@SQL_MultiDimInsert) > 4 SET @SQL_MultiDimInsert = LEFT(@SQL_MultiDimInsert, LEN(@SQL_MultiDimInsert) - 1)
				IF LEN(@SQL_MultiDimSelect) > 4 SET @SQL_MultiDimSelect = LEFT(@SQL_MultiDimSelect, LEN(@SQL_MultiDimSelect) - 1)
				IF LEN(@SQL_MultiDimJoin) > 4 SET @SQL_MultiDimJoin = LEFT(@SQL_MultiDimJoin, LEN(@SQL_MultiDimJoin) - 4)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#MultiDim', * FROM #MultiDim

				IF CURSOR_STATUS('global','MultiDim_Cursor') >= -1 DEALLOCATE MultiDim_Cursor
				DECLARE MultiDim_Cursor CURSOR FOR
			
					SELECT 
						DimensionID,
						DimensionName,
						HierarchyName,
						EqualityString,
						LeafLevelFilter
					FROM
						#FilterTable
					WHERE
						StepReference = @StepReference AND
						[MultiDimIncludedYN] <> 0
					ORDER BY
						DimensionID

					OPEN MultiDim_Cursor
					FETCH NEXT FROM MultiDim_Cursor INTO @DimensionID, @DimensionName, @HierarchyName, @EqualityString, @LeafLevelFilter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@HierarchyName] = @HierarchyName, [@EqualityString] = @EqualityString, [@LeafLevelFilter] = @LeafLevelFilter

							IF @ResultTypeBM & 256 > 0
								SET @SQLStatement = '
									INSERT INTO #MultiDim
										(
										[DimensionID],
										[DimensionName],
										[HierarchyName],
										[Category_MemberKey],
										[Category_Description],
										[Leaf_MemberKey],
										[Leaf_Description],' + @SQL_MultiDimInsert + '
										)
									SELECT
										[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID) + ',
										[DimensionName] = ''' + @DimensionName + ''',
										[HierarchyName] = ''' + @HierarchyName + ''',
										[Category_MemberKey] = P.[Label],
										[Category_Description] = P.[Description],
										[Leaf_MemberKey] = M.[Label],
										[Leaf_Description] = M.[Description],' + @SQL_MultiDimSelect + '
									FROM
										[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] M
										INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H ON H.MemberID = M.MemberID
										INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] P ON P.NodeTypeBM & 1024 > 0 AND P.MemberID = H.ParentMemberID
									WHERE
										M.NodeTypeBM & 1 > 0
										' + CASE WHEN LEN(@LeafLevelFilter) > 0 THEN 'AND M.[MemberID] ' + @EqualityString + '(' + @LeafLevelFilter + ')' ELSE '' END + '
									ORDER BY
										[Category_MemberKey],
										[Leaf_MemberKey]'
							ELSE
								SET @SQLStatement = '
									INSERT INTO #MultiDim
										(
										[DimensionID],
										[DimensionName],
										[HierarchyName],
										[Leaf_MemberKey],
										[Leaf_Description],' + @SQL_MultiDimInsert + '
										)
									SELECT
										[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID) + ',
										[DimensionName] = ''' + @DimensionName + ''',
										[HierarchyName] = ''' + @HierarchyName + ''',
										[Leaf_MemberKey] = M.[Label],
										[Leaf_Description] = M.[Description],' + @SQL_MultiDimSelect + '
									FROM
										[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] M
									WHERE
										M.NodeTypeBM & 1 > 0
										' + CASE WHEN LEN(@LeafLevelFilter) > 0 THEN 'AND M.[MemberID] ' + @EqualityString + '(' + @LeafLevelFilter + ')' ELSE '' END + '
									ORDER BY
										[Leaf_MemberKey]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC(@SQLStatement)

							FETCH NEXT FROM MultiDim_Cursor INTO @DimensionID, @DimensionName, @HierarchyName, @EqualityString, @LeafLevelFilter
						END

				CLOSE MultiDim_Cursor
				DEALLOCATE MultiDim_Cursor

			IF @DebugBM & 2 > 0 SELECT TempTable = '#MultiDim', * FROM #MultiDim
		END

	SET @Step = 'Get WHERE clause'
		IF @ResultTypeBM & 772 > 0
			BEGIN
				IF CURSOR_STATUS('global','Where_Cursor') >= -1 DEALLOCATE Where_Cursor
				DECLARE Where_Cursor CURSOR FOR

					SELECT DISTINCT
						FT.[TupleNo]
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] = @StepReference AND
						LEN(FT.[LeafLevelFilter]) > 0 AND
						FT.[DimensionTypeID] <> 27
					ORDER BY
						FT.[TupleNo]

					OPEN Where_Cursor
					FETCH NEXT FROM Where_Cursor INTO @TupleNo

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@TupleNo] = @TupleNo

							SET @SQL_Where = ''
							
							SELECT 
								@SQL_Where = @SQL_Where + 'DC.[' + FT.[DimensionName] + '_MemberID] ' + FT.[EqualityString] + ' (' + FT.[LeafLevelFilter] + ') AND '
							FROM
								#FilterTable FT
							WHERE
								FT.[StepReference] = @StepReference AND
								FT.[TupleNo] = @TupleNo AND
								LEN(FT.[LeafLevelFilter]) > 0 AND
								FT.[DimensionTypeID] <> 27
							ORDER BY
								FT.[SortOrder]

							IF @TupleNo = 0
								SET @SQL_Where_Total = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @SQL_Where
							ELSE
								BEGIN
									SET @SQL_Where = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '(' + LEFT(@SQL_Where, LEN(@SQL_Where) -4) + ') OR'
									SET @SQL_Where_Tuple = @SQL_Where_Tuple + @SQL_Where
								END

							FETCH NEXT FROM Where_Cursor INTO @TupleNo
						END

				CLOSE Where_Cursor
				DEALLOCATE Where_Cursor

				IF @TupleNo > 0
					SET @SQL_Where_Total = @SQL_Where_Total + '(' + LEFT(@SQL_Where_Tuple, LEN(@SQL_Where_Tuple) - 3) + ') AND'					
			END

	SET @Step = 'Get Tuple clause'
		IF @ResultTypeBM & 772 > 0
			BEGIN
				IF CURSOR_STATUS('global','Tuple_Cursor') >= -1 DEALLOCATE Tuple_Cursor
				DECLARE Tuple_Cursor CURSOR FOR

					SELECT DISTINCT
						[TupleNo] = FT.[TupleNo],
						[TupleName] = ISNULL(MAX(FT.[ObjectReference]), 'Tuple_' + CONVERT(nvarchar(15), FT.[TupleNo]))
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] = @StepReference AND
						FT.[TupleNo] > 0 AND
						(LEN(FT.[LeafLevelFilter]) > 0 OR LEN(FT.[ObjectReference]) > 0) AND
						ISNULL(FT.[DimensionTypeID], 0) <> 27
					GROUP BY
						FT.[TupleNo]
					ORDER BY
						FT.[TupleNo]

					OPEN Tuple_Cursor
					FETCH NEXT FROM Tuple_Cursor INTO @TupleNo, @TupleName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@TupleNo] = @TupleNo, [@TupleName] = @TupleName

							SET @SQL_Tuple = @SQL_Tuple + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @TupleName +'] = ROUND(SUM(CASE WHEN '
							
							SELECT 
								@SQL_Tuple = @SQL_Tuple + 'DC.' + FT.[DimensionName] + '_MemberID ' + FT.[EqualityString] + ' (' + FT.[LeafLevelFilter] + ') AND '
							FROM
								#FilterTable FT
							WHERE
								FT.[StepReference] = @StepReference AND
								FT.[TupleNo] = @TupleNo AND
								LEN(FT.[LeafLevelFilter]) > 0 AND
								FT.[DimensionTypeID] <> 27
							ORDER BY
								FT.[SortOrder]

							SET @SQL_Tuple = LEFT(@SQL_Tuple, LEN(@SQL_Tuple) -4) + ' THEN ' + @Measure + '_Value ELSE 0 END), 4),'

							FETCH NEXT FROM Tuple_Cursor INTO @TupleNo, @TupleName
						END

				CLOSE Tuple_Cursor
				DEALLOCATE Tuple_Cursor

				IF LEN(@SQL_Tuple) > 0 
					SET @SQL_Tuple = ISNULL(LEFT(@SQL_Tuple, LEN(@SQL_Tuple) - 1), '')
			END

	SET @Step = 'Get parts for SQL-statement'
		IF @ResultTypeBM & 772 > 0
			BEGIN
				SELECT
					@SQL_Select1 = @SQL_Select1 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN '[' + GB.[DimensionName] + '_MemberKey] = MD.[Leaf_MemberKey],' ELSE '[' + GB.[DimensionName] + '_MemberId] = DC.[' + GB.[DimensionName] + '_MemberId],' END,
					@SQL_Select2 = @SQL_Select2 + CASE WHEN GB.[TupleNo] = 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN '[' + GB.[DimensionName] + '_MemberKey] = DC.[' + GB.[DimensionName] + '_MemberKey],' ELSE '[' + GB.[DimensionName] + '_' + REPLACE(GB.[PropertyName], 'Label', 'MemberKey') + '] = [' + GB.[DimensionName] + '].[' + GB.[PropertyName] + '],' END ELSE '' END,
					@SQL_GroupBy1 = @SQL_GroupBy1 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN 'MD.[Leaf_MemberKey],' ELSE 'DC.[' + GB.[DimensionName] + '_MemberId],' END,
					@SQL_GroupBy2 = @SQL_GroupBy2 + CASE WHEN GB.[TupleNo] = 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] = 27 THEN 'DC.[' + GB.[DimensionName] + '_MemberKey],' ELSE '[' + GB.[DimensionName] + '].[' + GB.[PropertyName] + '],' END ELSE '' END,
					@SQL_Join2 = @SQL_Join2 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN FT.[DimensionTypeID] <> 27 THEN 'INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + GB.[DimensionName] + '] [' + GB.[DimensionName] + '] ON [' + GB.[DimensionName] + '].MemberId = DC.[' + GB.[DimensionName] + '_MemberId]' ELSE '' END
				FROM
					#GroupBy GB
					INNER JOIN #FilterTable FT ON FT.[StepReference] = @StepReference AND FT.[TupleNo] = 0 AND FT.[DimensionName] = GB.[DimensionName]
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

	SET @Step = '@ResultTypeBM & 12'
		IF @ResultTypeBM & 12 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT' + @SQL_Select1 + '
						[' + @Measure + '_Value] = SUM(DC.[' + @Measure + '_Value]),
						[WorkflowStateID] = MAX(CONVERT(int, DC.[WorkFlowState_MemberId])),
						[Workflow_UpdatedBy_UserID] = 0
					INTO
						' + @TmpGlobalTable + '
					FROM
						[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC WITH (INDEX([NCCSI_' + @DataClassName + ']))' + CASE WHEN OBJECT_ID(N'TempDB.dbo.#MultiDim', N'U') IS NOT NULL THEN '
						' + @SQL_MultiDimJoin ELSE '' END + '
					WHERE' + @SQL_Where_Total + '
						1 = 1
					' + CASE WHEN LEN(@SQL_GroupBy1) > 0 THEN 'GROUP BY' + @SQL_GroupBy1 ELSE '' END + ' 
					HAVING
						SUM(DC.' + @Measure + '_Value) <> 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @SQLStatement = '			
					SELECT' + @SQL_Select2 + '
						[' + @Measure + '_Value] = ROUND(SUM(DC.[' + @Measure + '_Value]), 4),
						[WorkflowStateID] = MAX(DC.[WorkflowStateID]),
						[Workflow_UpdatedBy_UserID] = MAX(DC.[Workflow_UpdatedBy_UserID])
					INTO ' + @TmpGlobalTable_2 + '
					FROM
						' + @TmpGlobalTable + ' DC' + @SQL_Join2 + '
					' + CASE WHEN LEN(@SQL_GroupBy2) > 0 THEN 'GROUP BY' + @SQL_GroupBy2 ELSE '' END + ' 
					HAVING
						SUM(DC.' + @Measure + '_Value) <> 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = '@ResultTypeBM & 4'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '			
					SELECT
						[ResultTypeBM] = 4,
						*
					FROM
						' + @TmpGlobalTable_2

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = '@ResultTypeBM & 8'
		IF @ResultTypeBM & 8 > 0 --Changeable
			BEGIN
				CREATE TABLE #WorkflowState
					(
					[WorkflowStateID] int,
					[Scenario_MemberKey] nvarchar(50),
					[Scenario_MemberId] bigint,
					[TimeFrom] int,
					[TimeTo] int
					)

				EXEC [spGet_WriteAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @AssignmentID = @AssignmentID, @DataClassID = @DataClassID

				IF @DebugBM & 2 > 0 SELECT TempTable = '#WorkflowState', * FROM #WorkflowState

				SET @SQLStatement = '
					UPDATE WFS
					SET
						[Scenario_MemberId] = S.[MemberId]
					FROM
						#WorkflowState WFS
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Scenario] S ON S.[Label] = WFS.[Scenario_MemberKey]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

--				SET @DimensionDistinguishing = CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN '_MemberKey' ELSE '_MemberId' END

				IF (SELECT COUNT(1) FROM #FilterTable FT WHERE FT.[StepReference] = @StepReference AND FT.[TupleNo] = 0 AND FT.[DimensionID] = -7) = 1
					SET @YearMonthColumn = 'DC.[Time_MemberId]'
				ELSE IF (SELECT COUNT(1) FROM #FilterTable FT WHERE FT.[StepReference] = @StepReference AND FT.[TupleNo] = 0 AND FT.[DimensionID] IN (-40, -11)) = 2
					SET @YearMonthColumn = 'DC.[TimeYear_MemberId] * 100 + DC.[TimeMonth_MemberId]' 
				ELSE IF (SELECT COUNT(1) FROM #FilterTable FT WHERE FT.[StepReference] = @StepReference AND FT.[TupleNo] = 0 AND FT.[DimensionID] IN (-49)) = 1
					SET @YearMonthColumn = 'DC.[TimeDay_MemberId] / 100' 
		END

/*
				DECLARE MeasureList_8_Cursor CURSOR FOR

					SELECT 
						MeasureName = REPLACE([ParameterName], '_Value', '') + '_Value'
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
							IF @DebugBM & 2 > 0 SELECT MeasureName = @MeasureName

--							SET @SQLMeasureList_8 = @SQLMeasureList_8 + CASE WHEN CHARINDEX (@MeasureName, @Measure) > 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @MeasureName + '_Value = CASE WHEN MAX(WS.WorkflowStateID) IS NULL THEN 0 ELSE 1 END,' ELSE '' END
							SET @SQLMeasureList_8 = @SQLMeasureList_8 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @MeasureName + ' = CASE WHEN WS.WorkflowStateID IS NULL AND ' + CONVERT(nvarchar(15), @DataClassTypeID) + ' NOT IN (-6) THEN 0 ELSE 1 END,'

							FETCH NEXT FROM MeasureList_8_Cursor INTO @MeasureName
						END

				CLOSE MeasureList_8_Cursor
				DEALLOCATE MeasureList_8_Cursor		

				SET @DimensionDistinguishing = CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN '_MemberKey' ELSE '' END


				SET @SQLSelectList_8 = @SQLDimList + @SQLMeasureList_8

				IF @StorageTypeBM_DataClass & 2 > 0
					BEGIN
						SET @SQLStatement = '
	SELECT
		ResultTypeBM = 8,' + @SQLSelectList_8 + '
		DC.WorkFlowStateID,
		Workflow_UpdatedBy_UserID = MAX(DC.Workflow_UpdatedBy_UserID)
	FROM
		' + @ETLDatabase + '.[dbo].[pcDC_' + @InstanceID_String + '_' + @DataClassName + '] DC
		LEFT JOIN Scenario S ON S.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND S.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND S.MemberKey = DC.Scenario_MemberKey' + @SQLJoin + ' 
		LEFT JOIN #WorkflowState WS ON WS.WorkflowStateID = DC.WorkFlowStateID AND DC.Time_MemberKey BETWEEN CONVERT(nvarchar(15), WS.TimeFrom) AND CONVERT(nvarchar(15), WS.TimeTo) AND WS.Scenario_MemberKey = DC.Scenario_MemberKey
	WHERE
		ResultTypeBM & 12 > 0 AND' + @SQLWhereClause + '
	GROUP BY' + @SQLGroupBy +  ',
		DC.WorkFlowStateID
	ORDER BY' + @SQLGroupBy + ',
		DC.WorkFlowStateID'
					END
				ELSE IF @StorageTypeBM_DataClass & 4 > 0
					BEGIN
						SET @SQLStatement = '
	SELECT
		[ResultTypeBM] = 8,' + @SQLSelectList_8 + CASE WHEN @MasterDataClassID IS NULL THEN '
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN 'DC.[WorkflowStateID],' ELSE '' END + '
		DC.[Workflow_UpdatedBy_UserID]' ELSE '' END + '
	FROM
		' + @TmpGlobalTable + ' DC' + @SQLJoin_Callisto + '
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN 'LEFT JOIN #WorkflowState WS ON WS.WorkflowStateID = DC.WorkFlowStateID AND DC.Time_MemberID BETWEEN WS.TimeFrom AND WS.TimeTo AND WS.Scenario_MemberId = DC.Scenario_MemberId' ELSE 'LEFT JOIN (SELECT WorkFlowStateID=1) WS ON 1 = 1' END
--		LEFT JOIN Scenario S ON S.ScenarioID = DC.Scenario_MemberId 
--		LEFT JOIN #WorkflowState WS ON WS.WorkflowStateID = ' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN 'DC.WorkFlowStateID' ELSE 'NULL' END + ' AND DC.Time_MemberID BETWEEN WS.TimeFrom AND WS.TimeTo AND WS.Scenario_MemberId = DC.Scenario_MemberId'

/*
						SET @SQLStatement = '
	SELECT
		ResultTypeBM = 8,' + @SQLSelectList_8 + '
		--WorkFlowStateID = CONVERT(int, DC.WorkFlowState_MemberId),
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN 'WorkflowStateID = CONVERT(int, DC.WorkFlowState_MemberId),' ELSE '' END + '
		Workflow_UpdatedBy_UserID = 0
	FROM
		' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] DC
		LEFT JOIN Scenario S ON S.ScenarioID = DC.Scenario_MemberId' + @SQLJoin_Callisto + ' 
		--LEFT JOIN #WorkflowState WS ON WS.WorkflowStateID = CONVERT(int, DC.WorkFlowState_MemberId) AND DC.Time_MemberID BETWEEN WS.TimeFrom AND WS.TimeTo AND WS.Scenario_MemberId = DC.Scenario_MemberId
		LEFT JOIN #WorkflowState WS ON WS.WorkflowStateID = ' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN 'CONVERT(int, DC.WorkFlowState_MemberId)' ELSE 'NULL' END + ' AND DC.Time_MemberID BETWEEN WS.TimeFrom AND WS.TimeTo AND WS.Scenario_MemberId = DC.Scenario_MemberId
	GROUP BY' + @SQLGroupBy +  '
		--CONVERT(int, DC.WorkFlowState_MemberId)
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN ', CONVERT(int, DC.WorkFlowState_MemberId)' ELSE '' END + '
	ORDER BY' + @SQLGroupBy + '
		--CONVERT(int, DC.WorkFlowState_MemberId)
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN ', CONVERT(int, DC.WorkFlowState_MemberId)' ELSE '' END + ''
*/
					END

				IF @DebugBM & 1 > 0 AND LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Return ResultTypeBM = 8'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Return ResultTypeBM = 8', 
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement

				EXEC (@SQLStatement)
				SET @Selected = @Selected + @@ROWCOUNT
			END
*/

	SET @Step = '@ResultTypeBM & 256'
		IF @ResultTypeBM & 256 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT
						[Category_MemberKey] = MD.[Category_MemberKey],' + @SQL_Select1 + '
						[' + @Measure + '_Value] = SUM(DC.[' + @Measure + '_Value])
					INTO
						' + @TmpGlobalTable + '
					FROM
						[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC WITH (INDEX([NCCSI_' + @DataClassName + ']))' + CASE WHEN OBJECT_ID(N'TempDB.dbo.#MultiDim', N'U') IS NOT NULL THEN '
						' + @SQL_MultiDimJoin ELSE '' END + '
					WHERE' + @SQL_Where_Total + '
						1 = 1
					GROUP BY
						MD.[Category_MemberKey],' + @SQL_GroupBy1 + '
					HAVING
						SUM(DC.' + @Measure + '_Value) <> 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 EXEC('SELECT TempTable = ''' + @TmpGlobalTable + ''', * FROM ' + @TmpGlobalTable)

				SET @SQLStatement = '
					SELECT
						[Category_MemberKey] = DC.[Category_MemberKey],' + @SQL_Select2 + @SQL_Tuple + '
					FROM
						' + @TmpGlobalTable + ' DC
					GROUP BY
						DC.[Category_MemberKey]' + @SQL_GroupBy2 + '
					ORDER BY
						DC.[Category_MemberKey]' + @SQL_GroupBy2

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #FilterTable
		IF @MultiDimYN <> 0
			BEGIN
				DROP TABLE #MultiDim
				SET @SQLStatement = 'DROP TABLE ' + @TmpGlobalTable EXEC (@SQLStatement)
			END

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
