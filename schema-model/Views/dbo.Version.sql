SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Version] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[VersionName],
	[sub].[VersionDescription],
	[sub].[EnvironmentLevelID],
	[sub].[ModelingLockedYN],
	[sub].[DataLockedYN],
	[sub].[ErasableYN],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[VersionName],
		[VersionDescription],
		[EnvironmentLevelID],
		[ModelingLockedYN],
		[DataLockedYN],
		[ErasableYN],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Version]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[VersionName],
		[VersionDescription],
		[EnvironmentLevelID],
		[ModelingLockedYN],
		[DataLockedYN],
		[ErasableYN],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Version]
	) sub
GO
