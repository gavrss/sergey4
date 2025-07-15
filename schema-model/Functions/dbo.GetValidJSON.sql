SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[GetValidJSON]
(
	@text NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
-- select dbo.GetValidJSON('"')

-- https://docs.microsoft.com/en-us/sql/relational-databases/json/how-for-json-escapes-special-characters-and-control-characters-sql-server?view=sql-server-ver15

	SELECT @text = 
					REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( @text, '\', '\\')
															, '"', '\"')
													 , '/', '\/')
											 , CHAR(10), '\n')
									, CHAR(13), '\r')
							, CHAR(9), '\t')
	SELECT @text = REPLACE(REPLACE(@text, CHAR(10), '\u000A'), CHAR(13), '\u000D')
	-- Return the result of the function
	RETURN @text

END
GO
