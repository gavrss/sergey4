SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_SIE4_StartJob]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@FLAGGA nvarchar(100) = NULL,
	@PROGRAM nvarchar(100) = NULL,
	@FORMAT nvarchar(100) = NULL,
	@GEN nvarchar(100) = NULL,
	@SIETYP nvarchar(100) = NULL,
	@PROSA nvarchar(100) = NULL,
	@FNR nvarchar(100) = NULL,
	@ORGNR nvarchar(100) = NULL,
	@BKOD nvarchar(100) = NULL,
	@ADRESS nvarchar(100) = NULL,
	@FNAMN nvarchar(100) = NULL,
	@RAR_0_FROM int = NULL,
	@RAR_0_TO int = NULL,
	@RAR_1_FROM int = NULL,
	@RAR_1_TO int = NULL,
	@TAXAR nvarchar(50) = NULL,
	@OMFATTN nvarchar(100) = NULL,
	@KPTYP nvarchar(50) = NULL,
	@VALUTA nchar(3) = NULL,
	@RowCountYN bit = 0,

	@JobID int = NULL OUT,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000176,
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
EXEC [spPortalSet_SIE4_StartJob] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @FNR = 'SE5566987300', @ORGNR = '556698-7300', @FNAMN = 'DSPanel AB', @RAR_0_FROM = 20160101, @RAR_0_TO = 20161231, @RowCountYN = 1, @Debug = 1
EXEC [spPortalSet_SIE4_StartJob] @UserID = 2109, @InstanceID = 404, @VersionID = 1003, @FNR = '000-7', @ORGNR = '556101-7582', @FNAMN = 'Garp (Jeeves Information Systems AB)', @RAR_0_FROM = 20170101, @RAR_0_TO = 20170331, @RowCountYN = 1, @Debug = 1
EXEC [spPortalSet_SIE4_StartJob] @UserID = 2109, @InstanceID = 404, @VersionID = 1003, @FNR = '000-7', @ORGNR = '556101-7582', @FNAMN = 'Garp (Jeeves Information Systems AB)', @RAR_0_FROM = 20170401, @RAR_0_TO = 20170630, @RowCountYN = 1, @Debug = 1
EXEC [spPortalSet_SIE4_StartJob] @UserID = 2109, @InstanceID = 404, @VersionID = 1003, @FNR = '000-7', @ORGNR = '556101-7582', @FNAMN = 'Garp (Jeeves Information Systems AB)', @RAR_0_FROM = 20170701, @RAR_0_TO = 20171231, @RowCountYN = 1, @Debug = 1

EXEC [spPortalSet_SIE4_StartJob] @UserID = 2109, @InstanceID = 404, @VersionID = 1003, @JobID = 324, @RowCountYN = 1, @Debug = 1

EXEC [spPortalSet_SIE4_StartJob] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@Entity_Source nvarchar(100),
	@Entity_MemberKey nvarchar(50),
	@SQLStatement nvarchar(max),
	@EntityID int,
	@MonthID int,
	@StartMonth int,
	@EndMonth int,
	@Entity_FiscalYearID int,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Start load of SIE4',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-194, DB-195: Change EntityID from 0 to real EntityID for EntityPropertyType = -6 on EntityPropertyValue table.'
		IF @Version = '2.1.1.2168' SET @Description = 'Adjusted primary keys for Entity and Entity _Book.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create Job'
		IF ISNULL(@JobID, 0) = 0
			BEGIN
				SET @JobID = NULL

				EXEC [spSet_Job]
					@UserID=@UserID, 
					@InstanceID=@InstanceID, 
					@VersionID=@VersionID, 
					@ActionType='Start', 
					@MasterCommand=@ProcedureName, 
					@CurrentCommand=@ProcedureName, 
					@JobQueueYN=0, 
					@CheckCount=0, 
					@JobListID=NULL,
					@JobID=@JobID OUT

	SET @Step = 'Insert into SIE4_Job'
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[SIE4_Job]
					(
					[UserID],
					[InstanceID],
					[VersionID],
					[JobID],
					[FLAGGA],
					[PROGRAM],
					[FORMAT],
					[GEN],
					[SIETYP],
					[PROSA],
					[FNR],
					[ORGNR],
					[BKOD],
					[ADRESS],
					[FNAMN],
					[RAR_0_FROM],
					[RAR_0_TO],
					[RAR_1_FROM],
					[RAR_1_TO],
					[TAXAR],
					[OMFATTN],
					[KPTYP],
					[VALUTA],
					[InsertedBy]
					)
				SELECT
					[UserID] = @UserID,
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[JobID] = @JobID,
					[FLAGGA] = @FLAGGA,
					[PROGRAM] = @PROGRAM,
					[FORMAT] = @FORMAT,
					[GEN] = @GEN,
					[SIETYP] = @SIETYP,
					[PROSA] = @PROSA,
					[FNR] = @FNR,
					[ORGNR] = @ORGNR,
					[BKOD] = @BKOD,
					[ADRESS] = @ADRESS,
					[FNAMN] = @FNAMN,
					[RAR_0_FROM] = @RAR_0_FROM,
					[RAR_0_TO] = @RAR_0_TO,
					[RAR_1_FROM] = @RAR_1_FROM,
					[RAR_1_TO] = @RAR_1_TO,
					[TAXAR] = @TAXAR,
					[OMFATTN] = @OMFATTN,
					[KPTYP] = @KPTYP,
					[VALUTA] = @VALUTA,
					[InsertedBy] = @UserName

				SET @Inserted = @Inserted + @@ROWCOUNT
			END
		ELSE
			BEGIN
				SELECT
					@FLAGGA = [FLAGGA],
					@PROGRAM = [PROGRAM],
					@FORMAT = [FORMAT],
					@GEN = [GEN],
					@SIETYP = [SIETYP],
					@PROSA  = [PROSA],
					@FNR  = [FNR],
					@ORGNR  = [ORGNR],
					@BKOD  = [BKOD],
					@ADRESS = [ADRESS],
					@FNAMN = [FNAMN],
					@RAR_0_FROM = [RAR_0_FROM],
					@RAR_0_TO = [RAR_0_TO],
					@RAR_1_FROM = [RAR_1_FROM],
					@RAR_1_TO = [RAR_1_TO],
					@TAXAR = [TAXAR],
					@OMFATTN = [OMFATTN],
					@KPTYP = [KPTYP],
					@VALUTA = [VALUTA]
				FROM
					pcINTEGRATOR_Data..SIE4_Job
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					JobID = @JobID
			END

		IF @DebugBM & 2 > 0 SELECT [Table] = 'SIE4_Job', * FROM SIE4_Job WHERE JobID = @Jobid

	SET @Step = 'Set variables'
		SELECT
			@Entity_Source = MAX(EntityPropertyValue)
		FROM
			EntityPropertyValue EPV
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			--EntityID = 0 AND
			EntityPropertyTypeID = -6

		IF @Entity_Source IS NULL
			SET @Entity_MemberKey = @FNR
		ELSE
			BEGIN
				SET @Entity_Source = REPLACE(@Entity_Source, '@FNR', '''' + @FNR + '''')

				SET @SQLStatement = 'SELECT @InternalVariable = ' + @Entity_Source
		
				EXEC sp_executesql @SQLStatement, N'@internalVariable nvarchar(50) OUT', @internalVariable = @Entity_MemberKey OUT
			END

		IF @DebugBM & 2 > 0 
			SELECT
				[@Entity_Source] = @Entity_Source,
				[@SQLStatement] = @SQLStatement,
				[@Entity_MemberKey] = @Entity_MemberKey

	SET @Step = 'Check Entity'
		SELECT
			@EntityID = [EntityID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[MemberKey] = @Entity_MemberKey

		IF @EntityID IS NULL
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity]
					(
					[InstanceID],
					[VersionID],
					[MemberKey],
					[EntityName]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[MemberKey] = @Entity_MemberKey,
					[EntityName] = @FNAMN
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Entity] E WHERE E.[InstanceID] = @InstanceID AND E.[VersionID] = @VersionID AND E.[MemberKey] = @Entity_MemberKey)

				SET @Inserted = @Inserted + @@ROWCOUNT

				SELECT
					@EntityID = MAX(EntityID)
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[MemberKey] = @Entity_MemberKey AND
					[EntityName] = @FNAMN
			END

		UPDATE [pcINTEGRATOR_Data].[dbo].[SIE4_Job]
		SET
			EntityID = @EntityID
		WHERE
			JobID = @JobID

		IF @DebugBM & 2 > 0
			SELECT
				[@JobID] = @JobID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@EntityID] = @EntityID,
				[@Entity_MemberKey] = @Entity_MemberKey,
				[@EntityName] = @FNAMN

	SET @Step = 'Insert into Entity_Book'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_Book]
			(
			[InstanceID],
			[VersionID],
			[EntityID],
			[Book],
			[Currency],
			[BookTypeBM]
			)
		SELECT 
			[InstanceID] = SJ.[InstanceID],
			[VersionID] = @VersionID,
			[EntityID] = SJ.[EntityID],
			[Book] = 'GL',
			[Currency] = SJ.[VALUTA],
			[BookTypeBM] = 3
		FROM
			SIE4_Job SJ
		WHERE
			SJ.JobID = @JobID AND
			SJ.[InstanceID] = @InstanceID AND
			SJ.EntityID = @EntityID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB WHERE EB.[EntityID] =  SJ.[EntityID] AND EB.[Book] = 'GL')

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Entity_FiscalYear'
		SET @MonthID = @RAR_0_FROM / 100

		EXEC [dbo].[spGet_Entity_FiscalYear_StartMonth]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@EntityID = @EntityID,
			@Book = 'GL',
			@MonthID = @MonthID,
			@StartMonth = @StartMonth OUT,
			@EndMonth = @EndMonth OUT,
			@Entity_FiscalYearID = @Entity_FiscalYearID OUT

		IF @DebugBM & 2 > 0 SELECT [@MonthID] = @MonthID, [@StartMonth] = @StartMonth, [@EndMonth] = @EndMonth

		IF @MonthID <> @StartMonth OR @RAR_0_TO / 100 > @EndMonth
			BEGIN
				UPDATE [pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear]
				SET
					EndMonth = CASE WHEN @MonthID % 100 = 1 THEN (@MonthID / 100 - 1) * 100 + 12 ELSE @MonthID - 1 END
				WHERE
					Entity_FiscalYearID = @Entity_FiscalYearID 

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear]
					(
					InstanceID,
					EntityID,
					Book,
					StartMonth,
					EndMonth
					)
				SELECT
					InstanceID = @InstanceID,
					EntityID = @EntityID,
					Book = 'GL',
					StartMonth = @MonthID,
					EndMonth = 209900 + @RAR_0_TO % 100

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Return @JobID'
		SELECT JobID = @JobID

	SET @Step = 'Return Statistics'
		SELECT @Duration = CONVERT(time(7), GetDate() - @StartTime)
		
		IF @RowCountYN <> 0
			SELECT
				[@Duration] = @Duration,
				[@Deleted] = @Deleted,
				[@Inserted] = @Inserted,
				[@Updated] = @Updated

	SET @Step = 'Return Debug'
		IF @DebugBM & 1 > 0
			SELECT
				[Table] = 'SIE4_Job',
				*
			FROM
				SIE4_Job
			WHERE
				[JobID] = @JobID

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
