SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Dimension_Property] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DimensionID],
	[sub].[PropertyID],
	[sub].[DependencyPrio],
	[sub].[TabularYN],
	[sub].[SortOrder],
	[sub].[Introduced],
	[sub].[SelectYN],
	[sub].[Version],
	[sub].[MultiDimYN],
	[sub].[NodeTypeBM]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[DimensionID],
		[PropertyID],
		[DependencyPrio],
		[TabularYN],
		[SortOrder],
		[Introduced],
		[SelectYN],
		[Version],
		[MultiDimYN],
		[NodeTypeBM]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Dimension_Property]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[DimensionID],
		[PropertyID],
		[DependencyPrio],
		[TabularYN],
		[SortOrder],
		[Introduced],
		[SelectYN],
		[Version],
		[MultiDimYN],
		[NodeTypeBM]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Dimension_Property]
	) sub
GO
