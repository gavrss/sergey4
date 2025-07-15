SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DataClass_Process] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DataClassID],
	[sub].[ProcessID],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[ProcessID],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DataClass_Process]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[ProcessID],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DataClass_Process]
	) sub
GO
