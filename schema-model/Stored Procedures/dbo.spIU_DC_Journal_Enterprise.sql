SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_Enterprise]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@StartFiscalYear int = NULL,
	@SequenceBM int = 11, --1 = GL transactions, 2 = Opening balances, 4 = Budget transactions, 8 = Income Summary
	@JournalTable nvarchar(100) = NULL,
	@FullReloadYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000639,
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
	@ProcedureName = 'spIU_DC_Journal_Enterprise',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "Entity_MemberKey",  "TValue": "52982"},
		{"TKey" : "Book",  "TValue": "CBN_Main"}
		]',
	@Debug = 1

EXEC [spIU_DC_Journal_Enterprise] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '52982', @Book = 'CBN_Main', @FiscalYear = 2019, @FiscalPeriod = 5, @Debug = 1
EXEC [spIU_DC_Journal_Enterprise] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '16', @Book = 'GL', @Debug = 1
EXEC [spIU_DC_Journal_Enterprise_New] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Entity_MemberKey = '1', @Book = 'GL', @SequenceBM = 8, @FiscalYear = 2018, @FiscalPeriod = 5, @Debug = 1

EXEC [spIU_DC_Journal_Enterprise] @UserID = -10, @InstanceID = 428, @VersionID = 1001, @Entity_MemberKey = '1', @Book = 'GL', @SequenceBM = 8, @FiscalYear = 2017, @Debug = 1
EXEC [spIU_DC_Journal_Enterprise] @UserID = -10, @InstanceID = 428, @VersionID = 1001, @Entity_MemberKey = '1', @Book = 'GL', @FiscalYear = 2019, @Debug = 1

EXEC [spIU_DC_Journal_Enterprise] @UserID = -10, @InstanceID = 424, @VersionID = 1017, @Entity_MemberKey = 'HDCI', @Book = 'GL', @FiscalYear = 2010, @Debug = 1
EXEC [spIU_DC_Journal_Enterprise] @UserID = -10, @InstanceID = 458, @VersionID = 1022, @Entity_MemberKey = '1', @Book = 'GL', @SequenceBM = 8, @Debug = 1

EXEC [spIU_DC_Journal_Enterprise] @UserID = -10, @InstanceID = -1051, @VersionID = -1051, @Entity_MemberKey = '4', @Book = 'GL', @SequenceBM = 4, @Debug = 1

EXEC [spIU_DC_Journal_Enterprise] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceDatabase nvarchar(100),
	@EntityID int,
	@Currency nchar(3),
	@SQLStatement nvarchar(max),
	@SQLSegment nvarchar(max),
	@SegmentNo int = -1,
	@MinFiscalYear int,
	@MinYearMonth int,
	@MinStartDate int,
	@StartDate date,
	@PrevStartDate int,
	@PrevEndDate int,
	@AccountSegmentNo nchar(1),
	@MasterDatabase nvarchar(100),
	@App_id_AR int,
	@App_id_AP int,
	@SourceTypeID int = 12, --Enterprise
	@ENT_CYNI_B nvarchar(50),
	@ENT_CYNI_I nvarchar(50),
	@AccountCode nvarchar(50),
	@MaxYearMonth int,

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
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into #Journal from source Enterprise.',
			@MandatoryParameter = 'Entity_MemberKey|Book' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2144' SET @Description = 'Test on full account for Income Summary. Changed join in Update #FiscalPeriod. Added setting of [Journal] column SourceModule from [gltrx_all] journal_type column.'
		IF @Version = '2.0.2.2146' SET @Description = 'Added budget, @SequenceBM = 4. While missing, set @App_id_AR and @App_id_AP to 0 instead of NULL'
		IF @Version = '2.0.3.2151' SET @Description = 'Updated datatypes in temp table #Journal.'
		IF @Version = '2.1.0.2155' SET @Description = 'Removed @StartFiscalYear parameter when calling [spIU_DC_Journal_OpeningBalance].'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.0.2162' SET @Description = 'Changed Balance account selection, according to Sandra/Gotwals.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added COLLATE expression in the query for @Step = Insert opening balances into temp table #Journal.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added @FullReloadYN.'

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

	SELECT
			@EntityID = E.EntityID,
			@Currency = EB.Currency
		FROM
			Entity E
			INNER JOIN Entity_Book EB ON EB.EntityID = E.EntityID AND EB.Book = @Book AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.MemberKey = @Entity_MemberKey AND
			E.SelectYN <> 0

		SELECT
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(EntityPropertyValue, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			EntityPropertyValue
		WHERE
			EntityID = @EntityID AND
			EntityPropertyTypeID = -1 AND
			SelectYN <> 0

		SELECT
			@MasterDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@StartFiscalYear = ISNULL(@StartFiscalYear, S.StartYear)
		FROM
			[Source] S
			INNER JOIN [Model] M ON M.ModelID = S.ModelID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.InstanceID = @InstanceID AND A.VersionID = @VersionID AND A.SelectYN <> 0
		WHERE
			S.SourceTypeID = @SourceTypeID AND
			S.SelectYN <> 0

		CREATE TABLE #app_id
			(
			[app_id] [int],
			[app_code] [nvarchar](3) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = '
			INSERT INTO #app_id
				(
				[app_id],
				[app_code]
				)
			SELECT
				[app_id],
				[app_code]
			FROM
				' + @MasterDatabase + '.[dbo].[smapp]
			WHERE
				app_code IN (''AR'', ''AP'')'

		EXEC (@SQLStatement)

		SELECT 
			@App_id_AR = MAX(CASE WHEN app_code = 'AR' THEN app_id ELSE 0 END),
			@App_id_AP = MAX(CASE WHEN app_code = 'AP' THEN app_id ELSE 0 END)
		FROM
			#app_id

		SELECT @ENT_CYNI_B = [EntityPropertyValue] FROM [EntityPropertyValue] WHERE InstanceID = @InstanceID AND EntityID = @EntityID AND EntityPropertyTypeID = -4
		SELECT @ENT_CYNI_I = [EntityPropertyValue] FROM [EntityPropertyValue] WHERE InstanceID = @InstanceID AND EntityID = @EntityID AND EntityPropertyTypeID = -5
		SELECT @AccountCode = [SourceCode] FROM [Journal_SegmentNo] WHERE InstanceID = @InstanceID AND EntityID = @EntityID AND Book = @Book AND DimensionID = -1

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		IF @Debug <> 0
			SELECT 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceDatabase] = @SourceDatabase,
				[@Currency] = @Currency,
				[@MasterDatabase] = @MasterDatabase,
				[@App_id_AR] = @App_id_AR,
				[@App_id_AP] = @App_id_AP,
				[@ENT_CYNI_B] = @ENT_CYNI_B,
				[@ENT_CYNI_I] = @ENT_CYNI_I,
				[@JournalTable] = @JournalTable

	SET @Step = 'Create temp table #Segment'
		CREATE TABLE #Segment
			(
			SourceCode nvarchar(50),
			SegmentNo int,
			DimensionName nvarchar(50)
			)

	SET @Step = 'Fill temp table #Segment'
		INSERT INTO #Segment
			(
			SourceCode,
			SegmentNo,
			DimensionName
			)
		SELECT 
			JSN.SourceCode,
			JSN.SegmentNo,
			D.DimensionName
		FROM
			Journal_SegmentNo JSN
			LEFT JOIN Dimension D ON D.DimensionID = JSN.DimensionID
		WHERE
			JSN.InstanceID = @InstanceID AND
			JSN.EntityID = @EntityID AND
			JSN.Book = @Book

		IF @Debug <> 0 SELECT TempTable = '#Segment', * FROM #Segment

		WHILE @SegmentNo < 20
			BEGIN
				SET @SegmentNo = @SegmentNo + 1
				IF @SegmentNo = 0
					SELECT @SQLSegment = '[Account] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN SourceCode ELSE '''''' END) + ',' FROM #Segment
				ELSE
					SELECT @SQLSegment = @SQLSegment + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), @SegmentNo) + '] = ' + MAX(CASE WHEN SegmentNo = @SegmentNo THEN SourceCode ELSE '''''' END) + ',' FROM #Segment
			END

		IF @Debug <> 0 PRINT @SQLSegment

	SET @Step = 'Get Segment for Account'
		SELECT @AccountSegmentNo = LEFT(stuff(SourceCode, 1, patindex('%[0-9]%', SourceCode)-1, ''), 1) FROM #Segment WHERE SegmentNo = 0
		IF @Debug <> 0 SELECT AccountSegmentNo = @AccountSegmentNo

	SET @Step = 'Create and fill temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int,
			StartDate int, 
			EndDate int
			)

		IF @Debug <> 0 SELECT UserID = @UserID, InstanceID = @InstanceID, VersionID = @VersionID, EntityID = @EntityID, Book = @Book, StartFiscalYear = @StartFiscalYear, FiscalYear = @FiscalYear, FiscalPeriod = @FiscalPeriod

		EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriod = @FiscalPeriod, @JobID = @JobID

		IF @Debug <> 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth

		SELECT
			@MinYearMonth = MIN(YearMonth),
			@MaxYearMonth = MAX(YearMonth)
		FROM
			#FiscalPeriod

		IF @Debug <> 0 SELECT [@MinYearMonth] = @MinYearMonth, [@MaxYearMonth] = @MaxYearMonth

		CREATE TABLE #Period
			(
			FiscalPeriod int IDENTITY(1, 1),
			YearMonth int,
			MidDate date, 
			StartDate date, 
			EndDate date,
			StartDateInt int, 
			EndDateInt int
			)

		SET @SQLStatement = '
			INSERT INTO #Period
				(
				YearMonth,
				MidDate, 
				StartDate, 
				EndDate,
				StartDateInt, 
				EndDateInt
				)
			SELECT 
				YearMonth = CONVERT(nvarchar(6), CONVERT(datetime, (period_start_date + period_end_date) / 2 - 693596), 112),
				MidDate = CONVERT(date, CONVERT(datetime, (period_start_date + period_end_date) / 2 - 693596)), 
				StartDate = CONVERT(date, CONVERT(datetime, period_start_date - 693596)), 
				EndDate = CONVERT(date, CONVERT(datetime, period_end_date - 693596)),
				StartDateInt = period_start_date, 
				EndDateInt = period_end_date
			FROM
				 ' + @SourceDatabase + '.[dbo].[glprd]
			WHERE
				CONVERT(nvarchar(6), CONVERT(datetime, (period_start_date + period_end_date) / 2 - 693596), 112) BETWEEN ' + CONVERT(nvarchar(10), @MinYearMonth) + ' AND ' + CONVERT(nvarchar(10), @MaxYearMonth) + '
			ORDER BY
				period_type,
				period_start_date'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#Period', * FROM #Period

		INSERT INTO #FiscalPeriod
			(
			FiscalYear,
			FiscalPeriod,
			YearMonth
			)
		SELECT 
			FiscalYear = @FiscalYear,
			FiscalPeriod,
			YearMonth
		FROM
			#Period P
		WHERE
			@FiscalYear IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM #FiscalPeriod FP WHERE FP.FiscalPeriod = P.FiscalPeriod)

		UPDATE FP
		SET
			StartDate = P.StartDateInt, 
			EndDate = P.EndDateInt
		FROM
			#FiscalPeriod FP
			INNER JOIN #Period P ON P.YearMonth = FP.YearMonth

		IF @Debug <> 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY FiscalYear, FiscalPeriod

	SET @Step = 'Create temp table #Journal'
		IF OBJECT_ID(N'TempDB.dbo.#Journal', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Journal
					(
					[JobID] [int],
					[InstanceID] [int],
					[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [int],
					[FiscalPeriod] [int],
					[JournalSequence] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalNo] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalLine] [int],
					[YearMonth] [int],
					[TransactionTypeBM] [int],
					[BalanceYN] [bit],
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
					[JournalDate] [date],
					[TransactionDate] [date],
					[PostedDate] [date],
					[PostedStatus] [bit],
					[PostedBy] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Description_Head] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Currency_Book] [nchar](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Book] [float],
					[ValueCredit_Book] [float],
					[SourceModule] [nvarchar](20) COLLATE DATABASE_DEFAULT,
					[SourceModuleReference] [nvarchar](100) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Insert GL transactions into temp table #Journal'
		IF @SequenceBM & 1 > 0
			BEGIN
				SET @SQLStatement = '
			INSERT INTO #Journal
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
				[ValueCredit_Book],
				[SourceModule],
				[SourceModuleReference]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[Entity] = ''' + @Entity_MemberKey + ''',
				[Book] = ''' + @Book + ''',
				[FiscalYear] = FP.FiscalYear,
				[FiscalPeriod] = FP.FiscalPeriod,
				[JournalSequence] = H.[journal_type],
				[JournalNo] = F.[journal_ctrl_num],
				[JournalLine] = F.[sequence_id],
				[YearMonth] = FP.YearMonth,
				[TransactionTypeBM] = CASE WHEN F.' + @AccountCode + ' IN (''' + ISNULL(@ENT_CYNI_B, '0') + ''', ''' + ISNULL(@ENT_CYNI_I, '0') + ''') THEN 4 ELSE 1 END,
				[BalanceYN] = ISNULL(CASE WHEN GLS.account_type < 400 THEN 1 ELSE 0 END, 0),
				' + @SQLSegment + '
				[JournalDate] = CONVERT(datetime, H.date_entered - 693596),
				[TransactionDate] = CONVERT(datetime, H.date_applied - 693596),
				[PostedDate] = CASE WHEN F.[posted_flag] = 0 THEN NULL ELSE CONVERT(datetime, F.date_posted - 693596) END,
				[PostedStatus] = F.[posted_flag],
				[PostedBy] = H.[user_id],
				[Source] = ''ENT'',
				[Scenario] = ''ACTUAL'',
				[Description_Head] = H.[journal_description],
				[Description_Line] = F.[description],
				[Currency_Book] = ''' + @Currency + ''',
				[ValueDebit_Book] = ROUND(CASE WHEN F.[balance] > 0 THEN F.[balance] ELSE 0 END, 4),
				[ValueCredit_Book] = ROUND(CASE WHEN F.[balance] < 0 THEN -1 * F.[balance] ELSE 0 END, 4),				
				[SourceModule] = CASE H.app_id WHEN ' + CONVERT(nvarchar(10), @App_id_AR) + ' THEN ''AR'' WHEN ' + CONVERT(nvarchar(10), @App_id_AP) + ' THEN ''AP'' ELSE H.journal_type END,
				[SourceModuleReference] = CASE WHEN H.app_id IN (' + CONVERT(nvarchar(10), @App_id_AR) + ', ' + CONVERT(nvarchar(10), @App_id_AP) + ') THEN F.[document_1] ELSE '''' END
			FROM
				' + @SourceDatabase + '.[dbo].[gltrxdet] F
				INNER JOIN ' + @SourceDatabase + '.[dbo].[gltrx_all] H ON H.journal_ctrl_num = F.journal_ctrl_num
				INNER JOIN #FiscalPeriod FP ON H.date_applied BETWEEN FP.StartDate AND FP.EndDate
				LEFT JOIN ' + @SourceDatabase + '.[dbo].[glseg' + @AccountSegmentNo + '] GLS ON GLS.seg_code = F.seg' + @AccountSegmentNo + '_code
			WHERE
				ROUND(F.[balance], 4) <> 0.0'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Insert opening balances into temp table #Journal'
		IF @SequenceBM & 2 > 0
			BEGIN
				CREATE TABLE #PrevPeriod
					(
					PrevStartDate int,
					PrevEndDate int
					)

				CREATE TABLE #AccountDate
					(
					[account_code] varchar(32),
					[balance_date] int
					)

				DECLARE OpeningBalance_Cursor CURSOR FOR
					SELECT
						MinFiscalYear = FiscalYear,
						MinYearMonth = MIN(YearMonth),
						MinStartDate = MIN(StartDate),
						StartDate = CONVERT(date, CONVERT(datetime, MIN(StartDate) - 693596))
					FROM
						#FiscalPeriod
					GROUP BY
						FiscalYear

					OPEN OpeningBalance_Cursor
					FETCH NEXT FROM OpeningBalance_Cursor INTO @MinFiscalYear, @MinYearMonth, @MinStartDate, @StartDate

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @Debug <> 0
								SELECT
									JobID = @JobID, 
									ProcedureID = @ProcedureID,
									InstanceID = @InstanceID,
									Entity_MemberKey = @Entity_MemberKey,
									Book = @Book,
									MinFiscalYear = @MinFiscalYear,
									MinYearMonth = @MinYearMonth,
									SQLSegment = @SQLSegment,
									Currency = @Currency,
									SourceDatabase = @SourceDatabase,
									AccountSegmentNo = @AccountSegmentNo

							TRUNCATE TABLE #PrevPeriod

							SET @SQLStatement = '
								INSERT INTO #PrevPeriod
									(
									PrevStartDate,
									PrevEndDate
									)
								SELECT
									PrevStartDate = MAX(period_start_date),
									PrevEndDate = MAX(period_end_date)
								FROM
									' + @SourceDatabase + '.[dbo].[glprd] 
								WHERE
									period_type = 1003 AND
									period_end_date < ' + CONVERT(nvarchar(10), @MinStartDate)

							EXEC (@SQLStatement)

							SELECT
								@PrevStartDate = PrevStartDate,
								@PrevEndDate = PrevEndDate
							FROM
								#PrevPeriod

							TRUNCATE TABLE #AccountDate

							SET @SQLStatement = '
								INSERT INTO #AccountDate
									(
									[account_code],
									[balance_date]
									)
								SELECT 
									[account_code] = B.[account_code] COLLATE DATABASE_DEFAULT,
									[balance_date] = MAX(B.[balance_date])
								FROM
									' + @SourceDatabase + '.[dbo].[glbal] B
									INNER JOIN ' + @SourceDatabase + '.[dbo].[glseg' + @AccountSegmentNo + '] GLS ON GLS.seg_code = B.seg' + @AccountSegmentNo + '_code AND (GLS.[account_type] <= 399 OR GLS.[account_type] BETWEEN 590 AND 599)
								WHERE
									B.[balance_type] = 1 AND
									B.[currency_code] = ''' + @Currency + ''' AND
--									B.[balance_date] BETWEEN ' + CONVERT(nvarchar(10), @PrevStartDate) + ' AND ' + CONVERT(nvarchar(10), @PrevEndDate) + '
									B.[balance_date] <= ' + CONVERT(nvarchar(10), @PrevEndDate) + '
								GROUP BY
									B.[account_code]'

							EXEC (@SQLStatement)

							SET @SQLStatement = '
			INSERT INTO #Journal
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
				[FiscalYear] = ' + CONVERT(nvarchar(10), @MinFiscalYear) + ',
				[FiscalPeriod] = 0,
				[JournalSequence] = ''OB_ERP'',
				[JournalNo] = ''0'',
				[JournalLine] = 0,
				[YearMonth] = ' + CONVERT(nvarchar(10), @MinYearMonth) + ',
				[TransactionTypeBM] = 4,
				[BalanceYN] = 1,
				' + REPLACE(@SQLSegment, 'Reference_Code', '''''') + '
				[JournalDate] = ''' + CONVERT(nvarchar(10), @StartDate) + ''',
				[TransactionDate] = ''' + CONVERT(nvarchar(10), @StartDate) + ''',
				[PostedDate] = ''' + CONVERT(nvarchar(10), @StartDate) + ''',
				[PostedStatus] = 1,
				[PostedBy] = '''',
				[Source] = ''ENT'',
				[Scenario] = ''ACTUAL'',
				[Description_Head] = ''Opening Balance'',
				[Description_Line] = ''Opening Balance'',
				[Currency_Book] = ''' + @Currency + ''',
				[ValueDebit_Book] = ROUND(CASE WHEN F.[home_current_balance] > 0 THEN F.[home_current_balance] ELSE 0 END, 4),
				[ValueCredit_Book] = ROUND(CASE WHEN F.[home_current_balance] < 0 THEN -1 * F.[home_current_balance] ELSE 0 END, 4)
			FROM
				' + @SourceDatabase + '.[dbo].[glbal] F
				INNER JOIN #AccountDate AD ON AD.[account_code] = F.[account_code] COLLATE DATABASE_DEFAULT AND AD.[balance_date] BETWEEN F.[balance_date] AND F.[balance_until]
			WHERE
				F.[balance_type] = 1 AND
				F.[currency_code] = ''' + @Currency + ''' AND
				F.[account_code] NOT IN (''' + ISNULL(@ENT_CYNI_I, '0') + ''')'

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Selected = @Selected + @@ROWCOUNT

							FETCH NEXT FROM OpeningBalance_Cursor INTO @MinFiscalYear, @MinYearMonth, @MinStartDate, @StartDate
						END

				CLOSE OpeningBalance_Cursor
				DEALLOCATE OpeningBalance_Cursor	

				EXEC [spIU_DC_Journal_OpeningBalance] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Entity_MemberKey = @Entity_MemberKey, @Book = @Book, @FiscalYear = @FiscalYear, @SequenceBM = @SequenceBM, @JournalTable = @JournalTable, @JobID = @JobID, @Debug = @Debug
			END

	SET @Step = 'Insert Budget transactions into temp table #Journal'
		IF @SequenceBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
			INSERT INTO #Journal
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
				[ValueCredit_Book],
				[SourceModule],
				[SourceModuleReference]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[Entity] = ''' + @Entity_MemberKey + ''',
				[Book] = ''' + @Book + ''',
				[FiscalYear] = FP.FiscalYear,
				[FiscalPeriod] = FP.FiscalPeriod,
				[JournalSequence] = ''Budget'',
				[JournalNo] = '''',
				[JournalLine] = F.[sequence_id],
				[YearMonth] = FP.YearMonth,
				[TransactionTypeBM] = 1,
				[BalanceYN] = ISNULL(CASE WHEN GLS.account_type < 400 THEN 1 ELSE 0 END, 0),
				' + @SQLSegment + '
				[JournalDate] = CONVERT(datetime, F.period_end_date - 693596),
				[TransactionDate] = CONVERT(datetime, F.period_end_date - 693596),
				[PostedDate] = CONVERT(datetime, F.period_end_date - 693596),
				[PostedStatus] = 1,
				[PostedBy] = '''',
				[Source] = ''ENT'',
				[Scenario] = F.[budget_code],
				[Description_Head] = ''Budget'',
				[Description_Line] = ''Budget'',
				[Currency_Book] = ''' + @Currency + ''',
				[ValueDebit_Book] = ROUND(CASE WHEN F.[net_change] > 0 THEN F.[net_change] ELSE 0 END, 4),
				[ValueCredit_Book] = ROUND(CASE WHEN F.[net_change] < 0 THEN -1 * F.[net_change] ELSE 0 END, 4),				
				[SourceModule] = '''',
				[SourceModuleReference] = ''''
			FROM
				' + @SourceDatabase + '.[dbo].[glbuddet] F
				INNER JOIN #FiscalPeriod FP ON F.period_end_date BETWEEN FP.StartDate AND FP.EndDate
				LEFT JOIN ' + @SourceDatabase + '.[dbo].[glseg' + @AccountSegmentNo + '] GLS ON GLS.seg_code = F.seg' + @AccountSegmentNo + '_code
			WHERE
				ROUND(F.[net_change], 4) <> 0.0'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Insert income summary into temp table #Journal'
		IF @SequenceBM & 8 > 0
			BEGIN
				IF @ENT_CYNI_B IS NULL OR @ENT_CYNI_I IS NULL OR @AccountCode IS NULL GOTO MissingParam

				SET @SQLStatement = '
			INSERT INTO #Journal
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
				[ValueCredit_Book],
				[SourceModule],
				[SourceModuleReference]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[Entity] = ''' + @Entity_MemberKey + ''',
				[Book] = ''' + @Book + ''',
				[FiscalYear] = FP.FiscalYear,
				[FiscalPeriod] = FP.FiscalPeriod,
				[JournalSequence] = ''CYNI'',
				[JournalNo] = ''0'',
				[JournalLine] = 0,
				[YearMonth] = FP.YearMonth,
				[TransactionTypeBM] = 1,
				[BalanceYN] = ISNULL(CASE WHEN F.[account_code] = ''' + @ENT_CYNI_B + ''' THEN 1 ELSE 0 END, 0),
				' + REPLACE(@SQLSegment, 'Reference_Code', '''''') + '
				[JournalDate] = CONVERT(datetime, F.balance_date - 693596),
				[TransactionDate] = CONVERT(datetime, F.balance_date - 693596),
				[PostedDate] = CONVERT(datetime, F.balance_date - 693596),
				[PostedStatus] = 1,
				[PostedBy] = ''ETL'',
				[Source] = ''ENT'',
				[Scenario] = ''ACTUAL'',
				[Description_Head] = '''',
				[Description_Line] = '''',
				[Currency_Book] = ''' + @Currency + ''',
				[ValueDebit_Book] = ROUND(CASE WHEN F.[net_change] > 0 THEN F.[net_change] ELSE 0 END, 4),
				[ValueCredit_Book] = ROUND(CASE WHEN F.[net_change] < 0 THEN -1 * F.[net_change] ELSE 0 END, 4),
				[SourceModule] = '''',
				[SourceModuleReference] = ''''
			FROM
				' + @SourceDatabase + '.[dbo].[glbal] F
				INNER JOIN #FiscalPeriod FP ON F.balance_date BETWEEN FP.StartDate AND FP.EndDate
				LEFT JOIN ' + @SourceDatabase + '.[dbo].[glseg' + @AccountSegmentNo + '] GLS ON GLS.seg_code = F.seg' + @AccountSegmentNo + '_code
			WHERE
				F.[account_code] IN (''' + @ENT_CYNI_B + ''', ''' + @ENT_CYNI_I + ''')'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT

				MissingParam:
			END


----------
	SET @Step = 'Return rows'
		IF @CalledYN = 0
			BEGIN
				SELECT * FROM #Journal ORDER BY [InstanceID], [Entity], [Book], [FiscalYear], [FiscalPeriod], [JournalSequence], [JournalNo], [JournalLine]
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #app_id
		DROP TABLE #Segment
		DROP TABLE #FiscalPeriod
		DROP TABLE #Period
		IF @CalledYN = 0 DROP TABLE #Journal

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
