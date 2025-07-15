SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCleanUp_TableRow]
	@UserID int = NULL,
	@InstanceID int = NULL, --Mandatory
	@VersionID int = NULL, --If @InstanceID is set and @VersionID is NULL, delete all VersionIDs and all InstanceIDs. If @VersionID is set, then only that specific VersionID will be deleted.

	@DatabaseName_CleanUp nvarchar(100) = 'pcINTEGRATOR_Data', --Mandatory
	@SaveInstanceYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000323,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose
    

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spCleanUp_TableRow',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spCleanUp_TableRow] @UserID=-10, @InstanceID=390, @VersionID=1011, @SaveInstanceYN = 1, @Debug=1

EXEC [spCleanUp_TableRow] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @Debug = 1 --Christian_14
EXEC [spCleanUp_TableRow] @UserID = -10, @InstanceID = 413, @VersionID = 1009, @Debug = 1 --CBN_Pilot
EXEC [spCleanUp_TableRow] @UserID = -10, @InstanceID = 390, @VersionID = 1011, @Debug = 1 --EFP10_INTEGRATED
EXEC [spCleanUp_TableRow] @UserID = -10, @InstanceID = 412, @VersionID = 1005, @Debug = 1 --AthenPlaza 

	CLOSE CleanUp_Cursor
	DEALLOCATE CleanUp_Cursor	

EXEC [spCleanUp_TableRow] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SaveInstanceID int,
	@DeleteInstanceID int,
	@VersionIDYN bit,
	@TableName nvarchar(100),
	@SQLStatement nvarchar(max),

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.2.2190'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Delete rows in pcINTEGRATOR_Data tables',
			@MandatoryParameter = 'SaveInstanceYN' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Use table DataObject and cursor. Exclude Customer and Instance table for Customer Instances.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-147: Deallocate CleanUp_Cursor if previously existing.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.2.2190' SET @Description = '1. Sorting by foreign keys hierarchy insteas of SortOrder. 2. Update to actual SP template. 3. Rename input @DatabaseName variable name to @DatabaseName_CleanUp'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Check if correct UserID'
		IF @UserID NOT IN (-10)
			BEGIN
				SET @Message = 'This SP can only be used by super admin'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Set InstanceID'
		IF @SaveInstanceYN <> 0
			SET @SaveInstanceID = @InstanceID
		ELSE
			SET @DeleteInstanceID = @InstanceID


	SET @Step = 'Create Cursor table'

	--If @InstanceID is set and @VersionID is NULL, delete all VersionIDs and all InstanceIDs. If @VersionID is set, then only that specific VersionID will be deleted.

	-- create sorting by foreign keys hierarchy
		DECLARE @OrderByFK TABLE(TableName NVARCHAR(100) NOT NULL,  
								 SortByFK INT NOT NULL); 

		SET @SQLStatement = 
		'
		use ' + @DatabaseName_CleanUp + ';

		WITH cte_FKtable (Child, FKConstraintName, Parent)
		AS (SELECT PO.name AS ParentTable,
				   FK.name,
				   RO.name AS ChildTable
			FROM sys.foreign_keys AS FK
				INNER JOIN sys.objects AS RO
					ON RO.object_id = FK.referenced_object_id
				INNER JOIN sys.objects AS PO
					ON PO.object_id = FK.parent_object_id),
			 cte_allTable (parent, FKConstraintName, child)
		AS (SELECT Parent,
				   FKConstraintName,
				   Child
			FROM cte_FKtable
			UNION
			SELECT O.name,
				   NULL,
				   NULL
			FROM sys.objects AS O
			WHERE type = ''U''
				  AND -- user table

				NOT EXISTS
			(
				SELECT 1
				FROM cte_FKtable
				WHERE (
						  cte_FKtable.Parent = O.name
						  OR cte_FKtable.Child = O.name
					  )
			)),
			 cte_tree (name, description, level, sort)
		AS (SELECT DISTINCT
				   parent,
				   CAST(parent AS VARCHAR(1024)),
				   1,
				   CAST(parent AS VARCHAR(1024))
			FROM cte_allTable AS a
			WHERE a.parent NOT IN
				  (
					  SELECT child FROM cte_allTable WHERE child IS NOT NULL
				  )
				  OR a.child IS NULL
			UNION ALL
			SELECT FK.Child,
				   CAST(REPLICATE(''|---'', cte_tree.level) + FK.Child AS VARCHAR(1024)),
				   cte_tree.level + 1,
				   CAST(cte_tree.sort + ''\'' + FK.Child AS VARCHAR(1024))
			FROM cte_tree
				INNER JOIN cte_FKtable AS FK
					ON cte_tree.name = FK.Parent)
		--SELECT DISTINCT
		--       name,
		--       description,
		--       level,
		--       sort
		--FROM cte_tree
		--ORDER BY sort;
		SELECT 
			   TableName = [name],
			   SortByFK = -MAX(level) -- sort by foreign_keys tree
		FROM cte_tree
		GROUP by [name]
		ORDER BY 2, [name];'

		IF @Debug <> 0 PRINT @SQLStatement

		INSERT INTO @OrderByFK
		(
			TableName,
			SortByFK
		)
		EXEC (@SQLStatement);

		IF @Debug <> 0 SELECT TempTable = '@OrderByFK', * FROM @OrderByFK ORDER BY SortByFK;

		SELECT 
			[TableName] = DO.DataObjectName,
			DO.[VersionIDYN],
			DO.[SortOrder],
			OFK.SortByFK
		INTO
			#CleanUp_CursorTable
		FROM
			[DataObject] DO
		LEFT JOIN @OrderByFK OFK ON OFK.TableName = DO.DataObjectName
		WHERE
			DO.[ObjectType] = 'Table' AND
			DO.[DatabaseName] = @DatabaseName_CleanUp AND
			DO.[SelectYN] <> 0 AND
			DO.[DeletedYN] = 0 AND
			DO.[InstanceIDYN] <> 0 AND
			(DO.[VersionIDYN] <> 0 OR @VersionID IS NULL)
		ORDER BY
			--DO.[SortOrder]
			OFK.SortByFK,
			DO.DataObjectName

		IF @Debug <> 0 SELECT TempTable = '#CleanUp_CursorTable', * FROM #CleanUp_CursorTable ORDER BY SortByFK, TableName--[SortOrder]

	SET @Step = 'CleanUp Cursor'
		IF CURSOR_STATUS('global','CleanUp_Cursor') >= -1 DEALLOCATE CleanUp_Cursor
		DECLARE CleanUp_Cursor CURSOR FOR
			
			SELECT 
				[TableName],
				[VersionIDYN]
			FROM
				#CleanUp_CursorTable
			ORDER BY
				--[SortOrder]
				SortByFK, TableName

			OPEN CleanUp_Cursor
			FETCH NEXT FROM CleanUp_Cursor INTO @TableName, @VersionIDYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT TableName = @TableName
					
					IF @InstanceID > -1000 AND @TableName IN ('Customer', 'Instance') AND @SaveInstanceYN = 0
					GOTO CUSTOMER_INSTANCE
					
						IF @SaveInstanceYN <> 0
							BEGIN
								SET @SQLStatement = '
								DELETE [' + @DatabaseName_CleanUp + '].[dbo].[' + @TableName + ']
								WHERE
									InstanceID NOT IN (' + CONVERT(nvarchar(10), @SaveInstanceID) + ')'
							END
						ELSE
							BEGIN
								SET @SQLStatement = '
								DELETE [' + @DatabaseName_CleanUp + '].[dbo].[' + @TableName + ']
								WHERE
									InstanceID IN (' + CONVERT(nvarchar(10), @DeleteInstanceID) + ')' + 
									CASE WHEN @VersionID IS NOT NULL AND @VersionIDYN <> 0 THEN ' AND VersionID IN (' + CONVERT(nvarchar(10), @VersionID) + ')' ELSE '' END
							END

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					
						SET @Deleted = @Deleted + @@ROWCOUNT

					CUSTOMER_INSTANCE:

					FETCH NEXT FROM CleanUp_Cursor INTO @TableName, @VersionIDYN
				END

		CLOSE CleanUp_Cursor
		DEALLOCATE CleanUp_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
