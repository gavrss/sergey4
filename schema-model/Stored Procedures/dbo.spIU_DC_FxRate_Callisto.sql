SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_FxRate_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StartYear int = NULL,
	@BaseCurrency nchar(3) = NULL,
	@Entity_MemberKey nvarchar(50) = NULL,
	@InvertBaseCurrencyYN bit = 0,
	@InvertRateYN bit = 0,
	@SpeedRunYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000700,
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
EXEC [spIU_DC_FxRate_Callisto] @UserID=-10, @InstanceID=454, @VersionID=1021, @Debug=1
EXEC [spIU_DC_FxRate_Callisto] @UserID=-10, @InstanceID=454, @VersionID=1021, @InvertBaseCurrencyYN = 1, @InvertRateYN = 1, @Debug=1
EXEC [spIU_DC_FxRate_Callisto] @UserID=-10, @InstanceID=454, @VersionID=1021, @Entity_MemberKey = 'R510', @InvertBaseCurrencyYN = 0, @InvertRateYN = 0, @Debug=1
EXEC [spIU_DC_FxRate_Callisto] @UserID=-10, @InstanceID=485, @VersionID=1034, @InvertBaseCurrencyYN = 1, @StartYear=2018, @Debug=1

EXEC [spIU_DC_FxRate_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@DataClass_StorageTypeBM int,
	@SQLStatement nvarchar(max),
	@MinDay int,
	@MaxDay int,
	@MonthID int,
	@DateFirst int = 1,  --First day of week; 1 = Monday, 2 = Tuesday ... 7 = Sunday (SQL default)
	@WeekFirst int = 1, --1 = Jan 1, 2 = First 4-day week, 3 = First full week --https://docs.microsoft.com/en-us/sql/t-sql/functions/datepart-transact-sql?view=sql-server-2017
	@MasterEntity nvarchar(50),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
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
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Load Callisto FACT table FxRate.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2162' SET @Description = 'Changed handling of @MasterEntity.'
		IF @Version = '2.1.1.2168' SET @Description = 'Test on Rate when deleting old rows.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT 
			@DataClass_StorageTypeBM = StorageTypeBM
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassTypeID = -6

		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF @DebugBM & 2 > 0 
			SELECT
				[@DataClass_StorageTypeBM] = @DataClass_StorageTypeBM,
				[@StartYear] = @StartYear

	SET @Step = 'Create and fill temp table #FxRate_Raw'
		CREATE TABLE #FxRate_Raw
			(
			[BaseCurrency] nchar(3) COLLATE DATABASE_DEFAULT,
			[Currency] nchar(3) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[TimeDay] int,
			[FxRate_Value] float
			)

		EXEC [dbo].[spIU_DC_FxRate_Raw]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@StartYear = @StartYear,
			@BaseCurrency = @BaseCurrency,
			@Entity_MemberKey = @Entity_MemberKey,
			@InvertBaseCurrencyYN = @InvertBaseCurrencyYN,
			@InvertRateYN = @InvertRateYN,
			@MasterEntity = @MasterEntity OUT,
			@JobID = @JobID,
			@Debug = @DebugSub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FxRate_Raw', [@MasterEntity] = @MasterEntity, * FROM #FxRate_Raw ORDER BY [BaseCurrency], [TimeDay], [Currency], [Entity], [Scenario]

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

	SET @Step = 'Create and fill temp table #Month'
		SELECT 
			@MinDay = MIN(TimeDay / 10000) * 10000 + 101, 
			@MaxDay = MAX(TimeDay / 10000) * 10000 + 1231 
		FROM
			#FxRate_Raw

		If @DebugBM & 2 > 0 SELECT [@MinDay] = @MinDay, [@MaxDay] = @MaxDay

		SELECT DISTINCT TOP 1000000
			[Month] = Y.Y * 100 + M.M
		INTO
			[#Month]
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
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @MinDay / 10000 AND @MaxDay / 10000
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
		ORDER BY
			Y.Y * 100 + M.M

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Month', * FROM #Month ORDER BY [Month]

	SET @Step = 'Create and fill temp table #Day'
		CREATE TABLE #Day_Member 
			(
			[DayID] bigint,
			[DayName] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeWeekDay] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeWeekDay_MemberId] bigint,
			[TimeWeek] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeWeek_MemberId] bigint
			)

		CREATE TABLE #Day
			(
			DayID int
			)

		IF CURSOR_STATUS('global','Days_cursor') >= -1 DEALLOCATE Days_cursor
		DECLARE Days_cursor CURSOR FOR
		SELECT
			MonthID = M.[Month]
		FROM
			#Month M
		ORDER BY 
			M.[Month]

		OPEN Days_cursor
		FETCH NEXT FROM Days_cursor INTO @MonthID

		WHILE @@FETCH_STATUS = 0
			BEGIN
				TRUNCATE TABLE #Day

				EXEC [spGet_AddDays] @MonthID = @MonthID, @DateFirst = @DateFirst, @WeekFirst = @WeekFirst

				SET @Step = 'Insert into temp table ' + CONVERT(nvarchar, @MonthID)
					INSERT INTO #Day
						(
						[DayId]
						)
					SELECT TOP 1000000
						[DayId] = [DayId]
					FROM
						#Day_Member
					ORDER BY
						[DayId]	

				FETCH NEXT FROM Days_cursor INTO @MonthID
				END

		CLOSE Days_cursor
		DEALLOCATE Days_cursor

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Day', * FROM #Day ORDER BY [DayID]

	SET @Step = 'Create temp table for FxRates on every specific day'

		SELECT
			D.[DayID],
			FRR.[BaseCurrency],
			FRR.[Currency],
			FRR.[Entity],
			FRR.[Scenario],
			FxRate = CONVERT(float, 1),
			[TimeDay] = MAX(FRR.[TimeDay])
		INTO
			#DayRate
		FROM
			[#FxRate_Raw] FRR
			INNER JOIN (
				SELECT
					FRR.[Currency],
					FRR.[Entity],
					FRR.[BaseCurrency],
					FRR.[Scenario],
					[TimeDay] = ISNULL(MAX(sub2.[TimeDay]), MIN(FRR.[TimeDay]))
				FROM
					[#FxRate_Raw] FRR
					LEFT JOIN (
						SELECT
							FRR.[Currency],
							FRR.[Entity],
							FRR.[BaseCurrency],
							FRR.[Scenario],
							[TimeDay] = MAX(FRR.[TimeDay])
						FROM
							[#FxRate_Raw] FRR
						WHERE
							FRR.[TimeDay] <= @MinDay
						GROUP BY
							FRR.[Currency],
							FRR.[Entity],
							FRR.[BaseCurrency],
							FRR.[Scenario]
						) sub2 ON	sub2.[Currency] = FRR.[Currency] AND
									sub2.[Entity] = FRR.[Entity] AND
									sub2.[BaseCurrency] = FRR.[BaseCurrency] AND
									sub2.[Scenario] = FRR.[Scenario]
				GROUP BY
					FRR.[Currency],
					FRR.[Entity],
					FRR.[BaseCurrency],
					FRR.[Scenario]
				) sub ON	sub.[Currency] = FRR.[Currency] AND
							sub.[Entity] = FRR.[Entity] AND
							sub.[BaseCurrency] = FRR.[BaseCurrency] AND
							sub.[Scenario] = FRR.[Scenario] AND
							sub.[TimeDay] <= FRR.[TimeDay]
			INNER JOIN #Day D ON D.[DayID] >= FRR.[TimeDay]
		GROUP BY
			D.[DayID],
			FRR.[Currency],
			FRR.[Entity],
			FRR.[BaseCurrency],
			FRR.[Scenario]

		UPDATE DR
		SET
			FxRate = FRR.FxRate_Value
		FROM
			#DayRate DR
			INNER JOIN #FxRate_Raw FRR ON 
				FRR.[Currency] =	DR.[Currency] AND 
				FRR.[Entity] = DR.[Entity] AND 
				FRR.[BaseCurrency] = DR.[BaseCurrency] AND 
				FRR.[Scenario] = DR.[Scenario] AND 
				FRR.[TimeDay] = DR.[TimeDay]

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#DayRate', * FROM #DayRate ORDER BY [DayID], [BaseCurrency], [Currency], [Entity], [Scenario]

	SET @Step = 'Create temp table #MonthRate'
		SELECT
			[BaseCurrency],
			[Currency],
			[Entity],
			[Rate],
			[Scenario],
			[Time],
			[FxRate_Value]
		INTO
			#MonthRate
		FROM
			(
			SELECT
				[BaseCurrency],
				[Currency],
				[Entity],
				[Rate] = 'Average',
				[Scenario],
				[Time] = CONVERT(nvarchar(100), [DayID] / 100),
				[FxRate_Value] = AVG([FxRate])
			FROM
				#DayRate
			GROUP BY
				[BaseCurrency],
				[Currency],
				[Entity],
				[Scenario],
				[DayID] / 100

			UNION SELECT
				[BaseCurrency] = DR.[BaseCurrency],
				[Currency] = DR.[Currency],
				[Entity] = DR.[Entity],
				[Rate] = 'EOP',
				[Scenario] = DR.[Scenario],
				[Time] = CONVERT(nvarchar(100), sub.[Time]),
				[FxRate_Value] = DR.[FxRate]
			FROM
				#DayRate DR
				INNER JOIN (SELECT [Time] = [DayID] / 100, [DayID] = MAX([DayID]) FROM #Day GROUP BY [DayID] / 100) sub ON sub.[DayID] = DR.[DayID]
			) sub

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#MonthRate', * FROM #MonthRate ORDER BY [Time], [BaseCurrency], [Currency], [Entity], [Scenario], [Rate]

	SET @Step = 'Add FxRate = 1 for BaseCurrency in #MonthRate'
		DELETE #MonthRate WHERE [BaseCurrency] = [Currency]

		INSERT INTO #MonthRate
		SELECT DISTINCT
			[BaseCurrency] = [BaseCurrency],
			[Currency] = [BaseCurrency],
			[Entity] = [Entity],
			[Rate] = [Rate],
			[Scenario] = [Scenario],
			[Time] = [Time],
			[FxRate_Value] = 1
		FROM 
			#MonthRate

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#MonthRate', * FROM #MonthRate ORDER BY [Time], [BaseCurrency], [Currency], [Entity], [Scenario], [Rate]

	SET @Step = 'Handle MasterEntity'
		DELETE #MonthRate WHERE [Entity] = 'NONE'

		INSERT INTO #MonthRate
		SELECT DISTINCT
			[BaseCurrency] = [BaseCurrency],
			[Currency] = [Currency],
			[Entity] = 'NONE',
			[Rate] = [Rate],
			[Scenario] = [Scenario],
			[Time] = [Time],
			[FxRate_Value] = [FxRate_Value]
		FROM 
			#MonthRate
		WHERE
			[Entity] = @MasterEntity

		DELETE #MonthRate WHERE [Entity] = @MasterEntity

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#MonthRate', * FROM #MonthRate ORDER BY [Time], [BaseCurrency], [Currency], [Entity], [Scenario], [Rate]

	SET @Step = 'Insert into temp table #FxRate'
		CREATE TABLE #FxRate
			(
			[BaseCurrency_MemberId] bigint,
			[Currency_MemberId] bigint,
			[Entity_MemberId] bigint,
			[Rate_MemberId] bigint,
			[Scenario_MemberId] bigint,
			[Time_MemberId] bigint,
			[FxRate_Value] float
			)
		
		IF @DataClass_StorageTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #FxRate
						(
						[BaseCurrency_MemberId],
						[Currency_MemberId],
						[Entity_MemberId],
						[Rate_MemberId],
						[Scenario_MemberId],
						[Time_MemberId],
						[FxRate_Value]
						)
					SELECT
						[BaseCurrency_MemberId] = [BaseCurrency].[MemberId],
						[Currency_MemberId] = [Currency].[MemberId],
						[Entity_MemberId] = [Entity].[MemberId],
						[Rate_MemberId] = [Rate].[MemberId],
						[Scenario_MemberId] = [Scenario].[MemberId],
						[Time_MemberId] = [Time].[MemberId],
						[FxRate_Value]
					FROM
						#MonthRate [Raw]
						INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BaseCurrency] [BaseCurrency] ON [BaseCurrency].Label COLLATE DATABASE_DEFAULT = [Raw].[BaseCurrency]
						INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Currency] [Currency] ON [Currency].Label COLLATE DATABASE_DEFAULT = [Raw].[Currency]
						INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Entity] [Entity] ON [Entity].Label COLLATE DATABASE_DEFAULT = [Raw].[Entity]
						INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Rate] [Rate] ON [Rate].Label COLLATE DATABASE_DEFAULT = [Raw].[Rate]
						INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Scenario] [Scenario] ON [Scenario].Label COLLATE DATABASE_DEFAULT = [Raw].[Scenario]
						INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Time] [Time] ON [Time].Label COLLATE DATABASE_DEFAULT = [Raw].[Time]
					WHERE
						[Raw].[FxRate_Value] <> 0.0'
			END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Create #FACT_Update'
		SELECT DISTINCT
			[Entity_MemberId],
			[Scenario_MemberId],
			[Time_MemberId],
			[Rate_MemberId]
		INTO
			#FACT_Update
		FROM
			#FxRate

	SET @Step = 'Set all existing rows that should be inserted to 0'
		IF @DataClass_StorageTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					UPDATE
						F
					SET
						[FxRate_Value] = 0
					FROM
						' + @CallistoDatabase + '.[dbo].[FACT_FxRate_default_partition] F
						INNER JOIN [#FACT_Update] V ON
										V.[Entity_MemberId] = F.[Entity_MemberId] AND
										V.[Scenario_MemberId] = F.[Scenario_MemberId] AND
										V.[Time_MemberId] = F.[Time_MemberId] AND
										V.[Rate_MemberId] = F.[Rate_MemberId]'
			END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert new rows'
		IF @DataClass_StorageTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_FxRate_default_partition]
						(
						[BaseCurrency_MemberId],
						[Currency_MemberId],
						[Entity_MemberId],
						[Rate_MemberId],
						[Scenario_MemberId],
						[Time_MemberId],
						[ChangeDatetime],
						[Userid],
						[FxRate_Value]
						)
					SELECT
						[BaseCurrency_MemberId],
						[Currency_MemberId],
						[Entity_MemberId],
						[Rate_MemberId],
						[Scenario_MemberId],
						[Time_MemberId],
						[ChangeDatetime] = GetDate(),
						[Userid] = suser_name(),
						[FxRate_Value]
					FROM
						#FxRate'
			END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Clean up'
		IF (SELECT DATEPART(WEEKDAY, GETDATE())) IN (6, 7) OR @SpeedRunYN = 0 --Saturday, Sunday or not SpeedRun
			BEGIN
				IF @DataClass_StorageTypeBM & 4 > 0
					BEGIN
						SET @SQLStatement = '
							DELETE
								f
							FROM
								' + @CallistoDatabase + '.[dbo].[FACT_FxRate_default_partition] F
							WHERE
								[FxRate_Value] = 0'
					END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Deleted = @Deleted + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #Day
		DROP TABLE #Day_Member
		DROP TABLE #DayRate
		DROP TABLE #Digit
		DROP TABLE #FxRate
		DROP TABLE #FxRate_Raw
		DROP TABLE #Month
		DROP TABLE #MonthRate

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
