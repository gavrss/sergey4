SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_FilterTable_20230510]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StepReference nvarchar(20) = NULL,
	@PipeString nvarchar(max) = NULL, --Mandatory
	@DatabaseName nvarchar(100) = NULL, --Mandatory
	@DataClassID int = NULL, --Optional
	@StorageTypeBM_DataClass int = 2, --1 returns formatted for Journal, 2 returns _MemberKey, 4 returns _MemberId, 
	@StorageTypeBM int = NULL, --Move to variables?
	@SQLFilter nvarchar(max) = NULL OUT,
	@Hierarchy nvarchar(1024) = NULL, --Only for backwards compatibility (not valid for tuples)
	@SetJobLogYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000439,
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
EXEC pcINTEGRATOR.dbo.[spGet_FilterTable]
	@UserID = 9863,
	@InstanceID = 572,
	@VersionID = 1080,
	@DataClassID = 5715,
	@PipeString = 'TimeView=Periodic|BaseCurrency=AUD|BusinessRule=NONE|Currency=All_|Entity=NONE|Rate=All_|Scenario=FORECAST1|Simulation=NONE|Time=FY2022',
	@DatabaseName = 'pcDATA_BRAD1', --Mandatory
	@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
	@StorageTypeBM = NULL, --Mandatory
	@StepReference = 'GetData',
	@Hierarchy = NULL,
	@Debug = 1

Separators:
	#Tuple = ObjectReference, (TupleName)
	Semicolon ; (59) = Separator between different tuples
	Pipe | (124) = Separator between different objects
	Dot . (46) = After dot, reference to property
	Colon : (58) = After colon, reference to hierarchy, if numeric reference to HierarchyNo, else to HierarchyName
	Comma , (44) = Separator between different filter members of same object type


Comparisons:
	'-'				Exclude
	'='				IN
	' LIKE '		IN
	' IN '			IN
	'<>'			NOT IN
	'!='			NOT IN
	' NOT IN '		NOT IN
	' NOT LIKE '	NOT IN

SELECT [SemiColon] = ascii(';'), [Pipe] = ascii('|'), [Dot] = ascii('.'), [Colon] = ascii(':'), [Paragraph] = ascii('§'), [Comma] = ascii(',')

EXEC pcINTEGRATOR..spGet_FilterTable
	@UserID = -10,
	@InstanceID = 424,
	@VersionID = 1017,
	@PipeString = 'GL_Future_Use=00000,00004,00005,00008,00014,00016,00015,00017',
	@StorageTypeBM_DataClass = 4,
	@StorageTypeBM = 4,
	@Debug = 1

EXEC pcINTEGRATOR..spGet_FilterTable
	@UserID = -10,
	@InstanceID = 424,
	@VersionID = 1017,
	@PipeString = 'GL_Office=04%',
	@StorageTypeBM_DataClass = 4,
	@StorageTypeBM = 4,
	@Debug = 1

EXEC pcINTEGRATOR..spGet_FilterTable
	@UserID = -10,
	@InstanceID = -1001,
	@VersionID = -1001,
	@PipeString = 'Account=Wages|Employees:All=300,355|Employees.Other=Weekend',
	@StorageTypeBM_DataClass = 4,
	@StorageTypeBM = 4,
	@Debug = 1

EXEC pcINTEGRATOR..spGet_FilterTable
	@UserID = -10,
	@InstanceID = 454,
	@VersionID = 1021,
	@PipeString = 'Account=AC_SALESGROSS|Entity:Entity=Globa|Product.ProductGroup=BRANDAPP',
	@StorageTypeBM_DataClass = 4,
	@StorageTypeBM = 4,
	@Debug = 1

EXEC [spGet_FilterTable]
	@UserID = -10,
	@InstanceID = 529,
	@VersionID = 1001,
	@PipeString = 'Account=10,20',
	@DatabaseName = 'pcDATA_TECA', --Mandatory
	@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
	@StorageTypeBM = 4, --Mandatory
	@DebugBM = 7

EXEC [spGet_FilterTable]
	@UserID	= -10, @InstanceID=561,	@VersionID=1071, @StepReference = 'BR01',@PipeString='BusinessProcess=CONSOLIDATED',
	@StorageTypeBM_DataClass = 3,@StorageTypeBM=4,@Debug=1


EXEC [spGet_FilterTable] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@Filter nvarchar(4000) = NULL,
	@LeafLevelFilter nvarchar(max) = NULL,
	@PropertyFilter nvarchar(max) = NULL,
	@MemberId bigint = NULL, 
	@FilterLevel nvarchar(2) = 'L',
	@LeafMemberOnlyYN bit = 1,
	@GetLeafLevelYN bit = 1,
	@CalledYN bit = 1,
	@DataClassDatabase nvarchar(100),
	@DimensionID nvarchar(100),
	@HierarchyName nvarchar(100),
	@PropertyName nvarchar(100),
	@EqualityString nvarchar(10),
	@FilterType nvarchar(10) = 'MemberKey',
	@MultiDimensionID int,
	@DimensionTypeID int,
	@TupleNo int,
	@ObjectReference nvarchar(100),
	@FilterString nvarchar(4000),
	@JournalColumn nvarchar(50),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@ToBeChanged nvarchar(255) = 'Switch meaning of separator | and ; (spGet_PipeStringSplit). Implement the combination hierarchy and property Account:Account.Label=AC_SALESGROSS. Handle multiple occurences of same dimension Account<>AC_SALESGROSS|Account<>AC_OTH_REV',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2193'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return data in temp table #FilterTable from a @PipeString',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'Switched meaning in pipe strings of dot and colon to align the other parts of the product. Now dot reference to property and colon reference to hierarchy.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added @FilterType.'
		IF @Version = '2.1.0.2162' SET @Description = 'Changed debug handling.'
		IF @Version = '2.1.0.2167' SET @Description = 'Added parameter @SQLFilter'
		IF @Version = '2.1.1.2168' SET @Description = 'Added parameter @SetJobLogYN, defaulted to 0.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle AutoMultiDim-filter.'
		IF @Version = '2.1.1.2172' SET @Description = 'Read column [EqualityString] from table #FilterTable when setting @SQLFilter.'
		IF @Version = '2.1.1.2173' SET @Description = 'Implement ObjectReference.'
		IF @Version = '2.1.2.2177' SET @Description = 'Set @SQLFilter correctly by deleting the extra '' AND''.'
		IF @Version = '2.1.2.2179' SET @Description = 'Added optional parameter @DataClassID.'
		IF @Version = '2.1.2.2180' SET @Description = 'Improved handling of ObjectReference. Get StorageTypeBM from #FilterTable when calling [spGet_LeafLevelFilter].'
		IF @Version = '2.1.2.2181' SET @Description = 'Translate HierarchyNo to HierarchyName when parameter is numeric.'
		IF @Version = '2.1.2.2183' SET @Description = 'Handle DimensionID = -77 (TimeView). Insert unique DimensionID into #FilterTable (DataClass).'
		IF @Version = '2.1.2.2184' SET @Description = 'Improved handling of convert HierarchyNo to HierarchyName.'
		IF @Version = '2.1.2.2187' SET @Description = 'Fixed bug for TimeView in Tuples.'
		IF @Version = '2.1.2.2191' SET @Description = 'Handle @JournalColumn.'
		IF @Version = '2.1.2.2192' SET @Description = 'Handle multiple filters on same dimension.'
		IF @Version = '2.1.2.2193' SET @Description = 'Handle JournalSequence as filter in Journal mode.'


		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
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
			@DataClassDatabase = DestinationDatabase
		FROM
			pcINTEGRATOR_Data.dbo.[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @DebugBM & 2 > 0 SELECT [@DataClassDatabase] = @DataClassDatabase

	SET @Step = 'Create temp table, #PipeStringSplit'
		IF OBJECT_ID(N'TempDB.dbo.#PipeStringSplit', N'U') IS NULL
			CREATE TABLE #PipeStringSplit
				(
				[TupleNo] int,
				[PipeObject] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
				[PipeFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
				)

	SET @Step = 'Create temp table, #FilterTable'
		IF OBJECT_ID(N'TempDB.dbo.#FilterTable', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

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
		ELSE
			BEGIN
				UPDATE #FilterTable SET [HierarchyName] = ISNULL([HierarchyName], [DimensionName])
			END

	SET @Step = 'Fill data from DataClass_Dimension'	
		IF @DataClassID IS NOT NULL
			BEGIN
				INSERT INTO #FilterTable
					(
					[StepReference],
					[TupleNo],
					[DimensionID],
					[DimensionName],
					[DimensionTypeID],
					[StorageTypeBM],
					[SortOrder]
					)
				SELECT
					[StepReference] = @StepReference,
					[TupleNo] = 0,
					[DimensionID] = DCD.[DimensionID],
					[DimensionName] = MAX(D.[DimensionName]),
					[DimensionTypeID] = MAX(D.[DimensionTypeID]),
					[StorageTypeBM] = MAX(DST.[StorageTypeBM]),
					[SortOrder] = MAX(DCD.[SortOrder])
				FROM
					pcINTEGRATOR..DataClass_Dimension DCD
					INNER JOIN pcINTEGRATOR..Dimension D ON D.[InstanceID] IN (0, DCD.[InstanceID]) AND D.[DimensionID] = DCD.[DimensionID] AND D.[SelectYN] <> 0 AND D.[DeletedID] IS NULL
					INNER JOIN pcINTEGRATOR..Dimension_StorageType DST ON DST.[InstanceID] IN (0, DCD.[InstanceID]) AND DST.[VersionID] IN (0, DCD.[VersionID]) AND DST.[DimensionID] = DCD.[DimensionID]
				WHERE
					DCD.[InstanceID] IN (0, @InstanceID) AND
					DCD.[VersionID] IN (0, @VersionID) AND
					DCD.[DataClassID] IN (0, @DataClassID) AND
					DCD.[SelectYN] <> 0
				GROUP BY DCD.[DimensionID]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable (DataClass)', * FROM #FilterTable ORDER BY SortOrder
			END

	SET @Step = 'Check method for filling #FilterTable'		
		IF @PipeString IS NULL AND @CalledYN <> 0
			GOTO UpdateFilterTable

	SET @Step = 'Execute spGet_PipeStringSplit'
		EXEC [dbo].[spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @PipeString, @JobID = @JobID, @Debug = @DebugSub
		IF @DebugBM & 2 > 0 SELECT TempTable = '#PipeStringSplit', * FROM #PipeStringSplit

	SET @Step = 'Set @FilterType'
		SELECT
			@FilterType = ISNULL(PipeFilter, @FilterType)
		FROM
			#PipeStringSplit
		WHERE
			PipeObject = 'FilterType'

		IF @DebugBM & 2 > 0 SELECT TempTable = '#PipeStringSplit', * FROM #PipeStringSplit

	SET @Step = 'Initial fill of temp table #FilterTable with filter info'
		UPDATE FT
		SET
			[HierarchyName] = ISNULL([dbo].[f_GetObjectString] (PSS.[PipeObject], 'Hierarchy'), [dbo].[f_GetObjectString] ([PipeObject], 'Dimension')),
			[PropertyName] = [dbo].[f_GetObjectString] (PSS.[PipeObject], 'Property'),
			[EqualityString] = PSS.[EqualityString],
			[Filter] = PSS.[PipeFilter]
		FROM
			#FilterTable FT
			INNER JOIN #PipeStringSplit PSS ON PSS.[TupleNo] = FT.[TupleNo] AND [dbo].[f_GetObjectString] (PSS.[PipeObject], 'Dimension') = FT.[DimensionName]
		WHERE
			FT.[StepReference] = @StepReference

		INSERT INTO #FilterTable
			(
			[StepReference],
			[TupleNo],
			[DimensionName],
			[ObjectReference],
			[HierarchyName],
			[PropertyName],
			[EqualityString],
			[Filter]
			)
		SELECT
			[StepReference] = @StepReference,
			[TupleNo],
			[DimensionName] = [dbo].[f_GetObjectString] (PSS.[PipeObject], 'Dimension'),
			[ObjectReference] = [dbo].[f_GetObjectString] (PSS.[PipeObject], 'Reference'),
			[HierarchyName] = ISNULL([dbo].[f_GetObjectString] (PSS.[PipeObject], 'Hierarchy'), [dbo].[f_GetObjectString] (PSS.[PipeObject], 'Dimension')),
			[PropertyName] = [dbo].[f_GetObjectString] (PSS.[PipeObject], 'Property'),
			[EqualityString] = [EqualityString],
			[Filter] = [PipeFilter]
		FROM
			#PipeStringSplit PSS
		WHERE
			PSS.PipeObject <> 'FilterType' AND
			NOT EXISTS (SELECT 1 FROM #FilterTable FT WHERE FT.[StepReference] = @StepReference AND FT.[TupleNo] = PSS.[TupleNo] AND FT.[DimensionName] = [dbo].[f_GetObjectString] (PSS.[PipeObject], 'Dimension'))

		UpdateFilterTable:
		UPDATE FT
		SET
			[DimensionID] = D.[DimensionID],
			[StorageTypeBM] = DST.[StorageTypeBM],
			[SortOrder] = ISNULL(DCD.[SortOrder], 0)
		FROM
			#FilterTable FT
			INNER JOIN Dimension D ON D.[InstanceID] IN (@InstanceID, 0) AND D.[DimensionName] = FT.[DimensionName] AND D.[SelectYN] <> 0 AND D.[DeletedID] IS NULL
			INNER JOIN pcINTEGRATOR..Dimension_StorageType DST ON DST.[InstanceID] IN (0, @InstanceID) AND DST.[VersionID] IN (0, @VersionID) AND DST.[DimensionID] = D.[DimensionID]
			LEFT JOIN pcINTEGRATOR_Data..DataClass_Dimension DCD ON DCD.[InstanceID] = @InstanceID AND DCD.[VersionID] = @VersionID AND DCD.[DataClassID] = @DataClassID AND DCD.[DimensionID] = D.[DimensionID] AND DCD.[SelectYN] <> 0
		WHERE
			FT.[StepReference] = @StepReference

		UPDATE FT
		SET
			[DimensionID] = ISNULL(FT.[DimensionID], D.[DimensionID]),
			[StorageTypeBM] = ISNULL(FT.[StorageTypeBM], DST.[StorageTypeBM]),
			[SortOrder] = ISNULL(FT.[SortOrder], 99999)
		FROM
			#FilterTable FT
			INNER JOIN Dimension D ON D.[InstanceID] IN (@InstanceID, 0) AND D.[DimensionName] = FT.[DimensionName] AND D.[SelectYN] <> 0 AND D.[DeletedID] IS NULL
			INNER JOIN pcINTEGRATOR..Dimension_StorageType DST ON DST.[InstanceID] IN (0, @InstanceID) AND DST.[VersionID] IN (0, @VersionID) AND DST.[DimensionID] = D.[DimensionID]
		WHERE
			FT.[StepReference] = @StepReference

		IF @DataClassID IS NOT NULL AND @StorageTypeBM_DataClass & 1 = 0
			DELETE FT
			FROM
				#FilterTable FT
			WHERE
				FT.[StepReference] = @StepReference AND
				FT.[DimensionName] NOT IN ('#Tuple', 'TimeView') AND
				NOT EXISTS (SELECT 1 FROM pcINTEGRATOR..DataClass_Dimension DCD WHERE DCD.[InstanceID] IN (0, @InstanceID) AND DCD.[VersionID] IN (0, @VersionID) AND DCD.DataClassID IN (0, @DataClassID) AND DCD.DimensionID = FT.DimensionID)

		UPDATE FT
		SET
			[HierarchyName] = FT.[DimensionName]
		FROM
			#FilterTable FT
		WHERE
			FT.[StepReference] = @StepReference AND
			FT.[HierarchyName] = '0'

		UPDATE FT
		SET
			[HierarchyName] = ISNULL(DH.[HierarchyName], FT.[DimensionName])
		FROM
			#FilterTable FT
			LEFT JOIN [pcINTEGRATOR].[dbo].[DimensionHierarchy] DH ON DH.[InstanceID] IN (0, @InstanceID) AND DH.[VersionID] IN (0, @VersionID) AND DH.[DimensionID] = FT.[DimensionID] AND CONVERT(nvarchar(15), DH.[HierarchyNo]) = FT.[HierarchyName]
		WHERE
			FT.[StepReference] = @StepReference AND
			ISNUMERIC(FT.[HierarchyName]) <> 0

	SET @Step = 'Set DimensionTypeID'
		UPDATE FT
		SET
			[DimensionTypeID] = D.[DimensionTypeID]
		FROM
			#FilterTable FT
			INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionID = FT.DimensionID AND D.SelectYN <> 0
		WHERE
			FT.[StepReference] = @StepReference

	SET @Step = 'Set Hierarchy'
		IF LEN(@Hierarchy) > 3
			BEGIN
				TRUNCATE TABLE #PipeStringSplit

				EXEC [spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @Hierarchy, @JobID = @JobID, @Debug = @DebugSub

				UPDATE FT
				SET
					[HierarchyName] = DH.[HierarchyName]
				FROM
					#FilterTable FT
					INNER JOIN [pcINTEGRATOR].[dbo].[DimensionHierarchy] DH ON DH.[InstanceID] = @InstanceID AND DH.[VersionID] = @VersionID AND DH.[DimensionID] = FT.DimensionID
					INNER JOIN #PipeStringSplit PSS ON PSS.[PipeObject] = FT.[DimensionName] AND PSS.[PipeFilter] = DH.[HierarchyNo]
				WHERE
					FT.[StepReference] = @StepReference AND
					FT.[TupleNo] = 0
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = @StepReference ORDER BY [TupleNo], [DimensionId]

/*
	SET @Step = 'Handle AutoMultiDim'
		CREATE TABLE #AutoMultiDim
			(
			MultiDimensionID int,
			DimensionID int,
			DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT,
			JournalColumn nvarchar(50) COLLATE DATABASE_DEFAULT,
			SortOrder int
			)

		IF CURSOR_STATUS('global','MultiDim_Cursor') >= -1 DEALLOCATE MultiDim_Cursor
		DECLARE MultiDim_Cursor CURSOR FOR
			
			SELECT
				MultiDimensionID = DimensionID
			FROM
				#FilterTable
			WHERE
				[DimensionTypeID] = 27
			ORDER BY
				[DimensionID]

			OPEN MultiDim_Cursor
			FETCH NEXT FROM MultiDim_Cursor INTO @MultiDimensionID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@MultiDimensionID] = @MultiDimensionID

					INSERT INTO #AutoMultiDim
						(
						[MultiDimensionID],
						[DimensionID],
						[DimensionName],
						[SortOrder]
						)
					SELECT
						[MultiDimensionID] = @MultiDimensionID,
						[DimensionID] = P.[DependentDimensionID],
						[DimensionName] = D.[DimensionName],
						[SortOrder] = DP.[SortOrder]
					FROM
						[pcINTEGRATOR].[dbo].[Dimension_Property] DP
						INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.[PropertyID] = DP.[PropertyID] AND P.[DataTypeID] = 3 AND P.[SelectYN] <> 0
						INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.[DimensionID] = P.[DependentDimensionID] AND D.[DimensionTypeID] IN (1, -1)
					WHERE 
						DP.[InstanceID] IN (0, @InstanceID) AND
						DP.[VersionID] IN (0, @VersionID) AND
						DP.[DimensionID] = @MultiDimensionID AND
						DP.[SelectYN] <> 0

					FETCH NEXT FROM MultiDim_Cursor INTO @MultiDimensionID
				END

		CLOSE MultiDim_Cursor
		DEALLOCATE MultiDim_Cursor

		IF @DebugBM & 2 > 0 SELECT TempTable = '#AutoMultiDim', * FROM #AutoMultiDim

	UPDATE FT
		SET
			[Filter] = ''
		FROM
			#FilterTable FT
			INNER JOIN #AutoMultiDim AMD ON AMD.DimensionID = FT.DimensionID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable
*/
	SET @Step = 'Synchronize tuples'
		IF (SELECT COUNT(DISTINCT TupleNo) FROM #FilterTable WHERE [StepReference] = @StepReference) > 1
			BEGIN
				SELECT DISTINCT [TupleNo] INTO #TupleNo FROM #FilterTable WHERE [TupleNo] <> 0

				IF CURSOR_STATUS('global','DimensionFilter_Cursor') >= -1 DEALLOCATE DimensionFilter_Cursor
				DECLARE DimensionFilter_Cursor CURSOR FOR
				
					SELECT
						[DimensionID]
					FROM
						#FilterTable
					WHERE
						[StepReference] = @StepReference AND
						[DimensionID] NOT IN (-7, -49, -77)
--						[DimensionID] NOT IN (-7, -49)
					GROUP BY
						[DimensionID]
					HAVING
						COUNT(1) > 1

					OPEN DimensionFilter_Cursor
					FETCH NEXT FROM DimensionFilter_Cursor INTO @DimensionID

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID

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
								[JournalColumn],
								[EqualityString],
								[Filter]
								)
							SELECT
								[StepReference] = FT.[StepReference],
								[TupleNo] = TN.[TupleNo],
								[DimensionID] = FT.[DimensionID],
								[DimensionName] = FT.[DimensionName],
								[DimensionTypeID] = FT.[DimensionTypeID],
								[StorageTypeBM] = FT.[StorageTypeBM],
								[SortOrder] = FT.[SortOrder],
								[HierarchyName] = FT.[HierarchyName],
								[PropertyName] = FT.[PropertyName],
								[JournalColumn] = FT.[JournalColumn],
								[EqualityString] = FT.[EqualityString],
								[Filter] = FT.[Filter]
							FROM
								#FilterTable FT
								INNER JOIN #TupleNo TN ON 1=1
							WHERE
								FT.[StepReference] = @StepReference AND
								FT.[TupleNo] = 0 AND
								FT.[DimensionID] = @DimensionID AND
								NOT EXISTS (SELECT 1 FROM #FilterTable FTD WHERE FTD.[StepReference] = FT.[StepReference] AND FTD.[TupleNo] = TN.[TupleNo] AND FTD.[DimensionID] = FT.[DimensionID] AND FTD.[HierarchyName] = FT.[HierarchyName] AND ISNULL(FTD.[PropertyName], '') = ISNULL(FT.[PropertyName], ''))

							SET @FilterString = ''
							
							SELECT
								@FilterString = @FilterString + sub.[Filter] + ','
							FROM
								(
								SELECT DISTINCT
									FT.[Filter]
								FROM
									#FilterTable FT
								WHERE
									FT.[StepReference] = @StepReference AND
									FT.[DimensionID] = @DimensionID
								) sub

							SET @FilterString = LEFT(@FilterString, LEN(@FilterString) -1)

							UPDATE FT
							SET
								[Filter] = @FilterString
							FROM
								#FilterTable FT
							WHERE
								FT.[StepReference] = @StepReference AND
								FT.[TupleNo] = 0 AND
								FT.[DimensionID] = @DimensionID

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
								[JournalColumn],
								[EqualityString],
								[Filter]
								)
							SELECT
								[StepReference] = FT.[StepReference],
								[TupleNo] = 0,
								[DimensionID] = FT.[DimensionID],
								[DimensionName] = MAX(FT.[DimensionName]),
								[DimensionTypeID] = MAX(FT.[DimensionTypeID]),
								[StorageTypeBM] = MAX(FT.[StorageTypeBM]),
								[SortOrder] = MAX(FT.[SortOrder]),
								[HierarchyName] = MAX(FT.[HierarchyName]),
								[PropertyName] = MAX(FT.[PropertyName]),
								[JournalColumn] = MAX(FT.[JournalColumn]),
								[EqualityString] = MAX(FT.[EqualityString]),
								[Filter] = @FilterString
							FROM
								#FilterTable FT
							WHERE
								FT.[StepReference] = @StepReference AND
								FT.[DimensionID] = @DimensionID AND
								NOT EXISTS (SELECT 1 FROM #FilterTable FTD WHERE FTD.[StepReference] = FT.[StepReference] AND FTD.[TupleNo] = 0 AND FTD.[DimensionID] = FT.[DimensionID])
							GROUP BY
								FT.[StepReference],
								FT.[DimensionID]

							FETCH NEXT FROM DimensionFilter_Cursor INTO @DimensionID
						END

				CLOSE DimensionFilter_Cursor
				DEALLOCATE DimensionFilter_Cursor

				DROP TABLE #TupleNo
			END

	SET @Step = 'Update ObjectReference'
		UPDATE FT
		SET
			[ObjectReference] = FT.[Filter]
		FROM
			#FilterTable FT
		WHERE
			FT.[StepReference] = @StepReference AND
			FT.[DimensionName] = '#Tuple'

		UPDATE FT
		SET
			[ObjectReference] = ISNULL(ObjRef.[ObjectReference], CASE WHEN FT.[TupleNo] = 0 THEN NULL ELSE 'TupleNo_' + CASE WHEN FT.[TupleNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), FT.[TupleNo]) END)
		FROM
			#FilterTable FT
			LEFT JOIN
				(
				SELECT
					[TupleNo],
					[ObjectReference] = MAX([ObjectReference])
				FROM
					#FilterTable
				WHERE
					[StepReference] = @StepReference AND
					[ObjectReference] IS NOT NULL
				GROUP BY
					[TupleNo]
				) ObjRef ON ObjRef.[TupleNo] = FT.[TupleNo]
		WHERE
			FT.[StepReference] = @StepReference

		UPDATE FT
		SET
			[JournalColumn] = CASE WHEN FT.DimensionTypeID = -1 THEN 'Segment' + CASE WHEN JSN.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.SegmentNo) ELSE FT.[DimensionName] END
		FROM
			#FilterTable FT
			INNER JOIN pcINTEGRATOR_Data..Journal_SegmentNo JSN ON JSN.InstanceID = @InstanceID AND JSN.VersionID = @VersionID AND JSN.DimensionID = FT.DimensionID
		WHERE
			@StorageTypeBM_DataClass & 1 > 0

		UPDATE FT
		SET
			[JournalColumn] = FT.[DimensionName],
			[LeafLevelFilter] = '''' + REPLACE([Filter], ',', ''',''') + ''''
		FROM
			#FilterTable FT
		WHERE
			DimensionName IN ('JournalSequence', 'Segment20')

--Changed 20221002 By Jawo
		SELECT
			TupleNo,
			TupleRows = COUNT(1)
		INTO
			#TupleRows
		FROM
			#FilterTable FT
		WHERE
			FT.[StepReference] = @StepReference
		GROUP BY
			TupleNo
		
		DELETE FT
		FROM
			#FilterTable FT
			INNER JOIN #TupleRows TR ON TR.TupleNo = FT.TupleNo AND TR.TupleRows > 1
		WHERE
			FT.[StepReference] = @StepReference AND
			FT.[DimensionName] = '#Tuple'

		UPDATE FT
		SET
			[HierarchyName] = NULL,
			[EqualityString] = NULL,
			[Filter] = NULL
		FROM
			#FilterTable FT
			INNER JOIN #TupleRows TR ON TR.TupleNo = FT.TupleNo AND TR.TupleRows = 1
		WHERE
			FT.[StepReference] = @StepReference AND
			FT.[DimensionName] = '#Tuple'
		
--Previous version
		--DELETE FT
		--FROM
		--	#FilterTable FT
		--WHERE
		--	FT.[StepReference] = @StepReference AND
		--	FT.[DimensionName] = '#Tuple'

	SET @Step = 'Run cursor to update #FilterTable'
		IF CURSOR_STATUS('global','LeafLevelFilter_Cursor') >= -1 DEALLOCATE LeafLevelFilter_Cursor
		DECLARE LeafLevelFilter_Cursor CURSOR FOR
			SELECT 
				[TupleNo],
				[DimensionID],
				[DimensionTypeID],
				[StorageTypeBM],
				[ObjectReference],
				[HierarchyName],
				[PropertyName],
				[JournalColumn],
				[EqualityString],
				[Filter]
			FROM
				#FilterTable FT
			WHERE
				FT.[StepReference] = @StepReference AND
				FT.[DimensionID] IS NOT NULL

			OPEN LeafLevelFilter_Cursor
			FETCH NEXT FROM LeafLevelFilter_Cursor INTO @TupleNo, @DimensionID, @DimensionTypeID, @StorageTypeBM, @ObjectReference, @HierarchyName, @PropertyName, @JournalColumn, @EqualityString, @Filter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionTypeID] = @DimensionTypeID, [@HierarchyName] = @HierarchyName, [@PropertyName] = @PropertyName, [@JournalColumn] = @JournalColumn, [@StorageTypeBM] = @StorageTypeBM, [@Filter] = @Filter
					--IF @DimensionTypeID = 27
					--	BEGIN
					--		EXEC pcINTEGRATOR..spGet_AutoMultiDimFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = @DimensionID, @HierarchyName = @HierarchyName, @MemberKey = @Filter, @LeafLevelFilter = @LeafLevelFilter OUT, @Debug = @DebugSub

					--		UPDATE #FilterTable
					--		SET
					--			[LeafLevelFilter] = @LeafLevelFilter
					--		WHERE
					--			[StepReference] = @StepReference AND
					--			[TupleNo] = @TupleNo AND
					--			[DimensionID] = @DimensionID AND
					--			ISNULL([ObjectReference], '') = ISNULL(@ObjectReference, '') AND
					--			[HierarchyName] = @HierarchyName AND
					--			[EqualityString] LIKE '%IN%'
					--	END

					--ELSE 
					IF @PropertyName IS NOT NULL AND CASE WHEN LEN(@Filter) = 0 THEN NULL ELSE @Filter END IS NOT NULL
						BEGIN
							EXEC spGet_PropertyFilter @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DatabaseName=@DataClassDatabase, @DimensionID=@DimensionID, @PropertyName = @PropertyName, @Filter = @Filter, @StorageTypeBM=4, @EqualityString = @EqualityString, @JournalColumn = @JournalColumn, @PropertyFilter = @PropertyFilter OUT, @Debug = @DebugSub

							IF @DebugBM & 2 > 0
								SELECT
									[@PropertyFilter] = @PropertyFilter,
									[@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass,
									[@StepReference] = @StepReference,
									[@TupleNo] = @TupleNo,
									[@DimensionID] = @DimensionID,
									[@ObjectReference] = @ObjectReference,
									[@PropertyName] = @PropertyName
							
							UPDATE FT
							SET
								[PropertyFilter] = @PropertyFilter
							FROM
								#FilterTable FT
							WHERE
								FT.[StepReference] = @StepReference AND
								FT.[TupleNo] = @TupleNo AND
								FT.[DimensionID] = @DimensionID AND
								ISNULL(FT.[ObjectReference], '') = ISNULL(@ObjectReference, '') AND
								FT.[PropertyName] = @PropertyName AND
								FT.[EqualityString] LIKE '%IN%'
						END

					ELSE IF @HierarchyName IS NOT NULL AND CASE WHEN LEN(@Filter) = 0 THEN NULL ELSE @Filter END IS NOT NULL
						BEGIN
							EXEC pcINTEGRATOR..spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DataClassDatabase, @DimensionID = @DimensionID, @HierarchyName = @HierarchyName, @Filter = @Filter, @StorageTypeBM_DataClass = @StorageTypeBM_DataClass, @StorageTypeBM = @StorageTypeBM, @FilterLevel = @FilterLevel, @FilterType = @FilterType, @LeafLevelFilter = @LeafLevelFilter OUT, @Debug = @DebugSub

							UPDATE #FilterTable
							SET
								[LeafLevelFilter] = @LeafLevelFilter
							WHERE
								[StepReference] = @StepReference AND
								[TupleNo] = @TupleNo AND
								[DimensionID] = @DimensionID AND
								ISNULL([ObjectReference], '') = ISNULL(@ObjectReference, '') AND
								[HierarchyName] = @HierarchyName AND
								[EqualityString] LIKE '%IN%' AND
								[Filter] = @Filter
						END


										
					FETCH NEXT FROM LeafLevelFilter_Cursor INTO @TupleNo, @DimensionID, @DimensionTypeID, @StorageTypeBM, @ObjectReference, @HierarchyName, @PropertyName, @JournalColumn, @EqualityString, @Filter
				END

		CLOSE LeafLevelFilter_Cursor
		DEALLOCATE LeafLevelFilter_Cursor							

		IF @DebugBM & 1 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = @StepReference ORDER BY [TupleNo], [DimensionId]

	SET @Step = 'Set @SQLFilter'
		SET @SQLFilter = ''

		IF @Debug <> 0 SELECT [@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass

		IF @StorageTypeBM_DataClass & 1 > 0
			BEGIN
				SELECT
					@SQLFilter = @SQLFilter + CHAR(13) + CHAR(10) + CHAR(9) + CASE WHEN DimensionTypeID = 27 THEN [LeafLevelFilter] ELSE REPLACE([JournalColumn], 'Time', 'YearMonth') + ' IN(' + [LeafLevelFilter] + ')' END + ' AND'
				FROM
					#FilterTable
				WHERE
					[StepReference] = @StepReference AND
					ISNULL([LeafLevelFilter], '') <> '' AND
					(DimensionTypeID IN (-1, 1, 4, 6, 27) OR DimensionName IN ('FiscalYear', 'Book', 'Time'))
				ORDER BY
					DimensionID

				IF LEN(@SQLFilter) > 3
					SET @SQLFilter = LEFT(@SQLFilter, LEN(@SQLFilter) -3)
			END
		ELSE
			BEGIN
				IF @Debug <> 0
					SELECT
						[TempTable_#FilterTable] = '#FilterTable', [@SQLFilter] = @SQLFilter, *
					FROM
						#FilterTable
					WHERE
						[StepReference] = @StepReference AND
						[LeafLevelFilter] IS NOT NULL
					ORDER BY
						DimensionID

				SELECT
					@SQLFilter = @SQLFilter + CHAR(13) + CHAR(10) + CHAR(9) + [DimensionName] + CASE WHEN @StorageTypeBM_DataClass = 4 THEN '_MemberId' ELSE '' END + ' ' + [EqualityString] + ' (' + [LeafLevelFilter] + ') AND'
				FROM
					#FilterTable
				WHERE
					[StepReference] = @StepReference AND
					[LeafLevelFilter] IS NOT NULL
				ORDER BY
					DimensionID
			END

--		SET @SQLFilter = LEFT(@SQLFilter, LEN(@SQLFilter) - 4)

		IF @DebugBM & 1 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = @StepReference ORDER BY [TupleNo], [DimensionId]
		IF @DebugBM & 2 > 0 SELECT [@SQLFilter] = @SQLFilter

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
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
