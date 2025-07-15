SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_Journal_OpeningBalance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 1, --1=generate new CheckSumStatus count, 2=get CheckSumStatus count, 4=Details (of @CheckSumStatusBM) 
	@CheckSumValue int = NULL OUT,
	@CheckSumStatus10 int = NULL OUT,
	@CheckSumStatus20 int = NULL OUT,
	@CheckSumStatus30 int = NULL OUT,
	@CheckSumStatus40 int = NULL OUT,
	@CheckSumStatusBM int = 7, -- 1=Open, 2=Investigating, 4=Ignored, 8=Solved

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000787,
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
EXEC spCheckSum_Journal_OpeningBalance @UserID=-10,@InstanceID=561,@VersionID=1071,@ResultTypeBM=4,@CheckSumStatusBM=7,@Debug=1

DECLARE @CheckSumValue int, @CheckSumStatus10 int, @CheckSumStatus20 int, @CheckSumStatus30 int, @CheckSumStatus40 int
EXEC [spCheckSum_Journal_OpeningBalance] @UserID=-10, @InstanceID=476, @VersionID=1029, @Debug=0,
@CheckSumValue = @CheckSumValue OUT, @CheckSumStatus10=@CheckSumStatus10 OUT, @CheckSumStatus20=@CheckSumStatus20 OUT,
@CheckSumStatus30=@CheckSumStatus30 OUT, @CheckSumStatus40=@CheckSumStatus40 OUT
SELECT [@CheckSumValue] = @CheckSumValue, [@CheckSumStatus10] = @CheckSumStatus10, [@CheckSumStatus20] = @CheckSumStatus20, 
[@CheckSumStatus30] = @CheckSumStatus30, [@CheckSumStatus40] = @CheckSumStatus40

DECLARE @CheckSumValue int
EXEC [spCheckSum_Journal_OpeningBalance] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @CheckSumValue = @CheckSumValue OUT, @Debug=1
SELECT [@CheckSumValue] = @CheckSumValue

EXEC [spCheckSum_Journal_OpeningBalance] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(max),
	@CalledYN bit = 1,
	@JournalTable nvarchar(100),
	@BusinessProcess_LeafLevelFilter nvarchar(4000),
	@CallistoDatabase nvarchar(100),
	@GroupExistYN bit,
	@ReturnVariable int,

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
	@ToBeChanged nvarchar(255),
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Checks OpeningBalances from source system and Journal adjustments',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2172' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2173' SET @Description = 'Removed filters for @Step = Insert into JobLog.'
		IF @Version = '2.1.1.2174' SET @Description = 'Added [CheckSumStatusBM] in @ResultTypeBM = 4.'

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
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		EXEC spGet_LeafLevelFilter @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DatabaseName=@CallistoDatabase, @DimensionName='BusinessProcess', @Filter= 'Consolidated', @StorageTypeBM=4, @LeafLevelFilter=@BusinessProcess_LeafLevelFilter OUT

	SET @Step = 'Calculate OpeningBalance from source and Journal'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				CREATE TABLE #wrk_CheckSum_Journal_OpeningBalance
					(
					[InstanceID] int,
					[VersionID] int,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] int,
					[FiscalPeriod] int,
					[Journal_Amount] float,
					[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
					)

				SET @SQLStatement = '
					INSERT INTO #wrk_CheckSum_Journal_OpeningBalance
						(
						[InstanceID],
						[VersionID],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod],
						[Journal_Amount],
						[Source]
						)
					SELECT 
						[InstanceID],
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod] = MAX(FiscalPeriod),
						[Journal_Amount] = ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 2),
						[Source] = ''OB to be used''
					FROM
						' + @JournalTable + '
					WHERE
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						[TransactionTypeBM] & 3 > 0 AND
						[BalanceYN] <> 0 AND
						[FiscalPeriod] = 0 AND
						[Scenario] = ''ACTUAL'' AND
						[ConsolidationGroup] IS NULL
					GROUP BY
						[InstanceID],
						[Entity],
						[Book],
						[FiscalYear]
					HAVING
						ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 2) <> 0.0
					UNION
					SELECT 
						[InstanceID],
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod] = MAX(FiscalPeriod),
						[Journal_Amount] = ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 2),
						[Source] = ''OB to be used''
					FROM
						' + @JournalTable + '
					WHERE
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						[TransactionTypeBM] & 4 > 0 AND
						[BalanceYN] <> 0 AND
						[FiscalPeriod] = 0 AND
						[Scenario] = ''ACTUAL'' AND
						[ConsolidationGroup] IS NULL
					GROUP BY
						[InstanceID],
						[Entity],
						[Book],
						[FiscalYear]
					HAVING
						ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 2) <> 0.0
					OPTION (MAXDOP 1)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				--'Fill table wrk_CheckSum_FACT_Financials_Balance'
				--DELETE pcINTEGRATOR_Log.dbo.wrk_CheckSum_FACT_Financials_Balance
				--WHERE
				--	[InstanceID] = @InstanceID AND
				--	[VersionID] = @VersionID

				--SET @Deleted = @Deleted + @@ROWCOUNT

				--INSERT INTO pcINTEGRATOR_Log..wrk_CheckSum_FACT_Financials_Balance
				--	(
				--	[InstanceID],
				--	[VersionID],
				--	[Entity],
				--	[Book],
				--	[Scenario],
				--	[FiscalYear],
				--	[Account],
				--	[FromYearMonth],
				--	[ToYearMonth],
				--	[Currency_Book],
				--	[Journal_Amount],
				--	[FACT_Amount],
				--	Diff
				--	)
				--SELECT
				--	[InstanceID],
				--	[VersionID],
				--	[Entity],
				--	[Book],
				--	[Scenario],
				--	[FiscalYear],
				--	[Account],
				--	[FromYearMonth],
				--	[ToYearMonth],
				--	[Currency_Book],
				--	[Journal_Amount],
				--	[FACT_Amount],
				--	Diff = Journal_Amount - FACT_Amount
				--FROM 
				--	#wrk_CheckSum_Journal_OpeningBalance J 
				--WHERE
				--	ROUND((Journal_Amount - FACT_Amount), 1) <> 0.0

				--SET @Inserted = @Inserted + @@ROWCOUNT

				DROP TABLE #wrk_CheckSum_Journal_OpeningBalance
/*
	SET @Step = 'Set CheckSumRowLogID'
					INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
						(
						[CheckSumRowKey],
						[InstanceID],
						[VersionID],
						[ProcedureID]
						)
					SELECT
						[CheckSumRowKey] = CFFB.[Entity] + '_' + CFFB.[Book] + '_' + CFFB.[Scenario] + '_' + CFFB.[Account] + '_' + CONVERT(nvarchar(20), CFFB.[ToYearMonth]) + '_' + CFFB.[Currency_Book],
						[InstanceID] = CFFB.[InstanceID],
						[VersionID] = CFFB.[VersionID],
						[ProcedureID] = @ProcedureID
					FROM
						[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_FACT_Financials_Balance] CFFB
					WHERE
						CFFB.[InstanceID] = @InstanceID AND
						CFFB.[VersionID] = @VersionID AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = CFFB.[Entity] + '_' + CFFB.[Book] + '_' + CFFB.[Scenario] + '_' + CFFB.[Account] + '_' + CONVERT(nvarchar(20), CFFB.[ToYearMonth]) + '_' + CFFB.[Currency_Book] AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = CFFB.[InstanceID] AND CSRL.[VersionID] = CFFB.[VersionID] AND CSRL.[CheckSumStatusBM] & 12 = 0)

					UPDATE CFFB
					SET
						CheckSumRowLogID = CSRL.CheckSumRowLogID
					FROM
						[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_FACT_Financials_Balance] CFFB
						INNER JOIN [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL ON CSRL.[CheckSumRowKey] = CFFB.[Entity] + '_' + CFFB.[Book] + '_' + CFFB.[Scenario] + '_' + CFFB.[Account] + '_' + CONVERT(nvarchar(20), CFFB.[ToYearMonth]) + '_' + CFFB.[Currency_Book] AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = CFFB.[InstanceID] AND CSRL.[VersionID] = CFFB.[VersionID]

					UPDATE CSRL
					SET
						--[Solved] = GetDate(),
						--[CheckSumStatusID] = 40,
						[CheckSumStatusBM] = 8,
						[UserID] = @UserID,
						[Comment] = 'Resolved automatically.',
						[Updated] = GetDate()
					FROM
						[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
					WHERE
						CSRL.[InstanceID] = @InstanceID AND
						CSRL.[VersionID] = @VersionID AND
						CSRL.[ProcedureID] = @ProcedureID AND
						--CSRL.[Solved] IS NULL AND
						--CSRL.[CheckSumStatusID] <> 40 AND
						CSRL.[CheckSumStatusBM] & 8 = 0 AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_FACT_Financials_Balance] CFFB WHERE CFFB.[InstanceID] = CSRL.[InstanceID] AND CFFB.[VersionID] = CSRL.[VersionID] AND CFFB.[CheckSumRowLogID] = CSRL.[CheckSumRowLogID])

					SET @Updated = @Updated + @@ROWCOUNT
*/
			END
/*
	SET @Step = 'Calculate @CheckSumValue'
		IF @ResultTypeBM & 3 > 0
			BEGIN
				SELECT
					@CheckSumValue = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 3 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus10 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 1 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus20 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 2 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus30 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 4 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus40 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 8 > 0 THEN 1 ELSE 0 END), 0)
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
					LEFT JOIN #wrk_CheckSum_Journal_OpeningBalance J ON J.InstanceID = CSRL.InstanceID AND J.VersionID = CSRL.VersionID AND J.CheckSumRowLogID = CSRL.CheckSumRowLogID 
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND
					CSRL.[ProcedureID] = @ProcedureID

				IF @Debug <> 0 
					SELECT 
						[@CheckSumValue] = @CheckSumValue, 
						[@CheckSumStatus10] = @CheckSumStatus10, 
						[@CheckSumStatus20] = @CheckSumStatus20,
						[@CheckSumStatus30] = @CheckSumStatus30,
						[@CheckSumStatus40] = @CheckSumStatus40
			END

	SET @Step = 'Get detailed info'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					[CheckSumRowLogID] = CSRL.[CheckSumRowLogID],
					[FirstOccurrence] = CSRL.[Inserted],
					[CheckSumStatusBM] = CSS.[CheckSumStatusBM],
					[CurrentStatus] = CSS.[CheckSumStatusName],
					[Comment] = CSRL.[Comment],
					[Entity] = CFFB.[Entity],
					[Book] = CFFB.[Book],
					[Scenario] = CFFB.[Scenario],
					[FiscalYear] = CFFB.[FiscalYear],
					[Account] = CFFB.[Account],
					[FromYearMonth] = CFFB.[FromYearMonth],
					[ToYearMonth] = CFFB.[ToYearMonth],
					[Currency_Book] = CFFB.[Currency_Book],
					[Journal_Amount] = CFFB.[Journal_Amount],
					[FACT_Amount] = CFFB.[FACT_Amount],
					[Diff] = CFFB.[Diff],
					[LastCheck] = CFFB.[Inserted],
					[AuthenticatedUserID] = CSRL.UserID,
					[AuthenticatedUserName] = U.UserNameDisplay,
					[AuthenticatedUserOrganization] = I.InstanceName,
					[Updated] = CSRL.[Updated]
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL 
					LEFT JOIN pcINTEGRATOR_Log..wrk_CheckSum_FACT_Financials_Balance CFFB ON CFFB.CheckSumRowLogID = CSRL.CheckSumRowLogID
					INNER JOIN CheckSumStatus CSS ON CSS.CheckSumStatusBM = CSRL.CheckSumStatusBM
					LEFT JOIN [pcINTEGRATOR].[dbo].[User] U ON U.UserID = CSRL.UserID
					LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID 
				WHERE
					CSRL.InstanceID = @InstanceID AND
					CSRL.VersionID = @VersionID AND   
                    CSRL.ProcedureID = @ProcedureID AND 
					CSRL.CheckSumStatusBM & @CheckSumStatusBM > 0
				ORDER BY
					CFFB.[Inserted] DESC,
					CFFB.FiscalYear,
					CFFB.Entity,
					CFFB.Book,
					CFFB.Scenario,
					CFFB.Currency_Book,
					CFFB.Account,
					CFFB.ToYearMonth
		
				SET @Selected = @Selected + @@ROWCOUNT
			END
*/
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
