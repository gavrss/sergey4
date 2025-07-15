SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[LoginToken] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[UserID],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[Token],
	[sub].[ValidUntil],
	[sub].[Inserted]
FROM
	(
	SELECT
		[UserID],
		[InstanceID],
		[VersionID],
		[Token],
		[ValidUntil],
		[Inserted]
	FROM
		[pcINTEGRATOR_Data].[dbo].[LoginToken]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[UserID],
		[InstanceID],
		[VersionID],
		[Token],
		[ValidUntil],
		[Inserted]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_LoginToken]
	) sub
GO
