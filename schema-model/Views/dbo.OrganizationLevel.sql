SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[OrganizationLevel] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[OrganizationHierarchyID],
	[sub].[OrganizationLevelNo],
	[sub].[OrganizationLevelName]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationHierarchyID],
		[OrganizationLevelNo],
		[OrganizationLevelName]
	FROM
		[pcINTEGRATOR_Data].[dbo].[OrganizationLevel]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationHierarchyID],
		[OrganizationLevelNo],
		[OrganizationLevelName]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_OrganizationLevel]
	) sub
GO
