SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSetup_AddOn]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@ProductOptionID INT = NULL, --Mandatory
	@TemplateObjectID INT = NULL, -- Mandatory for SalesReport (-118)

	@SourceServer NVARCHAR(100) = NULL,
	@SourceDatabase NVARCHAR(100) = NULL,
	@StartYear INT = NULL,
	@MasterCommand NVARCHAR(100) = NULL,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880001003,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spPortalAdminSetup_AddOn] @UserID=-10, @InstanceID=0, @VersionID=0, @DebugBM=7, @ProductOptionID=201 --HR
EXEC [spPortalAdminSetup_AddOn] @UserID=-10, @InstanceID=0, @VersionID=0, @DebugBM=7, @ProductOptionID=204 --AP
EXEC [spPortalAdminSetup_AddOn] @UserID=-10, @InstanceID=0, @VersionID=0, @DebugBM=7, @ProductOptionID=205 --AR

EXEC [spPortalAdminSetup_AddOn] @UserID=-10, @InstanceID=975, @VersionID=1376, @DebugBM=7, @ProductOptionID=211 --Sales
,@SourceServer = 'dspsource01', @SourceDatabase = 'pcSource_CRSCNTMNF', @StartYear = 2015

EXEC [spPortalAdminSetup_AddOn] @UserID=-10, @InstanceID=975, @VersionID=1376, @DebugBM=7, @ProductOptionID=211, @TemplateObjectID=-118 --SalesReport
,@SourceServer = 'dspsource01', @SourceDatabase = 'pcSource_CRSCNTMNF', @StartYear = 2015

EXEC [spPortalAdminSetup_AddOn] @GetVersion = 1

*/

SET ANSI_WARNINGS OFF

DECLARE
	@SourceTypeID INT = -20,
	@StorageTypeBM INT = NULL,
	@JobListID INT = NULL,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'NeHa',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup add-on modules (Advanced Financials and/or Sales).',
			@MandatoryParameter = 'ProductOptionID' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT 
			@StorageTypeBM = A.StorageTypeBM
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
            A.[VersionID] = @VersionID

		SET @StorageTypeBM = ISNULL(@StorageTypeBM, 4)

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@StorageTypeBM] = @StorageTypeBM,
				[@ProductOptionID] = @ProductOptionID,
				[@TemplateObjectID] = @TemplateObjectID,
				[@SourceServer] = @SourceServer,
				[@SourceDatabase] = @SourceDatabase,
				[@StartYear] = @StartYear

	--SET @Step = 'Set Job status.'
	--	SET @MasterCommand = ISNULL(@MasterCommand, @ProcedureName)

	--	EXEC [pcINTEGRATOR].[dbo].[spSet_Job]
	--		@UserID=@UserID,
	--		@InstanceID=@InstanceID,
	--		@VersionID=@VersionID,
	--		@ActionType='Start',
	--		@MasterCommand=@MasterCommand,
	--		@CurrentCommand=@ProcedureName,
	--		@JobQueueYN=0,
	--		@JobID=@JobID OUT

	SET @Step = 'Setup Model/Source'
		EXEC [pcINTEGRATOR].[dbo].[spSetup_Source] 
			@UserID = @UserID, 
			@InstanceID = @InstanceID, 
			@VersionID = @VersionID, 
			@SourceTypeID = @SourceTypeID, 
			@ProductOptionID = @ProductOptionID,
			@SourceServer = @SourceServer,
			@SourceDatabase = @SourceDatabase, 
			@StartYear = @StartYear, 
			@Debug = @DebugSub

	SET @Step = 'Setup DataClass'
		EXEC [pcINTEGRATOR].[dbo].[spSetup_DataClass] 
			@UserID = @UserID, 
			@InstanceID = @InstanceID, 
			@VersionID = @VersionID, 
			@SourceTypeID = @SourceTypeID, 
			@ProductOptionID = @ProductOptionID,
			@StorageTypeBM = @StorageTypeBM,
			@TemplateObjectID = @TemplateObjectID,
			@Debug = @DebugSub

	SET @Step = 'Setup Dimension'
		EXEC [pcINTEGRATOR].[dbo].[spSetup_Dimension] 
			@UserID = @UserID, 
			@InstanceID = @InstanceID, 
			@VersionID = @VersionID, 
			@SourceTypeID = @SourceTypeID, 
			@ProductOptionID = @ProductOptionID,
			@StorageTypeBM = @StorageTypeBM,
			@TemplateObjectID = @TemplateObjectID,
			@Debug = @DebugSub

	SET @Step = 'Import to Callisto'
		EXEC [pcINTEGRATOR].[dbo].[spSetup_Callisto] 
			@UserID = @UserID, 
			@InstanceID = @InstanceID, 
			@VersionID = @VersionID, 
			@SequenceBM = 23, --includes AP&AR/Sales Dynamic BRs
			@CallistoDeployYN = 0, 
			@DebugBM = @DebugSub												

	SET @Step = 'Insert JobStep'
		EXEC [pcINTEGRATOR].[dbo].[spSetup_Job] 
			@UserID = @UserID, 
			@InstanceID = @InstanceID, 
			@VersionID = @VersionID, 
			@SourceTypeID = @SourceTypeID, 
			@ProductOptionID = @ProductOptionID,
			@StorageTypeBM = @StorageTypeBM,
			@TemplateObjectID = @TemplateObjectID,
			@DebugBM = @DebugSub

	SET @Step = 'Insert BookType'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_Book]
			(
			[InstanceID]
			,[VersionID]
			,[EntityID]
			,[Book]
			,[Currency]
			,[BookTypeBM]
			,[SelectYN]
			,[Version]
			,[COA]
			,[BalanceType]
			)
		SELECT 
			[InstanceID],
			[VersionID],
			[EntityID],
			[Book] = CASE @ProductOptionID WHEN 204 THEN 'AccountPayable' WHEN 205 THEN 'AccountReceivable' WHEN 211 THEN 'Sales' END,
			[Currency],
			[BookTypeBM] = 8,
			[SelectYN],
			[Version],
			[COA],
			[BalanceType]
		FROM 
			[pcINTEGRATOR_Data].[dbo].[Entity_Book] EB
		WHERE 
			EB.[InstanceID] = @InstanceID AND EB.[VersionID] = @VersionID AND EB.[BookTypeBM] & 2 > 0 AND EB.[SelectYN] <> 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] EBK 
						WHERE EBK.[InstanceID] = EB.[InstanceID] AND EBK.[VersionID] = EB.[VersionID] AND EBK.[EntityID] = EB.[EntityID] AND EBK.[BookTypeBM] = 8
							AND EBK.[Book] = CASE @ProductOptionID WHEN 204 THEN 'AccountPayable' WHEN 205 THEN 'AccountReceivable' WHEN 211 THEN 'Sales' END)		

	SET @Step = 'Run job to load dimensions and full deploy to create fact tables'
		SELECT
			@JobListID = [JobListID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[JobList] JL
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[InheritedFrom] = -111 AND --Dim Load
			[SelectYN] <> 0

		EXEC [pcINTEGRATOR].[dbo].[spRun_Job_Callisto_Generic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StepName='ETLFull', @JobListID=@JobListID, @AsynchronousYN=0, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Recreate Index'
		EXEC [pcINTEGRATOR].[dbo].[spSetup_Index] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Load data to FACT table'
		IF @ProductOptionID = 204 
			EXEC [pcINTEGRATOR].[dbo].[spIU_DC_AccountPayable_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @DebugBM=@DebugSub

		ELSE IF @ProductOptionID = 205 
			EXEC [pcINTEGRATOR].[dbo].[spIU_DC_AccountReceivable_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @DebugBM=@DebugSub

		ELSE IF @ProductOptionID = 211 
			EXEC [pcINTEGRATOR].[dbo].[spIU_DC_Sales_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @DebugBM=@DebugSub

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	SET @Step = 'Set EndTime for the actual job'
		EXEC [pcINTEGRATOR].[dbo].[spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@MasterCommand,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	EXEC [pcINTEGRATOR].[dbo].[spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@MasterCommand, @CurrentCommand=@ProcedureName, @JobID=@JobID

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
