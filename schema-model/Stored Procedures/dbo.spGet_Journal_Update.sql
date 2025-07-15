SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Journal_Update]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,
	@JournalTable nvarchar(100) = NULL,
	@MaxPostedDate date = NULL OUT,
	@MaxSourceCounter bigint = NULL OUT,
	@FullReloadYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000547,
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
EXEC [spGet_Journal_Update] @UserID=-10, @InstanceID=454, @VersionID=1021, @SourceTypeID = 11, @JobID = 1, @DebugBM=2
EXEC [spGet_Journal_Update] @UserID=-10, @InstanceID=413, @VersionID=1008, @SourceTypeID = 11, @JobID = 2, @DebugBM=2
EXEC [spGet_Journal_Update] @UserID=-10, @InstanceID=529, @VersionID=1001, @SourceTypeID = 3, @DebugBM=3

EXEC [spGet_Journal_Update] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(MAX),
	@SourceTypeName nvarchar(50),
	@SourceDatabase nvarchar(100),
	@StartYear int,
	@FiscalYear int,
	@MasterClosedYearMonth int,
	@MasterClosedFiscalYear int,

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
	@Version nvarchar(50) = '2.1.0.2165'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows from [pcINTEGRATOR_Log].[dbo].[wrk_Journal_Update]',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2152' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Based on Last PostedDate and MaxSourceCounter.'
		IF @Version = '2.1.0.2156' SET @Description = 'Added parameter @FullReloadYN.'
		IF @Version = '2.1.0.2163' SET @Description = 'Test on active and not deleted Entities and Books.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'

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

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @JournalTable IS NULL EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @JournalTable=@JournalTable OUT 

		SELECT @SourceTypeName = [SourceTypeName] FROM SourceType WHERE [SourceTypeID] = @SourceTypeID

		SELECT
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.[SourceDatabase], '[', ''), ']', ''), '.', '].[') + ']',
			@StartYear = S.StartYear
		FROM
			[pcINTEGRATOR_Data]..[Source] S
			INNER JOIN [pcINTEGRATOR_Data]..[Model] M ON M.InstanceID = S.InstanceID AND M.VersionID = S.VersionID AND M.ModelID = S.ModelID AND M.BaseModelID = -7 AND M.SelectYN <> 0
		WHERE
			S.InstanceID = @InstanceID AND
			S.VersionID = @VersionID AND
			S.SourceTypeID = @SourceTypeID AND
			S.SelectYN <> 0

		EXEC [spGet_MasterClosedYear] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @MasterClosedYearMonth=@MasterClosedYearMonth OUT, @MasterClosedFiscalYear=@MasterClosedFiscalYear OUT

		SET @SQLStatement = 'SELECT @InternalVariable1 = MAX([PostedDate]), @InternalVariable2 = MAX([SourceCounter]) FROM ' + @JournalTable + ' WHERE [InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + 'AND [Scenario] = ''ACTUAL'' AND [Source] = ''' + @SourceTypeName + ''''
		IF @MasterClosedYearMonth IS NOT NULL SET @SQLStatement = @SQLStatement + ' AND [YearMonth] > ' + CONVERT(nvarchar(15), @MasterClosedYearMonth)
		EXEC sp_executesql @SQLStatement, N'@InternalVariable1 date OUT, @InternalVariable2 bigint OUT', @InternalVariable1 = @MaxPostedDate OUT, @InternalVariable2 = @MaxSourceCounter OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@JournalTable] = @JournalTable,
				[@SourceTypeName] = @SourceTypeName,
				[@SourceDatabase] = @SourceDatabase,
				[@StartYear] = @StartYear,
				[@MasterClosedYearMonth] = @MasterClosedYearMonth,
				[@MasterClosedFiscalYear] = @MasterClosedFiscalYear,
				[@MaxPostedDate] = @MaxPostedDate,
				[@MaxSourceCounter] = @MaxSourceCounter

	SET @Step = 'Create table #Journal_Update'
		IF OBJECT_ID(N'TempDB.dbo.#Journal_Update', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Journal_Update
					(
					[SourceTypeID] [int],
					[MaxSourceCounter] [bigint],
					[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [int],
					[FiscalPeriod] [int]
					)
			END
	
	SET @Step = 'Delete existing data'
		DELETE WJU
		FROM
			[pcINTEGRATOR_Log].[dbo].[wrk_Journal_Update] WJU
		WHERE
			[JobID] = @JobID AND
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[Comparison] = 'pcSource'

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Insert new data into wrk_Journal_Update'
		IF @SourceTypeID = 3 --iScala
			BEGIN
				CREATE TABLE #FiscalYear
					(
					[FiscalYear] int
					)
				
				SET @StartYear = @StartYear - 1
				SET @FiscalYear = ISNULL(@MasterClosedFiscalYear, @StartYear) + 1
				
				WHILE @FiscalYear <= YEAR(getdate()) + 1
					BEGIN
						INSERT INTO #FiscalYear
							(
							[FiscalYear]
							)
						SELECT
							[FiscalYear] = @FiscalYear

						SET @FiscalYear = @FiscalYear + 1

					END

				INSERT INTO pcINTEGRATOR_Log.dbo.wrk_Journal_Update
					(
					[JobID],
					[InstanceID],
					[VersionID],
					[SourceTypeID],
					[MaxSourceCounter],
					[Entity],
					[Book],
					[FiscalYear],
					[FiscalPeriod],
					[Comparison]
					)
				SELECT DISTINCT
					[JobID] = @JobID,
					[InstanceID] = E.InstanceID,
					[VersionID] = E.VersionID,
					[SourceTypeID] = @SourceTypeID,
					[MaxSourceCounter] = NULL,
					[Entity] = E.[MemberKey],
					[Book] = EB.[Book],
					[FiscalYear] = FY.[FiscalYear],
					[FiscalPeriod] = 0,
					[Comparison] = 'pcSource'
				FROM 
					pcINTEGRATOR_Data..[Entity] E
					INNER JOIN pcINTEGRATOR_Data..[Entity_Book] EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
					INNER JOIN #FiscalYear FY ON 1 = 1
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.SelectYN <> 0 AND
					E.DeletedID IS NULL

				SET @Inserted = @Inserted + @@ROWCOUNT
			END
		
		ELSE IF @SourceTypeID = 11 --E10
			BEGIN
				SET @SQLStatement = '
					INSERT INTO pcINTEGRATOR_Log.dbo.wrk_Journal_Update
						(
						[JobID],
						[InstanceID],
						[VersionID],
						[SourceTypeID],
						[MaxSourceCounter],
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod],
						[Comparison]
						)
					SELECT DISTINCT
						[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[SourceTypeID] = ' + CONVERT(nvarchar(15), @SourceTypeID) + ',
						[MaxSourceCounter] = ' + CASE WHEN @MaxSourceCounter IS NULL OR @FullReloadYN <> 0 THEN 'NULL' ELSE CONVERT(nvarchar(20), @MaxSourceCounter) END + ',
						[Entity] = [Company],
						[Book] = [BookID],
						[FiscalYear],
						[FiscalPeriod],
						[Comparison] = ''pcSource''
					FROM 
						' + @SourceDatabase + '.[Erp].[GLJrnDtl]'

			--IF @FullReloadYN <> 0
			--	PRINT 'Full reload'

				IF @MaxSourceCounter IS NOT NULL AND @FullReloadYN = 0 
					SET @SQLStatement = @SQLStatement + '
						WHERE
							CONVERT(bigint, [SysRevID]) > ' + CONVERT(nvarchar(15), @MaxSourceCounter)
				ELSE IF @FullReloadYN = 0 
					BEGIN

						IF @MaxPostedDate IS NOT NULL SET @SQLStatement = @SQLStatement + '
						WHERE
							[PostedDate] >= ''' + CONVERT(nvarchar(20), @MaxPostedDate) + ''''

						IF @MaxPostedDate IS NULL AND @MasterClosedFiscalYear IS NOT NULL SET @SQLStatement = @SQLStatement + '
						WHERE'

						IF @MaxPostedDate IS NOT NULL AND @MasterClosedFiscalYear IS NOT NULL SET @SQLStatement = @SQLStatement + ' AND'

						IF @MasterClosedFiscalYear IS NOT NULL SET @SQLStatement = @SQLStatement + '
							[FiscalYear] > ' + CONVERT(nvarchar(15), @MasterClosedFiscalYear)
					END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Delete rows for not selected entities and books'
		DELETE WJU
		FROM
			[pcINTEGRATOR_Log].[dbo].[wrk_Journal_Update] WJU
		WHERE
			[JobID] = @JobID AND
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[Comparison] = 'pcSource' AND
			NOT EXISTS (SELECT 1 
				FROM
					pcINTEGRATOR_Data..Entity E 
					INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.EntityID = E.EntityID AND EB.Book = WJU.Book AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
				WHERE
					E.[InstanceID] = WJU.[InstanceID] AND E.[VersionID] = WJU.[VersionID] AND E.[MemberKey] = WJU.[Entity] AND E.[SelectYN] <> 0 AND E.[DeletedID] IS NULL)

	SET @Step = 'Fill table #Journal_Update'
		INSERT INTO #Journal_Update
			(
			[SourceTypeID],
			[MaxSourceCounter],
			[Entity],
			[Book],
			[FiscalYear],
			[FiscalPeriod]
			)
		SELECT
			[SourceTypeID],
			[MaxSourceCounter],
			[Entity],
			[Book],
			[FiscalYear],
			[FiscalPeriod]
		FROM
			[pcINTEGRATOR_Log].[dbo].[wrk_Journal_Update]
		WHERE
			[JobID] = @JobID AND
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[Comparison] = 'pcSource'

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return table #Journal_Update'
		IF @CalledYN = 0
			BEGIN
				SELECT [TempTable] = '#Journal_Update', * FROM #Journal_Update ORDER BY [Entity], [Book], [FiscalYear], [FiscalPeriod]

				SET @Selected = @Selected + @@ROWCOUNT
			END
		
	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0 DROP TABLE #Journal_Update

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID=@ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID=@ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
