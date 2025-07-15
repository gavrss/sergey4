SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_HL_Table]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionName nvarchar(50) = NULL,
	@HierarchyName nvarchar(50) = NULL,
	@NoOfLevels int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 0,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000862,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spGet_HL_Table] @UserID=-10, @InstanceID=-1590, @VersionID=-1590, @DimensionName = 'Entity', @HierarchyName = 'Entity', @DebugBM=1
EXEC [spGet_HL_Table] @UserID=-10, @InstanceID=-1590, @VersionID=-1590, @DimensionName = 'Account', @HierarchyName = 'Account', @DebugBM=1

EXEC [spGet_HL_Table] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@Level int = 0,
	@SQLStatement nvarchar(max),
	@SQLStatementBase nvarchar(max),
	@SQLSetStatement nvarchar(max) = '',
	@SQLSelectStatement nvarchar(max) = '',
	@CallistoDatabase nvarchar(100),
	@MaxSortOrder int,
	@MemberId bigint,

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
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get depth of specified dimension hierarchy',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2191' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		IF @NoOfLevels IS NULL
			EXEC [spGet_NoOfLevels] @UserID=-10, @InstanceID=@InstanceID, @VersionID=@VersionID, @DimensionName = @DimensionName, @HierarchyName = @HierarchyName, @NoOfLevels = @NoOfLevels OUT, @Debug=@DebugSub

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@NoOfLevels] = @NoOfLevels

	SET @Step = 'Create temp table #HL_Table'
		IF OBJECT_ID(N'TempDB.dbo.#HL_Table', N'U') IS NULL
			BEGIN
				CREATE TABLE #HL_Table
					(
					[MemberId] bigint,
					[SequenceNumber] [bigint] IDENTITY(1,1)
					)
			END

			--Loop through all levels
			WHILE @Level < @NoOfLevels
				BEGIN
					SET @Level = @Level + 1
					
					SET @SQLStatement = '
						ALTER TABLE #HL_Table ADD [Parent_L' + CONVERT(nvarchar(15), @Level) + '] bigint'

						IF @DebugBM & 32 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)				
				END

		IF @DebugBM & 32 > 0 SELECT * FROM #HL_Table

	SET @Step = 'Create temp table #Hierarchy'
		CREATE TABLE #Hierarchy
			(
			[MemberId] bigint,
			[ParentMemberId] bigint,
			[SequenceNumber] bigint
			)
		
		SET @SQLStatement = '
			INSERT INTO #Hierarchy
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
				[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + ']'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 32 > 0 SELECT * FROM #Hierarchy ORDER BY [MemberId], [ParentMemberId], [SequenceNumber]

		INSERT INTO #HL_Table
			(
			[MemberId]
			)
		SELECT [MemberId] FROM #Hierarchy H WHERE NOT EXISTS (SELECT 1 FROM #Hierarchy H1 WHERE H1.ParentMemberId = H.MemberId) ORDER BY MemberId

		IF @DebugBM & 32 > 0 SELECT * FROM #HL_Table ORDER BY SequenceNumber

	SET @Step = 'CTE Loop'
		CREATE TABLE #Parent
			(
			[MemberId] bigint,
			[SortOrder] int IDENTITY(1,1)
			)

	SET @Step = 'Create Update Statement'
		SET @Level = 0

		WHILE @Level < @NoOfLevels
			BEGIN
				SET @Level = @Level + 1
				SELECT
					@SQLSetStatement = @SQLSetStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'Parent_L' + CONVERT(nvarchar(15), @Level) + ' = CASE WHEN sub.Parent_L' + CONVERT(nvarchar(15), @Level) + ' = 0 THEN @MemberId ELSE sub.Parent_L' + CONVERT(nvarchar(15), @Level) + ' END,',
					@SQLSelectStatement = @SQLSelectStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'Parent_L' + CONVERT(nvarchar(15), @Level) + ' = SUM(CASE WHEN SortOrder = @MaxSortOrder - ' + CONVERT(nvarchar(15), @Level - 1) + ' THEN [MemberId] ELSE 0 END),'
			END

		SET @SQLStatementBase = '
			UPDATE HL
			SET' + LEFT(@SQLSetStatement, LEN(@SQLSetStatement) - 1) + '
			FROM
				#HL_Table HL
				INNER JOIN
				(
				SELECT' + LEFT(@SQLSelectStatement, LEN(@SQLSelectStatement) - 1) + '
				FROM
					#Parent
				) sub ON 1 = 1
			WHERE
				HL.[MemberId] = @MemberId'

		IF @DebugBM & 2 > 0 PRINT @SQLStatementBase

	SET @Step = 'HL_Cursor'
		IF CURSOR_STATUS('global','HL_Cursor') >= -1 DEALLOCATE HL_Cursor
		DECLARE HL_Cursor CURSOR FOR
			
			SELECT 
				[MemberId]
			FROM
				#HL_Table
			ORDER BY
				[SequenceNumber]
				

			OPEN HL_Cursor
			FETCH NEXT FROM HL_Cursor INTO @MemberId

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 32 > 0 SELECT [@MemberId] = @MemberId
					TRUNCATE TABLE #Parent

					;WITH cte AS
					(
						--Find bottom nodes for tree
						SELECT
							H.[MemberID],
							H.[ParentMemberID]
						FROM
							#Hierarchy H
						WHERE
							H.[MemberID] = @MemberId
						UNION ALL
						SELECT
							H.[MemberID],
							H.[ParentMemberID]
						FROM
							#Hierarchy H
							INNER JOIN cte c on c.[ParentMemberID] = H.[MemberID]
					)
					INSERT INTO #Parent
						(
						[MemberId]
						)
					SELECT
						cte.[MemberId]
					FROM
						cte

					IF @DebugBM & 32 > 0 SELECT * FROM #Parent ORDER BY SortOrder DESC
					
					SELECT @MaxSortOrder = MAX(SortOrder) FROM #Parent
					IF @DebugBM & 32 > 0 SELECT [@MaxSortOrder] = @MaxSortOrder

					SET @SQLStatement = REPLACE (@SQLStatementBase, '@MemberId', @MemberId)
					SET @SQLStatement = REPLACE (@SQLStatement, '@MaxSortOrder', @MaxSortOrder)

					IF @DebugBM & 32 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM HL_Cursor INTO @MemberId
				END

		CLOSE HL_Cursor
		DEALLOCATE HL_Cursor

	SET @Step = 'Return result'
		IF @DebugBM & 1 > 0 SELECT * FROM #HL_Table ORDER BY [SequenceNumber]

	SET @Step = 'Drop temp tables'
		DROP TABLE #Hierarchy
--		DROP TABLE #HL_Table
		DROP TABLE #Parent

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
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
