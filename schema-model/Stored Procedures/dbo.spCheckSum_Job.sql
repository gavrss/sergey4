SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_Job]
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

	@HourBack int = -10, --How many hours back should look into error logs

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000376,
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
DECLARE @CheckSumValue int, @CheckSumStatus10 int, @CheckSumStatus20 int, @CheckSumStatus30 int, @CheckSumStatus40 int
EXEC [spCheckSum_Job] @UserID=-10, @InstanceID=476, @VersionID=1029, @Debug=0,
@CheckSumValue=@CheckSumValue OUT, @CheckSumStatus10=@CheckSumStatus10 OUT, @CheckSumStatus20 =@CheckSumStatus20 OUT,
@CheckSumStatus30=@CheckSumStatus30 OUT, @CheckSumStatus40=@CheckSumStatus40 OUT
SELECT [@CheckSumValue] = @CheckSumValue, [@CheckSumStatus10] = @CheckSumStatus10, [@CheckSumStatus20] = @CheckSumStatus20, 
[@CheckSumStatus30] = @CheckSumStatus30, [@CheckSumStatus40] = @CheckSumStatus40

DECLARE @CheckSumValue int
EXEC [spCheckSum_Job] @UserID=-10, @InstanceID=476, @VersionID=1029, @JobID=10406, @CheckSumValue = @CheckSumValue OUT, @Debug=1
SELECT CheckSumValue = @CheckSumValue

EXEC [spCheckSum_Job] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM = 2, @Debug=1
EXEC [spCheckSum_Job] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumStatusBM=8, @Debug=1

EXEC [spCheckSum_Job] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CalledYN bit = 1,
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@JobName nvarchar(100),

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
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get CheckSum for specified Job (default last ERP load).',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-106: Implemented CheckSumRowLogID.'
		IF @Version = '2.0.3.2154' SET @Description = 'Removed references to ETL database and SQL Server Agent.'
		IF @Version = '2.1.1.2171' SET @Description = 'If @JobID IS NULL, set @JobID of last Inserted in [CheckSumLog]. Exclude CheckSumStatusID IN (30,40) in CheckSumValue count. Exclude #JobLog.[ErrorNumber] < 0.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added parameters @CheckSumStatus10, @CheckSumStatus20, @CheckSumStatus30, @CheckSumStatus40, @CheckSumStatusBM.'
		IF @Version = '2.1.1.2173' SET @Description = 'Removed filters for @Step = Insert into JobLog.'
		IF @Version = '2.1.1.2174' SET @Description = 'Added [CheckSumStatusBM] in @ResultTypeBM = 4.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			--@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		--SELECT
		--	@JobID = ISNULL(@JobID, MAX(J.[JobID]))
		--FROM
		--	[pcINTEGRATOR_Log].[dbo].[Job] J
		--	INNER JOIN pcINTEGRATOR_Data.dbo.JobList JL ON JL.JobListID = J.JobListID AND JL.JobStepGroupBM & 1 > 0
		--WHERE
		--	J.InstanceID = @InstanceID AND
		--	J.VersionID = @VersionID AND
		--	J.EndTime IS NOT NULL

		IF @JobID IS NULL 
			BEGIN 
				SELECT TOP(1)
					@JobID = ISNULL(@JobID, CSL.[JobID])
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumLog] CSL
				WHERE
					CSL.InstanceID = @InstanceID AND
					CSL.VersionID = @VersionID
				ORDER BY
					CSL.Inserted DESC

				IF @Debug <> 0 SELECT [@JobID] = @JobID
			END

		SELECT
			@ETLDatabase = [ETLDatabase],
			@JobName = [DestinationDatabase] + '_Load'
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @Debug <> 0 SELECT [@ETLDatabase] = @ETLDatabase, [@JobName] = @JobName, [@JobID] = @JobID

	SET @Step = 'Create temp table #JobLog'
		CREATE TABLE #JobLog
			(
			[Table] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[JobID] bigint,
			[JobLogID] bigint,
			[StartTime] datetime,
			[ProcedureName] nvarchar(100),
			[ErrorNumber] int,
			[ErrorMessage] nvarchar(4000),
			[Inserted] datetime,
			[CheckSumRowLogID] bigint
			)

	--SET @Step = 'Insert data into temp table #JobLog from ETL database'
	--	SET @SQLStatement = '
	--		INSERT INTO #JobLog
	--			(
	--			[Table],
	--			[JobID],
	--			[JobLogID],
	--			[StartTime],
	--			[ProcedureName],
	--			[ErrorNumber],
	--			[ErrorMessage],
	--			[Inserted],
	--			[CheckSumRowLogID]
	--			)
	--		SELECT
	--			[Table] = ''[' + @ETLDatabase + '].[dbo].[JobLog]'',
	--			[JobID],
	--			[JobLogID],
	--			[StartTime],
	--			[ProcedureName],
	--			[ErrorNumber],
	--			[ErrorMessage],
	--			[Inserted] = GetDate(),
	--			[CheckSumRowLogID] = NULL
	--		FROM
	--			' +  @ETLDatabase + '.[dbo].[JobLog]
	--		WHERE
	--			([JobID] = ' + CONVERT(nvarchar(20), @JobID) + ' OR [StartTime] > DATEADD(hh, ' + CONVERT(nvarchar(15), @HourBack) + ', GetDate())) AND
	--			ErrorNumber <> 0'

	--	IF @Debug <> 0 PRINT @SQLStatement
	--	EXEC (@SQLStatement)

	SET @Step = 'Insert data into temp table #JobLog from pcINTEGRATOR_Log'
		INSERT INTO #JobLog
			(
			[Table],
			[JobID],
			[JobLogID],
			[StartTime],
			[ProcedureName],
			[ErrorNumber],
			[ErrorMessage],
			[Inserted],
			[CheckSumRowLogID]
			)
		SELECT
			[Table] = '[pcINTEGRATOR_Log].[dbo].[JobLog]',
			[JobID] = JL.[JobID],
			[JobLogID] = JL.[JobLogID],
			[StartTime] = JL.[StartTime],
			[ProcedureName] = JL.[ProcedureName],
			[ErrorNumber] = JL.[ErrorNumber],
			[ErrorMessage] = JL.[ErrorMessage],
			[Inserted] = GetDate(),
			[CheckSumRowLogID] = NULL
		FROM
			[pcINTEGRATOR_Log].[dbo].[JobLog] JL
		WHERE
			JL.[InstanceID] = @InstanceID AND
			JL.[VersionID] = @VersionID AND
			[JobID] = @JobID AND --OR [StartTime] > DATEADD(hh, @HourBack, GetDate())) AND
			[ErrorNumber] > 0
		OPTION (MAXDOP 1)

	--SET @Step = 'Insert data into temp table #JobLog from SQL Server Agent'
	--	INSERT INTO #JobLog
	--		(
	--		[Table],
	--		[JobID],
	--		[JobLogID],
	--		[StartTime],
	--		[ProcedureName],
	--		[ErrorNumber],
	--		[ErrorMessage],
	--		[Inserted],
	--		[CheckSumRowLogID]
	--		)
	--	SELECT
	--		[Table] = 'SQL Server Agent',
	--		[JobID] = 0,
	--		[JobLogID] = 0,
	--		[StartTime] = CONVERT(datetime, sub.[StartDate] + ' ' + LEFT(sub.[StartTime], 2) + ':' + SUBSTRING(sub.[StartTime], 3, 2) + ':' + RIGHT(sub.[StartTime], 2), 112),
	--		[ProcedureName] = 'Job = ' + sub.[JobName] + ', Step = ' + sub.[StepName],
	--		[ErrorNumber] = sub.[ErrorNumber],
	--		[ErrorMessage] = sub.[ErrorMessage],
	--		[Inserted] = GetDate(),
	--		[CheckSumRowLogID] = NULL
	--	FROM
	--		(
	--		SELECT
	--			[JobName] = J.[name],
	--			[StepName] = H.[step_name],
	--			--[StartDate] = CONVERT(datetime, CONVERT(nvarchar(10), run_date), 112),
	--			[StartDate] = CONVERT(nvarchar(10), H.[run_date]),
	--			[StartTime] = CASE LEN(run_time) WHEN 0 THEN '000000'  WHEN 1 THEN '00000' WHEN 2 THEN '0000' WHEN 3 THEN '000' WHEN 4 THEN '00' WHEN 5 THEN '0' ELSE '' END + CONVERT(nvarchar(6), run_time),
	--			[ErrorNumber] = 1,
	--			[ErrorMessage] = H.[message]
	--		FROM
	--			msdb..sysjobhistory H 
	--			INNER JOIN  msdb..sysjobs J ON J.job_id = H.job_id AND J.[name] = @JobName
	--		WHERE
	--			H.step_id <> 0 AND
	--			H.run_status = 0
	--		) sub
	--	WHERE
	--		CONVERT(datetime, sub.[StartDate] + ' ' + LEFT(sub.[StartTime], 2) + ':' + SUBSTRING(sub.[StartTime], 3, 2) + ':' + RIGHT(sub.[StartTime], 2), 112) > DATEADD(hh, @HourBack, GetDate())

	SET @Step = 'Set CheckSumRowLogID'
		INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
			(
			[CheckSumRowKey],
			[InstanceID],
			[VersionID],
			[ProcedureID]
			)
		SELECT
			[CheckSumRowKey] = JL.[Table] + '_' + JL.[ProcedureName] + '_' + CONVERT(nvarchar(15), JL.[ErrorNumber]),
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[ProcedureID] = @ProcedureID
		FROM
			[#JobLog] JL
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = JL.[Table] + '_' + JL.[ProcedureName] + '_' + CONVERT(nvarchar(15), JL.[ErrorNumber]) AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = @InstanceID AND CSRL.[VersionID] = @VersionID AND CSRL.[CheckSumStatusBM] & 8 = 0)
		OPTION (MAXDOP 1)

		UPDATE JL
		SET
			CheckSumRowLogID = CSRL.CheckSumRowLogID
		FROM
			[#JobLog] JL
			INNER JOIN [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL ON CSRL.[CheckSumRowKey] = JL.[Table] + '_' + JL.[ProcedureName] + '_' + CONVERT(nvarchar(15), JL.[ErrorNumber]) AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = @InstanceID AND CSRL.[VersionID] = @VersionID
		OPTION (MAXDOP 1)

		UPDATE CSRL
		SET
			--[Solved] = GetDate(),
			--[CheckSumStatusID] = 40
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
			NOT EXISTS (SELECT 1 FROM [#JobLog] JL WHERE JL.[CheckSumRowLogID] = CSRL.[CheckSumRowLogID])
		OPTION (MAXDOP 1)

		SET @Updated = @Updated + @@ROWCOUNT

	IF @Debug <> 0 SELECT [TempTable] = '#JobLog', * FROM #JobLog

	SET @Step = 'Get CheckSumValue'
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
					LEFT JOIN #JobLog wrk ON wrk.CheckSumRowLogID = CSRL.CheckSumRowLogID
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND 
                    CSRL.[ProcedureID] = @ProcedureID
				OPTION (MAXDOP 1)

				IF @Debug <> 0 
					SELECT 
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
					[Table] = JL.[Table],
					[JobID] = JL.[JobID],
					[JobLogID] = JL.[JobLogID],
					[StartTime] = JL.[StartTime],
					[ProcedureName] = JL.[ProcedureName],
					[ErrorNumber] = JL.[ErrorNumber],
					[ErrorMessage] = JL.[ErrorMessage],
					[LastCheck] = JL.[Inserted],
					[AuthenticatedUserID] = CSRL.UserID,
					[AuthenticatedUserName] = U.UserNameDisplay,
					[AuthenticatedUserOrganization] = I.InstanceName,
					[Updated] = CSRL.[Updated]
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
					LEFT JOIN [#JobLog] JL ON JL.CheckSumRowLogID = CSRL.CheckSumRowLogID
					INNER JOIN CheckSumStatus CSS ON CSS.CheckSumStatusBM = CSRL.CheckSumStatusBM
					LEFT JOIN [pcINTEGRATOR].[dbo].[User] U ON U.UserID = CSRL.UserID
					LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID 
				WHERE
					CSRL.InstanceID = @InstanceID AND
					CSRL.VersionID = @VersionID AND   
                    CSRL.ProcedureID = @ProcedureID AND 
					CSRL.CheckSumStatusBM & @CheckSumStatusBM > 0
				OPTION (MAXDOP 1)
				
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Drop Temp table'
		DROP TABLE #JobLog

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
