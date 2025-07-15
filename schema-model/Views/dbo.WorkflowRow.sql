SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[WorkflowRow] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[WorkflowID],
	[sub].[DimensionID],
	[sub].[Dimension_MemberKey],
	[sub].[CogentYN]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[DimensionID],
		[Dimension_MemberKey],
		[CogentYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[WorkflowRow]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[DimensionID],
		[Dimension_MemberKey],
		[CogentYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_WorkflowRow]
	) sub
GO
