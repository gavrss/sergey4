SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_FiscalYear]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,	--Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000595,
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
EXEC [spSetup_FiscalYear] @UserID = -10, @InstanceID = 52, @VersionID = 1035, @SourceTypeID = 11, @DebugBM=7
EXEC [spSetup_FiscalYear] @UserID=-10, @InstanceID=15, @VersionID=1039, @SourceTypeID = 11, @DebugBM=1

EXEC [spSetup_FiscalYear] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@FiscalYearStartMonthSetYN bit,
	@FiscalYearNamingSetYN bit,
	@FiscalYearNaming int,
	@FiscalYearStartMonth int,

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
	@Version nvarchar(50) = '2.1.0.2165'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup parameters for FiscalYear',
			@MandatoryParameter = 'SourceTypeID' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'

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
			@FiscalYearStartMonthSetYN = [FiscalYearStartMonthSetYN],
			@FiscalYearNamingSetYN = [FiscalYearNamingSetYN],
			@FiscalYearNaming = [FiscalYearNaming],
			@FiscalYearStartMonth = [FiscalYearStartMonth]
		FROM
			[pcINTEGRATOR_Data]..[Instance]
		WHERE
			[InstanceID] = @InstanceID

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceTypeID] = @SourceTypeID,
				[@FiscalYearStartMonthSetYN] = @FiscalYearStartMonthSetYN,
				[@FiscalYearNamingSetYN] = @FiscalYearNamingSetYN,
				[@FiscalYearNaming] = @FiscalYearNaming,
				[@FiscalYearStartMonth] = @FiscalYearStartMonth,
				[@JobID] = @JobID

	SET @Step = 'Temp table #Entity_FiscalYear'
		CREATE TABLE #Entity_FiscalYear
			(
			[EntityID] int,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[StartMonth] int,
			[EndMonth] int
			)

	SET @Step = 'Call sub routine to get parameters and fill table #Entity_FiscalYear'		
		IF @SourceTypeID IN (1, 11) --Epicor ERP
			EXEC [spSetup_FiscalYear_EpicorERP]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@SourceTypeID=@SourceTypeID,
				@FiscalYearNaming = @FiscalYearNaming OUT,
				@FiscalYearStartMonth = @FiscalYearStartMonth OUT,
				@JobID=@JobID,
				@Debug=@DebugSub
	
	SET @Step = 'Update Instance and Application'
		UPDATE I
		SET
			[FiscalYearNaming] = CASE WHEN I.[FiscalYearNamingSetYN] = 0 THEN @FiscalYearNaming ELSE I.[FiscalYearNaming] END,
			[FiscalYearStartMonth] = CASE WHEN I.[FiscalYearStartMonthSetYN] = 0 THEN @FiscalYearStartMonth ELSE I.[FiscalYearStartMonth] END
		FROM
			[pcINTEGRATOR_Data].[dbo].[Instance] I
		WHERE
			I.[InstanceID] = @InstanceID

		UPDATE A
		SET
			[FiscalYearStartMonth] = I.[FiscalYearStartMonth]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Instance] I ON I.[InstanceID] = A.[InstanceID]
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

	SET @Step = 'Update [pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear]'
		DELETE EFY
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear] EFY
			INNER JOIN #Entity_FiscalYear TEFY ON TEFY.[EntityID] = EFY.[EntityID] AND TEFY.[Book] = EFY.[Book]
		WHERE
			EFY.[InstanceID] = @InstanceID AND
			EFY.[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear]
			(
			[InstanceID],
			[VersionID],
			[EntityID],
			[Book],
			[StartMonth],
			[EndMonth]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[EntityID],
			[Book],
			[StartMonth],
			[EndMonth]
		FROM
			#Entity_FiscalYear

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return information'
		IF @DebugBM & 1 > 0 
			BEGIN
				SELECT 
					[@FiscalYearNaming] = @FiscalYearNaming,
					[@FiscalYearStartMonth] = @FiscalYearStartMonth

				SELECT
					[Table] = 'pcINTEGRATOR_Data..Entity_FiscalYear',
					EFY.* 
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear] EFY 
				WHERE
					EFY.[InstanceID] = @InstanceID AND EFY.[VersionID] = @VersionID
				ORDER BY
					[EntityID],
					[Book],
					[StartMonth]
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
