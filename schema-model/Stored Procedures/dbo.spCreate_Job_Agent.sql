SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Job_Agent]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ApplicationID int = NULL,
	@JobType nvarchar(10) = NULL, --Create or Load
	@SQLversion int = NULL, --9 = SQL 2005, 10 = SQL 2008, 11 = SQL 2012
	@SandBox nvarchar(100) = NULL,
	@DemoYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000039,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spCreate_Job_Agent',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spCreate_Job_Agent] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spCreate_Job_Agent] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ApplicationServer nvarchar(50),
	@DestinationDatabase nvarchar(255),
	@ETLDatabase nvarchar(255),
	@JobName nvarchar(255),
	@Command_String nvarchar(4000),
	@xmlAppdef nvarchar(1000),
	@Tomorrow int,
	@StepID int,
	@Collation nvarchar(50),
	@pcExchangeYN bit,
	@WebServicePath nvarchar(100),
	@Enabled bit = 0,

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
			@ProcedureDescription = 'Create standard SQL agent jobs, Setup and ETL',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2053' SET @Description = 'User handling added as step into Create job'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.2083' SET @Description = 'Removed spSet_User from CREATE-job.'
		IF @Version = '1.3.2084' SET @Description = 'Quit the job reporting success after first step in the CREATE-job.'
		IF @Version = '1.3.2098' SET @Description = 'Pick Collation from [spGet_Version].'
		IF @Version = '1.3.2113' SET @Description = 'Handle SandBox.'
		IF @Version = '1.3.0.2118' SET @Description = 'Avoid schedule by default for pcEXCHANGE.'
		IF @Version = '1.4.0.2126' SET @Description = 'Check for version 4 of Callisto.'
		IF @Version = '1.4.0.2128' SET @Description = 'Handle case sensitive.'
		IF @Version = '1.4.0.2139' SET @Description = 'Added parameter DemoYN. Added Callisto-parameter bDefrag=true for deploy.'
		IF @Version = '2.0.3.2152' SET @Description = 'Added step LogStartTime.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ApplicationID = ISNULL(@ApplicationID, ApplicationID)
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT
			@InstanceID = ISNULL(@InstanceID, A.InstanceID),
			@ApplicationServer = A.ApplicationServer,
			@DestinationDatabase = ISNULL(@SandBox, A.DestinationDatabase),
			@ETLDatabase = A.ETLDatabase
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID

		IF (SELECT COUNT(1) FROM CallistoAppDictionary.sys.tables WHERE name = 'DbVersion') > 0
			SET @WebServicePath = 'CLAdmin'				--Version 4 of Callisto
		ELSE
			SET @WebServicePath = 'Callisto_Server'		--Version 1 - 3 of Callisto

		SELECT
			@pcExchangeYN = CASE WHEN MAX(S.SourceTypeID) = MIN(S.SourceTypeID) AND MAX(S.SourceTypeID) = 6 THEN 1 ELSE 0 END
		FROM
			[Source] S
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = 600

		IF @SQLversion IS NULL
			SELECT @SQLversion = CONVERT(int, SUBSTRING(CONVERT(nvarchar, SERVERPROPERTY ('ProductVersion')), 1, CHARINDEX ( '.', CONVERT(nvarchar, SERVERPROPERTY ('ProductVersion'))) - 1))

		SET @JobName = @DestinationDatabase + '_' + @JobType

	SET @Step = 'Check if job already exists'
		IF (SELECT COUNT(1) FROM msdb..sysjobs WHERE name = @JobName) > 0
			BEGIN
				SET @Message = 'SQL Agent Job ' + @JobName + ' already exists.'
				SET @Severity = 0
				GOTO EXITPOINT
			END

	SET @Step = 'Create jobs'
		IF @JobType = 'Create'
			BEGIN
				--Create job
				EXEC msdb.[dbo].sp_add_job
					@job_name = @JobName,
					@owner_login_name = N'sa',
					@enabled = @Enabled

				--Step 1 LogStartTime
				EXEC msdb.dbo.sp_add_jobstep
					@job_name = @JobName,
					@step_id = 1,
					@step_name = 'LogStartTime', 
					@subsystem = 'TSQL',
					@command = N'WAITFOR DELAY ''00:00:00''',
					@database_name = N'master',
					@on_success_action = 3

				--Step 2 Create Application
				SET @xmlAppdef = '<xmlOptions><collation value=”' + @Collation + '”/></xmlOptions>'

				IF @SQLversion <= 9  --SQL 2005

					BEGIN

						SET	@Command_String = 'strURL = "http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx/CreateApplication"

Set oXMLHTTP = CreateObject("MSXML2.XMLHTTP")
oXMLHTTP.open "POST", strURL, False 
oXMLHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
oXMLHTTP.send "sAppLabel=' + @DestinationDatabase + '&xmlAppdef=' + @xmlAppdef + '"

Set oXMLHTTP = Nothing'

						EXEC msdb.[dbo].sp_add_jobstep
							@job_name = @JobName,
							@step_id = 2,
							@step_name = 'Create',
							@subsystem = 'ACTIVESCRIPTING',
							@command = @Command_String,
							@database_name = 'VBScript', 
							@on_success_action = 1

					END

				ELSE --SQL 2008 or SQL 2012
					BEGIN
						SET	@Command_String = '[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create("http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx")
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
      <sAppLabel>' + @DestinationDatabase + '</sAppLabel>
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

						EXEC msdb.[dbo].sp_add_jobstep
							@job_name = @JobName,
							@step_id = 2,
							@step_name = 'Create',
							@subsystem = 'PowerShell',
							@command = @Command_String,
							@database_name = 'VBScript', 
							@on_success_action = 1

					END

				--Step 3 Import
				IF @SQLversion <= 9  --SQL 2005

					BEGIN

						SET	@Command_String = 'strURL = "http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx/ImportFromSQL"

Set oXMLHTTP = CreateObject("MSXML2.XMLHTTP")
oXMLHTTP.open "POST", strURL, False 
oXMLHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
oXMLHTTP.send "sAppLabel=' + @DestinationDatabase + '&sSourceDb=' + @ETLDatabase + '"

Set oXMLHTTP = Nothing'

						EXEC msdb.[dbo].sp_add_jobstep
							@job_name = @JobName,
							@step_id = 3,
							@step_name = 'Import',
							@subsystem = 'ACTIVESCRIPTING',
							@command = @Command_String,
							@database_name = 'VBScript', 
							@on_success_action = 1

					END

				ELSE --SQL 2008 or SQL 2012
					BEGIN
						SET	@Command_String = '
[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create("http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx/ImportFromSQL")
$webRequest.UseDefaultCredentials = $true
$webRequest.PreAuthenticate = $true
$webRequest.ContentType = "application/x-www-form-urlencoded"
$webRequest.Timeout = 900000
$webRequest.Method = "POST"
$enc = [System.Text.Encoding]::GetEncoding("UTF-8")
[byte[]]$bytes = $enc.GetBytes("sAppLabel=' + @DestinationDatabase + '&sSourceDb=' + @ETLDatabase + '")
$webRequest.ContentLength = $bytes.Length
[System.IO.Stream]$reqStream = $webRequest.GetRequestStream()
$reqStream.Write($bytes, 0, $bytes.Length)
$reqStream.Flush()
$resp = $webRequest.GetResponse()
$rs = $resp.GetResponseStream()
[System.IO.StreamReader]$sr = New-Object System.IO.StreamReader -argumentList $rs
Write-Output(([int]$resp.StatusCode).ToString() + "-" + $resp.StatusCode)
Write-Output($sr.ReadToEnd())'

						EXEC msdb.[dbo].sp_add_jobstep
							@job_name = @JobName,
							@step_id = 3,
							@step_name = 'Import',
							@subsystem = 'PowerShell',
							@command = @Command_String,
							@database_name = 'VBScript', 
							@on_success_action = 1

					END
			END

		ELSE IF @JobType = 'Load'
			BEGIN
				--Create job
				SET @Enabled = CASE WHEN @DemoYN <> 0 THEN 0 ELSE 1 END

				EXEC msdb.[dbo].sp_add_job
					@job_name = @JobName,
					@owner_login_name = N'sa',
					@enabled = @Enabled

				--Step 1 LogStartTime
				EXEC msdb.dbo.sp_add_jobstep
					@job_name = @JobName,
					@step_id = 1,
					@step_name = 'LogStartTime', 
					@subsystem = 'TSQL',
					@command = N'WAITFOR DELAY ''00:00:00''',
					@database_name = N'master',
					@on_success_action = 3

				--Step 2 Load
				IF @SandBox IS NULL
					EXEC msdb.[dbo].sp_add_jobstep
						@job_name = @JobName,
						@step_id = 1,
						@step_name = 'Load',
						@subsystem = 'TSQL',
						@command = 'EXEC spIU_Load_All',
						@database_name = @ETLDatabase,
						@on_success_action = 3

				--Step 3 Deploy
				SET @StepID = CASE WHEN @SandBox IS NOT NULL THEN 2 ELSE 3 END
				IF @SQLversion <= 9  --SQL 2005

					BEGIN
						SET	@Command_String = 'strURL = "http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx/DeployApplication2"

Set oXMLHTTP = CreateObject("MSXML2.XMLHTTP")
oXMLHTTP.open "POST", strURL, False 
oXMLHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
oXMLHTTP.send "sAppLabel=' + @DestinationDatabase + '"

Set oXMLHTTP = Nothing'

						EXEC msdb.[dbo].sp_add_jobstep
							@job_name = @JobName,
							@step_id = @StepID,
							@step_name = 'Deploy',
							@subsystem = 'ACTIVESCRIPTING',
							@command = @Command_String,
							@database_name = 'VBScript', 
							@on_success_action = 1
	
					END

				ELSE --SQL 2008 or SQL 2012
					BEGIN
						SET	@Command_String = '$ErrorActionPreference = "Stop"
[System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create("http://' + @ApplicationServer + '/' + @WebServicePath + '/callistoadmin.asmx/DeployApplication2")
$webRequest.UseDefaultCredentials = $true
$webRequest.PreAuthenticate = $true
$webRequest.ContentType = "application/x-www-form-urlencoded"
$webRequest.Timeout = 900000
$webRequest.Method = "POST"
$enc = [System.Text.Encoding]::GetEncoding("UTF-8")
[byte[]]$bytes = $enc.GetBytes("sAppLabel=' + @DestinationDatabase + '&bDefrag=true")
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

						EXEC msdb.[dbo].sp_add_jobstep
							@job_name = @JobName,
							@step_id = @StepID,
							@step_name = 'Deploy',
							@subsystem = 'PowerShell',
							@command = @Command_String,
							@database_name = 'VBScript', 
							@on_success_action = 1
					END

				IF @SandBox IS NULL AND @pcExchangeYN = 0
					BEGIN
						SET @Tomorrow = Year(GetDate() + 1) * 10000 + Month(GetDate() + 1) * 100 + Day(GetDate() + 1)

						EXEC msdb.dbo.sp_add_jobschedule 
							@job_name = @JobName,
							@name = N'Nightly', 
							@enabled = @Enabled, 
							@freq_type = 4, 
							@freq_interval = 1, 
							@freq_subday_type = 1, 
							@freq_subday_interval = 0, 
							@freq_relative_interval = 0, 
							@freq_recurrence_factor = 0, 
							@active_start_date = @Tomorrow, 
							@active_end_date = 99991231, 
							@active_start_time = 20000, 
							@active_end_time = 235959
					END
			END

	SET @Step = 'Add jobserver'
		EXEC msdb.[dbo].sp_add_jobserver @job_name = @JobName

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
