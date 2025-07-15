SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_CYNI]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@SequenceBM int = 0, --2 = Called from SP holding #Journal filled with transactions
	@JournalTable nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000640,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_Journal_CYNI',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "Entity_MemberKey",  "TValue": "52982"},
		{"TKey" : "Book",  "TValue": "CBN_Main"}
		]',
	@Debug = 1

EXEC [spIU_DC_Journal_CYNI] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @Entity_MemberKey = 'SAN', @Book = 'MAIN', @FiscalYear = 2019, @Debug = 1

EXEC [spIU_DC_Journal_CYNI] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '11', @Book = 'GL', @FiscalYear = 2015, @Debug = 1
EXEC [spIU_DC_Journal_CYNI] @UserID = -10, @InstanceID = 448, @VersionID = 1018, @Entity_MemberKey = '1', @Book = 'GL', @FiscalYear = 2019, @Debug = 1

EXEC [spIU_DC_Journal_CYNI @UserID = -10, @InstanceID = 527, @VersionID = 1055, @Entity_MemberKey = 'GGI01', @Book = 'NewBook', @FiscalYear = 2021, @Debug = 1

EXEC [spIU_DC_Journal_CYNI] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @Entity_MemberKey = 'GGI03', @FiscalYear = 2019, @Debug = 1

EXEC [spIU_DC_Journal_CYNI] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @Debug = 1

EXEC [spIU_DC_Journal_CYNI] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CYNI_Value float,
	@YearMonth int,
	@Currency nchar(3),
	@SQLStatement nvarchar(max),
	@CalledFiscalPeriod int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
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
	@ModifiedBy nvarchar(50) = 'KeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert CYNI transactions into Journal.',
			@MandatoryParameter = '' --Without @, separated by |


		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data]. Implemented [spGet_JournalTable].'
		IF @Version = '2.0.2.2148' SET @Description = 'Exclude FiscalPeriod = 0 from CYNI calculation.'
		IF @Version = '2.0.3.2151' SET @Description = 'Exclude rows where ConsolidationGroup is set from CYNI calculation.'
		IF @Version = '2.0.3.2153' SET @Description = 'Calculate year by year.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set all segments to empty string.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.1.2168' SET @Description = 'Set [TransactionTypeBM] = 2.'
		IF @Version = '2.1.1.2174' SET @Description = 'Include [TransactionTypeBM] = 16. Handle Multiple Entities, Books and FiscalYears by using a cursor.'
		IF @Version = '2.1.1.2176' SET @Description = 'Test on PostedStatus.'
		IF @Version = '2.1.2.2188' SET @Description = 'DB-1311: Added @Entity_MemberKey filter when INSERTing INTO #Entity_Cursor (ETL routine).'
		IF @Version = '2.1.2.2199' SET @Description = 'Added J.[TransactionTypeBM] = 2 in the CYNI_B delete statement'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

--SET NOCOUNT ON

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

		SET @CalledFiscalPeriod = @FiscalPeriod

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		IF @Debug <> 0
			SELECT
				[@Entity_MemberKey] = @Entity_MemberKey,
				[@Book] = @Book,
				[@FiscalYear] = @FiscalYear,
				[@CalledFiscalPeriod] = @CalledFiscalPeriod,
				[@JournalTable] = @JournalTable

	SET @Step = 'Create temp table #CYNI_Value'
		CREATE TABLE #CYNI_Value
			(
			[PostedStatus] bit,
			[CYNI_Value] float
            )

	SET @Step = 'Create temp table #FiscalYear_CYNI'
		CREATE TABLE #FiscalYear_CYNI 
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] int,
			[FiscalPeriod] int,
			[YearMonth] int,
			[PostedStatus] bit,
			[CYNI_Value] float
			)

	SET @Step = 'Create temp #Entity_Cursor'
		CREATE TABLE #Entity_Cursor 
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Currency] nchar(3),
			[FiscalYear] int
			)

		IF @Entity_MemberKey IS NOT NULL AND @Book IS NOT NULL AND @FiscalYear IS NOT NULL
			INSERT INTO #Entity_Cursor 
				(
				[Entity],
				[Book],
				[Currency],
				[FiscalYear]
				)
			SELECT DISTINCT
				--[Entity] = @Entity_MemberKey,
				--[Book] = @Book,
				[Entity] = E.[MemberKey],
				[Book] = EB.[Book],
				[Currency] = EB.[Currency],
				[FiscalYear] = @FiscalYear
			FROM
				[pcINTEGRATOR_Data].[dbo].[Entity] E
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND EB.[BookTypeBM] & 1 > 0 AND EB.[SelectYN] <> 0 AND EB.[Book] = @Book
			WHERE
				E.[InstanceID] = @InstanceID AND
				E.[VersionID] = @VersionID AND
				E.[MemberKey] = @Entity_MemberKey AND
				E.[EntityTypeID] = -1 AND
				E.[SelectYN] <> 0
		ELSE
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #Entity_Cursor 
						(
						[Entity],
						[Book],
						[Currency],
						FiscalYear
						)
					SELECT DISTINCT
						[Entity] = E.[MemberKey],
						[Book] = EB.[Book],
						[Currency] = EB.[Currency],
						[FiscalYear] = J.[FiscalYear]
					FROM
						pcINTEGRATOR_Data..[Entity] E
						INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND EB.[BookTypeBM] & 1 > 0 AND EB.[SelectYN] <> 0' + CASE WHEN @Book IS NOT NULL THEN ' AND EB.[Book] = ''' + @Book + '''' ELSE '' END + '
						INNER JOIN ' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J ON J.[InstanceID] = E.[InstanceID] AND J.[Entity] = E.[MemberKey] AND J.[Book] = EB.[Book] AND J.[Scenario] = ''ACTUAL''' + CASE WHEN @FiscalYear IS NOT NULL THEN ' AND J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) ELSE '' END + '
					WHERE
						E.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						E.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
						E.[EntityTypeID] = -1 AND
						E.[SelectYN] <> 0' +
						CASE WHEN @Entity_MemberKey IS NOT NULL THEN ' AND E.[MemberKey] = ''' + @Entity_MemberKey + '''' ELSE '' END
			END

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			IF @Debug <> 0 SELECT TempTable = '#Entity_Cursor', * FROM #Entity_Cursor ORDER BY [Entity], [Book], [FiscalYear]

	SET @Step = 'Entity_Cursor'
		IF CURSOR_STATUS('global','Entity_Cursor') >= -1 DEALLOCATE Entity_Cursor
		DECLARE Entity_Cursor CURSOR FOR
			
			SELECT DISTINCT
				Entity,
				Book,
				Currency,
				FiscalYear
			FROM
				#Entity_Cursor 
			ORDER BY
				Entity,
				Book,
				FiscalYear

			OPEN Entity_Cursor
			FETCH NEXT FROM Entity_Cursor INTO @Entity_MemberKey, @Book, @Currency, @FiscalYear

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@Entity_MemberKey] = @Entity_MemberKey, [@Book] = @Book, [@Currency] = @Currency, [@FiscalYear] = @FiscalYear

					--Fill temp table #FiscalYear_CYNI'
					TRUNCATE TABLE #FiscalYear_CYNI
					SET @SQLStatement = '
						INSERT INTO #FiscalYear_CYNI
							(
							[Entity],
							[Book],
							[FiscalYear],
							[FiscalPeriod],
							[YearMonth],
							[PostedStatus],
							[CYNI_Value]
							)
						SELECT
							[Entity] = ''' + @Entity_MemberKey + ''',
							[Book] = ''' + @Book + ''',
							[FiscalYear],
							[FiscalPeriod],
							YearMonth = MAX(YearMonth),
							[PostedStatus],
							CYNI_Value = CONVERT(float, 0.0)
						FROM
							' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
						WHERE
							[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
							[Entity] = ''' + @Entity_MemberKey + ''' AND
							[Book] = ''' + @Book + ''' AND
							[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
							' + CASE WHEN @CalledFiscalPeriod IS NOT NULL THEN '[FiscalPeriod] = ' + CONVERT(nvarchar(10), @CalledFiscalPeriod) + ' AND' ELSE '' END + '
							[FiscalPeriod] <> 0 
							' + CASE WHEN @SequenceBM & 2 > 0 THEN '' ELSE 'AND [ConsolidationGroup] IS NULL' END + '
						GROUP BY
							[FiscalYear],
							[FiscalPeriod],
							[PostedStatus]
						ORDER BY
							[FiscalYear],
							[FiscalPeriod],
							[PostedStatus]'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @Debug <> 0 SELECT TempTable = '#FiscalYear_CYNI', * FROM #FiscalYear_CYNI ORDER BY FiscalYear, FiscalPeriod

					--Calculate @CYNI_Value'
					DECLARE FiscalYear_CYNI_Cursor CURSOR FOR
						SELECT DISTINCT
							[FiscalYear],
							[FiscalPeriod],
							[YearMonth]
						FROM
							#FiscalYear_CYNI
						WHERE
							[Entity] = @Entity_MemberKey AND
							[Book] = @Book AND
							[FiscalPeriod] <> 0
						ORDER BY
							[FiscalYear],
							[FiscalPeriod]

						OPEN FiscalYear_CYNI_Cursor
						FETCH NEXT FROM FiscalYear_CYNI_Cursor INTO @FiscalYear, @FiscalPeriod, @YearMonth

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @Debug <> 0 SELECT [@FiscalYear] = @FiscalYear, [@FiscalPeriod] = @FiscalPeriod, [@YearMonth] = @YearMonth

								TRUNCATE TABLE #CYNI_Value
								
								SET @SQLStatement = '
								INSERT INTO #CYNI_Value
									(
									[PostedStatus],
									[CYNI_Value]
									)
								SELECT
									[PostedStatus] = J.[PostedStatus],
									[CYNI_Value] = ROUND(SUM(J.[ValueDebit_Book] - J.[ValueCredit_Book]), 4)
								FROM
									' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
								WHERE
									J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
									J.[Entity] = ''' + @Entity_MemberKey + ''' AND
									J.[Book] = ''' + @Book + ''' AND
									J.[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
									J.[FiscalPeriod] = ' + CONVERT(nvarchar(10), @FiscalPeriod) + ' AND
									J.[TransactionTypeBM] & 19 > 0 AND
									J.[BalanceYN] = 0 AND
									J.[Scenario] = ''ACTUAL'' AND
									J.[Account] NOT IN (''CYNI_I'', ''CYNI_B'')
									' + CASE WHEN @SequenceBM & 2 > 0 THEN '' ELSE 'AND J.[ConsolidationGroup] IS NULL' END + '
								GROUP BY
									J.[PostedStatus]'

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								IF @Debug <> 0 SELECT [TempTable] = '#CYNI_Value', * FROM #CYNI_Value

								UPDATE FY_CYNI
								SET
									[CYNI_Value] = CYNI.[CYNI_Value]
								FROM
									#FiscalYear_CYNI FY_CYNI
									INNER JOIN #CYNI_Value CYNI ON CYNI.[PostedStatus] = FY_CYNI.[PostedStatus] AND CYNI.[CYNI_Value] IS NOT NULL
								WHERE
									FY_CYNI.[Entity] = @Entity_MemberKey AND
									FY_CYNI.[Book] = @Book AND
									FY_CYNI.[FiscalYear] = @FiscalYear AND
									FY_CYNI.[FiscalPeriod] = @FiscalPeriod

								FETCH NEXT FROM FiscalYear_CYNI_Cursor INTO @FiscalYear, @FiscalPeriod, @YearMonth
							END

					CLOSE FiscalYear_CYNI_Cursor
					DEALLOCATE FiscalYear_CYNI_Cursor	

					IF @Debug <> 0 SELECT TempTable = '#FiscalYear_CYNI', * FROM #FiscalYear_CYNI ORDER BY [FiscalYear], [FiscalPeriod]

					--Delete rows from Journal
					SET @SQLStatement = '
						DELETE J
						FROM
							' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
							INNER JOIN #FiscalYear_CYNI FY ON FY.[Entity] = J.[Entity] AND FY.[Book] = J.[Book] AND FY.[FiscalYear] = J.FiscalYear AND FY.[FiscalPeriod] = J.FiscalPeriod
						WHERE
							J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
							J.[Entity] = ''' + @Entity_MemberKey + ''' AND
							J.[Book] = ''' + @Book + ''' AND
							J.[TransactionTypeBM] = 2 AND
							J.[Account] IN (''CYNI_I'', ''CYNI_B'')
							' + CASE WHEN @SequenceBM & 2 > 0 THEN '' ELSE 'AND [ConsolidationGroup] IS NULL' END

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Deleted = @Deleted + @@ROWCOUNT
			
					--Insert rows into Journal
					IF @Debug <> 0 
						SELECT
							[@UserName] = @UserName,
							[@Currency] = @Currency

					SET @SQLStatement = '
						INSERT INTO ' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + '
							(
							[JobID],
							[InstanceID],
							[Entity],
							[Book],
							[FiscalYear],
							[FiscalPeriod],
							[JournalSequence],
							[JournalNo],
							[JournalLine],
							[YearMonth],
							[TransactionTypeBM],
							[BalanceYN],
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
							[JournalDate],
							[TransactionDate],
							[PostedDate],
							[PostedStatus],
							[PostedBy],
							[Source],
							[Scenario],
							[Description_Head],
							[Description_Line],
							[Currency_Book],
							[ValueDebit_Book],
							[ValueCredit_Book]
							)
						SELECT
							[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
							[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
							[Entity] = FY.[Entity],
							[Book] = FY.[Book],
							[FiscalYear] = FY.[FiscalYear],
							[FiscalPeriod] = FY.[FiscalPeriod],
							[JournalSequence] = ''CYNI'',
							[JournalNo] = ''0'',
							[JournalLine] = 0,
							[YearMonth] = FY.[YearMonth],
							[TransactionTypeBM] = 2,
							[BalanceYN] = CASE A.Account WHEN ''CYNI_I'' THEN 0 WHEN ''CYNI_B'' THEN 1 END,
							[Account] = A.[Account],
							[Segment01] = '''',
							[Segment02] = '''',
							[Segment03] = '''',
							[Segment04] = '''',
							[Segment05] = '''',
							[Segment06] = '''',
							[Segment07] = '''',
							[Segment08] = '''',
							[Segment09] = '''',
							[Segment10] = '''',
							[Segment11] = '''',
							[Segment12] = '''',
							[Segment13] = '''',
							[Segment14] = '''',
							[Segment15] = '''',
							[Segment16] = '''',
							[Segment17] = '''',
							[Segment18] = '''',
							[Segment19] = '''',
							[Segment20] = '''',
							[JournalDate] = DATEADD(day, -1, DATEADD(month, 1, CONVERT(datetime, CONVERT(nvarchar(10), FY.[YearMonth]) + ''01'', 112))),
							[TransactionDate] = DATEADD(day, -1, DATEADD(month, 1, CONVERT(datetime, CONVERT(nvarchar(10), FY.[YearMonth]) + ''01'', 112))),
							[PostedDate] = GetDate(),
							[PostedStatus] = FY.[PostedStatus],
							[PostedBy] = ''' + @UserName + ''',
							[Source] = ''BR'',
							[Scenario] = ''ACTUAL'',
							[Description_Head] = ''Current Year Net Income'',
							[Description_Line] = ''Current Year Net Income'',
							[Currency_Book] = ''' + @Currency + ''',
							[ValueDebit_Book] = CASE WHEN FY.CYNI_Value < 0.0 AND A.Account = ''CYNI_I'' THEN -1 * CYNI_Value ELSE CASE WHEN FY.CYNI_Value > 0.0 AND A.Account = ''CYNI_B'' THEN CYNI_Value ELSE 0 END END,
							[ValueCredit_Book] = CASE WHEN FY.CYNI_Value < 0.0 AND A.Account = ''CYNI_B'' THEN -1 * CYNI_Value ELSE CASE WHEN FY.CYNI_Value > 0.0 AND A.Account = ''CYNI_I'' THEN CYNI_Value ELSE 0 END END
						FROM
							#FiscalYear_CYNI FY
							INNER JOIN (SELECT Account = ''CYNI_I'' UNION SELECT Account = ''CYNI_B'') A ON 1 = 1
						WHERE
							CYNI_Value <> 0.0'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Inserted = @Inserted + @@ROWCOUNT

					FETCH NEXT FROM Entity_Cursor INTO @Entity_MemberKey, @Book, @Currency, @FiscalYear
				END

		CLOSE Entity_Cursor
		DEALLOCATE Entity_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE #FiscalYear_CYNI
		DROP TABLE #CYNI_Value

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
