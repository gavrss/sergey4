SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_SegmentNo]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000575,
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
EXEC [spSet_SegmentNo] @UserID=-10, @InstanceID=52, @VersionID=1033, @DebugBM=3

EXEC [spSet_SegmentNo] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@JournalTable nvarchar(100),
	@SQLStatement nvarchar(MAX),
	@JournalRows int,
	@SegmentNo int,
	@SegmentName nvarchar(100),

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
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set SegmentNo in table pcINTEGRATOR_Data..Journal_SegmentNo',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2168' SET @Description = 'Modified query in Step = Update SegmentNo in Journal_SegmentNo; ISNULL checking on [SourceCode].'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		EXEC [spGet_JournalTable] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JournalTable = @JournalTable OUT, @JobID = @JobID

		SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM ' + @JournalTable
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @JournalRows OUT

		IF @DebugBM & 2 > 0 SELECT [@JournalTable] = @JournalTable, [@JournalRows] = @JournalRows

	SET @Step = 'Reset SegmentNo in Journal_SegmentNo'
		IF @JournalRows = 0
			BEGIN
				UPDATE JSN
				SET
					SegmentNo = -1
				FROM
					[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN
				WHERE
					JSN.InstanceID = @InstanceID AND
					JSN.VersionID = @VersionID AND
					JSN.SegmentNo <> 0
			END

	SET @Step = 'Update SegmentNo in Journal_SegmentNo'
		SELECT 
			[SegmentName] = JSN.SegmentName,
			[Number] = Count(1),
			[AVG] = AVG(CONVERT(float, SUBSTRING(ISNULL([SourceCode], [SegmentCode]), PATINDEX('%[0-9]%', ISNULL([SourceCode], [SegmentCode])), PATINDEX('%[0-9][^0-9]%', ISNULL([SourceCode], [SegmentCode]) + 't') - PATINDEX('%[0-9]%', ISNULL([SourceCode], [SegmentCode])) + 1)))
		INTO
			#CursorTable
		FROM
			[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN
		WHERE
			JSN.InstanceID = @InstanceID AND
			JSN.VersionID = @VersionID AND
			JSN.SegmentNo <> 0 AND
			JSN.SelectYN <> 0 AND
			CASE WHEN JSN.SegmentNo = -1 THEN NULL ELSE JSN.SegmentNo END IS NULL
		GROUP BY
			JSN.SegmentName
		ORDER BY
			[Number] DESC,
			[AVG]

		SELECT DISTINCT
			JSN.SegmentName,
			SegmentNo = CASE WHEN JSN.SegmentNo = -1 THEN NULL ELSE JSN.SegmentNo END
		INTO
			#SegmentNo
		FROM
			[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN
		WHERE
			JSN.InstanceID = @InstanceID AND
			JSN.VersionID = @VersionID AND
			JSN.SelectYN <> 0

		DECLARE SegmentNo_Cursor CURSOR FOR
			SELECT
				SegmentName
			FROM
				#CursorTable
			ORDER BY
				[Number] DESC,
				[AVG]

			OPEN SegmentNo_Cursor
			FETCH NEXT FROM SegmentNo_Cursor INTO @SegmentName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@SegmentName] = @SegmentName

					SELECT @SegmentNo = MAX(SegmentNo) FROM #SegmentNo WHERE SegmentName = @SegmentName
					SET @SegmentNo = ISNULL(@SegmentNo, (SELECT MAX(SegmentNo) FROM #SegmentNo) + 1)

					IF @DebugBM & 2 > 0 SELECT [@SegmentNo] = @SegmentNo
					
					UPDATE SN
					SET
						SegmentNo = @SegmentNo
					FROM
						#SegmentNo SN
					WHERE
						SN.SegmentName = @SegmentName

					FETCH NEXT FROM SegmentNo_Cursor INTO @SegmentName
				END

		CLOSE SegmentNo_Cursor
		DEALLOCATE SegmentNo_Cursor	
		
		UPDATE JSN
		SET
			SegmentNo = SN.SegmentNo
		FROM
			[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN
			INNER JOIN #SegmentNo SN ON SN.SegmentName = JSN.SegmentName AND SN.SegmentNo IS NOT NULL
		WHERE
			JSN.InstanceID = @InstanceID AND
			JSN.VersionID = @VersionID AND
			JSN.SegmentNo = -1
		
		SET @Updated = @Updated + @@ROWCOUNT

		IF @DebugBM & 1 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Journal_SegmentNo', * FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] WHERE InstanceID = @InstanceID AND VersionID = @VersionID ORDER BY EntityID, Book, SourceCode

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
