SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Translation] 
	(
	@BaseLanguageID int = NULL,
	@TranslatedLanguageID int = NULL,
	@ObjectTypeBM int = 63,
	@BaseWord nvarchar(256) = NULL,
	@TranslatedWord nvarchar(512) = '' OUTPUT,
	@GetVersion bit = 0
	)

--#WITH ENCRYPTION#--
AS

/*
DECLARE
	@TranslatedWord nvarchar(100)
	EXEC [dbo].[spGet_Translation] @BaseLanguageID = 1, @TranslatedLanguageID = 2, @ObjectTypeBM = 2, @BaseWord = 'Account', @TranslatedWord = @TranslatedWord OUTPUT
	SELECT TranslatedWord = @TranslatedWord 

DECLARE
	@TranslatedWord nvarchar(100)
	EXEC [dbo].[spGet_Translation] @BaseLanguageID = 1, @TranslatedLanguageID = 2, @ObjectTypeBM = 2, @BaseWord = '€£Account£€',  @TranslatedWord = @TranslatedWord OUTPUT
	SELECT TranslatedWord = @TranslatedWord 
*/

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2088'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2085' SET @Description = 'Changed design of table Translation.'
		IF @Version = '1.2.2088' SET @Description = 'Changed design of table Translation.'

		SELECT [Version] =  @Version, [Description] = @Description
			RETURN
		END

IF @BaseLanguageID IS NULL OR @BaseWord IS NULL OR @TranslatedLanguageID IS NULL
	BEGIN
		PRINT 'Parameter @BaseLanguageID, parameter @BaseWord and parameter @TranslatedLanguageID be set'
		RETURN 
	END

SET @BaseWord = CASE WHEN SUBSTRING(@BaseWord, 1, 2) = '€£' THEN SUBSTRING(@BaseWord, 3, LEN(@BaseWord) - 4) ELSE @BaseWord END

SELECT
	@TranslatedWord = TranslatedWord
FROM
	Translation
WHERE
	BaseLanguageID = @BaseLanguageID AND
	TranslatedLanguageID = @TranslatedLanguageID AND
	ObjectTypeBM & @ObjectTypeBM > 0 AND
	BaseWord = @BaseWord
		
IF @TranslatedWord IS NULL
	BEGIN
		IF SUBSTRING(@BaseWord, 1, 1) <> '@'
			BEGIN
				SELECT
					@ObjectTypeBM = ISNULL(ObjectTypeBM, @ObjectTypeBM),
					@TranslatedWord = TranslatedWord
				FROM
					Translation
				WHERE
					BaseLanguageID = @BaseLanguageID AND
					TranslatedLanguageID = @BaseLanguageID AND
					ObjectTypeBM & @ObjectTypeBM > 0 AND
					BaseWord = @BaseWord

				SELECT @TranslatedWord = ISNULL(@TranslatedWord, @BaseWord)

				INSERT INTO Translation
					(
					BaseLanguageID,
					TranslatedLanguageID,
					ObjectTypeBM,
					BaseWord,
					TranslatedWord
					)
				SELECT
					BaseLanguageID = @BaseLanguageID,
					TranslatedLanguageID = @TranslatedLanguageID,
					ObjectTypeBM = @ObjectTypeBM,
					BaseWord = @BaseWord,
					TranslatedWord = @TranslatedWord
			END
		ELSE
			SET @TranslatedWord = @BaseWord
	END


















GO
