SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR03_Rule_Allocation] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[Rule_AllocationID],
	[sub].[Rule_AllocationName],
	[sub].[JournalSequence],
	[sub].[Source_DataClassID],
	[sub].[Source_DimensionFilter],
	[sub].[Across_DataClassID],
	[sub].[Across_Member],
	[sub].[Across_WithinDim],
	[sub].[Across_Basis],
	[sub].[Across_Member_Default],
	[sub].[JournalOnlyYN],
	[sub].[ModifierID],
	[sub].[Parameter],
	[sub].[StartTime],
	[sub].[EndTime],
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
		[Rule_AllocationID],
		[Rule_AllocationName],
		[JournalSequence],
		[Source_DataClassID],
		[Source_DimensionFilter],
		[Across_DataClassID],
		[Across_Member],
		[Across_WithinDim],
		[Across_Basis],
		[Across_Member_Default],
		[JournalOnlyYN],
		[ModifierID],
		[Parameter],
		[StartTime],
		[EndTime],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR03_Rule_Allocation]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Rule_AllocationID],
		[Rule_AllocationName],
		[JournalSequence],
		[Source_DataClassID],
		[Source_DimensionFilter],
		[Across_DataClassID],
		[Across_Member],
		[Across_WithinDim],
		[Across_Basis],
		[Across_Member_Default],
		[JournalOnlyYN],
		[ModifierID],
		[Parameter],
		[StartTime],
		[EndTime],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR03_Rule_Allocation]
	) sub
GO
