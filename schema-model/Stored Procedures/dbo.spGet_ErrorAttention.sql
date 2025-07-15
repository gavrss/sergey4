SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_ErrorAttention]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 3, --1 (64) = Not cleared errors, 2 (128) = Cleared Errors

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000753,
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
EXEC [spGet_ErrorAttention] @ResultTypeBM = 3, @InstanceID = 413

EXEC [spGet_ErrorAttention] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ResultTypeBM_Show int,

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
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get rows regarding ErrorAttention',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2168' SET @Description = 'Procedure created. Set correct @ResultTypeBM_Show value. Used function [f_GetExecutionTime] in setting [TimeOpen].'
		IF @Version = '2.1.1.2174' SET @Description = 'Filtered out: exclude JobLog.[ErrorNumber] <> -1 and Inserted time less than 24 hours'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

	SET @Step = '@ResultTypeBM & 1, not cleared'
		IF @ResultTypeBM & 65 > 0
			BEGIN
				SET @ResultTypeBM_Show = CASE WHEN @ResultTypeBM & 64 > 0 THEN 64 ELSE 1 END

				SELECT 
					[ResultTypeBM] = @ResultTypeBM_Show,
					EA.[Comment],
					EA.[UpdatedBy],
					--[TimeOpen] = CONVERT(nvarchar(15), DATEDIFF(dd, EA.[Inserted], ISNULL(EA.[Updated], GetDate()))) + ' day(s) ' + CONVERT(nvarchar(15), DATEDIFF(hh, EA.[Inserted], ISNULL(EA.[Updated], GetDate())) - DATEDIFF(dd, EA.[Inserted], ISNULL(EA.[Updated], GetDate())) * 24) + ' hour(s)',
					[TimeOpen] = [dbo].[f_GetExecutionTime](EA.[Inserted], NULL, NULL),
					[Inserted] = EA.[Inserted],
					JL.*
				FROM
					[pcINTEGRATOR_Log].[dbo].[JobLog] JL
					LEFT JOIN [pcINTEGRATOR_Log].[dbo].[ErrorAttention] EA ON EA.[JobLogID] = JL.[JobLogID]
				WHERE
					(JL.[InstanceID] = @InstanceID OR ISNULL(@InstanceID, 0) = 0) AND
					(JL.[VersionID] = @VersionID OR ISNULL(@VersionID, 0) = 0) AND
					JL.[ErrorNumber] <> 0 AND
					(	(JL.[ErrorNumber] <> -1 AND DATEDIFF(HOUR, EA.[Inserted], GETDATE()) <=24) OR
						DATEDIFF(HOUR, EA.[Inserted], GETDATE()) > 24) AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[ErrorAttention] EAD WHERE EAD.[JobLogID] = JL.[JobLogID] AND EAD.[ClearedYN] <> 0) 


				ORDER BY
					EA.[Inserted] DESC
			END

	SET @Step = '@ResultTypeBM & 2, Cleared'
		IF @ResultTypeBM & 130 > 0
			BEGIN
				SET @ResultTypeBM_Show = CASE WHEN @ResultTypeBM & 128 > 0 THEN 128 ELSE 2 END

				SELECT
					[ResultTypeBM] = @ResultTypeBM_Show,
					EA.[Comment],
					EA.[UpdatedBy],
					--[TimeOpen] = CONVERT(nvarchar(15), DATEDIFF(dd, EA.[Inserted], ISNULL(EA.[Updated], GetDate()))) + ' day(s) ' + CONVERT(nvarchar(15), DATEDIFF(hh, EA.[Inserted], ISNULL(EA.[Updated], GetDate())) - DATEDIFF(dd, EA.[Inserted], ISNULL(EA.[Updated], GetDate())) * 24) + ' hour(s)',
					[TimeOpen] = [dbo].[f_GetExecutionTime](EA.[Inserted], EA.[Updated], EA.[Updated]),
					EA.[InstanceID],
					EA.[VersionID],
					EA.[JobLogID],
					JL.[ProcedureName],
					JL.[ErrorNumber],
					JL.[ErrorSeverity],
					JL.[ErrorMessage],
					EA.[Inserted],
					EA.[Updated]
				FROM
					[pcINTEGRATOR_Log].[dbo].[ErrorAttention] EA
					INNER JOIN [pcINTEGRATOR_Log].[dbo].[JobLog] JL ON JL.[JobLogID] = EA.[JobLogID]
				WHERE
					(EA.[InstanceID] = @InstanceID OR ISNULL(@InstanceID, 0) = 0) AND
					(EA.[VersionID] = @VersionID OR ISNULL(@VersionID, 0) = 0) AND
					EA.[ClearedYN] <> 0
				ORDER BY
					EA.[Inserted] DESC
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
