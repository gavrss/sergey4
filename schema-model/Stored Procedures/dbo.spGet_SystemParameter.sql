SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_SystemParameter]
	(
	@InstanceID int = NULL,
	@Parameter nvarchar(50) = NULL,
	@ParameterValue nvarchar(50) = NULL OUT,
	@GetSystemParameterYN bit = 0,
	@GetVersion bit = 0,
	@Debug bit = 0
	)

--#WITH ENCRYPTION#--

AS

/*
EXEC spGet_SystemParameter @InstanceID = 0, @Parameter = '@FinancialsClosedMonth', @GetSystemParameterYN = 1

DECLARE @ParameterValue nvarchar(50), @FinancialsClosedMonth int
EXEC spGet_SystemParameter @InstanceID = 0, @Parameter = '@FinancialsClosedMonth', @ParameterValue = @ParameterValue OUT
SET @FinancialsClosedMonth = CONVERT(int, @ParameterValue)
SELECT [@FinancialsClosedMonth] = @FinancialsClosedMonth

EXEC spGet_SystemParameter @GetVersion = 1
*/

DECLARE
	@SQLStatement nvarchar(max),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2137'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2137' SET @Description = 'Parameter @GetSystemParameterYN added to get a 1x1 result set.'
		
		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @InstanceID IS NULL OR @Parameter IS NULL 
	BEGIN
		PRINT 'Parameter @InstanceID and parameter @Parameter must be set'
		RETURN 
	END

SELECT
	@ParameterValue = ParameterValue
FROM
	SystemParameter
WHERE
	InstanceID = @InstanceID AND
	Parameter = @Parameter

SET @SQLStatement = '
	SELECT
		[' + @Parameter + '] = ' + @ParameterValue

IF @Debug <> 0 
	BEGIN
		PRINT @SQLStatement
		EXEC (@SQLStatement)
	END

IF @GetSystemParameterYN <> 0 
	EXEC (@SQLStatement)

GO
