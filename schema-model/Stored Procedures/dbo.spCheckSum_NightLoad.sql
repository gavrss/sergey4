SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_NightLoad] 
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 1, --1=generate new CheckSumStatus count, 2=get CheckSumStatus count, 4=Details (of @CheckSumStatusBM) 
	@CheckSumValue int = NULL OUT,
	@CheckSumStatus10 int = NULL OUT,
	@CheckSumStatus20 int = NULL OUT,
	@CheckSumStatus30 int = NULL OUT,
	@CheckSumStatus40 int = NULL OUT,
	@CheckSumStatusBM int = 7, -- 1=Open, 2=Investigating, 4=Ignored, 8=Solved

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000825,
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

DECLARE @CheckSumValue int,@CheckSumStatus10 int,@CheckSumStatus20 int,@CheckSumStatus30 int,@CheckSumStatus40 int
EXEC [spCheckSum_NightLoad] @Debug=1, @UserID = -10, @InstanceID = 478, @VersionID = 1030, @CheckSumValue = @CheckSumValue OUT, @CheckSumStatus10 = @CheckSumStatus10 OUT, @CheckSumStatus20 = @CheckSumStatus20 OUT, @CheckSumStatus30 = @CheckSumStatus30 OUT, @CheckSumStatus40 = @CheckSumStatus40 OUT--, @JobID = 34814
SELECT [@CheckSumValue] = @CheckSumValue,[@CheckSumStatus10] = @CheckSumStatus10,[@CheckSumStatus20] = @CheckSumStatus20,[@CheckSumStatus30] = @CheckSumStatus30,[@CheckSumStatus40] = @CheckSumStatus40 

EXEC [spCheckSum_NightLoad] @UserID = -10, @InstanceID = 531, @VersionID = 1057, 
@ResultTypeBM = 1, @CheckSumStatusBM = 7, @DebugBM=3
EXEC [spCheckSum_NightLoad] @UserID = -10, @InstanceID = 513, @VersionID = 1046, 
@ResultTypeBM = 1, @CheckSumStatusBM = 7, @DebugBM=3


EXEC [spCheckSum_NightLoad] @UserID = -10, @InstanceID = 478, @VersionID = 1030, 
@ResultTypeBM = 4, @CheckSumStatusBM = 15, @DebugBM=3

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spCheckSum_NightLoad',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spCheckSum_NightLoad] @GetVersion = 1
*/

SET ANSI_WARNINGS ON


DECLARE
	--SP-specific variables
	@SQLStatement NVARCHAR(MAX),
	@CallistoDatabase NVARCHAR(100),
	@ETLDatabase NVARCHAR(100),
	@SourceDatabase NVARCHAR(255),
	@ReturnVariable INT,
	--@EntityID INT,
	--@Entity NVARCHAR(50),
	--@Book NVARCHAR(50),
	--@BalanceType NVARCHAR(10),
	--@StartFiscalYear INT,
	--@FiscalPeriodDimExistsYN BIT = 0,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'NeHa',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.1.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Checks successful night loads in the last 48 hrs.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2179' SET @Description = 'Procedure created.'

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
			@ETLDatabase = ETLDatabase,
			@CallistoDatabase = DestinationDatabase
		FROM
			[pcINTEGRATOR].[dbo].[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @DebugBM & 2 > 0 
			SELECT 
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@ResultTypeBM] = @ResultTypeBM,
				[@CheckSumStatusBM] = @CheckSumStatusBM,
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'Create and insert data into temp table #NightLoadJobLog'
		CREATE TABLE #NightLoadJobLog
			(
			[InstanceID] INT,
			[VersionID] INT,
			[JobID] INT,
			[StartTime] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[ErrorNumber] INT,
			)

		INSERT INTO #NightLoadJobLog 
			(
			[InstanceID],
			[VersionID],
			[JobID],
			[StartTime],
			[ErrorNumber]
			)
		SELECT 
			[InstanceID] = J.InstanceID,
			[VersionID] = J.VersionID,
			[JobID] = J.JobID,
			[StartTime] = J.StartTime,
			[ErrorNumber] = J.ErrorNumber 
			--,[NoOfDeployJob] = COUNT(1)	
		--INTO 
		--	#NightLoadJobLog
		FROM 
			[pcINTEGRATOR_Log].[dbo].[JobLog] J		
		WHERE 
			J.InstanceID = @InstanceID AND
			J.VersionID = @VersionID AND
			J.ProcedureName = 'spPortalAdmin_LoadCallisto' AND 
			J.Parameter LIKE '%@CallistoDeployYN=''1''%' AND 
			J.StartTime > DATEADD(HOUR, -48, GETDATE()) AND 
			J.ErrorNumber IN(0, -1)		
		--GROUP BY 
		--	J.InstanceID, J.VersionID, J.JobID, J.ErrorNumber				
		ORDER BY 
			J.JobID DESC 
		OPTION (MAXDOP 1)

		IF @DebugBM & 2 > 0	SELECT [TempTable] = '#NightLoadJobLog', * FROM #NightLoadJobLog ORDER BY JobID DESC 
	
	SET @Step = 'Create and insert data into temp table #NightLoadJobStatus'
		CREATE TABLE #NightLoadJobStatus 
			(
			[InstanceID] INT,
			[VersionID] INT,
			[ErrorNumber] INT,
			[NoOfDeployJob] INT,
			[Test1] INT,
			[Test2] INT,
			[CheckSum] INT
			)

		INSERT INTO #NightLoadJobStatus 
			(
			[InstanceID],
			[VersionID],
			[ErrorNumber],
			[NoOfDeployJob]
			)
		SELECT 
			[InstanceID] = J.InstanceID,
			[VersionID] = J.VersionID,
			[ErrorNumber] = J.ErrorNumber,
			[NoOfDeployJob] = COUNT(1)
		FROM 
			#NightLoadJobLog J
		WHERE 
			J.InstanceID = @InstanceID AND
			J.VersionID = @VersionID	
		GROUP BY 
			J.InstanceID, J.VersionID, J.ErrorNumber				
		ORDER BY 
			J.InstanceID, J.VersionID, J.ErrorNumber 			

		IF @DebugBM & 2 > 0	SELECT [TempTable] = '#NightLoadJobStatus', * FROM #NightLoadJobStatus ORDER BY InstanceID, VersionID, ErrorNumber

	SET @Step = 'Create and insert data into temp table #CheckSumRowLog'
		CREATE TABLE #CheckSumRowLog
			(
			[InstanceID] INT,
			[VersionID] INT,
			[ProcedureID] INT,
			[CheckSumRowKey] NVARCHAR(255) COLLATE DATABASE_DEFAULT
			)

		--More than 1 Unsuccessful Night Loads
		INSERT INTO #CheckSumRowLog
			(
			[InstanceID],
			[VersionID],
			[ProcedureID],
			[CheckSumRowKey]
			)
		SELECT
			[InstanceID] = S.InstanceID,
			[VersionID] = S.VersionID,
			[ProcedureID] = @ProcedureID,
			[CheckSumRowKey] = 'NIGHTLOAD_UNSUCCESSFUL_StartTime_' + L.StartTime
		FROM
			#NightLoadJobStatus S
			INNER JOIN #NightLoadJobLog L ON L.InstanceID = S.InstanceID AND L.VersionID = S.VersionID AND L.ErrorNumber = S.ErrorNumber
		WHERE
			S.ErrorNumber = -1 AND
            S.NoOfDeployJob > 1 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = 'NIGHTLOAD_UNSUCCESSFUL_StartTime_' + L.StartTime AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = @InstanceID AND CSRL.[VersionID] = @VersionID AND CSRL.[CheckSumStatusBM] & 12 = 0)
				
		--Night Load NOT EXECUTING
		INSERT INTO #CheckSumRowLog
			(
			[InstanceID],
			[VersionID],
			[ProcedureID],
			[CheckSumRowKey]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[ProcedureID] = @ProcedureID,
			[CheckSumRowKey] = 'NIGHTLOAD_NOT_EXECUTING'
		WHERE
		NOT EXISTS (SELECT 1 FROM #NightLoadJobStatus WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID) AND
        NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = 'NIGHTLOAD_NOT_EXECUTING' AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = @InstanceID AND CSRL.[VersionID] = @VersionID AND CSRL.[CheckSumStatusBM] & 12 = 0)	

		IF @DebugBM & 2 > 0	SELECT [TempTable] = '#CheckSumRowLog', * FROM #CheckSumRowLog
	
	SET @Step = 'Set CheckSumRowLogID'
		IF @ResultTypeBM & 1 > 0
			BEGIN 
				INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
					(
					[InstanceID],
					[VersionID],
					[ProcedureID],
					[CheckSumRowKey]
					)
				SELECT
					[InstanceID],
					[VersionID],
					[ProcedureID],
					[CheckSumRowKey]
				FROM
					#CheckSumRowLog
					
				SET @Inserted = @Inserted + @@ROWCOUNT

				----More than 1 Unsuccessful Night Loads
				--INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
				--	(
				--	[InstanceID],
				--	[VersionID],
				--	[ProcedureID],
				--	[CheckSumRowKey]
				--	)
				--SELECT
				--	[InstanceID] = S.InstanceID,
				--	[VersionID] = S.VersionID,
				--	[ProcedureID] = @ProcedureID,
				--	[CheckSumRowKey] = 'NIGHTLOAD_UNSUCCESSFUL_StartTime_' + L.StartTime
				--FROM
				--	#NightLoadJobStatus S
				--	INNER JOIN #NightLoadJobLog L ON L.InstanceID = S.InstanceID AND L.VersionID = S.VersionID AND L.ErrorNumber = S.ErrorNumber
				--WHERE
				--	S.ErrorNumber = -1 AND
    --                S.NoOfDeployJob > 1 AND
				--	NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = 'NIGHTLOAD_UNSUCCESSFUL_StartTime_' + L.StartTime AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = @InstanceID AND CSRL.[VersionID] = @VersionID AND CSRL.[CheckSumStatusBM] & 12 = 0)
										
				--SET @Inserted = @Inserted + @@ROWCOUNT

				----Night Load NOT EXECUTING
				--INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
				--	(
				--	[InstanceID],
				--	[VersionID],
				--	[ProcedureID],
				--	[CheckSumRowKey]
				--	)
				--SELECT
				--	[InstanceID] = @InstanceID,
				--	[VersionID] = @VersionID,
				--	[ProcedureID] = @ProcedureID,
				--	[CheckSumRowKey] = 'NIGHTLOAD_NOT_EXECUTING'
				--WHERE
				--NOT EXISTS (SELECT 1 FROM #NightLoadJobStatus WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID) AND
    --            NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = 'NIGHTLOAD_NOT_EXECUTING' AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = @InstanceID AND CSRL.[VersionID] = @VersionID AND CSRL.[CheckSumStatusBM] & 12 = 0)
					
				--SET @Inserted = @Inserted + @@ROWCOUNT

				UPDATE CSRL
				SET
				--	--[Solved] = GetDate(),
				--	--[CheckSumStatusID] = 40,
				--SELECT
				--	CSRL.CheckSumRowKey,
					[CheckSumStatusBM] = 8,
					[UserID] = @UserID,
					[Comment] = 'Resolved automatically.',
					[Updated] = GetDate()
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND
					CSRL.[ProcedureID] = @ProcedureID AND
					--CSRL.[Solved] IS NULL AND
					--CSRL.[CheckSumStatusID] <> 40 AND
					CSRL.[CheckSumStatusBM] & 8 = 0 AND
					CSRL.[CheckSumRowKey] LIKE '%NIGHTLOAD_%' AND
					NOT EXISTS (SELECT 1 FROM #CheckSumRowLog C WHERE C.[InstanceID] = CSRL.[InstanceID] AND C.[VersionID] = CSRL.[VersionID] AND C.[ProcedureID] = CSRL.[ProcedureID] AND C.CheckSumRowKey = CSRL.[CheckSumRowKey])
				OPTION (MAXDOP 1)

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Calculate @CheckSumValue'
		IF @ResultTypeBM & 3 > 0
			BEGIN
				SELECT
					@CheckSumValue = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 3 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus10 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 1 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus20 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 2 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus30 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 4 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus40 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 8 > 0 THEN 1 ELSE 0 END), 0)
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND
					CSRL.[ProcedureID] = @ProcedureID AND
                    CSRL.[CheckSumRowKey] LIKE 'NIGHTLOAD_%'
				OPTION (MAXDOP 1)

				IF @Debug <> 0 
					SELECT 
						[CheckSumRowKey] = 'NIGHTLOAD_%',
						[@CheckSumValue] = @CheckSumValue, 
						[@CheckSumStatus10] = @CheckSumStatus10, 
						[@CheckSumStatus20] = @CheckSumStatus20,
						[@CheckSumStatus30] = @CheckSumStatus30,
						[@CheckSumStatus40] = @CheckSumStatus40						
			END	

	SET @Step = 'Get detailed info'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					[CheckSumRowLogID] = CSRL.[CheckSumRowLogID],
					[FirstOccurrence] = CSRL.[Inserted],
					[CheckSumStatusBM] = CSS.[CheckSumStatusBM],
					[CurrentStatus] = CSS.[CheckSumStatusName],
					[Comment] = CSRL.[Comment],
					[Description] = CSRL.CheckSumRowKey,
					[AuthenticatedUserID] = CSRL.UserID,
					[AuthenticatedUserName] = U.UserNameDisplay,
					[AuthenticatedUserOrganization] = I.InstanceName,
					[Updated] = CSRL.[Updated]
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL 
					--LEFT JOIN #TrialBalance_CheckSum_ByFiscalPeriod TB ON TB.InstanceID = CSRL.[InstanceID] AND TB.VersionID = CSRL.[VersionID] AND CSRL.[CheckSumRowKey] = TB.[Entity] + '_' + TB.[Book] + '_' + CONVERT(NVARCHAR(15), TB.[FiscalYear]) + '_' + CONVERT(NVARCHAR(15), TB.[FiscalPeriod]) + '_' + TB.[Account] + '_GLJrnDtl_Diff_' +  CONVERT(NVARCHAR(20), ROUND(TB.[FACT_Financials_View] - TB.[Journal], 2))
					INNER JOIN [pcINTEGRATOR].[dbo].CheckSumStatus CSS ON CSS.CheckSumStatusBM = CSRL.CheckSumStatusBM
					LEFT JOIN [pcINTEGRATOR].[dbo].[User] U ON U.UserID = CSRL.UserID
					LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID 
				WHERE
					CSRL.InstanceID = @InstanceID AND
					CSRL.VersionID = @VersionID AND   
					CSRL.ProcedureID = @ProcedureID AND 
					CSRL.CheckSumStatusBM & @CheckSumStatusBM > 0 AND
					CSRL.CheckSumRowKey LIKE '%NIGHTLOAD_%'
				ORDER BY
					CSRL.[Inserted] DESC
				OPTION (MAXDOP 1)
		
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #NightLoadJobLog
		DROP TABLE #NightLoadJobStatus

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
