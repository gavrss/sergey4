SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_RemoveDuplicate]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000873,
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
EXEC [spIU_DC_Journal_RemoveDuplicate] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spIU_DC_Journal_RemoveDuplicate] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables

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
	@Version nvarchar(50) = '2.1.2.2197'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Remove duplicates in temp table #Journal',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2197' SET @Description = 'Procedure created.'

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

	SET @Step = 'Count rows before'		
		IF @DebugBM & 2 > 0 SELECT RowsBeforeDeletion = COUNT(1) FROM #Journal

	SET @Step = 'Create temp table #Dupl'
		SELECT 
			[SourceCounter],
			NoOfRows = COUNT(1)
		INTO
			#Dupl
		FROM
			#Journal
		WHERE
			[SourceCounter] IS NOT NULL
		GROUP BY
			[SourceCounter]
		HAVING
			COUNT(1) > 1

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Create temp table #Journal_Distinct'
		SELECT
			[JobID] = MAX([J].[JobID]),
			[InstanceID] = MAX([J].[InstanceID]),
			[Entity] = MAX([J].[Entity]),
			[Book] = MAX([J].[Book]),
			[FiscalYear] = MAX([J].[FiscalYear]),
			[FiscalPeriod] = MAX([J].[FiscalPeriod]),
			[JournalSequence] = MAX([J].[JournalSequence]),
			[JournalNo] = MAX([J].[JournalNo]),
			[JournalLine] = MAX([J].[JournalLine]),
			[YearMonth] = MAX([J].[YearMonth]),
			[TransactionTypeBM] = MAX([J].[TransactionTypeBM]),
			[BalanceYN] = MAX(CONVERT(int, [J].[BalanceYN])),
			[Account] = MAX([J].[Account]),
			[Segment01] = MAX([J].[Segment01]),
			[Segment02] = MAX([J].[Segment02]),
			[Segment03] = MAX([J].[Segment03]),
			[Segment04] = MAX([J].[Segment04]),
			[Segment05] = MAX([J].[Segment05]),
			[Segment06] = MAX([J].[Segment06]),
			[Segment07] = MAX([J].[Segment07]),
			[Segment08] = MAX([J].[Segment08]),
			[Segment09] = MAX([J].[Segment09]),
			[Segment10] = MAX([J].[Segment10]),
			[Segment11] = MAX([J].[Segment11]),
			[Segment12] = MAX([J].[Segment12]),
			[Segment13] = MAX([J].[Segment13]),
			[Segment14] = MAX([J].[Segment14]),
			[Segment15] = MAX([J].[Segment15]),
			[Segment16] = MAX([J].[Segment16]),
			[Segment17] = MAX([J].[Segment17]),
			[Segment18] = MAX([J].[Segment18]),
			[Segment19] = MAX([J].[Segment19]),
			[Segment20] = MAX([J].[Segment20]),
			[JournalDate] = MAX([J].[JournalDate]),
			[TransactionDate] = MAX([J].[TransactionDate]),
			[PostedDate] = MAX([J].[PostedDate]),
			[PostedStatus] = MAX(CONVERT(int, [J].[PostedStatus])),
			[PostedBy] = MAX([J].[PostedBy]),
			[Source] = MAX([J].[Source]),
			[Scenario] = MAX([J].[Scenario]),
			[Customer] = MAX([J].[Customer]),
			[Supplier] = MAX([J].[Supplier]),
			[Description_Head] = MAX([J].[Description_Head]),
			[Description_Line] = MAX([J].[Description_Line]),
			[Currency_Book] = MAX([J].[Currency_Book]),
			[ValueDebit_Book] = MAX([J].[ValueDebit_Book]),
			[ValueCredit_Book] = MAX([J].[ValueCredit_Book]),
			[Currency_Group] = MAX([J].[Currency_Group]),
			[ValueDebit_Group] = MAX([J].[ValueDebit_Group]),
			[ValueCredit_Group] = MAX([J].[ValueCredit_Group]),
			[Currency_Transaction] = MAX([J].[Currency_Transaction]),
			[ValueDebit_Transaction] = MAX([J].[ValueDebit_Transaction]),
			[ValueCredit_Transaction] = MAX([J].[ValueCredit_Transaction]),
			[SourceModule] = MAX([J].[SourceModule]),
			[SourceModuleReference] = MAX([J].[SourceModuleReference]),
			[SourceCounter] = [J].[SourceCounter],
			[SourceGUID] = MAX([J].[SourceGUID])
		INTO
			#Journal_Distinct
		FROM
			#Journal J
			INNER JOIN #Dupl D ON D.[SourceCounter] = [J].[SourceCounter]
		GROUP BY
			[J].[SourceCounter]

		IF @DebugBM & 8 > 0 SELECT TempTable = '#Journal_Distinct', * FROM #Journal_Distinct

	SET @Step = 'Delete duplicates from #Journal'
		DELETE J
		FROM
			#Journal J
			INNER JOIN #Dupl D ON D.[SourceCounter] = J.[SourceCounter]

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Insert distinct rows into #Journal from #Journal_Distinct'
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
			[SourceGUID]
			)
		SELECT
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
			[SourceGUID]
		FROM
			#Journal_Distinct

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Count rows after'		
		IF @DebugBM & 2 > 0 SELECT [RowsAfterDeletion] = COUNT(1) FROM #Journal

	SET @Step = 'Drop temp tables'	
		DROP TABLE #Dupl
		DROP TABLE #Journal_Distinct

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
