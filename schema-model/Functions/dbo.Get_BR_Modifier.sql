SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[Get_BR_Modifier] (@ModifierID int, @Basevalue int, @Parameter int)

RETURNS int
WITH EXECUTE AS CALLER
AS
BEGIN

	DECLARE @Return_Value int

	IF @ModifierID = 30
		BEGIN




	DECLARE
		@Year int,
		@YearFrom int,
		@YearTo int

--Create @Month table
		DECLARE @Month table 
		   ( 
		   [Counter] int IDENTITY(1, 1), 
		   [Time] int
		   )

--Calculate @YearFrom and @YearTo
		SELECT
			@Year = @Basevalue / 100

		SELECT
			@YearFrom = @Year + (@Parameter / 12) - 1,
			@YearTo = @Year + (@Parameter / 12) + 1

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

--Calculate @Return_Value
		SELECT @Return_Value = [Time] FROM @Month WHERE [Counter] = (SELECT [Counter] + @Parameter FROM @Month WHERE [Time] = @Basevalue)

		END
	RETURN(@Return_Value)
END
GO
