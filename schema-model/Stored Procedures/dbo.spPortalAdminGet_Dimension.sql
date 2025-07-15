SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Dimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 4095,
	--   1 = Dimension
	--   2 = Property
	--   4 = Hierarchy
	--   8 = HierarchyLevel
	--  16 = DimensionType
	--  32 = StorageType
	--  64 = ObjectGUIBehavior
	-- 128 = MappingType
	-- 256 = ModelingStatus
	-- 512 = DataType
	--1024 = Available dimensions
	--2048 = Available properties
	--4096 = MultiDim
	--8192 = Hierarchy types
	--16384 = NodeTypeBM
	@DimensionID int = NULL, --@DimensionID = NULL + @ResultTypeBM = 1 gives a full list of Dimensions
	@HierarchyNo int = NULL,
	@LevelNo int = NULL,
	@ProcessID int = NULL,
	@DataClassID int = NULL,
	@ObjectGuiBehaviorBM int = 1,
	@OrganizationHierarchyID int = NULL,
	@StorageTypeBM int = NULL,
	@DimensionList nvarchar(1000) = NULL, --Valid for @ResultTypeBM=4096 AND DimensionTypeID=27
	@DataClassList nvarchar(1000) = NULL, --Valid for @ResultTypeBM=4096 AND DimensionTypeID=27

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000282,
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
--Get Dimensions list
EXEC [spRun_Procedure_KeyValuePair] @JSON='[
	{"TKey":"Debug","TValue":"0"},
	{"TKey":"InstanceID","TValue":"413"},
	{"TKey":"UserID","TValue":"2147"},
	{"TKey":"VersionID","TValue":"1008"},
	{"TKey":"ResultTypeBM","TValue":"1"}
]', @ProcedureName='spPortalAdminGet_Dimension'

EXEC [spPortalAdminGet_Dimension] @UserID = 1005, @InstanceID = 574, @VersionID = 1045, @DimensionID = -1, @ResultTypeBM = 4095, @Debug = 0

EXEC [spPortalAdminGet_Dimension] @UserID = -10, @InstanceID = 15, @VersionID = 1039, @ResultTypeBM = 1, @DebugBM = 2
EXEC [spPortalAdminGet_Dimension] @UserID = -10, @InstanceID = 15, @VersionID = 1039, @ResultTypeBM = 127, @DimensionID = -1
EXEC [pcINTEGRATOR].[dbo].[spPortalAdminGet_Dimension] @InstanceID='531',@ObjectGuiBehaviorBM='63',@ResultTypeBM='1',@UserID='26626',@VersionID='1041', @DebugBM=7

EXEC [spPortalAdminGet_Dimension] @UserID=-10, @InstanceID = 531, @VersionID = 1041, @DimensionID = 9155, @ResultTypeBM=4096, @DimensionList = '-32', @DataClassList = '13864'

EXEC [spPortalAdminGet_Dimension] @UserID=-10, @InstanceID = 531, @VersionID = 1041, @DimensionID = 9155, @ResultTypeBM=8192
EXEC [spPortalAdminGet_Dimension] @UserID=-10, @InstanceID = 531, @VersionID = 1041, @DimensionID = 9155, @ResultTypeBM=4

EXEC [spPortalAdminGet_Dimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@Cursor_DimensionID int,
	@DimensionName nvarchar(100),
	@DimensionTypeID int,
	@Cursor_StorageTypeBM int,
	@DefaultSetMemberKey nvarchar(100),
	@DefaultGetMemberKey nvarchar(100),
	@SQLStatement nvarchar(max),

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns meta data for Dimensions.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Enhanced structure.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added ResultTypeBM.'
		IF @Version = '2.1.0.2156' SET @Description = 'Added ReplaceStringYN. Fixed duplicates for ResultTypeBM = 1. @DataClassID and @ObjectGuiBehaviorBM added as filter. DB-472, DB-514: Modified query for @ResultTypeBM = 1 (Get Dimension Info), changed to dynamic.'
		IF @Version = '2.1.0.2159' SET @Description = 'DB-537: Modified dynamic query for @ResultTypeBM = 1. Purpose of table OrganizationHierarchy_Process must be verified, temporary disabled.'
		IF @Version = '2.1.0.2161' SET @Description = 'Modified dynamic query for @ResultTypeBM = 1; not include INNER JOINS to [DataClass_Dimension] and [DataClass_Process] IF @DataClassID and @ProcessID are both NULL.'
		IF @Version = '2.1.2.2177' SET @Description = 'DB-708: Handle MultiDim ResultTypeBM = 4096.'
		IF @Version = '2.1.2.2179' SET @Description = 'Updated list of Hierarchy properties.'
		IF @Version = '2.1.2.2180' SET @Description = 'Test on Dimension.SelectYN and DeletedID.'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-1934: Include DimensionTypeID = -1 (GL_Segment) in @ResultTypeBM = 16 (DimensionType) resultset.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @DebugBM & 2 > 0 
			SELECT 
				[@InstanceID] = @InstanceID, 
				[@VersionID] = @VersionID, 
				[@DataClassID] = @DataClassID, 
				[@ProcessID] = @ProcessID, 
				[@OrganizationHierarchyID] = @OrganizationHierarchyID, 
				[@StorageTypeBM] = @StorageTypeBM, 
				[@DimensionID] = @DimensionID

	SET @Step = 'Get Default members'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					@CallistoDatabase = [DestinationDatabase],
					@ETLDatabase = [ETLDatabase]
				FROM
					[pcINTEGRATOR_Data].[dbo].[Application]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID
				
				CREATE TABLE #DefaultMembers
					(
					[DimensionID] int,
					[MemberKey] nvarchar (100),
					[Description] nvarchar (255)
					)

				IF CURSOR_STATUS('global','DefaultMember_Cursor') >= -1 DEALLOCATE DefaultMember_Cursor
				DECLARE DefaultMember_Cursor CURSOR FOR
			
					SELECT 
						[Cursor_DimensionID] = DST.[DimensionID],
						[DimensionName] = D.[DimensionName],
						[Cursor_StorageTypeBM] = DST.[StorageTypeBM],
						[DefaultSetMemberKey] = DST.[DefaultSetMemberKey],
						[DefaultGetMemberKey] = DST.[DefaultGetMemberKey]
					FROM
						pcINTEGRATOR_Data..Dimension_StorageType DST
						INNER JOIN Dimension D ON D.DimensionID = DST.DimensionID AND D.[SelectYN] <> 0 AND D.[DeletedID] IS NULL
					WHERE
						DST.InstanceID = @InstanceID AND
						DST.VersionID = @VersionID AND
						(DST.DimensionID = @DimensionID OR @DimensionID IS NULL)

					OPEN DefaultMember_Cursor
					FETCH NEXT FROM DefaultMember_Cursor INTO @Cursor_DimensionID, @DimensionName, @Cursor_StorageTypeBM, @DefaultSetMemberKey, @DefaultGetMemberKey

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Cursor_DimensionID] = @Cursor_DimensionID, [@DimensionName] = @DimensionName, [@Cursor_StorageTypeBM] = @Cursor_StorageTypeBM, [@DefaultSetMemberKey] = @DefaultSetMemberKey, [@DefaultGetMemberKey] = @DefaultGetMemberKey

							IF @Cursor_StorageTypeBM & 2 > 0
								SET @SQLStatement = '
									INSERT INTO #DefaultMembers
										(
										[DimensionID],
										[MemberKey],
										[Description]
										)
									SELECT DISTINCT
										[DimensionID] = ' + CONVERT(nvarchar(15), @Cursor_DimensionID) + ',
										[MemberKey],
										[Description]
									FROM
										[' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + ']
									WHERE
										[MemberKey] IN (''' + @DefaultSetMemberKey + ''', ''' + @DefaultGetMemberKey + ''')'

							ELSE IF @Cursor_StorageTypeBM & 4 > 0
								SET @SQLStatement = '
									INSERT INTO #DefaultMembers
										(
										[DimensionID],
										[MemberKey],
										[Description]
										)
									SELECT DISTINCT
										[DimensionID] = ' + CONVERT(nvarchar(15), @Cursor_DimensionID) + ',
										[MemberKey] = [Label],
										[Description]
									FROM
										[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
									WHERE
										[Label] IN (''' + @DefaultSetMemberKey + ''', ''' + @DefaultGetMemberKey + ''')'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							
							FETCH NEXT FROM DefaultMember_Cursor INTO @Cursor_DimensionID, @DimensionName, @Cursor_StorageTypeBM, @DefaultSetMemberKey, @DefaultGetMemberKey
						END
				CLOSE DefaultMember_Cursor
				DEALLOCATE DefaultMember_Cursor

				IF @DebugBM & 2 > 0 SELECT TempTable = '#DefaultMembers', * FROM #DefaultMembers ORDER BY DimensionID
			END

	SET @Step = 'Get Default hierarchy'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				CREATE TABLE #DefaultHierarchy
					(
					[DimensionID] int,
					[HierarchyNo] int,
					[HierarchyName] nvarchar (100)
					)

				INSERT INTO #DefaultHierarchy
					(
					[DimensionID],
					[HierarchyNo],
					[HierarchyName]
					)
				SELECT
					DST.[DimensionID],
					DH.[HierarchyNo],
					DH.[HierarchyName]
				FROM
					pcINTEGRATOR_Data..Dimension_StorageType DST
					INNER JOIN pcINTEGRATOR_Data..DimensionHierarchy DH ON DH.[InstanceID] = DST.[InstanceID] AND DH.[VersionID] = DST.[VersionID] AND DH.[DimensionID] = DST.[DimensionID] AND DH.[HierarchyNo] = DST.[DefaultGetHierarchyNo]
				WHERE
					DST.[InstanceID] = @InstanceID AND
					DST.[VersionID] = @VersionID AND
					(DST.[DimensionID] = @DimensionID OR @DimensionID IS NULL)

				INSERT INTO #DefaultHierarchy
					(
					[DimensionID],
					[HierarchyNo],
					[HierarchyName]
					)
				SELECT
					DST.[DimensionID],
					DH.[HierarchyNo],
					DH.[HierarchyName]
				FROM
					pcINTEGRATOR_Data..[Dimension_StorageType] DST
					INNER JOIN pcINTEGRATOR..[@Template_DimensionHierarchy] DH ON DH.[InstanceID] = 0 AND DH.[VersionID] = 0 AND DH.[DimensionID] = DST.[DimensionID] AND DH.[HierarchyNo] = DST.[DefaultGetHierarchyNo]
				WHERE
					DST.[InstanceID] = @InstanceID AND
					DST.[VersionID] = @VersionID AND
					(DST.[DimensionID] = @DimensionID OR @DimensionID IS NULL) AND
					NOT EXISTS (SELECT 1 FROM #DefaultHierarchy DDH WHERE DDH.[DimensionID] = DST.[DimensionID] AND DDH.[HierarchyNo] = DH.[HierarchyNo])

				IF @DebugBM & 2 > 0 SELECT TempTable = '#DefaultHierarchy', * FROM #DefaultHierarchy ORDER BY DimensionID
			END

	SET @Step = 'Get Dimension Info'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				CREATE TABLE #DimensionInfo 
					(
					[InstanceID] int,
					[DimensionID] int,
					[DimensionName] nvarchar (50),
					[DimensionDescription] nvarchar (255),
					[DimensionTypeID] int,
					[DimensionTypeName] nvarchar (50),
					[ReportOnlyYN] bit,
					[SourceTypeBM] int,
					[MasterDimensionID] int,
					[InheritedFrom] int,
					[SeedMemberID] int,
					[LoadSP] nvarchar (50),
					[DimensionFilter] nvarchar(4000),
					[StorageTypeBM] int,
					[ObjectGuiBehaviorBM] int,
					[ReadSecurityEnabledYN] bit,
					[MappingTypeID] int,
					[ReplaceStringYN] bit,
					[DefaultSetMemberKey] nvarchar (100),
					[DefaultSetMemberDescription] nvarchar (255),
					[DefaultGetMemberKey] nvarchar(100),
					[DefaultGetMemberDescription] nvarchar (255),
					[DefaultGetHierarchyNo] int,
					[DefaultGetHierarchyName] nvarchar (100),
					[ModelingStatusID] int,
					[ModelingComment] nvarchar (1024),
					[Introduced] nvarchar (100),
					[SelectYN] bit
					)

				SET @SQLStatement = '
					INSERT INTO #DimensionInfo
						(
						[InstanceID],
						[DimensionID],
						[DimensionName],
						[DimensionDescription],
						[DimensionTypeID],
						[DimensionTypeName],
						[ReportOnlyYN],
						[SourceTypeBM],
						[MasterDimensionID],
						[InheritedFrom],
						[SeedMemberID],
						[LoadSP],
						[DimensionFilter],
						[StorageTypeBM],
						[ObjectGuiBehaviorBM],
						[ReadSecurityEnabledYN],
						[MappingTypeID],
						[ReplaceStringYN],
						[DefaultSetMemberKey],
						[DefaultSetMemberDescription],
						[DefaultGetMemberKey],
						[DefaultGetMemberDescription],
						[DefaultGetHierarchyNo],
						[DefaultGetHierarchyName] ,
						[ModelingStatusID],
						[ModelingComment],
						[Introduced],
						[SelectYN]
						)
					SELECT DISTINCT
						[InstanceID] = D.[InstanceID],
						[DimensionID] = D.[DimensionID],
						[DimensionName] = D.[DimensionName],
						[DimensionDescription] = D.[DimensionDescription],
						[DimensionTypeID] = D.[DimensionTypeID],
						[DimensionTypeName] = DT.[DimensionTypeName],
					--	[GenericYN],
					--	[MultipleProcedureYN],
					--	[AllYN],
						[ReportOnlyYN] = D.[ReportOnlyYN],
					--	[HiddenMember],
					--	[Hierarchy],
					--	[TranslationYN],
					--	[DefaultSelectYN],
					--	[DefaultValue],
					--	[DeleteJoinYN],
						[SourceTypeBM] = D.[SourceTypeBM],
						[MasterDimensionID] = D.[MasterDimensionID],
					--	[HierarchyMasterDimensionID],
						[InheritedFrom] = D.[InheritedFrom],
						[SeedMemberID] = D.[SeedMemberID],
						[LoadSP] = D.[LoadSP],
						[DimensionFilter] = DST.[DimensionFilter],
					--	[MasterDataManagementBM],
						[StorageTypeBM] = DST.[StorageTypeBM],
						[ObjectGuiBehaviorBM] = DST.[ObjectGuiBehaviorBM],
						[ReadSecurityEnabledYN] = DST.[ReadSecurityEnabledYN],
						[MappingTypeID] = DST.[MappingTypeID],
						[ReplaceStringYN] = DST.[ReplaceStringYN],
						[DefaultSetMemberKey] = DST.[DefaultSetMemberKey],
						[DefaultSetMemberDescription] = DMS.[Description],
						[DefaultGetMemberKey] = DST.[DefaultGetMemberKey],
						[DefaultGetMemberDescription] = DMG.[Description],
						[DefaultGetHierarchyNo] = DST.[DefaultGetHierarchyNo],
						[DefaultGetHierarchyName] = DHG.[HierarchyName],
						[ModelingStatusID] = D.[ModelingStatusID],
						[ModelingComment] = D.[ModelingComment],
						[Introduced] = D.[Introduced],
						[SelectYN] = D.[SelectYN]
					FROM
						Dimension D
						INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID 
						INNER JOIN Dimension_StorageType DST ON DST.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND DST.VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ' AND DST.DimensionID = D.DimensionID AND ' + CASE WHEN @StorageTypeBM IS NULL THEN '' ELSE 'DST.[StorageTypeBM] & ' + CONVERT(NVARCHAR(15), @StorageTypeBM) + ' > 0 AND' END + ' DST.ObjectGuiBehaviorBM & ' + CONVERT(NVARCHAR(15), @ObjectGuiBehaviorBM) + ' > 0
						' + CASE WHEN @DataClassID IS NULL AND @ProcessID IS NULL THEN '' ELSE 'INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = DST.InstanceID AND DCD.VersionID = DST.VersionID AND DCD.DimensionID = D.DimensionID' + CASE WHEN @DataClassID IS NULL THEN '' ELSE ' AND DCD.DataClassID = ' + CONVERT(NVARCHAR(15), @DataClassID) END END + '
						' + CASE WHEN @DataClassID IS NULL AND @ProcessID IS NULL THEN '' ELSE 'INNER JOIN DataClass_Process DCP ON DCP.InstanceID = DCD.InstanceID AND DCP.VersionID = DCD.VersionID AND DCP.DataClassID = DCD.DataClassID' + CASE WHEN @ProcessID IS NULL THEN '' ELSE ' AND DCP.ProcessID = ' + CONVERT(NVARCHAR(15), @ProcessID) END END + '
--						INNER JOIN OrganizationHierarchy_Process OHP ON OHP.InstanceID = DCP.InstanceID AND OHP.VersionID = DCP.VersionID AND OHP.ProcessID = DCP.ProcessID' + CASE WHEN @OrganizationHierarchyID IS NULL THEN '' ELSE ' AND OHP.OrganizationHierarchyID = ' + CONVERT(NVARCHAR(15), @OrganizationHierarchyID) END + '
						LEFT JOIN #DefaultMembers DMS ON DMS.DimensionID = DST.DimensionID AND DMS.MemberKey = DST.[DefaultSetMemberKey]
						LEFT JOIN #DefaultMembers DMG ON DMG.DimensionID = DST.DimensionID AND DMG.MemberKey = DST.[DefaultGetMemberKey]
						LEFT JOIN #DefaultHierarchy DHG ON DHG.DimensionID = DST.DimensionID AND DHG.HierarchyNo = DST.[DefaultGetHierarchyNo]
					WHERE ' + 
						CASE WHEN @DimensionID IS NULL THEN '' ELSE 'D.[DimensionID] = ' + CONVERT(NVARCHAR(15), @DimensionID) + ' AND ' END + '
						D.[DeletedID] IS NULL
					ORDER BY
						D.[DimensionName]'

						--INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID' + 
						--CASE WHEN @DataClassID IS NULL THEN '' ELSE ' INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND DCD.VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ' AND DCD.DimensionID = D.DimensionID AND DCD.DataClassID = ' + CONVERT(NVARCHAR(15), @DataClassID) END +
						--CASE WHEN @ProcessID IS NULL THEN '' ELSE ' INNER JOIN DataClass_Process DCP ON DCP.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND DCP.VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ' AND DCP.DataClassID = DCD.DataClassID AND DCP.ProcessID = ' + CONVERT(NVARCHAR(15), @ProcessID) END +
						--CASE WHEN @OrganizationHierarchyID IS NULL THEN '' ELSE ' INNER JOIN OrganizationHierarchy_Process OHP ON OHP.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND OHP.OrganizationHierarchyID = ' + CONVERT(NVARCHAR(15), @OrganizationHierarchyID) + ' AND OHP.ProcessID = DCP.ProcessID' END + '

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SELECT [ResultTypeBM] = 1, * FROM #DimensionInfo
				SET @Selected = @Selected + @@ROWCOUNT

			END

	SET @Step = 'Get list of Properties for specified Dimension'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 2,
					DP.[InstanceID],
					DP.[VersionID],
					DP.[DimensionID],
					DP.[PropertyID],
--					DP.[DependencyPrio],
					P.[PropertyName],
					P.[PropertyDescription],
					P.[ObjectGuiBehaviorBM],
					P.[DataTypeID],
					P.[Size],
					P.[DependentDimensionID],
--					P.[StringTypeBM],
--					P.[DynamicYN],
					[DefaultSetValue] = P.[DefaultValueTable],
--					P.[DefaultValueView],
					P.[SynchronizedYN],
--					P.[SourceTypeBM],
--					P.[StorageTypeBM],
--					P.[ViewPropertyYN],
--					P.[HierarchySortOrderYN],
--					P.[MandatoryYN],
--					P.[DefaultSelectYN],
					DP.[MultiDimYN],
					DP.[TabularYN],
					DP.[NodeTypeBM],
					[SortOrder] = ISNULL(DP.[SortOrder], P.[SortOrder]),
					[SelectYN] = CONVERT(bit, CONVERT(int, DP.[SelectYN]) * CONVERT(int, P.[SelectYN]))
				FROM
					[pcINTEGRATOR].[dbo].[Dimension_Property] DP
					INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.[InstanceID] IN (0, @InstanceID) AND P.[PropertyID] = DP.[PropertyID]
				WHERE
					DP.[InstanceID] IN (0, @InstanceID) AND
					DP.[VersionID] IN (0, @VersionID) AND
					DP.[DimensionID] = @DimensionID
				ORDER BY
					CONVERT(int, DP.[MultiDimYN]) DESC,
					ISNULL(DP.[SortOrder], P.[SortOrder]),
					P.[PropertyName]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of Hierarchies for specified Dimension'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
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
				FROM
					(
					SELECT
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
					FROM
						[pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] TDH
					WHERE
						TDH.[InstanceID] = 0 AND
						TDH.[VersionID] = 0 AND
						TDH.[DimensionID] = @DimensionID AND 
						(TDH.[HierarchyNo] = @HierarchyNo OR @HierarchyNo IS NULL) AND
						NOT EXISTS (
							SELECT 1 
							FROM
								[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH
							WHERE
								DH.[InstanceID] = @InstanceID AND
								DH.[VersionID] = @VersionID AND
								DH.[DimensionID] = TDH.[DimensionID] AND
								DH.[HierarchyNo] = TDH.[HierarchyNo]
									)
					UNION SELECT
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
					FROM
						[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH
					WHERE
						DH.[InstanceID] = @InstanceID AND
						DH.[VersionID] = @VersionID AND
						DH.[DimensionID] = @DimensionID AND
						(DH.[HierarchyNo] = @HierarchyNo OR @HierarchyNo IS NULL)
					) sub
				ORDER BY
					sub.[HierarchyNo]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of Hierarchy Levels for specified Dimension'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 8,
					[Comment],
					[InstanceID],
					[VersionID],
					[DimensionID],
					[HierarchyNo],
					[LevelNo],
					[LevelName]
				FROM
					(
					SELECT
						[Comment],
						[InstanceID],
						[VersionID],
						[DimensionID],
						[HierarchyNo],
						[LevelNo],
						[LevelName]
					FROM
						[pcINTEGRATOR].[dbo].[@Template_DimensionHierarchyLevel] TDHL
					WHERE
						TDHL.[InstanceID] = 0 AND
						TDHL.[VersionID] = 0 AND
						TDHL.[DimensionID] = @DimensionID AND 
						(TDHL.[HierarchyNo] = @HierarchyNo OR @HierarchyNo IS NULL) AND
						(TDHL.[LevelNo] = @LevelNo OR @LevelNo IS NULL) AND
						NOT EXISTS (
							SELECT 1 
							FROM
								[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL
							WHERE
								DHL.[InstanceID] = @InstanceID AND
								DHL.[VersionID] = @VersionID AND
								DHL.[DimensionID] = TDHL.[DimensionID] AND
								DHL.[HierarchyNo] = TDHL.[HierarchyNo] AND
								DHL.[LevelNo] = TDHL.[LevelNo]
									)
					UNION SELECT
						[Comment],
						[InstanceID],
						[VersionID],
						[DimensionID],
						[HierarchyNo],
						[LevelNo],
						[LevelName]
					FROM
						[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL
					WHERE
						DHL.[InstanceID] = @InstanceID AND
						DHL.[VersionID] = @VersionID AND
						DHL.[DimensionID] = @DimensionID AND 
						(DHL.[HierarchyNo] = @HierarchyNo OR @HierarchyNo IS NULL) AND
						(DHL.[LevelNo] = @LevelNo OR @LevelNo IS NULL)
					) sub

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of DimensionTypes'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 16,
					*
				FROM
					DimensionType
				WHERE
					InstanceID IN (0, @InstanceID) AND
					DimensionTypeID >= -1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of StorageTypes'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 32,
					*
				FROM
					StorageType
				WHERE
					StorageTypeBM & 6 > 0

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of ObjectGUIBehavior'
		IF @ResultTypeBM & 64 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 64,
					*
				FROM
					ObjectGUIBehavior

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of MappingTypes'
		IF @ResultTypeBM & 128 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 128,
					*
				FROM
					MappingType
				WHERE
					SelectYN <> 0

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of ModelingStatus'
		IF @ResultTypeBM & 256 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 256,
					*
				FROM
					ModelingStatus
				WHERE
					InstanceID IN (0, @InstanceID)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of DataType'
		IF @ResultTypeBM & 512 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 512,
					*
				FROM
					DataType
				WHERE
					InstanceID IN (0, @InstanceID)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of available dimensions'
		IF @ResultTypeBM & 1024 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 1024,
					D.*
				FROM
					[Dimension] D
				WHERE
					InstanceID IN (0, @InstanceID) AND
					DimensionID < 0 AND
					SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data.dbo.Dimension_StorageType DST WHERE DST.DimensionID = D.DimensionID )
				ORDER BY
					DimensionName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of available properties'
		IF @ResultTypeBM & 2048 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 2048,
					*
				FROM
					Property
				WHERE
					InstanceID IN (0, @InstanceID)
				ORDER BY
					PropertyName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get lists of available Dimensions and DataClasses for MultiDim'
		IF @ResultTypeBM & 4096 > 0
			BEGIN
				SELECT @DimensionTypeID = [DimensionTypeID] FROM [Dimension] D WHERE InstanceID IN (0, @InstanceID) AND D.DimensionID = @DimensionID AND D.SelectYN <> 0 AND D.DeletedID IS NULL
				IF @DimensionTypeID = 27
					BEGIN
						CREATE TABLE #AvailableDim
							(
							DimensionID int,
							DimensionName nvarchar(50) COLLATE DATABASE_DEFAULT
							)

						CREATE TABLE #AvailableDC
							(
							DataClassID int,
							DataClassName nvarchar(50) COLLATE DATABASE_DEFAULT
							)

						SET @SQLStatement = '
							INSERT INTO #AvailableDim
								(
								DimensionID,
								DimensionName
								)
							SELECT DISTINCT
								D.DimensionID,
								D.DimensionName
							FROM
								pcINTEGRATOR_Data..DataClass_Dimension DCD
								INNER JOIN pcINTEGRATOR..Dimension D ON D.InstanceID IN (0, DCD.InstanceID) AND D.[DimensionID] = DCD.[DimensionID] AND D.[DimensionTypeID] <> 27 AND D.SelectYN <> 0 AND D.DeletedID IS NULL
							WHERE
								DCD.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
								DCD.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + 
								CASE WHEN @DataClassList IS NOT NULL THEN ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DCD.DataClassID IN (' + @DataClassList + ')' ELSE '' END

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						IF @DebugBM & 2 > 0 SELECT TempTable = '#AvailableDim', * FROM #AvailableDim

						SET @SQLStatement = '
							INSERT INTO #AvailableDC
								(
								DataClassID,
								DataClassName
								)
							SELECT DISTINCT
								DC.DataClassID,
								DC.DataClassName
							FROM
								pcINTEGRATOR_Data..DataClass_Dimension DCD
								INNER JOIN pcINTEGRATOR_Data..DataClass DC ON DC.[InstanceID] = DCD.InstanceID AND DC.[VersionID] = DCD.VersionID AND DC.DataClassID = DCD.DataClassID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL
							WHERE
								DCD.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
								DCD.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + 
								CASE WHEN @DimensionList IS NOT NULL THEN ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DCD.DimensionID IN (' + @DimensionList + ')' ELSE '' END
		
						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						IF @DebugBM & 2 > 0 SELECT TempTable = '#AvailableDC', * FROM #AvailableDC

						SELECT
							D.DimensionID,
							D.DimensionName
						INTO
							#StoredDim
						FROM
							pcINTEGRATOR..Dimension_Property DP
							INNER JOIN pcINTEGRATOR..Property P ON P.InstanceID IN (0, DP.[InstanceID]) AND P.PropertyID = DP.PropertyID AND P.SelectYN <> 0
							INNER JOIN pcINTEGRATOR..Dimension D ON D.InstanceID IN (0, P.[InstanceID]) AND D.DimensionID = P.DependentDimensionID AND D.SelectYN <> 0 AND D.DeletedID IS NULL
						WHERE
							DP.InstanceID IN (0, @InstanceID) AND
							DP.VersionID IN (0, @VersionID) AND 
							DP.DimensionID = @DimensionID AND
							DP.MultiDimYN <> 0 AND
							DP.SelectYN <> 0

						IF @DebugBM & 2 > 0 SELECT TempTable = '#StoredDim', * FROM #StoredDim

						SELECT
							DC.DataClassID,
							DC.DataClassName
						INTO
							#StoredDC
						FROM
							pcINTEGRATOR_Data..DataClass DC
							INNER JOIN pcINTEGRATOR_Data..DataClass_Dimension DCD ON DCD.[InstanceID] = DC.InstanceID AND DCD.[VersionID] = DC.VersionID AND DCD.DataClassID = DC.DataClassID AND DCD.DimensionID = @DimensionID
						WHERE
							DC.[InstanceID] = @InstanceID AND
							DC.[VersionID] = @VersionID AND
							DC.SelectYN <> 0 AND
							DC.DeletedID IS NULL

						IF @DebugBM & 2 > 0 SELECT TempTable = '#StoredDC', * FROM #StoredDC

						SELECT
							[ResultTypeBM] = '4096_1',
							D.DimensionID,
							D.DimensionName,
							StoredYN = CASE WHEN SD.DimensionID IS NULL THEN 0 ELSE 1 END,
							AvailableYN = CASE WHEN AD.DimensionID IS NULL THEN 0 ELSE 1 END
						FROM
							(
							SELECT DISTINCT DimensionID, DimensionName FROM #AvailableDim
							UNION SELECT DISTINCT DimensionID, DimensionName FROM #StoredDim
							) D
							LEFT JOIN #AvailableDim AD ON AD.DimensionID = D.DimensionID
							LEFT JOIN #StoredDim SD ON SD.DimensionID = D.DimensionID
						ORDER BY
							D.DimensionName

						SET @Selected = @Selected + @@ROWCOUNT

						SELECT
							[ResultTypeBM] = '4096_2',
							DC.DataClassID,
							DC.DataClassName,
							StoredYN = CASE WHEN SD.DataClassID IS NULL THEN 0 ELSE 1 END,
							AvailableYN = CASE WHEN AD.DataClassID IS NULL THEN 0 ELSE 1 END
						FROM
							(
							SELECT DISTINCT DataClassID, DataClassName FROM #AvailableDC
							UNION SELECT DISTINCT DataClassID, DataClassName FROM #StoredDC
							) DC
							LEFT JOIN #AvailableDC AD ON AD.DataClassID = DC.DataClassID
							LEFT JOIN #StoredDC SD ON SD.DataClassID = DC.DataClassID
						ORDER BY
							DC.DataClassName

						SET @Selected = @Selected + @@ROWCOUNT

						SELECT
							[ResultTypeBM] = '4096_3',
							D.DimensionID,
							D.DimensionName,
							DP.SortOrder
						FROM
							pcINTEGRATOR..Dimension_Property DP
							INNER JOIN pcINTEGRATOR..Property P ON P.InstanceID IN (0, DP.[InstanceID]) AND P.PropertyID = DP.PropertyID AND P.SelectYN <> 0
							INNER JOIN pcINTEGRATOR..Dimension D ON D.InstanceID IN (0, P.[InstanceID]) AND D.DimensionID = P.DependentDimensionID AND D.SelectYN <> 0 AND D.DeletedID IS NULL
						WHERE
							DP.InstanceID IN (0, @InstanceID) AND
							DP.VersionID IN (0, @VersionID) AND 
							DP.DimensionID = @DimensionID AND
							DP.MultiDimYN <> 0 AND
							DP.SelectYN <> 0
						ORDER BY
							DP.SortOrder

						SET @Selected = @Selected + @@ROWCOUNT

						SELECT
							[ResultTypeBM] = '4096_4',
							[Punctuation] = '-',
							[DescriptionPunctuation] = ' - '

						DROP TABLE #AvailableDim
						DROP TABLE #AvailableDC
						DROP TABLE #StoredDim
						DROP TABLE #StoredDC
					END
			END

	SET @Step = 'Get lists of available HierarchyTypes'
		IF @ResultTypeBM & 8192 > 0
			BEGIN
				SELECT
					[HierarchyTypeID],
					[HierarchyTypeName],
					[HierarchyTypeDescription],
					[ReadOnlyYN],
					[MandatoryProperty]
				FROM
					[pcINTEGRATOR].[dbo].[HierarchyType]
				WHERE
					[SelectYN] <> 0
			END

	SET @Step = 'Get lists of available NodeTypes'
		IF @ResultTypeBM & 16384 > 0
			BEGIN
				SELECT
					[NodeTypeBM],
					[NodeTypeDescription]
				FROM
					[pcINTEGRATOR].[dbo].[NodeType]
				WHERE
					[NodeTypeGroupID] = 1
			END

	SET @Step = 'Drop temp tables'
		IF @ResultTypeBM & 1 > 0 DROP TABLE #DefaultMembers
		IF @ResultTypeBM & 1 > 0 DROP TABLE #DefaultHierarchy
		IF @ResultTypeBM & 1 > 0 DROP TABLE #DimensionInfo

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
