SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_ScenarioList]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ProcessID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000104,
	@Parameter nvarchar(4000) = NULL,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

AS

/*
**** LEGACY Replaced by [spPortalAdminGet_ScenarioList] ResultTypeBM=1 *******

EXEC [spRun_Procedure_KeyValuePair] 
@JSON='[{"TKey":"InstanceID","TValue":"413"},{"TKey":"UserID","TValue":"2147"},{"TKey":"VersionID","TValue":"1008"}]', 
@ProcedureName='spPortalAdminGet_ScenarioList'

EXEC [spPortalAdminGet_ScenarioList] @UserID = -10, @InstanceID = 304, @VersionID = 1001
EXEC [spPortalAdminGet_ScenarioList] @UserID = -10, @InstanceID = 413, @VersionID = 1008

EXEC [spPortalAdminGet_ScenarioList] @GetVersion = 1
*/

DECLARE
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows for form Scenario.',
			@MandatoryParameter = ''
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'New JobLog handling.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set ProcedureID in JobLog.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added column [SimplifiedDimensionalityYN].'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())
		--EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT

	SET @Step = 'Return rows'
		IF @ProcessID IS NULL
			BEGIN
				SELECT 
					S.[ScenarioID],
					S.[MemberKey],
					S.[ScenarioDescription],
					S.[ScenarioTypeID],
					ST.[ScenarioTypeName],
					ST.[LiveYN],
					ST.[WorkflowYN],
					S.[ActualOverwriteYN],
					S.[AutoRefreshYN],
					S.[InputAllowedYN],
					S.[AutoSaveOnCloseYN],
					S.[SimplifiedDimensionalityYN],
					S.[ClosedMonth],
					S.DrillTo_MemberKey,
					S.LockedDate,
					S.[SelectYN]
				FROM
					Scenario S
					INNER JOIN ScenarioType ST ON ST.ScenarioTypeID = S.ScenarioTypeID
				WHERE
					S.[InstanceID] = @InstanceID AND
					S.[VersionID] = @VersionID AND
					S.[DeletedID] IS NULL
				ORDER BY
					S.[SortOrder],
					S.[ScenarioTypeID] DESC,
					S.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END
		ELSE
			BEGIN
				SELECT 
					S.[ScenarioID],
					S.[MemberKey],
					S.[ScenarioDescription],
					S.[ScenarioTypeID],
					ST.[ScenarioTypeName],
					ST.[LiveYN],
					ST.[WorkflowYN],
					S.[ActualOverwriteYN],
					S.[AutoRefreshYN],
					S.[InputAllowedYN],
					S.[AutoSaveOnCloseYN],
					S.[SimplifiedDimensionalityYN],
					S.[ClosedMonth],
					S.DrillTo_MemberKey,
					S.LockedDate,
					S.[SelectYN]
				FROM
					Scenario S
					INNER JOIN ScenarioType ST ON ST.ScenarioTypeID = S.ScenarioTypeID
					INNER JOIN Process_Scenario PS ON PS.ScenarioID = S.ScenarioID AND PS.ProcessID = @ProcessID
				WHERE
					S.[InstanceID] = @InstanceID AND
					S.[VersionID] = @VersionID AND
					S.[DeletedID] IS NULL
				ORDER BY
					S.[SortOrder],
					S.[ScenarioTypeID] DESC,
					S.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

--WAITFOR DELAY '00:00:10'
--SELECT 3 / 0

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
