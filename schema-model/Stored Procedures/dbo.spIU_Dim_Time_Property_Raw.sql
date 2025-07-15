SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Time_Property_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StartYear int = 2017,
	@AddYear int = 2, --Number of years to add after current year
	@FiscalYearStartMonth int = 1,
	@FiscalYearNaming int = 0,
	@DimensionID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000672,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM = 3 (include high and low prio, exclude sub routines)
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID=-45, @StartYear = 2019, @FiscalYearStartMonth = 7, @FiscalYearNaming = 1, @AddYear=2, @DebugBM=3

EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -45	--TimeFiscalYear		Fiscal Year FYYYYY
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -44	--TimeFiscalTertial		Fiscal Tertial FT1-FT3
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -43	--TimeFiscalSemester	Fiscal Semester FS1-FS2
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -42	--TimeFiscalQuarter		Fiscal Quarter FQ1-FQ4
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -41	--TimeFiscalPeriod		Fiscal Period FP01-FP12
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -40	--TimeYear				Calendar Year YYYY
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -39	--TimeTertial			Calendar Tertial T1-T3
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -38	--TimeSemester			Calendar Semester S1-S2
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -37	--TimeQuarter			Calendar Quarter Q1-Q4
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -30	--TimeWeek				Week number W01-W53
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -25	--TimeWeekDay			Weekday 1-7
EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = -11	--TimeMonth				Calendar Month 01-12

EXEC [spIU_Dim_Time_Property_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@DateFirst int = 1,  --In EFP, Monday is always day no. 1
	@DimensionName nvarchar(100),

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
	@ToBeChanged nvarchar(255) = 'To set FiscalYear, include referencing to Instance.FiscalYearNaming ',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to get Members to load into Dimension Tables',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Made generic.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-310: Added @FiscalYearNaming.'
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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SET DATEFIRST @DateFirst 

		SELECT @DimensionName = DimensionName FROM Dimension WHERE DimensionID = @DimensionID

		IF OBJECT_ID(N'TempDB.dbo.#Time_Property', N'U') IS NULL SET @CalledYN = 0

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

	SET @Step = 'Create table #Time_Property_Raw'
		CREATE TABLE #Time_Property_Raw
			(
			[MemberId] int,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'TimeWeekDay, 1 - 7'
		IF @DimensionID IN (-25)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[MemberKey] = CONVERT(nvarchar(255), D1.Number),
						[Description] = DATENAME(weekday, CONVERT(smalldatetime, '2013-07-' + CONVERT(nvarchar, D1.Number))),
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 7
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -25) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeWeek W01 - W53'
		IF @DimensionID IN (-30)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D2.Number * 10 + D1.Number + 1,
						[MemberKey] = 'W' + CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN '0' ELSE '' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1),
						[Description] = 'Week ' + CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN '0' ELSE '' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1),
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1,
						#Digit D2
					WHERE
						D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 53
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -30) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeMonth'
		IF @DimensionID IN (-11)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D2.Number * 10 + D1.Number + 1,
						[MemberKey] = CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN '0' ELSE '' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1),
						[Description] = DATENAME(month, CONVERT(smalldatetime, '2000-' + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1) + '-01')),
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1,
						#Digit D2
					WHERE
						D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -11) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeQuarter Q1 - Q4'
		IF @DimensionID IN (-37)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[MemberKey] = 'Q' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN 'st' WHEN 2 THEN 'nd' WHEN 3 THEN 'rd' WHEN 4 THEN 'th' ELSE '' END + ' Quarter',
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 4
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -37) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeTertial T1 -T3'
		IF @DimensionID IN (-39)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[MemberKey] = 'T' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN 'st' WHEN 2 THEN 'nd' WHEN 3 THEN 'rd' ELSE '' END + ' Tertial',
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 3
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -39) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END
	
	SET @Step = 'TimeSemester S1 - S2'
		IF @DimensionID IN (-38)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[MemberKey] = 'S' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN 'st' WHEN 2 THEN 'nd' ELSE '' END + ' Semester',
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 2
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -38) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeYear @StartYear - CurrentYear + @AddYear'
		IF @DimensionID IN (-40)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1, 
						MemberKey = CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1),
						[Description] = CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1),
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1,
						#Digit D2,
						#Digit D3,
						#Digit D4
					WHERE
						D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear AND YEAR(GetDate()) + @AddYear + CASE WHEN @FiscalYearStartMonth = 1 THEN 0 ELSE 1 END
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -40) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeFiscalPeriod FP01 - FP12'
		IF @DimensionID IN (-41)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D2.Number * 10 + D1.Number + 1,
						[MemberKey] = 'FP' + CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN '0' ELSE '' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1),
						[Description] = 'Period ' + CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN '0' ELSE '' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1) + ' (' + DATENAME(month, DATEADD(month, @FiscalYearStartMonth - 1, CONVERT(smalldatetime, '2000-' + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1) + '-01'))) + ')',
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1,
						#Digit D2
					WHERE
						D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -41) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeFiscalQuarter FQ1 - FQ4'
		IF @DimensionID IN (-42)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number, 
						[MemberKey] = 'FQ' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN 'st' WHEN 2 THEN 'nd' WHEN 3 THEN 'rd' WHEN 4 THEN 'th' ELSE '' END + ' Fiscal Quarter',
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 4
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -42) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeFiscalTertial FT1 - FT3'
		IF @DimensionID IN (-44)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[MemberKey] = 'FT' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN 'st' WHEN 2 THEN 'nd' WHEN 3 THEN 'rd' ELSE '' END + ' Fiscal Tertial',
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 3
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -44) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeFiscalSemester FS1 - FS2'
		IF @DimensionID IN (-43)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number, 
						[MemberKey] = 'FS' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN 'st' WHEN 2 THEN 'nd' ELSE '' END + ' Fiscal Semester',
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 2
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -43) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'TimeFiscalYear FY + @StartYear - FY + CurrentYear + @AddYear'
		IF @DimensionID IN (-45)
			BEGIN
				TRUNCATE TABLE #Time_Property_Raw
				INSERT INTO #Time_Property_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[MemberKey] = sub.[MemberKey],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[NodeTypeBM] = MAX(sub.[NodeTypeBM]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1,
						[MemberKey] = 'FY' + CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1),
						[Description] = 'Yr ' + CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1) ELSE CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + CASE WHEN @FiscalYearNaming = 1 THEN 0 ELSE 1 END) + '/' + CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + CASE WHEN @FiscalYearNaming = 1 THEN 1 ELSE 2 END) END,
						[NodeTypeBM] = 1,
						[Parent] = 'All_'
					FROM
						#Digit D1,
						#Digit D2,
						#Digit D3,
						#Digit D4
					WHERE
						(@FiscalYearStartMonth = 1 AND
						D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear AND YEAR(GetDate()) + @AddYear) OR
						(@FiscalYearStartMonth <> 1 AND
						D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear + @FiscalYearNaming AND YEAR(GetDate()) + @AddYear + @FiscalYearNaming)
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -45) AND M.MemberId = sub.MemberId AND M.[Label] = sub.MemberKey
				GROUP BY
					sub.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Add static rows'
		IF @DimensionID IS NOT NULL
			BEGIN
				INSERT INTO [#Time_Property_Raw]
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
					[Description] = MAX(REPLACE([Description], '@All_Dimension', 'All ' + @DimensionName + 's')),
					[HelpText] = MAX([HelpText]),
					[NodeTypeBM] = MAX([NodeTypeBM]),
					[Parent] = MAX([Parent])
				FROM 
					Member
				WHERE
					DimensionID IN (0, @DimensionID) AND
					SelectYN <> 0
				GROUP BY
					[Label]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Time_Property_Raw',
					*
				FROM
					#Time_Property_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#Time_Property]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
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
					[HelpText] = CASE WHEN [MaxRaw].[HelpText] = '' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END,
					[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
					[SBZ] = [MaxRaw].[SBZ],
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
						[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), [Raw].[MemberKey]),
						[Synchronized] = 1,
						[Parent] = MAX([Raw].[Parent])
					FROM
						[#Time_Property_Raw] [Raw]
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
		DROP TABLE #Digit
		DROP TABLE #Time_Property_Raw

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
