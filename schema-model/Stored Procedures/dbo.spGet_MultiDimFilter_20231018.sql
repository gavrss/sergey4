SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create PROCEDURE [dbo].[spGet_MultiDimFilter_20231018]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@MultiDimensionID int = NULL,
	@MultiDimensionName nvarchar(100) = NULL,
	@MultiHierarchyName nvarchar(100) = NULL,
	@MultiDimFilter nvarchar(max) = NULL,
	@LeafLevelFilter nvarchar(max) = NULL,
	@EqualityString nvarchar(10) = 'IN',
	@CategoryYN bit = 0,
	@JournalYN bit = 0,
	@CallistoDatabase nvarchar(100) = NULL,
	@SQL_MultiDimJoin nvarchar(2000) = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000833,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [dbo].[spGet_MultiDimFilter]
	@UserID = -10,
	@InstanceID = -1590,
	@VersionID = -1590,
	@MultiDimensionID = 13735,
	@MultiDimensionName = 'FullAccount',
	@MultiHierarchyName = 'FullAccount',
	@LeafLevelFilter = '1080,1099,1274,1410,1411,1412,1414,1415,1416,1417,1418,1419,1420,1421,1422,1423,1424,1425,1426,1427,1428,1429,1430,1431,1432,1433,1434,1435,1436,1437,1438,1439,1440,1441,1442,1443,1444,1445,1446,1447,1448,1449,1450,1451,1453,1454,1455,1456,1457,1458,1459,1460,1461,1462,1463,1464,1465,1466,1467,1468,1469,1470,1471,1472,1473,1474,1475,1476,1477,1478,1479,1480,1481,1482,1483,1484,1485,1486,1487,1488,1489,1490,1491,1492,1493,1494,1495,1496,1497,1498,1499,1500,1501,1502,1503,1504,1505,1506,1507,1508,1510,1511,1512,1513,1514,1515,1516,1517,1518,1519,1520,1521,1522,1523,1524,1525,1526,1527,1528,1529,1530,1531,1532,1533,1534,1535,1536,1537,1538,1539,1540,1541,1542,1543,1544,1545,1546,1547,1548,1549,1550,1551,1552,1553,1554,1555,1556,1557,1558,1559,1560,1561,1562,1563,1564,1565,1566,1567,1568,1570,1571,1572,1573,1574,1575,1576,1577,1578,1579,1580,1582,1583,1585,1586,1587,1588,1589,1590,1591,1592,1593,1594,1595,1596,1597,1598,1599,1600,1601,1602,1603,1604,1605,1606,1607,1608,1609,1610,1611,1612,1613,1614,1615,1616,1617,1618,1619,1620,1621,1622,1623,1624,1625,1626,1627,1628,1629,1630,1631,1632,1633,1634,1635,1636,1637,1638,1639,1640,1641,1642,1643,1644,1645,1646,1647,1648,1649,1650,1651,1652,1653,1654,1655,1656,1657,1658,1659,1660,1661,1662,1663,1664,1665,1666,1667,1668,1669,1670,1671,1672,1673,1674,1675,1676,1677,1678,1679,1680,1681,1682,1683,1684,1685,1686,1687,1688,1689,1720,1721,1722,1723,1724,1725,1726,1727,1728,1729,1730,1731,1732,1733,1734,1735,1737,1738,1739,1740,1741,1742,1743,1745,1746,1747,1748,1749,1751,1752,1753,1754,1755,1756,1757,1758,1759,1760,1761,1762,1763,1764,1765,1766,1767,1768,1769,1770,1771,1772,1773,1774,1775,1776,1777,1778,1779,1780,1781,1782,1788,1789,1790,1791,1792,1795,1798,1799,1800,1801,1802,1803,1804,1805,1806,1807,1809,1811,1812,1813,1814,1815,1816,1817,1818,1819,1821,1822,1823,1824,1825,1826,1827,1828,1829,1830,1831,1832,1833,1834,1835,1836,1837,1838,1839,1840,1842,1843,1845,1846,1847,1848,1849,1850,1851,1853,1854,1856,1857,1858,1859,1860,1861,1862,1863,1864,1865,1866,1867,1868,1873,1874,1875,1876,1877,1878,1879,1880,1881,1882,1883,1884,1885,1886,1887,1888,1889,1890,1891,1892,1893,1894,1895,1896,1897,1898,1899,1900,1901,1902,1903,1904,1905,1906,1907,1908,1909,1911,1912,1913,1914,1915,1916,1917,1918,1919,1920,1921,1922,1923,1924,1925,1926,1927,1928,1929,1930,1931,1932,1933,1934,1935,1936,1937,1938,1939,1940,1941,1942,1943,1944,1945,1946,1947,1948,1949,1950,1951,1952,1953,1954,1955,1956,1957,1958,1959,1960,1962,1963,1964,1965,1966,1967,1968,1969,1970,1971,1972,1973,1974,1975,1976,1977,1978,1979,1980,1981,1982,1983,1984,1985,1986,1987,1988,1989,1990,1991,1993,1994,1996,1997,1999,2484,2485',
	@EqualityString = 'IN',
	@CategoryYN = 0,
	@CallistoDatabase = 'pcDATA_DC07B',
	@DebugBM = 3

EXEC [dbo].[spGet_MultiDimFilter]
	@UserID = 14572,
	@InstanceID = 621,
	@VersionID = 1105,
	@MultiDimensionID = 5822,
	@MultiDimensionName = 'FullAccount',
	@MultiHierarchyName = 'Consol_Narrative',
	@MultiDimFilter = 'Net_Income_',
	@LeafLevelFilter = '1023,1024,1025,1026,1027,1028,1029,1030,1031,1032',
	@EqualityString = 'IN',
	@CategoryYN = 0,
	@JournalYN = 0,
	@CallistoDatabase = 'pcDATA_PGL',
	@SQL_MultiDimJoin = '',
	@JobID = 0,
	@DebugBM = 3

EXEC [spGet_MultiDimFilter] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@SQL_MultiDimInsert nvarchar(2000) = '',
	@SQL_MultiDimSelect nvarchar(2000) = '',
	@DimensionID int = NULL,
	@DimensionName nvarchar(100),
	@JournalColumn nvarchar(50),
	@LoopNo nvarchar(15),
	@MultiDimFilter_MemberId bigint,
	@MultiDimFilterYN bit,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Template for creating SPs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2181' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2187' SET @Description = 'Fixed bug related to non filtered selections.'
		IF @Version = '2.1.2.2196' SET @Description = 'Calculate Multidim leaflevelfilter by CTE into temp table instead of using already calculated string.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @DebugBM & 2 > 0
			SELECT
				[@MultiDimensionID] = @MultiDimensionID,
				[@MultiDimensionName] = @MultiDimensionName,
				[@MultiHierarchyName] = @MultiHierarchyName,
				[@MultiDimFilter] = @MultiDimFilter,
				[@LeafLevelFilter] = @LeafLevelFilter,
				[@EqualityString] = @EqualityString,
				[@CategoryYN] = @CategoryYN,
				[@JournalYN] = @JournalYN,
				[@CallistoDatabase] = @CallistoDatabase,
				[@SQL_MultiDimJoin] = @SQL_MultiDimJoin

	SET @Step = 'Create temp table #MultiDim when needed'
		IF OBJECT_ID (N'tempdb..#MultiDim', N'U') IS NULL
			BEGIN
				CREATE TABLE #MultiDim
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Category_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Category_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Leaf_MemberId] bigint,
					[Leaf_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Leaf_Description] nvarchar(100) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Add needed columns to temp table #MultiDim'
		--Run cursor for adding columns to temp tables for MultiDim members
		SELECT @LoopNo = CONVERT(nvarchar(15), COUNT(1) + 1) FROM (SELECT DISTINCT DimensionName FROM #MultiDim) sub
		SET @SQL_MultiDimJoin = ISNULL(@SQL_MultiDimJoin, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN #MultiDim MD' + @LoopNo + ' ON MD' + @LoopNo + '.[DimensionName]=''' + @MultiDimensionName + ''' AND'

		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT
				sub.[DimensionName],
				[JournalColumn] = MAX(sub.[JournalColumn])
			FROM
				(
				SELECT
					D.[DimensionName],
					S.[JournalColumn],
					DP.[SortOrder]
				FROM
					[pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP
					INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.[InstanceID] IN (0, DP.[InstanceID]) AND P.PropertyID = DP.PropertyID AND P.[SelectYN] <> 0
					INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON P.[InstanceID] IN (0, DP.[InstanceID]) AND D.DimensionID = P.[DependentDimensionID] AND D.[SelectYN] <> 0 AND D.[DeletedID] IS NULL
					LEFT JOIN (SELECT [DimensionID], [JournalColumn] = CASE WHEN MAX([SegmentNo]) = 0 THEN 'Account' ELSE 'Segment' + CASE WHEN MAX([SegmentNo]) <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), MAX([SegmentNo])) END FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [SelectYN] <> 0 GROUP BY [DimensionID]) S ON S.[DimensionID] = P.[DependentDimensionID]
				WHERE
					DP.[InstanceID] = @InstanceID AND
					DP.[VersionID] = @VersionID AND
					DP.MultiDimYN <> 0 AND
					DP.DimensionID = @MultiDimensionID
				) sub
--Removed by JaWo 20230509
--Caused problems due to looking into temp tables for other calls
--Remove will possibly cause problem when using multiple MultiDims in the same dataclass
			--WHERE
			--	NOT EXISTS
			--		(
			--		SELECT 1
			--		FROM
			--			tempdb.sys.tables t
			--			INNER JOIN tempdb.sys.columns c ON c.[object_id] = t.[object_id]
			--		WHERE
			--			t.[name] LIKE '#MultiDim%' AND c.[name] = sub.[DimensionName] + '_MemberId'
			--		)
			GROUP BY
				sub.[DimensionName]
			ORDER BY
				MIN(sub.[SortOrder])

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @DimensionName, @JournalColumn

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName, [@JournalColumn] = @JournalColumn
					SET @SQLStatement = '
						ALTER TABLE #MultiDim ADD [' + @DimensionName + '_MemberId] bigint
						ALTER TABLE #MultiDim ADD [' + @DimensionName + '_MemberKey] nvarchar(50)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					SELECT
						@SQL_MultiDimInsert = @SQL_MultiDimInsert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberID],' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberKey],',
						@SQL_MultiDimSelect = @SQL_MultiDimSelect + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberID] = M.[' + @DimensionName + '_MemberID],' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '_MemberKey] = M.[' + @DimensionName + '],',
						@SQL_MultiDimJoin = @SQL_MultiDimJoin + CASE WHEN @JournalYN = 0 THEN ' MD' + @LoopNo + '.[' + @DimensionName + '_MemberId] = DC.[' + @DimensionName + '_MemberId] AND' ELSE ' MD' + @LoopNo + '.[' + @DimensionName + '_MemberKey] = J.[' + @JournalColumn + '] AND' END

					FETCH NEXT FROM AddColumn_Cursor INTO @DimensionName, @JournalColumn
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

		IF LEN(@SQL_MultiDimInsert) > 4 SET @SQL_MultiDimInsert = LEFT(@SQL_MultiDimInsert, LEN(@SQL_MultiDimInsert) - 1)
		IF LEN(@SQL_MultiDimSelect) > 4 SET @SQL_MultiDimSelect = LEFT(@SQL_MultiDimSelect, LEN(@SQL_MultiDimSelect) - 1)
		IF LEN(@SQL_MultiDimJoin) > 4 SET @SQL_MultiDimJoin = LEFT(@SQL_MultiDimJoin, LEN(@SQL_MultiDimJoin) - 4)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#MultiDim', * FROM #MultiDim ORDER BY DimensionID, Leaf_MemberId

	SET @Step = 'Create #LeafLevelFilterTable for @MultiDimFilter'
		SET @SQLStatement = '
			SELECT
				@InternalVariable = MemberId
			FROM
				' + @CallistoDatabase + '..S_DS_' + @MultiDimensionName + '
			WHERE
				[Label] = ''' + @MultiDimFilter + ''''

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @MultiDimFilter_MemberId OUT

		CREATE TABLE #SourceHierarchy
			(
			[MemberId] bigint,
			[ParentMemberId] bigint
			)

		SET @SQLStatement = '
			INSERT INTO #SourceHierarchy
				(
				[MemberId],
				[ParentMemberId]
				)
			SELECT
				D.[MemberID],
				D.[ParentMemberID]
			FROM
				' + @CallistoDatabase + '.dbo.S_HS_' + @MultiDimensionName + '_' + @MultiHierarchyName + ' D'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		CREATE TABLE #LeafLevelFilterTable
			(
			[MemberId] bigint
			)
		
		;WITH cte AS
		(
			--Find top nodes for tree
			SELECT
				D.[MemberID],
				D.[ParentMemberID]
			FROM
				#SourceHierarchy D
			WHERE
				D.[MemberID] = @MultiDimFilter_MemberId
			UNION ALL
			SELECT
				D.[MemberID],
				D.[ParentMemberID]
			FROM
				#SourceHierarchy D
				INNER JOIN cte c on c.[MemberID] = D.[ParentMemberID]
		)
		INSERT INTO #LeafLevelFilterTable
			(
			[MemberId]
			)
		SELECT
			[MemberId] = D.[MemberId]
		FROM
			cte
			INNER JOIN #SourceHierarchy D ON D.MemberID = cte.MemberID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#LeafLevelFilterTable', * FROM #LeafLevelFilterTable 
		
		SELECT @MultiDimFilterYN = CASE WHEN COUNT(1) > 0 THEN 1 ELSE 0 END FROM #LeafLevelFilterTable

	SET @Step = 'Fill temp table #MultiDim'
		IF @JournalYN <> 0
			SET @SQLStatement = '
				INSERT INTO #MultiDim
					(
					[DimensionID],
					[DimensionName],
					[HierarchyName],
					[Leaf_MemberId],
					[Leaf_MemberKey],
					[Leaf_Description]' + CASE WHEN LEN(@SQL_MultiDimInsert) > 0 THEN ',' + @SQL_MultiDimInsert ELSE '' END + '
					)
				SELECT DISTINCT
					[DimensionID] = ' + CONVERT(nvarchar(15), @MultiDimensionID) + ',
					[DimensionName] = ''' + @MultiDimensionName + ''',
					[HierarchyName] = ''' + @MultiHierarchyName + ''',
					[Leaf_MemberId] = M.[MemberId],
					[Leaf_MemberKey] = M.[Label],
					[Leaf_Description] = M.[Description]' + CASE WHEN LEN(@SQL_MultiDimSelect) > 0 THEN ',' + @SQL_MultiDimSelect ELSE '' END + '
				FROM
					[' + @CallistoDatabase + '].[dbo].[S_DS_' + @MultiDimensionName + '] M
					' + CASE WHEN @MultiDimFilterYN <> 0 THEN 'INNER JOIN #LeafLevelFilterTable LLFT ON LLFT.[MemberId] = M.[MemberId]' ELSE '' END + '
				WHERE
					M.NodeTypeBM & 1 > 0 AND
					NOT EXISTS (SELECT 1 FROM #MultiDim MD WHERE MD.[DimensionID] = ' + CONVERT(nvarchar(15), @MultiDimensionID) + ' AND MD.[Leaf_MemberKey] = M.[Label])
				ORDER BY
					[Leaf_MemberKey]'

		ELSE IF @CategoryYN <> 0
			SET @SQLStatement = '
				INSERT INTO #MultiDim
					(
					[DimensionID],
					[DimensionName],
					[HierarchyName],
					[Category_MemberKey],
					[Category_Description],
					[Leaf_MemberId],
					[Leaf_MemberKey],
					[Leaf_Description]' + CASE WHEN LEN(@SQL_MultiDimInsert) > 0 THEN ',' + @SQL_MultiDimInsert ELSE '' END + '
					)
				SELECT DISTINCT
					[DimensionID] = ' + CONVERT(nvarchar(15), @MultiDimensionID) + ',
					[DimensionName] = ''' + @MultiDimensionName + ''',
					[HierarchyName] = ''' + @MultiHierarchyName + ''',
					[Category_MemberKey] = P.[Label],
					[Category_Description] = P.[Description],
					[Leaf_MemberId] = M.[MemberId],
					[Leaf_MemberKey] = M.[Label],
					[Leaf_Description] = M.[Description]' + CASE WHEN LEN(@SQL_MultiDimSelect) > 0 THEN ',' + @SQL_MultiDimSelect ELSE '' END + '
				FROM
					[' + @CallistoDatabase + '].[dbo].[S_DS_' + @MultiDimensionName + '] M
					INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_' + @MultiDimensionName + '_' + @MultiHierarchyName + '] H ON H.MemberID = M.MemberID
					INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @MultiDimensionName + '] P ON P.NodeTypeBM & 1024 > 0 AND P.MemberID = H.ParentMemberID
					' + CASE WHEN @MultiDimFilterYN <> 0 THEN 'INNER JOIN #LeafLevelFilterTable LLFT ON LLFT.[MemberId] = M.[MemberId]' ELSE '' END + '
				WHERE
					M.NodeTypeBM & 1 > 0 AND
					NOT EXISTS (SELECT 1 FROM #MultiDim MD WHERE MD.[DimensionID] = ' + CONVERT(nvarchar(15), @MultiDimensionID) + ' AND MD.[Leaf_MemberKey] = M.[Label])
				ORDER BY
					[Category_MemberKey],
					[Leaf_MemberKey]'
		ELSE
			SET @SQLStatement = '
				INSERT INTO #MultiDim
					(
					[DimensionID],
					[DimensionName],
					[HierarchyName],
					[Leaf_MemberId],
					[Leaf_MemberKey],
					[Leaf_Description]' + CASE WHEN LEN(@SQL_MultiDimInsert) > 0 THEN ',' + @SQL_MultiDimInsert ELSE '' END + '
					)
				SELECT DISTINCT
					[DimensionID] = ' + CONVERT(nvarchar(15), @MultiDimensionID) + ',
					[DimensionName] = ''' + @MultiDimensionName + ''',
					[HierarchyName] = ''' + @MultiHierarchyName + ''',
					[Leaf_MemberId] = M.[MemberId],
					[Leaf_MemberKey] = M.[Label],
					[Leaf_Description] = M.[Description]' + CASE WHEN LEN(@SQL_MultiDimSelect) > 0 THEN ',' + @SQL_MultiDimSelect ELSE '' END + '
				FROM
					[' + @CallistoDatabase + '].[dbo].[S_DS_' + @MultiDimensionName + '] M
					' + CASE WHEN @MultiDimFilterYN <> 0 THEN 'INNER JOIN #LeafLevelFilterTable LLFT ON LLFT.[MemberId] = M.[MemberId]' ELSE '' END + '
				WHERE
					M.NodeTypeBM & 1 > 0 AND
					NOT EXISTS (SELECT 1 FROM #MultiDim MD WHERE MD.[DimensionID] = ' + CONVERT(nvarchar(15), @MultiDimensionID) + ' AND MD.[Leaf_MemberKey] = M.[Label])
				ORDER BY
					[Leaf_MemberKey]'

				IF @DebugBM & 2 > 0 
					BEGIN
						IF LEN(@SQLStatement) > 4000 
							BEGIN
								PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; INSERT INTO #MultiDim'
								EXEC [dbo].[spSet_wrk_Debug]
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@DatabaseName = @DatabaseName,
									@CalledProcedureName = @ProcedureName,
									@Comment = 'INSERT INTO #MultiDim', 
									@SQLStatement = @SQLStatement
							END
						ELSE
							PRINT @SQLStatement
					END
		
		EXEC(@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#MultiDim', * FROM #MultiDim
		IF @DebugBM & 2 > 0 SELECT [@SQL_MultiDimJoin] = @SQL_MultiDimJoin

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
