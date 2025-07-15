SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Dimension_StorageType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DimensionID],
	[sub].[StorageTypeBM],
	[sub].[ObjectGuiBehaviorBM],
	[sub].[ReadSecurityEnabledYN],
	[sub].[Version],
	[sub].[MappingTypeID],
	[sub].[NumberHierarchy],
	[sub].[ReplaceStringYN],
	[sub].[DefaultSetMemberKey],
	[sub].[DefaultGetMemberKey],
	[sub].[DefaultGetHierarchyNo],
	[sub].[DimensionFilter],
	[sub].[ETLProcedure]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[DimensionID],
		[StorageTypeBM],
		[ObjectGuiBehaviorBM],
		[ReadSecurityEnabledYN],
		[Version],
		[MappingTypeID],
		[NumberHierarchy],
		[ReplaceStringYN],
		[DefaultSetMemberKey],
		[DefaultGetMemberKey],
		[DefaultGetHierarchyNo],
		[DimensionFilter],
		[ETLProcedure]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[DimensionID],
		[StorageTypeBM],
		[ObjectGuiBehaviorBM],
		[ReadSecurityEnabledYN],
		[Version],
		[MappingTypeID],
		[NumberHierarchy],
		[ReplaceStringYN],
		[DefaultSetMemberKey],
		[DefaultGetMemberKey],
		[DefaultGetHierarchyNo],
		[DimensionFilter],
		[ETLProcedure]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Dimension_StorageType]
	) sub
GO
