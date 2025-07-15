SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_FiscalYear_EpicorERP]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,
	@FiscalYearNaming int = NULL OUT,
	@FiscalYearStartMonth int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000596,
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
EXEC [spSetup_FiscalYear_EpicorERP] @UserID=-10, @InstanceID=15, @VersionID=1039, @SourceTypeID = 11, @DebugBM=0

EXEC [spSetup_FiscalYear_EpicorERP] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),	
	@SourceDatabase nvarchar(100),
	@Owner nvarchar(3),
	@EntityID int,
	@Book nvarchar(50),
	@StartMonth int,
	@EndMonth int,
	@CalledYN bit = 1,

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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup financial FiscalYears from Epicor ERP',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@SourceDatabase = MAX(CASE WHEN M.[BaseModelID] = -7 THEN S.[SourceDatabase] ELSE '' END)
		FROM
			[Source] S
			INNER JOIN [Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.[BaseModelID] IN (-7)
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID

		SET @Owner = CASE WHEN @SourceTypeID = 11 THEN 'erp' ELSE 'dbo' END

		IF @DebugBM & 2 > 0 SELECT [@SourceDatabase] = @SourceDatabase, [@Owner] = @Owner

	SET @Step = 'Create temp tables'
		IF OBJECT_ID(N'TempDB.dbo.#Entity_FiscalYear', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Entity_FiscalYear
					(
					[EntityID] int,
					[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[StartMonth] int,
					[EndMonth] int
					)
			END

		CREATE TABLE #Calendar
			(
			[Entity_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[MainBookYN] bit,
			[FiscalYear] int,
			[StartMonth] int,
			[EndMonth] int
			)

		CREATE TABLE #MainParam
			(
			[FiscalYearNaming] int,
			[FiscalYearStartMonth] int,
			[Count] int
			)

	SET @Step = 'Fill temp table #Calendar'
		SET @SQLStatement = '
			INSERT INTO #Calendar
				(
				[Entity_MemberKey],
				[Book],
				[MainBookYN],
				[FiscalYear],
				[StartMonth],
				[EndMonth]
				)
			SELECT 
				[Entity_MemberKey] = B.[Company] COLLATE DATABASE_DEFAULT,
				[Book] = B.[BookID] COLLATE DATABASE_DEFAULT,
				[MainBookYN] = CONVERT(bit, MAX(CONVERT(int, B.[MainBook]))),
				[FiscalYear] = FP.[FiscalYear],
				[StartMonth] = MIN(YEAR(FP.[StartDate]) * 100 + MONTH(FP.[StartDate])),
				[EndMonth] = MAX(YEAR(FP.[EndDate]) * 100 + MONTH(FP.[EndDate]))
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[GLBook] B
				INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[FiscalPer] FP ON FP.[Company]= B.[Company] AND FP.[FiscalCalendarID] = B.[FiscalCalendarID]
			GROUP BY
				B.[Company],
				B.[BookID],
				FP.[FiscalYear]
			ORDER BY
				B.[Company],
				B.[BookID],
				FP.[FiscalYear]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Selected = @Selected + @@ROWCOUNT
		IF @Debug <> 0 SELECT [TempTable] = '#Calendar', * FROM #Calendar ORDER BY [Entity_MemberKey], [Book], [FiscalYear]

	SET @Step = 'Fill temp table #MainParam'
		INSERT INTO #MainParam
			(
			[FiscalYearNaming],
			[FiscalYearStartMonth],
			[Count]
			)
		SELECT 
			[FiscalYearNaming] = ([FiscalYear] - ([StartMonth] / 100)),
			[FiscalYearStartMonth] = ([StartMonth] % 100),
			[Count] = COUNT(1)
		FROM
			#Calendar C
			INNER JOIN pcINTEGRATOR_Data..Entity E ON E.[InstanceID] = @InstanceID AND E.[VersionID] = @VersionID AND E.[MemberKey] = C.[Entity_MemberKey] AND E.[SelectYN] <> 0
			INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND EB.[Book] = C.[Book] AND EB.[SelectYN] <> 0
		WHERE
			C.[MainBookYN] <> 0
		GROUP BY
			([FiscalYear] - ([StartMonth] / 100)),
			([StartMonth] % 100)

	SET @Step = 'Set @FiscalYearNaming AND @FiscalYearStartMonth'
		SELECT TOP 1
			@FiscalYearNaming = [FiscalYearNaming],
			@FiscalYearStartMonth = [FiscalYearStartMonth]
		FROM
			#MainParam
		ORDER BY
			[Count] DESC

	SET @Step = 'Entity_FiscalYear_Cursor'
		IF CURSOR_STATUS('global','Entity_FiscalYear_Cursor') >= -1 DEALLOCATE Entity_FiscalYear_Cursor
		DECLARE Entity_FiscalYear_Cursor CURSOR FOR
			SELECT
				E.EntityID,
				C.Book,
				C.StartMonth,
				C.EndMonth
			FROM
				#Calendar C
				INNER JOIN pcINTEGRATOR_Data..Entity E ON E.[InstanceID] = @InstanceID AND E.[VersionID] = @VersionID AND E.[MemberKey] = C.[Entity_MemberKey] 
			ORDER BY
				E.EntityID,
				C.Book,
				C.StartMonth

			OPEN Entity_FiscalYear_Cursor
			FETCH NEXT FROM Entity_FiscalYear_Cursor INTO @EntityID, @Book, @StartMonth, @EndMonth

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@EntityID] = @EntityID, [@Book] = @Book, [@StartMonth] = @StartMonth, [@EndMonth] = @EndMonth

					IF NOT ISNULL((SELECT [StartFY] = MAX([StartMonth]) % 100 FROM #Entity_FiscalYear WHERE [EntityID] = @EntityID AND [Book] = @Book), 0) = @StartMonth % 100
						INSERT INTO #Entity_FiscalYear
							(
							[EntityID],
							[Book],
							[StartMonth],
							[EndMonth]
							)
						SELECT
							[EntityID] = @EntityID,
							[Book] = @Book,
							[StartMonth] = @StartMonth,
							[EndMonth] = @EndMonth

					FETCH NEXT FROM Entity_FiscalYear_Cursor INTO @EntityID, @Book, @StartMonth, @EndMonth
				END

		CLOSE Entity_FiscalYear_Cursor
		DEALLOCATE Entity_FiscalYear_Cursor

		UPDATE EFY
		SET
			[StartMonth] = 190000 + sub.[StartMonth] % 100
		FROM
			#Entity_FiscalYear EFY
			INNER JOIN 
				(
				SELECT
					[EntityID],
					[Book],
					[StartMonth] = MIN(EFY.[StartMonth])
				FROM
					#Entity_FiscalYear EFY
				GROUP BY
					[EntityID],
					[Book]
				) sub ON sub.[EntityID] = EFY.[EntityID] AND sub.[Book] = EFY.[Book] AND sub.[StartMonth] = EFY.[StartMonth]

		UPDATE EFY
		SET
			[EndMonth] = 209900 + sub.[EndMonth] % 100
		FROM
			#Entity_FiscalYear EFY
			INNER JOIN 
				(
				SELECT
					[EntityID],
					[Book],
					[EndMonth] = MAX(EFY.[EndMonth])
				FROM
					#Entity_FiscalYear EFY
				GROUP BY
					[EntityID],
					[Book]
				) sub ON sub.[EntityID] = EFY.[EntityID] AND sub.[Book] = EFY.[Book] AND sub.[EndMonth] = EFY.[EndMonth]

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			BEGIN
				SELECT 
					[@FiscalYearNaming] = @FiscalYearNaming,
					[@FiscalYearStartMonth] = @FiscalYearStartMonth
				SELECT TempTable = '#Entity_FiscalYear', * FROM #Entity_FiscalYear ORDER BY [EntityID], [Book], [StartMonth]
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Calendar
		DROP TABLE #MainParam
		IF @CalledYN = 0 DROP TABLE #Entity_FiscalYear

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
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
