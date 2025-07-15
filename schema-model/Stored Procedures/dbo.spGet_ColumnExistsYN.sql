SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_ColumnExistsYN]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DatabaseName nvarchar(100) = NULL, --Mandatory
	@TableName nvarchar(100) = NULL, --Mandatory
	@ColumnName nvarchar(100) = NULL, --Mandatory
	@ExistsYN bit = NULL OUT,
	@SetJobLogYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000328,
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
EXEC spGet_ColumnExistsYN @DatabaseName = '[DSPSOURCE02].[Epicor10_UniversalRadiology]', @TableName = '[Erp].[GLBudgetDtl]', @ColumnName = 'BudgetCodeID', @DebugBM=7
EXEC spGet_ColumnExistsYN @DatabaseName = 'DSPSOURCE01.pcSource_ausmtsapp01_cbn', @TableName = '[Erp].[GLBudgetDtl]', @ColumnName = 'BudgetCodeID', @Debug=1
EXEC spGet_ColumnExistsYN @DatabaseName = 'DSPSOURCE01.pcSource_ausmtsapp01_cbn', @TableName = 'GLBudgetDtl', @ColumnName = 'BudgetCodeID', @Debug=1

EXEC [spGet_ColumnExistsYN] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@SchemaName nvarchar(100),
	@DotPosition int,
	@schema_id int,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2169'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Check existence of specific column',
			@MandatoryParameter = 'DatabaseName|TableName|ColumnName' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2157' SET @Description = 'Updated template.'
		IF @Version = '2.1.1.2168' SET @Description = 'Used [spGet_DatabaseExistsYN] and [spGet_TableExistsYN]; Added step to get schemaID.'
		IF @Version = '2.1.1.2169' SET @Description = 'Added parameter @SetJobLogYN, defaulted to 0.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Check server and database existence'
		IF @DatabaseName IS NULL
			SET @DatabaseName = DB_NAME()
		ELSE
			BEGIN
				EXEC [spGet_DatabaseExistsYN] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DatabaseName, @ExistsYN = @ExistsYN OUT, @JobID = @JobID, @Debug = @DebugSub
				IF @DebugBM & 2 > 0 SELECT [Database_ExistsYN] = @ExistsYN
				IF @ExistsYN = 0 GOTO Result
			END

	SET @Step = 'Get Schema'
		IF CHARINDEX('.', @TableName) <> 0
			BEGIN
				SELECT @DotPosition = CHARINDEX('.', @TableName)			
				SET @SchemaName = LEFT(@TableName, @DotPosition - 1)
				SET @TableName = SUBSTRING(@TableName, @DotPosition + 1, LEN(@TableName) - @DotPosition)
			END

		SET @DatabaseName = '[' + REPLACE(REPLACE(REPLACE(@DatabaseName, '[', ''), ']', ''), '.', '].[') + ']'

		SET @TableName = REPLACE(REPLACE(REPLACE(@TableName, '[', ''), ']', ''), '.', '')
		SET @SchemaName = REPLACE(REPLACE(REPLACE(ISNULL(@SchemaName, 'dbo'), '[', ''), ']', ''), '.', '')

		SET @SQLStatement = 'SELECT @InternalVariable = [schema_id] FROM ' + @DatabaseName + '.sys.schemas WHERE [name] = ''' + @SchemaName + ''''
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @schema_id  OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@DatabaseName] = @DatabaseName,
				[@SchemaName] = @SchemaName,
				[@TableName] = @TableName,
				[@schema_id] = @schema_id

	SET @Step = 'Check table existence'
		SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM ' + @DatabaseName + '.sys.tables WHERE [name] = ''' + @TableName + ''' AND [schema_id] = ' + CONVERT(nvarchar(15), @Schema_id) + ''
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ExistsYN OUT
		IF @DebugBM & 2 > 0 SELECT [Table_ExistsYN] = @ExistsYN
		IF @ExistsYN = 0 GOTO Result

	SET @Step = 'Check column existence'
		SET @ColumnName = REPLACE(REPLACE(REPLACE(@ColumnName, '[', ''), ']', ''), '.', '')

		IF @DebugBM & 2 > 0 SELECT [@ColumnName] = @ColumnName

		SET @SQLStatement = '
			SELECT 
				@InternalVariable = COUNT(1) 
			FROM 
				' + @DatabaseName + '.sys.tables t
				INNER JOIN ' + @DatabaseName + '.sys.columns c ON c.object_id = t.object_id AND c.name = ''' + @ColumnName + ''' 
			WHERE 
				t.[name] = ''' + @TableName + ''' AND t.[schema_id] = ' + CONVERT(nvarchar(15), @Schema_id) + ''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ExistsYN OUT

	SET @Step = 'Return result'
		Result:
		IF @DebugBM & 1 > 0 SELECT [@ExistsYN] = @ExistsYN
		
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SET @ExistsYN = 0
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
