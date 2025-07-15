SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_JobQueue]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	--SP-specific parameters
	@LoopInterval nvarchar(10) = NULL,

	@JobID int = NULL, --Mandatory
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000585,
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
EXEC [spCheck_JobQueue] @UserID=-10, @InstanceID=0, @VersionID=0, @Debug=1
EXEC [spCheck_JobQueue] @UserID=-10, @InstanceID=0, @VersionID=0, @LoopInterval = '00:00:30', @Debug=1

EXEC [spCheck_JobQueue] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@JobQueueID bigint,
	@LoopStart datetime,

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
	@Version nvarchar(50) = '2.1.1.2169'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Check for rows in JobQueue to release',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2159' SET @Description = 'Make Loop optional.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added timeout handling. Check JobQueue when setting timeout.'
		IF @Version = '2.1.0.2165' SET @Description = 'Enhanced timeout handling. Enhanced logging.'
		IF @Version = '2.1.1.2169' SET @Description = 'Set JobStatus to Timeout.'

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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create temp table'
		CREATE TABLE #Loop_Cursor_Table
			(
			[InstanceID] int,
			[VersionID] int,
			[JobQueueID] bigint,
			[JobID] bigint
			)

	SET @Step = 'Timeout handling'
		UPDATE J
		SET
			[JobStatus] = 'Timeout',
			[ErrorTime] = GetDate(),
			[ClosedYN] = 1,
			[Message] = 'Timeout'
		FROM
			[pcINTEGRATOR_Log].[dbo].[Job] J 
			INNER JOIN (SELECT
							[JobID] = J.[JobID], 
							[MaxStartTime] = MAX(JL.StartTime)
						FROM
							[pcINTEGRATOR_Log].[dbo].[JobLog] JL
							INNER JOIN [pcINTEGRATOR_Log].[dbo].[Job] J ON J.JobID = JL.JobID AND J.[EndTime] IS NULL AND J.[ErrorTime] IS NULL AND J.[ClosedYN] = 0
						GROUP BY
							J.[JobID]
						) sub ON sub.[JobID] = J.[JobID] AND sub.[MaxStartTime] + CONVERT(datetime, J.[TimeOut]) < GetDate()
		WHERE 
			J.[EndTime] IS NULL AND
			J.[ErrorTime] IS NULL AND
			J.[ClosedYN] = 0 AND
			(J.[JobQueueYN] = 0 OR NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[JobQueue] JQ WHERE JQ.[JobID] = J.[JobID] AND JQ.[JobQueueStatusID] = 1))

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Check for queue rows to release'
		IF @LoopInterval IS NULL
			BEGIN
				TRUNCATE TABLE #Loop_Cursor_Table

				INSERT INTO #Loop_Cursor_Table
					(
					[InstanceID],
					[VersionID],
					[JobQueueID],
					[JobID]
					)
				SELECT
					JQ.[InstanceID],
					JQ.[VersionID],
					JQ.[JobQueueID],
					JQ.[JobID]
				FROM
					[pcINTEGRATOR_Log].[dbo].[JobQueue] JQ
					INNER JOIN
						(
						SELECT 
							[InstanceID],
							[VersionID],
							[JobQueueID] = MIN([JobQueueID])
						FROM
							[pcINTEGRATOR_Log].[dbo].[JobQueue]
						WHERE
							[JobQueueStatusID] = 1
						GROUP BY
							[InstanceID],
							[VersionID]
						) sub ON sub.[InstanceID] = JQ.[InstanceID] AND sub.[VersionID] = JQ.[VersionID] AND sub.[JobQueueID] = JQ.[JobQueueID]

				IF CURSOR_STATUS('global','Loop_Cursor') >= -1 DEALLOCATE Loop_Cursor
				DECLARE Loop_Cursor CURSOR FOR
			
					SELECT 
						[InstanceID],
						[VersionID],
						[JobQueueID],
						[JobID]
					FROM
						#Loop_Cursor_Table
					ORDER BY
						[InstanceID],
						[VersionID]

					OPEN Loop_Cursor
					FETCH NEXT FROM Loop_Cursor INTO @InstanceID, @VersionID, @JobQueueID, @JobID

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@JobQueueID] = @JobQueueID, [@JobID] = @JobID

							IF (SELECT COUNT(1) FROM [pcINTEGRATOR_Log].[dbo].[Job] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [JobID] < @JobID AND [JobQueueYN] <> 0 AND [ClosedYN] = 0) = 0
								EXEC [spSet_JobQueue]
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@JobQueueID = @JobQueueID,
									@JobQueueStatusID = 2,
									@SetJobLogYN = 0,
									@JobID = @JobID

							FETCH NEXT FROM Loop_Cursor INTO @InstanceID, @VersionID, @JobQueueID, @JobID
						END

				CLOSE Loop_Cursor
				DEALLOCATE Loop_Cursor

				IF @DebugBM & 2 > 0 SELECT [Time] = GetDate(), [ExecutionTime] = GetDate() - @LoopStart
			END

	SET @Step = 'Loop and check for queue rows to release'
		IF @LoopInterval IS NOT NULL
			BEGIN
				WHILE 1 = 1
					BEGIN
						WAITFOR DELAY @LoopInterval

						SET @LoopStart = GetDate()
				
						TRUNCATE TABLE #Loop_Cursor_Table

						INSERT INTO #Loop_Cursor_Table
							(
							[InstanceID],
							[VersionID],
							[JobQueueID],
							[JobID]
							)
						SELECT
							JQ.[InstanceID],
							JQ.[VersionID],
							JQ.[JobQueueID],
							JQ.[JobID]
						FROM
							[pcINTEGRATOR_Log].[dbo].[JobQueue] JQ
							INNER JOIN
								(
								SELECT 
									[InstanceID],
									[VersionID],
									[JobQueueID] = MIN([JobQueueID])
								FROM
									[pcINTEGRATOR_Log].[dbo].[JobQueue]
								WHERE
									[JobQueueStatusID] = 1
								GROUP BY
									[InstanceID],
									[VersionID]
								) sub ON sub.[InstanceID] = JQ.[InstanceID] AND sub.[VersionID] = JQ.[VersionID] AND sub.[JobQueueID] = JQ.[JobQueueID]

						IF CURSOR_STATUS('global','Loop_Cursor') >= -1 DEALLOCATE Loop_Cursor
						DECLARE Loop_Cursor CURSOR FOR
			
							SELECT 
								[InstanceID],
								[VersionID],
								[JobQueueID],
								[JobID]
							FROM
								#Loop_Cursor_Table
							ORDER BY
								[InstanceID],
								[VersionID]

							OPEN Loop_Cursor
							FETCH NEXT FROM Loop_Cursor INTO @InstanceID, @VersionID, @JobQueueID, @JobID

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @DebugBM & 2 > 0 SELECT [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@JobQueueID] = @JobQueueID, [@JobID] = @JobID

									IF (SELECT COUNT(1) FROM [pcINTEGRATOR_Log].[dbo].[Job] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [JobID] < @JobID AND [JobQueueYN] <> 0 AND [ClosedYN] = 0) = 0
										EXEC [spSet_JobQueue]
											@UserID = @UserID,
											@InstanceID = @InstanceID,
											@VersionID = @VersionID,
											@JobQueueID = @JobQueueID,
											@JobQueueStatusID = 2,
											@SetJobLogYN = 0,
											@JobID = @JobID

									FETCH NEXT FROM Loop_Cursor INTO @InstanceID, @VersionID, @JobQueueID, @JobID
								END

						CLOSE Loop_Cursor
						DEALLOCATE Loop_Cursor

						IF @DebugBM & 2 > 0 SELECT [Time] = GetDate(), [ExecutionTime] = GetDate() - @LoopStart
					END
			END

	SET @Step = 'Drop temp table'
		DROP TABLE #Loop_Cursor_Table

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @Updated <> 0 OR (DATEPART(minute, GetDate()) = 0 AND DATEPART(second, GetDate()) BETWEEN 10 AND 50)
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
