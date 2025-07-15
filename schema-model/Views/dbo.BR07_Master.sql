SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR07_Master] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[Comment],
	[sub].[DimensionID],
	[sub].[HierarchyNo],
	[sub].[DeletedID],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Comment],
		[DimensionID],
		[HierarchyNo],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR07_Master]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Comment],
		[DimensionID],
		[HierarchyNo],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR07_Master]
	) sub
GO
