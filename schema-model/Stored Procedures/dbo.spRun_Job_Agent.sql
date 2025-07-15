SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spRun_Job_Agent] 

	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,
	@JobID int = NULL,
	@JobName nvarchar(255) = NULL,
	@StepName nvarchar(255) = NULL,
	@AsynchronousYN bit = 0,
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

SET ANSI_WARNINGS OFF

--EXEC [dbo].[spRun_Job_Agent] @GetVersion = 1
--EXEC [dbo].[spRun_Job_Agent] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 2, @JobName = '304_test'

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SysJob_Instance_ID int,
	@Counter int = 0,
	@CounterString nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'SP created'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF 	@UserID IS NULL OR @InstanceID IS NULL OR @VersionID IS NULL OR @JobID IS NULL OR @JobName IS NULL
	BEGIN
		PRINT 'Parameter @UserID, @InstanceID, @VersionID, @JobID and @JobName must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

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

	SET @Step = 'Get Return Values'
		SELECT
			JobName = J.name, 
			JobStatus = H.run_status,
			[Description] =	CASE H.run_status WHEN 0 THEN 'Failed' WHEN 1 THEN 'Successful' WHEN 3 THEN 'Cancelled' WHEN 4 THEN 'In Progress' END,
			[Message] = H.[message],
			Duration = H.run_duration
		FROM
			msdb..sysjobhistory H 
			INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id
		WHERE
			H.instance_id > @SysJob_Instance_ID AND
			H.step_id = 0

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH






GO
