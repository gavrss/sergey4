SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[BR05_FormulaFX] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[FormulaFXID],
	[sub].[FormulaFXName],
	[sub].[FormulaFX],
	[sub].[Version]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[FormulaFXID],
		[FormulaFXName],
		[FormulaFX],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[BR05_FormulaFX]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[FormulaFXID],
		[FormulaFXName],
		[FormulaFX],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_BR05_FormulaFX]
	) sub
GO
