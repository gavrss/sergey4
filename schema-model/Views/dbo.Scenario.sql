SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Scenario] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[ScenarioID],
	[sub].[VersionID],
	[sub].[MemberKey],
	[sub].[ScenarioTypeID],
	[sub].[ScenarioName],
	[sub].[ScenarioDescription],
	[sub].[ActualOverwriteYN],
	[sub].[AutoRefreshYN],
	[sub].[InputAllowedYN],
	[sub].[AutoSaveOnCloseYN],
	[sub].[ClosedMonth],
	[sub].[DrillTo_MemberKey],
	[sub].[LockedDate],
	[sub].[SortOrder],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[DeletedID],
	[sub].[Version],
	[sub].[SimplifiedDimensionalityYN]
FROM
	(
	SELECT
		[InstanceID],
		[ScenarioID],
		[VersionID],
		[MemberKey],
		[ScenarioTypeID],
		[ScenarioName],
		[ScenarioDescription],
		[ActualOverwriteYN],
		[AutoRefreshYN],
		[InputAllowedYN],
		[AutoSaveOnCloseYN],
		[ClosedMonth],
		[DrillTo_MemberKey],
		[LockedDate],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[DeletedID],
		[Version],
		[SimplifiedDimensionalityYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Scenario]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[ScenarioID],
		[VersionID],
		[MemberKey],
		[ScenarioTypeID],
		[ScenarioName],
		[ScenarioDescription],
		[ActualOverwriteYN],
		[AutoRefreshYN],
		[InputAllowedYN],
		[AutoSaveOnCloseYN],
		[ClosedMonth],
		[DrillTo_MemberKey],
		[LockedDate],
		[SortOrder],
		[InheritedFrom],
		[SelectYN],
		[DeletedID],
		[Version],
		[SimplifiedDimensionalityYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Scenario]
	) sub
GO
