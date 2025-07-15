SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_DimensionMember_List]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DimensionID int = NULL,
	@JSON_table nvarchar(MAX) = NULL,
	@ListType nvarchar(20) = NULL, --'Leaf', 'Category', 'Parent'

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000821,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*

EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DimensionMember_List] @DebugBM=15, @DimensionID='5979',@InstanceID='670',@ListType='Leaf',@UserID='28525',@VersionID='1130'
,@JSON_table='[{"D01_MemberKey":"01","D02_MemberKey":"000","D03_MemberKey":"10100","D04_MemberKey":"00","D05_MemberKey":"NONE"}]'

EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DimensionMember_List] @DebugBM=7, @DimensionID='-1',@InstanceID='666',@ListType='Leaf',@UserID='28189',@VersionID='1128'
,@JSON_table='[
{"MemberKey":"TestAccountM1","Description":"TestAccountMember1","H00_MemberKey":"All_","H01_MemberKey":"","P01":"Asset","HelpText":"TestAccountMember1"},
{"MemberKey":"TestAccountM2","Description":"TestAccountMember2","H00_MemberKey":"All_","H01_MemberKey":"","P01":"Income","HelpText":"TestAccountMember2"},
{"MemberKey":"TestAccountM3","Description":"TestAccountMember3","H00_MemberKey":"All_","H01_MemberKey":"","P01":"Expense","HelpText":"TestAccountMember3"},
{"MemberKey":"TestAccountM4","Description":"TestAccountMember4","H00_MemberKey":"All_","H01_MemberKey":"","P01":"Liability","HelpText":"TestAccountMember4"},
{"MemberKey":"TestAccountM5","Description":"TestAccountMember5","H00_MemberKey":"All_","H01_MemberKey":"","P01":"Equity","HelpText":"TestAccountMember5"},
{"MemberKey":"TestAccountM6","Description":"TestAccountMember6","H00_MemberKey":"All_","H01_MemberKey":"","P01":"NONE","HelpText":"TestAccountMember6"},
{"MemberKey":"TestAccountM7","Description":"TestAccountMember7","H00_MemberKey":"All_","H01_MemberKey":"","P01":"Other","HelpText":"TestAccountMember7"},
{"MemberKey":"TestAccountM8","Description":"TestAccountMember8","H00_MemberKey":"All_","H01_MemberKey":"","P01":"Statistical","HelpText":"TestAccountMember8"}
]'

EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DimensionMember_List] @DebugBM=15, @ListType='Parent',
@DimensionID='-1',@InstanceID='666',@UserID='28189',@VersionID='1128',@JSON_table='[
{"MemberKey":"AC_1","Description":"Assets","H00_MemberKey":"Balance_Sheet_","H01_MemberKey":"","HelpText":"Assets"},
{"MemberKey":"AC_10","Description":"Intangible fixed assets","H00_MemberKey":"AC_1","H01_MemberKey":"","HelpText":"Intangible fixed assets"},
{"MemberKey":"AC_1010","Description":"Development expenditure","H00_MemberKey":"AC_10","H01_MemberKey":"","HelpText":"Development expenditure"},
{"MemberKey":"AC_1020","Description":"Concessions etc.","H00_MemberKey":"","H01_MemberKey":"","HelpText":"Concessions etc."},
{"MemberKey":"AC_1030","Description":"Patents","H00_MemberKey":"AC_10","H01_MemberKey":"","HelpText":"Patents"}]'


EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DimensionMember_List] @DebugBM=15,@DimensionID='-1',@InstanceID='582',@UserID='9899',@VersionID='1082'
,@JSON_table='[
{"ResultTypeBM":"4","MemberId":"1002","MemberKey":"11116","Description":"Residential Care Subsidy-AN-ACC","HelpText":"Residential Care Subsidy-AN-ACC"
,"H00_MemberKey":"AC_SUBS_INC","H01_MemberKey":"AC_SUBS_INC","H06_MemberKey":"AC_SUBS_INC","H08_MemberKey":"AC_SUBS_INC","H09_MemberKey":"AC_SUBS_INC"
,"H10_MemberKey":"AC_SUBS_INC","H11_MemberKey":"AC_SUBS_INC","H12_MemberKey":"AC_SUBS_INC","P01":"INPUT"}]'

EXEC [spRun_Procedure_KeyValuePair] @JSON='[
{"TKey":"InstanceID","TValue":"574"},{"TKey":"UserID","TValue":"7881"},
{"TKey":"VersionID","TValue":"1081"},{"TKey":"DimensionID","TValue":"5604"}
]', @JSON_table='[
{"ResultTypeBM":"4","MemberId":"2451","MemberKey":"201-608010","Description":"Manufacturing - Other Benefits",
"HelpText":"Manufacturing - Other Benefits","D01_MemberKey":"201","D02_MemberKey":"608010","H00_MemberKey":"I_DOB",
"H01_MemberKey":"I_DIR_LAB_OS","H02_MemberKey":"","H03_MemberKey":"I_DOB","P01":null,"P02":null,"P03":false,"P04":"1"}
]', @ProcedureName='spPortalSet_DimensionMember_List', @XML=null

DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"MemberId" : "1025", "P01": "More testing"},
	{"MemberId" : "1026", "H01_MemberKey": "Cat_AE", "H02_MemberKey": "Cat_AC"},
	{"D01_MemberKey" : "ST_VM", "D02_MemberKey": "019", "D03_MemberKey": "01", "H01_MemberKey" : "Cat_AB", "H02_MemberKey": "Cat_AC", "H03_MemberKey": "Cat_AD", "P01": "Test new row"},
	{"MemberId" : "1028", "DeleteYN": "1" }
	]'

EXEC [dbo].[spPortalSet_DimensionMember_List] 
	@UserID = -10,
	@InstanceID = 531,
	@VersionID = 1041,
	@DimensionID = 9155,
	@DebugBM = 7,
	@JSON_table = @JSON_table

EXEC [pcINTEGRATOR].[dbo].[spPortalSet_DimensionMember_List] 
@DimensionID='5807',@InstanceID='596',@UserID='10830',@VersionID='1091',
@JSON_table='[{"ResultTypeBM":"4","MemberId":"3784","MemberKey":"1106-00000-009","Description":"Inversiones en Acciones VC CAOR.",
"HelpText":"Inversiones En Acciones - Sub 00000 - Cuenta Afectable 009","D01_MemberKey":"1106","D02_MemberKey":"00000",
"D03_MemberKey":"009","H00_MemberKey":"AC_INV ACC","H01_MemberKey":"C_INV ACC","H02_MemberKey":"C_INV ACC",
"H03_MemberKey":"AC_INV ACC","H04_MemberKey":"AC_INV ACC","H05_MemberKey":"AC_INV ACC","H06_MemberKey":"AC_INV ACC",
"H07_MemberKey":"AC_INV ACC","H08_MemberKey":"AC_INV ACC","H09_MemberKey":"AC_INV ACC","H10_MemberKey":"AC_INV ACC",
"H11_MemberKey":"AC_INV ACC","H12_MemberKey":"AC_INV ACC","H13_MemberKey":"AC_INV ACC","H14_MemberKey":"AC_INV ACC",
"H15_MemberKey":"AC_INV ACC","H16_MemberKey":"AC_INV ACC","H17_MemberKey":"AC_INV ACC","H18_MemberKey":"AC_INV ACC","P01":true,"P02":"1"}]'

EXEC [spPortalSet_DimensionMember_List] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
--	@EntityID int,
	@SQLStatement NVARCHAR(MAX),
	@CallistoDatabase NVARCHAR(100),
	@DeletedID INT,
	@DimensionName NVARCHAR(50),
	@ColumnCode NCHAR(3),
	@ColumnName NVARCHAR(50),
	@SubDimensionName NVARCHAR(50),
	@Punctuation NVARCHAR(10) = '-',
	@DescriptionPunctuation NVARCHAR(10) = ' - ',
	@SQL_Dimension_Insert NVARCHAR(1000) = '',
	@SQL_Dimension_Select NVARCHAR(1000) = '',
	@SQL_Property_Insert NVARCHAR(1000) = '',
	@SQL_Property_Select NVARCHAR(1000) = '',
	@HierarchyName NVARCHAR(100),
	@Dimensionhierarchy NVARCHAR(100),
	@NodeTypeBMExistsYN BIT,
	@NodeTypeBM INT,
	@TableName NVARCHAR(100),
	@EnhancedStorageYN BIT,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
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
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain leaf dimension members setting Category parents in columns.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2175' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-724: Added update and insert of multidim dimension values. DB-725: Update Helptext. DB-734: Removed SELECT query on error information.'
		IF @Version = '2.1.2.2179' SET @Description = 'Added SortOrder in temp table #Column.'
		IF @Version = '2.1.2.2180' SET @Description = 'Changed sub call from obsolete spGet_Category_Column to new spGet_DimensionMember_List_Column.'
		IF @Version = '2.1.2.2192' SET @Description = 'Handle Enhanced Storage.'
		IF @Version = '2.1.2.2193' SET @Description = 'Added up to [H15_Member**] columns on #LeafMemberTable temp table.'
		IF @Version = '2.1.2.2198' SET @Description = 'EA-7530: Added up to [H25_Member**] columns on #LeafMemberTable temp table.'
		IF @Version = '2.1.2.2199' SET @Description = 'DB-1248: Added @ListType parameter. FDB-1702: Allow setting of [AccounType] property for Account dimension in DimensionMembers import routine. FEA-8810: Update[AccounType] property for @DimensionID=-1 (Account) only.'

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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = DestinationDatabase,
			@EnhancedStorageYN = EnhancedStorageYN
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		SELECT
			@DimensionName = [DimensionName],
			@TableName = 'S_DS_' + [DimensionName]
		FROM
			[Dimension]
		WHERE
			[InstanceID] IN (0, @InstanceID) AND
			[DimensionID] = @DimensionID
		
		SET @ListType = ISNULL(@ListType, 'Leaf')
		SET @NodeTypeBM = CASE @ListType WHEN 'Category' THEN 1042 WHEN 'Parent' THEN 2 ELSE 1 END 

		EXEC [pcINTEGRATOR].[dbo].[spGet_ColumnExistsYN]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DatabaseName = @CallistoDatabase,
			@TableName = @TableName,
			@ColumnName = 'NodeTypeBM',
			@ExistsYN  = @NodeTypeBMExistsYN OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@CallistoDatabase] = @CallistoDatabase,
				[@EnhancedStorageYN] = @EnhancedStorageYN,
				[@ListType] = @ListType,
				[@NodeTypeBM] = @NodeTypeBM,
				[@NodeTypeBMExistsYN] = @NodeTypeBMExistsYN

	SET @Step = 'Create and fill #LeafMemberTable'
		CREATE TABLE #LeafMemberTable
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[D01_MemberID] bigint,
			[D01_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D01_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D02_MemberID] bigint,
			[D02_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D02_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D03_MemberID] bigint,
			[D03_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D03_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D04_MemberID] bigint,
			[D04_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D04_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D05_MemberID] bigint,
			[D05_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D05_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D06_MemberID] bigint,
			[D06_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D06_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D07_MemberID] bigint,
			[D07_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D07_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D08_MemberID] bigint,
			[D08_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D08_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D09_MemberID] bigint,
			[D09_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D09_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D10_MemberID] bigint,
			[D10_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D10_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C00_MemberID] bigint,
			[C00_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C01_MemberID] bigint,
			[C01_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C02_MemberID] bigint,
			[C02_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C03_MemberID] bigint,
			[C03_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C04_MemberID] bigint,
			[C04_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C05_MemberID] bigint,
			[C05_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C06_MemberID] bigint,
			[C06_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C07_MemberID] bigint,
			[C07_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C08_MemberID] bigint,
			[C08_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C09_MemberID] bigint,
			[C09_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[C10_MemberID] bigint,
			[C10_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H00_MemberID] bigint,
			[H00_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H01_MemberID] bigint,
			[H01_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H02_MemberID] bigint,
			[H02_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H03_MemberID] bigint,
			[H03_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H04_MemberID] bigint,
			[H04_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H05_MemberID] bigint,
			[H05_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H06_MemberID] bigint,
			[H06_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H07_MemberID] bigint,
			[H07_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H08_MemberID] bigint,
			[H08_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H09_MemberID] bigint,
			[H09_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H10_MemberID] bigint,
			[H10_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H11_MemberID] bigint,
			[H11_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H12_MemberID] bigint,
			[H12_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H13_MemberID] bigint,
			[H13_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H14_MemberID] bigint,
			[H14_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H15_MemberID] bigint,
			[H15_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H16_MemberID] bigint,
			[H16_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H17_MemberID] bigint,
			[H17_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H18_MemberID] bigint,
			[H18_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H19_MemberID] bigint,
			[H19_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H20_MemberID] bigint,
			[H20_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H21_MemberID] bigint,
			[H21_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H22_MemberID] bigint,
			[H22_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H23_MemberID] bigint,
			[H23_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H24_MemberID] bigint,
			[H24_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H25_MemberID] bigint,
			[H25_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[P01] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P02] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P03] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P04] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P05] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P06] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P07] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P08] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P09] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P10] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[DeleteYN] bit DEFAULT 0
			)			

		IF @JSON_table IS NOT NULL	
			INSERT INTO #LeafMemberTable
				(
				[MemberId],
				[MemberKey],
				[Description],
				[HelpText],
				[D01_MemberID],
				[D01_MemberKey],
				[D02_MemberID],
				[D02_MemberKey],
				[D03_MemberID],
				[D03_MemberKey],
				[D04_MemberID],
				[D04_MemberKey],
				[D05_MemberID],
				[D05_MemberKey],
				[D06_MemberID],
				[D06_MemberKey],
				[D07_MemberID],
				[D07_MemberKey],
				[D08_MemberID],
				[D08_MemberKey],
				[D09_MemberID],
				[D09_MemberKey],
				[D10_MemberID],
				[D10_MemberKey],
				[C00_MemberID],
				[C00_MemberKey],
				[C01_MemberID],
				[C01_MemberKey],
				[C02_MemberID],
				[C02_MemberKey],
				[C03_MemberID],
				[C03_MemberKey],
				[C04_MemberID],
				[C04_MemberKey],
				[C05_MemberID],
				[C05_MemberKey],
				[C06_MemberID],
				[C06_MemberKey],
				[C07_MemberID],
				[C07_MemberKey],
				[C08_MemberID],
				[C08_MemberKey],
				[C09_MemberID],
				[C09_MemberKey],
				[C10_MemberID],
				[C10_MemberKey],
				[H00_MemberID],
				[H00_MemberKey],
				[H01_MemberID],
				[H01_MemberKey],
				[H02_MemberID],
				[H02_MemberKey],
				[H03_MemberID],
				[H03_MemberKey],
				[H04_MemberID],
				[H04_MemberKey],
				[H05_MemberID],
				[H05_MemberKey],
				[H06_MemberID],
				[H06_MemberKey],
				[H07_MemberID],
				[H07_MemberKey],
				[H08_MemberID],
				[H08_MemberKey],
				[H09_MemberID],
				[H09_MemberKey],
				[H10_MemberID],
				[H10_MemberKey],
				[H11_MemberID],
				[H11_MemberKey],
				[H12_MemberID],
				[H12_MemberKey],
				[H13_MemberID],
				[H13_MemberKey],
				[H14_MemberID],
				[H14_MemberKey],
				[H15_MemberID],
				[H15_MemberKey],
				[H16_MemberID],
				[H16_MemberKey],
				[H17_MemberID],
				[H17_MemberKey],
				[H18_MemberID],
				[H18_MemberKey],
				[H19_MemberID],
				[H19_MemberKey],
				[H20_MemberID],
				[H20_MemberKey],
				[H21_MemberID],
				[H21_MemberKey],
				[H22_MemberID],
				[H22_MemberKey],
				[H23_MemberID],
				[H23_MemberKey],
				[H24_MemberID],
				[H24_MemberKey],
				[H25_MemberID],
				[H25_MemberKey],
				[P01],
				[P02],
				[P03],
				[P04],
				[P05],
				[P06],
				[P07],
				[P08],
				[P09],
				[P10],
				[DeleteYN]
				)
			SELECT
				[MemberId],
				[MemberKey],
				[Description],
				[HelpText],
				[D01_MemberID],
				[D01_MemberKey],
				[D02_MemberID],
				[D02_MemberKey],
				[D03_MemberID],
				[D03_MemberKey],
				[D04_MemberID],
				[D04_MemberKey],
				[D05_MemberID],
				[D05_MemberKey],
				[D06_MemberID],
				[D06_MemberKey],
				[D07_MemberID],
				[D07_MemberKey],
				[D08_MemberID],
				[D08_MemberKey],
				[D09_MemberID],
				[D09_MemberKey],
				[D10_MemberID],
				[D10_MemberKey],
				[C00_MemberID],
				[C00_MemberKey],
				[C01_MemberID],
				[C01_MemberKey],
				[C02_MemberID],
				[C02_MemberKey],
				[C03_MemberID],
				[C03_MemberKey],
				[C04_MemberID],
				[C04_MemberKey],
				[C05_MemberID],
				[C05_MemberKey],
				[C06_MemberID],
				[C06_MemberKey],
				[C07_MemberID],
				[C07_MemberKey],
				[C08_MemberID],
				[C08_MemberKey],
				[C09_MemberID],
				[C09_MemberKey],
				[C10_MemberID],
				[C10_MemberKey],
				[H00_MemberID],
				[H00_MemberKey],
				[H01_MemberID],
				[H01_MemberKey],
				[H02_MemberID],
				[H02_MemberKey],
				[H03_MemberID],
				[H03_MemberKey],
				[H04_MemberID],
				[H04_MemberKey],
				[H05_MemberID],
				[H05_MemberKey],
				[H06_MemberID],
				[H06_MemberKey],
				[H07_MemberID],
				[H07_MemberKey],
				[H08_MemberID],
				[H08_MemberKey],
				[H09_MemberID],
				[H09_MemberKey],
				[H10_MemberID],
				[H10_MemberKey],
				[H11_MemberID],
				[H11_MemberKey],
				[H12_MemberID],
				[H12_MemberKey],
				[H13_MemberID],
				[H13_MemberKey],
				[H14_MemberID],
				[H14_MemberKey],
				[H15_MemberID],
				[H15_MemberKey],
				[H16_MemberID],
				[H16_MemberKey],
				[H17_MemberID],
				[H17_MemberKey],
				[H18_MemberID],
				[H18_MemberKey],
				[H19_MemberID],
				[H19_MemberKey],
				[H20_MemberID],
				[H20_MemberKey],
				[H21_MemberID],
				[H21_MemberKey],
				[H22_MemberID],
				[H22_MemberKey],
				[H23_MemberID],
				[H23_MemberKey],
				[H24_MemberID],
				[H24_MemberKey],
				[H25_MemberID],
				[H25_MemberKey],
				[P01],
				[P02],
				[P03],
				[P04],
				[P05],
				[P06],
				[P07],
				[P08],
				[P09],
				[P10],
				[DeleteYN] = ISNULL([DeleteYN], 0)
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				[MemberId] bigint,
				[MemberKey] nvarchar(100),
				[Description] nvarchar(255),
				[HelpText] nvarchar(1024),
				[D01_MemberID] bigint,
				[D01_MemberKey] nvarchar(100),
				[D02_MemberID] bigint,
				[D02_MemberKey] nvarchar(100),
				[D03_MemberID] bigint,
				[D03_MemberKey] nvarchar(100),
				[D04_MemberID] bigint,
				[D04_MemberKey] nvarchar(100),
				[D05_MemberID] bigint,
				[D05_MemberKey] nvarchar(100),
				[D06_MemberID] bigint,
				[D06_MemberKey] nvarchar(100),
				[D07_MemberID] bigint,
				[D07_MemberKey] nvarchar(100),
				[D08_MemberID] bigint,
				[D08_MemberKey] nvarchar(100),
				[D09_MemberID] bigint,
				[D09_MemberKey] nvarchar(100),
				[D10_MemberID] bigint,
				[D10_MemberKey] nvarchar(100),
				[C00_MemberID] bigint,
				[C00_MemberKey] nvarchar(100),
				[C01_MemberID] bigint,
				[C01_MemberKey] nvarchar(100),
				[C02_MemberID] bigint,
				[C02_MemberKey] nvarchar(100),
				[C03_MemberID] bigint,
				[C03_MemberKey] nvarchar(100),
				[C04_MemberID] bigint,
				[C04_MemberKey] nvarchar(100),
				[C05_MemberID] bigint,
				[C05_MemberKey] nvarchar(100),
				[C06_MemberID] bigint,
				[C06_MemberKey] nvarchar(100),
				[C07_MemberID] bigint,
				[C07_MemberKey] nvarchar(100),
				[C08_MemberID] bigint,
				[C08_MemberKey] nvarchar(100),
				[C09_MemberID] bigint,
				[C09_MemberKey] nvarchar(100),
				[C10_MemberID] bigint,
				[C10_MemberKey] nvarchar(100),
				[H00_MemberID] bigint,
				[H00_MemberKey] nvarchar(100),
				[H01_MemberID] bigint,
				[H01_MemberKey] nvarchar(100),
				[H02_MemberID] bigint,
				[H02_MemberKey] nvarchar(100),
				[H03_MemberID] bigint,
				[H03_MemberKey] nvarchar(100),
				[H04_MemberID] bigint,
				[H04_MemberKey] nvarchar(100),
				[H05_MemberID] bigint,
				[H05_MemberKey] nvarchar(100),
				[H06_MemberID] bigint,
				[H06_MemberKey] nvarchar(100),
				[H07_MemberID] bigint,
				[H07_MemberKey] nvarchar(100),
				[H08_MemberID] bigint,
				[H08_MemberKey] nvarchar(100),
				[H09_MemberID] bigint,
				[H09_MemberKey] nvarchar(100),
				[H10_MemberID] bigint,
				[H10_MemberKey] nvarchar(100),
				[H11_MemberID] bigint,
				[H11_MemberKey] nvarchar(100),
				[H12_MemberID] bigint,
				[H12_MemberKey] nvarchar(100),
				[H13_MemberID] bigint,
				[H13_MemberKey] nvarchar(100),
				[H14_MemberID] bigint,
				[H14_MemberKey] nvarchar(100),
				[H15_MemberID] bigint,
				[H15_MemberKey] nvarchar(100),
				[H16_MemberID] bigint,
				[H16_MemberKey] nvarchar(100),
				[H17_MemberID] bigint,
				[H17_MemberKey] nvarchar(100),
				[H18_MemberID] bigint,
				[H18_MemberKey] nvarchar(100),
				[H19_MemberID] bigint,
				[H19_MemberKey] nvarchar(100),
				[H20_MemberID] bigint,
				[H20_MemberKey] nvarchar(100),
				[H21_MemberID] bigint,
				[H21_MemberKey] nvarchar(100),
				[H22_MemberID] bigint,
				[H22_MemberKey] nvarchar(100),
				[H23_MemberID] bigint,
				[H23_MemberKey] nvarchar(100),
				[H24_MemberID] bigint,
				[H24_MemberKey] nvarchar(100),
				[H25_MemberID] bigint,
				[H25_MemberKey] nvarchar(100),
				[P01] nvarchar(255),
				[P02] nvarchar(255),
				[P03] nvarchar(255),
				[P04] nvarchar(255),
				[P05] nvarchar(255),
				[P06] nvarchar(255),
				[P07] nvarchar(255),
				[P08] nvarchar(255),
				[P09] nvarchar(255),
				[P10] nvarchar(255),
				[DeleteYN] bit
				)
		ELSE
			GOTO EXITPOINT

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_1', * FROM #LeafMemberTable

	SET @Step = 'Create and fill temp table #Column'
		CREATE TABLE #Column
			(
			[ColumnCode] nchar(3) COLLATE DATABASE_DEFAULT,
			[ColumnName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DimensionID] int,
			[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[VisibleYN] bit,
			[SortOrder] int
			)

		--EXEC [spGet_Category_Column]
		--	@UserID = @UserID,
		--	@InstanceID = @InstanceID,
		--	@VersionID = @VersionID,
		--	@DimensionID = @DimensionID,
		--	@JobID = @JobID

		EXEC [spGet_DimensionMember_List_Column]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DimensionID = @DimensionID,
			@NodeTypeBM = 3, --@NodeTypeBM,
--			@ObjectGuiBehaviorBM = @ObjectGuiBehaviorBM,
			@JobID = @JobID,
			@Debug = @DebugSub

		IF @DebugBM & 2 > 0
			SELECT TempTable = '#Column', * FROM #Column ORDER BY [ColumnCode]

	SET @Step = 'Add new categories'
		CREATE TABLE #Category
			(
			[Category_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			)

		IF CURSOR_STATUS('global','Category_Cursor') >= -1 DEALLOCATE Category_Cursor
		DECLARE Category_Cursor CURSOR FOR
			
			SELECT 
				[ColumnCode]
			FROM
				#Column C
			WHERE
				[ColumnCode] LIKE 'C%'
			ORDER BY
				[ColumnCode]

			OPEN Category_Cursor
			FETCH NEXT FROM Category_Cursor INTO @ColumnCode

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ColumnCode] = @ColumnCode

					SET @SQLStatement = '
						INSERT INTO #Category
							(
							[Category_MemberKey]
							)
						SELECT DISTINCT
							[Category_MemberKey] = LMT.[' + @ColumnCode + '_MemberKey]
						FROM
							#LeafMemberTable LMT
						WHERE
							LMT.[' + @ColumnCode + '_MemberKey] IS NOT NULL AND
							LMT.[' + @ColumnCode + '_MemberID] IS NULL AND
							NOT EXISTS (SELECT 1 FROM #Category C WHERE C.[Category_MemberKey] = LMT.[' + @ColumnCode + '_MemberKey])'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Category_Cursor INTO @ColumnCode
				END

		CLOSE Category_Cursor
		DEALLOCATE Category_Cursor

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Category', * FROM #Category ORDER BY Category_MemberKey

		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
				(
				[Label],
				[Description],
				[HelpText],
				[Inserted],
				[JobID],'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized],
				[Updated]
				)
			SELECT
				[Label] = C.[Category_MemberKey],
				[Description] = C.[Category_MemberKey],
				[HelpText] = C.[Category_MemberKey],
				[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',
				[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ','
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM] = 1042,' ELSE '' END + '
				[RNodeType] = ''P'',
				[SBZ] = 1,
				[Source] = ''Manually Loaded'',
				[Synchronized] = 0,
				[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + '''
			FROM
				#Category C
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D WHERE D.[Label] = C.[Category_MemberKey])'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Update dim columns in #LeafMemberTable'
		IF CURSOR_STATUS('global','Column_Cursor') >= -1 DEALLOCATE Column_Cursor
		DECLARE Column_Cursor CURSOR FOR
			
			SELECT 
				[ColumnCode],
				[ColumnName],
				[DimensionName] = ISNULL(C.[DimensionName], @DimensionName)
			FROM
				#Column C
			WHERE
				[ColumnCode] NOT LIKE 'P%'
			ORDER BY
				[ColumnCode]

			OPEN Column_Cursor
			FETCH NEXT FROM Column_Cursor INTO @ColumnCode, @ColumnName, @SubDimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ColumnCode] = @ColumnCode, [@ColumnName] = @ColumnName, [@SubDimensionName] = @SubDimensionName

					SET @SQLStatement = '
						UPDATE LMT
						SET
							[' + @ColumnCode + '_MemberKey] = ISNULL(LMT.[' + @ColumnCode + '_MemberKey], D.[Label]),
							[' + @ColumnCode + '_MemberId] = ISNULL(LMT.[' + @ColumnCode + '_MemberID], D.[MemberId])' +
							CASE WHEN @ColumnCode LIKE 'D%' THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @ColumnCode + '_Description] = D.[Description]' ELSE '' END + '
						FROM
							#LeafMemberTable LMT
							INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @SubDimensionName + '] D ON D.[Label] = LMT.[' + @ColumnCode + '_MemberKey] OR D.[MemberId] = LMT.[' + @ColumnCode + '_MemberId]
						WHERE
							LMT.[DeleteYN] = 0'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Column_Cursor INTO @ColumnCode, @ColumnName, @SubDimensionName
				END

		CLOSE Column_Cursor
		DEALLOCATE Column_Cursor

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_2', * FROM #LeafMemberTable

	SET @Step = 'Update property columns in #LeafMemberTable'
		UPDATE LMT
		SET
			[MemberKey] = ISNULL(LMT.[MemberKey], REVERSE(STUFF(REVERSE(
								CASE WHEN [D01_MemberKey] IS NOT NULL THEN [D01_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D02_MemberKey] IS NOT NULL THEN [D02_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D03_MemberKey] IS NOT NULL THEN [D03_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D04_MemberKey] IS NOT NULL THEN [D04_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D05_MemberKey] IS NOT NULL THEN [D05_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D06_MemberKey] IS NOT NULL THEN [D06_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D07_MemberKey] IS NOT NULL THEN [D07_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D08_MemberKey] IS NOT NULL THEN [D08_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D09_MemberKey] IS NOT NULL THEN [D09_MemberKey] + @Punctuation ELSE '' END +
								CASE WHEN [D10_MemberKey] IS NOT NULL THEN [D10_MemberKey] + @Punctuation ELSE '' END), 1, LEN(@Punctuation), ''))),
			[Description] = ISNULL(LMT.[Description], REVERSE(STUFF(REVERSE(
								CASE WHEN [D01_Description] IS NOT NULL THEN [D01_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D02_Description] IS NOT NULL THEN [D02_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D03_Description] IS NOT NULL THEN [D03_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D04_Description] IS NOT NULL THEN [D04_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D05_Description] IS NOT NULL THEN [D05_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D06_Description] IS NOT NULL THEN [D06_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D07_Description] IS NOT NULL THEN [D07_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D08_Description] IS NOT NULL THEN [D08_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D09_Description] IS NOT NULL THEN [D09_Description] + @DescriptionPunctuation ELSE '' END +
								CASE WHEN [D10_Description] IS NOT NULL THEN [D10_Description] + @DescriptionPunctuation ELSE '' END), 1, LEN(@DescriptionPunctuation), ''))),
			[HelpText] = COALESCE(LMT.[HelpText], LMT.[Description], REVERSE(STUFF(REVERSE(
								CASE WHEN [D01_Description] IS NOT NULL THEN [D01_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D02_Description] IS NOT NULL THEN [D02_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D03_Description] IS NOT NULL THEN [D03_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D04_Description] IS NOT NULL THEN [D04_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D05_Description] IS NOT NULL THEN [D05_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D06_Description] IS NOT NULL THEN [D06_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D07_Description] IS NOT NULL THEN [D07_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D08_Description] IS NOT NULL THEN [D08_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D09_Description] IS NOT NULL THEN [D09_Description] + @DescriptionPunctuation ELSE '' END +
								CASE WHEN [D10_Description] IS NOT NULL THEN [D10_Description] + @DescriptionPunctuation ELSE '' END), 1, LEN(@DescriptionPunctuation), '')))
		FROM
			#LeafMemberTable LMT
		WHERE
			LMT.[MemberId] IS NULL AND
			LMT.[DeleteYN] = 0

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_3', * FROM #LeafMemberTable

	SET @Step = 'Update identification columns in #LeafMemberTable'
		SET @SQLStatement = '
			UPDATE LMT
			SET
				[MemberKey] = ISNULL(LMT.[MemberKey], D.[Label]),
				[MemberId] = ISNULL(LMT.[MemberID], D.[MemberId])
			FROM
				#LeafMemberTable LMT
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[Label] = LMT.[MemberKey] OR D.[MemberId] = LMT.[MemberId]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_4', * FROM #LeafMemberTable

	SET @Step = 'Delete dimension members'
		IF @DebugBM & 2 > 0 SELECT [@Step] = @Step, * FROM #LeafMemberTable WHERE [DeleteYN] <> 0

		SET @SQLStatement = '
			DELETE D
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
				INNER JOIN #LeafMemberTable LMT ON LMT.[MemberID] = D.[MemberID] AND LMT.[DeleteYN] <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Update dimension properties'
		IF @DebugBM & 2 > 0 SELECT [@Step] = @Step, * FROM #LeafMemberTable WHERE [DeleteYN] = 0 AND [MemberId] IS NOT NULL
/*
		SET @SQLStatement = '
			UPDATE D
			SET
				[Description] = ISNULL(LMT.[Description], D.[Description]),
				[HelpText] = ISNULL(LMT.[HelpText], D.[HelpText]),'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM] = ISNULL(D.[NodeTypeBM], 1),' ELSE '' END + '
				[RNodeType] = ISNULL(D.[RNodeType], ''L''),
				[SBZ] = ISNULL(D.[SBZ], 0),
				[Source] = ISNULL(D.[Source], ''MANUAL''),
				[Synchronized] = ISNULL(D.[Synchronized], 1)'
*/
		SET @SQLStatement = '
			UPDATE D
			SET
				[Description] = ISNULL(LMT.[Description], D.[Description]),
				[HelpText] = ISNULL(LMT.[HelpText], D.[HelpText]),'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM] = ISNULL(D.[NodeTypeBM], ' + CONVERT(NVARCHAR(10), @NodeTypeBM) + '),' ELSE '' END + '
				[RNodeType] = ISNULL(D.[RNodeType], ' + CASE @NodeTypeBM WHEN 1042 THEN '''P''' WHEN 2 THEN '''P''' ELSE '''L''' END + '),
				[SBZ] = ISNULL(D.[SBZ], 0),
				[Source] = ISNULL(D.[Source], ''MANUAL''),
				[Synchronized] = ISNULL(D.[Synchronized], 1)'

		SELECT
			@SQLStatement = @SQLStatement + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '] = ISNULL(LMT.[' + [ColumnCode] + '_MemberKey], D.[' + [ColumnName] + ']),' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '_MemberId] = ISNULL(LMT.[' + [ColumnCode] + '_MemberId], D.[' + [ColumnName] + '_MemberId])'
		FROM
			#Column
		WHERE
			LEFT([ColumnCode], 1) = 'D'
		ORDER BY
			[ColumnCode]

		SELECT
			@SQLStatement = @SQLStatement + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '] = ISNULL(LMT.[' + [ColumnCode] + '], D.[' + [ColumnName] + '])'
		FROM
			#Column
		WHERE
			LEFT([ColumnCode], 1) = 'P'
		ORDER BY
			[ColumnCode]

		SET @SQLStatement = @SQLStatement + '
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
				INNER JOIN #LeafMemberTable LMT ON LMT.[DeleteYN] = 0 AND LMT.[MemberID] = D.[MemberId]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert new dimension members'
		IF @DebugBM & 2 > 0 SELECT [@Step] = @Step, * FROM #LeafMemberTable WHERE [DeleteYN] = 0 AND [MemberId] IS NULL

		SELECT
			@SQL_Dimension_Insert = @SQL_Dimension_Insert + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '],' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '_MemberId]',
			@SQL_Dimension_Select = @SQL_Dimension_Select + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '] = LMT.[' + [ColumnCode] + '_MemberKey],' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '_MemberId] = LMT.[' + [ColumnCode] + '_MemberId]'
		FROM
			#Column
		WHERE
			LEFT([ColumnCode], 1) = 'D'
		ORDER BY
			[ColumnCode]

		SELECT
			@SQL_Property_Insert = @SQL_Property_Insert + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + ']',
			@SQL_Property_Select = @SQL_Property_Select + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '] = LMT.[' + [ColumnCode] + ']'
		FROM
			#Column
		WHERE
			LEFT([ColumnCode], 1) = 'P'
		ORDER BY
			[ColumnCode]			
/*			
		SET @SQLStatement = '		
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
				(
				[Label],
				[Description],
				[HelpText],'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]' + @SQL_Dimension_Insert + @SQL_Property_Insert + '
				)
			SELECT
				[Label] = LMT.[MemberKey],
				[Description] = LMT.[Description],
				[HelpText] = LMT.[Description],'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM] = 1,' ELSE '' END + '
				[RNodeType] = ''L'',
				[SBZ] = 0,
				[Source] = ''MANUAL'',
				[Synchronized] = 1' + @SQL_Dimension_Select + @SQL_Property_Select + '
			FROM
				#LeafMemberTable LMT
			WHERE
				LMT.[DeleteYN] = 0 AND
				LMT.[MemberID] IS NULL'
*/
		SET @SQLStatement = '		
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
				(
				[Label],
				[Description],
				[HelpText],'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]' + @SQL_Dimension_Insert + @SQL_Property_Insert + '
				)
			SELECT
				[Label] = LMT.[MemberKey],
				[Description] = LMT.[Description],
				[HelpText] = LMT.[Description],'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM] = ' + CONVERT(NVARCHAR(10), @NodeTypeBM) + ',' ELSE '' END + '
				[RNodeType] = ' + CASE @NodeTypeBM WHEN 1042 THEN '''P''' WHEN 2 THEN '''P''' ELSE '''L''' END + ',
				[SBZ] = 0,
				[Source] = ''MANUAL'',
				[Synchronized] = 1' + @SQL_Dimension_Select + @SQL_Property_Select + '
			FROM
				#LeafMemberTable LMT
			WHERE
				LMT.[DeleteYN] = 0 AND
				LMT.[MemberID] IS NULL'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

		--Update MemberID in #LeafMemberTable
		SET @SQLStatement = '	
			UPDATE LMT
			SET
				[MemberID] = D.[MemberId]
			FROM
				#LeafMemberTable LMT
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[Label] = LMT.[MemberKey]
			WHERE
				LMT.[DeleteYN] = 0 AND
				LMT.[MemberID] IS NULL'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_5', * FROM #LeafMemberTable

	SET @Step = 'Update Account dimension properties [Sign], [TimeBalance] and [Rate] based from [AccountType] value'
		IF (@DimensionID = -1) --Update property [AccountType] for [Account] dimension only
			BEGIN
				CREATE TABLE #AccountType
					(
					[MemberId] bigint, 
					[Label] nvarchar(255) COLLATE DATABASE_DEFAULT, 
					[Account Type] nvarchar(50) COLLATE DATABASE_DEFAULT, 
					[Sign] int, 
					[TimeBalance] bit, 
					[Rate_MemberId] bigint, 
					[Rate] nvarchar(255) COLLATE DATABASE_DEFAULT
					)
			
				SET @SQLStatement = '
					INSERT INTO #AccountType
						(
						[MemberId], 
						[Label], 
						[Account Type], 
						[Sign], 
						[TimeBalance], 
						[Rate_MemberId], 
						[Rate] 
						)
					SELECT 
						[MemberId], 
						[Label], 
						[Account Type], 
						[Sign], 
						[TimeBalance], 
						[Rate_MemberId], 
						[Rate]
					FROM 
						[' + @CallistoDatabase + '].[dbo].[S_DS_AccountType] D
					WHERE
						D.[MemberId] NOT IN (1, 2, 1000)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#AccountType', * FROM #AccountType

				SET @SQLStatement = '	
					UPDATE D
					SET
						[AccountType_MemberID] = AT.[MemberId],
						[Account Type] = AT.[Account Type],
						[Sign] = AT.[Sign],
						[TimeBalance] = AT.[TimeBalance],
						[Rate_MemberId] = AT.[Rate_MemberId], 
						[Rate] = AT.[Rate]
					FROM
						[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
						INNER JOIN #LeafMemberTable LMT ON LMT.[DeleteYN] = 0 AND LMT.[MemberKey] = D.[Label]
						INNER JOIN #AccountType AT ON AT.[Label] = D.[AccountType]
						INNER JOIN #Column C ON C.[ColumnName] = ''AccountType'' AND LEFT(C.[ColumnCode], 1) = ''P'' 
					WHERE
						D.[AccountType] IS NOT NULL'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Hierarchy members, (Update, Insert and Delete)'
		IF CURSOR_STATUS('global','HierarchyMember_Cursor') >= -1 DEALLOCATE HierarchyMember_Cursor
		DECLARE HierarchyMember_Cursor CURSOR FOR
			
			SELECT
				[ColumnCode],
				[HierarchyName] = [ColumnName]
			FROM
				#Column
			WHERE
				LEFT([ColumnCode], 1) IN ('C', 'H')
			ORDER BY
				[ColumnCode]	

			OPEN HierarchyMember_Cursor
			FETCH NEXT FROM HierarchyMember_Cursor INTO @ColumnCode, @HierarchyName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @Dimensionhierarchy = @DimensionName + '_' + ISNULL(@HierarchyName,  @DimensionName)
					IF @DebugBM & 2 > 0 SELECT [@ColumnCode] = @ColumnCode, [@HierarchyName] = @HierarchyName, [@Dimensionhierarchy] = @Dimensionhierarchy

					SET @SQLStatement = '
						DELETE H
						FROM
							[' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + '] H
							INNER JOIN #LeafMemberTable LMT ON LMT.[MemberID] = H.[MemberID] AND (LMT.[' + @ColumnCode + '_MemberID] IS NOT NULL OR LMT.[DeleteYN] <> 0)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @ListType = 'Category'
						BEGIN
							SET @SQLStatement = '
								INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + ']
									(
									[MemberID],
									[ParentMemberID],
									[SequenceNumber]
									)
								SELECT DISTINCT
									[MemberID] = LMT.[' + @ColumnCode + '_MemberID],
									[ParentMemberID] = 1,
									[SequenceNumber] = LMT.[' + @ColumnCode + '_MemberID]
								FROM
									#LeafMemberTable LMT 
								WHERE
									LMT.[DeleteYN] = 0 AND
									ISNULL(LMT.[' + @ColumnCode + '_MemberID], '''') <> '''' AND
									NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + '] H WHERE H.[MemberID] = LMT.[' + @ColumnCode + '_MemberID])'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = '
						INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + ']
							(
							[MemberID],
							[ParentMemberID],
							[SequenceNumber]
							)
						SELECT DISTINCT
							[MemberID] = LMT.[MemberID],
							[ParentMemberID] = LMT.[' + @ColumnCode + '_MemberID],
							[SequenceNumber] = LMT.[MemberID]
						FROM
							#LeafMemberTable LMT 
						WHERE
							LMT.[DeleteYN] = 0 AND
							ISNULL(LMT.[MemberID], '''') <> '''' AND
							ISNULL(LMT.[' + @ColumnCode + '_MemberID], '''') <> '''' AND
							NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + '] H WHERE H.[MemberID] = LMT.[MemberID])'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Updated = @Updated + @@ROWCOUNT

					IF @EnhancedStorageYN = 0
						EXEC [pcINTEGRATOR].[dbo].[spSet_HierarchyCopy] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Database = @CallistoDatabase, @Dimensionhierarchy = @Dimensionhierarchy, @JobID = @JobID, @Debug = @DebugSub

					FETCH NEXT FROM HierarchyMember_Cursor INTO @ColumnCode, @HierarchyName
				END

		CLOSE HierarchyMember_Cursor
		DEALLOCATE HierarchyMember_Cursor
		
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
