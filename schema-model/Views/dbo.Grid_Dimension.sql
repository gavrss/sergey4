SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Grid_Dimension] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[GridID],
	[sub].[DimensionID],
	[sub].[GridAxisID],
	[sub].[Version],
	[sub].[VersionID]
FROM
	(
	SELECT
		[InstanceID],
		[GridID],
		[DimensionID],
		[GridAxisID],
		[Version],
		[VersionID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Grid_Dimension]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[GridID],
		[DimensionID],
		[GridAxisID],
		[Version],
		[VersionID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Grid_Dimension]
	) sub
GO
