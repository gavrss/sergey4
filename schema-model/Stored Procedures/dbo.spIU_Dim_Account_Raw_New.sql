SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Account_Raw_New]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -1,
	@SourceTypeID int = NULL, --Optional
	@SourceID int = NULL, --Optional
	@SourceDatabase nvarchar(100) = NULL, --Optional
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN bit = 1,
	@MappingTypeID int = NULL,
	@Entity_MemberKey NVARCHAR(50) = NULL,	--Mandatory for SIE4

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000630,
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
EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_Account_Raw] @Debug='0',@DimensionID='-1',@InstanceID='621'
,@MappingTypeID='0',@SequenceBMStep='65535',@StaticMemberYN='1',@UserID='-10',@VersionID='1105',@DebugBM=15

EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_Account_Raw] @Debug='0',@DimensionID='-1',@InstanceID='531'
,@MappingTypeID='0',@UserID='-10',@VersionID='1057',@DebugBM=15


EXEC [spIU_Dim_Account_Raw] @UserID = -10, @InstanceID = 672, @VersionID = 1132, @SourceTypeID = 5,  @DebugBM = 7


EXEC [spIU_Dim_Account_Raw] @UserID = -10, @InstanceID = -1316, @VersionID = -1254, @SourceTypeID = 11,  @Debug = 1
EXEC [spIU_Dim_Account_Raw] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @SequenceBMStep = 15, @StaticMemberYN = 1, @Debug = 1
EXEC [spIU_Dim_Account_Raw] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @SequenceBMStep = 15, @StaticMemberYN = 1, @DebugBM = 3
EXEC [spIU_Dim_Account_Raw] @UserID = -10, @InstanceID = 497, @VersionID = 1039, @SequenceBMStep = 15, @StaticMemberYN = 1, @Debug = 1
EXEC [spIU_Dim_Account_Raw_New] @UserID = -10, @InstanceID = 515, @VersionID = 1064, @SequenceBMStep = 15, @StaticMemberYN = 1, @Debug = 1
EXEC [spIU_Dim_Account_Raw] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @SequenceBMStep = 15, @StaticMemberYN = 1, @DebugBM = 7
EXEC [spIU_Dim_Account_Raw] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @SequenceBMStep = 15, @StaticMemberYN = 1, @Debug = 1

EXEC [spIU_Dim_Account_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceTypeName nvarchar(50),
	@SourceTypeBM int,
	@SQLStatement nvarchar(max),
	@ModelBM int,
	@AccountCategory_StorageTypeBM int,
	@AccountCategory_SourceTable nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@Owner nvarchar(3),
	@Entity nvarchar(50),
	@Priority int,
	@TableName nvarchar(255),

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
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of Financial Accounts from Source system',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2149' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'More features handled.'
		IF @Version = '2.0.3.2154' SET @Description = 'Changed AccountType to Member.'
		IF @Version = '2.1.0.2159' SET @Description = 'Handle priority order and MappingTypeID.'
		IF @Version = '2.1.0.2160' SET @Description = 'Handle P21.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added [Entity] when INSERTing into temp table #Account_Members.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.0.2167' SET @Description = 'Prefix AccountCategory with AC_ for iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed default Priority to 99999999.'
		IF @Version = '2.1.1.2171' SET @Description = 'Set Entity to empty string for SIE4 source.'
		IF @Version = '2.1.1.2172' SET @Description = 'Handle references to not synchronized parents. Added COLLATE DATABASE_DEFAULT on reference to source table in the LEFT JOIN to [#NoSyncParent].'
		IF @Version = '2.1.1.2173' SET @Description = 'Removed ELSE-IF statements for @SourceTypeIDs not yet implemented.'
		IF @Version = '2.1.1.2177' SET @Description = 'Distinguish InstanceID from which table since InstanceID is added to SourceType table.'
		IF @Version = '2.1.2.2179' SET @Description = 'Added @DimensionID and @SourceID as Parameters. Added @Entity_MemberKey parameter (Mandatory for SIE4).'
		IF @Version = '2.1.2.2190' SET @Description = 'EA-2852: Fixed datatype conversion issue on @SourceTypeID = 11.EA-1636: Added [SourceID] column in #EB.'
		IF @Version = '2.1.2.2193' SET @Description = 'Added [] arround @SourceDatabase for dynamic SQL'
		IF @Version = '2.1.2.2197' SET @Description = 'Set correct AccountType for iScala source.'
		IF @Version = '2.1.2.2199' SET @Description = 'Made generic code for P21 Account Leaf Members. Made a temp table for P21/COA to increase performance with new query optimizer in SQL 2019.'

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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@SourceTypeBM = SUM(SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				ST.SourceTypeBM
			FROM
				SourceType ST
				INNER JOIN [Source] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.SourceTypeID = ST.SourceTypeID AND S.SelectYN <> 0
			) sub

		SELECT
			@AccountCategory_StorageTypeBM = StorageTypeBM
		FROM
			pcINTEGRATOR_Data.dbo.Dimension_StorageType
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = -65

		SELECT
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = ETLDatabase
		FROM
			pcINTEGRATOR_Data.dbo.[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT
			@AccountCategory_SourceTable = CASE WHEN @AccountCategory_StorageTypeBM & 2 > 0 THEN @ETLDatabase + '.dbo.pcD_AccountCategory' ELSE CASE WHEN @AccountCategory_StorageTypeBM & 4 > 0 THEN @CallistoDatabase + '.dbo.S_DS_AccountCategory' ELSE @ETLDatabase + '.dbo.AccountType_Translate' END END

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @SourceTypeID IS NULL
			SELECT @SourceTypeID = 7 FROM pcINTEGRATOR_Data..SIE4_Job WHERE InstanceID = @InstanceID AND JobID = @JobID

		IF OBJECT_ID(N'TempDB.dbo.#Account_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@AccountCategory_StorageTypeBM] = @AccountCategory_StorageTypeBM,
				[@AccountCategory_SourceTable] = @AccountCategory_SourceTable,
				[@MappingTypeID] = @MappingTypeID,
				[@CalledYN] = @CalledYN,
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@SourceTypeID] = @SourceTypeID

	SET @Step = 'Check for not synchronized parents'
		IF OBJECT_ID(N'TempDB.dbo.#NoSyncParent', N'U') IS NULL
			CREATE TABLE #NoSyncParent
				(
				[MemberId] bigint,
				[MemberKey] nvarchar(255) COLLATE DATABASE_DEFAULT
				)

		--NB. Table #NoSyncParent is not filled with any rows when just running the Raw-SP.

	SET @Step = 'Create temp table #Account_Members_Raw'
		CREATE TABLE #Account_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) DEFAULT ('') COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[AccountCategory] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[AccountType] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[Rate] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[Sign] int,
			[TimeBalance] int,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Priority] int,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #TableName'
		CREATE TABLE #TableName
			(
			[TableName] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Entity_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] int,
			[Priority] int
			)

	SET @Step = 'Create temp table #MappedMemberKey'
		CREATE TABLE #MappedMemberKey
			(
			[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[MemberKeyFrom] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[MemberKeyTo] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[MappedMemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[MappedDescription] [nvarchar](255) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #MappedMemberKey
			(
			[Entity],
			[MemberKeyFrom],
			[MemberKeyTo],
			[MappedMemberKey],
			[MappedDescription]
			)
		SELECT 
			[Entity] = [Entity_MemberKey],
			[MemberKeyFrom],
			[MemberKeyTo],
			[MappedMemberKey],
			[MappedDescription]
		FROM
			[pcINTEGRATOR_Data].[dbo].[MappedMemberKey]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DimensionID] = @DimensionID AND
			[MappingTypeID] = 3 AND
			[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#MappedMemberKey', * FROM #MappedMemberKey

	SET @Step = 'Create temp table #AccountType'
		SELECT
			[AccountType] = DM.MemberKey,
			[Rate] = MAX(CASE WHEN DMP.PropertyID = -5 THEN DMP.[Value] END),
			[Sign] = MAX(CASE WHEN DMP.PropertyID = -7 THEN DMP.[Value] END),
			[TimeBalance] = MAX(CASE WHEN DMP.PropertyID = -8 THEN DMP.[Value] END)
		INTO	
			#AccountType
		FROM
			[DimensionMember] DM
			LEFT JOIN [DimensionMember_Property] DMP ON DMP.InstanceID = DM.InstanceID AND DMP.DimensionID = DM.DimensionID AND DM.MemberKey = DMP.MemberKey
		WHERE
			DM.InstanceID = 0 AND 
			DM.DimensionID = -62
		GROUP BY
			DM.MemberKey

	SET @Step = 'Create temp table #AccountCategory'
		CREATE TABLE #AccountCategory
			(
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[AccountCategory] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[AccountType] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		IF @AccountCategory_StorageTypeBM & 2 > 0
			SET @SQLStatement = '
				INSERT INTO #AccountCategory
					(
					[Source],
					[AccountCategory],
					[Description],
					[AccountType]
					)
				SELECT
					[Source] = [Source],
					[AccountCategory] = [MemberKey],
					[Description] = [Description],
					[AccountType] = [AccountType]
				FROM
					' + @AccountCategory_SourceTable + '
				WHERE
					NodeTypeBM & 1 > 0'
		ELSE IF @AccountCategory_StorageTypeBM & 4 > 0
			SET @SQLStatement = '
				INSERT INTO #AccountCategory
					(
					[Source],
					[AccountCategory],
					[Description],
					[AccountType]
					)
				SELECT
					[Source] = [Source],
					[AccountCategory] = [Label],
					[Description] = [Description],
					[AccountType] = [AccountType]
				FROM
					' + @AccountCategory_SourceTable + '
				WHERE
					RNodeType = ''L'''
		ELSE
			SET @SQLStatement = '
				INSERT INTO #AccountCategory
					(
					[Source],
					[AccountCategory],
					[AccountType]
					)
				SELECT
					[Source] = [SourceTypeName],
					[AccountCategory] = [CategoryID],
					[AccountType] = [AccountType]
				FROM
					' + @AccountCategory_SourceTable 

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Create #EB (Entity/Book)'
		CREATE TABLE #EB
			(
			[EntityID] int,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[COA] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Priority] int,
			[SourceCode] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SourceID] int,
			)

		INSERT INTO #EB
			(
			[EntityID],
			[Entity],
			[Book],
			[COA],
			[Priority],
			[SourceCode],
			[SourceID]
			)
		SELECT DISTINCT
			[EntityID] = E.[EntityID],
			[Entity] = E.[MemberKey],
			[Book] = B.[Book],
			[COA] = B.[COA],
			[Priority] = CONVERT(int, ISNULL(E.[Priority], 99999999)),
			[SourceCode] = JSN.[SourceCode], --CONVERT(int, SUBSTRING([SourceCode],PATINDEX('%[0-9]%', [SourceCode]),LEN([SourceCode])))
			[SourceID] = E.[SourceID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.VersionID AND B.EntityID = E.EntityID AND B.BookTypeBM & 1 > 0 AND B.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.[InstanceID] = E.[InstanceID] AND JSN.[VersionID] = E.[VersionID] AND JSN.[Book] = B.[Book] AND JSN.[DimensionID] = -1 AND JSN.[SelectYN] <> 0
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.[MemberKey] = @Entity_MemberKey OR @Entity_MemberKey IS NULL) AND
			E.[SelectYN] <> 0

		IF @DebugBM & 2 > 0
			BEGIN
				SELECT TempTable = '#AccountType', * FROM #AccountType
				SELECT TempTable = '#AccountCategory', * FROM #AccountCategory
				SELECT TempTable = '#EB', * FROM #EB
			END

	SET @Step = 'Create CursorTable'
		CREATE TABLE #Account_CursorTable
			(
			[SourceTypeID] int,
			[SourceTypeName] nvarchar(50),
			[SourceID] int,
			[Owner] nvarchar(3) COLLATE DATABASE_DEFAULT,
			[SourceDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #Account_CursorTable
			(
			[SourceTypeID],
			[SourceTypeName],
			[SourceID],
			[Owner],
			[SourceDatabase]
			)
		SELECT DISTINCT
			[SourceTypeID] = S.[SourceTypeID],
			[SourceTypeName] = ST.[SourceTypeName],
			[SourceID] = S.[SourceID],
			[Owner] = CASE WHEN S.[SourceTypeID] = 11 THEN 'erp' ELSE 'dbo' END,
			[SourceDatabase] = ISNULL(@SourceDatabase, S.[SourceDatabase])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Source] S
			INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.[ModelID] = S.[ModelID] AND M.[ModelBM] & 64 > 0
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SelectYN] <> 0 AND
			(S.[SourceTypeID] = @SourceTypeID OR @SourceTypeID IS NULL) AND
			(S.[SourceID] = @SourceID OR @SourceID IS NULL)			
		UNION SELECT DISTINCT
			[SourceTypeID] = @SourceTypeID,
			[SourceTypeName] = ST.[SourceTypeName],
			[SourceID] = NULL,
			[Owner] = CASE WHEN ST.[SourceTypeID] = 11 THEN 'erp' ELSE 'dbo' END,
			[SourceDatabase] = NULL
		FROM
			pcINTEGRATOR_Data..SIE4_Job J
			INNER JOIN SourceType ST ON ST.SourceTypeID = @SourceTypeID
		WHERE
			J.InstanceID = @InstanceID AND
			J.JobID = @JobID

		UPDATE #Account_CursorTable
		SET [SourceDatabase] = CASE WHEN CHARINDEX( '[', [SourceDatabase]) = 0 
										THEN '[' + REPLACE([SourceDatabase], '.', '].[') + ']'
									ELSE [SourceDatabase]
									END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Account_CursorTable', * FROM #Account_CursorTable ORDER BY [SourceTypeID]		

	SET @Step = 'Fill temptable #Account_Members_Raw by using #Account_CursorTable'
		IF CURSOR_STATUS('global','Account_SourceType_Cursor') >= -1 DEALLOCATE Account_SourceType_Cursor
		DECLARE Account_SourceType_Cursor CURSOR FOR
			
			SELECT 
				[SourceTypeID],
				[SourceTypeName],
				[SourceID],
				[Owner],
				[SourceDatabase]
			FROM
				#Account_CursorTable
			ORDER BY
				[SourceTypeID]

			OPEN Account_SourceType_Cursor
			FETCH NEXT FROM Account_SourceType_Cursor INTO @SourceTypeID, @SourceTypeName, @SourceID, @Owner, @SourceDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@SourceTypeID] = @SourceTypeID, [@SourceTypeName] = @SourceTypeName, [@SourceID] = @SourceID, [@Owner] = @Owner, [@SourceDatabase] = @SourceDatabase
					
					IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10)
						BEGIN
							IF @SequenceBMStep & 1 > 0 --Account Categories, Parent levels
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Account_Members_Raw
											(
											[MemberId],
											[MemberKey],
											[Description],
											[NodeTypeBM],
											[AccountCategory],
											[AccountType],
											[Rate],
											[Sign],
											[TimeBalance],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT DISTINCT
											[MemberId] = NULL,
											[MemberKey] = ''AC_'' + COA.CategoryID,
											[Description] = COA.[Description],
											[NodeTypeBM] = 18,
											[AccountCategory] = COA.[CategoryID],
											[AccountType] = AC.[AccountType],
											[Rate] = [AT].[Rate],
											[Sign] = [AT].[Sign],
											[TimeBalance] = [AT].[TimeBalance],
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = CASE WHEN ISNULL(COA.ParentCategory, '''') = '''' OR COA.ParentCategory = COA.CategoryID THEN CASE WHEN [AT].AccountType IN (''Expense'', ''Income'') THEN ''Income_Statement_'' ELSE ''Balance_Sheet_'' END ELSE ''AC_'' + COA.ParentCategory END COLLATE DATABASE_DEFAULT,
											[Priority] = EB.[Priority],
											[Entity] = EB.[Entity]
										FROM
											' + @SourceDatabase + '.[' + @Owner + '].[COAActCat] COA
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COA.Company AND GLB.COACode = COA.COACode
											INNER JOIN [#EB] EB ON EB.SourceID = ' + CONVERT(NVARCHAR(15), @SourceID) + ' AND EB.Entity = GLB.Company COLLATE DATABASE_DEFAULT AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.COA = GLB.COACode COLLATE DATABASE_DEFAULT
											LEFT JOIN [#AccountCategory] AC ON AC.[Source] = ''' + @SourceTypeName + ''' AND AC.AccountCategory = COA.CategoryID COLLATE DATABASE_DEFAULT 
											LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = AC.[AccountType]'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT
								END

							IF @SequenceBMStep & 2 > 0 --Account Leafs
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Account_Members_Raw
											(
											[MemberId],
											[MemberKey],
											[Description],
											[NodeTypeBM],
											[AccountCategory],
											[AccountType],
											[Rate],
											[Sign],
											[TimeBalance],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT DISTINCT
											[MemberId] = NULL,
											[MemberKey] = COASV.[SegmentCode],
											[Description] = COASV.[SegmentName],
											[NodeTypeBM] = 1,
											[AccountCategory] = COASV.[Category],
											[AccountType] = [AC].[AccountType],
											[Rate] = [AT].[Rate],
											[Sign] = [AT].[Sign],
											[TimeBalance] = CONVERT(int, [AT].[TimeBalance]),
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = CASE WHEN ISNULL(COASV.Category, '''') = '''' OR NSP.[MemberKey] IS NOT NULL THEN NULL ELSE ''AC_'' + COASV.Category END,
											[Priority] = EB.[Priority],
											[Entity] = EB.[Entity]
										FROM
											' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COASV.Company AND GLB.COACode = COASV.COACode
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COASegment] COAS ON COAS.Company = GLB.Company AND COAS.COACode = GLB.COACode AND COAS.SegmentNbr = COASV.SegmentNbr		
											--INNER JOIN [#EB] EB ON EB.Entity = GLB.Company COLLATE DATABASE_DEFAULT AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.COA = GLB.COACode COLLATE DATABASE_DEFAULT AND CONVERT(int, SUBSTRING(EB.[SourceCode],PATINDEX(''%[0-9]%'', EB.[SourceCode]),LEN(EB.[SourceCode]))) = COAS.SegmentNbr
											INNER JOIN [#EB] EB ON EB.SourceID = ' + CONVERT(NVARCHAR(15), @SourceID) + ' AND EB.Entity = GLB.Company COLLATE DATABASE_DEFAULT AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.COA = GLB.COACode COLLATE DATABASE_DEFAULT AND CONVERT(int, SUBSTRING(EB.[SourceCode], CASE WHEN PATINDEX(''%[0-9]%'', EB.[SourceCode]) = 0 THEN NULL ELSE PATINDEX(''%[0-9]%'', EB.[SourceCode]) END,LEN(EB.[SourceCode]))) = COAS.SegmentNbr
											LEFT JOIN [#AccountCategory] AC ON AC.[Source] = ''' + @SourceTypeName + ''' AND AC.AccountCategory = COASV.Category COLLATE DATABASE_DEFAULT 
											LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = AC.[AccountType]
											LEFT JOIN [#NoSyncParent] NSP ON NSP.[MemberKey] = ''AC_'' + COASV.Category COLLATE DATABASE_DEFAULT'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT
								END

							IF @SequenceBMStep & 4 > 0 --Account Categories for Statistical Accounts
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Account_Members_Raw
											(
											[MemberId],
											[MemberKey],
											[Description],
											[NodeTypeBM],
											[AccountCategory],
											[AccountType],
											[Rate],
											[Sign],
											[TimeBalance],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT DISTINCT
											[MemberId] = NULL,
											[MemberKey] = ''ST_'' + COA.CategoryID,
											[Description] = COA.[Description],
											[NodeTypeBM] = 18,
											[AccountCategory] = COA.[CategoryID],
											[AccountType] = AC.[AccountType],
											[Rate] = [AT].[Rate],
											[Sign] = [AT].[Sign],
											[TimeBalance] = [AT].[TimeBalance],
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = ''ST_ERP_GL'' COLLATE DATABASE_DEFAULT,
											[Priority] = EB.[Priority],
											[Entity] = EB.[Entity]
										FROM
											' + @SourceDatabase + '.[' + @Owner + '].[COAActCat] COA
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COA.Company AND GLB.COACode = COA.COACode
											INNER JOIN (SELECT DISTINCT [CategoryID] = [Category] FROM ' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV WHERE Statistical <> 0) CAT ON CAT.[CategoryID] = COA.[CategoryID]
											INNER JOIN [#EB] EB ON EB.SourceID = ' + CONVERT(NVARCHAR(15), @SourceID) + ' AND EB.Entity = GLB.Company COLLATE DATABASE_DEFAULT AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.COA = GLB.COACode COLLATE DATABASE_DEFAULT
											LEFT JOIN [#AccountCategory] AC ON AC.[Source] = ''' + @SourceTypeName + ''' AND AC.AccountCategory = COA.CategoryID COLLATE DATABASE_DEFAULT 
											LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = AC.[AccountType]'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT
								END

							IF @SequenceBMStep & 8 > 0 --Account Leafs for Statistical Accounts
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Account_Members_Raw
											(
											[MemberId],
											[MemberKey],
											[Description],
											[NodeTypeBM],
											[AccountCategory],
											[AccountType],
											[Rate],
											[Sign],
											[TimeBalance],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT DISTINCT
											[MemberId] = NULL,
											[MemberKey] = ''ST_'' + COASV.[SegmentCode],
											[Description] = COASV.[SegmentName],
											[NodeTypeBM] = 1,
											[AccountCategory] = COASV.[Category],
											[AccountType] = [AC].[AccountType],
											[Rate] = [AT].[Rate],
											[Sign] = [AT].[Sign],
											[TimeBalance] = CONVERT(int, [AT].[TimeBalance]),
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] =  ''ST_'' + COASV.Category,
											[Priority] = EB.[Priority],
											[Entity] = EB.[Entity]
										FROM
											' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COASV.Company AND GLB.COACode = COASV.COACode
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COASegment] COAS ON COAS.Company = GLB.Company AND COAS.COACode = GLB.COACode AND COAS.SegmentNbr = COASV.SegmentNbr		
											--INNER JOIN [#EB] EB ON EB.Entity = GLB.Company COLLATE DATABASE_DEFAULT AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.COA = GLB.COACode COLLATE DATABASE_DEFAULT AND CONVERT(int, SUBSTRING(EB.[SourceCode],PATINDEX(''%[0-9]%'', EB.[SourceCode]),LEN(EB.[SourceCode]))) = COAS.SegmentNbr
											INNER JOIN [#EB] EB ON EB.SourceID = ' + CONVERT(NVARCHAR(15), @SourceID) + ' AND EB.Entity = GLB.Company COLLATE DATABASE_DEFAULT AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.COA = GLB.COACode COLLATE DATABASE_DEFAULT AND CONVERT(int, SUBSTRING(EB.[SourceCode], CASE WHEN PATINDEX(''%[0-9]%'', EB.[SourceCode]) = 0 THEN NULL ELSE PATINDEX(''%[0-9]%'', EB.[SourceCode]) END,LEN(EB.[SourceCode]))) = COAS.SegmentNbr
											LEFT JOIN [#AccountCategory] AC ON AC.[Source] = ''' + @SourceTypeName + ''' AND AC.AccountCategory = COASV.Category COLLATE DATABASE_DEFAULT 
											LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = AC.[AccountType]
										WHERE
											COASV.Statistical <> 0'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT
								END
						END

					ELSE IF @SourceTypeID = 3 --iScala
						BEGIN
							IF @SequenceBMStep & 1 > 0 --Account Categories, Parent levels
								BEGIN
									--Account Categories
									INSERT INTO #Account_Members_Raw
										(
										[MemberId],
										[MemberKey],
										[Description],
										[NodeTypeBM],
										[AccountCategory],
										[AccountType],
										[Rate],
										[Sign],
										[TimeBalance],
										[Source],
										[Parent],
										[Priority],
										[Entity]
										)
									SELECT DISTINCT
										[MemberId] = NULL,
										[MemberKey] = 'AC_' + AC.[AccountCategory],
										[Description] = AC.[Description],
										[NodeTypeBM] = 18,
										[AccountCategory] = [AC].[AccountCategory],
										[AccountType] = [AC].[AccountType],
										[Rate] = [AT].[Rate],
										[Sign] = [AT].[Sign],
										[TimeBalance] = CONVERT(int, [AT].[TimeBalance]),
										[Source] = @SourceTypeName,
										[Parent] = CASE [AT].[AccountType] WHEN 'Asset' THEN 'Assets_' WHEN 'Equity' THEN 'Equity_' WHEN 'Expense' THEN 'Expense_'WHEN 'Income' THEN 'Gross_Profit_'WHEN 'Liability' THEN 'Liabilities_' END,
										[Priority] = -999999,
										[Entity] = ''
									FROM
										[#AccountCategory] AC  
										LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = AC.[AccountType]
									WHERE
										AC.[Source] = @SourceTypeName

									SET @Selected = @Selected + @@ROWCOUNT
								END

							IF @SequenceBMStep & 2 > 0 --Accounts, Leaf level
								BEGIN
									TRUNCATE TABLE #TableName

									SET @SQLStatement = '
										INSERT INTO #TableName
											(
											[TableName],
											[Entity_MemberKey],
											[FiscalYear],
											[Priority]
											)
										SELECT
											[TableName],
											[Entity_MemberKey],
											[FiscalYear],
											[Priority]
										FROM
											' + @ETLDatabase + '.[dbo].[wrk_SourceTable]
										WHERE
											TableCode = ''GL53'' AND
											SourceID = ' + CONVERT(nvarchar(15), @SourceID)

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									IF CURSOR_STATUS('global','Table_Cursor') >= -1 DEALLOCATE Table_Cursor
									DECLARE Table_Cursor CURSOR FOR
			
										SELECT
											[TableName],
											[Entity_MemberKey],
											[Priority]
										FROM
											#TableName
										ORDER BY
											[Priority],
											[FiscalYear] DESC,
											[Entity_MemberKey]

										OPEN Table_Cursor
										FETCH NEXT FROM Table_Cursor INTO @TableName, @Entity, @Priority

										WHILE @@FETCH_STATUS = 0
											BEGIN
												IF @DebugBM & 2 > 0 SELECT [@TableName] = @TableName, [@Entity] = @Entity, [@Priority] = @Priority

												SET @SQLStatement = '
													INSERT INTO #Account_Members_Raw
														(
														[MemberId],
														[MemberKey],
														[Description],
														[NodeTypeBM],
														[AccountCategory],
														[AccountType],
														[Rate],
														[Sign],
														[TimeBalance],
														[Source],
														[Parent],
														[Priority],
														[Entity]
														)
													SELECT DISTINCT
														[MemberId] = NULL,
														[MemberKey] = LTRIM(RTRIM(S.[GL53001])),
														[Description] = LTRIM(RTRIM(S.[GL53002])),
														[NodeTypeBM] = 1,
														[AccountCategory] = COALESCE(AC4.[AccountCategory], AC3.[AccountCategory], AC2.[AccountCategory], AC1.[AccountCategory]),
														--[AccountType] = AT.[AccountType],
														AccountType = CASE (S.[GL53003]) 
																		WHEN ''0'' THEN CASE WHEN S.[GL53051 ]  = ''0'' THEN ''Expense'' ELSE ''Income'' END
																		WHEN ''1'' THEN CASE WHEN S.[GL53051 ]  = ''0'' THEN ''Asset'' ELSE ''Equity'' END
																		WHEN ''2'' THEN ''Statistical'' 
																		ELSE  AT.[AccountType]
																	END,
														[Rate] = AT.[Rate],
														[Sign] = AT.[Sign],
														[TimeBalance] = CONVERT(int, AT.[TimeBalance]),
														[Source] = ''' + @SourceTypeName + ''',
														[Parent] = ''AC_'' + COALESCE(AC4.[AccountCategory], AC3.[AccountCategory], AC2.[AccountCategory], AC1.[AccountCategory]),
														[Priority] = ' + CONVERT(nvarchar(15), @Priority) + ',
														[Entity] = ''' + @Entity + '''
													FROM
														' + @TableName + ' S
														LEFT JOIN [#AccountCategory] AC1 ON AC1.[Source] = ''' + @SourceTypeName + ''' AND AC1.[AccountCategory] = SUBSTRING(S.[GL53001], 1, 1) COLLATE DATABASE_DEFAULT 
														LEFT JOIN [#AccountCategory] AC2 ON AC2.[Source] = ''' + @SourceTypeName + ''' AND AC2.[AccountCategory] = SUBSTRING(S.[GL53001], 1, 2) COLLATE DATABASE_DEFAULT 
														LEFT JOIN [#AccountCategory] AC3 ON AC3.[Source] = ''' + @SourceTypeName + ''' AND AC3.[AccountCategory] = SUBSTRING(S.[GL53001], 1, 3) COLLATE DATABASE_DEFAULT 
														LEFT JOIN [#AccountCategory] AC4 ON AC4.[Source] = ''' + @SourceTypeName + ''' AND AC4.[AccountCategory] = SUBSTRING(S.[GL53001], 1, 4) COLLATE DATABASE_DEFAULT 
														LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = CASE (S.[GL53003]) 
																												WHEN ''0'' THEN CASE WHEN S.[GL53051 ]  = ''0'' THEN ''Expense'' ELSE ''Income'' END
																												WHEN ''1'' THEN CASE WHEN S.[GL53051 ]  = ''0'' THEN ''Asset'' ELSE ''Equity'' END
																												WHEN ''2'' THEN ''Statistical'' 
																												ELSE  AT.[AccountType] 
																												END
														--LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = COALESCE(AC4.[AccountType], AC3.[AccountType], AC2.[AccountType], AC1.[AccountType])
													WHERE
														NOT EXISTS (SELECT 1 FROM #Account_Members_Raw AMR WHERE AMR.MemberKey = S.[GL53001] COLLATE DATABASE_DEFAULT AND AMR.[Entity] = ''' + @Entity + ''')'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)
												SET @Selected = @Selected + @@ROWCOUNT

												FETCH NEXT FROM Table_Cursor INTO @TableName, @Entity, @Priority
											END
									CLOSE Table_Cursor
									DEALLOCATE Table_Cursor
								END
						END

					ELSE IF @SourceTypeID = 5 --P21
						BEGIN
							CREATE TABLE #Entity_AccountSourceCode
								(
								[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
								[MaskPosition] INT,
								[MaskCharacters] INT
								)

							CREATE TABLE #COA
								(
								[MemberKey] [nvarchar](50) COLLATE DATABASE_DEFAULT,
								[Description] [nvarchar](255) COLLATE DATABASE_DEFAULT,
								[AccountCategory] [nvarchar](50) COLLATE DATABASE_DEFAULT,
								[Parent] [nvarchar](50) COLLATE DATABASE_DEFAULT,
								[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT
								)

							INSERT INTO #Entity_AccountSourceCode
							(
								[Entity],							
								[MaskPosition],
								[MaskCharacters]
							)
							SELECT 
								EB.[Entity], 								
								JSN.[MaskPosition],
								JSN.[MaskCharacters]
							FROM 
								[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN
								INNER JOIN #EB EB ON EB.EntityID = JSN.EntityID and EB.Book = JSN.Book					
							WHERE													
								JSN.InstanceID = @InstanceID AND 
								JSN.VersionID =  @VersionID AND
								JSN.DimensionID = -1 AND  -- Account
								JSN.SelectYN <> 0 AND
								JSN.MaskPosition IS NOT NULL AND JSN.MaskCharacters IS NOT NULL 
						
							IF @DebugBM & 2 > 0 SELECT [Temp_Table] = '#Entity_AccountSourceCode', * FROM #Entity_AccountSourceCode

							IF @SequenceBMStep & 1 > 0 --Account Categories, Parent levels
								BEGIN
									--Account Categories
									SET @SQLStatement = '
										INSERT INTO #Account_Members_Raw
											(
											[MemberId],
											[MemberKey],
											[Description],
											[NodeTypeBM],
											[AccountCategory],
											[AccountType],
											[Rate],
											[Sign],
											[TimeBalance],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT DISTINCT
											[MemberId] = NULL,
											[MemberKey] = AC.[AccountCategory],
											[Description] = AC.[Description],
											[NodeTypeBM] = 18,
											[AccountCategory] = [AC].[AccountCategory],
											[AccountType] = [AC].[AccountType],
											[Rate] = [AT].[Rate],
											[Sign] = [AT].[Sign],
											[TimeBalance] = CONVERT(int, [AT].[TimeBalance]),
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = CASE WHEN [AT].TimeBalance = 0 THEN ''Income_Statement_'' ELSE ''Balance_Sheet_'' END,
											[Priority] = -999999,
											[Entity] = ''''
										FROM
											[#AccountCategory] AC  
											LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = AC.[AccountType]
										WHERE
											AC.[Source] = ''' + @SourceTypeName + ''''

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT

									IF @InstanceID = 515
										BEGIN
											--Major
											TRUNCATE TABLE #COA

											SET @SQLStatement = '
												INSERT INTO #COA
													(
													[MemberKey],
													[Description],
													[AccountCategory],
													[Parent],
													[Entity]
													)
												SELECT 
													[MemberKey] = SUBSTRING(account_no, 1, 4) COLLATE DATABASE_DEFAULT,
													[Description] = MAX([account_desc]) COLLATE DATABASE_DEFAULT,
													[AccountCategory] = MAX(account_type) COLLATE DATABASE_DEFAULT,
													[Parent] = MAX(account_type) COLLATE DATABASE_DEFAULT,
													[Entity] = [company_no] COLLATE DATABASE_DEFAULT
												FROM
													' + @SourceDatabase + '.[dbo].[chart_of_accts]
												GROUP BY
													SUBSTRING(account_no, 1, 4) COLLATE DATABASE_DEFAULT,
													[company_no] COLLATE DATABASE_DEFAULT'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
											IF @DebugBM & 2 > 0 SELECT TempTable = '#COA_1', * FROM #COA ORDER BY [Entity], [MemberKey]

											SET @SQLStatement = '
												INSERT INTO #Account_Members_Raw
													(
													[MemberId],
													[MemberKey],
													[Description],
													[NodeTypeBM],
													[AccountCategory],
													[AccountType],
													[Rate],
													[Sign],
													[TimeBalance],
													[Source],
													[Parent],
													[Priority],
													[Entity]
													)
												SELECT DISTINCT
													[MemberId] = NULL,
													[MemberKey] = COA.[MemberKey],
													[Description] = COA.[Description],
													[NodeTypeBM] = 18,
													[AccountCategory] = COA.[AccountCategory],
													[AccountType] = [AC].[AccountType],
													[Rate] = [AT].[Rate],
													[Sign] = [AT].[Sign],
													[TimeBalance] = CONVERT(int, [AT].[TimeBalance]),
													[Source] = ''' + @SourceTypeName + ''',
													[Parent] = COA.[Parent],
													[Priority] = EB.[Priority],
													[Entity] = EB.[Entity]
												FROM
													#COA COA
													INNER JOIN [#EB] EB ON EB.Entity = COA.Entity AND EB.Book = ''GL''
													LEFT JOIN [#AccountCategory] AC ON AC.[Source] = ''' + @SourceTypeName + ''' AND AC.AccountCategory = COA.AccountCategory 
													LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = AC.[AccountType]'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
											SET @Selected = @Selected + @@ROWCOUNT
										END
								
								END

							IF @SequenceBMStep & 2 > 0 --Account Leafs
								BEGIN
									IF @InstanceID = 515
										BEGIN
											--Minor
											TRUNCATE TABLE #COA

											SET @SQLStatement = '
												INSERT INTO #COA
													(
													[MemberKey],
													[Description],
													[AccountCategory],
													[Parent],
													[Entity]
													)
												SELECT 
													[MemberKey] = (SUBSTRING(account_no, 1, 4) + ''-'' + SUBSTRING(account_no, 5, 4)) COLLATE DATABASE_DEFAULT,
													[Description] = MAX([account_desc]) COLLATE DATABASE_DEFAULT,
													[AccountCategory] = MAX(account_type) COLLATE DATABASE_DEFAULT,
													[Parent] = MAX(SUBSTRING(account_no, 1, 4)) COLLATE DATABASE_DEFAULT,
													[Entity] = [company_no] COLLATE DATABASE_DEFAULT
												FROM
													' + @SourceDatabase + '.[dbo].[chart_of_accts]
												GROUP BY
													(SUBSTRING(account_no, 1, 4) + ''-'' + SUBSTRING(account_no, 5, 4)) COLLATE DATABASE_DEFAULT,
													[company_no] COLLATE DATABASE_DEFAULT'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
											IF @DebugBM & 2 > 0 SELECT TempTable = '#COA_2', * FROM #COA ORDER BY [Entity], [MemberKey]

											SET @SQLStatement = '
												INSERT INTO #Account_Members_Raw
													(
													[MemberId],
													[MemberKey],
													[Description],
													[NodeTypeBM],
													[AccountCategory],
													[AccountType],
													[Rate],
													[Sign],
													[TimeBalance],
													[Source],
													[Parent],
													[Priority],
													[Entity]
													)
												SELECT DISTINCT
													[MemberId] = NULL,
													[MemberKey] = COA.[MemberKey],
													[Description] = COA.[Description],
													[NodeTypeBM] = 1,
													[AccountCategory] = COA.[AccountCategory],
													[AccountType] = [AC].[AccountType],
													[Rate] = [AT].[Rate],
													[Sign] = [AT].[Sign],
													[TimeBalance] = CONVERT(int, [AT].[TimeBalance]),
													[Source] = ''' + @SourceTypeName + ''',
													[Parent] = COA.[Parent],
													[Priority] = EB.[Priority],
													[Entity] = EB.[Entity]
												FROM
													#COA COA
													INNER JOIN [#EB] EB ON EB.Entity = COA.Entity AND EB.Book = ''GL''
													LEFT JOIN [#AccountCategory] AC ON AC.[Source] = ''' + @SourceTypeName + ''' AND AC.AccountCategory = COA.AccountCategory 
													LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = AC.[AccountType]'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
											SET @Selected = @Selected + @@ROWCOUNT
										END
									ELSE
										BEGIN
											--Minor, Account Leafs
											TRUNCATE TABLE #COA

											SET @SQLStatement = '
												INSERT INTO #COA
													(
													[MemberKey],
													[Description],
													[AccountCategory],
													[Parent],
													[Entity]
													)
												SELECT 
													[MemberKey] = SUBSTRING(C.[account_no], EA.MaskPosition, EA.MaskCharacters),
													[Description] = MAX(C.[account_desc]) COLLATE DATABASE_DEFAULT,
													[AccountCategory] = MAX(C.[account_type]) COLLATE DATABASE_DEFAULT,
													[Parent] = MAX(C.[account_type]) COLLATE DATABASE_DEFAULT,
													[Entity] = C.[company_no] COLLATE DATABASE_DEFAULT
												FROM
													' + @SourceDatabase + '.[dbo].[chart_of_accts] C
													INNER JOIN [#Entity_AccountSourceCode] EA ON EA.Entity = C.[company_no]
												GROUP BY
													SUBSTRING(C.account_no, EA.MaskPosition, EA.MaskCharacters),														
													C.[company_no] COLLATE DATABASE_DEFAULT'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
											IF @DebugBM & 2 > 0 SELECT TempTable = '#COA', * FROM #COA ORDER BY [Entity], [MemberKey]

											SET @SQLStatement = '
												INSERT INTO #Account_Members_Raw
													(
													[MemberId],
													[MemberKey],
													[Description],
													[NodeTypeBM],
													[AccountCategory],
													[AccountType],
													[Rate],
													[Sign],
													[TimeBalance],
													[Source],
													[Parent],
													[Priority],
													[Entity]
													)
												SELECT DISTINCT
													[MemberId] = NULL,
													[MemberKey] = COA.[MemberKey],
													[Description] = COA.[Description],
													[NodeTypeBM] = 1,
													[AccountCategory] = COA.[AccountCategory],
													[AccountType] = [AC].[AccountType],
													[Rate] = [AT].[Rate],
													[Sign] = [AT].[Sign],
													[TimeBalance] = CONVERT(int, [AT].[TimeBalance]),
													[Source] = ''' + @SourceTypeName + ''',
													[Parent] = COA.[Parent],
													[Priority] = EB.[Priority],
													[Entity] = EB.[Entity]
												FROM
													#COA COA
													INNER JOIN [#EB] EB ON EB.Entity = COA.Entity AND EB.Book = ''GL''
													LEFT JOIN [#AccountCategory] AC ON AC.[Source] = ''' + @SourceTypeName + ''' AND AC.AccountCategory = COA.AccountCategory 
													LEFT JOIN [#AccountType] [AT] ON [AT].[AccountType] = AC.[AccountType]'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement) 
											SET @Selected = @Selected + @@ROWCOUNT
										END
								END
						END

					ELSE IF @SourceTypeID = 7 --SIE4
						BEGIN
							INSERT INTO #Account_Members_Raw
								(
								[MemberId],
								[MemberKey],
								[Description],
								[NodeTypeBM],
								[AccountCategory],
								[AccountType],
								[Rate],
								[Sign],
								[TimeBalance],
								[Source],
								[Parent],
								[Priority],
								[Entity]
								)
							SELECT
								[MemberId] = NULL,
								[MemberKey] = A.[MemberKey],
								[Description] = AD.[Description],
								[NodeTypeBM] = 1,
								[AccountCategory] = AAC.[AccountCategory],
								[AccountType] = AC.[AccountType],
								[Rate] = [AT].[Rate],
								[Sign] = [AT].[Sign],
								[TimeBalance] = [AT].[TimeBalance],
								[Source] = @SourceTypeName,
								[Parent] =	CASE AAC.[AccountCategory]
												WHEN 'T' THEN 'Assets_'
												WHEN 'S' THEN 'Equity_'
												WHEN 'K' THEN 'Expense_'
												WHEN 'I' THEN 'Gross_Profit_'
												WHEN '0' THEN 'Liabilities_'
												ELSE 'All_' END,
								[Priority] = 99999999,
								[Entity] = EB.Entity
							FROM
								#EB EB
								INNER JOIN 
									(
									SELECT DISTINCT
										[MemberKey] = [ObjectCode]
									FROM
										[SIE4_Object] O
									WHERE
										O.[InstanceID] = @InstanceID AND
										O.[JobID] = @JobID AND
										O.[Param] IN ('#KONTO', '#KTYP') AND
										O.[DimCode] = 'Account'
									) A ON 1=1
								LEFT JOIN 
									(
									SELECT DISTINCT
										[MemberKey] = [ObjectCode],
										[Description] = [ObjectName]
									FROM
										[SIE4_Object] O
									WHERE
										O.[InstanceID] = @InstanceID AND
										O.[JobID] = @JobID AND
										O.[Param] = '#KONTO' AND
										O.[DimCode] = 'Account'
									) AD ON AD.MemberKey = A.MemberKey
								LEFT JOIN 
									(
									SELECT DISTINCT
										[MemberKey] = [ObjectCode],
										[AccountCategory] = [ObjectName]							
									FROM
										[SIE4_Object] O
									WHERE
										O.[InstanceID] = @InstanceID AND
										O.[JobID] = @JobID AND
										O.[Param] = '#KTYP' AND
										O.[DimCode] = 'Account'
									) AAC ON AAC.MemberKey = A.MemberKey
								LEFT JOIN #AccountCategory AC ON AC.AccountCategory = AAC.[AccountCategory]
								LEFT JOIN #AccountType [AT] ON [AT].AccountType = AC.[AccountType]

							SET @Selected = @Selected + @@ROWCOUNT

						END

					--ELSE IF @SourceTypeID = 8 --Navision
					--	BEGIN
					--		SET @Message = 'Code for Navision is not yet implemented.'
					--		SET @Severity = 16
					--		GOTO EXITPOINT
					--	END

					--ELSE IF @SourceTypeID = 9 --Axapta
					--	BEGIN
					--		SET @Message = 'Code for Axapta is not yet implemented.'
					--		SET @Severity = 16
					--		GOTO EXITPOINT
					--	END

					--ELSE IF @SourceTypeID = 12 --Enterprise (E7)
					--	BEGIN
					--		SET @Message = 'Code for Enterprise (E7) is not yet implemented.'
					--		SET @Severity = 16
					--		GOTO EXITPOINT
					--	END

					--ELSE IF @SourceTypeID = 15 --pcSource
					--	BEGIN
					--		SET @Message = 'Code for pcSource is not yet implemented.'
					--		SET @Severity = 16
					--		GOTO EXITPOINT
					--	END

					--ELSE
					--	BEGIN
					--		SET @Message = 'Code for selected SourceTypeID (' + CONVERT(nvarchar(15), @SourceTypeID) + ') is not yet implemented.'
					--		SET @Severity = 16
					--		GOTO EXITPOINT
					--	END

					FETCH NEXT FROM Account_SourceType_Cursor INTO @SourceTypeID, @SourceTypeName, @SourceID, @Owner, @SourceDatabase
				END

		CLOSE Account_SourceType_Cursor
		DEALLOCATE Account_SourceType_Cursor

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				SELECT
					@ModelBM = SUM(ModelBM)
				FROM
					(SELECT DISTINCT ModelBM FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DEletedID IS NULL) sub
				
				IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@SourceTypeBM] = @SourceTypeBM, [@ModelBM] = @ModelBM

				INSERT INTO #Account_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[AccountCategory],
					[AccountType],
					[Rate],
					[Sign],
					[TimeBalance],
					[Source],
					[Parent],
					[Priority],
					[Entity]
					)
				SELECT 
					[MemberId] = M.[MemberId],
					[MemberKey] = MAX(M.[Label]),
					[Description] = MAX(REPLACE(M.[Description], '@All_Dimension', 'All Accounts')),
					[HelpText] = MAX(M.[HelpText]),
					[NodeTypeBM] = MAX(M.[NodeTypeBM]),
					[AccountCategory] = 'NONE',
					[AccountType] = ISNULL(MAX(CASE WHEN MPV.PropertyID = -4 THEN REPLACE(MPV.[Value], '''', '') END), 'Other'),
					[Rate] = ISNULL(MAX(CASE WHEN MPV.PropertyID = -5 THEN REPLACE(MPV.[Value], '''', '')  END), 'Average'),
					[Sign] = ISNULL(MAX(CASE WHEN MPV.PropertyID = -7 THEN REPLACE(MPV.[Value], '''', '')  END), '1'),
					[TimeBalance] = ISNULL(MAX(CASE WHEN MPV.PropertyID = -8 THEN REPLACE(MPV.[Value], '''', '')  END), '0'),
					[Source] = 'ETL',
					[Parent] = MAX(M.[Parent]),
					[Priority] = -999999,
					[Entity] = ''
				FROM 
					[Member] M
					LEFT JOIN [Member_Property_Value] MPV ON MPV.[DimensionID] = M.[DimensionID] AND MPV.[MemberId] = M.[MemberId]
				WHERE
					M.[DimensionID] IN (0, @DimensionID) AND
					M.[SourceTypeBM] & @SourceTypeBM > 0 AND
					M.[ModelBM] & @ModelBM > 0
				GROUP BY
					M.[MemberId]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Account_Members_Raw',
					*
				FROM
					#Account_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END, [Priority], [Entity]

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				IF CURSOR_STATUS('global','Account_Members_Cursor') >= -1 DEALLOCATE Account_Members_Cursor
				DECLARE Account_Members_Cursor CURSOR FOR
			
					SELECT DISTINCT
						[Entity],
						[Priority]
					FROM
						(
						SELECT DISTINCT
							[Entity] = '',
							[Priority] = -999999
						UNION SELECT DISTINCT
							[Entity],
							[Priority]
						FROM
							#EB
						) sub
					ORDER BY
						sub.[Priority],
						sub.[Entity]

					OPEN Account_Members_Cursor
					FETCH NEXT FROM Account_Members_Cursor INTO @Entity, @Priority

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@Priority] = @Priority

							INSERT INTO [#Account_Members]
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[AccountCategory],
								[AccountType],
								[Rate],
								[Sign],
								[TimeBalance],
								[MemberKeyBase],
								[Entity],
								[NodeTypeBM],
								[SBZ],
								[Source],
								[Synchronized],
								[Parent]
								)
							SELECT TOP 1000000
								[MemberId] = ISNULL([MaxRaw].[MemberId], M.MemberID),
								[MemberKey] = [MaxRaw].[MemberKey],
								[Description] = [MaxRaw].[Description],
								[HelpText] = CASE WHEN [MaxRaw].[HelpText] = '' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END,
								[AccountCategory] = [MaxRaw].[AccountCategory],
								[AccountType] = [MaxRaw].[AccountType],
								[Rate] = [MaxRaw].[Rate],
								[Sign] = [MaxRaw].[Sign],
								[TimeBalance] = [MaxRaw].[TimeBalance],
								[MemberKeyBase] = [MaxRaw].[MemberKeyBase],
								[Entity] = [MaxRaw].[Entity],
								[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
								[SBZ] = [MaxRaw].[SBZ],
								[Source] = [MaxRaw].[Source],
								[Synchronized] = 1,
								[Parent] = CASE [MaxRaw].[Parent] WHEN 'NULL' THEN NULL ELSE [MaxRaw].[Parent] END
							FROM
								(
								SELECT
									[MemberId] = MAX([Raw].[MemberId]),
									[MemberKey] = CASE WHEN @MappingTypeID = 1 AND @Entity <> '' THEN @Entity + '_' ELSE '' END + CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END + CASE WHEN @MappingTypeID = 2 AND @Entity <> '' THEN '_' + @Entity ELSE '' END,
									[Description] = MAX(CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedDescription] ELSE [Raw].[Description] END),
									[HelpText] = MAX([Raw].[HelpText]),
									[AccountCategory] = MAX([Raw].[AccountCategory]),
									[AccountType] = MAX([Raw].[AccountType]),
									[Rate] = MAX([Raw].[Rate]),
									[Sign] = MAX([Raw].[Sign]),
									[TimeBalance] = MAX([Raw].[TimeBalance]),
									[MemberKeyBase] = MAX([Raw].[MemberKey]),
									[Entity] = MAX([Raw].[Entity]),
									[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
									[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), MAX([Raw].[MemberKey])),
									[Source] = MAX([Raw].[Source]),
									[Synchronized] = 1,
									[Parent] = MAX([Raw].[Parent])
								FROM
									[#Account_Members_Raw] [Raw]
									LEFT JOIN #MappedMemberKey MMK ON MMK.[Entity] = [Raw].[Entity] AND [Raw].[MemberKey] BETWEEN MMK.[MemberKeyFrom] AND MMK.[MemberKeyTo]
								WHERE
									[Raw].[MemberKey] <> '' AND
									[Raw].[Entity] = @Entity AND
									[Raw].[Priority] = @Priority
								GROUP BY
									CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END
								) [MaxRaw]
								LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = @DimensionID AND M.[Label] = [MaxRaw].MemberKey
							WHERE
								[MaxRaw].[MemberKey] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [#Account_Members] AM WHERE AM.[MemberKey] = [MaxRaw].[MemberKey])
							ORDER BY
								CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

							FETCH NEXT FROM Account_Members_Cursor INTO @Entity, @Priority
						END

				CLOSE Account_Members_Cursor
				DEALLOCATE Account_Members_Cursor
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Account_Members_Raw
		DROP TABLE #MappedMemberKey
		DROP TABLE #AccountType
		DROP TABLE #AccountCategory
		DROP TABLE #EB
		DROP TABLE #TableName

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
