SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR05_Rule_ICmatch] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[Rule_ICmatchID],
	[sub].[Rule_ICmatchName],
	[sub].[DimensionFilter],
	[sub].[AccountInterCoDiffManual],
	[sub].[AccountInterCoDiffAuto],
	[sub].[Source],
	[sub].[SortOrder],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[Rule_ICmatchID],
		[Rule_ICmatchName],
		[DimensionFilter],
		[AccountInterCoDiffManual],
		[AccountInterCoDiffAuto],
		[Source],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR05_Rule_ICmatch]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[Rule_ICmatchID],
		[Rule_ICmatchName],
		[DimensionFilter],
		[AccountInterCoDiffManual],
		[AccountInterCoDiffAuto],
		[Source],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR05_Rule_ICmatch]
	) sub
GO
