SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Upgrade_pcINTEGRATOR_Data]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	@pcINTEGRATOR_Data_Source nvarchar(100) = 'pcINTEGRATOR_Data_Source',
	@pcINTEGRATOR_Data_Destination nvarchar(100) = 'pcINTEGRATOR_Data_Destination',

	@FromVersion nvarchar(100) = NULL,
	@ToVersion nvarchar(100) = NULL,

	@TruncateYN bit = 1,
	@InsertYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000411,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'sp_Tool_Upgrade_pcINTEGRATOR_Data',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [sp_Tool_Upgrade_pcINTEGRATOR_Data] @TruncateYN = 1, @InsertYN = 0, @pcINTEGRATOR_Data_Destination = 'pcINTEGRATOR_Data', @pcINTEGRATOR_Data_Source = 'pcINTEGRATOR_Data', @FromVersion = '2.1.0.2165', @ToVersion = '2.1.0.2165', @Debug=1

		CLOSE Truncate_Cursor
		DEALLOCATE Truncate_Cursor

		CLOSE Insert_Cursor
		DEALLOCATE Insert_Cursor

EXEC [sp_Tool_Upgrade_pcINTEGRATOR_Data] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

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
	@ToBeChanged nvarchar(255) = '[Upgrade].[UpgradeYN] must always be changed back to 0.',
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2159'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Truncate and refill pcINTEGRATOR_Data_Destination from a previous version of pcINTEGRATOR',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Renamed to [sp_Tool_Upgrade_pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2146' SET @Description = 'Added UPDATE statement for [WorkflowState].[VersionID]. Added Update query for [Model].[ProcessID]. Added Update query for [DataClass].'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-194, DB-195: Added Update query for VersionID of [MailMessage] table.'
		IF @Version = '2.0.2.2149' SET @Description = 'Close cursor if exists.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added call to [sp_Tool_Update_VersionID]. Enhanced Debugging.'
		IF @Version = '2.1.0.2155' SET @Description = 'Reverted UPDATE query to table [DataClass].'
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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @ToVersion IS NULL
			EXEC spGet_Version @Version = @ToVersion OUT

	SET @Step = 'Check Version'
		CREATE TABLE #Counter ([Count] INT)

		IF @FromVersion IS NULL
			BEGIN
				SET @SQLStatement = 'INSERT INTO #Counter ([Count]) SELECT [Count] = COUNT(1) FROM ' + @pcINTEGRATOR_Data_Source + '.sys.procedures WHERE name = ''spGet_Version'''
				EXEC (@SQLStatement)
				IF (SELECT [Count] FROM #Counter) > 0
					BEGIN
						SET @SQLStatement = @pcINTEGRATOR_Data_Source + '..spGet_Version @Version = @FromVersion OUT'
						EXEC sp_executesql @SQLStatement, N'@FromVersion nvarchar(50) OUT', @FromVersion = @FromVersion OUT
					END
				ELSE
					BEGIN
						SET @Message = '@FromVersion must be set as parameter.'
						SET @Severity = 16
						GOTO EXITPOINT
					END
			END

		IF @Debug <> 0	
			SELECT
				FromVersion = @FromVersion,
				ToVersion = @ToVersion

	SET @Step = 'Create temp table #Upgrade_RowCount'
		CREATE TABLE #Upgrade_RowCount (UpgradeRowCount int)

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
				IF CURSOR_STATUS('global','Truncate_Cursor') >= -1 DEALLOCATE Truncate_Cursor
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

							SET @SQLStatement = 'DELETE T FROM [' + @pcINTEGRATOR_Data_Destination + '].[dbo].[' + @TableName + '] T'

							EXEC (@SQLStatement)
							SET @Deleted = @Deleted + @@ROWCOUNT

							IF @IdentityYN <> 0 
								BEGIN
									SET @SQLStatement = 'EXEC [' + @pcINTEGRATOR_Data_Destination + '].dbo.sp_executesql N''DBCC CHECKIDENT ([' + @TableName + '], RESEED, 1000)'''
									PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

							FETCH NEXT FROM Truncate_Cursor INTO @TableName, @IdentityYN
						END

				CLOSE Truncate_Cursor
				DEALLOCATE Truncate_Cursor
			END

	SET @Step = 'Insert_Cursor'
		IF @InsertYN <> 0
			BEGIN

				SET @SQLStatement = 'UPDATE ' + @pcINTEGRATOR_Data_Destination + '..[Upgrade] SET [UpgradeYN] = 1'
				EXEC (@SQLStatement)

				CREATE TABLE #Column
					(
					[Type] nvarchar(20) COLLATE DATABASE_DEFAULT,
					[ColumnName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[SortOrder] int
					)

				CREATE TABLE #RowCounter
					(
					RowCounter int
					)

				IF CURSOR_STATUS('global','Insert_Cursor') >= -1 DEALLOCATE Insert_Cursor
				DECLARE Insert_Cursor CURSOR FOR
			
					SELECT 
						TableName = DataObjectName,
						InstanceIDYN,
						IdentityYN,
						UpgradeSP = CASE WHEN @FromVersion <= VersionLevel THEN 'spUpgrade_'+ DataObjectName END
					FROM
						DataObject
					WHERE
						ObjectType = 'Table' AND
						DatabaseName = 'pcINTEGRATOR_Data' AND
						(Introduced <= @FromVersion OR Introduced IS NULL) AND
						SelectYN <> 0 AND
						DeletedYN = 0
					ORDER BY
						SortOrder DESC

					OPEN Insert_Cursor
					FETCH NEXT FROM Insert_Cursor INTO @TableName, @InstanceIDYN, @IdentityYN, @UpgradeSP

					WHILE @@FETCH_STATUS = 0
						BEGIN
							TRUNCATE TABLE #Column
							SELECT @SQL_Insert = '', @SQL_Select = ''

							IF @Debug <> 0 SELECT TableName = @TableName, InstanceIDYN = @InstanceIDYN, IdentityYN = @IdentityYN, UpgradeSP = @UpgradeSP

							SET @SQLStatement = '
							
							INSERT INTO #Column
								(
								[Type],
								[ColumnName],
								[SortOrder]
								)
							SELECT
								[Type] = ''Dest'',
								[ColumnName] = c.[name],
								[SortOrder] = c.[column_id]
							FROM
								[' + @pcINTEGRATOR_Data_Destination +'].sys.tables t
								INNER JOIN [' + @pcINTEGRATOR_Data_Destination + '].sys.columns c ON c.object_id = t.object_id AND c.system_type_id <> 241
							WHERE
								t.[name] = ''' + @TableName + '''
							ORDER BY
								c.column_id

							INSERT INTO #Column
								(
								[Type],
								[ColumnName],
								[SortOrder]
								)
							SELECT 
								[Type] = ''Source'',
								[ColumnName] = c.[name],
								[SortOrder] = c.[column_id]
							FROM
								[' + @pcINTEGRATOR_Data_Source + '].sys.tables t
								INNER JOIN [' + @pcINTEGRATOR_Data_Source + '].sys.columns c ON c.object_id = t.object_id AND c.system_type_id <> 241
							WHERE
								t.[name] = ''' + @TableName + '''
							ORDER BY
								c.column_id'

							EXEC (@SQLStatement)

							IF (SELECT COUNT(1) FROM #Column WHERE [Type] = 'Source') > 0
								BEGIN
									TRUNCATE TABLE #RowCounter
									SET @SQLStatement = 'INSERT INTO #RowCounter (RowCounter) SELECT RowCounter = COUNT(1) FROM [' + @pcINTEGRATOR_Data_Source + ']..[' + @TableName + ']'
									EXEC(@SQLStatement)
									IF (SELECT RowCounter FROM #RowCounter) = 0 GOTO MoveNext
								END
							ELSE
								GOTO MoveNext
							
							IF @UpgradeSP IS NULL
								BEGIN
									SELECT
										@SQL_Insert = @SQL_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + D.[ColumnName] + '],',
										@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + D.[ColumnName] + '] = ' + CASE WHEN S.[ColumnName] IS NULL THEN 'NULL,' ELSE 'S.[' + S.[ColumnName] + '],' END
									FROM
										#Column D
										INNER JOIN (
											SELECT
												[ColumnName]
											FROM
												#Column
											WHERE
												[Type] = 'Source'
											) S ON S.[ColumnName] = D.[ColumnName]
									WHERE
										[Type] = 'Dest'
									ORDER BY
										D.[SortOrder]

									SELECT 
										@SQL_Insert = LEFT(@SQL_Insert, LEN(@SQL_Insert) - 1),
										@SQL_Select = LEFT(@SQL_Select, LEN(@SQL_Select) - 1)

--									(SELECT COUNT(1) FROM #Column WHERE [ColumnName] = @TableName + 'ID') = 2

									IF @IdentityYN <> 0 AND ((SELECT COUNT(1) FROM #Column WHERE [ColumnName] = @TableName + 'ID') = 2 OR @TableName IN ('DeletedItem', 'ScenarioCopyRule', 'DimensionMember'))
										SET @SQLStatement = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'SET IDENTITY_INSERT [' + @pcINTEGRATOR_Data_Destination + '].[dbo].[' + @TableName + '] ON'
									ELSE
										SET @SQLStatement = ''

									SET @SQLStatement = @SQLStatement + '
									INSERT INTO [' + @pcINTEGRATOR_Data_Destination + '].[dbo].[' + @TableName + ']
										(' + @SQL_Insert + '
										)
									SELECT' + @SQL_Select + '
									FROM
										[' + @pcINTEGRATOR_Data_Source + '].[dbo].[' + @TableName + '] S
									' + CASE WHEN @InstanceIDYN <> 0 AND CHARINDEX('InstanceID', @SQL_Insert) <> 0 THEN 'WHERE InstanceID NOT IN (-10, 0)' ELSE '' END

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SET @Inserted_Counter = @Inserted_Counter + @@ROWCOUNT

									IF @IdentityYN <> 0 AND ((SELECT COUNT(1) FROM #Column WHERE [ColumnName] = @TableName + 'ID') = 2 OR @TableName IN ('DeletedItem', 'ScenarioCopyRule', 'DimensionMember'))
										BEGIN
											SET @SQLStatement = 'SET IDENTITY_INSERT [' + @pcINTEGRATOR_Data_Destination + '].[dbo].[' + @TableName + '] OFF'
											EXEC (@SQLStatement)
										END
								END
							ELSE
								BEGIN
									TRUNCATE TABLE #Counter
									SET @SQLStatement = 'INSERT INTO #Counter ([Count]) SELECT [Count] = COUNT(1) FROM [' + @pcINTEGRATOR_Data_Destination + '].[sys].[procedures] WHERE [name] = ''' + @UpgradeSP + ''''
									EXEC (@SQLStatement)
									IF (SELECT [Count] FROM #Counter) > 0
										BEGIN
											SET @UpgradeSP = '[' + @pcINTEGRATOR_Data_Destination + '].[dbo].['+ @UpgradeSP + '] @JobID = ' + CONVERT(nvarchar(10), @JobID) + ', @pcINTEGRATOR_Data_Source = ''' + @pcINTEGRATOR_Data_Source + ''''
											IF @Debug <> 0 PRINT @UpgradeSP
											EXEC (@UpgradeSP)
										END
								END

							MoveNext:

							FETCH NEXT FROM Insert_Cursor INTO @TableName, @InstanceIDYN, @IdentityYN, @UpgradeSP
						END

				CLOSE Insert_Cursor
				DEALLOCATE Insert_Cursor

				DROP TABLE #RowCounter
				DROP TABLE #Column

				SET @SQLStatement = '
					UPDATE DC
					SET 
						[DataClassTypeID] = CASE DC.DataClassName WHEN ''FxRate'' THEN -6 WHEN ''Journal'' THEN -5 END      
					FROM 
						' + @pcINTEGRATOR_Data_Destination + '.[dbo].[DataClass] DC
					WHERE 
						DC.DataClassName IN (''FxRate'', ''Journal'')'
				EXEC (@SQLStatement)

				--UPDATE VersionID column
				EXEC [sp_Tool_Update_VersionID] @pcINTEGRATOR_Data_Destination = @pcINTEGRATOR_Data_Destination, @Debug = @DebugSub

			END
	
	SET @Step = 'Set Upgrade status to FALSE'
		
		SET @SQLStatement = 'INSERT INTO #Upgrade_RowCount (UpgradeRowCount) SELECT COUNT(1) FROM ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Upgrade]'
		EXEC (@SQLStatement)

		SELECT @Upgrade_RowCount = UpgradeRowCount FROM #Upgrade_RowCount
		
		IF @Upgrade_RowCount > 0
			SET @SQLStatement = 'UPDATE ' + @pcINTEGRATOR_Data_Destination + '..[Upgrade] SET [UpgradeYN] = 0'
		ELSE
			SET @SQLStatement = 'INSERT INTO ' + @pcINTEGRATOR_Data_Destination + '..[Upgrade] SELECT [UpgradeYN] = 0'
		EXEC (@SQLStatement)

	SET @Step = 'Set @Inserted'
		SET @Inserted = @Inserted_Counter

	SET @Step = 'Drop temp tables'
		DROP TABLE #Counter
		DROP TABLE #Upgrade_RowCount

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

/*
To take care of:

--Trigger OP
UPDATE OPDM
SET
	[DeletedID] = OP.[DeletedID]
FROM
	[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DimensionMember] OPDM
	INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.[OrganizationPositionID] = OPDM.[OrganizationPositionID] AND OP.[DeletedID] IS NOT NULL

--Trigger OP
UPDATE OPU
SET
	[DeletedID] = OP.[DeletedID]
FROM
	[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU
	INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP ON OP.[OrganizationPositionID] = OPU.[OrganizationPositionID] AND OP.[DeletedID] IS NOT NULL

--Trigger A
UPDATE AOL
SET
	[DeletedID] = A.[DeletedID]
FROM
	[pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOL
	INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.[AssignmentID] = AOL.[AssignmentID] AND A.[DeletedID] IS NOT NULL

--Trigger A
UPDATE AR
SET
	[DeletedID] = A.[DeletedID]
FROM
	[pcINTEGRATOR_Data].[dbo].[AssignmentRow] AR
	INNER JOIN [pcINTEGRATOR_Data].[dbo].[Assignment] A ON A.[AssignmentID] = AR.[AssignmentID] AND A.[DeletedID] IS NOT NULL
*/

GO
