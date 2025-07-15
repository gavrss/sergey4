SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_GetDefaultValue]
(
	@TableName nvarchar(100),
	@ColumnName nvarchar(100)
)
RETURNS nvarchar(100)
BEGIN

	DECLARE
		@DefaultValue nvarchar(100)

	SELECT 
		@DefaultValue = df.[definition]
	FROM 
		pcINTEGRATOR_Data.sys.default_constraints df
		INNER JOIN pcINTEGRATOR_Data.sys.tables t ON df.[parent_object_id] = t.[object_id] AND t.[name] = @TableName
		INNER JOIN pcINTEGRATOR_Data.sys.columns c ON c.[object_id] = df.[parent_object_id] AND df.[parent_column_id] = c.[column_id] AND c.[name] = @ColumnName

	SET	@DefaultValue = REPLACE(REPLACE(REPLACE(REPLACE(@DefaultValue, '(N''', ''), ''')', ''), '((', ''), '))', '')

	RETURN @DefaultValue       
END
GO
