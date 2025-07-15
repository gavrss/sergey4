SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- Stored Procedure

CREATE PROCEDURE [dbo].[spPortalConvert_PCFULLCV_Filter]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@PCFULLCV PCFULLCV READONLY,
	@JSON_table nvarchar(max) = NULL,
	@Filter nvarchar(max) = NULL OUT,
	@LeafLevelFilter nvarchar(max) = NULL OUT,
	@ProcessName nvarchar(100) = NULL OUT,
	@GetLeafLevelYN bit = 1,
	@ResultTypeBM int = 7,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000319,
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
EXEC spRun_Procedure_KeyValuePair @ProcedureName='spPortalConvert_PCFULLCV_Filter',@JSON='[{"TKey":"DebugBM","TValue":"7"},
{"TKey":"UserID","TValue":"7944"},{"TKey":"InstanceID","TValue":"478"},{"TKey":"VersionID","TValue":"1030"},
{"TKey":"ResultTypeBM","TValue":"36"},{"TKey":"Rows","TValue":"500"}]',
@JSON_table='[
{"TKey":"[Account].[Account]","TValue":"[Account].[Account].[Account_L12].&[1159]"},
{"TKey":"[BusinessProcess].[BusinessProcess]","TValue":"[BusinessProcess].[BusinessProcess].[BusinessProcess_L2].&[200]"},
{"TKey":"[BusinessRule].[BusinessRule]","TValue":"[BusinessRule].[BusinessRule].[BusinessRule_L1].&[1]"},
{"TKey":"[Currency].[Currency]","TValue":"[Currency].[Currency].[Currency_L2].&[826]"},
{"TKey":"[Entity].[Entity]","TValue":"[Entity].[Entity].[Entity_L2].&[30000001]"},
{"TKey":"[GL_COST_CENTRE].[GL_COST_CENTRE]","TValue":"[GL_COST_CENTRE].[GL_COST_CENTRE].[GL_COST_CENTRE_L1].&[1]"},
{"TKey":"[GL_DIVISION].[GL_DIVISION]","TValue":"[GL_DIVISION].[GL_DIVISION].[GL_DIVISION_L4].&[1002]"},
{"TKey":"[GL_Posted].[GL_Posted]","TValue":"[GL_Posted].[GL_Posted].[GL_Posted_L1].&[1]"},
{"TKey":"[LineItem].[LineItem]","TValue":"[LineItem].[LineItem].[LineItem_L2].&[-1]"},
{"TKey":"[Measures]","TValue":"[Financials_Measures].[Financials_Value]"},
{"TKey":"[Scenario].[Scenario]","TValue":"[Scenario].[Scenario].[Scenario_L2].&[110]"},
{"TKey":"[Time].[Time]","TValue":"[Time].[Time].[Month].&[202011]"},
{"TKey":"[TimeDataView].[TimeDataView]","TValue":"[TimeDataView].[TimeDataView].[TimeDataView_L2].&[102]"},
{"TKey":"[Version].[Version]","TValue":"[Version].[Version].[Version_L2].&[-1]"},
{"TKey":"[WorkflowState].[WorkflowState]","TValue":"[WorkflowState].[WorkflowState].[WorkflowState_L1].&[1]"}]'

CREATE TYPE dbo.PCFULLCV AS TABLE ([Key] nvarchar(255), [Value] nvarchar(255))  

SELECT 
	tt.[name],
	c.*
FROM
	sys.table_types tt
	INNER JOIN sys.columns c ON c.object_id = tt.type_table_object_id
WHERE
	tt.user_type_id = 259

DECLARE @p2 dbo.PCFULLCV, @ProcessName nvarchar(100)
insert into @p2 values(N'[Account].[Account]',N'[Account].[Account].[Account_L6].&[1546]')
insert into @p2 values(N'[BusinessProcess].[BusinessProcess]',N'[BusinessProcess].[BusinessProcess].[BusinessProcess_L2].&[200]')
insert into @p2 values(N'[Currency].[Currency]',N'[Currency].[Currency].[Currency_L2].&[840]')
insert into @p2 values(N'[Entity].[Entity]',N'[Entity].[Entity].[Entity_L1].&[10447]')
insert into @p2 values(N'[GL_Department].[GL_Department]',N'[GL_Department].[GL_Department].[GL_Department_L1].&[1213]')
--insert into @p2 values(N'[GL_Project].[GL_Project]',N'[GL_Project].[GL_Project].[GL_Project_L1].&[-1]')
insert into @p2 values(N'[LineItem].[LineItem]',N'[LineItem].[LineItem].[LineItem_L1].&[-1]')
insert into @p2 values(N'[Measures]',N'[Measures].[Financials_Value]')
insert into @p2 values(N'[Scenario].[Scenario]',N'[Scenario].[Scenario].[Scenario_L1].&[1354]')
insert into @p2 values(N'[Time].[Time]',N'[Time].[Time].[Year].&[200906]')
insert into @p2 values(N'[TimeDataView].[TimeDataView]',N'[TimeDataView].[TimeDataView].[TimeDataView_L2].&[103]')
insert into @p2 values(N'[Version].[Version]',N'[Version].[Version].[Version_L2].&[-1]')

EXEC dbo.[spPortalConvert_PCFULLCV_Filter] @UserID = 3813, @InstanceID = 413, @VersionID = 1008, @PCFULLCV = @p2, @Rows = 100, @ResultTypeBM = 39
, @Debug = 1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalConvert_PCFULLCV_Filter',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"3813"},
		{"TKey":"InstanceID", "TValue":"413"},
		{"TKey":"VersionID", "TValue":"1008"},
		{"TKey":"Rows", "TValue":"100"},
		{"TKey":"ResultTypeBM", "TValue":"39"}
		]',
	@JSON_table = '
		[
		{"TKey":"[Account].[Account]", "TValue":"[Account].[Account].[Account_L6].&[1546]"},
		{"TKey":"[BusinessProcess].[BusinessProcess]", "TValue":"[BusinessProcess].[BusinessProcess].[BusinessProcess_L2].&[200]"},
		{"TKey":"[Currency].[Currency]", "TValue":"[Currency].[Currency].[Currency_L2].&[840]"},
		{"TKey":"[Entity].[Entity]", "TValue":"[Entity].[Entity].[Entity_L1].&[10447]"},
		{"TKey":"[GL_Department].[GL_Department]", "TValue":"[GL_Department].[GL_Department].[GL_Department_L1].&[1213]"},
		{"TKey":"[LineItem].[LineItem]", "TValue":"[LineItem].[LineItem].[LineItem_L1].&[-1]"},
		{"TKey":"[Measures]", "TValue":"[Measures].[Financials_Value]"},
		{"TKey":"[Scenario].[Scenario]", "TValue":"[Scenario].[Scenario].[Scenario_L1].&[1354]"},
		{"TKey":"[Time].[Time]", "TValue":"[Time].[Time].[Year].&[200906]"},
		{"TKey":"[TimeDataView].[TimeDataView]", "TValue":"[TimeDataView].[TimeDataView].[TimeDataView_L2].&[103]"},
		{"TKey":"[Version].[Version]", "TValue":"[Version].[Version].[Version_L2].&[-1]"}
		]'

EXEC [spPortalConvert_PCFULLCV_Filter] @InstanceID='413',@ResultTypeBM='3',@UserID='2151',@VersionID='1008', @JSON_table='[{"TKey":"[Account].[CBN]","TValue":"[Account].[CBN].[CBN_L8].&amp;[1393]"},{"TKey":"[BusinessProcess].[BusinessProcess]","TValue":"[BusinessProcess].[BusinessProcess].[BusinessProcess_L2].&amp;[200]"},{"TKey":"[BusinessRule].[BusinessRule]","TValue":"[BusinessRule].[BusinessRule].[BusinessRule_L1].&amp;[1]"},{"TKey":"[Currency].[Currency]","TValue":"[Currency].[Currency].[Currency_L2].&amp;[840]"},{"TKey":"[Entity].[Entity]","TValue":"[Entity].[Entity].[Entity_L2].&amp;[30000059]"},{"TKey":"[GL_Department].[GL_Department]","TValue":"[GL_Department].[GL_Department].[GL_Department_L5].&amp;[1144]"},{"TKey":"[GL_Project].[GL_Project]","TValue":"[GL_Project].[GL_Project].[GL_Project_L1].&amp;[1]"},{"TKey":"[LineItem].[LineItem]","TValue":"[LineItem].[LineItem].[LineItem_L1].&amp;[1]"},{"TKey":"[Measures]","TValue":"[Measures].[Financials_Value]"},{"TKey":"[Scenario].[Scenario]","TValue":"[Scenario].[Scenario].[Scenario_L2].&amp;[110]"},{"TKey":"[Time].[Time]","TValue":"[Time].[Time].[Month].&amp;[201908]"},{"TKey":"[TimeDataView].[TimeDataView]","TValue":"[TimeDataView].[TimeDataView].[TimeDataView_L2].&amp;[103]"},{"TKey":"[Version].[Version]","TValue":"[Version].[Version].[Version_L2].&amp;[-1]"},{"TKey":"[WorkflowState].[WorkflowState]","TValue":"[WorkflowState].[WorkflowState].[WorkflowState_L1].&amp;[1]"}]'

EXEC [spPortalConvert_PCFULLCV_Filter] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DimensionName nvarchar(100),
	@MemberID bigint,
	@ApplicationID int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@ResultTemplate nvarchar(50),
	@TimeDataView_MemberId bigint,
	@Time_MemberId bigint,
	@Entity_MemberId bigint,
	@Entity_MemberKey nvarchar(50),
	@EntityID int,
	@Entity_LeafLevelFilter nvarchar(max),
	@Book_LeafLevelFilter nvarchar(max) = '',
	@Book nvarchar(50),
	@CharIndex int,
	@FiscalYear int,
	@FiscalPeriod int,
	@StartMonth int,
	@Parameter nvarchar(4000),
	@NodeTypeBM int,
	@JournalDrillYN bit = 1,

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
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.0.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Drill from Callisto reports into source data.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2141' SET @Description = 'Added support for JSON table.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2149' SET @Description = 'Added Debug filter for ResultTemplate = Journal.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-329: Enhanced debugging. DB-336: Added @JournalDrillYN parameter.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-336: Added MappingTypeID to temp table #DimensionFilter.'
		IF @Version = '2.1.0.2162' SET @Description = 'DB-579: Set [Filter] column in #DimensionFilter for Dimension Entity. Enhanced debugging.'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle Group and empty segments.'
		IF @Version = '2.1.0.2174' SET @Description = 'Step: Set FiscalYear. Get the first month from several parts inside LeafLevelFilter by MemberId key. Instead of using MemberID.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
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
			@ApplicationID = ApplicationID,
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = ETLDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND 
			SelectYN <> 0

	/*
	SET @Step = 'Set @Parameter'
		SET @Parameter = 
			'EXEC [spPortalConvert_PCFULLCV_Filter] ' +
			'@UserID = ' + ISNULL(CONVERT(nvarchar(10), @UserID), 'NULL') + ', ' +
			'@InstanceID = ' + ISNULL(CONVERT(nvarchar(10), @InstanceID), 'NULL') + ', ' +
			'@VersionID = ' + ISNULL(CONVERT(nvarchar(10), @VersionID), 'NULL') + ', ' +
			'@PCFULLCV = ''' + CONVERT(nvarchar(4000), @PCFULLCV) + ''', ' +
			'@GetLeafLevelYN = ' + ISNULL(CONVERT(nvarchar(10), CONVERT(int, @GetLeafLevelYN)), 'NULL') + ', ' +
			'@ResultTypeBM = ' + ISNULL(CONVERT(nvarchar(10), @ResultTypeBM), 'NULL')
	*/

	SET @Step = 'Create and fill Temp table #DimensionFilter'
		CREATE TABLE #DimensionFilter
			(
			[ID] INT IDENTITY(1,1) PRIMARY KEY,
			[DimensionID] int,
			[DimensionName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[MemberID] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] int,
			[MappingTypeID] int,
			[Filter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[DataColumn] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[FilterName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SelectYN] bit
			)

		IF @JSON_table IS NOT NULL	
			BEGIN
				INSERT INTO #DimensionFilter
					(
					[DimensionName],
					[MemberID]
					)
				SELECT
					[DimensionName] = RIGHT(LEFT([TKey],CHARINDEX(']',[TKey]) - 1),CHARINDEX(']',[TKey]) - 2),
					[MemberID] = LEFT(RIGHT([TValue],CHARINDEX('[',REVERSE([TValue])) - 1),CHARINDEX('[',REVERSE([TValue])) - 2)
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[TKey] nvarchar(100) COLLATE database_default,
					[TValue] nvarchar(100) COLLATE database_default
					)

				UPDATE DF
				SET
					[DimensionID] = D.[DimensionID]
				FROM
					#DimensionFilter DF
					INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = DF.DimensionName
			END
		ELSE
			INSERT INTO #DimensionFilter
				(
				[DimensionID],
				[DimensionName],
				[MemberID],
				[StorageTypeBM]
				)
			SELECT DISTINCT
				[DimensionID] = D.DimensionID,
				[DimensionName] = RIGHT(LEFT(CV.[Key],CHARINDEX(']',CV.[Key]) - 1),CHARINDEX(']',CV.[Key]) - 2),
				[MemberID] = LEFT(RIGHT(CV.[Value],CHARINDEX('[',REVERSE(CV.[Value])) - 1),CHARINDEX('[',REVERSE(CV.[Value])) - 2),
				[StorageTypeBM] = 4
			FROM
				@PCFULLCV CV
				LEFT JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = RIGHT(LEFT([Key],CHARINDEX(']',[Key]) - 1),CHARINDEX(']',[Key]) - 2)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionFilter', * FROM #DimensionFilter

	SET @Step = 'Set @ProcessName'
		SELECT
			@ProcessName = REPLACE(MemberID, '_Value', '')
		FROM
			#DimensionFilter
		WHERE
			DimensionName = 'Measures'

		SET @ResultTemplate = CASE WHEN @ProcessName IN ('Financials') THEN 'Journal' ELSE 'Generic' END

		IF @DebugBM & 2 > 0 SELECT ResultTypeBM = 0, ResultTemplate = @ResultTemplate

	SET @Step = 'Dimension Cursor'
		DECLARE Dimension_Cursor CURSOR FOR

			SELECT
				DimensionName,
				MemberID
			FROM
				#DimensionFilter
			WHERE
				ISNUMERIC([MemberID]) <> 0
			ORDER BY
				ID

			OPEN Dimension_Cursor
			FETCH NEXT FROM Dimension_Cursor INTO @DimensionName, @MemberID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName, [@MemberID] = @MemberID
					SELECT @Filter = NULL, @LeafLevelFilter = NULL

					IF @DebugBM & 2 > 0
						SELECT 
							[@UserID] = @UserID, 
							[@InstanceID] = @InstanceID, 
							[@VersionID] = @VersionID, 
							[@DatabaseName] = @CallistoDatabase, 
							[@DimensionName] = @DimensionName, 
							[@MemberID] = @MemberID, 
							[@Filter] = @Filter, 
							[@StorageTypeBM] = 4, 
							[@LeafLevelFilter] = @LeafLevelFilter, 
							[@NodeTypeBM]= @NodeTypeBM, 
							[@GetLeafLevelYN] = @GetLeafLevelYN, 
							[@JournalDrillYN] = @JournalDrillYN

					EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @CallistoDatabase, @DimensionName = @DimensionName, @MemberID = @MemberID, @Filter = @Filter OUT, @StorageTypeBM = 4, @LeafLevelFilter = @LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @GetLeafLevelYN = @GetLeafLevelYN, @JournalDrillYN = @JournalDrillYN, @Debug = 0

					UPDATE #DimensionFilter
					SET
						[Filter] = @Filter,
						[LeafLevelFilter] = @LeafLevelFilter,
						[NodeTypeBM] = @NodeTypeBM
					WHERE
						[DimensionName] = @DimensionName

					--Set [Filter] column for Dimension Entity if @Filter IS NULL.
					UPDATE #DimensionFilter
					SET
						[Filter] = REPLACE(@LeafLevelFilter, '''', '')
					WHERE
						[DimensionID] = -4 AND
						@DimensionName = 'Entity' AND
                        @Filter IS NULL

					FETCH NEXT FROM Dimension_Cursor INTO @DimensionName, @MemberID
				END

		CLOSE Dimension_Cursor
		DEALLOCATE Dimension_Cursor

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionFilter', * FROM #DimensionFilter ORDER BY [ID]

	SET @Step = 'Set Group'
		UPDATE #DimensionFilter
		SET
			DataColumn = 'ConsolidationGroup',
			FilterName = 'Group',
			SelectYN = 1
		WHERE
			DimensionID = -35


	SET @Step = 'Set Entity & Book'
		CREATE TABLE #Entity
			(
			Entity_MemberKey nvarchar(50),
			EntityID int,
			Book nvarchar(50)
			)

		SELECT @Entity_LeafLevelFilter = [LeafLevelFilter] + ',' FROM #DimensionFilter WHERE DimensionID = -4

		WHILE CHARINDEX (',', @Entity_LeafLevelFilter) > 0
			BEGIN
				SET @CharIndex = CHARINDEX(',', @Entity_LeafLevelFilter)
				SET @Entity_MemberKey = LTRIM(RTRIM(REPLACE(LEFT(@Entity_LeafLevelFilter, @CharIndex - 1), '''', '')))

				IF CHARINDEX('_', @Entity_MemberKey) = 0
					SELECT
						@Book = EB.Book 
					FROM
						Entity E
						INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 2 > 0
					WHERE
						E.InstanceID = @InstanceID AND
						E.VersionID = @VersionID AND
						E.MemberKey = @Entity_MemberKey
				ELSE
					SELECT @Book = SUBSTRING(@Entity_MemberKey, CHARINDEX('_', @Entity_MemberKey) + 1, LEN(@Entity_MemberKey) - CHARINDEX('_', @Entity_MemberKey))

				SELECT @EntityID = EntityID FROM Entity WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND MemberKey = REPLACE(@Entity_MemberKey, '_' + @Book, '')

				SET @Book_LeafLevelFilter = @Book_LeafLevelFilter + '''' + @Book + '''' + ','

				INSERT INTO #Entity
					(
					Entity_MemberKey,
					EntityID,
					Book
					)
				SELECT
					Entity_MemberKey = @Entity_MemberKey,
					EntityID = @EntityID,
					Book = @Book

				SET @Entity_LeafLevelFilter = SUBSTRING(@Entity_LeafLevelFilter, @CharIndex + 1, LEN(@Entity_LeafLevelFilter) - @CharIndex)
			END

			SET @Book_LeafLevelFilter = LEFT(@Book_LeafLevelFilter, LEN(@Book_LeafLevelFilter) - 1)

			IF @DebugBM & 2 > 0 SELECT TempTable = '#Entity', * FROM #Entity

	SET @Step = 'Set FiscalYear'
		-- Get the first month from several parts inside LeafLevelFilter by MemberId key:
		SELECT TOP 1 @Time_MemberId = LEFT(value, 6) 
		FROM #DimensionFilter 
			CROSS APPLY STRING_SPLIT(REPLACE(LeafLevelFilter, '''', ''), ',') 
		WHERE DimensionID IN (-7, -49) ORDER BY value ASC;

		EXEC dbo.[spGet_Entity_FiscalYear_StartMonth] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @MonthID = @Time_MemberId, @FiscalYear = @FiscalYear OUT, @FiscalPeriod = @FiscalPeriod OUT,  @StartMonth = @StartMonth OUT

		IF @DebugBM & 2 > 0 SELECT '@UserID' = @UserID, '@InstanceID' = @InstanceID, '@VersionID' = @VersionID, '@EntityID' = @EntityID, '@Book' = @Book, '@MonthID' = @Time_MemberId, '@FiscalYear' = @FiscalYear , '@FiscalPeriod' = @FiscalPeriod ,  '@StartMonth' = @StartMonth 			

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
			[LeafLevelFilter] = @Book_LeaflevelFilter,
			[NodeTypeBM] = 1,
			[DataColumn] = 'Book',
			[FilterName] = 'Book',
			[SelectYN] = 1

	SET @Step = 'Handle TimeDataView = YTD'
		SELECT @TimeDataView_MemberId = MemberId FROM #DimensionFilter WHERE DimensionID = -8

		IF @DebugBM & 2 > 0 SELECT ResultTemplate = @ResultTemplate, TimeDataView_MemberId = @TimeDataView_MemberId, StartMonth = @StartMonth, Time_MemberId = @Time_MemberId

		IF @TimeDataView_MemberId = 103 AND LEN(@Time_MemberId) > 4 AND @ResultTemplate = 'Journal'
			BEGIN
				SELECT DISTINCT TOP 1000000
					[Month_MemberId] = Y.Y * 100 + M.M,
					[Month] = CONVERT(nvarchar(10), Y.Y * 100 + M.M) COLLATE DATABASE_DEFAULT
				INTO
					[#Month]
				FROM
					(
						SELECT
							[Y] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
						FROM
							Digit D1,
							Digit D2,
							Digit D3,
							Digit D4
						WHERE
							D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartMonth / 100 AND @Time_MemberId / 100
					) Y,
					(
						SELECT
							[M] = D2.Number * 10 + D1.Number + 1 
						FROM
							Digit D1,
							Digit D2
						WHERE
							D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
					) M 
				ORDER BY
					CONVERT(nvarchar(10), Y.Y * 100 + M.M)

				SET @LeafLevelFilter = ''
				SELECT @LeafLevelFilter = @LeafLevelFilter + '''' + [Month] + ''',' FROM [#Month] WHERE [Month_MemberId] BETWEEN @StartMonth AND @Time_MemberId ORDER BY [Month_MemberId]
				SET @LeafLevelFilter = LEFT(@LeafLevelFilter, LEN(@LeafLevelFilter) - 1)
				IF @DebugBM & 2 > 0 SELECT LeafLevelFilter = @LeafLevelFilter 
				UPDATE #DimensionFilter SET LeafLevelFilter = @LeafLevelFilter WHERE DimensionID IN (-7, -49)
				IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionFilter', * FROM #DimensionFilter ORDER BY [ID]
				DROP TABLE [#Month]
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

		IF @DebugBM & 1 > 0 SELECT TempTable = '#DimensionFilter', * FROM #DimensionFilter

	SET @Step = 'Return data'
		IF @ResultTemplate = 'Journal'
			BEGIN
				EXEC [dbo].[spPortalGet_Journal] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @ResultTypeBM = @ResultTypeBM, @FieldTypeBM = 3, @Rows = @Rows, @Debug = @DebugSub
			END
		ELSE IF @ResultTemplate = 'Generic'
			BEGIN
				SET @Message = 'Template for ' + @ResultTemplate + ' is not yet implemented'
				SET @Severity = 16
				GOTO EXITPOINT
			END
		ELSE
			BEGIN
				SET @Message = 'Template for ' + @ResultTemplate + ' is not yet implemented'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #DimensionFilter
		DROP TABLE #Entity

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
