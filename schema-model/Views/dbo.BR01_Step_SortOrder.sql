SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR01_Step_SortOrder] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[BR01_StepID],
	[sub].[SortOrder],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR01_StepID],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR01_Step_SortOrder]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR01_StepID],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR01_Step_SortOrder]
	) sub
GO
