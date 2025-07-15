SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spStart_Job_Agent]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ApplicationID int = NULL,
	@JobName nvarchar(255) = NULL,
	@StepName nvarchar(255) = 'Load', --'Create', 'Import', 'Load' or 'Deploy'
	@AsynchronousYN bit = 0,
	@SandBox nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000192,
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
EXEC [dbo].[spStart_Job_Agent] 	@ApplicationID = 6, @StepName = 'Create'
EXEC [dbo].[spStart_Job_Agent] 	@ApplicationID = 6, @StepName = 'Load'
EXEC [dbo].[spStart_Job_Agent] 	@ApplicationID = 400, @JobName = 'pcDATA_DevTest76_Load', @StepName = 'Process', @AsynchronousYN = 1

EXEC [spStart_Job_Agent] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@instance_id int,
	@job_id uniqueidentifier,
	@Run_Date int,
	@Run_Time int,
	@DestinationDatabase nvarchar(255),
	@SysJob_Instance_ID int,
	@Counter int = 0,
	@CounterString nvarchar(50),
	@UserNameDisplay nvarchar(100),

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
	@Version nvarchar(50) = '2.0.3.2152'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'PROBABLY OBSOLETE AND CANDIDATE TO REMOVE, Start job in SQL Server agent',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.2113' SET @Description = 'Handle SandBox.'
		IF @Version = '1.4.0.2128' SET @Description = 'Handle case sensitive.'
		IF @Version = '1.4.0.2134' SET @Description = '@JobName added as parameter.'
		IF @Version = '2.0.3.2152' SET @Description = 'Upgraded template. Return parameters for checking status'

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
		EXEC [spGet_User] @UserID = @UserID, @UserNameDisplay = @UserNameDisplay OUT

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ApplicationID = ISNULL(@ApplicationID, ApplicationID)
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID
		
		SELECT
			@InstanceID = ISNULL(@InstanceID, A.InstanceID),
			@VersionID = ISNULL(@VersionID, A.VersionID),
			@DestinationDatabase = ISNULL(@SandBox, A.DestinationDatabase)
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID

	SET @Step = 'Set JobName'
		IF @JobName IS NULL
			BEGIN
				IF @StepName IN ('Create', 'Import')
					SET @JobName = @DestinationDatabase + '_Create'
				ELSE IF @StepName IN ('Load', 'Deploy')
					SET @JobName = @DestinationDatabase + '_Load'
			END

	SET @Step = 'Check existence of @StepName = LogStartTime'
		IF @StepName IN ('Create', 'Load') AND
			(
			SELECT 
				COUNT(1) 
			FROM
				msdb..sysjobs J
				INNER JOIN msdb..sysjobsteps JS ON JS.job_id = J.job_id AND JS.step_id = 1 AND JS.step_name = 'LogStartTime'
			WHERE
				J.[name] = 'Test'
			) > 0

			SET @StepName = 'LogStartTime'

	SET @Step = 'Enable Job'
		EXEC msdb.[dbo].sp_update_job
			@job_name = @JobName,
			@enabled = 1

	SET @Step = 'Get @SysJob_Instance_ID'
		SELECT
			@SysJob_Instance_ID = MAX(H.instance_id)
		FROM
			msdb..sysjobhistory H 
			INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id
		SET @SysJob_Instance_ID = ISNULL(@SysJob_Instance_ID, 0)

	SET @Step = 'Start the Job'
		EXEC msdb.[dbo].sp_start_job 
			 @job_name = @JobName,
			 @step_name = @StepName

	SET @Step = 'Wait loop if not asynchronous'
		IF @AsynchronousYN = 0
			BEGIN
				WHILE (SELECT COUNT(1) FROM msdb..sysjobhistory H INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id WHERE H.instance_id > @SysJob_Instance_ID AND H.step_id = 0) = 0
					BEGIN
						WAITFOR DELAY '00:00:01'
						IF @Counter < 95
							BEGIN
								SET @Counter = @Counter + 2
								SET @CounterString = CONVERT(nvarchar(10), @Counter) + ' percent'
								RAISERROR (@CounterString, 0, @Counter) WITH NOWAIT
							END
					END
			END
		ELSE
			WHILE @Run_Date IS NULL
				BEGIN
					WAITFOR DELAY '00:00:01'
					SELECT
						@instance_id = MIN(instance_id),
						@job_id = H.job_id,
						@run_date = MIN(run_date),
						@run_time = MIN(run_time)
					FROM
						msdb..sysjobhistory H
						INNER JOIN msdb..sysjobs J ON J.[name] = @JobName AND J.job_id = H.job_id
					WHERE
						H.instance_id > @SysJob_Instance_ID
					GROUP BY
						H.job_id
				END

	SET @Step = 'Get Return Values'
		IF @AsynchronousYN = 0
			SELECT
				[JobStatus] = CASE H.run_status WHEN 0 THEN 'Failed' WHEN 1 THEN 'Successful' WHEN 3 THEN 'Cancelled' WHEN 4 THEN 'In Progress' END,
				[StartTime] = DATEADD(s, (run_time / 10000) * 3600 + (run_time / 100 % 100) * 60 + (run_time % 100), CONVERT(datetime, CONVERT(nvarchar(15), run_date), 112)),
				[EndTime] = DATEADD(s, (run_time / 10000) * 3600 + (run_time / 100 % 100) * 60 + (run_time % 100) + [run_duration], CONVERT(datetime, CONVERT(nvarchar(15), run_date), 112)),
				[Duration] = H.run_duration,
				[Message] = H.[message]
			FROM
				msdb..sysjobhistory H 
				INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id
			WHERE
				H.instance_id > @SysJob_Instance_ID AND
				H.step_id = 0
		ELSE
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@instance_id] = @instance_id,
				[@job_id] = @job_id,
				[@run_date] = @run_date,
				[@run_time] = @run_time,
				[@UserNameDisplay] = @UserNameDisplay,
				[@JobName] = @JobName

	SET @Step = 'Disable Job'
		IF RIGHT(@JobName, 6) = 'Create'
			EXEC msdb.[dbo].sp_update_job
				@job_name = @JobName,
				@enabled = 0

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
