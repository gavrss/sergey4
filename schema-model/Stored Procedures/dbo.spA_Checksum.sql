SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spA_Checksum] AS

--More than 1 top nodes in [OrganizationPosition]
SELECT 
	[InstanceID] = MAX([InstanceID]),
	[OrganizationHierarchyID],
	[TopNodes#] = COUNT(1)
FROM
	[OrganizationPosition]
WHERE
	[ParentOrganizationPositionID] IS NULL
GROUP BY
	[OrganizationHierarchyID]
HAVING
	COUNT(1) > 1

--Missing FxRates
SELECT 
	[Time],
	[Currency],
	COUNT(1)
FROM
	[pcDATA_BullGuard].[dbo].[FACT_FxRate_View] 
GROUP BY
	[Time],
	[Currency]
HAVING
	COUNT(1) <> 4
ORDER BY
	[Time],
	[Currency]


SELECT DISTINCT
	Fx.[Currency],
	sub.[Rate],
	sub.[Scenario],
	sub.[Time]
FROM
	[pcDATA_BullGuard].[dbo].[FACT_FxRate_View] Fx
	INNER JOIN (SELECT DISTINCT
		[Rate],
		[Scenario],
		[Time]
	FROM
		[pcDATA_BullGuard].[dbo].[FACT_FxRate_View]
	) sub ON 1 = 1
WHERE
	NOT EXISTS (SELECT 1 FROM [pcDATA_BullGuard].[dbo].[FACT_FxRate_View] D WHERE D.[Currency] = Fx.[Currency] AND D.[Rate] = sub.[Rate] AND D.[Scenario] = sub.[Scenario] AND D.[Time] = sub.[Time])
ORDER BY
	Fx.[Currency],
	sub.[Rate],
	sub.[Scenario],
	sub.[Time]

--Verify not having more than one not delegated user per OrganizationPosition
/*
		SELECT 
			ResultTypeBM = 1,
			OP.[OrganizationPositionID],
			[OrganizationPositionName],
			[OrganizationPositionDescription],
			[ParentOrganizationPositionID],
			[OrganizationLevelNo],
			[SortOrder],
			UserID = MAX(OPU.UserID),
			UserNameDisplay = MAX(U.UserNameDisplay)
		FROM
			OrganizationPosition OP
			LEFT JOIN OrganizationPosition_User OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.DelegateYN = 0
			LEFT JOIN [User] U ON U.UserID = OPU.UserID AND U.DeletedID IS NULL
		WHERE
			OP.InstanceID = @InstanceID AND
			OP.VersionID = @VersionID AND
			OP.OrganizationHierarchyID = @OrganizationHierarchyID AND
			OP.DeletedID IS NULL
		GROUP BY
			OP.[OrganizationPositionID],
			[OrganizationPositionName],
			[OrganizationPositionDescription],
			[ParentOrganizationPositionID],
			[OrganizationLevelNo],
			[SortOrder]
*/

--Check Modeling Status

DECLARE
	@InstanceID int = 454,
	@VersionID int = 1021,

	@SQLStatement nvarchar(max),	
	@TableName nvarchar(100),
	@InstanceIDYN bit,
	@VersionIDYN bit

		DECLARE ModelingStatus_Cursor CURSOR FOR
			
			SELECT DISTINCT
				[TableName] = T.[name],
				[InstanceIDYN] = CASE WHEN I.[name] IS NULL THEN 0 ELSE 1 END,
				[VersionIDYN] = CASE WHEN V.[name] IS NULL THEN 0 ELSE 1 END
			FROM
				pcINTEGRATOR_Data.sys.tables T
				INNER JOIN pcINTEGRATOR_Data.sys.columns C ON C.object_id = T.object_id AND C.[name] = 'ModelingStatusID'
				LEFT JOIN pcINTEGRATOR_Data.sys.columns I ON I.object_id = T.object_id AND I.[name] = 'InstanceID'
				LEFT JOIN pcINTEGRATOR_Data.sys.columns V ON V.object_id = T.object_id AND V.[name] = 'VersionID'
			WHERE
				T.[name] <> 'ModelingStatus'

			OPEN ModelingStatus_Cursor
			FETCH NEXT FROM ModelingStatus_Cursor INTO @TableName, @InstanceIDYN, @VersionIDYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT [@TableName] = @TableName

					SET @SQLStatement = '
						SELECT
							TableName = ''' + @TableName + ''',
							T.' + @TableName + 'ID,
							T.' + @TableName + 'Name,
							ModelingStatusID = T.ModelingStatusID,
							ModelingStatusName = MS.ModelingStatusName,
							ModelingStatusDescription = MS.ModelingStatusDescription,
							ModelingComment = T.ModelingComment
						FROM
							pcINTEGRATOR_Data.dbo.' + @TableName + ' T
							INNER JOIN pcINTEGRATOR.dbo.ModelingStatus MS ON MS.ModelingStatusID = T.ModelingStatusID
						WHERE
							' + CASE WHEN @InstanceIDYN <> 0 THEN 'T.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND' ELSE '' END + '
							' + CASE WHEN @VersionIDYN <> 0 THEN 'T.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND' ELSE '' END + '
							T.ModelingStatusID <> -10'

					PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM ModelingStatus_Cursor INTO @TableName, @InstanceIDYN, @VersionIDYN
				END

		CLOSE ModelingStatus_Cursor
		DEALLOCATE ModelingStatus_Cursor

		--Check on multiple SiteID set to Main in pcINTEGRATOR_Master
		SELECT * FROM DSPMASTER.pcINTEGRATOR_Master.dbo.Customer C
INNER JOIN (

SELECT [SiteID], [COUNT] = COUNT(1)
FROM DSPMASTER.pcINTEGRATOR_Master.[dbo].[Customer]
WHERE MainYN <> 0
GROUP BY [SiteID]
HAVING COUNT(1) > 1
) sub ON sub.SiteID = C.SiteID
WHERE C.MainYN <> 0
ORDER BY C.SiteID, C.CustomerID

--Missing match between LicensePortal and Master DB
SELECT DISTINCT
	wLP.SiteID,
	wLP.SiteName,
	C.CustomerID,
	C.CustomerName
FROM
	DSPMASTER.pcINTEGRATOR_Master.[dbo].wrk_LicensePortal wLP
	LEFT JOIN DSPMASTER.pcINTEGRATOR_Master.[dbo].Customer C ON C.SiteID = wLP.SiteID AND C.MainYN <> 0
ORDER BY
	CustomerID,
	SiteName
GO
