SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[GetDefaultPropertyYN]
	(
	@DimensionID int,
	@PropertyID int,
	@SourceTypeBM int,
	@ModelBM int
	)
RETURNS bit
WITH EXECUTE AS CALLER
AS
BEGIN

DECLARE
	@Return bit,
	@DynamicYN bit

	SELECT @DynamicYN = DynamicYN FROM Property WHERE PropertyID = @PropertyID

	IF @DynamicYN = 0 
		SET @Return = 1
	ELSE IF @PropertyID < 0 OR @PropertyID > 1000
			SELECT
				@Return = CASE WHEN 
						(
						SELECT
							COUNT(1)
						FROM
							[pcINTEGRATOR].[dbo].[Member_Property_Value] MPV
							INNER JOIN [pcINTEGRATOR].[dbo].Member M ON
									M.DimensionID = MPV.DimensionID AND 
									M.MemberID = MPV.MemberID AND 
									M.SourceTypeBM & @SourceTypeBM > 0 AND
									M.ModelBM & @ModelBM > 0
						WHERE
							MPV.DimensionID = @DimensionID AND
							MPV.PropertyID = @PropertyID
						)
						+
						(
						SELECT
							COUNT(1)
						FROM
							[pcINTEGRATOR].[dbo].[SqlSource_Dimension]
						WHERE
							SequenceBM > 0 AND
							DimensionID = @DimensionID AND
							PropertyID = @PropertyID AND
							SourceTypeBM & @SourceTypeBM > 0 AND
							ModelBM & @ModelBM > 0
						)
					> 0 THEN 0 ELSE 1 END
	ELSE
		SELECT @Return = 0

	RETURN (@Return)
END
GO
