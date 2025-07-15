SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Application_Translation] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[ApplicationID],
	[sub].[TranslationID],
	[sub].[LanguageID],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[ApplicationID],
		[TranslationID],
		[LanguageID],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Application_Translation]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[ApplicationID],
		[TranslationID],
		[LanguageID],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Application_Translation]
	) sub
GO
