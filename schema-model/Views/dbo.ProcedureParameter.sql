SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[ProcedureParameter] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[ProcedureID],
	[sub].[Parameter],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[ProcedureID],
		[Parameter],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[ProcedureParameter]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[ProcedureID],
		[Parameter],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_ProcedureParameter]
	) sub
GO
