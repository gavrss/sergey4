SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Fact_Sales_CurrentOrderState] 

	@SourceID int = NULL,
	@ProcedureName nvarchar(100) = '' OUT,
	@StepSize int = 5000,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug int = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--

--EXEC [spCreate_Fact_Sales_CurrentOrderState] @SourceID = 104, @StepSize = 6000, @Debug = 1

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@InstanceID int,
	@ApplicationID int,
	@LanguageID int,
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLStatement_Action nvarchar(1000),
	@Action nvarchar(10),
	@SourceID_varchar nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2109'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2093' SET @Description = 'Procedure created'
		IF @Version = '1.3.2094' SET @Description = 'Looping introduced'
		IF @Version = '1.3.2109' SET @Description = 'Filter on Actual only. Using Fixed MemberIds to increase performance.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID IS NULL
	BEGIN
		PRINT 'Parameter @SourceID must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SET @SourceID_varchar = CASE WHEN @SourceID <= 9 THEN '000' ELSE CASE WHEN @SourceID <= 99 THEN '00' ELSE CASE WHEN @SourceID <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, @SourceID)

		SELECT
			@InstanceID = A.InstanceID,
			@ApplicationID = A.ApplicationID,
			@ETLDatabase = A.ETLDatabase,
			@DestinationDatabase = A.DestinationDatabase,
			@LanguageID = A.LanguageID
		FROM
			Source S
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
			INNER JOIN [Language] L ON L.LanguageID = A.LanguageID
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & 8 > 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
		WHERE
			S.SourceID = @SourceID AND
			S.SelectYN <> 0

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Check necessity of the procedure'
		CREATE TABLE #Counter ([Counter] int)
		SET @SQLStatement = '
		INSERT INTO #Counter ([Counter]) SELECT [Counter] = COUNT(1) FROM ' + @ETLDatabase + '..MappedObject WHERE ObjectName = ''CurrentOrderState'' AND ObjectTypeBM & 2 > 0 AND ModelBM & 8 > 0 AND SelectYN <> 0'
		EXEC (@SQLStatement)

		IF (SELECT [Counter] FROM #Counter) <> 1 OR @ApplicationID IS NULL
			BEGIN
				DROP TABLE #Counter
				RETURN
			END

	SET @Step = 'Create temp table #Action'
		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Set @SQLStatement'
		SET @SQLStatement = '

	@JobID int = 0,
	@SpeedRunYN bit = 1, --0 = Set all rows, 1 = Only set rows involved in the last load
	@StepSize int = ' + CONVERT(nvarchar(50), @StepSize) + ',
	@Rows int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

	AS 

--EXEC [spIU_' + @SourceID_varchar + '_FACT_€£Sales£€_€£CurrentOrderState£€] @SpeedRunYN = 0, @StepSize = 5000, @Debug = 1
--EXEC [spIU_' + @SourceID_varchar + '_FACT_€£Sales£€_€£CurrentOrderState£€] @SpeedRunYN = 1, @StepSize = 10000, @Debug = 1

DECLARE
	@StartTime datetime,
	@StepStartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@FromRowID int = 0,
	@MaxRowID int,
	@StepCounter int = 0,
	@StepUpdated int = 0,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()
		SET DATEFIRST 1
		
	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)'

		SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create temp tables''''
		CREATE TABLE #€£OrderState£€
			(
			[RowID] [int] IDENTITY(1,1) NOT NULL,
			[€£Entity£€_MemberID] [bigint] NOT NULL,
			[€£OrderNo£€_MemberID] [bigint] NOT NULL,
			[€£OrderLine£€_MemberId] [bigint] NOT NULL,
		CONSTRAINT [PK_#€£OrderState£€] PRIMARY KEY CLUSTERED 
			(
			[RowID] ASC
			))

		CREATE TABLE #€£OrderState£€_wrk
			(
			[€£Entity£€_MemberID] [bigint] NOT NULL,
			[€£OrderNo£€_MemberID] [bigint] NOT NULL,
			[€£OrderLine£€_MemberId] [bigint] NOT NULL,
		CONSTRAINT [PK_#€£OrderState£€_wrk] PRIMARY KEY CLUSTERED 
			(
			[€£Entity£€_MemberID] ASC,
			[€£OrderNo£€_MemberID] ASC,
			[€£OrderLine£€_MemberId] ASC
			))

	SET @Step = ''''Fill temp table''''
		INSERT INTO #€£OrderState£€
			(
			€£Entity£€_MemberID,
			€£OrderNo£€_MemberID,
			€£OrderLine£€_MemberId
			)
		SELECT
			€£Entity£€_MemberID,
			€£OrderNo£€_MemberID,
			€£OrderLine£€_MemberId
		FROM
			' + @DestinationDatabase + '.dbo.FACT_€£Sales£€_default_partition
		WHERE
			(€£CurrentOrderState£€_MemberId = -1 OR @SpeedRunYN = 0) AND
			€£Scenario£€_MemberId = 110
		GROUP BY
			€£Entity£€_MemberID,
			€£OrderNo£€_MemberID,
			€£OrderLine£€_MemberId

		SELECT @MaxRowID = MAX(RowID) FROM #€£OrderState£€

		--IF @Debug <> 0 SELECT * FROM #€£OrderState£€'

		SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Update €£CurrentOrderState£€''''
		WHILE @FromRowID < @MaxRowID
			BEGIN
				SET @StepStartTime = GETDATE()
				SET @StepCounter = @StepCounter + 1

				TRUNCATE TABLE #€£OrderState£€_wrk

				INSERT INTO #€£OrderState£€_wrk
					(
					€£Entity£€_MemberID,
					€£OrderNo£€_MemberID,
					€£OrderLine£€_MemberId
					)
				SELECT 
					€£Entity£€_MemberID,
					€£OrderNo£€_MemberID,
					€£OrderLine£€_MemberId
				FROM
					#€£OrderState£€
				WHERE
					RowID BETWEEN @FromRowID AND @FromRowID + @StepSize - 1'

/*
				UPDATE F
				SET
					€£CurrentOrderState£€_MemberId = CuOS.MemberId
				FROM
					' + @DestinationDatabase + '.dbo.FACT_€£Sales£€_default_partition F
					INNER JOIN #€£OrderState£€_wrk OSw ON OSw.€£Entity£€_MemberID = F.€£Entity£€_MemberID AND OSw.€£OrderNo£€_MemberID = F.€£OrderNo£€_MemberID AND OSw.€£OrderLine£€_MemberId = F.€£OrderLine£€_MemberId 
					LEFT JOIN ' + @DestinationDatabase + '.dbo.S_DS_€£OrderState£€ OS ON OS.MemberId = F.€£OrderState£€_MemberId
					LEFT JOIN 
						(SELECT
							F.€£Entity£€_MemberId,
							F.€£OrderNo£€_MemberId,
							F.€£OrderLine£€_MemberId,
							€£OrderState£€ = MAX(€£OrderState£€.Label) 
						FROM
							' + @DestinationDatabase + '.dbo.FACT_€£Sales£€_default_partition F
							INNER JOIN #€£OrderState£€_wrk OSw ON OSw.€£Entity£€_MemberID = F.€£Entity£€_MemberID AND OSw.€£OrderNo£€_MemberID = F.€£OrderNo£€_MemberID AND OSw.€£OrderLine£€_MemberId = F.€£OrderLine£€_MemberId 
							INNER JOIN ' + @DestinationDatabase + '.dbo.S_DS_€£TimeDay£€ [€£TimeDay£€] ON [€£TimeDay£€].MemberId = F.€£TimeDay£€_MemberId
							LEFT JOIN ' + @DestinationDatabase + '.dbo.S_DS_€£OrderState£€ €£OrderState£€ ON €£OrderState£€.MemberId = F.€£OrderState£€_MemberId
						WHERE
							(([€£TimeDay£€].Label <= CONVERT(nvarchar(50), GetDate(), 112) AND €£OrderState£€.Label = ''''70'''') OR
							€£OrderState£€.Label NOT IN (''''70''''))  AND
							F.€£Scenario£€_MemberId = 110
						GROUP BY
							F.€£Entity£€_MemberId,
							F.€£OrderNo£€_MemberId,
							F.€£OrderLine£€_MemberId
						) sub ON	sub.€£Entity£€_MemberId = F.€£Entity£€_MemberId AND
									sub.€£OrderNo£€_MemberId = F.€£OrderNo£€_MemberId AND
									sub.€£OrderLine£€_MemberId = F.€£OrderLine£€_MemberId AND
									sub.€£OrderState£€ = OS.Label -- OS.Label is the €£OrderState£€
					INNER JOIN ' + @DestinationDatabase + '.dbo.S_DS_€£CurrentOrderState£€ CuOS ON CuOS.Label = CASE WHEN sub.€£OrderNo£€_MemberId IS NOT NULL THEN ''''TRUE'''' ELSE ''''FALSE'''' END
				WHERE
					 F.€£Scenario£€_MemberId = 110
*/

		SET @SQLStatement = @SQLStatement + '

				UPDATE F
				SET
					€£CurrentOrderState£€_MemberId = CASE WHEN sub.€£OrderNo£€_MemberId IS NOT NULL THEN 101 ELSE 100 END
				FROM
					' + @DestinationDatabase + '.dbo.FACT_€£Sales£€_default_partition F
					INNER JOIN #€£OrderState£€_wrk OSw ON OSw.€£Entity£€_MemberID = F.€£Entity£€_MemberID AND OSw.€£OrderNo£€_MemberID = F.€£OrderNo£€_MemberID AND OSw.€£OrderLine£€_MemberId = F.€£OrderLine£€_MemberId 
					LEFT JOIN 
						(SELECT
							F.€£Entity£€_MemberId,
							F.€£OrderNo£€_MemberId,
							F.€£OrderLine£€_MemberId,
							€£OrderState£€_MemberId = MAX(F.€£OrderState£€_MemberId)
						FROM
							' + @DestinationDatabase + '.dbo.FACT_€£Sales£€_default_partition F
							INNER JOIN #€£OrderState£€_wrk OSw ON OSw.€£Entity£€_MemberID = F.€£Entity£€_MemberID AND OSw.€£OrderNo£€_MemberID = F.€£OrderNo£€_MemberID AND OSw.€£OrderLine£€_MemberId = F.€£OrderLine£€_MemberId 
							INNER JOIN ' + @DestinationDatabase + '.dbo.S_DS_€£TimeDay£€ [€£TimeDay£€] ON [€£TimeDay£€].MemberId = F.€£TimeDay£€_MemberId
						WHERE
							(([€£TimeDay£€].Label <= CONVERT(nvarchar(50), GetDate(), 112) AND F.€£OrderState£€_MemberID = 170) OR
							F.€£OrderState£€_MemberID NOT IN (170))  AND
							F.€£Scenario£€_MemberId = 110
						GROUP BY
							F.€£Entity£€_MemberId,
							F.€£OrderNo£€_MemberId,
							F.€£OrderLine£€_MemberId
						) sub ON	sub.€£Entity£€_MemberId = F.€£Entity£€_MemberId AND
									sub.€£OrderNo£€_MemberId = F.€£OrderNo£€_MemberId AND
									sub.€£OrderLine£€_MemberId = F.€£OrderLine£€_MemberId AND
									sub.€£OrderState£€_MemberId = F.€£OrderState£€_MemberId
				WHERE
					 F.€£Scenario£€_MemberId = 110

				SET @StepUpdated = @@ROWCOUNT
				SET @Updated = @Updated + @StepUpdated'

		SET @SQLStatement = @SQLStatement + '

				IF @Debug <> 0
					BEGIN
						SELECT
							StepCounter = @StepCounter,
							FromRowID = @FromRowID,
							ToRowID = @FromRowID + @StepSize - 1,
							MaxRowID = @MaxRowID,
							StepsLeft = CEILING(CONVERT(float, (@MaxRowID - (@FromRowID + @StepSize - 1))) / CONVERT(float, @StepSize)),
							StepUpdated = @StepUpdated,
							StepDuration = CONVERT(time(3), GetDate() - @StepStartTime),
							TotalUpdated = @Updated,
							TotalDuration = CONVERT(time(3), GetDate() - @StartTime)
						RAISERROR ('''''''', 0, 10) WITH NOWAIT
					END

				SET @FromRowID = @FromRowID + @StepSize

			END

	SET @Step = ''''Drop temp tables''''
		DROP TABLE #OrderState
		DROP TABLE #OrderState_wrk

	SET @Step = ''''Set @Duration''''
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
				
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

	SET @Step = 'CREATE PROCEDURE'
		SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_FACT_€£Sales£€_€£CurrentOrderState£€'
		EXEC spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @ProcedureName, @StringOut = @ProcedureName OUTPUT

		SET @SQLStatement_Action = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement_Action)
		SELECT @Action = [Action] FROM #Action

		IF @Debug <> 0 SELECT [SQLStatement_Action] = @SQLStatement_Action, [Action] = @Action

		SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ProcedureName + ']' + @SQLStatement
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

		EXEC spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of Procedure', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)

	SET @Step = 'Drop temporary tables'	
		DROP TABLE #Action
		DROP TABLE #Counter

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH






GO
