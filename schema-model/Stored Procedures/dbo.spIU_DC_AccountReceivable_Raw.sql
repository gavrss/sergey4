SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_AccountReceivable_Raw]
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
	@ProcedureID int = 880000973,
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
EXEC [spIU_DC_AccountReceivable_Raw] @UserID=-10, @InstanceID=817, @VersionID=1236, @DataClassID=6650, @StartYear=2023, @DebugBM=31

EXEC [spIU_DC_AccountReceivable_Raw] @GetVersion = 1
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
			@ProcedureDescription = 'Get #DC_AccountReceivable_Raw from source system',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

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
			INNER JOIN [pcINTEGRATOR].[dbo].[Model] M ON M.ApplicationID = A.ApplicationID AND M.ModelBM = 512 AND M.SelectYN <> 0
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

	SET @Step = 'Create temp table #DC_AccountReceivable'
		IF OBJECT_ID(N'TempDB.dbo.#DC_AccountReceivable', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #DC_AccountReceivable
					(
					[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Aging_AR] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[BusinessProcess] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[BusinessRule] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Currency] nchar(3) COLLATE DATABASE_DEFAULT,
					[Customer] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[InvoiceNo_AR] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[TimeDataView] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[TimeDay] int,
					[AccountReceivable_Value] float
					)
			END

	SET @Step = 'Insert into #DC_AccountReceivable'
--@SequenceCounter = 1, @SequenceBMStep = 1
--AccountsReceivable
		SET @SQLStatement = '
			INSERT INTO #DC_AccountReceivable
				(
				[Account],
				[Aging_AR],
				[BusinessProcess],
				[BusinessRule],
				[Currency],
				[Customer], 
				[Entity],
				[InvoiceNo_AR],
				[Scenario],
				[TimeDataView],
				[TimeDay],
				[AccountReceivable_Value]
				)
			SELECT
				[Account] = A.[Label],
				[Aging_AR] = ''NONE'',
				[BusinessProcess] = ''' + @Source_BP+ ''',
				[BusinessRule] = ''NONE'',
				[Currency] = MAX(RIGHT(IH.[CurrencyCode], 3)),
				--[Customer] = C.[CustID] COLLATE DATABASE_DEFAULT + ''_'',
				[Customer] = C.[CustID] COLLATE DATABASE_DEFAULT,
				[Entity] = MAX(E.[MemberKey]),
				[InvoiceNo_AR] = E.[MemberKey] + ''_'' + (CASE LEN([InvoiceNum]) WHEN 1 THEN ''00000'' WHEN 2 THEN ''0000''  WHEN 3 THEN ''000''  WHEN 4 THEN ''00''  WHEN 5 THEN ''0'' ELSE '''' END + CONVERT(NVARCHAR(50), IH.[InvoiceNum])) COLLATE DATABASE_DEFAULT,
				[Scenario] = ''ACTUAL'',
				[TimeDataView] = ''RAWDATA'',
				[TimeDay] = MAX(CONVERT(NVARCHAR(10), CASE A.[Label] WHEN ''ReceivableInvoice_'' THEN IH.[InvoiceDate] WHEN ''ReceivableDue_'' THEN IH.[DueDate] WHEN ''ReceivablePaid_'' THEN IH.[ClosedDate] END, 112)),
				[AccountReceivable_Value] = SUM(IH.[InvoiceAmt]) * CASE WHEN A.[Label] = ''ReceivablePaid_'' THEN -1 ELSE 1 END
			FROM
				' + @SourceDatabase+ '.[' + @Owner+ '].[InvcHead] IH
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[MemberSelection] A ON A.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND A.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND A.[DataClassID] = ' + CONVERT(nvarchar(15), @DataClassID) + ' AND A.[DimensionID] = -1 AND A.[SelectYN] <> 0 AND A.[Label] IN (''ReceivableInvoice_'', ''ReceivableDue_'', ''ReceivablePaid_'')
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.[MemberKey] = IH.[Company] COLLATE DATABASE_DEFAULT AND E.[SelectYN] <> 0
				LEFT JOIN ' + @SourceDatabase+ '.[' + @Owner+ '].[Customer] C ON C.[Company] = IH.[Company] AND C.[CustNum] = IH.[CustNum]
			WHERE
				(YEAR([IH].[InvoiceDate]) >= ' + CONVERT(nvarchar(15), @StartYear) + ' OR YEAR([IH].[DueDate]) >= ' + CONVERT(nvarchar(15), @StartYear) + ' OR YEAR([IH].[ClosedDate]) >= ' + CONVERT(nvarchar(15), @StartYear) + ') 				
			GROUP BY 
				A.[Label],
				--C.[CustID] COLLATE DATABASE_DEFAULT + ''_'',
				C.[CustID] COLLATE DATABASE_DEFAULT,
				E.[MemberKey] + ''_'' + (CASE LEN([InvoiceNum]) WHEN 1 THEN ''00000'' WHEN 2 THEN ''0000''  WHEN 3 THEN ''000''  WHEN 4 THEN ''00''  WHEN 5 THEN ''0'' ELSE '''' END + CONVERT(NVARCHAR(50), IH.[InvoiceNum])) COLLATE DATABASE_DEFAULT
			HAVING
				SUM(IH.[InvoiceAmt]) * CASE WHEN A.[Label] = ''ReceivablePaid_'' THEN -1 ELSE 1 END <> 0'
		
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Selected = @Selected + @@ROWCOUNT

		IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_AccountReceivable', * FROM #DC_AccountReceivable ORDER BY [Entity], [Account], [TimeDay]
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert into #DC_AccountReceivable', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
	
	SET @Step = 'Return rows'
		IF @CalledYN = 0
			SELECT TempTable = '#DC_AccountReceivable', * FROM #DC_AccountReceivable ORDER BY [Entity], [Account], [Timeday]

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0 DROP TABLE #DC_AccountReceivable

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
