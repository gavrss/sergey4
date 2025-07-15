SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalConvert_DataClass_Filter_20231221_nehatest]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	@DataClassID INT = NULL,
	@JSON_table NVARCHAR(MAX) = NULL,
	@Filter NVARCHAR(MAX) = NULL OUT,
	@LeafLevelFilter NVARCHAR(MAX) = NULL OUT,
	@ProcessName NVARCHAR(100) = NULL OUT,
	@GetLeafLevelYN BIT = 1,
	@ResultTypeBM INT = 7,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000335,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*

EXEC [pcINTEGRATOR].[dbo].[spPortalConvert_DataClass_Filter_20231221_nehatest] @DebugBM=31, @DataClassID='5630',@InstanceID='515',@ResultTypeBM='37',@Rows='2000',@UserID='15278',@VersionID='1064'
,@JSON_table='[  {"TKey":"Account","TValue":"CB_SSOE_AdjDollars"},{"TKey":"Entity","TValue":"REM"},{"TKey":"Description","TValue":"REMichel"},  
{"TKey":"GL_Branch","TValue":"NONE"},{"TKey":"GL_Contact","TValue":"All_"},{"TKey":"Time","TValue":"202312"},{"TKey":"BusinessRule","TValue":"All_"},  
{"TKey":"Flow","TValue":"All_"},{"TKey":"Scenario","TValue":"ACTUAL"},{"TKey":"Currency","TValue":"USD"},  
{"TKey":"Measure","TValue":"Commission"},{"TKey":"TimeView","TValue":"Periodic"},{"TKey":"BusinessProcess","TValue":"CONSOLIDATED"}]'


EXEC [pcINTEGRATOR].[dbo].[spPortalConvert_DataClass_Filter_20231221_nehatest] @DebugBM=31, @DataClassID='5630',@InstanceID='515',@ResultTypeBM='37',@Rows='2000',@UserID='15278',@VersionID='1064'
,@JSON_table='[  {"TKey":"Account","TValue":"CB_SSOE_AdjDollars"},{"TKey":"Entity","TValue":"REM"},{"TKey":"Description","TValue":"REMichel"},  
{"TKey":"GL_Branch","TValue":"NONE"},{"TKey":"GL_Contact","TValue":"8760"},{"TKey":"Time","TValue":"202312"},{"TKey":"BusinessRule","TValue":"All_"},  
{"TKey":"Flow","TValue":"All_"},{"TKey":"Scenario","TValue":"ACTUAL"},{"TKey":"Currency","TValue":"USD"},  
{"TKey":"Measure","TValue":"Commission"},{"TKey":"TimeView","TValue":"Periodic"},{"TKey":"BusinessProcess","TValue":"CONSOLIDATED"}]'


*/

SET ANSI_WARNINGS OFF

DECLARE
	@DimensionName NVARCHAR(100),
	@MemberID BIGINT,
	@ApplicationID INT,
	@CallistoDatabase NVARCHAR(100),
	@ETLDatabase NVARCHAR(100),
	@ResultTemplate NVARCHAR(50),
	@TimeDataView_MemberId BIGINT,
	@MonthID BIGINT,
	@Entity_MemberId BIGINT,
	@Entity NVARCHAR(50),
	@Book NVARCHAR(50),
	@FiscalYear INT,
	@FiscalPeriod INT,
	@StartMonth INT,
	@Parameter NVARCHAR(4000),
	@NodeTypeBM INT,
	@StorageTypeBM INT,
	@EntityID INT,
	@SQLStatement NVARCHAR(MAX),
	@JournalDrillYN BIT = 1,
	@DimensionID_FiscalPeriod INT,
	@FiscalPeriod_Filter NVARCHAR(10),
	@FiscalPeriod_Jrn_FY NVARCHAR(10),
	@FiscalPeriod_Jrn_FP NVARCHAR(255) = '',
	@PipeString NVARCHAR(MAX) = '',
	@SQL_MultiDimJoin NVARCHAR(2000),
	@MultiDimensionID INT,
	@MultiDimensionName NVARCHAR(100),
	@MultiHierarchyName NVARCHAR(100),
	@MultiLeafLevelFilter NVARCHAR(MAX),
	@EqualityString NVARCHAR(10),
	@GroupYN BIT = 0,
	@FieldTypeBM INT = 1,
	@DataClassName NVARCHAR(50),
	@CheckExistence INT,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
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
	@ToBeChanged NVARCHAR(255) = 'When Time/TimeDay is on aggregated level, set @MonthID to last Month, not first. Important for calculating YTD.',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'JaWo',
	@Version NVARCHAR(50) = '2.1.2.2189'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Drill from V2 reports into source data.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2141' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2144' SET @Description = 'Handle Fiscal years on aggregated level. DB-7'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-197: Convert Time to FiscalYear and FiscalPeriod.'
		IF @Version = '2.0.3.2151' SET @Description = 'DB-264: Removed FiscalPeriod to handle multiple month values'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-336: Added @JournalDrillYN parameter. DB-348: MappingTypeID missing in temp table #DimensionFilter.'
		IF @Version = '2.0.3.2153' SET @Description = 'Removed handling of TimeDataView. Now handled in [spPortalGet_Journal].'
		IF @Version = '2.1.0.2162' SET @Description = 'DB-567: Set correct @Entity for non-Main Entity books. Enhanced debugging.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added @Step = Handle custom dimension FiscalPeriod.'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-704: Get correct books for Entity names with underscore. Look for Dimension FiscalPeriod IN (0, @InstanceID).'
		IF @Version = '2.1.2.2181' SET @Description = 'Handle Multidim and use #FilterTable.'
		IF @Version = '2.1.2.2182' SET @Description = 'Ignore references to LineItem and TimeDataView.'
		IF @Version = '2.1.2.2183' SET @Description = 'Ignore references to TimeView.'
		IF @Version = '2.1.2.2187' SET @Description = '@ProcessName picked up from DataClass. In Dimension_Cursor, update [LeafLeverFilter] FROM #DimensionFilter ONLY if NULL or empty (sample case: handling alternate hierarchy).'
		IF @Version = '2.1.2.2188' SET @Description = 'HotFixes: 1. GL_Posted convert to PostedStatus, 2. When DimensionName = BusinessRule - just ignore it for Journal'
		IF @Version = '2.1.2.2189' SET @Description = 'Add generic columns for Drill and handle drill from Group <> NONE.' 

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ApplicationID = ApplicationID,
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = ETLDatabase
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application]
		WHERE
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND 
			SelectYN <> 0

	/*
	SET @Step = 'Set @Parameter'
		SET @Parameter = 
			'EXEC [spPortalConvert_DataClass_Filter] ' +
			'@UserID = ' + ISNULL(CONVERT(nvarchar(10), @UserID), 'NULL') + ', ' +
			'@InstanceID = ' + ISNULL(CONVERT(nvarchar(10), @InstanceID), 'NULL') + ', ' +
			'@VersionID = ' + ISNULL(CONVERT(nvarchar(10), @VersionID), 'NULL') + ', ' +
			'@PCFULLCV = ''' + CONVERT(nvarchar(4000), @PCFULLCV) + ''', ' +
			'@GetLeafLevelYN = ' + ISNULL(CONVERT(nvarchar(10), CONVERT(int, @GetLeafLevelYN)), 'NULL') + ', ' +
			'@ResultTypeBM = ' + ISNULL(CONVERT(nvarchar(10), @ResultTypeBM), 'NULL')
	*/

	SET @Step = 'Create and fill Temp table #FilterTable'
		CREATE TABLE #FilterTable
			(
			[StepReference] NVARCHAR(20) COLLATE DATABASE_DEFAULT,
			[TupleNo] INT,
			[DimensionID] INT,
			[DimensionName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[DimensionTypeID] INT,
			[StorageTypeBM] INT,
			[SortOrder] INT,
			[ObjectReference] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[HierarchyName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[PropertyName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[JournalColumn] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[EqualityString] NVARCHAR(10) COLLATE DATABASE_DEFAULT,
			[Filter] NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
			[PropertyFilter] NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
			[Segment] NVARCHAR(20) COLLATE DATABASE_DEFAULT,
			[Method] NVARCHAR(20) COLLATE DATABASE_DEFAULT,
			[MappingTypeID] INT
			)
		
		CREATE TABLE #DimensionFilter
			(
			[ID] INT IDENTITY(1,1) PRIMARY KEY,
			[DimensionID] INT,
			[DimensionName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[HierarchyName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[MemberID] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] INT,
			[MappingTypeID] INT,
			[Filter] NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] INT,
			[DataColumn] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[FilterName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[SelectYN] BIT
			)

		IF @JSON_table IS NOT NULL	
			BEGIN
				SELECT
					[DimensionName] = [TKey],
					[Filter] = [TValue]
				INTO
					#DimFilter
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[TKey] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
					[TValue] nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				SELECT @PipeString = @PipeString + [DimensionName] + '=' + [Filter] + '|'
				FROM
					#DimFilter

				IF @DebugBM & 2 > 0 SELECT [@PipeString] = @PipeString

				EXEC [spGet_FilterTable]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@StepReference = 'Drill',
					@PipeString = @PipeString, --Mandatory
--					@DatabaseName nvarchar(100) = NULL, --Mandatory
					@DataClassID = @DataClassID, --Optional
					@StorageTypeBM_DataClass = 1, --1 returns formatted for Journal, 2 returns _MemberKey, 4 returns _MemberId, 
--					@StorageTypeBM int = NULL, --Move to variables?
--					@SQLFilter nvarchar(max) = NULL OUT,
--					@Hierarchy nvarchar(1024) = NULL, --Only for backwards compatibility (not valid for tuples)
					@SetJobLogYN = 0,

					@JobID = @JobID,

					@Debug = @DebugSub


				--UPDATE DF
				--SET
				--	[DimensionID] = D.[DimensionID],
				--	[DimensionTypeID] = D.[DimensionTypeID],
				--	[StorageTypeBM] = DST.[StorageTypeBM],
				--	[MappingTypeID] = DST.[MappingTypeID]
				--FROM
				--	#FilterTable DF
				--	INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = DF.DimensionName
				--	LEFT JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = D.DimensionID
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable

	SET @Step = 'Get MultiDimFilter'
		IF (SELECT COUNT(1) FROM #FilterTable WHERE StepReference = 'Drill' AND DimensionTypeID = 27 AND LEN(LeafLevelFilter) > 0) >= 1
			BEGIN
				CREATE TABLE #MultiDim
					(
					[DimensionID] INT,
					[DimensionName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
					[HierarchyName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
					[Category_MemberKey] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
					[Category_Description] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
					[Leaf_MemberId] BIGINT,
					[Leaf_MemberKey] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
					[Leaf_Description] NVARCHAR(100) COLLATE DATABASE_DEFAULT
					)

				IF CURSOR_STATUS('global','MultiDim_Cursor') >= -1 DEALLOCATE MultiDim_Cursor
				DECLARE MultiDim_Cursor CURSOR FOR
			
					SELECT 
						[MultiDimensionID] = [DimensionID],
						[MultiDimensionName] = [DimensionName],
						[MultiHierarchyName] = ISNULL([HierarchyName], [DimensionName]),
						[MultiLeafLevelFilter] = [LeafLevelFilter],
						[EqualityString] = [EqualityString]
					FROM
						#FilterTable
					WHERE
						[StepReference] = 'Drill' AND
						[DimensionTypeID] = 27 AND
						LEN([LeafLevelFilter]) > 0
					ORDER BY
						[SortOrder],
						[DimensionName]

					OPEN MultiDim_Cursor
					FETCH NEXT FROM MultiDim_Cursor INTO @MultiDimensionID, @MultiDimensionName, @MultiHierarchyName, @MultiLeafLevelFilter, @EqualityString

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@MultiDimensionID] = @MultiDimensionID, [@MultiDimensionName] = @MultiDimensionName, [@MultiHierarchyName] = @MultiHierarchyName, [@MultiLeafLevelFilter] = @MultiLeafLevelFilter, [@EqualityString] = @EqualityString

							EXEC [dbo].[spGet_MultiDimFilter]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@MultiDimensionID = @MultiDimensionID,
								@MultiDimensionName = @MultiDimensionName,
								@MultiHierarchyName = @MultiHierarchyName,
								@LeafLevelFilter = @MultiLeafLevelFilter,
								@EqualityString = @EqualityString,
								@CategoryYN = 0,
								@JournalYN = 1,
								@CallistoDatabase = @CallistoDatabase,
								@SQL_MultiDimJoin = @SQL_MultiDimJoin OUT,
								@JobID = @JobID,
								@DebugBM = @DebugSub

							FETCH NEXT FROM MultiDim_Cursor INTO @MultiDimensionID, @MultiDimensionName, @MultiHierarchyName, @MultiLeafLevelFilter, @EqualityString
						END

				CLOSE MultiDim_Cursor
				DEALLOCATE MultiDim_Cursor

				IF @DebugBM & 2 > 0 SELECT TempTable = '#MultiDim', * FROM #MultiDim
				IF @DebugBM & 2 > 0 SELECT [@SQL_MultiDimJoin] = @SQL_MultiDimJoin

			END

	SET @Step = 'Fill table #DimensionFilter'
		INSERT INTO #DimensionFilter
			(
			[DimensionID],
			[DimensionName],
			[HierarchyName],
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
			[DimensionID] = FT.[DimensionID],
			[DimensionName] = FT.[DimensionName],
			[HierarchyName] = FT.[HierarchyName],
			[MemberID] = NULL, --?
			[StorageTypeBM] = FT.[StorageTypeBM],
			[MappingTypeID] = FT.[MappingTypeID],
			[Filter] = FT.[Filter],
			[LeafLevelFilter] = FT.[LeafLevelFilter],
			[NodeTypeBM] = 1, --?
			[DataColumn] = ISNULL([JournalColumn], [DimensionName]),
			[FilterName] = '', --?
			[SelectYN] = 1
		FROM
			#FilterTable FT
		WHERE
			FT.[StepReference] = 'Drill' AND
			FT.[DimensionTypeID] <> 27 AND
			FT.[DimensionID] NOT IN (-2, -8, -26, -27) AND
			LEN(FT.[LeafLevelFilter]) > 0

	SET @Step = 'Set @ProcessName'
		SELECT 
			@ProcessName = CASE WHEN [ModelBM] & 64 > 0 THEN 'Financials' ELSE 'Generic' END,
			@DataClassName = [DataClassName]
		FROM 
			[pcINTEGRATOR_Data].[dbo].[DataClass]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DataClassID] = @DataClassID
		
		--SELECT
		--	@ProcessName = 'Financials'
		--	--Should be picked up from DataClassID

		SET @ResultTemplate = CASE WHEN @ProcessName IN ('Financials') THEN 'Journal' ELSE 'Generic' END

		SELECT
			[ResultTypeBM] = 0,
			[ResultTemplate] = @ResultTemplate

	SET @Step = 'Set DataColumn for irregular dimensions'
		UPDATE DF
		SET
			DataColumn = CASE [DimensionName] WHEN 'GL_Posted' THEN 'PostedStatus' WHEN 'Group' THEN 'ConsolidationGroup' WHEN 'Time' THEN 'YearMonth'END
		FROM
			#DimensionFilter DF
		WHERE
			[DimensionName]	IN ('GL_Posted', 'Group', 'Time') AND
			@ResultTemplate = 'Journal'	

		SELECT
			@GroupYN = COUNT(1)
		FROM
			#DimensionFilter
		WHERE
			[DimensionName] = 'Group' AND
			[Filter] <> 'NONE'

		IF @DebugBM & 2 > 0 SELECT [@GroupYN] = @GroupYN

		IF @GroupYN <> 0 SET @FieldTypeBM = 4

		UPDATE DF
		SET
			[DataColumn] = CASE WHEN @GroupYN = 0 THEN 'Currency_Book' ELSE 'Currency_Group' END
		FROM
			#DimensionFilter DF
		WHERE
			[DimensionName]	IN ('Currency') AND
			@ResultTemplate = 'Journal'	
		
	SET @Step = 'Ignore BusinessRule dimension on case: @ResultTemplate = Journal'
		-- Hotfix when DimensionName = BusinessRule - just ignore it for Journal
		DELETE #DimensionFilter
		WHERE	DataColumn		= 'BusinessRule'
			AND DimensionName	= 'BusinessRule'
			AND @ResultTemplate = 'Journal'

	SET @Step = 'Set @Entity and @Book'
		SELECT @Entity = [Filter] FROM #DimensionFilter WHERE DimensionID = -4

		IF CHARINDEX('_', @Entity) = 0 OR 
			(SELECT COUNT(1) FROM [pcINTEGRATOR_Data].[dbo].[Entity] E 
			WHERE
				E.InstanceID = @InstanceID AND
				E.VersionID = @VersionID AND
				E.MemberKey = @Entity AND
				E.SelectYN <> 0 AND
				E.DeletedID IS NULL) <> 0

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
			BEGIN
				SELECT @Book = SUBSTRING(@Entity, CHARINDEX('_', @Entity) + 1, LEN(@Entity) - CHARINDEX('_', @Entity))
				SELECT @Entity = LEFT(@Entity, CHARINDEX('_', @Entity) - 1)
			END

		SELECT @EntityID = EntityID FROM [Entity] E WHERE MemberKey = @Entity

		IF @DebugBM & 2 > 0 SELECT [@EntityID] = @EntityID, [@Entity] = @Entity, [@Book] = @Book

	SET @Step = 'Update [Filter] column in #DimensionFilter with correct @Entity'
		UPDATE D
			SET [Filter] = @Entity
		FROM 
			#DimensionFilter D
		WHERE 
			D.DimensionID = -4

/*
SELECT 'Arne1', * FROM #DimensionFilter

	SET @Step = 'Dimension Cursor'
		IF CURSOR_STATUS('global','Dimension_Cursor') >= -1 DEALLOCATE Dimension_Cursor
		DECLARE Dimension_Cursor CURSOR FOR
			
			SELECT
				DimensionName,
				[Filter],
				StorageTypeBM
			FROM
				#DimensionFilter
			WHERE
				LEN([Filter]) > 0
			ORDER BY
				ID

			OPEN Dimension_Cursor
			FETCH NEXT FROM Dimension_Cursor INTO @DimensionName, @Filter, @StorageTypeBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName, [@Filter] = @Filter, [@StorageTypeBM] = @StorageTypeBM
					SELECT @LeafLevelFilter = NULL

					EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @CallistoDatabase, @DimensionName = @DimensionName, @Filter = @Filter, @StorageTypeBM = @StorageTypeBM, @LeafLevelFilter = @LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @GetLeafLevelYN = @GetLeafLevelYN, @JournalDrillYN = @JournalDrillYN, @Debug = @DebugSub

					UPDATE #DimensionFilter
					SET
						[LeafLevelFilter] = @LeafLevelFilter,
						[NodeTypeBM] = @NodeTypeBM
					WHERE
						[DimensionName] = @DimensionName
						AND LEN(ISNULL([LeafLevelFilter], '')) = 0

					IF @StorageTypeBM & 4 > 0 AND LEN(@LeafLevelFilter) > 0
						BEGIN
							SET @SQLStatement = '
								UPDATE DF
								SET
									MemberID = S.MemberID
								FROM
									' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' S
									INNER JOIN #DimensionFilter DF ON DF.DimensionName = ''' + @DimensionName + '''
								WHERE
									Label IN (' + @LeafLevelFilter + ')'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END
					FETCH NEXT FROM Dimension_Cursor INTO @DimensionName, @Filter, @StorageTypeBM
				END

		CLOSE Dimension_Cursor
		DEALLOCATE Dimension_Cursor

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionFilter', * FROM #DimensionFilter ORDER BY [ID]


SELECT 'Arne2', * FROM #DimensionFilter
*/
	SET @Step = 'Set FiscalYear'
		SELECT
			[YearMonth] = CASE WHEN REPLACE([value], '''', '') BETWEEN 19000101 AND 20991231 THEN REPLACE([value], '''', '') / 100 ELSE REPLACE([value], '''', '') END
		INTO
			#YearMonth
		FROM STRING_SPLIT((SELECT TOP 1  
									DF.[LeafLevelFilter] 
							FROM #DimensionFilter DF 
							-- In case @DataClassID is null - we don't check: are there DF.DimensionID in [DataClass_Dimension] for @DataClassID
							-- In case @DataClassID is NOT null - we are checking
							JOIN  [pcINTEGRATOR_Data].[dbo].DataClass_Dimension DCD ON	DCD.DataClassID = COALESCE (@DataClassID, DCD.DataClassID) 
																					AND DCD.DimensionID = DF.DimensionID
							WHERE DF.DimensionID IN (-7, -49) 
							), ',')  

				
		IF @DebugBM & 2 > 0	
			SELECT 
				[@DataClassID] = @DataClassID,
				DCD.*
			FROM
				[pcINTEGRATOR_Data].[dbo].DataClass_Dimension DCD
			WHERE
				DCD.DataClassID = COALESCE (@DataClassID, DCD.DataClassID) AND
				DCD.DimensionID IN (-7, -49)

		IF @DebugBM & 1 > 0 SELECT TempTable = '#YearMonth', * FROM #YearMonth

		SELECT
			@MonthID = MIN([YearMonth])
		FROM
			#YearMonth
			
		IF @DebugBM & 2 > 0 SELECT [@MonthID] = @MonthID

		SELECT @Entity_MemberId = MemberId FROM #DimensionFilter WHERE DimensionID = -4

		IF @DebugBM & 2 > 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@EntityID] = @EntityID, [@Entity_MemberId] = @Entity_MemberId, [@Entity] = @Entity, [@Book] = @Book, [@MonthID] = @MonthID

		EXEC dbo.[spGet_Entity_FiscalYear_StartMonth] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @MonthID = @MonthID, @FiscalYear = @FiscalYear OUT, @FiscalPeriod = @FiscalPeriod OUT,  @StartMonth = @StartMonth OUT
				
		IF @DebugBM & 2 > 0 SELECT [@FiscalYear] = @FiscalYear, [@FiscalPeriod] = @FiscalPeriod, [@StartMonth] = @StartMonth, [@Time_MemberId] = @MonthID

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
			[DimensionName] = 'FiscalYear',
			[StorageTypeBM] = 1,
			[Filter] = CONVERT(nvarchar(10), @FiscalYear),
			[LeafLevelFilter] = '''' + CONVERT(nvarchar(10), @FiscalYear) + '''',
			[NodeTypeBM] = 1,
			[DataColumn] = 'FiscalYear',
			[FilterName] = 'FiscalYear',
			[SelectYN] = 1
		UNION
		SELECT
			[DimensionName] = 'Book',
			[StorageTypeBM] = 1,
			[Filter] = @Book,
			[LeafLevelFilter] = '''' + @Book + '''',
			[NodeTypeBM] = 1,
			[DataColumn] = 'Book',
			[FilterName] = 'Book',
			[SelectYN] = 1

	SET @Step = 'Handle custom dimension FiscalPeriod (i.e. BROOK)'
		SELECT 
			@DimensionID_FiscalPeriod = DimensionID 
		FROM 
			[pcINTEGRATOR].[dbo].Dimension 
		WHERE 
			InstanceID IN (0, @InstanceID) AND 
			DimensionName = 'FiscalPeriod' AND 
			DeletedID IS NULL

		SELECT 
			@FiscalPeriod_Filter = [Filter] 
		FROM 
			#DimensionFilter 
		WHERE 
			DimensionName = 'FiscalPeriod' AND 
			DimensionID = @DimensionID_FiscalPeriod AND 			
			LEN([Filter]) > 0 AND
			[Filter] <> 'All_'

		IF @DebugBM & 2 > 0 SELECT [@DimensionID_FiscalPeriod] = @DimensionID_FiscalPeriod, [@FiscalPeriod_Filter] = @FiscalPeriod_Filter

		IF @ResultTemplate = 'Journal' AND @FiscalPeriod_Filter IS NOT NULL
			BEGIN
				SELECT @FiscalPeriod_Jrn_FY = LEFT(@FiscalPeriod_Filter, 4)

				IF @DebugBM & 2 > 0 SELECT [@FiscalPeriod_Jrn_FY] = @FiscalPeriod_Jrn_FY

				UPDATE DF
				SET 
					[StorageTypeBM] = 1,
					[Filter] = @FiscalPeriod_Jrn_FY,
					[LeafLevelFilter] = '''' + @FiscalPeriod_Jrn_FY + '''',
					[NodeTypeBM] = 1,
					[DataColumn] = 'FiscalYear',
					[FilterName] = 'FiscalYear',
					[SelectYN] = 1
				FROM 
					#DimensionFilter DF
				WHERE 
					DF.[DimensionName] = 'FiscalYear'

				SELECT 
					[FiscalPeriod] = CASE WHEN RIGHT(REPLACE([value], '''', ''), 2) > 9 THEN RIGHT(REPLACE([value], '''', ''), 2) ELSE RIGHT(REPLACE([value], '''', ''), 2) % 10 END 
				INTO
					#FiscalPeriod_LeafLevelFilter
				FROM STRING_SPLIT((SELECT [LeafLevelFilter] FROM #DimensionFilter WHERE DimensionID = @DimensionID_FiscalPeriod), ',')  

				IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod_LeafLevelFilter', * FROM #FiscalPeriod_LeafLevelFilter

				SELECT @FiscalPeriod_Jrn_FP = @FiscalPeriod_Jrn_FP + '''' + CONVERT(NVARCHAR(15),[FiscalPeriod]) + '''' + ',' FROM #FiscalPeriod_LeafLevelFilter
				SET @FiscalPeriod_Jrn_FP = LEFT(@FiscalPeriod_Jrn_FP, LEN(@FiscalPeriod_Jrn_FP) - 1)

				IF @DebugBM & 2 > 0 SELECT [@FiscalPeriod_Jrn_FP] = @FiscalPeriod_Jrn_FP

				UPDATE DF
				SET 
					[StorageTypeBM] = 1,
					[LeafLevelFilter] = @FiscalPeriod_Jrn_FP,
					[NodeTypeBM] = 1,
					[DataColumn] = 'FiscalPeriod',
					[FilterName] = 'FiscalPeriod',
					[SelectYN] = 1	
				FROM 
					#DimensionFilter DF
				WHERE 
					DF.[DimensionName] = 'FiscalPeriod'
				
			END

	SET @Step = 'Calculate filter string'
		SELECT @Filter = '', @LeafLevelFilter = ''
		SELECT
			@Filter = @Filter + [DimensionName] + '=' + [Filter] + '|',
			@LeafLevelFilter = @LeafLevelFilter + '[' + [DimensionName] + '] IN(' + [LeafLevelFilter] + ')|'
		FROM
			#DimensionFilter
		WHERE
			[Filter] IS NOT NULL
		ORDER BY
			ID

		SELECT
			@Filter = LEFT(@Filter, LEN(@Filter) - 1),
			@LeafLevelFilter = LEFT(@LeafLevelFilter, LEN(@LeafLevelFilter) - 1)

	SET @Step = 'Return data'
		IF @DebugBM & 1 > 0 
			BEGIN
				SELECT [@ResultTemplate] = @ResultTemplate, [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@ResultTypeBM] = @ResultTypeBM, [@FieldTypeBM] = 1, [@SQL_MultiDimJoin] = @SQL_MultiDimJoin, [@Rows] = @Rows, [@Debug] = @DebugSub
				SELECT [TempTable] = '#DimensionFilter', * FROM #DimensionFilter
			END
		
		IF @ResultTemplate = 'Journal'
			EXEC [dbo].[spPortalGet_Journal] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @ResultTypeBM = @ResultTypeBM, @FieldTypeBM = @FieldTypeBM, @SQL_MultiDimJoin = @SQL_MultiDimJoin, @Rows = @Rows, @Debug = @DebugSub
		ELSE IF @ResultTemplate = 'Generic'
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@ETLDatabase] = @ETLDatabase, [@DataClassName] = @DataClassName
				
				CREATE TABLE #CheckExistence
					(
					[name] nvarchar(100)
					)

				SET @SQLStatement = '
					INSERT INTO #CheckExistence
						(
						[name]
						)
					SELECT
						[name] 
					FROM
						' + @ETLDatabase + '.sys.procedures
					WHERE
						[name] = ''spPortalGet_' + @DataClassName + '_Drill_HC_20231221_nehatest'''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @CheckExistence = @@ROWCOUNT

				IF @DebugBM & 2 > 0 SELECT TempTable = '#CheckExistence', * FROM #CheckExistence

				DROP TABLE #CheckExistence

				IF @CheckExistence <> 0
					BEGIN
						SET ANSI_WARNINGS ON
						SET @SQLStatement = '[' + @ETLDatabase + '].[dbo].[spPortalGet_' + @DataClassName + '_Drill_HC_20231221_nehatest] @UserID = ' + CONVERT(nvarchar(15), @UserID) + ', @InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ', @VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ', @ResultTypeBM = ' + CONVERT(nvarchar(15), @ResultTypeBM) + CASE WHEN @Rows IS NOT NULL THEN ', @Rows = ' + CONVERT(nvarchar(15), @Rows) ELSE '' END + ', @JobID = ' + CONVERT(nvarchar(15), @JobID) + ', @Debug = ' + CONVERT(nvarchar(15), @DebugSub)
						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END
				ELSE
					BEGIN
						SET @Message = 'Template for ' + @ResultTemplate + ' is not yet implemented'
						SET @Severity = 0
						GOTO EXITPOINT
					END
			END
		ELSE
			BEGIN
				SET @Message = 'Template for ' + @ResultTemplate + ' is not yet implemented'
				SET @Severity = 0
				GOTO EXITPOINT
			END

	SET @Step = 'Drop temp tables'
--		DROP TABLE #Filter
--		DROP TABLE #Month

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
