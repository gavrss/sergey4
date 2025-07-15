SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Product_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -19,
	@SourceTypeID int = NULL,
	@SourceID int = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@SequenceBMStep int = 65535, --1 = Leaf level
	@StaticMemberYN bit = 1,
	@MappingTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000718,
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
EXEC [spIU_Dim_Product_Raw]  @DebugBM='15',@InstanceID='669',@UserID='-10',@VersionID='1129',@SourceTypeID = 11, @SourceDatabase='dspsource01.pcSource_BTMG'
EXEC [spIU_Dim_Product_Raw] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @SourceTypeID = 11, @DebugBM = 3, @SourceDatabase = 'DSPSOURCE01.CCM_E10'
EXEC [spIU_Dim_Product_Raw] @UserID = -10, @InstanceID = 531, @VersionID = 1041, @DebugBM=7 --PCX

EXEC [spIU_Dim_Product_Raw] @GetVersion = 1
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
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get Products from Source system',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed default Priority to 99999999. Excluded properties AgeGroup, StyleCode and TopNode.'
		IF @Version = '2.1.1.2173' SET @Description = 'Changed references to [Model] from BaseModelID = -7 (Financials) to BaseModelID = -4 (Sales).'
		IF @Version = '2.1.2.2179' SET @Description = 'Loop on different sources.'
		IF @Version = '2.1.2.2199' SET @Description = 'Implement [dbo].[f_ReplaceString] function when setting [Description] property. FEA-10944: Return empty string for NULL [Description] values.'
		
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
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF OBJECT_ID(N'TempDB.dbo.#Product_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceID] = @SourceID,
				[@SourceDatabase] = @SourceDatabase,
				[@MappingTypeID] = @MappingTypeID,
				[@CalledYN] = @CalledYN

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

	SET @Step = 'Create temp table #Product_Members_Raw'
		CREATE TABLE #Product_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[ProductCategory] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[ProductGroup] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Priority] int,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create cursor table'
		CREATE TABLE #Product_Cursor_table
			(
			SourceTypeID int,
			SourceDatabase nvarchar(100) COLLATE DATABASE_DEFAULT,
			StartYear int
			)

		INSERT INTO #Product_Cursor_table
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

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Product_Cursor_table', * FROM #Product_Cursor_table

	SET @Step = 'Product_Cursor'
		IF CURSOR_STATUS('global','Product_Cursor') >= -1 DEALLOCATE Product_Cursor
		DECLARE Product_Cursor CURSOR FOR
			
			SELECT 
				SourceTypeID,
				SourceDatabase,
				StartYear
			FROM
				#Product_Cursor_table
			ORDER BY
				SourceTypeID,
				SourceDatabase

			OPEN Product_Cursor
			FETCH NEXT FROM Product_Cursor INTO @SourceTypeID, @SourceDatabase, @StartYear

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
					
					IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10)
						BEGIN
							IF @SequenceBMStep & 1 > 0 --ProductGroup, parent for Products
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Product_Members_Raw
											(
											[MemberId],
											[MemberKey],
											[Description],
											[HelpText],
											[ProductCategory],
											[ProductGroup],
											[NodeTypeBM],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT DISTINCT
											[MemberId] = NULL,
											[MemberKey] = ''PG_'' + PG.[ProdCode] COLLATE DATABASE_DEFAULT,
											[Description] = PG.[Description] COLLATE DATABASE_DEFAULT,
											[HelpText] = '''',
											[ProductCategory] = ''NONE'' COLLATE DATABASE_DEFAULT,
											[ProductGroup] = PG.[ProdCode] COLLATE DATABASE_DEFAULT,
											[NodeTypeBM] = 2,
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = ''All_'',
											[Priority] = EB.[Priority],
											[Entity] = EB.Entity
										FROM
											' + @SourceDatabase + '.[' + @Owner + '].[ProdGrup] PG
											INNER JOIN [#EB] EB ON EB.Entity = PG.Company COLLATE DATABASE_DEFAULT'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT
								END

							IF @SequenceBMStep & 2 > 0 --Product Leafs
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Product_Members_Raw
											(
											[MemberId],
											[MemberKey],
											[Description],
											[HelpText],
											[ProductCategory],
											[ProductGroup],
											[NodeTypeBM],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT DISTINCT
											[MemberId] = NULL,
											[MemberKey] = P.[PartNum] COLLATE DATABASE_DEFAULT,
											[Description] = LEFT(P.[PartNum] + '' - '' + P.[PartDescription], 512) COLLATE DATABASE_DEFAULT,
											[HelpText] = '''',
											[ProductCategory] = CASE WHEN P.ClassID IS NULL OR P.ClassID = '''' THEN ''NONE'' ELSE P.ClassID END COLLATE DATABASE_DEFAULT,
											[ProductGroup] = CASE WHEN P.ProdCode IS NULL OR P.ProdCode = '''' THEN ''NONE'' ELSE P.ProdCode END COLLATE DATABASE_DEFAULT,
											[NodeTypeBM] = 1,
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = ''PG_'' + CASE WHEN P.ProdCode IS NULL OR P.ProdCode = '''' THEN ''NONE'' ELSE P.ProdCode END COLLATE DATABASE_DEFAULT,
											[Priority] = EB.[Priority],
											[Entity] = EB.Entity
										FROM
											' + @SourceDatabase + '.[' + @Owner + '].[Part] P
											INNER JOIN [#EB] EB ON EB.Entity = P.Company COLLATE DATABASE_DEFAULT'

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

					FETCH NEXT FROM Product_Cursor INTO @SourceTypeID, @SourceDatabase, @StartYear
				END
		CLOSE Product_Cursor
		DEALLOCATE Product_Cursor

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				SELECT
					@ModelBM = SUM(ModelBM)
				FROM
					(SELECT DISTINCT ModelBM FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DeletedID IS NULL) sub
				
				INSERT INTO #Product_Members_Raw
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
				SELECT 
					[MemberId] = M.[MemberId],
					[MemberKey] = MAX(M.[Label]),
					[Description] = MAX(REPLACE(M.[Description], '@All_Dimension', 'All ' + CASE WHEN RIGHT(@DimensionName, 1) = 'y' THEN LEFT(@DimensionName, LEN(@DimensionName) - 1) + 'ie' ELSE @DimensionName END + 's')),
					[HelpText] = MAX(M.[HelpText]),
					[NodeTypeBM] = MAX(M.[NodeTypeBM]),
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
					TempTable = '#Product_Members_Raw',
					*
				FROM
					#Product_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END, [Priority], [Entity] 

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				IF @MappingTypeID IN (1, 2)
					BEGIN
						INSERT INTO [#Product_Members]
							(
							[MemberKey],
							[Description],
							[HelpText],
							[Entity],
							[ProductCategory],
							[ProductGroup],
							[NodeTypeBM],
							[SBZ],
							[Source],
							[Synchronized],
							[Parent]
							)
						SELECT DISTINCT
							[MemberKey] = E.[Entity],
							[Description] = E.[EntityName],
							[HelpText] = E.[EntityName],
							[Entity] = E.[Entity],
							[ProductCategory] = 'NONE',
							[ProductGroup] = 'NONE',
							[NodeTypeBM] = 18,
							[SBZ] = 1,
							[Source] = 'ETL',
							[Synchronized] = 1,
							[Parent] = 'All_'
						FROM
							#EB E
					END

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

							INSERT INTO [#Product_Members]
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[MemberKeyBase],
								[Entity],
								[ProductCategory],
								[ProductGroup],
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
								[ProductCategory] = [MaxRaw].[ProductCategory],
								[ProductGroup] = [MaxRaw].[ProductGroup],
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
									--[Description] = MAX(CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedDescription] ELSE [Raw].[Description] END),
									[Description] = ISNULL([dbo].[f_ReplaceString] (@InstanceID, @VersionID, MAX(CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedDescription] ELSE [Raw].[Description] END), 2), ''),
									[HelpText] = MAX([Raw].[HelpText]),
									[MemberKeyBase] = MAX([Raw].[MemberKey]),
									[Entity] = MAX([Raw].[Entity]),
									[ProductCategory] = MAX([Raw].[ProductCategory]),
									[ProductGroup] = MAX([Raw].[ProductGroup]),
									[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
									[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), MAX([Raw].[MemberKey])),
									[Source] = MAX([Raw].[Source]),
									[Synchronized] = 1,
									[Parent] = MAX(CASE WHEN @MappingTypeID IN (1, 2) AND [Raw].[Parent] = 'All_' THEN CASE WHEN [Raw].[MemberKey] IN ('NONE', 'ToBeSet') THEN 'All_' ELSE @Entity END ELSE CASE WHEN @MappingTypeID = 1 AND @Entity <> '' THEN @Entity + '_' ELSE '' END + CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[Parent] END + CASE WHEN @MappingTypeID = 2 AND @Entity <> '' THEN '_' + @Entity ELSE '' END END)
								FROM
									[#Product_Members_Raw] [Raw]
									LEFT JOIN #MappedMemberKey MMK ON MMK.[Entity] = [Raw].[Entity] AND [Raw].[MemberKey] BETWEEN MMK.[MemberKeyFrom] AND MMK.[MemberKeyTo]
								WHERE
									[Raw].[MemberKey] <> '' AND
									[Raw].[Entity] = @Entity AND
									[Raw].[Priority] = @Priority
								GROUP BY
									CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END
								) [MaxRaw]
								LEFT JOIN pcINTEGRATOR..Member M ON M.[DimensionID] = @DimensionID AND M.[Label] = [MaxRaw].[MemberKey]
							WHERE
								[MaxRaw].[MemberKey] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [#Product_Members] AM WHERE AM.[MemberKey] = [MaxRaw].[MemberKey])
							ORDER BY
								CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

							FETCH NEXT FROM Entity_Members_Cursor INTO @Entity, @Priority
						END

				CLOSE Entity_Members_Cursor
				DEALLOCATE Entity_Members_Cursor
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Product_Members_Raw
		IF @CalledYN = 0 DROP TABLE #EB

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
