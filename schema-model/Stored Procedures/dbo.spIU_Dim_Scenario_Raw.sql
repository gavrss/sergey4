SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Scenario_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBMStep int = 65535,
	@StaticMemberYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000650,
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
EXEC [spIU_Dim_Scenario_Raw] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @Debug = 1
EXEC [spIU_Dim_Scenario_Raw] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Debug = 1
EXEC [spIU_Dim_Scenario_Raw] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @Debug = 1

EXEC [spIU_Dim_Scenario_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@DimensionID int = -6, --Scenario
	@ApplicationID int,
	@JournalTable nvarchar(100),
	@SourceTypeBM int,

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
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of Scenarios from pcINTEGRATOR',
			@MandatoryParameter = 'SourceTypeID|SourceDatabase' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2153' SET @Description = 'Pass @JobID.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.0.2160' SET @Description = 'Changed default WorkflowStateID to -1.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2174' SET @Description = 'Filter on Scenario not NULL in Journal.'

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
			@ApplicationID = ApplicationID
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT
			@SourceTypeBM = SUM(SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				SourceTypeBM
			FROM
				SourceType ST
				INNER JOIN [Source] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.SourceTypeID = ST.SourceTypeID
			) sub

		SET @SourceTypeBM = ISNULL(@SourceTypeBM, 64) --SIE4

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable=@JournalTable OUT, @JobID=@JobID

		IF OBJECT_ID (N'tempdb..#Scenario_Members', N'U') IS NULL SET @CalledYN = 0

		IF @Debug <> 0 SELECT [@JournalTable] = @JournalTable, [@CalledYN] = @CalledYN, [@SourceTypeBM] = @SourceTypeBM

	SET @Step = 'Create temp table #Scenario_Members_Raw'
		CREATE TABLE [#Scenario_Members_Raw]
			(
			[MemberId] bigint,
			[MemberKey] nvarchar (100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar (512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar (1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[WorkflowStateID] int,
			[Source] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar (255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Insert scenarios from Journal' --Sources
		IF @SequenceBMStep & 1 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Scenario]
						(
						[InstanceID],
						[VersionID],
						[MemberKey],
						[ScenarioTypeID],
						[ScenarioName],
						[ScenarioDescription]
						)
					SELECT DISTINCT
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[MemberKey] = J.[Scenario],
						[ScenarioTypeID] = -7, --Copied from other system
						[ScenarioName] = J.[Scenario],
						[ScenarioDescription] = J.[Scenario]
					FROM
						' + @JournalTable + ' J 
					WHERE
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.Scenario is not null AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Scenario] D WHERE D.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND D.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND D.[MemberKey] = J.[Scenario])'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = '@SequenceCounter = 2, @SequenceBMStep = 2' --Journal sequences from Journal
		IF @SequenceBMStep & 2 > 0
			BEGIN
				INSERT INTO [#Scenario_Members_Raw]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Source],
					[Parent]
					)
				SELECT DISTINCT
					[MemberId] = M.[MemberID],
					[MemberKey] = S.[MemberKey],
					[Description] = S.[ScenarioDescription],
					[HelpText] = S.[ScenarioDescription],
					[NodeTypeBM] = 1,
					[Source] = 'Scenario',
					[Parent] = 'All_'
				FROM
					pcINTEGRATOR..Scenario S
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = -6 AND M.[Label] = S.MemberKey
				WHERE
					S.[InstanceID] = @InstanceID AND
					S.[VersionID] = @VersionID AND
					S.[SelectYN] <> 0 AND
					S.DeletedID IS NULL

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = 'Static Rows'
		IF @StaticMemberYN <> 0
			BEGIN
				INSERT INTO [#Scenario_Members_Raw]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Source],
					[Parent]
					)
				SELECT 
					[MemberId] = MAX([MemberId]),
					[MemberKey] = [Label],
					[Description] = MAX(REPLACE([Description], '@All_Dimension', 'All Scenarios')),
					[HelpText] = MAX([HelpText]),
					[NodeTypeBM] = MAX([NodeTypeBM]),
					[Source] = 'ETL',
					[Parent] = MAX([Parent])
				FROM 
					Member M
				WHERE
					DimensionID IN (0) AND
					[SourceTypeBM] & @SourceTypeBM > 0  AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Scenario] D WHERE D.[InstanceID] = @InstanceID AND D.[VersionID] = @VersionID AND D.[MemberKey] = M.[Label])
				GROUP BY
					[Label]

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = 'Get default WorkflowState'
		UPDATE SR
		SET
			WorkflowStateID = ISNULL(sub.WorkflowStateID, -1)
		FROM
			[#Scenario_Members_Raw] SR
			LEFT JOIN
			(
			SELECT
				MemberKey = S.MemberKey,
				WorkflowStateID = MAX(WF.InitialWorkflowStateID)
			FROM
				Workflow WF
				INNER JOIN Scenario S ON S.InstanceID = WF.InstanceID AND S.VersionID = WF.VersionID AND S.ScenarioID = WF.ScenarioID AND S.SelectYN <> 0 AND S.DeletedID IS NULL
			WHERE
				WF.InstanceID = @InstanceID AND
				WF.VersionID = @VersionID AND
				WF.SelectYN <> 0 AND
				WF.DeletedID IS NULL
			GROUP BY
				S.MemberKey
			) sub ON sub.MemberKey = SR.MemberKey

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Scenario_Members_Raw',
					*
				FROM
					#Scenario_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#Scenario_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[WorkflowState_MemberID],
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
					[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
					[WorkflowState_MemberID] = [MaxRaw].[WorkflowStateID],
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
						[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
						[WorkflowStateID] = MAX([Raw].[WorkflowStateID]),
						[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), [Raw].[MemberKey]),
						[Source] = MAX([Raw].[Source]),
						[Synchronized] = 1,
						[Parent] = MAX([Raw].[Parent])
					FROM
						[#Scenario_Members_Raw] [Raw]
					GROUP BY
						[Raw].[MemberKey]
					) [MaxRaw]
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = @DimensionID AND M.[Label] = [MaxRaw].[MemberKey]
				WHERE
					[MaxRaw].[MemberKey] IS NOT NULL
				ORDER BY
					CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Scenario_Members_Raw

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
