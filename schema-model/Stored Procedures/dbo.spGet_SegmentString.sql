SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_SegmentString]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SegmentString nvarchar(max) = NULL OUT,
	@SegmentJoin nvarchar(max) = NULL OUT,
	@SegmentGroupBy nvarchar(max) = NULL OUT,
	@OutPut nvarchar(20) = 'FACT', --FACT, Journal

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000844,
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
EXEC [spGet_SegmentString] @UserID=-10, @InstanceID = 533, @VersionID = 1058, @OutPut = 'FACT', @DebugBM = 1  --SASAP
EXEC [spGet_SegmentString] @UserID=-10, @InstanceID = 533, @VersionID = 1058, @OutPut = 'Journal', @DebugBM = 1  --SASAP
EXEC [spGet_SegmentString] @UserID=-10, @InstanceID = 454, @VersionID = 1021, @OutPut = 'FACT', @DebugBM = 1  --CCM
EXEC [spGet_SegmentString] @UserID=-10, @InstanceID = 454, @VersionID = 1021, @OutPut = 'Journal', @DebugBM = 1  --CCM
EXEC [spGet_SegmentString] @UserID=-10, @InstanceID = 531, @VersionID = 1057, @OutPut = 'FACT', @DebugBM = 1  --PCX
EXEC [spGet_SegmentString] @UserID=-10, @InstanceID = 531, @VersionID = 1057, @OutPut = 'Journal', @DebugBM = 1  --PCX
EXEC [spGet_SegmentString] @UserID=-10, @InstanceID = 576, @VersionID = 1082, @OutPut = 'Journal', @DebugBM = 1  --AXYZ

EXEC [spGet_SegmentString] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DimensionID int,
	@DimensionName nvarchar(50),
	@SegmentNo int,
	@SegmentName nvarchar(50),
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),

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
	@Version nvarchar(50) = '2.1.2.2187'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get SQL-string for conversion between Journal and DC Financials',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2187' SET @Description = 'Procedure created.'

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
			@CallistoDatabase = A.DestinationDatabase
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SET @SegmentString = ''

	SET @Step = 'Create temp tables'
		CREATE TABLE #EntityCount
			(
			SegmentNo int,
			DimensionID int,
			DimensionName nvarchar(50),
			NoOfEntity int,
			LastYN bit DEFAULT(0)
			)

		SELECT DISTINCT
			E.EntityID,
			Entity = E.MemberKey
		INTO
			#Entity
		FROM
			pcINTEGRATOR_Data..Entity E
			INNER JOIN pcINTEGRATOR_Data..Journal_SegmentNo JSN ON JSN.InstanceID = E.InstanceID AND JSN.VersionID = E.VersionID AND JSN.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.EntityTypeID = -1 AND
			E.SelectYN <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Entity', * FROM #Entity ORDER BY Entity

		SELECT
			Entity_MemberId = CONVERT(bigint, 0),
			E.Entity,
			JSN.Book,
			JSN.DimensionID,
			JSN.SegmentNo
		INTO
			#JSN
		FROM
			pcINTEGRATOR_Data..Journal_SegmentNo JSN
			INNER JOIN #Entity E ON E.EntityID = JSN.EntityID
		WHERE
			JSN.SelectYN <> 0

		SET @SQLStatement = '
			UPDATE JSN
			SET 
				Entity_MemberId = E.MemberId
			FROM
				#JSN JSN
				INNER JOIN ' + @CallistoDatabase + '..S_DS_Entity E ON E.Company = JSN.Entity AND E.Book = JSN.Book'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#JSN', * FROM #JSN ORDER BY Entity

		IF @OutPut = 'FACT'
			BEGIN
				SET @Step = 'FACT_Cursor'

				IF CURSOR_STATUS('global','FACT_Cursor') >= -1 DEALLOCATE FACT_Cursor
				DECLARE FACT_Cursor CURSOR FOR
			
					SELECT DISTINCT
						JSN.DimensionID,
						D.DimensionName
					FROM 
						pcINTEGRATOR_Data..Journal_SegmentNo JSN
						INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionID = JSN.DimensionID
					WHERE
						JSN.InstanceID = @InstanceID AND
						JSN.VersionID = @VersionID AND
						JSN.DimensionID <> -1 AND
						JSN.SelectYN <> 0
					ORDER BY
						D.DimensionName

					OPEN FACT_Cursor
					FETCH NEXT FROM FACT_Cursor INTO @DimensionID, @DimensionName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName

							TRUNCATE TABLE #EntityCount

							INSERT INTO #EntityCount
								(
								SegmentNo,
								NoOfEntity
								)
							SELECT
								SegmentNo = JSN.SegmentNo,
								NoOfEntity = COUNT(1)
							FROM
								pcINTEGRATOR_Data..Journal_SegmentNo JSN
							WHERE
								JSN.InstanceID = @InstanceID AND
								JSN.VersionID = @VersionID AND
								JSN.DimensionID = @DimensionID AND
								JSN.SelectYN <> 0
							GROUP BY
								SegmentNo

							UPDATE EC
							SET
								LastYN = 1
							FROM
								#EntityCount EC
								INNER JOIN (SELECT TOP 1 SegmentNo FROM #EntityCount ORDER BY NoOfEntity DESC) sub ON sub.SegmentNo = EC.SegmentNo

							IF @DebugBM & 2 > 0 SELECT TempTable = '#EntityCount', * FROM #EntityCount ORDER BY LastYN, NoOfEntity

							IF (SELECT COUNT(1) FROM #EntityCount) = 1
								BEGIN
									SELECT @SegmentString = @SegmentString + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '] = ISNULL(J.[Segment' + CASE WHEN EC.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), EC.SegmentNo) + '], ''''),'
									FROM
										#EntityCount EC
									WHERE
										EC.LastYN <> 0
								END
							ELSE
								BEGIN
									SELECT @SegmentString = @SegmentString + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '] = ISNULL(CASE J.[Entity]' + ' + ''_'' + ' + 'J.[Book]'
							
									SELECT @SegmentString = @SegmentString + ' WHEN ''' + JSN.Entity + '_' + JSN.Book + ''' THEN J.[Segment' + CASE WHEN EC.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), EC.SegmentNo) + ']'
									FROM
										#EntityCount EC
										INNER JOIN #JSN JSN ON JSN.DimensionID = @DimensionID AND JSN.SegmentNo = EC.SegmentNo
									WHERE
										EC.LastYN = 0

									SELECT @SegmentString = @SegmentString + ' ELSE J.[Segment' + CASE WHEN EC.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), EC.SegmentNo) + '] END, ''''),'
									FROM
										#EntityCount EC
									WHERE
										EC.LastYN <> 0
								END

							FETCH NEXT FROM FACT_Cursor INTO @DimensionID, @DimensionName
						END

				CLOSE FACT_Cursor
				DEALLOCATE FACT_Cursor
			END

		ELSE IF @OutPut = 'Journal'
			BEGIN
				SET @Step = 'Journal_Cursor'
				
				IF CURSOR_STATUS('global','Journal_Cursor') >= -1 DEALLOCATE Journal_Cursor
				DECLARE Journal_Cursor CURSOR FOR
			
					SELECT 
						SegmentNo = sub.SegmentNo,
						SegmentName = 'Segment' + CASE WHEN sub.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), sub.SegmentNo)
					FROM
						(SELECT SegmentNo = 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10
						UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20) sub
					ORDER BY
						sub.SegmentNo

					OPEN Journal_Cursor
					FETCH NEXT FROM Journal_Cursor INTO @SegmentNo, @SegmentName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@SegmentNo] = @SegmentNo, [@SegmentName] = @SegmentName

							TRUNCATE TABLE #EntityCount

							INSERT INTO #EntityCount
								(
								DimensionID,
								DimensionName,
								NoOfEntity
								)
							SELECT
								DimensionID = JSN.DimensionID,
								DimensionName = MAX(D.DimensionName),
								NoOfEntity = COUNT(1)
							FROM
								pcINTEGRATOR_Data..Journal_SegmentNo JSN
								LEFT JOIN pcINTEGRATOR..Dimension D ON D.DimensionID = JSN.DimensionID 
							WHERE
								JSN.InstanceID = @InstanceID AND
								JSN.VersionID = @VersionID AND
								JSN.SegmentNo = @SegmentNo AND
								JSN.SelectYN <> 0
							GROUP BY
								JSN.DimensionID

							UPDATE EC
							SET
								LastYN = 1
							FROM
								#EntityCount EC
								INNER JOIN (SELECT TOP 1 DimensionID FROM #EntityCount ORDER BY NoOfEntity DESC) sub ON sub.DimensionID = EC.DimensionID

							IF @DebugBM & 2 > 0 SELECT TempTable = '#EntityCount', * FROM #EntityCount ORDER BY LastYN, NoOfEntity

							IF (SELECT COUNT(1) FROM #EntityCount) = 0
								BEGIN
									SELECT @SegmentString = @SegmentString + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @SegmentName + '] = '''','
								END

							ELSE IF (SELECT COUNT(1) FROM #EntityCount) = 1
								BEGIN
									SELECT @SegmentString = @SegmentString + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @SegmentName + '] = [' + EC.DimensionName + '].[Label],'
									FROM
										#EntityCount EC
									WHERE
										EC.LastYN <> 0
								END

							ELSE
								BEGIN
									SELECT @SegmentString = @SegmentString + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + @SegmentName + '] = CASE DC.Entity_MemberId'
	
									SELECT @SegmentString = @SegmentString + ' WHEN ' + CONVERT(nvarchar(20), JSN.Entity_MemberId) + ' THEN [' + EC.DimensionName + '].[Label]'
									FROM
										#EntityCount EC
										INNER JOIN #JSN JSN ON JSN.DimensionID = EC.DimensionID AND JSN.SegmentNo = @SegmentNo
									WHERE
										EC.LastYN = 0

									SELECT @SegmentString = @SegmentString + ' ELSE [' + EC.DimensionName + '].[Label] END,'
									FROM
										#EntityCount EC
									WHERE
										EC.LastYN <> 0
								END

							FETCH NEXT FROM Journal_Cursor INTO @SegmentNo, @SegmentName
						END

				CLOSE Journal_Cursor
				DEALLOCATE Journal_Cursor

				--SELECT DISTINCT
				--	DimensionName
				--FROM
				--	#JSN JSN
				--	INNER JOIN pcINTEGRATOR_Data..Dimension D ON D.DimensionID = JSN.DimensionID

				SET @Step = 'Dimension_Cursor'

				SELECT @SegmentJoin = '', @SegmentGroupBy = ''
				
				IF CURSOR_STATUS('global','Journal_Cursor') >= -1 DEALLOCATE Journal_Cursor
				DECLARE Journal_Cursor CURSOR FOR
			
					SELECT DISTINCT
						D.[DimensionName]
					FROM
						#JSN JSN
						INNER JOIN pcINTEGRATOR_Data..Dimension D ON D.DimensionID = JSN.DimensionID
					ORDER BY
						D.[DimensionName]

					OPEN Journal_Cursor
					FETCH NEXT FROM Journal_Cursor INTO @DimensionName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName

							SELECT
								@SegmentJoin = @SegmentJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] ON [' + @DimensionName + '].[MemberId] = DC.[' + @DimensionName + '_MemberId]',
								@SegmentGroupBy = @SegmentGroupBy + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @DimensionName + '].[Label],'
							
							FETCH NEXT FROM Journal_Cursor INTO @DimensionName
						END

				CLOSE Journal_Cursor
				DEALLOCATE Journal_Cursor
			END

	SET @Step = 'Return result'
		IF @DebugBM & 1 > 0
			BEGIN
				SELECT [@SegmentString] = @SegmentString
				PRINT @SegmentString
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #EntityCount
		DROP TABLE #Entity
		DROP TABLE #JSN

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
