SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Get_Usage]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000866,
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
EXEC [sp_Tool_Get_Usage] @GetVersion = 1
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
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get usage of Callisto and pcPortal',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2191' SET @Description = 'Procedure created.'

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

	SET @Step = 'Return result'
		SELECT
			sub.InstanceID, 
			I.InstanceName,
			sub.ApplicationName,
			C.SiteID,
			[Type] = CT.CompanyTypeName,
			LastPortalUsage = JL.LastUse,
			NoOfPortalCalls = JL.NoOfCalls,
			sub.CallistoLogons, 
			sub.FirstCallistoLogon,
			sub.LastCallistoLogon,
			[Server] = @@SERVERNAME 
		FROM
			(
			SELECT
				U.InstanceID, 
				A.ApplicationName,
				CallistoLogons = COUNT(1), 
				FirstCallistoLogon = MIN(LogonTime),
				LastCallistoLogon = MAX(LogonTime)
			FROM
				[CallistoAppDictionary].[dbo].[LogonSessions] LS
				INNER JOIN pcINTEGRATOR_Data..[User] U ON U.UserNameAD = LS.UserID

				INNER JOIN pcINTEGRATOR_Data..[Application] A ON A.InstanceID = U.InstanceID AND A.SelectYN <> 0
			GROUP BY
				U.InstanceID,
				A.ApplicationName

			UNION SELECT
				A.InstanceID,
				A.ApplicationName,
				CallistoLogons = 0,
				FirstCallistoLogon = NULL,
				LastCallistoLogon = NULL
			FROM
				[pcINTEGRATOR_Data]..[Application] A
				INNER JOIN pcINTEGRATOR_Data..Instance I ON I.InstanceID = A.InstanceID
			WHERE
				A.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM [CallistoAppDictionary].[dbo].[LogonSessions] LS INNER JOIN pcINTEGRATOR_Data..[User] U ON U.UserNameAD = LS.UserID WHERE U.InstanceID = A.InstanceID)
			) sub
			INNER JOIN pcINTEGRATOR_Data..Instance I ON I.InstanceID = sub.InstanceID
			LEFT JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C ON C.CustomerID = I.CustomerID
			LEFT JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[CompanyType] CT ON CT.CompanyTypeID = C.CompanyTypeID
			LEFT JOIN (SELECT InstanceID, LastUse = MAX(StartTime), NoOfCalls = Count(1) FROM [pcINTEGRATOR_Log]..[JobLog] WHERE ProcedureName = 'spPortalAdminSet_InstanceLogin' AND UserID <> -10 GROUP BY InstanceID) JL ON JL.InstanceID = sub.InstanceID
		ORDER BY
			LastCallistoLogon,
			[Server],
			ApplicationName

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
