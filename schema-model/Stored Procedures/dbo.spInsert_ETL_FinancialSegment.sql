SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_ETL_FinancialSegment]

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

--EXEC [spInsert_ETL_FinancialSegment] @ApplicationID = 400, @Debug = true
--EXEC [spInsert_ETL_FinancialSegment] @ApplicationID = 1315, @Debug = true --AthensPlaza
--EXEC [spInsert_ETL_FinancialSegment] @ApplicationID = 1321, @Debug = true --Bullguard
--EXEC [spInsert_ETL_FinancialSegment] @ApplicationID = 1324, @Debug = true --Heartland
--EXEC [spInsert_ETL_FinancialSegment] @ApplicationID = 1317, @Debug = true --CBN

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SourceID int,
	@SQLStatement nvarchar(max),
	@Action nvarchar(10),
	@InstanceID int,
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(50),
	@SourceType nvarchar(50),
	@EntityCode nvarchar(50),
	@EntityName nvarchar(50),
	@TablePrefix nvarchar(255),
	@SQLDB nvarchar(255),
	@LanguageCode nchar(3),
	@SourceDBTypeID int,
	@SourceTypeFamilyID int,
	@SourceTypeID int,
	@Owner nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2098' SET @Description = 'Procedure created'
		IF @Version = '1.3.2101' SET @Description = 'Added Axapta'
		IF @Version = '1.3.2111' SET @Description = 'Added Navision'
		IF @Version = '1.3.1.2120' SET @Description = 'Changed Navision handling'
		IF @Version = '1.4.0.2133' SET @Description = 'Changed Epicor ERP handling. Added DynamicYN.'
		IF @Version = '1.4.0.2139' SET @Description = 'Added more debug.'

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

		SELECT @InstanceID = A.InstanceID FROM [Application] A WHERE A.ApplicationID = @ApplicationID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Create Source cursor'
		SELECT
			SourceID = S.SourceID,
			SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			SourceTypeID = S.SourceTypeID,
			SourceType = ST.SourceTypeName,
			SourceDBTypeID = ST.SourceDBTypeID,
			SourceTypeFamilyID = ST.SourceTypeFamilyID,
			[Owner] = ST.[Owner],
			ETLDatabase = A.ETLDatabase,
			LanguageCode = L.LanguageCode
		INTO
			#FinancialSegment_Source_Cursor
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.[OptFinanceDimYN] <> 0 AND BM.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
			INNER JOIN [Language] L ON L.LanguageID = A.LanguageID
		WHERE
			S.SelectYN <> 0

		IF @Debug <> 0 SELECT TempTable = '#FinancialSegment_Source_Cursor',* FROM #FinancialSegment_Source_Cursor ORDER BY SourceID

		DECLARE FinancialSegment_Source_Cursor CURSOR FOR

		SELECT
			SourceID,
			SourceDatabase,
			SourceTypeID,
			SourceType,
			SourceDBTypeID,
			SourceTypeFamilyID,
			[Owner],
			ETLDatabase,
			LanguageCode
		FROM
			#FinancialSegment_Source_Cursor
		ORDER BY
			SourceID

		OPEN FinancialSegment_Source_Cursor

		FETCH NEXT FROM FinancialSegment_Source_Cursor INTO @SourceID, @SourceDatabase, @SourceTypeID, @SourceType, @SourceDBTypeID, @SourceTypeFamilyID, @Owner, @ETLDatabase, @LanguageCode

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @SourceDBTypeID = 1 --Single
					BEGIN
						IF @SourceTypeFamilyID = 1 --Epicor ERP
						  BEGIN
							SET @SQLStatement = '
							INSERT INTO ' + @ETLDatabase + '.[dbo].[FinancialSegment]
							   (
							   [SourceID],
							   [EntityCode],
							   [SegmentNbr],
							   [EntityName],
							   [COACode],
							   [SegmentCode],
							   [SegmentName],
							   [Company_COACode],
							   [DimensionTypeID],
							   [DynamicYN]
							   )
							SELECT TOP 1000
								[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ',
								[EntityCode] = GLB.Company + ''_'' + GLB.[BookID],
								[SegmentNbr] = COAS.SegmentNbr,
								[EntityName] = C.Name,
								[COACode] = GLB.COACode,
								[SegmentCode] = ''SegValue'' + CONVERT(nvarchar(7), COAS.SegmentNbr),
								[SegmentName] = COAS.SegmentName,
								[Company_COACode] = GLB.Company + ''_'' + GLB.COACode,
								[DimensionTypeID] = CASE WHEN E.Par04 = COAS.SegmentName COLLATE DATABASE_DEFAULT THEN 1 ELSE -1 END,
								[DynamicYN] = COAS.[Dynamic]
							FROM
								' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COASegment] COAS ON COAS.Company = GLB.Company AND COAS.COACode = GLB.COACode
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[Company] C ON C.Company = GLB.Company
								INNER JOIN ' + @ETLDatabase + '.dbo.Entity E ON E.Par01 = GLB.Company COLLATE DATABASE_DEFAULT AND E.Par02 = GLB.BookID COLLATE DATABASE_DEFAULT AND E.Par03 = GLB.COACode COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0 AND E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + '
							WHERE
								NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS WHERE FS.[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ' AND FS.[EntityCode] = (GLB.Company + ''_'' + GLB.[BookID]) COLLATE DATABASE_DEFAULT AND FS.[SegmentNbr] = COAS.SegmentNbr)
							ORDER BY
								GLB.Company,
								GLB.COACode,
								COAS.SegmentNbr'
						   END

						ELSE IF @SourceTypeFamilyID = 4 --Axapta
						  BEGIN
							SET @SQLStatement = '
							INSERT INTO ' + @ETLDatabase + '.[dbo].[FinancialSegment]
							   (
							   [SourceID],
							   [EntityCode],
							   [SegmentNbr],
							   [EntityName],
							   [COACode],
							   [SegmentTable],
							   [SegmentCode],
							   [SegmentName],
							   [DimensionTypeID]
							   )						   
							SELECT TOP 10000
								SourceID = E.SourceID,
								EntityCode = E.EntityCode,
								SegmentNbr = DHL.LEVEL_,
								EntityName = E.EntityName,
								COACode = CONVERT(nvarchar(20), DHL.DIMENSIONHIERARCHY),
								SegmentTable = DA.VIEWNAME,
								SegmentCode = DA.RECID,
								SegmentName = DA.NAME,
								DimensionTypeID = CASE WHEN DA.TYPE = 2 THEN 1 ELSE -1 END
							FROM
								' + @SourceDatabase + '.[dbo].[DIMENSIONHIERARCHYLEVEL] DHL
								INNER JOIN ' + @SourceDatabase + '.[dbo].[DIMENSIONATTRIBUTE] DA ON DA.RECID = DHL.DIMENSIONATTRIBUTE AND DA.PARTITION = DHL.PARTITION
								INNER JOIN ' + @SourceDatabase + '.[dbo].[LEDGERSTRUCTURE] LS ON LS.DIMENSIONHIERARCHY = DHL.DIMENSIONHIERARCHY AND LS.PARTITION = DHL.PARTITION
								INNER JOIN ' + @ETLDatabase + '.[dbo].[Entity] E ON E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND E.Par01 = CONVERT(nvarchar(20), LS.LEDGER) AND E.SelectYN <> 0
							WHERE
								NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS WHERE FS.[SourceID] = E.SourceID AND FS.[EntityCode] = E.EntityCode AND FS.COACode = CONVERT(nvarchar(20), DHL.DIMENSIONHIERARCHY) AND FS.[SegmentNbr] = DHL.LEVEL_)
							ORDER BY
								E.EntityCode,
								LEVEL_'					   
						   END
						ELSE IF @SourceType = 'EvryDW'
						  BEGIN
 							SET @SQLStatement = '					
								SELECT
								 EntityCode = ''0'',
								 SegmentNbr = 0,
 								 SegmentCode = REPLACE(COLUMN_NAME, ''Key'', '''') COLLATE DATABASE_DEFAULT,
								 ObjectName = REPLACE(COLUMN_NAME, ''Key'', '''') COLLATE DATABASE_DEFAULT,
								 JoinField = COLUMN_NAME COLLATE DATABASE_DEFAULT,
								 DimensionTypeID = -1
								FROM
								 ' + @SourceDatabase + '.information_schema.columns
								WHERE
								 table_name = ''tblFctGeneralLedger'' AND
								 COLUMN_NAME LIKE ''%Key'' AND
								 COLUMN_NAME NOT IN (''GeneralLedger_Key'', ''CurrencyKey'', ''CompanyKey'', ''AccountLocalKey'', ''AccountGlobalKey'', ''ProjectKey'', ''PeriodKey'', ''PostingDateKey'', ''InventoryKey'', ''IntegrationSourceKey'') AND
								 COLUMN_NAME NOT LIKE ''AccountDimension%Key'''
						  END

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
						SET @Inserted = @Inserted + @@ROWCOUNT

					END --End of @SourceDBTypeID = 1 Single

				IF @SourceDBTypeID = 2 --Multiple
					BEGIN

						CREATE TABLE #Entity 
							(
							SQLDB nvarchar(255) COLLATE DATABASE_DEFAULT,
							EntityCode nvarchar(50) COLLATE DATABASE_DEFAULT,
							EntityName nvarchar(255) COLLATE DATABASE_DEFAULT,
							TablePrefix nvarchar(255) COLLATE DATABASE_DEFAULT
							)

						IF @SourceType = 'iScala'
						  BEGIN

							SET @SQLStatement = 
							'INSERT INTO #Entity
							 (
							 SQLDB,
							 EntityCode,
							 EntityName
							 )
							SELECT 
							 SQLDB = Par01,
							 EntityCode,
							 EntityName
							FROM
							 ' + @ETLDatabase + '.dbo.Entity
							WHERE
							 SelectYN = 1 AND
							 SourceID = ' + CONVERT(nvarchar, @SourceID) + '
							ORDER BY
							 Par01,
							 EntityCode'
		 
							IF @Debug <> 0 SELECT '#Entity',@SQLStatement
							EXEC(@SQLStatement)
							SET @SQLStatement = NULL

  							  DECLARE Entity_Cursor CURSOR FOR

								SELECT 
								 SQLDB,
								 EntityCode,
								 EntityName
								FROM
								 #Entity

								OPEN Entity_Cursor
								FETCH NEXT FROM Entity_Cursor INTO @SQLDB, @EntityCode, @EntityName

								WHILE @@FETCH_STATUS = 0
								  BEGIN
									SET @SQLStatement = '
										INSERT INTO ' + @ETLDatabase + '.[dbo].[FinancialSegment]
										   (
										   [SourceID],
										   [EntityCode],
										   [COACode],
										   [SegmentNbr],
										   [EntityName],
										   [SQLDB],
										   [SegmentCode],
										   [SegmentName],
										   [DimensionTypeID],
										   [Start],
										   [Length]
										   )									
										SELECT TOP 1000
											SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ',
											EntityCode = ''' + @EntityCode + ''',
											[COACode] = '''',
											SegmentNbr = SCS.SegmentID,
											EntityName = ''' + @EntityName + ''',
											SQLDB = ''' + @SQLDB + ''',
											SegmentCode = CASE SCS.SegmentID WHEN 0 THEN ''A'' WHEN 1 THEN ''B'' WHEN 2 THEN ''C'' WHEN 3 THEN ''D'' WHEN 4 THEN ''E'' WHEN 5 THEN ''F'' WHEN 6 THEN ''G'' WHEN 7 THEN ''H'' WHEN 8 THEN ''I'' WHEN 9 THEN ''J'' WHEN 10 THEN ''K'' WHEN 11 THEN ''L'' WHEN 12 THEN ''M'' WHEN 13 THEN ''N'' WHEN 14 THEN ''O'' ELSE ''Warning'' END,
											SegmentName = SCS.Name,
											DimensionTypeID = CASE WHEN SCS.SegmentID = 0 THEN 1 ELSE -1 END,
											Start = 1 + ISNULL((select SUM([Length]) FROM ' + @SQLDB + '.dbo.[ScaCompanySegment] sub WHERE sub.CompanyCode = SCS.CompanyCode AND sub.SegmentID < SCS.SegmentID), 0),
											[Length]
										FROM
											' + @SQLDB + '.dbo.[ScaCompanySegment] SCS 
										WHERE
											SCS.CompanyCode COLLATE DATABASE_DEFAULT = ''' + @EntityCode + ''' COLLATE DATABASE_DEFAULT AND
											NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS WHERE FS.[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ' AND FS.[EntityCode] = ''' + @EntityCode + ''' AND FS.[SegmentNbr] = SCS.SegmentID)'

										IF @Debug <> 0 SELECT @SQLStatement
										EXEC (@SQLStatement)
										SET @Inserted = @Inserted + @@ROWCOUNT

									FETCH NEXT FROM Entity_Cursor INTO @SQLDB, @EntityCode, @EntityName
								  END

							CLOSE Entity_Cursor
							DEALLOCATE Entity_Cursor

						  END

						ELSE IF @SourceType = 'ENT'
						  BEGIN

							SET @SQLStatement = 
							'INSERT INTO #Entity
							 (
							 SQLDB,
							 EntityCode,
							 EntityName
							 )
							SELECT 
							 SQLDB = Par01,
							 EntityCode,
							 EntityName
							FROM
							 ' + @ETLDatabase + '.dbo.Entity
							WHERE
							 SelectYN = 1 AND
							 SourceID = ' + CONVERT(nvarchar, @SourceID) + '
							ORDER BY
							 Par01,
							 EntityCode'
		 
							EXEC(@SQLStatement)
							SET @SQLStatement = NULL

  							  DECLARE Entity_Cursor CURSOR FOR

								SELECT 
								 SQLDB,
								 EntityCode,
								 EntityName
								FROM
								 #Entity

								OPEN Entity_Cursor
								FETCH NEXT FROM Entity_Cursor INTO @SQLDB, @EntityCode, @EntityName

								WHILE @@FETCH_STATUS = 0
								  BEGIN

									SET @SQLStatement = '
										INSERT INTO ' + @ETLDatabase + '.[dbo].[FinancialSegment]
										   (
										   [SourceID],
										   [EntityCode],
										   [COACode],
										   [SegmentNbr],
										   [EntityName],
										   [SQLDB],
										   [SegmentTable],
										   [SegmentCode],
										   [SegmentName],
										   [DimensionTypeID],
										   [Start],
										   [Length]
										   )
										SELECT TOP 1000
											SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ',
											EntityCode = ''' + @EntityCode + ''',
											[COACode] = '''',
											SegmentNbr = gla.acct_level,
											EntityName = ''' + @EntityName + ''',
											SQLDB = ''' + @SQLDB + ''',
											SegmentTable = ''glseg'' + CONVERT(nvarchar, gla.acct_level),
											SegmentCode = ''seg'' + CONVERT(nvarchar, gla.acct_level) + ''_code'',
											SegmentName = gla.[description],
											DimensionTypeID = CASE WHEN gla.[natural_acct_flag] = 1 THEN 1 ELSE -1 END,
											Start = gla.start_col,
											[Length] = gla.length
										FROM
											' + @SQLDB + '.[dbo].[glaccdef] gla
										WHERE
											NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS WHERE FS.[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ' AND FS.[EntityCode] = ''' + @EntityCode + ''' AND FS.[SegmentNbr] = gla.acct_level)'

										IF @Debug <> 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										SET @Inserted = @Inserted + @@ROWCOUNT

									FETCH NEXT FROM Entity_Cursor INTO @SQLDB, @EntityCode, @EntityName
								  END

							CLOSE Entity_Cursor
							DEALLOCATE Entity_Cursor

						  END  --End of ENT

						ELSE IF @SourceType = 'NAV'
						  BEGIN
							IF @Debug > 0 SELECT 'Start of NAV'

							IF OBJECT_ID('tempdb..##wrk_FinancialSegment') IS NULL
							SELECT A = 1 INTO ##wrk_FinancialSegment
							
							IF OBJECT_ID('tempdb..##MappedObjectName') IS NULL
							SELECT A = 1 INTO ##MappedObjectName

							SET @SQLStatement = 
							'INSERT INTO #Entity
							 (
							 SQLDB,
							 EntityCode,
							 EntityName,
							 TablePrefix
							 )
							SELECT 
							 SQLDB = ''' + @SourceDatabase + ''',
							 EntityCode,
							 EntityName,
							 TablePrefix = Par01
							FROM
							 ' + @ETLDatabase + '.dbo.Entity
							WHERE
							 SelectYN = 1 AND
							 SourceID = ' + CONVERT(nvarchar, @SourceID) + '
							ORDER BY
							 Par01,
							 EntityCode'
		 
							IF @Debug <> 0 PRINT @SQLStatement
							EXEC(@SQLStatement)
							SET @SQLStatement = NULL

  							  DECLARE Entity_Cursor CURSOR FOR


								SELECT 
								 SQLDB,
								 EntityCode,
								 EntityName,
								 TablePrefix
								FROM
								 #Entity

								OPEN Entity_Cursor
								FETCH NEXT FROM Entity_Cursor INTO @SQLDB, @EntityCode, @EntityName, @TablePrefix

								WHILE @@FETCH_STATUS = 0
								  BEGIN

									SET @SQLStatement = '
										INSERT INTO ' + @ETLDatabase + '.[dbo].[FinancialSegment]
										   (
										   [SourceID],
										   [EntityCode],
										   [COACode],
										   [SegmentNbr],
										   [EntityName],
										   [SQLDB],
										   [SegmentTable],
										   [SegmentCode],
										   [SegmentName],
										   [DimensionTypeID],
										   [Start],
										   [Length]
										   )
										SELECT TOP 1000
											SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ',
											EntityCode = ''' + @EntityCode + ''',
											[COACode] = D.[Code],
											SegmentNbr = 0,
											EntityName = ''' + @EntityName + ''',
											SQLDB = ''' + @SQLDB + ''',
											SegmentTable = ''[' + @TablePrefix + 'Dimension Value]'',
											SegmentCode = D.[Code],
											SegmentName = D.[Name],
											DimensionTypeID = -1,
											Start = NULL,
											[Length] = NULL
										FROM
											' + @SQLDB + '.[dbo].[' + @TablePrefix + 'Dimension] D
										WHERE
											NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS WHERE FS.[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ' AND FS.[EntityCode] = ''' + @EntityCode + ''' AND FS.[SegmentCode] = D.Code COLLATE DATABASE_DEFAULT)'

										IF @Debug <> 0 SELECT 'FinancialSegment',@SQLStatement
										EXEC (@SQLStatement)
										SET @Inserted = @Inserted + @@ROWCOUNT

									SET @SQLStatement = ''

									SET @SQLStatement = @SQLStatement + '
									IF OBJECT_ID(''tempdb..##DimensionSetHierarchy'') IS NULL
									BEGIN
										CREATE TABLE ##DimensionSetHierarchy(
											[EntityCode] [int] NOT NULL,
											[DimensionSetIDLevel1] [int] NOT NULL,
											[DimensionSetIDLevel2] [int] NULL,
											[DimensionSetIDLevel3] [int] NULL,
											[DimensionSetIDLevel4] [int] NULL,
											[DimensionSetIDLevel5] [int] NULL,
											[DimensionSetIDLevel6] [int] NULL,
											[DimensionSetIDLevel7] [int] NULL,
											[DimensionSetIDLevel8] [int] NULL,
											[SetCount] [int] NULL,
											[DimensionCodeLevel1] [nvarchar](20) NULL,
											[DimensionCodeLevel2] [nvarchar](20) NULL,
											[DimensionCodeLevel3] [nvarchar](20) NULL,
											[DimensionCodeLevel4] [nvarchar](20) NULL,
											[DimensionCodeLevel5] [nvarchar](20) NULL,
											[DimensionCodeLevel6] [nvarchar](20) NULL,
											[DimensionCodeLevel7] [nvarchar](20) NULL,
											[DimensionCodeLevel8] [nvarchar](20) NULL,
											[CodeLevel1] [int] NULL,
											[CodeLevel2] [int] NULL,
											[CodeLevel3] [int] NULL,
											[CodeLevel4] [int] NULL,
											[CodeLevel5] [int] NULL,
											[CodeLevel6] [int] NULL,
											[CodeLevel7] [int] NULL,
											[CodeLevel8] [int] NULL
										) ON [PRIMARY]
									END
									'

									SET @SQLStatement = @SQLStatement + '
									INSERT INTO ##DimensionSetHierarchy 
									(
										EntityCode
										,DimensionSetIDLevel1
										,DimensionSetIDLevel2
										,DimensionSetIDLevel3
										,DimensionSetIDLevel4
										,DimensionSetIDLevel5 
										,DimensionSetIDLevel6 
										,DimensionSetIDLevel7 
										,DimensionSetIDLevel8
										,SetCount
										,DimensionCodeLevel1
										,DimensionCodeLevel2 
										,DimensionCodeLevel3
										,DimensionCodeLevel4 
										,DimensionCodeLevel5
										,DimensionCodeLevel6
										,DimensionCodeLevel7
										,DimensionCodeLevel8
										,CodeLevel1
										,CodeLevel2
										,CodeLevel3
										,CodeLevel4
										,CodeLevel5 
										,CodeLevel6
										,CodeLevel7
										,CodeLevel8
									)
									'
									SET @SQLStatement = @SQLStatement + '
									  SELECT DISTINCT
										EntityCode = ' + @EntityCode + '
										,DimensionSetIDLevel1 = L1.[Dimension Set ID]
										,DimensionSetIDLevel2 = L2.[Dimension Set ID]
										,DimensionSetIDLevel3 = L3.[Dimension Set ID]
										,DimensionSetIDLevel4 = L4.[Dimension Set ID]
										,DimensionSetIDLevel5 = L5.[Dimension Set ID]
										,DimensionSetIDLevel6 = L6.[Dimension Set ID]
										,DimensionSetIDLevel7 = L7.[Dimension Set ID]
										,DimensionSetIDLevel8 = L8.[Dimension Set ID]
										,SetCount = 
											CASE WHEN L1.[Dimension Set ID] IS NULL THEN 0 ELSE 1 END +
											CASE WHEN L2.[Dimension Set ID] IS NULL THEN 0 ELSE 1 END +
											CASE WHEN L3.[Dimension Set ID] IS NULL THEN 0 ELSE 1 END +
											CASE WHEN L4.[Dimension Set ID] IS NULL THEN 0 ELSE 1 END +
											CASE WHEN L5.[Dimension Set ID] IS NULL THEN 0 ELSE 1 END +
											CASE WHEN L6.[Dimension Set ID] IS NULL THEN 0 ELSE 1 END +
											CASE WHEN L7.[Dimension Set ID] IS NULL THEN 0 ELSE 1 END +
											CASE WHEN L8.[Dimension Set ID] IS NULL THEN 0 ELSE 1 END
										,DimensionCodeLevel1 = DV1.[Dimension Code]
										,DimensionCodeLevel2 = DV2.[Dimension Code]
										,DimensionCodeLevel3 = DV3.[Dimension Code]
										,DimensionCodeLevel4 = DV4.[Dimension Code]
										,DimensionCodeLevel5 = DV5.[Dimension Code]
										,DimensionCodeLevel6 = DV6.[Dimension Code]
										,DimensionCodeLevel7 = DV7.[Dimension Code]
										,DimensionCodeLevel8 = DV8.[Dimension Code]
										,CodeLevel1 = DV1.[Dimension Value ID]
										,CodeLevel2 = DV2.[Dimension Value ID]
										,CodeLevel3 = DV3.[Dimension Value ID]
										,CodeLevel4 = DV4.[Dimension Value ID]
										,CodeLevel5 = DV5.[Dimension Value ID]
										,CodeLevel6 = DV6.[Dimension Value ID]
										,CodeLevel7 = DV7.[Dimension Value ID]
										,CodeLevel8 = DV8.[Dimension Value ID]
										
									'
									SET @SQLStatement = @SQLStatement + '
									FROM ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Set Tree Node] L1
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Value] DV1
										ON DV1.[Dimension Value ID] = L1.[Dimension Value ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Set Tree Node] L2
										ON L2.[Parent Dimension Set ID] = L1.[Dimension Set ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Value] DV2
										ON DV2.[Dimension Value ID] = L2.[Dimension Value ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Set Tree Node] L3
										ON L3.[Parent Dimension Set ID] = L2.[Dimension Set ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Value] DV3
										ON DV3.[Dimension Value ID] = L3.[Dimension Value ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Set Tree Node] L4
										ON L4.[Parent Dimension Set ID] = L3.[Dimension Set ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Value] DV4
										ON DV4.[Dimension Value ID] = L4.[Dimension Value ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Set Tree Node] L5
										ON L5.[Parent Dimension Set ID] = L4.[Dimension Set ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Value] DV5
										ON DV5.[Dimension Value ID] = L5.[Dimension Value ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Set Tree Node] L6
										ON L6.[Parent Dimension Set ID] = L5.[Dimension Set ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Value] DV6
										ON DV6.[Dimension Value ID] = L6.[Dimension Value ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Set Tree Node] L7
										ON L7.[Parent Dimension Set ID] = L6.[Dimension Set ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Value] DV7
										ON DV7.[Dimension Value ID] = L7.[Dimension Value ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Set Tree Node] L8
										ON L8.[Parent Dimension Set ID] = L7.[Dimension Set ID]
									LEFT JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Value] DV8
										ON DV8.[Dimension Value ID] = L7.[Dimension Value ID]
									'
										IF @Debug <> 0 SELECT '##DimensionSetHierarchy',@SQLStatement

									IF @Debug <> 0 PRINT @SQLStatement
									IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'INSERT INTO ##DimensionSetHierarchy', [SQLStatement] = @SQLStatement

									EXEC (@SQLStatement)
									SET @Inserted = @Inserted + @@ROWCOUNT

									FETCH NEXT FROM Entity_Cursor INTO @SQLDB, @EntityCode, @EntityName, @TablePrefix
								  END

							CLOSE Entity_Cursor
							DEALLOCATE Entity_Cursor
							
  							DECLARE @wrkFinancialSegment NVARCHAR(MAX)
							SET @wrkFinancialSegment = ''

							SET @wrkFinancialSegment = '
							IF OBJECT_ID(''tempdb..##DimensionSetHierarchyRanked'') IS NOT NULL
							BEGIN
								TRUNCATE TABLE ##DimensionSetHierarchyRanked
								DROP TABLE ##DimensionSetHierarchyRanked
							END

							SELECT
							  RK = ROW_NUMBER() OVER (PARTITION BY DimensioSetID ORDER BY SetCount DESC)
							  ,*
							INTO ##DimensionSetHierarchyRanked
							FROM (
								SELECT DISTINCT
									DimensioSetID = DSH.DimensionSetIDLevel1
									,DSH2.*
								FROM ##DimensionSetHierarchy DSH
								INNER JOIN ##DimensionSetHierarchy DSH2
									ON (
									DSH2.DimensionSetIDLevel1 = DSH.DimensionSetIDLevel1
									OR DSH2.DimensionSetIDLevel2 = DSH.DimensionSetIDLevel1
									OR DSH2.DimensionSetIDLevel3 = DSH.DimensionSetIDLevel1
									OR DSH2.DimensionSetIDLevel4 = DSH.DimensionSetIDLevel1
									OR DSH2.DimensionSetIDLevel5 = DSH.DimensionSetIDLevel1
									OR DSH2.DimensionSetIDLevel6 = DSH.DimensionSetIDLevel1
									OR DSH2.DimensionSetIDLevel7 = DSH.DimensionSetIDLevel1
									OR DSH2.DimensionSetIDLevel8 = DSH.DimensionSetIDLevel1)
							) AS T
							ORDER BY 2
							'
							
							--IF @Debug <> 0 PRINT @wrkFinancialSegment
							IF @Debug <> 0 SELECT '##DimensionSetHierarchyRanked',@SQLStatement
							EXEC (@wrkFinancialSegment)
							SET @Inserted = @Inserted + @@ROWCOUNT

							SET @wrkFinancialSegment = '
							IF OBJECT_ID(''tempdb..##Segments'') IS NOT NULL
							BEGIN
								TRUNCATE TABLE ##Segments
								DROP TABLE ##Segments
							END

							SELECT DISTINCT
								ID = IDENTITY(INT,1,1)
								,[COACode] = REPLACE([SegmentName],'' '','''')
							INTO ##Segments
							FROM ' + @ETLDatabase + '.[dbo].[FinancialSegment]
							ORDER BY 2
							'

							IF @Debug <> 0 SELECT '##Segments',@SQLStatement
							EXEC (@wrkFinancialSegment)
							SET @Inserted = @Inserted + @@ROWCOUNT
							
							SET @wrkFinancialSegment = '
							DECLARE @SQL NVARCHAR(MAX)
							DECLARE @InSQL NVARCHAR(MAX)
							DECLARE @Start INT
							DECLARE @End INT

							SELECT
								@Start = 1
								,@End = MAX(ID)
							FROM ##Segments

							IF OBJECT_ID(''tempdb..##SegmentNames'') IS NOT NULL
							BEGIN
								TRUNCATE TABLE ##SegmentNames
								DROP TABLE ##SegmentNames
							END
							CREATE TABLE ##SegmentNames (
								SegmentName NVARCHAR(MAX)
							)
							
							IF OBJECT_ID(''tempdb..#SQL'') IS NOT NULL
							BEGIN
								TRUNCATE TABLE #SQL
								DROP TABLE #SQL
							END
							CREATE TABLE #SQL (
								SQLQuery NVARCHAR(MAX)
							)

							INSERT INTO #SQL
							(
								SQLQuery
							)
							SELECT
								SQLQuery = ''
								IF OBJECT_ID(''''tempdb..##wrk_FinancialSegment'''') IS NOT NULL
								DROP TABLE ##wrk_FinancialSegment

								SELECT DISTINCT
									EntityCode
									,DimensionSetID = COALESCE(DimensionSetIDLevel8,DimensionSetIDLevel7,DimensionSetIDLevel6,DimensionSetIDLevel5,DimensionSetIDLevel4,DimensionSetIDLevel3,DimensionSetIDLevel2,DimensionSetIDLevel1)
							''
							'

							SET @wrkFinancialSegment = @wrkFinancialSegment + '
							WHILE (@Start < (@End + 1))
							BEGIN

								UPDATE S
								SET SQLQuery = SQLQuery + ''
									,['' + REPLACE([COACode],'' '',''_'') + ''] = 
										CASE
											WHEN DimensionCodeLevel1 = '''''' + [COACode] + '''''' THEN CodeLevel1
											WHEN DimensionCodeLevel2 = '''''' + [COACode] + '''''' THEN CodeLevel2
											WHEN DimensionCodeLevel3 = '''''' + [COACode] + '''''' THEN CodeLevel3
											WHEN DimensionCodeLevel4 = '''''' + [COACode] + '''''' THEN CodeLevel4
											WHEN DimensionCodeLevel5 = '''''' + [COACode] + '''''' THEN CodeLevel5
											WHEN DimensionCodeLevel6 = '''''' + [COACode] + '''''' THEN CodeLevel6
											WHEN DimensionCodeLevel7 = '''''' + [COACode] + '''''' THEN CodeLevel7
											WHEN DimensionCodeLevel8 = '''''' + [COACode] + '''''' THEN CodeLevel8
											ELSE NULL
										END
											''
								FROM #SQL S
								INNER JOIN ##Segments Se
									ON 1 = 1
								WHERE Se.ID = @Start

								INSERT INTO ##SegmentNames
								(
									SegmentName
								)
								SELECT DISTINCT
									[COACode]
								FROM #SQL S
								INNER JOIN ##Segments Se
									ON 1 = 1
								WHERE Se.ID = @Start

								SET @Start = @Start + 1
							END
							'

							SET @wrkFinancialSegment = @wrkFinancialSegment + '
							UPDATE  #SQL
							SET SQLQuery = SQLQuery + ''
								INTO ##wrk_FinancialSegment
								FROM ##DimensionSetHierarchyRanked
								WHERE RK = 1
								ORDER BY 1
							''

							SELECT
								@SQL = SQLQuery
							FROM #SQL

							IF (' + CONVERT(NVARCHAR(10),@Debug) + ' <> 0) SELECT ''@SQL2'',@SQL
							EXEC (@SQL)
							'

							IF @Debug <> 0 SELECT '@wrkFinancialSegment',@wrkFinancialSegment
							IF @Debug <> 0 PRINT @wrkFinancialSegment
							EXEC (@wrkFinancialSegment)
							SET @Inserted = @Inserted + @@ROWCOUNT
							
							IF @Debug <> 0
							SELECT '##wrk_FinancialSegment',* FROM ##wrk_FinancialSegment

							SET @wrkFinancialSegment = '
							IF OBJECT_ID(''tempdb..##MappedObjectName'') IS NOT NULL
							BEGIN
								TRUNCATE TABLE ##MappedObjectName
								DROP TABLE ##MappedObjectName
							END

							SELECT DISTINCT 
								ID = IDENTITY(INT,1,1)
								,[ObjectName] = [SegmentName]
								,[MappedObjectName] = ''GL_'' + [SegmentName]
								,RK = DENSE_RANK() OVER (ORDER BY [SegmentName])
							INTO ##MappedObjectName
							FROM ' + @ETLDatabase + '.[dbo].[FinancialSegment]
							'

							IF @Debug <> 0 SELECT '##MappedObjectName',@wrkFinancialSegment
							EXEC (@wrkFinancialSegment)
							SET @Inserted = @Inserted + @@ROWCOUNT
							
							SET @wrkFinancialSegment = ''
							
							IF OBJECT_ID('tempdb..##MappedObjectNameGroup') IS NOT NULL
							BEGIN
								TRUNCATE TABLE ##MappedObjectNameGroup
								DROP TABLE ##MappedObjectNameGroup
							END
							CREATE TABLE ##MappedObjectNameGroup (
								ID INT IDENTITY(1,1)
								,[ObjectName] NVARCHAR(MAX)
								,[MappedObjectName] NVARCHAR(MAX)
							)

							DECLARE @Start INT
							DECLARE @End INT

							SELECT
								@Start = 1
								,@End = MAX(RK)
							FROM ##MappedObjectName

							WHILE (@Start < (@End + 1))
							BEGIN
								SET @wrkFinancialSegment = ''

								SELECT
									@wrkFinancialSegment = @wrkFinancialSegment + CASE WHEN NULLIF(@wrkFinancialSegment,'') IS NULL THEN '' ELSE ',' END + '[' + REPLACE([ObjectName],' ','') + ']'
								FROM ##MappedObjectName
								WHERE RK = @Start
								AND [ObjectName] <> ''

								INSERT INTO ##MappedObjectNameGroup
								(
									[ObjectName]
									,[MappedObjectName]
								)
								SELECT DISTINCT
									'COALESCE(' + @wrkFinancialSegment + ',NULL)'
									,[MappedObjectName]
								FROM ##MappedObjectName
								WHERE RK = @Start 

								SET @Start = @Start + 1
							END

							SET @wrkFinancialSegment = '
							IF OBJECT_ID(''' + @ETLDatabase + '.[dbo].[wrk_FinancialSegment]'') IS NOT NULL
							BEGIN
								TRUNCATE TABLE ' + @ETLDatabase + '.[dbo].[wrk_FinancialSegment]
								DROP TABLE ' + @ETLDatabase + '.[dbo].[wrk_FinancialSegment]
							END

							SELECT DISTINCT
								FS.*
								,wFS.DimensionSetID'

							SELECT
								@wrkFinancialSegment = @wrkFinancialSegment + '
								,[' + [MappedObjectName] + '] = ' + [ObjectName]
							FROM ##MappedObjectNameGroup MON

							SELECT @wrkFinancialSegment = @wrkFinancialSegment + '
							INTO ' + @ETLDatabase + '.[dbo].[wrk_FinancialSegment]
							FROM ##wrk_FinancialSegment wFS
							INNER JOIN ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS
								ON FS.[EntityCode] = wFS.[EntityCode]
							'

							--SELECT @wrkFinancialSegment
							--SELECT '##SegmentNames',* FROM ##SegmentNames
							--SELECT '##wrk_FinancialSegment',* FROM ##wrk_FinancialSegment
							--SELECT '##MappedObjectNameGroup',* FROM ##MappedObjectNameGroup
							
							IF @Debug <> 0 SELECT 'wrk_FinancialSegment',@wrkFinancialSegment
							EXEC (@wrkFinancialSegment)
							SET @Inserted = @Inserted + @@ROWCOUNT
						  END  --End of NAV
						
						DROP TABLE #Entity

					END  --End of @SourceDBTypeID = 2 Multiple

			FETCH NEXT FROM FinancialSegment_Source_Cursor INTO @SourceID, @SourceDatabase, @SourceTypeID, @SourceType, @SourceDBTypeID, @SourceTypeFamilyID, @Owner, @ETLDatabase, @LanguageCode
			END

		CLOSE FinancialSegment_Source_Cursor
		DEALLOCATE FinancialSegment_Source_Cursor
		
	SET @Step = 'Return wrk_FinancialSegment rows.'
		IF @SourceType = 'NAV'
			BEGIN
				SET @SQLStatement = '
				SELECT * FROM ' + @ETLDatabase + '.[dbo].[wrk_FinancialSegment]'
				EXEC (@SQLStatement)
			END

	SET @Step = 'Return FinancialSegment rows.'
		SET @SQLStatement = '
		SELECT * FROM ' + @ETLDatabase + '.[dbo].[FinancialSegment]'
		EXEC (@SQLStatement)

	SET @Step = 'Drop temp tables'
		DROP TABLE #FinancialSegment_Source_Cursor

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
