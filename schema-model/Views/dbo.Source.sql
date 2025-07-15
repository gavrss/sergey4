SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Source] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[SourceID],
	[sub].[SourceName],
	[sub].[SourceDescription],
	[sub].[BusinessProcess],
	[sub].[ModelID],
	[sub].[SourceTypeID],
	[sub].[SourceDatabase],
	[sub].[ETLDatabase_Linked],
	[sub].[StartYear],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version],
	[sub].[SourceDatabase_Original]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[SourceID],
		[SourceName],
		[SourceDescription],
		[BusinessProcess],
		[ModelID],
		[SourceTypeID],
		[SourceDatabase],
		[ETLDatabase_Linked],
		[StartYear],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[SourceDatabase_Original]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Source]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[SourceID],
		[SourceName],
		[SourceDescription],
		[BusinessProcess],
		[ModelID],
		[SourceTypeID],
		[SourceDatabase],
		[ETLDatabase_Linked],
		[StartYear],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[SourceDatabase_Original]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Source]
	) sub
GO
