SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Menu] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[MenuID],
	[sub].[VersionID],
	[sub].[MenuName],
	[sub].[MenuDescription],
	[sub].[MenuParentID],
	[sub].[MenuTypeBM],
	[sub].[MenuItemTypeID],
	[sub].[MenuParameter],
	[sub].[LicenseYN],
	[sub].[ExistYN],
	[sub].[SecurityYN],
	[sub].[SortOrder],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[MenuID],
		[VersionID],
		[MenuName],
		[MenuDescription],
		[MenuParentID],
		[MenuTypeBM],
		[MenuItemTypeID],
		[MenuParameter],
		[LicenseYN],
		[ExistYN],
		[SecurityYN],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Menu]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[MenuID],
		[VersionID],
		[MenuName],
		[MenuDescription],
		[MenuParentID],
		[MenuTypeBM],
		[MenuItemTypeID],
		[MenuParameter],
		[LicenseYN],
		[ExistYN],
		[SecurityYN],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Menu]
	) sub
GO
