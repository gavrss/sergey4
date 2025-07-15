SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_GUID]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@TableName nvarchar(100) = NULL,
	@Database nvarchar(100) = 'pcINTEGRATOR_Data',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000188,
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
EXEC [dbo].[spSet_GUID] @UserID = -10, @TableName = 'Scenario', @Debug = 1
EXEC [dbo].[spSet_GUID] @UserID = -10, @TableName = 'Workflow', @Debug = 1
EXEC [dbo].[spSet_GUID] @UserID = -10, @TableName = 'Assignment', @Debug = 1
EXEC [dbo].[spSet_GUID] @UserID = -10, @TableName = 'OrganizationHierarchy', @Debug = 1
EXEC [dbo].[spSet_GUID] @UserID = -10, @TableName = 'OrganizationPosition', @Debug = 1
EXEC [dbo].[spSet_GUID] @UserID = -10, @TableName = 'DataClass', @Debug = 1
EXEC [dbo].[spSet_GUID] @UserID = -10, @TableName = 'Measure', @Debug = 1
EXEC [dbo].[spSet_GUID] @UserID = -10, @TableName = 'Process', @Debug = 1
EXEC [dbo].[spSet_GUID] @UserID = -10, @TableName = 'Entity', @Debug = 1

EXEC [spSet_GUID] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@MemberID int,
	@GUID uniqueidentifier,
	@SQLStatement nvarchar(max),
	@InstanceID_Cursor int,
	@VersionID_Cursor int,

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
	@Version nvarchar(50) = '2.0.3.2151'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set GUID',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2137' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2139' SET @Description = 'Handle duplicates.'
		IF @Version = '2.0.2.2146' SET @Description = 'New template.'
		IF @Version = '2.0.3.2151' SET @Description = 'Set correct ProcedureID.'

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

		SELECT
			@InstanceID = ISNULL(@InstanceID, 0),
			@VersionID = ISNULL(@VersionID, 0)

	SET @Step = 'Create and fill Cursor Table'
		CREATE TABLE #Member
			(
			InstanceID int,
			MemberID int,
			VersionID int
			)

	SET @Step = 'Fill Cursor Table when GUID is NULL'
		SET @SQLStatement = '
			INSERT INTO #Member
				(
				InstanceID,
				MemberID,
				VersionID
				)
			SELECT 
				InstanceID = InstanceID,
				MemberID = ' + @TableName + 'ID,
				VersionID = ISNULL(VersionID, 0)
			FROM
				' + @Database + '.[dbo].[' + @TableName + ']
			WHERE
				GUID IS NULL'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Fill Cursor Table when multiple GUID ON same VersionID'
		SET @SQLStatement = '
			INSERT INTO #Member
				(
				InstanceID,
				MemberID,
				VersionID
				)
			SELECT 
				T.InstanceID,
				MemberID = T.' + @TableName + 'ID,
				T.VersionID 
			FROM
				' + @Database + '.[dbo].[' + @TableName + '] T
				INNER JOIN (
					SELECT
						[GUID],
						[VersionID]
					FROM
						' + @Database + '.[dbo].[' + @TableName + ']
					GROUP BY
						[GUID],
						[VersionID]
					HAVING
						COUNT(1) > 1
				) G ON G.[GUID] = T.[GUID]
			WHERE
				NOT EXISTS (SELECT 1 FROM #Member M WHERE M.InstanceID = T.InstanceID AND M.MemberID = T.' + @TableName + 'ID AND M.VersionID = T.VersionID)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Fill Cursor Table when multiple GUID ON different InstanceID'
		SET @SQLStatement = '
			INSERT INTO #Member
				(
				InstanceID,
				MemberID,
				VersionID
				)
			SELECT 
				T.InstanceID,
				MemberID = T.' + @TableName + 'ID,
				T.VersionID 
			FROM
				' + @Database + '.[dbo].[' + @TableName + '] T
				INNER JOIN 
				(
				SELECT
					I.[GUID]
				FROM
					(
					SELECT DISTINCT
						T.InstanceID,
						T.[GUID]
					FROM
						' + @Database + '.[dbo].[' + @TableName + '] T
						INNER JOIN (
							SELECT
								[GUID],
								temp = COUNT(1)
							FROM
								' + @Database + '.[dbo].[' + @TableName + ']
							GROUP BY
								[GUID]
							HAVING
								COUNT(1) > 1
						) G ON G.[GUID] = T.[GUID]
					) I 
				GROUP BY
					I.[GUID]
				HAVING
					COUNT(1) > 1
				) S ON S.[GUID] = T.[GUID]
			WHERE
				NOT EXISTS (SELECT 1 FROM #Member M WHERE M.InstanceID = T.InstanceID AND M.MemberID = T.' + @TableName + 'ID AND M.VersionID = T.VersionID)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Run GUID_Cursor'
		DECLARE GUID_Cursor CURSOR FOR

			SELECT
				InstanceID, 
				MemberID,
				VersionID
			FROM
				#Member

			OPEN GUID_Cursor
			FETCH NEXT FROM GUID_Cursor INTO @InstanceID_Cursor, @MemberID, @VersionID_Cursor

			WHILE @@FETCH_STATUS = 0
				BEGIN
					EXEC [dbo].[spGet_GUID] @UserID = @UserID, @InstanceID = @InstanceID_Cursor, @VersionID = @VersionID_Cursor, @TableName = @TableName, @GUID = @GUID OUT
					IF @Debug <> 0 SELECT MemberID = @MemberID, [GUID] = @GUID, VersionID_Cursor = @VersionID_Cursor

					SET @SQLStatement = '
						UPDATE T
						SET
							[GUID] = ''' + CONVERT(nvarchar(100), @GUID) + ''',
							[VersionID] = ' + CONVERT(nvarchar(10), @VersionID_Cursor) + '
						FROM 
							' + @Database + '.[dbo].[' + @TableName + '] T
						WHERE
							' + @TableName + 'ID = ' + CONVERT(nvarchar(10), @MemberID)
					
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Updated = @Updated + @@ROWCOUNT

					FETCH NEXT FROM GUID_Cursor INTO @InstanceID_Cursor, @MemberID, @VersionID_Cursor
				END

		CLOSE GUID_Cursor
		DEALLOCATE GUID_Cursor

	SET @Step = 'Delete changed GUIDs'
		SET @SQLStatement = '
			DELETE UI
			FROM
				[pcINTEGRATOR_Data].[dbo].[UniqueIdentifier] UI
			WHERE
				UI.TableName = ''' + @TableName + ''' AND
				NOT EXISTS (SELECT 1 FROM ' + @Database + '.[dbo].[' + @TableName + '] T WHERE T.[GUID] = UI.[GUID])'
	
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)	
		
		SET @Deleted = @Deleted + @@ROWCOUNT	

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Member

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
