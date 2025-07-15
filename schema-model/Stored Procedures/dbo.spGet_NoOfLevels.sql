SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_NoOfLevels]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionName nvarchar(50) = NULL,
	@HierarchyName nvarchar(50) = NULL,
	@NoOfLevels int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 0,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000863,
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
EXEC [spGet_NoOfLevels] @UserID=-10, @InstanceID=-1590, @VersionID=-1590, @DimensionName = 'Entity', @HierarchyName = 'Entity', @DebugBM=1
EXEC [spGet_NoOfLevels] @UserID=-10, @InstanceID=-1590, @VersionID=-1590, @DimensionName = 'Account', @HierarchyName = 'Account', @DebugBM=1

EXEC [spGet_NoOfLevels] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ParentMemberID bigint,
	@RunningParentMemberID bigint,
	@Level int,
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),

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

	SET @Step = 'Fill temp tables'
		CREATE TABLE #Hierarchy
			(
			[MemberId] bigint,
			[ParentMemberId] bigint
			)

		SET @SQLStatement = '
			INSERT INTO #Hierarchy
				(
				[MemberId],
				[ParentMemberId]
				)
			SELECT
				[MemberId],
				[ParentMemberId]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + ']'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SELECT
			[MemberId],
			[ParentMemberId]
		INTO
			#Leaf
		FROM
			#Hierarchy H
		WHERE
			NOT EXISTS (SELECT 1 FROM #Hierarchy P WHERE P.[ParentMemberId] = H.[MemberId])

		SELECT DISTINCT [ParentMemberID], [Level] = 0 INTO #Parent FROM #Leaf

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Parent', * FROM #Parent ORDER BY [ParentMemberID]

	SET @Step = 'Level_Cursor'
		IF CURSOR_STATUS('global','Level_Cursor') >= -1 DEALLOCATE Level_Cursor
		DECLARE Level_Cursor CURSOR FOR
			
			SELECT 
				[ParentMemberID]
			FROM
				#Parent
			ORDER BY
				[ParentMemberID]

			OPEN Level_Cursor
			FETCH NEXT FROM Level_Cursor INTO @ParentMemberID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ParentMemberID] = @ParentMemberID
					SELECT
						@Level = 1,
						@RunningParentMemberId = @ParentMemberID

					WHILE (SELECT COUNT(1) FROM #Hierarchy WHERE [MemberId] = @RunningParentMemberId) > 0
						BEGIN
							SET @Level = @Level + 1
							SELECT @RunningParentMemberId = [ParentMemberId] FROM #Hierarchy WHERE [MemberId] = @RunningParentMemberId
						END

					UPDATE #Parent
					SET [Level] = @Level
					WHERE [ParentMemberID] = @ParentMemberID

					FETCH NEXT FROM Level_Cursor INTO @ParentMemberID
				END

		CLOSE Level_Cursor
		DEALLOCATE Level_Cursor

	SET @Step = 'Return result'
		SELECT @NoOfLevels = MAX([Level]) FROM #Parent
		
		IF @DebugBM & 1 > 0 SELECT [@NoOfLevels] = @NoOfLevels

	SET @Step = 'Drop temp tables'
		DROP TABLE #Hierarchy
		DROP TABLE #Leaf
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
