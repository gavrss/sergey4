SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_ReplaceString]
(
	@InstanceID int,
	@VersionID int,
    @InputText nvarchar(max),
	@StringTypeBM int --1 = Code, 2 = Text
)
RETURNS nvarchar(max)
WITH INLINE = OFF
AS
BEGIN
	IF @StringTypeBM & 1 > 0 --Code
		BEGIN
			SET @InputText = REPLACE(@InputText, char(0), '') --Char(0) NULL --> Blank
			SET @InputText = REPLACE(@InputText, char(1), '') --Char(1) Start of heading --> Blank
			SET @InputText = REPLACE(@InputText, char(2), '') --Char(2) Start of text --> Blank
			SET @InputText = REPLACE(@InputText, char(3), '') --Char(3) End of text --> Blank
			SET @InputText = REPLACE(@InputText, char(4), '') --Char(4) End of transmission --> Blank
			SET @InputText = REPLACE(@InputText, char(5), '') --Char(5) Enquiry --> Blank
			SET @InputText = REPLACE(@InputText, char(6), '') --Char(6) Acknowledge --> Blank
			SET @InputText = REPLACE(@InputText, char(7), '') --Char(7) Bell --> Blank
			SET @InputText = REPLACE(@InputText, char(8), '') --Char(8) Backspace --> Blank
			SET @InputText = REPLACE(@InputText, char(9), '') --Char(9) Horizontal tab --> Blank
			SET @InputText = REPLACE(@InputText, char(10), '') --Char(10) NL Line feed --> Blank
			SET @InputText = REPLACE(@InputText, char(11), '') --Char(11) Vertical tab --> Blank
			SET @InputText = REPLACE(@InputText, char(12), '') --Char(12) NP form feed --> Blank
			SET @InputText = REPLACE(@InputText, char(13), '_') --Char(13) Carriage return --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(14), '') --Char(14) Shift out --> Blank
			SET @InputText = REPLACE(@InputText, char(15), '') --Char(15) Shift in --> Blank
			SET @InputText = REPLACE(@InputText, char(16), '') --Char(16) Data link escape --> Blank
			SET @InputText = REPLACE(@InputText, char(17), '') --Char(17) Device control 1 --> Blank
			SET @InputText = REPLACE(@InputText, char(18), '') --Char(18) Device control 2 --> Blank
			SET @InputText = REPLACE(@InputText, char(19), '') --Char(19) Device control 3 --> Blank
			SET @InputText = REPLACE(@InputText, char(20), '') --Char(20) Device control 4 --> Blank
			SET @InputText = REPLACE(@InputText, char(21), '') --Char(21) Negative acknowledge --> Blank
			SET @InputText = REPLACE(@InputText, char(22), '') --Char(22) Synchronous idle --> Blank
			SET @InputText = REPLACE(@InputText, char(23), '') --Char(23) End of trans --> Blank
			SET @InputText = REPLACE(@InputText, char(24), '') --Char(24) Cancel --> Blank
			SET @InputText = REPLACE(@InputText, char(25), '') --Char(25) End of medium --> Blank
			SET @InputText = REPLACE(@InputText, char(26), '') --Char(26) Substitute --> Blank
			SET @InputText = REPLACE(@InputText, char(27), '') --Char(27) Escape --> Blank
			SET @InputText = REPLACE(@InputText, char(28), '') --Char(28) File separator --> Blank
			SET @InputText = REPLACE(@InputText, char(29), '') --Char(29) Group separator --> Blank
			SET @InputText = REPLACE(@InputText, char(30), '') --Char(30) Record separator --> Blank
			SET @InputText = REPLACE(@InputText, char(31), '') --Char(31) Unit separator --> Blank
			SET @InputText = REPLACE(@InputText, char(32), '_') --Char(32), ' ', Space --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(33), '') --Char(33), '!', Exclamation mark --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(34), '') --Char(34), '"', Double quotes --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(35), '') --Char(35), '#', Number --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(36), '') --Char(36), '$', Dollar --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(37), '') --Char(37), '%', Percent --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(38), '_') --Char(38), '&', Ampersand --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(39), '') --Char(39), ''', Single quote --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(40), '') --Char(40), '(', Open parenthesis --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(41), '') --Char(41), ')', Close parenthesis --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(42), '') --Char(42), '*', Asterisk --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(43), '_') --Char(43), '+', Plus --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(44), '') --Char(44), ',', Comma --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(45), '_') --Char(45), '-', Dash --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(46), '_') --Char(46), '.', Dot --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(47), '_') --Char(47), '/', Slash --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(58), '') --Char(58), ':', Colon --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(60), '') --Char(60), '<', Less than --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(61), '') --Char(61), '=', Equals --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(62), '') --Char(62), '>', Greater than --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(63), '_') --Char(63), '?', Question mark --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(64), '_') --Char(64), '@', At symbol --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(91), '') --Char(91), '[', Opening bracket --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(92), '_') --Char(92), '\', Backslash --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(93), '') --Char(93), ']', Closing bracket --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(94), '') --Char(94), '^', Caret - circumflex --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(96), '') --Char(96), '`', Grave accent --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(123), '') --Char(123), '{', Opening brace --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(124), '') --Char(124), '|', Vertical bar --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(125), '') --Char(125), '}', Closing brace --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(126), '') --Char(126), '~', Equivalency sign - tilde --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(145), '') --Char(145), '‘', Left single quotation mark --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(146), '') --Char(146), '’', Right single quotation mark --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(147), '') --Char(147), '“', Left double quotation mark --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(148), '') --Char(148), '”', Right double quotation mark --> Blank (Code)
			SET @InputText = REPLACE(@InputText, char(150), '_') --Char(150), '–', Dash --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(151), '_') --Char(151), '—', Dash --> Underscore (Code)
			SET @InputText = REPLACE(@InputText, char(180), '') --Char(180), '´', Acute accent --> Blank (Code)
		END

	ELSE IF @StringTypeBM & 2 > 0 --Text
		BEGIN
			SET @InputText = REPLACE(@InputText, char(0), '') --Char(0) NULL --> Blank
			SET @InputText = REPLACE(@InputText, char(1), '') --Char(1) Start of heading --> Blank
			SET @InputText = REPLACE(@InputText, char(2), '') --Char(2) Start of text --> Blank
			SET @InputText = REPLACE(@InputText, char(3), '') --Char(3) End of text --> Blank
			SET @InputText = REPLACE(@InputText, char(4), '') --Char(4) End of transmission --> Blank
			SET @InputText = REPLACE(@InputText, char(5), '') --Char(5) Enquiry --> Blank
			SET @InputText = REPLACE(@InputText, char(6), '') --Char(6) Acknowledge --> Blank
			SET @InputText = REPLACE(@InputText, char(7), '') --Char(7) Bell --> Blank
			SET @InputText = REPLACE(@InputText, char(8), '') --Char(8) Backspace --> Blank
			SET @InputText = REPLACE(@InputText, char(9), '') --Char(9) Horizontal tab --> Blank
			SET @InputText = REPLACE(@InputText, char(10), '') --Char(10) NL Line feed --> Blank
			SET @InputText = REPLACE(@InputText, char(11), '') --Char(11) Vertical tab --> Blank
			SET @InputText = REPLACE(@InputText, char(12), '') --Char(12) NP form feed --> Blank
			SET @InputText = REPLACE(@InputText, char(13), ' ') --Char(13) Carriage return --> Space (Text)
			SET @InputText = REPLACE(@InputText, char(14), '') --Char(14) Shift out --> Blank
			SET @InputText = REPLACE(@InputText, char(15), '') --Char(15) Shift in --> Blank
			SET @InputText = REPLACE(@InputText, char(16), '') --Char(16) Data link escape --> Blank
			SET @InputText = REPLACE(@InputText, char(17), '') --Char(17) Device control 1 --> Blank
			SET @InputText = REPLACE(@InputText, char(18), '') --Char(18) Device control 2 --> Blank
			SET @InputText = REPLACE(@InputText, char(19), '') --Char(19) Device control 3 --> Blank
			SET @InputText = REPLACE(@InputText, char(20), '') --Char(20) Device control 4 --> Blank
			SET @InputText = REPLACE(@InputText, char(21), '') --Char(21) Negative acknowledge --> Blank
			SET @InputText = REPLACE(@InputText, char(22), '') --Char(22) Synchronous idle --> Blank
			SET @InputText = REPLACE(@InputText, char(23), '') --Char(23) End of trans --> Blank
			SET @InputText = REPLACE(@InputText, char(24), '') --Char(24) Cancel --> Blank
			SET @InputText = REPLACE(@InputText, char(25), '') --Char(25) End of medium --> Blank
			SET @InputText = REPLACE(@InputText, char(26), '') --Char(26) Substitute --> Blank
			SET @InputText = REPLACE(@InputText, char(27), '') --Char(27) Escape --> Blank
			SET @InputText = REPLACE(@InputText, char(28), '') --Char(28) File separator --> Blank
			SET @InputText = REPLACE(@InputText, char(29), '') --Char(29) Group separator --> Blank
			SET @InputText = REPLACE(@InputText, char(30), '') --Char(30) Record separator --> Blank
			SET @InputText = REPLACE(@InputText, char(31), '') --Char(31) Unit separator --> Blank
		END

	RETURN @InputText       
END
GO
