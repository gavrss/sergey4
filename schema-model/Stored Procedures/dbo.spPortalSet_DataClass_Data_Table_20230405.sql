SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create PROCEDURE [dbo].[spPortalSet_DataClass_Data_Table_20230405]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DataClassID INT = NULL,
	@WorkFlowStateID INT = NULL,
	@AssignmentID INT = NULL,

	@JSON_table NVARCHAR(MAX) = NULL,
	@XML_table XML = NULL,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000331,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*


EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DataClass_Data_Table] @DebugBM=15,
@AssignmentID='21050',@DataClassID='5817',@InstanceID='617',@UserID='10250',@VersionID='1091',@WorkflowStateID='9809'
,@JSON_table='[{"Filter" : "Flow=NONE|Time=202406|Scenario=BUDGET|Entity=SCC|Currency=AUD|Account=4605|GL_Cost_Centre=1001|GL_Project=NONE|GL_Project_Child=NONE|LineItem=NONE|ReferenceType=NONE|BusinessProcess=INPUT|BusinessRule=NONE|Version=NONE", "MeasureValue" : "Financials=5750.0"}]'


EXEC [spRun_Procedure_KeyValuePair] @ProcedureName='spPortalSet_DataClass_Data_Table', @JSON='[{"TKey" : "DebugBM", "TValue" : "15"},
{"TKey" : "UserID", "TValue" : "-1571"},{"TKey" : "InstanceID", "TValue" : "583"},{"TKey" : "VersionID", "TValue" : "1083"},
{"TKey" : "DataClassID", "TValue" : "5788"},{"TKey" : "WorkflowStateID", "TValue" : "9604"},{"TKey" : "AssignmentID", "TValue" : "21098"}]'
, @JSON_table='[
{"Filter" : "BaseCurrency=NZD|Time=202204|Scenario=BUDGET|Rate=Average|Entity=NONE|Currency=USD|BusinessRule=NONE|Simulation=NONE", "MeasureValue" : "FxRate=0"}]'

TODO: for CAPEX, it should be possible to set BP='Input_CAPEX' with LineItem details, and this rule must be tested with different cases

EXEC spRun_Procedure_KeyValuePair @ProcedureName='spPortalSet_DataClass_Data_Table',@JSON='[{"TKey" : "DebugBM", "TValue" : "63"},
{"TKey" : "UserID", "TValue" : "18518"},{"TKey" : "InstanceID", "TValue" : "-1590"},{"TKey" : "VersionID", "TValue" : "-1590"},
{"TKey" : "DataClassID", "TValue" : "18071"},{"TKey" : "WorkflowStateID", "TValue" : "24039"},{"TKey" : "AssignmentID", "TValue" : "37810"}
]',@JSON_table='[{"Filter" : "Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202201|Scenario=BUDGET|Entity=EPIC_A|Currency=USD|Account=1520|GL_Department=00|GL_Division=00|GL_Reference_Type=NONE|WFS=NONE|GL_Customer=NONE|GL_Employee=NONE|GL_Product=NONE|GL_TradingPartner=NONE|BusinessRule=NONE|LineItem=02|Version=NONE|BusinessProcess=DEPR_YEAR", 
"MeasureValue" : "Financials=5.0"}]'


EXEC [spRun_Procedure_KeyValuePair] @ProcedureName='spPortalSet_DataClass_Data_Table', @JSON='[{"TKey" : "DebugBM", "TValue" : "15"},
{"TKey" : "UserID", "TValue" : "18309"},{"TKey" : "InstanceID", "TValue" : "-1558"},{"TKey" : "VersionID", "TValue" : "-1558"}
,{"TKey" : "DataClassID", "TValue" : "17663"},{"TKey" : "WorkflowStateID", "TValue" : "22636"},{"TKey" : "AssignmentID", "TValue" : "25128"}
]', @JSON_table='[
{"Filter" : "Product=Z2170|OrderState=60|Customer=CHIGLEASE_|Time=202101|Scenario=BUDGET|Entity=EPIC03|Currency=NONE|Account=SalesQtyUnit_|BusinessProcess=INPUT|BusinessRule=NONE|TimeDataView=RAWDATA", "MeasureValue" : "SalesBudget=1234.0"}]'


EXEC [spRun_Procedure_KeyValuePair] @ProcedureName='spPortalSet_DataClass_Data_Table', @JSON='[{"TKey" : "DebugBM", "TValue" : "15"},
{"TKey" : "UserID", "TValue" : "18309"},{"TKey" : "InstanceID", "TValue" : "-1558"},{"TKey" : "VersionID", "TValue" : "-1558"}
,{"TKey" : "DataClassID", "TValue" : "17663"},{"TKey" : "WorkflowStateID", "TValue" : "22636"},{"TKey" : "AssignmentID", "TValue" : "25128"}
]', @JSON_table='[
{"Filter" : "Product=Z2170|OrderState=60|Customer=CHIGLEASE_|Time=202101|Scenario=BUDGET|Entity=EPIC03|Currency=NONE|Account=SalesQtyUnit_|BusinessProcess=INPUT|BusinessRule=NONE|TimeDataView=RAWDATA", "MeasureValue" : "SalesBudget=1234.0"}]'

EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DataClass_Data_Table] @DataClassID='5713',@InstanceID='572',@UserID='9863',@VersionID='1080', @DebugBM=63
,@JSON_table='[{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202206|Scenario=F8|Entity=AU03|Currency=AUD|Account=8554|GL_CostCenter=07|GL_Branch=229|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE|Measure=Comment", 
"MeasureValue" : "Comment=eyJtZXNzYWdlIjoidGVzdCBjb21tZW50IC0gSnVuZTIwMjIgLSBBY2NvdW50IDg1NTQiLCJ1c2VyIjo5ODYzLCJkYXRlIjoxNjY5MjAxNDQ1MjE4fQ=="}]'

--LineItem 
EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DataClass_Data_Table] @AssignmentID='19994',@DataClassID='5713',@InstanceID='572',@UserID='9863',@VersionID='1080',@WorkflowStateID='9660',@DebugBM=63
,@JSON_table='
[{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202309|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8411|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|TimeDataView=RAWDATA|Version=NONE|LineItem=05", "MeasureValue" : "Financials=60000.0"}]
'

--LlineItem WITH Comment
EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DataClass_Data_Table] @AssignmentID='19994',@DataClassID='5713',@InstanceID='572',@UserID='9863',@VersionID='1080',@WorkflowStateID='9660',@DebugBM=63
,@JSON_table='
[{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202304|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8411|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|TimeDataView=RAWDATA|Version=NONE|LineItem=05", "MeasureValue" : "Comment=QkVFIFZlcmlmaWNhdGlvbg=="}]
'

--Comments
EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DataClass_Data_Table] @DataClassID='5713',@InstanceID='572',@UserID='9863',@VersionID='1080',@DebugBM=63
,@JSON_table='
[{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=FY2023|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8412|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|Version=NONE|Measure=Comment", 
"MeasureValue" : "Comment=eyJtZXNzYWdlIjoiSW5jb21lIFRheCBBdWRpdCBBc3Npc3RhbmNlIiwidXNlciI6OTg2MywiZGF0ZSI6MTY2ODc0NjczODM4Mn0="}]
'
EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DataClass_Data_Table] @DataClassID='5713',@InstanceID='572',@UserID='9863',@VersionID='1080',@DebugBM=63
,@JSON_table='
[{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202307|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8411|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE|Measure=Comment", 
"MeasureValue" : "Comment=eyJtZXNzYWdlIjoiSGl0YWNoaSBUUCBSZXBvcnQiLCJ1c2VyIjo5ODYzLCJkYXRlIjoxNjY4NzQ2NzgyNDE1fQ=="}]
'

DECLARE	@JSON_table nvarchar(MAX) = '
[
{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202305|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8082|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE", "MeasureValue" : "Financials=0.0"}
,{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202306|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8781|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE", "MeasureValue" : "Financials=0.0"}
]'

EXEC [dbo].[spPortalSet_DataClass_Data_Table] @AssignmentID='19994',@DataClassID='5713',@InstanceID='572',@UserID='9916',@VersionID='1080',@WorkflowStateID='9660'
	,@DebugBM=63
	,@JSON_table = @JSON_table


--JSON table sample--
--=================--
DECLARE	@JSON_table nvarchar(MAX) = '
[
{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202305|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8082|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE", "MeasureValue" : "Financials=0.0"}
,{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202306|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8781|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE", "MeasureValue" : "Financials=0.0"}
,{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202309|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8082|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE", "MeasureValue" : "Financials=0.0"}
,{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202308|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8553|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE", "MeasureValue" : "Financials=0.0"}
,{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202307|Scenario=BUDGET|Entity=ZA01|Currency=ZAR|Account=8566|GL_CostCenter=13|GL_Branch=650|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE", "MeasureValue" : "Financials=0.0"}
]'

EXEC [dbo].[spPortalSet_DataClass_Data_Table] @AssignmentID='19994',@DataClassID='5713',@InstanceID='572',@UserID='9916',@VersionID='1080',@WorkflowStateID='9660'
	,@DebugBM=31
	,@JSON_table = @JSON_table


--XML table sample--
--================--
DECLARE	@XML_table xml = '
	<root>
		<row Filter="AccountManager=WF24|BudgetProduct=PLT/FLT-CSGG_Plate_ShipPlate_Japan|Currency=SGD|Entity=AJ04|Scenario=Budget|Time=201701|TimeFiscalYear=2017|GL_Branch = 3B" MeasureValue="SalesRM = 700|SalesPrice = 63.3" />
		<row Filter="AccountManager=WF24|BudgetProduct=PLT/FLT-CSGG_Plate_ShipPlate_Japan|Currency=SGD|Entity=AJ04|Scenario=Budget|Time=201702|TimeFiscalYear=2017|GL_Branch = 3B" MeasureValue="SalesRM = 700|SalesPrice = 63.3" />
	</root>'

EXEC [dbo].[spPortalSet_DataClass_Data_Table] 
	@UserID = -10,
	@InstanceID = 114,
	@VersionID = 1004,
	@DataClassID = 1004,
	@XML_table = @XML_table,
	@Debug = 1

--spRun_Procedure_KeyValuePair sample for JSON--
--============================================--
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalSet_DataClass_Data_Table',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "8345"},
		{"TKey" : "InstanceID",  "TValue": "454"},
		{"TKey" : "VersionID",  "TValue": "1021"},
		{"TKey" : "DataClassID",  "TValue": "5153"}
		]',
	@JSON_table = '
		[
		{"Filter" : "AccountManager=WF24|BudgetProduct=PLT/FLT-CSGG_Plate_ShipPlate_Japan|Currency=SGD|Entity=AJ04|Scenario=Budget|Time=201701|TimeFiscalYear=2017|GL_Branch = 3B", "MeasureValue": "SalesRM = 700|SalesPrice = 63.3"},
		{"Filter" : "AccountManager=WF24|BudgetProduct=PLT/FLT-CSGG_Plate_ShipPlate_Japan|Currency=SGD|Entity=AJ04|Scenario=Budget|Time=201702|TimeFiscalYear=2017|GL_Branch = 3B", "MeasureValue": "SalesRM = 700|SalesPrice = 63.3"}
		]'

EXEC [spPortalSet_DataClass_Data_Table] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ApplicationID INT,
	@Filter NVARCHAR(4000),
	@MeasureValue NVARCHAR(4000),
	@ObjectListMaster_Dimension NVARCHAR(50),
	@MeasureName NVARCHAR(50),
	@Measure_Value NVARCHAR (4000) = NULL,
	@Measure_Text NVARCHAR (4000) = NULL,
	@ColumnName NVARCHAR(255),
	@EqualityString NVARCHAR(50),
	@FACT_DataClass_MemberId_InsertCallisto NVARCHAR(MAX) = '',
	@FACT_DataClass_MemberId_SelectCallisto NVARCHAR(MAX) = '',
	@FACT_DataClass_MemberId_JoinCallisto NVARCHAR(MAX) = '',
	@FACT_DataClass_MemberId_DeleteCallisto NVARCHAR(MAX) = '',
	@FACT_DataClass_MemberKey_InsertCallisto NVARCHAR(MAX) = '',
	@FACT_DataClass_MemberKey_SelectCallisto NVARCHAR(MAX) = '',
	@FACT_DataClass_InsertCallisto_Measure_Value NVARCHAR(MAX) = NULL,
	@FACT_DataClass_SelectCallisto_Measure_Value NVARCHAR(MAX) = NULL,
	@FACT_DataClass_InsertCallisto_Measure_Text NVARCHAR(MAX) = NULL,
	@FACT_DataClass_SelectCallisto_Measure_Text NVARCHAR(MAX) = NULL,	
	@FACT_DataClass_MemberKey_UpdateSendTo NVARCHAR(MAX) = '',
	@FACT_DataClass_MemberKey_JoinSendTo NVARCHAR(MAX) = '',

	@SQLStatement NVARCHAR(MAX),	
	@InputValue NVARCHAR(4000),	
	@StorageTypeBM_DataClass INT,
	@DataClassName NVARCHAR(100),	
	@ETLDatabase NVARCHAR(100),
	@CallistoDatabase NVARCHAR(100),
	@MissingDimension NVARCHAR(1000) = '',
	@InitialWorkflowStateID INT,
	@StepWorkflowState_MemberId BIGINT,
	@StepWorkflowState_MemberKey NVARCHAR(100),
	@InitialWorkflowStateMemberKey NVARCHAR(100),
	@WorkflowStateMemberKey NVARCHAR(100),
	@Account_MaxHierarchyNo INT = 0,
	@ObjectType NVARCHAR(20),
	@ResultTypeBM INT = 4,
	@CalledYN BIT = 1,
	@CommentYN BIT = 0,
	@FACT_DataClass_Table NVARCHAR(100),
	@FACT_DataClass_Text_Table NVARCHAR(100),
	@FACT_DataClass_Table_ExistsYN BIT = 0,
	@FACT_DataClass_Text_Table_ExistsYN BIT = 0,
	@FACT_DataClass_Table_LI_ExistsYN BIT = 0,
	@FACT_DataClass_Text_Table_LI_ExistsYN BIT = 0,
	@LineItem_ExistsYN BIT = 0,
	@AuditLogYN BIT = 0,
	@ReturnVariable INT,
	
	--@DataClassTypeID INT,
	--@DimensionDistinguishing NVARCHAR(20),
	--@InstanceID_String NVARCHAR(10),

	--@UsedValue NVARCHAR(4000),
	--@MemberId_List NVARCHAR(4000),
	--@SQLWhereClause NVARCHAR(MAX) = '',
	--@SQLWhereDeleteClause NVARCHAR(MAX) = '',
	--@SQLInsertClause NVARCHAR(MAX) = '',
	--@SQLSelectClause NVARCHAR(MAX) = '',
	--@SQLJoin_UpdateCallisto_Measure NVARCHAR(MAX) = '',
	--@SQLJoin_UpdateCallisto_Comment NVARCHAR(MAX) = '',
	--@SQLJoin_InsertCallisto_Measure NVARCHAR(MAX) = '',
	--@SQLJoin_InsertCallisto_Comment NVARCHAR(MAX) = '',
	--@SQLSelect_InsertCallisto NVARCHAR(MAX) = '',
	--@SQLSelect_InsertCallistoText NVARCHAR(MAX) = '',
	--@SQLSetClause NVARCHAR(1000) = '',	
	--@Comment NVARCHAR(4000) = '',
	--@CharIndex INT, 
	--@DimFilter NVARCHAR(2000),
	--@FilterLen INT,
	--@EqualSignPos INT,
	--@ObjectName NVARCHAR(100),
	--@StorageTypeBM_Dimension INT,
	--@DestinationDatabase NVARCHAR(100),
	--@ReturnVariable INT,
	--@HierarchyNo INT = 0,
	--@Inserted_Check INT,
	--@Deleted_Check INT,
	--@Updated_Check INT,
	--@MeasureYN BIT = 0,
	--@LineItemYN BIT = 0,
	--@Temp_FACT_DataClass_Table NVARCHAR(100),
	--@LineItemBP INT,
	--@FromNum FLOAT,
	--@FromText NVARCHAR(4000),

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName nvarchar(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged nvarchar(255) = '1. Update to new template; 2.for CAPEX, it should be possible to set BP=''Input_CAPEX'' with LineItem details, and this rule must be tested with different cases',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2194'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Save multiple rows of data into a DataClass',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2141' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-98: Implemented Setting of LineItem and Comment. DB-104 Add possibility to define WorkflowState as Filter in @JSON_table.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-144: Handle dimensions ReportOnlyYN = 1. DB-152: Handle when WorkflowState is set as parameter and not in JSON table.'
		IF @Version = '2.0.3.2151' SET @Description = 'DB-274: Handle LineItem when stored in separate FACT table.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-316: Ignore filters for dimensions not existing in DataClass.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-368: Handle Strings longer than 1000. DB-371: Always set WorkflowState to NONE in text tables. Store @UserID instead of @UserName in Callisto UserID column. DB-377: Simplify delete query to increase performance.'
		IF @Version = '2.0.3.2154' SET @Description = 'Enable Audit Log'
		IF @Version = '2.1.0.2161' SET @Description = 'Fixed an issue with empty where clause when saving comments.'
		IF @Version = '2.1.0.2163' SET @Description = 'Replaced call to spGet_MemberId and spGet_MemberKey with call to spGet_MemberInfo.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle empty @MemberId_List.'
		IF @Version = '2.1.1.2169' SET @Description = 'Check for included dimensions before creating SQL statements. DB-624: Set [IncludedYN]=1 for [ObjectType]=Comment in #ObjectList temp table.'
		IF @Version = '2.1.2.2181' SET @Description = 'Exclude DimensionID = -77 in #ObjectListMaster for [ObjectType] = Dimension; DB-1225: Added brackets around @ObjectName names.'
		IF @Version = '2.1.2.2182' SET @Description = 'Temp fix for Account Dimension: Handle accounts NOT existing in the default hierarchy.'
		IF @Version = '2.1.2.2190' SET @Description = 'Refactored for performance enhancement (i.e. instead of inserting into FACT table per @Filter, we no do INSERT one time at the end). '
		IF @Version = '2.1.2.2193' SET @Description = 'For CAPEX, add possibility to set [BusinessProcess] with ''Input_CAPEX'',''DEPR_YEAR'' or ''Capex_Display'' with LineItem details. Add WorkflowState in #ObjectListMaster if dimension is existing in the DataClass (@DataClassID).'
		IF @Version = '2.1.2.2194' SET @Description = 'EA-4840: Update temptable #ObjectListMaster [DefaultValue] for WorkflowState dimension if @WorkFlowStateID IS NOT NULL.'

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
			@ApplicationID = ISNULL(@ApplicationID , MAX(ApplicationID))
		FROM 
			[pcIntegrator_Data].[dbo].[Application] 
		WHERE 
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND 
			SelectYN <> 0
		
		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[pcIntegrator_Data].[dbo].[Application] A
		WHERE
			A.ApplicationID = @ApplicationID

		IF @DebugBM & 2 > 0 SELECT [@ApplicationID] = @ApplicationID, [@CallistoDatabase] = @CallistoDatabase, [@ETLDatabase] = @ETLDatabase

		SELECT
			@DataClassName = D.DataClassName,
			@MeasureName = M.MeasureName,
			--@DataClassTypeID = D.DataClassTypeID,
			@StorageTypeBM_DataClass = D.StorageTypeBM
			--@InstanceID_String = CASE LEN(@InstanceID) WHEN 1 THEN '000' WHEN 2 THEN '00' WHEN 3 THEN '0' ELSE '' END + CONVERT(NVARCHAR(10), @InstanceID)
		FROM
			[DataClass] D
			LEFT JOIN [Measure] M ON M.InstanceID = D.InstanceID AND M.VersionID = D.VersionID AND M.DataClassID = D.DataClassID AND M.SelectYN <> 0 AND M.DeletedID IS NULL
		WHERE
			D.InstanceID = @InstanceID AND
			D.VersionID = @VersionID AND
			D.DataClassID = @DataClassID

		SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM ' + @CallistoDatabase + '.sys.tables WHERE [name] = ''AUDIT_' + @DataClassName + '_num'''
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @AuditLogYN OUT

		SET @FACT_DataClass_Table = 'FACT_' + @DataClassName + '_default_partition'
		SET @FACT_DataClass_Table_ExistsYN = CASE WHEN (SELECT OBJECT_ID(@CallistoDatabase + '.[dbo].' + @FACT_DataClass_Table, 'U')) IS NULL THEN 0 ELSE 1 END 

		SET @FACT_DataClass_Text_Table = 'FACT_' + @DataClassName + '_Text'
		SET @FACT_DataClass_Text_Table_ExistsYN = CASE WHEN (SELECT OBJECT_ID(@CallistoDatabase + '.[dbo].' + @FACT_DataClass_Text_Table, 'U')) IS NULL THEN 0 ELSE 1 END 

		
		SET @SQLStatement = '
			SELECT @internalVariable = COUNT(1)
			FROM
				' + @CallistoDatabase + '.[sys].[tables] T
				INNER JOIN ' + @CallistoDatabase + '.[sys].[columns] C ON c.object_id = T.object_id AND C.[name] = ''LineItem_MemberId''
			WHERE
				T.[name] = ''' + @FACT_DataClass_Table + ''''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ReturnVariable OUT
		IF @ReturnVariable > 0 SELECT @FACT_DataClass_Table_LI_ExistsYN = 1

		SET @SQLStatement = '
			SELECT @internalVariable = COUNT(1)
			FROM
				' + @CallistoDatabase + '.[sys].[tables] T
				INNER JOIN ' + @CallistoDatabase + '.[sys].[columns] C ON c.object_id = T.object_id AND C.[name] = ''LineItem_MemberId''
			WHERE
				T.[name] = ''' + @FACT_DataClass_Text_Table + ''''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ReturnVariable OUT
		IF @ReturnVariable > 0 SELECT @FACT_DataClass_Text_Table_LI_ExistsYN = 1
		
		--SET @DimensionDistinguishing = CASE WHEN @StorageTypeBM_DataClass & 4 > 0 THEN '_MemberId' ELSE '_MemberKey' END

		SELECT
			@InitialWorkflowStateID = InitialWorkflowStateID
		FROM
			[Workflow] WF
			INNER JOIN [Assignment] A ON A.InstanceID = WF.InstanceID AND A.VersionID = WF.VersionID AND A.WorkflowID = WF.WorkflowID AND A.AssignmentID = @AssignmentID
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID

		SET @InitialWorkflowStateID  = ISNULL(@InitialWorkflowStateID, -1)

		IF @WorkflowStateID IS NULL
			SET @WorkflowStateMemberKey = NULL
		ELSE
			EXEC [spGet_MemberInfo] @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = -63, @MemberID = @WorkflowStateID, @MemberKey = @WorkflowStateMemberKey OUT

		EXEC [spGet_MemberInfo] @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = -63, @MemberID = @InitialWorkflowStateID, @MemberKey = @InitialWorkflowStateMemberKey OUT						
			
		SELECT @Account_MaxHierarchyNo = MAX(HierarchyNo) FROM [pcINTEGRATOR].[dbo].[DimensionHierarchy] WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND DimensionID = -1

		IF @DebugBM & 2 > 0 
			SELECT
				[@DataClassName] = @DataClassName,
				[@MeasureName] = @MeasureName,
				[@InitialWorkflowStateID] = @InitialWorkflowStateID,
				[@InitialWorkflowStateMemberKey] = @InitialWorkflowStateMemberKey,
				[@WorkflowStateID] = @WorkflowStateID,
				[@WorkflowStateMemberKey] = @WorkflowStateMemberKey,
				[@AuditLogYN] = @AuditLogYN,
				[@Account_MaxHierarchyNo] = @Account_MaxHierarchyNo,
				[@FACT_DataClass_Table] = @FACT_DataClass_Table,
				[@FACT_DataClass_Table_ExistsYN] = @FACT_DataClass_Table_ExistsYN,
				[@FACT_DataClass_Text_Table] = @FACT_DataClass_Text_Table,
				[@FACT_DataClass_Text_Table_ExistsYN] = @FACT_DataClass_Text_Table_ExistsYN

	--SET @Step = 'Create temp table #ObjectList'	
	--	CREATE TABLE #ObjectList
	--		(
	--		[ObjectType] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
	--		[ObjectID] INT,
	--		[ObjectName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
	--		[StorageTypeBM] INT,
	--		[IncludedYN] BIT,
	--		[SortOrder] INT,
	--		[InputValue] NVARCHAR(4000) COLLATE DATABASE_DEFAULT,
	--		[MeasureValue] NVARCHAR(4000) COLLATE DATABASE_DEFAULT,
	--		[CommentValue] NVARCHAR(4000) COLLATE DATABASE_DEFAULT,
	--		)
	
	SET @Step = 'Create temp table #ObjectListMaster'
		SELECT DISTINCT
			[ObjectType] = 'Dimension' COLLATE DATABASE_DEFAULT,
			[ObjectID] = DCD.DimensionID,
			[ObjectName] = D.DimensionName COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] = DST.StorageTypeBM,
			[IncludedYN] = CONVERT(BIT, 1),
			[DefaultValue] = CONVERT(NVARCHAR(4000), D.[DefaultValue]) COLLATE DATABASE_DEFAULT,
			[SortOrder] = DCD.SortOrder
		INTO
			#ObjectListMaster
		FROM
			DataClass_Dimension DCD
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = DCD.DimensionID AND [DimensionTypeID] <> 27 --AND D.DimensionID <> -63
			LEFT JOIN Dimension_StorageType DST ON DST.InstanceID = DCD.InstanceID AND DST.VersionID = DCD.VersionID AND DST.DimensionID = DCD.DimensionID
		WHERE
			DCD.InstanceID = @InstanceID AND
			DCD.VersionID = @VersionID AND
			DCD.DataClassID = @DataClassID AND
			DCD.DimensionID NOT IN (-77)
		ORDER BY
			DCD.SortOrder

		INSERT INTO #ObjectListMaster
			(
			[ObjectType],
			[ObjectID],
			[ObjectName],
			[StorageTypeBM],
			[IncludedYN],
			[SortOrder]
			)
		SELECT DISTINCT
			[ObjectType] = 'Measure',
			[ObjectID] = M.MeasureID,
			[ObjectName] = M.MeasureName,
			[StorageTypeBM] = @StorageTypeBM_DataClass,
			[IncludedYN] = 1,
			[SortOrder] = M.SortOrder
		FROM
			Measure M
			INNER JOIN DataType DT ON DT.DataTypeID = M.DataTypeID
		WHERE
			M.InstanceID = @InstanceID AND
			M.VersionID = @VersionID AND
			M.DataClassID = @DataClassID AND
			M.SelectYN <> 0 AND
			M.DeletedID IS NULL
		ORDER BY
			M.SortOrder

		--INSERT INTO #ObjectListMaster
		--	(
		--	[ObjectType],
		--	[ObjectID],
		--	[ObjectName],
		--	[StorageTypeBM],
		--	[IncludedYN],
		--	[DefaultValue],
		--	[SortOrder]
		--	)
		--SELECT DISTINCT
		--	[ObjectType] = 'Dimension' COLLATE DATABASE_DEFAULT,
		--	[ObjectID] = -63,
		--	[ObjectName] = 'WorkflowState' COLLATE DATABASE_DEFAULT,
		--	[StorageTypeBM] = 4,
		--	[IncludedYN] = 0,
		--	[DefaultValue] = COALESCE(@WorkflowStateMemberKey, @InitialWorkflowStateMemberKey, 'NONE'),
		--	[SortOrder] = 9999
		--WHERE
		--	@WorkFlowStateID IS NOT NULL AND
		--	EXISTS (SELECT 1 FROM #ObjectListMaster D WHERE D.ObjectID = -63)
		
		UPDATE OLM 
		SET
			[DefaultValue] = COALESCE(@WorkflowStateMemberKey, @InitialWorkflowStateMemberKey, 'NONE')
		FROM 
			#ObjectListMaster OLM
		WHERE
			@WorkFlowStateID IS NOT NULL AND
			OLM.ObjectID = -63 --WorkflowState

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ObjectListMaster', * FROM #ObjectListMaster

	SET @Step = 'Create temp tables #Dummy'
		SELECT [Dummy] = 1 INTO #Dummy

	SET @Step = 'Create temp tables #SendTo_Dimensions'
		CREATE TABLE #SendTo_Dimensions
		(
			[Dimension] NVARCHAR(255) COLLATE DATABASE_DEFAULT
		)

	SET @Step = 'Create temp tables #FACT_DataClass_%'
		CREATE TABLE #FACT_DataClass_MemberKey
			(
			[Dummy] [int] DEFAULT(0)
			)

		CREATE TABLE #FACT_DataClass_MemberId
			(
			[Dummy] [int] DEFAULT(0)
			)

		SET @SQLStatement = '
			ALTER TABLE #FACT_DataClass_MemberKey ADD [' + @MeasureName + '_Value] FLOAT 
			ALTER TABLE #FACT_DataClass_MemberId ADD [' + @MeasureName + '_Value] FLOAT 
			
			ALTER TABLE #FACT_DataClass_MemberKey ADD [' + @MeasureName + '_Text] NVARCHAR(4000) COLLATE DATABASE_DEFAULT 
			ALTER TABLE #FACT_DataClass_MemberId ADD [' + @MeasureName + '_Text] NVARCHAR(4000) COLLATE DATABASE_DEFAULT '

			IF @DebugBM & 2 > 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

		--Loop through all dimensions
		IF CURSOR_STATUS('global','ObjectListMaster_Cursor') >= -1 DEALLOCATE ObjectListMaster_Cursor
		DECLARE ObjectListMaster_Cursor CURSOR FOR
			SELECT DISTINCT 
				[ObjectListMaster_Dimension] = [ObjectName]
			FROM
				#ObjectListMaster
			WHERE
				[ObjectType] = 'Dimension'
			ORDER BY
				[ObjectName]

			OPEN ObjectListMaster_Cursor
			FETCH NEXT FROM ObjectListMaster_Cursor INTO @ObjectListMaster_Dimension

			WHILE @@FETCH_STATUS = 0
				BEGIN
					--IF @DebugBM & 2> 0 SELECT [ObjectListMaster_Dimension] = @ObjectListMaster_Dimension

					IF @ObjectListMaster_Dimension = 'LineItem' 
						SET @LineItem_ExistsYN = 1
					
					SET @SQLStatement = '
						ALTER TABLE #FACT_DataClass_MemberKey ADD [' + @ObjectListMaster_Dimension + '] NVARCHAR(255) COLLATE DATABASE_DEFAULT
						ALTER TABLE #FACT_DataClass_MemberId ADD [' + @ObjectListMaster_Dimension + '_MemberId] BIGINT DEFAULT(-1)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)				

					FETCH NEXT FROM ObjectListMaster_Cursor INTO  @ObjectListMaster_Dimension
				END

		CLOSE ObjectListMaster_Cursor
		DEALLOCATE ObjectListMaster_Cursor

		IF @DebugBM & 2 > 0 
			BEGIN
				SELECT [@LineItem_ExistsYN] = @LineItem_ExistsYN
				--SELECT [#FACT_DataClass_MemberKey] = '#FACT_DataClass_MemberKey', * FROM #FACT_DataClass_MemberKey
				--SELECT [#FACT_DataClass_MemberId] = '#FACT_DataClass_MemberId', * FROM #FACT_DataClass_MemberId
			END

	SET @Step = 'Create temp table #PipeStringSplit'
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

	SET @Step = 'Create and fill Cursor table'
		CREATE TABLE #Data_Cursor_Table
			(
			[Filter] nvarchar(4000) COLLATE database_default,
			[MeasureValue] nvarchar(4000) COLLATE database_default
			)			

		IF @JSON_table IS NOT NULL	
			BEGIN
				INSERT INTO #Data_Cursor_Table
					(
					[Filter],
					[MeasureValue]
					)
				SELECT
					[Filter],
					[MeasureValue] 
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[Filter] nvarchar(4000) COLLATE database_default,
					[MeasureValue] nvarchar(4000) COLLATE database_default
					)
			END

		ELSE IF @XML_table IS NOT NULL
			BEGIN
				SET ANSI_WARNINGS ON
				 
				INSERT INTO #Data_Cursor_Table
					(
					[Filter],
					[MeasureValue]
					)
				SELECT 
					[Filter] = r.v.value('@Filter[1]', 'nvarchar(4000)'),
					[MeasureValue] = r.v.value('@MeasureValue[1]', 'nvarchar(4000)')
				FROM
					@XML_table.nodes('root/row') r(v)

				SET ANSI_WARNINGS OFF
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Data_Cursor_Table', * FROM #Data_Cursor_Table

	SET @Step = 'DataClass_Data_Cursor'
		DECLARE DataClass_Data_Cursor CURSOR FOR
			SELECT 
				[Filter],
				[MeasureValue]
			FROM
				#Data_Cursor_Table

			OPEN DataClass_Data_Cursor
			FETCH NEXT FROM DataClass_Data_Cursor INTO @Filter, @MeasureValue

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT '>>>>>>>>> START: BEGIN DataClass_Data_Cursor'
					IF @DebugBM & 2 > 0 SELECT [Filter] = @Filter, [MeasureValue] = @MeasureValue

					SELECT 						
						@FACT_DataClass_MemberKey_InsertCallisto = '',
						@FACT_DataClass_MemberKey_SelectCallisto = '',
						@FACT_DataClass_InsertCallisto_Measure_Value = NULL,
						@FACT_DataClass_SelectCallisto_Measure_Value = NULL,
						@FACT_DataClass_InsertCallisto_Measure_Text = NULL,
						@FACT_DataClass_SelectCallisto_Measure_Text = NULL
					
					SET @Step = 'Generate queries for temptables @FACT_DataClass_% (Based on @Filter)'
						IF LEN(@Filter) > 3
							BEGIN
								TRUNCATE TABLE #PipeStringSplit

								EXEC [pcINTEGRATOR].[dbo].[spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @Filter, @Debug = 0

								IF @DebugBM & 2 > 0 SELECT [#PipeStringSplit] = '#PipeStringSplit', * FROM #PipeStringSplit

								IF @StorageTypeBM_DataClass & 4 > 0
									BEGIN
										--Fill temp table #FACT_DataClass_MemberId
										IF CURSOR_STATUS('global','AddColumnValue_Cursor') >= -1 DEALLOCATE AddColumnValue_Cursor
										DECLARE AddColumnValue_Cursor CURSOR FOR
											SELECT 
												OLM.[ObjectType],
												[ColumnName] = ISNULL(PSS.[PipeObject], OLM.ObjectName),
												[EqualityString] = ISNULL(PSS.[EqualityString], 'IN'),
												[InputValue] = ISNULL(PSS.[PipeFilter], OLM.DefaultValue)
											FROM
												#ObjectListMaster OLM
												LEFT JOIN #PipeStringSplit PSS ON PSS.PipeObject = OLM.[ObjectName]
											WHERE 
												OLM.[ObjectType] = 'Dimension'

											OPEN AddColumnValue_Cursor
											FETCH NEXT FROM AddColumnValue_Cursor INTO @ObjectType, @ColumnName, @EqualityString, @InputValue

											WHILE @@FETCH_STATUS = 0
												BEGIN
													--Dimension @InputValue modifications:
													IF @ColumnName = 'WorkflowState' 
														BEGIN
															SET @InputValue = COALESCE(@WorkflowStateMemberKey, @InputValue, @InitialWorkflowStateMemberKey, 'NONE')
															SET @StepWorkflowState_MemberKey = @InputValue

															EXEC [pcINTEGRATOR].[dbo].[spGet_MemberInfo] @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = -63, @MemberKey = @StepWorkflowState_MemberKey, @MemberID = @StepWorkflowState_MemberId OUT
														
															IF @DebugBM & 2 > 0 SELECT [@StepWorkflowState_MemberKey] = @StepWorkflowState_MemberKey, [@StepWorkflowState_MemberId] = @StepWorkflowState_MemberId
														END
													
													IF @ColumnName = 'TimeDataView' AND @InputValue = 'PERIODIC'
														SET @InputValue = 'RAWDATA'

													IF @DebugBM & 2 > 0
														SELECT [@ColumnName] = @ColumnName, [@EqualityString] = @EqualityString, [@InputValue] = @InputValue
																
													--Set @MissingDimension
													IF @ColumnName <> 'LineItem' AND (@InputValue IS NULL OR @InputValue = '')
														SELECT @MissingDimension = @MissingDimension + @ColumnName + ', '

													SET @FACT_DataClass_MemberKey_InsertCallisto = @FACT_DataClass_MemberKey_InsertCallisto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + @ColumnName + '],'
													SET @FACT_DataClass_MemberKey_SelectCallisto = @FACT_DataClass_MemberKey_SelectCallisto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + @ColumnName + '] = ''' + @InputValue + ''','
													
													FETCH NEXT FROM AddColumnValue_Cursor INTO  @ObjectType, @ColumnName, @EqualityString, @InputValue
												END

										CLOSE AddColumnValue_Cursor
										DEALLOCATE AddColumnValue_Cursor

										
										IF @DebugBM & 2 > 0 
											BEGIN
												SELECT [@FACT_DataClass_MemberKey_InsertCallisto] = @FACT_DataClass_MemberKey_InsertCallisto
												SELECT [@FACT_DataClass_MemberKey_SelectCallisto] = @FACT_DataClass_MemberKey_SelectCallisto
											END

									END
							END --IF LEN(@Filter) > 3


						IF LEN(@MissingDimension) > 0
							BEGIN
								SET @MissingDimension = LEFT(@MissingDimension, LEN(@MissingDimension) - 1)
								SET @Message = 'Missing dimension(s): ' + @MissingDimension
								SET @Severity = 16
								GOTO EXITPOINT
							END

					SET @Step = 'Generate queries for temptables @FACT_DataClass_% (Based on @MeasureValue)'
						IF LEN(@MeasureValue) > 3
							BEGIN
								TRUNCATE TABLE #PipeStringSplit

								EXEC [pcINTEGRATOR].[dbo].[spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @MeasureValue, @Debug = 0

								IF @DebugBM & 2 > 0 SELECT [#PipeStringSplit] = '#PipeStringSplit', * FROM #PipeStringSplit

								IF @StorageTypeBM_DataClass & 4 > 0
									BEGIN
										--Fill temp table #FACT_DataClass_MemberId
										IF CURSOR_STATUS('global','AddColumnValue_Cursor') >= -1 DEALLOCATE AddColumnValue_Cursor
										DECLARE AddColumnValue_Cursor CURSOR FOR
											SELECT 
												[ObjectType] = OLM.[ObjectType],
												[ColumnName] = ISNULL(PSS.[PipeObject], OLM.ObjectName),
												[EqualityString] = ISNULL(PSS.[EqualityString], 'IN'),
												[InputValue] = ISNULL(PSS.[PipeFilter], OLM.DefaultValue)
											FROM
												#PipeStringSplit PSS
												LEFT JOIN #ObjectListMaster OLM ON OLM.[ObjectName] = PSS.PipeObject AND OLM.[ObjectType] = 'Measure'
											 
											OPEN AddColumnValue_Cursor
											FETCH NEXT FROM AddColumnValue_Cursor INTO @ObjectType, @ColumnName, @EqualityString, @InputValue

											WHILE @@FETCH_STATUS = 0
												BEGIN
													SET @CommentYN = CASE WHEN @ObjectType IS NULL AND @ColumnName = 'Comment' THEN 1 ELSE 0 END
													
													IF LEN(@InputValue) > 0
														SET @InputValue = REPLACE(@InputValue, ',', '.')

													IF @CommentYN <> 0
														SET @Measure_Text = @InputValue
													ELSE
														SET @Measure_Value = @InputValue

													IF @DebugBM & 2 > 0
														SELECT 
															[@ObjectType] = @ObjectType, [@ColumnName] = @ColumnName, [@EqualityString] = @EqualityString, 
															[@InputValue] = @InputValue, [@MeasureValue] = @MeasureValue

													IF @CommentYN <> 0 
														BEGIN
															SET @FACT_DataClass_InsertCallisto_Measure_Text = CHAR(13) + CHAR(10) + CHAR(9) + '[' + @MeasureName + '_Text]'
															SET @FACT_DataClass_SelectCallisto_Measure_Text = CHAR(13) + CHAR(10) + CHAR(9) + '[' + @MeasureName + '_Text] = ''' + @Measure_Text + ''''
														END
													ELSE
														SET @FACT_DataClass_InsertCallisto_Measure_Value = CHAR(13) + CHAR(10) + CHAR(9) + '[' + @MeasureName + '_Value]'
														SET @FACT_DataClass_SelectCallisto_Measure_Value = CHAR(13) + CHAR(10) + CHAR(9) + '[' + @MeasureName + '_Value] = ' + @Measure_Value

													IF @DebugBM & 2 > 0 
														BEGIN
															SELECT [@FACT_DataClass_InsertCallisto_Measure_Value] = @FACT_DataClass_InsertCallisto_Measure_Value
															SELECT [@FACT_DataClass_SelectCallisto_Measure_Value] = @FACT_DataClass_SelectCallisto_Measure_Value
															SELECT [@FACT_DataClass_InsertCallisto_Measure_Text] = @FACT_DataClass_InsertCallisto_Measure_Text
															SELECT [@FACT_DataClass_SelectCallisto_Measure_Text] = @FACT_DataClass_SelectCallisto_Measure_Text
														END

													FETCH NEXT FROM AddColumnValue_Cursor INTO  @ObjectType, @ColumnName, @EqualityString, @InputValue
												END

										CLOSE AddColumnValue_Cursor
										DEALLOCATE AddColumnValue_Cursor

									END
							END --IF LEN(@MeasureValue) > 3

					SET @Step = 'Create initial SQL Statements for temp tables'
						IF @ResultTypeBM & 4 > 0
							BEGIN

	SET @SQLStatement = '
		INSERT INTO #FACT_DataClass_MemberKey
			(' + @FACT_DataClass_MemberKey_InsertCallisto + @FACT_DataClass_InsertCallisto_Measure_Value + '
			)
		SELECT' + @FACT_DataClass_MemberKey_SelectCallisto + @FACT_DataClass_SelectCallisto_Measure_Value 

	IF @DebugBM & 2 > 0 PRINT '
						>>>>>>>>>INSERT INTO FACT_DataClass_MemberKey (Value):	' + @SQLStatement
	EXEC(@SQLStatement)

	SET @SQLStatement = '
		INSERT INTO #FACT_DataClass_MemberKey
			(' + @FACT_DataClass_MemberKey_InsertCallisto + @FACT_DataClass_InsertCallisto_Measure_Text + '
			)
		SELECT' + @FACT_DataClass_MemberKey_SelectCallisto + @FACT_DataClass_SelectCallisto_Measure_Text 

	IF @DebugBM & 2 > 0 PRINT '
						>>>>>>>>>INSERT INTO FACT_DataClass_MemberKey (Text):	' + @SQLStatement
	EXEC(@SQLStatement)

	SET @Selected = @Selected + @@ROWCOUNT
								
							END

					IF @DebugBM & 2 > 0 SELECT '>>>>>>>>> END LOOP: FETCH NEXT FROM DataClass_Data_Cursor'		
						FETCH NEXT FROM DataClass_Data_Cursor INTO  @Filter, @MeasureValue
				END

		CLOSE DataClass_Data_Cursor
		DEALLOCATE DataClass_Data_Cursor
	
		IF @DebugBM & 32 > 0 SELECT [TempTable_#FACT_DataClass_MemberKey] =  '#FACT_DataClass_MemberKey', * FROM #FACT_DataClass_MemberKey
	
	SET @Step = 'Fill temp table #FACT_DataClass_MemberId'
		SELECT
			@FACT_DataClass_MemberId_JoinCallisto = '',
			@FACT_DataClass_MemberId_DeleteCallisto = ''

		--Loop #ObjectListMaster dimensions
		IF CURSOR_STATUS('global','ObjectLM_Cursor') >= -1 DEALLOCATE ObjectLM_Cursor
		DECLARE ObjectLM_Cursor CURSOR FOR
			SELECT DISTINCT 
				[ColumnName] = [ObjectName]
			FROM
				#ObjectListMaster
			WHERE
				[ObjectType] = 'Dimension'
			ORDER BY
				[ObjectName]

			OPEN ObjectLM_Cursor
			FETCH NEXT FROM ObjectLM_Cursor INTO @ColumnName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					--IF @DebugBM & 2> 0 SELECT [@ColumnName] = @ColumnName

					SELECT
						@FACT_DataClass_MemberId_InsertCallisto = @FACT_DataClass_MemberId_InsertCallisto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + @ColumnName + '_MemberId],',
						@FACT_DataClass_MemberId_SelectCallisto = @FACT_DataClass_MemberId_SelectCallisto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + @ColumnName + '_MemberId] = ISNULL([' + @ColumnName + '].[MemberId], -1),',
						@FACT_DataClass_MemberId_JoinCallisto = @FACT_DataClass_MemberId_JoinCallisto + CHAR(13) + CHAR(10) + CHAR(9) + 'LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + @ColumnName + '] [' + @ColumnName + '] ON [' + @ColumnName + '].[Label] = [#FACT_DataClass_MemberKey].[' + @ColumnName + ']'
													
					IF @ColumnName NOT IN ('GL_Posted', 'WorkflowState')	
						SET @FACT_DataClass_MemberId_DeleteCallisto = @FACT_DataClass_MemberId_DeleteCallisto + CHAR(13) + CHAR(10) + CHAR(9) + '[#FACT_DataClass_MemberId].[' + @ColumnName + '_MemberId] = F.[' + @ColumnName + '_MemberId] AND'
							
					FETCH NEXT FROM ObjectLM_Cursor INTO  @ColumnName
				END

		CLOSE ObjectLM_Cursor
		DEALLOCATE ObjectLM_Cursor

		IF @DebugBM & 2 > 0 PRINT '
							>>>>>>>>>@FACT_DataClass_MemberId_JoinCallisto:	' + @FACT_DataClass_MemberId_JoinCallisto
		
		IF LEN(@FACT_DataClass_MemberId_DeleteCallisto) > 4 
			SET @FACT_DataClass_MemberId_DeleteCallisto = SUBSTRING(@FACT_DataClass_MemberId_DeleteCallisto, 1, LEN(@FACT_DataClass_MemberId_DeleteCallisto) - 4)

		IF @DebugBM & 2 > 0 PRINT '
							>>>>>>>>>@FACT_DataClass_MemberId_DeleteCallisto:	' + @FACT_DataClass_MemberId_DeleteCallisto

	SET @Step = 'Fill temp table #FACT_DataClass_MemberId'
		SET @SQLStatement = '
			INSERT INTO #FACT_DataClass_MemberId
				(' + @FACT_DataClass_MemberId_InsertCallisto + @FACT_DataClass_InsertCallisto_Measure_Value + '
				)
			SELECT' + @FACT_DataClass_MemberId_SelectCallisto + @FACT_DataClass_InsertCallisto_Measure_Value + '
			FROM
				#FACT_DataClass_MemberKey [#FACT_DataClass_MemberKey] ' + @FACT_DataClass_MemberId_JoinCallisto + '
			WHERE
				[#FACT_DataClass_MemberKey].[' + @MeasureName + '_Value] IS NOT NULL '

		IF @DebugBM & 2 > 0 PRINT '
							>>>>>>>>>INSERT INTO #FACT_DataClass_MemberId (Measure_Value):	' + @SQLStatement
		EXEC(@SQLStatement)

		SET @Selected = @Selected + @@ROWCOUNT

		SET @SQLStatement = '
			INSERT INTO #FACT_DataClass_MemberId
				(' + @FACT_DataClass_MemberId_InsertCallisto + @FACT_DataClass_InsertCallisto_Measure_Text + '
				)
			SELECT' + @FACT_DataClass_MemberId_SelectCallisto + @FACT_DataClass_InsertCallisto_Measure_Text + '
			FROM
				#FACT_DataClass_MemberKey [#FACT_DataClass_MemberKey] ' + @FACT_DataClass_MemberId_JoinCallisto + '
			WHERE
				[#FACT_DataClass_MemberKey].[' + @MeasureName + '_Text] IS NOT NULL'

		IF @DebugBM & 2 > 0 PRINT '
							>>>>>>>>>INSERT INTO #FACT_DataClass_MemberId (Measure_Text):	' + @SQLStatement
		EXEC(@SQLStatement)

		SET @Selected = @Selected + @@ROWCOUNT

		IF @DebugBM & 32 > 0 SELECT [TempTable_#FACT_DataClass_MemberId] =  '#FACT_DataClass_MemberId', * FROM #FACT_DataClass_MemberId
		IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase, [@FACT_DataClass_Table] = @FACT_DataClass_Table

	SET @Step = 'Delete & Insert into FACT_Text table where Lineitem = NONE'
		IF @FACT_DataClass_Text_Table_ExistsYN <> 0 AND @FACT_DataClass_Text_Table_LI_ExistsYN <> 0
			BEGIN 
				SET @SQLStatement = '
					DELETE F
					FROM
						' + @CallistoDatabase + '.[dbo].[' + @FACT_DataClass_Text_Table + '] F
						INNER JOIN #FACT_DataClass_MemberId [#FACT_DataClass_MemberId_LI] ON [#FACT_DataClass_MemberId_LI].[LineItem_MemberId] = -1 AND [#FACT_DataClass_MemberId_LI].[' + @MeasureName + '_Text] IS NOT NULL
						INNER JOIN #FACT_DataClass_MemberId [#FACT_DataClass_MemberId] ON ' + @FACT_DataClass_MemberId_DeleteCallisto
		
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				SELECT @Deleted = @Deleted + @@ROWCOUNT

				SET @SQLStatement = '
					INSERT INTO ' + @CallistoDatabase + '.[dbo].[' + @FACT_DataClass_Text_Table + ']
						(' + @FACT_DataClass_MemberId_InsertCallisto + '
						ChangeDatetime,
						UserID,' + @FACT_DataClass_InsertCallisto_Measure_Text + '
						)													
					SELECT' + @FACT_DataClass_MemberId_InsertCallisto + '
						ChangeDatetime = GetDate(),
						UserID = ''' + CONVERT(nvarchar(15), @UserID) + ''',' + @FACT_DataClass_InsertCallisto_Measure_Text + '
					FROM
						#FACT_DataClass_MemberId
					WHERE
						[LineItem_MemberId] = -1 AND
						[' + @MeasureName + '_Text] IS NOT NULL'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)	

				SELECT @Inserted = @Inserted + @@ROWCOUNT
			END
		
	SET @Step = 'Update #FACT_DataClass_MemberKey with SendTo values (dimensions with SendTo property)'
		SELECT
			@FACT_DataClass_MemberKey_UpdateSendTo = '',
			@FACT_DataClass_MemberKey_JoinSendTo = ''

		--Fill temp table #SendTo_Dimensions
		SET @SQLStatement = '
			INSERT INTO #SendTo_Dimensions
				(
				[Dimension]
				)
			SELECT DISTINCT
				[Dimension] = O.ObjectName
			FROM
				' + @CallistoDatabase + '.sys.tables t 
				INNER JOIN ' + @CallistoDatabase + '.sys.columns c ON c.[object_id] = t.[object_id] AND c.[name] = ''SendTo''
				INNER JOIN #ObjectListMaster O ON O.ObjectType = ''Dimension'' AND O.ObjectName = REPLACE(t.[name], ''S_DS_'', '''')
			WHERE t.[name] LIKE ''S_DS_%'''
			
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [#SendTo_Dimensions] = '#SendTo_Dimensions', * FROM #SendTo_Dimensions

		--Loop Callisto dimensions with SendTo property
		IF CURSOR_STATUS('global','Dim_SendTo_Cursor') >= -1 DEALLOCATE Dim_SendTo_Cursor
		DECLARE Dim_SendTo_Cursor CURSOR FOR
			SELECT  
				[ColumnName] = [Dimension]
			FROM
				 #SendTo_Dimensions
			ORDER BY
				[Dimension]

			OPEN Dim_SendTo_Cursor
			FETCH NEXT FROM Dim_SendTo_Cursor INTO @ColumnName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2> 0 SELECT [@ColumnName] = @ColumnName

					SELECT
						@FACT_DataClass_MemberKey_UpdateSendTo = @FACT_DataClass_MemberKey_UpdateSendTo + CHAR(13) + CHAR(10) + CHAR(9) + '[' + @ColumnName + '_MemberId] = COALESCE([' + @ColumnName + '].[SendTo_MemberId], [#FACT_DataClass_MemberId].[' + @ColumnName + '_MemberId], -1),',
						@FACT_DataClass_MemberKey_JoinSendTo = @FACT_DataClass_MemberKey_JoinSendTo + CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + @ColumnName + '] [' + @ColumnName + '] ON [' + @ColumnName + '].[MemberId] = [#FACT_DataClass_MemberId].[' + @ColumnName + '_MemberId]'

					FETCH NEXT FROM Dim_SendTo_Cursor INTO  @ColumnName
				END

		CLOSE Dim_SendTo_Cursor
		DEALLOCATE Dim_SendTo_Cursor

		IF @DebugBM & 2 > 0 PRINT '
							>>>>>>>>>@FACT_DataClass_MemberKey_UpdateSendTo:	' + @FACT_DataClass_MemberKey_UpdateSendTo		
		
		IF LEN(@FACT_DataClass_MemberKey_UpdateSendTo) > 1
			SET @FACT_DataClass_MemberKey_UpdateSendTo = SUBSTRING(@FACT_DataClass_MemberKey_UpdateSendTo, 1, LEN(@FACT_DataClass_MemberKey_UpdateSendTo) - 1)

		IF @DebugBM & 2 > 0 PRINT '
							>>>>>>>>>@FACT_DataClass_MemberKey_JoinSendTo:	' + @FACT_DataClass_MemberKey_JoinSendTo
							
		--Update #FACT_DataClass_MemberKey
		SET @SQLStatement = '
			UPDATE [#FACT_DataClass_MemberId]
			SET ' + @FACT_DataClass_MemberKey_UpdateSendTo + '
			FROM 
				#FACT_DataClass_MemberId [#FACT_DataClass_MemberId] ' + @FACT_DataClass_MemberKey_JoinSendTo

			IF @DebugBM & 2 > 0 PRINT '
							>>>>>>>>>Update #FACT_DataClass_MemberId:	' + @SQLStatement
			EXEC(@SQLStatement)

			IF @DebugBM & 32 > 0 SELECT [TempTable_#FACT_DataClass_MemberKey_UpdateSendTo] =  '#FACT_DataClass_MemberId', * FROM #FACT_DataClass_MemberId

	SET @Step = 'Update BusinessProcess (LineItem <> NONE AND BusinessProcess <> INPUT_Capex'
		IF @LineItem_ExistsYN <> 0
			BEGIN 
				SET @SQLStatement = '
					UPDATE F
					SET 
						[BusinessProcess_MemberId] = 118 --LineItem BP
					FROM
						#FACT_DataClass_MemberId F
						INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessProcess] BP ON BP.[MemberId] = F.[BusinessProcess_MemberId] AND BP.[Label] NOT IN (''INPUT_Capex'',''DEPR_YEAR'',''Capex_Display'')
					WHERE
						F.[LineItem_MemberId] <> -1'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)	
			END

		IF @DebugBM & 32 > 0 SELECT [TempTable_#FACT_DataClass_MemberId] =  '#FACT_DataClass_MemberId', * FROM #FACT_DataClass_MemberId

	SET @Step = 'Delete row from Callisto (Measure_Value)'
		IF @FACT_DataClass_Table_ExistsYN <> 0
			BEGIN 
				SET @SQLStatement = '
					DELETE F
					FROM
						' + @CallistoDatabase + '.[dbo].[' + @FACT_DataClass_Table + '] F
						INNER JOIN #FACT_DataClass_MemberId [#FACT_DataClass_MemberId_Value] ON [#FACT_DataClass_MemberId_Value].[' + @MeasureName + '_Value] IS NOT NULL
						INNER JOIN #FACT_DataClass_MemberId [#FACT_DataClass_MemberId] ON ' + @FACT_DataClass_MemberId_DeleteCallisto
		
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				SELECT @Deleted = @Deleted + @@ROWCOUNT
			END 

	SET @Step = 'Delete row from Callisto (Measure_Text)'
		IF @FACT_DataClass_Text_Table_ExistsYN <> 0 AND @LineItem_ExistsYN <> 0
			BEGIN 
				SET @SQLStatement = '
					DELETE F
					FROM
						' + @CallistoDatabase + '.[dbo].[' + @FACT_DataClass_Text_Table + '] F
						INNER JOIN #FACT_DataClass_MemberId [#FACT_DataClass_MemberId_LI] ON [#FACT_DataClass_MemberId_LI].[LineItem_MemberId] <> -1 AND [#FACT_DataClass_MemberId_LI].[' + @MeasureName + '_Text] IS NOT NULL
						INNER JOIN #FACT_DataClass_MemberId [#FACT_DataClass_MemberId] ON ' + @FACT_DataClass_MemberId_DeleteCallisto
		
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				SELECT @Deleted = @Deleted + @@ROWCOUNT
			END 

	SET @Step = 'Insert into Callisto (Measure_Value)'
		IF @DebugBM & 2 > 0 PRINT '@FACT_DataClass_MemberId_InsertCallisto' +  @FACT_DataClass_MemberId_InsertCallisto
		IF @DebugBM & 2 > 0 PRINT '@FACT_DataClass_InsertCallisto_Measure_Value' +  @FACT_DataClass_InsertCallisto_Measure_Value

		IF @FACT_DataClass_Table_ExistsYN <> 0
			BEGIN 
				SET @SQLStatement = '
					INSERT INTO ' + @CallistoDatabase + '.[dbo].[' + @FACT_DataClass_Table + ']
						(' + @FACT_DataClass_MemberId_InsertCallisto + '
						ChangeDatetime,
						UserID,' + @FACT_DataClass_InsertCallisto_Measure_Value + '
						)													
					SELECT' + @FACT_DataClass_MemberId_InsertCallisto + '
						ChangeDatetime = GetDate(),
						UserID = ''' + CONVERT(nvarchar(15), @UserID) + ''',' + @FACT_DataClass_InsertCallisto_Measure_Value + '
					FROM
						#FACT_DataClass_MemberId
					WHERE
						' + @MeasureName + '_Value IS NOT NULL'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				SELECT @Inserted = @Inserted + @@ROWCOUNT
			END 

	SET @Step = 'Insert into Callisto (Measure_Text) '
		IF @DebugBM & 2 > 0 PRINT '@FACT_DataClass_MemberId_InsertCallisto' +  @FACT_DataClass_MemberId_InsertCallisto
		IF @DebugBM & 2 > 0 PRINT '@FACT_DataClass_InsertCallisto_Measure_Text' +  @FACT_DataClass_InsertCallisto_Measure_Text

		IF  @FACT_DataClass_Text_Table_ExistsYN <> 0 AND @LineItem_ExistsYN <> 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO ' + @CallistoDatabase + '.[dbo].[' + @FACT_DataClass_Text_Table + ']
						(' + @FACT_DataClass_MemberId_InsertCallisto + '
						ChangeDatetime,
						UserID,' + @FACT_DataClass_InsertCallisto_Measure_Text + '
						)													
					SELECT' + @FACT_DataClass_MemberId_InsertCallisto + '
						ChangeDatetime = GetDate(),
						UserID = ''' + CONVERT(nvarchar(15), @UserID) + ''',' + @FACT_DataClass_InsertCallisto_Measure_Text + '
					FROM
						#FACT_DataClass_MemberId
					WHERE
						[LineItem_MemberId] <> -1 AND
						[' + @MeasureName + '_Text] IS NOT NULL'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				SELECT @Inserted = @Inserted + @@ROWCOUNT
			END 

	SET @Step = 'Drop temp tables'
		DROP TABLE [#ObjectListMaster]
		DROP TABLE [#Data_Cursor_Table]
		DROP TABLE [#Dummy]
		DROP TABLE [#SendTo_Dimensions]
		DROP TABLE [#FACT_DataClass_MemberId]
		DROP TABLE [#FACT_DataClass_MemberKey]
		IF @CalledYN = 0 DROP TABLE #PipeStringSplit

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
