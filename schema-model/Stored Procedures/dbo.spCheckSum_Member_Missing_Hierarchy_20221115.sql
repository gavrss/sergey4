SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create PROCEDURE [dbo].[spCheckSum_Member_Missing_Hierarchy_20221115]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 1, --1=generate new CheckSumStatus count, 2=get CheckSumStatus count, 4=Details (of @CheckSumStatusBM) 
	@CheckSumValue int = NULL OUT,
	@CheckSumStatus10 int = NULL OUT,
	@CheckSumStatus20 int = NULL OUT,
	@CheckSumStatus30 int = NULL OUT,
	@CheckSumStatus40 int = NULL OUT,
	@CheckSumStatusBM int = 7, -- 1=Open, 2=Investigating, 4=Ignored, 8=Solved

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000382,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
DECLARE @CheckSumValue int, @CheckSumStatus10 int, @CheckSumStatus20 int, @CheckSumStatus30 int, @CheckSumStatus40 int
EXEC [spCheckSum_Member_Missing_Hierarchy] @UserID=-10, @InstanceID=476, @VersionID=1029, @Debug=0,
@CheckSumValue=@CheckSumValue OUT, @CheckSumStatus10=@CheckSumStatus10 OUT, @CheckSumStatus20 =@CheckSumStatus20 OUT,
@CheckSumStatus30=@CheckSumStatus30 OUT, @CheckSumStatus40=@CheckSumStatus40 OUT
SELECT [@CheckSumValue] = @CheckSumValue, [@CheckSumStatus10] = @CheckSumStatus10, [@CheckSumStatus20] = @CheckSumStatus20, 
[@CheckSumStatus30] = @CheckSumStatus30, [@CheckSumStatus40] = @CheckSumStatus40

DECLARE @CheckSumValue int
EXEC [spCheckSum_Member_Missing_Hierarchy] @UserID=-10, @InstanceID = 476, @VersionID = 1029, @CheckSumValue = @CheckSumValue OUT, @Debug=1,@JobID = 10406
SELECT CheckSumValue = @CheckSumValue

EXEC [spCheckSum_Member_Missing_Hierarchy]  @UserID = -10, @InstanceID = 476, @VersionID = 1029, @ResultTypeBM = 4

EXEC [spCheckSum_Member_Missing_Hierarchy] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM = 2
EXEC [spCheckSum_Member_Missing_Hierarchy] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumStatusBM = 8

EXEC [spCheckSum_Member_Missing_Hierarchy] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@CalledYN bit = 1,
	@StorageTypeBM int,
	@LeafLevelFilter nvarchar(MAX),

	@Table nvarchar(100),
	@object_id bigint,
	@Dimension nvarchar(100),
	@Hierarchy nvarchar(100),
	@HierarchyTable nvarchar(100),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = 'Now only support Callisto storage',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get CheckSum for existing members not in hierarchy',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-106: Implemented CheckSumRowLogID.'
		IF @Version = '2.1.1.2171' SET @Description = 'Exclude Callisto FACT tables not existing in DataClass. Only inlcude DimensionHierarchies with HierarchyNo = 0. Retrieve latest [CheckSumRowLog].[CheckSumRowLogID] to update [wrk_CheckSum_Member_Missing_Hierarchy].[CheckSumRowLogID].'
		IF @Version = '2.1.1.2172' SET @Description = 'Added parameters @CheckSumStatus10, @CheckSumStatus20, @CheckSumStatus30, @CheckSumStatus40, @CheckSumStatusBM.'
		IF @Version = '2.1.1.2174' SET @Description = 'Added [CheckSumStatusBM] in @ResultTypeBM = 4.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@ETLDatabase = ETLDatabase,
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT 
			@StorageTypeBM = [StorageTypeBM]
		FROM
			[Dimension_StorageType]
  		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DimensionID] = -1

		--IF OBJECT_ID(N'TempDB.dbo.#CheckSumValue', N'U') IS NULL
		--	SET @CalledYN = 0

	SET @Step = 'Check StorageType'
		IF @StorageTypeBM & 4 > 0
			GOTO ResultTypeBM1
		ELSE
			BEGIN
				SET @Message = 'This Checksum is only implemented for Callisto storage.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Get CheckSumValue'
		ResultTypeBM1:
		IF @ResultTypeBM & 1 = 0
			GOTO ResultTypeBM2

	SET @Step = 'Create table #FactMember'	
		CREATE TABLE #FactTable_Cursor
			(
			[Table] nvarchar(100),
			[object_id] bigint
            )

		SET @SQLStatement = '
			INSERT INTO #FactTable_Cursor
				(
				[Table],
				[object_id]
				)
			SELECT
				[Table] = t.[name],
				t.[object_id]
			FROM
				' + @CallistoDatabase + '.sys.tables t
				INNER JOIN pcINTEGRATOR_Data..DataClass D ON D.InstanceID = ' + convert(NVARCHAR(15), @InstanceID) + ' AND D.VersionID = ' + convert(NVARCHAR(15), @VersionID) + ' AND ''FACT_'' + D.DataClassName + ''_default_partition'' = t.[name] AND D.SelectYN <> 0 AND D.DeletedID IS NULL
			WHERE
				t.[name] LIKE ''FACT_%'' AND
				t.[name] NOT LIKE ''%_text'''

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

	SET @Step = 'Create table #RowCount'	
		CREATE TABLE #RowCount
			(
			[RowCount] BIGINT
			)
		
	SET @Step = 'Create table #FactTableDimension_Cursor'	
		CREATE TABLE #FactTableDimension_Cursor
			(
			[Dimension] nvarchar(100)
            )

	SET @Step = 'Create table #FactMember'	
		CREATE TABLE #FactMember
			(
			[Table] nvarchar(100),
			[Dimension] nvarchar(100),
			[MemberId] bigint
            )

	SET @Step = 'Create table #HierarchyMember'	
		CREATE TABLE #HierarchyMember 
			(
			MemberId bigint
			)

	SET @Step = 'Create table #Hierarchy_Cursor'	
		CREATE TABLE #Hierarchy_Cursor
			(
			[Dimension] nvarchar(100),
			[Hierarchy] nvarchar(100),
			[HierarchyTable] nvarchar(100)
			)

	SET @Step = 'FactTable Cursor'
		DECLARE FactTable_Cursor CURSOR FOR
			
			SELECT
				[Table],
				[object_id]
			FROM
				#FactTable_Cursor

			OPEN FactTable_Cursor
			FETCH NEXT FROM FactTable_Cursor INTO @Table, @object_id

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [Table] = @Table
					
					TRUNCATE TABLE #RowCount
					EXEC('INSERT INTO #RowCount ([RowCount]) SELECT [RowCount] = COUNT(1) FROM ' + @CallistoDatabase + '..' + @Table)
					IF @Debug <> 0 SELECT [RowCount] FROM #RowCount

					IF (SELECT [RowCount] FROM #RowCount) > 0
						BEGIN
							TRUNCATE TABLE #FactTableDimension_Cursor
							SET @SQLStatement = '
								INSERT INTO #FactTableDimension_Cursor
									(
									[Dimension]
									)
								SELECT 
									[Dimension] = [name]
								FROM
									' + @CallistoDatabase + '.sys.columns
								WHERE
									[object_id] = ' + CONVERT(NVARCHAR(20), @object_id) + ' AND
									[name] LIKE ''%_MemberId'''

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement) 
									
							DECLARE FactTableDimension_Cursor CURSOR FOR
			
								SELECT 
									[Dimension]
								FROM
									#FactTableDimension_Cursor

								OPEN FactTableDimension_Cursor
								FETCH NEXT FROM FactTableDimension_Cursor INTO @Dimension

								WHILE @@FETCH_STATUS = 0
									BEGIN
										IF @Debug <> 0 SELECT [Dimension] = @Dimension

										SET @SQLStatement = '
											INSERT INTO #FactMember
												(
												[Table],
												[Dimension],
												[MemberId]
												)
											SELECT DISTINCT
												[Table] = ''' + @Table + ''',
												[Dimension] = ''' + REPLACE(@Dimension, '_MemberId', '') + ''',
												[MemberId] = ' + @Dimension + '
											FROM
												' + @CallistoDatabase + '..' + @Table

										IF @Debug <> 0 PRINT @SQLStatement
										EXEC (@SQLStatement)


										FETCH NEXT FROM FactTableDimension_Cursor INTO @Dimension
									END

							CLOSE FactTableDimension_Cursor
							DEALLOCATE FactTableDimension_Cursor
						END

					FETCH NEXT FROM FactTable_Cursor INTO @Table, @object_id
				END

		CLOSE FactTable_Cursor
		DEALLOCATE FactTable_Cursor

		IF @Debug <> 0 SELECT TempTable = '#FactMember', * FROM #FactMember

	SET @Step = 'Delete table pcINTEGRATOR_Log..[wrk_CheckSum_Member_Missing_Hierarchy]'
		DELETE pcINTEGRATOR_Log..[wrk_CheckSum_Member_Missing_Hierarchy]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT

		IF @Debug <> 0 
			BEGIN
				SELECT [@Deleted] = @Deleted
				SELECT 
					[Table] = 'wrk_CheckSum_Member_Missing_Hierarchy', *  
				FROM 
					pcINTEGRATOR_Log..[wrk_CheckSum_Member_Missing_Hierarchy]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID
			END
		
	SET @Step = 'Hierarchy Cursor'
		SET @SQLStatement = '
			INSERT INTO #Hierarchy_Cursor
				(
				[Dimension],
				[Hierarchy],
				[HierarchyTable]
				)
			SELECT DISTINCT
				[Dimension] = REPLACE(T2.[name], ''S_DS_'', ''''),
				[Hierarchy] = REPLACE(T1.[name], ''S_HS_'' + REPLACE(T2.[name], ''S_DS_'', '''') + ''_'', ''''),
				[HierarchyTable] = T1.[name]
			FROM
				' + @CallistoDatabase + '.sys.tables T1
				INNER JOIN ' + @CallistoDatabase + '.sys.tables T2 ON T2.[name] LIKE ''S_DS_%'' AND CHARINDEX (''HS_'' + REPLACE(T2.[name], ''S_DS_'', '''') + ''_'', T1.[name], 3) > 0
				INNER JOIN [pcINTEGRATOR].[dbo].[DimensionHierarchy] DH ON DH.InstanceID IN (0, ' + CONVERT(nvarchar(15), @InstanceID) + ') AND DH.HierarchyNo = 0 AND DH.HierarchyName = REPLACE(T1.[name], ''S_HS_'' + REPLACE(T2.[name], ''S_DS_'', '''') + ''_'', '''')
			WHERE
				T1.[name] LIKE ''S_HS_%'''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		DECLARE Hierarchy_Cursor CURSOR FOR
			
			SELECT 
				[Dimension],
				[Hierarchy],
				[HierarchyTable]
			FROM
				#Hierarchy_Cursor
			ORDER BY
				[Dimension],
				[Hierarchy]

			OPEN Hierarchy_Cursor
			FETCH NEXT FROM Hierarchy_Cursor INTO @Dimension, @Hierarchy, @HierarchyTable

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT Dimension = @Dimension, Hierarchy = @Hierarchy, HierarchyTable = @HierarchyTable
					
					TRUNCATE TABLE #HierarchyMember

					SET @SQLStatement = '
						INSERT INTO #HierarchyMember
							(
							MemberId
							)
						SELECT DISTINCT
							MemberId 
						FROM
							' + @CallistoDatabase + '..' + @HierarchyTable + ' M
						WHERE
							NOT EXISTS (SELECT DISTINCT P.ParentMemberId FROM ' + @CallistoDatabase + '..' + @HierarchyTable + ' P WHERE P.ParentMemberId = M.MemberId)'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @Debug <> 0 SELECT TempTable = '#HierarchyMember', * FROM #HierarchyMember ORDER BY MemberId

					SET @SQLStatement = '
						INSERT INTO pcINTEGRATOR_Log..[wrk_CheckSum_Member_Missing_Hierarchy]
							(
							[InstanceID],
							[VersionID],
							[FactTable],
							[Dimension],
							[Hierarchy],
							[MemberId],
							[MemberKey],
							[MemberDescription]
							)
						SELECT DISTINCT
							[InstanceID] = ' + CONVERT(NVARCHAR(10), @InstanceID) + ',
							[VersionID] = ' + CONVERT(NVARCHAR(10), @VersionID) + ',
							[FactTable] = ''' + @CallistoDatabase + ''' + ''.dbo.'' + FM.[Table],
							[Dimension] = FM.[Dimension],
							[Hierarchy] = ''' + @Hierarchy + ''',
							[MemberId] = FM.[MemberId],
							[MemberKey] = ISNULL(D.Label, CONVERT(NVARCHAR(20), FM.[MemberId])),
							[MemberDescription] = ISNULL(D.[Description], CONVERT(NVARCHAR(20), FM.[MemberId]))
						FROM
							#FactMember FM
							INNER JOIN 
								(
								SELECT DISTINCT
									FM.[MemberId]
								FROM
									#FactMember FM
								WHERE
									Dimension = ''' + @Dimension + ''' AND
									NOT EXISTS (SELECT 1 FROM #HierarchyMember HM WHERE HM.[MemberId] = FM.[MemberId])
								) MM ON MM.MemberId = FM.MemberId
							LEFT JOIN ' + @CallistoDatabase + '..S_DS_' + @Dimension + ' D ON D.[MemberId] = FM.[MemberId]
						WHERE
							FM.Dimension = ''' + @Dimension + ''' AND
							NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Log..[wrk_CheckSum_Member_Missing_Hierarchy] MSH WHERE MSH.[InstanceID] = ' + CONVERT(NVARCHAR(10), @InstanceID) + ' AND MSH.[VersionID] = ' + CONVERT(NVARCHAR(10), @VersionID) + ' AND MSH.[FactTable] = ''' + @CallistoDatabase + ''' + ''.dbo.'' + FM.[Table] AND MSH.[Dimension] = FM.Dimension AND MSH.[Hierarchy] = ''' + @Hierarchy + ''' AND MSH.[MemberId] = FM.[MemberId])'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Inserted = @Inserted + @@ROWCOUNT
					
					FETCH NEXT FROM Hierarchy_Cursor INTO @Dimension, @Hierarchy, @HierarchyTable
				END

		CLOSE Hierarchy_Cursor
		DEALLOCATE Hierarchy_Cursor

	SET @Step = 'Set CheckSumRowLogID'
		INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
			(
			[CheckSumRowKey],
			[InstanceID],
			[VersionID],
			[ProcedureID]
			)
		SELECT
			[CheckSumRowKey] = CMMH.[FactTable] + '_' + CMMH.[Dimension] + '_'  + CMMH.[Hierarchy] + '_' + CONVERT(nvarchar(20), CMMH.[MemberId]),
			[InstanceID] = CMMH.[InstanceID],
			[VersionID] = CMMH.[VersionID],
			[ProcedureID] = @ProcedureID
		FROM
			[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_Member_Missing_Hierarchy] CMMH
		WHERE
			CMMH.[InstanceID] = @InstanceID AND
			CMMH.[VersionID] = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = CMMH.[FactTable] + '_' + CMMH.[Dimension] + '_'  + CMMH.[Hierarchy] + '_' + CONVERT(nvarchar(20), CMMH.[MemberId]) AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = CMMH.[InstanceID] AND CSRL.[VersionID] = CMMH.[VersionID] AND CSRL.[CheckSumStatusBM] & 8 = 0)

		UPDATE CMMH
		SET
			CheckSumRowLogID = CSRL.CheckSumRowLogID
		FROM
			[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_Member_Missing_Hierarchy] CMMH
			--INNER JOIN [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL ON CSRL.[CheckSumRowKey] = CMMH.[FactTable] + '_' + CMMH.[Dimension] + '_'  + CMMH.[Hierarchy] + '_' + CONVERT(nvarchar(20), CMMH.[MemberId]) AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = CMMH.[InstanceID] AND CSRL.[VersionID] = CMMH.[VersionID]
			INNER JOIN (
				SELECT TOP (1)
					C.InstanceID,
					C.VersionID,
					C.[CheckSumRowLogID],
					C.[CheckSumRowKey],
					C.[ProcedureID]
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] C
				ORDER BY 
					C.CheckSumRowLogID DESC
			) CSRL ON CSRL.[CheckSumRowKey] = CMMH.[FactTable] + '_' + CMMH.[Dimension] + '_'  + CMMH.[Hierarchy] + '_' + CONVERT(nvarchar(20), CMMH.[MemberId]) AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = CMMH.[InstanceID] AND CSRL.[VersionID] = CMMH.[VersionID]
        
		UPDATE CSRL
		SET
			--[Solved] = GetDate(),
			--[CheckSumStatusID] = 40,
			[CheckSumStatusBM] = 8,
			[UserID] = @UserID,
			[Comment] = 'Resolved automatically.',
			[Updated] = GetDate()
		FROM
			[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
		WHERE
			CSRL.[InstanceID] = @InstanceID AND
			CSRL.[VersionID] = @VersionID AND
			CSRL.[ProcedureID] = @ProcedureID AND
			--CSRL.[Solved] IS NULL AND
			--CSRL.[CheckSumStatusID] <> 40 AND
			CSRL.[CheckSumStatusBM] & 8 = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_Member_Missing_Hierarchy] CMMH WHERE CMMH.[InstanceID] = CSRL.[InstanceID] AND CMMH.[VersionID] = CSRL.[VersionID] AND CMMH.[CheckSumRowLogID] = CSRL.[CheckSumRowLogID])

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Drop Temp table'
		DROP TABLE #FactTable_Cursor
		DROP TABLE #FactTableDimension_Cursor
		DROP TABLE #FactMember
		DROP TABLE #RowCount
		DROP TABLE #HierarchyMember
		DROP TABLE #Hierarchy_Cursor

	ResultTypeBM2:		

	SET @Step = 'Set @CheckSumValue'
		IF @ResultTypeBM & 3 > 0
			BEGIN
				--SELECT
				--	@CheckSumValue = COUNT(1)
				--FROM
				--	[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_Member_Missing_Hierarchy]
				--WHERE
				--	[InstanceID] = @InstanceID AND
				--	[VersionID] = @VersionID

				SELECT
					@CheckSumValue = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 3 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus10 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 1 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus20 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 2 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus30 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 4 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus40 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 8 > 0 THEN 1 ELSE 0 END), 0)
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
					LEFT JOIN [pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_Member_Missing_Hierarchy] wrk ON wrk.CheckSumRowLogID = CSRL.CheckSumRowLogID
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND 
					CSRL.[ProcedureID] = @ProcedureID

				IF @Debug <> 0 
					SELECT 
						[@CheckSumValue] = @CheckSumValue, 
						[@CheckSumStatus10] = @CheckSumStatus10, 
						[@CheckSumStatus20] = @CheckSumStatus20,
						[@CheckSumStatus30] = @CheckSumStatus30,
						[@CheckSumStatus40] = @CheckSumStatus40
			END

	SET @Step = 'Get detailed info'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 4,
					[CheckSumRowLogID] = CSRL.[CheckSumRowLogID],
					[FirstOccurrence] = CSRL.[Inserted],
					[CheckSumStatusBM] = CSS.[CheckSumStatusBM],
					[CurrentStatus] = CSS.[CheckSumStatusName],
					[Comment] = CSRL.[Comment],
					[FactTable] = CMMH.[FactTable],
					[Dimension] = CMMH.[Dimension],
					[Hierarchy] = CMMH.[Hierarchy],
					[MemberId] = CMMH.[MemberId],
					[MemberKey] = CMMH.[MemberKey],
					[MemberDescription] = CMMH.[MemberDescription],
					[LastCheck] = CMMH.[Inserted],
					[AuthenticatedUserID] = CSRL.UserID,
					[AuthenticatedUserName] = U.UserNameDisplay,
					[AuthenticatedUserOrganization] = I.InstanceName,
					[Updated] = CSRL.[Updated]
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
					LEFT JOIN [pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_Member_Missing_Hierarchy] CMMH ON CMMH.CheckSumRowLogID = CSRL.CheckSumRowLogID
					INNER JOIN CheckSumStatus CSS ON CSS.CheckSumStatusBM = CSRL.CheckSumStatusBM
					LEFT JOIN [pcINTEGRATOR].[dbo].[User] U ON U.UserID = CSRL.UserID
					LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID 
				WHERE
					CSRL.InstanceID = @InstanceID AND
					CSRL.VersionID = @VersionID AND   
                    CSRL.ProcedureID = @ProcedureID AND 
					CSRL.CheckSumStatusBM & @CheckSumStatusBM > 0

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
