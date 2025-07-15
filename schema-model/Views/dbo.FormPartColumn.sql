SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[FormPartColumn] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[FormID],
	[sub].[FormPartID],
	[sub].[FormPartColumn],
	[sub].[DataObjectColumnName],
	[sub].[ColumnSet],
	[sub].[DataTypeID],
	[sub].[ObjectGuiBehaviorBM],
	[sub].[DefaultValue],
	[sub].[ValueListType],
	[sub].[ValueList],
	[sub].[ValidationRule],
	[sub].[VisibleYN],
	[sub].[FormPartColumn_Reference],
	[sub].[SortOrder],
	[sub].[Inserted],
	[sub].[InsertedBy],
	[sub].[Updated],
	[sub].[UpdatedBy],
	[sub].[Version],
	[sub].[KeyYN],
	[sub].[EnabledYN],
	[sub].[HelpText],
	[sub].[ShowNullAs],
	[sub].[NullYN],
	[sub].[ValueListParameter],
	[sub].[IdentityYN]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[FormID],
		[FormPartID],
		[FormPartColumn],
		[DataObjectColumnName],
		[ColumnSet],
		[DataTypeID],
		[ObjectGuiBehaviorBM],
		[DefaultValue],
		[ValueListType],
		[ValueList],
		[ValidationRule],
		[VisibleYN],
		[FormPartColumn_Reference],
		[SortOrder],
		[Inserted],
		[InsertedBy],
		[Updated],
		[UpdatedBy],
		[Version],
		[KeyYN],
		[EnabledYN],
		[HelpText],
		[ShowNullAs],
		[NullYN],
		[ValueListParameter],
		[IdentityYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[FormPartColumn]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[FormID],
		[FormPartID],
		[FormPartColumn],
		[DataObjectColumnName],
		[ColumnSet],
		[DataTypeID],
		[ObjectGuiBehaviorBM],
		[DefaultValue],
		[ValueListType],
		[ValueList],
		[ValidationRule],
		[VisibleYN],
		[FormPartColumn_Reference],
		[SortOrder],
		[Inserted],
		[InsertedBy],
		[Updated],
		[UpdatedBy],
		[Version],
		[KeyYN],
		[EnabledYN],
		[HelpText],
		[ShowNullAs],
		[NullYN],
		[ValueListParameter],
		[IdentityYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_FormPartColumn]
	) sub
GO
