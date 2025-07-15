SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_AutoMultiDimFilter]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@DimensionID int = NULL,
	@DimensionName nvarchar(50) = NULL,
	@HierarchyNo int = NULL,
	@HierarchyName nvarchar(50) = NULL,
	@MemberID bigint = NULL,
	@MemberKey nvarchar(100) = NULL,
	@StorageTypeBM_DataClass int = 1, --1 returns formatted for Journal, 2 returns _MemberKey, 4 returns _MemberId, 
	@LeafLevelFilter nvarchar(max) = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000760,
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
DECLARE @LeafLevelFilter nvarchar(max) = ''
EXEC [spGet_AutoMultiDimFilter]
	@UserID = -10,
	@InstanceID = 529,
	@VersionID = 1001,
	@DimensionID = -53,
	@DimensionName = 'FullAccount',
	@HierarchyNo = 2,
	@HierarchyName = 'Bal_Carrier',
	@MemberKey = 'CA_Balance Sheet',
	@StorageTypeBM_DataClass = 2,
	@LeafLevelFilter = @LeafLevelFilter OUT,
	@JobID = 0,
	@DebugBM = 0
SELECT [@LeafLevelFilter] = @LeafLevelFilter

DECLARE @LeafLevelFilter nvarchar(max) = ''
EXEC [dbo].[spGet_AutoMultiDimFilter]
	@UserID = -10,
	@InstanceID = 574,
	@VersionID = 1045,
	@DimensionID = 9188,
	@DimensionName = 'FullAccount',
	@HierarchyNo = 0,
	@HierarchyName = 'FullAccount',
	@MemberKey = 'I_',
	@StorageTypeBM_DataClass = 4,
	@LeafLevelFilter = @LeafLevelFilter OUT,
	@JobID = 0,
	@Debug = 1
SELECT [@LeafLevelFilter] = @LeafLevelFilter	

EXEC [spGet_AutoMultiDimFilter] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spGet_AutoMultiDimFilter] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@StorageTypeBM int,
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@MultiMemberID bigint,
	@DimensionMemberID bigint,
	@DimensionMemberKey nvarchar(50),
	@MultiDimensionName nvarchar(50),
	@EntityID int,
	@Count int,
	@SqlSet nvarchar(4000) = '',
	@MultiDim_DimensionName nvarchar(50) = NULL,

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
	@Version nvarchar(50) = '2.1.1.2177'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get filter for AutoMultiDim',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2169' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2177' SET @Description = 'Remove hard coded segments.'

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
			@DimensionID = ISNULL(@DimensionID, [DimensionID]),
			@DimensionName = ISNULL(@DimensionName, [DimensionName]),
			@MultiDim_DimensionName = ISNULL(@DimensionName, [DimensionName])
		FROM
			[pcINTEGRATOR].[dbo].[Dimension] D
		WHERE
			[InstanceID] IN (0, @InstanceID) AND
			([DimensionID] = @DimensionID OR @DimensionID IS NULL) AND
			([DimensionName] = @DimensionName OR @DimensionName IS NULL)

		IF @HierarchyNo IS NOT NULL OR @HierarchyName IS NOT NULL
			SELECT
				@HierarchyNo = ISNULL(@HierarchyNo, [HierarchyNo]),
				@HierarchyName = ISNULL(@HierarchyName, [HierarchyName])
			FROM
				[pcINTEGRATOR].[dbo].[DimensionHierarchy] H
			WHERE
				[InstanceID] IN (0, @InstanceID) AND
				[VersionID] IN (0, @VersionID) AND
				[DimensionID] = @DimensionID AND
				([HierarchyNo] = @HierarchyNo OR @HierarchyNo IS NULL) AND
				([HierarchyName] = @HierarchyName OR @HierarchyName IS NULL)
		ELSE
			SELECT
				@HierarchyNo = 0,
				@HierarchyName = @DimensionName

		SELECT
			@StorageTypeBM = StorageTypeBM
		FROM
			pcINTEGRATOR_Data..Dimension_StorageType
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DimensionID] = @DimensionID

		SELECT	
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		IF @StorageTypeBM & 4 > 0

		IF @MemberID IS NULL
			BEGIN
				SET @SQLStatement = '
					SELECT @InternalVariable = [MemberID] FROM ' + @CallistoDatabase + '.dbo.[S_DS_' + @DimensionName + '] WHERE [Label] = ''' + @MemberKey + ''''
				EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @MemberID OUT
			END

		IF @MemberKey IS NULL
			BEGIN
				SET @SQLStatement = '
					SELECT @InternalVariable = [Label] FROM ' + @CallistoDatabase + '.dbo.[S_DS_' + @DimensionName + '] WHERE [MemberId] = ' + CONVERT(nvarchar(20), @MemberID)
				EXEC sp_executesql @SQLStatement, N'@InternalVariable nvarchar(100) OUT', @InternalVariable = @MemberKey OUT
			END

		SET @MultiDimensionName = @DimensionName

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@CallistoDatabase] = @CallistoDatabase,
				[@Entity_MemberKey] = @Entity_MemberKey,
				[@DimensionID] = @DimensionID,
				[@MultiDimensionName] = @MultiDimensionName,
				[@StorageTypeBM] = @StorageTypeBM,
				[@HierarchyNo] = @HierarchyNo,
				[@HierarchyName] = @HierarchyName,
				[@MemberID] = @MemberID,
				[@MemberKey] = @MemberKey,
				[@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass

	SET @Step = 'Create and fill #AutoMultiDim'
		IF OBJECT_ID(N'TempDB.dbo.#AutoMultiDim', N'U') IS NULL
			BEGIN
				CREATE TABLE #AutoMultiDim
					(
					MultiDimensionID int,
					DimensionID int,
					DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT,
					JournalColumn nvarchar(50) COLLATE DATABASE_DEFAULT,
					SortOrder int
					)

				INSERT INTO #AutoMultiDim
					(
					[MultiDimensionID],
					[DimensionID],
					[DimensionName],
					[SortOrder]
					)
				SELECT
					[MultiDimensionID] = @DimensionID,
					[DimensionID] = P.[DependentDimensionID],
					[DimensionName] = D.[DimensionName],
					[SortOrder] = DP.[SortOrder]
				FROM
					[pcINTEGRATOR].[dbo].[Dimension_Property] DP
					INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.PropertyID = DP.PropertyID AND P.DataTypeID = 3 AND P.SelectYN <> 0
					INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.DimensionID = P.DependentDimensionID AND D.DimensionTypeID IN (1, -1)
				WHERE 
					DP.[InstanceID] IN (0, @InstanceID) AND
					DP.[VersionID] IN (0, @VersionID) AND
					DP.[DimensionID] = @DimensionID AND
					DP.[MultiDimYN] <> 0 AND
					DP.[SelectYN] <> 0

				IF @DebugBM & 2 > 0 SELECT TempTable = '#AutoMultiDim', * FROM #AutoMultiDim ORDER BY [SortOrder]
--SELECT TempTable = '#AutoMultiDim', * FROM #AutoMultiDim ORDER BY [SortOrder]
			END
--SELECT TempTable = '#AutoMultiDim', * FROM #AutoMultiDim ORDER BY [SortOrder]
	SET @Step = 'Get Leaf level members'
		CREATE TABLE #Hierarchy
			(
			[MemberID] bigint,
			[ParentMemberID] bigint
			)
		
		SET @SQLStatement = '
			INSERT INTO #Hierarchy
				(
				[MemberID],
				[ParentMemberID]
				)
			SELECT 
				[MemberID],
				[ParentMemberID]
			FROM
				' + @CallistoDatabase + '..S_HS_' + @DimensionName + '_' +  @HierarchyName

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		CREATE TABLE #MultiMember
			(
			MultiMemberID bigint
			)

		CREATE TABLE #Member
			(
			MemberID bigint
			)

	SET @Step = 'Run cursor for adding columns to temp tables for data'
		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT
				[DimensionName]
			FROM
				(
				SELECT 
					[DimensionName] = AMD.[DimensionName],
					[SortOrder] = MIN(AMD.[SortOrder])
				FROM
					#AutoMultiDim AMD
--				WHERE
--					MultiDimensionID = @DimensionID
				GROUP BY
					AMD.[DimensionName]
				) sub
			ORDER BY
				[SortOrder],
				[DimensionName]
		

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						ALTER TABLE #MultiMember ADD [' + @DimensionName + '_MemberId] bigint'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					FETCH NEXT FROM AddColumn_Cursor INTO  @DimensionName
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

		CREATE TABLE #MultiDimRows
			(
			MultiMemberID bigint,
			DimensionName nvarchar(50) COLLATE DATABASE_DEFAULT,
			DimensionMemberID bigint,
			DimensionMemberKey nvarchar(50)
			)

		;WITH cte AS
			(
			SELECT
				H.[MemberId],
				H.[ParentMemberId],
				Depth = 1
			FROM
				#Hierarchy H
			WHERE
				H.[MemberId] = @MemberID
			UNION ALL
			SELECT
				H.[MemberId],
				H.[ParentMemberId],
				C.Depth + 1
			FROM
				#Hierarchy H
				INNER JOIN cte c on c.[MemberId] = H.[ParentMemberId]
			)

		INSERT INTO #MultiMember
			(
			MultiMemberID
			)
		SELECT 
			MultiMemberID = CTE.MemberID
		FROM
			CTE
		WHERE
			NOT EXISTS (SELECT 1 FROM #Hierarchy H WHERE H.[ParentMemberID] = CTE.[MemberID])
--RETURN

--RETURN

	SET @Step = 'Set @LeafLevelFilter'
		IF @DebugBM & 2 > 0 SELECT 'Arne1'

		IF @StorageTypeBM_DataClass & 1 > 0 --Journal
			BEGIN
				--'Multi_Cursor'
				IF CURSOR_STATUS('global','Multi_Cursor') >= -1 DEALLOCATE Multi_Cursor
				DECLARE Multi_Cursor CURSOR FOR
			
					SELECT 
						MultiMemberID
					FROM
						#MultiMember
					ORDER BY
						MultiMemberID

					OPEN Multi_Cursor
					FETCH NEXT FROM Multi_Cursor INTO @MultiMemberID

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@MultiMemberID] = @MultiMemberID

							IF CURSOR_STATUS('global','MultiRow_Cursor') >= -1 DEALLOCATE MultiRow_Cursor
							DECLARE MultiRow_Cursor CURSOR FOR
			
								SELECT 
									DimensionName
								FROM
									#AutoMultiDim
								ORDER BY
									DimensionID

								OPEN MultiRow_Cursor
								FETCH NEXT FROM MultiRow_Cursor INTO @DimensionName

								WHILE @@FETCH_STATUS = 0
									BEGIN
										IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName

										SET @SQLStatement = '
											SELECT
												@InternalVariable1 = [' + @DimensionName + '_MemberId],
												@InternalVariable2 = [' + @DimensionName + '] 
											FROM 
												' + @CallistoDatabase + '.[dbo].[S_DS_' + @MultiDimensionName + ']
											WHERE
												[MemberID] = ' + CONVERT(nvarchar(20), @MultiMemberID)

										EXEC sp_executesql @SQLStatement, N'@InternalVariable1 bigint OUT, @InternalVariable2 nvarchar(50) OUT', @InternalVariable1 = @DimensionMemberID OUT, @InternalVariable2 = @DimensionMemberKey OUT

										INSERT INTO #MultiDimRows
											(
											MultiMemberID,
											DimensionName,
											DimensionMemberID,
											DimensionMemberKey
											)
										SELECT
											MultiMemberID = @MultiMemberID,
											DimensionName = @DimensionName,
											DimensionMemberID = @DimensionMemberID,
											DimensionMemberKey = @DimensionMemberKey

										FETCH NEXT FROM MultiRow_Cursor INTO @DimensionName
									END

							CLOSE MultiRow_Cursor
							DEALLOCATE MultiRow_Cursor

							FETCH NEXT FROM Multi_Cursor INTO @MultiMemberID
						END

				CLOSE Multi_Cursor
				DEALLOCATE Multi_Cursor

				IF @DebugBM & 2 > 0 SELECT TempTable = '#MultiDimRows', * FROM #MultiDimRows ORDER BY MultiMemberID, DimensionName

				IF @Entity_MemberKey IS NULL
					BEGIN
						SELECT
							EntityID,
							NoOfSegment = COUNT(1)
						INTO
							#CountSegment
						FROM
							pcINTEGRATOR_Data..[Journal_SegmentNo] JSN
						WHERE
							JSN.InstanceID = @InstanceID AND
							JSN.VersionID = @VersionID AND
							JSN.SelectYN <> 0
						GROUP BY
							EntityID

						SELECT @Count = MAX(NoOfSegment) FROM #CountSegment

						SELECT @EntityID = MIN(EntityID) FROM #CountSegment WHERE NoOfSegment = @Count
					END

				SELECT 
					@EntityID = ISNULL(@EntityID, [EntityID])
				FROM
					pcINTEGRATOR_Data..[Entity] E
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.MemberKey = @Entity_MemberKey AND
					E.SelectYN <> 0 AND
					E.DeletedID IS NULL

				SELECT
					@Book = ISNULL(@Book, EB.[Book])
				FROM
					pcINTEGRATOR_Data..[Entity_Book] EB
				WHERE
					EB.InstanceID = @InstanceID AND
					EB.VersionID = @VersionID AND
					EB.EntityID = @EntityID AND
					EB.BookTypeBM & 2 > 0 AND
					EB.SelectYN <> 0

				UPDATE AMD
				SET
					JournalColumn = CASE WHEN AMD.DimensionID = -1 THEN 'Account' ELSE 'Segment' + CASE WHEN JSN.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.SegmentNo) END
				FROM
					#AutoMultiDim AMD
					INNER JOIN pcINTEGRATOR_Data..Journal_SegmentNo JSN ON JSN.InstanceID = @InstanceID AND JSN.VersionID = @VersionID AND JSN.EntityID = @EntityID AND JSN.Book = @Book AND JSN.DimensionID = AMD.DimensionID
				
				IF @DebugBM & 2 > 0 SELECT TempTable = '#AutoMultiDim', * FROM #AutoMultiDim ORDER BY [SortOrder]

				SET @LeafLevelFilter = ''
				
				IF @DebugBM & 2 > 0 	
					SELECT DISTINCT
						MultiMemberID
					FROM
						#MultiMember
					ORDER BY
						MultiMemberID

				IF CURSOR_STATUS('global','JournalFilter_Cursor') >= -1 DEALLOCATE JournalFilter_Cursor
				DECLARE JournalFilter_Cursor CURSOR FOR
			
					SELECT DISTINCT
						MultiMemberID
					FROM
						#MultiMember
					ORDER BY
						MultiMemberID

					OPEN JournalFilter_Cursor
					FETCH NEXT FROM JournalFilter_Cursor INTO @MultiMemberID

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@MultiMemberID] = @MultiMemberID

							SET @LeafLevelFilter = @LeafLevelFilter + '('

							SELECT
								@LeafLevelFilter = @LeafLevelFilter + '[' + AMD.[JournalColumn] + '] IN (' + CASE WHEN MDR.[DimensionMemberKey] = 'NONE' THEN ''''',' ELSE '' END + '''' + MDR.[DimensionMemberKey] + '''' + ') AND '
							FROM
								#MultiDimRows MDR
								INNER JOIN #AutoMultiDim AMD ON AMD.DimensionName = MDR.DimensionName
							WHERE
								MDR.MultiMemberID = @MultiMemberID
							ORDER BY
								AMD.[JournalColumn]

							SET @LeafLevelFilter = LEFT(@LeafLevelFilter, LEN(@LeafLevelFilter) -4) + ') OR '

							FETCH NEXT FROM JournalFilter_Cursor INTO @MultiMemberID
						END

				CLOSE JournalFilter_Cursor
				DEALLOCATE JournalFilter_Cursor

				SET @LeafLevelFilter = LEFT(@LeafLevelFilter, LEN(@LeafLevelFilter) -3)

				IF @DebugBM & 1 > 0 SELECT [@LeafLevelFilter] = @LeafLevelFilter
			END

		ELSE IF @StorageTypeBM_DataClass & 2 > 0 --MemberKey
			BEGIN
				SELECT 'Not yet implemented'
			END

		ELSE IF @StorageTypeBM_DataClass & 4 > 0 --MemberID
			BEGIN
				IF @DebugBM & 2 > 0 SELECT TempTable = '#MultiMember', * FROM #MultiMember

				SELECT
					@SqlSet = @SqlSet + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + AMD.[DimensionName] + '_MemberId] = D.[' + AMD.[DimensionName] + '_MemberId],'
				FROM
					#AutoMultiDim AMD
				ORDER BY
					AMD.[SortOrder]

				SET @SQLStatement = '
					UPDATE MM
					SET' + LEFT(@SqlSet, LEN(@SqlSet) - 1) + '
					FROM
						#MultiMember MM
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @MultiDim_DimensionName + '] D ON D.[MemberId] = MM.[MultiMemberID]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#MultiMember', * FROM #MultiMember

				SET @LeafLevelFilter = ''
				
				IF CURSOR_STATUS('global','JournalFilter_Cursor') >= -1 DEALLOCATE JournalFilter_Cursor
				DECLARE JournalFilter_Cursor CURSOR FOR
			
					SELECT 
						[DimensionName]
					FROM
						#AutoMultiDim
					ORDER BY
						[SortOrder],
						[DimensionName]

					OPEN JournalFilter_Cursor
					FETCH NEXT FROM JournalFilter_Cursor INTO @DimensionName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName

							TRUNCATE TABLE #Member
							
							SET @SQLStatement = '
								INSERT INTO #Member
									(
									MemberID
									)
								SELECT DISTINCT
									MemberID = [' + @DimensionName + '_MemberId]
								FROM
									#MultiMember
								WHERE
									[' + @DimensionName + '_MemberId] IS NOT NULL'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							IF @DebugBM & 2 > 0 SELECT TempTable = '#Member', Dimension = @DimensionName, * FROM #Member ORDER BY MemberID

							SET @LeafLevelFilter = @LeafLevelFilter + 'DC.[' + @DimensionName + '_MemberId] IN ('
							
							SELECT
								@LeafLevelFilter = @LeafLevelFilter + CONVERT(nvarchar(20), [MemberID]) + ','
							FROM
								#Member
							ORDER BY
								[MemberID]

							SET @LeafLevelFilter = LEFT(@LeafLevelFilter, LEN(@LeafLevelFilter) - 1) + ') AND '

							FETCH NEXT FROM JournalFilter_Cursor INTO @DimensionName
						END

				CLOSE JournalFilter_Cursor
				DEALLOCATE JournalFilter_Cursor

				SET @LeafLevelFilter = LEFT(@LeafLevelFilter, LEN(@LeafLevelFilter) -3)

				IF @DebugBM & 1 > 0 SELECT [@LeafLevelFilter] = @LeafLevelFilter

			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #Hierarchy

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
