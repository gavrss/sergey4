SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Workflow_OrganizationLevel] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[WorkflowID],
	[sub].[OrganizationLevelNo],
	[sub].[LevelInWorkflowYN],
	[sub].[ExpectedDate],
	[sub].[ActionDescription]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[OrganizationLevelNo],
		[LevelInWorkflowYN],
		[ExpectedDate],
		[ActionDescription]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Workflow_OrganizationLevel]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[OrganizationLevelNo],
		[LevelInWorkflowYN],
		[ExpectedDate],
		[ActionDescription]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Workflow_OrganizationLevel]
	) sub
GO
