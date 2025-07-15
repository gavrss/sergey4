SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- use pcINTEGRATOR;
CREATE   PROCEDURE [dbo].[sp_Tool_send_slack] (
	 @Text VARCHAR(MAX) = 'Complete'
	,@User VARCHAR(255) = 'SeGa'
	)
AS
-- EXEC pcINTEGRATOR..sp_Tool_send_slack @User = 'AlGa', @Text = 'Test from Sergey'
-- exec master.dbo.send_slack @User = 'NeHa', @Text = 'Test6'
SET NOCOUNT ON;
SET @Text  =  dbo.GetValidJSON(@Text)
					+ '\n' + @@SERVERNAME
					+ CASE
							WHEN @@SERVICENAME = 'MSSQLSERVER' THEN ''
							ELSE '\\' + @@SERVICENAME
						END
					+ '.' + ORIGINAL_DB_NAME()
					+ '\n' +  CONVERT(VARCHAR(11), GETDATE(), 104)  + '\t' + CONVERT(VARCHAR(8), GETDATE(), 114)

DECLARE  @OUTSTATUS VARCHAR(MAX)
		,@OUTRESPONSE VARCHAR(MAX)
		,@POSTDATA VARCHAR(MAX) ='{"channel": "@U02HS8AELMQ", "text":"' + @Text + '"}'
		,@CUSTNAME VARCHAR(MAX)
		,@ORDERAMT MONEY
		,@URL VARCHAR(MAX) = 'https://hooks.slack.com/services/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'

-- EXEC sp_Tool_SPX_MAKE_API_REQUEST 'POST','', @POSTDATA, 'https://hooks.slack.com/services/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',@OUTSTATUS OUTPUT,@OUTRESPONSE OUTPUT

SET @POSTDATA = CASE @User
                       WHEN 'SeGa' THEN '{"channel": "@U02HS8AELMQ", "text":"' + @Text + '"}'
                       --WHEN 'AlGa' THEN '{"channel": "D06U2RN6GDV", "text":"' + @Text + '"}'
                       WHEN 'AlGa' THEN '{"channel": "@U06UBPMGGG5", "text":"' + @Text + '"}'
			            -- WHEN 'NeHa' THEN '{"channel": "@UH37F03TP", "text":"' + @Text + '"}'
			            WHEN 'NeHa' THEN '{"channel": "private-nevhan", "text":"' + @Text + '"}'
                       else '{"channel": "@U02HS8AELMQ", "text":"' + @Text + '"}'
                       end

SET @URL = CASE @User
				WHEN 'SeGa' THEN  'https://hooks.slack.com/services/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'
				--WHEN 'NeHa' THEN  'https://hooks.slack.com/services/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'
				ELSE 'https://hooks.slack.com/services/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'
				END

EXEC sp_Tool_SPX_MAKE_API_REQUEST 'POST','', @POSTDATA, @URL, @OUTSTATUS OUTPUT,@OUTRESPONSE OUTPUT
GO
