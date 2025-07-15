SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_ActingAs]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 1,
	@ActingAsID int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000627,
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
EXEC [spPortalGet_ActingAs] @UserID=2151, @InstanceID=413, @VersionID=1008, @Debug=1

EXEC [spPortalGet_ActingAs] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'List of possible OrganizationPositions to act as',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2168' SET @Description = 'DB-620: For @ResultTypeBM = 1, return separate columns for OrganizationPositionName, OrganizationHierarchyName, OrganizationLevelNo and DelegateYN. Added DeletedID IS NULL filter on [OrganizationPosition].'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create table #ActingAs'
		CREATE TABLE #ActingAs
			(
			ActingAsID int,
			ActingAsName nvarchar(255) COLLATE DATABASE_DEFAULT,
			OrganizationPositionName nvarchar(100) COLLATE DATABASE_DEFAULT,
			OrganizationHierarchyName nvarchar(50) COLLATE DATABASE_DEFAULT,
			OrganizationLevelNo int,
			DelegateYN bit,
			SortOrder int IDENTITY(1,1)
			)

		INSERT INTO #ActingAs
			(
			ActingAsID,
			ActingAsName,
			OrganizationPositionName,
			OrganizationHierarchyName,
			OrganizationLevelNo,
			DelegateYN
			)
		SELECT
			ActingAsID,
			ActingAsName,
			OrganizationPositionName,
			OrganizationHierarchyName,
			OrganizationLevelNo,
			DelegateYN
		FROM
			(
			SELECT
				ActingAsID = OP.OrganizationPositionID,
				ActingAsName = MAX(OH.OrganizationHierarchyName + ', ' + OP.OrganizationPositionName + CASE WHEN OPU.DelegateYN <> 0 THEN ' (' +  U.UserNameDisplay + ')' ELSE '' END + ' {' + CONVERT(nvarchar(15), OP.OrganizationLevelNo) + '}'),
				OrganizationPositionName = MAX(OP.OrganizationPositionName),
				OrganizationHierarchyName = MAX(OH.OrganizationHierarchyName),
				OrganizationLevelNo = MAX(OP.OrganizationLevelNo),
				OrganizationHierarchyID = MAX(OH.OrganizationHierarchyID),
				DelegateYN = OPU.DelegateYN
			FROM 
				pcINTEGRATOR_Data..OrganizationPosition OP
				INNER JOIN pcINTEGRATOR_Data..OrganizationPosition_User OPU ON OPU.InstanceID = OP.InstanceID AND OPU.VersionID = OP.VersionID AND OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.UserID = @UserID
				INNER JOIN pcINTEGRATOR_Data..OrganizationHierarchy OH ON OH.InstanceID = OP.InstanceID AND OH.VersionID = OP.VersionID AND OH.OrganizationHierarchyID = OP.OrganizationHierarchyID AND OH.DeletedID IS NULL
				LEFT JOIN pcINTEGRATOR_Data..OrganizationPosition_User OPUD ON OPUD.InstanceID = OP.InstanceID AND OPUD.VersionID = OP.VersionID AND OPUD.OrganizationPositionID = OP.OrganizationPositionID AND OPUD.DelegateYN = 0
				LEFT JOIN pcINTEGRATOR_Data..[User] U ON U.UserID = OPUD.UserID
			WHERE
				OP.InstanceID = @InstanceID AND
				OP.VersionID = @VersionID AND
				OP.DeletedID IS NULL
			GROUP BY
				OP.OrganizationPositionID,
				OPU.DelegateYN
			) sub
		ORDER BY
			sub.OrganizationHierarchyID DESC,
			sub.OrganizationLevelNo,
			sub.OrganizationPositionName

	SET @Step = 'Set @ActingAsID'
		SELECT TOP 1
			@ActingAsID = ActingAsID
		FROM
			#ActingAs

	SET @Step = 'Get list of OrganizationPositions'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					ResultTypeBM = 1,
					ActingAsID,
					ActingAsName,
					OrganizationPositionName,
					OrganizationHierarchyName,
					OrganizationLevelNo,
					DelegateYN,
					DefaultYN = CASE WHEN SortOrder = 1 THEN 1 ELSE 0 END
				FROM
					#ActingAs
				ORDER BY
					SortOrder
			END

	SET @Step = 'Drop temp table'
		DROP TABLE #ActingAs

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
