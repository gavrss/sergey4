SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_MultiDim_Callisto_20230714_neha]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@DimensionName nvarchar(50) = NULL,
	@HierarchyNo int = NULL, --Optional, if not set all hierarchies will be updated
	@HierarchyName nvarchar(50) = NULL,  --Optional, if not set all hierarchies will be updated

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000808,
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
EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_MultiDim_Callisto_20230714_neha] @DebugBM='31',@DimensionID='5828',@InstanceID='621',@UserID='-10',@VersionID='1105'

EXEC [spIU_Dim_MultiDim_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@DataClassID nvarchar(100),
	@DataClassName nvarchar(100),
	@SegmentName nvarchar(100),
	@PropertyName nvarchar(100),
	@DependentDimensionName nvarchar(100),
	@Punctuation nvarchar(10) = '-',
	@DescriptionPunctuation nvarchar(10) = ' - ',
	@SqlSelect nvarchar(max) = '',
	@SqlInsert nvarchar(max) = '',
	@MemberKey nvarchar(1000) = '',
	@MemberDescription nvarchar(1000) = '',
	@SqlJoin nvarchar(1000) = '',
	@StorageTypeBM int = 4,
	@DimensionFilter nvarchar(max),
	@JSON nvarchar(max),

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2185'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update selected MultiDim dimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2177' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2179' SET @Description = 'Use sub routine [spSet_Hierarchy].'
		IF @Version = '2.1.2.2180' SET @Description = 'Changed columns names and added step "Update BalanceYN and ReverseSign."'
		IF @Version = '2.1.2.2181' SET @Description = 'Made more generic'
		IF @Version = '2.1.2.2185' SET @Description = 'Added [Account] filter in Step = "Update BalanceYN and ReverseSign."'
		
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
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = ETLDatabase
		FROM
			pcINTEGRATOR_Data.dbo.[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT
			@DimensionName = ISNULL(@DimensionName, D.[DimensionName]),
			@DimensionID = ISNULL(@DimensionID, D.[DimensionID])
		FROM
			pcINTEGRATOR.dbo.[Dimension] D
		WHERE
			D.[InstanceID] IN (0, @InstanceID) AND
			D.[SelectYN] <> 0 AND
			D.[DeletedID] IS NULL AND
			(D.[DimensionID] = @DimensionID OR D.[DimensionName] = @DimensionName)

		SELECT
			@StorageTypeBM = [StorageTypeBM],
			@DimensionFilter = [DimensionFilter]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DimensionID] = @DimensionID

		SELECT
			@HierarchyName = ISNULL(@HierarchyName, DH.[HierarchyName]),
			@HierarchyNo = ISNULL(@HierarchyNo, DH.[HierarchyNo])
		FROM
			pcINTEGRATOR_Data.dbo.[DimensionHierarchy] DH
		WHERE
			DH.[InstanceID] IN (@InstanceID) AND
			DH.[VersionID] IN (@VersionID) AND
			DH.[DimensionID] = @DimensionID AND
			(DH.[HierarchyNo] = @HierarchyNo OR DH.[HierarchyName] = @HierarchyName)

		SELECT
			@HierarchyName = ISNULL(@HierarchyName, DH.[HierarchyName]),
			@HierarchyNo = ISNULL(@HierarchyNo, DH.[HierarchyNo])
		FROM
			pcINTEGRATOR.dbo.[@Template_DimensionHierarchy] DH
		WHERE
			DH.[InstanceID] IN (0) AND
			DH.[VersionID] IN (0) AND
			DH.[DimensionID] = @DimensionID AND
			(DH.[HierarchyNo] = @HierarchyNo OR DH.[HierarchyName] = @HierarchyName)

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@DimensionFilter] = @DimensionFilter,
				[@StorageTypeBM] = @StorageTypeBM,
				[@HierarchyNo] = @HierarchyNo,
				[@HierarchyName] = @HierarchyName

	SET @Step = 'Add all standard members'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
			{"TKey" : "RefreshHierarchyYN",  "TValue": "0"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), CONVERT(int, @DebugSub)) + '"}
			]'

		IF @DebugBM & 2 > 0 PRINT @JSON
		--EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_Dim_Dimension_Generic_Callisto', @JSON = @JSON

	SET @Step = 'Create temp table #Segment'	
		CREATE TABLE #Segment
			(
--			[SegmentName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DependentDimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[PropertyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)
	
		INSERT INTO #Segment
			(
--			SegmentName,
			[DependentDimensionName],
			[PropertyName],
			[SortOrder]
			)
		SELECT
--			SegmentName = PD.DimensionName,
			[DependentDimensionName] = PD.[DimensionName],
			[PropertyName] = P.[PropertyName],
			[SortOrder] = DP.[SortOrder]
		FROM
			pcINTEGRATOR..Dimension D
			INNER JOIN pcINTEGRATOR_Data..[Dimension_Property] DP ON DP.InstanceID = @InstanceID AND DP.VersionID = @VersionID AND DP.DimensionID = D.DimensionID AND DP.MultiDimYN <> 0 AND DP.SelectYN <> 0
			INNER JOIN pcINTEGRATOR..[Property] P ON P.InstanceID IN (0, DP.InstanceID) AND P.PropertyID = DP.PropertyID AND P.SelectYN <> 0
			INNER JOIN pcINTEGRATOR..[Dimension] PD ON PD.DimensionID = P.DependentDimensionID AND PD.SelectYN <> 0 AND PD.DeletedID IS NULL
		WHERE
			D.[InstanceID] IN (0, @InstanceID) AND
			D.[DimensionID] = @DimensionID AND
			D.[DimensionTypeID] = 27 AND
			D.[SelectYN] <> 0 AND
			D.[DeletedID] IS NULL

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment', * FROM #Segment ORDER BY [SortOrder], [PropertyName]

	SET @Step = 'Create temp table #DefaultColumn'
		SELECT
			[ColumnName],
			[SqlSelect]
		INTO
			#DefaultColumn
		FROM
			(
			SELECT [ColumnName] = 'Inserted', [SqlSelect] = 'CONVERT(nvarchar(50), FORMAT(GetDate(),''yyyy-MM-dd HH:mm:ss.fff''))'
			UNION SELECT [ColumnName] = 'JobID', [SqlSelect] = CONVERT(nvarchar(15), @JobID)
			UNION SELECT [ColumnName] = 'NodeTypeBM', [SqlSelect] = '1'
			UNION SELECT [ColumnName] = 'RNodeType', [SqlSelect] = '''L'''
			UNION SELECT [ColumnName] = 'SBZ', [SqlSelect] = '1'
			UNION SELECT [ColumnName] = 'Source', [SqlSelect] = '''ETL'''
			UNION SELECT [ColumnName] = 'Synchronized', [SqlSelect] = '1'
			UNION SELECT [ColumnName] = 'Updated', [SqlSelect] = 'CONVERT(nvarchar(50), FORMAT(GetDate(),''yyyy-MM-dd HH:mm:ss.fff''))'
			UNION SELECT [ColumnName] = 'Sign', [SqlSelect] = '1'
			UNION SELECT [ColumnName] = 'TimeBalance', [SqlSelect] = '0'
			) sub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DefaultColumn', * FROM #DefaultColumn

	SET @Step = 'Create and fill temp table #ColumnList'
		CREATE TABLE #ColumnList
			(
			[ColumnName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SqlSelect] nvarchar(255) DEFAULT '' COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

		SET @SQLStatement = '
			INSERT INTO #ColumnList
				(
				[ColumnName],
				[SortOrder]
				)
			SELECT
				[ColumnName] = C.[name],
				[SortOrder] = C.[column_id]
			FROM
				[' + @CallistoDatabase + '].[sys].[tables] T
				INNER JOIN [' + @CallistoDatabase + '].[sys].[columns] C ON C.[object_id] = T.[object_id]
			WHERE
				T.[name] = ''S_DS_' + @DimensionName + '''
			ORDER BY
				C.[column_id]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ColumnList_1', * FROM #ColumnList ORDER BY SortOrder

	SET @Step = 'Update column [SqlSelect] in temp table #ColumnList with all default values.'
		UPDATE CL
		SET
			[SqlSelect] = DC.[SqlSelect]
		FROM
			#ColumnList CL
			INNER JOIN #DefaultColumn DC ON DC.[ColumnName] = CL.[ColumnName]

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ColumnList_2', * FROM #ColumnList ORDER BY SortOrder

	SET @Step = 'Update column [SqlSelect] in temp table #ColumnList for all segments.'
		IF CURSOR_STATUS('global','Segment_Cursor') >= -1 DEALLOCATE Segment_Cursor
		DECLARE Segment_Cursor CURSOR FOR
			SELECT 
				[PropertyName] = S.[PropertyName] + CS.[ColumnSuffix],
				[SqlSelect] = CASE WHEN CS.[ColumnSuffix] = '' THEN '[' + S.[PropertyName] + '].[Label]' ELSE 'DC.[' + S.[PropertyName] + '_MemberId]' END
			FROM
				#Segment S
				INNER JOIN (SELECT [ColumnSuffix]='' UNION SELECT [ColumnSuffix] = '_MemberId') CS ON 1 = 1
			ORDER BY
				S.SortOrder,
				S.[PropertyName]

			OPEN Segment_Cursor
			FETCH NEXT FROM Segment_Cursor INTO @PropertyName, @SqlSelect

			WHILE @@FETCH_STATUS = 0
				BEGIN
					UPDATE #ColumnList
					SET
						[SqlSelect] = @SqlSelect
					WHERE
						[ColumnName] = @PropertyName

					FETCH NEXT FROM Segment_Cursor INTO @PropertyName, @SqlSelect
				END

		CLOSE Segment_Cursor
		DEALLOCATE Segment_Cursor	

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ColumnList_3', * FROM #ColumnList ORDER BY SortOrder

	SET @Step = 'Update column [SqlSelect] in temp table #ColumnList for MemberKey and Description.'
		SELECT
			@MemberKey = @MemberKey + '[' + S.[PropertyName] + '].[Label] + ''' + @Punctuation + ''' + ',
			@MemberDescription = @MemberDescription + '[' + S.[PropertyName] + '].[Description] + ''' + @DescriptionPunctuation + ''' + ',
			@SqlJoin = @SqlJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + S.[DependentDimensionName] + '] [' + S.[PropertyName] + '] ON [' + S.[PropertyName] + '].[MemberId] = DC.[' + S.[PropertyName] + '_MemberId]'
		FROM
			#Segment S
		ORDER BY
			[SortOrder],
			[PropertyName]

		IF LEN(@MemberKey) > 7 AND LEN(@MemberDescription) > 7
			BEGIN
				SELECT
					@MemberKey = LEFT(@MemberKey, LEN(@MemberKey) - (LEN(@Punctuation) + 7)),
					@MemberDescription = LEFT(@MemberDescription, LEN(@MemberDescription) - (LEN(@DescriptionPunctuation) + 7))

				UPDATE #ColumnList
				SET
					[SqlSelect] = @MemberKey
				WHERE
					[ColumnName] = 'Label'

				UPDATE #ColumnList
				SET
					[SqlSelect] = @MemberDescription
				WHERE
					[ColumnName] IN ('Description', 'HelpText')
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ColumnList_4', * FROM #ColumnList ORDER BY SortOrder
		IF @DebugBM & 2 > 0 SELECT [@MemberDescription] = @MemberDescription

	SET @Step = 'Update column [SqlSelect] in temp table #ColumnList for Sign and TimeBalance.'
		IF (SELECT COUNT(1) FROM #Segment WHERE [DependentDimensionName] = 'Account') = 1
			BEGIN
				UPDATE CL
				SET
					[SqlSelect] = '[' + S.[PropertyName] + '].[Sign]'
				FROM
					#ColumnList CL
					INNER JOIN #Segment S ON S.[DependentDimensionName] = 'Account'
				WHERE
					CL.[ColumnName] = 'ReverseSign'

				UPDATE CL
				SET
					[SqlSelect] = '[' + S.[PropertyName] + '].[TimeBalance]'
				FROM
					#ColumnList CL
					INNER JOIN #Segment S ON S.[DependentDimensionName] = 'Account'
				WHERE
					CL.[ColumnName] = 'BalanceYN'

				--UPDATE #ColumnList
				--SET
				--	[SqlSelect] = '[Account].[TimeBalance]'
				--WHERE
				--	[ColumnName] = 'TimeBalance'
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ColumnList_5', * FROM #ColumnList ORDER BY SortOrder

	SET @Step = 'Create Filter.'
		CREATE TABLE #FilterTable
			(
			[StepReference] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[TupleNo] int,
			[DimensionID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DimensionTypeID] int,
			[StorageTypeBM] int,
			[SortOrder] int,
			[ObjectReference] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[PropertyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[JournalColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[Filter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[PropertyFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[Segment] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[Method] nvarchar(20) COLLATE DATABASE_DEFAULT
			)

		EXEC [spGet_FilterTable]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@StepReference = 'MultiDim',
			@PipeString = @DimensionFilter,
			@DatabaseName = @CallistoDatabase, --Mandatory
			@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
			@StorageTypeBM = 4, --Mandatory
			@Debug = @DebugSub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable ORDER BY [DimensionName]

	SET @Step = 'Insert new rows into Dimension table.'
		SELECT
			@SqlInsert = '',
			@SqlSelect = ''

		SELECT
			@SqlInsert = @SqlInsert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '],',
			@SqlSelect = @SqlSelect + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '] = ' + [SqlSelect] + ','
		FROM
			#ColumnList
		WHERE
			LEN([SqlSelect]) > 0
		ORDER BY
			[SortOrder]
		
		IF @DebugBM & 2 > 0 SELECT [@SqlInsert] = @SqlInsert
		SELECT
			@SqlInsert = LEFT(@SqlInsert, LEN(@SqlInsert) - 1),
			@SqlSelect = LEFT(@SqlSelect, LEN(@SqlSelect) - 1)

		IF CURSOR_STATUS('global','DataClass_Cursor') >= -1 DEALLOCATE DataClass_Cursor
		DECLARE DataClass_Cursor CURSOR FOR
			SELECT
				DC.[DataClassID],
				DC.[DataClassName]
			FROM
				[pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = DCD.[InstanceID] AND DC.[VersionID] = DCD.[VersionID] AND DC.[DataClassID] = DCD.[DataClassID] AND DC.[SelectYN] <> 0 AND DC.DeletedID IS NULL
			WHERE
				DCD.[InstanceID] = @InstanceID AND
				DCD.[VersionID] = @VersionID AND
				DCD.[DimensionID] = @DimensionID AND
				DCD.[SelectYN] <> 0

			OPEN DataClass_Cursor
			FETCH NEXT FROM DataClass_Cursor INTO @DataClassID, @DataClassName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DataClassID] = @DataClassID, [@DataClassName] = @DataClassName

					--Create filter applicable for current DataClass
					SET @DimensionFilter = ''

					SELECT
						@DimensionFilter = @DimensionFilter + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.' + FT.[DimensionName] + '_MemberId ' + FT.[EqualityString] + ' (' + [LeafLevelFilter] + ') AND '
					FROM
						pcINTEGRATOR_Data..DataClass_Dimension DCD
						INNER JOIN #FilterTable FT ON FT.DimensionID = DCD.DimensionID
					WHERE
						DCD.[InstanceID] = @InstanceID AND
						DCD.[VersionID] = @VersionID AND
						DCD.[DataClassID] = @DataClassID AND
						DCD.[SelectYN] <> 0					

					--Update [Description] and [HelpText] columns
					SET @SQLStatement = '
						UPDATE DC
						SET
							[Description] = ' + REPLACE(@MemberDescription, '', '''') + ',
							[HelpText] = ' + REPLACE(@MemberDescription, '''', '') + ',
							[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + '''
						FROM
							[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] DC ' + @SqlJoin + ' 
						WHERE
							DC.Synchronized <> 0 AND
							DC.RNodeType = ''L'' AND 
							DC.MemberId NOT IN (-1) AND
							DC.[Description] <> ' + REPLACE(@MemberDescription, '''', '') 

					IF @DebugBM & 2 > 0 
						BEGIN
							PRINT '>>> UPDATE @SQLStatement >>> ' + @SQLStatement
							PRINT '>>> @SqlSelect >>> ' + @SqlSelect
							PRINT '>>> @SqlJoin >>> ' + @SqlJoin
							PRINT '>>> @DimensionFilter >>> ' + @DimensionFilter
							PRINT '>>> @DimensionName >>> ' + @DimensionName
							PRINT '>>> @MemberKey >>> ' + @MemberKey
						END 

					--Insert new rows into dimension table
					--SET @SQLStatement = '
					--	INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
					--		(' + @SqlInsert + '
					--		)
					--	SELECT DISTINCT' + @SqlSelect + '
					--	FROM
					--		[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_Partition] DC' + @SqlJoin + ' 
					--	WHERE ' 
					SET @SQLStatement = '
						SELECT DISTINCT' + @SqlSelect + '
						FROM
							[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_Partition] DC' + @SqlJoin + ' 
						WHERE ' 
						
					SET @SQLStatement = @SQLStatement + @DimensionFilter
						
					SET @SQLStatement = @SQLStatement + '
							NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] WHERE [' + @DimensionName + '].[Label] = ' + @MemberKey + ')'

					IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
						BEGIN
							PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Add MultiDim rows to [Dimension] table'
							EXEC [pcINTEGRATOR].[dbo].[spSet_wrk_Debug]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@DatabaseName = @DatabaseName,
								@CalledProcedureName = @ProcedureName,
								@Comment = 'Add MultiDim rows to [Dimension] table', 
								@SQLStatement = @SQLStatement
						END
					ELSE
						PRINT @SQLStatement

					--EXEC (@SQLStatement)

					SET @Inserted = @Inserted + @@ROWCOUNT

					FETCH NEXT FROM DataClass_Cursor INTO @DataClassID, @DataClassName
				END

		CLOSE DataClass_Cursor
		DEALLOCATE DataClass_Cursor	
/*
	SET @Step = 'Update BalanceYN and ReverseSign.'
		IF (SELECT COUNT(1) FROM #ColumnList WHERE ColumnName IN ('Account','BalanceYN','ReverseSign')) = 3
			BEGIN
				CREATE TABLE #PropertyCount
					(
					MemberId bigint,
					[BalanceYN_0] int,
					[BalanceYN_1] int,
					[ReverseSign_1] int,
					[ReverseSign_-1] int
					)

				DECLARE @SqlExec VARCHAR(MAX) = '';
				-- Update BalanceYN and ReverseSign for the Leafs
				SET @SqlExec = 
'				UPDATE MD
				SET
					[BalanceYN] = [Account].[TimeBalance],
					[ReverseSign] = [Account].[Sign]
				FROM
					[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] MD
					INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Account] [Account] ON [Account].[MemberId] = MD.[Account_MemberId]
				WHERE
					MD.Synchronized <> 0'
			
				IF @DebugBM & 2 > 0 PRINT @SqlExec
				EXEC (@SqlExec)

				-- Update BalanceYN and ReverseSign for the Parents
				DECLARE @RootLabel VARCHAR(255) = 'All_';
				DECLARE @HIERARCHY_SELECT VARCHAR(MAX) = '';
				IF CURSOR_STATUS('global','Cur1_Cursor') >= -1 DEALLOCATE Cur1_Cursor
				DECLARE Cur1_Cursor CURSOR FOR
			
					SELECT HierarchyName
					FROM DimensionHierarchy
					WHERE DimensionID = @DimensionID

					DECLARE @Hierarchy nvarchar(100);
					DECLARE @counter1 INT = 0;

					OPEN Cur1_Cursor
					FETCH NEXT FROM Cur1_Cursor INTO @Hierarchy

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Hierarchy] = @Hierarchy
							SET @counter1 = @counter1 + 1
							SET @HIERARCHY_SELECT = @HIERARCHY_SELECT + 
									IIF(@counter1 <= 1, '', CHAR(13) + CHAR(10) + '				UNION ALL' + CHAR(13) + CHAR(10)) +
									'SELECT	 HierarchyName = ''' + @Hierarchy + '''
											,MemberId
											,ParentMemberId
									FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @Hierarchy + '] '
							FETCH NEXT FROM Cur1_Cursor INTO @Hierarchy
						END

				CLOSE Cur1_Cursor
				DEALLOCATE Cur1_Cursor

				SET @SqlExec = '
				WITH CTE1 AS (
					SELECT     
						H.HierarchyName,
						[Path] = cast(H.MemberId AS varchar(255)),
						H.MemberId, 
						MD.Label,
						H.ParentMemberId,
						MD.RNodeType,
						MD.NodeTypeBM,
						MD.BalanceYN,
						MD.ReverseSign
					FROM (
							' + @HIERARCHY_SELECT + ' 
							) AS H
					JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] MD ON		MD.MemberID = H.MemberID
															AND MD.Label IN (''' + @RootLabel + ''')
					WHERE
						MD.NodeTypeBM & 2 > 0 AND
						MD.Synchronized <> 0
					UNION ALL
					SELECT     
						H2.HierarchyName,
						[Path] = CAST(o.[Path] + ''->'' + cast(H2.MemberId AS varchar(255))  AS VARCHAR(255)),
						H2.MemberId, 
						Label = DETAIL.Label,
						H2.ParentMemberId,
						DETAIL.RNodeType,
						DETAIL.NodeTypeBM,
						DETAIL.BalanceYN,
						DETAIL.ReverseSign
					FROM (
							' + @HIERARCHY_SELECT + ' 
							) AS H2
					JOIN CTE1 o ON   o.MemberId = H2.ParentMemberId
									AND o.HierarchyName = H2.HierarchyName
					JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] DETAIL ON		DETAIL.MemberID = H2.MemberID
																AND DETAIL.Synchronized <> 0
				)

				UPDATE MD
				SET  MD.BalanceYN	= AAA.PARENT_BalanceYN
					,MD.ReverseSign = AAA.PARENT_ReverseSign
				FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] MD 
				JOIN (
						SELECT   
								 PARENT.Path
								,PARENT.MemberId
								,PARENT.Label
								,PARENT_BalanceYN	= IIF(SUM(CASE WHEN LEAF.BalanceYN = 0 THEN 1 ELSE 0 end)   >= SUM(CASE WHEN LEAF.BalanceYN = 1 THEN 1 ELSE 0 end), 0, 1)
								,PARENT_ReverseSign = IIF(sum(CASE WHEN LEAF.ReverseSign = 1 THEN 1 ELSE 0 end) >= SUM(CASE WHEN LEAF.ReverseSign = -1 THEN 1 ELSE 0 end), 1, -1)
								,SUM(CASE WHEN LEAF.BalanceYN = 0 THEN 1 ELSE 0 end)  AS BalanceYNzeros
								,sum(CASE WHEN LEAF.BalanceYN = 1 THEN 1 ELSE 0 end)  AS BalanceYNones 
								,SUM(CASE WHEN LEAF.ReverseSign = -1 THEN 1 ELSE 0 end)  AS ReverseSign_MinusOnes
								,sum(CASE WHEN LEAF.ReverseSign = 1 THEN 1 ELSE 0 end)  AS ReverseSign_PlusOnes
						FROM CTE1 PARENT
						LEFT OUTER JOIN CTE1 LEAF ON LEAF.Path LIKE PARENT.Path + ''->%''
													AND LEAF.HierarchyName = PARENT.HierarchyName
						WHERE
								PARENT.NodeTypeBM & 1 = 0 -- parent
							AND LEAF.NodeTypeBM & 1 > 0 -- leaf
						GROUP BY 
								PARENT.Path
								,PARENT.MemberId
								,PARENT.Label
						/*ORDER BY 
								PARENT.Path */
						) AS AAA ON AAA.MemberID = MD.MemberID 
				WHERE MD.Label <> ''All_'';

				UPDATE MD
				SET  MD.BalanceYN	= 0
					,MD.ReverseSign = 1
				FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] MD 
				WHERE MD.Label = ''All_'';
				';

				IF @DebugBM & 2 > 0 PRINT @SqlExec
				EXEC (@SqlExec)

				/*
				SELECT
					*
				FROM
					pcDATA_GMN..S_DS_FullAccount MD
					INNER JOIN pcDATA_GMN..S_HS_FullAccount_FullAccount H ON H.MemberID = MD.MemberID
				WHERE
					MD.NodeTypeBM & 2 = 0 AND
					MD.Synchronized <> 0
					*/

			END

	SET @Step = 'Set MemberID for all new rows.'
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Update selected hierarchy (or all hierarchies if @HierarchyNo IS NULL).'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
			' + CASE WHEN @HierarchyNo IS NOT NULL THEN '{"TKey" : "HierarchyNo",  "TValue": "' + CONVERT(nvarchar(10), @HierarchyNo) + '"},' ELSE '' END + '
			{"TKey" : "SourceTable",  "TValue": "' + '[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']' + '"},
			{"TKey" : "StorageTypeBM",  "TValue": "' + CONVERT(nvarchar(15), @StorageTypeBM) + '"},
			{"TKey" : "StorageDatabase",  "TValue": "' + @CallistoDatabase + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
			]'

		IF @DebugBM & 2 > 0 PRINT @JSON
					
		EXEC spRun_Procedure_KeyValuePair
			@DatabaseName = 'pcINTEGRATOR',
			@ProcedureName = 'spSet_Hierarchy',
			@JSON = @JSON
*/		
	SET @Step = 'Drop the temp tables'
		DROP TABLE #Segment
		DROP TABLE #ColumnList
		DROP TABLE #DefaultColumn
		DROP TABLE #FilterTable

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		--EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	--EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
