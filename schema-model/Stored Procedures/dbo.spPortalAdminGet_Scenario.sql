SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Scenario]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 15, -- 1=Scenarios, 2=ScenarioTypes, 4=DataClasses, 8=Conversion_MemberKey
--	@ProcessID int = NULL,
	@DataClassID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000783,
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
EXEC [spPortalAdminGet_Scenario] @UserID = -10, @InstanceID = 413, @VersionID = 1008
EXEC [spPortalAdminGet_Scenario] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @DataClassID = 1028

EXEC [spPortalAdminGet_Scenario] @GetVersion = 1
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
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows for form Scenario.',
			@MandatoryParameter = ''
		IF @Version = '2.1.1.2172' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2173' SET @Description = 'Disable Version and LineItem in ResultTypeBM = 8.'

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

	SET @Step = 'Return list of Scenarios'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 1,
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

	SET @Step = 'Return list of ScenarioTypes'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 2,
					ScenarioTypeId = ST.ScenarioTypeId,
					ScenarioTypeName = ST.ScenarioTypeName,
					ScenarioTypeDescription = ST.ScenarioTypeName,
					WorkflowYN = ST.WorkflowYN,
					FullDimensionalityYN = ST.FullDimensionalityYN,
					LiveYN = ST.LiveYN
				FROM 
					[ScenarioType] ST
				WHERE
					ST.InstanceID IN (0, @InstanceID)
					--(ST.WorkflowYN = @WorkflowYN OR @WorkflowYN IS NULL) AND
					--(ST.FullDimensionalityYN = @FullDimensionalityYN OR @FullDimensionalityYN IS NULL) AND
					--(ST.LiveYN = @LiveYN OR @LiveYN IS NULL)
				ORDER BY
					ScenarioTypeName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of DataClasses'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					DataClassID = DC.DataClassID,
					[DataClassName] = DC.[DataClassName]
				FROM 
					[DataClass] DC
				WHERE
					DC.InstanceID = @InstanceID AND
					DC.VersionID = @VersionID AND
					DC.SelectYN <> 0 AND
					DC.DeletedID IS NULL AND
					DC.DataClassTypeID <> -5
				ORDER BY
					DC.[DataClassName]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of DataClass dimensions'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 8,
					[DataClassID] = DCD.[DataClassID],
					[DimensionID] = DCD.[DimensionID],
					[DimensionName] = D.[DimensionName],
					[Conversion_MemberKey] = DCD.[Conversion_MemberKey],
					[EnabledYN] = CASE WHEN DCD.[DimensionID] IN (-2, -26, -27, -34, -55) THEN 0 ELSE 1 END
				FROM 
					[DataClass_Dimension] DCD
					INNER JOIN [Dimension] D ON D.InstanceID IN (0, @InstanceID) AND D.[DimensionID] = DCD.[DimensionID]
				WHERE
					DCD.[InstanceID] = @InstanceID AND
					DCD.[VersionID] = @VersionID AND
					DCD.[DataClassID] = @DataClassID AND
					DCD.[DimensionID] NOT IN (-6, -7, -8, -49, -63)
				ORDER BY
					D.[DimensionName]

				SET @Selected = @Selected + @@ROWCOUNT
			END

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
