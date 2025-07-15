SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR01_Master] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[Comment],
	[sub].[DataClassID],
	[sub].[BaseObject],
	[sub].[BeforeFxYN],
	[sub].[DimensionSetting],
	[sub].[DimensionFilter],
	[sub].[PreExec],
	[sub].[PostExec],
	[sub].[InheritedFrom],
	[sub].[DeletedID],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Comment],
		[DataClassID],
		[BaseObject],
		[BeforeFxYN],
		[DimensionSetting],
		[DimensionFilter],
		[PreExec],
		[PostExec],
		[InheritedFrom],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR01_Master]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Comment],
		[DataClassID],
		[BaseObject],
		[BeforeFxYN],
		[DimensionSetting],
		[DimensionFilter],
		[PreExec],
		[PostExec],
		[InheritedFrom],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR01_Master]
	) sub
GO
