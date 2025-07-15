SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SIE4_Object] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[JobID],
	[sub].[Param],
	[sub].[DimCode],
	[sub].[ObjectCode],
	[sub].[ObjectName],
	[sub].[Inserted],
	[sub].[InsertedBy]
FROM
	(
	SELECT
		[InstanceID],
		[JobID],
		[Param],
		[DimCode],
		[ObjectCode],
		[ObjectName],
		[Inserted],
		[InsertedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SIE4_Object]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[JobID],
		[Param],
		[DimCode],
		[ObjectCode],
		[ObjectName],
		[Inserted],
		[InsertedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SIE4_Object]
	) sub
GO
