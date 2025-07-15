SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Workflow_LiveFcstNextFlow] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[WorkflowID],
	[sub].[LiveFcstNextFlowID],
	[sub].[WorkflowStateID],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[LiveFcstNextFlowID],
		[WorkflowStateID],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[LiveFcstNextFlowID],
		[WorkflowStateID],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Workflow_LiveFcstNextFlow]
	) sub
GO
