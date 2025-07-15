SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[FormPart] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[FormID],
	[sub].[FormPartID],
	[sub].[FormPartName],
	[sub].[DataObjectName],
	[sub].[FormPartID_Reference],
	[sub].[SortOrder],
	[sub].[Inserted],
	[sub].[InsertedBy],
	[sub].[Updated],
	[sub].[UpdatedBy],
	[sub].[Version],
	[sub].[Filter]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[FormID],
		[FormPartID],
		[FormPartName],
		[DataObjectName],
		[FormPartID_Reference],
		[SortOrder],
		[Inserted],
		[InsertedBy],
		[Updated],
		[UpdatedBy],
		[Version],
		[Filter]
	FROM
		[pcINTEGRATOR_Data].[dbo].[FormPart]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[FormID],
		[FormPartID],
		[FormPartName],
		[DataObjectName],
		[FormPartID_Reference],
		[SortOrder],
		[Inserted],
		[InsertedBy],
		[Updated],
		[UpdatedBy],
		[Version],
		[Filter]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_FormPart]
	) sub
GO
