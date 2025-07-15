SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_TabularDefinition]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
--	@ModelBM int = NULL,
	@DataClassID INT = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000480,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spGet_TabularDefinition] @UserID=-10, @InstanceID=-1318, @VersionID=-1256, @DataClassID=6320, @Debug=1
EXEC [spGet_TabularDefinition] @UserID=-10, @InstanceID=413, @VersionID=1008, @DataClassID=1028, @DebugBM=1

IF OBJECT_ID(N'tempdb..#Def', N'U') IS NOT NULL
	DROP TABLE #Def	
CREATE TABLE #Def
(	
	[ObjectID]		int NOT NULL, 
	[ObjectType]		nvarchar(50) NOT NULL,
	[ObjectName]		nvarchar(50) NOT NULL,	
	[ParentObjectID]	int NOT NULL,
	[Data]			nvarchar(MAX),
	[SortOrder]		int,
	PRIMARY KEY (ObjectID, ObjectType)
)
INSERT INTO #Def EXEC [spGet_TabularDefinition] @UserID=-10, @InstanceID=-1318, @VersionID=-1256, @DataClassID=6320
SELECT * FROM #Def WHERE ObjectType = 'Hierarchy'
ORDER BY SortOrder
DROP TABLE #Def

EXEC [spGet_TabularDefinition] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
--	@DataClassID int,
	@ApplicationName nvarchar(255),
	--@CallistoDatabase nvarchar(255),
	@ETLDatabase nvarchar(255),
	@DataClassName nvarchar(255),
	@ObjectID int,
	@FilterString nvarchar(4000),
	@DimensionID int, 
	@DimensionName nvarchar(50), 
	@HierarchyNo int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'BeJa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return metadata for building a Tabular model',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Set default values on all parameters.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set ProcedureID in JobLog.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@DataClassID = dc.DataClassID,
			@ApplicationName = ApplicationName,
			@ETLDatabase = ETLDatabase,
			@DataClassName = DataClassName
		FROM
			[Application] a
			INNER JOIN DataClass dc ON dc.InstanceID = a.InstanceID AND dc.VersionID = a.VersionID AND dc.DataClassID = @DataClassID AND dc.TabularYN <> 0
		WHERE
			a.InstanceID = @InstanceID AND 
			a.VersionID = @VersionID

		IF @DebugBM & 2 > 0 SELECT [@DataClassID] = @DataClassID, [@ApplicationName] = @ApplicationName, [@ETLDatabase] = @ETLDatabase, [@DataClassName] = @DataClassName

	SET @Step = 'Check that instance exists'
		IF @ApplicationName IS NULL
			BEGIN
				SET @Message = 'Could not find valid Application with InstanceID=' + CAST(@InstanceID as nvarchar) + ' and VersionID=' + CAST(@VersionID as nvarchar)
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp table #Definition, #ValidDimensionColumn and #HierachyDepth'
		CREATE TABLE #Definition
			(	
			[ObjectID]		int NOT NULL, 
			[ObjectType]		nvarchar(50) COLLATE DATABASE_DEFAULT NOT NULL,
			[ObjectName]		nvarchar(50) COLLATE DATABASE_DEFAULT NOT NULL,	
			[ParentObjectID]	int NOT NULL,
			[Data]			nvarchar(MAX) COLLATE DATABASE_DEFAULT,
			[SortOrder]		int,
			PRIMARY KEY (ObjectID, ObjectType)
			)
		CREATE UNIQUE NONCLUSTERED INDEX Unique_ObjectName ON #Definition (ObjectName, ObjectType, ParentObjectID) --Make sure that ObjectNames are unique
		CREATE TABLE #ValidDimensionColumn
			(
				DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT NOT NULL,
				ColumnName nvarchar(100) COLLATE DATABASE_DEFAULT NOT NULL,
				PRIMARY KEY (DimensionName, ColumnName)
			)
		CREATE TABLE #HierachyDepth
			(
				DimensionID int,
				HierarchyNo int,
				Depth int NOT NULL,
				PRIMARY KEY (DimensionID, HierarchyNo, Depth)
			)

	SET @Step = 'Create temp tables for dynamic security roles'
		CREATE TABLE #User
			(
			[InstanceID] [INT],
			[UserID] [INT],
			[UserName] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[UserNameAD] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[AzureUPN] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[UserNameDisplay] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[UserTypeID] [INT],
			[UserLicenseTypeID] [INT],
			[LocaleID] [INT],
			[LanguageID] [INT],
			[ObjectGuiBehaviorBM] [INT],
			[InheritedFrom] [INT] NULL,
			[SelectYN] [BIT] NOT NULL,
			[Version] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[DeletedID] [INT]
			)

		CREATE TABLE #RoleMemberRow
			(
			RoleID int,
			DataClassID int,
			DimensionID int,
			MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #RoleOrganizationPosition
			(
			RoleID int,
			OrganizationPositionID int
			)

	SET @Step = 'Exec [spGet_SecurityRoles_Dynamic]'
		EXEC [spGet_SecurityRoles_Dynamic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @Debug=@DebugSub

	SET @Step = 'Data source' --SQLServer|SQLDb|ASServer|ASDb
		INSERT INTO #Definition
		SELECT
			ObjectID = 1, 
			ObjectType = N'DataSource', 
			ObjectName = a.ETLDatabase, 
			ParentObjectID = 0,
			[Data] = @@SERVERNAME + CASE WHEN DEFAULT_DOMAIN() = 'LIVE' THEN N'.live.dspcloud.local' WHEN DEFAULT_DOMAIN() IN('DEV','DEMO') THEN N'.' + LOWER(DEFAULT_DOMAIN()) + N'.live.dspcloud.local' ELSE N'' END  + N'|' + a.ETLDatabase + N'|' + a.TabularServer + N'|' + @ApplicationName + N'_' + @DataClassName, 
			SortOrder = -1
		FROM
			[Application] a 
		WHERE
			a.InstanceID = @InstanceID AND
			a.VersionID = @VersionID

	SET @Step = 'Fact table' --Table|0=Fact table
		INSERT INTO #Definition
		SELECT
			ObjectID = ROW_NUMBER() OVER (ORDER BY dcv.DataClassViewBM),
			ObjectType = N'Table',
			ObjectName = dc.DataClassName + ISNULL(N'_' + dcv.DataClassViewName, N''),
			ParentObjectID = 0,
			[Data] = N'vw_Tab_pcDC_' + dc.DataClassName + ISNULL(N'_' + dcv.DataClassViewName, N'') + N'|0',
			SortOrder = 1000 * ROW_NUMBER() OVER (ORDER BY dcv.DataClassViewBM)
		FROM
			DataClass dc
			LEFT JOIN DataClassView dcv ON dcv.DataClassID = dc.DataClassID	AND dcv.SelectYN = 1
		WHERE dc.DataClassID = @DataClassID AND dc.SelectYN = 1

	SET @Step = 'Get columns for fact table' --	Column|Query|DataType|NULL/NOTNULL|Key|Hidden
		SELECT @SQLStatement = '
			INSERT INTO #Definition
			SELECT
				ObjectID = d.ObjectID * 1000 + column_id,
				ObjectType = N''Column'',
				ObjectName = Replace(c.[name], N'' '', N''_''),
				ParentObjectID = d.ObjectID, 
				[Data] = c.[name] + N''||'' + ty.[name] + N''|'' + CASE WHEN c.is_nullable = 1 THEN N''NULL'' ELSE N''NOTNULL'' END + N''||'' + 
					CAST(CASE WHEN RIGHT(c.[name], LEN(N''_MemberId'')) = N''_MemberId'' OR c.[name] = N''TimeDate'' OR RIGHT(c.[name], 6) = N''_Value'' THEN 1 ELSE 0 END as nvarchar),
				SortOrder = d.SortOrder + column_id
			FROM
				' + @ETLDatabase + '.sys.views v
				INNER JOIN ' + @ETLDatabase + '.sys.columns c ON c.object_id = v.object_id
				INNER JOIN ' + @ETLDatabase + '.sys.types ty ON ty.user_type_id = c.user_type_id
				INNER JOIN #Definition d ON SUBSTRING(d.Data, 1, CHARINDEX(N''|'', d.Data) - 1) = v.[name] AND d.ObjectType = N''Table'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Get measures for fact table' --Expression|Format|Folder
		INSERT INTO #Definition
		SELECT
			ObjectID = d.ObjectID * 1000 + ROW_NUMBER() OVER (ORDER BY m.SortOrder), ObjectType = N'Measure',
			ObjectName = CASE WHEN dcv.DataClassViewName IS NULL THEN MeasureName ELSE REPLACE(MeasureName, N'_DataClassView_', dcv.DataClassViewName) END,
			ParentObjectID = d.ObjectID,
			[Data] = ISNULL(CASE WHEN dcv.DataClassViewName IS NULL THEN m.TabularFormula ELSE REPLACE(m.TabularFormula, N'_DataClassView_', dcv.DataClassViewName) END, 
						agg.AggregationTypeName + N'([' + REPLACE(MeasureName, N'_DataClassView_', '') + N'_Value])') + N'|' + ISNULL(FormatString, '') + N'|' + ISNULL(m.TabularFolder, ''),
			SortOrder = d.SortOrder + 50 + m.SortOrder
		FROM 
			Measure m
			INNER JOIN AggregationType agg ON agg.AggregationTypeID = m.AggregationTypeID AND agg.AggregationTypeID <> -5 --Exclude LEVEL
			LEFT JOIN DataClassView dcv ON dcv.DataClassID = m.DataClassID AND dcv.SelectYN = 1 AND (dcv.DataClassViewBM & m.DataClassViewBM) > 0
			INNER JOIN #Definition d ON d.ObjectName = @DataClassName + ISNULL(N'_' + dcv.DataClassViewName, N'') AND d.ObjectType = N'Table'
		WHERE 
			m.InstanceID IN(0, @InstanceID) AND m.DataClassID = @DataClassID AND 
			m.TabularYN <> 0 

	SET @Step = 'Create temp table object @Dimension' --Create to avoild have same join and logic in more than one place
		DECLARE @Dimension TABLE 
			(
			DimensionID		int PRIMARY KEY, 
			DimensionName	nvarchar(100) NOT NULL,
			DimensionTypeGroupID int NOT NULL
			)

		INSERT INTO @Dimension
		SELECT
			d.DimensionID,
			d.DimensionName,
			dt.DimensionTypeGroupID
		FROM
			DataClass dc
			INNER JOIN DataClass_Dimension dcd ON dcd.DataClassID = dc.DataClassID
			INNER JOIN Dimension d ON d.DimensionID = dcd.DimensionID
			INNER JOIN DimensionType dt ON dt.DimensionTypeID = d.DimensionTypeID
		WHERE
			dc.DataClassID = @DataClassID AND
			d.ReportOnlyYN = 0 AND
			dcd.TabularYN <> 0 AND
			d.InstanceID IN (dc.InstanceID, 0)

	SET @Step = 'Fill temp table with dimensions from table variable @Dimension' --Table|DimensionTypeGroupID
		INSERT INTO #Definition
		SELECT
			ObjectID = 10 * ROW_NUMBER() OVER (ORDER BY DimensionName), ObjectType = N'Table', 
			ObjectName = DimensionName, 
			ParentObjectID = 0, 
			[Data] = N'vw_Tab_pcD_' + DimensionName + N'|' + CAST(DimensionTypeGroupID as nvarchar), 
			SortOrder = ROW_NUMBER() OVER (ORDER BY DimensionName) * 100000
		FROM @Dimension

	SET @Step = 'Fill temptable #ValidDimensionColumn with existing columns in views'
		SET @SQLStatement = '
			INSERT INTO #ValidDimensionColumn
			SELECT
				DimensionName = REPLACE(v.name, ''vw_Tab_pcD_'', ''''),
				ColumnName = c.[name]
			FROM
				' + @ETLDatabase + '.sys.views v
				INNER JOIN ' + @ETLDatabase + '.sys.columns c ON c.object_id = v.object_id
			WHERE
				v.[name] LIKE N''vw_Tab_pcD_%'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Get columns for dim table' --Column|Query|DataType|NULL/NOTNULL|Key|Hidden
		INSERT INTO #Definition
		SELECT
			ObjectID = 1000 * def.ObjectID + ROW_NUMBER() OVER (PARTITION BY d.DimensionID ORDER BY p.SortOrder, p.PropertyName), 
			ObjectType = N'Column', 
			ObjectName = CASE WHEN p.PropertyName = 'Label' THEN d.DimensionName WHEN p.PropertyName = N'MemberId' AND d.DimensionTypeGroupID = 2 THEN N'TimeDate' ELSE Replace(p.PropertyName, N' ', N'_') END, 
			ParentObjectID = def.ObjectID,
			[Data] = CASE WHEN p.PropertyName = 'Label' THEN d.DimensionName WHEN p.PropertyName = N'MemberId' AND d.DimensionTypeGroupID = 2 THEN N'TimeDate' ELSE p.PropertyName END + N'||' + 
				CASE WHEN p.PropertyName = N'MemberId' AND d.DimensionTypeGroupID = 2 THEN 'date' ELSE dat.DataTypeCode END + N'|' +
				CASE WHEN p.MandatoryYN = 0 THEN N'NULL' ELSE N'NOTNULL' END + N'|' +
				CASE WHEN p.PropertyName = N'MemberId' THEN N'Key|1' ELSE N'|' + CAST(p.Hidden as nvarchar) END,
			SortOrder = def.SortOrder + ROW_NUMBER() OVER (PARTITION BY d.DimensionID ORDER BY p.SortOrder, p.PropertyName)
		FROM
			@Dimension d			
			INNER JOIN 
			(	
				SELECT dp.DimensionID, p.PropertyName, p.DataTypeID, p.MandatoryYN, p.SortOrder, Hidden = 0
				FROM Dimension_Property dp
				INNER JOIN Property p ON p.PropertyID = dp.PropertyID AND p.SelectYN = 1
				WHERE
					dp.TabularYN <> 0 AND dp.SelectYN <> 0
				UNION ALL
				SELECT r.DimensionID, PropertyName = c.[Column] + CAST(r.HierarchyNo as nvarchar), DataTypeID, MandatoryYN, SortOrder = r.HierarchyNo + 1 * 10 + SortOrder, Hidden = 1
				FROM 
					(
						--SELECT [Column] = 'ParentMemberId', DataTypeID = 8, MandatoryYN = 0, SortOrder = 1 UNION ALL
						SELECT [Column] = 'HierarchyPath', DataTypeID = 2, MandatoryYN = 1, SortOrder = 2 UNION ALL
						SELECT [Column] = 'HierarchyDepth', DataTypeID = 1, MandatoryYN = 1, SortOrder = 3 UNION ALL
						SELECT [Column] = 'SortOrder', DataTypeID = 8, MandatoryYN = 1, SortOrder = 4
					) c, (SELECT dh.DimensionID, dh.HierarchyNo FROM DimensionHierarchy dh WHERE dh.FixedLevelsYN <> 1 AND dh.InstanceID IN (@InstanceID, 0)) r
			) p ON p.DimensionID IN(0, d.DimensionID)				
			INNER JOIN DataType dat ON dat.DataTypeID = p.DataTypeID
			INNER JOIN #Definition def ON def.ObjectName = d.DimensionName AND def.ObjectType = 'Table'
			INNER JOIN #ValidDimensionColumn vdc ON vdc.DimensionName = d.DimensionName AND vdc.ColumnName = CASE WHEN p.PropertyName = 'Label' THEN d.DimensionName WHEN p.PropertyName = N'MemberId' AND d.DimensionTypeGroupID = 2 THEN N'TimeDate' ELSE p.PropertyName END

	SET @Step = 'Get hierarchies for dim table' --Type[1=Regular,2=ParentChild]|HierarchyNo
		INSERT INTO #Definition
		SELECT
			ObjectID = 1000 * def.ObjectID + ROW_NUMBER() OVER (PARTITION BY d.DimensionID ORDER BY dh.HierarchyNo), ObjectType = N'Hierarchy', 
			ObjectName = dh.HierarchyName, --Not allowed to be same as a Column in same Table
			ParentObjectID = def.ObjectID, 
			[Data] = CAST(CASE WHEN dh.FixedLevelsYN = 1 THEN 1 ELSE 2 END as nvarchar) + N'|' + CAST(dh.HierarchyNo as nvarchar), 
			SortOrder = def.SortOrder + ROW_NUMBER() OVER (PARTITION BY d.DimensionID ORDER BY dh.HierarchyNo) * 100
		FROM
			@Dimension d
			INNER JOIN DimensionHierarchy dh ON dh.DimensionID = d.DimensionID AND dh.InstanceID IN (@InstanceID, 0)
			INNER JOIN #Definition def ON def.ObjectName = d.DimensionName AND def.ObjectType = 'Table'

	SET @Step = 'Fill temptable #HierachyDepth with max depth per Hierachy'
		IF CURSOR_STATUS('global','DimensionHierachy_Cursor') >= -1 DEALLOCATE DimensionHierachy_Cursor
		DECLARE DimensionHierachy_Cursor CURSOR FOR
			SELECT 
				d.DimensionID,
				d.DimensionName,
				dh.HierarchyNo
			FROM
				@Dimension d
				INNER JOIN DimensionHierarchy dh ON dh.DimensionID = d.DimensionID AND dh.InstanceID IN (@InstanceID, 0)
				INNER JOIN #Definition def ON def.ObjectName = d.DimensionName AND def.ObjectType = 'Table'
			WHERE FixedLevelsYN = 0
			
		OPEN DimensionHierachy_Cursor
		FETCH NEXT FROM DimensionHierachy_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo
		
		WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #HierachyDepth
					SELECT
						DimensionID = ' + CAST(@DimensionID as nvarchar) + ',
						HierarchyNo = ' + CAST(@HierarchyNo as nvarchar) + ',
						Depth = HierarchyDepth' + CAST(@HierarchyNo as nvarchar) + '
					FROM
						' + @ETLDatabase + N'..vw_Tab_pcD_' + @DimensionName + '
					GROUP BY HierarchyDepth' + CAST(@HierarchyNo as nvarchar)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				FETCH NEXT FROM DimensionHierachy_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo
			END

		CLOSE DimensionHierachy_Cursor
		DEALLOCATE DimensionHierachy_Cursor	

	SET @Step = 'Get levels for hierarchies' --Column|LevelNo
		INSERT INTO #Definition
		SELECT
			ObjectID = 1000 * def.ObjectID + ROW_NUMBER() OVER (PARTITION BY d.DimensionID, dh.HierarchyNo ORDER BY dhl.LevelNo), ObjectType = N'Level', 
			ObjectName = dhl.LevelName,
			ParentObjectID = def.ObjectID,
			[Data] = dhl.LevelName + N'|' + CAST(ROW_NUMBER() OVER (PARTITION BY d.DimensionID, dh.HierarchyNo ORDER BY dhl.LevelNo) as nvarchar), 
			SortOrder = def.SortOrder + ROW_NUMBER() OVER (PARTITION BY d.DimensionID, dh.HierarchyNo ORDER BY dhl.LevelNo)
		FROM
			@Dimension d
			INNER JOIN DimensionHierarchy dh ON dh.DimensionID = d.DimensionID AND dh.InstanceID IN (@InstanceID, 0)
			INNER JOIN DimensionHierarchyLevel dhl ON dhl.DimensionID = d.DimensionID AND dhl.InstanceID IN (@InstanceID, 0) AND dhl.HierarchyNo = dh.HierarchyNo
			INNER JOIN #Definition def ON def.ObjectName = dh.HierarchyName AND def.ObjectType = 'Hierarchy'
			INNER JOIN #Definition defcol ON defcol.ObjectName = dhl.LevelName AND defcol.ObjectType = 'Column' AND def.ParentObjectID = defcol.ParentObjectID --Column must exist
		WHERE dhl.LevelNo <> 1 AND --Exclude All level
			dh.FixedLevelsYN <> 0
		UNION ALL
		SELECT
			ObjectID = 1000 * def.ObjectID + ROW_NUMBER() OVER (PARTITION BY d.DimensionID, dh.HierarchyNo ORDER BY hd.Depth), ObjectType = N'Level', 
			ObjectName = dh.HierarchyName + N' Lev ' + CAST(hd.Depth as nvarchar),
			ParentObjectID = def.ObjectID,
			[Data] = N'|' + CAST(hd.Depth as nvarchar), 
			SortOrder = def.SortOrder + ROW_NUMBER() OVER (PARTITION BY d.DimensionID, dh.HierarchyNo ORDER BY hd.Depth)
		FROM
			@Dimension d
			INNER JOIN DimensionHierarchy dh ON dh.DimensionID = d.DimensionID AND dh.InstanceID IN (@InstanceID, 0)
			INNER JOIN #Definition def ON def.ObjectName = dh.HierarchyName AND def.ObjectType = 'Hierarchy'
			INNER JOIN #HierachyDepth hd ON hd.DimensionID = d.DimensionID AND hd.HierarchyNo = dh.HierarchyNo
		WHERE dh.FixedLevelsYN = 0

	SET @Step = 'Get relationships' --FromTable|FromColumn|ToTable|ToColumn|Cardinality[1=ManyToOne,2=ManyToMany]
		INSERT INTO #Definition
		SELECT
			ObjectID = ROW_NUMBER() OVER (ORDER BY FromTable, ToTable), 
			ObjectType = N'Relationship', 
			ObjectName = FromTable + '_' + ToTable, 
			ParentObjectID = 0, 
			[Data] = FromTable + N'|' + FromColumn + N'|' + ToTable + N'|' + ToColumn + N'|' + CAST(Cardinality as nvarchar),
			SortOrder = 1000000000 + ROW_NUMBER() OVER (ORDER BY FromTable, ToTable)
		FROM
			(
				SELECT FromTable, FromColumn, ToTable, ToColumn, Cardinality = 1 FROM
				(
					SELECT
						FromTable = pd.ObjectName,
						FromColumn = d.ObjectName,
						ToTable = CASE WHEN d.ObjectName = N'TimeDate' THEN (SELECT DimensionName FROM @Dimension WHERE DimensionTypeGroupID = 2) ELSE LEFT(d.ObjectName, LEN(d.ObjectName) - CHARINDEX('_', REVERSE(d.ObjectName))) END,
						ToColumn = CASE WHEN d.ObjectName = N'TimeDate' THEN d.ObjectName ELSE RIGHT(d.ObjectName, CHARINDEX(N'_', REVERSE(d.ObjectName)) - 1) END
					FROM
						#Definition d
						INNER JOIN #Definition pd ON pd.ObjectID = d.ParentObjectID AND pd.ObjectType = N'Table'
					WHERE
						SUBSTRING(pd.Data, CHARINDEX(N'|', pd.Data), 999) = '|0' AND --Filter Fact tables
						d.ObjectType = N'Column' AND
						(CHARINDEX(N'_MemberId', d.ObjectName) > 0 OR d.ObjectName = 'TimeDate')

				) d
				INNER JOIN @Dimension dt ON dt.DimensionName = d.ToTable
				UNION ALL --Relations between fact tables
				SELECT
					FromTable = dc.DataClassName + N'_' + dcvf.DataClassViewName,
					FromColumn = dt.DimensionName + N'_MemberId',
					ToTable = dc.DataClassName + N'_' + dcvt.DataClassViewName,
					ToColumn = dt.DimensionName + N'_MemberId',
					Cardinality = 2
				FROM DataClass dc 
				INNER JOIN @Dimension dt ON dt.DimensionID = dc.PrimaryJoin_DimensionID
				INNER JOIN DataClassView dcvf ON dcvf.DataClassID = dc.DataClassID AND dcvf.DataClassViewBM > 1 --From is Greather than 1
				INNER JOIN DataClassView dcvt ON dcvt.DataClassID = dc.DataClassID AND dcvt.DataClassViewBM = 1 --To is always 1
				WHERE dc.DataClassID = @DataClassID
			) d

	SET @Step = 'Get roles' --Table1.Col=Member1,Member2;Table2.Col=Member1,Member2
		INSERT INTO #Definition
			(
			ObjectID, 
			ObjectType, 
			ObjectName, 
			ParentObjectID, 
			[Data], 
			SortOrder
			)
		SELECT
			ObjectID = SecurityRoleID, 
			ObjectType = N'Role', 
			ObjectName = SecurityRoleName, 
			ParentObjectID = 0, 
			[Data] = '', 
			SortOrder = 5000000 + 1000 * ABS(SecurityRoleID)
		FROM
			pcINTEGRATOR.dbo.SecurityRole SR
		WHERE
			SR.InstanceID IN (0, 413) AND
			SR.SecurityRoleID <> -10

		UNION SELECT
			ObjectID = ROP.RoleID, 
			ObjectType = N'Role', 
			ObjectName = 'zSecurityRole_' + CASE WHEN ROP.RoleID <= 9 THEN '00' ELSE CASE WHEN ROP.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), ROP.RoleID), 
			ParentObjectID = 0, 
			[Data] = '', 
			SortOrder = 10000000 * ROP.RoleID
		FROM
			#RoleOrganizationPosition ROP

		IF CURSOR_STATUS('global','Role_Cursor') >= -1 DEALLOCATE Role_Cursor
		DECLARE Role_Cursor CURSOR FOR
			
			SELECT 
				ObjectID
			FROM
				#Definition
			WHERE
				ObjectType = 'Role'
			ORDER BY
				ObjectID

			OPEN Role_Cursor
			FETCH NEXT FROM Role_Cursor INTO @ObjectID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ObjectID] = @ObjectID
				
					SET @FilterString = ''

					SELECT
						@FilterString = @FilterString + CASE WHEN PrevDimension IS NULL OR PrevDimension <> Dimension THEN N';' + Dimension + N'.' + Dimension + N'=' ELSE N',' END + MemberKey
					FROM
						(
						SELECT DISTINCT
							Dimension = D.DimensionName,
							MemberKey = RMR.MemberKey,
							PrevDimension = LAG(D.DimensionName) OVER (ORDER BY D.DimensionName, RMR.MemberKey)
						FROM
							#RoleMemberRow RMR
							INNER JOIN Dimension D ON D.DimensionID = RMR.DimensionID
						WHERE
							RoleID = @ObjectID AND
							MemberKey <> N'All_'
						) sub
					ORDER BY
						Dimension,
						MemberKey

					IF LEN(@FilterString) > 0
						UPDATE D
						SET
							[Data] = SUBSTRING(@FilterString, 2, LEN(@FilterString) - 1)
						FROM
							#Definition D
						WHERE
							ObjectID = @ObjectID AND
							ObjectType = N'Role'

					FETCH NEXT FROM Role_Cursor INTO @ObjectID
				END

		CLOSE Role_Cursor
		DEALLOCATE Role_Cursor

	SET @Step = 'Get rolemembers' --User
		INSERT INTO #Definition	--All Role members
			(
			ObjectID, 
			ObjectType, 
			ObjectName, 
			ParentObjectID, 
			[Data], 
			SortOrder
			)
		SELECT DISTINCT
			ObjectID = 1000000 + ABS(SRU.SecurityRoleID) + ROW_NUMBER() OVER (ORDER BY ABS(SRU.SecurityRoleID), U.UserID),
			ObjectType = N'RoleMember',
			ObjectName = SR.SecurityRoleName + N'_' +  U.AzureUPN,
			ParentObjectID = SRU.SecurityRoleID,
			[Data] = U.AzureUPN,
			SortOrder = def.SortOrder + ROW_NUMBER() OVER (PARTITION BY ABS(SRU.SecurityRoleID) ORDER BY U.UserID)		
		FROM
			SecurityRoleUser SRU
			INNER JOIN [#User] U ON U.UserID = SRU.UserID AND U.AzureUPN IS NOT NULL
			INNER JOIN SecurityRole SR ON SR.SecurityRoleID = SRU.SecurityRoleID
			INNER JOIN #Definition def ON def.ObjectID = SRU.SecurityRoleID AND def.ObjectType = 'Role'
		WHERE
			SRU.SecurityRoleID <> -10 AND 
			SRU.InstanceID = @InstanceID

		INSERT INTO #Definition	--All Role Members via groups
			(
			ObjectID, 
			ObjectType, 
			ObjectName, 
			ParentObjectID, 
			[Data], 
			SortOrder
			)
		SELECT DISTINCT
			ObjectID = 1200000 + ABS(SRU.SecurityRoleID) + ROW_NUMBER() OVER (ORDER BY ABS(SRU.SecurityRoleID), U.UserID),
			ObjectType = N'RoleMember',
			ObjectName = SR.SecurityRoleName + N'_' +  U.AzureUPN,
			ParentObjectID = SRU.SecurityRoleID,
			[Data] = U.AzureUPN,
			SortOrder = def.SortOrder + ROW_NUMBER() OVER (PARTITION BY ABS(SRU.SecurityRoleID) ORDER BY U.UserID)		
		FROM
			SecurityRoleUser SRU
			INNER JOIN [UserMember] UM ON UM.UserID_Group = SRU.UserID
			INNER JOIN [#User] U ON U.UserID = UM.UserID_User AND U.AzureUPN IS NOT NULL
			INNER JOIN SecurityRole SR ON SR.SecurityRoleID = SRU.SecurityRoleID
			INNER JOIN #Definition def ON def.ObjectID = SRU.SecurityRoleID AND def.ObjectType = 'Role'
		WHERE
			SRU.SecurityRoleID <> -10 AND 
			SRU.InstanceID = @InstanceID AND
			NOT EXISTS (SELECT 1 FROM #Definition D WHERE D.ObjectType = 'RoleMember' AND D.ParentObjectID = SR.SecurityRoleID AND D.[Data] = U.AzureUPN)

		INSERT INTO #Definition	--All Users
			(
			ObjectID, 
			ObjectType, 
			ObjectName, 
			ParentObjectID, 
			[Data], 
			SortOrder
			)
		SELECT
			ObjectID = 1400000 + ABS(SR.SecurityRoleID) + ROW_NUMBER() OVER (ORDER BY ABS(SR.SecurityRoleID), U.UserID),
			ObjectType = N'RoleMember',
			ObjectName = SR.SecurityRoleName + N'_' +  U.AzureUPN,
			ParentObjectID = SR.SecurityRoleID,
			[Data] = U.AzureUPN,
			SortOrder = def.SortOrder + ROW_NUMBER() OVER (PARTITION BY ABS(SR.SecurityRoleID) ORDER BY U.UserID)		
		FROM
			[#User] U 
			INNER JOIN SecurityRole SR ON SR.SecurityRoleID = -3
			INNER JOIN #Definition def ON def.ObjectID = SR.SecurityRoleID AND def.ObjectType = 'Role'
		WHERE
			U.AzureUPN IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM #Definition D WHERE D.ObjectType = 'RoleMember' AND D.ParentObjectID = SR.SecurityRoleID AND D.[Data] = U.AzureUPN)

		INSERT INTO #Definition	--All Z-roles
			(
			ObjectID, 
			ObjectType, 
			ObjectName, 
			ParentObjectID, 
			[Data], 
			SortOrder
			)
		SELECT
			ObjectID = 2000000 + ABS(ROP.RoleID) + ROW_NUMBER() OVER (ORDER BY ABS(ROP.RoleID), U.UserID),
			ObjectType = N'RoleMember',
			ObjectName = 'zSecurityRole_' + CASE WHEN ROP.RoleID <= 9 THEN '00' ELSE CASE WHEN ROP.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), ROP.RoleID) + N'_' +  U.AzureUPN,
			ParentObjectID = ROP.RoleID,
			[Data] = U.AzureUPN,
			SortOrder = def.SortOrder + ROW_NUMBER() OVER (PARTITION BY ROP.RoleID ORDER BY U.UserID)
		FROM
			#RoleOrganizationPosition ROP
			INNER JOIN [OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = ROP.OrganizationPositionID
			INNER JOIN [#User] U ON U.UserID = OPU.UserID AND U.AzureUPN IS NOT NULL
			INNER JOIN #Definition def ON def.ObjectID = ROP.RoleID AND def.ObjectType = 'Role'
		WHERE
			NOT EXISTS (SELECT 1 FROM #Definition D WHERE D.ObjectType = 'RoleMember' AND D.ParentObjectID = -2 AND D.[Data] = U.AzureUPN)

	SET @Step = 'Return data'
		SELECT
			*
		FROM
			#Definition
		ORDER BY -- SortOrder needs to be, DataSource => Table,Column,Measure,Hierarchy => Rest of types
			SortOrder

	SET @Step = 'Drop temp tables'
		DROP TABLE #Definition
		DROP TABLE #ValidDimensionColumn
		DROP TABLE #HierachyDepth
		DROP TABLE #User
		DROP TABLE #RoleMemberRow
		DROP TABLE #RoleOrganizationPosition

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
