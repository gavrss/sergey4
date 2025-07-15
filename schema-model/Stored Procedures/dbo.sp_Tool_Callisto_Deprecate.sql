SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Callisto_Deprecate]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ApplicationName nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000860,
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
EXEC [sp_Tool_Callisto_Deprecate] @ApplicationName = 'NEHA1', @DebugBM = 3
EXEC [sp_Tool_Callisto_Deprecate] @UserID = -10, @InstanceID = -1714, @VersionID = -1714, @DebugBM = 3

EXEC [sp_Tool_Callisto_Deprecate] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@ObjectName nvarchar(100),
	@OLAPServer nvarchar(100),
	@XMLA nvarchar(1000),

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Convert Callisto to Enhanced Storage',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2191' SET @Description = 'Procedure created.'

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

		SELECT
			@InstanceID = ISNULL(@InstanceID, [InstanceID]),
			@VersionID = ISNULL(@VersionID, [VersionID]),
			@ApplicationName = ISNULL(@ApplicationName, [ApplicationName]),
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = [ETLDatabase]
		FROM
			pcINTEGRATOR_Data..[Application]
		WHERE
			(
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID
			) OR
			[ApplicationName] = @ApplicationName

		SELECT @OLAPServer = CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(100)) + '_OLAP'

		IF @DebugBM & 2 > 0
			SELECT
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@ApplicationName] = @ApplicationName,
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@OLAPServer] = @OLAPServer

	SET @Step = 'Create #CursorTable'	
		CREATE TABLE #CursorTable
			(
			[SortOrder] int IDENTITY(1,1),
			[ObjectName] nvarchar(100) COLLATE DATABASE_DEFAULT
			)
			
	SET @Step = 'Set to Enhanced Storage'
		UPDATE A
		SET
			[EnhancedStorageYN] = 1 
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

	SET @Step = 'Drop AS Database'
		CREATE TABLE #OlapDB (DBName nvarchar(100))

		SET @SQLStatement = '
			INSERT INTO #OlapDB
				(
				DBName
				) 
			SELECT
				DBName = CATALOG_NAME
			FROM
				Openquery(' + @OLAPServer + ',''SELECT * from $System.DBSCHEMA_CATALOGS'')'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement

		SET ANSI_WARNINGS ON	
		BEGIN TRY
			EXEC (@SQLStatement)
		END TRY
        BEGIN CATCH
			-- do nothing on SSAS does't exist
		END CATCH
		SET ANSI_WARNINGS OFF

		IF @DebugBM & 2 > 0 SELECT TempTable = '#OlapDB', * FROM #OlapDB ORDER BY DBName

	--Delete OLAP database
		IF (SELECT COUNT(1) FROM #OlapDB WHERE DBName = @CallistoDatabase) > 0
			BEGIN
				Set @XMLA = N'<Delete xmlns="http://schemas.microsoft.com/analysisservices/2003/engine">
<Object>
<DatabaseID>' + @CallistoDatabase + '</DatabaseID>
</Object>
</Delete>';
				SET @SQLStatement = 'EXEC (N''' + @XMLA + ''') At ' + CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(100)) + '_OLAP;'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Delete rows in CallistoAppDictionary'
		IF DB_ID('CallistoAppDictionary') IS NOT NULL
			BEGIN
				DELETE [CallistoAppDictionary].[dbo].[Applications]
				WHERE
					[ApplicationLabel] = @CallistoDatabase

				DELETE [CallistoAppDictionary].[dbo].[ApplicationAdmins]
				WHERE
					[ApplicationLabel] = @CallistoDatabase

				DELETE [CallistoAppDictionary].[dbo].[ApplicationUsers]
				WHERE
					[ApplicationLabel] = @CallistoDatabase

				DELETE [CallistoAppDictionary].[dbo].[ModelUsers]
				WHERE
					[ApplicationLabel] = @CallistoDatabase
			END

	SET @Step = 'Delete tables in pcDATA'
		TRUNCATE TABLE #CursorTable

		SET @SQLStatement = '
			INSERT INTO #CursorTable
				(
				[ObjectName]
				)
			SELECT
				[ObjectName] = ''[' + @CallistoDatabase + '].[dbo].['' + [name] + '']''
			FROM
				[' + @CallistoDatabase + '].[sys].[tables]
			WHERE
				[name] NOT LIKE ''FACT_%_default_partition'' AND
				[name] NOT LIKE ''FACT_%_text'' AND
				[name] NOT LIKE ''S_DS_%'' AND
				[name] NOT LIKE ''S_HS_%''
			ORDER BY
				[name]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT ObjectType = 'CallistoTable', * FROM #CursorTable ORDER BY [SortOrder]

		IF CURSOR_STATUS('global','CallistoTable_Cursor') >= -1 DEALLOCATE CallistoTable_Cursor
		DECLARE CallistoTable_Cursor CURSOR FOR
			
			SELECT 
				[ObjectName]
			FROM
				#CursorTable
			ORDER BY
				[SortOrder]

			OPEN CallistoTable_Cursor
			FETCH NEXT FROM CallistoTable_Cursor INTO @ObjectName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ObjectName] = @ObjectName

					SET @SQLStatement = 'DROP TABLE ' + @ObjectName
					EXEC (@SQLStatement)

					FETCH NEXT FROM CallistoTable_Cursor INTO @ObjectName
				END

		CLOSE CallistoTable_Cursor
		DEALLOCATE CallistoTable_Cursor

	SET @Step = 'Delete views in pcDATA'
		TRUNCATE TABLE #CursorTable

		SET @SQLStatement = '
			INSERT INTO #CursorTable
				(
				[ObjectName]
				)
			SELECT
				[ObjectName] = [name]
			FROM
				[' + @CallistoDatabase + '].[sys].[views]
			ORDER BY
				[name]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT ObjectType = 'CallistoView', * FROM #CursorTable ORDER BY [SortOrder]

		IF CURSOR_STATUS('global','CallistoView_Cursor') >= -1 DEALLOCATE CallistoView_Cursor
		DECLARE CallistoView_Cursor CURSOR FOR
			
			SELECT 
				[ObjectName]
			FROM
				#CursorTable
			ORDER BY
				[SortOrder]

			OPEN CallistoView_Cursor
			FETCH NEXT FROM CallistoView_Cursor INTO @ObjectName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ObjectName] = @ObjectName

					SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''DROP VIEW ' + @ObjectName + ''''
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					
					FETCH NEXT FROM CallistoView_Cursor INTO @ObjectName
				END

		CLOSE CallistoView_Cursor
		DEALLOCATE CallistoView_Cursor

	SET @Step = 'Delete procedures in pcDATA'
		TRUNCATE TABLE #CursorTable

		SET @SQLStatement = '
			INSERT INTO #CursorTable
				(
				[ObjectName]
				)
			SELECT
				[ObjectName] = [name]
			FROM
				[' + @CallistoDatabase + '].[sys].[procedures]
			ORDER BY
				[name]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT ObjectType = 'CallistoProcedure', * FROM #CursorTable ORDER BY [SortOrder]

		IF CURSOR_STATUS('global','CallistoProcedure_Cursor') >= -1 DEALLOCATE CallistoProcedure_Cursor
		DECLARE CallistoProcedure_Cursor CURSOR FOR
			
			SELECT 
				[ObjectName]
			FROM
				#CursorTable
			ORDER BY
				[SortOrder]

			OPEN CallistoProcedure_Cursor
			FETCH NEXT FROM CallistoProcedure_Cursor INTO @ObjectName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ObjectName] = @ObjectName

					SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''DROP PROCEDURE ' + @ObjectName + ''''
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					
					FETCH NEXT FROM CallistoProcedure_Cursor INTO @ObjectName
				END

		CLOSE CallistoProcedure_Cursor
		DEALLOCATE CallistoProcedure_Cursor

	SET @Step = 'Delete tables in pcETL'
		TRUNCATE TABLE #CursorTable

		SET @SQLStatement = '
			INSERT INTO #CursorTable
				(
				[ObjectName]
				)
			SELECT
				[ObjectName] = ''[' + @ETLDatabase + '].[dbo].['' + [name] + '']''
			FROM
				[' + @ETLDatabase + '].[sys].[tables]
			WHERE
				[name] NOT IN (''Journal'') AND
				(
				[name] LIKE ''XT_%'' OR
				[name] IN
					(
					''AccountType'',
					''AccountType_Translate'',
					''BudgetSelection'',
					''CheckSum'',
					''CheckSumLog'',
					''ClosedPeriod'',
					''Digit'',
					''Entity'',
					''FinancialSegment'',
					''FiscalPeriod_BusinessProcess'',
					''Frequency'',
					''Job'',
					''JobLog'',
					''Load'',
					''LoadType'',
					''MappedLabel'',
					''MappedObject'',
					''MappingType'',
					''MemberSelection'',
					''ReplaceText'',
					''ReplaceText_ScanLog'',
					''wrk_Debug'',
					''wrk_Dimension'',
					''wrk_EntityPriority_Member'',
					''wrk_EntityPriority_SQLStatement'',
					''wrk_FACT_Update'',
					''wrk_SBZ_Check''
					)
				)
			ORDER BY
				[name]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT ObjectType = 'ETLTable', * FROM #CursorTable ORDER BY [SortOrder]

		IF CURSOR_STATUS('global','ETLTable_Cursor') >= -1 DEALLOCATE ETLTable_Cursor
		DECLARE ETLTable_Cursor CURSOR FOR
			
			SELECT 
				[ObjectName]
			FROM
				#CursorTable
			ORDER BY
				[SortOrder]

			OPEN ETLTable_Cursor
			FETCH NEXT FROM ETLTable_Cursor INTO @ObjectName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ObjectName] = @ObjectName

					SET @SQLStatement = 'DROP TABLE ' + @ObjectName
					EXEC (@SQLStatement)

					FETCH NEXT FROM ETLTable_Cursor INTO @ObjectName
				END

		CLOSE ETLTable_Cursor
		DEALLOCATE ETLTable_Cursor

	SET @Step = 'Delete procedures in pcETL'
		TRUNCATE TABLE #CursorTable

		SET @SQLStatement = '
			INSERT INTO #CursorTable
				(
				[ObjectName]
				)
			SELECT
				[ObjectName] = [name]
			FROM
				[' + @ETLDatabase + '].[sys].[procedures]
			WHERE
				[name] NOT LIKE ''%_HC'' AND
				(
				[name] LIKE ''spForm%'' OR
				[name] LIKE ''spCheck%'' OR
				[name] LIKE ''spCreate%'' OR
				[name] LIKE ''spIU_0000%'' OR
				[name] IN
					(
					''sp_AddDays'',
					''sp_CheckObject'',
					''sp_ScanText'',
					''spFix_ChangedLabel'',
					''spIU_Load_All'',
					''spRun_BR_All'',
					''spSet_HierarchyCopy'',
					''spSet_JobLog'',
					''spSet_LeafCheck'',
					''spSet_MemberId'',
					''spIU_wrk_FACT_FxTrans''
					)
				)
			ORDER BY
				[name]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT ObjectType = 'ETLProcedure', * FROM #CursorTable ORDER BY [SortOrder]

		IF CURSOR_STATUS('global','ETLProcedure_Cursor') >= -1 DEALLOCATE ETLProcedure_Cursor
		DECLARE ETLProcedure_Cursor CURSOR FOR
			
			SELECT 
				[ObjectName]
			FROM
				#CursorTable
			ORDER BY
				[SortOrder]

			OPEN ETLProcedure_Cursor
			FETCH NEXT FROM ETLProcedure_Cursor INTO @ObjectName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ObjectName] = @ObjectName

					SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''DROP PROCEDURE ' + @ObjectName + ''''
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					
					FETCH NEXT FROM ETLProcedure_Cursor INTO @ObjectName
				END

		CLOSE ETLProcedure_Cursor
		DEALLOCATE ETLProcedure_Cursor

	SET @Step = 'Recreate FACT views'
		EXEC [dbo].[spSetup_Fact_View] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @Debug = @DebugSub

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
