SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Sales_CurrentOrderState]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@TableName_DataClass nvarchar(100) = NULL,
	@FullReloadYN bit = 0, --0 = Only set rows involved in the last load, 1 = Set all rows
	@StepSize int = 5000,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000701,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_Sales_CurrentOrderState',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spIU_DC_Sales_CurrentOrderState] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spIU_DC_Sales_CurrentOrderState] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@MaxRowID int,
	@StepStartTime datetime,
	@LoopStartTime datetime,
	@FromRowID int = 0,
	@StepCounter int = 0,
	@StepUpdated int = 0,
	@GUID nvarchar(50),
	@CallistoDatabase nvarchar(100),
	
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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2163'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set CurrentOrderState in DataClass Sales',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2162' SET @Description = 'Fully tested and finalized.'
		IF @Version = '2.1.0.2163' SET @Description = 'Converted hardcoded queries to dynamic code.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -4 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

	SET @Step = 'Create temp table #OrderState'
		IF OBJECT_ID(N'TempDB.dbo.#OrderState', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #OrderState
					(
					[RowID] [int] IDENTITY(1,1) NOT NULL,
					[Entity_MemberID] [bigint] NOT NULL,
					[OrderNo_MemberID] [bigint] NOT NULL,
					[OrderLine_MemberId] [bigint] NOT NULL
					)

				SELECT @GUID = NEWID()
				SET @SQLStatement = '
					ALTER TABLE [#OrderState] ADD CONSTRAINT [PK_' + @GUID + '_#OrderState] PRIMARY KEY CLUSTERED 
					(
						[RowID] ASC
					)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]'

				EXEC (@SQLStatement)

				SET @SQLStatement = '
					INSERT INTO #OrderState
						(
						Entity_MemberID,
						OrderNo_MemberID,
						OrderLine_MemberId
						)
					SELECT
						Entity_MemberID,
						OrderNo_MemberID,
						OrderLine_MemberId
					FROM
						' + @CallistoDatabase + '.dbo.FACT_Sales_default_partition
					WHERE
						(CurrentOrderState_MemberId = -1 OR ' + CONVERT(NVARCHAR(10), @FullReloadYN) + ' <> 0) AND
						Scenario_MemberId = 110
					GROUP BY
						Entity_MemberID,
						OrderNo_MemberID,
						OrderLine_MemberId'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

			END
			
		IF @DebugBM & 8 > 0 SELECT TempTable = '#OrderState', * FROM #OrderState ORDER BY [RowID]
			
		SELECT @MaxRowID = MAX(RowID) FROM #OrderState

		IF @DebugBM & 2 > 0 SELECT [@MaxRowID] = @MaxRowID

	SET @Step = 'Create temp table #OrderState_wrk'
		CREATE TABLE #OrderState_wrk
			(
			[Entity_MemberID] [bigint] NOT NULL,
			[OrderNo_MemberID] [bigint] NOT NULL,
			[OrderLine_MemberId] [bigint] NOT NULL,
			[Scenario_MemberId] [bigint] NOT NULL
			)
		--	,
		--CONSTRAINT [PK_#OrderState_wrk] PRIMARY KEY CLUSTERED 
		--	(
		--	[Entity_MemberID] ASC,
		--	[OrderNo_MemberID] ASC,
		--	[OrderLine_MemberId] ASC,
		--	[Scenario_MemberId] ASC
		--	))

	SET @Step = 'Create temp table #Sales_Sub'
		CREATE TABLE #Sales_Sub
			(
			[Entity_MemberId] bigint NOT NULL,
			[OrderNo_MemberId] bigint NOT NULL,
			[OrderLine_MemberId] bigint NOT NULL,
			[Scenario_MemberId] bigint NOT NULL,
			[OrderState_MemberId] bigint NOT NULL
			)

		--SELECT @GUID = NEWID()
		--SET @SQLStatement = '
		--	ALTER TABLE [#Sales_Sub] ADD CONSTRAINT [PK_' + @GUID + '_#Sales_Sub] PRIMARY KEY CLUSTERED 
		--	(
		--		[Entity_MemberID] ASC,
		--		[OrderNo_MemberID] ASC,
		--		[OrderLine_MemberId] ASC,
		--		[Scenario_MemberId] ASC,
		--		[OrderState_MemberId] ASC
		--	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]'

		--EXEC (@SQLStatement)

	SET @Step = 'Create temp table #CurrentOrderState'
		CREATE TABLE #CurrentOrderState
			(
			[Entity_MemberId] bigint,
			[OrderNo_MemberId] bigint,
			[OrderLine_MemberId] bigint,
			[Scenario_MemberId] bigint,
			[OrderState_MemberId] bigint,
			[CurrentOrderState_MemberId] bigint
			)

	SET @Step = 'Create INDEX in Sales FACT table'
		SELECT @SQLStatement = '
			EXEC ' + @CallistoDatabase + '.[dbo].sp_executesql N''
			CREATE NONCLUSTERED INDEX [IX_Sales_OrderState] ON [dbo].[FACT_Sales_default_partition]
			(
				[Entity_MemberId] ASC,
				[OrderNo_MemberId] ASC,
				[OrderLine_MemberId] ASC,
				[Scenario_MemberId] ASC,
				[OrderState_MemberId] ASC,
				[CurrentOrderState_MemberId] ASC,
				[TimeDay_MemberId] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Update CurrentOrderState'
		WHILE @FromRowID < @MaxRowID
			BEGIN
				SET @LoopStartTime = GETDATE()
				SET @StepCounter = @StepCounter + 1

				TRUNCATE TABLE #OrderState_wrk
				TRUNCATE TABLE #Sales_Sub
				TRUNCATE TABLE #CurrentOrderState

				INSERT INTO #OrderState_wrk
					(
					[Entity_MemberId],
					[OrderNo_MemberId],
					[OrderLine_MemberId],
					[Scenario_MemberId]
					)
				SELECT 
					[Entity_MemberId],
					[OrderNo_MemberId],
					[OrderLine_MemberId],
					[Scenario_MemberId] = 110
				FROM
					#OrderState
				WHERE
					RowID BETWEEN @FromRowID AND @FromRowID + @StepSize - 1

				SET @StepStartTime = GETDATE()

				SET @SQLStatement = '
					INSERT INTO #Sales_Sub
						(
						[Entity_MemberId],
						[OrderNo_MemberId],
						[OrderLine_MemberId],
						[Scenario_MemberId],
						[OrderState_MemberId]
						)
					SELECT
						[Entity_MemberId] = OS.[Entity_MemberId],
						[OrderNo_MemberId] = OS.[OrderNo_MemberId],
						[OrderLine_MemberId] = OS.[OrderLine_MemberId],
						[Scenario_MemberId] = OS.[Scenario_MemberId],
						[OrderState_MemberId] = MAX(F.[OrderState_MemberId])
					FROM
						#OrderState_wrk OS
						INNER JOIN ' + @TableName_DataClass + ' F ON 
							F.[Entity_MemberId] = OS.[Entity_MemberId] AND
							F.[OrderNo_MemberId] = OS.[OrderNo_MemberId] AND
							F.[OrderLine_MemberId] = OS.[OrderLine_MemberId] AND
							F.[Scenario_MemberId] = OS.[Scenario_MemberId] AND
							((F.[TimeDay_MemberId] <= CONVERT(int, CONVERT(nvarchar(50), GetDate(), 112)) AND F.[OrderState_MemberId] = 170) OR
							F.[OrderState_MemberId] NOT IN (170))
					GROUP BY
						OS.[Entity_MemberId],
						OS.[OrderNo_MemberId],
						OS.[OrderLine_MemberId],
						OS.[Scenario_MemberId]'

				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'INSERT INTO #Sales_Sub', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [@FromRowID] = @FromRowID

				SET @StepStartTime = GETDATE()
				
				--SET @SQLStatement = '
				--	UPDATE F
				--	SET
				--		CurrentOrderState_MemberId = CASE WHEN sub.OrderNo_MemberId IS NOT NULL THEN 101 ELSE 100 END
				--	FROM
				--		' + @TableName_DataClass + ' F
				--		INNER JOIN #OrderState_wrk OS ON
				--			OS.[Entity_MemberId] = F.[Entity_MemberId] AND 
				--			OS.[OrderNo_MemberId] = F.[OrderNo_MemberId] AND 
				--			OS.[OrderLine_MemberId] = F.[OrderLine_MemberId] AND
				--			OS.[Scenario_MemberId] = F.[Scenario_MemberId]
				--		LEFT JOIN #Sales_Sub sub ON	
				--			sub.[Entity_MemberId] = F.[Entity_MemberId] AND
				--			sub.[OrderNo_MemberId] = F.[OrderNo_MemberId] AND
				--			sub.[OrderLine_MemberId] = F.[OrderLine_MemberId] AND
				--			sub.[Scenario_MemberId] = F.[Scenario_MemberId] AND
				--			sub.[OrderState_MemberId] = F.[OrderState_MemberId]'

				--EXEC (@SQLStatement)

				SET @SQLStatement = '
					INSERT INTO #CurrentOrderState
						(
						[Entity_MemberId],
						[OrderNo_MemberId],
						[OrderLine_MemberId],
						[Scenario_MemberId],
						[OrderState_MemberId],
						[CurrentOrderState_MemberId]
						)
					SELECT DISTINCT
						[Entity_MemberId] = F.[Entity_MemberId],
						[OrderNo_MemberId] = F.[OrderNo_MemberId],
						[OrderLine_MemberId] = F.[OrderLine_MemberId],
						[Scenario_MemberId] = F.[Scenario_MemberId],
						[OrderState_MemberId] = F.[OrderState_MemberId],
						[CurrentOrderState_MemberId] = CASE WHEN sub.OrderNo_MemberId IS NOT NULL THEN 101 ELSE 100 END
					FROM
						' + @CallistoDatabase + '.dbo.FACT_Sales_default_partition F
						INNER JOIN #OrderState_wrk OS ON
							OS.[Entity_MemberId] = F.[Entity_MemberId] AND 
							OS.[OrderNo_MemberId] = F.[OrderNo_MemberId] AND 
							OS.[OrderLine_MemberId] = F.[OrderLine_MemberId] AND
							OS.[Scenario_MemberId] = F.[Scenario_MemberId]
						LEFT JOIN #Sales_Sub sub ON	
							sub.[Entity_MemberId] = F.[Entity_MemberId] AND
							sub.[OrderNo_MemberId] = F.[OrderNo_MemberId] AND
							sub.[OrderLine_MemberId] = F.[OrderLine_MemberId] AND
							sub.[Scenario_MemberId] = F.[Scenario_MemberId] AND
							sub.[OrderState_MemberId] = F.[OrderState_MemberId]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT Step = 'Insert into #CurrentOrderState', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [@FromRowID] = @FromRowID

				SET @StepStartTime = GETDATE()

				SET @SQLStatement = '
					UPDATE F
					SET
						[CurrentOrderState_MemberId] = [COS].[CurrentOrderState_MemberId]
					FROM
						' + @CallistoDatabase + '.dbo.FACT_Sales_default_partition F
						INNER JOIN #CurrentOrderState [COS] ON	
							[COS].[Entity_MemberId] = F.[Entity_MemberId] AND
							[COS].[OrderNo_MemberId] = F.[OrderNo_MemberId] AND
							[COS].[OrderLine_MemberId] = F.[OrderLine_MemberId] AND
							[COS].[Scenario_MemberId] = F.[Scenario_MemberId] AND
							[COS].[OrderState_MemberId] = F.[OrderState_MemberId]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @StepUpdated = @@ROWCOUNT
				SET @Updated = @Updated + @StepUpdated

				IF @DebugBM & 2 > 0 SELECT Step = 'SET CurrentOrderState', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [@FromRowID] = @FromRowID

				IF @DebugBM & 2 > 0
					BEGIN
						SELECT
							StepCounter = @StepCounter,
							FromRowID = @FromRowID,
							ToRowID = @FromRowID + @StepSize - 1,
							MaxRowID = @MaxRowID,
							StepsLeft = CEILING(CONVERT(float, (@MaxRowID - (@FromRowID + @StepSize - 1))) / CONVERT(float, @StepSize)),
							StepUpdated = @StepUpdated,
							StepDuration = CONVERT(time(3), GetDate() - @LoopStartTime),
							TotalUpdated = @Updated,
							TotalDuration = CONVERT(time(3), GetDate() - @StartTime)
						RAISERROR ('', 0, 10) WITH NOWAIT
					END

				SET @FromRowID = @FromRowID + @StepSize
			END

	SET @Step = 'Drop INDEX in Sales FACT table'
		SET @SQLStatement = '
			EXEC ' + @CallistoDatabase + '.[dbo].sp_executesql N''DROP INDEX dbo.[FACT_Sales_default_partition].[IX_Sales_OrderState]'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0 DROP TABLE #OrderState
		DROP TABLE #OrderState_wrk
		DROP TABLE #Sales_Sub

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
