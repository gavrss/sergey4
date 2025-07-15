SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Job]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 15, --1 = Parameter List, 2 = Parameter members, 4 = JobList, 8 = JobStep
	@JobListID int = NULL, --If set, used as Filter on @ResultTypeBM = 8

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000593,
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
EXEC [spPortalAdminGet_Job] @UserID=-10, @InstanceID=52, @VersionID=1035, @Debug=1
EXEC [spPortalAdminGet_Job] @UserID=-10, @InstanceID=52, @VersionID=1035, @ResultTypeBM = 12, @JobListID = 2006, @Debug=1

EXEC [spPortalAdminGet_Job] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@JobStepTypeBM int = 255, --1=Setup, 2=ETL tables, 4=Dimensions, 8=FactTables, 16=BusinessRules, 32=Other, 64=SQL Agent jobs, 128=Checksums
	@JobFrequencyBM int = 7, --1=On demand, 2=Working days, 4=Weekend
	@JobStepGroupBM int = NULL, --Defined per InstanceID, Parameter
	@ProcessBM int = NULL, --Defined per InstanceID, Parameter NULL is ignored
--	@JobSetupStepBM int = NULL, --Parameter NULL is ignored
	@JobStep_List nvarchar(4000) = NULL, --Pipe separated list of JobStepID, Parameter NULL is ignored
	@Entity_List nvarchar(4000) = NULL, --Pipe separated list of Entities, Defined per InstanceID, Parameter NULL is ignored

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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return all Job related data',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Get filter variables'
		IF @ResultTypeBM & 8 > 0 AND @JobListID IS NOT NULL
			BEGIN
				SELECT
					@JobStepTypeBM = JobStepTypeBM,
					@JobFrequencyBM = JobFrequencyBM,
					@JobStepGroupBM = JobStepGroupBM,
					@ProcessBM = ProcessBM,
--					@JobSetupStepBM = JobSetupStepBM,
					@JobStep_List = JobStep_List,
					@Entity_List = Entity_List
				FROM
					[pcINTEGRATOR_Data].[dbo].[JobList]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[JobListID] = @JobListID

				IF @DebugBM & 2 > 0 SELECT [@JobID] = @JobID, [@JobListID] = @JobListID, [@JobStepTypeBM] = @JobStepTypeBM, [@JobFrequencyBM] = @JobFrequencyBM, [@JobStepGroupBM] = @JobStepGroupBM, [@ProcessBM] = @ProcessBM, [@JobStep_List] = @JobStep_List, [@Entity_List] = @Entity_List

				--Fill #JobStep_List
				SELECT [JobStepID] = CONVERT(int, LTRIM(RTRIM([Value]))) INTO #JobStep_List FROM STRING_SPLIT(@JobStep_List, '|')
				IF @DebugBM & 2 > 0 SELECT TempTable = '#JobStep_List', * FROM #JobStep_List ORDER BY [JobStepID]
			END

	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 1,
					ParameterName,
					ParameterDescription = ParameterName,
					DataType,
					ParameterType,
					KeyColumn,
					MandatoryYN
				FROM
					( 
					SELECT ParameterType = 'BitMap', ParameterName = 'JobStepTypeBM', DataType = 'int', KeyColumn = 'MemberBM', MandatoryYN = 1, SortOrder = 10
					UNION SELECT ParameterType = 'BitMap', ParameterName = 'JobFrequencyBM', DataType = 'int', KeyColumn = 'MemberBM', MandatoryYN = 1, SortOrder = 20
					UNION SELECT ParameterType = 'BitMap', ParameterName = 'JobStepGroupBM', DataType = 'int', KeyColumn = 'MemberBM', MandatoryYN = 1, SortOrder = 30
					UNION SELECT ParameterType = 'BitMap', ParameterName = 'ProcessBM', DataType = 'int', KeyColumn = 'MemberBM', MandatoryYN = 0, SortOrder = 40
--					UNION SELECT ParameterType = 'BitMap', ParameterName = 'JobSetupStepBM', DataType = 'int', KeyColumn = 'MemberBM', MandatoryYN = 0, SortOrder = 50
					UNION SELECT ParameterType = 'MultiSelect', ParameterName = 'JobStep_List', DataType = 'int', KeyColumn = 'MemberID', MandatoryYN = 0, SortOrder = 60
					UNION SELECT ParameterType = 'MultiSelect', ParameterName = 'Entity_List', DataType = 'int', KeyColumn = 'MemberID', MandatoryYN = 0, SortOrder = 70
					) sub
				ORDER BY
					SortOrder
			END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT ResultTypeBM = 2, ParameterName = 'JobStepTypeBM', MemberBM = JobStepTypeBM, [Name] = JobStepTypeName, [Description] = [JobStepTypeDescription] FROM JobStepType ORDER BY JobStepTypeBM
				SELECT ResultTypeBM = 2, ParameterName = 'JobFrequencyBM', MemberBM = JobFrequencyBM, [Name] = JobFrequencyName, [Description] = [JobFrequencyDescription] FROM JobFrequency ORDER BY JobFrequencyBM
				SELECT ResultTypeBM = 2, ParameterName = 'JobStepGroupBM', MemberBM = JobStepGroupBM, [Name] = JobStepGroupName, [Description] = JobStepGroupDescription FROM JobStepGroup WHERE [InstanceID] IN (0, @InstanceID) AND [VersionID] IN (0, @VersionID) ORDER BY JobStepGroupBM
				SELECT ResultTypeBM = 2, ParameterName = 'ProcessBM', MemberBM = ProcessBM, [Name] = ProcessName, [Description] = ProcessDescription FROM Process WHERE InstanceID = @InstanceID AND SelectYN <> 0 ORDER BY ProcessBM
--				SELECT ResultTypeBM = 2, ParameterName = 'JobSetupStepBM', MemberBM = JobSetupStepBM, [Name] = JobSetupStepName, [Description] = JobSetupStepName FROM JobSetupStep ORDER BY JobSetupStepBM
				SELECT ResultTypeBM = 2, ParameterName = 'JobStep_List', MemberID = [JobStepID], [Name] = [Comment], [Description] = [StoredProcedure] + ' ' + [Parameter] FROM JobStep WHERE InstanceID = @InstanceID AND SelectYN <> 0 ORDER BY [Comment]
				SELECT ResultTypeBM = 2, ParameterName = 'Entity_List', MemberID = [EntityID], [Name] = [MemberKey], [Description] = [EntityName] FROM pcINTEGRATOR_Data.dbo.Entity WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND SelectYN <> 0  ORDER BY [MemberKey]
			END

	SET @Step = '@ResultTypeBM & 4'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4, 
					[JobListID],
					[JobListName],
					[JobListDescription],
					[JobStepTypeBM],
					[JobFrequencyBM],
					[JobStepGroupBM],
					[ProcessBM],
--					[JobSetupStepBM],
					[JobStep_List],
					[Entity_List],
					[SelectYN]
				FROM
					JobList JL
				WHERE
					JL.[InstanceID] = @InstanceID AND
					JL.[VersionID] = @VersionID
			END

	SET @Step = '@ResultTypeBM & 8'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				IF @JobListID IS NULL
					SELECT
						ResultTypeBM = 8,
						Comment,
						JobStepID,
						JobStepTypeBM,
						[Database] = DatabaseName,
						[Procedure] = StoredProcedure,
						[Parameter],
						JobFrequencyBM,
						JobStepGroupBM,
						ProcessBM,
						SortOrder,
						SelectYN
					FROM
						JobStep JS
					WHERE
						JS.[InstanceID] = @InstanceID AND
						JS.[VersionID] = @VersionID
					ORDER BY
						JS.JobStepTypeBM,
						JS.SortOrder
				ELSE
					BEGIN
						SELECT
							Comment,
							JobStepID,
							JobStepTypeBM,
							[Database] = DatabaseName,
							[Procedure] = StoredProcedure,
							[Parameter],
							JobFrequencyBM,
							JobStepGroupBM,
							ProcessBM,
							SortOrder,
							SelectYN
						INTO
							#JobStep
						FROM
							[pcINTEGRATOR_Data].[dbo].[JobStep]
						WHERE
							[InstanceID] = @InstanceID AND
							[VersionID] = @VersionID AND
							[JobStepTypeBM] & @JobStepTypeBM > 0 AND
							[JobFrequencyBM] & @JobFrequencyBM > 0 AND
							[JobStepGroupBM] & @JobStepGroupBM > 0 AND
							([ProcessBM] & @ProcessBM > 0 OR @ProcessBM IS NULL) AND
							[SelectYN] <> 0

						IF (SELECT COUNT(1) FROM #JobStep_List) > 0
							DELETE JS
							FROM
								#JobStep JS
							WHERE
								NOT EXISTS (SELECT 1 FROM #JobStep_List JSL WHERE JSL.JobStepID = JS.JobStepID)

						SELECT
							ResultTypeBM = 8,
							JS.*
						FROM
							#JobStep JS
						ORDER BY
							JS.JobStepTypeBM,
							JS.SortOrder
					END
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
