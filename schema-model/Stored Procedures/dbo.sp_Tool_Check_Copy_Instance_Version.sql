SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Check_Copy_Instance_Version]
	@UserID int = NULL,
	@InstanceID int = NULL, --FromInstanceID
	@VersionID int = NULL, --FromVersionID

	@ToInstanceID int = NULL,
	@ToVersionID int = NULL,

	@SourceDatabase nvarchar(100) = '[pcINTEGRATOR_Data]',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000458,
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
EXEC [sp_Tool_Check_Copy_Instance_Version] 	
	@UserID = -10, 
	@InstanceID = 561, 
	@VersionID = 1071, 
	@ToInstanceID = 561, 
	@ToVersionID = 1044, 
	@SourceDatabase = 'DSPPROD02.pcINTEGRATOR_Data',
	@Debug = 1


EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'sp_Tool_Check_Copy_Instance_Version',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"},
		{"TKey" : "ToInstanceID",  "TValue": "-1001"},
		{"TKey" : "ToVersionID",  "TValue": "-1001"},
		{"TKey" : "Debug",  "TValue": "1"}
		]'

		CLOSE RowCounter_Cursor
		DEALLOCATE RowCounter_Cursor
		
EXEC [sp_Tool_Check_Copy_Instance_Version] 
	@UserID = -10, 
	@InstanceID = 454, 
	@VersionID = 1021, 
	@ToInstanceID = 454, 
	@ToVersionID = 1021, 
	@SourceDatabase = '[DSPPROD02].[pcINTEGRATOR_Data]',
	@Debug = 1

EXEC [sp_Tool_Check_Copy_Instance_Version] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	@TableName nvarchar(100),
	@SQLStatement nvarchar(max),
	@VersionIDYN bit,
	@DeletedIDYN bit,

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Recheck and verify data after Copy Instance/Version procedure.',
			@MandatoryParameter = 'ToInstanceID|ToVersionID' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Deallocate RowCounter_Cursor if existing.'

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

	SET @Step = 'Create temp tables'
		CREATE TABLE #CursorTable
			(
			[TableName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[VersionIDYN] bit,
			[DeletedIDYN] bit,
			[SourceTable_RowCounter] int,
			[DestinationTable_RowCounter] int,
			[SortOrder] int
			)
			
	SET @Step = 'Fill #CursorTable'
		INSERT INTO #CursorTable
			(
			[TableName],
			[VersionIDYN],
			[DeletedIDYN],
			[SortOrder]
			)
		SELECT 
			[TableName] = DataObjectName,
			[VersionIDYN],
			[DeletedIDYN],
			[SortOrder]
		FROM
			[DataObject]
		WHERE
			[ObjectType] = 'Table' AND
			[DatabaseName] = 'pcINTEGRATOR_Data' AND
			[DataObjectName] NOT IN ('BR05_Rule_FX_OpeningHistRate','BR16_Master') AND
			[InstanceIDYN] <> 0 AND
			[DeletedYN] = 0
		ORDER BY
			[SortOrder] DESC

	SET @Step = 'Create RowCounter_Cursor'
		IF CURSOR_STATUS('global','RowCounter_Cursor') >= -1 DEALLOCATE RowCounter_Cursor
		DECLARE RowCounter_Cursor CURSOR FOR
			SELECT 
				[TableName],
				[VersionIDYN],
				[DeletedIDYN]
			FROM
				#CursorTable
			ORDER BY
				[SortOrder]

			OPEN RowCounter_Cursor
			FETCH NEXT FROM RowCounter_Cursor INTO @TableName, @VersionIDYN, @DeletedIDYN

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
								WHERE
									InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + '
									' + CASE WHEN @VersionIDYN <> 0 THEN ' AND VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) ELSE '' END + '
									' + CASE WHEN @DeletedIDYN <> 0 THEN ' AND DeletedID IS NULL' ELSE '' END + '
							) AS sub ON 1 = 1
						WHERE
							CT.[TableName] = ''' + @TableName + ''''
								

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @SQLStatement = '
						UPDATE CT
						SET
							[DestinationTable_RowCounter] = sub.[DestinationTable_RowCounter]
						FROM 
							#CursorTable CT
							INNER JOIN
							(
								SELECT 
									[DestinationTable_RowCounter] = COUNT(1)
								FROM
									[pcINTEGRATOR_Data].[dbo].[' + @TableName + ']
								WHERE
									InstanceID = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + '
									' + CASE WHEN @VersionIDYN <> 0 THEN ' AND VersionID = ' + CONVERT(NVARCHAR(15), @ToVersionID) ELSE '' END + '
									' + CASE WHEN @DeletedIDYN <> 0 THEN ' AND DeletedID IS NULL' ELSE '' END + '
							) AS sub ON 1 = 1
						WHERE
							CT.[TableName] = ''' + @TableName + ''''
								

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM RowCounter_Cursor INTO @TableName, @VersionIDYN, @DeletedIDYN
				END

		CLOSE RowCounter_Cursor
		DEALLOCATE RowCounter_Cursor

	SET @Step = 'Return Rows'
		SELECT 
			[TempTable] = '#CursorTable', * 
		FROM 
			#CursorTable 
		WHERE
			[SourceTable_RowCounter] <> [DestinationTable_RowCounter]
		ORDER BY 
			SortOrder

	SET @Step = 'Drop temp tables'
		DROP TABLE #CursorTable

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
