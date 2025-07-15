SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DimensionType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[DimensionTypeID],
	[sub].[DimensionTypeName],
	[sub].[AS_DimensionTypeName],
	[sub].[DimensionTypeDescription],
	[sub].[ExtensionYN],
	[sub].[DimensionTypeGroupID],
	[sub].[SecuredYN],
	[sub].[MappingEnabledYN],
	[sub].[DefaultMappingTypeID],
	[sub].[ReplaceTextEnabledYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[DimensionTypeID],
		[DimensionTypeName],
		[AS_DimensionTypeName],
		[DimensionTypeDescription],
		[ExtensionYN],
		[DimensionTypeGroupID],
		[SecuredYN],
		[MappingEnabledYN],
		[DefaultMappingTypeID],
		[ReplaceTextEnabledYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DimensionType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[DimensionTypeID],
		[DimensionTypeName],
		[AS_DimensionTypeName],
		[DimensionTypeDescription],
		[ExtensionYN],
		[DimensionTypeGroupID],
		[SecuredYN],
		[MappingEnabledYN],
		[DefaultMappingTypeID],
		[ReplaceTextEnabledYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DimensionType]
	) sub
GO
