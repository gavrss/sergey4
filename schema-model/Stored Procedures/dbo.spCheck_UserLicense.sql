SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_UserLicense]

@InstanceID int = NULL,
@UserLicenseTypeID int = NULL,
@NoOfUsers int = 0 OUT,
@ValidYN bit = 0 OUT,
@GetVersion bit = 0,
@Debug int = 0

--EXEC [spCheck_UserLicense] @GetVersion = 1
--EXEC [spCheck_UserLicense]

/*
DECLARE @ValidYN bit, @NoOfUsers int = 1
EXEC [spCheck_UserLicense] @InstanceID = 400, @UserLicenseTypeID = -1, @ValidYN = @ValidYN OUT, @NoOfUsers = @NoOfUsers OUT, @Debug = 42
SELECT ValidYN = @ValidYN, NoOfUsers = @NoOfUsers
*/

--#WITH ENCRYPTION#--

AS

DECLARE
	@Nyu nvarchar(50),
	@ProductKey nvarchar(17),
	@Step int = 0,
	@CharacterStep int = 0,
	@ASCII int,
	@Character nchar(1),
	@NvalueString nvarchar(20),
	@Nvalue float,
	@FactorString nvarchar(20),
	@Factor float,
	@StartPos int,
	@Length int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.1.2124' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2134' SET @Description = 'Handle 0 users.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @InstanceID IS NULL OR @UserLicenseTypeID IS NULL
	BEGIN
		PRINT 'Parameter @InstanceID and parameter @UserLicenseTypeID must be set'
		RETURN 
	END

--Set procedure variables
	SET @NoOfUsers = ISNULL(@NoOfUsers, 0)

	SELECT
		@ProductKey = I.ProductKey, 
		@Nyu = I.Nyu
	FROM
		Instance I
	WHERE
		I.InstanceID = @InstanceID

	IF @Debug = 42 SELECT ProductKey = @ProductKey, Nyu = @Nyu

--Check string format
	IF LEN(@Nyu) - LEN(REPLACE(@Nyu, '|', '')) <> 3 OR @Nyu IS NULL
		GOTO ERRORPOINT

	WHILE @Step < 17 AND @CharacterStep < 2
		BEGIN
			SET @Step = @Step + 1
			SET @Character = SUBSTRING(@ProductKey, @Step, 1)
			IF @Character NOT LIKE '%[^a-Z]%'
				BEGIN
					SET @CharacterStep = @CharacterStep + 1
					IF @CharacterStep = 2 SET @ASCII = ASCII(@Character)
				END
			IF @Debug = 42 SELECT [Character] = @Character, [ASCII] = @ASCII
		END

	SET @FactorString = SUBSTRING(@Nyu, 1, CHARINDEX ('|', @Nyu, 1) - 1)
	IF ISNUMERIC(@FactorString) = 0
		GOTO ERRORPOINT
	ELSE
		IF FLOOR((FLOOR(ABS(@FactorString)))/ABS(@FactorString)) = 0
			GOTO ERRORPOINT
		ELSE
			SET @Factor = CONVERT(int, @FactorString)

	IF @Factor <> @ASCII
		GOTO ERRORPOINT

--Get value
	IF @UserLicenseTypeID = -1
		SELECT @StartPos = CHARINDEX ('|', @Nyu, CHARINDEX ('|', @Nyu, CHARINDEX ('|', @Nyu, 1) + 1) + 1) + 1, @Length = LEN(@Nyu) - CHARINDEX ('|', @Nyu, CHARINDEX ('|', @Nyu, CHARINDEX ('|', @Nyu, 1) + 1) + 1)
	ELSE IF @UserLicenseTypeID = -2
		SELECT @StartPos = CHARINDEX ('|', @Nyu, CHARINDEX ('|', @Nyu, 1) + 1) + 1, @Length = CHARINDEX ('|', @Nyu, CHARINDEX ('|', @Nyu, CHARINDEX ('|', @Nyu, 1) + 1) + 1) - CHARINDEX ('|', @Nyu, CHARINDEX ('|', @Nyu, 1) + 1) - 1
	ELSE IF @UserLicenseTypeID = -3
		SELECT @StartPos = CHARINDEX ('|', @Nyu, 1) + 1, @Length = CHARINDEX ('|', @Nyu, CHARINDEX ('|', @Nyu, 1) + 1) - CHARINDEX ('|', @Nyu, 1) - 1

	SELECT @NvalueString = SUBSTRING(@Nyu, @StartPos, @Length)

	IF ISNUMERIC(@NvalueString) = 0 
		GOTO ERRORPOINT
	ELSE
		IF ABS(@NvalueString) = 0
			GOTO ERRORPOINT
		ELSE IF FLOOR((FLOOR(ABS(@NvalueString)))/ABS(@NvalueString)) = 0
			GOTO ERRORPOINT
		ELSE
			SET @Nvalue = CONVERT(int, @NvalueString)

	IF @Debug = 42 SELECT Nyu = @Nyu, UserLicenseTypeID = @UserLicenseTypeID, StartPos = @StartPos, [Length] = @Length, Nvalue = @Nvalue, Factor = @Factor

--Check and convert value
	IF @Nvalue = 0
		GOTO ERRORPOINT
	ELSE IF FLOOR((FLOOR(ABS(@Nvalue / @UserLicenseTypeID / @Factor)))/ABS(@Nvalue / @UserLicenseTypeID / @Factor)) = 0
		GOTO ERRORPOINT
	ELSE
		SET @Nvalue = @Nvalue / @UserLicenseTypeID / @Factor

	IF @Debug = 42 SELECT Nvalue = @Nvalue, NoOfUsers =  @NoOfUsers

--Set return values
	SET @ValidYN = CASE WHEN @Nvalue >= @NoOfUsers THEN 1 ELSE 0 END
	SET @NoOfUsers = @Nvalue
	RETURN

--Errorpoint
	ERRORPOINT:
		SELECT @ValidYN = 0, @NoOfUsers = 0


GO
