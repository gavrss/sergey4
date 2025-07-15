SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_WorkflowState_Reset]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@WorkflowID int = NULL, --Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000396,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_WorkflowState_Reset',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminSet_WorkflowState_Reset] @UserID=-10, @InstanceID=413, @VersionID=1008, @WorkflowID=2174, @Debug=1

EXEC [spPortalAdminSet_WorkflowState_Reset] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ProcessID int,
	@ScenarioID int,
	@TimeFrom int,
	@TimeTo int,
	@Scenario_MemberKey nvarchar(100),
	@Scenario_MemberId bigint,
	@InputAllowedYN bit,
	@ClosedMonth int,
	@DataClassID int,
	@DataClassName nvarchar(50),
	@StorageTypeBM int,
	@InitialWorkFlowStateID int,
	@RefreshActualsInitialWorkflowStateID int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@TimeDayYN bit,

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2164'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Reset WorkflowState to initial values for the specified Workflow',
			@MandatoryParameter = 'WorkflowID' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2164' SET @Description = 'Test on deleted and not selected Process, Assignment and DataClass when selecting affected DataClasses.'

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
			@CallistoDatabase = A.DestinationDatabase,
			@ETLDatabase = A.ETLDatabase
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		SELECT 
			@ProcessID = ProcessID,
			@ScenarioID = ScenarioID,
			@TimeFrom = TimeFrom,
			@TimeTo = TimeTo,
			@InitialWorkFlowStateID = InitialWorkflowStateID,
			@RefreshActualsInitialWorkflowStateID = RefreshActualsInitialWorkflowStateID
		FROM 
			dbo.Workflow
		WHERE
			WorkflowID = @WorkflowID AND
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT
			@Scenario_MemberKey = MemberKey,
			@InputAllowedYN = InputAllowedYN,
			@ClosedMonth = ClosedMonth
		FROM
			dbo.Scenario
		WHERE
			ScenarioID = @ScenarioID AND
			InstanceID = @InstanceID AND
			VersionID = @VersionID

	SET @Step = 'SP-Specific check'
		IF @InputAllowedYN = 0
			BEGIN
				SET @Message = 'The Scenario for selected Workflow does not allow input.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp table #FACT_Table_Column'
		CREATE TABLE #FACT_Table_Column
			(
			ColumnName nvarchar(50)
			)

	SET @Step = 'Create temp table #Scenario_MemberId'
		CREATE TABLE #Scenario_MemberId
			(
			Scenario_MemberId bigint
			)

	SET @Step = 'Create temp table #DataClass_List'
		CREATE TABLE #DataClass_List
			(
			DataClassID int,
			DataClassName nvarchar(50),
			StorageTypeBM int,
			)

		INSERT INTO #DataClass_List
			(
			DataClassID,
			DataClassName,
			StorageTypeBM
			)
		SELECT DISTINCT
			DataClassID = A.DataClassID,
			DataClassName = DC.DataClassName,
			StorageTypeBM = DC.StorageTypeBM
		FROM
			dbo.Assignment A
			INNER JOIN dbo.DataClass DC ON DC.InstanceID = A.InstanceID AND DC.VersionID = A.VersionID AND DC.DataClassID = A.DataClassID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL
		WHERE
			A.WorkflowID = @WorkflowID AND
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0 AND
			A.DeletedID IS NULL
			
		INSERT INTO #DataClass_List
			(
			DataClassID,
			DataClassName,
			StorageTypeBM
			)
		SELECT DISTINCT
			DataClassID = DCP.DataClassID,
			DataClassName = DC.DataClassName,
			StorageTypeBM = DC.StorageTypeBM
		FROM
			dbo.DataClass_Process DCP
			INNER JOIN dbo.Process P ON P.InstanceID = DCP.InstanceID AND P.VersionID = DCP.VersionID AND P.ProcessID = DCP.ProcessID AND P.SelectYN <> 0
			INNER JOIN dbo.DataClass DC ON DC.InstanceID = DCP.InstanceID AND DC.VersionID = DCP.VersionID AND DC.DataClassID = DCP.DataClassID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL
		WHERE
			DCP.ProcessID = @ProcessID AND
			DCP.InstanceID = @InstanceID AND
			DCP.VersionID = @VersionID AND
			NOT EXISTS (SELECT 1 FROM #DataClass_List DCL WHERE DCL.DataClassID = DCP.DataClassID)

	SET @Step = 'Set @Scenario_MemberId'		
		IF (SELECT COUNT(1) FROM #DataClass_List WHERE StorageTypeBM & 4 > 0) > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #Scenario_MemberId
						(
						Scenario_MemberId
						)
					SELECT 
						Scenario_MemberId = MemberId
					FROM 
						' + @CallistoDatabase + '..S_DS_Scenario
					WHERE
						Label = ''' + @Scenario_MemberKey + ''''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				SELECT 
					@Scenario_MemberId = [Scenario_MemberId]
				FROM
					#Scenario_MemberId
			END

	SET @Step = 'WorkflowState_Reset_Cursor'
		DECLARE WorkflowState_Reset_Cursor CURSOR FOR
			
			SELECT 
				DataClassID,
				DataClassName,
				StorageTypeBM
			FROM 
				#DataClass_List
			ORDER BY
				DataClassID

			OPEN WorkflowState_Reset_Cursor
			FETCH NEXT FROM WorkflowState_Reset_Cursor INTO @DataClassID, @DataClassName, @StorageTypeBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT DataClassID = @DataClassID, DataClassName = @DataClassName, StorageTypeBM = @StorageTypeBM

					IF @StorageTypeBM & 2 > 0 
						BEGIN
							SET @Message = 'So far, only implemented for data stored in Callisto.'
							SET @Severity = 16
							GOTO EXITPOINT
						END

					ELSE IF @StorageTypeBM & 4 > 0 
						BEGIN						
							TRUNCATE TABLE #FACT_Table_Column

							SET @SQLStatement = '
								INSERT INTO #FACT_Table_Column
									(
									ColumnName
									)							
								SELECT 
									C.[name] 
								FROM 
									' + @CallistoDatabase + '.sys.tables T
									INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND
										C.[name] IN (''Scenario_MemberId'', ''Time_MemberId'', ''TimeDay_MemberId'', ''WorkflowState_MemberId'')
								WHERE 
									T.[name] = ''FACT_' + @DataClassName + '_default_partition'''

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC(@SQLStatement)

							IF @Debug <> 0 SELECT TempTable = '#FACT_Table_Column', * FROM #FACT_Table_Column

							IF (SELECT COUNT(1) FROM #FACT_Table_Column) = 3
								BEGIN
									SELECT @TimeDayYN = COUNT(1) FROM #FACT_Table_Column WHERE ColumnName = 'TimeDay_MemberId'

									IF @Debug <> 0
										SELECT
											[@ClosedMonth] = @ClosedMonth,
											[@RefreshActualsInitialWorkflowStateID] = @RefreshActualsInitialWorkflowStateID,
											[@InitialWorkFlowStateID] = @InitialWorkFlowStateID,
											[@CallistoDatabase] = @CallistoDatabase,
											[@DataClassName] = @DataClassName,
											[@Scenario_MemberId] = @Scenario_MemberId,
											[@TimeFrom] = @TimeFrom,
											[@TimeTo] = @TimeTo

									IF @TimeDayYN = 0 --Time Month Level
										SET @SQLStatement = '
											UPDATE F
											SET 
												WorkflowState_MemberId = CASE WHEN Time_MemberId <= ' + CONVERT(nvarchar(10), @ClosedMonth) + ' THEN ' + CONVERT(nvarchar(10), @RefreshActualsInitialWorkflowStateID) + ' ELSE ' + CONVERT(nvarchar(10), @InitialWorkFlowStateID) + ' END
											FROM
												' + @CallistoDatabase + '..FACT_' + @DataClassName + '_default_partition F
											WHERE
												Scenario_MemberId = ' + CONVERT(nvarchar(10), @Scenario_MemberId) + ' AND
												Time_MemberId BETWEEN ' + CONVERT(nvarchar(10), @TimeFrom) + ' AND ' + CONVERT(nvarchar(10), @TimeTo)
									
									ELSE --Time Day Level
										SET @SQLStatement = '
											UPDATE F
											SET 
												WorkflowState_MemberId = CASE WHEN TimeDay_MemberId <= ' + CONVERT(nvarchar(10), @ClosedMonth * 100 + 31) + ' THEN ' + CONVERT(nvarchar(10), @RefreshActualsInitialWorkflowStateID) + ' ELSE ' + CONVERT(nvarchar(10), @InitialWorkFlowStateID) + ' END
											FROM
												' + @CallistoDatabase + '..FACT_' + @DataClassName + '_default_partition F
											WHERE
												Scenario_MemberId = ' + CONVERT(nvarchar(10), @Scenario_MemberId) + ' AND
												TimeDay_MemberId BETWEEN ' + CONVERT(nvarchar(10), @TimeFrom * 100) + ' AND ' + CONVERT(nvarchar(10), @TimeTo * 100 + 31)

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC(@SQLStatement)

									SET @Updated = @Updated + @@ROWCOUNT
								END
						END

					FETCH NEXT FROM WorkflowState_Reset_Cursor INTO  @DataClassID, @DataClassName, @StorageTypeBM
				END

		CLOSE WorkflowState_Reset_Cursor
		DEALLOCATE WorkflowState_Reset_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE #FACT_Table_Column
		DROP TABLE #DataClass_List
		DROP TABLE #Scenario_MemberId

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
