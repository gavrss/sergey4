SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_AddDays]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@MonthID int = NULL, --Mandatory
	@DateFirst int = 1,  --First day of week; 1 = Monday, 2 = Tuesday ... 7 = Sunday (SQL default)
	@WeekFirst int = 1, --1 = Jan 1, 2 = First 4-day week, 3 = First full week --https://docs.microsoft.com/en-us/sql/t-sql/functions/datepart-transact-sql?view=sql-server-2017
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000394,
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
	@ProcedureName = 'spGet_AddDays',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"},
		{"TKey" : "MonthID",  "TValue": "200501"}
		]'

EXEC [spGet_AddDays] @UserID=-10, @InstanceID=390, @VersionID=1011, @MonthID = 200501, @Debug=1
EXEC [spGet_AddDays] @MonthID = 200501, @DateFirst = 1, @WeekFirst = 1
EXEC [spGet_AddDays] @MonthID = 200501, @DateFirst = 1, @WeekFirst = 2
EXEC [spGet_AddDays] @MonthID = 200501, @DateFirst = 1, @WeekFirst = 3
EXEC [spGet_AddDays] @MonthID = 200501, @DateFirst = 7, @WeekFirst = 1
EXEC [spGet_AddDays] @MonthID = 200501, @DateFirst = 7, @WeekFirst = 2
EXEC [spGet_AddDays] @MonthID = 200501, @DateFirst = 7, @WeekFirst = 3

EXEC [spGet_AddDays] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DayCount int,
	@CalledYN bit = 1,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Add Day Members for a specified Month.',
			@MandatoryParameter = 'MonthID' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'

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

		SET DATEFIRST 1

		IF @MonthID % 100 IN (1, 3, 5, 7, 8, 10, 12)
			SET @DayCount = 31
		ELSE IF @MonthID % 100 IN (4, 6, 9, 11)
			SET @DayCount = 30
		ELSE IF @MonthID % 100 = 2
			BEGIN
				IF (@MonthID / 100) % 4 = 0
					SET @DayCount = 29
				ELSE
					SET @DayCount = 28
			END
		ELSE
			SET @DayCount = 0

	SET @Step = 'Create temp table #Day_Member if not existing'
		IF OBJECT_ID(N'TempDB.dbo.#Day_Member', N'U') IS NULL
		BEGIN  
			SET @CalledYN = 0

			CREATE TABLE #Day_Member 
				(
				DayID bigint,
				[DayName] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[TimeWeekDay] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[TimeWeekDay_MemberId] bigint,
				[TimeWeek] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[TimeWeek_MemberId] bigint
				)
		END

	SET @Step = 'Create temp table #Days'
		CREATE TABLE #Days (DayNo int)

		INSERT INTO #Days
			  SELECT  1 UNION SELECT  2 UNION SELECT  3 UNION SELECT  4 UNION SELECT  5 UNION SELECT  6 UNION SELECT  7 UNION SELECT  8
		UNION SELECT  9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16
		UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23 UNION SELECT 24 
		UNION SELECT 25 UNION SELECT 26 UNION SELECT 27 UNION SELECT 28 UNION SELECT 29 UNION SELECT 30 UNION SELECT 31

	SET @Step = 'Insert values to #Day_Member'
		INSERT INTO #Day_Member
			(
			DayID ,
			[DayName],
			[TimeWeekDay],
			[TimeWeekDay_MemberId]
			)
		SELECT 
			DayID = @MonthID * 100 + DayNo,
			[DayName] = SUBSTRING(DATENAME(DW, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112)),1,3) + ', ' + 
						DATENAME(day, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112))  + ' ' + 
						SUBSTRING(DATENAME(MONTH, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112)), 1, 3)  + ' ' + 
						DATENAME(year, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112)),
			[TimeWeekDay] = DATEPART(weekday, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112)),
			[TimeWeekDay_MemberId] = 100 + DATEPART(weekday, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112))
		FROM
			#Days
		WHERE
			DayNo <= @DayCount
		ORDER BY 
			DayNo

	SET @Step = 'Update Week Numbering fields on #Day_Member'
		SET DATEFIRST @DateFirst

		IF @WeekFirst = 2 --Week numbering starts on the First 4-day week
			UPDATE #Day_Member
			SET
				TimeWeek = 'W' + CASE WHEN DATEPART(ISOWK, CONVERT(datetime, CONVERT(varchar, DayID), 112)) <= 9 THEN '0' ELSE '' END + CONVERT(NVARCHAR(10), DATEPART(ISOWK, CONVERT(datetime, CONVERT(varchar, DayID), 112))),
				TimeWeek_MemberId = 100 + DATEPART(ISOWK, CONVERT(datetime, CONVERT(varchar, DayID), 112))

		ELSE IF @WeekFirst = 3 --Week numbering starts on the First Full Week
			UPDATE #Day_Member
			SET
				TimeWeek = 'W' + CASE WHEN [dbo].[f_GetWeekNumber] (CONVERT(datetime, CONVERT(varchar, DayID), 112)) <= 9 THEN '0' ELSE '' END + CONVERT(NVARCHAR(10), [dbo].[f_GetWeekNumber] (CONVERT(datetime, CONVERT(varchar, DayID), 112))),
				TimeWeek_MemberId = 100 + [dbo].[f_GetWeekNumber] (CONVERT(datetime, CONVERT(varchar, DayID), 112))

		ELSE --Week numbering starts Jan 1 (@WeekFirst = 1) 
			UPDATE #Day_Member
			SET
				TimeWeek = 'W' + CASE WHEN DATEPART(WK, CONVERT(datetime, CONVERT(varchar, DayID), 112)) <= 9 THEN '0' ELSE '' END + CONVERT(NVARCHAR(10), DATEPART(WK, CONVERT(datetime, CONVERT(varchar, DayID), 112))),
				TimeWeek_MemberId = 100 + DATEPART(WK, CONVERT(datetime, CONVERT(varchar, DayID), 112))

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable='#Day_Member', * FROM #Day_Member ORDER BY DayID
				SET @Selected = @@ROWCOUNT
			END
	
	SET @Step = 'Drop the temp tables'
		DROP TABLE #Days
		IF @CalledYN = 0 DROP TABLE #Day_Member			

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
