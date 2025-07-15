SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR15]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000795,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spBR_BR15',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "460"},
		{"TKey" : "VersionID",  "TValue": "1052"}
		]'

EXEC [spBR_BR15] @UserID=-10, @InstanceID=460, @VersionID=1052, @DebugBM=3

EXEC [spBR_BR15] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@FromTimeDay int,
	@ToTimeDay int,
    
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
	@ToBeChanged nvarchar(255) = 'Convert to generic SP. Right now, this is only specific for TPH.',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2177'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Commission Calculations',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2177' SET @Description = 'Procedure created.'

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


--Create temp table #TimeDay
CREATE TABLE #TimeDay
	(
	TimeDay bigint
	)

--Create temp table
CREATE TABLE #Commission
	(
	[Account] nvarchar(50),
	[AccountManager] nvarchar(50),
	[BusinessProcess] nvarchar(50),
	[BusinessRule] nvarchar(50),
	[Currency] nvarchar(50),
	[CustomerCategory] nvarchar(50),
	[Entity] nvarchar(50),
	[Flow] nvarchar(50),
	[OrderManager] nvarchar(50),
	[ProductCategory] nvarchar(50),
	[ProductGroup] nvarchar(50),
	[Scenario] nvarchar(50),
	[TimeDataView] nvarchar(50),
	[TimeDay] nvarchar(50),
	[WorkflowState] nvarchar(50),
	[Commission_Value] float
	)


--BusinessRuleID = 2546, Comment = 2021 ISR
SELECT 
	OrderManager,
	TimeDay,
	Component_Value = SUM(Commission_Value)
INTO
	#2546_Component
FROM
	[pcDATA_TPH].[dbo].[FACT_Commission_View]
WHERE
	Account = 'CB_B_NetSales_ISR' AND
	Scenario = 'ACTUAL' AND
	Currency = 'USD' AND
	Entity = 'TPH'
GROUP BY
	OrderManager,
	TimeDay
ORDER BY
	OrderManager,
	TimeDay


SELECT
	@FromTimeDay = MIN(TimeDay),
	@ToTimeDay = MAX(TimeDay)
FROM
	#2546_Component

IF @DebugBM & 2 > 0
	SELECT
		[@FromTimeDay] = @FromTimeDay,
		[@ToTimeDay] = @ToTimeDay

TRUNCATE TABLE #TimeDay
	
INSERT INTO #TimeDay
	(
	TimeDay
	)
SELECT
	TimeDay = MemberId
FROM
	pcDATA_TPH..S_DS_TimeDay
WHERE
	MemberID BETWEEN @FromTimeDay AND @ToTimeDay

SELECT
	ComponentID = 1015,
	sub.OrderManager, 
	TDMax.TimeDay,
	sub.Factor 
INTO
	#2546_ComponentTierFactor
FROM
	(
	SELECT
		OrderManager, 
		TimeDay = TD.TimeDay, 
		TimeDayChange= MAX(CASE WHEN C.TimeDay <= TD.TimeDay THEN C.TimeDay ELSE 0 END)
	FROM
		[pcDATA_TPH].[dbo].[FACT_Commission_View] C
		INNER JOIN #TimeDay TD ON 1=1
	WHERE
		Account = 'CB_G_SalesRate' AND
		Scenario = 'ACTUAL'
	GROUP BY
		C.OrderManager,
		TD.TimeDay
	) TDMax
	INNER JOIN
	(
	SELECT
		OrderManager,
		TimeDay,
		Factor = MAX(Commission_Value) 
	FROM
		[pcDATA_TPH].[dbo].[FACT_Commission_View]
	WHERE
		Account = 'CB_G_SalesRate' AND
		Scenario = 'ACTUAL'
	GROUP BY
		OrderManager,
		TimeDay
	) sub ON sub.OrderManager = TDMax.OrderManager AND sub.TimeDay=TDMax.TimeDayChange

IF @DebugBM & 2 > 0
	BEGIN
		SELECT TempTable='#2546_Component', * FROM #2546_Component
		SELECT TempTable='#2546_ComponentTierFactor', * FROM #2546_ComponentTierFactor ORDER BY OrderManager, TimeDay
	END


/*
SELECT OrderManager, Factor = MAX(Commission_Value) 
INTO
	#2546_ComponentTierFactor
FROM [pcDATA_TPH].[dbo].[FACT_Commission_View]
WHERE Account = 'CB_G_SalesRate' AND Scenario = 'ACTUAL'
GROUP BY
	OrderManager

IF @DebugBM & 2 > 0
	BEGIN
		SELECT * FROM #2546_Component
		SELECT * FROM #2546_ComponentTierFactor
	END
*/

INSERT INTO #Commission
	(
	[Account],
	[AccountManager],
	[BusinessProcess],
	[BusinessRule],
	[Currency],
	[CustomerCategory],
	[Entity],
	[Flow],
	[OrderManager],
	[ProductCategory],
	[ProductGroup],
	[Scenario],
	[TimeDataView],
	[TimeDay],
	[WorkflowState],
	[Commission_Value]
	)
SELECT
	[Account] = 'CB_S_C_ISR',
	[AccountManager] = 'NONE',
	[BusinessProcess] = 'BR_CB',
	[BusinessRule] = 'NONE',
	[Currency] = 'USD',
	[CustomerCategory] = 'NONE',
	[Entity] = 'TPH',
	[Flow] = 'NONE',
	[OrderManager] = C.OrderManager,
	[ProductCategory] = 'NONE',
	[ProductGroup] = 'NONE',
	[Scenario] = 'ACTUAL',
	[TimeDataView] = 'RAWDATA',
	[TimeDay] = C.TimeDay,
	[WorkflowState] = 'NONE',
	[Commission_Value] = C.Component_Value * CTF.Factor
FROM
	#2546_Component C
	INNER JOIN #2546_ComponentTierFactor CTF ON CTF.OrderManager = C.OrderManager AND CTF.TimeDay = C.TimeDay

DROP TABLE #2546_Component
DROP TABLE #2546_ComponentTierFactor

-----------------------
--BusinessRuleID = 2547, Comment = 2021 OSR Sales

SELECT 
	AccountManager,
	TimeDay,
	Component_Value = SUM(Commission_Value)
INTO
	#2547_Component
FROM
	[pcDATA_TPH].[dbo].[FACT_Commission_View]
WHERE
	Account = 'CB_B_NetSales_OSR' AND
	Scenario = 'ACTUAL' AND
	Currency = 'USD' AND
	Entity = 'TPH'
GROUP BY
	AccountManager,
	TimeDay
ORDER BY
	AccountManager,
	TimeDay

-----------------------
SELECT
	@FromTimeDay = MIN(TimeDay),
	@ToTimeDay = MAX(TimeDay)
FROM
	#2547_Component

IF @DebugBM & 2 > 0
	SELECT
		[@FromTimeDay] = @FromTimeDay,
		[@ToTimeDay] = @ToTimeDay

TRUNCATE TABLE #TimeDay
	
INSERT INTO #TimeDay
	(
	TimeDay
	)
SELECT
	TimeDay = MemberId
FROM
	pcDATA_TPH..S_DS_TimeDay
WHERE
	MemberID BETWEEN @FromTimeDay AND @ToTimeDay

SELECT
	sub.AccountManager, 
	TDMax.TimeDay,
	sub.Factor 
INTO
	#2547_ComponentTierFactor
FROM
	(
	SELECT
		AccountManager, 
		TimeDay = TD.TimeDay, 
		TimeDayChange= MAX(CASE WHEN C.TimeDay <= TD.TimeDay THEN C.TimeDay ELSE 0 END)
	FROM
		[pcDATA_TPH].[dbo].[FACT_Commission_View] C
		INNER JOIN #TimeDay TD ON 1=1
	WHERE
		Account = 'CB_G_SalesRate' AND
		Scenario = 'ACTUAL'
	GROUP BY
		C.AccountManager,
		TD.TimeDay
	) TDMax
	INNER JOIN
	(
	SELECT
		AccountManager,
		TimeDay,
		Factor = MAX(Commission_Value) 
	FROM
		[pcDATA_TPH].[dbo].[FACT_Commission_View]
	WHERE
		Account = 'CB_G_SalesRate' AND
		Scenario = 'ACTUAL'
	GROUP BY
		AccountManager,
		TimeDay
	) sub ON sub.AccountManager = TDMax.AccountManager AND sub.TimeDay=TDMax.TimeDayChange

IF @DebugBM & 2 > 0
	BEGIN
		SELECT TempTable='#2547_Component', * FROM #2547_Component
		SELECT TempTable='#2547_ComponentTierFactor', * FROM #2547_ComponentTierFactor ORDER BY AccountManager, TimeDay
	END


----------------------


--SELECT AccountManager, Factor = MAX(Commission_Value) 
--INTO
--	#2547_ComponentTierFactor
--FROM [pcDATA_TPH].[dbo].[FACT_Commission_View]
--WHERE Account = 'CB_G_SalesRate' AND Scenario = 'ACTUAL'
--GROUP BY
--	AccountManager

--IF @DebugBM & 2 > 0
--	BEGIN
--		SELECT * FROM #2547_Component
--		SELECT * FROM #2547_ComponentTierFactor
--	END

INSERT INTO #Commission
	(
	[Account],
	[AccountManager],
	[BusinessProcess],
	[BusinessRule],
	[Currency],
	[CustomerCategory],
	[Entity],
	[Flow],
	[OrderManager],
	[ProductCategory],
	[ProductGroup],
	[Scenario],
	[TimeDataView],
	[TimeDay],
	[WorkflowState],
	[Commission_Value]
	)
SELECT
	[Account] = 'CB_S_C_OSR_NS',
	[AccountManager] = C.AccountManager,
	[BusinessProcess] = 'BR_CB',
	[BusinessRule] = 'NONE',
	[Currency] = 'USD',
	[CustomerCategory] = 'NONE',
	[Entity] = 'TPH',
	[Flow] = 'NONE',
	[OrderManager] = 'NONE',
	[ProductCategory] = 'NONE',
	[ProductGroup] = 'NONE',
	[Scenario] = 'ACTUAL',
	[TimeDataView] = 'RAWDATA',
	[TimeDay] = C.TimeDay,
	[WorkflowState] = 'NONE',
	[Commission_Value] = C.Component_Value * CTF.Factor
FROM
	#2547_Component C
	INNER JOIN #2547_ComponentTierFactor CTF ON CTF.AccountManager = C.AccountManager AND CTF.TimeDay = C.TimeDay

DROP TABLE #2547_Component
DROP TABLE #2547_ComponentTierFactor

-----------------------
--BusinessRuleID = 2548, Comment = 2021 OSR GP

SELECT
	ComponentID,
	AccountManager,
	TimeDay,
	Component_Value
INTO
	#2548_Component
FROM
	(
	SELECT 
		ComponentID = 1015,
		AccountManager,
		TimeDay,
		Component_Value = SUM(Commission_Value)
	FROM
		[pcDATA_TPH].[dbo].[FACT_Commission_View]
	WHERE
		Account = 'CB_B_GP' AND
		Scenario = 'ACTUAL' AND
		Currency = 'USD' AND
		Entity = 'TPH'
	GROUP BY
		AccountManager,
		TimeDay
	) sub

SELECT
	@FromTimeDay = MIN(TimeDay),
	@ToTimeDay = MAX(TimeDay)
FROM
	#2548_Component

IF @DebugBM & 2 > 0
	SELECT
		[@FromTimeDay] = @FromTimeDay,
		[@ToTimeDay] = @ToTimeDay

TRUNCATE TABLE #TimeDay
	
INSERT INTO #TimeDay
	(
	TimeDay
	)
SELECT
	TimeDay = MemberId
FROM
	pcDATA_TPH..S_DS_TimeDay
WHERE
	MemberID BETWEEN @FromTimeDay AND @ToTimeDay

SELECT
	ComponentID = 1015,
	sub.AccountManager, 
	TDMax.TimeDay,
	sub.Factor 
INTO
	#2548_ComponentTierFactor
FROM
	(
	SELECT
		AccountManager, 
		TimeDay = TD.TimeDay, 
		TimeDayChange= MAX(CASE WHEN C.TimeDay <= TD.TimeDay THEN C.TimeDay ELSE 0 END)
	FROM
		[pcDATA_TPH].[dbo].[FACT_Commission_View] C
		INNER JOIN #TimeDay TD ON 1=1
	WHERE
		Account = 'CB_G_GPRate' AND
		Scenario = 'ACTUAL'
	GROUP BY
		C.AccountManager,
		TD.TimeDay
	) TDMax
	INNER JOIN
	(
	SELECT
		AccountManager,
		TimeDay,
		Factor = MAX(Commission_Value) 
	FROM
		[pcDATA_TPH].[dbo].[FACT_Commission_View]
	WHERE
		Account = 'CB_G_GPRate' AND
		Scenario = 'ACTUAL'
	GROUP BY
		AccountManager,
		TimeDay
	) sub ON sub.AccountManager = TDMax.AccountManager AND sub.TimeDay=TDMax.TimeDayChange



IF @DebugBM & 2 > 0
	BEGIN
		SELECT TempTable='#2548_Component', * FROM #2548_Component
		SELECT TempTable='#2548_ComponentTierFactor', * FROM #2548_ComponentTierFactor ORDER BY AccountManager, TimeDay
	END

--RETURN

INSERT INTO #Commission
	(
	[Account],
	[AccountManager],
	[BusinessProcess],
	[BusinessRule],
	[Currency],
	[CustomerCategory],
	[Entity],
	[Flow],
	[OrderManager],
	[ProductCategory],
	[ProductGroup],
	[Scenario],
	[TimeDataView],
	[TimeDay],
	[WorkflowState],
	[Commission_Value]
	)
SELECT
	[Account] = 'CB_S_C_OSR_GP',
	[AccountManager] = C.AccountManager,
	[BusinessProcess] = 'BR_CB',
	[BusinessRule] = 'NONE',
	[Currency] = 'USD',
	[CustomerCategory] = 'NONE',
	[Entity] = 'TPH',
	[Flow] = 'NONE',
	[OrderManager] = 'NONE',
	[ProductCategory] = 'NONE',
	[ProductGroup] = 'NONE',
	[Scenario] = 'ACTUAL',
	[TimeDataView] = 'RAWDATA',
	[TimeDay] = C.TimeDay,
	[WorkflowState] = 'NONE',
	[Commission_Value] = C.Component_Value * CTF.Factor
FROM
	#2548_Component C
	INNER JOIN #2548_ComponentTierFactor CTF ON CTF.ComponentID = C.ComponentID AND CTF.AccountManager = C.AccountManager AND CTF.TimeDay = C.TimeDay

DROP TABLE #2548_Component
DROP TABLE #2548_ComponentTierFactor

-----------------------
--BusinessRuleID = 2570, Comment = 2021 OSR BW

SELECT
	AccountManager,
	TimeDay,
	Component_Value = SUM(Commission_Value)
INTO
	#2570_Component
FROM
	[pcDATA_TPH].[dbo].[FACT_Commission_View]
WHERE
	Account = 'CB_B_NetSales_OSR_BW' AND
	Scenario = 'ACTUAL' AND
	Currency = 'USD' AND
	Entity = 'TPH'
GROUP BY
	AccountManager,
	TimeDay
ORDER BY
	AccountManager,
	TimeDay


SELECT AccountManager, Factor = 0.01
INTO
	#2570_ComponentTierFactor
FROM 
	[pcDATA_TPH].[dbo].[FACT_Commission_View]
WHERE Account = 'CB_B_NetSales_OSR_BW' AND
	Scenario = 'ACTUAL' AND
	Currency = 'USD' AND
	Entity = 'TPH'
GROUP BY
	AccountManager

IF @DebugBM & 2 > 0
	BEGIN
		SELECT * FROM #2570_Component
		SELECT * FROM #2570_ComponentTierFactor
	END

INSERT INTO #Commission
	(
	[Account],
	[AccountManager],
	[BusinessProcess],
	[BusinessRule],
	[Currency],
	[CustomerCategory],
	[Entity],
	[Flow],
	[OrderManager],
	[ProductCategory],
	[ProductGroup],
	[Scenario],
	[TimeDataView],
	[TimeDay],
	[WorkflowState],
	[Commission_Value]
	)
SELECT
	[Account] = 'CB_S_C_OSR_BW',
	[AccountManager] = C.AccountManager,
	[BusinessProcess] = 'BR_CB',
	[BusinessRule] = 'NONE',
	[Currency] = 'USD',
	[CustomerCategory] = 'NONE',
	[Entity] = 'TPH',
	[Flow] = 'NONE',
	[OrderManager] = 'NONE',
	[ProductCategory] = 'NONE',
	[ProductGroup] = 'NONE',
	[Scenario] = 'ACTUAL',
	[TimeDataView] = 'RAWDATA',
	[TimeDay] = C.TimeDay,
	[WorkflowState] = 'NONE',
	[Commission_Value] = C.Component_Value * CTF.Factor
FROM
	#2570_Component C
	INNER JOIN #2570_ComponentTierFactor CTF ON CTF.AccountManager = C.AccountManager

DROP TABLE #2570_Component
DROP TABLE #2570_ComponentTierFactor


-----------------
DELETE DC
FROM
	[pcDATA_TPH].[dbo].[FACT_Commission_default_partition] DC
	INNER JOIN pcDATA_TPH..S_DS_Account A ON A.[MemberId] = DC.[Account_MemberId] AND A.[Label] IN ('CB_S_C_ISR','CB_S_C_OSR_NS','CB_S_C_OSR_GP','CB_S_C_OSR_BW')

	SET @Deleted = @Deleted + @@ROWCOUNT

INSERT INTO [pcDATA_TPH].[dbo].[FACT_Commission_default_partition]
	(
	[Account_MemberId],
	[AccountManager_MemberId],
	[BusinessProcess_MemberId],
	[BusinessRule_MemberId],
	[Currency_MemberId],
	[CustomerCategory_MemberId],
	[Entity_MemberId],
	[Flow_MemberId],
	[OrderManager_MemberId],
	[ProductCategory_MemberId],
	[ProductGroup_MemberId],
	[Scenario_MemberId],
	[TimeDataView_MemberId],
	[TimeDay_MemberId],
	[WorkflowState_MemberId],
	[ChangeDatetime],
	[Userid],
	[Commission_Value]
	)
SELECT 
	[Account_MemberId] = A.[MemberId],
	[AccountManager_MemberId] = AM.[MemberId],
	[BusinessProcess_MemberId] = BP.[MemberId],
	[BusinessRule_MemberId] = -1,
	[Currency_MemberId] = 840,
	[CustomerCategory_MemberId] = -1,
	[Entity_MemberId] = E.[MemberId] ,
	[Flow_MemberId] = -1,
	[OrderManager_MemberId] = OM.[MemberId],
	[ProductCategory_MemberId] = -1,
	[ProductGroup_MemberId] = -1,
	[Scenario_MemberId] = 110,
	[TimeDataView_MemberId] = 101,
	[TimeDay_MemberId] = C.TimeDay,
	[WorkflowState_MemberId] = -1,
	[ChangeDatetime] = GetDate(),
	[Userid] = suser_name(),
	[Commission_Value] = C.[Commission_Value]
FROM
	#Commission C
	INNER JOIN pcDATA_TPH..S_DS_Account A ON A.[Label] = C.[Account]
	INNER JOIN pcDATA_TPH..S_DS_AccountManager AM ON AM.[Label] = C.[AccountManager]
	INNER JOIN pcDATA_TPH..S_DS_BusinessProcess BP ON BP.[Label] = C.[BusinessProcess]
	INNER JOIN pcDATA_TPH..S_DS_Entity E ON E.[Label] = C.[Entity]
	INNER JOIN pcDATA_TPH..S_DS_OrderManager OM ON OM.[Label] = C.[OrderManager]

	SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [ErrorNumber] = @ErrorNumber, [ErrorSeverity] = @ErrorSeverity, [ErrorState] = @ErrorState, [ErrorProcedure] = @ErrorProcedure, [ErrorStep] = @Step, [ErrorLine] = @ErrorLine, [ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
