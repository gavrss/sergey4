SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_WorkflowCreateCopy]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@FromWorkflowID int = NULL,
	@NewWorkflowID int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000131,
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
	@ProcedureName = 'spPortalAdminSet_WorkflowCreateCopy',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC spPortalAdminSet_WorkflowCreateCopy @UserID = -10, @InstanceID = 304, @VersionID = 1001, @FromWorkflowID = 1001
EXEC spPortalAdminSet_WorkflowCreateCopy @UserID = -10, @InstanceID = 304, @VersionID = 1013, @FromWorkflowID = 3284

EXEC [spPortalAdminSet_WorkflowCreateCopy] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@AssignmentName nvarchar(100),
	@Comment nvarchar(100),
	@OrganizationPositionID int,
	@DataClassID int,
	@GridID int,
	@Priority int,
	@InheritedFrom int,
	@StorageTypeBM int,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2190'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Copy an existing Workflow',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-123: Added VersionID for all tables were missing. Changed logic for updating InitialWorkflowState.'
		IF @Version = '2.0.2.2148' SET @Description = 'Added Step: Update WorkflowState dimension table.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'
		IF @Version = '2.1.0.2156' SET @Description = 'Modified query to set @StorageTypeBM.'
		IF @Version = '2.1.2.2182' SET @Description = 'Refer to correct version of ETL-procedure: spIU_Dim_WorkflowState_Callisto.'
		IF @Version = '2.1.2.2190' SET @Description = 'DB-1333: Generate Workflowstates after creating/duplicating a Workflow. Updated SP to new template.'

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

	SET @Step = 'Insert new data into table Workflow.'

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
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom],
			[SelectYN],
			[DeletedID]
			)
		SELECT 
			[InstanceID],
			[VersionID],
			[WorkflowName] = WF.[WorkflowName] + ' (Copy)',
			[ProcessID],
			[ScenarioID],
			[CompareScenarioID],
			[TimeFrom],
			[TimeTo],
			[TimeOffsetFrom],
			[TimeOffsetTo],
			[InitialWorkflowStateID],
			[ModelingStatusID] = -40,
			[ModelingComment] = NULL,
			[InheritedFrom] = WF.[WorkflowID],
			[SelectYN] = 1,
			[DeletedID]
		FROM
			[Workflow] WF
		WHERE
			WF.[InstanceID] = @InstanceID AND
			WF.[VersionID] = @VersionID AND
			WF.[WorkflowID] = @FromWorkflowID

		SET @NewWorkflowID = @@IDENTITY

	SET @Step = 'Insert new data into table WorkflowState.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowState]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[WorkflowStateName],
			[InheritedFrom]
			)
		SELECT
			[InstanceID],
			[VersionID],
			[WorkflowID] = @NewWorkflowID,
			[WorkflowStateName],
			[InheritedFrom] = WFS.[WorkflowStateId]
		FROM
			[WorkflowState] WFS
		WHERE
			WFS.[InstanceID] = @InstanceID AND
			WFS.[VersionID] = @VersionID AND
			WFS.[WorkflowID] = @FromWorkflowID

	SET @Step = 'Update [InitialWorkflowStateID] in table [Workflow].'
		UPDATE WF
		SET
			[InitialWorkflowStateID] = sub.[InitialWorkflowStateID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow] WF
			INNER JOIN
				(
				SELECT
					[InstanceID] = WFS.[InstanceID],
					[VersionID] = WFS.[VersionID],
					[WorkflowID] = WFS.[WorkflowID],
					[InitialWorkflowStateID] = MAX(WFS.[WorkflowStateID])
				FROM
					[pcINTEGRATOR_Data].[dbo].[Workflow] WF
					INNER JOIN [pcINTEGRATOR].[dbo].[WorkflowState] WFS ON WFS.[InstanceID] = WF.[InstanceID] AND WFS.[VersionID] = WF.[VersionID] AND WFS.[WorkflowID] = @NewWorkflowID AND WFS.[InheritedFrom] = WF.[InitialWorkflowStateID]
				WHERE
					WF.[InstanceID] = @InstanceID AND
					WF.[VersionID] = @VersionID AND
					WF.[WorkflowID] = @FromWorkflowID
				GROUP BY
					WFS.[InstanceID],
					WFS.[VersionID],
					WFS.[WorkflowID]
				) sub ON sub.[InstanceID] = WF.[InstanceID] AND sub.[VersionID] = WF.[VersionID] AND sub.[WorkflowID] = WF.[WorkflowID]

	SET @Step = 'Update [RefreshActualsInitialWorkflowStateID] in table [Workflow].'
		UPDATE WF
		SET
			[RefreshActualsInitialWorkflowStateID] = sub.[RefreshActualsInitialWorkflowStateID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow] WF
			INNER JOIN
				(
				SELECT
					[InstanceID] = WFS.[InstanceID],
					[VersionID] = WFS.[VersionID],
					[WorkflowID] = WFS.[WorkflowID],
					[RefreshActualsInitialWorkflowStateID] = MAX(WFS.[WorkflowStateID])
				FROM
					[pcINTEGRATOR_Data].[dbo].[Workflow] WF
					INNER JOIN [pcINTEGRATOR].[dbo].[WorkflowState] WFS ON WFS.[InstanceID] = WF.[InstanceID] AND WFS.[VersionID] = WF.[VersionID] AND WFS.[WorkflowID] = @NewWorkflowID AND WFS.[InheritedFrom] = WF.[RefreshActualsInitialWorkflowStateID]
				WHERE
					WF.[InstanceID] = @InstanceID AND
					WF.[VersionID] = @VersionID AND
					WF.[WorkflowID] = @FromWorkflowID
				GROUP BY
					WFS.[InstanceID],
					WFS.[VersionID],
					WFS.[WorkflowID]
				) sub ON sub.[InstanceID] = WF.[InstanceID] AND sub.[VersionID] = WF.[VersionID] AND sub.[WorkflowID] = WF.[WorkflowID]

	SET @Step = 'Insert new data into table WorkflowRow.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowRow]
			(
			[InstanceID],
			[VersionID],
			[WorkflowID],
			[DimensionID],
			[Dimension_MemberKey],
			[CogentYN]
			)
		SELECT 
			[InstanceID] = WFR.[InstanceID],
			[VersionID] = WFR.[VersionID],
			[WorkflowID] = @NewWorkflowID,
			[DimensionID],
			[Dimension_MemberKey],
			[CogentYN]
		FROM
			[pcINTEGRATOR].[dbo].[WorkflowRow] WFR
		WHERE
			WFR.[InstanceID] = @InstanceID AND
			WFR.[VersionID] = @VersionID AND
			WFR.[WorkflowID] = @FromWorkflowID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[WorkflowRow] WR WHERE WR.[InstanceID] = WFR.[InstanceID] AND WR.[VersionID] = WFR.[VersionID] AND WR.[WorkflowID] = @NewWorkflowID AND WR.[DimensionID] = WFR.DimensionID AND WR.[Dimension_MemberKey] = WFR.Dimension_MemberKey)

	SET @Step = 'Insert new data into table WorkflowAccessRight.'
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
			[InstanceID] = WFAR.[InstanceID],
			[VersionID] = WFAR.[VersionID],
			[WorkflowID] = @NewWorkflowID,
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[WorkflowStateID] = WFS.WorkflowStateId,
			[SecurityLevelBM]
		FROM
			[WorkflowAccessRight] WFAR
			INNER JOIN WorkflowState WFS ON WFS.InheritedFrom = WFAR.WorkflowStateID
		WHERE
			WFAR.[InstanceID] = @InstanceID AND
			WFAR.[VersionID] = @VersionID AND
			WFAR.[WorkflowID] = @FromWorkflowID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[WorkflowAccessRight] WAR WHERE WAR.[InstanceID] = WFAR.[InstanceID] AND WAR.[VersionID] = WFAR.[VersionID] AND WAR.[WorkflowID] = @NewWorkflowID AND WAR.[OrganizationHierarchyID] = WFAR.[OrganizationHierarchyID] AND WAR.OrganizationLevelNo = WFAR.OrganizationLevelNo AND WAR.WorkflowStateID = WFS.WorkflowStateId)

	SET @Step = 'Insert new data into table WorkflowStateChange.'
		INSERT INTO	[pcINTEGRATOR_Data].[dbo].[WorkflowStateChange]
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
			[InstanceID] = WFSC.[InstanceID],
			[VersionID] = WFSC.[VersionID],
			[WorkflowID] = @NewWorkflowID,
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[FromWorkflowStateID] = WFSF.WorkflowStateId,
			[ToWorkflowStateID] = WFST.WorkflowStateId,
			[UserChangeableYN],
			[BRChangeableYN]
		FROM
			[WorkflowStateChange] WFSC
			--INNER JOIN [WorkflowState] WFSF ON WFSF.InheritedFrom = WFSC.[FromWorkflowStateID]
			--INNER JOIN [WorkflowState] WFST ON WFST.InheritedFrom = WFSC.[ToWorkflowStateID]
			INNER JOIN [WorkflowState] WFSF ON WFSF.[WorkflowID] = @NewWorkflowID AND WFSF.InheritedFrom = WFSC.[FromWorkflowStateID]
			INNER JOIN [WorkflowState] WFST ON WFST.[WorkflowID] = @NewWorkflowID AND WFST.InheritedFrom = WFSC.[ToWorkflowStateID]
		WHERE
			WFSC.[InstanceID] = @InstanceID AND
			WFSC.[VersionID] = @VersionID AND
			WFSC.[WorkflowID] = @FromWorkflowID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WSC WHERE WSC.[InstanceID] = WFSC.[InstanceID] AND WSC.[VersionID] = WFSC.[VersionID] AND WSC.[WorkflowID] = @NewWorkflowID AND WSC.[OrganizationHierarchyID] = WFSC.[OrganizationHierarchyID] AND WSC.OrganizationLevelNo = WFSC.OrganizationLevelNo AND WSC.[FromWorkflowStateID] = WFSF.WorkflowStateId AND WSC.[ToWorkflowStateID] = WFST.WorkflowStateId)

	SET @Step = 'Insert new data into table Workflow_OrganizationLevel.'
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
			[InstanceID],
			[VersionID],
			[WorkflowID] = @NewWorkflowID,
			[OrganizationLevelNo],
			[LevelInWorkflowYN],
			[ExpectedDate],
			[ActionDescription]
		FROM
			[Workflow_OrganizationLevel] WFOL
		WHERE
			WFOL.[InstanceID] = @InstanceID AND
			WFOL.[VersionID] = @VersionID AND
			WFOL.[WorkflowID] = @FromWorkflowID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Workflow_OrganizationLevel] WOL WHERE WOL.WorkflowID = @NewWorkflowID AND WOL.OrganizationLevelNo = WFOL.OrganizationLevelNo)

	SET @Step = 'Insert new data into table Assignment.'
		DECLARE WF_Assignment_Cursor CURSOR FOR

			SELECT 
				[AssignmentName],
				[Comment],
				[OrganizationPositionID],
				[DataClassID],
				[GridID],
				[Priority],
				[InheritedFrom] = [AssignmentID]
			FROM
				[Assignment] A
			WHERE
				A.[InstanceID] = @InstanceID AND
				A.[VersionID] = @VersionID AND
				A.[WorkflowID] = @FromWorkflowID AND
				A.SelectYN <> 0 AND
				A.DeletedID IS NULL	

			OPEN WF_Assignment_Cursor
			FETCH NEXT FROM WF_Assignment_Cursor INTO @AssignmentName, @Comment, @OrganizationPositionID, @DataClassID, @GridID, @Priority, @InheritedFrom

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT @AssignmentName, @Comment, @OrganizationPositionID, @DataClassID, @GridID, @Priority, @InheritedFrom

					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Assignment]
						(
 						[InstanceID],
						[VersionID],
						[AssignmentName],
						[Comment],
						[OrganizationPositionID],
						[DataClassID],
						[WorkflowID],
						[GridID],
						[Priority],
						[InheritedFrom],
						[SelectYN]
						)
					SELECT
 						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[AssignmentName] = @AssignmentName,
						[Comment] = @Comment,
						[OrganizationPositionID] = @OrganizationPositionID,
						[DataClassID] = @DataClassID,
						[WorkflowID] = @NewWorkflowID,
						[GridID] = @GridID,
						[Priority] = @Priority,
						[InheritedFrom] = @InheritedFrom,
						[SelectYN] = 1

					FETCH NEXT FROM WF_Assignment_Cursor INTO @AssignmentName, @Comment, @OrganizationPositionID, @DataClassID, @GridID, @Priority, @InheritedFrom
				END

		CLOSE WF_Assignment_Cursor
		DEALLOCATE WF_Assignment_Cursor	

	SET @Step = 'Insert new data into table AssignmentRow.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[AssignmentRow]
			(
			[InstanceID],
			[VersionID],
			[AssignmentID],
			[DimensionID],
			[Dimension_MemberKey]
			)
		SELECT 
			[InstanceID] = AR.[InstanceID],
			[VersionID] = AR.[VersionID],
			[AssignmentID] = A.AssignmentID,
			[DimensionID] = AR.DimensionID,
			[Dimension_MemberKey] = AR.Dimension_MemberKey
		FROM
			[AssignmentRow] AR
			INNER JOIN [Assignment] A ON A.InstanceID = AR.InstanceID AND A.[VersionID] = AR.[VersionID] AND A.WorkflowID = @NewWorkflowID AND A.InheritedFrom = AR.AssignmentID
		WHERE
			AR.[InstanceID] = @InstanceID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[AssignmentRow] ARS WHERE ARS.[InstanceID] = AR.[InstanceID] AND ARS.[VersionID] = AR.[VersionID] AND ARS.[AssignmentID] = A.AssignmentID AND ARS.[DimensionID] = AR.DimensionID AND ARS.[Dimension_MemberKey] = AR.Dimension_MemberKey)

	SET @Step = 'Insert new data into table Assignment_OrganizationLevel.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel]
			(
			[InstanceID],
			[VersionID],
			[AssignmentID],
			[OrganizationLevelNo],
			[OrganizationPositionID],
			[LevelInWorkflowYN],
			[ExpectedDate],
			[ActionDescription],
			[GridID]
			)
		SELECT 
			[InstanceID] = AOL.InstanceID,
			[VersionID] = AOL.[VersionID],
			[AssignmentID] = A.AssignmentID,
			[OrganizationLevelNo],
			[OrganizationPositionID] = AOL.[OrganizationPositionID],
			[LevelInWorkflowYN],
			[ExpectedDate],
			[ActionDescription],
			[GridID] = AOL.GridID
		FROM
			[Assignment_OrganizationLevel] AOL
			INNER JOIN [Assignment] A ON A.InstanceID = AOL.InstanceID AND A.WorkflowID = @NewWorkflowID AND A.InheritedFrom = AOL.AssignmentID
		WHERE
			AOL.[InstanceID] = @InstanceID AND
			AOL.[VersionID] = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel] AOLS WHERE AOLS.[InstanceID] = AOL.InstanceID AND AOLS.[VersionID] = AOL.[VersionID] AND AOLS.[AssignmentID] = A.AssignmentID AND AOLS.OrganizationLevelNo = AOL.OrganizationLevelNo)

/*
Update RefreshActualsInitialWorkflowStateID in table Workflow

SELECT TOP (1000) [InstanceID]
      ,[WorkflowID]
      ,[WorkflowStateId]
      ,[WorkflowStateName]
      ,[InheritedFrom]
  FROM [pcINTEGRATOR].[dbo].[WorkflowState]
  WHERE InheritedFrom = 4481
*/

	SET @Step = 'Update WorkflowState dimension table.'
		SELECT
			@StorageTypeBM = StorageTypeBM
		FROM
			Dimension_StorageType
		WHERE
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND
			DimensionID = -63 --WorkflowState

		IF @StorageTypeBM & 2 > 0
			EXEC [spIU_Dim_WorkflowState] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID

		IF @StorageTypeBM & 4 > 0
			EXEC [spIU_Dim_WorkflowState_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID

	SET @Step = 'Set (copied ) Workflow to inactive.'
		UPDATE WF
		SET
			[SelectYN] = 0
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow] WF
		WHERE
			WF.[InstanceID] = @InstanceID AND
			WF.[VersionID] = @VersionID AND
			WF.[WorkflowID] = @NewWorkflowID

	SET @Step = 'Return value @NewWorkflowID.'
		SELECT NewWorkflowID = @NewWorkflowID

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
