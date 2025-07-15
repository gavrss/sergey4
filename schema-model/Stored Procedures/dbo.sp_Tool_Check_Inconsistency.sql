SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Check_Inconsistency]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ColumnName nvarchar(100) = NULL, --'DimensionID',
	@MasterTable nvarchar(100) = NULL, --'Dimension',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000559,
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
EXEC [sp_Tool_Check_Inconsistency] @UserID=-10, @InstanceID=0, @VersionID=0, @DebugBM=3
EXEC [sp_Tool_Check_Inconsistency] @UserID=-10, @InstanceID=0, @VersionID=0, @MasterTable = 'Dimension', @DebugBM=3
EXEC [sp_Tool_Check_Inconsistency] @UserID=-10, @InstanceID=0, @VersionID=0, @ColumnName = 'InstanceID', @MasterTable = 'Instance', @DebugBM=3

EXEC [sp_Tool_Check_Inconsistency] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@TableName nvarchar(100),
	@SQLStatement nvarchar(max),
	@ReturnVariable int,

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2155'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Checks for inconsistent data reference',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2153' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Added correct DB reference (pcINTEGRATOR_Data) when setting @InternalVariable.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'MasterTable_Cursor'
		IF CURSOR_STATUS('global','MasterTable_Cursor') >= -1 DEALLOCATE MasterTable_Cursor
		DECLARE MasterTable_Cursor CURSOR FOR
			
			SELECT DISTINCT
				[@MasterTable] = t.[name],
				[@ColumnName] = c.[name]
			FROM
				[pcINTEGRATOR_Data].sys.columns c
				INNER JOIN [pcINTEGRATOR_Data].sys.tables t ON t.[name] = REPLACE(c.[name], 'ID', '') AND (t.[name] = @MasterTable OR @MasterTable IS NULL) AND t.[name] NOT IN ('FullAccount') AND t.[name] NOT LIKE 'tmp_%' AND t.[name] NOT LIKE 'wrk_%'
			WHERE
				(c.[name] = @ColumnName OR @ColumnName IS NULL) AND
				c.[name] LIKE '%ID'
			ORDER BY
				t.[name]

			OPEN MasterTable_Cursor
			FETCH NEXT FROM MasterTable_Cursor INTO @MasterTable, @ColumnName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@MasterTable] = @MasterTable, [@ColumnName] = @ColumnName

					SET @Step = 'Table_Cursor'
						IF CURSOR_STATUS('global','Table_Cursor') >= -1 DEALLOCATE Table_Cursor
						DECLARE Table_Cursor CURSOR FOR
			
							SELECT
								TableName = t.[name] 
							FROM
								[pcINTEGRATOR_Data].sys.columns c
								INNER JOIN [pcINTEGRATOR_Data].sys.tables t ON t.object_id = c.object_id AND t.[name] NOT IN ('FullAccount') AND t.[name] NOT LIKE 'tmp_%' AND t.[name] NOT LIKE 'wrk_%'
							WHERE
								c.[name] = @ColumnName

							OPEN Table_Cursor
							FETCH NEXT FROM Table_Cursor INTO @TableName

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @DebugBM & 2 > 0 SELECT [@TableName] = @TableName
--[pcINTEGRATOR_Data].[dbo].
--' + CASE WHEN @ColumnName = 'DimensionID' THEN 'T.' + @ColumnName + ' > 1000 AND' ELSE '' END + '
									SET @SQLStatement = '
										SELECT @InternalVariable = COUNT(1) FROM [pcINTEGRATOR_Data].[dbo].[' + @TableName + '] T 
										WHERE NOT EXISTS (SELECT 1 FROM [' + @MasterTable + '] MT WHERE ' + CASE WHEN @MasterTable NOT IN ('User', 'Customer') THEN 'MT.InstanceID IN (0, T.InstanceID) AND ' ELSE '' END + 'MT.' + @ColumnName + ' = T.' + @ColumnName + ')'

									IF @DebugBM & 2 > 0  PRINT @SQLStatement

									EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ReturnVariable OUT

									IF @DebugBM & 1 > 0 SELECT [@ReturnVariable] = @ReturnVariable

									IF @ReturnVariable > 0
										BEGIN
											SET @SQLStatement = '
												SELECT
													[@TableName] = ''' + @TableName + ''',
													[@ColumnName] = ''' + @ColumnName + ''',
													*
												FROM
													[' + @TableName + '] T
												WHERE
													NOT EXISTS (SELECT 1 FROM [' + @MasterTable + '] MT WHERE ' + CASE WHEN @MasterTable NOT IN ('User', 'Customer') THEN 'MT.InstanceID IN (0, T.InstanceID) AND ' ELSE '' END + 'MT.' + @ColumnName + ' = T.' + @ColumnName + ')'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
										END

									FETCH NEXT FROM Table_Cursor INTO @TableName
								END

						CLOSE Table_Cursor
						DEALLOCATE Table_Cursor

					FETCH NEXT FROM MasterTable_Cursor INTO @MasterTable, @ColumnName
				END

		CLOSE MasterTable_Cursor
		DEALLOCATE MasterTable_Cursor

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
