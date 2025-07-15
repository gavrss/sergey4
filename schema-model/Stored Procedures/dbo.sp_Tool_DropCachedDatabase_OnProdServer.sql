SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_DropCachedDatabase_OnProdServer]
	@UserID int = null,
	@InstanceID int = null,
	@VersionID int = null,

--	@SQLServerFrom nvarchar(4000),
--	@SQLServerTo nvarchar(4000),
--	@DatabaseList nvarchar(4000),
--	@Path nvarchar(100) = '\\DSPBETA01\BackupTemp$',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000987,
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
EXEC [sp_Tool_DropCachedDatabase_OnProdServer]
		@UserID=-10, @InstanceID = 460, @VersionID = 1052,
		@DebugBM=1

EXEC [sp_Tool_DropCachedDatabase_OnProdServer] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@LinkedServer nvarchar(255),
	@SourceDatabaseShort nvarchar(255),
	@SQLStatement nvarchar(max),
	@DynamicSQL NVARCHAR(MAX),
	@DefaultDataPath NVARCHAR(255),
    @DefaultLogPath NVARCHAR(255),

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
	@CreatedBy nvarchar(50) = 'SeGa',
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version NVARCHAR(50) = '2.1.2.2199'
IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Drop dspSourceXXX database on "Production" server',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

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

	declare @BackupLog TABLE (
				LogMessage NVARCHAR(MAX)
				);

	SET @Step = 'Create #BU_Cursor_Table'
		CREATE TABLE #BU_Cursor_Table
			(
			LinkedServer nvarchar(255),
			SourceDatabaseShort nvarchar(255)
			)

    update pcINTEGRATOR_data..Source
    set  SourceDatabase = coalesce(SourceDatabase_Original, SourceDatabase)
    WHERE   InstanceID = @InstanceID
        and VersionID = @VersionID
        and SelectYN <> 0

		INSERT INTO #BU_Cursor_Table
			(
			LinkedServer,
			SourceDatabaseShort
			)
        select distinct
             LinkedServer = left(SourceDatabase, charindex(N'.', SourceDatabase) - 1)
            ,DatabaseName = right(SourceDatabase, len(SourceDatabase) - charindex(N'.', SourceDatabase))
        from pcINTEGRATOR_data..Source
        WHERE   InstanceID = @InstanceID
            and VersionID = @VersionID
	        and SelectYN <> 0
	        and SourceDatabase like '%.%' -- means : it's linked server database
	        and (   SourceDatabase like '%pcSource_%'
	            or right(SourceDatabase, len(SourceDatabase) - charindex(N'.', SourceDatabase)) in ('CCM_E10')
	            )

		IF @DebugBM & 2 > 0 SELECT * FROM #BU_Cursor_Table ORDER BY LinkedServer ,SourceDatabaseShort

	SET @Step = 'BU_Cursor'
		IF CURSOR_STATUS('global','BU_Cursor') >= -1 DEALLOCATE BU_Cursor
		DECLARE BU_Cursor CURSOR FOR

			SELECT
			     LinkedServer
				,SourceDatabaseShort
			FROM
				#BU_Cursor_Table
			ORDER BY
			     LinkedServer
				,SourceDatabaseShort

			OPEN BU_Cursor
			FETCH NEXT FROM BU_Cursor INTO @LinkedServer, @SourceDatabaseShort

	SET @Step = 'Dropping databases'
			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@LinkedServer] = @LinkedServer, [@SourceDatabaseShort] = @SourceDatabaseShort

                    select @SQLStatement =
                    'IF EXISTS (SELECT * FROM sys.databases WHERE name = N''' + @SourceDatabaseShort + ''')
                    BEGIN
                        ALTER DATABASE [' + @SourceDatabaseShort + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                        DROP DATABASE [' + @SourceDatabaseShort + '];
                    END;'
                    print @SQLStatement
                    EXEC sp_executesql @SQLStatement;

					FETCH NEXT FROM BU_Cursor INTO @LinkedServer, @SourceDatabaseShort
				END

		CLOSE BU_Cursor
		DEALLOCATE BU_Cursor


	SET @Step = 'Set @Duration'
		DROP TABLE #BU_Cursor_Table

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
