SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_Dim_InvoiceNo_AP_Raw]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@SourceTypeID INT = NULL,
	@SourceDatabase NVARCHAR(100) = NULL,
	@SequenceBMStep INT = 65535, --8 = Leaf level
	@StaticMemberYN BIT = 1,
	@MappingTypeID INT = NULL,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000733,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_InvoiceNo_AP_Raw] @UserID=-10, @InstanceID=748, @VersionID=1176, @SourceTypeID=11, @SourceDatabase='dspsource01.pcSource_BSL', @DebugBM=15

EXEC [spIU_Dim_InvoiceNo_AP_Raw] @UserID = -10, @InstanceID = -1089, @VersionID = -1086, @SourceTypeID = 11, @SourceDatabase = 'DSPSOURCE04.Sumitomo_E10Live', @DebugBM = 7
EXEC [spIU_Dim_InvoiceNo_AP_Raw] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @SourceTypeID = 11, @DebugBM = 3, @SourceDatabase = 'DSPSOURCE01.CCM_E10'

EXEC [spIU_Dim_InvoiceNo_AP_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN BIT = 1,
	@SourceTypeName NVARCHAR(50),
	@SourceTypeBM INT,
	@SQLStatement NVARCHAR(MAX),
	@DimensionID INT = -46,
	@DimensionName NVARCHAR(50),
	@Owner NVARCHAR(3),
	@ModelBM INT,
	@Step_ProcedureName NVARCHAR(100),
	@Entity NVARCHAR(50),
	@Priority INT,
	@StartYear INT,
	@ETLDatabase NVARCHAR(100),
	@SourceID INT,
	@MappingTypeID_Supplier INT,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName nvarchar(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'NeHa',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get InvoiceNo_APs from Source system',
			@MandatoryParameter = 'SourceTypeID' --Without @, separated by |

		IF @Version = '2.1.0.2163' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed default Priority to 99999999.'
		IF @Version = '2.1.2.2191' SET @Description = 'Handle Entity for prefix/suffix'
		IF @Version = '2.1.2.2199' SET @Description = 'Updated to latest sp_Template. FDB-2264: Added [Supplier] value in leaf level.'
		
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
			[pcINTEGRATOR].[dbo].[Dimension]
		WHERE
			InstanceID IN (0, @InstanceID) AND
			DimensionID = @DimensionID

		SELECT 
			@ETLDatabase = ETLDatabase
		FROM 
			[pcINTEGRATOR_Data].[dbo].[Application] 
		WHERE
			InstanceID = @InstanceID AND
            VersionID = @VersionID AND
            SelectYN <> 0

		SELECT
			@SourceTypeName = SourceTypeName,
			@SourceTypeBM = SourceTypeBM
		FROM
			[pcINTEGRATOR].[dbo].[SourceType]
		WHERE
			SourceTypeID = @SourceTypeID

		SET @Owner = CASE WHEN @SourceTypeID = 11 THEN 'erp' ELSE 'dbo' END

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		SELECT
			@MappingTypeID_Supplier = MappingTypeID
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = -46 --Supplier

		SELECT DISTINCT
			@SourceID = S.SourceID,
			@SourceTypeID = ISNULL(@SourceTypeID, S.SourceTypeID),
			@SourceDatabase = ISNULL(@SourceDatabase, S.SourceDatabase),
			@StartYear = S.StartYear
		FROM
			[pcINTEGRATOR_Data].[dbo].[Model] M
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Source] S ON S.InstanceID = M.InstanceID AND S.VersionID = M.VersionID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
		WHERE
			M.InstanceID = @InstanceID AND
			M.VersionID = @VersionID AND
			M.BaseModelID = -11 AND --AccountPayable
			M.SelectYN <> 0
		
		IF OBJECT_ID(N'TempDB.dbo.#InvoiceNo_AP_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0 SELECT [@SourceDatabase] = @SourceDatabase, [@DimensionName] = @DimensionName, [@SourceTypeName] = @SourceTypeName, [@SourceTypeBM] = @SourceTypeBM, [@MappingTypeID] = @MappingTypeID, [@CalledYN] = @CalledYN

	SET @Step = 'Create #EB (Entity/Book)'
		IF OBJECT_ID(N'TempDB.dbo.#EB', N'U') IS NULL
			BEGIN
				SELECT DISTINCT
					[EntityID] = E.[EntityID],
					[Entity] = E.[MemberKey],
					[EntityName] = E.[EntityName],
					[Priority] = CONVERT(INT, ISNULL(E.[Priority], 99999999))
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
			[Entity] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[MemberKeyFrom] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[MemberKeyTo] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[MappedMemberKey] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[MappedDescription] [NVARCHAR](255) COLLATE DATABASE_DEFAULT
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

	SET @Step = 'Create temp table #InvoiceNo_AP_Members_Raw'
		CREATE TABLE #InvoiceNo_AP_Members_Raw
			(
			[MemberId] BIGINT,
			[MemberKey] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[Description] NVARCHAR(512) COLLATE DATABASE_DEFAULT,
			[HelpText] NVARCHAR(1024) COLLATE DATABASE_DEFAULT,
			[Supplier] NVARCHAR (255) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] INT,
			[Source] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Parent] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[Priority] INT,
			[Entity] NVARCHAR(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Fill temptable #InvoiceNo_AP_Members_Raw, Entity level'
		IF @MappingTypeID IN (0, 1, 2) -- 0 shoul be removed later !!!!!!
			BEGIN
				INSERT INTO #InvoiceNo_AP_Members_Raw
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

	SET @Step = 'Fill temptable #InvoiceNo_AP_Members_Raw'
		IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10)
			BEGIN
				--IF @SequenceBMStep & 1 > 0 --Parent: Entity
				--	BEGIN
				--		SET @SQLStatement = '
				--			INSERT INTO #InvoiceNo_AP_Members_Raw
				--				(
				--				[MemberId],
				--				[MemberKey],
				--				[Description],
				--				[HelpText],
				--				[Supplier],
				--				[NodeTypeBM],
				--				[Source],
				--				[Parent],
				--				[Priority],
				--				[Entity]
				--				)
				--			SELECT DISTINCT
				--				[MemberId] = NULL,
				--				[MemberKey] = EB.Entity,
				--				[Description] = EB.EntityName,
				--				[HelpText] = '''',
				--				[Supplier] = ''NONE'',
				--				[NodeTypeBM] = 2,
				--				[Source] = ''' + @SourceTypeName + ''',							
				--				[Parent] = ''All_'',
				--				[Priority] = EB.[Priority],
				--				[Entity] = EB.Entity
				--			FROM
				--				' + @SourceDatabase + '.[' + @Owner + '].[APInvHed] [APIH]
				--				INNER JOIN [#EB] EB ON EB.Entity = APIH.Company COLLATE DATABASE_DEFAULT'

				--		IF @DebugBM & 2 > 0 PRINT @SQLStatement
				--		EXEC (@SQLStatement)
				--		SET @Selected = @Selected + @@ROWCOUNT
				--	END

				IF @SequenceBMStep & 2 > 0 --Parent: InvoiceNo_AP; Supplier
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #InvoiceNo_AP_Members_Raw
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[Supplier],
								[NodeTypeBM],
								[Source],
								[Parent],
								[Priority],
								[Entity]
								)
							SELECT DISTINCT
								[MemberId] = NULL,
								[MemberKey] = CONVERT(nvarchar(255), [APIH].[VendorNum]) COLLATE DATABASE_DEFAULT,
								--[MemberKey] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CONVERT(nvarchar(255), [APIH].[VendorNum]) COLLATE DATABASE_DEFAULT + CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' = 2 THEN ''_'' + EB.Entity ELSE '''' END,
								[Description] = ISNULL([Supplier].VendorID, CONVERT(nvarchar(255), APIH.[VendorNum])) + '' '' + ISNULL([Supplier].[Name], '''') COLLATE DATABASE_DEFAULT,				
								[HelpText] = '''',
								[Supplier] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' = 1 AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CONVERT(nvarchar(255), [APIH].[VendorNum]) COLLATE DATABASE_DEFAULT + CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' = 2 THEN ''_'' + EB.Entity ELSE '''' END,
								[NodeTypeBM] = 2,
								[Source] = ''' + @SourceTypeName + ''',					
								[Parent] = ''E_'' + EB.Entity,
								[Priority] = EB.[Priority],
								[Entity] = EB.Entity
							FROM
								' + @SourceDatabase + '.[' + @Owner + '].[APInvHed] [APIH]
								INNER JOIN [#EB] EB ON EB.Entity = APIH.Company COLLATE DATABASE_DEFAULT
								LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[Vendor] [Supplier] ON [Supplier].[Company] = [APIH].[Company] AND [Supplier].[VendorNum] = [APIH].[VendorNum]
							WHERE
								YEAR(APIH.InvoiceDate) >= ' + CONVERT(NVARCHAR(15), @StartYear)

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Selected = @Selected + @@ROWCOUNT
					END

				IF @SequenceBMStep & 4 > 0 --Leaf: InvoiceNo_AP; Invoice
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #InvoiceNo_AP_Members_Raw
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[Supplier],
								[NodeTypeBM],
								[Source],
								[Parent],
								[Priority],
								[Entity]
								)
							SELECT DISTINCT
								[MemberId] = NULL,
								[MemberKey] = CONVERT(nvarchar(255), [APIH].[VendorNum]) + ''_'' + [APIH].[InvoiceNum] COLLATE DATABASE_DEFAULT ,
								--[MemberKey] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CONVERT(nvarchar(255), [APIH].[VendorNum]) + ''_'' + [APIH].[InvoiceNum] COLLATE DATABASE_DEFAULT + CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' = 2 THEN ''_'' + EB.Entity ELSE '''' END,
								[Description] = ISNULL([Supplier].VendorID, CONVERT(nvarchar(255), APIH.[VendorNum])) + '', '' + [APIH].[InvoiceNum] COLLATE DATABASE_DEFAULT,
								[HelpText] = '''',								
								--[Supplier] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID_Supplier) + ' = 1 AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID_Supplier) + ' = 2 THEN ''_'' + EB.Entity ELSE '''' END,
								[Supplier] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID_Supplier) + ' = 1 AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CONVERT(nvarchar(255), [APIH].[VendorNum]) COLLATE DATABASE_DEFAULT + CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID_Supplier) + ' = 2 THEN ''_'' + EB.Entity ELSE '''' END,
								[NodeTypeBM] = 1,
								[Source] = ''' + @SourceTypeName + ''',
								[Parent] = CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' IN (0, 1) AND EB.Entity <> '''' THEN EB.Entity + ''_'' ELSE '''' END + CONVERT(nvarchar(255), [APIH].[VendorNum]) COLLATE DATABASE_DEFAULT + CASE WHEN ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ' = 2 THEN ''_'' + EB.Entity ELSE '''' END,
								[Priority] = EB.[Priority],
								[Entity] = EB.Entity
							FROM
								' + @SourceDatabase + '.[' + @Owner + '].[APInvHed] [APIH]
								INNER JOIN [#EB] EB ON EB.Entity = APIH.Company COLLATE DATABASE_DEFAULT
								LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[Vendor] [Supplier] ON [Supplier].[Company] = [APIH].[Company] AND [Supplier].[VendorNum] = [APIH].[VendorNum]
							WHERE
								YEAR(APIH.InvoiceDate) >= ' + CONVERT(NVARCHAR(15), @StartYear)

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
				SET @Message = 'Code for selected SourceTypeID (' + CONVERT(NVARCHAR(15), @SourceTypeID) + ') is not yet implemented.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				SELECT
					@ModelBM = SUM(ModelBM)
				FROM
					(SELECT DISTINCT ModelBM FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DeletedID IS NULL) sub
				
				INSERT INTO #InvoiceNo_AP_Members_Raw
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
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#InvoiceNo_AP_Members_Raw',
					*
				FROM
					#InvoiceNo_AP_Members_Raw
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

							INSERT INTO [#InvoiceNo_AP_Members]
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[MemberKeyBase],
								[Entity],
								[Supplier],
								[Paid],
								[Paid_Time],
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
								[Supplier] = [MaxRaw].[Supplier],
								[Paid] = [MaxRaw].[Paid],
								[Paid_Time] = [MaxRaw].[Paid_Time],
								[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
								[SBZ] = [MaxRaw].[SBZ],
								[Source] = [MaxRaw].[Source],
								[Synchronized] = 1,
								[Parent] = CASE [MaxRaw].[Parent] WHEN 'NULL' THEN NULL ELSE [MaxRaw].[Parent] END
							FROM
								(
								SELECT
									[MemberId] = MAX([Raw].[MemberId]),
									[MemberKey] = CASE WHEN @MappingTypeID IN (0, 1) AND MAX([Raw].[Entity]) <> '' THEN MAX([Raw].[Entity]) + '_' ELSE '' END + [Raw].[MemberKey] + CASE WHEN @MappingTypeID = 2 AND MAX([Raw].[Entity]) <> '' THEN '_' + MAX([Raw].[Entity]) ELSE '' END,											
									--[MemberKey] = [Raw].[MemberKey],									
									[Description] = MAX([Raw].[Description]),
									[HelpText] = MAX([Raw].[HelpText]),
									[MemberKeyBase] = [Raw].[MemberKey],
									[Entity] = MAX([Raw].[Entity]),
									[Supplier] = MAX([Raw].[Supplier]),
									[Paid] = 'N',
									[Paid_Time] = 'NONE',
									[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
									[SBZ] = [pcINTEGRATOR].[dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), MAX([Raw].[MemberKey])),
									[Source] = MAX([Raw].[Source]),
									[Synchronized] = 1,
									[Parent] = MAX([Raw].[Parent])
								FROM
									[#InvoiceNo_AP_Members_Raw] [Raw]
									LEFT JOIN #MappedMemberKey MMK ON MMK.[Entity] = [Raw].[Entity] AND [Raw].[MemberKey] BETWEEN MMK.[MemberKeyFrom] AND MMK.[MemberKeyTo]
								WHERE
									[Raw].[Entity] = @Entity AND
									[Raw].[Priority] = @Priority
								GROUP BY
									[Raw].[MemberKey]
								) [MaxRaw]
								LEFT JOIN [pcINTEGRATOR].[dbo].[Member] M ON M.[DimensionID] = @DimensionID AND M.[Label] = [MaxRaw].[MemberKey]
							WHERE
								[MaxRaw].[MemberKey] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [#InvoiceNo_AP_Members] AM WHERE AM.[MemberKey] = [MaxRaw].[MemberKey])
							ORDER BY
								CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

							FETCH NEXT FROM Entity_Members_Cursor INTO @Entity, @Priority
						END

				CLOSE Entity_Members_Cursor
				DEALLOCATE Entity_Members_Cursor
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #InvoiceNo_AP_Members_Raw
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
