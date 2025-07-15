SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[GetStepDescription] (@StepID int)
RETURNS nvarchar(1000)
WITH EXECUTE AS CALLER
AS
BEGIN
	DECLARE
		@StepDescription nvarchar(1000)

	SELECT
		@StepDescription = [Description]
	FROM
		[StepXML]
	WHERE
		StepID = @StepID

	RETURN(@StepDescription)
END
GO
