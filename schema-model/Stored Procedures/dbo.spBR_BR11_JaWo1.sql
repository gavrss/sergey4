SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR11_JaWo1]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@FromTime int = NULL,
	@ToTime int = NULL,
	@DataClassID int = NULL,
	@InterCompanySelection nvarchar(100) = NULL,	
	@DimensionFilter nvarchar(4000) = NULL,
	@EventTypeID int = NULL,
	@CallistoRefreshYN bit = 1,
	@CallistoRefreshAsynchronousYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000758,
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
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"DebugBM","TValue":"7"},
{"TKey":"InstanceID","TValue":"572"},{"TKey":"ToTime","TValue":"202303"},{"TKey":"UserID","TValue":"9863"},
{"TKey":"BusinessRuleID","TValue":"2632"},{"TKey":"VersionID","TValue":"1080"},{"TKey":"FromTime","TValue":"202204"}]', @ProcedureName='spBR_BR11'

EXEC spBR_BR11 @BusinessRuleID='2360',@FromTime='202007',@InstanceID='548',@ToTime='202106',@UserID='9548',@VersionID='1061',@DebugBM=15
EXEC spBR_BR11 @BusinessRuleID='2360',@FromTime='202107',@InstanceID='548',@ToTime='202106',@UserID='9548',@VersionID='1061',@DebugBM=15

EXEC spBR_BR11 @BusinessRuleID='2360',@FromTime='202008',@InstanceID='548',@ToTime='202106',@UserID='7888',@VersionID='1061',@DebugBM=15

EXEC [spBR_BR11] @UserID=-10, @InstanceID=454, @VersionID=1021, @BusinessRuleID = 12183, @FromTime = 202101, @ToTime = 202112, @DebugBM = 3
EXEC [spBR_BR11] @UserID=-10, @InstanceID=454, @VersionID=1021, @BusinessRuleID = 12183, @FromTime = 201901, @ToTime = 201912, @DebugBM = 11
EXEC [spBR_BR11] @UserID=-10, @InstanceID=525, @VersionID=1054, @BusinessRuleID = 2309, @FromTime = 202001, @ToTime = 202112, @DebugBM = 11

EXEC [spBR_BR11] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CallistoDatabase NVARCHAR(100),
	@SQLFilter NVARCHAR(MAX),
	--@Elim_Currency_MemberId bigint,
	--@Scenario_MemberId bigint,

	@Elim_Currency_String NVARCHAR(1000),
	@Scenario_String NVARCHAR(1000),

	@SQLStatement NVARCHAR(MAX),
	@BP_Elim_MemberID BIGINT,
	@BP_LeafLevelFilter NVARCHAR(4000),
	@InterCompanySelection_Dimension NVARCHAR(100),
	@InterCompanySelection_Property NVARCHAR(100),
	@Entity_MemberId BIGINT,
	@EntityParent_MemberId BIGINT,
	@Path NVARCHAR(1000),
	@Depth INT,
	@DataClassName NVARCHAR(100),
	@DC_StorageTypeBM INT,
	@ColumnName NVARCHAR(100),
	@DataType NVARCHAR(20),
	@SQL_Insert NVARCHAR(4000) = '',
	@SQL_Select NVARCHAR(4000) = '',
	@EnhancedStorageYN bit,

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
	@ModifiedBy NVARCHAR(50) = 'JaWo',
	@Version NVARCHAR(50) = '2.1.2.2193'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Multi-company consolidation eliminations (standard)',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2168' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Updated @ProcedureDescription.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added NULL checking for [Elim] property in the #Entity INSERT query. Handle multiple scenarios and multiple currencies.'
		IF @Version = '2.1.1.2172' SET @Description = 'Remove test of property NoAutoElim when set variable @BP_Elim_MemberID.'
		IF @Version = '2.1.1.2173' SET @Description = 'Updated version of temp table #FilterTable.'
		IF @Version = '2.1.2.2179' SET @Description = 'Filter on not selected and deleted dimensions.'
		IF @Version = '2.1.2.2183' SET @Description = 'Added [StorageTypeBM] and [SortOrder] columns in #FilterTable.'
		IF @Version = '2.1.2.2193' SET @Description = 'Handle @CallistoRefreshYN and @EnhancedStorageYN.'

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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT 
			@DataClassID = ISNULL(@DataClassID, BR11.[DataClassID]),
			@InterCompanySelection = ISNULL(@InterCompanySelection, BR11.[InterCompanySelection]),
			@DimensionFilter = ISNULL(@DimensionFilter, BR11.[DimensionFilter])
		FROM
			pcINTEGRATOR_Data..BR11_Master BR11
			INNER JOIN pcINTEGRATOR_Data..BusinessRule BR ON BR.InstanceID = BR11.InstanceID AND BR.VersionID = BR11.VersionID AND BR.BusinessRuleID = BR11.BusinessRuleID AND BR.SelectYN <> 0 AND BR.DeletedID IS NULL
		WHERE
			BR11.InstanceID = @InstanceID AND
			BR11.VersionID = @VersionID AND
			BR11.BusinessRuleID = @BusinessRuleID AND
			BR11.DeletedID IS NULL

		SELECT
			@DataClassName = DC.DataClassName,
			@DC_StorageTypeBM = DC.StorageTypeBM
		FROM
			pcINTEGRATOR_Data..DataClass DC
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.VersionID = @VersionID AND
			DC.DataClassID = @DataClassID AND
			DC.SelectYN <> 0 AND
			DC.DeletedID IS NULL

		SELECT
			@CallistoDatabase = A.[DestinationDatabase],
			@EnhancedStorageYN = A.[EnhancedStorageYN]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0


		SELECT
			@InterCompanySelection_Dimension = REPLACE(REPLACE(LEFT(@InterCompanySelection, CHARINDEX('.', @InterCompanySelection) -1), '[', ''), ']', ''),
			@InterCompanySelection_Property = REPLACE(REPLACE(SUBSTRING(@InterCompanySelection, CHARINDEX('.', @InterCompanySelection) + 1, LEN(@InterCompanySelection)), '[', ''), ']', '')

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@DataClassID] = @DataClassID,
				[@DataClassName] = @DataClassName,
				[@DC_StorageTypeBM] = @DC_StorageTypeBM,
				[@InterCompanySelection] = @InterCompanySelection,
				[@InterCompanySelection_Dimension] = @InterCompanySelection_Dimension,
				[@InterCompanySelection_Property] = @InterCompanySelection_Property,
				[@DimensionFilter] = @DimensionFilter,
				[@FromTime] = @FromTime,
				[@ToTime] = @ToTime,
				[@EnhancedStorageYN] = @EnhancedStorageYN

	SET @Step = 'Get dimension filter'
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_FilterTable] 
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@StepReference = 'BR11',
			@PipeString = @DimensionFilter, --Mandatory
			@DatabaseName = @CallistoDatabase, --Mandatory
			@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
			@StorageTypeBM = 4, --Mandatory
			@SQLFilter = @SQLFilter OUT,
			@JobID = @JobID,
			@Debug=@DebugSub

--		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = 'BR11'

		--SELECT
		--	[Currency] = REPLACE(REPLACE(LTRIM(RTRIM([Value])), CHAR(13), ''), CHAR(10), '')
		--FROM
		--	STRING_SPLIT((SELECT LeafLevelFilter FROM #FilterTable WHERE DimensionID = -3), ',')
		
		--SELECT
		--	[Scenario] = REPLACE(REPLACE(LTRIM(RTRIM([Value])), CHAR(13), ''), CHAR(10), '')
		--FROM
		--	STRING_SPLIT((SELECT LeafLevelFilter FROM #FilterTable WHERE DimensionID = -6), ',')
		
--		SELECT @Elim_Currency_MemberId = LeafLevelFilter FROM #FilterTable WHERE DimensionID = -3
--RETURN
--		SELECT @Elim_Currency_MemberId = LeafLevelFilter FROM #FilterTable WHERE DimensionID = -3
--		SELECT @Scenario_MemberId = LeafLevelFilter FROM #FilterTable WHERE DimensionID = -6

		SELECT @Elim_Currency_String = LeafLevelFilter FROM #FilterTable WHERE [StepReference] = 'BR11' AND DimensionID = -3
		SELECT @Scenario_String = LeafLevelFilter FROM #FilterTable WHERE [StepReference] = 'BR11' AND DimensionID = -6
		
		IF @DebugBM & 2 > 0
			BEGIN
				SELECT [@SQLFilter] = @SQLFilter, [@Elim_Currency_String] = @Elim_Currency_String, [@Scenario_String] = @Scenario_String --[@Elim_Currency_MemberId] = @Elim_Currency_MemberId, [@Scenario_MemberId] = @Scenario_MemberId
				SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = 'BR11'
			END

	SET @Step = 'Create and fill temp table #Account_Elim'
		CREATE TABLE #Account_Elim
			(
			[Account_MemberId] bigint,
			[Account_MemberKey] nvarchar(100)
			)

		SET @SQLStatement = '
			INSERT INTO #Account_Elim
				(
				[Account_MemberId],
				[Account_MemberKey]
				)
			SELECT
				[Account_MemberId] = [MemberId],
				[Account_MemberKey] = [Label]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Account]
			WHERE 
				IC <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#Account_Elim', * FROM #Account_Elim

	SET @Step = 'Get @BP_Elim_MemberID'
		SET @SQLStatement = '
			SELECT
				@InternalVariable = [MemberId]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_BusinessProcess]
			WHERE 
--				[NoAutoElim] <> 0 AND
				[Label] = ''ELIMINATION'''

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @BP_Elim_MemberID OUT

		IF @DebugBM & 2 > 0 SELECT [@BP_Elim_MemberID] = @BP_Elim_MemberID

	SET @Step = 'Create and fill temp table #BusinessProcess_Elim'
		CREATE TABLE #BusinessProcess_Elim
			(
			[BusinessProcess_MemberId] bigint,
			[BusinessProcess_MemberKey] nvarchar(100)
			)

		SELECT @BP_LeafLevelFilter = [LeafLevelFilter] FROM #FilterTable WHERE [StepReference] = 'BR11' AND DimensionID = -2

		SET @SQLStatement = '
			INSERT INTO #BusinessProcess_Elim
				(
				[BusinessProcess_MemberId],
				[BusinessProcess_MemberKey]
				)
			SELECT
				[BusinessProcess_MemberId] = BP.[MemberId],
				[BusinessProcess_MemberKey] = BP.[Label]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_BusinessProcess] BP
			WHERE 
				BP.[NoAutoElim] = 0 AND
				BP.[MemberId] <> ' + CONVERT(nvarchar(20), @BP_Elim_MemberID) + ' AND
				BP.[MemberId] IN (' + @BP_LeafLevelFilter + ')'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#BusinessProcess_Elim', * FROM #BusinessProcess_Elim

	SET @Step = 'Create and fill temp table #InterCompany'
		CREATE TABLE #InterCompany
			(
			[InterCompany_MemberID] bigint,
			[InterCompany_Entity_MemberID] bigint
			)

		SET @SQLStatement = '
			INSERT INTO #InterCompany
				(
				[InterCompany_MemberID],
				[InterCompany_Entity_MemberID]
				)
			SELECT DISTINCT
				[InterCompany_MemberID] = IC.[MemberId],
				[InterCompany_Entity_MemberID] = ISNULL(E.MemberId, -1)
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @InterCompanySelection_Dimension + '] IC
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Entity] E ON E.[MemberId] = ISNULL(IC.' + @InterCompanySelection_Property + '_MemberId, -1)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#InterCompany', * FROM #InterCompany

	SET @Step = 'Create and fill temp table #Entity'
		CREATE TABLE #EntityPair
			(
			[Entity_MemberId] bigint
			)

		CREATE TABLE #Entity
			(
			[Entity_MemberId] bigint,
			[EntityParent_MemberId] bigint,
			[Entity_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Elim] bit
			)

		SET @SQLStatement = '
			INSERT INTO #Entity
				(
				[Entity_MemberId],
				[EntityParent_MemberId],
				[Entity_MemberKey],
				[Elim]
				)
			SELECT
				[Entity_MemberId] = D.[MemberId],
				[EntityParent_MemberId] = H.[ParentMemberId],
				[Entity_MemberKey] = D.[Label],
				[Elim] = ISNULL(D.[Elim], 0)
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Entity] D
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_Entity_Entity] H ON H.MemberId = D.MemberId'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#Entity', * FROM #Entity

		;WITH cte AS
			(
			SELECT
				D.[Entity_MemberId],
				D.[EntityParent_MemberId],
				Depth = 1,
				[Path] = CONVERT(nvarchar(max), '')
			FROM
				#Entity D
			WHERE
				D.[Entity_MemberId] = 1
			UNION ALL
			SELECT
				D.[Entity_MemberId],
				D.[EntityParent_MemberId],
				C.Depth + 1,
				[Path] = c.[Path] + N'|' + CONVERT(nvarchar(20), D.[EntityParent_MemberId])
			FROM
				#Entity D
				INNER JOIN cte c on c.[Entity_MemberId] = D.[EntityParent_MemberId]
			)

		SELECT
			[Entity_MemberId] = cte.[Entity_MemberId],
			[EntityParent_MemberId] = cte.[EntityParent_MemberId],
			[Path] = cte.[Path],
			[Entity_MemberKey] = E.[Entity_MemberKey],
			[Elim] = E.[Elim],
			[Depth] = cte.[Depth]
		INTO
			#EntityHierarchy
		FROM
			cte
			INNER JOIN #Entity E ON E.[Entity_MemberId] = cte.[Entity_MemberId]
		ORDER BY
			cte.[Depth] DESC,
			cte.[EntityParent_MemberId],
			E.[Elim] DESC

		IF @DebugBM & 2 > 0 SELECT TempTable = '#EntityHierarchy', * FROM #EntityHierarchy ORDER BY [Depth] DESC, [EntityParent_MemberId], [Elim] DESC

	SET @Step = 'Create cursor table for creating temp tables for data'
		CREATE TABLE #DataClassList
			(
			[DataClassID] int,
			[DimensionID] int,
			[ColumnName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DataType] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

		INSERT INTO #DataClassList
			(
			[DataClassID],
			[DimensionID],
			[ColumnName],
			[DataType],
			[SortOrder]
			)
		SELECT 
			[DataClassID] = DC.[DataClassID],
			[DimensionID] = DCD.[DimensionID],
			[ColumnName] = D.[DimensionName] + '_MemberID',
			[DataType] = 'bigint',
			[SortOrder] = DCD.[SortOrder]
		FROM
			pcINTEGRATOR_Data..DataClass DC
			INNER JOIN pcINTEGRATOR_Data..DataClass_Dimension DCD ON DCD.InstanceID = DC.InstanceID AND DCD.VersionID = DC.VersionID AND DCD.DataClassID = DC.DataClassID
			INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.DimensionTypeID <> 27 AND D.SelectYN <> 0 AND D.DeletedID IS NULL
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.VersionID = @VersionID AND
			DC.DataClassID = @DataClassID
		UNION
		SELECT 
			[DataClassID] = M.[DataClassID],
			[DimensionID] = NULL,
			[ColumnName] = M.[MeasureName] + '_Value',
			[DataType] = 'float',
			[SortOrder] = 10000 + M.[SortOrder]
		FROM
			pcINTEGRATOR_Data..Measure M
		WHERE
			M.InstanceID = @InstanceID AND
			M.VersionID = @VersionID AND
			M.DataClassID = @DataClassID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassList', * FROM #DataClassList ORDER BY SortOrder

	SET @Step = 'Create temp table #DC_Source and #DC'
		CREATE TABLE #DC_Source
			(
			[CheckedEntity] [bigint],
			[InterCompany_Entity_MemberID] [bigint]
			)

		CREATE TABLE #DC
			(
			[Dummy] [int] DEFAULT(0)
			)

		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT 
				ColumnName,
				DataType
			FROM
				#DataClassList
			ORDER BY
				DataType,
				SortOrder

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @ColumnName, @DataType

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						ALTER TABLE #DC ADD [' + @ColumnName + '] ' + @DataType + '
						ALTER TABLE #DC_Source ADD [' + @ColumnName + '] ' + @DataType

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					FETCH NEXT FROM AddColumn_Cursor INTO  @ColumnName, @DataType
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

		--CREATE TABLE #DC_Source
		--	(
		--	[InterCompany_Entity_MemberID] [bigint],
		--	[Account_MemberId] [bigint],
		--	[BusinessProcess_MemberId] [bigint],
		--	[BusinessRule_MemberId] [bigint],
		--	[Currency_MemberId] [bigint],
		--	[Entity_MemberId] [bigint],
		--	[Scenario_MemberId] [bigint],
		--	[Time_MemberId] [bigint],
		--	[TimeDataView_MemberId] [bigint],
		--	[Version_MemberId] [bigint],
		--	[WorkflowState_MemberId] [bigint],
		--	[GL_Cost_Center_MemberId] [bigint],
		--	[GL_Product_Category_MemberId] [bigint],
		--	[GL_Project_MemberId] [bigint],
		--	[GL_Trading_Partner_MemberId] [bigint],
		--	[LineItem_MemberId] [bigint],
		--	[Intercompany_MemberId] [bigint],
		--	[Financials_Value] [float],
		--	[CheckedEntity] [bigint]
		--	)

		--CREATE TABLE #DC
		--	(
		--	[Account_MemberId] [bigint],
		--	[BusinessProcess_MemberId] [bigint],
		--	[BusinessRule_MemberId] [bigint],
		--	[Currency_MemberId] [bigint],
		--	[Entity_MemberId] [bigint],
		--	[Scenario_MemberId] [bigint],
		--	[Time_MemberId] [bigint],
		--	[TimeDataView_MemberId] [bigint],
		--	[Version_MemberId] [bigint],
		--	[WorkflowState_MemberId] [bigint],
		--	[GL_Cost_Center_MemberId] [bigint],
		--	[GL_Product_Category_MemberId] [bigint],
		--	[GL_Project_MemberId] [bigint],
		--	[GL_Trading_Partner_MemberId] [bigint],
		--	[LineItem_MemberId] [bigint],
		--	[Intercompany_MemberId] [bigint],
		--	[Financials_Value] [float]
		--	)

	SET @Step = 'Fill temp table #DC_Source'
		SELECT
			@SQL_Insert = @SQL_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '],',
			@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '] = DC.[' + ColumnName + '],'
		FROM
			#DataClassList
		ORDER BY
			SortOrder

		SELECT 
			@SQL_Insert = LEFT(@SQL_Insert, LEN(@SQL_Insert) - 1),
			@SQL_Select = LEFT(@SQL_Select, LEN(@SQL_Select) - 1)

		SET @SQLStatement = '
			INSERT INTO #DC_Source
				(
				[InterCompany_Entity_MemberID],' + @SQL_Insert +'
				)
			SELECT 
				[InterCompany_Entity_MemberID] = IC.[InterCompany_Entity_MemberID],' + @SQL_Select + '
			FROM
				[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC
				INNER JOIN #Account_Elim AE ON AE.Account_MemberId = DC.Account_MemberId
				INNER JOIN #InterCompany IC ON IC.InterCompany_MemberId = DC.' + @InterCompanySelection_Dimension + '_MemberId
				INNER JOIN #BusinessProcess_Elim BPE ON BPE.BusinessProcess_MemberId = DC.BusinessProcess_MemberId
			WHERE
				DC.Time_MemberId BETWEEN ' + CONVERT(nvarchar(15), @FromTime) + ' AND ' + CONVERT(nvarchar(15), @ToTime) + ' AND
				DC.Currency_MemberId IN (' + @Elim_Currency_String + ') AND
				DC.Scenario_MemberId IN (' + @Scenario_String + ')'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_Source', * FROM #DC_Source

	SET @Step = 'Create SQL call to fill #DC from #DC_Source'
		SELECT 
			@SQL_Insert = '',
			@SQL_Select = ''

/*
Flow --> Increase <--> Decrease
*/
		SELECT
			@SQL_Insert = @SQL_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '],',
			@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '] = ' + CASE WHEN ColumnName = 'Flow_MemberId' THEN 'CASE DCS.[Flow_MemberId] WHEN 121 THEN 122 WHEN 122 THEN 121 ELSE DCS.[Flow_MemberId] END' ELSE 'DCS.[' + ColumnName + ']' + CASE WHEN ColumnName LIKE '%_Value' THEN ' * -1' ELSE '' END END + ','
		FROM
			#DataClassList
		WHERE
			[ColumnName] NOT IN ('BusinessProcess_MemberId', 'Entity_MemberId')
		ORDER BY
			SortOrder

		SELECT 
			@SQL_Insert = LEFT(@SQL_Insert, LEN(@SQL_Insert) - 1),
			@SQL_Select = LEFT(@SQL_Select, LEN(@SQL_Select) - 1)

	SET @Step = 'EntityElim_Cursor'
		IF CURSOR_STATUS('global','EntityElim_Cursor') >= -1 DEALLOCATE EntityElim_Cursor
		DECLARE EntityElim_Cursor CURSOR FOR
			
			SELECT
				[Entity_MemberId],
				[EntityParent_MemberId],
				[Path],
				[Depth]
			FROM
				#EntityHierarchy
			WHERE
				[Elim] <> 0
			ORDER BY
				[Depth] DESC,
				[EntityParent_MemberId]

			OPEN EntityElim_Cursor
			FETCH NEXT FROM EntityElim_Cursor INTO @Entity_MemberId, @EntityParent_MemberId, @Path, @Depth

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@Entity_MemberId] = @Entity_MemberId, [@EntityParent_MemberId] = @EntityParent_MemberId, [@Path] = @Path, [@Depth] = @Depth

					TRUNCATE TABLE #EntityPair
					
					INSERT INTO #EntityPair
						(
						[Entity_MemberId]
						)
					SELECT
						[Entity_MemberId]
					FROM
						#EntityHierarchy
					WHERE
						[Elim] = 0 AND
						[Path] LIKE '%' + CONVERT(nvarchar(20), @EntityParent_MemberId) + '%'

					IF @DebugBM & 2 > 0 SELECT TempTable = '#EntityPair', * FROM #EntityPair

					UPDATE FFS
					SET
						FFS.[CheckedEntity] = @Entity_MemberId
					FROM
						#DC_Source FFS
						INNER JOIN #EntityPair EP1 ON EP1.Entity_MemberId = FFS.[Entity_MemberId]
						INNER JOIN #EntityPair EP2 ON EP2.Entity_MemberId = FFS.[InterCompany_Entity_MemberID]
					WHERE
						FFS.[CheckedEntity] IS NULL
					
					SET @SQLStatement = '
						INSERT INTO #DC
							(
							[BusinessProcess_MemberId],
							[Entity_MemberId],' + @SQL_Insert + '
							)
						SELECT 
							[BusinessProcess_MemberId] = ' + CONVERT(nvarchar(20), @BP_Elim_MemberID) + ',
							[Entity_MemberId] = ' + CONVERT(nvarchar(20), @Entity_MemberId) + ',' + @SQL_Select + '
						FROM
							#DC_Source DCS
							INNER JOIN #EntityPair EP1 ON EP1.Entity_MemberId = DCS.[Entity_MemberId]
							INNER JOIN #EntityPair EP2 ON EP2.Entity_MemberId = DCS.[InterCompany_Entity_MemberID]
						WHERE
							DCS.[CheckedEntity] = ' + CONVERT(nvarchar(20), @Entity_MemberId)

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM EntityElim_Cursor INTO  @Entity_MemberId, @EntityParent_MemberId, @Path, @Depth
				END

		CLOSE EntityElim_Cursor
		DEALLOCATE EntityElim_Cursor

		IF @DebugBM & 8 > 0 SELECT TempTable = '#DC', * FROM #DC

	SET @Step = 'Delete old rows from DataClass'
		SET @SQLStatement = '
			DELETE F
			FROM
				[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] F
				INNER JOIN #Entity E ON E.Entity_MemberId = F.Entity_MemberId AND E.Elim <> 0
			WHERE
				[BusinessProcess_MemberId] = ' + CONVERT(nvarchar(20), @BP_Elim_MemberID) + ' AND
				[Time_MemberId] BETWEEN ' + CONVERT(nvarchar(15), @FromTime) + ' AND ' + CONVERT(nvarchar(15), @ToTime) + ' AND
				[Scenario_MemberId] IN (' + @Scenario_String + ')'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Add new rows into DataClass'
		SELECT 
			@SQL_Insert = '',
			@SQL_Select = ''

		SELECT
			@SQL_Insert = @SQL_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '],',
			@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '] = DC.[' + ColumnName + '],'
		FROM
			#DataClassList
		ORDER BY
			SortOrder

		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition]
				(' + @SQL_Insert + '
				[ChangeDatetime],
				[Userid]
				)
			SELECT' + @SQL_Select + '
				[ChangeDatetime] = GetDate(),
				[Userid] = suser_name()
			FROM
				#DC DC'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Run Callisto Refresh'
		IF @CallistoRefreshYN <> 0 AND @DC_StorageTypeBM & 4 > 0 AND @EnhancedStorageYN = 0
			BEGIN
				EXEC [spRun_Job_Callisto_Generic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StepName = 'Refresh', @ModelName = @DataClassName, @AsynchronousYN = @CallistoRefreshAsynchronousYN, @JobID = @JobID
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #Account_Elim
		DROP TABLE #Entity
		DROP TABLE #EntityHierarchy
		DROP TABLE #InterCompany
		DROP TABLE #DC_Source
		DROP TABLE #DC

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
