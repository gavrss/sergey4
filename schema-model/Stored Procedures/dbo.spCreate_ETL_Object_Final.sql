SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_ETL_Object_Final]

	@JobID int = 0,
	@ApplicationID int = NULL,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug int = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--spCreate_ETL_Object_Final @ApplicationID = 400, @Debug = 1
--spCreate_ETL_Object_Final @ApplicationID = 601, @Debug = 1
--EXEC [spCreate_ETL_Object_Final] @ApplicationID = 1315, @Encryption = 42, @Debug = 1
--EXEC [spCreate_ETL_Object_Final] @ApplicationID = 1345, @Encryption = 42, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@InstanceID int,
	@ETLDatabase nvarchar(50),
	@SourceID int,
	@SourceTypeID int,
	@DimensionID int,
	@ObjectName nvarchar(100),
	@MappedObjectName nvarchar(100),
	@GenericYN bit,
	@OptionalYN bit,
	@ViewName nvarchar(100),
	@ProcedureName nvarchar(100),
	@Action nvarchar(10),
	@DimensionTypeID int,
	@LanguageCode nchar(3),
	@SourceID_varchar nvarchar(50),
	@FinanceAccountYN bit,
	@OptFinanceDimYN bit,
	@SortOrder int,
	@SortOrder1000 int,
	@SortOrder_pcExchange_Dim int,
	@SlaveYN bit,
	@Rows float,
	@Counter float = 0.0,
	@Percent int,
	@PercentString nvarchar(10),
	@SourceDBTypeID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2065' SET @Description = 'Added check on Source.SelectYN <> 0.'
		IF @Version = '1.2.2068' SET @Description = 'spCreate_ETL_MappedObject added.'
		IF @Version = '1.3.2070' SET @Description = 'Handling SourceType pcEXCHANGE.'
		IF @Version = '1.3.2071' SET @Description = 'Removed Dimension.ModelBM. Handle dimensions without any source db, Removed special handling for Number dimensions.'
		IF @Version = '1.3.2073' SET @Description = 'Added ETL_BudgetSelection.'
		IF @Version = '1.3.2075' SET @Description = 'Changed from EntityCode to Entity.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption, added test on SourceTypeBM'
		IF @Version = '1.3.2093' SET @Description = 'CurrentOrderState added'
		IF @Version = '1.3.2095' SET @Description = 'spCreate_ETL_View added'
		IF @Version = '1.3.2096' SET @Description = 'Run spIU_0000_ETL_wrk_SourceTable in the beginning. @Encryption implemented on all sub commands.'
		IF @Version = '1.3.2100' SET @Description = 'Procedure spCreate_Canvas_Export_Financials_AFR renamed to spCreate_Canvas_Export_Financials'
		IF @Version = '1.3.2107' SET @Description = 'Modified handling of pcEXCHANGE'
		IF @Version = '1.3.2110' SET @Description = 'Only create Linked procedures when SourceTypeID <> 6.'
		IF @Version = '1.3.2115' SET @Description = 'Added spFix_ChangedLabel to load table.'
		IF @Version = '1.3.2116' SET @Description = 'Handle unicode in dimension names. Handle MasterDimensionID.'
		IF @Version = '1.3.0.2118' SET @Description = 'Adjust sortorder for slave dimensions.'
		IF @Version = '1.3.1.2120' SET @Description = 'Adjust sortorder for loading pcExchange dimensions.'
		IF @Version = '1.4.0.2131' SET @Description = 'Removed references to properties for financial segments.'
		IF @Version = '1.4.0.2137' SET @Description = 'Removed filter for not creating Dimensions with ID > 1000.'
		IF @Version = '1.4.0.2139' SET @Description = 'Check that pcExchange has correct ApplicationID to be included'
		IF @Version = '2.0.0.2141' SET @Description = 'Load Financials via Journal'
		IF @Version = '2.0.3.2154' SET @Description = 'Remove references of DimensionID column from Property. Replaced with column DimensionID from Dimension_Property table.'

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
		RAISERROR ('10 percent', 0, 10) WITH NOWAIT

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT
			@InstanceID = A.InstanceID,
			@LanguageCode = L.LanguageCode,
			@SortOrder = 10
		FROM
			[Application] A
			INNER JOIN [Language] L ON L.LanguageID = A.LanguageID
		WHERE
			A.ApplicationID = @ApplicationID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		SELECT
			@SourceDBTypeID = MAX(ST.SourceDBTypeID)
		FROM
			[Model] M
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
		WHERE
			M.ApplicationID = @ApplicationID AND
			M.SelectYN <> 0

	SET @Step = 'Create temp table #MappedObject'
		CREATE TABLE #MappedObject
		(
		SourceID int,
		DimensionTypeID int,
		ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
		MappedObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
		ObjectTypeBM int 
		)

	SET @Step = 'Create #Dimension_SortOrder table'
		SELECT
			[DimensionID],
			SortOrder = CASE WHEN P4_PropertyID IS NOT NULL THEN 10 ELSE
						CASE WHEN P3_PropertyID IS NOT NULL THEN 20 ELSE
						CASE WHEN P2_PropertyID IS NOT NULL THEN 30 ELSE
						CASE WHEN P1_PropertyID IS NOT NULL THEN 40 ELSE
						50 END END END END,
			SlaveYN = 0
		INTO #Dimension_SortOrder
		FROM
			(
			--SELECT DISTINCT
			--	D.[DimensionID],
			--	P1_PropertyID = MAX(P1.PropertyID),
			--	P2_PropertyID = MAX(P2.PropertyID),
			--	P3_PropertyID = MAX(P3.PropertyID),
			--	P4_PropertyID = MAX(P4.PropertyID)
			--FROM
			--	[Dimension] D
			--	LEFT JOIN Property P1 ON P1.DependentDimensionID = D.DimensionID AND P1.DependentDimensionID <> P1.DimensionID
			--	LEFT JOIN Property P2 ON P2.DependentDimensionID = P1.DimensionID AND P2.DependentDimensionID <> P2.DimensionID
			--	LEFT JOIN Property P3 ON P3.DependentDimensionID = P2.DimensionID AND P3.DependentDimensionID <> P3.DimensionID
			--	LEFT JOIN Property P4 ON P4.DependentDimensionID = P3.DimensionID AND P4.DependentDimensionID <> P4.DimensionID
			--WHERE
			--	D.DimensionID NOT BETWEEN 1 AND 1000 AND
			--	D.MasterDimensionID IS NULL
			--GROUP BY
			--	D.[DimensionID]
			
			SELECT DISTINCT
				D.[DimensionID],
				P1_PropertyID = MAX(P1.PropertyID),
				P2_PropertyID = MAX(P2.PropertyID),
				P3_PropertyID = MAX(P3.PropertyID),
				P4_PropertyID = MAX(P4.PropertyID)
			FROM
				[Dimension] D
				LEFT JOIN 
					(
					SELECT 
						DP.DimensionID, PP.PropertyID, PP.DependentDimensionID 
					FROM 
						Property PP
						INNER JOIN Dimension_Property DP ON DP.PropertyID = PP.PropertyID 
					) P1 ON P1.DependentDimensionID = D.DimensionID AND P1.DependentDimensionID <> P1.DimensionID
				LEFT JOIN 
					(
					SELECT 
						DP.DimensionID, PP.PropertyID, PP.DependentDimensionID 
					FROM 
						Property PP
						INNER JOIN Dimension_Property DP ON DP.PropertyID = PP.PropertyID 
					) P2 ON P2.DependentDimensionID = P1.DimensionID AND P2.DependentDimensionID <> P2.DimensionID
				LEFT JOIN 
					(
					SELECT 
						DP.DimensionID, PP.PropertyID, PP.DependentDimensionID 
					FROM 
						Property PP
						INNER JOIN Dimension_Property DP ON DP.PropertyID = PP.PropertyID 
					) P3 ON P3.DependentDimensionID = P2.DimensionID AND P3.DependentDimensionID <> P3.DimensionID
				LEFT JOIN 
					(
					SELECT 
						DP.DimensionID, PP.PropertyID, PP.DependentDimensionID 
					FROM 
						Property PP
						INNER JOIN Dimension_Property DP ON DP.PropertyID = PP.PropertyID 
					) P4 ON P4.DependentDimensionID = P3.DimensionID AND P4.DependentDimensionID <> P4.DimensionID
			WHERE
				D.DimensionID NOT BETWEEN 1 AND 1000 AND
				D.MasterDimensionID IS NULL
			GROUP BY
				D.[DimensionID]
			) sub

		INSERT INTO #Dimension_SortOrder
			(
			[DimensionID],
			[SortOrder],
			[SlaveYN]
			)
		SELECT
			[DimensionID] = D.[DimensionID],
			[SortOrder] = 60,
			[SlaveYN] = 1
		FROM
			[Dimension] D
		WHERE
			D.MasterDimensionID IS NOT NULL

		IF @Debug <> 0 SELECT TempTable = '#Dimension_SortOrder', * FROM #Dimension_SortOrder ORDER BY SortOrder

		RAISERROR ('20 percent', 0, 20) WITH NOWAIT

	SET @Step = 'CURSOR LOOP on @SourceID that fills temp table and creates views'

		SELECT
			S.SourceID,
			A.ETLDatabase
		INTO
			#Source_All_Cursor
		FROM
			Source S
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
		WHERE
			S.SourceTypeID <> 6 AND
			S.SelectYN <> 0 
		ORDER BY
			S.SourceID

		IF @Debug <> 0 SELECT TempTable = '#Source_All_Cursor', * FROM #Source_All_Cursor
	
		IF CURSOR_STATUS('global','Source_All_Cursor') >= -1 DEALLOCATE Source_All_Cursor
		DECLARE Source_All_Cursor CURSOR FOR

		SELECT
			SourceID,
			ETLDatabase
		FROM
			#Source_All_Cursor
		ORDER BY
			SourceID
		
		OPEN Source_All_Cursor

		FETCH NEXT FROM Source_All_Cursor INTO @SourceID, @ETLDatabase

		WHILE @@FETCH_STATUS = 0
		  BEGIN

		  IF @Debug <> 0  SELECT SourceID = @SourceID, ETLDatabase = @ETLDatabase

		  SET @SQLStatement = '
			SELECT DISTINCT
				SourceID = ' + CONVERT(nvarchar, @SourceID) + ', 
				DimensionTypeID,
				ObjectName = CASE WHEN DimensionTypeID = -1 THEN MO.MappedObjectName ELSE MO.ObjectName END, 
				MappedObjectName = MO.MappedObjectName,
				MO.ObjectTypeBM
			FROM
				' + @ETLDatabase + '.dbo.MappedObject MO
				INNER JOIN ' + @ETLDatabase + '.dbo.Entity E ON (E.SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND E.Entity = MO.Entity AND E.SelectYN <> 0) OR MO.Entity = ''-1''
				INNER JOIN Source S ON S.SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND S.SelectYN <> 0
				INNER JOIN Model M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & MO.ModelBM > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
			WHERE
				(MO.ObjectTypeBM & 1 > 0 OR MO.ObjectTypeBM & 2 > 0) AND
				DimensionTypeID NOT IN (25) AND
				(MO.DimensionTypeID <> -1 OR BM.OptFinanceDimYN <> 0) AND
				MO.SelectYN <> 0
				
			UNION

			SELECT DISTINCT
				SourceID = ' + CONVERT(nvarchar, @SourceID) + ', 
				MO.DimensionTypeID,
				ObjectName = MO.ObjectName, 
				MappedObjectName = MO.MappedObjectName,
				MO.ObjectTypeBM
			FROM
				' + @ETLDatabase + '.dbo.MappedObject MO
				INNER JOIN ' + @ETLDatabase + '.dbo.Entity E ON (E.SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND E.Entity = MO.Entity AND E.SelectYN <> 0) OR MO.Entity = ''-1''
				INNER JOIN Source S ON S.SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND S.SelectYN <> 0
				INNER JOIN Model M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
				INNER JOIN (
							SELECT DISTINCT
								ModelID = MD.ModelID,
								ObjectName = DD.DimensionName,
								ParentObjectName = D.DimensionName
							FROM
								Property P
								INNER JOIN Dimension_Property DP ON DP.PropertyID = P.PropertyID AND DP.DimensionID <> P.DependentDimensionID 
								INNER JOIN Dimension D ON D.DimensionID = DP.DimensionID AND D.Introduced < ''' + @Version + ''' AND D.SelectYN <> 0
								INNER JOIN Dimension DD ON DD.DimensionID = P.DependentDimensionID AND DD.Introduced < ''' + @Version + ''' AND DD.SelectYN <> 0
								INNER JOIN Model_Dimension MD ON MD.DimensionID = D.DimensionID
							WHERE
								P.DataTypeID = 3 AND
								P.SelectYN <> 0 
								--P.DimensionID <> P.DependentDimensionID
							) P ON P.ModelID = BM.ModelID AND P.ObjectName = MO.ObjectName
				INNER JOIN ' + @ETLDatabase + '.dbo.MappedObject MOP ON MOP.ObjectName = P.ParentObjectName AND MOP.ObjectTypeBM & 2 > 0 AND MOP.ModelBM & BM.ModelBM > 0 AND MOP.DimensionTypeID NOT IN (-1, 25) AND MOP.SelectYN <> 0
			WHERE
				MO.ModelBM & BM.ModelBM = 0 AND
				MO.ObjectTypeBM & 2 > 0 AND
				MO.DimensionTypeID NOT IN (-1, 25) AND
				MO.SelectYN <> 0'	  

			IF @Debug <> 0 PRINT @SQLStatement

			EXEC spCreate_Dimension_View_Segment @SourceID = @SourceID, @Encryption = @Encryption
			INSERT INTO #MappedObject (SourceID, DimensionTypeID, ObjectName, MappedObjectName, ObjectTypeBM) EXEC (@SQLStatement)

			SET @Inserted = @@ROWCOUNT
			IF @Debug <> 0 SELECT SourceID = @SourceID, Inserted = @Inserted
		
			FETCH NEXT FROM Source_All_Cursor INTO @SourceID, @ETLDatabase
		  END

		CLOSE Source_All_Cursor
		DEALLOCATE Source_All_Cursor

IF @Debug <> 0 SELECT Step = 8

		SET @SQLStatement = '
			SELECT DISTINCT
				SourceID = ' + CONVERT(nvarchar, @SourceID) + ', 
				DimensionTypeID,
				ObjectName = MO.ObjectName, 
				MappedObjectName = MO.MappedObjectName,
				MO.ObjectTypeBM
			FROM
				' + @ETLDatabase + '.dbo.MappedObject MO
			WHERE
				MO.ObjectTypeBM & 2 > 0 AND
				DimensionTypeID NOT IN (25) AND
				MO.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM #MappedObject MOT WHERE MOT.MappedObjectName = MO.MappedObjectName)'

		INSERT INTO #MappedObject (SourceID, DimensionTypeID, ObjectName, MappedObjectName, ObjectTypeBM) EXEC (@SQLStatement)

		SET @Inserted = @@ROWCOUNT
		IF @Debug <> 0 SELECT SourceID = 0, Inserted = @Inserted
		IF @Debug <> 0 SELECT TempTable = '#MappedObject', * FROM #MappedObject ORDER BY SourceID, DimensionTypeID

IF @Debug <> 0 SELECT Step = 9

SET @Step = 'Run spIU_0000_ETL_wrk_SourceTable'
	IF @SourceDBTypeID = 2
		BEGIN
			SET @SQLStatement = '
				EXEC ' + @ETLDatabase + '.dbo.spIU_0000_ETL_wrk_SourceTable'
			EXEC (@SQLStatement)
		END

IF @Debug <> 0 SELECT Step = 10

SET @Step = 'Cursor for Creating dimension views and creating dimension load procedures'
	RAISERROR ('30 percent', 0, 30) WITH NOWAIT
	SELECT
		 sub.DimGroup,
		 sub.SourceID,
		 sub.DimensionID,
		 sub.ObjectName,
		 sub.MappedObjectName,
		 sub.GenericYN,
		 sub.OptionalYN,
		 ViewName = '[vw_' + CASE WHEN sub.GenericYN <> 0 THEN '0000' ELSE CASE WHEN sub.SourceID <= 9 THEN '000' ELSE CASE WHEN sub.SourceID <= 99 THEN '00' ELSE CASE WHEN sub.SourceID <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, sub.SourceID) END + '_' + sub.ObjectName + ']',
		 sub.DimensionTypeID,
		 DSO.SortOrder,
		 DSO.SlaveYN
	INTO
		#Dimension_All
	FROM
		(
		--Optional Finance dimensions
		SELECT DISTINCT
		 DimGroup = '1 Optional Finance dimensions',
		 MO.SourceID,
		 DimensionID = 0,
		 MO.ObjectName,
		 MO.MappedObjectName,
		 GenericYN = 0,
		 OptionalYN = 1,
		 MO.DimensionTypeID
		FROM
		 #MappedObject MO
		 INNER JOIN [Source] S ON S.SourceID = MO.SourceID AND S.SourceTypeID <> 6 AND S.SelectYN <> 0
		WHERE
		 MO.DimensionTypeID = -1 AND
		 MO.ObjectTypeBM & 2 > 0

		--Generic dimensions with source
		UNION SELECT 
		 DimGroup = '2 Generic dimensions',
		 SourceID = MIN(S.SourceID),
		 D.DimensionID,
		 ObjectName = MAX(D.DimensionName),
		 MappedObjectName = MAX(MO.MappedObjectName),
 		 GenericYN = 1,
		 OptionalYN = 0,
 		 DimensionTypeID = MAX(D.DimensionTypeID)
		FROM 
		 Source S
		 INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
		 INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
		 INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.Introduced < @Version AND MD.SelectYN <> 0
		 INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.GenericYN <> 0 AND D.Introduced < @Version AND D.SelectYN <> 0
		 INNER JOIN #MappedObject MO ON MO.ObjectName = D.DimensionName AND MO.DimensionTypeID <> -1 AND MO.ObjectTypeBM & 2 > 0
		WHERE
		 S.SourceTypeID <> 6 AND
		 S.SelectYN <> 0 AND
		 M.SelectYN <> 0
		GROUP BY
		 D.DimensionID	

		--Generic dimensions without source
		UNION SELECT 
			DimGroup = '2 Generic dimensions, no source',
			SourceID = @SourceID,
			D.DimensionID,
			ObjectName = MAX(D.DimensionName),
			MappedObjectName = MAX(MO.MappedObjectName),
 			GenericYN = 1,
			OptionalYN = 0,
 			DimensionTypeID = MAX(D.DimensionTypeID)
		FROM 
			Model M
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.Introduced < @Version AND MD.SelectYN <> 0
			INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.GenericYN <> 0 AND D.Introduced < @Version AND D.SelectYN <> 0
			INNER JOIN #MappedObject MO ON MO.ObjectName = D.DimensionName AND MO.DimensionTypeID <> -1 AND MO.ObjectTypeBM & 2 > 0
		WHERE
			M.ApplicationID = @ApplicationID AND
			M.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM (	SELECT DISTINCT
											MO.DimensionTypeID,
											MO.MappedObjectName
										FROM 
											#MappedObject MO
											INNER JOIN Dimension D ON D.DimensionTypeID = MO.DimensionTypeID AND D.DimensionName = MO.ObjectName AND D.Introduced < @Version AND D.SelectYN <> 0
											INNER JOIN Model_Dimension MD ON MD.DimensionID = D.DimensionID AND MD.Introduced < @Version AND MD.SelectYN <> 0
											INNER JOIN Model BM ON BM.ModelID = MD.ModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
											INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0 
											INNER JOIN Source S ON S.SourceID = MO.SourceID AND S.ModelID = M.ModelID AND S.SourceTypeID <> 6 AND S.SelectYN <> 0
										WHERE
											MO.DimensionTypeID <> -1 AND
											MO.ObjectTypeBM & 2 > 0
									 ) S WHERE S.DimensionTypeID = MO.DimensionTypeID AND S.MappedObjectName = MO.MappedObjectName)
		GROUP BY
			D.DimensionID	

		--Specific dimensions
		UNION SELECT DISTINCT
			DimGroup = '3 Specific dimensions',
			S.SourceID,
			D.DimensionID,
			MO.ObjectName,
			MO.MappedObjectName,
			D.GenericYN,
			OptionalYN = 0,
			D.DimensionTypeID
		FROM 
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.Introduced < @Version AND MD.SelectYN <> 0
			INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.GenericYN = 0 AND D.SourceTypeBM & ST.SourceTypeBM > 0 AND D.Introduced < @Version AND D.SelectYN <> 0
			INNER JOIN #MappedObject MO ON MO.ObjectName = D.DimensionName AND MO.DimensionTypeID <> -1 AND MO.ObjectTypeBM & 2 > 0
		WHERE
			S.SourceTypeID <> 6 AND
			S.SelectYN <> 0

		--Property member dimensions
		UNION SELECT DISTINCT
			DimGroup = '4 Property member dimensions',
			SourceID = CASE WHEN PD.GenericYN <> 0 THEN Min_Source.MIN_SourceID ELSE S.SourceID END,
			PD.DimensionID,
			MO.ObjectName,
 			MO.MappedObjectName,
			PD.GenericYN,
			OptionalYN = 0,
 			PD.DimensionTypeID
		FROM 
			Source S
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.Introduced < @Version AND MD.SelectYN <> 0
			INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.Introduced < @Version AND D.SelectYN <> 0
			INNER JOIN Dimension_Property DP ON DP.DimensionID = D.DimensionID
			INNER JOIN Property P ON P.PropertyID = DP.PropertyID AND P.DataTypeID = 3 AND P.Introduced < @Version AND P.SelectYN <> 0
			--INNER JOIN Property P ON P.DimensionID = D.DimensionID AND P.DataTypeID = 3 AND P.Introduced < @Version AND P.SelectYN <> 0
			INNER JOIN Dimension PD ON PD.DimensionID = P.DependentDimensionID AND PD.Introduced < @Version AND PD.SelectYN <> 0
 			INNER JOIN #MappedObject MO ON MO.ObjectName = PD.DimensionName AND MO.DimensionTypeID <> -1 AND MO.ObjectTypeBM & 2 > 0
			INNER JOIN (
						SELECT
							PD.DimensionID,
							MIN_SourceID = MIN(S.SourceID)
						FROM 
							Source S
							INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
							INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
							INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.Introduced < @Version AND MD.SelectYN <> 0
							INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.Introduced < @Version AND D.SelectYN <> 0
							INNER JOIN Dimension_Property DP ON DP.DimensionID = D.DimensionID
							INNER JOIN Property P ON P.PropertyID = DP.PropertyID AND P.DataTypeID = 3 AND P.Introduced < @Version AND P.SelectYN <> 0
							INNER JOIN Dimension PD ON PD.DimensionID = P.DependentDimensionID AND PD.Introduced < @Version AND PD.SelectYN <> 0
 							INNER JOIN #MappedObject MO ON MO.ObjectName = PD.DimensionName AND MO.DimensionTypeID <> -1 AND MO.ObjectTypeBM & 2 > 0
						WHERE
							S.SourceTypeID <> 6 AND
							S.SelectYN <> 0
						GROUP BY
							PD.DimensionID
						) Min_Source ON Min_Source.DimensionID = PD.DimensionID
			WHERE
				S.SourceTypeID <> 6 AND
				S.SelectYN <> 0
		 ) sub
		INNER JOIN #Dimension_SortOrder DSO ON DSO.DimensionID = sub.DimensionID
--		INNER JOIN [Source] S ON S.SourceID = sub.SourceID AND S.SourceTypeID <> 6
	ORDER BY
	 DSO.SortOrder,
	 GenericYN DESC,
	 SourceID,
	 OptionalYN,
	 sub.DimensionID DESC

	IF @Debug <> 0 SELECT TempTable = '#Dimension_All', * FROM #Dimension_All ORDER BY DimGroup, GenericYN DESC, SourceID, OptionalYN, DimensionID DESC

--	RAISERROR ('60 percent', 0, 60) WITH NOWAIT

	SELECT @Rows = COUNT(1) FROM (SELECT DISTINCT
						SourceID,
						DimensionID,
						ObjectName,
						MappedObjectName,
						GenericYN,
						OptionalYN,
						ViewName,
						DimensionTypeID,
						SortOrder
					FROM
						#Dimension_All) sub

	DECLARE Dimension_All_Cursor CURSOR FOR

	SELECT 
		SourceID,
		DimensionID,
		ObjectName,
		MappedObjectName,
		GenericYN,
		OptionalYN,
		ViewName,
		DimensionTypeID,
		SlaveYN
	FROM
		(
		SELECT DISTINCT
			SourceID,
			DimensionID,
			ObjectName,
			MappedObjectName,
			GenericYN,
			OptionalYN,
			ViewName,
			DimensionTypeID,
			SortOrder,
			SlaveYN
		FROM
			#Dimension_All
		) sub
	ORDER BY
		SortOrder,
		GenericYN DESC,
		SourceID,
		OptionalYN,
		DimensionID DESC
		
	OPEN Dimension_All_Cursor

	FETCH NEXT FROM Dimension_All_Cursor INTO @SourceID, @DimensionID, @ObjectName, @MappedObjectName, @GenericYN, @OptionalYN, @ViewName, @DimensionTypeID, @SlaveYN

	WHILE @@FETCH_STATUS = 0
	  BEGIN
		SET @Counter = @Counter + 1.0
		SET @Percent = CONVERT(int, @Counter / @Rows * 58) + 30
		SET @PercentString = CONVERT(nvarchar(10), @Percent) + ' percent'
		RAISERROR (@PercentString, 0, @Percent) WITH NOWAIT

		IF @Debug <> 0 SELECT SourceID = @SourceID, DimensionID = @DimensionID
	  
SET @Step = 'CREATE Generic Dimension View'
		IF @OptionalYN = 0 AND @DimensionTypeID NOT IN (7, 25)
			EXEC spCreate_Dimension_View_Generic @SourceID = @SourceID, @DimensionID = @DimensionID, @Encryption = @Encryption
									
SET @Step = 'CREATE Dimension Procedure'
		IF @DimensionTypeID = 7  --Time dimension (including Time Properties)
			EXEC [spCreate_Dimension_Procedure_Time] @ApplicationID = @ApplicationID, @Encryption = @Encryption, @SortOrder = @SortOrder OUT
		ELSE
			BEGIN
				EXEC spCreate_Dimension_Procedure_Generic @SourceID = @SourceID, @DimensionID = @DimensionID, @DimensionName = @MappedObjectName, @DimensionTypeID = @DimensionTypeID, @GenericYN = @GenericYN, @Encryption = @Encryption, @ProcedureName = @ProcedureName OUT
			END

		IF @Debug <> 0
			BEGIN
			  PRINT 'SourceID = ' + CONVERT(nvarchar, @SourceID) + ', DimensionID = ' + CONVERT(nvarchar, @DimensionID) + ', ObjectName = ' + @ObjectName + ', GenericYN = ' + CONVERT(nvarchar, @GenericYN) + ', OptionalYN = ' + CONVERT(nvarchar, @OptionalYN) + ', ViewName = ' + @ViewName + ', ProcedureName = ' + @ProcedureName
			  SELECT SourceID = @SourceID, DimensionID = @DimensionID, ObjectName = @ObjectName, GenericYN = @GenericYN, OptionalYN = @OptionalYN, ViewName = @ViewName, ProcedureName = @ProcedureName
			END

		SET @SortOrder = @SortOrder + 10
		IF @SlaveYN <> 0 SET @SortOrder1000 = @SortOrder + 1000
		SET @ProcedureName = REPLACE(REPLACE(@ProcedureName, '[', ''), ']', '')
		SET @SQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 2, Command = N''' + @ProcedureName + ''', SortOrder = ' + CONVERT(nvarchar(10), CASE WHEN @SlaveYN = 0 THEN @SortOrder ELSE @SortOrder1000 END) + ', SelectYN = 1
		WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = N''' + @ProcedureName + ''')'
		EXEC (@SQLStatement)

		FETCH NEXT FROM Dimension_All_Cursor INTO @SourceID, @DimensionID, @ObjectName, @MappedObjectName, @GenericYN, @OptionalYN, @ViewName, @DimensionTypeID, @SlaveYN
	  END

	CLOSE Dimension_All_Cursor
	DEALLOCATE Dimension_All_Cursor

SET @Step = 'Add generic ETL rows to Load'
	IF @SourceDBTypeID = 2
		BEGIN
			SET @SortOrder = @SortOrder + 10
			SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 1, Command = ''spIU_0000_ETL_wrk_SourceTable'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
			WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_0000_ETL_wrk_SourceTable'')'
			EXEC (@SQLStatement)
		END

SET @Step = 'Insert Procedures for updating Linked ETL databases'
	IF (
		SELECT COUNT(DISTINCT 1)
		FROM
			[Source] S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0 
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0 
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.SelectYN <> 0 
		WHERE
			S.SourceTypeID <> 6 AND
			S.SourceDatabase LIKE '%.%' AND
			S.SelectYN <> 0 
		) > 0
		BEGIN
			EXEC [spCreate_Linked_ETL_Procedure] @ApplicationID = @ApplicationID, @Encryption = @Encryption
			SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 1, Command = ''spIU_0000_ETL_Linked'', SortOrder = 9999, SelectYN = 1 
			WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_0000_ETL_Linked'')
			INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 2, Command = ''spIU_0000_Dimension_Linked'', SortOrder = 9999, SelectYN = 1 
			WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_0000_Dimension_Linked'')'
			EXEC (@SQLStatement)
		END

	IF (
		SELECT COUNT(DISTINCT 1)
		FROM
			[Source] S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0 
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0 
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.SelectYN <> 0 
		WHERE
			S.SourceDatabase NOT LIKE '%.%' AND
			S.SelectYN <> 0 
		) > 0	
		BEGIN
			EXEC [spCreate_ETL_View] @ApplicationID = @ApplicationID, @Encryption = @Encryption
		END

SET @Step = 'CursorLoop on Model that creates views and procedures for fact tables'
	SELECT 
		ObjectName,
		MappedObjectName,
		SourceID,
		SourceID_varchar,
		FinanceAccountYN,
		OptFinanceDimYN,
		SourceTypeID,
		SortOrder
	INTO
		#Model_Cursor_Table
	FROM
		(
		SELECT DISTINCT
			MO.ObjectName,
			MO.MappedObjectName,
			S.SourceID,
			SourceID_varchar = CASE WHEN ABS(S.SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(S.SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(S.SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(S.SourceID)),
			BM.FinanceAccountYN,
			BM.OptFinanceDimYN,
			S.SourceTypeID,
			SortOrder = CASE WHEN BM.ModelID = -3 THEN 20 ELSE 30 END
		FROM
			#MappedObject MO
			INNER JOIN Model M ON M.ModelName = MO.ObjectName AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN Source S ON S.ModelID = M.ModelID AND S.SelectYN <> 0 AND S.SourceTypeID <> 6
		WHERE
			MO.ObjectTypeBM & 1 > 0

		UNION
		SELECT DISTINCT
			ObjectName = 'pcEXCHANGE',
			MappedObjectName = 'pcEXCHANGE',
			SourceID = MAX(S.SourceID),
			SourceID_varchar = '6000',
			FinanceAccountYN = 0,
			OptFinanceDimYN = 0,
			SourceTypeID = S.SourceTypeID,
			SortOrder = 10
		FROM
			Source S
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID
		WHERE
			S.SourceTypeID = 6 AND
			S.SelectYN <> 0 
		GROUP BY
			S.SourceTypeID
		) sub

	IF @Debug <> 0 
		BEGIN
			SELECT ApplicationID = @ApplicationID, [Version] = @Version
			SELECT TempTable = '#Model_Cursor_Table', * FROM #Model_Cursor_Table
		END

	RAISERROR ('90 percent', 0, 90) WITH NOWAIT
	DECLARE Model_Cursor CURSOR FOR

	SELECT 
		ObjectName,
		MappedObjectName,
		SourceID,
		SourceID_varchar,
		FinanceAccountYN,
		OptFinanceDimYN,
		SourceTypeID
	FROM
		#Model_Cursor_Table
	ORDER BY
		SortOrder,
		SourceID

	OPEN Model_Cursor

	FETCH NEXT FROM Model_Cursor INTO @ObjectName, @MappedObjectName, @SourceID, @SourceID_varchar, @FinanceAccountYN, @OptFinanceDimYN, @SourceTypeID

	WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @SourceTypeID <> 6
				BEGIN
					EXEC spCreate_ETL_ClosedPeriod @SourceID = @SourceID, @Encryption = @Encryption
					SET @SortOrder = @SortOrder + 10
					SET @SQLStatement = '
					INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 1, Command = ''spIU_' + @SourceID_varchar + '_ETL_ClosedPeriod'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
					WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_' + @SourceID_varchar + '_ETL_ClosedPeriod'')'
					EXEC (@SQLStatement)
				END

			EXEC spCreate_ETL_Entity @ApplicationID = @ApplicationID, @Encryption = @Encryption, @SortOrder = @SortOrder OUT

			IF @FinanceAccountYN <> 0 AND @SourceTypeID <> 6
				BEGIN
					EXEC spCreate_ETL_AccountType_Translate @SourceID = @SourceID, @Encryption = @Encryption
					SET @SortOrder = @SortOrder + 10
					SET @SQLStatement = '
					INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 1, Command = ''spIU_' + @SourceID_varchar + '_ETL_AccountType_Translate'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
					WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_' + @SourceID_varchar + '_ETL_AccountType_Translate'')'
					EXEC (@SQLStatement)

					SET @ProcedureName = NULL
					EXEC spCreate_ETL_BudgetSelection @SourceID = @SourceID, @Encryption = @Encryption, @ProcedureName = @ProcedureName OUT
					IF @ProcedureName IS NOT NULL
						BEGIN
							SET @ProcedureName = REPLACE(REPLACE(@ProcedureName, '[', ''), ']', '')
							SET @SortOrder = @SortOrder + 10
							SET @SQLStatement = '
							INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 1, Command = ''' + @ProcedureName + ''', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
							WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''' + @ProcedureName + ''')'
							EXEC (@SQLStatement)
						END
				END

			IF @OptFinanceDimYN <> 0 AND @SourceTypeID <> 6
				BEGIN
					EXEC spCreate_ETL_MappedObject @ApplicationID = @ApplicationID, @Encryption = @Encryption
					SET @SortOrder = @SortOrder + 10
					SET @SQLStatement = '
					INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 1, Command = ''spIU_' + @SourceID_varchar + '_ETL_MappedObject'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
					WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_' + @SourceID_varchar + '_ETL_MappedObject'')'
					EXEC (@SQLStatement)
				END

			--Changed by Jawo 20181018 to avoid creation of old Financials load
			IF @SourceTypeID <> 6 AND @ObjectName <> 'Financials'
				BEGIN
					EXEC spCreate_Fact_Generic @SourceID = @SourceID, @Encryption = @Encryption, @ProcedureName = @ProcedureName OUT
					IF @Debug <> 0 SELECT SourceID = @SourceID, ProcedureName = @ProcedureName

					SET @SortOrder = @SortOrder + 10
					SET @SQLStatement = '
					INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 4, Command = ''' + @ProcedureName + ''', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
					WHERE ''' + @ProcedureName + ''' NOT LIKE ''%_Raw'' AND NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''' + @ProcedureName + ''')'
					EXEC (@SQLStatement)
				END

			IF @ObjectName = 'pcEXCHANGE' AND @SourceID_varchar = '6000'
				BEGIN
					CREATE TABLE #SortOrder_pcExchange_Dim (SortOrder_pcExchange_Dim int)
					SET @SQLStatement = 'INSERT INTO #SortOrder_pcExchange_Dim (SortOrder_pcExchange_Dim) SELECT SortOrder_pcExchange_Dim = MIN(SortOrder) - 5 FROM ' + @ETLDatabase + '.dbo.[Load] WHERE LoadTypeBM & 2 > 0 AND SelectYN <> 0'
					EXEC (@SQLStatement)
					SELECT @SortOrder_pcExchange_Dim = SortOrder_pcExchange_Dim FROM #SortOrder_pcExchange_Dim
					DROP TABLE #SortOrder_pcExchange_Dim

					EXEC spCreate_Dimension_Procedure_pcEXCHANGE @SourceID = @SourceID, @Encryption = @Encryption
					SET @SortOrder = @SortOrder + 10
					SET @SQLStatement = '
					INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, FrequencyBM, SelectYN) SELECT LoadTypeBM = 2, Command = ''spIU_6000_Dimension'', SortOrder = ' + CONVERT(nvarchar, ISNULL(@SortOrder_pcExchange_Dim, @SortOrder)) + ', FrequencyBM = 1, SelectYN = 1
					WHERE ''' + @ProcedureName + ''' NOT LIKE ''%_Raw'' AND NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_6000_Dimension'')'
					EXEC (@SQLStatement)

					EXEC spCreate_Fact_pcEXCHANGE @SourceID = @SourceID, @Encryption = @Encryption
					SET @SortOrder = @SortOrder + 10
					SET @SQLStatement = '
					INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, FrequencyBM, SelectYN) SELECT LoadTypeBM = 4, Command = ''spIU_6000_FACT'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', FrequencyBM = 1, SelectYN = 1
					WHERE ''' + @ProcedureName + ''' NOT LIKE ''%_Raw'' AND NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_6000_FACT'')'
					EXEC (@SQLStatement)
				END

			IF @ObjectName = 'Sales'
				BEGIN
					EXEC spCreate_Fact_Sales_CurrentOrderState @SourceID = @SourceID, @Encryption = @Encryption, @ProcedureName = @ProcedureName OUT

					IF @Debug <> 0 SELECT SourceID = @SourceID, ProcedureName = @ProcedureName

					SET @SortOrder = @SortOrder + 10
					SET @SQLStatement = '
					INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 4, Command = ''' + @ProcedureName + ''', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
					WHERE ''' + @ProcedureName + ''' NOT LIKE ''%_Raw'' AND NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''' + @ProcedureName + ''')'
					EXEC (@SQLStatement)
				END

			FETCH NEXT FROM Model_Cursor INTO @ObjectName, @MappedObjectName, @SourceID, @SourceID_varchar, @FinanceAccountYN, @OptFinanceDimYN, @SourceTypeID
		END

	CLOSE Model_Cursor
	DEALLOCATE Model_Cursor

	SET @Step = 'Insert spCreate_Fact_View procedure to the Load table'
		SET @SortOrder = @SortOrder + 10
		SET @SQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 8, Command = ''spCreate_Fact_View'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
		WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spCreate_Fact_View'')'
		EXEC (@SQLStatement)

/* Temporarly removed 20180721 until the SP get fixed
	SET @Step = 'Insert spCreate_Canvas_Export_Financials procedure to the Load table'
		CREATE TABLE #CountObject (CountObject int)
		SET  @SQLStatement = 'INSERT INTO #CountObject (CountObject) SELECT CountObject = COUNT(1) FROM ' + @ETLDatabase + '.sys.procedures WHERE name = ''spCreate_Canvas_Export_Financials'''
		EXEC (@SQLStatement)
		IF (SELECT CountObject FROM #CountObject) > 0
			BEGIN
				SET @SortOrder = @SortOrder + 10
				SET @SQLStatement = '
				INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 8, Command = ''spCreate_Canvas_Export_Financials'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
				WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spCreate_Canvas_Export_Financials'')'
				EXEC (@SQLStatement)
			END
*/

	--Added by Jawo 20181018 to load Financials via Journal
	SET @Step = 'Insert spIU_0000_FACT_Financials procedure to the Load table'
		SET @SQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 4, Command = ''spIU_0000_FACT_Financials'', SortOrder = 100, SelectYN = 0
		WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_0000_FACT_Financials'')'
		EXEC (@SQLStatement)

	SET @Step = 'Insert spFix procedure to the Load table'
		SET @SortOrder = @SortOrder + 10
		SET @SQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 1, Command = ''spFix_ChangedLabel'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1
		WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spFix_ChangedLabel'')'
		EXEC (@SQLStatement)

	SET @Step = 'Insert spIU_CheckSum procedure to the Load table'
		SET @SortOrder = @SortOrder + 10
		SET @SQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 16, Command = ''spCheck_SBZ'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1 
		WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spCheck_SBZ'')'
		EXEC (@SQLStatement)

		SET @SortOrder = @SortOrder + 10
		SET @SQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 16, Command = ''spCheck_CheckSum'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1 
		WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spCheck_CheckSum'')'
		EXEC (@SQLStatement)

	SET @Step = 'Drop temp tables'
		DROP TABLE #MappedObject
		DROP TABLE #Dimension_All
		DROP TABLE #Dimension_SortOrder
--		DROP TABLE #CountObject  --Temporarly removed 20180721 until the SP spCreate_Canvas_Export_Financials get fixed
		DROP TABLE #Model_Cursor_Table

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		RAISERROR ('100 percent', 0, 100) WITH NOWAIT
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
