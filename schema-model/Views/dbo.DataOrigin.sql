SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [dbo].[DataOrigin] AS
-- Current Version: 2.1.2.2198
-- Created: Feb  6 2025  4:26PM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DataOriginID],
	[sub].[DataOriginName],
	[sub].[ConnectionTypeID],
	[sub].[ConnectionName],
	[sub].[SourceID],
	[sub].[StagingPosition],
	[sub].[MasterDataYN],
	[sub].[DataClassID],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[DataOriginID],
		[DataOriginName],
		[ConnectionTypeID],
		[ConnectionName],
		[SourceID],
		[StagingPosition],
		[MasterDataYN],
		[DataClassID],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DataOrigin]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[DataOriginID],
		[DataOriginName],
		[ConnectionTypeID],
		[ConnectionName],
		[SourceID],
		[StagingPosition],
		[MasterDataYN],
		[DataClassID],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DataOrigin]
	) sub
GO
