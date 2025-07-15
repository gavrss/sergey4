SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
Create PROCEDURE [dbo].[spPortalSet_DataClass_Data_Table_20230105]
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
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
TODO: for CAPEX, it should be possible to set BP='Input_CAPEX' with LineItem details, and this rule must be tested with different cases

EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DataClass_Data_Table] @DataClassID='5713',@InstanceID='572',@UserID='9863',@VersionID='1080',@DebugBM=15,
@JSON_table='
[{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202206|Scenario=Forecast1|Entity=US01|Currency=USD|Account=8741|GL_CostCenter=07|GL_Branch=807|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE|Measure=Comment", "MeasureValue" : "Comment=eyJtZXNzYWdlIjoiVGVzdGluZyIsInVzZXIiOjk4NjMsImRhdGUiOjE2NTM5Nzg0NzA3Njd9"}]
'

EXEC [spRun_Procedure_KeyValuePair] @ProcedureName='spPortalSet_DataClass_Data_Table', @JSON='[{"TKey" : "DebugBM", "TValue" : "15"},
{"TKey" : "UserID", "TValue" : "9863"},{"TKey" : "InstanceID", "TValue" : "572"},{"TKey" : "VersionID", "TValue" : "1080"},
{"TKey" : "DataClassID", "TValue" : "5713"},{"TKey" : "WorkflowStateID", "TValue" : "9475"},{"TKey" : "AssignmentID", "TValue" : "18895"}
]', @JSON_table='[
{"Filter" : "FixedAsset=NONE|Group=NONE|Flow=NONE|Supplier=NONE|Customer=NONE|Time=202205|Scenario=Forecast1|Entity=AU03|Currency=AUD|Account=8741|GL_CostCenter=07|GL_Branch=229|BusinessProcess=INPUT|BusinessRule=NONE|GL_Posted=TRUE|LineItem=NONE|TimeDataView=RAWDATA|Version=NONE", "MeasureValue" : "Financials=100.0"}]'

EXEC spPortalSet_DataClass_Data_Table @AssignmentID='17045',@DataClassID='1028',@InstanceID='413',@UserID='3806',@VersionID='1008',@WorkflowStateID='8520',
@JSON_table='[{"Filter" : "Time=202104|Scenario=BUDGET|Entity=52982|Currency=USD|GL_Department=IT30|Account=652500|BusinessProcess=INPUT|GL_Project=All_", 
"MeasureValue" : "Financials=0"}]',@DebugBM=3

EXEC spRun_Procedure_KeyValuePair @ProcedureName='spPortalSet_DataClass_Data_Table',
@JSON='[{"TKey" : "UserID", "TValue" : "7564"},{"TKey" : "InstanceID", "TValue" : "454"},{"TKey" : "VersionID", "TValue" : "1021"},
{"TKey" : "DataClassID", "TValue" : "4977"},{"TKey" : "WorkflowStateID", "TValue" : "6812"},{"TKey" : "Debug", "TValue" : "1"}]'
,@JSON_table='
[{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201901|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201902|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201903|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201904|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201905|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201906|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201907|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201908|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201909|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201910|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201911|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"},{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|LineItem=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201912|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=503220|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Financials=30888.64"}]
'

@DataClassID='4977',@InstanceID='454',@UserID='7564',@VersionID='1021'
,@WorkflowStateID='6812'

EXEC spRun_Procedure_KeyValuePair @ProcedureName='spPortalSet_DataClass_Data_Table',
@JSON='[{"TKey" : "UserID", "TValue" : "7564"},{"TKey" : "InstanceID", "TValue" : "454"},{"TKey" : "VersionID", "TValue" : "1021"},{"TKey" : "DataClassID", "TValue" : "4977"},{"TKey" : "Debug", "TValue" : "1"}]'
,@JSON_table='[
{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201908|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=532220|GL_Cost_Center=380|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Comment=UpdateComment3"}]'


--JSON table sample--
--=================--
DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"Filter" : "BusinessProcess=INPUT|BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201809|Scenario=F2|Entity=R520|Currency=USD|Account=550300|GL_Cost_Center=510|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue": "Financials=21050.00"},
	{"Filter" : "LineItem=01|BusinessProcess=NONE|BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201809|Scenario=F2|Entity=R520|Currency=USD|Account=550300|GL_Cost_Center=510|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue": "Financials=2300.00|Comment=UpdateComment21"},
	{"Filter" : "LineItem=02|BusinessProcess=NONE|BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201809|Scenario=F2|Entity=R520|Currency=USD|Account=550300|GL_Cost_Center=510|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue": "Financials=2350.00|Comment=UpdateComment22"},
	{"Filter" : "LineItem=03|BusinessProcess=NONE|BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201809|Scenario=F2|Entity=R520|Currency=USD|Account=550300|GL_Cost_Center=510|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue": "Financials=2400.00|Comment=UpdateComment23"}
	]'

EXEC [dbo].[spPortalSet_DataClass_Data_Table_New] 
	@UserID = 9631,
	@InstanceID = 454,
	@VersionID = 1021,
	@DataClassID = 5153,
	@JSON_table = @JSON_table,
	@Debug = 1

DECLARE	@JSON_table_Value nvarchar(MAX) = '
	[
	{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201908|Scenario=BUDGET|Entity=R510|Currency=CAD|BusinessProcess=INPUT|Account=532220|GL_Cost_Center=380|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue" : "Comment=UpdateComment3"}
	]'
EXEC spPortalSet_DataClass_Data_Table @DataClassID='4977',@InstanceID='454',@UserID='7564',@VersionID='1021',@JSON_table=@JSON_table_Value,@Debug=1

-----
DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"Filter" : "BusinessProcess=NONE|BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Time=201908|Scenario=F2|Entity=R520|Currency=USD|Account=550300|GL_Cost_Center=510|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000", "MeasureValue": "Financials=3000.00|Comment=AddCommentHere1"}
	]'

EXEC [dbo].[spPortalSet_DataClass_Data_Table] 
	@UserID = 8345,
	@InstanceID = 454,
	@VersionID = 1021,
	@DataClassID = 5153,
	@JSON_table = @JSON_table,
	@Debug = 1

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

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName='spPortalSet_DataClass_Data_Table',@JSON='[{"TKey" : "UserID", "TValue" : "8346"},{"TKey" : "InstanceID", "TValue" : "454"},{"TKey" : "VersionID", "TValue" : "1021"},{"TKey" : "DataClassID", "TValue" : "5153"},{"TKey" : "Debug", "TValue" : "1"}]',
	@JSON_table='[{"Filter" : "WorkflowState=NONE|BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Scenario=BUDGET|Entity=R520|Currency=USD|BusinessProcess=INPUT|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000|Time=201901|Account=548216", "MeasureValue" : "Financials=1000.0"}]'

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName='spPortalSet_DataClass_Data_Table',@JSON='[{"TKey" : "UserID", "TValue" : "8346"},{"TKey" : "InstanceID", "TValue" : "454"},{"TKey" : "VersionID", "TValue" : "1021"},{"TKey" : "DataClassID", "TValue" : "5153"}, {"TKey" : "WorkflowStateID", "TValue" : "6810"}, {"TKey" : "Debug", "TValue" : "1"}]',
	@JSON_table='[{"Filter" : "BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Scenario=BUDGET|Entity=R520|Currency=USD|BusinessProcess=INPUT|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000|Time=201901|Account=548216", "MeasureValue" : "Financials=1000.0"}]'

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName='spPortalSet_DataClass_Data_Table',@JSON='[{"TKey" : "UserID", "TValue" : "8346"},{"TKey" : "InstanceID", "TValue" : "454"},{"TKey" : "VersionID", "TValue" : "1021"},{"TKey" : "DataClassID", "TValue" : "5153"}, {"TKey" : "AssignmentID", "TValue" : "12402"}, {"TKey" : "Debug", "TValue" : "1"}]',
	@JSON_table='[{"Filter" : "BusinessRule=NONE|Version=NONE|TimeDataView=RAWDATA|Scenario=BUDGET|Entity=R520|Currency=USD|BusinessProcess=INPUT|GL_Cost_Center=100|GL_Product_Category=000|GL_Project=NONE|GL_Trading_Partner=000|Time=201901|Account=548216", "MeasureValue" : "Financials=1000.0"}]'


EXEC [spPortalSet_DataClass_Data_Table] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ApplicationID INT,
	@Filter NVARCHAR(4000),
	@MeasureValue NVARCHAR(4000),

	@SQLStatement NVARCHAR(MAX),
	@UsedValue NVARCHAR(4000),
	@MemberId_List NVARCHAR(4000),
	@SQLWhereClause NVARCHAR(MAX) = '',
	@SQLWhereDeleteClause NVARCHAR(MAX) = '',
	@SQLInsertClause NVARCHAR(MAX) = '',
	@SQLSelectClause NVARCHAR(MAX) = '',
	@SQLJoin_UpdateCallisto_Measure NVARCHAR(MAX) = '',
	@SQLJoin_UpdateCallisto_Comment NVARCHAR(MAX) = '',
	@SQLJoin_InsertCallisto_Measure NVARCHAR(MAX) = '',
	@SQLJoin_InsertCallisto_Comment NVARCHAR(MAX) = '',
	@SQLSelect_InsertCallisto NVARCHAR(MAX) = '',
	@SQLSelect_InsertCallistoText NVARCHAR(MAX) = '',
	@SQLSetClause NVARCHAR(1000) = '',
	@MeasureValue_Value NVARCHAR (4000) = '',
	@Comment NVARCHAR(4000) = '',
	@CharIndex INT, 
	@DimFilter NVARCHAR(2000),
	@FilterLen INT,
	@EqualSignPos INT,
	@ObjectName NVARCHAR(100),
	@InputValue NVARCHAR(4000),
	@StorageTypeBM_Dimension INT,
	@StorageTypeBM_DataClass INT,
	@DataClassName NVARCHAR(100),
	@DataClassTypeID INT,
	@InstanceID_String NVARCHAR(10),
	@DimensionDistinguishing NVARCHAR(20),
	@DestinationDatabase NVARCHAR(100),
	@ETLDatabase NVARCHAR(100),
	@CallistoDatabase NVARCHAR(100),
	@MissingDimension NVARCHAR(1000) = '',
	@InitialWorkflowStateID INT,
	@StepWorkflowState_MemberId BIGINT,
	@StepWorkflowState_MemberKey NVARCHAR(100),
	@InitialWorkflowStateMemberKey NVARCHAR(100),
	@WorkflowStateMemberKey NVARCHAR(100),
	@ReturnVariable INT,
	@HierarchyNo INT = 0,
	@Account_MaxHierarchyNo INT = 0,


	@ObjectType NVARCHAR(20),
	@Inserted_Check INT,
	@Deleted_Check INT,
	@Updated_Check INT,
	@ResultTypeBM INT = 4,
	@CalledYN BIT = 1,
	@MeasureYN BIT = 0,
	@CommentYN BIT = 0,
	@LineItemYN BIT = 0,
	@FACT_DataClass_Table NVARCHAR(100),
	@FACT_DataClass_Text_Table NVARCHAR(100),
	@LineItemBP INT,
	@AuditLogYN BIT = 0,
	@FromNum FLOAT,
	@FromText NVARCHAR(4000),

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
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
	@Version NVARCHAR(50) = '2.1.2.2182'

IF @GetVersion <> 0
	BEGIN
		SELECT
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

		SELECT @UserName = UserName FROM [User] WHERE UserID = @UserID
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT 
			@ApplicationID = ISNULL(@ApplicationID , MAX(ApplicationID))
		FROM 
			[Application] 
		WHERE 
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND 
			SelectYN <> 0
				
		SELECT 
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = ETLDatabase 
		FROM 
			[Application] 
		WHERE 
			ApplicationID = @ApplicationID

		IF @DebugBM & 2 > 0 SELECT [@ApplicationID] = @ApplicationID, [@CallistoDatabase] = @CallistoDatabase, [@ETLDatabase] = @ETLDatabase

		SELECT
			@DataClassName = DataClassName,
			@DataClassTypeID = DataClassTypeID,
			@StorageTypeBM_DataClass = StorageTypeBM,
			@InstanceID_String = CASE LEN(@InstanceID) WHEN 1 THEN '000' WHEN 2 THEN '00' WHEN 3 THEN '0' ELSE '' END + CONVERT(NVARCHAR(10), @InstanceID)
		FROM
			[DataClass]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassID = @DataClassID

		SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM ' + @CallistoDatabase + '.sys.tables WHERE [name] = ''AUDIT_' + @DataClassName + '_num'''
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @AuditLogYN OUT

		SET @DimensionDistinguishing = CASE WHEN @StorageTypeBM_DataClass & 4 > 0 THEN '_MemberId' ELSE '_MemberKey' END

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
				[@InitialWorkflowStateID] = @InitialWorkflowStateID,
				[@InitialWorkflowStateMemberKey] = @InitialWorkflowStateMemberKey,
				[@WorkflowStateID] = @WorkflowStateID,
				[@WorkflowStateMemberKey] = @WorkflowStateMemberKey,
				[@AuditLogYN] = @AuditLogYN,
				[@Account_MaxHierarchyNo] = @Account_MaxHierarchyNo

	SET @Step = 'Create temp table #ObjectList'	
		CREATE TABLE #ObjectList
			(
			[ObjectType] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[ObjectID] INT,
			[ObjectName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] INT,
			[IncludedYN] BIT,
			[SortOrder] INT,
			[InputValue] NVARCHAR(4000) COLLATE DATABASE_DEFAULT,
			[MeasureValue] NVARCHAR(4000) COLLATE DATABASE_DEFAULT,
			[CommentValue] NVARCHAR(4000) COLLATE DATABASE_DEFAULT,
			)
	
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

		INSERT INTO #ObjectListMaster
			(
			[ObjectType],
			[ObjectID],
			[ObjectName],
			[StorageTypeBM],
			[IncludedYN],
			[DefaultValue],
			[SortOrder]
			)
		SELECT DISTINCT
			[ObjectType] = 'Dimension' COLLATE DATABASE_DEFAULT,
			[ObjectID] = -63,
			[ObjectName] = 'WorkflowState' COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] = 4,
			[IncludedYN] = 0,
			[DefaultValue] = COALESCE(@WorkflowStateMemberKey, @InitialWorkflowStateMemberKey, 'NONE'),
			[SortOrder] = 9999
		WHERE
			@WorkFlowStateID IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM #ObjectListMaster D WHERE D.ObjectID = -63)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ObjectListMaster', * FROM #ObjectListMaster

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
					IF @DebugBM & 2 > 0 SELECT [Filter] = @Filter, [MeasureValue] = @MeasureValue

					SET @FACT_DataClass_Table = 'FACT_' + @DataClassName + '_default_partition'
					SET @FACT_DataClass_Text_Table = 'FACT_' + @DataClassName + '_Text'

					SELECT 	@SQLWhereClause = '', @SQLWhereDeleteClause = '', @SQLInsertClause = '', @SQLSelectClause = '', @SQLJoin_UpdateCallisto_Measure = '', @SQLJoin_UpdateCallisto_Comment = '', @SQLJoin_InsertCallisto_Measure = '', @SQLJoin_InsertCallisto_Comment = '', @SQLSelect_InsertCallisto  = '', @SQLSelect_InsertCallistoText = '', @SQLSetClause = '', @Comment = ''
					TRUNCATE TABLE #ObjectList
					INSERT INTO #ObjectList
						(
						[ObjectType],
						[ObjectID],
						[ObjectName],
						[StorageTypeBM],
						[IncludedYN],
						[SortOrder],
						[InputValue]
						)
					SELECT
						[ObjectType],
						[ObjectID],
						[ObjectName],
						[StorageTypeBM],
						[IncludedYN],
						[SortOrder],
						[InputValue] = [DefaultValue]
					FROM
						#ObjectListMaster
					
					SET @Step = 'Update column InputValue in temptable #ObjectList (Based on @Filter)'
						IF LEN(@Filter) > 3
							BEGIN
								TRUNCATE TABLE #PipeStringSplit

								EXEC [spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @Filter, @Debug = 0

								UPDATE OL
								SET
									[InputValue] = PSS.[PipeFilter]
								FROM
									#ObjectList OL
									INNER JOIN #PipeStringSplit PSS ON PSS.PipeObject = OL.[ObjectName]
								WHERE OL.[ObjectType] = 'Dimension'

								INSERT INTO #ObjectList
									(
									[ObjectType],
									[ObjectID],
									[ObjectName],
									[StorageTypeBM],
									[IncludedYN],
									[SortOrder],
									[InputValue]
									)
								SELECT
									[ObjectType] = 'Dimension',
									[ObjectID] = D.DimensionID,
									[ObjectName] = PSS.[PipeObject],
									[StorageTypeBM] = DST.StorageTypeBM,
									[IncludedYN] = 0,
									[SortOrder] = 999,
									[InputValue] = PSS.[PipeFilter]
								FROM
									#PipeStringSplit PSS
									INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = PSS.[PipeObject]
									INNER JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = D.DimensionID
									INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = DST.InstanceID AND DCD.VersionID = DST.VersionID AND DCD.DataClassID = @DataClassID AND DCD.DimensionID = DST.DimensionID
								WHERE
									NOT EXISTS (SELECT 1 FROM #ObjectList OL WHERE [ObjectType] = 'Dimension' AND OL.[ObjectID] = D.DimensionID AND OL.ObjectName = PSS.[PipeObject])

								SET @Inserted_Check = @@ROWCOUNT
								IF @Inserted_Check > 0
									BEGIN	
										IF
										(SELECT
											COUNT(1)
										FROM
											#PipeStringSplit PSS
											INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = PSS.[PipeObject]
											INNER JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = D.DimensionID
										WHERE
											PSS.[PipeObject] = 'LineItem' AND
											NOT EXISTS (SELECT 1 FROM #ObjectListMaster OL WHERE [ObjectType] = 'Dimension' AND OL.[ObjectID] = D.DimensionID AND OL.ObjectName = PSS.[PipeObject])) > 0

										BEGIN
											IF @DebugBM & 2 > 0 SELECT [Info] = 'LineItem added', [@DataClassName] = @DataClassName
											UPDATE #ObjectList
											SET
												[ObjectName] = @DataClassName + '_Detail'
											WHERE
												[ObjectType] = 'Measure' AND
												[ObjectName] = @DataClassName

											SET @FACT_DataClass_Table = 'FACT_' + @DataClassName + '_Detail_default_partition'
											SET @FACT_DataClass_Text_Table = 'FACT_' + @DataClassName + '_Detail_Text'
										END
									END
							END

						UPDATE OL
						SET
							--[InputValue] = COALESCE(OL.[InputValue], @WorkflowStateMemberKey, @InitialWorkflowStateMemberKey, 'NONE')
							[InputValue] = COALESCE(@WorkflowStateMemberKey, OL.[InputValue], @InitialWorkflowStateMemberKey, 'NONE')
						FROM
							#ObjectList OL
						WHERE
							ObjectID = -63

						SELECT
							@MissingDimension = @MissingDimension + [ObjectName] + ', '
						FROM
							#ObjectList
						WHERE
							[ObjectType] = 'Dimension' AND
							[ObjectName] <> 'LineItem' AND
							[InputValue] IS NULL 

						IF LEN(@MissingDimension) > 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT TempTable = '#ObjectList', * FROM #ObjectList ORDER BY ObjectType, SortOrder
								SET @MissingDimension = LEFT(@MissingDimension, LEN(@MissingDimension) - 1)
								SET @Message = 'Missing dimension(s): ' + @MissingDimension
								SET @Severity = 16
								GOTO EXITPOINT
							END

						SELECT
							@StepWorkflowState_MemberKey = [InputValue]
						FROM
							#ObjectList OL
						WHERE
							ObjectID = -63

						EXEC [spGet_MemberInfo] @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = -63, @MemberKey = @StepWorkflowState_MemberKey, @MemberID = @StepWorkflowState_MemberId OUT

					SET @Step = 'Update column InputValue in temptable #ObjectList (Based on @MeasureValue)'
						IF LEN(@MeasureValue) > 3
							BEGIN
								TRUNCATE TABLE #PipeStringSplit

								EXEC [spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @MeasureValue, @Debug = 0

								UPDATE OL
								SET
									[InputValue] = PSS.[PipeFilter]
								FROM
									#ObjectList OL
									INNER JOIN #PipeStringSplit PSS ON PSS.PipeObject = REPLACE(OL.[ObjectName], '_Detail', '')
								WHERE OL.[ObjectType] = 'Measure'

								INSERT INTO #ObjectList
								(
								    ObjectType,
								    ObjectID,
								    ObjectName,
								    StorageTypeBM,
									IncludedYN,
								    SortOrder,
								    InputValue
								)
								SELECT
									ObjectType = PSS.PipeObject,
								    ObjectID = NULL,
								    ObjectName = @DataClassName + '_text',
								    StorageTypeBM = 4,
									IncludedYN = 1,
								    SortOrder = 0,
								    InputValue = PSS.PipeFilter
								FROM
									#PipeStringSplit PSS
								WHERE 
									PSS.[PipeObject] = 'Comment'
							END
						
						IF @DebugBM & 2 > 0 SELECT TempTable = '#ObjectList', * FROM #ObjectList ORDER BY ObjectType, SortOrder

						IF (SELECT COUNT(1) FROM #ObjectList DL WHERE StorageTypeBM & 4 > 0) > 0 OR @StorageTypeBM_DataClass & 4 > 0
							BEGIN
								SELECT @ApplicationID = ISNULL(@ApplicationID , MAX(ApplicationID)) FROM [Application] WHERE InstanceID = @InstanceID AND VersionID = @VersionID-- AND SelectYN <> 0
								SELECT
									@DestinationDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
									@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
								FROM
									[Application] A
								WHERE
									A.ApplicationID = @ApplicationID
								IF @DebugBM & 2 > 0 SELECT ApplicationID = @ApplicationID, DestinationDatabase = @DestinationDatabase, ETLDatabase = @ETLDatabase
							END

					SET @Step = 'Update YN values'
						IF (SELECT COUNT(1) FROM #ObjectList WHERE ObjectType = 'Comment') <> 0 SET @CommentYN = 1 ELSE SET @CommentYN = 0
						IF (SELECT COUNT(1) FROM #ObjectList WHERE ObjectType = 'Measure' AND InputValue IS NOT NULL) <> 0 SET @MeasureYN = 1 ELSE SET @MeasureYN = 0
						IF (SELECT COUNT(1) FROM #ObjectList WHERE ObjectType = 'Dimension' AND ObjectName = 'LineItem') <> 0 SET @LineItemYN = 1 ELSE SET @LineItemYN = 0

						IF @DebugBM & 2 > 0 SELECT [@CommentYN] = @CommentYN, [@MeasureYN] = @MeasureYN, [@LineItemYN] = @LineItemYN

					SET @Step = 'Get LineItem table'
						IF @LineItemYN <> 0
							BEGIN
								SET @SQLStatement = '
									SELECT @internalVariable = COUNT(1)
									FROM
										' + @CallistoDatabase + '.[sys].[tables] T
										INNER JOIN ' + @CallistoDatabase + '.[sys].[columns] C ON c.object_id = T.object_id AND C.[name] = ''LineItem_MemberId''
									WHERE
										T.[name] = ''FACT_' + @DataClassName + '_default_partition'''

								IF @DebugBM & 2 > 0 PRINT @SQLStatement

								EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ReturnVariable OUT

								IF @ReturnVariable > 0
									SELECT
										@FACT_DataClass_Table = 'FACT_' + @DataClassName + '_default_partition',
										@LineItemBP = 118
								ELSE
									BEGIN
										SET @SQLStatement = '
											SELECT @internalVariable = COUNT(1)
											FROM
												' + @CallistoDatabase + '.[sys].[tables] T
												INNER JOIN ' + @CallistoDatabase + '.[sys].[columns] C ON c.object_id = T.object_id AND C.[name] = ''LineItem_MemberId''
											WHERE
												T.[name] = ''FACT_' + @DataClassName + '_Detail_default_partition'''

										IF @DebugBM & 2 > 0 PRINT @SQLStatement

										EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ReturnVariable OUT

										IF @ReturnVariable > 0
											SELECT
												@FACT_DataClass_Table = 'FACT_' + @DataClassName + '_Detail_default_partition',
												@LineItemBP = NULL
									END

								IF @DebugBM & 2 > 0 SELECT [@FACT_DataClass_Table] = @FACT_DataClass_Table, [@LineItemBP] = @LineItemBP
							END

					--START:NOTE (for  @Step = 'Update temp table #ObjectList'): for CAPEX, it should be possible to set BP='Input_CAPEX' with LineItem details, and this rule must be tested with different cases
					SET @Step = 'Update temp table #ObjectList'
							UPDATE OL
							SET
								[InputValue] = 'NONE'
							FROM
								#ObjectList OL
							WHERE 
								OL.[ObjectType] = 'Dimension' AND
								OL.[ObjectName] = 'LineItem' AND
								OL.[InputValue] IS NULL

							IF (
								SELECT COUNT(1)
								FROM
									#ObjectList OL
								WHERE 
									OL.[ObjectType] = 'Dimension' AND
									OL.[ObjectName] = 'LineItem' AND
									OL.[InputValue] <> 'NONE'
								) > 0 AND @LineItemBP IS NOT NULL
								UPDATE OL
								SET
									[InputValue] = 'LineItem'
								FROM
									#ObjectList OL
								WHERE 
									OL.[ObjectType] = 'Dimension' AND
									OL.[ObjectName] = 'BusinessProcess'
					--END:NOTE (for  @Step = 'Update temp table #ObjectList'): for CAPEX, it should be possible to set BP='Input_CAPEX' with LineItem details, and this rule must be tested with different cases

					SET @Step = 'Update columns MeasureValue and CommentValue in temptable #ObjectList and create final SQL Statement parts'
						IF @ResultTypeBM & 4 > 0
							BEGIN
								UPDATE #ObjectList
								SET
									InputValue = 'RAWDATA'
								WHERE
									ObjectType = 'Dimension' AND
									ObjectID = -8 AND
									InputValue = 'PERIODIC'

								DECLARE ObjectList_Cursor CURSOR FOR

									SELECT 
										[ObjectName],
										[StorageTypeBM_Dimension] = [StorageTypeBM],
										[InputValue],
										[ObjectType]
									FROM
										#ObjectList
									WHERE
										IncludedYN <> 0
									ORDER BY
										ObjectType,
										SortOrder

									OPEN ObjectList_Cursor
									FETCH NEXT FROM ObjectList_Cursor INTO @ObjectName, @StorageTypeBM_Dimension, @InputValue, @ObjectType

									WHILE @@FETCH_STATUS = 0
										BEGIN
											IF @DebugBM & 2 > 0 SELECT [@ObjectName] = @ObjectName, [@StorageTypeBM_Dimension] = @StorageTypeBM_Dimension, [@InputValue] = @InputValue
											
											IF @ObjectType = 'Dimension'
												BEGIN
													IF LEN(@InputValue) > 0
														BEGIN															
															
															IF @LineItemYN <> 0 AND  @CommentYN <> 0 AND @MeasureYN <> 0 --AND @ObjectName <> 'WorkflowState'													
																BEGIN
																	EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DestinationDatabase, @DimensionName = @ObjectName, @Filter = @InputValue, @StorageTypeBM = @StorageTypeBM_Dimension, @LeafMemberOnlyYN = 1, @LeafLevelFilter = @UsedValue OUT
																	EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DestinationDatabase, @DimensionName = @ObjectName, @Filter = @InputValue, @StorageTypeBM = @StorageTypeBM_Dimension, @LeafMemberOnlyYN = 1, @StorageTypeBM_DataClass = 4, @LeafLevelFilter = @MemberId_List OUT

																	--@StorageTypeBM_DataClass

																	SET @UsedValue = CASE WHEN @ObjectName = 'WorkflowState' THEN '''NONE''' ELSE @UsedValue END
																	
																	UPDATE #ObjectList SET [MeasureValue] = @UsedValue WHERE ObjectType = 'Dimension' AND ObjectName = @ObjectName
																	UPDATE #ObjectList SET [CommentValue] = @UsedValue WHERE ObjectType = 'Dimension' AND ObjectName = @ObjectName
																		
																	--IF @ObjectName <> 'WorkflowState'
																	--	IF LEN(@MemberId_List) > 0 SET @SQLWhereDeleteClause = @SQLWhereDeleteClause + CHAR(13) + CHAR(10) + CHAR(9) + 'F.[' + @ObjectName + '_MemberId] IN (' + @MemberId_List + ') AND' 

																	IF @ObjectName <> 'WorkflowState'
																			IF LEN(@MemberId_List) > 0 
																				BEGIN 
																					--temporary fix by NeHa 20220620: Handle accounts NOT existing in the default hierarchy
																					IF @MemberId_List = '-999' AND @ObjectName = 'Account'
																						BEGIN
																							WHILE (@MemberId_List = '-999' AND @HierarchyNo < @Account_MaxHierarchyNo) 
																								BEGIN
																									SET @HierarchyNo = @HierarchyNo + 1
																									EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DestinationDatabase, @DimensionName = @ObjectName, @Filter = @InputValue, @StorageTypeBM = @StorageTypeBM_Dimension, @LeafMemberOnlyYN = 1, @StorageTypeBM_DataClass = 4, @LeafLevelFilter = @MemberId_List OUT, @HierarchyNo = @HierarchyNo
																									IF @DebugBM & 1 > 0 SELECT [@ObjectName] = @ObjectName, [@HierarchyNo] = @HierarchyNo, [@MemberId_List] = @MemberId_List
                                                                                                END                                                                                                 
																						END 
																					SET @SQLWhereDeleteClause = @SQLWhereDeleteClause + CHAR(13) + CHAR(10) + CHAR(9) + 'F.[' + @ObjectName + '_MemberId] IN (' + @MemberId_List + ') AND'
																				END	
																		IF @DebugBM & 1 > 0 SELECT [@SQLWhereDeleteClause] = @SQLWhereDeleteClause																	
																	
																	SET @SQLJoin_UpdateCallisto_Measure = @SQLJoin_UpdateCallisto_Measure + CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + @ObjectName + '] [' + @ObjectName + '] ON [' + @ObjectName + '].[MemberId] = F.[' + @ObjectName + '_MemberId] AND [' + @ObjectName + '].[Label] IN (' + @UsedValue + ')'
																	SET @SQLJoin_InsertCallisto_Measure = @SQLJoin_InsertCallisto_Measure + CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + @ObjectName + '] [' + @ObjectName + '] ON [' + @ObjectName + '].[Label] IN (' + @UsedValue + ')'
																	IF @ObjectName <> 'WorkflowState'
																		BEGIN
																			SET @SQLJoin_UpdateCallisto_Comment = @SQLJoin_UpdateCallisto_Comment + CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + @ObjectName + '] [' + @ObjectName + '] ON [' + @ObjectName + '].[MemberId] = F.[' + @ObjectName + '_MemberId] AND [' + @ObjectName + '].[Label] IN (' + @UsedValue + ')'
																			SET @SQLJoin_InsertCallisto_Comment = @SQLJoin_InsertCallisto_Comment + CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + @ObjectName + '] [' + @ObjectName + '] ON [' + @ObjectName + '].[Label] IN (' + @UsedValue + ')'
																		END
																END
															ELSE 
																BEGIN
																	IF @MeasureYN <> 0
																	BEGIN
																		EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DestinationDatabase, @DimensionName = @ObjectName, @Filter = @InputValue, @StorageTypeBM = @StorageTypeBM_Dimension, @LeafLevelFilter = @UsedValue OUT
																		EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DestinationDatabase, @DimensionName = @ObjectName, @Filter = @InputValue, @StorageTypeBM = @StorageTypeBM_Dimension, @LeafMemberOnlyYN = 1, @StorageTypeBM_DataClass = 4, @LeafLevelFilter = @MemberId_List OUT
																		SET @UsedValue = ISNULL(CASE WHEN @UsedValue = '' THEN NULL ELSE @UsedValue END, '''NONE''')
																		UPDATE #ObjectList SET [MeasureValue] = @UsedValue WHERE ObjectType = 'Dimension' AND ObjectName = @ObjectName
																		
																		IF @DebugBM & 1 > 0 SELECT [@ObjectName] = @ObjectName, [@MemberId_List] = @MemberId_List
																		
																		--IF @ObjectName <> 'WorkflowState'
																		--	IF LEN(@MemberId_List) > 0 SET @SQLWhereDeleteClause = @SQLWhereDeleteClause + CHAR(13) + CHAR(10) + CHAR(9) + 'F.[' + @ObjectName + '_MemberId] IN (' + @MemberId_List + ') AND' 

																		IF @ObjectName <> 'WorkflowState'
																			IF LEN(@MemberId_List) > 0 
																				BEGIN 
																					--temporary fix by NeHa 20220620: Handle accounts NOT existing in the default hierarchy
																					IF @MemberId_List = '-999' AND @ObjectName = 'Account'
																						BEGIN
																							WHILE (@MemberId_List = '-999' AND @HierarchyNo < @Account_MaxHierarchyNo) 
																								BEGIN
																									SET @HierarchyNo = @HierarchyNo + 1
																									EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DestinationDatabase, @DimensionName = @ObjectName, @Filter = @InputValue, @StorageTypeBM = @StorageTypeBM_Dimension, @LeafMemberOnlyYN = 1, @StorageTypeBM_DataClass = 4, @LeafLevelFilter = @MemberId_List OUT, @HierarchyNo = @HierarchyNo
																									IF @DebugBM & 1 > 0 SELECT [@ObjectName] = @ObjectName, [@HierarchyNo] = @HierarchyNo, [@MemberId_List] = @MemberId_List
                                                                                                END                                                                                                 
																						END 
																					SET @SQLWhereDeleteClause = @SQLWhereDeleteClause + CHAR(13) + CHAR(10) + CHAR(9) + 'F.[' + @ObjectName + '_MemberId] IN (' + @MemberId_List + ') AND'
																				END

																		IF @DebugBM & 1 > 0 SELECT [@SQLWhereDeleteClause] = @SQLWhereDeleteClause
																		
																		SET @SQLJoin_UpdateCallisto_Measure = @SQLJoin_UpdateCallisto_Measure + CASE WHEN @ObjectName <> 'WorkflowState' THEN CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + @ObjectName + '] [' + @ObjectName + '] ON [' + @ObjectName + '].[MemberId] = F.[' + @ObjectName + '_MemberId] AND [' + @ObjectName + '].[Label] IN (' + @UsedValue + ')' ELSE '' END
																		SET @SQLJoin_InsertCallisto_Measure = @SQLJoin_InsertCallisto_Measure + CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + @ObjectName + '] [' + @ObjectName + '] ON [' + @ObjectName + '].[Label] IN (' + @UsedValue + ')'
																	END
																	IF @CommentYN <> 0 --AND @ObjectName <> 'WorkflowState'	--AND @LineItemYN = 0
																	BEGIN
																		EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DestinationDatabase, @DimensionName = @ObjectName, @Filter = @InputValue, @StorageTypeBM = @StorageTypeBM_Dimension, @FilterLevel = 'LF', @LeafLevelFilter = @UsedValue OUT
																		--IF @DebugBM & 1 > 0 SELECT [TestNeHa] = 'TestNeHa101_after_[spGet_LeafLevelFilter]',[@UsedValue] = @UsedValue,[@ObjectName]=@ObjectName

																		--temporary fix by NeHa 20220620: Handle accounts NOT existing in the default hierarchy
																		SET @HierarchyNo = 0
																		IF (@UsedValue = CHAR(39) + '-999' + CHAR(39)) AND @ObjectName = 'Account'
																			BEGIN
																				IF @DebugBM & 1 > 0 SELECT [TestNeHa] = 'TestNeHa102',[@UsedValue] = @UsedValue,[@ObjectName]=@ObjectName,[@HierarchyNo] = @HierarchyNo
																				WHILE (@UsedValue = CHAR(39) + '-999' + CHAR(39) AND @HierarchyNo < @Account_MaxHierarchyNo) 
																					BEGIN
																						SET @HierarchyNo = @HierarchyNo + 1
																						EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DestinationDatabase, @DimensionName = @ObjectName, @Filter = @InputValue, @StorageTypeBM = @StorageTypeBM_Dimension, @FilterLevel = 'LF', @LeafLevelFilter = @UsedValue OUT, @HierarchyNo = @HierarchyNo
																						IF @DebugBM & 1 > 0 SELECT [@ObjectName] = @ObjectName, [@HierarchyNo] = @HierarchyNo, [@UsedValue] = @UsedValue
																					END                                                                                                 
																			END 
																		--IF @DebugBM & 1 > 0 SELECT [TestNeHa] = 'TestNeHa103',[@UsedValue] = @UsedValue
																		
																		SET @UsedValue = ISNULL(CASE @UsedValue WHEN '' THEN NULL ELSE @UsedValue END, '''All_''')
																		SET @UsedValue = CASE WHEN @ObjectName = 'WorkflowState' THEN '''NONE''' ELSE @UsedValue END

																		UPDATE #ObjectList SET [CommentValue] = @UsedValue WHERE ObjectType = 'Dimension' AND ObjectName = @ObjectName
																		IF @ObjectName <> 'WorkflowState'
																			BEGIN
																				SET @SQLJoin_UpdateCallisto_Comment = @SQLJoin_UpdateCallisto_Comment + CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + @ObjectName + '] [' + @ObjectName + '] ON [' + @ObjectName + '].[MemberId] = F.[' + @ObjectName + '_MemberId] AND [' + @ObjectName + '].[Label] IN (' + @UsedValue + ')'
																				SET @SQLJoin_InsertCallisto_Comment = @SQLJoin_InsertCallisto_Comment + CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + @ObjectName + '] [' + @ObjectName + '] ON [' + @ObjectName + '].[Label] IN (' + @UsedValue + ')'
																			END
																	END
																END

															SET @SQLWhereClause = @SQLWhereClause + CHAR(13) + CHAR(10) + CHAR(9) + @ObjectName + @DimensionDistinguishing + ' IN (' + @UsedValue + ') AND'
															SET @SQLInsertClause = @SQLInsertClause + CHAR(13) + CHAR(10) + CHAR(9) + @ObjectName + @DimensionDistinguishing + ','
															SET @SQLSelectClause = @SQLSelectClause + CHAR(13) + CHAR(10) + CHAR(9) + @ObjectName + @DimensionDistinguishing + ' = ' + @UsedValue + ','
															SET @SQLSelect_InsertCallisto = @SQLSelect_InsertCallisto + CHAR(13) + CHAR(10) + CHAR(9) + @ObjectName + @DimensionDistinguishing + ' = ISNULL([' + @ObjectName + '].MemberId, -1),'
															SET @SQLSelect_InsertCallistoText = @SQLSelect_InsertCallistoText + CHAR(13) + CHAR(10) + CHAR(9) + @ObjectName + @DimensionDistinguishing + ' = ' + CASE WHEN @ObjectName = 'WorkflowState' THEN '-1' ELSE 'ISNULL([' + @ObjectName + '].MemberId, -1)' END + ','
															
														END
												END
											ELSE IF @ObjectType = 'Measure'
												BEGIN
													IF LEN(@InputValue) > 0
														BEGIN
															SET @UsedValue = REPLACE(@InputValue, ',', '.')
															UPDATE #ObjectList SET [MeasureValue] = @UsedValue WHERE ObjectType = 'Measure' AND ObjectName = @ObjectName
															--SET @SQLSetClause = @SQLSetClause + CHAR(13) + CHAR(10) + CHAR(9) + @ObjectName + '_Value = ' + @UsedValue + ','
															--SET @SQLInsertClause = @SQLInsertClause + CHAR(13) + CHAR(10) + CHAR(9) + @ObjectName  + '_Value,'
															--SET @SQLSelectClause = @SQLSelectClause + CHAR(13) + CHAR(10) + CHAR(9) + @ObjectName  + '_Value = ' + @UsedValue + ','
															--SET @SQLSelect_InsertCallisto = @SQLSelect_InsertCallisto + CHAR(13) + CHAR(10) + CHAR(9) + @ObjectName  + '_Value = ' + @UsedValue + ','
															SET @MeasureValue_Value = @InputValue
														END
												END
											ELSE IF @ObjectType = 'Comment'
												BEGIN
													IF LEN(@InputValue) > 0
														BEGIN
															SET @UsedValue = @InputValue
															UPDATE #ObjectList SET [CommentValue] = '''' + @UsedValue + '''' WHERE ObjectType = 'Comment' AND ObjectName = @ObjectName
															SET @Comment = @InputValue
														END	
												END

											FETCH NEXT FROM ObjectList_Cursor INTO @ObjectName, @StorageTypeBM_Dimension, @InputValue, @ObjectType
										END

								CLOSE ObjectList_Cursor
								DEALLOCATE ObjectList_Cursor		

								IF @DebugBM & 2 > 0 SELECT [@SQLWhereClause] = @SQLWhereClause                                
								IF LEN(@SQLWhereClause) > 4 SET @SQLWhereClause = SUBSTRING(@SQLWhereClause, 1, LEN(@SQLWhereClause) - 4)
								IF LEN(@SQLWhereDeleteClause) > 4 SET @SQLWhereDeleteClause = SUBSTRING(@SQLWhereDeleteClause, 1, LEN(@SQLWhereDeleteClause) - 4)

							END

						IF @DebugBM & 2 > 0 SELECT TempTable = '#ObjectList', * FROM #ObjectList ORDER BY ObjectType, SortOrder

					SET @Step = 'Check empty Measure and Comment values'
						IF @MeasureYN <> 0
							BEGIN
								SET @MissingDimension = ''

								SELECT
									@MissingDimension = @MissingDimension + [ObjectName] + ', '
								FROM
									#ObjectList
								WHERE
									[IncludedYN] <> 0 AND
									[ObjectType] = 'Dimension' AND
									([MeasureValue] IS NULL OR [MeasureValue] = '')

								IF LEN(@MissingDimension) > 0
									BEGIN
										SET @MissingDimension = LEFT(@MissingDimension, LEN(@MissingDimension) - 1)
										SET @Message = 'Incorrect value(s) for the following Dimension(s): ' + @MissingDimension
										SET @Severity = 16
										GOTO EXITPOINT
									END
							END

						IF @CommentYN <> 0
							BEGIN
								SET @MissingDimension = ''

								SELECT
									@MissingDimension = @MissingDimension + [ObjectName] + ', '
								FROM
									#ObjectList
								WHERE
									[ObjectType] = 'Dimension' AND
									([CommentValue] IS NULL OR [CommentValue] = '')

								IF LEN(@MissingDimension) > 0
									BEGIN
										SET @MissingDimension = LEFT(@MissingDimension, LEN(@MissingDimension) - 1)
										SET @Message = 'Incorrect value(s) for the following Dimension(s): ' + @MissingDimension
										SET @Severity = 16
										GOTO EXITPOINT
									END
							END

					SET @Step = 'Check dimension filters are unique'
						SELECT
							@MissingDimension = @MissingDimension + [ObjectName] + ', '
						FROM
							#ObjectList
						WHERE
							[ObjectType] = 'Dimension' AND
							-- [UsedValue] LIKE '%,%'
							([MeasureValue] LIKE '%,%' OR [CommentValue] LIKE '%,%')

						IF LEN(@MissingDimension) > 0
							BEGIN
								SET @MissingDimension = LEFT(@MissingDimension, LEN(@MissingDimension) - 1)
								SET @Message = 'Dimension(s) ' + @MissingDimension + ' do(es) not have a unique leaf level value defined.'
								SET @Severity = 16
								GOTO EXITPOINT
							END
					SET @Step = 'Update and Insert data into DataClass'
						IF @StorageTypeBM_DataClass & 2 > 0
							BEGIN
								SET @SQLStatement = '
UPDATE pcDC
SET' + @SQLSetClause + '
	WorkFlowStateID            = ' + CASE WHEN @WorkFlowStateID IS NULL THEN 'pcDC.WorkFlowStateID' ELSE CONVERT(nvarchar(10), @WorkFlowStateID) END + ',
	WorkFlow_UpdatedBy_UserID  = ' + CASE WHEN @WorkFlowStateID IS NULL THEN 'pcDC.WorkFlow_UpdatedBy_UserID' ELSE CONVERT(nvarchar(10), @UserID) END + ',
	Data_UpdatedBy_UserID      = ' + CASE WHEN LEN('ValueSet') > 0 THEN CONVERT(nvarchar(10), @UserID) ELSE 'pcDC.Data_UpdatedBy_UserID' END + ',
	Updated                    = GetDate(),
	UpdatedBy                  = ''' + CONVERT(nvarchar(15), @UserID) + '''
FROM
	' + @ETLDatabase + '.[dbo].[pcDC_' + @InstanceID_String + '_' + @DataClassName + '] pcDC
WHERE
	ResultTypeBM = ' + CONVERT(nvarchar(10), @ResultTypeBM) + ' AND' + @SQLWhereClause

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
								SET @Updated_Check = @@ROWCOUNT
								SET @Updated = ISNULL(@Updated, 0) + @Updated_Check

							SET @Step = 'Insert into DataClass (v2)'
								IF @Updated_Check = 0
									BEGIN
										SET @SQLStatement = '
INSERT INTO ' + @ETLDatabase + '.[dbo].[pcDC_' + @InstanceID_String + '_' + @DataClassName + ']
	(
	ResultTypeBM,' + @SQLInsertClause + '
	WorkFlowStateID,
	Workflow_UpdatedBy_UserID,
	Data_UpdatedBy_UserID,
	Inserted,
	InsertedBy,
	Updated,
	UpdatedBy
	)
SELECT
	ResultTypeBM = ' + CONVERT(nvarchar(10), @ResultTypeBM) + ',' + @SQLSelectClause + '
	WorkFlowStateID = ' + CONVERT(nvarchar(10), ISNULL(@WorkflowStateID, @InitialWorkflowStateID)) + ',
	WorkFlow_UpdatedBy_UserID = ' + CASE WHEN ISNULL(@WorkflowStateID, @InitialWorkflowStateID) IS NULL THEN 'NULL' ELSE CONVERT(nvarchar(10), @UserID) END + ',
	Data_UpdatedBy_UserID = ' + CONVERT(nvarchar(10), @UserID) + ',
	Inserted = GetDate(),
	InsertedBy = ''' + CONVERT(nvarchar(15), @UserID) + ''',
	Updated = GetDate(),
	UpdatedBy = ''' + CONVERT(nvarchar(15), @UserID) + ''''

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Inserted = ISNULL(@Inserted, 0) + @@ROWCOUNT
									END
							END

						ELSE IF @StorageTypeBM_DataClass & 4 > 0

							BEGIN
								IF @MeasureYN <> 0
									BEGIN
/*
										SET @SQLStatement = '
UPDATE F
SET ' + @DataClassName + '_Value = ' + @MeasureValue_Value + ',
	' + CASE WHEN @StepWorkflowState_MemberId IS NOT NULL THEN 'WorkflowState_MemberId = ' + CONVERT(nvarchar(10), @StepWorkflowState_MemberId) + ',' ELSE '' END + '
	ChangeDatetime = GetDate(),
	UserID = ''' + CONVERT(nvarchar(15), @UserID) + '''
FROM
	' + @DestinationDatabase + '.[dbo].[' + @FACT_DataClass_Table + '] F' + @SQLJoin_UpdateCallisto_Measure

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Updated_Check = @@ROWCOUNT
										SET @Updated = ISNULL(@Updated, 0) + @Updated_Check

										IF @DebugBM & 2 > 0 SELECT [@Updated_Check] = @Updated_Check
*/
								SET @Step = 'Delete row from DataClass (Callisto)'
/*
										SET @SQLStatement = '
DELETE F
FROM
	' + @DestinationDatabase + '.[dbo].[' + @FACT_DataClass_Table + '] F' + @SQLJoin_UpdateCallisto_Measure
*/
										IF @AuditLogYN <> 0
											BEGIN
												SET @SQLStatement = '
SELECT @InternalVariable = ' + @DataClassName + '_Value
FROM
	' + @DestinationDatabase + '.[dbo].[' + @FACT_DataClass_Table + '] F
WHERE' + @SQLWhereDeleteClause

												IF @DebugBM & 2 > 0 PRINT @SQLStatement

												EXEC sp_executesql @SQLStatement, N'@InternalVariable float OUT', @InternalVariable = @FromNum OUT
												SET @FromNum = ISNULL(@FromNum, 0)
											END

										SET @SQLStatement = '
DELETE F
FROM
	' + @DestinationDatabase + '.[dbo].[' + @FACT_DataClass_Table + '] F
WHERE' + @SQLWhereDeleteClause

										IF @DebugBM & 1 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Deleted_Check = @@ROWCOUNT
										SET @Deleted = ISNULL(@Deleted, 0) + @Deleted_Check

										IF @DebugBM & 2 > 0 SELECT [@Deleted_Check] = @Deleted_Check


								SET @Step = 'Insert into DataClass (Callisto)'
--											IF @Updated_Check = 0
												BEGIN
													SELECT [Dummy] = 1 INTO #Dummy

													IF @DebugBM & 2 > 0
														SELECT
															[@DestinationDatabase] = @DestinationDatabase,
															[@FACT_DataClass_Table] = @FACT_DataClass_Table,
															[@DataClassName] = @DataClassName,
															[@SQLSelect_InsertCallisto] = @SQLSelect_InsertCallisto,
															[@UserName] = @UserName,
															[@MeasureValue_Value] = @MeasureValue_Value,
															[@SQLJoin_InsertCallisto_Measure] = @SQLJoin_InsertCallisto_Measure

													SET @SQLStatement = '
INSERT INTO ' + @DestinationDatabase + '.[dbo].[' + @FACT_DataClass_Table + ']
	(' + @SQLInsertClause + '
	ChangeDatetime,
	UserID,
	' + REPLACE(REPLACE(@FACT_DataClass_Table, 'FACT_', ''), '_default_partition', '') + '_Value
	)
SELECT' + @SQLSelect_InsertCallisto + '
	ChangeDatetime = GetDate(),
	UserID = ''' + CONVERT(nvarchar(15), @UserID) + ''',
	' + REPLACE(REPLACE(@FACT_DataClass_Table, 'FACT_', ''), '_default_partition', '') + '_Value = ' + @MeasureValue_Value + '
FROM
	#Dummy F' + @SQLJoin_InsertCallisto_Measure

													IF @DebugBM & 2 > 0 PRINT @SQLStatement
													EXEC (@SQLStatement)
													SET @Inserted = ISNULL(@Inserted, 0) + @@ROWCOUNT

													IF @AuditLogYN <> 0
														BEGIN
															SET @SQLStatement = '
INSERT INTO ' + @DestinationDatabase + '.[dbo].[AUDIT_' + @DataClassName + '_num]
	(' + @SQLInsertClause + '
	ChangeDatetime,
	UserID,
	[From],
	[To]
	)
SELECT' + @SQLSelect_InsertCallisto + '
	ChangeDatetime = GetDate(),
	UserID = ''' + @UserName + ''',
	[From] = ' + CONVERT(nvarchar(25), @FromNum) + ',
	[To] = ' + @MeasureValue_Value + '
FROM
	#Dummy F' + @SQLJoin_InsertCallisto_Measure

															IF @DebugBM & 2 > 0 PRINT @SQLStatement
															EXEC (@SQLStatement)
														END
					
													DROP TABLE #Dummy
												END -- of IF @Updated_Check = 0

									END -- of IF (@MeasureYN <> 0)

								SET @Step = 'Update FACT_Financials_text'
									IF @CommentYN <> 0
										BEGIN 
											IF @AuditLogYN <> 0
												BEGIN
													SET @SQLStatement = '
SELECT @InternalVariable = ' + @DataClassName + '_Text
FROM
	' + @DestinationDatabase + '.[dbo].[' + @FACT_DataClass_Text_Table + '] F' + CASE WHEN LEN(@SQLWhereDeleteClause) > 0 THEN CHAR(13) + CHAR(10) + 'WHERE ' + @SQLWhereDeleteClause ELSE '' END
													IF @DebugBM & 2 > 0 PRINT @SQLStatement

													EXEC sp_executesql @SQLStatement, N'@InternalVariable nvarchar(4000) OUT', @InternalVariable = @FromText OUT
													SET @FromText = ISNULL(@FromText, '')
												END

											SET @SQLStatement = '
UPDATE F
SET ' + REPLACE(@FACT_DataClass_Text_Table, 'FACT_', '') + ' = ''' + @Comment + ''',
	' + CASE WHEN @StepWorkflowState_MemberId IS NOT NULL THEN 'WorkflowState_MemberId = -1,' ELSE '' END + '
	ChangeDatetime = GetDate(),
	UserID = ''' + CONVERT(nvarchar(15), @UserID) + '''
FROM
	' + @DestinationDatabase + '.[dbo].[' + @FACT_DataClass_Text_Table + '] F' + @SQLJoin_UpdateCallisto_Comment

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
											SET @Updated_Check = @@ROWCOUNT
											SET @Updated = ISNULL(@Updated, 0) + @Updated_Check

											SET @Step = 'Insert into FACT_Financials_text'
												IF @DebugBM & 2 > 0 SELECT [@Updated_Check] = @Updated_Check
												IF @Updated_Check < 1
													BEGIN
														SELECT [Dummy] = 1 INTO #Dummy2

														SET @SQLStatement = '
INSERT INTO ' + @DestinationDatabase + '.[dbo].[' + @FACT_DataClass_Text_Table + ']
	(' + @SQLInsertClause + ' 
	ChangeDatetime,
	UserID,
	' + REPLACE(@FACT_DataClass_Text_Table, 'FACT_', '') + '
	)
SELECT' + @SQLSelect_InsertCallistoText + '
	ChangeDatetime = GetDate(),
	UserID = ''' + CONVERT(nvarchar(15), @UserID) + ''',
	' + REPLACE(@FACT_DataClass_Text_Table, 'FACT_', '') + ' = ''' + @Comment + '''
FROM
	#Dummy2 F' + @SQLJoin_InsertCallisto_Comment

														IF @DebugBM & 2 > 0 PRINT @SQLStatement
														EXEC (@SQLStatement)
														SET @Inserted = ISNULL(@Inserted, 0) + @@ROWCOUNT

														DROP TABLE #Dummy2
													END -- of IF @Updated_Check < 1

												IF @AuditLogYN <> 0
													BEGIN
														SELECT [Dummy] = 1 INTO #Dummy3
														SET @SQLStatement = '
INSERT INTO ' + @DestinationDatabase + '.[dbo].[AUDIT_' + @DataClassName + '_text]
	(' + @SQLInsertClause + '
	ChangeDatetime,
	UserID,
	[From],
	[To]
	)
SELECT' + @SQLSelect_InsertCallistoText + '
	ChangeDatetime = GetDate(),
	UserID = ''' + @UserName + ''',
	[From] = ''' + @FromText + ''',
	[To] = ''' + @Comment + '''
FROM
	#Dummy3 F' + @SQLJoin_InsertCallisto_Comment

														IF @DebugBM & 2 > 0 PRINT @SQLStatement
														EXEC (@SQLStatement)
														DROP TABLE #Dummy3
													END



										END -- OF IF (@CommentYN <> 0)

							END --IF @StorageTypeBM_DataClass & 4 > 0
								
						FETCH NEXT FROM DataClass_Data_Cursor INTO  @Filter, @MeasureValue
				END

		CLOSE DataClass_Data_Cursor
		DEALLOCATE DataClass_Data_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE [#ObjectList]
		DROP TABLE [#Data_Cursor_Table]
		IF @CalledYN = 0 DROP TABLE #PipeStringSplit

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
