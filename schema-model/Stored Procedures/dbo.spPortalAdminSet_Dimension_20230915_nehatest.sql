SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create PROCEDURE [dbo].[spPortalAdminSet_Dimension_20230915_nehatest]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JSON_table nvarchar(MAX) = NULL,
	@ResultTypeBM int = NULL, --1  Dimension, 2 = Property, 4 = Hierarchy, 8 = HierarchyLevel, 16 = Delete DimensionMembers, 4096 = Multidim
	@SetupCallistoYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000284,
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
--Create Dimension
EXEC [spRun_Procedure_KeyValuePair] @JSON='[
{"TKey":"DebugBM","TValue":"7"},
{"TKey":"InstanceID","TValue":"413"},
{"TKey":"UserID","TValue":"2147"},
{"TKey":"VersionID","TValue":"1008"}]', 
@JSON_table='[
{"ResultTypeBM":"1","DimensionID":null,"DimensionName":"TestGenericDim3","DimensionDescription":"TestGenericDim3 Description",
"DimensionTypeID":"0","StorageTypeBM":"4","ReadSecurityEnabledYN":false,"ReplaceStringYN":false,"DeleteYN":"0"}
]', @ProcedureName='spPortalAdminSet_Dimension', @XML=null

EXEC [spRun_Procedure_KeyValuePair] @JSON='[
{"TKey":"InstanceID","TValue":"413"},{"TKey":"UserID","TValue":"2147"},{"TKey":"VersionID","TValue":"1008"}
]', @JSON_table='[
{"ResultTypeBM":"8","DimensionID":"-1","HierarchyNo":"1","HierarchyName":"test_hierarchy1","LevelNo":"1","LevelName":"TopNode","DeleteYN":"0"},
{"ResultTypeBM":"8","DimensionID":"-1","HierarchyNo":"1","HierarchyName":"test_hierarchy1","LevelNo":"2","LevelName":"Parent","DeleteYN":"0"}
]', @ProcedureName='spPortalAdminSet_Dimension', @XML=null

EXEC [spRun_Procedure_KeyValuePair] @JSON='[
{"TKey":"InstanceID","TValue":"413"},{"TKey":"UserID","TValue":"2147"},{"TKey":"VersionID","TValue":"1008"}]', 
@JSON_table='[
{"ResultTypeBM":"8","DimensionID":"1038","HierarchyNo":"1","HierarchyName":"GL_Test1","LevelNo":"1","LevelName":"TopNode","DeleteYN":"0"},
{"ResultTypeBM":"8","DimensionID":"1038","HierarchyNo":"1","HierarchyName":"GL_Test1","LevelNo":"2","LevelName":"Parent","DeleteYN":"0"},
{"ResultTypeBM":"8","DimensionID":"1038","HierarchyNo":"1","HierarchyName":"GL_Test1","LevelNo":"3","LevelName":"GL_TestLevel1","DeleteYN":"0"}
]', @ProcedureName='spPortalAdminSet_Dimension', @XML=null

DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "1", "DimensionID": "5592", "DimensionName": "GL_K"},
	{"ResultTypeBM" : "1", "DimensionID": "5598", "DeleteYN": "1"},
	{"ResultTypeBM" : "1", "DimensionName": "test2", "DimensionDescription": "Test2 description", "StorageTypeBM": "4"},
	{"ResultTypeBM" : "2", "PropertyID": "-212", "DimensionID": "5592"},
	{"ResultTypeBM" : "2", "PropertyName": "Test7", "PropertyDescription": "Test7 Description", "DataTypeID": "1", "DimensionID": "5592"},
	{"ResultTypeBM" : "4", "DimensionID": "5592", "HierarchyName": "test3", "HierarchyDescription": "Test 3 Description"},
	{"ResultTypeBM" : "4", "HierarchyNo": "1001", "DeleteYN": "1"},
	{"ResultTypeBM" : "8", "DimensionID": "5592", "HierarchyName": "test3", "LevelNo": "1", "LevelName": "TopNode"},
	{"ResultTypeBM" : "8", "DimensionID": "5592", "HierarchyName": "test3", "LevelNo": "2", "LevelName": "Parent"},
	{"ResultTypeBM" : "8", "DimensionID": "5592", "HierarchyName": "test3", "LevelNo": "3", "LevelName": "GL_K"}
	]'		
EXEC [spPortalAdminSet_Dimension]
	@UserID=-10,
	@InstanceID=15,
	@VersionID=1039,
	@JSON_table = @JSON_table,
	@DebugBM=1

DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "4", "DimensionID": "-1", "HierarchyName": "TestHN1", "HierarchyDescription": "Test HierarchyName1"}
	]'		
EXEC [spPortalAdminSet_Dimension]
	@UserID=-10,
	@InstanceID=454,
	@VersionID=1021,
	@JSON_table = @JSON_table,
	@DebugBM=7

--Delete DimensionMember
EXEC [spRun_Procedure_KeyValuePair] 
@JSON='[{"TKey":"UserID","TValue":"-10"},{"TKey":"InstanceID","TValue":"413"},{"TKey":"VersionID","TValue":"1008"},{"TKey":"DebugBM","TValue":"2"}]', 
@JSON_table='[{"ResultTypeBM":"16","DimensionID":"-63","DimensionName":"WorkflowState","DimensionMemberID":"30004401","DimensionMemberKey":"TestL","DeleteYN":"1"}]',
@ProcedureName='spPortalAdminSet_Dimension'

--Delete Multiple DimensionMembers
EXEC [spRun_Procedure_KeyValuePair] 
@JSON='[{"TKey":"UserID","TValue":"-10"},{"TKey":"InstanceID","TValue":"454"},{"TKey":"VersionID","TValue":"1021"},{"TKey":"DebugBM","TValue":"2"}]', 
@JSON_table='[
{"ResultTypeBM":"16","DimensionID":"-63","DimensionName":"WorkflowState","DimensionMemberID":"30004690","DimensionMemberKey":"TestP","DeleteYN":"1"},
{"ResultTypeBM":"16","DimensionID":"-63","DimensionName":"WorkflowState","DimensionMemberID":"30004691","DimensionMemberKey":"TestL","DeleteYN":"1"}
]',
@ProcedureName='spPortalAdminSet_Dimension'

--Update, Delete, Insert MultiDims
EXEC [spRun_Procedure_KeyValuePair] 
@JSON='[{"TKey":"UserID","TValue":"-10"},{"TKey":"InstanceID","TValue":"531"},{"TKey":"VersionID","TValue":"1041"},{"TKey":"DebugBM","TValue":"2"}]', 
@JSON_table='[
{"ResultTypeBM":"4096","DimensionID":"9155","DependentDimensionID":"-1","SortOrder":"10","DeleteYN":"0"},
{"ResultTypeBM":"4096","DimensionID":"9155","DependentDimensionID":"9106","SortOrder":"20","DeleteYN":"0"},
{"ResultTypeBM":"4096","DimensionID":"9155","DependentDimensionID":"9107","SortOrder":"30","DeleteYN":"0"},
{"ResultTypeBM":"4096","DimensionID":"9155","DataClassID":"13864","DeleteYN":"0"}
]',
@ProcedureName='spPortalAdminSet_Dimension'

EXEC [spPortalAdminSet_Dimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,
	@Inserted_Local int,
	@DimensionID int,
	@DimensionMemberID int,
	@StorageTypeBM int,
	@PropertyID int,
	@DimensionName nvarchar(50),
	@PropertyName nvarchar(50),
	@HierarchyName nvarchar(50),
	@HierarchyNo int,
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@DependentDimensionID int,
	@SortOrder int,
	@DimensionTypeID int,
	@EnhancedStorageYN int,

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
	@Version nvarchar(50) = '2.1.2.2198'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain table Dimension and corresponding tables',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'Added multiple @ResultTypeBM and @JSON table.'
		IF @Version = '2.1.0.2155' SET @Description = 'Added ReplaceStringYN. Set default SortOrder value for Dimension_Property table. Added Step to Add standard rows to newly created dimension.'
		IF @Version = '2.1.0.2156' SET @Description = 'DB-470: Added @ResultTypeBM 16 (Delete Dimension members).'
		IF @Version = '2.1.0.2157' SET @Description = 'DB-469: Include BusinessRules when executing [spSetup_Callisto] for ResultTypeBM 1 & 4.'
		IF @Version = '2.1.0.2161' SET @Description = 'For @ResultTypeBM=4 (Insert), Set @HierarchyNo = 1 if NULL.'
		IF @Version = '2.1.0.2162' SET @Description = 'DB-570: Create default Callisto [HL_*] table for newly added Dimension/Hierarchy. For @ResultTypeBM=4 (Insert), set default [DimensionHierarchyLevel]. DB-576: Modified DELETE query for ResultTypeBM=1 (Dimension) and ResultTypeBM=4 (Hierarchy).'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-726: Minor bug fixed. Add property NodeTypeBM if any Hierarchy of type 2 exists. AccountType if Account is added where MultiDimYN <> 0.'
		IF @Version = '2.1.2.2179' SET @Description = 'Updated list of Hierarchy properties. NodeTypeBM for Properties is implemented.'
		IF @Version = '2.1.2.2191' SET @Description = 'Handle @EnhancedStorageYN'
		IF @Version = '2.1.2.2198' SET @Description = 'Added @JobID parameter in the sub call to [spIU_Dim_Dimension_Generic_Callisto]. Added new parameter @SetupCallistoYN and increased debugging. DB-1549: Added INSERT query to Callisto [HS_*] table for ResultTypeBM=4 (Hierarchy); enabled Callisto Setup for creation of Dimension (ResultypeBM 1) and DimensionHierarchy (ResultTypeBM 4).'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@CallistoDatabase = [DestinationDatabase],
			@EnhancedStorageYN = [EnhancedStorageYN]
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create and fill #DimList'
		CREATE TABLE #DimList
			(
			[ResultTypeBM] int,
			[DimensionID] int,
			[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DimensionDescription] nvarchar(255) COLLATE DATABASE_DEFAULT,					
			[DimensionMemberID] int,
			[DimensionMemberKey] nvarchar(255) COLLATE DATABASE_DEFAULT,	
			[DimensionTypeID] int,
			[ReportOnlyYN] bit,
			[MasterDimensionID] int,
			[SeedMemberID] int,
			[LoadSP] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] int,
			[ObjectGuiBehaviorBM] int,
			[ReadSecurityEnabledYN] bit,
			[MappingTypeID] int,
			[ReplaceStringYN] bit,
			[DefaultSetMemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DefaultGetMemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DefaultGetHierarchyNo] int,
			[ModelingStatusID] int,
			[ModelingComment] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[Comment] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[PropertyID] int,
			[PropertyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[PropertyDescription] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[DataTypeID] int,
			[Size] int,
			[DependentDimensionID] int,
			[DefaultSetValue] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[SynchronizedYN] bit,
			[DependencyPrio] int,
			[MultiDimYN] bit,
			[TabularYN] bit,
			[NodeTypeBM] int,
			[CopyFromHierarchyNo] int,
			[HierarchyNo] int,
			[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[HierarchyTypeID] int,
			[FixedLevelsYN] bit,
			[BaseDimension] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BaseHierarchy] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BaseDimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[PropertyHierarchy] nvarchar(1000) COLLATE DATABASE_DEFAULT,
			[BusinessRuleID] int,
			[LockedYN] bit,
			[LevelNo] int,
			[LevelName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DataClassID] int,
			[SortOrder] int,
			[SelectYN] bit,
			[DeleteYN] bit
			)

		IF @JSON_table IS NOT NULL	
			INSERT INTO #DimList
				(
				[ResultTypeBM],
				[DimensionID],
				[DimensionName],
				[DimensionDescription],
				[DimensionMemberID],
				[DimensionMemberKey],
				[DimensionTypeID],
				[ReportOnlyYN],
				[MasterDimensionID],
				[SeedMemberID],
				[LoadSP],
				[DimensionFilter],
				[StorageTypeBM],
				[ObjectGuiBehaviorBM],
				[ReadSecurityEnabledYN],
				[MappingTypeID],
				[ReplaceStringYN],
				[DefaultSetMemberKey],
				[DefaultGetMemberKey],
				[DefaultGetHierarchyNo],
				[ModelingStatusID],
				[ModelingComment],
				[Comment],
				[PropertyID],
				[PropertyName],
				[PropertyDescription],
				[DataTypeID],
				[Size],
				[DependentDimensionID],
				[DefaultSetValue],
				[SynchronizedYN],
				[DependencyPrio],
				[MultiDimYN],
				[TabularYN],
				[NodeTypeBM],
				[CopyFromHierarchyNo],
				[HierarchyNo],
				[HierarchyName],
				[HierarchyTypeID],
				[FixedLevelsYN],
				[BaseDimension],
				[BaseHierarchy],
				[BaseDimensionFilter],
				[PropertyHierarchy],
				[BusinessRuleID],
				[LockedYN],
				[LevelNo],
				[LevelName],
				[DataClassID],
				[SortOrder],
				[SelectYN],
				[DeleteYN]
				)
			SELECT
				[ResultTypeBM],
				[DimensionID],
				[DimensionName],
				[DimensionDescription],
				[DimensionMemberID],
				[DimensionMemberKey],
				[DimensionTypeID],
				[ReportOnlyYN],
				[MasterDimensionID],
				[SeedMemberID],
				[LoadSP],
				[DimensionFilter],
				[StorageTypeBM],
				[ObjectGuiBehaviorBM],
				[ReadSecurityEnabledYN],
				[MappingTypeID],
				[ReplaceStringYN],
				[DefaultSetMemberKey],
				[DefaultGetMemberKey],
				[DefaultGetHierarchyNo],
				[ModelingStatusID],
				[ModelingComment],
				[Comment],
				[PropertyID],
				[PropertyName],
				[PropertyDescription],
				[DataTypeID],
				[Size],
				[DependentDimensionID],
				[DefaultSetValue],
				[SynchronizedYN],
				[DependencyPrio],
				[MultiDimYN],
				[TabularYN],
				[NodeTypeBM],
				[CopyFromHierarchyNo],
				[HierarchyNo],
				[HierarchyName],
				[HierarchyTypeID],
				[FixedLevelsYN],
				[BaseDimension],
				[BaseHierarchy],
				[BaseDimensionFilter],
				[PropertyHierarchy],
				[BusinessRuleID],
				[LockedYN],
				[LevelNo],
				[LevelName],
				[DataClassID],
				[SortOrder],
				[SelectYN] = ISNULL([SelectYN], 1),
				[DeleteYN] = ISNULL([DeleteYN], 0)
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				[ResultTypeBM] int,
				[DimensionID] int,
				[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[DimensionDescription] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[DimensionMemberID] int,
				[DimensionMemberKey] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[DimensionTypeID] int,
				[ReportOnlyYN] bit,
				[MasterDimensionID] int,
				[SeedMemberID] int,
				[LoadSP] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[DimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
				[StorageTypeBM] int,
				[ObjectGuiBehaviorBM] int,
				[ReadSecurityEnabledYN] bit,
				[MappingTypeID] int,
				[ReplaceStringYN] bit,
				[DefaultSetMemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[DefaultGetMemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[DefaultGetHierarchyNo] int,
				[ModelingStatusID] int,
				[ModelingComment] nvarchar(1024) COLLATE DATABASE_DEFAULT,
				[Comment] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[PropertyID] int,
				[PropertyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[PropertyDescription] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[DataTypeID] int,
				[Size] int,
				[DependentDimensionID] int,
				[DefaultSetValue] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[SynchronizedYN] bit,
				[DependencyPrio] int,
				[MultiDimYN] bit,
				[TabularYN] bit,
				[NodeTypeBM] int,
				[CopyFromHierarchyNo] int,
				[HierarchyNo] int,
				[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[HierarchyTypeID] int,
				[FixedLevelsYN] bit,
				[BaseDimension] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[BaseHierarchy] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[BaseDimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
				[PropertyHierarchy] nvarchar(1000) COLLATE DATABASE_DEFAULT,
				[BusinessRuleID] int,
				[LockedYN] bit,
				[LevelNo] int,
				[LevelName] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[DataClassID] int,
				[SortOrder] int,
				[SelectYN] bit,
				[DeleteYN] bit
				)

		UPDATE DL
		SET
			[HierarchyNo] = ISNULL(DL.[HierarchyNo], 0)
		FROM
			#DimList DL
			INNER JOIN dbo.[Dimension] D ON D.[DimensionID] = DL.[DimensionID] AND D.[DimensionName] = DL.[HierarchyName]
		WHERE
			DL.ResultTypeBM & 4 > 0 

		UPDATE DL
		SET
			[DimensionTypeID] = ISNULL(DL.[DimensionTypeID], D.[DimensionTypeID]),
			[DimensionName] = ISNULL(DL.[DimensionName], D.[DimensionName])
		FROM
			#DimList DL
			INNER JOIN dbo.[Dimension] D ON D.[DimensionID] = DL.[DimensionID]

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After fill temp table #DimList', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#DimList', * FROM #DimList

	SET @Step = 'Update ResultTypeBM = 1 (Dimension)'
		UPDATE D
		SET
			[DimensionName] = ISNULL(DL.[DimensionName], D.[DimensionName]),
			[DimensionDescription] = ISNULL(DL.[DimensionDescription], D.[DimensionDescription]),
			[DimensionTypeID] = ISNULL(DL.[DimensionTypeID], D.[DimensionTypeID]),
			[ReportOnlyYN] = ISNULL(DL.[ReportOnlyYN], D.[ReportOnlyYN]),
			[MasterDimensionID] = ISNULL(DL.[MasterDimensionID], D.[MasterDimensionID]),
			[SeedMemberID] = ISNULL(DL.[SeedMemberID], D.[SeedMemberID]),
			[LoadSP] = ISNULL(DL.[LoadSP], D.[LoadSP]),
			[ObjectGuiBehaviorBM] = ISNULL(DL.[ObjectGuiBehaviorBM], D.[ObjectGuiBehaviorBM]),
			[DefaultSetMemberKey] = ISNULL(DL.[DefaultSetMemberKey], D.[DefaultSetMemberKey]),
			[DefaultGetMemberKey] = ISNULL(DL.[DefaultGetMemberKey], D.[DefaultGetMemberKey]),
			[DefaultGetHierarchyNo] = ISNULL(DL.[DefaultGetHierarchyNo], D.[DefaultGetHierarchyNo]),
			[ModelingStatusID] = ISNULL(DL.[ModelingStatusID], D.[ModelingStatusID]),
			[ModelingComment] = ISNULL(DL.[ModelingComment], D.[ModelingComment]),
			[SelectYN] = ISNULL(DL.[SelectYN], D.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension] D
			INNER JOIN #DimList DL ON DL.ResultTypeBM = 1 AND DL.DeleteYN = 0 AND DL.[DimensionID] = D.[DimensionID] 
		WHERE
			D.[InstanceID] = @InstanceID AND
			D.[DeletedID] IS NULL

		SET @Updated = @Updated + @@ROWCOUNT

		UPDATE DST
		SET
			[StorageTypeBM] = ISNULL(DL.[StorageTypeBM], DST.[StorageTypeBM]),
			[ObjectGuiBehaviorBM] = ISNULL(DL.[ObjectGuiBehaviorBM], DST.[ObjectGuiBehaviorBM]),
			[ReadSecurityEnabledYN] = ISNULL(DL.[ReadSecurityEnabledYN], DST.[ReadSecurityEnabledYN]),
			[MappingTypeID] = ISNULL(DL.[MappingTypeID], DST.[MappingTypeID]),
			[ReplaceStringYN] = ISNULL(DL.[ReplaceStringYN], DST.[ReplaceStringYN]),
			[DefaultSetMemberKey] = ISNULL(DL.[DefaultSetMemberKey], DST.[DefaultSetMemberKey]),
			[DefaultGetMemberKey] = ISNULL(DL.[DefaultGetMemberKey], DST.[DefaultGetMemberKey]),
			[DefaultGetHierarchyNo] = ISNULL(DL.[DefaultGetHierarchyNo], DST.[DefaultGetHierarchyNo]),
			[DimensionFilter] = ISNULL(DL.[DimensionFilter], DST.[DimensionFilter])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
			INNER JOIN #DimList DL ON DL.ResultTypeBM = 1 AND DL.DeleteYN = 0 AND DL.[DimensionID] = DST.[DimensionID] 
		WHERE
			DST.[InstanceID] = @InstanceID AND
			DST.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After update @ResultTypeBM = 1', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Update ResultTypeBM = 2 (Property)'
		UPDATE P
		SET
			[PropertyName] = ISNULL(DL.[PropertyName], P.[PropertyName]),
			[PropertyDescription] = ISNULL(DL.[PropertyDescription], P.[PropertyDescription]),
			[ObjectGuiBehaviorBM] = ISNULL(DL.[ObjectGuiBehaviorBM], P.[ObjectGuiBehaviorBM]),
			[DataTypeID] = ISNULL(DL.[DataTypeID], P.[DataTypeID]),
			[Size] = ISNULL(DL.[Size], P.[Size]),
			[DependentDimensionID] = ISNULL(DL.[DependentDimensionID], P.[DependentDimensionID]),
			[DefaultValueTable] = ISNULL(DL.[DefaultSetValue], P.[DefaultValueTable]),
			[SynchronizedYN] = ISNULL(DL.[SynchronizedYN], P.[SynchronizedYN]),
			[SortOrder] = ISNULL(DL.[SortOrder], P.[SortOrder]),
			[SelectYN] = ISNULL(DL.[SelectYN], P.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Property] P
			INNER JOIN #DimList DL ON DL.ResultTypeBM = 2 AND DL.DeleteYN = 0 AND DL.[PropertyID] = P.[PropertyID] 
		WHERE
			P.[InstanceID] = @InstanceID

		SET @Updated = @Updated + @@ROWCOUNT

		UPDATE DP
		SET
			[DependencyPrio] = ISNULL(DL.[DependencyPrio], DP.[DependencyPrio]),
			[MultiDimYN] = ISNULL(DL.[MultiDimYN], DP.[MultiDimYN]),
			[TabularYN] = ISNULL(DL.[TabularYN], DP.[TabularYN]),
			[NodeTypeBM] = ISNULL(DL.[NodeTypeBM], DP.[NodeTypeBM]),
			[SortOrder] = ISNULL(DL.[SortOrder], DP.[SortOrder]),
			[SelectYN] = ISNULL(DL.[SelectYN], DP.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP
			INNER JOIN #DimList DL ON DL.ResultTypeBM = 2 AND DL.DeleteYN = 0 AND DL.[DimensionID] = DP.[DimensionID] AND DL.[PropertyID] = DP.[PropertyID] 
		WHERE
			DP.[InstanceID] = @InstanceID AND
			DP.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update ResultTypeBM = 4 (Hierarchy)'
		UPDATE H
		SET
			[HierarchyName] = ISNULL(DL.[HierarchyName], H.[HierarchyName]),
			[HierarchyTypeID] = ISNULL(DL.[HierarchyTypeID], H.[HierarchyTypeID]),
			[FixedLevelsYN] = ISNULL(DL.[FixedLevelsYN], H.[FixedLevelsYN]),
			[BaseDimension] = ISNULL(DL.[BaseDimension], H.[BaseDimension]),
			[BaseHierarchy] = ISNULL(DL.[BaseHierarchy], H.[BaseHierarchy]),
			[BaseDimensionFilter] = ISNULL(DL.[BaseDimensionFilter], H.[BaseDimensionFilter]),
			[PropertyHierarchy] = ISNULL(DL.[PropertyHierarchy], H.[PropertyHierarchy]),
			[BusinessRuleID] = ISNULL(DL.[BusinessRuleID], H.[BusinessRuleID]),
			[LockedYN] = ISNULL(DL.[LockedYN], H.[LockedYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] H
			INNER JOIN #DimList DL ON DL.ResultTypeBM = 4 AND DL.DeleteYN = 0 AND DL.[DimensionID] = H.[DimensionID] AND DL.[HierarchyNo] = H.[HierarchyNo] 
		WHERE
			H.[InstanceID] = @InstanceID AND
			H.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

		--IF (SELECT COUNT(1) FROM #DimList WHERE [HierarchyTypeID] = 2) > 0
		--	BEGIN
		--		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
		--			(
		--			[Comment],
		--			[InstanceID],
		--			[VersionID],
		--			[DimensionID],
		--			[PropertyID],
		--			[DependencyPrio],
		--			[MultiDimYN],
		--			[TabularYN],
		--			[SortOrder],
		--			[SelectYN]
		--			)
		--		SELECT DISTINCT
		--			[Comment] = P.[Comment],
		--			[InstanceID] = @InstanceID,
		--			[VersionID] = @VersionID,
		--			[DimensionID] = DL.[DimensionID],
		--			[PropertyID] = P.[PropertyID], 
		--			[DependencyPrio] = 0,
		--			[MultiDimYN] = 0,
		--			[TabularYN] = ISNULL(DL.[TabularYN], 1),
		--			[SortOrder] = P.[SortOrder],
		--			[SelectYN] = ISNULL(DL.[SelectYN], 1)
		--		FROM
		--			#DimList DL 
		--			INNER JOIN (
		--				SELECT [Comment] = 'NodeTypeBM', [PropertyID] = 12, [SortOrder] = 44 
		--				UNION SELECT [Comment] = 'DimensionFilter', [PropertyID] = -227, [SortOrder] = 45 
		--				UNION SELECT [Comment] = 'EvalPrio', [PropertyID] = -230, [SortOrder] = 46
		--				) P ON 1=1
		--		WHERE
		--			DL.[DeleteYN] = 0 AND
		--			DL.[HierarchyTypeID] = 2 AND
		--			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[Dimension_Property] DP WHERE DP.[InstanceID] IN (0, @InstanceID) AND DP.[VersionID] IN (0, @VersionID) AND DP.[DimensionID] = DL.[DimensionID] AND DP.[PropertyID] = P.[PropertyID])
		--	END

	SET @Step = 'Update ResultTypeBM = 8 (HierarchyLevel)'
		UPDATE HL
		SET
			[LevelName] = ISNULL(DL.[LevelName], HL.[LevelName])
		FROM
			[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] HL
			INNER JOIN #DimList DL ON DL.ResultTypeBM = 8 AND DL.DeleteYN = 0 AND DL.[DimensionID] = HL.[DimensionID] AND DL.[HierarchyNo] = HL.[HierarchyNo] AND DL.[LevelNo] = HL.[LevelNo] 
		WHERE
			HL.[InstanceID] = @InstanceID AND
			HL.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update (and/or delete) ResultTypeBM = 4096 (Multidim)'
		UPDATE DP
		SET
			[MultiDimYN] = 1,
			[SortOrder] = ISNULL(DL.[SortOrder], DP.[SortOrder]),
			[SelectYN] = CASE WHEN DL.[DeleteYN] <> 0 THEN 0 ELSE ISNULL(DL.[SelectYN], DP.[SelectYN]) END
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Property] P ON P.[InstanceID] IN (0, DP.[InstanceID]) AND P.PropertyID = DP.PropertyID
			INNER JOIN #DimList DL ON DL.ResultTypeBM & 4096 > 0 AND DL.DimensionID = DP.DimensionID AND DL.DependentDimensionID = P.DependentDimensionID
		WHERE
			DP.[InstanceID] = @InstanceID AND
			DP.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

		UPDATE DCD
		SET
			[SortOrder] = COALESCE(DL.[SortOrder], DCD.[SortOrder], 0),
			[SelectYN] = CASE WHEN DL.[DeleteYN] <> 0 THEN 0 ELSE ISNULL(DL.[SelectYN], DCD.[SelectYN]) END
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD
			INNER JOIN #DimList DL ON DL.ResultTypeBM & 4096 > 0 AND DL.DimensionID = DCD.DimensionID AND DL.DataClassID = DCD.DataClassID
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After update @ResultTypeBM = 4096', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Delete ResultTypeBM = 1 (Dimension)'
		DELETE DST
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
			INNER JOIN #DimList DL ON DL.ResultTypeBM = 1 AND DL.DeleteYN <> 0 AND DL.[DimensionID] = DST.[DimensionID] 
		WHERE
			DST.[InstanceID] = @InstanceID AND
			DST.[VersionID] = @VersionID

		IF CURSOR_STATUS('global','DeleteDimension_Cursor') >= -1 DEALLOCATE DeleteDimension_Cursor
		DECLARE DeleteDimension_Cursor CURSOR FOR
			
			SELECT
				DL.DimensionID,
				D.DimensionName
			FROM
				#DimList DL
				INNER JOIN [Dimension] D ON D.[InstanceID] IN (0, @InstanceID) AND D.[DimensionID] = DL.[DimensionID]
			WHERE
				DL.ResultTypeBM = 1 AND
				DL.DeleteYN <> 0 AND
				DL.DimensionID IS NOT NULL

			OPEN DeleteDimension_Cursor
			FETCH NEXT FROM DeleteDimension_Cursor INTO @DimensionID, @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName

					EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'Dimension', @DeletedID = @DeletedID OUT

					UPDATE D
					SET
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[Dimension] D
					WHERE
						D.[InstanceID] = @InstanceID AND
						D.[DimensionID] = @DimensionID

					SET @Deleted = @Deleted + @@ROWCOUNT

					--Delete Dimension-related Callisto tables
					IF OBJECT_ID(@CallistoDatabase + '.dbo.S_DS_' + @DimensionName) IS NOT NULL
						BEGIN
							SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[S_DS_' + @DimensionName + ']'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT
						END 

					IF OBJECT_ID(@CallistoDatabase + '.dbo.O_DS_' + @DimensionName) IS NOT NULL
						BEGIN
							SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[O_DS_' + @DimensionName + ']'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT
						END 

					IF OBJECT_ID(@CallistoDatabase + '.dbo.HC_' + @DimensionName) IS NOT NULL
						BEGIN
							SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[HC_' + @DimensionName + ']'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT
						END 

					IF OBJECT_ID(@CallistoDatabase + '.dbo.DS_' + @DimensionName) IS NOT NULL
						BEGIN
							SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[DS_' + @DimensionName + ']'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT
						END 

					IF @EnhancedStorageYN = 0
						BEGIN
							SET @SQLStatement = '
								DELETE D
								FROM ' + @CallistoDatabase + '.[dbo].[Dimensions] D
								WHERE
									D.[Label] = ''' + @DimensionName + ''''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT
						
							SET @SQLStatement = '
								DELETE SD
								FROM ' + @CallistoDatabase + '.[dbo].[S_Dimensions] SD
								WHERE
									SD.[Label] = ''' + @DimensionName + ''''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT

							SET @SQLStatement = '
								DELETE DH
								FROM ' + @CallistoDatabase + '.[dbo].[DimensionHierarchies] DH
								WHERE
									DH.[Dimension] = ''' + @DimensionName + ''''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT

							SET @SQLStatement = '
								DELETE DHL
								FROM ' + @CallistoDatabase + '.[dbo].[DimensionHierarchyLevels] DHL
								WHERE
									DHL.[Dimension] = ''' + @DimensionName + ''''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT

							SET @SQLStatement = '
								DELETE A
								FROM ' + @CallistoDatabase + '.[dbo].[ApplicationDefinitionObjects] A
								WHERE
									A.[Label] = ''' + @DimensionName + ''' AND
									A.[Type] = ''Dimension'''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT
						END

					--Delete DimensionHierarchy-related Callisto tables
					IF CURSOR_STATUS('global','DeleteDimHierarchy_Cursor') >= -1 DEALLOCATE DeleteDimHierarchy_Cursor
					DECLARE DeleteDimHierarchy_Cursor CURSOR FOR
			
						SELECT
							DH.HierarchyName
						FROM
							[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH
						WHERE
							DH.InstanceID = @InstanceID AND
                            DH.VersionID = @VersionID AND
                            DH.DimensionID = @DimensionID

						OPEN DeleteDimHierarchy_Cursor
						FETCH NEXT FROM DeleteDimHierarchy_Cursor INTO @HierarchyName

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF OBJECT_ID(@CallistoDatabase + '.dbo.S_HS_' + @DimensionName + '_' + @HierarchyName) IS NOT NULL
									BEGIN
										SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[S_HS_' + @DimensionName + '_' + @HierarchyName + ']'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Deleted = @Deleted + @@ROWCOUNT
									END 

								IF OBJECT_ID(@CallistoDatabase + '.dbo.O_HS_' + @DimensionName + '_' + @HierarchyName) IS NOT NULL
									BEGIN
										SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[O_HS_' + @DimensionName + '_' + @HierarchyName + ']'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Deleted = @Deleted + @@ROWCOUNT
									END 
								
								IF OBJECT_ID(@CallistoDatabase + '.dbo.HL_' + @DimensionName + '_' + @HierarchyName) IS NOT NULL
									BEGIN
										SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[HL_' + @DimensionName + '_' + @HierarchyName + ']'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Deleted = @Deleted + @@ROWCOUNT
									END 

								IF OBJECT_ID(@CallistoDatabase + '.dbo.HS_' + @DimensionName + '_' + @HierarchyName) IS NOT NULL
									BEGIN
										SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[HS_' + @DimensionName + '_' + @HierarchyName + ']'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Deleted = @Deleted + @@ROWCOUNT
									END 

							FETCH NEXT FROM DeleteDimHierarchy_Cursor INTO @HierarchyName
							END

					CLOSE DeleteDimHierarchy_Cursor
					DEALLOCATE DeleteDimHierarchy_Cursor

					DELETE DH
					FROM
						[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH
					WHERE
						DH.[InstanceID] = @InstanceID AND
						DH.[VersionID] = @VersionID AND
                        DH.[DimensionID] = @DimensionID

					DELETE DHL
					FROM
						[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL
					WHERE
						DHL.[InstanceID] = @InstanceID AND
						DHL.[VersionID] = @VersionID AND
                        DHL.[DimensionID] = @DimensionID

					SET @Deleted = @Deleted + @@ROWCOUNT	

					FETCH NEXT FROM DeleteDimension_Cursor INTO @DimensionID, @DimensionName
				END

		CLOSE DeleteDimension_Cursor
		DEALLOCATE DeleteDimension_Cursor

	SET @Step = 'Delete ResultTypeBM = 2 (Property)'
		DELETE DP
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP
			INNER JOIN #DimList DL ON DL.ResultTypeBM = 2 AND DL.DeleteYN <> 0 AND DL.[DimensionID] = DP.[DimensionID] AND DL.[PropertyID] = DP.[PropertyID] 
		WHERE
			DP.[InstanceID] = @InstanceID AND
			DP.[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT

		DELETE P
		FROM
			[pcINTEGRATOR_Data].[dbo].[Property] P
			INNER JOIN #DimList DL ON DL.[ResultTypeBM] = 2 AND DL.[DeleteYN] <> 0 AND DL.[PropertyID] = P.[PropertyID] 
		WHERE
			P.[InstanceID] = @InstanceID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete ResultTypeBM = 4 (Hierarchy)'
		IF CURSOR_STATUS('global','DeleteHierarchy_Cursor') >= -1 DEALLOCATE DeleteHierarchy_Cursor
		DECLARE DeleteHierarchy_Cursor CURSOR FOR
			
			SELECT DISTINCT
				DL.[DimensionID],
				D.[DimensionName],
				DL.[HierarchyNo],
				[HierarchyName] = ISNULL(DL.[HierarchyName], H.[HierarchyName])
			FROM
				#DimList DL
				INNER JOIN [Dimension] D ON D.[InstanceID] IN (0, @InstanceID) AND D.[DimensionID] = DL.[DimensionID]
				INNER JOIN [DimensionHierarchy] H ON H.[InstanceID] IN (0, @InstanceID) AND H.[VersionID] IN (0, @VersionID) AND H.DimensionID = DL.[DimensionID] AND H.HierarchyNo = DL.HierarchyNo
			WHERE
				DL.[ResultTypeBM] = 4 AND
				DL.[DeleteYN] <> 0 AND
				DL.[DimensionID] IS NOT NULL AND 
				DL.[HierarchyNo] IS NOT NULL AND 
				DL.[HierarchyNo] <> 0 

			OPEN DeleteHierarchy_Cursor
			FETCH NEXT FROM DeleteHierarchy_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo, @HierarchyName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@HierarchyNo] = @HierarchyNo, [@HierarchyName] = @HierarchyName

					--1. Delete DimensionHierarchy
					DELETE H
					FROM
						[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] H
					WHERE
						H.[InstanceID] = @InstanceID AND
                        H.[VersionID] = @VersionID AND 
						H.[DimensionID] = @DimensionID AND 
						H.[HierarchyNo] = @HierarchyNo

					SET @Deleted = @Deleted + @@ROWCOUNT

					--2. Delete DimensionHierarchyLevel
					DELETE HL
					FROM
						[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] HL
					WHERE
						HL.[InstanceID] = @InstanceID AND
						HL.[VersionID] = @VersionID AND 
						HL.[DimensionID] = @DimensionID AND 
						HL.[HierarchyNo] = @HierarchyNo

					SET @Deleted = @Deleted + @@ROWCOUNT
                        
					--3. Delete DimensionHierarchy-related Callisto tables
					IF @EnhancedStorageYN = 0
						BEGIN
							SET @SQLStatement = '
								DELETE DH
								FROM ' + @CallistoDatabase + '.[dbo].[DimensionHierarchies] DH
								WHERE
									DH.[Dimension] = ''' + @DimensionName + ''' AND
									DH.[Hierarchy] = ''' + @HierarchyName + ''''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT

							SET @SQLStatement = '
								DELETE DHL
								FROM ' + @CallistoDatabase + '.[dbo].[DimensionHierarchyLevels] DHL
								WHERE
									DHL.[Dimension] = ''' + @DimensionName + ''' AND
									DHL.[Hierarchy] = ''' + @HierarchyName + ''''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT
				
/*
NOTE: When deleting DimensionHierarchies, with StorageTypeBM = 4 (Callisto), manual Delete of the Hierarchy in the modeler should be done as well, to prevent Deploy issues.

					IF OBJECT_ID(@CallistoDatabase + '.dbo.S_HS_' + @DimensionName + '_' + @HierarchyName) IS NOT NULL
						BEGIN
							SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[S_HS_' + @DimensionName + '_' + @HierarchyName + ']'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT
						END 

					IF OBJECT_ID(@CallistoDatabase + '.dbo.O_HS_' + @DimensionName + '_' + @HierarchyName) IS NOT NULL
						BEGIN
							SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[O_HS_' + @DimensionName + '_' + @HierarchyName + ']'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT
						END 
		*/							
							IF OBJECT_ID(@CallistoDatabase + '.dbo.HL_' + @DimensionName + '_' + @HierarchyName) IS NOT NULL
								BEGIN
									SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[HL_' + @DimensionName + '_' + @HierarchyName + ']'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Deleted = @Deleted + @@ROWCOUNT
								END 

							IF OBJECT_ID(@CallistoDatabase + '.dbo.HS_' + @DimensionName + '_' + @HierarchyName) IS NOT NULL
								BEGIN
									SET @SQLStatement = 'DROP TABLE ' + @CallistoDatabase + '.dbo.[HS_' + @DimensionName + '_' + @HierarchyName + ']'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Deleted = @Deleted + @@ROWCOUNT
								END
						END

					FETCH NEXT FROM DeleteHierarchy_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo, @HierarchyName
				END

		CLOSE DeleteHierarchy_Cursor
		DEALLOCATE DeleteHierarchy_Cursor

	SET @Step = 'Delete ResultTypeBM = 8 (HierarchyLevel)'
		DELETE HL
		FROM
			[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] HL
			INNER JOIN #DimList DL ON DL.[ResultTypeBM] = 8 AND DL.[DeleteYN] <> 0 AND DL.[DimensionID] = HL.[DimensionID] AND DL.[HierarchyNo] = HL.[HierarchyNo] AND DL.[LevelNo] = HL.[LevelNo]
		WHERE
			HL.[InstanceID] = @InstanceID AND
			HL.[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete ResultTypeBM = 16 (DimensionMember)'
		SELECT 
			@DimensionID = MAX(DimensionID) ,
			@ResultTypeBM = MAX(ResultTypeBM)
		FROM 
			#DimList 
		WHERE
			ResultTypeBM = 16 AND
			DeleteYN <> 0 AND
			DimensionID IS NOT NULL AND
            DimensionMemberID IS NOT NULL

		IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@ResultTypeBM] = @ResultTypeBM

		IF @ResultTypeBM = 16
			BEGIN
				CREATE TABLE #MemberIDsForDeletion
					(
					ResultTypeBM int,
					InstanceID int,
					DimensionID int,
					DimensionName nvarchar(100),
					MemberID bigint,
					MemberKey nvarchar(255) COLLATE DATABASE_DEFAULT,
					MemberDescription nvarchar(512) COLLATE DATABASE_DEFAULT
					)

				INSERT INTO #MemberIDsForDeletion
					(
					ResultTypeBM,
					InstanceID,
					DimensionID,
					DimensionName,
					MemberID,
					MemberKey,
					MemberDescription
					)
				EXEC [spPortalGet_DimensionMember] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = @DimensionID, @ResultTypeBM = 8 --Members possible to Dele
		
				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#MemberIDsForDeletion', DimensionID, DimensionName, MemberID, MemberKey FROM #MemberIDsForDeletion

				IF CURSOR_STATUS('global','DeleteDimensionMember_Cursor') >= -1 DEALLOCATE DeleteDimensionMember_Cursor
				DECLARE DeleteDimensionMember_Cursor CURSOR FOR
			
					SELECT DISTINCT
						DimensionID = DL.DimensionID,
						DimensionName = ISNULL(DL.DimensionName, D.DimensionName),
						DimensionMemberID = DL.DimensionMemberID,
						StorageTypeBM = ISNULL(DL.StorageTypeBM, DST.StorageTypeBM)
					FROM
						#DimList DL
						INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = DL.DimensionID
						INNER JOIN Dimension_StorageType DST ON DST.InstanceID IN (0, @InstanceID) AND DST.DimensionID = DL.DimensionID
					WHERE
						DL.ResultTypeBM = 16 AND
						DL.DeleteYN <> 0 AND
						DL.DimensionID IS NOT NULL AND
						DL.DimensionMemberID IS NOT NULL

					OPEN DeleteDimensionMember_Cursor
					FETCH NEXT FROM DeleteDimensionMember_Cursor INTO @DimensionID, @DimensionName, @DimensionMemberID, @StorageTypeBM

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@DimensionMemberID] = @DimensionMemberID, [@StorageTypeBM] = @StorageTypeBM

							IF @StorageTypeBM & 4 > 0  --Callisto
								BEGIN
                        			SET @SQLStatement = '
										DELETE W
										FROM
											' + @CallistoDatabase + '.dbo.S_DS_' + @DimensionName + ' W
											INNER JOIN #MemberIDsForDeletion M ON M.MemberID = W.MemberId
										WHERE
											W.MemberId = ' + CONVERT(NVARCHAR(15), @DimensionMemberID)
							
									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC(@SQLStatement)
                        
									SET @Deleted = @Deleted + @@ROWCOUNT

									IF @EnhancedStorageYN = 0
										BEGIN
											SET @SQLStatement = '
												DELETE W
												FROM
													' + @CallistoDatabase + '.dbo.O_DS_' + @DimensionName + ' W
													INNER JOIN #MemberIDsForDeletion M ON M.MemberID = W.MemberId
												WHERE
													W.MemberId = ' + CONVERT(NVARCHAR(15), @DimensionMemberID)
							
											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC(@SQLStatement)
										END
                        
									SET @Deleted = @Deleted + @@ROWCOUNT
								END 

							FETCH NEXT FROM DeleteDimensionMember_Cursor INTO @DimensionID, @DimensionName, @DimensionMemberID, @StorageTypeBM
						END

				CLOSE DeleteDimensionMember_Cursor
				DEALLOCATE DeleteDimensionMember_Cursor

				DROP TABLE #MemberIDsForDeletion
			END

	SET @Step = 'Delete ResultTypeBM = 4096 (Multidim)'
		--See above: @Step = 'Update (and/or delete) ResultTypeBM = 4096 (Multidim)'

	SET @Step = 'Insert new member ResultTypeBM = 1 (Dimension)'
		IF CURSOR_STATUS('global','InsertDimension_Cursor') >= -1 DEALLOCATE InsertDimension_Cursor
		DECLARE InsertDimension_Cursor CURSOR FOR
			
			SELECT DISTINCT
				[DimensionName] = DL.[DimensionName],
				[DimensionTypeID] = MAX(DL.[DimensionTypeID])
			FROM
				#DimList DL
			WHERE
				ResultTypeBM & 1 > 0 AND
				DeleteYN = 0 AND
				DimensionID IS NULL AND
				NOT EXISTS (SELECT 1 FROM [Dimension] D WHERE D.[InstanceID] IN (0, @InstanceID) AND D.[DimensionName] = DL.[DimensionName] AND D.[DeletedID] IS NULL)
			GROUP BY
				DL.[DimensionName]
			ORDER BY
				DL.[DimensionName]

			OPEN InsertDimension_Cursor
			FETCH NEXT FROM InsertDimension_Cursor INTO @DimensionName, @DimensionTypeID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName, [@DimensionTypeID] = @DimensionTypeID

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
						(
						[InstanceID],
						[DimensionName],
						[DimensionDescription],
						[DimensionTypeID],
						[ReportOnlyYN],
						[MasterDimensionID],
						[SeedMemberID],
						[LoadSP],
						[ObjectGuiBehaviorBM],
						[DefaultSetMemberKey],
						[DefaultGetMemberKey],
						[DefaultGetHierarchyNo],
						[ModelingStatusID],
						[ModelingComment],
						[SelectYN]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[DimensionName] = DL.[DimensionName],
						[DimensionDescription] = CASE WHEN ISNULL(DL.[DimensionDescription], '') = '' THEN DL.[DimensionName] ELSE DL.[DimensionDescription] END,
						[DimensionTypeID] = ISNULL(DL.[DimensionTypeID], [dbo].[f_GetDefaultValue] ('Dimension', 'DimensionTypeID')),
						[ReportOnlyYN] = ISNULL(DL.[ReportOnlyYN], [dbo].[f_GetDefaultValue] ('Dimension', 'ReportOnlyYN')),
						[MasterDimensionID] = ISNULL(DL.[MasterDimensionID], [dbo].[f_GetDefaultValue] ('Dimension', 'MasterDimensionID')),
						[SeedMemberID] = ISNULL(DL.[SeedMemberID], [dbo].[f_GetDefaultValue] ('Dimension', 'SeedMemberID')),
						[LoadSP] = ISNULL(DL.[LoadSP], CASE WHEN ISNULL(DL.[DimensionTypeID], [dbo].[f_GetDefaultValue] ('Dimension', 'DimensionTypeID')) = 27 THEN 'MultiDim' ELSE [dbo].[f_GetDefaultValue] ('Dimension', 'LoadSP') END),
--						[LoadSP] = ISNULL(DL.[LoadSP], [dbo].[f_GetDefaultValue] ('Dimension', 'LoadSP')),
						[ObjectGuiBehaviorBM] = ISNULL(DL.[ObjectGuiBehaviorBM], [dbo].[f_GetDefaultValue] ('Dimension', 'ObjectGuiBehaviorBM')),
						[DefaultSetMemberKey] = ISNULL(DL.[DefaultSetMemberKey], [dbo].[f_GetDefaultValue] ('Dimension', 'DefaultSetMemberKey')),
						[DefaultGetMemberKey] = ISNULL(DL.[DefaultGetMemberKey], [dbo].[f_GetDefaultValue] ('Dimension', 'DefaultGetMemberKey')),
						[DefaultGetHierarchyNo] = ISNULL(DL.[DefaultGetHierarchyNo], [dbo].[f_GetDefaultValue] ('Dimension', 'DefaultGetHierarchyNo')),
						[ModelingStatusID] = ISNULL(DL.[ModelingStatusID], [dbo].[f_GetDefaultValue] ('Dimension', 'ModelingStatusID')),
						[ModelingComment] = ISNULL(DL.[ModelingComment], [dbo].[f_GetDefaultValue] ('Dimension', 'ModelingComment')),
						[SelectYN] = ISNULL(DL.[SelectYN], [dbo].[f_GetDefaultValue] ('Dimension', 'SelectYN'))
					FROM
						#DimList DL  
					WHERE
						DL.[ResultTypeBM] = 1 AND
						DL.[DeleteYN] = 0 AND
						DL.[DimensionName] = @DimensionName AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[Dimension] D WHERE D.[InstanceID] IN (0, @InstanceID) AND D.[DimensionName] = DL.[DimensionName] AND D.[DeletedID] IS NULL)

					SET @Inserted_Local = @@ROWCOUNT
					IF @Inserted_Local = 0
						SET @DimensionID = NULL
					ELSE
						BEGIN
							SET @Inserted = @Inserted + @Inserted_Local

							SELECT
								@DimensionID = MAX(D.[DimensionID])
							FROM
								[pcINTEGRATOR_Data].[dbo].[Dimension] D
								INNER JOIN #DimList DL ON DL.[DimensionName] = D.[DimensionName]
							WHERE
								D.[InstanceID] = @InstanceID

							UPDATE DL
							SET
								DimensionID = ISNULL(DL.[DimensionID], @DimensionID)
							FROM
								#DimList DL

							INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
								(
								[InstanceID],
								[VersionID],
								[DimensionID], 
								[StorageTypeBM],
								[ObjectGuiBehaviorBM],
								[ReadSecurityEnabledYN],
								[MappingTypeID],
								[ReplaceStringYN],
								[DefaultSetMemberKey],
								[DefaultGetMemberKey],
								[DefaultGetHierarchyNo],
								[DimensionFilter]
								)
							SELECT
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[DimensionID] = @DimensionID, 
								[StorageTypeBM] = ISNULL(DL.[StorageTypeBM], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'StorageTypeBM')),
								[ObjectGuiBehaviorBM] = ISNULL(DL.[ObjectGuiBehaviorBM], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'ObjectGuiBehaviorBM')),
								[ReadSecurityEnabledYN] = ISNULL(DL.[ReadSecurityEnabledYN], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'ReadSecurityEnabledYN')),
								[MappingTypeID] = ISNULL(DL.[MappingTypeID], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'MappingTypeID')),
								[ReplaceStringYN] = ISNULL(DL.[ReplaceStringYN], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'ReplaceStringYN')),
								[DefaultSetMemberKey] = ISNULL(DL.[DefaultSetMemberKey], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'DefaultSetMemberKey')),
								[DefaultGetMemberKey] = ISNULL(DL.[DefaultGetMemberKey], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'DefaultGetMemberKey')),
								[DefaultGetHierarchyNo] = ISNULL(DL.[DefaultGetHierarchyNo], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'DefaultGetHierarchyNo')),
								[DimensionFilter] = ISNULL(DL.[DimensionFilter], [dbo].[f_GetDefaultValue] ('Dimension', 'DimensionFilter'))
							FROM
								#DimList DL 
							WHERE
								DL.ResultTypeBM = 1 AND
								DL.DeleteYN = 0 AND
								DL.[DimensionName] = @DimensionName

							SET @Inserted = @Inserted + @@ROWCOUNT

							INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
								(
								[Comment],
								[InstanceID],
								[VersionID],
								[DimensionID],
								[HierarchyNo],
								[HierarchyName],
								[HierarchyTypeID],
								[FixedLevelsYN],
								[LockedYN]
								)
							SELECT
								[Comment] = @DimensionName,
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[DimensionID] = @DimensionID,
								[HierarchyNo] = 0,
								[HierarchyName] = @DimensionName,
								[HierarchyTypeID] = CASE WHEN @DimensionTypeID = 27 THEN 3 ELSE 1 END,
								[FixedLevelsYN] = [dbo].[f_GetDefaultValue] ('DimensionHierarchy', 'FixedLevelsYN'),
								[LockedYN] = [dbo].[f_GetDefaultValue] ('DimensionHierarchy', 'LockedYN')							
							WHERE
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchy] D WHERE D.[InstanceID] = @InstanceID AND D.[VersionID] = @VersionID AND D.[DimensionID] = @DimensionID AND D.[HierarchyNo] = 0)

							SET @Inserted = @Inserted + @@ROWCOUNT

							INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
								(
								[Comment],
								[InstanceID],
								[VersionID],
								[DimensionID],
								[HierarchyNo],
								[LevelNo],
								[LevelName]
								)
							SELECT
								[Comment] = @DimensionName,
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[DimensionID] = @DimensionID,
								[HierarchyNo] = 0, 
								[LevelNo] = 1,
								[LevelName] = 'TopNode'
							WHERE
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = @InstanceID AND DHL.[VersionID] = @VersionID AND DHL.[DimensionID] = @DimensionID AND DHL.[HierarchyNo] = 0 AND DHL.[LevelNo] = 1)

							SET @Inserted = @Inserted + @@ROWCOUNT

							INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
								(
								[Comment],
								[InstanceID],
								[VersionID],
								[DimensionID],
								[HierarchyNo],
								[LevelNo],
								[LevelName]
								)
							SELECT
								[Comment] = @DimensionName,
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[DimensionID] = @DimensionID,
								[HierarchyNo] = 0, 
								[LevelNo] = 2,
								[LevelName] = @DimensionName
							WHERE
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = @InstanceID AND DHL.[VersionID] = @VersionID AND DHL.[DimensionID] = @DimensionID AND DHL.[HierarchyNo] = 0 AND DHL.[LevelNo] = 2)

							SET @Inserted = @Inserted + @@ROWCOUNT
						END

					FETCH NEXT FROM InsertDimension_Cursor INTO @DimensionName, @DimensionTypeID
				END

		CLOSE InsertDimension_Cursor
		DEALLOCATE InsertDimension_Cursor

		--Enable SetupCallisto for created Dimension
		IF @EnhancedStorageYN = 0 SET @SetupCallistoYN = 1
		
		IF @DebugBM & 16 > 0 SELECT [Step] = 'After Insert new member ResultTypeBM = 1 (Dimension)', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Insert new member ResultTypeBM = 2 (Property)'
		--NodeTypeBM if any Hierarchy of type 2 (Category) exists
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
			(
			[Comment],
			[InstanceID],
			[VersionID],
			[DimensionID],
			[PropertyID], 
			[DependencyPrio],
			[MultiDimYN],
			[TabularYN],
			[NodeTypeBM],
			[SortOrder],
			[SelectYN]
			)
		SELECT DISTINCT
			[Comment] = P.[Comment],
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[DimensionID] = DL.[DimensionID],
			[PropertyID] = P.[PropertyID], 
			[DependencyPrio] = 0,
			[MultiDimYN] = 0,
			[TabularYN] = ISNULL(DL.[TabularYN], 1),
			[NodeTypeBM] = ISNULL(DL.[NodeTypeBM], 1027),
			[SortOrder] = P.[SortOrder],
			[SelectYN] = ISNULL(DL.[SelectYN], 1)
		FROM
			#DimList DL 
			INNER JOIN (
				SELECT [Comment] = 'NodeTypeBM', [PropertyID] = 12, [SortOrder] = 44 
				UNION SELECT [Comment] = 'DimensionFilter', [PropertyID] = -227, [SortOrder] = 45 
				UNION SELECT [Comment] = 'EvalPrio', [PropertyID] = -230, [SortOrder] = 46
				) P ON 1=1
		WHERE
			DL.[DeleteYN] = 0 AND
			DL.[HierarchyTypeID] = 2 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[Dimension_Property] DP WHERE DP.[InstanceID] IN (0, @InstanceID) AND DP.[VersionID] IN (0, @VersionID) AND DP.[DimensionID] = DL.[DimensionID] AND DP.[PropertyID] = P.[PropertyID])

		--DimensionFilter if DimensionTypeID = 27
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
			(
			[Comment],
			[InstanceID],
			[VersionID],
			[DimensionID],
			[PropertyID], 
			[DependencyPrio],
			[MultiDimYN],
			[TabularYN],
			[NodeTypeBM],
			[SortOrder],
			[SelectYN]
			)
		SELECT DISTINCT
			[Comment] = P.[Comment],
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[DimensionID] = DL.[DimensionID],
			[PropertyID] = P.[PropertyID], 
			[DependencyPrio] = 0,
			[MultiDimYN] = 0,
			[TabularYN] = ISNULL(DL.[TabularYN], 1),
			[NodeTypeBM] = P.[NodeTypeBM],
			[SortOrder] = P.[SortOrder],
			[SelectYN] = ISNULL(DL.[SelectYN], 1)
		FROM
			#DimList DL 
			INNER JOIN (
				SELECT [Comment] = 'NodeTypeBM', [PropertyID] = 12, [NodeTypeBM]=1027, [SortOrder] = 44 
				UNION SELECT [Comment] = 'DimensionFilter', [PropertyID] = -227, [NodeTypeBM]=1024, [SortOrder] = 45 
				UNION SELECT [Comment] = 'EvalPrio', [PropertyID] = -230, [NodeTypeBM]=1024, [SortOrder] = 46
				UNION SELECT [Comment] = 'BalanceYN', [PropertyID] = -232, [NodeTypeBM]=1, [SortOrder] = 41 
				UNION SELECT [Comment] = 'ReverseSign', [PropertyID] = -231, [NodeTypeBM]=1, [SortOrder] = 42 
				--UNION SELECT [Comment] = 'TimeBalance', [PropertyID] = -8, [NodeTypeBM]=1, [SortOrder] = 41 
				--UNION SELECT [Comment] = 'Sign', [PropertyID] = -7, [NodeTypeBM]=1, [SortOrder] = 42 
				) P ON 1=1
		WHERE
			DL.[DeleteYN] = 0 AND
			DL.[DimensionTypeID] = 27 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP WHERE DP.[InstanceID] = @InstanceID AND DP.[VersionID] = @VersionID AND DP.[DimensionID] = DL.[DimensionID] AND DP.[PropertyID] = P.[PropertyID])



		----AccountType if Account is added where MultiDimYN <> 0
		--INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
		--	(
		--	[Comment],
		--	[InstanceID],
		--	[VersionID],
		--	[DimensionID],
		--	[PropertyID], 
		--	[DependencyPrio],
		--	[MultiDimYN],
		--	[TabularYN],
		--	[SortOrder],
		--	[SelectYN]
		--	)
		--SELECT
		--	[Comment] = 'AccountType',
		--	[InstanceID] = @InstanceID,
		--	[VersionID] = @VersionID,
		--	[DimensionID] = DL.[DimensionID],
		--	[PropertyID] = -192, 
		--	[DependencyPrio] = 0,
		--	[MultiDimYN] = 0,
		--	[TabularYN] = ISNULL(DL.[TabularYN], 1),
		--	[SortOrder] = 25,
		--	[SelectYN] = ISNULL(DL.[SelectYN], 1)
		--FROM
		--	#DimList DL 
		--WHERE
		--	DL.[ResultTypeBM] & 4098 > 0 AND
		--	DL.[DeleteYN] = 0 AND
		--	DL.[DependentDimensionID] = -1 AND
		--	DL.[MultiDimYN] <> 0 AND
		--	NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP WHERE DP.[InstanceID] = @InstanceID AND DP.[VersionID] = @VersionID AND DP.[DimensionID] = DL.[DimensionID] AND DP.[PropertyID] = -192)


		IF CURSOR_STATUS('global','InsertProperty_Cursor') >= -1 DEALLOCATE InsertProperty_Cursor
		DECLARE InsertProperty_Cursor CURSOR FOR
			
			SELECT DISTINCT
				DL.[PropertyName]
			FROM
				#DimList DL
			WHERE
				ResultTypeBM = 2 AND
				DeleteYN = 0 AND
				PropertyID IS NULL AND
				NOT EXISTS (SELECT 1 FROM [Property] D WHERE D.[InstanceID] IN (0, @InstanceID) AND D.[PropertyName] = DL.[PropertyName])

			OPEN InsertProperty_Cursor
			FETCH NEXT FROM InsertProperty_Cursor INTO @PropertyName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@PropertyName] = @PropertyName

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Property]
						(
						[InstanceID],
						[PropertyName],
						[PropertyDescription],
						[ObjectGuiBehaviorBM],
						[DataTypeID],
						[Size],
						[DependentDimensionID],
						[DefaultValueTable],
						[SynchronizedYN],
						[SortOrder],
						[DefaultNodeTypeBM],
						[SelectYN]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[PropertyName] = DL.[PropertyName],
						[PropertyDescription] = DL.[PropertyDescription],
						[ObjectGuiBehaviorBM] = ISNULL(DL.[ObjectGuiBehaviorBM], [dbo].[f_GetDefaultValue] ('Property', 'ObjectGuiBehaviorBM')),
						[DataTypeID] = DL.[DataTypeID],
						[Size] = DL.[Size],
						[DependentDimensionID] = DL.[DependentDimensionID],
						[DefaultValueTable] = DL.[DefaultSetValue],
						[SynchronizedYN] = ISNULL(DL.[SynchronizedYN], [dbo].[f_GetDefaultValue] ('Property', 'SynchronizedYN')),
						[SortOrder] = ISNULL(DL.[SortOrder], [dbo].[f_GetDefaultValue] ('Property', 'SortOrder')),
						[DefaultNodeTypeBM] = ISNULL(DL.[NodeTypeBM], 1027),
						[SelectYN] = ISNULL(DL.[SelectYN], [dbo].[f_GetDefaultValue] ('Property', 'SelectYN'))
					FROM
						#DimList DL  
					WHERE
						DL.[ResultTypeBM] = 2 AND
						DL.[DeleteYN] = 0 AND
						DL.[PropertyName] = @PropertyName AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[Property] D WHERE D.[InstanceID] IN (0, @InstanceID) AND D.[PropertyName] = DL.[PropertyName])

					SET @Inserted_Local = @@ROWCOUNT
					IF @Inserted_Local = 0
						SET @PropertyID = NULL
					ELSE
						BEGIN
							SET @Inserted = @Inserted + @Inserted_Local

							SELECT
								@PropertyID = MAX([PropertyID])
							FROM
								[pcINTEGRATOR_Data].[dbo].[Property]
							WHERE
								[InstanceID] = @InstanceID

							INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
								(
								[Comment],
								[InstanceID],
								[VersionID],
								[DimensionID],
								[PropertyID], 
								[DependencyPrio],
								[MultiDimYN],
								[TabularYN],
								[NodeTypeBM],
								[SortOrder],
								[SelectYN]
								)
							SELECT
								[Comment] = ISNULL(DL.[Comment], @PropertyName),
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[DimensionID] = DL.[DimensionID],
								[PropertyID] = @PropertyID, 
								[DependencyPrio] = ISNULL(DL.[DependencyPrio], 0),
								[MultiDimYN] = 0,
								[TabularYN] = DL.[TabularYN],
								[NodeTypeBM] = ISNULL(DL.[NodeTypeBM], 1027),
								[SortOrder] = ISNULL(DL.[SortOrder], [dbo].[f_GetDefaultValue] ('Property', 'SortOrder')),
								[SelectYN] = DL.[SelectYN]
							FROM
								#DimList DL 
							WHERE
								DL.[ResultTypeBM] = 2 AND
								DL.[DeleteYN] = 0 AND
								DL.[PropertyName] = @PropertyName

							SET @Inserted = @Inserted + @@ROWCOUNT
						END

					FETCH NEXT FROM InsertProperty_Cursor INTO @PropertyName
				END

		CLOSE InsertProperty_Cursor
		DEALLOCATE InsertProperty_Cursor

	SET @Step = 'Insert new member ResultTypeBM = 4 (Hierarchy)'
		IF CURSOR_STATUS('global','InsertHierarchy_Cursor') >= -1 DEALLOCATE InsertHierarchy_Cursor
		DECLARE InsertHierarchy_Cursor CURSOR FOR
			
			SELECT DISTINCT
				DL.[DimensionID],
				DL.[HierarchyNo],
				DL.[HierarchyName]
			FROM
				#DimList DL
			WHERE
				[ResultTypeBM] = 4 AND
				[DeleteYN] = 0 AND
				NOT EXISTS (SELECT 1 FROM [@Template_DimensionHierarchy] TDH WHERE TDH.[InstanceID] = 0 AND TDH.[VersionID] = 0 AND TDH.[DimensionID] = DL.[DimensionID] AND TDH.[HierarchyName] = DL.[HierarchyName] AND TDH.[FixedLevelsYN] = DL.[FixedLevelsYN] AND TDH.[LockedYN] = DL.[LockedYN]) AND
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].dbo.[DimensionHierarchy] DH WHERE DH.[InstanceID] = @InstanceID AND DH.[VersionID] = @VersionID AND DH.[DimensionID] = DL.[DimensionID] AND DH.[HierarchyName] = DL.[HierarchyName])
			ORDER BY
				DL.[DimensionID],
				DL.[HierarchyNo],
				DL.[HierarchyName]

			OPEN InsertHierarchy_Cursor
			FETCH NEXT FROM InsertHierarchy_Cursor INTO @DimensionID, @HierarchyNo, @HierarchyName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT @HierarchyNo = MAX([HierarchyNo]) + 1 FROM [DimensionHierarchy] DH WHERE DH.[InstanceID] = @InstanceID AND DH.[VersionID] = @VersionID AND DH.[DimensionID] = @DimensionID
					SET @HierarchyNo = ISNULL(@HierarchyNo, 1)
 
					SELECT @DimensionName = D.[DimensionName] FROM [pcINTEGRATOR].[dbo].[Dimension] D WHERE D.[InstanceID] IN (0, @InstanceID) AND D.[DimensionID] = @DimensionID

					IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@HierarchyNo] = @HierarchyNo, [@HierarchyName] = @HierarchyName

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
						(
						[Comment],
						[InstanceID],
						[VersionID],
						[DimensionID],
						[HierarchyNo],
						[HierarchyName],
						[HierarchyTypeID],
						[FixedLevelsYN],
						[BaseDimension],
						[BaseHierarchy],
						[BaseDimensionFilter],
						[PropertyHierarchy],
						[BusinessRuleID],
						[LockedYN]
						)
					SELECT
						[Comment] = ISNULL(DL.[Comment], @HierarchyName),
						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[DimensionID] = DL.[DimensionID],
						[HierarchyNo] = @HierarchyNo,
						[HierarchyName] = DL.[HierarchyName],
						[HierarchyTypeID] = ISNULL(DL.[HierarchyTypeID], 1),
						[FixedLevelsYN]= ISNULL(DL.[FixedLevelsYN], [dbo].[f_GetDefaultValue] ('DimensionHierarchy', 'FixedLevelsYN')),
						[BaseDimension] = DL.[BaseDimension],
						[BaseHierarchy] = DL.[BaseHierarchy],
						[BaseDimensionFilter] = DL.[BaseDimensionFilter],
						[PropertyHierarchy] = DL.[PropertyHierarchy],
						[BusinessRuleID] = DL.[BusinessRuleID],
						[LockedYN] = ISNULL(DL.[LockedYN], [dbo].[f_GetDefaultValue] ('DimensionHierarchy', 'LockedYN'))
					FROM
						#DimList DL  
					WHERE
						DL.[ResultTypeBM] = 4 AND
						DL.[DeleteYN] = 0 AND
						DL.[DimensionID] = @DimensionID AND
						DL.[HierarchyName] = @HierarchyName AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchy] D WHERE D.[InstanceID] = @InstanceID AND D.[VersionID] = @VersionID AND D.[DimensionID] = @DimensionID AND D.[HierarchyNo] = @HierarchyNo)

					SET @Inserted = @Inserted + @@ROWCOUNT

					--Insert [DimensionHierarchyLevel] if ResultTypeBM=8 is given
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
						(
						[Comment],
						[InstanceID],
						[VersionID],
						[DimensionID],
						[HierarchyNo],
						[LevelNo],
						[LevelName]
						)
					SELECT
						[Comment] = ISNULL(DL.[Comment], DL.[LevelName]),
						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[DimensionID] = DL.[DimensionID],
						[HierarchyNo] = @HierarchyNo, 
						[LevelNo] = DL.[LevelNo],
						[LevelName] = DL.[LevelName]
					FROM
						#DimList DL 
					WHERE
						DL.[ResultTypeBM] = 8 AND
						DL.[DeleteYN] = 0 AND
						DL.[DimensionID] = @DimensionID AND
						(DL.[HierarchyName] = @HierarchyName OR DL.[HierarchyNo] = @HierarchyNo) AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = @InstanceID AND DHL.[VersionID] = @VersionID AND DHL.[DimensionID] = @DimensionID AND DHL.[HierarchyNo] = @HierarchyNo AND DHL.[LevelNo] = DL.[LevelNo])

					SET @Inserted_Local = @@ROWCOUNT
					SET @Inserted = @Inserted + @Inserted_Local
				
					IF @DebugBM & 2 > 0 SELECT [@Inserted_Local] = @Inserted_Local
					IF @Inserted_Local = 0
						BEGIN
							--Insert Default [DimensionHierarchyLevel] if ResultTypeBM=8 is NOT given
							INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
								(
								[Comment],
								[InstanceID],
								[VersionID],
								[DimensionID],
								[HierarchyNo],
								[LevelNo],
								[LevelName]
								)
							SELECT
								[Comment] = ISNULL(DL.[Comment], DL.[HierarchyName]),
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[DimensionID] = DL.[DimensionID],
								[HierarchyNo] = @HierarchyNo, 
								[LevelNo] = TDL.[LevelNo],
								[LevelName] = TDL.[LevelName]
							FROM
								#DimList DL
								INNER JOIN [pcINTEGRATOR].[dbo].[@Template_DimensionHierarchyLevel] TDL ON TDL.DimensionID = DL.DimensionID
							WHERE
								DL.[ResultTypeBM] = 4 AND
								DL.[DeleteYN] = 0 AND
								DL.[DimensionID] = @DimensionID AND
								(DL.[HierarchyName] = @HierarchyName OR DL.[HierarchyNo] = @HierarchyNo) AND
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = @InstanceID AND DHL.[VersionID] = @VersionID AND DHL.[DimensionID] = @DimensionID AND DHL.[HierarchyNo] = @HierarchyNo AND DHL.[LevelNo] = DL.[LevelNo])
							
							INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
								(
								[Comment],
								[InstanceID],
								[VersionID],
								[DimensionID],
								[HierarchyNo],
								[LevelNo],
								[LevelName]
								)
							SELECT
								[Comment] = ISNULL(DL.[Comment], DL.[HierarchyName]),
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[DimensionID] = DL.[DimensionID],
								[HierarchyNo] = @HierarchyNo, 
								[LevelNo] = DH.[LevelNo],
								[LevelName] = DH.[LevelName]
							FROM
								#DimList DL
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DH ON DH.DimensionID = DL.DimensionID AND DH.HierarchyNo = 0
							WHERE
								DL.[ResultTypeBM] = 4 AND
								DL.[DeleteYN] = 0 AND
								DL.[DimensionID] = @DimensionID AND
								(DL.[HierarchyName] = @HierarchyName OR DL.[HierarchyNo] = @HierarchyNo) AND
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = @InstanceID AND DHL.[VersionID] = @VersionID AND DHL.[DimensionID] = @DimensionID AND DHL.[HierarchyNo] = @HierarchyNo AND DHL.[LevelNo] = DH.[LevelNo])

							SET @Inserted = @Inserted + @@ROWCOUNT
						END
                        
					IF @HierarchyNo <> 0 
						BEGIN	
							IF OBJECT_ID(@CallistoDatabase + '.dbo.S_HS_' + @DimensionName + '_' + @HierarchyName) IS NULL
								BEGIN
									SET @SQLStatement = '
										CREATE TABLE ' + @CallistoDatabase + '.dbo.[S_HS_' + @DimensionName + '_' + @HierarchyName + ']
											(
											[MemberId] bigint,
											[ParentMemberId] bigint,
											[SequenceNumber] bigint
											)'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END
							ELSE
								BEGIN
									SET @SQLStatement = 'TRUNCATE TABLE ' + @CallistoDatabase + '.dbo.[S_HS_' + @DimensionName + '_' + @HierarchyName + ']'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

							SET @SQLStatement = '
								INSERT INTO ' + @CallistoDatabase + '.[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + ']
									(
									[MemberId],
									[ParentMemberId],
									[SequenceNumber]
									)
								SELECT
									[MemberId],
									[ParentMemberId],
									[SequenceNumber]
								FROM
									' + @CallistoDatabase + '.[dbo].[S_HS_' + @DimensionName + '_' + @DimensionName + ']'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							SET @Inserted = @Inserted + @@ROWCOUNT

							IF @EnhancedStorageYN = 0
								BEGIN
									IF OBJECT_ID(@CallistoDatabase + '.dbo.O_HS_' + @DimensionName + '_' + @HierarchyName) IS NULL
										BEGIN
											SET @SQLStatement = '
												CREATE TABLE ' + @CallistoDatabase + '.dbo.[O_HS_' + @DimensionName + '_' + @HierarchyName + ']
													(
													[MemberId] bigint,
													[ParentMemberId] bigint,
													[SequenceNumber] bigint
													)'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
										END
									ELSE
										BEGIN
											SET @SQLStatement = 'TRUNCATE TABLE ' + @CallistoDatabase + '.dbo.[O_HS_' + @DimensionName + '_' + @HierarchyName + ']'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
										END

									SET @SQLStatement = '
										INSERT INTO ' + @CallistoDatabase + '.[dbo].[O_HS_' + @DimensionName + '_' + @HierarchyName + ']
											(
											[MemberId],
											[ParentMemberId],
											[SequenceNumber]
											)
										SELECT
											[MemberId],
											[ParentMemberId],
											[SequenceNumber]
										FROM
											' + @CallistoDatabase + '.[dbo].[O_HS_' + @DimensionName + '_' + @DimensionName + ']'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Inserted = @Inserted + @@ROWCOUNT

									IF OBJECT_ID(@CallistoDatabase + '.dbo.HL_' + @DimensionName + '_' + @HierarchyName) IS NULL AND OBJECT_ID(@CallistoDatabase + '.dbo.HL_' + @DimensionName + '_' + @DimensionName) IS NOT NULL
										BEGIN
											SET @SQLStatement = '
												SELECT * INTO ' + @CallistoDatabase + '.[dbo].[HL_' + @DimensionName + '_' + @HierarchyName + '] FROM ' + @CallistoDatabase + '.[dbo].[HL_' + @DimensionName + '_' + @DimensionName + ']'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF OBJECT_ID(@CallistoDatabase + '.dbo.HS_' + @DimensionName + '_' + @HierarchyName) IS NULL AND OBJECT_ID(@CallistoDatabase + '.dbo.HS_' + @DimensionName + '_' + @DimensionName) IS NOT NULL
										BEGIN
											SET @SQLStatement = '
												SELECT * INTO ' + @CallistoDatabase + '.[dbo].[HS_' + @DimensionName + '_' + @HierarchyName + '] FROM ' + @CallistoDatabase + '.[dbo].[HS_' + @DimensionName + '_' + @DimensionName + ']'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									--Enable SetupCallisto for created Dimension Hierarchy
									SET @SetupCallistoYN = 1
								END
						END

					FETCH NEXT FROM InsertHierarchy_Cursor INTO @DimensionID, @HierarchyNo, @HierarchyName
				END

		CLOSE InsertHierarchy_Cursor
		DEALLOCATE InsertHierarchy_Cursor

	SET @Step = 'Insert new member ResultTypeBM = 8 (HierarchyLevel)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
			(
			[Comment],
			[InstanceID],
			[VersionID],
			[DimensionID],
			[HierarchyNo],
			[LevelNo],
			[LevelName]
			)
		SELECT
			[Comment] = ISNULL(DL.[Comment], DL.[LevelName]),
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[DimensionID] = DL.[DimensionID],
			[HierarchyNo] = ISNULL(DL.[HierarchyNo], DH.HierarchyNo),
			[LevelNo] = DL.[LevelNo],
			[LevelName] = DL.[LevelName]
		FROM
			#DimList DL 
			LEFT JOIN [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH ON DH.InstanceID = @InstanceID AND DH.[VersionID] = @VersionID AND DH.[DimensionID] = DL.[DimensionID] AND (DH.HierarchyNo = DL.HierarchyNo OR DH.HierarchyName = DL.HierarchyName)
		WHERE
			DL.[ResultTypeBM] = 8 AND
			DL.[DeleteYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = @InstanceID AND DHL.[VersionID] = @VersionID AND DHL.[DimensionID] = DL.[DimensionID] AND DHL.[HierarchyNo] = ISNULL(DL.[HierarchyNo], DH.HierarchyNo) AND DHL.[LevelNo] = DL.[LevelNo])

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert new member ResultTypeBM = 4096 (Multidim)'
		IF CURSOR_STATUS('global','InsertMultiDim_Cursor') >= -1 DEALLOCATE InsertMultiDim_Cursor
		DECLARE InsertMultiDim_Cursor CURSOR FOR
			SELECT DISTINCT
				DL.[DimensionID],
				DL.[DependentDimensionID],
				D.[DimensionName],
				DL.[SortOrder]
			FROM
				#DimList DL
				INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.[InstanceID] IN (0, @InstanceID) AND D.[DimensionID] = DL.[DependentDimensionID]
			WHERE
				DL.[ResultTypeBM] & 4096 > 0 AND
				DL.[SelectYN] <> 0 AND
				DL.[DeleteYN] = 0 AND
				DL.[DependentDimensionID] IS NOT NULL AND
				NOT EXISTS (SELECT 1 FROM 
							(SELECT
								DP.[DimensionID],
								P.[DependentDimensionID]
							FROM
								[pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP
								INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.[InstanceID] IN (0, DP.[InstanceID]) AND P.PropertyID = DP.PropertyID
							WHERE
								DP.[InstanceID] = @InstanceID AND
								DP.[VersionID] = @VersionID AND
								DP.MultiDimYN <> 0) DE WHERE DE.[DimensionID] = DL.[DimensionID] AND DE.[DependentDimensionID] = DL.[DependentDimensionID])

			OPEN InsertMultiDim_Cursor
			FETCH NEXT FROM InsertMultiDim_Cursor INTO @DimensionID, @DependentDimensionID, @DimensionName, @SortOrder

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionID]=@DimensionID, [@DependentDimensionID]=@DependentDimensionID, [@DimensionName]=@DimensionName, [@SortOrder]=@SortOrder

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Property]
						(
						[InstanceID],
						[PropertyName],
						[PropertyDescription],
						[ObjectGuiBehaviorBM],
						[DataTypeID],
						[DependentDimensionID],
						[DefaultNodeTypeBM],
						[SelectYN]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[PropertyName] = @DimensionName,
						[PropertyDescription] = @DimensionName,
						[ObjectGuiBehaviorBM] = [dbo].[f_GetDefaultValue] ('Property', 'ObjectGuiBehaviorBM'),
						[DataTypeID] = 3,
						[DependentDimensionID] = @DependentDimensionID,
						[DefaultNodeTypeBM] = 1027,
						[SelectYN] = 1
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[Property] P WHERE P.[InstanceID] IN (0, @InstanceID) AND P.[PropertyName] = @DimensionName)

					SELECT
						@PropertyID = [PropertyID]
					FROM
						[pcINTEGRATOR].[dbo].[Property] P
					WHERE
						P.[InstanceID] IN (0, @InstanceID) AND
						P.[PropertyName] = @DimensionName

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
						(
						[Comment],
						[InstanceID],
						[VersionID],
						[DimensionID],
						[PropertyID], 
						[DependencyPrio],
						[MultiDimYN],
						[TabularYN],
						[NodeTypeBM],
						[SortOrder],
						[SelectYN]
						)
					SELECT
						[Comment] = @DimensionName,
						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[DimensionID] = @DimensionID,
						[PropertyID] = @PropertyID, 
						[DependencyPrio] = 0,
						[MultiDimYN] = 1,
						[TabularYN] = 1,
						[NodeTypeBM] = 1027,
						[SortOrder] = @SortOrder,
						[SelectYN] = 1
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[Dimension_Property] DP WHERE DP.[InstanceID] = @InstanceID AND DP.[VersionID] = @VersionID AND DP.[DimensionID] = @DimensionID AND DP.[PropertyID] = @PropertyID)

					FETCH NEXT FROM InsertMultiDim_Cursor INTO @DimensionID, @DependentDimensionID, @DimensionName, @SortOrder
				END

		CLOSE InsertMultiDim_Cursor
		DEALLOCATE InsertMultiDim_Cursor

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
			(
			[InstanceID],
			[VersionID],
			[DataClassID],
			[DimensionID],
			[SortOrder],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[DataClassID] = DL.DataClassID,
			[DimensionID] = DL.DimensionID,
			[SortOrder] = ISNULL(DL.[SortOrder], 2000),
			[SelectYN] = 1
		FROM
			#DimList DL 
		WHERE
			DL.ResultTypeBM & 4096 > 0 AND
			DL.DimensionID IS NOT NULL AND
			DL.DataClassID IS NOT NULL AND
			DL.SelectYN <> 0 AND
			DL.DeleteYN = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD WHERE DCD.[DataClassID] = DL.DataClassID AND DCD.[DimensionID] = DL.DimensionID)

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After insert @ResultTypeBM = 4096', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Update Callisto'
		IF @SetupCallistoYN <> 0 AND (SELECT COUNT(1) FROM #DimList WHERE ResultTypeBM & 16 > 0) < 1 AND (SELECT COUNT(1) FROM pcINTEGRATOR_Data..Dimension_StorageType WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND StorageTypeBM & 4 > 0) > 0
			BEGIN
				--IF (SELECT COUNT(1) FROM #DimList WHERE ResultTypeBM & 4 > 0 AND DimensionID = -1) > 0
				--	EXEC [spSetup_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM = 23, @JobID=@JobID, @Debug = @DebugSub
				--ELSE 
					EXEC [spSetup_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM = 19, @JobID=@JobID, @Debug = @DebugSub
			END

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After Update Callisto', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Add standard rows to newly created dimension'
		IF (SELECT COUNT(1) FROM pcINTEGRATOR_Data..Dimension_StorageType WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND StorageTypeBM & 4 > 0) > 0
			BEGIN
				IF @DebugBM & 2 > 0
					SELECT DISTINCT
						DL.[DimensionName]
					FROM
						#DimList DL
					WHERE
						ResultTypeBM = 1 AND
						DeleteYN = 0 AND
						DimensionID IS NULL

				IF CURSOR_STATUS('global','InsertDimRows_Cursor') >= -1 DEALLOCATE InsertDimRows_Cursor
				DECLARE InsertDimRows_Cursor CURSOR FOR
			
					SELECT DISTINCT
						DL.[DimensionID],
						DL.[DimensionName]
					FROM
						#DimList DL
					WHERE
						--ResultTypeBM = 1 AND
						ResultTypeBM & 5 > 0 AND
						DeleteYN = 0 --AND
						--DimensionID IS NULL

					OPEN InsertDimRows_Cursor
					FETCH NEXT FROM InsertDimRows_Cursor INTO @DimensionID, @DimensionName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							--SELECT 
							--	@DimensionID = D.[DimensionID]
							--FROM
							--	[pcINTEGRATOR_Data].[dbo].[Dimension] D
							--WHERE
							--	D.[InstanceID] = @InstanceID AND
							--	D.[DimensionName] = @DimensionName

							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName

							EXEC [dbo].[spIU_Dim_Dimension_Generic_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = @DimensionID, @JobID = @JobID, @Debug = @DebugSub

							--Create Default pcDATA..[HL_*] table
							IF DB_ID(@CallistoDatabase) IS NOT NULL AND @EnhancedStorageYN = 0
								BEGIN
									IF OBJECT_ID(@CallistoDatabase + '.dbo.HL_' + @DimensionName + '_' + @DimensionName) IS NULL
										BEGIN
											SET @SQLStatement = '
												CREATE TABLE ' + @CallistoDatabase + '.dbo.HL_' + @DimensionName + '_' + @DimensionName + '
													(
													[Parent_L1] bigint,
													[Parent_L2] bigint,
													[SequenceNumber] bigint
													)'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
										END
									ELSE
										BEGIN
											SET @SQLStatement = 'TRUNCATE TABLE ' + @CallistoDatabase + '.dbo.HL_' + @DimensionName + '_' + @DimensionName

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
										END

									SET @SQLStatement = '
										INSERT INTO ' + @CallistoDatabase + '.[dbo].[HL_' + @DimensionName + '_' + @DimensionName + ']
											(
											[Parent_L1],
											[Parent_L2],
											[SequenceNumber] 
											)
										SELECT
											[Parent_L1] = 1,
											[Parent_L2] = -1,
											[SequenceNumber] = 1'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

							FETCH NEXT FROM InsertDimRows_Cursor INTO @DimensionID, @DimensionName
						END
				CLOSE InsertDimRows_Cursor
				DEALLOCATE InsertDimRows_Cursor
			END	

		IF @DebugBM & 16 > 0 SELECT [Step] = 'After "Add standard rows to newly created dimension"', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Add hierarchy members'
		--SELECT 'Add hierarchy members'

	SET @Step = 'Return Rows'
		IF @DebugBM & 1 > 0
			BEGIN
				SELECT [Table] = 'Dimension', * FROM [pcINTEGRATOR_Data].[dbo].[Dimension] D WHERE [InstanceID] = @InstanceID ORDER BY [DimensionID]
				SELECT [Table] = 'Property', * FROM [pcINTEGRATOR_Data].[dbo].[Property] WHERE [InstanceID] = @InstanceID ORDER BY [PropertyID]
				SELECT [Table] = 'Hierarchy', * FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID ORDER BY [DimensionID], [HierarchyNo]
				SELECT [Table] = 'HierarchyLevel', * FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID ORDER BY [DimensionID], [HierarchyNo], [LevelNo]
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT [ErrorNumber] = @ErrorNumber, [ErrorSeverity] = @ErrorSeverity, [ErrorState] = @ErrorState, [ErrorProcedure] = @ErrorProcedure, [ErrorStep] = @Step, [ErrorLine] = @ErrorLine, [ErrorMessage] = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
