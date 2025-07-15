SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[OrganizationHierarchy_Process] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[OrganizationHierarchyID],
	[sub].[ProcessID]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationHierarchyID],
		[ProcessID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationHierarchyID],
		[ProcessID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_OrganizationHierarchy_Process]
	) sub
GO
