SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_Dim_Time_Callisto_20230118]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@DimensionID INT = -7, 
	@HierarchyNo INT = NULL,
	--NB New hierarchy routines are not yet implemented

	@StartYear INT = NULL,
	@AddYear INT = NULL, --Number of years to add after current year
	@FiscalYearStartMonth INT = NULL,
	@FiscalYearNaming INT = NULL,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000674,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM = 3 (include high and low prio, exclude sub routines)
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_Time_Callisto] @UserID=-10, @InstanceID = -1329, @VersionID = -1267, @StartYear = 2019, @DebugBM=3
EXEC [spIU_Dim_Time_Callisto] @UserID=-10, @InstanceID = -1335, @VersionID = -1273, @DebugBM=1
EXEC [spIU_Dim_Time_Callisto] @UserID=-10, @InstanceID = 521, @VersionID = 1049, @DebugBM=7

EXEC [spIU_Dim_Time_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CallistoDatabase NVARCHAR(100),
	@SQLStatement NVARCHAR(MAX),

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
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
	@ToBeChanged NVARCHAR(255) = 'Add database stored parameters for @AddYear and @DataFirst',
	@CreatedBy NVARCHAR(50) = 'NeHa',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2178'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to load Members into Callisto Time Dimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Made generic.'
		IF @Version = '2.0.3.2152' SET @Description = 'Added @FiscalYearNaming.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-369: Set correct TimeFiscal* properties. DB-310: Added @FiscalYearNaming. Get @StartYear and @AddYear from Instance, added PeriodStartDate, PeriodEndDate and SortOrder.'
		IF @Version = '2.1.0.2161' SET @Description = 'Calculate RowOrder before set MemberID. Changed prefix in the SP name.'
		IF @Version = '2.1.0.2164' SET @Description = 'Added parameters @UserID, @InstanceID and @VersionID in [spIU_Dim_Time_Raw] call.'
		IF @Version = '2.1.2.2178' SET @Description = 'Added parameter @JobID in [spIU_Dim_Time_Raw] call.'

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

		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = A.DestinationDatabase,
			@StartYear = ISNULL(@StartYear, I.[StartYear]),
			@AddYear = ISNULL(@AddYear,  I.[AddYear]),
			@FiscalYearStartMonth = COALESCE(@FiscalYearStartMonth, A.FiscalYearStartMonth, I.FiscalYearStartMonth),
			@FiscalYearNaming = ISNULL(@FiscalYearNaming, I.FiscalYearNaming)
		FROM
			[Application] A
			INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID 
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		SELECT
			@StartYear = ISNULL(@StartYear, MIN(StartYear))
		FROM
			[Source] S
		WHERE
			S.InstanceID = @InstanceID AND
			S.VersionID = @VersionID

		SELECT
			@AddYear = ISNULL(@AddYear, 2) --Number of years to add after current year

		IF @DebugBM & 2 > 0 SELECT [@StartYear] = @StartYear, [@AddYear] = @AddYear, [@FiscalYearStartMonth] = @FiscalYearStartMonth, [@FiscalYearNaming] = @FiscalYearNaming

	SET @Step = 'Create table #LeafCheck'
		CREATE TABLE #LeafCheck
			(
			[MemberId] [BIGINT] NOT NULL,
			HasChild BIT NOT NULL
			)

	SET @Step = 'Create table #Time_Members'
		CREATE TABLE #Time_Members
			(
			[MemberId] BIGINT,
			[MemberKey] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[Label] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[Description] NVARCHAR(512) COLLATE DATABASE_DEFAULT,
			[HelpText] NVARCHAR(1024) COLLATE DATABASE_DEFAULT,
			[Level] NVARCHAR(10) COLLATE DATABASE_DEFAULT,
			[PeriodStartDate] [DATE] NULL,
			[PeriodEndDate] [DATE] NULL,
			[TimeMonth] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeMonth_MemberId] BIGINT,
			[TimeQuarter] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeQuarter_MemberId] BIGINT,
			[TimeTertial] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeTertial_MemberId] BIGINT,
			[TimeSemester] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeSemester_MemberId] BIGINT,
			[TimeYear] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeYear_MemberId] BIGINT,
			[TimeFiscalPeriod] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalPeriod_MemberId] BIGINT,
			[TimeFiscalQuarter] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalQuarter_MemberId] BIGINT,
			[TimeFiscalTertial] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalTertial_MemberId] BIGINT,
			[TimeFiscalSemester] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalSemester_MemberId] BIGINT,
			[TimeFiscalYear] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalYear_MemberId] BIGINT,
			[SendTo] NVARCHAR(255) COLLATE DATABASE_DEFAULT,	
			[SendTo_MemberId] BIGINT,
			[NumberOfDays] INT,
			[TopNode] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] INT,
			[RNodeType] NVARCHAR(2) COLLATE DATABASE_DEFAULT,
			[SBZ] BIT,
			[Source] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] BIT,				
			[Parent] NVARCHAR(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Get values to insert'
		EXEC [spIU_Dim_Time_Raw] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @StartYear = @StartYear, @AddYear = @AddYear, @FiscalYearStartMonth = @FiscalYearStartMonth, @FiscalYearNaming = @FiscalYearNaming, @JobID = @JobID, @Debug = @DebugSub

		UPDATE #Time_Members SET [Label] = [MemberKey], [RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END, [TopNode] = 'All Time'
		
	SET @Step = 'Update Description and dimension specific Properties where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[Time]
			SET
				[Description] = [Members].[Description],
				[Level] = [Members].[Level],
				[PeriodStartDate] = CONVERT(nvarchar(50), [Members].[PeriodStartDate], 23),
				[PeriodEndDate] = CONVERT(nvarchar(50), [Members].[PeriodEndDate], 23),
				[TimeMonth] = [Members].[TimeMonth],
				[TimeMonth_MemberId] = [Members].[TimeMonth_MemberId],
				[TimeQuarter] = [Members].[TimeQuarter],
				[TimeQuarter_MemberId] = [Members].[TimeQuarter_MemberId],
				[TimeTertial] = [Members].[TimeTertial],
				[TimeTertial_MemberId] = [Members].[TimeTertial_MemberId],
				[TimeSemester] = [Members].[TimeSemester],
				[TimeSemester_MemberId] = [Members].[TimeSemester_MemberId],
				[TimeYear] = [Members].[TimeYear],
				[TimeYear_MemberId] = [Members].[TimeYear_MemberId],
				[TimeFiscalPeriod] = [Members].[TimeFiscalPeriod],
				[TimeFiscalPeriod_MemberId] = [Members].[TimeFiscalPeriod_MemberId],
				[TimeFiscalQuarter] = [Members].[TimeFiscalQuarter],
				[TimeFiscalQuarter_MemberId] = [Members].[TimeFiscalQuarter_MemberId],
				[TimeFiscalTertial] = [Members].[TimeFiscalTertial],
				[TimeFiscalTertial_MemberId] = [Members].[TimeFiscalTertial_MemberId],
				[TimeFiscalSemester] = [Members].[TimeFiscalSemester],
				[TimeFiscalSemester_MemberId] = [Members].[TimeFiscalSemester_MemberId],
				[TimeFiscalYear] = [Members].[TimeFiscalYear],
				[TimeFiscalYear_MemberId] = [Members].[TimeFiscalYear_MemberId],
				[TopNode] = [Members].[TopNode],
				[NumberOfDays] = [Members].[NumberOfDays],
				[Source] = [Members].[Source]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Time] [Time] 
				INNER JOIN [#Time_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Time].Label
			WHERE 
				[Time].[Synchronized] <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT		
	
	SET @Step = 'Insert new members'
		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[S_DS_Time]
				(
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[Level],
				[PeriodStartDate],
				[PeriodEndDate],
				[TimeMonth],
				[TimeMonth_MemberId],
				[TimeQuarter],
				[TimeQuarter_MemberId],
				[TimeTertial],
				[TimeTertial_MemberId],
				[TimeSemester],
				[TimeSemester_MemberId],
				[TimeYear],
				[TimeYear_MemberId],
				[TimeFiscalPeriod],
				[TimeFiscalPeriod_MemberId],
				[TimeFiscalQuarter],
				[TimeFiscalQuarter_MemberId],
				[TimeFiscalTertial],
				[TimeFiscalTertial_MemberId],
				[TimeFiscalSemester],
				[TimeFiscalSemester_MemberId],
				[TimeFiscalYear],
				[TimeFiscalYear_MemberId],
				[SendTo],	
				[SendTo_MemberId],
				[NumberOfDays],
				[TopNode],
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]
				)
			SELECT
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[Level],
				[PeriodStartDate] = CONVERT(nvarchar(50), [Members].[PeriodStartDate], 23),
				[PeriodEndDate] = CONVERT(nvarchar(50), [Members].[PeriodEndDate], 23),
				[TimeMonth],
				[TimeMonth_MemberId],
				[TimeQuarter],
				[TimeQuarter_MemberId],
				[TimeTertial],
				[TimeTertial_MemberId],
				[TimeSemester],
				[TimeSemester_MemberId],
				[TimeYear],
				[TimeYear_MemberId],
				[TimeFiscalPeriod],
				[TimeFiscalPeriod_MemberId],
				[TimeFiscalQuarter],
				[TimeFiscalQuarter_MemberId],
				[TimeFiscalTertial],
				[TimeFiscalTertial_MemberId],
				[TimeFiscalSemester],
				[TimeFiscalSemester_MemberId],
				[TimeFiscalYear],
				[TimeFiscalYear_MemberId],
				[SendTo],	
				[SendTo_MemberId],
				[NumberOfDays],
				[TopNode],
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]
			FROM   
				[#Time_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Time] [Time] WHERE [Time].Label COLLATE DATABASE_DEFAULT = Members.Label)'
			
		IF @DebugBM & 2 > 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)			

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update RowOrder'
		SET @SQLStatement = '
			UPDATE [Time]
			SET
				[RowOrder] = ISNULL(sub.[RowOrder], 0)
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Time] [Time]
				LEFT JOIN
				(
				SELECT
					[MemberId],
					[RowOrder] = CASE [Level] WHEN ''Year'' THEN 1000 WHEN ''Quarter'' THEN 10000 WHEN ''Month'' THEN 100000 WHEN ''Week'' THEN 1000000 WHEN ''Day'' THEN 10000000 ELSE 0 END + ROW_NUMBER() OVER(PARTITION BY [Level] ORDER BY [MemberId])
				FROM
					[' + @CallistoDatabase + '].[dbo].[S_DS_Time] [Time]
				WHERE
					[Level] IS NOT NULL
				) sub ON sub.[MemberId] = [Time].[MemberId]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)	

	SET @Step = 'Update MemberId'
		EXEC spSet_MemberId @Database = @CallistoDatabase, @Dimension = 'Time', @Debug = @Debug

	SET @Step = 'Check which parent members have leaf members as children.'
		TRUNCATE TABLE #LeafCheck

		EXEC spSet_LeafCheck @Database = @CallistoDatabase, @Dimension = 'Time', @DimensionTemptable = N'#Time_Members', @Debug = @DebugSub

	SET @Step = 'Insert new members into the default hierarchy. To change the hierarchy, use the Modeler.'
		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[S_HS_Time_Time]
				(
				[MemberId],
				[ParentMemberId],
				[SequenceNumber]
				)
			SELECT
				D1.MemberId,
				ISNULL(D2.MemberId, 0),
				D1.MemberId  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Time] D1
				INNER JOIN [#Time_Members] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Time] D2 ON D2.Label = CONVERT(nvarchar(255), V.Parent) COLLATE DATABASE_DEFAULT
				LEFT JOIN [#LeafCheck] LC ON LC.MemberId = D1.MemberId AND LC.HasChild <> 0
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_Time_Time] H WHERE H.MemberId = D1.MemberId) AND
				[D1].[Synchronized] <> 0 AND
				D1.MemberId <> ISNULL(D2.MemberId, 0) AND
				D1.MemberId IS NOT NULL AND
				D1.MemberId NOT IN (1000, 30000000) AND
				(D1.RNodeType IN (''L'', ''LC'') OR LC.MemberId IS NOT NULL)
			ORDER BY
				D1.Label'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)

	SET @Step = 'Copy the hierarchy to all instances'
		EXEC spSet_HierarchyCopy @Database = @CallistoDatabase, @Dimensionhierarchy = 'Time_Time'

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_Time]'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Time] ORDER BY MemberId')

	SET @Step = 'Drop the temp tables'
		DROP TABLE #LeafCheck
		DROP TABLE #Time_Members

	SET @Step = 'Set @Duration'
		SET @Duration = GETDATE() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
