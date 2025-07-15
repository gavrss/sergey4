SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Table_Row_Counter]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	@SourceDatabase nvarchar(100) = 'pcINTEGRATOR_Data',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000472,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'sp_Tool_Table_Row_Counter',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [sp_Tool_Table_Row_Counter] @SourceDatabase = 'pcINTEGRATOR_Data', @Debug = 1

EXEC [sp_Tool_Table_Row_Counter] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	@TableName nvarchar(100),
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
	@ToBeChanged nvarchar(255),
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2159'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns total number of rows per table.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2147' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Added ORDER BY filter ON [SourceTable_RowCounter] for Return Rows.'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine [spSet_Job].'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			EXEC [spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=0,
				@JobID=@JobID OUT

	SET @Step = 'Create temp tables'
		CREATE TABLE #CursorTable
			(
			[TableName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SourceTable_RowCounter] int
			)
			
	SET @Step = 'Fill #CursorTable'
		SET @SQLStatement = '
		INSERT INTO #CursorTable
			(
			[TableName]
			)
		SELECT 
			[name]
		FROM
			' + @SourceDatabase + '.sys.tables'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
	SET @Step = 'Create RowCounter_Cursor'	
		IF CURSOR_STATUS('global','RowCounter_Cursor') >= -1 DEALLOCATE RowCounter_Cursor	
		DECLARE RowCounter_Cursor CURSOR FOR
			SELECT 
				[TableName]
			FROM
				#CursorTable

			OPEN RowCounter_Cursor
			FETCH NEXT FROM RowCounter_Cursor INTO @TableName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						UPDATE CT
						SET
							[SourceTable_RowCounter] = sub.[SourceTable_RowCounter]
						FROM 
							#CursorTable CT
							INNER JOIN
							(
								SELECT 
									[SourceTable_RowCounter] = COUNT(1)
								FROM
									' + @SourceDatabase + '.[dbo].[' + @TableName + ']
							) AS sub ON 1 = 1
						WHERE
							CT.[TableName] = ''' + @TableName + ''''
								

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM RowCounter_Cursor INTO @TableName
				END

		CLOSE RowCounter_Cursor
		DEALLOCATE RowCounter_Cursor

	SET @Step = 'Return Rows'
		SELECT 
			[TempTable] = '#CursorTable', * 
		FROM 
			#CursorTable
		ORDER BY
			[SourceTable_RowCounter] DESC, TableName

	SET @Step = 'Drop temp tables'
		DROP TABLE #CursorTable

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

	SET @Step = 'Set EndTime for the actual job'
		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
