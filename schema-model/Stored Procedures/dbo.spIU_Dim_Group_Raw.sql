SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Group_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBMStep int = 65535,
	@StaticMemberYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000666,
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
EXEC [spIU_Dim_Group_Raw] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @Debug = 1
EXEC [spIU_Dim_Group_Raw] @UserID = -10, @InstanceID = 476, @VersionID = 1029, @Debug = 1

EXEC [spIU_Dim_Group_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@DimensionID int = -35, --Group
	@ApplicationID int,
	@JournalTable nvarchar(100),
	@SourceTypeBM int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of Group from pcINTEGRATOR',
			@MandatoryParameter = 'SourceTypeID|SourceDatabase' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2153' SET @Description = 'Enhanced hierarchy handling.'
		IF @Version = '2.0.3.2154' SET @Description = 'Modified currency handling.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

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

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT, @JobID=@JobID

		IF OBJECT_ID (N'tempdb..#Group_Members', N'U') IS NULL SET @CalledYN = 0

		IF @Debug <> 0 SELECT [@JournalTable] = @JournalTable, [@CalledYN] = @CalledYN, [@SourceTypeBM] = @SourceTypeBM

	SET @Step = 'Create temp table #Group_Members_Raw'
		CREATE TABLE [#Group_Members_Raw]
			(
			[MemberId] bigint,
			[MemberKey] nvarchar (100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar (512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar (1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Currency] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[Currency_MemberId] int,
			[Source] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar (255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = '@SequenceCounter = 1, @SequenceBMStep = 1' --Group
		IF @SequenceBMStep & 1 > 0
			BEGIN
				INSERT INTO [#Group_Members_Raw]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Currency],
					[Source],
					[Parent]
					)
				SELECT DISTINCT
					[MemberId] = NULL,
					[MemberKey] = E.MemberKey,
					[Description] = E.EntityName,
					[NodeTypeBM] = 1,
					[Currency] = EB.Currency,
					[Source] = 'EFP',
					[Parent] = 'All_'
				FROM
					pcINTEGRATOR..Entity E
					INNER JOIN pcINTEGRATOR..Entity_Book EB ON EB.EntityID = E.EntityID AND EB.BookTypeBM & 16 > 0 AND EB.SelectYN <> 0
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.EntityTypeID = 0 AND
					E.SelectYN <> 0

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = 'Static Rows'
		IF @StaticMemberYN <> 0
			BEGIN
				INSERT INTO [#Group_Members_Raw]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Currency],
					[Source],
					[Parent]
					)
				SELECT 
					[MemberId] = MAX([MemberId]),
					[MemberKey] = [Label],
					[Description] = MAX(REPLACE([Description], '@All_Dimension', 'All Groups')),
					[HelpText] = MAX([HelpText]),
					[NodeTypeBM] = MAX([NodeTypeBM]),
					[Currency] = 'NONE',
					[Source] = 'ETL',
					[Parent] = MAX([Parent])
				FROM 
					Member
				WHERE
					DimensionID IN (0, @DimensionID) AND
					[SourceTypeBM] & @SourceTypeBM > 0
				GROUP BY
					[Label]

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = 'Set Currency_MemberId'
		UPDATE EMR
		SET
			Currency_MemberId = ISNULL(M.MemberID, -1)
		FROM
			[#Group_Members_Raw] EMR
			LEFT JOIN Member M ON M.DimensionID = -3 AND M.Label = EMR.Currency

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Group_Members_Raw',
					*
				FROM
					#Group_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#Group_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Currency],
					[Currency_MemberId],
					[SBZ],
					[Source],
					[Synchronized],
					[Parent]
					)
				SELECT TOP 1000000
					[MemberId] = ISNULL([MaxRaw].[MemberId], M.MemberID),
					[MemberKey] = [MaxRaw].[MemberKey],
					[Description] = [MaxRaw].[Description],
					[HelpText] = CASE WHEN ISNULL([MaxRaw].[HelpText], '') = '' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END,
					[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
					[Currency] = [MaxRaw].[Currency],
					[Currency_MemberId] = [MaxRaw].[Currency_MemberId],
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
						[Currency] = MAX([Raw].[Currency]),
						[Currency_MemberId] = MAX([Raw].[Currency_MemberId]), 
						[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), [Raw].[MemberKey]),
						[Source] = MAX([Raw].[Source]),
						[Synchronized] = 1,
						[Parent] = MAX([Raw].[Parent])
					FROM
						[#Group_Members_Raw] [Raw]
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
		DROP TABLE #Group_Members_Raw

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
