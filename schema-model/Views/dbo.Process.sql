SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [dbo].[Process] AS
-- Current Version: 2.1.2.2198
-- Created: Feb  6 2025  4:26PM

SELECT 
	[sub].[InstanceID],
	[sub].[ProcessID],
	[sub].[VersionID],
	[sub].[ProcessBM],
	[sub].[ProcessName],
	[sub].[ProcessDescription],
	[sub].[Destination_DataClassID],
	[sub].[ModelingStatusID],
	[sub].[ModelingComment],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[DeletedID],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[ProcessID],
		[VersionID],
		[ProcessBM],
		[ProcessName],
		[ProcessDescription],
		[Destination_DataClassID],
		[ModelingStatusID],
		[ModelingComment],
		[InheritedFrom],
		[SelectYN],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Process]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[ProcessID],
		[VersionID],
		[ProcessBM],
		[ProcessName],
		[ProcessDescription],
		[Destination_DataClassID],
		[ModelingStatusID],
		[ModelingComment],
		[InheritedFrom],
		[SelectYN],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Process]
	) sub
GO
