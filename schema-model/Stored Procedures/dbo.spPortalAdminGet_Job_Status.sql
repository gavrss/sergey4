SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Job_Status]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 23, --1=Parameter List, 2=Parameter members, 4=Current JobStatus, 8=Historic JobLog, 16=Job details, 32=All jobs executing or in queue for all instances, 64=Open errors, 128=Cleared errors
	@AssignedJobID int = NULL, --Valid for @ResultTypeBM IN (8, 16)
	@AssignedJobListID int = NULL, --Valid for @ResultTypeBM IN (8)
	@AssignedUserID int = NULL, --Valid for @ResultTypeBM IN (8)
	@AssignedProcedureID int = NULL, --Valid for @ResultTypeBM IN (16)
	@SubRoutinesYN bit = 0, --Valid for @ResultTypeBM IN (16)
	@OnlyErrorYN bit = 0, --Valid for @ResultTypeBM IN (16)
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = 100,
	@ProcedureID int = 880000594,
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
EXEC [spPortalAdminGet_Job_Status] @UserID=-10, @InstanceID=527, @VersionID=1055, @ResultTypeBM = 8, @Debug=1,@AssignedJobID = 670
EXEC [spPortalAdminGet_Job_Status] @UserID=-10, @InstanceID=525, @VersionID=1035, @ResultTypeBM = 3, @Debug=1
EXEC [spPortalAdminGet_Job_Status] @UserID=-10, @InstanceID=52, @VersionID=1035, @ResultTypeBM = 24, @Rows = 20, @Debug=1
EXEC [spPortalAdminGet_Job_Status] @UserID=-10, @InstanceID=52, @VersionID=1035, @ResultTypeBM = 16, @AssignedJobID = 87, @OnlyErrorYN = 1, @Debug=1

EXEC [spPortalAdminGet_Job_Status] @ResultTypeBM = 128

EXEC [spPortalAdminGet_Job_Status] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@JobListID int,

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Show Status for all current and previous jobs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-482: Renamed column names in the result set.'
		IF @Version = '2.1.0.2159' SET @Description = 'DB-539: Return parameter info.'
		IF @Version = '2.1.0.2162' SET @Description = 'Return error and timeout info.'
		IF @Version = '2.1.1.2168' SET @Description = 'Added Error Attention. Used [f_GetExecutionTime] function to set [ExecutionTime] and [QueueingTime].'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create temp table'
		IF @ResultTypeBM & 36 > 0
			BEGIN
				CREATE TABLE #JobList
					(
					[InstanceID] int,
					[VersionID] int,
					[JobListID] int,
					[EstimatedTime] time(7)
					)
			END

	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 1,
					ParameterName,
					ParameterDescription = ParameterName,
					DataType,
					ParameterType,
					KeyColumn,
					[@Parameter]
				FROM
					( 
					SELECT ParameterType = 'SingleSelect', [@Parameter] = '@AssignedJobID', ParameterName = 'Job', DataType = 'int', KeyColumn = 'JobID', SortOrder = 10
					UNION SELECT ParameterType = 'SingleSelect', [@Parameter] = '@AssignedJobListID', ParameterName = 'JobList', DataType = 'int', KeyColumn = 'JobListID', SortOrder = 20
					UNION SELECT ParameterType = 'SingleSelect', [@Parameter] = '@AssignedUserID', ParameterName = 'User', DataType = 'int', KeyColumn = 'UserID', SortOrder = 30
					UNION SELECT ParameterType = 'SingleSelect', [@Parameter] = '@AssignedProcedureID', ParameterName = 'Procedure', DataType = 'int', KeyColumn = 'ProcedureID', SortOrder = 40
					) sub
				ORDER BY
					SortOrder
			END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT ResultTypeBM = 2, ParameterName = 'Job', [JobID], [Name] = 'StartTime: ' + CONVERT(nvarchar(50), StartTime), [Description] = 'Duration: ' + CONVERT(nvarchar(20), CONVERT(Time(7), EndTime - StartTime)) FROM pcINTEGRATOR_Log..[Job] J WHERE J.[InstanceID] = @InstanceID AND J.[VersionID] = @VersionID ORDER BY [JobID] DESC
				SELECT DISTINCT ResultTypeBM = 2, ParameterName = 'JobList', J.[JobListID], [Name] = JL.JobListName, [Description] = JL.JobListDescription FROM pcINTEGRATOR_Log..[Job] J INNER JOIN pcINTEGRATOR_Data..JobList JL ON JL.JobListID = J.JobListID WHERE J.[InstanceID] = @InstanceID AND J.[VersionID] = @VersionID ORDER BY J.[JobListID]
				SELECT DISTINCT ResultTypeBM = 2, ParameterName = 'User', J.[UserID], [Name] = U.UserNameDisplay, [Description] = U.UserName FROM pcINTEGRATOR_Log..[Job] J INNER JOIN [User] U ON U.UserID = J.UserID WHERE J.[InstanceID] = @InstanceID AND J.[VersionID] = @VersionID ORDER BY J.[UserID]
				SELECT DISTINCT ResultTypeBM = 2, ParameterName = 'Procedure', P.ProcedureID, [Name] = JL.ProcedureName, [Description] = P.ProcedureDescription FROM pcINTEGRATOR_Log..[JobLog] JL INNER JOIN [Procedure] P ON P.ProcedureName = JL.ProcedureName WHERE JL.[InstanceID] = @InstanceID AND JL.[VersionID] = @VersionID AND JL.JobStepID IS NOT NULL ORDER BY JL.ProcedureName
			END

	SET @Step = '@ResultTypeBM & 4'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				INSERT INTO #JobList
					(
					[InstanceID],
					[VersionID],
					[JobListID]
					)
				SELECT DISTINCT
					[InstanceID] = J.[InstanceID],
					[VersionID] = J.[VersionID],
					[JobListID] = J.JobListID
				FROM
					pcINTEGRATOR_Log..Job J
				WHERE
					J.[InstanceID] = @InstanceID AND
					J.[VersionID] = @VersionID AND
					J.JobQueueYN <> 0 AND
					(J.ClosedYN = 0 OR J.JobID = @JobID)

				UPDATE JL
				SET
					[EstimatedTime] = sub.[EstimatedTime]
				FROM
					#JobList JL
					INNER JOIN 
						(
						SELECT
							J.JobListID,
							[EstimatedTime] = DATEADD(second, AVG(DATEDIFF(second, J.[StartTime], J.[EndTime])), CAST('00:00:00' as time(7)))
						FROM
							pcINTEGRATOR_Log..Job J
							INNER JOIN #JobList JL ON JL.JobListID = J.JobListID
						WHERE
							J.[InstanceID] = @InstanceID AND
							J.[VersionID] = @VersionID AND
							J.ClosedYN <> 0 AND
							J.[StartTime] + 30 > GetDate()
						GROUP BY
							J.JobListID
						) sub ON sub.JobListID = JL.JobListID

				IF @DebugBM & 2 > 0 SELECT TempTable = '#JobList', * FROM #JobList
				
				SELECT
					[ResultTypeBM] = 4, 
					[JobID],
					[JobList],
					[User] = ISNULL(U.[UserNameDisplay], suser_name()),
					[Status],
					[ExecutionStartTime],
					[ExecutionTime],
					[EstimatedTime],
					[QueuingStartTime],
					[QueuingTime]
				FROM
					(
					SELECT TOP (@Rows)
						[JobID] = J.[JobID],
						[JobList] = JL.JobListName,
						[UserID] = J.[UserID],
						[Status] = J.JobStatus, --CASE WHEN J.ClosedYN = 0 THEN 'In Progress' ELSE 'Finalized' END,
						[ExecutionStartTime] = J.[StartTime],
						--[ExecutionTime] = CONVERT(Time(7), CASE WHEN J.ClosedYN = 0 THEN GetDate() ELSE J.[EndTime] END - J.[StartTime]),
						[ExecutionTime] = [dbo].[f_GetExecutionTime] (J.[StartTime], J.[EndTime], J.[ErrorTime]),
						[EstimatedTime] = TJL.[EstimatedTime],
						[QueuingStartTime] = JQ.[Inserted],
						--[QueuingTime] = CONVERT(Time(7), J.[StartTime] - JQ.[Inserted])
						[QueuingTime] = [dbo].[f_GetExecutionTime] (JQ.[Inserted], J.[StartTime], NULL)
					FROM
						pcINTEGRATOR_Log..Job J
						LEFT JOIN #JobList TJL ON TJL.JobListID = J.JobListID
						LEFT JOIN pcINTEGRATOR_Data..JobList JL ON JL.JobListID = J.JobListID
						LEFT JOIN pcINTEGRATOR_Log..JobQueue JQ ON JQ.JobID = J.JobID
					WHERE
						J.[InstanceID] = @InstanceID AND
						J.[VersionID] = @VersionID AND
						J.JobQueueYN <> 0 AND
						(J.ClosedYN = 0 OR J.JobID = @JobID) AND
						NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Log..JobQueue JQC WHERE JQC.JobID = J.JobID AND JQC.JobQueueStatusID = 1)

					UNION
					SELECT TOP (@Rows)
						[JobID] = JQ.[JobID],
						[JobList] = JL.JobListName,
						[UserID] = JQ.[UserID],
						[Status] = J.JobStatus, --'Waiting',
						[ExecutionStartTime] = NULL,
						[ExecutionTime] = NULL,
						[EstimatedTime] = NULL,
						[QueuingStartTime] = JQ.[Inserted],
						--[QueuingTime] = CONVERT(Time(7), GetDate() - JQ.[Inserted])
						[QueuingTime] = [dbo].[f_GetExecutionTime] (JQ.[Inserted], NULL, NULL)
					FROM
						pcINTEGRATOR_Log..JobQueue JQ
						INNER JOIN pcINTEGRATOR_Log..Job J ON J.JobID = JQ.JobID
						LEFT JOIN pcINTEGRATOR_Data..JobList JL ON JL.JobListID = JQ.JobListID
					WHERE
						JQ.[InstanceID] = @InstanceID AND
						JQ.[VersionID] = @VersionID AND
						JQ.JobQueueStatusID = 1
					) sub
					LEFT JOIN [User] U ON U.[UserID] = sub.[UserID]
				ORDER BY
					sub.[JobID] ASC

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 8'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT TOP (@Rows)
					[ResultTypeBM] = 8, 
					[JobID] = J.[JobID],
					[JobList] = JL.[JobListName],
					[UserID] = J.[UserID], 
					[Status] = J.JobStatus, --CASE WHEN J.[ErrorTime] IS NULL THEN 'Finalized' ELSE 'Error' + CASE WHEN J.[Message] IS NULL THEN '' ELSE ' (' + J.[Message] + ')' END END,
					[ExecutionStartTime] = J.[StartTime],
					--[ExecutionTime] = CONVERT(Time(7), ISNULL(J.[EndTime], J.[ErrorTime]) - J.[StartTime])
					[ExecutionTime] = [dbo].[f_GetExecutionTime] (J.[StartTime], J.[EndTime], J.[ErrorTime]),
					[EndTime] = J.[EndTime],
					[ErrorTime] = J.[ErrorTime]
				FROM
					[pcINTEGRATOR_Log].[dbo].[Job] J
					LEFT JOIN pcINTEGRATOR_Data..[JobList] JL ON JL.[JobListID] = J.[JobListID]
					LEFT JOIN [User] U ON U.[UserID] = J.[UserID]
				WHERE
					(J.[InstanceID] = @InstanceID OR @InstanceID IS NULL) AND
					(J.[VersionID] = @VersionID OR @VersionID IS NULL) AND
					(J.[JobID] = @AssignedJobID OR @AssignedJobID IS NULL) AND
					(J.[JobListID] = @AssignedJobListID OR @AssignedJobListID IS NULL) AND
					(J.[UserID] = @AssignedUserID OR @AssignedUserID IS NULL)
				ORDER BY
					J.[JobID] DESC

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 16'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 16, 
					[Procedure] = JL.[ProcedureName],
					[ExecutionStartTime] = JL.[StartTime],
					[ExecutionTime] = JL.[Duration],
					[Deleted] = JL.[Deleted],
					[Inserted] = JL.[Inserted],
					[Updated] = JL.[Updated],
					[Selected] = JL.[Selected],
					[ErrorNo] = JL.[ErrorNumber],
					[ErrorMessage] = JL.[ErrorMessage]
				FROM
					[pcINTEGRATOR_Log].[dbo].[JobLog] JL
				WHERE
					JL.[InstanceID] = @InstanceID AND
					JL.[VersionID] = @VersionID AND
					JL.[JobID] = @AssignedJobID AND
					(JL.[JobStepID] IS NOT NULL OR @SubRoutinesYN <> 0) AND
					(JL.[ErrorNumber] <> 0 OR @OnlyErrorYN = 0) AND
					(JL.[ProcedureID] = @AssignedProcedureID OR @AssignedProcedureID IS NULL)
				ORDER BY
					JL.[StartTime] DESC

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 32'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				TRUNCATE TABLE #JobList
				
				INSERT INTO #JobList
					(
					[InstanceID],
					[VersionID],
					[JobListID]
					)
				SELECT DISTINCT
					[InstanceID] = J.[InstanceID],
					[VersionID] = J.[VersionID],
					[JobListID] = J.JobListID
				FROM
					pcINTEGRATOR_Log..Job J
				WHERE
					J.JobQueueYN <> 0 AND
					J.ClosedYN = 0

				UPDATE JL
				SET
					[EstimatedTime] = sub.[EstimatedTime]
				FROM
					#JobList JL
					INNER JOIN 
						(
						SELECT
							J.JobListID,
							[EstimatedTime] = DATEADD(second, AVG(DATEDIFF(second, J.[StartTime], J.[EndTime])), CAST('00:00:00' as time(7)))
						FROM
							pcINTEGRATOR_Log..Job J
							INNER JOIN #JobList JL ON JL.JobListID = J.JobListID
						WHERE
							J.ClosedYN <> 0 AND
							J.[StartTime] + 30 > GetDate()
						GROUP BY
							J.JobListID
						) sub ON sub.JobListID = JL.JobListID

				IF @DebugBM & 2 > 0 SELECT TempTable = '#JobList', * FROM #JobList
				
				SELECT
					[ResultTypeBM] = 32, 
					[InstanceID] = sub.[InstanceID],
					[VersionID] = sub.[VersionID],
					[InstanceName] = I.[InstanceName],
					[VersionName] = V.[VersionName],
					[ApplicationName] = A.[ApplicationName],
					[JobID],
					[JobList],
					[User] = ISNULL(U.[UserNameDisplay], suser_name()),
					[Status],
					[ExecutionStartTime],
					[ExecutionTime],
					[EndTime],
					[ErrorTime],
					[EstimatedTime],
					[QueuingStartTime],
					[QueuingTime]
				FROM
					(
					SELECT TOP (@Rows)
						[InstanceID] = J.[InstanceID],
						[VersionID] = J.[VersionID],
						[JobID] = J.[JobID],
						[JobList] = JL.JobListName,
						[UserID] = J.[UserID],
						[Status] = J.JobStatus, --CASE WHEN J.ClosedYN = 0 THEN 'In Progress' ELSE 'Finalized' END,
						[ExecutionStartTime] = J.[StartTime],
						--[ExecutionTime] = CONVERT(Time(7), CASE WHEN J.ClosedYN = 0 THEN GetDate() ELSE J.[EndTime] END - J.[StartTime]),
						[ExecutionTime] = [dbo].[f_GetExecutionTime] (J.[StartTime], J.[EndTime], J.[ErrorTime]),
						[EndTime] = J.[EndTime],
						[ErrorTime] = J.[ErrorTime],
						[EstimatedTime] = TJL.[EstimatedTime],
						[QueuingStartTime] = JQ.[Inserted],
						--[QueuingTime] = CONVERT(Time(7), J.[StartTime] - JQ.[Inserted])
						[QueuingTime] = [dbo].[f_GetExecutionTime] (JQ.[Inserted], J.[StartTime], NULL)
					FROM
						pcINTEGRATOR_Log..Job J
						LEFT JOIN #JobList TJL ON TJL.JobListID = J.JobListID
						LEFT JOIN pcINTEGRATOR_Data..JobList JL ON JL.JobListID = J.JobListID
						LEFT JOIN pcINTEGRATOR_Log..JobQueue JQ ON JQ.JobID = J.JobID
					WHERE
						J.JobQueueYN <> 0 AND
						J.ClosedYN = 0 AND
						NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Log..JobQueue JQC WHERE JQC.JobID = J.JobID AND JQC.JobQueueStatusID = 1)

					UNION
					SELECT TOP (@Rows)
						[InstanceID] = JQ.[InstanceID],
						[VersionID] = JQ.[VersionID],
						[JobID] = JQ.[JobID],
						[JobList] = JL.JobListName,
						[UserID] = JQ.[UserID],
						[Status] = J.JobStatus, --'Waiting',
						[ExecutionStartTime] = NULL,
						[ExecutionTime] = NULL,
						[EndTime] = NULL,
						[ErrorTime] = NULL,
						[EstimatedTime] = NULL,
						[QueuingStartTime] = JQ.[Inserted],
						--[QueuingTime] = CONVERT(Time(7), GetDate() - JQ.[Inserted])
						[QueuingTime] = [dbo].[f_GetExecutionTime] (JQ.[Inserted], NULL, NULL)
					FROM
						pcINTEGRATOR_Log..JobQueue JQ
						INNER JOIN pcINTEGRATOR_Log..Job J ON J.JobID = JQ.JobID
						LEFT JOIN pcINTEGRATOR_Data..JobList JL ON JL.JobListID = JQ.JobListID
					WHERE
						JQ.JobQueueStatusID = 1
					) sub
					LEFT JOIN pcINTEGRATOR_Data..[Instance] I ON I.[InstanceID] = sub.[InstanceID]
					LEFT JOIN pcINTEGRATOR_Data..[Version] V ON V.[VersionID] = sub.[VersionID]
					LEFT JOIN pcINTEGRATOR_Data..[Application] A ON A.[InstanceID] = sub.[InstanceID] AND A.[VersionID] = sub.[VersionID]
					LEFT JOIN [User] U ON U.[UserID] = sub.[UserID]
				ORDER BY
					sub.[InstanceID],
					sub.[VersionID],
					sub.[JobID] ASC

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 192, ErrorAttention'
		IF @ResultTypeBM & 192 > 0
			BEGIN
				EXEC [spGet_ErrorAttention] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ResultTypeBM=@ResultTypeBM, @JobID=@JobID, @Debug=@DebugSub
			END

	SET @Step = 'Drop temp tables'
		IF @ResultTypeBM & 36 > 0 DROP TABLE #JobList

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
