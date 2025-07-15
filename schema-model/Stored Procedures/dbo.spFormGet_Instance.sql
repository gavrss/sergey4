SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFormGet_Instance] 

	@GetVersion bit = 0

--#WITH ENCRYPTION#--

AS

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2137'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.3.2076' SET @Description = '[Rows] added.'
		IF @Version = '1.4.0.2137' SET @Description = 'Only selected Instances visible.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

SELECT
	I.[CustomerID],
	C.CustomerName,
	I.[InstanceID],
	I.[InstanceName],
	I.[InstanceDescription],
	I.[Rows],
	I.[ProductKey]
FROM
	[Instance] I
	INNER JOIN [Customer] C ON C.CustomerID = I.CustomerID
WHERE
	I.CustomerID > 0 AND
	I.InstanceID > 0 AND
	I.SelectYN <> 0






GO
