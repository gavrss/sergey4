SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_DC_Financials_Update]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@JournalTable nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000615,
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
EXEC [spGet_DC_Financials_Update] @UserID=-10, @InstanceID=454, @VersionID=1021, @JobID = 60, @DebugBM=2

EXEC [spGet_DC_Financials_Update] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(MAX),
	@MasterClosedYearMonth int,
	@FinancialsClosedYearMonth int,

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
	@Version nvarchar(50) = '2.1.0.2155'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Check Journal for updated Periods',
			@MandatoryParameter = 'JobID' --Without @, separated by |

		IF @Version = '2.1.0.2155' SET @Description = 'Procedure created.'

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

		EXEC [spGet_MasterClosedYear] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @MasterClosedYearMonth=@MasterClosedYearMonth OUT, @FinancialsClosedYearMonth = @FinancialsClosedYearMonth OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@JournalTable] = @JournalTable,
				[@MasterClosedYearMonth] = @MasterClosedYearMonth,
				[@FinancialsClosedYearMonth] = @FinancialsClosedYearMonth

	SET @Step = 'Create table #DC_Financials_Update'
		IF OBJECT_ID(N'TempDB.dbo.#DC_Financials_Update', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #DC_Financials_Update
					(
					[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [int],
					[FiscalPeriod] [int],
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Insert into #DC_Financials_Update'
		SET @SQLStatement = '
			INSERT INTO #DC_Financials_Update
				(
				[Entity],
				[Book],
				[FiscalYear],
				[FiscalPeriod],
				[Scenario]
				)
			SELECT
				[Entity] = J.[Entity],
				[Book] = J.[Book],
				[FiscalYear] = J.[FiscalYear],
				[FiscalPeriod] = MIN([FiscalPeriod]),
				[Scenario] = J.[Scenario]
			FROM
				' + @JournalTable + ' J
			WHERE
				J.[JobID] = ' + CONVERT(nvarchar(15), @JobID) + CASE WHEN @MasterClosedYearMonth IS NOT NULL THEN ' AND
				J.[YearMonth] > ' + CONVERT(nvarchar(15), @MasterClosedYearMonth) ELSE '' END + CASE WHEN @FinancialsClosedYearMonth IS NOT NULL THEN ' AND
				J.[YearMonth] > ' + CONVERT(nvarchar(15), @FinancialsClosedYearMonth) ELSE '' END + '
			GROUP BY
				J.[Entity],
				J.[Book],
				J.[FiscalYear],
				J.[Scenario]'

			IF @DebugBM & 2 > 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return table #Journal_Update'
		IF @CalledYN = 0
			BEGIN
				SELECT [TempTable] = '#DC_Financials_Update', * FROM #DC_Financials_Update ORDER BY [Entity], [Book], [FiscalYear], [FiscalPeriod], [Scenario]

				SET @Selected = @Selected + @@ROWCOUNT
			END
		
	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0 DROP TABLE #DC_Financials_Update

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
