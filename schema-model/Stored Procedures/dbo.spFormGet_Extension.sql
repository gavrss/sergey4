SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFormGet_Extension] 

	@GetVersion bit = 0

--#WITH ENCRYPTION#--

AS

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2113'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2113' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

SELECT 
	E.ExtensionID,
	E.ExtensionName,
	ET.[Description],
	E.SelectYN,
	ET.FixedDbNameYN
FROM
	[Extension] E
	INNER JOIN [ExtensionType] ET ON ET.ExtensionTypeID = E.ExtensionTypeID




GO
