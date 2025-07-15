SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Misc_Master_Instance_ProductOption]
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	@AssignedInstanceID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000686,
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
	@ProcedureName = 'spIU_Misc_Master_Instance_ProductOption',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "0"},
		{"TKey" : "VersionID",  "TValue": "0"}
		]'

EXEC [spIU_Misc_Master_Instance_ProductOption] @UserID=-10, @InstanceID=0, @VersionID=0, @DebugBM=3

EXEC [spIU_Misc_Master_Instance_ProductOption] @GetVersion = 1
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
			@ProcedureDescription = 'Calculate Instance_ProductOption based on license info.',
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

	SET @Step = 'Create temp table #Instance_ProductOption'
		CREATE TABLE #Instance_ProductOption
			(
			[InstanceID] int,
			[OptionID] int,
			[Number] int,
			[SelectYN] int
			)

	SET @Step = 'Insert number of Users into temp table #Instance_ProductOption'
		INSERT INTO #Instance_ProductOption
			(
			[InstanceID],
			[OptionID],
			[Number],
			[SelectYN]
			)
		SELECT 
			[InstanceID] = I.[InstanceID],
			[OptionID] = O.[OptionID],
			[Number] = SUM(CP.[Number]),
			[SelectYN] = CASE WHEN MAX(CONVERT(int, O.[SelectableYN])) = 0 THEN 1 ELSE 0 END
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_Plan] CP ON CP.[CustomerID] = I.[CustomerID] AND GetDate() BETWEEN CP.[ValidFromDate] AND CP.[ValidToDate]
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Option] O ON O.[OptionID] = 301
		WHERE
			(I.[InstanceID] = @AssignedInstanceID OR @AssignedInstanceID IS NULL) AND
			I.[SelectYN] <> 0
		GROUP BY
			I.[InstanceID],
			O.[OptionID]

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Insert all Plan Options into temp table #Instance_ProductOption'
		INSERT INTO #Instance_ProductOption
			(
			[InstanceID],
			[OptionID],
			[Number],
			[SelectYN]
			)
		SELECT 
			[InstanceID] = I.[InstanceID],
			[OptionID] = O.[OptionID],
			[Number] = CASE WHEN MAX(CONVERT(int, O.[AdditiveYN])) = 0 THEN MAX(LOPO.[Number]) ELSE SUM(LOPO.[Number]) END,
			[SelectYN] = CASE WHEN MAX(CONVERT(int, O.[SelectableYN])) = 0 THEN 1 ELSE 0 END
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_Plan] CP ON CP.[CustomerID] = I.[CustomerID] AND GetDate() BETWEEN CP.[ValidFromDate] AND CP.[ValidToDate]
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[LicenseOption_ProductOption] LOPO ON LOPO.[PlanID] = CP.[PlanID] AND LOPO.[LicenseOptionID] = 1
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Option] O ON O.[OptionID] = LOPO.[ProductOptionID]
		WHERE
			(I.[InstanceID] = @AssignedInstanceID OR @AssignedInstanceID IS NULL) AND
			I.[SelectYN] <> 0
		GROUP BY
			I.[InstanceID],
			O.[OptionID]

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Insert all other ProductOptions into temp table #Instance_ProductOption'
		INSERT INTO #Instance_ProductOption
			(
			[InstanceID],
			[OptionID],
			[Number],
			[SelectYN]
			)
		SELECT 
			[InstanceID] = I.[InstanceID],
			[OptionID] = O.[OptionID],
			[Number] = CASE WHEN MAX(CONVERT(int, O.[AdditiveYN])) = 0 THEN MAX(LOPO.[Number]) ELSE SUM(CLO.[Number] * LOPO.[Number]) END,
			[SelectYN] = CASE WHEN MAX(CONVERT(int, O.[SelectableYN])) = 0 THEN 1 ELSE 0 END
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_Plan] CP ON CP.[CustomerID] = I.[CustomerID] AND GetDate() BETWEEN CP.[ValidFromDate] AND CP.[ValidToDate]
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer_LicenseOption] CLO ON CLO.[CustomerID] = I.[CustomerID] AND GetDate() BETWEEN CLO.[ValidFromDate] AND CLO.[ValidToDate]
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[LicenseOption_ProductOption] LOPO ON LOPO.[PlanID] = CP.[PlanID] AND LOPO.[LicenseOptionID] = CLO.[OptionID]
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Option] O ON O.[OptionID] = LOPO.[ProductOptionID]
		WHERE
			(I.[InstanceID] = @AssignedInstanceID OR @AssignedInstanceID IS NULL) AND
			I.[SelectYN] <> 0
		GROUP BY
			I.[InstanceID],
			O.[OptionID]

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Update [Instance_ProductOption]'
		UPDATE DIPO
		SET
			[Number] = IPO.[Number]
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance_ProductOption] DIPO
			INNER JOIN
				(
				SELECT 
					[InstanceID] = IPO.[InstanceID],
					[OptionID] = IPO.[OptionID],
					[Number] = CASE WHEN MAX(CONVERT(int, O.[AdditiveYN])) = 0 THEN MAX(IPO.[Number]) ELSE SUM(IPO.[Number]) END
				FROM
					#Instance_ProductOption IPO
					INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Option] O ON O.[OptionID] = IPO.[OptionID]
				GROUP BY
					IPO.[InstanceID],
					IPO.[OptionID]
				) IPO ON IPO.[InstanceID] = DIPO.[InstanceID] AND IPO.[OptionID] = DIPO.[OptionID] AND IPO.[Number] <> DIPO.[Number]

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert into [Instance_ProductOption]'
		INSERT INTO [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance_ProductOption]
			(
			[InstanceID],
			[OptionID],
			[Number],
			[SelectYN]
			)
		SELECT 
			[InstanceID] = IPO.[InstanceID],
			[OptionID] = IPO.[OptionID],
			[Number] = CASE WHEN MAX(CONVERT(int, O.[AdditiveYN])) = 0 THEN MAX(IPO.[Number]) ELSE SUM(IPO.[Number]) END,
			[SelectYN] = MAX(IPO.[SelectYN])
		FROM
			#Instance_ProductOption IPO
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Option] O ON O.[OptionID] = IPO.[OptionID]
		WHERE
			NOT EXISTS (SELECT 1 FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance_ProductOption] DIPO WHERE DIPO.[InstanceID] = IPO.[InstanceID] AND DIPO.[OptionID] = IPO.[OptionID])
		GROUP BY
			IPO.[InstanceID],
			IPO.[OptionID]

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0
			BEGIN
				SELECT
					[Table] = '[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance_ProductOption]',
					IPO.[InstanceID],
					I.[InstanceName],
					IPO.[OptionID],
					O.[OptionName],
					IPO.[Number],
					IPO.[SelectYN],
					IPO.[Updated]
				FROM
					[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance_ProductOption] IPO
					INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I ON I.[InstanceID] = IPO.[InstanceID]
					INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Option] O ON O.[OptionID] = IPO.[OptionID]
				WHERE
					(IPO.[InstanceID] = @AssignedInstanceID OR @AssignedInstanceID IS NULL)
				ORDER BY
					IPO.[InstanceID],
					O.[SortOrder]
			END

	SET @Step = 'Drop temp table'
		DROP TABLE #Instance_ProductOption

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
