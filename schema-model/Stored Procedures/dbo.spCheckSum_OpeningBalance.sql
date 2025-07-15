SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_OpeningBalance] 
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	--@SequenceBM int = 7,	--1 - GLPeriodBal VS GLJrnDtl; 2 - GLJrnDtl VS Journal; 4 - Journal VS FACT_Financials;
	@Entity_MemberKey nvarchar(50) = NULL,
	@Entity_Book nvarchar(50) = NULL, 
	@FiscalYear int = NULL, --Default: go back 3 months
	--@FiscalPeriod int = NULL,--Default: go back 3 months
	--@Account nvarchar(50) = NULL,
	@ShowAllYN bit = 0,
	@ResultTypeBM int = 1, --1=generate new CheckSumStatus count, 2=get CheckSumStatus count, 4=Details (of @CheckSumStatusBM) 
	@CheckSumValue int = NULL OUT,
	--@CheckSumStatus10 int = NULL OUT,
	--@CheckSumStatus20 int = NULL OUT,
	--@CheckSumStatus30 int = NULL OUT,
	--@CheckSumStatus40 int = NULL OUT,
	@CheckSumStatusBM int = 7, -- 1=Open, 2=Investigating, 4=Ignored, 8=Solved
	@Balance_Sheet_ nvarchar(50) = 'Balance_Sheet_',


	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000898,
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
EXEC [spCheckSum_OpeningBalance] @UserID=-10, @InstanceID=454, @VersionID=1021,
@ResultTypeBM=7,@ShowAllYN=0, @Balance_Sheet_ = 'Balance_Sheet_', @Entity_MemberKey = 'R510',
@FiscalYear=2024, @DebugBM=7

EXEC [spCheckSum_OpeningBalance] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF


DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
--	@EntityID int,
	@Entity nvarchar(50),
	@Book nvarchar(50),
--	@SourceDatabase nvarchar(255),
--	@BalanceType nvarchar(10),
--	@StartFiscalYear int,
--	@FiscalPeriodDimExistsYN bit = 0,
	@ReturnVariable int,
	@LeafLevelFilter nvarchar(max),

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
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Check opening balances',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

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
			[pcINTEGRATOR].[dbo].[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @DebugBM & 2 > 0 
			SELECT 
				[@ETLDatabase] = @ETLDatabase, 
				[@CallistoDatabase] = @CallistoDatabase, 
				[@Entity_MemberKey] = @Entity_MemberKey,
				[@Entity_Book] = @Entity_Book,
				[@FiscalYear] = @FiscalYear

	SET @Step = 'Create table #OB_Check_1'
		CREATE TABLE #OB_Check_1
			(
			[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[OB_ERP] money,
			[OB_JRN] money,
			[OB_ADJ] money
			)

	SET @Step = 'Create #EB (Entity/Book)'
		SELECT DISTINCT
			[EntityID] = E.[EntityID],
			[Entity] = E.[MemberKey],
			[EntityName] = E.[EntityName],
			[Book] = B.[Book]
		INTO
			#EB
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.VersionID AND B.EntityID = E.EntityID AND B.BookTypeBM & 3 > 0 AND B.SelectYN <> 0 AND (B.Book = @Entity_Book OR @Entity_Book IS NULL)
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.MemberKey = @Entity_MemberKey OR @Entity_MemberKey IS NULL) AND
			(B.[Book] = @Entity_Book OR @Entity_Book IS NULL) AND
			E.[SelectYN] <> 0
		OPTION (MAXDOP 1)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#EB', * FROM #EB

	SET @Step = 'Create temp table #BalanceSheet'
		CREATE TABLE #BalanceSheet
			(
			Account nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		CREATE UNIQUE NONCLUSTERED INDEX [Account_idx] ON [#BalanceSheet]
			(
			[Account] ASC
			)

		EXEC pcINTEGRATOR..spGet_LeafLevelFilter @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DatabaseName=@CallistoDatabase, @DimensionName='Account', @Filter= @Balance_Sheet_, @StorageTypeBM=4, @UseCacheYN=0, @StorageTypeBM_DataClass=4, @LeafLevelFilter=@LeafLevelFilter OUT

		SET @SQLStatement = '
			INSERT INTO #BalanceSheet
				(
				[Account]
				)
			SELECT DISTINCT
				[Label]
			FROM
				' + @CallistoDatabase + '..S_DS_Account
			WHERE
				MemberID IN (' + @LeafLevelFilter + ') AND
				TimeBalance <> 0'
	
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#BalanceSheet', * FROM #BalanceSheet ORDER BY [Account]

	SET @Step = 'EB_Cursor'
		SET @CheckSumValue = 0

		IF CURSOR_STATUS('global','EB_Cursor') >= -1 DEALLOCATE EB_Cursor
		DECLARE EB_Cursor CURSOR FOR
			
			SELECT 
				[Entity],
				[Book]
			FROM
				#EB
			ORDER BY
				[Entity],
				[Book]

			OPEN EB_Cursor
			FETCH NEXT FROM EB_Cursor INTO @Entity, @Book

			WHILE @@FETCH_STATUS = 0
				BEGIN
					TRUNCATE TABLE #OB_Check_1
					IF OBJECT_ID(N'tempdb..#OB_Check') IS NOT NULL DROP TABLE #OB_Check
					IF OBJECT_ID(N'tempdb..#OB_Check_Tot') IS NOT NULL DROP TABLE #OB_Check_Tot

					SET @SQLStatement = '
						INSERT INTO #OB_Check_1
							(
							[Account],
							[OB_ERP],
							[OB_JRN],
							[OB_ADJ]
							)
						SELECT 
							J.[Account],
							[OB_ERP] = ROUND(SUM(CASE WHEN JournalSequence = ''OB_ERP'' THEN ValueDebit_Book - ValueCredit_Book ELSE 0 END), 2),
							[OB_JRN] = ROUND(SUM(CASE WHEN JournalSequence = ''OB_JRN'' THEN ValueDebit_Book - ValueCredit_Book ELSE 0 END), 2),
							[OB_ADJ] = ROUND(SUM(CASE WHEN JournalSequence = ''OB_ADJ'' THEN ValueDebit_Book - ValueCredit_Book ELSE 0 END), 2)
						FROM
							' + @ETLDatabase + '.[dbo].[Journal] J
							INNER JOIN #BalanceSheet BS ON BS.[Account] = J.[Account]
						WHERE
							[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							[Entity] = ''' + @Entity + ''' AND 
							[Book] = ''' + @Book + ''' AND
							FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
							[FiscalPeriod] = 0 AND
							[JournalSequence] IN (''OB_ERP'', ''OB_JRN'', ''OB_ADJ'') AND 
							[BalanceYN] <> 0 AND
							[ConsolidationGroup] IS NULL AND 
							[TransactionTypeBM] & 23 > 0 AND
							[Scenario] = ''ACTUAL'' AND
							1 = 1 
						GROUP BY J.[Account]
						ORDER BY J.[Account]'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					IF @DebugBM & 2 > 0 SELECT TempTable = '#OB_Check_1', * FROM #OB_Check_1 ORDER BY [Account]

					SELECT
						[Account],
						[OB_ERP],
						[OB_JRN],
						[OB_ADJ],	
						[JRN+ADJ] = ROUND(OBC.[OB_JRN] + OBC.[OB_ADJ], 2),
						[ERPvsADJ] = ROUND(OBC.[OB_ERP] - (OBC.[OB_JRN] + OBC.[OB_ADJ]), 2),
						[ERPvsJRN] = ROUND(OBC.[OB_ERP] - OBC.[OB_JRN], 2)
					INTO
						#OB_Check
					FROM
						#OB_Check_1 OBC
					ORDER BY
						[Account]

					IF @DebugBM & 2 > 0 SELECT TempTable = '#OB_Check', * FROM #OB_Check ORDER BY [Account]

					SELECT
						[OB_ERP] = ROUND(SUM(OBC.[OB_ERP]), 2),
						[OB_JRN] = ROUND(SUM(OBC.[OB_JRN]), 2),
						[OB_ADJ] = ROUND(SUM(OBC.[OB_ADJ]), 2),
						[JRN+ADJ] = ROUND(SUM(OBC.[JRN+ADJ]), 2),
						[ERPvsADJ] = ROUND(SUM(OBC.[ERPvsADJ]), 2),
						[ERPvsJRN] = ROUND(SUM(OBC.[ERPvsJRN]), 2)
					INTO
						#OB_Check_Tot
					FROM
						#OB_Check OBC

					IF @DebugBM & 2 > 0 SELECT TempTable = '#OB_Check_Tot', * FROM #OB_Check_Tot

					SELECT
						@CheckSumValue = @CheckSumValue + CONVERT(int, ISNULL([OB_ERP], 0) + ISNULL([OB_JRN], 0) + ISNULL([OB_ADJ], 0) + ISNULL([JRN+ADJ], 0) + ISNULL([ERPvsADJ], 0))
					FROM
						#OB_Check_Tot

					IF @ResultTypeBM & 4 > 0 AND (SELECT CONVERT(int, ISNULL([OB_ERP], 0) + ISNULL([OB_JRN], 0) + ISNULL([OB_ADJ], 0) + ISNULL([JRN+ADJ], 0) + ISNULL([ERPvsADJ], 0)) FROM #OB_Check_Tot) <> 0
						SELECT
							[Entity with issue] = @Entity,
							[@Book] = @Book,
							[@FiscalYear] = @FiscalYear,
							*
						FROM
							#OB_Check_Tot

					FETCH NEXT FROM EB_Cursor INTO @Entity, @Book
				END

		CLOSE EB_Cursor
		DEALLOCATE EB_Cursor

	SET @Step = 'Get detailed info'
		IF @ResultTypeBM & 4 > 0 AND @Entity_MemberKey IS NOT NULL
			BEGIN
				SELECT
					[@InstanceID] = @InstanceID,
					[@Entity] = @Entity,
					[@Book] = @Book,
					[@FiscalYear] = @FiscalYear,
					[@CheckSumValue] = @CheckSumValue

				SELECT
					TempTable = '#OB_Check',
					*
				FROM
					#OB_Check
				ORDER BY
					[Account]

				SELECT
					TempTable = '#OB_Check_Tot',
					*
				FROM
					#OB_Check_Tot
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #BalanceSheet
		DROP TABLE #OB_Check_1
		DROP TABLE #OB_Check
		DROP TABLE #OB_Check_Tot

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
