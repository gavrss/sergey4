SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[EntityHierarchy] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[EntityGroupID],
	[sub].[EntityID],
	[sub].[ParentID],
	[sub].[ValidFrom],
	[sub].[OwnershipDirect],
	[sub].[OwnershipUltimate],
	[sub].[OwnershipConsolidation],
	[sub].[ConsolidationMethodBM],
	[sub].[SortOrder],
	[sub].[ValidTo]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[EntityGroupID],
		[EntityID],
		[ParentID],
		[ValidFrom],
		[OwnershipDirect],
		[OwnershipUltimate],
		[OwnershipConsolidation],
		[ConsolidationMethodBM],
		[SortOrder],
		[ValidTo]
	FROM
		[pcINTEGRATOR_Data].[dbo].[EntityHierarchy]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[EntityGroupID],
		[EntityID],
		[ParentID],
		[ValidFrom],
		[OwnershipDirect],
		[OwnershipUltimate],
		[OwnershipConsolidation],
		[ConsolidationMethodBM],
		[SortOrder],
		[ValidTo]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_EntityHierarchy]
	) sub
GO
