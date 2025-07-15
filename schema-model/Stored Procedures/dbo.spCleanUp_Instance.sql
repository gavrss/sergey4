SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCleanUp_Instance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SavedListYN bit = 0, --If set to 1, then delete all defined in [wrk_DeleteList]; @AssignedInstanceID and @AssignedVersionID do not matter.
	@DeleteAllDemoYN bit = 0, --If set to 1, then delete all InstanceIDs < -1000, including all Versions; @AssignedInstanceID and @AssignedVersionID do not matter.
	@AssignedInstanceID int = NULL,--is Mandatory if @SavedListYN and @DeleteAllDemoYN are both set to 0.
	@AssignedVersionID int = NULL, --If @AssignedInstanceID is set and @AssignedVersionID is NULL, delete all VersionIDs and all InstanceIDs. If @AssignedVersionID is set, then only that specific VersionID will be deleted.

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000267,
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
EXEC spRun_Procedure_KeyValuePairCreate temp table for Olap databases
	@ProcedureName = 'spCleanUp_Instance',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'
EXEC spCleanUp_Instance @AssignedInstanceID='419',@AssignedInstanceID='419'@InstanceID='0',@UserID='-10',@VersionID='0', @Debug = 1
EXEC spCleanUp_Instance @AssignedInstanceID='114', @UserID='-10', @Debug = 1

EXEC [spCleanUp_Instance] @UserID = -10, @AssignedInstanceID = -1315, @Debug = 1

-- Delete specific Instance and Version
EXEC [spCleanUp_Instance] @UserID = -10, @AssignedInstanceID = -1315, @AssignedVersionID = -1315, @Debug = 1

EXEC spCleanUp_Instance @AssignedInstanceID='-1279',@UserID='-10',@AssignedVersionID='-1217',@ProcedureID=880000267,@StartTime='2019-06-01 10:38:51.293', @Debug = 1

EXEC [spCleanUp_Instance] @UserID = -10, @AssignedInstanceID = -1083, @AssignedVersionID = -1083, @SavedListYN = 1, @Debug = 1 --Delete all defined in [wrk_DeleteList]
EXEC [spCleanUp_Instance] @UserID = -10, @AssignedInstanceID = -1196, @AssignedVersionID = -1134, @DeleteAllDemoYN = 1, @Debug = 1 --Delete all Demo Instances

	CLOSE Instance_Cursor
	DEALLOCATE Instance_Cursor	

	CLOSE CleanUp_Cursor
	DEALLOCATE CleanUp_Cursor	

EXEC [spCleanUp_Instance] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),	
	@CustomerID int,
	@ApplicationID int,
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase_Linked nvarchar(100),
	@job_name nvarchar(100),
	@LinkedServer nvarchar(100),
	@XMLA nvarchar(1000),
	@OLAPServer NVARCHAR(100),
	@DeleteETLDatabase_LinkedYN bit = 0, --Should only be set to 1 when running in PROD environment.
	@TabularVersionID int,
	@MaxID int,

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
			@ProcedureDescription = 'Cleanup of Instance',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, implemented @OLAPServer.'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-32 Delete Instance Fails.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-138: Added @AssignedInstanceID and @AssignedVersionID - use these parameters to delete an Instance and/or Version. DB-147: Deallocate Instance_Cursor if previously existing. DB-149 and DB-153: Modified dynamic sql for deleting Olap database. DB-162: Implement [ErasableYN] column on [pcINTEGRATOR_Data].[dbo].[Version]. DB-166: Added sp call to delete tabular database.'
		IF @Version = '2.0.3.2151' SET @Description = 'Omitted checking of positive InstanceIDs. Instances/Versions not to be deleted should be set at [Version], [ErasableYN] column.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-313: Ability to delete positive InstanceID and delete Customers without Instances.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID. Reset ID counters for main tables. Added Job handling'
		IF @Version = '2.1.0.2159' SET @Description = 'Renamed Instance_Cursor to Master_Instance_Cursor. Check VersionID IS NULL before deleting Instances and Version independent data. Use sub routine [spSet_Job].'
		IF @Version = '2.1.2.2190' SET @Description = 'Ignore unexisting OLAPs. Upgraded to actual SP template.'


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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@InstanceID = @AssignedInstanceID,
			@VersionID = @AssignedVersionID

		SET @AssignedVersionID = ISNULL(@AssignedVersionID, 0)

		SELECT @OLAPServer = CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(100)) + '_OLAP'

		IF CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(100)) LIKE '%PROD%'
			SET @DeleteETLDatabase_LinkedYN = 1 --Should only be set to 1 when running in PROD environment.
		ELSE
			SET @DeleteETLDatabase_LinkedYN = 0

	SET @Step = 'Start Job'
		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@AssignedVersionID,
			@ActionType='Start',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobQueueYN=0,
			@CheckCount=0,
			@JobID=@JobID OUT

	SET @Step = 'SP-Specific check'
		IF (SELECT 1 FROM [Version] WHERE InstanceID = @InstanceID AND (VersionID = @VersionID OR @VersionID IS NULL) AND ErasableYN = 0) <> 0
			BEGIN
				SET @Message = 'This Instance and Version is NOT ERASABLE.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp table'
		CREATE TABLE #Count ([Count] int)

	SET @Step = 'Refill wrk_DeleteList_Last'
		TRUNCATE TABLE wrk_DeleteList_Last

		IF @SavedListYN <> 0
			INSERT INTO wrk_DeleteList_Last
				(
				CustomerID,
				InstanceID,
				VersionID,
				ApplicationID,
				ETLDatabase,
				CallistoDatabase,
				ETLDatabase_Linked,
				Inserted
				)
			SELECT
				sub1.CustomerID,
				sub1.InstanceID,
				sub1.VersionID,
				sub1.ApplicationID,
				sub1.ETLDatabase,
				sub1.CallistoDatabase,
				sub2.ETLDatabase_Linked,
				Inserted = GetDate()
			FROM
				wrk_DeleteList wDL
				INNER JOIN
					(
					SELECT DISTINCT
						I.CustomerID,
						I.InstanceID,
						A.VersionID,
						A.ApplicationID,
						A.ETLDatabase,
						CallistoDatabase = A.DestinationDatabase
					FROM
						Instance I
						INNER JOIN [Version] V ON V.InstanceID = I.InstanceID AND V.ErasableYN <> 0
						LEFT JOIN [Application] A ON A.InstanceID = I.InstanceID AND A.VersionID = V.VersionID
					WHERE
						I.InstanceID < -1000
					) sub1 ON
						sub1.InstanceID = wDL.InstanceID AND
						(sub1.VersionID = wDL.VersionID OR wDL.VersionID IS NULL)
				LEFT JOIN
					(
					SELECT DISTINCT
						I.CustomerID,
						I.InstanceID,
						A.ApplicationID,
						S.ETLDatabase_Linked
					FROM
						Instance I
						INNER JOIN [Version] V ON V.InstanceID = I.InstanceID AND V.ErasableYN <> 0
						INNER JOIN [Application] A ON A.InstanceID = I.InstanceID AND A.VersionID = V.VersionID
						INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID
						INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.ETLDatabase_Linked IS NOT NULL
					WHERE
						I.InstanceID < -1000
					) sub2 ON 
						sub2.CustomerID = sub1.CustomerID AND
						sub2.InstanceID = sub1.InstanceID AND
						sub2.ApplicationID = sub1.ApplicationID

		ELSE IF @DeleteAllDemoYN <> 0
			INSERT INTO wrk_DeleteList_Last
				(
				CustomerID,
				InstanceID,
				VersionID,
				ApplicationID,
				ETLDatabase,
				CallistoDatabase,
				ETLDatabase_Linked,
				Inserted
				)
			SELECT
				sub1.CustomerID,
				sub1.InstanceID,
				VersionID = NULL,
				sub1.ApplicationID,
				sub1.ETLDatabase,
				sub1.CallistoDatabase,
				sub2.ETLDatabase_Linked,
				Inserted = GetDate()
			FROM
				(
				SELECT DISTINCT
					I.CustomerID,
					I.InstanceID,
					A.ApplicationID,
					A.ETLDatabase,
					CallistoDatabase = A.DestinationDatabase
				FROM
					Instance I
					INNER JOIN [Version] V ON V.InstanceID = I.InstanceID AND V.ErasableYN <> 0
					LEFT JOIN [Application] A ON A.InstanceID = I.InstanceID AND A.VersionID = V.VersionID
				WHERE
					I.InstanceID < -1000
				) sub1
				LEFT JOIN
				(
				SELECT DISTINCT
					I.CustomerID,
					I.InstanceID,
					A.ApplicationID,
					S.ETLDatabase_Linked
				FROM
					Instance I
					INNER JOIN [Version] V ON V.InstanceID = I.InstanceID AND V.ErasableYN <> 0
					INNER JOIN [Application] A ON A.InstanceID = I.InstanceID AND A.VersionID = V.VersionID
					INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID
					INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.ETLDatabase_Linked IS NOT NULL
				WHERE
					I.InstanceID < -1000
				) sub2 ON 
					sub2.CustomerID = sub1.CustomerID AND
					sub2.InstanceID = sub1.InstanceID AND
					sub2.ApplicationID = sub1.ApplicationID

		ELSE 
			INSERT INTO wrk_DeleteList_Last
				(
				CustomerID,
				InstanceID,
				VersionID,
				ApplicationID,
				ETLDatabase,
				CallistoDatabase,
				ETLDatabase_Linked,
				Inserted
				)
			SELECT
				sub1.CustomerID,
				sub1.InstanceID,
				VersionID = @VersionID,
				sub1.ApplicationID,
				sub1.ETLDatabase,
				sub1.CallistoDatabase,
				sub2.ETLDatabase_Linked,
				Inserted = GetDate()
			FROM
				(
				SELECT DISTINCT
					I.CustomerID,
					I.InstanceID,
					V.VersionID,
					A.ApplicationID,
					A.ETLDatabase,
					CallistoDatabase = A.DestinationDatabase
				FROM
					[Instance] I
					LEFT JOIN [Version] V  ON V.InstanceID = I.InstanceID AND (V.VersionID = @VersionID OR @VersionID IS NULL) AND V.ErasableYN <> 0
					LEFT JOIN [Application] A ON A.InstanceID = V.InstanceID AND A.VersionID = V.VersionID					
				WHERE
					I.InstanceID = @InstanceID
				) sub1
				LEFT JOIN
				(
				SELECT DISTINCT
					I.CustomerID,
					I.InstanceID,
					A.ApplicationID,
					S.ETLDatabase_Linked
				FROM
					Instance I
					INNER JOIN [Version] V ON V.InstanceID = I.InstanceID AND V.ErasableYN <> 0
					INNER JOIN [Application] A ON A.InstanceID = I.InstanceID AND A.VersionID = V.VersionID
					INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID
					INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.ETLDatabase_Linked IS NOT NULL
				WHERE
					I.InstanceID = @InstanceID AND
					(A.VersionID = @VersionID OR @VersionID IS NULL)
				) sub2 ON 
					sub2.CustomerID = sub1.CustomerID AND
					sub2.InstanceID = sub1.InstanceID AND
					sub2.ApplicationID = sub1.ApplicationID

					
		IF @Debug <> 0 SELECT wrkTable = 'wrk_DeleteList_Last', * FROM dbo.wrk_DeleteList_Last

	--SET @Step = 'Check no positive InstanceIDs get deleted'
	--	IF (SELECT COUNT(1) FROM wrk_DeleteList_Last WHERE InstanceID >= -1000) > 0
	--		BEGIN
	--			SET @Message = 'It is not allowed to delete any Instances in production (InstanceID >= -1000) by this routine.'
	--			SET @Severity = 16
	--			GOTO EXITPOINT
	--		END

	SET @Step = 'Create temp table for Olap databases'	
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

		IF @Debug <> 0 PRINT @SQLStatement

--		SET ANSI_WARNINGS ON	
		BEGIN TRY
			EXEC (@SQLStatement)
		END TRY
        BEGIN CATCH
			-- do nothing on SSAS does't exist
		END CATCH

        
--		SET ANSI_WARNINGS OFF
		
		IF @Debug <> 0 SELECT TempTable = '#OlapDB', * FROM #OlapDB ORDER BY DBName
		IF @Debug <> 0 SELECT TempTable = 'wrk_DeleteList_Last', * FROM wrk_DeleteList_Last

	SET @Step = 'Create Cursor for all Instances and Applications'
		IF CURSOR_STATUS('global','Master_Instance_Cursor') >= -1 DEALLOCATE Master_Instance_Cursor
		DECLARE Master_Instance_Cursor CURSOR FOR
			SELECT
				CustomerID,
				InstanceID,
				VersionID,
				ApplicationID,
				ETLDatabase,
				CallistoDatabase,
				ETLDatabase_Linked
			FROM
				wrk_DeleteList_Last
			ORDER BY
				InstanceID

			OPEN Master_Instance_Cursor
			FETCH NEXT FROM Master_Instance_Cursor INTO @CustomerID, @InstanceID, @VersionID, @ApplicationID, @ETLDatabase, @CallistoDatabase, @ETLDatabase_Linked

			WHILE @@FETCH_STATUS = 0
				BEGIN
	SET @Step = 'Create Cursor for all Instances and Applications'
					IF @Debug <> 0 SELECT CustomerID = @CustomerID, InstanceID = @InstanceID, VersionID = @VersionID, ApplicationID = @ApplicationID, ETLDatabase = @ETLDatabase, CallistoDatabase = @CallistoDatabase, ETLDatabase_Linked = @ETLDatabase_Linked

					--Delete logins in AD
					---------------------------
					--#### Has to be added ####
					---------------------------
					
					--Delete OLAP database
						IF (SELECT COUNT(1) FROM #OlapDB WHERE DBName = @CallistoDatabase) > 0
							BEGIN
								Set @XMLA = N'<Delete xmlns="http://schemas.microsoft.com/analysisservices/2003/engine">
<Object>
<DatabaseID>' + @CallistoDatabase + '</DatabaseID>
</Object>
</Delete>';
					-- Execute the string across the linked server (SSAS)
								--SET @SQLStatement = 'EXEC ' +  @@SERVERNAME + '_OLAP.' + @CallistoDatabase + '.dbo.sp_executesql N''' + @XMLA + ''''
								--EXEC (@XMLA) At EFPDEMO02_OLAP;
								SET @SQLStatement = 'EXEC (N''' + @XMLA + ''') At ' + CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(100)) + '_OLAP;'

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
							END
				
					--Delete Job
						SET @job_name = @CallistoDatabase + '_Create'
						IF (SELECT COUNT(1) FROM msdb.dbo.sysjobs WHERE [name] = @job_name) > 0
								EXEC msdb..sp_delete_job @job_name = @job_name

						SET @job_name = @CallistoDatabase + '_Load'
						IF (SELECT COUNT(1) FROM msdb.dbo.sysjobs WHERE [name] = @job_name) > 0
								EXEC msdb..sp_delete_job @job_name = @job_name

					--Delete Tabular Database
					SET @TabularVersionID = ISNULL(@VersionID, 0)
 					EXEC [spRun_Job_Tabular_Generic] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @TabularVersionID, @DataClassID = 0, @Action = 'Delete', @AsynchronousYN = 0, @JobID = @JobID

					--Delete @ETLDatabase_Linked
					IF @DeleteETLDatabase_LinkedYN <> 0
						BEGIN
							SET @LinkedServer = LEFT(@ETLDatabase_Linked, CHARINDEX ('.', @ETLDatabase_Linked) - 1)
							SET @ETLDatabase_Linked = REPLACE(@ETLDatabase_Linked, @LinkedServer + '.', '')

							SET @SQLStatement = 'EXEC ' + @LinkedServer + '.sysDSPanel.dbo.sp_executesql N''TRUNCATE TABLE wrk_Count'''
							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						
							SET @SQLStatement = 'EXEC ' + @LinkedServer + '.master.dbo.sp_executesql N''INSERT INTO sysDSPanel..wrk_Count ([Count]) SELECT [Count] = COUNT(1) FROM sys.databases WHERE [name] = ''''' + @ETLDatabase_Linked + ''''''''
							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							TRUNCATE TABLE #Count
							SET @SQLStatement = 'INSERT INTO #Count ([Count]) SELECT [Count] FROM ' + @LinkedServer + '.sysDSPanel.dbo.wrk_Count'
							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF (SELECT [Count] FROM #Count) > 0
								BEGIN
									SET @SQLStatement = 'EXEC ' + @LinkedServer + '.msdb.dbo.sp_delete_database_backuphistory @database_name = N''' + @ETLDatabase_Linked + ''''
									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SET @SQLStatement = 'EXEC ' + @LinkedServer + '.master.dbo.sp_executesql N''ALTER DATABASE [' + @ETLDatabase_Linked + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE'''
									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SET @SQLStatement = 'EXEC ' + @LinkedServer + '.master.dbo.sp_executesql N''DROP DATABASE ' + @ETLDatabase_Linked + ''''
									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END
						END

					--Delete @CallistoDatabase (also delete from [CallistoAppDictionary].[dbo].[Applications])
						IF (SELECT COUNT(1) FROM sys.databases WHERE [name] = @CallistoDatabase) > 0
							BEGIN
								EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = @CallistoDatabase

								SET @SQLStatement = 'ALTER DATABASE [' + @CallistoDatabase + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE'
								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @SQLStatement = 'DROP DATABASE ' + @CallistoDatabase
								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
							END

						IF DB_ID('CallistoAppDictionary') IS NOT NULL
							DELETE [CallistoAppDictionary].[dbo].[Applications]
							WHERE
								[ApplicationLabel] = @CallistoDatabase

					--Delete @ETLDatabase
						IF (SELECT COUNT(1) FROM sys.databases WHERE [name] = @ETLDatabase) > 0
							BEGIN
								EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = @ETLDatabase

								SET @SQLStatement = 'ALTER DATABASE [' + @ETLDatabase + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE'
								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @SQLStatement = 'DROP DATABASE ' + @ETLDatabase
								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
							END

					IF @Debug <> 0 select   [@UserID] = @UserID,
											[@InstanceID] = @InstanceID,
											[@VersionID] = @VersionID, --If @VersionID IS NULL, Delete all VersionID for selected InstanceID
											[@SaveInstanceYN] = 0,
											[@Debug] = @Debug,
											[@JobID] = @JobID

					--Delete data in tables with known parameters
						EXEC [spCleanUp_TableRow]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID, --If @VersionID IS NULL, Delete all VersionID for selected InstanceID
							@SaveInstanceYN = 0,
							@Debug = @Debug,
							@Deleted = @Deleted OUT,
							@Inserted = @Inserted OUT,
							@Updated = @Updated OUT,
							@Selected = @Selected OUT,
							@JobID = @JobID

					FETCH NEXT FROM Master_Instance_Cursor INTO @CustomerID, @InstanceID, @VersionID, @ApplicationID, @ETLDatabase, @CallistoDatabase, @ETLDatabase_Linked
				END

		CLOSE Master_Instance_Cursor
		DEALLOCATE Master_Instance_Cursor	

	SET @Step = 'Delete Users in pcINTEGRATOR_Data that not exists in User_Instance'
		DELETE U
		FROM
			pcINTEGRATOR_Data.dbo.[User] U
			INNER JOIN wrk_DeleteList_Last DL ON DL.InstanceID = U.InstanceID AND DL.VersionID IS NULL
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data.dbo.[User_Instance] UI WHERE UI.UserID = U.UserID)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete selected Instance if they dont have any users used in other instances'
		DELETE I
		FROM
			pcINTEGRATOR_Data.dbo.[Instance] I
			INNER JOIN wrk_DeleteList_Last DL ON DL.InstanceID = I.InstanceID AND DL.VersionID IS NULL
		WHERE
			--I.InstanceID < -1000 AND
			@VersionID IS NULL AND
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data.dbo.[User] U WHERE U.InstanceID = I.InstanceID)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete all Customers without Instances'
		DELETE C
		FROM
			pcINTEGRATOR_Data.dbo.[Customer] C
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data.dbo.[Instance] I WHERE I.CustomerID = C.CustomerID)
		
		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Reset ID counters for main tables'
		--[Source]
		SELECT @MaxID = MAX(SourceID) FROM [pcINTEGRATOR_Data].[dbo].[Source]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Source], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''
		EXECUTE (@SQLStatement)

		--[Model]
		SELECT @MaxID = MAX(ModelID) FROM [pcINTEGRATOR_Data].[dbo].[Model]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Model], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''
		EXECUTE (@SQLStatement)

		--[Application]
		SELECT @MaxID = MAX(ApplicationID) FROM [pcINTEGRATOR_Data].[dbo].[Application]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Application], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''
		EXECUTE (@SQLStatement)

		--[Version]
		SELECT @MaxID = MAX(VersionID) FROM [pcINTEGRATOR_Data].[dbo].[Version]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Version], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''
		EXECUTE (@SQLStatement)

		--[Process]
		SELECT @MaxID = MAX(ProcessID) FROM [pcINTEGRATOR_Data].[dbo].[Process]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Process], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''
		EXECUTE (@SQLStatement)

		--[DataClass]
		SELECT @MaxID = MAX(DataClassID) FROM [pcINTEGRATOR_Data].[dbo].[DataClass]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([DataClass], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''
		EXECUTE (@SQLStatement)

		--[Measure]
		SELECT @MaxID = MAX(MeasureID) FROM [pcINTEGRATOR_Data].[dbo].[Measure]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Measure], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''
		EXECUTE (@SQLStatement)

		--[Dimension]
		SELECT @MaxID = MAX(DimensionID) FROM [pcINTEGRATOR_Data].[dbo].[Dimension]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Dimension], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''
		EXECUTE (@SQLStatement)

	SET @Step = 'Drop temp tables'
		DROP TABLE #Count
		DROP TABLE #OlapDB

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
