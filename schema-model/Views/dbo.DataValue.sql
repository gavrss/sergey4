SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DataValue] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[DataClassID],
	[sub].[DataRowID],
	[sub].[MeasureID],
	[sub].[VersionID],
	[sub].[DataValue],
	[sub].[Updated],
	[sub].[UpdatedBy]
FROM
	(
	SELECT
		[InstanceID],
		[DataClassID],
		[DataRowID],
		[MeasureID],
		[VersionID],
		[DataValue],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DataValue]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[DataClassID],
		[DataRowID],
		[MeasureID],
		[VersionID],
		[DataValue],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DataValue]
	) sub
GO
