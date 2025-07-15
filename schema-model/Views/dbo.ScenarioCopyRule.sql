SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[ScenarioCopyRule] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[CopyRuleID],
	[sub].[ToDataClassID],
	[sub].[FromDataClassID],
	[sub].[DimensionID],
	[sub].[MeasureID],
	[sub].[SetTo_MemberKey],
	[sub].[SetTo_Column],
	[sub].[Filter_MemberKey],
	[sub].[CaseFilter_MemberKey],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[CopyRuleID],
		[ToDataClassID],
		[FromDataClassID],
		[DimensionID],
		[MeasureID],
		[SetTo_MemberKey],
		[SetTo_Column],
		[Filter_MemberKey],
		[CaseFilter_MemberKey],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[ScenarioCopyRule]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[CopyRuleID],
		[ToDataClassID],
		[FromDataClassID],
		[DimensionID],
		[MeasureID],
		[SetTo_MemberKey],
		[SetTo_Column],
		[Filter_MemberKey],
		[CaseFilter_MemberKey],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_ScenarioCopyRule]
	) sub
GO
