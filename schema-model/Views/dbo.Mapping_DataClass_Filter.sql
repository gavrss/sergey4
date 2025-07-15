SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Mapping_DataClass_Filter] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[Mapping_DimensionGroupID],
	[sub].[DataClassPosition],
	[sub].[DimensionID],
	[sub].[MemberKey],
	[sub].[Updated],
	[sub].[UpdatedBy]
FROM
	(
	SELECT
		[InstanceID],
		[Mapping_DimensionGroupID],
		[DataClassPosition],
		[DimensionID],
		[MemberKey],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Mapping_DataClass_Filter]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[Mapping_DimensionGroupID],
		[DataClassPosition],
		[DimensionID],
		[MemberKey],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Mapping_DataClass_Filter]
	) sub
GO
