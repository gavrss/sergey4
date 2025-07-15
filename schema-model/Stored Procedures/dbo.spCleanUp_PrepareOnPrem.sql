SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCleanUp_PrepareOnPrem]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DatabaseName nvarchar(100) = NULL, --Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000278,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC [dbo].[spCleanUp_PrepareOnPrem] 
	@UserID = -10,
	@InstanceID = 428,
	@VersionID = 1100, 
	@DatabaseName = 'pcINTEGRATOR_Gotwals',
	@Debug = 1

EXEC [spCleanUp_PrepareOnPrem] @GetVersion = 1
*/
DECLARE
	@CurrentDatabaseName nvarchar(100),
	@TableName nvarchar(100),
	@CursorProcedureName nvarchar(100),
	@SQLStatement nvarchar(max),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.0.2140'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Delete objects and rows not relevant for a specific InstanceID',
			@MandatoryParameter = 'DatabaseName' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'Handle more tables and SPs.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description
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

	SET @Step = 'Check if correct UserID'
		IF @UserID NOT IN (-10)
			BEGIN
				SET @Message = 'This SP can only be used by super admin'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Check Databasename'
		SELECT @CurrentDatabaseName = DB_Name()
		
		IF @CurrentDatabaseName = 'pcINTEGRATOR' OR @CurrentDatabaseName <> @DatabaseName
			BEGIN
				SET @Message = 'The parameter @DatabaseName must be set to the name of this database and it cant be set to pcINTEGRATOR'
				SET @Severity = 16
				
				GOTO EXITPOINT
			END

	SET @Step = 'Delete data in tables with known parameters'
		EXEC [spCleanUp_TableRow]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DatabaseName = @DatabaseName,
			@SaveInstanceYN = 1,
			@Deleted = @Deleted OUT,
			@Inserted = @Inserted OUT,
			@Updated = @Updated OUT,
			@Selected = @Selected OUT

	SET @Step = 'Truncate wrk tables'
		DECLARE Table_Cursor CURSOR FOR
			SELECT 
				TableName = T.[name]
			FROM
				[sys].[tables] T
			WHERE
				T.[name] LIKE 'wrk_%' OR T.[Name] IN ('Job', 'JobLog')
			ORDER BY
				T.[name]

			OPEN Table_Cursor
			FETCH NEXT FROM Table_Cursor INTO @TableName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT TableName = @TableName

					SET @SQLStatement = '
						TRUNCATE TABLE ' + @TableName

					EXEC (@SQLStatement)

					FETCH NEXT FROM Table_Cursor INTO @TableName
				END

		CLOSE Table_Cursor
		DEALLOCATE Table_Cursor	

	SET @Step = 'Drop temporary stored Procedures'
		DECLARE Procedure_Cursor CURSOR FOR
			SELECT 
				ProcedureName = P.[name]
			FROM
				[sys].[procedures] P
			WHERE
				ISNUMERIC(RIGHT(P.[name], 8)) <> 0 OR RIGHT(P.[name], 3) IN ('New', 'Old')
			ORDER BY
				P.[name]

			OPEN Procedure_Cursor
			FETCH NEXT FROM Procedure_Cursor INTO @CursorProcedureName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT ProcedureName = @CursorProcedureName

					SET @SQLStatement = '
						DROP PROCEDURE ' + @CursorProcedureName

					EXEC (@SQLStatement)

					FETCH NEXT FROM Procedure_Cursor INTO @CursorProcedureName
				END

		CLOSE Procedure_Cursor
		DEALLOCATE Procedure_Cursor	

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
