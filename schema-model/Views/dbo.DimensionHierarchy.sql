SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DimensionHierarchy] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DimensionID],
	[sub].[HierarchyNo],
	[sub].[HierarchyName],
	[sub].[HierarchyTypeID],
	[sub].[FixedLevelsYN],
	[sub].[BaseDimension],
	[sub].[BaseHierarchy],
	[sub].[BaseDimensionFilter],
	[sub].[PropertyHierarchy],
	[sub].[BusinessRuleID],
	[sub].[DimensionFilter],
	[sub].[LockedYN],
	[sub].[Version]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[DimensionID],
		[HierarchyNo],
		[HierarchyName],
		[HierarchyTypeID],
		[FixedLevelsYN],
		[BaseDimension],
		[BaseHierarchy],
		[BaseDimensionFilter],
		[PropertyHierarchy],
		[BusinessRuleID],
		[DimensionFilter],
		[LockedYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[DimensionID],
		[HierarchyNo],
		[HierarchyName],
		[HierarchyTypeID],
		[FixedLevelsYN],
		[BaseDimension],
		[BaseHierarchy],
		[BaseDimensionFilter],
		[PropertyHierarchy],
		[BusinessRuleID],
		[DimensionFilter],
		[LockedYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy]
	) sub
GO
