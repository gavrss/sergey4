SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Financials]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBM int = 3, --1 = P&L transactions, 2 = Balance Sheet transactions, 4 = Not differentiated by TimeBalance
	@FieldTypeBM int = 1, --1 = Book currency, 2 = Transaction Currency, 4 = Consolidation, 8 = PostedInfo, 16 = InsertedInfo
	@ConsolidationGroupYN bit = 0,

	@Entity NVARCHAR(50) = NULL, 
	@Book NVARCHAR(50) = NULL,
	@Scenario nvarchar(100) = NULL,

	@ConsolidationGroup nvarchar(50) = NULL, --Optional
	@FiscalYear int = NULL,

	@SpeedRunYN bit = 0,
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000633,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_Financials',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

	CLOSE JournalData_Cursor
	DEALLOCATE JournalData_Cursor	

EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=476, @VersionID=1024, @FiscalYear = 2019, @DebugBM = 4 --Allied
EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=476, @VersionID=1024, @SequenceBM = 0, @ConsolidationGroupYN = 1, @FiscalYear = 2019, @ConsolidationGroup = 'G_ASRV', @Entity='SAN', @Book='Main', @DebugBM = 4 --Allied
EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=476, @VersionID=1024, @SequenceBM = 0, @ConsolidationGroupYN = 1, @Entity='SAN', @Book='Main', @DebugBM = 4 --Allied

EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=424, @VersionID=1017, @Debug=1 --Heartland
EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=413, @VersionID=1008, @Debug=1 --CBN

EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=413, @VersionID=1008, @Entity='52982', @Book='CBN_Main', @FiscalYear = 2020, @SequenceBM = 2, @Debug=1 --CBN
EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=413, @VersionID=1008, @Entity='52982', @Book='CBN_Main', @FiscalYear = 2019, @SequenceBM = 2, @Debug=1 --CBN

EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=413, @VersionID=1008, @Entity='52982', @SequenceBM = 2, @Debug=1 --CBN
EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=454, @VersionID=1021, @Debug=1 --CCM

EXEC [spIU_DC_Financials] @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @Scenario='ACTUAL', @SequenceBM=4, @FieldTypeBM=2, @Debug=1 --Interfor

EXEC [spIU_DC_Financials] @GetVersion = 1 
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataClassID int,
	@DataClassName nvarchar(100),
	@StorageTypeBM int, --1 = Internal, 2 = Table, 4 = Callisto
	@SQLStatement nvarchar(MAX),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@BusinessProcess_FieldName nvarchar(50),
	@Entity_FieldName nvarchar(50),
	@Scenario_FieldName nvarchar(50),
	@Time_FieldName nvarchar(50),
	@ApplicationID int,
	@JournalTable nvarchar(100),
	@JSON nvarchar(MAX),
	@TempTable_ObjectID int,
	@DimensionName nvarchar(50), 
	@MemberId nvarchar(20),
	@Filter nvarchar(max),
	@MultiplyYN bit,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Load Financials FACT table from Journal',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data]. Implemented [spGet_JournalTable].'
		IF @Version = '2.0.2.2146' SET @Description = 'Added parameter @Scenario, defaulted to ACTUAL. DB-92: Added parameter @TempTable_ObjectID to distinguish different temp tables in a multi tenant environment. DB-102 Handle extra books'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-129: Scenarios <> ACTUAL not correct handled. If not set, read all existing in Journal.'
		IF @Version = '2.0.2.2149' SET @Description = 'Added deallocation of JournalData_Cursor if already exists.'
		IF @Version = '2.0.3.2151' SET @Description = 'Enhanced debugging. Handle ConsolidationGroup.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-330: Handle #Journal_Update.'
		IF @Version = '2.0.3.2153' SET @Description = '@FieldTypeBM passed to [spIU_DC_Financials_Raw].'
		IF @Version = '2.0.3.2154' SET @Description = 'Use spBR_BR04 for currency conversion.'
		IF @Version = '2.1.0.2156' SET @Description = 'Based on JobID.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())
		IF @Debug <> 0 SELECT [@StartTime] = @StartTime

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
			@DataClassID = MAX(DataClassID),
			@DataClassName = MAX(DataClassName),
			@StorageTypeBM = MAX(StorageTypeBM)
		FROM
			DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			ModelBM & 64 > 0 AND
			SelectYN <> 0 AND
			DeletedID IS NULL

		SELECT
			@MultiplyYN = MultiplyYN
		FROM
			[Instance]
		WHERE
			[InstanceID] = @InstanceID

		SELECT
			@ApplicationID = ISNULL(@ApplicationID, MAX(ApplicationID))
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID AND
			A.SelectYN <> 0

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		IF @Debug <> 0 SELECT JournalTable = @JournalTable

	SET @Step = 'Create temp table'
		IF @StorageTypeBM & 1 > 0
			BEGIN
				SET @Message = 'StorageTypeBM 1, Internal model is not yet implemented'
				SET @Severity = 16
				GOTO EXITPOINT
			END

		IF @StorageTypeBM & 2 > 0
			BEGIN
				SET @Message = 'StorageTypeBM 2, Specific table is not yet implemented'
				SET @Severity = 16
				GOTO EXITPOINT
			END

		IF @StorageTypeBM & 4 > 0
			BEGIN
				CREATE TABLE #DataClassColumns
					(
					DimensionID int,
					DimensionTypeID int,
					ColumnName nvarchar(100) COLLATE DATABASE_DEFAULT,
					DataType nvarchar(50) COLLATE DATABASE_DEFAULT,
					SortOrder int
					)

				INSERT INTO #DataClassColumns
					(
					DimensionID,
					DimensionTypeID,
					ColumnName,
					DataType,
					SortOrder
					)
				SELECT 
					DimensionID = DCD.DimensionID,
					DimensionTypeID = D.DimensionTypeID,
					ColumnName = CONVERT(nvarchar(100), D.DimensionName + '_MemberId') COLLATE DATABASE_DEFAULT,
					DataType = CONVERT(nvarchar(50), 'bigint'),
					SortOrder = DCD.SortOrder
				FROM
					DataClass_Dimension DCD
					INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.SelectYN <> 0 AND D.DeletedID IS NULL
				WHERE
					DataClassID = @DataClassID 
				ORDER BY
					DCD.SortOrder

				IF @Debug <> 0 SELECT TempTable = '#DataClassColumns', * FROM #DataClassColumns ORDER BY SortOrder

				IF (SELECT COUNT(1) FROM #DataClassColumns) = 0
					BEGIN
						SET @Message = 'No dimensions specified for selected DataClassID'
						SET @Severity = 0
						GOTO EXITPOINT
					END

				SELECT
					@BusinessProcess_FieldName = MAX(CASE WHEN DimensionTypeID = 2 THEN ColumnName ELSE '' END),
					@Entity_FieldName = MAX(CASE WHEN DimensionTypeID = 4 THEN ColumnName ELSE '' END),
					@Scenario_FieldName = MAX(CASE WHEN DimensionTypeID = 6 THEN ColumnName ELSE '' END),
					@Time_FieldName = MAX(CASE WHEN DimensionTypeID = 7 THEN ColumnName ELSE '' END)
				FROM
					#DataClassColumns
				WHERE
					DimensionTypeID IN (2, 4, 6, 7)

				IF @DebugBM & 2 > 0
					SELECT
						[@BusinessProcess_FieldName] = @BusinessProcess_FieldName,
						[@Entity_FieldName] = @Entity_FieldName,
						[@Scenario_FieldName] = @Scenario_FieldName,
						[@Time_FieldName] = @Time_FieldName

				CREATE TABLE #Journal_DataClass_Financials
					(DataClassID int)

				SELECT @TempTable_ObjectID = OBJECT_ID (N'tempdb..#Journal_DataClass_Financials', N'U')

				SET @SQLStatement = 'ALTER TABLE #Journal_DataClass_Financials' + CHAR(13) + CHAR(10) + 'ADD'

				SELECT 
					@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + ColumnName + ' ' + DataType + ','
				FROM
					#DataClassColumns
				ORDER BY
					SortOrder

				SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + @DataClassName + '_Value float' 

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				IF @DebugBM & 2 > 0 SELECT TempTable = '#Journal_DataClass_Financials', * FROM #Journal_DataClass_Financials
			END

	SET @Step = 'Create temp table #JournalData_Cursor'
		CREATE TABLE #JournalData_Cursor 
		(
		Entity nvarchar(50) COLLATE DATABASE_DEFAULT,
		Book nvarchar(50) COLLATE DATABASE_DEFAULT,
		FiscalYear int,
		Scenario nvarchar(50) COLLATE DATABASE_DEFAULT
		)

	SET @Step = 'Fill temp table #JournalData_Cursor'
		IF @Entity IS NOT NULL OR @Book IS NOT NULL OR @Scenario IS NOT NULL OR @FiscalYear IS NOT NULL
			INSERT INTO #JournalData_Cursor 
				(
				Entity,
				Book,
				FiscalYear,
				Scenario
				)
			SELECT DISTINCT
				Entity = @Entity,
				Book = @Book,
				FiscalYear = @FiscalYear,
				Scenario = @Scenario
		ELSE
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #JournalData_Cursor 
						(
						Entity,
						Book,
						FiscalYear,
						Scenario
						)
					SELECT DISTINCT
						J.Entity,
						J.Book,
						J.FiscalYear,
						J.Scenario
					FROM
						' + @JournalTable + ' J
					WHERE
						J.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
						J.JobID = ' + CONVERT(nvarchar(10), @JobID)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	--SET @Step = 'Fill #CursorTable'
	--	IF OBJECT_ID(N'TempDB.dbo.#Journal_Update', N'U') IS NOT NULL
	--		BEGIN
	--			INSERT INTO #CursorTable
	--				(
	--				Entity_MemberKey,
	--				Book,
	--				FiscalYear,
	--				Scenario
	--				)
	--			SELECT DISTINCT
	--				Entity_MemberKey = Entity,
	--				Book = Book,
	--				FiscalYear = FiscalYear,
	--				Scenario = 'ACTUAL'
	--			FROM
	--				#Journal_Update
	--		END
	--	ELSE
	--		BEGIN
	--			SET @SQLStatement = '
	--				INSERT INTO #JournalData_Cursor 
	--					(
	--					Entity,
	--					Book,
	--					FiscalYear,
	--					Scenario
	--					)
	--				SELECT DISTINCT
	--					J.Entity,
	--					J.Book,
	--					J.FiscalYear,
	--					J.Scenario
	--				FROM
	--					' + @JournalTable + ' J
	--					INNER JOIN Entity E ON E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.MemberKey = J.Entity AND E.SelectYN <> 0 AND E.DeletedID IS NULL
	--					INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.Book = J.Book AND EB.SelectYN <> 0
	--				WHERE
	--					J.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + '
	--					' + CASE WHEN @Entity IS NULL THEN '' ELSE ' AND J.Entity = ''' + @Entity + '''' END + '
	--					' + CASE WHEN @Book IS NULL THEN '' ELSE ' AND J.Book = ''' + @Book + '''' END + '
	--					' + CASE WHEN @FiscalYear IS NULL THEN '' ELSE ' AND J.FiscalYear =''' + CONVERT(nvarchar(10), @FiscalYear) + '''' END + '
	--					' + CASE WHEN @Scenario IS NULL THEN '' ELSE ' AND J.Scenario = ''' + @Scenario + '''' END 							
	--				/* 
	--				WHERE
	--					InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + '
	--					' + CASE WHEN @JobID IS NULL THEN '' ELSE ' AND JobID = ''' + CONVERT(nvarchar(10), @JobID) + '''' END + '
	--					' + CASE WHEN @Entity IS NULL THEN '' ELSE ' AND Entity = ''' + @Entity + '''' END + '
	--					' + CASE WHEN @Book IS NULL THEN '' ELSE ' AND Book = ''' + @Book + '''' END + '
	--					' + CASE WHEN @FiscalYear IS NULL THEN '' ELSE ' AND FiscalYear =''' + CONVERT(nvarchar(10), @FiscalYear) + '''' END 
	--				*/

		IF @DebugBM & 2 > 0 
			BEGIN
				SELECT [@JournalTable] = @JournalTable, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@JobID] = @JobID, [@Entity] = @Entity, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@SQLStatement] = @SQLStatement
				SELECT [@SequenceBM] = @SequenceBM, [@Scenario] = @Scenario, [@TempTable_ObjectID] = @TempTable_ObjectID
				SELECT TempTable = '#JournalData_Cursor', * FROM  #JournalData_Cursor 
			END
	
	SET @Step = 'Handle Consolidation Group'
		IF @ConsolidationGroup IS NOT NULL
			DELETE JDC
			FROM
				#JournalData_Cursor JDC
				INNER JOIN pcINTEGRATOR_Data..Entity E ON E.InstanceID = @InstanceID AND E.VersionID = @VersionID AND E.MemberKey = JDC.Entity
			WHERE
				NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..EntityHierarchy EH INNER JOIN Entity GE ON GE.EntityID = EH.EntityGroupID AND GE.MemberKey = @ConsolidationGroup AND EH.EntityID = E.EntityID)

		IF @Debug <> 0 SELECT TempTable = '#JournalData_Cursor', * FROM #JournalData_Cursor ORDER BY Entity, Book, FiscalYear

	SET @Step = 'Exec JournalData_Cursor'		
		IF CURSOR_STATUS('global','JournalData_Cursor') >= -1 DEALLOCATE JournalData_Cursor
		DECLARE JournalData_Cursor CURSOR FOR

			SELECT
				Entity,
				Book,
				FiscalYear,
				Scenario
			FROM
				#JournalData_Cursor
			ORDER BY
				Entity,
				Book,
				FiscalYear,
				Scenario

			OPEN JournalData_Cursor
			FETCH NEXT FROM JournalData_Cursor INTO @Entity, @Book, @FiscalYear, @Scenario

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 1 > 0 
						SELECT
							[@UserID] = @UserID,
							[@InstanceID] = @InstanceID,
							[@VersionID] = @VersionID,
							[@SequenceBM] = @SequenceBM,
							[@FieldTypeBM] = @FieldTypeBM,
							[@ConsolidationGroupYN] = @ConsolidationGroupYN,
							[@Entity] = @Entity,
							[@Book] = @Book,
							[@FiscalYear] = @FiscalYear,
							[@Scenario] = @Scenario,
							[@StartTime] = @StartTime,
							[@JournalTable] = @JournalTable,
							[@TempTable_ObjectID] = @TempTable_ObjectID,
							[@JobID] = @JobID,
							[@DebugSub] = @DebugSub

					SET @JSON = '
						[
						{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
						{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
						{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
						{"TKey" : "SequenceBM",  "TValue": "' + CONVERT(nvarchar(15), @SequenceBM) + '"},
						{"TKey" : "FieldTypeBM",  "TValue": "' + CONVERT(nvarchar(15), @FieldTypeBM) + '"},
						{"TKey" : "ConsolidationGroupYN",  "TValue": "' + CONVERT(nvarchar(15), CONVERT(int, @ConsolidationGroupYN)) + '"},
						{"TKey" : "Entity",  "TValue": "' + @Entity + '"},
						{"TKey" : "Book",  "TValue": "' + @Book + '"},
						{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(nvarchar(15), @FiscalYear) + '"},
						{"TKey" : "Scenario",  "TValue": "' + @Scenario + '"},
						{"TKey" : "MasterStartTime",  "TValue": "' + CONVERT(nvarchar(50), @StartTime, 121) + '"},
						{"TKey" : "JournalTable",  "TValue": "' + @JournalTable + '"},
						{"TKey" : "TempTable_ObjectID",  "TValue": "' + CONVERT(nvarchar(15), @TempTable_ObjectID) + '"},
						{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
						{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}
						]'
					
					IF @DebugBM & 2 > 0 PRINT @JSON

					EXEC spRun_Procedure_KeyValuePair
						@ProcedureName = 'spIU_DC_Financials_Raw',
						@JSON = @JSON

					IF @Debug <> 0 SELECT TempTable = '#Journal_DataClass_Financials', * FROM #Journal_DataClass_Financials ORDER BY Account_MemberId, Time_MemberId

					FETCH NEXT FROM JournalData_Cursor INTO @Entity, @Book, @FiscalYear, @Scenario
				END

		CLOSE JournalData_Cursor
		DEALLOCATE JournalData_Cursor		

		IF @Debug <> 0 SELECT TempTable = '#Journal_DataClass_Financials', * FROM #Journal_DataClass_Financials ORDER BY Account_MemberId, Time_MemberId

	SET @Step = 'Create #FACT_Update'
		CREATE TABLE #FACT_Update
			(
			[BusinessProcess_MemberId] bigint,
			[Entity_MemberId] bigint,
			[Scenario_MemberId] bigint,
			[Time_MemberId] bigint
			)

		SET @SQLStatement = '
			INSERT INTO #FACT_Update
				(
				[BusinessProcess_MemberId],
				[Entity_MemberId],
				[Scenario_MemberId],
				[Time_MemberId]
				)
			SELECT DISTINCT
				[BusinessProcess_MemberId] = ' + @BusinessProcess_FieldName + ',
				[Entity_MemberId] = ' + @Entity_FieldName + ',
				[Scenario_MemberId] = ' + @Scenario_FieldName + ',
				[Time_MemberId] = ' + @Time_FieldName + '
			FROM
				#Journal_DataClass_Financials'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#FACT_Update', * FROM #FACT_Update

	SET @Step = 'Set all existing rows that should be inserted to 0'
		SET @SQLStatement = '
			UPDATE
				F
			SET
				[' + @DataClassName + '_Value] = 0
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] F
				INNER JOIN [#FACT_Update] V ON
					V.[BusinessProcess_MemberId] = F.' + @BusinessProcess_FieldName + ' AND
					V.[Entity_MemberId] = F.' + @Entity_FieldName + ' AND
					V.[Scenario_MemberId] = F.' + @Scenario_FieldName + ' AND
					V.[Time_MemberId] = F.' + @Time_FieldName

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert new rows'
		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition]
				('

		SELECT 
			@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ColumnName + ','
		FROM
			#DataClassColumns
		ORDER BY
			SortOrder

		SET @SQLStatement = @SQLStatement + '
				[ChangeDatetime],
				[Userid],
				[' + @DataClassName + '_Value]
				)
			SELECT'

		SELECT 
			@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ColumnName + ','
		FROM
			#DataClassColumns
		ORDER BY
			SortOrder

		SET @SQLStatement = @SQLStatement + '
				[ChangeDatetime] = GetDate(),
				[Userid] = ''' + @UserName + ''',
				[' + @DataClassName + '_Value]
			FROM
				#Journal_DataClass_Financials'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Create temp table #ReportingCurrency'	
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

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ReportingCurrency', * FROM #ReportingCurrency

		IF (SELECT COUNT(1) FROM #ReportingCurrency) = 0
			GOTO NoReportingCurrency

	SET @Step = 'Set @Filter for FxTrans conversion'
		CREATE TABLE #Parameter ([DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT, [MemberID] bigint)

		INSERT INTO #Parameter
			(
			[DimensionName],
			[MemberID]
			)
		SELECT
			[DimensionName] = sub.[DimensionName],
			[MemberID]
		FROM
			(
			SELECT DISTINCT
				[DimensionName] = 'BusinessProcess',
				[MemberID] = [BusinessProcess_MemberId]
			FROM
				#FACT_Update
			UNION SELECT DISTINCT
				[DimensionName] = 'Entity',
				[MemberID] = [Entity_MemberId]
			FROM
				#FACT_Update
			UNION SELECT DISTINCT
				[DimensionName] = 'Scenario',
				[MemberID] = [Scenario_MemberId]
			FROM
				#FACT_Update
			UNION SELECT DISTINCT
				[DimensionName] = 'Time',
				[MemberID] = [Time_MemberId]
			FROM
				#FACT_Update
			) sub

		IF CURSOR_STATUS('global','Filter_Cursor') >= -1 DEALLOCATE Filter_Cursor
		DECLARE Filter_Cursor CURSOR FOR
			SELECT DISTINCT
				[DimensionName]
			FROM
				#Parameter
			ORDER BY
				[DimensionName]
				
			OPEN Filter_Cursor
			FETCH NEXT FROM Filter_Cursor INTO @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName

					SET @Filter = @Filter + '|' + @DimensionName + '='

					IF CURSOR_STATUS('global','Parameter_Cursor') >= -1 DEALLOCATE Parameter_Cursor
					DECLARE Parameter_Cursor CURSOR FOR
						SELECT DISTINCT
							[MemberId]
						FROM
							#Parameter 
						WHERE
							DimensionName = @DimensionName
						ORDER BY
							[MemberId]

						OPEN Parameter_Cursor
						FETCH NEXT FROM Parameter_Cursor INTO @MemberId

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@MemberId] = @MemberId

								SET @Filter = @Filter + @MemberId + ','
								
								FETCH NEXT FROM Parameter_Cursor INTO @MemberId
							END

					CLOSE Parameter_Cursor
					DEALLOCATE Parameter_Cursor

					SET @Filter = LEFT(@Filter, LEN(@Filter) -1)

					FETCH NEXT FROM Filter_Cursor INTO @DimensionName
				END

		CLOSE Filter_Cursor
		DEALLOCATE Filter_Cursor

		IF @DebugBM & 1 > 0 SELECT [@Filter] = @Filter

	SET @Step = 'Run FxTrans'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DataClassID",  "TValue": "' + CONVERT(nvarchar(15), @DataClassID) + '"},
			{"TKey" : "MultiplyYN",  "TValue": "' + CONVERT(nvarchar(10), CONVERT(int, @MultiplyYN)) + '"},
			{"TKey" : "CalledBy",  "TValue": "ETL"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}' +
			+ CASE WHEN LEN(@Filter) = 0 THEN '' ELSE ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "Filter",  "TValue": "' + @Filter + '"}' END +
			']'

		IF @DebugBM & 2 > 0 PRINT @JSON
		EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spBR_BR04', @JSON = @JSON

--		EXEC [spBR_BR04] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID = @DataClassID, @Filter = @Filter, @MultiplyYN = @MultiplyYN, @CalledBy = 'ETL', @DebugBM = @DebugSub

		NoReportingCurrency:

	SET @Step = 'Clean up'
		IF (SELECT DATEPART(WEEKDAY, GETDATE())) IN (6, 7) OR @SpeedRunYN = 0 --Saturday, Sunday or not SpeedRun
			BEGIN
				SET @SQLStatement = '
					DELETE
						F
					FROM
						' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] F
					WHERE
						[' + @DataClassName + '_Value] = 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Deleted = @Deleted + @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Journal_DataClass_Financials
		DROP TABLE #FACT_Update
		DROP TABLE #JournalData_Cursor
		DROP TABLE #ReportingCurrency

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
