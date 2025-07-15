SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SqlSource_Model_FACT] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[Comment],
	[sub].[DimensionID],
	[sub].[SourceTypeBM],
	[sub].[RevisionBM],
	[sub].[ModelBM],
	[sub].[LinkedBM],
	[sub].[SequenceBM],
	[sub].[Variance],
	[sub].[GroupByYN],
	[sub].[ReplaceTextYN],
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
		[LinkedBM],
		[SequenceBM],
		[Variance],
		[GroupByYN],
		[ReplaceTextYN],
		[SourceString],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SqlSource_Model_FACT]
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
		[LinkedBM],
		[SequenceBM],
		[Variance],
		[GroupByYN],
		[ReplaceTextYN],
		[SourceString],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SqlSource_Model_FACT]
	) sub
GO
