SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Assignment] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[AssignmentID],
	[sub].[VersionID],
	[sub].[AssignmentName],
	[sub].[Comment],
	[sub].[OrganizationPositionID],
	[sub].[DataClassID],
	[sub].[WorkflowID],
	[sub].[SpreadingKeyID],
	[sub].[GridID],
	[sub].[LiveFcstNextFlowID],
	[sub].[Priority],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[AssignmentID],
		[VersionID],
		[AssignmentName],
		[Comment],
		[OrganizationPositionID],
		[DataClassID],
		[WorkflowID],
		[SpreadingKeyID],
		[GridID],
		[LiveFcstNextFlowID],
		[Priority],
		[InheritedFrom],
		[SelectYN],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Assignment]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[AssignmentID],
		[VersionID],
		[AssignmentName],
		[Comment],
		[OrganizationPositionID],
		[DataClassID],
		[WorkflowID],
		[SpreadingKeyID],
		[GridID],
		[LiveFcstNextFlowID],
		[Priority],
		[InheritedFrom],
		[SelectYN],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Assignment]
	) sub
GO
