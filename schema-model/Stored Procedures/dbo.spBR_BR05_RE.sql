SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_RE]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@FiscalYear int = NULL,
	@ConsolidationGroup nvarchar(50) = NULL,
	@JournalTable nvarchar(100) = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000824,
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
EXEC [spBR_BR05_RE] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2016, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 0
EXEC [spBR_BR05_RE] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2017, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 0
EXEC [spBR_BR05_RE] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2018, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 0
EXEC [spBR_BR05_RE] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2019, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 3
EXEC [spBR_BR05_RE] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2020, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 3
EXEC [spBR_BR05_RE] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2021, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 0
EXEC [spBR_BR05_RE] @UserID=-10, @InstanceID=527, @VersionID=1055, @FiscalYear = 2022, @ConsolidationGroup = 'Group', @JournalTable = '[pcETL_E2IP].[dbo].[Journal]', @JobID = 9999999, @DebugBM = 3

EXEC [spBR_BR05_RE] @GetVersion = 1
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

		IF @Version = '2.1.1.2177' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2179' SET @Description = 'Made generic.'
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

	SET @Step = 'Create temp table(s)'
		CREATE TABLE #Journal_Cons
			(
			[Entity] [nvarchar](50),
			[Book] [nvarchar](50),
			[TransactionTypeBM] int,
			[JournalSequence] [nvarchar](50),
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
			[Description_Head] [nvarchar](255) DEFAULT '',
			[Description_Line] [nvarchar](255) DEFAULT '',
			[Currency_Group] nchar(3),
			[Opening_Group] float DEFAULT 0
			)

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

	SET @Step = 'Fill temp table #Journal_Cons'
		SET @SQLStatement = '
			INSERT INTO #Journal_Cons
				(
				[Entity],
				[Book],
				[TransactionTypeBM],
				[JournalSequence],
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
				[Description_Head],
				[Description_Line],
				[Currency_Group],
				[Opening_Group]
				)
			SELECT 
				M.[Entity], M.[Book], M.[TransactionTypeBM], [JournalSequence], M.[Account], 
				M.[Segment01], M.[Segment02], M.[Segment03], M.[Segment04], M.[Segment05], M.[Segment06], M.[Segment07], M.[Segment08], M.[Segment09], M.[Segment10], M.[Segment11], M.[Segment12], M.[Segment13], M.[Segment14], M.[Segment15], M.[Segment16], M.[Segment17], M.[Segment18], M.[Segment19], M.[Segment20],
				[Description_Head],
				[Description_Line],
				[Currency_Group]=M.[Currency_Group],
				[Opening_Group]=ROUND(ISNULL(M.Value_Group,0),2)
			FROM'
		SET @SQLStatement = @SQLStatement + '
					(
					SELECT
						J.[Entity], J.[Book], J.[Currency_Group],
						[TransactionTypeBM] = 4,
						[JournalSequence] = ''OP_OCI'',
						[Account] = MAX(EB.[Account_RE]),
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
						[Description_Head] = ''Carry forward of OCI Group Retained earnings.'',
						[Description_Line] = ''@Account_RE = '' + MAX(EB.[Account_RE]) + '', @Account_OCI IN ('' + MAX(EB.[Account_OCI]) + '')'',
						[Value_Group] = SUM([ValueDebit_Group] - [ValueCredit_Group])
					FROM
						' + @JournalTable + ' J
						INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[BookTypeBM] & 3 = 3 AND EB.[Account_RE] IS NOT NULL AND EB.[Account_OCI] IS NOT NULL AND EB.[SelectYN] <> 0
						INNER JOIN #Account_OCI OCI ON OCI.Entity = J.[Entity] AND OCI.[Account_OCI] = J.[Account]
					WHERE
						J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND 
						J.[Scenario] = ''' + @Scenario + ''' AND
						J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''' AND
						J.[TransactionTypeBM] = 8 AND
						J.[BalanceYN] <> 0 AND
						J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' - 1 AND
						J.[FiscalPeriod] = 12 AND
						J.[JournalSequence] <> ''ELIM''
					GROUP BY
						J.[Entity], J.[Book], J.[Currency_Group],
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
						CASE ISNULL(J.[Segment20], ''NONE'') WHEN ''NONE'' THEN '''' ELSE J.[Segment20] END'
				
				SET @SQLStatement = @SQLStatement + '

					UNION
					SELECT
						J.[Entity], J.[Book], J.[Currency_Group],
						[TransactionTypeBM] = 4,
						[JournalSequence] = ''OP_Allocation'',
						[Account] = MAX(EB.[Account_RE]),
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
						[Description_Head] = ''Carry forward of Group Retained earnings comparable with functional amount.'',
						[Description_Line] = ''@Account_RE = '' + MAX(EB.[Account_RE]) + '', @Account_OCI IN ('' + MAX(EB.[Account_OCI]) + '')'',
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
						(J.[Account] = EB.[Account_RE] OR J.[Account] = ''CYNI_B'')
					GROUP BY
						J.[Entity], J.[Book], J.[Currency_Group],
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
					) M
			WHERE
				ROUND(ISNULL(M.Value_Group,0),2) <> 0'

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
			SELECT TempTable = '#Journal_Cons_1', * FROM #Journal_Cons ORDER BY [TransactionTypeBM] DESC, [Entity], [Book], [Account], [Segment01], [Segment02], [Segment03], [Segment04], [Segment05], [Segment06], [Segment07], [Segment08], [Segment09], [Segment10], [Segment11], [Segment12], [Segment13], [Segment14], [Segment15], [Segment16], [Segment17], [Segment18], [Segment19], [Segment20]

	SET @Step = 'Delete existing rows from [Journal]'
		SET @SQLStatement = '
			DELETE J FROM ' + @JournalTable + ' J WHERE J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND J.[Source] = ''RE'' AND [FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND J.[Scenario] = ''' + @Scenario + ''' AND J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
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
				)'

		SET @SQLStatement = @SQLStatement + '
			SELECT
				[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[Entity],
				[Book],
				[FiscalYear] = FP.[FiscalYear],
				[FiscalPeriod] = FP.[FiscalPeriod],
				[JournalSequence] = JC.[JournalSequence],
				[JournalNo] = 0,
				[JournalLine] = 0,
				[YearMonth] = FP.[YearMonth],
				[TransactionTypeBM] = JC.[TransactionTypeBM],
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
				[Source] = ''RE'',
				[Flow] = ''OP_RE'',
				[ConsolidationGroup] = ''' + @ConsolidationGroup + ''',
				[InterCompanyEntity] = NULL,
				[Scenario] = ''' + @Scenario + ''',
				[Customer] = NULL,
				[Supplier] = NULL,
				[Description_Head] = JC.[Description_Head],
				[Description_Line] = JC.[Description_Line],
				[Currency_Book] = NULL,
				[ValueDebit_Book] = 0,
				[ValueCredit_Book] = 0,
				[Currency_Group] = JC.[Currency_Group],  --Hardcoded
				[ValueDebit_Group] = CASE WHEN [Opening_Group] > 0 THEN [Opening_Group] ELSE 0 END,
				[ValueCredit_Group] = CASE WHEN [Opening_Group] < 0 THEN -1 * [Opening_Group] ELSE 0 END,
				[Currency_Transaction] = '''',
				[ValueDebit_Transaction] = 0,
				[ValueCredit_Transaction] = 0,
				[SourceModule] = ''RetainedEarnings'',
				[SourceModuleReference] = NULL,
				[SourceCounter] = NULL,
				[SourceGUID] = NULL,
				[Inserted] = GetDate(),
				[InsertedBy] = suser_name()
			FROM
				#Journal_Cons JC
				INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND FP.[FiscalPeriod] = 1'

				--INNER JOIN (
				--	SELECT [TransactionTypeBM] = 4, [FiscalPeriod] = 1 
				--	--UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 1 UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 2 UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 3 UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 4 
				--	--UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 5 UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 6 UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 7 UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 8
				--	--UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 9 UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 10 UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 11 UNION SELECT [TransactionTypeBM] = 8, [FiscalPeriod] = 12
				--	) FP ON FP.[TransactionTypeBM]=JC.[TransactionTypeBM]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

--Deactivated 20220225 JaWo
	--SET @Step = 'Úpdate FACT table'
	--	EXEC pcINTEGRATOR..[spIU_DC_Financials_Callisto] @UserID=-10, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM=0, @ConsolidationGroupYN=1, @ConsolidationStep=2, @FieldTypeBM=4, @FiscalYear=@FiscalYear, @ConsolidationGroup=@ConsolidationGroup, @JobID=@JobID

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
