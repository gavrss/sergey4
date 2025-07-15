SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Grid_Dimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@GridID int = NULL,
	@DimensionID int = NULL,
	@GridAxisID int = NULL, -- -5=Fixed, -3=Column, -2=Row, -1=Filter
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000274,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_Grid_Dimension',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

--UPDATE
EXEC [spPortalAdminSet_Grid_Dimension]
	@UserID = -10,
	@InstanceID = 114,
	@VersionID = 1004,
	@GridID = 1006,
	@DimensionID = 1016,
	@GridAxisID = -2,
	@DeleteYN = 0,

--DELETE
EXEC [spPortalAdminSet_Grid_Dimension]
	@UserID = -10,
	@InstanceID = 114,
	@VersionID = 1004,
	@GridID = 1006,
	@DimensionID = 1016,
	@DeleteYN = 1

--INSERT
EXEC [spPortalAdminSet_Grid_Dimension]
	@UserID = -10,
	@InstanceID = 114,
	@VersionID = 1004,
	@GridID = 1006,
	@DimensionID = 1016,
	@GridAxisID = -2

EXEC [spPortalAdminSet_Grid_Dimension] @GetVersion = 1
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update Dimension list for a specific Grid',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'

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

	SET @Step = 'Update existing member'
		IF @DeleteYN = 0 AND @GridAxisID IS NOT NULL
			BEGIN
				UPDATE GD
				SET
					[GridAxisID] = @GridAxisID
				FROM
					[pcINTEGRATOR_Data].[dbo].[Grid_Dimension] GD
				WHERE
					GD.[InstanceID] = @InstanceID AND
					GD.[GridID] = @GridID AND
					GD.[DimensionID] = @DimensionID

				SET @Updated = @Updated + @@ROWCOUNT

				IF @Updated > 0
					SET @Message = 'The member is updated.' 
				ELSE
					SET @Message = 'No member is updated.' 
				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				DELETE GD
				FROM
					[pcINTEGRATOR_Data].[dbo].[Grid_Dimension] GD
				WHERE
					GD.[InstanceID] = @InstanceID AND
					GD.[GridID] = @GridID AND
					GD.[DimensionID] = @DimensionID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 
				ELSE
					SET @Message = 'No member is deleted.' 
				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @DeleteYN = 0 AND @Updated = 0 AND @GridAxisID IS NOT NULL
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid_Dimension]
					(
					[InstanceID],
					[GridID],
					[DimensionID],
					[GridAxisID]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[GridID] = @GridID,
					[DimensionID] = @DimensionID,
					[GridAxisID] = @GridAxisID
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Grid_Dimension] GD WHERE GD.[GridID] = @GridID AND GD.[DimensionID] = @DimensionID)

				SET @Inserted = @Inserted + @@ROWCOUNT
				
				IF @Inserted > 0
					SET @Message = 'The new member is added.' 
				ELSE
					SET @Message = 'No member is added.' 
			END

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
