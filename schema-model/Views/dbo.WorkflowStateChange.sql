SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[WorkflowStateChange] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[WorkflowID],
	[sub].[OrganizationHierarchyID],
	[sub].[OrganizationLevelNo],
	[sub].[FromWorkflowStateID],
	[sub].[ToWorkflowStateID],
	[sub].[UserChangeableYN],
	[sub].[BRChangeableYN]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[OrganizationHierarchyID],
		[OrganizationLevelNo],
		[FromWorkflowStateID],
		[ToWorkflowStateID],
		[UserChangeableYN],
		[BRChangeableYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[WorkflowStateChange]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[OrganizationHierarchyID],
		[OrganizationLevelNo],
		[FromWorkflowStateID],
		[ToWorkflowStateID],
		[UserChangeableYN],
		[BRChangeableYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_WorkflowStateChange]
	) sub
GO
