SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_GetObjectString]
(
	@PipeObject nvarchar(1000),
	@ObjectType nvarchar(20) -- Dimension, Reference, Property, Hierarchy
)
RETURNS nvarchar(100)
AS
BEGIN

	DECLARE
		@ReturnValue  nvarchar(100),
		@CheckObject nvarchar(1000),
		@Position int = 0,
		@EndPosition int,
		@PositionCheck int

	IF @ObjectType = 'Dimension'
		SET @CheckObject = @PipeObject
	
	--ELSE IF @ObjectType = 'Reference' AND CHARINDEX('#Tuple', @PipeObject) > 0
	--	SET @CheckObject = SUBSTRING(@PipeObject, CHARINDEX('#Tuple=', @PipeObject) + 1, LEN(@PipeObject))

	ELSE IF @ObjectType = 'Property' AND CHARINDEX('.', @PipeObject) > 0
		SET @CheckObject = SUBSTRING(@PipeObject, CHARINDEX('.', @PipeObject) + 1, LEN(@PipeObject))

	ELSE IF @ObjectType = 'Hierarchy' AND CHARINDEX(':', @PipeObject) > 0
		SET @CheckObject = SUBSTRING(@PipeObject, CHARINDEX(':', @PipeObject) + 1, LEN(@PipeObject))

	IF @CheckObject IS NOT NULL
		BEGIN
			--SET @PositionCheck = CHARINDEX('#Tuple', @CheckObject)
			--IF @PositionCheck > 0 AND (@PositionCheck < @Position OR @Position = 0) SET @Position = @PositionCheck

			SET @PositionCheck = CHARINDEX('.', @CheckObject)
			IF @PositionCheck > 0 AND (@PositionCheck < @Position OR @Position = 0) SET @Position = @PositionCheck

			SET @PositionCheck = CHARINDEX(':', @CheckObject)
			IF @PositionCheck > 0 AND (@PositionCheck < @Position OR @Position = 0) SET @Position = @PositionCheck

			SET @EndPosition = CASE WHEN @Position > 0 THEN @Position - 1 ELSE LEN(@CheckObject) END

			SET @ReturnValue = LEFT(@CheckObject, @EndPosition)
		END
	ELSE
		SET @ReturnValue = NULL

	RETURN @ReturnValue       
END
GO
