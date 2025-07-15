SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR05_Rule_Consolidation] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[Rule_ConsolidationID],
	[sub].[Rule_ConsolidationName],
	[sub].[JournalSequence],
	[sub].[DimensionFilter],
	[sub].[ConsolidationMethodBM],
	[sub].[ModifierID],
	[sub].[OnlyInterCompanyInGroupYN],
	[sub].[FunctionalCurrencyYN],
	[sub].[UsePreviousStepYN],
	[sub].[MovementYN],
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
		[Rule_ConsolidationID],
		[Rule_ConsolidationName],
		[JournalSequence],
		[DimensionFilter],
		[ConsolidationMethodBM],
		[ModifierID],
		[OnlyInterCompanyInGroupYN],
		[FunctionalCurrencyYN],
		[UsePreviousStepYN],
		[MovementYN],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Rule_ConsolidationID],
		[Rule_ConsolidationName],
		[JournalSequence],
		[DimensionFilter],
		[ConsolidationMethodBM],
		[ModifierID],
		[OnlyInterCompanyInGroupYN],
		[FunctionalCurrencyYN],
		[UsePreviousStepYN],
		[MovementYN],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR05_Rule_Consolidation]
	) sub
GO
