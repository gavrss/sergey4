SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DataClass_Dimension] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DataClassID],
	[sub].[DimensionID],
	[sub].[ChangeableYN],
	[sub].[Conversion_MemberKey],
	[sub].[TabularYN],
	[sub].[DataClassViewBM],
	[sub].[FilterLevel],
	[sub].[SortOrder],
	[sub].[Version],
	[sub].[SelectYN]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[DimensionID],
		[ChangeableYN],
		[Conversion_MemberKey],
		[TabularYN],
		[DataClassViewBM],
		[FilterLevel],
		[SortOrder],
		[Version],
		[SelectYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[DimensionID],
		[ChangeableYN],
		[Conversion_MemberKey],
		[TabularYN],
		[DataClassViewBM],
		[FilterLevel],
		[SortOrder],
		[Version],
		[SelectYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DataClass_Dimension]
	) sub
GO
