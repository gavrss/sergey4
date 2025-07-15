SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_GLJrnDtl]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 1, 
	@CheckTypeBM int = 7, 
	@IncrementalYN bit = 1,
	@CheckSumValue int = NULL OUT,
	@CheckSumStatus10 int = NULL OUT,
	@CheckSumStatus20 int = NULL OUT,
	@CheckSumStatus30 int = NULL OUT,
	@CheckSumStatus40 int = NULL OUT,
	@CheckSumStatusBM int = 7, -- 1=Open, 2=Investigating, 4=Ignored, 8=Solved

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000616,
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
DECLARE @CheckSumValue int, @CheckSumStatus10 int, @CheckSumStatus20 int, @CheckSumStatus30 int, @CheckSumStatus40 int
EXEC [spCheckSum_GLJrnDtl] @UserID=-10, @InstanceID=478, @VersionID=1030, @Debug=0,
@CheckSumValue=@CheckSumValue OUT, @CheckSumStatus10=@CheckSumStatus10 OUT, @CheckSumStatus20 =@CheckSumStatus20 OUT,
@CheckSumStatus30=@CheckSumStatus30 OUT, @CheckSumStatus40=@CheckSumStatus40 OUT
SELECT [@CheckSumValue] = @CheckSumValue, [@CheckSumStatus10] = @CheckSumStatus10, [@CheckSumStatus20] = @CheckSumStatus20, 
[@CheckSumStatus30] = @CheckSumStatus30, [@CheckSumStatus40] = @CheckSumStatus40

DECLARE @CheckSumValue int
EXEC [spCheckSum_GLJrnDtl] @UserID=-10, @InstanceID=478, @VersionID=1030, @CheckSumValue = @CheckSumValue OUT, @Debug=1
SELECT CheckSumValue = @CheckSumValue

EXEC [spCheckSum_GLJrnDtl] @UserID=-10, @InstanceID=478, @VersionID=1030, @ResultTypeBM=4, @CheckSumStatusBM=8

EXEC [spCheckSum_GLJrnDtl] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	@SQLStatement nvarchar(max),
	@CalledYN bit = 1,
	@JournalTable nvarchar(100),
	@SourceDatabase nvarchar(100),
	@Owner nvarchar(10),
	@ETLDatabase nvarchar(100),

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
	@ToBeChanged nvarchar(255),
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get CheckSums for Epicor ERP GLJrnDtl table',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2155' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added parameters @CheckSumStatus10, @CheckSumStatus20, @CheckSumStatus30, @CheckSumStatus40, @CheckSumStatusBM. Modified queries for @ResultTypeBM=4.'
		IF @Version = '2.1.1.2173' SET @Description = 'Removed filters for @Step = Insert into JobLog.'
		IF @Version = '2.1.1.2174' SET @Description = 'Added [CheckSumStatusBM] in @ResultTypeBM = 4.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			--@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

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

				IF @Debug <> 0 SELECT [@JobID] = @JobID
			END

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		SELECT
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@Owner = ST.[Owner]
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = 1
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SELECT
			@ETLDatabase = ETLDatabase
		FROM
			pcINTEGRATOR_Data.dbo.[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

	SET @Step = 'Get CheckSumValue'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				--SET @Step = 'Set CheckSumRowLogID'
				--	INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
				--		(
				--		[CheckSumRowKey],
				--		[InstanceID],
				--		[VersionID],
				--		[ProcedureID]
				--		)
				--	SELECT
				--		[CheckSumRowKey] = CONVERT(nvarchar(20), CJT.[JobID]) + '_' + CJT.[Company] + '_' + CJT.[BookID] + '_' + CONVERT(nvarchar(15), CJT.[FiscalYear]) + '_' + CJT.[JournalCode] + '_' + CONVERT(nvarchar(15), CJT.[JournalNum]) + '_' + CONVERT(nvarchar(15), CJT.[CheckTypeBM]) + '_' + CONVERT(nvarchar(15), CJT.[CheckValue]),
				--		[InstanceID] = CJT.[InstanceID],
				--		[VersionID] = CJT.[VersionID],
				--		[ProcedureID] = @ProcedureID
				--	FROM
				--		[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_GLJrnDtl] CJT
				--	WHERE
				--		CJT.[InstanceID] = @InstanceID AND
				--		CJT.[VersionID] = @VersionID AND
				--		NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = CONVERT(nvarchar(20), CJT.[JobID]) + '_' + CJT.[Company] + '_' + CJT.[BookID] + '_' + CONVERT(nvarchar(15), CJT.[FiscalYear]) + '_' + CJT.[JournalCode] + '_' + CONVERT(nvarchar(15), CJT.[JournalNum]) + '_' + CONVERT(nvarchar(15), CJT.[CheckTypeBM]) + '_' + CONVERT(nvarchar(15), CJT.[CheckValue]))

				--	UPDATE CJT
				--	SET
				--		CheckSumRowLogID = CSRL.CheckSumRowLogID
				--	FROM
				--		[pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_GLJrnDtl] CJT
				--		INNER JOIN [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL ON CSRL.[InstanceID] = CJT.InstanceID AND CSRL.[VersionID] = CJT.VersionID AND CSRL.[CheckSumRowKey] = CONVERT(nvarchar(20), CJT.[JobID]) + '_' + CJT.[Company] + '_' + CJT.[BookID] + '_' + CONVERT(nvarchar(15), CJT.[FiscalYear]) + '_' + CJT.[JournalCode] + '_' + CONVERT(nvarchar(15), CJT.[JournalNum]) + '_' + CONVERT(nvarchar(15), CJT.[CheckTypeBM]) + '_' + CONVERT(nvarchar(15), CJT.[CheckValue])
				--	WHERE
				--		CJT.[InstanceID] = @InstanceID AND
				--		CJT.[VersionID] = @VersionID

				--	UPDATE CSRL
				--	SET
				--		--[Solved] = GetDate(),
				--		--[CheckSumStatusID] = 40
				--		[CheckSumStatusBM] = 8,
				--		[UserID] = @UserID,
				--		[Comment] = 'Resolved automatically.',
				--		[Updated] = GetDate()
				--	FROM
				--		[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
				--	WHERE
				--		CSRL.[InstanceID] = @InstanceID AND
				--		CSRL.[VersionID] = @VersionID AND
				--		CSRL.[ProcedureID] = @ProcedureID AND
				--		--CSRL.[Solved] IS NULL AND
				--		--CSRL.[CheckSumStatusID] <> 40 AND
				--		CSRL.[CheckSumStatusBM] & 8 = 0 AND
				--		NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[wrk_CheckSum_GLJrnDtl] CJT WHERE CJT.[InstanceID] = CSRL.[InstanceID] AND CJT.[VersionID] = CSRL.[VersionID] AND CJT.[CheckSumRowLogID] = CSRL.[CheckSumRowLogID])

				--	SET @Updated = @Updated + @@ROWCOUNT

				SET @Step = 'Calculate @CheckSumValue'
					SELECT
						@CheckSumValue = ISNULL(SUM(CASE WHEN wrk.[JournalAmount] IS NULL OR wrk.[JournalAmount] <> 0 THEN 1 ELSE 0 END), 0),
						@CheckSumStatus10 = 0,
						@CheckSumStatus20 = ISNULL(SUM(CASE WHEN wrk.[JournalAmount] IS NULL OR wrk.[JournalAmount] <> 0 THEN 1 ELSE 0 END), 0),
						@CheckSumStatus30 = ISNULL(SUM(CASE WHEN wrk.[JournalAmount] = 0 THEN 1 ELSE 0 END), 0),
						@CheckSumStatus40 = ISNULL(MAX(sub.[CheckSumStatus40]), 0)
					FROM
						[pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance] wrk
						LEFT JOIN (
							SELECT 
								[CheckSumStatus40] = COUNT(1) 
							FROM (
									SELECT [cnt] = 1
										--SourceID, Company, BookID, FiscalYear, FiscalPeriod, JournalCode, JournalNum
									FROM
										[pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance] GL
									WHERE
										GL.[InstanceID] = @InstanceID AND
										GL.[VersionID] = @VersionID AND 
										GL.[JobID] <> @JobID AND 
										NOT EXISTS (
													SELECT 1 
													FROM 
														[pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance] W 
													WHERE 
														W.InstanceID = GL.InstanceID AND 
														W.VersionID = GL.VersionID AND 
														W.JobID = @JobID AND 
														W.SourceID = GL.SourceID AND
														W.Company = GL.Company AND
														W.BookID = GL.BookID AND
														W.FiscalYear = GL.FiscalYear AND
														W.FiscalPeriod = GL.FiscalPeriod AND
														W.JournalCode = GL.JournalCode AND
														W.JournalNum = GL.JournalNum AND
														W.JournalAmount <> 0
													)
									GROUP BY 
										GL.SourceID, GL.Company, GL.BookID, GL.FiscalYear, GL.FiscalPeriod, GL.JournalCode, GL.JournalNum
								) sub1
						)sub ON 1 = 1
					WHERE
						wrk.[InstanceID] = @InstanceID AND
						wrk.[VersionID] = @VersionID AND 
						wrk.[JobID] = @JobID
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
				CREATE TABLE #GLJrnDtl_NotBalance
					(
					CheckSumStatusBM INT,
					Comment NVARCHAR(255) COLLATE DATABASE_DEFAULT,
					SourceID INT,
					Company NVARCHAR(8) COLLATE DATABASE_DEFAULT,
					BookID NVARCHAR(12) COLLATE DATABASE_DEFAULT,
					FiscalYear INT,
                    FiscalPeriod INT,
					JournalCode NVARCHAR(4) COLLATE DATABASE_DEFAULT,
                    JournalNum INT,
					MinJournalLine INT,
					MaxJournalLine INT,
					PostedDate DATE,
					MinSysRevID BIGINT,
					MaxSysRevID BIGINT,
					[Rows] INT,
					Amount FLOAT,
					JournalRows INT,
					JournalAmount FLOAT,
					Inserted DATETIME,
					AuthenticatedUserID INT,
					AuthenticatedUserName NVARCHAR(100) COLLATE DATABASE_DEFAULT,
					AuthenticatedUserOrganization NVARCHAR(50) COLLATE DATABASE_DEFAULT,
					Updated DATETIME 
					)

				--Insert CheckStatus IGNORED and INVESTIGATING
				INSERT INTO #GLJrnDtl_NotBalance
					(
					CheckSumStatusBM,
					Comment,
					SourceID,
					Company,
					BookID,
					FiscalYear,
                    FiscalPeriod,
					JournalCode,
                    JournalNum,
					MinJournalLine,
					MaxJournalLine,
					PostedDate,
					MinSysRevID,
					MaxSysRevID,
					[Rows],
					Amount,
					JournalRows,
					JournalAmount,
					Inserted ,
					AuthenticatedUserID,
					AuthenticatedUserName,
					AuthenticatedUserOrganization,
					Updated
					)
				SELECT
					CheckSumStatusBM = CASE WHEN wrk.[JournalAmount] = 0 THEN 4 ELSE 2 END,
					Comment = CASE WHEN wrk.[JournalAmount] = 0 THEN 'Ignored. Sum of Journal = 0.' ELSE 'Investigating.' END,
					wrk.SourceID,
					wrk.Company,
					wrk.BookID,
					wrk.FiscalYear,
                    wrk.FiscalPeriod,
					wrk.JournalCode,
                    wrk.JournalNum,
					wrk.MinJournalLine,
					wrk.MaxJournalLine,
					wrk.PostedDate,
					wrk.MinSysRevID,
					wrk.MaxSysRevID,
					wrk.[Rows],
					wrk.Amount,
					wrk.JournalRows,
					wrk.JournalAmount,
					wrk.Inserted,
					AuthenticatedUserID = U.UserID,
					AuthenticatedUserName = U.UserNameDisplay,
					AuthenticatedUserOrganization = I.InstanceName,
					Updated = wrk.Inserted
				FROM
					pcINTEGRATOR_Log..[wrk_GLJrnDtl_NotBalance] wrk
					--INNER JOIN CheckSumStatus CSS ON CSS.CheckSumStatusBM = wrk.CheckSumStatusBM
					LEFT JOIN [pcINTEGRATOR].[dbo].[User] U ON U.UserID = -10 --default for now
					LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID 
				WHERE
					wrk.[InstanceID] = @InstanceID AND
					wrk.[VersionID] = @VersionID AND 
					wrk.[JobID] = @JobID
				OPTION (MAXDOP 1)

				--Insert CheckStatus SOLVED
				INSERT INTO #GLJrnDtl_NotBalance
					(
					CheckSumStatusBM,
					Comment,
					SourceID,
					Company,
					BookID,
					FiscalYear,
                    FiscalPeriod,
					JournalCode,
                    JournalNum,
					MinJournalLine,
					MaxJournalLine,
					PostedDate,
					MinSysRevID,
					MaxSysRevID,
					[Rows],
					Amount,
					JournalRows,
					JournalAmount,
					Inserted ,
					AuthenticatedUserID,
					AuthenticatedUserName,
					AuthenticatedUserOrganization,
					Updated
					)
				SELECT
					CheckSumStatusBM = 8,
					Comment = 'Resolved automatically.',
					wrk.SourceID,
					wrk.Company,
					wrk.BookID,
					wrk.FiscalYear,
                    wrk.FiscalPeriod,
					wrk.JournalCode,
                    wrk.JournalNum,
					MinJournalLine = MIN(wrk.MinJournalLine),
					MaxJournalLine = MAX(wrk.MaxJournalLine),
					PostedDate = MIN(wrk.PostedDate),
					MinSysRevID = MIN(wrk.MinSysRevID),
					MaxSysRevID = MAX(wrk.MaxSysRevID),
					[Rows] = MAX(wrk.[Rows]),
					Amount = 0, 
					JournalRows = MAX(wrk.JournalRows), 
					JournalAmount = 0,
					Inserted = MIN(wrk.Inserted),
					AuthenticatedUserID = MAX(U.UserID),
					AuthenticatedUserName = MAX(U.UserNameDisplay),
					AuthenticatedUserOrganization = MAX(I.InstanceName),
					Updated = MAX(wrk.Inserted)
				FROM 
					[pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance] wrk 
					LEFT JOIN [pcINTEGRATOR].[dbo].[User] U ON U.UserID = -10 --default for now
					LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID 
				WHERE 
					wrk.InstanceID = @InstanceID AND 
					wrk.VersionID = @VersionID AND 
					wrk.JobID <> @JobID AND 
					NOT EXISTS 
						(
						SELECT 1
						FROM 
							[pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance] G
						WHERE 
							G.JobID = @JobID AND 
							G.InstanceID = wrk.InstanceID AND 
							G.VersionID = wrk.VersionID AND 
							G.SourceID = wrk.SourceID AND
							G.Company = wrk.Company AND
							G.BookID = wrk.BookID AND
							G.FiscalYear = wrk.FiscalYear AND 
							G.FiscalPeriod = wrk.FiscalYear AND
							G.JournalCode = wrk.JournalCode AND 
							G.JournalNum = wrk.JournalNum
						)
				GROUP BY 
					wrk.SourceID, 
					wrk.Company,
					wrk.BookID, 
					wrk.FiscalYear, 
					wrk.FiscalPeriod, 
					wrk.JournalCode, 
					wrk.JournalNum
				ORDER BY 
					MIN(wrk.Inserted) DESC 
				OPTION (MAXDOP 1)

				SELECT
					[ResultTypeBM] = 4,
					[FirstOccurrence] = GLJ.[Inserted],
					[CheckSumStatusBM] = CSS.[CheckSumStatusBM],
					[CurrentStatus] = CSS.[CheckSumStatusName],
					GLJ.Comment,
					GLJ.SourceID,
					GLJ.Company,
					GLJ.BookID,
					GLJ.FiscalYear,
                    GLJ.FiscalPeriod,
					GLJ.JournalCode,
                    GLJ.JournalNum,
					GLJ.MinJournalLine,
					GLJ.MaxJournalLine,
					GLJ.PostedDate,
					GLJ.MinSysRevID,
					GLJ.MaxSysRevID,
					GLJ.[Rows],
					GLJ.Amount,
					GLJ.JournalRows,
					GLJ.JournalAmount,
					GLJ.AuthenticatedUserID,
					GLJ.AuthenticatedUserName,
					GLJ.AuthenticatedUserOrganization,
					Updated = GLJ.Inserted
				FROM
					#GLJrnDtl_NotBalance GLJ
					INNER JOIN pcINTEGRATOR.dbo.CheckSumStatus CSS ON CSS.CheckSumStatusBM = GLJ.CheckSumStatusBM
				WHERE
					GLJ.CheckSumStatusBM & @CheckSumStatusBM > 0
				ORDER BY
					GLJ.[Inserted] DESC
				OPTION (MAXDOP 1)

				SET @Selected = @Selected + @@ROWCOUNT

				DROP table #GLJrnDtl_NotBalance
			END

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
