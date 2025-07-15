SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_CheckSum]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 3,	--1=JobID, 2=Log, 4=Detail, 8=List of Instances with CheckSum, 16=Historic values for a specific CheckSum, 32=CheckSumStatus
	@ShowAllYN bit = 1,
	@CheckSumID int = NULL,	--Mandatory for @ResultTypeBM=4 and 16
	@CheckSumStatusBM int = 7,	--Optional for @ResultTypeBM=4
	@GUIBehaviorBM int = 4,	--1=Ordinary user, 2=Advanced, 4=System

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000461,
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
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 8	--Show all Instances with summarized CheckSumStatus
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 8, @GUIBehaviorBM = 4
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 3
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 16, @CheckSumID = 1103
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumID = 1097
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumID = 1098
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumID = 1099
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumID = 1100
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumID = 1101
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumID = 1102
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumID = 1103, @CheckSumStatusBM = 8
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumID = 1104
EXEC [spPortalGet_CheckSum] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 32	--CheckSumStatus description

EXEC [spPortalGet_CheckSum] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@spCheckSum nvarchar(100),
	@SQLStatement nvarchar(MAX),
	@CSL_InstanceID int,
	@CSL_VersionID int,
	@CSL_JobID int,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2172'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get CheckSumLog for specified Job (default last CheckSum batch executed) and/or Details for specified CheckSum.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.1.2171' SET @Description = 'Set @JobID of last Inserted in [CheckSumLog].'
		IF @Version = '2.1.1.2172' SET @Description = 'Return count for all CheckSumStatusID. Added @ResultTypeBM 8 & 16. Added parameter @CheckSumStatusBM.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @JobID IS NULL 
			BEGIN 
				SELECT TOP(1)
					@JobID = ISNULL(@JobID, CSL.[JobID])
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumLog] CSL
				WHERE
					CSL.InstanceID = @InstanceID AND
					CSL.VersionID = @VersionID
				ORDER BY
					CSL.Inserted DESC
				OPTION (MAXDOP 1)

				IF @Debug <> 0 SELECT [@JobID] = @JobID
			END

	SET @Step = 'Get JobID'
		IF @ResultTypeBM & 17 > 0
			BEGIN
				CREATE TABLE #CheckSumHistory
					(
					InstanceID int,
					VersionID int,
					JobID int,
					EndTime datetime,
					SelectYN bit
					)

				INSERT INTO #CheckSumHistory
					(
					InstanceID,
					VersionID,
					JobID,
					EndTime,
					SelectYN
					)
				SELECT
					InstanceID = @InstanceID,
					VersionID = @VersionID,
					JobID,
					EndTime,
					SelectYN
				FROM
					(
					SELECT DISTINCT
						JobID = CSL.JobID,
						EndTime = MAX(ISNULL(J.EndTime, CSL.Inserted)),
						SelectYN = MAX(CASE WHEN CSL.JobID = @JobID THEN 1 ELSE 0 END)
					FROM
						[pcINTEGRATOR_Log].[dbo].[CheckSumLog] CSL
						LEFT JOIN [pcINTEGRATOR_Log].[dbo].[Job] J ON J.JobID = CSL.JobID AND J.EndTime IS NOT NULL
					WHERE
						CSL.InstanceID = @InstanceID AND
						CSL.VersionID = @VersionID
					GROUP BY
						CSL.JobID
					) sub
				ORDER BY
					EndTime DESC
				OPTION (MAXDOP 1)
			END

	SET @Step = 'Get JobID'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT ResultTypeBM=1, * FROM #CheckSumHistory ORDER BY EndTime DESC

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get CheckSumLog'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				CREATE TABLE #LastRecords
					(
					[JobID] int,
					[CheckSumID] int,
					[CheckSumLogID] bigint
					)
		
				INSERT INTO #LastRecords
					(
					[JobID],
					[CheckSumID],
					[CheckSumLogID]
					)
				SELECT
					[JobID] = MAX(CSL.JobID),
					[CheckSumID],
					[CheckSumLogID] = MAX(CSL.[CheckSumLogID])
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumLog] CSL
				WHERE
					CSL.[InstanceID] = @InstanceID AND
					CSL.[VersionID] = @VersionID AND
					CSL.[JobID] = @JobID AND
					(@ShowAllYN <> 0 OR CSL.[CheckSumValue] <> 0)
				GROUP BY
					[CheckSumID]
				OPTION (MAXDOP 1)

				IF @Debug <> 0 SELECT [TempTable] = '#LastRecords', * FROM #LastRecords

				SELECT 
					ResultTypeBM=2,
					CSL.[JobID],
					CSL.[CheckSumLogID],
					CSL.[CheckSumID],
					CS.[CheckSumName],
					[Description] = CS.[CheckSumDescription],
					[DescriptionColumns] = CS.[DescriptionColumns],
					[DescriptionMitigate] = CS.[DescriptionMitigate],
					CS.[ObjectGuiBehaviorBM],
					CSL.[CheckSumValue],
					[Open] = CSL.[CheckSumStatus10],
					[Investigating] = CSL.[CheckSumStatus20],
					[Ignored] = CSL.[CheckSumStatus30],
					[Closed] = CSL.[CheckSumStatus40],
					CSL.[Inserted],
					CS.[SortOrder]
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumLog] CSL
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[CheckSum] CS ON CS.CheckSumID = CSL.CheckSumID AND CS.SelectYN <> 0
					INNER JOIN #LastRecords LR ON LR.[CheckSumID] = CSL.[CheckSumID] AND LR.[CheckSumLogID] = CSL.[CheckSumLogID]
				WHERE
					CSL.[InstanceID] = @InstanceID AND
					CSL.[VersionID] = @VersionID AND
					CSL.[JobID] = @JobID AND
					(@ShowAllYN <> 0 OR CSL.[CheckSumValue] <> 0)
				ORDER BY
					CS.SortOrder
				OPTION (MAXDOP 1)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get CheckSum Detail'
		IF @ResultTypeBM & 4 > 0 AND @CheckSumID IS NOT NULL
			BEGIN
				SELECT
					@spCheckSum = CS.[spCheckSum]
				FROM
					[pcINTEGRATOR_Data].[dbo].[CheckSum] CS
				WHERE
					CS.InstanceID = @InstanceID AND
					CS.VersionID = @VersionID AND
					CS.[CheckSumID] = @CheckSumID AND
					CS.SelectYN <> 0

				IF @Debug <> 0 SELECT spCheckSum = @spCheckSum

				SET @SQLStatement = '
					EXEC ' + @spCheckSum + ' @UserID = ' + CONVERT(NVARCHAR(15), @UserID) + ', @InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ', @VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ', @ResultTypeBM = ' + CONVERT(NVARCHAR(15), @ResultTypeBM) + ', @CheckSumStatusBM = ' + CONVERT(NVARCHAR(15), @CheckSumStatusBM)

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Get List of Instances with valid CheckSum and latest JobID'
		IF @ResultTypeBM & 24 > 0
			BEGIN
				CREATE TABLE #InstancesWithCheckSum
				(
					InstanceID int,
					VersionID int,
					JobID int
				)

				INSERT INTO #InstancesWithCheckSum 
					(InstanceID, VersionID) 
				SELECT DISTINCT 
					InstanceID, VersionID 
				FROM 
					[pcINTEGRATOR_Log].[dbo].[CheckSumLog]

				DECLARE InstancesWithCheckSum_Cursor CURSOR FOR
					SELECT 
						InstanceID,
						VersionID
					FROM 
						#InstancesWithCheckSum
					ORDER BY 
						InstanceID

					OPEN InstancesWithCheckSum_Cursor
					FETCH NEXT FROM InstancesWithCheckSum_Cursor INTO @CSL_InstanceID, @CSL_VersionID

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @Debug <> 0 SELECT [@CSL_InstanceID] = @CSL_InstanceID, [@CSL_VersionID] = @CSL_VersionID

							SELECT TOP(1) @CSL_JobID = [JobID]
							FROM
								[pcINTEGRATOR_Log].[dbo].[CheckSumLog]
							WHERE
								InstanceID = @CSL_InstanceID AND
								VersionID = @CSL_VersionID
							ORDER BY
								Inserted DESC
							OPTION (MAXDOP 1)

							UPDATE C
							SET JobID = @CSL_JobID
							FROM 
								#InstancesWithCheckSum  C
							WHERE 
								C.InstanceID = @CSL_InstanceID AND 
								C.VersionID = @CSL_VersionID

							FETCH NEXT FROM InstancesWithCheckSum_Cursor INTO @CSL_InstanceID, @CSL_VersionID
						END

				CLOSE InstancesWithCheckSum_Cursor
				DEALLOCATE InstancesWithCheckSum_Cursor

				IF @Debug <> 0 SELECT [TempTable] = '#InstancesWithCheckSum', * FROM #InstancesWithCheckSum ORDER BY InstanceID 

			END

	SET @Step = 'Get List of Instances with valid checksum'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 8,
					CSL.[InstanceID],
					CSL.[VersionID],
					CSL.[JobID],
					[Open] = SUM(CSL.[CheckSumStatus10]),
					[Investigating] = SUM(CSL.[CheckSumStatus20]),
					[Ignored] = SUM(CSL.[CheckSumStatus30]),
					[Solved] = SUM(CSL.[CheckSumStatus40])
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumLog] CSL
					INNER JOIN #InstancesWithCheckSum I ON I.InstanceID = CSL.InstanceID AND I.VersionID = CSL.VersionID AND I.JobID = CSL.JobID
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[CheckSum] C ON C.CheckSumID = CSL.CheckSumID AND C.ObjectGuiBehaviorBM & @GUIBehaviorBM > 0 AND C.SelectYN <> 0
				GROUP BY 
					CSL.[InstanceID],
					CSL.[VersionID],
					CSL.[JobID]
				ORDER BY
					CSL.[InstanceID],
					CSL.[VersionID]
				OPTION (MAXDOP 1)

				SET @Selected = @Selected + @@ROWCOUNT
				
			END

	SET @Step = 'Get historic values for a specific CheckSum'
		IF @ResultTypeBM & 16 > 0 AND @CheckSumID IS NOT NULL
			BEGIN
				SELECT 
					ResultTypeBM = 16,
					[InstanceID] = MAX(CSL.[InstanceID]),
					[VersionID] = MAX(CSL.[VersionID]),
					[JobID] = C.[JobID],
					[CheckSumID] = MAX(CSL.[CheckSumID]),
					[CheckSumName] = MAX(CS.[CheckSumName]),
					--CS.[CheckSumDescription],
					[CheckSumValue] = MAX(CSL.[CheckSumValue]),
					[Open] = MAX(CSL.[CheckSumStatus10]),
					[Investigating] = MAX(CSL.[CheckSumStatus20]),
					[Ignored] = MAX(CSL.[CheckSumStatus30]),
					[Solved] = MAX(CSL.[CheckSumStatus40]),
					[Inserted] = MAX(CSL.[Inserted])
				FROM
					#CheckSumHistory C
					INNER JOIN [pcINTEGRATOR_Log].[dbo].[CheckSumLog] CSL ON CSL.InstanceID = C.InstanceID AND CSL.VersionID = C.VersionID AND CSL.JobID = C.JobID AND CSL.CheckSumID = @CheckSumID
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[CheckSum] CS ON CS.CheckSumID = CSL.CheckSumID AND CS.SelectYN <> 0
				WHERE
					C.InstanceID = @InstanceID AND
                    C.VersionID = @VersionID 
				GROUP BY
					C.JobID
				ORDER BY 
					MAX(CSL.[Inserted]) DESC
				OPTION (MAXDOP 1)
			END

	SET @Step = 'Get CheckSumStatus'
		IF @ResultTypeBM & 32 > 0
			SELECT
				ResultTypeBM=32,
				[CheckSumStatusID],
				[CheckSumStatusName],
				[CheckSumStatusDescription],
				[CheckSumStatusBM]
			FROM
				[pcINTEGRATOR].[dbo].[CheckSumStatus]
			ORDER BY
				[CheckSumStatusID]
			OPTION (MAXDOP 1)

	SET @Step = 'Drop temp tables'
		IF @ResultTypeBM & 17 > 0 DROP TABLE #CheckSumHistory
		IF @ResultTypeBM & 2 > 0 DROP TABLE #LastRecords
		IF @ResultTypeBM & 24 > 0 DROP TABLE #InstancesWithCheckSum

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
