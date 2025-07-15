SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Segment_iScala]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000744,
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
EXEC [spSetup_Segment_iScala] @UserID=-10, @InstanceID=529, @VersionID=1001, @SourceTypeID = 3, @DebugBM=3

EXEC [spSetup_Segment_iScala] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),	
	@SourceDatabase nvarchar(100),
	@Owner nvarchar(3),
	@Company nvarchar(2),
	@SegmentID int,
	@StartPosition int,
	@Length int,
	@TableExistsYN bit,

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
			@ProcedureDescription = 'Setup financial segments from iScala',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2165' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Updated handling of source databases.'

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
			@SourceDatabase = MAX(CASE WHEN M.[BaseModelID] = -7 THEN S.[SourceDatabase] ELSE '' END)
		FROM
			[Source] S
			INNER JOIN [Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.[BaseModelID] IN (-7)
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID

		SET @Owner = CASE WHEN @SourceTypeID = 11 THEN 'erp' ELSE 'dbo' END

		IF @DebugBM & 2 > 0 SELECT [@SourceDatabase] = @SourceDatabase, [@Owner] = @Owner

	SET @Step = 'Create and fill temp table #Company'
		CREATE TABLE #Company
			(
			[Company] nvarchar(8) COLLATE DATABASE_DEFAULT,
			[Name] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SourceServer] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SourceDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			)

		--TODO: temp, to be deleted
		SET @SQLStatement = '
			INSERT INTO #Company
				(
				[Company],
				[Name],
				[SourceServer],
				[SourceDatabase]
				)
			SELECT
				[Company] = C.[CompanyCode],
				[Name] = MAX(C.[CompanyName]),
				[SourceServer] = ''ABSH_ScalaDB'',
				--[SourceDatabase] = MAX(ISNULL(EPV.[EntityPropertyValue], C.[DBName]))
				[SourceDatabase] = MAX(ISNULL(EPV.[EntityPropertyValue], ''ABSH_ScalaDB.ABSH_ScalaDB''))
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[ScaCompanies] C
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.[MemberKey] = C.[CompanyCode] COLLATE DATABASE_DEFAULT AND E.[SelectYN] <> 0 AND E.[DeletedID] IS NULL
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV ON EPV.[EntityID] = E.[EntityID] AND EPV.[EntityPropertyTypeID] = -1 AND EPV.[SelectYN] <> 0
			GROUP BY
				C.[CompanyCode]'

/*
		SET @SQLStatement = '
			INSERT INTO #Company
				(
				[Company],
				[Name],
				[SourceServer],
				[SourceDatabase]
				)
			SELECT
				[Company] = C.[CompanyCode],
				[Name] = MAX(C.[CompanyName]),
				[SourceServer] = MAX(C.[ServerName]),
				[SourceDatabase] = MAX(ISNULL(EPV.[EntityPropertyValue], C.[DBName]))
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[ScaCompanies] C
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.[MemberKey] = C.[CompanyCode] COLLATE DATABASE_DEFAULT AND E.[SelectYN] <> 0 AND E.[DeletedID] IS NULL
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV ON EPV.[EntityID] = E.[EntityID] AND EPV.[EntityPropertyTypeID] = -1 AND EPV.[SelectYN] <> 0
			GROUP BY
				C.[CompanyCode]'
*/
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Company', * FROM #Company ORDER BY [Company]

	SET @Step = 'Create and fill temp table #Segment'
		CREATE TABLE #Segment
			(
			[Company] [nvarchar](2) COLLATE DATABASE_DEFAULT,
			[SegmentID] [int],
			[Name] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[ShortName] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[StartPosition] [int],
			[Length] [tinyint],
			[Flag] [tinyint]
			)

		IF CURSOR_STATUS('global','Segment_Cursor') >= -1 DEALLOCATE Segment_Cursor
		DECLARE Segment_Cursor CURSOR FOR

		SELECT DISTINCT
			DatabaseName = C.[SourceDatabase]
		FROM
			#Company C
--			INNER JOIN sys.databases d ON d.[name] = C.[SourceDatabase]
		ORDER BY
			C.[SourceDatabase]

		OPEN Segment_Cursor

		FETCH NEXT FROM Segment_Cursor INTO @SourceDatabase

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@SourceDatabase] = @SourceDatabase
			
				EXEC [spGet_TableExistsYN]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@DatabaseName = @SourceDatabase,
					@TableName = 'ScaCompanySegment',
					@ExistsYN = @TableExistsYN OUT,
					@JobID = @JobID

				SELECT [@TableExistsYN] = @TableExistsYN

				IF @TableExistsYN <> 0
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #Segment
								(
								[Company],
								[SegmentID],
								[Name],
								[ShortName],
								[Length],
								[Flag]
								)
							SELECT
								[Company] = [CompanyCode],
								[SegmentID],
								[Name],
								[ShortName],
								[Length],
								[Flag]
							FROM
								' + @SourceDatabase + '.[dbo].[ScaCompanySegment] SCS
							WHERE
								NOT EXISTS (SELECT 1 FROM #Segment S WHERE S.[Company] = SCS.[CompanyCode] COLLATE DATABASE_DEFAULT AND S.[SegmentID] = SCS.[SegmentID])'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END
			
			FETCH NEXT FROM Segment_Cursor INTO @SourceDatabase
			END

		CLOSE Segment_Cursor
		DEALLOCATE Segment_Cursor

	SET @Step = 'Update [#Segment]..[StartPosition]'
		IF CURSOR_STATUS('global','StartPosition_Cursor') >= -1 DEALLOCATE StartPosition_Cursor
		DECLARE StartPosition_Cursor CURSOR FOR

		SELECT DISTINCT
			[Company] = S.[Company]
		FROM
			#Segment S
		ORDER BY
			S.[Company]

		OPEN StartPosition_Cursor

		FETCH NEXT FROM StartPosition_Cursor INTO @Company

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@CompanyCode] = @Company
				SELECT
					@SegmentID = 0,
					@StartPosition = 1,
					@Length = 1

				WHILE @Length > 0
					BEGIN
						UPDATE S
						SET
							StartPosition = @StartPosition
						FROM
							#Segment S
						WHERE
							[Company] = @Company AND
							[SegmentID] = @SegmentID

						SELECT
							@Length = COUNT(1)
						FROM
							#Segment
						WHERE
							[Company] = @Company AND
							[SegmentID] = @SegmentID

						IF @Length > 0
							SELECT
								@Length = [Length]
							FROM
								#Segment
							WHERE
								[Company] = @Company AND
								[SegmentID] = @SegmentID

						SELECT
							@StartPosition = @StartPosition + @Length,
							@SegmentID = @SegmentID + 1
					END

			FETCH NEXT FROM StartPosition_Cursor INTO @Company
			END

		CLOSE StartPosition_Cursor
		DEALLOCATE StartPosition_Cursor

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment', * FROM #Segment ORDER BY [Company], [SegmentID]

	SET @Step = 'Fill Journal_SegmentNo'
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
				[JobID] = @JobID,
				[InstanceID] = E.[InstanceID],
				[VersionID] = E.[VersionID],
				[EntityID] = E.EntityID,
				[Book] = 'GL',
				[SegmentCode] = CONVERT(nvarchar(15), S.[SegmentID]),
				[SourceCode] = CASE S.[SegmentID] WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 2 THEN 'C' WHEN 3 THEN 'D' WHEN 4 THEN 'E' WHEN 5 THEN 'F' WHEN 6 THEN 'G' WHEN 7 THEN 'H' WHEN 8 THEN 'I' WHEN 9 THEN 'J' WHEN 10 THEN 'K' WHEN 11 THEN 'L' WHEN 12 THEN 'M' WHEN 13 THEN 'N' WHEN 14 THEN 'O' ELSE 'Warning' END,
				[SegmentNo] = CASE WHEN S.[SegmentID] = 0 THEN 0 ELSE -1 END,
				[SegmentName] = S.[Name],
				[DimensionID] = CASE WHEN S.[SegmentID] = 0 THEN -1 END,
				[BalanceAdjYN] = 0,
				[MaskPosition] = S.[StartPosition],
				[MaskCharacters] = S.[Length],
				[SelectYN] = CASE WHEN S.[SegmentID] = 0 THEN 1 ELSE 0 END
			FROM
				#Segment S
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = @InstanceID AND E.VersionID = @VersionID AND E.MemberKey = S.[Company]
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN WHERE JSN.[EntityID] = E.EntityID AND JSN.[Book] = 'GL' AND JSN.[SegmentCode] = CONVERT(nvarchar(15), S.[SegmentID]))
			ORDER BY
				E.MemberKey,
				S.[SegmentID]

		SET @Inserted = @Inserted + @@ROWCOUNT
		IF @DebugBM & 1 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Journal_SegmentNo', * FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] WHERE InstanceID = @InstanceID AND VersionID = @VersionID ORDER BY EntityID, Book, CONVERT(int, SegmentCode)

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
