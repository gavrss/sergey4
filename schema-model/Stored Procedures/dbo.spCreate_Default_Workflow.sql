SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Default_Workflow]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000415,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spCreate_Default_Workflow',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spCreate_Default_Workflow] @UserID=-10, @InstanceID=458, @VersionID=1022, @Debug=1

EXEC spCreate_Default_Workflow @InstanceID='404',@UserID='2109',@VersionID='1003', @Debug=1

EXEC [spCreate_Default_Workflow] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@InsertedWorkFlow int,
	@OrganizationHierarchyID int,
	@InsertedRowCount int,
	
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
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT			
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set up default Workflow',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2144' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-42, DB-103: Handled correct setting of [Scenario].InheritedFrom and [OrganizationHierarchy].OrganizationHierarchyID.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'
		IF @Version = '2.1.1.2171' SET @Description = 'SELECT DISTINCT in test for Set Initial WorkflowState.'
		IF @Version = '2.1.1.2172' SET @Description = 'Updated queries to exclude deleted rows from Workflow-related tables.'
		IF @Version = '2.1.2.2199' SET @Description = 'Updated queries to exclude deleted rows from Workflow-related tables.'

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

		SELECT
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		IF @Debug <> 0 SELECT [@ETLDatabase] = @ETLDatabase, [@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'Create temp table #Scenario'
		CREATE TABLE #Scenario
			(
			InstanceID int,
			VersionID int,
			ScenarioID int,
			MemberKey nvarchar(100),
			InheritedFrom int
			)

	SET @Step = 'Insert into Scenario'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Scenario]
			(
			[InstanceID],
			[VersionID],
			[MemberKey],
			[ScenarioTypeID],
			[ScenarioName],
			[ScenarioDescription],
			[ActualOverwriteYN],
			[AutoRefreshYN],
			[InputAllowedYN],
			[AutoSaveOnCloseYN],
			[ClosedMonth],
			[SortOrder],
			[InheritedFrom],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[MemberKey],
			[ScenarioTypeID],
			[ScenarioName],
			[ScenarioDescription],
			[ActualOverwriteYN],
			[AutoRefreshYN],
			[InputAllowedYN],
			[AutoSaveOnCloseYN],
			[ClosedMonth],
			[SortOrder],
			[InheritedFrom] = S.ScenarioID,
			[SelectYN]
		FROM
			[Scenario] S
		WHERE
			[InstanceID] = @SourceInstanceID AND
			[VersionID] = @SourceVersionID AND
			[SelectYN] <> 0 AND
			NOT EXISTS (SELECT 1 FROM [Scenario] SD WHERE SD.[InstanceID] = @InstanceID AND SD.[VersionID] = @VersionID AND SD.[MemberKey] = S.[MemberKey])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = '[Scenario]', * FROM [pcINTEGRATOR_Data].[dbo].[Scenario] WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Insert into temp table #Scenario'
		INSERT INTO #Scenario
		(
			InstanceID,
			VersionID,
			ScenarioID,
			MemberKey,
			InheritedFrom
		)
		SELECT
			InstanceID = S.InstanceID,
			VersionID = S.VersionID,
			ScenarioID = S.ScenarioID,
			MemberKey = S.MemberKey,
			InheritedFrom = ISNULL(S.InheritedFrom, TS.ScenarioID)
		FROM
			[Scenario] S
			INNER JOIN [@Template_Scenario] TS ON TS.InstanceID = @SourceInstanceID AND TS.VersionID = @SourceVersionID AND TS.MemberKey = S.MemberKey
		WHERE
			S.InstanceID = @InstanceID AND
			S.VersionID = @VersionID

		IF @Debug <> 0 SELECT [TempTable] = '[#Scenario]', * FROM #Scenario

	SET @Step = 'Insert into Workflow'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow]
			(
			[InstanceID],
			[VersionID],
			[WorkflowName],
			[ProcessID],
			[ScenarioID],
			[CompareScenarioID],
			[TimeFrom],
			[TimeTo],
			[TimeOffsetFrom],
			[TimeOffsetTo],
			[InitialWorkflowStateID],
			[RefreshActualsInitialWorkflowStateID],
			[SpreadingKeyID],
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom],
			[SelectYN],
			[DeletedID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowName] = WF.[WorkflowName],
			[ProcessID] = ISNULL(P.ProcessID, 0),
			[ScenarioID] = S.ScenarioID,
			[CompareScenarioID] = CS.ScenarioID,
			[TimeFrom] = WF.[TimeFrom],
			[TimeTo] = WF.[TimeTo],
			[TimeOffsetFrom] = WF.[TimeOffsetFrom],
			[TimeOffsetTo] = WF.[TimeOffsetTo],
			[InitialWorkflowStateID] = WF.[InitialWorkflowStateID],
			[RefreshActualsInitialWorkflowStateID] = WF.[RefreshActualsInitialWorkflowStateID],
			[SpreadingKeyID] = WF.[SpreadingKeyID],
			[ModelingStatusID] = WF.[ModelingStatusID],
			[ModelingComment] = WF.[ModelingComment],
			[InheritedFrom] = WF.WorkflowID,
			[SelectYN] = 1,
			[DeletedID] = NULL
		FROM
			[Workflow] WF
			--INNER JOIN [Scenario] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.InheritedFrom = WF.[ScenarioID]
			INNER JOIN [#Scenario] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.InheritedFrom = WF.[ScenarioID]
			--INNER JOIN [Scenario] CS ON CS.InstanceID = @InstanceID AND CS.VersionID = @VersionID AND CS.InheritedFrom = WF.[CompareScenarioID]
			INNER JOIN [#Scenario] CS ON CS.InstanceID = @InstanceID AND CS.VersionID = @VersionID AND CS.InheritedFrom = WF.[CompareScenarioID]			 
			LEFT JOIN [Process] P ON P.InstanceID = @InstanceID AND P.VersionID = @VersionID AND P.ProcessName = 'Financials'
		WHERE
			WF.InstanceID = @SourceInstanceID AND
			WF.VersionID = @SourceVersionID AND
			NOT EXISTS (SELECT 1 FROM [Workflow] WFD WHERE WFD.[InstanceID] = @InstanceID AND WFD.[VersionID] = @VersionID AND WFD.[ScenarioID] = S.[ScenarioID] AND WFD.SelectYN <> 0 AND WFD.DeletedID IS NULL)

		SELECT @InsertedWorkFlow = @@ROWCOUNT

		IF @InsertedWorkFlow < 2 
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow]
				(
				[InstanceID],
				[VersionID],
				[WorkflowName],
				[ProcessID],
				[ScenarioID],
				[CompareScenarioID],
				[TimeFrom],
				[TimeTo],
				[TimeOffsetFrom],
				[TimeOffsetTo],
				[InitialWorkflowStateID],
				[RefreshActualsInitialWorkflowStateID],
				[SpreadingKeyID],
				[ModelingStatusID],
				[ModelingComment],
				[InheritedFrom],
				[SelectYN],
				[DeletedID]
				)
			SELECT
				[InstanceID] = @InstanceID,
				[VersionID] = @VersionID,
				[WorkflowName] = WF.[WorkflowName],
				[ProcessID] = ISNULL(P.ProcessID, 0),
				[ScenarioID] = S.ScenarioID,
				[CompareScenarioID] = CS.ScenarioID,
				[TimeFrom] = WF.[TimeFrom],
				[TimeTo] = WF.[TimeTo],
				[TimeOffsetFrom] = WF.[TimeOffsetFrom],
				[TimeOffsetTo] = WF.[TimeOffsetTo],
				[InitialWorkflowStateID] = WF.[InitialWorkflowStateID],
				[RefreshActualsInitialWorkflowStateID] = WF.[RefreshActualsInitialWorkflowStateID],
				[SpreadingKeyID] = WF.[SpreadingKeyID],
				[ModelingStatusID] = WF.[ModelingStatusID],
				[ModelingComment] = WF.[ModelingComment],
				[InheritedFrom] = WF.WorkflowID,
				[SelectYN] = 1,
				[DeletedID] = NULL
			FROM
				[Workflow] WF
				INNER JOIN [Scenario] TS1 ON TS1.InstanceID = WF.instanceID AND TS1.VersionID = WF.VersionID AND TS1.ScenarioID = WF.ScenarioID
				--INNER JOIN [#Scenario] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.MemberKey = 'BUDGET'
				INNER JOIN [#Scenario] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.MemberKey = TS1.MemberKey
				--INNER JOIN [#Scenario] CS ON CS.InstanceID = @InstanceID AND CS.VersionID = @VersionID AND S.MemberKey = 'ACTUAL'
				INNER JOIN [#Scenario] CS ON CS.InstanceID = @InstanceID AND CS.VersionID = @VersionID AND CS.MemberKey = 'ACTUAL'
				LEFT JOIN [Process] P ON P.InstanceID = @InstanceID AND P.VersionID = @VersionID AND P.ProcessName = 'Financials'
			WHERE
				WF.InstanceID = @SourceInstanceID AND
				WF.VersionID = @SourceVersionID AND
				NOT EXISTS (SELECT 1 FROM [Workflow] WFD WHERE WFD.[InstanceID] = @InstanceID AND WFD.[VersionID] = @VersionID AND WFD.[ScenarioID] = S.[ScenarioID] AND WFD.SelectYN <> 0 AND WFD.DeletedID IS NULL)
		
		SET @Inserted = @Inserted + @InsertedWorkFlow + @@ROWCOUNT

	SET @Step = 'UPDATE ProcessID in Workflow'
		UPDATE WF
		SET
			[ProcessID] = P.ProcessID
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow] WF
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P ON P.InstanceID = @InstanceID AND P.VersionID = @VersionID AND P.ProcessName = 'Financials'
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID AND
			WF.ProcessID = 0	
		
		IF @Debug <> 0 SELECT [Table] = '[Workflow]', * FROM [pcINTEGRATOR_Data].[dbo].[Workflow] WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Insert into WorkflowState'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowState]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[WorkflowStateName],
			[InheritedFrom]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowID] = WF.WorkflowID,
			[WorkflowStateName] = WS.[WorkflowStateName],
			[InheritedFrom] = WS.[WorkflowStateId]
		FROM
			[WorkflowState] WS
			INNER JOIN [Workflow] WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WS.WorkflowID AND WF.DeletedID IS NULL AND WF.SelectYN <> 0
		WHERE
			WS.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [WorkflowState] WSD WHERE WSD.InstanceID = @InstanceID AND WSD.[WorkflowID] = WF.[WorkflowID] AND WSD.[WorkflowStateName] = WS.[WorkflowStateName])
		ORDER BY
			WS.[WorkflowStateId] DESC

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = '[WorkflowState]', * FROM [pcINTEGRATOR_Data].[dbo].[WorkflowState]	WHERE InstanceID = @InstanceID

	SET @Step = 'UPDATE [Workflow].[InitialWorkflowStateID]'
		UPDATE WF
		SET
			[InitialWorkflowStateID] = WS.[WorkflowStateID],
			[RefreshActualsInitialWorkflowStateID] = RAWS.[WorkflowStateID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow] WF
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WS ON WS.InstanceID = @InstanceID AND WS.InheritedFrom = WF.[InitialWorkflowStateID]
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] RAWS ON RAWS.InstanceID = @InstanceID AND RAWS.InheritedFrom = WF.[RefreshActualsInitialWorkflowStateID]
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID AND
            WF.DeletedID IS NULL AND
            WF.SelectYN <> 0

		SELECT @Updated = @Updated + @@ROWCOUNT

		IF @Debug <> 0 SELECT [UpdatedTable] = '[Workflow]', [InstanceID], [WorkflowID], [VersionID], [InitialWorkflowStateID], [RefreshActualsInitialWorkflowStateID] FROM [pcINTEGRATOR_Data].[dbo].[Workflow] WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'INSERT INTO [OrganizationHierarchy]'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy]
			(
			[InstanceID],
			[VersionID],
			[OrganizationHierarchyName],
			[LinkedDimensionID],
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom],
			[DeletedID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[OrganizationHierarchyName],
			[LinkedDimensionID] = NULL,
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom] = OH.[OrganizationHierarchyID],
			[DeletedID]
		FROM
			[OrganizationHierarchy] OH
		WHERE
			InstanceID = @SourceInstanceID AND
			VersionID = @SourceVersionID AND
			NOT EXISTS (SELECT 1 FROM [OrganizationHierarchy] OHD WHERE OHD.[InstanceID] = @InstanceID AND OHD.[VersionID] = @VersionID AND OHD.[OrganizationHierarchyName] = OH.[OrganizationHierarchyName] AND OHD.DeletedID IS NULL)

		SELECT @InsertedRowCount = @@ROWCOUNT, @OrganizationHierarchyID = @@IDENTITY
		SELECT @Inserted = @Inserted + @InsertedRowCount

		IF @Debug <> 0 SELECT [@InsertedRowCount] = @InsertedRowCount, [@OrganizationHierarchyID] = @OrganizationHierarchyID

		IF @InsertedRowCount < 1 OR @OrganizationHierarchyID IS NULL
			BEGIN
				SELECT 
					@OrganizationHierarchyID = OHD.OrganizationHierarchyID 
				FROM 
					[OrganizationHierarchy] OHD 
					INNER JOIN [@Template_OrganizationHierarchy] OH ON OH.InstanceID = @SourceInstanceID AND OH.VersionID = @SourceVersionID AND OH.[OrganizationHierarchyName] = OHD.[OrganizationHierarchyName]
				WHERE 
					OHD.[InstanceID] = @InstanceID AND OHD.[VersionID] = @VersionID AND OHD.DeletedID IS NULL

				IF @Debug <> 0 SELECT [@OrganizationHierarchyID] = @OrganizationHierarchyID
			END

		IF @Debug <> 0 SELECT [Table] = '[OrganizationHierarchy]', * FROM [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy]	WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'INSERT INTO OrganizationHierarchy_Process'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process]
			(
			[InstanceID],
			[VersionID],
			[OrganizationHierarchyID],
			[ProcessID]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[OrganizationHierarchyID] = @OrganizationHierarchyID, -- MAX(OH.[OrganizationHierarchyID]),
			[ProcessID] = P.ProcessID --MAX(P.ProcessID)
		FROM
			[Process] P
			--INNER JOIN [OrganizationHierarchy] OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID
		WHERE
			P.InstanceID = @InstanceID AND 
			P.VersionID = @VersionID AND
			P.ProcessName = 'Financials' AND
			NOT EXISTS (SELECT 1 FROM [OrganizationHierarchy_Process] OHP WHERE OHP.[InstanceID] = @InstanceID AND OHP.[OrganizationHierarchyID] = @OrganizationHierarchyID AND OHP.[ProcessID] = P.ProcessID)

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = '[OrganizationHierarchy_Process]', * FROM [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process]	WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Insert into OrganizationLevel'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationLevel]
			(
			[InstanceID],
			[VersionID],
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[OrganizationLevelName]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[OrganizationLevelNo] = OL.[OrganizationLevelNo],
			[OrganizationLevelName] = OL.[OrganizationLevelName]
		FROM
			[OrganizationLevel] OL
			INNER JOIN [OrganizationHierarchy] OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = OL.OrganizationHierarchyID AND OH.DeletedID IS NULL 
		WHERE
			OL.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [OrganizationLevel] OLD WHERE OLD.[InstanceID] = @InstanceID AND OLD.[VersionID] = @VersionID AND OLD.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND OLD.[OrganizationLevelNo] = OL.[OrganizationLevelNo] AND OLD.[OrganizationLevelName] = OL.[OrganizationLevelName])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = '[OrganizationLevel]', * FROM [pcINTEGRATOR_Data].[dbo].[OrganizationLevel]	WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Insert into WorkflowStateChange'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[FromWorkflowStateID],
			[ToWorkflowStateID],
			[UserChangeableYN],
			[BRChangeableYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowID] = WF.WorkflowID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[OrganizationLevelNo] = WSC.[OrganizationLevelNo],
			[FromWorkflowStateID] = FWS.[WorkflowStateID],
			[ToWorkflowStateID] = TWS.[WorkflowStateID],
			[UserChangeableYN] = WSC.[UserChangeableYN],
			[BRChangeableYN] = WSC.[BRChangeableYN]
		FROM
			[WorkflowStateChange] WSC
			INNER JOIN [Workflow] WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WSC.WorkflowID AND WF.DeletedID IS NULL AND WF.SelectYN <> 0
			INNER JOIN [OrganizationHierarchy] OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = WSC.OrganizationHierarchyID AND OH.DeletedID IS NULL 
			INNER JOIN [WorkflowState] FWS ON FWS.InstanceID = @InstanceID AND FWS.InheritedFrom = WSC.FromWorkflowStateid
			INNER JOIN [WorkflowState] TWS ON TWS.InstanceID = @InstanceID AND TWS.InheritedFrom = WSC.ToWorkflowStateid
		WHERE
			WSC.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [WorkflowStateChange] WSCD WHERE WSCD.[InstanceID] = @InstanceID AND WSCD.[VersionID] = @VersionID AND WSCD.[WorkflowID] = WF.WorkflowID AND WSCD.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND WSCD.[OrganizationLevelNo] = WSC.[OrganizationLevelNo] AND WSCD.[FromWorkflowStateID] = FWS.WorkflowStateID AND WSCD.[ToWorkflowStateID] = TWS.WorkflowStateID)

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = '[WorkflowStateChange]', * FROM [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange]	WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Insert into Workflow_OrganizationLevel'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow_OrganizationLevel]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[OrganizationLevelNo],
			[LevelInWorkflowYN],
			[ExpectedDate],
			[ActionDescription]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowID] = WF.WorkflowID,
			[OrganizationLevelNo] = WOL.[OrganizationLevelNo],
			[LevelInWorkflowYN] = WOL.[LevelInWorkflowYN],
			[ExpectedDate] = WOL.[ExpectedDate],
			[ActionDescription] = WOL.[ActionDescription]
		FROM
			[Workflow_OrganizationLevel] WOL
			INNER JOIN [Workflow] WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WOL.WorkflowID AND WF.DeletedID IS NULL AND WF.SelectYN <> 0
		WHERE
			WOL.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [Workflow_OrganizationLevel] WOLD WHERE WOLD.[InstanceID] = @InstanceID AND WOLD.[VersionID] = @VersionID AND WOLD.[WorkflowID] = WF.[WorkflowID] AND WOLD.[OrganizationLevelNo] = WOL.[OrganizationLevelNo])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = '[Workflow_OrganizationLevel]', * FROM [pcINTEGRATOR_Data].[dbo].[Workflow_OrganizationLevel] WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Insert into WorkflowAccessRight'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowAccessRight]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[WorkflowStateID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowID] = WF.WorkflowID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[OrganizationLevelNo] = WAR.[OrganizationLevelNo],
			[WorkflowStateID] = WS.[WorkflowStateID],
			[SecurityLevelBM] = WAR.[SecurityLevelBM]
		FROM
			[WorkflowAccessRight] WAR
			INNER JOIN [Workflow] WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WAR.WorkflowID AND WF.DeletedID IS NULL AND WF.SelectYN <> 0
			INNER JOIN [OrganizationHierarchy] OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = WAR.OrganizationHierarchyID AND OH.DeletedID IS NULL 
			INNER JOIN [WorkflowState] WS ON WS.InstanceID = @InstanceID AND WS.InheritedFrom = WAR.WorkflowStateid
		WHERE
			WAR.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [WorkflowAccessRight] WARD WHERE WARD.[InstanceID] = @InstanceID AND WARD.[VersionID] = @VersionID AND WARD.[WorkflowID] = WF.WorkflowID AND WARD.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND WARD.[OrganizationLevelNo] = WAR.[OrganizationLevelNo] AND WARD.[WorkflowStateID] = WS.[WorkflowStateID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = '[WorkflowAccessRight]', * FROM [pcINTEGRATOR_Data].[dbo].[WorkflowAccessRight]	WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Insert into Workflow_LiveFcstNextFlow'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[LiveFcstNextFlowID],
			[WorkflowStateID]
			)
		SELECT
			[InstanceID] = WS.[InstanceID],
			[VersionID] = @VersionID,
			[WorkflowID] = WS.[WorkflowID],
			[LiveFcstNextFlowID] = CASE WS.InheritedFrom WHEN -120 THEN 1 WHEN -121 THEN 2 WHEN -125 THEN 3 END,
			[WorkflowStateID] = WS.[WorkflowStateID]
		FROM
			[WorkflowState] WS
		WHERE
			WS.InstanceID = @InstanceID AND
			WS.InheritedFrom IN (-120, -121, -125) AND
			NOT EXISTS (SELECT 1 FROM [Workflow_LiveFcstNextFlow] WLFNC WHERE WLFNC.[InstanceID] = @InstanceID AND WLFNC.[VersionID] = @VersionID AND WLFNC.[WorkflowID] = WS.[WorkflowID] AND WLFNC.[LiveFcstNextFlowID] = CASE WS.InheritedFrom WHEN -120 THEN 1 WHEN -121 THEN 2 WHEN -125 THEN 3 END AND WLFNC.[WorkflowStateID] = WS.[WorkflowStateId])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	IF @Debug <> 0 SELECT [Table] = '[Workflow_LiveFcstNextFlow]', * FROM [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow]	WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Set Initial WorkflowState'
		IF @CallistoDatabase IS NOT NULL
			
/*========================================================
TODO: Check Dimension ID = -63 exists 
-Run cursor in DataClass_Dimension where DimensionID = -63 (WorkflowState)
-And set InitialWorkflowStateID for those DataClasses
========================================================*/

		IF (SELECT DISTINCT 1 FROM DataClass_Dimension WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND DimensionID = -63) > 0
			BEGIN
					SET @SQLStatement = '
						UPDATE F
						SET
							[WorkflowState_MemberId] = W.InitialWorkflowStateID
						FROM
							' + @CallistoDatabase + '.[dbo].[FACT_Financials_default_partition] F
							INNER JOIN [Workflow] W ON
										W.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
										W.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND
										W.DeletedID IS NULL AND
										W.SelectYN <> 0 AND
										W.ScenarioID = F.[Scenario_MemberId] AND
										F.[Time_MemberId] BETWEEN W.[TimeFrom] AND W.[TimeTo]'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SELECT @Updated = @Updated + @@ROWCOUNT
				END
	
	SET @Step = 'Return rows - Workflow List'
		IF @Debug <> 0 EXEC [dbo].[spPortalAdminGet_Workflow_List] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID
	
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
