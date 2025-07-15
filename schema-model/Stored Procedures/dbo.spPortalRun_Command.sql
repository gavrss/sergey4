SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalRun_Command]

@UserID int = NULL,
@InstanceID int = NULL,
@CommandID int = NULL,
@JobID int = 0,
@GetVersion bit = 0,
@Duration time(7) = '00:00:00' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT,
@Debug bit = 0

--#WITH ENCRYPTION#--

AS

--SET ANSI_WARNINGS OFF  --Must be SET ON to handle heterogeneous queries

--EXEC [spPortalRun_Command] @UserID = 1005, @InstanceID = 357, @CommandID = 1001, @Debug = 1
--EXEC [spPortalRun_Command] @GetVersion = 1				

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@DatabaseName nvarchar(100),
	@Command nvarchar(255),
	@SQLStatement nvarchar(max),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2135'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2135' SET @Description = 'Procedure created'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL OR @CommandID IS NULL
	BEGIN
		SET @Message = 'Parameter @UserID, @InstanceID and @CommandID must be set.'
		SET @Severity = 16
		RAISERROR (@Message, @Severity, 100)
		RETURN
	END

SET @Step = 'Set @StartTime'
	SET @StartTime = GETDATE()

SET @Step = 'Set procedure variables'
	SELECT
		@Deleted = ISNULL(@Deleted, 0),
		@Inserted = ISNULL(@Inserted, 0),
		@Updated = ISNULL(@Updated, 0)

SET @Step = 'EXEC RemoteCall'
	SELECT
		@DatabaseName = '[' + REPLACE(REPLACE(REPLACE(ISNULL(C.[DatabaseName], DB_NAME()), '[', ''), ']', ''), '.', '].[') + ']',
		@Command = '[' + REPLACE(REPLACE(REPLACE(C.[Command], '[', ''), ']', ''), '.', '].[') + ']'
	FROM
		[Command] C
	WHERE
		CommandID = @CommandID

	SET @SQLStatement = 'EXEC ' + @DatabaseName + '.[dbo].[sp_executesql] N''' + @Command + ''''

	IF @Debug <> 0 PRINT @SQLStatement

	EXEC (@SQLStatement)

SET @Step = 'Set @Duration'	
	SET @Duration = GetDate() - @StartTime

SET @Step = 'Insert into JobLog'
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version


GO
