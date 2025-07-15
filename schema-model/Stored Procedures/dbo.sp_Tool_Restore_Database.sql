SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Restore_Database]
	@UserID int = NULL,
	@InstanceID int = NULL, 
	@VersionID int = NULL, 

	@DatabaseList nvarchar(4000) = NULL,
	@Path nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000522,
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
EXEC [sp_Tool_Restore_Database]
@UserID=-10, @InstanceID=0, @VersionID=0, 
@DatabaseList = 'pcDATA_SSCT,pcDATA_BP,pcDATA_JACK,pcDATA_BACK,pcDATA_ADP,pcDATA_CDR3,pcDATA_MEI,pcDATA_SCC,pcDATA_ACA,pcDATA_MTQA,pcDATA_ESA,pcDATA_SAKER,pcDATA_GTI,pcDATA_ELM,pcDATA_ES243,pcDATA_FLB,pcDATA_REST3,pcDATA_APUN,pcDATA_UN,pcDATA_TUF',
@Path = 'C:\BackupsStorage\dsptest01\20191210\',
@DebugBM=1

EXEC [sp_Tool_Restore_Database] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DatabaseName nvarchar(100),
	@SQLStatement nvarchar(max),

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
	@Version nvarchar(50) = '2.0.2.2150'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Restore listed databases',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2150' SET @Description = 'Procedure created.'

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create #Restore_Cursor_Table'
		CREATE TABLE #Restore_Cursor_Table
			(
			DatabaseName nvarchar(100)
			)

		INSERT INTO #Restore_Cursor_Table
			(
			DatabaseName
			)
		SELECT 
			DatabaseName = value
		FROM STRING_SPLIT(@DatabaseList, ',')

		IF @DebugBM & 2 > 0 SELECT * FROM #Restore_Cursor_Table ORDER BY DatabaseName

	SET @Step = 'Restore_Cursor'
		IF CURSOR_STATUS('global','Restore_Cursor') >= -1 DEALLOCATE Restore_Cursor
		DECLARE Restore_Cursor CURSOR FOR
			
			SELECT 
				DatabaseName
			FROM
				#Restore_Cursor_Table
			ORDER BY
				DatabaseName

			OPEN Restore_Cursor
			FETCH NEXT FROM Restore_Cursor INTO @DatabaseName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DatabaseName] = @DatabaseName

					--Drop existent @DatabaseName
					IF EXISTS (SELECT 1 FROM sys.databases WHERE [name] = @DatabaseName)
						BEGIN
							SET @SQLStatement = 'ALTER DATABASE ' + @DatabaseName + ' SET SINGLE_USER WITH ROLLBACK IMMEDIATE'
							SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + 'DROP DATABASE ' + @DatabaseName
				
							IF @Debug <> 0 PRINT @SQLStatement	
							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + 1
						END

					--Restore @DatabaseName
					SET @SQLStatement = '
						RESTORE DATABASE ' + @DatabaseName + '  
						   FROM DISK = ''' + @Path + @DatabaseName + '.Bak''
						   WITH 
						   REPLACE, RECOVERY'

					IF @DebugBM & 1 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Restore_Cursor INTO @DatabaseName
				END

		CLOSE Restore_Cursor
		DEALLOCATE Restore_Cursor


	SET @Step = 'Set @Duration'
		DROP TABLE #Restore_Cursor_Table

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
