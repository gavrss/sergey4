SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[GetTime_MemberKey] (@LiveYN bit, @ClosedMonth int, @TimeFrom int, @TimeTo int, @TimeOffsetFrom int, @TimeOffsetTo int)

RETURNS nvarchar(4000)
WITH EXECUTE AS CALLER
AS
BEGIN
	DECLARE
		@Time_MemberKey nvarchar(4000),
		@YearFrom int,
		@YearTo int,
		@ClosedMonth_Counter int

--Create @Month table
		DECLARE @Month table 
		   ( 
		   [Counter] int IDENTITY(1, 1), 
		   [Time] int
		   )

--Calculate @YearFrom and @YearTo
		SELECT
			@YearFrom = CASE WHEN @LiveYN = 0 THEN @TimeFrom / 100 ELSE @ClosedMonth / 100 + @TimeOffsetFrom / 12 - 1 END,
			@YearTo = CASE WHEN @LiveYN = 0 THEN @TimeTo / 100 ELSE @ClosedMonth / 100 + @TimeOffsetTo / 12 + 1 END

--Fill @Month table
		INSERT INTO @Month
			(
			[Time]
			)
		SELECT DISTINCT TOP 1000000
			[Time] = Y.Y * 100 + M.M
		FROM
			(
				SELECT
					[Y] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2,
					Digit D3,
					Digit D4
				WHERE
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @YearFrom AND @YearTo
			) Y,
			(
				SELECT
					[M] = D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2
				WHERE
					D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
			) M 
		ORDER BY
			Y.Y * 100 + M.M

--Calculate @TimeFrom and @TimeTo
		IF @LiveYN <> 0
			BEGIN
				SELECT @ClosedMonth_Counter = [Counter] FROM @Month WHERE [Time] = @ClosedMonth
				SELECT @TimeFrom = [Time] FROM @Month WHERE [Counter] = @ClosedMonth_Counter + @TimeOffsetFrom
				SELECT @TimeTo = [Time] FROM @Month WHERE [Counter] = @ClosedMonth_Counter + @TimeOffsetTo
			END

--Calculate @Time_MemberKey
		SET @Time_MemberKey = ''
		SELECT @Time_MemberKey = @Time_MemberKey + CONVERT(nvarchar(6), [Time]) + ',' FROM @Month WHERE [Time] BETWEEN @TimeFrom AND @TimeTo ORDER BY [Time]
		SET @Time_MemberKey = LEFT(@Time_MemberKey, LEN(@Time_MemberKey) - 1)

	RETURN(@Time_MemberKey)
END
GO
