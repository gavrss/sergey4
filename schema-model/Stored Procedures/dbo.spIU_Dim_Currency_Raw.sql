SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Currency_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBMStep int = 65535,
	@StaticMemberYN bit = 1,
	@SourceTypeID int = NULL,
	@SourceDatabase nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000654,
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
EXEC [spIU_Dim_Currency_Raw] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @SourceTypeID = 11, @SourceDatabase = 'DSPSOURCE03.CCM_Epicor10', @Debug = 1
EXEC [spIU_Dim_Currency_Raw] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @SourceTypeID = 12, @Debug = 1
EXEC [spIU_Dim_Currency_Raw] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @SourceTypeID = 11, @SourceDatabase = 'ERP10', @DebugBM = 2
EXEC [spIU_Dim_Currency_Raw] @UserID = -10, @InstanceID = -1590, @VersionID = -1590, @DebugBM = 3

EXEC [spIU_Dim_Currency_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceTypeName nvarchar(50),
	@SourceTypeDescription nvarchar(255),
	@SourceTypeBM int,
	@SQLStatement nvarchar(max),
	@SourceID int = 2018,
	@DimensionID int = -3,
	@Entity_MemberKey nvarchar(50),
	@JournalTable nvarchar(100),

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
	@Version nvarchar(50) = '2.1.2.2181'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of Currencies from Source system',
			@MandatoryParameter = 'SourceTypeID|SourceDatabase' --Without @, separated by |

		IF @Version = '2.0.3.2153' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2173' SET @Description = 'Added a NOT EXISTS filter when INSERTing INTO [#Currency_Members].'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-731: For @SourceTypeID = 11, set valid Currency existing in pcINTEGRATOR..Member table.'
		IF @Version = '2.1.2.2181' SET @Description = 'Exclude blank currencies.'

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
			@SourceTypeName = SourceTypeName,
			@SourceTypeDescription = SourceTypeDescription
		FROM
			SourceType
		WHERE
			SourceTypeID = @SourceTypeID

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

		IF OBJECT_ID(N'TempDB.dbo.#Currency_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@SourceTypeBM] = @SourceTypeBM

	SET @Step = 'Create temp table #Currency_Members_Raw'
		CREATE TABLE #Currency_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Get existing currencies from Entity'
		IF @SequenceBMStep & 1 > 0
			BEGIN
				INSERT INTO #Currency_Members_Raw
					(
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Source],
					[Parent]
					)
				SELECT DISTINCT
					[Label] = EB.[Currency] COLLATE DATABASE_DEFAULT,
					[Description] = EB.[Currency] COLLATE DATABASE_DEFAULT,
					[NodeTypeBM] = 1,
					[Source] = 'ETL' COLLATE DATABASE_DEFAULT,
					[Parent] = 'All_' COLLATE DATABASE_DEFAULT
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity] E
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.SelectYN <> 0
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.SelectYN <> 0 AND
					EB.[Currency] IS NOT NULL AND
					EB.[Currency] <> ''

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Currencies from Journal'
		IF @SequenceBMStep & 2 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #Currency_Members_Raw
						(
						[MemberKey],
						[Description],
						[NodeTypeBM],
						[Source],
						[Parent]
						)
					SELECT
						[MemberKey] = sub.[MemberKey],
						[Description] = sub.[Description],
						[NodeTypeBM] = 1,
						[Source] = ''EFP'',
						[Parent] = ''All_''
					FROM
						(
						SELECT DISTINCT
							[MemberKey] = [Currency_Book],
							[Description] = [Currency_Book]
						FROM
							' + @JournalTable + ' J 
						WHERE
							J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + '
						UNION SELECT DISTINCT
							[MemberKey] = [Currency_Transaction],
							[Description] = [Currency_Transaction]
						FROM
							' + @JournalTable + ' J 
						WHERE
							J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + '
						) sub
					WHERE
						ISNULL(sub.[MemberKey], '''') <> '''' AND
						NOT EXISTS (SELECT 1 FROM #Currency_Members_Raw C WHERE C.[MemberKey] = sub.[MemberKey])'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @@ROWCOUNT
				IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected
			END

	SET @Step = 'Fill temptable #Currency_Members_Raw'
		IF @SequenceBMStep & 4 > 0
			BEGIN
				--IF @SourceTypeID = 1 --Epicor ERP (E9)
				--	BEGIN
				--		SET @Message = 'Currencies for Epicor ERP (E9) is not yet implemented.'
				--		SET @Severity = 16
				--		GOTO EXITPOINT
				--	END
					
				--ELSE IF @SourceTypeID = 8 --Navision
				--	BEGIN
				--		SET @Message = 'Currencies for Navision is not yet implemented.'
				--		SET @Severity = 16
				--		GOTO EXITPOINT
				--	END

				--ELSE 
				IF @SourceTypeID = 11 --Epicor ERP (E10)
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@SourceTypeName] = @SourceTypeName, [@SourceDatabase] = @SourceDatabase, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID

						SET @SQLStatement = '
							INSERT INTO #Currency_Members_Raw
								(
								[MemberKey],
								[Description],
								[NodeTypeBM],
								[Source],
								[Parent]
								)
							SELECT
								[MemberKey] = sub.[MemberKey],
								[Description] = sub.[Description],
								[NodeTypeBM] = 1,
								[Source] = ''' + @SourceTypeName + ''',
								[Parent] = ''All_''
							FROM
								pcINTEGRATOR.dbo.Member M
								INNER JOIN 
								(
								SELECT DISTINCT
									[MemberKey] = CR.[TargetCurrCode] COLLATE DATABASE_DEFAULT,
									[Description] = CR.[TargetCurrCode] COLLATE DATABASE_DEFAULT
								FROM
									' + @SourceDatabase + '.[Erp].[CurrExRate] CR
									INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.MemberKey = CR.Company COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
								UNION
								SELECT DISTINCT
									[MemberKey] = CR.[SourceCurrCode] COLLATE DATABASE_DEFAULT,
									[Description] = CR.[SourceCurrCode] COLLATE DATABASE_DEFAULT
								FROM
									' + @SourceDatabase + '.[Erp].[CurrExRate] CR
									INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.MemberKey = CR.Company COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
								) sub ON sub.[MemberKey] = M.[Label]
							WHERE
								M.DimensionID = -3 AND 
								ISNULL(sub.[MemberKey], '''') <> '''' AND
								NOT EXISTS (SELECT 1 FROM #Currency_Members_Raw C WHERE C.[MemberKey] = sub.[MemberKey])'

					END

				--ELSE IF @SourceTypeID = 12 --Enterprise (E7)
				--	BEGIN
				--		SET @Message = 'Currencies for Enterprise is not yet implemented.'
				--		SET @Severity = 16
				--		GOTO EXITPOINT
				--	END

				--ELSE IF @SourceTypeID = 15 --pcSource
				--	BEGIN
				--		SET @Message = 'Currencies for pcSource is not yet implemented.'
				--		SET @Severity = 16
				--		GOTO EXITPOINT
				--	END

				--ELSE
				--	BEGIN
				--		SET @Message = 'Currencies for selected SourceTypeID (' + CONVERT(nvarchar(15), @SourceTypeID) + ') is not yet implemented.'
				--		SET @Severity = 16
				--		GOTO EXITPOINT
				--	END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				INSERT INTO #Currency_Members_Raw
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
					[MemberId],
					[MemberKey] = [Label],
					[Description] = REPLACE([Description], '@All_Dimension', 'All Currencies'),
					[HelpText],
					[NodeTypeBM],
					[Source] = 'ETL',
					[Parent]
				FROM 
					Member
				WHERE
					DimensionID IN (0, @DimensionID) AND
					[SourceTypeBM] & @SourceTypeBM > 0

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Currency_Members_Raw',
					[MemberId] = ISNULL(C.[MemberId], M.MemberID),
					[MemberKey] = C.[MemberKey],
					[Description] = C.[Description],
					[HelpText] = COALESCE(C.[HelpText], M.[HelpText], C.[Description]),
					[NodeTypeBM] = C.[NodeTypeBM],
					[Source] = C.[Source],
					[Synchronized] = 1,
					[Parent] = CASE C.[Parent] WHEN 'NULL' THEN NULL ELSE C.[Parent] END
				FROM
					#Currency_Members_Raw C
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = @DimensionID AND M.[Label] = C.MemberKey
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#Currency_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
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
					[HelpText] = COALESCE([MaxRaw].[HelpText], M.[HelpText], [MaxRaw].[Description]),
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
						[#Currency_Members_Raw] [Raw]
					GROUP BY
						[Raw].[MemberKey]
					) [MaxRaw]
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = @DimensionID AND M.[Label] = [MaxRaw].MemberKey
				WHERE
					[MaxRaw].[MemberKey] IS NOT NULL AND
					NOT EXISTS (SELECT 1 FROM [#Currency_Members] CM WHERE CM.[MemberKey] = [MaxRaw].[MemberKey])
				ORDER BY
					CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Currency_Members_Raw

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
