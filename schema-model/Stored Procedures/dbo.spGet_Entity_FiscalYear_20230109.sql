SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Entity_FiscalYear_20230109]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@EntityID int = NULL, --Mandatory
	@Book nvarchar(50) = NULL, --Mandatory
	@StartFiscalYear int = NULL, --Mandatory
	@EndFiscalYear int = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@FiscalPeriodString nvarchar(1000) = NULL,
	@FiscalPeriod0YN bit = 0,
	@FiscalPeriod13YN bit = 0,
	@SetJobLogYN bit = 0,
	@FullReloadYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000231,
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
Agreed algorithm examples:
1. If @FiscalPeriod0YN = 1			then add 1 row for each year with FiscalPeriod = 0.
2. If @FiscalPeriod13YN = 1			then add 3 rows for each year with FiscalPeriod = 13, 14, 15
3. If @FiscalPeriodString = null	then add all rows between 1 and 12
4. If @FiscalPeriodString = '11,14' then add 11, 14 rows
5. If @FiscalPeriod0YN = 1,  @FiscalPeriodString = '11' then add 0, 11 rows
6. If @FiscalPeriod13YN = 1,  @FiscalPeriodString = '11' then add 11,13,14,15 rows
7. If @FiscalPeriod0YN = 0, @FiscalPeriod13YN = 0, @FiscalPeriodString = '0, 13' then add 0, 13

EXEC dbo.[spGet_Entity_FiscalYear] @UserID = -10, @InstanceID = 603, @VersionID = 1095, @EntityID = 15122, @Book = 'GL', @FiscalYear=2022, @FiscalPeriod13YN = 1, @FiscalPeriod0YN = 1, @Debug = 1
EXEC dbo.[spGet_Entity_FiscalYear_20230109] @UserID = -10, @InstanceID = 603, @VersionID = 1095, @EntityID = 15122, @Book = 'GL', @FiscalYear=2021, @FiscalPeriod13YN = 1, @FiscalPeriod0YN = 1, @Debug = 1

EXEC dbo.[spGet_Entity_FiscalYear] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @EntityID = 10447, @Book = 'GL', @StartFiscalYear=2000, @FiscalYear = 2013
EXEC dbo.[spGet_Entity_FiscalYear] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @EntityID = 10447, @Book = 'GL', @StartFiscalYear=2000, @FiscalPeriod = 12
EXEC dbo.[spGet_Entity_FiscalYear] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @EntityID = 13849, @Book = 'MAIN', @StartFiscalYear=2020, @FiscalYear=2020, @FiscalPeriod = 2, @Debug=1
EXEC dbo.[spGet_Entity_FiscalYear] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @EntityID = 13849, @Book = 'MAIN', @StartFiscalYear=2020, @FiscalYear=2020, @FiscalPeriodString = '1,5,12', @FiscalPeriod0YN = 0, @FiscalPeriod13YN = 13, @Debug=1
EXEC dbo.[spGet_Entity_FiscalYear] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @EntityID = 16038, @Book = 'MAIN', @StartFiscalYear=2020, @FiscalYear=2020, @debug=1
EXEC dbo.[spGet_Entity_FiscalYear] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @EntityID = 16055, @Book = 'MAIN', @StartFiscalYear=2020, @FiscalYear=2020, @debug=1
EXEC dbo.[spGet_Entity_FiscalYear] @UserID=-10, @InstanceID=531, @VersionID=1057, @EntityID = 14712, @Book = 'MAIN', @FiscalYear=2021 , @FiscalPeriodString = '0,13', @FiscalPeriod0YN = 0, @DebugBM=3

EXEC dbo.[spGet_Entity_FiscalYear] @UserID=-10,@InstanceID = 515, @VersionID = 1064, @EntityID = 14812, @Book = 'GL', @FiscalYear=2021, @FiscalPeriod0YN = 0, @FiscalPeriod13YN = 0, @FiscalPeriodString = '0,13'--, @DebugBM=3


EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = -10, @InstanceID = 478, @VersionID = 1030, 
@EntityID = 14054, @Book = 'MAIN', @StartFiscalYear = NULL, @FiscalYear = 2021, @FiscalPeriodString = NULL,
@FiscalPeriod0YN = 1, @FiscalPeriod13YN = 1, @DebugBM=15--, @JobID = @JobID


EXEC [spGet_Entity_FiscalYear] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CalledYN bit = 1,
	@FiscalYearNamingBase int,
	@FiscalYearNaming int,
	@StartMonth int,
	@EndMonth int,
	@CursorFiscalYear int,
	@CursorFiscalPeriod int,
	@YearMonth int,
	@StartYear int,
	@EndYear int,
	@Counter int,
	@SQLStatement nvarchar(max),
	@ETLDatabase nvarchar(100),
	@TableName nvarchar(100),
	@Entity nvarchar(50),
	
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
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.1.2177'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return all valid combinations of FiscalPeriods and YearMonth.',
			@MandatoryParameter = 'EntityID|Book|StartYear'

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2153' SET @Description = 'Added parameter @FiscalPeriod0YN. @StartFiscalYear defaulted to @FiscalYear.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added parameter @FiscalPeriod13YN.'
		IF @Version = '2.1.0.2155' SET @Description = 'Added parameter @FiscalPeriodString.'
		IF @Version = '2.1.0.2156' SET @Description = 'Changed handling of FiscalYearNaming.'
		IF @Version = '2.1.1.2169' SET @Description = 'Added parameter @SetJobLogYN, defaulted to 0. Set @FiscalPeriodString to NULL if @FullReloadYN = 1.'
		IF @Version = '2.1.1.2176' SET @Description = 'DB-696 Check existance of table pcETL FiscalCalendar. DB-692 Fixed noncorrect using: FiscalPeriod0YN, FiscalPeriod13YN, @FiscalPeriodString. Example: Now it is possible to get only one row with Period=13.'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-695 Correction calculating @EndYear in loop.'

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

		SET @StartFiscalYear = COALESCE(@StartFiscalYear, @FiscalYear, YEAR(GetDate()))

		SELECT @EndFiscalYear = COALESCE(@EndFiscalYear, @FiscalYear, YEAR(GetDate()) + 3)
		SELECT @StartYear = @StartFiscalYear - 1 , @EndYear = @EndFiscalYear

		SELECT
			--@FiscalYearNaming = CASE WHEN [FiscalYearStartMonth] = 1 THEN 0 ELSE [FiscalYearNaming] END
			@FiscalYearNamingBase =[FiscalYearNaming]
        FROM
			[pcINTEGRATOR_Data].[dbo].[Instance]
		WHERE
			InstanceID = @InstanceID

		IF exists (select 1 from STRING_SPLIT(@FiscalPeriodString, ',') where Value = 0)
			SET @FiscalPeriod0YN = 1

		IF @FullReloadYN <> 0 SET @FiscalPeriodString = NULL

		SELECT
			@Entity = [MemberKey]
		FROM
			pcINTEGRATOR_Data..Entity
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[EntityID] = @EntityID AND
			[SelectYN] <> 0
		
		SELECT
			@ETLDatabase = [ETLDatabase]
		FROM
			pcINTEGRATOR_Data.[dbo].[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		SET @TableName = @ETLDatabase + '.dbo.FiscalCalendar'

		IF @DebugBM & 2 > 0
			SELECT
				[@Entity] = @Entity,
				[@FiscalYear] = @FiscalYear,
				[@StartFiscalYear] = @StartFiscalYear,
				[@EndFiscalYear] = @EndFiscalYear,
				[@StartYear] = @StartYear,
				[@FiscalYearNamingBase] = @FiscalYearNamingBase,
				[@ETLDatabase] = @ETLDatabase,
				[@TableName] = @TableName

	SET @Step = 'Create or truncate table #FiscalPeriod'
		IF OBJECT_ID(N'TempDB.dbo.#FiscalPeriod', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #FiscalPeriod
					(
					FiscalYear int,
					FiscalPeriod int,
					YearMonth int
					)
			END
		ELSE
			TRUNCATE TABLE #FiscalPeriod

	SET @Step = 'Check FiscalCalendar'
		IF OBJECT_ID(@TableName, N'U') IS NOT NULL
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #FiscalPeriod
						(
						[FiscalYear],
						[FiscalPeriod],
						[YearMonth]
						)
					SELECT 
						[FiscalYear],
						[FiscalPeriod],
						[YearMonth]
					FROM
						' + @TableName + ' FC
					WHERE
						FC.[Entity] = ''' + @Entity + ''' AND
						FC.[FiscalYear] BETWEEN ' + CONVERT(nvarchar(15), @StartFiscalYear) + ' AND ' + CONVERT(nvarchar(15), @EndFiscalYear) + ' AND
						(' + CONVERT(nvarchar(15), CONVERT(int, @FiscalPeriod0YN)) + ' <> 0 OR FC.[FiscalPeriod] <> 0) AND
						(' + CONVERT(nvarchar(15), CONVERT(int, @FiscalPeriod13YN)) + ' <> 0 OR FC.[CloseFiscalPeriodYN] = 0)' +
						CASE WHEN @FiscalPeriodString IS NOT NULL THEN ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'FC.[FiscalPeriod] IN (0,13,14,15,' + @FiscalPeriodString + ')' ELSE '' END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF (SELECT COUNT(1) FROM #FiscalPeriod) > 0
					GOTO ReturnRows
			END

	SET @Step = 'Run Fiscal_Cursor'
		
			IF @DebugBM & 2 > 0
				SELECT 
					[StartMonth],
					[EndMonth]
				FROM
					[Entity] E
					INNER JOIN [Entity_FiscalYear] EFY ON EFY.EntityID = E.EntityID AND EFY.Book = @Book AND EndMonth / 100 >= @StartYear AND StartMonth /100 <= @EndYear
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.EntityID = @EntityID 
		
		DECLARE Fiscal_Cursor CURSOR FOR
			SELECT 
				[StartMonth],
				[EndMonth]
			FROM
				[Entity] E
				INNER JOIN [Entity_FiscalYear] EFY ON EFY.EntityID = E.EntityID AND EFY.Book = @Book AND EndMonth / 100 >= @StartYear AND StartMonth /100 <= @EndYear
			WHERE
				E.InstanceID = @InstanceID AND
				E.VersionID = @VersionID AND
				E.EntityID = @EntityID 

			OPEN Fiscal_Cursor
			FETCH NEXT FROM Fiscal_Cursor INTO @StartMonth, @EndMonth

			SET @EndYear = CASE WHEN @StartMonth % 100 =1 then @EndFiscalYear ELSE @EndFiscalYear+1 END;

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @FiscalYearNaming = CASE WHEN @StartMonth % 100 = 1 THEN 0 ELSE @FiscalYearNamingBase END

					IF @DebugBM & 2 > 0 SELECT [@StartMonth] = @StartMonth, [@EndMonth] = @EndMonth, [@FiscalYearNamingBase] = @FiscalYearNamingBase, [@FiscalYearNaming] = @FiscalYearNaming

					SET @CursorFiscalYear = CASE WHEN @StartYear >= (@StartMonth / 100) + @FiscalYearNaming THEN @StartYear + @FiscalYearNaming ELSE (@StartMonth / 100) + @FiscalYearNaming END
--					SET @CursorFiscalYear = 2022--CASE WHEN @StartYear >= (@StartMonth / 100) + @FiscalYearNaming THEN @StartYear + @FiscalYearNaming ELSE (@StartMonth / 100) + @FiscalYearNaming END
	--	(2022)		--		2022						2021					1900			1						   2022							
	--	(2022_new)	--		2023						2022					2021			1						   2023
	--  (2023)		--		2023						2022					2021			1						   2023
					SET @CursorFiscalPeriod = 1
					SET @YearMonth = CASE WHEN @StartYear >= (@StartMonth / 100) + @FiscalYearNaming THEN (@StartYear * 100) + (@StartMonth % 100) ELSE @StartMonth END
					-- 201212						2021				1900			1						2021 00						12			190012
					-- 202212						2022				2021			1						2022 00						12			202112
					IF @DebugBM & 2 > 0 SELECT   [@CursorFiscalYear] = @CursorFiscalYear, [@CursorFiscalPeriod] = @CursorFiscalPeriod, [@YearMonth] = @YearMonth, [@EndYear] = @EndYear, [@EndMonth] = @EndMonth

					WHILE @YearMonth <= CASE WHEN @EndMonth / 100 <= @EndYear THEN @EndMonth ELSE (@EndYear * 100) + (@EndMonth % 100) END
						-- 202112						  2021			2023		202111
						-- 202212						  2022			2024		202212
						BEGIN
							IF @DebugBM & 2 > 0 SELECT  [inserting] = 'before insert', [@CursorFiscalYear] = @CursorFiscalYear, [@CursorFiscalPeriod] = @CursorFiscalPeriod, [@YearMonth] = @YearMonth, [@EndYear] = @EndYear, [@EndMonth] = @EndMonth
							INSERT INTO #FiscalPeriod
								(
								FiscalYear,
								FiscalPeriod,
								YearMonth
								)
							SELECT
								FiscalYear = @CursorFiscalYear,
								FiscalPeriod = @CursorFiscalPeriod,
								YearMonth = @YearMonth

							SET @CursorFiscalYear = CASE WHEN @YearMonth % 100 = @EndMonth % 100 AND @EndMonth - @StartMonth > 111 THEN @CursorFiscalYear + 1 ELSE @CursorFiscalYear END
							SET @CursorFiscalPeriod = CASE WHEN @YearMonth % 100 = @EndMonth % 100 AND @EndMonth - @StartMonth > 111 THEN 1 ELSE @CursorFiscalPeriod + 1 END
							SET @YearMonth = CASE WHEN @YearMonth % 100 = 12 THEN ((@YearMonth / 100) + 1) * 100 + 1 ELSE @YearMonth + 1 END
		
							IF @DebugBM & 2 > 0 SELECT  [inserting] = 'after insert',  [@CursorFiscalYear] = @CursorFiscalYear, [@CursorFiscalPeriod] = @CursorFiscalPeriod, [@YearMonth] = @YearMonth, [@EndYear] = @EndYear, [@EndMonth] = @EndMonth
						
						END
					FETCH NEXT FROM Fiscal_Cursor INTO @StartMonth, @EndMonth
				END

		CLOSE Fiscal_Cursor
		DEALLOCATE Fiscal_Cursor	


	IF @DebugBM & 2 > 0 SELECT [TempTable_#FiscalPeriod_1] = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod
	

	SET @Step = 'Check parameter @FiscalYear and @FiscalPeriod'
		DELETE #FiscalPeriod WHERE FiscalYear < @StartFiscalYear OR FiscalYear > @EndFiscalYear
	
		IF @DebugBM & 2 > 0 SELECT [TempTable_#FiscalPeriod_2] = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod

		IF @FiscalYear IS NOT NULL
			DELETE #FiscalPeriod WHERE FiscalYear <> @FiscalYear

		IF @DebugBM & 2 > 0 SELECT [TempTable_#FiscalPeriod_3] = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth, FiscalPeriod

		IF (@FiscalPeriod0YN <> 0)
			begin
			INSERT INTO #FiscalPeriod
				(
				FiscalYear,
				FiscalPeriod,
				YearMonth
				)
			SELECT
				FiscalYear = FiscalYear,
				FiscalPeriod = 0,
				YearMonth = YearMonth
			FROM
				#FiscalPeriod
			WHERE
				FiscalPeriod = 1
			end;

	SET @Step = 'Add FP13 - FP15'
		IF (@FiscalPeriod13YN <> 0) or exists (select 1 from STRING_SPLIT(@FiscalPeriodString, ',') where Value in (13, 14, 15))
			BEGIN
				IF CURSOR_STATUS('global','Extra_Cursor') >= -1 DEALLOCATE Extra_Cursor
				DECLARE Extra_Cursor CURSOR FOR
					SELECT 
						[FiscalYear],
						[FiscalPeriod] = MAX([FiscalPeriod]),
						[YearMonth] = MAX([YearMonth])
					FROM
						#FiscalPeriod FP1
					WHERE
						EXISTS (SELECT 1 FROM #FiscalPeriod FP12 WHERE FP12.FiscalPeriod = 12 AND FP12.[FiscalYear] = FP1.[FiscalYear])
					GROUP BY
						[FiscalYear]
					ORDER BY
						[FiscalYear]

					declare  @FiscalYear_cur	int	
							,@FiscalPeriod_cur	int
							,@YearMonth_cur		int
					OPEN Extra_Cursor
					FETCH NEXT FROM Extra_Cursor INTO @FiscalYear_cur, @FiscalPeriod_cur, @YearMonth_cur

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@FiscalYear_cur] = @FiscalYear_cur, [@FiscalPeriod_cur] = @FiscalPeriod_cur, [@YearMonth_cur] = @YearMonth_cur
							SET @Counter = 1

							WHILE (@Counter <= 3) AND (@FiscalPeriod_cur + @Counter <= 15)
								BEGIN
									INSERT INTO #FiscalPeriod
										(
										[FiscalYear],
										[FiscalPeriod],
										[YearMonth]
										)
									SELECT
										[FiscalYear] = @FiscalYear_cur,
										[FiscalPeriod] = @FiscalPeriod_cur + @Counter,
										[YearMonth] = @YearMonth_cur

									SET @Counter = @Counter + 1
								END

							FETCH NEXT FROM Extra_Cursor INTO @FiscalYear_cur, @FiscalPeriod_cur, @YearMonth_cur
						END

				CLOSE Extra_Cursor
				DEALLOCATE Extra_Cursor
			END


		IF @FiscalPeriod IS NOT NULL
			DELETE #FiscalPeriod WHERE FiscalPeriod <> @FiscalPeriod

		-- HotFix: sometimes table [Entity_FiscalYear] has several rows for the one EntityID and Book. And [pcINTEGRATOR_Data].[dbo].[Instance].FiscalYearNaming must be different for these rows.
		-- But we have only one FiscalYearNaming for the InstanceID (for the all EntityID and Book in the InstanceID).
		-- So sometimes we have duplicates in this step by [FiscalYear], [FiscalPeriod].
		-- And we cleaning these duplicates.
		-- Example: 	EXEC dbo.[spGet_Entity_FiscalYear_20230109] @UserID = -10, @InstanceID = 603, @VersionID = 1095, @EntityID = 15122, @Book = 'GL', @FiscalYear=2023, @FiscalPeriod13YN = 1, @FiscalPeriod0YN = 1, @Debug = 1
		DELETE FP1
		FROM #FiscalPeriod FP1
		WHERE FP1.[YearMonth] < (SELECT MAX(FP2.YearMonth) 
								 FROM [#FiscalPeriod] FP2
								 WHERE	FP2.[FiscalYear] = FP1.[FiscalYear] 
									AND FP2.[FiscalPeriod] = FP1.[FiscalPeriod] 
								 GROUP BY FP2.[FiscalYear], FP2.[FiscalPeriod])

		IF ISNULL(@FiscalPeriodString, '') <> ''
			begin
			SET @SQLStatement = '
				DELETE #FiscalPeriod WHERE FiscalPeriod NOT IN (' + @FiscalPeriodString + ')' 
														+ iif(@FiscalPeriod0YN <> 0, ' AND (FiscalPeriod <> 0)', '') 
														+ iif(@FiscalPeriod13YN <> 0, ' AND FiscalPeriod not in (13, 14, 15)', '')
			EXEC (@SQLStatement)
			end



		SELECT @Selected = COUNT(1) FROM #FiscalPeriod



	SET @Step = 'Return rows and drop table #FiscalPeriod if SP not called'
		ReturnRows:

		IF @CalledYN = 0
			BEGIN
				SELECT
					*
				FROM
					#FiscalPeriod
				ORDER BY
					[FiscalYear],
					[FiscalPeriod],
					[YearMonth]

				SET @Selected = @Selected + @@ROWCOUNT

				DROP TABLE #FiscalPeriod
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
