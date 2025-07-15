SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Measure] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[DataClassID],
	[sub].[MeasureID],
	[sub].[VersionID],
	[sub].[MeasureName],
	[sub].[MeasureDescription],
	[sub].[SourceFormula],
	[sub].[ExecutionOrder],
	[sub].[MeasureParentID],
	[sub].[DataTypeID],
	[sub].[FormatString],
	[sub].[ValidRangeFrom],
	[sub].[ValidRangeTo],
	[sub].[Unit],
	[sub].[AggregationTypeID],
	[sub].[TabularYN],
	[sub].[DataClassViewBM],
	[sub].[TabularFormula],
	[sub].[TabularFolder],
	[sub].[InheritedFrom],
	[sub].[SortOrder],
	[sub].[ModelingStatusID],
	[sub].[ModelingComment],
	[sub].[SelectYN],
	[sub].[DeletedID],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[DataClassID],
		[MeasureID],
		[VersionID],
		[MeasureName],
		[MeasureDescription],
		[SourceFormula],
		[ExecutionOrder],
		[MeasureParentID],
		[DataTypeID],
		[FormatString],
		[ValidRangeFrom],
		[ValidRangeTo],
		[Unit],
		[AggregationTypeID],
		[TabularYN],
		[DataClassViewBM],
		[TabularFormula],
		[TabularFolder],
		[InheritedFrom],
		[SortOrder],
		[ModelingStatusID],
		[ModelingComment],
		[SelectYN],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Measure]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[DataClassID],
		[MeasureID],
		[VersionID],
		[MeasureName],
		[MeasureDescription],
		[SourceFormula],
		[ExecutionOrder],
		[MeasureParentID],
		[DataTypeID],
		[FormatString],
		[ValidRangeFrom],
		[ValidRangeTo],
		[Unit],
		[AggregationTypeID],
		[TabularYN],
		[DataClassViewBM],
		[TabularFormula],
		[TabularFolder],
		[InheritedFrom],
		[SortOrder],
		[ModelingStatusID],
		[ModelingComment],
		[SelectYN],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Measure]
	) sub
GO
