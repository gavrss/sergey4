SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Sales_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,
	@StartYear int = NULL,
	@StartDay int = NULL,
	@SequenceBM int = NULL,
	@Entity nvarchar(50) = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@MasterClosedYear int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000697,
	--SELECT top 10 * FROM [pcINTEGRATOR_Data].[dbo].[Procedure] WHERE [ProcedureId] = 990000658
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

EXEC [spIU_DC_Sales_Raw] @UserID=-10, @InstanceID=531, @VersionID=1057, @StartDay= 20210101, @SourceDatabase='[DSPSOURCE01].[pcSource_PSAC]', @DebugBM=15, @SequenceBM=1
EXEC [spIU_DC_Sales_Raw] @UserID=-10, @InstanceID=907, @VersionID=1313, @StartDay= 20250401, @DebugBM=3
EXEC [spIU_DC_Sales_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@Owner nvarchar(10),
	@SourceID int,
	@SourceTypeID int,
	@SourceTypeName nvarchar(50),
	@Entity_StartDay int,
	@EntityString nvarchar(1000) = '',
	@StepStartTime datetime,
	@StartDate date,
	@RowCount int,
	@SQLStatement nvarchar(MAX),
	@CallistoDatabase nvarchar(100),

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
	@ModifiedBy nvarchar(50) = 'WiHe',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get #DC_Sales_Raw from source system',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added queries for @SequenceBM 16 & 32.'
		IF @Version = '2.1.1.2174' SET @Description = 'Modified queries for @SequenceBM 16 (added GROUP BY InvoiceLine) and @SequenceBM 3 (get [ShipDate] value from [ShipDtl] table).'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-731: Updated valid [Currency] value in temp table [#DC_Sales_Raw].'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-3117: Made generic.'

		--EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		--SET @StartDate = CONVERT(date, CONVERT(nvarchar(15), @StartDay), 112)
		--If condition to check if @StartDate is null, if null it will set variable to the begining of last month. These can later be use for the full reload of data.
		IF @StartDay IS NULL AND @StartDate IS NULL	SET @StartDate = DATEFROMPARTS(YEAR(DATEADD(Month,-1,GETDATE())),MONTH(DATEADD(Month,-1,GETDATE())),1)
		--If to always set the start of the month using @StartDay
		IF @StartDay IS NOT NULL AND @StartDate IS NULL	SET @StartDate = CONVERT(date, LEFT(CONVERT(nvarchar(15), @StartDay),6) + '01', 112)

		SELECT
			@DataClassID = ISNULL(@DataClassID, MAX(DC.DataClassID))
		FROM
			[pcINTEGRATOR_Data].[dbo].DataClass DC
		WHERE
			DC.[InstanceID] = @InstanceID AND
			DC.[VersionID] = @VersionID AND
			DC.[DataClassTypeID] = -10 AND
			DC.[SelectYN] <> 0 AND
			DC.[DeletedID] IS NULL

		SELECT
			@SourceDatabase = ISNULL(@SourceDatabase, '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']'),
			@Owner = ST.[Owner],
			@StartYear = ISNULL(@StartYear, S.StartYear),
			@SourceID = S.[SourceID],
			@SourceTypeID = S.[SourceTypeID],
			@SourceTypeName = ST.[SourceTypeName],
			@CallistoDatabase = A.DestinationDatabase
		FROM
			[pcINTEGRATOR].[dbo].[Application] A
			INNER JOIN [pcINTEGRATOR].[dbo].[Model] M ON M.[ApplicationID] = A.[ApplicationID] AND M.[BaseModelID] = -4 AND M.[SelectYN] <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.[ModelID] = M.[ModelID] AND S.[SelectYN] <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.[SourceTypeID] = S.[SourceTypeID] --AND ST.SourceTypeFamilyID = 1
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		IF @MasterClosedYear IS NULL
			EXEC [pcINTEGRATOR].[dbo].[spGet_MasterClosedYear]
				@UserID = @UserID,
				@InstanceID = @InstanceID,
				@VersionID = @VersionID,
				@MasterClosedYear = @MasterClosedYear OUT,
				@JobID = @JobID

		IF @MasterClosedYear >= @StartYear SET @StartYear = @MasterClosedYear + 1

	SET @Step = 'Create temp table #Callisto_Currency'
		CREATE TABLE #Callisto_Currency
			(
			[Currency] nvarchar(5) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #Entity_Currency'
		CREATE TABLE #Entity_Currency
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,            
			[Currency] nvarchar(5) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Fill temp table #MemberSelection'
		SET @StepStartTime = GETDATE()

		CREATE TABLE [dbo].[#MemberSelection]
			(
			[DimensionID] [int],
			[Label] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[SequenceBM] [int]
			)

		INSERT INTO #MemberSelection
			(
			[DimensionID],
			[Label],
			[SequenceBM]
			)
		SELECT
			MS.[DimensionID],
			MS.[Label],
			MS.[SequenceBM]
		FROM
			[pcINTEGRATOR_Data].[dbo].[MemberSelection] MS
		WHERE	
			MS.[InstanceID] = @InstanceID AND
			MS.[VersionID] = @VersionID AND
			MS.[DataClassID] = @DataClassID AND
			(MS.[SequenceBM] & @SequenceBM > 0 OR @SequenceBM IS NULL) AND
			MS.[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT Step = '#MemberSelection', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #MemberSelection
		IF @DebugBM & 8 > 0 SELECT TempTable = '#MemberSelection', * FROM #MemberSelection

	SET @Step = 'Set @SequenceBM'
		IF @SequenceBM IS NULL
			BEGIN
				SELECT 
					@SequenceBM =
						CASE WHEN SUM(BM01) = 2 THEN 1 ELSE 0 END +
						CASE WHEN SUM(BM02) = 2 THEN 2 ELSE 0 END +
						CASE WHEN SUM(BM04) = 2 THEN 4 ELSE 0 END +
						CASE WHEN SUM(BM08) = 2 THEN 8 ELSE 0 END +
						CASE WHEN SUM(BM16) = 2 THEN 16 ELSE 0 END +
						CASE WHEN SUM(BM32) = 2 THEN 32 ELSE 0 END
				FROM
					(
					SELECT
						DimensionID,
						BM01 = MAX(CASE WHEN SequenceBM & 1 > 0 THEN 1 ELSE 0 END),
						BM02 = MAX(CASE WHEN SequenceBM & 2 > 0 THEN 1 ELSE 0 END),
						BM04 = MAX(CASE WHEN SequenceBM & 4 > 0 THEN 1 ELSE 0 END),
						BM08 = MAX(CASE WHEN SequenceBM & 8 > 0 THEN 1 ELSE 0 END),
						BM16 = MAX(CASE WHEN SequenceBM & 16 > 0 THEN 1 ELSE 0 END),
						BM32 = MAX(CASE WHEN SequenceBM & 32 > 0 THEN 1 ELSE 0 END)
					FROM 
						#MemberSelection
					WHERE
						DimensionID = -17 AND --OrderState
						SequenceBM <> 0
					GROUP BY
						DimensionID

					UNION SELECT
						DimensionID,
						BM01 = MAX(CASE WHEN SequenceBM & 1 > 0 THEN 1 ELSE 0 END),
						BM02 = MAX(CASE WHEN SequenceBM & 2 > 0 THEN 1 ELSE 0 END),
						BM04 = MAX(CASE WHEN SequenceBM & 4 > 0 THEN 1 ELSE 0 END),
						BM08 = MAX(CASE WHEN SequenceBM & 8 > 0 THEN 1 ELSE 0 END),
						BM16 = MAX(CASE WHEN SequenceBM & 16 > 0 THEN 1 ELSE 0 END),
						BM32 = MAX(CASE WHEN SequenceBM & 32 > 0 THEN 1 ELSE 0 END)
					FROM 
						#MemberSelection
					WHERE
						DimensionID = -1 AND --Measure/Account
						SequenceBM <> 0
					GROUP BY
						DimensionID
					) sub
			END
		
		IF @DebugBM & 2 > 0 
			SELECT
				[@SourceDatabase] = @SourceDatabase,
				[@Owner] = @Owner,
				[@StartYear] = @StartYear,
				[@StartDate] = @StartDate,
				[@MasterClosedYear] = @MasterClosedYear,
				[@SourceID] = @SourceID,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName,
				[@DataClassID] = @DataClassID,
				[@SequenceBM] = @SequenceBM,
				[@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'Create temp table #DC_Sales_Raw'
		IF OBJECT_ID(N'TempDB.dbo.#DC_Sales_Raw', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #DC_Sales_Raw
					(
					--[Currency] [nvarchar](10) COLLATE DATABASE_DEFAULT,
					[Document_Currency] [nvarchar](10) COLLATE DATABASE_DEFAULT,
					[Customer] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Entity] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[InvoiceNo_AR] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[OrderLine] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[OrderNo] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[OrderState] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[OrderType] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Plant] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Product] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[TimeDay] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[SalesPrice_] [float] DEFAULT (0),
					[SalesMiscCharge_] [float] DEFAULT (0),
					[SalesDiscount_] [float] DEFAULT (0),
					[SalesCOGSLabor] [float] DEFAULT (0),
					[SalesCOGSMater] [float] DEFAULT (0),
					[SalesCOGSBurden] [float] DEFAULT (0),
					[SalesCOGSSubCont] [float] DEFAULT (0),
					[SalesCOGSMatBurd] [float] DEFAULT (0),
					[SalesCOGSLabor_Unit] [float] DEFAULT (0),
					[SalesCOGSMater_Unit] [float] DEFAULT (0),
					[SalesCOGSBurden_Unit] [float] DEFAULT (0),
					[SalesCOGSSubCont_Unit] [float] DEFAULT (0),
					[SalesCOGSMatBurd_Unit] [float] DEFAULT (0),
					[SalesQtyUnit_] [float] DEFAULT (0),
					[SalesQtyOrder_] [float] DEFAULT (0),
					[SalesQtyOrderLine_] [float] DEFAULT (0)
					)
			END

	SET @Step = 'Create source temp tables'
		CREATE TABLE [dbo].[#Customer]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[CustNum] [int],
			[CustID] [nvarchar](10) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE [dbo].[#Entity]
			(
			[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Currency] [nchar](3) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE [dbo].[#OD]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[OrderNum] [int],
			[OrderLine] [int],
			[CurrencyCode] [nvarchar](4) COLLATE DATABASE_DEFAULT,
			[CustNum] [int],
			[ShipToNum] [nvarchar](14) COLLATE DATABASE_DEFAULT,
			[OrderDate] [date],
			[NeedByDate] [date],
			[ShipDate] [date],
			[DocUnitPrice] [numeric](17, 5),
			[VoidLine] [bit],
			[PartNum] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[DocExtPriceDtl] [numeric](17, 3),
			[DocDiscount] [numeric](17, 3),
			[SellingQuantity] [numeric](22, 8),
			[OrderQty] [numeric](22, 8),
			[SalesUM] [nvarchar](6) COLLATE DATABASE_DEFAULT,
			[IUM] [nvarchar](6) COLLATE DATABASE_DEFAULT,
			[Plant] [nvarchar](8) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE [dbo].[#OH]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[OrderNum] [int],
			[CurrencyCode] [nvarchar](4) COLLATE DATABASE_DEFAULT,
			[ShipToNum] [nvarchar](14) COLLATE DATABASE_DEFAULT,
			[CustNum] [int],
			[OrderDate] [date],
			[NeedByDate] [date],
			[ShipDate] [date]
			)

		CREATE TABLE [dbo].[#Part]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[PartNum] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[UOMClassID] [nvarchar](12) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE [dbo].[#PartCost]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[PartNum] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[CostID] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[AvgLaborCost] [numeric](18, 5),
			[FIFOAvgLaborCost] [numeric](18, 5),
			[LastLaborCost] [numeric](18, 5),
			[StdLaborCost] [numeric](17, 5),
			[AvgMaterialCost] [numeric](15, 5),
			[FIFOAvgMaterialCost] [numeric](15, 5),
			[LastMaterialCost] [numeric](15, 5),
			[StdMaterialCost] [numeric](17, 5),
			[AvgBurdenCost] [numeric](18, 5),
			[FIFOAvgBurdenCost] [numeric](18, 5),
			[LastBurdenCost] [numeric](18, 5),
			[StdBurdenCost] [numeric](18, 5),
			[AvgSubContCost] [numeric](15, 5),
			[FIFOAvgSubContCost] [numeric](15, 5),
			[LastSubContCost] [numeric](15, 5),
			[StdSubContCost] [numeric](17, 5),
			[AvgMtlBurCost] [numeric](15, 5),
			[FIFOAvgMtlBurCost] [numeric](15, 5),
			[LastMtlBurCost] [numeric](15, 5),
			[StdMtlBurCost] [numeric](17, 5)
			)

		CREATE TABLE [dbo].[#PartPlant]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[Plant] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[PartNum] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[CostMethod] [nvarchar](2) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE [dbo].[#Plant]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[Plant] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[PlantCostID] [nvarchar](8) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE [dbo].[#UOMConv]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[UOMClassID] [nvarchar](12) COLLATE DATABASE_DEFAULT,
			[UOMCode] [nvarchar](6) COLLATE DATABASE_DEFAULT,
			[ConvFactor] [decimal](17, 7)
			)

		CREATE TABLE [dbo].[#IH]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[InvoiceNum] [int],
			[InvoiceDate] [date],
			[DueDate] [date],
			[ClosedDate] [date],
			[OrderNum] [int],
			[CustNum] [int],
			[ShipToNum] [nvarchar](14) COLLATE DATABASE_DEFAULT,
			)

		CREATE TABLE [dbo].[#ID]
			(
			[Company] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[InvoiceNum] [int],
			[InvoiceLine] [int],
			[InvoiceDate] [date],
			[DueDate] [date],
			[ClosedDate] [date],
			[PartNum] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[ShipToNum] [nvarchar](14) COLLATE DATABASE_DEFAULT,
			[OrderLine] [int],			
			[DocExtPrice] [numeric](17, 3),
			[DocTotalMiscChrg] [numeric](17, 3),
			[DocDiscount] [numeric](17, 3),			
			[SalesUM] [nvarchar](6) COLLATE DATABASE_DEFAULT,
			[IUM] [nvarchar](6) COLLATE DATABASE_DEFAULT,
			[SellingShipQty] [numeric](22, 8),
			[OurOrderQty] [numeric](22, 8),
			[LbrUnitCost] [numeric](17, 5),
			[MtlUnitCost] [numeric](17, 5),
			[BurUnitCost] [numeric](17, 5),
			[SubUnitCost] [numeric](17, 5),
			[MtlBurUnitCost] [numeric](17, 5),
			[CustNum] [int],
			[CreditMemo] [bit],
			[InvoiceRef] [int],
			[InvoiceLineRef] [int],
			[Plant] [nvarchar](8) COLLATE DATABASE_DEFAULT,
			[CurrencyCode] [nvarchar](4) COLLATE DATABASE_DEFAULT,
			[OrderNum] [int],
			[CorrectionInv] [bit],
			[InvoiceType] [nvarchar](3) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Fill temp table #Entity'
		SET @StepStartTime = GETDATE()
		
		TRUNCATE TABLE #Entity
		
		INSERT INTO #Entity
			(
			[Entity],
			[Currency]
			)
		SELECT
			[Entity] = E.MemberKey,
			[Currency] = EB.Currency
		FROM
			[pcINTEGRATOR_Data].[dbo].Entity E 
			INNER JOIN [pcINTEGRATOR_Data].[dbo].Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 8 > 0 AND EB.SelectYN <> 0
		WHERE	
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.[MemberKey] = @Entity OR @Entity IS NULL) AND
			E.[SelectYN] <> 0

		SELECT @EntityString = @EntityString + '''' + [Entity] + '''' + ',' FROM #Entity ORDER BY [Entity]
		SET @EntityString = LEFT(@EntityString, LEN(@EntityString) -1)

		IF @DebugBM & 2 > 0 SELECT Step = '#Entity', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Entity
		IF @DebugBM & 8 > 0 SELECT TempTable = '#Entity', * FROM #Entity
		IF @DebugBM & 2 > 0 SELECT [@EntityString] = @EntityString

		IF @SourceTypeID IN (1, 11) --Epicor ERP
			BEGIN

	SET @Step = '@SequenceBMStep = 3, Orders'
		IF @SequenceBM & 3 > 0
			BEGIN
				--#OH
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #OH
				
				SET @SQLStatement = '
					INSERT INTO	#OH
						(
						[Company],
						[OrderNum],
						[CurrencyCode],
						[CustNum],
						[ShipToNum],
						[OrderDate],
						[NeedByDate]
						)
					SELECT
						[Company],
						[OrderNum],
						OH.[CurrencyCode],
						OH.[CustNum],
						OH.[ShipToNum],
						OH.[OrderDate],
						OH.[NeedByDate]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[OrderHed] OH
					WHERE
						OH.[Company] IN (' + @EntityString + ') AND
						(OH.[OrderDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'' OR OH.[NeedByDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'')
						' + CASE WHEN @StartDate IS NOT NULL THEN 'AND (OH.[OrderDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''' OR OH.[NeedByDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''')' ELSE '' END

				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Order; #OH', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #OH
				IF @DebugBM & 8 > 0 SELECT TempTable = '#OH', * FROM #OH

				--#Customer
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #Customer

				SET @SQLStatement = '
					INSERT INTO #Customer
						(
						[Company],
						[CustNum],
						[CustID]
						)
					SELECT
						[Company] = C.[Company],
						[CustNum] = C.[CustNum],
						[CustID] = C.[CustID]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[Customer] C
						INNER JOIN (SELECT DISTINCT [Company], [CustNum] FROM #OH) D ON D.[Company] = C.[Company] AND D.[CustNum] = C.[CustNum]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Order; #Customer', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Customer
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Customer', * FROM #Customer
			END

	SET @Step = '@SequenceBMStep = 1, Orders, Value'
		IF @SequenceBM & 1 > 0
			BEGIN
				--#OD
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #OD

				SET @SQLStatement = '
					INSERT INTO #OD
						(
						[Company],
						[OrderNum],
						[OrderLine],
						[CurrencyCode],
						[CustNum],
						[ShipToNum],
						[OrderDate],
						[NeedByDate],
						[DocUnitPrice],
						[VoidLine],
						[PartNum],
						[DocExtPriceDtl],
						[DocDiscount],
						[SellingQuantity],
						[OrderQty],
						[SalesUM],
						[IUM],
						[Plant]
						)
					SELECT 
						[Company] = OD.[Company],
						[OrderNum] = OD.[OrderNum],
						[OrderLine] = OD.[OrderLine],
						[CurrencyCode] = MAX(OH.CurrencyCode),
						[CustNum] = MAX(OH.CustNum),
						[ShipToNum] = MAX(OH.ShipToNum),
						[OrderDate] = MAX(OH.OrderDate),
						[NeedByDate] = MAX(OH.NeedByDate),
						[DocUnitPrice] = MAX(OD.DocUnitPrice),
						[VoidLine] = CONVERT(bit, MAX(CONVERT(int, OD.VoidLine))),
						[PartNum] = MAX(OD.PartNum),
						[DocExtPriceDtl] = MAX(OD.DocExtPriceDtl),
						[DocDiscount] = MAX(OD.DocDiscount),
						[SellingQuantity] = MAX(OD.SellingQuantity),
						[OrderQty] = MAX(OD.[OrderQty]),
						[SalesUM] = MAX(OD.SalesUM),
						[IUM] = MAX(OD.IUM),
						[Plant] = MAX([OR].[Plant])
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[OrderHed] OH
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[OrderDtl] [OD] ON [OD].[Company] = [OH].[Company] AND [OD].[OrderNum] = [OH].[OrderNum]
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[OrderRel] [OR] ON [OR].[Company] = [OD].[Company] AND [OR].[OrderNum] = [OD].[OrderNum] AND [OR].[OrderLine] = [OD].[OrderLine]
					WHERE
						OH.[Company] IN (' + @EntityString + ') AND
						(OH.[OrderDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'' OR OH.[NeedByDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'')
						' + CASE WHEN @StartDate IS NOT NULL THEN 'AND (OH.[OrderDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''' OR OH.[NeedByDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''')' ELSE '' END + '
					GROUP BY
						OD.[Company],
						OD.[OrderNum],
						OD.[OrderLine]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				
				IF @DebugBM & 2 > 0 SELECT Step = 'Order; #OD', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #OD
				IF @DebugBM & 8 > 0 SELECT TempTable = '#OD', * FROM #OD

				--#Part
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #Part

				SET @SQLStatement = '
					INSERT INTO #Part
						(
						[Company],
						[PartNum],
						[UOMClassID]
						)
					SELECT
						P.[Company],
						P.[PartNum],
						P.[UOMClassID]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].Part P
						INNER JOIN (SELECT DISTINCT [Company], [PartNum] FROM #OD) D ON D.[Company] = P.[Company] AND D.[PartNum] = P.[PartNum]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Order; #Part', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Part
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Part', * FROM #Part

				--#UOMConv
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #UOMConv

				SET @SQLStatement = '
					INSERT INTO #UOMConv
						(
						[Company],
						[UOMClassID],
						[UOMCode],
						[ConvFactor]
						)
					SELECT
						[Company] = UOM.[Company],
						[UOMClassID] = UOM.[UOMClassID],
						[UOMCode] = UOM.[UOMCode],
						[ConvFactor] = UOM.[ConvFactor]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[UOMConv] UOM
						INNER JOIN (SELECT DISTINCT [Company], [UOMCode] = [SalesUM] FROM #OD UNION SELECT DISTINCT [Company], [UOMCode] = [IUM] FROM #OD) D ON D.[Company] = UOM.[Company] AND D.[UOMCode] = UOM.[UOMCode]
						INNER JOIN (SELECT DISTINCT [Company], [UOMClassID] FROM #Part) P ON P.[Company] = UOM.[Company] AND P.[UOMClassID] = UOM.[UOMClassID]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Order; #UOMConv', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #UOMConv
				IF @DebugBM & 8 > 0 SELECT TempTable = '#UOMConv', * FROM #UOMConv

				--#Plant
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #Plant

				SET @SQLStatement = '
					INSERT INTO #Plant
						(
						[Company],
						[Plant],
						[PlantCostID]
						)
					SELECT
						[Company],
						[Plant],
						[PlantCostID]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[Plant]
					WHERE
						LEN([PlantCostID]) > 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Order; #Plant', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Plant
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Plant', * FROM #Plant

				--#PartPlant
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #PartPlant

				SET @SQLStatement = '
					INSERT INTO #PartPlant
						(
						[Company],
						[Plant],
						[PartNum],
						[CostMethod]
						)

					SELECT
						[Company] = PP.[Company],
						[Plant] = PP.[Plant],
						[PartNum] = PP.[PartNum],
						[CostMethod] = PP.[CostMethod]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[PartPlant] PP
						INNER JOIN #Plant Plant ON Plant.[Company] = PP.[Company] AND Plant.[Plant] = PP.[Plant]
						INNER JOIN #Part P ON P.[Company] = PP.[Company] AND P.[PartNum] = PP.[PartNum]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Order; #PartPlant', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #PartPlant
				IF @DebugBM & 8 > 0 SELECT TempTable = '#PartPlant', * FROM #PartPlant

				--#PartCost
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #PartCost

				SET @SQLStatement = '
					INSERT INTO #PartCost
						(
						[Company],
						[PartNum],
						[CostID], 
						[AvgLaborCost],
						[FIFOAvgLaborCost],
						[LastLaborCost],
						[StdLaborCost],
						[AvgMaterialCost],
						[FIFOAvgMaterialCost],
						[LastMaterialCost],
						[StdMaterialCost],
						[AvgBurdenCost],
						[FIFOAvgBurdenCost],
						[LastBurdenCost],
						[StdBurdenCost],
						[AvgSubContCost],
						[FIFOAvgSubContCost],
						[LastSubContCost],
						[StdSubContCost],
						[AvgMtlBurCost],
						[FIFOAvgMtlBurCost],
						[LastMtlBurCost],
						[StdMtlBurCost]
						)
					SELECT
						PC.[Company],
						PC.[PartNum],
						PC.[CostID], 
						PC.[AvgLaborCost],
						PC.[FIFOAvgLaborCost],
						PC.[LastLaborCost],
						PC.[StdLaborCost],
						PC.[AvgMaterialCost],
						PC.[FIFOAvgMaterialCost],
						PC.[LastMaterialCost],
						PC.[StdMaterialCost],
						PC.[AvgBurdenCost],
						PC.[FIFOAvgBurdenCost],
						PC.[LastBurdenCost],
						PC.[StdBurdenCost],
						PC.[AvgSubContCost],
						PC.[FIFOAvgSubContCost],
						PC.[LastSubContCost],
						PC.[StdSubContCost],
						PC.[AvgMtlBurCost],
						PC.[FIFOAvgMtlBurCost],
						PC.[LastMtlBurCost],
						PC.[StdMtlBurCost]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[PartCost]  PC
						INNER JOIN #Part P ON P.Company = PC.Company AND P.PartNum = PC.PartNum'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Order; #PartCost', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #PartCost
				IF @DebugBM & 8 > 0 SELECT TempTable = '#PartCost', * FROM #PartCost

				--#DC_Sales_Raw
				SET @StepStartTime = GETDATE()

				SET @SQLStatement = '
				INSERT INTO [#DC_Sales_Raw]
					(
					[Document_Currency],
					[Customer],
					[Entity],
					[InvoiceNo_AR],
					[OrderLine],
					[OrderNo],
					[OrderState],
					[OrderType],
					[Plant],
					[Product],
					[TimeDay],
					[SalesPrice_],
					[SalesDiscount_],
					[SalesCOGSLabor],
					[SalesCOGSMater],
					[SalesCOGSBurden],
					[SalesCOGSSubCont],
					[SalesCOGSMatBurd],'

				IF (SELECT COUNT(*) FROM #MemberSelection WHERE [Label] like '%Unit') <> 0
					BEGIN

					SET @SQLStatement = @SQLStatement + '
					[SalesCOGSLabor_Unit],
					[SalesCOGSMater_Unit],
					[SalesCOGSBurden_Unit],
					[SalesCOGSSubCont_Unit],
					[SalesCOGSMatBurd_Unit],'

					END

				SET @SQLStatement = @SQLStatement + '
					[SalesQtyUnit_],
					[SalesQtyOrderLine_]
					)
				SELECT
					[Document_Currency] = MAX(OD.[CurrencyCode]),
					[Customer] = C.[CustID] + CASE WHEN LEN(ISNULL(OD.[ShipToNum], '''')) = 0 THEN '''' ELSE ''_'' + OD.[ShipToNum] END,
					[Entity] = OD.[Company],
					[InvoiceNo_AR] = OD.[Company] + ''_'' + ''NONE'',
					[OrderLine] = CONVERT(nvarchar(255), OD.[OrderLine]),
					
					[OrderNo] = OD.[Company] + ''_'' + RIGHT(''0000000'' + CONVERT(nvarchar(255), OD.[OrderNum]),7) COLLATE DATABASE_DEFAULT,
					[OrderState] = OS.[Label],
					[OrderType] = CASE WHEN SUM(OD.[DocUnitPrice]) = 0 THEN ''FOC'' ELSE
									CASE WHEN MAX(CONVERT(int, OD.[VoidLine])) = 0 THEN ''UNMARKED'' ELSE ''CUSCANCEL'' END
									END,
					[Plant] = MAX(OD.[Plant]),
					[Product] = OD.[PartNum],
					[TimeDay] = MAX(CASE OS.[Label] WHEN ''20'' THEN CONVERT(nvarchar(10), OD.OrderDate, 112) WHEN ''40'' THEN CONVERT(nvarchar(10), OD.[NeedByDate], 112) END),
					[SalesPrice_] = SUM(OD.[DocExtPriceDtl]), 
					[SalesDiscount_] = SUM(-1 * OD.[DocDiscount]),

					[SalesCOGSLabor] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgLaborCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgLaborCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastLaborCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdLaborCost], 0)) ELSE 0 END,
					[SalesCOGSMater] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgMaterialCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgMaterialCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastMaterialCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdMaterialCost], 0)) ELSE 0 END,
					[SalesCOGSBurden] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgBurdenCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgBurdenCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastBurdenCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdBurdenCost], 0)) ELSE 0 END,
					[SalesCOGSSubCont] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgSubContCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgSubContCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastSubContCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdSubContCost], 0)) ELSE 0 END,
					[SalesCOGSMatBurd] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgMtlBurCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgMtlBurCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastMtlBurCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdMtlBurCost], 0)) ELSE 0 END,'
					
					IF (SELECT COUNT(*) FROM #MemberSelection WHERE [Label] like '%Unit') <> 0
						BEGIN

						SET @SQLStatement = @SQLStatement + '
							[SalesCOGSLabor_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgLaborCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgLaborCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastLaborCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdLaborCost], 0)) ELSE 0 END,
							[SalesCOGSMater_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgMaterialCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgMaterialCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastMaterialCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdMaterialCost], 0)) ELSE 0 END,
							[SalesCOGSBurden_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgBurdenCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgBurdenCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastBurdenCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdBurdenCost], 0)) ELSE 0 END,
							[SalesCOGSSubCont_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgSubContCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgSubContCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastSubContCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdSubContCost], 0)) ELSE 0 END,
							[SalesCOGSMatBurd_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgMtlBurCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgMtlBurCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastMtlBurCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdMtlBurCost], 0)) ELSE 0 END,'
						END
					
				SET @SQLStatement = @SQLStatement + '
					[SalesQtyUnit_] = SUM(OD.[OrderQty]),
					[SalesQtyOrderLine_] = 1
				
					FROM
						#OD OD
						INNER JOIN #Part P ON P.[Company] = OD.[Company] AND P.[PartNum] = OD.[PartNum]
						INNER JOIN #Customer C ON C.[Company] = OD.[Company] AND C.[CustNum] = OD.[CustNum]
						INNER JOIN #MemberSelection OS ON OS.DimensionID = -17 AND OS.[SequenceBM] & 1 > 0 AND (OS.[Label] = CASE WHEN OD.OrderDate IS NOT NULL THEN ''20'' END OR OS.[Label] = CASE WHEN OD.NeedByDate IS NOT NULL THEN ''40'' END)
						LEFT JOIN #UOMConv SIUM ON SIUM.[Company] = OD.[Company] AND SIUM.[UOMClassID] = P.[UOMClassID] AND SIUM.[UOMCode] = OD.[SalesUM] 
						LEFT JOIN #UOMConv IUM ON IUM.[Company] = OD.[Company] AND IUM.[UOMClassID] = P.[UOMClassID] AND IUM.[UOMCode] = OD.[IUM] 
						LEFT JOIN #Plant Plant ON Plant.[Company] = OD.[Company] AND Plant.[Plant] = OD.[Plant]
						LEFT JOIN #PartPlant PP ON PP.[Company] = OD.[Company] AND PP.[Plant] = OD.[Plant] AND PP.[PartNum] = OD.[PartNum]
						LEFT JOIN #PartCost PC ON PC.[Company] = OD.[Company] AND PC.[PartNum] = OD.[PartNum] AND PC.[CostID] = Plant.[PlantCostID]
					GROUP BY 
						C.[CustID] + CASE WHEN LEN(ISNULL(OD.[ShipToNum], '''')) = 0 THEN '''' ELSE ''_'' + OD.[ShipToNum] END,
						OD.[Company],
						CONVERT(nvarchar(255), OD.[OrderLine]),
						OD.[Company] + ''_'' + RIGHT(''0000000'' + CONVERT(nvarchar(255), OD.[OrderNum]),7) COLLATE DATABASE_DEFAULT,
						OS.[Label],
						OD.[PartNum]'

				SET @RowCount = @@RowCount
				SET @Selected = @Selected + @RowCount

				IF @DebugBM & 2 > 0 SELECT [@SQLStatement] = @SQLStatement
				EXEC(@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = '#DC_Sales_Raw, SequenceBM = 1', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = @RowCount
			END

	SET @Step = '@SequenceBMStep = 2, Orders, Count'
		IF @SequenceBM & 2 > 0
			BEGIN
				--#DC_Sales_Raw
				SET @StepStartTime = GETDATE()

				INSERT INTO [#DC_Sales_Raw]
					(
					[Document_Currency],
					[Customer],
					[Entity],
					[InvoiceNo_AR],
					[OrderLine],
					[OrderNo],
					[OrderState],
					[OrderType],
					[Plant],
					[Product],
					[TimeDay],
					[SalesQtyOrder_]
					)
				SELECT
					[Document_Currency] = OD.CurrencyCode,
					[Customer] = C.CustID + CASE WHEN LEN(ISNULL(OD.ShipToNum, '')) = 0 THEN '' ELSE '_' + OD.ShipToNum END,
					[Entity] = OD.Company,
					[InvoiceNo_AR] = OD.Company + '_' + 'NONE',
					[OrderLine] = 'NONE',
					[OrderNo] = OD.Company + '_' + (CASE LEN(OD.[OrderNum]) WHEN 1 THEN '000000' WHEN 2 THEN '00000'  WHEN 3 THEN '0000'  WHEN 4 THEN '000'  WHEN 5 THEN '00' WHEN 6 THEN '0' ELSE '' END + CONVERT(nvarchar(255), OD.OrderNum)) COLLATE DATABASE_DEFAULT,
					[OrderState] = OS.[Label],
					[OrderType] = 'NONE',
					[Plant] = 'NONE',
					[Product] = 'NONE',
					[TimeDay] = CASE OS.[Label] WHEN '20' THEN CONVERT(nvarchar(10), OD.OrderDate, 112) WHEN '40' THEN CONVERT(nvarchar(10), OD.NeedByDate, 112) END,
					[SalesQtyOrder_] = 1
				FROM
					#OH OD
					INNER JOIN #Customer C ON C.Company = OD.Company AND C.CustNum = OD.CustNum
					INNER JOIN #MemberSelection OS ON OS.DimensionID = -17 AND OS.SequenceBM & 2 > 0 AND (OS.[Label] = CASE WHEN OD.OrderDate IS NOT NULL THEN '20' END OR OS.[Label] = CASE WHEN OD.NeedByDate IS NOT NULL THEN '40' END)

				SET @RowCount = @@RowCount
				SET @Selected = @Selected + @RowCount

				IF @DebugBM & 2 > 0 SELECT Step = '#DC_Sales_Raw, SequenceBM = 2', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = @RowCount
			END

	SET @Step = '@SequenceBMStep = 12, Shipment'
		IF @SequenceBM & 12 > 0
			BEGIN
				--#OH
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #OH
		
				SET @SQLStatement = '
					INSERT INTO	#OH
						(
						[Company],
						[OrderNum],
						[CurrencyCode],
						[CustNum],
						[ShipToNum],
						[ShipDate]
						)
					SELECT
						[Company] = OH.[Company],
						[OrderNum] = OH.[OrderNum],
						[CurrencyCode] = MAX(OH.[CurrencyCode]),
						[CustNum] = MAX(SH.[ShipToCustNum]),
						[ShipToNum] = MAX(SH.[ShipToNum]),
						[ShipDate] = MAX(SD.[ShipDate])
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[ShipHead] SH 
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[ShipDtl] SD ON SD.[Company] = SH.[Company] AND SD.[PackNum] = SH.[PackNum]
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[OrderHed] OH ON OH.[Company] = SH.[Company] AND OH.[OrderNum] = SD.[OrderNum]
					WHERE
						SH.[Company] IN (' + @EntityString + ') AND
						SD.[ShipDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01''
						' + CASE WHEN @StartDate IS NOT NULL THEN 'AND SD.[ShipDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + '''' ELSE '' END + '
					GROUP BY
						OH.[Company],
						OH.[OrderNum]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Shipment; #OH', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #OH
				IF @DebugBM & 8 > 0 SELECT TempTable = '#OH', * FROM #OH

				--#Customer
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #Customer

				SET @SQLStatement = '
					INSERT INTO #Customer
						(
						[Company],
						[CustNum],
						[CustID]
						)
					SELECT
						[Company] = C.[Company],
						[CustNum] = C.[CustNum],
						[CustID] = C.[CustID]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[Customer] C
						INNER JOIN (SELECT DISTINCT [Company], [CustNum] FROM #OH) D ON D.[Company] = C.[Company] AND D.[CustNum] = C.[CustNum]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Shipment; #Customer', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Customer
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Customer', * FROM #Customer
			END

	SET @Step = '@SequenceBMStep = 4, Shipment, Values'
		IF @SequenceBM & 4 > 0
			BEGIN
				--#OD
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #OD

				SET @SQLStatement = '
					INSERT INTO #OD
						(
						[Company],
						[OrderNum],
						[OrderLine],
						[CurrencyCode],
						[CustNum],
						[ShipToNum],
						[ShipDate],
						[DocUnitPrice],
						[VoidLine],
						[PartNum],
						[DocExtPriceDtl],
						[DocDiscount],
						[SellingQuantity],
						[OrderQty],
						[SalesUM],
						[IUM],
						[Plant]
						)
					SELECT 
						[Company] = OD.[Company],
						[OrderNum] = OD.[OrderNum],
						[OrderLine] = OD.[OrderLine],
						[CurrencyCode] = MAX(OH.CurrencyCode),
						[CustNum] = MAX(SH.ShipToCustNum),
						[ShipToNum] = MAX(SH.ShipToNum),
						[ShipDate] = MAX(SD.ShipDate),
						[DocUnitPrice] = MAX(OD.DocUnitPrice),
						[VoidLine] = CONVERT(bit, MAX(CONVERT(int, OD.VoidLine))),
						[PartNum] = MAX(OD.PartNum),
						[DocExtPriceDtl] = MAX(OD.DocExtPriceDtl),
						[DocDiscount] = MAX(OD.DocDiscount),
						[SellingQuantity] = MAX(OD.SellingQuantity),
						[OrderQty] = MAX(OD.[OrderQty]),
						[SalesUM] = MAX(OD.SalesUM),
						[IUM] = MAX(OD.IUM),
						[Plant] = MAX([OR].[Plant])
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[ShipHead] SH 
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[ShipDtl] SD ON SD.Company = SH.Company AND SD.PackNum = SH.PackNum
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[OrderHed] OH ON OH.Company = SH.Company AND OH.OrderNum = SD.OrderNum
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[OrderDtl] OD ON OD.Company = SH.Company AND OD.OrderNum = SD.OrderNum AND OD.OrderLine = SD.OrderLine
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[OrderRel] [OR] ON [OR].[Company] = [OD].[Company] AND [OR].[OrderNum] = [OD].[OrderNum] AND [OR].[OrderLine] = [OD].[OrderLine]
					WHERE
						SH.Company IN (' + @EntityString + ') AND
						SD.[ShipDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01''
						' + CASE WHEN @StartDate IS NOT NULL THEN 'AND SD.[ShipDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + '''' ELSE '' END + '
					GROUP BY
						OD.[Company],
						OD.[OrderNum],
						OD.[OrderLine]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				
				IF @DebugBM & 2 > 0 SELECT Step = 'Shipment; #OD', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #OD
				IF @DebugBM & 8 > 0 SELECT TempTable = '#OD', * FROM #OD

				--#Part
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #Part

				SET @SQLStatement = '
					INSERT INTO #Part
						(
						[Company],
						[PartNum],
						[UOMClassID]
						)
					SELECT
						P.[Company],
						P.[PartNum],
						P.[UOMClassID]
				
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].Part P
						INNER JOIN (SELECT DISTINCT [Company], [PartNum] FROM #OD) D ON D.[Company] = P.[Company] AND D.[PartNum] = P.[PartNum]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Shipment; #Part', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Part
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Part', * FROM #Part

				--#UOMConv
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #UOMConv

				SET @SQLStatement = '
					INSERT INTO #UOMConv
						(
						[Company],
						[UOMClassID],
						[UOMCode],
						[ConvFactor]
						)
					SELECT
						[Company] = UOM.[Company],
						[UOMClassID] = UOM.[UOMClassID],
						[UOMCode] = UOM.[UOMCode],
						[ConvFactor] = UOM.[ConvFactor]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[UOMConv] UOM
						INNER JOIN (SELECT DISTINCT [Company], [UOMCode] = [SalesUM] FROM #OD UNION SELECT DISTINCT [Company], [UOMCode] = [IUM] FROM #OD) D ON D.[Company] = UOM.[Company] AND D.[UOMCode] = UOM.[UOMCode]
						INNER JOIN (SELECT DISTINCT [Company], [UOMClassID] FROM #Part) P ON P.[Company] = UOM.[Company] AND P.[UOMClassID] = UOM.[UOMClassID]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Shipment; #UOMConv', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #UOMConv
				IF @DebugBM & 8 > 0 SELECT TempTable = '#UOMConv', * FROM #UOMConv

				--#Plant
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #Plant

				SET @SQLStatement = '
					INSERT INTO #Plant
						(
						[Company],
						[Plant],
						[PlantCostID]
						)
					SELECT
						[Company],
						[Plant],
						[PlantCostID]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[Plant]
					WHERE
						LEN(PlantCostID) > 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Shipment; #Plant', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Plant
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Plant', * FROM #Plant

				--#PartPlant
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #PartPlant

				SET @SQLStatement = '
					INSERT INTO #PartPlant
						(
						[Company],
						[Plant],
						[PartNum],
						[CostMethod]
						)

					SELECT
						[Company] = PP.[Company],
						[Plant] = PP.[Plant],
						[PartNum] = PP.[PartNum],
						[CostMethod] = PP.[CostMethod]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[PartPlant] PP
						INNER JOIN #Plant Plant ON Plant.Company = PP.Company AND Plant.Plant = PP.Plant
						INNER JOIN #Part P ON P.Company = PP.Company AND P.PartNum = PP.PartNum'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Shipment; #PartPlant', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #PartPlant
				IF @DebugBM & 8 > 0 SELECT TempTable = '#PartPlant', * FROM #PartPlant

				--#PartCost
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #PartCost

				SET @SQLStatement = '
					INSERT INTO #PartCost
						(
						[Company],
						[PartNum],
						[CostID], 
						[AvgLaborCost],
						[FIFOAvgLaborCost],
						[LastLaborCost],
						[StdLaborCost],
						[AvgMaterialCost],
						[FIFOAvgMaterialCost],
						[LastMaterialCost],
						[StdMaterialCost],
						[AvgBurdenCost],
						[FIFOAvgBurdenCost],
						[LastBurdenCost],
						[StdBurdenCost],
						[AvgSubContCost],
						[FIFOAvgSubContCost],
						[LastSubContCost],
						[StdSubContCost],
						[AvgMtlBurCost],
						[FIFOAvgMtlBurCost],
						[LastMtlBurCost],
						[StdMtlBurCost]
						)
					SELECT
						PC.[Company],
						PC.[PartNum],
						PC.[CostID], 
						PC.[AvgLaborCost],
						PC.[FIFOAvgLaborCost],
						PC.[LastLaborCost],
						PC.[StdLaborCost],
						PC.[AvgMaterialCost],
						PC.[FIFOAvgMaterialCost],
						PC.[LastMaterialCost],
						PC.[StdMaterialCost],
						PC.[AvgBurdenCost],
						PC.[FIFOAvgBurdenCost],
						PC.[LastBurdenCost],
						PC.[StdBurdenCost],
						PC.[AvgSubContCost],
						PC.[FIFOAvgSubContCost],
						PC.[LastSubContCost],
						PC.[StdSubContCost],
						PC.[AvgMtlBurCost],
						PC.[FIFOAvgMtlBurCost],
						PC.[LastMtlBurCost],
						PC.[StdMtlBurCost]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[PartCost]  PC
						INNER JOIN #Part P ON P.Company = PC.Company AND P.PartNum = PC.PartNum'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Shipment; #PartCost', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #PartCost
				IF @DebugBM & 8 > 0 SELECT TempTable = '#PartCost', * FROM #PartCost

				--#DC_Sales_Raw
				SET @StepStartTime = GETDATE()

				SET @SQLStatement = '
				INSERT INTO [#DC_Sales_Raw]
					(
					[Document_Currency],
					[Customer],
					[Entity],
					[InvoiceNo_AR],
					[OrderLine],
					[OrderNo],
					[OrderState],
					[OrderType],
					[Plant],
					[Product],
					[TimeDay],
					[SalesPrice_],
					[SalesDiscount_],
					[SalesCOGSLabor],
					[SalesCOGSMater],
					[SalesCOGSBurden],
					[SalesCOGSSubCont],
					[SalesCOGSMatBurd],'
					
				IF (SELECT COUNT(*) FROM #MemberSelection WHERE [Label] like '%Unit') <> 0
					BEGIN

						SET @SQLStatement = @SQLStatement + '
						[SalesCOGSLabor_Unit],
						[SalesCOGSMater_Unit],
						[SalesCOGSBurden_Unit],
						[SalesCOGSSubCont_Unit],
						[SalesCOGSMatBurd_Unit],'

					END
				SET @SQLStatement = @SQLStatement + '
					[SalesQtyUnit_],
					[SalesQtyOrderLine_]
					)
				SELECT
					[Document_Currency] = MAX(OD.[CurrencyCode]),
					[Customer] = C.[CustID] + CASE WHEN LEN(ISNULL(OD.[ShipToNum], '''')) = 0 THEN '''' ELSE ''_'' + OD.[ShipToNum] END,
					[Entity] = OD.[Company],
					[InvoiceNo_AR] = OD.[Company] + ''_'' + ''NONE'',
					[OrderLine] = CONVERT(nvarchar(255), OD.[OrderLine]),
					[OrderNo] = OD.[Company] + ''_'' + RIGHT(''0000000'' + CONVERT(nvarchar(255), OD.[OrderNum]),7) COLLATE DATABASE_DEFAULT,
					[OrderState] = OS.[Label],
					[OrderType] = CASE WHEN SUM(OD.DocUnitPrice) = 0 THEN ''FOC'' ELSE
									CASE WHEN MAX(CONVERT(int, OD.VoidLine)) = 0 THEN ''UNMARKED'' ELSE ''CUSCANCEL'' END
									END,
					[Plant] = MAX(OD.[Plant]),
					[Product] = OD.[PartNum],
					[TimeDay] = MAX(CASE OS.[Label] WHEN ''50'' THEN CONVERT(nvarchar(10), OD.[ShipDate], 112) END),
					[SalesPrice_] = SUM(OD.DocExtPriceDtl), 
					[SalesDiscount_] = SUM(-1 * OD.DocDiscount),

					
					[SalesCOGSLabor] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgLaborCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgLaborCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastLaborCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdLaborCost], 0)) ELSE 0 END,
					[SalesCOGSMater] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgMaterialCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgMaterialCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastMaterialCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdMaterialCost], 0)) ELSE 0 END,
					[SalesCOGSBurden] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgBurdenCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgBurdenCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastBurdenCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdBurdenCost], 0)) ELSE 0 END,
					[SalesCOGSSubCont] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgSubContCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgSubContCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastSubContCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdSubContCost], 0)) ELSE 0 END,
					[SalesCOGSMatBurd] = SUM(-1 * OD.[OrderQty]) * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN SUM(ISNULL(PC.[AvgMtlBurCost], 0)) WHEN ''F'' THEN SUM(ISNULL(PC.[FIFOAvgMtlBurCost], 0)) WHEN ''L'' THEN SUM(ISNULL(PC.[LastMtlBurCost], 0)) WHEN ''S'' THEN SUM(ISNULL(PC.[StdMtlBurCost], 0)) ELSE 0 END,'
					IF (SELECT COUNT(*) FROM #MemberSelection WHERE [Label] like '%Unit') <> 0
						BEGIN
						SET @SQLStatement = @SQLStatement + '
							[SalesCOGSLabor_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgLaborCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgLaborCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastLaborCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdLaborCost], 0)) ELSE 0 END,
							[SalesCOGSMater_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgMaterialCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgMaterialCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastMaterialCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdMaterialCost], 0)) ELSE 0 END,
							[SalesCOGSBurden_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgBurdenCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgBurdenCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastBurdenCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdBurdenCost], 0)) ELSE 0 END,
							[SalesCOGSSubCont_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgSubContCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgSubContCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastSubContCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdSubContCost], 0)) ELSE 0 END,
							[SalesCOGSMatBurd_Unit] = -1 * CASE MAX(PP.[CostMethod]) WHEN ''A'' THEN MAX(ISNULL(PC.[AvgMtlBurCost], 0)) WHEN ''F'' THEN MAX(ISNULL(PC.[FIFOAvgMtlBurCost], 0)) WHEN ''L'' THEN MAX(ISNULL(PC.[LastMtlBurCost], 0)) WHEN ''S'' THEN MAX(ISNULL(PC.[StdMtlBurCost], 0)) ELSE 0 END,'
						END
					
			SET @SQLStatement = @SQLStatement + '
					[SalesQtyUnit_] = SUM(OD.[OrderQty]),
					[SalesQtyOrderLine_] = 1
				FROM
					#OD OD
					INNER JOIN #Part P ON P.[Company] = OD.[Company] AND P.[PartNum] = OD.[PartNum]
					INNER JOIN #Customer C ON C.[Company] = OD.[Company] AND C.[CustNum] = OD.[CustNum]
					INNER JOIN #MemberSelection OS ON OS.[DimensionID] = -17 AND OS.[SequenceBM] & 4 > 0 AND OS.[Label] = CASE WHEN OD.[ShipDate] IS NOT NULL THEN ''50'' END
					LEFT JOIN #UOMConv SIUM ON SIUM.[Company] = OD.[Company] AND SIUM.[UOMClassID] = P.[UOMClassID] AND SIUM.[UOMCode] = OD.[SalesUM] 
					LEFT JOIN #UOMConv IUM ON IUM.[Company] = OD.[Company] AND IUM.[UOMClassID] = P.[UOMClassID] AND IUM.[UOMCode] = OD.[IUM] 
					LEFT JOIN #Plant Plant ON Plant.[Company] = OD.[Company] AND Plant.[Plant] = OD.[Plant]
					LEFT JOIN #PartPlant PP ON PP.[Company] = OD.[Company] AND PP.[Plant] = OD.[Plant] AND PP.[PartNum] = OD.[PartNum]
					LEFT JOIN #PartCost PC ON PC.[Company] = OD.[Company] AND PC.[PartNum] = OD.[PartNum] AND PC.[CostID] = Plant.[PlantCostID]
				GROUP BY 
					C.[CustID] + CASE WHEN LEN(ISNULL(OD.[ShipToNum], '''')) = 0 THEN '''' ELSE ''_'' + OD.[ShipToNum] END,
					OD.[Company],
					CONVERT(nvarchar(255), OD.[OrderLine]),
					OD.[Company] + ''_'' + RIGHT(''0000000'' + CONVERT(nvarchar(255), OD.[OrderNum]),7) COLLATE DATABASE_DEFAULT,
					OS.[Label],
					OD.[PartNum]'

				SET @RowCount = @@RowCount
				SET @Selected = @Selected + @RowCount

				IF @DebugBM & 2 > 0 SELECT [@SQLStatement] = @SQLStatement
				EXEC(@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = '#DC_Sales_Raw, SequenceBM = 4', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = @RowCount
			END

	SET @Step = '@SequenceBMStep = 8, Shipment, Count'
		IF @SequenceBM & 8 > 0
			BEGIN
				--#DC_Sales_Raw
				SET @StepStartTime = GETDATE()

				INSERT INTO [#DC_Sales_Raw]
					(
					[Document_Currency],
					[Customer],
					[Entity],
					[InvoiceNo_AR],
					[OrderLine],
					[OrderNo],
					[OrderState],
					[OrderType],
					[Plant],
					[Product],
					[TimeDay],
					[SalesQtyOrder_]
					)
				SELECT
					[Currency] = OD.CurrencyCode,
					[Customer] = C.CustID + CASE WHEN LEN(ISNULL(OD.ShipToNum, '')) = 0 THEN '' ELSE '_' + OD.ShipToNum END,
					[Entity] = OD.Company,
					[InvoiceNo_AR] = OD.Company + '_' + 'NONE',
					[OrderLine] = 'NONE',
					[OrderNo] = OD.Company + '_' + (CASE LEN(OD.[OrderNum]) WHEN 1 THEN '000000' WHEN 2 THEN '00000'  WHEN 3 THEN '0000'  WHEN 4 THEN '000'  WHEN 5 THEN '00' WHEN 6 THEN '0' ELSE '' END + CONVERT(nvarchar(255), OD.OrderNum)) COLLATE DATABASE_DEFAULT,
					[OrderState] = OS.[Label],
					[OrderType] = 'NONE',
					[Plant] = 'NONE',
					[Product] = 'NONE',
					[TimeDay] = CASE OS.[Label] WHEN '50' THEN CONVERT(nvarchar(10), OD.ShipDate, 112) END,
					[SalesQtyOrder_] = 1
				FROM
					#OH OD
					INNER JOIN #Customer C ON C.Company = OD.Company AND C.CustNum = OD.CustNum
					INNER JOIN #MemberSelection OS ON OS.DimensionID = -17 AND OS.SequenceBM & 8 > 0 AND (OS.[Label] = CASE WHEN OD.ShipDate IS NOT NULL THEN '50' END)

				SET @RowCount = @@RowCount
				SET @Selected = @Selected + @RowCount
				
				IF @DebugBM & 2 > 0 SELECT Step = '#DC_Sales_Raw, SequenceBM = 8', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = @RowCount
			END

	SET @Step = '@SequenceBMStep = 48, Invoices'
		IF @SequenceBM & 48 > 0
			BEGIN
            	--#IH
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #IH
								
				SET @SQLStatement = '
					INSERT INTO	#IH
						(
						[Company],
						[InvoiceNum],
						[InvoiceDate],
						[DueDate],
						[ClosedDate],
						[OrderNum],
						[CustNum],
						[ShipToNum]
						)
					SELECT
						[Company] = IH.[Company],
						[InvoiceNum] = MAX(IH.[InvoiceNum]),
						[InvoiceDate] = MAX(IH.[InvoiceDate]),
						[DueDate] = MAX(IH.[DueDate]),
						[ClosedDate] = MAX(IH.[ClosedDate]),
						[OrderNum] = ID.[OrderNum],
						[CustNum] = MAX(ID.[ShipToCustNum]),
						[ShipToNum] = MAX(ID.[ShipToNum])
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[InvcHead] IH
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[InvcDtl] ID ON ID.[Company] = IH.[Company] AND ID.[InvoiceNum] = IH.[InvoiceNum]
					WHERE
						IH.[Company] IN (' + @EntityString + ') AND
						(IH.[InvoiceDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'' OR IH.[DueDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'' OR IH.[ClosedDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'')
						' + CASE WHEN @StartDate IS NOT NULL THEN 'AND (IH.[InvoiceDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''' OR IH.[DueDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''' OR IH.[ClosedDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''')' ELSE '' END + '
					GROUP BY
						IH.[Company],
						ID.[OrderNum]'					

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Invoices; #IH', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #IH
				IF @DebugBM & 8 > 0 SELECT TempTable = '#IH', * FROM #IH

				--#Customer
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #Customer

				SET @SQLStatement = '
					INSERT INTO #Customer
						(
						[Company],
						[CustNum],
						[CustID]
						)
					SELECT
						[Company] = C.[Company],
						[CustNum] = C.[CustNum],
						[CustID] = C.[CustID]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[Customer] C
						INNER JOIN (SELECT DISTINCT [Company], [CustNum] FROM #IH) D ON D.[Company] = C.[Company] AND D.[CustNum] = C.[CustNum]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Invoices; #Customer', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Customer
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Customer', * FROM #Customer
			END

	SET @Step = '@SequenceBMStep = 16, Invoices, Values'
		IF @SequenceBM & 16 > 0
			BEGIN  
				--#ID
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #ID

				SET @SQLStatement = '
					INSERT INTO #ID
						(
						[Company],
						[InvoiceNum],
						[InvoiceLine],
						[InvoiceDate],
						[DueDate],
						[ClosedDate],
						[PartNum],
						[ShipToNum],
						[OrderLine],			
						[DocExtPrice],
						[DocTotalMiscChrg],
						[DocDiscount],		
						[SalesUM],
						[IUM],
						[SellingShipQty],
						[OurOrderQty],
						[LbrUnitCost],
						[MtlUnitCost],
						[BurUnitCost],
						[SubUnitCost],
						[MtlBurUnitCost],
						[CustNum],
						[CreditMemo],
						[InvoiceRef],
						[InvoiceLineRef],
						[Plant],
						[CurrencyCode],
						[OrderNum],
						[CorrectionInv],
						[InvoiceType]
						)
					SELECT 
						[Company] = IH.[Company],
						[InvoiceNum] = IH.[InvoiceNum],
						[InvoiceLine] = ID.[InvoiceLine],
						[InvoiceDate] = MAX(IH.[InvoiceDate]),
						[DueDate] = MAX(IH.[DueDate]),
						[ClosedDate] = MAX(IH.[ClosedDate]),
						[PartNum] = MAX(ID.[PartNum]),
						[ShipToNum] = MAX(ID.[ShipToNum]),
						[OrderLine] = ID.[OrderLine],			
						[DocExtPrice] = MAX(ID.[DocExtPrice]),
						[DocTotalMiscChrg] = MAX(ID.[DocTotalMiscChrg]),
						[DocDiscount] = MAX(ID.[DocDiscount]),		
						[SalesUM] = MAX(ID.[SalesUM]),
						[IUM] = MAX(ID.[IUM]),
						[SellingShipQty] = MAX(ID.[SellingShipQty]),
						[OurOrderQty] = MAX(ID.[OurOrderQty]),
						[LbrUnitCost] = MAX(ID.[LbrUnitCost]),
						[MtlUnitCost] = MAX(ID.[MtlUnitCost]),
						[BurUnitCost] = MAX(ID.[BurUnitCost]),
						[SubUnitCost] = MAX(ID.[SubUnitCost]),
						[MtlBurUnitCost] = MAX(ID.[MtlBurUnitCost]),
						[CustNum] = MAX(IH.[CustNum]),
						[CreditMemo] = CONVERT(bit, MAX(CONVERT(int, IH.[CreditMemo]))),
						[InvoiceRef] = MAX(IH.[InvoiceRef]),
						[InvoiceLineRef] = MAX(ID.[InvoiceLineRef]),
						[Plant] = MAX([OR].[Plant]),
						[CurrencyCode] = MAX(IH.[CurrencyCode]),
						[OrderNum] = ID.[OrderNum],
						[CorrectionInv] = CONVERT(bit, MAX(CONVERT(int, IH.[CorrectionInv]))),
						[InvoiceType] = MAX(IH.[InvoiceType])
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[InvcHead] IH
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[InvcDtl] ID ON ID.[Company] = IH.[Company] AND ID.[InvoiceNum] = IH.[InvoiceNum]
						LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[OrderRel] [OR] ON [OR].[Company] = [ID].[Company] AND [OR].[OrderNum] = [ID].[OrderNum] AND [OR].[OrderLine] = [ID].[OrderLine]
					WHERE
						IH.[Company] IN (' + @EntityString + ') AND
						(IH.[InvoiceDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'' OR IH.[DueDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'' OR IH.[ClosedDate] >= ''' + CONVERT(nvarchar(15), @StartYear) + '-01-01'')
						' + CASE WHEN @StartDate IS NOT NULL THEN 'AND (IH.[InvoiceDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''' OR IH.[DueDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''' OR IH.[ClosedDate] >= ''' + CONVERT(nvarchar(10), @StartDate) + ''')' ELSE '' END + '
					GROUP BY
						IH.[Company],
						IH.[InvoiceNum],
						ID.[InvoiceLine],
						ID.[OrderLine],
						ID.[OrderNum]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				
				IF @DebugBM & 2 > 0 SELECT Step = 'Invoices; #ID', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #ID
				IF @DebugBM & 8 > 0 SELECT TempTable = '#ID', * FROM #ID

				--#Part
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #Part

				SET @SQLStatement = '
					INSERT INTO #Part
						(
						[Company],
						[PartNum],
						[UOMClassID]
						)
					SELECT
						P.[Company],
						P.[PartNum],
						P.[UOMClassID]
				
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].Part P
						INNER JOIN (SELECT DISTINCT [Company], [PartNum] FROM #ID) D ON D.[Company] = P.[Company] AND D.[PartNum] = P.[PartNum]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Invoices; #Part', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Part
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Part', * FROM #Part

				--#UOMConv
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #UOMConv

				SET @SQLStatement = '
					INSERT INTO #UOMConv
						(
						[Company],
						[UOMClassID],
						[UOMCode],
						[ConvFactor]
						)
					SELECT
						[Company] = UOM.[Company],
						[UOMClassID] = UOM.[UOMClassID],
						[UOMCode] = UOM.[UOMCode],
						[ConvFactor] = UOM.[ConvFactor]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[UOMConv] UOM
						INNER JOIN (SELECT DISTINCT [Company], [UOMCode] = [SalesUM] FROM #ID UNION SELECT DISTINCT [Company], [UOMCode] = [IUM] FROM #ID) D ON D.[Company] = UOM.[Company] AND D.[UOMCode] = UOM.[UOMCode]
						INNER JOIN (SELECT DISTINCT [Company], [UOMClassID] FROM #Part) P ON P.[Company] = UOM.[Company] AND P.[UOMClassID] = UOM.[UOMClassID]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Invoices; #UOMConv', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #UOMConv
				IF @DebugBM & 8 > 0 SELECT TempTable = '#UOMConv', * FROM #UOMConv

				--#Plant
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #Plant

				SET @SQLStatement = '
					INSERT INTO #Plant
						(
						[Company],
						[Plant],
						[PlantCostID]
						)
					SELECT
						[Company],
						[Plant],
						[PlantCostID]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[Plant]
					WHERE
						LEN(PlantCostID) > 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Invoices; #Plant', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #Plant
				IF @DebugBM & 8 > 0 SELECT TempTable = '#Plant', * FROM #Plant

				--#PartPlant
				SET @StepStartTime = GETDATE()
				TRUNCATE TABLE #PartPlant

				SET @SQLStatement = '
					INSERT INTO #PartPlant
						(
						[Company],
						[Plant],
						[PartNum],
						[CostMethod]
						)

					SELECT
						[Company] = PP.[Company],
						[Plant] = PP.[Plant],
						[PartNum] = PP.[PartNum],
						[CostMethod] = PP.[CostMethod]
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[PartPlant] PP
						INNER JOIN #Plant Plant ON Plant.Company = PP.Company AND Plant.Plant = PP.Plant
						INNER JOIN #Part P ON P.Company = PP.Company AND P.PartNum = PP.PartNum'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Invoices; #PartPlant', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #PartPlant
				IF @DebugBM & 8 > 0 SELECT TempTable = '#PartPlant', * FROM #PartPlant

				--#DC_Sales_Raw
				SET @StepStartTime = GETDATE()

				SET @SQLStatement = '
				INSERT INTO [#DC_Sales_Raw]
					(
					[Document_Currency],
					[Customer],
					[Entity],
					[InvoiceNo_AR],
					[OrderLine],
					[OrderNo],
					[OrderState],
					[OrderType],
					[Plant],
					[Product],
					[TimeDay],
					[SalesPrice_],
					[SalesMiscCharge_],
					[SalesDiscount_],
					[SalesCOGSLabor],
					[SalesCOGSMater],
					[SalesCOGSBurden],
					[SalesCOGSSubCont],
					[SalesCOGSMatBurd],'
					IF (SELECT COUNT(*) FROM #MemberSelection WHERE [Label] like '%Unit') <> 0
						BEGIN
							SET @SQLStatement = @SQLStatement + '
							[SalesCOGSLabor_Unit],
							[SalesCOGSMater_Unit],
							[SalesCOGSBurden_Unit],
							[SalesCOGSSubCont_Unit],
							[SalesCOGSMatBurd_Unit],'
						END
				SET @SQLStatement = @SQLStatement + '
					[SalesQtyUnit_],
					[SalesQtyOrderLine_]
					)
				SELECT
					[Document_Currency] = MAX(ID.[CurrencyCode]),			
					[Customer] = C.[CustID] + CASE WHEN LEN(ISNULL(ID.[ShipToNum], '''')) = 0 THEN '''' ELSE ''_'' + ID.[ShipToNum] END,
					[Entity] = ID.[Company],
					
					[InvoiceNo_AR] = ID.[Company] + ''_'' + RIGHT(''000000'' + CONVERT(nvarchar(255), ID.[InvoiceNum]),6) COLLATE DATABASE_DEFAULT,
					[OrderLine] = CONVERT(nvarchar(255), ID.[OrderLine]),
					[OrderNo] = ID.[Company] + ''_'' + RIGHT(''0000000'' + CONVERT(nvarchar(255), ID.[OrderNum]),7) COLLATE DATABASE_DEFAULT,
					[OrderState] = OS.[Label],
					[OrderType] = CASE WHEN SUM(ID.DocExtPrice) = 0 THEN ''FOC'' ELSE
									CASE WHEN MAX(CONVERT(int, ID.CorrectionInv)) = 0 THEN 
									CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) = 0 THEN MAX(ID.InvoiceType) ELSE ''CREDIT'' END
									ELSE ''CORRINV'' END
									END,
					[Plant] = MAX(ID.[Plant]),
					[Product] = ID.[PartNum],
					[TimeDay] = MAX(CASE OS.[Label] WHEN ''60'' THEN CONVERT(nvarchar(10), ID.InvoiceDate, 112) WHEN ''70'' THEN CONVERT(nvarchar(10), ID.DueDate, 112) WHEN ''90'' THEN CONVERT(nvarchar(10), ID.ClosedDate, 112) END),
					
					[SalesPrice_] = SUM(ID.DocExtPrice),
					[SalesMiscCharge_] = SUM(ID.DocTotalMiscChrg),
					[SalesDiscount_] = SUM(-1 * ID.DocDiscount),
					
					[SalesCOGSLabor] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN -1.0 * SUM(IDC.LbrUnitCost * ID.[OurOrderQty]) ELSE SUM(ID.LbrUnitCost * ID.[OurOrderQty]) END,
					[SalesCOGSMater] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN -1.0 * SUM(IDC.MtlUnitCost * ID.[OurOrderQty]) ELSE SUM(ID.MtlUnitCost * ID.[OurOrderQty]) END,
					[SalesCOGSBurden] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN -1.0 * SUM(IDC.BurUnitCost * ID.[OurOrderQty]) ELSE SUM(ID.BurUnitCost * ID.[OurOrderQty]) END,
					[SalesCOGSSubCont] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN -1.0 * SUM(IDC.SubUnitCost * ID.[OurOrderQty]) ELSE SUM(ID.SubUnitCost * ID.[OurOrderQty]) END,
					[SalesCOGSMatBurd] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN -1.0 * SUM(IDC.MtlBurUnitCost * ID.[OurOrderQty]) ELSE SUM(ID.MtlBurUnitCost * ID.[OurOrderQty]) END,'
					
					IF (SELECT COUNT(*) FROM #MemberSelection WHERE [Label] like '%Unit') <> 0
						BEGIN
							SET @SQLStatement = @SQLStatement + '
								[SalesCOGSLabor_Unit] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN MAX(IDC.LbrUnitCost) ELSE MAX(ID.LbrUnitCost) END,
								[SalesCOGSMater_Unit] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN MAX(IDC.MtlUnitCost) ELSE MAX(ID.MtlUnitCost) END,
								[SalesCOGSBurden_Unit] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN MAX(IDC.BurUnitCost) ELSE MAX(ID.BurUnitCost) END,
								[SalesCOGSSubCont_Unit] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN MAX(IDC.SubUnitCost) ELSE MAX(ID.SubUnitCost) END,
								[SalesCOGSMatBurd_Unit] = -1 * CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) <> 0 THEN MAX(IDC.MtlBurUnitCost) ELSE MAX(ID.MtlBurUnitCost) END,'
						END
					
				SET @SQLStatement = @SQLStatement + '
					[SalesQtyUnit_] = SUM(ID.[OurOrderQty]),
					[SalesQtyOrderLine_] = CASE WHEN MAX(CONVERT(int, ID.CreditMemo)) = 0 THEN 1 ELSE -1 END
				FROM
					#ID ID
					INNER JOIN #Part P ON P.[Company] = ID.[Company] AND P.[PartNum] = ID.[PartNum]
					INNER JOIN #Customer C ON C.[Company] = ID.[Company] AND C.[CustNum] = ID.[CustNum]
					LEFT JOIN #UOMConv SIUM ON SIUM.[Company] = ID.[Company] AND SIUM.[UOMClassID] = P.[UOMClassID] AND SIUM.[UOMCode] = ID.[SalesUM] 
					LEFT JOIN #UOMConv IUM ON IUM.[Company] = ID.[Company] AND IUM.[UOMClassID] = P.[UOMClassID] AND IUM.[UOMCode] = ID.[IUM] 
					INNER JOIN #MemberSelection OS ON OS.DimensionID = -17 AND OS.[SequenceBM] & 16 > 0 AND (OS.[Label] = CASE WHEN ID.InvoiceDate IS NOT NULL THEN ''60'' END OR OS.[Label] = CASE WHEN ID.DueDate IS NOT NULL THEN ''70'' END OR OS.[Label] = CASE WHEN ID.ClosedDate IS NOT NULL THEN ''90'' END)
					
					LEFT JOIN #ID IDC ON ID.CreditMemo = 1 AND IDC.Company = ID.Company AND IDC.InvoiceNum = ID.InvoiceRef AND IDC.OrderLine = ID.OrderLine AND IDC.PartNum = ID.PartNum AND IDC.[InvoiceLine] = ID.[InvoiceLineRef]
					LEFT JOIN #Plant Plant ON Plant.[Company] = ID.[Company] AND Plant.[Plant] = ID.[Plant]
					LEFT JOIN #PartPlant PP ON PP.[Company] = ID.[Company] AND PP.[Plant] = ID.[Plant] AND PP.[PartNum] = ID.[PartNum]
				GROUP BY
					C.[CustID] + CASE WHEN LEN(ISNULL(ID.[ShipToNum], '''')) = 0 THEN '''' ELSE ''_'' + ID.[ShipToNum] END,
					ID.[Company],
					ID.[Company] + ''_'' + RIGHT(''000000'' + CONVERT(nvarchar(255), ID.[InvoiceNum]),6) COLLATE DATABASE_DEFAULT,
					CONVERT(nvarchar(255), ID.[OrderLine]),
					ID.[Company] + ''_'' + RIGHT(''0000000'' + CONVERT(nvarchar(255), ID.[OrderNum]),7) COLLATE DATABASE_DEFAULT,
					OS.[Label],
					ID.[PartNum]'

				SET @RowCount = @@RowCount
				SET @Selected = @Selected + @RowCount

				IF @DebugBM & 2 > 0 SELECT [@SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = '#DC_Sales_Raw, SequenceBM = 16', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = @RowCount
			END

	SET @Step = '@SequenceBMStep = 32, Invoices, Count'
		IF @SequenceBM & 32 > 0
			BEGIN
				--#DC_Sales_Raw
				SET @StepStartTime = GETDATE()

				INSERT INTO [#DC_Sales_Raw]
					(
					[Document_Currency],
					[Customer],
					[Entity],
					[InvoiceNo_AR],
					[OrderLine],
					[OrderNo],
					[OrderState],
					[OrderType],
					[Plant],
					[Product],
					[TimeDay],
					[SalesQtyOrder_]
					)
				SELECT
					[Document_Currency] = 'NONE',
					[Customer] = C.CustID + CASE WHEN LEN(ISNULL(INV.ShipToNum, '')) = 0 THEN '' ELSE '_' + INV.ShipToNum END,
					[Entity] = INV.Company,
					[InvoiceNo_AR] = INV.Company + '_' + 'NONE',
					[OrderLine] = 'NONE',
					[OrderNo] = INV.Company + '_' + (CASE LEN(INV.[OrderNum]) WHEN 1 THEN '000000' WHEN 2 THEN '00000'  WHEN 3 THEN '0000'  WHEN 4 THEN '000'  WHEN 5 THEN '00' WHEN 6 THEN '0' ELSE '' END + CONVERT(nvarchar(255), INV.OrderNum)),
					[OrderState] = OS.[Label],
					[OrderType] = 'NONE',
					[Plant] = 'NONE',
					[Product] = 'NONE',
					[TimeDay] = MAX(CASE OS.[Label] WHEN '60' THEN CONVERT(nvarchar(10), INV.InvoiceDate, 112) WHEN '70' THEN CONVERT(nvarchar(10), INV.DueDate, 112) WHEN '90' THEN CONVERT(nvarchar(10), INV.ClosedDate, 112) END),
					[SalesQtyOrder_] = 1
				FROM
					#IH INV
					INNER JOIN #Customer C ON C.Company = INV.Company AND C.CustNum = INV.CustNum
					INNER JOIN #MemberSelection OS ON OS.DimensionID = -17 AND OS.SequenceBM & 48 > 0 AND (OS.[Label] = CASE WHEN INV.InvoiceDate IS NOT NULL THEN '60' END OR OS.[Label] = CASE WHEN INV.DueDate IS NOT NULL THEN '70' END OR OS.[Label] = CASE WHEN INV.ClosedDate IS NOT NULL THEN '90' END)
				GROUP BY
					C.CustID + CASE WHEN LEN(ISNULL(INV.ShipToNum, '')) = 0 THEN '' ELSE '_' + INV.ShipToNum END,
					INV.Company,
					INV.Company + '_' + (CASE LEN(INV.[OrderNum]) WHEN 1 THEN '000000' WHEN 2 THEN '00000'  WHEN 3 THEN '0000'  WHEN 4 THEN '000'  WHEN 5 THEN '00' WHEN 6 THEN '0' ELSE '' END + CONVERT(nvarchar(255), INV.OrderNum)),
					OS.[Label]

				SET @RowCount = @@RowCount
				SET @Selected = @Selected + @RowCount
				
				IF @DebugBM & 2 > 0 SELECT Step = '#DC_Sales_Raw, SequenceBM = 32', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = @RowCount
            END

			END --END OF: IF @SourceTypeID IN (1, 11) --Epicor ERP
		ELSE 
			BEGIN
				SET @Message = 'Setup Sales is not yet implemented for ' + @SourceTypeName + '.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Update Currency'
		SET @SQLStatement = '
			INSERT INTO #Callisto_Currency
				(
				Currency
				)
			SELECT 
				Currency = [Label]
			FROM 
				' + @CallistoDatabase + '.[dbo].[S_DS_Currency]
			WHERE 
				RNodeType = ''L'' AND MemberId <> -1'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Callisto_Currency', * FROM #Callisto_Currency

		SET @SQLStatement = '
			INSERT INTO #Entity_Currency
				(
				[Entity],
				[Currency]
				)
			SELECT 
				[Entity] = E.MemberKey, 
				[Currency] = EB.Currency
			FROM 
				[pcINTEGRATOR_Data].[dbo].[Entity] E 
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 8 > 0 AND EB.SelectYN <> 0
			WHERE 
				E.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND 
				E.VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ' AND 
				E.SelectYN <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Entity_Currency', * FROM #Entity_Currency

		UPDATE SR
		SET [Document_Currency] = ISNULL(C.Currency, E.Currency)
		FROM 
			#DC_Sales_Raw SR
			INNER JOIN #Entity_Currency E ON E.[Entity] = SR.[Entity] 
			LEFT JOIN #Callisto_Currency C ON C.[Currency] = SR.[Document_Currency]
		WHERE SR.[Document_Currency] <> 'NONE'

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			SELECT TempTable = '#DC_Sales_Raw', * FROM #DC_Sales_Raw ORDER BY [TimeDay], [Document_Currency], [Entity]

	SET @Step = 'Drop temp tables'
		DROP TABLE #Callisto_Currency
		DROP TABLE #Entity_Currency
		IF @CalledYN = 0 DROP TABLE #DC_Sales_Raw

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
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
