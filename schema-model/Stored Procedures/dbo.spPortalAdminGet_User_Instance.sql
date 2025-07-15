SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_User_Instance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignedUserID int = NULL,
	@AssignedInstanceID int = NULL,
	@ResultTypeBM int = 1,
		-- 1 = List of Assigned Instances for a specified User
		-- 2 = List of Instances
		-- 4 = List of Default Groups of selected Instance

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000368,
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
	@ProcedureName = 'spPortalAdminGet_User_Instance',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spRun_Procedure_KeyValuePair]
	@ProcedureName='spPortalAdminGet_User_Instance',
	@JSON='
		[
		{"TKey":"InstanceID","TValue":"0"},
		{"TKey":"AssignedInstanceID","TValue":"390"},
		{"TKey":"UserID","TValue":"-10"},
		{"TKey":"VersionID","TValue":"0"},
		{"TKey":"ResultTypeBM","TValue":"4"}
		]'

EXEC [spPortalAdminGet_User_Instance] @UserID=-10, @InstanceID=0, @VersionID=0, @AssignedInstanceID=390, @ResultTypeBM=4
EXEC [spPortalAdminGet_User_Instance] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID=6566
EXEC [spPortalAdminGet_User_Instance] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID=6566, @AssignedInstanceID=-1306, @ResultTypeBM=7, @Debug=1
EXEC [spPortalAdminGet_User_Instance] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID=6327, @AssignedInstanceID=-1316, @ResultTypeBM=7, @Debug=1
EXEC [spPortalAdminGet_User_Instance] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID=6566, @ResultTypeBM=7

EXEC [spPortalAdminGet_User_Instance] @GetVersion = 1
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
	@Version nvarchar(50) = '2.0.3.2151'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of Assigned Instances for specified User',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Added @ResultTypeBM for different result lists.'
		IF @Version = '2.0.2.2146' SET @Description = 'Removed parameter @AssignedUserID from list of mandatory parameters. EFP-939: Added CompanyTypeID, CompanyTypeName, AllowExternalAccessYN'
		IF @Version = '2.0.3.2151' SET @Description = 'Update User info for Partner Users.'


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

		IF @Debug <> 0
			SELECT [@AssignedUserID] = @AssignedUserID, [@AssignedInstanceID] = @AssignedInstanceID

	SET @Step = 'Update user tables for partner users'
		SET ANSI_NULLS ON; SET ANSI_WARNINGS ON; EXEC [spGet_PartnerUser] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID
		SET ANSI_WARNINGS OFF

	SET @Step = 'Create temp table #AssignedInstances'
		CREATE TABLE #AssignedInstances
			(
			InstanceID int,
			InstanceName nvarchar(50),
			InstanceDescription nvarchar(255),
			ExpiryDate date,
			MasterYN bit,
			CustomerID int,
			AllowExternalAccessYN bit,
			LoginEnabledYN bit
			)

	SET @Step = 'Insert data into temp table #AssignedInstances'
		INSERT INTO #AssignedInstances
			(
			InstanceID,
			InstanceName,
			InstanceDescription,
			ExpiryDate,
			MasterYN,
			CustomerID,
			AllowExternalAccessYN,
			LoginEnabledYN
			)
		SELECT
			U.InstanceID,
			I.InstanceName,
			I.InstanceDescription,
			ExpiryDate = NULL,
			MasterYN = 1,
			I.CustomerID,
			I.AllowExternalAccessYN,
			U.LoginEnabledYN
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID
		WHERE
			U.UserID = @AssignedUserID AND
			U.SelectYN <> 0 AND
			U.DeletedID IS NULL
		UNION 
		SELECT
			UI.InstanceID,
			I.InstanceName,
			I.InstanceDescription,
			UI.ExpiryDate,
			MasterYN = 0,
			I.CustomerID,
			I.AllowExternalAccessYN,
			UI.LoginEnabledYN
		FROM
			[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
			LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.[InstanceID] = UI.InstanceID
		WHERE
			UI.UserID = @AssignedUserID AND
			UI.SelectYN <> 0 AND
			UI.DeletedID IS NULL
		ORDER BY
			MasterYN DESC,
			InstanceID

		IF @Debug <> 0
			SELECT [TempTable] = '#AssignedInstances', * FROM #AssignedInstances

	SET @Step = 'Get list of Assigned Instances for specified User'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					ResultTypeBM = 1,
					InstanceID,
					InstanceName,
					InstanceDescription,
					ExpiryDate,
					MasterYN,
					C.CompanyTypeID,
					CT.CompanyTypeName,
					AI.AllowExternalAccessYN,
					AI.LoginEnabledYN
				FROM
					#AssignedInstances AI
					INNER JOIN pcINTEGRATOR_Data..[Customer] C ON C.CustomerID = AI.CustomerID
					INNER JOIN CompanyType CT ON CT.CompanyTypeID = C.CompanyTypeID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of available Instances'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					ResultTypeBM = 2,
					InstanceID,
					InstanceName,
					InstanceDescription
--					C.CompanyTypeID,
--					CT.CompanyTypeName,
--					I.AllowExternalAccessYN
				FROM 
					[pcINTEGRATOR_Data].[dbo].[Instance] I
					INNER JOIN pcINTEGRATOR_Data..[Customer] C ON C.CustomerID = I.CustomerID AND C.CompanyTypeID = 2
--					INNER JOIN CompanyType CT ON CT.CompanyTypeID = C.CompanyTypeID
				WHERE
					I.SelectYN <> 0 AND
					I.AllowExternalAccessYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM #AssignedInstances AI WHERE AI.InstanceID = I.InstanceID)
					
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get List of Default Groups of selected Instance'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					ResultTypeBM = 4,
					InstanceID,
					UserID,
					UserName,
					UserNameDisplay,
					UserTypeID
				FROM 
					[pcINTEGRATOR_Data].[dbo].[User]
				WHERE
					InstanceID = @AssignedInstanceID AND
					UserTypeID = -2 AND
					SelectYN <> 0 AND
					DeletedID IS NULL

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp table'
		DROP TABLE #AssignedInstances

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
