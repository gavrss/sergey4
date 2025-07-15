SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Journal_SegmentNo] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[JobID],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[EntityID],
	[sub].[Book],
	[sub].[SegmentCode],
	[sub].[SourceCode],
	[sub].[SegmentNo],
	[sub].[SegmentName],
	[sub].[DimensionID],
	[sub].[BalanceAdjYN],
	[sub].[MaskPosition],
	[sub].[MaskCharacters],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[Comment],
		[JobID],
		[InstanceID],
		[VersionID],
		[EntityID],
		[Book],
		[SegmentCode],
		[SourceCode],
		[SegmentNo],
		[SegmentName],
		[DimensionID],
		[BalanceAdjYN],
		[MaskPosition],
		[MaskCharacters],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[JobID],
		[InstanceID],
		[VersionID],
		[EntityID],
		[Book],
		[SegmentCode],
		[SourceCode],
		[SegmentNo],
		[SegmentName],
		[DimensionID],
		[BalanceAdjYN],
		[MaskPosition],
		[MaskCharacters],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Journal_SegmentNo]
	) sub
GO
