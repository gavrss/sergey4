SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_AccountPayable_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,
	@StartYear int = NULL,
	@Entity nvarchar(50) = NULL,
	--@StartDay int = NULL,
	--@SequenceBM int = NULL,
	--@SourceDatabase nvarchar(100) = NULL, 
	--@MasterClosedYear int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000738,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_DC_AccountPayable_Raw] @UserID=-10, @InstanceID=817, @VersionID=1236, @DataClassID=6649, @StartYear=2023, @DebugBM=31

EXEC [spIU_DC_AccountPayable_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceDatabase nvarchar(100),
	@Owner nvarchar(10),
	@SQLStatement nvarchar(max),
	@SourceID int,
	@SourceTypeID int,
	@SourceTypeName nvarchar(50),
	@MasterClosedYear int,
	@Entity_StartDay int,
	@Time_MemberId int,
	@Source_BP nvarchar(50),

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get #DC_AccountPayable_Raw from source system',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2163' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2199' SET @Description = 'Updated template.'

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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@Owner = ST.[Owner],
			@StartYear = ISNULL(@StartYear, S.StartYear),
			@SourceID = S.[SourceID],
			@SourceTypeID = S.[SourceTypeID],
			@SourceTypeName = ST.[SourceTypeName],
			@Source_BP = S.[BusinessProcess]
		FROM
			[pcINTEGRATOR].[dbo].[Application] A
			INNER JOIN [pcINTEGRATOR].[dbo].[Model] M ON M.ApplicationID = A.ApplicationID AND M.ModelBM = 1024 AND M.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = 1
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		EXEC [pcINTEGRATOR].[dbo].[spGet_MasterClosedYear]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@MasterClosedYear = @MasterClosedYear OUT,
			@JobID = @JobID

		IF @MasterClosedYear >= @StartYear SET @StartYear = @MasterClosedYear + 1

		IF @DebugBM & 2 > 0 
			SELECT
				[@SourceDatabase] = @SourceDatabase,
				[@Owner] = @Owner,
				[@StartYear] = @StartYear,
				[@SourceID] = @SourceID,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName

	SET @Step = 'Create temp table #DC_AccountPayable'
		IF OBJECT_ID(N'TempDB.dbo.#DC_AccountPayable', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #DC_AccountPayable
					(
					[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Aging_AP] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[BusinessProcess] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[BusinessRule] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Currency] nchar(3) COLLATE DATABASE_DEFAULT,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[InvoiceNo_AP] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Supplier] nvarchar(50) COLLATE DATABASE_DEFAULT, 
					[TimeDataView] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[TimeDay] int,
					[AccountPayable_Value] float
					)
			END

	SET @Step = 'Insert Invoices to #DC_AccountPayable'
--@SequenceCounter = 1, @SequenceBMStep = 1
--AccountsPayable; 'PayableInvoice_', 'PayableDue_'
		SET @SQLStatement = '
			INSERT INTO #DC_AccountPayable
				(
				[Account],
				[Aging_AP],
				[BusinessProcess],
				[BusinessRule],
				[Currency],
				[Entity],
				[InvoiceNo_AP],
				[Scenario],
				[Supplier], 
				[TimeDataView],
				[TimeDay],
				[AccountPayable_Value]
				)
			SELECT
				[Account] = A.[Label],
				[Aging_AP] = ''NONE'',
				[BusinessProcess] = ''' + @Source_BP+ ''',
				[BusinessRule] = ''NONE'',
				[Currency] = MAX(RIGHT(APIH.[CurrencyCode], 3)),
				[Entity] = E.[MemberKey], 
				[InvoiceNo_AP] = E.[MemberKey] + ''_'' + (CONVERT(NVARCHAR(255), APIH.[VendorNum]) + ''_'' + APIH.[InvoiceNum]) COLLATE DATABASE_DEFAULT,
				[Scenario] = ''ACTUAL'',
				[Supplier] = CONVERT(NVARCHAR(255), APIH.[VendorNum]),
				[TimeDataView] = ''RAWDATA'',
				[TimeDay] = MAX(CONVERT(NVARCHAR(10), CASE A.[Label] WHEN ''PayableInvoice_'' THEN APIH.[InvoiceDate] WHEN ''PayableDue_'' THEN APIH.[DueDate] END, 112)),
				[AccountPayable_Value] = SUM(APIH.[InvoiceAmt]) * -1
			FROM
				' + @SourceDatabase+ '.[' + @Owner+ '].[APInvHed] APIH
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.MemberKey = APIH.Company COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[MemberSelection] A ON A.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND A.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND A.DataClassID = ' + CONVERT(nvarchar(15), @DataClassID) + ' AND A.DimensionID = -1 AND A.SelectYN <> 0 AND A.[Label] IN (''PayableInvoice_'', ''PayableDue_'')
			WHERE
				(YEAR([APIH].[InvoiceDate]) >= ' + CONVERT(nvarchar(15), @StartYear) + ' OR YEAR([APIH].[DueDate]) >= ' + CONVERT(nvarchar(15), @StartYear) + ')				
			GROUP BY 
				A.[Label],
				E.[MemberKey],
				E.[MemberKey] + ''_'' + (CONVERT(NVARCHAR(255), APIH.[VendorNum]) + ''_'' + APIH.[InvoiceNum]) COLLATE DATABASE_DEFAULT,
				CONVERT(NVARCHAR(255), APIH.[VendorNum])
			HAVING
				SUM(APIH.[InvoiceAmt]) * -1 <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Selected = @Selected + @@ROWCOUNT

		IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_AccountPayable [Invoices]', * FROM #DC_AccountPayable WHERE [Account] IN ('PayableInvoice_', 'PayableDue_') ORDER BY [Entity], [Account], [TimeDay]
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert into #DC_AccountPayable [Invoices]', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Insert Payments to #DC_AccountPayable'		
--@SequenceCounter = 2, @SequenceBMStep = 2
--AccountsPayable; 'PayablePaid_'
		SET @SQLStatement = '
			INSERT INTO #DC_AccountPayable
				(
				[Account],
				[Aging_AP],
				[BusinessProcess],
				[BusinessRule],
				[Currency],
				[Entity],
				[InvoiceNo_AP],
				[Scenario],
				[Supplier], 
				[TimeDataView],
				[TimeDay],
				[AccountPayable_Value]
				)
			SELECT
				[Account] = A.[Label],
				[Aging_AP] = ''NONE'',
				[BusinessProcess] = ''' + @Source_BP+ ''',
				[BusinessRule] = ''NONE'',
				[Currency] = MAX(BA.[CurrencyCode]),
				[Entity] = E.[MemberKey],
				[InvoiceNo_AP] = E.[MemberKey] + ''_'' + (CONVERT(NVARCHAR(255), APT.[VendorNum]) + ''_'' + APT.[InvoiceNum]) COLLATE DATABASE_DEFAULT,
				[Scenario] = ''ACTUAL'',
				[Supplier] = CONVERT(NVARCHAR(255), APT.[VendorNum]),
				[TimeDataView] = ''RAWDATA'',
				[TimeDay] = MAX(CONVERT(NVARCHAR(10), APT.[TranDate], 112)),
				[AccountPayable_Value] = SUM(APT.[TranAmt])
			FROM
				' + @SourceDatabase+ '.[' + @Owner+ '].[APTran] APT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.MemberKey = APT.Company COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
				INNER JOIN ' + @SourceDatabase+ '.' + @Owner+ '.[BankAcct] BA ON APT.Company = BA.Company AND APT.BankAcctID = BA.BankAcctID
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[MemberSelection] A ON A.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND A.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND A.DataClassID = ' + CONVERT(nvarchar(15), @DataClassID) + ' AND A.DimensionID = -1 AND A.SelectYN <> 0 AND A.[Label] IN (''PayablePaid_'')
			WHERE
				[APT].[TranType] = ''Pay'' AND
				YEAR([APT].[TranDate]) >= ' + CONVERT(nvarchar(15), @StartYear) + '				
			GROUP BY 
				A.[Label],
				E.[MemberKey],
				E.[MemberKey] + ''_'' + (CONVERT(NVARCHAR(255), APT.[VendorNum]) + ''_'' + APT.[InvoiceNum]) COLLATE DATABASE_DEFAULT,
				CONVERT(NVARCHAR(255), APT.[VendorNum])
			HAVING
				SUM(APT.[TranAmt]) <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Selected = @Selected + @@ROWCOUNT

		IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_AccountPayable [Payments]', * FROM #DC_AccountPayable WHERE [Account] = 'PayablePaid_' ORDER BY [Entity], [TimeDay]
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert into #DC_AccountPayable [Payments]', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			SELECT TempTable = '#DC_AccountPayable', * FROM #DC_AccountPayable ORDER BY [Entity], [Account], [Timeday]

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0 DROP TABLE #DC_AccountPayable

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
