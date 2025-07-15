SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFormGet_Source] 

	@GetVersion bit = 0

--#WITH ENCRYPTION#--

AS

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2137'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.3.2076' SET @Description = '[ETLDatabase_Linked] & [SelectYN] added.'
		IF @Version = '1.4.0.2137' SET @Description = 'Only children of selected Models are visible.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

SELECT  
	S.[ModelID],
	S.[SourceID],
	S.[SourceName],
	S.[SourceDescription],
	SourceType = ST.[SourceTypeName],
	S.[SourceDatabase],
	S.[ETLDatabase_Linked],
	S.[StartYear],
	S.[SelectYN]
FROM
	[Source] S
	INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
	INNER JOIN Model M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
WHERE
	S.ModelID > 0 AND
	S.SourceID > 0






GO
