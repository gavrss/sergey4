SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Property] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[PropertyID],
	[sub].[PropertyName],
	[sub].[PropertyDescription],
	[sub].[ObjectGuiBehaviorBM],
	[sub].[DataTypeID],
	[sub].[Size],
	[sub].[DependentDimensionID],
	[sub].[StringTypeBM],
	[sub].[DynamicYN],
	[sub].[DefaultValueTable],
	[sub].[DefaultValueView],
	[sub].[SynchronizedYN],
	[sub].[SortOrder],
	[sub].[SourceTypeBM],
	[sub].[StorageTypeBM],
	[sub].[ViewPropertyYN],
	[sub].[HierarchySortOrderYN],
	[sub].[MandatoryYN],
	[sub].[DefaultSelectYN],
	[sub].[Introduced],
	[sub].[SelectYN],
	[sub].[Version],
	[sub].[DefaultNodeTypeBM],
	[sub].[InheritedFrom]
FROM
	(
	SELECT
		[InstanceID],
		[PropertyID],
		[PropertyName],
		[PropertyDescription],
		[ObjectGuiBehaviorBM],
		[DataTypeID],
		[Size],
		[DependentDimensionID],
		[StringTypeBM],
		[DynamicYN],
		[DefaultValueTable],
		[DefaultValueView],
		[SynchronizedYN],
		[SortOrder],
		[SourceTypeBM],
		[StorageTypeBM],
		[ViewPropertyYN],
		[HierarchySortOrderYN],
		[MandatoryYN],
		[DefaultSelectYN],
		[Introduced],
		[SelectYN],
		[Version],
		[DefaultNodeTypeBM],
		[InheritedFrom]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Property]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[PropertyID],
		[PropertyName],
		[PropertyDescription],
		[ObjectGuiBehaviorBM],
		[DataTypeID],
		[Size],
		[DependentDimensionID],
		[StringTypeBM],
		[DynamicYN],
		[DefaultValueTable],
		[DefaultValueView],
		[SynchronizedYN],
		[SortOrder],
		[SourceTypeBM],
		[StorageTypeBM],
		[ViewPropertyYN],
		[HierarchySortOrderYN],
		[MandatoryYN],
		[DefaultSelectYN],
		[Introduced],
		[SelectYN],
		[Version],
		[DefaultNodeTypeBM],
		[InheritedFrom]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Property]
	) sub
GO
