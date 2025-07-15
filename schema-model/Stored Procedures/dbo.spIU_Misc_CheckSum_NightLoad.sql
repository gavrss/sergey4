SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Misc_CheckSum_NightLoad]
	@UserID INT = -10,
	@InstanceID INT = 0,
	@VersionID INT = 0,

	@AssignedInstanceID INT = NULL,
	@AssignedVersionID INT = NULL,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000830,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose


--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Misc_CheckSum_NightLoad] @UserID=-10, @InstanceID=0, @VersionID=0, @DebugBM=15, @AssignedInstanceID=559, @AssignedVersionID=1069

EXEC [spIU_Misc_CheckSum_NightLoad] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CheckSum_InstanceID INT = NULL,
	@CheckSum_VersionID INT = NULL,
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
			@ProcedureDescription = 'Calculate CheckSum (spCheckSum_NightLoad) for selected Application',
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
			--@JobID = ISNULL(@JobID, @ProcedureID),
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

	SET @Step = 'Create temp table #CheckSumValue'
		CREATE TABLE #CheckSumValue (CheckSumValue int)

	SET @Step = 'Run CheckSum_Cursor'
		SELECT DISTINCT
			[InstanceID],
			[VersionID],
			[CheckSumID],
			[spCheckSum],
			[SortOrder]
		INTO
			#CheckSum_Cursor
		FROM
			[pcINTEGRATOR_Data].[dbo].[CheckSum]
		WHERE
			[spCheckSum] = 'spCheckSum_NightLoad' AND
			([InstanceID] = @AssignedInstanceID OR @AssignedInstanceID IS NULL) AND 
			([VersionID] = @AssignedVersionID OR @AssignedVersionID IS NULL) AND
			[SelectYN] <> 0
		ORDER BY
			[InstanceID], 
			[VersionID], 
			[SortOrder]
		OPTION (MAXDOP 1)

		IF @Debug <> 0 SELECT TempTable = '#CheckSum_Cursor', * FROM #CheckSum_Cursor ORDER BY [SortOrder]

		IF CURSOR_STATUS('global','CheckSum_Cursor') >= -1 DEALLOCATE CheckSum_Cursor
		DECLARE CheckSum_Cursor CURSOR FOR

		SELECT
			[CheckSum_InstanceID] = [InstanceID],
			[CheckSum_VersionID] = [VersionID],
			[CheckSumID],
			[spCheckSum]
		FROM
			#CheckSum_Cursor
		ORDER BY
			[CheckSum_InstanceID], 
			[CheckSum_VersionID], 
			[SortOrder]
		
		OPEN CheckSum_Cursor

		FETCH NEXT FROM CheckSum_Cursor INTO @CheckSum_InstanceID, @CheckSum_VersionID, @CheckSumID, @spCheckSum
	
		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @Debug <> 0 SELECT [@CheckSum_InstanceID] = @CheckSum_InstanceID, [@CheckSum_VersionID] = @CheckSum_VersionID, [@CheckSumID] = @CheckSumID, [@spCheckSum] = @spCheckSum

				SELECT @CheckSumValue = 0, @CheckSumStatus10 = 0, @CheckSumStatus20 = 0, @CheckSumStatus30 = 0, @CheckSumStatus40 = 0

				SET @SQLStatement = @spCheckSum + ' @UserID = ' + CONVERT(nvarchar(10), @UserID) + ', @InstanceID = ' + CONVERT(nvarchar(15), @CheckSum_InstanceID) + ', @VersionID = ' + CONVERT(nvarchar(15), @CheckSum_InstanceID) + ', @CheckSumValue = @CheckSumValue OUT, @CheckSumStatus10 = @CheckSumStatus10 OUT, @CheckSumStatus20 = @CheckSumStatus20 OUT, @CheckSumStatus30 = @CheckSumStatus30 OUT, @CheckSumStatus40 = @CheckSumStatus40 OUT, @JobID = ' + CONVERT(nvarchar(15), @JobID)
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
							[InstanceID] = @CheckSum_InstanceID,
							[VersionID] = @CheckSum_VersionID,
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
				
				FETCH NEXT FROM CheckSum_Cursor INTO @CheckSum_InstanceID, @CheckSum_VersionID, @CheckSumID, @spCheckSum
			END

		CLOSE CheckSum_Cursor
		DEALLOCATE CheckSum_Cursor

	SET @Step = 'Drop temp table'
		DROP TABLE #CheckSumValue
		DROP TABLE #CheckSum_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

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
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
