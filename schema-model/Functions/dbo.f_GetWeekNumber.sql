SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_GetWeekNumber]
(
    @Date datetime
--	@DateFirst int
)
RETURNS int
AS
BEGIN

	DECLARE
		@StartFirstFullWeek int,
		@StartDate datetime,
		@Year int,
		@WeekNumber int,
		@FirstDatePY datetime

	DECLARE
		@DateTable TABLE ([Date] datetime)

--	SET DATEFIRST @DateFirst
	SET @Year = YEAR(@Date)
	SET @StartDate = CONVERT(DATETIME, CONVERT(NVARCHAR(10), @Year) + '-01-01')

	INSERT INTO @DateTable ([Date])
	SELECT [Date] FROM
		(
		SELECT [Date] = @StartDate
		UNION SELECT [Date] = DATEADD(DAY, 1, @StartDate)
		UNION SELECT [Date] = DATEADD(DAY, 2, @StartDate)
		UNION SELECT [Date] = DATEADD(DAY, 3, @StartDate)
		UNION SELECT [Date] = DATEADD(DAY, 4, @StartDate)
		UNION SELECT [Date] = DATEADD(DAY, 5, @StartDate)
		UNION SELECT [Date] = DATEADD(DAY, 6, @StartDate)
		) sub

	SELECT
		@StartFirstFullWeek = DATEPART(dy, [Date])
	FROM
		@DateTable
	WHERE
		DATEPART(WEEKDAY, [Date]) = 1

	SET @WeekNumber = (7 + (DATEPART(dy, @Date) - @StartFirstFullWeek)) / 7

	IF @WeekNumber = 0
		BEGIN
			SET @Year = @Year - 1
			SET @StartDate = CONVERT(DATETIME, CONVERT(NVARCHAR(10), @Year) + '-01-01')
			DELETE @DateTable		

			INSERT INTO @DateTable ([Date])
			SELECT [Date] FROM
				(
				SELECT [Date] = @StartDate
				UNION SELECT [Date] = DATEADD(DAY, 1, @StartDate)
				UNION SELECT [Date] = DATEADD(DAY, 2, @StartDate)
				UNION SELECT [Date] = DATEADD(DAY, 3, @StartDate)
				UNION SELECT [Date] = DATEADD(DAY, 4, @StartDate)
				UNION SELECT [Date] = DATEADD(DAY, 5, @StartDate)
				UNION SELECT [Date] = DATEADD(DAY, 6, @StartDate)
				) sub

			SELECT
				@FirstDatePY = [Date]
			FROM
				@DateTable
			WHERE
				DATEPART(WEEKDAY, [Date]) = 1

			SET @WeekNumber = (7 + DATEDIFF(DAY, @FirstDatePY, @Date)) / 7
		END

	RETURN @WeekNumber       
END
GO
