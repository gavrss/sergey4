SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_GetSBZ2]
(
    @DimensionID int,
	@NodeTypeBM int,
	@Label nvarchar(255)
)
RETURNS bit
AS
BEGIN

	DECLARE
		@SBZ bit

	IF @NodeTypeBM & 10 > 0  --Parent or calculated
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
