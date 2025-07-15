SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Grid] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[GridID],
	[sub].[GridName],
	[sub].[GridDescription],
	[sub].[DataClassID],
	[sub].[GridSkinID],
	[sub].[GetProc],
	[sub].[SetProc],
	[sub].[InheritedFrom],
	[sub].[Version],
	[sub].[VersionID]
FROM
	(
	SELECT
		[InstanceID],
		[GridID],
		[GridName],
		[GridDescription],
		[DataClassID],
		[GridSkinID],
		[GetProc],
		[SetProc],
		[InheritedFrom],
		[Version],
		[VersionID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Grid]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[GridID],
		[GridName],
		[GridDescription],
		[DataClassID],
		[GridSkinID],
		[GetProc],
		[SetProc],
		[InheritedFrom],
		[Version],
		[VersionID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Grid]
	) sub
GO
