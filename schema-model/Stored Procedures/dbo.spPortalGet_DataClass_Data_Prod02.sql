SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_DataClass_Data_Prod02]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DataClassID int = NULL,
	@MasterDataClassID int = NULL, --If set @DataClassID is of type SpreadingKey
	@ResultTypeBM int = 3, --1 = Filter, 2 = Filter rows, 4 = Data, 8 = Changeable, 16 = Last Actor UserID, 32 = LineItem, 64 = Comment, 128=Add column LineItemYN to ResultTypeBM = 4

	@GroupBy nvarchar(1024) = NULL,
	@Measure nvarchar(1024) = NULL,
	@Filter nvarchar(4000) = NULL,
	@PropertyList nvarchar(1024) = NULL,
	@DimensionList nvarchar(1024) = NULL,
	@Hierarchy nvarchar(1024) = NULL,
	@FilterLevel64 nvarchar(3) = NULL, --Valid for ResultTypeBM = 64 and 128; L=LeafLevel, P=Parent, LF=LevelFilter (not up or down), LLF=LevelFilter + all members below
	@OnlyDataClassDimMembersYN bit = 1, --Valid for @ResultTypeBM = 2
	@Parent_MemberKey nvarchar(1024) = NULL, --Valid for @ResultTypeBM = 2, Sample: 'GL_Student_ID=All_' Separator=|

	@ActingAs int = NULL, --Optional (OrganizationPositionID)
	@AssignmentID int = NULL,
	@WorkFlowStateID int = NULL,
	@OnlySecuredDimYN bit = 0,
	@ShowAllMembersYN bit = 0,
	@UseCacheYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000841,
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
EXEC [spRun_Procedure_KeyValuePair] @ProcedureName='spPortalGet_DataClass_Data_Prod02', @JSON='[{"TKey" : "UserID", "TValue" : "9863"},{"TKey" : "InstanceID", "TValue" : "572"},
{"TKey" : "VersionID", "TValue" : "1080"},{"TKey" : "DataClassID", "TValue" : "5713"},{"TKey" : "ResultTypeBM", "TValue" : "40"},{"TKey" : "GroupBy", "TValue" : "Time|LineItem"},
{"TKey" : "Measure", "TValue" : "Financials"},{"TKey" : "AssignmentID", "TValue" : "18896"},
{"TKey" : "Filter", "TValue" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=FY2023|Scenario=BUDGET|Entity=US01|Currency=USD|Account=8741|GL_CostCenter=07|GL_Branch=807"},
{"TKey" : "ActingAs", "TValue" : "5573"},{"TKey" : "UseCacheYN", "TValue" : "false"}]'

EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DataClass_Data_Prod02] @ActingAs='10159',@AssignmentID='25764',@DataClassID='15025',@Filter='Flow=NONE|OrderState=60|Supplier=NONE|Customer=Dreer_|Time=2021|Scenario=BUDGET|Entity=EPIC03|Currency=USD|Account=SalesAmount_|GL_Department=20|GL_Division=01|GL_Reference_Type=NONE|Product=All_|BusinessProcess=INPUT|BusinessRule=NONE|TimeDataView=RAWDATA',
@GroupBy='Time|LineItem',@InstanceID='-1508',@Measure='Financials',@ResultTypeBM='40',@UseCacheYN='false',@UserID='15985',@VersionID='-1508',@DebugBM=15

EXEC [spRun_Procedure_KeyValuePair] @ProcedureName='spPortalGet_DataClass_Data_Prod02', @JSON='[{"TKey" : "DebugBM", "TValue" : "7"},
{"TKey" : "UserID", "TValue" : "8033"},{"TKey" : "InstanceID", "TValue" : "486"},{"TKey" : "VersionID", "TValue" : "1035"},
{"TKey" : "DataClassID", "TValue" : "5297"},{"TKey" : "ResultTypeBM", "TValue" : "204"},{"TKey" : "GroupBy", "TValue" : "Time|Account|GL_Division|GL_Department"},
{"TKey" : "Measure", "TValue" : "Financials"},{"TKey" : "AssignmentID", "TValue" : "17610"},
{"TKey" : "Filter", "TValue" : "Time=FY2022|Scenario=BUDGET|Entity=1001|Currency=USD|GL_Department=HRCC|GL_Division=All_|GL_Reference=NONE|Account=AC_EXPENSES|BusinessProcess=INPUT|BusinessRule=NONE|Employee=NONE|GL_Posted=TRUE|TimeDataView=RAWDATA|Version=NONE"},
{"TKey" : "ActingAs", "TValue" : "3184"},{"TKey" : "UseCacheYN", "TValue" : "false"}]'

EXEC [spRun_Procedure_KeyValuePair] @ProcedureName='spPortalGet_DataClass_Data_Prod02', @JSON='[{"TKey" : "DebugBM", "TValue" : "7"},
{"TKey" : "UserID", "TValue" : "1127"},{"TKey" : "InstanceID", "TValue" : "529"},{"TKey" : "VersionID", "TValue" : "1001"},
{"TKey" : "DataClassID", "TValue" : "1002"},{"TKey" : "ResultTypeBM", "TValue" : "204"},{"TKey" : "GroupBy", "TValue" : "Time|Currency|Rate"},
{"TKey" : "Measure", "TValue" : "FxRate"},{"TKey" : "AssignmentID", "TValue" : "1002"},
{"TKey" : "Filter", "TValue" : "BaseCurrency=USD|Time=2021|Scenario=BUDGET|Rate=All_|Currency=All_"},
{"TKey" : "ActingAs", "TValue" : "1001"},{"TKey" : "UseCacheYN", "TValue" : "false"}]'

-- 2020
EXEC spRun_Procedure_KeyValuePair @ProcedureName='spPortalGet_DataClass_Data_Prod02',@JSON='[{"TKey" : "UserID", "TValue" : "2147"},
{"TKey" : "InstanceID", "TValue" : "413"},{"TKey" : "VersionID", "TValue" : "1008"},{"TKey" : "DataClassID", "TValue" : "1028"},
{"TKey" : "ResultTypeBM", "TValue" : "64"},{"TKey" : "GroupBy", "TValue" : "Time.TimeFiscalYear|GL_Project|Account"},
{"TKey" : "Measure", "TValue" : "Financials"},{"TKey" : "AssignmentID", "TValue" : "13795"},
{"TKey" : "Filter", "TValue" : "Time=FY2020|Scenario=BUDGET|Entity=52982|Currency=USD|GL_Department=DC60|Account=AC_NA_SA|BusinessProcess=INPUT|GL_Project=All_"},
{"TKey" : "Hierarchy", "TValue" : "Account=1"},{"TKey" : "DebugBM", "TValue" : "1"}]'

-- 2021
EXEC spRun_Procedure_KeyValuePair @ProcedureName='spPortalGet_DataClass_Data_Prod02',@JSON='[{"TKey" : "UserID", "TValue" : "2147"},
{"TKey" : "InstanceID", "TValue" : "413"},{"TKey" : "VersionID", "TValue" : "1008"},{"TKey" : "DataClassID", "TValue" : "1028"},
{"TKey" : "ResultTypeBM", "TValue" : "64"},{"TKey" : "GroupBy", "TValue" : "Time.TimeFiscalYear|GL_Project|Account"},
{"TKey" : "Measure", "TValue" : "Financials"},{"TKey" : "AssignmentID", "TValue" : "13795"},
{"TKey" : "Filter", "TValue" : "Time=FY2021|Scenario=BUDGET|Entity=52982|Currency=USD|GL_Department=DC60|Account=AC_NA_SA|BusinessProcess=INPUT|GL_Project=All_"},
{"TKey" : "Hierarchy", "TValue" : "Account=1"},{"TKey" : "DebugBM", "TValue" : "3"}]'


-- 2021 months
EXEC spRun_Procedure_KeyValuePair @ProcedureName='spPortalGet_DataClass_Data_Prod02',@JSON='[{"TKey" : "UserID", "TValue" : "2147"},{"TKey" : "InstanceID", "TValue" : "413"},
{"TKey" : "VersionID", "TValue" : "1008"},{"TKey" : "DataClassID", "TValue" : "1028"},{"TKey" : "ResultTypeBM", "TValue" : "64"},
{"TKey" : "GroupBy", "TValue" : "Time|GL_Project|Account"},{"TKey" : "Measure", "TValue" : "Financials"},{"TKey" : "AssignmentID", "TValue" : "13795"},
{"TKey" : "Filter", "TValue" : "Time=FY2021|Scenario=BUDGET|Entity=52982|Currency=USD|GL_Department=DC60|Account=AC_NA_SA|BusinessProcess=INPUT|GL_Project=All_"},
{"TKey" : "Hierarchy", "TValue" : "Account=1"}]'

--CBN
EXEC [spRun_Procedure_KeyValuePair] @ProcedureName='spPortalGet_DataClass_Data_Prod02', @JSON='[
{"TKey" : "UserID", "TValue" : "2147"},{"TKey" : "InstanceID", "TValue" : "413"},{"TKey" : "VersionID", "TValue" : "1008"},
{"TKey" : "DataClassID", "TValue" : "1028"},{"TKey" : "ResultTypeBM", "TValue" : "68"},
{"TKey" : "GroupBy", "TValue" : "Time.TimeFiscalYear|Account|GL_Project"},{"TKey" : "Measure", "TValue" : "Financials"},
{"TKey" : "AssignmentID", "TValue" : "13792"},
{"TKey" : "Filter", "TValue" : "Time=FY2020|Scenario=BUDGET|Entity=52982|Currency=USD|GL_Department=SC70|Account=AC_NA_SA|BusinessProcess=INPUT"},
{"TKey" : "Hierarchy", "TValue" : "Account=1"}]' 

--SSCycle
EXEC spPortalGet_DataClass_Data_Prod02 @AssignmentID='14516',@DataClassID='5297',@UserID='8033',@VersionID='1035',
@Filter='Scenario=BUDGET|Entity=1001|Currency=USD|GL_Department=All_|GL_Division=All_|GL_Reference=All_|Employee=All_|BusinessProcess=CONSOLIDATED',
@GroupBy='Time.TimeFiscalYear|Account',@InstanceID='486',@Measure='Financials',
@ResultTypeBM='68',
--@ResultTypeBM='64',
@Debug=1

--CCM
EXEC spPortalGet_DataClass_Data_Prod02 @AssignmentID='14542',@DataClassID='5073',@UserID='7707',@VersionID='1021',
@Filter='Scenario=F10X|Entity=All_|Currency=CAD|Account=AC_OPEX|GL_Cost_Center=All_|GL_Product_Category=All_|GL_Project=NONE|GL_Trading_Partner=All_|BusinessProcess=CONSOLIDATED',
@GroupBy='Time.TimeYear|Account',@InstanceID='454',@Measure='Financials',
@ResultTypeBM='68',
--@ResultTypeBM='64',
@Debug=1

EXEC spPortalGet_DataClass_Data_Prod02 @AssignmentID='14994',@DataClassID='5073',@InstanceID='454',@UserID='7702',@VersionID='1021',
@Filter='Scenario=F10X|Entity=All_|Currency=CAD|Account=AC_OPEX|GL_Cost_Center=All_|GL_Product_Category=All_|GL_Project=NONE|GL_Trading_Partner=All_|BusinessProcess=CONSOLIDATED',
@GroupBy='Time.TimeYear|Account',@Measure='Financials',
@ResultTypeBM='68',
--@ResultTypeBM='64',
@DebugBM=1

--SOCAN
EXEC spPortalGet_DataClass_Data_Prod02 @AssignmentID='14721',@DataClassID='5307',@UserID='8060',@VersionID='1025',
@Filter='Time=NONE|Scenario=ACTUAL|Entity=MNTUS|Currency=USD|GL_Branch=16|GL_Dept=01|GL_Detail=All_|Account=AC_EXPENSES|BusinessProcess=CONSOLIDATED|BusinessRule=NONE|TimeDataView=RAWDATA|Version=NONE',
@GroupBy='Time.TimeFiscalYear|GL_Dept|Account',@InstanceID='470',@Measure='Financials',
@ResultTypeBM='68',
--@ResultTypeBM='64',
@Debug=1


--AnnJoo
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalGet_DataClass_Data_Prod02',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "114"},
		{"TKey" : "VersionID",  "TValue": "1004"},
		{"TKey" : "DataClassID",  "TValue": "1004"},
		{"TKey" : "ResultTypeBM",  "TValue": "2"},
		{"TKey" : "GroupBy",  "TValue": "BudgetProduct.ProdFamily|BudgetProduct.ProdType|BudgetProduct.ProdGroup|BudgetProduct.CountryOrigin|Time"},
		{"TKey" : "Measure",  "TValue": "SalesMT|SalesRM|SalesPrice"},
		{"TKey" : "Filter",  "TValue": "Currency = MYR|Entity = AJ01|GL_Branch = 3B|Scenario = Budget|Time = 2018"}]'

--CB
EXEC spRun_Procedure_KeyValuePair 
	@ProcedureName='spPortalGet_DataClass_Data_Prod02',
	@JSON='
		[
		{"TKey" : "UserID", "TValue" : "2026"},
		{"TKey" : "InstanceID", "TValue" : "304"},
		{"TKey" : "VersionID", "TValue" : "1001"},
		{"TKey" : "DataClassID", "TValue" : "1001"},
		{"TKey" : "ResultTypeBM", "TValue" : "2"},
		{"TKey" : "GroupBy", "TValue" : "TimeMonth|GL_Leverantörsgrupp"},
		{"TKey" : "Measure", "TValue" : "SalesAmount_Budget|SalesMarginPercent|SalesMargin_Budget|SalesProvisionsPrice"},
		{"TKey" : "AssignmentID", "TValue" : "1351"},
		{"TKey" : "PropertyList", "TValue" : "Account.Sign|Entity.Currency"},
		{"TKey" : "Filter", "TValue" : "TimeYear=2017|Customer=NONE|Scenario=BUDGET|Entity=01|Currency=SEK|GL_Kostnadställe=NONE|GL_Säljarnr=01_1039|OrderState=20"}]'

--AnnJoo @ResultTypeBM = 3
EXEC [dbo].[spPortalGet_DataClass_Data_Prod02] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @DataClassID = 1004, @ResultTypeBM = 3

--AnnJoo SalesBudget
EXEC [dbo].[spPortalGet_DataClass_Data_Prod02] 
	@UserID = -10,
	@InstanceID = 114,
	@VersionID = 1004,
	@DataClassID = 1004,
	@ResultTypeBM = 15,
	@GroupBy = 'BudgetProduct|Time.TimeYear',
	@Measure = 'SalesMT|SalesRM|SalesPrice',
	@Filter = 'AccountManager = WF04|Currency = MYR|Entity = AJ01|GL_Branch = 99|Scenario = Budget|Time = 2018',
	@PropertyList = 'BudgetProduct.ProdFamily|BudgetProduct.ProdType|BudgetProduct.ProdGroup|BudgetProduct.CountryOrigin',
	@Debug = 1

EXEC [dbo].[spPortalGet_DataClass_Data_Prod02] 
	@UserID = -10,
	@InstanceID = 114,
	@VersionID = 1004,
	@DataClassID = 1004,
	@ResultTypeBM = 15,
	@GroupBy = 'BudgetProduct.ProdFamily|BudgetProduct.ProdType|BudgetProduct.ProdGroup|BudgetProduct.CountryOrigin|Time',
	@Measure = 'SalesMT|SalesRM|SalesPrice',
	@Filter = 'AccountManager = WF34|Currency = MYR|Entity = AJ01|GL_Branch = 3B|Scenario = Budget|Time = 2017',
	@PropertyList = 'Account.Sign|Entity.Currency',
	@Debug = 1

--AnnJoo SpreadingKey
EXEC [dbo].[spPortalGet_DataClass_Data_Prod02] 
	@UserID = -10,
	@InstanceID = 114,
	@VersionID = 1004,
	@MasterDataClassID = 1004,
	@DataClassID = 1005,
	@ResultTypeBM = 1,
	@GroupBy = 'Time',
	@Measure = 'SpreadingKey',
	@Filter = 'SpreadingKey = Spread|AccountManager = WF34|Entity = AJ01|GL_Branch = 3B|Scenario = Budget|Time = 2018',
	@Debug = 1

--Epicor Insights demo Financials
EXEC [dbo].[spPortalGet_DataClass_Data_Prod02] 
	@UserID = -10,
	@InstanceID = -1089,
	@VersionID = -1027,
	@DataClassID = 1252,
	@ResultTypeBM = 7,
	@GroupBy = 'Time',
	@Measure = 'Financials',
	@Filter = 'Scenario = ACTUAL',
	@DimensionProperty = 'Account.Sign|Entity.Currency',
	@Debug = 1

--F1804
EXEC [dbo].[spPortalGet_DataClass_Data_Prod02] 
	@UserID = -10,
	@InstanceID = -1122,
	@VersionID = -1060,
	@DataClassID = 1287,
	@ResultTypeBM = 4,
	@GroupBy = 'Time',
	@Measure = 'Financials',
	@Filter = 'Scenario = ACTUAL',
	@Debug = 1

--CCM
EXEC [dbo].[spPortalGet_DataClass_Data_Prod02] 
	@UserID = -10,
	@InstanceID = 454,
	@VersionID = 1021,
	@DataClassID = 7736,
	@ResultTypeBM = 3,
	@GroupBy = 'Time|GL_Cost_Center',
	@Measure = 'Financials',
	@Filter = 'Scenario=ACTUAL|Time=2018|Account=AC_SALESNET',
	@Hierarchy = 'Account=1',
	@DimensionList = '-2|-3|-63',
	@Debug = 1

EXEC spRun_Procedure_KeyValuePair @ProcedureName='spPortalGet_DataClass_Data_Prod02',
@JSON='[{"TKey" : "UserID", "TValue" : "-10"},{"TKey" : "InstanceID", "TValue" : "-1156"},{"TKey" : "VersionID", "TValue" : "-1094"},
{"TKey" : "DataClassID", "TValue" : "1333"},{"TKey" : "ResultTypeBM", "TValue" : "4"},{"TKey" : "GroupBy", "TValue" : "Time|Account"},
{"TKey" : "Measure", "TValue" : "Financials"},{"TKey" : "AssignmentID", "TValue" : "2937"},{"TKey" : "Debug", "TValue" : "1"},
{"TKey" : "Filter", "TValue" : "BusinessRule=NONE|Version=NONE|Scenario=FORECAST|Entity=EPIC03|Currency=USD|BusinessProcess=INPUT|GL_Department=40|Time=2018"}
]'

EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spPortalGet_DataClass_Data_Prod02',
@JSON='[{"TKey" : "UserID", "TValue" : "-10"},{"TKey" : "InstanceID", "TValue" : "390"},{"TKey" : "VersionID", "TValue" : "1011"},
{"TKey" : "DataClassID", "TValue" : "1296"},{"TKey" : "ResultTypeBM", "TValue" : "2"},{"TKey" : "GroupBy", "TValue" : "Time|Account"},
{"TKey" : "Measure", "TValue" : "Financials"},{"TKey" : "AssignmentID", "TValue" : "2937"},
{"TKey" : "Filter", "TValue" : "BusinessRule=NONE|Version=NONE|Scenario=BUDGET|Entity=EPIC03|Currency=USD|BusinessProcess=INPUT|GL_Department=40|Time=2018"}
]'

EXEC [spRun_Procedure_KeyValuePair] @ProcedureName='spPortalGet_DataClass_Data_Prod02', @JSON='[
{"TKey" : "UserID", "TValue" : "-10"},{"TKey" : "InstanceID", "TValue" : "470"},{"TKey" : "VersionID", "TValue" : "1025"},
{"TKey" : "DataClassID", "TValue" : "5308"},{"TKey" : "ResultTypeBM", "TValue" : "132"},{"TKey" : "GroupBy", "TValue" : "Time.TimeFiscalYear|Currency|Rate"},
{"TKey" : "Measure", "TValue" : "FxRate"},{"TKey" : "AssignmentID", "TValue" : "14757"},{"TKey" : "Debug", "TValue" : "1"},
{"TKey" : "Filter", "TValue" : "Simulation=NONE|BaseCurrency=USD|Time=201505|Scenario=ACTUAL|Rate=All_|Entity=NONE|Currency=All_|GL_Branch=NONE|GL_Dept=NONE|GL_Detail=NONE"}]'

InstanceID	VersionID
-1156	-1094

EXEC spPortalGet_DataClass_Data_Prod02 
	@UserID='9392',
	@InstanceID='523',
	@VersionID='1051',
	@DataClassID = 5522,
	@ResultTypeBM = 2,
	@DimensionList = '5412',
	@Parent_MemberKey = 'GL_Student_ID=All_'

EXEC spPortalGet_DataClass_Data_Prod02 
	@UserID='9392',
	@InstanceID='523',
	@VersionID='1051',
	@DataClassID = 5522,
	@ResultTypeBM = 2,
	@DimensionList = '5412',
	@Parent_MemberKey = 'GL_Student_ID=SUFS_0592'

EXEC [spPortalGet_DataClass_Data_Prod02] @GetVersion = 1
*/

DECLARE
	@ApplicationID int,
	@SQLStatement nvarchar(max),
	@SQLDimList nvarchar(max) = '',
	@SQLMeasureList_4 nvarchar(max) = '',
	@SQLMeasureList_8 nvarchar(max) = '',
	@SQLSelectList_4 nvarchar(max),
	@SQLSelectList_8 nvarchar(max),
	@SQLSelectList_32 nvarchar(max) = '',
	@SQLSelectList_32_LIT nvarchar(max) = '',
	@SQLSelectList_32_S nvarchar(max) = '',
	@SQLSelectList_32_DC nvarchar(max) = '',
	@SQLSelectList_32_DISTINCT nvarchar(max) = '',
	@SQLSelectList_64 nvarchar(max),
	@LeafLevelFilter nvarchar(max),
	@LeafLevelFilter_RA nvarchar(max),
	@LeafLevelFilter_64 nvarchar(max),
	@LevelFilter nvarchar(max),
	@SQLWhereClause nvarchar(max) = '',
	@SQLGroupBy nvarchar(max) = '',
	@SQLGroupBy_32_LIT nvarchar(max) = '',
	@SQLOrderBy nvarchar(max) = '',
	@SQLJoin nvarchar(max) = '',
	@SQLJoin_LIT nvarchar(max) = '',
	@SQLJoin_T nvarchar(max) = '',

	@SQLSelectList_4_LI nvarchar(max) = '',
	@SQLInsertList_4_LI nvarchar(max) = '',
	@SQLJoin_4_LI nvarchar(max) = '',
	@SQLJoin_4_LIT nvarchar(max) = '',

	@SQLJoin_32_DISTINCT nvarchar(max) = '',
	@SQLJoin_32_FILTER nvarchar(max) = '',
	@SQLJoin_32_S_FILTER nvarchar(max) = '',
	@SQLJoin_32_Callisto nvarchar(max) = '',
	@SQLJoin_64_Callisto nvarchar(max) = '',
	@SQLJoin_Callisto nvarchar(max) = '',
	@InputAllowedYN bit,
	@ClosedMonth int,
	@ChangeableYN int = 1,
	@AggregatedYN bit = 0,
	@CharIndex int, 
	@DimFilter nvarchar(2000),
	@FilterLen int,
	@GroupByYN bit,
	@GroupByCharindex int = 0,
	@GroupByCharindexBase int = 0,
	@GroupByStartPos int,
	@GroupByLen int,
	@GroupByDimProperty nvarchar(100),
	@EqualSignPos int,
	@DimensionName nvarchar(100),
	@MeasureName nvarchar(100),
	@StorageTypeBM_Dimension int,
	@StorageTypeBM_DataClass int,
	@DataClassName  nvarchar(100),
	@DataClassTypeID int,
	@InstanceID_String nvarchar(10),
	@DimensionDistinguishing nvarchar(20),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@MonthLock bit,
	@ChangeableYear nchar(1),
	@DimensionID int,
	@Property nvarchar(50),
	@SortOrder int,
	@StartPoint int = 1,
	@LoopStep int = 0,
	@InitialWorkflowStateID int,
	@JSON nvarchar(4000),
	@YearMonthColumn nvarchar(100),
	@FilterLevel nvarchar(2),
	@WorkflowID int,
	@OrganizationHierarchyID int,
	@OrganizationLevelNo int,
	@DatabaseName nvarchar(100),
	@PipePos int,
	@HierarchyNo int,
	@HierarchyName nvarchar(100),
	@CalledYN bit = 1,
	@ReturnVariable int,
	@LineItemTable nvarchar(100),
	@LineItemMeasure nvarchar(100),
	@LineItemBP bigint,
	@TextTable nvarchar(100),
	@TextColumn nvarchar(4000),
	@Inserted_Check int,
	@BusinessProcessYN bit,
	@DimensionTypeID int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2180'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows from selected DataClass.',
			@MandatoryParameter = 'DataClassID'

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'Updated log handling.'
		IF @Version = '2.0.0.2141' SET @Description = 'Handle ChangeableYN dependent on WorkflowState.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-87: Implemented parameter @DimensionList to reduce number of returned dimensions in ResultTypeBM = 2. DB-97: Implement ResultTypeBM 32 = LineItem and 64 = Comment.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-157: Use SP [spGet_WriteAccess] for ResultTypeBM = 8. DB-170: Filterstring changed from 4000 to max.'
		IF @Version = '2.0.2.2149' SET @Description = 'Added parameter @ShowAllMembersYN'
		IF @Version = '2.0.3.2151' SET @Description = 'DB-268: Changed handling for LineItem when using FACT_Financials_Detail. DB-274: Handle LineItem when stored in separate FACT table. DB-284: Handle @ResultTypeBM 128 when no LineItems exists. DB-280: Handle filter All_ for ResultTypeBM=64.'
		IF @Version = '2.0.3.2152' SET @Description = 'Avoid duplicates in temp table #DimensionList'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-364: Show LineItem if numeric measure is missing. Enhanced logic for testing LineItemYN. GROUP BY On LineItem Measure/Comment. DB-371: Always set WorkflowState to NONE in text tables. Added brackets around Dimension names. Created temp tables for ResultTypeBM=128'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-392: Added @BusinessProcessYN variable. DB-402: Modified query in setting @SQLJoin_Callisto under @ResultTypeBM=64.'
		IF @Version = '2.1.0.2157' SET @Description = 'DB-524: Include WorkflowState if existing in #DimensionList for ResultTypeBM=4; Filter ResutlTypeBM=64 if DataClassType = -1.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added optional parameter @OnlyDataClassDimMembersYN. Added optional parameter @ActingAs.'
		IF @Version = '2.1.0.2162' SET @Description = 'Use sub routine [spGet_DataClass_DimensionList] for ResultTypeBM = 1.'
		IF @Version = '2.1.0.2163' SET @Description = 'Parameter @UseCacheYN is added. If set to 0, cache is not used for getting LeafLevelFilter.'
		IF @Version = '2.1.0.2164' SET @Description = 'Parameter @Parent_MemberKey is added.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle DimensionType AutoMultiDim (27). Include WorkflowState if existing in #DimensionList for ResultTypeBM=8. Enhanced debugging; used SP [spSet_wrk_Debug].'
		IF @Version = '2.1.1.2170' SET @Description = 'Brackets around @Dimension names.'
		IF @Version = '2.1.1.2179' SET @Description = 'DB-882: Set correct @DataClassName if LineItem dimension exists.'
		IF @Version = '2.1.1.2180' SET @Description = 'DB-1224: Additional brackets around @Dimension object names.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())
--		SET @StartTime = SYSUTCDATETIME()

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())		

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@DataClassName = DataClassName,
			@DataClassTypeID = DataClassTypeID,
			@StorageTypeBM_DataClass = StorageTypeBM,
			@InstanceID_String = CASE LEN(ABS(@InstanceID)) WHEN 1 THEN '000' WHEN 2 THEN '00' WHEN 3 THEN '0' ELSE '' END + CONVERT(nvarchar(10), ABS(@InstanceID))
		FROM
			DataClass
		WHERE
			InstanceID = @InstanceID AND
			DataClassID = @DataClassID

		SELECT
			@WorkflowID = WorkflowID
		FROM
			Assignment
		WHERE
			AssignmentID = @AssignmentID

		IF @MasterDataClassID IS NOT NULL AND @DataClassTypeID <> -2	--SpreadingKey
			BEGIN
				SET @Message = '@MasterDataClassID can only be set if selected @DataClassID is of type SpreadingKey.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

--		SET @DimensionDistinguishing = CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN '_MemberKey' ELSE '_MemberId' END
		SET @DimensionDistinguishing = CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN '_MemberKey' ELSE '' END

--Temporary hardcoded
--		SET @AssignmentID = NULL

		IF @FilterLevel64 IS NULL
			IF (SELECT COUNT(1) FROM (SELECT DimensionName = [Value] FROM STRING_SPLIT(@GroupBy, '|')) sub WHERE sub.DimensionName LIKE 'Time.%') > 0
				SET @FilterLevel64 = 'LF'
			ELSE
				SET @FilterLevel64 = 'L'

		IF @DebugBM & 2 > 0
			SELECT
				[@DataClassName] = @DataClassName,
				[@DataClassTypeID] = @DataClassTypeID,
				[@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass,
				[@InstanceID_String] = @InstanceID_String,
				[@FilterLevel64] = @FilterLevel64

	SET @Step = 'Create temp table #FilterLevel_MemberKey'
		CREATE TABLE #FilterLevel_MemberKey
			(
			MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #HierarchyList'
		CREATE TABLE #HierarchyList
			(
			DimensionID int,
			DimensionName nvarchar(50) COLLATE DATABASE_DEFAULT,
			HierarchyNo int,
			HierarchyName nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #DimensionList'
		CREATE TABLE #DimensionList
			(
			[DimensionID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DimensionTypeID] int,
			[Property] nvarchar(50) COLLATE DATABASE_DEFAULT, 
			[StorageTypeBM] int,
			[SortOrder] int,
			[SelectYN] bit,
			[GroupByYN] bit,
			[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT, --Filterstring to get data back, used for ResultTypeBM = 4
			[LevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT, --Filterstring to get comments back, used for ResultTypeBM = 32
			[FilterLevel] nvarchar(2) COLLATE DATABASE_DEFAULT, --L will filter on leaf level members, P will filter on existing parent level members (mostly used for SpreadingKey dataclasses)
			[ChangeableYN] INT,
			[ReadSecurityEnabledYN] bit
			)

		INSERT INTO #DimensionList
			(
			[DimensionID],
			[DimensionName],
			[DimensionTypeID],
			[Property], 
			[StorageTypeBM],
			[SortOrder],
			[SelectYN],
			[GroupByYN],
			[Filter],
			[LeafLevelFilter],
			[FilterLevel],
			[ChangeableYN],
			[ReadSecurityEnabledYN]
			)
		SELECT
			[DimensionID] = DCD.DimensionID,
			[DimensionName] = D.DimensionName COLLATE DATABASE_DEFAULT,
			[DimensionTypeID] = D.[DimensionTypeID],
			[Property] = CONVERT(nvarchar(50), 'MemberKey') COLLATE DATABASE_DEFAULT, 
			[StorageTypeBM] = DST.StorageTypeBM,
			[SortOrder] = CASE WHEN DCD.DimensionID = -27 THEN -10 ELSE DCD.SortOrder END,
			[SelectYN] = CASE WHEN @MasterDataClassID IS NOT NULL THEN CASE WHEN DCD.[DimensionID] = -61 THEN 1 ELSE 0 END ELSE 1 END,
			[GroupByYN] = CONVERT(bit, 0),
			[Filter] = CONVERT(nvarchar(4000), '') COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] = CONVERT(nvarchar(4000), '') COLLATE DATABASE_DEFAULT,
			[FilterLevel] = DCD.[FilterLevel],
			[ChangeableYN] = CONVERT(int, 1),
			[ReadSecurityEnabledYN] = ISNULL(DST.[ReadSecurityEnabledYN], 0)
		FROM
			DataClass_Dimension DCD
--
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = DCD.DimensionID AND D.[DimensionTypeID] NOT IN (27,50)
--
			LEFT JOIN Dimension_StorageType DST ON DST.InstanceID = DCD.InstanceID AND DST.VersionID = DCD.VersionID AND DST.DimensionID = DCD.DimensionID
		WHERE
			DCD.InstanceID = @InstanceID AND
			DCD.VersionID = @VersionID AND
			DCD.DataClassID = @DataClassID
		ORDER BY
			DCD.SortOrder

		INSERT INTO #DimensionList
			(
			[DimensionID],
			[DimensionName],
			[Property], 
			[StorageTypeBM],
			[Filter],
			[ReadSecurityEnabledYN],
			[SortOrder]
			)
		SELECT
			[DimensionID] = sub.[DimensionID],
			[DimensionName] = sub.[DimensionName],
			[Property] = 'MemberKey', 
			[StorageTypeBM] = DST.[StorageTypeBM],
			[Filter] = '',
			[ReadSecurityEnabledYN] = 0,
			[SortOrder] = 9999
		FROM
			(
			SELECT DISTINCT
				D.DimensionID,
				D.DimensionName
			FROM
				Dimension D
				INNER JOIN (SELECT DimensionName = [Value] FROM STRING_SPLIT(@GroupBy, '|')) DN ON DN.DimensionName = D.DimensionName
			WHERE
				D.InstanceID IN (0, @InstanceID)
	
			UNION SELECT DISTINCT
				D.DimensionID,
				D.DimensionName
			FROM
				Dimension D
				INNER JOIN (SELECT DimensionName = LTRIM(RTRIM(LEFT([Value], CHARINDEX('=', [Value]) - 1))) FROM STRING_SPLIT(@Filter, '|')) DN ON DN.DimensionName = D.DimensionName
			WHERE
				D.InstanceID IN (0, @InstanceID)
			) sub
			INNER JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = sub.DimensionID
			INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DimensionID = sub.DimensionID AND DCD.DataClassID = @DataClassID
		WHERE
			sub.[DimensionName] = 'LineItem' AND
			NOT EXISTS (SELECT 1 FROM #DimensionList DL WHERE DL.DimensionID = sub.[DimensionID])

		SET @Inserted_Check = @@ROWCOUNT

		IF @Inserted_Check > 0 
			BEGIN
				IF (SELECT COUNT(1) FROM #DimensionList DL WHERE StorageTypeBM & 4 > 0) > 0 OR @StorageTypeBM_DataClass & 4 > 0
					SELECT @CallistoDatabase = DestinationDatabase FROM [Application] WHERE InstanceID = @InstanceID AND VersionID = @VersionID

				SET @SQLStatement = '
					SELECT @internalVariable = COUNT(1)
					FROM
						' + @CallistoDatabase + '.[sys].[tables] T
						INNER JOIN ' + @CallistoDatabase + '.[sys].[columns] C ON c.object_id = T.object_id AND C.[name] = ''LineItem_MemberId''
					WHERE
						T.[name] = ''FACT_' + REPLACE(@DataClassName, '_Detail', '') + '_Detail_default_partition'''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ReturnVariable OUT

				IF @ReturnVariable > 0
					SET @DataClassName = @DataClassName + '_Detail'		

				IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase, [@Inserted_Check] = @Inserted_Check, [@ReturnVariable] = @ReturnVariable, [@DataClassName] = @DataClassName
			END

		IF @DebugBM & 2 > 0
			SELECT
				TempTable = '#DimensionList',
				[DimensionID],
				[DimensionName],
				[DimensionTypeID],
				[StorageTypeBM_Dimension] = [StorageTypeBM],
				[Filter],
				[ReadSecurityEnabledYN],
				[SortOrder]
			FROM
				#DimensionList
			ORDER BY
				SortOrder

		SELECT 
			@BusinessProcessYN =  CASE WHEN COUNT(1) = 0 THEN 0 ELSE 1 END
		FROM
			#DimensionList
		WHERE
			[DimensionID] = -2 
	
	SET @Step = 'CREATE TABLE #AutoMultiDim'
		CREATE TABLE #AutoMultiDim
			(
			[MultiDimensionID] int,
			[DimensionID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #AutoMultiDim
			(
			[MultiDimensionID],
			[DimensionID],
			[DimensionName]
			)
		SELECT
			[MultiDimensionID] = DL.[DimensionID],
			[DimensionID] = P.[DependentDimensionID],
			[DimensionName] = D.[DimensionName]
		FROM
			#DimensionList DL
			INNER JOIN Dimension_Property DP ON DP.InstanceID IN (0, @InstanceID) AND DP.VersionID IN (0, @VersionID) AND DP.DimensionID = DL.DimensionID AND DP.SelectYN <> 0
			INNER JOIN Property P ON P.InstanceID IN (0, @InstanceID) AND P.PropertyID = DP.PropertyID AND P.DataTypeID = 3 AND P.SelectYN <> 0
			INNER JOIN #DimensionList DL1 ON DL1.DimensionID = P.[DependentDimensionID] AND DL1.DimensionTypeID <> 27
			INNER JOIN [Dimension] D ON D.DimensionID = P.[DependentDimensionID]
		WHERE
			DL.[DimensionTypeID] = 27

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#AutoMultiDim', * FROM #AutoMultiDim

	SET @Step = 'CREATE TABLE #ReadAccess'
		CREATE TABLE #ReadAccess
			(
			[DimensionID] int,
			[DimensionName] nvarchar(100),
			[StorageTypeBM] int,
			[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[DataColumn] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SelectYN] bit
			)

		EXEC [spGet_ReadAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, 	@ActingAs = @ActingAs

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ReadAccess', * FROM #ReadAccess
--SELECT Step = 10, StartTime = @StartTime, CurrentTime = SYSUTCDATETIME(), [Time] = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME())

	SET @Step = 'Create temp table, #PipeStringSplit'
		IF OBJECT_ID(N'TempDB.dbo.#PipeStringSplit', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #PipeStringSplit
					(
					[TupleNo] int,
					[PipeObject] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
					[PipeFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Update column Filter in temptable #DimensionList'
		IF LEN(@Filter) > 3
			BEGIN
				TRUNCATE TABLE #PipeStringSplit

				EXEC [spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @Filter, @Debug = 0

				UPDATE DL
				SET
					[Filter] = PSS.[PipeFilter]
				FROM
					#DimensionList DL
					INNER JOIN #PipeStringSplit PSS ON PSS.PipeObject = DL.DimensionName
			END
/*
		IF LEN(@Filter) > 3
			BEGIN
				WHILE CHARINDEX ('|', @Filter) > 0
					BEGIN
						SET @CharIndex = CHARINDEX('|', @Filter)
						SET @DimFilter = LTRIM(RTRIM(LEFT(@Filter, @CharIndex - 1)))
						SELECT
							@EqualSignPos = CHARINDEX('=', @DimFilter),
							@FilterLen = LEN(@DimFilter)
						IF @DebugBM & 2 > 0 
							SELECT
								[CharIndex] = @CharIndex,
								[DimFilter] = @DimFilter,
								[EqualSignPos] = @EqualSignPos,
								[FilterLen] = @FilterLen,
								[DimensionName] = LTRIM(RTRIM(LEFT(@DimFilter, @EqualSignPos - 1))),
								[FilterValue] = LTRIM(RTRIM(RIGHT(@DimFilter, @FilterLen - @EqualSignPos)))
						UPDATE #DimensionList
						SET [Filter] = LTRIM(RTRIM(RIGHT(@DimFilter, @FilterLen - @EqualSignPos)))
						WHERE DimensionName = LTRIM(RTRIM(LEFT(@DimFilter, @EqualSignPos - 1)))
						SET @Filter = SUBSTRING(@Filter, @CharIndex + 1, LEN(@Filter) - @CharIndex)
					END

				SELECT
					@EqualSignPos = CHARINDEX('=', @Filter),
					@FilterLen = LEN(@Filter)

				IF @DebugBM & 2 > 0 
					SELECT
						[CharIndex] = @CharIndex,
						[DimFilter] = @Filter,
						[EqualSignPos] = @EqualSignPos,
						[FilterLen] = @FilterLen,
						[DimensionName] = LTRIM(RTRIM(LEFT(@Filter, @EqualSignPos - 1))),
						[FilterValue] = LTRIM(RTRIM(RIGHT(@Filter, @FilterLen - @EqualSignPos)))

				UPDATE #DimensionList
				SET [Filter] = LTRIM(RTRIM(RIGHT(@Filter, @FilterLen - @EqualSignPos)))
				WHERE DimensionName = LTRIM(RTRIM(LEFT(@Filter, @EqualSignPos - 1)))
			END
*/

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionList', * FROM #DimensionList ORDER BY SortOrder

		IF (SELECT COUNT(1) FROM #DimensionList DL WHERE StorageTypeBM & 4 > 0) > 0 OR @StorageTypeBM_DataClass & 4 > 0
			BEGIN
				SELECT @ApplicationID = ISNULL(@ApplicationID , MAX(ApplicationID)) FROM [Application] WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0
				SELECT @CallistoDatabase = DestinationDatabase, @ETLDatabase = ETLDatabase FROM [Application] WHERE ApplicationID = @ApplicationID
				IF @DebugBM & 2 > 0 SELECT [@ApplicationID] = @ApplicationID, [@CallistoDatabase] = @CallistoDatabase, [@ETLDatabase] = @ETLDatabase
			END
--SELECT Step = 20, StartTime = @StartTime, CurrentTime = SYSUTCDATETIME(), [Time] = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME())
	SET @Step = 'Create temp table #DC_Param'
		CREATE TABLE [dbo].[#DC_Param]
			(
			[ParameterType] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[ParameterName] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Default_MemberID] [bigint],
			[Default_MemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[Default_MemberDescription] [nvarchar](255) COLLATE DATABASE_DEFAULT,
			[Visible] [bit],
			[Changeable] [bit],
			[Parameter] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[DataType] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[FormatString] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Axis] [nvarchar](50),
			[Index] [int] IDENTITY(1,1)
			)

		INSERT INTO [#DC_Param]
			(
			[ParameterType],
			[ParameterName],
			[Default_MemberID],
			[Default_MemberKey],
			[Default_MemberDescription],
			[Visible],
			[Changeable],
			[Parameter],
			[DataType],
			[FormatString],
			[Axis]
			)
		SELECT
			ParameterType = 'Measure',
--			Changed to handle LineItem in separate table 2020-01-03 Jawo
--			ParameterName = M.MeasureName,
--			ParameterName = @DataClassName + '_Value',
			ParameterName = @DataClassName,
			Default_MemberID = NULL,
			Default_MemberKey = NULL,
			Default_MemberDescription = M.MeasureDescription,
			Visible = 1,
			Changeable = 1,
--			Parameter = M.MeasureName,
--			Parameter = @DataClassName + '_Value',
			Parameter = @DataClassName,
			DataType = DT.DataTypePortal,
			FormatString = M.FormatString,
			Axis = 'Column'
		FROM
			Measure M
			INNER JOIN DataType DT ON DT.DataTypeID = M.DataTypeID
		WHERE
			M.DataClassID = @DataClassID AND
			M.SelectYN <> 0 AND
			M.DeletedID IS NULL
		ORDER BY
			M.SortOrder

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#DC_Param', * FROM #DC_Param

--SELECT Step = 30, StartTime = @StartTime, CurrentTime = SYSUTCDATETIME(), [Time] = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME())
	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				EXEC [dbo].[spGet_DataClass_DimensionList] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @OrganizationPositionID=@ActingAs, @AssignmentID=@AssignmentID, @DimensionList=@DimensionList, @ResultTypeBM=3, @JobID=@JobID, @Debug=@DebugSub
			END

		--IF @ResultTypeBM & 1 > 0
		--	BEGIN
		--		SELECT 
		--			@InitialWorkflowStateID = [InitialWorkflowStateID]
		--		FROM
		--			[Assignment] A  
		--			INNER JOIN [Workflow] W ON W.WorkflowID = A.WorkflowID
		--		WHERE
		--			A.InstanceID = @InstanceID AND
		--			A.AssignmentID = @AssignmentID

		--		IF @DebugBM & 2 > 0 SELECT InstanceID = @InstanceID, AssignmentID = @AssignmentID, InitialWorkflowStateID = @InitialWorkflowStateID

		--		SELECT 
		--			ResultTypeBM = 1,
		--			ParameterType = 'Dimension',
		--			DimensionID = DimensionID,
		--			ParameterName = DimensionName,
		--			DefaultMemberID = CASE WHEN DimensionName = 'TimeDataView' THEN 101 ELSE NULL END, --DM.MemberCounter,
		--			DefaultMemberKey = CASE WHEN DimensionName = 'TimeDataView' THEN 'RAWDATA' ELSE NULL END, --DM.MemberKey,
		--			DefaultMemberDescription = CASE WHEN DimensionName = 'TimeDataView' THEN 'The storage format for all data' ELSE NULL END, --DM.MemberDescription, 
		--			Visible = CASE WHEN DimensionName = 'TimeDataView' THEN 0 ELSE 1 END,
		--			Changeable = 0,
		--			Parameter = DimensionName,
		--			DataType = 'string',
		--			FormatString = NULL,
		--			Axis = 'Filter',
		--			[Index] = SortOrder,
		--			[ReadSecurityEnabledYN] = [ReadSecurityEnabledYN]
		--		FROM
		--			#DimensionList 
		--		WHERE
		--			DimensionName <> 'WorkflowState'

		--		UNION
		--		SELECT 
		--			ResultTypeBM = 1,
		--			ParameterType = 'Parameter',
		--			DimensionID = NULL,
		--			ParameterName = 'WorkflowState',
		--			DefaultMemberID = @InitialWorkflowStateID, --DM.MemberCounter,
		--			DefaultMemberKey = CONVERT(nvarchar(10), @InitialWorkflowStateID), --DM.MemberKey,
		--			DefaultMemberDescription = [WorkflowStateName], --DM.MemberDescription,
		--			Visible = 0,
		--			Changeable = 0,
		--			Parameter = 'DimensionName',
		--			DataType = 'string',
		--			FormatString = NULL,
		--			Axis = 'Filter',
		--			[Index] = 0,
		--			[ReadSecurityEnabledYN] = 0
		--		FROM
		--			[WorkflowState]
		--		WHERE
		--			WorkflowStateID = @InitialWorkflowStateID 

		--		UNION 
		--		SELECT
		--			ResultTypeBM = 1,
		--			ParameterType,
		--			DimensionID = NULL,
		--			ParameterName,
		--			Default_MemberID,
		--			Default_MemberKey,
		--			Default_MemberDescription,
		--			Visible,
		--			Changeable,
		--			Parameter,
		--			DataType,
		--			FormatString,
		--			Axis,
		--			[Index],
		--			[ReadSecurityEnabledYN] = 0
		--		FROM
		--			[#DC_Param]
		--		ORDER BY
		--			ParameterType,
		--			Axis,
		--			[Index],
		--			ParameterName

		--		SET @Selected = @Selected + @@ROWCOUNT
		--END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@UserID]=@UserID, [@InstanceID]=@InstanceID, [@VersionID]=@VersionID, [@DataClassID]=@DataClassID, [@PropertyList]=@PropertyList, [@AssignmentID]=@AssignmentID, [@DimensionList]=@DimensionList, [@OnlySecuredDimYN]=@OnlySecuredDimYN, [@ShowAllMembersYN]=@ShowAllMembersYN, [@OnlyDataClassDimMembersYN]=@OnlyDataClassDimMembersYN, [@Parent_MemberKey]=@Parent_MemberKey, [@Selected]=@Selected, [@JobID]=@JobID, [@Debug]=@DebugSub
				EXEC [spGet_DataClass_DimensionMember] @UserID=@UserID,  @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @PropertyList=@PropertyList, @AssignmentID=@AssignmentID, @DimensionList=@DimensionList, @OnlySecuredDimYN=@OnlySecuredDimYN, @ShowAllMembersYN=@ShowAllMembersYN, @OnlyDataClassDimMembersYN=@OnlyDataClassDimMembersYN, @Parent_MemberKey=@Parent_MemberKey, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub
			END
--SELECT Step = 40, StartTime = @StartTime, CurrentTime = SYSUTCDATETIME(), [Time] = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME())

	SET @Step = '@ResultTypeBM & 124'
		IF @ResultTypeBM & 124 > 0
			BEGIN
				CREATE TABLE #LI ([Dummy] int)
				CREATE TABLE #LIT ([Dummy] int)

				--Fill #HierarchyList
				IF LEN(@Hierarchy) > 3
					BEGIN
						TRUNCATE TABLE #PipeStringSplit

						EXEC [spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @Hierarchy, @Debug = 0

						INSERT INTO #HierarchyList
							(
							[DimensionName],
							[HierarchyNo]
							)
						SELECT
							[DimensionName] = PSS.[PipeObject],
							[HierarchyNo] = PSS.[PipeFilter]
						FROM
							#PipeStringSplit PSS

						UPDATE HL
						SET
							DimensionID = D.DimensionID
						FROM
							#HierarchyList HL
							INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = HL.DimensionName

						UPDATE HL
						SET
							HierarchyName = CASE WHEN DH.HierarchyName IS NULL AND HL.HierarchyNo = 0 THEN HL.DimensionName ELSE DH.HierarchyName END
						FROM
							#HierarchyList HL
							LEFT JOIN DimensionHierarchy DH ON DH.InstanceID = @InstanceID AND DH.DimensionID = HL.DimensionID AND DH.HierarchyNo = HL.HierarchyNo

						IF @DebugBM & 2 > 0 SELECT TempTable = '#HierarchyList', * FROM #HierarchyList
					END

				/*
				IF LEN(@Hierarchy) > 3
					BEGIN
						WHILE CHARINDEX ('|', @Hierarchy) > 0
							BEGIN
								SELECT
									@EqualSignPos = CHARINDEX('=', @Hierarchy),
									@PipePos = CHARINDEX('|', @Hierarchy)

								SELECT
									@DimensionName = LTRIM(RTRIM(LEFT(@Hierarchy, @EqualSignPos -1))),
									@HierarchyNo = LTRIM(RTRIM(SUBSTRING(@Hierarchy, @EqualSignPos + 1, @PipePos - @EqualSignPos - 1)))

								SET @Hierarchy = SUBSTRING(@Hierarchy, @PipePos + 1, LEN(@Hierarchy) - @PipePos)

								INSERT INTO #HierarchyList
									(
									DimensionName,
									HierarchyNo
									)
								SELECT
									[DimensionName] = @DimensionName,
									[HierarchyNo] = @HierarchyNo
							END

						SET @EqualSignPos = CHARINDEX('=', @Hierarchy)

						SELECT
							@DimensionName = LTRIM(RTRIM(LEFT(@Hierarchy, @EqualSignPos -1))),
							@HierarchyNo = LTRIM(RTRIM(SUBSTRING(@Hierarchy, @EqualSignPos + 1, LEN(@Hierarchy) - @EqualSignPos)))

						INSERT INTO #HierarchyList
							(
							DimensionName,
							HierarchyNo
							)
						SELECT
							[DimensionName] = @DimensionName,
							[HierarchyNo] = @HierarchyNo

						UPDATE HL
						SET
							DimensionID = D.DimensionID
						FROM
							#HierarchyList HL
							INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = HL.DimensionName

						UPDATE HL
						SET
							HierarchyName = DH.HierarchyName
						FROM
							#HierarchyList HL
							INNER JOIN DimensionHierarchy DH ON DH.InstanceID = @InstanceID AND DH.DimensionID = HL.DimensionID AND DH.HierarchyNo = HL.HierarchyNo

						IF @DebugBM & 2 > 0 SELECT TempTable = '#HierarchyList', * FROM #HierarchyList
					END
					*/
				SELECT
					[DimensionID] = DL.[DimensionID],
					[DimensionName] = DL.[DimensionName],
					[DimensionTypeID] = DL.[DimensionTypeID],
					[HierarchyNo] = ISNULL(CASE WHEN HL.[HierarchyName] IS NULL THEN NULL ELSE HL.[HierarchyNo] END, 0),
					[HierarchyName] = ISNULL(HL.[HierarchyName], DL.[DimensionName]),
					[StorageTypeBM_Dimension] = DL.[StorageTypeBM],
					DL.[Filter],
					[FilterLevel],
					[LeafLevelFilter] = DL.LeafLevelFilter,
					[LeafLevelFilter_RA] = RA.LeafLevelFilter,
					[GroupByYN] = DL.GroupByYN,
					[SortOrder]
				INTO
					#DimensionList_Cursor
				FROM
					#DimensionList DL
					LEFT JOIN #ReadAccess RA ON RA.DimensionID = DL.DimensionID
					LEFT JOIN #HierarchyList HL ON HL.DimensionID = DL.DimensionID
				ORDER BY
					DL.[FilterLevel],
					DL.[SortOrder]

				IF @DebugBM & 2 > 0	
					SELECT
						TempTable = '#DimensionList_Cursor',
						*
					FROM
						#DimensionList_Cursor
					ORDER BY
						[FilterLevel],
						[SortOrder]

				IF CURSOR_STATUS('global','DimensionList_Cursor') >= -1 DEALLOCATE DimensionList_Cursor
				DECLARE DimensionList_Cursor CURSOR FOR

					SELECT
						[DimensionID],
						[DimensionName],
						[DimensionTypeID],
						[HierarchyNo],
						[HierarchyName],
						[StorageTypeBM_Dimension],
						[Filter],
						[FilterLevel],
						[LeafLevelFilter_RA],
						[SortOrder]
					FROM
						#DimensionList_Cursor
					ORDER BY
						[FilterLevel],
						[SortOrder]

					OPEN DimensionList_Cursor
					FETCH NEXT FROM DimensionList_Cursor INTO @DimensionID, @DimensionName, @DimensionTypeID, @HierarchyNo, @HierarchyName, @StorageTypeBM_Dimension, @Filter, @FilterLevel, @LeafLevelFilter_RA, @SortOrder

					WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @GroupByYN = 0
							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName,  [@HierarchyNo] = @HierarchyNo, [@HierarchyName] = @HierarchyName, [@StorageTypeBM_Dimension] = @StorageTypeBM_Dimension, [@Filter] = @Filter, [@FilterLevel] = @FilterLevel, [@SortOrder] = @SortOrder

							IF @FilterLevel = 'P'
								BEGIN
									--Has to be dynamic code filtered by filter above

									TRUNCATE TABLE [#FilterLevel_MemberKey]
									
									SET @SQLStatement = '
										INSERT INTO #FilterLevel_MemberKey
											(
											MemberKey
											)
										SELECT DISTINCT
											MemberKey = ' + @DimensionName + '_MemberKey
										FROM
											' + @ETLDatabase + '.[dbo].[pcDC_' + @InstanceID_String + '_' + @DataClassName + ']'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								
									IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterLevel_MemberKey', * FROM [#FilterLevel_MemberKey]
								END

							IF CHARINDEX (@DimensionName, @GroupBy) > 0
								BEGIN
									SET @StartPoint = CHARINDEX (@DimensionName, @GroupBy) + LEN(@DimensionName)
									IF @DebugBM & 2 > 0 SELECT [GroupBy] = @GroupBy, [DimensionName] = @DimensionName, [GroupByLen] = LEN(@GroupBy), [DimStart] = CHARINDEX (@DimensionName, @GroupBy), [DimLen] = LEN(@DimensionName),  StartPoint = @StartPoint
									IF @StartPoint = LEN(@GroupBy) + 1 OR SUBSTRING(@GroupBy, @StartPoint, 1) = '|'
										BEGIN
											SET @GroupByYN = 1
											UPDATE #DimensionList SET [GroupByYN] = 1 WHERE DimensionName = @DimensionName

											IF @StorageTypeBM_DataClass & 2 > 0
												BEGIN
													IF @DebugBM & 2 > 0 SELECT SQLDimList = @DimensionName + '_MemberKey = DC.' + @DimensionName + @DimensionDistinguishing, SQLGroupBy = 'DC.' + @DimensionName + @DimensionDistinguishing
													SET @SQLDimList = @SQLDimList + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @DimensionName + '_MemberKey = DC.' + @DimensionName + @DimensionDistinguishing + ','
													SET @SQLGroupBy = @SQLGroupBy + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'DC.' + @DimensionName + @DimensionDistinguishing + ','
												END
											ELSE IF @StorageTypeBM_DataClass & 4 > 0
												BEGIN
													IF @DebugBM & 2 > 0 SELECT SQLDimList = @DimensionName + '_MemberKey = ' + @DimensionName + '.Label', SQLGroupBy = @DimensionName + '.[Label]'
													SET @SQLDimList = @SQLDimList + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @DimensionName + '_MemberKey = [' + @DimensionName + '].[Label],'
													SET @SQLSelectList_4_LI = @SQLSelectList_4_LI + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @DimensionName + '_MemberKey = [' + @DimensionName + '].[Label],'
													SET @SQLInsertList_4_LI = @SQLInsertList_4_LI + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @DimensionName + '_MemberKey,'
													SET @SQLJoin_4_LI = @SQLJoin_4_LI + CASE WHEN @DimensionID = -63 THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LI.' + @DimensionName + '_MemberKey = [' + @DimensionName + '].[Label] AND' END
													SET @SQLJoin_4_LIT = @SQLJoin_4_LIT + CASE WHEN @DimensionID = -63 THEN '' ELSE + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LIT.' + @DimensionName + '_MemberKey = [' + @DimensionName + '].[Label] AND' END

													SET @SQLStatement = 'ALTER TABLE #LI ADD [' + @DimensionName + '_MemberKey]  nvarchar(100) COLLATE DATABASE_DEFAULT' EXEC (@SQLStatement)
													SET @SQLStatement = 'ALTER TABLE #LIT ADD [' + @DimensionName + '_MemberKey]  nvarchar(100) COLLATE DATABASE_DEFAULT' EXEC (@SQLStatement)

													SET @SQLGroupBy = @SQLGroupBy + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '].[Label],'
												END
										END
								END

							IF CHARINDEX (@DimensionName + '.', @GroupBy) > 0 --AND @PropertyResultTypeBM & 4 > 0
								BEGIN
									SELECT @StartPoint = 1, @LoopStep = 0
									WHILE CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) > 0
										BEGIN
											SET @LoopStep = @LoopStep + 1
											SET @Property = SUBSTRING(@GroupBy, CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) + LEN(@DimensionName) + 1, CASE WHEN CHARINDEX ('|', @GroupBy, CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) + LEN(@DimensionName) + 1) = 0 THEN LEN(@GroupBy) + 1 ELSE CHARINDEX ('|', @GroupBy, CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) + LEN(@DimensionName) + 1) END - (CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) + LEN(@DimensionName) + 1))
											
											SET @GroupByYN = 1

											IF @DebugBM & 2 > 0
												SELECT
													String = @GroupBy,
													StartPoint = CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) + LEN(@DimensionName) + 1,
													PropertyLen = CASE WHEN CHARINDEX ('|', @GroupBy, CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) + LEN(@DimensionName) + 1) = 0 THEN LEN(@GroupBy) + 1 ELSE CHARINDEX ('|', @GroupBy, CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) + LEN(@DimensionName) + 1) END - (CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) + LEN(@DimensionName) + 1),
													Property = @Property
					
											INSERT INTO #DimensionList
												(
												[DimensionID],
												[DimensionName],
												[Property],
												[StorageTypeBM],
												[SortOrder],
												[SelectYN],
												[GroupByYN],
												[FilterLevel],
												[ChangeableYN]
												)
											SELECT
												[DimensionID] = @DimensionID,
												[DimensionName] = @DimensionName,
												[Property] = @Property, 
												[StorageTypeBM] = @StorageTypeBM_Dimension,
												[SortOrder] = @SortOrder + @LoopStep,
												[SelectYN] = CASE WHEN @MasterDataClassID IS NOT NULL THEN CASE WHEN @DimensionID = -61 THEN 1 ELSE 0 END ELSE 1 END,
												[GroupByYN] = @GroupByYN,
												[FilterLevel] = @FilterLevel,
												[ChangeableYN] = 1

											SET @SQLDimList = @SQLDimList + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '].[' + @Property + '],'
											--SET @SQLSelectList_4_LI = @SQLSelectList_4_LI + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @DimensionName + '.' + @Property + ','
											--SET @SQLJoin_4_LI = @SQLJoin_4_LI + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @DimensionName + '.' + @Property + ','
											SET @SQLGroupBy = @SQLGroupBy + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '].[' + @Property + '],'
											IF @DebugBM & 2 > 0 SELECT DimensionName = @DimensionName, LoopStep = @LoopStep, DimensionDistinguishing = @DimensionDistinguishing
											IF @LoopStep = 1 SET @SQLJoin = @SQLJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'LEFT JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' ' + @DimensionName + ' ON ' + @DimensionName + '.Label = DC.' + @DimensionName + @DimensionDistinguishing

											SET @StartPoint = CHARINDEX (@DimensionName + '.', @GroupBy, @StartPoint) + LEN(@DimensionName) + 1
										END
								END

							IF LEN(@Filter) > 0 AND @Filter <> 'All_'
								BEGIN
									IF @DimensionName <> 'TimeDataView'
										BEGIN
											EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @CallistoDatabase, @DimensionName = @DimensionName, @Filter = @Filter, @StorageTypeBM = @StorageTypeBM_Dimension, @HierarchyName = @HierarchyName, @FilterLevel = @FilterLevel, @UseCacheYN = @UseCacheYN, @LeafLevelFilter = @LeafLevelFilter OUT, @Debug = @DebugSub	
											EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @CallistoDatabase, @DimensionName = @DimensionName, @Filter = @Filter, @StorageTypeBM = @StorageTypeBM_Dimension, @HierarchyName = @HierarchyName, @FilterLevel = 'LF', @UseCacheYN = @UseCacheYN, @LeafLevelFilter = @LevelFilter OUT, @Debug = @DebugSub	
										END
									ELSE
										SET @LeafLevelFilter = ''
									UPDATE #DimensionList SET [LeafLevelFilter] = @LeafLevelFilter WHERE DimensionName = @DimensionName AND Property = 'MemberKey'
									IF LEN(@LeafLevelFilter) > 0 SET @SQLWhereClause = @SQLWhereClause + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @DimensionName + @DimensionDistinguishing + ' IN (' + @LeafLevelFilter + ') AND'
								END
							ELSE
								SET @LeafLevelFilter = ''

							IF @DebugBM & 2 > 0 SELECT [@DimensionTypeID] = @DimensionTypeID, [@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass, [@DimensionName] = @DimensionName, [@LeafLevelFilter] = @LeafLevelFilter, [@Len_LeafLevelFilter] = LEN(@LeafLevelFilter), [@GroupByYN] = @GroupByYN

							IF @StorageTypeBM_DataClass & 4 > 0 AND @DimensionName NOT IN ('TimeDataView', 'WorkflowState') AND (LEN(@LeafLevelFilter) > 0 OR LEN(@LeafLevelFilter_RA) > 0 OR @GroupByYN <> 0)
								IF @DimensionTypeID = 27
									BEGIN
										SET @SQLJoin_Callisto = @SQLJoin_Callisto + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' [' + @DimensionName + '] ON ' + CASE WHEN LEN(@LeafLevelFilter) > 0 THEN '[' + @DimensionName + '].[Label] IN (' + @LeafLevelFilter + ')' ELSE '' END + CASE WHEN LEN(@LeafLevelFilter_RA) > 0 THEN ' AND ' + @DimensionName + '.Label IN (' + @LeafLevelFilter_RA + ')' ELSE '' END
										SELECT 
											@SQLJoin_Callisto = @SQLJoin_Callisto + CASE WHEN RIGHT(@SQLJoin_Callisto, 3) = 'ON ' THEN '' ELSE ' AND ' END + '[' + @DimensionName + '].[' + AMD.[DimensionName] + '_MemberId] = DC.[' + AMD.[DimensionName] + '_MemberId]'
										FROM
											#AutoMultiDim AMD
										WHERE
											AMD.[MultiDimensionID] = @DimensionID
										ORDER BY
											AMD.[DimensionID]
									END
								ELSE
									BEGIN
										SET @SQLJoin_Callisto = @SQLJoin_Callisto + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' [' + @DimensionName + '] ON [' + @DimensionName + '].MemberId = DC.[' + @DimensionName + '_MemberId]' + CASE WHEN LEN(@LeafLevelFilter) > 0 THEN ' AND [' + @DimensionName + '].[Label] IN (' + @LeafLevelFilter + ')' ELSE '' END + CASE WHEN LEN(@LeafLevelFilter_RA) > 0 THEN ' AND ' + @DimensionName + '.Label IN (' + @LeafLevelFilter_RA + ')' ELSE '' END
									
										IF @FilterLevel64 = 'L'
											SET @LevelFilter = @LeafLevelFilter
										ELSE IF @FilterLevel64 = 'LF' AND @DimensionID IN (-7)
											SET @LevelFilter = @LevelFilter
										ELSE -- 'LLF'
											SET @LevelFilter = CASE WHEN @GroupByYN <> 0 AND @LeafLevelFilter <> @LevelFilter AND LEN(@LeafLevelFilter) > 0 AND LEN(@LevelFilter) > 0 THEN @LevelFilter + ',' + @LeafLevelFilter ELSE @LevelFilter END

										SET @SQLJoin_64_Callisto = @SQLJoin_64_Callisto + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' [' + @DimensionName + '] ON [' + @DimensionName + '].MemberId = DC.[' + @DimensionName + '_MemberId]' + CASE WHEN LEN(@LevelFilter) > 0 AND @Filter <> 'All_' THEN ' AND [' + @DimensionName + '].[Label] IN (' + @LevelFilter + ')' ELSE '' END + CASE WHEN LEN(@LeafLevelFilter_RA) > 0 THEN ' AND ' + @DimensionName + '.Label IN (' + @LeafLevelFilter_RA + ')' ELSE '' END
										IF @DimensionID NOT IN (-2) SET @SQLJoin_32_FILTER = @SQLJoin_32_FILTER + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' [' + @DimensionName + '] ON [' + @DimensionName + '].MemberId = DC.[' + @DimensionName + '_MemberId]' + CASE WHEN LEN(@LeafLevelFilter) > 0 THEN ' AND [' + @DimensionName + '].[Label] IN (' + @LeafLevelFilter + ')' ELSE '' END + CASE WHEN LEN(@LeafLevelFilter_RA) > 0 THEN ' AND ' + @DimensionName + '.Label IN (' + @LeafLevelFilter_RA + ')' ELSE '' END
									END

							FETCH NEXT FROM DimensionList_Cursor INTO @DimensionID, @DimensionName, @DimensionTypeID, @HierarchyNo, @HierarchyName, @StorageTypeBM_Dimension, @Filter, @FilterLevel, @LeafLevelFilter_RA, @SortOrder
						END

				CLOSE DimensionList_Cursor
				DEALLOCATE DimensionList_Cursor		

				IF @DebugBM & 2 > 0 SELECT SQLGroupBy = @SQLGroupBy, SQLWhereClause = @SQLWhereClause
				
				IF LEN(@SQLGroupBy) > 1 SET @SQLGroupBy = SUBSTRING(@SQLGroupBy, 1, LEN(@SQLGroupBy) - 1)
				IF LEN(@SQLWhereClause) > 4 SET @SQLWhereClause = SUBSTRING(@SQLWhereClause, 1, LEN(@SQLWhereClause) - 4)

				IF @AggregatedYN = 0 SET @AggregatedYN = CASE WHEN CHARINDEX (',', @SQLWhereClause) = 0 THEN 0 ELSE 1 END
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionList', * FROM #DimensionList ORDER BY SortOrder
		IF @DebugBM & 2 > 0 PRINT @SQLJoin
--SELECT Step = 50, StartTime = @StartTime, CurrentTime = SYSUTCDATETIME(), [Time] = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME())

	SET @Step = '@ResultTypeBM & 100'
		IF @ResultTypeBM & 100 > 0 --ResultSet/LineItem/Comment
			BEGIN
				SET @SQLStatement = '
					SELECT @internalVariable = COUNT(1)
					FROM
						' + @CallistoDatabase + '.[sys].[tables] T
						INNER JOIN ' + @CallistoDatabase + '.[sys].[columns] C ON c.object_id = T.object_id AND C.[name] = ''LineItem_MemberId''
					WHERE
						T.[name] = ''FACT_' + REPLACE(@DataClassName, '_Detail', '') + '_default_partition'''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement

				EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ReturnVariable OUT

				IF @ReturnVariable > 0
					SELECT
						@LineItemTable = 'FACT_' + REPLACE(@DataClassName, '_Detail', '') + '_default_partition',
						@LineItemMeasure = REPLACE(@DataClassName, '_Detail', '') + '_Value',
						@TextTable = 'FACT_' + REPLACE(@DataClassName, '_Detail', '') + '_Text',
						@TextColumn = REPLACE(@DataClassName, '_Detail', '') + '_Text',
						@LineItemBP = 118
				ELSE
					BEGIN
						SET @SQLStatement = '
							SELECT @internalVariable = COUNT(1)
							FROM
								' + @CallistoDatabase + '.[sys].[tables] T
								INNER JOIN ' + @CallistoDatabase + '.[sys].[columns] C ON c.object_id = T.object_id AND C.[name] = ''LineItem_MemberId''
							WHERE
								T.[name] = ''FACT_' + REPLACE(@DataClassName, '_Detail', '') + '_Detail_default_partition'''

						IF @DebugBM & 2 > 0 PRINT @SQLStatement

						EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ReturnVariable OUT

						IF @ReturnVariable > 0
							SELECT
								@LineItemTable = 'FACT_' + REPLACE(@DataClassName, '_Detail', '') + '_Detail_default_partition',
								@LineItemMeasure = REPLACE(@DataClassName, '_Detail', '') + '_Detail_Value',
								@TextTable = 'FACT_' + REPLACE(@DataClassName, '_Detail', '') + '_Detail_Text',
								@TextColumn = REPLACE(@DataClassName, '_Detail', '') + '_Detail_Text',
								@LineItemBP = NULL
					END

				IF @DebugBM & 1 > 0 SELECT [@LineItemTable] = @LineItemTable, [@LineItemMeasure] = @LineItemMeasure, [@TextTable] = @TextTable, [@TextColumn] = @TextColumn, [@LineItemBP] = @LineItemBP
			END

	SET @Step = '@ResultTypeBM & 4'
		IF @ResultTypeBM & 4 > 0 --Data
			BEGIN
				IF @StorageTypeBM_DataClass & 2 > 0
					BEGIN
						DECLARE MeasureList_4_Cursor CURSOR FOR

							SELECT 
								MeasureName = [ParameterName]
							FROM
								#DC_Param
							WHERE
								ParameterType = 'Measure'
							ORDER BY
								[Index]

							OPEN MeasureList_4_Cursor
							FETCH NEXT FROM MeasureList_4_Cursor INTO @MeasureName

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @DebugBM & 2 > 0 SELECT [@MeasureName] = @MeasureName

--									SET @SQLMeasureList_4 = @SQLMeasureList_4 + CASE WHEN CHARINDEX (@MeasureName, @Measure) > 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @MeasureName + '_Value = SUM(DC.' + @MeasureName + '_Value),' ELSE '' END
									SET @SQLMeasureList_4 = @SQLMeasureList_4 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @DataClassName + '_Value = SUM(DC.' + @MeasureName + '_Value),'

									FETCH NEXT FROM MeasureList_4_Cursor INTO @MeasureName
								END

						CLOSE MeasureList_4_Cursor
						DEALLOCATE MeasureList_4_Cursor		

						SET @SQLSelectList_4 = @SQLDimList + @SQLMeasureList_4
						SET @SQLSelectList_4 = SUBSTRING(@SQLSelectList_4, 1, LEN(@SQLSelectList_4) - 1)

						SET @SQLStatement = '
	SELECT
		ResultTypeBM = 4,' + @SQLSelectList_4 + CASE WHEN @MasterDataClassID IS NULL THEN ',
		WorkflowStateID = MAX(DC.WorkflowStateID),
		Workflow_UpdatedBy_UserID = MAX(DC.Workflow_UpdatedBy_UserID)' ELSE '' END + '
	FROM
		' + @ETLDatabase + '.[dbo].[pcDC_' + @InstanceID_String + '_' + @DataClassName + '] DC' + @SQLJoin + ' 
	WHERE
		ResultTypeBM & 4 > 0 AND' + @SQLWhereClause + '
	GROUP BY' + @SQLGroupBy + '
	ORDER BY' + @SQLGroupBy
					END
				ELSE IF @StorageTypeBM_DataClass & 4 > 0
					BEGIN
						DECLARE MeasureList_4_Cursor CURSOR FOR

							SELECT 
								MeasureName = REPLACE([ParameterName], '_Value', '') + '_Value'
							FROM
								#DC_Param
							WHERE
								ParameterType = 'Measure'
							ORDER BY
								[Index]

							OPEN MeasureList_4_Cursor
							FETCH NEXT FROM MeasureList_4_Cursor INTO @MeasureName

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @DebugBM & 2 > 0 SELECT [@MeasureName] = @MeasureName

--									SET @SQLMeasureList_4 = @SQLMeasureList_4 + CASE WHEN CHARINDEX (@MeasureName, @Measure) > 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @MeasureName + '_Value = SUM(DC.' + @MeasureName + '_Value),' ELSE '' END
									SET @SQLMeasureList_4 = @SQLMeasureList_4 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + REPLACE(@MeasureName, '_Detail', '') + ' = SUM(DC.' + @MeasureName + '),'

									FETCH NEXT FROM MeasureList_4_Cursor INTO @MeasureName
								END

						CLOSE MeasureList_4_Cursor
						DEALLOCATE MeasureList_4_Cursor		

						SET @SQLSelectList_4 = @SQLDimList + @SQLMeasureList_4
						SET @SQLSelectList_4 = SUBSTRING(@SQLSelectList_4, 1, LEN(@SQLSelectList_4) - 1)

						IF @ResultTypeBM & 128 > 0 AND @BusinessProcessYN <> 0
							BEGIN
								SELECT
									@SQLSelectList_4_LI = LEFT(@SQLSelectList_4_LI, LEN(@SQLSelectList_4_LI) - 1),
									@SQLInsertList_4_LI = LEFT(@SQLInsertList_4_LI, LEN(@SQLInsertList_4_LI) - 1),
									@SQLJoin_4_LI = LEFT(@SQLJoin_4_LI, LEN(@SQLJoin_4_LI) - 4),
									@SQLJoin_4_LIT = LEFT(@SQLJoin_4_LIT, LEN(@SQLJoin_4_LIT) - 4)


									SET @SQLStatement = '
			INSERT INTO #LI
				(
				Dummy, ' + @SQLInsertList_4_LI + '
				)
			SELECT DISTINCT
				Dummy = 1, ' + @SQLSelectList_4_LI + '
			FROM
				' + @CallistoDatabase + '.[dbo].[' + @LineItemTable + '] DC' + @SQLJoin_32_FILTER + ' 
			' + CASE WHEN @LineItemBP IS NULL THEN '' ELSE '
			WHERE
				DC.' + @LineItemMeasure + ' <> 0 AND
				DC.BusinessProcess_MemberId = ' + CONVERT(nvarchar(20), @LineItemBP) END

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SET @SQLStatement = '
			INSERT INTO #LIT
				(
				Dummy, ' + @SQLInsertList_4_LI + '
				)
			SELECT DISTINCT
				Dummy = 1, ' + @SQLSelectList_4_LI + '
			FROM
				' + @CallistoDatabase + '.[dbo].[' + @TextTable + '] DC' + @SQLJoin_32_FILTER + ' 
			' + CASE WHEN @LineItemBP IS NULL THEN '' ELSE '
			WHERE
				LEN(DC.' + @TextColumn + ') > 0 AND
				DC.BusinessProcess_MemberId = ' + CONVERT(nvarchar(20), @LineItemBP) END

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)


									SET @SQLStatement = '
	SELECT
		ResultTypeBM = 4,' + @SQLSelectList_4 + CASE WHEN @MasterDataClassID IS NULL THEN ',
		--WorkflowStateID = MAX(CONVERT(int, DC.WorkFlowState_MemberId)),
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN 'WorkflowStateID = MAX(CONVERT(int, DC.WorkFlowState_MemberId)),' ELSE '' END + '
		Workflow_UpdatedBy_UserID = 0' ELSE '' END + ',
		LineItemYN = ' + CASE WHEN @LineItemTable IS NULL THEN '0' ELSE 'MAX(CASE WHEN LI.Dummy IS NULL AND LIT.Dummy IS NULL THEN 0 ELSE 1 END)' END + '
	FROM
		' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] DC' + @SQLJoin_Callisto + ' 
		' + CASE WHEN @LineItemTable IS NULL THEN '' ELSE 'LEFT JOIN #LI LI ON ' + @SQLJoin_4_LI + '
			LEFT JOIN #LIT LIT ON ' + @SQLJoin_4_LIT END + '
	WHERE
		DC.BusinessProcess_MemberId <> 118
	GROUP BY' + @SQLGroupBy + '
	ORDER BY' + @SQLGroupBy

							END
						ELSE
							BEGIN

								SET @SQLStatement = '
	SELECT
		ResultTypeBM = 4,' + @SQLSelectList_4 + CASE WHEN @MasterDataClassID IS NULL THEN ',
		--WorkflowStateID = MAX(CONVERT(int, DC.WorkFlowState_MemberId)),
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN 'WorkflowStateID = MAX(CONVERT(int, DC.WorkFlowState_MemberId)),' ELSE '' END + '
		Workflow_UpdatedBy_UserID = 0' ELSE '' END + '
	FROM
		' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] DC' + @SQLJoin_Callisto + ' 
	' + CASE WHEN @BusinessProcessYN <> 0 THEN 'WHERE DC.BusinessProcess_MemberId <> 118' ELSE '' END + '	
	GROUP BY' + @SQLGroupBy + '
	ORDER BY' + @SQLGroupBy

							END

--					END
			END

				IF @DebugBM & 1 > 0 AND LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Return ResultTypeBM = 4'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Return ResultTypeBM = 4', 
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement

				EXEC (@SQLStatement)
				SET @Selected = @Selected + @@ROWCOUNT
			END
--SELECT Step = 60, StartTime = @StartTime, CurrentTime = SYSUTCDATETIME(), [Time] = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME())
	SET @Step = '@ResultTypeBM & 8'
		IF @ResultTypeBM & 8 > 0 --Changeable
			BEGIN
				CREATE TABLE #WorkflowState
					(
					[WorkflowStateID] int,
					[Scenario_MemberKey] nvarchar(50),
					[Scenario_MemberId] bigint,
					[TimeFrom] int,
					[TimeTo] int
					)

				EXEC [spGet_WriteAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @AssignmentID = @AssignmentID, @DataClassID = @DataClassID

				SET @SQLStatement = '
					UPDATE WFS
					SET
						[Scenario_MemberId] = MemberId
					FROM
						#WorkflowState WFS
						INNER JOIN ' + @CallistoDatabase + '..S_DS_Scenario S ON S.Label = WFS.Scenario_MemberKey'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @DimensionDistinguishing = CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN '_MemberKey' ELSE '_MemberId' END

				IF (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -7) = 1
					SET @YearMonthColumn = 'DC.Time' + @DimensionDistinguishing 
				ELSE IF (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID IN (-40, -11)) = 2
					SET @YearMonthColumn = 'DC.TimeYear' + @DimensionDistinguishing + ' * 100 + DC.TimeMonth' + @DimensionDistinguishing 

				DECLARE MeasureList_8_Cursor CURSOR FOR

					SELECT 
						MeasureName = REPLACE([ParameterName], '_Value', '') + '_Value'
					FROM
						#DC_Param
					WHERE
						ParameterType = 'Measure'
					ORDER BY
						[Index]

					OPEN MeasureList_8_Cursor
					FETCH NEXT FROM MeasureList_8_Cursor INTO @MeasureName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT MeasureName = @MeasureName

--							SET @SQLMeasureList_8 = @SQLMeasureList_8 + CASE WHEN CHARINDEX (@MeasureName, @Measure) > 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @MeasureName + '_Value = CASE WHEN MAX(WS.WorkflowStateID) IS NULL THEN 0 ELSE 1 END,' ELSE '' END
							SET @SQLMeasureList_8 = @SQLMeasureList_8 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + @MeasureName + ' = CASE WHEN MAX(WS.WorkflowStateID) IS NULL THEN 0 ELSE 1 END,'

							FETCH NEXT FROM MeasureList_8_Cursor INTO @MeasureName
						END

				CLOSE MeasureList_8_Cursor
				DEALLOCATE MeasureList_8_Cursor		

				SET @DimensionDistinguishing = CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN '_MemberKey' ELSE '' END


				SET @SQLSelectList_8 = @SQLDimList + @SQLMeasureList_8

				IF @StorageTypeBM_DataClass & 2 > 0
					BEGIN
						SET @SQLStatement = '
	SELECT
		ResultTypeBM = 8,' + @SQLSelectList_8 + '
		DC.WorkFlowStateID,
		Workflow_UpdatedBy_UserID = MAX(DC.Workflow_UpdatedBy_UserID)
	FROM
		' + @ETLDatabase + '.[dbo].[pcDC_' + @InstanceID_String + '_' + @DataClassName + '] DC
		LEFT JOIN Scenario S ON S.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND S.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND S.MemberKey = DC.Scenario_MemberKey' + @SQLJoin + ' 
		LEFT JOIN #WorkflowState WS ON WS.WorkflowStateID = DC.WorkFlowStateID AND DC.Time_MemberKey BETWEEN CONVERT(nvarchar(15), WS.TimeFrom) AND CONVERT(nvarchar(15), WS.TimeTo) AND WS.Scenario_MemberKey = DC.Scenario_MemberKey
	WHERE
		ResultTypeBM & 12 > 0 AND' + @SQLWhereClause + '
	GROUP BY' + @SQLGroupBy +  ',
		DC.WorkFlowStateID
	ORDER BY' + @SQLGroupBy + ',
		DC.WorkFlowStateID'
					END
				ELSE IF @StorageTypeBM_DataClass & 4 > 0
					BEGIN
						SET @SQLStatement = '
	SELECT
		ResultTypeBM = 8,' + @SQLSelectList_8 + '
		--WorkFlowStateID = CONVERT(int, DC.WorkFlowState_MemberId),
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN 'WorkflowStateID = CONVERT(int, DC.WorkFlowState_MemberId),' ELSE '' END + '
		Workflow_UpdatedBy_UserID = 0
	FROM
		' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] DC
		LEFT JOIN Scenario S ON S.ScenarioID = DC.Scenario_MemberId' + @SQLJoin_Callisto + ' 
		--LEFT JOIN #WorkflowState WS ON WS.WorkflowStateID = CONVERT(int, DC.WorkFlowState_MemberId) AND DC.Time_MemberID BETWEEN WS.TimeFrom AND WS.TimeTo AND WS.Scenario_MemberId = DC.Scenario_MemberId
		LEFT JOIN #WorkflowState WS ON WS.WorkflowStateID = ' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN 'CONVERT(int, DC.WorkFlowState_MemberId)' ELSE 'NULL' END + ' AND DC.Time_MemberID BETWEEN WS.TimeFrom AND WS.TimeTo AND WS.Scenario_MemberId = DC.Scenario_MemberId
	GROUP BY' + @SQLGroupBy +  '
		--CONVERT(int, DC.WorkFlowState_MemberId)
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN ', CONVERT(int, DC.WorkFlowState_MemberId)' ELSE '' END + '
	ORDER BY' + @SQLGroupBy + '
		--CONVERT(int, DC.WorkFlowState_MemberId)
		' + CASE WHEN (SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = -63) > 0 THEN ', CONVERT(int, DC.WorkFlowState_MemberId)' ELSE '' END + ''
					END

				IF @DebugBM & 1 > 0 AND LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Return ResultTypeBM = 8'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Return ResultTypeBM = 8', 
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement

				EXEC (@SQLStatement)
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 16'
		IF @ResultTypeBM & 16 > 0 --Last Update
			BEGIN
				IF @StorageTypeBM_DataClass & 2 > 0
					BEGIN
						SET @SQLStatement = '
	SELECT
		ResultTypeBM = 16,' + @SQLDimList + '
		UserID = DC.Data_UpdatedBy_UserID,
		UserName = MAX(U.UserNameDisplay),
		SystemUser = MAX(UpdatedBy)
	FROM
		' + @ETLDatabase + '.[dbo].[pcDC_' + @InstanceID_String + '_' + @DataClassName + '] DC
		LEFT JOIN [User] U ON U.UserID = DC.Data_UpdatedBy_UserID' + @SQLJoin + ' 
	WHERE
		ResultTypeBM & 12 > 0 AND' + @SQLWhereClause + '
	GROUP BY' + @SQLGroupBy +  ',
		DC.Data_UpdatedBy_UserID
	ORDER BY' + @SQLGroupBy + ',
		DC.Data_UpdatedBy_UserID'
					END
				ELSE IF @StorageTypeBM_DataClass & 4 > 0
					BEGIN
						SET @SQLStatement = '
	SELECT
		ResultTypeBM = 16,' + @SQLDimList + '
		UserID = 0,
		UserName = MAX(DC.UserID),
		SystemUser = suser_name()
	FROM
		' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] DC' + @SQLJoin_Callisto + ' 
	GROUP BY' + @SQLGroupBy +  '
	ORDER BY' + @SQLGroupBy
					END
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 96'
		IF @ResultTypeBM & 96 > 0 --LineItem AND/OR Comment
			BEGIN
				SET @DataClassName = REPLACE(@DataClassName, '_Detail', '')

				UPDATE DLC
				SET
					[LeafLevelFilter] = DL.[LeafLevelFilter],
					[GroupByYN] = DL.[GroupByYN]
				FROM	
					#DimensionList DL
					INNER JOIN #DimensionList_Cursor DLC ON DLC.DimensionID = DL.DimensionID

				IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionList_Cursor', * FROM #DimensionList_Cursor ORDER BY SortOrder
			END

	SET @Step = '@ResultTypeBM & 32'
		IF @ResultTypeBM & 32 > 0 --LineItem
			BEGIN
				IF @LineItemTable IS NOT NULL
					BEGIN
						--SELECT @SQLJoin_Callisto = '', @SQLJoin = '', @SQLJoin_32_FILTER = ''
						SELECT @SQLJoin_32_Callisto = '', @SQLJoin = '', @SQLJoin_32_FILTER = ''						

						DECLARE DimensionList_Cursor CURSOR FOR

							SELECT
								[DimensionID],
								[DimensionName],
								[HierarchyNo],
								[HierarchyName],
								[StorageTypeBM_Dimension],
								[Filter],
								[FilterLevel],
								[LeafLevelFilter],
								[GroupByYN],
								[SortOrder]
							FROM
								#DimensionList_Cursor
							ORDER BY
								[FilterLevel],
								[SortOrder]

							OPEN DimensionList_Cursor
							FETCH NEXT FROM DimensionList_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo, @HierarchyName, @StorageTypeBM_Dimension, @Filter, @FilterLevel, @LeafLevelFilter, @GroupByYN, @SortOrder

							WHILE @@FETCH_STATUS = 0
								BEGIN
									SELECT
										@SQLSelectList_32 = @SQLSelectList_32 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '] = [' + @DimensionName + '].[Label],',
										@SQLSelectList_32_LIT = @SQLSelectList_32_LIT + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberId] = ' + CASE WHEN @DimensionID = -63 THEN 'MAX' ELSE '' END + '([sub1].[' + @DimensionName + '_MemberId]),',
										@SQLGroupBy_32_LIT = @SQLGroupBy_32_LIT + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN @DimensionID = -63 THEN '' ELSE '[sub1].[' + @DimensionName + '_MemberId],' END,
										@SQLSelectList_32_S = @SQLSelectList_32_S + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberId] = [S].[' + @DimensionName + '_MemberId],',
--										@SQLSelectList_32_DC = @SQLSelectList_32_DC + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberId] = [DC].[' + @DimensionName + '_MemberId],',
										@SQLSelectList_32_DC = @SQLSelectList_32_DC + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberId] = ' + CASE WHEN @DimensionName = 'LineItem' THEN '-1' ELSE '[DC].[' + @DimensionName + '_MemberId]' END + ',',
										@SQLSelectList_32_DISTINCT = @SQLSelectList_32_DISTINCT + CASE WHEN @DimensionID NOT IN (-27, -2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberId] = [LIT].[' + @DimensionName + '_MemberId],' ELSE '' END,
										@SQLJoin_32_DISTINCT = @SQLJoin_32_DISTINCT + CASE WHEN @DimensionID NOT IN (-27, -2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[LIT].[' + @DimensionName + '_MemberId] = [DC].[' + @DimensionName + '_MemberId] AND' ELSE '' END,
										@SQLJoin = @SQLJoin + CASE WHEN @DimensionID NOT IN (-2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[T].[' + @DimensionName + '_MemberId] = [LIT].[' + @DimensionName + '_MemberId] AND' ELSE '' END,
										@SQLJoin_LIT = @SQLJoin_LIT + CASE WHEN @DimensionID NOT IN (-2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[LIT].[' + @DimensionName + '_MemberId] = [sub1].[' + @DimensionName + '_MemberId] AND' ELSE '' END,
										@SQLJoin_T = @SQLJoin_T + CASE WHEN @DimensionID NOT IN (-2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[T].[' + @DimensionName + '_MemberId] = [sub1].[' + @DimensionName + '_MemberId] AND' ELSE '' END,
										@SQLJoin_32_FILTER = @SQLJoin_32_FILTER + CASE WHEN LEN(@LeafLevelFilter) > 0 AND @DimensionID NOT IN (-2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] ON [' + @DimensionName + '].[MemberId] = [LIT].[' + @DimensionName + '_MemberId] AND [' + @DimensionName + '].[Label] IN (' + @LeafLevelFilter + ')' ELSE '' END,
										@SQLJoin_32_S_FILTER = @SQLJoin_32_S_FILTER + CASE WHEN LEN(@LeafLevelFilter) > 0 AND @DimensionID NOT IN (-2) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] ON [' + @DimensionName + '].[MemberId] = [S].[' + @DimensionName + '_MemberId] AND [' + @DimensionName + '].[Label] IN (' + @LeafLevelFilter + ')' ELSE '' END,
										@SQLJoin_32_Callisto = @SQLJoin_32_Callisto + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] ON [' + @DimensionName + '].[MemberId] = sub.[' + @DimensionName + '_MemberId]',
										@SQLOrderBy = @SQLOrderBy + CASE WHEN @DimensionID NOT IN (-27) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '].[Label],' ELSE '' END

									FETCH NEXT FROM DimensionList_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo, @HierarchyName, @StorageTypeBM_Dimension, @Filter, @FilterLevel, @LeafLevelFilter, @GroupByYN, @SortOrder
								END

						CLOSE DimensionList_Cursor
						DEALLOCATE DimensionList_Cursor		

						SELECT
							@SQLSelectList_32_DISTINCT = LEFT(@SQLSelectList_32_DISTINCT, LEN(@SQLSelectList_32_DISTINCT) - 1),
							@SQLJoin = LEFT(@SQLJoin, LEN(@SQLJoin) - 4),
							@SQLJoin_LIT = LEFT(@SQLJoin_LIT, LEN(@SQLJoin_LIT) - 4),
							@SQLJoin_T = LEFT(@SQLJoin_T, LEN(@SQLJoin_T) - 4),
							@SQLJoin_32_DISTINCT = LEFT(@SQLJoin_32_DISTINCT, LEN(@SQLJoin_32_DISTINCT) - 4),
							@SQLOrderBy = LEFT(@SQLOrderBy, LEN(@SQLOrderBy) - 1),
							@SQLSelectList_32_S = LEFT(@SQLSelectList_32_S, LEN(@SQLSelectList_32_S) - 1),
							@SQLGroupBy_32_LIT = LEFT(@SQLGroupBy_32_LIT, LEN(@SQLGroupBy_32_LIT) - 1)
			
						IF @DebugBM & 2 > 0 SELECT [@DataClassName] = @DataClassName, [@LineItemTable] = @LineItemTable, [@LineItemMeasure] = @LineItemMeasure

						SET @SQLStatement = '
	SELECT
		[ResultTypeBM] = 32,
		[Comment] = sub.[Comment],' + @SQLSelectList_32 + '
		[' + REPLACE(@DataClassName, '_Detail', '') + '_Value] = sub.[' + @DataClassName + '_Value],
		[UserID] = sub.[UserId],
		[ChangeDateTime] = sub.[ChangeDateTime]		
	FROM
		(	
		SELECT
			[Comment] = MAX([T].[' + @TextColumn + ']),' + @SQLSelectList_32_LIT + '
			[' + @DataClassName + '_Value] = SUM([LIT].[' + @LineItemMeasure + ']),
			[UserID] = MAX(ISNULL([LIT].[UserId], [T].[UserId])),
			[ChangeDateTime] = MAX(ISNULL([LIT].[ChangeDateTime], [T].[ChangeDateTime]))
		FROM
			(
			SELECT DISTINCT' + @SQLSelectList_32_S + '
			FROM
				' + @CallistoDatabase + '.[dbo].[' + @LineItemTable + '] [S]' + @SQLJoin_32_S_FILTER + ' 

			UNION SELECT DISTINCT' + @SQLSelectList_32_S + '
			FROM
				' + @CallistoDatabase + '.[dbo].[' + @TextTable + '] [S]' + @SQLJoin_32_S_FILTER + ' 
			) [sub1]

			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[' + @LineItemTable + '] [LIT] ON' + @SQLJoin_LIT + '
			
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[' + @TextTable + '] [T] ON' + @SQLJoin_T + '
		WHERE
			' + CASE WHEN @LineItemBP IS NOT NULL THEN '[sub1].BusinessProcess_MemberId = ' + CONVERT(nvarchar(10), @LineItemBP) + ' AND' ELSE '' END + '
			[sub1].[LineItem_MemberId] <> -1
		GROUP BY' + @SQLGroupBy_32_LIT + '

		UNION SELECT
			[Comment] = ''Master Row'',' + @SQLSelectList_32_DC + '
			[' + @DataClassName + '_Value] = [' + @DataClassName + '_Value],
			[UserID] = DC.[UserId],
			[ChangeDateTime] = DC.[ChangeDateTime]
		FROM
			' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] [DC]
			INNER JOIN (
				SELECT DISTINCT' + @SQLSelectList_32_DISTINCT + '
				FROM
					' + @CallistoDatabase + '.[dbo].[' + @LineItemTable + '] [LIT] ' + @SQLJoin_32_FILTER + '
				WHERE
					' + CASE WHEN @LineItemBP IS NOT NULL THEN 'LIT.BusinessProcess_MemberId = ' + CONVERT(nvarchar(10), @LineItemBP) + ' AND' ELSE '' END + '
					LIT.[LineItem_MemberId] <> -1
				) LIT ON' + @SQLJoin_32_DISTINCT + CASE WHEN @LineItemBP IS NULL THEN '' ELSE '
		WHERE
			DC.LineItem_MemberId = -1' END + '
		) sub' + @SQLJoin_32_Callisto + '
	ORDER BY' + CASE WHEN @LineItemBP IS NULL THEN '' ELSE '
		[sub].[LineItem_MemberId],' END + @SQLOrderBy

						IF @DebugBM & 1 > 0 AND LEN(@SQLStatement) > 4000 
							BEGIN
								PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Return ResultTypeBM = 32'
								EXEC [dbo].[spSet_wrk_Debug]
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@DatabaseName = @DatabaseName,
									@CalledProcedureName = @ProcedureName,
									@Comment = 'Return ResultTypeBM = 32', 
									@SQLStatement = @SQLStatement
							END
						ELSE IF @DebugBM & 2 > 0
							PRINT @SQLStatement
				
						EXEC (@SQLStatement)
						SET @Selected = @Selected + @@ROWCOUNT
					END
			END

	SET @Step = '@ResultTypeBM & 64'
		IF @ResultTypeBM & 64 > 0 --Comment
			AND @DataClassTypeID = -1 --Data
			BEGIN
				--SELECT @SQLJoin_Callisto = ''
/*
				DECLARE DimensionList_Cursor CURSOR FOR

					SELECT
						[DimensionID],
						[DimensionName],
						[HierarchyNo],
						[HierarchyName],
						[StorageTypeBM_Dimension],
						[Filter],
						[FilterLevel],
						[LeafLevelFilter],
						[GroupByYN],
						[SortOrder]
					FROM
						--#DimensionList
						#DimensionList_Cursor
					WHERE
						DimensionID NOT IN (-63, -55, -27, -8)
					ORDER BY
						[FilterLevel],
						[SortOrder]

					OPEN DimensionList_Cursor
					--FETCH NEXT FROM DimensionList_Cursor INTO @DimensionID, @DimensionName, @Filter, @FilterLevel, @LeafLevelFilter, @GroupByYN, @SortOrder
					FETCH NEXT FROM DimensionList_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo, @HierarchyName, @StorageTypeBM_Dimension, @Filter, @FilterLevel, @LeafLevelFilter, @GroupByYN, @SortOrder

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName,  [@HierarchyNo] = @HierarchyNo, [@HierarchyName] = @HierarchyName, [@StorageTypeBM_Dimension] = @StorageTypeBM_Dimension, [@Filter] = @Filter, [@FilterLevel] = @FilterLevel, [@LeafLevelFilter] = @LeafLevelFilter, [@GroupByYN] = @GroupByYN, [@SortOrder] = @SortOrder

							IF LEN(@Filter) > 0 AND @Filter <> 'All_'
								BEGIN
									EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @CallistoDatabase, @DimensionName = @DimensionName, @Filter = @Filter, @StorageTypeBM = @StorageTypeBM_Dimension, @HierarchyName = @HierarchyName, @FilterLevel = 'LF', @UseCacheYN = @UseCacheYN, @LeafLevelFilter = @LevelFilter OUT, @Debug = @DebugSub
								END
							ELSE
--								SET @LevelFilter = CASE WHEN @GroupByYN = 0 THEN '''All_''' ELSE NULL END
								SET @LevelFilter = CASE WHEN @GroupByYN = 0 THEN '' ELSE NULL END

							SET @LevelFilter = CASE WHEN @GroupByYN <> 0 AND @LeafLevelFilter <> @LevelFilter THEN @LevelFilter + ',' + @LeafLevelFilter ELSE @LevelFilter END
							
							UPDATE DL
							SET
								LevelFilter = @LevelFilter
							FROM
								#DimensionList DL
							WHERE
								DimensionID = @DimensionID

							IF @DebugBM & 2 > 0 SELECT [@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass, [@DimensionName] = @DimensionName, [@LevelFilter] = @LevelFilter, [@GroupByYN] =  @GroupByYN
							/*
							IF @StorageTypeBM_DataClass & 4 > 0 AND 
								(
									((SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = @DimensionID AND LEN(LevelFilter) <> 0) = 1) OR
									((SELECT COUNT(1) FROM #DimensionList WHERE DimensionID = @DimensionID AND LEN(LevelFilter) <> 0) = 0 AND @GroupByYN <> 0)
								)
								--@StorageTypeBM_DataClass & 4 > 0 AND (LEN(@LevelFilter) > 0 OR @GroupByYN <> 0)
								BEGIN
									SET @SQLJoin_Callisto = @SQLJoin_Callisto + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' ' + @DimensionName + ' ON ' + @DimensionName + '.MemberId = DC.' + @DimensionName + '_MemberId' + CASE WHEN LEN(@LevelFilter) > 0 THEN  ' AND ' + @DimensionName + '.Label IN (' + @LevelFilter + ')' ELSE '' END
								END
							*/
							--FETCH NEXT FROM DimensionList_Cursor INTO @DimensionID, @DimensionName, @Filter, @FilterLevel, @LeafLevelFilter, @GroupByYN, @SortOrder
							FETCH NEXT FROM DimensionList_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo, @HierarchyName, @StorageTypeBM_Dimension, @Filter, @FilterLevel, @LeafLevelFilter, @GroupByYN, @SortOrder
						END

				CLOSE DimensionList_Cursor
				DEALLOCATE DimensionList_Cursor		

				IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionList', * FROM #DimensionList
*/
				IF @StorageTypeBM_DataClass & 2 > 0
					BEGIN
						SET @Message = 'Comment is so far only handled for Callisto.'
						SET @Severity = 16
						GOTO EXITPOINT
					END
				ELSE IF @StorageTypeBM_DataClass & 4 > 0
					BEGIN
						SET @SQLSelectList_64 = @SQLDimList + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'Comment = MAX([' + @DataClassName + '_Text])'
						SET @SQLSelectList_4 = SUBSTRING(@SQLSelectList_4, 1, LEN(@SQLSelectList_4) - 1)

						SET @SQLStatement = '
	SELECT
		ResultTypeBM = 64,' + @SQLSelectList_64 + '
	FROM
		' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_text] DC' + @SQLJoin_64_Callisto + ' 
	' + CASE WHEN @BusinessProcessYN <> 0 THEN 'WHERE DC.BusinessProcess_MemberId <> 118' ELSE '' END + '	
	GROUP BY' + @SQLGroupBy + '
	ORDER BY' + @SQLGroupBy
					END

				IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Return ResultTypeBM = 64'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Return ResultTypeBM = 64', 
							@SQLStatement = @SQLStatement
					END
				ELSE IF @DebugBM & 2 > 0
					PRINT @SQLStatement
				
				EXEC (@SQLStatement)
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE [#DimensionList]
		DROP TABLE [#DC_Param]
		DROP TABLE [#FilterLevel_MemberKey]
		DROP TABLE [#ReadAccess]
		DROP TABLE [#HierarchyList]
		IF @ResultTypeBM & 124 > 0 DROP TABLE [#DimensionList_Cursor]
		IF @CalledYN = 0 DROP TABLE #PipeStringSplit

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
