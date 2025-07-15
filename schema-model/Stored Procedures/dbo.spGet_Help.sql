SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Help]
(
	--Default parameter
	@JobID int = 0,
	@UserName	nvarchar(50) = NULL,
	@URL		nvarchar(255) = NULL,
	@Param		nvarchar(1000) = NULL,
	@PageCode   nvarchar(50) = NULL,
	@Debug		bit = 0,
	@GetVersion bit = 0
)

/*
	EXEC dbo.spGet_Help @UserName = 'bengt@jaxit.se', @Debug = 1, @URL = '/DrillPage/', @Param = '', @PageCode = 'Admin'
	EXEC dbo.spGet_Help @UserName = 'bengt@jaxit.se', @Debug = 1, @URL = '/DrillPage/', @Param = '', @PageCode = 'DrillPage'
	EXEC dbo.spGet_Help @UserName = 'bengt@jaxit.se', @Debug = 1, @URL = '/DrillPage/', @Param = '', @PageCode = 'EditColumnLink'
	EXEC dbo.spGet_Help @UserName = 'bengt@jaxit.se', @Debug = 1, @URL = '/DrillPage/', @Param = '', @PageCode = 'EditPage'
	EXEC dbo.spGet_Help @UserName = 'bengt@jaxit.se', @Debug = 1, @URL = '/DrillPage/', @Param = '', @PageCode = 'EditPageColumn'
	EXEC dbo.spGet_Help @UserName = 'bengt@jaxit.se', @URL = '/DrillPage/', @Param = '', @PageCode = 'GL', @Debug = 1
	EXEC dbo.spGet_Help @UserName = 'bengt@jaxit.se', @Debug = 1, @URL = '/Sie4', @Param = '', @PageCode = ''
	EXEC dbo.spGet_Help @UserName = 'bengt@jaxit.se', @Debug = 1, @URL = '', @Param = '', @PageCode = ''
*/	

--#WITH ENCRYPTION#--

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@DrillPageDatabase nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2114'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2112' SET @Description = 'Procedure created'
		IF @Version = '1.3.2114' SET @Description = 'Check existence of DrillPage DB.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserName IS NULL OR @URL IS NULL OR @Param IS NULL OR @PageCode IS NULL
	BEGIN
		PRINT 'Parameter @UserName, @URL, @Param and @PageCode must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT

		SELECT @DrillPageDatabase = Ext.ExtensionName FROM Extension Ext WHERE Ext.ExtensionTypeID = 50 AND Ext.SelectYN <> 0

		IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DrillPageDatabase) SET @DrillPageDatabase = NULL

		IF @Debug <> 0 SELECT DrillPageDatabase = @DrillPageDatabase

	SET @Step = 'Get Help URL'
		IF @URL LIKE '%/DrillPage/%'
			IF @DrillPageDatabase IS NULL
				SELECT 
					HeaderCaption = 'DrillPage',
					Instruction = 'The DrillPage database is not created.',
					HelpLink = 'http://www.docu-pc.com/pc2/doku.php?id=pcdrillpage:start',
					[Version] = @Version
			ELSE
				BEGIN
					SET @SQLStatement = '
						EXEC ' + @DrillPageDatabase + '.dbo.spGet_Help @UserName = ''' + @UserName + ''', @PageCode = ''' + @PageCode + ''', @Version = ''' + @Version + ''', @Debug = ' + CONVERT(nvarchar(10), CONVERT(int, @Debug))
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
				END

		ELSE IF @URL LIKE '%/Sie4%'
			SELECT 
				HeaderCaption = 'SIE4 file',
				Instruction = 'Upload SIE4 file',
				HelpLink = 'http://www.docu-pc.com/pc2/doku.php?id=pcfinancials:start',
				[Version] = @Version
		ELSE
			SELECT 
				HeaderCaption = 'pcPortal',
				Instruction = 'Welcome to pcPortal',
				HelpLink = 'http://www.docu-pc.com/pc2/doku.php?id=pcfinancials:start',
				[Version] = @Version

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH



GO
