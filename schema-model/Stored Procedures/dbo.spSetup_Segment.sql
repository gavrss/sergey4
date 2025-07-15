SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Segment]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,	--Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000573,
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
EXEC [spSetup_Segment] @UserID = -10, @InstanceID = 52, @VersionID = 1035, @SourceTypeID = 11, @DebugBM=7
EXEC [spSetup_Segment] @UserID = -10, @InstanceID = 533, @VersionID = 1058, @SourceTypeID = 7, @JobID=367, @DebugBM=7

EXEC [spSetup_Segment] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@JSON nvarchar(max),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),

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
	@ModifiedBy nvarchar(50) = 'HaLa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup financial segments',
			@MandatoryParameter = 'SourceTypeID' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2180' SET @Description = 'Added @Step = Update DimensionID in Journal_SegmentNo.'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-2906: Inserting new segments into [Dimension] table and deploying them into Callisto. Updated to latest sp template.'

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

		SELECT
			@CallistoDatabase = A.DestinationDatabase,
			@ETLDatabase = A.ETLDatabase
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceTypeID] = @SourceTypeID,
				[@JobID] = @JobID,
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase

	SET @Step = 'Fill [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]'
		SET @JSON = '
					[
					{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
					{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
					{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
					{"TKey" : "SourceTypeID",  "TValue": "' + CONVERT(nvarchar(15), @SourceTypeID) + '"},
					{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
					{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}
					]'

		IF @DebugBM & 2 > 0 PRINT @JSON
		
		IF @SourceTypeID = 1 --Epicor ERP
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Segment_EpicorERP', @JSON = @JSON

		IF @SourceTypeID = 3 --iScala
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Segment_iScala', @JSON = @JSON
					
		IF @SourceTypeID = 7 --SIE4
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Segment_SIE4', @JSON = @JSON

		IF @SourceTypeID = 8 --Navision
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Segment_Navision', @JSON = @JSON

		IF @SourceTypeID = 11 --Epicor ERP
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Segment_EpicorERP', @JSON = @JSON

		IF @SourceTypeID = 12 --Enterprise
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Segment_Enterprise', @JSON = @JSON

		IF @SourceTypeID = 15 --pcSource
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Segment_pcSource', @JSON = @JSON
		
		IF @SourceTypeID = 16 --pcETL
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Segment_pcETL', @JSON = @JSON
	
	SET @Step = 'Update SegmentNo in Journal_SegmentNo'
		SET @JSON = '
					[
					{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
					{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
					{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
					{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
					{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}
					]'

		IF @DebugBM & 2 > 0 PRINT @JSON
		EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSet_SegmentNo', @JSON = @JSON

	SET @Step = 'Insert New Segments into Dimension Table (Kinetic source)'
	IF (@SourceTypeID = 11 AND DB_ID(@CallistoDatabase) IS NOT NULL AND DB_ID(@ETLDatabase) IS NOT NULL)
		BEGIN
			IF ( SELECT COUNT(1)
				 FROM
					  [pcIntegrator_Data].[dbo].[Entity] E
					  INNER JOIN [pcIntegrator_Data].[dbo].[Entity_Book] EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.SelectYN <> 0 AND EB.BookTypeBM & 1 > 0
					  INNER JOIN [pcIntegrator_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.InstanceID = E.InstanceID AND JSN.VersionID = E.VersionID AND JSN.EntityID = E.EntityID AND JSN.Book = EB.Book AND JSN.SelectYN <> 0 AND JSN.DimensionID IS NULL
				  WHERE
					  E.InstanceID = @InstanceID AND
					  E.VersionID = @VersionID AND
					  E.SelectYN <> 0
				) > 0
				BEGIN
					EXEC [pcIntegrator].[dbo].[spSetup_Dimension]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@SourceTypeID = -11,
						@ModelingComment = 'Default setup',
						@JobID = @JobID,
						@Debug = @DebugSub

					EXEC [pcIntegrator].[dbo].[spSetup_Callisto]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@SequenceBM = 19,
						@JobID = @JobID,
						@Debug = @DebugSub

					--load members to Segments
					EXEC [pcIntegrator].[dbo].[spIU_Dim_Segment_Callisto]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@JobID = @JobID,
						@Debug = @DebugSub

					--Deploy Callisto
					EXEC [pcIntegrator].[dbo].[spRun_Job_Callisto_Generic]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@StepName = 'Deploy',
						@AsynchronousYN = 0,
						@Debug = @DebugSub

				END
		END

	SET @Step = 'Update DimensionID in Journal_SegmentNo'
		UPDATE JSN
		SET
			DimensionID = D.DimensionID
		FROM
			[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension] D ON D.InstanceID = JSN.InstanceID AND D.[DimensionName] = 'GL_' + REPLACE(REPLACE(JSN.[SegmentName], ' ', ''), 'GL_', '') AND D.DeletedID IS NULL
		WHERE
			JSN.InstanceID = @InstanceID AND
			JSN.VersionID = @VersionID AND
			JSN.DimensionID IS NULL AND 
			JSN.SelectYN <> 0

		SET @Updated = @Updated + @@ROWCOUNT


	SET @Step = 'Return information'
		IF @DebugBM & 1 > 0 
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Journal_SegmentNo', JSN.* FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN WHERE JSN.[InstanceID] = @InstanceID AND JSN.[VersionID] = @VersionID
			END

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
