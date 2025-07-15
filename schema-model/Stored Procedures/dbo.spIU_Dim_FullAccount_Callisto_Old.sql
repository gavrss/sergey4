SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_FullAccount_Callisto_Old]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -53,
	@HierarchyNo int = NULL,
	@StaticMemberYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000752,
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
EXEC [spIU_Dim_FullAccount_Callisto] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DebugBM = 3
EXEC [spIU_Dim_FullAccount_Callisto] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @HierarchyNo=2, @DebugBM = 15

EXEC [spIU_Dim_FullAccount_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceTypeID int = NULL,
	@SourceDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@LinkedYN bit,
	@MappingTypeID int,
	@SQLStatement nvarchar(max),
	@DimensionName nvarchar(50),
	@HierarchyName nvarchar(50),
	@Dimensionhierarchy nvarchar(100),

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2169'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto FullAccount tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2165' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2167' SET @Description = 'Procedure enhanced.'
		IF @Version = '2.1.1.2169' SET @Description = 'Procedure enhanced.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT OFF 
--SET NOCOUNT ON 

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
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SELECT
			@DimensionName = [DimensionName]
		FROM
			[pcINTEGRATOR].[dbo].[Dimension]
		WHERE
			[InstanceID] IN (0, @InstanceID) AND
			[DimensionID] = @DimensionID

		--SELECT
		--	@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		--FROM
		--	pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		--WHERE
		--	InstanceID = @InstanceID AND
		--	VersionID = @VersionID AND
		--	DimensionID = @DimensionID

		IF @DebugBM & 2 > 0
			SELECT
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@StaticMemberYN] = @StaticMemberYN,
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'Create temp tables'
		CREATE TABLE #FullAccount_Members
			(
			[MemberId] [bigint] ,
			[MemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
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
			[RNodeType] [nvarchar](2) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[EvalPrio] int DEFAULT 0,
			[SBZ] [bit],
			[Sign] [int],
			[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Synchronized] [bit],
			[TimeBalance] [bit],
			[ParentMemberID] [bigint],
			[Parent] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

		CREATE TABLE #Hierarchy
			(
			[HierarchyNo] int,
			[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Fill cursor table'
		INSERT INTO #Hierarchy
			(
			[HierarchyNo],
			[HierarchyName]
			)
		SELECT
			[HierarchyNo],
			[HierarchyName]
		FROM
			(
			SELECT
				[HierarchyNo],
				[HierarchyName]
			FROM
				[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
			WHERE
				[InstanceID] IN (@InstanceID) AND
				[VersionID] IN (@VersionID) AND
				[DimensionID] = @DimensionID AND
				([HierarchyNo] = @HierarchyNo OR @HierarchyNo IS NULL)

			UNION SELECT
				[HierarchyNo],
				[HierarchyName]
			FROM
				[pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] DH
			WHERE
				[InstanceID] IN (0) AND
				[VersionID] IN (0) AND
				[DimensionID] = @DimensionID AND
				([HierarchyNo] = @HierarchyNo OR @HierarchyNo IS NULL) AND
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DDH WHERE DDH.[InstanceID] IN (@InstanceID) AND DDH.[VersionID] IN (@VersionID) AND DDH.DimensionID = DH.DimensionID AND DDH.HierarchyNo = DH.HierarchyNo)
			) sub

		IF @DebugBM & 2  > 0 SELECT TempTable = '#Hierarchy', * FROM #Hierarchy

	SET @Step = 'Fetch members'
		IF CURSOR_STATUS('global','Hierarchy_Cursor') >= -1 DEALLOCATE Hierarchy_Cursor
		DECLARE Hierarchy_Cursor CURSOR FOR
			
			SELECT
				[HierarchyNo],
				[HierarchyName]
			FROM
				#Hierarchy
			ORDER BY
				[HierarchyNo]

			OPEN Hierarchy_Cursor
			FETCH NEXT FROM Hierarchy_Cursor INTO @HierarchyNo, @HierarchyName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@HierarchyNo] = @HierarchyNo, [@HierarchyName] = @HierarchyName

					TRUNCATE TABLE #FullAccount_Members 

					EXEC [spIU_Dim_FullAccount_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DimensionID=@DimensionID, @DimensionName=@DimensionName, @StaticMemberYN=@StaticMemberYN, @HierarchyNo=@HierarchyNo, @HierarchyName=@HierarchyName, @JobID=@JobID, @Debug=@DebugSub

					IF @DebugBM & 8 > 0 SELECT TempTable = '#FullAccount_Members', * FROM #FullAccount_Members

					SET @Step = 'Update #FullAccount_Members.'
						UPDATE #FullAccount_Members 
						SET
							[Label] = [MemberKey],
							[RNodeType] = CASE WHEN [NodeTypeBM] & 1 > 0 THEN 'L' ELSE 'P' END
						
					IF @HierarchyNo = 0
						BEGIN
							SET @Step = 'Update Parent in #FullAccount_Members.'
								UPDATE FAM
								SET
									[Parent] = FAMP.[MemberKey]
								FROM
									#FullAccount_Members FAM
									INNER JOIN #FullAccount_Members FAMP ON FAMP.[MemberId] = FAM.[ParentMemberID]

							SET @Step = 'Delete Members.'
								SET @SQLStatement = '
									DELETE
										[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
									WHERE 
										[Synchronized] <> 0 AND
										MemberID < 30000000'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @Deleted = @Deleted + @@ROWCOUNT

								SET @SQLStatement = '
									DELETE
										[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + ']
									WHERE 
										MemberID < 30000000'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @Deleted = @Deleted + @@ROWCOUNT
		
							SET @Step = 'Insert new members from source system'
								SET @SQLStatement = '
									INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
										(
										[MemberId],
										[Label],
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
										[EvalPrio],
										[RNodeType],
										[SBZ],
										[Sign],
										[Source],
										[Synchronized],
										[TimeBalance]
										)
									SELECT
										[MemberId],
										[Label],
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
										[EvalPrio],
										[RNodeType],
										[SBZ],
										[Sign],
										[Source],
										[Synchronized],
										[TimeBalance]
									FROM   
										[#FullAccount_Members] Members
									WHERE
										NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [FullAccount] WHERE Members.Label = [FullAccount].[Label])'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @Inserted = @Inserted + @@ROWCOUNT

							SET @Step = 'Update MemberId'
								EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = N'FullAccount', @JobID = @JobID, @Debug = @DebugSub
						END
					ELSE IF @HierarchyNo > 0
						BEGIN
							SET @Step = 'Delete leafs in the hierarchy.'
								SET @SQLStatement = '
									DELETE H
									FROM
										[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H
										INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[MemberId] = H.[MemberId] AND D.[RNodeType] IN (''L'', ''LC'') AND LEN(ISNULL(D.[DimensionFilter], '''')) = 0
									WHERE
										H.[MemberId] >= 10 AND
										NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] P WHERE P.[ParentMemberId] = D.[MemberId])'

--										INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[MemberId] = H.[MemberId] AND D.[MemberId] > 10 AND D.[RNodeType] IN (''L'', ''LC'')'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @Deleted = @Deleted + @@ROWCOUNT
						END

					SET @Step = 'Insert new members into the hierarchy. Not Synchronized members will not be added. To change the hierarchy, use the Modeler.'
						SET @SQLStatement = '
							INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + ']
								(
								[MemberId],
								[ParentMemberId],
								[SequenceNumber]
								)
							SELECT
								[MemberId] = FAM.MemberId,
								[ParentMemberId] = FAM.[ParentMemberId],
								[SequenceNumber] = FAM.[SortOrder]
							FROM
								[#FullAccount_Members] FAM
							WHERE
								FAM.[MemberId] <> 30000000 AND
								NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] DH WHERE DH.[MemberId] = FAM.MemberId)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					
					SET @Step = 'Delete parents without children.'
						IF @HierarchyNo = 0
							BEGIN
								SET @SQLStatement = '
									DELETE H
									FROM
										[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H
										INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] DL ON DL.[MemberID] = H.[MemberID] AND DL.[RNodeType] = ''P''
									WHERE
										NOT EXISTS (SELECT DISTINCT HD.[ParentMemberID] FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] HD WHERE HD.[ParentMemberID] = H.[MemberID])'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
							END

					SET @Step = 'Update RNodeType'
						SET @SQLStatement = '
							UPDATE D
							SET
								[RNodeType] = CASE WHEN P.ParentMemberID IS NULL THEN ''L'' ELSE ''P'' END
							FROM 
								[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
								INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H ON H.[MemberId] = D.[MemberId]
								LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] P ON P.[ParentMemberId] = D.[MemberId]
								
							UPDATE D
							SET
								[RNodeType] = CASE WHEN P.ParentMemberID IS NULL THEN ''L'' ELSE ''P'' END
							FROM 
								[' + @CallistoDatabase + '].[dbo].[O_DS_' + @DimensionName + '] D
								INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H ON H.[MemberId] = D.[MemberId]
								LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] P ON P.[ParentMemberId] = D.[MemberId]'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					SET @Step = 'Copy the hierarchy to all instances'
						SET @Dimensionhierarchy = @DimensionName + '_' + @HierarchyName
						EXEC [pcINTEGRATOR].[dbo].[spSet_HierarchyCopy] @Database = @CallistoDatabase, @Dimensionhierarchy = @Dimensionhierarchy, @JobID = @JobID, @Debug = @DebugSub
					
					FETCH NEXT FROM Hierarchy_Cursor INTO @HierarchyNo, @HierarchyName
				END

		CLOSE Hierarchy_Cursor
		DEALLOCATE Hierarchy_Cursor

	SET @Step = 'Temporary fix'
		UPDATE FA
		SET 
			[DimensionFilter] = ISNULL([DimensionFilter], ''),
			[Account_MemberId] = ISNULL(CASE WHEN [Account_MemberId] = 0 THEN NULL ELSE [Account_MemberId] END, -1),
			[Account] = ISNULL([Account], 'NONE'),
			[AccountType_MemberId] = ISNULL(CASE WHEN [AccountType_MemberId] = 0 THEN NULL ELSE [AccountType_MemberId] END, -1),
			[AccountType] = ISNULL([AccountType], 'NONE'),
			[GL_Product_MemberId] = ISNULL(CASE WHEN [GL_Product_MemberId] = 0 THEN NULL ELSE [GL_Product_MemberId] END, -1),
			[GL_Product] = ISNULL([GL_Product], 'NONE'),
			[GL_CounterPart_MemberId] = ISNULL(CASE WHEN [GL_CounterPart_MemberId] = 0 THEN NULL ELSE [GL_CounterPart_MemberId] END, -1),
			[GL_CounterPart] = ISNULL([GL_CounterPart], 'NONE')
		FROM
			[pcDATA_TECA].[dbo].[S_DS_FullAccount] FA

		UPDATE FA
		SET 
			[DimensionFilter] = ISNULL([DimensionFilter], ''),
			[Account_MemberId] = ISNULL(CASE WHEN [Account_MemberId] = 0 THEN NULL ELSE [Account_MemberId] END, -1),
			[Account] = ISNULL([Account], 'NONE'),
			[AccountType_MemberId] = ISNULL(CASE WHEN [AccountType_MemberId] = 0 THEN NULL ELSE [AccountType_MemberId] END, -1),
			[AccountType] = ISNULL([AccountType], 'NONE'),
			[GL_Product_MemberId] = ISNULL(CASE WHEN [GL_Product_MemberId] = 0 THEN NULL ELSE [GL_Product_MemberId] END, -1),
			[GL_Product] = ISNULL([GL_Product], 'NONE'),
			[GL_CounterPart_MemberId] = ISNULL(CASE WHEN [GL_CounterPart_MemberId] = 0 THEN NULL ELSE [GL_CounterPart_MemberId] END, -1),
			[GL_CounterPart] = ISNULL([GL_CounterPart], 'NONE')
		FROM
			[pcDATA_TECA].[dbo].[O_DS_FullAccount] FA

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_FullAccount]'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_FullAccount]')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#FullAccount_Members]
		DROP TABLE [#Hierarchy]

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
