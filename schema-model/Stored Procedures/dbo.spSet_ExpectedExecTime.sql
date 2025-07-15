SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_ExpectedExecTime]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 0,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000791,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spSet_ExpectedExecTime] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID = 1002, @Duration = '00:04:25', @DebugBM=3

EXEC [spSet_ExpectedExecTime] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
--	@LastExecTime time(7),
	@ExpectedExecTime time(7),
	@ExpectedExecTime_Second int,
	@Duration_Second int,
	@Hour int,
	@Minute int,
	@Second int,
	
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
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Calculate and set LastExecTime and ExpectedExecTime.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2173' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Get @ExpectedExecTime'
		SELECT
			@ExpectedExecTime = [ExpectedExecTime]
		FROM
			[pcINTEGRATOR_Data].[dbo].[BusinessRule]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID

	SET @Step = 'Calculate new ExpectedExecTime'
		SELECT
			@ExpectedExecTime_Second = DATEPART(hh, @ExpectedExecTime) * 3600 + DATEPART(mi, @ExpectedExecTime) * 60 + DATEPART(ss, @ExpectedExecTime),
			@Duration_Second = DATEPART(hh, @Duration) * 3600 + DATEPART(mi, @Duration) * 60 + DATEPART(ss, @Duration)

		IF @DebugBM & 2 > 0 SELECT [@ExpectedExecTime] = @ExpectedExecTime, [@Duration] = @Duration, [@ExpectedExecTime_Second] = @ExpectedExecTime_Second, [@Duration_Second] = @Duration_Second

		SET @ExpectedExecTime_Second = (@ExpectedExecTime_Second + (@Duration_Second * 1.1)) / 2

		SELECT
			@Hour = @ExpectedExecTime_Second / 3600,
			@Minute = (@ExpectedExecTime_Second - (3600 * (@ExpectedExecTime_Second / 3600))) / 60,
			@Second = @ExpectedExecTime_Second - (3600 * (@ExpectedExecTime_Second / 3600)) - 60 * ((@ExpectedExecTime_Second - (3600 * (@ExpectedExecTime_Second / 3600))) / 60)

		SET @ExpectedExecTime = TIMEFROMPARTS (@Hour, @Minute, @Second, 0, 0)
		
		IF @DebugBM & 2 > 0 
			SELECT
				[@ExpectedExecTime_Second] = @ExpectedExecTime_Second,
				[@Hour] = @Hour,
				[@Minute] = @Minute,
				[@Second] = @Second,
				[@ExpectedExecTime] = @ExpectedExecTime
		
	SET @Step = 'Update BusinessRule'
		UPDATE BR
		SET
			[LastExecTime] = @Duration,
			[ExpectedExecTime] = @ExpectedExecTime
		FROM
			[pcINTEGRATOR_Data].[dbo].[BusinessRule] BR
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
