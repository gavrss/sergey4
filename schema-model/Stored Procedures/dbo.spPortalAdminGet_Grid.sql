SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Grid]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@GridID int = NULL, --Optional
	@ResultTypeBM int = 7, --1=List of grids, 2=Dimensions per grid, 4=List of GridAxis

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000492,
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
	@ProcedureName = 'spPortalAdminGet_Grid',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "114"},
		{"TKey" : "VersionID",  "TValue": "1004"}
		]'

EXEC [spPortalAdminGet_Grid] @UserID = -10, @InstanceID = 390, @GridID = 6278, @ResultTypeBM = 3, @Debug = 1
EXEC [spPortalAdminGet_Grid] @UserID = -10, @InstanceID = 413, @ResultTypeBM = 7, @Debug = 1

EXEC [spPortalAdminGet_Grid] @GetVersion = 1
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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.2.2149'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns data of a Grid.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'DB-167: Procedure created.'
		IF @Version = '2.0.2.2149' SET @Description = 'DB-231: Added ResultTypeBM = 2.'

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

	SET @Step = 'Get data of a Grid and Grid_Dimension'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 1,
					G.InstanceID,
					G.GridID,
					G.GridName,
					G.GridDescription,
					G.DataClassID,
					DC.DataClassName,
					G.GridSkinID,
					G.InheritedFrom
				FROM
					Grid G
					INNER JOIN DataClass DC ON DC.InstanceID = G.InstanceID AND DC.DataClassID = G.DataClassID
				WHERE
					G.InstanceID = @InstanceID AND
					(G.GridID = @GridID OR @GridID IS NULL)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get dimensions per Grid'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					ResultTypeBM = 2,
					GD.GridID,
					G.GridName,
					GD.DimensionID,
					D.DimensionName,
					GD.GridAxisID,
					GA.GridAxisName
				FROM
					Grid_Dimension GD
					LEFT JOIN Grid G ON G.GridID = GD.GridID
					LEFT JOIN Dimension D ON D.DimensionID = GD.DimensionID
					LEFT JOIN GridAxis GA ON GA.GridAxisID = GD.GridAxisID
				WHERE
					GD.InstanceID = @InstanceID AND
					(GD.GridID = @GridID OR @GridID IS NULL)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of GridAxis'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					ResultTypeBM = 4,
					GridAxisID,
					GridAxisName,
					GridAxisDescription
				FROM
					GridAxis
				WHERE
					InstanceID IN (0, @InstanceID)

				SET @Selected = @Selected + @@ROWCOUNT
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
