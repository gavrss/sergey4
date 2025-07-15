SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_TimeDay]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StartYear int = NULL,
	@AddYear int = 2, --Number of years to add after current year
	@FiscalYearStartMonth int = NULL,
	@DateFirst int = 1,  --First day of week; 1 = Monday, 2 = Tuesday ... 7 = Sunday (SQL default)
	@WeekFirst int = 1, --1 = Jan 1, 2 = First 4-day week, 3 = First full week --https://docs.microsoft.com/en-us/sql/t-sql/functions/datepart-transact-sql?view=sql-server-2017

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000678,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_Dim_TimeDay',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spIU_Dim_TimeDay] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spIU_Dim_TimeDay] @UserID=-10, @InstanceID=404, @VersionID=1003, @Debug=1 --Salinity2
EXEC [spIU_Dim_TimeDay] @UserID=-10, @InstanceID=404, @VersionID=1003, @DateFirst = 1, @WeekFirst = 2, @Debug=1 --Salinity2
EXEC [spIU_Dim_TimeDay] @UserID=-10, @InstanceID=404, @VersionID=1003, @DateFirst = 7, @WeekFirst = 2, @Debug=1 --Salinity2

EXEC [spIU_Dim_TimeDay] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = 'Add database stored parameters for @AddYear and @DataFirst',
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to load Members into TimeDay Dimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

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

		SET @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@CallistoDatabase = A.DestinationDatabase,
			@FiscalYearStartMonth = ISNULL(@FiscalYearStartMonth, A.FiscalYearStartMonth)
		FROM
			[Application] A
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

		SET DATEFIRST @DateFirst

		SELECT
			@AddYear = ISNULL(@AddYear, 2), --Number of years to add after current year
			@WeekFirst = ISNULL(@WeekFirst, 1) --First week of year starts on January 1

	SET @Step = 'Create table #LeafCheck'
		CREATE TABLE #LeafCheck
			(
			[MemberId] [bigint] NOT NULL,
			HasChild bit NOT NULL
			)

	SET @Step = 'Create table #TimeDay_Member'
		CREATE TABLE #TimeDay_Member
			(
			[MemberId] bigint,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[Level] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[TimeWeekDay] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeWeekDay_MemberId] bigint,
			[TimeWeek] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeWeek_MemberId] bigint,
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
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Get values to insert'
		EXEC [spIU_Dim_TimeDay_Raw] @StartYear = @StartYear, @AddYear = @AddYear, @FiscalYearStartMonth = @FiscalYearStartMonth, @DateFirst = @DateFirst, @WeekFirst = @WeekFirst, @Debug = @Debug
		
		IF @Debug <> 0 SELECT TempTable = '#TimeDay_Member', * FROM #TimeDay_Member ORDER BY MemberId

	SET @Step = 'Update Description and dimension specific Properties where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[TimeDay]
			SET
				[Description] = [Members].[Description],
				[Level] = [Members].[Level],
				[TimeWeekDay] = [Members].[TimeWeekDay],
				[TimeWeekDay_MemberId] = [Members].[TimeWeekDay_MemberId],
				[TimeWeek] = [Members].[TimeWeek],
				[TimeWeek_MemberId] = [Members].[TimeWeek_MemberId],
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
				[TopNode] = ''All Time'',
				[NumberOfDays] = [Members].[NumberOfDays],
				[Source] = [Members].[Source]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] 
				INNER JOIN [#TimeDay_Member] Members ON Members.Label COLLATE DATABASE_DEFAULT = [TimeDay].Label
			WHERE 
				[TimeDay].[Synchronized] <> 0'

		IF @Debug <> 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT		
	
	SET @Step = 'Insert new members'
		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[S_DS_TimeDay]
				(
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[Level],
				[TimeWeekDay],
				[TimeWeekDay_MemberId],
				[TimeWeek],
				[TimeWeek_MemberId],
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
				[TimeWeekDay],
				[TimeWeekDay_MemberId],
				[TimeWeek],
				[TimeWeek_MemberId],
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
				[#TimeDay_Member] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] WHERE [TimeDay].Label COLLATE DATABASE_DEFAULT = Members.Label)'

		IF @Debug <> 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)			

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update MemberId'
		EXEC spSet_MemberId @Database = @CallistoDatabase, @Dimension = 'TimeDay', @Debug = @Debug

	SET @Step = 'Check which parent members have leaf members as children.'
		TRUNCATE TABLE #LeafCheck

		EXEC spSet_LeafCheck @Database = @CallistoDatabase, @Dimension = 'TimeDay', @DimensionTemptable = N'#TimeDay_Member', @Debug = @Debug

	SET @Step = 'Insert new members into the default hierarchy. To change the hierarchy, use the Modeler.'
		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[S_HS_TimeDay_TimeDay]
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
				[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D1
				INNER JOIN [#TimeDay_Member] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D2 ON D2.Label = CONVERT(nvarchar(255), V.Parent) COLLATE DATABASE_DEFAULT
				LEFT JOIN [#LeafCheck] LC ON LC.MemberId = D1.MemberId AND LC.HasChild <> 0
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeDay] H WHERE H.MemberId = D1.MemberId) AND
				[D1].[Synchronized] <> 0 AND
				D1.MemberId <> ISNULL(D2.MemberId, 0) AND
				D1.MemberId IS NOT NULL AND
				D1.MemberId NOT IN (1000, 30000000) AND
				(D1.RNodeType IN (''L'', ''LC'') OR LC.MemberId IS NOT NULL)
			ORDER BY
				D1.Label'

		IF @Debug <> 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)

	SET @Step = 'Copy the hierarchy to all instances'
		EXEC spSet_HierarchyCopy @Database = @CallistoDatabase, @Dimensionhierarchy = 'TimeDay_TimeDay'

	SET @Step = 'Drop the temp tables'
		DROP TABLE #LeafCheck
		DROP TABLE #TimeDay_Member

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
