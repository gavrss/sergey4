SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spPortalAdminSet_DataClass]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JSON_table nvarchar(MAX) = NULL,


	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000924,
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
--1=Entity, 2=Entity tree, 4=Book, 8=FiscalYear
DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "1", "EntityID": "24041", "CountryID": "840"},
	{"ResultTypeBM" : "2", "EntityGroupID": "24053", "EntityID": "24041", "EntityParentID": "24053", "ValidFrom": "2018-01-01", "SortOrder": "100"},
	{"ResultTypeBM" : "2", "EntityGroupID": "24047", "EntityID": "24041", "EntityParentID": "24047", "ValidFrom": "2018-07-01", "SortOrder": "200"},
	{"ResultTypeBM" : "4", "EntityID": "24041", "Book": "MAIN", "COA": "ARNE"},
	{"ResultTypeBM" : "4", "EntityID": "24041", "Book": "FxRate", "COA": "NONE"},
	{"ResultTypeBM" : "8", "EntityID": "24041", "Book": "MAIN", "StartMonth": "190001", "EndMonth": "209912"}
	]'

EXEC [dbo].[spPortalAdminSet_Entity] 
	@UserID = -10,
	@InstanceID = -1412,
	@VersionID = -1350,
	@DebugBM = 7,
	@JSON_table = @JSON_table

EXEC [spPortalAdminSet_DataClass] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DataOriginDeleteID int,
	@DataOriginColumnDeleteID int,
	@DataClassIDDeleteID int, 
	@DimensionIDDeleteID int, 
	@MeasureIDDeleteID int,
	@ProcessIDDeleteID int,

	@DimensionID int,
	@DataClassID int,
	@DeletedID int,
	@ResultTypeBM int=0,
	@LastRowCount int,
	@SQLStatement nvarchar (max),

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
	@ModifiedBy nvarchar(50) = 'AlGa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update meta data for DataClass and other related tables',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1
		
	SET @Step = 'Create and fill #DataClassTable'
		CREATE TABLE #DataClassTable
			(
			--[DataOrigin]
			[ResultTypeBM] int,
			[DataOriginName] [nvarchar](100) ,
			[ConnectionTypeID] [int] ,
			[ConnectionName] [nvarchar](100) ,
			[SourceID] [int] ,
			[StagingPosition] [nvarchar](255) ,
			[MasterDataYN] [bit] ,
			[DataClassID] [int],
			--[DataOriginColumn]
			[DataOriginID] [int] ,
			[ColumnID] [int] ,
			[ColumnName] [nvarchar](50) ,
			[ColumnOrder] [int] ,
			[ColumnTypeID] [int] ,
			[ColumnTypeName] [nvarchar](50) ,
			[DestinationName] [nvarchar](50) ,
			[DataType] [nvarchar](50) ,
			[uOM] [nvarchar](50) ,
			[PropertyType] [nvarchar](50) ,
			[HierarchyLevel] [int] ,
			[Comment] [nvarchar](1024) ,
			[AutoAddYN] [bit] ,
			[DataClassYN] [bit], 
			--[DataClass]
			[DataClassName] [nvarchar](50) ,
			[DataClassDescription] [nvarchar](50) ,
			[DataClassTypeID] [int] ,
			[ModelBM] [int] ,
			[StorageTypeBM] [int] ,
			[ReadAccessDefaultYN] [bit] ,
			[ActualDataClassID] [int] ,
			[FullAccountDataClassID] [int] ,
			[TabularYN] [bit] ,
			[PrimaryJoin_DimensionID] [int] ,
			[ModelingStatusID] [int] ,
			[ModelingComment] [nvarchar](1024) ,
			[InheritedFrom] [int] ,
			[Version] [nvarchar](100) ,
			[DeletedID] [int] ,
			[TextSupportYN] [bit] ,
			--[Dimension]
			[DimensionName] [nvarchar](50) ,
			[DimensionDescription] [nvarchar](255) ,
			[DimensionTypeID] [int] ,
			[ObjectGuiBehaviorBM] [int] ,
			[GenericYN] [bit] ,
			[MultipleProcedureYN] [bit] ,
			[AllYN] [bit] ,
			[ReportOnlyYN] [bit] ,
			[HiddenMember] [nvarchar](1000) ,
			[Hierarchy] [nvarchar](50) ,
			[TranslationYN] [bit] ,
			[DefaultSelectYN] [bit] ,
			[DefaultSetMemberKey] [nvarchar](100) ,
			[DefaultGetMemberKey] [nvarchar](100) ,
			[DefaultGetHierarchyNo] [int] ,
			[DefaultValue] [nvarchar](50) ,
			[DeleteJoinYN] [bit] ,
			[SourceTypeBM] [int] ,
			[MasterDimensionID] [int] ,
			[HierarchyMasterDimensionID] [int] ,
			[SeedMemberID] [int] ,
			[LoadSP] [nvarchar](50) ,
			[MasterDataManagementBM] [int] ,
			[Introduced] [nvarchar](100) ,
			--[Dimension_StorageType]
			[ReadSecurityEnabledYN] [bit],
			[MappingTypeID] [int],
			[NumberHierarchy] [int],
			[ReplaceStringYN] [bit],
			[DimensionFilter] [nvarchar](4000),
			[ETLProcedure] [nvarchar](255),
			--[DimensionHierarchy]
			[HierarchyNo] [int] ,
			[HierarchyName] [nvarchar](50),
			[HierarchyTypeID] [int] ,
			[FixedLevelsYN] [bit] ,
			[LockedYN] [bit] ,
			--[DimensionHierarchyLevel]
			[LevelNo] [int] ,
			[LevelName] [nvarchar](50) ,
			--[DataClass_Dimension]
			[DimensionID] [int] ,
			[ChangeableYN] [bit] ,
			[Conversion_MemberKey] [nvarchar](100) ,
			[DataClassViewBM] [int] ,
			[FilterLevel] [nvarchar](2) ,
			[SortOrder] [int] ,
			--[Property]
			[PropertyName] [nvarchar](50) ,
			[PropertyDescription] [nvarchar](255) ,
			[DataTypeID] [int] ,
			[Size] [int] ,
			[DependentDimensionID] [int] ,
			[StringTypeBM] [int] ,
			[DynamicYN] [bit] ,
			[DefaultValueTable] [nvarchar](255) ,
			[DefaultValueView] [nvarchar](255) ,
			[SynchronizedYN] [bit] ,
			[ViewPropertyYN] [bit] ,
			[HierarchySortOrderYN] [bit] ,
			[MandatoryYN] [bit] ,
			[DefaultNodeTypeBM] [int] ,
			--[Dimension_Property]
			[PropertyID] [int] ,
			[DependencyPrio] [int] ,
			[MultiDimYN] [bit] ,
			[NodeTypeBM] [int] ,
			--[Measure]
			[MeasureID] [int] ,
			[MeasureName] [nvarchar](50) ,
			[MeasureDescription] [nvarchar](50) ,
			[SourceFormula] [nvarchar](max) ,
			[ExecutionOrder] [int] ,
			[MeasureParentID] [int] ,
			[FormatString] [nvarchar](50) ,
			[ValidRangeFrom] [nvarchar](100) ,
			[ValidRangeTo] [nvarchar](100) ,
			[Unit] [nvarchar](50) ,
			[AggregationTypeID] [int] ,
			[TabularFormula] [nvarchar](max) ,
			[TabularFolder] [nvarchar](50) ,
			--[Process]
			[ProcessBM] [int] ,
			[ProcessName] [nvarchar](50) ,
			[ProcessDescription] [nvarchar](50) ,
			[Destination_DataClassID] [int] ,
			--[DataClass_Process]
			[ProcessID] [int],
			[SelectYN] bit,
			[DeleteYN] bit DEFAULT 0
			)		

		IF @JSON_table IS NOT NULL	
			INSERT INTO #DataClassTable
				(
				--[DataOrigin]
				[ResultTypeBM]		
				,[DataOriginName]	
				,[ConnectionTypeID]	
				,[ConnectionName]	
				,[SourceID]			
				,[StagingPosition]	
				,[MasterDataYN]		
				,[DataClassID]
				--[DataOriginColumn]
				,[DataOriginID]	
				,[ColumnID]
				,[ColumnName]		
				,[ColumnOrder]		
				,[ColumnTypeID]	
				,[ColumnTypeName]
				,[DestinationName]	
				,[DataType]			
				,[uOM]				
				,[PropertyType]		
				,[HierarchyLevel]	
				,[Comment]			
				,[AutoAddYN]			
				,[DataClassYN]		
				--[DataClass]
				,[DataClassName]				
				,[DataClassDescription]		
				,[DataClassTypeID]			
				,[ModelBM]					
				,[StorageTypeBM]				
				,[ReadAccessDefaultYN]		
				,[ActualDataClassID]			
				,[FullAccountDataClassID]	
				,[TabularYN]					
				,[PrimaryJoin_DimensionID]	
				,[ModelingStatusID]			
				,[ModelingComment]			
				,[InheritedFrom]				
				,[Version]			
				,[DeletedID]			
				,[TextSupportYN]		
				--[Dimension]
				,[DimensionName]				
				,[DimensionDescription]		
				,[DimensionTypeID]			
				,[ObjectGuiBehaviorBM]		
				,[GenericYN]					
				,[MultipleProcedureYN]		
				,[AllYN]						
				,[ReportOnlyYN]				
				,[HiddenMember]				
				,[Hierarchy]					
				,[TranslationYN]				
				,[DefaultSelectYN]			
				,[DefaultSetMemberKey]		
				,[DefaultGetMemberKey]		
				,[DefaultGetHierarchyNo]		
				,[DefaultValue]				
				,[DeleteJoinYN]				
				,[SourceTypeBM]				
				,[MasterDimensionID]			
				,[HierarchyMasterDimensionID]	
				,[SeedMemberID]				
				,[LoadSP]					
				,[MasterDataManagementBM]	
				,[Introduced]
				--[Dimension_StorageType]
				,[ReadSecurityEnabledYN]
				,[MappingTypeID]		
				,[NumberHierarchy]	
				,[ReplaceStringYN]	
				,[DimensionFilter]	
				,[ETLProcedure]	
				--[DimensionHierarchy]
				,[HierarchyNo]	
				,[HierarchyName]	
				,[HierarchyTypeID]
				,[FixedLevelsYN]	
				,[LockedYN]
				--[DimensionHierarchyLevel]
				,[LevelNo]
				,[LevelName]
				--[DataClass_Dimension]
				,[DimensionID]				
				,[ChangeableYN]				
				,[Conversion_MemberKey]			
				,[DataClassViewBM]				
				,[FilterLevel]					
				,[SortOrder]						
				--[Property]
				,[PropertyName]			
				,[PropertyDescription]	
				,[DataTypeID]			
				,[Size]					
				,[DependentDimensionID]	
				,[StringTypeBM]			
				,[DynamicYN]				
				,[DefaultValueTable]		
				,[DefaultValueView]		
				,[SynchronizedYN]		
				,[ViewPropertyYN]		
				,[HierarchySortOrderYN]	
				,[MandatoryYN]			
				,[DefaultNodeTypeBM]		
				--[Dimension_Property]
				,[PropertyID]			
				,[DependencyPrio]		
				,[MultiDimYN]			
				,[NodeTypeBM]			
				--[Measure]
				,[MeasureID]
				,[MeasureName]			
				,[MeasureDescription]	
				,[SourceFormula]			
				,[ExecutionOrder]		
				,[MeasureParentID]		
				,[FormatString]			
				,[ValidRangeFrom]		
				,[ValidRangeTo]			
				,[Unit]					
				,[AggregationTypeID]		
				,[TabularFormula]		
				,[TabularFolder]			
				--[Process]
				,[ProcessBM]				
				,[ProcessName]			
				,[ProcessDescription]	
				,[Destination_DataClassID]
				--[DataClass_Process](
				,[ProcessID] 
				,[SelectYN]
				,[DeleteYN]
				)
			SELECT
				ResultTypeBM		
				,[DataOriginName]	
				,[ConnectionTypeID]	
				,[ConnectionName]	
				,[SourceID]			
				,[StagingPosition]	
				,[MasterDataYN]		
				,[DataClassID]	
				--[DataOriginColumn]
				,[DataOriginID]
				,[ColumnID]
				,[ColumnName]		
				,[ColumnOrder]		
				,[ColumnTypeID]	
				,[ColumnTypeName]=[ColumnType]
				,[DestinationName]	
				,[DataType]			
				,[uOM]				
				,[PropertyType]		
				,[HierarchyLevel]	
				,[Comment]			
				,[AutoAddYN]			
				,[DataClassYN]		
				--[DataClass]
				,[DataClassName]				
				,[DataClassDescription]		
				,[DataClassTypeID]			
				,[ModelBM]					
				,[StorageTypeBM]				
				,[ReadAccessDefaultYN]		
				,[ActualDataClassID]			
				,[FullAccountDataClassID]	
				,[TabularYN]					
				,[PrimaryJoin_DimensionID]	
				,[ModelingStatusID]			
				,[ModelingComment]			
				,[InheritedFrom]				
				,[Version]			
				,[DeletedID]			
				,[TextSupportYN]		
				--[Dimension]
				,[DimensionName]				
				,[DimensionDescription]		
				,[DimensionTypeID]			
				,[ObjectGuiBehaviorBM]		
				,[GenericYN]					
				,[MultipleProcedureYN]		
				,[AllYN]						
				,[ReportOnlyYN]				
				,[HiddenMember]				
				,[Hierarchy]					
				,[TranslationYN]				
				,[DefaultSelectYN]			
				,[DefaultSetMemberKey]		
				,[DefaultGetMemberKey]		
				,[DefaultGetHierarchyNo]		
				,[DefaultValue]				
				,[DeleteJoinYN]				
				,[SourceTypeBM]				
				,[MasterDimensionID]			
				,[HierarchyMasterDimensionID]	
				,[SeedMemberID]				
				,[LoadSP]					
				,[MasterDataManagementBM]	
				,[Introduced]	
				--[Dimension_StorageType]
				,[ReadSecurityEnabledYN]
				,[MappingTypeID]		
				,[NumberHierarchy]	
				,[ReplaceStringYN]	
				,[DimensionFilter]	
				,[ETLProcedure]	
				--[DimensionHierarchy]
				,[HierarchyNo]	
				,[HierarchyName]	
				,[HierarchyTypeID]
				,[FixedLevelsYN]	
				,[LockedYN]
				--[DimensionHierarchyLevel]
				,[LevelNo]
				,[LevelName]
				--[DataClass_Dimension]
				,[DimensionID]				
				,[ChangeableYN]				
				,[Conversion_MemberKey]			
				,[DataClassViewBM]				
				,[FilterLevel]					
				,[SortOrder]						
				--[Property]
				,[PropertyName]			
				,[PropertyDescription]	
				,[DataTypeID]			
				,[Size]					
				,[DependentDimensionID]	
				,[StringTypeBM]			
				,[DynamicYN]				
				,[DefaultValueTable]		
				,[DefaultValueView]		
				,[SynchronizedYN]		
				,[ViewPropertyYN]		
				,[HierarchySortOrderYN]	
				,[MandatoryYN]			
				,[DefaultNodeTypeBM]		
				--[Dimension_Property]
				,[PropertyID]			
				,[DependencyPrio]		
				,[MultiDimYN]			
				,[NodeTypeBM]			
				--[Measure]
				,[MeasureID]
				,[MeasureName]			
				,[MeasureDescription]	
				,[SourceFormula]			
				,[ExecutionOrder]		
				,[MeasureParentID]		
				,[FormatString]			
				,[ValidRangeFrom]		
				,[ValidRangeTo]			
				,[Unit]					
				,[AggregationTypeID]		
				,[TabularFormula]		
				,[TabularFolder]			
				--[Process]
				,[ProcessBM]				
				,[ProcessName]			
				,[ProcessDescription]	
				,[Destination_DataClassID]
				--[DataClass_Process](
				,[ProcessID] 
				,[SelectYN]
				,[DeleteYN] = ISNULL([DeleteYN], 0)
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				[ResultTypeBM] int,
			[DataOriginName] [nvarchar](100) ,
			[ConnectionTypeID] [int] ,
			[ConnectionName] [nvarchar](100) ,
			[SourceID] [int] ,
			[StagingPosition] [nvarchar](255) ,
			[MasterDataYN] [bit] ,
			[DataClassID] [int] ,
			--[DataOriginColumn]
			[DataOriginID] [int] ,
			[ColumnID] [int] ,
			[ColumnName] [nvarchar](50) ,
			[ColumnOrder] [int] ,
			[ColumnTypeID] [int] ,
			[ColumnType] [nvarchar](50) ,
			[DestinationName] [nvarchar](50) ,
			[DataType] [nvarchar](50) ,
			[uOM] [nvarchar](50) ,
			[PropertyType] [nvarchar](50) ,
			[HierarchyLevel] [int] ,
			[Comment] [nvarchar](1024) ,
			[AutoAddYN] [bit] ,
			[DataClassYN] [bit], 
			--[DataClass]
			[DataClassName] [nvarchar](50) ,
			[DataClassDescription] [nvarchar](50) ,
			[DataClassTypeID] [int] ,
			[ModelBM] [int] ,
			[StorageTypeBM] [int] ,
			[ReadAccessDefaultYN] [bit] ,
			[ActualDataClassID] [int] ,
			[FullAccountDataClassID] [int] ,
			[TabularYN] [bit] ,
			[PrimaryJoin_DimensionID] [int] ,
			[ModelingStatusID] [int] ,
			[ModelingComment] [nvarchar](1024) ,
			[InheritedFrom] [int] ,
			[Version] [nvarchar](100) ,
			[DeletedID] [int] ,
			[TextSupportYN] [bit] ,
			--[Dimension]
			[DimensionName] [nvarchar](50) ,
			[DimensionDescription] [nvarchar](255) ,
			[DimensionTypeID] [int] ,
			[ObjectGuiBehaviorBM] [int] ,
			[GenericYN] [bit] ,
			[MultipleProcedureYN] [bit] ,
			[AllYN] [bit] ,
			[ReportOnlyYN] [bit] ,
			[HiddenMember] [nvarchar](1000) ,
			[Hierarchy] [nvarchar](50) ,
			[TranslationYN] [bit] ,
			[DefaultSelectYN] [bit] ,
			[DefaultSetMemberKey] [nvarchar](100) ,
			[DefaultGetMemberKey] [nvarchar](100) ,
			[DefaultGetHierarchyNo] [int] ,
			[DefaultValue] [nvarchar](50) ,
			[DeleteJoinYN] [bit] ,
			[SourceTypeBM] [int] ,
			[MasterDimensionID] [int] ,
			[HierarchyMasterDimensionID] [int] ,
			[SeedMemberID] [int] ,
			[LoadSP] [nvarchar](50) ,
			[MasterDataManagementBM] [int] ,
			[Introduced] [nvarchar](100) ,
			--[Dimension_StorageType]
			[ReadSecurityEnabledYN] [bit],
			[MappingTypeID] [int],
			[NumberHierarchy] [int],
			[ReplaceStringYN] [bit],
			[DimensionFilter] [nvarchar](4000),
			[ETLProcedure] [nvarchar](255),
			--[DimensionHierarchy]
			[HierarchyNo] [int] ,
			[HierarchyName] [nvarchar](50),
			[HierarchyTypeID] [int] ,
			[FixedLevelsYN] [bit] ,
			[LockedYN] [bit] ,
			--[DimensionHierarchyLevel]
			[LevelNo] [int] ,
			[LevelName] [nvarchar](50) ,
			--[DataClass_Dimension]
			[InstanceID] [int] ,
			[VersionID] [int] ,
			[DimensionID] [int] ,
			[ChangeableYN] [bit] ,
			[Conversion_MemberKey] [nvarchar](100) ,
			[DataClassViewBM] [int] ,
			[FilterLevel] [nvarchar](2) ,
			[SortOrder] [int] ,
			--[Property]
			[PropertyName] [nvarchar](50) ,
			[PropertyDescription] [nvarchar](255) ,
			[DataTypeID] [int] ,
			[Size] [int] ,
			[DependentDimensionID] [int] ,
			[StringTypeBM] [int] ,
			[DynamicYN] [bit] ,
			[DefaultValueTable] [nvarchar](255) ,
			[DefaultValueView] [nvarchar](255) ,
			[SynchronizedYN] [bit] ,
			[ViewPropertyYN] [bit] ,
			[HierarchySortOrderYN] [bit] ,
			[MandatoryYN] [bit] ,
			[DefaultNodeTypeBM] [int] ,
			--[Dimension_Property]
			[PropertyID] [int] ,
			[DependencyPrio] [int] ,
			[MultiDimYN] [bit] ,
			[NodeTypeBM] [int] ,
			--[Measure]
			[MeasureID] [int] ,
			[MeasureName] [nvarchar](50) ,
			[MeasureDescription] [nvarchar](50) ,
			[SourceFormula] [nvarchar](max) ,
			[ExecutionOrder] [int] ,
			[MeasureParentID] [int] ,
			[FormatString] [nvarchar](50) ,
			[ValidRangeFrom] [nvarchar](100) ,
			[ValidRangeTo] [nvarchar](100) ,
			[Unit] [nvarchar](50) ,
			[AggregationTypeID] [int] ,
			[TabularFormula] [nvarchar](max) ,
			[TabularFolder] [nvarchar](50) ,
			--[Process]
			[ProcessBM] [int] ,
			[ProcessName] [nvarchar](50) ,
			[ProcessDescription] [nvarchar](50) ,
			[Destination_DataClassID] [int] ,
			--[DataClass_Process]
			[ProcessID] [int],
			[SelectYN] bit,
			[DeleteYN] bit 				 
				)
		ELSE
			GOTO EXITPOINT

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#DataOrigin', * FROM #DataClassTable
		
		--Set DeleteYN if missing
		UPDATE DCT
		SET
			[DeleteYN] = 0
		FROM
			#DataClassTable DCT
		WHERE [DeleteYN] =0

		--Set DataOriginID if missing
		UPDATE DCT
		SET
			DataOriginID = ISNULL(DCT.DataOriginID, DO.DataOriginID)
		FROM
			#DataClassTable DCT
				INNER JOIN pcIntegrator_Data.[dbo].[DataOrigin] DO
					ON DO.InstanceID = @InstanceID 
						AND DO.VersionID = @VersionID 
						AND DO.DataOriginName = DCT.DataOriginName
						AND DO.DeletedID IS NULL
		
		--Set DataOriginName if missing
		UPDATE DCT
		SET
			[DataOriginName] = ISNULL(DCT.DataOriginName,DO.[DataOriginName])
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataOrigin] DO
					ON DO.InstanceID = @InstanceID 
						AND DO.VersionID = @VersionID 
						AND DO.[DataOriginID] = DCT.[DataOriginID]
						AND DO.DeletedID IS NULL

		--Set ColumnID if missing
		UPDATE DCT
		SET
			ColumnID = ISNULL(DCT.ColumnId,DOC.ColumnID)
		FROM
			#DataClassTable DCT
				INNER JOIN pcIntegrator_Data.[dbo].[DataOriginColumn] DOC
					ON DOC.InstanceID = @InstanceID 
						AND DOC.VersionID = @VersionID 
						AND DOC.DataOriginID = DCT.DataOriginID
						AND DOC.ColumnName = DCT.ColumnName
						AND DOC.DeletedID IS NULL

		--Set ColumnName if missing
		UPDATE DCT
		SET
			ColumnName = ISNULL(DCT.ColumnName,DOC.ColumnName)
		FROM
			#DataClassTable DCT
				INNER JOIN pcIntegrator_Data.[dbo].[DataOriginColumn] DOC
					ON DOC.InstanceID = @InstanceID 
						AND DOC.VersionID = @VersionID 
						AND DOC.ColumnID = DCT.ColumnID
						AND DOC.DeletedID IS NULL

		--Set ColumnTypeID if missing
		UPDATE DCT
		SET
			ColumnTypeID = C.ColumnTypeID
		FROM
			#DataClassTable DCT
				INNER JOIN [pcIntegrator]..[ColumnType] C
					ON C.ColumnTypeName=DCT.ColumnTypeName
		WHERE [DeleteYN] =0

		--Set DataClassID if missing
		UPDATE DCT
		SET
			[DataClassID] = ISNULL(DCT.[DataClassID], DC.[DataClassID])
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC
					ON DC.InstanceID = @InstanceID 
						AND DC.VersionID = @VersionID 
						AND DC.[DataClassName] = DCT.[DataClassName]
						AND DC.DeletedID IS NULL

		--Set DataClassName if missing
		UPDATE DCT
		SET
			[DataClassName] = ISNULL(DCT.DataClassName,DC.[DataClassName])
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC
					ON DC.InstanceID = @InstanceID 
						AND DC.VersionID = @VersionID 
						AND DC.[DataClassID] = DCT.[DataClassID]
						AND DC.DeletedID IS NULL

		--Set DimensionID if missing
		UPDATE DCT
		SET
			DimensionID = ISNULL(DCT.DimensionID, D.DimensionID)
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D
					ON	D.InstanceID IN (@InstanceID ,0)
						AND D.[DimensionName] = DCT.[DimensionName]
						AND D.DeletedID IS NULL

		--Set DimensionName if missing
		UPDATE DCT
		SET
			[DimensionName] = ISNULL(DCT.DimensionName,D.[DimensionName])
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D
					ON D.InstanceID IN (@InstanceID ,0)
						AND D.[DimensionID] = DCT.[DimensionID]
						AND D.DeletedID IS NULL

				--INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension] D
				--	ON D.InstanceID = @InstanceID 
				--		AND D.[DimensionID] = DCT.[DimensionID]




		
		--Set [PropertyID] if missing
		UPDATE DCT
		SET
			[PropertyID] = ISNULL(DCT.PropertyID, P.PropertyID)
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Property] P
					ON	P.InstanceID = @InstanceID 
						AND P.[PropertyName] = DCT.[PropertyName]
						AND P.SelectYN=1

		--Set [PropertyID] if missing
		UPDATE DCT
		SET
			[PropertyName] = ISNULL(DCT.PropertyName, P.PropertyName)
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Property] P
					ON	P.InstanceID = @InstanceID 
						AND P.[PropertyID] = DCT.[PropertyID]
						AND P.SelectYN=1

		--Set [MeasureID] if missing
		UPDATE DCT
		SET
			[MeasureID] = ISNULL(DCT.[MeasureID], M.MeasureID)
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Measure] M
					ON	M.InstanceID = @InstanceID 
						AND M.VersionID = @VersionID
						AND M.DataClassID=DCT.DataClassID
						AND M.MeasureName=DCT.MeasureName
						AND M.SelectYN=1
						AND M.DeletedID IS NULL

		--Set [MeasureName] if missing
		UPDATE DCT
		SET
			[MeasureName] = ISNULL(DCT.[MeasureName], M.MeasureName)
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Measure] M
					ON	M.InstanceID = @InstanceID 
						AND M.VersionID = @VersionID
						AND M.MeasureID=DCT.MeasureID
						AND M.SelectYN=1

		--Set [ProcessID] if missing
		UPDATE DCT
		SET
			[ProcessID] = ISNULL(DCT.[ProcessID],P.[ProcessID])
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P
					ON P.InstanceID = @InstanceID 
						AND P.VersionID = @VersionID
						AND P.[ProcessName]=DCT.[ProcessName]
						AND P.SelectYN=1

		--Set [ProcessName] if missing
		UPDATE DCT
		SET
			[ProcessName] = ISNULL(DCT.[ProcessName],P.[ProcessName])
		FROM
			#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P
					ON P.InstanceID = @InstanceID 
						AND P.VersionID = @VersionID
						AND P.[ProcessID]=DCT.[ProcessID]
						AND P.SelectYN=1

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#DataClassTable', * FROM #DataClassTable

	
		IF (SELECT COUNT(1) FROM #DataClassTable	WHERE [ResultTypeBM] & 1>0) > 0 SET @ResultTypeBM=@ResultTypeBM+1
		IF (SELECT COUNT(1) FROM #DataClassTable	WHERE [ResultTypeBM] & 2>0) > 0 SET @ResultTypeBM=@ResultTypeBM+2	
		IF (SELECT COUNT(1) FROM #DataClassTable	WHERE [ResultTypeBM] & 4>0) > 0 SET @ResultTypeBM=@ResultTypeBM+4
		IF (SELECT COUNT(1) FROM #DataClassTable	WHERE [ResultTypeBM] & 8>0) > 0 SET @ResultTypeBM=@ResultTypeBM+8
		IF (SELECT COUNT(1) FROM #DataClassTable	WHERE [ResultTypeBM] & 16>0) > 0 SET @ResultTypeBM=@ResultTypeBM+16
		IF (SELECT COUNT(1) FROM #DataClassTable	WHERE [ResultTypeBM] & 32>0) > 0 SET @ResultTypeBM=@ResultTypeBM+32
		IF (SELECT COUNT(1) FROM #DataClassTable	WHERE [ResultTypeBM] & 64>0) > 0 SET @ResultTypeBM=@ResultTypeBM+64

		IF @DebugBM & 2 > 0 SELECT [@ResultTypeBM]=@ResultTypeBM
		

		--SELECT [TempTable] = '#DataClassTable', * FROM #DataClassTable

	SET @Step = '@ResultTypeBM = 1, DataOrigin' 
	IF @ResultTypeBM & 1  >0 
	BEGIN
		--Update
		UPDATE
			DO
		SET
			[DataOriginName] = ISNULL(DCT.[DataOriginName], DO.[DataOriginName])
			,[ConnectionTypeID]= ISNULL(DCT.[ConnectionTypeID], DO.[ConnectionTypeID])
			,[ConnectionName]= ISNULL(DCT.[ConnectionName], DO.[ConnectionName])
			,[SourceID]= ISNULL(DCT.[SourceID], DO.[SourceID])
			,[StagingPosition]= ISNULL(DCT.[StagingPosition], DO.[StagingPosition])
			,[MasterDataYN]= ISNULL(DCT.[MasterDataYN], DO.[MasterDataYN])
			,[DataClassID]= ISNULL(DCT.[DataClassID], DO.[DataClassID])
			,[DataClassTypeID]= ISNULL(DCT.[DataClassTypeID], DO.[DataClassTypeID])

		FROM
			[pcINTEGRATOR_Data].[dbo].[DataOrigin] DO
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 1 > 0 AND DCT.[DataOriginID] = DO.[DataOriginID]
					AND DCT.[DeleteYN] =0
		WHERE
			DO.[InstanceID] = @InstanceID AND
			DO.[VersionID]  = @VersionID 
			
			
		SET @Updated = @Updated + @@ROWCOUNT

		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataOrigin]
			(
			[InstanceID]
			,[VersionID]
			--,[DataOriginID]
			,[DataOriginName]
			,[ConnectionTypeID]
			,[ConnectionName]
			,[SourceID]
			,[StagingPosition]
			,[MasterDataYN]
			,[DataClassID]
			,[DataClassTypeID]
			,[DeletedID]
			)
		SELECT
			[InstanceID] = @InstanceID
			,[VersionID] = @VersionID
			,[DataOriginName] 
			,[ConnectionTypeID]
			,[ConnectionName]
			,[SourceID]
			,[StagingPosition]
			,[MasterDataYN]
			,[DataClassID]
			,[DataClassTypeID]
			,[DeletedID]
		FROM
			#DataClassTable DCT
		WHERE	
			DCT.[ResultTypeBM] & 1 > 0 AND
			DCT.[DeleteYN] = 0 AND
			DCT.[DataOriginID] IS NULL AND
			NOT EXISTS (
				SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataOrigin] DO 
					WHERE DO.[InstanceID] = @InstanceID 
						AND DO.[VersionID] = @VersionID 
							AND DO.DataOriginName=DCT.[DataOriginName]
							AND DO.[DeletedID] IS NULL)
			
		--SET @Inserted = @Inserted + @@ROWCOUNT
		SELECT @Inserted = @Inserted + @@ROWCOUNT, 	@LastRowCount=@@ROWCOUNT

		IF @LastRowCount>0 
			BEGIN

				SET @SQLStatement='SELECT TOP ' +  CONVERT(nvarchar(15), @LastRowCount) + ' ResultTypeBM = 1, DO.DataOriginID, DO.DataOriginName
					FROM [pcINTEGRATOR_Data].[dbo].[DataOrigin] DO 
						WHERE DO.[InstanceID] = ' +  CONVERT(nvarchar(15),@InstanceID) + ' ORDER BY DO.DataOriginID DESC'

				EXEC (@SQLStatement)

				UPDATE  DCT
					SET DCT.DataOriginID=DO.DataOriginID
					FROM #DataClassTable DCT
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataOrigin] DO 
							ON DO.DataOriginName = DCT.DataOriginName
							and  DO.[InstanceID] =  @InstanceID
							AND DO.VersionID = @VersionID

			END

		--Delete
		IF CURSOR_STATUS('local','Delete_Cursor') >= -1 DEALLOCATE Delete_Cursor
		DECLARE Delete_Cursor CURSOR FOR
			
			SELECT
				DO.DataOriginID
			FROM	
				#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataOrigin] DO ON
					DO.[InstanceID] = @InstanceID AND
					DO.[VersionID] = @VersionID AND
					DO.[DataOriginID] = DCT.DataOriginID AND
					DO.[DeletedID] IS NULL
			WHERE
				DCT.[ResultTypeBM] = 1 AND
				DCT.[DeleteYN] <> 0

			OPEN Delete_Cursor
			FETCH NEXT FROM Delete_Cursor INTO @DataOriginDeleteID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DataOriginDeleteID] = @DataOriginDeleteID

					EXEC [dbo].[spGet_DeletedItem]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@TableName = 'DataOrigin',
						@DeletedID = @DeletedID OUT,
						@JobID = @JobID

					UPDATE
						DO
					SET
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[DataOrigin] DO
					WHERE
						DO.[InstanceID] = @InstanceID AND
						DO.[VersionID] = @VersionID AND
						DO.[DataOriginID] = @DataOriginDeleteID AND
						DO.[DeletedID] IS NULL
			
					SET @Deleted = @Deleted + @@ROWCOUNT

					FETCH NEXT FROM Delete_Cursor INTO @DataOriginDeleteID
				END

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor
	END

	SET @Step = '@ResultTypeBM = 2, Data Origin Column'
	IF @ResultTypeBM & 2  >0 
	BEGIN
		--Update
		UPDATE
			DOC
		SET
			--[ColumnName] = ISNULL(DCT.[ColumnName], DOC.[ColumnName])
			[ColumnOrder]= ISNULL(DCT.[ColumnOrder], DOC.[ColumnOrder])
			,[ColumnTypeID]= ISNULL(DCT.[ColumnTypeID], DOC.[ColumnTypeID])
			,[DestinationName]= ISNULL(DCT.[DestinationName], DOC.[DestinationName])
			,[DataType]= ISNULL(DCT.[DataType], DOC.[DataType])
			,[uOM]= ISNULL(DCT.[uOM], DOC.[uOM])
			,[PropertyType]= ISNULL(DCT.[PropertyType], DOC.[PropertyType])
			,[HierarchyLevel]= ISNULL(DCT.[HierarchyLevel], DOC.[HierarchyLevel])
			,[Comment]= ISNULL(DCT.[Comment], DOC.[Comment])
			,[AutoAddYN]= ISNULL(DCT.[AutoAddYN], DOC.[AutoAddYN])
			,[DataClassYN]= ISNULL(DCT.[DataClassYN], DOC.[DataClassYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataOriginColumn] DOC
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 2 > 0 
					AND DCT.[DataOriginID] = DOC.[DataOriginID]
					AND DCT.ColumnID=DOC.ColumnID
					AND DCT.[DeleteYN] =0
		WHERE
			DOC.[InstanceID] = @InstanceID AND
			DOC.[VersionID] = @VersionID 
						
		SET @Updated = @Updated + @@ROWCOUNT
		
		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataOriginColumn]
			(
			 [InstanceID]
			,[VersionID]
			,[DataOriginID]
			--[ColumnID]
			,[ColumnName]
			,[ColumnOrder]
			,[ColumnTypeID]
			,[DestinationName]
			,[DataType]
			,[uOM]
			,[PropertyType]
			,[HierarchyLevel]
			,[Comment]
			,[AutoAddYN]
			,[DataClassYN]
			,[DeletedID]
			)
		SELECT
			[InstanceID] = @InstanceID
			,[VersionID] = @VersionID
			,DCT.[DataOriginID]
			,DCT.[ColumnName]
			,DCT.[ColumnOrder]
			,DCT.[ColumnTypeID]
			,DCT.[DestinationName]
			,DCT.[DataType]
			,DCT.[uOM]
			,DCT.[PropertyType]
			,DCT.[HierarchyLevel]
			,DCT.[Comment]
			,DCT.[AutoAddYN]
			,DCT.[DataClassYN]
			,DCT.[DeletedID]
		FROM
			#DataClassTable DCT
		WHERE	
			DCT.[ResultTypeBM] & 2 > 0 AND
			DCT.[DeleteYN] = 0 AND
			--ET.[DataOriginID] IS NULL AND			
			NOT EXISTS (
				SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataOriginColumn] DOC 
					WHERE DOC.[InstanceID] = @InstanceID 
						AND DOC.[VersionID] = @VersionID 
						AND DOC.[DataOriginID] = DCT.[DataOriginID] 
						AND DOC.[ColumnID] = DCT.[ColumnID]
						AND DOC.[DeletedID] IS NULL)
			
		--SET @Inserted = @Inserted + @@ROWCOUNT
		SELECT @Inserted = @Inserted + @@ROWCOUNT, 	@LastRowCount=@@ROWCOUNT

		IF @LastRowCount>0 
			BEGIN

				SET @SQLStatement='SELECT TOP ' +  CONVERT(nvarchar(15), @LastRowCount) + ' ResultTypeBM = 2, DOC.DataOriginID, DOC.ColumnID, DOC.ColumnName
					FROM [pcINTEGRATOR_Data].[dbo].[DataOriginColumn] DOC 
						WHERE DOC.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + '
						AND DOC.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' ORDER BY DOC.ColumnID DESC'

				EXEC (@SQLStatement)

			END
		--Delete
		IF CURSOR_STATUS('local','Delete_Cursor') >= -1 DEALLOCATE Delete_Cursor
		DECLARE Delete_Cursor CURSOR FOR
			
			SELECT
				DCT.ColumnID
				--DO.ColumnName
			FROM	
				#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataOriginColumn] DO ON
					DO.[InstanceID] = @InstanceID AND
					DO.[VersionID] = @VersionID AND
					DCT.[ColumnID]=DO.[ColumnID] AND
					DCT.ColumnName=DO.ColumnName AND
					DO.[DeletedID] IS NULL
			WHERE
				DCT.[ResultTypeBM] = 2 AND
				DCT.[DeleteYN] <> 0 

			OPEN Delete_Cursor
			FETCH NEXT FROM Delete_Cursor INTO @DataOriginColumnDeleteID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DataOriginColumnDeleteID] = @DataOriginColumnDeleteID

					EXEC [pcIntegrator].[dbo].[spGet_DeletedItem]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@TableName = 'DataOriginColumn',
						@DeletedID = @DeletedID OUT,
						@JobID = @JobID

					UPDATE
						DOC
					SET
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[DataOriginColumn] DOC
					WHERE
						DOC.[InstanceID] = @InstanceID AND
						DOC.[VersionID] = @VersionID AND
						DOC.ColumnID = @DataOriginColumnDeleteID AND
						--DOC.ColumnName=DO.ColumnName AND
						DOC.[DeletedID] IS NULL
			
					FETCH NEXT FROM Delete_Cursor INTO @DataOriginColumnDeleteID
				END

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor

		SET @Deleted = @Deleted + @@ROWCOUNT

	END

	SET @Step = '@ResultTypeBM = 4, DataClass'
	IF @ResultTypeBM & 4  >0 
	BEGIN
		--Update
		UPDATE DC
		SET
			[DataClassName] = ISNULL(DCT.[DataClassName], DC.[DataClassName]),
			[DataClassDescription] = ISNULL(DCT.[DataClassDescription], DC.[DataClassDescription]),
			[DataClassTypeID] = ISNULL(DCT.[DataClassTypeID], DC.[DataClassTypeID]),
			[ModelBM] = ISNULL(DCT.[ModelBM], DC.[ModelBM]),
			[StorageTypeBM] = ISNULL(DCT.[StorageTypeBM], DC.[StorageTypeBM]),
			[ReadAccessDefaultYN] = ISNULL(DCT.[ReadAccessDefaultYN], DC.[ReadAccessDefaultYN]),
			[ActualDataClassID] = ISNULL(DCT.[ActualDataClassID], DC.[ActualDataClassID]),
			[FullAccountDataClassID] = ISNULL(DCT.[FullAccountDataClassID], DC.[FullAccountDataClassID]),
			[TabularYN] = ISNULL(DCT.[TabularYN], DC.[TabularYN]),
			[PrimaryJoin_DimensionID] = ISNULL(DCT.[PrimaryJoin_DimensionID], DC.[PrimaryJoin_DimensionID]),
			[ModelingStatusID] = ISNULL(DCT.[ModelingStatusID], DC.[ModelingStatusID]),
			[ModelingComment] = ISNULL(DCT.[ModelingComment], DC.[ModelingComment]),
			[InheritedFrom] = ISNULL(DCT.[InheritedFrom], DC.[InheritedFrom]),
			[SelectYN] = ISNULL(DCT.[SelectYN], DC.[SelectYN]),
			[Version] = ISNULL(DCT.[Version], DC.[Version]),
			[DeletedID] = ISNULL(DCT.[DeletedID], DC.[DeletedID]),
			[TextSupportYN] = ISNULL(DCT.[TextSupportYN], DC.[TextSupportYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass] DC
				INNER JOIN #DataClassTable DCT 
					ON DCT.[ResultTypeBM] & 4 > 0 
						AND DCT.[DataClassID] = DC.[DataClassID]
						AND DCT.[DeleteYN] = 0
		WHERE
			DC.[InstanceID] = @InstanceID AND
			DC.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass]
			(
			[InstanceID]
			--,[DataClassID]
			,[VersionID]
			,[DataClassName]
			,[DataClassDescription]
			,[DataClassTypeID]
			,[ModelBM]
			,[StorageTypeBM]
			,[ReadAccessDefaultYN]
			,[ActualDataClassID]
			,[FullAccountDataClassID]
			,[TabularYN]
			,[PrimaryJoin_DimensionID]
			,[ModelingStatusID]
			,[ModelingComment]
			,[InheritedFrom]
			,[SelectYN]
			,[Version]
			,[DeletedID]
			,[TextSupportYN]
			)
		SELECT
			[InstanceID] = @InstanceID
			--,[DataClassID]
			,[VersionID] = @VersionID
			,[DataClassName]
			,[DataClassDescription]
			--,CASE WHEN (DataClassName = 'Journal') THEN '-5'
			--	  WHEN (DataClassName = 'Assumption') THEN '-3'
			--	  WHEN (DataClassName = 'FxRate') THEN '-6'
			--	  WHEN (DataClassName = 'Financials') THEN '-1'
			--	  WHEN (DataClassName = 'SalesReport') THEN '-11'
			--	  WHEN (DataClassName = 'SalesBudget') THEN '-11'
			--	  WHEN (DataClassName = 'Sales') THEN '-10'
			--	  ELSE '-12'
			--	END [DataClassTypeID]
			,ISNULL(DCT.DataClassTypeID, '-12')
			,CASE WHEN (DataClassName = 'Journal')		THEN '1'
				  WHEN (DataClassName = 'Assumption')	THEN '2'
				  WHEN (DataClassName = 'FxRate')		THEN '4'
				  WHEN (DataClassName = 'Financials')	THEN '64'
				  WHEN (DataClassName = 'SalesReport')	THEN '16'
				  WHEN (DataClassName = 'SalesBudget')	THEN '16'
				  WHEN (DataClassName = 'Sales')		THEN '8'
				  ELSE '2048'
				END [ModelBM]
			,CASE WHEN (DataClassName = 'Journal')		THEN '2'
				  WHEN (DataClassName = 'Assumption')	THEN '4'
				  WHEN (DataClassName = 'FxRate')		THEN '4'
				  WHEN (DataClassName = 'Financials')	THEN '4'
				  WHEN (DataClassName = 'SalesReport')	THEN '4'
				  WHEN (DataClassName = 'SalesBudget')	THEN '4'
				  WHEN (DataClassName = 'Sales')		THEN '4'
				  ELSE '4'
				END [StorageTypeBM]
			,ISNULL([ReadAccessDefaultYN], 1)
			,[ActualDataClassID]
			,[FullAccountDataClassID]
			,ISNUll([TabularYN], 0)
			,[PrimaryJoin_DimensionID]
			,ISNULL(DCT.[ModelingStatusID], '-40')
			,ISNULL([ModelingComment], 'Default setup')
			,[InheritedFrom]
			,ISNULL([SelectYN],1)
			,ISNULL([Version],@Version)
			,[DeletedID]
			,ISNULL([TextSupportYN],0)
		FROM
			#DataClassTable DCT
		WHERE	
			DCT.[ResultTypeBM] & 4 > 0 AND
			DCT.[DeleteYN] = 0 AND
			NOT EXISTS (
				SELECT 1 FROM [pcINTEGRATOR].[dbo].[DataClass] DC 
					WHERE   DC.[InstanceID] = @InstanceID 
						AND DC.[VersionID] = @VersionID 
						AND DC.[DataClassID] = DCT.[DataClassID] 
						AND DC.[DeletedID] IS NULL)	
						
		--SET @Inserted = @Inserted + @@ROWCOUNT
		SELECT @Inserted = @Inserted + @@ROWCOUNT, 	@LastRowCount=@@ROWCOUNT

		IF @LastRowCount>0 
			BEGIN

				SET @SQLStatement='SELECT TOP ' +  CONVERT(nvarchar(15), @LastRowCount) + ' ResultTypeBM = 4, DC.DataClassID, DC.DataClassName
					FROM [pcINTEGRATOR_Data].[dbo].[DataClass] DC 
						WHERE DC.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + '
						AND	DC.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' ORDER BY DC.DataClassID DESC'

				EXEC (@SQLStatement)

				UPDATE  DCT
					SET DCT.DataClassID=DC.DataClassID
					FROM #DataClassTable DCT
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC 
							ON	DC.DataClassName = DCT.DataClassName
							and	DC.[InstanceID] =  @InstanceID
							AND		DC.VersionID = @VersionID

			END
		--Delete
		IF CURSOR_STATUS('local','Delete_Cursor') >= -1 DEALLOCATE Delete_Cursor
		DECLARE Delete_Cursor CURSOR FOR
					
			SELECT
				DC.DataClassID
			FROM	
				#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass]  DC ON
					DC.[InstanceID] = @InstanceID AND
					DC.[VersionID] = @VersionID AND
					DCT.[DataClassID]=DC.[DataClassID] AND
					--DCT.[DataClassName]=DC.[DataClassName] AND
					DCT.[DeletedID] IS NULL
			WHERE
				DCT.[ResultTypeBM] = 4 AND
				DCT.[DeleteYN] <> 0
		
			OPEN Delete_Cursor
			FETCH NEXT FROM Delete_Cursor INTO @DataOriginDeleteID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 4 > 0 SELECT [@DataOriginDeleteID] = @DataOriginDeleteID

					EXEC [pcIntegrator].[dbo].[spGet_DeletedItem]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@TableName = 'DataClass',
						@DeletedID = @DeletedID OUT,
						@JobID = @JobID

					UPDATE
						DC
					SET
						SelectYN=0,
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[DataClass] DC
					WHERE
						DC.[InstanceID] = @InstanceID AND
						DC.[VersionID] = @VersionID AND
						DC.[DataClassID] = @DataOriginDeleteID AND
						--DC.[DataClassName]=DO.[DataClassName] AND
						DC.[DeletedID] IS NULL
			
					SET @Deleted = @Deleted + @@ROWCOUNT

					FETCH NEXT FROM Delete_Cursor INTO @DataOriginDeleteID
				END

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor
		SET @Deleted = @Deleted + @@ROWCOUNT

	END

	SET @Step = '@ResultTypeBM = 8, Dimension' 
	IF @ResultTypeBM & 8 >0 
	BEGIN
		--Update
		UPDATE
			D
		SET
			--[InstanceID]= ISNULL(DCT.[InstanceID], D.[InstanceID])
			--,[DimensionID]= ISNULL(DCT.[DimensionID], D.[DimensionID])
			--,[DimensionName]= ISNULL(DCT.[DimensionName], D.[DimensionName])
			[DimensionDescription]= ISNULL(DCT.[DimensionDescription], D.[DimensionDescription])
			,[DimensionTypeID]= ISNULL(DCT.[DimensionTypeID], D.[DimensionTypeID])
			,[ObjectGuiBehaviorBM]= ISNULL(DCT.[ObjectGuiBehaviorBM], D.[ObjectGuiBehaviorBM])
			,[GenericYN]= ISNULL(DCT.[GenericYN], D.[GenericYN])
			,[MultipleProcedureYN]= ISNULL(DCT.[MultipleProcedureYN], D.[MultipleProcedureYN])
			,[AllYN]= ISNULL(DCT.[AllYN], D.[AllYN])
			,[ReportOnlyYN]= ISNULL(DCT.[ReportOnlyYN], D.[ReportOnlyYN])
			,[HiddenMember]= ISNULL(DCT.[HiddenMember], D.[HiddenMember])
			,[Hierarchy]= ISNULL(DCT.[Hierarchy], D.[Hierarchy])
			,[TranslationYN]= ISNULL(DCT.[TranslationYN], D.[TranslationYN])
			,[DefaultSelectYN]= ISNULL(DCT.[DefaultSelectYN], D.[DefaultSelectYN])
			,[DefaultSetMemberKey]= ISNULL(DCT.[DefaultSetMemberKey], D.[DefaultSetMemberKey])
			,[DefaultGetMemberKey]= ISNULL(DCT.[DefaultGetMemberKey], D.[DefaultGetMemberKey])
			,[DefaultGetHierarchyNo]= ISNULL(DCT.[DefaultGetHierarchyNo], D.[DefaultGetHierarchyNo])
			,[DefaultValue]= ISNULL(DCT.[DefaultValue], D.[DefaultValue])
			,[DeleteJoinYN]= ISNULL(DCT.[DeleteJoinYN], D.[DeleteJoinYN])
			,[SourceTypeBM]= ISNULL(DCT.[SourceTypeBM], D.[SourceTypeBM])
			,[MasterDimensionID]= ISNULL(DCT.[MasterDimensionID], D.[MasterDimensionID])
			,[HierarchyMasterDimensionID]= ISNULL(DCT.[HierarchyMasterDimensionID], D.[HierarchyMasterDimensionID])
			,[InheritedFrom]= ISNULL(DCT.[InheritedFrom], D.[InheritedFrom])
			,[SeedMemberID]= ISNULL(DCT.[SeedMemberID], D.[SeedMemberID])
			,[LoadSP]= ISNULL(DCT.[LoadSP], D.[LoadSP])
			,[MasterDataManagementBM]= ISNULL(DCT.[MasterDataManagementBM], D.[MasterDataManagementBM])
			,[ModelingStatusID]= ISNULL(DCT.[ModelingStatusID], D.[ModelingStatusID])
			,[ModelingComment]= ISNULL(DCT.[ModelingComment], D.[ModelingComment])
			,[Introduced]= ISNULL(DCT.[Introduced], D.[Introduced])
			,[SelectYN]= ISNULL(DCT.[SelectYN], D.[SelectYN])
			,[DeletedID]= ISNULL(DCT.[DeletedID], D.[DeletedID])
			,[Version]= ISNULL(DCT.[Version], D.[Version])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension] D
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 8 > 0 AND DCT.[DimensionID] = D.[DimensionID]
					AND DCT.[DeleteYN] = 0
		WHERE
			D.[InstanceID] = @InstanceID

		SET @Updated = @Updated + @@ROWCOUNT
		
		UPDATE
			DST
		SET
			--[InstanceID]= ISNULL(DCT.[InstanceID], DST.[InstanceID])
			--,[DimensionID]= ISNULL(DCT.[DimensionID], DST.[DimensionID])
			--,[StorageTypeBM]= ISNULL(DCT.[StorageTypeBM], DST.[StorageTypeBM])
			--,[ObjectGuiBehaviorBM]= ISNULL(DCT.[ObjectGuiBehaviorBM], DST.[ObjectGuiBehaviorBM])
			[ReadSecurityEnabledYN]= ISNULL(DCT.[ReadSecurityEnabledYN], DST.[ReadSecurityEnabledYN])
			,[MappingTypeID]= ISNULL(DCT.[MappingTypeID], DST.[MappingTypeID])
			,[NumberHierarchy]= ISNULL(DCT.[NumberHierarchy], DST.[NumberHierarchy])
			,[ReplaceStringYN]= ISNULL(DCT.[ReplaceStringYN], DST.[ReplaceStringYN])
			--,[DefaultSetMemberKey]
			--,[DefaultGetMemberKey]
			--,[DefaultGetHierarchyNo]
			,[DimensionFilter]= ISNULL(DCT.[DimensionFilter], DST.[DimensionFilter])
			,[ETLProcedure]= ISNULL(DCT.[ETLProcedure], DST.[ETLProcedure])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 8 > 0 AND DCT.[DimensionID] = DST.[DimensionID]
					AND DCT.[DeleteYN] = 0
		WHERE
			DST.[InstanceID] = @InstanceID 

		UPDATE
			DH
		SET
			--[Comment]= ISNULL(DCT.[Comment], DH.[Comment])
			--,[InstanceID]= ISNULL(DCT.[InstanceID], DH.[InstanceID])
			--,[VersionID]= ISNULL(DCT.[VersionID], DH.[VersionID])
			--,[DimensionID]= ISNULL(DCT.[DimensionID], DH.[DimensionID])
			--,[DimensionName]= ISNULL(DCT.[DimensionName], DH.[DimensionName])
			[HierarchyNo]= ISNULL(DCT.[HierarchyNo], DH.[HierarchyNo])
			--,[HierarchyName]= ISNULL(DCT.[HierarchyName], DH.[HierarchyName])
			,[FixedLevelsYN]= ISNULL(DCT.[FixedLevelsYN], DH.[FixedLevelsYN])
			,[LockedYN]= ISNULL(DCT.[LockedYN], DH.[LockedYN])
			,[HierarchyTypeID]= ISNULL(DCT.[HierarchyTypeID], DH.[HierarchyTypeID])
		FROM
			[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 8 > 0 AND DCT.[DimensionID] = DH.[DimensionID]
					AND DCT.[DeleteYN] = 0
		WHERE
			DH.[InstanceID] = @InstanceID 
		
		/* Removing logic to update DimensionHierarchyLevel since its a 1-Many relationship with Dimension
		UPDATE
			DHL
		SET
			--[InstanceID]= ISNULL(DCT.[InstanceID], DHL.[InstanceID])
			--,[DimensionID]= ISNULL(DCT.[DimensionID], DHL.[DimensionID])
			[HierarchyNo]= ISNULL(DCT.[HierarchyNo], DHL.[HierarchyNo])
			,[LevelNo]= ISNULL(DCT.[LevelNo], DHL.[LevelNo])
			,[LevelName]= ISNULL(DCT.[LevelName], DHL.[LevelName])
			
		FROM
			[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 8 > 0 AND DCT.[DimensionID] = DHL.[DimensionID]
					AND DCT.[DeleteYN] = 0
		WHERE
			DHL.[InstanceID] = @InstanceID 
		*/

		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
			(
			 [InstanceID]
			--,[DimensionID]
			,[DimensionName]
			,[DimensionDescription]
			,[DimensionTypeID]
			,[ObjectGuiBehaviorBM]
			,[GenericYN]
			,[MultipleProcedureYN]
			,[AllYN]
			,[ReportOnlyYN]
			,[HiddenMember]
			,[Hierarchy]
			,[TranslationYN]
			,[DefaultSelectYN]
			,[DefaultSetMemberKey]
			,[DefaultGetMemberKey]
			,[DefaultGetHierarchyNo]
			,[DefaultValue]
			,[DeleteJoinYN]
			,[SourceTypeBM]
			,[MasterDimensionID]
			,[HierarchyMasterDimensionID]
			,[InheritedFrom]
			,[SeedMemberID]
			,[LoadSP]
			,[MasterDataManagementBM]
			,[ModelingStatusID]
			,[ModelingComment]
			,[Introduced]
			,[SelectYN]
			,[DeletedID]
			,[Version]
			)
		SELECT
			[InstanceID] = @InstanceID
			--,[DimensionID]
			,[DimensionName]
			,CASE WHEN ISNULL([DimensionDescription], '') = '' THEN [DimensionName] ELSE [DimensionDescription] END
			,ISNULL([DimensionTypeID], [dbo].[f_GetDefaultValue] ('Dimension', 'DimensionTypeID'))
			,ISNULL([ObjectGuiBehaviorBM], [dbo].[f_GetDefaultValue] ('Dimension', 'ObjectGuiBehaviorBM'))
			,ISNULL([GenericYN],0)
			,ISNULL([MultipleProcedureYN],0)
			,ISNULL([AllYN],1)
			,ISNULL([ReportOnlyYN], [dbo].[f_GetDefaultValue] ('Dimension', 'ReportOnlyYN'))
			,ISNULL([HiddenMember],'All')
			,[Hierarchy]
			,ISNULL([TranslationYN],1)
			,ISNULL([DefaultSelectYN],1)
			,ISNULL([DefaultSetMemberKey], [dbo].[f_GetDefaultValue] ('Dimension', 'DefaultSetMemberKey'))
			,ISNULL([DefaultGetMemberKey],'All_')
			,ISNULL([DefaultGetHierarchyNo], [dbo].[f_GetDefaultValue] ('Dimension', 'DefaultGetHierarchyNo'))
			,[DefaultValue]
			,ISNULL([DeleteJoinYN],0)
			,ISNULL([SourceTypeBM],65535)
			,ISNULL([MasterDimensionID], [dbo].[f_GetDefaultValue] ('Dimension', 'MasterDimensionID'))
			,[HierarchyMasterDimensionID]
			,[InheritedFrom]
			,ISNULL([SeedMemberID], [dbo].[f_GetDefaultValue] ('Dimension', 'SeedMemberID'))
			,ISNULL([LoadSP], CASE WHEN ISNULL([DimensionTypeID],[dbo].[f_GetDefaultValue] ('Dimension', 'DimensionTypeID')) = 27 THEN 'MultiDim' ELSE [dbo].[f_GetDefaultValue] ('Dimension', 'LoadSP') END)
			,ISNULL([MasterDataManagementBM],15)
			,ISNULL([ModelingStatusID], [dbo].[f_GetDefaultValue] ('Dimension', 'ModelingStatusID'))
			,ISNULL([ModelingComment], [dbo].[f_GetDefaultValue] ('Dimension', 'ModelingComment'))
			,ISNULL([Introduced],@Version)
			,ISNULL([SelectYN], [dbo].[f_GetDefaultValue] ('Dimension', 'SelectYN'))
			,[DeletedID]
			,ISNULL([Version],@Version)
		FROM
			#DataClassTable DCT
		WHERE	
			DCT.[ResultTypeBM] & 8 > 0 AND
			DCT.[DeleteYN] = 0 AND
			DCT.[DataOriginID] IS NULL AND
			NOT EXISTS (
				SELECT 1 FROM [pcINTEGRATOR].[dbo].[Dimension] D
					WHERE	D.[InstanceID] IN (@InstanceID ,0)
							AND D.[DimensionName]=DCT.[DimensionName]
							AND D.[DeletedID] IS NULL)
			
		SELECT @Inserted = @Inserted + @@ROWCOUNT, 	@LastRowCount=@@ROWCOUNT

		IF @LastRowCount>0 
			BEGIN

				SET @SQLStatement='SELECT TOP ' +  CONVERT(nvarchar(15), @LastRowCount) + ' ResultTypeBM = 8, D.DimensionID, D.DimensionName
					FROM [pcINTEGRATOR_Data].[dbo].[Dimension] D 
						WHERE D.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' ORDER BY D.DimensionID DESC'

				EXEC (@SQLStatement)

				UPDATE  DCT
					SET DCT.DimensionID=D.DimensionID
					FROM #DataClassTable DCT
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension] D 
							ON	D.DimensionName = DCT.DimensionName
							and	D.[InstanceID] =  @InstanceID

			
					--IF @DebugBM & 2 > 0 SELECT [@LastRowCount] = @LastRowCount

					SELECT @DimensionID=D.DimensionID
					FROM #DataClassTable DCT
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension] D 
							ON	D.DimensionName = DCT.DimensionName
							and	D.[InstanceID] =  @InstanceID


					IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID

			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
			(
				[InstanceID],
				[VersionID],
				[DimensionID], 
				[StorageTypeBM],
				[ObjectGuiBehaviorBM],
				[ReadSecurityEnabledYN],
				[MappingTypeID],
				[NumberHierarchy],
				[ReplaceStringYN],
				[DefaultSetMemberKey],
				[DefaultGetMemberKey],
				[DefaultGetHierarchyNo],
				[DimensionFilter],
				[ETLProcedure]
			)
			SELECT
				[InstanceID] = @InstanceID,
				[VersionID] = @VersionID,
				[DimensionID] = DCT.DimensionID, 
				[StorageTypeBM] = ISNULL(DCT.[StorageTypeBM], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'StorageTypeBM')),
				[ObjectGuiBehaviorBM] = ISNULL(DCT.[ObjectGuiBehaviorBM], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'ObjectGuiBehaviorBM')),
				[ReadSecurityEnabledYN] = ISNULL(DCT.[ReadSecurityEnabledYN], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'ReadSecurityEnabledYN')),
				[MappingTypeID] = ISNULL(DCT.[MappingTypeID], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'MappingTypeID')),
				[NumberHierarchy] = ISNULL(DCT.[NumberHierarchy], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'NumberHierarchy')),
				[ReplaceStringYN] = ISNULL(DCT.[ReplaceStringYN], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'ReplaceStringYN')),
				[DefaultSetMemberKey] = ISNULL(DCT.[DefaultSetMemberKey], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'DefaultSetMemberKey')),
				[DefaultGetMemberKey] = ISNULL(DCT.[DefaultGetMemberKey], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'DefaultGetMemberKey')),
				[DefaultGetHierarchyNo] = ISNULL(DCT.[DefaultGetHierarchyNo], [dbo].[f_GetDefaultValue] ('Dimension_StorageType', 'DefaultGetHierarchyNo')),
				[DimensionFilter] = ISNULL(DCT.[DimensionFilter], [dbo].[f_GetDefaultValue] ('Dimension', 'DimensionFilter')),
				[ETLProcedure] = ISNULL(DCT.[ETLProcedure], [dbo].[f_GetDefaultValue] ('Dimension', 'ETLProcedure'))
			FROM
				#DataClassTable DCT 
			WHERE
				DCT.ResultTypeBM = 8 AND
				DCT.DeleteYN = 0 
				--AND DCT.[DimensionName] = @DimensionName

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
				[Comment] = DCT.DimensionName,
				[InstanceID] = @InstanceID,
				[VersionID] = @VersionID,
				[DimensionID] = DCT.DimensionID, 
				[HierarchyNo] = 0,
				[HierarchyName] = DCT.DimensionName,
				--[HierarchyTypeID] = CASE WHEN @DimensionTypeID = 27 THEN 3 ELSE 1 END,
				[HierarchyTypeID] = CASE WHEN ISNULL([DimensionTypeID],[dbo].[f_GetDefaultValue] ('DimensionHierarchy', 'HierarchyTypeID')) = 27 THEN 3 ELSE 1 END,
				[FixedLevelsYN] = [dbo].[f_GetDefaultValue] ('DimensionHierarchy', 'FixedLevelsYN'),
				[LockedYN] = [dbo].[f_GetDefaultValue] ('DimensionHierarchy', 'LockedYN')	
			FROM #DataClassTable DCT 
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchy] D 
							WHERE D.[InstanceID] = @InstanceID 
								AND D.[VersionID] = @VersionID 
								AND D.[DimensionID] = DCT.DimensionID 
								AND D.[HierarchyNo] = 0)

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
				[Comment] = DCT.DimensionName,
				[InstanceID] = @InstanceID,
				[VersionID] = @VersionID,
				[DimensionID] = DCT.DimensionID, 
				[HierarchyNo] = 0, 
				[LevelNo] = 1,
				[LevelName] = 'TopNode'
			FROM #DataClassTable DCT 
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchyLevel] DHL 
							WHERE DHL.[InstanceID] = @InstanceID 
								AND DHL.[VersionID] = @VersionID 
								AND DHL.[DimensionID] = DCT.DimensionID 
								AND DHL.[HierarchyNo] = 0 
								AND DHL.[LevelNo] = 1)

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
				[Comment] = DCT.DimensionName,
				[InstanceID] = @InstanceID,
				[VersionID] = @VersionID,
				[DimensionID] = DCT.DimensionID, 
				[HierarchyNo] = 0, 
				[LevelNo] = 2,
				[LevelName] = DCT.DimensionName
			FROM #DataClassTable DCT 
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchyLevel] DHL 
							WHERE DHL.[InstanceID] = @InstanceID 
							AND DHL.[VersionID] = @VersionID 
							AND DHL.[DimensionID] = DCT.DimensionID 
							AND DHL.[HierarchyNo] = 0 
							AND DHL.[LevelNo] = 2)



				EXEC [spSetup_Callisto] 
					@UserID=@UserID, 
					@InstanceID=@InstanceID, 
					@VersionID=@VersionID, 
					@SequenceBM = 18, 
					@Debug = @DebugSub	
					

				EXEC [spIU_Dim_Dimension_Generic_Callisto] 
					@UserID=@UserID, 
					@InstanceID=@InstanceID, 
					@VersionID=@VersionID,
					@DimensionID = @DimensionID, 
					@DebugBM = 7


			END


	--Delete
		IF CURSOR_STATUS('local','Delete_Cursor') >= -1 DEALLOCATE Delete_Cursor
		DECLARE Delete_Cursor CURSOR FOR
			
			SELECT
				DCT.[DimensionID]
			FROM	
				#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension] D ON
					D.[InstanceID] = @InstanceID AND
					DCT.[DimensionName]=D.[DimensionName] AND
					DCT.[DeletedID] IS NULL
			WHERE
				DCT.[ResultTypeBM] = 8 AND
				DCT.[DeleteYN] <> 0

			OPEN Delete_Cursor
			FETCH NEXT FROM Delete_Cursor INTO @DimensionID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 8 > 0 SELECT [@DimensionID] = @DimensionID

					EXEC [dbo].[spGet_DeletedItem]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@TableName = 'Dimension',
						@DeletedID = @DeletedID OUT,
						@JobID = @JobID

					UPDATE
						D
					SET
						SelectYN=0,
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[Dimension] D
					WHERE
						D.[InstanceID] = @InstanceID AND
						D.[DimensionID] = @DimensionID AND
						D.[DeletedID] IS NULL
			
					SET @Deleted = @Deleted + @@ROWCOUNT

					DELETE DST
					FROM
						[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
						INNER JOIN #DataClassTable DCT 
							ON DCT.[ResultTypeBM] = 8 
								AND DCT.[DeleteYN] <> 0 
					WHERE
						DST.[InstanceID] = @InstanceID
						AND DST.DimensionID = @DimensionID

					DELETE DH
					FROM
						[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH
						INNER JOIN #DataClassTable DCT 
							ON DCT.[ResultTypeBM] = 8 
								AND DCT.[DeleteYN] <> 0 
					WHERE
						DH.[InstanceID] = @InstanceID
						AND DH.DimensionID = @DimensionID

					DELETE DHL
					FROM
						[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL
						INNER JOIN #DataClassTable DCT 
							ON DCT.[ResultTypeBM] = 8 
								AND DCT.[DeleteYN] <> 0 
					WHERE
						DHL.[InstanceID] = @InstanceID
						AND DHL.DimensionID = @DimensionID

					FETCH NEXT FROM Delete_Cursor INTO @DataOriginDeleteID
				END

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor

		SET @Deleted = @Deleted + @@ROWCOUNT

	END

	SET @Step = '@ResultTypeBM = 12, DataClass and Dimension' 
	IF (@ResultTypeBM & 4 > 0 AND @ResultTypeBM & 8 > 0)
	BEGIN

		--Update
		UPDATE
			DCD
		SET
			[ChangeableYN]= ISNULL(DCT.[ChangeableYN], DCD.[ChangeableYN])
			,[Conversion_MemberKey]= ISNULL(DCT.[Conversion_MemberKey], DCD.[Conversion_MemberKey])
			,[TabularYN]= ISNULL(DCT.[TabularYN], DCD.[TabularYN])
			,[DataClassViewBM]= ISNULL(DCT.[DataClassViewBM], DCD.[DataClassViewBM])
			,[FilterLevel]= ISNULL(DCT.[FilterLevel], DCD.[FilterLevel])
			,[SortOrder]= ISNULL(DCT.[SortOrder], DCD.[SortOrder])
			,[Version]= ISNULL(DCT.[Version], DCD.[Version])
			,[SelectYN]= 1-- ISNULL(DCT.[SelectYN], DCD.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 12 > 0 
					AND DCT.[DataClassID] = DCD.[DataClassID]
					AND DCT.[DimensionID]=DCD.[DimensionID]
					AND DCT.[DeleteYN] =0
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID]  = @VersionID 
			
			
		SET @Updated = @Updated + @@ROWCOUNT
		
		--Insert
		IF EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD 
					INNER JOIN #DataClassTable DCT 
						ON DCT.[ResultTypeBM] = 12  
						AND DCT.[DataClassID] = DCD.[DataClassID]
						AND DCT.[DimensionID]=DCD.[DimensionID]
				WHERE	DCD.[InstanceID] = @InstanceID 
					AND DCD.[VersionID] = @VersionID 
					AND DCD.SelectYN = 1)
			BEGIN 
				
				DELETE DCD
					FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD 
					INNER JOIN #DataClassTable DCT 
						ON DCT.[DataClassID] = DCD.[DataClassID]
				WHERE	DCD.[InstanceID] = @InstanceID 
					AND DCD.[VersionID] = @VersionID 
					AND DCT.[ResultTypeBM] = 12  
					AND DCD.SelectYN = 1

			END



		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
			(
			[InstanceID]
			,[VersionID]
			,[DataClassID]
			,[DimensionID]
			,[ChangeableYN]
			,[Conversion_MemberKey]
			,[TabularYN]
			,[DataClassViewBM]
			,[FilterLevel]
			,[SortOrder]
			,[Version]
			,[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID
			,[VersionID] = @VersionID
			,[DataClassID]
			,[DimensionID]
			,ISNULL([ChangeableYN],0)
			,[Conversion_MemberKey]
			,ISNULL([TabularYN],1)
			,ISNULL([DataClassViewBM],1)
			,ISNULL([FilterLevel],'L')
			,ISNULL([SortOrder],2000)
			,ISNULL([Version],@Version)
			,ISNULL([SelectYN],1)
		FROM
			#DataClassTable DCT
		WHERE	
			DCT.[ResultTypeBM] = 12 AND
			DCT.[DeleteYN] = 0 AND
			NOT EXISTS (
				SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD 
					WHERE	DCD.[InstanceID] = @InstanceID 
						AND DCD.[VersionID] = @VersionID 
						AND DCD.[DataClassID] = DCT.[DataClassID] 
						AND DCD.[DimensionID] = DCT.[DimensionID]
						AND SelectYN = 1)
			
		SET @Inserted = @Inserted + @@ROWCOUNT

		--Delete
		--IF CURSOR_STATUS('local','Delete_Cursor') >= -1 DEALLOCATE Delete_Cursor
		--DECLARE Delete_Cursor CURSOR FOR
			
		--	SELECT
		--		DCT.DataClassID, 
		--		DCT.DimensionID
		--	FROM	
		--		#DataClassTable DCT
		--		INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD ON
		--			DCD.[InstanceID] = @InstanceID AND
		--			DCD.[VersionID] = @VersionID AND
		--			(DCD.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
		--			(DCD.DimensionID = @DimensionID OR @DimensionID IS NULL) AND
		--			DCT.[DeletedID] IS NULL
		--	WHERE
		--		DCT.[ResultTypeBM] & 12 > 0 AND
		--		DCT.[DeleteYN] <> 0

		--	OPEN Delete_Cursor
		--	FETCH NEXT FROM Delete_Cursor INTO @DataClassIDDeleteID, @DimensionIDDeleteID

		--	WHILE @@FETCH_STATUS = 0
		--		BEGIN
		--			IF @DebugBM & 2 > 0 SELECT [@DataOriginDeleteID] = @DataOriginDeleteID

		--			EXEC [dbo].[spGet_DeletedItem]
		--				@UserID = @UserID,
		--				@InstanceID = @InstanceID,
		--				@VersionID = @VersionID,
		--				@TableName = 'DataClass_Dimension',
		--				@DeletedID = @DeletedID OUT,
		--				@JobID = @JobID

					--UPDATE
					--	DCD
					--SET
					--	SelectYN = 0--,@DeletedID

					--FROM
					--	[pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD
					--WHERE
					--	DCD.[InstanceID] = @InstanceID AND
					--	DCD.[VersionID] = @VersionID AND
					--	DCD.[DataClassID] = @DataClassIDDeleteID AND
					--	DCD.[DimensionID] = @DimensionIDDeleteID AND
					--	DCD.[SelectYN] IS NULL
			
					--SET @Deleted = @Deleted + @@ROWCOUNT

		--			FETCH NEXT FROM Delete_Cursor INTO @DataOriginDeleteID
		--		END

		--CLOSE Delete_Cursor
		--DEALLOCATE Delete_Cursor

		UPDATE
			DCD
		SET
			SelectYN = 0--,@DeletedID
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD
				INNER JOIN #DataClassTable DCT 
					ON DCT.[ResultTypeBM] = 12  
					AND DCT.[DataClassID] = DCD.[DataClassID]
					AND DCT.[DimensionID]=DCD.[DimensionID]
					AND DCD.SelectYN=1
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID] = @VersionID  AND
			DCT.[DeleteYN] <> 0

		SET @Deleted = @Deleted + @@ROWCOUNT


	END

	SET @Step = '@ResultTypeBM = 16, Property' 
	IF @ResultTypeBM & 16 > 0 
	BEGIN

		--Update
		UPDATE
			P
		SET
			 [PropertyDescription]= ISNULL(DCT.[PropertyDescription], P.[PropertyDescription])
			,[ObjectGuiBehaviorBM]= ISNULL(DCT.[ObjectGuiBehaviorBM], P.[ObjectGuiBehaviorBM])
			,[DataTypeID]= ISNULL(DCT.[DataTypeID], P.[DataTypeID])
			,[Size]= ISNULL(DCT.[Size], P.[Size])
			,[DependentDimensionID]= ISNULL(DCT.[DependentDimensionID], P.[DependentDimensionID])
			,[StringTypeBM]= ISNULL(DCT.[StringTypeBM], P.[StringTypeBM])
			,[DynamicYN]= ISNULL(DCT.[DynamicYN], P.[DynamicYN])
			,[DefaultValueTable]= ISNULL(DCT.[DefaultValueTable], P.[DefaultValueTable])
			,[DefaultValueView]= ISNULL(DCT.[DefaultValueView], P.[DefaultValueView])
			,[SynchronizedYN]= ISNULL(DCT.[SynchronizedYN], P.[SynchronizedYN])
			,[SortOrder]= ISNULL(DCT.[SortOrder], P.[SortOrder])
			,[SourceTypeBM]= ISNULL(DCT.[SourceTypeBM], P.[SourceTypeBM])
			,[StorageTypeBM]= ISNULL(DCT.[StorageTypeBM], P.[StorageTypeBM])
			,[ViewPropertyYN]= ISNULL(DCT.[ViewPropertyYN], P.[ViewPropertyYN])
			,[HierarchySortOrderYN]= ISNULL(DCT.[HierarchySortOrderYN], P.[HierarchySortOrderYN])
			,[MandatoryYN]= ISNULL(DCT.[MandatoryYN], P.[MandatoryYN])
			,[DefaultSelectYN]= ISNULL(DCT.[DefaultSelectYN], P.[DefaultSelectYN])
			,[Introduced]= ISNULL(DCT.[Introduced], P.[Introduced])
			,[SelectYN]= ISNULL(DCT.[SelectYN], P.[SelectYN])
			,[Version]= ISNULL(DCT.[Version], P.[Version])
			,[DefaultNodeTypeBM]= ISNULL(DCT.[DefaultNodeTypeBM], P.[DefaultNodeTypeBM])
			,[InheritedFrom]= ISNULL(DCT.[InheritedFrom], P.[InheritedFrom])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Property] P
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 16 > 0 
					AND DCT.[PropertyID] = P.[PropertyID]
					AND DCT.[DeleteYN] =0
		WHERE
			P.[InstanceID] = @InstanceID			
			
		SET @Updated = @Updated + @@ROWCOUNT

		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Property]
			(
			 [InstanceID]
			--,[PropertyID]
			,[PropertyName]
			,[PropertyDescription]
			,[ObjectGuiBehaviorBM]
			,[DataTypeID]
			,[Size]
			,[DependentDimensionID]
			,[StringTypeBM]
			,[DynamicYN]
			,[DefaultValueTable]
			,[DefaultValueView]
			,[SynchronizedYN]
			,[SortOrder]
			,[SourceTypeBM]
			,[StorageTypeBM]
			,[ViewPropertyYN]
			,[HierarchySortOrderYN]
			,[MandatoryYN]
			,[DefaultSelectYN]
			,[Introduced]
			,[SelectYN]
			,[Version]
			,[DefaultNodeTypeBM]
			,[InheritedFrom]
			)
		SELECT
			[InstanceID] = @InstanceID
			--,[PropertyID]
			,[PropertyName]
			,[PropertyDescription]
			,ISNULL([ObjectGuiBehaviorBM], 1)
			,ISNULL([DataTypeID],3)
			,[Size]
			,[DependentDimensionID]
			,ISNULL([StringTypeBM],0)
			,ISNULL([DynamicYN],1)
			,[DefaultValueTable]
			,ISNULL([DefaultValueView],'NONE')
			,ISNULL([SynchronizedYN],0)
			,ISNULL([SortOrder],0)
			,ISNULL([SourceTypeBM],65535)
			,ISNULL([StorageTypeBM],0)
			,ISNULL([ViewPropertyYN],0)
			,ISNULL([HierarchySortOrderYN],0)
			,ISNULL([MandatoryYN],1)
			,ISNULL([DefaultSelectYN],1)
			,ISNULL([Introduced],@Version)
			,ISNULL([SelectYN],1)
			,ISNULL([Version],@Version)
			,ISNULL([DefaultNodeTypeBM], 1027)
			,[InheritedFrom]
		FROM
			#DataClassTable DCT
		WHERE	
			DCT.[ResultTypeBM] & 16 > 0 AND
			DCT.[DeleteYN] = 0 AND
			DCT.[PropertyID] IS NULL AND
			NOT EXISTS (
				SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Property] P 
					WHERE P.[InstanceID] = @InstanceID 
							AND P.[PropertyName]=DCT.[PropertyName]
							AND P.[SelectYN] =0)
			
		SELECT @Inserted = @Inserted + @@ROWCOUNT, 	@LastRowCount=@@ROWCOUNT

		IF @LastRowCount>0 
			BEGIN

				SET @SQLStatement='SELECT TOP ' +  CONVERT(nvarchar(15), @LastRowCount) + ' ResultTypeBM = 16, P.PropertyID, P.PropertyName
					FROM [pcINTEGRATOR_Data].[dbo].[Property] P
						WHERE P.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' ORDER BY P.PropertyID DESC'

				EXEC (@SQLStatement)

				UPDATE  DCT
					SET DCT.PropertyID=P.PropertyID
					FROM #DataClassTable DCT
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[Property] P 
							ON	P.PropertyName = DCT.PropertyName
							and	P.[InstanceID] =  @InstanceID

			END
		--Delete
		DELETE P
		FROM
			[pcINTEGRATOR_Data].[dbo].[Property] P
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] = 16 
					AND DCT.[DeleteYN] <> 0 
					AND DCT.[PropertyID] = P.[PropertyID] 
					AND DCT.[PropertyName] = P.[PropertyName]
		WHERE
			P.[InstanceID] = @InstanceID 

		SET @Deleted = @Deleted + @@ROWCOUNT
		
		END 

	SET @Step = '@ResultTypeBM = 24, Property and Dimension' 
	IF (@ResultTypeBM & 16 > 0 AND  @ResultTypeBM & 8 > 0)
		BEGIN

			--Update
			UPDATE
				DP
			SET
				[Comment]= ISNULL(DCT.[Comment], DP.[Comment])
				--,[InstanceID]= ISNULL(DCT.[InstanceID], DP.[InstanceID])
				--,[VersionID]= ISNULL(DCT.[VersionID], DP.[VersionID])
				--,[DimensionID]= ISNULL(DCT.[DimensionID], DP.[DimensionID])
				--,[PropertyID]= ISNULL(DCT.[PropertyID], DP.[PropertyID])
				,[DependencyPrio]= ISNULL(DCT.[DependencyPrio], DP.[DependencyPrio])
				,[TabularYN]= ISNULL(DCT.[TabularYN], DP.[TabularYN])
				,[SortOrder]= ISNULL(DCT.[SortOrder], DP.[SortOrder])
				,[Introduced]= ISNULL(DCT.[Introduced], DP.[Introduced])
				,[SelectYN]= ISNULL(DCT.[SelectYN], DP.[SelectYN])
				,[Version]= ISNULL(DCT.[Version], DP.[Version])
				,[MultiDimYN]= ISNULL(DCT.[MultiDimYN], DP.[MultiDimYN])
				,[NodeTypeBM]= ISNULL(DCT.[NodeTypeBM], DP.[NodeTypeBM])
			FROM
				[pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP
				INNER JOIN #DataClassTable DCT 
					ON DCT.[ResultTypeBM] & 24 > 0 
						AND DCT.[DimensionID] = DP.[DimensionID]
						AND DCT.[PropertyID] = DP.[PropertyID]
						AND DCT.[DeleteYN] =0
			WHERE
				DP.[InstanceID] = @InstanceID AND
				DP.[VersionID]  = @VersionID 			
			
			SET @Updated = @Updated + @@ROWCOUNT

			--Insert
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
				(
				[Comment]
				,[InstanceID]
				,[VersionID]
				,[DimensionID]
				,[PropertyID]
				,[DependencyPrio]
				,[TabularYN]
				,[SortOrder]
				,[Introduced]
				,[SelectYN]
				,[Version]
				,[MultiDimYN]
				,[NodeTypeBM]
				)
			SELECT
				ISNULL([Comment], ' ')
				,[InstanceID] = @InstanceID
				,[VersionID] = @VersionID
				,[DimensionID]
				,[PropertyID]
				,ISNULL([DependencyPrio],0)
				,ISNULL([TabularYN],1)
				,ISNULL([SortOrder],0)
				,ISNULL([Introduced],@Version)
				,ISNULL([SelectYN],1)
				,ISNULL([Version],@Version)
				,ISNULL([MultiDimYN],0)
				,ISNULL([NodeTypeBM],0)
			FROM
				#DataClassTable DCT
			WHERE	
				DCT.[ResultTypeBM] = 24 AND
				DCT.[DeleteYN] = 0 AND
				NOT EXISTS (
					SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP 
						WHERE DP.[InstanceID] = @InstanceID 
							AND DP.[VersionID] = @VersionID 
								AND DP.[DimensionID]=DCT.[DimensionID]
								AND DP.[PropertyID]=DCT.[PropertyID]
								AND DP.[SelectYN]=1)
			
			SET @Inserted = @Inserted + @@ROWCOUNT

			--Delete
			DELETE DP
			FROM
				[pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP
				INNER JOIN #DataClassTable DCT 
					ON DCT.[ResultTypeBM] = 24
						AND DCT.[DeleteYN] <> 0 
						AND DCT.[DimensionID] = DP.[DimensionID]
						AND DCT.[PropertyID] = DP.[PropertyID] 
			WHERE DP.[InstanceID] = @InstanceID 
				AND DP.[VersionID] = @VersionID 

			SET @Deleted = @Deleted + @@ROWCOUNT
	END

	SET @Step = '@ResultTypeBM = 32, Measure'
	IF @ResultTypeBM & 32  >0 
	BEGIN

		--Update
		UPDATE
			M
		SET
			--,[InstanceID]= ISNULL(DCT.[InstanceID], M.[InstanceID])
			--,[DataClassID]= ISNULL(DCT.[DataClassID], M.[DataClassID])
			--,[MeasureID]= ISNULL(DCT.[MeasureID], M.[MeasureID])
			--,[VersionID]= ISNULL(DCT.[VersionID], M.[VersionID])
			[MeasureName]= ISNULL(DCT.[MeasureName], M.[MeasureName])
			,[MeasureDescription]= ISNULL(DCT.[MeasureDescription], M.[MeasureDescription])
			,[SourceFormula]= ISNULL(DCT.[SourceFormula], M.[SourceFormula])
			,[ExecutionOrder]= ISNULL(DCT.[ExecutionOrder], M.[ExecutionOrder])
			,[MeasureParentID]= ISNULL(DCT.[MeasureParentID], M.[MeasureParentID])
			,[DataTypeID]= ISNULL(DCT.[DataTypeID], M.[DataTypeID])
			,[FormatString]= ISNULL(DCT.[FormatString], M.[FormatString])
			,[ValidRangeFrom]= ISNULL(DCT.[ValidRangeFrom], M.[ValidRangeFrom])
			,[ValidRangeTo]= ISNULL(DCT.[ValidRangeTo], M.[ValidRangeTo])
			,[Unit]= ISNULL(DCT.[Unit], M.[Unit])
			,[AggregationTypeID]= ISNULL(DCT.[AggregationTypeID], M.[AggregationTypeID])
			,[TabularYN]= ISNULL(DCT.[TabularYN], M.[TabularYN])
			,[DataClassViewBM]= ISNULL(DCT.[DataClassViewBM], M.[DataClassViewBM])
			,[TabularFormula]= ISNULL(DCT.[TabularFormula], M.[TabularFormula])
			,[TabularFolder]= ISNULL(DCT.[TabularFolder], M.[TabularFolder])
			,[InheritedFrom]= ISNULL(DCT.[InheritedFrom], M.[InheritedFrom])
			,[SortOrder]= ISNULL(DCT.[SortOrder], M.[SortOrder])
			,[ModelingStatusID]= ISNULL(DCT.[ModelingStatusID], M.[ModelingStatusID])
			,[ModelingComment]= ISNULL(DCT.[ModelingComment], M.[ModelingComment])
			,[SelectYN]= ISNULL(DCT.[SelectYN], M.[SelectYN])
			,[DeletedID]= ISNULL(DCT.[DeletedID], M.[DeletedID])
			,[Version]= ISNULL(DCT.[Version], M.[Version])

		FROM
			[pcINTEGRATOR_Data].[dbo].[Measure] M
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 32 > 0 
					AND DCT.[MeasureID] = M.[MeasureID]
					AND DCT.[DeleteYN] =0
		WHERE
			M.[InstanceID] = @InstanceID AND
			M.[VersionID]  = @VersionID 
			
			
		SET @Updated = @Updated + @@ROWCOUNT
		
		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Measure]
			(
			 [InstanceID]
			,[DataClassID]
			--,[MeasureID]
			,[VersionID]
			,[MeasureName]
			,[MeasureDescription]
			,[SourceFormula]
			,[ExecutionOrder]
			,[MeasureParentID]
			,[DataTypeID]
			,[FormatString]
			,[ValidRangeFrom]
			,[ValidRangeTo]
			,[Unit]
			,[AggregationTypeID]
			,[TabularYN]
			,[DataClassViewBM]
			,[TabularFormula]
			,[TabularFolder]
			,[InheritedFrom]
			,[SortOrder]
			,[ModelingStatusID]
			,[ModelingComment]
			,[SelectYN]
			,[DeletedID]
			,[Version]
			)
		SELECT
			[InstanceID] = @InstanceID
			,[DataClassID]
			--,[MeasureID]
			,[VersionID] = @VersionID
			,[MeasureName]
			,[MeasureDescription]
			,[SourceFormula]
			,ISNULL([ExecutionOrder],0)
			,[MeasureParentID]
			,ISNULL([DataTypeID],'-3')
			,[FormatString]
			,[ValidRangeFrom]
			,[ValidRangeTo]
			,ISNULL([Unit],' ')
			,ISNULL([AggregationTypeID],'-1')
			,ISNULL([TabularYN],0)
			,ISNULL([DataClassViewBM],1)
			,[TabularFormula]
			,[TabularFolder]
			,[InheritedFrom]
			,ISNULL([SortOrder],1)
			,ISNULL([ModelingStatusID],-40)
			,ISNULL([ModelingComment],'Default setup')
			,ISNULL([SelectYN],1)
			,[DeletedID]
			,ISNULL([Version],@Version)
		FROM
			#DataClassTable DCT
		WHERE	
			DCT.[ResultTypeBM] & 32 > 0 AND
			DCT.[DeleteYN] = 0 AND
			DCT.[DataOriginID] IS NULL AND
			NOT EXISTS (
				SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Measure] M 
					WHERE M.[InstanceID] = @InstanceID 
						AND M.[VersionID] = @VersionID 
							AND M.[MeasureID]=DCT.[MeasureID]
							AND M.[DeletedID] IS NULL)
			
		SELECT @Inserted = @Inserted + @@ROWCOUNT, 	@LastRowCount=@@ROWCOUNT

		IF @DebugBM & 2 > 0 SELECT @LastRowCount = @LastRowCount


		IF @LastRowCount>0 
			BEGIN

				SET @SQLStatement='SELECT TOP ' +  CONVERT(nvarchar(15), @LastRowCount) + ' ResultTypeBM = 32, M.MeasureID, M.MeasureName
					FROM [pcINTEGRATOR_Data].[dbo].[Measure] M
						WHERE M.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND VersionID ='  + CONVERT(nvarchar(15), @VersionID) + ' ORDER BY M.MeasureID DESC'

				IF @DebugBM & 2 > 0 print @SQLStatement


				EXEC (@SQLStatement)

				UPDATE  DCT
					SET DCT.MeasureID=M.MeasureID
					FROM #DataClassTable DCT
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[Measure] M 
							ON	M.MeasureName = DCT.MeasureName
							and	M.[InstanceID] =  @InstanceID
							AND	M.VersionID = @VersionID

			END

		--Delete
		IF CURSOR_STATUS('local','Delete_Cursor') >= -1 DEALLOCATE Delete_Cursor
		DECLARE Delete_Cursor CURSOR FOR
			
			SELECT
				M.[MeasureID]
			FROM	
				#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Measure] M ON
					M.[InstanceID] = @InstanceID AND
					M.[VersionID] = @VersionID AND
					M.[DataClassID] = DCT.[DataClassID] AND
					M.MeasureName=DCT.MeasureName AND
					M.[DeletedID] IS NULL
			WHERE
				DCT.[ResultTypeBM] = 32 AND
				DCT.[DeleteYN] <> 0

			OPEN Delete_Cursor
			FETCH NEXT FROM Delete_Cursor INTO @MeasureIDDeleteID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@MeasureIDDeleteID] = @MeasureIDDeleteID

					EXEC [dbo].[spGet_DeletedItem]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@TableName = 'Measure',
						@DeletedID = @DeletedID OUT,
						@JobID = @JobID

					UPDATE
						M
					SET
						SelectYN=0,
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[Measure] M
					WHERE
						M.[InstanceID] = @InstanceID AND
						M.[VersionID] = @VersionID AND
						M.[MeasureID] = @MeasureIDDeleteID AND
						M.[DeletedID] IS NULL
			
					SET @Deleted = @Deleted + @@ROWCOUNT
					
					FETCH NEXT FROM Delete_Cursor INTO @MeasureIDDeleteID
				END

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor

	END

	SET @Step = '@ResultTypeBM = 64, Process' 
	IF @ResultTypeBM & 64 >0 
		BEGIN

		--Update
		UPDATE
			P
		SET
			--,[InstanceID]= ISNULL(DCT.[InstanceID], P.[InstanceID])
			--,[ProcessID]= ISNULL(DCT.[ProcessID], P.[ProcessID])
			--,[VersionID]= ISNULL(DCT.[VersionID], P.[VersionID])
			[ProcessBM]= ISNULL(DCT.[ProcessBM], P.[ProcessBM])
			--,[ProcessName]= ISNULL(DCT.[ProcessName], P.[ProcessName])
			,[ProcessDescription]= ISNULL(DCT.[ProcessDescription], P.[ProcessDescription])
			,[Destination_DataClassID]= ISNULL(DCT.[Destination_DataClassID], P.[Destination_DataClassID])
			,[ModelingStatusID]= ISNULL(DCT.[ModelingStatusID], P.[ModelingStatusID])
			,[ModelingComment]= ISNULL(DCT.[ModelingComment], P.[ModelingComment])
			,[InheritedFrom]= ISNULL(DCT.[InheritedFrom], P.[InheritedFrom])
			,[SelectYN]= ISNULL(DCT.[SelectYN], P.[SelectYN])
			,[Version]= ISNULL(DCT.[Version], P.[Version])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Process] P
			INNER JOIN #DataClassTable DCT 
				ON DCT.[ResultTypeBM] & 64 > 0 
					AND DCT.[ProcessID] = P.[ProcessID]
					AND DCT.[DeleteYN] =0
		WHERE
			P.[InstanceID] = @InstanceID AND
			P.[VersionID]  = @VersionID 
						
		SET @Updated = @Updated + @@ROWCOUNT

		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Process]
			(
			 [InstanceID]
			--,[ProcessID]
			,[VersionID]
			,[ProcessBM]
			,[ProcessName]
			,[ProcessDescription]
			,[Destination_DataClassID]
			,[ModelingStatusID]
			,[ModelingComment]
			,[InheritedFrom]
			,[SelectYN]
			,[Version]
			)
		SELECT
			[InstanceID] = @InstanceID
			--,[ProcessID]
			,[VersionID] = @VersionID
			,ISNULL([ProcessBM],'-1')
			--,[ProcessBM]
			,[ProcessName]
			,[ProcessDescription]
			,[Destination_DataClassID]
			,ISNULL([ModelingStatusID],'-40')
			,ISNULL([ModelingComment],'Default setup')
			,[InheritedFrom]
			,ISNULL([SelectYN],1)
			,ISNULL([Version],@Version)
		FROM
			#DataClassTable DCT
		WHERE	
			DCT.[ResultTypeBM] & 64 >0 AND
			DCT.[DeleteYN] = 0 AND
			DCT.[DataOriginID] IS NULL AND
			NOT EXISTS (
				SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Process] P 
					WHERE P.[InstanceID] = @InstanceID 
						AND P.[VersionID] = @VersionID 
							AND P.[ProcessID]=DCT.[ProcessID]
							AND P.[DeletedID] IS NULL
							)
		
		SELECT @Inserted = @Inserted + @@ROWCOUNT, 	@LastRowCount=@@ROWCOUNT

		IF @LastRowCount>0 
			BEGIN

				SET @SQLStatement='SELECT TOP ' +  CONVERT(nvarchar(15), @LastRowCount) + ' ResultTypeBM = 64, P.ProcessID, P.ProcessName
					FROM [pcINTEGRATOR_Data].[dbo].[Process] P 
					WHERE P.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' 
						AND P.VersionID ='  + CONVERT(nvarchar(15), @VersionID) + ' ORDER BY P.ProcessID DESC'
						
				EXEC (@SQLStatement)

				UPDATE  DCT
					SET DCT.ProcessID=P.ProcessID
					FROM #DataClassTable DCT
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P 
							ON P.ProcessName = DCT.ProcessName
							and  P.[InstanceID] =  @InstanceID
							AND P.VersionID = @VersionID

			END

		--Delete
		IF CURSOR_STATUS('local','Delete_Cursor') >= -1 DEALLOCATE Delete_Cursor
		DECLARE Delete_Cursor CURSOR FOR
			
			SELECT
				P.ProcessID
			FROM	
				#DataClassTable DCT
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P ON
					P.[InstanceID] = @InstanceID AND
					P.[VersionID] = @VersionID AND
					P.ProcessName=DCT.ProcessName AND
					P.[DeletedID] IS NULL
			WHERE
				DCT.[ResultTypeBM] = 64 AND
				DCT.[DeleteYN] <> 0

			OPEN Delete_Cursor
			FETCH NEXT FROM Delete_Cursor INTO @ProcessIDDeleteID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ProcessIDDeleteID] = @ProcessIDDeleteID

					EXEC [dbo].[spGet_DeletedItem]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@TableName = 'Process',
						@DeletedID = @DeletedID OUT,
						@JobID = @JobID

					UPDATE
						P
					SET
						SelectYN=0,
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[Process] P
					WHERE
						P.[InstanceID] = @InstanceID AND
						P.[VersionID] = @VersionID AND
						P.ProcessID = @ProcessIDDeleteID AND
						P.[DeletedID] IS NULL
			
					SET @Deleted = @Deleted + @@ROWCOUNT

					FETCH NEXT FROM Delete_Cursor INTO @ProcessIDDeleteID
				END

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor



		----Delete
		--DELETE P
		--FROM
		--	[pcINTEGRATOR_Data].[dbo].[Process] P
		--	INNER JOIN #DataClassTable ET 
		--		ON ET.[ResultTypeBM] & 64 > 0 
		--			AND ET.[DeleteYN] <> 0 
		--			AND ET.[ProcessID] = P.[ProcessID] 
		--WHERE
		--	P.[InstanceID] = @InstanceID AND
		--	P.[VersionID] = @VersionID

		END

	SET @Step = '@ResultTypeBM = 68, DataClass and Process'
	IF (@ResultTypeBM & 4 > 0 AND @ResultTypeBM & 64 > 0)
		BEGIN

			--Update
			UPDATE
				DCP
			SET
				[DataClassID]  = ISNULL(DCT.[DataClassID],DCP.[DataClassID])
				,[ProcessID]   = ISNULL(DCT.[ProcessID],DCP.[ProcessID])
				,[Version]	   = ISNULL(DCT.[Version],DCP.[Version])

			FROM
				[pcINTEGRATOR_Data].[dbo].[DataClass_Process] DCP
				INNER JOIN #DataClassTable DCT 
					ON DCT.[ResultTypeBM] & 68 > 0 
						AND DCT.[DataClassID] = DCP.[DataClassID]
						AND DCT.[ProcessID]=DCP.[ProcessID]
						AND DCT.[DeleteYN] =0
			WHERE
				DCP.[InstanceID] = @InstanceID AND
				DCP.[VersionID]  = @VersionID 
			
			SET @Updated = @Updated + @@ROWCOUNT

			--Insert
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Process]
				(
				[InstanceID],
				[VersionID],
				[DataClassID],
				[ProcessID],
				[Version]
				)
			SELECT
				[InstanceID] = @InstanceID
				,[VersionID] = @VersionID
				,[DataClassID]
				,[ProcessID]
				,ISNULL([Version],@Version)
			FROM
				#DataClassTable DCT
			WHERE	
				DCT.[ResultTypeBM] = 68 AND
				DCT.[DeleteYN] = 0 AND
				NOT EXISTS (
						SELECT 1 FROM [pcINTEGRATOR].[dbo].[DataClass_Process] DCP 
							WHERE	DCP.[InstanceID] = @InstanceID 
								AND DCP.[VersionID] = @VersionID 
								AND DCP.[DataClassID] = DCT.[DataClassID] 
								AND DCP.ProcessID = DCT.ProcessID)
			
			SET @Inserted = @Inserted + @@ROWCOUNT
			

		IF @DebugBM & 2 > 0 SELECT [TempTable_delete] = '#DataClassTable', * FROM #DataClassTable

			--Delete
			DELETE DCP
			FROM
				[pcINTEGRATOR_Data].[dbo].[DataClass_Process] DCP
				INNER JOIN #DataClassTable DCT 
					ON DCT.[ResultTypeBM] = 68 
						AND DCT.DeleteYN<>0
						AND DCT.ProcessID = DCP.ProcessID 
						AND DCT.DataClassID = DCP.DataClassID
			WHERE
				DCP.[InstanceID] = @InstanceID 
				AND DCP.[VersionID] = @VersionID 

			SET @Deleted = @Deleted + @@ROWCOUNT


		END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
