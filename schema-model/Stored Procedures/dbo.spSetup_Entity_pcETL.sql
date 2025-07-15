SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Entity_pcETL]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = 16,
	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Copied from Callisto',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000468,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spSetup_Entity',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSetup_Entity_pcETL] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @Debug = 1

EXEC [spSetup_Entity_pcETL] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@SQLStatement nvarchar(max),	
	@ApplicationID int,
	@ApplicationName nvarchar(100),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@EntityGroupID int,
	@SourceID_Financials int,
	@SourceID_FxRate int,
	@ETL_SourceID_Financials int,
	@ETL_SourceID_FxRate int,
	@ReturnVariable nvarchar(100),

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
	@Version nvarchar(50) = '2.1.0.2155'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Entity from ETL SourceType',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Code enhancement for ETL SourceType.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID. Remove @DemoYN.'
		IF @Version = '2.1.0.2155' SET @Description = 'Enhanced debugging.'

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
			@ApplicationID = [ApplicationID],
			@ApplicationName = [ApplicationName],
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		SELECT
			@SourceID_Financials = S.SourceID
		FROM
			[Source] S
			INNER JOIN Model M ON M.InstanceID = S.InstanceID AND M.VersionID = S.VersionID AND M.ModelID = S.ModelID AND M.ModelBM & 64 > 0
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SelectYN] <> 0

		SELECT
			@SourceID_FxRate = S.SourceID
		FROM
			[Source] S
			INNER JOIN Model M ON M.InstanceID = S.InstanceID AND M.VersionID = S.VersionID AND M.ModelID = S.ModelID AND M.ModelBM & 4 > 0
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT [@SourceID_Financials] = @SourceID_Financials, [@SourceID_FxRate] = @SourceID_FxRate

	SET @Step = 'Get SourceID from pcETL'
		SET @SQLStatement = '
			SELECT DISTINCT
				@InternalVariable = E.SourceID
			FROM 
				' + @ETLDatabase + '.[dbo].[Entity] E
				INNER JOIN [Source] S ON S.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND S.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND S.SourceID = E.SourceID --AND S.InheritedFrom = E.SourceID
			WHERE
				E.SourceID = ' + CONVERT(nvarchar(15), @SourceID_Financials)

		EXEC sp_executesql @SQLStatement, N'@InternalVariable nvarchar(100) OUT', @InternalVariable = @ReturnVariable OUT
		SELECT @ETL_SourceID_Financials = @ReturnVariable

		SET @SQLStatement = '
			SELECT DISTINCT
				@InternalVariable = E.SourceID
			FROM 
				' + @ETLDatabase + '.[dbo].[Entity] E
				INNER JOIN [Source] S ON S.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND S.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND S.SourceID = E.SourceID --AND S.InheritedFrom = E.SourceID
			WHERE
				E.SourceID = ' + CONVERT(nvarchar(15), @SourceID_FxRate)

		EXEC sp_executesql @SQLStatement, N'@InternalVariable nvarchar(100) OUT', @InternalVariable = @ReturnVariable OUT
		SELECT @ETL_SourceID_FxRate = @ReturnVariable

		IF @DebugBM & 2 > 0 SELECT [@ETL_SourceID_Financials] = @ETL_SourceID_Financials, [@ETL_SourceID_FxRate] = @ETL_SourceID_FxRate

	SET @Step = 'Fill Entity'	
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity]
				(
				[InstanceID],
				[VersionID],
				[MemberKey],
				[EntityName],
				[SelectYN]
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[MemberKey] = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE CASE WHEN ST.SourceTypeFamilyID IN (3) THEN E.EntityCode ELSE E.Entity END END,
				[EntityName] = MAX(CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN REPLACE(E.EntityName, '' - '' + E.Par02, '''') ELSE E.EntityName END),
				[SelectYN] = MAX(CONVERT(int, E.SelectYN))
			FROM
				' + @ETLDatabase + '.[dbo].[Entity] E
				INNER JOIN [Source] S ON S.SourceID = ' + CONVERT(nvarchar(15), @SourceID_Financials) + '
				INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
			WHERE
				E.SourceID = ' + CONVERT(nvarchar(15), @ETL_SourceID_Financials) + ' AND
				NOT EXISTS (SELECT 1 FROM [Entity] pcIE WHERE pcIE.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND pcIE.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND pcIE.MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE CASE WHEN ST.SourceTypeFamilyID IN (3) THEN E.EntityCode ELSE E.Entity END END)
			GROUP BY
				CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE CASE WHEN ST.SourceTypeFamilyID IN (3) THEN E.EntityCode ELSE E.Entity END END'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity', * FROM [pcINTEGRATOR_Data].[dbo].[Entity] WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Fill Entity_Book'
		/**
		NOTES: 
		1) To get EntityBook from ETL, set 
		2) INNER JOIN ... FS.[EntityCode] = E.MemberKey + ''_'' + EB.Book --> IS ONLY VALID FOR EPICOR ERP
		3) Need a JOIN between FinancialSegment and MappedObject to get correct [SegmentName]
		*/
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_Book]
				(
				[InstanceID],
				[VersionID],
				[EntityID],
				[Book],
				[Currency],
				[COA],
				[BookTypeBM],
				[SelectYN]
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
				[EntityID] = pcIE.EntityID,
				[Book] = CASE WHEN ST.SourceTypeFamilyID IN (1) AND BM.ModelID = -7 THEN E.Par02 ELSE CASE WHEN BM.ModelID = -7 THEN ''GL'' ELSE BM.ModelName END END,
				[Currency] = E.Currency,
				[COA] = CASE WHEN ST.SourceTypeFamilyID IN (1) AND BM.ModelID = -7 THEN E.Par03 END,
				[BookTypeBM] = CASE BM.ModelID WHEN -7 THEN 1 WHEN -3 THEN 4 ELSE 8 END + CASE WHEN BM.ModelID = -7 AND ((ST.SourceTypeFamilyID IN (1) AND E.Par08 = ''1'') OR ST.SourceTypeFamilyID NOT IN (1)) THEN 2 ELSE 0 END,
				[SelectYN] = E.SelectYN
			FROM
				' + @ETLDatabase + '..Entity E
				INNER JOIN [Source] S ON ' + CASE WHEN (@SourceID_Financials = @ETL_SourceID_Financials AND @SourceID_FxRate = @ETL_SourceID_FxRate) THEN 'S.SourceID = E.SourceID' ELSE 'S.InheritedFrom = E.SourceID' END + '
				INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
				INNER JOIN [Entity] pcIE ON pcIE.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND pcIE.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND pcIE.MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE CASE WHEN ST.SourceTypeFamilyID IN (3) THEN E.EntityCode ELSE E.Entity END END
				INNER JOIN [Model] M ON M.ModelID = S.ModelID
				INNER JOIN [Model] BM ON BM.ModelID = M.BaseModelID
			WHERE
				E.SourceID IN (' + CONVERT(nvarchar(15), @ETL_SourceID_Financials) + ', ' + CONVERT(nvarchar(15), @ETL_SourceID_FxRate) + ') AND
				NOT EXISTS (SELECT 1 FROM [Entity_Book] EB WHERE EB.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND EB.EntityID = pcIE.EntityID AND EB.Book = CASE WHEN ST.SourceTypeFamilyID IN (1) AND BM.ModelID = -7 THEN E.Par02 ELSE CASE WHEN BM.ModelID = -7 THEN ''GL'' ELSE BM.ModelName END END)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity_Book', EB.* FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.EntityID = EB.EntityID WHERE E.InstanceID = @InstanceID AND E.VersionID = @VersionID

	SET @Step = 'Fill Journal_SegmentNo'
		/**
		TODOS: Issues found:
		1) For ENT, the EntityNames does not match between [FinancialSegment] and [MappedObject]
		2) INNER JOIN ... FS.[EntityCode] = E.MemberKey + ''_'' + EB.Book --> IS ONLY VALID FOR EPICOR ERP
		3) Need a JOIN between FinancialSegment and MappedObject to get correct [SegmentName]
		*/
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
				(
				[JobID],
				[VersionID],
				[InstanceID],
				[EntityID],
				[Entity],
				[Book],
				[SegmentCode],
				[SourceCode],
				[SegmentNo],
				[SegmentName],
				[DimensionID],
				[MaskPosition],
				[MaskCharacters],
				[SelectYN]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(15), ISNULL(@JobID, @ProcedureID)) + ',
				[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
				[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
				[EntityID] = E.EntityID,
				[Entity] = E.MemberKey,
				[Book] = EB.Book,
				[SegmentCode] = FS.[SegmentName],
				[SourceCode] = FS.[SegmentCode],
				[SegmentNo] = CASE WHEN FS.DimensionTypeID = 1 THEN 0 ELSE -1 END,
				[SegmentName] = CASE WHEN FS.DimensionTypeID = 1 THEN ''Account'' ELSE ''GL_'' + REPLACE(REPLACE(FS.[SegmentName], '' '', ''_''), ''GL_'', '''') END,
				[DimensionID] = CASE WHEN FS.DimensionTypeID = 1 THEN -1 ELSE NULL END,
				[MaskPosition] = NULL,
				[MaskCharacters] = NULL,
				[SelectYN] = 1
			FROM
				[Entity_Book] EB
				INNER JOIN [Entity] E ON E.InstanceID = EB.InstanceID AND E.VersionID = EB.VersionID AND E.EntityID = EB.EntityID
				INNER JOIN ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS ON FS.SourceID = ' + CONVERT(nvarchar(15), @ETL_SourceID_Financials) + ' AND FS.EntityCode = E.MemberKey + ''_'' + EB.Book
			WHERE
				EB.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				EB.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
				EB.BookTypeBM & 3 > 0
				AND NOT EXISTS (SELECT 1 FROM [Journal_SegmentNo] JSN WHERE JSN.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND JSN.EntityID = E.EntityID AND JSN.Book = EB.Book AND JSN.SegmentCode = FS.SegmentName)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR..Journal_SegmentNo', JSN.* FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.EntityID = JSN.EntityID AND EB.Book = JSN.Book INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.EntityID = EB.EntityID WHERE E.InstanceID = @InstanceID AND E.VersionID = @VersionID

	SET @Step = 'Copy Entity structure to ETL Entity'
		--Must check other sources than Financials in ETL Entity. Fix later
		SET @SQLStatement = '
			UPDATE ETLE
			SET
				[SelectYN] = CONVERT(int, E.SelectYN)
			FROM 
				[Entity] E
				INNER JOIN [' + @ETLDatabase + '].[dbo].[Entity] ETLE ON ETLE.EntityCode = E.MemberKey
			WHERE
				E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + '

			UPDATE ETLE
			SET
				[SelectYN] = CONVERT(int, E.SelectYN) * CONVERT(int, EB.SelectYN)
			FROM 
				[Entity] E
				INNER JOIN [Entity_Book] EB ON EB.EntityID = E.EntityID
				INNER JOIN [' + @ETLDatabase + '].[dbo].[Entity] ETLE ON ETLE.EntityCode = E.MemberKey + ''_'' + EB.Book
			WHERE
				E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				E.VersionID = ' + CONVERT(nvarchar(15), @VersionID)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Copy Entity/Segment structure to MappedObject'
		SET @SQLStatement = '
			UPDATE MO
			SET
				[MappedObjectName] = JSN.SegmentName,
				[SelectYN] = CONVERT(int, E.SelectYN) * CONVERT(int, EB.SelectYN) * CONVERT(int, JSN.SelectYN)
			FROM 
				[Entity] E
				INNER JOIN [Entity_Book] EB ON EB.EntityID = E.EntityID
				INNER JOIN [Journal_SegmentNo] JSN ON JSN.EntityID = EB.EntityID AND JSN.Book = EB.Book
				INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.Entity = E.MemberKey + CASE WHEN EB.BookTypeBM & 2 > 0 THEN '''' ELSE ''_'' + EB.Book END AND MO.ObjectName = JSN.SegmentCode AND MO.DimensionTypeID = -1
			WHERE
				E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				E.VersionID = ' + CONVERT(nvarchar(15), @VersionID)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Updated = @Updated + @@ROWCOUNT

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
