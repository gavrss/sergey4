SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR12_Step] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[BR12_StepID],
	[sub].[Comment],
	[sub].[MemberKey],
	[sub].[DimensionFilter],
	[sub].[SortOrder],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR12_StepID],
		[Comment],
		[MemberKey],
		[DimensionFilter],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR12_Step]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR12_StepID],
		[Comment],
		[MemberKey],
		[DimensionFilter],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR12_Step]
	) sub
GO
