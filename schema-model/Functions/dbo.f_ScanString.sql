SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_ScanString]
(
	@InstanceID int,
	@VersionID int,
    @InputText nvarchar(max),
	@StringTypeBM int --1 = Code, 2 = Text
)
RETURNS nvarchar(max)
AS
BEGIN
	DECLARE
		@Position int,
		@ReturnStatement nvarchar(max) = ''
	IF @StringTypeBM & 1 > 0 --Code
		BEGIN
			SELECT @Position = CHARINDEX (char(0), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(0), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(1), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(1), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(2), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(2), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(3), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(3), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(4), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(4), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(5), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(5), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(6), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(6), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(7), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(7), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(8), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(8), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(9), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(9), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(10), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(10), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(11), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(11), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(12), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(12), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(13), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(13), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(14), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(14), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(15), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(15), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(16), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(16), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(17), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(17), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(18), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(18), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(19), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(19), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(20), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(20), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(21), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(21), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(22), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(22), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(23), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(23), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(24), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(24), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(25), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(25), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(26), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(26), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(27), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(27), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(28), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(28), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(29), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(29), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(30), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(30), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(31), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(31), Position = ' + CONVERT(nvarchar, @Position) + '; '
		END

	ELSE IF @StringTypeBM & 2 > 0 --Text
		BEGIN
			SELECT @Position = CHARINDEX (char(0), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(0), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(1), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(1), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(2), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(2), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(3), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(3), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(4), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(4), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(5), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(5), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(6), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(6), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(7), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(7), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(8), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(8), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(9), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(9), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(10), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(10), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(11), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(11), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(12), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(12), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(13), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(13), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(14), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(14), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(15), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(15), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(16), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(16), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(17), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(17), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(18), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(18), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(19), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(19), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(20), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(20), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(21), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(21), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(22), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(22), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(23), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(23), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(24), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(24), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(25), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(25), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(26), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(26), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(27), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(27), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(28), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(28), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(29), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(29), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(30), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(30), Position = ' + CONVERT(nvarchar, @Position) + '; '
			SELECT @Position = CHARINDEX (char(31), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + 'InputText = ' + @InputText + ', CharacterCode = char(31), Position = ' + CONVERT(nvarchar, @Position) + '; '
		END

	RETURN @ReturnStatement       
END
GO
