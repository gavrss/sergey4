SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_ETL_MappedObject] 

	@ApplicationID int = NULL,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_ETL_MappedObject] @ApplicationID = 400, @Debug = true
--EXEC [spCreate_ETL_MappedObject] @ApplicationID = -1029, @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SourceID int,
	@SourceID_varchar nvarchar(10),
	@ProcedureName nvarchar(100),
	@Action nvarchar(10),
	@BaseQuerySQLStatement nvarchar(max),
	@SQLStatement nvarchar(max),
	@InstanceID int,
	@ETLDatabase nvarchar(50),
	@ModelBM int,
	@FinanceAccountYN bit,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2068' SET @Description = 'Procedure introduced.'
		IF @Version = '1.3.2070' SET @Description = 'Default value for MappedObjectName is more sophisticated.'
		IF @Version = '1.3.2075' SET @Description = 'Get Entity instead of EntityCode.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2098' SET @Description = 'Replaced vw_XXXX_Dimension_Finance_Metadata with FinancialSegment.'
		IF @Version = '1.4.0.2139' SET @Description = 'Handle negative ApplicationID.'

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
			@InstanceID = MAX(A.InstanceID),
			@ModelBM = SUM(BM.ModelBM)
		FROM
			Model M
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.OptFinanceDimYN <> 0 AND BM.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.SelectYN <> 0
		WHERE
			M.ApplicationID = @ApplicationID AND
			M.SelectYN <> 0

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Cursor on Sources'
		DECLARE MappedObject_Source_Cursor CURSOR FOR

		SELECT
			SourceID = S.SourceID,
			ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID 
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.OptFinanceDimYN <> 0
		WHERE
			S.SourceID <> 0 AND
			S.SelectYN <> 0

		OPEN MappedObject_Source_Cursor

		FETCH NEXT FROM MappedObject_Source_Cursor INTO @SourceID, @ETLDatabase

		WHILE @@FETCH_STATUS = 0
			BEGIN

				IF @Debug <> 0
				  SELECT 
					SourceID = @SourceID, ETLDatabase = @ETLDatabase

				SET @SourceID_varchar = CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID))

				SET @BaseQuerySQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.[dbo].[MappedObject]
			(
			[Entity],
			[ObjectName],
			[DimensionTypeID],
			[MappedObjectName],
			[ObjectTypeBM],
			[ModelBM],
			[MappingTypeID],
			[SelectYN]
			)
		SELECT DISTINCT
			E.Entity,
			FS.SegmentName,
			FS.DimensionTypeID,
			MappedObjectName = ISNULL(DMO.MappedObjectName, ''''GL_'''' + REPLACE(' + @ETLDatabase + '.[dbo].[f_ReplaceText] (FS.SegmentName, 1), ''''GL_'''', '''''''')),
			ObjectTypeBM = 2,
			[ModelBM] = ' + CONVERT(nvarchar, @ModelBM) + ',
			[MappingTypeID] = DT.DefaultMappingTypeID,
			SelectYN = 1
		FROM
			' + @ETLDatabase + '.[dbo].[FinancialSegment] FS
			INNER JOIN ' + @ETLDatabase + '.[dbo].[Entity] E ON E.SourceID = FS.SourceID AND E.EntityCode = FS.EntityCode AND E.SelectYN <> 0
			INNER JOIN pcINTEGRATOR.dbo.DimensionType DT ON DT.DimensionTypeID = FS.DimensionTypeID
			LEFT JOIN (SELECT [ObjectName] = [ObjectName] COLLATE DATABASE_DEFAULT, [MappedObjectName] = MAX([MappedObjectName]) COLLATE DATABASE_DEFAULT FROM ' + @ETLDatabase + '.[dbo].[MappedObject] WHERE [DimensionTypeID] = -1 AND [SelectYN] <> 0 AND [ObjectTypeBM] & 2 > 0 GROUP BY [ObjectName]) DMO ON DMO.ObjectName = FS.SegmentName
		WHERE
			FS.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
			FS.DimensionTypeID = -1 AND
			NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[MappedObject] t WHERE t.Entity COLLATE DATABASE_DEFAULT = E.Entity AND t.ObjectName = FS.SegmentName)
	
		SET @Inserted = @Inserted + @@ROWCOUNT'

				IF @Debug <> 0 PRINT @BaseQuerySQLStatement 

				SET @Step = 'CREATE PROCEDURE'

				SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_ETL_MappedObject'

				SET @Step = 'Determine CREATE or ALTER'
				CREATE TABLE #Action
					(
					[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
					)

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
				INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
				SELECT @Action = [Action] FROM #Action
				DROP TABLE #Action

				SET @Step = 'Set SQL statement for creating Procedure'

				SET @SQLStatement = '
SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@LinkedYN bit,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = ''''Insert into MappedObject table'''''

				SET @SQLStatement = @SQLStatement + @BaseQuerySQLStatement + '

		SET ANSI_WARNINGS OFF

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'
	
				SET @ProcedureName = '[' + @ProcedureName + ']'

				SET @Step = 'Make Creation statement'

				SET @SQLStatement = @Action + ' PROCEDURE [dbo].' + @ProcedureName + '

@JobID int = 0,
@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
@Rows int = NULL,
@GetVersion bit = 0,
@Duration time(7) = ''''00:00:00'''' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT,
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS' + CHAR(13) + CHAR(10) + @SQLStatement

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0 PRINT @SQLStatement

				EXEC (@SQLStatement)

				FETCH NEXT FROM MappedObject_Source_Cursor INTO @SourceID, @ETLDatabase
			END

		CLOSE MappedObject_Source_Cursor
		DEALLOCATE MappedObject_Source_Cursor

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + @SourceID_varchar + ')', @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + @SourceID_varchar + ')', GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH







GO
