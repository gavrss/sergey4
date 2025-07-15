SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR07]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@EventTypeID int = NULL,
	@BusinessRuleID int = NULL,
	@DimensionID int = NULL,
	@HierarchyNo int = NULL,
	@CalledBy nvarchar(10) = 'pcPortal', --pcPortal, Callisto, ETL

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000726,
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
EXEC spBR_BR07 @UserID='-10', @InstanceID='454', @VersionID='1021', @BusinessRuleID = 12152, @CalledBy='pcPortal', @DebugBM=3

EXEC [spBR_BR07] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@StorageTypeBM int,
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@DimensionName nvarchar(50),
	@HierarchyName nvarchar(50),
	@Dimensionhierarchy nvarchar(100),
	@ColumnName nvarchar(50),
	@DataType nvarchar(50),
	@CustomYN bit = 0,
	@LevelNo int,
	@LevelName nvarchar(50),
	@Type nvarchar(10),
	@ParentLevelNo int,
	@ParentLevelName nvarchar(50),
	@ParentType nvarchar(10),
	@DimensionTable nvarchar(100),
	@HierarchyTable nvarchar(100),
	@DefaultHierarchyTable nvarchar(100),
	@MappingTypeID int,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2162'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Running business rule BR07 - Update hierarchy.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'

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
			@DatabaseName = DB_NAME(),
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
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.[ETLDatabase], '[', ''), ']', ''), '.', '].[') + ']',
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.[DestinationDatabase], '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID 

		IF @BusinessRuleID IS NOT NULL
			BEGIN
				SELECT
					@DimensionID = ISNULL(@DimensionID, [DimensionID]),
					@HierarchyNo = ISNULL(@HierarchyNo, [HierarchyNo])
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR07_Master]
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					BusinessRuleID = @BusinessRuleID
			END

		SELECT
			@DimensionName = DimensionName
		FROM
			pcINTEGRATOR..Dimension
		WHERE
			InstanceID IN (0, @InstanceID) AND
			DimensionID = @DimensionID

		SELECT
			@CustomYN = COUNT(1)
		FROM
			pcINTEGRATOR_Data..[DimensionHierarchy]
		WHERE
			InstanceID IN (@InstanceID) AND
			VersionID IN (@VersionID) AND
			DimensionID = @DimensionID AND
			HierarchyNo = @HierarchyNo

		SELECT
			@HierarchyName = HierarchyName
		FROM
			pcINTEGRATOR..[DimensionHierarchy]
		WHERE
			InstanceID = CASE WHEN @CustomYN = 0 THEN 0 ELSE @InstanceID END AND
			VersionID = CASE WHEN @CustomYN = 0 THEN 0 ELSE @VersionID END AND
			DimensionID = @DimensionID AND
			HierarchyNo = @HierarchyNo

		SELECT
			@StorageTypeBM = StorageTypeBM
		FROM
			pcINTEGRATOR_Data..Dimension_StorageType
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @StorageTypeBM & 4 > 0
			SELECT
				@DimensionTable = @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + ']',
				@HierarchyTable = @CallistoDatabase + '.[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + ']',
				@DefaultHierarchyTable = @CallistoDatabase + '.[dbo].[S_HS_' + @DimensionName + '_' + @DimensionName + ']'

	IF @DebugBM & 2 > 0
		SELECT
			[@CustomYN] = @CustomYN,
			[@DimensionName] = @DimensionName,
			[@HierarchyName] = @HierarchyName,
			[@StorageTypeBM] = @StorageTypeBM,
			[@ETLDatabase] = @ETLDatabase,
			[@CallistoDatabase] = @CallistoDatabase,
			[@DimensionTable] = @DimensionTable,
			[@HierarchyTable] = @HierarchyTable,
			[@DefaultHierarchyTable] = @DefaultHierarchyTable,
			[@JobID] = @JobID

			SELECT 
				[LevelName] = P.PropertyName,
				[Type] = CONVERT(nvarchar(10), 'Member'),
				[MappingTypeID] = CONVERT(int, NULL)
			INTO
				#Level
			FROM
				Dimension_Property DP
				INNER JOIN Property P ON P.PropertyID = DP.PropertyID AND P.DataTypeID = 3
			WHERE
				DP.InstanceID IN (0, @InstanceID) AND
				DP.VersionID IN (0, @VersionID) AND
				DP.DimensionID = @DimensionID
			ORDER BY
				DP.SortOrder 
/*
			INSERT INTO #Level
				(
				[LevelName],
				[Type]
				)
			SELECT DISTINCT
				LevelName = [Level],
				[Type] = 'Level'
			FROM
				pcDATA_CCM..S_DS_Customer D
			WHERE
				D.[Level] IS NOT NULL AND
				NOT EXISTS (SELECT 1 FROM #Level L WHERE L.[LevelName] = D.[Level])

			UPDATE L
			SET
				[MappingTypeID] = DST.[MappingTypeID]
			FROM
				#Level L
				INNER JOIN pcINTEGRATOR..[Dimension] D ON D.InstanceID IN (0, @InstanceID) AND D.[DimensionName] = L.[LevelName]
				INNER JOIN pcINTEGRATOR_Data..[Dimension_StorageType] DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = D.DimensionID
			WHERE
				L.[Type] = 'Member'
			
			SELECT TempTable = '#Level', * FROM #Level

	SET @Step = 'Create temp table #DimensionColumn'
		CREATE TABLE #DimensionColumn
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit
			)

	SET @Step = 'Run cursor for adding columns to temp table #DimensionColumn'
		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT 
				ColumnName = P.PropertyName,
				DataType = DT.DataTypeCode
			FROM
				Dimension_Property DP
				INNER JOIN Property P ON P.PropertyID = DP.PropertyID
				INNER JOIN DataType DT ON DT.DataTypeID = P.DataTypeID
			WHERE
				DP.InstanceID IN (0, @InstanceID) AND
				DP.VersionID IN (0, @VersionID) AND
				DP.DimensionID = @DimensionID
			ORDER BY
				DP.SortOrder

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @ColumnName, @DataType

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						ALTER TABLE #DimensionColumn ADD [' + @ColumnName + '] ' + @DataType

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					FETCH NEXT FROM AddColumn_Cursor INTO  @ColumnName, @DataType
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionColumn', * FROM #DimensionColumn

	SET @Step = 'Truncate hierarchy table'
		SET @SQLStatement = 'TRUNCATE TABLE' + @HierarchyTable

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Run Level_Cursor'
		SELECT
			[LevelNo] = DHL.[LevelNo],
			[LevelName] = DHL.[LevelName],
			[Type] = L.[Type],
			[MappingTypeID] = L.[MappingTypeID],
			[ParentLevelNo] = CONVERT(int, NULL),
			[ParentLevelName] = CONVERT(nvarchar(50), NULL),
			[ParentType] = CONVERT(nvarchar(10), NULL)
		INTO
			#Level_Cursor_Table
		FROM
			[pcINTEGRATOR].[dbo].[DimensionHierarchyLevel] DHL
			INNER JOIN #Level L ON L.LevelName = DHL.LevelName
		WHERE
			DHL.InstanceID = CASE WHEN @CustomYN = 0 THEN 0 ELSE @InstanceID END AND
			DHL.VersionID = CASE WHEN @CustomYN = 0 THEN 0 ELSE @VersionID END AND
			DHL.DimensionID = @DimensionID AND
			DHL.HierarchyNo = @HierarchyNo
		ORDER BY
			DHL.LevelNo

		UPDATE LCT
		SET
			[ParentLevelNo] = LCTP.[LevelNo],
			[ParentLevelName] = LCTP.[LevelName],
			[ParentType] = LCTP.[Type]
		FROM
			#Level_Cursor_Table LCT
			LEFT JOIN #Level_Cursor_Table LCTP ON LCTP.[LevelNo] = LCT.[LevelNo] - 1


		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Level_Cursor_Table', * FROM #Level_Cursor_Table ORDER BY [LevelNo]

		IF CURSOR_STATUS('global','Level_Cursor') >= -1 DEALLOCATE Level_Cursor
		DECLARE Level_Cursor CURSOR FOR
			SELECT
				[LevelNo],
				[LevelName],
				[Type],
				[MappingTypeID],
				[ParentLevelNo],
				[ParentLevelName],
				[ParentType]
			FROM
				#Level_Cursor_Table
			ORDER BY
				[LevelNo]

			OPEN Level_Cursor
			FETCH NEXT FROM Level_Cursor INTO @LevelNo, @LevelName, @Type, @MappingTypeID, @ParentLevelNo, @ParentLevelName, @ParentType

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@LevelNo] = @LevelNo, [@LevelName] = @LevelName, [@Type] = @Type, [@MappingTypeID] = @MappingTypeID, [@ParentLevelNo] = @ParentLevelNo, [@ParentLevelName] = @ParentLevelName, [@ParentType] = @ParentType

					IF @StorageTypeBM & 4 > 0
						BEGIN
							IF @Type = 'Level'
								BEGIN
									SELECT [Type] = @Type
									SET @SQLStatement = '
										INSERT INTO ' + @HierarchyTable + '
											(
											[MemberId],
											[ParentMemberId],
											[SequenceNumber]
											)
										SELECT
											[MemberId] = H.[MemberId],
											[ParentMemberId] = ' + CASE WHEN @ParentLevelNo IS NULL THEN 'NULL' ELSE 'H.[ParentMemberId]' END + ',
											[SequenceNumber] = H.[SequenceNumber]
										FROM
											' + @DefaultHierarchyTable + ' H
											INNER JOIN ' + @DimensionTable + ' D ON D.[MemberId] = H.[MemberId] AND D.[Level] = ''' + @LevelName + ''''

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

								END

							ELSE IF @Type = 'Member'
								BEGIN
									SELECT [Type] = @Type
									--Create Members if not exists


									SELECT DISTINCT
										--[MemberId],
										[Label] = 'CustomerCategory' + '_' + [CustomerCategory],
										[Description] = [CustomerCategory],
										--[AccountManager_MemberId],
										--[AccountManager],
										[CustomerCategory_MemberId],
										[CustomerCategory],
										--[Geography_MemberId],
										--[Geography],
										[HelpText] = [CustomerCategory],
										--[PaymentDays],
										--[PaymentHabit],
										[RNodeType] = 'P',
										[SBZ] = 1,
										--[SendTo_MemberId],
										--[SendTo],
										[Source] = 'EFP',
										[Synchronized] = 0,
										--[TopNode],
										[Level] = 'CustomerCategory'
										--[MemberKeyBase],
										--[Entity_MemberId],
										--[Entity]
									FROM
										[pcDATA_CCM].[dbo].[S_DS_Customer] Customer
									WHERE
										[CustomerCategory] IS NOT NULL AND
										NOT EXISTS (SELECT 1 FROM [pcDATA_CCM].[dbo].[S_DS_Customer] D WHERE D.[Label] = 'CustomerCategory' + '_' + [CustomerCategory])


									--Add rows to hierarchy
									SET @SQLStatement = '
										INSERT INTO ' + @HierarchyTable + '
											(
											[MemberId],
											[ParentMemberId],
											[SequenceNumber]
											)
										SELECT
											[MemberId] = D.[MemberId],
											[ParentMemberId] = ' + CASE WHEN @ParentLevelName = 'TopNode' THEN '1' ELSE 'DP.[MemberId]' END + ',
											[SequenceNumber] = DP.[MemberId]
										FROM
											' + @DimensionTable + ' D
											LEFT JOIN ' + @DimensionTable + ' DP ON DP.[Label] = ''' + @ParentLevelName + ''' + ''_'' + D.[' + @ParentLevelName + ']
										WHERE
											D.[Level] = ''' + @LevelName + ''''

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

						END

					FETCH NEXT FROM Level_Cursor INTO @LevelNo, @LevelName, @Type, @MappingTypeID, @ParentLevelNo, @ParentLevelName, @ParentType
				END

		CLOSE Level_Cursor
		DEALLOCATE Level_Cursor	
*/
	SET @Step = 'Copy Callisto hierarchy'
		IF @StorageTypeBM & 4 > 0
			BEGIN
				SET @Dimensionhierarchy = @DimensionName + '_' + @HierarchyName
			
				EXEC [dbo].[spSet_HierarchyCopy] 
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@Database = @CallistoDatabase,
					@Dimensionhierarchy = @Dimensionhierarchy,
					@JobID = @JobID,
					@Debug = @DebugSub
			END

	SET @Step = 'Drop temp tables'

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
