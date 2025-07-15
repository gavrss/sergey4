SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_Entity]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000236,
	@Parameter NVARCHAR(4000) = NULL,
	@StartTime DATETIME = NULL,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spInsert_Entity',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "417"},
		{"TKey" : "VersionID",  "TValue": "1007"}
		]'

EXEC [dbo].[spInsert_Entity] 
	@UserID = -10,
	@InstanceID = 417,
	@VersionID = 1007

EXEC [dbo].[spInsert_Entity] 
	@UserID = -10,
	@InstanceID = 413,
	@VersionID = 1008,
	@Debug = 1

--GetVersion
	EXEC [spInsert_Entity] @GetVersion = 1
*/
DECLARE
	@SQLStatement nvarchar(max),
	@SourceDatabase nvarchar(100) = '[DSPSOURCE01].[pcSource_ausmtspilot102_cbn]',
	@Owner nvarchar(10) = '[Erp]',

	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'

		IF ISNULL((SELECT [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL), 0) <> @ProcedureID
			BEGIN
				SET @ProcedureID = NULL
				SELECT @ProcedureID = [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL
				IF @ProcedureID IS NULL
					BEGIN
						EXEC spInsert_Procedure
						SET @Message = 'SP ' + OBJECT_NAME(@@PROCID) + ' was not registered. It is now registered by SP spInsert_Procedure. Rerun the command to get correct ProcedureID.'
					END
				ELSE
					SET @Message = 'ProcedureID mismatch, should be ' + CONVERT(nvarchar(10), @ProcedureID)
				SET @Severity = 16
				GOTO EXITPOINT
			END
		SELECT [Version] = @Version, [Description] = @Description, [ProcedureID] = @ProcedureID
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Step = 'Insert into Entity'
		SET @SQLStatement = '
			INSERT INTO [dbo].[Entity]
				(
				[InstanceID],
				[VersionID],
				[MemberKey],
				[EntityName]
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[MemberKey] = C.[Company],
				[EntityName] = C.[Name]
			FROM
				' + @SourceDatabase + '.' + @Owner + '.[Company] C
			WHERE
				NOT EXISTS (SELECT 1 FROM [Entity] E WHERE E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND E.MemberKey = C.[Company])'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Entity_Book'
		SET @SQLStatement = '
			INSERT INTO [dbo].[Entity_Book]
				(
				[InstanceID],
				[EntityID],
				[Book],
				[Currency],
				[BookTypeBM],
				[SelectYN]
				)
			SELECT
				[InstanceID] = E.InstanceID,
				[EntityID] = E.[EntityID],
				[Book] = GLB.[BookID],
				[Currency] = UPPER(SUBSTRING(GLB.[CurrencyCode], 1, 3)),
				[BookTypeBM] = CASE WHEN GLB.[MainBook] = 0 THEN 1 ELSE 3 END,
				[SelectYN] = GLB.[MainBook]
			FROM
				' + @SourceDatabase + '.' + @Owner + '.[Company] C
				INNER JOIN ' + @SourceDatabase + '.' + @Owner + '.[COA] COA ON COA.Company = C.Company
				INNER JOIN ' + @SourceDatabase + '.' + @Owner + '.[GLBook] GLB ON GLB.Company = C.Company AND GLB.COACode = COA.COACode
				INNER JOIN [Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND E.[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ' AND E.MemberKey = C.[Company]
			WHERE
				NOT EXISTS (SELECT 1 FROM Entity_Book EB WHERE EB.[InstanceID] = E.InstanceID AND EB.[EntityID] = E.[EntityID] AND EB.[Book] = GLB.[BookID])'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Journal_SegmentNo'
		SET @SQLStatement = '
			INSERT INTO [dbo].[Journal_SegmentNo]
				(
				[JobID],
				[InstanceID],
				[EntityID],
				[Entity],
				[Book],
				[SegmentCode],
				[SegmentNo],
				[SegmentName],
				[DimensionID],
				[MaskPosition],
				[MaskCharacters],
				[SelectYN]
	  			)
			SELECT TOP 1000
				[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
				[InstanceID] = E.InstanceID,
				[EntityID] = E.EntityID,
				[Entity] = E.MemberKey,
				[Book] = EB.Book,
				[SegmentCode] = COAS.SegmentName,
				[SegmentNo] = COAS.SegmentNbr,
				[SegmentName] = ''GL_'' + REPLACE(REPLACE(SegmentName, ''GL_'', ''''), '' '', ''''),
				[DimensionID] = NULL,
				[MaskPosition] = NULL,
				[MaskCharacters] = NULL,
				[SelectYN] = 1
			FROM
				' + @SourceDatabase + '.' + @Owner + '.[GLBook] GLB
				INNER JOIN ' + @SourceDatabase + '.' + @Owner + '.[COASegment] COAS ON COAS.Company = GLB.Company AND COAS.COACode = GLB.COACode
				INNER JOIN ' + @SourceDatabase + '.' + @Owner + '.[Company] C ON C.Company = GLB.Company
				INNER JOIN [Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND E.MemberKey = C.[Company]
				INNER JOIN [Entity_Book] EB ON EB.[InstanceID] = E.InstanceID AND EB.[EntityID] = E.[EntityID] AND EB.[Book] = GLB.[BookID]
			WHERE
				NOT EXISTS (SELECT 1 FROM [dbo].[Journal_SegmentNo] JSN WHERE JSN.[InstanceID] = E.InstanceID AND JSN.[EntityID] = E.[EntityID] AND JSN.[Book] = GLB.[BookID] AND JSN.SegmentCode = GLB.COACode)
			ORDER BY
				GLB.Company,
				GLB.COACode,
				COAS.SegmentNbr'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
				
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
