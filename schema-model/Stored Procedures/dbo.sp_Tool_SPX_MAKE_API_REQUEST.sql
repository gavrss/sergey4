SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROC [dbo].[sp_Tool_SPX_MAKE_API_REQUEST](
	 @RTYPE VARCHAR(MAX) ='POST'
	,@authHeader VARCHAR(MAX) =''
	,@RPAYLOAD VARCHAR(MAX) = '{"text":"complete"}'
	,@URL VARCHAR(MAX) = 'https://hooks.slack.com/services/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'--https://hooks.slack.com/services/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'
	,@OUTSTATUS VARCHAR(MAX) OUTPUT
	,@OUTRESPONSE VARCHAR(MAX) OUTPUT
)
AS
/*
sp_configure 'show advanced options', 1
GO
RECONFIGURE;
GO
sp_configure 'Ole Automation Procedures', 1
GO
RECONFIGURE;

DECLARE @OUTSTATUS VARCHAR(MAX),@OUTRESPONSE VARCHAR(MAX)
EXEC SPX_MAKE_API_REQUEST 'GET','XXX','XXX','http://api.open-notify.org/iss-now.json',@OUTSTATUS OUTPUT,@OUTRESPONSE OUTPUT
SELECT @OUTSTATUS AS [RESPONSE CODE],@OUTRESPONSE AS [RESPONSE VALUES]
*/
/*

DECLARE @OUTSTATUS VARCHAR(MAX),@OUTRESPONSE VARCHAR(MAX),@POSTDATA VARCHAR(MAX) ='{"text":"complete"}', @CUSTNAME VARCHAR(MAX),@ORDERAMT MONEY
EXEC SPX_MAKE_API_REQUEST 'POST','', @POSTDATA, 'https://hooks.slack.com/services/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',@OUTSTATUS OUTPUT,@OUTRESPONSE OUTPUT
SELECT @OUTSTATUS AS [RESPONSE CODE],@OUTRESPONSE AS [RESPONSE CODE]

*/
DECLARE @contentType NVARCHAR(64);
DECLARE @postData NVARCHAR(2000);
DECLARE @responseText NVARCHAR(2000);
DECLARE @responseXML NVARCHAR(2000);
DECLARE @ret INT;
DECLARE @status NVARCHAR(32);
DECLARE @statusText NVARCHAR(32);
DECLARE @token INT;
SET @contentType = 'application/json';
-- Open the connection.
EXEC @ret = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
IF @ret <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);
-- Send the request.
EXEC @ret = sp_OAMethod @token, 'open', NULL, @RTYPE, @url, 'false';
EXEC @ret = sp_OAMethod @token, 'setRequestHeader', NULL, 'Authentication', @authHeader;
EXEC @ret = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', 'application/json';
SET @RPAYLOAD = (SELECT CASE WHEN @RTYPE = 'Get' THEN NULL ELSE @RPAYLOAD END )
EXEC @ret = sp_OAMethod @token, 'send', NULL, @RPAYLOAD; -- IF YOUR POSTING, CHANGE THE LAST NULL TO @postData
-- Handle the response.
EXEC @ret = sp_OAGetProperty @token, 'status', @status OUT;
EXEC @ret = sp_OAGetProperty @token, 'statusText', @statusText OUT;
EXEC @ret = sp_OAGetProperty @token, 'responseText', @responseText OUT;
-- Show the response.
PRINT 'Status: ' + @status + ' (' + @statusText + ')';
PRINT 'Response text: ' + @responseText;
SET @OUTSTATUS = 'Status: ' + @status + ' (' + @statusText + ')'
SET @OUTRESPONSE = 'Response text: ' + @responseText;
-- Close the connection.
EXEC @ret = sp_OADestroy @token;
IF @ret <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);
GO
