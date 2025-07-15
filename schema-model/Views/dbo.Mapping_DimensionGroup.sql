SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Mapping_DimensionGroup] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[Comment],
	[sub].[Mapping_DataClassID],
	[sub].[Mapping_DimensionGroupID],
	[sub].[Updated],
	[sub].[UpdatedBy]
FROM
	(
	SELECT
		[InstanceID],
		[Comment],
		[Mapping_DataClassID],
		[Mapping_DimensionGroupID],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Mapping_DimensionGroup]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[Comment],
		[Mapping_DataClassID],
		[Mapping_DimensionGroupID],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Mapping_DimensionGroup]
	) sub
GO
