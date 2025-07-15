SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFormGetCB_Language] 

	@GetVersion bit = 0

--#WITH ENCRYPTION#--

AS

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.2.2052'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

SELECT
	[LanguageID],
    [Description] = [LanguageCode] + ' - ' + [LanguageName]
FROM
	[Language]
WHERE
	LanguageID > 0
ORDER BY
	[LanguageCode]






GO
