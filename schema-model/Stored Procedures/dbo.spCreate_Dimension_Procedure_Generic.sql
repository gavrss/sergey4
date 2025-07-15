SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Dimension_Procedure_Generic]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SourceID int = NULL,
	@DimensionID int = NULL,
	@DimensionName nvarchar(50) = NULL,		--Mandatory if DimensionID = 0
	@DimensionTypeID int = NULL,			--Mandatory if DimensionID = 0
	@GenericYN bit = NULL,					--Mandatory if DimensionID = 0
	@Encryption smallint = 1,
	@ProcedureName nvarchar(100) = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000018,
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
EXEC spCreate_Dimension_Procedure_Generic @UserID = -2051, @InstanceID = -1017, @VersionID = -1017, @SourceID = -1579, @DimensionID = -3, @Debug = 1

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 1103, @DimensionID = -32, @Debug = 1, @ProcedureName = @ProcedureName OUT
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 103, @DimensionID = -3, @Debug = 1, @ProcedureName = @ProcedureName OUT
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 107, @DimensionID = -2, @Debug = 1, @ProcedureName = @ProcedureName OUT
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100) = '[spIU_0107_GL_Cost_Center]'
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 107, @DimensionID = 0, @DimensionName = 'GL_Cost_Center', @DimensionTypeID = -1, @GenericYN = 0, @ProcedureName = @ProcedureName OUT, @Debug = 1
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 1107, @DimensionID = -53, @DimensionName = 'FullAccount', @DimensionTypeID = 27, @GenericYN = 0, @ProcedureName = @ProcedureName OUT, @Debug = 1
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 557, @DimensionID = -1, @Debug = 1, @ProcedureName = @ProcedureName OUT
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 1227, @DimensionID = -1, @Debug = 1, @ProcedureName = @ProcedureName OUT
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 1227, @DimensionID = -53, @Debug = 1, @ProcedureName = @ProcedureName OUT
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 557, @DimensionID = -53, @Debug = 0, @ProcedureName = @ProcedureName OUT
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 110, @DimensionID = -9, @Debug = 1, @ProcedureName = @ProcedureName OUT
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 0, @DimensionID = -27, @Debug = 1, @ProcedureName = @ProcedureName OUT
SELECT ProcedureName = @ProcedureName

DECLARE
	@ProcedureName nvarchar(100)
EXEC spCreate_Dimension_Procedure_Generic @SourceID = 304,  @DimensionID = -22, @Debug = 1, @ProcedureName = @ProcedureName OUT  --AccountManager	iScala
SELECT ProcedureName = @ProcedureName

EXEC [spCreate_Dimension_Procedure_Generic] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	@SQLStatement nvarchar(max),
	@SQLTempTableInsertStatement nvarchar(max),
	@PropertyUpdate nvarchar(max),
	@PropertyInsert nvarchar(max),
	@SQLStatement_CreateTable nvarchar(max),
	@ViewName nvarchar(100),
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@Action nvarchar(10),
	@SourceID_varchar nvarchar(10),
	@MappedDimensionName nvarchar(100),
	@SourceTypeName nvarchar(50),
	@MappedPropertyName nvarchar(100),
	@PropertyName nvarchar(100),
	@MultipleProcedureYN bit,
	@PropertyID int,
	@SourceDBTypeID int,
	@ApplicationID int,
	@MasterDimensionID int,
	@MasterDimensionName nvarchar(100),
	@HierarchyMasterDimensionID int,
	@HierarchyMasterDimensionName nvarchar(100),
	@HierarchySortOrderField nvarchar(100),
	@SourceTypeBM_All int,
	@StorageTypeBM int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@CalledProcedureName nvarchar(100),
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
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@CalledProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create Load SPs for dimensions',
			@MandatoryParameter = 'SourceID|DimensionID' --Without @, separated by |

		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2063' SET @Description = 'Length of nvarchar-conversions changed to 255 for Labels.'
		IF @Version = '1.2.2068' SET @Description = 'SET ANSI_WARNINGS OFF.'
		IF @Version = '1.3.2070' SET @Description = 'Collation problems fixed. SET ANSI_WARNINGS ON if needed.'
		IF @Version = '1.3.2071' SET @Description = 'Handle SegmentProperty. Handle SourceID = 0'
		IF @Version = '1.3.2074' SET @Description = 'Test on MemberId is not  NULL in hierarchy creation'
		IF @Version = '1.3.2077' SET @Description = 'Changed handling of FullAccount when SourceDBType = 2'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2095' SET @Description = 'Added RNodeType'
		IF @Version = '1.3.2096' SET @Description = 'Improved handling of SegmentProperty'
		IF @Version = '1.3.2101' SET @Description = 'Added reference to spSet_LeafCheck. Check AllYN.'
		IF @Version = '1.3.2104' SET @Description = 'Move Entity Prioritization to wrk_EntityPriority...'
		IF @Version = '1.3.2105' SET @Description = 'Dont check wrk_EntityPriority on Generic procedures.'
		IF @Version = '1.3.2110' SET @Description = 'Introduced parameter [SynchronizedYN] in Property.'
		IF @Version = '1.3.2116' SET @Description = 'Handle HelpText. Handle unicode. Handle MasterDimensionID.'
		IF @Version = '1.3.1.2120' SET @Description = 'Test on @SourceTypeBM.'
		IF @Version = '1.3.1.2123' SET @Description = 'Handle @MultipleProcedureYN.'
		IF @Version = '1.4.0.2129' SET @Description = 'Handle @HierarchyMasterDimensionID. (FullAccount)'
		IF @Version = '1.4.0.2135' SET @Description = 'Handle multiple leaf level sequences. Removed ISNULL-check for ParentMemberID.'
		IF @Version = '1.4.0.2139' SET @Description = 'Exclude NodeTypeBM.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @CalledProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@CalledProcedureName = OBJECT_NAME(@@PROCID),
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

		IF @SourceID = 0
			SELECT DISTINCT
				@ApplicationID = M.ApplicationID,
				@ETLDatabase = A.ETLDatabase,
				@DestinationDatabase = A.DestinationDatabase,
				@SourceTypeName = 'ETL',
				@SourceDBTypeID = 1
			FROM
				Model_Dimension MD 
				INNER JOIN Model BM ON BM.ModelID = MD.ModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
				INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.SelectYN <> 0
				INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.InstanceID = @InstanceID AND A.VersionID = @VersionID
				INNER JOIN [Language] L ON L.LanguageID = A.LanguageID
			WHERE
				MD.DimensionID = @DimensionID AND
				MD.Introduced < @Version AND
				MD.SelectYN <> 0
		ELSE
			SELECT
				@ApplicationID = A.ApplicationID,
				@ETLDatabase = A.ETLDatabase,
				@DestinationDatabase = A.DestinationDatabase,
				@SourceTypeName = ST.SourceTypeName,
				@SourceDBTypeID = ST.SourceDBTypeID
			FROM
				Source S
				INNER JOIN Model M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
				INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.InstanceID = @InstanceID AND A.VersionID = @VersionID
				INNER JOIN [Language] L ON L.LanguageID = A.LanguageID
				INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			WHERE
				SourceID = @SourceID

		SELECT
			@MasterDimensionID = MasterDimensionID,
			@HierarchyMasterDimensionID = HierarchyMasterDimensionID,
			@MultipleProcedureYN = MultipleProcedureYN
		FROM
			Dimension
		WHERE
			DimensionID = @DimensionID

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

		SELECT
			@StorageTypeBM = StorageTypeBM
		FROM
			Dimension_StorageType
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		SET @StorageTypeBM = ISNULL(@StorageTypeBM, 4)

	SET @Step = 'Get @MappedDimensionName'
		IF @DimensionID <> 0
			BEGIN
				SELECT
					@DimensionName = ISNULL(@DimensionName, DimensionName),
					@DimensionTypeID = ISNULL(@DimensionTypeID, DimensionTypeID),
					@GenericYN = ISNULL(@GenericYN, GenericYN)
				FROM
					Dimension
				WHERE
					DimensionID = @DimensionID

				CREATE TABLE #MappedDimension
					(
					DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT,
					MappedDimensionName nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				SET @SQLStatement = '
				INSERT INTO #MappedDimension
					(
					DimensionName,
					MappedDimensionName
					)
				SELECT
					DimensionName = ObjectName,
					MappedDimensionName = MappedObjectName
				FROM
					[' + @ETLDatabase + '].[dbo].[MappedObject] MO
				WHERE
					MO.ObjectName = ''' + @DimensionName + ''' AND
					MO.ObjectTypeBM & 2 > 0 AND
					MO.Entity = ''-1'''

				EXEC (@SQLStatement)
				IF @Debug <> 0 PRINT @SQLStatement
				IF @Debug <> 0 SELECT TempTable = '#MappedDimension', * FROM #MappedDimension

				SELECT
					@MappedDimensionName = MappedDimensionName
				FROM
					#MappedDimension

				DROP TABLE #MappedDimension
			END

	SET @Step = 'Get @MasterDimensionName'
		IF @MasterDimensionID IS NOT NULL
			BEGIN
				CREATE TABLE #MasterDimension
					(
					MasterDimensionName nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				SET @SQLStatement = '
				INSERT INTO #MasterDimension
					(
					MasterDimensionName
					)
				SELECT
					MappedDimensionName = MO.MappedObjectName
				FROM
					Dimension D
					INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.ObjectName = D.DimensionName AND MO.ObjectTypeBM & 2 > 0 
				WHERE
					D.DimensionID = ' + CONVERT(nvarchar(10), @MasterDimensionID)

				EXEC (@SQLStatement)
				IF @Debug <> 0 PRINT @SQLStatement
				IF @Debug <> 0 SELECT TempTable = '#MasterDimension', * FROM #MasterDimension

				SELECT
					@MasterDimensionName = MasterDimensionName
				FROM
					#MasterDimension

				DROP TABLE #MasterDimension
			END

	SET @Step = 'Get @HierarchyMasterDimensionName'
		IF @HierarchyMasterDimensionID IS NOT NULL
			BEGIN
				CREATE TABLE #HierarchyMasterDimension
					(
					HierarchyMasterDimensionName nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				SET @SQLStatement = '
				INSERT INTO #HierarchyMasterDimension
					(
					HierarchyMasterDimensionName
					)
				SELECT
					MappedDimensionName = MO.MappedObjectName
				FROM
					Dimension D
					INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.ObjectName = D.DimensionName AND MO.ObjectTypeBM & 2 > 0 
				WHERE
					D.DimensionID = ' + CONVERT(nvarchar(10), @HierarchyMasterDimensionID)

				EXEC (@SQLStatement)
				IF @Debug <> 0 PRINT @SQLStatement
				IF @Debug <> 0 SELECT TempTable = '#HierarchyMasterDimension', * FROM #HierarchyMasterDimension

				SELECT
					@HierarchyMasterDimensionName = HierarchyMasterDimensionName
				FROM
					#HierarchyMasterDimension

				DROP TABLE #HierarchyMasterDimension
			END

		IF @Debug <> 0
			SELECT 
				ETLDatabase = @ETLDatabase,
				DestinationDatabase = @DestinationDatabase,
				DimensionName = @DimensionName,
				GenericYN = @GenericYN,
				SourceTypeName = @SourceTypeName,
				DimensionTypeID = @DimensionTypeID

	SET @Step = 'Determine ObjectName'
		IF @GenericYN <> 0
			SET @SourceID_varchar = '0000'
		ELSE
			SET @SourceID_varchar = CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID))

	SET @Step = 'Determine ProcedureName'
		IF @DimensionTypeID < 0	
			BEGIN
				IF @SourceDBTypeID = 2
					BEGIN
						SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_GL_Segment'
						RETURN 0
					END
				SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_' + @DimensionName
				SET @ViewName = 'vw_' + @SourceID_varchar + '_' + @DimensionName
				SET @MappedDimensionName = @DimensionName
			END
		ELSE
			BEGIN
				SET @ViewName = 'vw_' + @SourceID_varchar + '_' + @MappedDimensionName
				SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_' + @MappedDimensionName
			END

		IF @Debug <> 0 SELECT SourceID_varchar = @SourceID_varchar, DimensionName = @DimensionName, MappedDimensionName = @MappedDimensionName, ProcedureName = @ProcedureName

	SET @Step = 'Determine CREATE or ALTER'
		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = N'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject N''' + @ProcedureName + '''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
		SELECT @Action = [Action] FROM #Action
		DROP TABLE #Action

	SET @Step = 'Get extra properties'
		CREATE TABLE [dbo].[#MappedProperty](
			[DimensionID] int NOT NULL,
			[PropertyID] int NOT NULL,
			[PropertyName] [nvarchar](100) NOT NULL,
			[MappedPropertyName] [nvarchar](100) NOT NULL,
			[DataTypeID] [int] NOT NULL,
			[SynchronizedYN] [bit] NOT NULL,
			[SortOrder] [int] NOT NULL,
			[ViewPropertyYN] [bit] NOT NULL,
			[HierarchySortOrderYN] [bit] NOT NULL,
			[SelectYN] [bit] NULL
		)
	
		SET @SQLStatement = '
			INSERT INTO #MappedProperty
			(
				[DimensionID],
				[PropertyID],
				[PropertyName],
				[MappedPropertyName],
				[DataTypeID],
				[SynchronizedYN],
				[SortOrder],
				[ViewPropertyYN],
				[HierarchySortOrderYN],
				[SelectYN]
			)
			SELECT 
				P.[DimensionID],
				P.[PropertyID],
				PropertyName = P.PropertyName,
				MappedPropertyName = ISNULL(MO.[MappedObjectName], P.PropertyName),
				P.[DataTypeID], 
				P.[SynchronizedYN],
				P.[SortOrder],
				P.[ViewPropertyYN],
				P.[HierarchySortOrderYN],
				MO.[SelectYN]
			FROM
				Property P
				LEFT JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.ObjectName = P.PropertyName AND MO.ObjectTypeBM & 4 > 0
			WHERE
				(P.DimensionID = ' + CONVERT(nvarchar, @DimensionID) + ' OR P.DimensionID = 0) AND
				P.PropertyID NOT BETWEEN 100 AND 1000 AND
				P.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM_All) + ' > 0 AND
				P.StorageTypeBM & ' + CONVERT(nvarchar(10), @StorageTypeBM) + ' > 0 AND
				P.Introduced < ''' + @Version + ''' AND
				P.SelectYN <> 0 AND
				(MO.ObjectName IS NULL OR (MO.ObjectName IS NOT NULL AND MO.SelectYN <> 0)) AND
				NOT EXISTS (SELECT 1 FROM Dimension DDD WHERE DDD.DimensionID = P.DependentDimensionID AND (DDD.Introduced > ''' + @Version + ''' OR DDD.SelectYN = 0))'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#MappedProperty', * FROM #MappedProperty ORDER BY SortOrder, DimensionID, MappedPropertyName

	SET @Step = 'Handle SegmentProperty'
		IF (SELECT COUNT(1) FROM #MappedProperty WHERE PropertyName = 'SegmentProperty') > 0
			BEGIN
				CREATE TABLE #ColumnList
					(
					ShortPropertyName nvarchar(100) COLLATE DATABASE_DEFAULT,
					SortOrder int
					)

				INSERT INTO #ColumnList EXEC spGet_FieldList @SourceID = @SourceID, @DimensionID = @DimensionID, @SortOrder = 32

				SET @SQLStatement = '
				INSERT INTO #MappedProperty
					(
					[DimensionID],
					[PropertyID],
					[PropertyName],
					[MappedPropertyName],
					[DataTypeID],
					[SynchronizedYN],
					[SortOrder],
					[ViewPropertyYN],
					[HierarchySortOrderYN],
					[SelectYN]
					)
				SELECT DISTINCT
					[DimensionID] = MP.DimensionID,
					[PropertyID] = MP.PropertyID,
					[PropertyName] = MO.MappedObjectName,
					[MappedPropertyName] = MO.MappedObjectName,
					[DataTypeID] = MP.DataTypeID,
					[SynchronizedYN] = MP.[SynchronizedYN],
					[SortOrder] = MP.SortOrder,
					[ViewPropertyYN] = MP.[ViewPropertyYN],
					[HierarchySortOrderYN] = MP.[HierarchySortOrderYN],
					[SelectYN] = 1
				FROM
					[' + @ETLDatabase + '].[dbo].[MappedObject] MO
					INNER JOIN #ColumnList FL ON FL.ShortPropertyName = MO.MappedObjectName
					INNER JOIN #MappedProperty MP ON MP.PropertyName = ''SegmentProperty''
				WHERE
					MO.Entity <> ''-1'' AND
					MO.DimensionTypeID = -1 AND
					MO.ObjectTypeBM & 2 > 0 AND
					MO.SelectYN <> 0'

				IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
				
				EXEC (@SQLStatement)

				DELETE #MappedProperty WHERE PropertyName = 'SegmentProperty'
				DROP TABLE #ColumnList
			END

		IF @Debug <> 0 SELECT TempTable = '#MappedProperty', * FROM [#MappedProperty] ORDER BY SortOrder, DimensionID, MappedPropertyName

		SELECT @HierarchySortOrderField = MAX('V.' + [PropertyName]) FROM #MappedProperty WHERE [HierarchySortOrderYN] <> 0
		SELECT @HierarchySortOrderField = ISNULL(@HierarchySortOrderField, 'D1.MemberId')

		IF @Debug <> 0 
			SELECT
				PropertyUpdate = @PropertyUpdate,
				*
			FROM
				[#MappedProperty]
			WHERE
				[SynchronizedYN] <> 0
			ORDER BY
				SortOrder,
				DimensionID,
				MappedPropertyName

		SELECT
			@PropertyUpdate = COALESCE(@PropertyUpdate + ', ' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9), '') + '[' + MappedPropertyName + '] = Members.[' + MappedPropertyName + ']' +
			CASE WHEN DataTypeID = 3 THEN ', ' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + MappedPropertyName + '_MemberId] = Members.[' + MappedPropertyName + '_MemberId]' ELSE '' END
		FROM
			[#MappedProperty]
		WHERE
			[SynchronizedYN] <> 0 AND
			[ViewPropertyYN] = 0
		ORDER BY
			SortOrder,
			DimensionID,
			MappedPropertyName

		IF @Debug <> 0 PRINT @PropertyUpdate
		IF @Debug <> 0 SELECT SourceID = @SourceID, DimensionID = @DimensionID, JobID = @JobID
				 
	SET @Step = 'Get Fieldlist'
		EXEC spGet_FieldList
			@SourceID = @SourceID,
			@DimensionID = @DimensionID, 
			@JobID = @JobID, 
			@SQLStatement_CreateTable = @SQLStatement_CreateTable OUT

		IF @Debug <> 0 
			BEGIN
				SELECT
					SourceID = @SourceID,
					DimensionID = @DimensionID, 
					JobID = @JobID, 
					SQLStatement_CreateTable = @SQLStatement_CreateTable

				PRINT @SQLStatement_CreateTable
			END

		SELECT
			@PropertyInsert = COALESCE(@PropertyInsert, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + MappedPropertyName + ']' + CASE WHEN MP.SortOrder = 70 THEN '' ELSE ',' END +
			CASE WHEN MP.DataTypeID = 3 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + MappedPropertyName + '_MemberId],'  ELSE '' END
		FROM
			[#MappedProperty] MP
			INNER JOIN pcINTEGRATOR.dbo.Property P ON P.PropertyID = MP.PropertyID
			INNER JOIN pcINTEGRATOR.dbo.DataType DT ON DT.DataTypeID = MP.DataTypeID
		WHERE
			(MP.DimensionID = @DimensionID OR MP.DimensionID = 0) AND
			MP.[ViewPropertyYN] = 0
			
			--MP.PropertyID <> 3
		ORDER BY
			MP.SortOrder,
			MP.DimensionID,
			MP.MappedPropertyName

		IF @Debug <> 0 PRINT @PropertyInsert

		SET @PropertyUpdate = ISNULL(@PropertyUpdate, '')

	SET @Step = 'CREATE PROCEDURE'
--		IF @SourceDBTypeID = 2 AND @GenericYN = 0 AND @DimensionID NOT IN (-53)
		IF @SourceDBTypeID = 2 AND @MultipleProcedureYN <> 0 AND @DimensionID NOT IN (-53)

			SET	@SQLTempTableInsertStatement = '

		INSERT INTO [#' + @MappedDimensionName + '_Members] EXEC spIU_' + @SourceID_varchar + '_' + @MappedDimensionName +'_Raw @JobID = @JobID, @SourceID = @SourceID, @Entity = @Entity, @Rows = @Rows'
		ELSE
			SET	@SQLTempTableInsertStatement = '

		EXEC spIU_' + @SourceID_varchar + '_' + @MappedDimensionName +'_Raw @JobID = @JobID, @SourceID = @SourceID, @Entity = @Entity, @Rows = @Rows'
/*
			SET	@SQLTempTableInsertStatement = '

		IF @Rows IS NULL
			INSERT INTO [#' + @MappedDimensionName + '_Members] SELECT * FROM [' + @ViewName + ']
		ELSE
			BEGIN
				SET @SQLStatement = N''''
				INSERT INTO [#' + @MappedDimensionName + '_Members] SELECT TOP '''' + CONVERT(nvarchar(10), @Rows) + N'''' * FROM [' + @ViewName + ']''''
				EXEC (@SQLStatement)
			END'
*/
		IF @Debug <> 0 PRINT @SQLTempTableInsertStatement

		SET @SQLStatement = '
SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(1000),
	' + CASE WHEN @SourceDBTypeID = 1 THEN '@SQLStatement_Prio nvarchar(max),' + CHAR(13) + CHAR(10) + CHAR(9) ELSE '' END + '@LinkedYN bit,

	@Step nvarchar(255),
	@Message nvarchar(500) = '''''''',
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
	@CreatedBy nvarchar(50) = ''''Auto'''',
	@ModifiedBy nvarchar(50) = ''''Auto'''',
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
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Step = ''''Create temp table''''
		CREATE TABLE [#' + @MappedDimensionName + '_Members]
		(' + @SQLStatement_CreateTable + '
		)

	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT'

		SET @SQLStatement = @SQLStatement + '
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON' +

	CASE WHEN @SourceDBTypeID = 1 AND @GenericYN = 0 THEN '

	SET @Step = ''''Set Entity priority order''''
		DELETE ' + @ETLDatabase + '.[dbo].[wrk_EntityPriority_Member] WHERE DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND SourceID = @SourceID

		DECLARE
			@SequenceBM int

		DECLARE EntityPriority_Cursor CURSOR FOR
			SELECT 
				SequenceBM
			FROM
				' + @ETLDatabase + '.[dbo].[wrk_EntityPriority_SQLStatement]
			WHERE
				DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND
				SourceID = @SourceID

			OPEN EntityPriority_Cursor
			FETCH NEXT FROM EntityPriority_Cursor INTO @SequenceBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					--SELECT SequenceBM = @SequenceBM
					
					SELECT @SQLStatement_Prio = SQLStatement FROM ' + @ETLDatabase + '.[dbo].[wrk_EntityPriority_SQLStatement] WHERE DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND SourceID = @SourceID AND SequenceBM = @SequenceBM
					IF @SQLStatement_Prio IS NOT NULL
						EXEC (@SQLStatement_Prio)
					
					FETCH NEXT FROM EntityPriority_Cursor INTO @SequenceBM
				END

		CLOSE EntityPriority_Cursor
		DEALLOCATE EntityPriority_Cursor' ELSE '' END + '

	SET @Step = ''''Insert into temp table'''''
		SET @SQLStatement = @SQLStatement + @SQLTempTableInsertStatement + '

		SET ANSI_WARNINGS OFF

	SET @Step = ''''Update Description and dimension specific Properties from ' + @SourceTypeName + ' where Synchronized is set to true.''''
		UPDATE
			[' + @MappedDimensionName + ']
		SET
			' + @PropertyUpdate + '  
		FROM
			[' + @DestinationDatabase + '].[dbo].[S_DS_' + @MappedDimensionName + '] [' + @MappedDimensionName + '] 
			INNER JOIN [#' + @MappedDimensionName + '_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [' + @MappedDimensionName + '].LABEL 
		WHERE 
			[' + @MappedDimensionName + '].[Synchronized] <> 0

		SET @Updated = @Updated + @@ROWCOUNT
		
	SET @Step = ''''Insert new members from ' + @SourceTypeName + '''''
		INSERT INTO [' + @DestinationDatabase + '].[dbo].[S_DS_' + @MappedDimensionName + ']
			(' + @PropertyInsert + '
			)
		SELECT' + @PropertyInsert + '
		FROM   
			[#' + @MappedDimensionName + '_Members] Members
		WHERE
			NOT EXISTS (SELECT 1 FROM [' + @DestinationDatabase + '].[dbo].[S_DS_' + @MappedDimensionName + '] [' + @MappedDimensionName + '] WHERE Members.Label = [' + @MappedDimensionName + '].Label)

		SET @Inserted = @Inserted + @@ROWCOUNT'

		SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Update MemberId''''
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = N''''' + @DestinationDatabase + ''''', @Dimension = N''''' + @MappedDimensionName + ''''', @JobID = @JobID, @Debug = @Debug

	SET @Step = ''''Check which parent members have leaf members as children.''''
		' + CASE WHEN @HierarchyMasterDimensionID IS NOT NULL THEN 'TRUNCATE TABLE [' + @DestinationDatabase + '].[dbo].[S_HS_' + @MappedDimensionName + '_' + @MappedDimensionName + ']' + CHAR(13) + CHAR(10) ELSE '' END + '
		CREATE TABLE #LeafCheck
			(
			[MemberId] [bigint] NOT NULL,
			HasChild bit NOT NULL
			)

		EXEC [pcINTEGRATOR].[dbo].[spSet_LeafCheck] @Database = N''''' + @DestinationDatabase + ''''', @Dimension = N''''' + @MappedDimensionName + ''''', @JobID = @JobID, @Debug = @Debug
		'

		IF @HierarchyMasterDimensionID IS NULL
			SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Insert new members into the default hierarchy. Not Synchronized members will not be added. To change the hierarchy, use the Modeler.'''''
		ELSE
			SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Insert members into the default hierarchy. Not Synchronized members will not be added. To change the hierarchy, use the Modeler and change the hierarchy in the ' + @HierarchyMasterDimensionName + ' dimension (used as master).'''''

		IF @MasterDimensionID IS NOT NULL AND @HierarchyMasterDimensionID IS NOT NULL AND @MasterDimensionID = @HierarchyMasterDimensionID
			SET @SQLStatement = @SQLStatement + '
		INSERT INTO [' + @DestinationDatabase + '].[dbo].[S_HS_' + @MappedDimensionName + '_' + @MappedDimensionName + ']
			(
			[MemberId],
			[ParentMemberId],
			[SequenceNumber]
			)
		SELECT
			[MemberId],
			[ParentMemberId],
			[SequenceNumber] 
		FROM
			[' + @DestinationDatabase + '].[dbo].[S_HS_' + @MasterDimensionName + '_' + @MasterDimensionName + ']'
		ELSE
			SET @SQLStatement = @SQLStatement + '
		INSERT INTO [' + @DestinationDatabase + '].[dbo].[S_HS_' + @MappedDimensionName + '_' + @MappedDimensionName + ']
			(
			[MemberId],
			[ParentMemberId],
			[SequenceNumber]
			)
		SELECT
			[MemberId] = D1.MemberId,
			[ParentMemberId] = ISNULL(D2.MemberId, 0),
			[SequenceNumber] = ' + @HierarchySortOrderField + ' 
		FROM
			[' + @DestinationDatabase + '].[dbo].[S_DS_' + @MappedDimensionName + '] D1
			INNER JOIN [#' + @MappedDimensionName + '_Members] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
			LEFT JOIN [' + @DestinationDatabase + '].[dbo].[S_DS_' + @MappedDimensionName + '] D2 ON D2.Label = CONVERT(nvarchar(255), V.Parent) COLLATE DATABASE_DEFAULT
			LEFT JOIN [#LeafCheck] LC ON LC.MemberId = D1.MemberId AND LC.HasChild <> 0
		WHERE
			NOT EXISTS (SELECT 1 FROM [' + @DestinationDatabase + '].[dbo].[S_HS_' + @MappedDimensionName + '_' + @MappedDimensionName + '] H WHERE H.MemberId = D1.MemberId) AND' + CASE WHEN @HierarchyMasterDimensionID IS NULL THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[D1].[Synchronized] <> 0 AND' ELSE '' END + '
			D1.MemberId <> ISNULL(D2.MemberId, 0) AND
			D1.MemberId IS NOT NULL AND
			(D2.MemberId IS NOT NULL OR @Rows IS NULL OR D1.Label = ''''All_'''' OR V.Parent IS NULL) AND
			(D1.RNodeType IN (''''L'''', ''''LC'''') OR LC.MemberId IS NOT NULL)
		ORDER BY
			' + @HierarchySortOrderField

		SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Copy the hierarchy to all instances''''
		EXEC [pcINTEGRATOR].[dbo].[spSet_HierarchyCopy] @Database = N''''' + @DestinationDatabase + ''''', @Dimensionhierarchy = N''''' + @MappedDimensionName + '_' + @MappedDimensionName + ''''', @JobID = @JobID, @Debug = @Debug

	SET @Step = ''''Drop temp tables''''
		DROP TABLE [#' + @MappedDimensionName + '_Members]
		DROP TABLE [#LeafCheck]

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = ''''Define exit point''''
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)'

	IF @Debug <> 0
		SELECT
			[Version] = @Version,
			MappedDimensionName = @MappedDimensionName,
			SQLStatement_CreateTable = @SQLStatement_CreateTable,
			SQLTempTableInsertStatement = @SQLTempTableInsertStatement ,
			SourceTypeName = @SourceTypeName,
			PropertyUpdate = @PropertyUpdate,
			DestinationDatabase = @DestinationDatabase,
			SourceTypeName = @SourceTypeName,
			PropertyInsert = @PropertyInsert

	SET @Step = 'Make Creation statement  '
		SET @ProcedureName = '[' + @ProcedureName + ']'

		SET @SQLStatement = @Action + ' PROCEDURE [dbo].' + @ProcedureName + '

	@UserID int = ' + CONVERT(nvarchar(10), @UserID) + ',
	@InstanceID int = ' + CONVERT(nvarchar(10), @InstanceID) + ',
	@VersionID int = ' + CONVERT(nvarchar(10), @VersionID) + ',

	@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
	@Entity nvarchar(50) = ''''-1'''',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = ' + CONVERT(nvarchar, @ProcedureID) + ',
	@StartTime datetime = NULL,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS' + CHAR(13) + CHAR(10) + @SQLStatement

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of Stored Procedure', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)

	SET @Step = 'Drop temporary tables'	
		DROP TABLE #MappedProperty

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @CalledProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @CalledProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
