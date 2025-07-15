SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

--The INSERT statement conflicted with the FOREIGN KEY constraint "FK_ProcedureParameter_Procedure". The conflict occurred in database "pcINTEGRATOR_Data", table "dbo.Procedure", column 'ProcedureID'.

CREATE PROCEDURE [dbo].[spSet_Procedure]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	@CalledInstanceID int = NULL,
	@CalledVersionID int = NULL,
	@CalledProcedureID int = NULL,
	@CalledDatabaseName nvarchar(100) = NULL, 
	@CalledProcedureName nvarchar(100) = NULL,
	@CalledProcedureDescription nvarchar(1024) = NULL,
	@CalledMandatoryParameter nvarchar(1000) = NULL,
	@CalledVersion nvarchar(100) = NULL,
	@CalledVersionDescription nvarchar(255) = NULL,
	@CalledCreatedBy nvarchar(50) = NULL,
	@CalledModifiedBy nvarchar(50) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000298,
	@Parameter nvarchar(4000) = NULL,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

AS

--EXEC spSet_Procedure @GetVersion = 1, @Debug=1

DECLARE
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2169'

SET NOCOUNT ON 

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName =  DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Verifies status of Metadata for selected Procedure. Called by all other SPs.',
			@MandatoryParameter = 'CalledProcedureID|CalledProcedureName|CalledProcedureDescription|CalledMandatoryParameter|CalledVersion|CalledVersionDescription'
		
		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2141' SET @Description = 'Added parameters @CalledCreatedBy and @CalledModifiedBy.'
		IF @Version = '2.0.3.2154' SET @Description = 'Return @CreatedBy and @ModifiedBy.'
		IF @Version = '2.1.0.2162' SET @Description = 'Enhanced debugging. Use spSet_Procedure_Sub instead of spInsert_Procedure.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle multiple databases.'

		IF ISNULL((SELECT [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = @ProcedureName AND DeletedID IS NULL), 0) <> @ProcedureID
			BEGIN
				SET @ProcedureID = NULL
				SELECT @ProcedureID = [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = @ProcedureName AND DeletedID IS NULL
				IF @ProcedureID IS NULL
					BEGIN
						EXEC spSet_Procedure_Sub @CalledInstanceID=0, @CalledVersionID=0, @CalledDatabaseName=@DatabaseName, @CalledProcedureName = @ProcedureName, @ProcedureDescription = @ProcedureDescription, @MandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @JobID = @JobID, @Debug = @DebugSub
						SET @Message = 'SP ' + @ProcedureName + ' was not registered. It is now registered by SP spSet_Procedure_Sub. Rerun the command to get correct ProcedureID.'
					END
				ELSE
					SET @Message = 'ProcedureID mismatch, should be ' + CONVERT(nvarchar(10), @ProcedureID)
				SET @Severity = 16
				GOTO EXITPOINT
			END
		ELSE
			BEGIN
				EXEC spSet_Procedure_Sub @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @ProcedureDescription=@ProcedureDescription, @MandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @JobID=@JobID, @Debug=@Debug
			END

		SELECT [ProcedureID] = @ProcedureID, [ProcedureName] = @ProcedureName, [ProcedureDescription] = @ProcedureDescription, [Version] = @Version, [VersionDescription] = @Description, [CreatedBy] = @CreatedBy, [ModifiedBy] = @ModifiedBy
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CalledInstanceID = ISNULL(@CalledInstanceID, 0),
			@CalledVersionID = ISNULL(@CalledVersionID, 0),
			@CalledDatabaseName = ISNULL(@CalledDatabaseName, 'pcINTEGRATOR')

	SET @Step = 'Verify status of Metadata for selected Procedure'
		IF ISNULL((SELECT [ProcedureID] FROM [Procedure] WHERE [InstanceID] = @CalledInstanceID AND [VersionID] = @CalledVersionID AND [DatabaseName] = @CalledDatabaseName AND [ProcedureName] = @CalledProcedureName AND DeletedID IS NULL), 0) <> @CalledProcedureID
			BEGIN
				SET @CalledProcedureID = NULL
				SELECT @CalledProcedureID = [ProcedureID] FROM [Procedure] WHERE [InstanceID] = @CalledInstanceID AND [VersionID] = @CalledVersionID AND [DatabaseName] = @CalledDatabaseName AND [ProcedureName] = @CalledProcedureName AND DeletedID IS NULL
				IF @CalledProcedureID IS NULL
					BEGIN
						EXEC spSet_Procedure_Sub @CalledInstanceID=@CalledInstanceID, @CalledVersionID=@CalledVersionID, @CalledDatabaseName=@CalledDatabaseName, @CalledProcedureName=@CalledProcedureName, @ProcedureDescription=@CalledProcedureDescription, @MandatoryParameter=@CalledMandatoryParameter, @CalledVersion=@CalledVersion, @JobID=@JobID, @Debug=@DebugSub
						SET @Message = 'SP ' + @CalledProcedureName + ' was not registered. It is now registered. Rerun the command to get correct ProcedureID.'
					END
				ELSE
					SET @Message = 'ProcedureID mismatch, should be ' + CONVERT(nvarchar(10), @CalledProcedureID)
				SET @Severity = 16
				GOTO EXITPOINT
			END
		ELSE
			EXEC spSet_Procedure_Sub @CalledInstanceID=@CalledInstanceID, @CalledVersionID=@CalledVersionID, @CalledProcedureID=@CalledProcedureID, @CalledDatabaseName=@CalledDatabaseName, @CalledProcedureName=@CalledProcedureName, @ProcedureDescription=@CalledProcedureDescription, @MandatoryParameter=@CalledMandatoryParameter, @CalledVersion=@CalledVersion, @JobID=@JobID

		SELECT [ProcedureID] = @CalledProcedureID, [ProcedureName] = @CalledProcedureName, [ProcedureDescription] = @CalledProcedureDescription, [Version] = @CalledVersion, [VersionDescription] = @CalledVersionDescription, [CreatedBy] = @CalledCreatedBy, [ModifiedBy] = @CalledModifiedBy
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = -100, @InstanceID = -100, @VersionID = -100, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @Parameter = @Parameter, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
