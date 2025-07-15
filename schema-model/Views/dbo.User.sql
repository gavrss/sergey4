SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[User] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[UserID],
	[sub].[UserName],
	[sub].[UserNameAD],
	[sub].[UserNameDisplay],
	[sub].[UserTypeID],
	[sub].[UserLicenseTypeID],
	[sub].[LocaleID],
	[sub].[LanguageID],
	[sub].[ObjectGuiBehaviorBM],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[LoginEnabledYN],
	[sub].[Version],
	[sub].[DeletedID],
	[sub].[PersonID]
FROM
	(
	SELECT
		[InstanceID],
		[UserID],
		[UserName],
		[UserNameAD],
		[UserNameDisplay],
		[UserTypeID],
		[UserLicenseTypeID],
		[LocaleID],
		[LanguageID],
		[ObjectGuiBehaviorBM],
		[InheritedFrom],
		[SelectYN],
		[LoginEnabledYN],
		[Version],
		[DeletedID],
		[PersonID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[User]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[UserID],
		[UserName],
		[UserNameAD],
		[UserNameDisplay],
		[UserTypeID],
		[UserLicenseTypeID],
		[LocaleID],
		[LanguageID],
		[ObjectGuiBehaviorBM],
		[InheritedFrom],
		[SelectYN],
		[LoginEnabledYN],
		[Version],
		[DeletedID],
		[PersonID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_User]
	) sub
GO
