SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Mapping_DataClass] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[Mapping_DataClassID],
	[sub].[A_DataClassID],
	[sub].[B_DataClassID],
	[sub].[Updated],
	[sub].[UpdatedBy]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[Mapping_DataClassID],
		[A_DataClassID],
		[B_DataClassID],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Mapping_DataClass]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[Mapping_DataClassID],
		[A_DataClassID],
		[B_DataClassID],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Mapping_DataClass]
	) sub
GO
