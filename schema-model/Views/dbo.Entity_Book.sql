SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Entity_Book] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[EntityID],
	[sub].[Book],
	[sub].[Currency],
	[sub].[BookTypeBM],
	[sub].[SelectYN],
	[sub].[Version],
	[sub].[COA],
	[sub].[BalanceType]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[EntityID],
		[Book],
		[Currency],
		[BookTypeBM],
		[SelectYN],
		[Version],
		[COA],
		[BalanceType]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Entity_Book]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[EntityID],
		[Book],
		[Currency],
		[BookTypeBM],
		[SelectYN],
		[Version],
		[COA],
		[BalanceType]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Entity_Book]
	) sub
GO
