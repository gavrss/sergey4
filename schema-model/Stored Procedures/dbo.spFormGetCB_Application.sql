SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFormGetCB_Application] 

	@GetVersion bit = 0

--#WITH ENCRYPTION#--

AS

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2080'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2080' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

	SELECT
		[ApplicationID],
		[Description] = [ApplicationName]
	FROM
		[Application]
	WHERE
		ApplicationID > 0 AND
		SelectYN <> 0
	ORDER BY
		[ApplicationName]






GO
