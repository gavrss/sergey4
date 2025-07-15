SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spReplace_CodeWord]

@ApplicationID int = NULL,
@ObjectTypeBM int = NULL, --0 = Search in Translation table, 1, 2, 4 = search in MappedObject
@TranslatedLanguageID int = NULL,
@StringIn nvarchar(max) = NULL,
@StringOut nvarchar(max) = NULL OUTPUT,
@GetVersion bit = 0,
@Debug bit = 0

--#WITH ENCRYPTION#--
AS

SET ANSI_WARNINGS OFF

/*
DECLARE
	@SQLStatement nvarchar(max) = 'S_DS_€£Account£€.Label €£TimeDataView£€'
	EXEC spReplace_CodeWord @ApplicationID = 400, @ObjectTypeBM = 2, @TranslatedLanguageID = 1, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT, @Debug = 1
	SELECT SQLStatement = @SQLStatement

DECLARE
	@SQLStatement nvarchar(max) = 'SELECT [Account] = [Label], [TimeBalance] = [TimeBalance] FROM pcDATA_DevTest44..S_DS_€£Account£€'
	EXEC spReplace_CodeWord @ApplicationID = 400, @ObjectTypeBM = 2, @TranslatedLanguageID = 1, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT, @Debug = 1
	SELECT SQLStatement = @SQLStatement

EXEC spReplace_CodeWord @GetVersion = 1

EXEC spReplace_CodeWord
*/

DECLARE
	@LanguageID int = NULL,
	@ETLDatabase nvarchar(100),
	@StartingPoint int = 1,
	@EndingPoint int,
	@BaseWord nvarchar(100),
	@TranslatedWord nvarchar(100),
	@SQLStatement nvarchar(max),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2088'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2085' SET @Description = 'Procedure created'
		IF @Version = '1.3.2088' SET @Description = 'Changed reference to spGet_Translation'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL OR @ObjectTypeBM IS NULL OR @TranslatedLanguageID IS NULL OR @StringIn IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID, parameter @ObjectTypeBM, parameter @TranslatedLanguageID and parameter @StringIn must be set'
		RETURN 
	END

--Set procedure variables
	SELECT 
		@LanguageID = A.LanguageID,
		@ETLDatabase = A.ETLDatabase
	FROM
		[Application] A
	WHERE
		A.[ApplicationID] = @ApplicationID

	SELECT @StringOut = @StringIn

	IF @Debug <> 0 SELECT LanguageID = @LanguageID, ETLDatabase = @ETLDatabase, StringIn = @StringIn

WHILE @StartingPoint > 0
	BEGIN
		SELECT @StartingPoint = CHARINDEX('€£', @StringOut, 1) 
		SELECT @EndingPoint = CHARINDEX('£€', @StringOut, @StartingPoint + 1)
		IF @Debug <> 0 SELECT StartingPoint = @StartingPoint, EndingPoint = @EndingPoint
		IF @StartingPoint > 0 AND @EndingPoint - @StartingPoint < 100
			BEGIN
				SELECT @BaseWord = SUBSTRING(@StringOut, @StartingPoint, @EndingPoint - @StartingPoint + 2), @TranslatedWord = NULL

				IF @TranslatedLanguageID = @LanguageID AND @ObjectTypeBM & 7 > 0
					BEGIN
						CREATE TABLE #TranslatedWord (TranslatedWord nvarchar(100))
						SET @SQLStatement = '
						INSERT INTO #TranslatedWord
							(TranslatedWord)
						SELECT
							TranslatedWord = MIN(MappedOBjectName)
						FROM
							' + @ETLDatabase + '..MappedObject MO
						WHERE
							ObjectName = SUBSTRING(''' + @BaseWord + ''', 3, LEN(''' + @BaseWord + ''') - 4) AND
							MO.ObjectTypeBM & ' + CONVERT(nvarchar(10), @ObjectTypeBM) + ' > 0'

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
						SELECT @TranslatedWord = TranslatedWord FROM #TranslatedWord
						DROP TABLE #TranslatedWord

						IF @TranslatedWord IS NULL
							EXEC [spGet_Translation] @BaseLanguageID = 1, @TranslatedLanguageID = @TranslatedLanguageID, @ObjectTypeBM = @ObjectTypeBM, @BaseWord = @BaseWord, @TranslatedWord = @TranslatedWord OUTPUT
					END
				ELSE
					EXEC [spGet_Translation] @BaseLanguageID = 1, @TranslatedLanguageID = @TranslatedLanguageID, @ObjectTypeBM = @ObjectTypeBM, @BaseWord = @BaseWord,  @TranslatedWord = @TranslatedWord OUTPUT

				IF @Debug <> 0 SELECT BaseWord = @BaseWord, TranslatedWord = @TranslatedWord, StringOut = @StringOut
				SELECT @StringOut = REPLACE(@StringOut, @BaseWord, @TranslatedWord)
				IF @Debug <> 0 SELECT BaseWord = @BaseWord, TranslatedWord = @TranslatedWord, StringOut = @StringOut
			END
	END





GO
