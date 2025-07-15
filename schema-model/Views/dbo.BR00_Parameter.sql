SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR00_Parameter] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BusinessRuleID],
	[sub].[ParameterName],
	[sub].[ParameterValue],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[ParameterName],
		[ParameterValue],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR00_Parameter]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[BusinessRuleID],
		[ParameterName],
		[ParameterValue],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR00_Parameter]
	) sub
GO
