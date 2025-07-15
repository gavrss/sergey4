SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Dimension_Procedure_pcEXCHANGE] 

	@SourceID int = NULL,
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

--EXEC spCreate_Dimension_Procedure_pcEXCHANGE @SourceID = 647, @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@Action nvarchar(10),
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@ApplicationID int,
	@InstanceID int,
	@SourceTypeID int,
	@SourceID_varchar nvarchar(10),
	@ObjectName nvarchar(50),
	@Description nvarchar(255),
	@ProcedureName nvarchar(100),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2070' SET @Description = 'Procedure introduced.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2107' SET @Description = 'Changed handling. Only add licensed dimensions.'
		IF @Version = '1.3.2110' SET @Description = 'Insert of [MemberId]. Insert of default values for not defined properties.'
		IF @Version = '1.3.0.2118' SET @Description = 'Fetch HelpText from Member table. Fixed bug on insert counting.'
		IF @Version = '1.3.1.2120' SET @Description = 'Changed handling of missing properties.'
		IF @Version = '1.4.0.2139' SET @Description = 'Changed reference to MappedObject.'

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

		SELECT
			@InstanceID = A.InstanceID,
			@ApplicationID = A.ApplicationID,
			@SourceTypeID = S.SourceTypeID,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@DestinationDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.SelectYN <> 0
		WHERE
			S.SourceID = @SourceID AND
			S.SelectYN <> 0

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		IF @Debug <> 0 SELECT InstanceID = @InstanceID, ApplicationID = @ApplicationID, SourceTypeID = @SourceTypeID, SourceDatabase = @SourceDatabase, ETLDatabase = @ETLDatabase, DestinationDatabase = @DestinationDatabase

		IF @SourceTypeID = 6
			SET @SourceID_varchar = '6000'
		ELSE
			RETURN

	SET @Step = 'SET @ObjectName'
		SET @ObjectName = 'spIU_' + @SourceID_varchar + '_Dimension'

	SET @Step = 'CREATE TABLE #Action'
		CREATE TABLE #Action
		(
		[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
		)

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
		SELECT @Action = [Action] FROM #Action

	SET @Step = 'Set @SQLStatement'
--  BEGIN
		SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ObjectName + '] 
	@JobID int = 0,
	@ApplicationID int = ' + CONVERT(nvarchar(10), @ApplicationID) + ',
	@SourceID int = ' + @SourceID_varchar + ',
	@ETLDatabase nvarchar(100) = ''''' + @ETLDatabase + ''''',
	@DestinationDatabase nvarchar(100) = ''''' + @DestinationDatabase + ''''',
	@Rows int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

--EXEC [spIU_6000_Dimension] @Debug = 1

AS

SET NOCOUNT ON

DECLARE
	@StartTime datetime,
	@StartTime_Step datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Deleted_Step int = 0,
    @Inserted_Step int = 0,
    @Updated_Step int = 0,
	@DimensionID int,
	@SourceDimension nvarchar(100),
	@Dimension nvarchar(100),
	@ApplicationName nvarchar(100),
	@SQLInsert nvarchar(max),
	@SQLSelect nvarchar(max),
	@SQLJoin nvarchar(max),
	@SQLStatement nvarchar(max),
	@Counter int = 0,
	@PropertyName nvarchar(100),
	@PropertyDataTypeID int,
	@PropertyMemberDimension nvarchar(100),
	@HierarchyName nvarchar(100),
	@SourceID_varchar nvarchar(10),
	@ProcedureName nvarchar(100),
	@SourceDatabase nvarchar(100),
	@DefaultValueView nvarchar(255),
	@DimensionName nvarchar(100),
	@RNodeTypeFieldName nvarchar(50),
	@SBZ nvarchar(100),
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()'

	SET @SQLStatement = @SQLStatement + '
    SET @Step = ''''Set procedure variables''''
        SET DATEFIRST 1

		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

    SET @Step = ''''Create cursor table with sortorder''''
		CREATE TABLE #Dimension_Cursor
			(
			DimensionID int,
			SourceDimensionName nvarchar(100) COLLATE DATABASE_DEFAULT,
			DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT,
			SortOrder int
			)

		CREATE TABLE #6000_Property ([Counter] int, PropertyName nvarchar(100) COLLATE DATABASE_DEFAULT, PropertyDataTypeID int, PropertyMemberDimension nvarchar(100) COLLATE DATABASE_DEFAULT)
		CREATE TABLE #6000_PropertyCount (PropertyCount int)
		CREATE TABLE #Hierarchy (HierarchyName nvarchar(100) COLLATE DATABASE_DEFAULT)
		CREATE TABLE #DependentDim (PropertyName nvarchar(100) COLLATE DATABASE_DEFAULT, DefaultValueView nvarchar(255) COLLATE DATABASE_DEFAULT, DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT)
		CREATE TABLE #DefaultValue (PropertyName nvarchar(100) COLLATE DATABASE_DEFAULT, DefaultValueView nvarchar(255) COLLATE DATABASE_DEFAULT)
		CREATE TABLE #Dimension_Members ([MemberId] [bigint], [Label] [nvarchar](50) COLLATE DATABASE_DEFAULT, [RNodeType] [nvarchar](2) COLLATE DATABASE_DEFAULT, [Parent] nvarchar(50) COLLATE DATABASE_DEFAULT)
		CREATE TABLE #LeafCheck ([MemberId] [bigint] NOT NULL, HasChild bit NOT NULL)

	SET @Step = ''''Create SourceDatabase cursor''''
		SELECT DISTINCT
			SourceDatabase = ''''['''' + REPLACE(REPLACE(REPLACE(MAX(S.SourceDatabase), ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']''''
		INTO
			#SourceDatabase_Cursor
		FROM
			pcINTEGRATOR.[dbo].[Source] S
			INNER JOIN pcINTEGRATOR.[dbo].[Model] M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
			INNER JOIN pcINTEGRATOR.[dbo].[Application] A ON A.ApplicationID = M.ApplicationID AND A.ApplicationID = @ApplicationID AND A.SelectYN <> 0
		WHERE
			S.SourceTypeID = 6 AND
			S.SelectYN <> 0

		IF @Debug <> 0 SELECT TempTable = ''''#SourceDatabase_Cursor'''', * FROM #SourceDatabase_Cursor

		DECLARE SourceDatabase_Cursor CURSOR FOR

		SELECT 
			SourceDatabase
		FROM
			#SourceDatabase_Cursor
		ORDER BY
			SourceDatabase

		OPEN SourceDatabase_Cursor
		FETCH NEXT FROM SourceDatabase_Cursor INTO @SourceDatabase

		WHILE @@FETCH_STATUS = 0
			BEGIN

    SET @Step = ''''Set @ApplicationName variable''''
		CREATE TABLE #ApplicationName (ApplicationName nvarchar(100) COLLATE DATABASE_DEFAULT)
		SET @SQLStatement = ''''
		INSERT INTO #ApplicationName (ApplicationName) SELECT [ApplicationName] FROM '''' + @SourceDatabase + ''''.[dbo].[SysParam] WHERE [SysParamID] = 1''''
		EXEC (@SQLStatement)
		SELECT @ApplicationName = [ApplicationName] FROM #ApplicationName
		DROP TABLE #ApplicationName'

	SET @SQLStatement = @SQLStatement + '

    SET @Step = ''''Fill Dimension cursor table with sortorder''''
		TRUNCATE TABLE #Dimension_Cursor

		--With no member properties
		SET @SQLStatement = ''''
		INSERT INTO #Dimension_Cursor
			(
			DimensionID,
			SourceDimensionName,
			DimensionName,
			SortOrder
			)
		SELECT DISTINCT
			D.DimensionID,
			SourceDimensionName = D.DimensionName,
			MO.MappedObjectName,
			SortOrder = 1
		FROM
			'''' + @SourceDatabase + ''''.[dbo].[Dimension] D
			INNER JOIN '''' + @ETLDatabase + ''''..MappedObject MO ON MO.MappedObjectName = D.DimensionName AND MO.DimensionTypeID = D.DimensionTypeID AND MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0
			INNER JOIN '''' + @DestinationDatabase + ''''.sys.tables t ON t.[name] = ''''''''S_DS_'''''''' + MO.MappedObjectName
		WHERE
			D.DimensionTypeID NOT IN (7, 25) AND
			D.SelectYN <> 0 AND
			ISNULL(PropertyDataTypeID01, 0) <> 3 AND ISNULL(PropertyDataTypeID02, 0) <> 3 AND ISNULL(PropertyDataTypeID03, 0) <> 3 AND ISNULL(PropertyDataTypeID04, 0) <> 3 AND
			ISNULL(PropertyDataTypeID05, 0) <> 3 AND ISNULL(PropertyDataTypeID06, 0) <> 3 AND ISNULL(PropertyDataTypeID07, 0) <> 3 AND ISNULL(PropertyDataTypeID08, 0) <> 3 AND
			ISNULL(PropertyDataTypeID09, 0) <> 3 AND ISNULL(PropertyDataTypeID10, 0) <> 3 AND ISNULL(PropertyDataTypeID11, 0) <> 3 AND ISNULL(PropertyDataTypeID12, 0) <> 3 AND
			ISNULL(PropertyDataTypeID13, 0) <> 3 AND ISNULL(PropertyDataTypeID14, 0) <> 3 AND ISNULL(PropertyDataTypeID15, 0) <> 3 AND ISNULL(PropertyDataTypeID16, 0) <> 3 AND
			ISNULL(PropertyDataTypeID17, 0) <> 3 AND ISNULL(PropertyDataTypeID18, 0) <> 3 AND ISNULL(PropertyDataTypeID19, 0) <> 3 AND ISNULL(PropertyDataTypeID20, 0) <> 3 AND
			NOT EXISTS (SELECT 1 FROM #Dimension_Cursor DC WHERE DC.DimensionName = MO.MappedObjectName)''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)'

	SET @SQLStatement = @SQLStatement + '

		--With member properties and used as member property
		SET @SQLStatement = ''''
		INSERT INTO #Dimension_Cursor
			(
			DimensionID,
			SourceDimensionName,
			DimensionName,
			SortOrder
			)
		SELECT DISTINCT
			D.DimensionID,
			SourceDimensionName = D.DimensionName,
			MO.MappedObjectName,
			SortOrder = 2
		FROM
			'''' + @SourceDatabase + ''''.[dbo].[Dimension] D
			INNER JOIN '''' + @SourceDatabase + ''''.[dbo].[Dimension] MD ON
						MD.PropertyMemberDimension01 = D.DimensionName OR MD.PropertyMemberDimension02 = D.DimensionName OR MD.PropertyMemberDimension03 = D.DimensionName OR MD.PropertyMemberDimension04 = D.DimensionName OR
						MD.PropertyMemberDimension05 = D.DimensionName OR MD.PropertyMemberDimension06 = D.DimensionName OR MD.PropertyMemberDimension07 = D.DimensionName OR MD.PropertyMemberDimension08 = D.DimensionName OR
						MD.PropertyMemberDimension09 = D.DimensionName OR MD.PropertyMemberDimension10 = D.DimensionName OR MD.PropertyMemberDimension11 = D.DimensionName OR MD.PropertyMemberDimension12 = D.DimensionName OR
						MD.PropertyMemberDimension13 = D.DimensionName OR MD.PropertyMemberDimension14 = D.DimensionName OR MD.PropertyMemberDimension15 = D.DimensionName OR MD.PropertyMemberDimension16 = D.DimensionName OR
						MD.PropertyMemberDimension17 = D.DimensionName OR MD.PropertyMemberDimension18 = D.DimensionName OR MD.PropertyMemberDimension19 = D.DimensionName OR MD.PropertyMemberDimension20 = D.DimensionName
			INNER JOIN '''' + @ETLDatabase + ''''..MappedObject MO ON MO.MappedObjectName = D.DimensionName AND MO.DimensionTypeID = D.DimensionTypeID AND MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0
			INNER JOIN '''' + @DestinationDatabase + ''''.sys.tables t ON t.[name] = ''''''''S_DS_'''''''' + MO.MappedObjectName
		WHERE
			D.DimensionTypeID NOT IN (7, 25) AND
			D.SelectYN <> 0 AND
			(
			ISNULL(D.PropertyDataTypeID01, 0) = 3 OR ISNULL(D.PropertyDataTypeID02, 0) = 3 OR ISNULL(D.PropertyDataTypeID03, 0) = 3 OR ISNULL(D.PropertyDataTypeID04, 0) = 3 OR
			ISNULL(D.PropertyDataTypeID05, 0) = 3 OR ISNULL(D.PropertyDataTypeID06, 0) = 3 OR ISNULL(D.PropertyDataTypeID07, 0) = 3 OR ISNULL(D.PropertyDataTypeID08, 0) = 3 OR
			ISNULL(D.PropertyDataTypeID09, 0) = 3 OR ISNULL(D.PropertyDataTypeID10, 0) = 3 OR ISNULL(D.PropertyDataTypeID11, 0) = 3 OR ISNULL(D.PropertyDataTypeID12, 0) = 3 OR
			ISNULL(D.PropertyDataTypeID13, 0) = 3 OR ISNULL(D.PropertyDataTypeID14, 0) = 3 OR ISNULL(D.PropertyDataTypeID15, 0) = 3 OR ISNULL(D.PropertyDataTypeID16, 0) = 3 OR
			ISNULL(D.PropertyDataTypeID17, 0) = 3 OR ISNULL(D.PropertyDataTypeID18, 0) = 3 OR ISNULL(D.PropertyDataTypeID19, 0) = 3 OR ISNULL(D.PropertyDataTypeID20, 0) = 3) AND
			NOT EXISTS (SELECT 1 FROM #Dimension_Cursor DC WHERE DC.DimensionName = D.DimensionName)''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		--Not included before (with member properties)
		SET @SQLStatement = ''''
		INSERT INTO #Dimension_Cursor
			(
			DimensionID,
			SourceDimensionName,
			DimensionName,
			SortOrder
			)
		SELECT DISTINCT
			D.DimensionID,
			SourceDimensionName = D.DimensionName,
			MO.MappedObjectName,
			SortOrder = 3
		FROM
			'''' + @SourceDatabase + ''''.[dbo].[Dimension] D
			INNER JOIN '''' + @ETLDatabase + ''''..MappedObject MO ON MO.MappedObjectName = D.DimensionName AND MO.DimensionTypeID = D.DimensionTypeID AND MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0
			INNER JOIN '''' + @DestinationDatabase + ''''.[sys].[tables] t ON t.[name] = ''''''''S_DS_'''''''' + MO.MappedObjectName
		WHERE
			D.DimensionTypeID NOT IN (7, 25) AND
			D.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM #Dimension_Cursor DC WHERE DC.DimensionName = MO.MappedObjectName)''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)'

	SET @SQLStatement = @SQLStatement + '

		IF @Debug <> 0 SELECT TempTable = ''''#Dimension_Cursor'''', * FROM #Dimension_Cursor ORDER BY SortOrder, DimensionName

	SET @Step = ''''Cursor on Dimensions''''
		DECLARE pcEXCHANGE_Dimension_Cursor CURSOR FOR

		SELECT DimensionID, SourceDimensionName, DimensionName FROM #Dimension_Cursor ORDER BY SortOrder, DimensionName

		OPEN pcEXCHANGE_Dimension_Cursor

		FETCH NEXT FROM pcEXCHANGE_Dimension_Cursor INTO @DimensionID, @SourceDimension, @Dimension

		WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @Step = ''''Set @StartTime_Step''''
					SET @StartTime_Step = GETDATE()

				IF @Debug <> 0 SELECT DimensionID = @DimensionID, SourceDimension = @SourceDimension, Dimension = @Dimension

				TRUNCATE TABLE #6000_Property

				SELECT @Counter = 0, @PropertyName = '''''''', @SQLInsert = '''''''', @SQLSelect = '''''''', @SQLJoin = ''''''''

				WHILE @Counter <= 20 AND @PropertyName IS NOT NULL
				  BEGIN
					SET @Counter = @Counter + 1'

	SET @SQLStatement = @SQLStatement + '
					     IF @Counter =  1 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName01, PropertyDataTypeID01, PropertyMemberDimension01 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter =  2 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName02, PropertyDataTypeID02, PropertyMemberDimension02 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter =  3 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName03, PropertyDataTypeID03, PropertyMemberDimension03 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter =  4 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName04, PropertyDataTypeID04, PropertyMemberDimension04 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter =  5 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName05, PropertyDataTypeID05, PropertyMemberDimension05 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter =  6 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName06, PropertyDataTypeID06, PropertyMemberDimension06 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter =  7 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName07, PropertyDataTypeID07, PropertyMemberDimension07 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter =  8 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName08, PropertyDataTypeID08, PropertyMemberDimension08 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter =  9 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName09, PropertyDataTypeID09, PropertyMemberDimension09 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 10 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName10, PropertyDataTypeID10, PropertyMemberDimension10 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + '''''''''''''''''

	SET @SQLStatement = @SQLStatement + '
					ELSE IF @Counter = 11 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName11, PropertyDataTypeID11, PropertyMemberDimension11 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 12 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName12, PropertyDataTypeID12, PropertyMemberDimension12 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 13 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName13, PropertyDataTypeID13, PropertyMemberDimension13 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 14 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName14, PropertyDataTypeID14, PropertyMemberDimension14 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 15 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName15, PropertyDataTypeID15, PropertyMemberDimension15 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 16 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName16, PropertyDataTypeID16, PropertyMemberDimension16 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 17 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName17, PropertyDataTypeID17, PropertyMemberDimension17 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 18 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName18, PropertyDataTypeID18, PropertyMemberDimension18 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 19 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName19, PropertyDataTypeID19, PropertyMemberDimension19 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''
					ELSE IF @Counter = 20 SET @SQLStatement = ''''INSERT INTO #6000_Property ([Counter], PropertyName, PropertyDataTypeID, PropertyMemberDimension) SELECT '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName20, PropertyDataTypeID20, PropertyMemberDimension20 FROM '''' + @SourceDatabase + ''''.[dbo].Dimension WHERE DimensionName = '''''''''''' + @SourceDimension + '''''''''''''''''

	SET @SQLStatement = @SQLStatement + '

					EXEC (@SQLStatement)
					SELECT @PropertyName = PropertyName, @PropertyDataTypeID = PropertyDataTypeID, @PropertyMemberDimension = PropertyMemberDimension FROM #6000_Property
					
					IF @Debug <> 0
						BEGIN
							PRINT ''''Counter: '''' + CONVERT(nvarchar(10), @Counter) + '''', PropertyName: '''' + @PropertyName + '''', PropertyDataTypeID: '''' + CONVERT(nvarchar(10), @PropertyDataTypeID) + '''', PropertyMemberDimension: '''' + @PropertyMemberDimension
							SELECT [Counter] = @Counter, PropertyName = @PropertyName, PropertyDataTypeID = @PropertyDataTypeID, PropertyMemberDimension = @PropertyMemberDimension
						END

				SET @Step = ''''Check Property existence''''
					TRUNCATE TABLE #6000_PropertyCount
					SET @SQLStatement = ''''
						INSERT INTO #6000_PropertyCount (PropertyCount)
						SELECT
							PropertyCount = COUNT(1) 
						FROM 
							'''' + @DestinationDatabase + ''''.[sys].[tables] t
							INNER JOIN '''' + @DestinationDatabase + ''''.[sys].[columns] c ON c.object_id = t.object_id AND c.name = '''''''''''' + @PropertyName + ''''''''''''
						WHERE
							t.[name] = ''''''''S_DS_'''' + @Dimension + ''''''''''''''''
					EXEC (@SQLStatement)
					IF (SELECT PropertyCount FROM #6000_PropertyCount) = 0 SET @PropertyName = ''''''''

					IF ISNULL(@PropertyName, '''''''') <> '''''''' AND NOT (@PropertyDataTypeID = 3 AND @PropertyMemberDimension IS NULL)
						BEGIN	
							SET @SQLInsert = @SQLInsert + ''''			
					['''' + @PropertyName + ''''],'''' +
					CASE WHEN @PropertyDataTypeID = 3 AND @PropertyMemberDimension IS NOT NULL THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ''''['''' + @PropertyName + ''''_MemberId],'''' ELSE '''''''' END

							SET @SQLSelect = @SQLSelect + ''''			
					['''' + @PropertyName + ''''] = DD.Property'''' + CASE WHEN @Counter <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), @Counter) + '''','''' + 
					CASE WHEN @PropertyDataTypeID = 3 AND @PropertyMemberDimension IS NOT NULL THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ''''['''' + @PropertyName + ''''_MemberId] = ISNULL(['''' + @PropertyName + ''''].[MemberId], -1),'''' ELSE '''''''' END

							SET @SQLJoin = @SQLJoin + CASE WHEN @PropertyDataTypeID = 3 AND @PropertyMemberDimension IS NOT NULL THEN ''''			
					LEFT JOIN '''' + @DestinationDatabase + ''''.[dbo].[S_DS_'''' + @PropertyMemberDimension + ''''] ['''' + @PropertyName + ''''] ON ['''' + @PropertyName + ''''].Label COLLATE DATABASE_DEFAULT = [DD].[Property'''' + CASE WHEN @Counter <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), @Counter) + '''']'''' ELSE '''''''' END
						
						END
				  END
				IF @Debug <> 0 SELECT TempTable = ''''#6000_Property'''', DimensionID = @DimensionID, Dimension = @Dimension, * FROM #6000_Property	

				SET @Step = ''''Set default values for not defined properties''''

					SELECT @SBZ = ''''[dbo].[f_GetSBZ] ('''' + CONVERT(nvarchar(10), @DimensionID) + '''', [DD].[Property'''' + CASE WHEN [Counter] <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), [Counter]) + ''''], [DD].[Label])''''   FROM #6000_Property WHERE PropertyName = ''''RNodeType''''
					IF @Debug <> 0 SELECT SBZ = @SBZ'

	SET @SQLStatement = @SQLStatement + '

					TRUNCATE TABLE #DependentDim

					SET @SQLStatement = ''''
						INSERT INTO #DependentDim
							(
							PropertyName,
							DefaultValueView,
							DimensionName
							)
						SELECT 
							PropertyName = P.PropertyName + ''''''''_MemberId'''''''',
							DefaultValueView = P.DefaultValueView,
							DimensionName = MO.MappedObjectName
						FROM 
							pcINTEGRATOR..Property P
							INNER JOIN '''' + @DestinationDatabase + ''''.[sys].[tables] t ON t.[name] = ''''''''S_DS_'''' + @Dimension + ''''''''''''
							INNER JOIN '''' + @DestinationDatabase + ''''.[sys].[columns] c ON c.object_id = t.object_id AND c.name = P.PropertyName + ''''''''_MemberId''''''''
							INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionID = P.DependentDimensionID AND D.SelectYN <> 0
							INNER JOIN '''' + @ETLDatabase + ''''..MappedObject MO ON MO.ObjectName = D.DimensionName AND MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0
						WHERE
							P.DataTypeID = 3 AND
							(P.DimensionID = '''' + CONVERT(nvarchar(10), @DimensionID) + '''' OR P.DimensionID = 0) AND
							P.PropertyID NOT BETWEEN 100 AND 1000 AND
							P.PropertyID NOT IN (1, 2, 3, 4, 5, 8) AND
							P.SelectYN <> 0 AND
							NOT EXISTS (SELECT 1 FROM #6000_Property #P WHERE #P.PropertyName = P.PropertyName)''''

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					IF @Debug <> 0 SELECT TempTable = ''''#DependentDim'''', * FROM #DependentDim

					TRUNCATE TABLE #DefaultValue

					SET @SQLStatement = ''''
						INSERT INTO #DefaultValue
							(
							PropertyName,
							DefaultValueView
							)
						SELECT 
							PropertyName = P.PropertyName,
							DefaultValueView = CASE P.PropertyID WHEN 7 THEN '''''''''''' + ISNULL(@SBZ, 0) + '''''''''''' WHEN 9 THEN ''''''''M.HelpText'''''''' ELSE P.DefaultValueView END
						FROM 
							pcINTEGRATOR..Property P
							INNER JOIN '''' + @DestinationDatabase + ''''.[sys].[tables] t ON t.[name] = ''''''''S_DS_'''' + @Dimension + ''''''''''''
							INNER JOIN '''' + @DestinationDatabase + ''''.[sys].[columns] c ON c.object_id = t.object_id AND c.name = P.PropertyName
						WHERE
							(P.DimensionID = '''' + CONVERT(nvarchar(10), @DimensionID) + '''' OR P.DimensionID = 0) AND
							P.PropertyID NOT BETWEEN 100 AND 1000 AND
							P.PropertyID NOT IN (1, 2, 3, 4, 5, 8) AND
							P.SelectYN <> 0 AND
							NOT EXISTS (SELECT 1 FROM #6000_Property #P WHERE #P.PropertyName = P.PropertyName)''''

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)'

	SET @SQLStatement = @SQLStatement + '
			
					DECLARE Dependent_DefaultValue_Cursor CURSOR FOR

						SELECT 
							PropertyName,
							DefaultValueView,
							DimensionName
						FROM
							#DependentDim

						OPEN Dependent_DefaultValue_Cursor
						FETCH NEXT FROM Dependent_DefaultValue_Cursor INTO @PropertyName, @DefaultValueView, @DimensionName

						WHILE @@FETCH_STATUS = 0
							BEGIN

								SET @SQLStatement = ''''
									INSERT INTO #DefaultValue
										(
										PropertyName,
										DefaultValueView
										)
									SELECT 
										PropertyName = '''''''''''' + @PropertyName + '''''''''''',
										DefaultValueView = MemberId
									FROM 
										'''' + @DestinationDatabase + ''''.[dbo].[S_DS_'''' + @DimensionName + '''']
									WHERE
										Label = '''' + @DefaultValueView

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								FETCH NEXT FROM Dependent_DefaultValue_Cursor INTO @PropertyName, @DefaultValueView, @DimensionName
							END

					CLOSE Dependent_DefaultValue_Cursor
					DEALLOCATE Dependent_DefaultValue_Cursor	

				IF @Debug <> 0 SELECT TempTable = ''''#DefaultValue'''', * FROM #DefaultValue'

	SET @SQLStatement = @SQLStatement + '

			SET @Step = ''''Fill #Dimension_Members''''
				TRUNCATE TABLE #Dimension_Members

				SELECT @RNodeTypeFieldName = ''''Property'''' + CASE WHEN [Counter] <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), [Counter])
				FROM
					#6000_Property
				WHERE
					PropertyName = ''''RNodeType''''

				SET @RNodeTypeFieldName = ISNULL(@RNodeTypeFieldName, ''''''''''''L'''''''''''')

				SET @SQLStatement = ''''
					INSERT INTO #Dimension_Members
						(
						[MemberId],
						[Label],
						[RNodeType],
						[Parent]
						)
					SELECT
						[MemberId] = ISNULL(M.MemberID, DD.[MemberId]),
						[Label] = DD.Label,
						[RNodeType] = DD.'''' + @RNodeTypeFieldName + '''',
						[Parent] = DD.Parent1
					FROM
						'''' + @SourceDatabase + ''''.[dbo].[DimensionData] DD
						LEFT JOIN pcINTEGRATOR.dbo.[Member] M ON M.[DimensionID] = '''' + CONVERT(nvarchar(10), @DimensionID) + '''' AND M.[Label] = DD.[Label]'''' + @SQLJoin + ''''
					WHERE
						DD.DimensionName = '''''''''''' + @SourceDimension + ''''''''''''''''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				IF @Debug <> 0 SELECT TempTable = ''''#Dimension_Members'''', * FROM #Dimension_Members'

	SET @SQLStatement = @SQLStatement + '

			SET @Step = ''''Create Insert query''''
				IF (SELECT COUNT(1) FROM #DefaultValue) > 0
					SELECT 
						@SQLInsert = @SQLInsert + ''''			
						['''' + PropertyName + ''''],'''',
						@SQLSelect = @SQLSelect + ''''			
						['''' + PropertyName + ''''] = '''' + DefaultValueView + '''',''''
					FROM
						#DefaultValue

				SET @SQLStatement = ''''
					INSERT INTO '''' + @DestinationDatabase + ''''.[dbo].[S_DS_'''' + @Dimension + '''']
						(
						[MemberId],
						[Label],
						[Description],'''' + @SQLInsert + ''''
						[Source],
						[Synchronized]
						)
					SELECT
						[MemberId] = ISNULL(M.MemberID, DD.[MemberId]),
						[Label] = DD.Label,
						[Description] = DD.Description,'''' + @SQLSelect + ''''
						[Source] = '''''''''''' + @ApplicationName + '''''''''''' + CASE WHEN DD.Source <> '''''''''''''''' THEN ''''''''_'''''''' + DD.Source ELSE '''''''''''''''' END,
						[Synchronized] = 1
					FROM
						'''' + @SourceDatabase + ''''.[dbo].[DimensionData] DD
						LEFT JOIN pcINTEGRATOR.dbo.[Member] M ON M.[DimensionID] = '''' + CONVERT(nvarchar(10), @DimensionID) + '''' AND M.[Label] = DD.[Label]'''' + @SQLJoin + ''''
					WHERE
						DD.DimensionName = '''''''''''' + @SourceDimension + '''''''''''' AND
						NOT EXISTS (SELECT 1 FROM '''' + @DestinationDatabase + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] DDD WHERE DDD.[Label] = DD.[Label])''''

				IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

				SET @Inserted_Step = @@ROWCOUNT

				SET @Step = ''''Update MemberId''''
					EXEC spSet_MemberId @Database = @DestinationDatabase, @Dimension = @Dimension, @Debug = @Debug'

	SET @SQLStatement = @SQLStatement + '

				SET @Step = ''''Create hierarchies.''''

				TRUNCATE TABLE #Hierarchy

				SELECT @Counter = 5, @HierarchyName = ''''''''

				WHILE @Counter <= 5 AND @HierarchyName IS NOT NULL
				  BEGIN
					SET @Counter = @Counter + 1
					SET @SQLStatement = ''''INSERT INTO #Hierarchy (HierarchyName) SELECT HierarchyName = '''''''''''' + @Dimension + ''''_'''' + @Dimension + ''''''''''''''''

					EXEC (@SQLStatement)
					SELECT @HierarchyName = HierarchyName FROM #Hierarchy

					IF @Debug <> 0
						BEGIN
							PRINT ''''Counter: '''' + CONVERT(nvarchar(10), @Counter) + '''', HierarchyName: '''' + @HierarchyName
							SELECT [Counter] = @Counter, HierarchyName = @HierarchyName
						END
					IF @HierarchyName IS NOT NULL 
						BEGIN
							SET @Step = ''''Check which parent members have leaf members as children.''''
								TRUNCATE TABLE #LeafCheck
								EXEC spSet_LeafCheck @Database = @DestinationDatabase, @Dimension = @Dimension, @DimensionTemptable = ''''#Dimension_Members'''', @Debug = @Debug

								IF @Debug <> 0 SELECT TempTable = ''''#LeafCheck'''', * FROM #LeafCheck
															
							SET @SQLStatement = ''''
								INSERT INTO '''' + @DestinationDatabase + ''''.[dbo].[S_HS_'''' + @HierarchyName + '''']
									(
									[MemberId],
									[ParentMemberId],
									[SequenceNumber]
									)
								SELECT
									[MemberId] = D1.MemberId,
									[ParentMemberId] = ISNULL(D2.MemberId, 0),
									[SequenceNumber] = ISNULL(V.SortOrder, D1.MemberId) 
								FROM
									'''' + @DestinationDatabase + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] D1
									INNER JOIN (SELECT Label, Parent = Parent1, SortOrder = SortOrder1 FROM '''' + @SourceDatabase + ''''.[dbo].[DimensionData] WHERE DimensionName = '''''''''''' + @SourceDimension + '''''''''''') V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
									LEFT JOIN '''' + @DestinationDatabase + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] D2 ON D2.Label = CONVERT(nvarchar(255), V.Parent) COLLATE DATABASE_DEFAULT
									LEFT JOIN [#LeafCheck] LC ON LC.MemberId = D1.MemberId AND LC.HasChild <> 0
								WHERE
									NOT EXISTS (SELECT 1 FROM '''' + @DestinationDatabase + ''''.[dbo].[S_HS_'''' + @HierarchyName + ''''] H WHERE H.MemberId = D1.MemberId) AND
									(D1.RNodeType IN (''''''''L'''''''', ''''''''LC'''''''') OR LC.MemberId IS NOT NULL)
								ORDER BY
									V.SortOrder''''

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Step = ''''Copy the hierarchy to all instances''''
								EXEC spSet_HierarchyCopy @Database = @DestinationDatabase, @Dimensionhierarchy = @HierarchyName'

	SET @SQLStatement = @SQLStatement + '
					
						END
				  END

				SET @Step = ''''Step count handling''''
					SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step

				SET @Step = ''''Set @Duration Step''''	
					SET @Duration = GetDate() - @StartTime_Step

				SET @Step = ''''Insert into JobLog''''
					INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime_Step, OBJECT_NAME(@@PROCID) + '''' ('''' + @Dimension + '''')'''', @Duration, @Deleted_Step, @Inserted_Step, @Updated_Step, @Version

				FETCH NEXT FROM pcEXCHANGE_Dimension_Cursor INTO @DimensionID, @SourceDimension, @Dimension
			END

		CLOSE pcEXCHANGE_Dimension_Cursor
		DEALLOCATE pcEXCHANGE_Dimension_Cursor

					FETCH NEXT FROM SourceDatabase_Cursor INTO @SourceDatabase
				END

		CLOSE SourceDatabase_Cursor
		DEALLOCATE SourceDatabase_Cursor

	SET @Step = ''''Drop temp tables''''	
		DROP TABLE #6000_PropertyCount
		DROP TABLE #SourceDatabase_Cursor
		DROP TABLE #Dimension_Cursor
		DROP TABLE #Hierarchy
		DROP TABLE #6000_Property
		DROP TABLE #DependentDim
		DROP TABLE #DefaultValue

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

    SET @Step = 'Create pcEXCHANGE Dimension Procedure'
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation pcEXCHANGE Dimension Procedure', [SQLStatement] = @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Drop Temp table'
		DROP TABLE #Action

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
