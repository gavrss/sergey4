SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFormGet_Model] 

	@GetVersion bit = 0

--#WITH ENCRYPTION#--

AS

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2137'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.3.2076' SET @Description = '[SelectYN] added.'
		IF @Version = '1.4.0.2137' SET @Description = 'Only children of selected Applications are visible.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

SELECT
	M.[ApplicationID],
	M.[ModelID],
	M.[ModelName],
	M.[ModelDescription],
	BaseModelName = BM.ModelName,
	M.[SelectYN]
FROM 
	[Model] M
	INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
	INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.SelectYN <> 0
WHERE
	M.ApplicationID > 0 AND
	M.ModelID > 0






GO
