SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

/*
sp to Get Members to Dimension from Source system
Template exemplified by reading from E10/Kinetic [ProdGrup]

Included in Nightly Load: Yes as called by [spIU_Dim_Plant_Callisto]

Done:
2023-11-17 by PEEK: Initially created based on [pcINTEGRATOR]..[spIU_Dim_Product_Raw]
ToDo:
Evaluate:

EXEC [spIU_Dim_Plant_Raw] @Debug = 1

*/
CREATE PROCEDURE [dbo].[spIU_Dim_Plant_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -60, -- = 0 gives 'ALL_' & 'NONE' as Default Members
-- SELECT * FROM [pcINTEGRATOR].[dbo].[@Template_Dimension] ORDER BY [DimensionId] DESC
-- SELECT * FROM [pcINTEGRATOR].[dbo].[@Template_Dimension] ORDER BY [DimensionName]
-- SELECT * FROM [pcINTEGRATOR_Data].[dbo].[Dimension] WHERE [InstanceID] = 850
	@SourceTypeID int = NULL,
	@SourceID int = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@SequenceBMStep int = 65535, --1 = Leaf level
	@StaticMemberYN bit = 1,
	@MappingTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,	
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880001000, -- 990000637 replaced by 0 CheckNevhan
--SELECT * FROM [pcINTEGRATOR].[dbo].[Procedure] WHERE [Procedureid] = 880001002
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
EXEC [spIU_Dim_Plant_Raw]  @DebugBM = 3
EXEC [spIU_Dim_Plant_Raw] @UserID = -10, @InstanceID = 531, @VersionID = 1057, @SourceTypeID = 11, @DebugBM = 3
EXEC [spIU_Dim_Plant_Raw] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @SourceTypeID = 11, @DebugBM = 3, @SourceDatabase = 'DSPSOURCE01.CCM_E10'
EXEC [spIU_Dim_Plant_Raw] @UserID = -10, @InstanceID = 907, @VersionID = 1313, @DebugBM=3 

EXEC [spIU_Dim_Plant_Raw] @GetVersion = 1
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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'PEEK',
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get Plants from Source system',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed default Priority to 99999999. Excluded properties AgeGroup, StyleCode and TopNode.'
		IF @Version = '2.1.1.2173' SET @Description = 'Changed references to [Model] from BaseModelID = -7 (Financials) to BaseModelID = -4 (Sales).'
		IF @Version = '2.1.2.2179' SET @Description = 'Loop on different sources.'
		
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

		IF OBJECT_ID(N'TempDB.dbo.#Plant_Members', N'U') IS NULL SET @CalledYN = 0

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

	SET @Step = 'Create temp table #Plant_Members_Raw'
		CREATE TABLE #Plant_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,

			[NodeTypeBM] int,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Priority] int,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create cursor table'
		CREATE TABLE #Plant_Cursor_table
			(
			SourceTypeID int,
			SourceDatabase nvarchar(100) COLLATE DATABASE_DEFAULT,
			StartYear int
			)

		INSERT INTO #Plant_Cursor_table
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

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Plant_Cursor_table', * FROM #Plant_Cursor_table

	SET @Step = 'Plant_Cursor'
		IF CURSOR_STATUS('global','Plant_Cursor') >= -1 DEALLOCATE Plant_Cursor
		DECLARE Plant_Cursor CURSOR FOR
			
			SELECT 
				SourceTypeID,
				SourceDatabase,
				StartYear
			FROM
				#Plant_Cursor_table
			ORDER BY
				SourceTypeID,
				SourceDatabase

			OPEN Plant_Cursor
			FETCH NEXT FROM Plant_Cursor INTO @SourceTypeID, @SourceDatabase, @StartYear

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT
						@SourceTypeName = [SourceTypeName],
						@SourceTypeBM = [SourceTypeBM],
						@Owner = [Owner]
					FROM
						-- [pcINTEGRATOR].[dbo]. added as prefix
						[pcIntegrator].[dbo].[SourceType]
					WHERE
						SourceTypeID = @SourceTypeID
					
					IF @DebugBM & 2 > 0 SELECT [@SourceTypeID]=@SourceTypeID, [@SourceTypeName] = @SourceTypeName, [@SourceTypeBM] = @SourceTypeBM, [@Owner] = @Owner, [@SourceDatabase]=@SourceDatabase, [@StartYear]=@StartYear
					
					IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10) -- All IF @SourceTypeID IN (X,X,...) removes as specific code for Application
						BEGIN
							IF @SequenceBMStep & 1 > 0 -- Top Hierical Level - Lowere levels @SequenceBMStep & 2, & 4, & 16....... Here samplified by [DSPSOURCE01].[pcSource_RDKP].[Erp].[PriceLst]
								BEGIN
										SET @SQLStatement = 'INSERT INTO #Plant_Members_Raw
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
											[MemberKey] = [Plant].[Plant] COLLATE DATABASE_DEFAULT,
											[Description] = [Plant].[Name] COLLATE DATABASE_DEFAULT,
											[HelpText] = [Plant].[Name] COLLATE DATABASE_DEFAULT,

											[NodeTypeBM] = 1, 
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = ''All_'',
											[Priority] = [EB].[Priority],
											[Entity] = [EB].[Entity]
										FROM '
											+ @SourceDatabase + '.[' + @Owner + ']' + '.[Plant] [Plant]
											INNER JOIN [#EB] [EB] ON [EB].[Entity] = [Plant].[Company] COLLATE DATABASE_DEFAULT'
									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									
									SET @Selected = @Selected + @@ROWCOUNT
								END
								--[NodeTypeBM] = 1, -- 1 = ''Leaf Member'' & 2 = ''Parent''
						END
					FETCH NEXT FROM Plant_Cursor INTO @SourceTypeID, @SourceDatabase, @StartYear
				END
		CLOSE Plant_Cursor
		DEALLOCATE Plant_Cursor

	SET @Step = 'Get default members' -- PEEK Only update Properties so not required
		IF @StaticMemberYN <> 0
			BEGIN
				SELECT
					@ModelBM = SUM(ModelBM)
				FROM
					(SELECT DISTINCT ModelBM FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DeletedID IS NULL) sub
				
				INSERT INTO #Plant_Members_Raw
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
					[MemberId] = [M].[MemberId],
					[MemberKey] = MAX([M].[Label]),
					[Description] = MAX(REPLACE([M].[Description], '@All_Dimension', 'All ' + CASE WHEN RIGHT(@DimensionName, 1) = 'y' THEN LEFT(@DimensionName, LEN(@DimensionName) - 1) + 'ie' ELSE @DimensionName END + 's')),
					[HelpText] = MAX([M].[HelpText]),
					[NodeTypeBM] = MAX([M].[NodeTypeBM]),
					[Source] = 'ETL',
					[Parent] = MAX([M].[Parent]),
					[Priority] = -999999,
					[Entity] = ''
				FROM
					-- [pcINTEGRATOR].[dbo]. added as prefix
					[pcINTEGRATOR].[dbo].[Member] [M]
					-- [pcINTEGRATOR].[dbo]. added as prefix
					LEFT JOIN [pcINTEGRATOR].[dbo].[Member_Property_Value] [MPV] ON [MPV].[DimensionID] = [M].[DimensionID] AND [MPV].[MemberId] = [M].[MemberId]
				WHERE
					[M].[DimensionID] IN (0, @DimensionID) AND
					[M].[SourceTypeBM] & @SourceTypeBM > 0 AND
					[M].[ModelBM] & @ModelBM > 0
				GROUP BY
					[M].[MemberId]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Plant_Members_Raw',
					*
				FROM
					#Plant_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END, [Priority], [Entity] 

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				IF @MappingTypeID IN (1, 2)
					BEGIN
						INSERT INTO [#Plant_Members]
							(
							[MemberKey],
							[Description],
							[HelpText],

							[Entity],
							[NodeTypeBM],
							[SBZ],
							[Source],
							[Synchronized],
							[Parent]
							)
						SELECT DISTINCT
							[MemberKey] = [E].[Entity],
							[Description] = [E].[EntityName],
							[HelpText] = [E].[EntityName],

							[Entity] = [E].[Entity],
							[NodeTypeBM] = 18,
							[SBZ] = 1,
							[Source] = 'ETL',
							[Synchronized] = 1,
							[Parent] = 'All_'
						FROM
							#EB [E]
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
							[#EB]
						) sub
					ORDER BY
						sub.[Priority],
						sub.[Entity]

					OPEN Entity_Members_Cursor
					FETCH NEXT FROM Entity_Members_Cursor INTO @Entity, @Priority

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@Priority] = @Priority

							INSERT INTO [#Plant_Members]
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
								[MemberId] = ISNULL([MaxRaw].[MemberId], [M].[MemberID]),
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
									[MemberKey] = CASE WHEN @MappingTypeID = 1 AND @Entity <> '' THEN @Entity + '_' ELSE '' END + CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END + CASE WHEN @MappingTypeID = 2 AND @Entity <> '' THEN '_' + @Entity ELSE '' END,
									[Description] = MAX(CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedDescription] ELSE [Raw].[Description] END),
									[HelpText] = MAX([Raw].[HelpText]),
									[MemberKeyBase] = MAX([Raw].[MemberKey]),
									[Entity] = MAX([Raw].[Entity]),

									[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
									-- [pcINTEGRATOR].[dbo]. added as prefix
									[SBZ] = [pcINTEGRATOR].[dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), MAX([Raw].[MemberKey])),
									[Source] = MAX([Raw].[Source]),
									[Synchronized] = 1,
									[Parent] = MAX(CASE WHEN @MappingTypeID IN (1, 2) AND [Raw].[Parent] = 'All_' THEN CASE WHEN [Raw].[MemberKey] IN ('NONE', 'ToBeSet') THEN 'All_' ELSE @Entity END ELSE CASE WHEN @MappingTypeID = 1 AND @Entity <> '' THEN @Entity + '_' ELSE '' END + CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[Parent] END + CASE WHEN @MappingTypeID = 2 AND @Entity <> '' THEN '_' + @Entity ELSE '' END END)
								FROM
									[#Plant_Members_Raw] [Raw]
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
								NOT EXISTS (SELECT 1 FROM [#Plant_Members] AM WHERE AM.[MemberKey] = [MaxRaw].[MemberKey])
							ORDER BY
								CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

							FETCH NEXT FROM Entity_Members_Cursor INTO @Entity, @Priority
						END

				CLOSE Entity_Members_Cursor
				DEALLOCATE Entity_Members_Cursor
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Plant_Members_Raw
		IF @CalledYN = 0 DROP TABLE #EB

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
