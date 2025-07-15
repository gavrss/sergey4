SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Dimension_View_FullAccount] 

	@SourceID int = NULL,
	@DimensionID int = -53,
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

--EXEC spCreate_Dimension_View_FullAccount @SourceID = 107,  @Debug = true --E9
--EXEC spCreate_Dimension_View_FullAccount @SourceID = 1107, @Debug = true --E10
--EXEC spCreate_Dimension_View_FullAccount @SourceID = 1167, @Debug = true --E10.1
--EXEC spCreate_Dimension_View_FullAccount @SourceID = 307,  @Debug = true --iScala
--EXEC spCreate_Dimension_View_FullAccount @SourceID = 907,  @Debug = true --Axapta
--EXEC spCreate_Dimension_View_FullAccount @SourceID = 1227, @Debug = true --Enterprise

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SQLStatement_Base nvarchar(max),
	@SQLStatement_Select nvarchar(max),
	@SQLStatement_RawSelect nvarchar(max) = '',
	@SQLStatement_Account nvarchar(max) = '',
--	@SQLStatement_RawEntity nvarchar(max) = '',
	@SQLStatement_RawFrom nvarchar(max) = '',
	@SQLStatement_RawWhere nvarchar(max) = '',
	@SQLStatement_RawGroupBy nvarchar(max) = '',
	@SQLStatement_SegmentProperty_RawSelect nvarchar(max) = '',
	@SQLStatement_SegmentProperty_Join nvarchar(max) = '',
	@SQLStatement_SegmentProperty_None nvarchar(1000) = '',
	@SQLStatement_SegmentProperty_NoneList nvarchar(2000) = '',
	@SQLStatement_SubQuery nvarchar(max) = '',
	@SQLStatement_SQ_Segment nvarchar(1000) = '',
	@SQLStatement_SQ_From nvarchar(max) = '',
	@SQLStatement_SQ_Where nvarchar(max) = '',
	@SQLStatement_SQ_GroupBy nvarchar(max) = '',
	@SubQuery nvarchar(50),
	@ActionStatement nvarchar(1000),
	@Action nvarchar(10),
	@InstanceID int,
	@ApplicationID int,
	@SourceType nvarchar(50),
	@SourceTypeBM int,
	@SourceTypeFamilyID int,
	@RevisionBM int,
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(100),
	@ETLDatabase_Linked nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@SourceID_varchar nvarchar(10),
	@EntityCode nvarchar(50),
	@ObjectName nvarchar(50),
	@Dimension nvarchar(50),
	@DimensionName nvarchar(50),
	@SegmentCode nvarchar(50),
	@ModelBM int,
	@OptFinanceDimYN bit,
	@SourceDBTypeID int,
	@SourceTypeID int,
	@Owner nvarchar(50),
	@Description nvarchar(255),
	@SequenceBM int = 1,
	@Counter int = 1,
	@TotalCount int = 0,
	@Introduced nvarchar(50),
	@Version nvarchar(50) = '1.4.0.2136'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2071' SET @Description = 'Dimension introduced.'
		IF @Version = '1.3.2073' SET @Description = 'Handle @RevisionBM (BudgetCode Epicor 10.1)'
		IF @Version = '1.3.2076' SET @Description = 'Sortorder implemented'
		IF @Version = '1.3.2077' SET @Description = 'Handle Enterprise'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2095' SET @Description = 'Added RNodeType'
		IF @Version = '1.3.2096' SET @Description = 'Handle ETLDatabase_Linked'
		IF @Version = '1.3.2104' SET @Description = 'Handle Axapta'
		IF @Version = '1.3.2109' SET @Description = 'Fixed MemberIDs for all Static Members.'
		IF @Version = '1.3.0.2119' SET @Description = 'Handle HelpText.'
		IF @Version = '1.4.0.2128' SET @Description = 'Handle pcPlaceHolder.'
		IF @Version = '1.4.0.2129' SET @Description = 'Hierarchy depends on Account.'
		IF @Version = '1.4.0.2130' SET @Description = 'Handle SubQuery.'
		IF @Version = '1.4.0.2136' SET @Description = 'Test on not yet implemented Properties.'
		 
		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID IS NULL
	BEGIN
		PRINT 'Parameter @SourceID must be set'
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

		SET @SourceID_varchar = CASE WHEN @SourceID <= 9 THEN '000' ELSE CASE WHEN @SourceID <= 99 THEN '00' ELSE CASE WHEN @SourceID <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, @SourceID)

		SELECT
			@InstanceID = A.InstanceID,
			@SourceTypeID = S.SourceTypeID,
			@SourceType = ST.SourceTypeName,
			@SourceTypeBM = ST.SourceTypeBM,
			@SourceTypeFamilyID = ST.SourceTypeFamilyID,
			@SourceDBTypeID = 	ST.SourceDBTypeID,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase_Linked = '[' + REPLACE(REPLACE(REPLACE(S.ETLDatabase_Linked, '[', ''), ']', ''), '.', '].[') + ']',
			@DestinationDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ApplicationID = A.ApplicationID,
			@ModelBM = BM.ModelBM,
			@OptFinanceDimYN = BM.OptFinanceDimYN
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN Model M ON M.ModelID = S.ModelID
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
		WHERE
			SourceID = @SourceID

		CREATE TABLE #DimensionName
			(
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		SET @ActionStatement = '
		INSERT INTO #DimensionName
			(
			DimensionName
			)
		SELECT
			MappedObjectName
		FROM
			Dimension D 
			INNER JOIN ' + @ETLDatabase + '..MappedObject MO ON MO.ObjectName = D.DimensionName AND MO.ObjectTypeBM & 2 > 0
		WHERE
			D.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID)

		EXEC (@ActionStatement)
		SELECT @DimensionName = [DimensionName] FROM #DimensionName
		DROP TABLE #DimensionName

		EXEC [spGet_Owner] @SourceTypeID, @Owner OUTPUT
		EXEC [spGet_Revision] @SourceID = @SourceID, @RevisionBM = @RevisionBM OUT
		
		SELECT @Introduced = Introduced FROM Dimension WHERE DimensionID = -53

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		IF @Debug <> 0 SELECT SourceID = @SourceID, DimensionID = @DimensionID, DimensionName = @DimensionName, SourceTypeFamilyID = @SourceTypeFamilyID, SourceTypeBM = @SourceTypeBM, SourceTypeID = @SourceTypeID, [Owner] = @Owner

	SET @Step = 'Check Introduced'
		IF @Introduced > @Version RETURN

	SET @Step = 'Check Model type'
		IF @OptFinanceDimYN = 0 RETURN

/*
	SET @Step = 'Check Source DBType'
		IF @SourceDBTypeID = 2 
			BEGIN
				--Not yet handled
				RETURN
			END
*/

	SET @Step = 'Create Temp table'
		CREATE TABLE #SourceDatabase
			(
			EntityCode nvarchar(50) COLLATE DATABASE_DEFAULT,
			SourceDatabase nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #SQLStatement_Select
			(
			SQLStatement_Select nvarchar(1000) COLLATE DATABASE_DEFAULT,
			Property nvarchar(100) COLLATE DATABASE_DEFAULT,
			SortOrder int
			)

	SET @Step = 'Create static part of SQL'
		SELECT 
			P.PropertyID,
			P.PropertyName,
			P.DatatypeID,
			SourceString = ISNULL(SSD.SourceString, P.DefaultValueView),
			SubQuery = ISNULL(SSD.SubQuery, ''),
			P.SortOrder 
		INTO
			#Property
		FROM
			Dimension D
--			LEFT JOIN Dimension_Property DP ON DP.DimensionID = D.DimensionID AND DP.Introduced < @Version AND DP.SelectYN <> 0
--			LEFT JOIN Property P ON P.PropertyID <> 0 AND (P.PropertyID = DP.PropertyID OR (P.DimensionID = 0 AND P.PropertyID NOT BETWEEN 100 AND 1000)) AND P.SourceTypeBM & @SourceTypeBM > 0 AND P.Introduced < @Version AND P.SelectYN <> 0
			INNER JOIN Property P ON P.PropertyID <> 0 AND (P.DimensionID = D.DimensionID OR (P.DimensionID = 0 AND P.PropertyID NOT BETWEEN 100 AND 1000)) AND P.SourceTypeBM & @SourceTypeBM > 0 AND P.Introduced < @Version AND P.SelectYN <> 0
			LEFT JOIN SqlSource_Dimension SSD ON SSD.DimensionID = D.DimensionID AND SSD.SourceTypeBM & @SourceTypeBM > 0 AND SSD.RevisionBM & @RevisionBM > 0 AND SSD.ModelBM & @ModelBM > 0 AND SSD.PropertyID = P.PropertyID AND SSD.SequenceBM & @SequenceBM > 0 AND SSD.SelectYN <> 0
		WHERE
			D.DimensionID = @DimensionID AND
			D.Introduced < @Version

		IF @Debug <> 0 SELECT TempTable = '#Property', * FROM #Property ORDER BY SortOrder, PropertyName

		SELECT @SubQuery = MAX(SubQuery) FROM #Property

		SELECT
			@SQLStatement_RawSelect = ISNULL(@SQLStatement_RawSelect, '') + CASE WHEN sub.PropertyID NOT IN (1) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + sub.PropertyName + '] = ' + sub.[SourceString]  + CASE WHEN sub.SortOrder = 80 THEN '' ELSE ',' END ELSE '' END,
			@SQLStatement_SegmentProperty_Join = ISNULL(@SQLStatement_SegmentProperty_Join, '') + CASE WHEN sub.DataTypeID = 3 AND sub.PropertyName <> 'SegmentProperty' THEN CHAR(13) + CHAR(10) + CHAR(9) + 'LEFT JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + sub.PropertyName + '] [' + sub.PropertyName + '] ON [' + sub.PropertyName + '].Label COLLATE DATABASE_DEFAULT = [sub].[' + sub.PropertyName + ']' ELSE '' END
		FROM
			#Property sub
		WHERE
			(SubQuery <> @SubQuery OR @SubQuery = '')
		ORDER BY
			sub.SortOrder,
			sub.PropertyName

		INSERT INTO #SQLStatement_Select
			(
			SQLStatement_Select,
			Property,
			SortOrder
			)
		SELECT
			SQLStatement_Select = '[' + PropertyName + '] = ' + CASE WHEN PropertyID IN (1) THEN [SourceString] ELSE 'sub.[' +  PropertyName + ']' END + CASE WHEN SortOrder <> 80 THEN ',' ELSE '' END,
			Property = PropertyName,
			SortOrder
		FROM
			#Property
		WHERE
			PropertyName <> 'SegmentProperty' AND
			(SubQuery <> @SubQuery OR @SubQuery = '')

		INSERT INTO #SQLStatement_Select
			(
			SQLStatement_Select,
			Property,
			SortOrder
			)
		SELECT
			SQLStatement_Select = '[' + PropertyName + '_MemberId] = ISNULL([' + PropertyName + '].[MemberId], -1),', 
			Property = PropertyName,
			SortOrder
		FROM
			#Property
		WHERE
			DataTypeID = 3 AND
			PropertyName <> 'SegmentProperty' AND
			(SubQuery <> @SubQuery OR @SubQuery = '')

		SELECT
			@SQLStatement_RawFrom = ISNULL(@SQLStatement_RawFrom, '') + CASE WHEN SSD.PropertyID = 100 THEN SSD.SourceString ELSE '' END,
			@SQLStatement_RawWhere = ISNULL(@SQLStatement_RawWhere, '') + CASE WHEN SSD.PropertyID = 200 THEN SSD.SourceString ELSE '' END,
			@SQLStatement_RawGroupBy = ISNULL(@SQLStatement_RawGroupBy, '') + CASE WHEN SSD.PropertyID = 300 THEN SSD.SourceString ELSE '' END
		FROM
			pcINTEGRATOR.dbo.SqlSource_Dimension SSD
		WHERE
			(SSD.SubQuery <> @SubQuery OR @SubQuery = '') AND
			SSD.SequenceBM & @SequenceBM > 0 AND
			SSD.DimensionID = @DimensionID AND 
			SSD.SourceTypeBM & @SourceTypeBM > 0 AND
			SSD.RevisionBM & @RevisionBM > 0 AND
			SSD.ModelBM & @ModelBM > 0 AND
			SSD.PropertyID IN (100, 200, 300) AND
			SSD.SelectYN <> 0

		IF @SubQuery > ''
			BEGIN
				SELECT
					@SQLStatement_SubQuery = ISNULL(@SQLStatement_SubQuery, '') + CASE WHEN sub.PropertyID NOT IN (1) THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + sub.PropertyName + '] = ' + sub.[SourceString]  + CASE WHEN sub.PropertyID = -164 THEN '' ELSE ',' END ELSE '' END
				FROM
					#Property sub
				WHERE
					SubQuery = @SubQuery
				ORDER BY
					sub.SortOrder,
					sub.PropertyName
				
				PRINT @SQLStatement_SubQuery


				SELECT
					@SQLStatement_SQ_From = ISNULL(@SQLStatement_SQ_From, '') + CASE WHEN SSD.PropertyID = 100 THEN SSD.SourceString ELSE '' END,
					@SQLStatement_SQ_Where = ISNULL(@SQLStatement_SQ_Where, '') + CASE WHEN SSD.PropertyID = 200 THEN SSD.SourceString ELSE '' END,
					@SQLStatement_SQ_GroupBy = ISNULL(@SQLStatement_SQ_GroupBy, '') + CASE WHEN SSD.PropertyID = 300 THEN SSD.SourceString ELSE '' END
				FROM
					pcINTEGRATOR.dbo.SqlSource_Dimension SSD
				WHERE
					SSD.SubQuery = @SubQuery AND @SubQuery > '' AND
					SSD.SequenceBM & @SequenceBM > 0 AND
					SSD.DimensionID = @DimensionID AND 
					SSD.SourceTypeBM & @SourceTypeBM > 0 AND
					SSD.RevisionBM & @RevisionBM > 0 AND
					SSD.ModelBM & @ModelBM > 0 AND
					SSD.PropertyID IN (100, 200, 300) AND
					SSD.SelectYN <> 0

				SET @SQLStatement_SubQuery = '
		(
		SELECT' + @SQLStatement_SubQuery + '
		FROM' + CHAR(13) + CHAR(10) + @SQLStatement_SQ_From + CASE WHEN LEN(@SQLStatement_SQ_Where) > 0 THEN 'WHERE' + CHAR(13) + CHAR(10) + @SQLStatement_SQ_Where ELSE '' END + '
		GROUP BY' + CHAR(13) + CHAR(10) + @SQLStatement_SQ_GroupBy + '
		) ' + @SubQuery

			END

	SET @Step = 'Fill SourceDatabase cursor table'
		IF @SourceDBTypeID = 1 --Single
			INSERT INTO #SourceDatabase
				(
				EntityCode,
				SourceDatabase
				)
			SELECT
				EntityCode = '-1',
				SourceDatabase = @SourceDatabase
		ELSE IF @SourceDBTypeID = 2 --Multiple
			BEGIN
				IF @SourceTypeBM & 4096 > 0 --Enterprise
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #SourceDatabase
								(
								EntityCode,
								SourceDatabase
								)
							SELECT DISTINCT
								EntityCode,
								SourceDatabase = Par01
							FROM
								' + @ETLDatabase + '..Entity
							WHERE
								SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
								SelectYN <> 0'
					END
				ELSE
					BEGIN
						SET @SQLStatement = ''
					END
				EXEC (@SQLStatement)
			END

	SET @Step = 'Create SourceDatabase cursor'
		DECLARE SourceDatabase_Cursor CURSOR FOR

			SELECT DISTINCT
				EntityCode,
				SourceDatabase
			FROM
				#SourceDatabase
			ORDER BY
				EntityCode

			OPEN SourceDatabase_Cursor
			FETCH NEXT FROM SourceDatabase_Cursor INTO @EntityCode, @SourceDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Counter >= 2
						SET @SQLStatement_Base = @SQLStatement_Base + CHAR(13) + CHAR(10) + CHAR(9) + 'UNION' + CHAR(13) + CHAR(10)
					ELSE
						 SET @SQLStatement_Base = ''

					SET @SQLStatement_Base = @SQLStatement_Base + '
	SELECT'
		+ @SQLStatement_RawSelect + '
	FROM
'		+ @SQLStatement_RawFrom + 
		CASE WHEN @SQLStatement_RawWhere = '' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + 'WHERE' + CHAR(13) + CHAR(10) + @SQLStatement_RawWhere END +
		CASE WHEN @SQLStatement_RawGroupBy = '' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + 'GROUP BY' + CHAR(13) + CHAR(10) + @SQLStatement_RawGroupBy END

/*
					SET @SQLStatement_Base = REPLACE (@SQLStatement_Base, '@EntityCode', @EntityCode)
					SET @SQLStatement_Base = REPLACE (@SQLStatement_Base, '@SourceDatabase', @SourceDatabase)
*/
					SET @Counter = @Counter + 1
				
					FETCH NEXT FROM SourceDatabase_Cursor INTO @EntityCode, @SourceDatabase
				END

		CLOSE SourceDatabase_Cursor
		DEALLOCATE SourceDatabase_Cursor		

		SET @SQLStatement = @SQLStatement_Base

	SET @Step = 'Create dynamic part of SQL'
		CREATE TABLE #ColumnList
			(
			ShortPropertyName nvarchar(100) COLLATE DATABASE_DEFAULT,
			SortOrder int
			)

		INSERT INTO #ColumnList EXEC spGet_FieldList @SourceID = @SourceID, @DimensionID = @DimensionID, @SortOrder = 32

		IF @SourceTypeFamilyID = 4
			INSERT INTO #ColumnList EXEC spGet_FieldList @SourceID = @SourceID, @DimensionID = @DimensionID, @SortOrder = 31

		IF @Debug <> 0 SELECT TempTable = '#ColumnList', * FROM #ColumnList

		CREATE TABLE [dbo].[#Segment](
			[Counter] [int] IDENTITY(1,1) NOT NULL,
			[MappedObjectName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
		 CONSTRAINT [PK_Segment] PRIMARY KEY CLUSTERED 
		(
			[Counter] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]

		SET @ActionStatement = '
			INSERT INTO #Segment
				(
				[MappedObjectName]
				)
			SELECT DISTINCT
				MO.[MappedObjectName]
			FROM
				' + @ETLDatabase + '.[dbo].[MappedObject] MO
				INNER JOIN #ColumnList CL ON CL.ShortPropertyName = MO.MappedObjectName
			WHERE
				(MO.DimensionTypeID = -1 OR (MO.DimensionTypeID = 1 AND ' + CONVERT(nvarchar(10), @SourceTypeFamilyID) + ' = 4)) AND 
				MO.ObjectTypeBM & 2 > 0 AND
				MO.SelectYN <> 0
			ORDER BY
				MO.[MappedObjectName]'
		EXEC (@ActionStatement)

		IF @Debug <> 0 SELECT TempTable = '#Segment', * FROM #Segment

		SELECT @TotalCount = COUNT(1) FROM #Segment
		SET @Counter = 1

		WHILE @Counter <= @TotalCount
			BEGIN
				IF @Debug <> 0 				
					SELECT
						[Counter] = @Counter,
						SQLStatement_Select = '[' + [MappedObjectName] + '] = CASE WHEN ISNULL([' + [MappedObjectName] + '].[MemberId], -1) = -1 THEN ''NONE'' ELSE sub.[' + [MappedObjectName] + '] END,',
						Property = [MappedObjectName],
						SortOrder = FL.SortOrder
					FROM
						#Segment S
						INNER JOIN #ColumnList FL ON FL.ShortPropertyName = S.MappedObjectName
					WHERE
						[Counter] = @Counter

				SELECT
					@SQLStatement_SQ_Segment = ISNULL(@SQLStatement_SQ_Segment, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + [MappedObjectName] + '] = ' + @SubQuery + '.[' + [MappedObjectName] + ']' + CASE WHEN @TotalCount <> @Counter THEN ',' ELSE '' END,
--					@SQLStatement_SegmentProperty_RawSelect = ISNULL(@SQLStatement_SegmentProperty_RawSelect, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + [MappedObjectName] + '] = MAX(CASE WHEN MO.MappedObjectName = ''' + [MappedObjectName] + ''' AND MO.MappingTypeID = 1 THEN E.Entity + ''_'' ELSE '''' END) + CASE MAX(CASE WHEN MO.MappedObjectName = ''' + [MappedObjectName] + ''' THEN FS.SegmentNbr ELSE 0 END) WHEN 1 THEN MAX(GLA.SegValue1) WHEN 2 THEN MAX(GLA.SegValue2) WHEN 3 THEN MAX(GLA.SegValue3) WHEN 4 THEN MAX(GLA.SegValue4) WHEN 5 THEN MAX(GLA.SegValue5) WHEN 6 THEN MAX(GLA.SegValue6) WHEN 7 THEN MAX(GLA.SegValue7) WHEN 8 THEN MAX(GLA.SegValue8) WHEN 9 THEN MAX(GLA.SegValue9) WHEN 10 THEN MAX(GLA.SegValue10) WHEN 11 THEN MAX(GLA.SegValue11) WHEN 12 THEN MAX(GLA.SegValue12) WHEN 13 THEN MAX(GLA.SegValue13) WHEN 14 THEN MAX(GLA.SegValue14) WHEN 15 THEN MAX(GLA.SegValue15) WHEN 16 THEN MAX(GLA.SegValue16) WHEN 17 THEN MAX(GLA.SegValue17) WHEN 18 THEN MAX(GLA.SegValue18) WHEN 19 THEN MAX(GLA.SegValue19) WHEN 20 THEN MAX(GLA.SegValue20) ELSE ''NONE'' END COLLATE DATABASE_DEFAULT + MAX(CASE WHEN MO.MappedObjectName = ''' + [MappedObjectName] + ''' AND MO.MappingTypeID = 2 THEN ''_'' + E.Entity ELSE '''' END)' + CASE WHEN @TotalCount <> @Counter THEN ',' ELSE '' END,
					@SQLStatement_SegmentProperty_RawSelect = ISNULL(@SQLStatement_SegmentProperty_RawSelect, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CASE WHEN @SubQuery > '' THEN CHAR(9) ELSE '' END + '[' + [MappedObjectName] + '] = ' + CASE WHEN @SourceTypeFamilyID IN (1, 3) THEN 'MAX(CASE WHEN MO.MappedObjectName = ''' + [MappedObjectName] + ''' AND MO.MappingTypeID = 1 THEN E.Entity + ''_'' ELSE '''' END) + CASE MAX(CASE WHEN MO.MappedObjectName = ''' + [MappedObjectName] + ''' THEN FS.SegmentNbr ELSE 0 END) ' ELSE '' END + 
						CASE @SourceTypeFamilyID
							WHEN 1 THEN 'WHEN 1 THEN MAX(GLA.SegValue1) WHEN 2 THEN MAX(GLA.SegValue2) WHEN 3 THEN MAX(GLA.SegValue3) WHEN 4 THEN MAX(GLA.SegValue4) WHEN 5 THEN MAX(GLA.SegValue5) WHEN 6 THEN MAX(GLA.SegValue6) WHEN 7 THEN MAX(GLA.SegValue7) WHEN 8 THEN MAX(GLA.SegValue8) WHEN 9 THEN MAX(GLA.SegValue9) WHEN 10 THEN MAX(GLA.SegValue10) WHEN 11 THEN MAX(GLA.SegValue11) WHEN 12 THEN MAX(GLA.SegValue12) WHEN 13 THEN MAX(GLA.SegValue13) WHEN 14 THEN MAX(GLA.SegValue14) WHEN 15 THEN MAX(GLA.SegValue15) WHEN 16 THEN MAX(GLA.SegValue16) WHEN 17 THEN MAX(GLA.SegValue17) WHEN 18 THEN MAX(GLA.SegValue18) WHEN 19 THEN MAX(GLA.SegValue19) WHEN 20 THEN MAX(GLA.SegValue20)'
							WHEN 2 THEN 'iScala, not yet implemented'
							WHEN 3 THEN 'WHEN 1 THEN MAX(GLA.seg1_code) WHEN 2 THEN MAX(GLA.seg2_code) WHEN 3 THEN MAX(GLA.seg3_code) WHEN 4 THEN MAX(GLA.seg4_code)'
							WHEN 4 THEN 'ISNULL(MAX(CASE WHEN MON.MappedObjectName = ''' + [MappedObjectName] + ''' THEN DV.SegmentLabel END), ''NONE'')'
							ELSE '@SourceTypeFamilyID = ' + CONVERT(nvarchar(10), @SourceTypeFamilyID) + ' not yet implemented'
						END
						+ CASE WHEN @SourceTypeFamilyID IN (1, 3) THEN ' ELSE ''NONE'' END COLLATE DATABASE_DEFAULT + MAX(CASE WHEN MO.MappedObjectName = ''' + [MappedObjectName] + ''' AND MO.MappingTypeID = 2 THEN ''_'' + E.Entity ELSE '''' END)' ELSE '' END + CASE WHEN @TotalCount <> @Counter THEN ',' ELSE '' END,

--					@SQLStatement_RawEntity = ISNULL(@SQLStatement_RawEntity, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + [MappedObjectName] + '] = ''NONE'',',
					@SQLStatement_SegmentProperty_Join = ISNULL(@SQLStatement_SegmentProperty_Join, '') + CHAR(13) + CHAR(10) + CHAR(9) + 'LEFT JOIN ' + @DestinationDatabase + '.[dbo].[S_DS_' + [MappedObjectName] + '] [' + [MappedObjectName] + '] ON [' + [MappedObjectName] + '].Label COLLATE DATABASE_DEFAULT = [sub].[' + [MappedObjectName] + ']',
					@SQLStatement_SegmentProperty_None = ISNULL(@SQLStatement_SegmentProperty_None, '') + '''NONE'',',
					@SQLStatement_SegmentProperty_NoneList = ISNULL(@SQLStatement_SegmentProperty_NoneList, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + [MappedObjectName] + '] = ''NONE'','
				FROM
					#Segment
				WHERE
					[Counter] = @Counter

				INSERT INTO #SQLStatement_Select
					(
					SQLStatement_Select,
					Property,
					SortOrder
					)
				SELECT
					SQLStatement_Select = '[' + [MappedObjectName] + '] = CASE WHEN ISNULL([' + [MappedObjectName] + '].[MemberId], -1) = -1 THEN ''NONE'' ELSE sub.[' + [MappedObjectName] + '] END,',
					Property = [MappedObjectName],
					SortOrder = FL.SortOrder
				FROM
					#Segment S
					INNER JOIN #ColumnList FL ON FL.ShortPropertyName = S.MappedObjectName
				WHERE
					[Counter] = @Counter

				INSERT INTO #SQLStatement_Select
					(
					SQLStatement_Select,
					Property,
					SortOrder
					)
				SELECT
					SQLStatement_Select = '[' + [MappedObjectName] + '_MemberId] = ISNULL([' + [MappedObjectName] + '].[MemberId], -1),',
					Property = [MappedObjectName],
					SortOrder = FL.SortOrder
				FROM
					#Segment S
					INNER JOIN #ColumnList FL ON FL.ShortPropertyName = S.MappedObjectName
				WHERE
					[Counter] = @Counter

				SET @Counter = @Counter + 1
			END

			SET @SQLStatement_Account = '
	SELECT
		[MemberId] = A.MemberId,
		[Label] = A.Label,
		[Description] = A.[Description],
		[AlfaDescription] = A.[Description],
		[Entity] = ''NONE'',
		[Account] = ''NONE'',' + @SQLStatement_SegmentProperty_NoneList + '
		[HelpText] = A.[HelpText],
		[RNodeType] = A.[RNodeType],
		[SBZ] = 1,
		[Source] = A.[Source],
		[SortOrder] = H.SequenceNumber,
		[Parent] = AP.Label
	FROM
		' + @DestinationDatabase + '..S_DS_Account A
		INNER JOIN ' + @DestinationDatabase + '..S_HS_Account_Account H ON H.MemberId = A.MemberId
		INNER JOIN ' + @DestinationDatabase + '..S_DS_Account AP ON AP.MemberId = H.ParentMemberId
	WHERE
		A.MemberID <> 1 AND
		(A.MemberID >= 1001 OR A.MemberID IN (276, 277, 290, 401, 402, 403, 404, 405)) AND
		A.RNodeType = ''P'''


/*
		IF @SourceTypeFamilyID IN (1, 3)
			SET @SQLStatement_RawEntity = '
	UNION SELECT
		[MemberId] = NULL,
		[Label] = E.Entity,
		[Description] = EntityName,
		[AlfaDescription] = EntityName,
		[Entity] = E.Entity,
		' + CASE WHEN @SourceTypeFamilyID IN (1, 3) THEN '[Account] = ''NONE'',' ELSE '' END + @SQLStatement_RawEntity + '
		[HelpText] = EntityName,
		[RNodeType] = ''P'',
		[SBZ] = 1,
		[Source] = ''@SourceType'',
		[Parent] = ''All_''
	FROM
		' + @ETLDatabase + '.[dbo].[Entity] E
	WHERE
		E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
		E.SelectYN <> 0'
		ELSE
			SET @SQLStatement_RawEntity = ''
*/
		IF @Debug <> 0 SELECT TempTable = '#SQLStatement_Select', * FROM #SQLStatement_Select ORDER BY SortOrder, Property, SQLStatement_Select

		SELECT
			@SQLStatement_Select = ISNULL(@SQLStatement_Select, '') + CHAR(13) + CHAR(10) + CHAR(9) + SQLStatement_Select
		FROM
			#SQLStatement_Select
		ORDER BY
			SortOrder,
			Property,
			SQLStatement_Select

		IF @Debug <> 0 PRINT @SQLStatement_Select

	SET @Step = 'Replace variables'
		SET @SQLStatement = REPLACE (@SQLStatement, '@SQ', ISNULL(@SQLStatement_SubQuery, ''))
		SET @SQLStatement = REPLACE (@SQLStatement, '@ETLDatabase_Linked', ISNULL(@ETLDatabase_Linked, @ETLDatabase))
		SET @SQLStatement = REPLACE (@SQLStatement, '@DestinationDatabase', @DestinationDatabase)
		SET @SQLStatement = REPLACE (@SQLStatement, '@EntityCode', @EntityCode)
		SET @SQLStatement = REPLACE (@SQLStatement, '@SourceDatabase', @SourceDatabase)
		SET @SQLStatement = REPLACE (@SQLStatement, '@Owner', @Owner)
		SET @SQLStatement = REPLACE (@SQLStatement, '@SourceType', @SourceType)
--		SET @SQLStatement_RawEntity = REPLACE (@SQLStatement_RawEntity, '@SourceType', @SourceType)
		SET @SQLStatement = REPLACE (@SQLStatement, '@SourceID_varchar', @SourceID_varchar)
		SET @SQLStatement = REPLACE (@SQLStatement, '@SourceID', @SourceID)
		SET @SQLStatement = REPLACE (@SQLStatement, '@DimensionID', @DimensionID)
		SET @SQLStatement = REPLACE (@SQLStatement, '@ModelBM', @ModelBM)
		SET @SQLStatement = REPLACE (@SQLStatement, '[SegmentProperty] = @SegmentProperty_SQ', @SQLStatement_SQ_Segment)
		SET @SQLStatement = REPLACE (@SQLStatement, '[SegmentProperty] = @SegmentProperty', @SQLStatement_SegmentProperty_RawSelect)
		

	SET @Step = 'Create complete statement'
		SET @SQLStatement = '
SELECT TOP 1000000'
	+ @SQLStatement_Select + '
FROM
	('	+ @SQLStatement_Account + '

	UNION
'		+ @SQLStatement + '
	UNION SELECT 
		1, ''All_'', ''All FullAccounts'', ''All FullAccounts'', ''NONE'', ' + CASE WHEN @SourceTypeFamilyID IN (1, 3) THEN '''NONE'', ' ELSE '' END + @SQLStatement_SegmentProperty_None + '''All FullAccounts'', ''P'', 1, ''ETL'',  0, NULL
	UNION SELECT 
		-1, ''NONE'', ''None'', ''None'', ''NONE'', ' + CASE WHEN @SourceTypeFamilyID IN (1, 3) THEN '''NONE'', ' ELSE '' END + @SQLStatement_SegmentProperty_None + '''None'', ''L'', 0, ''ETL'', 0, ''All_''
	UNION SELECT 
		30000000, ''pcPlaceHolder'', ''Not used in any hierarchy'', ''Not used in any hierarchy'', ''NONE'', ' + CASE WHEN @SourceTypeFamilyID IN (1, 3) THEN '''NONE'', ' ELSE '' END + @SQLStatement_SegmentProperty_None + '''This aggregation level has no business meaning. The existence of this row makes sure that all manually added rows get a MemberID > 30000000.'', ''P'', 0, ''ETL'', 0, ''All_''
	) sub
'	+ @SQLStatement_SegmentProperty_Join + '
ORDER BY
	CASE WHEN [sub].[Label] IN (''All_'', ''NONE'', ''pcPlaceHolder'') OR [sub].[Label] LIKE ''%NONE%'' OR sub.MemberId <= 30000000 THEN ''  '' + [sub].[Label] ELSE [sub].[Label] END'

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Runable View', [SQLStatement] = @SQLStatement

		SET @SQLStatement = REPLACE(@SQLStatement, '''', '''''')

	SET @Step = 'Determine ObjectName'
		SET @ObjectName = 'vw_' + @SourceID_varchar + '_' + @DimensionName

	SET @Step = 'Determine CREATE or ALTER'
		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

		SET @ActionStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''V''' 
		INSERT INTO #Action ([Action]) EXEC (@ActionStatement)
		SELECT @Action = [Action] FROM #Action
		DROP TABLE #Action

		SET @ObjectName = '[' + @ObjectName + ']'

	SET @Step = 'Make Creation statement'
		SET @SQLStatement = @Action + ' VIEW [dbo].' + @ObjectName + '
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS' + CHAR(13) + CHAR(10) + @SQLStatement

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of View', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)

	SET @Step = 'Drop Temp table'
		DROP TABLE #Property
		DROP TABLE #Segment
		DROP TABLE #SourceDatabase
		DROP TABLE #ColumnList

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
