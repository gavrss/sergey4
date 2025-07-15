SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR05_Rule_FX] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[Rule_FXID],
	[sub].[Rule_FXName],
	[sub].[JournalSequence],
	[sub].[DimensionFilter],
	[sub].[HistoricYN],
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
		[BusinessRuleID],
		[Rule_FXID],
		[Rule_FXName],
		[JournalSequence],
		[DimensionFilter],
		[HistoricYN],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Rule_FXID],
		[Rule_FXName],
		[JournalSequence],
		[DimensionFilter],
		[HistoricYN],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR05_Rule_FX]
	) sub
GO
