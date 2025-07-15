SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Instance_Master]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@AssignedCustomerID int = NULL,
	@AssignedInstanceID int = NULL,
	@ResultTypeBM int = 255,
		--   1 = Properties for assigned instance
		--   2 = Customer
		--   4 = CompanyType
		--   8 = Brand
		--  16 = Plan
		--  32 = LicenseOption
		--  64 = ProductOption
		-- 128 = Servers installed
		-- 256 = Valid license options
		-- 512 = Source table names @ResultTypeBM= 64 + [pcINTEGRATOR].[dbo].[ProductOption] + [pcINTEGRATOR].[dbo].[SourceTable]
		--1024 = List of available features @ResultTypeBM= 64 + [pcINTEGRATOR].[dbo].[ProductOption] (16384)

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000560,
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
EXEC [spPortalAdminGet_Instance_Master] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedCustomerID = 1, @AssignedInstanceID = 1, @Debug=1
EXEC [spPortalAdminGet_Instance_Master] @UserID=0, @InstanceID=0, @VersionID=0, @ResultTypeBM = 1
EXEC [spPortalAdminGet_Instance_Master] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedInstanceID = 454, @ResultTypeBM=511

EXEC [spPortalAdminGet_Instance_Master] @GetVersion = 1
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
	@Version nvarchar(50) = '2.1.0.2156'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get properties for Assigned Customer/Instance and values for listboxes.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2156' SET @Description = 'More resulttypes prepared.'

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

	SET @Step = 'Return Instance info'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 1,
					I.[InstanceID],
					I.[InstanceName],
					I.[InstanceShortName],
					I.[InstanceDescription],
					I.[CustomerID],
					I.[BrandID],
					[Inserted] = [Created],
					[InsertedBy] = [CreatedBy],
					I.[SelectYN],
					I.[Version]
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.[Instance] I
				WHERE
					(I.InstanceID = @AssignedInstanceID OR @AssignedInstanceID IS NULL) AND
					(I.CustomerID = @AssignedCustomerID OR @AssignedCustomerID IS NULL)
				ORDER BY
					I.InstanceID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of customers'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 2,
					[CustomerID] = C.[CustomerID],
					[CustomerName] = C.[CustomerName],
					[CompanyType] = C.[CompanyTypeID],
					[SiteID] = C.[SiteID],
					[ProductKey] = C.[ProductKey],
					[Inserted] = C.[Created],
					[InsertedBy] = C.[CreatedBy],
					[Version] = C.[Version]
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.Customer C
				WHERE
					(C.CustomerID = @AssignedCustomerID OR @AssignedCustomerID IS NULL)
				ORDER BY
					C.[CustomerName]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of CompanyTypes'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					CompanyTypeID,
					CompanyTypeName,
					CompanyTypeDescription
				FROM
					CompanyType
				ORDER BY
					CompanyTypeName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of Brands'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 8,
					[BrandID],
					[BrandName],
					[BrandDescription],
					[BrandLabel]
				FROM
					[Brand]
				WHERE
					SelectYN <> 0

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return Customer_Plan'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 16,
					C.CustomerID,
					C.CustomerName,
					P.PlanID,
					P.PlanName,
					P.PlanDescription,
					P.PlanDate,
					PT.PlanTypeName,
					PT.PlanTypeDescription,
					CP.Number,
					PT.UOM,
					CP.PurchaseDate,
					CP.ValidFromDate,
					CP.ValidToDate
				FROM
					pcINTEGRATOR_Data..Instance I
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Customer] C ON C.CustomerID = I.CustomerID
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Customer_Plan] CP ON CP.CustomerID = I.CustomerID
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Plan] P ON P.PlanID = CP.PlanID
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[PlanType] PT ON PT.PlanTypeID = P.PlanTypeID
				WHERE
					I.InstanceID = @AssignedInstanceID
				ORDER BY
					P.PlanID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return Customer_LicenseOption'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 32,
					C.CustomerID,
					C.CustomerName,
					O.OptionID,
					O.OptionName,
					O.OptionDescription,
					CLO.Number,
					O.UOM,
					CLO.PurchaseDate,
					CLO.ValidFromDate,
					CLO.ValidToDate
				FROM
					pcINTEGRATOR_Data..Instance I
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Customer] C ON C.CustomerID = I.CustomerID
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Customer_LicenseOption] CLO ON CLO.CustomerID = I.CustomerID 
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Option] O ON O.OptionID = CLO.OptionID
				WHERE
					I.InstanceID = @AssignedInstanceID
				ORDER BY
					CLO.OptionID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return Instance_ProductOption'
		IF @ResultTypeBM & 64 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 64,
					I.InstanceID,
					I.OptionID,
					O.OptionName,
					I.Number,
					I.[SelectYN],
					I.Updated
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.[Instance_ProductOption] I
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Option] O ON O.OptionID = I.OptionID
				WHERE
					I.InstanceID = @AssignedInstanceID
				ORDER BY
					I.OptionID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Instance installed on servers'
		IF @ResultTypeBM & 128 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 128,
					I.InstanceID,
					I.ServerName,
					I.Inserted
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.[Instance_Server] I
				WHERE
					I.InstanceID = @AssignedInstanceID
				ORDER BY
					I.ServerName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of valid Licence Options'
		IF @ResultTypeBM & 256 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 256,
					O.[OptionID],
					O.[OptionName],
					O.[OptionDescription],
					O.[OptionTypeBM],
					[OptionMin] = CASE WHEN VPLO.[OptionMin] >= O.[OptionMin] THEN VPLO.[OptionMin] ELSE O.[OptionMin] END,
					[OptionMax] = CASE WHEN VPLO.[OptionMax] <= O.[OptionMax] THEN VPLO.[OptionMax] ELSE O.[OptionMax] END,
					O.[UOM]
				FROM
					pcINTEGRATOR_Data..Instance I
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Customer_Plan] CP ON CP.CustomerID = I.CustomerID
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Valid_Plan_LicenseOption] VPLO ON VPLO.PlanID = [CP].PlanID
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[Option] O ON O.OptionID = VPLO.OptionID AND O.OptionTypeBM & 1 > 0 AND O.OptionID <> 1
				WHERE
					[I].InstanceID = @AssignedInstanceID
				ORDER BY
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
