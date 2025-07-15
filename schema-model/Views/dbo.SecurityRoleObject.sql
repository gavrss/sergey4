SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SecurityRoleObject] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[SecurityRoleID],
	[sub].[ObjectID],
	[sub].[SecurityLevelBM],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[SecurityRoleID],
		[ObjectID],
		[SecurityLevelBM],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[SecurityRoleID],
		[ObjectID],
		[SecurityLevelBM],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SecurityRoleObject]
	) sub
GO
