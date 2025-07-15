SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_DimensionMember_sega]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DimensionID int = NULL, --Mandatory
	@HierarchyNo int = 0,
	@HierarchyView nvarchar(10) = 'Parent', --'Parent' or 'Level'
	@HierarchyName nvarchar(50) = NULL OUT,
	@ResultTypeBM int = 4, --1 = PropertyDefinition, 2 = PropertyMember lists, 4 = Dimension members, 8 = Members possible to Delete, 16 = Properties, Locked/Invisible by NodeTypeBM
	@ObjectGuiBehaviorBM int = 1,
	@MemberKey nvarchar(50) = NULL, --Optional

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000142,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DimensionMember] @DebugBM=15, @DimensionID=N'5831',@HierarchyNo=N'0',@HierarchyView=N'Parent',@InstanceID=N'668',@ObjectGuiBehaviorBM=N'3',@ResultTypeBM=N'4',@UserID=N'11531',@VersionID=N'1100'

EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DimensionMember] @DebugBM=3, @DimensionID=N'-1',@HierarchyNo=N'0',@HierarchyView=N'Parent',
@InstanceID=N'534',@ObjectGuiBehaviorBM=N'3',@ResultTypeBM=N'4',@UserID=N'9526',@VersionID=N'1060'

EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DimensionMember] @UserID=-10,@InstanceID=-1786,@VersionID=-1786, @DimensionID=-1,@HierarchyView='Parent',@ResultTypeBM=4, @DebugBM = 0
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DimensionMember] @UserID=-10,@InstanceID=-1590,@VersionID=-1590, @DimensionID=-1,@HierarchyView='Level',@ResultTypeBM=4, @DebugBM = 0
EXEC [spPortalGet_DimensionMember] @UserID = -10, @InstanceID = -1590, @VersionID = -1590, @DimensionID = -1, @ResultTypeBM = 4, @Debug = 0
EXEC [spPortalGet_DimensionMember] @UserID = 1005, @InstanceID = 413, @VersionID = 1008, @DimensionID = -63, @ResultTypeBM = 8, @Debug = 1
EXEC [spPortalGet_DimensionMember] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @DimensionID = -63, @ResultTypeBM = 8, @Debug = 1
EXEC [spPortalGet_DimensionMember] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DimensionID = -53, @ResultTypeBM = 4, @Debug = 1
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DimensionMember] @DimensionID='9155',@HierarchyNo='2',@HierarchyView='Parent',@InstanceID='531',@ObjectGuiBehaviorBM='3',@ResultTypeBM='15',@UserID='26625',@VersionID='1041'

EXEC [spPortalGet_DimensionMember]
	@UserID = -10,
	@InstanceID = 531,
	@VersionID = 1041,
	@DimensionID = 9155,
	@HierarchyNo = 0,
	@ResultTypeBM = 20,
	@HierarchyView = 'Level', --'Parent', 'Level'
	@ObjectGuiBehaviorBM = 3

EXEC [spPortalGet_DimensionMember]
@UserID = 1005, @InstanceID = 413, @VersionID = 1008, @DimensionID = -4, @ResultTypeBM = 8,
@HierarchyView = 'Parent',  @ObjectGuiBehaviorBM = 7, @MemberKey = '39', @Debug = 1

EXEC [spPortalGet_DimensionMember]
@UserID = -10, @InstanceID = 621, @VersionID = 1105, @DimensionID = 5813, @ResultTypeBM = 15,
@HierarchyView = 'Parent',  @ObjectGuiBehaviorBM = 3, @HierarchyNo = '0' @Debug = 1

EXEC [spPortalGet_DimensionMember] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(max),
	@SQLStatement_Create nvarchar(max) = '',
	@SQLStatement_Select nvarchar(max) = '',
	@SQLStatement_Set nvarchar(max) = '',
	@SQLStatement_Return nvarchar(max) = '',
	@FixedLevelsYN bit,
	@MaxLevelNo int,
	@LevelNo int,
	@LevelName nvarchar(50),
	@PropertyID int,
	@PropertyName nvarchar(50),
	@PropertyNameParent nvarchar(50),
	@StorageTypeBM int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@DimensionName nvarchar(100),
	@DependentDimensionName nvarchar(100),
	@HierarchyLevelNo int,
	@KeyColumn nvarchar(50),
	@PropertyStorageTypeBM int,
	@PropertyDimensionID int,
	@Dimension_ObjectGuiBehaviorBM int,
	@DST_InstanceID int,
	@ApplicationID int = NULL,
	@DataClassID int,
	@DataClassName nvarchar(50),
	@DataClass_StorageTypeBM int,
	@NoOfLevels int,
	@EnhancedStorageYN int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get Dimension Members',
			@MandatoryParameter = 'DimensionID' --Without @, separated by |

		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2135' SET @Description = 'Handle properties and hierarchies.'
		IF @Version = '1.4.0.2139' SET @Description = 'Handle StorageTypeBM = 4.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2151' SET @Description = 'Test on SelectYN for Property.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-347: Deallocate Cursors if existing.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-427: Adding VersionID to tables DimensionHierarchy, DimensionHierarchyLevel & Dimension_Property.'
		IF @Version = '2.1.0.2156' SET @Description = 'DB-500, DB-508: Modified query for PropertyMember_Cursor. DB-470: Added @ResultTypeBM 8 (Members possible to Delete).'
		IF @Version = '2.1.0.2159' SET @Description = '@ResultTypeBM 8, test on DataClass.SelectYN <> 0'
		IF @Version = '2.1.0.2162' SET @Description = 'Set correct MAX @HierarchyLevelNo.'
		IF @Version = '2.1.1.2168' SET @Description = 'ResultTypeBM = 4, do not group by SortOrder, set to MAX to avoid duplicates. Applied table hint WITH (NOLOCK) when reading from @CallistoDatabase FACT table in @Step = @ResultTypeBM & 8.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle DimensionType AutoMultiDim.'
		IF @Version = '2.1.1.2170' SET @Description = 'Increase length of property column in temp table #Dimension_Member from nvarchar(100) to nvarchar(max). Handle hierarchy names with space.'
		IF @Version = '2.1.2.2179' SET @Description = 'Exclude property NodeTypeBM from list of extra properties.'
		IF @Version = '2.1.2.2191' SET @Description = 'Handle @EnhancedStorageYN'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-1948: Handle dimension property [NodeTypeBM] = NULL values by using [RNodeType]. FPA-135: FOr @ResultTypeBM=4, include NodeTypeBM=1024 for @HierarchyView <> "Level". FDB-3142: #Dimension_Member column types are based on original S_DS_XXX columns instead of nvarchar(max) - it was slow on update.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy = @ModifiedBy, @JobID = @ProcedureID
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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@Dimension_ObjectGuiBehaviorBM = ObjectGuiBehaviorBM
		FROM
			[Dimension]
		WHERE
			DimensionID = @DimensionID

		SELECT
			@StorageTypeBM = StorageTypeBM
		FROM
			[Dimension_StorageType]
		WHERE
			(InstanceID = @InstanceID OR (@Dimension_ObjectGuiBehaviorBM & 4 > 0 AND InstanceID = 0)) AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		SET @StorageTypeBM = ISNULL(@StorageTypeBM, 1)

		IF @StorageTypeBM IS NULL
			BEGIN
				SET @Message = 'StorageTypeBM is not defined for InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' and DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + '. Must be defined in table pcINTEGRATOR.dbo.Dimension_StorageType'
				SET @Severity = 16
				GOTO EXITPOINT
			END

		IF @StorageTypeBM & 4 > 0 AND @ResultTypeBM & 14 > 0 --Callisto
			BEGIN
				SELECT
					@ApplicationID = [ApplicationID],
					@EnhancedStorageYN = [EnhancedStorageYN]
				FROM
					[Application]
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					SelectYN <> 0

				SELECT
					@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
					@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
				FROM
					[Application] A
				WHERE
					A.ApplicationID = @ApplicationID

				IF @DebugBM & 2 > 0 SELECT [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@ApplicationID] = @ApplicationID, [@CallistoDatabase] = @CallistoDatabase, [@ETLDatabase] = @ETLDatabase
			END

		SELECT
			@DimensionName = DimensionName
		FROM
			Dimension
		WHERE
			InstanceID IN (0, @InstanceID) AND
			DimensionID = @DimensionID

		IF @DebugBM & 2 > 0
			SELECT
				[@DimensionName] = @DimensionName,
				[@CallistoDatabase] = @CallistoDatabase,
				[@EnhancedStorageYN] = @EnhancedStorageYN

	IF @DebugBM & 16 > 0 SELECT [Step] = 'After initial settings', [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)

	SET @Step = 'Create temp table #Dimension_Property'
		CREATE TABLE #Dimension_Property
			(
			PropertyID int,
			PropertyName nvarchar(100) COLLATE DATABASE_DEFAULT,
			PropertyName_Callisto nvarchar(100) COLLATE DATABASE_DEFAULT,
			DisplayName nvarchar(100) COLLATE DATABASE_DEFAULT,
			SortOrder int,
			InstanceID int,
			DataType nvarchar(50),
			GuiObject nvarchar(50),
			NodeTypeBM int,
			DependentDimensionID int,
			DataTypeSQL nvarchar(50),
			)

		INSERT INTO #Dimension_Property
			(
			PropertyID,
			PropertyName,
			PropertyName_Callisto,
			SortOrder,
			InstanceID,
			NodeTypeBM
			)
		SELECT
			PropertyID = P.[PropertyID],
			PropertyName = CASE WHEN P.PropertyID NOT BETWEEN 21 AND 49 THEN 'p' ELSE CONVERT(nvarchar(5), P.PropertyID % 10) END + '@' + P.PropertyName,
			PropertyName_Callisto = CONVERT(nvarchar(100), '') COLLATE DATABASE_DEFAULT,
			SortOrder = MAX(DP.SortOrder),
			InstanceID = ISNULL(MAX(DST.InstanceID), @InstanceID),
			[NodeTypeBM] = MAX(DP.[NodeTypeBM])
		FROM
			Dimension_Property DP
			INNER JOIN Property P ON P.PropertyID = DP.PropertyID AND (P.InstanceID = @InstanceID OR P.InstanceID = 0) AND P.ObjectGuiBehaviorBM & @ObjectGuiBehaviorBM > 0 AND P.SelectYN <> 0 AND P.PropertyID NOT BETWEEN 21 AND 49 --(P.PropertyID % 10 = @HierarchyNo OR P.PropertyID NOT BETWEEN 21 AND 49)
			LEFT JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = P.DependentDimensionID
		WHERE
			DP.InstanceID IN(0, @InstanceID) AND
			DP.VersionID IN(0, @VersionID) AND
			DP.DimensionID = @DimensionID AND
			DP.PropertyID <> 12 --NodeTypeBM
		GROUP BY
			P.PropertyID,
			CASE WHEN P.PropertyID NOT BETWEEN 21 AND 49 THEN 'p' ELSE CONVERT(nvarchar(5), P.PropertyID % 10) END + '@' + P.PropertyName
			--DP.SortOrder

		INSERT INTO #Dimension_Property
			(
			[PropertyID],
			[PropertyName],
			[DisplayName],
			[NodeTypeBM],
			[SortOrder]
			)
		SELECT PropertyID = 0, PropertyName = 'InstanceID', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 0
		UNION SELECT PropertyID = 0, PropertyName = 'DimensionID', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 0
		UNION SELECT PropertyID = 8, PropertyName = 'MemberID', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 5
		UNION SELECT PropertyID = 5, PropertyName = 'MemberKey', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 10
		UNION SELECT PropertyID = 4, PropertyName = 'MemberDescription', DisplayName = 'Description', [NodeTypeBM] = 1027, [SortOrder] = 20
		UNION SELECT PropertyID = 9, PropertyName = 'HelpText', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 25
		UNION SELECT PropertyID = 12, PropertyName = 'NodeTypeBM', DisplayName = 'NodeType', [NodeTypeBM] = 1027, [SortOrder] = 145
		UNION SELECT PropertyID = 7, PropertyName = 'SBZ', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 150
		UNION SELECT PropertyID = 2, PropertyName = 'Source', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 160
		UNION SELECT PropertyID = 1, PropertyName = 'Synchronized', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 170
		UNION SELECT PropertyID = 10, PropertyName = 'Level', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 175
		UNION SELECT PropertyID = 11, PropertyName = 'SortOrder', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 177
		UNION SELECT PropertyID = 3, PropertyName = 'Parent', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 180

		UPDATE DP
		SET
			DataType = DaT.DataTypePortal,
			GuiObject = CASE WHEN P.DependentDimensionID IS NOT NULL THEN 'ComboBox' ELSE DaT.GuiObject END,
			DependentDimensionID = P.DependentDimensionID
		FROM
			#Dimension_Property DP
			INNER JOIN Property P ON P.PropertyID = DP.PropertyID
			INNER JOIN DataType DaT ON DaT.DataTypeID = P.DataTypeID

        SET @SQLStatement = '
        UPDATE DP
        SET DP.DataTypeSQL =
            QUOTENAME(C.DATA_TYPE) +
            ISNULL(
                CASE
                    WHEN C.CHARACTER_MAXIMUM_LENGTH IS NOT NULL AND C.DATA_TYPE LIKE ''%char%''
                        THEN ''('' +
                            CASE WHEN C.CHARACTER_MAXIMUM_LENGTH = -1 THEN ''MAX''
                                 ELSE CAST(C.CHARACTER_MAXIMUM_LENGTH AS VARCHAR)
                            END + '')''
                    WHEN C.DATA_TYPE IN (''decimal'', ''numeric'')
                        THEN ''('' + CAST(C.NUMERIC_PRECISION AS VARCHAR) + '','' + CAST(C.NUMERIC_SCALE AS VARCHAR) + '')''
                    ELSE ''''
                END, '''')
        FROM #Dimension_Property DP
        INNER JOIN ' + @CallistoDatabase + '.INFORMATION_SCHEMA.COLUMNS C
            ON C.TABLE_NAME = ''S_DS_' + @DimensionName + '''
            AND C.COLUMN_NAME = replace(DP.PropertyName, ''p@'', '''');
        ';

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
        EXEC (@SQLStatement);

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension_Property', * FROM #Dimension_Property ORDER BY SortOrder, PropertyName

		IF @ResultTypeBM & 1 > 0
			SELECT
				[ResultTypeBM] = 1,
				[PropertyID],
				[PropertyName],
				[DisplayName] = ISNULL(DisplayName,REPLACE(PropertyName, 'p@', '')),
				[DataType],
				[GuiObject],
				[NodeTypeBM],
				[SortOrder]
			FROM
				#Dimension_Property
			WHERE
				PropertyID <> 0
			ORDER BY
				[SortOrder],
				[PropertyName]

	IF @DebugBM & 16 > 0 SELECT [Step] = 'After Create temp table #Dimension_Property', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = '@ResultTypeBM = 2'
--	SELECT [@PropertyID] = @PropertyID, [@PropertyName]=@PropertyName, [@PropertyDimensionID]=@PropertyDimensionID, [@DimensionName]=@DimensionName, [@PropertyStorageTypeBM]=@PropertyStorageTypeBM, [@DST_InstanceID]=@DST_InstanceID
		IF @ResultTypeBM & 2 > 0
			BEGIN
				IF CURSOR_STATUS('global','PropertyMember_Cursor') >= -1 DEALLOCATE PropertyMember_Cursor
				DECLARE PropertyMember_Cursor CURSOR FOR
					SELECT
						[PropertyID] = DP.[PropertyID],
						[PropertyName] = DP.[PropertyName],
						[PropertyDimensionID] = DP.[DependentDimensionID],
						[DependentDimensionName] = D.[DimensionName],
						[PropertyStorageTypeBM] = ISNULL(DST.[StorageTypeBM], 1),
						[InstanceID] = ISNULL(DST.[InstanceID], 0)
					FROM
						#Dimension_Property DP
						LEFT JOIN [Dimension] D ON D.[DimensionID] = DP.[DependentDimensionID]
						LEFT JOIN [Dimension_StorageType] DST ON DST.[InstanceID] = @InstanceID AND DST.[DimensionID] = DP.[DependentDimensionID]
					WHERE
						GuiObject IN ('BitMap', 'ComboBox')
					ORDER BY
						SortOrder,
						PropertyName

	                IF @DebugBM & 16 > 0 SELECT [Step] = 'After DECLARE PropertyMember_Cursor', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

					OPEN PropertyMember_Cursor
					FETCH NEXT FROM PropertyMember_Cursor INTO @PropertyID, @PropertyName, @PropertyDimensionID, @DependentDimensionName, @PropertyStorageTypeBM, @DST_InstanceID

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@PropertyID] = @PropertyID, [@PropertyName] = @PropertyName, [@PropertyDimensionID] = @PropertyDimensionID, [@DependentDimensionName] = @DependentDimensionName, [@PropertyStorageTypeBM] = @PropertyStorageTypeBM, [@DST_InstanceID] = @DST_InstanceID

							IF @PropertyID <> 12 AND @PropertyStorageTypeBM & 1 > 0
								BEGIN
									SELECT
										ResultTypeBM = 2,
										PropertyID = @PropertyID,
										PropertyName = @PropertyName,
										[MemberKey] = ISNULL(DMI.[MemberKey], DMG.[MemberKey]),
										[MemberDescription] = MAX(ISNULL(DMI.[MemberDescription], DMG.[MemberDescription])),
										[HelpText] = MAX(ISNULL(DMI.[HelpText], DMG.[HelpText]))
									FROM
										[Dimension] D
										LEFT JOIN [DimensionMember] DMI ON DMI.InstanceID = @DST_InstanceID AND DMI.DimensionID = D.DimensionID
										LEFT JOIN [DimensionMember] DMG ON DMG.InstanceID = 0 AND DMG.DimensionID = D.DimensionID AND DMG.MemberKey = DMI.MemberKey
									WHERE
										D.DimensionID = @PropertyDimensionID
									GROUP BY
										ISNULL(DMI.[MemberKey], DMG.[MemberKey])

	                                IF @DebugBM & 16 > 0 SELECT [Step] = 'After IF @PropertyID <> 12 AND @PropertyStorageTypeBM & 1 > 0', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
								END

							ELSE IF @PropertyID <> 12 AND @PropertyStorageTypeBM & 4 > 0
								BEGIN
									SET @SQLStatement = '
										SELECT
											ResultTypeBM = 2,
											PropertyID = ' + CONVERT(nvarchar(10), @PropertyID) + ',
											PropertyName = ''' + @PropertyName + ''',
											MemberKey = Label,
											MemberDescription = [Description],
											HelpText = [HelpText]
										FROM
											' + @CallistoDatabase + '..S_DS_' + @DependentDimensionName + '
										WHERE
											RNodeType = ''L''
										ORDER BY
											Label'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									IF @DebugBM & 16 > 0 SELECT [Step] = 'After ELSE IF @PropertyID <> 12 AND @PropertyStorageTypeBM & 4 > 0', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
								END

							IF @PropertyID = 12
								SELECT
									ResultTypeBM = 2,
									PropertyID = 12,
									PropertyName = 'NodeTypeBM',
									MemberKey = NodeTypeBM,
									MemberDescription = [NodeTypeName],
									HelpText = NodeTypeDescription,
									BitmapGroupID = NodeTypeGroupID,
									BitmapDependencyBM = NodeTypeDependencyBM
								FROM
									NodeType
								ORDER BY
									NodeTypeBM

                            IF @DebugBM & 16 > 0 SELECT [Step] = 'After IF @PropertyID = 12', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

							FETCH NEXT FROM PropertyMember_Cursor INTO  @PropertyID, @PropertyName, @PropertyDimensionID, @DependentDimensionName, @PropertyStorageTypeBM, @DST_InstanceID
						END

				CLOSE PropertyMember_Cursor
				DEALLOCATE PropertyMember_Cursor
			END

	IF @DebugBM & 16 > 0 SELECT [Step] = 'After @ResultTypeBM = 2', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

--SELECT
--	@PropertyID = NULL,
--	@PropertyName = NULL,
--	@PropertyDimensionID = NULL,
--	@DimensionName = 'Account',
--	@PropertyStorageTypeBM = NULL,
--	@DST_InstanceID = NULL

--SELECT [@PropertyID] = @PropertyID, [@PropertyName]=@PropertyName, [@PropertyDimensionID]=@PropertyDimensionID, [@DimensionName]=@DimensionName, [@PropertyStorageTypeBM]=@PropertyStorageTypeBM, [@DST_InstanceID]=@DST_InstanceID

	SET @Step = 'Handle Hierarchies'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				IF @HierarchyNo IS NOT NULL
					BEGIN
						SELECT
							@HierarchyName = MAX(ISNULL(DHI.HierarchyName, DHG.HierarchyName)),
							@FixedLevelsYN = MAX(CONVERT(int, ISNULL(DHI.FixedLevelsYN, DHG.FixedLevelsYN)))
						FROM
							Dimension D
							LEFT JOIN DimensionHierarchy DHI ON DHI.InstanceID = @InstanceID AND DHI.VersionID = @VersionID AND DHI.DimensionID = D.DimensionID AND DHI.HierarchyNo = @HierarchyNo
							LEFT JOIN DimensionHierarchy DHG ON DHG.InstanceID = 0 AND DHG.VersionID = 0 AND DHG.DimensionID = D.DimensionID AND DHG.HierarchyNo = @HierarchyNo
						WHERE
							D.DimensionID = @DimensionID
						GROUP BY
							D.DimensionID

						SELECT
							DimensionID = D.DimensionID,
							LevelNo = ISNULL(DHLI.LevelNo, DHLG.LevelNo),
							LevelName = MAX(ISNULL(DHLI.LevelName, DHLG.LevelName)),
							PropertyName = CONVERT(nvarchar(10), ISNULL(DHLI.LevelNo, DHLG.LevelNo)) + '@' + MAX(ISNULL(DHLI.LevelName, DHLG.LevelName)),
							SortOrder = 200 + ISNULL(DHLI.LevelNo, DHLG.LevelNo)
						INTO
							#HierarchyLevel
						FROM
							Dimension D
							LEFT JOIN DimensionHierarchyLevel DHLI ON DHLI.InstanceID = @InstanceID AND DHLI.VersionID = @VersionID AND DHLI.DimensionID = D.DimensionID AND DHLI.HierarchyNo = @HierarchyNo
							LEFT JOIN DimensionHierarchyLevel DHLG ON DHLG.InstanceID = 0 AND DHLG.VersionID = 0 AND DHLG.DimensionID = D.DimensionID AND DHLG.HierarchyNo = @HierarchyNo
						WHERE
							D.DimensionID = @DimensionID
						GROUP BY
							D.DimensionID,
							ISNULL(DHLI.LevelNo, DHLG.LevelNo)

						SELECT @MaxLevelNo = MAX(LevelNo) FROM #HierarchyLevel

						IF @DebugBM & 2 > 0 SELECT TempTable = '#HierarchyLevel', * FROM #HierarchyLevel

						IF @FixedLevelsYN <> 0 AND @HierarchyView = 'Level' AND @HierarchyName IS NOT NULL AND (SELECT MAX(LevelNo) FROM #HierarchyLevel) IS NOT NULL
							BEGIN
								INSERT INTO #Dimension_Property
									(
									P.PropertyID,
									PropertyName,
									DP.SortOrder
									)
								SELECT
									PropertyID = LevelNo * -1,
									PropertyName = PropertyName,
									SortOrder
								FROM
									#HierarchyLevel
							END
						ELSE
							SET @HierarchyView = 'Parent'

	                    IF @DebugBM & 16 > 0 SELECT [Step] = 'After IF @HierarchyNo IS NOT NULL', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
					END
				ELSE
					SET @HierarchyView = 'Parent'
			END

		IF @DebugBM & 2 > 0 SELECT [@HierarchyName] = @HierarchyName, [@FixedLevelsYN] = @FixedLevelsYN
/*
	SET @Step = 'Create sortorder'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase, [@DimensionName] = @DimensionName, [@HierarchyName] = @HierarchyName

				CREATE TABLE #SortOrder
					(
					[MemberId] bigint,
					[ParentMemberID] bigint,
					[SortOrder] bigint IDENTITY(1,1)
					)

				SET @SQLStatement = '
					SELECT
						*
					FROM
						' + @CallistoDatabase + '..S_HS_' + @DimensionName + '_' + @HierarchyName

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @SQLStatement = '
					;WITH CTE AS
					(
						SELECT
							H.[MemberID],
							H.[ParentMemberID],
							H.[SequenceNumber]
						FROM
							' + @CallistoDatabase + '..S_HS_' + @DimensionName + '_' + @HierarchyName + ' H
						WHERE
							H.[ParentMemberID] = 0
						UNION ALL
						SELECT
							H.[MemberID],
							H.[ParentMemberID],
							H.[SequenceNumber]
						FROM
							' + @CallistoDatabase + '..S_HS_' + @DimensionName + '_' + @HierarchyName + ' H
							INNER JOIN CTE on CTE.[MemberID] = H.[ParentMemberID]
					)
					INSERT INTO #SortOrder
						(
						[MemberId],
						[ParentMemberId]
						)
					SELECT
						[MemberId] = CTE.[MemberId],
						[ParentMemberID] = CTE.[ParentMemberID]
					FROM
						CTE'
--						INNER JOIN ' + @CallistoDatabase + '..S_HS_' + @DimensionName + '_' + @HierarchyName + ' H ON H.[MemberId] = CTE.[MemberId]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				IF @DebugBM & 2 > 0 SELECT TempTable = '#SortOrder', * FROM #SortOrder ORDER BY [SortOrder]
			END
*/
	IF @DebugBM & 16 > 0 SELECT [Step] = 'After step: ' + @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Create temp table #Dimension_Member'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
-- 					@SQLStatement_Create = @SQLStatement_Create + 'ALTER TABLE #Dimension_Member ADD [' + PropertyName + '] nvarchar(MAX) COLLATE DATABASE_DEFAULT' + CHAR(13) + CHAR(10),
					@SQLStatement_Create = @SQLStatement_Create + 'ALTER TABLE #Dimension_Member ADD [' + PropertyName + '] ' + DataTypeSQL + iif(DataTypeSQL like '%char%', ' COLLATE DATABASE_DEFAULT', '') + CHAR(13) + CHAR(10),
					@SQLStatement_Select = @SQLStatement_Select + '[' + PropertyName + '] = MAX(CASE WHEN DP.PropertyID = ' + CONVERT(nvarchar(10), PropertyID) + ' THEN ISNULL(DMPI.Value, DMPG.Value) ELSE NULL END),' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9),
					@SQLStatement_Set = @SQLStatement_Set + '[' + PropertyName + '] = sub.[' + PropertyName + '],' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9)
				FROM
					#Dimension_Property
				WHERE
					PropertyName LIKE '%@%' OR PropertyName LIKE '%#%'
				ORDER BY
					SortOrder,
					PropertyName

				IF @DebugBM & 2 > 0 SELECT [@SQLStatement_Create] = @SQLStatement_Create, [@SQLStatement_Select] = @SQLStatement_Select, [@SQLStatement_Set] = @SQLStatement_Set

				IF LEN(@SQLStatement_Select) > 0 SET @SQLStatement_Select = LEFT(@SQLStatement_Select, LEN(@SQLStatement_Select) - 7)
				IF LEN(@SQLStatement_Set) > 0 SET @SQLStatement_Set = LEFT(@SQLStatement_Set, LEN(@SQLStatement_Set) - 6)

					CREATE TABLE #Dimension_Member
						(
						[InstanceID] int,
						[DimensionID] int,
						[MemberID] int,
						[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
						[MemberDescription] nvarchar(255) COLLATE DATABASE_DEFAULT,
						[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
						[NodeTypeBM] int,
						[SBZ] bit,
						[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[Synchronized] bit,
						[LevelNo] int,
						[Level] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[SortOrder] int,
						[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT
						)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement_Create
				EXEC (@SQLStatement_Create)
			END

	IF @DebugBM & 16 > 0 SELECT [Step] = 'After step: ' + @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Fill temp table with members (#Dimension_Member).'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				IF @StorageTypeBM & 1 > 0  --Internal
					BEGIN
						INSERT INTO #Dimension_Member
							(
							[InstanceID],
							[DimensionID],
							[MemberID],
							[MemberKey],
							[MemberDescription],
							[HelpText],
							[NodeTypeBM],
							[SBZ],
							[Source],
							[Synchronized],
							[LevelNo],
							[Level],
							[SortOrder],
							[Parent]
							)
						SELECT
							[InstanceID] = MAX(ISNULL(DMI.InstanceID, DMG.InstanceID)),
							[DimensionID] = D.DimensionID,
							[MemberID] = MAX(ISNULL(DMI.[MemberID], DMG.[MemberID])),
							[MemberKey] = ISNULL(DMI.[MemberKey], DMG.[MemberKey]),
							[MemberDescription] = MAX(ISNULL(DMI.[MemberDescription], DMG.[MemberDescription])),
							[HelpText] = MAX(ISNULL(DMI.[HelpText], DMG.[HelpText])),
							[NodeTypeBM] = MAX(ISNULL(DMI.[NodeTypeBM], DMG.[NodeTypeBM])),
							[SBZ] = MAX(CONVERT(int, ISNULL(DMI.[SBZ], DMG.[SBZ]))),
							[Source] = MAX(ISNULL(DMI.[Source], DMG.[Source])),
							[Synchronized] = MAX(CONVERT(int, ISNULL(DMI.[Synchronized], DMG.[Synchronized]))),
							[LevelNo] = MAX(HL.[LevelNo]),
							[Level] = CASE WHEN @HierarchyNo = 0 THEN MAX(ISNULL(DMI.[Level], DMG.[Level])) ELSE MAX(ISNULL(DMP2I.[Value], DMP2G.[Value])) END,
							[SortOrder] = ISNULL(CASE WHEN @HierarchyNo = 0 THEN MAX(ISNULL(DMI.[SortOrder], DMG.[SortOrder])) ELSE MAX(ISNULL(DMP3I.[Value], DMP3G.[Value])) END, 100000000 + MAX(ISNULL(HL.LevelNo, CASE WHEN ISNULL(DMI.[NodeTypeBM], DMG.[NodeTypeBM]) & 1 > 0 THEN 99 ELSE 0 END)) * 1000000 + 10),
							[Parent] = CASE WHEN @HierarchyNo = 0 THEN MAX(ISNULL(DMI.[Parent], DMG.[Parent])) ELSE MAX(ISNULL(DMP4I.[Value], DMP4G.[Value])) END
						FROM
							[Dimension] D
							LEFT JOIN [DimensionMember] DMI ON DMI.InstanceID = @InstanceID AND DMI.DimensionID = D.DimensionID
							LEFT JOIN [DimensionMember] DMG ON DMG.InstanceID = 0 AND DMG.DimensionID = D.DimensionID AND (DMG.MemberKey = DMI.MemberKey OR DMI.MemberKey IS NULL)
							LEFT JOIN [DimensionMember_Property] DMP2I ON DMP2I.InstanceID = @InstanceID AND DMP2I.DimensionID = D.DimensionID AND DMP2I.MemberKey = ISNULL(DMI.[MemberKey], DMG.[MemberKey]) AND DMP2I.PropertyID = 20 + @HierarchyNo
							LEFT JOIN [DimensionMember_Property] DMP2G ON DMP2G.InstanceID = 0 AND DMP2G.DimensionID = D.DimensionID AND DMP2G.MemberKey = ISNULL(DMI.[MemberKey], DMG.[MemberKey]) AND DMP2G.PropertyID = 20 + @HierarchyNo
							LEFT JOIN [DimensionMember_Property] DMP3I ON DMP3I.InstanceID = @InstanceID AND DMP3I.DimensionID = D.DimensionID AND DMP3I.MemberKey = ISNULL(DMI.[MemberKey], DMG.[MemberKey]) AND DMP3I.PropertyID = 30 + @HierarchyNo
							LEFT JOIN [DimensionMember_Property] DMP3G ON DMP3G.InstanceID = 0 AND DMP3G.DimensionID = D.DimensionID AND DMP3G.MemberKey = ISNULL(DMI.[MemberKey], DMG.[MemberKey]) AND DMP3G.PropertyID = 30 + @HierarchyNo
							LEFT JOIN [DimensionMember_Property] DMP4I ON DMP4I.InstanceID = @InstanceID AND DMP4I.DimensionID = D.DimensionID AND DMP4I.MemberKey = ISNULL(DMI.[MemberKey], DMG.[MemberKey]) AND DMP4I.PropertyID = 40 + @HierarchyNo
							LEFT JOIN [DimensionMember_Property] DMP4G ON DMP4G.InstanceID = 0 AND DMP4G.DimensionID = D.DimensionID AND DMP4G.MemberKey = ISNULL(DMI.[MemberKey], DMG.[MemberKey]) AND DMP4G.PropertyID = 40 + @HierarchyNo
							LEFT JOIN #HierarchyLevel HL ON LevelName = CASE WHEN @HierarchyNo = 0 THEN ISNULL(DMI.[Level], DMG.[Level]) ELSE ISNULL(DMP2I.[Value], DMP2G.[Value]) END
						WHERE
							D.DimensionID = @DimensionID AND
							(ISNULL(DMI.[MemberKey], DMG.[MemberKey]) = @MemberKey OR @MemberKey IS NULL)
						GROUP BY
							D.DimensionID,
							ISNULL(DMI.[MemberKey], DMG.[MemberKey])
						ORDER BY
							D.DimensionID,
							ISNULL(DMI.[MemberKey], DMG.[MemberKey])

	                    IF @DebugBM & 16 > 0 SELECT [Step] = 'After step: INSERT INTO #Dimension_Member', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

						IF LEN(@SQLStatement_Set) > 0
							BEGIN
								SET @SQLStatement = '
						UPDATE DM
						SET
							' + @SQLStatement_Set + '
						FROM
							#Dimension_Member DM
							INNER JOIN
							(
							SELECT
								[MemberKey] = ISNULL(DMPI.MemberKey, DMPG.MemberKey),
								' + @SQLStatement_Select + '
							FROM
								Dimension_Property DP
								LEFT JOIN DimensionMember_Property DMPI ON DMPI.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND DMPI.DimensionID = DP.DimensionID AND DMPI.PropertyID = DP.PropertyID
								LEFT JOIN DimensionMember_Property DMPG ON DMPG.InstanceID = 0 AND DMPG.DimensionID = DP.DimensionID AND DMPG.PropertyID = DP.PropertyID
							WHERE
								DP.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND
								ISNULL(DMPI.MemberKey, DMPG.MemberKey) IS NOT NULL
							GROUP BY
								ISNULL(DMPI.MemberKey, DMPG.MemberKey)
							) sub ON sub.[MemberKey] = DM.MemberKey'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
							END

	                IF @DebugBM & 16 > 0 SELECT [Step] = 'After step: UPDATE DM', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

					SET @Step = 'Update Level columns'
						IF @HierarchyView = 'Level'
							BEGIN
								IF CURSOR_STATUS('global','Level_Cursor') >= -1 DEALLOCATE Level_Cursor
								DECLARE Level_Cursor CURSOR FOR

									SELECT
										[LevelNo] = HL.LevelNo,
										[LevelName] = HL.LevelName,
										[PropertyName] = '[' + HL.PropertyName + ']',
										[PropertyNameParent] = '[' + HL1.PropertyName + ']'
									FROM
										#HierarchyLevel HL
										LEFT JOIN #HierarchyLevel HL1 ON HL1.LevelNo = HL.LevelNo - 1
									ORDER BY
										HL.LevelNo DESC

									OPEN Level_Cursor
									FETCH NEXT FROM Level_Cursor INTO @LevelNo, @LevelName, @PropertyName, @PropertyNameParent--, @Level, @Parent

									WHILE @@FETCH_STATUS = 0
										BEGIN
											IF @DebugBM & 2 > 0 SELECT LevelNo = @LevelNo, LevelName = @LevelName, PropertyName = @PropertyName, PropertyNameParent = @PropertyNameParent

											IF @LevelNo = @MaxLevelNo
												SET @SQLStatement = '
													UPDATE #Dimension_Member
													SET
														' + @PropertyName + ' = [MemberKey],
														' + @PropertyNameParent + ' = [Parent]
													WHERE
														[Level] = ''' + @LevelName + ''''
											ELSE
												SET @SQLStatement = '
													UPDATE DM
													SET
														' + @PropertyNameParent + ' = sub.' + @PropertyNameParent + '
													FROM
														#Dimension_Member DM
														INNER JOIN
															(
															SELECT
																' + @PropertyName + ' = [MemberKey],
																' + @PropertyNameParent + ' = [Parent]
															FROM
																#Dimension_Member
															WHERE
																[Level] = ''' + @LevelName + '''
															) sub ON sub.' + @PropertyName + ' = DM.' + @PropertyName + ''

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											FETCH NEXT FROM Level_Cursor INTO @LevelNo, @LevelName, @PropertyName, @PropertyNameParent--, @Level, @Parent
										END

								CLOSE Level_Cursor
								DEALLOCATE Level_Cursor
							END
	                IF @DebugBM & 16 > 0 SELECT [Step] = 'After IF @StorageTypeBM & 1 > 0  --Internal', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
					END
				ELSE IF @StorageTypeBM & 4 > 0  --Callisto
					BEGIN
						--Standard columns
						SET @SQLStatement = '
						INSERT INTO #Dimension_Member
							(
							[InstanceID],
							[DimensionID],
							[MemberID],
							[MemberKey],
							[MemberDescription],
							[HelpText],
							[NodeTypeBM],
							[SBZ],
							[Source],
							[Synchronized],
							[LevelNo],
							[Level],
							[SortOrder],
							[Parent]
							)
						SELECT
							[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
							[DimensionID] = ' + CONVERT(nvarchar(10), @DimensionID) + ',
							[MemberID] = D.[MemberID],
							[MemberKey] = D.[Label],
							[MemberDescription] = D.[Description],
							[HelpText] = D.[HelpText],
							[NodeTypeBM] = CASE D.RNodeType WHEN ''L'' THEN 1 WHEN ''P'' THEN 18 WHEN ''LC'' THEN 9 WHEN ''PC'' THEN 10 ELSE 1 END,
							[SBZ] = D.[SBZ],
							[Source] = D.[Source],
							[Synchronized] = D.[Synchronized],
							[LevelNo] = CASE WHEN H.MemberID IS NOT NULL AND (H.ParentMemberID IS NULL OR H.ParentMemberID = 0) THEN 1 END,
							[Level] = CASE ' + CONVERT(nvarchar(10), CONVERT(int, @FixedLevelsYN)) + ' WHEN 0 THEN CASE WHEN ISNULL(CASE WHEN D.RNodeType = '''' THEN NULL ELSE D.RNodeType END, ''L'') = ''L'' THEN ''Leaf'' ELSE CASE WHEN H.MemberID IS NOT NULL AND (H.ParentMemberID IS NULL OR H.ParentMemberID = 0) THEN ''TopNode'' ELSE ''Parent'' END END ELSE '''' END,
							[SortOrder] = H.SequenceNumber,
							[Parent] = DP.Label
						FROM
							' + @CallistoDatabase + '..[S_DS_' + @DimensionName + '] D
							LEFT JOIN ' + @CallistoDatabase + '..[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H ON H.MemberID = D.MemberID
							LEFT JOIN ' + @CallistoDatabase + '..[S_DS_' + @DimensionName + '] DP ON DP.MemberID = H.ParentMemberID
						WHERE
							(D.[Label] = ''' + ISNULL(@MemberKey, '') + ''' OR ''' + ISNULL(@MemberKey, 'NULL') + ''' = ''NULL'')'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
						IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension_Member_1', * FROM #Dimension_Member
	                    IF @DebugBM & 16 > 0 SELECT [Step] = 'After INSERT INTO #Dimension_Member', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

						--Dimension specific Properties
						SET @SQLStatement = '
							UPDATE DP
							SET
								PropertyName_Callisto = C.[name]
							FROM
								#Dimension_Property DP
								INNER JOIN ' + @CallistoDatabase + '.sys.tables T ON T.[name] = ''S_DS_'' + ''' + @DimensionName + '''
								INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.[object_id] = T.[object_id] AND C.[name] = REPLACE(DP.PropertyName, ''p@'', '''')'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
	                    IF @DebugBM & 16 > 0 SELECT [Step] = 'After UPDATE DP', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

						IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension_Property(UPDATE PropertyName_Callisto)', * FROM #Dimension_Property ORDER BY SortOrder, PropertyName

						SET @SQLStatement_Set = ''
						SELECT
							--Fix for FDB: FDB-1948
							--@SQLStatement_Set = @SQLStatement_Set + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + PropertyName + '] = D.[' + PropertyName_Callisto + '],'
							@SQLStatement_Set = @SQLStatement_Set + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + PropertyName + '] = ' + CASE WHEN PropertyName_Callisto = 'NodeTypeBM' THEN 'ISNULL(D.[NodeTypeBM], CASE D.[RNodeType] WHEN ''L'' THEN 1 WHEN ''P'' THEN 18 WHEN ''LC'' THEN 9 WHEN ''PC'' THEN 10 ELSE 1 END),' ELSE + 'D.[' + PropertyName_Callisto + '],' END
						FROM
							#Dimension_Property
						WHERE
							LEN(PropertyName_Callisto) > 0
						ORDER BY
							SortOrder,
							PropertyName
	                    IF @DebugBM & 16 > 0 SELECT [Step] = 'Before UPDATE DM 1', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

						IF LEN(@SQLStatement_Set) > 0
							BEGIN
								SET @SQLStatement = '
									UPDATE DM
									SET' + LEFT(@SQLStatement_Set, LEN(@SQLStatement_Set) - 1) + '
									FROM
										#Dimension_Member DM
										INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' D ON D.Label = DM.MemberKey'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
	                        IF @DebugBM & 16 > 0 SELECT [Step] = 'After UPDATE DM 1', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
							END

					--Level Names
					SET @Step = 'Update Level columns'
--SELECT 'Arne'
						--Get MAX DimensionHierarchyLevel.LevelNo from pcINTEGRATOR
						SELECT
							@HierarchyLevelNo = MAX([LevelNo])
						FROM
							[DimensionHierarchyLevel]
						WHERE
							InstanceID IN (0, @InstanceID) AND
							VersionID IN (0, @VersionID) AND
							DimensionID = @DimensionID AND
							HierarchyNo = @HierarchyNo

						--Get MAX DimensionHierarchyLevel.LevelNo from CALLISTO
						IF @EnhancedStorageYN = 0
							BEGIN
								SET @SQLStatement = '
									SELECT
										@InternalVariable = MAX(REPLACE(C.name, ''Parent_L'', ''''))
									FROM
										' + @CallistoDatabase + '.sys.tables T
										INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.name LIKE ''Parent_L%''
									WHERE
										T.name = ''HL_' + @DimensionName + '_' + @HierarchyName + ''''

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @NoOfLevels OUT
							END
						ELSE
							EXEC [spGet_NoOfLevels] @UserID=-10, @InstanceID=@InstanceID, @VersionID=@VersionID, @DimensionName = @DimensionName, @HierarchyName = @HierarchyName, @NoOfLevels = @NoOfLevels OUT, @Debug=@DebugSub

						IF @DebugBM & 2 > 0  SELECT [@HierarchyLevelNo] = @HierarchyLevelNo, [@NoOfLevels] = @NoOfLevels

						SET @SQLStatement = ''

						--Set correct MAX DimensionHierarchyLevel.LevelNo
						SELECT @HierarchyLevelNo = CASE WHEN @NoOfLevels > @HierarchyLevelNo THEN @HierarchyLevelNo ELSE @NoOfLevels END

						IF @DebugBM & 2 > 0 PRINT 'MAX @HierarchyLevelNo: ' + CONVERT(NVARCHAR(15), CASE WHEN @NoOfLevels > @HierarchyLevelNo THEN @HierarchyLevelNo ELSE @NoOfLevels END)

						SET @KeyColumn = 'Parent_L' + CONVERT(nvarchar(10), @HierarchyLevelNo)

						IF @EnhancedStorageYN <> 0
							BEGIN
								CREATE TABLE #HL_Table
									(
									[MemberId] bigint,
									[SequenceNumber] [bigint] IDENTITY(1,1)
									)

								EXEC [spGet_HL_Table] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DimensionName = @DimensionName, @HierarchyName = @HierarchyName, @NoOfLevels = @NoOfLevels, @JobID=@JobID, @Debug=@DebugSub

								IF @DebugBM & 2 > 0 SELECT TempTable = '#HL_Table', * FROM #HL_Table
							END

						WHILE @HierarchyLevelNo > 0
							BEGIN
								SELECT
									@LevelName = [LevelName]
								FROM
									[pcINTEGRATOR].[dbo].[DimensionHierarchyLevel]
								WHERE
									[InstanceID] IN (0, @InstanceID) AND
									[VersionID] IN (0, @VersionID) AND
									[DimensionID] = @DimensionID AND
									[HierarchyNo] = @HierarchyNo AND
									[LevelNo] = @HierarchyLevelNo

							IF @DebugBM & 2 > 0 PRINT '@LevelName: ' + @LevelName

							IF @HierarchyView = 'Level'
								SET @SQLStatement = '
									UPDATE DM
									SET
										[' + CONVERT(nvarchar(10), @HierarchyLevelNo) + '@' + @LevelName + '] = DN.Label
									FROM
										' + CASE WHEN @EnhancedStorageYN <> 0 THEN '#HL_Table HL' ELSE @CallistoDatabase + '..[HL_' + @DimensionName + '_' + @HierarchyName + '] HL' END + '
										INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' DJ ON DJ.MemberID = HL.' + @KeyColumn + '
										INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' DN ON DN.MemberID = HL.Parent_L' + CONVERT(nvarchar(10), @HierarchyLevelNo) + '
										INNER JOIN #Dimension_Member DM ON DM.MemberKey = DJ.Label'

							ELSE IF @FixedLevelsYN <> 0
								SET @SQLStatement = '
									UPDATE DM
									SET
										DM.Level = CASE WHEN DM.NodeTypeBM & 1 > 0  AND ' + CONVERT(nvarchar(10), @HierarchyLevelNo) + ' <> ' + CONVERT(nvarchar(10), @MaxLevelNo) + ' THEN DM.Level ELSE ''' + @LevelName + ''' END
									FROM
										' + CASE WHEN @EnhancedStorageYN <> 0 THEN '#HL_Table HL' ELSE @CallistoDatabase + '..[HL_' + @DimensionName + '_' + @HierarchyName + '] HL' END + '
										INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' DN ON DN.MemberID = HL.Parent_L' + CONVERT(nvarchar(10), @HierarchyLevelNo) + '
										INNER JOIN #Dimension_Member DM ON DM.MemberKey = DN.Label'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
	                        IF @DebugBM & 16 > 0 SELECT [Step] = 'After UPDATE DM 2', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

							SET @HierarchyLevelNo = @HierarchyLevelNo - 1
						END
	                    IF @DebugBM & 16 > 0 SELECT [Step] = 'After ELSE IF @StorageTypeBM & 4 > 0  --Callisto', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
					END
				IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension_Member_2', * FROM #Dimension_Member
			END

	IF @DebugBM & 16 > 0 SELECT [Step] = 'After step: ' + @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = '@ResultTypeBM & 4'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					@SQLStatement_Return = @SQLStatement_Return + CASE PropertyName WHEN 'SortOrder' THEN '[' + PropertyName + '] = [' + PropertyName + '] % 1000000,' WHEN 'Parent' THEN '[Parent] = ISNULL(Parent, CASE WHEN LevelNo = 1 THEN ''TopNode'' END),' ELSE '[' + PropertyName + '],' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
				FROM
					#Dimension_Property
				WHERE
					SortOrder > 0 AND
					(PropertyID NOT IN (3, 10, 11) OR @HierarchyView = 'Parent')
				ORDER BY
					SortOrder,
					PropertyName

				SET @SQLStatement_Return = LEFT(@SQLStatement_Return, LEN(@SQLStatement_Return) - 7)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension_Member_4', * FROM #Dimension_Member ORDER BY MemberId

				--SET @SQLStatement = '
				--	SELECT
				--		ResultTypeBM = 4,
				--		' + @SQLStatement_Return + '
				--	FROM
				--		#Dimension_Member DM
				--	WHERE
				--		DM.NodeTypeBM & ' + CASE WHEN @HierarchyView = 'Level' THEN '1' ELSE '255' END + ' > 0
				--	ORDER BY
				--		ISNULL(DM.SortOrder, 99999999)'

				--FIX for FPA-135: WHERE clause, change to NodeTypeBM 1279 (255 + 1024) for @HierarchyView <> 'Level'
				SET @SQLStatement = '
					SELECT
						ResultTypeBM = 4,
						' + @SQLStatement_Return + '
					FROM
						#Dimension_Member DM
					WHERE
						DM.NodeTypeBM & ' + CASE WHEN @HierarchyView = 'Level' THEN '1' ELSE '1279' END + ' > 0
					ORDER BY
						ISNULL(DM.SortOrder, 99999999)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	IF @DebugBM & 16 > 0 SELECT [Step] = 'After step: ' + @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = '@ResultTypeBM & 8'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				CREATE TABLE #Dimension_MemberID_List
					(
					Dimension_MemberID BIGINT
					)

				--1. Add all unique Dimension MemberIDs existing from DataClass FACT tables (Leaf Members)
				IF CURSOR_STATUS('global','DataClassDim_Cursor') >= -1 DEALLOCATE DataClassDim_Cursor
					DECLARE DataClassDim_Cursor CURSOR FOR
						SELECT
							DC.[DataClassID],
							DC.[DataClassName],
							DC.[StorageTypeBM],
							D.[DimensionName]
						FROM
							DataClass_Dimension DCD
							INNER JOIN DataClass DC ON DC.DataClassID = DCD.DataClassID AND DC.SelectYN <> 0
							INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND DimensionTypeID <> 27
						WHERE
							DCD.InstanceID = @InstanceID AND
							DCD.VersionID = @VersionID AND
							DCD.DimensionID = @DimensionID

						OPEN DataClassDim_Cursor
						FETCH NEXT FROM DataClassDim_Cursor INTO @DataClassID, @DataClassName, @DataClass_StorageTypeBM, @DimensionName

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@DataClassID] = @DataClassID, [@DataClassName] = @DataClassName, [@DataClass_StorageTypeBM] = @DataClass_StorageTypeBM, [@DimensionName] = @DimensionName

								IF @DataClass_StorageTypeBM & 4 > 0  --Callisto
									BEGIN
										SET @SQLStatement = '
											INSERT INTO #Dimension_MemberID_List
												(
												Dimension_MemberID
												)
											SELECT DISTINCT
												[Dimension_MemberID] = ' + @DimensionName+ '_MemberId
											FROM
												' + @CallistoDatabase + '.dbo.FACT_' + @DataClassName+ '_default_partition F WITH (NOLOCK)'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
									END

								FETCH NEXT FROM DataClassDim_Cursor INTO @DataClassID, @DataClassName, @DataClass_StorageTypeBM, @DimensionName
							END

					CLOSE DataClassDim_Cursor
					DEALLOCATE DataClassDim_Cursor

				--2. Add all unique Dimension MemberIDs existing from Dimension Hierarchy tables (Parent Members)
				IF CURSOR_STATUS('global','HierarchyDim_Cursor') >= -1 DEALLOCATE HierarchyDim_Cursor
					DECLARE HierarchyDim_Cursor CURSOR FOR
						SELECT DISTINCT
							DH.HierarchyName,
							D.DimensionName
						FROM
							DimensionHierarchy DH
							INNER JOIN Dimension D ON D.DimensionID = DH.DimensionID
						WHERE
							DH.InstanceID IN (0, @InstanceID) AND
							DH.VersionID IN (0, @VersionID) AND
							DH.DimensionID = @DimensionID

						OPEN HierarchyDim_Cursor
						FETCH NEXT FROM HierarchyDim_Cursor INTO @HierarchyName, @DimensionName

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@HierarchyName] = @HierarchyName, [@DimensionName] = @DimensionName, [@StorageTypeBM] = @StorageTypeBM

								IF @StorageTypeBM & 4 > 0 AND @EnhancedStorageYN = 0 --Callisto
									BEGIN
										SET @SQLStatement = '
											INSERT INTO #Dimension_MemberID_List
												(
												Dimension_MemberID
												)
											SELECT DISTINCT
												[Dimension_MemberID] = H.MemberId
											FROM
												' + @CallistoDatabase + '.dbo.[HS_' + @DimensionName+ '_' + @HierarchyName + '] H
												INNER JOIN ' + @CallistoDatabase + '.dbo.[O_HS_' + @DimensionName+ '_' + @HierarchyName + '] OH ON OH.MemberId = H.MemberId'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
									END

								FETCH NEXT FROM HierarchyDim_Cursor INTO @HierarchyName, @DimensionName
							END

					CLOSE HierarchyDim_Cursor
					DEALLOCATE HierarchyDim_Cursor

				--3. Add all existing members from [Member] table (System/Locked Members)
				INSERT INTO #Dimension_MemberID_List
					(
					Dimension_MemberID
					)
				SELECT DISTINCT
					[Dimension_MemberID] = MemberId
				FROM
					Member
				WHERE
					DimensionID = @DimensionID

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Dimension_MemberID_List', * FROM #Dimension_MemberID_List

				--4. Return Dimension Members possible for deletion (not existing from FACT, Hierarchies & Member tables)
				CREATE TABLE #MembersForDeletion
					(
					ResultTypeBM int,
					InstanceID int,
					DimensionID int,
					DimensionName nvarchar(100),
					MemberID bigint,
					MemberKey nvarchar(255) COLLATE DATABASE_DEFAULT,
					MemberDescription nvarchar(512) COLLATE DATABASE_DEFAULT
					)

				IF @StorageTypeBM & 4 > 0  --Callisto
					BEGIN
						SELECT
							@DimensionName = DimensionName
						FROM
							Dimension
						WHERE
							InstanceID IN (0, @InstanceID) AND
							DimensionID = @DimensionID

						SET @SQLStatement = '
							INSERT INTO #MembersForDeletion
								(
								ResultTypeBM,
								InstanceID,
								DimensionID,
								DimensionName,
								MemberID,
								MemberKey,
								MemberDescription
								)
							SELECT
								[ResultTypeBM] = 8,
								[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID) + ',
								[DimensionID] = ' + CONVERT(NVARCHAR(15), @DimensionID) + ',
								[DimensionName] = ''' + @DimensionName + ''',
								[MemberID] = D.[MemberID],
								[MemberKey] = D.[Label],
								[MemberDescription] = D.[Description]
							FROM
								' + @CallistoDatabase + '.dbo.S_DS_' + @DimensionName + ' D
							WHERE
								D.[Label] NOT IN (''All'',''NONE'',''pcPlaceHolder'',''ToBeSet'') AND
								NOT EXISTS (SELECT 1 FROM #Dimension_MemberID_List DML WHERE DML.Dimension_MemberID = D.MemberId)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END

				--Return rows
				SELECT * FROM #MembersForDeletion
			END

	IF @DebugBM & 16 > 0 SELECT [Step] = 'After step: ' + @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = '@ResultTypeBM & 16'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT
					ResultTypeBM = 16,
					Property = 'MemberId',
					NodeTypeBM = 3,
					LockedYN = 1,
					InvisibleYN = CASE WHEN @ObjectGuiBehaviorBM & 2 > 0 THEN 0 ELSE 1 END
				UNION SELECT
					ResultTypeBM = 16,
					Property = 'NodeTypeBM',
					NodeTypeBM = 1024,
					LockedYN = 1,
					InvisibleYN = 1
				UNION SELECT
					ResultTypeBM = 16,
					Property = 'SortOrder',
					NodeTypeBM = 3,
					LockedYN = 1,
					InvisibleYN = CASE WHEN @ObjectGuiBehaviorBM & 2 > 0 THEN 0 ELSE 1 END
			END

	IF @DebugBM & 16 > 0 SELECT [Step] = 'After step: ' + @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Drop temp tables'
		DROP TABLE #Dimension_Property
		IF @ResultTypeBM & 4 > 0 DROP TABLE #Dimension_Member
		IF @ResultTypeBM & 8 > 0
			BEGIN
				DROP TABLE #Dimension_MemberID_List
				DROP TABLE #MembersForDeletion
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
