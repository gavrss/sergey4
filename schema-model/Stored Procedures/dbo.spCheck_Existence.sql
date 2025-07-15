SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_Existence]

@InstanceID int = NULL,
@ApplicationID int = NULL,
@ExtensionTypeID int = NULL,
@ValidYN bit = 0 OUT,
@GetVersion bit = 0,
@Debug int = 0

/*
DECLARE @ValidYN bit
EXEC spCheck_Existence @ApplicationID = 400, @ExtensionTypeID = 50, @ValidYN = @ValidYN OUT
SELECT ValidYN = @ValidYN

EXEC spCheck_Existence @ApplicationID = 400, @ExtensionTypeID = 50
*/

--#WITH ENCRYPTION#--

AS

DECLARE
	@ExtensionName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL OR @ExtensionTypeID IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID and @ExtensionTypeID must be set'
		RETURN 
	END

--Set @ValidYN
	SET @ValidYN = 1

	SELECT 
		@ExtensionName = ExtensionName
	FROM
		[pcINTEGRATOR].[dbo].[Extension] E
	WHERE
		E.ExtensionTypeID = @ExtensionTypeID AND
		E.SelectYN <> 0

	IF @Debug = 42 SELECT ExtensionName = @ExtensionName

	IF @ExtensionName IS NULL SET @ValidYN = 0


	IF (SELECT COUNT(1) FROM sys.databases WHERE name = @ExtensionName) = 0
		SET @ValidYN = 0


--Return result
	SELECT ValidYN = @ValidYN

GO
