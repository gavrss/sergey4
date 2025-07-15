SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_spFormGet_MappedObject] 

	@ApplicationID int = NULL,
	@Debug bit = 0,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@ProcedureName nvarchar(100) = NULL OUT,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_spFormGet_MappedObject] @ApplicationID = 400, @Debug = true 
--EXEC [spCreate_spFormGet_MappedObject] @ApplicationID = 600, @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SQLStatement_ModelBM nvarchar(max) = '',
	@Action nvarchar(10),
	@ETLDatabase nvarchar(50),
	@ModelID int,
	@ModelID_String nvarchar(10),
	@ModelBM_String nvarchar(10),
	@SourceTypeBM int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2075' SET @Description = 'Procedure created.'
		IF @Version = '1.3.2079' SET @Description = 'Test on VisibilityLevelBM.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2104' SET @Description = 'Changed logic for Financial segments that are not selected'
		IF @Version = '1.4.0.2134' SET @Description = 'Check SourceTypeBM for available dimensions'
		
		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL 
	BEGIN
		PRINT 'Parameter @ApplicationID must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT
			@ETLDatabase = A.ETLDatabase
		FROM
			[Application] A 
		WHERE
			A.ApplicationID = @ApplicationID AND
			A.SelectYN <> 0

		SELECT
			@SourceTypeBM = SUM(sub.SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				ST.SourceTypeBM
			FROM
				[Source] S 
				INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			WHERE
				S.SelectYN <> 0
			) sub

	IF @Debug <> 0 SELECT SourceTypeBM = @SourceTypeBM

	SET @Step = 'Create Temp tables'
		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #Model
			(
			ModelID int IDENTITY(1,1) NOT NULL,
			ModelBM int
			)

	SET @Step = 'Fill Temp table #Model'
		SET @SQLStatement = '
			INSERT INTO #Model
				(
				ModelBM
				)
			SELECT 
				ModelBM
			FROM
				' + @ETLDatabase + '..MappedObject
			WHERE
				ObjectTypeBM & 1 > 0 AND
				DimensionTypeID = -2 AND
				SelectYN <> 0
			ORDER BY
				ModelBM'

			IF @Debug <> 0 PRINT @SQLStatement

			EXEC (@SQLStatement)

	SET @Step = 'Determine CREATE or ALTER'
		SET @ProcedureName = 'spFormGet_MappedObject'
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
		SELECT @Action = [Action] FROM #Action

	SET @Step = 'Set ModelBM'
		DECLARE ModelBM_Cursor CURSOR FOR
			SELECT DISTINCT
				ModelID,
				ModelID_String = CASE WHEN ModelID <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), ModelID),
				ModelBM_String = CONVERT(nvarchar(10), MAX(ModelBM))
			FROM
				#Model
			GROUP BY
				ModelID
			ORDER BY
				ModelID			

			OPEN ModelBM_Cursor
			FETCH NEXT FROM ModelBM_Cursor INTO @ModelID, @ModelID_String, @ModelBM_String

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement_ModelBM = @SQLStatement_ModelBM + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) +
						'Model' + @ModelID_String + ' = CONVERT(bit, MAX(CASE WHEN MO.ModelBM & ' + @ModelBM_String + ' > 0 THEN 1 ELSE CASE WHEN MO.ObjectTypeBM & 1 > 0 AND MO.DimensionTypeID = -2 AND M1.ModelID = ' + @ModelID_String + ' THEN 0 ELSE CASE WHEN MO.ObjectTypeBM & 2 > 0 AND MO.DimensionTypeID <> -1 AND M2.ModelID = ' + @ModelID_String + ' THEN 0 ELSE CASE WHEN MO.ObjectTypeBM & 2 > 0 AND MO.DimensionTypeID = -1 AND M3.ModelID = ' + @ModelID_String + ' THEN 0 ELSE NULL END END END END)),'
					FETCH NEXT FROM ModelBM_Cursor INTO @ModelID, @ModelID_String, @ModelBM_String
				END
		CLOSE ModelBM_Cursor
		DEALLOCATE ModelBM_Cursor		

		WHILE @ModelID < 20
			BEGIN
				SET @ModelID = @ModelID + 1
				SET @SQLStatement_ModelBM = @SQLStatement_ModelBM + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) +
					'Model' + CASE WHEN @ModelID <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), @ModelID) + ' = CONVERT(bit, NULL)' + CASE WHEN @ModelID < 20 THEN ',' ELSE '' END
			END

		IF @Debug <> 0 PRINT @SQLStatement_ModelBM

	SET @Step = 'Create Source statement for procedure'
		SET @SQLStatement = '
		SET ANSI_WARNINGS OFF

		DECLARE @SourceTypeBM int = ' + CONVERT(nvarchar(10), @SourceTypeBM) + '

		CREATE TABLE #MOModel
			(
			ModelID int IDENTITY(1,1) NOT NULL,
			ModelBM int,
			ModelName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #MOModel
			(
			ModelBM,
			ModelName
			)
		SELECT 
			ModelBM,
			ModelName = MappedObjectName
		FROM
			MappedObject
		WHERE
			ObjectTypeBM & 1 > 0 AND
			DimensionTypeID = -2 AND
			SelectYN <> 0
		ORDER BY
			ModelBM

		SELECT
			MO.[Entity],
			MO.[ObjectName],
			[DimensionType] = MAX(DT.[DimensionTypeName]),
			[MappedObjectName] = MAX(MO.[MappedObjectName]),
			[ObjectTypeBM] = MAX(MO.[ObjectTypeBM]),
			[ModelBM] = MAX(MO.[ModelBM]),
			[MappingTypeID] = MAX(MO.[MappingTypeID]),
			[ReplaceTextYN] = CONVERT(bit, MAX(CONVERT(int, MO.[ReplaceTextYN]))),
			[SelectYN] = CONVERT(bit, MAX(CONVERT(int, MO.[SelectYN]))),' + @SQLStatement_ModelBM + '
		FROM
			[MappedObject] MO
			INNER JOIN pcINTEGRATOR..DimensionType DT ON DT.DimensionTypeID = MO.DimensionTypeID
			LEFT JOIN #MOModel M1 ON M1.ModelName = MO.[MappedObjectName]

			LEFT JOIN pcINTEGRATOR..[Dimension] D2 ON D2.DimensionTypeID = MO.DimensionTypeID AND D2.DimensionName = MO.ObjectName AND D2.SelectYN <> 0
			LEFT JOIN pcINTEGRATOR..[Model_Dimension] MD2 ON MD2.DimensionID = D2.DimensionID AND MD2.VisibilityLevelBM & 1 > 0 AND MD2.SourceTypeBM & @SourceTypeBM > 0 AND MD2.SelectYN <> 0
			LEFT JOIN pcINTEGRATOR..[Model] Mod2 ON Mod2.ModelID = MD2.ModelID
			LEFT JOIN [MappedObject] MO2 ON MO2.ObjectName = Mod2.ModelName AND MO2.ObjectTypeBM & 1 > 0 AND MO2.DimensionTypeID = -2
			LEFT JOIN #MOModel M2 ON M2.ModelName = MO2.[MappedObjectName]

			LEFT JOIN pcINTEGRATOR..[Dimension] D3 ON D3.DimensionTypeID = -1 AND D3.SelectYN <> 0
			LEFT JOIN pcINTEGRATOR..[Model_Dimension] MD3 ON MD3.DimensionID = D3.DimensionID AND MD3.VisibilityLevelBM & 1 > 0 AND MD3.SourceTypeBM & @SourceTypeBM > 0 AND MD3.SelectYN <> 0
			LEFT JOIN pcINTEGRATOR..[Model] Mod3 ON Mod3.ModelID = MD3.ModelID AND Mod3.OptFinanceDimYN <> 0 AND Mod3.SelectYN <> 0
			LEFT JOIN [MappedObject] MO3 ON MO3.ObjectName = Mod3.ModelName AND MO3.ObjectTypeBM & 1 > 0 AND MO3.DimensionTypeID = -2
			LEFT JOIN #MOModel M3 ON M3.ModelName = MO3.[MappedObjectName]
		GROUP BY
			MO.[Entity],
			MO.[ObjectName]
		ORDER BY
			MO.[Entity],
			MO.[ObjectName]	

		IF OBJECT_ID(''''tempdb..#MOModel'''') IS NOT NULL DROP TABLE #MOModel'

		IF @Debug <> 0 PRINT @SQLStatement

	SET @Step = 'Make Creation statement'
		SET @ProcedureName = '[' + @ProcedureName + ']'
		SET @SQLStatement = @Action + ' PROCEDURE [dbo].' + @ProcedureName + '

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

	AS' + CHAR(13) + CHAR(10) + @SQLStatement

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Drop temp tables'	
		DROP TABLE #Action
		DROP TABLE #Model

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH



GO
