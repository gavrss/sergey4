SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spBR_BR04]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@EventTypeID int = NULL,
	@BusinessRuleID int = NULL,
	@DataClassID int = NULL,
	@FromTime int = NULL,
	@ToTime int = NULL,
	@Filter nvarchar(max) = NULL,
	@CallistoRefreshYN bit = 1,
	@CallistoRefreshAsynchronousYN bit = 1,
	@CalledBy nvarchar(10) = 'pcPortal', --pcPortal, Callisto, ETL, MasterSP
	@MultiplyYN bit = NULL,
	@BaseCurrency int = NULL,
	@TempTable nvarchar(100) = NULL, --When data is held in a temp table before inserted into DataClass. Used in ETL processes.
	@Operator nvarchar(1) = NULL OUT,
	@Parameter nvarchar(4000) = NULL, 

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000566,
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
EXEC [spBR_BR04] @UserID=-10, @InstanceID=454, @VersionID=1021, @BusinessRuleID = NULL, @DataClassID = 5153, @Filter = 'FilterType=MemberID|BusinessProcess=30000001|Entity=30000008|Scenario=110|Time=201912', @DebugBM=3 --Financials
EXEC [spBR_BR04] @UserID=-10, @InstanceID=454, @VersionID=1021, @BusinessRuleID = NULL, @DataClassID = 5152, @Filter = 'FilterType=MemberID|Scenario=110|TimeDay=201905', @DebugBM=3 --Sales
EXEC [spBR_BR04] @CalledBy='Callisto',@DataClassID='7480',@DebugBM='3',@Filter='FilterType=MemberID|BusinessProcess=200|Entity=30000018|Scenario=110|Time=2020',@InstanceID='-1335',@JobID='28',@MultiplyYN='1',@UserID='-10',@VersionID='-1273'
EXEC spBR_BR04 @CalledBy='pcPortal', @BusinessRuleID = 9073, @InstanceID='454', @UserID='-10', @VersionID='1021', @Debug='1'

EXEC [spBR_BR04] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@None_MemberId bigint = -1,
	@BusinessRule_Conversion_MemberId bigint = 101,
	@StorageTypeBM_DataClass int,
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLStatement_Insert nvarchar(4000) = '',
	@SQLStatement_Select nvarchar(4000) = '',
	@SQLStatement_NotExists nvarchar(4000) = '',
	@DataClassID_Currency int,
	@StorageTypeBM_DataClass_Currency int,
	@DataClassName nvarchar(50),
	@DataClassName_Currency nvarchar(50),
	@TableName_DataClass nvarchar(100),
	@TableName_DataClass_Currency nvarchar(100),
	@ColumnName nvarchar(100),
	@DataType nvarchar(20),
	@LeafLevelFilter nvarchar(max) = '',
	@BaseCurrencyYN bit,
	@BusinessRuleYN bit,
	@SimulationYN bit,
	@TimeTypeID int,

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Running business rule BR04 - Fx conversion.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Set ProcedureID in JobLog. Added @Parameter.'
		IF @Version = '2.1.0.2157' SET @Description = 'Filter on FxRate <> 0.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added parameter @TempTable to handle data in temp tables.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added @AuthenticatedUserID.'
		IF @Version = '2.1.0.2163' SET @Description = 'DB-591: Increased nvarchar size for parameter @TempTable from 50 to 100.'
		IF @Version = '2.1.1.2168' SET @Description = 'Changed multiply handling. Improved error and debug handling.'
		IF @Version = '2.1.1.2169' SET @Description = 'Exclude [DimensionTypeID] = 27 from FACT temp table.'
		IF @Version = '2.1.1.2170' SET @Description = 'Handle @CalledBy = MasterSP.'
		IF @Version = '2.1.1.2171' SET @Description = 'Modified INSERT query to #DataClassList - [Measure] table INNER JOIN to [DataClass].'
		IF @Version = '2.1.1.2172' SET @Description = 'Read column [EqualityString] from table #FilterTable when setting @LeafLevelFilter.'
		IF @Version = '2.1.2.2173' SET @Description = 'Updated version of temp table #FilterTable. Added @JobID in the [spRun_Job_Callisto_Generic] parameter. Set severity for no reporting currencies to 0.'
		IF @Version = '2.1.2.2174' SET @Description = 'Added new parameters @FromTime, @ToTime, @CallistoRefreshYN, @CallistoRefreshAsynchronousYN.'
		IF @Version = '2.1.2.2181' SET @Description = 'Added columns to temptable #FilterTable.'
		IF @Version = '2.1.2.2183' SET @Description = 'Updated temp table deletion.'
		IF @Version = '2.1.2.2199' SET @Description = 'Updated to lates sp template. Removed filter condition (@CalledBy = Callisto) in the checker sections.'

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
			@ETLDatabase = ETLDatabase,
			@CallistoDatabase = DestinationDatabase
		FROM
			pcINTEGRATOR_Data..[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID 

		IF @BusinessRuleID IS NOT NULL
			BEGIN
				SELECT
					@DataClassID = ISNULL(@DataClassID, [DataClassID]),
					@Filter = ISNULL(@Filter, [DimensionFilter]),
					@MultiplyYN = ISNULL(@MultiplyYN, [MultiplyYN]),
					@BaseCurrency = ISNULL(@BaseCurrency, [BaseCurrency])
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR04_Master]
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					BusinessRuleID = @BusinessRuleID
			END

		SELECT
			@StorageTypeBM_DataClass = StorageTypeBM,
			@DataClassName = DataClassName
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassID = @DataClassID

		SELECT
			@StorageTypeBM_DataClass_Currency = StorageTypeBM,
			@DataClassName_Currency = DataClassName
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassTypeID = -6

		SELECT
			@TableName_DataClass = ISNULL(@TempTable, CASE WHEN @StorageTypeBM_DataClass & 4 > 0 THEN '[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition]' ELSE '[' + @ETLDatabase + '].[dbo].[pcDC_' + @DataClassName + ']' END),
			@TableName_DataClass_Currency = CASE WHEN @StorageTypeBM_DataClass_Currency & 4 > 0 THEN '[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName_Currency + '_default_partition]' ELSE '[' + @ETLDatabase + '].[dbo].[pcDC_' + @DataClassName_Currency + ']' END

		SELECT
			@MultiplyYN = COALESCE(@MultiplyYN, [MultiplyYN], 1)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Instance]
		WHERE
			[InstanceID] = @InstanceID

		SET @Operator = CASE WHEN @MultiplyYN <> 0 THEN '*' ELSE '/' END
	
	IF @DebugBM & 2 > 0
		SELECT
			[@CalledBy] = @CalledBy,
			[@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass,
			[@ETLDatabase] = @ETLDatabase,
			[@CallistoDatabase] = @CallistoDatabase,
			[@StorageTypeBM_DataClass_Currency] = @StorageTypeBM_DataClass_Currency,
			[@DataClassName_Currency] = @DataClassName_Currency,
			[@TableName_DataClass] = @TableName_DataClass,
			[@TableName_DataClass_Currency] = @TableName_DataClass_Currency,
			[@MultiplyYN] = @MultiplyYN,
			[@Operator] = @Operator,
			[@JobID] = @JobID

	SET @Step = 'Get Filter Table'
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

		EXEC pcINTEGRATOR..spGet_FilterTable
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@StepReference = 'BR04',
			@PipeString = @Filter,
			@StorageTypeBM_DataClass = @StorageTypeBM_DataClass,
			@StorageTypeBM = 4,
			@JobID = @JobID,
			@Debug = @DebugSub



		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = 'BR04'

	SET @Step = 'Set @LeafLevelFilter'
		SELECT
			@FromTime = ISNULL(@FromTime, CASE WHEN [ObjectReference] = 'FromTime' THEN [Filter] ELSE NULL END),
			@ToTime = ISNULL(@ToTime, CASE WHEN [ObjectReference] = 'ToTime' THEN [Filter] ELSE NULL END)
		FROM
			#FilterTable
		WHERE
			[StepReference] = 'BR04' AND
			[DimensionID] = -7 AND
			[ObjectReference] IN ('FromTime', 'ToTime')

		IF @FromTime IS NOT NULL SET @LeafLevelFilter = @LeafLevelFilter + CHAR(13) + CHAR(10) + CHAR(9) + 'DC.[Time_MemberId] >= ' + CONVERT(nvarchar(15), @FromTime) + ' AND'
		IF @ToTime IS NOT NULL SET @LeafLevelFilter = @LeafLevelFilter + CHAR(13) + CHAR(10) + CHAR(9) + 'DC.[Time_MemberId] <= ' + CONVERT(nvarchar(15), @ToTime) + ' AND'

		IF @DebugBM & 2 > 0 SELECT [@LeafLevelFilter_1] = @LeafLevelFilter

		SELECT
			@LeafLevelFilter = @LeafLevelFilter + CHAR(13) + CHAR(10) + CHAR(9) + 'DC.[' + [DimensionName] + '_MemberID] ' + [EqualityString] + ' (' + [LeafLevelFilter] + ') AND'
		FROM
			#FilterTable
		WHERE
			[StepReference] = 'BR04' AND
			[LeafLevelFilter] IS NOT NULL AND
			ISNULL([ObjectReference], '') NOT IN ('FromTime', 'ToTime')
		ORDER BY
			DimensionID

		IF LEN(@LeafLevelFilter) > 4 SET @LeafLevelFilter = LEFT(@LeafLevelFilter, LEN(@LeafLevelFilter) - 4)

		IF @DebugBM & 2 > 0 SELECT [@LeafLevelFilter_2] = @LeafLevelFilter

	SET @Step = 'Create temp table #ReportingCurrency'
		IF OBJECT_ID (N'tempdb..#ReportingCurrency', N'U') IS NULL
			BEGIN
				CREATE TABLE #ReportingCurrency (Currency_MemberId bigint, Currency_MemberKey nvarchar(50) COLLATE DATABASE_DEFAULT)
	
				SET @SQLStatement = '
					INSERT INTO #ReportingCurrency
						(
						Currency_MemberId,
						Currency_MemberKey
						)
					SELECT
						Currency_MemberId = [MemberId],
						Currency_MemberKey = [Label]
					FROM
						' + @CallistoDatabase + '..S_DS_Currency C
					WHERE
						C.Reporting <> 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ReportingCurrency', * FROM #ReportingCurrency

		IF (SELECT COUNT(1) FROM #ReportingCurrency) = 0
			BEGIN
				SET @Message = 'There are no selected reporting currencies.'
				SET @Severity = 0
				--IF @CalledBy = 'Callisto'
					--BEGIN
						SET @Duration = GetDate() - @StartTime
						EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = 50000, @ErrorSeverity = @Severity, @ErrorState = 100, @ErrorProcedure = @ProcedureName, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @Message, @Parameter = @Parameter, @LogVersion = @Version, @UserName = @UserName
					--END
				GOTO EXITPOINT
			END

	SET @Step = 'Create and fill temp table #DataClassList.'
		IF @CalledBy <> 'MasterSP'
			BEGIN
				CREATE TABLE #DataClassList
					(
					[DataClassID] int,
					[DimensionID] int,
					[DimensionTypeID] int,
					[ColumnName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[DataType] nvarchar(20) COLLATE DATABASE_DEFAULT,
					[Unit] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[SortOrder] int
					)

				INSERT INTO #DataClassList
					(
					[DataClassID],
					[DimensionID],
					[DimensionTypeID],
					[ColumnName],
					[DataType],
					[Unit],
					[SortOrder]
					)
				SELECT 
					[DataClassID] = DCD.[DataClassID],
					[DimensionID] = DCD.[DimensionID],
					[DimensionTypeID] = D.[DimensionTypeID],
					[ColumnName] = D.DimensionName + '_MemberID',
					[DataType] = 'bigint',
					[Unit] = NULL,
					[SortOrder] = DCD.[SortOrder]
				FROM
					pcINTEGRATOR_Data..DataClass_Dimension DCD 
					INNER JOIN Dimension D ON D.InstanceID IN (@InstanceID, 0) AND D.DimensionID = DCD.DimensionID
				WHERE
					DCD.InstanceID = @InstanceID AND
					DCD.VersionID = @VersionID AND
					DCD.DataClassID = @DataClassID

				UNION
				SELECT 
					[DataClassID] = M.[DataClassID],
					[DimensionID] = 0,
					[DimensionTypeID] = 0,
					[ColumnName] = M.[MeasureName] + '_Value',
					[DataType] = 'float',
					[Unit] = M.[Unit],
					[SortOrder] = 10000 + M.[SortOrder]
				FROM
					pcINTEGRATOR_Data..Measure M 
					INNER JOIN pcINTEGRATOR_Data..DataClass D ON D.InstanceID = M.InstanceID AND D.VersionID = M.VersionID AND D.DataClassID = M.DataClassID AND D.DataClassName = M.MeasureName
				WHERE
					M.InstanceID = @InstanceID AND
					M.VersionID = @VersionID AND
					M.DataClassID = @DataClassID

				IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassList', * FROM #DataClassList ORDER BY DataClassID, SortOrder
			END

	SET @Step = 'Get @TimeTypeID'
		IF @CalledBy <> 'MasterSP'
			SELECT
				@TimeTypeID = MAX(DimensionID)
			FROM
				#DataClassList
			WHERE
				DimensionID IN (-7, -49)
		ELSE
			SET @TimeTypeID = -7

		IF @TimeTypeID IS NULL
			BEGIN
				SET @Message = 'Selected DataClass (' + @DataClassName + ') does not have any valid Time dimension.'
				SET @Severity = 16
				--IF @CalledBy = 'Callisto'
					--BEGIN
						SET @Duration = GetDate() - @StartTime
						EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = 50000, @ErrorSeverity = @Severity, @ErrorState = 100, @ErrorProcedure = @ProcedureName, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @Message, @Parameter = @Parameter, @LogVersion = @Version, @UserName = @UserName
					--END
				GOTO EXITPOINT
			END

		IF @DebugBM & 2 > 0 SELECT [@TimeTypeID] = @TimeTypeID

	SET @Step = 'Create and fill temp table #Selection'
		IF OBJECT_ID(N'TempDB.dbo.#Selection', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0
				CREATE TABLE #Selection
					(
					[Scenario_MemberId] bigint,
					[Time_MemberId] bigint
					)

				SET @SQLStatement = '
					INSERT INTO #Selection
						(
						[Scenario_MemberId],
						[Time_MemberId]
						)
					SELECT DISTINCT
						[Scenario_MemberId] = DC.[Scenario_MemberId],
						[Time_MemberId] = ' + CASE @TimeTypeID WHEN -7 THEN 'DC.[Time_MemberId]' WHEN -49 THEN 'DC.[TimeDay_MemberId] / 100' END + '
					FROM
						' + @TableName_DataClass + ' DC
					' + CASE WHEN LEN(@LeafLevelFilter) > 0 THEN 'WHERE ' + @LeafLevelFilter ELSE '' END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END
			
		IF @DebugBM & 2 > 0 SELECT TempTable = '#Selection', * FROM #Selection
		IF @DebugBM & 2 > 0 SELECT [@JobID] = @JobID

		IF (SELECT COUNT(1) FROM #Selection) = 0
			BEGIN
				SET @Message = 'There are no valid rows for selected Scenario and Time frame.'
				SET @Severity = 0
				--IF @CalledBy = 'Callisto'
					--BEGIN
						SET @Duration = GetDate() - @StartTime
						EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = 0, @ErrorSeverity = @Severity, @ErrorState = 100, @ErrorProcedure = @ProcedureName, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @Message, @Parameter = @Parameter, @LogVersion = @Version, @UserName = @UserName
					--END
				GOTO EXITPOINT
			END

	SET @Step = 'Create and fill temp table #FxRate'
		IF OBJECT_ID(N'TempDB.dbo.#FxRate', N'U') IS NULL
			BEGIN
				CREATE TABLE #FxRate
					(
					[BaseCurrency_MemberId] bigint,
					[Currency_MemberId] bigint, 
					[Entity_MemberId] bigint,
					[Rate_MemberId] bigint, 
					[Scenario_MemberId] bigint, 
					[Time_MemberId] bigint,
					[FxRate] float
					)
			END

		IF @StorageTypeBM_DataClass_Currency & 2 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT
						@BaseCurrencyYN = CASE WHEN BC.[name] = ''BaseCurrency_MemberId'' THEN 1 ELSE 0 END,
						@BusinessRuleYN = CASE WHEN BR.[name] = ''BusinessRule_MemberId'' THEN 1 ELSE 0 END,
						@SimulationYN = CASE WHEN S.[name] = ''Simulation_MemberId'' THEN 1 ELSE 0 END
					FROM
						' + @ETLDatabase + '.sys.tables T
						LEFT JOIN ' + @ETLDatabase + '.sys.columns BC on BC.object_id = T.object_id AND BC.[name] = ''BaseCurrency_MemberId''
						LEFT JOIN ' + @ETLDatabase + '.sys.columns BR on BR.object_id = T.object_id AND BR.[name] = ''BusinessRule_MemberId''
						LEFT JOIN ' + @ETLDatabase + '.sys.columns S on S.object_id = T.object_id AND S.[name] = ''Simulation_MemberId''
					WHERE
						T.[name] = ''pcDC_' + @DataClassName_Currency + ''''
			END
		ELSE IF @StorageTypeBM_DataClass_Currency & 4 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT
						@BaseCurrencyYN = CASE WHEN BC.[name] = ''BaseCurrency_MemberId'' THEN 1 ELSE 0 END,
						@BusinessRuleYN = CASE WHEN BR.[name] = ''BusinessRule_MemberId'' THEN 1 ELSE 0 END,
						@SimulationYN = CASE WHEN S.[name] = ''Simulation_MemberId'' THEN 1 ELSE 0 END
					FROM
						' + @CallistoDatabase + '.sys.tables T
						LEFT JOIN ' + @CallistoDatabase + '.sys.columns BC on BC.object_id = T.object_id AND BC.[name] = ''BaseCurrency_MemberId''
						LEFT JOIN ' + @CallistoDatabase + '.sys.columns BR on BR.object_id = T.object_id AND BR.[name] = ''BusinessRule_MemberId''
						LEFT JOIN ' + @CallistoDatabase + '.sys.columns S on S.object_id = T.object_id AND S.[name] = ''Simulation_MemberId''
					WHERE
						T.[name] = ''FACT_' + @DataClassName_Currency + '_default_partition'''
			END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@BaseCurrencyYN bit OUT, @BusinessRuleYN bit OUT, @SimulationYN bit OUT', @BaseCurrencyYN = @BaseCurrencyYN OUT, @BusinessRuleYN = @BusinessRuleYN OUT, @SimulationYN = @SimulationYN OUT

		IF @DebugBM & 2 > 0 SELECT [@BaseCurrencyYN] = @BaseCurrencyYN, [@BusinessRuleYN] = @BusinessRuleYN, [@SimulationYN] = @SimulationYN

		SET @SQLStatement = '
			INSERT INTO #FxRate
				(
				[BaseCurrency_MemberId],
				[Currency_MemberId], 
				[Entity_MemberId],
				[Rate_MemberId], 
				[Scenario_MemberId], 
				[Time_MemberId],
				[FxRate]
				)
			SELECT DISTINCT
				[BaseCurrency_MemberId] = ' + CASE WHEN @BaseCurrencyYN <> 0 THEN 'DCC.[BaseCurrency_MemberId]' ELSE 'NULL' END + ',
				DCC.[Currency_MemberId], 
				DCC.[Entity_MemberId],
				DCC.[Rate_MemberId], 
				DCC.[Scenario_MemberId], 
				DCC.[Time_MemberId],
				[FxRate] = DCC.FxRate_Value
			FROM
				' + @TableName_DataClass_Currency + ' DCC
				INNER JOIN #Selection S ON S.[Scenario_MemberId] = DCC.[Scenario_MemberId] AND S.[Time_MemberId] = DCC.[Time_MemberId]
			WHERE
				DCC.FxRate_Value <> 0 AND
				' + CASE WHEN @BaseCurrency IS NULL OR @BaseCurrencyYN = 0 THEN '' ELSE 'DCC.BaseCurrency_MemberId = ' + CONVERT(nvarchar(15), @BaseCurrency) + ' AND' END + '
				DCC.[Entity_MemberId] IN (-1)
				' + CASE WHEN @BusinessRuleYN = 0 THEN '' ELSE ' AND DCC.[BusinessRule_MemberId] IN (-1)' END + '
				' + CASE WHEN @BusinessRuleYN = 0 THEN '' ELSE ' AND DCC.[Simulation_MemberId] IN (-1)' END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @BaseCurrency IS NULL
			BEGIN
				SELECT @BaseCurrency = MAX(BaseCurrency_MemberID) FROM #FxRate
				DELETE #FxRate WHERE BaseCurrency_MemberID <> @BaseCurrency
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FxRate', * FROM #FxRate

		IF @CalledBy = 'MasterSP' GOTO MasterSP

	SET @Step = 'Create temp table #FxTrans'
		CREATE TABLE #FxTrans
			(
			[Dummy] int
			)

	SET @Step = 'Run cursor for adding columns to temp table FxTrans'
		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT 
				[ColumnName],
				[DataType]
			FROM
				#DataClassList
			WHERE
				[DataClassID] = @DataClassID AND
				[DimensionTypeID] NOT IN (27, 50)
			ORDER BY
				[SortOrder]

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @ColumnName, @DataType

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						ALTER TABLE #FxTrans ADD [' + @ColumnName + '] ' + @DataType

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					FETCH NEXT FROM AddColumn_Cursor INTO  @ColumnName, @DataType
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

	SET @Step = 'Fill temp table #FxTrans'
		SELECT
			@SQLStatement_Insert = @SQLStatement_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '],',
			@SQLStatement_Select = @SQLStatement_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '] = ' + CASE DimensionID WHEN -55 THEN CONVERT(nvarchar(15), @BusinessRule_Conversion_MemberId) WHEN -3 THEN 'FxD.[' + ColumnName + ']' WHEN 0 THEN CASE WHEN [Unit] = 'Currency' THEN 'DC.[' + ColumnName + '] ' + @Operator + ' (FxD.[FxRate] / FxS.[FxRate])' ELSE 'DC.[' + ColumnName + ']' END ELSE 'DC.[' + ColumnName + ']' END + ',',
			@SQLStatement_NotExists = @SQLStatement_NotExists + CASE WHEN DimensionID IN (-55, -63) THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.[' + ColumnName + '] = Fx.[' + ColumnName + '] AND' END
		FROM
			#DataClassList
		WHERE
			[DimensionTypeID] NOT IN (27, 50)
		ORDER BY
			[SortOrder]

		IF LEN(@SQLStatement_Insert) > 1 SET @SQLStatement_Insert = LEFT(@SQLStatement_Insert, LEN(@SQLStatement_Insert) - 1)
		IF LEN(@SQLStatement_Select) > 1 SET @SQLStatement_Select = LEFT(@SQLStatement_Select, LEN(@SQLStatement_Select) - 1)
		IF LEN(@SQLStatement_NotExists) > 1 SET @SQLStatement_NotExists = LEFT(@SQLStatement_NotExists, LEN(@SQLStatement_NotExists) - 4)

		IF @DebugBM & 2 > 0 SELECT [@LeafLevelFilter] = @LeafLevelFilter

		IF @DebugBM & 8 > 0
			BEGIN
				SET @SQLStatement = 'SELECT TempTable = ''' + @TableName_DataClass + ''', * FROM ' +  @TableName_DataClass
				EXEC (@SQLStatement)
			END

		SET @SQLStatement = '
			INSERT INTO #FxTrans
				(' + @SQLStatement_Insert + '
				)'

		SET @SQLStatement = @SQLStatement + '
			SELECT' + @SQLStatement_Select

		SET @SQLStatement = @SQLStatement + '
			FROM
				' + @TableName_DataClass + ' DC
				INNER JOIN ' + @CallistoDatabase + '.[dbo].S_DS_Account [Account] ON [Account].[MemberId] = DC.[Account_MemberId]
				INNER JOIN #ReportingCurrency C ON 1 = 1
				INNER JOIN #FxRate FxD ON 
					FxD.[Currency_MemberId] = C.[Currency_MemberId] AND 
					FxD.[Rate_MemberId] = [Account].[Rate_MemberId] AND 
					FxD.[Scenario_MemberId] = DC.[Scenario_MemberId] AND 
					FxD.[Time_MemberId] = ' + CASE @TimeTypeID WHEN -7 THEN 'DC.[Time_MemberId]' WHEN -49 THEN 'DC.[TimeDay_MemberId] / 100' END + '
				INNER JOIN #FxRate FxS ON
					FxS.[Currency_MemberId] = DC.[Currency_MemberId] AND
					FxS.[Rate_MemberId] = FxD.[Rate_MemberId] AND
					FxS.[Scenario_MemberId] = FxD.[Scenario_MemberId] AND
					FxS.[Time_MemberId] = FxD.[Time_MemberId]
			WHERE
				' + CASE WHEN LEN(@LeafLevelFilter) > 0 THEN @LeafLevelFilter + ' AND' ELSE '' END + '
				DC.[BusinessRule_MemberId] IN (-1)'

		IF @DebugBM & 2 > 0 
			BEGIN
				IF LEN(@SQLStatement) > 4000
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; INSERT INTO #FxTrans'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'INSERT INTO #FxTrans', 
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement
			END

		EXEC (@SQLStatement)
		SET @Selected = @Selected + @@ROWCOUNT

		IF @DebugBM & 8 > 0 
			BEGIN
				SET @SQLStatement = 'SELECT TempTable = ''#FxTrans'', * FROM #FxTrans WHERE [' + @DataClassName + '_Value] <> 0'
				PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Delete rows from FACT table'
		IF @DebugBM & 2 > 0
			SELECT
				[@BusinessRule_Conversion_MemberId] = @BusinessRule_Conversion_MemberId,
				[@TableName_DataClass] = @TableName_DataClass,
				[@SQLStatement_Insert] = @SQLStatement_Insert

		SET @SQLStatement = '
			DELETE DC
			FROM
				' + @TableName_DataClass + ' DC
			WHERE
				' + CASE WHEN LEN(@LeafLevelFilter) > 0 THEN @LeafLevelFilter + ' AND' ELSE '' END + '
				DC.[BusinessRule_MemberId] IN (' + CONVERT(nvarchar(15), @BusinessRule_Conversion_MemberId) + ')'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Insert rows into FACT table'
		IF @DebugBM & 2 > 0 SELECT [@TempTable] = @TempTable, [@TableName_DataClass] = @TableName_DataClass
		IF @TempTable IS NOT NULL
			SET @SQLStatement = '
			INSERT INTO ' + @TableName_DataClass + '
				(' + @SQLStatement_Insert + ')
			SELECT' + @SQLStatement_Insert + '
			FROM
				#FxTrans Fx
			WHERE
				[' + @DataClassName + '_Value] <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @TableName_DataClass + ' DC WHERE' + @SQLStatement_NotExists + ')'
		ELSE --Callisto
			SET @SQLStatement = '
			INSERT INTO ' + @TableName_DataClass + '
				(' + @SQLStatement_Insert + ',
				[ChangeDatetime],
				[Userid]
				)
			SELECT' + @SQLStatement_Insert + ',
				[ChangeDatetime] = GetDate(),
				[Userid] = ''' + @UserName + '''
			FROM
				#FxTrans Fx
			WHERE
				[' + @DataClassName + '_Value] <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @TableName_DataClass + ' DC WHERE' + @SQLStatement_NotExists + ')'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Refresh Callisto model'
		IF @CalledBy = 'pcPortal' AND @StorageTypeBM_DataClass & 4 > 0 AND @CallistoRefreshYN <> 0
			BEGIN
				EXEC [spRun_Job_Callisto_Generic]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@JobName = 'Callisto_Generic',
					@StepName = 'Refresh', --Load, Deploy, Refresh, Import, DeployRole
					@ModelName = @DataClassName, --Mandatory for Refresh
					@AsynchronousYN = @CallistoRefreshAsynchronousYN,
					@JobID = @JobID
			END

	SET @Step = 'Jump to MasterSP:'
		MasterSP:

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0
			BEGIN
--				DROP TABLE #Selection
				DROP TABLE #FilterTable
			END

		IF @CalledBy <> 'MasterSP' 
			BEGIN
				DROP TABLE #FxTrans
				DROP TABLE #FxRate
			END

		IF @CalledBy NOT IN ('ETL', 'MasterSP') DROP TABLE #ReportingCurrency

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Set Duration'
		IF @CalledBy = 'pcPortal' AND @BusinessRuleID IS NOT NULL
			BEGIN
				UPDATE BR04M
				SET
					[Duration] = @Duration
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR04_Master] BR04M
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					BusinessRuleID = @BusinessRuleID
			END

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
