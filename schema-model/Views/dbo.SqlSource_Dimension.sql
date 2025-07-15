SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SqlSource_Dimension] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[Comment],
	[sub].[DimensionID],
	[sub].[SourceTypeBM],
	[sub].[RevisionBM],
	[sub].[ModelBM],
	[sub].[PropertyID],
	[sub].[LinkedBM],
	[sub].[SequenceBM],
	[sub].[SubQuery],
	[sub].[Variance],
	[sub].[LeafLevelYN],
	[sub].[GroupByYN],
	[sub].[ReplaceTextEnabledYN],
	[sub].[SourceString],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[Comment],
		[DimensionID],
		[SourceTypeBM],
		[RevisionBM],
		[ModelBM],
		[PropertyID],
		[LinkedBM],
		[SequenceBM],
		[SubQuery],
		[Variance],
		[LeafLevelYN],
		[GroupByYN],
		[ReplaceTextEnabledYN],
		[SourceString],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SqlSource_Dimension]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[Comment],
		[DimensionID],
		[SourceTypeBM],
		[RevisionBM],
		[ModelBM],
		[PropertyID],
		[LinkedBM],
		[SequenceBM],
		[SubQuery],
		[Variance],
		[LeafLevelYN],
		[GroupByYN],
		[ReplaceTextEnabledYN],
		[SourceString],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SqlSource_Dimension]
	) sub
GO
