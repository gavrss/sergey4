SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Instance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@AssignedInstanceID int = NULL,
	@AssignedCustomerID int = NULL,
	@ResultTypeBM int = 63,
		--  1 = Properties for assigned instance
		--  2 = Customer
		--  4 = StartYear
		--  8 = EndYear
		-- 16 = FiscalYearStartMonth
		-- 32 = FiscalYearNaming
		-- 64 = Instances possible for Setup
		--128 = Brand
		--256 = CompanyType

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000541,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spPortalAdminGet_Instance] @InstanceID=N'0',@ResultTypeBM=N'3',@UserID=N'-10',@VersionID=N'0',@DebugBM='15'
,@AssignedCustomerID=617
,@AssignedInstanceID=741

EXEC [spPortalAdminGet_Instance] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedInstanceID = 1, @Debug=1
EXEC [spPortalAdminGet_Instance] @UserID=0, @InstanceID=0, @VersionID=0, @ResultTypeBM = 2
EXEC [spPortalAdminGet_Instance] @UserID=0, @InstanceID=0, @VersionID=0, @AssignedInstanceID = 52, @ResultTypeBM = 2
EXEC [spPortalAdminGet_Instance] @UserID=0, @InstanceID=0, @VersionID=0, @ResultTypeBM = 256

EXEC [spPortalAdminGet_Instance] @GetVersion = 1
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
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get properties for Assigned Instance and values for listboxes.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2152' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Include all functionality from [spPortalAdminGet_InstanceList].'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-475: Added [InstanceShortName] column for @ResultTypeBM = 1.'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-2939: Updated to lates SP template. Added parameter @AssignedCustomerID.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create table #Digit'
		IF @ResultTypeBM & 28 > 0
			BEGIN
				CREATE TABLE #Digit
					(
					Number int
					)

				INSERT INTO #Digit
					(
					Number
					)
				SELECT Number = 0 UNION
				SELECT Number = 1 UNION
				SELECT Number = 2 UNION
				SELECT Number = 3 UNION
				SELECT Number = 4 UNION
				SELECT Number = 5 UNION
				SELECT Number = 6 UNION
				SELECT Number = 7 UNION
				SELECT Number = 8 UNION
				SELECT Number = 9
			END

	SET @Step = 'Return Instance info'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					ResultTypeBM = 1,
					I.[InstanceID],
					[InstanceName] = ISNULL(A.[ApplicationName], I.InstanceName) + CASE WHEN C.CompanyTypeID = 1 THEN ' (Partner Instance)' ELSE '' END,
--					I.[InstanceName],
					I.[InstanceDescription],
					I.[InstanceShortName],
					I.[CustomerID],
					C.CompanyTypeID,
					CT.CompanyTypeName,
					I.[StartYear],
					[EndYear] = YEAR(GETDATE()) + I.[AddYear],
					I.[FiscalYearStartMonth],
					I.[FiscalYearNaming],
--					C.[ProductKey],
					I.[pcPortal_URL],
					I.[Mail_ProfileName],
--					I.[Rows],
--					I.[Nyc],
--					I.[Nyu],
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
					INNER JOIN pcINTEGRATOR_Data..[Customer] C ON C.CustomerID = I.CustomerID AND (C.CustomerID = @AssignedCustomerID OR @AssignedCustomerID IS NULL)
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
					(I.InstanceID = @AssignedInstanceID OR @AssignedInstanceID IS NULL) AND
					I.[SelectYN] <> 0
				ORDER BY
					I.InstanceName


				--	LEFT JOIN pcINTEGRATOR_Data..[User] U ON U.UserID = I.LastLoginByUserId 
				--	LEFT JOIN pcINTEGRATOR..[@Template_User] TU ON TU.UserID = I.LastLoginByUserId
				--	LEFT JOIN (
				--				SELECT 
				--					A.InstanceID, [ApplicationName] = MAX([ApplicationName]) 
				--				FROM 
				--					pcINTEGRATOR_Data..[Application] A
				--					INNER JOIN pcINTEGRATOR_Data..[Version] V ON V.InstanceID = A.InstanceID AND V.VersionID = A.VersionID AND V.EnvironmentLevelID = 0
				--				GROUP BY 
				--					A.InstanceID
				--				) A ON A.InstanceID = I.InstanceID
				--WHERE
				--	I.[SelectYN] <> 0
				--ORDER BY
				--	I.InstanceName



				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of customers'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT DISTINCT
					[ResultTypeBM] = 2,
					[CustomerID] = C.[CustomerID],
					[CustomerName] = C.[CustomerName],
					[CompanyType] = CT.[CompanyTypeName],
					[ProductKey] = C.[ProductKey]
				FROM
					pcINTEGRATOR_Data..[Customer] C
					INNER JOIN CompanyType CT ON CT.[CompanyTypeID] = C.[CompanyTypeID]
					INNER JOIN [Instance] I ON I.[CustomerID] = C.[CustomerID] AND (I.[InstanceID] = @AssignedInstanceID OR @AssignedInstanceID IS NULL)
				WHERE
					C.CustomerID = @AssignedCustomerID or @AssignedCustomerID IS NULL
				ORDER BY
					C.[CustomerName]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of StartYears'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					[StartYear] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1
				FROM
					#Digit D1,
					#Digit D2,
					#Digit D3,
					#Digit D4
				WHERE
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN YEAR(GetDate()) - 25 AND YEAR(GetDate()) + 1
				ORDER BY
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of EndYears'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 8,
					[EndYear] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1
				FROM
					#Digit D1,
					#Digit D2,
					#Digit D3,
					#Digit D4
				WHERE
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN YEAR(GetDate()) AND YEAR(GetDate()) + 10
				ORDER BY
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of FiscalYearStartMonth'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 16,
					[FiscalYearStartMonth] = D2.Number * 10 + D1.Number + 1,
					[Description] = DATENAME(month, CONVERT(smalldatetime, '2000-' + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1) + '-01'))
				FROM
					#Digit D1,
					#Digit D2
				WHERE
					D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
				ORDER BY
					D2.Number * 10 + D1.Number + 1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of FiscalYearNaming'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 32,
					[FiscalYearNaming] = sub.[FiscalYearNaming],
					[Description] = sub.[Description]
				FROM
					(
					SELECT
						[FiscalYearNaming] = 0,
						[Description] = 'Opening month'
					UNION SELECT
						[FiscalYearNaming] = 1,
						[Description] = 'Closing month'
					) sub
				ORDER BY
					sub.[FiscalYearNaming]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Instances possible for Setup'
		IF @ResultTypeBM & 64 > 0
			BEGIN
				SET ANSI_WARNINGS ON

				SELECT
					[ResultTypeBM] = 64,
					[InstanceID] = I.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[CompanyType] = CT.[CompanyTypeName]
				FROM
					DSPMASTER.pcINTEGRATOR_Master.dbo.Instance I
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.Customer C ON C.[CustomerID] = I.[CustomerID] AND C.MainYN <> 0
					INNER JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.CompanyType CT ON CT.[CompanyTypeID] = C.[CompanyTypeID]
				WHERE
					I.SelectYN <> 0 AND
					(NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Instance D WHERE D.InstanceID = I.InstanceID) OR C.[CompanyTypeID] = 1) AND
					NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..[Version] V WHERE V.InstanceID = I.InstanceID)
				ORDER BY
					I.[InstanceName]

				SET @Selected = @Selected + @@ROWCOUNT

				SET ANSI_WARNINGS OFF
			END

	SET @Step = 'Return Brand info'
		IF @ResultTypeBM & 128 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 128,
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
		IF @ResultTypeBM & 256 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 256,
					CompanyTypeID,
					CompanyTypeName,
					CompanyTypeDescription
				FROM
					CompanyType

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp table'
		IF @ResultTypeBM & 28 > 0 DROP TABLE #Digit

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
