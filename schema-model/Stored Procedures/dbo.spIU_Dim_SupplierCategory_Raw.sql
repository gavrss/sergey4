SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_SupplierCategory_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@SequenceBMStep int = 65535, --1 = Leaf level
	@StaticMemberYN bit = 1,
	@MappingTypeID int = NULL,
	@ETLDatabase nvarchar(100) = NULL,
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000749,
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
EXEC [spIU_Dim_SupplierCategory_Raw] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @SourceTypeID = 11, @DebugBM = 3, @SourceDatabase = '[DSPSOURCE01].[pcSource_E2IP]'
EXEC [spIU_Dim_SupplierCategory_Raw] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @SourceTypeID = 3, @DebugBM = 3

EXEC [spIU_Dim_SupplierCategory_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceTypeName nvarchar(50),
	@SourceTypeBM int,
	@SQLStatement nvarchar(max),
	@DimensionID int = -72,
	@DimensionName nvarchar(50),
	@Owner nvarchar(3),
	@ModelBM int,
	@Step_ProcedureName nvarchar(100),
	@Entity nvarchar(50),
	@Priority int,
	@TableName nvarchar(255),
	@SourceID int,
	@TableExistsYN bit,

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
			@ProcedureDescription = 'Get list of SupplierCategories from Source system',
			@MandatoryParameter = 'DimensionID|SourceTypeID|SourceDatabase' --Without @, separated by |

		IF @Version = '2.1.0.2165' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2166' SET @Description = 'Set correct source table for @SourceTypeID IN (1,11).'
		IF @Version = '2.1.1.2168' SET @Description = 'For @SourceTypeID IN (1,11), get data from source table [Vendor] IF [VendGrup] does not exists.'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed default Priority to 99999999.'
		
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
			@SourceTypeName = SourceTypeName,
			@SourceTypeBM = SourceTypeBM
		FROM
			SourceType
		WHERE
			SourceTypeID = @SourceTypeID

		SELECT
			@SourceID = S.[SourceID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Source] S
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.ModelBM & 584 > 0 AND M.[SelectYN] <> 0
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SourceTypeID] = @SourceTypeID AND
			S.[SelectYN] <> 0

		SET @Owner = CASE WHEN @SourceTypeID = 11 THEN 'erp' ELSE 'dbo' END

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @ETLDatabase IS NULL
			SELECT
				@ETLDatabase = ISNULL(@ETLDatabase, A.[ETLDatabase])
			FROM
				pcINTEGRATOR_Data.dbo.[Application] A
			WHERE
				A.InstanceID = @InstanceID AND
				A.VersionID = @VersionID AND
				A.SelectYN <> 0

		SELECT DISTINCT
			@SourceTypeID = ISNULL(@SourceTypeID, S.SourceTypeID),
			@SourceDatabase = ISNULL(@SourceDatabase, S.SourceDatabase)
		FROM
			pcINTEGRATOR_Data..[Model] M
			INNER JOIN pcINTEGRATOR_Data..[Source] S ON S.InstanceID = M.InstanceID AND S.VersionID = M.VersionID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
		WHERE
			M.InstanceID = @InstanceID AND
			M.VersionID = @VersionID AND
			M.BaseModelID = -7 AND
			M.SelectYN <> 0
		
		IF OBJECT_ID(N'TempDB.dbo.#SupplierCategory_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0 
			SELECT
				[@SourceDatabase] = @SourceDatabase, 
				[@DimensionName] = @DimensionName,
				[@SourceID] = @SourceID,
				[@SourceTypeName] = @SourceTypeName,
				[@SourceTypeBM] = @SourceTypeBM,
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
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.VersionID AND B.EntityID = E.EntityID AND B.BookTypeBM & 9 > 0 AND B.SelectYN <> 0
				WHERE
					E.[InstanceID] = @InstanceID AND
					E.[VersionID] = @VersionID AND
					E.[SelectYN] <> 0

				IF @DebugBM & 2 > 0 SELECT TempTable = '#EB', * FROM #EB
			END

	SET @Step = 'Create temp table #CCTable'
		CREATE TABLE #CCTable
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

	SET @Step = 'Create temp table #SupplierCategory_Members_Raw'
		CREATE TABLE #SupplierCategory_Members_Raw
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

	SET @Step = 'Fill temptable #SupplierCategory_Members_Raw, Entity level'
		IF @MappingTypeID IN (1, 2)
			BEGIN
				INSERT INTO #SupplierCategory_Members_Raw
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
					[MemberKey] = 'E_' + E.[Entity],
					[Description] = E.[EntityName],
					[NodeTypeBM] = 18,
					[Source] = 'ETL',
					[Parent] = 'All_',
					[Priority] = -999999,
					[Entity] = ''
				FROM
					#EB E
			END

	SET @Step = 'Fill temptable #SupplierCategory_Members_Raw'
		IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10)
			BEGIN
				IF @SequenceBMStep & 1 > 0 --SupplierCategory Leafs
					BEGIN
						SET @SQLStatement = '
							DECLARE @ReturnVar int
							EXEC spGet_TableExistsYN @DatabaseName = ''' + @SourceDatabase + ''', @TableName = ''[' + @Owner + '].[VendGrup]'',  @ExistsYN =  @ReturnVar OUT
							SELECT @InternalVariable = @ReturnVar'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableExistsYN OUT
						
						IF @DebugBM & 2 > 0 SELECT [@TableExistsYN_VendGrup] = @TableExistsYN

						IF @TableExistsYN <> 0
							BEGIN
								SET @SQLStatement = '
									INSERT INTO #SupplierCategory_Members_Raw
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
										[MemberKey] = VG.[GroupCode] COLLATE DATABASE_DEFAULT,
										[Description] = VG.[GroupDesc] COLLATE DATABASE_DEFAULT,
										[NodeTypeBM] = 1,
										[Source] = ''' + @SourceTypeName + ''',
										[Parent] = ' + CASE WHEN @MappingTypeID IN (1, 2) THEN '''E_'' + EB.Entity' ELSE '''All_''' END + ',
										[Priority] = EB.[Priority],
										[Entity] = EB.[Entity]
									FROM
										' + @SourceDatabase + '.[' + @Owner + '].[VendGrup] VG
										INNER JOIN #EB EB ON EB.Entity = VG.Company COLLATE DATABASE_DEFAULT'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
								SET @Selected = @Selected + @@ROWCOUNT
							END

						ELSE
							BEGIN
								SET @SQLStatement = '
									DECLARE @ReturnVar int
									EXEC spGet_TableExistsYN @DatabaseName = ''' + @SourceDatabase + ''', @TableName = ''[' + @Owner + '].[Vendor]'',  @ExistsYN =  @ReturnVar OUT
									SELECT @InternalVariable = @ReturnVar'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableExistsYN OUT
						
								IF @DebugBM & 2 > 0 SELECT [@TableExistsYN_Vendor] = @TableExistsYN
								
								IF @TableExistsYN <> 0
									BEGIN
										SET @SQLStatement = '
											INSERT INTO #SupplierCategory_Members_Raw
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
												[MemberKey] = V.[GroupCode] COLLATE DATABASE_DEFAULT,
												[Description] = V.[GroupCode] COLLATE DATABASE_DEFAULT,
												[NodeTypeBM] = 1,
												[Source] = ''' + @SourceTypeName + ''',
												[Parent] = ' + CASE WHEN @MappingTypeID IN (1, 2) THEN '''E_'' + EB.Entity' ELSE '''All_''' END + ',
												[Priority] = EB.[Priority],
												[Entity] = EB.[Entity]
											FROM
												' + @SourceDatabase + '.[' + @Owner + '].[Vendor] V
												INNER JOIN #EB EB ON EB.Entity = V.Company COLLATE DATABASE_DEFAULT
											WHERE
												LEN(V.[GroupCode]) > 0'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Selected = @Selected + @@ROWCOUNT
									END
							END
					END
			END

		IF @SourceTypeID IN (3) --iScala
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #CCTable
						(
						[TableName],
						[Entity_MemberKey],
						[FiscalYear],
						[Priority]
						)
					SELECT
						wST.[TableName],
						wST.[Entity_MemberKey],
						wST.[FiscalYear],
						wST.[Priority]
					FROM
						' + @ETLDatabase + '.[dbo].[wrk_SourceTable] wST
					WHERE
						wST.TableCode = ''SY24'' AND
						wST.SourceID = ' + CONVERT(nvarchar(15), @SourceID)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#CCTable', * FROM #CCTable ORDER BY [Priority], [FiscalYear] DESC, [Entity_MemberKey]

				IF CURSOR_STATUS('global','SegmentTable_Cursor') >= -1 DEALLOCATE SegmentTable_Cursor
				DECLARE SegmentTable_Cursor CURSOR FOR
			
					SELECT
						[TableName],
						[Entity_MemberKey],
						[Priority]
					FROM
						#CCTable
					ORDER BY
						[Priority],
						[FiscalYear] DESC,
						[Entity_MemberKey]

					OPEN SegmentTable_Cursor
					FETCH NEXT FROM SegmentTable_Cursor INTO @TableName, @Entity, @Priority

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@TableName] = @TableName, [@Entity] = @Entity, [@Priority] = @Priority

							IF @SequenceBMStep & 2 > 0 --Segment Leafs
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #SupplierCategory_Members_Raw
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
											[MemberKey] = [SY24].[SY24002],
											[Description] = [SY24].[SY24003],
											[NodeTypeBM] = 1,
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = ' + CASE WHEN @MappingTypeID IN (1, 2) THEN @Entity ELSE '''All_''' END + ',
											[Priority] = ' + CONVERT(nvarchar(15), @Priority) + ',
											[Entity] = ''' + @Entity + '''
										FROM
											' + @TableName  + ' [SY24]
										WHERE
											[SY24].[SY24001] = ''CB'' AND
											[SY24].[SY24002] <> '''' AND [SY24].[SY24002] IS NOT NULL AND
											NOT EXISTS (SELECT 1 FROM #SupplierCategory_Members_Raw CCMR WHERE CCMR.[MemberKey] = [SY24].[SY24002] COLLATE DATABASE_DEFAULT AND CCMR.[Entity] = ''' + @Entity + ''')'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT
						
									IF @DebugBM & 2 > 0 SELECT ConsumedTime = CONVERT(Time(7), GetDate() - @StartTime)
								END
						
								FETCH NEXT FROM SegmentTable_Cursor INTO @TableName, @Entity, @Priority
						END	
					CLOSE SegmentTable_Cursor
					DEALLOCATE SegmentTable_Cursor
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

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				SELECT
					@ModelBM = SUM(ModelBM)
				FROM
					(SELECT DISTINCT ModelBM FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DeletedID IS NULL) sub
				
				INSERT INTO #SupplierCategory_Members_Raw
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
					TempTable = '#SupplierCategory_Members_Raw',
					*
				FROM
					#SupplierCategory_Members_Raw
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

							INSERT INTO [#SupplierCategory_Members]
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[MemberKeyBase],
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
									[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
									[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), MAX([Raw].[MemberKey])),
									[Source] = MAX([Raw].[Source]),
									[Synchronized] = 1,
									[Parent] = MAX([Raw].[Parent])
								FROM
									[#SupplierCategory_Members_Raw] [Raw]
									LEFT JOIN #MappedMemberKey MMK ON MMK.[Entity] = [Raw].[Entity] AND [Raw].[MemberKey] BETWEEN MMK.[MemberKeyFrom] AND MMK.[MemberKeyTo]
								WHERE
									[Raw].[Entity] = @Entity AND
									[Raw].[Priority] = @Priority
								GROUP BY
									CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END
								) [MaxRaw]
								LEFT JOIN pcINTEGRATOR..Member M ON M.[DimensionID] = @DimensionID AND M.[Label] = [MaxRaw].[MemberKey]
							WHERE
								[MaxRaw].[MemberKey] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [#SupplierCategory_Members] AM WHERE AM.[MemberKey] = [MaxRaw].[MemberKey])
							ORDER BY
								CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

							FETCH NEXT FROM Account_Members_Cursor INTO @Entity, @Priority
						END

				CLOSE Account_Members_Cursor
				DEALLOCATE Account_Members_Cursor
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #CCTable
		DROP TABLE #SupplierCategory_Members_Raw
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
