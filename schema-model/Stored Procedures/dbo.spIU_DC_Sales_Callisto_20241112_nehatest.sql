SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Sales_Callisto_20241112_nehatest]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceID int = NULL,
	@DataClassID int = NULL,
	@StartYear int = NULL,
	@StartDay int = NULL,
	@SequenceBM int = NULL,
	@Entity nvarchar(50) = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@FullReloadYN bit = 0,
	@SpeedRunYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000698,
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
EXEC [spIU_DC_Sales_Callisto_20241112_nehatest] @UserID=-10, @InstanceID=637, @VersionID=1111,@DebugBM=31 --RDKP
EXEC [spIU_DC_Sales_Callisto_20241112_nehatest] @UserID=-10, @InstanceID=895, @VersionID=1302,@DebugBM=31 --VRTK

*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@StorageTypeBM int, --1 = Internal, 2 = Table, 4 = Callisto
	@JSON nvarchar(max),
	@CalledYN bit = 1,
	@Owner nvarchar(10),
	@SQLStatement nvarchar(max),
	@SourceTypeID int,
	@SourceTypeName nvarchar(50),
	@MasterClosedYear int,
	@Entity_StartDay int,
	@EntityString nvarchar(1000) = '',
	@StepStartTime datetime,
	@StartDate date,
	@RowCount int,
	@BusinessProcess nvarchar(50),
	@DataClassName nvarchar(50),
	@TableName_DataClass nvarchar(100),
	@StepSize int = 5000,
	@GUID nvarchar(50),
	@ReturnVariable int,
	@TempTable_ObjectID int,	
	@SQLInsertInto nvarchar(4000) = '',
	@SQLSelect nvarchar(4000) = '',
	@SQLGroupBy nvarchar(4000) = '',
	@SQLSegmentDistinct nvarchar(2000) = '',
	@SQLSegmentJoin nvarchar(2000) = '',
	@SQLDimJoin nvarchar(4000) = '',
	@SQLDim_FACT_Sales nvarchar(4000) = '',

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
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert new rows into Callisto Sales FACT table',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2163' SET @Description = 'Converted hardcoded queries to dynamic code. Added column [SalesMiscCharge_] in #DC_Sales_Raw.'
		IF @Version = '2.1.1.2170' SET @Description = 'Added NULL-checking for @StartDay in #DC_Sales INSERT query.'
		IF @Version = '2.1.1.2173' SET @Description = 'Made @SourceID as parameter.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		SET @StartDate = CONVERT(date, CONVERT(nvarchar(15), @StartDay), 112)
		
		SELECT
			@DataClassID = ISNULL(@DataClassID, MAX(DC.DataClassID)),
			@DataClassName = MAX(DC.DataClassName),
			@StorageTypeBM = MAX(StorageTypeBM)
		FROM
			pcINTEGRATOR_Data..DataClass DC
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.VersionID = @VersionID AND
			DC.DataClassTypeID = -10 AND
			(DC.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
			DC.SelectYN <> 0 AND
			DC.DeletedID IS NULL

		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(ISNULL(@CallistoDatabase, A.DestinationDatabase), '[', ''), ']', ''), '.', '].[') + ']',
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(ISNULL(@SourceDatabase, S.SourceDatabase), '[', ''), ']', ''), '.', '].[') + ']',
			@Owner = ST.[Owner],
			@StartYear = ISNULL(@StartYear, S.StartYear),
			@SourceID = ISNULL(@SourceID, S.[SourceID]),
			@SourceTypeID = S.[SourceTypeID],
			@SourceTypeName = ST.[SourceTypeName],
			@BusinessProcess = S.[BusinessProcess]
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -4 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0 AND (S.SourceID = @SourceID OR @SourceID IS NULL)
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID --AND ST.SourceTypeFamilyID = 1
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		EXEC [spGet_MasterClosedYear]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@MasterClosedYear = @MasterClosedYear OUT,
			@JobID = @JobID

		IF @MasterClosedYear >= @StartYear SET @StartYear = @MasterClosedYear + 1

		SET @TableName_DataClass = @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition]'

		CREATE TABLE [dbo].[#MemberSelection]
			(
			[DimensionID] [int],
			[Label] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[SequenceBM] [int],
			[RNodeType] [nvarchar](2) COLLATE DATABASE_DEFAULT,
			[Unit] [nvarchar](50) COLLATE DATABASE_DEFAULT
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
			pcINTEGRATOR_Data..MemberSelection MS
		WHERE	
			MS.InstanceID = @InstanceID AND
			MS.VersionID = @VersionID AND
			MS.DataClassID = @DataClassID AND
			MS.DimensionID = -1 AND
			MS.SelectYN <> 0

		SET @SQLStatement = '
			UPDATE MS
			SET
				[RNodeType] = A.[RNodeType]
			FROM 
				#MemberSelection MS
				INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Account] A ON A.[Label] = MS.[Label]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		UPDATE MS
		SET
			[Unit] = TM.[Unit]
		FROM 
			#MemberSelection MS
			INNER JOIN [pcINTEGRATOR].[dbo].[@Template_Measure] TM ON TM.InstanceID = -20 AND TM.VersionID = -20 AND TM.DataClassID = -104 AND TM.[MeasureName] = MS.[Label]

		IF @DebugBM & 8 > 0 SELECT TempTable = '#MemberSelection', * FROM #MemberSelection
		
		IF @DebugBM & 2 > 0 
			SELECT
				[@SourceDatabase] = @SourceDatabase,
				[@CallistoDatabase] = @CallistoDatabase,
				[@Owner] = @Owner,
				[@StartYear] = @StartYear,
				[@StartDate] = @StartDate,
				[@MasterClosedYear] = @MasterClosedYear,
				[@SourceID] = @SourceID,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName,
				[@DataClassID] = @DataClassID,
				[@SequenceBM] = @SequenceBM,
				[@BusinessProcess] = @BusinessProcess,
				[@DataClassName] = @DataClassName,
				[@TableName_DataClass] = @TableName_DataClass,
				[@StorageTypeBM] = @StorageTypeBM

	SET @Step = 'Create temp table #OrderState'
		CREATE TABLE #OrderState
			(
			[RowID] [int] IDENTITY(1,1) NOT NULL,
			[Entity_MemberID] [bigint] NOT NULL,
			[OrderNo_MemberID] [bigint] NOT NULL,
			[OrderLine_MemberId] [bigint] NOT NULL
			)

		SELECT @GUID = NEWID()
		SET @SQLStatement = '
			ALTER TABLE [#OrderState] ADD CONSTRAINT [PK_' + @GUID + '_#OrderState] PRIMARY KEY CLUSTERED 
			(
				[RowID] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]'

		EXEC (@SQLStatement)

	SET @Step = 'Create temp table #DC_Sales'
	/*
		CREATE TABLE [#DC_Sales]
			(
			[Account_MemberId] bigint,
			[BusinessProcess_MemberId] bigint,
			[BusinessRule_MemberId] bigint DEFAULT -1,
			[Currency_MemberId] bigint,
			[CurrentOrderState_MemberId] bigint DEFAULT -1,
			[Customer_MemberId] bigint,
			[Entity_MemberId] bigint,
			[InvoiceNo_AR_MemberId] bigint,
			--[OrderManager_MemberId] bigint,
			[OrderLine_MemberId] bigint,
			[OrderNo_MemberId] bigint,
			[OrderState_MemberId] bigint,
			--[OrderType_MemberId] bigint,
			--[Plant_MemberId] bigint,
			[Product_MemberId] bigint,
			[Scenario_MemberId] bigint DEFAULT 110,
			[TimeDataView_MemberId] bigint DEFAULT 101,
			[TimeDay_MemberId] bigint,
			[Sales_Value] float
			)
	*/
		IF @StorageTypeBM & 4 > 0
			BEGIN
				CREATE TABLE #DataClassColumns
					(
					DimensionID INT,
					DimensionTypeID INT,
					ColumnName NVARCHAR(100) COLLATE DATABASE_DEFAULT,
					DataType nvarchar(50) COLLATE DATABASE_DEFAULT,
					SortOrder int
					)

				INSERT INTO #DataClassColumns
					(
					DimensionID,
					DimensionTypeID,
					ColumnName,
					DataType,
					SortOrder
					)
				SELECT 
					DimensionID = DCD.DimensionID,
					DimensionTypeID = D.DimensionTypeID,
					ColumnName = CONVERT(nvarchar(100), D.DimensionName + '_MemberId') COLLATE DATABASE_DEFAULT,
					DataType = CONVERT(nvarchar(50), 'bigint'),
					SortOrder = DCD.SortOrder
				FROM
					[pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD
					INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.DimensionID = DCD.DimensionID AND D.DimensionTypeID NOT IN (27,50) AND D.SelectYN <> 0 AND D.DeletedID IS NULL
				WHERE
					DCD.DataClassID = @DataClassID  AND
					DCD.DimensionID NOT IN (-77)
				ORDER BY
					DCD.SortOrder

				IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassColumns', * FROM #DataClassColumns ORDER BY SortOrder

				IF (SELECT COUNT(1) FROM #DataClassColumns) = 0
					BEGIN
						SET @Message = 'No dimensions specified for selected DataClassID'
						SET @Severity = 0
						GOTO EXITPOINT
					END

				CREATE TABLE #DC_Sales
					(DataClassID int)

				SELECT @TempTable_ObjectID = OBJECT_ID (N'tempdb..#DC_Sales', N'U')
				IF @DebugBM & 2 > 0 SELECT [@TempTable_ObjectID] = @TempTable_ObjectID

				SET @SQLStatement = 'ALTER TABLE #DC_Sales' + CHAR(13) + CHAR(10) + 'ADD'

				SELECT 
					@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + ColumnName + ' ' + DataType + ','
				FROM
					#DataClassColumns
				ORDER BY
					SortOrder

				SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + @DataClassName + '_Value float' 

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_Sales', * FROM #DC_Sales
			END

	SET @Step = 'Create temp table #DC_Sales_Raw'
		CREATE TABLE #DC_Sales_Raw
			(			
			[Currency] [nvarchar](10) COLLATE DATABASE_DEFAULT,
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

	SET @Step = 'Fill temp table #DC_Sales_Raw'
		SET @StepStartTime = GETDATE()

		IF @DebugBM & 2 > 0
			SELECT 
				[@UserID] = @UserID, 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@DataClassID] = @DataClassID,
				[@StartYear] = @StartYear,
				[@StartDay] = @StartDay,
				[@MasterClosedYear] = @MasterClosedYear,
				[@SequenceBM] = @SequenceBM,
				[@Entity] = @Entity,
				[@SourceDatabase] = @SourceDatabase,
				[@JobID] = @JobID,
				[@DebugSub] = @DebugSub

		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DataClassID",  "TValue": "' + CONVERT(nvarchar(15), @DataClassID) + '"},
			{"TKey" : "StartYear",  "TValue": "' + CONVERT(nvarchar(15), @StartYear) + '"}, ' +
			CASE WHEN @StartDay IS NULL THEN '' ELSE '{"TKey" : "StartDay",  "TValue": "' + CONVERT(nvarchar(15), @StartDay) + '"}, ' END +
			CASE WHEN @MasterClosedYear IS NULL THEN '' ELSE '{"TKey" : "MasterClosedYear",  "TValue": "' + CONVERT(nvarchar(15), @MasterClosedYear) + '"}, ' END +
			CASE WHEN @SequenceBM IS NULL THEN '' ELSE '{"TKey" : "SequenceBM",  "TValue": "' + CONVERT(nvarchar(15), @SequenceBM) + '"}, ' END +
			CASE WHEN @Entity IS NULL THEN '' ELSE '{"TKey" : "Entity",  "TValue": "' + @Entity + '"}, ' END + '
			{"TKey" : "SourceDatabase",  "TValue": "' + @SourceDatabase + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}
			]'

		IF @DebugBM & 2 > 0 PRINT @JSON
--		EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Sales_Raw', @JSON = @JSON

		SET @Selected = @Selected + (SELECT COUNT(1) FROM #DC_Sales_Raw)

		IF @DebugBM & 2 > 0 SELECT Step = '#DC_Sales_Raw', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #DC_Sales_Raw
		IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_Sales_Raw', * FROM #DC_Sales_Raw

	SET @Step = 'Insert into temp table #DC_Sales'
		SET @StepStartTime = GETDATE()

		SELECT
			@SQLInsertInto = '',
			@SQLSelect = '',
			@SQLDimJoin = '',
			@SQLGroupBy = '',
			@SQLDim_FACT_Sales = ''

		IF @Debug <> 0 
			BEGIN
				PRINT 'INSERT INTO #DC_Sales'

				SELECT
					TempTable= 'sys.tables' , c.[name], t.create_date
				FROM
					tempDB.sys.tables t
					INNER JOIN tempDB.sys.columns c ON c.object_id = t.object_id
				WHERE
					t.[object_id] = @TempTable_ObjectID
				ORDER BY
					c.column_id	
			END
				
		SELECT
			@SQLInsertInto = @SQLInsertInto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + c.name + '],',
			@SQLSelect =  @SQLSelect + CASE WHEN c.name = 'Sales_Value' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + '[' + c.name + '] = ' + CASE WHEN c.name LIKE '%_MemberId' THEN 'ISNULL([' + REPLACE(c.name, '_MemberId', '') + '].[MemberId], -1),' ELSE '' END END,
			@SQLDimJoin = @SQLDimJoin + CASE WHEN c.name IN ('Account_MemberId', 'BusinessProcess_MemberId', 'Currency_MemberId') THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CASE WHEN c.name LIKE '%_MemberId' THEN 'LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + REPLACE(c.name, '_MemberId', '') + '] [' + REPLACE(c.name, '_MemberId', '') + '] ON [' + REPLACE(c.name, '_MemberId', '') + '].Label COLLATE DATABASE_DEFAULT = [Raw].[' + REPLACE(c.name, '_MemberId', '') + ']' ELSE '' END END,
			@SQLGroupBy = @SQLGroupBy + CASE WHEN c.name = 'Sales_Value' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CASE WHEN c.name LIKE '%_MemberId' THEN 'ISNULL([' + REPLACE(c.name, '_MemberId', '') + '].[MemberId], -1),' ELSE '' END END
		FROM
			tempDB.sys.tables t
			INNER JOIN tempdb.sys.columns c ON c.object_id = t.object_id AND c.name NOT IN ('DataClassID','BusinessRule_MemberId', 'CurrentOrderState_MemberId', 'Scenario_MemberId', 'TimeDataView_MemberId')
		WHERE
			t.[object_id] = @TempTable_ObjectID
		ORDER BY
			c.column_id

		SELECT
			@SQLDim_FACT_Sales = @SQLDim_FACT_Sales + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'[' + c.name + '],'
		FROM
			tempDB.sys.tables t
			INNER JOIN tempdb.sys.columns c ON c.object_id = t.object_id AND c.name NOT IN ('DataClassID','Sales_Value')
		WHERE
			t.[object_id] = @TempTable_ObjectID
		ORDER BY
			c.name--c.column_id

		IF @Debug <> 0 
			BEGIN
				SELECT [@SQLInsertInto] = @SQLInsertInto
				SELECT [@SQLSelect] = @SQLSelect
				SELECT [@SQLDimJoin] = @SQLDimJoin
				SELECT [@SQLGroupBy] = @SQLGroupBy
				SELECT [@SQLDim_FACT_Sales] = @SQLDim_FACT_Sales
						 
				PRINT 'SQLInsertInto: ' + @SQLInsertInto
				PRINT 'SQLSelect: ' + @SQLSelect
				PRINT 'SQLDimJoin: ' + @SQLDimJoin
				PRINT 'SQLGroupBy: ' + @SQLGroupBy
				PRINT '@SQLDim_FACT_Sales: ' + @SQLDim_FACT_Sales
			END

		SELECT
			@SQLInsertInto = LEFT(@SQLInsertInto, LEN(@SQLInsertInto) - 1),
			@SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) - 1),
			@SQLGroupBy = LEFT(@SQLGroupBy, LEN(@SQLGroupBy) - 1)

		SET @SQLStatement = '
			INSERT INTO [#DC_Sales]
				(' + @SQLInsertInto + '
				)
			SELECT' + @SQLSelect + ',
				[Sales_Value] = SUM(CASE MS.[Label]
					WHEN ''SalesPrice_'' THEN [Raw].[SalesPrice_] 
					WHEN ''SalesMiscCharge_'' THEN [Raw].[SalesMiscCharge_] 
					WHEN ''SalesDiscount_'' THEN [Raw].[SalesDiscount_]
					WHEN ''SalesCOGSLabor'' THEN [Raw].[SalesCOGSLabor]
					WHEN ''SalesCOGSMater'' THEN [Raw].[SalesCOGSMater]
					WHEN ''SalesCOGSBurden'' THEN [Raw].[SalesCOGSBurden]
					WHEN ''SalesCOGSSubCont'' THEN [Raw].[SalesCOGSSubCont]
					WHEN ''SalesCOGSMatBurd'' THEN [Raw].[SalesCOGSMatBurd]
					WHEN ''SalesCost_'' THEN [Raw].[SalesCOGSLabor] + [Raw].[SalesCOGSMater] + [Raw].[SalesCOGSBurden] + [Raw].[SalesCOGSSubCont] + [Raw].[SalesCOGSMatBurd]
					WHEN ''SalesCOGSLabor_Unit'' THEN [Raw].[SalesCOGSLabor_Unit]
					WHEN ''SalesCOGSMater_Unit'' THEN [Raw].[SalesCOGSMater_Unit]
					WHEN ''SalesCOGSBurden_Unit'' THEN [Raw].[SalesCOGSBurden_Unit]
					WHEN ''SalesCOGSSubCont_Unit'' THEN [Raw].[SalesCOGSSubCont_Unit]
					WHEN ''SalesCOGSMatBurd_Unit'' THEN [Raw].[SalesCOGSMatBurd_Unit]
					WHEN ''SalesQtyUnit_'' THEN [Raw].[SalesQtyUnit_]
					WHEN ''SalesQtyOrder_'' THEN [Raw].[SalesQtyOrder_]
					WHEN ''SalesQtyOrderLine_'' THEN [Raw].[SalesQtyOrderLine_]
				ELSE 0 END)
			FROM
				[#DC_Sales_Raw] [Raw]
				INNER JOIN #MemberSelection MS ON MS.RNodeType = ''L''
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Account] [Account] ON [Account].[Label] COLLATE DATABASE_DEFAULT = MS.[Label]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessProcess] [BusinessProcess] ON [BusinessProcess].[Label] COLLATE DATABASE_DEFAULT = ''' + @BusinessProcess + '''
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Currency] [Currency] ON [Currency].Label COLLATE DATABASE_DEFAULT = CASE WHEN MS.Unit = ''Currency'' THEN [Raw].[Currency] ELSE ''NONE'' END
			' 
					
		SET @SQLStatement =	@SQLStatement + @SQLDimJoin
		SET @SQLStatement = @SQLStatement + CASE WHEN @StartDay IS NULL THEN '' ELSE '
			WHERE
				[Raw].TimeDay >= ' + CONVERT(nvarchar(15), @StartDay) END + '
			GROUP BY
			'
		
		SET @SQLStatement =	@SQLStatement + @SQLGroupBy + CHAR(13) + CHAR(10) + CHAR(9)
		
		SET @SQLStatement = @SQLStatement + ' 
			HAVING
				SUM(CASE MS.[Label]
					WHEN ''SalesPrice_'' THEN [Raw].[SalesPrice_] 
					WHEN ''SalesMiscCharge_'' THEN [Raw].[SalesMiscCharge_] 
					WHEN ''SalesDiscount_'' THEN [Raw].[SalesDiscount_]
					WHEN ''SalesCOGSLabor'' THEN [Raw].[SalesCOGSLabor]
					WHEN ''SalesCOGSMater'' THEN [Raw].[SalesCOGSMater]
					WHEN ''SalesCOGSBurden'' THEN [Raw].[SalesCOGSBurden]
					WHEN ''SalesCOGSSubCont'' THEN [Raw].[SalesCOGSSubCont]
					WHEN ''SalesCOGSMatBurd'' THEN [Raw].[SalesCOGSMatBurd]
					WHEN ''SalesCost_'' THEN [Raw].[SalesCOGSLabor] + [Raw].[SalesCOGSMater] + [Raw].[SalesCOGSBurden] + [Raw].[SalesCOGSSubCont] + [Raw].[SalesCOGSMatBurd]
					WHEN ''SalesCOGSLabor_Unit'' THEN [Raw].[SalesCOGSLabor_Unit]
					WHEN ''SalesCOGSMater_Unit'' THEN [Raw].[SalesCOGSMater_Unit]
					WHEN ''SalesCOGSBurden_Unit'' THEN [Raw].[SalesCOGSBurden_Unit]
					WHEN ''SalesCOGSSubCont_Unit'' THEN [Raw].[SalesCOGSSubCont_Unit]
					WHEN ''SalesCOGSMatBurd_Unit'' THEN [Raw].[SalesCOGSMatBurd_Unit]
					WHEN ''SalesQtyUnit_'' THEN [Raw].[SalesQtyUnit_]
					WHEN ''SalesQtyOrder_'' THEN [Raw].[SalesQtyOrder_]
					WHEN ''SalesQtyOrderLine_'' THEN [Raw].[SalesQtyOrderLine_]
				ELSE 0 END) <> 0'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Selected = @@ROWCOUNT
				
		IF @DebugBM & 2 > 0 SELECT Step = '#DC_Sales', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #DC_Sales
		IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_Sales', * FROM #DC_Sales

/*
	SET @Step = 'Create #FACT_Update'
		SELECT DISTINCT
			[BusinessProcess_MemberId],
			[Entity_MemberId],
			[Scenario_MemberId],
			[Time_MemberId] = [TimeDay_MemberId] / 100
		INTO
			[#FACT_Update]
		FROM
			#DC_Sales

		IF @DebugBM & 8 > 0 SELECT TempTable = '#FACT_Update', * FROM #FACT_Update ORDER BY [BusinessProcess_MemberId], [Entity_MemberId], [Scenario_MemberId], [Time_MemberId]

	SET @Step = 'Calculate Fx'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DataClassID",  "TValue": "' + CONVERT(nvarchar(15), @DataClassID) + '"},
			{"TKey" : "CalledBy",  "TValue": "ETL"},
			{"TKey" : "TempTable",  "TValue": "#DC_Sales"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}
			]'

		IF @DebugBM & 2 > 0 PRINT @JSON
		EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spBR_BR04', @JSON = @JSON

	SET @Step = 'Set all existing rows that should be inserted to 0'
		SET @SQLStatement = '
			UPDATE
				F
			SET
				[Sales_Value] = 0
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_Sales_default_partition] F
				INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_TimeDay] TimeDay ON TimeDay.MemberId = F.TimeDay_MemberId
				INNER JOIN [#FACT_Update] FU ON
					FU.[BusinessProcess_MemberId] = F.[BusinessProcess_MemberId] AND
					FU.[Entity_MemberId] = F.[Entity_MemberId] AND
					FU.[Scenario_MemberId] = F.[Scenario_MemberId] AND
					FU.[Time_MemberId] = TimeDay.[TimeYear_MemberId] * 100 + TimeDay.[TimeMonth_MemberId] % 100'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Drop INDEX in Sales FACT table'
		SET @SQLStatement = '
			SELECT @InternalVariable = COUNT(1) 
			FROM ' + @CallistoDatabase + '.sys.indexes 
			WHERE
				object_id = OBJECT_ID(''' + @CallistoDatabase + '.dbo.FACT_Sales_default_partition'', N''U'') AND
				[name]=''IX_Sales_OrderState'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ReturnVariable OUT

		IF @DebugBM & 2 > 0 SELECT [CountIndex_IX_Sales_OrderState] = @ReturnVariable
		
		IF @ReturnVariable > 0
			BEGIN
				SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.[dbo].sp_executesql N''DROP INDEX dbo.[FACT_Sales_default_partition].[IX_Sales_OrderState]'''
				
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END		
*/
	SET @Step = 'Insert rows into FACT table'
		--SET @SQLStatement = '
		--	INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_Sales_default_partition]
		--		(
		--		[Account_MemberId],
		--		[BusinessProcess_MemberId],
		--		[BusinessRule_MemberId],
		--		[Currency_MemberId],
		--		[CurrentOrderState_MemberId],
		--		[Customer_MemberId],
		--		[Entity_MemberId],
		--		[InvoiceNo_AR_MemberId],
		--		--[OrderManager_MemberId],
		--		[OrderLine_MemberId],
		--		[OrderNo_MemberId],
		--		[OrderState_MemberId],
		--		--[OrderType_MemberId],
		--		--[Plant_MemberId],
		--		[Product_MemberId],
		--		[Scenario_MemberId],
		--		[TimeDataView_MemberId],
		--		[TimeDay_MemberId],
		--		[ChangeDatetime],
		--		[Userid],
		--		[Sales_Value]
		--		)
		--	SELECT
		--		[Account_MemberId],
		--		[BusinessProcess_MemberId],
		--		[BusinessRule_MemberId],
		--		[Currency_MemberId],
		--		[CurrentOrderState_MemberId],
		--		[Customer_MemberId],
		--		[Entity_MemberId],
		--		[InvoiceNo_AR_MemberId],
		--		--[OrderManager_MemberId],
		--		[OrderLine_MemberId],
		--		[OrderNo_MemberId],
		--		[OrderState_MemberId],
		--		--[OrderType_MemberId],
		--		--[Plant_MemberId],
		--		[Product_MemberId],
		--		[Scenario_MemberId],
		--		[TimeDataView_MemberId],
		--		[TimeDay_MemberId],
		--		[ChangeDatetime] = GetDate(),
		--		[Userid] = suser_name(),
		--		[Sales_Value]
		--	FROM
		--		#DC_Sales'

		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_Sales_default_partition]
				(' + @SQLDim_FACT_Sales + '
				[ChangeDatetime],
				[Userid],
				[Sales_Value]
				)
			SELECT' + @SQLDim_FACT_Sales + '
				[ChangeDatetime] = GetDate(),
				[Userid] = suser_name(),
				[Sales_Value]
			FROM
				#DC_Sales'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT
/*
	SET @Step = 'Clean up'
		IF (SELECT DATEPART(WEEKDAY, GETDATE())) IN (6, 7) OR @SpeedRunYN = 0 --Saturday, Sunday or not SpeedRun
			BEGIN
				SET @SQLStatement = '
					DELETE
						F
					FROM
						' + @CallistoDatabase + '.[dbo].[FACT_Sales_default_partition] F
					WHERE
						[Sales_Value] = 0'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Deleted = @Deleted + @@ROWCOUNT
			END

	SET @Step = 'Set CurrentOrderState'
		INSERT INTO #OrderState
			(
			[Entity_MemberID],
			[OrderNo_MemberID],
			[OrderLine_MemberId]
			)
		SELECT DISTINCT
			[Entity_MemberID],
			[OrderNo_MemberID],
			[OrderLine_MemberId]
		FROM
			#DC_Sales
		WHERE
			[OrderNo_MemberID] <> -1 AND
			[OrderLine_MemberId] <> -1
		ORDER BY
			[Entity_MemberID],
			[OrderNo_MemberID],
			[OrderLine_MemberId]

		IF @DebugBM & 8 > 0 SELECT * FROM #OrderState ORDER BY RowID

		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "TableName_DataClass",  "TValue": "' + @TableName_DataClass + '"},
			{"TKey" : "FullReloadYN",  "TValue": "' + CONVERT(nvarchar(15), CONVERT(int, @FullReloadYN)) + '"},
			{"TKey" : "StepSize",  "TValue": "' + CONVERT(nvarchar(15), @StepSize) + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}
			]'

		IF @DebugBM & 2 > 0 PRINT @JSON
		EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_DC_Sales_CurrentOrderState', @JSON = @JSON
*/
	SET @Step = 'Drop temp tables'
		DROP TABLE #MemberSelection
		DROP TABLE #DataClassColumns
		DROP TABLE #DC_Sales_Raw
		DROP TABLE #DC_Sales
		DROP TABLE #OrderState

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
