SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Empty_pcINTEGRATOR_Data]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	@pcINTEGRATOR_Data_Source nvarchar(100) = 'pcINTEGRATOR_Data',
	@TruncateYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000471,
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
	@ProcedureName = 'sp_Tool_Empty_pcINTEGRATOR_Data',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [sp_Tool_Empty_pcINTEGRATOR_Data] @TruncateYN = 1, @pcINTEGRATOR_Data_Source='pcINTEGRATOR_Data', @Debug=1

		CLOSE Truncate_Cursor
		DEALLOCATE Truncate_Cursor

		CLOSE Insert_Cursor
		DEALLOCATE Insert_Cursor

EXEC [sp_Tool_Empty_pcINTEGRATOR_Data] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@TableName nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQL_Insert nvarchar(max),
	@SQL_Select nvarchar(max),
	@InstanceIDYN bit,
	@IdentityYN bit,
	@UpgradeSP nvarchar(4000),
	@Inserted_Counter int = 0,
	@Upgrade_RowCount int = 0,

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
			@ProcedureDescription = 'Empty or delete data on pcINTEGRATOR_Data',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Added call to [sp_Tool_Table_Row_Counter].'
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

	SET @Step = 'Truncate_Cursor'
		IF @TruncateYN <> 0
			BEGIN
				DECLARE Truncate_Cursor CURSOR FOR
			
					SELECT 
						TableName = DataObjectName,
						IdentityYN = IdentityYN
					FROM
						DataObject
					WHERE
						ObjectType = 'Table' AND
						DatabaseName = 'pcINTEGRATOR_Data' AND
						SelectYN <> 0 AND
						DeletedYN = 0
					ORDER BY
						SortOrder

					OPEN Truncate_Cursor
					FETCH NEXT FROM Truncate_Cursor INTO @TableName, @IdentityYN

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @Debug <> 0 SELECT TableName = @TableName, IdentityYN = @IdentityYN

							SET @SQLStatement = 'DELETE T FROM [' + @pcINTEGRATOR_Data_Source + '].[dbo].[' + @TableName + '] T'

							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT

							IF @IdentityYN <> 0 
								BEGIN
									SET @SQLStatement = 'EXEC [' + @pcINTEGRATOR_Data_Source + '].dbo.sp_executesql N''DBCC CHECKIDENT ([' + @TableName + '], RESEED, 1000)'''
									PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

							FETCH NEXT FROM Truncate_Cursor INTO @TableName, @IdentityYN
						END

				CLOSE Truncate_Cursor
				DEALLOCATE Truncate_Cursor
			END

	SET @Step = 'Count Table Rows'
		EXEC [sp_Tool_Table_Row_Counter] @SourceDatabase = @pcINTEGRATOR_Data_Source, @Debug = @Debug

	SET @Step = 'Set @Inserted'
		SET @Inserted = @Inserted_Counter
		
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
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
