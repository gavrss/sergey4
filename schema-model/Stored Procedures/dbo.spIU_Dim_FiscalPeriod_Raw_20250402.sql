SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_FiscalPeriod_Raw_20250402]

	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -76, --FiscalPeriod
	@SequenceBMStep int = 65535, --1 = Years, 2 = FiscalPeriods
	@StaticMemberYN bit = 1,
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000805,
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
EXEC [spIU_Dim_FiscalPeriod_Raw] @UserID=-10, @InstanceID=531, @VersionID=1057, @DebugBM=7
EXEC [spIU_Dim_FiscalPeriod_Raw] @UserID=-10, @InstanceID=478, @VersionID=1032, @DebugBM=7

EXEC [spIU_Dim_FiscalPeriod_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@JournalTable nvarchar(100),
	@Entity nvarchar(50),
	@Book nvarchar(50),

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
	@Version nvarchar(50) = '2.1.2.2176'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to get Members to load into FiscalPeriod Dimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2176' SET @Description = 'Procedure created. DB-697 Create SP for loading new dimension FiscalPeriod (generic)'
		
		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

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

		EXEC [pcINTEGRATOR].[dbo].[spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		SELECT TOP 1
			@Entity = E.[MemberKey],
			@Book = EB.[Book]
		FROM
			pcINTEGRATOR_Data..Entity E
			INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND EB.[BookTypeBM] & 1 > 0 AND EB.[BookTypeBM] & 2 > 0 AND EB.[SelectYN] <> 0
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[EntityTypeID] = -1 AND
			E.[SelectYN] <> 0 AND
			E.[DeletedID] IS NULL
		ORDER BY
			ISNULL(E.[Priority], 999999999)

		IF OBJECT_ID(N'TempDB.dbo.#FiscalPeriod_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@JournalTable] = @JournalTable,
				[@Entity] = @Entity,
				[@Book] = @Book,
				[@CalledYN] = @CalledYN

	SET @Step = 'Create temp table #FYP'
		CREATE TABLE #FYP
			(
			[FiscalYear] int,
			[FiscalPeriod] int,
			[YearMonth] int
			)

	SET @Step = 'Create table #FiscalPeriod_Members_Raw'
		CREATE TABLE #FiscalPeriod_Members_Raw
			(
			[MemberId] int,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,			
			[TimeFiscalYear_MemberId] int DEFAULT -1,
			[TimeFiscalPeriod_MemberId] int DEFAULT -1,			
			[Time_MemberId] int DEFAULT -1,
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT
			)
		
	SET @Step = 'Get rows from Journal'
		SET @SQLStatement = '
			INSERT INTO #FYP
				(
				[FiscalYear],
				[FiscalPeriod],
				[YearMonth]
				)
			SELECT
				[FiscalYear],
				[FiscalPeriod],
				[YearMonth] = MIN([YearMonth])
			FROM
				' + @JournalTable + ' J
			WHERE
				J.[Entity] = ''' + @Entity + ''' AND
				J.[Book] = ''' + @Book + '''
			GROUP BY
				[FiscalYear],
				[FiscalPeriod]
			ORDER BY
				[FiscalYear],
				[FiscalPeriod]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			INSERT INTO #FYP
				(
				[FiscalYear],
				[FiscalPeriod],
				[YearMonth]
				)
			SELECT
				[FiscalYear] = J.[FiscalYear],
				[FiscalPeriod] = J.[FiscalPeriod],
				[YearMonth] = MIN(J.[YearMonth])
			FROM
				' + @JournalTable + ' J
			WHERE
				NOT EXISTS (SELECT 1 FROM #FYP F WHERE F.[FiscalYear] = J.[FiscalYear] AND F.[FiscalPeriod] = J.[FiscalPeriod])
			GROUP BY
				[FiscalYear],
				[FiscalPeriod]
			ORDER BY
				[FiscalYear],
				[FiscalPeriod]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FYP', * FROM #FYP ORDER BY [FiscalYear], [FiscalPeriod], [YearMonth]

	SET @Step = 'Insert FiscalYears into temp table [#FiscalPeriod_Members_Raw]'
		IF @SequenceBMStep & 1 > 0 --Parent
			BEGIN
				INSERT INTO #FiscalPeriod_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],			
					[TimeFiscalYear_MemberId],
					[TimeFiscalPeriod_MemberId],	
					[Time_MemberId],
					[Parent]
					)
				SELECT DISTINCT
					[MemberId] = [FiscalYear],
					[MemberKey] = CONVERT(NVARCHAR(15), [FiscalYear]),
					[Description] = CONVERT(NVARCHAR(15), [FiscalYear]),
					[HelpText] = CONVERT(NVARCHAR(15), [FiscalYear]),
					[NodeTypeBM] = 18,			
					[TimeFiscalYear_MemberId] = [FiscalYear],
					[TimeFiscalPeriod_MemberId] = -1,	
					[Time_MemberId] = -1,
					[Parent] = 'All_'
				FROM
					#FYP
				ORDER BY
					[FiscalYear]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Insert FiscalPeriods into temp table [#FiscalPeriod_Members_Raw]'
		IF @SequenceBMStep & 2 > 0 --Leafs
			BEGIN
				INSERT INTO #FiscalPeriod_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],			
					[TimeFiscalYear_MemberId],
					[TimeFiscalPeriod_MemberId],	
					[Time_MemberId],
					[Parent]
					)
				SELECT DISTINCT
					[MemberId] = [FiscalYear] * 100 + [FiscalPeriod],
					[MemberKey] = CONVERT(NVARCHAR(15), [FiscalYear] * 100 + [FiscalPeriod]),
					[Description] = CONVERT(NVARCHAR(15), [FiscalYear]) + '-' + CONVERT(NVARCHAR(15), [FiscalPeriod]),
					[HelpText] = CONVERT(NVARCHAR(15), [FiscalYear]) + '-' + CONVERT(NVARCHAR(15), [FiscalPeriod]),
					[NodeTypeBM] = 1,			
					[TimeFiscalYear_MemberId] = [FiscalYear],
					[TimeFiscalPeriod_MemberId] = 100 + [FiscalPeriod],	
					[Time_MemberId] = [YearMonth],
					[Parent] = [FiscalYear]
				FROM
					#FYP
				ORDER BY
					[FiscalYear] * 100 + [FiscalPeriod],
					[YearMonth]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Static Rows'
		IF @StaticMemberYN <> 0
			BEGIN
				INSERT INTO [#FiscalPeriod_Members_Raw]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT 
					[MemberId] = MAX([MemberId]),
					[MemberKey] = [Label],
					[Description] = MAX(REPLACE([Description], '@All_Dimension', 'All FiscalPeriods')),
					[HelpText] = MAX([HelpText]),
					[NodeTypeBM] = MAX([NodeTypeBM]),
					[Parent] = MAX([Parent])
				FROM 
					pcINTEGRATOR.dbo.Member
				WHERE
					DimensionID IN (0, @DimensionID)
				GROUP BY
					[Label]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#FiscalPeriod_Members_Raw',
					*
				FROM
					#FiscalPeriod_Members_Raw
				ORDER BY
					MemberID

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#FiscalPeriod_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],			
					[TimeFiscalYear_MemberId],
					[TimeFiscalPeriod_MemberId],	
					[Time_MemberId],
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
					[NodeTypeBM] = [MaxRaw].[NodeTypeBM],					
					[TimeFiscalYear_MemberId] = [MaxRaw].[TimeFiscalYear_MemberId],
					[TimeFiscalPeriod_MemberId] = [MaxRaw].[TimeFiscalPeriod_MemberId],					
					[Time_MemberId] = [MaxRaw].[Time_MemberId],
					[SBZ] = pcINTEGRATOR.[dbo].[f_GetSBZ2] (@DimensionID, [MaxRaw].[NodeTypeBM], [MaxRaw].[MemberKey]),
					[Source] = 'ETL',
					[Synchronized] = 1,				
					[Parent] = CASE [MaxRaw].[Parent] WHEN 'NULL' THEN NULL ELSE [MaxRaw].[Parent] END
				FROM
					(
					SELECT
						[MemberId] = MAX([Raw].[MemberId]),
						[MemberKey] = [Raw].[MemberKey],
						[Description] = MAX([Raw].[Description]),
						[HelpText] = MAX([Raw].[HelpText]),
						[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),	
						[TimeFiscalYear_MemberId] = MAX([Raw].[TimeFiscalYear_MemberId]),
						[TimeFiscalPeriod_MemberId] = MAX([Raw].[TimeFiscalPeriod_MemberId]),
						[Time_MemberId] = MAX([Raw].[Time_MemberId]),
						[Parent] = MAX([Raw].[Parent])
					FROM
						[#FiscalPeriod_Members_Raw] [Raw]
					GROUP BY
						[Raw].[MemberKey]
					) [MaxRaw]
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = 0 AND M.[Label] = [MaxRaw].MemberKey
				WHERE
					[MaxRaw].[MemberKey] IS NOT NULL
				ORDER BY
					CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #FYP
		DROP TABLE #FiscalPeriod_Members_Raw

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @CalledYN = 0
			BEGIN
				EXEC pcINTEGRATOR..[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
			END
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC pcINTEGRATOR..[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
