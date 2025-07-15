SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_DimensionHierarchy] AS

INSERT INTO [dbo].[DimensionHierarchy]
	(
	[Comment],
	[InstanceID],
	[DimensionID],
	[HierarchyNo],
	[HierarchyName],
	[FixedLevelsYN],
	[LockedYN]
	)
SELECT 
	[Comment] = InstanceName + ', ' + DimensionName,
	D.[InstanceID],
	[DimensionID],
	[HierarchyNo] = 0,
	[HierarchyName] = [DimensionName],
	[FixedLevelsYN] = 1,
	[LockedYN] = 0
FROM
	[pcINTEGRATOR].[dbo].[Dimension] D
	INNER JOIN Instance I ON I.InstanceID = D.InstanceID
WHERE
	DimensionID NOT BETWEEN 0 AND 1000 AND
	NOT EXISTS (SELECT 1 FROM [DimensionHierarchy] DH WHERE DH.InstanceID = D.InstanceID AND DH.DimensionID = D.DimensionID AND DH.HierarchyNo = 0)

INSERT INTO [dbo].[DimensionHierarchyLevel]
	(
	[Comment],
	[InstanceID],
	[DimensionID],
	[HierarchyNo],
	[LevelNo],
	[LevelName]
	)
SELECT 
	[Comment],
	[InstanceID],
	[DimensionID],
	[HierarchyNo],
	[LevelNo],
	[LevelName]
FROM
	(
	SELECT 
		[Comment] = InstanceName + ', ' + DimensionName,
		D.[InstanceID],
		[DimensionID],
		[HierarchyNo] = 0,
		[LevelNo] = 1,
		[LevelName] = 'TopNode'
	FROM
		[pcINTEGRATOR].[dbo].[Dimension] D
		INNER JOIN Instance I ON I.InstanceID = D.InstanceID
	WHERE
		DimensionID NOT BETWEEN 0 AND 1000
	UNION SELECT 
		[Comment] = InstanceName + ', ' + DimensionName,
		D.[InstanceID],
		[DimensionID],
		[HierarchyNo] = 0,
		[LevelNo] = 2,
		[LevelName] = REPLACE(DimensionName, 'GL_', '')
	FROM
		[pcINTEGRATOR].[dbo].[Dimension] D
		INNER JOIN Instance I ON I.InstanceID = D.InstanceID
	WHERE
		DimensionID NOT BETWEEN 0 AND 1000
	) sub	
WHERE
	NOT EXISTS (SELECT 1 FROM [DimensionHierarchyLevel] DHL WHERE DHL.InstanceID = sub.InstanceID AND DHL.DimensionID = sub.DimensionID AND DHL.HierarchyNo = 0 AND DHL.LevelNo IN (1, 2))
GO
