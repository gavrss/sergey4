SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Extension] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[ExtensionID],
	[sub].[ExtensionName],
	[sub].[ApplicationID],
	[sub].[ExtensionTypeID],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[ExtensionID],
		[ExtensionName],
		[ApplicationID],
		[ExtensionTypeID],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Extension]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[ExtensionID],
		[ExtensionName],
		[ApplicationID],
		[ExtensionTypeID],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Extension]
	) sub
GO
