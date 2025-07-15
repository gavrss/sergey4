SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[GridAxis] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[GridAxisID],
	[sub].[GridAxisName],
	[sub].[GridAxisDescription],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[GridAxisID],
		[GridAxisName],
		[GridAxisDescription],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[GridAxis]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[GridAxisID],
		[GridAxisName],
		[GridAxisDescription],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_GridAxis]
	) sub
GO
