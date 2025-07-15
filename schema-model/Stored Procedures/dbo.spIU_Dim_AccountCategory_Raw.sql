SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_AccountCategory_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,
	@SourceDatabase nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000644,
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
EXEC [spIU_Dim_AccountCategory_Raw] @DebugBM='7',@InstanceID='621',@UserID='-10',@VersionID='1105',@SourceTypeID=3,@SourceDatabase='dspsource04.PGL_ScaSystemDB'

EXEC [spIU_Dim_AccountCategory_Raw] @UserID = -10, @InstanceID = 619, @VersionID = 1104, @SourceTypeID = 11, @SourceDatabase = 'DSPSOURCE03.CCM_Epicor10', @Debug = 1
EXEC [spIU_Dim_AccountCategory_Raw] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @SourceTypeID = 12, @Debug = 1
EXEC [spIU_Dim_AccountCategory_Raw] @UserID = -10, @InstanceID = 15, @VersionID = 1039, @SourceTypeID = 11, @SourceDatabase = 'ERP10'

EXEC [spIU_Dim_AccountCategory_Raw] @UserID = -10, @InstanceID = 380, @VersionID = 1022, @SourceTypeID = 11, @SourceDatabase = 'RMC_Prod'
EXEC [spIU_Dim_AccountCategory_Raw] @UserID = -10, @InstanceID = 598, @VersionID = 1092, @SourceTypeID = 5, @SourceDatabase = 'dspsource01.pcSource_CIOT',@DebugBM=15

EXEC [spIU_Dim_AccountCategory_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN BIT = 1,
	@LinkedYN BIT,
	@SourceTypeName NVARCHAR(50),
	@SourceTypeDescription NVARCHAR(255),
	@SourceTypeBM INT,
	@SQLStatement NVARCHAR(MAX),
	@SourceID INT,
	@DimensionID INT = -65,
	@Entity_MemberKey NVARCHAR(50),
	@LinkedServer NVARCHAR(100),
	@SourceDatabase_Local NVARCHAR(100),
	@ReturnVariable INT,
	@TableName NVARCHAR(100),
	@FiscalYear INT,
	@ETLDatabase NVARCHAR(100),

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
	@ToBeChanged nvarchar(255) = 'Test if Source database is available',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of Account Categories from Source system',
			@MandatoryParameter = 'SourceTypeID|SourceDatabase' --Without @, separated by |

		IF @Version = '2.0.2.2147' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Made generic for all storage types.'
		IF @Version = '2.0.3.2151' SET @Description = 'Handle Enterprise.'
		IF @Version = '2.0.3.2154' SET @Description = 'Changed AccountType to Member.'
		IF @Version = '2.1.0.2159' SET @Description = 'Change Severity where not implemented SourceType from 16 to 10. Check existance of Source database.'
		IF @Version = '2.1.0.2160' SET @Description = 'Added P21, SourceTypeID = 5.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name. Modified checking of SourceDatabase existence.'
		IF @Version = '2.1.0.2162' SET @Description = 'Changed Intervals for Enterprise.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added INNER JOIN to [Entity_Book] for @SourceTypeID = 11; and added COLLATE DATABASE_DEFAULT on references to source tables.'
		IF @Version = '2.1.2.2190' SET @Description = 'Fixed the error [Must declare the scalar variable "@InternalVariable"].'
		IF @Version = '2.1.2.2193' SET @Description = '1. Replace brackets [] in @LinkedServer, 2. HOT-FIX: exclude checking linked server for AZURE: ...AND (NOT @LinkedServer LIKE ''%EFP-SQL-USEA02%'') '
		IF @Version = '2.1.2.2197' SET @Description = 'DB-1416: Set Statistical AccountType for iScala sourceType.'
		IF @Version = '2.1.2.2199' SET @Description = 'FEA-10119: Azure SQL doesn''t have "master" database, regular MSSQL Server doesn''t need to use prefix "master" for "sp_executesql" command. So: excluded [Master] from dynamic sql on  @Step = ''Check existence of Source Database'''

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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF CHARINDEX('.', @SourceDatabase) > 0
			BEGIN
				SELECT @LinkedServer = LEFT(@SourceDatabase, CHARINDEX('.', @SourceDatabase) - 1)
				SELECT @SourceDatabase_Local = SUBSTRING(@SourceDatabase, CHARINDEX('.', @SourceDatabase) + 1, LEN(@SourceDatabase))
			END

		SET @LinkedServer = '[' + REPLACE(REPLACE(REPLACE(@LinkedServer, '[', ''), ']', ''), '.', '].[') + ']';

		IF @DebugBM & 2 > 0	SELECT [@LinkedServer] = @LinkedServer, [@SourceDatabase_Local] = @SourceDatabase_Local, [@SourceDatabase] = @SourceDatabase

		IF @SourceTypeID IS NULL
			SELECT @SourceTypeID = 7 FROM pcINTEGRATOR_Data..SIE4_Job WHERE InstanceID = @InstanceID AND JobID = @JobID

		SELECT
			@SourceTypeName = SourceTypeName,
			@SourceTypeDescription = SourceTypeDescription
		FROM
			SourceType
		WHERE
			SourceTypeID = @SourceTypeID

		SELECT
			@SourceTypeBM = SUM(SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				SourceTypeBM
			FROM
				SourceType ST
				INNER JOIN [Source] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.SourceTypeID = ST.SourceTypeID AND S.SelectYN <> 0
			UNION SELECT DISTINCT
				SourceTypeBM
			FROM
				SourceType ST
			WHERE
				ST.SourceTypeID = @SourceTypeID
			) sub

		IF OBJECT_ID(N'TempDB.dbo.#AccountCategory_Members', N'U') IS NULL SET @CalledYN = 0

		SELECT
			@SourceID = S.[SourceID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Source] S
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.[ModelID] = S.[ModelID] AND M.[ModelBM] & 64 > 0 AND M.[SelectYN] <> 0
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SourceTypeID] = @SourceTypeID AND
			S.[SelectYN] <> 0

		IF @DebugBM & 2 > 0
			SELECT
				[@SourceID] = @SourceID,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName,
				[@SourceTypeDescription] = @SourceTypeDescription,
				[@SourceTypeBM] = @SourceTypeBM,
				[@CalledYN] = @CalledYN,
				[@LinkedServer] = @LinkedServer

	SET @Step = 'Handle ANSI_WARNINGS'
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = 'Create temp table #AccountCategory_Members_Raw'
		CREATE TABLE #AccountCategory_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[AccountType] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Get parent member'
		INSERT INTO #AccountCategory_Members_Raw
			(
			[MemberId],
			[MemberKey],
			[Description],
			[HelpText],
			[AccountType],
			[NodeTypeBM],
			[Source],
			[Parent]
			)
		SELECT
			[MemberId] = NULL,
			[MemberKey] = @SourceTypeName,
			[Description] = @SourceTypeDescription,
			[HelpText] = @SourceTypeDescription,
			[AccountType] = 'NONE',
			[NodeTypeBM] = 2,
			[Source] = 'ETL',
			[Parent] = 'All_'

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Check existence of Source Database'
		--Must check linked server...
		IF @SourceTypeID <> 7
			BEGIN
				IF @LinkedServer IS NOT NULL AND @SourceDatabase_Local IS NOT NULL
					AND (NOT @LinkedServer LIKE '%EFP-SQL-USEA02%') -- hot-fix: Linked server to Azure SQL doesn't support cross-database query, so we can't have linked server to user database and do "exec [Master].dbo.sp_executesql ..."
																	-- ToDo: It should be fixed later
					BEGIN
						SET @SQLStatement = '
							DECLARE @ReturnVar INT
							EXEC ' + @LinkedServer + '..dbo.sp_executesql N''SELECT @InternalVar = DB_ID(''''' + @SourceDatabase_Local + ''''')'', N''@InternalVar int OUT'', @InternalVar = @ReturnVar OUT
							SELECT @InternalVariable = @ReturnVar'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement

						EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ReturnVariable OUT
						IF @DebugBM & 2 > 0 SELECT [@ReturnVariable] = @ReturnVariable

						IF (@ReturnVariable) IS NULL
							GOTO STATICPOINT
					END
				ELSE
					IF DB_ID(@SourceDatabase) IS NULL
						GOTO STATICPOINT
			END

	SET @Step = 'Fill temptable #AccountCategory_Members_Raw'
		IF @SourceTypeID = 1 --Epicor ERP (E9)
			BEGIN
				SET @Message = 'Code for Epicor ERP (E9) is not yet implemented.'
				SET @Severity = 10
				GOTO EXITPOINT
			END

		ELSE IF @SourceTypeID = 3 --iScala
			BEGIN
				SELECT
					@ETLDatabase = [ETLDatabase]
				FROM
					pcINTEGRATOR_Data..[Application]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID

				SET @Step = 'Create and fill temp tables'
					CREATE TABLE #iScalaCursor
						(
						Entity_MemberKey nvarchar(50) COLLATE DATABASE_DEFAULT,
						TableName nvarchar(255) COLLATE DATABASE_DEFAULT,
						FiscalYear int,
						SortOrder int
						)

					SET @SQLStatement = '
						INSERT INTO #iScalaCursor
							(
							Entity_MemberKey,
							TableName,
							FiscalYear,
							SortOrder
							)
						SELECT
							wST.Entity_MemberKey,
							TableName,
							FiscalYear,
							SortOrder = ISNULL(E.Priority, 99999999)
						FROM
							' + @ETLDatabase + '..[wrk_SourceTable] wST
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.MemberKey = wST.Entity_MemberKey AND E.SelectYN <> 0 AND E.DeletedID IS NULL
						WHERE
							wST.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
							wST.[TableCode] = ''GL53'''

					EXEC (@SQLStatement)

					CREATE TABLE #iScalaCategory
						(
						[CategoryID] nvarchar(50) COLLATE DATABASE_DEFAULT,
						[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
						[iScala_Type] int
						)

				SET @Step = 'Loop and fill data into temp table from GL53'
  					SET @SQLStatement = ''

					DECLARE iScala_AccountType_Translate_Cursor CURSOR FOR

					SELECT Entity_MemberKey, TableName, FiscalYear FROM #iScalaCursor ORDER BY SortOrder, FiscalYear DESC

					OPEN iScala_AccountType_Translate_Cursor
					FETCH NEXT FROM iScala_AccountType_Translate_Cursor INTO @Entity_MemberKey, @TableName, @FiscalYear

					WHILE @@FETCH_STATUS = 0
					  BEGIN
	  					SET @SQLStatement = 'INSERT INTO #iScalaCategory
								(
								[CategoryID],
								[Description],
								[iScala_Type]
								)
							SELECT
								[CategoryID] = SUBSTRING(GL53001, 1, 2),
								[Description] = MAX(SUBSTRING(GL53001, 1, 2)),
								[iScala_Type] = MAX(GL53003)
							FROM
								' + @TableName + ' ST
							WHERE
								--ISNUMERIC(SUBSTRING(GL53001, 1, 2)) <> 0 AND
								NOT EXISTS (SELECT 1 FROM #iScalaCategory iSC WHERE iSC.[CategoryID] = SUBSTRING(ST.GL53001, 1, 2) COLLATE DATABASE_DEFAULT)
							GROUP BY
								SUBSTRING(GL53001, 1, 2)'

						EXEC (@SQLStatement)

						IF @DebugBM & 8 > 0 SELECT [LastSourceTable] = @TableName, * FROM #iScalaCategory ORDER BY [CategoryID]

						FETCH NEXT FROM iScala_AccountType_Translate_Cursor INTO @Entity_MemberKey, @TableName, @FiscalYear
					  END

					CLOSE iScala_AccountType_Translate_Cursor
					DEALLOCATE iScala_AccountType_Translate_Cursor

					IF @DebugBM & 2 > 0 SELECT [SourceTableType] = 'GL53', * FROM #iScalaCategory ORDER BY [CategoryID]

				SET @Step = 'Collect information from GL12'
					TRUNCATE TABLE #iScalaCursor

					SET @SQLStatement = '
						INSERT INTO #iScalaCursor
							(
							Entity_MemberKey,
							TableName,
							FiscalYear,
							SortOrder
							)
						SELECT
							wST.Entity_MemberKey,
							TableName,
							FiscalYear,
							SortOrder = ISNULL(E.Priority, 99999999)
						FROM
							' + @ETLDatabase + '..[wrk_SourceTable] wST
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.MemberKey = wST.Entity_MemberKey AND E.SelectYN <> 0 AND E.DeletedID IS NULL
						WHERE
							wST.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
							TableCode = ''GL12'''

					EXEC (@SQLStatement)
					IF @DebugBM & 2 > 0 SELECT TempTable = '#iScalaCursor', * FROM #iScalaCursor ORDER BY SortOrder, FiscalYear DESC

				SET @Step = 'Add specific members to temp table'

					IF CURSOR_STATUS('global','iScala_AccountType_Hierarchy_Cursor') >= -1 DEALLOCATE iScala_AccountType_Hierarchy_Cursor
					DECLARE iScala_AccountType_Hierarchy_Cursor CURSOR FOR

					SELECT Entity_MemberKey, TableName, FiscalYear FROM #iScalaCursor ORDER BY SortOrder, FiscalYear DESC

					OPEN iScala_AccountType_Hierarchy_Cursor
					FETCH NEXT FROM iScala_AccountType_Hierarchy_Cursor INTO @Entity_MemberKey, @TableName, @FiscalYear

					WHILE @@FETCH_STATUS = 0
					  BEGIN
	  					SET @SQLStatement = '
							INSERT INTO #iScalaCategory
								(
								[CategoryID],
								[Description],
								[iScala_Type]
								)
							SELECT
								[CategoryID] = CONVERT(nvarchar(50), ST.GL12001),
								[Description] = MAX(ST.GL12002),
								[iScala_Type] = NULL
							FROM
								' + @TableName + ' ST
							WHERE
								NOT EXISTS (SELECT 1 FROM #iScalaCategory iSC WHERE iSC.[CategoryID] = CONVERT(nvarchar(50), ST.GL12001) COLLATE DATABASE_DEFAULT)
							GROUP BY
								ST.GL12001'

						EXEC (@SQLStatement)

						IF @DebugBM & 8 > 0 SELECT [LastSourceTable] = @TableName, * FROM #iScalaCategory iSC ORDER BY iSC.CategoryID

						--IF @Debug <> 0
						--	BEGIN
						--		PRINT @SQLStatement
						--		SELECT * FROM #iScalaCategory
						--		SET @SQLStatement = '
						--			SELECT iSC.*
						--			FROM
						--				#iScalaCategory iSC
						--				INNER JOIN ' + @TableName + ' ST ON ST.GL12001 COLLATE DATABASE_DEFAULT = iSC.CategoryID'

						--		EXEC (@SQLStatement)

						--	END

						FETCH NEXT FROM iScala_AccountType_Hierarchy_Cursor INTO @Entity_MemberKey, @TableName, @FiscalYear
					  END

					CLOSE iScala_AccountType_Hierarchy_Cursor
					DEALLOCATE iScala_AccountType_Hierarchy_Cursor

				SET @Step = 'Update Description in temp table'

					DECLARE iScala_AccountType_Description_Cursor CURSOR FOR

					SELECT Entity_MemberKey, TableName, FiscalYear FROM #iScalaCursor ORDER BY SortOrder DESC, FiscalYear

					OPEN iScala_AccountType_Description_Cursor
					FETCH NEXT FROM iScala_AccountType_Description_Cursor INTO @Entity_MemberKey, @TableName, @FiscalYear

					WHILE @@FETCH_STATUS = 0
					  BEGIN
	  					SET @SQLStatement = '
							UPDATE iSC
							SET
								[Description] = ST.GL12002
							FROM
								#iScalaCategory iSC
								INNER JOIN ' + @TableName + ' ST ON ST.GL12001 COLLATE DATABASE_DEFAULT = iSC.CategoryID'

						EXEC (@SQLStatement)

						IF @DebugBM & 2 > 0
							BEGIN
								PRINT @SQLStatement
								SELECT * FROM #iScalaCategory
								SET @SQLStatement = '
									SELECT iSC.*
									FROM
										#iScalaCategory iSC
										INNER JOIN ' + @TableName + ' ST ON ST.GL12001 COLLATE DATABASE_DEFAULT = iSC.CategoryID'

								EXEC (@SQLStatement)

							END

						FETCH NEXT FROM iScala_AccountType_Description_Cursor INTO @Entity_MemberKey, @TableName, @FiscalYear
					  END

					CLOSE iScala_AccountType_Description_Cursor
					DEALLOCATE iScala_AccountType_Description_Cursor

				INSERT INTO #iScalaCategory
					(
					[CategoryID],
					[Description]
					)
				SELECT DISTINCT
					[CategoryID] = LEFT([CategoryID], 1),
					[Description] = LEFT([CategoryID], 1)
				FROM
					#iScalaCategory iSC
				WHERE
					NOT EXISTS (SELECT 1 FROM #iScalaCategory isCD WHERE isCD.[CategoryID] = LEFT(iSC.[CategoryID], 1))

				IF @DebugBM & 2 > 0 SELECT TempTable = '#iScalaCategory', * FROM #iScalaCategory ORDER BY [CategoryID]

				INSERT INTO #AccountCategory_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[AccountType],
					[NodeTypeBM],
					[Source],
					[Parent]
					)
				SELECT TOP 10000
					[MemberId] = NULL,
					[MemberKey] = iSC.[CategoryID],
					[Description] = MAX(iSC.[Description]),
					[HelpText] = MAX(iSC.[Description]),
					AccountType = CASE MAX(iSC.[iScala_Type])
									WHEN '0' THEN CASE WHEN SUBSTRING(iSC.CategoryID, 1, 1) = '3' THEN 'Income' ELSE 'Expense' END
									WHEN '1' THEN CASE WHEN SUBSTRING(iSC.CategoryID, 1, 1) = '2' THEN CASE WHEN SUBSTRING(iSC.CategoryID, 1, 2) IN ('25', '26') THEN 'Liability' ELSE 'Equity' END ELSE 'Asset' END
									--WHEN '2' THEN 'Expense'
									WHEN '2' THEN CASE WHEN ISNUMERIC(SUBSTRING(iSC.CategoryID, 1, 2)) <> 0 THEN 'Expense' ELSE 'Statistical' END
									ELSE  NULL
								END,
					[NodeTypeBM] = CASE LEN(iSC.[CategoryID]) WHEN 1 THEN 18 WHEN 2 THEN 1 END,
					[Source] = @SourceTypeName,
					[Parent] = CASE LEN(iSC.[CategoryID]) WHEN 1 THEN @SourceTypeName WHEN 2 THEN LEFT(iSC.[CategoryID], 1) END
				FROM
					#iScalaCategory iSC
				GROUP BY
					iSC.CategoryID
				ORDER BY
					iSC.CategoryID

				SET @Selected = @Selected + @@ROWCOUNT
			END

		ELSE IF @SourceTypeID = 5 --P21
			BEGIN
				INSERT INTO #AccountCategory_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[AccountType],
					[NodeTypeBM],
					[Source],
					[Parent]
					)
				SELECT
					[MemberId] = NULL,
					[MemberKey] = sub.[MemberKey],
					[Description] = sub.[Description],
					[HelpText] = sub.[Description],
					[AccountType] = sub.[AccountType],
					[NodeTypeBM] = 1,
					[Source] = @SourceTypeName,
					[Parent] = @SourceTypeName
				FROM
					(
					SELECT [MemberKey] = 'A', [Description] = 'Asset', [AccountType] = 'Asset'
					UNION SELECT [MemberKey] = 'C', [Description] = 'Liabilities', [AccountType] = 'Liability'
					UNION SELECT [MemberKey] = 'E', [Description] = 'Equity', [AccountType] = 'Equity'
					UNION SELECT [MemberKey] = 'F', [Description] = 'Fixed Asset', [AccountType] = 'Asset'
					UNION SELECT [MemberKey] = 'L', [Description] = 'Long Term Liabilities', [AccountType] = 'Liability'
					UNION SELECT [MemberKey] = 'R', [Description] = 'Revenue', [AccountType] = 'Income'
					UNION SELECT [MemberKey] = 'S', [Description] = 'Short Term Asset', [AccountType] = 'Asset'
					UNION SELECT [MemberKey] = 'X', [Description] = 'Expense', [AccountType] = 'Expense'
					) sub

			END

		ELSE IF @SourceTypeID = 7 --SIE4
			BEGIN
				INSERT INTO #AccountCategory_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[AccountType],
					[NodeTypeBM],
					[Source],
					[Parent]
					)
				SELECT DISTINCT
					[MemberId] = NULL,
					[MemberKey] = O.[ObjectName],
					[Description] = CASE O.[ObjectName]
										WHEN 'T' THEN 'Asset'
										WHEN 'S' THEN 'Equity'
										WHEN 'K' THEN 'Expense'
										WHEN 'I' THEN 'Income'
										WHEN '0' THEN 'Liability'
										ELSE 'NONE' END,
					[AccountType] = CASE O.[ObjectName]
										WHEN 'T' THEN 'Asset'
										WHEN 'S' THEN 'Equity'
										WHEN 'K' THEN 'Expense'
										WHEN 'I' THEN 'Income'
										WHEN '0' THEN 'Liability'
										ELSE 'NONE' END,
					[NodeTypeBM] = 1,
					[Source] = @SourceTypeName,
					[Parent] = @SourceTypeName
				FROM
					[pcINTEGRATOR_Data].[dbo].[SIE4_Object] O
				WHERE
					[InstanceID] = @InstanceID AND
					[JobID] = @JobID AND
					[Param] = '#KTYP' AND
					[DimCode] = 'Account'

				SET @Selected = @Selected + @@ROWCOUNT
			END

		ELSE IF @SourceTypeID = 8 --Navision
			BEGIN
				SET @Message = 'Code for Navision is not yet implemented.'
				SET @Severity = 10
				GOTO EXITPOINT
			END

		ELSE IF @SourceTypeID = 11 --Epicor ERP (E10)
			BEGIN
				--Note pcETL..Entity.Par03 (COACode) must be set as a property on books and referenced in the query below (Hardcoded to 'MAIN')
				IF @DebugBM & 2 > 0 SELECT [@SourceTypeName] = @SourceTypeName, [@SourceDatabase] = @SourceDatabase, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID

				SET @SQLStatement = '
					INSERT INTO #AccountCategory_Members_Raw
						(
						[MemberId],
						[MemberKey],
						[Description],
						[HelpText],
						[AccountType],
						[NodeTypeBM],
						[Source],
						[Parent]
						)
					SELECT
						[MemberId] = NULL,
						[MemberKey] = sub.[CategoryID],
						[Description] = sub.[Description],
						[HelpText] = sub.[Description],
						[AccountType] = sub.[AccountType],
						[NodeTypeBM] = 1,
						[Source] = ''' + @SourceTypeName + ''',
						[Parent] = ''' + @SourceTypeName + '''
					FROM
						(
						SELECT
							[CategoryID] = COA.CategoryID,
							[Description] = MAX(COA.[Description]),
							[AccountType] = CASE WHEN MAX(COA.[Type]) = ''I'' AND MAX(COA.[NormalBalance]) = ''D'' THEN ''Expense'' ELSE
											CASE WHEN MAX(COA.[Type]) = ''I'' AND MAX(COA.[NormalBalance]) = ''C'' THEN ''Income'' ELSE
											CASE WHEN MAX(COA.[Type]) = ''B'' AND MAX(COA.[NormalBalance]) = ''D'' THEN ''Asset'' ELSE
											CASE WHEN MAX(COA.[Type]) = ''B'' AND MAX(COA.[NormalBalance]) = ''C'' THEN
												CASE WHEN COA.CategoryID LIKE ''%EQUIT%'' OR MAX(COA.[Description]) LIKE ''%EQUIT%'' THEN ''Equity'' ELSE ''Liability'' END ELSE
											NULL END END END END
						FROM
							' + @SourceDatabase + '.[erp].[COAActCat] COA
							INNER JOIN ' + @SourceDatabase + '.[erp].[GLBook] GLB ON GLB.Company = COA.Company AND GLB.COACode = COA.COACode
							INNER JOIN Entity E ON E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND E.MemberKey = COA.Company COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
							INNER JOIN [pcINTEGRATOR_Data].[dbo].Entity_Book EB ON EB.EntityID = E.EntityID AND EB.COA = COA.COACode COLLATE DATABASE_DEFAULT AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.SelectYN <> 0
							INNER JOIN (
								SELECT COA.CategoryID, Priority = MIN(ISNULL(Priority, 99999999))
								FROM
									Entity E
									INNER JOIN ' + @SourceDatabase + '.[erp].[COAActCat] COA ON COA.Company COLLATE DATABASE_DEFAULT = E.MemberKey
								WHERE
									E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
									E.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND
									E.SelectYN <> 0
								GROUP BY
									COA.CategoryID
									) Prio ON Prio.CategoryID = COA.CategoryID AND Prio.Priority = ISNULL(E.Priority, 99999999)
						GROUP BY
							COA.CategoryID

						UNION
						SELECT
							[CategoryID] = ''ST_'' + COA.CategoryID,
							[Description] = MAX(COA.[Description]),
							[AccountType] = ''Income''
						FROM
							' + @SourceDatabase + '.[erp].[COAActCat] COA
							INNER JOIN ' + @SourceDatabase + '.[erp].[GLBook] GLB ON GLB.Company = COA.Company AND GLB.COACode = COA.COACode
							INNER JOIN Entity E ON E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND E.MemberKey = COA.Company COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
							INNER JOIN (SELECT DISTINCT Category FROM ' + @SourceDatabase + '.[erp].[COASegValues] COASV WHERE Statistical <> 0) ST ON ST.Category = COA.CategoryID
						GROUP BY
							COA.CategoryID
						) sub'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

		ELSE IF @SourceTypeID = 12 --Enterprise (E7)
			BEGIN
				CREATE TABLE #CursorTable
					(
					Entity_MemberKey nvarchar(100),
					SourceDatabase nvarchar(100),
					SortOrder int
					)

				CREATE TABLE #ATT
					(
					[CategoryID] nvarchar(10),
					[Description] nvarchar(255)
					)

				INSERT INTO #CursorTable
					(
					Entity_MemberKey,
					SourceDatabase,
					SortOrder
					)
				SELECT
					Entity_MemberKey = E.MemberKey,
					SourceDatabase = EPV.EntityPropertyValue,
					SortOrder = ISNULL([Priority], 99999999)
				FROM
					pcINTEGRATOR_Data..Entity E
					INNER JOIN pcINTEGRATOR_Data..EntityPropertyValue EPV ON EPV.InstanceID = E.InstanceID AND EPV.VersionID = E.VersionID AND EPV.EntityID = E.EntityID AND EPV.EntityPropertyTypeID = -1
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.EntityTypeID = -1 AND
					E.SelectYN <> 0

				IF CURSOR_STATUS('global','Ent_AccountType_Translate_Cursor') >= -1 DEALLOCATE Ent_AccountType_Translate_Cursor
				DECLARE Ent_AccountType_Translate_Cursor CURSOR FOR

				SELECT Entity_MemberKey, SourceDatabase FROM #CursorTable ORDER BY SortOrder

				OPEN Ent_AccountType_Translate_Cursor
				FETCH NEXT FROM Ent_AccountType_Translate_Cursor INTO @Entity_MemberKey, @SourceDatabase

				WHILE @@FETCH_STATUS = 0
				  BEGIN

	  				SET @SQLStatement = '
					INSERT INTO #ATT
						(
						[CategoryID],
						[Description]
						)
					SELECT DISTINCT
						[CategoryID] = gt.type_code,
						[Description] = gt.type_description
					FROM
						' + @SourceDatabase + '.[dbo].[glactype] gt
					WHERE
						NOT EXISTS (SELECT 1 FROM #ATT A WHERE A.CategoryID = gt.type_code)'

					EXEC (@SQLStatement)

					FETCH NEXT FROM Ent_AccountType_Translate_Cursor INTO @Entity_MemberKey, @SourceDatabase
				  END

				CLOSE Ent_AccountType_Translate_Cursor
				DEALLOCATE Ent_AccountType_Translate_Cursor

				INSERT INTO #AccountCategory_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[AccountType],
					[NodeTypeBM],
					[Source],
					[Parent]
					)
				SELECT
					[MemberId] = NULL,
					[MemberKey] = [CategoryID],
					[Description] = [Description],
					[HelpText] =[Description],
					[AccountType] = CASE
										WHEN CategoryID BETWEEN 100 AND 199 THEN 'Asset'
										WHEN CategoryID BETWEEN 200 AND 299 THEN 'Liability'
										WHEN CategoryID BETWEEN 300 AND 399 THEN 'Equity'
										WHEN CategoryID BETWEEN 400 AND 449 THEN 'Income'
										WHEN CategoryID BETWEEN 450 AND 589 THEN 'Expense'
										WHEN CategoryID BETWEEN 590 AND 599 THEN 'Equity'
										ELSE 'Expense'
									END,
					[NodeTypeBM] = 1,
					[Source] = @SourceTypeName,
					[Parent] = @SourceTypeName
				FROM
					#ATT
			END

		ELSE IF @SourceTypeID = 15 --pcSource
			BEGIN
				SET @Message = 'Code for pcSource is not yet implemented.'
				SET @Severity = 10
				GOTO EXITPOINT
			END

		ELSE
			BEGIN
				SET @Message = 'Code for selected SourceTypeID (' + CONVERT(nvarchar(15), @SourceTypeID) + ') is not yet implemented.'
				SET @Severity = 10
				GOTO EXITPOINT
			END

	SET @Step = 'Get default members'
		STATICPOINT:
		INSERT INTO #AccountCategory_Members_Raw
			(
			[MemberId],
			[MemberKey],
			[Description],
			[HelpText],
			[AccountType],
			[NodeTypeBM],
			[Source],
			[Parent]
			)
		SELECT
			[MemberId],
			[MemberKey] = [Label],
			[Description] = REPLACE([Description], '@All_Dimension', 'All Account Categories'),
			[HelpText],
			[AccountType] = 'NONE',
			[NodeTypeBM],
			[Source] = 'ETL',
			[Parent]
		FROM
			Member
		WHERE
			DimensionID IN (0, @DimensionID) AND
			[SourceTypeBM] & @SourceTypeBM > 0

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#AccountCategory_Members_Raw',
					*
				FROM
					#AccountCategory_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#AccountCategory_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[AccountType],
					[AccountType_MemberID],
					[NodeTypeBM],
					[SBZ],
					[Source],
					[Synchronized],
					[Parent]
					)
				SELECT TOP 1000000
					[MemberId] = ISNULL([MaxRaw].[MemberId], M.MemberID),
					[MemberKey] = [MaxRaw].[MemberKey],
					[Description] = [MaxRaw].[Description],
					[HelpText] = CASE WHEN [MaxRaw].[HelpText] = '' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END,
					[AccountType],
					[AccountType_MemberID] = ISNULL(MAT.[MemberID], -1),
					[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
					[SBZ] = [MaxRaw].[SBZ],
					[Source] = [MaxRaw].[Source],
					[Synchronized] = 1,
					[Parent] = CASE [MaxRaw].[Parent] WHEN 'NULL' THEN NULL ELSE [MaxRaw].[Parent] END
				FROM
					(
					SELECT
						[MemberId] = MAX([Raw].[MemberId]),
						[MemberKey] = [Raw].[MemberKey],
						[Description] = MAX([Raw].[Description]),
						[HelpText] = MAX([Raw].[HelpText]),
						[AccountType] = MAX([Raw].[AccountType]),
						[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
						[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), [Raw].[MemberKey]),
						[Source] = MAX([Raw].[Source]),
						[Synchronized] = 1,
						[Parent] = MAX([Raw].[Parent])
					FROM
						[#AccountCategory_Members_Raw] [Raw]
					GROUP BY
						[Raw].[MemberKey]
					) [MaxRaw]
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = @DimensionID AND M.[Label] = [MaxRaw].MemberKey
					LEFT JOIN pcINTEGRATOR..Member MAT ON MAT.DimensionID = -62 AND MAT.[Label] = [MaxRaw].[AccountType]
				WHERE
					[MaxRaw].[MemberKey] IS NOT NULL
				ORDER BY
					CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		IF OBJECT_ID (N'tempdb..#CursorTable', N'U') IS NOT NULL DROP TABLE #CursorTable
		IF OBJECT_ID (N'tempdb..#ATT', N'U') IS NOT NULL DROP TABLE #ATT
		DROP TABLE #AccountCategory_Members_Raw

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
