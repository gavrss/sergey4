SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Instance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JSON_table nvarchar(MAX) = NULL,
	@ResultTypeBM int = NULL, --1 = Instance

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000609,
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
DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "1", "InstanceID": "-1428", "CompanyTypeID": "4"}
	]'
			
EXEC [spPortalAdminSet_Instance]
	@UserID=-10,
	@InstanceID=0,
	@VersionID=0,
	@JSON_table = @JSON_table,
	@DebugBM=7

EXEC [spPortalAdminSet_Instance] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,
	@Inserted_Local int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2166'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain table Instance (most properties are inherited from Master DB)',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2166' SET @Description = 'DB-205 Added @Step = Update CompanyTypeID.'

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

	--SET @Step = 'Check parameters'
	--	IF @DeleteYN = 0
	--		IF @BR_Name IS NULL OR @BR_Description IS NULL
	--			BEGIN
	--				SET @Message = 'To insert a new or update an existing member parameter @BR_Name AND @BR_Description must be set'
	--				SET @Severity = 16
	--				GOTO EXITPOINT
	--			END

	SET @Step = 'Create and fill #InstanceList'
		CREATE TABLE #InstanceList
			(
			[ResultTypeBM] int,
			[InstanceID] int,
			[CompanyTypeID] int,
			[StartYear] int,
			[EndYear] int,
			[FiscalYearStartMonth] int,
			[FiscalYearNaming] int,
			[pcPortal_URL] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Mail_ProfileName] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[AllowExternalAccessYN] bit,
			[TriggerActiveYN] bit,
			[SelectYN] bit
			)

		IF @JSON_table IS NOT NULL	
			INSERT INTO #InstanceList
				(
				[ResultTypeBM],
				[InstanceID],
				[CompanyTypeID],
				[StartYear],
				[EndYear],
				[FiscalYearStartMonth],
				[FiscalYearNaming],
				[pcPortal_URL],
				[Mail_ProfileName],
				[AllowExternalAccessYN],
				[TriggerActiveYN],
				[SelectYN]
				)
			SELECT
				[ResultTypeBM],
				[InstanceID],
				[CompanyTypeID],
				[StartYear],
				[EndYear],
				[FiscalYearStartMonth],
				[FiscalYearNaming],
				[pcPortal_URL],
				[Mail_ProfileName],
				[AllowExternalAccessYN],
				[TriggerActiveYN],
				[SelectYN]
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				[ResultTypeBM] int,
				[InstanceID] int,
				[CompanyTypeID] int,
				[StartYear] int,
				[EndYear] int,
				[FiscalYearStartMonth] int,
				[FiscalYearNaming] int,
				[pcPortal_URL] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[Mail_ProfileName] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[AllowExternalAccessYN] bit,
				[TriggerActiveYN] bit,
				[SelectYN] bit
				)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#InstanceList', * FROM #InstanceList

	SET @Step = 'Update ResultTypeBM = 1 (Instance)'
		UPDATE I
		SET
			[StartYear] = ISNULL(IL.[StartYear], I.[StartYear]),
			[AddYear] = ISNULL(IL.[EndYear] - YEAR(GetDate()), I.[AddYear]),
			[FiscalYearStartMonth] = ISNULL(IL.[FiscalYearStartMonth], I.[FiscalYearStartMonth]),
			[FiscalYearNaming] = ISNULL(IL.[FiscalYearNaming], I.[FiscalYearNaming]),
			[pcPortal_URL] = ISNULL(IL.[pcPortal_URL], I.[pcPortal_URL]),
			[Mail_ProfileName] = ISNULL(IL.[Mail_ProfileName], I.[Mail_ProfileName]),
			[AllowExternalAccessYN] = ISNULL(IL.[AllowExternalAccessYN], I.[AllowExternalAccessYN]),
			[TriggerActiveYN] = ISNULL(IL.[TriggerActiveYN], I.[TriggerActiveYN]),
			[SelectYN] = ISNULL(IL.[SelectYN], I.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Instance] I
			INNER JOIN #InstanceList IL ON IL.ResultTypeBM = 1 AND IL.[InstanceID] = I.[InstanceID] 

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update CompanyTypeID'
		UPDATE C
		SET
			[CompanyTypeID] = IL.CompanyTypeID
		FROM 
			[pcINTEGRATOR_Data].[dbo].[Customer] C
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Instance] I ON I.CustomerID = C.CustomerID
			INNER JOIN #InstanceList IL ON IL.ResultTypeBM = 1 AND IL.[InstanceID] = I.[InstanceID]
			INNER JOIN [pcINTEGRATOR].[dbo].[CompanyType] CT ON CT.CompanyTypeID = IL.CompanyTypeID
		WHERE
			C.CustomerID NOT IN (435, 436)

	SET @Step = 'Return Rows'
		IF @DebugBM & 1 > 0
			BEGIN
				SELECT 
					I.*, C.*, CT.CompanyTypeName, CT.CompanyTypeDescription
				FROM [pcINTEGRATOR_Data].[dbo].[Instance] I 
					INNER JOIN #InstanceList IL ON IL.ResultTypeBM = 1 AND IL.[InstanceID] = I.[InstanceID]
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Customer] C ON C.CustomerID = I.CustomerID
					INNER JOIN [pcINTEGRATOR].[dbo].[CompanyType] CT ON CT.CompanyTypeID = C.CompanyTypeID
				ORDER BY I.[InstanceName]
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
