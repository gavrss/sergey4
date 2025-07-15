SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_OrderNo_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -16, 
	@SourceTypeID int = NULL,
	@SourceID int = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@SequenceBMStep int = 65535, --8 = Leaf level
	@StaticMemberYN bit = 1,
	@MappingTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000720,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*

EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_OrderNo_Raw] @DebugBM='15',@DimensionID='-16',@InstanceID='637',@UserID='-10',@VersionID='1111'


EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_OrderNo_Raw] @DebugBM='15',@DimensionID='-16',@InstanceID='595'
,@MappingTypeID='1',@SequenceBMStep='65535',@StaticMemberYN='1',@UserID='-10',@VersionID='1086'

EXEC [spIU_Dim_OrderNo_Raw] @UserID = -10, @InstanceID = -1088, @VersionID = -1085, @SourceTypeID = 11, @DebugBM = 3
EXEC [spIU_Dim_OrderNo_Raw] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @SourceTypeID = 11, @DebugBM = 3, @SourceDatabase = 'DSPSOURCE01.CCM_E10'
EXEC [spIU_Dim_OrderNo_Raw] @DimensionID='-16',@InstanceID='531',@MappingTypeID='1',@SequenceBMStep='65535',@StaticMemberYN='1',@UserID='-10',@VersionID='1041',@Debug='1'

EXEC [spIU_Dim_OrderNo_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceTypeName nvarchar(50),
	@SourceTypeBM int,
	@SQLStatement nvarchar(max),
	@DimensionName nvarchar(50),
	@Owner nvarchar(3),
	@ModelBM int,
	@Step_ProcedureName nvarchar(100),
	@Entity nvarchar(50),
	@Priority int,
	@StartYear int,
	@ETLDatabase nvarchar(100),
	@SourceID_Sales int,

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
	@Version nvarchar(50) = '2.1.2.2198'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get OrderNos from Source system',
			@MandatoryParameter = 'DimensionID' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed default Priority to 99999999.'
		IF @Version = '2.1.2.2179' SET @Description = 'Loop on multiple sources.'
		IF @Version = '2.1.2.2190' SET @Description = 'Modified query on #OrderNo_Members_Raw, Entity level.'
		IF @Version = '2.1.2.2198' SET @Description = 'Added parent level (Entity) for MappingType = 0.'
		
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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@DimensionName = DimensionName
		FROM
			pcINTEGRATOR.dbo.[Dimension]
		WHERE
			InstanceID IN (0, @InstanceID) AND
			DimensionID = @DimensionID

		SELECT 
			@ETLDatabase = ETLDatabase
		FROM 
			[Application] 
		WHERE
			InstanceID = @InstanceID AND
            VersionID = @VersionID AND
            SelectYN <> 0

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF OBJECT_ID(N'TempDB.dbo.#OrderNo_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT 
				[@InstanceID]=@InstanceID,
				[@VersionID]=@VersionID,
				[@DimensionID]=@DimensionID,
				[@DimensionName]=@DimensionName,
				[@SourceTypeID]=@SourceTypeID,
				[@SourceTypeBM]=@SourceTypeBM,
				[@SourceDatabase]=@SourceDatabase,
				[@MappingTypeID]=@MappingTypeID,
				[@CalledYN]=@CalledYN

	SET @Step = 'Create #EB (Entity/Book)'
		IF OBJECT_ID(N'TempDB.dbo.#EB', N'U') IS NULL
			BEGIN
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
			END

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

	SET @Step = 'Create temp table #OrderNo_Members_Raw'
		CREATE TABLE #OrderNo_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Priority] int,
			[MemberKeyBase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Fill temptable #OrderNo_Members_Raw, Entity level'
		IF @MappingTypeID IN (0, 1, 2)
			BEGIN
				INSERT INTO #OrderNo_Members_Raw
					(
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Source],
					[Parent],
					[Priority],
					[Entity]
					)
				SELECT DISTINCT
					[MemberKey] = E.[Entity],
					[Description] = E.[EntityName],
					[NodeTypeBM] = 18,
					[Source] = 'ETL',
					[Parent] = 'All_',
					[Priority] = E.[Priority],
					[Entity] = E.[Entity]
				FROM
					#EB E
			END

	SET @Step = 'Create cursor table'
		CREATE TABLE #OrderNo_Cursor_table
			(
			SourceTypeID int,
			SourceDatabase nvarchar(100) COLLATE DATABASE_DEFAULT,
			StartYear int
			)

		INSERT INTO #OrderNo_Cursor_table
			(
			SourceTypeID,
			SourceDatabase,
			StartYear
			)
		SELECT DISTINCT
			S.SourceTypeID,
			S.SourceDatabase,
			StartYear = MIN(S.StartYear)
		FROM
			pcINTEGRATOR_Data..[Model] M
			INNER JOIN pcINTEGRATOR_Data..[Source] S ON 
				S.InstanceID = M.InstanceID AND
				S.VersionID = M.VersionID AND
				(S.[SourceTypeID] = @SourceTypeID OR @SourceTypeID IS NULL) AND
				(S.[SourceID] = @SourceID OR @SourceID IS NULL) AND
				(S.[SourceDatabase] = @SourceDatabase OR @SourceDatabase IS NULL) AND
				S.ModelID = M.ModelID AND
				S.SelectYN <> 0
		WHERE
			M.InstanceID = @InstanceID AND
			M.VersionID = @VersionID AND
			M.ModelBM & 8 > 0 AND --Sales
			M.SelectYN <> 0
		GROUP BY
			S.SourceTypeID,
			S.SourceDatabase

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#OrderNo_Cursor_table', * FROM #OrderNo_Cursor_table

	--SET @Step = 'Insert Entity level'
	--	IF @SequenceBMStep & 1 > 0 AND @MappingTypeID IN (1, 2) --Parent
	--		BEGIN
	--			SET @SQLStatement = '
	--				INSERT INTO #OrderNo_Members_Raw
	--					(
	--					[MemberId],
	--					[MemberKey],
	--					[Description],
	--					[HelpText],
	--					[NodeTypeBM],
	--					[Source],
	--					[Parent],
	--					[Priority],
	--					[MemberKeyBase],
	--					[Entity]
	--					)
	--				SELECT DISTINCT
	--					[MemberId] = NULL,
	--					[MemberKey] = EB.Entity,
	--					[Description] = EB.EntityName,
	--					[HelpText] = '''',
	--					[NodeTypeBM] = 2,
	--					[Source] = ''' + @SourceTypeName + ''',								
	--					[Parent] = ''All_'',
	--					[Priority] = EB.[Priority],
	--					[MemberKeyBase] = EB.[Entity],
	--					[Entity] = EB.Entity
	--				FROM
	--					' + @SourceDatabase + '.[' + @Owner + '].[OrderHed] OH
	--					INNER JOIN [#EB] EB ON EB.Entity = OH.Company COLLATE DATABASE_DEFAULT'

	--			IF @DebugBM & 2 > 0 PRINT @SQLStatement
	--			EXEC (@SQLStatement)
	--			SET @Selected = @Selected + @@ROWCOUNT
	--		END

	SET @Step = 'OrderNo_Cursor'
		IF CURSOR_STATUS('global','OrderNo_Cursor') >= -1 DEALLOCATE OrderNo_Cursor
		DECLARE OrderNo_Cursor CURSOR FOR
			
			SELECT 
				SourceTypeID,
				SourceDatabase,
				StartYear
			FROM
				#OrderNo_Cursor_table
			ORDER BY
				SourceTypeID,
				SourceDatabase

			OPEN OrderNo_Cursor
			FETCH NEXT FROM OrderNo_Cursor INTO @SourceTypeID, @SourceDatabase, @StartYear

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT
						@SourceTypeName = [SourceTypeName],
						@SourceTypeBM = [SourceTypeBM],
						@Owner = [Owner]
					FROM
						SourceType
					WHERE
						SourceTypeID = @SourceTypeID
					
					IF @DebugBM & 2 > 0 SELECT [@SourceTypeID]=@SourceTypeID, [@SourceTypeName] = @SourceTypeName, [@SourceTypeBM] = @SourceTypeBM, [@Owner] = @Owner, [@SourceDatabase]=@SourceDatabase, [@StartYear]=@StartYear
					
					SET @Step = 'Fill temptable #OrderNo_Members_Raw'
						IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10)
							BEGIN

								IF @SequenceBMStep & 2 > 0 --Parent
									BEGIN
										SET @SQLStatement = '
											INSERT INTO #OrderNo_Members_Raw
												(
												[MemberId],
												[MemberKey],
												[Description],
												[HelpText],
												[NodeTypeBM],
												[Source],
												[Parent],
												[Priority],
												[Entity]
												)
											SELECT DISTINCT
												[MemberId] = NULL,
												--[MemberKey] = CASE LEN(OH.[OrderNum] / 10000) WHEN 1 THEN ''00'' WHEN 2 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 10000) COLLATE DATABASE_DEFAULT,
												[MemberKey] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CASE LEN(OH.[OrderNum] / 10000) WHEN 1 THEN ''00'' WHEN 2 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 10000) COLLATE DATABASE_DEFAULT + CASE WHEN (SELECT CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) THEN 1 ELSE ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' END) = 2 AND EB.Entity <> '''' THEN ''_'' + EB.Entity ELSE '''' END,
												[Description] = CASE LEN(OH.[OrderNum] / 10000) WHEN 1 THEN ''00'' WHEN 2 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 10000) COLLATE DATABASE_DEFAULT,
												[HelpText] = '''',
												[NodeTypeBM] = 2,
												[Source] = ''' + @SourceTypeName + ''',								
												[Parent] = EB.Entity,
												[Priority] = EB.[Priority],
												[Entity] = EB.Entity
											FROM
												' + @SourceDatabase + '.[' + @Owner + '].[OrderHed] OH
												INNER JOIN [#EB] EB ON EB.Entity = OH.Company COLLATE DATABASE_DEFAULT
											WHERE
												NOT EXISTS (SELECT 1 FROM #OrderNo_Members_Raw R WHERE R.[MemberKey] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CASE LEN(OH.[OrderNum] / 10000) WHEN 1 THEN ''00'' WHEN 2 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 10000) COLLATE DATABASE_DEFAULT + CASE WHEN (SELECT CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) THEN 1 ELSE ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' END) = 2 AND EB.Entity <> '''' THEN ''_'' + EB.Entity ELSE '''' END)'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Selected = @Selected + @@ROWCOUNT
									END

								IF @SequenceBMStep & 4 > 0 --Parent
									BEGIN
										SET @SQLStatement = '
											INSERT INTO #OrderNo_Members_Raw
												(
												[MemberId],
												[MemberKey],
												[Description],
												[HelpText],
												[NodeTypeBM],
												[Source],
												[Parent],
												[Priority],
												[Entity]
												)
											SELECT DISTINCT
												[MemberId] = NULL,
												--[MemberKey] = CASE LEN(OH.[OrderNum] / 100) WHEN 1 THEN ''0000'' WHEN 2 THEN ''000'' WHEN 3 THEN ''00'' WHEN 4 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 100) COLLATE DATABASE_DEFAULT,
												[MemberKey] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CASE LEN(OH.[OrderNum] / 100) WHEN 1 THEN ''0000'' WHEN 2 THEN ''000'' WHEN 3 THEN ''00'' WHEN 4 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 100) COLLATE DATABASE_DEFAULT + CASE WHEN (SELECT CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) THEN 1 ELSE ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' END) = 2 AND EB.Entity <> '''' THEN ''_'' + EB.Entity ELSE '''' END,
												[Description] = CASE LEN(OH.[OrderNum] / 100) WHEN 1 THEN ''0000'' WHEN 2 THEN ''000'' WHEN 3 THEN ''00'' WHEN 4 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 100) COLLATE DATABASE_DEFAULT,
												[HelpText] = '''',
												[NodeTypeBM] = 2,
												[Source] = ''' + @SourceTypeName + ''',
												[Parent] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CASE LEN(OH.[OrderNum] / 10000) WHEN 1 THEN ''00'' WHEN 2 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 10000) COLLATE DATABASE_DEFAULT + CASE WHEN (SELECT CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) THEN 1 ELSE ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' END) = 2 AND EB.Entity <> '''' THEN ''_'' + EB.Entity ELSE '''' END,
												[Priority] = EB.[Priority],
												[Entity] = EB.Entity
											FROM
												' + @SourceDatabase + '.[' + @Owner + '].[OrderHed] OH
												INNER JOIN [#EB] EB ON EB.Entity = OH.Company COLLATE DATABASE_DEFAULT
											WHERE
												NOT EXISTS (SELECT 1 FROM #OrderNo_Members_Raw R WHERE R.[MemberKey] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CASE LEN(OH.[OrderNum] / 100) WHEN 1 THEN ''0000'' WHEN 2 THEN ''000'' WHEN 3 THEN ''00'' WHEN 4 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 100) COLLATE DATABASE_DEFAULT + CASE WHEN (SELECT CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) THEN 1 ELSE ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' END) = 2 AND EB.Entity <> '''' THEN ''_'' + EB.Entity ELSE '''' END)'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Selected = @Selected + @@ROWCOUNT
									END

								IF @SequenceBMStep & 8 > 0 --Leaf
									BEGIN
										SET @SQLStatement = '
											INSERT INTO #OrderNo_Members_Raw
												(
												[MemberId],
												[MemberKey],
												[Description],
												[HelpText],
												[NodeTypeBM],
												[Source],
												[Parent],
												[Priority],
												[MemberKeyBase],
												[Entity]
												)
											SELECT DISTINCT
												[MemberId] = NULL,
												--[MemberKey] = CASE LEN(OH.[OrderNum]) WHEN 1 THEN ''000000'' WHEN 2 THEN ''00000'' WHEN 3 THEN ''0000'' WHEN 4 THEN ''000'' WHEN 5 THEN ''00'' WHEN 6 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum) COLLATE DATABASE_DEFAULT,
												[MemberKey] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CASE LEN(OH.[OrderNum]) WHEN 1 THEN ''000000'' WHEN 2 THEN ''00000'' WHEN 3 THEN ''0000'' WHEN 4 THEN ''000'' WHEN 5 THEN ''00'' WHEN 6 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum) COLLATE DATABASE_DEFAULT + CASE WHEN (SELECT CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) THEN 1 ELSE ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' END) = 2 AND EB.Entity <> '''' THEN ''_'' + EB.Entity ELSE '''' END,
												[Description] = CASE LEN(OH.[OrderNum]) WHEN 1 THEN ''000000'' WHEN 2 THEN ''00000'' WHEN 3 THEN ''0000'' WHEN 4 THEN ''000'' WHEN 5 THEN ''00'' WHEN 6 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum) COLLATE DATABASE_DEFAULT,
												[HelpText] = '''',
												[NodeTypeBM] = 1,
												[Source] = ''' + @SourceTypeName + ''',
												[Parent] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CASE LEN(OH.[OrderNum] / 100) WHEN 1 THEN ''0000'' WHEN 2 THEN ''000'' WHEN 3 THEN ''00'' WHEN 4 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum / 100) COLLATE DATABASE_DEFAULT + CASE WHEN (SELECT CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) THEN 1 ELSE ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' END) = 2 AND EB.Entity <> '''' THEN ''_'' + EB.Entity ELSE '''' END,
												[Priority] = EB.[Priority],
												[MemberKeyBase] = CONVERT(nvarchar(255), OH.OrderNum),
												[Entity] = EB.Entity
											FROM
												' + @SourceDatabase + '.[' + @Owner + '].[OrderHed] OH
												INNER JOIN [#EB] EB ON EB.Entity = OH.Company COLLATE DATABASE_DEFAULT
											WHERE
												NOT EXISTS (SELECT 1 FROM #OrderNo_Members_Raw R WHERE R.[MemberKey] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CASE LEN(OH.[OrderNum]) WHEN 1 THEN ''000000'' WHEN 2 THEN ''00000'' WHEN 3 THEN ''0000'' WHEN 4 THEN ''000'' WHEN 5 THEN ''00'' WHEN 6 THEN ''0'' ELSE '''' END + CONVERT(nvarchar(255), OH.OrderNum) COLLATE DATABASE_DEFAULT + CASE WHEN (SELECT CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) THEN 1 ELSE ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' END) = 2 AND EB.Entity <> '''' THEN ''_'' + EB.Entity ELSE '''' END)'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Selected = @Selected + @@ROWCOUNT
									END
							END

						ELSE IF @SourceTypeID = 8 --Navision
							BEGIN
								SET @Message = 'Code for Navision is not yet implemented.'
								SET @Severity = 16
								GOTO EXITPOINT
							END

						ELSE IF @SourceTypeID = 9 --Axapta
							BEGIN
								SET @Message = 'Code for Axapta is not yet implemented.'
								SET @Severity = 16
								GOTO EXITPOINT
							END

						ELSE IF @SourceTypeID = 12 --Enterprise (E7)
							BEGIN
								SET @Message = 'Code for Enterprise (E7) is not yet implemented.'
								SET @Severity = 16
								GOTO EXITPOINT
							END

						ELSE IF @SourceTypeID = 15 --pcSource
							BEGIN
								SET @Message = 'Code for pcSource is not yet implemented.'
								SET @Severity = 16
								GOTO EXITPOINT
							END

						ELSE
							BEGIN
								SET @Message = 'Code for selected SourceTypeID (' + CONVERT(nvarchar(15), @SourceTypeID) + ') is not yet implemented.'
								SET @Severity = 16
								GOTO EXITPOINT
							END


					FETCH NEXT FROM OrderNo_Cursor INTO @SourceTypeID, @SourceDatabase, @StartYear
				END
		CLOSE OrderNo_Cursor
		DEALLOCATE OrderNo_Cursor

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				SELECT
					@ModelBM = SUM(ModelBM)
				FROM
					(SELECT DISTINCT ModelBM FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DeletedID IS NULL) sub
				
				INSERT INTO #OrderNo_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Source],
					[Parent],
					[Priority],
					[MemberKeyBase],
					[Entity]
					)
				SELECT
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Source],
					[Parent],
					[Priority],
					[MemberKeyBase],
					[Entity]
				FROM
					(
					SELECT 
						[MemberId] = M.[MemberId],
						[MemberKey] = MAX(M.[Label]),
						[Description] = MAX(REPLACE(M.[Description], '@All_Dimension', 'All ' + CASE WHEN RIGHT(@DimensionName, 1) = 'y' THEN LEFT(@DimensionName, LEN(@DimensionName) - 1) + 'ie' ELSE @DimensionName END + 's')),
						[HelpText] = MAX(M.[HelpText]),
						[NodeTypeBM] = MAX(M.[NodeTypeBM]),
						[Source] = 'ETL',
						[Parent] = MAX(M.[Parent]),
						[Priority] = -999999,
						[MemberKeyBase] = MAX(M.[Label]),
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
					) sub
				WHERE
					NOT EXISTS (SELECT 1 FROM #OrderNo_Members_Raw R WHERE R.[MemberKey] = sub.[MemberKey])

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#OrderNo_Members_Raw',
					*
				FROM
					#OrderNo_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END, [Priority], [Entity] 

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				IF CURSOR_STATUS('global','Entity_Members_Cursor') >= -1 DEALLOCATE Entity_Members_Cursor
				DECLARE Entity_Members_Cursor CURSOR FOR
			
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

					OPEN Entity_Members_Cursor
					FETCH NEXT FROM Entity_Members_Cursor INTO @Entity, @Priority

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@Priority] = @Priority

							INSERT INTO [#OrderNo_Members]
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
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
								[HelpText] = CASE WHEN ISNULL([MaxRaw].[HelpText], '') = '' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END,
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
									--[MemberKey] = CASE WHEN @MappingTypeID IN (0, 1) AND @Entity <> '' THEN @Entity + '_' ELSE '' END + CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END + CASE WHEN (SELECT CASE WHEN @MappingTypeID IN (0, 1) THEN 1 ELSE @MappingTypeID END) = 2 AND @Entity <> '' THEN '_' + @Entity ELSE '' END,
									[MemberKey] = [Raw].[MemberKey],									
									--[Description] = MAX(CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedDescription] ELSE [Raw].[Description] END),
									[Description] = MAX([Raw].[Description]),
									[HelpText] = MAX([Raw].[HelpText]),
									[MemberKeyBase] = MAX([Raw].[MemberKeyBase]),
									[Entity] = MAX([Raw].[Entity]),
									[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
									[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), MAX([Raw].[MemberKey])),
									[Source] = MAX([Raw].[Source]),
									[Synchronized] = 1,
									[Parent] = MAX([Raw].[Parent])
								FROM
									[#OrderNo_Members_Raw] [Raw]
									LEFT JOIN #MappedMemberKey MMK ON MMK.[Entity] = [Raw].[Entity] AND [Raw].[MemberKey] BETWEEN MMK.[MemberKeyFrom] AND MMK.[MemberKeyTo]
								WHERE
									[Raw].[Entity] = @Entity AND
									[Raw].[Priority] = @Priority
								GROUP BY
									[Raw].[MemberKey]
									--CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END
								) [MaxRaw]
								LEFT JOIN pcINTEGRATOR..Member M ON M.[DimensionID] = @DimensionID AND M.[Label] = [MaxRaw].[MemberKey]
							WHERE
								[MaxRaw].[MemberKey] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [#OrderNo_Members] AM WHERE AM.[MemberKey] = [MaxRaw].[MemberKey])
							ORDER BY
								CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

							FETCH NEXT FROM Entity_Members_Cursor INTO @Entity, @Priority
						END

				CLOSE Entity_Members_Cursor
				DEALLOCATE Entity_Members_Cursor
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #OrderNo_Members_Raw
		IF @CalledYN = 0 DROP TABLE #EB

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
