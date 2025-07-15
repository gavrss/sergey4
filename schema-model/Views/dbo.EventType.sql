SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[EventType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[EventTypeID],
	[sub].[EventTypeName],
	[sub].[EventTypeDescription],
	[sub].[AutoEventTypeID],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[EventTypeID],
		[EventTypeName],
		[EventTypeDescription],
		[AutoEventTypeID],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[EventType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[EventTypeID],
		[EventTypeName],
		[EventTypeDescription],
		[AutoEventTypeID],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_EventType]
	) sub
GO
