SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_ETL_MappedObject]

	@ApplicationID int = NULL,
	@Debug bit = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--EXEC [spInsert_ETL_MappedObject] @ApplicationID = 400, @Debug = true
--EXEC [spInsert_ETL_MappedObject] @ApplicationID = 601, @Debug = true
--EXEC [spInsert_ETL_MappedObject] @ApplicationID = 1320, @Debug = true
--EXEC [spInsert_ETL_MappedObject] @ApplicationID = -1111, @Debug = true
--EXEC [spInsert_ETL_MappedObject] @ApplicationID = 1326, @Debug = true
--EXEC [spInsert_ETL_MappedObject] @ApplicationID = 1335, @Debug = 1

--#WITH ENCRYPTION#--
AS

DECLARE
	@InstanceID int,
	@VersionID int,
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SourceID int,
	@SourceDatabase nvarchar(100),
	@SourceTypeBM int,
	@ETLDatabase nvarchar(100),
	@ETLDatabase_InheritedFrom nvarchar(100),
	@LanguageID int,
	@ObjectName nvarchar(100),
	@MappedObjectName nvarchar(100),
	@TranslatedWord nvarchar(100),
	@ModelID int,
	@ValidYN bit,
	@ModelBM int,
	@SumModelBM int = 0,
	@SumModelBM_Segment int,
	@ConsolidationYN bit,
	@Entity nvarchar(100),
	@Model nvarchar(100),
	@Counter int = 0,
	@CounterString nvarchar(10),
	@ObjectTypeBM int,
	@Application_InheritedFrom int,
	@FieldList nvarchar(max),
	@InsertCheck nvarchar(max),
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2061' SET @Description = 'Exclude mandatory dimensions where VisibleYN = false'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2065' SET @Description = 'Handle SourceTypeID = 6, pcEXCHANGE.'
		IF @Version = '1.2.2068' SET @Description = 'Run [spCreate_ETL_MappedObject].'
		IF @Version = '1.3.2070' SET @Description = 'Abbreviation adjustments regarding SourceTypeID = 6, pcEXCHANGE.'
		IF @Version = '1.3.2071' SET @Description = 'Test on Introduced. Replaced ModelBM in Dimension with DefaultSelectYN in Model_Dimension. Fill MemberSelection added'
		IF @Version = '1.2.2072' SET @Description = 'Show inserted rows'
		IF @Version = '1.3.2075' SET @Description = 'Implement the difference between EntityCode and Entity'
		IF @Version = '1.3.2076' SET @Description = 'Ignore the VisibleYN property (Opposite to 1.2.2061 fix)'
		IF @Version = '1.3.2077' SET @Description = 'Check @SourceTypeBM on dimensions, not include @VisibleYN = 0'
		IF @Version = '1.3.2078' SET @Description = 'Check on MD.VisibilityLevelBM, replaces MandatoryYN & VisibleYN'
		IF @Version = '1.3.2085' SET @Description = 'Enhanced translation of the MappedObjectName field.'
		IF @Version = '1.3.2088' SET @Description = 'Changed reference to [spGet_Translation].'
		IF @Version = '1.2.2089' SET @Description = 'Splitted long SQL strings'
		IF @Version = '1.3.2098' SET @Description = 'Replaced vw_XXXX_Dimension_Finance_Metadata with FinancialSegment.'
		IF @Version = '1.3.2104' SET @Description = 'Added test on SourceTypeBM in table Model_Dimension.'
		IF @Version = '1.3.2107' SET @Description = 'Fixed bug on default value for ModelBM. Get MappedObjectName from pcEXCHANGE. Check Nyc'
		IF @Version = '1.3.2110' SET @Description = 'Fixed bug on pcEXCHANGE (added not available dimensions).'
		IF @Version = '1.3.2111' SET @Description = 'Fixed bug on ModelBM calculation.'
		IF @Version = '1.3.0.2118' SET @Description = 'Fixed bug on ModelBM calculation for pcExchange. Fixed bug on calculating @SumModelBM_Segment.'
		IF @Version = '1.3.1.2120' SET @Description = 'Changed handling for Upgrade. Properties filtered on SourceTypeBM.'
		IF @Version = '1.4.0.2139' SET @Description = 'Handle SourceID < 0.'
		IF @Version = '2.0.3.2154' SET @Description = 'OBSOLETE?, Removed Property.DimensionID.'

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
			@InstanceID = A.InstanceID,
			@VersionID = A.VersionID,
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@LanguageID = A.LanguageID,
			@Application_InheritedFrom = InheritedFrom
		FROM
			[Application] A 
		WHERE
			A.ApplicationID = @ApplicationID

		IF @Debug <> 0
			SELECT
				[ApplicationID] = @ApplicationID,
				InstanceID = @InstanceID,
				ETLDatabase = @ETLDatabase,
				LanguageID = @LanguageID,
				Application_InheritedFrom = @Application_InheritedFrom,
				[Version] = @Version

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		SELECT @ETLDatabase_InheritedFrom = ETLDatabase FROM [Application] WHERE ApplicationID = @Application_InheritedFrom

		DECLARE Nyc_Cursor CURSOR FOR
			SELECT
				ModelID = MAX(M.ModelID),
				BM.ModelBM
			FROM
				Model M
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			WHERE
				M.ApplicationID = @ApplicationID AND
				M.SelectYN <> 0
			GROUP BY
				BM.ModelBM

			OPEN Nyc_Cursor
			FETCH NEXT FROM Nyc_Cursor INTO @ModelID, @ModelBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					EXEC spCheck_Feature @ModelID = @ModelID, @ValidYN = @ValidYN OUT, @Debug = @Debug
					SET @SumModelBM = @SumModelBM + @ModelBM * @ValidYN

					FETCH NEXT FROM Nyc_Cursor INTO @ModelID, @ModelBM
				END
		CLOSE Nyc_Cursor
		DEALLOCATE Nyc_Cursor	

		IF @Debug <> 0 SELECT SumModelBM = @SumModelBM

		SELECT
			@SourceTypeBM = SUM(sub.SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				ST.SourceTypeBM
			FROM
				[Model] M 
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & @SumModelBM > 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
				INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
				INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			WHERE
				M.ApplicationID = @ApplicationID AND
				M.SelectYN <> 0
			) sub

		SELECT
			@SumModelBM_Segment = SUM(BM.ModelBM)
		FROM
			Model M
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.OptFinanceDimYN <> 0 AND BM.ModelBM & @SumModelBM > 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN Model_Dimension MD ON MD.ModelID = M.BaseModelID AND MD.DimensionID = 0 AND MD.DefaultSelectYN <> 0
		WHERE
			M.ApplicationID = @ApplicationID AND
			M.SelectYN <> 0

		SELECT @ConsolidationYN = CASE WHEN (SELECT COUNT(1) FROM Model WHERE ApplicationID = @ApplicationID AND BaseModelID = -9) > 0 THEN 1 ELSE 0 END

		IF @Debug <> 0 
			SELECT
				ApplicationID = @ApplicationID,
				LanguageID = @LanguageID,
				ETLDatabase = @ETLDatabase,
				SourceTypeBM = @SourceTypeBM,
				SumModelBM = @SumModelBM,
				SumModelBM_Segment = @SumModelBM_Segment,
				ConsolidationYN = @ConsolidationYN,
				ETLDatabase_InheritedFrom = @ETLDatabase_InheritedFrom,
				Application_InheritedFrom = @Application_InheritedFrom

	SET @Step = 'Insert members from upgraded database'
		IF @ETLDatabase_InheritedFrom IS NOT NULL
			BEGIN
				CREATE TABLE #ColumnList
					(
					ColumnName nvarchar(100) COLLATE DATABASE_DEFAULT,
					SortOrder int,
					PK bit
					)

				SET @SQLStatement = '
					INSERT INTO #ColumnList
						(
						ColumnName,
						SortOrder,
						PK
						)
					SELECT
						ColumnName,
						SortOrder = MAX(SortOrder),
						PK = MAX(PK)
					FROM
						(
						SELECT
							ColumnName = c.name,
							SortOrder = 0,
							PK = 0
						FROM
							' + @ETLDatabase_InheritedFrom + '.sys.columns c
							INNER JOIN ' + @ETLDatabase_InheritedFrom + '.sys.tables t ON t.object_id = c.object_id AND t.name = ''MappedObject''

						UNION SELECT
							ColumnName = c.name,
							SortOrder = c.column_id,
							PK = CASE WHEN ic.object_id IS NULL THEN 0 ELSE 1 END 
						FROM
							' + @ETLDatabase + '.sys.columns c
							INNER JOIN ' + @ETLDatabase + '.sys.tables t ON t.object_id = c.object_id AND t.name = ''MappedObject''
							LEFT JOIN ' + @ETLDatabase + '.sys.indexes i ON i.object_id = c.object_id AND i.is_primary_key <> 0
							LEFT JOIN ' + @ETLDatabase + '.sys.index_columns ic ON ic.object_id = c.object_id and ic.index_id = i.index_id AND ic.column_id = c.column_id
						) sub
					GROUP BY
						ColumnName
					HAVING
						COUNT(1) = 2
					ORDER BY
						MAX(SortOrder)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @Debug <> 0 SELECT TempTable = '#ColumnList', * FROM #ColumnList ORDER BY SortOrder

				SELECT @FieldList = ISNULL(@FieldList, '') + '[' + ColumnName + '], ' FROM #ColumnList ORDER BY SortOrder
				SELECT @InsertCheck = ISNULL(@InsertCheck, '') + 'D.[' + ColumnName + '] = S.[' + ColumnName + '] AND ' FROM #ColumnList WHERE PK <> 0 ORDER BY SortOrder

				SET @FieldList = SUBSTRING(@FieldList, 1, LEN(@FieldList) - 1)
				SET @InsertCheck = SUBSTRING(@InsertCheck, 1, LEN(@InsertCheck) - 4)

				SET @SQLStatement = '
					INSERT INTO ' + @ETLDatabase + '..[MappedObject] (' + @FieldList + ') 
					SELECT ' + @FieldList + ' FROM ' + @ETLDatabase_InheritedFrom + '..[MappedObject] S
					WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '..[MappedObject] D WHERE ' + @InsertCheck + ')'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Inserted = @Inserted + @@ROWCOUNT

				SET @SQLStatement = '
					UPDATE MO
						SET MappedObjectName =
							CASE DimensionTypeID
								WHEN 21 THEN ''BaseCurrency''
								WHEN 30 THEN ''AccountManager''
							END
					FROM
						' + @ETLDatabase + '..MappedObject MO
					WHERE
						(DimensionTypeID = 21 AND MappedObjectName = ''ReportingCurrency'') OR
						(DimensionTypeID = 30 AND MappedObjectName = ''SalesMan'')'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
		
				DROP TABLE #ColumnList
			END

	SET @Step = 'Run [spCreate_ETL_MappedObject]'
		EXEC [spCreate_ETL_MappedObject] @ApplicationID = @ApplicationID

	SET @Step = 'Add Finance Segment Dimensions'
		DECLARE Segment_Source_Cursor CURSOR FOR

		SELECT
			SourceID = S.SourceID
		FROM
			Source S
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.OptFinanceDimYN <> 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
		WHERE
			S.SelectYN <> 0

		OPEN Segment_Source_Cursor

		FETCH NEXT FROM Segment_Source_Cursor INTO @SourceID

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @SourceID <> 0
				  BEGIN
		
					SET @SQLStatement = '
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
						[Entity] = E.Entity,
						[ObjectName] = v.SegmentName,
						[DimensionTypeID] = -1,
						[MappedObjectName] = ''GL_'' + REPLACE(' + @ETLDatabase + '.[dbo].[f_ReplaceText] (v.SegmentName, 1), ''GL_'', ''''),
						[ObjectTypeBM] = 2,
						[ModelBM] = ' + CONVERT(nvarchar, @SumModelBM_Segment) + ',
						[MappingTypeID] = DT.DefaultMappingTypeID,
						[SelectYN] = 1
					FROM
						' + @ETLDatabase + '.[dbo].FinancialSegment v
						INNER JOIN ' + @ETLDatabase + '.[dbo].Entity E ON E.SourceID = v.SourceID AND E.EntityCode = v.EntityCode AND E.SelectYN <> 0
						INNER JOIN DimensionType DT ON DT.DimensionTypeID = v.DimensionTypeID
					WHERE
						v.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
						v.DimensionTypeID = -1 AND
						NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[MappedObject] t WHERE t.Entity = E.Entity COLLATE DATABASE_DEFAULT AND t.ObjectName = v.SegmentName COLLATE DATABASE_DEFAULT)'
	
					IF @Debug <> 0 PRINT @SQLStatement 
			
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT

				  END

			FETCH NEXT FROM Segment_Source_Cursor INTO @SourceID
			END

		CLOSE Segment_Source_Cursor
		DEALLOCATE Segment_Source_Cursor

	SET @Step = 'Ordinary Dimensions & Properties'
	--Properties has to be checked. Ex SendTo DimensionType = 28 JaWo 2016-04-08
		SET @SQLStatement = '
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
				Entity = ''-1'',
				ObjectName = sub.ObjectName,
				DimensionTypeID = MAX(sub.DimensionTypeID),
				MappedObjectName = sub.ObjectName,
				ObjectTypeBM = CASE WHEN MAX(sub.ObjectTypeBM) = 6 THEN 6 ELSE CASE WHEN MIN(sub.ObjectTypeBM) = 2 AND MAX(sub.ObjectTypeBM) = 4 THEN 6 ELSE CASE WHEN MIN(sub.ObjectTypeBM) = 2 AND MAX(sub.ObjectTypeBM) = 2 THEN 2 ELSE CASE WHEN MIN(sub.ObjectTypeBM) = 4 AND MAX(sub.ObjectTypeBM) = 4 THEN 4 ELSE 0 END END END END,
				ModelBM = SUM(CASE WHEN sub.DefaultSelectYN <> 0 THEN 1 ELSE 0 END * sub.ModelBM),
				[MappingTypeID] = MAX(sub.MappingTypeID),
				SelectYN = MAX(CONVERT(int, sub.SelectYN))
			FROM'
		SET @SQLStatement = @SQLStatement + '
				(
				SELECT DISTINCT
					ObjectName = ISNULL(P.PropertyName, D.DimensionName),
					DimensionTypeID = MAX(D.DimensionTypeID),
					ObjectTypeBM = MAX(CASE WHEN P.PropertyName = D.DimensionName OR P.PropertyName IS NULL THEN 2 ELSE 0 END) + MAX(CASE WHEN P.PropertyID IS NOT NULL THEN 4 ELSE 0 END),
					ModelBM = BM.ModelBM,
					[MappingTypeID] = MAX(DT.DefaultMappingTypeID),
					SelectYN = CASE WHEN (MAX(D.DimensionID) = -4 AND ' + CONVERT(nvarchar(10), CONVERT(int, @ConsolidationYN)) + ' <> 0) OR (MAX(D.DimensionID) = -36 AND ' + CONVERT(nvarchar(10), CONVERT(int, @ConsolidationYN)) + ' = 0) THEN 0 ELSE CASE WHEN MAX(ISNULL(CONVERT(int, P.DefaultSelectYN), 1)) + MAX(CONVERT(int, D.DefaultSelectYN)) = 2 THEN 1 ELSE 0 END END,
					DefaultSelectYN = MAX(CONVERT(int, MD.DefaultSelectYN))
				FROM
					Model M
					INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
					INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM) + ' > 0 AND MD.VisibilityLevelBM & 1 > 0 AND MD.Introduced < ''' + @Version + ''' AND MD.SelectYN <> 0
					INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM) + ' > 0 AND D.Introduced < ''' + @Version + ''' AND D.SelectYN <> 0
					INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
					LEFT JOIN Property P ON P.DependentDimensionID = D.DimensionID AND P.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM) + ' > 0 AND P.Introduced < ''' + @Version + ''' AND P.SelectYN <> 0
				WHERE
					M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND
					M.SelectYN <> 0 AND
					D.DimensionTypeID <> -1 AND
					NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[MappedObject] t WHERE t.Entity = ''-1'' AND t.ObjectName = ISNULL(P.PropertyName, D.DimensionName))
				GROUP BY
					ISNULL(P.PropertyName, D.DimensionName),
					BM.ModelBM
				) sub
			GROUP BY
				sub.ObjectName'
	
		IF @Debug <> 0 PRINT @SQLStatement 
			
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Dimensions that are used as Member Properties with changed names on the Property'
		SET @SQLStatement = '
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
			SELECT 
				[Entity] = ''-1'',
				[ObjectName] = DimensionName,
				[DimensionTypeID] = MAX(DimensionTypeID),
				[MappedObjectName] = DimensionName,
				[ObjectTypeBM] = 2,
				[ModelBM] = SUM(CASE WHEN sub.DefaultSelectYN <> 0 THEN 1 ELSE 0 END * sub.ModelBM),
				[MappingTypeID] = MAX(sub.[MappingTypeID]),
				[SelectYN] = CASE WHEN (MAX(DimensionID) = -4 AND ' + CONVERT(nvarchar(10), CONVERT(int, @ConsolidationYN)) + ' <> 0) OR (MAX(DimensionID) = -36 AND ' + CONVERT(nvarchar(10), CONVERT(int, @ConsolidationYN)) + ' = 0) THEN 0 ELSE MAX(CONVERT(int, sub.DefaultSelectYN)) END
			FROM'
		SET @SQLStatement = @SQLStatement + '
				(
				SELECT
					[DimensionName] = D.DimensionName,
					[DimensionTypeID] = MAX(D.DimensionTypeID),
					[ObjectTypeBM] = 2,
					[ModelBM] = BM.ModelBM,
					[MappingTypeID] = MAX(DT.DefaultMappingTypeID),
					[DimensionID] = MAX(D.DimensionID),
					[DefaultSelectYN] = MAX(CONVERT(int, MD.DefaultSelectYN))
				FROM
					Model M
					INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
					INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM) + ' > 0 AND MD.VisibilityLevelBM & 1 > 0 AND MD.Introduced < ''' + @Version + ''' AND MD.SelectYN <> 0
					INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM) + ' > 0 AND D.Introduced < ''' + @Version + ''' AND D.SelectYN <> 0
					INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
					LEFT JOIN Property P ON P.DependentDimensionID = D.DimensionID AND P.Introduced < ''' + @Version + ''' AND P.SelectYN <> 0
				WHERE
					M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND
					M.SelectYN <> 0 AND
					P.PropertyName <> D.DimensionName AND
					D.DimensionTypeID <> -1 AND
					NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[MappedObject] t WHERE t.Entity = ''-1'' AND t.ObjectName = D.DimensionName)
				GROUP BY
					D.DimensionName,
					BM.ModelBM
				) sub
			GROUP BY
				DimensionName'
	
		IF @Debug <> 0 PRINT @SQLStatement 
			
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Properties that are used as Member Properties in selected dimensions'
		SET @SQLStatement = '
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
				Entity = ''-1'',
				ObjectName = P.PropertyName,
				DimensionTypeID = MAX(PD.DimensionTypeID),
				MappedObjectName = P.PropertyName,
				ObjectTypeBM = 6,
				ModelBM = 0,
				[MappingTypeID] = MAX(DT.DefaultMappingTypeID),
				SelectYN = MAX(CONVERT(int, PD.DefaultSelectYN))
			FROM
				Model M
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
				INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM) + ' > 0 AND MD.VisibilityLevelBM & 1 > 0 AND MD.Introduced < ''' + @Version + ''' AND MD.SelectYN <> 0
				INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM) + ' > 0 AND D.Introduced < ''' + @Version + ''' AND D.SelectYN <> 0
				INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
				INNER JOIN Dimension_Property DP ON DP.InstanceID IN(0, ' + CONVERT(nvarchar(15), @InstanceID) + ') AND DP.VersionID IN(0, ' + CONVERT(nvarchar(15), @VersionID) + ') AND DP.DimensionID = D.DimensionID 
				INNER JOIN Property P ON P.PropertyID = DP.PropertyID AND P.DataTypeID = 3 AND P.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM) + ' > 0 AND P.Introduced < ''' + @Version + ''' AND P.SelectYN <> 0
				INNER JOIN Dimension PD ON PD.DimensionID = P.DependentDimensionID AND PD.DimensionTypeID <> -1 AND PD.Introduced < ''' + @Version + ''' AND PD.SelectYN <> 0
			WHERE
				M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND
				M.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[MappedObject] t WHERE t.Entity = ''-1'' AND t.ObjectName = P.PropertyName)
			GROUP BY
				P.PropertyName'
	
		IF @Debug <> 0 PRINT @SQLStatement 
			
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT
			
	SET @Step = 'Ordinary Models'
		SET @SQLStatement = '
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
				Entity = ''-1'',
				ObjectName = BM.ModelName,
				DimensionTypeID = -2,
				MappedObjectName = M.ModelName,
				ObjectTypeBM = 1,
				ModelBM = BM.ModelBM,
				[MappingTypeID] = 0,
				SelectYN = 1			 
			FROM
				Model M
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
			WHERE
				M.BaseModelID <> 0 AND
				M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND
				M.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[MappedObject] t WHERE t.Entity = ''-1'' AND t.ObjectName = BM.ModelName AND ObjectTypeBM & 1 > 0)'
	
		IF @Debug <> 0 PRINT @SQLStatement 
			
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert rows to MemberSelection'
		IF @Version > '1.3'
			BEGIN
				SET @SQLStatement = '
					INSERT INTO ' + @ETLDatabase + '.dbo.MemberSelection
						(
						DimensionID,
						Label,
						SelectYN
						)
					SELECT 
						DimensionID = M.DimensionID,
						Label = M.Label,
						SelectYN = M.DefaultSelectYN
					FROM
						pcINTEGRATOR.dbo.Member M 
					WHERE
						M.MandatoryYN = 0 AND
						M.SourceTypeBM & ' + CONVERT(nvarchar, @SourceTypeBM) + ' > 0 AND
						M.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND
						M.Introduced < ''' + @Version + ''' AND
						M.SelectYN <> 0 AND
						NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.MemberSelection MS WHERE MS.DimensionID = M.DimensionID AND MS.Label = M.Label)'
	
				IF @Debug <> 0 PRINT @SQLStatement 
			
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'pcEXCHANGE datasources'
		DECLARE pcEXCHANGE_Source_Cursor CURSOR FOR

		SELECT
			[SourceDatabase]
		FROM
			Source S
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
		WHERE
			S.SourceTypeID = 6 AND
			S.SelectYN <> 0

		OPEN pcEXCHANGE_Source_Cursor

		FETCH NEXT FROM pcEXCHANGE_Source_Cursor INTO @SourceDatabase

		WHILE @@FETCH_STATUS = 0
			BEGIN
				--pcEXCHANGE Model
		
				SET @SQLStatement = '
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
					Entity = ''-1'',
					ObjectName = ISNULL(BM.ModelName, M.ModelName),
					DimensionTypeID = -2,
					MappedObjectName = M.ModelName,
					ObjectTypeBM = 1,
					ModelBM = BM.ModelBM,
					[MappingTypeID] = 0,
					SelectYN = 1
				FROM
					' + @SourceDatabase + '.dbo.Model M
					INNER JOIN pcINTEGRATOR.dbo.Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
				WHERE
					M.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[MappedObject] t WHERE t.Entity = ''-1'' AND t.ObjectName = ISNULL(BM.ModelName, M.ModelName) COLLATE DATABASE_DEFAULT)'
	
				IF @Debug <> 0 PRINT @SQLStatement 
			
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				--Prepare Dim
				CREATE TABLE #Entity
					(
					Entity nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				SET @SQLStatement = '
				INSERT INTO #Entity
					(
					Entity
					)
				SELECT DISTINCT
					DimensionName 
				FROM
					' + @SourceDatabase + '.dbo.Dimension D
				WHERE
					D.SelectYN <> 0 AND
					D.DimensionTypeID = 4'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)
				SELECT @Entity = Entity FROM #Entity
				TRUNCATE TABLE #Entity

				CREATE TABLE #Model
					(
					Model nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				SET @SQLStatement = '
				INSERT INTO #Model
					(
					Model
					)
				SELECT 
					M.ModelName 
				FROM
					' + @SourceDatabase + '.dbo.Model M
					INNER JOIN pcINTEGRATOR.dbo.Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.[OptFinanceDimYN] <> 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
				WHERE
					M.SelectYN <> 0'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

				DECLARE pcEXCHANGE_Model_Cursor CURSOR FOR

				SELECT
					[Model]
				FROM
					#Model

				OPEN pcEXCHANGE_Model_Cursor

				FETCH NEXT FROM pcEXCHANGE_Model_Cursor INTO @Model

				WHILE @@FETCH_STATUS = 0
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #Entity
								(
								Entity
								)
							SELECT DISTINCT
								' + @Entity + '
							FROM
								' + @SourceDatabase + '.dbo.[FactData_' + @Model + '] M
							WHERE
								Entity <> ''NONE'' AND
								NOT EXISTS (SELECT 1 FROM #Entity E WHERE E.Entity = M.' + @Entity + ')'

						IF @Debug <> 0 PRINT @SQLStatement 
						EXEC (@SQLStatement)

					FETCH NEXT FROM pcEXCHANGE_Model_Cursor INTO @Model
					END

				CLOSE pcEXCHANGE_Model_Cursor
				DEALLOCATE pcEXCHANGE_Model_Cursor

				--Prepare Dimension
				CREATE TABLE [dbo].[#Dimension]
					(
					[Entity] [varchar](50) COLLATE DATABASE_DEFAULT NOT NULL,
					[ObjectName] [nvarchar](100) COLLATE DATABASE_DEFAULT NULL,
					[DimensionID] [int] NOT NULL,
					[DimensionTypeID] [int] NOT NULL,
					[MappedObjectName] [nvarchar](100) COLLATE DATABASE_DEFAULT NULL,
					[ObjectTypeBM] [int] NOT NULL,
					[ModelBM] [int] NULL,
					[MappingTypeID] [int] NOT NULL,
					[SelectYN] [int] NOT NULL
					)

				SET @SQLStatement = '
					INSERT INTO #Dimension
						(
						[Entity],
						[ObjectName],
						[DimensionID],
						[DimensionTypeID],
						[MappedObjectName],
						[ObjectTypeBM],
						[ModelBM],
						[MappingTypeID],
						[SelectYN]
						)
					SELECT 
						[Entity],
						[ObjectName],
						[DimensionID],
						[DimensionTypeID],
						[MappedObjectName],
						[ObjectTypeBM],
						[ModelBM] = SUM(ModelBM),
						[MappingTypeID],
						[SelectYN]
					FROM
						(
						SELECT DISTINCT
							Entity = CASE WHEN MAX(D.DimensionTypeID) = -1 THEN E.Entity ELSE ''-1'' END,
							ObjectName = MAX(ISNULL(CASE WHEN D.DimensionTypeID = -1 THEN D.DimensionName ELSE pcID.DimensionName END, D.DimensionName)),
							[DimensionID] = MAX(D.[DimensionID]),
							DimensionTypeID = MAX(D.DimensionTypeID),
							MappedObjectName = D.DimensionName,
							ObjectTypeBM = 2,
							M.BaseModelID,
							ModelBM = MAX(ISNULL(BM.ModelBM, 0)),
							[MappingTypeID] = 0,
							SelectYN = 1
						FROM
							' + @SourceDatabase + '.dbo.[Dimension] D
							INNER JOIN #Entity E ON 1 = 1
							INNER JOIN ' + @SourceDatabase + '.dbo.[ModelDimension] MD ON MD.DimensionName = D.DimensionName
							INNER JOIN ' + @SourceDatabase + '.dbo.[Model] M ON M.ModelName = MD.ModelName
							INNER JOIN [pcINTEGRATOR].[dbo].[Model] BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
							INNER JOIN [pcINTEGRATOR].[dbo].[Model_Dimension] pcMD ON pcMD.DimensionID = D.DimensionID AND pcMD.VisibilityLevelBM & 9 > 0 AND pcMD.Introduced < ''' + @Version + ''' AND pcMD.SelectYN <> 0
							INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] pcID ON pcID.DimensionID = pcMD.[DimensionID] AND pcID.DimensionTypeID = D.DimensionTypeID
						WHERE
							D.SelectYN <> 0
						GROUP BY
							D.DimensionName,
							E.Entity,
							M.BaseModelID
						) sub
					GROUP BY
						Entity,
						ObjectName,
						[DimensionID],
						DimensionTypeID,
						MappedObjectName,
						ObjectTypeBM,
						[MappingTypeID],
						SelectYN'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

				SET @SQLStatement = '
					INSERT INTO #Dimension
						(
						[Entity],
						[ObjectName],
						[DimensionID],
						[DimensionTypeID],
						[MappedObjectName],
						[ObjectTypeBM],
						[ModelBM],
						[MappingTypeID],
						[SelectYN]
						)
					SELECT DISTINCT
						[Entity] = ''-1'',
						[ObjectName] = D.DimensionName,
						[DimensionID] = MAX(D.DimensionID),
						[DimensionTypeID] = MAX(D.DimensionTypeID),
						[MappedObjectName] = D.DimensionName,
						[ObjectTypeBM] = 2,
						[ModelBM] = SUM(CASE WHEN MD.VisibilityLevelBM & 8 > 0 THEN M.ModelBM ELSE 0 END),
						[MappingTypeID] = 0,
						[SelectYN] = MAX(CONVERT(int, MD.DefaultSelectYN))
					FROM
						[pcINTEGRATOR].[dbo].[Dimension] D
						INNER JOIN ' + @ETLDatabase + '.dbo.MappedObject MO ON MO.ObjectTypeBM = 1
						INNER JOIN [pcINTEGRATOR].dbo.Model_Dimension MD ON MD.DimensionID = D.DimensionID AND MD.VisibilityLevelBM & 9 > 0 AND MD.Introduced < ''' + @Version + ''' AND MD.SelectYN <> 0
						INNER JOIN [pcINTEGRATOR].dbo.Model M ON M.ModelID = MD.ModelID AND M.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND M.ModelBM & MO.ModelBM > 0 AND M.Introduced < ''' + @Version + ''' AND M.SelectYN <> 0
					WHERE
						D.DimensionTypeID >= 0 AND
						D.Introduced < ''' + @Version + ''' AND
						D.SelectYN <> 0 AND
						NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.MappedObject MO WHERE MO.Entity = ''-1'' AND MO.ObjectName = D.DimensionName AND MO.ObjectTypeBM & 2 > 0) AND
						NOT EXISTS (SELECT 1 FROM #Dimension Dim WHERE (Dim.ObjectName = D.DimensionName OR Dim.DimensionID = D.DimensionID) AND Dim.ObjectTypeBM & 2 > 0)
					GROUP BY
						D.DimensionName
					ORDER BY
						D.DimensionName'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

				--Prepare Property
				CREATE TABLE [dbo].[#Property]
					(
					[Entity] [varchar](50) COLLATE DATABASE_DEFAULT NOT NULL,
					[ObjectName] [nvarchar](100) COLLATE DATABASE_DEFAULT NULL,
					[DimensionTypeID] [int] NOT NULL,
					[MappedObjectName] [nvarchar](100) COLLATE DATABASE_DEFAULT NULL,
					[ObjectTypeBM] [int] NOT NULL,
					[ModelBM] [int] NULL,
					[MappingTypeID] [int] NOT NULL,
					[SelectYN] [int] NOT NULL
					)

				WHILE @Counter < 20
					BEGIN
						SET @Counter = @Counter + 1
						SET @CounterString = CASE WHEN @Counter <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar, @Counter)
						SET @SQLStatement = '
							INSERT INTO #Property
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
								Entity = ''-1'',
--								ObjectName = D.PropertyName' + @CounterString + ',
								ObjectName = D.PropertyMemberDimension' + @CounterString + ',
								DimensionTypeID = -3,
--								MappedObjectName = D.PropertyName' + @CounterString + ',
								MappedObjectName = D.PropertyMemberDimension' + @CounterString + ',
								ObjectTypeBM = 4,
								ModelBM = BM.ModelBM,
								[MappingTypeID] = 0,
								SelectYN = 1
							FROM
								' + @SourceDatabase + '.dbo.[Dimension] D
								INNER JOIN ' + @SourceDatabase + '.dbo.[ModelDimension] MD ON MD.DimensionName = D.DimensionName
								INNER JOIN ' + @SourceDatabase + '.dbo.[Model] M ON M.ModelName = MD.ModelName
								INNER JOIN pcINTEGRATOR.dbo.Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
							WHERE
								D.SelectYN <> 0 AND
								D.PropertyName' + @CounterString + ' IS NOT NULL AND
								D.PropertyDataTypeID' + @CounterString + ' = 3
							GROUP BY
--								D.PropertyName' + @CounterString + ',
								D.PropertyMemberDimension' + @CounterString + ',
								BM.ModelBM'

						IF @Debug <> 0 PRINT @SQLStatement 
						EXEC (@SQLStatement)
					END

					SET @SQLStatement = '
					INSERT INTO #Property
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
					SELECT 
						[Entity] = ''-1'',
						[ObjectName] = P.PropertyName,
						[DimensionTypeID] = -3,
						[MappedObjectName] = P.PropertyName,
						[ObjectTypeBM] = 4,
						[ModelBM] = 0,
						[MappingTypeID] = 0,
						[SelectYN] = MAX(CONVERT(int, MD.DefaultSelectYN))
					FROM
						[pcINTEGRATOR].[dbo].[Property] P
						INNER JOIN Dimension_Property DP ON DP.InstanceID IN(0, ' + CONVERT(nvarchar(15), @InstanceID) + ') AND DP.VersionID IN(0, ' + CONVERT(nvarchar(15), @VersionID) + ') AND DP.PropertyID = P.PropertyID 
						INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.DimensionID = DP.DimensionID AND D.Introduced < ''' + @Version + ''' AND D.SelectYN <> 0
						INNER JOIN ' + @ETLDatabase + '.dbo.MappedObject MO ON MO.ObjectTypeBM = 1
						INNER JOIN [pcINTEGRATOR].dbo.Model_Dimension MD ON MD.DimensionID = D.DimensionID AND MD.VisibilityLevelBM & 9 > 0 AND MD.Introduced < ''' + @Version + ''' AND MD.SelectYN <> 0
						INNER JOIN [pcINTEGRATOR].dbo.Model M ON M.ModelID = MD.ModelID AND M.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND M.ModelBM & MO.ModelBM > 0 AND M.Introduced < ''' + @Version + ''' AND M.SelectYN <> 0
					WHERE
						P.PropertyID NOT BETWEEN 0 AND 1000 AND
						P.DataTypeID = 3 AND
						P.Introduced < ''' + @Version + ''' AND
						P.SelectYN <> 0 AND
						P.[DependentDimensionID] <> 0 AND
						NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.MappedObject MO WHERE MO.Entity = ''-1'' AND MO.ObjectName = P.PropertyName AND MO.ObjectTypeBM & 4 > 0) AND
						NOT EXISTS (SELECT 1 FROM #Property Prop WHERE Prop.ObjectName = P.PropertyName AND Prop.ObjectTypeBM & 4 > 0)
					GROUP BY
						P.PropertyName
					ORDER BY
						P.PropertyName'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

				--pcEXCHANGE Dimension & Property
				IF @Debug <> 0
					BEGIN
						SELECT * FROM #Entity
						SELECT * FROM #Model
						SELECT DISTINCT
							TempTable = '#Property',
							Entity =  MAX(Entity),
							ObjectName = ObjectName,
							DimensionTypeID = MAX(DimensionTypeID),
							MappedObjectName = MAX(MappedObjectName),
							ObjectTypeBM =  MAX(ObjectTypeBM),
							ModelBM = SUM(ModelBM),
							[MappingTypeID] =  MAX([MappingTypeID]),
							SelectYN = MAX(SelectYN)
						FROM
							#Property
						GROUP BY
							ObjectName
					END

				SET @SQLStatement = '
				UPDATE MO
				SET
					[MappedObjectName] = D.[MappedObjectName]
				FROM
					' + @ETLDatabase + '.[dbo].[MappedObject] MO
					INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] pcID ON pcID.DimensionName = MO.ObjectName AND pcID.DimensionTypeID = MO.DimensionTypeID
					INNER JOIN #Dimension D ON D.DimensionID = pcID.[DimensionID] AND D.DimensionTypeID = pcID.DimensionTypeID
				WHERE
					MO.ObjectTypeBM & 2 > 0 AND
					NOT (MO.DimensionTypeID = 21 AND MO.MappedObjectName = ''BaseCurrency'') AND
					NOT (MO.DimensionTypeID = 30 AND MO.MappedObjectName = ''AccountManager'')'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

				SET @SQLStatement = '
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
				SELECT
					[Entity] = sub.[Entity],
					[ObjectName] = sub.[ObjectName],
					[DimensionTypeID] = MAX(sub.[DimensionTypeID]),
					[MappedObjectName] = MAX(sub.[MappedObjectName]),
					[ObjectTypeBM] = SUM(sub.[ObjectTypeBM]),
					[ModelBM] = MAX(sub.[ModelBM]),
					[MappingTypeID] = MAX(sub.[MappingTypeID]),
					[SelectYN] = MAX(sub.[SelectYN])
				FROM'
				SET @SQLStatement = @SQLStatement + '
					(
				--Dimension
					SELECT DISTINCT
						[Entity],
						[ObjectName],
						[DimensionTypeID],
						[MappedObjectName],
						[ObjectTypeBM],
						[ModelBM],
						[MappingTypeID],
						[SelectYN]
					FROM
						#Dimension
				--Property
					UNION SELECT DISTINCT
						Entity =  MAX(Entity),
						ObjectName = ObjectName,
						DimensionTypeID = MAX(DimensionTypeID),
						MappedObjectName = MAX(MappedObjectName),
						ObjectTypeBM =  MAX(ObjectTypeBM),
						ModelBM = SUM(ModelBM),
						[MappingTypeID] =  MAX([MappingTypeID]),
						SelectYN = MAX(SelectYN)
					FROM
						#Property
					GROUP BY
						ObjectName
					) sub
				WHERE
					NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[MappedObject] MO WHERE MO.Entity = sub.[Entity] AND MO.ObjectName = sub.[ObjectName])
				GROUP BY
					sub.[Entity],
					sub.[ObjectName]'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

			DROP TABLE #Entity
			DROP TABLE #Model
			DROP TABLE #Dimension
			DROP TABLE #Property

			FETCH NEXT FROM pcEXCHANGE_Source_Cursor INTO @SourceDatabase
			END

		CLOSE pcEXCHANGE_Source_Cursor
		DEALLOCATE pcEXCHANGE_Source_Cursor

	SET @Step = 'Adjustments'
		SET @SQLStatement = '
			UPDATE ' + @ETLDatabase + '.[dbo].[MappedObject]
			SET [ModelBM] = 0
			WHERE [ObjectTypeBM] = 4'

			IF @Debug <> 0 PRINT @SQLStatement 
			EXEC (@SQLStatement)

	SET @Step = 'Translation'
		CREATE Table #MappedObjectName (ObjectName nvarchar(100), MappedObjectName nvarchar(100), ObjectTypeBM int)
		
		SET @SQLStatement = '
			INSERT INTO #MappedObjectName
			(ObjectName, MappedObjectName, ObjectTypeBM)
			SELECT [ObjectName], [MappedObjectName], [ObjectTypeBM]
			FROM ' + @ETLDatabase + '..MappedObject
			WHERE Entity = ''-1'''

			IF @Debug <> 0 PRINT @SQLStatement 
			EXEC (@SQLStatement)

		DECLARE Translation_Cursor CURSOR FOR

		SELECT
			[ObjectName],
			[MappedObjectName],
			[ObjectTypeBM]
		FROM
			#MappedObjectName
		ORDER BY
			[MappedObjectName]

		OPEN Translation_Cursor

		FETCH NEXT FROM Translation_Cursor INTO @ObjectName, @MappedObjectName, @ObjectTypeBM

		WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC [dbo].[spGet_Translation] @BaseLanguageID = 1, @TranslatedLanguageID = @LanguageID, @ObjectTypeBM = @ObjectTypeBM, @BaseWord = @MappedObjectName, @TranslatedWord = @TranslatedWord OUTPUT

				SET @SQLStatement = '
					UPDATE ' + @ETLDatabase + '..MappedObject
					SET MappedObjectName = ''' + @TranslatedWord + '''
					WHERE Entity = ''-1'' AND ObjectName = ''' + @ObjectName + ''''

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

				SET @TranslatedWord = NULL

			FETCH NEXT FROM Translation_Cursor INTO @ObjectName, @MappedObjectName, @ObjectTypeBM
			END

		CLOSE Translation_Cursor
		DEALLOCATE Translation_Cursor

		DROP TABLE #MappedObjectName

	SET @Step = 'Show inserted content in the MappedObject table'
		SET @SQLStatement =
			'SELECT * FROM ' + @ETLDatabase + '.[dbo].MappedObject'
		EXEC (@SQLStatement)

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
