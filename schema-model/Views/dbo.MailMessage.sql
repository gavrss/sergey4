SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[MailMessage] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[ApplicationID],
	[sub].[UserPropertyTypeID],
	[sub].[Subject],
	[sub].[Body],
	[sub].[Importance],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[ApplicationID],
		[UserPropertyTypeID],
		[Subject],
		[Body],
		[Importance],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[MailMessage]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[ApplicationID],
		[UserPropertyTypeID],
		[Subject],
		[Body],
		[Importance],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_MailMessage]
	) sub
GO
