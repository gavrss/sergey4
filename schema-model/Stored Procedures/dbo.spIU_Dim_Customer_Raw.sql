SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Customer_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL, --Optional
	@SourceDatabase nvarchar(100) = NULL, --Optional
	@CallistoDatabase nvarchar(100) = NULL, --Optional
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN bit = 1,
	@MappingTypeID int = NULL,
	@StorageTypeBM int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000689,
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
EXEC [spIU_Dim_Customer_Raw] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @DebugBM = 2

EXEC [spIU_Dim_Customer_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceTypeName nvarchar(50),
	@SourceTypeBM int,
	@SQLStatement nvarchar(max),
	@SourceID int = 2018,
	@DimensionID int = -9,
	@ModelBM int,
	@Owner nvarchar(3),
	@Entity nvarchar(50),
	@Priority int,
	@AccountManager_MappingTypeID int,
	@CustomerCategory_MappingTypeID int,
	@Geography_MappingTypeID int,

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
			@ProcedureDescription = 'Get list of Customers from Source system',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2162' SET @Description = 'Updated handling of @SourceDatabase and @Entity. Added property Level.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.1.2170' SET @Description = 'Removed hardcoded SourceDatabase of [ShipTo] table - made generic.'
		IF @Version = '2.1.1.2173' SET @Description = 'Moved creation of temp tables #Customer and #Geography outside the loop.'
		IF @Version = '2.1.1.2174' SET @Description = 'Handle situation when SalesRepCode is blank, then set parent to ToBeSet.'
		IF @Version = '2.1.2.2199' SET @Description = 'Implement [dbo].[f_ReplaceString] function when setting [Description] property. Return empty string for NULL [Description] values. FEA-16178: Increased data type size of [SalesRepCode] in temp table #Customer from 8 to 15.'

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
				SourceTypeBM
			FROM
				SourceType ST
				INNER JOIN [Source] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.SourceTypeID = ST.SourceTypeID AND S.SelectYN <> 0
			) sub

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID),
			@StorageTypeBM = ISNULL(@StorageTypeBM, StorageTypeBM)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		SELECT
			@AccountManager_MappingTypeID = ISNULL(MAX(CASE WHEN DimensionID = -22 THEN MappingTypeID ELSE NULL END), 0),
			@CustomerCategory_MappingTypeID = ISNULL(MAX(CASE WHEN DimensionID = -13 THEN MappingTypeID ELSE NULL END), 0),
			@Geography_MappingTypeID = ISNULL(MAX(CASE WHEN DimensionID = -12 THEN MappingTypeID ELSE NULL END), 0)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID IN (-12, -13, -22)

		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.[DestinationDatabase], '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		IF OBJECT_ID(N'TempDB.dbo.#Customer_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@CalledYN] = @CalledYN,
				[@MappingTypeID] = @MappingTypeID,
				[@AccountManager_MappingTypeID] = @AccountManager_MappingTypeID,
				[@CustomerCategory_MappingTypeID] = @CustomerCategory_MappingTypeID,
				[@Geography_MappingTypeID] = @Geography_MappingTypeID

	SET @Step = 'Create temp table #Customer_Members_Raw'
		CREATE TABLE #Customer_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[MemberKeyBase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Level] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[AccountManager] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[CustomerCategory] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[Geography] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[PaymentDays] int,
			[SendTo] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Priority] int,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT
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

	SET @Step = 'Create #EB (Entity/Book)'
		SELECT DISTINCT
			[Entity] = E.[MemberKey],
			[EntityName] = E.[EntityName],
			[Priority] = CONVERT(int, ISNULL(E.[Priority], 999999999))
		INTO
			#EB
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.VersionID AND B.EntityID = E.EntityID AND B.SelectYN <> 0
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[SelectYN] <> 0 AND
			E.[DeletedID] IS NULL

		IF @DebugBM & 2 > 0 SELECT TempTable = '#EB', * FROM #EB

	SET @Step = 'Fill temptable #AccountManager_Members_Raw, Entity level'
		IF @MappingTypeID IN (1, 2)
			BEGIN
				INSERT INTO #Customer_Members_Raw
					(
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Level],
					[Source],
					[Parent],
					[Priority],
					[Entity]
					)
				SELECT DISTINCT
					[MemberKey] = 'Entity_' + E.[Entity],
					[Description] = E.[EntityName],
					[NodeTypeBM] = 18,
					[Level] = 'Entity',
					[Source] = 'ETL',
					[Parent] = 'All_',
					[Priority] = -999999,
					[Entity] = E.[Entity]
				FROM
					#EB E
			END

	SET @Step = 'Create Temp table #Customer'
		CREATE TABLE #Customer
			(
			[CustNum] int,
			[CustID] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[Name] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SalesRepCode] nvarchar(15) COLLATE DATABASE_DEFAULT,
			[GroupCode] nvarchar(4) COLLATE DATABASE_DEFAULT,
			[CountryNum] int,
			[TerritoryID] nvarchar(8) COLLATE DATABASE_DEFAULT,
			[PaymentDays] int,
			[Company] nvarchar(8) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create Temp table #Geography'
		CREATE TABLE #Geography
			(
			[Company] nvarchar(8) COLLATE DATABASE_DEFAULT,
			[CountryNum] int,
			[Country] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create CursorTable'
		CREATE TABLE #Customer_CursorTable
			(
			[SourceTypeID] int,
			[SourceTypeName] nvarchar(50),
			[Owner] nvarchar(3) COLLATE DATABASE_DEFAULT,
			[SourceDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #Customer_CursorTable
			(
			[SourceTypeID],
			[SourceTypeName],
			[Owner],
			[SourceDatabase]
			)
		SELECT DISTINCT
			[SourceTypeID] = S.[SourceTypeID],
			[SourceTypeName] = ST.[SourceTypeName],
			[Owner] = CASE WHEN S.[SourceTypeID] = 11 THEN 'Erp' ELSE 'dbo' END,
			[SourceDatabase] = '[' + REPLACE(REPLACE(REPLACE(ISNULL(@SourceDatabase, S.[SourceDatabase]), '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			pcINTEGRATOR_Data.dbo.[Source] S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SelectYN] <> 0 AND
			(S.[SourceTypeID] = @SourceTypeID OR @SourceTypeID IS NULL)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Customer_CursorTable', * FROM #Customer_CursorTable ORDER BY [SourceTypeID]		

	SET @Step = 'Fill temptable #Customer_Members_Raw by using #Customer_CursorTable'
		IF CURSOR_STATUS('global','Customer_SourceType_Cursor') >= -1 DEALLOCATE Customer_SourceType_Cursor
		DECLARE Customer_SourceType_Cursor CURSOR FOR
			
			SELECT 
				[SourceTypeID],
				[SourceTypeName],
				[Owner],
				[SourceDatabase]
			FROM
				#Customer_CursorTable
			ORDER BY
				[SourceTypeID]

			OPEN Customer_SourceType_Cursor
			FETCH NEXT FROM Customer_SourceType_Cursor INTO @SourceTypeID, @SourceTypeName, @Owner, @SourceDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@SourceTypeID] = @SourceTypeID, [@SourceTypeName] = @SourceTypeName, [@Owner] = @Owner, [@SourceDatabase] = @SourceDatabase

					IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10)
						BEGIN
							IF @SequenceBMStep & 1 > 0 --AccountManager, Parent levels
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Customer_Members_Raw
											(
											[MemberId],
											[MemberKey],
											[Description],
											[HelpText],
											[NodeTypeBM],
											[Level],
											[AccountManager],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT DISTINCT
											[MemberId] = NULL,
											[MemberKey] = ''AccountManager' + CASE WHEN @MappingTypeID IN (1, 2) THEN '_'' + EB.Entity' ELSE '''' END + ' + ''_'' + SR.[SalesRepCode],
											[Description] = SR.[Name],
											[HelpText] = '''',
											[NodeTypeBM] = 18,
											[Level] = ''AccountManager'',
											[AccountManager] = ' + CASE WHEN @AccountManager_MappingTypeID = 1 THEN 'EB.[Entity] + ''_'' + ' ELSE '' END + 'SR.[SalesRepCode]' + CASE WHEN @AccountManager_MappingTypeID = 2 THEN ' + ''_'' + EB.[Entity]' ELSE '' END + ',
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = ' + CASE WHEN @MappingTypeID IN (1, 2) THEN '''Entity_'' + EB.Entity' ELSE '''All_''' END + ',
											[Priority] = EB.[Priority],
											[Entity] = EB.Entity
										FROM
											' + @SourceDatabase + '.[' + @Owner + '].[SalesRep] SR
											INNER JOIN [#EB] EB ON EB.Entity = SR.Company COLLATE DATABASE_DEFAULT'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SET @Selected = @Selected + @@ROWCOUNT
								END

							--IF @SequenceBMStep & 1 > 0 --Customer Categories, Parent levels
							--	BEGIN
							--		SET @SQLStatement = '
							--			INSERT INTO #Customer_Members_Raw
							--				(
							--				[MemberKey],
							--				[Description],
							--				[NodeTypeBM],
							--				[CustomerCategory],
							--				[Source],
							--				[Parent],
							--				[Priority],
							--				[Entity]
							--				)
							--			SELECT DISTINCT
							--				[MemberKey] = CG.[GroupCode],
							--				[Description] = CG.[GroupDesc],
							--				[NodeTypeBM] = 1,
							--				[CustomerCategory] = ' + CASE WHEN @CustomerCategory_MappingTypeID = 1 THEN 'EB.[Entity] + ''_'' + ' ELSE '' END + 'CG.[GroupCode]' + CASE WHEN @CustomerCategory_MappingTypeID = 2 THEN ' + ''_'' + EB.[Entity]' ELSE '' END + ',
							--				[Source] = ''' + @SourceTypeName + ''',
							--				[Parent] = ' + CASE WHEN @MappingTypeID IN (1, 2) THEN '''E_'' + EB.Entity' ELSE '''All_''' END + ',
							--				[Priority] = EB.[Priority],
							--				[Entity] = EB.[Entity]
							--			FROM
							--				' + @SourceDatabase + '.[' + @Owner + '].[CustGrup] CG
							--				INNER JOIN #EB EB ON EB.Entity = CG.Company COLLATE DATABASE_DEFAULT AND EB.Entity = CG.Company COLLATE DATABASE_DEFAULT'

							--		IF @DebugBM & 2 > 0 PRINT @SQLStatement
							--		EXEC (@SQLStatement)

							--		SET @Selected = @Selected + @@ROWCOUNT
							--	END


							IF @SequenceBMStep & 14 > 0 --Customer and ShipTo
								BEGIN
									TRUNCATE TABLE #Customer

									SET @SQLStatement = '
									INSERT INTO #Customer
										(
										[CustNum],
										[CustID],
										[Name],
										[SalesRepCode],
										[GroupCode],
										[CountryNum],
										[TerritoryID],
										[PaymentDays],
										[Company]
										)
									SELECT DISTINCT
										[CustNum] = [Cu].[CustNum],
										[CustID] = LTRIM(RTRIM([Cu].[CustID])),
										[Name] = [Cu].[Name],
										[SalesRepCode] = [Cu].[SalesRepCode],
										[GroupCode] = [Cu].[GroupCode],
										[CountryNum] = [Cu].[CountryNum],
										[TerritoryID] = REPLACE([Cu].[TerritoryID], '' '', ''_''),
										[PaymentDays] = ISNULL([T].[NumberOfDays], 0),
										[Company] = [Cu].Company
									FROM
										' + @SourceDatabase + '.[' + @Owner + '].[Customer] [Cu]
										INNER JOIN #EB EB ON EB.Entity = [Cu].Company COLLATE DATABASE_DEFAULT
										LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[Terms] [T] ON [T].[Company] = [Cu].[Company] AND [T].[TermsCode] = [Cu].[TermsCode]'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									IF @DebugBM & 2 > 0 SELECT TempTable = '#Customer', * FROM #Customer ORDER BY CustID

									TRUNCATE TABLE #Geography									

									SET @SQLStatement = '
									INSERT INTO #Geography
										(
										[Company],
										[CountryNum],
										[Country]
										)

									SELECT 
										C.Company,
										C.CountryNum, 
										Country = COALESCE(MAX(M1.Label), MAX(M2.Label), ''00'')
									FROM 
										' + @SourceDatabase + '.[' + @Owner + '].[Country] C
										INNER JOIN #EB EB ON EB.Entity = [C].Company COLLATE DATABASE_DEFAULT
										LEFT JOIN pcINTEGRATOR..Member M1 ON M1.DimensionID = -12 AND M1.Label = C.ISOCode COLLATE DATABASE_DEFAULT
										LEFT JOIN pcINTEGRATOR..Member M2 ON M2.DimensionID = -12 AND M2.[Description] = C.[Description] COLLATE DATABASE_DEFAULT
									GROUP BY
										C.Company,
										C.CountryNum'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									IF @DebugBM & 2 > 0 SELECT TempTable = '#Geography', * FROM #Geography
								END

							IF @SequenceBMStep & 2 > 0 --Customer Parents
								BEGIN
									INSERT INTO #Customer_Members_Raw
										(
										[MemberId],
										[MemberKey],
										[Description],
										[HelpText],
										[MemberKeyBase],
										[NodeTypeBM],
										[Level],
										[AccountManager],
										[CustomerCategory],
										[Geography],
										[PaymentDays],
										[SendTo],
										[Source],
										[Parent],
										[Priority],
										[Entity]
										)
									SELECT DISTINCT
										[MemberId] = NULL,
										[MemberKey] = CASE WHEN @MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + C.[CustID] + CASE WHEN @MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END + '_',
										[Description] = C.[Name],
										[HelpText] = '',
										[MemberKeyBase] = C.[CustID],
										[NodeTypeBM] = 18,
										[Level] = 'ParentCustomer',
										[AccountManager] = CASE WHEN @AccountManager_MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + C.[SalesRepCode] + CASE WHEN @AccountManager_MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END,
										[CustomerCategory] = CASE WHEN @CustomerCategory_MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + [GroupCode] + CASE WHEN @CustomerCategory_MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END,
										[Geography] = CASE WHEN @Geography_MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + ISNULL(G.[Country], '00') + '_' + C.[TerritoryID] + CASE WHEN @Geography_MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END,
										[PaymentDays] = [PaymentDays],
										[SendTo] = CASE WHEN @MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + C.[CustID] + CASE WHEN @MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END,
										[Source] = @SourceTypeName,
										[Parent] = CASE WHEN C.[SalesRepCode] IS NULL OR C.[SalesRepCode] = '' THEN 'ToBeSet' ELSE 'AccountManager' + CASE WHEN @MappingTypeID IN (1, 2) THEN '_' + EB.Entity ELSE '' END + '_' + C.[SalesRepCode] END,
										[Priority] = EB.[Priority],
										[Entity] = EB.Entity
									FROM
										#Customer C
										INNER JOIN [#EB] EB ON EB.Entity = C.Company COLLATE DATABASE_DEFAULT
										LEFT JOIN [#Geography] G ON G.Company = C.Company AND G.CountryNum = C.CountryNum

									SET @Selected = @Selected + @@ROWCOUNT
								END

							IF @SequenceBMStep & 4 > 0 --Customer Leafs
								BEGIN
									INSERT INTO #Customer_Members_Raw
										(
										[MemberId],
										[MemberKey],
										[Description],
										[HelpText],
										[MemberKeyBase],
										[NodeTypeBM],
										[Level],
										[AccountManager],
										[CustomerCategory],
										[Geography],
										[PaymentDays],
										[SendTo],
										[Source],
										[Parent],
										[Priority],
										[Entity]
										)
									SELECT DISTINCT
										[MemberId] = NULL,
										[MemberKey] = CASE WHEN @MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + C.[CustID] + CASE WHEN @MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END,
										[Description] = [Name],
										[HelpText] = '',
										[MemberKeyBase] = C.[CustID],
										[NodeTypeBM] = 1,
										[Level] = 'Customer',
										[AccountManager] = CASE WHEN @AccountManager_MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + C.[SalesRepCode] + CASE WHEN @AccountManager_MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END,
										[CustomerCategory] = CASE WHEN @CustomerCategory_MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + C.[GroupCode] + CASE WHEN @CustomerCategory_MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END,
										[Geography] = CASE WHEN @Geography_MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + ISNULL(G.[Country], '00') + '_' + C.[TerritoryID] + CASE WHEN @Geography_MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END,
										[PaymentDays] = [PaymentDays],
										[SendTo] = CASE WHEN @MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + C.[CustID] + CASE WHEN @MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END,
										[Source] = @SourceTypeName,
										[Parent] = CASE WHEN @MappingTypeID = 1 THEN EB.[Entity] + '_' ELSE '' END + C.[CustID] + CASE WHEN @MappingTypeID = 2 THEN '_' + EB.[Entity] ELSE '' END + '_',
										[Priority] = EB.[Priority],
										[Entity] = EB.Entity
									FROM
										#Customer C
										INNER JOIN [#EB] EB ON EB.Entity = C.Company COLLATE DATABASE_DEFAULT
										LEFT JOIN [#Geography] G ON G.Company = C.Company AND G.CountryNum = C.CountryNum
									
									SET @Selected = @Selected + @@ROWCOUNT
								END

							IF @SequenceBMStep & 8 > 0 --ShipTo
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Customer_Members_Raw
											(
											[MemberId],
											[MemberKey],
											[Description],
											[HelpText],
											[MemberKeyBase],
											[NodeTypeBM],
											[Level],
											[AccountManager],
											[CustomerCategory],
											[Geography],
											[PaymentDays],
											[SendTo],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT DISTINCT
											[MemberId] = NULL,
											[MemberKey] = ' + CASE WHEN @MappingTypeID = 1 THEN 'EB.[Entity] + ''_'' + ' ELSE '' END + '[C].[CustID] + ''_'' + ST.[ShipToNum]' + CASE WHEN @MappingTypeID = 2 THEN ' + ''_'' + EB.[Entity]' ELSE '' END + ',
											[Description] = REPLACE([ST].[Name], ''('' + ST.ShipToNum + '') '', '''') + '' - ('' + ST.ShipToNum + '')'',
											[HelpText] = '''',
											[MemberKeyBase] = C.[CustID],
											[NodeTypeBM] = 1,
											[Level] = ''Customer'',
											[AccountManager] = ' + CASE WHEN @AccountManager_MappingTypeID = 1 THEN 'EB.[Entity] + ''_'' + ' ELSE '' END + 'ST.[SalesRepCode]' + CASE WHEN @AccountManager_MappingTypeID = 2 THEN ' + ''_'' + EB.[Entity]' ELSE '' END + ',
											[CustomerCategory] = ' + CASE WHEN @CustomerCategory_MappingTypeID = 1 THEN 'EB.[Entity] + ''_'' + ' ELSE '' END + 'C.[GroupCode]' + CASE WHEN @CustomerCategory_MappingTypeID = 2 THEN ' + ''_'' + EB.[Entity]' ELSE '' END + ',
											[Geography] = ' + CASE WHEN @Geography_MappingTypeID = 1 THEN 'EB.[Entity] + ''_'' + ' ELSE '' END + 'ISNULL(G.[Country], ''00'') + ''_'' + ST.[TerritoryID]' + CASE WHEN @Geography_MappingTypeID = 2 THEN ' + ''_'' + EB.[Entity]' ELSE '' END + ',
											[PaymentDays] = C.[PaymentDays],
											[SendTo] = ' + CASE WHEN @MappingTypeID = 1 THEN 'EB.[Entity] + ''_'' + ' ELSE '' END + '[C].[CustID] + ''_'' + ST.[ShipToNum]' + CASE WHEN @MappingTypeID = 2 THEN ' + ''_'' + EB.[Entity]' ELSE '' END + ',
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = ' + CASE WHEN @MappingTypeID = 1 THEN 'EB.[Entity] + ''_'' + ' ELSE '' END + '[C].[CustID]' + CASE WHEN @MappingTypeID = 2 THEN ' + ''_'' + EB.[Entity]' ELSE '' END + ' + ''_''' + ',
											[Priority] = EB.[Priority],
											[Entity] = EB.Entity
										FROM
											[#Customer] [C]
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[ShipTo] [ST] ON ST.Company = C.Company AND ST.CustNum = C.CustNum AND ST.ShipToNum <> ''''
											INNER JOIN [#EB] EB ON EB.Entity = C.Company COLLATE DATABASE_DEFAULT
											LEFT JOIN [#Geography] G ON G.Company = ST.Company AND G.CountryNum = ST.CountryNum'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SET @Selected = @Selected + @@ROWCOUNT
								END
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

					FETCH NEXT FROM Customer_SourceType_Cursor INTO @SourceTypeID, @SourceTypeName, @Owner, @SourceDatabase
				END

		CLOSE Customer_SourceType_Cursor
		DEALLOCATE Customer_SourceType_Cursor

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				SELECT
					@ModelBM = SUM(ModelBM)
				FROM
					(SELECT DISTINCT ModelBM FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DEletedID IS NULL) sub
				
				IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@SourceTypeBM] = @SourceTypeBM, [@ModelBM] = @ModelBM

				INSERT INTO #Customer_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Level],
					[CustomerCategory],
					[Source],
					[Parent],
					[Priority],
					[Entity]
					)
				SELECT 
					[MemberId] = M.[MemberId],
					[MemberKey] = MAX(M.[Label]),
					[Description] = MAX(REPLACE(M.[Description], '@All_Dimension', 'All Customers')),
					[HelpText] = MAX(M.[HelpText]),
					[NodeTypeBM] = MAX(M.[NodeTypeBM]),
					[Level] = CASE WHEN MAX(M.[Label]) = 'All_' THEN 'TopNode' END,
					[CustomerCategory] = 'NONE',
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
		IF @CalledYN = 0 OR @DebugBM & 2 > 0
			BEGIN
				SELECT
					TempTable = '#Customer_Members_Raw',
					*
				FROM
					#Customer_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END, [Priority], [Entity]

				SET @Selected = @@ROWCOUNT
			END
		
		IF @CalledYN <> 0
			BEGIN
				SELECT DISTINCT
					[Entity],
					[Priority]
				INTO
					#Customer_Members_Cursor_Table
				FROM
					[#Customer_Members_Raw]
				ORDER BY
					[Priority],
					[Entity]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Customer_Members_Cursor_Table', * FROM #Customer_Members_Cursor_Table ORDER BY [Priority], [Entity]

				IF CURSOR_STATUS('global','Customer_Members_Cursor') >= -1 DEALLOCATE Customer_Members_Cursor
				DECLARE Customer_Members_Cursor CURSOR FOR
			
					SELECT DISTINCT
						[Entity],
						[Priority]
					FROM
						#Customer_Members_Cursor_Table
					ORDER BY
						[Priority],
						[Entity]

					OPEN Customer_Members_Cursor
					FETCH NEXT FROM Customer_Members_Cursor INTO @Entity, @Priority

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@Priority] = @Priority

							INSERT INTO [#Customer_Members]
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[MemberKeyBase],
								[Entity],
								[NodeTypeBM],
								[Level],
								[AccountManager],
								[CustomerCategory],
								[Geography],
								[PaymentDays],
								[SendTo],
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
								[MemberKeyBase] = [MaxRaw].[MemberKeyBase],
								[Entity] = @Entity,
								[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
								[Level] = [MaxRaw].[Level],
								[AccountManager] = [MaxRaw].[AccountManager],
								[CustomerCategory] = [MaxRaw].[CustomerCategory],
								[Geography] = [MaxRaw].[Geography],
								[PaymentDays] = [MaxRaw].[PaymentDays],
								[SendTo] = [MaxRaw].[SendTo],
								[SBZ] = [MaxRaw].[SBZ],
								[Source] = [MaxRaw].[Source],
								[Synchronized] = 1,
								[Parent] = CASE [MaxRaw].[Parent] WHEN 'NULL' THEN NULL ELSE [MaxRaw].[Parent] END
							FROM
								(
								SELECT
									[MemberId] = MAX([Raw].[MemberId]),
									[MemberKey] = CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END,
									--[Description] = MAX(CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedDescription] ELSE [Raw].[Description] END),
									[Description] = ISNULL([dbo].[f_ReplaceString] (@InstanceID, @VersionID, MAX(CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedDescription] ELSE [Raw].[Description] END), 2), ''),
									[HelpText] = MAX([Raw].[HelpText]),
									[MemberKeyBase] = MAX([Raw].[MemberKeyBase]),
									[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
									[Level] = MAX([Raw].[Level]),
									[AccountManager] = MAX([Raw].[AccountManager]),
									[CustomerCategory] = MAX([Raw].[CustomerCategory]),
									[Geography] = MAX([Raw].[Geography]),
									[PaymentDays] = MAX([Raw].[PaymentDays]),
									[SendTo] = MAX([Raw].[SendTo]),
									[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), MAX([Raw].[MemberKey])),
									[Source] = MAX([Raw].[Source]),
									[Synchronized] = 1,
									[Parent] = MAX([Raw].[Parent])
								FROM
									[#Customer_Members_Raw] [Raw]
									LEFT JOIN #MappedMemberKey MMK ON MMK.[Entity] = [Raw].[Entity] AND [Raw].[MemberKey] BETWEEN MMK.[MemberKeyFrom] AND MMK.[MemberKeyTo]
								WHERE
									[Raw].[Entity] = @Entity AND
									[Raw].[Priority] = @Priority
								GROUP BY
									CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END
								) [MaxRaw]
								LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = @DimensionID AND M.[Label] = [MaxRaw].MemberKey
							WHERE
								[MaxRaw].[MemberKey] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [#Customer_Members] AM WHERE AM.[MemberKey] = [MaxRaw].[MemberKey])
							ORDER BY
								CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

							FETCH NEXT FROM Customer_Members_Cursor INTO @Entity, @Priority
						END

				CLOSE Customer_Members_Cursor
				DEALLOCATE Customer_Members_Cursor
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Customer_Members_Raw
		DROP TABLE #MappedMemberKey
		DROP TABLE #EB
		IF @CalledYN <> 0 DROP TABLE #Customer_Members_Cursor_Table

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
