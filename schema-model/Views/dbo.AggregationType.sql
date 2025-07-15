SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[AggregationType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[AggregationTypeID],
	[sub].[AggregationTypeName],
	[sub].[AggregationTypeDescription],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[AggregationTypeID],
		[AggregationTypeName],
		[AggregationTypeDescription],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[AggregationType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[AggregationTypeID],
		[AggregationTypeName],
		[AggregationTypeDescription],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_AggregationType]
	) sub
GO
