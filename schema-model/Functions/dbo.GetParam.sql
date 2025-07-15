SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[GetParam] (@ParamBM int)

--Used in StepXML

RETURNS nvarchar(1000)
WITH EXECUTE AS CALLER
AS
BEGIN
	DECLARE
		@Param_String nvarchar(1000) = ''

	IF @ParamBM & 1 > 0 
		SET @Param_String = @Param_String + ', @Param_01 OUT'

	IF @ParamBM & 2 > 0 
		SET @Param_String = @Param_String + ', @Param_02 OUT'

	IF @ParamBM & 4 > 0 
		SET @Param_String = @Param_String + ', @Param_03 OUT'

	IF @ParamBM & 8 > 0 
		SET @Param_String = @Param_String + ', @Param_04 OUT'

	IF @ParamBM & 16 > 0 
		SET @Param_String = @Param_String + ', @Param_05 OUT'

	IF @ParamBM & 32 > 0 
		SET @Param_String = @Param_String + ', @Param_06 OUT'

	IF @ParamBM & 64 > 0 
		SET @Param_String = @Param_String + ', @Param_07 OUT'

	IF @ParamBM & 128 > 0 
		SET @Param_String = @Param_String + ', @Param_08 OUT'

	IF @ParamBM & 256 > 0 
		SET @Param_String = @Param_String + ', @Param_09 OUT'

	IF @ParamBM & 512 > 0 
		SET @Param_String = @Param_String + ', @Param_10 OUT'

	RETURN(@Param_String)
END
GO
