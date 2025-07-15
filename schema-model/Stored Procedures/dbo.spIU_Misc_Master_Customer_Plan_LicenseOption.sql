SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Misc_Master_Customer_Plan_LicenseOption]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	@SiteID int = NULL,
	@ProductKey nvarchar(17) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000685,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_Misc_Master_Customer_Plan_LicenseOption',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "0"},
		{"TKey" : "VersionID",  "TValue": "0"}
		]'

EXEC [spIU_Misc_Master_Customer_Plan_LicenseOption] @UserID=-10, @InstanceID=0, @VersionID=0, @DebugBM=3

EXEC [spIU_Misc_Master_Customer_Plan_LicenseOption] @GetVersion = 1
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
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update License info from the License portal',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

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

	SET @Step = 'Create temp table #Site'
		SELECT DISTINCT
			wLP.SiteID,
			wLP.ProductKey
		INTO
			#Site
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[wrk_LicensePortal] wLP
		WHERE
			(wLP.SiteID = @SiteID OR @SiteID IS NULL) AND
			(wLP.ProductKey = @ProductKey OR @ProductKey IS NULL)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Site', * FROM #Site ORDER BY [SiteID]

	SET @Step = 'Delete rows in table [Customer_Plan]'
		DELETE CP
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_Plan] CP
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C ON C.CustomerID = CP.CustomerID
			INNER JOIN #Site S ON S.[SiteID] = C.[SiteID] AND S.[ProductKey] = C.[ProductKey]

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Fill table [Customer_Plan]'
		INSERT INTO [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_Plan]
			(
			[CustomerID],
			[PlanID],
			[PurchaseDate],
			[Number],
			[ValidFromDate],
			[ValidToDate]
			)
		SELECT
			[CustomerID] = C.[CustomerID],
			[PlanID] = PPM.[PlanID],
			[PurchaseDate] = MIN(wLP.[PurchaseDate]),
			[Number] = SUM(wLP.[Quantity]),
			[ValidFromDate] = MIN(wLP.[PurchaseDate]),
			[ValidToDate] = '2020-12-31'
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[wrk_LicensePortal] wLP
			INNER JOIN #Site S ON S.[SiteID] = wLP.[SiteID] AND S.[ProductKey] = wLP.[ProductKey]
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C ON C.SiteID = wLP.SiteID AND C.ProductKey = wLP.ProductKey AND C.MainYN <> 0
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[ProductPackage_Mapping] PPM ON PPM.[ProductPackageID] = wLP.[ProductPackageID] AND PPM.PlanID IS NOT NULL
		WHERE
			NOT EXISTS (SELECT 1 FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_Plan] CP WHERE CP.[CustomerID] = C.[CustomerID] AND CP.[PlanID] = PPM.[PlanID])
		GROUP BY
			C.[CustomerID],
			PPM.[PlanID]
		ORDER BY
			C.[CustomerID]

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Delete rows in table [Customer_LicenseOption]'
		DELETE CLO
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_LicenseOption] CLO
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C ON C.CustomerID = CLO.CustomerID
			INNER JOIN #Site S ON S.[SiteID] = C.[SiteID] AND S.[ProductKey] = C.[ProductKey]

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Fill table [Customer_LicenseOption]'
		INSERT INTO [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_LicenseOption]
			(
			[CustomerID],
			[OptionID],
			[Number],
			[PurchaseDate],
			[ValidFromDate],
			[ValidToDate]
			)
		SELECT
			[CustomerID] = C.[CustomerID],
			[OptionID] = PPM.[OptionID],
			[Number] = CASE WHEN MAX(CONVERT(int, O.[AdditiveYN])) = 0 THEN MAX(wLP.[Quantity]) ELSE SUM(wLP.[Quantity]) END,
			[PurchaseDate] = MIN(wLP.[PurchaseDate]),
			[ValidFromDate] = MIN(wLP.[PurchaseDate]),
			[ValidToDate] = '2020-12-31'
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[wrk_LicensePortal] wLP
			INNER JOIN #Site S ON S.[SiteID] = wLP.[SiteID] AND S.[ProductKey] = wLP.[ProductKey]
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C ON C.SiteID = wLP.SiteID AND C.ProductKey = wLP.ProductKey AND C.MainYN <> 0
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[ProductPackage_Mapping] PPM ON PPM.[ProductPackageID] = wLP.[ProductPackageID] AND PPM.[OptionID] IS NOT NULL
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Option] O ON O.[OptionID] = PPM.[OptionID]
		WHERE
			NOT EXISTS (SELECT 1 FROM[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_LicenseOption] CLO WHERE CLO.[CustomerID] = C.[CustomerID] AND CLO.[OptionID] = PPM.[OptionID])
		GROUP BY
			C.[CustomerID],
			PPM.[OptionID]
		ORDER BY
			C.[CustomerID]

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0
			BEGIN
				SELECT
					[Table] = '[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_Plan]',
					CP.* 
				FROM
					[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_Plan] CP
					INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C ON C.CustomerID = CP.CustomerID
					INNER JOIN #Site S ON S.[SiteID] = C.[SiteID] AND S.[ProductKey] = C.[ProductKey]
				ORDER BY
					CP.[CustomerID],
					CP.[PlanID]

				SELECT
					[Table] = '[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_LicenseOption]',
					CLO.* 
				FROM
					[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_LicenseOption] CLO
					INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C ON C.CustomerID = CLO.CustomerID
					INNER JOIN #Site S ON S.[SiteID] = C.[SiteID] AND S.[ProductKey] = C.[ProductKey]
				ORDER BY
					CLO.[CustomerID],
					CLO.[OptionID]
			END

	SET @Step = 'Drop temp table'
		DROP TABLE #Site

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
