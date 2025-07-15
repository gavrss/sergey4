SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_SIE4_EndJob]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	@KSUMMA NVARCHAR(100) = NULL,
	@SentRows INT = NULL,
	@RowCountYN BIT = 0,

	@JobID INT = NULL OUT,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000169,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalSet_SIE4_EndJob',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

--EXEC [spPortalSet_SIE4_EndJob] @UserID = 2122, @InstanceID = 404, @VersionID = 1003, @JobID = 24488, @RowCountYN = 1, @Debug = 1 --SALINITY
--EXEC [spPortalSet_SIE4_EndJob] @UserID = -10, @InstanceID = 533, @VersionID = 1058, @JobID = 1146, @RowCountYN = 1, @Debug = 1 --SALINITY
--EXEC [spPortalSet_SIE4_EndJob] @UserID = -10, @InstanceID = 533, @VersionID = 1058, @JobID = 12793, @RowCountYN = 1, @Debug = 1 --SALINITY

EXEC [spPortalSet_SIE4_EndJob] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@Entity NVARCHAR(50),
	@EntityID INT,
	@Book NVARCHAR(50) = 'GL',
	@JSON NVARCHAR(1000),
	@ApplicationID INT,
	@StartFiscalYear INT,
	@StartDate INT,
	@FiscalYearStartMonth INT,
	@FiscalYear INT,
	@FiscalYearNaming INT,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2187'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Finalize SIE4 load',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'Added full Callisto deploy.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2145' SET @Description = 'Set parameter @FiscalYear when loading into Journal.'
		IF @Version = '2.1.1.2168' SET @Description = 'End job by [spSet_Job].'
		IF @Version = '2.1.1.2179' SET @Description = 'Added @Entity_MemberKey as parameter (mandatory) to [spPortalSet_SIE4_Dimension] sub-routine.'
		IF @Version = '2.1.2.2187' SET @Description = 'Added DB name reference (pcINTEGRATOR_Log) for table [JobLog].'

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

		SELECT
			@Entity = E.MemberKey,
			@EntityID = E.EntityID
		FROM
			SIE4_Job SJ
			INNER JOIN Entity E ON E.EntityID = SJ.EntityID
		WHERE
--			SJ.UserID = @UserID AND
			SJ.InstanceID = @InstanceID AND
			SJ.VersionID = @VersionID AND
			SJ.JobID = @JobID

		SELECT
			@ApplicationID = A.ApplicationID
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SELECT 
			@StartFiscalYear = [RAR_1_FROM] / 10000,
			@StartDate = [RAR_0_FROM]
		FROM
			[pcINTEGRATOR_Data].[dbo].[SIE4_Job]
		WHERE
--			[UserID] = @UserID AND
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[JobID] = @JobID

		SELECT 
			@FiscalYear = @StartDate / 10000,
			@FiscalYearStartMonth = StartMonth % 100
		FROM 
			[pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear]
		WHERE 
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND 
			EntityID = @EntityID AND 
			Book = @Book AND
			@StartDate / 100 BETWEEN StartMonth AND EndMonth

		IF @FiscalYearStartMonth <> 1
			SELECT 
				@FiscalYear = @FiscalYear + FiscalYearNaming 
			FROM 
				[pcINTEGRATOR_Data].[dbo].[Instance] 
			WHERE 
				InstanceID = @InstanceID

		IF @Debug <> 0 
			SELECT
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@ApplicationID] = @ApplicationID,
				[@JobID] = @JobID,
				[@Entity] = @Entity,
				[@EntityID] = @EntityID,
				[@FiscalYear] = @FiscalYear,
				[@StartFiscalYear] = @StartFiscalYear,
				[@StartDate] = @StartDate


	SET @Step = 'Update Job'
		EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Start', @MasterCommand='spPortalSet_SIE4_StartJob', @CurrentCommand=@ProcedureName, @JobQueueYN=0, @JobID=@JobID OUT
		
		--UPDATE J
		--SET
		--	CurrentCommand = 'spPortalSet_SIE4_EndJob',
		--	CurrentCommand_StartTime = GETDATE()
		--FROM
		--	[pcINTEGRATOR_Log].[dbo].[Job] J
		--WHERE
		--	J.JobID = @JobID

	SET @Step = 'Handle Financial Segments used in Journal'
		EXEC [spPortalSet_SIE4_Journal_SegmentNo] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID

	SET @Step = 'Load data into Journal'
--		EXEC [spPortalSet_SIE4_Journal] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID
--		EXEC [spIU_Journal] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @SourceTypeID = 7, @Entity_MemberKey = @Entity, @Book = @Book, @JobID = @JobID

		SET @JSON = '
				[
				{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
				{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
				{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
				{"TKey" : "SourceTypeID",  "TValue": "7"},
				{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity + '"},
				{"TKey" : "Book",  "TValue": "' + @Book + '"},
				{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
				{"TKey" : "StartFiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @StartFiscalYear) + '"},
				{"TKey" : "FiscalYear",  "TValue": "' + CONVERT(nvarchar(10), @FiscalYear) + '"},
				{"TKey" : "FullReloadYN",  "TValue": "1"}
				]'
		IF @Debug <> 0 PRINT @JSON

		EXEC spRun_Procedure_KeyValuePair
			@ProcedureName = 'spIU_DC_Journal',
			@JSON = @JSON

	SET @Step = 'Load dimension into selected StorageTypes'
		EXEC [spPortalSet_SIE4_Dimension] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Entity_MemberKey = @Entity, @JobID = @JobID

	SET @Step = 'Update Callisto FACT table'
--		EXEC [spIU_Journal_DataClass_Financials] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @SequenceBM = 3, @Entity = @Entity, @Book = @Book, @JobID = @JobID
		SET @JSON = '
				[
				{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
				{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
				{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
				{"TKey" : "SequenceBM",  "TValue": "3"},
				{"TKey" : "Entity",  "TValue": "' + @Entity + '"},
				{"TKey" : "Book",  "TValue": "' + @Book + '"},
				{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"}
				]'
		
		IF @Debug <> 0 SELECT UserID = @UserID, InstanceID = @InstanceID, VersionID = @VersionID, Entity = @Entity, Book = @Book, JobID = @JobID

		EXEC spRun_Procedure_KeyValuePair
			@ProcedureName = 'spIU_DC_Financials_Callisto',
			@JSON = @JSON

	SET @Step = 'Deploy Callisto database'
		--EXEC [spStart_Job_Agent] @ApplicationID = @ApplicationID, @StepName = 'Deploy', @AsynchronousYN = 1
		EXEC [spRun_Job_Callisto_Generic]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@StepName = 'Refresh', --Load, Deploy, Refresh
			@ModelName = 'Financials', --Mandatory for Refresh
			@AsynchronousYN = 0,
			@JobID = @JobID

	SET @Step = 'End #Job'
		UPDATE J
		SET
			KSUMMA = ISNULL(@KSUMMA, J.KSUMMA),
			SentRows = ISNULL(@SentRows, J.SentRows),
			EndTime = GETDATE()
		FROM
			[pcINTEGRATOR_Data].[dbo].[SIE4_Job] J
		WHERE
			EndTime IS NULL AND
			JobID = @JobID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update Job'
		EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='End', @MasterCommand='spPortalSet_SIE4_StartJob', @CurrentCommand=@ProcedureName, @JobID=@JobID
		
		--UPDATE J
		--SET
		--	EndTime = GETDATE()
		--FROM
		--	[pcINTEGRATOR_Log].[dbo].[Job] J
		--WHERE
		--	J.JobID = @JobID

	SET @Step = 'Return result'
		SELECT 
--			[Error#] = COUNT(1),
			[ErrorInfo] = CASE WHEN COUNT(1) = 0 THEN 'No errors occurred during the process.' ELSE CONVERT(nvarchar(10), COUNT(1)) + ' error(s) occurred during the process. Look into the JobLog table for details.' END
		FROM
			[pcINTEGRATOR_Log].[dbo].[JobLog]
		WHERE
			[JobID] = @JobID AND
			[ErrorNumber] <> 0

	SET @Step = 'Return Statistics'
		SELECT @Duration = CONVERT(time(7), EndTime - StartTime) FROM SIE4_Job WHERE [JobID] = @JobID
		
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = 'Return Debug'
		IF @Debug <> 0
			BEGIN

				SELECT
					Duration = @Duration,
					*
				FROM
					SIE4_Job
				WHERE
					[JobID] = @JobID


				SELECT 
					[Table] = sub.[Table],
					[Param] = sub.[Param],
					[Counter] = sub.[Counter]
				FROM
					(
					SELECT 
						[Table] = 'SIE4_Job',
						[Param] = 'Multiple',
						[Counter] = COUNT(1)
					FROM
						SIE4_Job
					WHERE
						JobID = @JobID
					UNION SELECT 
						[Table] = 'SIE4_Dim',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Dim
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = 'SIE4_Object',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Object
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = 'SIE4_Balance',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Balance
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = 'SIE4_Ver',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Ver
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = 'SIE4_Trans',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Trans
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = 'SIE4_Other',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Trans
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					) sub
				ORDER BY
					sub.[Table],
					sub.[Param]
			END

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
