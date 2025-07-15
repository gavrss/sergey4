SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Time_Raw]

	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StartYear int = 2019,
	@AddYear int = 0, --Number of years to add after current year
	@FiscalYearStartMonth int = 1,
	@FiscalYearNaming int = 0,
	@SequenceBMStep int = 65535, --1 = Years, 2 = Quarters, 4 = Months
	@StaticMemberYN bit = 1,
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000670,
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
EXEC [spIU_Dim_Time_Raw] @UserID=-10, @InstanceID=478, @VersionID=1032, @StartYear=2019, @FiscalYearStartMonth = 1, @FiscalYearNaming = 1, @AddYear=2, @DebugBM=0
EXEC [spIU_Dim_Time_Raw] @UserID=-10, @InstanceID=478, @VersionID=1032, @FiscalYearStartMonth = 2, @FiscalYearNaming = 1, @DebugBM=7

EXEC [spIU_Dim_Time_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@DimensionID int = -7, --Time
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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2162'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to get Members to load into Time Dimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'Changed quarter creation for @FiscalYearStartMonth <> 1.'
		IF @Version = '2.0.2.2148' SET @Description = 'Made generic.'
		IF @Version = '2.0.2.2149' SET @Description = 'Changed numbering on @SequenceBMStep.'
		IF @Version = '2.0.3.2152' SET @Description = 'Added @FiscalYearNaming.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-369: Set correct TimeFiscal* properties. DB-310: Added @FiscalYearNaming. Removed CONSTRAINTS from temp table.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.0.2162' SET @Description = 'Get [PeriodStartDate] from ERP database. Modified SELECT query for @YearMonthFrom.'

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

		SET @FiscalYearNaming = CASE WHEN @FiscalYearStartMonth = 1 THEN 0 ELSE @FiscalYearNaming END

		SELECT
			--@YearMonthFrom = (@StartYear - @FiscalYearNaming) * 100 + @FiscalYearStartMonth,
			@YearMonthFrom = (@StartYear * 100) + @FiscalYearStartMonth,
			@YearMonthTo = CASE WHEN @FiscalYearStartMonth <> 1 THEN (YEAR(GETDATE()) + @AddYear + 1) * 100 + (@FiscalYearStartMonth - 1) ELSE (YEAR(GETDATE()) + @AddYear) * 100 + 12 END

		IF OBJECT_ID(N'TempDB.dbo.#Time_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@SourceTypeID] = @SourceTypeID,
				[@CalledYN] = @CalledYN,
				[@StartYear] = @StartYear,
				[@AddYear] = @AddYear,
				[@FiscalYearNaming] = @FiscalYearNaming,
				[@FiscalYearStartMonth] = @FiscalYearStartMonth,
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

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Month', * FROM #Month ORDER BY [FiscalYear], [FiscalPeriod], [YearMonth]
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

	SET @Step = 'Set PeriodStartDate'
		UPDATE M
		SET
			[PeriodStartDate] = ISNULL([PeriodStartDate], CONVERT(NVARCHAR(15), M.[YearMonth] / 100) + '-' + CONVERT(NVARCHAR(15), M.[YearMonth] % 100) + '-1'),
            [PeriodEndDate] = ISNULL([PeriodEndDate], DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), M.[YearMonth] / 100) + '-' + CONVERT(NVARCHAR(15), M.[YearMonth] % 100) + '-1'))),
			[NumberOfDays] = ISNULL([NumberOfDays], DAY(DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), M.[YearMonth] / 100) + '-' + CONVERT(NVARCHAR(15), M.[YearMonth] % 100) + '-1'))))
		FROM 
			[#Month] M			

		IF @DebugBM & 1 > 0 SELECT TempTable = '#Month', * FROM #Month ORDER BY [YearMonth]

	SET @Step = 'Create table #Time_Members_Raw'
		CREATE TABLE #Time_Members_Raw
			(
			[MemberId] int,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Level] [nvarchar](10) COLLATE DATABASE_DEFAULT,
			[PeriodStartDate] [date] NULL,
			[PeriodEndDate] [date] NULL,
			[NumberOfDays] [int] NULL,
			[SendTo] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,	
			[SendTo_MemberId] int DEFAULT -1,
			[TimeMonth] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeMonth_MemberId] int DEFAULT -1,
			[TimeQuarter] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeQuarter_MemberId] int DEFAULT -1,
			[TimeTertial] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeTertial_MemberId] int DEFAULT -1,
			[TimeSemester] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeSemester_MemberId] int DEFAULT -1,
			[TimeYear] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeYear_MemberId] int DEFAULT -1,
			[TimeFiscalPeriod] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalPeriod_MemberId] int DEFAULT -1,
			[TimeFiscalQuarter] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalQuarter_MemberId] int DEFAULT -1,
			[TimeFiscalTertial] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalTertial_MemberId] int DEFAULT -1,
			[TimeFiscalSemester] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalSemester_MemberId] int DEFAULT -1,
			[TimeFiscalYear] nvarchar(255) DEFAULT 'NONE' COLLATE DATABASE_DEFAULT,
			[TimeFiscalYear_MemberId] int DEFAULT -1,
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Insert Years into temp table [#Time_Members_Raw]'
		IF @SequenceBMStep & 1 > 0
			BEGIN
				INSERT INTO #Time_Members_Raw
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
					--[Description] = MAX(CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15),Mo.[YearMonth] / 100) ELSE 'FY' + CONVERT(nvarchar(15), CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END) END),
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

	SET @Step = 'Insert Quarters into temp table [#Time_Members_Raw]'
		IF @SequenceBMStep & 2 > 0
			BEGIN
				INSERT INTO #Time_Members_Raw
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
					--[Y] = CASE WHEN ([Mo].[YearMonth] % 100) >= @FiscalYearStartMonth THEN [Mo].[YearMonth] / 100 + @FiscalYearNaming ELSE [Mo].[YearMonth] / 100 + CASE WHEN @FiscalYearNaming = 0 THEN -1 ELSE 0 END END,
					--[M] = CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END,				
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

	SET @Step = 'Insert Months into temp table [#Time_Members_Raw]'
		IF @SequenceBMStep & 4 > 0
			BEGIN
				INSERT INTO #Time_Members_Raw
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
					[NodeTypeBM] = 1,
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
					--[TimeFiscalYear] = 'FY' + CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) ELSE CONVERT(nvarchar(15), YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) + '-' + CONVERT(nvarchar(15), [Mo].[YearMonth] % 100) + '-01'))) END,
					--[TimeFiscalYear_MemberId] = CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) ELSE CONVERT(nvarchar(15), YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) + '-' + CONVERT(nvarchar(15), [Mo].[YearMonth] % 100) + '-01'))) END,
					--[Parent] = CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) + 'Q' + CONVERT(nvarchar(15), ([Mo].[YearMonth] % 100 + 2) / 3) ELSE 'FY' + CONVERT(nvarchar(15), YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar(15), [Mo].[YearMonth] / 100) + '-' + CONVERT(nvarchar(15), [Mo].[YearMonth] % 100) + '-01'))) + 'FQ' + CONVERT(nvarchar(15), (CASE WHEN ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE ([Mo].[YearMonth] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3) END
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

	SET @Step = 'Static Rows'
		IF @StaticMemberYN <> 0
			BEGIN
				INSERT INTO [#Time_Members_Raw]
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
				IF @DebugBM & 2 > 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Time_Members_Raw',
					*
				FROM
					#Time_Members_Raw
				ORDER BY
					MemberID

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#Time_Members]
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
						[#Time_Members_Raw] [Raw]
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
		DROP TABLE #Time_Members_Raw

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
