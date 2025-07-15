SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[ModelingStatus] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[ModelingStatusID],
	[sub].[ModelingStatusName],
	[sub].[ModelingStatusDescription],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[ModelingStatusID],
		[ModelingStatusName],
		[ModelingStatusDescription],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[ModelingStatus]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[ModelingStatusID],
		[ModelingStatusName],
		[ModelingStatusDescription],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_ModelingStatus]
	) sub
GO
