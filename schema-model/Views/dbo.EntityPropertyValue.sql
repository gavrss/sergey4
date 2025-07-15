SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[EntityPropertyValue] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[EntityID],
	[sub].[EntityPropertyTypeID],
	[sub].[EntityPropertyValue],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[EntityID],
		[EntityPropertyTypeID],
		[EntityPropertyValue],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[EntityPropertyValue]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[EntityID],
		[EntityPropertyTypeID],
		[EntityPropertyValue],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_EntityPropertyValue]
	) sub
GO
