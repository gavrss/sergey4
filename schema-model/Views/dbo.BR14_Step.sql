SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR14_Step] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[BR14_StepID],
	[sub].[ICCounterpart],
	[sub].[Method],
	[sub].[DimensionFilter],
	[sub].[SortOrder],
	[sub].[Version]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR14_StepID],
		[ICCounterpart],
		[Method],
		[DimensionFilter],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR14_Step]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR14_StepID],
		[ICCounterpart],
		[Method],
		[DimensionFilter],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR14_Step]
	) sub
GO
