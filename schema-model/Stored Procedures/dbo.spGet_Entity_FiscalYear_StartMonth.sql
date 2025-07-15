SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Entity_FiscalYear_StartMonth]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@EntityID int = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL OUT,
	@FiscalPeriod int = NULL OUT,
	@MonthID int = NULL OUT,
	@StartMonth int = NULL OUT,
	@EndMonth int = NULL OUT,
	@Entity_FiscalYearID int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000309,
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
DECLARE @StartMonth int, @EndMonth int, @FiscalYear int, @FiscalPeriod int
EXEC dbo.[spGet_Entity_FiscalYear_StartMonth] @UserID = -10, @InstanceID = 404, @VersionID = 1003, @EntityID = 1001, @Book = 'GL', @MonthID = 201807, @StartMonth = @StartMonth OUT, @EndMonth = @EndMonth OUT, @FiscalYear = @FiscalYear OUT, @FiscalPeriod = @FiscalPeriod OUT
SELECT StartMonth = @StartMonth, EndMonth = @EndMonth, FiscalYear = @FiscalYear, FiscalPeriod = @FiscalPeriod

DECLARE @StartMonth int, @EndMonth int, @FiscalYear int = 2018, @FiscalPeriod int = 7, @MonthID int
EXEC dbo.[spGet_Entity_FiscalYear_StartMonth] @UserID = -10, @InstanceID = -1156, @VersionID = -1094, @EntityID = 10140, @Book = 'MAIN', @FiscalYear = @FiscalYear OUT, @FiscalPeriod = @FiscalPeriod OUT, @MonthID = @MonthID OUT, @StartMonth = @StartMonth OUT, @EndMonth = @EndMonth OUT, @Debug = 1
SELECT StartMonth = @StartMonth, EndMonth = @EndMonth, FiscalYear = @FiscalYear, FiscalPeriod = @FiscalPeriod, MonthID = @MonthID

EXEC [spGet_Entity_FiscalYear_StartMonth] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@FiscalYearNaming int,

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
	@Version nvarchar(50) = '2.0.2.2148'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Conversion between FiscalYear/FiscalPeriod and CalendarMonth',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Changed calculation of FiscalPeriod.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@FiscalYearNaming = [FiscalYearNaming]
        FROM
			[pcINTEGRATOR].[dbo].[Instance]
		WHERE
			InstanceID = @InstanceID

		IF @Debug <> 0 SELECT FiscalYearNaming = @FiscalYearNaming

	SET @Step = 'Check that @FiscalPeriod or @MonthID is set.'
		IF (@FiscalYear IS NULL OR @FiscalPeriod IS NULL) AND @MonthID IS NULL
			BEGIN
				SET @Message = 'Either @FiscalYear and @FiscalPeriod or @MonthID must be set.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Return StartMonth and EndMonth for selected MonthID'
		IF @MonthID IS NOT NULL
			BEGIN
				SELECT 
					@StartMonth = CASE WHEN @MonthID % 100 >= StartMonth % 100 THEN (@MonthID / 100) * 100 + StartMonth % 100 ELSE ((@MonthID / 100) - 1) * 100 + StartMonth % 100 END,
					@EndMonth = CASE WHEN @MonthID % 100 <= EndMonth % 100 THEN (@MonthID / 100) * 100 + EndMonth % 100 ELSE ((@MonthID / 100) + 1) * 100 + EndMonth % 100 END,
					@Entity_FiscalYearID = Entity_FiscalYearID
				FROM
					Entity_FiscalYear
				WHERE
					InstanceID = @InstanceID AND
					EntityID = @EntityID AND
					Book = @Book AND
					@MonthID BETWEEN StartMonth AND EndMonth

				SELECT
					@FiscalYear = @StartMonth / 100 + @FiscalYearNaming,
					@FiscalPeriod = CASE WHEN (@MonthID % 100 - @StartMonth % 100 + 13) % 12 = 0 THEN 12 ELSE (@MonthID % 100 - @StartMonth % 100 + 13) % 12 END

--					@FiscalPeriod = (@StartMonth % 100 + @MonthID % 100 + 11) % 12
			END
		ELSE IF @FiscalYear IS NOT NULL AND	@FiscalPeriod IS NOT NULL
			BEGIN
				SET @FiscalPeriod = CASE WHEN @FiscalPeriod < 1 THEN 1 ELSE CASE WHEN @FiscalPeriod > 12 THEN 12 ELSE @FiscalPeriod END END
				
				SELECT 
					StartMonth = MAX(StartMonth)
				FROM
					Entity_FiscalYear
				WHERE
					InstanceID = @InstanceID AND
					EntityID = @EntityID AND
					Book = @Book AND
					StartMonth <= (@FiscalYear - @FiscalYearNaming) * 100 + StartMonth % 100 + @FiscalPeriod + CASE WHEN StartMonth % 100 + @FiscalPeriod > 12 THEN 88 ELSE 0 END
			END

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
