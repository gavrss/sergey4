SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Update_Callisto_TimeDimension]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	--SP-specific parameters
	@ShrinkCallistoYN bit = 0,
	@InstanceExceptionList nvarchar(1000) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000626,
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
EXEC [sp_Tool_Update_Callisto_TimeDimension] @InstanceID=-1475, @VersionID=-1475, @Debug = 1

EXEC [sp_Tool_Update_Callisto_TimeDimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@StorageTypeBM int,
	@ETL_DB_YN bit,
	@Callisto_DB_YN bit,
	@SQLStatement nvarchar(max),
	@RowCount int,
	@AssignedInstanceID int,
	@AssignedVersionID int,
	@Callisto_Generic_StartTime datetime,

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
	@Version nvarchar(50) = '2.1.0.2160'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Template for creating SPs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2159' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2160' SET @Description = 'Added @DebugSub on subroutines.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Start Job'
		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='Start',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobQueueYN=0,
			@JobID=@JobID OUT

	SET @Step = 'Create temp table #Application_Cursor'
		CREATE TABLE #Application_Cursor
			(
			[AssignedInstanceID] int,
			[AssignedVersionID] int,
			[ETLDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[CallistoDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] int
			)

		SET @SQLStatement = '
			INSERT INTO #Application_Cursor
				(
				[AssignedInstanceID],
				[AssignedVersionID],
				[ETLDatabase],
				[CallistoDatabase],
				[StorageTypeBM]
				)
			SELECT 
				[AssignedInstanceID] = A.[InstanceID],
				[AssignedVersionID] = A.[VersionID],
				[ETLDatabase] = A.[ETLDatabase],
				[CallistoDatabase] = A.[DestinationDatabase],
				[StorageTypeBM] = A.[StorageTypeBM]
			FROM
				[Application] A
			WHERE
				' + CASE WHEN @InstanceExceptionList IS NULL THEN '' ELSE 'A.[InstanceID] NOT IN (' + @InstanceExceptionList + ') AND' END + '
				(A.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' OR  ' + CONVERT(nvarchar(15), @InstanceID) + ' = 0) AND
				(A.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' OR ' + CONVERT(nvarchar(15), @VersionID) + ' = 0)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Application_Cursor',  * FROM #Application_Cursor ORDER BY [AssignedInstanceID], [AssignedVersionID]

	SET @Step = 'Application_Cursor'
		IF CURSOR_STATUS('global','Application_Cursor') >= -1 DEALLOCATE Application_Cursor
		DECLARE Application_Cursor CURSOR FOR
			
			SELECT 
				[AssignedInstanceID],
				[AssignedVersionID],
				[ETLDatabase],
				[CallistoDatabase],
				[StorageTypeBM]
			FROM
				 #Application_Cursor
			ORDER BY
				 [AssignedInstanceID],
				 [AssignedVersionID]

			OPEN Application_Cursor
			FETCH NEXT FROM Application_Cursor INTO @AssignedInstanceID, @AssignedVersionID, @ETLDatabase, @CallistoDatabase, @StorageTypeBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@AssignedInstanceID] = @AssignedInstanceID, [@AssignedVersionID] = @AssignedVersionID, [@ETLDatabase] = @ETLDatabase, [@CallistoDatabase] = @CallistoDatabase, [@StorageTypeBM] = @StorageTypeBM			

					--pcDATA (Callisto)
					SELECT @Callisto_DB_YN = CASE WHEN db_id(@CallistoDatabase) IS NULL THEN 0 ELSE 1 END
					IF @Callisto_DB_YN <> 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase

							--Insert into Callisto Applications table
							INSERT INTO [CallistoAppDictionary].[dbo].[Applications]
								(
								[ApplicationLabel],
								[SqlDbName],
								[SqlDbServer],
								[OlapDbName],
								[OlapDbServer],
								[ApplicationType],
								[EnableAppLogon],
								[ReportServer],
								[MDXQueryTimeout],
								[WebSvcTraceLevel],
								[SvcWaitTime],
								[SvcTraceLevel],
								[SvcServerId],
								[ReportServerTraceLevel],
								[Offline]
								)
							SELECT
								[ApplicationLabel] = @CallistoDatabase,
								[SqlDbName] = @CallistoDatabase,
								[SqlDbServer] = 'localhost',
								[OlapDbName] = @CallistoDatabase,
								[OlapDbServer] = 'localhost',
								[ApplicationType] = NULL,
								[EnableAppLogon] = 2,
								[ReportServer] = 'localhost:43000',
								[MDXQueryTimeout] = 30,
								[WebSvcTraceLevel] = 0,
								[SvcWaitTime] = 30,
								[SvcTraceLevel] = 1,
								[SvcServerId] = 'localhost',
								[ReportServerTraceLevel] = 0,
								[Offline] = 0
							WHERE
								NOT EXISTS (SELECT 1 FROM [CallistoAppDictionary].[dbo].[Applications] A WHERE A.[ApplicationLabel] = @CallistoDatabase)

							--Import new objects into Callisto
							SET @Callisto_Generic_StartTime = GetDate()

							EXEC [spRun_Job_Callisto_Generic]
								@UserID = @UserID,
								@InstanceID = @AssignedInstanceID,
								@VersionID = @AssignedVersionID,
								@StepName = 'Import',
								@AsynchronousYN = 0,
								@SourceDatabase = 'pcCALLISTO_Import_TimeDimension',
								@MasterCommand=@ProcedureName,
								@JobID=@JobID,
								@Debug=@DebugSub
						END

					FETCH NEXT FROM Application_Cursor INTO @AssignedInstanceID, @AssignedVersionID, @ETLDatabase, @CallistoDatabase, @StorageTypeBM
				END

		CLOSE Application_Cursor
		DEALLOCATE Application_Cursor

	SET @Step = 'Set EndTime for the actual job'
		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID

	SET @Step = 'Drop temp tables'
		DROP TABLE #Application_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
