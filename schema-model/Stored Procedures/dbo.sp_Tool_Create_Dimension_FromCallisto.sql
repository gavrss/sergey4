SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Create_Dimension_FromCallisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionName nvarchar(50) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000410,
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
===============================================================================

NOTE: Before executing this sp, please run an Export Application from Modeler.
	1) Select the correct Application in the Modeler
	2) Export Application
	3) Export to SQL Database [pcCALLISTO_Export]
	4) Select 'All Dimensions Definitions
	5) Click OK

===============================================================================

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'sp_Tool_Create_Dimension_FromCallisto',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [sp_Tool_Create_Dimension_FromCallisto] @UserID=-10, @InstanceID=533, @VersionID=1058, @DimensionName = 'Product', @Debug=1
EXEC [sp_Tool_Create_Dimension_FromCallisto] @UserID=-10, @InstanceID=-1425, @VersionID=-1363, @Debug=1

EXEC [sp_Tool_Create_Dimension_FromCallisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DimensionID int,
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(MAX),

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create Full Dimension, from Callisto.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Renamed to [sp_Tool_Create_Dimension_FromCallisto]. Added Insert statements to tables [Process], [DataClass], [DataClass_Process] and [Measure]. Added Delete statements to delete Property if not existing in Callisto.'
		IF @Version = '2.0.2.2148' SET @Description = 'Commented out the [EXEC] line for deleting Property when not existing in other Dimensions.'
		IF @Version = '2.0.2.2149' SET @Description = 'DB-222: Modified Filter for INSERT queries to [Property] and [Dimension_Property] tables. Renamed column [Formula] to [SourceFormula] for table [Measure].'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID. Added VersionID to DimensionHierarchy, DimensionHierarchyLevel and Dimension_Property'
		IF @Version = '2.1.0.2155' SET @Description = 'Added VersionID to NOT EXISTS filter in DimensionHierarchy, DimensionHierarchyLevel and Dimension_Property'
		IF @Version = '2.1.0.2162' SET @Description = 'Modified INSERT query for [DimensionHierarchy] and [DimensionHierarchyLevel].'
		IF @Version = '2.1.1.2168' SET @Description = 'Changed Step order - first Insert data into [Dimension_Property], then Delete properties in [Property] not used in [Dimension_Property].'

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

		SET @UserName = ISNULL(@UserName, suser_name())
		
		EXEC [spGet_Version] @Version = @Version OUT

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT 
			@CallistoDatabase = A.DestinationDatabase
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID

		IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase, [@DimensionName] = @DimensionName, [@Version] = @Version

	SET @Step = 'Create temp table #CallistoDimension'
		CREATE TABLE #CallistoDimension (DimensionCount int)

		SET @SQLStatement = '
			INSERT INTO 
				#CallistoDimension (DimensionCount)
			SELECT 
				DimensionCount = COUNT (1)
			FROM ' + @CallistoDatabase + '.[dbo].[S_Dimensions] 
			' + CASE WHEN @DimensionName IS NOT NULL THEN + ' WHERE Label = ''' + @DimensionName + '''' ELSE  '' END
			
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#CallistoDimension', *	FROM #CallistoDimension

	SET @Step = 'SP-Specific check'
		IF (SELECT DimensionCount FROM #CallistoDimension) < 1
			BEGIN
				SET @Message = 'The Dimension is not existing in Callisto. Please create first the Dimension in the Modeler.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp table #CallistoDimensionHierarchy'
		CREATE TABLE #CallistoDimensionHierarchy
			(
			[Comment] nvarchar(255),
			[InstanceID] int,
			[VersionID] int,
			[DimensionID] int,
			[DimensionName] nvarchar(50),
			[HierarchyNo] int IDENTITY(0,1),
			[HierarchyName] nvarchar(50),
			[FixedLevelsYN] bit,
			[LockedYN] bit
			)

	SET @Step = 'Create temp table #CallistoDimensionHierarchyLevel'
		CREATE TABLE #CallistoDimensionHierarchyLevel
			(
			[Comment] nvarchar(255),
			[InstanceID] int,
			[VersionID] int,
			[DimensionID] int,
			[DimensionName] nvarchar(50),
			[HierarchyNo] int,
			[HierarchyName] nvarchar(50),
			[LevelNo] int,
			[LevelName] nvarchar(50)
			)

	SET @Step = 'Create temp table #Property'
		CREATE TABLE #Property
			(
			[InstanceID] [int],
			[PropertyName] [nvarchar](50),
			[PropertyDescription] [nvarchar](255),
			[ObjectGuiBehaviorBM] [int],
			[DataTypeID] [int],
			[Size] [int],
			[DependentDimensionID] [int],
			[StringTypeBM] [int],
			[DynamicYN] [bit],
			[DefaultValueTable] [nvarchar](255),
			[DefaultValueView] [nvarchar](255),
			[SynchronizedYN] [bit],
			[SortOrder] [int],
			[SourceTypeBM] [int],
			[StorageTypeBM] [int],
			[ViewPropertyYN] [bit],
			[HierarchySortOrderYN] [bit],
			[MandatoryYN] [bit],
			[DefaultSelectYN] [bit],
			[Introduced] [nvarchar](100),
			[SelectYN] [bit],
			[Version] [nvarchar](100)
			)
/*
	SET @Step = 'Insert Process to pcINTEGRATOR_Data, if not existing.'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Process]
				(
				[InstanceID],
				[VersionID],
				[ProcessBM],
				[ProcessName],
				[ProcessDescription],
				[ModelingStatusID],
				[ModelingComment],
				[InheritedFrom],
				[SelectYN]
				)
			SELECT DISTINCT 
				[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(15),@VersionID) + ',
				[ProcessBM] = 0,
				[ProcessName] = M.Label,
				[ProcessDescription] = M.Description,
				[ModelingStatusID] = -40,
				[ModelingComment] = ''Copied from Callisto'',
				[InheritedFrom] = NULL,
				[SelectYN] = 1
			FROM 
				' + @CallistoDatabase + '.[dbo].[Models] M
			WHERE 
				M.Label <> ''Financials_Detail'' AND
				NOT EXISTS (SELECT 1 FROM Process P WHERE P.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND P.ProcessName = M.Label)
			'
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert DataClass to pcINTEGRATOR_Data, if not existing.'
		
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass]
				(
				[InstanceID],
				[VersionID],
				[DataClassName],
				[DataClassDescription],
				[DataClassTypeID],
				[ModelBM],
				[StorageTypeBM],
				[ReadAccessDefaultYN],
				[ActualDataClassID],
				[ModelingStatusID],
				[ModelingComment],
				[InheritedFrom],
				[SelectYN]
				)
			SELECT DISTINCT
				[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(15),@VersionID) + ',				
				[DataClassName] = M.Label,
				[DataClassDescription] = M.Description,
				[DataClassTypeID] = -1,
				[ModelBM] = TM.ModelBM,
				[StorageTypeBM] = 4,
				[ReadAccessDefaultYN] = 1,
				[ActualDataClassID] = NULL,
				[ModelingStatusID] = -40,
				[ModelingComment] = ''Copied from Callisto'',
				[InheritedFrom] = NULL,
				[SelectYN] = 1
			FROM 
				' + @CallistoDatabase + '.[dbo].[Models] M
				LEFT JOIN [@Template_Model] TM ON TM.ModelName = M.Label
			WHERE
				NOT EXISTS (SELECT 1 FROM DataClass DC WHERE DC.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND DC.DataClassName = M.Label)
			'
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert DataClass_Process to pcINTEGRATOR_Data, if not existing.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Process]
			(
			[InstanceID],
			[VersionID],
			[DataClassID],
			[ProcessID]
			)
		SELECT 
			[InstanceID] = DC.InstanceID,
			[VersionID] = DC.VersionID,
			[DataClassID] = DC.DataClassID,
			[ProcessID] = P.ProcessID
		FROM 
			[DataClass] DC
			INNER JOIN [Process] P ON P.InstanceID = DC.InstanceID AND P.VersionID = DC.VersionID AND DC.DataClassName LIKE P.ProcessName + '%'
		WHERE
			DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Process] DCP WHERE DCP.[InstanceID] = DC.InstanceID AND DCP.[VersionID] = DC.VersionID AND DCP.[DataClassID] = DC.DataClassID AND DCP.[ProcessID] = P.ProcessID )
				
		SET @Inserted = @Inserted + @@ROWCOUNT 

	SET @Step = 'Insert Measure to pcINTEGRATOR_Data, if not existing.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Measure]
			(
			[InstanceID],
			[DataClassID],
			[VersionID],
			[MeasureName],
			[MeasureDescription],
			[SourceFormula],
			[ExecutionOrder],
			[MeasureParentID],
			[DataTypeID],
			[FormatString],
			[ValidRangeFrom],
			[ValidRangeTo],
			[Unit],
			[AggregationTypeID],
			[InheritedFrom],
			[SortOrder],
			[ModelingStatusID],
			[ModelingComment]
			)
		SELECT DISTINCT
			[InstanceID] = @InstanceID,
			[DataClassID] = DC.DataClassID,
			[VersionID] = @VersionID,
			[MeasureName] = DC.DataClassName,
			[MeasureDescription] = 'Unified measure',
			[SourceFormula] = NULL,
			[ExecutionOrder] = 0,
			[MeasureParentID] = NULL,
			[DataTypeID] = -3,
			[FormatString] = '#,##0',
			[ValidRangeFrom] = NULL,
			[ValidRangeTo] = NULL,
			[Unit] = 'Generic',
			[AggregationTypeID] = -1,
			[InheritedFrom] = NULL,
			[SortOrder] = 1,
			[ModelingStatusID] = -40,
			[ModelingComment] = 'Copied from Callisto'
		FROM 
			DataClass DC 
		WHERE
			DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND
			NOT EXISTS (SELECT 1 FROM Measure M WHERE M.InstanceID = @InstanceID AND M.VersionID = @VersionID AND M.DataClassID = DC.DataClassID AND M.MeasureName = DC.DataClassName)
		
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert Dimension to pcINTEGRATOR_Data, if not existing.'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
				(
				[InstanceID],
				[DimensionName],
				[DimensionDescription],
				[DimensionTypeID],
				[ObjectGuiBehaviorBM],
				[GenericYN],
				[MultipleProcedureYN],
				[AllYN],
				[HiddenMember],
				[Hierarchy],
				[TranslationYN],
				[DefaultSelectYN],
				[DefaultValue],
				[DeleteJoinYN],
				[SourceTypeBM],
				[MasterDimensionID],
				[HierarchyMasterDimensionID],
				[InheritedFrom],
				[SeedMemberID],
				[ModelingStatusID],
				[ModelingComment],
				[Introduced],
				[SelectYN],
				[DeletedID],
				[Version]
				)
			SELECT DISTINCT
				[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
				[DimensionName] = D.Label,
				[DimensionDescription] = D.Label,
				[DimensionTypeID] = ISNULL(DT.DimensionTypeID, 0),
				[ObjectGuiBehaviorBM] = 1,
				[GenericYN] = 0,
				[MultipleProcedureYN] = 0,
				[AllYN] = 1,
				[HiddenMember] = ''All'',
				[Hierarchy] = NULL,
				[TranslationYN] = 1,
				[DefaultSelectYN] = 1,
				[DefaultValue] = NULL,
				[DeleteJoinYN] = 0,
				[SourceTypeBM] = 65535,
				[MasterDimensionID] = NULL,
				[HierarchyMasterDimensionID] = NULL,
				[InheritedFrom] = NULL,
				[SeedMemberID] = 1001,
				[ModelingStatusID] = -40,
				[ModelingComment] = ''Copied from Callisto'',
				[Introduced] = ''' + @Version + ''',
				[SelectYN] = 1,
				[DeletedID] = NULL,
				[Version] = ''' + @Version + '''
			FROM 
				' + @CallistoDatabase + '.[dbo].[S_Dimensions] D
				LEFT JOIN [pcINTEGRATOR].[dbo].[DimensionType] DT ON DT.InstanceID IN (0, ' + CONVERT(nvarchar(15),@InstanceID) +') AND DT.[DimensionTypeName] = D.Type
			WHERE
				' + CASE WHEN @DimensionName IS NOT NULL THEN + ' D.Label = ''' + @DimensionName + ''' AND ' ELSE  '' END + '
				NOT EXISTS (SELECT 1 FROM Dimension DD WHERE DD.InstanceID IN (0, ' + CONVERT(nvarchar(15),@InstanceID) + ') AND DD.DimensionName = D.Label)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Dimension', * FROM [pcINTEGRATOR_Data].[dbo].[Dimension] D WHERE D.[InstanceID] = @InstanceID AND D.[DimensionID] = @DimensionID 

	SET @Step = 'Insert DataClass_Dimension to pcINTEGRATOR_Data, if not existing.'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
				(
				[InstanceID],
				[VersionID],
				[DataClassID],
				[DimensionID],
				[FilterLevel],
				[SortOrder],
				[Version]
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(15),@VersionID) + ',
				[DataClassID] = DC.DataClassID,
				[DimensionID] = D.DimensionID,
				[FilterLevel] = ''L'',
				[SortOrder] = 1,
				[Version] = ''' + @Version + '''
			FROM
				' + @CallistoDatabase + '.[dbo].[ModelDimensions] MD
				INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.InstanceID IN (0, ' + CONVERT(nvarchar(15),@InstanceID) + ') AND D.DimensionName = MD.Dimension 
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(15),@VersionID) + ' AND DC.DataClassName = MD.Model
			WHERE
				' + CASE WHEN @DimensionName IS NOT NULL THEN + ' MD.Dimension = ''' + @DimensionName + ''' AND ' ELSE  '' END + '	 
				NOT EXISTS (SELECT 1 FROM DataClass_Dimension DCD WHERE DCD.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND DCD.VersionID = ' + CONVERT(nvarchar(15),@VersionID) + ' AND DCD.DataClassID = DC.DataClassID AND DCD.DimensionID = D.DimensionID)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..DataClass_Dimension', * FROM DataClass_Dimension DCD WHERE DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DimensionID = @DimensionID
*/
	SET @Step = 'Create temp table #Dim_Cur_Table'
		CREATE TABLE #Dim_Cur_Table
			(
			DimensionID int,	
			DimensionName nvarchar(50)
			)

		SET @SQLStatement = '
			INSERT INTO #Dim_Cur_Table
				(
				DimensionID,	
				DimensionName
				)
			SELECT	
				DimensionID,
				DimensionName
			FROM 
				Dimension D
				INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_Dimensions] SD ON SD.Label = D.DimensionName
			WHERE
				D.InstanceID IN (0, ' + CONVERT(nvarchar(15),@InstanceID) + ') ' + CASE WHEN @DimensionName IS NOT NULL THEN 'AND D.DimensionName = ''' + @DimensionName + '''' ELSE '' END				

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Dim_Cur_Table', * FROM #Dim_Cur_Table
        
	SET @Step = 'Dimension Cursor'
		DECLARE Dimension_Cursor CURSOR FOR
			
			SELECT	
				DimensionID,
				DimensionName
			FROM 
				#Dim_Cur_Table

			OPEN Dimension_Cursor
			FETCH NEXT FROM Dimension_Cursor INTO @DimensionID, @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName
/*					
					SET @Step = 'Insert Dimension_StorageType to pcINTEGRATOR_Data, if not existing.'
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
							(
							[InstanceID],
							[VersionID],
							[DimensionID],
							[StorageTypeBM],
							[ReadSecurityEnabledYN],
							[Version]
							)
						SELECT 
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[DimensionID] = D.DimensionID,
							[StorageTypeBM] = 4,
							[ReadSecurityEnabledYN] = 0,
							[Version] = @Version
						FROM [pcINTEGRATOR].[dbo].[Dimension] D
						WHERE
							D.InstanceID IN (0, @InstanceID) AND 
							D.DimensionName = @DimensionName AND
							NOT EXISTS (SELECT 1 FROM Dimension_StorageType DST WHERE DST.[InstanceID] = @InstanceID AND DST.[VersionID] = @VersionID AND DST.[DimensionID] = D.DimensionID)
			
						SET @Inserted = @Inserted + @@ROWCOUNT 
			
						IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Dimension_StorageType', * FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST WHERE DST.[InstanceID] = @InstanceID AND DST.[VersionID] = @VersionID AND DST.[DimensionID] = @DimensionID 
*/
					SET @Step = 'Insert Property to pcINTEGRATOR_Data, if not existing.'
						SET @SQLStatement = '
							INSERT INTO #Property
								(
								[InstanceID],	
								[PropertyName],
								[PropertyDescription],
								[ObjectGuiBehaviorBM],
								[DataTypeID],
								[Size],
								[DependentDimensionID],
								[StringTypeBM],
								[DynamicYN],
								[DefaultValueTable],
								[DefaultValueView],
								[SynchronizedYN],
								[SortOrder],
								[SourceTypeBM],
								[StorageTypeBM],
								[ViewPropertyYN],
								[HierarchySortOrderYN],
								[MandatoryYN],
								[DefaultSelectYN],
								[Introduced],
								[SelectYN],
								[Version]
								)
							SELECT 
								[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
								[PropertyName] = C.name,
								[PropertyDescription] = C.name,
								[ObjectGuiBehaviorBM] = 9,
								[DataTypeID] = CASE WHEN M.DataType IS NOT NULL THEN 3 ELSE DT.DataTypeID END,
								[Size] = CASE WHEN Ty.name IN (''nvarchar'',''varchar'', ''nchar'', ''char'') AND M.PropertyName IS NULL THEN C.max_length/2 ELSE NULL END,
								[DependentDimensionID] = D.DimensionID,
								[StringTypeBM] = 0,
								[DynamicYN] = 1,
								[DefaultValueTable] = NULL,
								[DefaultValueView] = ''NONE'',
								[SynchronizedYN] = 1,
								[SortOrder] = C.column_id + 30,
								[SourceTypeBM] = 65535,
								[StorageTypeBM] = 4,
								[ViewPropertyYN] = 0,
								[HierarchySortOrderYN] = 0,
								[MandatoryYN] = 1,
								[DefaultSelectYN] = 1,
								[Introduced] = ''' + @Version + ''',
								[SelectYN] = 1,
								[Version] = ''' + @Version + '''
							FROM 
								' + @CallistoDatabase + '.sys.tables T 
								INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.name NOT IN (''MemberId'', ''Label'', ''Description'', ''HelpText'', ''RNodeType'', ''SBZ'', ''Source'', ''Synchronized'') AND C.NAME NOT LIKE ''%_MemberId''
								INNER JOIN ' + @CallistoDatabase + '.sys.types Ty ON Ty.system_type_id = C.system_type_id AND Ty.user_type_id = C.user_type_id
								LEFT JOIN
								(
								SELECT DataType = ''Member'', PropertyName = REPLACE(C.Name,''_MemberId'', '''') 
								FROM ' + @CallistoDatabase + '.sys.tables T 
									INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON c.object_id = T.object_id AND C.name LIKE ''%_MemberId''
								WHERE T.name = ''S_DS_' + @DimensionName + '''
								)
								AS M ON M.PropertyName = C.name
								LEFT JOIN [pcINTEGRATOR].[dbo].[DataType] DT ON DT.DataTypeID IN (1,2,4,5,8,9) AND DT.DataTypeCode = ISNULL(CONVERT(NVARCHAR(100),M.DataType), Ty.name)
								LEFT JOIN [pcCALLISTO_Export].[dbo].[XT_PropertyDefinition] XPD ON XPD.Dimension = ''' + @DimensionName + ''' AND XPD.Label = C.name AND XPD.DataType = ''Member''
								LEFT JOIN 
								(
								SELECT InstanceID, DimensionID, DimensionName 
								FROM [pcINTEGRATOR].[dbo].[Dimension] 
								WHERE InstanceID IN (0, ' + CONVERT(nvarchar(15),@InstanceID) + ')
								)
								AS D ON D.DimensionName = XPD.MemberDimension
							WHERE
								T.name = ''S_DS_' + @DimensionName + ''' AND
								NOT EXISTS (SELECT 1 FROM Property PR WHERE PR.InstanceID IN (0, ' + CONVERT(nvarchar(15),@InstanceID) + ') AND PR.PropertyName = C.name)
							ORDER BY 
								C.column_id'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC(@SQLStatement)

						IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Property', * FROM [#Property] P

						SET @SQLStatement = '
							INSERT INTO pcINTEGRATOR_Data..Property
								(
								[InstanceID],
								[PropertyName],
								[PropertyDescription],
								[ObjectGuiBehaviorBM],
								[DataTypeID],
								[Size],
								[DependentDimensionID],
								[StringTypeBM],
								[DynamicYN],
								[DefaultValueTable],
								[DefaultValueView],
								[SynchronizedYN],
								[SortOrder],
								[SourceTypeBM],
								[StorageTypeBM],
								[ViewPropertyYN],
								[HierarchySortOrderYN],
								[MandatoryYN],
								[DefaultSelectYN],
								[Introduced],
								[SelectYN],
								[Version]
								)
							SELECT 
								[InstanceID],	
								[PropertyName],
								[PropertyDescription],
								[ObjectGuiBehaviorBM],
								[DataTypeID],
								[Size],
								[DependentDimensionID],
								[StringTypeBM],
								[DynamicYN],
								[DefaultValueTable],
								[DefaultValueView],
								[SynchronizedYN],
								[SortOrder],
								[SourceTypeBM],
								[StorageTypeBM],
								[ViewPropertyYN],
								[HierarchySortOrderYN],
								[MandatoryYN],
								[DefaultSelectYN],
								[Introduced],
								[SelectYN],
								[Version]
							FROM 
								#Property
							ORDER BY 
								[SortOrder]'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC(@SQLStatement)

						SET @Inserted = @Inserted + @@ROWCOUNT
/*
					SET @Step = 'Delete Dimension_Property in pcINTEGRATOR_Data, if Property is not existing in Callisto.'
						SET @SQLStatement = '
							DELETE DP
							FROM 
								[pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[Property] P ON P.PropertyID = DP.PropertyID
							WHERE
								DP.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND
								DP.VersionID = ' + CONVERT(nvarchar(15),@VersionID) + ' AND
								DP.DimensionID = ' + CONVERT(nvarchar(15),@DimensionID) + ' AND
								NOT EXISTS 
									(
									SELECT 1
									FROM 
										#Property TP
									WHERE
										TP.[PropertyName] = P.[PropertyName] AND
										P.[PropertyName] NOT IN (''MemberId'', ''Label'', ''Description'', ''HelpText'', ''RNodeType'', ''SBZ'', ''Source'', ''Synchronized'') AND
										P.[PropertyName] NOT LIKE ''%_MemberId''
									)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC(@SQLStatement)

						SET @Deleted = @Deleted + @@ROWCOUNT

						IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Dimension_Property', * FROM [pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP WHERE DP.InstanceID = @InstanceID AND DP.VersionID = @VersionID AND DP.DimensionID = @DimensionID
*/
					SET @Step = 'Insert Dimension_Property to pcINTEGRATOR_Data, if not existing.'
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[DimensionID],
							[PropertyID],
							[SortOrder],
							[Introduced],
							[SelectYN],
							[Version]
							)
						SELECT
							[Comment] = P.PropertyName,
							P.[InstanceID],
							[VersionID] = @VersionID,
							[DimensionID] = @DimensionID,
							P.[PropertyID],
							P.[SortOrder],
							P.[Introduced],
							P.[SelectYN],
							P.[Version]
						FROM
							#Property TP
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[Property] P ON P.InstanceID = @InstanceID AND P.PropertyName = TP.PropertyName
						WHERE
							NOT EXISTS (SELECT 1 FROM Dimension_Property DP WHERE DP.InstanceID IN (0, @InstanceID) AND DP.VersionID IN (0, @VersionID) AND DP.DimensionID = @DimensionID AND DP.PropertyID = P.PropertyID)

						SET @Inserted = @Inserted + @@ROWCOUNT

						IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Dimension_Property', * FROM Dimension_Property DP WHERE DP.InstanceID = @InstanceID AND DP.VersionID = @VersionID AND DP.DimensionID = @DimensionID ORDER BY DP.SortOrder
/*
					SET @Step = 'Delete Property in pcINTEGRATOR_Data, if Property is not used in other Dimensions.'
						SET @SQLStatement = '
							DELETE P
							FROM 
								[pcINTEGRATOR_Data].[dbo].[Property] P
							WHERE
								P.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP WHERE DP.InstanceID = P.InstanceID AND DP.VersionID = ' + CONVERT(nvarchar(15),@VersionID) + ' AND DP.PropertyID = P.PropertyID)'
							
						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC(@SQLStatement)

						SET @Deleted = @Deleted + @@ROWCOUNT

						IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Property', * FROM [pcINTEGRATOR_Data].[dbo].[Property] P WHERE P.InstanceID = @InstanceID

					SET @Step = 'Insert values to #CallistoDimensionHierarchy.'
						INSERT INTO #CallistoDimensionHierarchy
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[DimensionID],
							[DimensionName],
							[HierarchyName],
							[FixedLevelsYN],
							[LockedYN]
							)
						SELECT
							[Comment] = XHD.Dimension,
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[DimensionID] = @DimensionID,
							[DimensionName] = XHD.[Dimension],
							[HierarchyName] = XHD.[Label],
							[FixedLevelsYN] = 1,
							[LockedYN] = 0
						FROM 
							[pcCALLISTO_Export].[dbo].[XT_HierarchyDefinition] XHD
						WHERE
							XHD.[Dimension] = @DimensionName --AND XHD.Dimension <> XHD.Label

						IF @DebugBM & 2 > 0 SELECT [TempTable] = '#CallistoDimensionHierarchy', * FROM #CallistoDimensionHierarchy

					SET @Step = 'Insert DimensionHierarchy to pcINTEGRATOR_Data, if not existing.'
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[DimensionID],
							[HierarchyNo],
							[HierarchyName],
							[FixedLevelsYN],
							[LockedYN],
							[Version]
							)
						SELECT
							[Comment],
							[InstanceID],
							[VersionID],
							[DimensionID],
							[HierarchyNo],
							[HierarchyName],
							[FixedLevelsYN],
							[LockedYN],
							[Version] = @Version
						FROM
							#CallistoDimensionHierarchy C
						WHERE
							NOT EXISTS (SELECT 1 FROM DimensionHierarchy DH WHERE DH.InstanceID IN (0, C.InstanceID) AND DH.VersionID IN (0, C.VersionID) AND DH.DimensionID = C.DimensionID AND DH.HierarchyName = C.HierarchyName)

						SET @Inserted = @Inserted + @@ROWCOUNT 

						IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..DimensionHierarchy', * FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH WHERE DH.[InstanceID] = @InstanceID AND DH.[VersionID] = @VersionID AND DH.[DimensionID] = @DimensionID

					SET @Step = 'Insert values to #CallistoDimensionHierarchyLevel.'
						INSERT INTO #CallistoDimensionHierarchyLevel
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[DimensionID],
							[DimensionName],
							[HierarchyNo],
							[HierarchyName],
							[LevelNo],
							[LevelName]
							)
						SELECT
							[Comment] = C.HierarchyName,
							[InstanceID] = MAX(C.InstanceID),
							[VersionID] = MAX(C.VersionID),
							[DimensionID] = MAX(C.DimensionID),
							[DimensionName] = MAX(C.DimensionName),
							[HierarchyNo] = C.HierarchyNo,
							[HierarchyName] = C.HierarchyName,
							[LevelNo] = ISNULL(XHL.SequenceNumber, T.LevelNo),
							[LevelName] = ISNULL(XHL.LevelName, T.LevelName)
						FROM 
							#CallistoDimensionHierarchy C
							LEFT JOIN [pcCALLISTO_Export].[dbo].[XT_HierarchyLevels] XHL ON XHL.Dimension = C.DimensionName AND XHL.Hierarchy = C.HierarchyName
							LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_DimensionHierarchyLevel] T ON T.DimensionID = C.DimensionID
						WHERE
							C.InstanceID = @InstanceID AND 
							C.VersionID = @VersionID AND 
							C.DimensionName = @DimensionName
						GROUP BY
							C.HierarchyNo, 
							C.HierarchyName, 
							ISNULL(XHL.SequenceNumber, T.LevelNo),
							ISNULL(XHL.LevelName, T.LevelName)
						ORDER BY 
							C.HierarchyNo, 
							ISNULL(XHL.SequenceNumber, T.LevelNo)

						IF @DebugBM & 2 > 0 SELECT [TempTable] = '#CallistoDimensionHierarchyLevel', * FROM #CallistoDimensionHierarchyLevel

					SET @Step = 'Insert DimensionHierarchyLevel to pcINTEGRATOR_Data, if not existing.'
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[DimensionID],
							[HierarchyNo],
							[LevelNo],
							[LevelName],
							[Version]
							)
						SELECT
							[Comment],
							[InstanceID],
							[VersionID],
							[DimensionID],
							[HierarchyNo],
							[LevelNo],
							[LevelName],
							[Version] = @Version
						FROM
							#CallistoDimensionHierarchyLevel C
						WHERE
							NOT EXISTS (SELECT 1 FROM DimensionHierarchyLevel DHL WHERE DHL.InstanceID IN (0, C.InstanceID) AND DHL.VersionID IN (0, C.VersionID) AND DHL.DimensionID = C.DimensionID AND DHL.HierarchyNo = C.HierarchyNo AND DHL.LevelNo = C.LevelNo)
	
						SET @Inserted = @Inserted + @@ROWCOUNT

						IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..DimensionHierarchyLevel', * FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = @InstanceID AND DHL.[VersionID] = @VersionID AND DHL.[DimensionID] = @DimensionID
*/			
					TRUNCATE TABLE #Property
					TRUNCATE TABLE #CallistoDimensionHierarchy
					TRUNCATE TABLE #CallistoDimensionHierarchyLevel

				FETCH NEXT FROM Dimension_Cursor INTO @DimensionID, @DimensionName
				END

		CLOSE Dimension_Cursor
		DEALLOCATE Dimension_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE #CallistoDimension
		DROP TABLE #CallistoDimensionHierarchy
		DROP TABLE #CallistoDimensionHierarchyLevel
		DROP TABLE #Dim_Cur_Table
		DROP TABLE #Property

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
