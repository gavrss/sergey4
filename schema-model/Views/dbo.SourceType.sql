SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SourceType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[SourceTypeID],
	[sub].[SourceTypeName],
	[sub].[SourceTypeDescription],
	[sub].[SourceTypeBM],
	[sub].[SourceTypeFamilyID],
	[sub].[SourceDBTypeID],
	[sub].[Owner],
	[sub].[BrandBM],
	[sub].[Introduced],
	[sub].[SelectYN],
	[sub].[SortOrder],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[SourceTypeID],
		[SourceTypeName],
		[SourceTypeDescription],
		[SourceTypeBM],
		[SourceTypeFamilyID],
		[SourceDBTypeID],
		[Owner],
		[BrandBM],
		[Introduced],
		[SelectYN],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SourceType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[SourceTypeID],
		[SourceTypeName],
		[SourceTypeDescription],
		[SourceTypeBM],
		[SourceTypeFamilyID],
		[SourceDBTypeID],
		[Owner],
		[BrandBM],
		[Introduced],
		[SelectYN],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SourceType]
	) sub
GO
