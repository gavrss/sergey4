SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_ETL_wrk_SourceTable_20230928]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceID int = NULL,
	@StartYear int = NULL,
	@TableCode nvarchar(50) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000745,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_ETL_wrk_SourceTable] @UserID=-10, @InstanceID=621, @VersionID=1105, @DebugBM=3

EXEC [spIU_ETL_wrk_SourceTable] @UserID=-10, @InstanceID=529, @VersionID=1001, @TableCode = 'SY24', @DebugBM=1
EXEC [spIU_ETL_wrk_SourceTable] @UserID=-10, @InstanceID=529, @VersionID=1001, @TableCode = 'GL12', @DebugBM=3

EXEC [spIU_ETL_wrk_SourceTable] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@SourceTypeFamilyID int,
	@SourceType nvarchar(50),
	@SourceDBTypeID int,
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(50),
	@Entity_MemberKey nvarchar(50),
	@TableName nvarchar(50),
	@YearlyYN int,
	@Counter int,
	@CenturySplit int,
	@Priority int,
	@ExistsYN bit,

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2175'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Fill table pcETL..wrk_SourceTable',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2165' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2167' SET @Description = 'Enhanced logging.'
		IF @Version = '2.1.1.2175' SET @Description = 'Modified queries for @SourceTypeFamilyID = 3 (Enterprise).'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		SELECT
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			pcINTEGRATOR_Data..[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT @CenturySplit = YEAR(GETDATE()) % 100 + 10

		IF @DebugBM & 2 > 0 
			SELECT
				[@ETLDatabase] = @ETLDatabase,
				[@CenturySplit] = @CenturySplit

	SET @Step = 'Create temp tables'
		CREATE TABLE #Database
			(
			[Entity_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DatabaseName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Priority] int
			)

		CREATE TABLE #SourceTable
			(
			[SourceID] [int] NOT NULL,
			[Entity_MemberKey] [nvarchar](50) COLLATE DATABASE_DEFAULT NOT NULL,
			[TableCode] [nvarchar](50) COLLATE DATABASE_DEFAULT NOT NULL,
			[DatabaseName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
			[TableName] [nvarchar](255) COLLATE DATABASE_DEFAULT NOT NULL,
			[FiscalYear] [int] NOT NULL,
			[Priority] [int] NULL,
			[Rows] [int] NOT NULL
			)

	SET @Step = 'Create master cursor'
		IF CURSOR_STATUS('global','SourceTable_Cursor') >= -1 DEALLOCATE SourceTable_Cursor
		DECLARE SourceTable_Cursor CURSOR FOR

			SELECT DISTINCT
				[SourceTypeFamilyID] = ST.[SourceTypeFamilyID],
				[SourceDBTypeID] = ST.[SourceDBTypeID],
				[SourceType] = ST.[SourceTypeName],
				[SourceDatabase] = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
				[ETLDatabase] = @ETLDatabase,
				[SourceID] = S.[SourceID],
				[StartYear] = ISNULL(@StartYear, S.[StartYear]),
				[TableCode] = STa.[TableCode],
				[YearlyYN] = STa.[YearlyYN]
			FROM
				pcINTEGRATOR..SourceTable STa
				INNER JOIN pcINTEGRATOR..Model BM ON BM.ModelBM & STa.ModelBM > 0 AND BM.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..Model M ON M.ModelID <> 0 AND M.BaseModelID = BM.ModelID AND M.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..[Source] S ON S.SourceID <> 0 AND S.ModelID = M.ModelID AND (S.SourceID = @SourceID OR @SourceID IS NULL) AND S.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = STa.SourceTypeFamilyID AND ST.SourceDBTypeID = 2 AND ST.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..[Application] A ON A.InstanceID = @InstanceID AND A.VersionID = @VersionID AND A.ApplicationID = M.ApplicationID AND '[' + A.ETLDatabase + ']' = @ETLDatabase AND A.SelectYN <> 0
			WHERE
				(STa.[TableCode] = @TableCode OR @TableCode IS NULL)

			OPEN SourceTable_Cursor
			FETCH NEXT FROM SourceTable_Cursor INTO @SourceTypeFamilyID, @SourceDBTypeID, @SourceType, @SourceDatabase, @ETLDatabase, @SourceID, @StartYear, @TableCode, @YearlyYN

			WHILE @@FETCH_STATUS = 0
			  BEGIN

			  	IF @DebugBM & 2 > 0 	
					SELECT
						[@CenturySplit] = @CenturySplit,
						[@SourceTypeFamilyID] = @SourceTypeFamilyID,
						[@SourceDBTypeID] = @SourceDBTypeID,
						[@SourceType] = @SourceType,
						[@SourceDatabase] = @SourceDatabase,
						[@ETLDatabase] = @ETLDatabase,
						[@SourceID] = @SourceID,
						[@StartYear] = @StartYear,
						[@TableCode] =  @TableCode

				SET @Step = 'Truncate temp tables'	
					TRUNCATE TABLE #Database
					TRUNCATE TABLE #SourceTable

				SET @Step = 'Fill temp table #Database'
					--IF @SourceTypeFamilyID = 5
					--	SET @SQLStatement = 'SELECT EntityCode, DatabaseName = ''' + @SourceDatabase + ''' FROM ' + @ETLDatabase + '.dbo.Entity WHERE SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND SelectYN <> 0'
					--ELSE
					--	SET @SQLStatement = 'SELECT EntityCode, DatabaseName = Par01 FROM ' + @ETLDatabase + '.dbo.Entity WHERE SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND SelectYN <> 0'
						
					--IF @DebugBM & 2 > 0 PRINT @SQLStatement
					--INSERT INTO #Database (EntityCode, DatabaseName) EXEC (@SQLStatement)

					INSERT INTO #Database
						(
						[Entity_MemberKey],
						[DatabaseName],
						[Priority]
						)
					SELECT 
						[Entity_MemberKey] = E.[MemberKey],
						[DatabaseName] = '[' + REPLACE(REPLACE(REPLACE(EPV.EntityPropertyValue, '[', ''), ']', ''), '.', '].[') + ']',
						[Priority] = ISNULL(E.[Priority], 99999999)
					FROM
						[pcINTEGRATOR_Data].[dbo].[Entity] E
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV ON EPV.InstanceID = E.InstanceID AND EPV.VersionID = E.VersionID AND EPV.EntityID = E.EntityID AND EPV.EntityPropertyTypeID=-1 AND EPV.SelectYN <> 0
					WHERE
						E.InstanceID = @InstanceID AND
						E.VersionID = @VersionID AND
						E.SelectYN <> 0 AND
						E.DeletedID IS NULL

					IF @DebugBM & 2 > 0 PRINT CONVERT(nvarchar, GETDATE() - @StartTime, 114)
					IF @DebugBM & 2 > 0 SELECT TempTable = '#Database', * FROM #Database ORDER BY [Entity_MemberKey]
 
				SET @Step = 'Start Database_Cursor'
					IF CURSOR_STATUS('global','Database_Cursor') >= -1 DEALLOCATE Database_Cursor
					DECLARE Database_Cursor CURSOR FOR

						SELECT 
							[Entity_MemberKey],
							[DatabaseName],
							[Priority]
						FROM
							#Database
						ORDER BY
							[Entity_MemberKey]

						OPEN Database_Cursor
						FETCH NEXT FROM Database_Cursor INTO @Entity_MemberKey, @DatabaseName, @Priority

						WHILE @@FETCH_STATUS = 0
						  BEGIN
							EXEC [spGet_DatabaseExistsYN] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @DatabaseName, @ExistsYN = @ExistsYN OUT, @JobID = @JobID, @Debug = @DebugSub
							IF @DebugBM & 2 > 0 SELECT [@Entity_MemberKey] = @Entity_MemberKey, [@DatabaseName] = @DatabaseName, [@Priority] = @Priority, [@ExistsYN] = @ExistsYN
							
							IF @ExistsYN = 0 SET @SQLStatement = ''

							IF @SourceTypeFamilyID = 2 AND @ExistsYN <> 0 --iScala
								BEGIN
									SET @SQLStatement = '
										SELECT
											[SourceID] = ' + CONVERT(nvarchar, @SourceID) + ',
											[Entity_MemberKey] = ''' + @Entity_MemberKey + ''',
											[TableCode] = ''' + @TableCode + ''',
											[DatabaseName] = ''' + @DatabaseName + ''',
											[TableName] = st.[name] COLLATE DATABASE_DEFAULT,
											[FiscalYear] = CASE WHEN CONVERT(int, SUBSTRING(st.[name], 7, 2)) < ' + CONVERT(nvarchar, @CenturySplit) + ' THEN 2000 + CONVERT(int, SUBSTRING(st.[name], 7, 2)) ELSE 1900 + CONVERT(int, SUBSTRING(st.[name], 7, 2)) END,
											[Priority] = ' + CONVERT(nvarchar(15), @Priority) + ',
											[Rows] = 0
										FROM
											' + @DatabaseName + '.sys.tables st
										WHERE
											st.[name] COLLATE DATABASE_DEFAULT LIKE ''' + @TableCode + '%' + ''' AND
											SUBSTRING(st.[name] COLLATE DATABASE_DEFAULT, 5, 2) = ''' + @Entity_MemberKey + ''' AND LEN(st.[name]) = 8 AND
											ISNUMERIC(SUBSTRING(st.[name], 7,2)) <> 0 AND' 

									SET @SQLStatement = @SQLStatement + '
											((CASE WHEN CONVERT(int, SUBSTRING(st.[name], 7, 2)) < ' + CONVERT(nvarchar, @CenturySplit) + ' THEN 2000 + CONVERT(int, SUBSTRING(st.[name], 7, 2)) ELSE 1900 + CONVERT(int, SUBSTRING(st.[name], 7, 2)) END >= ' + CONVERT(nvarchar, @StartYear) + ') OR 
											(SUBSTRING(st.[name], 7, 2) = ''00'' AND ' + CONVERT(nvarchar(10), @YearlyYN) + ' = 0))'					 
				
									SET @SQLStatement = @SQLStatement + '	 
										ORDER BY
											st.[name] DESC'
								END

							ELSE IF @SourceTypeFamilyID = 3 AND @ExistsYN <> 0 --Enterprise
								BEGIN
									SET @SQLStatement = '
										SELECT
											SourceID = ' + CONVERT(nvarchar, @SourceID) + ',
											Entity_MemberKey = ''' + @Entity_MemberKey + ''',
											TableCode = ''' + @TableCode + ''',
											DatabaseName = EPV.EntityPropertyValue,
											TableName = st.name COLLATE DATABASE_DEFAULT,
											FiscalYear = 0,
											[Priority] = ' + CONVERT(nvarchar(15), @Priority) + ',
											[Rows] = 0
										FROM
											[pcINTEGRATOR_Data].[dbo].Entity E
											INNER JOIN [pcINTEGRATOR_Data].dbo.EntityPropertyValue EPV ON EPV.InstanceID = E.InstanceID AND EPV.VersionID = E.VersionID and EPV.EntityID = E.EntityID AND EPV.EntityPropertyTypeID = -1
											INNER JOIN ' + @DatabaseName + '.dbo.sysobjects st ON xtype IN (''U'', ''V'') AND
												st.name COLLATE DATABASE_DEFAULT = ''' + @TableCode + '''
										WHERE
											E.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND
											E.VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ' AND
											E.SourceID = ' + CONVERT(NVARCHAR(15), @SourceID) + ' AND
											E.MemberKey = ''' + @Entity_MemberKey + ''' AND
											E.SelectYN <> 0'					 
				
									SET @SQLStatement = @SQLStatement + '	 
										ORDER BY
											EPV.EntityPropertyValue,
											st.name DESC'
								END

							ELSE IF @SourceTypeFamilyID = 5 AND @ExistsYN <> 0 --Navision
								BEGIN
									SET @SQLStatement = '
										SELECT
											SourceID = ' + CONVERT(nvarchar, @SourceID) + ',
											Entity_MemberKey = ''' + @Entity_MemberKey + ''',
											TableCode = ''' + @TableCode + ''',
											DatabaseName = ''' + @SourceDatabase + ''',
											TableName = st.name COLLATE DATABASE_DEFAULT,
											FiscalYear = 0,
											[Priority] = ' + CONVERT(nvarchar(15), @Priority) + ',
											[Rows] = 0
										FROM
											[' + @ETLDatabase + '].dbo.Entity E
											INNER JOIN ' + @DatabaseName + '.dbo.sysobjects st ON xtype IN (''U'', ''V'') AND
												st.name COLLATE DATABASE_DEFAULT = E.Par01 + ''' + @TableCode + '''
										WHERE
											E.SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND
											E.Entity_MemberKey = ''' + @Entity_MemberKey + ''' AND
											E.SelectYN <> 0'					 
				
									SET @SQLStatement = @SQLStatement + '	 
										ORDER BY
											st.name DESC'
								END

							IF @DebugBM & 2 > 0 
								BEGIN
									PRINT @Entity_MemberKey + ' ' + CONVERT(nvarchar, GETDATE() - @StartTime, 114)
									PRINT @SQLStatement
								END

							INSERT INTO #SourceTable ([SourceID], [Entity_MemberKey], [TableCode], [DatabaseName], [TableName], [FiscalYear], [Priority], [Rows]) EXEC (@SQLStatement)

							IF @DebugBM & 2 > 0 SELECT [@Entity_MemberKey] = @Entity_MemberKey, [RowCount] = COUNT(1) FROM #SourceTable
				
							FETCH NEXT FROM Database_Cursor INTO @Entity_MemberKey, @DatabaseName, @Priority
						  END

					CLOSE Database_Cursor
					DEALLOCATE Database_Cursor

					IF @DebugBM & 2 > 0 SELECT TempTable = '#SourceTable', * FROM #SourceTable WHERE SourceID = @SourceID AND TableCode = @TableCode ORDER BY Entity_MemberKey, FiscalYear DESC

				SET @Step = 'Start Table_Cursor'
					DECLARE Table_Cursor CURSOR FOR

						SELECT 
							DatabaseName,
							TableName
						FROM
							#SourceTable
						ORDER BY
							DatabaseName,
							TableName

						OPEN Table_Cursor
						FETCH NEXT FROM Table_Cursor INTO @DatabaseName, @TableName

						WHILE @@FETCH_STATUS = 0
						  BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DatabaseName] = @DatabaseName, [@TableName] = @TableName
							SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM ' + @DatabaseName + '.dbo.sysobjects WHERE xtype IN (''U'', ''V'') AND [name] = ''' + @TableName + ''''
							EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @Counter OUT
							
							IF  @DatabaseName = '[PGL_ScaCompany].[PGL_ScaCompany]' and @TableName  = 'GL030124' 
								BEGIN
								
									IF @DebugBM & 2 > 0 SELECT [@Counter] = @Counter 
								
								END

								ELSE 


							IF @Counter = 1
								BEGIN
									SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM ' + @DatabaseName + '.dbo.[' + @TableName + ']'
									EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @Counter OUT

									IF @DebugBM & 2 > 0 SELECT [@Counter] = @Counter

									IF @Counter > 0
										BEGIN
											UPDATE
												#SourceTable
											SET
												[Rows] = @Counter
											WHERE
												DatabaseName = @DatabaseName AND
												TableName = @TableName
										END
								END
							FETCH NEXT FROM Table_Cursor INTO @DatabaseName, @TableName
						  END

					CLOSE Table_Cursor
					DEALLOCATE Table_Cursor

				SET @Step = 'CleanUp'
					SET @SQLStatement = '
						DELETE ' + @ETLDatabase + '..wrk_SourceTable WHERE SourceID = ' + CONVERT(nvarchar(15), @SourceID) + ' AND TableCode = ''' + @TableCode + ''''
		
					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					SET @Deleted = @Deleted + @@ROWCOUNT

				SET @Step = 'Insert data into wrk_SourceTable'
					IF @DebugBM & 2 > 0 SELECT [TempTable] = '#SourceTable', * FROM #SourceTable ORDER BY [SourceID], [TableCode], [Entity_MemberKey], [TableName]

					SET @SQLStatement = '
						INSERT INTO ' + @ETLDatabase + '.[dbo].[wrk_SourceTable]
							(
							[SourceID],
							[TableCode],
							[Entity_MemberKey],
							[TableName],
							[FiscalYear],
							[Priority],
							[Rows]
							)
						 SELECT
							[SourceID] = iST.[SourceID],
							[TableCode] = iST.[TableCode],
							[Entity_MemberKey] = iST.[Entity_MemberKey],
							[TableName] = iST.[DatabaseName] + ''.[dbo].['' + iST.[TableName] + '']'',
							[FiscalYear] = iST.[FiscalYear],
							[Priority] = ist.[Priority],
							[Rows] = iST.[Rows]
						FROM
							#SourceTable iST
						WHERE
							[Rows] > 0'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT	

				FETCH NEXT FROM SourceTable_Cursor INTO @SourceTypeFamilyID, @SourceDBTypeID, @SourceType, @SourceDatabase, @ETLDatabase, @SourceID, @StartYear, @TableCode, @YearlyYN
				END

		CLOSE SourceTable_Cursor
		DEALLOCATE SourceTable_Cursor

		IF @DebugBM & 1 > 0
			BEGIN
				SET @SQLStatement = 'SELECT [Table] = ''' + @ETLDatabase + '.[dbo].[wrk_SourceTable]'', * FROM ' + @ETLDatabase + '.[dbo].[wrk_SourceTable] ORDER BY [SourceID], [TableCode], [Entity_MemberKey], [TableName], [FiscalYear]'
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Drop temp tables'	
		DROP TABLE #Database
		DROP TABLE #SourceTable

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
