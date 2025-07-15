SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_InstanceList]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 7, --1 = InstanceList, 2 = Brand, 4 = CompanyType

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000371,
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
--**********************************************
--**********************************************
OBSOLETE! Replaced by [spPortalAdminGet_Instance]
--**********************************************
--**********************************************

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_InstanceList',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_InstanceList] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM = 7, @Debug=1

EXEC [spPortalAdminGet_InstanceList] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ToBeChanged nvarchar(255) = 'Change source in the return query to views in pcINTEGRATOR when the user views follow standard. Handling of multiple versions/applications must be implemented.',

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
	@Version nvarchar(50) = '2.0.2.2149'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return Instance info',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Deleted reference of column StepXML on table [Instance].'
		IF @Version = '2.0.2.2146' SET @Description = 'EFP-939: Added CompanyTypeID, CompanyTypeName, AllowExternalAccessYN'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-118: There are no any instances with companyTypeId PARTNER(1) or CUSTOMER(2) instances'
		IF @Version = '2.0.2.2148' SET @Description = 'Added [InstanceName] on Partner Instances.'
		IF @Version = '2.0.2.2149' SET @Description = 'Corrected [InstanceName] for EnvironmentLevel = 0 (Prod).'

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

	SET @Step = 'Return Instance info'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					ResultTypeBM = 1,
					I.[InstanceID],
					[InstanceName] = ISNULL(A.[ApplicationName], I.InstanceName) + CASE WHEN C.CompanyTypeID = 1 THEN ' (Partner Instance)' ELSE '' END,
					I.[InstanceDescription],
					I.[CustomerID],
					C.CompanyTypeID,
					CT.CompanyTypeName,
					I.[FiscalYearStartMonth],
					I.[FiscalYearNaming],
					I.[ProductKey],
					I.[pcPortal_URL],
					I.[Mail_ProfileName],
					I.[Rows],
					I.[Nyc],
					I.[Nyu],
					I.[BrandID],
					I.AllowExternalAccessYN,
					I.[TriggerActiveYN],
					I.[LastLogin],
					I.[LastLoginByUserID],
					I.[InheritedFrom],
					I.[SelectYN],
					I.[Version],
					[LastLoginByUserName] = ISNULL(U.UserName, TU.UserName)
				FROM
					pcINTEGRATOR_Data..[Instance] I
					INNER JOIN pcINTEGRATOR_Data..[Customer] C ON C.CustomerID = I.CustomerID
					INNER JOIN CompanyType CT ON CT.CompanyTypeID = C.CompanyTypeID
					LEFT JOIN pcINTEGRATOR_Data..[User] U ON U.UserID = I.LastLoginByUserId 
					LEFT JOIN pcINTEGRATOR..[@Template_User] TU ON TU.UserID = I.LastLoginByUserId
					LEFT JOIN (
								SELECT 
									A.InstanceID, [ApplicationName] = MAX([ApplicationName]) 
								FROM 
									pcINTEGRATOR_Data..[Application] A
									INNER JOIN pcINTEGRATOR_Data..[Version] V ON V.InstanceID = A.InstanceID AND V.VersionID = A.VersionID AND V.EnvironmentLevelID = 0
								GROUP BY 
									A.InstanceID
								) A ON A.InstanceID = I.InstanceID
				WHERE
					I.[SelectYN] <> 0
				ORDER BY
					I.InstanceName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return Brand info'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 2,
					BrandID,
					ProductName,
					LongName,
					OrgBrand
				FROM
					(
						  SELECT BrandID = 0, ProductName = 'Blank',		LongName = 'Generic',							OrgBrand = 'DSPanel'
					UNION SELECT BrandID = 1, ProductName = 'pcFinancials', LongName = 'Performance Canvas pcFinancials',	OrgBrand = 'DSPanel'
					UNION SELECT BrandID = 2, ProductName = 'EFP',          LongName = 'Epicor Financial Planner',			OrgBrand = 'Epicor'
					UNION SELECT BrandID = 3, ProductName = 'pcFinancials', LongName = 'Performance Canvas pcFinancials',	OrgBrand = 'deFacto'
					) sub

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return CompanyType info'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 4,
					CompanyTypeID,
					CompanyTypeName,
					CompanyTypeDescription
				FROM
					CompanyType

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
