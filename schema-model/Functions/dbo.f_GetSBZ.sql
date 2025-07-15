SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_GetSBZ]
(
    @DimensionID int,
	@RNodeType nvarchar(2),
	@Label nvarchar(255)
)
RETURNS bit
AS
BEGIN

	DECLARE
		@SBZ bit

	IF @RNodeType <> 'L'  --Not Leaf
		SET @SBZ = 1
	ELSE
		BEGIN
			IF (SELECT COUNT(1) FROM pcINTEGRATOR..Dimension WHERE DimensionID = @DimensionID AND HiddenMember LIKE '%|' + @Label + '|%' AND NOT (@DimensionID = -8 AND @Label = 'RAWDATA')) > 0 --HiddenMember
				SET @SBZ = 1
			ELSE --Not Hidden Leaf
				SET @SBZ = 0
		END

	RETURN @SBZ       
END
GO
