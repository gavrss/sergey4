SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BusinessRule] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[BR_Name],
	[sub].[BR_Description],
	[sub].[BR_TypeID],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[DeletedID],
	[sub].[Version],
	[sub].[SortOrder],
	[sub].[LastExecTime],
	[sub].[ExpectedExecTime]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR_Name],
		[BR_Description],
		[BR_TypeID],
		[InheritedFrom],
		[SelectYN],
		[DeletedID],
		[Version],
		[SortOrder],
		[LastExecTime],
		[ExpectedExecTime]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BusinessRule]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[BR_Name],
		[BR_Description],
		[BR_TypeID],
		[InheritedFrom],
		[SelectYN],
		[DeletedID],
		[Version],
		[SortOrder],
		[LastExecTime],
		[ExpectedExecTime]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BusinessRule]
	) sub
GO
