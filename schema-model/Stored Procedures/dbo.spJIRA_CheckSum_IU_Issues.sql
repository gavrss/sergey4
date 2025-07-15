SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO




CREATE PROCEDURE [dbo].[spJIRA_CheckSum_IU_Issues]
AS
-- exec [spJIRA_CheckSum_IU_Issues]

DECLARE @SQLInstanceName VARCHAR(255);
SET @SQLInstanceName = @@SERVERNAME + CASE WHEN @@SERVICENAME = 'MSSQLSERVER' THEN '' ELSE '\\' + @@SERVICENAME END;

CREATE TABLE #JiraUserList(
	  [AccountID] [VARCHAR](255)
	 ,[UserEmail] [NVARCHAR](255) 
)
EXEC spJIRA_IU_API_Calls @Operation			= 'GetUserList'
						,@BodyData			= ''
						,@JiraProject		= 'CHEC'



------------------------------
CREATE TABLE #DBEnvironment(
	[EnvName] [NVARCHAR](100) 
)

DECLARE @EnvName		NVARCHAR(MAX) 
EXEC spJIRA_IU_API_Calls @Operation			= 'GetDBEnvironments'
						,@BodyData			= ''
						,@JiraProject		= 'CHEC'
						,@DBEnvironments	= @EnvName OUT

INSERT INTO #DBEnvironment (EnvName)
SELECT	 splt.value
FROM STRING_SPLIT(@EnvName, '|')  splt 
WHERE splt.value <> ''

DECLARE @DBEnvironment NVARCHAR(255) = '';
SELECT TOP 1  
		@DBEnvironment = EnvName
FROM #DBEnvironment
WHERE EnvName like '%' + @SQLInstanceName + '%';

-------------------------------------------------------------------
CREATE TABLE #JiraVersion(
	[Version] [nvarchar](100) 
)

CREATE TABLE #CheckSum (
	[InstanceID]			[int] NOT NULL,
	[VersionID]				[int] NOT NULL,
	[CheckSumID]			[int] NOT NULL,
	[CheckSumLogID_Max]		[bigint] NULL,
	[Open]					[int] NOT NULL,
	[Inserted]				[datetime] NOT NULL,
	[JobID]					[bigint] NOT NULL,
	[CheckSumName]			[nvarchar](50) NOT NULL,
	[CheckSumDescription]	[nvarchar](255) NOT NULL,
	[DescriptionMitigate]	[nvarchar](1000) NULL,
	[SortOrder]				[int] NOT NULL,
	[ActionResponsible]		[nvarchar](100) NULL,
	[InstanceName]			[nvarchar](50) NULL,
	[InstanceDescription]	[nvarchar](255) NULL,
	[ApplicationName]		[nvarchar](100) NULL
)

DECLARE @FixVersion nvarchar(100)
EXEC dspdevdb01.pcintegrator.dbo.[spGet_Version] @Version = @FixVersion OUTPUT

INSERT INTO #CheckSum
(
	 [InstanceID]			
	,[VersionID]				
	,[CheckSumID]			
	,[CheckSumLogID_Max]		
	,[Open]					
	,[Inserted]				
	,[JobID]					
	,[CheckSumName]			
	,[CheckSumDescription]	
	,[DescriptionMitigate]	
	,[SortOrder]				
	,[ActionResponsible]		
	,[InstanceName]		
	,[InstanceDescription]
	,[ApplicationName]		
)
SELECT  CSL1.*
		,[Open] = CSL2.CheckSumStatus10
		,CSL2.Inserted
		,CSL2.JobID
		,C.CheckSumName
		,C.CheckSumDescription
		,C.DescriptionMitigate
		,C.SortOrder
		,C.ActionResponsible
		,INS.InstanceName
		,INS.InstanceDescription
		,APP.ApplicationName
		--,[AffectVersion] = JL.[Version]
FROM (
/*
		  SELECT 
				 CSL.InstanceID
				,CSL.VersionID
				,CSL.CheckSumID
				,CheckSumLogID_Max = MAX(CSL.CheckSumLogID)
		  FROM pcINTEGRATOR_Log..CheckSumLog CSL
		  WHERE CSL.CheckSumStatus10 <> 0
		  GROUP BY 
				 CSL.InstanceID
				,CSL.VersionID
				,CSl.CheckSumID
*/
			SELECT 
					 CSL.InstanceID
					,CSL.VersionID
					,CSL.CheckSumID
					,CheckSumLogID_Max = MAX(CSL.CheckSumLogID)
			FROM  (
					  SELECT 
							 CSL0.InstanceID
							,CSL0.VersionID
							,CSL0.CheckSumID
							,CSL0.CheckSumLogID
							,RANK() OVER (PARTITION BY CSL0.InstanceID, CSL0.VersionID ORDER BY CSL0.JobID DESC) AS Rank1  
					  FROM pcINTEGRATOR_Log..CheckSumLog CSL0
					  WHERE CSL0.CheckSumStatus10 <> 0
						-- AND CSL0.InstanceID = 531
						-- AND CSL.CheckSumID = 1006
					) AS CSL
			WHERE CSL.Rank1 = 1
			GROUP BY 
				 CSL.InstanceID
				,CSL.VersionID
				,CSl.CheckSumID
		) AS CSL1
LEFT JOIN pcINTEGRATOR_Data..[CheckSum] C ON		C.InstanceID = CSL1.InstanceID AND C.VersionID = CSL1.VersionID AND C.CheckSumID = CSL1.CheckSumID
										AND C.JiraIssueID IS NULL 
JOIN pcINTEGRATOR_Log..CheckSumLog CSL2 ON CSL2.CheckSumLogID = CSL1.CheckSumLogID_Max
LEFT JOIN [pcINTEGRATOR_Data].dbo.Instance INS ON INS.InstanceID = CSL1.InstanceID
LEFT JOIN [pcINTEGRATOR_Data].dbo.Application APP ON	APP.InstanceID = CSL1.InstanceID
													AND App.VersionID = CSL1.VersionID	
-- LEFT JOIN [pcINTEGRATOR_Log].[dbo].[JobLog] JL ON JL.JobID
WHERE 
	C.ActionResponsible IS NOT null
--	AND DATEDIFF(HOUR, CSL2.[Inserted], GETDATE()) <= 72
ORDER BY CSL1.InstanceID, CSL1.VersionID, C.SortOrder DESC


INSERT INTO #JiraVersion
(
Version
)
/*
SELECT DISTINCT AffectVersion AS [Version]
FROM #CheckSum
UNION
*/
SELECT @FixVersion AS [Version]


DECLARE @VersionsList		nVARCHAR(MAX) 
		,@i1 INT
		,@i2 int
EXEC spJIRA_IU_API_Calls @Operation			= 'GetVersionsList'
						,@BodyData			= ''
						,@JiraProject		= 'CHEC'
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
		DECLARE @BodyVersion VARCHAR(8000)
		SET @BodyVersion = '
		{
		  "name": "' + dbo.GetValidJSON(@NewVersion) + '",
		  "startDate": "' + CONVERT(VARCHAR(10), @StartDate1, 120) + '",
		  "project": "CHEC"
		}
		'
		EXEC spJIRA_IU_API_Calls @Operation			= 'AddVersion'
								,@BodyData			= @BodyVersion
								,@JiraProject		= 'CHEC'

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
		 [InstanceID]			
		,[VersionID]				
		,[CheckSumID]			
		,[CheckSumLogID_Max]		
		,[Open]					
		,[Inserted]				
		,[JobID]					
		,[CheckSumName]			
		,[CheckSumDescription]	
		,[DescriptionMitigate]	
		,[SortOrder]				
		,[ActionResponsible]		
		,[InstanceName]	
		,[InstanceDescription]
		,[ApplicationName]		
	FROM #CheckSum

DECLARE  
	 @InstanceID 			[int]
	,@VersionID				[INT]
	,@CheckSumID			[int]
	,@CheckSumLogID_Max		[bigint]
	,@Open					[int]
	,@Inserted				[datetime]
	,@JobID					[bigint]
	,@CheckSumName			[nvarchar](50)
	,@CheckSumDescription	[nvarchar](255)
	,@DescriptionMitigate	[nvarchar](1000)
	,@SortOrder				[int]
	,@ActionResponsible		[nvarchar](100)
	,@InstanceName			[nvarchar](50)
	,@InstanceDescription	[nvarchar](255)
	,@ApplicationName		[nvarchar](100)

		--,@LastParameter		NVARCHAR(MAX)
	,@JiraAccountID			[VARCHAR](255)
		--SELECT [@FixVersion] = @FixVersion 

OPEN cur1

FETCH NEXT FROM cur1 INTO  
						 @InstanceID 			
						,@VersionID				
						,@CheckSumID			
						,@CheckSumLogID_Max		
						,@Open					
						,@Inserted				
						,@JobID					
						,@CheckSumName			
						,@CheckSumDescription
						,@DescriptionMitigate
						,@SortOrder				
						,@ActionResponsible		
						,@InstanceName	
						,@InstanceDescription
						,@ApplicationName		

WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

	--DECLARE @Summary NVARCHAR(MAX) = 'ErrorAttention ' + CONVERT(NVARCHAR(10), @InsertedDate, 102) + ' @InstanceID=' + CAST(@InstanceID AS NVARCHAR(15))+ ' ' + @ProcedureName;
--	SET @ErrorMessage	= COALESCE(@ErrorMessage, N'null')
	SET @CheckSumName			= COALESCE(@CheckSumName, N'null')
	SET @CheckSumDescription	= COALESCE(@CheckSumDescription, N'null')
	SET @DescriptionMitigate	= COALESCE(@DescriptionMitigate, N'null')
	SET @ActionResponsible		= COALESCE(@ActionResponsible, N'null')
--	SET	@AffectVersion	= COALESCE(@AffectVersion, '')
	SET @FixVersion		= COALESCE(@FixVersion, '')

	SELECT TOP 1 @JiraAccountID = [AccountID]
	FROM #JiraUserList 
	WHERE UserEmail = @ActionResponsible

	DECLARE @IssueSummary NVARCHAR(MAX) = COALESCE(@ApplicationName + '. ', '') + @CheckSumName 

	SELECT  			 
		 [@InstanceID] 			= @InstanceID 			
		,[@VersionID]			= @VersionID				
		,[@CheckSumID]			= @CheckSumID			
		,[@CheckSumLogID_Max]	= @CheckSumLogID_Max		
		,[@Open]				= @Open					
		,[@Inserted]			= @Inserted				
		,[@JobID]				= @JobID					
		,[@CheckSumName]		= @CheckSumName			
		,[@CheckSumDescription]	= @CheckSumDescription
		,[@DescriptionMitigate]	= @DescriptionMitigate
		,[@SortOrder]			= @SortOrder				
		,[@ActionResponsible]	= @ActionResponsible		
		,[@InstanceName]		= @InstanceName	
		,[@InstanceDescription] = @InstanceDescription
		,[@ApplicationName]		= @ApplicationName	
		,[@JiraAccountID]		= @JiraAccountID

	DECLARE  
		 --@JSON_ProcedureName	NVARCHAR(MAX) = dbo.GetValidJSON(@ProcedureName) 
		--,@JSON_ErrorMessage		NVARCHAR(MAX) = dbo.GetValidJSON(@ErrorMessage)
		 @JSON_InstanceName		NVARCHAR(50)  = dbo.GetValidJSON(@InstanceName)
		,@JSON_InstanceDescription		NVARCHAR(50)	= dbo.GetValidJSON(@InstanceDescription)
		,@JSON_ApplicationName	NVARCHAR(100)			= dbo.GetValidJSON(COALESCE(@ApplicationName, 'null'))
		,@JSON_DescriptionMitigate	NVARCHAR(1000)		= dbo.GetValidJSON(COALESCE(@DescriptionMitigate, 'null'))
		,@JSON_URL				NVARCHAR(MAX)			= dbo.GetValidJSON('https://epicor.performancecanvas.com/#!check-sum-details/instanceID=' + CAST(@InstanceID AS varchar(255)) + '&versionID=' + CAST(@VersionID AS varchar(255)) + '&checksumID=' + CAST(COALESCE(@CheckSumID, '') AS NVARCHAR(20)))
		--,@JSON_LastParameter		NVARCHAR(MAX) 
		,@Exist_JiraIssueID			INT
		,@Exist_JiraIssueStatusID	INT
		--,@Exist_JiraMaxInsertedDate	DATETIME
		--,@Exist_JiraMinInsertedDate	DATETIME
		--,@Exist_JiraEACount			INT 
		,@JSON_Inserted VARCHAR(255)


		SELECT TOP 1 
				 @Exist_JiraIssueID			= CS_with_Jira.[JiraIssueID]
				,@Exist_JiraIssueStatusID	= CS_with_Jira.[JiraIssueStatusID]
		FROM pcINTEGRATOR_Data..[CheckSum] CS_with_Jira 
		WHERE   	CS_with_Jira.InstanceID = @InstanceID 
				AND CS_with_Jira.VersionID = @VersionID 
				AND CS_with_Jira.CheckSumID = @CheckSumID
				AND CS_with_Jira.JiraIssueID IS NOT NULL 


		SET @JSON_Inserted	 =  CONVERT(VARCHAR(10), @Inserted, 104) + ' ' + CONVERT(VARCHAR(12), @Inserted, 114)
--		SET @JSON_MinInsertedDate	 =  CONVERT(VARCHAR(10), @MinInsertedDate, 104) + ' ' + CONVERT(VARCHAR(12), @MinInsertedDate, 114)
	
		--SET @JSON_LastParameter = dbo.GetValidJSON(COALESCE(@JSON_LastParameter, 'null'));

	DECLARE @BodyData VARCHAR(8000) = 
		CASE WHEN @Exist_JiraIssueID IS NULL THEN -- create new issue
--                      "id": "6169dfbbc7bea40069e05464"
--                      "id": "' + dbo.GetValidJSON(@JiraAccountID) + '"


	'{
			"fields": {
				"fixVersions":[{"name":"' + @FixVersion + '"}],
 				"customfield_12962":[{"value":"' + @DBEnvironment + '"}],
			   "project":
			   {
				  "key": "CHEC"
			   },
			   "summary": "' + dbo.GetValidJSON(@IssueSummary) + '",
			   "assignee": {
                     "id": "6169dfbbc7bea40069e05464"
                },
			   "labels": [
						 "' + dbo.GetValidJSON(@ActionResponsible) + '"
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
											"text": "CheckSumID : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@CheckSumID, '') AS NVARCHAR(20)) + '",
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
											"text": "Name           : "
										},
										{
											"type": "text",
											"text": "' + @CheckSumName + '",
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
											"text": "Description  : "
										},
										{
											"type": "text",
											"text": "' + @CheckSumDescription + '",
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
											"text": "Mitigate       : "
										},
										{
											"type": "text",
											"text": "' + @JSON_DescriptionMitigate + '",
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
								"panelType": "note"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "InstanceDescription   : "
										},
										{
											"type": "text",
											"text": "' + @JSON_InstanceDescription + '",
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
										},										
										{
											"type": "hardBreak"
										},										
										{
											"type": "text",
											"text": "Inserted      : "
										},
										{
											"type": "text",
											"text": "' + @JSON_Inserted + '",
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
											"text": "JobID          : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@JobID, '') AS NVARCHAR(20)) + '",
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
											"text": "Open          : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@Open, '') AS NVARCHAR(20)) + '",
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
											"text": "CheckSumLogID: "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@CheckSumLogID_Max, '') AS NVARCHAR(20)) + '",
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
								"panelType": "warning"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "' + @JSON_URL + '",
											"marks": [
												{
													"type": "link",
													"attrs": {
														"href": "' + @JSON_URL + '"
													}
												}
											]
										}
									]
								}
							]
						}
					]
				},
			   "issuetype": {
				  "name": "CheckSum"
			   }
		   }
		}'
	ELSE -- update existing issue
	'{
			"fields": {
				"fixVersions":[{"name":"' + @FixVersion + '"}],				 
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
											"text": "CheckSumID : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@CheckSumID, '') AS NVARCHAR(20)) + '",
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
											"text": "Name           : "
										},
										{
											"type": "text",
											"text": "' + @CheckSumName + '",
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
											"text": "Description  : "
										},
										{
											"type": "text",
											"text": "' + @CheckSumDescription + '",
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
											"text": "Mitigate       : "
										},
										{
											"type": "text",
											"text": "' + @JSON_DescriptionMitigate + '",
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
								"panelType": "note"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "InstanceDescription   : "
										},
										{
											"type": "text",
											"text": "' + @JSON_InstanceDescription + '",
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
										},										
										{
											"type": "hardBreak"
										},										
										{
											"type": "text",
											"text": "Inserted      : "
										},
										{
											"type": "text",
											"text": "' + @JSON_Inserted + '",
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
											"text": "JobID          : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@JobID, '') AS NVARCHAR(20)) + '",
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
											"text": "Open          : "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@Open, '') AS NVARCHAR(20)) + '",
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
											"text": "CheckSumLogID: "
										},
										{
											"type": "text",
											"text": "' + CAST(COALESCE(@CheckSumLogID_Max, '') AS NVARCHAR(20)) + '",
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
								"panelType": "warning"
							},
							"content": [
								{
									"type": "paragraph",
									"content": [
										{
											"type": "text",
											"text": "' + @JSON_URL + '",
											"marks": [
												{
													"type": "link",
													"attrs": {
														"href": "' + @JSON_URL + '"
													}
												}
											]
										}
									]
								}
							]
						}
					]
				}
		   }
		}'

		END;

	DECLARE  @IssueID INT 
			,@issueStatusID	INT
			,@Operation VARCHAR(255) = CASE WHEN  @Exist_JiraIssueID IS NULL THEN 'Insert'
										ELSE 'Update'
										END;

-- SELECT [Debug] = 'Step_1'

	EXEC spJIRA_IU_API_Calls @Operation			= @Operation
							,@BodyData			= @BodyData
							,@Exist_JiraIssueID = @Exist_JiraIssueID
							,@Exist_JiraIssueStatusID = @Exist_JiraIssueStatusID
							,@JiraProject		= 'CHEC'
							,@IssueID			= @IssueID OUT
							,@issueStatusID		= @issueStatusID OUT 

SELECT	 [Scope] = 'Jira_Add_CheckSum'
		,[@Operation]			= @Operation
		,[@BodyData]			= @BodyData
		,[@JSON_URL]			= @JSON_URL
		,[@IssueSummary]		= @IssueSummary
		--,[@JSON_ProcedureName]	= @JSON_ProcedureName
		,[@InstanceID]			= @InstanceID
		,[@VersionID]			= @VersionID
		,[@JSON_ApplicationName]= @JSON_ApplicationName
		--,[@ErrorMessage]		= @ErrorMessage
		--,[@JSON_LastParameter]	= @JSON_LastParameter
		--,[@JSON_MaxInsertedDate] = @JSON_MaxInsertedDate
		--,[@JSON_MinInsertedDate] = @JSON_MinInsertedDate
		--,[@EACount]				 = @EACount

		,[@Exist_JiraIssueID]	= @Exist_JiraIssueID
		,[@Exist_JiraIssueStatusID] = @Exist_JiraIssueStatusID
		,[@IssueID]				= @IssueID 
		,[@issueStatusID]		= @issueStatusID 


	UPDATE CS
	SET  CS.JiraIssueID			= COALESCE(@Exist_JiraIssueID, @IssueID)
		,CS.jiraIssueStatusID	= @issueStatusID
	FROM pcINTEGRATOR_Data..[CheckSum] CS 
	WHERE 	CS.InstanceID	= @InstanceID 
		AND CS.VersionID	= @VersionID 
		AND CS.CheckSumID	= @CheckSumID
		AND CS.JiraIssueID IS NULL 


	END
	-- SELECT @@ROWCOUNT;

	FETCH NEXT FROM cur1 INTO @InstanceID 			
							,@VersionID				
							,@CheckSumID			
							,@CheckSumLogID_Max		
							,@Open					
							,@Inserted				
							,@JobID					
							,@CheckSumName			
							,@CheckSumDescription
							,@DescriptionMitigate
							,@SortOrder				
							,@ActionResponsible		
							,@InstanceName	
							,@InstanceDescription
							,@ApplicationName		
END

CLOSE cur1
DEALLOCATE cur1

-- select CONVERT(VARCHAR(16), GETDATE(), 120)
DECLARE @startupdate VARCHAR(16) = CONVERT(VARCHAR(10), DATEADD(d,-1,CAST(GETDATE() AS DATE)), 120) + ' 00:00';
DECLARE @stopupdate VARCHAR(16) = CONVERT(VARCHAR(16), GETDATE(), 120);
DECLARE @BodyDataUpdate VARCHAR(8000) = '{
										  "jql": "updated >= \"' + @startupdate + '\" AND updated <= \"' + @stopupdate + '\" AND project = \"CHEC\" AND issuetype = \"CheckSum\" order by created DESC",
										  "maxResults": 100,
										  "fields": [
											"summary",
											"status"
										  ],
										  "startAt": 0
										}';

--SELECT @startupdate
	   --,@stopupdate

EXEC spJIRA_IU_API_Calls @Operation			= 'UpdateFromJira'
						,@BodyData			= @BodyDataUpdate
						,@JiraProject		= 'CHEC'
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
DROP TABLE #CheckSum
DROP TABLE #JiraVersion
DROP TABLE #DBEnvironment
DROP TABLE #JiraUserList
GO
