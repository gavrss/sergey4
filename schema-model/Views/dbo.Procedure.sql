SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Procedure] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[ProcedureID],
	[sub].[DatabaseName],
	[sub].[ProcedureName],
	[sub].[ProcedureDescription],
	[sub].[StdParameterYN],
	[sub].[StdParameterMandatoryYN],
	[sub].[Updated],
	[sub].[Version],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[ProcedureID],
		[DatabaseName],
		[ProcedureName],
		[ProcedureDescription],
		[StdParameterYN],
		[StdParameterMandatoryYN],
		[Updated],
		[Version],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Procedure]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[ProcedureID],
		[DatabaseName],
		[ProcedureName],
		[ProcedureDescription],
		[StdParameterYN],
		[StdParameterMandatoryYN],
		[Updated],
		[Version],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Procedure]
	) sub
GO
