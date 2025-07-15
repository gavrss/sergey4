SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SqlQueryGroup] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[SqlQueryGroupID],
	[sub].[SqlQueryGroupName],
	[sub].[SqlQueryGroupDescription],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[SqlQueryGroupID],
		[SqlQueryGroupName],
		[SqlQueryGroupDescription],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SqlQueryGroup]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[SqlQueryGroupID],
		[SqlQueryGroupName],
		[SqlQueryGroupDescription],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SqlQueryGroup]
	) sub
GO
