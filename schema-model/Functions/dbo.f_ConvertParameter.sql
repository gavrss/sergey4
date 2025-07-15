SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_ConvertParameter]
(
    @ParameterString nvarchar(255),
	@ParameterList nvarchar(255)
	
)
RETURNS nvarchar(255)
AS
BEGIN

	DECLARE
		@ParameterString_Converted nvarchar(255),
		@Parameter nvarchar(25),
		@ParameterValue nvarchar(25)

	DECLARE
		@ParameterTable TABLE ([Parameter] nvarchar(25), [ParameterValue] nvarchar(25))

	INSERT INTO @ParameterTable
		(
		[Parameter],
		[ParameterValue]
		)
	SELECT 
		[Parameter] = LEFT(sub.[Value], CHARINDEX('=', sub.[Value]) - 1),
		[ParameterValue] = SUBSTRING(sub.[Value], CHARINDEX('=', sub.[Value]) + 1, LEN(sub.[Value]))
	FROM
		(SELECT [Value] FROM STRING_SPLIT(@ParameterList, '|')) sub

	SET @ParameterString_Converted = @ParameterString

	DECLARE ParameterTable_Cursor CURSOR FOR
			
		SELECT 
			[Parameter],
			[ParameterValue]
		FROM
			@ParameterTable
		ORDER BY
			[Parameter]

		OPEN ParameterTable_Cursor
		FETCH NEXT FROM ParameterTable_Cursor INTO @Parameter, @ParameterValue

		WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @ParameterString_Converted = REPLACE(@ParameterString_Converted, '{' + @Parameter + '}', '''' + @ParameterValue + '''')

				FETCH NEXT FROM ParameterTable_Cursor INTO @Parameter, @ParameterValue
			END

	CLOSE ParameterTable_Cursor
	DEALLOCATE ParameterTable_Cursor

	RETURN @ParameterString_Converted       
END
GO
