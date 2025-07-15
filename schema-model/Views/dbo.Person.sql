SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Person] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[PersonID],
	[sub].[ReplacedBy_PersonID],
	[sub].[EmployeeNumber],
	[sub].[DisplayName],
	[sub].[FamilyName],
	[sub].[GivenName],
	[sub].[Email],
	[sub].[SocialSecurityNumber],
	[sub].[SourceSpecificKey],
	[sub].[Source],
	[sub].[SourceID],
	[sub].[DeletedID],
	[sub].[Inserted],
	[sub].[InsertedBy],
	[sub].[Updated],
	[sub].[UpdatedBy],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[PersonID],
		[ReplacedBy_PersonID],
		[EmployeeNumber],
		[DisplayName],
		[FamilyName],
		[GivenName],
		[Email],
		[SocialSecurityNumber],
		[SourceSpecificKey],
		[Source],
		[SourceID],
		[DeletedID],
		[Inserted],
		[InsertedBy],
		[Updated],
		[UpdatedBy],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Person]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[PersonID],
		[ReplacedBy_PersonID],
		[EmployeeNumber],
		[DisplayName],
		[FamilyName],
		[GivenName],
		[Email],
		[SocialSecurityNumber],
		[SourceSpecificKey],
		[Source],
		[SourceID],
		[DeletedID],
		[Inserted],
		[InsertedBy],
		[Updated],
		[UpdatedBy],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Person]
	) sub
GO
