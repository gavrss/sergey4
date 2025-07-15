SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SIE4_Ver] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[JobID],
	[sub].[Param],
	[sub].[Seq],
	[sub].[Ver],
	[sub].[Date],
	[sub].[Description],
	[sub].[Inserted],
	[sub].[InsertedBy]
FROM
	(
	SELECT
		[InstanceID],
		[JobID],
		[Param],
		[Seq],
		[Ver],
		[Date],
		[Description],
		[Inserted],
		[InsertedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SIE4_Ver]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[JobID],
		[Param],
		[Seq],
		[Ver],
		[Date],
		[Description],
		[Inserted],
		[InsertedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SIE4_Ver]
	) sub
GO
