SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Update_Callisto_Models_Dims]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	--SP-specific parameters
	@CallistoShrinkYN bit = 0,
	@CallistoDeployYN bit = 0,
	@InstanceExceptionList nvarchar(1000) = NULL,
	@InstanceIncludeList nvarchar(1000) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000702,
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
EXEC [sp_Tool_Update_Callisto_Models_Dims] @InstanceIncludeList = '-1492,-1493,-1494,-1496', @CallistoDeployYN=1, @DebugBM = 7
EXEC [sp_Tool_Update_Callisto_Models_Dims] @InstanceExceptionList = '-1405,-1484,-1486,-1495', @CallistoDeployYN=1, @DebugBM = 3
EXEC [sp_Tool_Update_Callisto_Models_Dims] @DebugBM = 7

EXEC [sp_Tool_Update_Callisto_Models_Dims] @GetVersion = 1
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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2162'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Loop all pcETL and pcDATA databases and make updates/adjustments.',
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

		SELECT [@JobID] = @JobID

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
				' + CASE WHEN @InstanceIncludeList IS NULL THEN '' ELSE 'A.[InstanceID] IN (' + @InstanceIncludeList + ') AND' END + '
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

					--Check if pcETL and pcDATA (Callisto) EXISTS
					SELECT @ETL_DB_YN = CASE WHEN db_id(@ETLDatabase) IS NULL THEN 0 ELSE 1 END
					SELECT @Callisto_DB_YN = CASE WHEN db_id(@CallistoDatabase) IS NULL THEN 0 ELSE 1 END

					IF @ETL_DB_YN <> 0 AND @Callisto_DB_YN <> 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@ETLDatabase] = @ETLDatabase, [@CallistoDatabase] = @CallistoDatabase

							--Import Models + Dimensions to from pcETL..[XT_*] tables to CallistoDatabase
							--@SequenceBM 1=Create XT_tables, 2=Models+Dims, 4=BusinessRules, 16=Deploy(Import) to Callisto

							EXEC [spSetup_Callisto] @UserID=@UserID, @InstanceID=@AssignedInstanceID, @VersionID=@AssignedVersionID, @SequenceBM = 19, @DebugBM = @DebugSub


							--Deploy Callisto database
							IF @CallistoDeployYN <> 0
								BEGIN
									SET @JSON = '
											[
											{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
											{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @AssignedInstanceID) + '"},
											{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @AssignedVersionID) + '"},
											{"TKey" : "StepName",  "TValue": "Deploy"},
											{"TKey" : "AsynchronousYN",  "TValue": "1"},
											{"TKey" : "MasterCommand",  "TValue": "' + @ProcedureName + '"},
											{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
											{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}
											]'

									IF @DebugBM & 2 > 0 PRINT @JSON

									EXEC spRun_Procedure_KeyValuePair
										@ProcedureName = 'spRun_Job_Callisto_Generic',
										@JSON = @JSON

									--EXEC [spRun_Job_Callisto_Generic]
									--	@UserID = @UserID,
									--	@InstanceID = @AssignedInstanceID,
									--	@VersionID = @AssignedVersionID,
									--	@StepName = 'Deploy',
									--	@AsynchronousYN = 1,
									--	@MasterCommand=@ProcedureName,
									--	@JobID=@JobID,
									--	@Debug=@DebugSub
								END
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
