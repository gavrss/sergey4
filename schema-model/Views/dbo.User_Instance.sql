SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[User_Instance] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[UserID],
	[sub].[ExpiryDate],
	[sub].[Inserted],
	[sub].[InsertedBy],
	[sub].[SelectYN],
	[sub].[LoginEnabledYN],
	[sub].[Version],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[UserID],
		[ExpiryDate],
		[Inserted],
		[InsertedBy],
		[SelectYN],
		[LoginEnabledYN],
		[Version],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[User_Instance]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[UserID],
		[ExpiryDate],
		[Inserted],
		[InsertedBy],
		[SelectYN],
		[LoginEnabledYN],
		[Version],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_User_Instance]
	) sub
GO
