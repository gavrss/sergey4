SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Workflow] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[WorkflowID],
	[sub].[VersionID],
	[sub].[WorkflowName],
	[sub].[ProcessID],
	[sub].[ScenarioID],
	[sub].[CompareScenarioID],
	[sub].[TimeFrom],
	[sub].[TimeTo],
	[sub].[TimeOffsetFrom],
	[sub].[TimeOffsetTo],
	[sub].[InitialWorkflowStateID],
	[sub].[RefreshActualsInitialWorkflowStateID],
	[sub].[SpreadingKeyID],
	[sub].[LiveFcstNext_TimeFrom],
	[sub].[LiveFcstNext_TimeTo],
	[sub].[LiveFcstNext_ClosedMonth],
	[sub].[ModelingStatusID],
	[sub].[ModelingComment],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[WorkflowID],
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
		[LiveFcstNext_TimeFrom],
		[LiveFcstNext_TimeTo],
		[LiveFcstNext_ClosedMonth],
		[ModelingStatusID],
		[ModelingComment],
		[InheritedFrom],
		[SelectYN],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Workflow]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[WorkflowID],
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
		[LiveFcstNext_TimeFrom],
		[LiveFcstNext_TimeTo],
		[LiveFcstNext_ClosedMonth],
		[ModelingStatusID],
		[ModelingComment],
		[InheritedFrom],
		[SelectYN],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Workflow]
	) sub
GO
