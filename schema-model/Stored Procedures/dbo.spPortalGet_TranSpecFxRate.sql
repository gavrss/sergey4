SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_TranSpecFxRate]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@JournalSequence nvarchar(50) = NULL,
	@JournalNo nvarchar(50) = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000856,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spPortalGet_TranSpecFxRate]
	@UserID=-10,
	@InstanceID = 576,
	@VersionID = 1082,
	@Entity = '104',
	@Book = 'MAIN2',
	@FiscalYear = 2021,
	@FiscalPeriod = 2,
	@JournalSequence = 'GJ',
	@JournalNo = '2'

EXEC [spPortalGet_TranSpecFxRate] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@YearMonth int,

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2190'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Show rows from TranSpecFxRate',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2190' SET @Description = 'Procedure created.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SET @YearMonth = @FiscalYear * 100 + @FiscalPeriod ----Should be based on proper sub routine


	SET @Step = 'Create temp table #Groups'
		SELECT 
			[Group] = EG.MemberKey,
			[Currency_Book] = EB.Currency,
			[Currency_Group] = EBG.Currency
		INTO
			#Groups
		FROM
			[pcINTEGRATOR_Data].[dbo].[EntityHierarchy] EH
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = EH.InstanceID AND E.VersionID = EH.VersionID AND E.MemberKey = @Entity AND E.EntityID = EH.EntityID AND E.EntityTypeID = -1 AND E.SelectYN <> 0 AND E.DeletedID IS NULL
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.InstanceID = EH.InstanceID AND EB.VersionID = EH.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] EG ON EG.InstanceID = EH.InstanceID AND EG.VersionID = EH.VersionID AND EG.EntityID = EH.EntityGroupID AND EG.EntityTypeID = 0 AND EG.SelectYN <> 0 AND EG.DeletedID IS NULL
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EBG ON EBG.InstanceID = EH.InstanceID AND EBG.VersionID = EH.VersionID AND EBG.EntityID = EG.EntityID AND EBG.BookTypeBM & 16 > 0 AND EBG.SelectYN <> 0
		WHERE
			EH.InstanceID = @InstanceID AND
			EH.VersionID = @VersionID AND
			EH.ValidFrom <= GetDate() --Should be based on @YearMonth

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Groups', * FROM #Groups

	SET @Step = 'Calculate Fx rate'
		/*
		SELECT
			*
		FROM
			pcDATA_AXYZ..FACT_FxRate_View
		WHERE
			[Rate] = 'Average' AND
			[Time] = CONVERT(nvarchar(15), @YearMonth)
		*/

	SET @Step = 'Return valid rows'
		SELECT 
			G.*,
			[AvgRate] = 2.3, --To be calculated
			[TranSpecFxRate] = TSFR.[TranSpecFxRate]
		FROM
			#Groups G
			LEFT JOIN [pcINTEGRATOR_Data].[dbo].[BR05_TranSpecFxRate] TSFR ON
				TSFR.ConsolidationGroup = G.[Group] AND
				TSFR.InstanceID = @InstanceID AND
				TSFR.VersionID = @VersionID AND
				TSFR.Entity = @Entity AND
				TSFR.Book = @Book AND
				TSFR.FiscalYear = @FiscalYear AND
				TSFR.FiscalPeriod = @FiscalPeriod AND
				TSFR.JournalSequence = @JournalSequence AND
				TSFR.JournalNo = @JournalNo

	SET @Step = 'Drop temp tables'
		DROP Table #Groups

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
