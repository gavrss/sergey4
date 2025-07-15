SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Measure_Property] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[MeasureID],
	[sub].[PropertyID],
	[sub].[Value]
FROM
	(
	SELECT
		[InstanceID],
		[MeasureID],
		[PropertyID],
		[Value]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Measure_Property]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[MeasureID],
		[PropertyID],
		[Value]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Measure_Property]
	) sub
GO
