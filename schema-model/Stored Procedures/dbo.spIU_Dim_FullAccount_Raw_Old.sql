SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_FullAccount_Raw_Old]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@DimensionName nvarchar(50) = NULL,
	@HierarchyNo int = NULL,
	@HierarchyName nvarchar(50) = NULL,
	@SourceTypeID int = NULL, --Optional
	@StaticMemberYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000751,
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
EXEC [spIU_Dim_FullAccount_Raw] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DimensionID = -53, @HierarchyNo = 0, @HierarchyName = 'FullAccount', @DebugBM = 0
EXEC [spIU_Dim_FullAccount_Raw] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DimensionID = -53, @DimensionName = 'FullAccount', @HierarchyNo = 1, @HierarchyName = 'PnL_Carrier', @DebugBM = 0
EXEC [spIU_Dim_FullAccount_Raw] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DimensionID = -53, @DimensionName = 'FullAccount', @HierarchyNo = 2, @HierarchyName = 'Bal_Carrier', @SourceTypeID=3, @DebugBM = 3

EXEC [spIU_Dim_FullAccount_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@MemberID bigint,
	@DimensionFilter nvarchar(4000),
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@ModelBM int = 64,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@SQLFilter nvarchar(max),
	@TopNode_MemberId bigint,
	@Comment nvarchar(255),

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get a list of FullAccounts based on FACT_Financials and Account default hierarchy',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2165' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2167' SET @Description = 'Procedure enhanced.'
		IF @Version = '2.1.1.2169' SET @Description = 'Procedure enhanced.'
		IF @Version = '2.1.1.2173' SET @Description = 'Added parameter @StepReference in call to spGet_FilterTable.'
		
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

		IF @JobID = @ProcedureID SET @CalledYN = 0
		
		SELECT
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = ETLDatabase
		FROM
			pcINTEGRATOR_Data.dbo.[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @DebugBM & 2 > 0
			SELECT
				[@CalledYN] = @CalledYN,
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@DimensionID] = @DimensionID,
				[@SourceTypeID] = @SourceTypeID,
				[@ModelBM] = @ModelBM

	SET @Step = 'Create temp tables'
		CREATE TABLE #FullAccount_Members_Raw
			(
			[MemberId] [bigint] IDENTITY(20000001, 1),
			[MemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[Description] [nvarchar](255) COLLATE DATABASE_DEFAULT,
			[Account_MemberId] [bigint],
			[Account] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[AccountDescription] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[AccountType_MemberId] [bigint],
			[AccountType] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[DimensionFilter] [nvarchar](4000) COLLATE DATABASE_DEFAULT,
			[FullAccountDescription] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[GL_Product_MemberId] [bigint],
			[GL_Product] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[GL_CounterPart_MemberId] [bigint],
			[GL_CounterPart] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[HelpText] [nvarchar](1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[EvalPrio] int DEFAULT 0,
			[SBZ] [bit],
			[Sign] [int],
			[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Synchronized] [bit],
			[TimeBalance] [bit],
			[ParentMemberID] [bigint],
			[SortOrder] int
			)

		CREATE TABLE #Parent
			(
			[MemberID] bigint,
			[ParentMemberID] bigint,
			[SortOrder] int,
			[NodeTypeBM] int,
			[Checked] bit
			)

		CREATE TABLE #DimensionFilter
			(
			[MemberID] bigint,
			[DimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT
			)

	IF @HierarchyNo = 0
		BEGIN
			SET @Step = 'Fill table #FullAccount_Members_Raw with leaf members.'
				INSERT INTO #FullAccount_Members_Raw
					(
					[Account_MemberID],
					[GL_Product_MemberId],
					[GL_CounterPart_MemberId],
					[NodeTypeBM]
					)
				SELECT DISTINCT
					[Account_MemberID],
					[GL_Product_MemberId],
					[GL_CounterPart_MemberId],
					[NodeTypeBM] = 1
				FROM
					pcDATA_TECA..[FACT_Financials_default_partition]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#FullAccount_Members_Raw', * FROM #FullAccount_Members_Raw ORDER BY [MemberID]

			SET @Step = 'Fill temp table #Parent'
				INSERT INTO #Parent
					(
					[MemberID],
					[ParentMemberID],
					[SortOrder],
					[NodeTypeBM]
					)
				SELECT 
					[MemberID] = H.[MemberID],
					[ParentMemberID] = H.[ParentMemberID],
					[SortOrder] = H.[SequenceNumber],
					[NodeTypeBM] = 18
				FROM
					pcDATA_TECA..S_HS_Account_Account H
				WHERE
					[MemberID] = 290

				WHILE (SELECT COUNT(1) FROM #Parent WHERE [NodeTypeBM] & 16 > 0 AND [Checked] IS NULL) > 0
					BEGIN
						SELECT
							@MemberID = MIN([MemberID])
						FROM
							#Parent
						WHERE
							[NodeTypeBM] & 16 > 0 AND
							[Checked] IS NULL

						INSERT INTO #Parent
							(
							[MemberID],
							[ParentMemberID],
							[SortOrder],
							[NodeTypeBM]
							)
						SELECT 
							[MemberID] = H.[MemberID],
							[ParentMemberID] = H.[ParentMemberID],
							[SortOrder] = H.[SequenceNumber],
							[NodeTypeBM] = CASE WHEN D.[RNodeType] = 'P' THEN 18 ELSE 1 END
						FROM
							pcDATA_TECA..S_HS_Account_Account H
							INNER JOIN pcDATA_TECA..S_DS_Account D ON D.[MemberID] = H.[MemberId]
						WHERE
							[ParentMemberID] = @MemberID

						UPDATE #Parent
						SET [Checked] = 1
						WHERE [MemberID] = @MemberID
					END

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Parent', * FROM #Parent ORDER BY [MemberID]

			SET @Step = 'Update #FullAccount_Members_Raw'
				UPDATE FAMR
				SET
					[MemberKey] = [Account].[Label] + '-' + [GL_Product].[Label] + '-' + [GL_CounterPart].[Label],
					[Description] = [Account].[Description] + ' - ' + [GL_Product].[Description] + ' - ' + [GL_CounterPart].[Description],
					[Account] = [Account].[Label],
					[AccountDescription] = [Account].[Description],
					[AccountType_MemberId] = [Account].[AccountType_MemberId],
					[AccountType] = [Account].[AccountType],
					[DimensionFilter] = '',
					[FullAccountDescription] = [Account].[Description] + ' - ' + [GL_Product].[Description] + ' - ' + [GL_CounterPart].[Description],
					[GL_Product] = [GL_Product].[Label],
					[GL_CounterPart] = [GL_CounterPart].[Label],
					[HelpText] = [Account].[Label] + '-' + [GL_Product].[Label] + '-' + [GL_CounterPart].[Label] + ' ' + [Account].[Description] + ' - ' + [GL_Product].[Description] + ' - ' + [GL_CounterPart].[Description],
					[NodeTypeBM] = 1,
					[SBZ] = 0,
					[Sign] = [Account].[Sign],
					[Source] = 'ETL',
					[Synchronized] = 1,
					[TimeBalance] = [Account].[TimeBalance],
					[ParentMemberID] = ISNULL(P.[ParentMemberID], 2),
					[SortOrder] = P.[SortOrder]
				FROM
					#FullAccount_Members_Raw FAMR
					INNER JOIN pcDATA_TECA..[S_DS_Account] [Account] ON [Account].[MemberID] = FAMR.[Account_MemberId]
					INNER JOIN pcDATA_TECA..[S_DS_GL_Product] [GL_Product] ON [GL_Product].[MemberID] = FAMR.[GL_Product_MemberId]
					INNER JOIN pcDATA_TECA..[S_DS_GL_CounterPart] [GL_CounterPart] ON [GL_CounterPart].[MemberID] = FAMR.[GL_CounterPart_MemberId]
					LEFT JOIN #Parent P ON P.[MemberID] = FAMR.[Account_MemberId] AND P.NodeTypeBM = 1

				IF @DebugBM & 2 > 0 SELECT TempTable = '#FullAccount_Members_Raw', * FROM #FullAccount_Members_Raw ORDER BY [MemberID]

			SET @Step = 'DimensionFilter_Cursor'
				IF CURSOR_STATUS('global','DimensionFilter_Cursor') >= -1 DEALLOCATE DimensionFilter_Cursor
				DECLARE DimensionFilter_Cursor CURSOR FOR
			
					SELECT DISTINCT
						[MemberID] = [ParentMemberID]
					FROM
						#Parent
					WHERE
						NodeTypeBM & 1 > 0
					ORDER BY
						[ParentMemberID]

					OPEN DimensionFilter_Cursor
					FETCH NEXT FROM DimensionFilter_Cursor INTO @MemberID

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@MemberID] = @MemberID

							SET @DimensionFilter = 'Account='

							SELECT
								@DimensionFilter = @DimensionFilter + [Account].[Label] + ','
							FROM
								#Parent P
								INNER JOIN pcDATA_TECA..[S_DS_Account] [Account] ON [Account].[MemberID] = P.[MemberId]
							WHERE
								P.[ParentMemberID] = @MemberID
							ORDER BY
								[SortOrder]

							INSERT INTO #DimensionFilter
								(
								[MemberID],
								[DimensionFilter]
								)
							SELECT
								[MemberID] = @MemberID,
								[DimensionFilter] = LEFT(@DimensionFilter, LEN(@DimensionFilter) -1)

							FETCH NEXT FROM DimensionFilter_Cursor INTO @MemberID
						END

				CLOSE DimensionFilter_Cursor
				DEALLOCATE DimensionFilter_Cursor

			SET @Step = 'Insert parents into #FullAccount_Members_Raw'	
				SET IDENTITY_INSERT #FullAccount_Members_Raw ON

				INSERT INTO #FullAccount_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[Account_MemberId],
					[Account],
					[AccountDescription],
					[AccountType_MemberId],
					[AccountType],
					[DimensionFilter],
					[FullAccountDescription],
					[GL_Product_MemberId],
					[GL_Product],
					[GL_CounterPart_MemberId],
					[GL_CounterPart],
					[HelpText],
					[NodeTypeBM],
					[SBZ],
					[Sign],
					[Source],
					[Synchronized],
					[TimeBalance],
					[ParentMemberID],
					[SortOrder]
					)
				SELECT DISTINCT
					[MemberId] = P.[MemberId],
					[MemberKey] = [Account].[Label],
					[Description] = [Account].[Description],
					[Account_MemberId] = P.[MemberId],
					[Account] = [Account].[Label],
					[AccountDescription] = [Account].[Description],
					[AccountType_MemberId] = [AccountType_MemberId],
					[AccountType] = [AccountType],
					[DimensionFilter] = DF.[DimensionFilter],
					[FullAccountDescription] = [Account].[Description],
					[GL_Product_MemberId] = -1,
					[GL_Product] = 'NONE',
					[GL_CounterPart_MemberId] = -1,
					[GL_CounterPart] = 'NONE',
					[HelpText] = [Account].[HelpText],
					[NodeTypeBM] = 18,
					[SBZ] = [Account].[SBZ],
					[Sign] = [Account].[Sign],
					[Source] = 'ETL',
					[Synchronized] = 1,
					[TimeBalance] = [Account].[TimeBalance],
					[ParentMemberID] = P.[ParentMemberID],
					[SortOrder] = P.[SortOrder]
				FROM
					#Parent P
					INNER JOIN pcDATA_TECA..[S_DS_Account] [Account] ON [Account].[MemberID] = P.[MemberId] AND [Account].[RNodeType] = 'P'
					LEFT JOIN #DimensionFilter DF ON DF.[MemberID] = P.[MemberID]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#FullAccount_Members_Raw', * FROM #FullAccount_Members_Raw ORDER BY [MemberID]

			SET @Step = 'Get default members'
				IF @StaticMemberYN <> 0
					BEGIN
						SELECT
							@ModelBM = SUM(ModelBM)
						FROM
							(SELECT DISTINCT ModelBM FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DEletedID IS NULL) sub
				
						INSERT INTO #FullAccount_Members_Raw
							(
							[MemberId],
							[MemberKey],
							[Description],
							[HelpText],
							[NodeTypeBM],
							[Source],
							[ParentMemberID]
							)
						SELECT 
							[MemberId] = MAX(M.[MemberId]),
							[MemberKey] = M.[Label],
							[Description] = MAX(REPLACE(M.[Description], '@All_Dimension', 'All FullAccounts')),
							[HelpText] = MAX(M.[HelpText]),
							[NodeTypeBM] = MAX(M.[NodeTypeBM]),
							[Source] = 'ETL',
							[ParentMemberID] = CASE WHEN MAX(M.[Parent]) = 'All_' THEN 1 ELSE MAX(M.[Parent]) END
						FROM 
							[Member] M
						WHERE
							M.[DimensionID] IN (0, @DimensionID) AND
							M.[ModelBM] & @ModelBM > 0
						GROUP BY
							M.[Label]

						SET @Selected = @Selected + @@ROWCOUNT
					END

				SET IDENTITY_INSERT #FullAccount_Members_Raw OFF
		END

	ELSE
		BEGIN
			SET @Step = 'Manual Hierarchies'
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
		END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#FullAccount_Members_Raw',
					*
				FROM
					#FullAccount_Members_Raw
				ORDER BY
					MemberID

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#FullAccount_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[Account_MemberId],
					[Account],
					[AccountDescription],
					[AccountType_MemberId],
					[AccountType],
					[DimensionFilter],
					[FullAccountDescription],
					[GL_Product_MemberId],
					[GL_Product],
					[GL_CounterPart_MemberId],
					[GL_CounterPart],
					[HelpText],
					[NodeTypeBM],
					[EvalPrio],
					[SBZ],
					[Sign],
					[Source],
					[Synchronized],
					[TimeBalance],
					[ParentMemberID],
					[SortOrder]
					)
				SELECT TOP 1000000
					[MemberId],
					[MemberKey],
					[Description],
					[Account_MemberId],
					[Account],
					[AccountDescription],
					[AccountType_MemberId],
					[AccountType],
					[DimensionFilter],
					[FullAccountDescription],
					[GL_Product_MemberId],
					[GL_Product],
					[GL_CounterPart_MemberId],
					[GL_CounterPart],
					[HelpText],
					[NodeTypeBM],
					[EvalPrio],
					[SBZ],
					[Sign],
					[Source],
					[Synchronized],
					[TimeBalance],
					[ParentMemberID],
					[SortOrder]
				FROM
					[#FullAccount_Members_Raw]
				WHERE
					NodeTypeBM & 3 > 0
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #FullAccount_Members_Raw
		DROP TABLE #Parent
		DROP TABLE #DimensionFilter

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
