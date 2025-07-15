SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DimensionHierarchyLevel] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DimensionID],
	[sub].[HierarchyNo],
	[sub].[LevelNo],
	[sub].[LevelName],
	[sub].[Version]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[DimensionID],
		[HierarchyNo],
		[LevelNo],
		[LevelName],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[DimensionID],
		[HierarchyNo],
		[LevelNo],
		[LevelName],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DimensionHierarchyLevel]
	) sub
GO
