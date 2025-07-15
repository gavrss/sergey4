SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spJIRA_ErrorAttention_IU_Issues_Epicor]

AS
/*
SET TEXTSIZE -1;
exec [spJIRA_ErrorAttention_IU_Issues_Epicor]

*/
DECLARE @JiraProject VARCHAR(255);
SET @JiraProject = 'FEA';

DECLARE @SQLInstanceName VARCHAR(255);
SET @SQLInstanceName = CAST(SERVERPROPERTY('servername') AS VARCHAR(255)) + CASE WHEN @@SERVICENAME = 'MSSQLSERVER' THEN '' ELSE '\\' + @@SERVICENAME END;

/*
CREATE TABLE #JiraUserList(
	  [AccountID] [VARCHAR](255)
	 ,[UserEmail] [NVARCHAR](255)
)
EXEC spJIRA_IU_API_Calls_Epicor @Operation			= 'GetUserList'
						,@BodyData			= ''
						,@JiraProject		= @JiraProject
*/
/*
 select * from #JiraUserList;
 drop table #JiraUserList
*/
------------------------------


CREATE TABLE #DBEnvironment(
	[EnvName] [nvarchar](100)
)

DECLARE @EnvName		nVARCHAR(MAX)
/*
EXEC spJIRA_IU_API_Calls_Epicor @Operation			= 'GetDBEnvironments'
						,@BodyData			= ''
						,@DBEnvironments	= @EnvName OUT
*/
INSERT INTO #DBEnvironment (EnvName)
SELECT	 splt.value
FROM STRING_SPLIT(@EnvName, '|')  splt
WHERE splt.value <> ''

DECLARE @DBEnvironment NVARCHAR(255) = '';
SELECT TOP 1
		@DBEnvironment = EnvName
FROM #DBEnvironment
WHERE EnvName like '%' + @SQLInstanceName + '%';

SET @DBEnvironment = COALESCE(@DBEnvironment, @SQLInstanceName);

-------------------------------------------------------------------
CREATE TABLE #JiraVersion(
	[Version] [nvarchar](100)
)

CREATE TABLE #ErrAtt(
	[MaxInsertedDate] [datetime] NULL,
	[MinInsertedDate] [datetime] NULL,
	[EACount] [int] NULL,
	[InstanceID] [int] NULL,
	[VersionID] [int] NULL,
	[ProcedureName] [nvarchar](100) NULL,
	[ErrorMessage] [nvarchar](4000) NULL,
	[InstanceName] [nvarchar](50) NULL,
	[ApplicationName] [nvarchar](100) NULL,
	[AffectVersion] [nvarchar](100) NULL
)

DECLARE @FixVersion nvarchar(100)
-- ToDo: uncomment after dspDEVDB01 restoring
-- EXEC dspdevdb01.pcintegrator.dbo.[spGet_Version] @Version = @FixVersion OUTPUT
EXEC [spGet_Version] @Version = @FixVersion OUTPUT

INSERT INTO #ErrAtt
(
	MaxInsertedDate,
	MinInsertedDate,
	EACount,
	InstanceID,
	VersionID,
	ProcedureName,
	ErrorMessage,
	InstanceName,
	ApplicationName,
	AffectVersion
)
SELECT
		 MAX(EA.[Inserted]) AS [MaxInsertedDate]
		,MIN(EA.[Inserted]) AS [MinInsertedDate]
		,COUNT(1) AS EACount
		,JL.InstanceID
		,JL.VersionID
		,JL.ProcedureName
		,JL.ErrorMessage
		,INS.InstanceName
		,APP.ApplicationName
		,MAX(JL.[Version])  AS [AffectVersion]
FROM
	[pcINTEGRATOR_Log].[dbo].[JobLog] JL (nolock)
	LEFT JOIN [pcINTEGRATOR_Log].[dbo].[ErrorAttention] EA ON EA.[JobLogID] = JL.[JobLogID]
	LEFT JOIN [pcINTEGRATOR_Data].dbo.Instance INS ON INS.InstanceID = JL.InstanceID
	LEFT JOIN [pcINTEGRATOR_Data].dbo.Application APP ON APP.InstanceID = JL.InstanceID
													AND App.VersionID = JL.VersionID
WHERE
	    (EA.JiraIssueID IS NULL
	AND JL.[ErrorNumber] NOT IN (0, -1))
    AND ErrorMessage NOT LIKE N'%ErrorNumber = 51000%'
    AND ErrorMessage NOT LIKE N'%Executed as user%Correct the script and reschedule the job. The error information returned by PowerShell is: %Deploy successfully finished with the following warnings:%live%Invalid user name%'
GROUP BY JL.InstanceID
		,JL.VersionID
		,INS.InstanceName
		,APP.ApplicationName
		,JL.ProcedureName
		,JL.ErrorMessage
HAVING DATEDIFF(HOUR, MAX(EA.[Inserted]), GETDATE()) <= 72
ORDER BY [MaxInsertedDate] DESC

INSERT INTO #JiraVersion
(
Version
)
SELECT DISTINCT AffectVersion AS [Version]
FROM #ErrAtt
UNION
SELECT @FixVersion AS [Version]


DECLARE @VersionsList		nVARCHAR(MAX)
		,@i1 INT
		,@i2 int
EXEC spJIRA_IU_API_Calls_Epicor @Operation			= 'GetVersionsList'
						,@BodyData			= ''
						,@VersionsList		= @VersionsList OUT
                        ,@issueID			= @i1 OUT
						,@issueStatusID		= @i2 OUT

DECLARE cur0 CURSOR
KEYSET
FOR
	SELECT	 a.[Version]
			,StartDate1 = GETDATE()
	FROM #JiraVersion AS a
	LEFT JOIN STRING_SPLIT(@VersionsList, '|')  splt ON splt.value = A.[Version]
													AND RTRIM(splt.value) <> ''
	WHERE splt.value IS NULL

DECLARE  @NewVersion	NVARCHAR(100)
		,@StartDate1	DATE
OPEN cur0

FETCH NEXT FROM cur0 INTO  @NewVersion
						  ,@StartDate1

WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		DECLARE @BodyVersion VARCHAR(MAX)
		SET @BodyVersion = '
		{
		  "name": "' + dbo.GetValidJSON(@NewVersion) + '",
		  "startDate": "' + CONVERT(VARCHAR(10), @StartDate1, 120) + '",
		  "project": "' + @JiraProject + '"
		}
		'
		EXEC spJIRA_IU_API_Calls_Epicor @Operation			= 'AddVersion'
								,@BodyData			= @BodyVersion
	END
	-- SELECT @@ROWCOUNT;

	FETCH NEXT FROM cur0 INTO  @NewVersion
							  ,@StartDate1
END

CLOSE cur0
DEALLOCATE cur0

--GOTO FINISH1;




DECLARE cur1 CURSOR
KEYSET
FOR
	SELECT
		MaxInsertedDate,
		MinInsertedDate,
		EACount,
		InstanceID,
		VersionID,
		ProcedureName,
		ErrorMessage,
		InstanceName,
		ApplicationName,
		AffectVersion
	FROM #ErrAtt

DECLARE  @MaxInsertedDate	DATETIME
		,@MinInsertedDate	DATETIME
		,@EACount			INT
		,@InstanceID		INT
		,@VersionID			INT
		,@ProcedureName		NVARCHAR(MAX)
		,@ErrorMessage		NVARCHAR(MAX)
		,@InstanceName		NVARCHAR(100)
		,@ApplicationName	NVARCHAR(100)
		,@AffectVersion		NVARCHAR(100)

		,@LastParameter		NVARCHAR(MAX)

		--SELECT [@FixVersion] = @FixVersion

OPEN cur1

FETCH NEXT FROM cur1 INTO  @MaxInsertedDate
						  ,@MinInsertedDate
						  ,@EACount
						  ,@InstanceID
						  ,@VersionID
						  ,@ProcedureName
						  ,@ErrorMessage
						  ,@InstanceName
						  ,@ApplicationName
						  ,@AffectVersion

WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

	--DECLARE @Summary NVARCHAR(MAX) = 'ErrorAttention ' + CONVERT(NVARCHAR(10), @InsertedDate, 102) + ' @InstanceID=' + CAST(@InstanceID AS NVARCHAR(15))+ ' ' + @ProcedureName;
	SET @ErrorMessage	= COALESCE(@ErrorMessage, N'null')
	SET @ProcedureName	= COALESCE(@ProcedureName, N'null')
	SET	@AffectVersion	= COALESCE(@AffectVersion, '')
	SET @FixVersion		= COALESCE(@FixVersion, '')

	DECLARE @IssueSummary NVARCHAR(MAX) = COALESCE(@ApplicationName + ' ', '') + @ProcedureName + ' ' + LEFT(@ErrorMessage, 100) + IIF(LEN(@ErrorMessage)>100, '...', '');

	SELECT  [@IssueSummary]     = @IssueSummary
		   ,[@MaxInsertedDate]	= @MaxInsertedDate
		   ,[@MinInsertedDate]	= @MinInsertedDate
		   ,[@EACount]			= @EACount
		   ,[@InstanceID]		= @InstanceID
		   ,[@VersionID]		= @VersionID
		   ,[@ProcedureName]	= @ProcedureName
		   ,[@ErrorMessage]		= @ErrorMessage
		   ,[@InstanceName]		= @InstanceName
		   ,[@ApplicationName]	= @ApplicationName

	DECLARE
		 @JSON_MaxInsertedDate	NVARCHAR(22)
		,@JSON_MinInsertedDate	NVARCHAR(22)
		,@JSON_ProcedureName	NVARCHAR(MAX) = dbo.GetValidJSON(@ProcedureName)
		,@JSON_ErrorMessage		NVARCHAR(MAX) = dbo.GetValidJSON(@ErrorMessage)
		,@JSON_InstanceName		NVARCHAR(50)  = dbo.GetValidJSON(COALESCE(@InstanceName, 'null'))
		,@JSON_ApplicationName	NVARCHAR(100) = dbo.GetValidJSON(COALESCE(@ApplicationName, 'null'))
		,@JSON_QUERY			NVARCHAR(MAX) = dbo.GetValidJSON(
'SELECT  EA.*
		,JL.*
FROM
	[pcINTEGRATOR_Log].[dbo].[ErrorAttention] EA
INNER JOIN [pcINTEGRATOR_Log].[dbo].[JobLog] JL (nolock) ON 1 = 1
	AND JL.JobLogID = EA.JobLogID
	AND JL.ProcedureName = ''' + @ProcedureName + '''
	AND JL.ErrorMessage ' + CASE WHEN @ErrorMessage <> N'null' THEN '= ''' + REPLACE(@ErrorMessage, '''', '''''') + ''' '
								else ' IS NULL '
								END +
	/*
							CASE WHEN @ErrorMessage <> N'null' THEN 'LIKE ''%' + REPLACE(REPLACE(@ErrorMessage, '[', '|['), '''', '''''') + '%'' ESCAPE ''|'' '
								else ' IS NULL '
								END +
								*/
'
WHERE
		EA.InstanceID ' + CASE WHEN @InstanceID IS NULL then 'IS NULL' ELSE '= ' + CAST(@InstanceID AS NVARCHAR(20)) END + '
	AND EA.VersionID ' + CASE WHEN @VersionID IS NULL then 'IS NULL' ELSE '= ' + CAST(@VersionID AS NVARCHAR(20)) END + '
	--AND EA.ClearedYN = 0
ORDER BY
	JL.InstanceID,
	JL.StartTime DESC'
	)


		,@JSON_LastParameter		NVARCHAR(MAX)
		,@Exist_JiraIssueID			INT
		,@Exist_JiraIssueStatusID	INT
		,@Exist_JiraMaxInsertedDate	DATETIME
		,@Exist_JiraMinInsertedDate	DATETIME
		,@Exist_JiraEACount			INT


		SELECT TOP 1
				 @JSON_LastParameter		= Parameter
				,@Exist_JiraIssueID			= EA_with_Jira.[JiraIssueID]
				,@Exist_JiraIssueStatusID	= EA_with_Jira.[JiraIssueStatusID]
				,@Exist_JiraMaxInsertedDate	= EA_with_Jira.[MaxInsertedDate]
				,@Exist_JiraMinInsertedDate	= EA_with_Jira.[MinInsertedDate]
				,@Exist_JiraEACount			= EA_with_Jira.EACount
		FROM [pcINTEGRATOR_Log].[dbo].[JobLog] (nolock) JL
		LEFT JOIN [pcINTEGRATOR_Log].[dbo].[ErrorAttention] EA ON EA.[JobLogID] = JL.[JobLogID]
		LEFT JOIN (SELECT	 JL_with_Jira.InstanceID
							,JL_with_Jira.VersionID
							,JL_with_Jira.ProcedureName
							,JL_with_Jira.ErrorMessage
							,EA_with_Jira2.[JiraIssueID]
							,EA_with_Jira2.[JiraIssueStatusID]
							,MAX(EA_with_Jira2.[Inserted]) AS [MaxInsertedDate]
							,MIN(EA_with_Jira2.[Inserted]) AS [MinInsertedDate]
							,COUNT(1) AS EACount
					FROM [pcINTEGRATOR_Log].[dbo].[JobLog] JL_with_Jira (nolock)
					JOIN [pcINTEGRATOR_Log].[dbo].[ErrorAttention] EA_with_Jira2 ON EA_with_Jira2.[JobLogID] = JL_with_Jira.[JobLogID]
																				AND EA_with_Jira2.JiraIssueID IS NOT NULL
					GROUP BY JL_with_Jira.InstanceID
							,JL_with_Jira.VersionID
							,JL_with_Jira.ProcedureName
							,JL_with_Jira.ErrorMessage
							,EA_with_Jira2.[JiraIssueID]
							,EA_with_Jira2.[JiraIssueStatusID]
                    ) AS EA_with_Jira ON	EA_with_Jira.InstanceID		= JL.InstanceID
										AND EA_with_Jira.VersionID		= JL.VersionID
										AND EA_with_Jira.ProcedureName	= JL.ProcedureName
										AND EA_with_Jira.ErrorMessage	= JL.ErrorMessage
		WHERE   EA.Inserted = @MaxInsertedDate
			AND COALESCE(JL.VersionID, 0) = COALESCE(@VersionID, 0)
			AND COALESCE(JL.InstanceID, 0) = COALESCE(@InstanceID, 0)
			AND COALESCE(JL.ProcedureName, 'null') = COALESCE(@ProcedureName, 'null')
			AND COALESCE(JL.ErrorMessage, 'null') = COALESCE(@ErrorMessage, 'null')

		SET @MaxInsertedDate = CASE WHEN @MaxInsertedDate >= COALESCE(@Exist_JiraMaxInsertedDate, @MaxInsertedDate) THEN @MaxInsertedDate ELSE @Exist_JiraMaxInsertedDate END;
		SET @MinInsertedDate = CASE when @MinInsertedDate <= COALESCE(@Exist_JiraMinInsertedDate, @MinInsertedDate) THEN @MinInsertedDate ELSE @Exist_JiraMinInsertedDate end;
		SET @EACount = @EACount + COALESCE(@Exist_JiraEACount, 0)

		SET @JSON_MaxInsertedDate	 =  CONVERT(VARCHAR(10), @MaxInsertedDate, 104) + ' ' + CONVERT(VARCHAR(12), @MaxInsertedDate, 114)
		SET @JSON_MinInsertedDate	 =  CONVERT(VARCHAR(10), @MinInsertedDate, 104) + ' ' + CONVERT(VARCHAR(12), @MinInsertedDate, 114)

		SET @JSON_LastParameter = dbo.GetValidJSON(COALESCE(@JSON_LastParameter, 'null'));

--				"customfield_20277":[{"value":"' + @DBEnvironment + '"}],
	DECLARE @BodyData_forInsert VARCHAR(MAX) =  -- create new issue
	'{
			"fields": {
				"fixVersions":[{"name":"' + @FixVersion + '"}],
				"versions":[{"name":"' + @AffectVersion + '"}],
			   "project":
			   {
				  "key": "' + @JiraProject + '"
			   },
			   "summary": "' + dbo.GetValidJSON(@IssueSummary) + '",
			   "assignee": {
                    "id": "712020:14b043b7-d278-4dd5-b364-37dfdb89be65"
                },
			   "labels": [
						 "ErrorAttention"
						 ,"' + dbo.GetValidJSON(@SQLInstanceName) + '"
						 ],
				"description": {
					"version": 1,
					"type": "doc",
					"content": [
						{
							"type": "panel",
							"attrs": {
								"panelType": "info"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "SP               : "
										},
										{
											"type": "text",
											"text": "' + @JSON_ProcedureName + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "InstanceID  : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@InstanceID, '') AS NVARCHAR(20)) + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "VersionID   : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@VersionID, '') AS NVARCHAR(20)) + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "Instance    : "
										},
										{
											"type": "text",
											"text": "' + @JSON_InstanceName + '",
											"marks": [
												{
													"type": "strong"
												},
												{
													"type": "textColor",
													"attrs": {
														"color": "#6554c0"
													}
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "Application: "
										},
										{
											"type": "text",
											"text": "' + @JSON_ApplicationName + '",
											"marks": [
												{
													"type": "strong"
												},
												{
													"type": "textColor",
													"attrs": {
														"color": "#6554c0"
													}
												}
											]
										}
									]
								}
							]
						},
						{
							"type": "panel",
							"attrs": {
								"panelType": "note"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "Newest date: "
										},
										{
											"type": "text",
											"text": "' + @JSON_MaxInsertedDate + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "Oldest  date: "
										},
										{
											"type": "text",
											"text": "' + @JSON_MinInsertedDate + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "Errors count: "
										},
										{
											"type": "text",
											"text": "' + CAST(@EACount AS NVARCHAR(20)) + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										}
									]
								}
							]
						},
						{
							"type": "panel",
							"attrs": {
								"panelType": "error"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "' + dbo.GetValidJSON(@ErrorMessage) + '"
										}
									]
								}
							]
						},
						{
							"type": "panel",
							"attrs": {
								"panelType": "warning"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "' + @JSON_LastParameter + '"
										}
									]
								}
							]
						},
						{
							"type": "codeBlock",
							"attrs": {
								"language": "sql"
							},
							"content": [
								{
									"type": "text",
									"text": "' + @JSON_QUERY + '"
								}
							]
						}
					]
				},
			   "issuetype": {
				  "name": "Error Attention"
			   }
		   }
		}';

-- 				"customfield_20277":[{"value":"' + @DBEnvironment + '"}],
	DECLARE @BodyData_forUpdate VARCHAR(MAX) =  -- update existing issue
		'{
			"fields": {
				"fixVersions":[{"name":"' + @FixVersion + '"}],
				"versions":[{"name":"' + @AffectVersion + '"}],
				"description": {
					"version": 1,
					"type": "doc",
					"content": [
						{
							"type": "panel",
							"attrs": {
								"panelType": "info"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "SP               : "
										},
										{
											"type": "text",
											"text": "' + @JSON_ProcedureName + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "InstanceID : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@InstanceID, '') AS NVARCHAR(20)) + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "VersionID   : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@VersionID, '') AS NVARCHAR(20)) + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "Instance    : "
										},
										{
											"type": "text",
											"text": "' + @JSON_InstanceName + '",
											"marks": [
												{
													"type": "strong"
												},
												{
													"type": "textColor",
													"attrs": {
														"color": "#6554c0"
													}
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "Application: "
										},
										{
											"type": "text",
											"text": "' + @JSON_ApplicationName + '",
											"marks": [
												{
													"type": "strong"
												},
												{
													"type": "textColor",
													"attrs": {
														"color": "#6554c0"
													}
												}
											]
										}
									]
								}
							]
						},
						{
							"type": "panel",
							"attrs": {
								"panelType": "note"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "Newest date: "
										},
										{
											"type": "text",
											"text": "' + @JSON_MaxInsertedDate + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "Oldest  date: "
										},
										{
											"type": "text",
											"text": "' + @JSON_MinInsertedDate + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										},
										{
											"type": "hardBreak"
										},
										{
											"type": "text",
											"text": "Errors count: "
										},
										{
											"type": "text",
											"text": "' + CAST(@EACount AS NVARCHAR(20)) + '",
											"marks": [
												{
													"type": "strong"
												}
											]
										}
									]
								}
							]
						},
						{
							"type": "panel",
							"attrs": {
								"panelType": "error"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "' + dbo.GetValidJSON(@ErrorMessage) + '"
										}
									]
								}
							]
						},
						{
							"type": "panel",
							"attrs": {
								"panelType": "warning"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "' + @JSON_LastParameter + '"
										}
									]
								}
							]
						},
						{
							"type": "codeBlock",
							"attrs": {
								"language": "sql"
							},
							"content": [
								{
									"type": "text",
									"text": "' + @JSON_QUERY + '"
								}
							]
						}
					]
				}
		   }
		}';

	DECLARE  @IssueID INT
			,@issueStatusID	INT
			,@Operation VARCHAR(255) = CASE WHEN  @Exist_JiraIssueID IS NULL THEN 'Insert'
										ELSE 'Update'
										END
			,@BodyData VARCHAR(MAX) = CASE WHEN @Exist_JiraIssueID IS NULL THEN -- create new issue
													@BodyData_forInsert
											ELSE -- update existing issue
													@BodyData_forUpdate
											END;

-- SELECT [Debug] = 'Step_1'

	EXEC spJIRA_IU_API_Calls_Epicor @Operation			= @Operation
							,@BodyData			= @BodyData
							,@Exist_JiraIssueID = @Exist_JiraIssueID
							,@Exist_JiraIssueStatusID = @Exist_JiraIssueStatusID
							,@IssueID			= @IssueID OUT
							,@issueStatusID		= @issueStatusID OUT

	-- if something happened on update existed issue..., usually [spJIRA_IU_API_Calls_Epicor] gets:  "Response Text" = {"errorMessages":["Issue does not exist or you do not have permission to see it."],"errors":{}}
	IF		@Exist_JiraIssueID IS NOT NULL
		AND @Operation = 'Update'
		AND	@IssueID IS NULL
		AND @issueStatusID IS NULL
		BEGIN
			SELECT   [@Exist_JiraIssueID] = @Exist_JiraIssueID
					,[@IssueID] = @IssueID
					,[@issueStatusID] = @issueStatusID

			SELECT   @Operation = 'Insert'
					,@BodyData = @BodyData_forInsert
					,@Exist_JiraIssueID = NULL
					,@Exist_JiraIssueStatusID = NULL

			-- try to create new jira issue
			EXEC spJIRA_IU_API_Calls_Epicor @Operation	= @Operation
									,@BodyData			= @BodyData
									,@Exist_JiraIssueID = @Exist_JiraIssueID
									,@Exist_JiraIssueStatusID = @Exist_JiraIssueStatusID
									,@IssueID			= @IssueID OUT
									,@issueStatusID		= @issueStatusID OUT
			--CLOSE cur1
			--DEALLOCATE cur1
			--GOTO FINISH1;
		END

SELECT	 [Scope] = 'Jira_Add_ErrorAttention'
		,[@Operation]				= @Operation
		,[@BodyData]				= @BodyData
		,[@JSON_QUERY]				= @JSON_QUERY
		,[@IssueSummary]			= @IssueSummary
		,[@JSON_ProcedureName]		= @JSON_ProcedureName
		,[@InstanceID]				= @InstanceID
		,[@VersionID]				= @VersionID
		,[@JSON_InstanceName]	    = @JSON_InstanceName
		,[@JSON_ApplicationName]	= @JSON_ApplicationName
		,[@ErrorMessage]			= @ErrorMessage
		,[@JSON_LastParameter]		= @JSON_LastParameter
		,[@JSON_MaxInsertedDate]	= @JSON_MaxInsertedDate
		,[@JSON_MinInsertedDate]	= @JSON_MinInsertedDate
		,[@EACount]					= @EACount

		,[@Exist_JiraIssueID]		= @Exist_JiraIssueID
		,[@Exist_JiraIssueStatusID] = @Exist_JiraIssueStatusID
		,[@IssueID]					= @IssueID
		,[@issueStatusID]			= @issueStatusID

	UPDATE EA
	SET  EA.JiraIssueID			= COALESCE(@Exist_JiraIssueID, @IssueID)
		,EA.jiraIssueStatusID	= @issueStatusID
	FROM [pcINTEGRATOR_Log].[dbo].[JobLog] JL (nolock)
	JOIN [pcINTEGRATOR_Log].[dbo].[ErrorAttention] EA ON	EA.[JobLogID] = JL.[JobLogID]
														AND COALESCE(EA.JiraIssueID, -999) <> COALESCE(@Exist_JiraIssueID, @IssueID)
	WHERE		COALESCE(JL.VersionID, 0)			= COALESCE(@VersionID, 0)
			AND COALESCE(JL.InstanceID, 0)			= COALESCE(@InstanceID, 0)
			AND COALESCE(JL.ProcedureName, 'null')	= COALESCE(@ProcedureName, 'null')
			AND COALESCE(JL.ErrorMessage, N'null')	= COALESCE(@ErrorMessage, N'null')


	END
	SELECT [updated_count] = @@ROWCOUNT;

	FETCH NEXT FROM cur1 INTO  @MaxInsertedDate
							  ,@MinInsertedDate
							  ,@EACount
							  ,@InstanceID
							  ,@VersionID
							  ,@ProcedureName
							  ,@ErrorMessage
							  ,@InstanceName
							  ,@ApplicationName
							  ,@AffectVersion
END

CLOSE cur1
DEALLOCATE cur1

-- select CONVERT(VARCHAR(16), GETDATE(), 120)
DECLARE @startupdate VARCHAR(16) = CONVERT(VARCHAR(10), DATEADD(d,-1,CAST(GETDATE() AS DATE)), 120) + ' 00:00';
DECLARE @stopupdate VARCHAR(16) = CONVERT(VARCHAR(16), GETDATE(), 120);
DECLARE @BodyDataUpdate VARCHAR(MAX) = '{
										  "jql": "updated >= \"' + @startupdate + '\" AND updated <= \"' + @stopupdate + '\" AND project = \"' + @JiraProject + '\" AND issuetype in (\"Bug\", \"Error Attention\") AND labels in (\"ErrorAttention\") order by created DESC",
										  "maxResults": 100,
										  "fields": [
											"summary",
											"status"
										  ],
										  "startAt": 0
										}';

--SELECT @startupdate
	   --,@stopupdate

EXEC spJIRA_IU_API_Calls_Epicor @Operation			= 'UpdateFromJira'
						,@BodyData			= @BodyDataUpdate

			,@Exist_JiraIssueID = @Exist_JiraIssueID
			,@Exist_JiraIssueStatusID = @Exist_JiraIssueStatusID
			,@IssueID			= @IssueID OUT
			,@issueStatusID		= @issueStatusID OUT

/*
'{
  "jql": "updated >= \"2022-01-04 10:00\" AND updated <= \"2023-01-11 23:59\" AND project = \"SEG\" AND issuetype = \"Bug\" AND labels in (\"ErrorAttention\") order by created DESC",
  "maxResults": 100,
  "fields": [
    "summary",
    "status"
  ],
  "startAt": 0
}'
*/


FINISH1:
DROP TABLE #ErrAtt
DROP TABLE #JiraVersion
-- drop table #JiraUserList

DROP TABLE #DBEnvironment
GO
