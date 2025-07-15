SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_ETL_BudgetSelection] 

	@SourceID int = NULL,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@ProcedureName nvarchar(100) = NULL OUT,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC spCreate_ETL_BudgetSelection @SourceID = 1147, @Debug = true --E10.1 Financials Linked
--EXEC spCreate_ETL_BudgetSelection @SourceID = -1055, @Debug = true --E10 Cloud demo
DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SQLSourceStatement nvarchar(max),
	@Action nvarchar(10),
	@InstanceID int,
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(50),
	@SourceID_varchar nvarchar(10),
	@ViewName nvarchar(50),
	@SourceTypeID int,
	@Owner nvarchar(50),
	@RevisionBM int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2073' SET @Description = 'Procedure created.'
		IF @Version = '1.3.2075' SET @Description = 'SourceID added.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2104' SET @Description = 'Added iScala'
		IF @Version = '1.4.0.2139' SET @Description = 'Brackets around object names'

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

		SET @SourceID_varchar = CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID))

		SELECT
			@InstanceID = A.InstanceID,
			@SourceTypeID = S.SourceTypeID,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = A.ETLDatabase
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN Model M ON M.ModelID = S.ModelID
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
		WHERE
			SourceID = @SourceID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		EXEC [spGet_Owner] @SourceTypeID, @Owner OUTPUT
		EXEC [spGet_Revision] @SourceID = @SourceID, @RevisionBM = @RevisionBM OUT

	SET @Step = 'CREATE VIEW'
		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

		SET @ViewName = 'vw_' + @SourceID_varchar + '_ETL_BudgetSelection'

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ViewName + '''' + ', ' + '''V''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
		SELECT @Action = [Action] FROM #Action
		TRUNCATE TABLE #Action

		IF (@SourceTypeID = 11 AND @RevisionBM & 2 > 0) OR @SourceTypeID = 3  --Epicor 10.1 or iScala
			BEGIN
				IF @SourceTypeID = 11 --Epicor 10.1
					SET @SQLStatement = '
	SELECT
		SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ',
		EntityCode = Company COLLATE DATABASE_DEFAULT,
		BudgetCode = BudgetCodeID COLLATE DATABASE_DEFAULT,
		Scenario = BudgetCodeID COLLATE DATABASE_DEFAULT + ''''_ERP'''',
		SelectYN = 0
	FROM
		' + @SourceDatabase + '.[' + @Owner + '].BudgetCode BC'

				ELSE IF @SourceTypeID = 3 --iScala
					SET @SQLStatement = '
	SELECT DISTINCT
		[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ',
		[EntityCode] = E.EntityCode,
		[BudgetCode] = TTi.Scenario,
		[Scenario] = TTi.Scenario + ''''_ERP'''',
		[SelectYN] = TTi.SelectYN
	FROM
		' + @ETLDatabase + '.[dbo].[TransactionType_iScala] TTi
		INNER JOIN ' + @ETLDatabase + '.[dbo].Entity E ON E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND E.SelectYN <> 0
	WHERE
		TTi.Scenario <> ''''Actual'''' AND
		TTi.Symbol IN (''''U'''', ''''V'''', ''''W'''', ''''X'''', ''''Y'''', ''''Z'''')'

	SET @Step = 'Create View'
		SET @SQLStatement = @Action + ' VIEW [dbo].[' + @ViewName + '] 
	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
	AS ' + @SQLStatement

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

		EXEC (@SQLStatement)

		IF @Debug <> 0
		  BEGIN
			PRINT @SQLStatement
			EXEC ('SELECT * FROM [' + @ETLDatabase + '].[dbo].[' + @ViewName + ']')
		  END

	SET @Step = 'Create Source statement for procedure'

	SET @SQLSourceStatement = '
	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = ''''Insert into table BudgetSelection''''
		INSERT INTO BudgetSelection
			(
			SourceID,
			EntityCode,
			BudgetCode,
			Scenario,
			SelectYN
			)
		SELECT
			SourceID,
			EntityCode,
			BudgetCode,
			Scenario,
			SelectYN
		FROM
			[' + @ViewName + '] V
		WHERE
			NOT EXISTS (SELECT 1 FROM BudgetSelection BS WHERE BS.SourceID = V.SourceID AND BS.EntityCode = V.EntityCode AND BS.BudgetCode = V.BudgetCode)

		SET @Inserted = @Inserted + @@ROWCOUNT
		
		SET ANSI_WARNINGS OFF'


SET @Step = 'CREATE PROCEDURE'
--------------------
SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_ETL_BudgetSelection'

--Determine CREATE or ALTER
SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
SELECT @Action = [Action] FROM #Action
DROP TABLE #Action

SET @SQLStatement = '
SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@LinkedYN bit,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

' + @SQLSourceStatement + '

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

	SET @Step = 'Make Creation statement'
		SET @ProcedureName = '[' + @ProcedureName + ']'
		SET @SQLStatement = @Action + ' PROCEDURE [dbo].' + @ProcedureName + '

	@JobID int = 0,
	@SourceID int = ''''' + CONVERT(nvarchar, @SourceID) + ''''',
	@Rows int = NULL,
	@GetVersion bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

	AS' + CHAR(13) + CHAR(10) + @SQLStatement

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

		IF @Debug <> 0 PRINT @SQLStatement

		EXEC (@SQLStatement)
	END

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + @SourceID_varchar + ')', @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + @SourceID_varchar + ')', GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH













GO
