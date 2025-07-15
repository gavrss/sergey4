SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Create_pcINTEGRATOR_View]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000422,
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
EXEC [sp_Tool_Create_pcINTEGRATOR_View] @Debug = 1

		CLOSE pcINTEGRATOR_View_Cursor
		DEALLOCATE pcINTEGRATOR_View_Cursor

		CLOSE pcINTEGRATOR_Log_View_Cursor
		DEALLOCATE pcINTEGRATOR_Log_View_Cursor

EXEC [sp_Tool_Create_pcINTEGRATOR_View] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(max),
	@TableName nvarchar(100),
	@TemplateTableName nvarchar(100),
	@InstanceIDYN bit,
	@DatabaseName nvarchar(100),
	@FieldList nvarchar(max),
	@FieldList2 nvarchar(max),

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.2.2148'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create views showing both template rows (from pcINTEGRATOR) and custom rows (from pcINTEGRATOR_Data).',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Renamed to [sp_Tool_Create_pcINTEGRATOR_View] from [spCreate_pcINTEGRATOR_View]. Added Current Version and Date Created comments.'
		IF @Version = '2.0.2.2148' SET @Description = 'Set step to table name in cursor.'

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

		EXEC [spGet_Version] @Version = @Version OUTPUT
		IF @Debug <> 0 SELECT [@Version] = @Version

	SET @Step = 'Update table DataObject'
		EXEC [sp_Tool_Set_DataObject] @ReturnDataYN = 0

	SET @Step = 'Create cursor table'
		CREATE TABLE #pcINTEGRATOR_View_CursorTable
			(
			DataObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
			TemplateObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
			InstanceIDYN bit
			)

		INSERT INTO #pcINTEGRATOR_View_CursorTable
			(
			DataObjectName,
			TemplateObjectName,
			InstanceIDYN
			)
		SELECT 
			DataObjectName = DO.DataObjectName,
			TemplateObjectName = sub.TemplateObjectName,
			InstanceIDYN = DO.InstanceIDYN
		FROM
			DataObject DO
			LEFT JOIN (
				SELECT
					DataObjectName = REPLACE(DataObjectName, '@Template_', ''),
					TemplateObjectName = DataObjectName
				FROM 
					DataObject
				WHERE
					ObjectType = 'Template' AND
					DatabaseName = 'pcINTEGRATOR'
			) sub ON sub.DataObjectName = DO.DataObjectName
		WHERE
			DO.ObjectType = 'Table' AND
			DO.DatabaseName = 'pcINTEGRATOR_Data' AND
			DO.DeletedYN = 0 AND
--			DO.DataObjectName NOT IN ('DeletedItem') AND
			DO.CreateViewYN <> 0
		ORDER BY
			DataObjectName

		IF @Debug <> 0 SELECT TempTable = '#pcINTEGRATOR_View_CursorTable', * FROM #pcINTEGRATOR_View_CursorTable ORDER BY DataObjectName

	SET @Step = 'pcINTEGRATOR_View_Cursor'
		IF CURSOR_STATUS('global','pcINTEGRATOR_View_Cursor') >= -1 DEALLOCATE pcINTEGRATOR_View_Cursor
		DECLARE pcINTEGRATOR_View_Cursor CURSOR FOR
			
			SELECT 
				DataObjectName,
				TemplateObjectName,
				InstanceIDYN
			FROM
				#pcINTEGRATOR_View_CursorTable
			ORDER BY
				DataObjectName

			OPEN pcINTEGRATOR_View_Cursor
			FETCH NEXT FROM pcINTEGRATOR_View_Cursor INTO @TableName, @TemplateTableName, @InstanceIDYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT TableName = @TableName
					SET @Step = 'Table: ' + @TableName
					IF (SELECT COUNT(1) FROM sys.views WHERE [name] = @TableName) > 0
						BEGIN
							SET @SQLStatement = '
								DROP VIEW [' + @TableName + ']'

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Deleted = @Deleted + @@ROWCOUNT

						END

					SELECT
						@FieldList = '',
						@FieldList2 = ''
					
					SELECT 
						@FieldList = @FieldList + CHAR(13) + CHAR(10) + CHAR(9) + '[sub].[' + c.[name] + '],',
						@FieldList2 = @FieldList2 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + c.[name] + '],'
					FROM
						pcINTEGRATOR_Data.sys.tables t
						INNER JOIN pcINTEGRATOR_Data.sys.columns c ON c.object_id = t.object_id AND c.system_type_id <> 241
					WHERE
						t.[name] = @TableName
					ORDER BY
						c.column_id

					IF @Debug <> 0 SELECT FieldList = @FieldList, FieldList2 = @FieldList2

					SELECT
						@FieldList = LEFT(@FieldList, LEN(@FieldList) - 1),
						@FieldList2 = LEFT(@FieldList2, LEN(@FieldList2) - 1)

					SET
						@SQLStatement = '
CREATE VIEW [' + @TableName + '] AS
-- Current Version: ' + @Version + '
-- Created: ' + CONVERT(nvarchar(100), @StartTime) + '

SELECT ' + @FieldList + '
FROM
	(
	SELECT' + @FieldList2 + '
	FROM
		[pcINTEGRATOR_Data].[dbo].[' + @TableName + ']
	' + CASE WHEN @InstanceIDYN <> 0 THEN 'WHERE
		InstanceID NOT IN (-10, 0)' ELSE '' END + '

	' + CASE WHEN @TemplateTableName IS NOT NULL THEN '
	UNION
	SELECT' + @FieldList2 + '
	FROM
		[pcINTEGRATOR].[dbo].[' + @TemplateTableName + ']' ELSE '' END + '
	) sub'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Inserted = @Inserted + @@ROWCOUNT

					FETCH NEXT FROM pcINTEGRATOR_View_Cursor INTO @TableName, @TemplateTableName, @InstanceIDYN
				END

		CLOSE pcINTEGRATOR_View_Cursor
		DEALLOCATE pcINTEGRATOR_View_Cursor


	SET @Step = 'pcINTEGRATOR_Data_View_Cursor'
		DECLARE pcINTEGRATOR_Data_View_Cursor CURSOR FOR
			
			SELECT 
				DataObjectName
			FROM
				pcINTEGRATOR..DataObject DO
			WHERE
				DO.ObjectType = 'Table' AND
				DO.DatabaseName = 'pcINTEGRATOR' AND
				DO.DeletedYN = 0 AND
--				DO.DataObjectName NOT IN ('DeletedItem')
				DO.CreateViewYN <> 0
			ORDER BY
				DataObjectName

			OPEN pcINTEGRATOR_Data_View_Cursor
			FETCH NEXT FROM pcINTEGRATOR_Data_View_Cursor INTO @TableName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT TableName = @TableName

					IF (SELECT COUNT(1) FROM pcINTEGRATOR_Data.sys.views WHERE [name] = @TableName) > 0
						BEGIN
							SET @SQLStatement = '
								DROP VIEW [' + @TableName + ']'

							IF @Debug <> 0 PRINT @SQLStatement
							SET @SQLStatement = 'EXEC pcINTEGRATOR_Data.dbo.sp_executesql N''' + @SQLStatement + ''''
							EXEC (@SQLStatement)

							SET @Deleted = @Deleted + @@ROWCOUNT
						END

					SELECT
						@FieldList = ''
					
					SELECT 
						@FieldList = @FieldList + CHAR(13) + CHAR(10) + CHAR(9) + '[' + c.[name] + '],'
					FROM
						pcINTEGRATOR.sys.tables t
						INNER JOIN pcINTEGRATOR.sys.columns c ON c.object_id = t.object_id
					WHERE
						t.[name] = @TableName
					ORDER BY
						c.column_id

					IF @Debug <> 0 SELECT FieldList = @FieldList

					SELECT
						@FieldList = LEFT(@FieldList, LEN(@FieldList) - 1)

					SET
						@SQLStatement = '
CREATE VIEW [' + @TableName + '] AS

SELECT ' + @FieldList + '
FROM
	[pcINTEGRATOR].[dbo].[' + @TableName + ']'

					IF @Debug <> 0 PRINT @SQLStatement
					SET @SQLStatement = 'EXEC pcINTEGRATOR_Data.dbo.sp_executesql N''' + @SQLStatement + ''''
					EXEC (@SQLStatement)

					SET @Inserted = @Inserted + @@ROWCOUNT

					FETCH NEXT FROM pcINTEGRATOR_Data_View_Cursor INTO @TableName
				END

		CLOSE pcINTEGRATOR_Data_View_Cursor
		DEALLOCATE pcINTEGRATOR_Data_View_Cursor

	SET @Step = 'pcINTEGRATOR_Log_View_Cursor'
		DECLARE pcINTEGRATOR_Log_View_Cursor CURSOR FOR
			
			SELECT 
				DataObjectName,
				DatabaseName
			FROM
				pcINTEGRATOR..DataObject DO
			WHERE
				DO.ObjectType = 'Table' AND
				DO.DatabaseName IN ('pcINTEGRATOR', 'pcINTEGRATOR_Data')  AND
				DO.DeletedYN = 0 AND
				DO.DataObjectName LIKE 'Job%' AND
				DO.DataObjectName NOT IN ('Job', 'JobLog')
			ORDER BY
				DataObjectName

			OPEN pcINTEGRATOR_Log_View_Cursor
			FETCH NEXT FROM pcINTEGRATOR_Log_View_Cursor INTO @TableName, @DatabaseName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT TableName = @TableName

					IF (SELECT COUNT(1) FROM pcINTEGRATOR_Log.sys.views WHERE [name] = @TableName) > 0
						BEGIN
							SET @SQLStatement = '
								DROP VIEW [' + @TableName + ']'

							IF @Debug <> 0 PRINT @SQLStatement
							SET @SQLStatement = 'EXEC pcINTEGRATOR_Log.dbo.sp_executesql N''' + @SQLStatement + ''''
							EXEC (@SQLStatement)

							SET @Deleted = @Deleted + @@ROWCOUNT
						END

					SELECT
						@FieldList = ''
					
					IF @DatabaseName = 'pcINTEGRATOR'
						SELECT 
							@FieldList = @FieldList + CHAR(13) + CHAR(10) + CHAR(9) + '[' + c.[name] + '],'
						FROM
							pcINTEGRATOR.sys.tables t
							INNER JOIN pcINTEGRATOR.sys.columns c ON c.object_id = t.object_id
						WHERE
							t.[name] = @TableName
						ORDER BY
							c.column_id
					ELSE IF @DatabaseName = 'pcINTEGRATOR_Data'
						SELECT 
							@FieldList = @FieldList + CHAR(13) + CHAR(10) + CHAR(9) + '[' + c.[name] + '],'
						FROM
							pcINTEGRATOR_Data.sys.tables t
							INNER JOIN pcINTEGRATOR_Data.sys.columns c ON c.object_id = t.object_id
						WHERE
							t.[name] = @TableName
						ORDER BY
							c.column_id

					IF @Debug <> 0 SELECT FieldList = @FieldList

					SELECT
						@FieldList = LEFT(@FieldList, LEN(@FieldList) - 1)

					SET
						@SQLStatement = '
CREATE VIEW [' + @TableName + '] AS

SELECT ' + @FieldList + '
FROM
	[' + @DatabaseName + '].[dbo].[' + @TableName + ']'

					IF @Debug <> 0 PRINT @SQLStatement
					SET @SQLStatement = 'EXEC pcINTEGRATOR_Log.dbo.sp_executesql N''' + @SQLStatement + ''''
					EXEC (@SQLStatement)

					SET @Inserted = @Inserted + @@ROWCOUNT

					FETCH NEXT FROM pcINTEGRATOR_Log_View_Cursor INTO @TableName, @DatabaseName
				END

		CLOSE pcINTEGRATOR_Log_View_Cursor
		DEALLOCATE pcINTEGRATOR_Log_View_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE #pcINTEGRATOR_View_CursorTable

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
