SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_CYNI_Adjustment]
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
	@ProcedureID int = 880000773,
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
EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = '44', @Book = 'GL', @FiscalYear = 2020, @Debug = 1

EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = 'CR', @Book = 'GL', @FiscalYear = 2013, @Debug = 1
EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = 'CR', @Book = 'GL', @FiscalYear = 2014, @Debug = 1
EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = 'CR', @Book = 'GL', @FiscalYear = 2015, @Debug = 1
EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = 'CR', @Book = 'GL', @FiscalYear = 2016, @Debug = 1
EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = 'CR', @Book = 'GL', @FiscalYear = 2017, @Debug = 1
EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = 'CR', @Book = 'GL', @FiscalYear = 2018, @Debug = 1
EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = 'CR', @Book = 'GL', @FiscalYear = 2019, @Debug = 1
EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = 'CR', @Book = 'GL', @FiscalYear = 2020, @Debug = 1
EXEC [spIU_DC_Journal_CYNI_Adjustment] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @Entity_MemberKey = 'CR', @Book = 'GL', @FiscalYear = 2021, @Debug = 1

EXEC [spIU_DC_Journal_CYNI_Adjustment] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CYNI_Value float,
--	@FiscalYear int,
--	@FiscalPeriod int,
	@YearMonth int,
	@Currency nchar(3),
	@SQLStatement nvarchar(max),

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert CYNI transactions into Journal.',
			@MandatoryParameter = 'Entity_MemberKey|Book|FiscalYear' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data]. Implemented [spGet_JournalTable].'
		IF @Version = '2.0.2.2148' SET @Description = 'Exclude FiscalPeriod = 0 from CYNI calculation.'
		IF @Version = '2.0.3.2151' SET @Description = 'Exclude rows where ConsolidationGroup is set from CYNI calculation.'
		IF @Version = '2.0.3.2153' SET @Description = 'Calculate year by year.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set all segments to empty string.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.1.2168' SET @Description = 'Set [TransactionTypeBM] = 2.'

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

		SELECT
			@Currency = Currency
		FROM
			Entity E
			INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.EntityID = E.EntityID AND EB.Book = @Book
		WHERE
			E.InstanceID = @InstanceID AND
			E.MemberKey = @Entity_MemberKey

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		IF @Debug <> 0 SELECT [@FiscalYear] = @FiscalYear, [@JournalTable] = @JournalTable

	SET @Step = 'Create temp table #CYNI_Value'
		CREATE TABLE #CYNI_Value
			(
			Segment08 nvarchar(50),
			CYNI_Value float
            )

	SET @Step = 'Create and fill temp table #FiscalYear_CYNI'
		CREATE TABLE #FiscalYear_CYNI 
		(
		FiscalYear int,
		FiscalPeriod int,
		YearMonth int,	
		Segment08 nvarchar(50),
		CYNI_Value float
		)

		SET @SQLStatement = '
		INSERT INTO #FiscalYear_CYNI
			(
			FiscalYear,
			FiscalPeriod,
			YearMonth,
			Segment08,
			CYNI_Value
			)
		SELECT
			FiscalYear,
			FiscalPeriod,
			YearMonth = MAX(YearMonth),
			Segment08,
			CYNI_Value = CONVERT(float, 0.0)
		FROM
			' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
			INNER JOIN pcDATA_TECA..S_DS_Account A ON A.[Label] = J.[Account] AND A.[AccountType_MemberId] IN (10, 20, 30, 40, 50)
		WHERE
			InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
			Entity = ''' + @Entity_MemberKey + ''' AND
			Book = ''' + @Book + ''' AND
			ConsolidationGroup IS NULL AND
			FiscalYear = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
			' + CASE WHEN @FiscalPeriod IS NOT NULL THEN 'FiscalPeriod = ' + CONVERT(nvarchar(10), @FiscalPeriod) + ' AND' ELSE '' END + '
			FiscalPeriod <> 0 
			' + CASE WHEN @SequenceBM & 2 > 0 THEN '' ELSE 'AND [ConsolidationGroup] IS NULL' END + '
		GROUP BY
			FiscalYear,
			FiscalPeriod,
			Segment08
		ORDER BY
			FiscalYear,
			FiscalPeriod,
			Segment08'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#FiscalYear_CYNI', * FROM #FiscalYear_CYNI ORDER BY FiscalYear, FiscalPeriod

	SET @Step = 'Calculate @CYNI_Value'
		DECLARE FiscalYear_CYNI_Cursor CURSOR FOR
			SELECT DISTINCT
				FiscalYear,
				FiscalPeriod,
				YearMonth
			FROM
				#FiscalYear_CYNI
			WHERE
				FiscalPeriod <> 0
			ORDER BY
				FiscalYear,
				FiscalPeriod

			OPEN FiscalYear_CYNI_Cursor
			FETCH NEXT FROM FiscalYear_CYNI_Cursor INTO @FiscalYear, @FiscalPeriod, @YearMonth

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@FiscalYear] = @FiscalYear, [@FiscalPeriod] = @FiscalPeriod, [@YearMonth] = @YearMonth

					TRUNCATE TABLE #CYNI_Value
					
					SET @SQLStatement = '
					INSERT INTO #CYNI_Value
						(
						Segment08,
						CYNI_Value
						)
					SELECT
						Segment08,
						CYNI_Value = ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 4)
					FROM
						' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
						INNER JOIN pcDATA_TECA..S_DS_Account A ON A.[Label] = J.[Account] AND A.[AccountType_MemberId] IN (10, 20, 30, 40, 50)
					WHERE
						[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
						[Entity] = ''' + @Entity_MemberKey + ''' AND
						[Book] = ''' + @Book + ''' AND
						[ConsolidationGroup] IS NULL AND
						[FiscalYear] = ' + CONVERT(nvarchar(10), @FiscalYear) + ' AND
						[FiscalPeriod] = ' + CONVERT(nvarchar(10), @FiscalPeriod) + ' AND
						[TransactionTypeBM] & 1 > 0 AND
						[BalanceYN] = 0 AND
						[Scenario] = ''ACTUAL'' AND
						[Account] NOT IN (''CYNI_I'', ''CYNI_B'')
						' + CASE WHEN @SequenceBM & 2 > 0 THEN '' ELSE 'AND [ConsolidationGroup] IS NULL' END + '
					GROUP BY
						Segment08'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					--SELECT @CYNI_Value = CYNI_Value FROM #CYNI_Value

					--IF @Debug <> 0 SELECT [@CYNI_Value] = @CYNI_Value

					IF @Debug <> 0 SELECT TempTable = '#CYNI_Value', * FROM #CYNI_Value

					--IF ISNULL(@CYNI_Value, 0.0) <> 0.0
					--	BEGIN
							UPDATE FYC
							SET
								CYNI_Value = CV.[CYNI_Value]
							FROM
								#FiscalYear_CYNI FYC
								INNER JOIN #CYNI_Value CV ON CV.Segment08 = FYC.Segment08
							WHERE
								FYC.[FiscalYear] = @FiscalYear AND
								FYC.[FiscalPeriod] = @FiscalPeriod
						--END

					FETCH NEXT FROM FiscalYear_CYNI_Cursor INTO @FiscalYear, @FiscalPeriod, @YearMonth
				END

		CLOSE FiscalYear_CYNI_Cursor
		DEALLOCATE FiscalYear_CYNI_Cursor	

		IF @Debug <> 0 SELECT TempTable = '#FiscalYear_CYNI', * FROM #FiscalYear_CYNI ORDER BY [FiscalYear], [FiscalPeriod]

	SET @Step = 'Delete rows from Journal'

		SET @SQLStatement = '
		DELETE J
		FROM
			' + CASE WHEN @SequenceBM & 2 > 0 THEN '#Journal' ELSE @JournalTable END + ' J
			INNER JOIN #FiscalYear_CYNI FY ON FY.[FiscalYear] = J.FiscalYear AND FY.[FiscalPeriod] = J.FiscalPeriod
		WHERE
			J.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
			J.[Entity] = ''' + @Entity_MemberKey + ''' AND
			J.[Book] = ''' + @Book + ''' AND
			J.[ConsolidationGroup] IS NULL AND
			J.[Account] IN (''CYNI_I'', ''CYNI_B'')
			' + CASE WHEN @SequenceBM & 2 > 0 THEN '' ELSE 'AND [ConsolidationGroup] IS NULL' END

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT
			
	SET @Step = 'Insert rows into Journal'

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
			[Entity] = ''' + @Entity_MemberKey + ''',
			[Book] = ''' + @Book + ''',
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
			[Segment08] = FY.[Segment08],
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
			[PostedStatus] = 1,
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
