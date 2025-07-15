SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR01_Step] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[BR01_StepID],
	[sub].[BR01_StepPartID],
	[sub].[Comment],
	[sub].[MemberKey],
	[sub].[ModifierID],
	[sub].[Parameter],
	[sub].[DataClassID],
	[sub].[Decimal],
	[sub].[DimensionFilter],
	[sub].[ValueFilter],
	[sub].[Operator],
	[sub].[MultiplyWith],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR01_StepID],
		[BR01_StepPartID],
		[Comment],
		[MemberKey],
		[ModifierID],
		[Parameter],
		[DataClassID],
		[Decimal],
		[DimensionFilter],
		[ValueFilter],
		[Operator],
		[MultiplyWith],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR01_Step]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR01_StepID],
		[BR01_StepPartID],
		[Comment],
		[MemberKey],
		[ModifierID],
		[Parameter],
		[DataClassID],
		[Decimal],
		[DimensionFilter],
		[ValueFilter],
		[Operator],
		[MultiplyWith],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR01_Step]
	) sub
GO
