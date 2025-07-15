SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DataClass] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[DataClassID],
	[sub].[VersionID],
	[sub].[DataClassName],
	[sub].[DataClassDescription],
	[sub].[DataClassTypeID],
	[sub].[ModelBM],
	[sub].[StorageTypeBM],
	[sub].[ReadAccessDefaultYN],
	[sub].[ActualDataClassID],
	[sub].[FullAccountDataClassID],
	[sub].[TabularYN],
	[sub].[PrimaryJoin_DimensionID],
	[sub].[ModelingStatusID],
	[sub].[ModelingComment],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version],
	[sub].[DeletedID],
	[sub].[TextSupportYN]
FROM
	(
	SELECT
		[InstanceID],
		[DataClassID],
		[VersionID],
		[DataClassName],
		[DataClassDescription],
		[DataClassTypeID],
		[ModelBM],
		[StorageTypeBM],
		[ReadAccessDefaultYN],
		[ActualDataClassID],
		[FullAccountDataClassID],
		[TabularYN],
		[PrimaryJoin_DimensionID],
		[ModelingStatusID],
		[ModelingComment],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[DeletedID],
		[TextSupportYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DataClass]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[DataClassID],
		[VersionID],
		[DataClassName],
		[DataClassDescription],
		[DataClassTypeID],
		[ModelBM],
		[StorageTypeBM],
		[ReadAccessDefaultYN],
		[ActualDataClassID],
		[FullAccountDataClassID],
		[TabularYN],
		[PrimaryJoin_DimensionID],
		[ModelingStatusID],
		[ModelingComment],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[DeletedID],
		[TextSupportYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DataClass]
	) sub
GO
