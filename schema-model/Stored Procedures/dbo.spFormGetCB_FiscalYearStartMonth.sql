SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFormGetCB_FiscalYearStartMonth] 

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
	[FiscalYearStartMonth] = CONVERT(int, MonthID),
    [Description] = CONVERT(nvarchar, MonthID) + ' - ' + [MonthName]
FROM
	(
	SELECT [MonthID] = 1, [MonthName] = 'Jan'
	UNION SELECT [MonthID] = 2, [MonthName] = 'Feb'
	UNION SELECT [MonthID] = 3, [MonthName] = 'Mar'
	UNION SELECT [MonthID] = 4, [MonthName] = 'Apr'
	UNION SELECT [MonthID] = 5, [MonthName] = 'May'
	UNION SELECT [MonthID] = 6, [MonthName] = 'Jun'
	UNION SELECT [MonthID] = 7, [MonthName] = 'Jul'
	UNION SELECT [MonthID] = 8, [MonthName] = 'Aug'
	UNION SELECT [MonthID] = 9, [MonthName] = 'Sep'
	UNION SELECT [MonthID] = 10, [MonthName] = 'Oct'
	UNION SELECT [MonthID] = 11, [MonthName] = 'Nov'
	UNION SELECT [MonthID] = 12, [MonthName] = 'Dec'
	) sub
ORDER BY
	Sub.[MonthID]






GO
