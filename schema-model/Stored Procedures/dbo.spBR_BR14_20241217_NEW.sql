SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR14_20241217_NEW]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@EventTypeID int = NULL,
	@BusinessRuleID int = NULL,
	@FiscalYear int = NULL,
	@FromTime int = NULL,
	@ToTime int = NULL,
	@JournalTable nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000764,
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
EXEC [spBR_BR14] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 2340, @FiscalYear = 2021, @DebugBM = 3
EXEC [spBR_BR14] @UserID=-10, @InstanceID=529, @VersionID=1001, @BusinessRuleID = 1004, @DebugBM = 3
EXEC [spBR_BR14] @UserID=-10, @InstanceID=572, @VersionID=1080, @BusinessRuleID=2586, @FiscalYear=2021, @DebugBM=3
EXEC [spBR_BR14] @UserID=-10, @InstanceID=580, @VersionID=1084, @BusinessRuleID=2739, @FiscalYear=2021, @DebugBM=3

EXEC [spBR_BR14] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

--Temporary test
--SET @DebugBM = 3

DECLARE
	--SP-specific variables
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@SQLFilter nvarchar(max),
	@SQLJoin nvarchar(max),
	@SQLStatement nvarchar(max),
	@DimensionID int,
	@DimensionName nvarchar(100),
	@PropertyDimension nvarchar(100),
--	@JournalTable nvarchar(100),
	@ICCounterpart nvarchar(100),
	@Method nvarchar(20),
	@DimensionFilter nvarchar(4000),
	@DimMethod nvarchar(20),
	@PropertyLen int,
	@Segment nvarchar(20),
	@CalledYN bit = 1,
	@ID int,
	@StepReference nvarchar(20),
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
	@Version nvarchar(50) = '2.1.2.2192'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set InterCompanyEntity in Journal',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2170' SET @Description = 'Procedure created. Added Property handling.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added parameter @EventTypeID.'
		IF @Version = '2.1.1.2173' SET @Description = 'Updated version of temp table #FilterTable.'
		IF @Version = '2.1.2.2179' SET @Description = 'Optional Parameter @FiscalYear added.'
		IF @Version = '2.1.2.2180' SET @Description = 'Set temporary fix for Bradken when Intercompany property is not set for Account dimension.'
		IF @Version = '2.1.2.2181' SET @Description = 'Updated version of temp table #FilterTable.'
		IF @Version = '2.1.2.2183' SET @Description = 'Removed extra brackets around @ICCounterpart.'
		IF @Version = '2.1.2.2185' SET @Description = 'Removed property filters from Journal filters (@SQLFilter).'
		IF @Version = '2.1.2.2186' SET @Description = 'Implement Variable @ID in cursor and dynamic @StepReference.'
		IF @Version = '2.1.2.2187' SET @Description = 'Handle other dataclass source than Journal.'
		IF @Version = '2.1.2.2192' SET @Description = 'Handle MappingTypeID <> 0 and multiple Property rules.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = [DestinationDatabase],
			@ETLDatabase = [ETLDatabase]
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT, @JobID=@JobID, @Debug=@DebugSub			

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@JournalTable] = @JournalTable,
				[@FromTime] = @FromTime,
				[@ToTime] = @ToTime

	SET @Step = 'CREATE TABLE #FilterTable'
		IF OBJECT_ID(N'TempDB.dbo.#FilterTable', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

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
			END

	SET @Step = 'CREATE TABLE #Entity'
		CREATE TABLE #Entity
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[EntityOwner] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[ValidFrom] date,
			[OwnershipShare] float
			)

		INSERT INTO #Entity
			(
			[Entity],
			[EntityOwner],
			[ValidFrom],
			[OwnershipShare]
			)
		SELECT
			[Entity] = E.[MemberKey],
			[EntityOwner] = EOE.[MemberKey],
			[ValidFrom] = EO.[ValidFrom],
			[OwnershipShare] = EO.[OwnershipShare]
		FROM
			pcINTEGRATOR_Data..Entity E
			LEFT JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Ownership] EO ON EO.[InstanceID] = E.InstanceID AND EO.[VersionID] = E.VersionID AND EO.EntityID = E.EntityID AND EO.OwnershipShare >= 0.5
			LEFT JOIN pcINTEGRATOR_Data..Entity EOE ON EOE.[InstanceID] = EO.InstanceID AND EOE.[VersionID] = EO.VersionID AND EOE.EntityID = EO.EntityOwnerID AND EOE.[SelectYN] <> 0 AND EOE.[DeletedID] IS NULL
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[SelectYN] <> 0 AND
			E.[DeletedID] IS NULL

		IF @DebugBM & 2 > 0 SELECT TempTabel = '#Entity', * FROM #Entity

	SET @Step = 'CREATE TABLE #SegmentEntity'
		CREATE TABLE #SegmentEntity
			(
			[DimensionID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SegmentNo] int
			)

	SET @Step = 'CREATE TABLE #SegmentEntity'
		CREATE TABLE #SegmentDimension
			(
			[DimensionID] int,
			[SegmentNo] int
			)

	SET @Step = 'Fill temp table #BR14_Cursor_Table'
		CREATE TABLE [#BR14_Cursor_Table]
			(
			[ID] int IDENTITY(1001, 1),
			[Comment] [nvarchar](1024) COLLATE DATABASE_DEFAULT,
			[ICCounterpart] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[Method] [nvarchar] (20) COLLATE DATABASE_DEFAULT,
			[DimensionFilter] [nvarchar](4000) COLLATE DATABASE_DEFAULT,
			[SortOrder] [int]
			)

		INSERT INTO [#BR14_Cursor_Table]
			(
			[Comment],
			[ICCounterpart],
			[Method],
			[DimensionFilter],
			[SortOrder]
			)
		SELECT
			[Comment],
			[ICCounterpart],
			[Method],
			[DimensionFilter],
			[SortOrder]
		FROM 
			[pcINTEGRATOR_Data].[dbo].[BR14_Step]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#BR14_Cursor_Table', * FROM [#BR14_Cursor_Table] ORDER BY SortOrder

	SET @Step = 'Run BR14_Cursor'
		IF CURSOR_STATUS('global','BR14_Cursor') >= -1 DEALLOCATE BR14_Cursor
		DECLARE BR14_Cursor CURSOR FOR
			SELECT 
				[ID],
				[ICCounterpart],
				[Method],
				[DimensionFilter]
			FROM
				[#BR14_Cursor_Table]
			ORDER BY
				[SortOrder]

			OPEN BR14_Cursor
			FETCH NEXT FROM BR14_Cursor INTO @ID, @ICCounterpart, @Method, @DimensionFilter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @StepReference = 'BR14_' + CONVERT(nvarchar(15), @ID)

					IF @DebugBM & 2 > 0 SELECT [Cursor] = 'BR14_Cursor', [@ID] = @ID, [@StepReference] = @StepReference, [@ICCounterpart] = @ICCounterpart, [@Method] = @Method, [@DimensionFilter]=@DimensionFilter

					--TRUNCATE TABLE #FilterTable
					
					EXEC [dbo].[spGet_FilterTable]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@StepReference = @StepReference,
						@PipeString = @DimensionFilter, --Mandatory
						@DatabaseName = @CallistoDatabase, --Mandatory
						@StorageTypeBM_DataClass = 1, --3 returns _MemberKey, 4 returns _MemberId
						@StorageTypeBM = 4, --Mandatory
						@SQLFilter = @SQLFilter OUT,
						@JobID = @JobID

					IF @Method = 'Property'
						BEGIN
							INSERT INTO #FilterTable
								(
								[StepReference],
								[DimensionID],
								[DimensionTypeID],
								[Segment],
								[DimensionName],
								[HierarchyName],
								[PropertyName],
								[EqualityString],
								[Filter],
								[LeafLevelFilter],
								[PropertyFilter],
								[Method]
								)
							SELECT
								[StepReference] = @StepReference,
								[DimensionID] = NULL,
								[DimensionTypeID] = NULL,
								[Segment] = NULL,
								[DimensionName] = REPLACE(REPLACE(LEFT(@ICCounterpart, CHARINDEX('.', @ICCounterpart) -1),'[', ''), ']', ''),
								[HierarchyName] = NULL,
								[PropertyName] = NULL,
								[EqualityString] = NULL,
								[Filter] = NULL,
								[LeafLevelFilter] = NULL,
								[PropertyFilter] = NULL,
								[Method] = 'Property'
							WHERE
								NOT EXISTS (SELECT 1 FROM #FilterTable FT WHERE FT.[StepReference] = @StepReference AND FT.[DimensionName] = LEFT(@ICCounterpart, CHARINDEX('.', @ICCounterpart) -1))

							SET @Inserted = @@ROWCOUNT
							
							IF @Inserted = 1
								BEGIN
									UPDATE FT
									SET
										[DimensionID] = D.[DimensionID]
									FROM
										#FilterTable FT
										INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = FT.DimensionName
									WHERE
										FT.[StepReference] = @StepReference
								END
						END

					UPDATE FT
					SET
						DimensionTypeID = D.DimensionTypeID
					FROM
						#FilterTable FT
						INNER JOIN Dimension D ON D.DimensionID = FT.DimensionID
					WHERE
						FT.[StepReference] = @StepReference
	
					IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = @StepReference

					--SegmentEntity
					TRUNCATE TABLE #SegmentEntity
					INSERT INTO #SegmentEntity
						(
						[DimensionID],
						[DimensionName],
						[Entity],
						[SegmentNo]
						)
					SELECT
						[DimensionID] = FT.[DimensionID],
						[DimensionName] = FT.[DimensionName],
						[Entity] = E.[MemberKey],
						[SegmentNo] = JSN.[SegmentNo]
					FROM
						#FilterTable FT
						INNER JOIN pcINTEGRATOR_Data..Journal_SegmentNo JSN ON JSN.InstanceID = @InstanceID AND JSN.VersionID = @VersionID AND JSN.DimensionID = FT.DimensionID AND JSN.SelectYN <> 0
						INNER JOIN pcINTEGRATOR_Data..Entity E ON E.InstanceID = JSN.InstanceID AND E.VersionID = JSN.VersionID AND E.EntityID = JSN.EntityID AND E.SelectYN <> 0 AND E.DeletedID IS NULL
					WHERE
						FT.[StepReference] = @StepReference AND
						FT.[DimensionTypeID] = -1

					IF @DebugBM & 2 > 0 SELECT TempTable = '#SegmentEntity', * FROM #SegmentEntity

					--SegmentDimension
					TRUNCATE TABLE #SegmentDimension
					INSERT INTO #SegmentDimension
						(
						[DimensionID],
						[SegmentNo]
						)
					SELECT DISTINCT
						DimensionID,
						SegmentNo
					FROM
						#SegmentEntity

					IF CURSOR_STATUS('global','SegmentDimension_Cursor') >= -1 DEALLOCATE SegmentDimension_Cursor
					DECLARE SegmentDimension_Cursor CURSOR FOR
			
						SELECT DISTINCT
							DimensionID
						FROM
							#SegmentDimension

						OPEN SegmentDimension_Cursor
						FETCH NEXT FROM SegmentDimension_Cursor INTO @DimensionID

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [NoOfMappings] = (SELECT COUNT(1) FROM #SegmentDimension WHERE DimensionID = @DimensionID)

								IF (SELECT COUNT(1) FROM #SegmentDimension WHERE DimensionID = @DimensionID) = 1
									BEGIN
										UPDATE FT
										SET
											[Segment] = 'Segment' + CASE WHEN SD.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), SD.[SegmentNo])
										FROM
											#FilterTable FT
											INNER JOIN #SegmentDimension SD ON SD.[DimensionID] = FT.[DimensionID]
										WHERE
											FT.[StepReference] = @StepReference AND
											FT.[DimensionID] = @DimensionID

										IF @DebugBM & 2  > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = @StepReference
									END
								ELSE
									BEGIN
										PRINT 'Spread segment mapping not yet handled'
									END
								
								FETCH NEXT FROM SegmentDimension_Cursor INTO @DimensionID
							END

					CLOSE SegmentDimension_Cursor
					DEALLOCATE SegmentDimension_Cursor
					
					SET @SQLFilter = ''
					SELECT
						@SQLFilter = @SQLFilter + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'J.[' + CASE WHEN FT.DimensionTypeID = -1 THEN FT.[Segment] ELSE FT.[DimensionName] END + '] ' + [EqualityString] + ' (' + [LeafLevelFilter] + ') AND'
					FROM
						#FilterTable FT
					WHERE
						FT.[StepReference] = @StepReference AND
						LEN(FT.[LeafLevelFilter]) > 0 AND
--						ISNULL([PropertyName], '') = '' AND
						(
						NOT (FT.[DimensionTypeID] = -1 AND FT.[Segment] IS NULL) OR
						JournalColumn = DimensionName
						)
					ORDER BY
						DimensionID

					IF LEN(@SQLFilter) > 3
						SET @SQLFilter = LEFT(@SQLFilter, LEN(@SQLFilter) - 3)

					IF @DebugBM & 2 > 0 SELECT [@SQLFilter] = @SQLFilter
					IF @DebugBM & 2 > 0 
						SELECT
							TempTable = '#FilterTable', FT.* 
						FROM #FilterTable FT
						WHERE 
							FT.[StepReference] = @StepReference AND
							LEN(FT.[LeafLevelFilter]) > 0 AND
	--						ISNULL([PropertyName], '') = '' AND
							(NOT (FT.[DimensionTypeID] = -1 AND FT.[Segment] IS NULL) OR
							JournalColumn = DimensionName) AND
							1=1

					--Property_Cursor
					SET @SQLJoin = ''

					IF CURSOR_STATUS('global','Property_Cursor') >= -1 DEALLOCATE Property_Cursor
					DECLARE Property_Cursor CURSOR FOR
			
						SELECT DISTINCT
							[PropertyDimension] = FT.[DimensionName],
							[Segment] = FT.[Segment],
							[DimMethod] = FT.[Method],
							[PropertyLen] = LEN(ISNULL([PropertyName], '')),
							[MappingTypeID] = DST.[MappingTypeID]
						FROM
							#FilterTable FT
							INNER JOIN pcINTEGRATOR_Data..Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = FT.DimensionID
						WHERE
							[StepReference] = @StepReference AND
							(LEN(FT.PropertyName) > 0 OR [Method] = 'Property')
						ORDER BY
							FT.[DimensionName]

						OPEN Property_Cursor
						FETCH NEXT FROM Property_Cursor INTO @PropertyDimension, @Segment, @DimMethod, @PropertyLen, @MappingTypeID

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@PropertyDimension] = @PropertyDimension, [@Segment] = @Segment, [@DimMethod] = @DimMethod, [@PropertyLen] = @PropertyLen, [@MappingTypeID] = @MappingTypeID

								--SET @SQLJoin = ''

								IF @DimMethod = 'Property' AND @PropertyLen = 0
									BEGIN
										SET @SQLJoin = @SQLJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @PropertyDimension + '] [' + @PropertyDimension + '] ON [' + @PropertyDimension + '].[' + CASE WHEN @MappingTypeID > 0 THEN 'MemberKeyBase' ELSE 'Label' END + '] = J.[' + ISNULL(@Segment, @PropertyDimension) + ']' + CASE WHEN @MappingTypeID > 0 THEN '[' + @PropertyDimension + '].[Entity] = J.[Entity]' ELSE '' END
									END
								ELSE
									BEGIN
										SET @SQLJoin = @SQLJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @PropertyDimension + '] [' + @PropertyDimension + '] ON [' + @PropertyDimension + '].[' + CASE WHEN @MappingTypeID > 0 THEN 'MemberKeyBase' ELSE 'Label' END + '] = J.[' + @PropertyDimension + ']' + CASE WHEN @MappingTypeID > 0 THEN '[' + @PropertyDimension + '].[Entity] = J.[Entity]' ELSE '' END

										SELECT
											@SQLJoin = @SQLJoin + ' AND [' + @PropertyDimension + '].[' + [PropertyName] + '] IN (''' + [Filter] + ''')'
										FROM
											#FilterTable
										WHERE
											[StepReference] = @StepReference AND
											[DimensionName] = @PropertyDimension AND
											LEN([PropertyName]) > 0
										ORDER BY
											[PropertyName]
									END
								
								FETCH NEXT FROM Property_Cursor INTO @PropertyDimension, @Segment, @DimMethod, @PropertyLen, @MappingTypeID
							END

					CLOSE Property_Cursor
					DEALLOCATE Property_Cursor

					IF @DebugBM & 2 > 0 SELECT [@JournalTable]=@JournalTable, [@DimensionName]=@DimensionName, [@ICCounterpart]=@ICCounterpart, [@SQLJoin]=@SQLJoin, [@SQLFilter]=@SQLFilter, [@FromTime]=@FromTime, [@ToTime]=@ToTime
					
					IF @Method = 'Fixed'
						BEGIN
							SET @SQLStatement = '
								UPDATE J
								SET
									[InterCompanyEntity] = ''' + @ICCounterpart + '''
								FROM
									' + @JournalTable + ' J
									' + @SQLJoin + '
								WHERE
									1=1'
									+ CASE WHEN @JournalTable = '#JournalBase' THEN '' ELSE ' AND J.[ConsolidationGroup] IS NULL' END
									+ CASE WHEN LEN(@FiscalYear) > 3 THEN ' AND J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) ELSE '' END
									+ CASE WHEN LEN(@FromTime) > 3 THEN ' AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END
									+ CASE WHEN LEN(@ToTime) > 3 THEN ' AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END
									+ CASE WHEN LEN(@SQLFilter) > 3 THEN ' AND ' + @SQLFilter ELSE '' END
						END

					ELSE IF @Method = 'Property'
						BEGIN
							SET @ICCounterpart = '[' + REPLACE(REPLACE(REPLACE(@ICCounterpart, ']', ''), '[', ''), '.', '].[') + ']'

							SET @SQLStatement = '
								UPDATE J
								SET
									[InterCompanyEntity] = E.[Entity]
								FROM
									' + @JournalTable + ' J
									' + @SQLJoin + '
									INNER JOIN #Entity E ON E.[Entity] = ' + @ICCounterpart + '
								WHERE
									1=1'
									+ CASE WHEN @JournalTable = '#JournalBase' THEN '' ELSE ' AND J.[ConsolidationGroup] IS NULL' END
									+ CASE WHEN LEN(@FiscalYear) > 3 THEN ' AND J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) ELSE '' END
									+ CASE WHEN LEN(@FromTime) > 3 THEN ' AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END
									+ CASE WHEN LEN(@ToTime) > 3 THEN ' AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END
									+ CASE WHEN LEN(@SQLFilter) > 3 THEN ' AND ' + @SQLFilter ELSE '' END
						END

					ELSE IF @Method = 'Owner'
						BEGIN
							SET @SQLStatement = '
								UPDATE J
								SET
									[InterCompanyEntity] = E.[EntityOwner]
								FROM
									' + @JournalTable + ' J
									' + @SQLJoin + '
									INNER JOIN #Entity E ON E.[Entity] = J.[Entity] AND E.[EntityOwner] IS NOT NULL
								WHERE
									1=1'
									+ CASE WHEN @JournalTable = '#JournalBase' THEN '' ELSE ' AND J.[ConsolidationGroup] IS NULL' END
									+ CASE WHEN LEN(@FiscalYear) > 3 THEN ' AND J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) ELSE '' END
									+ CASE WHEN LEN(@FromTime) > 3 THEN ' AND J.[YearMonth] >= ' + CONVERT(nvarchar(15), @FromTime) ELSE '' END
									+ CASE WHEN LEN(@ToTime) > 3 THEN ' AND J.[YearMonth] <= ' + CONVERT(nvarchar(15), @ToTime) ELSE '' END
									+ CASE WHEN LEN(@SQLFilter) > 3 THEN ' AND ' + @SQLFilter ELSE '' END
						END

					IF @DebugBM & 2 > 0 PRINT '@ID = ' + CONVERT(nvarchar(15), @ID) + ', @StepReference] = ' + @StepReference + CHAR(13) + CHAR(10) + @SQLStatement
					EXEC (@SQLStatement)

					SET @Updated = @Updated + @@ROWCOUNT

					FETCH NEXT FROM BR14_Cursor INTO @ID, @ICCounterpart, @Method, @DimensionFilter
				END

		CLOSE BR14_Cursor
		DEALLOCATE BR14_Cursor	

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0 DROP TABLE #FilterTable
		DROP TABLE #BR14_Cursor_Table
		DROP TABLE #Entity

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
