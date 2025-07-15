SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR13]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL, --Mandatory
	@ComputeDate date = NULL,

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
		{"TKey" : "InstanceID",  "TValue": "877"},
		{"TKey" : "VersionID",  "TValue": "1286"}
		]'

EXEC [spBR_BR13] @UserID=-10, @InstanceID=877, @VersionID=1286, @DebugBM=15, @DataClassID = 7560 --AccountPayable
EXEC [spBR_BR13] @UserID=-10, @InstanceID=877, @VersionID=1286, @DebugBM=15, @DataClassID = 7561 --AccountReceivable

EXEC [spBR_BR13] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataClassName nvarchar(50),
	@BusinessProcess nvarchar(50),
	@DC_StorageTypeBM int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@ComputeDayID nvarchar(10),
	@ModelBM int,
	@SQLStatement nvarchar(max),
	@DC_Name_AP_AR nvarchar(10),
	@Account_Name_AP_AR nvarchar(10),
	@BusinessProcess_MemberId bigint,
	@Account_MemberId_Invoice bigint,
	@Account_MemberId_Paid bigint,
	@Account_MemberId_Due bigint,
	@Account_MemberId_Due_OverDue bigint,
	
	@Scenario_MemberId bigint = 110, -- ACTUAL
	@TimeDataView_MemberId bigint = 101, --RAWDATA

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Calculate AR/AP parameters.',
			@MandatoryParameter = 'DataClassID' --Without @, separated by |

		IF @Version = '2.1.1.2169' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2199' SET @Description = 'Update to latest SP template. Made generic.'

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

		SELECT
			@DataClassName = DC.[DataClassName],
			@DC_StorageTypeBM = DC.[StorageTypeBM],
			@ModelBM = DC.[ModelBM],
			@BusinessProcess = S.[BusinessProcess]
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass] DC
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.[InstanceID] = DC.[InstanceID] AND M.[VersionID] = DC.[VersionID] AND M.[SelectYN] <> 0 AND M.[ModelBM] = DC.[ModelBM]
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Source] S ON S.[InstanceID] = DC.[InstanceID] AND S.[VersionID] = DC.[VersionID] AND S.[SelectYN] <> 0 AND S.[ModelID] = M.[ModelID]
		WHERE
			DC.[InstanceID] = @InstanceID AND
			DC.[VersionID] = @VersionID AND
			DC.[DataClassID] = @DataClassID AND
			DC.[SelectYN] <> 0 AND
			DC.[DeletedID] IS NULL

		SELECT
			@CallistoDatabase = [DestinationDatabase],
			@ETLDatabase = [ETLDatabase]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.SelectYN <> 0

		SELECT
			@ComputeDate = ISNULL(@ComputeDate, GETDATE()),
			@ComputeDayID = CONVERT(nvarchar(10), @ComputeDate, 112),
			@DC_Name_AP_AR = CASE @DataClassName WHEN 'AccountReceivable' THEN 'AR' WHEN 'AccountPayable' THEN 'AP' ELSE NULL END,
			@Account_Name_AP_AR = CASE @DataClassName WHEN 'AccountReceivable' THEN 'Receivable' WHEN 'AccountPayable' THEN 'Payable' ELSE NULL END

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@DataClassID] = @DataClassID,
				[@DataClassName] = @DataClassName,
				[@DC_StorageTypeBM] = @DC_StorageTypeBM,
				[@ComputeDate] = @ComputeDate,
				[@ComputeDayID] = @ComputeDayID,
				[@ModelBM] = @ModelBM,
				[@BusinessProcess] = @BusinessProcess,
				[@DC_Name_AP_AR] = @DC_Name_AP_AR,
				[@Account_Name_AP_AR] = @Account_Name_AP_AR

	SET @Step = 'SP-Specific check'
		IF @ModelBM & 1536 = 0
			BEGIN
				SET @Message = 'BR13 is only valid for DataClass AccountReceivable or AccountPayable.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

		IF @ModelBM IS NULL
			BEGIN
				SET @Message = 'No DataClass selected or DataClassID is NULL.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Set variable values based from selected DataClass'
		SET @SQLStatement = '
			SELECT @InternalVariable = [MemberId] FROM ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessProcess] WHERE [Label] = ''' + @BusinessProcess + ''''
		IF @DebugBM & 2 > 0 PRINT @SQLStatement

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @BusinessProcess_MemberId OUT

		SET @SQLStatement = '
			SELECT @InternalVariable = [MemberId] FROM ' + @CallistoDatabase + '.[dbo].[S_DS_Account] WHERE [Label] = ''' + @Account_Name_AP_AR + 'Invoice_'''
		IF @DebugBM & 2 > 0 PRINT @SQLStatement

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @Account_MemberId_Invoice OUT

		SET @SQLStatement = '
			SELECT @InternalVariable = [MemberId] FROM ' + @CallistoDatabase + '.[dbo].[S_DS_Account] WHERE [Label] = ''' + @Account_Name_AP_AR + 'Paid_'''
		IF @DebugBM & 2 > 0 PRINT @SQLStatement

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @Account_MemberId_Paid OUT

		SET @SQLStatement = '
			SELECT @InternalVariable = [MemberId] FROM ' + @CallistoDatabase + '.[dbo].[S_DS_Account] WHERE [Label] = ''' + @Account_Name_AP_AR + 'Due_'''
		IF @DebugBM & 2 > 0 PRINT @SQLStatement

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @Account_MemberId_Due OUT

		SET @SQLStatement = '
			SELECT @InternalVariable = [MemberId] FROM ' + @CallistoDatabase + '.[dbo].[S_DS_Account] WHERE [Label] = ''' + @Account_Name_AP_AR + 'Due_OverDue_'''
		IF @DebugBM & 2 > 0 PRINT @SQLStatement

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @Account_MemberId_Due_OverDue OUT
		
		IF @DebugBM & 2 > 0 
			SELECT 
				[@BusinessProcess_MemberId] = @BusinessProcess_MemberId,
				[@Account_MemberId_Invoice] = @Account_MemberId_Invoice,
				[@Account_MemberId_Paid] = @Account_MemberId_Paid,
				[@Account_MemberId_Due] = @Account_MemberId_Due,
				[@Account_MemberId_Due_OverDue] = @Account_MemberId_Due_OverDue

	SET @Step = 'Create temp table #PP'
		CREATE TABLE #PP
			(
			[InvoiceNo_MemberId] bigint,
			[Currency_MemberId] bigint,
			[PaidAmount] float
			)
		
		SET @SQLStatement = '
			INSERT INTO #PP
				(
				[InvoiceNo_MemberId],
				[Currency_MemberId],
				[PaidAmount]
				)
			SELECT DISTINCT
				[InvoiceNo_MemberId] = [InvoiceNo_' + @DC_Name_AP_AR + '_MemberId],
				[Currency_MemberId] = [Currency_MemberId],
				[PaidAmount] = [' + @DataClassName + '_Value]
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition]
			WHERE
				[Scenario_MemberId] = ' + CONVERT(nvarchar(15), @Scenario_MemberId) + ' AND
				[InvoiceNo_' + @DC_Name_AP_AR + '_MemberId] <> -1 AND 
				[Account_MemberId] = ' + CONVERT(nvarchar(15), @Account_MemberId_Paid) + ' AND
				[TimeDay_MemberId] <= ' + @ComputeDayID

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		IF @DebugBM & 8 > 0 SELECT [TempTable_#PP] = '#PP', * FROM #PP

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

		SET @SQLStatement = '
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
				[InvoiceNo_MemberId] = [InvoiceNo_' + @DC_Name_AP_AR + '_MemberId],
				[Currency_MemberId] = [Currency_MemberId],
				[Entity_MemberId] = [Entity_MemberId],
				[CS_MemberId] = ' + CASE @DC_Name_AP_AR WHEN 'AP' THEN '[Supplier_MemberId],' WHEN 'AR' THEN '[Customer_MemberId],' ELSE '' END + '
				[BusinessRule_MemberId],
				[DueAmount] = [' + @DataClassName + '_Value],
				[DueDate] = CONVERT(DATETIME, CONVERT(NVARCHAR(20), [TimeDay_MemberId]), 112)
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition]
			WHERE
				[Scenario_MemberId] = ' + CONVERT(nvarchar(15), @Scenario_MemberId) + ' AND
				[InvoiceNo_' + @DC_Name_AP_AR + '_MemberId] <> -1 AND
				[TimeDay_MemberId] <> -1 AND
				ISDATE(CONVERT(NVARCHAR(4), [TimeDay_MemberId]/10000) + ''-'' + CONVERT(NVARCHAR(2), ([TimeDay_MemberId]/100) % 100) + ''-'' + CONVERT(NVARCHAR(2), [TimeDay_MemberId] % 100)) <> 0 AND
				[Account_MemberId] = ' + CONVERT(nvarchar(15), @Account_MemberId_Due)
		
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		IF @DebugBM & 8 > 0 SELECT [TempTable_#PD] = '#PD', * FROM #PD

	SET @Step = 'Create temp table #PI'
		CREATE TABLE #PI
			(
			[InvoiceNo_MemberId] BIGINT
			)

		SET @SQLStatement = '
			INSERT INTO #PI
				(
				[InvoiceNo_MemberId]
				)
			SELECT DISTINCT
				[InvoiceNo_MemberId] = [InvoiceNo_' + @DC_Name_AP_AR + '_MemberId]
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition]
			WHERE
				[Scenario_MemberId] = ' + CONVERT(nvarchar(15), @Scenario_MemberId) + ' AND
				[InvoiceNo_' + @DC_Name_AP_AR + '_MemberId] <> -1 AND
				[Account_MemberId] = ' + CONVERT(nvarchar(15), @Account_MemberId_Invoice) + ' AND
				[TimeDay_MemberId] > ' + @ComputeDayID

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		IF @DebugBM & 8 > 0 SELECT [TempTable_#PI] = '#PI', * FROM #PI

	SET @Step = 'Create temp table #Aging'
		CREATE TABLE #Aging
			(
			[FromDay] int,
			[MemberId] bigint,
			[Description] nvarchar(255)
			)

		SET @SQLStatement = '
			INSERT INTO #Aging
				(
				[FromDay],
				[MemberId],
				[Description]
				)
			SELECT
				[FromDay],
				[MemberId],
				[Label]
			FROM
				' + @CallistoDatabase + '.[dbo].[S_DS_Aging_' + @DC_Name_AP_AR + '] 
			WHERE
				[RNodeType] = ''L'' AND 
				[MemberID] NOT IN (-1, 101, 102) 
			ORDER BY
				[FromDay]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 8 > 0 SELECT [TempTable_#Aging] = '#Aging', * FROM #Aging ORDER BY [FromDay]

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

		IF @DebugBM & 8 > 0 SELECT [TempTable_#Days] = '#Days', * FROM #Days ORDER BY [Days]

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
			[DueAmount] = MAX(D.[DueAmount])
		INTO
			#AgingData
		FROM
			#Days D
			INNER JOIN #Aging A ON A.[FromDay] <= D.[Days]
		GROUP BY
			D.[InvoiceNo_MemberId],
			D.[Currency_MemberId]
		ORDER BY
			MAX(D.[Days])

		IF @DebugBM & 8 > 0 SELECT [TempTable_#AgingData] = '#AgingData', * FROM #AgingData ORDER BY [Days], [InvoiceNo_MemberId], [Currency_MemberId]

	SET @Step = 'Delete all rows in DataClass with account @Account_MemberId_Due_OverDue.'
		SET @SQLStatement = '
			DELETE
				' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition]
			WHERE
				[Account_MemberID] = ' + CONVERT(nvarchar(15), @Account_MemberId_Due_OverDue) + ' AND
				[BusinessProcess_MemberId] = ' + CONVERT(nvarchar(15), @BusinessProcess_MemberId) + ' AND
				[Scenario_MemberId] = ' + CONVERT(nvarchar(15), @Scenario_MemberId) + ' AND
				[TimeDataView_MemberId] = ' + CONVERT(nvarchar(15), @TimeDataView_MemberId)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Add new rows in DataClass with account @Account_MemberId_Due_OverDue.'
		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition]
				(
				[Account_MemberId],
				[Aging_' + @DC_Name_AP_AR + '_MemberId],
				[BusinessProcess_MemberId],
				[BusinessRule_MemberId],
				[Currency_MemberId],
				[Entity_MemberId],
				[InvoiceNo_' + @DC_Name_AP_AR + '_MemberId],
				[Scenario_MemberId],
				' + CASE @DC_Name_AP_AR WHEN 'AP' THEN '[Supplier_MemberId] ' WHEN 'AR' THEN '[Customer_MemberId] ' ELSE '' END + ',
				[TimeDataView_MemberId],
				[TimeDay_MemberId],
				[ChangeDatetime],
				[Userid],
				[' + @DataClassName + '_Value]
				)
			SELECT
				[Account_MemberId] = ' + CONVERT(nvarchar(15), @Account_MemberId_Due_OverDue) + ',
				[Aging_' + @DC_Name_AP_AR + '_MemberId] = A.[MemberId],
				[BusinessProcess_MemberId] = ' + CONVERT(nvarchar(15), @BusinessProcess_MemberId) + ',
				[BusinessRule_MemberId] = AD.[BusinessRule_MemberId],
				[Currency_MemberId] = AD.[Currency_MemberId],
				[Entity_MemberId] = AD.[Entity_MemberId],
				[InvoiceNo_' + @DC_Name_AP_AR + '_MemberId] = AD.[InvoiceNo_MemberId],
				[Scenario_MemberId] = ' + CONVERT(nvarchar(15), @Scenario_MemberId) + ',
				' + CASE @DC_Name_AP_AR WHEN 'AP' THEN '[Supplier_MemberId] ' WHEN 'AR' THEN '[Customer_MemberId] ' ELSE '' END + ' = AD.[CS_MemberId],
				[TimeDataView_MemberId] = ' + CONVERT(nvarchar(15), @TimeDataView_MemberId) + ',
				--[TimeDay_MemberId] = CONVERT(NVARCHAR(10), AD.[DueDate], 112),
				[TimeDay_MemberId] = ' + @ComputeDayID + ',
				[ChangeDatetime] = GETDATE(),
				[Userid] = ''' + @UserName + ''',
				[' + @DataClassName + '_Value] = AD.[BalanceAmount]
			FROM
				#AgingData AD
				INNER JOIN #Aging A ON A.[FromDay] = AD.[FromDay]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
		DROP TABLE #PP
		DROP TABLE #PD
		DROP TABLE #PI
		DROP TABLE #Days
		DROP TABLE #Aging
		DROP TABLE #AgingData

	SET @Step = 'Set @Duration'
		SET @Duration = GETDATE() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
