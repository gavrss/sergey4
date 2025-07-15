SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Product_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -19,
	@HierarchyNo int = NULL,
	@SourceTypeID int = NULL,
	@SourceID int = NULL,
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN bit = 1,
	@MappingTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000719,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM = 3 (include high and low prio, exclude sub routines)
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_Product_Callisto] @UserID = -10, @InstanceID = 531, @VersionID = 1057, @DebugBM = 3
EXEC [spIU_Dim_Product_Callisto] @UserID = -10, @InstanceID = 574, @VersionID = 1045, @DebugBM=7 --GMN
EXEC [spIU_Dim_Product_Callisto] @UserID = -10, @InstanceID = 531, @VersionID = 1041, @DebugBM=7 --PCX

EXEC [spIU_Dim_Product_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@DimensionName nvarchar(100),
	@SQLStatement nvarchar(max),
	@JSON nvarchar(max),
	@StorageTypeBM int = 4,
	@LogPropertyYN bit,
	@NodeTypeBMYN bit,

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
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto Product tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed default Priority to 99999999. Excluded properties AgeGroup, StyleCode and TopNode.'
		IF @Version = '2.1.1.2173' SET @Description = 'Changed references to [Model] from BaseModelID = -7 (Financials) to BaseModelID = -4 (Sales).'
		IF @Version = '2.1.2.2179' SET @Description = 'Use sub routine [spSet_Hierarchy].'
		
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

		SELECT
			@DimensionName = DimensionName
		FROM
			pcINTEGRATOR.dbo.[Dimension]
		WHERE
			InstanceID IN (0, @InstanceID) AND
			DimensionID = @DimensionID

		SELECT
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		EXEC [dbo].[spGet_DimPropertyStatus]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DimensionID = @DimensionID,
			@StorageTypeBM = @StorageTypeBM,
			@LogPropertyYN = @LogPropertyYN OUT,
			@NodeTypeBMYN = @NodeTypeBMYN OUT,
			@JobID = @JobID,
			@Debug = @DebugSub

		IF @DebugBM & 2 > 0
			SELECT
				[@SourceTypeID]=@SourceTypeID,
				[@SourceDatabase]=@SourceDatabase,
				[@DimensionID]=@DimensionID,
				[@DimensionName]=@DimensionName,
				[@SequenceBMStep]=@SequenceBMStep,
				[@StaticMemberYN]=@StaticMemberYN,
				[@MappingTypeID]=@MappingTypeID,
				[@LogPropertyYN] = @LogPropertyYN,
				[@NodeTypeBMYN] = @NodeTypeBMYN

	SET @Step = 'Create temp tables'
		CREATE TABLE #Product_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[MemberKeyBase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[Entity_MemberID] bigint,
			[ProductCategory] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[ProductCategory_MemberId] bigint,
			[ProductGroup] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[ProductGroup_MemberId] bigint,
			[NodeTypeBM] int,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)
				
	SET @Step = 'Create #EB (Entity/Book)'
		SELECT DISTINCT
			[EntityID] = E.[EntityID],
			[Entity] = E.[MemberKey],
			[EntityName] = E.[EntityName],
			[Priority] = CONVERT(int, ISNULL(E.[Priority], 99999999))
		INTO
			#EB
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.VersionID AND B.EntityID = E.EntityID AND B.BookTypeBM & 8 > 0 AND B.SelectYN <> 0
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#EB', * FROM #EB

/*
	SET @Step = 'Set Instance specific hierarchy levels'
		IF @MappingTypeID IN (1, 2)
			BEGIN
				--Set Instance specific Hierarchy
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
					(
					[Comment],
					[InstanceID],
					[VersionID],
					[DimensionID],
					[HierarchyNo],
					[HierarchyName],
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
					[FixedLevelsYN] = 1,
					[LockedYN] = 0
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchy] DDH WHERE DDH.[InstanceID] IN (0, @InstanceID) AND DDH.[VersionID] IN (0, @VersionID) AND DDH.[DimensionID] = @DimensionID AND DDH.[HierarchyNo] = 0)

				--Set Instance specific Hierarchy levels
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
					[Comment] = sub.[Comment],
					[InstanceID] = sub.[InstanceID],
					[VersionID] = sub.[VersionID],
					[DimensionID] = sub.[DimensionID],
					[HierarchyNo] = sub.[HierarchyNo],
					[LevelNo] = sub.[LevelNo],
					[LevelName] = sub.[LevelName]
				FROM
					(
					SELECT [Comment] = @DimensionName, [InstanceID] = @InstanceID, [VersionID] = @VersionID, [DimensionID] = @DimensionID, [HierarchyNo] = 0, [LevelNo] = 1, [LevelName] = 'TopNode'
					UNION SELECT [Comment] = @DimensionName, [InstanceID] = @InstanceID, [VersionID] = @VersionID, [DimensionID] = @DimensionID, [HierarchyNo] = 0, [LevelNo] = 2, [LevelName] = 'ProductGroup'
					UNION SELECT [Comment] = @DimensionName, [InstanceID] = @InstanceID, [VersionID] = @VersionID, [DimensionID] = @DimensionID, [HierarchyNo] = 0, [LevelNo] = 3, [LevelName] = @DimensionName
					) sub
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DDHL WHERE DDHL.[InstanceID] IN (0, sub.[InstanceID]) AND DDHL.[VersionID] IN (0, sub.[VersionID]) AND DDHL.[DimensionID] = sub.[DimensionID] AND DDHL.[HierarchyNo] = sub.[HierarchyNo] AND DDHL.[LevelNo] = sub.[LevelNo])
			END
*/

	SET @Step = 'Fetch members'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
			' + CASE WHEN @SourceTypeID IS NOT NULL THEN '{"TKey" : "SourceTypeID",  "TValue": "' + CONVERT(nvarchar(15), @SourceTypeID) + '"},' ELSE '' END + ' 
			' + CASE WHEN @SourceID IS NOT NULL THEN '{"TKey" : "SourceID",  "TValue": "' + CONVERT(nvarchar(15), @SourceID) + '"},' ELSE '' END + '
			' + CASE WHEN @SourceDatabase IS NOT NULL THEN '{"TKey" : "SourceDatabase",  "TValue": "' + @SourceDatabase + '"},' ELSE '' END + '
			{"TKey" : "SequenceBMStep",  "TValue": "' + CONVERT(nvarchar(15), @SequenceBMStep) + '"},
			{"TKey" : "StaticMemberYN",  "TValue": "' + CONVERT(nvarchar(15), CONVERT(int, @StaticMemberYN)) + '"},
			{"TKey" : "MappingTypeID",  "TValue": "' + CONVERT(nvarchar(15), @MappingTypeID) + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), CONVERT(int, @DebugSub)) + '"}
			]'

		IF @DebugBM & 2 > 0 PRINT @JSON
		EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_Dim_Product_Raw', @JSON = @JSON

	SET @Step = 'Update #Product_Members'
		UPDATE #Product_Members 
		SET
			[Label] = [MemberKey], 
			[RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END

        SET @SQLStatement = '
			UPDATE
				[Members]
			SET
				[ProductCategory_MemberId] = ISNULL([ProductCategory].[MemberId], -1)
			FROM
				[#' + @DimensionName + '_Members] Members
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_ProductCategory] [ProductCategory] ON [ProductCategory].[Label] COLLATE DATABASE_DEFAULT = Members.[ProductCategory]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

        SET @SQLStatement = '
			UPDATE
				[Members]
			SET
				[ProductGroup_MemberId] = ISNULL([ProductGroup].[MemberId], -1)
			FROM
				[#' + @DimensionName + '_Members] Members
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_ProductGroup] [ProductGroup] ON [ProductGroup].[Label] COLLATE DATABASE_DEFAULT = Members.[ProductGroup]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @MappingTypeID <> 0
			BEGIN
            	SET @SQLStatement = '
					UPDATE
						[Members]
					SET
						[Entity_MemberId] = E.[MemberId]
					FROM
						[#' + @DimensionName + '_Members] Members
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Entity] [E] ON E.Label = [Members].[Entity]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Product_Members', * FROM #Product_Members ORDER BY MemberKey

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[Product]
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText], 
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity] = Members.[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberId] = Members.[Entity_MemberId],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase] = Members.[MemberKeyBase],' ELSE '' END + '
				[ProductCategory] = Members.[ProductCategory], 
				[ProductCategory_MemberId] = Members.[ProductCategory_MemberId],
				[ProductGroup] = Members.[ProductGroup], 
				[ProductGroup_MemberId] = Members.[ProductGroup_MemberId], 
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM] = Members.[NodeTypeBM],' ELSE '' END + '
				[Source] = Members.[Source]  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [Product] 
				INNER JOIN [#Product_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Product].[Label] 				
			WHERE 
				[Product].[Synchronized] <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert new members from source system'
		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
				(
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberId],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase],' ELSE '' END + '
				[ProductCategory],
				[ProductCategory_MemberId],
				[ProductGroup],
				[ProductGroup_MemberId],
				[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated],' ELSE '' END + '
				[SBZ],
				[Source],
				[Synchronized]				)
			SELECT
				[MemberId] = Members.[MemberId],
				[Label] = Members.[Label],
				[Description] = Members.[Description],
				[HelpText] = Members.[HelpText],
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity] = Members.[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberId] = Members.[Entity_MemberId],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase] = Members.[MemberKeyBase],' ELSE '' END + '
				[ProductCategory] = Members.[ProductCategory],
				[ProductCategory_MemberId] = Members.[ProductCategory_MemberId],
				[ProductGroup] = Members.[ProductGroup],
				[ProductGroup_MemberId] = Members.[ProductGroup_MemberId],
				[RNodeType] = Members.[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM] = Members.[NodeTypeBM],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				[SBZ] = Members.[SBZ],
				[Source] = Members.[Source],
				[Synchronized] = Members.[Synchronized]
			FROM   
				[#Product_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [Product] WHERE Members.[Label] = [Product].Label)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update MemberId'
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Update selected hierarchy (or all hierarchies if @HierarchyNo IS NULL).'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
			' + CASE WHEN @HierarchyNo IS NOT NULL THEN '{"TKey" : "HierarchyNo",  "TValue": "' + CONVERT(nvarchar(10), @HierarchyNo) + '"},' ELSE '' END + '
			{"TKey" : "StorageTypeBM",  "TValue": "' + CONVERT(nvarchar(15), @StorageTypeBM) + '"},
			{"TKey" : "StorageDatabase",  "TValue": "' + @CallistoDatabase + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
			]'

		IF @DebugBM & 2 > 0 PRINT @JSON
					
		EXEC spRun_Procedure_KeyValuePair
			@DatabaseName = 'pcINTEGRATOR',
			@ProcedureName = 'spSet_Hierarchy',
			@JSON = @JSON

	SET @Step = 'Clear Filter Cache'
		IF @Inserted + @Deleted > 0
			BEGIN
				SET @JSON = '
					[
					{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
					{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
					{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
					{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(10), @DimensionID) + '"},
					{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
					{"TKey" : "SetJobLogYN",  "TValue": "0"},
					{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
					]'

				IF @DebugBM & 2 > 0 PRINT @JSON
				EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSet_LeafLevelFilter_ClearCache', @JSON = @JSON
			END

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#Product_Members]
		DROP TABLE [#EB]

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
