SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_DimensionMember]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DimensionID int = NULL,
	@MemberKey nvarchar(100) = NULL,
	@MemberDescription nvarchar(255) = NULL,
	@HelpText nvarchar(1024) = NULL,
	@NodeTypeBM int = NULL,
	@SBZ bit = NULL,
	@Source nvarchar(50) = NULL,
	@Synchronized bit = NULL,
	@Level nvarchar(50) = NULL,	--SortOrder is only changed when @Level is not passed in call (@Level IS NULL)
	@SortOrder int = NULL,
	@Parent nvarchar(100) = NULL,
	@MemberKey_Above nvarchar(100) = NULL,
	@Property nvarchar(max) = NULL,
	@HierarchyNo int = 0,
	@HierarchyView nvarchar(10) = 'Parent', --'Parent' or 'Level'
	@DeleteYN bit = 0,
	@ReturnMemberIdYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000166,
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
EXEC [spPortalSet_DimensionMember]  
	@UserID='2106', 
	@InstanceID=16, 
	@DimensionID=-4, 
	@MemberKey='NewMemberKey', 
	@MemberDescription='NewMemberDescription', 
	@HelpText='SomeHelpText', 
	@NodeTypeBM=1, 
	@SBZ=0, 
	@Source='Grid',  
	@Synchronized=0, 
	@Property='', 
	@HierarchyNo=1, 
	@HierarchyView='Level'

EXEC [spPortalSet_DimensionMember]  
	@UserID='-10', 
	@InstanceID=413, 
	@VersionID=1008,
	@DimensionID=-1, 
	@MemberKey='219199', 
	@Property='p@Rate=History'

EXEC [spPortalSet_DimensionMember] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(max),
	@SQLSet nvarchar(max) = '',
	@StringLength int,
	@Position int = 0,
	@Position_Variable int,
	@TypeStart int,
	@TypeLen int,
	@NameStart int,
	@NameLen int,
	@ValueStart int,
	@ValueLen int,
	@LevelNo int,
	@MaxLevelNo int,
	@Child nvarchar(50),
	@StorageTypeBM int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@DimensionName nvarchar(100),
	@HierarchyName nvarchar(50),
	@FixedLevelsYN bit,
	@MemberId bigint,
	@ParentName nvarchar(50),
	@LevelName nvarchar(50),
	@OTable nvarchar(100),
	@STable nvarchar(100),
	@PropertyName nvarchar(100),
	@DependentDimensionName nvarchar(100),
	@ApplicationID int,
	@AccountType_MemberKey nvarchar(100),
	@Account_Type nvarchar(50),
	@Rate nvarchar(50),
	@Sign nvarchar(10),
	@TimeBalance nvarchar(10),
	@AboveMemberId bigint,
	@SequenceNumber int,
	@NodeTypeBM_ExistYN bit = 0,
	@EnhancedStorageYN bit,

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set DimensionMember',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2135' SET @Description = 'Handle properties and hierarchies.'
		IF @Version = '1.4.0.2139' SET @Description = 'Handle Callisto.'
		IF @Version = '2.0.0.2140' SET @Description = 'Fixed bug, remove from hierarchy'
		IF @Version = '2.0.0.2142' SET @Description = 'Removed space cleaning from property values.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data]. Removed space cleaning from property values.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-294: Removed references to Property.DimensionID.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-432: Update #Hierarchy only when @MemberKey_Above IS NOT NULL.'
		IF @Version = '2.0.3.2154' SET @Description = 'Clear cache [pcINTEGRATOR_Log].[dbo].[wrk_LeafLevelFilter] when change dimension table. DB-427: Adding VersionID to tables DimensionHierarchy, DimensionHierarchyLevel & Dimension_Property.'
		IF @Version = '2.1.0.2158' SET @Description = 'Clear cache by using SP [spSet_Clear_LeafLevelFilter_Cache].'
		IF @Version = '2.1.0.2162' SET @Description = 'DB-547: Return MemberId of @MemberKey. Make return optional.'
		IF @Version = '2.1.1.2168' SET @Description = 'Test on existing rows in temp table #PropertyValue to avoid duplicates with the same PropertyID.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle @Property with pipe (|) in the string that should be stored. Filter on existing Properties. Length of PropertyValue column increased from nvarchar(100) to nvarchar(max). Changed clear cache to [spSet_LeafLevelFilter_ClearCache].'
		IF @Version = '2.1.1.2173' SET @Description = 'Added "NOT EXISTS" test on inserting new rows into hierarchy tables' 
		IF @Version = '2.1.1.2174' SET @Description = 'Set MemberID to 0 for not existing Members in MemberProperties. (Mainly used to handle Blank)' 
		IF @Version = '2.1.1.2177' SET @Description = 'Instance and Version filter on Property and Dimension_Property added when joining by name (sys.tables). Handle existance of NodeTypeBM.' 
		IF @Version = '2.1.2.2191' SET @Description = 'Handle Enhanced Storage'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID

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

		SET @Property = CASE WHEN @Property = '' THEN NULL ELSE @Property END

		SELECT
			@LevelNo = MAX(ISNULL(DHLI.LevelNo, DHLG.LevelNo))
		FROM
			Dimension D
			LEFT JOIN DimensionHierarchyLevel DHLI ON DHLI.InstanceID = @InstanceID AND DHLI.VersionID = @VersionID AND DHLI.DimensionID = D.DimensionID AND DHLI.HierarchyNo = @HierarchyNo AND DHLI.LevelName = @Level
			LEFT JOIN DimensionHierarchyLevel DHLG ON DHLG.InstanceID = 0 AND DHLG.VersionID = 0 AND DHLG.DimensionID = D.DimensionID AND DHLG.HierarchyNo = @HierarchyNo AND DHLG.LevelName = @Level
		WHERE
			D.DimensionID = @DimensionID
		GROUP BY
			D.DimensionID

		SELECT
			@MaxLevelNo = MAX(ISNULL(DHLI.LevelNo, DHLG.LevelNo))
		FROM
			Dimension D
			LEFT JOIN DimensionHierarchyLevel DHLI ON DHLI.InstanceID = @InstanceID AND DHLI.VersionID = @VersionID AND DHLI.DimensionID = D.DimensionID AND DHLI.HierarchyNo = @HierarchyNo
			LEFT JOIN DimensionHierarchyLevel DHLG ON DHLG.InstanceID = 0 AND DHLG.VersionID = 0 AND DHLG.DimensionID = D.DimensionID AND DHLG.HierarchyNo = @HierarchyNo
		WHERE
			D.DimensionID = @DimensionID
		GROUP BY
			D.DimensionID

		SELECT
			@StorageTypeBM = StorageTypeBM
		FROM
			[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @Debug <> 0 SELECT [@LevelNo] = @LevelNo, [@MaxLevelNo] = @MaxLevelNo, [@StorageTypeBM] = @StorageTypeBM, [@Property]=@Property --SortOrder = @SortOrder, 

		IF @StorageTypeBM IS NULL
			BEGIN
				SET @Message = 'StorageTypeBM is not defined for InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ', VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' and DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + '. Must be defined in table pcINTEGRATOR.dbo.Dimension_StorageType'
				SET @Severity = 16
				GOTO EXITPOINT
			END

		IF @StorageTypeBM & 4 > 0
			BEGIN
				SELECT
					@DimensionName = DimensionName
				FROM
					Dimension
				WHERE
					InstanceID IN (0, @InstanceID) AND
					DimensionID = @DimensionID

				SELECT
					@ApplicationID = ISNULL(@ApplicationID , MAX(A.[ApplicationID])),
					@EnhancedStorageYN = MAX(CONVERT(int, A.[EnhancedStorageYN]))
				FROM
					[Application] A
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

				SET @SQLStatement = '
					SELECT
						@InternalVariable = COUNT(1)
					FROM
						' + @CallistoDatabase + '.sys.tables t
						INNER JOIN ' + @CallistoDatabase + '.sys.columns c ON c.object_id = t.object_id AND c.[name] = ''NodeTypeBM''
					WHERE
						t.[name] = ''S_DS_' + @DimensionName + ''''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC sp_executesql @SQLStatement, N'@InternalVariable bit OUT', @InternalVariable = @NodeTypeBM_ExistYN OUT
				
				IF @Debug <> 0 
					SELECT
						[@DimensionName] = @DimensionName, 
						[@HierarchyName] = @HierarchyName,
						[@ApplicationID] = @ApplicationID,
						[@DestinationDatabase] = @CallistoDatabase,
						[@ETLDatabase] = @ETLDatabase,
						[@FixedLevelsYN] = @FixedLevelsYN,
						[@NodeTypeBM_ExistYN] = @NodeTypeBM_ExistYN
			END

	SET @Step = 'Handle @Properties, fill #PropertyValue'
		IF @Property IS NOT NULL AND LEN(@Property) <> 0
			BEGIN
				CREATE TABLE #PropertyValue
					(
					MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT,
					PropertyType nchar(1) COLLATE DATABASE_DEFAULT,
					PropertyID int,
					PropertyName nvarchar(100) COLLATE DATABASE_DEFAULT,
					PropertyValue nvarchar(max) COLLATE DATABASE_DEFAULT,
					DependentDimensionName nvarchar(100) COLLATE DATABASE_DEFAULT,
					SelectYN bit DEFAULT(1)
					)

				SET @StringLength = LEN(@Property)

				WHILE @Position < @StringLength
					BEGIN
						SET @Position = @Position + 1
						SET @Position_Variable = CHARINDEX ('@', @Property, @Position) 
						IF @Position_Variable > 0
							BEGIN
								SELECT
									@TypeStart = @Position_Variable - 1,
									@TypeLen = 1,
									@NameStart = @Position_Variable + 1,
									@NameLen = CHARINDEX('=', @Property, @Position_Variable) - (@Position_Variable + 1),
									@ValueStart = CHARINDEX('=', @Property, @Position_Variable) + 1,
									@ValueLen = CASE WHEN CHARINDEX('|p@', @Property, @Position_Variable) = 0 THEN @StringLength - CHARINDEX('=', @Property, @Position_Variable) ELSE CHARINDEX('|', @Property, @Position_Variable) - (CHARINDEX('=', @Property, @Position_Variable) + 1) END

								IF @Debug <> 0
									SELECT
										[@Property] = @Property,
										[@StringLength] = @StringLength,
										[@Position] = @Position,
										[@Position_Variable] = @Position_Variable, 
										[@TypeStart] = @TypeStart,
										[@TypeLen] = @TypeLen,
										[@NameStart] = @NameStart,
										[@NameLen] = @NameLen,
										[@ValueStart] = @ValueStart,
										[@ValueLen] = @ValueLen,
										[@PropertyType] = SUBSTRING(@Property, @TypeStart, @TypeLen),
										[@PropertyName] = REPLACE(SUBSTRING(@Property, @NameStart, @NameLen), ' ', ''),
										[@PropertyValue] = REPLACE(SUBSTRING(@Property, @ValueStart, @ValueLen), '''', '')

								INSERT INTO #PropertyValue
									(
									MemberKey,
									PropertyType,
									PropertyName,
									PropertyValue
									)
								SELECT
									MemberKey = @MemberKey,
									PropertyType = SUBSTRING(@Property, @TypeStart, @TypeLen),
									PropertyName = REPLACE(SUBSTRING(@Property, @NameStart, @NameLen), ' ', ''),
									PropertyValue = REPLACE(SUBSTRING(@Property, @ValueStart, @ValueLen), '''', '')
								
								SET @Position_Variable = CHARINDEX('|', @Property, @Position + CHARINDEX('=', @Property, @Position_Variable) - (@Position_Variable + 1))
								SET @Position = CASE WHEN @Position_Variable > 0 THEN @Position_Variable ELSE @StringLength END
							END
						ELSE
							SET @Position = @StringLength
					END

				UPDATE PV
				SET
					PropertyID = P.PropertyID
				FROM
					#PropertyValue PV
					INNER JOIN Property P ON P.PropertyName = PV.PropertyName
					INNER JOIN Dimension_Property DP ON DP.InstanceID IN (0, @InstanceID) AND DP.DimensionID = @DimensionID AND DP.PropertyID = P.PropertyID

				IF @HierarchyNo <> 0 AND @HierarchyView = 'Parent'
					INSERT INTO #PropertyValue
						(
						MemberKey,
						PropertyType,
						PropertyID,
						PropertyName,
						PropertyValue
						)
					SELECT
						MemberKey = @MemberKey,
						PropertyType = CONVERT(nvarchar(1), @HierarchyNo),
						PropertyID = 20 + @HierarchyNo,
						PropertyName = 'Level0' + CONVERT(nvarchar(1), @HierarchyNo),
						PropertyValue = @Level
					UNION
					SELECT
						MemberKey = @MemberKey,
						PropertyType = CONVERT(nvarchar(1), @HierarchyNo),
						PropertyID = 30 + @HierarchyNo,
						PropertyName = 'SortOrder0' + CONVERT(nvarchar(1), @HierarchyNo),
						PropertyValue = CONVERT(nvarchar(10), @SortOrder)
					UNION
					SELECT
						MemberKey = @MemberKey,
						PropertyType = CONVERT(nvarchar(1), @HierarchyNo),
						PropertyID = 40 + @HierarchyNo,
						PropertyName = 'Parent0' + CONVERT(nvarchar(1), @HierarchyNo),
						PropertyValue = @Parent

				IF (SELECT COUNT(1) FROM #PropertyValue WHERE PropertyName = 'AccountType') > 0
					BEGIN
						SELECT @AccountType_MemberKey = PropertyValue FROM #PropertyValue WHERE PropertyName = 'AccountType'
						
						CREATE TABLE #AccountType
							(
							ResultTypeBM int,
							MemberID int,
							MemberKey nvarchar(100),
							MemberDescription nvarchar(255),
							HelpText nvarchar(1024),
							[p@Account Type] nvarchar(50),
							[p@Rate] nvarchar(50),
							[p@Sign] int,
							[p@TimeBalance] int,
							NodeTypeBM int,
							SBZ bit,
							[Source] nvarchar(50),
							Synchronized bit,
							[Level] nvarchar(50),
							SortOrder int,
							Parent nvarchar(100)
							)

						INSERT INTO #AccountType EXEC [spPortalGet_DimensionMember] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = -62, @HierarchyView = 'Parent',  @ObjectGuiBehaviorBM = 7, @MemberKey = @AccountType_MemberKey

						SELECT
							@Account_Type = [p@Account Type],
							@Rate = [p@Rate],
							@Sign = [p@Sign],
							@TimeBalance = [p@TimeBalance]
						FROM
							#AccountType

						IF @Debug <> 0
							SELECT
								[Account_Type] = @Account_Type,
								[Rate] = @Rate,
								[Sign] = @Sign,
								[TimeBalance] = @TimeBalance

						DELETE #PropertyValue
						WHERE PropertyID IN (-4, -5, -7, -8)

						INSERT INTO #PropertyValue
							(
							MemberKey,
							PropertyType,
							PropertyID,
							PropertyName,
							PropertyValue
							)
						SELECT
							MemberKey = @MemberKey,
							PropertyType = 'p',
							PropertyID = -4,
							PropertyName = 'Account Type',
							PropertyValue = @Account_Type
						UNION
						SELECT
							MemberKey = @MemberKey,
							PropertyType = 'p',
							PropertyID = -5,
							PropertyName = 'Rate',
							PropertyValue = @Rate
						UNION
						SELECT
							MemberKey = @MemberKey,
							PropertyType = 'p',
							PropertyID = -7,
							PropertyName = 'Sign',
							PropertyValue = @Sign
						UNION
						SELECT
							MemberKey = @MemberKey,
							PropertyType = 'p',
							PropertyID = -8,
							PropertyName = 'TimeBalance',
							PropertyValue = @TimeBalance
					
						DROP TABLE #AccountType
					END

				UPDATE PV
				SET
					SelectYN = CASE WHEN sub.PropertyID IS NULL THEN 0 ELSE PV.PropertyID END
				FROM 
					#PropertyValue PV
					LEFT JOIN
					(
						SELECT
							P.PropertyID
						FROM
							pcINTEGRATOR..Property P
							INNER JOIN pcINTEGRATOR..Dimension_Property DP ON DP.InstanceID IN (0, @InstanceID) AND DP.VersionID IN (0, @VersionID) AND DP.PropertyID = P.PropertyID AND DP.DimensionID = @DimensionID AND DP.SelectYN <> 0
						WHERE
							P.InstanceID IN (0, @InstanceID) AND
							P.SelectYN <> 0
					) sub ON sub.PropertyID = PV.PropertyID
				WHERE
					PV.PropertyType = 'P'

				IF @Debug <> 0 SELECT TempTable = '#PropertyValue_1', * FROM #PropertyValue
			END

	SET @Step = 'Create temp table #Dimension_Member'	
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
				[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[ParentMemberId] int,
				[MemberKey_Above] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[AboveMemberId] int
				)

		IF @HierarchyView = 'Level'
			BEGIN
	SET @Step = 'Handle @HierarchyView = Level'	
				CREATE TABLE #ParentChild
					(
					[Child] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Parent] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Level] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[LevelNo] int
					)

				SET @Child = @MemberKey

				IF @Property IS NOT NULL AND LEN(@Property) <> 0
					BEGIN
						DECLARE Level_Cursor CURSOR FOR
							SELECT
								[ParentName] = PropertyValue,
								[LevelName] = PropertyName,
								[LevelNo] = CONVERT(int, PropertyType)
							FROM
								#PropertyValue
							WHERE
								ISNUMERIC(PropertyType) <> 0
							ORDER BY
								PropertyType DESC

							OPEN Level_Cursor
							FETCH NEXT FROM Level_Cursor INTO @ParentName, @LevelName, @LevelNo

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @Debug <> 0 SELECT Child = @Child, ParentName = @ParentName, [LevelName] = @LevelName, LevelNo = @LevelNo

									UPDATE #ParentChild
									SET
										Parent = @ParentName
									WHERE
										Child = @Child

									INSERT INTO #ParentChild
										(
										Child,
										[Level],
										LevelNo
										)
									SELECT
										Child = @ParentName,
										[Level] = @LevelName,
										LevelNo = @LevelNo 

									SET @Child = @ParentName

									FETCH NEXT FROM Level_Cursor INTO @ParentName, @LevelName, @LevelNo
								END

						CLOSE Level_Cursor
						DEALLOCATE Level_Cursor
					END

				UPDATE #ParentChild
				SET
					Parent = 'TopNode'
				WHERE
					[LevelNo] = 1

				IF @Debug <> 0 SELECT TempTable = '#ParentChild', * FROM #ParentChild

				INSERT INTO [#Dimension_Member]
					(
					[InstanceID],
					[DimensionID],
					[MemberKey],
					[MemberDescription],
					[HelpText],
					[NodeTypeBM],
					[SBZ],
					[Source],
					[Synchronized],
					[LevelNo],
					[Level],
					[Parent],
					[MemberKey_Above]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[DimensionID] = @DimensionID,
					[MemberKey] = PC.Child,
					[MemberDescription] = CASE WHEN PC.Child = @MemberKey THEN @MemberDescription ELSE NULL END,
					[HelpText] = CASE WHEN PC.Child = @MemberKey THEN @HelpText ELSE NULL END,
					[NodeTypeBM] = CASE WHEN PC.Child = @MemberKey THEN @NodeTypeBM ELSE CASE WHEN PC.LevelNo = @MaxLevelNo THEN 1 ELSE NULL END END,
					[SBZ] = CASE WHEN PC.Child = @MemberKey THEN @SBZ ELSE CASE WHEN PC.LevelNo = @MaxLevelNo THEN 0 ELSE 1 END END,
					[Source] = @Source,
					[Synchronized] = @Synchronized,
					[LevelNo] = PC.[LevelNo],
					[Level] = PC.[Level],
					[Parent] = PC.Parent,
					[MemberKey_Above] = NULL
				FROM
					#ParentChild PC

				IF @HierarchyNo <> 0 AND @HierarchyView = 'Level'
					INSERT INTO #PropertyValue
						(
						MemberKey,
						PropertyType,
						PropertyID,
						PropertyName,
						PropertyValue
						)
					SELECT
						MemberKey = PC.Child,
						PropertyType = CONVERT(nvarchar(1), @HierarchyNo),
						PropertyID = 20 + @HierarchyNo,
						PropertyName = 'Level0' + CONVERT(nvarchar(1), @HierarchyNo),
						PropertyValue = PC.[Level]
					FROM
						#ParentChild PC
					UNION
					SELECT
						MemberKey = PC.Child,
						PropertyType = CONVERT(nvarchar(1), @HierarchyNo),
						PropertyID = 30 + @HierarchyNo,
						PropertyName = 'SortOrder0' + CONVERT(nvarchar(1), @HierarchyNo),
						PropertyValue = CONVERT(nvarchar(10), 100000000 + PC.LevelNo * 1000000 + 10)
					FROM
						#ParentChild PC
					UNION
					SELECT
						MemberKey = PC.Child,
						PropertyType = CONVERT(nvarchar(1), @HierarchyNo),
						PropertyID = 40 + @HierarchyNo,
						PropertyName = 'Parent0' + CONVERT(nvarchar(1), @HierarchyNo),
						PropertyValue = PC.Parent
					FROM
						#ParentChild PC

				IF @Debug <> 0 SELECT TempTable = '#PropertyValue', * FROM #PropertyValue
			END


		ELSE IF @HierarchyView = 'Parent'
			BEGIN
	SET @Step = 'Handle @HierarchyView = Parent'
				SELECT
					@LevelNo = LevelNo
				FROM
					DimensionHierarchyLevel DHL
					INNER JOIN (SELECT InstanceID = MAX(InstanceID) FROM DimensionHierarchyLevel WHERE InstanceID IN (0, @InstanceID) AND VersionID IN (0, @VersionID) AND DimensionID = @DimensionID AND HierarchyNo = @HierarchyNo) I ON I.InstanceID = DHL.InstanceID
				WHERE
					DHL.InstanceID IN (0, @InstanceID) AND
					DHL.VersionID IN (0, @VersionID) AND
					DHL.DimensionID = @DimensionID AND
					DHL.HierarchyNo = @HierarchyNo AND
					DHL.LevelName = @Level

				SET @LevelNo = ISNULL(@LevelNo, @MaxLevelNo)
				
				SELECT
					@LevelName = ISNULL(@Level, LevelName)
				FROM
					DimensionHierarchyLevel DHL
					INNER JOIN (SELECT InstanceID = MAX(InstanceID) FROM DimensionHierarchyLevel WHERE InstanceID IN (0, @InstanceID) AND VersionID IN (0, @VersionID) AND DimensionID = @DimensionID AND HierarchyNo = @HierarchyNo) I ON I.InstanceID = DHL.InstanceID
				WHERE
					DHL.InstanceID IN (0, @InstanceID) AND
					DHL.VersionID IN (0, @VersionID) AND
					DHL.DimensionID = @DimensionID AND
					DHL.HierarchyNo = @HierarchyNo AND
					DHL.LevelNo = @LevelNo

				IF @Debug <> 0 SELECT LevelNo = @LevelNo, LevelName = @LevelName
					
				INSERT INTO [#Dimension_Member]
					(
					[InstanceID],
					[DimensionID],
					[MemberKey],
					[MemberDescription],
					[HelpText],
					[NodeTypeBM],
					[SBZ],
					[Source],
					[Synchronized],
					[LevelNo],
					[Level],
					[Parent],
					[MemberKey_Above]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[DimensionID] = @DimensionID,
					[MemberKey] = @MemberKey,
					[MemberDescription] = @MemberDescription,
					[HelpText] = @HelpText,
					[NodeTypeBM] = @NodeTypeBM,
					[SBZ] = @SBZ,
					[Source] = @Source,
					[Synchronized] = @Synchronized,
					[LevelNo] = @LevelNo, 
					[Level] = @LevelName,
					[Parent] = @Parent,
					[MemberKey_Above] = @MemberKey_Above
			END
		
		IF @StorageTypeBM & 1 > 0
			BEGIN
				IF @Debug <> 0 SELECT TempTable = '#Dimension_Member', * FROM [#Dimension_Member]
	SET @Step = '@StorageTypeBM = 1, UPDATE'	 
				IF @DeleteYN = 0
					BEGIN
						UPDATE DMD
						SET
							[MemberDescription] = ISNULL(DM.MemberDescription, DMD.[MemberDescription]),
							[HelpText] = ISNULL(DM.HelpText, DMD.[HelpText]),
							[NodeTypeBM] = ISNULL(DM.NodeTypeBM, DMD.[NodeTypeBM]),
							[SBZ] = ISNULL(DM.SBZ, DMD.[SBZ]),
							[Source] = ISNULL(DM.Source, DMD.[Source]),
							[Synchronized] = ISNULL(DM.Synchronized, DMD.[Synchronized]),
							[Level] = ISNULL(CASE WHEN @HierarchyNo = 0 THEN ISNULL(DM.[Level], DMD.[Level]) ELSE NULL END, DMD.[Level]),
							[Parent] = ISNULL(CASE WHEN @HierarchyNo = 0 THEN ISNULL(DM.Parent, DMD.[Parent]) ELSE NULL END, DMD.[Parent])
						FROM
							[pcINTEGRATOR_Data].[dbo].[DimensionMember] DMD
							INNER JOIN [#Dimension_Member] DM ON 
								DM.[InstanceID] = DMD.InstanceID AND
								DM.DimensionID = DMD.DimensionID AND
								DM.MemberKey = DMD.MemberKey

						SET @Updated = @Updated + @@ROWCOUNT

						IF @Debug <> 0 SELECT Updated = @Updated

						IF @Property IS NOT NULL AND LEN(@Property) <> 0
							UPDATE DMP
							SET
								[Value] = CASE WHEN @HierarchyNo <> 0 AND PV.PropertyID / 10 % 10 = 3 AND @HierarchyView = 'Level' AND DMP.[Value] % 1000000 <> 10 THEN DMP.[Value] ELSE PV.[PropertyValue] END
							FROM
								[pcINTEGRATOR_Data].[dbo].[DimensionMember_Property] DMP
								INNER JOIN #PropertyValue PV ON PV.PropertyID = DMP.PropertyID AND PV.MemberKey = DMP.MemberKey
							WHERE
								(ISNUMERIC(PV.PropertyType) = 0 OR @HierarchyView = 'Parent') AND
								DMP.InstanceID = @InstanceID AND
								DMP.DimensionID = @DimensionID AND
								DMP.MemberKey = @MemberKey
					END

	SET @Step = '@StorageTypeBM = 1, INSERT'	
				IF @DeleteYN = 0
					BEGIN
						IF @Debug <> 0 
							BEGIN
								SELECT TempTable = '#Dimension_Member', Step = '@StorageTypeBM = 1, INSERT', * FROM [#Dimension_Member]
								SELECT
									[InstanceID] = DM.InstanceID,
									[DimensionID] = DM.DimensionID,
									[MemberKey] = DM.MemberKey,
									[MemberDescription] = ISNULL(DM.MemberDescription, DM.MemberKey),
									[HelpText] = COALESCE(DM.HelpText, DM.MemberDescription, DM.MemberKey),
									[NodeTypeBM] = ISNULL(DM.NodeTypeBM, CASE WHEN DM.LevelNo = @MaxLevelNo THEN 1 ELSE 18 END),
									[SBZ] = ISNULL(DM.SBZ, CASE WHEN DM.LevelNo = @MaxLevelNo THEN 0 ELSE 1 END),
									[Source] = ISNULL(DM.[Source], 'pcPortal'),
									[Synchronized] = ISNULL(DM.Synchronized, 0),
									[Level] = CASE WHEN @HierarchyNo = 0 THEN DM.[Level] ELSE NULL END,
									[Parent] = CASE WHEN @HierarchyNo = 0 THEN DM.[Parent] ELSE NULL END
								FROM
									[#Dimension_Member] DM
								WHERE
									NOT EXISTS (SELECT 1 FROM [DimensionMember] DMD WHERE 
										DMD.[InstanceID] = DM.[InstanceID] AND
										DMD.[DimensionID] = DM.[DimensionID] AND
										DMD.[MemberKey] = DM.[MemberKey])
							END

						INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionMember]
							(
							[InstanceID],
							[DimensionID],
							[MemberKey],
							[MemberDescription],
							[HelpText],
							[NodeTypeBM],
							[SBZ],
							[Source],
							[Synchronized],
							[Level],
							[Parent]
							)
						SELECT
							[InstanceID] = DM.InstanceID,
							[DimensionID] = DM.DimensionID,
							[MemberKey] = DM.MemberKey,
							[MemberDescription] = ISNULL(DM.MemberDescription, DM.MemberKey),
							[HelpText] = COALESCE(DM.HelpText, DM.MemberDescription, DM.MemberKey),
							[NodeTypeBM] = ISNULL(DM.NodeTypeBM, CASE WHEN DM.LevelNo = @MaxLevelNo THEN 1 ELSE 18 END),
							[SBZ] = ISNULL(DM.SBZ, CASE WHEN DM.LevelNo = @MaxLevelNo THEN 0 ELSE 1 END),
							[Source] = ISNULL(DM.[Source], 'pcPortal'),
							[Synchronized] = ISNULL(DM.Synchronized, 0),
							[Level] = CASE WHEN @HierarchyNo = 0 THEN DM.[Level] ELSE NULL END,
							[Parent] = CASE WHEN @HierarchyNo = 0 THEN DM.[Parent] ELSE NULL END
						FROM
							[#Dimension_Member] DM
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionMember] DMD WHERE 
								DMD.[InstanceID] = DM.[InstanceID] AND
								DMD.[DimensionID] = DM.[DimensionID] AND
								DMD.[MemberKey] = DM.[MemberKey])

						SET @Inserted = @Inserted + @@ROWCOUNT

						IF @Property IS NOT NULL AND LEN(@Property) <> 0
							INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionMember_Property]
								(
								[InstanceID],
								[DimensionID],
								[MemberKey],
								[PropertyID],
								[Value]
								)
							SELECT
								[InstanceID] = @InstanceID,
								[DimensionID] = @DimensionID,
								[MemberKey] = PV.MemberKey,
								[PropertyID] = PV.PropertyID,
								[Value] = PV.PropertyValue
							FROM
								#PropertyValue PV
							WHERE
								(ISNUMERIC(PV.PropertyType) = 0 OR @HierarchyView = 'Parent') AND
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionMember_Property] DMP WHERE DMP.[InstanceID] = @InstanceID AND DMP.[DimensionID] = @DimensionID AND DMP.[MemberKey] = @MemberKey AND DMP.[PropertyID] = PV.PropertyID)
					END

	SET @Step = '@StorageTypeBM = 1, DELETE'	
				IF @DeleteYN <> 0
					BEGIN
						DELETE DMP
						FROM
							[pcINTEGRATOR_Data].[dbo].[DimensionMember_Property] DMP
						WHERE
							DMP.[InstanceID] = @InstanceID AND
							DMP.[DimensionID] = @DimensionID AND
							DMP.[MemberKey] = @MemberKey

						DELETE DM
						FROM 
							[pcINTEGRATOR_Data].[dbo].[DimensionMember] DM
						WHERE
							[InstanceID] =  @InstanceID AND
							[DimensionID] = @DimensionID AND
							[MemberKey] = @MemberKey

						SET @Deleted = @Deleted + @@ROWCOUNT
					END
			END

		ELSE IF @StorageTypeBM & 4 > 0
			BEGIN
	SET @Step = '@StorageTypeBM = 4, Handle MemberId'
				SET @SQLStatement = '
					UPDATE DM
					SET
						[MemberId] = DMD.[MemberID]
					FROM
						[#Dimension_Member] DM
						INNER JOIN ' + @CallistoDatabase + '..[S_DS_' + @DimensionName + '] DMD ON DMD.[Label] = DM.[MemberKey]'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				UPDATE DM
				SET
					[MemberId] = sub.[MemberID]
				FROM
					[#Dimension_Member] DM
					INNER JOIN
					(SELECT
						Label = M.Label,
						[MemberId] = MAX(M.[MemberID])
					FROM
						[#Dimension_Member] DM
						INNER JOIN Member M ON M.DimensionID IN (0, @DimensionID) AND M.[Label] = DM.[MemberKey]
					WHERE
						DM.MemberID IS NULL
					GROUP BY
						M.Label) sub ON sub.[Label] = DM.[MemberKey]
				
				CREATE TABLE #MemberId (MemberId bigint)

				SET @SQLStatement = '
					INSERT INTO #MemberId
						(MemberId)
					SELECT 
						MemberId = MAX(MemberID)
					FROM
						' + @CallistoDatabase + '..[S_DS_' + @DimensionName + ']'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SELECT @MemberId = MemberID FROM #MemberId

				WHILE (SELECT COUNT(1) FROM [#Dimension_Member] WHERE MemberId IS NULL) > 0
					BEGIN
						SET @MemberID = @MemberID + 1
						UPDATE DM
							SET MemberID = @MemberID
						FROM
							[#Dimension_Member] DM
							INNER JOIN (SELECT TOP 1 MemberKey FROM [#Dimension_Member] WHERE MemberId IS NULL) sub ON sub.MemberKey = DM.MemberKey
					END

				SET @SQLStatement = '
					UPDATE DM
					SET
						[ParentMemberId] = DMD.[MemberID]
					FROM
						[#Dimension_Member] DM
						INNER JOIN ' + @CallistoDatabase + '..[S_DS_' + @DimensionName + '] DMD ON DMD.[Label] = DM.[Parent]'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @SQLStatement = '
					UPDATE DM
					SET
						[AboveMemberId] = ISNULL(DMD.[MemberID], 0)
					FROM
						[#Dimension_Member] DM
						LEFT JOIN ' + @CallistoDatabase + '..[S_DS_' + @DimensionName + '] DMD ON DMD.[Label] = DM.[MemberKey_Above]'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#Dimension_Member', * FROM [#Dimension_Member]

	SET @Step = '@StorageTypeBM = 4, Handle MemberId for MemberProperties'
		IF @Property IS NOT NULL AND LEN(@Property) <> 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #PropertyValue
						(
						MemberKey,
						PropertyType,
						PropertyID,
						PropertyName,
						DependentDimensionName
						)
					SELECT DISTINCT
						MemberKey = PV.MemberKey,
						PropertyType = PV.PropertyType,
						PropertyID = PV.PropertyID,
						PropertyName = c.[name],
						DependentDimensionName = D.DimensionName
					FROM
						' + @CallistoDatabase + '.sys.tables t
						INNER JOIN ' + @CallistoDatabase + '.sys.columns c ON c.object_id = t.object_id
						INNER JOIN #PropertyValue PV ON PV.PropertyName + ''_MemberId'' = c.[name]
						INNER JOIN [Property] P ON P.InstanceID IN (0, ' + CONVERT(nvarchar(10), @InstanceID) + ') AND P.PropertyName = PV.PropertyName 
						INNER JOIN [Dimension_Property] DP ON DP.InstanceID IN (0, ' + CONVERT(nvarchar(10), @InstanceID) + ') AND DP.VersionID IN (0, ' + CONVERT(nvarchar(10), @VersionID) + ') AND DP.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND DP.PropertyID = P.PropertyID
						INNER JOIN Dimension D ON D.DimensionID = P.[DependentDimensionID]
					WHERE
						t.[name] = ''S_DS_' + @DimensionName + ''' AND
						NOT EXISTS (SELECT 1 FROM #PropertyValue PVD WHERE PVD.PropertyID = PV.PropertyID AND PVD.[PropertyName] = c.[name])'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @Debug <> 0 SELECT TempTable = '#PropertyValue_2', * FROM #PropertyValue

				DECLARE PropertyMember_Cursor CURSOR FOR

					SELECT 
						PropertyName = REPLACE(PV.PropertyName, '_MemberId', ''),
						DependentDimensionName
					FROM
						#PropertyValue PV
					WHERE
						PV.PropertyValue IS NULL AND
						PV.DependentDimensionName IS NOT NULL

					OPEN PropertyMember_Cursor
					FETCH NEXT FROM PropertyMember_Cursor INTO @PropertyName, @DependentDimensionName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @Debug <> 0 SELECT PropertyName = @PropertyName, DependentDimensionName = @DependentDimensionName

							SET @SQLStatement = '
								UPDATE PV
								SET
									PropertyValue = CONVERT(nvarchar(15), ISNULL(D.MemberId, 0))
								FROM
									#PropertyValue PV
									INNER JOIN #PropertyValue PVS ON PVS.PropertyID = PV.PropertyID AND PVS.PropertyName = REPLACE(PV.PropertyName, ''_MemberId'', '''')
									LEFT JOIN ' + @CallistoDatabase + '..[S_DS_' + @DependentDimensionName + '] D ON D.Label = PVS.PropertyValue
								WHERE
									PV.PropertyName = ''' + @PropertyName + '_MemberId'' AND
									PV.DependentDimensionName = ''' + @DependentDimensionName + ''''

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							FETCH NEXT FROM PropertyMember_Cursor INTO @PropertyName, @DependentDimensionName
						END

				CLOSE PropertyMember_Cursor
				DEALLOCATE PropertyMember_Cursor	
			END

IF @Debug <> 0 SELECT TempTable = '#PropertyValue_3', * FROM #PropertyValue

	SET @Step = '@StorageTypeBM = 4, UPDATE'	 
				IF @DeleteYN = 0
					BEGIN
						--Ordinary columns
						SET @SQLStatement = '
							UPDATE DMD
							SET
								[Description] = ISNULL(DM.[MemberDescription], DMD.[Description]),
								[HelpText] = ISNULL(DM.[HelpText], DMD.[HelpText]),
								[RNodeType] = ISNULL(CASE WHEN DM.[NodeTypeBM] & 1 > 0 THEN ''L'' ELSE ''P'' END + CASE WHEN DM.[NodeTypeBM] & 8 > 0 THEN ''C'' ELSE '''' END, DMD.[RNodeType]),'
								+ CASE WHEN @NodeTypeBM_ExistYN <> 0 THEN '[NodeTypeBM] = DM.[NodeTypeBM],' ELSE '' END + '
								[SBZ] = ISNULL(DM.[SBZ], DMD.[SBZ]),
								[Source] = ISNULL(DM.[Source], DMD.[Source]),
								[Synchronized] = ISNULL(DM.[Synchronized], DMD.[Synchronized])
							FROM
								' + @CallistoDatabase + '..[S_DS_' + @DimensionName + '] DMD
								INNER JOIN [#Dimension_Member] DM ON DM.[MemberKey] = DMD.[Label]'

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Updated = @Updated + @@ROWCOUNT

					END

	SET @Step = '@StorageTypeBM = 4, INSERT'	
				IF @DeleteYN = 0
					BEGIN
						--Ordinary columns
						SET @SQLStatement = '
							INSERT INTO ' + @CallistoDatabase + '..[S_DS_' + @DimensionName + ']
								(
								[MemberID],
								[Label],
								[Description],
								[HelpText],
								[RNodeType],'
								+ CASE WHEN @NodeTypeBM_ExistYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
								[SBZ],
								[Source],
								[Synchronized]
								)
							SELECT
								[MemberID] = DM.MemberID,
								[Label] = DM.MemberKey,
								[Description] = ISNULL(DM.MemberDescription, DM.MemberKey),
								[HelpText] = COALESCE(DM.HelpText, DM.MemberDescription, DM.MemberKey),
								[RNodeType] = CASE WHEN ISNULL(DM.NodeTypeBM, CASE WHEN DM.LevelNo = ' + CONVERT(nvarchar(10), @MaxLevelNo) + ' THEN 1 ELSE 18 END) & 1 > 0 THEN ''L'' ELSE ''P'' END + CASE WHEN ISNULL(DM.NodeTypeBM, CASE WHEN DM.LevelNo = ' + CONVERT(nvarchar(10), @MaxLevelNo) + ' THEN 1 ELSE 18 END) & 8 > 0 THEN ''C'' ELSE '''' END,'
								+ CASE WHEN @NodeTypeBM_ExistYN <> 0 THEN '[NodeTypeBM] = DM.[NodeTypeBM],' ELSE '' END + '
								[SBZ] = ISNULL(DM.SBZ, CASE WHEN DM.LevelNo = ' + CONVERT(nvarchar(10), @MaxLevelNo) + ' THEN 0 ELSE 1 END),
								[Source] = ISNULL(DM.[Source], ''pcPortal''),
								[Synchronized] = ISNULL(DM.Synchronized, 0)
							FROM
								[#Dimension_Member] DM
							WHERE
								NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '..[S_DS_' + @DimensionName + '] DMD WHERE DMD.[Label] = DM.[MemberKey])'

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
						
						SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '@StorageTypeBM = 4, UPDATE Dimension specific property columns'	
						IF @Property IS NOT NULL AND LEN(@Property) <> 0
							BEGIN
								SELECT
									@SQLSet = @SQLSet + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + PropertyName + '] = ''' + PropertyValue + ''','
								FROM
									#PropertyValue PV
								WHERE
									PropertyType = 'p' AND
									PropertyName IS NOT NULL AND
									PropertyValue IS NOT NULL AND
									SelectYN <> 0

								SET @SQLStatement = '
									UPDATE ' + @CallistoDatabase + '..[S_DS_' + @DimensionName + ']
									SET' + LEFT(@SQLSet, LEN(@SQLSet) - 1) + '
									WHERE
										Label = ''' + @MemberKey + ''''

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
							END

	SET @Step = '@StorageTypeBM = 4, UPDATE Hierarchy'	
						IF @Parent IS NOT NULL AND @DeleteYN = 0 AND @Level IS NULL
							BEGIN
								CREATE TABLE #Hierarchy
									(
									[MemberId] bigint,
									[ParentMemberId] bigint,
									[SequenceNumber] int IDENTITY(10,10) NOT NULL
									)

								SET @SQLStatement = '
									INSERT INTO #Hierarchy
										(
										[MemberId],
										[ParentMemberId]
										)
									SELECT
										[MemberId] = DMH.[MemberId],
										[ParentMemberId] = DMH.[ParentMemberId]
									FROM
										[#Dimension_Member] DM
										INNER JOIN ' + @CallistoDatabase + '..[S_HS_' + @DimensionName + '_' + @HierarchyName + '] DMH ON DMH.ParentMemberId = DM.ParentMemberId AND DMH.MemberId <> DM.MemberId 
									WHERE
										DM.[MemberKey] = ''' + @MemberKey + '''
									ORDER BY
										DMH.SequenceNumber'

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)								

								IF @Debug <> 0 SELECT * FROM #Hierarchy
								SELECT @AboveMemberId = AboveMemberId FROM #Dimension_Member WHERE [MemberKey] = @MemberKey
								SELECT @SequenceNumber = [SequenceNumber] + 5 FROM #Hierarchy WHERE [MemberId] = @AboveMemberId
								SET @SequenceNumber = ISNULL(@SequenceNumber, 5)
								IF @Debug <> 0 SELECT SequenceNumber = @SequenceNumber

								SET IDENTITY_INSERT #Hierarchy ON
								
								INSERT INTO #Hierarchy
									(
									[MemberId],
									[ParentMemberId],
									[SequenceNumber]
									)
								SELECT
									[MemberId] = DM.[MemberId],
									[ParentMemberId] = DM.[ParentMemberId],
									[SequenceNumber] = @SequenceNumber
								FROM
									[#Dimension_Member] DM
								WHERE
									DM.[MemberKey] = @MemberKey

								SET IDENTITY_INSERT #Hierarchy OFF

								SET @SQLStatement = '
									DELETE H 
									FROM
										' + @CallistoDatabase + '..[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H
										INNER JOIN [#Dimension_Member] DM ON DM.ParentMemberId = H.ParentMemberId AND DM.[MemberKey] = ''' + @MemberKey + '''

									DELETE H 
									FROM
										' + @CallistoDatabase + '..[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H
										INNER JOIN [#Hierarchy] HT ON HT.MemberId = H.MemberId

									INSERT INTO ' + @CallistoDatabase + '..[S_HS_' + @DimensionName + '_' + @HierarchyName + ']
										(
										[MemberId],
										[ParentMemberId],
										[SequenceNumber]
										)
									SELECT
										[MemberId] = H.[MemberId],
										[ParentMemberId] = H.[ParentMemberId],
										[SequenceNumber] = H.[SequenceNumber]
									FROM
										#Hierarchy H
									WHERE	
										NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '..[S_HS_' + @DimensionName + '_' + @HierarchyName + '] DH WHERE DH.[MemberId] = H.[MemberId])'

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @Inserted = @Inserted + @@ROWCOUNT

								DROP TABLE #Hierarchy
							END
					END

	SET @Step = '@StorageTypeBM = 4, DELETE'	
				IF @DeleteYN <> 0
					BEGIN
						SET @SQLStatement = '
							DELETE DMH
							FROM
								' + @CallistoDatabase + '..[S_HS_' + @DimensionName + '_' + @HierarchyName + '] DMH
								INNER JOIN #DimensionMember DM ON DM.MemberID = DMH.MemberId AND DM.MemberKey = ''' + @MemberKey + ''''

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @SQLStatement = '
							DELETE DMD
							FROM
								' + @CallistoDatabase + '..[S_DS_' + @DimensionName + '] DMD
								INNER JOIN #DimensionMember DM ON DM.MemberID = DMH.MemberId AND DM.MemberKey = ''' + @MemberKey + ''''

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Deleted = @Deleted + @@ROWCOUNT
					END

				IF @Parent IS NULL
					BEGIN
						TRUNCATE TABLE #MemberId
						SET @SQLStatement = '
							INSERT INTO #MemberId
								(MemberId)
							SELECT 
								MemberId = MemberID
							FROM
								' + @CallistoDatabase + '..[S_DS_' + @DimensionName + ']
							WHERE
								Label = ''' + @MemberKey + ''''

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SELECT @MemberId = MemberID FROM #MemberId

						DROP TABLE #MemberId

						SET @SQLStatement = '
							DELETE DMH
							FROM
								' + @CallistoDatabase + '..[S_HS_' + @DimensionName + '_' + @HierarchyName + '] DMH
							WHERE
								DMH.MemberId = ' + CONVERT(nvarchar(10), @MemberID)

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END

	SET @Step = 'COPY S-tables to O-tables'	
				IF @EnhancedStorageYN = 0
					BEGIN
						SET @OTable = @CallistoDatabase + '.dbo.[O_DS_' + @DimensionName + ']'
						SET @STable = @CallistoDatabase + '.dbo.[S_DS_' + @DimensionName + ']'
						EXEC('TRUNCATE TABLE ' + @OTable)
						EXEC('INSERT INTO '  + @OTable + ' SELECT * FROM ' + @STable)

						SET @OTable = @CallistoDatabase + '.dbo.[O_HS_' + @DimensionName + '_' + @HierarchyName + ']'
						SET @STable = @CallistoDatabase + '.dbo.[S_HS_' + @DimensionName + '_' + @HierarchyName + ']'
						EXEC('TRUNCATE TABLE ' + @OTable)
						EXEC('INSERT INTO '  + @OTable + ' SELECT * FROM ' + @STable)

	SET @Step = 'Update ChangeDatetime to enable replacement of cached information when deploy'	
						EXEC('UPDATE ' + @CallistoDatabase + '.dbo.[S_Dimensions] SET [ChangeDatetime] = getdate() WHERE Label = ''' + @DimensionName + '''')
					END

			END

	SET @Step = 'Clear cache table for changed dimension'
		EXEC [spSet_LeafLevelFilter_ClearCache] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DimensionID=@DimensionID, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Return created MemberID'
		IF @ReturnMemberIdYN <> 0 SELECT InstanceID, MemberID, MemberKey, MemberDescription, [Level], Parent, MemberKey_Above, AboveMemberId FROM #Dimension_Member WHERE MemberKey = @MemberKey

	SET @Step = 'Drop temp tables'
		IF OBJECT_ID('tempdb..#PropertyValue') IS NOT NULL DROP TABLE #PropertyValue
		IF OBJECT_ID('tempdb..#ParentChild') IS NOT NULL DROP TABLE #ParentChild
		DROP TABLE #Dimension_Member

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
