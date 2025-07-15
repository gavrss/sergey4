SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Entity] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[EntityID],
	[sub].[MemberKey],
	[sub].[EntityName],
	[sub].[EntityTypeID],
	[sub].[LegalID],
	[sub].[LegalName],
	[sub].[CountryID],
	[sub].[Priority],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[DeletedID],
	[sub].[Version],
	[sub].[SourceID]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[EntityID],
		[MemberKey],
		[EntityName],
		[EntityTypeID],
		[LegalID],
		[LegalName],
		[CountryID],
		[Priority],
		[InheritedFrom],
		[SelectYN],
		[DeletedID],
		[Version],
		[SourceID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Entity]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[EntityID],
		[MemberKey],
		[EntityName],
		[EntityTypeID],
		[LegalID],
		[LegalName],
		[CountryID],
		[Priority],
		[InheritedFrom],
		[SelectYN],
		[DeletedID],
		[Version],
		[SourceID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Entity]
	) sub
GO
