SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_TimeDay_Raw]

	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StartYear int = 2017,
	@AddYear int = 2, --Number of years to add after current year
	@FiscalYearStartMonth int = 1,
	@FiscalYearNaming int = 0,
	@SequenceBMStep int = 65535, --1 = Years, 2 = Quarters, 4 = Months, 8 = Days, 16 = Weeks, 32 = 4WeekPeriod
	@StaticMemberYN bit = 1,
	@DateFirst int = 1,  --First day of week; 1 = Monday, 2 = Tuesday ... 7 = Sunday (SQL default)
	@WeekFirst int = 1, --1 = Jan 1, 2 = First 4-day week, 3 = First full week --https://docs.microsoft.com/en-us/sql/t-sql/functions/datepart-transact-sql?view=sql-server-2017
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000671,
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
EXEC [spIU_Dim_TimeDay_Raw] @UserID=-10, @InstanceID=-1427, @VersionID=-1365, @SequenceBMStep=31,
@StartYear=2020, @AddYear=1, @FiscalYearStartMonth=1, @FiscalYearNaming=0, @DebugBM=7

EXEC [spIU_Dim_TimeDay_Raw] @UserID=-10, @InstanceID=-1427, @VersionID=-1365, @SequenceBMStep=31,
@StartYear=2020, @AddYear=1, @FiscalYearStartMonth=4, @FiscalYearNaming=1, @DebugBM=3

EXEC [spIU_Dim_TimeDay_Raw] @UserID=-10, @InstanceID=452, @VersionID=1020, @Debug=1 --ReSales
EXEC [spIU_Dim_TimeDay_Raw] @UserID=-10, @InstanceID=404, @VersionID=1003, @FiscalYearStartMonth = 1, @StartYear= 2019, @WeekFirst = 2, @Debug=1 --Salinity2
EXEC [spIU_Dim_TimeDay_Raw] @UserID=-10, @InstanceID=452, @VersionID=1020, @DateFirst = 1, @WeekFirst = 3, @Debug=1 --ReSales
EXEC [spIU_Dim_TimeDay_Raw] @UserID=-10, @InstanceID=452, @VersionID=1020, @DateFirst = 7, @WeekFirst = 3, @Debug=1 --ReSales

EXEC [spIU_Dim_TimeDay_Raw] @UserID=-10, @InstanceID=452, @VersionID=1020, @DateFirst = 1, @WeekFirst = 2, @Debug=1 --ReSales

EXEC [spIU_Dim_TimeDay_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@MonthID int,
	@DimensionID int = -49, --TimeDay
	@SourceTypeID int,
	@YearMonthFrom int,
	@YearMonthTo int,

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
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to get Members to load into TimeDay Dimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2149' SET @Description = 'Made generic. Add week hierarchy.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added parameter @FiscalYearNaming. Get [PeriodStartDate] from ERP database.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added 4WeekPeriod.'

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

		SELECT
			@SourceTypeID = S.[SourceTypeID]
		FROM
			[Application] A
			INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SET DATEFIRST @DateFirst
		SET @FiscalYearNaming = CASE WHEN @FiscalYearStartMonth = 1 THEN 0 ELSE @FiscalYearNaming END

		SELECT
			@AddYear = ISNULL(@AddYear, 2), --Number of years to add after current year
			@WeekFirst = ISNULL(@WeekFirst, 1), --First week of year starts on January 1
			--@YearMonthFrom = (@StartYear - @FiscalYearNaming) * 100 + @FiscalYearStartMonth,
			@YearMonthFrom = (@StartYear * 100) + @FiscalYearStartMonth,
			@YearMonthTo = CASE WHEN @FiscalYearStartMonth <> 1 THEN (YEAR(GETDATE()) + @AddYear + 1) * 100 + (@FiscalYearStartMonth - 1) ELSE (YEAR(GETDATE()) + @AddYear) * 100 + 12 END

		IF OBJECT_ID(N'TempDB.dbo.#TimeDay_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@CalledYN] = @CalledYN,
				[@SourceTypeID] = @SourceTypeID,
				[@StartYear] = @StartYear,
				[@AddYear] = @AddYear,
				[@FiscalYearNaming] = @FiscalYearNaming,
				[@FiscalYearStartMonth] = @FiscalYearStartMonth,
				[@DateFirst] = @DateFirst,
				[@WeekFirst] = @WeekFirst,
				[@YearMonthFrom] = @YearMonthFrom,
				[@YearMonthTo] = @YearMonthTo

	SET @Step = 'Create table #Digit'
		CREATE TABLE #Digit
			(
			Number int
			)

		INSERT INTO #Digit
			(
			Number
			)
		SELECT Number = 0 UNION
		SELECT Number = 1 UNION
		SELECT Number = 2 UNION
		SELECT Number = 3 UNION
		SELECT Number = 4 UNION
		SELECT Number = 5 UNION
		SELECT Number = 6 UNION
		SELECT Number = 7 UNION
		SELECT Number = 8 UNION
		SELECT Number = 9

	SET @Step = 'Create table #Month'
		CREATE TABLE #Month
			(
			[FiscalYear] int,
			[FiscalPeriod] int,
			[YearMonth] int,
			[MidDate] date, 
            [PeriodStartDate] date,
            [PeriodEndDate] date,
			[NumberOfDays] int
			)

	SET @Step = 'Insert into temp table [#Month]'
		IF @SourceTypeID IN (1, 11, 12)
			BEGIN
				EXEC [spIU_Dim_Time_PeriodDate] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @Debug=@DebugSub
				
				DELETE #Month
				WHERE
					[YearMonth] NOT BETWEEN @YearMonthFrom AND @YearMonthTo

				DELETE #Month
				WHERE
					[FiscalPeriod] NOT BETWEEN 1 AND 12

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Month[spIU_Dim_Time_PeriodDate]', * FROM #Month ORDER BY [FiscalYear], [FiscalPeriod], [YearMonth]
			END

		INSERT INTO [#Month]
			(
			[YearMonth]
			)
		SELECT DISTINCT TOP 1000000
			[YearMonth] = Y.Y * 100 + M.M
		FROM
			(
				SELECT
					[Y] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
				FROM
					#Digit D1,
					#Digit D2,
					#Digit D3,
					#Digit D4
				WHERE
					--D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear AND YEAR(GetDate()) + @AddYear
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear - @FiscalYearNaming AND YEAR(GetDate()) + @AddYear + CASE WHEN @FiscalYearStartMonth <> 1 THEN 1 ELSE 0 END
			) Y,
			(
				SELECT
					[M] = D2.Number * 10 + D1.Number + 1 
				FROM
					#Digit D1,
					#Digit D2
				WHERE
					D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
			) M 
		WHERE
--			((CASE WHEN @FiscalYearStartMonth = 1 THEN 1 ELSE 0 END = 1) OR
--			Y.Y * 100 + M.M BETWEEN (CASE WHEN @FiscalYearStartMonth <> 1 THEN @StartYear * 100 + @FiscalYearStartMonth ELSE 0 END) AND (CASE WHEN @FiscalYearStartMonth <> 1 THEN (YEAR(GETDATE()) + @AddYear + 1) * 100 + (@FiscalYearStartMonth - 1) ELSE 0 END)) AND
			Y.Y * 100 + M.M BETWEEN @YearMonthFrom AND @YearMonthTo AND
			NOT EXISTS (SELECT 1 FROM [#Month] DM WHERE DM.[YearMonth] = Y.Y * 100 + M.M)
		ORDER BY
			Y.Y * 100 + M.M

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Month', * FROM #Month ORDER BY [FiscalYear], [FiscalPeriod], [YearMonth]

	SET @Step = 'Set PeriodStartDate'
		UPDATE M
		SET
			[PeriodStartDate] = ISNULL([PeriodStartDate], CONVERT(NVARCHAR(15), M.[YearMonth] / 100) + '-' + CONVERT(NVARCHAR(15), M.[YearMonth] % 100) + '-1'),
            [PeriodEndDate] = ISNULL([PeriodEndDate], DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), M.[YearMonth] / 100) + '-' + CONVERT(NVARCHAR(15), M.[YearMonth] % 100) + '-1'))),
			[NumberOfDays] = ISNULL([NumberOfDays], DAY(DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), M.[YearMonth] / 100) + '-' + CONVERT(NVARCHAR(15), M.[YearMonth] % 100) + '-1'))))
		FROM 
			[#Month] M			

		IF @DebugBM & 1 > 0 SELECT TempTable = '#Month(Update PeriodDate)', * FROM #Month ORDER BY [YearMonth]

	SET @Step = 'Create temp table [#Day_Member]'
		CREATE TABLE #Day_Member 
			(
			DayID BIGINT,
			[DayName] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeWeekDay] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeWeekDay_MemberId] bigint,
			[TimeWeek] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeWeek_MemberId] bigint
			)

	SET @Step = 'Create table #TimeDay_Members_Raw'
		CREATE TABLE #TimeDay_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Level] [nvarchar](10) COLLATE DATABASE_DEFAULT,
			[PeriodStartDate] [date] NULL,
			[PeriodEndDate] [date] NULL,
			[NumberOfDays] [int] NULL,
			[SendTo] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,	
			[SendTo_MemberId] bigint DEFAULT -1,
			[TimeWeekDay] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeWeekDay_MemberId] bigint DEFAULT -1,
			[TimeWeek] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeWeek_MemberId] bigint DEFAULT -1,
			[TimeMonth] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeMonth_MemberId] bigint DEFAULT -1,
			[TimeQuarter] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeQuarter_MemberId] bigint DEFAULT -1,
			[TimeTertial] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeTertial_MemberId] bigint DEFAULT -1,
			[TimeSemester] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeSemester_MemberId] bigint DEFAULT -1,
			[TimeYear] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeYear_MemberId] bigint DEFAULT -1,
			[Time4WeekPeriod] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[Time4WeekPeriod_MemberId] bigint DEFAULT -1,
			[TimeFiscalPeriod] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalPeriod_MemberId] bigint DEFAULT -1,
			[TimeFiscalQuarter] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalQuarter_MemberId] bigint DEFAULT -1,
			[TimeFiscalTertial] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalTertial_MemberId] bigint DEFAULT -1,
			[TimeFiscalSemester] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalSemester_MemberId] bigint DEFAULT -1,
			[TimeFiscalYear] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalYear_MemberId] bigint DEFAULT -1,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Insert Years into temp table [#TimeDay_Members_Raw]'
		IF @SequenceBMStep & 1 > 0
			BEGIN
				INSERT INTO #TimeDay_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Level],
					[PeriodStartDate],
					[PeriodEndDate],
					[NumberOfDays],
					[SendTo],	
					[SendTo_MemberId],
					[TimeYear],
					[TimeYear_MemberId],
					[TimeFiscalYear],
					[TimeFiscalYear_MemberId],
					[Parent]
					)
				SELECT DISTINCT TOP 1000000
					[MemberId] = CASE WHEN @FiscalYearStartMonth = 1 THEN Mo.[YearMonth] / 100 ELSE CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END END,
					[MemberKey] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15),Mo.[YearMonth] / 100) ELSE 'FY' + CONVERT(nvarchar(15), CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END) END),
					[Description] = MAX('Yr ' + CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), Mo.[YearMonth] / 100) ELSE CONVERT(nvarchar, CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END + CASE WHEN @FiscalYearNaming = 1 THEN -1 ELSE 0 END) + '/' + CONVERT(nvarchar, CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END + CASE WHEN @FiscalYearNaming = 1 THEN 0 ELSE 1 END) END),
					[NodeTypeBM] = 18,
					[Level] = 'Year',
					[PeriodStartDate] = MIN(Mo.PeriodStartDate),
					[PeriodEndDate] = MAX(Mo.PeriodEndDate),
					[NumberOfDays] = SUM(Mo.NumberOfDays),
					[SendTo] = CONVERT(NVARCHAR(15), MAX(Mo.[YearMonth])),	
					[SendTo_MemberId] = MAX(Mo.[YearMonth]),
					[TimeYear] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) ELSE 'NONE' END),
					[TimeYear_MemberId] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN [Mo].[YearMonth] / 100 ELSE -1 END),
					[TimeFiscalYear] = MAX('FY' + CONVERT(NVARCHAR(15), CASE WHEN @FiscalYearStartMonth = 1 THEN Mo.[YearMonth] / 100 ELSE CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END END)),
					[TimeFiscalYear_MemberId] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN Mo.[YearMonth] / 100 ELSE CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END END),
					[Parent] = 'All_'
				FROM
					[#Month] [Mo] 
				GROUP BY
					CASE WHEN @FiscalYearStartMonth = 1 THEN Mo.[YearMonth] / 100 ELSE CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END END
				ORDER BY
					[MemberId]
			END

		IF @SequenceBMStep & 16 > 0 --Insert Calendar Year members for TimeWeek Hierarchy
			BEGIN
				INSERT INTO #TimeDay_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Level],
					[PeriodStartDate],
					[PeriodEndDate],
					[NumberOfDays],
					[SendTo],	
					[SendTo_MemberId],
					[TimeYear],
					[TimeYear_MemberId],
					[Parent]
					)
				SELECT DISTINCT TOP 1000000
					[MemberId] = (Mo.[YearMonth] / 100) * 10,
					[MemberKey] = MAX(CONVERT(nvarchar(15),Mo.[YearMonth] / 100)),
					[Description] = MAX('Yr ' + CONVERT(nvarchar(15), Mo.[YearMonth] / 100)),
					[NodeTypeBM] = 18,
					[Level] = 'Year',
					[PeriodStartDate] = MIN(Mo.PeriodStartDate),
					[PeriodEndDate] = MAX(Mo.PeriodEndDate),
					[NumberOfDays] = SUM(Mo.NumberOfDays),
					[SendTo] = CONVERT(NVARCHAR(15), MAX(Mo.[YearMonth])),	
					[SendTo_MemberId] = MAX(Mo.[YearMonth]),
					[TimeYear] = MAX(CONVERT(nvarchar(15), [Mo].[YearMonth] / 100)),
					[TimeYear_MemberId] = MAX([Mo].[YearMonth] / 100),
					[Parent] = 'All_'
				FROM
					[#Month] [Mo]
				GROUP BY
					Mo.[YearMonth] / 100
				ORDER BY
					[MemberId]

				IF @DebugBM & 2 > 0 SELECT [#TimeDay_Members_Raw] = '#TimeDay_Members_Raw(Year)', * FROM #TimeDay_Members_Raw WHERE [Level] = 'Year'
			END

	SET @Step = 'Insert Quarters into temp table [#TimeDay_Members_Raw]'
		IF @SequenceBMStep & 2 > 0
			BEGIN
				INSERT INTO #TimeDay_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Level],
					[PeriodStartDate],
					[PeriodEndDate],
					[NumberOfDays],
					[SendTo],	
					[SendTo_MemberId],
					[TimeQuarter],
					[TimeQuarter_MemberId],
					[TimeSemester],
					[TimeSemester_MemberId],
					[TimeYear],
					[TimeYear_MemberId],
					[TimeFiscalQuarter],
					[TimeFiscalQuarter_MemberId],
					[TimeFiscalSemester],
					[TimeFiscalSemester_MemberId],				
					[TimeFiscalYear],
					[TimeFiscalYear_MemberId],				
					[Parent]
					)
				SELECT 
					[MemberId] = CASE WHEN @FiscalYearStartMonth = 1 THEN ([Mo].[YearMonth] / 100) * 10 + ([Mo].[YearMonth] % 100 + 2) / 3 ELSE (CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END) * 10 + ((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3 END,
					[MemberKey] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) + 'Q' + CONVERT(nvarchar(15), ((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3 ) ELSE 'FY' + CONVERT(nvarchar(15), CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END) + 'FQ' + CONVERT(nvarchar(15), (((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3)) END),
					[Description] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) + 'Q' + CONVERT(nvarchar(15), ((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3 ) ELSE 'FY' + CONVERT(nvarchar(15), CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END) + 'FQ' + CONVERT(nvarchar(15), (((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3)) END),
					[NodeTypeBM] = 18,
					[Level] = 'Quarter',
					[PeriodStartDate] = MIN(Mo.PeriodStartDate),
					[PeriodEndDate] = MAX(Mo.PeriodEndDate),
					[NumberOfDays] = SUM(Mo.NumberOfDays),
					[SendTo] = CONVERT(NVARCHAR(15), MAX(Mo.[YearMonth])),	
					[SendTo_MemberId] = MAX(Mo.[YearMonth]),
					[TimeQuarter] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN 'Q' + CONVERT(nvarchar(15), ((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3) ELSE 'NONE' END),
					[TimeQuarter_MemberId] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN (100 + ((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3) ELSE -1 END),
					[TimeSemester] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN 'S' + CONVERT(nvarchar(15), ([Mo].[YearMonth] % 100 + 5) / 6) ELSE 'NONE' END),
					[TimeSemester_MemberId] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN 100 + ([Mo].[YearMonth] % 100 + 5) / 6 ELSE -1 END),
					[TimeYear] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) ELSE 'NONE' END),
					[TimeYear_MemberId] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN ([Mo].[YearMonth] / 100) ELSE -1 END),
					[TimeFiscalQuarter] = MAX('FQ' + CONVERT(nvarchar(15), ((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3)),
					[TimeFiscalQuarter_MemberId] =  MAX(100 + ((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3),
					[TimeFiscalSemester] = MAX('FS' + CASE WHEN @FiscalYearStartMonth <> 1 THEN CONVERT(nvarchar(15), (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 5) / 6) ELSE CONVERT(nvarchar(15), ([Mo].[YearMonth] % 100 + 5) / 6) END),
					[TimeFiscalSemester_MemberId] = MAX(CASE WHEN @FiscalYearStartMonth <> 1 THEN 100 + (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 5) / 6 ELSE 100 + ([Mo].[YearMonth] % 100 + 5) / 6 END),
					[TimeFiscalYear] = MAX('FY' + CASE WHEN @FiscalYearStartMonth <> 1 THEN CONVERT(nvarchar(15), CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END) ELSE CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) END),
					[TimeFiscalYear_MemberId] = MAX(CASE WHEN @FiscalYearStartMonth <> 1 THEN CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END ELSE ([Mo].[YearMonth] / 100) END),
					[Parent] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) ELSE 'FY' + CONVERT(nvarchar(15), CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END) END)
				FROM
					[#Month] [Mo]
				GROUP BY
					CASE WHEN @FiscalYearStartMonth = 1 THEN ([Mo].[YearMonth] / 100) * 10 + ([Mo].[YearMonth] % 100 + 2) / 3 ELSE (CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END) * 10 + ((CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END) + 2) / 3 END
				ORDER BY
					[MemberId]
			END

	SET @Step = 'Insert Months into temp table [#TimeDay_Members_Raw]'
		IF @SequenceBMStep & 4 > 0
			BEGIN
				INSERT INTO #TimeDay_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Level],
					[PeriodStartDate],
					[PeriodEndDate],
					[NumberOfDays],
					[SendTo],	
					[SendTo_MemberId],
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
					[Parent]
					)
				SELECT DISTINCT TOP 1000000
					[MemberId] = [Mo].[YearMonth],
					[MemberKey] = MAX(CONVERT(nvarchar(15), [Mo].[YearMonth])),
					[Description] = MAX(SUBSTRING(DATENAME(m, CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) + '-' + CONVERT(nvarchar(15), [Mo].[YearMonth] % 100) + '-01'), 1, 3) + ' ' + CONVERT(nvarchar(15), [Mo].[YearMonth] / 100)),
					[NodeTypeBM] = 18,
					[Level] = 'Month',
					[PeriodStartDate] = MIN(Mo.PeriodStartDate),
					[PeriodEndDate] = MAX(Mo.PeriodEndDate),
					[NumberOfDays] = SUM(Mo.NumberOfDays),
					[SendTo] = CONVERT(NVARCHAR(15), MAX(Mo.[YearMonth])),	
					[SendTo_MemberId] = MAX(Mo.[YearMonth]),
					[TimeMonth] = MAX(CASE WHEN [Mo].[YearMonth] % 100 < 10 THEN '0' ELSE '' END + CONVERT(nvarchar(15), [Mo].[YearMonth] % 100)),
					[TimeMonth_MemberId] = MAX(100 + [Mo].[YearMonth] % 100),
					[TimeQuarter] = MAX('Q' + CONVERT(nvarchar(15), ([Mo].[YearMonth] % 100 + 2) / 3)),
					[TimeQuarter_MemberId] = MAX(100 + ([Mo].[YearMonth] % 100 + 2) / 3),
					[TimeTertial] = MAX('T' + CONVERT(nvarchar(15), ([Mo].[YearMonth] % 100 + 3) / 4)),
					[TimeTertial_MemberId] = MAX(100 + ([Mo].[YearMonth] % 100 + 3) / 4),
					[TimeSemester] = MAX('S' + CONVERT(nvarchar(15), ([Mo].[YearMonth] % 100 + 5) / 6)),
					[TimeSemester_MemberId] = MAX(100 + ([Mo].[YearMonth] % 100 + 5) / 6),
					[TimeYear] = MAX(CONVERT(nvarchar(15), [Mo].[YearMonth] / 100)),
					[TimeYear_MemberId] = MAX([Mo].[YearMonth] / 100),
					[TimeFiscalPeriod] = MAX('FP' + CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN '12' ELSE CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 < 10 THEN '0' ELSE '' END + CONVERT(nvarchar(15), ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12) END),
					[TimeFiscalPeriod_MemberId] = MAX(100 + CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN '12' ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END),
					[TimeFiscalQuarter] = MAX('FQ' + CONVERT(nvarchar(15), (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3)),
					[TimeFiscalQuarter_MemberId] = MAX(100 + (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3),
					[TimeFiscalTertial] = MAX('FT' + CONVERT(nvarchar(15), (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 3) / 4)),
					[TimeFiscalTertial_MemberId] = MAX(100 + (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 3) / 4),
					[TimeFiscalSemester] = MAX('FS' + CONVERT(nvarchar(15), (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 5) / 6)),
					[TimeFiscalSemester_MemberId] = MAX(100 + (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 5) / 6),
					[TimeFiscalYear] = MAX('FY' + CONVERT(nvarchar(15), [Mo].[YearMonth]/100 + @FiscalYearNaming + CASE WHEN [Mo].[YearMonth]%100 < @FiscalYearStartMonth THEN -1 ELSE 0 END)),
					[TimeFiscalYear_MemberId] = MAX([Mo].[YearMonth]/100 + @FiscalYearNaming + CASE WHEN [Mo].[YearMonth]%100 < @FiscalYearStartMonth THEN -1 ELSE 0 END),
					[Parent] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) + 'Q' + CONVERT(nvarchar(15), ([Mo].[YearMonth] % 100 + 2) / 3) ELSE 'FY' + CONVERT(nvarchar(15), [Mo].[YearMonth]/100 + @FiscalYearNaming + CASE WHEN [Mo].[YearMonth]%100 < @FiscalYearStartMonth THEN -1 ELSE 0 END) + 'FQ' + CONVERT(nvarchar(15), (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3) END)
				FROM
					[#Month] [Mo]
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -7) AND M.MemberId = [Mo].[YearMonth] AND M.[Label] = CONVERT(nvarchar(15), [Mo].[YearMonth])
				GROUP BY
					[Mo].[YearMonth]
				ORDER BY
					[MemberId]
			END

	SET @Step = 'Insert Days into temp table [#TimeDay_Members_Raw]'
		IF @SequenceBMStep & 8 > 0
			BEGIN
				IF CURSOR_STATUS('global','Days_cursor') >= -1 DEALLOCATE Days_cursor
				DECLARE Days_cursor CURSOR FOR
				SELECT
					MonthID = M.[YearMonth]
				FROM
					#Month M
				ORDER BY 
					M.[YearMonth]

				OPEN Days_cursor
				FETCH NEXT FROM Days_cursor INTO @MonthID

				WHILE @@FETCH_STATUS = 0
					BEGIN
						TRUNCATE TABLE #Day_Member

						EXEC [spGet_AddDays] @MonthID = @MonthID, @DateFirst = @DateFirst, @WeekFirst = @WeekFirst

						SET @Step = 'Insert into temp table ' + CONVERT(nvarchar, @MonthID)
							INSERT INTO #TimeDay_Members_Raw
								(
								[MemberId],
								[MemberKey],
								[Description],
								[NodeTypeBM],
								[Level],
								[PeriodStartDate],
								[PeriodEndDate],
								[NumberOfDays],
								[SendTo],	
								[SendTo_MemberId],
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
								[Parent]
								)
							SELECT TOP 1000000
								[MemberId] = [DM].[DayId],
								[MemberKey] = CONVERT(nvarchar, [DM].[DayId]),
								[Description] = [DM].[DayName],
								[NodeTypeBM] = 1,
								[Level] = 'Day',
								[PeriodStartDate] = CONVERT(date, CONVERT(nvarchar(10), [DM].[DayId]), 112),
								[PeriodEndDate] = CONVERT(date, CONVERT(nvarchar(10), [DM].[DayId]), 112),
								[NumberOfDays] = 1,
								[SendTo] = CONVERT(nvarchar, [DM].[DayId]),	
								[SendTo_MemberId] = [DM].[DayId],
								[TimeWeekDay] = [DM].[TimeWeekDay],
								[TimeWeekDay_MemberId] = [DM].[TimeWeekDay_MemberId],
								[TimeWeek] = [DM].[TimeWeek],
								[TimeWeek_MemberId] = [DM].[TimeWeek_MemberId],
								[TimeMonth] = CASE WHEN [DM].[DayId] / 100 % 100 < 10 THEN '0' ELSE '' END + CONVERT(nvarchar, [DM].[DayId] / 100 % 100),
								[TimeMonth_MemberId] = 100 + [DM].[DayId] / 100 % 100,
								[TimeQuarter] = 'Q' + CONVERT(nvarchar, ([DM].[DayId] / 100 % 100 + 2) / 3),
								[TimeQuarter_MemberId] = 100 + ([DM].[DayId] / 100 % 100 + 2) / 3,
								[TimeTertial] = 'T' + CONVERT(nvarchar, ([DM].[DayId] / 100 % 100 + 3) / 4),
								[TimeTertial_MemberId] = 100 + ([DM].[DayId] / 100 % 100 + 3) / 4,
								[TimeSemester] = 'S' + CONVERT(nvarchar, ([DM].[DayId] / 100 % 100 + 5) / 6),
								[TimeSemester_MemberId] = 100 + ([DM].[DayId] / 100 % 100 + 5) / 6,
								[TimeYear] = CONVERT(nvarchar, [DM].[DayId] / 10000),
								[TimeYear_MemberId] = [DM].[DayId] / 10000,
								[TimeFiscalPeriod] = 'FP' + CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN '12' ELSE CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 < 10 THEN '0' ELSE '' END  + CONVERT(nvarchar, ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12) END,
								[TimeFiscalPeriod_MemberId] = 100 + CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END,
								[TimeFiscalQuarter] = 'FQ' + CONVERT(nvarchar, (CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3),
								[TimeFiscalQuarter_MemberId] = 100 + (CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3,
								[TimeFiscalTertial] = 'FT' + CONVERT(nvarchar, (CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 3) / 4),
								[TimeFiscalTertial_MemberId] = 100 + (CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 3) / 4,
								[TimeFiscalSemester] = 'FS' + CONVERT(nvarchar, (CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 5) / 6),
								[TimeFiscalSemester_MemberId] = 100 + (CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 5) / 6,
								--[TimeFiscalYear] = 'FY' + CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar, [DM].[DayId] / 100 / 100) ELSE CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, [DM].[DayId] / 100 / 100) + '-' + CONVERT(nvarchar, [DM].[DayId] / 100 % 100) + '-01'))) END,
								--[TimeFiscalYear_MemberId] = CASE WHEN @FiscalYearStartMonth = 1 THEN [DM].[DayId] / 100 / 100 ELSE YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, [DM].[DayId] / 100 / 100) + '-' + CONVERT(nvarchar, [DM].[DayId] / 100 % 100) + '-01')) END,
								[TimeFiscalYear] = ('FY' + CONVERT(nvarchar(15), [DM].[DayId] / 100 / 100 + @FiscalYearNaming + CASE WHEN [DM].[DayId] / 100 % 100 < @FiscalYearStartMonth THEN -1 ELSE 0 END)),
								[TimeFiscalYear_MemberId] = ([DM].[DayId] / 100 / 100 + @FiscalYearNaming + CASE WHEN [DM].[DayId] / 100 % 100 < @FiscalYearStartMonth THEN -1 ELSE 0 END),
								--[Parent] = (CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [DM].[DayId] / 100 / 100) + 'Q' + CONVERT(nvarchar(15), ([DM].[DayId] / 100 % 100 + 2) / 3) ELSE 'FY' + CONVERT(nvarchar(15), [DM].[DayId] / 100 / 100 + @FiscalYearNaming + CASE WHEN [DM].[DayId] / 100 % 100 < @FiscalYearStartMonth THEN -1 ELSE 0 END) + 'FQ' + CONVERT(nvarchar(15), (CASE WHEN ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([DM].[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3) END)
								[Parent] = CONVERT(NVARCHAR, [DM].[DayId] / 100)
							FROM
								#Day_Member DM
							ORDER BY
								[DM].[DayId]	

						FETCH NEXT FROM Days_cursor INTO @MonthID
						END

				CLOSE Days_cursor
				DEALLOCATE Days_cursor
			END

	SET @Step = 'Insert Weeks into temp table [#TimeDay_Members_Raw]'
		IF @SequenceBMStep & 16 > 0
			BEGIN
				INSERT INTO #TimeDay_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Level],
					[TimeWeek],
					[TimeWeek_MemberId],
					[TimeYear],
					[TimeYear_MemberId],
					--[TimeFiscalYear],
					--[TimeFiscalYear_MemberId],
					[Parent]
					)
				SELECT 
					--[MemberId] = REPLACE(CASE WHEN @FiscalYearNaming <> 0 THEN (REPLACE(TD.TimeFiscalYear, 'FY', '')) ELSE TD.TimeYear END + TD.TimeWeek, 'W', '0'),
					[MemberId] = REPLACE(TD.TimeYear + TD.TimeWeek, 'W', '0'),
					--[MemberKey] = CASE WHEN @FiscalYearNaming <> 0 THEN TD.TimeFiscalYear ELSE TD.TimeYear END + TD.TimeWeek,
					[MemberKey] = TD.TimeYear + TD.TimeWeek,
					[Description] = TD.TimeYear + ' ' + TD.TimeWeek,
					[NodeTypeBM] = 18,
					[Level] = 'Week',
					[TimeWeek] = TD.TimeWeek,
					[TimeWeek_MemberId] = MAX(TD.TimeWeek_MemberId),
					[TimeYear] = TD.TimeYear,
					[TimeYear_MemberId] = MAX(TD.TimeYear_MemberId),
					--[TimeFiscalYear] = TD.TimeFiscalYear,
					--[TimeFiscalYear_MemberId] = MAX(TD.TimeFiscalYear_MemberId),
					--[Parent] = CASE WHEN @FiscalYearNaming <> 0 THEN TD.TimeFiscalYear ELSE TD.TimeYear END
					[Parent] = TD.TimeYear
				FROM
					#TimeDay_Members_Raw TD
				WHERE
					[Level] = 'Day'
				GROUP BY
					--TD.TimeFiscalYear,
					TD.TimeYear,
					TD.TimeWeek
				ORDER BY
					--TD.TimeFiscalYear,
					TD.TimeYear,
					TD.TimeWeek

				IF @DebugBM & 2 > 0 SELECT [#TimeDay_Members_Raw] = '#TimeDay_Members_Raw(Week)', * FROM #TimeDay_Members_Raw WHERE [Level] = 'Week'
			END

	SET @Step = 'Update 4WeekPeriod in temp table [#TimeDay_Members_Raw]'
		IF @SequenceBMStep & 32 > 0
			BEGIN
				UPDATE TD
				SET
					[Time4WeekPeriod] = CASE WHEN [TimeWeek_MemberId] = 153 THEN 'P13' ELSE 'P' + CONVERT(nvarchar(15), (([TimeWeek_MemberId] % 100) + 3) / 4) END,
					[Time4WeekPeriod_MemberId] = 100 + CASE WHEN [TimeWeek_MemberId] = 153 THEN 13 ELSE ([TimeWeek_MemberId] % 100 + 3) / 4 END
				FROM
					#TimeDay_Members_Raw TD
				WHERE
					[TimeWeek_MemberId] BETWEEN 101 AND 153
			END
/*
	SET @Step = 'Update SendTo'
		SELECT
			MemberKey = sub.MemberKey, 
			SendTo = sub.SendTo,
			[Level] = sub.[Level]
		INTO 
			#SendTo
		FROM
			(	
			--Day
			SELECT
			 MemberKey = MemberKey, 
			 SendTo = MAX(MemberKey),
			 [Level] = 'Day'
			FROM
			 #TimeDay_Members_Raw 
			WHERE
			 ISNUMERIC(MemberKey) <> 0 AND LEN(MemberKey) = 8
			GROUP BY
			 MemberKey

			--Week
			UNION SELECT
			 MemberKey = TimeYear + TimeWeek, 
			 SendTo = MAX(MemberKey),
			 [Level] = 'Week'
			FROM
			 #TimeDay_Members_Raw 
			WHERE
			 ISNUMERIC(MemberKey) <> 0 AND LEN(MemberKey) = 8
			GROUP BY
			 TimeYear + TimeWeek

			--Month
			UNION SELECT
			 MemberKey = SUBSTRING(MemberKey, 1, 6), 
			 SendTo = MAX(MemberKey),
			 [Level] = 'Month'
			FROM
			 #TimeDay_Members_Raw 
			WHERE
			 ISNUMERIC(MemberKey) <> 0 AND LEN(MemberKey) = 8
			GROUP BY
			 SUBSTRING(MemberKey, 1, 6)
 
			--Quarter
			UNION SELECT
			 MemberKey = Q.[Quarter], 
			 SendTo = MAX(D.MemberKey),
			 [Level] = 'Quarter' 
			FROM
			 #TimeDay_Members_Raw D
			 INNER JOIN (SELECT [Quarter] = MemberKey FROM #TimeDay_Members_Raw WHERE SUBSTRING(MemberKey, 5, 1) = 'Q') Q ON 
				SUBSTRING(Q.[Quarter], 1, 4) = SUBSTRING(D.[MemberKey], 1, 4) AND 
				SUBSTRING(Q.[Quarter], 6, 1) = CONVERT(NVARCHAR, (CONVERT(INT, SUBSTRING(D.MemberKey, 5, 2)) + 2) / 3)
			WHERE
			 ISNUMERIC(D.MemberKey) <> 0 AND LEN(D.MemberKey) = 8
			GROUP BY
			 Q.[Quarter]

			--Year
			UNION SELECT
			 MemberKey = SUBSTRING(MemberKey, 1, 4), 
			 SendTo = MAX(MemberKey),
			 [Level] = 'Year' 
			FROM
			 #TimeDay_Members_Raw 
			WHERE
			 ISNUMERIC(MemberKey) <> 0 AND LEN(MemberKey) = 8
			GROUP BY
			 SUBSTRING(MemberKey, 1, 4)
			) sub

		UPDATE [D]
			SET
				SendTo = SendTo.SendTo,
				SendTo_MemberId = ISNULL([Time].MemberId, -1)
			FROM
				#TimeDay_Members_Raw [D] 
				INNER JOIN #SendTo SendTo ON SendTo.MemberKey COLLATE DATABASE_DEFAULT = [D].MemberKey
				LEFT JOIN #TimeDay_Members_Raw [Time] ON [Time].MemberKey = SendTo.SendTo

	SET @Step = 'Update StartDate, EndDate and NumberOfDays.'
		UPDATE [TM]
		SET 
			[PeriodStartDate] =
				CASE [Level]
					WHEN 'Year' THEN CONVERT(date, CONVERT(nvarchar(10), sub.YMin * 100 + 1), 112)
					WHEN 'Quarter' THEN CONVERT(date, CONVERT(nvarchar(10), sub.QMin * 100 + 1), 112)
					WHEN 'Month' THEN CONVERT(date, CONVERT(nvarchar(10), TM.MemberID * 100 + 1), 112)
					WHEN 'Week' THEN sub.WMin
				END,
			[PeriodEndDate] =
				CASE [Level]
					WHEN 'Year' THEN DATEADD(day, -1, DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), sub.YMax * 100 + 1), 112)))
					WHEN 'Quarter' THEN DATEADD(day, -1, DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), sub.QMax * 100 + 1), 112)))
					WHEN 'Month' THEN DATEADD(day, -1, DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), TM.MemberID * 100 + 1), 112)))
					WHEN 'Week' THEN sub.WMax
				END,
			[NumberOfDays] =
				CASE [Level]
					WHEN 'Year' THEN DATEDIFF(day, CONVERT(date, CONVERT(nvarchar(10), sub.YMin * 100 + 1), 112), DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), sub.YMax * 100 + 1), 112)))
					WHEN 'Quarter' THEN DATEDIFF(day, CONVERT(date, CONVERT(nvarchar(10), sub.QMin * 100 + 1), 112), DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), sub.QMax * 100 + 1), 112)))
					WHEN 'Month' THEN DATEDIFF(day, CONVERT(date, CONVERT(nvarchar(10), TM.MemberID * 100 + 1), 112), DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), TM.MemberID * 100 + 1), 112)))
					WHEN 'Week' THEN DATEDIFF(day, sub.WMin, sub.WMax) + 1
					ELSE 0
				END
		FROM	
			[#TimeDay_Members_Raw] TM
			INNER JOIN
				(
				SELECT
					TM.MemberID,
					QMin = MIN(Q.MemberID),
					QMax = MAX(Q.MemberID),
					YMin = MIN(Y.YMin),
					YMax = MAX(Y.YMax),
					WMin = MIN(W.WMin),
					WMax = MAX(W.WMax)
				FROM	
					[#TimeDay_Members_Raw] TM
					LEFT JOIN [#TimeDay_Members_Raw] Q ON Q.[Level] = 'Month' AND Q.Parent = TM.MemberKey
					LEFT JOIN 
						(SELECT MemberKey = Q.Parent, YMin = MIN(M.MemberID), YMax = MAX(M.MemberID) 
						FROM [#TimeDay_Members_Raw] M 
							INNER JOIN [#TimeDay_Members_Raw] Q ON Q.[Level] = 'Quarter' AND Q.MemberKey = M.Parent 
						WHERE M.[Level] = 'Month'
						GROUP BY
							Q.Parent) Y ON Y.MemberKey = TM.MemberKey
					LEFT JOIN 
						(SELECT MemberKey = TimeYear + TimeWeek, WMin = CONVERT(date, CONVERT(nvarchar(10), MIN(MemberID)), 112), WMax = CONVERT(date, CONVERT(nvarchar(10), MAX(MemberID)), 112) 
						FROM [#TimeDay_Members_Raw] WHERE [Level] = 'Day' GROUP BY TimeYear + TimeWeek) W ON W.MemberKey = TM.MemberKey
				WHERE
					TM.[Level] IN ('Year', 'Quarter', 'Month', 'Week')
				GROUP BY
					TM.MemberID

				) sub ON sub.MemberId = TM.MemberId
		WHERE
			TM.[Level] IN ('Year', 'Quarter', 'Month', 'Week')
*/
	SET @Step = 'Static Rows'
		IF @StaticMemberYN <> 0
			BEGIN
				INSERT INTO [#TimeDay_Members_Raw]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Level],
					[Parent]
					)
				SELECT 
					[MemberId] = MAX([MemberId]),
					[MemberKey] = [Label],
					[Description] = MAX(REPLACE([Description], '@All_Dimension', 'All Time')),
					[HelpText] = MAX([HelpText]),
					[NodeTypeBM] = MAX([NodeTypeBM]),
					[Level] = CASE WHEN [Label] = 'All_' THEN 'TopNode' ELSE NULL END,
					[Parent] = MAX([Parent])
				FROM 
					Member
				WHERE
					DimensionID IN (0, @DimensionID)
				GROUP BY
					[Label]

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#TimeDay_Members_Raw',
					*
				FROM
					#TimeDay_Members_Raw
				ORDER BY
					MemberID

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#TimeDay_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Level],
					[PeriodStartDate],
					[PeriodEndDate],
					[NumberOfDays],
					[SendTo],	
					[SendTo_MemberId],
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
					[Level] = [MaxRaw].[Level],
					[PeriodStartDate] = [MaxRaw].[PeriodStartDate],
					[PeriodEndDate] = [MaxRaw].[PeriodEndDate],
					[NumberOfDays] = [MaxRaw].[NumberOfDays],
					[SendTo] = [MaxRaw].[SendTo],	
					[SendTo_MemberId] = [MaxRaw].[SendTo_MemberId],
					[TimeWeekDay] = [MaxRaw].[TimeWeekDay],
					[TimeWeekDay_MemberId] = [MaxRaw].[TimeWeekDay_MemberId],
					[TimeWeek] = [MaxRaw].[TimeWeek],
					[TimeWeek_MemberId] = [MaxRaw].[TimeWeek_MemberId],
					[TimeMonth] = [MaxRaw].[TimeMonth],
					[TimeMonth_MemberId] = [MaxRaw].[TimeMonth_MemberId],
					[TimeQuarter] = [MaxRaw].[TimeQuarter],
					[TimeQuarter_MemberId] = [MaxRaw].[TimeQuarter_MemberId],
					[TimeTertial] = [MaxRaw].[TimeTertial],
					[TimeTertial_MemberId] = [MaxRaw].[TimeTertial_MemberId],
					[TimeSemester] = [MaxRaw].[TimeSemester],
					[TimeSemester_MemberId] = [MaxRaw].[TimeSemester_MemberId],
					[TimeYear] = [MaxRaw].[TimeYear],
					[TimeYear_MemberId] = [MaxRaw].[TimeYear_MemberId],
					[TimeFiscalPeriod] = [MaxRaw].[TimeFiscalPeriod],
					[TimeFiscalPeriod_MemberId] = [MaxRaw].[TimeFiscalPeriod_MemberId],
					[TimeFiscalQuarter] = [MaxRaw].[TimeFiscalQuarter],
					[TimeFiscalQuarter_MemberId] = [MaxRaw].[TimeFiscalQuarter_MemberId],
					[TimeFiscalTertial] = [MaxRaw].[TimeFiscalTertial],
					[TimeFiscalTertial_MemberId] = [MaxRaw].[TimeFiscalTertial_MemberId],
					[TimeFiscalSemester] = [MaxRaw].[TimeFiscalSemester],
					[TimeFiscalSemester_MemberId] = [MaxRaw].[TimeFiscalSemester_MemberId],
					[TimeFiscalYear] = [MaxRaw].[TimeFiscalYear],
					[TimeFiscalYear_MemberId] = [MaxRaw].[TimeFiscalYear_MemberId],
					[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, [MaxRaw].[NodeTypeBM], [MaxRaw].[MemberKey]),
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
						[Level] = MAX([Raw].[Level]),
						[PeriodStartDate] = MAX([Raw].[PeriodStartDate]),
						[PeriodEndDate] = MAX([Raw].[PeriodEndDate]),
						[NumberOfDays] = MAX([Raw].[NumberOfDays]),
						[SendTo] = MAX([Raw].[SendTo]),	
						[SendTo_MemberId] = MAX([Raw].[SendTo_MemberId]),
						[TimeWeekDay] = MAX([Raw].[TimeWeekDay]),
						[TimeWeekDay_MemberId] = MAX([Raw].[TimeWeekDay_MemberId]),
						[TimeWeek] = MAX([Raw].[TimeWeek]),
						[TimeWeek_MemberId] = MAX([Raw].[TimeWeek_MemberId]),
						[TimeMonth] = MAX([Raw].[TimeMonth]),
						[TimeMonth_MemberId] = MAX([Raw].[TimeMonth_MemberId]),
						[TimeQuarter] = MAX([Raw].[TimeQuarter]),
						[TimeQuarter_MemberId] = MAX([Raw].[TimeQuarter_MemberId]),
						[TimeTertial] = MAX([Raw].[TimeTertial]),
						[TimeTertial_MemberId] = MAX([Raw].[TimeTertial_MemberId]),
						[TimeSemester] = MAX([Raw].[TimeSemester]),
						[TimeSemester_MemberId] = MAX([Raw].[TimeSemester_MemberId]),
						[TimeYear] = MAX([Raw].[TimeYear]),
						[TimeYear_MemberId] = MAX([Raw].[TimeYear_MemberId]),
						[TimeFiscalPeriod] = MAX([Raw].[TimeFiscalPeriod]),
						[TimeFiscalPeriod_MemberId] = MAX([Raw].[TimeFiscalPeriod_MemberId]),
						[TimeFiscalQuarter] = MAX([Raw].[TimeFiscalQuarter]),
						[TimeFiscalQuarter_MemberId] = MAX([Raw].[TimeFiscalQuarter_MemberId]),
						[TimeFiscalTertial] = MAX([Raw].[TimeFiscalTertial]),
						[TimeFiscalTertial_MemberId] = MAX([Raw].[TimeFiscalTertial_MemberId]),
						[TimeFiscalSemester] = MAX([Raw].[TimeFiscalSemester]),
						[TimeFiscalSemester_MemberId] = MAX([Raw].[TimeFiscalSemester_MemberId]),
						[TimeFiscalYear] = MAX([Raw].[TimeFiscalYear]),
						[TimeFiscalYear_MemberId] = MAX([Raw].[TimeFiscalYear_MemberId]),
						[Parent] = MAX([Raw].[Parent])
					FROM
						[#TimeDay_Members_Raw] [Raw]
					GROUP BY
						[Raw].[MemberKey]
					) [MaxRaw]
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = @DimensionID AND M.[Label] = [MaxRaw].MemberKey
				WHERE
					[MaxRaw].[MemberKey] IS NOT NULL
				ORDER BY
					CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE [#Month]
		DROP TABLE #Digit
		--DROP TABLE #SendTo
		DROP TABLE #TimeDay_Members_Raw

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @CalledYN = 0
			BEGIN
				EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
			END
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
