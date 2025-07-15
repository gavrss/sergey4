SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR03_Rule_Allocation_Row] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[Rule_AllocationID],
	[sub].[Rule_Allocation_RowID],
	[sub].[MultiDimSetting],
	[sub].[CrossEntityYN],
	[sub].[BaseRow],
	[sub].[Factor],
	[sub].[Sign],
	[sub].[InheritedFrom],
	[sub].[SortOrder],
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
		[Rule_Allocation_RowID],
		[MultiDimSetting],
		[CrossEntityYN],
		[BaseRow],
		[Factor],
		[Sign],
		[InheritedFrom],
		[SortOrder],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR03_Rule_Allocation_Row]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Rule_AllocationID],
		[Rule_Allocation_RowID],
		[MultiDimSetting],
		[CrossEntityYN],
		[BaseRow],
		[Factor],
		[Sign],
		[InheritedFrom],
		[SortOrder],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR03_Rule_Allocation_Row]
	) sub
GO
