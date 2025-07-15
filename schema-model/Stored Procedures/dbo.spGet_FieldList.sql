SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_FieldList]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SourceID int = NULL,
	@DimensionID int = NULL,
	@SortOrder int = NULL,
	@SQLStatement_CreateTable nvarchar(max) = '' OUT,
	@SQLStatement_InsertInto nvarchar(4000) = '' OUT,
	@DimensionName nvarchar(100) = '' OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000071,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*

EXEC [spGet_FieldList] @SourceID = -1579, @DimensionID = -5, @Debug = true  --Rate

DECLARE
@SQLStatement_CreateTable nvarchar(4000),
@SQLStatement_InsertInto nvarchar(4000),
@DimensionName nvarchar(100)
EXEC spGet_FieldList @SourceID = 107, @DimensionID = 0, @Debug = 1, @SQLStatement_CreateTable = @SQLStatement_CreateTable OUT, @SQLStatement_InsertInto = @SQLStatement_InsertInto OUT, @DimensionName = @DimensionName OUT

DECLARE
@SQLStatement_CreateTable nvarchar(4000),
@SQLStatement_InsertInto nvarchar(4000),
@DimensionName nvarchar(100)
EXEC spGet_FieldList @SourceID = 107, @DimensionID = -2, @Debug = 1, @SQLStatement_CreateTable = @SQLStatement_CreateTable OUT, @SQLStatement_InsertInto = @SQLStatement_InsertInto OUT, @DimensionName = @DimensionName OUT

EXEC spGet_FieldList @SourceID = 1107, @DimensionID = -53, @Debug = 1 --FullAccount
EXEC spGet_FieldList @SourceID = 1107, @DimensionID = -53, @SortOrder = 32, @Debug = 1 --FullAccount
EXEC spGet_FieldList @SourceID = 110, @DimensionID = -9, @Debug = 1 --Customer
EXEC spGet_FieldList @SourceID = 0, @DimensionID = -26, @Debug = 1 --Version
EXEC spGet_FieldList @SourceID = 0, @DimensionID = -27, @Debug = 1 --LineItem
EXEC spGet_FieldList @SourceID = 907, @DimensionID = -53, @SortOrder = 32
EXEC spGet_FieldList @SourceID = 1227, @DimensionID = -53, @SortOrder = 32
EXEC spGet_FieldList @SourceID = 111, @DimensionID = -27, @Debug = 1

EXEC [spGet_FieldList] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ETLDatabase nvarchar(100),
	@BaseModelID int,
	@ModelBM int,
	@SQLStatement nvarchar(max),
	@SQLStatement_FieldList nvarchar(max),
	@SourceID_varchar nvarchar(10),
	@SourceDatabase nvarchar(100),
	@SourceDatabase_ERP nvarchar(100),
	@Owner nvarchar(10),
	@Owner_ERP nvarchar(10),
	@GenericYN bit,
	@ApplicationID int,
	@SourceTypeBM_All int,
	@StorageTypeBM int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get full field list for specified dimension',
			@MandatoryParameter = 'SourceID|DimensionID' --Without @, separated by |

		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.3.2070' SET @Description = 'Changed joins from ModelID = @BaseModelID to ModelBM & @ModelBM > 0.'
		IF @Version = '1.3.2071' SET @Description = 'Handle SegmentProperty. Handle @SourceID = 0'
		IF @Version = '1.3.2095' SET @Description = 'Replace MandatoryYN and VisibleYN with VisibilityLevelBM. Added RNodeType.'
		IF @Version = '1.3.2096' SET @Description = 'Handle Dynamic segments for EpicorERP/FullAccount. Added parameter @SortOrder'
		IF @Version = '1.3.2098' SET @Description = 'Replaced vw_XXXX_Dimension_Finance_Metadata with FinancialSegment.'
		IF @Version = '1.3.2107' SET @Description = 'SourceID = 0 is not allowed. Instead test on GenericYN.'
		IF @Version = '1.3.2116' SET @Description = 'Handle HelpText.'
		IF @Version = '1.3.1.2120' SET @Description = 'Test on @SourceTypeBM'
		IF @Version = '1.4.0.2133' SET @Description = 'Test on DynamicYN in ETL table FinancialSegment.'
		IF @Version = '1.4.0.2135' SET @Description = 'Test on Introduced for properties in Financial Segments.'
		IF @Version = '1.4.0.2139' SET @Description = 'Exclude NodeTypeBM.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'OBSOLETE?, Removed Property.DimensionID.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@UserID = ISNULL(@UserID, -10),
			@InstanceID = ISNULL(@InstanceID, A.InstanceID),
			@VersionID = ISNULL(@VersionID, A.VersionID)
		FROM
			[Application] A
			INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SourceID = @SourceID AND S.SelectYN <> 0
		WHERE
			 A.SelectYN <> 0

		SELECT
			@StorageTypeBM = StorageTypeBM
		FROM
			Dimension_StorageType
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		SET @StorageTypeBM = ISNULL(@StorageTypeBM, 4)

		SELECT 
			@GenericYN = GenericYN
		FROM
			Dimension
		WHERE
			DimensionID = @DimensionID

		SELECT DISTINCT
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ApplicationID = A.ApplicationID
		FROM
			[Application] A
			INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SourceID = @SourceID

		IF @GenericYN <> 0
			SELECT DISTINCT
				@BaseModelID = M.BaseModelID,
				@ModelBM = BM.ModelBM,
				@SourceDatabase = '',
				@Owner = 'dbo'
			FROM
				Model_Dimension MD 
				INNER JOIN Model BM ON BM.ModelID = MD.ModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
				INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.SelectYN <> 0
				INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
			WHERE
				MD.DimensionID = @DimensionID AND
				MD.Introduced < @Version AND
				MD.SelectYN <> 0
		ELSE
			SELECT
				@BaseModelID = M.BaseModelID,
				@ModelBM = BM.ModelBM,
				@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
				@Owner = ST.[Owner]
			FROM
				Model M
				INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
				INNER JOIN Source S ON S.SourceID = @SourceID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
				INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			WHERE
				M.SelectYN <> 0

		SELECT
			@SourceTypeBM_All = SUM(sub.SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				ST.SourceTypeBM
			FROM
				SourceType ST
				INNER JOIN [Source] S ON S.SourceTypeID = ST.SourceTypeID AND S.SelectYN <> 0
				INNER JOIN Model M ON M.ModelID = S.ModelID AND M.Introduced < @Version AND M.SelectYN <> 0 AND M.ApplicationID = @ApplicationID
			WHERE
				ST.SelectYN <> 0 AND
				ST.Introduced < @Version
			) sub

	SET @Step = 'Create #ModelDimension temp table'
		CREATE TABLE #ModelDimension
			(
				ModelID int,
				DimensionID int,
				ModelBM int,
				VisibilityLevelBM int,
				MappingEnabledYN bit
			)

		IF @GenericYN <> 0
			INSERT INTO #ModelDimension
				(
				ModelID,
				DimensionID,
				ModelBM,
				VisibilityLevelBM,
				MappingEnabledYN
				)
			SELECT DISTINCT
				BM.ModelID,
				D.DimensionID,
				BM.ModelBM,
				MD.VisibilityLevelBM,
				MD.MappingEnabledYN
			FROM
				Dimension D
				INNER JOIN Model_Dimension MD ON MD.DimensionID = D.DimensionID AND MD.Introduced < @Version AND MD.SelectYN <> 0
				INNER JOIN Model BM ON  BM.ModelID = MD.ModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
				INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.SelectYN <> 0
			WHERE
				D.DimensionID = @DimensionID AND
				D.Introduced < @Version AND
				D.SelectYN <> 0
		ELSE
			INSERT INTO #ModelDimension
				(
				ModelID,
				DimensionID,
				ModelBM,
				VisibilityLevelBM,
				MappingEnabledYN
				)
			SELECT DISTINCT
				BM.ModelID,
				D.DimensionID,
				BM.ModelBM,
				MD.VisibilityLevelBM,
				MD.MappingEnabledYN
			FROM
				Dimension D
				INNER JOIN Model_Dimension MD ON MD.DimensionID = D.DimensionID AND MD.Introduced < @Version AND MD.SelectYN <> 0
				INNER JOIN Model BM ON  BM.ModelID = MD.ModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
				INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.SelectYN <> 0
				INNER JOIN [Source] S ON S.SourceID = @SourceID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
			WHERE
				D.DimensionID = @DimensionID AND
				D.Introduced < @Version AND
				D.SelectYN <> 0

		IF @Debug <> 0 SELECT TempTable = '#ModelDimension', * FROM #ModelDimension

	SET @Step = 'Set dimension properties in temp table (#FieldList)'
		CREATE TABLE #FieldList
			(
			DimensionID int,
			DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT,
			PropertyID int,
			PropertyName nvarchar(100) COLLATE DATABASE_DEFAULT,
			ShortPropertyName nvarchar(100) COLLATE DATABASE_DEFAULT,
			DataTypeID int,
			DataTypeCode nvarchar(100) COLLATE DATABASE_DEFAULT,
			SortOrder int
			)

		SET @SQLStatement_FieldList = '
		INSERT INTO #FieldList
			(
			DimensionID,
			DimensionName,
			PropertyID,
			PropertyName,
			ShortPropertyName,
			DataTypeID,
			DataTypeCode,
			SortOrder
			)
		SELECT
			DP.DimensionID,
			DimensionName = MO.MappedObjectName,
			P.PropertyID,
			P.PropertyName,
			ShortPropertyName = P.PropertyName,
			DataTypeID = CASE WHEN P.DataTypeID = 3 THEN 2 ELSE P.DataTypeID END,
			DataTypeCode = DaT.DataTypeCode + CASE WHEN DaT.SizeYN <> 0 THEN ''('' + CONVERT(nvarchar, ISNULL(P.Size, 255)) + '')'' ELSE '''' END + CASE WHEN DaT.DataTypeID = 2 THEN '' COLLATE DATABASE_DEFAULT'' ELSE '''' END,  
			P.SortOrder 
		FROM
			Property P
			INNER JOIN Dimension_Property DP ON DP.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND DP.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND DP.DimensionID = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND DP.PropertyID = P.PropertyID
			INNER JOIN Dimension D ON D.DimensionID = DP.DimensionID AND D.Introduced < ''' + @Version + ''' AND D.SelectYN <> 0
			INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
			INNER JOIN #ModelDimension MD ON MD.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND MD.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND MD.VisibilityLevelBM & 9 > 0
			INNER JOIN ' + @ETLDatabase + '.dbo.MappedObject MO ON MO.Entity = ''-1'' AND MO.ObjectName = D.DimensionName AND MO.DimensionTypeID = D.DimensionTypeID AND ((MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0) OR MD.VisibilityLevelBM & 8 > 0)
			INNER JOIN DataType DaT ON DaT.DataTypeID = CASE WHEN P.DataTypeID = 3 THEN 2 ELSE P.DataTypeID END
			LEFT JOIN Dimension DD ON DD.DimensionID = P.DependentDimensionID AND DD.SelectYN <> 0
			LEFT JOIN Model_Dimension DMD ON DMD.ModelID = ' + CONVERT(nvarchar(10), @BaseModelID) + ' AND DMD.DimensionID = P.DependentDimensionID AND DMD.VisibilityLevelBM & 9 > 0 AND DMD.Introduced < ''' + @Version + ''' AND DMD.SelectYN <> 0
			LEFT JOIN ' + @ETLDatabase + '.dbo.MappedObject DMO ON DMO.Entity = ''-1'' AND DMO.ObjectName = DD.DimensionName AND DMO.DimensionTypeID = DD.DimensionTypeID AND ((DMO.ObjectTypeBM & 4 > 0) OR DMD.VisibilityLevelBM & 8 > 0)
		WHERE
			P.PropertyID NOT BETWEEN 100 AND 1000 AND 
			P.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM_All) + ' > 0 AND
			P.StorageTypeBM & ' + CONVERT(nvarchar(10), @StorageTypeBM) + ' > 0 AND
			P.Introduced < ''' + @Version + ''' AND
			P.SelectYN <> 0 AND
			(DMO.ObjectName IS NULL OR (DMO.ObjectName IS NOT NULL AND DMO.SelectYN <> 0)) AND
			NOT EXISTS (SELECT 1 FROM Dimension DDD WHERE DDD.DimensionID = P.DependentDimensionID AND (DDD.Introduced >= ''' + @Version + ''' OR DDD.SelectYN = 0))'

		SET @SQLStatement_FieldList = @SQLStatement_FieldList + '

		UNION SELECT
			DP.DimensionID,
			DimensionName = MO.MappedObjectName,
			P.PropertyID,
			PropertyName = P.PropertyName + ''_MemberId'',
			ShortPropertyName = P.PropertyName,
			DataTypeID = 8,
			DataTypeCode = ''bigint'',
			P.SortOrder 
		FROM
			Property P
			INNER JOIN Dimension_Property DP ON DP.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND DP.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND DP.DimensionID = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND DP.PropertyID = P.PropertyID
			INNER JOIN Dimension D ON D.DimensionID = DP.DimensionID AND D.SelectYN <> 0
			INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
			INNER JOIN #ModelDimension MD ON MD.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND MD.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND MD.VisibilityLevelBM & 9 > 0
			INNER JOIN ' + @ETLDatabase + '.dbo.MappedObject MO ON MO.Entity = ''-1'' AND MO.ObjectName = D.DimensionName AND MO.DimensionTypeID = D.DimensionTypeID AND ((MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0) OR MD.VisibilityLevelBM & 8 > 0)
			LEFT JOIN Dimension DD ON DD.DimensionID = P.DependentDimensionID AND DD.SelectYN <> 0
			LEFT JOIN Model_Dimension DMD ON DMD.ModelID = ' + CONVERT(nvarchar(10), @BaseModelID) + ' AND DMD.DimensionID = P.DependentDimensionID AND DMD.VisibilityLevelBM & 9 > 0 AND DMD.Introduced < ''' + @Version + ''' AND DMD.SelectYN <> 0
			LEFT JOIN ' + @ETLDatabase + '.dbo.MappedObject DMO ON DMO.Entity = ''-1'' AND DMO.ObjectName = DD.DimensionName AND DMO.DimensionTypeID = DD.DimensionTypeID AND ((DMO.ObjectTypeBM & 4 > 0) OR DMD.VisibilityLevelBM & 8 > 0)
		WHERE
			P.PropertyID NOT BETWEEN 100 AND 1000 AND
			P.DataTypeID = 3 AND
			P.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM_All) + ' > 0 AND
			P.StorageTypeBM & ' + CONVERT(nvarchar(10), @StorageTypeBM) + ' > 0 AND
			P.Introduced < ''' + @Version + ''' AND
			P.SelectYN <> 0 AND
			(DMO.ObjectName IS NULL OR (DMO.ObjectName IS NOT NULL AND DMO.SelectYN <> 0)) AND
			NOT EXISTS (SELECT 1 FROM Dimension DDD WHERE DDD.DimensionID = P.DependentDimensionID AND (DDD.Introduced >= ''' + @Version + ''' OR DDD.SelectYN = 0))'

		IF @Debug <> 0 SELECT DimensionID = @DimensionID, BaseModelID = @BaseModelID, ETLDatabase = @ETLDatabase, ModelBM = @ModelBM
		IF @Debug <> 0 PRINT @SQLStatement_FieldList
		EXEC (@SQLStatement_FieldList)

	SET @Step = 'Handle SegmentProperty'
		IF (SELECT COUNT(1) FROM #FieldList WHERE PropertyName LIKE 'SegmentProperty%') > 0
			BEGIN
				--Create Temp tables
				CREATE TABLE #MappedObjectName
					(
					MappedObjectName nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				--Get All MappedObjectName
				SET @SQLStatement = '
				INSERT INTO #MappedObjectName
					(
					MappedObjectName 
					)
				SELECT DISTINCT
					MO.MappedObjectName
				FROM
					' + @ETLDatabase + '.[dbo].[MappedObject] MO
					INNER JOIN ' + @ETLDatabase + '.[dbo].[Entity] E ON E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND E.Entity = MO.Entity AND E.SelectYN <> 0
					INNER JOIN ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS ON FS.SourceID = E.SourceID AND FS.EntityCode = E.EntityCode AND FS.SegmentName = MO.ObjectName AND FS.DynamicYN = 0
					INNER JOIN Source S ON S.SourceID = E.SourceID AND S.SelectYN <> 0
					INNER JOIN Model M ON M.ModelID = S.ModelID
					INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 
					INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SelectYN <> 0
				WHERE
					MO.Entity <> ''-1'' AND
					MO.DimensionTypeID = -1 AND
					MO.ObjectTypeBM & 2 > 0 AND
					MO.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND
					MO.SelectYN <> 0'

				IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
				EXEC (@SQLStatement)

				--Add segments to #FieldList
				SET @SQLStatement = '
				INSERT INTO #FieldList
					(
					DimensionID,
					DimensionName,
					PropertyID,
					PropertyName,
					ShortPropertyName,
					DataTypeID,
					DataTypeCode,
					SortOrder
					)
				SELECT DISTINCT
					DimensionID = FL.DimensionID,
					DimensionName = FL.DimensionName,
					PropertyID = FL.PropertyID,
					PropertyName = MO.MappedObjectName + CASE WHEN FL.DataTypeID = 8 THEN ''_MemberId'' ELSE '''' END,
					ShortPropertyName = MO.MappedObjectName,
					DataTypeID = FL.DataTypeID,
					DataTypeCode = FL.DataTypeCode,
					SortOrder = FL.SortOrder
				FROM
					' + @ETLDatabase + '.[dbo].[MappedObject] MO
					INNER JOIN #FieldList FL ON FL.PropertyName LIKE ''SegmentProperty%''
					INNER JOIN #MappedObjectName MON ON MON.MappedObjectName = MO.MappedObjectName
				WHERE
					MO.Entity <> ''-1'' AND
					MO.DimensionTypeID = -1 AND
					MO.ObjectTypeBM & 2 > 0 AND
					MO.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND
					MO.SelectYN <> 0'

				IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
				
				EXEC (@SQLStatement)

				DELETE #FieldList WHERE PropertyName LIKE 'SegmentProperty%'

				DROP TABLE #MappedObjectName
			END

/*
		IF @DimensionID = 0
			INSERT INTO #FieldList
				(
				DimensionID,
				DimensionName,
				PropertyID,
				PropertyName,
				DataTypeID,
				DataTypeCode,
				SortOrder
				)
			SELECT
				P.DimensionID,
				DimensionName = NULL,
				P.PropertyID,
				P.PropertyName,
				DataTypeID = CASE WHEN P.DataTypeID = 3 THEN 2 ELSE P.DataTypeID END,
				DataTypeCode = DaT.DataTypeCode + CASE WHEN DaT.SizeYN <> 0 THEN '(' + CONVERT(nvarchar, ISNULL(P.Size, 255)) + ')' ELSE '' END + CASE WHEN DaT.DataTypeID = 2 THEN ' COLLATE DATABASE_DEFAULT' ELSE '' END,  
				P.SortOrder 
			FROM
				Property P
				INNER JOIN Dimension D ON D.DimensionID = 0 AND D.SelectYN <> 0
				INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
				INNER JOIN DataType DaT ON DaT.DataTypeID = CASE WHEN P.DataTypeID = 3 THEN 2 ELSE P.DataTypeID END
			WHERE
				P.DimensionID IN (0) AND
				P.PropertyID NOT BETWEEN 100 AND 1000 AND
				P.SourceTypeBM & @SourceTypeBM_All > 0 AND
				P.StorageTypeBM & @StorageTypeBM > 0 AND
				P.Introduced < @Version AND
				P.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM #FieldList FL WHERE FL.PropertyID = P.PropertyID)

		IF @Debug <> 0 SELECT TempTable = '#FieldList', * FROM #FieldList ORDER BY SortOrder, ShortPropertyName, PropertyName
*/
		IF @SortOrder IS NOT NULL
			SELECT DISTINCT
				ShortPropertyName,
				SortOrder
			FROM
				#FieldList
			WHERE
				SortOrder = @SortOrder OR
				@SortOrder = 0
			ORDER BY
				SortOrder, ShortPropertyName

	SET @Step = 'Select variables'
		SELECT 
			@SQLStatement_CreateTable = ISNULL(@SQLStatement_CreateTable, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + PropertyName + '] ' + DataTypeCode + CASE WHEN SortOrder = 80 THEN '' ELSE ',' END,
			@SQLStatement_InsertInto = ISNULL(@SQLStatement_InsertInto, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + PropertyName + ']' + CASE WHEN SortOrder = 80 THEN '' ELSE ',' END
		FROM
			#FieldList
		ORDER BY
			[SortOrder],
			[ShortPropertyName],
			[PropertyName]

		SELECT
			@DimensionName = MAX(DimensionName)
		FROM
			#FieldList

		IF @Debug <> 0 
			BEGIN
				PRINT @SQLStatement_CreateTable
				PRINT @SQLStatement_InsertInto
				PRINT @DimensionName
			END

	SET @Step = 'Drop temp tables'			
		DROP TABLE #FieldList
		DROP TABLE #ModelDimension

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

--	SET @Step = 'Insert into JobLog'
--		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
