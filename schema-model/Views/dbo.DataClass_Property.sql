SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DataClass_Property] AS
-- Current Version: 2.0.2.2148
-- Created: Nov 13 2019  8:48PM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DataClassID],
	[sub].[PropertyName],
	[sub].[DataTypeID],
	[sub].[SortOrder],
	[sub].[InheritedFrom],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[PropertyName],
		[DataTypeID],
		[SortOrder],
		[InheritedFrom],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DataClass_Property]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[PropertyName],
		[DataTypeID],
		[SortOrder],
		[InheritedFrom],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DataClass_Property]
	) sub
GO
