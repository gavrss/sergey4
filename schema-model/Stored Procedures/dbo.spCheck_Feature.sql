SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_Feature]

@ModelID int = NULL,
@InstanceID int = NULL,
@FeatureID int = NULL,
@ValidYN bit = 0 OUT,
@ReturnResultYN bit = 0,
@GetVersion bit = 0,
@Debug int = 0

/*
DECLARE @ValidYN bit
EXEC spCheck_Feature @ModelID = 607, @ValidYN = @ValidYN OUT, @Debug = 42
SELECT ValidYN = @ValidYN

EXEC spCheck_Feature @ModelID = 607

DECLARE @ValidYN bit
EXEC spCheck_Feature @InstanceID = 400, @FeatureID = 4096, @ValidYN = @ValidYN OUT--, @Debug = 42
SELECT ValidYN = @ValidYN

EXEC spCheck_Feature @InstanceID = 400, @FeatureID = 4096
*/

--#WITH ENCRYPTION#--

AS

DECLARE
	@BaseModelID int,
	@Nyc int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2135'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2107' SET @Description = 'Procedure created.'
		IF @Version = '1.3.1.2124' SET @Description = 'Changed debug handling.'
		IF @Version = '1.4.0.2134' SET @Description = 'Possibility to check license for any feature.'
		IF @Version = '1.4.0.2135' SET @Description = 'Added @ReturnResultYN parameter, default false.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ModelID IS NULL AND (@FeatureID IS NULL OR @InstanceID IS NULL)
	BEGIN
		PRINT 'Parameter @ModelID or parameter @InstanceID and @FeatureID must be set'
		RETURN 
	END

--Create temp tables
	CREATE TABLE #Valid (ValidYN int, FeatureBM int)
	INSERT #Valid (ValidYN, FeatureBM) VALUES (0, 63)
	INSERT #Valid (ValidYN, FeatureBM) VALUES (1, 8128)

	IF @Debug = 42 SELECT TempTable = '#Valid', * FROM #Valid

--Set @ValidYN
	SET @ValidYN = 1

IF @ModelID IS NOT NULL
	BEGIN
		SELECT 
			@Nyc = I.Nyc,
			@BaseModelID = BM.ModelID
		FROM
			Instance I
			INNER JOIN [Application] A ON A.InstanceID = I.InstanceID AND A.SelectYN <> 0
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.ModelID = @ModelID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.SelectYN <> 0

		IF @Debug = 42 SELECT Nyc = @Nyc, BaseModelID = @BaseModelID



		CREATE TABLE #Model (ModelID int, FeatureBM int)
		INSERT #Model (ModelID, FeatureBM) VALUES (-14, 128)
		INSERT #Model (ModelID, FeatureBM) VALUES (-13, 512)
		INSERT #Model (ModelID, FeatureBM) VALUES (-11, 128)
		INSERT #Model (ModelID, FeatureBM) VALUES (-10, 128)
		INSERT #Model (ModelID, FeatureBM) VALUES (-8, 64)
		INSERT #Model (ModelID, FeatureBM) VALUES (-7, 64)
		INSERT #Model (ModelID, FeatureBM) VALUES (-4, 256)
		INSERT #Model (ModelID, FeatureBM) VALUES (-3, 64)

		IF @Debug = 42 SELECT TempTable = '#Model', * FROM #Model

		SELECT @ValidYN = @ValidYN * COUNT(1) FROM #Model WHERE ModelID = @BaseModelID AND FeatureBM & @Nyc > 0
		IF @Debug = 42 SELECT ValidModel = COUNT(1) FROM #Model WHERE ModelID = @BaseModelID AND FeatureBM & @Nyc > 0
	
		DROP TABLE #Model
	END

IF @FeatureID IS NOT NULL AND @InstanceID IS NOT NULL
	BEGIN
		SELECT 
			@Nyc = I.Nyc
		FROM
			Instance I
		WHERE
			I.InstanceID = @InstanceID AND
			I.SelectYN <> 0

		SELECT @ValidYN = @ValidYN * CASE WHEN @FeatureID & @Nyc > 0 THEN 1 ELSE 0 END
		IF @Debug = 42 SELECT ValidFeature = CASE WHEN @FeatureID & @Nyc > 0 THEN 1 ELSE 0 END
	END

	SELECT @ValidYN = @ValidYN * COUNT(1) FROM #Valid WHERE ValidYN <> 0 AND FeatureBM & @Nyc > 0
	SELECT @ValidYN = @ValidYN * COUNT(1) FROM #Valid WHERE ValidYN = 0 AND FeatureBM & @Nyc = 0


	IF @Debug = 42 
		BEGIN
			SELECT ValidNyc = COUNT(1) FROM #Valid WHERE ValidYN <> 0 AND FeatureBM & @Nyc > 0
			SELECT InvalidNyc = COUNT(1) FROM #Valid WHERE ValidYN = 0 AND FeatureBM & @Nyc = 0
		END

--Drop temp tables
	DROP TABLE #Valid

--Return result
	IF @ReturnResultYN <> 0
		SELECT ValidYN = @ValidYN
GO
