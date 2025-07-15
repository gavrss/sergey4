SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR_Type] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[BR_TypeID],
	[sub].[BR_TypeCode],
	[sub].[BR_TypeName],
	[sub].[BR_TypeDescription],
	[sub].[Operation],
	[sub].[CallistoEnabledYN],
	[sub].[ProcedureName],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[BR_TypeID],
		[BR_TypeCode],
		[BR_TypeName],
		[BR_TypeDescription],
		[Operation],
		[CallistoEnabledYN],
		[ProcedureName],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR_Type]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[BR_TypeID],
		[BR_TypeCode],
		[BR_TypeName],
		[BR_TypeDescription],
		[Operation],
		[CallistoEnabledYN],
		[ProcedureName],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR_Type]
	) sub
GO
