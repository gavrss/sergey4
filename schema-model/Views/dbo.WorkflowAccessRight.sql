SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[WorkflowAccessRight] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[WorkflowID],
	[sub].[OrganizationHierarchyID],
	[sub].[OrganizationLevelNo],
	[sub].[WorkflowStateID],
	[sub].[SecurityLevelBM]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[OrganizationHierarchyID],
		[OrganizationLevelNo],
		[WorkflowStateID],
		[SecurityLevelBM]
	FROM
		[pcINTEGRATOR_Data].[dbo].[WorkflowAccessRight]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[OrganizationHierarchyID],
		[OrganizationLevelNo],
		[WorkflowStateID],
		[SecurityLevelBM]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_WorkflowAccessRight]
	) sub
GO
