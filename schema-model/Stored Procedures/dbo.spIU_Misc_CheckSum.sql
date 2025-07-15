SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Misc_CheckSum]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000684,
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
EXEC [spIU_Misc_CheckSum] @UserID=-10, @InstanceID=390, @VersionID=1011, @JobID = 2054, @Debug=1
EXEC [spIU_Misc_CheckSum] @UserID=-10, @InstanceID=531, @VersionID=1057, @Debug=1

EXEC [spIU_Misc_CheckSum] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CheckSumID INT,
	@spCheckSum NVARCHAR(100),
	@SQLStatement NVARCHAR(MAX),
	@CheckSumValue INT,
	@CheckSumStatus10 INT,
	@CheckSumStatus20 INT,
	@CheckSumStatus30 INT,
	@CheckSumStatus40 INT,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
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
	@Version nvarchar(50) = '2.1.1.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Calculate CheckSum for selected Application',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-106: Implemented full logging.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.1.2171' SET @Description = 'Enhanced debugging.'
		IF @Version = '2.1.1.2172' SET @Description = 'Implemented CheckSumStatusID count from [CheckSumLog].'
		IF @Version = '2.1.1.2179' SET @Description = 'Reset CheckSumStatus count at the start of CheckSum_Cursor WHILE loop.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy = @ModifiedBy, @JobID = @ProcedureID
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

	SET @Step = 'Create temp table #CheckSumValue'
		CREATE TABLE #CheckSumValue (CheckSumValue int)

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			EXEC [spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=1,
				@CheckCount = 0,
				@JobID=@JobID OUT

	SET @Step = 'Run CheckSum_Cursor'
		SELECT DISTINCT
			[CheckSumID],
			[spCheckSum],
			[SortOrder]
		INTO
			#CheckSum_Cursor
		FROM
			pcINTEGRATOR_Data..[CheckSum]
		 WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0
		ORDER BY
			[SortOrder]
		OPTION (MAXDOP 1)

		IF @Debug <> 0 SELECT TempTable = '#CheckSum_Cursor', * FROM #CheckSum_Cursor ORDER BY [SortOrder]

		DECLARE CheckSum_Cursor CURSOR FOR

		SELECT
			[CheckSumID],
			[spCheckSum]
		FROM
			#CheckSum_Cursor
		ORDER BY
			[SortOrder]
		
		OPEN CheckSum_Cursor

		FETCH NEXT FROM CheckSum_Cursor INTO @CheckSumID, @spCheckSum
	
		WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT @CheckSumValue = 0, @CheckSumStatus10 = 0, @CheckSumStatus20 = 0, @CheckSumStatus30 = 0, @CheckSumStatus40 = 0

				SET @SQLStatement = @spCheckSum + ' @UserID = ' + CONVERT(nvarchar(10), @UserID) + ', @InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ', @VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ', @CheckSumValue = @CheckSumValue OUT, @CheckSumStatus10 = @CheckSumStatus10 OUT, @CheckSumStatus20 = @CheckSumStatus20 OUT, @CheckSumStatus30 = @CheckSumStatus30 OUT, @CheckSumStatus40 = @CheckSumStatus40 OUT, @JobID = ' + CONVERT(nvarchar(15), @JobID)
				IF @Debug <> 0 PRINT @SQLStatement
				EXEC sp_executesql @SQLStatement, N'@CheckSumValue int OUT, @CheckSumStatus10 int OUT, @CheckSumStatus20 int OUT, @CheckSumStatus30 int OUT, @CheckSumStatus40 int OUT', @CheckSumValue = @CheckSumValue OUT, @CheckSumStatus10 = @CheckSumStatus10 OUT, @CheckSumStatus20 = @CheckSumStatus20 OUT, @CheckSumStatus30 = @CheckSumStatus30 OUT, @CheckSumStatus40 = @CheckSumStatus40 OUT

				IF @Debug <> 0 SELECT [@JobID] = @JobID, [@CheckSumID] = @CheckSumID, [@spCheckSum] = @spCheckSum, [@CheckSumValue] = @CheckSumValue, [@CheckSumStatus10] = @CheckSumStatus10, [@CheckSumStatus20] = @CheckSumStatus20, [@CheckSumStatus30] = @CheckSumStatus30, [@CheckSumStatus40] = @CheckSumStatus40

				IF @CheckSumValue IS NOT NULL
					BEGIN
						INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumLog]
							(
							[InstanceID],
							[VersionID],
							[JobID],
							[CheckSumID],
							[CheckSumValue],
							[CheckSumStatus10],
							[CheckSumStatus20],
							[CheckSumStatus30],
							[CheckSumStatus40],
							[Inserted]							
							)
						SELECT
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[JobID] = @JobID,
							[CheckSumID] = @CheckSumID,
							[CheckSumValue] = @CheckSumValue,
							[CheckSumStatus10] = @CheckSumStatus10,
							[CheckSumStatus20] = @CheckSumStatus20,
							[CheckSumStatus30] = @CheckSumStatus30,
							[CheckSumStatus40] = @CheckSumStatus40,
							[Inserted] = GetDate()							

						SET @Inserted = @Inserted + @@ROWCOUNT
					END
						
				FETCH NEXT FROM CheckSum_Cursor INTO @CheckSumID, @spCheckSum
			END

		CLOSE CheckSum_Cursor
		DEALLOCATE CheckSum_Cursor

	SET @Step = 'Drop temp table'
		DROP TABLE #CheckSumValue
		DROP TABLE #CheckSum_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

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
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
