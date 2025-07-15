SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spJIRA_IU_API_Calls_Epicor_20240324]
	 @Operation			VARCHAR(255)	= 'Insert' -- Insert/Update/GetStatus/UpdateFromJira/GetVersionsList/AddVersion/GetDBEnvironments/GetUserList
	,@BodyData			VARCHAR(MAX)	= ''
	,@Exist_JiraIssueID INT = NULL
	,@Exist_JiraIssueStatusID INT = NULL
	,@JiraProject		VARCHAR(20) = 'FEA'
	,@issueID			INT = NULL OUT
	,@issueStatusID		INT = NULL OUT
    ,@DebugBM			INT = 7 --1=High Prio, 2=Low Prio, 4=Sub routines
	,@VersionsList		NVARCHAR(MAX) = NULL OUT
	,@DBEnvironments	NVARCHAR(MAX) = NULL OUT

AS
/*
declare  @issueID		INT
		,@issueStatusID	INT

exec spJIRA_IU_API_Calls_Epicor @Operation = 'GetStatus', @BodyData = '', @Exist_JiraIssueID = 58726, @Exist_JiraIssueStatusID = 10014, @issueID = @issueID OUT, @issueStatusID = @issueStatusID out

select	 [@issueID]			= @issueID
		,[@issueStatusID]	= @issueStatusID
*/

/*
SELECT	 [Scope] = 'Jira_IU_start'
		,[@Operation]			= @Operation
		,[@BodyData]			= @BodyData
		,[@Exist_JiraIssueID]	= @Exist_JiraIssueID
		,[@Exist_JiraIssueStatusID] = @Exist_JiraIssueStatusID
		,[@IssueID]				= @IssueID
		,[@issueStatusID]		= @issueStatusID
*/

DECLARE @Url VARCHAR(MAX) = CASE
								WHEN @Operation = 'Insert'			THEN 'https://epicor.atlassian.net/rest/api/3/issue'
								WHEN @Operation = 'Update'			THEN 'https://epicor.atlassian.net/rest/api/3/issue/' + CAST(@Exist_JiraIssueID AS VARCHAR(255))
								WHEN @Operation = 'UpdateFromJira'	THEN 'https://epicor.atlassian.net/rest/api/3/search'
								WHEN @Operation = 'GetVersionsList'	THEN 'https://epicor.atlassian.net/rest/api/3/project/' + @JiraProject + '/versions'
								WHEN @Operation = 'GetDBEnvironments' THEN 'https://epicor.atlassian.net/rest/api/3/field/customfield_20277/context/14272/option'
								WHEN @Operation = 'GetUserList'		THEN 'https://epicor.atlassian.net/rest/api/3/users?maxResults=1000'
								WHEN @Operation = 'AddVersion'		THEN 'https://epicor.atlassian.net/rest/api/3/version'
								ELSE									 'https://epicor.atlassian.net/rest/api/3/issue/' + CAST(@Exist_JiraIssueID AS VARCHAR(255)) + '?fields=status'
								END,
		@Method VARCHAR(5) = CASE
								WHEN @Operation IN ('Insert', 'UpdateFromJira', 'AddVersion')				THEN 'POST'
								WHEN @Operation = 'Update'													THEN 'PUT'
								WHEN @Operation IN ('GetVersionsList', 'GetDBEnvironments', 'GetUserList')	THEN 'GET'
								ELSE							'GET'
								END,
		@Authorization VARCHAR(MAX) = 'Basic c2VyZ2lpLmdhdnJ5bGVua29AZXBpY29yLmNvbTpBVEFUVDN4RmZHRjBHQ05YWk1Xa1lNRHBpRUdudTlIY2ZhdElOXzZLdXMzcEJDV0hBeGZuSXNPbTEwRDFURXViWWtObkl1TWlrZnE5di1oTWFzbGtGUmtkUlVyMFdlMmlidzF3YUtrNU5TdDJsXzlzRGNrM3F5cTgxdmtLN0lTSlFsME92ZFdqbWtDTF9wQlotYnJ3d0M2QURyQ0JHdDRLaXU4bWhWVmhtQ1VzYURpSXFtN3FTSjg9NEM4Qjc4MjQ=',--Basic auth token, Api key,...
		@ContentType VARCHAR(255) = 'application/json' --'application/json; charset=utf-8' --'application/xml'

 DECLARE @vWin INT --token of WinHttp object
 DECLARE @vReturnCode INT
 DECLARE @tResponse TABLE (ResponseText NVARCHAR(MAX))
 --Creates an instance of WinHttp.WinHttpRequest
 --Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/winhttp-versions
 --Version of 5.0 is no longer supported
 EXEC @vReturnCode = sp_OACreate 'WinHttp.WinHttpRequest.5.1',@vWin OUT
 IF @vReturnCode <> 0 GOTO EXCEPTION
 --Opens an HTTP connection to an HTTP resource.
 --Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-open
 EXEC @vReturnCode = sp_OAMethod @vWin, 'Open', NULL, @Method/*Method*/, @Url /*Url*/, 'false' /*IsAsync*/
 IF @vReturnCode <> 0 GOTO EXCEPTION
 IF @Authorization IS NOT NULL
 BEGIN
     EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Authorization', @Authorization
     IF @vReturnCode <> 0 GOTO EXCEPTION
 END
 IF @ContentType IS NOT NULL
 BEGIN
     EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Content-type', @ContentType
     IF @vReturnCode <> 0 GOTO EXCEPTION
 END
 --Sends an HTTP request to an HTTP server.
 --Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-send
 IF @BodyData IS NOT NULL
 BEGIN
     EXEC @vReturnCode = sp_OAMethod @vWin,'Send', NULL, @BodyData
     IF @vReturnCode <> 0 GOTO EXCEPTION
 END
 ELSE
 BEGIN
     EXEC @vReturnCode = sp_OAMethod @vWin,'Send'
     IF @vReturnCode <> 0 GOTO EXCEPTION
 END
 IF @vReturnCode <> 0 GOTO EXCEPTION
 --Get Response text
 --Doc: https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-oagetproperty-transact-sql
 INSERT INTO @tResponse (ResponseText)
 EXEC @vReturnCode = sp_OAGetProperty @vWin,'ResponseText'
 IF @vReturnCode <> 0 GOTO EXCEPTION
 IF @vReturnCode = 0
     GOTO RESULT
 EXCEPTION:
     BEGIN
         DECLARE @tException TABLE
         (
             Error BINARY(4),
             Source VARCHAR(MAX),
             Description VARCHAR(MAX),
             HelpFile VARCHAR(MAX),
             HelpID VARCHAR(MAX)
         )
         INSERT INTO @tException EXEC sp_OAGetErrorInfo @vWin
         INSERT
         INTO    @tResponse
         (
                 ResponseText
         )
         SELECT    (
                     SELECT    *
                     FROM    @tException
                     FOR        JSON AUTO
                 ) AS ResponseText
     END

 --FINALLY
 RESULT:
 --Dispose objects
 /*
 IF @vWin IS NOT NULL
     EXEC sp_OADestroy @vWin
*/

IF @DebugBM  > 0
					 SELECT    *
							 --,@Operation
							 --,@BodyData
							 --,@Exist_JiraIssueID
					 FROM    @tResponse




 DECLARE
		-- @issueID	INT
		 @issueKey	NVARCHAR(50)
		,@issueURL	NVARCHAR(MAX)

SELECT
		 @issueID			= JSON_VALUE(ResponseText, '$.id')
		,@issueKey			= JSON_VALUE(ResponseText, '$.key')
		,@issueURL			= JSON_VALUE(ResponseText, '$.self')
		,@issueStatusID		= JSON_VALUE(ResponseText, '$.fields.status.id')
FROM @tResponse
/*
'
{
    "expand": "renderedFields,names,schema,operations,editmeta,changelog,versionedRepresentations",
    "id": "58726",
    "self": "https://epicor.atlassian.net/rest/api/3/issue/58726",
    "key": "SEG-182",
    "fields": {
        "status": {
            "self": "https://epicor.atlassian.net/rest/api/3/status/10434",
            "description": "This issue is being actively worked on at the moment by the assignee.",
            "iconUrl": "https://epicor.atlassian.net/",
            "name": "In Progress",
            "id": "10434",
            "statusCategory": {
                "self": "https://epicor.atlassian.net/rest/api/3/statuscategory/4",
                "id": 4,
                "key": "indeterminate",
                "colorName": "yellow",
                "name": "In Progress"
            }
        }
    }
}'*/


------- additional: on Update and if current stauts in (Done, Deployed, Closed) then change status to "Reopened" -------------------------------------------------------------

IF (@Operation = 'Update' AND @Exist_JiraIssueStatusID IN (10001, 17253, 6)) -- (Done, Deployed, Closed). In the past: when DSPanel Jira:  ( Deployed, Closed: 10001, 6)
BEGIN
	DECLARE @UrlTransition VARCHAR(MAX) =  'https://epicor.atlassian.net/rest/api/3/issue/' + CAST(@Exist_JiraIssueID AS VARCHAR(255)) + '/transitions'
	EXEC @vReturnCode = sp_OAMethod @vWin, 'Open', NULL, 'Post', @UrlTransition, 'false' /*IsAsync*/
	 IF @vReturnCode <> 0 GOTO EXCEPTION2
	 IF @Authorization IS NOT NULL
	 BEGIN
		 EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Authorization', @Authorization
		 IF @vReturnCode <> 0 GOTO EXCEPTION2
	 END
	 IF @ContentType IS NOT NULL
	 BEGIN
		 EXEC @vReturnCode = sp_OAMethod @vWin, 'SetRequestHeader', NULL, 'Content-type', @ContentType
		 IF @vReturnCode <> 0 GOTO EXCEPTION2
	 END
	 --Sends an HTTP request to an HTTP server.
	 --Doc: https://docs.microsoft.com/en-us/windows/desktop/winhttp/iwinhttprequest-send
	 IF @BodyData IS NOT NULL
	 BEGIN
		 EXEC @vReturnCode = sp_OAMethod @vWin,'Send', NULL, '{
																	"transition": {
																		"id": "101"
																	}
																}'
		 IF @vReturnCode <> 0 GOTO EXCEPTION2
	 END
	 ELSE
	 BEGIN
		 EXEC @vReturnCode = sp_OAMethod @vWin,'Send'
		 IF @vReturnCode <> 0 GOTO EXCEPTION2
	 END
	 IF @vReturnCode <> 0 GOTO EXCEPTION2
	 --Get Response text
	 --Doc: https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-oagetproperty-transact-sql
	 INSERT INTO @tResponse (ResponseText)
	 EXEC @vReturnCode = sp_OAGetProperty @vWin,'ResponseText'
	 IF @vReturnCode <> 0 GOTO EXCEPTION2
	 IF @vReturnCode = 0
		 GOTO RESULT2
	 EXCEPTION2:
		 BEGIN
			 DELETE FROM @tException
			 INSERT INTO @tException EXEC sp_OAGetErrorInfo @vWin

			 DELETE FROM @tResponse
			 INSERT
			 INTO    @tResponse
			 (
					 ResponseText
			 )
			 SELECT    (
						 SELECT    *
						 FROM    @tException
						 FOR        JSON AUTO
					 ) AS ResponseText
		 END

	 --FINALLY
	 RESULT2:
	 --Dispose objects
	 /*
	 IF @vWin IS NOT NULL
		 EXEC sp_OADestroy @vWin
		 */

	 --SELECT [debug] = 'transition'

	 SELECT    *
	 FROM    @tResponse

END

IF @Operation ='GetDBEnvironments'
	BEGIN
		DECLARE @SerchResult3 NVARCHAR(MAX);
		SELECT TOP 1  @SerchResult3 = ResponseText
		FROM    @tResponse

		set @DBEnvironments = ''

		SELECT @DBEnvironments = @DBEnvironments + DBEnvName + '|'
		FROM OPENJSON(@SerchResult3,'$.values')
		WITH (	DBEnvName	VARCHAR(100) '$.value'
				)

		/*
		'{
			"maxResults": 100,
			"startAt": 0,
			"total": 11,
			"isLast": true,
			"values": [
				{
					"id": "10306",
					"value": "Develop (dspdevdb01)",
					"disabled": false
				},
				{
					"id": "10307",
					"value": "Beta (dsptest01)",
					"disabled": true
				},
				{
					"id": "10313",
					"value": "Beta (dspbeta01)",
					"disabled": false
				},
				{
					"id": "10308",
					"value": "Test (dsptest03)",
					"disabled": false
				},
				{
					"id": "10309",
					"value": "Demo (efpdemo01)",
					"disabled": false
				},
				{
					"id": "10314",
					"value": "Demo (efpdemo02)",
					"disabled": false
				},
				{
					"id": "10312",
					"value": "Stage (dspstage01)",
					"disabled": false
				},
				{
					"id": "10310",
					"value": "Prod  (dspprod01)",
					"disabled": false
				},
				{
					"id": "10311",
					"value": "Prod (dspprod02)",
					"disabled": false
				},
				{
					"id": "10316",
					"value": "Prod (dspprod03)",
					"disabled": false
				},
				{
					"id": "10315",
					"value": "Prod (dspprodau01)",
					"disabled": false
				}
			]
		}'
		*/
    END

IF @Operation ='GetVersionsList'
	BEGIN
		DECLARE @SerchResult2 NVARCHAR(MAX);
		SELECT TOP 1  @SerchResult2 = ResponseText
		FROM    @tResponse

		set @VersionsList = ''

		SELECT @VersionsList = @VersionsList + VersionName + '|'
		FROM OPENJSON(@SerchResult2,'$')
		WITH (	VersionName	VARCHAR(100) '$.name'
				)


		/*
		'[
				{
					"self": "https://epicor.atlassian.net/rest/api/3/version/17062",
					"id": "17062",
					"name": "2.1.1.2176",
					"archived": false,
					"released": true,
					"startDate": "2021-12-06",
					"releaseDate": "2021-12-13",
					"userStartDate": "06/Dec/21",
					"userReleaseDate": "13/Dec/21",
					"projectId": 14309
				},
				{
					"self": "https://epicor.atlassian.net/rest/api/3/version/17026",
					"id": "17026",
					"name": "2.0.2.2144",
					"archived": false,
					"released": true,
					"releaseDate": "2019-07-04",
					"userReleaseDate": "04/Jul/19",
					"projectId": 14309
				},
				{
					"self": "https://epicor.atlassian.net/rest/api/3/version/17027",
					"id": "17027",
					"description": "Released together with Versions 2.0.2.2145 - 2.0.2.2150",
					"name": "2.0.2.2145",
					"archived": false,
					"released": true,
					"releaseDate": "2019-12-11",
					"userReleaseDate": "11/Dec/19",
					"projectId": 14309
				}
		]'
		*/
    END

	IF @Operation ='GetUserList'
	BEGIN
		DECLARE @SerchResult4 NVARCHAR(MAX);
		SELECT TOP 1  @SerchResult4 = ResponseText
		FROM    @tResponse

		set @VersionsList = ''


		INSERT INTO #JiraUserList (
									  [AccountID]
									 ,[UserEmail]
									)
		SELECT   accountId
				,emailAddress
		FROM OPENJSON(@SerchResult4,'$')
		WITH (	 accountId	  VARCHAR(255) '$.accountId'
				,emailAddress VARCHAR(255) '$.emailAddress'
				)
		WHERE   COALESCE(emailAddress, '') <> ''
			AND COALESCE(accountId, '') <> ''

		/*
		'[
			{
				"self": "https://epicor.atlassian.net/rest/api/3/user?accountId=557058:5ea453f3-5741-4d89-a716-60c8aa2d2991",
				"accountId": "557058:5ea453f3-5741-4d89-a716-60c8aa2d2991",
				"accountType": "atlassian",
				"emailAddress": "andrey.polyakov@epicor.com",
				"avatarUrls": {
					"48x48": "https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net/557058:5ea453f3-5741-4d89-a716-60c8aa2d2991/7ad6d97b-c81e-4c22-af4c-4a0b47ee1bea/48",
					"24x24": "https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net/557058:5ea453f3-5741-4d89-a716-60c8aa2d2991/7ad6d97b-c81e-4c22-af4c-4a0b47ee1bea/24",
					"16x16": "https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net/557058:5ea453f3-5741-4d89-a716-60c8aa2d2991/7ad6d97b-c81e-4c22-af4c-4a0b47ee1bea/16",
					"32x32": "https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net/557058:5ea453f3-5741-4d89-a716-60c8aa2d2991/7ad6d97b-c81e-4c22-af4c-4a0b47ee1bea/32"
				},
				"displayName": "Andrey Polyakov",
				"active": true,
				"timeZone": "Europe/Berlin",
				"locale": "en_US"
			},
			{
				"self": "https://epicor.atlassian.net/rest/api/3/user?accountId=5be37f8aa430e70fb00dfdaa",
				"accountId": "5be37f8aa430e70fb00dfdaa",
				"accountType": "atlassian",
				"avatarUrls": {
					"48x48": "https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net/default-avatar.png",
					"24x24": "https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net/default-avatar.png",
					"16x16": "https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net/default-avatar.png",
					"32x32": "https://avatar-management--avatars.us-west-2.prod.public.atl-paas.net/default-avatar.png"
				},
				"displayName": "Former user",
				"active": false
			},
			{
				"self": "https://epicor.atlassian.net/rest/api/3/user?accountId=557058:2ceed135-912e-4ead-a65a-9cb8a177c304",
				"accountId": "557058:2ceed135-912e-4ead-a65a-9cb8a177c304",
				"accountType": "atlassian",
				"emailAddress": "eve.liu@epicor.com",
				"avatarUrls": {
					"48x48": "https://secure.gravatar.com/avatar/939623c8913909a52219c448414510a1?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FEL-2.png",
					"24x24": "https://secure.gravatar.com/avatar/939623c8913909a52219c448414510a1?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FEL-2.png",
					"16x16": "https://secure.gravatar.com/avatar/939623c8913909a52219c448414510a1?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FEL-2.png",
					"32x32": "https://secure.gravatar.com/avatar/939623c8913909a52219c448414510a1?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FEL-2.png"
				},
				"displayName": "Eve Liu",
				"active": false,
				"locale": "en_US"
			}
		]'
		*/
    END

IF @Operation in ('Insert', 'Update')
	BEGIN
		DECLARE @issueIDforGetStatus INT = COALESCE(@issueID, @Exist_JiraIssueID);
		EXEC spJIRA_IU_API_Calls_Epicor @Operation = 'GetStatus', @BodyData = '', @Exist_JiraIssueID = @issueIDforGetStatus, @issueID = @issueID OUT, @issueStatusID = @issueStatusID OUT
    END

IF @Operation ='UpdateFromJira'
	BEGIN
		DECLARE @SerchResult NVARCHAR(MAX);
		SELECT TOP 1  @SerchResult = ResponseText
		FROM    @tResponse

		UPDATE EA
		   SET   [JiraIssueStatusID]	= JIRA.statusID
				,ClearedYN				= CASE WHEN jira.statusName IN ('Done', 'Deployed', 'Closed') THEN 1
												ELSE 0
												END
        FROM pcINTEGRATOR_Log.[dbo].[ErrorAttention] EA
		JOIN 	(SELECT  issueKey
					   ,issueId
					   ,statusID
					   ,statusName
				FROM OPENJSON(@SerchResult,'$.issues')
				WITH (	issueKey	VARCHAR(100) '$.key',
						issueId		VARCHAR(100) '$.id',
						statusID	NVARCHAR(200) '$.fields.status.id',
						statusName	NVARCHAR(200) '$.fields.status.name'
						)
				) AS JIRA ON	JIRA.issueId  = EA.[JiraIssueID]
							AND JIRA.statusID <> EA.[JiraIssueStatusID]
		WHERE EA.[JiraIssueID] IS NOT NULL


		/*
		'{
				"expand": "schema,names",
				"startAt": 0,
				"maxResults": 100,
				"total": 4,
				"issues": [
					{
						"expand": "operations,versionedRepresentations,editmeta,changelog,renderedFields",
						"id": "58728",
						"self": "https://epicor.atlassian.net/rest/api/3/issue/58728",
						"key": "SEG-183",
						"fields": {
							"summary": "Error Attention",
							"status": {
								"self": "https://epicor.atlassian.net/rest/api/3/status/10433",
								"description": "",
								"iconUrl": "https://epicor.atlassian.net/",
								"name": "To Do",
								"id": "10433",
								"statusCategory": {
									"self": "https://epicor.atlassian.net/rest/api/3/statuscategory/2",
									"id": 2,
									"key": "new",
									"colorName": "blue-gray",
									"name": "To Do"
								}
							}
						}
					},
					{
						"expand": "operations,versionedRepresentations,editmeta,changelog,renderedFields",
						"id": "58726",
						"self": "https://epicor.atlassian.net/rest/api/3/issue/58726",
						"key": "SEG-182",
						"fields": {
							"summary": "CCM spBR_BR01 Transaction (Process ID 73) wa...",
							"status": {
								"self": "https://epicor.atlassian.net/rest/api/3/status/10434",
								"description": "This issue is being actively worked on at the moment by the assignee.",
								"iconUrl": "https://epicor.atlassian.net/",
								"name": "In Progress",
								"id": "10434",
								"statusCategory": {
									"self": "https://epicor.atlassian.net/rest/api/3/statuscategory/4",
									"id": 4,
									"key": "indeterminate",
									"colorName": "yellow",
									"name": "In Progress"
								}
							}
						}
					},
					{
						"expand": "operations,versionedRepresentations,editmeta,changelog,renderedFields",
						"id": "58725",
						"self": "https://epicor.atlassian.net/rest/api/3/issue/58725",
						"key": "SEG-181",
						"fields": {
							"summary": "CCM spBR_BR01 Incorrect syntax near the keyw...",
							"status": {
								"self": "https://epicor.atlassian.net/rest/api/3/status/10433",
								"description": "",
								"iconUrl": "https://epicor.atlassian.net/",
								"name": "To Do",
								"id": "10433",
								"statusCategory": {
									"self": "https://epicor.atlassian.net/rest/api/3/statuscategory/2",
									"id": 2,
									"key": "new",
									"colorName": "blue-gray",
									"name": "To Do"
								}
							}
						}
					},
					{
						"expand": "operations,versionedRepresentations,editmeta,changelog,renderedFields",
						"id": "58718",
						"self": "https://epicor.atlassian.net/rest/api/3/issue/58718",
						"key": "SEG-174",
						"fields": {
							"summary": "PCX Callisto_Generic03.Refresh_2 Executed as user: DEV\\sql_serv...",
							"status": {
								"self": "https://epicor.atlassian.net/rest/api/3/status/10433",
								"description": "",
								"iconUrl": "https://epicor.atlassian.net/",
								"name": "To Do",
								"id": "10433",
								"statusCategory": {
									"self": "https://epicor.atlassian.net/rest/api/3/statuscategory/2",
									"id": 2,
									"key": "new",
									"colorName": "blue-gray",
									"name": "To Do"
								}
							}
						}
					}
				]
			}
			'*/
    END
/*
SELECT
		 @issueID
		,@issueKey
		,@issueURL
		,@issueStatusID
*/

IF @vWin IS NOT NULL
	EXEC sp_OADestroy @vWin
GO
