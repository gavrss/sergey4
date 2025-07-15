SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_ETL_CheckSum]

	@ApplicationID int = NULL,
	@Debug bit = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--EXEC [spInsert_ETL_CheckSum] @ApplicationID = 400, @Debug = true

--#WITH ENCRYPTION#--
AS

DECLARE	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@InstanceID int,
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@ModelBM int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2135'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.2073' SET @Description = 'Shows result in the end.'
		IF @Version = '1.3.2106' SET @Description = 'Added CheckSumDescription and CheckSumReport.'
		IF @Version = '1.4.0.2128' SET @Description = 'Added Parameter replacement for @ETLDatabase and @DestinationDatabase.'
		IF @Version = '1.4.0.2130' SET @Description = 'Added reference to SqlQuery.'
		IF @Version = '1.4.0.2135' SET @Description = 'Use table MailMessage instead of CheckSumSystem.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

-- This SP is obsolete.  CheckSum should be handle by pcINTEGRATOR.
RETURN
 
IF @ApplicationID IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID must be set'
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

		SELECT
			@InstanceID = A.InstanceID,
			@ETLDatabase = A.ETLDatabase,
			@DestinationDatabase = A.DestinationDatabase
		FROM
			[Application] A 
		WHERE
			 A.ApplicationID = @ApplicationID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		SELECT 
			@ModelBM = SUM(sub.ModelBM)
		FROM
			(
			SELECT DISTINCT
				BM.ModelBM
			FROM
				Model M 
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
			WHERE
				M.ApplicationID = @ApplicationID AND
				M.SelectYN <> 0
			) sub
		OPTION (MAXDOP 1)

	SET @Step = 'Insert into MailMessage'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[MailMessage]
			(
			[InstanceID],
			[ApplicationID],
			[UserPropertyTypeID],
			[Subject],
			[Body],
			[Importance]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[ApplicationID] = @ApplicationID,
			[UserPropertyTypeID] = MM.[UserPropertyTypeID],
			[Subject] = MM.[Subject],
			[Body] = MM.[Body],
			[Importance] = MM.[Importance]
		FROM
			[pcINTEGRATOR_Data].[dbo].[MailMessage] MM
		WHERE
			MM.[InstanceID] = 0 AND
			MM.[ApplicationID] = 0 AND
			MM.[UserPropertyTypeID] IN (-5, -6) AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[MailMessage] MM1 WHERE MM1.ApplicationID = @ApplicationID AND MM1.[UserPropertyTypeID] = MM.[UserPropertyTypeID])
		OPTION (MAXDOP 1)

	SET @Step = 'Insert into CheckSum'
		SET @SQLStatement = '
			INSERT INTO [' + @ETLDatabase + '].[dbo].[CheckSum]
				(
				[CheckSumName],
				[CheckSumDescription],
				[CheckSumQuery],
				[CheckSumReport],
				[SortOrder]
				)
			SELECT 
				[CheckSumName],
				[CheckSumDescription],
				[CheckSumQuery] = REPLACE(REPLACE (CS.CheckSumQuery, ''@DestinationDatabase'', ''' + @DestinationDatabase + '''), ''@ETLDatabase'', ''' + @ETLDatabase + '''),
				[CheckSumReport] = REPLACE(CS.CheckSumReport, ''@RefID'', ISNULL(SQ.SqlQueryID, '''')),
				[SortOrder]
			FROM
				CheckSum CS
				LEFT JOIN (SELECT RefID, SqlQueryID = MAX(SqlQueryID) FROM SqlQuery WHERE InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND RefID IS NOT NULL GROUP BY RefId) SQ ON SQ.RefID = CS.RefID
			WHERE
				CS.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0  AND 
				CS.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[CheckSum] d WHERE d.CheckSumName = CS.CheckSumName)
			ORDER BY
				CS.SortOrder
			OPTION (MAXDOP 1)'

			IF @Debug <> 0 PRINT @SQLStatement
	
			EXEC (@SQLStatement)

			SET @Inserted = @Inserted + @@ROWCOUNT

			SET @SQLStatement = 'SELECT * FROM [' + @ETLDatabase + '].[dbo].[CheckSum] OPTION (MAXDOP 1)'
			EXEC (@SQLStatement)

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
