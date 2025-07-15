SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Journal_New3] 
	@UserID INT = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 4, --1 = Filter, 2 = Filter rows, 4 = Data, Flat, 8 = Data, Head, 16 = Data, Line, 32 = CheckSum
	@FieldTypeBM int = NULL, --1 = Book currency, 2 = Transaction Currency, 4 = Consolidation, 8 = PostedInfo, 16 = InsertedInfo
	@TransactionTypeBM int = 19, --1 = Source System; 2 = Calculated; 4 = Information transactions; 8 = Advanced Consolidation; 16 = Manual Transactions/ Entries made in EFP; 32 = Temporary transactions related to TransactionTypeBM 8

	@Filter nvarchar(4000) = NULL,
	@SQL_MultiDimJoin nvarchar(2000) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000147,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

AS

/*
-- entities on consolidation
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"572"},{"TKey":"UserID","TValue":"9863"},{"TKey":"DebugBM","TValue":"3"},
{"TKey":"VersionID","TValue":"1080"},{"TKey":"ResultTypeBM","TValue":"3"}]', @ProcedureName='spPortalGet_Journal'

EXEC spPortalGet_Journal @InstanceID='485',@ResultTypeBM='3',@UserID='13690',@VersionID='1034',@DebugBM=3

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalGet_Journal',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "3813"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "ResultTypeBM",  "TValue": "7"},
		{"TKey" : "Filter",  "TValue": "Entity=1|Book=GL|FiscalYear=2009|Account=746000"}
		]'

EXEC [spRun_Procedure_KeyValuePair]
	@JSON='
		[
		{"TKey":"InstanceID","TValue":"413"},
		{"TKey":"Filter","TValue":"Entity=1|Book=GL|FiscalYear=2010"},
		{"TKey":"UserID","TValue":"2147"},
		{"TKey":"VersionID","TValue":"1008"},
		{"TKey":"ResultTypeBM","TValue":"3"}
		]',
	@ProcedureName='spPortalGet_Journal'

EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"-1072"},{"TKey":"UserID","TValue":"-1238"},{"TKey":"VersionID","TValue":"-1069"},{"TKey":"ResultTypeBM","TValue":"3"}]', @ProcedureName='spPortalGet_Journal'

EXEC [dbo].[spPortalGet_Journal] @InstanceID='-1001', @ResultTypeBM='2', @UserID='-1174', @VersionID='-1001', @Debug = 1
EXEC [dbo].[spPortalGet_Journal] @UserID = 2126, @InstanceID = 412, @VersionID = 1005, @ResultTypeBM = 7, @Filter='Entity=801|Book=GL|FiscalYear=2014', @Rows = 100, @Debug = 1
EXEC [dbo].[spPortalGet_Journal] @UserID = 2126, @InstanceID = 390, @VersionID = 1011, @ResultTypeBM = 7, @Filter='Entity=EPIC03|Book=MAIN|FiscalYear=2009', @Rows = 100, @Debug = 1

EXEC [dbo].[spPortalGet_Journal] @UserID = 3813, @InstanceID = 413, @VersionID = 1008, @ResultTypeBM = 7, @Filter='Entity=1|Book=GL|FiscalYear=2009|Account=746000,746100|JournalSequence=All_|GL_Project=All_', @Rows = 100, @Debug = 1
EXEC [dbo].[spPortalGet_Journal] @UserID = 2147, @InstanceID = 413, @VersionID = 1008, @ResultTypeBM = 36, @Filter='Entity=1|Book=GL|FiscalYear=2009|Account=746000', @Debug = 1

EXEC [spRun_Procedure_KeyValuePair] @JSON='[
{"TKey":"InstanceID","TValue":"481"},{"TKey":"Filter","TValue":"Entity=GNI01|Book=Principal|FiscalYear=2019"},
{"TKey":"UserID","TValue":"12567"},{"TKey":"VersionID","TValue":"1031"},{"TKey":"ResultTypeBM","TValue":"2"},
{"TKey":"Rows","TValue":"500"},{"TKey":"DebugBM","TValue":"0"}]', @ProcedureName='spPortalGet_Journal'

EXEC [dbo].[spPortalGet_Journal] @GetVersion = 1
*/

DECLARE
	@SQLStatement nvarchar(max),
	@SQLWhereClause nvarchar(max) = '',
	@SQLSegment NVARCHAR(2000),
	@ParameterName nvarchar(100),
	@DataColumn nvarchar(100),
	@SegmentName nvarchar(100),
	@SegmentNo int,
	@LeafLevelFilter nvarchar(max),
	@DimensionFilter nvarchar(max),
	@ReadAccessFilter nvarchar(max),
	@Entity NVARCHAR(50), --Mandatory
	@EntityID int,
	@Book NVARCHAR(50), --Mandatory
	@FiscalYear int,
	@YearMonth int,
	@StorageTypeBM int,
	@CallistoDatabase nvarchar(100),
	@CalledYN bit,
	@NodeTypeBM int,
	@InitialYN bit = 0,
	@JournalTable nvarchar(100),
	@MappingTypeID int,
	@YtdYN bit = 0,
	@BP_FiscalPeriod int,
	@Scenario_LeafLevelFilter nvarchar(MAX) = '',
	@ValueType nvarchar(20) = 'Book',

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2189'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows from Journal.',
			@MandatoryParameter = ''
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'New JobLog handling. @Rows implemented for @ResultTypeBM = 2.'
		IF @Version = '2.0.1.2143' SET @Description = 'Handle Journal stored in ETL database.'
		IF @Version = '2.0.2.2144' SET @Description = 'Added RowCount column to CheckSum resultset. Added sortorder for ResultTypeBM = 4'
		IF @Version = '2.0.2.2148' SET @Description = 'Added DimensionFilter for property columns. DB-197: Convert Time to FiscalYear and FiscalPeriod.'
		IF @Version = '2.0.2.2150' SET @Description = 'DB-244: Added DEALLOCATE CURSOR if exists.'
		IF @Version = '2.0.3.2151' SET @Description = 'Updated datatypes in temp table #Journal.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-336: Added @MappingTypeID. DB-348: MappingTypeID missing in temp table #DimensionFilter. DB-352: Journal filter on parents for prefixed/suffixed accounts.'
		IF @Version = '2.0.3.2153' SET @Description = 'Handle TimeDataView = YTD.'
		IF @Version = '2.0.3.2154' SET @Description = 'Created variable @EntityID. Referenced @EntityID on Journal_SegmentNo instead of @Entity.'
		IF @Version = '2.1.0.2156' SET @Description = 'DB-507: Set correct @BP_FiscalPeriod for DimensionFilter on BusinessProcess IN (Jrn_FP13 - 15).'
		IF @Version = '2.1.0.2163' SET @Description = 'Do not show [JournalLine] = -1.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle multiple hierarchies.'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle ConsolidationGroup and empty segments.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added filter to exclude deleted dimensions when creating/inserting into temp table #FinancialSegment.'
		IF @Version = '2.1.2.2173' SET @Description = 'Set Severity = 0 instead of 16 for message "Entity and Book are mandatory parameters."'
		IF @Version = '2.1.2.2177' SET @Description = 'CONVERT to nvarchar(50) when joining with column [Label].'
		IF @Version = '2.1.2.2179' SET @Description = 'Set parameter @TransactionTypeBM = 19. Added WHERE clause filter ([JournalLine] <> -1) in ResultTypeBM 32.' 
		IF @Version = '2.1.2.2181' SET @Description = 'Parameter @SQL_MultiDimJoin added to handle MultiDim.' 
		IF @Version = '2.1.2.2182' SET @Description = 'Remove SELECT @Error.' 
		IF @Version = '2.1.2.2183' SET @Description = 'Include entities with no Journal data. Handle multiple [Scenario].[DrillTo_MemberKey] values in [#ReadAccess].[LeafLevelFilter].' 
		IF @Version = '2.1.2.2189' SET @Description = 'Add generic columns for Drill and handle drill from Group <> NONE.' 

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())
		
	SET @Step = 'Set procedure variables'
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = suser_name()

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @JournalTable = @JournalTable OUT

	SET @Step = 'Check Initial'	
		IF @Filter IS NULL AND OBJECT_ID (N'tempdb..#DimensionFilter', N'U') IS NULL
			SET @InitialYN = 1

		IF @DebugBM & 2 > 0
			SELECT [@InitialYN] = @InitialYN

	SET @Step = 'Check if drilled'
		IF OBJECT_ID (N'tempdb..#DimensionFilter', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0 --Temporary setting just for checking performance
				CREATE TABLE #DimensionFilter
					(
					[ID] INT IDENTITY(1,1) PRIMARY KEY,
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[HierarchyName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
					[MemberID] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
					[StorageTypeBM] int,
					[MappingTypeID] int,
					[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[NodeTypeBM] int,
					[DataColumn] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[FilterName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[SelectYN] bit
					)

				IF @InitialYN = 0
					EXEC [spGet_DimensionFilter] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @FilterString = @Filter, @DimensionFilter = @DimensionFilter OUT, @JournalDrillYN = 1, @Debug = @DebugSub
			END
		ELSE
			SET @CalledYN = 1

		IF @DebugBM & 2 > 0
			SELECT [@InitialYN] = @InitialYN, [@CalledYN] = @CalledYN

		IF @InitialYN <> 0
			GOTO Initial1

	SET @Step = 'Insert missing rows into #DimensionFilter'
		INSERT INTO #DimensionFilter
			(
			[DimensionID],
			[DimensionName],
			[MemberID],
			[StorageTypeBM],
			[MappingTypeID],
			[Filter],
			[LeafLevelFilter],
			[NodeTypeBM],
			[DataColumn],
			[FilterName],
			[SelectYN]
			)
		SELECT
			[DimensionID] = D.[DimensionID],
			[DimensionName] = D.[DimensionName],
			[MemberID] = NULL,
			[StorageTypeBM] = DST.[StorageTypeBM],
			[MappingTypeID] = DST.[MappingTypeID],
			[Filter] = NULL,
			[LeafLevelFilter] = NULL,
			[NodeTypeBM] = NULL,
			[DataColumn] = D.[DimensionName],
			[FilterName] = D.[DimensionName],
			[SelectYN] = 1
		FROM
			Dimension D
			INNER JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = D.DimensionID
		WHERE
			D.InstanceID IN (0, @InstanceID) AND
			D.[DimensionName] IN ('Entity', 'Account', 'Currency', 'Scenario') AND
			NOT EXISTS (SELECT 1 FROM #DimensionFilter DF WHERE DF.[DimensionName] = D.[DimensionName])

	SET @Step = 'Set Entity and Book'
		SELECT
			@Entity = MAX(CASE WHEN [DimensionName] = 'Entity' THEN [Filter] ELSE NULL END),
			@Book = MAX(CASE WHEN [DimensionName] = 'Book' THEN [Filter] ELSE NULL END),
			@FiscalYear = MAX(CASE WHEN [DimensionName] = 'FiscalYear' THEN [Filter] ELSE NULL END),
			@FieldTypeBM = ISNULL(@FieldTypeBM, MAX(CASE WHEN [DimensionName] = 'FieldTypeBM' THEN [Filter] ELSE NULL END)),
			@YtdYN = MAX(CASE WHEN [DimensionName] = 'TimeDataView' AND [Filter] = 'YTD' THEN 1 ELSE 0 END)
		FROM
			#DimensionFilter
		WHERE
			[DimensionName] IN ('Entity', 'Book', 'FiscalYear', 'FieldTypeBM', 'TimeDataView')

		SELECT @EntityID = EntityID FROM pcINTEGRATOR_Data..Entity WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND MemberKey = @Entity

		IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@EntityID] = @EntityID, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@FieldTypeBM] = @FieldTypeBM, [@YtdYN] = @YtdYN

		IF @Book IS NULL
			BEGIN
				IF CHARINDEX('_', @Entity) = 0
					SELECT
						@Book = EB.Book 
					FROM
						Entity E
						INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 2 > 0
					WHERE
						E.InstanceID = @InstanceID AND
						E.VersionID = @VersionID AND
						E.MemberKey = @Entity
				ELSE
					SELECT @Book = SUBSTRING(@Entity, CHARINDEX('_', @Entity) + 1, LEN(@Entity) - CHARINDEX('_', @Entity))
					
				INSERT INTO #DimensionFilter
					(
					[DimensionName],
					[StorageTypeBM],
					[Filter],
					[LeafLevelFilter],
					[NodeTypeBM],
					[DataColumn],
					[FilterName],
					[SelectYN]
					)
				SELECT
					[DimensionName] = 'Book',
					[StorageTypeBM] = 1,
					[Filter] = @Book,
					[LeafLevelFilter] = '''' + @Book + '''',
					[NodeTypeBM] = 1,
					[DataColumn] = 'Book',
					[FilterName] = 'Book',
					[SelectYN] = 1

				IF @Entity IS NULL OR @Book IS NULL
					BEGIN
						SET @Message = 'Entity and Book are mandatory parameters.'
						SET @Severity = 0
						GOTO EXITPOINT
					END
			END

			SET @FieldTypeBM = ISNULL(@FieldTypeBM, 3)

			SET @ValueType = CASE WHEN @FieldTypeBM & 2 > 0 THEN 'Transaction' ELSE CASE WHEN @FieldTypeBM & 4 > 0 THEN 'Group' ELSE 'Book' END END

--		IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@FieldTypeBM] = @FieldTypeBM, [@YtdYN] = @YtdYN

	SET @Step = 'Update #DimensionFilter'
		IF (
			SELECT
				COUNT(1)
			FROM
				#DimensionFilter DF 
				INNER JOIN Scenario S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.MemberKey = DF.[Filter] AND S.LockedDate IS NOT NULL
			WHERE
				DF.DimensionID = -6
			) > 0
			BEGIN
				INSERT INTO #DimensionFilter
					(
					[DimensionName],
					[StorageTypeBM],
					[Filter],
					[LeafLevelFilter],
					[NodeTypeBM],
					[DataColumn],
					[FilterName],
					[SelectYN]
					)
				SELECT
					[DimensionName] = 'PostedDate',
					[StorageTypeBM] = 1,
					[Filter] = S.LockedDate,
					[LeafLevelFilter] = '''' + CONVERT(nvarchar(10), YEAR(S.LockedDate)) + '-' + CONVERT(nvarchar(10), MONTH(S.LockedDate)) + '-' + CONVERT(nvarchar(10), DAY(S.LockedDate)) + '''',
					[NodeTypeBM] = 1,
					[DataColumn] = 'PostedDate',
					[FilterName] = 'PostedDate',
					[SelectYN] = 1
				FROM
					#DimensionFilter DF 
					INNER JOIN Scenario S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.MemberKey = DF.[Filter] AND S.LockedDate IS NOT NULL
			END

		UPDATE DF
		SET
			[DataColumn] = 'Segment' + CASE WHEN JSN.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), JSN.SegmentNo),
			[FilterName] = DF.[DimensionName],
			[SelectYN] = 1
		FROM
			#DimensionFilter DF
			INNER JOIN Dimension D ON D.InstanceID IN (@InstanceID) AND D.DimensionName = DF.DimensionName
			INNER JOIN Journal_SegmentNo JSN ON JSN.InstanceID = D.InstanceID AND JSN.EntityID = @EntityID AND JSN.Book = @Book AND JSN.SelectYN <> 0 AND JSN.DimensionID = D.DimensionID

		UPDATE DF
		SET
			[LeafLevelFilter] = CASE WHEN S.[DrillTo_MemberKey] IS NULL THEN DF.[LeafLevelFilter] ELSE '''' + S.[DrillTo_MemberKey] + '''' END,
			[NodeTypeBM] = CASE WHEN S.[DrillTo_MemberKey] IS NULL THEN DF.[NodeTypeBM] ELSE 2 END,
			[DataColumn] = CASE [DimensionName] WHEN 'Time' THEN 'YearMonth' WHEN 'Currency' THEN 'Currency_' + @ValueType ELSE [DimensionName] END,
			[FilterName] = CASE [DimensionName] WHEN 'Time' THEN 'YearMonth' ELSE [DimensionName] END,
			[SelectYN] = CASE WHEN [DimensionName] IN ('FieldTypeBM') THEN 0 ELSE 1 END
		FROM
			#DimensionFilter DF
			LEFT JOIN Scenario S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.MemberKey = DF.[Filter] AND DF.DimensionID = -6
		WHERE
			[DimensionName] IN ('JobID', 'Entity', 'Book', 'JournalSequence', 'JournalNo', 'JournalLine', 'FiscalYear', 'FiscalPeriod', 'YearMonth', 'Account', 'FieldTypeBM', 'Currency', 'Time', 'Scenario')
			
		UPDATE #DimensionFilter 
		SET
			[LeafLevelFilter] = '''' + [Filter] + ''''
		WHERE
			LEN([Filter]) > 0 AND
			([LeafLevelFilter] = '' OR [LeafLevelFilter] IS NULL) AND
			[Filter] <> 'All_'

	SET @Step = 'Update Segment filters'
		UPDATE #DimensionFilter
		SET
			LeafLevelFilter = LeafLevelFilter + ','''''
		WHERE
			DataColumn LIKE 'Segment%' AND LeafLevelFilter LIKE '%''NONE''%'
			
		/**
		TODO: 
		Convert BusinessProcess to JournalSequence, FiscalPeriod, BalanceYN and TimeDataView = YTD for BalanceAccounts
		*/
		--SET correct @FiscalPeriod when BusinessProcess IN ('Jrn_FP13','Jrn_FP14','Jrn_FP15')
		SELECT @BP_FiscalPeriod = 12 FROM #DimensionFilter WHERE [DimensionName] = 'BusinessProcess' AND LEN([LeafLevelFilter]) > 0
		SELECT @BP_FiscalPeriod = 13 FROM #DimensionFilter WHERE [DimensionName] = 'BusinessProcess' AND [LeafLevelFilter] LIKE '%Jrn_FP13%'
		SELECT @BP_FiscalPeriod = 14 FROM #DimensionFilter WHERE [DimensionName] = 'BusinessProcess' AND [LeafLevelFilter] LIKE '%Jrn_FP14%'
		SELECT @BP_FiscalPeriod = 15 FROM #DimensionFilter WHERE [DimensionName] = 'BusinessProcess' AND [LeafLevelFilter] LIKE '%Jrn_FP15%' 

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionFilter', * FROM #DimensionFilter 

		SELECT
			DataColumn,
			LeafLevelFilter
		INTO
			#LeafLevelFilter
		FROM
			#DimensionFilter
		WHERE
			[SelectYN] <> 0 AND
			ISNULL(LeafLevelFilter, '') <> ''
		ORDER BY
			DataColumn DESC

		IF @YtdYN <> 0
			BEGIN
				IF OBJECT_ID (N'tempdb..#YearMonth', N'U') IS NULL
					SELECT @YearMonth = MAX(REPLACE([value], '''', '')) FROM STRING_SPLIT((SELECT [LeafLevelFilter] FROM #LeafLevelFilter WHERE DataColumn = 'YearMonth'), ',')
				ELSE
					SELECT @YearMonth = MAX([YearMonth]) FROM #YearMonth

				UPDATE #LeafLevelFilter
				SET
					[LeafLevelFilter] = @YearMonth
				WHERE
					DataColumn = 'YearMonth'

			END

IF @Debug = 1 SELECT TempTable = '#LeafLevelFilter', * FROM #LeafLevelFilter

		SET @DimensionFilter = ''
		SELECT
			@DimensionFilter = @DimensionFilter + CASE WHEN DataColumn = 'PostedDate' OR (DataColumn = 'YearMonth' AND @YtdYN <> 0) THEN DataColumn + ' <= ' + LeafLevelFilter + ' AND ' ELSE DataColumn + ' IN (' + LeafLevelFilter + ') AND ' END
		FROM
			#LeafLevelFilter
		ORDER BY
			DataColumn DESC

--		SET @DimensionFilter = REPLACE(@DimensionFilter, 'Group IN', 'ConsolidationGroup IN')
		SET @DimensionFilter = REPLACE(@DimensionFilter, 'ConsolidationGroup IN (''NONE'')', 'ConsolidationGroup IS NULL')
		
		IF LEN(@DimensionFilter) >= 4
			SET @DimensionFilter = LEFT(@DimensionFilter, LEN(@DimensionFilter) - 4)
		ELSE
			SET @DimensionFilter = NULL

		IF @DebugBM & 2 > 0 SELECT [@DimensionFilter] = @DimensionFilter

		DROP TABLE #LeafLevelFilter

	SET @Step = 'Get Read Access'
		Initial1:
		CREATE TABLE #ReadAccess
			(
			[DimensionID] int,
			[DimensionName] nvarchar(100),
			[StorageTypeBM] int,
			[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[DataColumn] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SelectYN] bit
			)

		EXEC [spGet_ReadAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID

		IF (
			SELECT
				COUNT(1)
			FROM
				#ReadAccess RA 
				INNER JOIN Scenario S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.MemberKey = RA.[Filter] AND S.LockedDate IS NOT NULL
			WHERE
				RA.DimensionID = -6
			) > 0
			BEGIN
				INSERT INTO #ReadAccess
					(
					[DimensionName],
					[StorageTypeBM],
					[Filter],
					[LeafLevelFilter],
					[DataColumn],
					[SelectYN]
					)
				SELECT
					[DimensionName] = 'PostedDate',
					[StorageTypeBM] = 1,
					[Filter] = S.LockedDate,
					[LeafLevelFilter] = '''' + CONVERT(nvarchar(10), YEAR(S.LockedDate)) + '-' + CONVERT(nvarchar(10), MONTH(S.LockedDate)) + '-' + CONVERT(nvarchar(10), DAY(S.LockedDate)) + '''',
					[DataColumn] = 'PostedDate',
					[SelectYN] = 1
				FROM
					#ReadAccess DF 
					INNER JOIN Scenario S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.MemberKey = DF.[Filter] AND S.LockedDate IS NOT NULL
			END


		UPDATE RA
		SET
			DataColumn = 'Segment' + CASE WHEN JSN.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), JSN.SegmentNo),
			SelectYN = 1
		FROM
			#ReadAccess RA
			INNER JOIN Dimension D ON D.InstanceID IN (@InstanceID) AND D.DimensionID = RA.DimensionID
			INNER JOIN Journal_SegmentNo JSN ON JSN.InstanceID = D.InstanceID AND JSN.EntityID = @EntityID AND JSN.Book = @Book AND JSN.SelectYN <> 0 AND JSN.DimensionID = D.DimensionID

		UPDATE RA
		SET
			[LeafLevelFilter] = CASE WHEN S.[DrillTo_MemberKey] IS NULL THEN RA.[LeafLevelFilter] ELSE '''' + S.[DrillTo_MemberKey] + '''' END,
			[DataColumn] = CASE [DimensionName] WHEN 'Time' THEN 'YearMonth' WHEN 'Currency' THEN 'Currency_' + @ValueType ELSE [DimensionName] END,
			[SelectYN] = 1
		FROM
			#ReadAccess RA
			LEFT JOIN Scenario S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.MemberKey = RA.[Filter] AND RA.DimensionID = -6
		WHERE
			[DimensionName] IN ('JobID', 'Entity', 'Book', 'JournalSequence', 'JournalNo', 'JournalLine', 'FiscalYear', 'FiscalPeriod', 'YearMonth', 'Account', 'FieldTypeBM', 'Currency', 'Scenario', 'Time')

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ReadAccess_before Scenario_LeafLevelFilter UPDATE', * FROM #ReadAccess

		--Create temp table #Scenario_DrillTo	
		SELECT 
			[Scenario_MemberKey] = S.MemberKey,
			[DrillTo_MemberKey] = S.DrillTo_MemberKey,
			[Scenario_LeafLevelFilter] = COALESCE(S.DrillTo_MemberKey,S.MemberKey,sp.[value])
		INTO #Scenario_DrillTo
		FROM
			STRING_SPLIT(
				(
				SELECT 
					RA.[Filter]
				FROM 
					#ReadAccess RA
				WHERE
					RA.[DimensionName] IN ('Scenario') AND
					RA.DimensionID = -6 AND
					RA.[Filter] <> 'All_'
				),',') sp
		LEFT JOIN [pcINTEGRATOR_Data].[dbo].[Scenario] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.MemberKey = sp.[value] AND S.DeletedID IS NULL 
		
		IF @DebugBM & 2 > 0 SELECT [TempTable_#Scenario_DrillTo] = '#Scenario_DrillTo', * FROM #Scenario_DrillTo
				
		SELECT 
			@Scenario_LeafLevelFilter = @Scenario_LeafLevelFilter + CASE WHEN ISNULL([Scenario_LeafLevelFilter],'') <> '' THEN '''' + [Scenario_LeafLevelFilter] + ''',' ELSE '' END 
		FROM 
			#Scenario_DrillTo
		GROUP BY 
			[Scenario_LeafLevelFilter]

		IF LEN(@Scenario_LeafLevelFilter) > 0
			SET @Scenario_LeafLevelFilter = LEFT(@Scenario_LeafLevelFilter, LEN(@Scenario_LeafLevelFilter) - 1)
		ELSE 
			SET @Scenario_LeafLevelFilter = NULL 

		IF @DebugBM & 2 > 0 SELECT [@Scenario_LeafLevelFilter] = @Scenario_LeafLevelFilter
/*
		UPDATE RA
		SET
			[LeafLevelFilter] = ISNULL(REPLACE(RA.[LeafLevelFilter], S.[MemberKey], S.[DrillTo_MemberKey]), RA.[LeafLevelFilter])
		FROM
			#ReadAccess RA
			INNER JOIN Scenario S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.SelectYN <> 0 AND S.DeletedID IS NULL AND S.[DrillTo_MemberKey] IS NOT NULL AND RA.[Filter] LIKE '%' + S.MemberKey + '%'
		WHERE
			RA.[DimensionName] IN ('Scenario') AND
			RA.DimensionID = -6
*/
		UPDATE RA
		SET
			[LeafLevelFilter] = ISNULL(@Scenario_LeafLevelFilter, RA.[LeafLevelFilter])
		FROM
			#ReadAccess RA
		WHERE
			RA.[DimensionName] IN ('Scenario') AND
			RA.DimensionID = -6

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ReadAccess', * FROM #ReadAccess

		SELECT DataColumn, LeafLevelFilter INTO #ReadAccessFilter FROM #ReadAccess WHERE [SelectYN] <> 0 AND ISNULL(LeafLevelFilter, '') <> '' ORDER BY DataColumn

		SET @ReadAccessFilter = ''
		SELECT
			@ReadAccessFilter = @ReadAccessFilter + CASE WHEN DataColumn = 'PostedDate' THEN DataColumn + ' <= ' + LeafLevelFilter + ' AND ' ELSE DataColumn + ' IN (' + LeafLevelFilter + ') AND ' END
		FROM
			#ReadAccessFilter
		ORDER BY
			DataColumn DESC

		IF LEN(@ReadAccessFilter) >= 4
			SET @ReadAccessFilter = LEFT(@ReadAccessFilter, LEN(@ReadAccessFilter) - 4)
		ELSE
			SET @ReadAccessFilter = NULL

		IF @DebugBM & 2 > 0 SELECT ReadAccessFilter = @ReadAccessFilter

		DROP TABLE #ReadAccessFilter

	SET @Step = '@ResultTypeBM & 3'
		IF @ResultTypeBM & 3 > 0
			BEGIN
				CREATE TABLE #ResultType3
					(
					ParameterType nvarchar(50),
					ParameterName nvarchar(50),
					DataColumn nvarchar(50),
					DataType nvarchar(50),
					KeyColumn nvarchar(50),
					SortOrder int
					)

				IF @InitialYN = 0
					BEGIN
						SELECT
							D.DimensionName, 
							DataColumn = 'Segment' + CASE WHEN JSN.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), JSN.SegmentNo),
							SegmentNo
						INTO
							#FinancialSegment
						FROM
							Dimension D
							INNER JOIN Journal_SegmentNo JSN ON JSN.InstanceID = D.InstanceID AND JSN.EntityID = @EntityID AND JSN.Book = @Book AND JSN.SelectYN <> 0 AND JSN.DimensionID = D.DimensionID
						WHERE
							D.InstanceID IN (@InstanceID) AND
							D.DimensionTypeID = -1 AND
                            D.DeletedID IS NULL

						IF @DebugBM & 2 > 0 SELECT TempTable = '#FinancialSegment', * FROM #FinancialSegment

						INSERT INTO #DimensionFilter
							(
							[DimensionName],
							[StorageTypeBM],
							[Filter],
							[LeafLevelFilter],
							[DataColumn],
							[SelectYN]
							)
						SELECT DISTINCT
							[DimensionName],
							[StorageTypeBM] = (SELECT MAX([StorageTypeBM]) FROM #DimensionFilter),
							[Filter] = NULL,
							[LeafLevelFilter] = NULL,
							[DataColumn],
							[SelectYN] = 0
						FROM
							#FinancialSegment FS
						WHERE
							NOT EXISTS (SELECT 1 FROM #DimensionFilter DF WHERE DF.DimensionName = FS.DimensionName)

						INSERT INTO #ResultType3
							(
							ParameterType,
							ParameterName,
							DataColumn,
							DataType,
							KeyColumn,
							SortOrder
							)
						SELECT
							ParameterType = CONVERT(nvarchar(50), ParameterType),
							ParameterName = CONVERT(nvarchar(50), ParameterName),
							DataColumn = CONVERT(nvarchar(50), DataColumn),
							DataType = CONVERT(nvarchar(50), DataType),
							KeyColumn = CONVERT(nvarchar(50), KeyColumn),
							SortOrder
						FROM
							(
							SELECT ParameterType = 'MultiSelect', ParameterName = 'JobID', DataColumn = 'JobID', DataType = 'int', KeyColumn = 'MemberID', SortOrder = 10
							UNION SELECT ParameterType = 'SingleSelect', ParameterName = 'Entity', DataColumn = 'Entity',  DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 20
							UNION SELECT ParameterType = 'SingleSelect', ParameterName = 'Book', DataColumn = 'Book',  DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 30
							UNION SELECT ParameterType = 'MultiSelect', ParameterName = 'JournalSequence', DataColumn = 'JournalSequence',  DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 40
							UNION SELECT ParameterType = 'Search', ParameterName = 'JournalNo', DataColumn = 'JournalNo',  DataType = 'int', KeyColumn = 'MemberKey', SortOrder = 50
							UNION SELECT ParameterType = 'Search', ParameterName = 'JournalLine', DataColumn = 'JournalLine',  DataType = 'int', KeyColumn = 'MemberKey', SortOrder = 60
							UNION SELECT ParameterType = 'MultiSelect', ParameterName = 'FiscalYear', DataColumn = 'FiscalYear',  DataType = 'int', KeyColumn = 'MemberKey', SortOrder = 70
							UNION SELECT ParameterType = 'MultiSelect', ParameterName = 'FiscalPeriod', DataColumn = 'FiscalPeriod',  DataType = 'int', KeyColumn = 'MemberKey', SortOrder = 80
							UNION SELECT ParameterType = 'MultiSelect', ParameterName = 'YearMonth', DataColumn = 'YearMonth',  DataType = 'int', KeyColumn = 'MemberKey', SortOrder = 90
							UNION SELECT ParameterType = 'SingleSelect', ParameterName = 'Scenario', DataColumn = 'Scenario',  DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 95
							UNION SELECT ParameterType = 'MultiSelect', ParameterName = 'Account', DataColumn = 'Account',  DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 100
							UNION SELECT ParameterType = 'BitMap', ParameterName = 'FieldTypeBM', DataColumn = 'FieldTypeBM', DataType = 'int', KeyColumn = 'MemberKey', SortOrder = 500
							UNION SELECT ParameterType = 'MultiSelect', ParameterName = DimensionName, DataColumn = DataColumn, DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 300 + SegmentNo FROM #FinancialSegment
							) sub
					END
				ELSE
					BEGIN
						INSERT INTO #ResultType3
							(
							ParameterType,
							ParameterName,
							DataColumn,
							DataType,
							KeyColumn,
							SortOrder
							)
						SELECT
							ParameterType = CONVERT(nvarchar(50), ParameterType),
							ParameterName = CONVERT(nvarchar(50), ParameterName),
							DataColumn = CONVERT(nvarchar(50), DataColumn),
							DataType = CONVERT(nvarchar(50), DataType),
							KeyColumn = CONVERT(nvarchar(50), KeyColumn),
							SortOrder
						FROM
							(
							SELECT ParameterType = 'SingleSelect', ParameterName = 'Entity', DataColumn = 'Entity',  DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 20
							UNION SELECT ParameterType = 'SingleSelect', ParameterName = 'Book', DataColumn = 'Book',  DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 30
							UNION SELECT ParameterType = 'MultiSelect', ParameterName = 'FiscalYear', DataColumn = 'FiscalYear',  DataType = 'int', KeyColumn = 'MemberKey', SortOrder = 70
							) sub
					END

				IF @DebugBM & 2 > 0 SELECT TempTable = '#ResultType3', * FROM #ResultType3
			END

	SET @Step = 'Set @TransactionTypeBM'
		IF (SELECT COUNT(1) FROM #DimensionFilter WHERE DimensionID = -35 AND LeafLevelFilter <> '''NONE''') > 0
			SET @TransactionTypeBM = 24


	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 1,
					ParameterName,
					ParameterDescription = RT.ParameterName,
					DataType,
					ParameterType,
					KeyColumn,
					DefaultMemberKey = CASE WHEN RT.ParameterName = 'FieldTypeBM' THEN CONVERT(nvarchar(10), @FieldTypeBM) ELSE DF.[Filter] END,
					[NodeTypeBM] = DF.[NodeTypeBM],
					[LeafLevelFilter] = DF.[LeafLevelFilter]
				FROM
					#ResultType3 RT
					LEFT JOIN #DimensionFilter DF ON DF.FilterName = RT.ParameterName
				ORDER BY
					SortOrder

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				CREATE TABLE #Members
					(
					MemberID bigint,
					MemberKey [nvarchar](100) COLLATE DATABASE_DEFAULT,
					MemberDescription [nvarchar](255) COLLATE DATABASE_DEFAULT,
					NodeTypeBM int,
					ParentMemberId bigint,
					SortOrder int
					)

				CREATE TABLE #EBFDistinct
					(
					[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [int]
					)

				SET @SQLStatement = '
					INSERT INTO #EBFDistinct
						(
						[Entity],
						[Book],
						[FiscalYear]
						)
					SELECT DISTINCT
						[Entity],
						[Book],
						[FiscalYear]
					FROM
						' + @JournalTable + '
					WHERE
						InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + 
						CASE WHEN LEN(@ReadAccessFilter) > 3 THEN ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @ReadAccessFilter ELSE '' END

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#EBFDistinct_1', * FROM #EBFDistinct

				--Add entities with no Journal data:
				INSERT INTO #EBFDistinct
					(
					[Entity],
					[Book],
					[FiscalYear]
					)
				SELECT DISTINCT
					[Entity] = E.MemberKey,
					[Book] = EB.Book,
					[FiscalYear] = NULL
				FROM 
					[pcIntegrator_Data].[dbo].[Entity] E 
					INNER JOIN [pcIntegrator_Data].[dbo].[Entity_Book] EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 3 > 0 AND EB.SelectYN <> 0
				WHERE 
					E.InstanceID = @InstanceID AND 
					E.VersionID = @VersionID AND
					E.EntityTypeID <> 0 AND 
					E.SelectYN <> 0 AND 
					E.DeletedID IS NULL AND
					NOT EXISTS (SELECT 1 FROM #EBFDistinct EFB WHERE EFB.Entity = E.MemberKey AND EFB.Book = EB.Book)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#EBFDistinct_2', * FROM #EBFDistinct

				IF @InitialYN <> 0
					GOTO Initial2

				CREATE TABLE #JournalDistinct
					(
					[JobID] [int],
					[FiscalPeriod] [int],
					[JournalSequence] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[YearMonth] [int],
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
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT
					)

				SET @SQLStatement = '
					INSERT INTO #JournalDistinct
						(
						[JobID],
						[FiscalPeriod],
						[JournalSequence],
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
						[Scenario]
						)
					SELECT DISTINCT
						[JobID],
						[FiscalPeriod],
						[JournalSequence],
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
						[Scenario]
					FROM
						' + @JournalTable + '
					WHERE
						InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
						Entity = ''' + @Entity + ''' AND
						Book = ''' + @Book + ''' AND
						FiscalYear = ' + CONVERT(nvarchar(10), @FiscalYear) + 
						CASE WHEN LEN(@ReadAccessFilter) > 3 THEN ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @ReadAccessFilter ELSE '' END +
						CASE WHEN LEN(@DimensionFilter) > 3 AND @CalledYN <> 0 THEN ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @DimensionFilter ELSE '' END

					IF @DebugBM & 2 > 0 
						BEGIN
							SELECT [@JournalTable]=@JournalTable,[@InstanceID]=@InstanceID,[@Entity]=@Entity,[@Book]=@Book,[@FiscalYear]=@FiscalYear,[@ReadAccessFilter]=@ReadAccessFilter,[@DimensionFilter]=@DimensionFilter,[@CalledYN]=@CalledYN,[@SQLStatement]=@SQLStatement
							PRINT @SQLStatement
						END                        
					EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#JournalDistinct', * FROM #JournalDistinct

				--Update #DimensionFilter
				UPDATE DF
				SET 
					[MappingTypeID] = DS.MappingTypeID
				FROM
					#DimensionFilter DF
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DS ON DS.InstanceID = @InstanceID AND DS.VersionID = @VersionID AND DS.DimensionID = DF.DimensionID

				Initial2:

				SET @Step = '@ResultTypeBM & 2, Parameter Cursor' --All, only filtered by @InstanceID
				IF CURSOR_STATUS('global','Parameter_Cursor') >= -1 DEALLOCATE Parameter_Cursor
				DECLARE Parameter_Cursor CURSOR FOR

					SELECT
						RT.ParameterName,
						RT.DataColumn,
						StorageTypeBM = CASE WHEN @InitialYN = 0 THEN DF.StorageTypeBM ELSE CASE WHEN RT.ParameterName = 'Entity' THEN 4 ELSE 1 END END,
						MappingTypeID = ISNULL(DF.MappingTypeID, 0)
					FROM
						#ResultType3 RT
						LEFT JOIN #DimensionFilter DF ON DF.DimensionName = RT.ParameterName
					WHERE
						RT.[ParameterName] <> 'FieldTypeBM' AND
						RT.[ParameterType] <> 'Search'
					ORDER BY
						RT.SortOrder

					OPEN Parameter_Cursor
					FETCH NEXT FROM Parameter_Cursor INTO @ParameterName, @DataColumn, @StorageTypeBM, @MappingTypeID

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@ParameterName] = @ParameterName, [@DataColumn] = @DataColumn, [@StorageTypeBM] = @StorageTypeBM, [@MappingTypeID] = @MappingTypeID

							TRUNCATE TABLE #Members

							IF @StorageTypeBM & 4 > 0
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Members
											(
											MemberID,
											MemberKey,
											MemberDescription,
											NodeTypeBM,
											ParentMemberId,
											SortOrder
											)
										SELECT DISTINCT' + CASE WHEN @Rows IS NULL THEN '' ELSE ' TOP ' + CONVERT(nvarchar(10), @Rows) END + '
											MemberID = D.[MemberId],
											MemberKey = ' + CASE WHEN @MappingTypeID = 0 THEN 'D.Label' ELSE 'D.MemberKeyBase' END + ',
											MemberDescription = D.[Description],
											NodeTypeBM = 1,
											ParentMemberId = H.ParentMemberId,
											SortOrder = ISNULL(H.SequenceNumber, 0)
										FROM
											' + CASE WHEN @ParameterName = 'Entity' THEN '#EBFDistinct' ELSE '#JournalDistinct' END + ' JD
											INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @ParameterName + ' D ON ' + CASE WHEN @MappingTypeID = 0 THEN 'D.[Label]' ELSE 'D.[MemberKeyBase]' END + ' = CONVERT(nvarchar(50), JD.[' + @DataColumn + '])' + CASE WHEN @MappingTypeID = 0 THEN '' ELSE ' AND D.Entity IN (''NONE'', ''' + @Entity + ''')' END + '
											INNER JOIN ' + @CallistoDatabase + '..S_HS_' + @ParameterName + '_' + @ParameterName + ' H ON H.MemberId = D.MemberId
										ORDER BY
											' + CASE WHEN @MappingTypeID = 0 THEN 'D.Label' ELSE 'D.MemberKeyBase' END 
------------------------------------------------------------------
										IF @DebugBM & 2 > 0 
											BEGIN
												SELECT TempTable = '#Members',ParameterName=@ParameterName,CallistoDatabase=@CallistoDatabase,DataColumn=@DataColumn,SQLStatement=@SQLStatement
												SELECT TempTable = '#Members', * FROM #Members
												PRINT @SQLStatement
											END                                            
										EXEC (@SQLStatement)
------------------------------------------------------------------
										--Loop to find missing parents
										WHILE (SELECT COUNT(1) FROM #Members P WHERE ISNULL(P.ParentMemberId, 0) <> 0 AND NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)) > 0
											BEGIN
												SET @SQLStatement = '
													INSERT INTO #Members
														(
														MemberID,
														MemberKey,
														MemberDescription,
														NodeTypeBM,
														ParentMemberId,
														SortOrder
														)
													SELECT
														MemberID = D.MemberID,
														MemberKey = D.Label,
														MemberDescription = D.[Description],
														NodeTypeBM = 18,
														ParentMemberId = H.ParentMemberId,
														SortOrder = ISNULL(H.SequenceNumber, 0)
													FROM
														' + @CallistoDatabase + '..S_DS_' + @ParameterName + ' D
														INNER JOIN (SELECT DISTINCT MemberId = ParentMemberId FROM #Members P WHERE NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)) NP ON NP.MemberId = D.MemberId
														LEFT JOIN ' + @CallistoDatabase + '..S_HS_' + @ParameterName + '_' + @ParameterName + ' H ON H.MemberId = D.MemberId
													ORDER BY
														SortOrder,
														D.Label'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)
												IF @DebugBM & 2 > 0 SELECT TempTable = '#Members', * FROM #Members ORDER BY SortOrder, MemberKey
											END
								END
							ELSE
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Members
											(
											MemberID,
											MemberKey,
											MemberDescription,
											NodeTypeBM,
											ParentMemberId,
											SortOrder
											)
										SELECT DISTINCT' + CASE WHEN @Rows IS NULL THEN '' ELSE ' TOP ' + CONVERT(nvarchar(10), @Rows) END + '
											MemberID = NULL,
											MemberKey = ' + @DataColumn + ',
											MemberDescription = ' + @DataColumn + ',
											NodeTypeBM = 1,
											ParentMemberId = 1,
											SortOrder = 1
										FROM
											' + CASE WHEN @ParameterName IN ('Entity', 'Book', 'FiscalYear') THEN '#EBFDistinct' ELSE '#JournalDistinct' END + ' JD
										ORDER BY
											' + @DataColumn

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									INSERT INTO #Members
										(
										MemberID,
										MemberKey,
										MemberDescription,
										NodeTypeBM,
										ParentMemberId,
										SortOrder
										)
									SELECT DISTINCT
										MemberID = 1,
										MemberKey = 'All_',
										MemberDescription = 'All ' + @ParameterName,
										NodeTypeBM = 18,
										ParentMemberId = 0,
										SortOrder = 0

								END

							IF @DataColumn = 'Book'
								SELECT DISTINCT
									ResultTypeBM = 2, 
									Dim =  @ParameterName,
									MemberID,
									MemberKey,
									MemberDescription,
									NodeTypeBM,
									ParentMemberId,
									WriteYN = 1,
									SortOrder,
									Entity_MemberKey = JD.Entity
								FROM
									#Members M
									LEFT JOIN #EBFDistinct JD ON JD.Book = M.MemberKey
                        
							ELSE
								SELECT DISTINCT
									ResultTypeBM = 2, 
									Dim =  @ParameterName,
									MemberID,
									MemberKey,
									MemberDescription,
									NodeTypeBM,
									ParentMemberId,
									WriteYN = 1,
									SortOrder
								FROM
									#Members
								WHERE 
									MemberKey IS NOT NULL

							FETCH NEXT FROM Parameter_Cursor INTO @ParameterName, @DataColumn, @StorageTypeBM, @MappingTypeID
						END

				CLOSE Parameter_Cursor
				DEALLOCATE Parameter_Cursor

			IF @InitialYN <> 0
				GOTO Initial3

			SET @Step = '@ResultTypeBM & 2, Union'
				SELECT
					ResultTypeBM = 2,
					Dim = 'FieldTypeBM',
					MemberID = NULL,
					MemberKey = CONVERT(nvarchar(10), MemberBM),
					MemberDescription = [Description],
					NodeTypeBM = 1,
					ParentMemberId = NULL,
					WriteYN = 1,
					SortOrder
				FROM
					(
					SELECT MemberBM = 1, [Name] = 'Book currency', [Description] = 'Book currency', SortOrder = 10
					UNION SELECT MemberBM = 2, [Name] = 'Transaction Currency', [Description] = 'Transaction Currency', SortOrder = 20
					UNION SELECT MemberBM = 4, [Name] = 'Consolidation', [Description] = 'Consolidation', SortOrder = 30
					UNION SELECT MemberBM = 8, [Name] = 'PostedInfo', [Description] = 'Posted Info', SortOrder = 40
					UNION SELECT MemberBM = 16, [Name] = 'InsertedInfo', [Description] = 'Inserted Info', SortOrder = 50
					) sub
				ORDER BY
					SortOrder

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Calculate Segments'
		IF @ResultTypeBM & 20 > 0
			BEGIN
				SELECT 
					@SQLSegment = ISNULL(@SQLSegment, '') + '[' + SegmentName + '] = [Segment' + CASE WHEN SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(NVARCHAR(10), SegmentNo) + '],' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
				FROM
					Journal_SegmentNo
				WHERE
					SegmentNo >= 1 AND
					InstanceID = @InstanceID AND
					EntityID = @EntityID AND
					Book = @Book
				ORDER BY
					SegmentNo

				SET @Selected = @Selected + @@ROWCOUNT
			END

		Initial3:
	SET @Step = '@ResultTypeBM & 4, Data, Flat'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT' + CASE WHEN @Rows IS NULL THEN '' ELSE ' TOP ' + CONVERT(nvarchar(10), @Rows) END + '
						[ResultTypeBM] = 4, 
						[JobID],
						[InstanceID],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod],
						[YearMonth],
						[JournalSequence],
						[JournalNo],
						[JournalLine],
						[TransactionTypeBM],
						[BalanceYN],
						[Account],
						' + ISNULL(@SQLSegment, '') + '[JournalDate],
						[TransactionDate],
						[PostedDate],
						[PostedStatus],
						[PostedBy],
						[Flow],
						[ConsolidationGroup],
						[InterCompanyEntity],'

				SET @SQLStatement = @SQLStatement + '
						[Scenario],
						[Customer],
						[Supplier],
						[Description_Head],
						[Description_Line],
						[Currency_Drill] =  [Currency_' + @ValueType+ '],
						[ValueDebit_Drill] = [ValueDebit_' + @ValueType + '],
						[ValueCredit_Drill]=  [ValueCredit_' + @ValueType+ '],
						[Currency_Book],
						[ValueDebit_Book],
						[ValueCredit_Book],
						[Currency_Group],
						[ValueDebit_Group],
						[ValueCredit_Group],
						[Currency_Transaction],
						[ValueDebit_Transaction],
						[ValueCredit_Transaction],
						[Source],
						[SourceModule],
						[SourceModuleReference],
						[SourceCounter],
						[SourceGUID],
						[Inserted],
						[InsertedBy]'

				SET @SQLStatement = @SQLStatement + '
						
					FROM
						' + @JournalTable + ' J' + ISNULL(@SQL_MultiDimJoin, '') + '
					WHERE
						[JournalLine] <> -1 AND
						' + CASE WHEN @BP_FiscalPeriod IS NULL THEN '' ELSE '
						FiscalPeriod <= ' + CONVERT(NVARCHAR(15), @BP_FiscalPeriod) + ' AND ' END + '
						TransactionTypeBM & ' + CONVERT(NVARCHAR(10), @TransactionTypeBM) + ' > 0 AND
						InstanceID = ' + CONVERT(NVARCHAR(10), @InstanceID) + ' AND'

				IF @DimensionFilter IS NOT NULL SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @DimensionFilter  + ' AND'
				IF @ReadAccessFilter IS NOT NULL SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @ReadAccessFilter  + ' AND'

				SET @SQLStatement = @SQLStatement + '
						1 = 1
					ORDER BY
						[JournalDate] DESC'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 8, Data, Head'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT' + CASE WHEN @Rows IS NULL THEN '' ELSE ' TOP ' + CONVERT(nvarchar(10), @Rows) END + ' 
						[ResultTypeBM] = 8, 
						[JobID] = MAX([JobID]),
						[InstanceID],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod],
						[YearMonth] = MAX([YearMonth]),
						[JournalSequence],
						[JournalNo],
						[TransactionDate] = MAX([TransactionDate]),
						[PostedDate] = MAX([PostedDate]),
						[PostedStatus] = MAX(CONVERT(int, [PostedStatus])),
						[PostedBy] = MAX([PostedBy]),
						[Flow] = MAX([Flow]),
						[ConsolidationGroup] = MAX([ConsolidationGroup]),
						[InterCompanyEntity] = MAX([InterCompanyEntity]),
						[Scenario] = MAX([Scenario]),
						[Description_Head] = MAX([Description_Head]),
						[Currency_Drill] =  MAX([Currency_' + @ValueType+ ']),
						[Currency_Book] = MAX([Currency_Book]),
						[Currency_Group] = MAX([Currency_Group]),
						[Currency_Transaction] = MAX([Currency_Transaction]),
						[Inserted] = MAX([Inserted]),
						[InsertedBy] = MAX([InsertedBy]),
						[Source] = MAX([Source]),
						[SourceModuleReference] = MAX([SourceModuleReference])
					FROM
						' + @JournalTable + ' J' + ISNULL(@SQL_MultiDimJoin, '') + '
					WHERE
						' + CASE WHEN @BP_FiscalPeriod IS NULL THEN '' ELSE '
						FiscalPeriod <= ' + CONVERT(NVARCHAR(15), @BP_FiscalPeriod) + ' AND ' END + '
						TransactionTypeBM & ' + CONVERT(NVARCHAR(10), @TransactionTypeBM) + ' > 0 AND
						InstanceID = ' + CONVERT(NVARCHAR(10), @InstanceID) + ' AND'

				IF @DimensionFilter IS NOT NULL SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @DimensionFilter  + ' AND'
				IF @ReadAccessFilter IS NOT NULL SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @ReadAccessFilter  + ' AND'

				SET @SQLStatement = @SQLStatement + '
						1 = 1
					GROUP BY
						[InstanceID],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod],
						[JournalSequence],
						[JournalNo]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 16, Data, Line'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT' + CASE WHEN @Rows IS NULL THEN '' ELSE ' TOP ' + CONVERT(nvarchar(10), @Rows) END + '
						[ResultTypeBM] = 16, 
						[InstanceID],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod],
						[JournalSequence],
						[JournalNo],
						[JournalLine],
						[Account],
						' + ISNULL(@SQLSegment, '') + '[Customer],
						[Supplier],
						[Description_Line],
						[ValueDebit_Drill] = [ValueDebit_' + @ValueType + '],
						[ValueCredit_Drill] = [ValueCredit_' + @ValueType+ '],
						[ValueDebit_Book],
						[ValueCredit_Book],
						[ValueDebit_Group],
						[ValueCredit_Group],
						[ValueDebit_Transaction],
						[ValueCredit_Transaction],
						[Source],
						[SourceModule],
						[SourceModuleReference],
						[SourceCounter],
						[SourceGUID]
					FROM
						' + @JournalTable + ' J' + ISNULL(@SQL_MultiDimJoin, '') + '
					WHERE
						[JournalLine] <> -1 AND
						' + CASE WHEN @BP_FiscalPeriod IS NULL THEN '' ELSE '
						FiscalPeriod <= ' + CONVERT(NVARCHAR(15), @BP_FiscalPeriod) + ' AND ' END + '
						TransactionTypeBM & ' + CONVERT(NVARCHAR(10), @TransactionTypeBM) + ' > 0 AND
						InstanceID = ' + CONVERT(NVARCHAR(10), @InstanceID) + ' AND'

				IF @DimensionFilter IS NOT NULL SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @DimensionFilter  + ' AND'
				IF @ReadAccessFilter IS NOT NULL SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @ReadAccessFilter  + ' AND'

				SET @SQLStatement = @SQLStatement + '
						1 = 1
					ORDER BY
						[JournalLine]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 32, CheckSum'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 32, 
						[CheckSum] = SUM([ValueDebit_' + @ValueType + '] - [ValueCredit_' + @ValueType+ ']),
						[RowCount] = COUNT(1)
					FROM
						' + @JournalTable + ' J' + ISNULL(@SQL_MultiDimJoin, '') + ' 
					WHERE
						[JournalLine] <> -1 AND
						' + CASE WHEN @BP_FiscalPeriod IS NULL THEN '' ELSE '
						FiscalPeriod <= ' + CONVERT(NVARCHAR(15), @BP_FiscalPeriod) + ' AND ' END + '
						TransactionTypeBM & ' + CONVERT(NVARCHAR(10), @TransactionTypeBM) + ' > 0 AND
						InstanceID = ' + CONVERT(NVARCHAR(10), @InstanceID) + ' AND'

				IF @DimensionFilter IS NOT NULL SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @DimensionFilter  + ' AND'
				IF @ReadAccessFilter IS NOT NULL SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @ReadAccessFilter  + ' AND'

				SET @SQLStatement = @SQLStatement + '
						1 = 1'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END


	SET @Step = 'Drop temp tables'
		DROP TABLE #Scenario_DrillTo
		IF @ResultTypeBM & 3 > 0 DROP TABLE #ResultType3
		IF @ResultTypeBM & 2 > 0 DROP TABLE #Members

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		SET @JobID = ISNULL(@JobID, @ProcedureID)
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	SET @JobID = ISNULL(@JobID, @ProcedureID)
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
