SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Entity_FiscalYear] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[Entity_FiscalYearID],
	[sub].[EntityID],
	[sub].[Book],
	[sub].[StartMonth],
	[sub].[EndMonth],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[Entity_FiscalYearID],
		[EntityID],
		[Book],
		[StartMonth],
		[EndMonth],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[Entity_FiscalYearID],
		[EntityID],
		[Book],
		[StartMonth],
		[EndMonth],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Entity_FiscalYear]
	) sub
GO
