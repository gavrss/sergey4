SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR05_Rule_Consolidation_Row] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[Rule_ConsolidationID],
	[sub].[Rule_Consolidation_RowID],
	[sub].[DestinationEntity],
	[sub].[Account],
	[sub].[Flow],
	[sub].[Sign],
	[sub].[FormulaAmountID],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version],
	[sub].[NaturalAccountOnlyYN],
	[sub].[SortOrder]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Rule_ConsolidationID],
		[Rule_Consolidation_RowID],
		[DestinationEntity],
		[Account],
		[Flow],
		[Sign],
		[FormulaAmountID],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[NaturalAccountOnlyYN],
		[SortOrder]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation_Row]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Rule_ConsolidationID],
		[Rule_Consolidation_RowID],
		[DestinationEntity],
		[Account],
		[Flow],
		[Sign],
		[FormulaAmountID],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[NaturalAccountOnlyYN],
		[SortOrder]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR05_Rule_Consolidation_Row]
	) sub
GO
