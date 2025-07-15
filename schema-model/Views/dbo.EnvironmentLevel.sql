SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[EnvironmentLevel] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[EnvironmentLevelID],
	[sub].[EnvironmentLevelName],
	[sub].[EnvironmentLevelDescription],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[EnvironmentLevelID],
		[EnvironmentLevelName],
		[EnvironmentLevelDescription],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[EnvironmentLevel]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[EnvironmentLevelID],
		[EnvironmentLevelName],
		[EnvironmentLevelDescription],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_EnvironmentLevel]
	) sub
GO
