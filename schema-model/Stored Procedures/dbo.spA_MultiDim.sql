SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spA_MultiDim] AS
/*
INSERT INTO [pcDATA_PCX].[dbo].[S_DS_MultiDim]
	(
	[MemberId],
	[Label],
	[Description],
	[Account_MemberId],
	[Account],
	[GL_DEPARTMENT_MemberId],
	[GL_DEPARTMENT],
	[GL_DIVISION_MemberId],
	[GL_DIVISION],
	[AccountType_MemberId],
	[AccountType],
	[HelpText],
	[RNodeType],
	[SBZ],
	[Source],
	[Synchronized],
	[NodeTypeBM]
	)
SELECT DISTINCT
	[MemberId] = NULL,
	[Label] = [Account].[Label] + '-' + [GL_DEPARTMENT].[Label] + '-' + [GL_DIVISION].[Label],
	[Description] = [Account].[Description] + ' - ' + [GL_DEPARTMENT].[Description] + ' - ' + [GL_DIVISION].[Description],
	[Account_MemberId] = Financials.[Account_MemberId],
	[Account] = [Account].[Label],
	[GL_DEPARTMENT_MemberId] = Financials.[GL_DEPARTMENT_MemberId],
	[GL_DEPARTMENT] = [GL_DEPARTMENT].[Label],
	[GL_DIVISION_MemberId] = Financials.[GL_DIVISION_MemberId],
	[GL_DIVISION] = [GL_DIVISION].[Label],
	[AccountType_MemberId] = [Account].[AccountType_MemberId],
	[AccountType] = [Account].[AccountType],
	[HelpText] = [Account].[Description] + ' - ' + [GL_DEPARTMENT].[Description] + ' - ' + [GL_DIVISION].[Description],
	[RNodeType] = 'L',
	[SBZ] = 0,
	[Source] = 'ETL',
	[Synchronized] = 1,
	[NodeTypeBM] = 1
FROM
	[pcDATA_PCX].[dbo].[FACT_Financials_default_partition] Financials
	INNER JOIN [pcDATA_PCX].[dbo].[S_DS_Account] Account ON Account.MemberId = Financials.Account_MemberId
	INNER JOIN [pcDATA_PCX].[dbo].[S_DS_GL_DEPARTMENT] GL_DEPARTMENT ON GL_DEPARTMENT.MemberId = Financials.GL_DEPARTMENT_MemberId
	INNER JOIN [pcDATA_PCX].[dbo].[S_DS_GL_DIVISION] GL_DIVISION ON GL_DIVISION.MemberId = Financials.GL_DIVISION_MemberId
WHERE
	NOT EXISTS (SELECT 1 FROM [pcDATA_PCX].[dbo].[S_DS_MultiDim] D WHERE D.[Label] = [Account].[Label] + '-' + [GL_DEPARTMENT].[Label] + '-' + [GL_DIVISION].[Label])
ORDER BY
	[Account].[Label],
	[GL_DEPARTMENT].[Label],
	[GL_DIVISION].[Label]

EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = '[pcDATA_PCX]', @Dimension = 'MultiDim'
*/

/*
SELECT
	MemberId, [Label]
FROM
	pcDATA_PCX..S_DS_MultiDim
WHERE
	NodeTypeBM & 1024 > 0
*/

DECLARE
	@InstanceID int = 531,
	@VersionID int = 1041,
	@DimensionID int = 9155

--ResultTypeBM=1
CREATE TABLE #MultiDimension
	(
	[ID] int IDENTITY(1,1),
	[PropertyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
	[DimensionID] int,
	[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT
	)

INSERT INTO #MultiDimension
	(
	[PropertyName],
	[DimensionID],
	[DimensionName]
	)
SELECT 
	[PropertyName] = P.[PropertyName],
	[DimensionID] = P.[DependentDimensionID],
	[DimensionName] = D.[DimensionName]
FROM
	[pcINTEGRATOR].[dbo].[Dimension_Property] DP
	INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.[PropertyID] = DP.[PropertyID]
	INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.InstanceID IN (0, @InstanceID) AND D.[DimensionID] = P.[DependentDimensionID]
WHERE
	DP.[InstanceID] = @InstanceID AND
	DP.[VersionID] = @VersionID AND
	DP.[DimensionID] = @DimensionID AND
	DP.[MultiDimYN] <> 0
ORDER BY
	DP.SortOrder

SELECT
	[ResultTypeBM] = 1,
	[ColumnCode],
	[ColumnName]
FROM
	(
	SELECT
		[ColumnCode] = 'H' + CASE WHEN DH.[HierarchyNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), DH.[HierarchyNo]),
		[ColumnName] = [HierarchyName]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH 
	WHERE
		[InstanceID] = @InstanceID AND
		[VersionID] = @VersionID AND
		[DimensionID] = @DimensionID AND
		[CategoryYN] <> 0

	UNION
	SELECT 
		[ColumnCode] = 'D' + CASE WHEN MD.[ID] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), MD.[ID]),
		[ColumnName] = MD.[PropertyName]
	FROM
		#MultiDimension MD
	) sub
ORDER BY
	sub.[ColumnCode]

--ResultTypeBM=2
SELECT 
	[ResultTypeBM] = 2,
	[ColumnCode] = 'D01',
	[MemberId] = D.[MemberId],
	[MemberKey] = D.[Label],
	[Description] = D.[Description]
FROM
	pcDATA_PCX..S_DS_Account D
WHERE
	[RNodeType] LIKE 'L%'
ORDER BY
	[Label]

SELECT 
	[ResultTypeBM] = 2,
	[ColumnCode] = 'D02',
	[MemberId] = D.[MemberId],
	[MemberKey] = D.[Label],
	[Description] = D.[Description]
FROM
	pcDATA_PCX..S_DS_GL_DEPARTMENT D
WHERE
	[RNodeType] LIKE 'L%'
ORDER BY
	[Label]

SELECT 
	[ResultTypeBM] = 2,
	[ColumnCode] = 'D03',
	[MemberId] = D.[MemberId],
	[MemberKey] = D.[Label],
	[Description] = D.[Description]
FROM
	pcDATA_PCX..S_DS_GL_DIVISION D
WHERE
	[RNodeType] LIKE 'L%'
ORDER BY
	[Label]

SELECT 
	[ResultTypeBM] = 2,
	[ColumnCode] = 'H',
	[MemberId] = D.[MemberId],
	[MemberKey] = D.[Label],
	[Description] = D.[Description]
FROM
	pcDATA_PCX..S_DS_MultiDim D
WHERE
	[NodeTypeBM] & 1024 > 0
ORDER BY
	[Label]

--ResultTypeBM=4
SELECT 
	[ResultTypeBM] = 4,
	[MemberId] = D.[MemberId],
	[MemberKey] = D.[Label],
	[Description] = D.[Description],
	[HelpText] = D.[HelpText],
	[D01_MemberID] = D.[Account_MemberId],
	[D01_MemberKey] = D.[Account],
	[D02_MemberID] = D.[GL_DEPARTMENT_MemberId],
	[D02_MemberKey] = D.[GL_DEPARTMENT],
	[D03_MemberID] = D.[GL_DIVISION_MemberId],
	[D03_MemberKey] = D.[GL_DIVISION],
	[H01_MemberID] = [H01].[Category_MemberID],
	[H01_MemberKey] = [H01].[Category_MemberKey],
	[H02_MemberID] = [H02].[Category_MemberID],
	[H02_MemberKey] = [H02].[Category_MemberKey],
	[H03_MemberID] = [H03].[Category_MemberID],
	[H03_MemberKey] = [H03].[Category_MemberKey]
FROM
	pcDATA_PCX..S_DS_MultiDim D
	LEFT JOIN
		(
		SELECT
			[MemberId] = H.[MemberId],
			[Category_MemberId] = H.[ParentMemberId],
			[Category_MemberKey] = D.[Label]
		FROM
			[pcDATA_PCX].[dbo].[S_HS_MultiDim_Budget] H
			INNER JOIN [pcDATA_PCX].[dbo].[S_DS_MultiDim] D ON D.[NodeTypeBM] & 1024 > 0 AND D.[MemberId] = H.[ParentMemberId]
		) [H01] ON [H01].[MemberId] = D.[MemberId]
	LEFT JOIN
		(
		SELECT
			[MemberId] = H.[MemberId],
			[Category_MemberId] = H.[ParentMemberId],
			[Category_MemberKey] = D.[Label]
		FROM
			[pcDATA_PCX].[dbo].[S_HS_MultiDim_Board] H
			INNER JOIN [pcDATA_PCX].[dbo].[S_DS_MultiDim] D ON D.[NodeTypeBM] & 1024 > 0 AND D.[MemberId] = H.[ParentMemberId]
		) [H02] ON [H02].[MemberId] = D.[MemberId]
	LEFT JOIN
		(
		SELECT
			[MemberId] = H.[MemberId],
			[Category_MemberId] = H.[ParentMemberId],
			[Category_MemberKey] = D.[Label]
		FROM
			[pcDATA_PCX].[dbo].[S_HS_MultiDim_Dept] H
			INNER JOIN [pcDATA_PCX].[dbo].[S_DS_MultiDim] D ON D.[NodeTypeBM] & 1024 > 0 AND D.[MemberId] = H.[ParentMemberId]
		) [H03] ON [H03].[MemberId] = D.[MemberId]
WHERE
	D.[NodeTypeBM] & 1 > 0
ORDER BY
	D.[Label]

/*
SELECT
	HierarchyName,
	CategoryYN
FROM
	pcINTEGRATOR_Data..DimensionHierarchy 
WHERE
	InstanceID = 531 AND
	VersionID = 1041 AND
	DimensionID = 9155 AND
--	CategoryYN <> 0 AND
	1=1

SELECT * FROM 
	pcDATA_PCX..S_HS_MultiDim_Budget
*/

DROP TABLE #MultiDimension

GO
