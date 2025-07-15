SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Plan_Master]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@PlanID int = NULL,
	@PlanTypeID int = NULL,
	@OptionID int = NULL,
	@ResultTypeBM int = 15,
		-- 1 = Plan
		-- 2 = Option
		-- 4 = PlanType
		-- 8 = Plan_Option
	@OptionTypeBM int = 3,
		-- 1 = License option
		-- 2 = Product option

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000561,
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
EXEC [spPortalAdminGet_Plan_Master] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spPortalAdminGet_Plan_Master] @UserID=0, @InstanceID=0, @VersionID=0, @PlanTypeID = 1100, @ResultTypeBM = 15, @OptionTypeBM = 1
EXEC [spPortalAdminGet_Plan_Master] @UserID=0, @InstanceID=0, @VersionID=0, @OptionID=101, @PlanTypeID = 1100, @ResultTypeBM = 15

EXEC [spPortalAdminGet_Plan_Master] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables

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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get properties for Plans/Options and values for listboxes.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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

	SET @Step = 'Return Plan info'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 1,
					*
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.[Plan]
				WHERE
					(PlanID = @PlanID OR @PlanID IS NULL) AND
					(PlanTypeID = @PlanTypeID OR @PlanTypeID IS NULL)
				ORDER BY
					PlanTypeID,
					PlanID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of Options'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 2,
					*
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.[Option]
				WHERE
					(OptionID = @OptionID OR @OptionID IS NULL) AND
					OptionTypeBM & @OptionTypeBM > 0
				ORDER BY
					[OptionID]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of PlanTypes'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					*
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.[PlanType]
				WHERE
					(PlanTypeID = @PlanTypeID OR @PlanTypeID IS NULL)
				ORDER BY
					[PlanTypeID]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of Valid_Plan_LicenseOption'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 8,
					VPLO.*
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.[Valid_Plan_LicenseOption] VPLO
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Plan] P ON P.PlanID = VPLO.PlanID AND (P.PlanTypeID = @PlanTypeID OR @PlanTypeID IS NULL)
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Option] O ON O.OptionID = VPLO.OptionID AND O.OptionTypeBM & @OptionTypeBM > 0 AND O.OptionID <> 1
				WHERE
					(VPLO.PlanID = @PlanID OR @PlanID IS NULL) AND
					(VPLO.OptionID = @OptionID OR @OptionID IS NULL)
				ORDER BY
					VPLO.[PlanID],
					VPLO.[OptionID]

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
