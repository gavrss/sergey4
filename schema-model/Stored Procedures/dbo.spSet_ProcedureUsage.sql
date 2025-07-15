SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_ProcedureUsage]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SPUsageID int = NULL,
	@SPName nvarchar(100) = NULL,
	@Module nvarchar(50) = NULL,
	@Section nvarchar(50) = NULL,
	@Page nvarchar(50) = NULL,
	@Comment nvarchar(1024) = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000297,
	@Parameter nvarchar(4000) = NULL,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

AS

/*
--Select
EXEC [spSet_ProcedureUsage]
	@SPName = 'spPortalAdminGet_ScenarioList'

--Insert
EXEC [spSet_ProcedureUsage]
	@SPName = 'spPortalAdminGet_ScenarioList',
	@Module = 'pcPortal',
	@Section = 'Test',
	@Page = 'Test',
	@Comment = 'First try'

--Update
EXEC [spSet_ProcedureUsage]
	@SPUsageID = 1002,
	@SPName = 'spPortalAdminGet_ScenarioList',
	@Module = 'pcPortal',
	@Section = 'Test',
	@Page = 'Test',
	@Comment = 'Second try'

--Delete
EXEC [spSet_ProcedureUsage]
	@SPUsageID = 1003,
	@SPName = 'spPortalAdminGet_ScenarioList',
	@DeleteYN = 1

EXEC [spSet_ProcedureUsage] @GetVersion = 1
*/

DECLARE
	@SPID int,

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
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Documentation of where SPs are used.',
			@MandatoryParameter = 'SPName' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2173' SET @Description = 'Converted to new sp template.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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
		--EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT

		SELECT 
			@SPID = ProcedureID
		FROM
			[Procedure]
		WHERE
			[ProcedureName] = @SPName

	SET @Step = 'Insert row'
		IF @SPUsageID IS NULL AND @DeleteYN = 0 AND (@Module IS NOT NULL OR @Section IS NOT NULL OR @Page IS NOT NULL OR @Comment IS NOT NULL)
			BEGIN
				INSERT INTO [ProcedureUsage]
					(
					[ProcedureID],
					[Module],
					[Section],
					[Page],
					[Comment]
					)
				SELECT
					[ProcedureID] = @SPID,
					[Module] = @Module,
					[Section] = @Section,
					[Page] = @Page,
					[Comment] = @Comment

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Update row'
		IF @SPUsageID IS NOT NULL AND @DeleteYN = 0 AND (@Module IS NOT NULL OR @Section IS NOT NULL OR @Page IS NOT NULL OR @Comment IS NOT NULL)
			BEGIN
				UPDATE [ProcedureUsage]
				SET
					[ProcedureID] = @SPID,
					[Module] = @Module,
					[Section] = @Section,
					[Page] = @Page,
					[Comment] = @Comment
				WHERE
					ProcedureUsageID = @SPUsageID

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Delete row'
		IF @SPUsageID IS NOT NULL AND @DeleteYN <> 0
			BEGIN
				DELETE PU
				FROM
					[Procedure] P
					INNER JOIN ProcedureUsage PU ON PU.ProcedureID = P.ProcedureID
				WHERE
					P.ProcedureName = @SPName AND
					PU.ProcedureUsageID = @SPUsageID

				SET @Deleted = @Deleted + @@ROWCOUNT
			END

	SET @Step = 'Return rows'
		SELECT
			SPName = P.[ProcedureName],
			SPUsageID = PU.[ProcedureUsageID],
			[Module] = PU.[Module],
			[Section] = PU.[Section],
			[Page] = PU.[Page],
			[Comment] = PU.[Comment],
			[Updated] = PU.[Updated],
			[Version] = PU.[Version]
		FROM
			ProcedureUsage PU
			INNER JOIN [Procedure] P ON P.[ProcedureID] = PU.[ProcedureID]
		WHERE
			PU.[ProcedureID] = @SPID

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = 0, @InstanceID = 0, @VersionID = 0, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @Parameter = @Parameter, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = 0, @InstanceID = 0, @VersionID = 0, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @Parameter = @Parameter, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
