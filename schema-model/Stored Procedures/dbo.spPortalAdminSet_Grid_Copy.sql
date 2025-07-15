SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Grid_Copy]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignedGridID int = NULL, --Mandatory Source GridID
	@AssignedInstanceID int = NULL, --Mandatory Source InstanceID
	@GridName nvarchar(50) = NULL, --Optional
	@NewGridID int = NULL OUT,
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000518,
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
EXEC [spPortalAdminSet_Grid_Copy]
	@UserID = -10,
	@InstanceID = 413,
	@VersionID = 1008,
	@AssignedGridID = 12482,
	@AssignedInstanceID = 413,
	@GridName = 'TestGridCopy'

EXEC [spPortalAdminSet_Grid_Copy] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2155'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Make a copy of specified Grid and Grid_Dimension',
			@MandatoryParameter = 'AssignedGridID|AssignedInstanceID' --Without @, separated by |

		IF @Version = '2.0.2.2149' SET @Description = 'DB-232: Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-283, DB-302: Support copy of Grid/Grid_Dimension of another Instance.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-403: Added @VersionID and set correct newly created GridID.'

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Step = 'Create new Grid'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid]
			(
			[InstanceID],
			[VersionID],
			[GridName],
			[GridDescription],
			[DataClassID],
			[GridSkinID],
			[GetProc],
			[SetProc],
			[InheritedFrom]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[GridName] = ISNULL(@GridName, [GridName] + ' (copy)'),
			[GridDescription] = ISNULL(@GridName, [GridDescription] + ' (copy)'),
			[DataClassID],
			[GridSkinID],
			[GetProc],
			[SetProc],
			[InheritedFrom] = [GridID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Grid]
		WHERE
			InstanceID = @AssignedInstanceID AND
			GridID = @AssignedGridID

		SELECT 
			@NewGridID = SCOPE_IDENTITY(),
			@Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [@NewGridID] = @NewGridID

	SET @Step = 'Add rows to table Grid_Dimension'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid_Dimension]
			(
			[InstanceID],
			[VersionID],
			[GridID],
			[DimensionID],
			[GridAxisID]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[GridID] = @NewGridID,
			[DimensionID],
			[GridAxisID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Grid_Dimension]
		WHERE
			InstanceID = @AssignedInstanceID AND
			GridID = @AssignedGridID
				
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return new GridID'		
		SELECT [@NewGridID] = @NewGridID

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
