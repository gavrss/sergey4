SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [dbo].[DataOriginColumn] AS
-- Current Version: 2.1.2.2198
-- Created: Feb  6 2025  4:26PM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DataOriginID],
	[sub].[ColumnID],
	[sub].[ColumnName],
	[sub].[ColumnOrder],
	[sub].[ColumnTypeID],
	[sub].[DestinationName],
	[sub].[DataType],
	[sub].[uOM],
	[sub].[PropertyType],
	[sub].[HierarchyLevel],
	[sub].[Comment],
	[sub].[AutoAddYN],
	[sub].[DataClassYN],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[DataOriginID],
		[ColumnID],
		[ColumnName],
		[ColumnOrder],
		[ColumnTypeID],
		[DestinationName],
		[DataType],
		[uOM],
		[PropertyType],
		[HierarchyLevel],
		[Comment],
		[AutoAddYN],
		[DataClassYN],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DataOriginColumn]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[DataOriginID],
		[ColumnID],
		[ColumnName],
		[ColumnOrder],
		[ColumnTypeID],
		[DestinationName],
		[DataType],
		[uOM],
		[PropertyType],
		[HierarchyLevel],
		[Comment],
		[AutoAddYN],
		[DataClassYN],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DataOriginColumn]
	) sub
GO
