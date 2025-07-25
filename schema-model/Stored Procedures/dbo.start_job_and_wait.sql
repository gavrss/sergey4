SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [dbo].[start_job_and_wait]
	@job_name SYSNAME ,     -- INPUT YOUR JOB NAME HERE
	@WaitTime DATETIME = '00:00:01'  -- default check frequency
AS
-- exec start_job_and_wait @job_name = 'REMichel_SSIS'
--SET TRANSACTION ISOLATIONLEVEL READ UNCOMMITTED
SET NOCOUNT ON
DECLARE
@JobCompletionStatus INT
-- CHECK IF IT IS A VALID AND EXISTING JOB NAME
IF NOT EXISTS (SELECT * FROM msdb..sysjobs WHERE name =@job_name)
BEGIN
       RAISERROR ('[ERROR]:[%s] job does not exist. Please check',16, 1, @job_name) WITH LOG
       RETURN
END
DECLARE @job_id             UNIQUEIDENTIFIER
DECLARE @job_owner   sysname
--Createing TEMP TABLE
CREATE TABLE #xp_results (job_id             UNIQUEIDENTIFIER NOT NULL,
                        last_run_date         INT              NOT NULL,
                        last_run_time         INT              NOT NULL,
                        next_run_date         INT              NOT NULL,
                        next_run_time         INT              NOT NULL,
                        next_run_schedule_id  INT              NOT NULL,
                        requested_to_run      INT              NOT NULL, -- BOOL
                        request_source        INT              NOT NULL,
                        request_source_id     sysname          COLLATE DATABASE_DEFAULT NULL,
                        running               INT              NOT NULL, -- BOOL
                        current_step          INT              NOT NULL,
                        current_retry_attempt INT              NOT NULL,
                        job_state             INT              NOT NULL)
SELECT @job_id = job_id FROM msdb.dbo.sysjobs WHERE name = @job_name
SELECT @job_owner = SUSER_SNAME()
INSERT INTO #xp_results EXECUTE master.dbo.xp_sqlagent_enum_jobs  1, @job_owner, @job_id
-- Start the job only if it is not already running
IF NOT EXISTS(SELECT TOP 1 * FROM #xp_results WHERE running = 1)
       EXEC msdb.dbo.sp_start_job @job_name = @job_name
-- Give it 2 seconds for think time.
WAITFOR DELAY '00:00:02'
DELETE FROM #xp_results
INSERT INTO #xp_results
EXECUTE master.dbo.xp_sqlagent_enum_jobs  1, @job_owner, @job_id
WHILE EXISTS(SELECT TOP 1 * FROM #xp_results WHERE running = 1)
BEGIN
       WAITFOR DELAY @WaitTime
       -- Display informational message at each interval
       -- raiserror('JOB IS RUNNING', 0, 1 ) WITH NOWAIT 
       DELETE FROM #xp_results
       INSERT INTO #xp_results
       EXECUTE master.dbo.xp_sqlagent_enum_jobs  1, @job_owner, @job_id
END
SELECT top 1 @JobCompletionStatus =run_status    FROM msdb.dbo.sysjobhistory   
WHERE job_id = @job_id     AND step_id = 0   
order by run_date desc, run_time desc   
IF @JobCompletionStatus = 1
       PRINT 'The job ran Successful'
ELSE IF @JobCompletionStatus =3
       PRINT 'The job is Cancelled'
ELSE
BEGIN
       RAISERROR ('[ERROR]:%s job is either failed or not in good state. Please check',16, 1, @job_name) WITH LOG
END

GO
