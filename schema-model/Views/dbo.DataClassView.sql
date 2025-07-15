SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DataClassView] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DataClassID],
	[sub].[DataClassViewBM],
	[sub].[DataClassViewName],
	[sub].[SourceDataClassID],
	[sub].[FilterString],
	[sub].[SelectYN],
	[sub].[Version],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[DataClassViewBM],
		[DataClassViewName],
		[SourceDataClassID],
		[FilterString],
		[SelectYN],
		[Version],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DataClassView]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[DataClassViewBM],
		[DataClassViewName],
		[SourceDataClassID],
		[FilterString],
		[SelectYN],
		[Version],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DataClassView]
	) sub
GO
