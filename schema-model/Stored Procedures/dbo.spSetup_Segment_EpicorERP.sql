SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Segment_EpicorERP]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000574,
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
EXEC [spSetup_Segment_EpicorERP] @UserID=-10, @InstanceID=52, @VersionID=1033, @SourceTypeID = 11, @DebugBM=3

EXEC [spSetup_Segment_EpicorERP] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),	
	@SourceDatabase nvarchar(100),
	@Owner nvarchar(3),

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup financial segments from Epicor ERP',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2168' SET @Description = 'Replaced hyphen(-) with underscore(_) when setting SegmentName.'
		IF @Version = '2.1.1.2174' SET @Description = 'Filter on @SourceTypeID and handle multiple @SourceDatabase.'

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

		--SELECT 
		--	@SourceDatabase = MAX(CASE WHEN M.[BaseModelID] = -7 THEN S.[SourceDatabase] ELSE '' END)
		--FROM
		--	[Source] S
		--	INNER JOIN [Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.[BaseModelID] IN (-7)
		--WHERE
		--	S.[InstanceID] = @InstanceID AND
		--	S.[VersionID] = @VersionID AND
		--	S.[SourceTypeID] = ISNULL(@SourceTypeID, 11)

		SET @Owner = CASE WHEN @SourceTypeID = 11 THEN 'erp' ELSE 'dbo' END

		IF @DebugBM & 2 > 0 SELECT [@Owner] = @Owner

	SET @Step = 'Fill Journal_SegmentNo'
		IF CURSOR_STATUS('global','SourceDatabase_Cursor') >= -1 DEALLOCATE SourceDatabase_Cursor
			DECLARE SourceDatabase_Cursor CURSOR FOR
			
			SELECT DISTINCT 
				S.SourceDatabase
			FROM
				[Source] S
				INNER JOIN [Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.[BaseModelID] IN (-7)
			WHERE
				S.[InstanceID] = @InstanceID AND
				S.[VersionID] = @VersionID AND
				S.[SourceTypeID] = ISNULL(@SourceTypeID, 11)

				OPEN SourceDatabase_Cursor
				FETCH NEXT FROM SourceDatabase_Cursor INTO @SourceDatabase

				WHILE @@FETCH_STATUS = 0
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@SourceDatabase] = @SourceDatabase

						SET @SQLStatement = '
							INSERT INTO [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
								(
								[Comment],
								[JobID],
								[InstanceID],
								[VersionID],
								[EntityID],
								[Book],
								[SegmentCode],
								[SourceCode],
								[SegmentNo],
								[SegmentName],
								[DimensionID],
								[BalanceAdjYN],
								[MaskPosition],
								[MaskCharacters],
								[SelectYN]
								)
							SELECT 
								[Comment] = E.MemberKey,
								[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
								[InstanceID] = E.[InstanceID],
								[VersionID] = E.[VersionID],
								[EntityID] = E.EntityID,
								[Book] = EB.Book,
								[SegmentCode] = COAS.SegmentName,
								[SourceCode] = ''SegValue'' + CONVERT(nvarchar(7), COAS.SegmentNbr),
								[SegmentNo] = CASE WHEN COAS.SegmentNbr = 1 THEN 0 ELSE -1 END,
								[SegmentName] = CASE WHEN COAS.SegmentNbr = 1 THEN ''Account'' ELSE ''GL_'' + REPLACE(REPLACE(REPLACE(COAS.SegmentName, '' '', ''_''), ''-'', ''_''), ''GL_'', '''') END,
								[DimensionID] = CASE WHEN COAS.SegmentNbr = 1 THEN -1 END,
								[BalanceAdjYN] = CASE WHEN COAS.[Dynamic] = 0 THEN 1 ELSE 0 END,
								[MaskPosition] = NULL,
								[MaskCharacters] = NULL,
								[SelectYN] = EB.SelectYN
							FROM
								' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COASegment] COAS ON COAS.Company = GLB.Company AND COAS.COACode = GLB.COACode
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.MemberKey = GLB.Company COLLATE DATABASE_DEFAULT
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.COA = GLB.COACode COLLATE DATABASE_DEFAULT
							WHERE
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN WHERE JSN.[EntityID] = E.EntityID AND JSN.[Book] = EB.Book AND JSN.[SegmentCode] = COAS.SegmentName COLLATE DATABASE_DEFAULT)
							ORDER BY
								E.MemberKey,
								EB.Book,
								COAS.SegmentNbr'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Inserted = @Inserted + @@ROWCOUNT

						FETCH NEXT FROM SourceDatabase_Cursor INTO @SourceDatabase
					END

			CLOSE SourceDatabase_Cursor
			DEALLOCATE SourceDatabase_Cursor

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Journal_SegmentNo', * FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] WHERE InstanceID = @InstanceID AND VersionID = @VersionID ORDER BY EntityID, Book, SourceCode

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
