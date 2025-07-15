SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_ReturnSecondString]
/*
Example:
@FullString = 'Segment01=GL_Branch|Segment02=GL_Contact'
@SearchString = 'Segment01'
@Prefix1 = 'JB'
@Prefix2 = 'AA'

Searchstring exists and returns: AA.[GL_Branch]

@FullString = 'Segment01=GL_Branch|Segment02=GL_Contact'
@SearchString = 'Segment03'
@Prefix1 = 'JB'
@Prefix2 = 'AA'

Searchstring does not exist and returns: JB.[Segment03]
*/

(
    @FullString nvarchar(max),
	@SearchString nvarchar(100),
	@Prefix1 nvarchar(10),
	@Prefix2 nvarchar(10)
)
RETURNS nvarchar(100)

AS
BEGIN
	DECLARE @ReturnString nvarchar(100)

	IF CHARINDEX(@SearchString, @FullString) = 0
		SET @ReturnString = @Prefix1 + '.[' + @SearchString + ']'
	ELSE
		SET @ReturnString = @Prefix2 + '.[' + SUBSTRING(@FullString, CHARINDEX('=', @FullString, CHARINDEX(@SearchString, @FullString)) + 1, CHARINDEX('|', @FullString, CHARINDEX(@SearchString, @FullString)) - CHARINDEX('=', @FullString, CHARINDEX(@SearchString, @FullString)) - 1) + ']'
	
	
	RETURN @ReturnString       
END
GO
