SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Update_Callisto]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	--SP-specific parameters
	@CallistoShrinkYN bit = 0,
	@CallistoDeployYN bit = 0,
	@InstanceExceptionList nvarchar(1000) = NULL,
	@InstanceIncludeList nvarchar(1000) = NULL,
	@SourceTypeID int = NULL,


	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000624,
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
EXEC [pcINTEGRATOR].[dbo].[sp_Tool_Update_Callisto] @InstanceIncludeList = '525', @CallistoDeployYN=1, @CallistoShrinkYN=1, @DebugBM = 3
EXEC [sp_Tool_Update_Callisto] @CallistoShrinkYN=1, @Debug = 1
EXEC [sp_Tool_Update_Callisto] @CallistoShrinkYN=1, @InstanceExceptionList = '114, 380, 413, 424, 454', @Debug = 1
EXEC [sp_Tool_Update_Callisto] @InstanceID = 515, @VersionID = 1040, @CallistoShrinkYN=1, @Debug = 1
EXEC [sp_Tool_Update_Callisto] @InstanceID = -1410, @VersionID = -1348, @CallistoShrinkYN=1, @Debug = 1
EXEC [sp_Tool_Update_Callisto] @InstanceID = -1410, @VersionID = -1348, @CallistoDeployYN=1, @Debug = 1
EXEC [sp_Tool_Update_Callisto] @InstanceID = -1410, @VersionID = -1348, @CallistoShrinkYN=1, @InstanceExceptionList = '114, 380, 413, 424, 454', @Debug = 1
EXEC [sp_Tool_Update_Callisto] @CallistoDeployYN=1,  @InstanceIncludeList = '-1220,-1365,-1393,-1399,-1358,-1380,-1387,-1353,-1368,-1371,-1335,-1444,-1110,-1463,-1418,-1361,-1355,-1431', @Debug = 1

EXEC [sp_Tool_Update_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@StorageTypeBM int,
	@ETL_DB_YN bit,
	@Callisto_DB_YN bit,
	@SQLStatement nvarchar(max),
	@RowCount int,
	@AssignedInstanceID int,
	@AssignedVersionID int,
	@Callisto_Generic_StartTime datetime,
	@JSON nvarchar(max),
	@ReturnVariable int,
	@DeletedID int,

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
	@Version nvarchar(50) = '2.1.1.2180'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Loop all pcETL and pcDATA databases and make updates/adjustments.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2159' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2160' SET @Description = 'Added @DebugSub on subroutines.'
		IF @Version = '2.1.0.2161' SET @Description = 'Add deploy of Callisto databases.'
		IF @Version = '2.1.0.2162' SET @Description = 'Rename pcETL..[Load] table to pcETL..[Load_*DATE*].'
		IF @Version = '2.1.0.2163' SET @Description = 'Added step to import default Dimensions and Properties to Callisto.'
		IF @Version = '2.1.1.2168' SET @Description = 'Added Dimension setup for Flow and LineItem. Disable and get DeletedID for Financials_Detail.'
		IF @Version = '2.1.1.2180' SET @Description = 'Added @SourceTypeID to input parameters, Added @SourceTypeID to exec [spIU_Dim_AccountCategory_Callisto]...'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
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

	SET @Step = 'Start Job'
		EXEC [pcINTEGRATOR].[dbo].[spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='Start',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobQueueYN=0,
			@JobID=@JobID OUT

		SELECT [@JobID] = @JobID

	SET @Step = 'Create temp table #Application_Cursor'
		CREATE TABLE #Application_Cursor
			(
			[AssignedInstanceID] int,
			[AssignedVersionID] int,
			[ETLDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[CallistoDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] int
			)

		SET @SQLStatement = '
			INSERT INTO #Application_Cursor
				(
				[AssignedInstanceID],
				[AssignedVersionID],
				[ETLDatabase],
				[CallistoDatabase],
				[StorageTypeBM]
				)
			SELECT 
				[AssignedInstanceID] = A.[InstanceID],
				[AssignedVersionID] = A.[VersionID],
				[ETLDatabase] = A.[ETLDatabase],
				[CallistoDatabase] = A.[DestinationDatabase],
				[StorageTypeBM] = A.[StorageTypeBM]
			FROM
				[pcINTEGRATOR_Data].[dbo].[Application] A
			WHERE
				' + CASE WHEN @InstanceExceptionList IS NULL THEN '' ELSE 'A.[InstanceID] NOT IN (' + @InstanceExceptionList + ') AND' END + '
				' + CASE WHEN @InstanceIncludeList IS NULL THEN '' ELSE 'A.[InstanceID] IN (' + @InstanceIncludeList + ') AND' END + '
				(A.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' OR  ' + CONVERT(nvarchar(15), @InstanceID) + ' = 0) AND
				(A.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' OR ' + CONVERT(nvarchar(15), @VersionID) + ' = 0)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Application_Cursor',  * FROM #Application_Cursor ORDER BY [AssignedInstanceID], [AssignedVersionID]

	SET @Step = 'Application_Cursor'
		IF CURSOR_STATUS('global','Application_Cursor') >= -1 DEALLOCATE Application_Cursor
		DECLARE Application_Cursor CURSOR FOR
			
			SELECT 
				[AssignedInstanceID],
				[AssignedVersionID],
				[ETLDatabase],
				[CallistoDatabase],
				[StorageTypeBM]
			FROM
				 #Application_Cursor
			ORDER BY
				 [AssignedInstanceID],
				 [AssignedVersionID]

			OPEN Application_Cursor
			FETCH NEXT FROM Application_Cursor INTO @AssignedInstanceID, @AssignedVersionID, @ETLDatabase, @CallistoDatabase, @StorageTypeBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@AssignedInstanceID] = @AssignedInstanceID, [@AssignedVersionID] = @AssignedVersionID, [@ETLDatabase] = @ETLDatabase, [@CallistoDatabase] = @CallistoDatabase, [@StorageTypeBM] = @StorageTypeBM

					--pcETL
					SELECT @ETL_DB_YN = CASE WHEN db_id(@ETLDatabase) IS NULL THEN 0 ELSE 1 END
					IF @ETL_DB_YN <> 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@ETLDatabase] = @ETLDatabase
							EXEC [pcINTEGRATOR].[dbo].[spSet_JournalTable] @UserID=@UserID, @InstanceID=@AssignedInstanceID, @VersionID=@AssignedVersionID, @StorageTypeBM = 2, @JobID=@JobID, @Debug = @DebugSub

							EXEC [pcINTEGRATOR].[dbo].[spSetup_Job] @UserID=@UserID, @InstanceID=@AssignedInstanceID, @VersionID=@AssignedVersionID, @StorageTypeBM = @StorageTypeBM, @SourceTypeID = 11, @JobID=@JobID, @Debug = @DebugSub

							--Rename pcETL_*..[Load] should be renamed to pcETL_*..[Load_20201009]
							SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM ' + @ETLDatabase + '.sys.tables WHERE name = ''Load'''
							EXEC sp_executesql @SQLStatement, N'@InternalVariable nvarchar(100) OUT', @InternalVariable = @ReturnVariable OUT
							SELECT [@ReturnVariable] = @ReturnVariable

							IF (@ReturnVariable) = 1
								BEGIN
									SET @SQLStatement = 'sp_rename ''''' + @ETLDatabase + '.dbo.[Load]'''', ''''Load_' + CONVERT(NVARCHAR(15), GETDATE(), 112) + ''''''
									SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END							
						END

					--pcDATA (Callisto)
					SELECT @Callisto_DB_YN = CASE WHEN db_id(@CallistoDatabase) IS NULL THEN 0 ELSE 1 END
					IF @Callisto_DB_YN <> 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase

							--Insert into Callisto Applications table
							INSERT INTO [CallistoAppDictionary].[dbo].[Applications]
								(
								[ApplicationLabel],
								[SqlDbName],
								[SqlDbServer],
								[OlapDbName],
								[OlapDbServer],
								[ApplicationType],
								[EnableAppLogon],
								[ReportServer],
								[MDXQueryTimeout],
								[WebSvcTraceLevel],
								[SvcWaitTime],
								[SvcTraceLevel],
								[SvcServerId],
								[ReportServerTraceLevel],
								[Offline]
								)
							SELECT
								[ApplicationLabel] = @CallistoDatabase,
								[SqlDbName] = @CallistoDatabase,
								[SqlDbServer] = 'localhost',
								[OlapDbName] = @CallistoDatabase,
								[OlapDbServer] = 'localhost',
								[ApplicationType] = NULL,
								[EnableAppLogon] = 2,
								[ReportServer] = 'localhost:43000',
								[MDXQueryTimeout] = 30,
								[WebSvcTraceLevel] = 0,
								[SvcWaitTime] = 30,
								[SvcTraceLevel] = 1,
								[SvcServerId] = 'localhost',
								[ReportServerTraceLevel] = 0,
								[Offline] = 0
							WHERE
								NOT EXISTS (SELECT 1 FROM [CallistoAppDictionary].[dbo].[Applications] A WHERE A.[ApplicationLabel] = @CallistoDatabase)
								
							--Disable Financials_Detail
							EXEC [pcINTEGRATOR].[dbo].[spGet_DeletedItem]	@UserID=@UserID, @InstanceID=@AssignedInstanceID, @VersionID=@AssignedVersionID, @TableName='DataClass', @DeletedID=@DeletedID OUT, @JobID=@JobID

							UPDATE D
							SET 
								SelectYN = 0,
								DeletedID = @DeletedID
							FROM 
								[pcINTEGRATOR_Data].[dbo].[DataClass] D
							WHERE 
								D.InstanceID = @AssignedInstanceID AND
								D.VersionID = @AssignedVersionID AND 
								D.DataClassName = 'Financials_Detail'

							--Adding default Dimensions and Properties to Callisto:
							EXEC [pcINTEGRATOR].[dbo].[spSetup_Dimension] @UserID=-10, @InstanceID=@AssignedInstanceID, @VersionID=@AssignedVersionID, @SourceTypeID = -10, @Debug=0
							EXEC [pcINTEGRATOR].[dbo].[spSetup_Callisto] @UserID = @UserID, @InstanceID = @AssignedInstanceID, @VersionID = @AssignedVersionID, @SequenceBM = 19, @DebugBM = @DebugSub
							
							--Update dimension tables
							EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_Dimension_Generic_Callisto] @UserID = @UserID, @InstanceID = @AssignedInstanceID, @VersionID = @AssignedVersionID, @DimensionID = -62, @JobID=@JobID, @DebugBM = @DebugSub
							EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_AccountCategory_Callisto] @UserID = @UserID, @InstanceID = @AssignedInstanceID, @VersionID = @AssignedVersionID, @SourceTypeID = @SourceTypeID, @JobID=@JobID, @DebugBM = @DebugSub
							EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_Dimension_Generic_Callisto] @UserID = @UserID, @InstanceID = @AssignedInstanceID, @VersionID = @AssignedVersionID, @DimensionID = -34, @JobID=@JobID, @DebugBM = @DebugSub
							
							SET @SQLStatement = '
								SELECT @InternalVariable = COUNT(1) FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Account] A WHERE A.[AccountType_MemberId] IS NOT NULL'

							EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @RowCount OUT

							IF @DebugBM & 2 > 0 SELECT [@RowCount] = @RowCount

							IF @RowCount = 0
								BEGIN
									SET @SQLStatement = '
										UPDATE A
										SET
											AccountType = [AT].[Label],
											AccountType_MemberID = [AT].MemberID
										FROM
											[' + @CallistoDatabase + '].[dbo].[S_DS_Account] A
											INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_AccountType] [AT] ON [AT].[Label] = A.[Account Type]

										UPDATE A
										SET
											AccountType = [AT].[Label],
											AccountType_MemberID = [AT].MemberID
										FROM
											[' + @CallistoDatabase + '].[dbo].[O_DS_Account] A
											INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_AccountType] [AT] ON [AT].[Label] = A.[Account Type]'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

							--TODO: Copy all rows from FACT_Financials_Detail to FACT_Financials

							--Shrink Callisto database
							IF @CallistoShrinkYN <> 0
								BEGIN
									SET @SQLStatement = '
									DBCC SHRINKDATABASE (' + @CallistoDatabase  + ')'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

							--Deploy Callisto database
							IF @CallistoDeployYN <> 0
								BEGIN
									SET @JSON = '
											[
											{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
											{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @AssignedInstanceID) + '"},
											{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @AssignedVersionID) + '"},
											{"TKey" : "StepName",  "TValue": "Deploy"},
											{"TKey" : "AsynchronousYN",  "TValue": "1"},
											{"TKey" : "MasterCommand",  "TValue": "' + @ProcedureName + '"},
											{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
											{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}
											]'

									EXEC [pcINTEGRATOR].[dbo].[spRun_Procedure_KeyValuePair]
										@ProcedureName = 'spRun_Job_Callisto_Generic',
										@JSON = @JSON

								END

							SkipCallistoUpdate:
						END

					FETCH NEXT FROM Application_Cursor INTO @AssignedInstanceID, @AssignedVersionID, @ETLDatabase, @CallistoDatabase, @StorageTypeBM
				END


		CLOSE Application_Cursor
		DEALLOCATE Application_Cursor

	SET @Step = 'Set EndTime for the actual job'
		EXEC [pcINTEGRATOR].[dbo].[spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID

	SET @Step = 'Drop temp tables'
		DROP TABLE #Application_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	EXEC [pcINTEGRATOR].[dbo].[spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
