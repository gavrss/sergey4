SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Check_Dimension_Property]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionName nvarchar(100) = NULL,
	@PropertyName nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000514,
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
EXEC [sp_Tool_Check_Dimension_Property] @UserID=-10, @InstanceID=390, @VersionID=1011, @DimensionName = 'WorkflowState', @PropertyName = 'SendTo', @Debug=1

EXEC [sp_Tool_Check_Dimension_Property] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),

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
	@Version nvarchar(50) = '2.0.3.2151'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Check existence of specific dimension property',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2149' SET @Description = 'DB-217: Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Set default values on all parameters.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create temp table'
		CREATE TABLE #MissingProperty
			(
			CallistoDatabase nvarchar(100)
			)


	SET @Step = 'CallistoDB_Cursor'
		IF CURSOR_STATUS('global','CallistoDB_Cursor') >= -1 DEALLOCATE CallistoDB_Cursor
		DECLARE CallistoDB_Cursor CURSOR FOR
			
			SELECT 
				CallistoDatabase = A.[DestinationDatabase]
			FROM
				[Application] A
				INNER JOIN sys.databases db ON db.[name] = A.[DestinationDatabase]
			ORDER BY
				A.[DestinationDatabase]


			OPEN CallistoDB_Cursor
			FETCH NEXT FROM CallistoDB_Cursor INTO @CallistoDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@CallistoDatabase] = @CallistoDatabase

					SET @SQLStatement = '
						INSERT INTO #MissingProperty
							(
							CallistoDatabase
							)
						SELECT
							CallistoDatabase = ''' + @CallistoDatabase + '''
						FROM
							' + @CallistoDatabase + '.sys.tables t
						WHERE
							t.name = ''S_DS_' + @DimensionName + ''' AND
							NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '.sys.columns c WHERE c.object_id = t.object_id AND c.name = ''' + @PropertyName + ''')'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					FETCH NEXT FROM CallistoDB_Cursor INTO @CallistoDatabase
				END

		CLOSE CallistoDB_Cursor
		DEALLOCATE CallistoDB_Cursor

	SET @Step = 'Return result'
		SELECT * FROM #MissingProperty ORDER BY CallistoDatabase

	SET @Step = 'Drop temp table'
		DROP TABLE #MissingProperty

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
