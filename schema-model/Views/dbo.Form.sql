SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Form] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[FormID],
	[sub].[FormName],
	[sub].[Menu],
	[sub].[ObjectGuiBehaviorBM],
	[sub].[SortOrder],
	[sub].[SelectYN],
	[sub].[Inserted],
	[sub].[InsertedBy],
	[sub].[Updated],
	[sub].[UpdatedBy],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[FormID],
		[FormName],
		[Menu],
		[ObjectGuiBehaviorBM],
		[SortOrder],
		[SelectYN],
		[Inserted],
		[InsertedBy],
		[Updated],
		[UpdatedBy],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Form]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[FormID],
		[FormName],
		[Menu],
		[ObjectGuiBehaviorBM],
		[SortOrder],
		[SelectYN],
		[Inserted],
		[InsertedBy],
		[Updated],
		[UpdatedBy],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Form]
	) sub
GO
