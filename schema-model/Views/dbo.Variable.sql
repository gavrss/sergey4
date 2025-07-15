SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Variable] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[MemberKey],
	[sub].[Description],
	[sub].[Variable_Value],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[MemberKey],
		[Description],
		[Variable_Value],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Variable]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[MemberKey],
		[Description],
		[Variable_Value],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Variable]
	) sub
GO
