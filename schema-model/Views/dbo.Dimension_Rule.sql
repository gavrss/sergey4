SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Dimension_Rule] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[Entity_MemberKey],
	[sub].[DimensionID],
	[sub].[MappingTypeID],
	[sub].[ReplaceTextYN],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[Entity_MemberKey],
		[DimensionID],
		[MappingTypeID],
		[ReplaceTextYN],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Dimension_Rule]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[Entity_MemberKey],
		[DimensionID],
		[MappingTypeID],
		[ReplaceTextYN],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Dimension_Rule]
	) sub
GO
