SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_OBAdj_20221028]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@FiscalYear int = NULL,
	@ConsolidationGroup nvarchar(50) = NULL,
	@GroupCurrency nchar(3) = NULL,
	@JournalTable nvarchar(100) = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
	@Update_DC_FinancialsYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000794,
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
EXEC [spBR_BR05_OBAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2016, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 0
EXEC [spBR_BR05_OBAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2017, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 0
EXEC [spBR_BR05_OBAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2018, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 0
EXEC [spBR_BR05_OBAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2019, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 3
EXEC [spBR_BR05_OBAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2020, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 3
EXEC [spBR_BR05_OBAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2021, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 0
EXEC [spBR_BR05_OBAdj] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2022, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 3

EXEC [spBR_BR05_OBAdj] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@CalledYN bit = 1,

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
	@ToBeChanged nvarchar(255) = 'Closing FiscalPeriod now has 12 as assumption. Not correct in all cases. YearMonth has hardcoded relation to FiscalPeriod.',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2187'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Adjust opening balance to align with closing (carry forward) by setting Flow=OB_ADJ.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2172' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2173' SET @Description = 'Include CTA_RR_Historic and CTA_RR_Inventory in retained earnings.'
		IF @Version = '2.1.1.2177' SET @Description = 'Include CTA_Gains in retained earnings. Fixed bug with NULL in joins.'
		IF @Version = '2.1.2.2179' SET @Description = 'Exclude CYNI_B_REVAL. Made generic.'
		IF @Version = '2.1.2.2180' SET @Description = 'Made even more generic.'
		IF @Version = '2.1.2.2187' SET @Description = 'Handle multiple Scenarios.'

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

		IF @JournalTable IS NULL EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@JournalTable] = @JournalTable

	SET @Step = 'Create temp table(s)'
		IF OBJECT_ID(N'TempDB.dbo.#EntityBook', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #EntityBook
					(
					[EntityID] int,
					[MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[BookTypeBM] int,
					[Currency] nchar(3),
					[OwnershipConsolidation] float,
					[ConsolidationMethodBM] int,
					[Account_RE] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Account_OCI] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[SelectYN] bit
					)
			END

		IF OBJECT_ID(N'TempDB.dbo.#Account_OCI', N'U') IS NULL
			BEGIN
				CREATE TABLE #Account_OCI
					(
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Account_OCI] nvarchar(100) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Create temp table(s)'
		CREATE TABLE #Journal_Cons
			(
			[Entity] [nvarchar](50),
			[Book] [nvarchar](50),
			[Account] [nvarchar](50),
			[Segment01] [nvarchar](50) DEFAULT '',
			[Segment02] [nvarchar](50) DEFAULT '',
			[Segment03] [nvarchar](50) DEFAULT '',
			[Segment04] [nvarchar](50) DEFAULT '',
			[Segment05] [nvarchar](50) DEFAULT '',
			[Segment06] [nvarchar](50) DEFAULT '',
			[Segment07] [nvarchar](50) DEFAULT '',
			[Segment08] [nvarchar](50) DEFAULT '',
			[Segment09] [nvarchar](50) DEFAULT '',
			[Segment10] [nvarchar](50) DEFAULT '',
			[Segment11] [nvarchar](50) DEFAULT '',
			[Segment12] [nvarchar](50) DEFAULT '',
			[Segment13] [nvarchar](50) DEFAULT '',
			[Segment14] [nvarchar](50) DEFAULT '',
			[Segment15] [nvarchar](50) DEFAULT '',
			[Segment16] [nvarchar](50) DEFAULT '',
			[Segment17] [nvarchar](50) DEFAULT '',
			[Segment18] [nvarchar](50) DEFAULT '',
			[Segment19] [nvarchar](50) DEFAULT '',
			[Segment20] [nvarchar](50) DEFAULT '',
			[Currency_Book] nchar(3),
			[Closing_Book] float DEFAULT 0, 
			[Opening_Book] float DEFAULT 0,  
			[Adjustment_Book] float DEFAULT 0,
			[Currency_Group] nchar(3),
			[Closing_Group] float DEFAULT 0, 
			[Opening_Group] float DEFAULT 0,  
			[Adjustment_Group] float DEFAULT 0
			)

	SET @Step = 'Fill temp table #Journal_Cons'
		SET @SQLStatement = '
			INSERT INTO #Journal_Cons
				(
				[Entity],
				[Book],
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
				[Currency_Book],
				[Closing_Book], 
				[Opening_Book],  
				[Adjustment_Book],
				[Currency_Group],
				[Closing_Group], 
				[Opening_Group],  
				[Adjustment_Group]
				)
			SELECT 
				M.[Entity], M.[Book], M.[Account], 
				M.[Segment01], M.[Segment02], M.[Segment03], M.[Segment04], M.[Segment05], M.[Segment06], M.[Segment07], M.[Segment08], M.[Segment09], M.[Segment10], M.[Segment11], M.[Segment12], M.[Segment13], M.[Segment14], M.[Segment15], M.[Segment16], M.[Segment17], M.[Segment18], M.[Segment19], M.[Segment20],
				[Currency_Book]=M.[Currency_Book],
				[Closing_Book]=ROUND(ISNULL(C.Value_Book,0),2), 
				[Opening_Book]=ROUND(ISNULL(O.Value_Book,0),2),  
				[Adjustment_Book]=ROUND(ISNULL(C.Value_Book, 0)-ISNULL(O.Value_Book, 0), 2),
				[Currency_Group]=M.[Currency_Group],
				[Closing_Group]=ROUND(ISNULL(C.Value_Group,0),2), 
				[Opening_Group]=ROUND(ISNULL(O.Value_Group,0),2),  
				[Adjustment_Group]=ROUND(ISNULL(C.Value_Group, 0)-ISNULL(O.Value_Group, 0), 2)
			FROM'
		SET @SQLStatement = @SQLStatement + '
				(
				SELECT
					[Entity] = J.[Entity],
					[Book] = J.[Book],
					[Account] = J.[Account],
					[Segment01] = CASE ISNULL(J.[Segment01], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment01] END, 
					[Segment02] = CASE ISNULL(J.[Segment02], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment02] END,
					[Segment03] = CASE ISNULL(J.[Segment03], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment03] END,
					[Segment04] = CASE ISNULL(J.[Segment04], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment04] END,
					[Segment05] = CASE ISNULL(J.[Segment05], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment05] END,
					[Segment06] = CASE ISNULL(J.[Segment06], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment06] END,
					[Segment07] = CASE ISNULL(J.[Segment07], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment07] END,
					[Segment08] = CASE ISNULL(J.[Segment08], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment08] END,
					[Segment09] = CASE ISNULL(J.[Segment09], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment09] END,
					[Segment10] = CASE ISNULL(J.[Segment10], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment10] END,
					[Segment11] = CASE ISNULL(J.[Segment11], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment11] END,
					[Segment12] = CASE ISNULL(J.[Segment12], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment12] END,
					[Segment13] = CASE ISNULL(J.[Segment13], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment13] END,
					[Segment14] = CASE ISNULL(J.[Segment14], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment14] END,
					[Segment15] = CASE ISNULL(J.[Segment15], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment15] END,
					[Segment16] = CASE ISNULL(J.[Segment16], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment16] END,
					[Segment17] = CASE ISNULL(J.[Segment17], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment17] END,
					[Segment18] = CASE ISNULL(J.[Segment18], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment18] END,
					[Segment19] = CASE ISNULL(J.[Segment19], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment19] END,
					[Segment20] = CASE ISNULL(J.[Segment20], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment20] END,
					[Currency_Book] = MAX([Currency_Book]), [Currency_Group] = MAX([Currency_Group])
				FROM
					' + @JournalTable + ' J
					INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[BookTypeBM] & 3 = 3 AND EB.[Account_RE] IS NOT NULL AND EB.[Account_OCI] IS NOT NULL AND EB.[SelectYN] <> 0
				WHERE 
					J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND 
					J.[Scenario] = ''' + @Scenario + ''' AND
					J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''' AND
					J.[TransactionTypeBM] = 8 AND
					J.[BalanceYN] <> 0 AND
					(
					(J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' - 1 AND J.[FiscalPeriod] = 12 AND J.[JournalSequence] <> ''ELIM'') OR 
					(J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND J.[FiscalPeriod] = 1 AND LEFT(J.[Flow],3)=''OP_''AND (J.[Flow] <> ''OP_HistRate'') OR (J.[Account] = EB.[Account_RE]) AND J.[JournalSequence] = ''JRNL'')
					) AND
					J.[Account] NOT IN (''PYNI_B'', ''CYNI_B'', ''CTA_RR_Historic'', ''CTA_RR_Inventory'', ''CYNI_B_REVAL'') AND
					J.[Account] <> EB.[Account_RE] AND
					NOT EXISTS (SELECT 1 FROM #Account_OCI OCI WHERE OCI.[Entity] = J.[Entity] AND OCI.[Account_OCI] = J.[Account])
				GROUP BY
					J.[Entity], J.[Book],
					J.[Account],
					CASE ISNULL(J.[Segment01], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment01] END, 
					CASE ISNULL(J.[Segment02], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment02] END,
					CASE ISNULL(J.[Segment03], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment03] END,
					CASE ISNULL(J.[Segment04], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment04] END,
					CASE ISNULL(J.[Segment05], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment05] END,
					CASE ISNULL(J.[Segment06], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment06] END,
					CASE ISNULL(J.[Segment07], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment07] END,
					CASE ISNULL(J.[Segment08], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment08] END,
					CASE ISNULL(J.[Segment09], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment09] END,
					CASE ISNULL(J.[Segment10], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment10] END,
					CASE ISNULL(J.[Segment11], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment11] END,
					CASE ISNULL(J.[Segment12], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment12] END,
					CASE ISNULL(J.[Segment13], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment13] END,
					CASE ISNULL(J.[Segment14], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment14] END,
					CASE ISNULL(J.[Segment15], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment15] END,
					CASE ISNULL(J.[Segment16], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment16] END,
					CASE ISNULL(J.[Segment17], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment17] END,
					CASE ISNULL(J.[Segment18], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment18] END,
					CASE ISNULL(J.[Segment19], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment19] END,
					CASE ISNULL(J.[Segment20], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment20] END					
				) M'
		SET @SQLStatement = @SQLStatement + '
				LEFT JOIN
					(
					SELECT
						[Entity] = J.[Entity],
						[Book] = J.[Book],
						[Account] = J.[Account], 
						[Segment01] = CASE ISNULL(J.[Segment01], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment01] END, 
						[Segment02] = CASE ISNULL(J.[Segment02], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment02] END,
						[Segment03] = CASE ISNULL(J.[Segment03], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment03] END,
						[Segment04] = CASE ISNULL(J.[Segment04], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment04] END,
						[Segment05] = CASE ISNULL(J.[Segment05], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment05] END,
						[Segment06] = CASE ISNULL(J.[Segment06], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment06] END,
						[Segment07] = CASE ISNULL(J.[Segment07], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment07] END,
						[Segment08] = CASE ISNULL(J.[Segment08], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment08] END,
						[Segment09] = CASE ISNULL(J.[Segment09], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment09] END,
						[Segment10] = CASE ISNULL(J.[Segment10], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment10] END,
						[Segment11] = CASE ISNULL(J.[Segment11], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment11] END,
						[Segment12] = CASE ISNULL(J.[Segment12], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment12] END,
						[Segment13] = CASE ISNULL(J.[Segment13], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment13] END,
						[Segment14] = CASE ISNULL(J.[Segment14], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment14] END,
						[Segment15] = CASE ISNULL(J.[Segment15], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment15] END,
						[Segment16] = CASE ISNULL(J.[Segment16], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment16] END,
						[Segment17] = CASE ISNULL(J.[Segment17], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment17] END,
						[Segment18] = CASE ISNULL(J.[Segment18], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment18] END,
						[Segment19] = CASE ISNULL(J.[Segment19], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment19] END,
						[Segment20] = CASE ISNULL(J.[Segment20], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment20] END,
						[Value_Book] = SUM([ValueDebit_Book] - [ValueCredit_Book]),
						[Value_Group] = SUM([ValueDebit_Group] - [ValueCredit_Group])
					FROM
						' + @JournalTable + ' J
						INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[BookTypeBM] & 3 = 3 AND EB.[Account_RE] IS NOT NULL AND EB.[Account_OCI] IS NOT NULL AND EB.[SelectYN] <> 0
					WHERE
						J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND 
						J.[Scenario] = ''' + @Scenario + ''' AND
						J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''' AND
						J.[TransactionTypeBM] = 8 AND
						J.[BalanceYN] <> 0 AND
						J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' - 1 AND
						J.[FiscalPeriod] = 12 AND
						J.[JournalSequence] <> ''ELIM'' AND
						J.[Account] NOT IN (''PYNI_B'', ''CYNI_B'', ''CTA_RR_Historic'', ''CTA_RR_Inventory'', ''CYNI_B_REVAL'') AND
						J.[Account] <> EB.[Account_RE] AND
						NOT EXISTS (SELECT 1 FROM #Account_OCI OCI WHERE OCI.[Entity] = J.[Entity] AND OCI.[Account_OCI] = J.[Account])
					GROUP BY
						J.[Entity],
						J.[Book], 
						J.[Account], 
						CASE ISNULL(J.[Segment01], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment01] END, 
						CASE ISNULL(J.[Segment02], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment02] END,
						CASE ISNULL(J.[Segment03], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment03] END,
						CASE ISNULL(J.[Segment04], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment04] END,
						CASE ISNULL(J.[Segment05], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment05] END,
						CASE ISNULL(J.[Segment06], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment06] END,
						CASE ISNULL(J.[Segment07], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment07] END,
						CASE ISNULL(J.[Segment08], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment08] END,
						CASE ISNULL(J.[Segment09], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment09] END,
						CASE ISNULL(J.[Segment10], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment10] END,
						CASE ISNULL(J.[Segment11], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment11] END,
						CASE ISNULL(J.[Segment12], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment12] END,
						CASE ISNULL(J.[Segment13], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment13] END,
						CASE ISNULL(J.[Segment14], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment14] END,
						CASE ISNULL(J.[Segment15], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment15] END,
						CASE ISNULL(J.[Segment16], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment16] END,
						CASE ISNULL(J.[Segment17], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment17] END,
						CASE ISNULL(J.[Segment18], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment18] END,
						CASE ISNULL(J.[Segment19], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment19] END,
						CASE ISNULL(J.[Segment20], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment20] END	
					) C ON 
						C.[Entity]=M.[Entity] AND C.[Book]=M.[Book] AND C.[Account]=M.[Account] AND C.[Segment01]=M.[Segment01] AND C.[Segment02]=M.[Segment02] AND C.[Segment03]=M.[Segment03] AND C.[Segment04]=M.[Segment04] AND C.[Segment05]=M.[Segment05] AND C.[Segment06]=M.[Segment06] AND C.[Segment07]=M.[Segment07] AND C.[Segment08]=M.[Segment08] AND C.[Segment09]=M.[Segment09] AND C.[Segment10]=M.[Segment10] AND C.[Segment11]=M.[Segment11] AND C.[Segment12]=M.[Segment12] AND C.[Segment13]=M.[Segment13] AND C.[Segment14]=M.[Segment14] AND C.[Segment15]=M.[Segment15] AND C.[Segment16]=M.[Segment16] AND C.[Segment17]=M.[Segment17] AND C.[Segment18]=M.[Segment18] AND C.[Segment19]=M.[Segment19] AND C.[Segment20]=M.[Segment20]'
		SET @SQLStatement = @SQLStatement + '
				LEFT JOIN
					(
					SELECT
						[Entity] = J.[Entity],
						[Book] = J.[Book],
						[Account] = J.[Account], 
						[Segment01] = CASE ISNULL(J.[Segment01], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment01] END, 
						[Segment02] = CASE ISNULL(J.[Segment02], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment02] END,
						[Segment03] = CASE ISNULL(J.[Segment03], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment03] END,
						[Segment04] = CASE ISNULL(J.[Segment04], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment04] END,
						[Segment05] = CASE ISNULL(J.[Segment05], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment05] END,
						[Segment06] = CASE ISNULL(J.[Segment06], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment06] END,
						[Segment07] = CASE ISNULL(J.[Segment07], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment07] END,
						[Segment08] = CASE ISNULL(J.[Segment08], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment08] END,
						[Segment09] = CASE ISNULL(J.[Segment09], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment09] END,
						[Segment10] = CASE ISNULL(J.[Segment10], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment10] END,
						[Segment11] = CASE ISNULL(J.[Segment11], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment11] END,
						[Segment12] = CASE ISNULL(J.[Segment12], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment12] END,
						[Segment13] = CASE ISNULL(J.[Segment13], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment13] END,
						[Segment14] = CASE ISNULL(J.[Segment14], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment14] END,
						[Segment15] = CASE ISNULL(J.[Segment15], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment15] END,
						[Segment16] = CASE ISNULL(J.[Segment16], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment16] END,
						[Segment17] = CASE ISNULL(J.[Segment17], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment17] END,
						[Segment18] = CASE ISNULL(J.[Segment18], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment18] END,
						[Segment19] = CASE ISNULL(J.[Segment19], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment19] END,
						[Segment20] = CASE ISNULL(J.[Segment20], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment20] END,
						[Value_Book] = SUM([ValueDebit_Book] - [ValueCredit_Book]),
						[Value_Group] = SUM([ValueDebit_Group] - [ValueCredit_Group])
					FROM
						' + @JournalTable + ' J
						INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[BookTypeBM] & 3 = 3 AND EB.[Account_RE] IS NOT NULL AND EB.[Account_OCI] IS NOT NULL AND EB.[SelectYN] <> 0
					WHERE
						J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND 
						J.[Scenario] = ''' + @Scenario + ''' AND
						J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''' AND
						LEFT(J.[Flow],3)=''OP_'' AND
						J.[Flow] NOT IN (''OP_HistRate'', ''OP_AdjSrc'') AND
						J.[TransactionTypeBM] = 8 AND
						J.[BalanceYN] <> 0 AND
						J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
						J.[FiscalPeriod] = 1 AND
						J.[JournalSequence] = ''JRNL'' AND
						J.[Account] NOT IN (''PYNI_B'', ''CYNI_B'', ''CTA_RR_Historic'', ''CTA_RR_Inventory'', ''CYNI_B_REVAL'') AND
						J.[Account] <> EB.[Account_RE] AND
						NOT EXISTS (SELECT 1 FROM #Account_OCI OCI WHERE OCI.[Entity] = J.[Entity] AND OCI.[Account_OCI] = J.[Account])
					GROUP BY 
						J.[Entity],
						J.[Book],
						J.[Account], 
						CASE ISNULL(J.[Segment01], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment01] END, 
						CASE ISNULL(J.[Segment02], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment02] END,
						CASE ISNULL(J.[Segment03], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment03] END,
						CASE ISNULL(J.[Segment04], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment04] END,
						CASE ISNULL(J.[Segment05], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment05] END,
						CASE ISNULL(J.[Segment06], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment06] END,
						CASE ISNULL(J.[Segment07], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment07] END,
						CASE ISNULL(J.[Segment08], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment08] END,
						CASE ISNULL(J.[Segment09], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment09] END,
						CASE ISNULL(J.[Segment10], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment10] END,
						CASE ISNULL(J.[Segment11], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment11] END,
						CASE ISNULL(J.[Segment12], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment12] END,
						CASE ISNULL(J.[Segment13], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment13] END,
						CASE ISNULL(J.[Segment14], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment14] END,
						CASE ISNULL(J.[Segment15], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment15] END,
						CASE ISNULL(J.[Segment16], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment16] END,
						CASE ISNULL(J.[Segment17], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment17] END,
						CASE ISNULL(J.[Segment18], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment18] END,
						CASE ISNULL(J.[Segment19], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment19] END,
						CASE ISNULL(J.[Segment20], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment20] END	
					) O ON 
						O.[Entity]=M.[Entity] AND O.[Book]=M.[Book] AND O.[Account]=M.[Account] AND O.[Segment01]=M.[Segment01] AND O.[Segment02]=M.[Segment02] AND O.[Segment03]=M.[Segment03] AND O.[Segment04]=M.[Segment04] AND O.[Segment05]=M.[Segment05] AND O.[Segment06]=M.[Segment06] AND O.[Segment07]=M.[Segment07] AND O.[Segment08]=M.[Segment08] AND O.[Segment09]=M.[Segment09] AND O.[Segment10]=M.[Segment10] AND O.[Segment11]=M.[Segment11] AND O.[Segment12]=M.[Segment12] AND O.[Segment13]=M.[Segment13] AND O.[Segment14]=M.[Segment14] AND O.[Segment15]=M.[Segment15] AND O.[Segment16]=M.[Segment16] AND O.[Segment17]=M.[Segment17] AND O.[Segment18]=M.[Segment18] AND O.[Segment19]=M.[Segment19] AND O.[Segment20]=M.[Segment20]
			WHERE
				ROUND(ISNULL(C.Value_Book, 0)-ISNULL(O.Value_Book, 0), 2) <> 0 OR
				ROUND(ISNULL(C.Value_Group, 0)-ISNULL(O.Value_Group, 0), 2) <> 0'

		IF @DebugBM & 2 > 0
			BEGIN
				IF LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Fill Temptable #Journal_Cons'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Fill Temptable #Journal_Cons', 
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement
			END

		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0
			SELECT TempTable = '#Journal_Cons_1', * FROM #Journal_Cons ORDER BY [Entity], [Book], [Account], [Segment01], [Segment02], [Segment03], [Segment04], [Segment05], [Segment06], [Segment07], [Segment08], [Segment09], [Segment10], [Segment11], [Segment12], [Segment13], [Segment14], [Segment15], [Segment16], [Segment17], [Segment18], [Segment19], [Segment20]

	SET @Step = 'Delete existing rows from [Journal]'
		SET @SQLStatement = '
			DELETE J FROM ' + @JournalTable + ' J WHERE J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND J.[Source] = ''CADJ'' AND J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND J.[Scenario] = ''' + @Scenario + ''' AND J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''''

		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Insert new rows into [Journal]'
		SET @SQLStatement = '
			INSERT INTO ' + @JournalTable + '
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
				[Flow],
				[ConsolidationGroup],
				[InterCompanyEntity],
				[Scenario],
				[Customer],
				[Supplier],
				[Description_Head],
				[Description_Line],
				[Currency_Book],
				[ValueDebit_Book],
				[ValueCredit_Book],
				[Currency_Group],
				[ValueDebit_Group],
				[ValueCredit_Group],
				[Currency_Transaction],
				[ValueDebit_Transaction],
				[ValueCredit_Transaction],
				[SourceModule],
				[SourceModuleReference],
				[SourceCounter],
				[SourceGUID],
				[Inserted],
				[InsertedBy]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[Entity],
				[Book],
				[FiscalYear] = FP.[FiscalYear],
				[FiscalPeriod] = FP.[FiscalPeriod],
				[JournalSequence] = ''OB_CADJ'',
				[JournalNo] = 0,
				[JournalLine] = 0,
				[YearMonth] = FP.[YearMonth],
				[TransactionTypeBM] = 8,
				[BalanceYN] = 1,
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
				[JournalDate] = CONVERT(nvarchar(15), FP.[YearMonth]) + ''01'',
				[TransactionDate] = CONVERT(nvarchar(15), FP.[YearMonth]) + ''01'',
				[PostedDate] = GetDate(),
				[PostedStatus] = 1,
				[PostedBy] = ''System'',
				[Source] = ''CADJ'',
				[Flow] = ''OP_Adjust'',
				[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
				[InterCompanyEntity] = NULL,
				[Scenario] = ''' + @Scenario + ''', --Hardcoded
				[Customer] = NULL,
				[Supplier] = NULL,
				[Description_Head] = ''Carry forward adjustment of consolidation opening balances'',
				[Description_Line] = ''Closing previous year = '' + CONVERT(nvarchar(15), [Closing_Group]) + '', Opening before adjustment = '' + CONVERT(nvarchar(15), [Opening_Group]),
				[Currency_Book] = JC.[Currency_Book],
				[ValueDebit_Book] = CASE WHEN [Adjustment_Book] > 0 THEN [Adjustment_Book] ELSE 0 END,
				[ValueCredit_Book] = CASE WHEN [Adjustment_Book] < 0 THEN -1 * [Adjustment_Book] ELSE 0 END,
				[Currency_Group] = ''' + @GroupCurrency + ''',
				[ValueDebit_Group] = CASE WHEN [Adjustment_Group] > 0 THEN [Adjustment_Group] ELSE 0 END,
				[ValueCredit_Group] = CASE WHEN [Adjustment_Group] < 0 THEN -1 * [Adjustment_Group] ELSE 0 END,
				[Currency_Transaction] = '''',
				[ValueDebit_Transaction] = 0,
				[ValueCredit_Transaction] = 0,
				[SourceModule] = ''ConsolidationJournal'',
				[SourceModuleReference] = NULL,
				[SourceCounter] = NULL,
				[SourceGUID] = NULL,
				[Inserted] = GetDate(),
				[InsertedBy] = suser_name()
			FROM
				#Journal_Cons JC
				INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND FP.[FiscalPeriod] BETWEEN 1 AND 12'
				
				--(SELECT FiscalPeriod = 1 UNION SELECT FiscalPeriod = 2 UNION SELECT FiscalPeriod = 3 UNION SELECT FiscalPeriod = 4 UNION SELECT FiscalPeriod = 5 UNION SELECT FiscalPeriod = 6
				--UNION SELECT FiscalPeriod = 7 UNION SELECT FiscalPeriod = 8 UNION SELECT FiscalPeriod = 9 UNION SELECT FiscalPeriod = 10 UNION SELECT FiscalPeriod = 11 UNION SELECT FiscalPeriod = 12) FP ON 1=1'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Úpdate FACT table'
		IF @Update_DC_FinancialsYN <> 0
			EXEC pcINTEGRATOR..[spIU_DC_Financials_Callisto] @UserID=-10, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM=0, @ConsolidationGroupYN=1, @ConsolidationStep=2, @FieldTypeBM=4, @FiscalYear=@FiscalYear, @ConsolidationGroup=@ConsolidationGroup, @JobID=@JobID

	SET @Step = 'Drop temp tables'
		DROP TABLE #Journal_Cons
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #EntityBook
				DROP TABLE #Account_OCI
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
