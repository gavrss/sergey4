SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_FACT_Financials_Balance]
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
	@ProcedureID int = 880000453,
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
EXEC spCheckSum_FACT_Financials_Balance @UserID = -10, @InstanceID = 476, @VersionID = 1029, @ResultTypeBM = 4, @CheckSumStatusBM = 7, @Debug=1

EXEC [spCheckSum_FACT_Financials_Balance] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = , @Debug=1
EXEC [spCheckSum_FACT_Financials_Balance] @UserID=-10, @InstanceID=478, @VersionID=1030, @ResultTypeBM = 1, @Debug=1

DECLARE @CheckSumValue int, @CheckSumStatus10 int, @CheckSumStatus20 int, @CheckSumStatus30 int, @CheckSumStatus40 int
EXEC [spCheckSum_FACT_Financials_Balance] @UserID=-10, @InstanceID=476, @VersionID=1029, @Debug=0,
@CheckSumValue = @CheckSumValue OUT, @CheckSumStatus10=@CheckSumStatus10 OUT, @CheckSumStatus20=@CheckSumStatus20 OUT,
@CheckSumStatus30=@CheckSumStatus30 OUT, @CheckSumStatus40=@CheckSumStatus40 OUT
SELECT [@CheckSumValue] = @CheckSumValue, [@CheckSumStatus10] = @CheckSumStatus10, [@CheckSumStatus20] = @CheckSumStatus20, 
[@CheckSumStatus30] = @CheckSumStatus30, [@CheckSumStatus40] = @CheckSumStatus40

EXEC [spCheckSum_FACT_Financials_Balance] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM = 3, @Debug=1
EXEC [spCheckSum_FACT_Financials_Balance] @UserID=-10, @InstanceID=413, @VersionID=1008, @ResultTypeBM = 1, @Debug=1
EXEC [spCheckSum_FACT_Financials_Balance] @UserID=-10, @InstanceID=413, @VersionID=1008, @ResultTypeBM = 2, @Debug=1
EXEC [spCheckSum_FACT_Financials_Balance] @UserID=-10, @InstanceID=413, @VersionID=1008, @ResultTypeBM = 3, @Debug=1

EXEC [spCheckSum_FACT_Financials_Balance] @UserID=-10, @InstanceID=454, @VersionID=1021, @ResultTypeBM = 3

DECLARE @CheckSumValue int
EXEC [spCheckSum_FACT_Financials_Balance] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @CheckSumValue = @CheckSumValue OUT, @Debug=1
SELECT [@CheckSumValue] = @CheckSumValue

EXEC [spCheckSum_FACT_Financials_Balance] @GetVersion = 1
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Compare balances between Journal and FACT_Financials',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2165' SET @Description = 'Removed hard coded call.'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle [Group]. Exclude CheckSumStatusID IN (30, 40) in CheckSumValue count.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added parameters @CheckSumStatus10, @CheckSumStatus20, @CheckSumStatus30, @CheckSumStatus40, @CheckSumStatusBM.'
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

	SET @Step = 'Check if [Group] exists'
		SET @SQLStatement = '
		SELECT 
			@InternalVariable = COUNT(1) 
		FROM 
			' + @CallistoDatabase + '.sys.tables t
			INNER JOIN ' + @CallistoDatabase + '.sys.columns c ON c.object_id = t.object_id AND c.name = ''Group_MemberId''
			WHERE t.name = ''FACT_Financials_default_partition''
		OPTION (MAXDOP 1)'

		EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ReturnVariable OUT

		SELECT @GroupExistYN = @ReturnVariable
		IF @Debug <> 0 SELECT [@GroupExistYN] = @GroupExistYN

	SET @Step = 'Calculate wrk_CheckSum_FACT_Financials_Balance and Get CheckSumValue'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				CREATE TABLE #Journal_Bal
					(
					[InstanceID] int,
					[VersionID] int,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] int,
					[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
					FromYearMonth int,
					ToYearMonth int,
					[Currency_Book] nchar(3),
					[Journal_Amount] float,
					[FACT_Amount] float
					)

				CREATE TABLE #FACT_Financials_Bal
					(
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
					ToYearMonth int,
					[Currency_Book] nchar(3),
					[FACT_Amount] float
					)

				SET @SQLStatement = '
					INSERT INTO #Journal_Bal
						(
						[InstanceID],
						[VersionID],
						[Entity],
						[Book],
						[Scenario],
						[FiscalYear],
						[Account],
						FromYearMonth,
						ToYearMonth,
						[Currency_Book],
						[Journal_Amount],
						[FACT_Amount]
						)
					SELECT 
						[InstanceID],
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[Entity],
						[Book],
						[Scenario],
						[FiscalYear],
						[Account],
						FromYearMonth = MIN([YearMonth]),
						ToYearMonth = MAX([YearMonth]),
						[Currency_Book],
						[Journal_Amount] = ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 2),
						[FACT_Amount] = CONVERT(float, 0.0)
					FROM
						' + @JournalTable + '
					WHERE
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						[TransactionTypeBM] & 3 > 0 AND
						[BalanceYN] <> 0 AND
						[ConsolidationGroup] IS NULL
					GROUP BY
						[InstanceID],
						[Entity],
						[Book],
						[Scenario],
						[FiscalYear],
						[Account],
						[Currency_Book]
					HAVING
						ROUND(SUM([ValueDebit_Book] - [ValueCredit_Book]), 2) <> 0.0
					OPTION (MAXDOP 1)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @SQLStatement = '
					INSERT INTO #FACT_Financials_Bal
						(
						[Entity],
						[Book],
						[Scenario],
						[Account],
						ToYearMonth,
						[Currency_Book],
						[FACT_Amount]
						)
					SELECT
						[Entity] = J.Entity,
						[Book] = J.Book,
						[Scenario] = J.Scenario,
						[Account] = J.Account,
						ToYearMonth = J.ToYearMonth,
						[Currency_Book] = J.Currency_Book,
						[FACT_Amount] = SUM(F.Financials_Value)
					FROM
						#Journal_Bal J
						INNER JOIN Entity E ON E.InstanceID = J.InstanceID AND E.VersionID = J.VersionID AND E.MemberKey = J.Entity
						INNER JOIN Entity_Book EB ON EB.EntityID = E.EntityID AND EB.Book = J.Book AND EB.BookTypeBM & 1 > 0
						INNER JOIN ' + @CallistoDatabase + '..FACT_Financials_View F ON
							F.Entity = J.Entity + CASE WHEN EB.BookTypeBM & 2 > 0 THEN '''' ELSE ''_'' + J.Book END AND
							F.Account = J.Account AND
							F.Scenario = J.Scenario AND
							F.[Time] = CONVERT(nvarchar(15), J.ToYearMonth) AND
							F.Currency = J.Currency_Book AND
							F.BusinessProcess IN (' + @BusinessProcess_LeafLevelFilter + ') AND
							F.BusinessRule = ''NONE''
					' + CASE WHEN @GroupExistYN = 0 THEN '' ELSE + '
					WHERE
						[Group] = ''NONE''' END + '
					GROUP BY
						J.Entity,
						J.Book,
						J.Scenario,
						J.Account,
						J.ToYearMonth,
						J.Currency_Book
					OPTION (MAXDOP 1)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				UPDATE J
				SET
					[FACT_Amount] = sub.[FACT_Amount]
				FROM
					#Journal_Bal J
					INNER JOIN #FACT_Financials_Bal sub ON
						sub.[Entity] = J.Entity AND
						sub.[Book] = J.Book AND
						sub.[Scenario] = J.Scenario AND
						sub.[Account] = J.Account AND
						sub.ToYearMonth = J.ToYearMonth AND
						sub.[Currency_Book] = J.Currency_Book

				--'Fill table wrk_CheckSum_FACT_Financials_Balance'
				DELETE pcINTEGRATOR_Log.dbo.wrk_CheckSum_FACT_Financials_Balance
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID

				SET @Deleted = @Deleted + @@ROWCOUNT

				INSERT INTO pcINTEGRATOR_Log..wrk_CheckSum_FACT_Financials_Balance
					(
					[InstanceID],
					[VersionID],
					[Entity],
					[Book],
					[Scenario],
					[FiscalYear],
					[Account],
					[FromYearMonth],
					[ToYearMonth],
					[Currency_Book],
					[Journal_Amount],
					[FACT_Amount],
					Diff
					)
				SELECT
					[InstanceID],
					[VersionID],
					[Entity],
					[Book],
					[Scenario],
					[FiscalYear],
					[Account],
					[FromYearMonth],
					[ToYearMonth],
					[Currency_Book],
					[Journal_Amount],
					[FACT_Amount],
					Diff = Journal_Amount - FACT_Amount
				FROM 
					#Journal_Bal J 
				WHERE
					ROUND((Journal_Amount - FACT_Amount), 1) <> 0.0

				SET @Inserted = @Inserted + @@ROWCOUNT

				DROP TABLE #Journal_Bal
				DROP TABLE #FACT_Financials_Bal

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
					OPTION (MAXDOP 1)

					UPDATE CFFB
					SET
						CheckSumRowLogID = CSRL.CheckSumRowLogID
					FROM
						[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_FACT_Financials_Balance] CFFB
						INNER JOIN [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL ON CSRL.[CheckSumRowKey] = CFFB.[Entity] + '_' + CFFB.[Book] + '_' + CFFB.[Scenario] + '_' + CFFB.[Account] + '_' + CONVERT(nvarchar(20), CFFB.[ToYearMonth]) + '_' + CFFB.[Currency_Book] AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = CFFB.[InstanceID] AND CSRL.[VersionID] = CFFB.[VersionID]
					OPTION (MAXDOP 1)

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
					OPTION (MAXDOP 1)

					SET @Updated = @Updated + @@ROWCOUNT
			END

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
					LEFT JOIN pcINTEGRATOR_Log..wrk_CheckSum_FACT_Financials_Balance F ON F.InstanceID = CSRL.InstanceID AND F.VersionID = CSRL.VersionID AND F.CheckSumRowLogID = CSRL.CheckSumRowLogID 
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND
					CSRL.[ProcedureID] = @ProcedureID
				OPTION (MAXDOP 1)

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
				OPTION (MAXDOP 1)
		
				SET @Selected = @Selected + @@ROWCOUNT
			END

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
