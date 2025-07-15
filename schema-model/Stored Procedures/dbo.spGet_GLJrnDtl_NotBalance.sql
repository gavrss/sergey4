SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_GLJrnDtl_NotBalance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceID int  = NULL,
	@JournalTable nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000779,
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
EXEC [spGet_GLJrnDtl_NotBalance] @UserID=-10, @InstanceID=478, @VersionID=1030, @Debug=1 --Angling Direct
EXEC [spGet_GLJrnDtl_NotBalance] @UserID=-10, @InstanceID=476, @VersionID=1029, @Debug=1 --Allied Aviation
EXEC [spGet_GLJrnDtl_NotBalance] @UserID=-10, @InstanceID=454, @VersionID=1021, @Debug=1 --CCM
EXEC [spGet_GLJrnDtl_NotBalance] @UserID=-10, @InstanceID=413, @VersionID=1008, @Debug=1 --CBN

EXEC [spGet_GLJrnDtl_NotBalance] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@Company nvarchar(8),
	@BookID nvarchar(12),
	@FiscalYear int,
	@FiscalPeriod int,
	@SourceDatabase nvarchar(100),
	@Owner nvarchar(10),
	@SQLStatement nvarchar(max),
	@MasterClosedFiscalYear int,

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
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Check GLJrnDtl for not balancing JournalNums.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2171' SET @Description = 'Procedure created.'

--		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@Owner = '[Erp]',
			@SourceID = ISNULL(@SourceID, S.[SourceID])
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND  S.SourceTypeID = 11 AND (S.SourceID = @SourceID OR @SourceID IS NULL) AND S.SelectYN <> 0
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0 

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		EXEC [spGet_MasterClosedYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @MasterClosedFiscalYear = @MasterClosedFiscalYear OUT, @JobID=@JobID

		IF @DebugBM & 2 > 0
			SELECT
				[@SourceDatabase] = @SourceDatabase,
				[@Owner] = @Owner,
				[@JournalTable] = @JournalTable,
				[@SourceID] = @SourceID,
				[@MasterClosedFiscalYear] = @MasterClosedFiscalYear

	SET @Step = 'Create #GLJrnDtl_NotBalance'
		IF OBJECT_ID(N'TempDB.dbo.#GLJrnDtl_NotBalance', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #GLJrnDtl_NotBalance
					(
					[SourceID] [int],
					[Company] [nvarchar](8),
					[BookID] [nvarchar](12),
					[FiscalYear] [int],
					[FiscalPeriod] [int],
					[JournalCode] [nvarchar](4),
					[JournalNum] [int],
					[MinJournalLine] [int],
					[MaxJournalLine] [int],
					[PostedDate] [date],
					[MinSysRevID] [bigint],
					[MaxSysRevID] [bigint],
					[Rows] [int],
					[Amount] [float],
					[JournalRows] [int],
					[JournalAmount] [float]
					)
			END

	SET @Step = 'Create #FP_CursorTable'
		CREATE TABLE #FP_CursorTable
			(
			[Company] nvarchar(8),
			[BookID] nvarchar(12),
			[FiscalYear] int,
			[FiscalPeriod] int,
			[Amount] decimal(18,3)
			)
		
		SET @SQLStatement = '
			INSERT INTO #FP_CursorTable
				(
				[Company],
				[BookID],
				[FiscalYear],
				[FiscalPeriod],
				[Amount]
				)
			SELECT 
				[Company],
				[BookID],
				[FiscalYear],
				[FiscalPeriod],
				[Amount] = ROUND(SUM(BookDebitAmount-BookCreditAmount), 2)
			FROM
				' + @SourceDatabase + '.' + @Owner + '.[GLJrnDtl]
			WHERE
				' + CASE WHEN @MasterClosedFiscalYear IS NULL THEN '' ELSE '[FiscalYear] > ' + CONVERT(nvarchar(15), @MasterClosedFiscalYear) + ' AND' END + '
				[FiscalPeriod] <> 0 
			GROUP BY
				[Company],
				[BookID],
				[FiscalYear],
				[FiscalPeriod]
			HAVING
				 ROUND(SUM(BookDebitAmount-BookCreditAmount), 2) <> 0.0
			ORDER BY
				[Company],
				[BookID],
				[FiscalYear],
				[FiscalPeriod]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#FP_CursorTable', * FROM #FP_CursorTable ORDER BY [Company], [BookID], [FiscalYear], [FiscalPeriod]

	SET @Step = 'FP_Cursor'
		IF CURSOR_STATUS('global','FP_Cursor') >= -1 DEALLOCATE FP_Cursor
		DECLARE FP_Cursor CURSOR FOR
			
			SELECT 
				[Company],
				[BookID],
				[FiscalYear],
				[FiscalPeriod]
			FROM
				#FP_CursorTable
			ORDER BY
				[Company],
				[BookID],
				[FiscalYear],
				[FiscalPeriod]

			OPEN FP_Cursor
			FETCH NEXT FROM FP_Cursor INTO @Company, @BookID, @FiscalYear, @FiscalPeriod

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@Company]=@Company, [@BookID]=@BookID, [@FiscalYear]=@FiscalYear, [@FiscalPeriod]=@FiscalPeriod

					SET @SQLStatement = '
						INSERT INTO #GLJrnDtl_NotBalance
							(
							[SourceID],
							[Company],
							[BookID],
							[FiscalYear],
							[FiscalPeriod],
							[JournalCode],
							[JournalNum],
							[MinJournalLine],
							[MaxJournalLine],
							[PostedDate],
							[MinSysRevID],
							[MaxSysRevID],
							[Rows],
							[Amount]
							)
						SELECT 
							[SourceID] = ' + CONVERT(nvarchar(15), @SourceID) + ',
							[Company],
							[BookID],
							[FiscalYear],
							[FiscalPeriod],
							[JournalCode],
							[JournalNum],
							[MinJournalLine] = MIN([JournalLine]),
							[MaxJournalLine] = MAX([JournalLine]),
							[PostedDate] = MAX([PostedDate]),
							[MinSysRevID] = MIN([SysRevID]),
							[MaxSysRevID] = MAX([SysRevID]),
							[Rows] = COUNT(1),
							[Amount] = ROUND(SUM(BookDebitAmount-BookCreditAmount), 2)
						FROM
							' + @SourceDatabase + '.' + @Owner + '.[GLJrnDtl]
						WHERE
							[Company] = ''' + @Company + ''' AND
							[BookID] = ''' + @Bookid + ''' AND
							[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
							[FiscalPeriod] = ' + CONVERT(nvarchar(15), @FiscalPeriod) + '
						GROUP BY
							[Company],
							[BookID],
							[FiscalYear],
							[FiscalPeriod],
							[JournalCode],
							[JournalNum] 
						HAVING
							 ROUND(SUM(BookDebitAmount-BookCreditAmount), 2) <> 0.0
						ORDER BY
							[Company],
							[BookID],
							[FiscalYear],
							[FiscalPeriod],
							[JournalCode],
							[JournalNum]' 

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM FP_Cursor INTO @Company, @BookID, @FiscalYear, @FiscalPeriod
				END

		CLOSE FP_Cursor
		DEALLOCATE FP_Cursor

	SET @Step = 'Update with data from Journal'
		SET @SQLStatement = '
			UPDATE wrk_NB
			SET
				[JournalRows] = sub.[JournalRows],
				[JournalAmount] = ROUND(sub.[JournalAmount], 4)
			FROM
				#GLJrnDtl_NotBalance wrk_NB
				INNER JOIN 
					(
					SELECT
						NB.[Company],
						NB.[BookID],
						NB.[FiscalYear],
						NB.[FiscalPeriod],
						NB.[JournalCode],
						NB.[JournalNum],
						[JournalRows] = COUNT(1),
						[JournalAmount] = SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book])
					FROM
						' + @JournalTable + ' J
						INNER JOIN #GLJrnDtl_NotBalance NB ON
							NB.[Company] = J.[Entity] AND
							NB.[BookID] = J.[Book] AND
							NB.[FiscalYear] = J.[FiscalYear] AND
							NB.[FiscalPeriod] = J.[FiscalPeriod] AND
							NB.[JournalCode] = J.[JournalSequence] AND
							CONVERT(nvarchar(50), NB.[JournalNum]) = J.[JournalNo]
					WHERE
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.TransactionTypeBM & 3 > 0
					GROUP BY
						NB.[Company],
						NB.[BookID],
						NB.[FiscalYear],
						NB.[FiscalPeriod],
						NB.[JournalCode],
						NB.[JournalNum]
					) sub ON 
						sub.[Company] = wrk_NB.[Company] AND
						sub.[BookID] = wrk_NB.[BookID] AND
						sub.[FiscalYear] = wrk_NB.[FiscalYear] AND
						sub.[FiscalPeriod] = wrk_NB.[FiscalPeriod] AND
						sub.[JournalCode] = wrk_NB.[JournalCode] AND
						sub.[JournalNum] = wrk_NB.[JournalNum]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Update table [wrk_GLJrnDtl_NotBalance]'
		DELETE [pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance]
		WHERE
			[JobID] = @JobID AND
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SourceID] = @SourceID

		SET @Deleted = @Deleted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance]
			(
			[JobID],
			[InstanceID],
			[VersionID],
			[SourceID],
			[Company],
			[BookID],
			[FiscalYear],
			[FiscalPeriod],
			[JournalCode],
			[JournalNum],
			[MinJournalLine],
			[MaxJournalLine],
			[PostedDate],
			[MinSysRevID],
			[MaxSysRevID],
			[Rows],
			[Amount],
			[JournalRows],
			[JournalAmount]
			)
		SELECT 
			[JobID] = @JobID,
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[SourceID] = @SourceID,
			[Company],
			[BookID],
			[FiscalYear],
			[FiscalPeriod],
			[JournalCode],
			[JournalNum],
			[MinJournalLine],
			[MaxJournalLine],
			[PostedDate],
			[MinSysRevID],
			[MaxSysRevID],
			[Rows],
			[Amount],
			[JournalRows],
			[JournalAmount]
		FROM
			#GLJrnDtl_NotBalance

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0
			SELECT
				[Table] = 'wrk_GLJrnDtl_NotBalance',
				*
			FROM
				[pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance]
			WHERE
				[JobID] = @JobID AND
				[InstanceID] = @InstanceID AND
				[VersionID] = @VersionID AND
				[SourceID] = @SourceID
			ORDER BY
				[Company],
				[BookID],
				[FiscalYear],
				[FiscalPeriod],
				[JournalCode],
				[JournalNum] 

	SET @Step = 'Drop the temp tables'
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #GLJrnDtl_NotBalance
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
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
