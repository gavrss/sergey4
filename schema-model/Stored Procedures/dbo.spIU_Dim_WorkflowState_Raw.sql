SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_WorkflowState_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -63, --WorkflowState
	@SequenceBMStep int = 65535,
	@StaticMemberYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000680,
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
EXEC [spIU_Dim_WorkflowState_Raw] @UserID = -10, @InstanceID = -1590, @VersionID = -1590, @Debug = 1

EXEC [spIU_Dim_WorkflowState_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2181'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of WorkflowStates from pcINTEGRATOR_Data',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.2.2181' SET @Description = 'Remove mandatory parameters. Use sub routine [spSet_Hierarchy].'

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

		IF OBJECT_ID (N'tempdb..#WorkflowState_Members', N'U') IS NULL SET @CalledYN = 0

		IF @Debug <> 0 SELECT [@CalledYN] = @CalledYN

	SET @Step = 'Create temp table #WorkflowState_Members_Raw'
		CREATE TABLE [#WorkflowState_Members_Raw]
			(
			[MemberId] int,
			[MemberKey] nvarchar (100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar (512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar (1024) COLLATE DATABASE_DEFAULT,
			[Scenario] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[SendTo_MemberId] int,
			[Source] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar (255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = '@SequenceCounter = 1, @SequenceBMStep = 1, '
		IF @SequenceBMStep & 1 > 0
			BEGIN
				INSERT INTO [#WorkflowState_Members_Raw]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[Scenario],
					[NodeTypeBM],
					[SendTo_MemberId],
					[Source],
					[Parent]
					)
				SELECT DISTINCT
					[MemberId] = 30000000 + W.WorkflowID,
					[MemberKey] = CONVERT(nvarchar(10), W.WorkflowID) + '_' + W.WorkflowName,
					[Description] = W.WorkflowName,
					[HelpText] = '',
					[Scenario] = S.MemberKey,
					[NodeTypeBM] = 2,
					[SendTo_MemberId] = W.InitialWorkflowStateID,
					[Source] = 'ETL',
					[Parent] = 'All_'
				FROM
					pcINTEGRATOR..[Workflow] W
					INNER JOIN pcINTEGRATOR..[Scenario] S ON S.ScenarioID = W.ScenarioID
				WHERE
					W.InstanceID = @InstanceID AND
					W.VersionID = @VersionID AND
					W.SelectYN <> 0

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = '@SequenceCounter = 2, @SequenceBMStep = 2, '
		IF @SequenceBMStep & 2 > 0
			BEGIN
				INSERT INTO [#WorkflowState_Members_Raw]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[Scenario],
					[NodeTypeBM],
					[SendTo_MemberId],
					[Source],
					[Parent]
					)
				SELECT DISTINCT
					[MemberId] = WS.WorkflowStateID,
					[MemberKey] = CONVERT(nvarchar(10), WS.WorkflowStateID) + '_' + WS.[WorkflowStateName],
					[Description] = WS.[WorkflowStateName],
					[HelpText] = '',
					[Scenario] = S.MemberKey,
					[NodeTypeBM] = 1,
					[SendTo_MemberId] = WS.WorkflowStateID,
					[Source] = 'ETL',
					[Parent] = CONVERT(nvarchar(10), W.WorkflowID) + '_' + W.WorkflowName
				FROM
					pcINTEGRATOR..[Workflow] W
					INNER JOIN pcINTEGRATOR..[Scenario] S ON S.ScenarioID = W.ScenarioID
					INNER JOIN [pcINTEGRATOR].[dbo].[WorkflowState] WS ON WS.WorkflowID = W.WorkflowID
				WHERE
					W.InstanceID = @InstanceID AND
					W.VersionID = @VersionID AND
					W.SelectYN <> 0

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = 'Static Rows'
		IF @StaticMemberYN <> 0
			BEGIN
				INSERT INTO [#WorkflowState_Members_Raw]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[Scenario],
					[NodeTypeBM],
					[SendTo_MemberId],
					[Source],
					[Parent]
					)
				SELECT 
					[MemberId] = MAX([MemberId]),
					[MemberKey] = [Label],
					[Description] = MAX(REPLACE([Description], '@All_Dimension', 'All WorkflowStates')),
					[HelpText] = MAX([HelpText]),
					[Scenario] = 'NONE',
					[NodeTypeBM] = MAX([NodeTypeBM]),
					[SendTo_MemberId] = -1,
					[Source] = 'ETL',
					[Parent] = MAX([Parent])
				FROM 
					Member
				WHERE
					DimensionID IN (0, @DimensionID)
				GROUP BY
					[Label]

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT [@Step] = @Step, [@Selected] = @Selected
			END

		IF @Debug <> 0 SELECT TempTable = '#WorkflowState_Members_Raw_1', * FROM [#WorkflowState_Members_Raw]

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#WorkflowState_Members_Raw_2',
					*
				FROM
					#WorkflowState_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#WorkflowState_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[Scenario],
					[NodeTypeBM],
					[SendTo_MemberId],
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
					[Scenario] = [MaxRaw].[Scenario],
					[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
					[SendTo_MemberId] = [MaxRaw].[SendTo_MemberId],
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
						[Scenario] = MAX([Raw].[Scenario]),
						[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
						[SendTo_MemberId] = MAX([Raw].[SendTo_MemberId]),
						[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), [Raw].[MemberKey]),
						[Source] = MAX([Raw].[Source]),
						[Synchronized] = 1,
						[Parent] = MAX([Raw].[Parent])
					FROM
						[#WorkflowState_Members_Raw] [Raw]
					GROUP BY
						[Raw].[MemberKey]
					) [MaxRaw]
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = @DimensionID AND M.[Label] = [MaxRaw].MemberKey
				WHERE
					[MaxRaw].[MemberKey] IS NOT NULL
				ORDER BY
					CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #WorkflowState_Members_Raw

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
