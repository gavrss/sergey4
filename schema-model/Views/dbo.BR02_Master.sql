SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR02_Master] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[Comment],
	[sub].[DatabaseName],
	[sub].[StoredProcedure],
	[sub].[Filter],
	[sub].[FromTime],
	[sub].[ToTime],
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
		[DatabaseName],
		[StoredProcedure],
		[Filter],
		[FromTime],
		[ToTime],
		[InheritedFrom],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR02_Master]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[Comment],
		[DatabaseName],
		[StoredProcedure],
		[Filter],
		[FromTime],
		[ToTime],
		[InheritedFrom],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR02_Master]
	) sub
GO
