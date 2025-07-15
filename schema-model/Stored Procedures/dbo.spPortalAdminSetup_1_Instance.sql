SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSetup_1_Instance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL, --Mandatory always - Only @SourceTypeID = 11 (EpicorERP) is VALID for now
	@StorageTypeBM int = NULL, --Mandatory always - Only @StorageTypeBM = 4 (Callisto) is VALID for now
	@DemoYN bit = NULL, --Mandatory always - IF @DemoYN = 1 and @AssignedCustomerID/@AssignedInstanceID/@AssignedVersionID IS NULL a new Instance will be created with negative ID
	@AssignedCustomerID int = NULL OUT, --Mandatory UseCase IN (4)
	@AssignedInstanceID int = NULL OUT, --Mandatory UseCase IN (3)
	@AssignedVersionID int = NULL OUT, --Mandatory UseCase IN (2)	 
	@CustomerName nvarchar(50) = NULL, --Mandatory UseCase IN (5)
	@InstanceName nvarchar(50) = NULL, --Optional UseCase IN (4, 5), if not set defaulted to @CustomerName
	@InstanceShortName nvarchar(5) = NULL, --Mandatory UseCase IN (4, 5), if not set defaulted to LEFT(@ApplicationName, 5)
	@ApplicationName nvarchar(100) = NULL, --Mandatory UseCase IN (3, 4, 5)
	@ProductKey nvarchar(17) = NULL, --Optional
	@Email nvarchar(100) = NULL, --Mandatory always
	@UserNameAD nvarchar(100) = NULL, --Optional
	@UserNameDisplay nvarchar(100) = NULL, --Optional
	@StartYear int = NULL, --Mandatory always
	@EndYear int = NULL, --Mandatory always
	@FiscalYearStartMonth int = NULL, --If not set, it will be checked in source database or defaulted to 1.
	@FiscalYearNaming int = NULL OUT, --If not set, it will be checked in source database or defaulted to 0.
	@SourceServer nvarchar(100) = 'DSPSOURCE01', --Mandatory always
	@SourceDatabase nvarchar(100) = NULL, --Mandatory always
	@LocaleID int = -41, --Optional
	@BrandID int = 2, --Mandatory always; 1 = pcFinancials, 2 = EFP
	@ModelingStatusID int = -40, --Optional
	@ModelingComment nvarchar(100) = 'Default Setup', --Optional
	@EnhancedStorageYN bit = 1,

	@JobID int = NULL OUT,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000588,
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
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"DebugBM","TValue":"15"},
{"TKey":"ApplicationName","TValue":"DBT04"},{"TKey":"Email","TValue":"DBT04@test.db"},
{"TKey":"SourceServer","TValue":"DSPSOURCE01"},{"TKey":"StorageTypeBM","TValue":"4"},
{"TKey":"FiscalYearStartMonth","TValue":"1"},{"TKey":"BrandID","TValue":"1"},
{"TKey":"UserNameDisplay","TValue":"DBT04"},{"TKey":"InstanceID","TValue":"0"},
{"TKey":"DemoYN","TValue":"1"},{"TKey":"StartYear","TValue":"2015"},
{"TKey":"EndYear","TValue":"2022"},{"TKey":"UserID","TValue":"-10"},
{"TKey":"UserNameAD","TValue":"demo\\DBT04.DBT04"},{"TKey":"SourceTypeID","TValue":"11"},
{"TKey":"CustomerName","TValue":"DBT04"},{"TKey":"VersionID","TValue":"0"},
{"TKey":"SourceDatabase","TValue":"ERP10"},{"TKey":"ProductKey","TValue":"EPICOR_INSIGHTS"}
]', @ProcedureName='spPortalAdminSetup_1_Instance'

5 different use cases:
----------------------
1. Demo/Trial (Possible to combine with Use Cases 2,3,4 & 5)
2. Existing VersionID (and CustomerID/InstanceID)
3. Existing InstanceID (and CustomerID, but not VersionID)
4. Existing CustomerID (but not InstanceID/VersionID)
5. Not existing CustomerID/InstanceID/VersionID

--5. Create Demo/Trial Instance (Not existing CustomerID/InstanceID/VersionID)
EXEC [spPortalAdminSetup_1_Instance]
	@UserID = -10,
	@InstanceID = 0,
	@VersionID = 0,
	@SourceTypeID = 11,
	@StorageTypeBM = 4,
	@DemoYN = 1,
	@AssignedInstanceID = -1367,
	@AssignedVersionID = NULL,
	@CustomerName = 'Nevhan1 Test Demo Instance',
	@ApplicationName = 'N1TDI',
	@ProductKey = NULL, 
	@Email = 'nevhan.hayag@test.com',
	@UserNameAD = NULL,
	@UserNameDisplay = NULL,
	@StartYear = 2018, 
	@EndYear = 2022,
	@FiscalYearStartMonth = NULL,
	@FiscalYearNaming = NULL,
	@SourceServer = 'DSPDEVDB01',
	@SourceDatabase = 'ERP10',
	@BrandID = 2,
	@DebugBM = 6

EXEC [spPortalAdminSetup_1_Instance] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	@JobIDSub int,
	@AddYear int,
	@FiscalYearStartMonthSetYN bit,
	@FiscalYearNamingSetYN bit,
	@AssignedUserID int = NULL,
	@Total decimal(5,2) = 25,
	@Counter decimal(5,2) = 0,
	@StatusMessage nvarchar(100),
	@PercentDone int,

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup a new instance.',
			@MandatoryParameter = 'SourceTypeID|StorageTypeBM|DemoYN|Email|StartYear|EndYear|SourceServer|SourceDatabase|BrandID' --Without @, separated by |

		IF @Version = '2.0.3.2152' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Update table DSPMASTER.pcINTEGRATOR_Master.dbo.[Instance_Server]. Code refactoring, use of [spSetup_*] calls.'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine [spSet_Job].'
		IF @Version = '2.1.0.2165' SET @Description = 'Added iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.' 
		IF @Version = '2.1.1.2172' SET @Description = 'Added @DemoYN parameter in the SP call to [spSetup_User_Security].'
		IF @Version = '2.1.1.2173' SET @Description = 'Set @FiscalYearNaming as OUT parameter. Set @MasterCommand parameter in [spSetup_Instance] subroutine. Added @Step = Set EndTime for the actual job.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
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

		SELECT
			@InstanceID = @AssignedInstanceID,
			@VersionID = @AssignedVersionID

		SELECT
			@AddYear = @EndYear - YEAR(GETDATE()),
			@FiscalYearStartMonthSetYN = CASE WHEN @FiscalYearStartMonth IS NULL THEN 0 ELSE 1 END,
			@FiscalYearNamingSetYN = CASE WHEN @FiscalYearNaming IS NULL THEN 0 ELSE 1 END,
			@FiscalYearStartMonth = ISNULL(@FiscalYearStartMonth, 1),
			@FiscalYearNaming = ISNULL(@FiscalYearNaming, 0)

		SELECT
			@InstanceID = ISNULL(@InstanceID, InstanceID)
		FROM 
			[pcINTEGRATOR_Data].[dbo].[Instance]
		WHERE
			[InstanceName] = ISNULL(@InstanceName, @CustomerName) AND
			[CustomerID] = @AssignedCustomerID

		SELECT
			@AssignedCustomerID = ISNULL(@AssignedCustomerID, I.[CustomerID]),
			@InstanceID = ISNULL(@InstanceID, V.[InstanceID])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Version] V
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Instance] I ON I.[InstanceID] = V.[InstanceID]
		WHERE
			V.[VersionID] = @VersionID

		SELECT
			@AssignedCustomerID = ISNULL(@AssignedCustomerID, I.[CustomerID]),
			@InstanceName = ISNULL(@InstanceName, I.[InstanceName])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Instance] I
		WHERE
			I.[InstanceID] = @InstanceID

		SELECT
			@ApplicationName = ISNULL(@ApplicationName, A.[ApplicationName])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		SELECT
			@AssignedCustomerID = ISNULL(@AssignedCustomerID, I.[CustomerID]),
			@InstanceName = ISNULL(@InstanceName, I.[InstanceName]),
			@InstanceShortName = ISNULL(@InstanceShortName, I.[InstanceShortName])
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I
		WHERE
			I.[InstanceID] = @InstanceID

		SELECT
			@CustomerName = ISNULL(@CustomerName, C.[CustomerName])
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C
		WHERE
			C.[CustomerID] = @AssignedCustomerID

		SELECT
			@VersionID = ISNULL(@VersionID, A.[VersionID])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[ApplicationName] = @ApplicationName

		SELECT
			@InstanceName = ISNULL(@InstanceName, @CustomerName),
			@InstanceShortName = ISNULL(@InstanceShortName, LEFT(@ApplicationName, 5))
			
		SELECT
			@UserNameAD = ISNULL(@UserNameAD, 'live\' + @InstanceShortName + '.' + LEFT(LEFT(@Email, CHARINDEX('@', @Email) - 1), 14)),
			@UserNameDisplay = ISNULL(@UserNameDisplay, @Email)

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@SourceTypeID] = @SourceTypeID,
				[@StorageTypeBM] = @StorageTypeBM,
				[@DemoYN] = @DemoYN,
				[@AssignedCustomerID] = @AssignedCustomerID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@CustomerName] = @CustomerName,
				[@InstanceName] = @InstanceName,
				[@InstanceShortName] = @InstanceShortName,
				[@ApplicationName] = @ApplicationName,
				[@ProductKey] = @ProductKey,
				[@Email] = @Email,
				[@UserNameAD] = @UserNameAD,
				[@UserNameDisplay] = @UserNameDisplay,
				[@StartYear] = @StartYear,
				[@EndYear] = @EndYear,
				[@AddYear] = @AddYear,
				[@FiscalYearStartMonthSetYN] = @FiscalYearStartMonthSetYN,
				[@FiscalYearStartMonth] = @FiscalYearStartMonth,
				[@FiscalYearNamingSetYN] = @FiscalYearNamingSetYN,
				[@FiscalYearNaming] = @FiscalYearNaming,
				[@SourceServer] = @SourceServer,
				[@SourceDatabase] = @SourceDatabase,
				[@LocaleID] = @LocaleID,
				[@BrandID] = @BrandID,
				[@ModelingStatusID] = @ModelingStatusID,
				[@ModelingComment] = @ModelingComment

	SET @Step = 'Check if Instance name is already used.'
		IF ISNULL(@InstanceID, -100) = -100
			IF (SELECT COUNT(1) FROM [Instance] WHERE InstanceName = @InstanceName AND [InstanceID] <> @InstanceID) > 0
				BEGIN
					SET @Message = 'The Instance name ' + @InstanceName + ' is already in use. Choose another Instance name or add the corresponding CustomerID/InstanceID as parameter.'
					SET @Severity = 16
					GOTO EXITPOINT
				END

		IF (SELECT COUNT(1) FROM [Instance] WHERE InstanceName = @InstanceName AND [InstanceID] <> @InstanceID) > 0
			BEGIN
				SET @Message = 'The Instance name ' + @InstanceName + ' is already in use. Choose another Instance name or leave blank.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Check if Application name is already used.'
		IF ISNULL(@VersionID, -100) = -100
			IF (SELECT COUNT(1) FROM [Application] WHERE InstanceID <> @InstanceID AND ApplicationName = @ApplicationName) > 0
				BEGIN
					SET @Message = 'The Application name ' + @ApplicationName + ' is already in use by another Instance. Choose another Application name.'
					SET @Severity = 16
					GOTO EXITPOINT
				END

	SET @Step = 'Start Job'
		IF @JobID IS NULL AND @InstanceID IS NOT NULL AND @VersionID IS NOT NULL
			EXEC [spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=0,
				@CheckCount = 0,
				@JobID=@JobID OUT

		IF @DebugBM & 2 > 0 SELECT [@JobID] = @JobID

	SET @Step = 'Create Instance.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_Instance] 
			@UserID = @UserID, 
			@InstanceID = @InstanceID OUT, 
			@VersionID = @VersionID OUT, 
			@StorageTypeBM = @StorageTypeBM,
			@DemoYN = @DemoYN, 
			@CustomerID = @AssignedCustomerID OUT,
			@CustomerName = @CustomerName,
			@InstanceName = @InstanceName,
			@InstanceShortName = @InstanceShortName,
			@ApplicationName = @ApplicationName,
			@ProductKey = @ProductKey,
			@StartYear = @StartYear,
			@AddYear = @AddYear,
			@FiscalYearStartMonthSetYN = @FiscalYearStartMonthSetYN,
			@FiscalYearStartMonth = @FiscalYearStartMonth,
			@FiscalYearNamingSetYN = @FiscalYearNamingSetYN,
			@FiscalYearNaming = @FiscalYearNaming,
			@BrandID = @BrandID,
			@MasterCommand = @ProcedureName,
			@EnhancedStorageYN = @EnhancedStorageYN,
			@Deleted = @Deleted OUT, 
			@Inserted = @Inserted OUT, 
			@Updated = @Updated OUT,
			@Selected = @Selected OUT, 
			@JobID = @JobID OUT,
			@Debug = @DebugSub

	SET @Step = 'Create Model and Source.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_Source] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @SourceTypeID = @SourceTypeID, @SourceServer = @SourceServer, @SourceDatabase = @SourceDatabase, @StartYear = @StartYear, @ModelingStatusID = @ModelingStatusID, @ModelingComment = @ModelingComment, @DemoYN = @DemoYN, @Deleted = @Deleted OUT, @Inserted = @Inserted OUT, @Updated = @Updated OUT, @Selected = @Selected OUT, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Create Entity.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_Entity] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @SourceTypeID = @SourceTypeID,	@Deleted = @Deleted OUT, @Inserted = @Inserted OUT, @Updated = @Updated OUT, @Selected = @Selected OUT, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Create Entity Segments.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_Segment] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @SourceTypeID = @SourceTypeID, @Deleted = @Deleted OUT, @Inserted = @Inserted OUT, @Updated = @Updated OUT, @Selected = @Selected OUT, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Create User and Security.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_User_Security] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DemoYN = @DemoYN, @SourceTypeID = @SourceTypeID, @Email = @Email, @UserNameAD = @UserNameAD, @UserNameDisplay = @UserNameDisplay, @AssignedUserID = @AssignedUserID OUT, @Deleted = @Deleted OUT, @Inserted = @Inserted OUT, @Updated = @Updated OUT, @Selected = @Selected OUT, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Return information'
		SELECT
			[@AssignedCustomerID] = @AssignedCustomerID,
			[@AssignedInstanceID] = @InstanceID, 
			[@AssignedVersionID] = @VersionID,
			[@AssignedUserID] = @AssignedUserID,
			[@FiscalYearNaming] = @FiscalYearNaming,
			[@JobID] = @JobID,
			[@MasterCommand] = @ProcedureName

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

	SET @Step = 'Set EndTime for the actual job'
		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID

END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
