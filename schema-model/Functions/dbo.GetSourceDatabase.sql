SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[GetSourceDatabase] (@SourceID int)
RETURNS nvarchar(100)
WITH EXECUTE AS CALLER
AS
BEGIN
     DECLARE @SourceDatabase nvarchar(100)

	 SELECT @SourceDatabase = SourceDatabase FROM Source WHERE SourceID = @SourceID

     SET @SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(@SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']'

     RETURN(@SourceDatabase)
END
GO
