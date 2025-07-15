SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR13_20250624]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,
	@ComputeDate date = NULL,
	@AllowedPayDiffPct float = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000763,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spBR_BR13',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spBR_BR13] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spBR_BR13] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataClassName nvarchar(50),
	@DC_StorageTypeBM int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@ComputeDayID nvarchar(10),
	@ModelBM int,

	@Account_MemberId_Paid bigint = 111,
	@Account_MemberId_Due bigint = 112,
	@Account_MemberId_Invoice bigint = 110,
	@Account_MemberId_Count bigint = 1921,
	@Account_MemberId_Due_OverDue bigint = 118,
	@Scenario_MemberId bigint = 110,
	@BusinessProcess_MemberId bigint = 1001194,
	@TimeDataView_MemberId bigint = 101,

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
	@Version nvarchar(50) = '2.1.1.2169'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Calculate AR/AP parameters.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2169' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
--		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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
			@DataClassName = DC.DataClassName,
			@DC_StorageTypeBM = DC.StorageTypeBM,
			@ModelBM = DC.[ModelBM]
		FROM
			pcINTEGRATOR_Data..DataClass DC
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.VersionID = @VersionID AND
			DC.DataClassID = @DataClassID AND
			DC.SelectYN <> 0 AND
			DC.DeletedID IS NULL

		SELECT
			@CallistoDatabase = [DestinationDatabase],
			@ETLDatabase = [ETLDatabase]
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SELECT
			@ComputeDate = ISNULL(@ComputeDate, GetDate()),
			@AllowedPayDiffPct = ISNULL(@AllowedPayDiffPct, 0.1),
			@ComputeDayID = CONVERT(nvarchar(10), @ComputeDate, 112)


		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@DataClassID] = @DataClassID,
				[@DataClassName] = @DataClassName,
				[@DC_StorageTypeBM] = @DC_StorageTypeBM,
				[@ComputeDate] = @ComputeDate,
				[@ComputeDayID] = @ComputeDayID,
				[@AllowedPayDiffPct] = @AllowedPayDiffPct,
				[@ModelBM] = @ModelBM

	SET @Step = 'SP-Specific check'
		IF @ModelBM & 1536 = 0
			BEGIN
				SET @Message = 'BR13 is only valid for DataClass AR and AP.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp table #PP'
		CREATE TABLE #PP
			(
			[InvoiceNo_MemberId] bigint,
			[Currency_MemberId] bigint,
			[PaidAmount] float
			)
		
		INSERT INTO #PP
			(
			[InvoiceNo_MemberId],
			[Currency_MemberId],
			[PaidAmount]
			)
		SELECT DISTINCT
			[InvoiceNo_MemberId] = [InvoiceNo_AP_MemberId],
			[Currency_MemberId] = [Currency_MemberId],
			[PaidAmount] = [AccountPayable_Value]
		FROM
			[pcDATA_E2IP].[dbo].[FACT_AccountPayable_default_partition]
		WHERE
			[Scenario_MemberId] = @Scenario_MemberId AND
			[InvoiceNo_AP_MemberId] <> -1 AND 
			[Account_MemberId] = @Account_MemberId_Paid AND
			[TimeDay_MemberId] <= @ComputeDayID

	SET @Step = 'Create temp table #PD'
		CREATE TABLE #PD
			(
			[InvoiceNo_MemberId] bigint,
			[Currency_MemberId] bigint,
			[Entity_MemberId] bigint,
			[CS_MemberId] bigint,
			[BusinessRule_MemberId] bigint,
			[DueAmount] float,
			[DueDate] date
			)

		INSERT INTO #PD
			(
			[InvoiceNo_MemberId],
			[Currency_MemberId],
			[Entity_MemberId],
			[CS_MemberId],
			[BusinessRule_MemberId],
			[DueAmount],
			[DueDate]
			)
		SELECT DISTINCT
			[InvoiceNo_MemberId] = [InvoiceNo_AP_MemberId],
			[Currency_MemberId] = [Currency_MemberId],
			[Entity_MemberId] = [Entity_MemberId],
			[CS_MemberId] = [Supplier_MemberId],
			[BusinessRule_MemberId],
			[DueAmount] = [AccountPayable_Value],
			[DueDate] = CONVERT(datetime, CONVERT(nvarchar(20), [TimeDay_MemberId]), 112)
		FROM
			[pcDATA_E2IP].[dbo].[FACT_AccountPayable_default_partition]
		WHERE
			[Scenario_MemberId] = @Scenario_MemberId AND
			[InvoiceNo_AP_MemberId] <> -1 AND
			ISDATE(CONVERT(nvarchar(4), [TimeDay_MemberId]/10000) + '-' + CONVERT(nvarchar(2), ([TimeDay_MemberId]/100) % 100) + '-' + CONVERT(nvarchar(2), [TimeDay_MemberId] % 100)) <> 0 AND
			[Account_MemberId] = @Account_MemberId_Due

	SET @Step = 'Create temp table #PI'
		CREATE TABLE #PI
			(
			[InvoiceNo_MemberId] bigint
			)

		INSERT INTO #PI
			(
			[InvoiceNo_MemberId]
			)
		SELECT DISTINCT
			[InvoiceNo_MemberId] = [InvoiceNo_AP_MemberId]
		FROM
			[pcDATA_E2IP].[dbo].[FACT_AccountPayable_default_partition]
		WHERE
			[Scenario_MemberId] = @Scenario_MemberId AND
			[InvoiceNo_AP_MemberId] <> -1 AND
			[Account_MemberId] = @Account_MemberId_Invoice AND
			[TimeDay_MemberId] > @ComputeDayID

	SET @Step = 'Create temp table #Aging'
		CREATE TABLE #Aging
			(
			[FromDay] int,
			[MemberId] bigint,
			[Description] nvarchar(255)
			)

		INSERT INTO #Aging
			(
			[FromDay],
			[MemberId],
			[Description]
			)
		SELECT
			FromDay,
			MemberId,
			[Label]
		FROM
			pcDATA_E2IP..S_DS_Aging_AP 
		WHERE
			RNodeType = 'L' AND 
			MemberID NOT IN (-1, 102) 
		ORDER BY
			FromDay

		IF @DebugBM & 8 > 0
			BEGIN
				SELECT TempTable = '#PP', * FROM #PP
				SELECT TempTable = '#PD', * FROM #PD
				SELECT TempTable = '#PI', * FROM #PI
				SELECT TempTable = '#Aging', * FROM #Aging ORDER BY [FromDay]
			END

	SET @Step = 'Create temp table #Days'
		SELECT
			[InvoiceNo_MemberId] = #PD.[InvoiceNo_MemberId],
			[Currency_MemberId] = #PD.[Currency_MemberId],
			[Entity_MemberId] =  MAX(#PD.[Entity_MemberId]),
			[CS_MemberId] = MAX(#PD.[CS_MemberId]),
			[BusinessRule_MemberId] = MAX(#PD.[BusinessRule_MemberId]),
			[Days] = DATEDIFF(dd, @ComputeDate, MAX(#PD.[DueDate])),
			[DueDate] = MAX(#PD.[DueDate]), 
			[BalanceAmount] = SUM(ISNULL(#PP.[PaidAmount], 0) + #PD.[DueAmount]),
			[DueAmount] = SUM(#PD.[DueAmount])
		INTO
			#Days
		FROM
			#PD
			LEFT JOIN #PP ON #PP.[InvoiceNo_MemberId] = #PD.[InvoiceNo_MemberId] AND #PP.[Currency_MemberId] = #PD.[Currency_MemberId]
		WHERE
			NOT EXISTS (SELECT 1 FROM #PI WHERE #PI.[InvoiceNo_MemberId] = #PD.[InvoiceNo_MemberId])
		GROUP BY
			#PD.[InvoiceNo_MemberId],
			#PD.[Currency_MemberId]
		HAVING
			SUM(ISNULL(#PP.[PaidAmount], 0) + #PD.[DueAmount]) < 0.0

		IF @DebugBM & 8 > 0 SELECT TempTable = '#Days', * FROM #Days ORDER BY [Days]

	SET @Step = 'Create temp table #AgingData'
		SELECT
			[InvoiceNo_MemberId] = D.[InvoiceNo_MemberId],
			[Currency_MemberId] = D.[Currency_MemberId],
			[Entity_MemberId] =  MAX(D.[Entity_MemberId]),
			[CS_MemberId] = MAX(D.[CS_MemberId]),
			[BusinessRule_MemberId] = MAX(D.[BusinessRule_MemberId]),
			[Days] = MAX(D.[Days]),
			[DueDate] = MAX(D.[DueDate]), 
			[FromDay] = MAX(A.[FromDay]),
			[BalanceAmount] = MAX(D.[BalanceAmount]),
			[DueAmount] = MAX(D.[DueAmount]),
			[PayDiffPct] = ABS(MAX(D.[BalanceAmount]))/ABS(MAX(D.[DueAmount])), 
			[AllowedPayDiffPct] = @AllowedPayDiffPct
		INTO
			#AgingData
		FROM
			#Days D
			INNER JOIN #Aging A ON A.[FromDay] <= D.[Days]
		GROUP BY
			D.[InvoiceNo_MemberId],
			D.[Currency_MemberId]
		HAVING
			ABS(MAX(D.[BalanceAmount]))/ABS(MAX(D.[DueAmount])) > @AllowedPayDiffPct
		ORDER BY
			MAX(D.[Days])

		IF @DebugBM & 8 > 0 SELECT TempTable = '#AgingData', * FROM #AgingData ORDER BY [Days], [InvoiceNo_MemberId], [Currency_MemberId]

	SET @Step = 'Delete all rows in DataClass with account @Account_MemberId_Count AND @Account_MemberId_Due_OverDue.'
		DELETE
			[pcDATA_E2IP].[dbo].[FACT_AccountPayable_default_partition]
		WHERE
			[Account_MemberID] IN (@Account_MemberId_Count, @Account_MemberId_Due_OverDue) AND
			[BusinessProcess_MemberId] = @BusinessProcess_MemberId AND
			[Scenario_MemberId] = @Scenario_MemberId AND
			[TimeDataView_MemberId] = @TimeDataView_MemberId

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Add new rows in DataClass with account @Account_MemberId_Count AND @Account_MemberId_Due_OverDue.'
		INSERT INTO [pcDATA_E2IP].[dbo].[FACT_AccountPayable_default_partition]
			(
			[Account_MemberId],
			[Aging_AP_MemberId],
			[BusinessProcess_MemberId],
			[BusinessRule_MemberId],
			[Currency_MemberId],
			[Entity_MemberId],
			[InvoiceNo_AP_MemberId],
			[Scenario_MemberId],
			[Supplier_MemberId],
			[TimeDataView_MemberId],
			[TimeDay_MemberId],
			[ChangeDatetime],
			[Userid],
			[AccountPayable_Value]
			)
		SELECT
			[Account_MemberId] = sub.[Account_MemberId],
			[Aging_AP_MemberId] = A.[MemberId],
			[BusinessProcess_MemberId] = @BusinessProcess_MemberId,
			[BusinessRule_MemberId] = AD.[BusinessRule_MemberId],
			[Currency_MemberId] = AD.[Currency_MemberId],
			[Entity_MemberId] = AD.[Entity_MemberId],
			[InvoiceNo_AP_MemberId] = AD.[Entity_MemberId],
			[Scenario_MemberId] = @Scenario_MemberId,
			[Supplier_MemberId] = AD.CS_MemberId,
			[TimeDataView_MemberId] = @TimeDataView_MemberId,
			[TimeDay_MemberId] = CONVERT(nvarchar(10), AD.DueDate, 112),
			[ChangeDatetime] = GetDate(),
			[Userid] = suser_name(),
			[AccountPayable_Value] = CASE WHEN sub.[Account_MemberId] = @Account_MemberId_Count THEN 1 ELSE AD.[BalanceAmount] END
		FROM
			#AgingData AD
			INNER JOIN #Aging A ON A.[FromDay] = AD.[FromDay]
			INNER JOIN 
				(
				SELECT [Account_MemberId] = @Account_MemberId_Count 
				UNION
				SELECT [Account_MemberId] = @Account_MemberId_Due_OverDue
				) sub ON 1 = 1

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
		DROP TABLE #PP
		DROP TABLE #PD
		DROP TABLE #PI
		DROP TABLE #Days
		DROP TABLE #Aging
		DROP TABLE #AgingData

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
