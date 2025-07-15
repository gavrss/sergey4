SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_SBZ]
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
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000375,
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
DECLARE @CheckSumValue int, @CheckSumStatus10 int, @CheckSumStatus20 int, @CheckSumStatus30 int, @CheckSumStatus40 int
EXEC [spCheckSum_SBZ] @UserID=-10, @InstanceID=533, @VersionID=1081, @Debug=1,
@CheckSumValue=@CheckSumValue OUT, @CheckSumStatus10=@CheckSumStatus10 OUT, @CheckSumStatus20 =@CheckSumStatus20 OUT,
@CheckSumStatus30=@CheckSumStatus30 OUT, @CheckSumStatus40=@CheckSumStatus40 OUT
SELECT [@CheckSumValue] = @CheckSumValue, [@CheckSumStatus10] = @CheckSumStatus10, [@CheckSumStatus20] = @CheckSumStatus20, 
[@CheckSumStatus30] = @CheckSumStatus30, [@CheckSumStatus40] = @CheckSumStatus40

DECLARE @CheckSumValue int
EXEC [spCheckSum_SBZ] @UserID=-10, @InstanceID=390, @VersionID=1011, @CheckSumValue = @CheckSumValue OUT--, @Debug=1
SELECT CheckSumValue = @CheckSumValue

EXEC [spCheckSum_SBZ] @UserID=-10, @InstanceID=413, @VersionID=1008, @ResultTypeBM = 1, @Debug=1
EXEC [spCheckSum_SBZ] @UserID=-10, @InstanceID=533, @VersionID=1058, @ResultTypeBM = 2, @Debug=1
EXEC [spCheckSum_SBZ] @UserID=-10, @InstanceID=413, @VersionID=1008, @ResultTypeBM = 3

EXEC [spCheckSum_SBZ] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumStatusBM = 8

EXEC [spCheckSum_SBZ] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@CalledYN bit = 1,

	@CallistoDatabase nvarchar(100),
	@Dimension nvarchar(100),
	@FACT_table nvarchar(150),
	@Model nvarchar(100),
	@EnhancedStorageYN bit,

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
	@Version nvarchar(50) = '2.1.2.2192'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Checks that all dimension members that have the SBZ property (Should Be Zero) set to true dont exists in any FACT tables.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-106: Implemented CheckSumRowLogID.'
		IF @Version = '2.1.1.2171' SET @Description = 'Exclude Callisto FACT backup tables. Exclude CheckSumStatusID=30 in CheckSumValue count.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added parameters @CheckSumStatus10, @CheckSumStatus20, @CheckSumStatus30, @CheckSumStatus40, @CheckSumStatusBM.'
		IF @Version = '2.1.1.2173' SET @Description = 'Removed filters for @Step = Insert into JobLog.'
		IF @Version = '2.1.1.2174' SET @Description = 'Added [CheckSumStatusBM] in @ResultTypeBM = 4.'
		IF @Version = '2.1.2.2189' SET @Description = 'EA-1649: Added parenthesis around DB table name. Upgraded to new tempalte SP. EA-1903: Modified query for INSERTing INTO #FACT_table_Cursor_Table.'
		IF @Version = '2.1.2.2192' SET @Description = 'Handled Enhanced Storage.'

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

		SELECT
			@ETLDatabase = ETLDatabase,
			@CallistoDatabase = DestinationDatabase,
			@EnhancedStorageYN = EnhancedStorageYN
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF OBJECT_ID(N'TempDB.dbo.#CheckSumValue', N'U') IS NULL
			SET @CalledYN = 0

	SET @Step = 'Get CheckSumValue'
		IF @ResultTypeBM & 1 > 0
			BEGIN

				SET @Step = 'Delete TABLE pcINTEGRATOR_Log..wrk_CheckSum_SBZ'
					DELETE pcINTEGRATOR_Log..wrk_CheckSum_SBZ
					WHERE
						InstanceID = @InstanceID AND
						VersionID = @VersionID

					SET @Deleted = @Deleted + @@ROWCOUNT

				SET @Step = 'Create temp tables'
					CREATE TABLE #Dimension_Cursor_Table
						(
						Dimension nvarchar(100) COLLATE DATABASE_DEFAULT
						)

					CREATE TABLE #SBZ_Member
						(
						Label nvarchar(255) COLLATE DATABASE_DEFAULT,
						MemberId bigint
						)

					CREATE TABLE #FACT_table_Cursor_Table
						(
						FACT_table nvarchar(255) COLLATE DATABASE_DEFAULT,
						Model nvarchar(100) COLLATE DATABASE_DEFAULT
						) 

				SET @Step = 'Fill #Dimension_Cursor_Table'
					IF @EnhancedStorageYN = 0
						BEGIN 
							SET @SQLStatement = '
								INSERT INTO #Dimension_Cursor_Table
									(
									Dimension
									) 
								SELECT
									Dimension = D.Label 
								FROM
									' + @CallistoDatabase + '..S_Dimensions D
									INNER JOIN ' + @CallistoDatabase + '.sys.tables T ON T.name = ''S_DS_'' + D.Label
									INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.name = ''SBZ'''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement

							EXEC (@SQLStatement)
						END
					ELSE 
						BEGIN 
							SET @SQLStatement = '
								INSERT INTO #Dimension_Cursor_Table
									(
									Dimension
									) 
								SELECT
									Dimension = D.DimensionName 
								FROM
									[pcINTEGRATOR].[dbo].[Dimension_StorageType] DS
									INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.InstanceID IN (0, DS.InstanceID) AND D.DimensionID = DS.DimensionID AND D.SelectYN <> 0 AND D.DeletedID IS NULL 
									INNER JOIN ' + @CallistoDatabase + '.sys.tables T ON T.name = ''S_DS_'' + D.DimensionName
									INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.name = ''SBZ''
								WHERE
									DS.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND 
									DS.VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ' AND 
									DS.StorageTypeBM & 4 > 0'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

				SET @Step = 'DECLARE SBZ_Dimension_Cursor'
					DECLARE SBZ_Dimension_Cursor CURSOR FOR

						SELECT Dimension FROM #Dimension_Cursor_Table ORDER BY Dimension

						OPEN SBZ_Dimension_Cursor
						FETCH NEXT FROM SBZ_Dimension_Cursor INTO @Dimension

						WHILE @@FETCH_STATUS = 0
							BEGIN
								TRUNCATE TABLE #SBZ_Member

								SET @SQLStatement = 'INSERT INTO #SBZ_Member (Label, MemberId) SELECT Label, MemberId FROM ' + @CallistoDatabase + '..S_DS_' + @Dimension + ' WHERE SBZ = 1 OPTION (MAXDOP 1)'

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								IF @Debug <> 0 SELECT TempTable = '#SBZ_Member', Dimension = @Dimension, * FROM #SBZ_Member

								SET @Step = 'Fill #FACT_table_Cursor_Table'
									TRUNCATE TABLE #FACT_table_Cursor_Table

									/*
									SET @SQLStatement = '
										INSERT INTO #FACT_table_Cursor_Table
											(
											FACT_table,
											Model
											) 
										SELECT
											FACT_table = ''' + @CallistoDatabase + ''' + ''.dbo.['' + ' + 'T.[name]' + ' + '']'',
											Model = REPLACE(REPLACE(T.[name], ''_default_partition'', ''''), ''FACT_'', '''')
										FROM
											' + @CallistoDatabase + '.sys.tables T 
											INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.name = ''' + @Dimension + '_MemberId''
										WHERE
											T.[name] LIKE ''FACT_%'' AND
											T.[name] NOT LIKE ''%_text'' AND
											ISNUMERIC(RIGHT(T.[name], 8)) = 0'
									*/
									SET @SQLStatement = '
										INSERT INTO #FACT_table_Cursor_Table
											(
											FACT_table,
											Model
											)
										SELECT 
											FACT_table = ''' + @CallistoDatabase + ''' + ''.dbo.[FACT_'' + ' + 'D.DataClassName' + ' + ''_default_partition]'',
											Model = D.DataClassName
										FROM
											[pcINTEGRATOR_Data].[dbo].[DataClass] D
											INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD ON DCD.DataClassID = D.DataClassID AND DCD.DimensionID = -1 AND DCD.SelectYN <> 0
											INNER JOIN ' + @CallistoDatabase + '.sys.tables T ON T.[name] = ''FACT_'' + ' + 'D.DataClassName' + ' + ''_default_partition''
											INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.name = ''' + @Dimension + '_MemberId''
										WHERE
											D.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND
											D.VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ' AND
											D.SelectYN <> 0 AND
											D.DeletedID IS NULL AND
											D.StorageTypeBM & 4 > 0
										OPTION (MAXDOP 1)'

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

								SET @Step = 'DECLARE SBZ_FACT_table_Cursor'
									DECLARE SBZ_FACT_table_Cursor CURSOR FOR

									SELECT
										FACT_table,
										Model
									FROM
										#FACT_table_Cursor_Table
									ORDER BY
										FACT_table

									OPEN SBZ_FACT_table_Cursor
									FETCH NEXT FROM SBZ_FACT_table_Cursor INTO @FACT_table, @Model

									WHILE @@FETCH_STATUS = 0
										BEGIN

											IF @Debug <> 0 SELECT FACT_table = @FACT_table

											SET @SQLStatement = '
												INSERT INTO pcINTEGRATOR_Log..wrk_CheckSum_SBZ
													(
													InstanceID,
													VersionID,
													Dimension,
													Model,
													Label,
													MemberId,
													FACT_table,
													FirstLoad,
													LatestLoad,
													Occurrences
													)
												SELECT
													InstanceID = ' + CONVERT(NVARCHAR(10), @InstanceID) + ',
													VersionID = ' + CONVERT(NVARCHAR(10), @VersionID) + ',
													Dimension = ''' + @Dimension + ''',
													Model = ''' + @Model + ''',
													Label = SM.Label,
													MemberId = MAX(SM.MemberId),
													FACT_table = ''' + @FACT_table + ''',
													FirstLoad = MIN(F.ChangeDateTime),
													LatestLoad = MAX(F.ChangeDateTime),
													Occurrences = COUNT(1)
												FROM
													' + @FACT_table + ' F
													INNER JOIN #SBZ_Member SM ON SM.MemberId = F.' + @Dimension + '_MemberId
												GROUP BY
													SM.Label
												HAVING
													COUNT(1) > 0
												OPTION (MAXDOP 1)'

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
								
											FETCH NEXT FROM SBZ_FACT_table_Cursor INTO @FACT_table, @Model
										END

									CLOSE SBZ_FACT_table_Cursor
									DEALLOCATE SBZ_FACT_table_Cursor		

								FETCH NEXT FROM SBZ_Dimension_Cursor INTO @Dimension
							END

					CLOSE SBZ_Dimension_Cursor
					DEALLOCATE SBZ_Dimension_Cursor	

				SET @Step = 'Set CheckSumRowLogID'
					INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
						(
						[CheckSumRowKey],
						[InstanceID],
						[VersionID],
						[ProcedureID]
						)
					SELECT
						[CheckSumRowKey] = CSBZ.[Dimension] + '_' + CSBZ.[Model] + '_' + CONVERT(nvarchar(20), CSBZ.[MemberId]) + '_' + CSBZ.[FACT_table],
						[InstanceID] = CSBZ.[InstanceID],
						[VersionID] = CSBZ.[VersionID],
						[ProcedureID] = @ProcedureID
					FROM
						[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_SBZ] CSBZ
					WHERE
						CSBZ.[InstanceID] = @InstanceID AND
						CSBZ.[VersionID] = @VersionID AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = CSBZ.[Dimension] + '_' + CSBZ.[Model]+ '_' + CONVERT(nvarchar(20), CSBZ.[MemberId]) + '_' + CSBZ.[FACT_table] AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = CSBZ.[InstanceID] AND CSRL.[VersionID] = CSBZ.[VersionID] AND CSRL.[CheckSumStatusBM] & 8 = 0)
					OPTION (MAXDOP 1)

					UPDATE CSBZ
					SET
						CheckSumRowLogID = CSRL.CheckSumRowLogID
					FROM
						[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_SBZ] CSBZ
						INNER JOIN [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL ON CSRL.[CheckSumRowKey] = CSBZ.[Dimension] + '_' + CSBZ.[Model] + '_' + CONVERT(nvarchar(20), CSBZ.[MemberId]) + '_' + CSBZ.[FACT_table] AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = CSBZ.[InstanceID] AND CSRL.[VersionID] = CSBZ.[VersionID]

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
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_SBZ] CSBZ WHERE CSBZ.[InstanceID] = CSRL.[InstanceID] AND CSBZ.[VersionID] = CSRL.[VersionID] AND CSBZ.[CheckSumRowLogID] = CSRL.[CheckSumRowLogID])
					OPTION (MAXDOP 1)

					SET @Updated = @Updated + @@ROWCOUNT
		
				SET @Step = 'Drop temp tables'
					DROP TABLE #Dimension_Cursor_Table
					DROP TABLE #SBZ_Member
					DROP TABLE #FACT_table_Cursor_Table

			END

	SET @Step = 'Set @CheckSumValue'
		IF @ResultTypeBM & 3 > 0
			BEGIN
					--SELECT
					--	@CheckSumValue = COUNT(1)
					--FROM
					--	pcINTEGRATOR_Log..wrk_CheckSum_SBZ wrk
					--	INNER JOIN [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL ON CSRL.InstanceID = wrk.InstanceID AND CSRL.VersionID = wrk.VersionID AND CSRL.CheckSumRowLogID = wrk.CheckSumRowLogID AND CSRL.CheckSumStatusID NOT IN (30)
					--WHERE
					--	wrk.InstanceID = @InstanceID AND
					--	wrk.VersionID = @VersionID

					SELECT
						@CheckSumValue = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 3 > 0 THEN 1 ELSE 0 END), 0),
						@CheckSumStatus10 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 1 > 0 THEN 1 ELSE 0 END), 0),
						@CheckSumStatus20 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 2 > 0 THEN 1 ELSE 0 END), 0),
						@CheckSumStatus30 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 4 > 0 THEN 1 ELSE 0 END), 0),
						@CheckSumStatus40 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 8 > 0 THEN 1 ELSE 0 END), 0)
					FROM
						[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
						LEFT JOIN [pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_SBZ] wrk ON wrk.CheckSumRowLogID = CSRL.CheckSumRowLogID
					WHERE
						CSRL.[InstanceID] = @InstanceID AND
						CSRL.[VersionID] = @VersionID AND 
						CSRL.[ProcedureID] = @ProcedureID
					OPTION (MAXDOP 1)

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
					[Dimension],
					[Model],
					[Label],
					[MemberId],
					[FACT_table],
					[FirstLoad],
					[LatestLoad],
					[Occurrences],
					[LastCheck] = CSBZ.[Inserted],
					[AuthenticatedUserID] = CSRL.UserID,
					[AuthenticatedUserName] = U.UserNameDisplay,
					[AuthenticatedUserOrganization] = I.InstanceName,
					[Updated] = CSRL.[Updated]
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
					LEFT JOIN [pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_SBZ] CSBZ ON CSBZ.CheckSumRowLogID = CSRL.CheckSumRowLogID
					INNER JOIN CheckSumStatus CSS ON CSS.CheckSumStatusBM = CSRL.CheckSumStatusBM
					LEFT JOIN [pcINTEGRATOR].[dbo].[User] U ON U.UserID = CSRL.UserID
					LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID 
				WHERE
					CSRL.InstanceID = @InstanceID AND
					CSRL.VersionID = @VersionID AND   
                    CSRL.ProcedureID = @ProcedureID AND 
					CSRL.CheckSumStatusBM & @CheckSumStatusBM > 0
				OPTION (MAXDOP 1)
		
				SET @Selected = @Selected + @@ROWCOUNT
			END

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
