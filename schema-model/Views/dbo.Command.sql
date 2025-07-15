SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Command] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[ProcessID],
	[sub].[CommandID],
	[sub].[CommandName],
	[sub].[CommandDescription],
	[sub].[DatabaseName],
	[sub].[Command],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[ProcessID],
		[CommandID],
		[CommandName],
		[CommandDescription],
		[DatabaseName],
		[Command],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Command]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[ProcessID],
		[CommandID],
		[CommandName],
		[CommandDescription],
		[DatabaseName],
		[Command],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Command]
	) sub
GO
