SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Mapping_DimensionRow] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[Mapping_DimensionGroupID],
	[sub].[RowID],
	[sub].[Updated],
	[sub].[UpdatedBy]
FROM
	(
	SELECT
		[InstanceID],
		[Mapping_DimensionGroupID],
		[RowID],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Mapping_DimensionRow]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[Mapping_DimensionGroupID],
		[RowID],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Mapping_DimensionRow]
	) sub
GO
