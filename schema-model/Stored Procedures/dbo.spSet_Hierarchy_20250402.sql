SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_Hierarchy_20250402]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTable nvarchar(100) = NULL, --Optional, default = '#' + @DimensionName + '_Members'
	@StorageTypeBM int = 4, 
	@StorageDatabase nvarchar(100) = NULL,
	@DimensionID int = NULL,
	@DimensionName nvarchar(50) = NULL,
	@HierarchyNo int = NULL, --Optional, if not set all hierarchies of type 3 and 4 will be updated
	@HierarchyName nvarchar(50) = NULL, --Optional, default = @DimensionName
	@ParentColumn nvarchar(50) = 'Parent',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000789,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spSet_Hierarchy] @DebugBM='15',@DimensionID='6090',@InstanceID='732',@SourceTable='[pcDATA_RSCR].[dbo].[S_DS_Program]',
@StorageDatabase='pcDATA_RSCR',@StorageTypeBM='4',@UserID='31020',@VersionID='1165'

EXEC [pcINTEGRATOR].[dbo].[spSet_Hierarchy] @DebugBM='3',@DimensionID='-1',
@InstanceID='549',@StorageDatabase='pcDATA_COX',@StorageTypeBM='4',@UserID='9552',@VersionID='1062'

EXEC [pcINTEGRATOR].[dbo].[spSet_Hierarchy] @DebugBM='15',@DimensionID='5828',@HierarchyNo='0',@InstanceID='621'
,@SourceTable='[pcDATA_PGL].[dbo].[S_DS_FullAccount]',@StorageDatabase='pcDATA_PGL',@StorageTypeBM='4'
,@UserID='-10',@VersionID='1105'

EXEC [spSet_Hierarchy] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spSet_Hierarchy] @UserID = -10, @InstanceID = 561, @VersionID = 1044, @DimensionID = 9181, @DebugBM=3 --DNKLY
EXEC [spSet_Hierarchy] @UserID = -10, @InstanceID = 531, @VersionID = 1041, @DimensionID = 9155, @DebugBM=3 --PCX
EXEC [spSet_Hierarchy] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @DimensionID = -19,@HierarchyNo = 1, @DebugBM=3 --CBN
EXEC [spSet_Hierarchy] @UserID='-10', @DimensionID='9188',@InstanceID='574',@StorageDatabase='pcDATA_GMN',@StorageTypeBM='4',@VersionID='1045', @DebugBM='3'

EXEC [spSet_Hierarchy] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@Dimensionhierarchy nvarchar(100),
	@Hierarchy_Inserted int = 0,
	@Hierarchy_Deleted int = 0,
	@ParentsWithoutChildrenCount int = 1,
	@Property nvarchar(100),
	@MemberKey nvarchar(4000),
	@Parent nvarchar(4000),
	@HierarchyTypeID int,
	@BaseDimension nvarchar(50),
	@BaseHierarchy nvarchar(50),
	@BaseDimensionFilter nvarchar(4000),
	@BaseDimensionFilter_Str nvarchar(4000),
	@PropertyHierarchy nvarchar(1000),
	@BusinessRuleID int,
	@DimensionTypeID int,
	@Property_DimensionName nvarchar(100),
	@EnhancedStorageYN bit,

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Fill dimension hierarchies with data. Called from dimension ETL SPs.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2173' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2174' SET @Description = 'Set initial value for variable @ParentsWithoutChildrenCount to 1.'
		IF @Version = '2.1.2.2178' SET @Description = 'Handle all types of HierarchyTypeID.'
		IF @Version = '2.1.2.2179' SET @Description = 'Always add All_ and NONE into any hierarchy.'
		IF @Version = '2.1.2.2180' SET @Description = 'Removed extra brackets in insert statement.'
		IF @Version = '2.1.2.2182' SET @Description = 'Exclude NULL in Description for HierarchyTypeID = 4.'
		IF @Version = '2.1.2.2190' SET @Description = 'DB-1323: Reset @ParentsWithoutChildrenCount to 1 in every #Hierarchy_Cursor loop.'
		IF @Version = '2.1.2.2191' SET @Description = 'Handle Enhanced Storage.'
		IF @Version = '2.1.2.2198' SET @Description = 'DB-1451: Handle multiple selection of MultiDim Hierarchy [Dimension Filter] for @HierarchyTypeID = 3. DB-1486: Increased data type size for variables @MemberKey and @Parent. DB-1581: Updated dimension [NodeTypeBM] property for HierarchyTypeID = 2 (Category).'
		IF @Version = '2.1.2.2199' SET @Description = 'FEA-11149: Modified INSERT query, making JOIN clause dynamic for @HierarchyTypeID = 3.'

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
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = ETLDatabase,
			@EnhancedStorageYN = EnhancedStorageYN
		FROM
			pcINTEGRATOR_Data.dbo.[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @StorageTypeBM & 2 > 0
			SET @StorageDatabase = ISNULL(@StorageDatabase, @ETLDatabase)
		ELSE IF @StorageTypeBM & 4 > 0
			SET @StorageDatabase = ISNULL(@StorageDatabase, @CallistoDatabase)

		SELECT
			@DimensionName = ISNULL(@DimensionName, D.[DimensionName]),
			@DimensionID = ISNULL(@DimensionID, D.[DimensionID]),
			@DimensionTypeID = D.[DimensionTypeID]
		FROM
			pcINTEGRATOR.dbo.[Dimension] D
		WHERE
			D.[InstanceID] IN (0, @InstanceID) AND
			D.[SelectYN] <> 0 AND
			D.[DeletedID] IS NULL AND
			(D.[DimensionID] = @DimensionID OR D.[DimensionName] = @DimensionName)

		SELECT
			@HierarchyName = ISNULL(@HierarchyName, DH.[HierarchyName]),
			@HierarchyNo = ISNULL(@HierarchyNo, DH.[HierarchyNo])
		FROM
			pcINTEGRATOR_Data.dbo.[DimensionHierarchy] DH
		WHERE
			DH.[InstanceID] IN (@InstanceID) AND
			DH.[VersionID] IN (@VersionID) AND
			DH.[DimensionID] = @DimensionID AND
			(DH.[HierarchyNo] = @HierarchyNo OR DH.[HierarchyName] = @HierarchyName)

		SELECT
			@HierarchyName = ISNULL(@HierarchyName, DH.[HierarchyName]),
			@HierarchyNo = ISNULL(@HierarchyNo, DH.[HierarchyNo])
		FROM
			pcINTEGRATOR.dbo.[@Template_DimensionHierarchy] DH
		WHERE
			DH.[InstanceID] IN (0) AND
			DH.[VersionID] IN (0) AND
			DH.[DimensionID] = @DimensionID AND
			(DH.[HierarchyNo] = @HierarchyNo OR DH.[HierarchyName] = @HierarchyName)

		SELECT @SourceTable = ISNULL(@SourceTable, '#' + @DimensionName + '_Members')
		SET @SourceTable = '[' + REPLACE(REPLACE(REPLACE(@SourceTable, '[', ''), ']', ''), '.', '].[') + ']'

		IF @DebugBM & 2 > 0
			SELECT
				[@SourceTable] = @SourceTable,
				[@StorageTypeBM] = @StorageTypeBM,
				[@StorageDatabase] = @StorageDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase,
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@DimensionTypeID] = @DimensionTypeID,
				[@HierarchyNo] = @HierarchyNo,
				[@HierarchyName] = @HierarchyName,
				[@Dimensionhierarchy] = @Dimensionhierarchy

	SET @Step = 'Create temp table #BaseDimension'
		CREATE TABLE #BaseDimension
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #PropertyHierarchy'
		CREATE TABLE #PropertyHierarchy
			(
			[MemberID] bigint,
			[MemberKey] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[ParentMemberID] bigint
			)

		CREATE TABLE #Property_Cursor_Table
			(
			[SortOrder] int IDENTITY (1,1),
			[Property] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Property_DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #Hierarchy_Cursor'
		CREATE TABLE #Hierarchy_Cursor
			(
			[HierarchyNo] int,
			[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DimensionHierarchy] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[HierarchyTypeID] int,
			[BaseDimension] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BaseHierarchy] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BaseDimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[PropertyHierarchy] nvarchar(1000) COLLATE DATABASE_DEFAULT,
			[BusinessRuleID] int
			)

	SET @Step = 'Create and fill Cursor table, #Hierarchy_Cursor.'
		INSERT INTO #Hierarchy_Cursor
			(
			[HierarchyNo],
			[HierarchyName],
			[DimensionHierarchy],
			[HierarchyTypeID],
			[BaseDimension],
			[BaseHierarchy],
			[BaseDimensionFilter],
			[PropertyHierarchy],
			[BusinessRuleID]
			)
		SELECT DISTINCT
			[HierarchyNo],
			[HierarchyName],
			[DimensionHierarchy] = @DimensionName + '_' + [HierarchyName],
			[HierarchyTypeID],
			[BaseDimension],
			[BaseHierarchy],
			[BaseDimensionFilter],
			[PropertyHierarchy],
			[BusinessRuleID]
		FROM
			pcINTEGRATOR_Data..DimensionHierarchy DH
		WHERE
			DH.[InstanceID] = @InstanceID AND
			DH.[VersionID] = @VersionID AND
			DH.[DimensionID] = @DimensionID AND
			DH.[HierarchyTypeID] IN (1,2,3,4,6) AND
			(DH.[HierarchyNo] = @HierarchyNo OR @HierarchyNo IS NULL)

		INSERT INTO #Hierarchy_Cursor
			(
			[HierarchyNo],
			[HierarchyName],
			[DimensionHierarchy],
			[HierarchyTypeID],
			[BaseDimension],
			[BaseHierarchy],
			[BaseDimensionFilter],
			[PropertyHierarchy],
			[BusinessRuleID]
			)
		SELECT DISTINCT
			[HierarchyNo] = DH.[HierarchyNo],
			[HierarchyName] = DH.[HierarchyName],
			[DimensionHierarchy] = @DimensionName + '_' + DH.[HierarchyName],
			[HierarchyTypeID] = DH.[HierarchyTypeID],
			[BaseDimension] = DH.[BaseDimension],
			[BaseHierarchy] = DH.[BaseHierarchy],
			[BaseDimensionFilter] = DH.[BaseDimensionFilter],
			[PropertyHierarchy] = DH.[PropertyHierarchy],
			[BusinessRuleID] = DH.[BusinessRuleID]
		FROM
			pcINTEGRATOR_Data..Dimension_StorageType DS
			INNER JOIN pcINTEGRATOR..DimensionHierarchy DH ON DH.[InstanceID] IN (0, DS.[InstanceID]) AND DH.[VersionID] IN (0, DS.[VersionID]) AND DH.[DimensionID] = DS.[DimensionID] AND DH.[HierarchyTypeID] IN (1,2,3,4,6) AND	(DH.[HierarchyNo] = @HierarchyNo OR @HierarchyNo IS NULL)
		WHERE
			DS.[InstanceID] IN (0, @InstanceID) AND
			DS.[VersionID] IN (0, @VersionID) AND
			DS.[DimensionID] = @DimensionID AND
			DS.[StorageTypeBM] & @StorageTypeBM > 0 AND
			NOT EXISTS (SELECT 1 FROM #Hierarchy_Cursor HC WHERE HC.[HierarchyNo] = DH.[HierarchyNo])

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Hierarchy_Cursor', * FROM #Hierarchy_Cursor ORDER BY [HierarchyNo]

	SET @Step = 'Update hierarchies for all type of hierarchies.'
		IF CURSOR_STATUS('global','Hierarchy_Cursor') >= -1 DEALLOCATE Hierarchy_Cursor
		DECLARE Hierarchy_Cursor CURSOR FOR
			SELECT 
				[HierarchyNo],
				[HierarchyName],
				[DimensionHierarchy],
				[HierarchyTypeID],
				[BaseDimension],
				[BaseHierarchy],
				[BaseDimensionFilter],
				[PropertyHierarchy],
				[BusinessRuleID]
			FROM
				#Hierarchy_Cursor
			ORDER BY
				[HierarchyNo]
			
			OPEN Hierarchy_Cursor
			FETCH NEXT FROM Hierarchy_Cursor INTO @HierarchyNo, @HierarchyName, @DimensionHierarchy, @HierarchyTypeID, 	@BaseDimension, @BaseHierarchy, @BaseDimensionFilter, @PropertyHierarchy, @BusinessRuleID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0
						SELECT
							[@HierarchyNo] = @HierarchyNo,
							[@HierarchyName] = @HierarchyName,
							[@DimensionHierarchy] = @DimensionHierarchy,
							[@HierarchyTypeID] = @HierarchyTypeID,
							[@BaseDimension] = @BaseDimension,
							[@BaseHierarchy] = @BaseHierarchy,
							[@BaseDimensionFilter] = @BaseDimensionFilter,
							[@PropertyHierarchy] = @PropertyHierarchy,
							[@BusinessRuleID] = @BusinessRuleID
				
					IF @HierarchyTypeID = 6 --Automated by ETL
						BEGIN
							SET @SQLStatement = '
								TRUNCATE TABLE  [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + ']'
							
							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = '
						INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + ']
							(
							[MemberId],
							[ParentMemberId],
							[SequenceNumber]
							)
						SELECT DISTINCT
							[MemberId] = sub.[MemberId],
							[ParentMemberId] = sub.[ParentMemberId],
							[SequenceNumber] = sub.[SequenceNumber]
						FROM
							(
							SELECT
								[MemberId] = 1,
								[ParentMemberId] = 0,
								[SequenceNumber] = 1
							UNION SELECT
								[MemberId] = -1,
								[ParentMemberId] = 1,
								[SequenceNumber] = 1
							) sub
						WHERE
							NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + '] D WHERE D.[MemberId] = sub.[MemberId])'
							
					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement) 

					IF @HierarchyTypeID IN (1, 6) --Standard / Automated by ETL
						BEGIN
							SET @Step = 'Insert new members into the default hierarchy. Not Synchronized members will not be added.'
								IF @StorageTypeBM & 4 > 0 AND @DimensionTypeID <> 27
									BEGIN
										SET @SQLStatement = '
											INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + ']
												(
												[MemberId],
												[ParentMemberId],
												[SequenceNumber]
												)
											SELECT DISTINCT
												[MemberId] = D1.[MemberId],
												[ParentMemberId] = ISNULL(D2.[MemberId], 0),
												[SequenceNumber] = D1.[MemberId] 
											FROM
												[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D1
												INNER JOIN ' + @SourceTable + ' ST ON ST.[Label] COLLATE DATABASE_DEFAULT = D1.[Label]
												LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D2 ON D2.[Label] = CONVERT(nvarchar(255), ST.[' + @ParentColumn + ']) COLLATE DATABASE_DEFAULT
											WHERE
												D1.[Synchronized] <> 0 AND
												D1.[MemberId] <> ISNULL(D2.[MemberId], 0) AND
												D1.[MemberId] IS NOT NULL AND
												(D2.[MemberId] IS NOT NULL OR D1.[Label] = ''All_'' OR ST.[' + @ParentColumn + '] IS NULL) AND
												NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + '] H WHERE H.[MemberId] = D1.[MemberId])
											ORDER BY
												D1.[MemberId]'

										IF @DebugBM & 1 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
		
										SET @Hierarchy_Inserted = @Hierarchy_Inserted + @@ROWCOUNT
										IF @DebugBM & 2 > 0 SELECT [@Hierarchy_Inserted] = @Hierarchy_Inserted
									END

							SET @Step = 'Delete parents without children.'
								IF @StorageTypeBM & 4 > 0
									BEGIN
										--Reset to 1 in every loop of #Hierarchy_Cursor
										SET @ParentsWithoutChildrenCount = 1

										WHILE @ParentsWithoutChildrenCount > 0
											BEGIN
												SET @SQLStatement = '
													DELETE H
													FROM
														[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + '] H
														INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] DL ON DL.[MemberID] = H.[MemberID] AND DL.[RNodeType] = ''P''
													WHERE
														NOT EXISTS (SELECT DISTINCT HD.[ParentMemberID] FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + '] HD WHERE HD.[ParentMemberID] = H.[MemberID])'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)

												SET @Hierarchy_Deleted = @Hierarchy_Deleted + @@ROWCOUNT
												IF @DebugBM & 2 > 0 SELECT [@Hierarchy_Deleted] = @Hierarchy_Deleted

												SET @SQLStatement = '
													SELECT @InternalVariable = COUNT(1)
													FROM
														[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + '] H
														INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] DL ON DL.[MemberID] = H.[MemberID] AND DL.[RNodeType] = ''P''
													WHERE
														NOT EXISTS (SELECT DISTINCT HD.[ParentMemberID] FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + '] HD WHERE HD.[ParentMemberID] = H.[MemberID])'

												EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @internalVariable = @ParentsWithoutChildrenCount OUT

												IF @DebugBM & 2 > 0 SELECT [@ParentsWithoutChildrenCount] = @ParentsWithoutChildrenCount
											END
									END
						END

					ELSE IF @HierarchyTypeID = 2 --Category
						BEGIN
							SET @Step = '@HierarchyTypeID = 2, Category'

							SET @SQLStatement = '
								INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
									(
									[MemberId],
									[Label],
									[Description],
									[HelpText],
									[NodeTypeBM],
									[RNodeType],
									[SBZ],
									[Source],
									[Synchronized],
									[JobID],
									[Inserted],
									[Updated]
									)
								SELECT
									[MemberId] = -2,
									[Label] = ''-'',
									[Description] = ''(blank)'',
									[HelpText] = ''Parent for leaf level members decided to not be included any Category'',
									[NodeTypeBM] = 1026,
									[RNodeType] = ''P'',
									[SBZ] = 1,
									[Source] = ''ETL'',
									[Synchronized] = 1,
									[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
									[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',
									[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + '''
								WHERE
									NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D WHERE D.[MemberId] = -2 OR [Label] = ''-'')'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							EXEC [spSet_MemberId] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @Database=@CallistoDatabase, @Dimension=@DimensionName, @JobID=@JobID, @Debug=@DebugSub
							
							--Add default rows into hierarchy
							SET @SQLStatement = '
								INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + ']
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
									(
									SELECT
										[MemberId] = 1,
										[ParentMemberId] = 0,
										[SequenceNumber] = 1 
									UNION SELECT
										[MemberId] = -1,
										[ParentMemberId] = 1,
										[SequenceNumber] = 1
									) sub
								WHERE
									NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + '] D WHERE D.[MemberId] = sub.[MemberId])'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							
							--Update [NodeTypeBM] property
							SET @SQLStatement = '
							UPDATE DS
							SET
								[NodeTypeBM] = CASE WHEN RNodeType = ''L'' THEN 1 ELSE CASE WHEN RNodeType = ''P'' THEN 18 ELSE RNodeType END END
							FROM 
								[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] DS
							WHERE
								NodeTypeBM IS NULL OR NodeTypeBM = 0'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SELECT 'Category, Not yet implemented' 

/*
							SET @SQLStatement = 'SELECT @InternalVariable = MIN([MemberId]) FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] WHERE ISNULL([ParentMemberId], 0) = 0'

							EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @TopNode_MemberId OUT

							IF @DebugBM & 2 > 0 
								SELECT 
									[@DimensionID] = @DimensionID,
									[@DimensionName] = @DimensionName,
									[@HierarchyNo] = @HierarchyNo, 
									[@HierarchyName] = @HierarchyName,
									[@TopNode_MemberId] = @TopNode_MemberId

						SET @Step = 'Create temp tables'
							CREATE TABLE #ParentMember
								(
								[MemberId] bigint,
								[DimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
								[ParentMemberId] bigint,
								[SortOrder] int,
								[EvalPrio] int
								)

							CREATE TABLE #DimensionFilter_Cursor
								(
								[MemberId] bigint,
								[DimensionFilter] nvarchar(4000),
								[EvalPrio] int,
								[Depth] int,
								[SortOrder] int
								)

							CREATE TABLE #Hierarchy
								(
								[MemberId] bigint,
								[ParentMemberId] bigint,
								[SequenceNumber] bigint IDENTITY(1,1)
								)

						SET @Step = 'Update RNodeType'
							SET @SQLStatement = '
								UPDATE D
								SET
									[RNodeType] = CASE WHEN P.ParentMemberID IS NULL THEN ''L'' ELSE ''P'' END
								FROM 
									[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H ON H.[MemberId] = D.[MemberId]
									LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] P ON P.[ParentMemberId] = D.[MemberId]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

						SET @Step = 'Fill table #DimensionFilter_Cursor'				
							SET @SQLStatement = '
								INSERT INTO #ParentMember
									(
									[MemberId],
									[DimensionFilter],
									[ParentMemberId],
									[SortOrder],
									[EvalPrio]
									)
								SELECT 
									[MemberId] = D.[MemberId],
									[DimensionFilter] = D.[DimensionFilter],
									[ParentMemberId] = H.[ParentMemberId],
									[SortOrder] = H.[SequenceNumber],
									[EvalPrio] = ISNULL(D.[EvalPrio], 0)
								FROM 
									[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H ON H.[MemberId] = D.[MemberId]
								WHERE
									LEN(D.[DimensionFilter]) > 0 OR
			--						H.ParentMemberId = ' + CONVERT(nvarchar(20), @TopNode_MemberId) + ' OR
									D.[RNodeType] = ''P'''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							IF @DebugBM & 2 > 0 SELECT TempTable = '#ParentMember', * FROM #ParentMember

							;WITH cte AS
								(
								SELECT
									D.[MemberID],
									D.[ParentMemberID],
									Depth = 1
								FROM
									#ParentMember D
								WHERE
									D.[MemberID] = @TopNode_MemberId
								UNION ALL
								SELECT
									D.[MemberID],
									D.[ParentMemberID],
									C.Depth + 1
								FROM
									#ParentMember D
									INNER JOIN cte c on c.[MemberID] = D.[ParentMemberID]
								)
							INSERT INTO #DimensionFilter_Cursor
								(
								[MemberId],
								[DimensionFilter],
								[EvalPrio],
								[Depth],
								[SortOrder]
								)
							SELECT
								[MemberId] = cte.[MemberId],
								[DimensionFilter] = D.DimensionFilter,
								[EvalPrio] = D.[EvalPrio],
								[Depth] = cte.[Depth],
								[SortOrder] = D.[SortOrder]
							FROM
								cte
								INNER JOIN #ParentMember D ON D.[MemberId] = cte.[MemberId] AND ISNULL(D.[DimensionFilter], '') <> ''
							ORDER BY
								D.[EvalPrio] DESC,
								cte.[Depth] DESC,
								D.[SortOrder] DESC

							IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionFilter_Cursor', * FROM #DimensionFilter_Cursor ORDER BY [EvalPrio] DESC, [Depth] DESC, [SortOrder] DESC


						SET @Step = 'Remove old leafs'
							SET @SQLStatement = '
								DELETE H
								FROM
									[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[MemberId] = H.[MemberId] AND D.[RNodeType] = ''L'' AND LEN(ISNULL(D.[DimensionFilter], '''')) = 0
								WHERE
									H.[MemberId] >= 10 AND
									NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] P WHERE P.[ParentMemberId] = D.[MemberId])'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

						SET @Step = 'MultiDimHierarchy_Cursor'
							TRUNCATE TABLE #FullAccount_Members_Raw

							IF CURSOR_STATUS('global','MultiDimHierarchy_Cursor') >= -1 DEALLOCATE MultiDimHierarchy_Cursor
							DECLARE MultiDimHierarchy_Cursor CURSOR FOR
			
								SELECT
									[MemberId],
									[DimensionFilter]
								FROM
									#DimensionFilter_Cursor 
								ORDER BY
									[Depth] DESC,
									[SortOrder] DESC

								OPEN MultiDimHierarchy_Cursor
								FETCH NEXT FROM MultiDimHierarchy_Cursor INTO @MemberId, @DimensionFilter

								WHILE @@FETCH_STATUS = 0
									BEGIN
										IF @DebugBM & 2 > 0 SELECT [@MemberId] = @MemberId, [@DimensionFilter] = @DimensionFilter

										TRUNCATE TABLE #Hierarchy

										EXEC [spGet_FilterTable] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @StepReference = 'FullAccount', @PipeString = @DimensionFilter, @DatabaseName = @CallistoDatabase, @StorageTypeBM_DataClass = 4, @StorageTypeBM = 4, @SQLFilter = @SQLFilter OUT, @JobID = @JobID, @DebugBM = @DebugSub

										IF @DebugBM & 2 > 0 SELECT [@SQLFilter] = @SQLFilter

										SET @SQLStatement = '
											INSERT INTO #Hierarchy
												(
												[MemberId],
												[ParentMemberId]
												)
											SELECT
												[MemberId] = D.[MemberId],
												[ParentMemberId] = ' + CONVERT(nvarchar(20), @MemberId) + '
											FROM
												[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
											WHERE' + @SQLFilter + '
												NOT EXISTS (SELECT 1 FROM #Hierarchy HD WHERE HD.[MemberId] = D.[MemberId])
											ORDER BY
												D.[Label]'

										IF @DebugBM & 2 > 0 
											BEGIN
												IF LEN(@SQLStatement) > 4000 
													BEGIN
														SET @Comment = 'FullAccount Hierarchy [ParentMemberId] = ' + CONVERT(nvarchar(20), @MemberId) + '.'
														PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; ' + @Comment
											
														EXEC [dbo].[spSet_wrk_Debug]
															@UserID = @UserID,
															@InstanceID = @InstanceID,
															@VersionID = @VersionID,
															@DatabaseName = @DatabaseName,
															@CalledProcedureName = @ProcedureName,
															@Comment = @Comment,
															@SQLStatement = @SQLStatement,
															@JobID = @JobID
													END
												ELSE
													PRINT @SQLStatement
											END
										EXEC (@SQLStatement)

										SET IDENTITY_INSERT #FullAccount_Members_Raw ON

										INSERT INTO #FullAccount_Members_Raw
											(
											[MemberId],
											[NodeTypeBM],
											[ParentMemberId],
											[SortOrder]
											)
										SELECT
											[MemberId],
											[NodeTypeBM] = 1,
											[ParentMemberId],
											[SortOrder] = [SequenceNumber]
										FROM
											#Hierarchy H
										WHERE
					 						NOT EXISTS (SELECT 1 FROM #FullAccount_Members_Raw HD WHERE HD.[MemberId] = H.[MemberId])

										SET IDENTITY_INSERT #FullAccount_Members_Raw OFF

										FETCH NEXT FROM MultiDimHierarchy_Cursor INTO @MemberId, @DimensionFilter
									END

							CLOSE MultiDimHierarchy_Cursor
							DEALLOCATE MultiDimHierarchy_Cursor

						SET @Step = 'Update RNodeType'
							SET @SQLStatement = '
								UPDATE D
								SET
									[RNodeType] = CASE WHEN P.ParentMemberID IS NULL THEN ''L'' ELSE ''P'' END
								FROM 
									[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H ON H.[MemberId] = D.[MemberId]
									LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] P ON P.[ParentMemberId] = D.[MemberId]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

						SET @Step = 'Drop temp tables'
							DROP TABLE #ParentMember
							DROP TABLE #DimensionFilter_Cursor
*/

						END				
					
					ELSE IF @HierarchyTypeID = 3 --Dimension based
						BEGIN
							SET @Step = 'Create hierarchy of type 3 (Dimension based)'

							SELECT @BaseDimensionFilter_Str = CASE WHEN ISNULL(@BaseDimensionFilter_Str,'') <> '' THEN @BaseDimensionFilter_Str + ',' ELSE '' END + '''' + value + '''' FROM STRING_SPLIT(@BaseDimensionFilter,',')

							IF @DebugBM & 2 > 0
								SELECT
									[@BaseDimension] = @BaseDimension,
									[@BaseHierarchy] = @BaseHierarchy,
									[@BaseDimensionFilter] = @BaseDimensionFilter,
									[@BaseDimensionFilter_Str] = @BaseDimensionFilter_Str

							TRUNCATE TABLE #BaseDimension

							SET @SQLStatement = '
								;WITH cte AS
								(
									SELECT
										MemberID,
										ParentMemberID = CONVERT(bigint, 0)
									FROM
										[' + @CallistoDatabase + '].[dbo].[S_DS_' + @BaseDimension + '] D
									WHERE
										--D.Label = ''' + @BaseDimensionFilter + ''' AND
										D.Label IN (' + @BaseDimensionFilter_Str + ') AND
										D.RNodeType LIKE ''P%''
									UNION ALL
									SELECT
										D.MemberID,
										H.ParentMemberID
									FROM
										[' + @CallistoDatabase + '].[dbo].[S_DS_' + @BaseDimension + '] D
										INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @BaseDimension + '_' + @BaseHierarchy + '] H ON H.MemberId = D.MemberId
										INNER JOIN cte c on c.[MemberID] = H.[ParentMemberID]
									WHERE
										D.RNodeType LIKE ''P%''
								)
								INSERT INTO #BaseDimension
									(
									[MemberId],
									[MemberKey],
									[Description],
									[HelpText]
									)
								SELECT
									[MemberId] = D.[MemberId],
									[MemberKey] = D.[Label],
									[Description] = D.[Description],
									[HelpText] = D.[HelpText]
								FROM
									cte
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @BaseDimension + '] D ON D.MemberId = cte.MemberId'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF @DebugBM & 2 > 0 SELECT TempTable = '#BaseDimension', * FROM #BaseDimension

							--Add parents	
							SET @SQLStatement = '
								INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
									(
									[Label],
									[Description],
									[HelpText],
									[Inserted],
									[JobID],
									[NodeTypeBM],
									[RNodeType],
									[SBZ],
									[Source],
									[Synchronized],
									[Updated]
									)
								SELECT
									[Label] = BD.[MemberKey],
									[Description] = BD.[Description],
									[HelpText] = BD.[HelpText],
									[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',
									[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
									[NodeTypeBM] = 18,
									[RNodeType] = ''P'',
									[SBZ] = 1,
									[Source] = ''System'',
									[Synchronized] = 1,
									[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + '''
								FROM
									#BaseDimension BD
								WHERE
									NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D WHERE D.[Label] = BD.[MemberKey])'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

							--Delete synchronized rows from the hierarchy
							SET @SQLStatement = '
								DELETE H
								FROM
									[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy +'] H
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[MemberId] = H.[MemberId] AND D.[Synchronized] <> 0
									INNER JOIN #BaseDimension BD ON BD.MemberKey = D.[Label]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @SQLStatement = '
								DELETE H
								FROM
									[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy +'] H
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[MemberId] = H.[MemberId] AND [RNodeType] = ''L'' AND D.[Synchronized] <> 0
								WHERE
									H.MemberID <> -1'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							--Insert new rows into the hierarchy
							SET @SQLStatement = '
								INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy +']
									(
									[MemberId],
									[ParentMemberId],
									[SequenceNumber]
									)
								SELECT DISTINCT
									[MemberId] = D.MemberId,
									[ParentMemberId] = ISNULL(DP2.MemberId, 1),
									[SequenceNumber] = H.[SequenceNumber]
								FROM
									[' + @CallistoDatabase + '].[dbo].[S_HS_' + @BaseDimension + '_' + @BaseHierarchy +'] H
									INNER JOIN #BaseDimension BD ON BD.MemberID = H.MemberId
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[Label] = BD.[MemberKey]
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @BaseDimension + '] DP1 ON DP1.[MemberID] = H.[ParentMemberID]
									LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] DP2 ON DP2.[Label] = DP1.[Label]
								WHERE
									NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy +'] DH WHERE DH.[MemberId] = D.[MemberId])'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @SQLStatement = '
								INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy +']
									(
									[MemberId],
									[ParentMemberId],
									[SequenceNumber]
									)
								SELECT DISTINCT
									[MemberId] = D2.MemberId,
									[ParentMemberId] = ISNULL(DP2.[MemberId], -1),
									[SequenceNumber] = H.[SequenceNumber]
								FROM
									[' + @CallistoDatabase + '].[dbo].[S_HS_' + @BaseDimension + '_' + @BaseHierarchy +'] H
									INNER JOIN #BaseDimension BD ON BD.MemberID = H.ParentMemberId
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @BaseDimension + '] D1 ON D1.[MemberID] = H.[MemberID]
									--INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D2 ON D2.[Account] = D1.[Label]
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D2 ON D2.[' + @BaseDimension + '] = D1.[Label]
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @BaseDimension + '] DP1 ON DP1.[MemberID] = H.[ParentMemberID]
									LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] DP2 ON DP2.[Label] = DP1.[Label]
								WHERE
									NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy +'] DH WHERE DH.[MemberId] = D2.[MemberId])'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

					ELSE IF @HierarchyTypeID = 4 --Property based
						BEGIN
							SET @Step = 'Create hierarchy of type 4 (Property based)'

							IF @DebugBM & 2 > 0 SELECT [@PropertyHierarchy] = @PropertyHierarchy

							INSERT INTO #Property_Cursor_Table
								(
								[Property]
								)
							SELECT
								[Property] = [Value]
							FROM
								STRING_SPLIT (@PropertyHierarchy, ',')

							UPDATE PCT
							SET
								[Property_DimensionName] = D.[DimensionName]
							FROM
								#Property_Cursor_Table PCT
								INNER JOIN [Property] P ON P.[InstanceID] IN (0, @InstanceID) AND P.[PropertyName] = PCT.[Property]
								INNER JOIN [Dimension] D ON D.[InstanceID] IN (0, @InstanceID) AND D.[DimensionID] = P.[DependentDimensionID]

							IF @DebugBM & 2 > 0 SELECT TempTable = '#Property_Cursor_Table', * FROM #Property_Cursor_Table ORDER BY [SortOrder]

							SELECT
								@MemberKey = '''PH''',
								@Parent = '''All_'''
							
							IF CURSOR_STATUS('global','Property_Cursor') >= -1 DEALLOCATE Property_Cursor
							DECLARE Property_Cursor CURSOR FOR
			
								SELECT 
									[Property],
									[Property_DimensionName]
								FROM
									#Property_Cursor_Table
								ORDER BY
									[SortOrder]

								OPEN Property_Cursor
								FETCH NEXT FROM Property_Cursor INTO @Property, @Property_DimensionName

								WHILE @@FETCH_STATUS = 0
									BEGIN
										IF @DebugBM & 2 > 0 SELECT [@Property] = @Property

										SET @MemberKey = @MemberKey + ' + ''_'' + ISNULL(CONVERT(nvarchar(100), D.[' + @Property + ']), ''NONE'')'

										IF @DebugBM & 2 > 0 SELECT [@MemberKey] = @MemberKey

										SET @SQLStatement = '
											INSERT INTO #PropertyHierarchy
												(
												[MemberKey],
												[Description],
												[NodeTypeBM],
												[Parent]
												)'

										IF @Property_DimensionName IS NOT NULL
											SET @SQLStatement = @SQLStatement + '
											SELECT DISTINCT
												[MemberKey] = ' + @MemberKey + ',
												[Description] = ISNULL(P.[Description], D.[' + @Property + ']),
												[NodeTypeBM] = 18,
												[Parent] = ' + @Parent + '
											FROM
												[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
												LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @Property_DimensionName + '] P ON P.[Label] = D.[' + @Property + ']'
										ELSE
											SET @SQLStatement = @SQLStatement + '
											SELECT DISTINCT
												[MemberKey] = ' + @MemberKey + ',
												[Description] = ISNULL(CONVERT(nvarchar(100), D.[' + @Property + ']), ''NONE''),
												[NodeTypeBM] = 18,
												[Parent] = ' + @Parent + '
											FROM
												[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)

										SET @Parent = @MemberKey

										FETCH NEXT FROM Property_Cursor INTO @Property, @Property_DimensionName
									END

							CLOSE Property_Cursor
							DEALLOCATE Property_Cursor

							SET  @SQLStatement = '
								INSERT INTO #PropertyHierarchy
									(
									[MemberID],
									[MemberKey],
									[Description],
									[NodeTypeBM],
									[Parent]
									)
								SELECT DISTINCT
									[MemberID] = D.[MemberID],
									[MemberKey] = D.[Label],
									[Description] = D.[Description],
									[NodeTypeBM] = 1,
									[Parent] = ' + @Parent + '
								FROM
									[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
								WHERE
									RNodeType LIKE ''L%'''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF @DebugBM & 2 > 0 SELECT TempTable = '#PropertyHierarchy_1', * FROM #PropertyHierarchy 

							SET  @SQLStatement = '	
								INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
									(
									[Label],
									[Description],
									[HelpText],
									[RNodeType],
									[SBZ],
									[Source],
									[Synchronized]
									)
								SELECT
									[Label] = PH.[MemberKey],
									[Description] = PH.[Description],
									[HelpText] = PH.[Description],
									[RNodeType] = ''P'',
									[SBZ] = 1,
									[Source] = ''ETL'',
									[Synchronized] = 1
								FROM
									#PropertyHierarchy PH
								WHERE
									PH.[NodeTypeBM] & 2 > 0 AND
									PH.[Description] IS NOT NULL AND
									NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D WHERE D.[Label] = PH.[MemberKey])'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@Database = @CallistoDatabase,
								@Dimension = @DimensionName,
								@JobID = @JobID

							SET  @SQLStatement = '	
								UPDATE PH
								SET
									[MemberID] = D.[MemberID]
								FROM
									#PropertyHierarchy PH
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[Label] = PH.[MemberKey]

								UPDATE PH
								SET
									[ParentMemberID] = D.[MemberID]
								FROM
									#PropertyHierarchy PH
									INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[Label] = PH.[Parent]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF @DebugBM & 2 > 0 SELECT TempTable = '#PropertyHierarchy_2', * FROM #PropertyHierarchy 

							SET  @SQLStatement = '	
								TRUNCATE TABLE [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + ']

								INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionHierarchy + ']
									(
									[MemberID],
									[ParentMemberID],
									[SequenceNumber]
									)
								SELECT DISTINCT
									[MemberID] = sub.[MemberID],
									[ParentMemberID] = MIN(sub.[ParentMemberID]),
									[SequenceNumber] = MIN(sub.[SequenceNumber])
								FROM
									(
									SELECT
										[MemberID] = 1,
										[ParentMemberID] = 0,
										[SequenceNumber] = 1
									UNION SELECT
										[MemberID] = -1,
										[ParentMemberID] = 1,
										[SequenceNumber] = 2
									UNION SELECT
										[MemberID] = PH.[MemberID],
										[ParentMemberID] = PH.[ParentMemberID],
										[SequenceNumber] = PH.[MemberID]
									FROM
										#PropertyHierarchy PH
									) sub
								GROUP BY
									sub.[MemberID]
								ORDER BY
									sub.[MemberID]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

						END

						IF @EnhancedStorageYN = 0
							EXEC [pcINTEGRATOR].[dbo].[spSet_HierarchyCopy] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Database = @CallistoDatabase, @Dimensionhierarchy = @Dimensionhierarchy, @JobID = @JobID, @Debug = @DebugSub

					FETCH NEXT FROM Hierarchy_Cursor INTO @HierarchyNo, @HierarchyName, @DimensionHierarchy, @HierarchyTypeID, 	@BaseDimension, @BaseHierarchy, @BaseDimensionFilter, @PropertyHierarchy, @BusinessRuleID
				END

		CLOSE Hierarchy_Cursor
		DEALLOCATE Hierarchy_Cursor		

	SET @Step = 'Count Inserted rows'
		SET @Inserted = @Inserted + @Hierarchy_Inserted - @Hierarchy_Deleted

	SET @Step = 'Drop temp tables' 
		DROP TABLE #Property_Cursor_Table
		DROP TABLE #PropertyHierarchy
		DROP TABLE #Hierarchy_Cursor
		DROP TABLE #BaseDimension

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
