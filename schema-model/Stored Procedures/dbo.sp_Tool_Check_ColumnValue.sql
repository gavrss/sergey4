SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Check_ColumnValue]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ColumnName nvarchar(50) = NULL,
	@ColumnValue nvarchar(50) = NULL,
	@SourceDatabase nvarchar(100) = 'pcINTEGRATOR_Data',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000406,
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
	@ProcedureName = 'sp_Tool_Check_ColumnValue',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [sp_Tool_Check_ColumnValue] @UserID=-10, @ColumnName = 'InstanceID', @ColumnValue = '1300', @Debug = 1
EXEC [sp_Tool_Check_ColumnValue] @UserID=-10, @ColumnName = 'VersionID', @ColumnValue = 'NULL', @Debug = 1

EXEC [sp_Tool_Check_ColumnValue] @UserID=-10, @ColumnName = 'VersionID', @ColumnValue = 'NULL', @SourceDatabase = 'pcINTEGRATOR_Data_MAS04', @Debug = 1

EXEC [sp_Tool_Check_ColumnValue] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@TableName nvarchar(100),
	@SQLStatement nvarchar(MAX),

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.2.2146'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Search for specific column values in all tables',
			@MandatoryParameter = 'ColumnName|ColumnValue' --Without @, separated by |

		IF @Version = '2.0.2.2144' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'Added parameter @SourceDatabase.'

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
		CREATE TABLE #ColumnValue
			(
			TableName nvarchar(100) COLLATE DATABASE_DEFAULT,
			ColumnName nvarchar(100) COLLATE DATABASE_DEFAULT,
			ColumnValue nvarchar(100) COLLATE DATABASE_DEFAULT,
			Occurencies int
			)

		CREATE TABLE #Table
			(
			TableName nvarchar(100) COLLATE DATABASE_DEFAULT,
			)

	SET @Step = 'Insert data into temp table'
		SET @SQLStatement = '
			INSERT INTO #Table
				(
				TableName
				)
			SELECT
				TableName = t.[name] 
			FROM 
				' + @SourceDatabase + '.sys.tables t
				INNER JOIN ' + @SourceDatabase + '.sys.columns c ON c.object_id = t.object_id AND c.[name] = ''' + @ColumnName + '''
			ORDER BY
				t.[name]'
		
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

	SET @Step = 'ColumnValue Cursor'
		DECLARE ColumnValue_Cursor CURSOR FOR
			
			SELECT
				[TableName] 
			FROM 
				#Table
			ORDER BY
				[TableName]

			OPEN ColumnValue_Cursor
			FETCH NEXT FROM ColumnValue_Cursor INTO @TableName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@TableName] = @TableName

					SET @SQLStatement = '
						INSERT INTO #ColumnValue
							(
							[TableName],
							[ColumnName],
							[ColumnValue],
							[Occurencies]
							)
						SELECT
							[TableName] = ''' + @TableName + ''',
							[ColumnName] = ''' + @ColumnName + ''',
							[ColumnValue] = ''' + @ColumnValue + ''',
							[Occurencies] = COUNT(1)
						FROM
							' + @SourceDatabase + '.[dbo].[' + @TableName + ']
						WHERE
							[' + @ColumnName + '] ' + CASE WHEN @ColumnValue = 'NULL' THEN 'IS NULL' ELSE '= ''' + @ColumnValue + '''' END + '
						GROUP BY
							[' + @ColumnName + ']'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM ColumnValue_Cursor INTO @TableName
				END

		CLOSE ColumnValue_Cursor
		DEALLOCATE ColumnValue_Cursor

	SET @Step = 'Return rows'
		SELECT * FROM #ColumnValue ORDER BY TableName

	SET @Step = 'Drop temp tables'
		DROP TABLE #ColumnValue
		DROP TABLE #Table

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
