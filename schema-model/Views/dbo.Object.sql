SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Object] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[ObjectID],
	[sub].[ObjectName],
	[sub].[ObjectTypeBM],
	[sub].[ParentObjectID],
	[sub].[SecurityLevelBM],
	[sub].[InheritedFrom],
	[sub].[SortOrder],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[ObjectID],
		[ObjectName],
		[ObjectTypeBM],
		[ParentObjectID],
		[SecurityLevelBM],
		[InheritedFrom],
		[SortOrder],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Object]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[ObjectID],
		[ObjectName],
		[ObjectTypeBM],
		[ParentObjectID],
		[SecurityLevelBM],
		[InheritedFrom],
		[SortOrder],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Object]
	) sub
GO
