SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_HierarchyTables] 

	@JobID int = 0,
	@ApplicationID int = NULL,
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--

AS

--EXEC [spCheck_HierarchyTables] @ApplicationID = 400, @Debug = 1
--EXEC [spCheck_HierarchyTables] @ApplicationID = 400
--EXEC [spCheck_HierarchyTables]
--EXEC [spCheck_HierarchyTables] @GetVersion = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@DestinationDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@TableName nvarchar(100),
	@InstanceID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2127'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.1.2124' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2127' SET @Description = 'Select part removed from ERROR-catch.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL 
	BEGIN
		PRINT 'Parameter @ApplicationID must be set'
		RETURN 
	END

BEGIN TRY

	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT
			@InstanceID = A.InstanceID,
			@DestinationDatabase = DestinationDatabase
		FROM
			[Application] A
		WHERE
			ApplicationID = @ApplicationID

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Create temp tables'
		CREATE TABLE #Hierarchy ([TableName] nvarchar(100), [RowCount] int)
		SET @SQLStatement = '
			INSERT INTO #Hierarchy (TableName) SELECT DISTINCT TableName = [name] FROM ' + @DestinationDatabase + '.sys.tables WHERE name LIKE ''S_HS_%'''
		EXEC (@SQLStatement)
		IF @Debug <> 0 SELECT TempTable = '#Hierarchy', * FROM #Hierarchy ORDER BY TableName

	SET @Step = 'Create Table_Cursor'	
		DECLARE Hierarchy_Cursor CURSOR FOR

			SELECT TableName FROM #Hierarchy ORDER BY TableName

			OPEN Hierarchy_Cursor
			FETCH NEXT FROM Hierarchy_Cursor INTO @TableName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT TableName = @TableName
					
					SET @SQLStatement = '
						UPDATE H
						SET
							[RowCount] = sub.[RowCount]
						FROM 
							#Hierarchy H
							INNER JOIN (SELECT TableName = ''' + @TableName + ''', [RowCount] = COUNT(1) FROM ' + @DestinationDatabase + '.dbo.' + @TableName + ') sub ON sub.[TableName] = H.[TableName]'

					EXEC (@SQLStatement)

					FETCH NEXT FROM Hierarchy_Cursor INTO @TableName
				END

		CLOSE Hierarchy_Cursor
		DEALLOCATE Hierarchy_Cursor	

		IF @Debug <> 0 SELECT TempTable = '#Hierarchy', * FROM #Hierarchy ORDER BY TableName

	SET @Step = 'Check for empty hierarchies'	
		IF (SELECT COUNT(1) FROM #Hierarchy WHERE [RowCount] = 0) > 0
			BEGIN
				SET @Message = 'The following dimension hierarchies are empty: ' 
				SELECT @Message = @Message + REPLACE(TableName, 'S_HS_', '') + ', ' FROM #Hierarchy WHERE [RowCount] = 0 ORDER BY TableName
				SET @Message = SUBSTRING(@Message, 1, LEN(@Message) - 1) + '. The setup can not continue until this problem is fixed.'
				SET @Severity = 16
				RAISERROR (@Message, @Severity, 100)
			END

	SET @Step = 'Drop temp tables'	
		DROP TABLE #Hierarchy

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		RETURN 0

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
END CATCH


GO
