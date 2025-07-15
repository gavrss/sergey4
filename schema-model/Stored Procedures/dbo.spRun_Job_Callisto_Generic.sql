SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spRun_Job_Callisto_Generic]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobName nvarchar(255) = 'Callisto_Generic',
	@StepName nvarchar(255) = NULL, --Import, Load, Deploy, Refresh, RunModelRule, DeployRole, Create, ETLFull, ETLData, GenericSP
	@AsynchronousYN bit = 0,
	@ModelName nvarchar(50) = NULL, --Mandatory for Refresh and ETLData
	@SourceDatabase nvarchar(100) = NULL, --Mandatory for Import
	@Database nvarchar(100) = NULL, --Mandatory for GenericSP
	@CommandStringGeneric nvarchar(4000) = NULL, --Mandatory for GenericSP
	@JobListID int = NULL, --Mandatory for ETLFull and ETLData
	@JobQueueStatusID int = 1,
	@MasterCommand nvarchar(100) = NULL,
	@JobQueueYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000316,
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
EXEC [spRun_Job_Callisto_Generic] @UserID=-10, @InstanceID=52, @VersionID=1035, @StepName = 'ETLFull', @JobListID = 2004, @AsynchronousYN = 1, @Debug=1
EXEC spPortalAdmin_LoadCallisto @CallistoDeployYN='0',@FullReloadYN='0',@InstanceID='732',@UserID='-10',@VersionID='1165',@DebugBM=4

EXEC [spRun_Job_Callisto_Generic] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ParallelJob# int = 50,
	@JobNo int,
	@JobNo_String nvarchar(3),
	@ApplicationServer nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@WebServicePath nvarchar(100),
	@CommandString nvarchar(4000),
	@CommandStringDeploy nvarchar(4000),
	@CommandStringRefresh nvarchar(4000),
	@Counter int = 0,
	@CounterString nvarchar(50),
	@SysJob_InstanceID int,
	@StepID int,
	@JobQueueID int,
	@Parameter nvarchar(400),
	@EnhancedStorageYN bit,
	@CallistoDeployAndRefreshYN bit = 1,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Run different web services or other Callisto related jobs',
			@MandatoryParameter = 'StepName' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2148' SET @Description = 'Queue handling.'
		IF @Version = '2.0.3.2154' SET @Description = 'Add step for creating new Callisto database. Add step ETL.'
		IF @Version = '2.1.0.2159' SET @Description = 'DB-539: Return parameter info. Use sub routine [spSet_Job] Add parameter @MasterCommand.'
		IF @Version = '2.1.0.2160' SET @Description = 'Added @StepName info when displaying [sysjobhistory].'
		IF @Version = '2.1.0.2162' SET @Description = 'Added parameter @EndOfSequenceYN when calling spRun_Job. Added @MasterCommand to @Parameter in JobQueue.'
		IF @Version = '2.1.1.2172' SET @Description = 'Increased size of variable @Parameter to 400.'
		IF @Version = '2.1.1.2173' SET @Description = 'Added @StepName GenericSP'
		IF @Version = '2.1.1.2174' SET @Description = 'Increased Callisto timeout from 900000 to 1800000 for StepName Deploy and ETLFull.'
		IF @Version = '2.1.2.2191' SET @Description = 'Added @EnhancedStorageYN.'
		IF @Version = '2.1.2.2196' SET @Description = 'Increased Callisto timeout from 1800000 to 3600000 for StepName Deploy and ETLFull; and from 900000 to 1800000 fro StepName DeployRole.'
		IF @Version = '2.1.2.2197' SET @Description = 'EA-6904: Do not execute Steps ''ETLFull_3_Deploy'' and ''ETLData_3_Refresh'' for @EnhanceStorageYN = 1. Increased Callisto timeout from 3600000 to 4500000 for StepName Deploy and ETLFull. EA-7131 Increased Callisto timeout from 4500000 to 5400000 for StepName Deploy and ETLFull.'
		IF @Version = '2.1.2.2199' SET @Description = 'Set @ParallelJob# = 25 and check for current session in table msdb.dbo.syssessions. Added parameter @JobID when calling [spSet_JobQueue]. Increased @ParallelJob# = 50. Turned off Deploy and Refresh steps for Application.[CallistoDeployAndRefreshYN]=0'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SET @MasterCommand = ISNULL(@MasterCommand, @ProcedureName)

		SELECT
			@ApplicationServer = A.ApplicationServer,
			@CallistoDatabase = A.DestinationDatabase,
			@ETLDatabase = A.ETLDatabase,
			@EnhancedStorageYN = A.EnhancedStorageYN,
			@CallistoDeployAndRefreshYN = A.[CallistoDeployAndRefreshYN]
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID

		SET @SourceDatabase = ISNULL(@SourceDatabase, @ETLDatabase)

		IF (SELECT COUNT(1) FROM CallistoAppDictionary.sys.tables WHERE name = 'DbVersion') > 0
			SET @WebServicePath = 'CLAdmin'				--Version 4 of Callisto
		ELSE
			SET @WebServicePath = 'Callisto_Server'		--Version 1 - 3 of Callisto

		IF @DebugBM & 2 > 0 
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@JobName] = @JobName,
				[@StepName] = @StepName,
				[@AsynchronousYN] = @AsynchronousYN,
				[@ModelName] = @ModelName,
				[@SourceDatabase] = @SourceDatabase,
				[@JobListID] = @JobListID,
				[@Database] = @Database,
				[@CommandStringGeneric] = @CommandStringGeneric,
				[@JobID] = @JobID

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			BEGIN
				EXEC [spSet_Job]
					@UserID=@UserID,
					@InstanceID=@InstanceID,
					@VersionID=@VersionID,
					@ActionType='Start',
					@MasterCommand=@MasterCommand,
					@CurrentCommand=@ProcedureName,
					@JobQueueYN=@JobQueueYN,
					@CheckCount=0,
					@JobID=@JobID OUT
			END

	SET @Step = 'Check for on going jobs'
		SELECT @JobQueueYN = [JobQueueYN] FROM [pcINTEGRATOR_Log].[dbo].[Job] WHERE [JobID] = @JobID

		IF @DebugBM & 2 > 0 SELECT [@JobQueueYN] = @JobQueueYN, [@JobQueueStatusID] = @JobQueueStatusID

		IF @JobQueueYN <> 0 AND @JobQueueStatusID = 1
			BEGIN
				SET @Parameter = 
					CASE WHEN @UserID IS NULL THEN '' ELSE '@UserID=' + CONVERT(nvarchar(15), @UserID) + ',' END +
					CASE WHEN @InstanceID IS NULL THEN '' ELSE '@InstanceID=' + CONVERT(nvarchar(15), @InstanceID) + ',' END +
					CASE WHEN @VersionID IS NULL THEN '' ELSE '@VersionID=' + CONVERT(nvarchar(15), @VersionID) + ',' END +
					CASE WHEN @JobID IS NULL THEN '' ELSE '@JobID=' + CONVERT(nvarchar(15), @JobID) + ',' END +
					CASE WHEN @JobName IS NULL THEN '' ELSE '@JobName=''' + @JobName + ''',' END +
					CASE WHEN @StepName IS NULL THEN '' ELSE '@StepName=''' + @StepName + ''',' END +
					CASE WHEN @MasterCommand IS NULL THEN '' ELSE '@MasterCommand=''' + @MasterCommand + ''',' END +
					CASE WHEN @AsynchronousYN IS NULL THEN '' ELSE '@AsynchronousYN=' + CONVERT(nvarchar(15), CONVERT(int, @AsynchronousYN)) + ',' END +
--					CASE WHEN @ModelName IS NULL THEN '' ELSE '@ModelName=''' + @ModelName + ''',' END +
					CASE WHEN @ModelName IS NULL THEN '@ModelName=''Financials'',' ELSE '@ModelName=''' + @ModelName + ''',' END +
					CASE WHEN @SourceDatabase IS NULL THEN '' ELSE '@SourceDatabase=''' + @SourceDatabase + ''',' END +
					CASE WHEN @JobListID IS NULL THEN '' ELSE '@JobListID=' + CONVERT(nvarchar(15), @JobListID) + ',' END +
					'@JobQueueStatusID = 2'

		--		IF LEN(@Parameter) > 5 SET @Parameter = LEFT(@Parameter, LEN(@Parameter) -1)
		
				EXEC [spSet_JobQueue]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@JobQueueStatusID = @JobQueueStatusID,
					@StoredProcedure = @ProcedureName,
					@Parameter = @Parameter,
					@JobListID = @JobListID,
					@JobID = @JobID,
					@JobQueueID = @JobQueueID OUT

				IF @DebugBM & 2 > 0 SELECT [@JobQueueID] = @JobQueueID

				IF @JobQueueID IS NOT NULL
					BEGIN
						SET @Message = 'This job is set to queue with @JobQueueID = ' + CONVERT(nvarchar(20), @JobQueueID) + '.'
						SET @Severity = 0
						GOTO EXITPOINT
					END
			END

	SET @Step = 'Select Job to run, queue handling for available agent jobs'
		WHILE @JobName = 'Callisto_Generic'	
			BEGIN
				SET @JobNo = 1
				WHILE @JobNo <= @ParallelJob#
					BEGIN 
						SET @JobNo_String = CASE WHEN @JobNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), @JobNo)
						IF NOT EXISTS
							(     
							SELECT 1 
							FROM
								msdb.dbo.sysjobs_view job  
								INNER JOIN msdb.dbo.sysjobactivity activity on job.job_id = activity.job_id 
								INNER JOIN
									(
									SELECT
										[session_id] = MAX(s.[session_id])
									FROM
										msdb.dbo.syssessions s
										INNER JOIN (SELECT MAX_agent_start_date = MAX(agent_start_date) FROM msdb.dbo.syssessions) masd ON masd.MAX_agent_start_date = s.agent_start_date
									) [sess] ON [sess].[session_id] = activity.[session_id]
							WHERE  
								activity.run_Requested_date IS NOT NULL AND
								activity.stop_execution_date IS NULL AND
								job.[name] = @JobName + @JobNo_String
							)
							BEGIN
								SET @JobName = @JobName + @JobNo_String
								GOTO CONTINUATION						
							END
						ELSE
							SET @JobNo = @JobNo + 1 
					END

				WAITFOR DELAY '00:00:01'
			END

			IF @DebugBM & 2 > 0 SELECT [@JobNo] = @JobNo

		CONTINUATION:

		IF @Debug <> 0 SELECT [@JobName] = @JobName

	SET @Step = 'Set @CommandString for step Start'
		SET @CommandString = '
EXEC spRun_Procedure_KeyValuePair 
@ProcedureName = ''spSet_JobAgent_Status'', 
@JSON = ''
	[
	{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
	{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
	{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
	{"TKey" : "JobName",  "TValue": "' + @JobName + '"},
	{"TKey" : "StepName",  "TValue": "' + @StepName + '"},
	{"TKey" : "Status",  "TValue": "Start"},
	{"TKey" : "MasterCommand",  "TValue": "' + @MasterCommand + '"},
	{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"}
	]'''

		SELECT 
			@StepID = JS.step_id
		FROM
			msdb..sysjobsteps JS
			INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
		WHERE
			JS.[step_name] = @StepName

		EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString

	SET @Step = 'Set @CommandString for step Success'
		SET @CommandString = '
EXEC spRun_Procedure_KeyValuePair 
@ProcedureName = ''spSet_JobAgent_Status'', 
@JSON = ''
	[
	{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
	{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
	{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
	{"TKey" : "JobName",  "TValue": "' + @JobName + '"},
	{"TKey" : "StepName",  "TValue": "Success"},
	{"TKey" : "Status",  "TValue": "Success"},
	{"TKey" : "MasterCommand",  "TValue": "' + @MasterCommand + '"},
	{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"}
	]'''

		SELECT 
			@StepID = JS.step_id
		FROM
			msdb..sysjobsteps JS
			INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
		WHERE
			JS.[step_name] = 'Success'

		EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString

	SET @Step = 'Set @CommandString for step Failure'
		SET @CommandString = '
EXEC spRun_Procedure_KeyValuePair 
@ProcedureName = ''spSet_JobAgent_Status'', 
@JSON = ''
	[
	{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
	{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
	{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
	{"TKey" : "JobName",  "TValue": "' + @JobName + '"},
	{"TKey" : "StepName",  "TValue": "Failure"},
	{"TKey" : "Status",  "TValue": "Failure"},
	{"TKey" : "MasterCommand",  "TValue": "' + @MasterCommand + '"},
	{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"}
	]'''

		SELECT 
			@StepID = JS.step_id
		FROM
			msdb..sysjobsteps JS
			INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
		WHERE
			JS.[step_name] = 'Failure'

		EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString



	SET @Step = 'Set @CommandStringDeploy'
		IF @StepName IN ('Deploy', 'ETLFull') AND @EnhancedStorageYN = 0
			BEGIN
				SET	@CommandStringDeploy = '$ErrorActionPreference = "Stop"
[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create("http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx/DeployApplication2")
$webRequest.UseDefaultCredentials = $true
$webRequest.PreAuthenticate = $true
$webRequest.ContentType = "application/x-www-form-urlencoded"
$webRequest.Timeout = 5400000
$webRequest.Method = "POST"
$enc = [System.Text.Encoding]::GetEncoding("UTF-8")
[byte[]]$bytes = $enc.GetBytes("sAppLabel=' + @CallistoDatabase + '&bDefrag=true")
$webRequest.ContentLength = $bytes.Length
[System.IO.Stream]$reqStream = $webRequest.GetRequestStream()
$reqStream.Write($bytes, 0, $bytes.Length)
$reqStream.Flush()
$resp = $webRequest.GetResponse()
$rs = $resp.GetResponseStream()
[System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
$statusCode = [int]$resp.StatusCode
if ($statusCode -eq 200) {
    [xml]$res = $sr.ReadToEnd()
    if ($res.error -ne $null) { Write-Error($res.error.msg) }
    else { Write-Output($res.InnerXml) }
} 
else {
    Write-Error($statusCode.ToString() + "-" + $resp.StatusCode + "`n" + $sr.ReadToEnd())
}'
			-- if we don't need to Deploy/Refresh: then comment powershell command
			if @CallistoDeployAndRefreshYN = 0
				BEGIN
				SET	@CommandStringDeploy = '<# ' + CHAR(10) + CHAR(13) + @CommandStringDeploy + CHAR(10) + CHAR(13) + ' #>'
				END
			END

	SET @Step = 'Set @CommandStringRefresh'
		IF @StepName IN ('Refresh', 'ETLData') AND @EnhancedStorageYN = 0
			BEGIN
				IF @ModelName IS NULL
					BEGIN
						SET @Message = 'For @StepName IN (Refresh, ETLData), @ModelName is mandatory.'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				SET	@CommandStringRefresh = '$ErrorActionPreference = "Stop"
[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create("http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx/ProcessModelData")
$webRequest.UseDefaultCredentials = $true
$webRequest.PreAuthenticate = $true
$webRequest.ContentType = "application/x-www-form-urlencoded"
$webRequest.Timeout = 900000
$webRequest.Method = "POST"
$enc = [System.Text.Encoding]::GetEncoding("UTF-8")
[byte[]]$bytes = $enc.GetBytes("sAppLabel=' + @CallistoDatabase + '&sModelLabel=' + @ModelName + '")
$webRequest.ContentLength = $bytes.Length
[System.IO.Stream]$reqStream = $webRequest.GetRequestStream()
$reqStream.Write($bytes, 0, $bytes.Length)
$reqStream.Flush()
$resp = $webRequest.GetResponse()
$rs = $resp.GetResponseStream()
[System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
$statusCode = [int]$resp.StatusCode
if ($statusCode -eq 200) {
    [xml]$res = $sr.ReadToEnd()
    if ($res.error -ne $null) { Write-Error($res.error.msg) }
    else { Write-Output($res.InnerXml) }
} 
else {
    Write-Error($statusCode.ToString() + "-" + $resp.StatusCode + "`n" + $sr.ReadToEnd())
}'
			if @CallistoDeployAndRefreshYN = 0
				BEGIN
				SET	@CommandStringRefresh = '<# ' + CHAR(10) + CHAR(13) + @CommandStringRefresh + CHAR(10) + CHAR(13) + ' #>'
				END
			END

	SET @Step = 'StepName = Create'
		IF @StepName = 'Create' AND @EnhancedStorageYN = 0
			BEGIN
				SET	@CommandString = '
[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create("http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx")
$webRequest.UseDefaultCredentials = $true
$webRequest.PreAuthenticate = $true
$webRequest.ContentType = "text/xml"
$webRequest.Timeout = 900000
$webRequest.Method = "POST"
$enc = [System.Text.Encoding]::GetEncoding("UTF-8")
$xml = ''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <CreateApplication xmlns="http://www.perlielab.com/">
      <sAppLabel>' + @CallistoDatabase + '</sAppLabel>
      <xmlAppdef></xmlAppdef>
      <xmlOptions><collation value="SQL_Latin1_General_CP1_CI_AS"/></xmlOptions>
    </CreateApplication>
  </soap:Body>
</soap:Envelope>''
[byte[]]$bytes = $enc.GetBytes($xml)
$webRequest.ContentLength = $bytes.Length
[System.IO.Stream]$reqStream = $webRequest.GetRequestStream()
$reqStream.Write($bytes, 0, $bytes.Length)
$reqStream.Flush()
$resp = $webRequest.GetResponse()
$rs = $resp.GetResponseStream()
[System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
Write-Output(([int]$resp.StatusCode).ToString() + "-" + $resp.StatusCode)
Write-Output($sr.ReadToEnd())'
			END

	SET @Step = 'StepName = Import'
		IF @StepName = 'Import' AND @EnhancedStorageYN = 0
			BEGIN
				SET	@CommandString = '
[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create("http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx/ImportFromSQL")
$webRequest.UseDefaultCredentials = $true
$webRequest.PreAuthenticate = $true
$webRequest.ContentType = "application/x-www-form-urlencoded"
$webRequest.Timeout = 900000
$webRequest.Method = "POST"
$enc = [System.Text.Encoding]::GetEncoding("UTF-8")
[byte[]]$bytes = $enc.GetBytes("sAppLabel=' + @CallistoDatabase + '&sSourceDb=' + @SourceDatabase + '")
$webRequest.ContentLength = $bytes.Length
[System.IO.Stream]$reqStream = $webRequest.GetRequestStream()
$reqStream.Write($bytes, 0, $bytes.Length)
$reqStream.Flush()
$resp = $webRequest.GetResponse()
$rs = $resp.GetResponseStream()
[System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
Write-Output(([int]$resp.StatusCode).ToString() + "-" + $resp.StatusCode)
Write-Output($sr.ReadToEnd())'
			END

	SET @Step = 'StepName = DeployRole'
		IF @StepName = 'DeployRole' AND @EnhancedStorageYN = 0
			BEGIN
				SET	@CommandString = '
[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create("http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx/DeploySecurityRole")
$webRequest.UseDefaultCredentials = $true
$webRequest.PreAuthenticate = $true
$webRequest.ContentType = "application/x-www-form-urlencoded"
$webRequest.Timeout = 1800000
$webRequest.Method = "POST"
$enc = [System.Text.Encoding]::GetEncoding("UTF-8")
[byte[]]$bytes = $enc.GetBytes("sAppLabel=' + @CallistoDatabase + '&bAllRoles=true&sRoleLabel=")
$webRequest.ContentLength = $bytes.Length
[System.IO.Stream]$reqStream = $webRequest.GetRequestStream()
$reqStream.Write($bytes, 0, $bytes.Length)
$reqStream.Flush()
$resp = $webRequest.GetResponse()
$rs = $resp.GetResponseStream()
[System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
Write-Output(([int]$resp.StatusCode).ToString() + "-" + $resp.StatusCode)
Write-Output($sr.ReadToEnd())'
			END

	SET @Step = 'Update @Step for Import, Load, Deploy, Refresh, RunModelRule, DeployRole, Create'
		IF @StepName IN ('Import', 'Load', 'Deploy', 'Refresh', 'RunModelRule', 'DeployRole', 'Create') AND @EnhancedStorageYN = 0
			BEGIN
				SELECT 
					@StepID = JS.step_id
				FROM
					msdb..sysjobsteps JS
					INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
				WHERE
					JS.[step_name] = @StepName + '_2'

				IF @Debug <> 0 SELECT [@StepID] = @StepID, [@StepName] = @StepName + '_2'

				IF @StepName IN ('Import', 'Load', 'RunModelRule', 'DeployRole', 'Create')
					EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString
				ELSE IF @StepName IN ('Deploy')
					EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandStringDeploy
				ELSE IF @StepName IN ('Refresh')
					EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandStringRefresh
			END

	SET @Step = 'Update @Step for ETLFull'
		IF @StepName IN ('ETLFull')
			BEGIN
				SET @CommandString = '
EXEC [spRun_Job]
	@UserID = ' + CONVERT(nvarchar(15), @UserID) + ',
	@InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ',
	@VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ',
	@JobListID = ' + CONVERT(nvarchar(15), @JobListID) + ',
	@EndOfSequenceYN = 0,
	@JobID = ' + CONVERT(nvarchar(15), @JobID)

				SELECT 
					@StepID = JS.step_id
				FROM
					msdb..sysjobsteps JS
					INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
				WHERE
					JS.[step_name] = @StepName + '_2'

				EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString

				SELECT 
					@StepID = JS.step_id
				FROM
					msdb..sysjobsteps JS
					INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
				WHERE
					JS.[step_name] = @StepName + '_3_Deploy'

				IF @EnhancedStorageYN = 0 EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandStringDeploy
			END

	SET @Step = 'Update @Step for ETLData'
		IF @StepName IN ('ETLData')
			BEGIN
				SET @CommandString = '
EXEC [spRun_Job]
	@UserID = ' + CONVERT(nvarchar(15), @UserID) + ',
	@InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ',
	@VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ',
	@JobListID = ' + CONVERT(nvarchar(15), @JobListID) + ',
	@EndOfSequenceYN = 0,
	@JobID = ' + CONVERT(nvarchar(15), @JobID)

				SELECT 
					@StepID = JS.step_id
				FROM
					msdb..sysjobsteps JS
					INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
				WHERE
					JS.[step_name] = @StepName + '_2'

				EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString

				SELECT 
					@StepID = JS.step_id
				FROM
					msdb..sysjobsteps JS
					INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
				WHERE
					JS.[step_name] = @StepName + '_3_Refresh'

				IF @EnhancedStorageYN = 0 EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandStringRefresh
			END

	SET @Step = 'Update @Step for GenericSP'
		IF @StepName IN ('GenericSP')
			BEGIN
				SELECT 
					@StepID = JS.step_id
				FROM
					msdb..sysjobsteps JS
					INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
				WHERE
					JS.[step_name] = @StepName

				EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @database_name = @Database, @command = @CommandStringGeneric
			END

	SET @Step = 'Enable Job'
		EXEC msdb.[dbo].sp_update_job @job_name = @JobName, @enabled = 1

	SET @Step = 'Get @SysJob_Instance_ID'
		SELECT
			@SysJob_InstanceID = MAX(H.instance_id)
		FROM
			msdb..sysjobhistory H 
			INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id
		SET @SysJob_InstanceID = ISNULL(@SysJob_InstanceID, 0)

	SET @Step = 'Start the Job'
		EXEC msdb.[dbo].sp_start_job @job_name = @JobName, @step_name = @StepName

	SET @Step = 'Wait loop if not asynchronous'
		IF @AsynchronousYN = 0
			BEGIN
				WHILE (SELECT COUNT(1) FROM msdb..sysjobhistory H INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id WHERE H.instance_id > @SysJob_InstanceID AND H.step_id = 0) = 0
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
		IF @AsynchronousYN = 0
			SELECT
				[JobName] = J.[name],
				[StepName] = @StepName,
				[JobStatus] = H.[run_status],
				[Description] =	CASE H.[run_status] WHEN 0 THEN 'Failed' WHEN 1 THEN 'Successful' WHEN 3 THEN 'Cancelled' WHEN 4 THEN 'In Progress' END,
				[Message] = H.[message],
				[Duration] = H.[run_duration]
			FROM
				msdb..sysjobhistory H 
				INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id
			WHERE
				H.instance_id > @SysJob_InstanceID AND
				H.step_id = 0

	SET @Step = 'Disable Job'
		EXEC msdb.[dbo].sp_update_job @job_name = @JobName, @enabled = 0

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

--GO
--EXEC spPortalAdmin_LoadCallisto @CallistoDeployYN='0',@FullReloadYN='0',@InstanceID='732',@UserID='-10',@VersionID='1165',@DebugBM=4
GO
