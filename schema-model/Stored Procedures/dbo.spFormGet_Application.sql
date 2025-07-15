SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFormGet_Application] 

	@GetVersion bit = 0

--#WITH ENCRYPTION#--

AS

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2137'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.3.2078' SET @Description = 'Added SelectYN.'
		IF @Version = '1.4.0.2137' SET @Description = 'Only children of selected Instances are visible.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

SELECT 
	A.[InstanceID],
	A.[ApplicationID],
	A.[ApplicationName],
	A.[ApplicationDescription],
	A.[ApplicationServer],
	A.[LanguageID],
	A.[ETLDatabase],
	A.[DestinationDatabase],
	A.[AdminUser],
	A.[FiscalYearStartMonth],
	A.[SelectYN]
FROM
	[Application] A
	INNER JOIN Instance I ON I.InstanceID = A.InstanceID AND I.SelectYN <> 0
WHERE
	A.ApplicationID > 0






GO
