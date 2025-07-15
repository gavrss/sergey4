SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_Dim_Time_Callisto]
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
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000674,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

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
	@DimensionName NVARCHAR(50),
	@CallistoDatabase NVARCHAR(100),
	@SQLStatement NVARCHAR(MAX),
	@JSON NVARCHAR(MAX),
	@LogPropertyYN BIT = 0, --Properties JobID, Inserted & Updated,
	@NodeTypeBMYN BIT = 0,
	@StorageTypeBM INT = 4,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
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
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
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
		IF @Version = '2.1.2.2191' SET @Description = 'Use sub routine spSet_Hierarchy for hierarchy setup.'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-2541: Added [PeriodStartDate] and [PeriodEndDate] filters when Updating [S_DS_Time].'

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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@DimensionName = D.[DimensionName]
		FROM
			pcINTEGRATOR..[Dimension] D
		WHERE
			D.[InstanceID] IN (0, @InstanceID) AND
			D.[DimensionID] = @DimensionID AND
			D.[SelectYN] <> 0 AND
			D.[DeletedID] IS NULL

		EXEC [dbo].[spGet_DimPropertyStatus]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DimensionID = @DimensionID,
			@StorageTypeBM = @StorageTypeBM,
			@LogPropertyYN = @LogPropertyYN OUT,
			@NodeTypeBMYN = @NodeTypeBMYN OUT,
			@JobID = @JobID,
			@Debug = @DebugSub

		IF @DebugBM & 2 > 0
			SELECT
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@CallistoDatabase] = @CallistoDatabase,
				[@LogPropertyYN] = @LogPropertyYN,
				[@NodeTypeBMYN] = @NodeTypeBMYN

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

	SET @Step = 'Create table #Time_Members'
		CREATE TABLE #Time_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[Level] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[PeriodStartDate] [date] NULL,
			[PeriodEndDate] [date] NULL,
			[TimeMonth] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeMonth_MemberId] bigint,
			[TimeQuarter] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeQuarter_MemberId] bigint,
			[TimeTertial] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeTertial_MemberId] bigint,
			[TimeSemester] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeSemester_MemberId] bigint,
			[TimeYear] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeYear_MemberId] bigint,
			[TimeFiscalPeriod] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalPeriod_MemberId] bigint,
			[TimeFiscalQuarter] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalQuarter_MemberId] bigint,
			[TimeFiscalTertial] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalTertial_MemberId] bigint,
			[TimeFiscalSemester] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalSemester_MemberId] bigint,
			[TimeFiscalYear] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalYear_MemberId] bigint,
			[SendTo] nvarchar(255) COLLATE DATABASE_DEFAULT,	
			[SendTo_MemberId] bigint,
			[NumberOfDays] int,
			[TopNode] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
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
				[HelpText] = [Members].[HelpText], 
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
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(NVARCHAR(50), FORMAT(GETDATE(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				[Source] = Members.[Source]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Time] [Time] 
				INNER JOIN [#Time_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Time].Label
			WHERE 
				[Time].[Synchronized] <> 0 AND
				(
					[Time].[Description] <> Members.[Description] OR
					[Time].[HelpText] <> Members.[HelpText] OR
					[Time].[Source] <> Members.[Source] OR
					[Time].[PeriodStartDate] <> CONVERT(nvarchar(50), [Members].[PeriodStartDate], 23) OR
					[Time].[PeriodEndDate] <> CONVERT(nvarchar(50), [Members].[PeriodEndDate], 23)
				)'

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
				[Synchronized],
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated],' ELSE '' END + '
				[Source]
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
				[Synchronized],
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(NVARCHAR(50), FORMAT(GETDATE(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(NVARCHAR(50), FORMAT(GETDATE(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				[Source]
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
		EXEC spSet_MemberId @Database = @CallistoDatabase, @Dimension = 'Time', @Debug = @DebugSub

	SET @Step = 'Refresh selected hierarchies.'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(NVARCHAR(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(NVARCHAR(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(NVARCHAR(15), @VersionID) + '"},
			{"TKey" : "DimensionID",  "TValue": "' + CONVERT(NVARCHAR(15), @DimensionID) + '"},
			' + CASE WHEN @HierarchyNo IS NOT NULL THEN '{"TKey" : "HierarchyNo",  "TValue": "' + CONVERT(NVARCHAR(10), @HierarchyNo) + '"},' ELSE '' END + '
			{"TKey" : "StorageTypeBM",  "TValue": "' + CONVERT(NVARCHAR(15), @StorageTypeBM) + '"},
			{"TKey" : "StorageDatabase",  "TValue": "' + @CallistoDatabase + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(NVARCHAR(10), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(NVARCHAR(10), @DebugSub) + '"}
			]'

		IF @DebugBM & 2 > 0 PRINT @JSON
					
		EXEC spRun_Procedure_KeyValuePair
			@DatabaseName = 'pcINTEGRATOR',
			@ProcedureName = 'spSet_Hierarchy',
			@JSON = @JSON

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_Time]'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Time] ORDER BY MemberId')

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Time_Members

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
