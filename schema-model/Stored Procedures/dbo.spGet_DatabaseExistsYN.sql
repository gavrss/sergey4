SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_DatabaseExistsYN]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DatabaseName nvarchar(100) = NULL, --Mandatory
	@ExistsYN bit = NULL OUT,
	@SetJobLogYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000747,
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
EXEC spGet_DatabaseExistsYN @DatabaseName = '[iScala01].[iScala01]', @Debug=1
EXEC spGet_DatabaseExistsYN @DatabaseName = '[iScala01]', @Debug=1
EXEC spGet_DatabaseExistsYN @DatabaseName = 'DSPSOURCE01.[pcSource_E5IP]', @DebugBM=1
EXEC spGet_DatabaseExistsYN @DatabaseName = '[pcSource_E5IP]', @DebugBM=1
EXEC spGet_DatabaseExistsYN @DatabaseName = 'DSPSOURCE01.[pcSource_E2IP]', @DebugBM=1

EXEC [spGet_DatabaseExistsYN] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@RowCount int,
	@SQLStatement nvarchar(max),
	@ServerName nvarchar(100),
	@DotPosition int,

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
	@Version nvarchar(50) = '2.1.1.2169'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Check existence of specific database',
			@MandatoryParameter = 'DatabaseName' --Without @, separated by |

		IF @Version = '2.1.0.2165' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle more cases. Modified query in setting @DatabaseName.'
		IF @Version = '2.1.1.2169' SET @Description = 'Avoid running sp_executesql on remote (linked) server. Added parameter @SetJobLogYN, defaulted to 0.'

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

		IF CHARINDEX('.', @DatabaseName) <> 0
			BEGIN
				SELECT @DotPosition = CHARINDEX('.', @DatabaseName)
				IF @DebugBM & 2 > 0 SELECT [@DotPosition] = @DotPosition
				SET @ServerName = LEFT(@DatabaseName, @DotPosition - 1)
				SET @DatabaseName = SUBSTRING(@DatabaseName, @DotPosition + 1, LEN(@DatabaseName) - @DotPosition)
				SET @ServerName = REPLACE(REPLACE(REPLACE(@ServerName, '[', ''), ']', ''), '.', '')
			END

		SET @DatabaseName = REPLACE(REPLACE(REPLACE(@DatabaseName, '[', ''), ']', ''), '.', '')

		IF @DebugBM & 2 > 0
			SELECT
				[@ServerName] = @ServerName,
				[@DatabaseName] = @DatabaseName

	SET @Step = 'Check server existence'
		IF @ServerName IS NOT NULL
			BEGIN
				SELECT @ExistsYN = COUNT(1) FROM sys.servers WHERE [name] = @ServerName
				IF @ExistsYN = 0
					GOTO Result
			END

	SET @Step = 'Check table existence'
		IF @ServerName IS NULL
			SET @SQLStatement = '
				SELECT @InternalVariable = COUNT(1) FROM sys.databases WHERE [name] = ''' + @DatabaseName + ''''
		ELSE
			SET @SQLStatement = '
				SELECT @InternalVariable = COUNT(1) FROM [' + @ServerName + '].[' + @DatabaseName + '].sys.databases WHERE [name] = ''' + @DatabaseName + ''''
			
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ExistsYN OUT
END TRY

BEGIN CATCH
	SET @ExistsYN = 0
END CATCH

	SET @Step = 'Return result'
		Result:
		IF @DebugBM & 1 > 0 SELECT [@ExistsYN] = @ExistsYN
		
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

GO
