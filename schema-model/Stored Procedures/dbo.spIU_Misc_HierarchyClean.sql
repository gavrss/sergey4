SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Misc_HierarchyClean]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int =  880000786,
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
EXEC [spIU_Misc_HierarchyClean] @UserID=-10, @InstanceID=476, @VersionID=1024, @DebugBM=3
EXEC [spIU_Misc_HierarchyClean] @UserID=-10, @InstanceID=454, @VersionID=1021, @DebugBM=3

EXEC [spIU_Misc_HierarchyClean] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@HierarchyTable nvarchar(100),

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
	@Version nvarchar(50) = '2.1.1.2172'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Remove invalid members from Callisto hierarchy tables.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2172' SET @Description = 'Procedure created.'

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
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'Fill cursor table #HierarchyTable'
		CREATE TABLE #HierarchyTable
			(
			[HierarchyTable] nvarchar(100) COLLATE DATABASE_DEFAULT
			)
		
		SET @SQLStatement = '
			INSERT INTO #HierarchyTable
				(
				[HierarchyTable]
				)
			SELECT
				[HierarchyTable] = T.[name]
			FROM
				pcINTEGRATOR_Data..Dimension_StorageType DST
				INNER JOIN pcINTEGRATOR..Dimension D ON D.InstanceID IN (0, DST.InstanceID) AND D.DimensionID = DST.DimensionID
				INNER JOIN pcINTEGRATOR..DimensionHierarchy DH ON DH.InstanceID IN (0, DST.InstanceID) AND DH.VersionID IN (0, DST.VersionID) AND DH.DimensionID = DST.DimensionID
				INNER JOIN ' + @CallistoDatabase + '.sys.tables T ON T.[name] = ''S_HS_'' + D.DimensionName + ''_'' + DH.HierarchyName
			WHERE
				DST.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND
				DST.VersionID = ' + CONVERT(nvarchar(15),@VersionID) + ' AND
				DST.StorageTypeBM & 4 > 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#HierarchyTable', * FROM #HierarchyTable ORDER BY [HierarchyTable]

	SET @Step = 'HierarchyTable_Cursor'
		IF CURSOR_STATUS('global','HierarchyTable_Cursor') >= -1 DEALLOCATE HierarchyTable_Cursor
		DECLARE HierarchyTable_Cursor CURSOR FOR
			
			SELECT 
				[HierarchyTable]
			FROM
				#HierarchyTable
			ORDER BY
				[HierarchyTable]


			OPEN HierarchyTable_Cursor
			FETCH NEXT FROM HierarchyTable_Cursor INTO @HierarchyTable

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@HierarchyTable] = @HierarchyTable

					SET @SQLStatement = '
						DELETE HT
						FROM
							' + @CallistoDatabase + '.[dbo].[' + @HierarchyTable + '] HT
						WHERE
							HT.MemberId IN
								(
								SELECT
									[MemberId]
								FROM
									' + @CallistoDatabase + '.[dbo].[' + @HierarchyTable + '] M
								WHERE
									M.[ParentMemberId] <> 0 AND
									NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '.[dbo].[' + @HierarchyTable + '] P WHERE P.[MemberId] = M.[ParentMemberId])
								)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					SET @Deleted = @Deleted + @@ROWCOUNT

					FETCH NEXT FROM HierarchyTable_Cursor INTO @HierarchyTable
				END

		CLOSE HierarchyTable_Cursor
		DEALLOCATE HierarchyTable_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
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
