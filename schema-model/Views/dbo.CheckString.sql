SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[CheckString] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[Input],
	[sub].[StringTypeBM],
	[sub].[Output],
	[sub].[Comment],
	[sub].[ScanYN],
	[sub].[ReplaceYN]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[Input],
		[StringTypeBM],
		[Output],
		[Comment],
		[ScanYN],
		[ReplaceYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[CheckString]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[Input],
		[StringTypeBM],
		[Output],
		[Comment],
		[ScanYN],
		[ReplaceYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_CheckString]
	) sub
GO
