SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SqlQuery] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[SqlQueryID],
	[sub].[SqlQueryName],
	[sub].[SqlQueryDescription],
	[sub].[SqlQuery],
	[sub].[SqlQueryGroupID],
	[sub].[RefID],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[SqlQueryID],
		[SqlQueryName],
		[SqlQueryDescription],
		[SqlQuery],
		[SqlQueryGroupID],
		[RefID],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SqlQuery]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[SqlQueryID],
		[SqlQueryName],
		[SqlQueryDescription],
		[SqlQuery],
		[SqlQueryGroupID],
		[RefID],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SqlQuery]
	) sub
GO
