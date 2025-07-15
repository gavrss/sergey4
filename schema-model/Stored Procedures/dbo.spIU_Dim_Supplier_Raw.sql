SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Supplier_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL, --Optional
	@SourceDatabase nvarchar(100) = NULL, --Optional
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN bit = 1,
	@MappingTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000724,
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
EXEC [spIU_Dim_Supplier_Raw] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @SequenceBMStep = 15, @StaticMemberYN = 1, @Debug = 1
EXEC [spIU_Dim_Supplier_Raw] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @SequenceBMStep = 15, @StaticMemberYN = 1, @Debug = 1
EXEC [spIU_Dim_Supplier_Raw] @UserID = -10, @InstanceID = 515, @VersionID = 1064, @SequenceBMStep = 15, @StaticMemberYN = 1, @Debug = 1

EXEC [spIU_Dim_Supplier_Raw] @GetVersion = 1
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
	@DimensionID int = -10,
	@ModelBM int,
	@Owner nvarchar(3),
	@Entity nvarchar(50),
	@Priority int,

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
			@ProcedureDescription = 'Get list of Suppliers from Source system',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2166' SET @Description = 'Added [SupplierCategory].'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed default Priority to 99999999.'
		IF @Version = '2.1.1.2173' SET @Description = 'Removed IF-ELSE handling of different @SourceTypeIDs.'
		IF @Version = '2.1.2.2198' SET @Description = 'Handle P21.'
		IF @Version = '2.1.2.2199' SET @Description = 'Updated to latest SP template.'

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
			@SourceTypeBM = SUM(SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				SourceTypeBM
			FROM
				[pcINTEGRATOR].[dbo].[SourceType] ST
				INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.SourceTypeID = ST.SourceTypeID AND S.SelectYN <> 0
			) sub

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF OBJECT_ID(N'TempDB.dbo.#Supplier_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@CalledYN] = @CalledYN,
				[@MappingTypeID] = @MappingTypeID

	SET @Step = 'Create temp table #Supplier_Members_Raw'
		CREATE TABLE #Supplier_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[PaymentDays] int,
			[SupplierCategory] nvarchar(100) COLLATE DATABASE_DEFAULT,
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
			[Priority] = CONVERT(int, ISNULL(E.[Priority], 99999999))
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

	SET @Step = 'Fill temptable #Supplier_Members_Raw, Entity level'
		IF @MappingTypeID IN (1, 2)
			BEGIN
				INSERT INTO #Supplier_Members_Raw
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
					[Entity] = E.[Entity]
				FROM
					#EB E
			END

	SET @Step = 'Create CursorTable'
		CREATE TABLE #Supplier_CursorTable
			(
			[SourceTypeID] int,
			[SourceTypeName] nvarchar(50),
			[Owner] nvarchar(3) COLLATE DATABASE_DEFAULT,
			[SourceDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #Supplier_CursorTable
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
			[pcINTEGRATOR_Data].[dbo].[Source] S
			INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SelectYN] <> 0 AND
			(S.[SourceTypeID] = @SourceTypeID OR @SourceTypeID IS NULL)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Supplier_CursorTable', * FROM #Supplier_CursorTable ORDER BY [SourceTypeID]		

	SET @Step = 'Fill temptable #Supplier_Members_Raw by using #Supplier_CursorTable'
		IF CURSOR_STATUS('global','Supplier_SourceType_Cursor') >= -1 DEALLOCATE Supplier_SourceType_Cursor
		DECLARE Supplier_SourceType_Cursor CURSOR FOR
			
			SELECT 
				[SourceTypeID],
				[SourceTypeName],
				[Owner],
				[SourceDatabase]
			FROM
				#Supplier_CursorTable
			ORDER BY
				[SourceTypeID]

			OPEN Supplier_SourceType_Cursor
			FETCH NEXT FROM Supplier_SourceType_Cursor INTO @SourceTypeID, @SourceTypeName, @Owner, @SourceDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@SourceTypeID] = @SourceTypeID, [@SourceTypeName] = @SourceTypeName, [@Owner] = @Owner, [@SourceDatabase] = @SourceDatabase
					
					IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10)
						BEGIN
							IF @SequenceBMStep & 4 > 0 --Supplier Leafs
								BEGIN
									SET @SQLStatement = '
									INSERT INTO #Supplier_Members_Raw
										(
										[MemberId],
										[MemberKey],
										[Description],
										[HelpText],
										[NodeTypeBM],
										[PaymentDays],
										[SupplierCategory],
										[Source],
										[Parent],
										[Priority],
										[Entity]
										)
									SELECT DISTINCT
										[MemberId] = NULL,
										[MemberKey] = CONVERT(nvarchar(50), [V].[VendorNum]),
										[Description] = [V].[Name],
										[HelpText] = NULL,
										[NodeTypeBM] = 1,
										[PaymentDays] = ISNULL([T].[NumberOfDays], 0),
										[SupplierCategory] = [V].[GroupCode],
										[Source] = ''' + @SourceTypeName + ''',
										[Parent] =  ' + CASE WHEN @MappingTypeID IN (1, 2) THEN '''E_'' + EB.Entity' ELSE '''All_''' END + ',
										[Priority] = EB.[Priority],
										[Entity] = EB.Entity
									FROM
										' + @SourceDatabase + '.[' + @Owner + '].[Vendor] [V]
										LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[Terms] [T] ON [T].[Company] = [V].[Company] AND [T].[TermsCode] = [V].[TermsCode]
										INNER JOIN [#EB] EB ON EB.Entity = V.Company COLLATE DATABASE_DEFAULT'
										
									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									
									SET @Selected = @Selected + @@ROWCOUNT
								END

						END

					ELSE IF @SourceTypeID IN (5) --P21
						BEGIN
							IF @SequenceBMStep & 4 > 0 --Supplier Leafs
								BEGIN
									SET @SQLStatement = '
									INSERT INTO #Supplier_Members_Raw
										(
										[MemberId],
										[MemberKey],
										[Description],
										[HelpText],
										[NodeTypeBM],
										[PaymentDays],
										[SupplierCategory],
										[Source],
										[Parent],
										[Priority],
										[Entity]
										)
									SELECT DISTINCT
										[MemberId] = NULL,
										[MemberKey] = CONVERT(nvarchar(50), CONVERT(int, [V].[vendor_id])),
										[Description] = [V].[vendor_name],
										[HelpText] = [V].[vendor_name],
										[NodeTypeBM] = 1,
										[PaymentDays] = 0, --[default_terms_id]
										[SupplierCategory] = ''NONE'',
										[Source] = ''' + @SourceTypeName + ''',
										[Parent] =  ' + CASE WHEN @MappingTypeID IN (1, 2) THEN '''E_'' + EB.Entity' ELSE '''All_''' END + ',
										[Priority] = EB.[Priority],
										[Entity] = EB.Entity
									FROM
										' + @SourceDatabase + '.[' + @Owner + '].[Vendor] [V]
										--LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[Terms] [T] ON [T].[Company] = [V].[Company] AND [T].[TermsCode] = [V].[TermsCode]
										INNER JOIN [#EB] EB ON EB.Entity = V.company_id COLLATE DATABASE_DEFAULT'
										
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

					FETCH NEXT FROM Supplier_SourceType_Cursor INTO @SourceTypeID, @SourceTypeName, @Owner, @SourceDatabase
				END

		CLOSE Supplier_SourceType_Cursor
		DEALLOCATE Supplier_SourceType_Cursor

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				SELECT
					@ModelBM = SUM(ModelBM)
				FROM
					(SELECT DISTINCT ModelBM FROM [pcINTEGRATOR_Data].[dbo].[DataClass] WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DeletedID IS NULL) sub
				
				IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@SourceTypeBM] = @SourceTypeBM, [@ModelBM] = @ModelBM

				INSERT INTO #Supplier_Members_Raw
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
					[Description] = MAX(REPLACE(M.[Description], '@All_Dimension', 'All Suppliers')),
					[HelpText] = MAX(M.[HelpText]),
					[NodeTypeBM] = MAX(M.[NodeTypeBM]),
					[Source] = 'ETL',
					[Parent] = MAX(M.[Parent]),
					[Priority] = -999999,
					[Entity] = ''
				FROM 
					[pcINTEGRATOR].[dbo].[Member] M
					LEFT JOIN [pcINTEGRATOR].[dbo].[Member_Property_Value] MPV ON MPV.[DimensionID] = M.[DimensionID] AND MPV.[MemberId] = M.[MemberId]
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
					TempTable = '#Supplier_Members_Raw',
					*
				FROM
					#Supplier_Members_Raw
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
					#Supplier_Members_Cursor_Table
				FROM
					[#Supplier_Members_Raw]
					--(
					--SELECT DISTINCT
					--	[Entity] = '',
					--	[Priority] = -999999
					--UNION SELECT DISTINCT
					--	[Entity],
					--	[Priority]
					--FROM
					--	#EB
					--) sub
				ORDER BY
					[Priority],
					[Entity]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Supplier_Members_Cursor_Table', * FROM #Supplier_Members_Cursor_Table ORDER BY [Priority], [Entity]

				IF CURSOR_STATUS('global','Supplier_Members_Cursor') >= -1 DEALLOCATE Supplier_Members_Cursor
				DECLARE Supplier_Members_Cursor CURSOR FOR
			
					SELECT DISTINCT
						[Entity],
						[Priority]
					FROM
						#Supplier_Members_Cursor_Table
					ORDER BY
						[Priority],
						[Entity]

					OPEN Supplier_Members_Cursor
					FETCH NEXT FROM Supplier_Members_Cursor INTO @Entity, @Priority

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@Priority] = @Priority

							INSERT INTO [#Supplier_Members]
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[MemberKeyBase],
								[Entity],
								[NodeTypeBM],
								[PaymentDays],
								[SupplierCategory],
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
								[Entity] = @Entity,
								[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
								[PaymentDays] = [MaxRaw].[PaymentDays],
								[SupplierCategory] = [MaxRaw].[SupplierCategory],
								[SBZ] = [MaxRaw].[SBZ],
								[Source] = [MaxRaw].[Source],
								[Synchronized] = 1,
								[Parent] = CASE [MaxRaw].[Parent] WHEN 'NULL' THEN NULL ELSE [MaxRaw].[Parent] END
							FROM
								(
								SELECT
									[MemberId] = MAX([Raw].[MemberId]),
									[MemberKey] = CASE WHEN @MappingTypeID = 1 AND @Priority <> -999999 THEN @Entity + '_' ELSE '' END + CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END + CASE WHEN @MappingTypeID = 2 AND @Priority <> -999999 THEN '_' + @Entity ELSE '' END,
									[Description] = MAX(CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedDescription] ELSE [Raw].[Description] END),
									[HelpText] = MAX([Raw].[HelpText]),
									[MemberKeyBase] = MAX([Raw].[MemberKey]),
									[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
									[PaymentDays] = MAX([Raw].[PaymentDays]),
									[SupplierCategory] = MAX([Raw].[SupplierCategory]),
									[SBZ] = [pcINTEGRATOR].[dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), MAX([Raw].[MemberKey])),
									[Source] = MAX([Raw].[Source]),
									[Synchronized] = 1,
									[Parent] = MAX([Raw].[Parent])
								FROM
									[#Supplier_Members_Raw] [Raw]
									LEFT JOIN #MappedMemberKey MMK ON MMK.[Entity] = [Raw].[Entity] AND [Raw].[MemberKey] BETWEEN MMK.[MemberKeyFrom] AND MMK.[MemberKeyTo]
								WHERE
									[Raw].[Entity] = @Entity AND
									[Raw].[Priority] = @Priority
								GROUP BY
									CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END
								) [MaxRaw]
								LEFT JOIN [pcINTEGRATOR].[dbo].[Member] M ON M.DimensionID = @DimensionID AND M.[Label] = [MaxRaw].MemberKey
							WHERE
								[MaxRaw].[MemberKey] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [#Supplier_Members] AM WHERE AM.[MemberKey] = [MaxRaw].[MemberKey])
							ORDER BY
								CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

							FETCH NEXT FROM Supplier_Members_Cursor INTO @Entity, @Priority
						END

				CLOSE Supplier_Members_Cursor
				DEALLOCATE Supplier_Members_Cursor
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Supplier_Members_Raw
		DROP TABLE #MappedMemberKey
		DROP TABLE #EB
		IF @CalledYN <> 0 DROP TABLE #Supplier_Members_Cursor_Table

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
