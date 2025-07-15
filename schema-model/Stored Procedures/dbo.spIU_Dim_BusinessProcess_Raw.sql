SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_BusinessProcess_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBMStep int = 65535,
	@StaticMemberYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000647,
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
EXEC [spIU_Dim_BusinessProcess_Raw] @UserID = -10, @InstanceID = 533, @VersionID = 1058, @Debug=1
EXEC [spIU_Dim_BusinessProcess_Raw] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @Debug = 1
EXEC [spIU_Dim_BusinessProcess_Raw] @UserID = -10, @InstanceID = 15, @VersionID = 1036, @Debug = 1

EXEC [spIU_Dim_BusinessProcess_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@DimensionID int = -2, --BusinessProcess
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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of BusinessProcess from pcINTEGRATOR',
			@MandatoryParameter = 'SourceTypeID|SourceDatabase' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Removed filter on BPs from Journal.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added test on LEN(S.BusinessProcess) > 0 for @SequenceBMStep = 1.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle FP13. Modified query for @SequenceBMStep = 2 (Journal sequences from Journal).'

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

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT, @JobID=@JobID

		IF OBJECT_ID (N'tempdb..#BusinessProcess_Members', N'U') IS NULL SET @CalledYN = 0

		IF @Debug <> 0 SELECT 	
			[@ProcedureName] = @ProcedureName,
			[@UserID] = @UserID,
			[@InstanceID] = @InstanceID,
			[@VersionID] = @VersionID,
			[@SequenceBMStep] = @SequenceBMStep,
			[@StaticMemberYN] = @StaticMemberYN,
			[@ApplicationID] = @ApplicationID,
			[@JournalTable] = @JournalTable,
			[@CalledYN] = @CalledYN,
			[@SourceTypeBM] = @SourceTypeBM,
			[@JobID] = @JobID

	SET @Step = 'Create temp table #BusinessProcess_Members_Raw'
		CREATE TABLE [#BusinessProcess_Members_Raw]
			(
			[MemberId] bigint,
			[MemberKey] nvarchar (100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar (512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar (1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Source] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar (255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = '@SequenceCounter = 1, @SequenceBMStep = 1' --Sources
		IF @SequenceBMStep & 1 > 0
			BEGIN
				INSERT INTO [#BusinessProcess_Members_Raw]
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
					[MemberId] = 1000000 + S.SourceID,
					[MemberKey] = S.BusinessProcess,
					[Description] = S.SourceName,
					[HelpText] = S.SourceName,
					[NodeTypeBM] = 1,
					[Source] = 'ETL',
					[Parent] = LEFT(S.BusinessProcess, CHARINDEX('_', S.BusinessProcess) - 1)
				FROM
					[pcINTEGRATOR].[dbo].[Source] S
					INNER JOIN [pcINTEGRATOR].[dbo].Model M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
					INNER JOIN [pcINTEGRATOR].[dbo].Model BM ON BM.ModelID = M.BaseModelID AND M.SelectYN <> 0
					INNER JOIN [pcINTEGRATOR].[dbo].[Application] A ON A.ApplicationID = M.ApplicationID AND A.ApplicationID = @ApplicationID AND A.SelectYN <> 0
				WHERE
					LEN(S.BusinessProcess) > 0 AND
					S.SelectYN <> 0

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = '@SequenceCounter = 2, @SequenceBMStep = 2' --Journal sequences from Journal
		IF @SequenceBMStep & 2 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO [#BusinessProcess_Members_Raw]
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
						[MemberId] = NULL,
						[MemberKey] = ''Jrn_'' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + J.[JournalSequence] + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''_FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE '''' END,
						[Description] = ''Jrn_'' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + J.[JournalSequence] + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''_FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE '''' END,
						[HelpText] = ''Jrn_'' + CASE WHEN LEFT(J.[JournalSequence], LEN(LTRIM(RTRIM(J.[Source])))) = LTRIM(RTRIM(J.[Source])) THEN '''' ELSE LTRIM(RTRIM(J.[Source])) + ''_'' END + J.[JournalSequence] + CASE WHEN J.[FiscalPeriod] >= 13 THEN ''_FP'' + CONVERT(nvarchar(15), J.[FiscalPeriod]) ELSE '''' END,
						[NodeTypeBM] = 1,
						[Source] = ''ETL'',
						[Parent] = ''Journal''
					FROM
						' + @JournalTable + ' J 
					WHERE
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID)
--						+ ' AND
--						J.[JournalSequence] NOT LIKE ''OB_%'''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = 'Static Rows'
		IF @StaticMemberYN <> 0
			BEGIN
				INSERT INTO [#BusinessProcess_Members_Raw]
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
					[Description] = MAX(REPLACE([Description], '@All_Dimension', 'All BusinessProcesss')),
					[HelpText] = MAX([HelpText]),
					[NodeTypeBM] = MAX([NodeTypeBM]),
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

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#BusinessProcess_Members_Raw',
					*
				FROM
					#BusinessProcess_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#BusinessProcess_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[Conversion],
					[Manual],
					[NoAutoElim],
					[NoAutoFx],
					[NodeTypeBM],
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
					[Conversion] = 0,
					[Manual] = 0,
					[NoAutoElim] = 0,
					[NoAutoFx] = 0,
					[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
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
						[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), [Raw].[MemberKey]),
						[Source] = MAX([Raw].[Source]),
						[Synchronized] = 1,
						[Parent] = MAX([Raw].[Parent])
					FROM
						[#BusinessProcess_Members_Raw] [Raw]
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
		DROP TABLE #BusinessProcess_Members_Raw

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
