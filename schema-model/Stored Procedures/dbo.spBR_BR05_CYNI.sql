SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_CYNI]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ConsolidationGroup nvarchar(50) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000792,
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
EXEC [spBR_BR05_CYNI] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @ConsolidationGroup = 'Group', @DebugBM = 3

EXEC [spBR_BR05_CYNI] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,

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
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert CYNI transactions in Group Currency into Journal.',
			@MandatoryParameter = 'ConsolidationGroup' --Without @, separated by |

		IF @Version = '2.1.1.2172' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2179' SET @Description = 'Made generic.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

--SET NOCOUNT ON

BEGIN TRY
--Test purpose
-- SET @Debug = 1

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

	SET @Step = 'CREATE TABLE #JournalBase'
		IF OBJECT_ID(N'TempDB.dbo.#JournalBase', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0
				CREATE TABLE #JournalBase
					(
					[Counter] int IDENTITY(1,1),
					[ReferenceNo] int,
					[Rule_ConsolidationID] int,
					[Rule_FXID] int,
					[ConsolidationMethodBM] int,
					[InstanceID] int,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT, 
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] int,
					[FiscalPeriod] int,
					[JournalSequence] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[JournalNo] int,
					[JournalLine] int,
					[YearMonth] int,
					[TransactionTypeBM] int,
					[BalanceYN] bit,
					[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment01] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment02] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment03] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment04] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment05] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment06] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment07] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment08] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment09] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment10] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment11] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment12] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment13] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment14] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment15] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment16] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment17] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment18] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment19] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Segment20] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[JournalDate] date,
					[TransactionDate] date,
					[PostedDate] date,
					[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Flow] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[ConsolidationGroup] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[InterCompanyEntity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Customer] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Supplier] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Description_Head] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[Description_Line] nvarchar(255) COLLATE DATABASE_DEFAULT,
					[Currency_Book] nchar(3) COLLATE DATABASE_DEFAULT,
					[Value_Book] float,
					[Currency_Group] nchar(3) COLLATE DATABASE_DEFAULT,
					[Value_Group] float,
					[Currency_Transaction] nchar(3) COLLATE DATABASE_DEFAULT,
					[Value_Transaction] float,
					[SourceModule] nvarchar(20) COLLATE DATABASE_DEFAULT,
					[SourceModuleReference] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Inserted] datetime DEFAULT getdate()
					)
			END

		IF @DebugBM & 32 > 0
			BEGIN
				IF OBJECT_ID(N'pcINTEGRATOR_Log.dbo.tmp_JournalBase', N'U') IS NOT NULL
					DROP TABLE pcINTEGRATOR_Log.dbo.tmp_JournalBase
				SELECT * INTO pcINTEGRATOR_Log.dbo.tmp_JournalBase FROM #JournalBase
			END

	SET @Step = 'Insert rows into #JB_CYNI'
		IF @Debug <> 0 SELECT TempTable='#JournalBase', * FROM #JournalBase ORDER BY FiscalYear, FiscalPeriod, Account

		SELECT
			[Entity], 
			[Book],
			[JournalSequence],
			[Source],
			[FiscalYear],
			[FiscalPeriod],
			[YearMonth],
			[Scenario],
			[Currency_Book],
			[Value_Book] = ROUND(SUM([Value_Book]), 4),
			[Currency_Group],
			[Value_Group] = ROUND(SUM([Value_Group]), 4)
		INTO
			#JB_CYNI
		FROM
			#JournalBase
		WHERE
			[ConsolidationGroup] = @ConsolidationGroup AND
			[Value_Group] IS NOT NULL AND
			[Account] NOT IN ('CYNI_I', 'CYNI_B', 'AXYZ_NI') AND
			[JournalSequence] NOT IN ('G_URPA') AND
			[BalanceYN] = 0
		GROUP BY
			[Entity], 
			[Book],
			[JournalSequence],
			[Source],
			[FiscalYear],
			[FiscalPeriod],
			[YearMonth],
			[Scenario],
			[Currency_Book],
			[Currency_Group]
		HAVING
			ROUND(SUM([Value_Book]), 4) <> 0.0 OR
			ROUND(SUM([Value_Group]), 4) <> 0.0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#JB_CYNI', * FROM #JB_CYNI ORDER BY [Entity],[Book],[FiscalYear],[FiscalPeriod],[YearMonth],[JournalSequence],[Source],[Scenario],[Currency_Group]

	SET @Step = 'Insert rows into #JournalBase'
		INSERT INTO #JournalBase
			(
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
			[Value_Book],
			[Currency_Group],
			[Value_Group],
			[SourceModule],
			[SourceModuleReference]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[Entity] = JB.[Entity], 
			[Book] = JB.[Book],
			[FiscalYear] = JB.[FiscalYear],
			[FiscalPeriod] = JB.[FiscalPeriod],
			[JournalSequence] = 'CYNI',
			[JournalNo] = 0,
			[JournalLine] = 0,
			[YearMonth] = JB.[YearMonth],
			[TransactionTypeBM] = 32,
			[BalanceYN] = CASE A.Account WHEN 'CYNI_I' THEN 0 WHEN 'CYNI_B' THEN 1 END,
			[Account] = A.[Account],
			[Segment01] = '',
			[Segment02] = '',
			[Segment03] = '',
			[Segment04] = '',
			[Segment05] = '',
			[Segment06] = '',
			[Segment07] = '',
			[Segment08] = '',
			[Segment09] = '',
			[Segment10] = '',
			[Segment11] = '',
			[Segment12] = '',
			[Segment13] = '',
			[Segment14] = '',
			[Segment15] = '',
			[Segment16] = '',
			[Segment17] = '',
			[Segment18] = '',
			[Segment19] = '',
			[Segment20] = '',
			[JournalDate] = DATEADD(day, -1, DATEADD(month, 1, CONVERT(datetime, CONVERT(nvarchar(10), JB.[YearMonth]) + '01', 112))),
			[TransactionDate] = DATEADD(day, -1, DATEADD(month, 1, CONVERT(datetime, CONVERT(nvarchar(10), JB.[YearMonth]) + '01', 112))),
			[PostedDate] = GetDate(),
			[Source] = JB.[Source],
			[Flow] = 'Result',
			[ConsolidationGroup] = @ConsolidationGroup,
			[InterCompanyEntity] = '',
			[Scenario] = JB.[Scenario],
			[Customer] = '',
			[Supplier] = '',
			[Description_Head] = 'Current Year Net Income',
			[Description_Line] = 'Current Year Net Income',
			[Currency_Book] = JB.[Currency_Book],
			[Value_Book] = CASE WHEN A.Account = 'CYNI_I' THEN -1.0 ELSE 1.0 END * [Value_Book],
			[Currency_Group] = JB.[Currency_Group],
			[Value_Group] = CASE WHEN A.Account = 'CYNI_I' THEN -1.0 ELSE 1.0 END * [Value_Group],
			[SourceModule] = 'BR',
			[SourceModuleReference] = ''
		FROM
			#JB_CYNI JB
			INNER JOIN (SELECT Account = 'CYNI_I' UNION SELECT Account = 'CYNI_B') A ON 1 = 1

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
		DROP TABLE #JB_CYNI

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
