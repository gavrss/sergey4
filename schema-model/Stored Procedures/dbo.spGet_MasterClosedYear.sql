SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_MasterClosedYear]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@MasterClosedYearMonth int = NULL OUT,
	@MasterClosedYear int = NULL OUT,
	@MasterClosedFiscalYear int = NULL OUT,
	@FinancialsClosedYearMonth int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000546,
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
EXEC [spGet_MasterClosedYear] @UserID=-10, @InstanceID=413, @VersionID=1008, @Debug=1

DECLARE @MasterClosedYearMonth int, @FinancialsClosedYearMonth int
EXEC [spGet_MasterClosedYear] @UserID=-10, @InstanceID=454, @VersionID=1021, @MasterClosedYearMonth = @MasterClosedYearMonth OUT, @FinancialsClosedYearMonth = @FinancialsClosedYearMonth OUT
SELECT [@MasterClosedYearMonth] = @MasterClosedYearMonth, [@FinancialsClosedYearMonth] = @FinancialsClosedYearMonth

EXEC [spGet_MasterClosedYear] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@FiscalYearStartMonth int,
	@FiscalYearNaming int,
	@MasterClosedMonth int,

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
			@ProcedureDescription = 'Return Master Closed Year',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2152' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Added @FinancialsClosedYearMonth'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID=@ProcedureID
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

		SELECT
			@MasterClosedMonth = A.MasterClosedMonth,
			@FinancialsClosedYearMonth = A.FinancialsClosedMonth,
			@FiscalYearStartMonth = ISNULL(A.FiscalYearStartMonth, I.FiscalYearStartMonth),
			@FiscalYearNaming = I.FiscalYearNaming
		FROM
			[Application] A
			INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID 
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		IF @DebugBM & 2 > 0 SELECT [@MasterClosedMonth] = @MasterClosedMonth, [@FiscalYearStartMonth] = @FiscalYearStartMonth, [@FiscalYearNaming] = @FiscalYearNaming

	SET @Step = 'Set return values'
		SELECT
			@MasterClosedYearMonth = @MasterClosedMonth,
			@MasterClosedYear = @MasterClosedMonth / 100 + CASE WHEN @MasterClosedMonth % 100 = 12 THEN 0 ELSE -1 END,
			@MasterClosedFiscalYear = @MasterClosedMonth / 100 + 
										CASE WHEN @FiscalYearStartMonth = 1
										THEN
											CASE WHEN @MasterClosedMonth % 100 = 12 THEN 0 ELSE -1 END
										ELSE
											CASE WHEN @FiscalYearStartMonth - @MasterClosedMonth % 100 = 1 THEN 0 ELSE -1 END - CASE WHEN @FiscalYearNaming = 0 THEN 1 ELSE 0 END
										END

	SET @Step = 'Return values'
		IF @DebugBM & 1 > 0
			SELECT
				[@MasterClosedYearMonth] = @MasterClosedYearMonth,
				[@MasterClosedYear] = @MasterClosedYear,
				[@MasterClosedFiscalYear] = @MasterClosedFiscalYear

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
