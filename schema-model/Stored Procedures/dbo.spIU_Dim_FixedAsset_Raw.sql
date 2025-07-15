SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_FixedAsset_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf Level
	@StaticMemberYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000664,
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
EXEC [spIU_Dim_FixedAsset_Raw] @UserID = -10, @InstanceID = -1370, @VersionID = -1308, @SourceTypeID = 11, @SourceDatabase = 'DSPSOURCE01.ERP10', @DebugBM = 3

EXEC [spIU_Dim_FixedAsset_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceTypeName nvarchar(50),
	@SourceTypeBM int,
	@SQLStatement nvarchar(max),	
	@DimensionID int = -68,
	@DimensionName nvarchar(50),
	@Owner nvarchar(3),
	@ModelBM int,
	@Step_ProcedureName nvarchar(100),

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of Fixed Assets from Source system',
			@MandatoryParameter = 'SourceTypeID|SourceDatabase' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		
		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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
			pcINTEGRATOR_Data.dbo.[Dimension]
		WHERE
			InstanceID = @InstanceID AND
			DimensionID = @DimensionID

		SELECT
			@SourceTypeName = SourceTypeName,
			@SourceTypeBM = SourceTypeBM
		FROM
			SourceType
		WHERE
			SourceTypeID = @SourceTypeID

		SET @Owner = CASE WHEN @SourceTypeID = 11 THEN 'erp' ELSE 'dbo' END

		IF OBJECT_ID(N'TempDB.dbo.#FixedAsset_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0 SELECT [@SourceDatabase] = @SourceDatabase, [@DimensionName] = @DimensionName, [@SourceTypeName] = @SourceTypeName, [@SourceTypeBM] = @SourceTypeBM, [@CalledYN] = @CalledYN

	SET @Step = 'Create temp table #FixedAsset_Members_Raw'
		CREATE TABLE #FixedAsset_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[AssetClass] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[DateAcquired] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DateCommissioned] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[UsefulLifeMonths] int,
			[SalvageValue] bigint
			)

	SET @Step = 'Create temptable #EB (Entity/Book)'
		SELECT DISTINCT
			Entity = E.MemberKey,
			B.Book,
			B.COA
		INTO
			#EB
		FROM
			[Entity] E
			INNER JOIN [Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.[VersionID] AND B.[EntityID] = E.[EntityID] AND B.[BookTypeBM] & 1 > 0 AND B.[SelectYN] <> 0
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#EB', * FROM #EB

	SET @Step = 'Fill temptable #FixedAsset_Members_Raw'
		IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10)
			BEGIN
				IF @SequenceBMStep & 1 > 0 --Parents
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #FixedAsset_Members_Raw
								(
								[MemberKey],
								[Description],
								[HelpText],
								[NodeTypeBM],
								[Source],
								[Parent],
								[Entity],
								[AssetClass],
								[DateAcquired],
								[DateCommissioned],
								[UsefulLifeMonths],
								[SalvageValue]
								)
							SELECT DISTINCT
								[MemberKey] = FAC.Company COLLATE DATABASE_DEFAULT + ''-'' + FAC.ClassCode COLLATE DATABASE_DEFAULT,
								[Description] = FAC.Description COLLATE DATABASE_DEFAULT,
								[HelpText] = FAC.Description COLLATE DATABASE_DEFAULT,
								[NodeTypeBM] = 18,
								[Source] = ''' + @SourceTypeName + ''',
								[Parent] = CASE WHEN FA.ClassCode IS NULL THEN '''' ELSE ''All_'' END,								
								[Entity] = EB.Entity,
								[AssetClass] = FAC.Company COLLATE DATABASE_DEFAULT + ''-'' + FAC.ClassCode COLLATE DATABASE_DEFAULT,
								[DateAcquired] = '''',
								[DateCommissioned] = '''',
								[UsefulLifeMonths] = 0,
								[SalvageValue] = 0
							FROM
								' + @SourceDatabase + '.[' + @Owner + '].[FAClass] FAC
								LEFT JOIN ' + @SourceDatabase + '.[' + @Owner + '].[FAsset] FA ON FA.Company = FAC.Company AND FA.ClassCode = FAC.ClassCode
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[Company] C ON C.Company = FA.Company
								INNER JOIN [#EB] EB ON EB.Entity = FA.Company COLLATE DATABASE_DEFAULT'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
						SET @Selected = @Selected + @@ROWCOUNT
					END

				IF @SequenceBMStep & 2 > 0 --Leafs
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #FixedAsset_Members_Raw
								(
								[MemberKey],
								[Description],
								[HelpText],
								[NodeTypeBM],
								[Source],
								[Parent],
								[Entity],
								[AssetClass],
								[DateAcquired],
								[DateCommissioned],
								[UsefulLifeMonths],
								[SalvageValue]
								)
							SELECT DISTINCT
								[MemberKey] = FA.Company COLLATE DATABASE_DEFAULT + ''-'' + FA.AssetNum COLLATE DATABASE_DEFAULT,
								[Description] = FA.AssetDescription COLLATE DATABASE_DEFAULT,
								[HelpText] = FA.AssetDescription COLLATE DATABASE_DEFAULT,
								[NodeTypeBM] = 1,
								[Source] = ''' + @SourceTypeName + ''',
								[Parent] = FA.Company COLLATE DATABASE_DEFAULT + ''-'' + FA.ClassCode COLLATE DATABASE_DEFAULT,
								[Entity] = EB.Entity,
								[AssetClass] = FA.Company COLLATE DATABASE_DEFAULT + ''-'' + FA.ClassCode COLLATE DATABASE_DEFAULT,
								[DateAcquired] = CONVERT(NVARCHAR(50), FA.AcquiredDate),
								[DateCommissioned] = CONVERT(NVARCHAR(50), FA.CommissionedDate),
								[UsefulLifeMonths] = 1,
								[SalvageValue] = 0
							FROM
								' + @SourceDatabase + '.[' + @Owner + '].[FAsset] FA
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[FAssetDtl] FAD ON FAD.Company = FA.Company AND FAD.AssetNum = FA.AssetNum
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[FAClass] FAC ON FAC.Company = FA.Company AND FAC.ClassCode = FA.ClassCode
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[Company] C ON C.Company = FA.Company
								INNER JOIN [#EB] EB ON EB.Entity = FA.Company COLLATE DATABASE_DEFAULT'

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

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				INSERT INTO #FixedAsset_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Source],
					[Parent]
					)
				SELECT 
					[MemberId],
					[MemberKey] = [Label],
					[Description] = REPLACE([Description], '@All_Dimension', 'All FixedAssets'),
					[HelpText],
					[NodeTypeBM],
					[Source] = 'ETL',
					[Parent]
				FROM 
					Member
				WHERE
					DimensionID IN (0, @DimensionID) AND
					[SourceTypeBM] & @SourceTypeBM > 0

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#FixedAsset_Members_Raw',
					*
				FROM
					#FixedAsset_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#FixedAsset_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[SBZ],
					[Source],
					[Synchronized],
					[Parent],
					[Entity],
					[AssetClass],
					[DateAcquired],
					[DateCommissioned],
					[UsefulLifeMonths],
					[SalvageValue]
					)
				SELECT TOP 1000000
					[MemberId] = ISNULL([MaxRaw].[MemberId], M.MemberID),
					[MemberKey] = [MaxRaw].[MemberKey],
					[Description] = [MaxRaw].[Description],
					[HelpText] = CASE WHEN ISNULL([MaxRaw].[HelpText], '') = '' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END,
					[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
					[SBZ] = [MaxRaw].[SBZ],
					[Source] = [MaxRaw].[Source],
					[Synchronized] = 1,
					[Parent] = CASE [MaxRaw].[Parent] WHEN 'NULL' THEN NULL ELSE [MaxRaw].[Parent] END,
					[Entity] = [MaxRaw].[Entity],
					[AssetClass] = [MaxRaw].[AssetClass],
					[DateAcquired] = [MaxRaw].[DateAcquired],
					[DateCommissioned] = [MaxRaw].[DateCommissioned],
					[UsefulLifeMonths] = [MaxRaw].[UsefulLifeMonths],
					[SalvageValue] = [MaxRaw].[SalvageValue]
				FROM
					(
					SELECT
						[MemberId] = MAX([Raw].[MemberId]),
						[MemberKey] = [Raw].[MemberKey],
						[Description] = MAX([Raw].[Description]),
						[HelpText] = MAX([Raw].[HelpText]),
						[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
						[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), [Raw].[MemberKey]),
						[Source] = MAX([Raw].[Source]),
						[Synchronized] = 1,
						[Parent] = MAX([Raw].[Parent]),
						[Entity] = MAX([Raw].[Entity]),
						[AssetClass] = MAX([Raw].[AssetClass]),
						[DateAcquired] = MAX([Raw].[DateAcquired]),
						[DateCommissioned] = MAX([Raw].[DateCommissioned]),
						[UsefulLifeMonths] = MAX([Raw].[UsefulLifeMonths]),
						[SalvageValue] = MAX([Raw].[SalvageValue])
					FROM
						[#FixedAsset_Members_Raw] [Raw]
					GROUP BY
						[Raw].[MemberKey]
					) [MaxRaw]
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = @DimensionID AND M.Label = [MaxRaw].MemberKey
				WHERE
					[MaxRaw].[MemberKey] IS NOT NULL
				ORDER BY
					CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #FixedAsset_Members_Raw
		DROP TABLE #EB

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		SET @Step_ProcedureName = @ProcedureName + ' (' + @DimensionName + ')'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @Step_ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
