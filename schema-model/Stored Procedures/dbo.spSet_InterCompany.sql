SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_InterCompany]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@JournalTable nvarchar(100) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@Scenario nvarchar(50) = 'ACTUAL', --Optional filter, ACTUAL by default
	@FiscalYear int = NULL, --Optional filter
	@Entity_MemberKey nvarchar(50) = NULL, --Optional filter

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000766,
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

!!!!OBSOLETE - Replaced by spBR_BR14!!!!!!!!!!


EXEC [spSet_InterCompany] @UserID=-10, @InstanceID=529, @VersionID=1001, @DebugBM=3
--, @Scenario = 'ACTUAL', @JournalTable = '[pcETL_EPIC].[dbo].[Journal]', @ConsolidationGroup = 'G_INTERFOR', @FiscalYear = 2020, @Entity_MemberKey = 'GILCHRIS', @DebugBM=2

EXEC [spSet_InterCompany] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@InterCompany_DimensionName nvarchar(100),
	@JournalColumn nvarchar(50),

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
	@Version nvarchar(50) = '2.1.1.2170'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set InterCompanyEntity column in the Journal table.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2170' SET @Description = 'Procedure created.'

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

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			pcINTEGRATOR_Data..[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @DebugBM & 2 > 0 
			SELECT
				[@JournalTable] = @JournalTable,
				[@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'Create temp table #InterCompanySelection'
		SELECT	
			InstanceID = E.InstanceID,
			VersionID = E.VersionID,
			EntityID = E.EntityID,
			Entity = E.MemberKey,
			Book = EB.Book,
			InterCompany_DimensionID = D.DimensionID,
			DimensionTypeID = D.DimensionTypeID,
			InterCompany_DimensionName = D.DimensionName,
			InterCompany_PropertyName = SUBSTRING(EPV.EntityPropertyValue, CHARINDEX('.', EPV.EntityPropertyValue) + 1, LEN(EPV.EntityPropertyValue) - CHARINDEX('.', EPV.EntityPropertyValue)),
			JournalColumn = CONVERT(nvarchar(50), '')
		INTO
			#InterCompanySelection
		FROM
			pcINTEGRATOR_Data..Entity E
			INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND BookTypeBM & 3 = 3 AND EB.SelectYN <> 0
			INNER JOIN pcINTEGRATOR_Data..EntityPropertyValue EPV ON EPV.InstanceID = E.InstanceID AND EPV.VersionID = E.VersionID AND EPV.EntityID = E.EntityID AND EPV.EntityPropertyTypeID = -8 AND EPV.SelectYN <> 0
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = LEFT(EPV.EntityPropertyValue, CHARINDEX('.', EPV.EntityPropertyValue) -1)
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			(E.MemberKey = @Entity_MemberKey OR @Entity_MemberKey IS NULL) AND
			E.SelectYN <> 0
	
		IF @DebugBM & 2 > 0 SELECT TempTable = '#InterCompanySelection', * FROM #InterCompanySelection

	SET @Step = 'Handle references to segments'	
		UPDATE ICS
		SET
			JournalColumn = 'Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), JSN.[SegmentNo])
		FROM
			#InterCompanySelection ICS 
			INNER JOIN pcINTEGRATOR_Data..[Journal_SegmentNo] JSN ON JSN.[InstanceID] = ICS.InstanceID AND JSN.[VersionID] = ICS.VersionID AND JSN.[EntityID] = ICS.[EntityID] AND JSN.[DimensionID] = ICS.InterCompany_DimensionID AND JSN.[SelectYN] <> 0
			INNER JOIN pcINTEGRATOR_Data..[Entity] E ON E.[InstanceID] = JSN.[InstanceID] AND E.[VersionID] = JSN.[VersionID] AND E.[EntityID] = JSN.[EntityID] AND E.[SelectYN] <> 0 AND E.[DeletedID] IS NULL AND (E.MemberKey = @Entity_MemberKey OR @Entity_MemberKey IS NULL)
			INNER JOIN pcINTEGRATOR_Data..[Entity_Book] EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND EB.BookTypeBM & 3 = 3 AND EB.[SelectYN] <> 0 
		WHERE
			ICS.DimensionTypeID = -1

		IF @DebugBM & 2 > 0 SELECT TempTable = '#InterCompanySelection', * FROM #InterCompanySelection	
		
	SET @Step = 'Handle references to Account and other columns'	
		--Not yet handled

	SET @Step = 'Set InterCompanyEntity to NULL for relevant rows'
		SET @SQLStatement = '
			UPDATE J
			SET
				InterCompanyEntity = NULL
			FROM
				' + @JournalTable + ' J
			WHERE
				J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				J.ConsolidationGroup IS NULL AND
				J.InterCompanyEntity IS NOT NULL 
				' + CASE WHEN @Scenario IS NOT NULL THEN 'AND J.Scenario = ''' + @Scenario + '''' ELSE '' END + '
				' + CASE WHEN @FiscalYear IS NOT NULL THEN 'AND J.FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) ELSE '' END + '
				' + CASE WHEN @Entity_MemberKey IS NOT NULL THEN 'AND J.Entity = ''' + @Entity_MemberKey + '''' ELSE '' END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'JournalColumn_Cursor'
		IF CURSOR_STATUS('global','JournalColumn_Cursor') >= -1 DEALLOCATE JournalColumn_Cursor
		DECLARE JournalColumn_Cursor CURSOR FOR
			
			SELECT DISTINCT
				InterCompany_DimensionName,
				JournalColumn
			FROM
				#InterCompanySelection
			ORDER BY
				JournalColumn

			OPEN JournalColumn_Cursor
			FETCH NEXT FROM JournalColumn_Cursor INTO @InterCompany_DimensionName, @JournalColumn

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@InterCompany_DimensionName] = @InterCompany_DimensionName, [@JournalColumn] = @JournalColumn
				
					SET @SQLStatement = '
						UPDATE J
						SET
							InterCompanyEntity = E.[Label]
						FROM
							' + @JournalTable + ' J
							INNER JOIN #InterCompanySelection ICS ON ICS.[Entity] = J.[Entity] AND ICS.[InterCompany_DimensionName] = ''' + @InterCompany_DimensionName + ''' AND ICS.[JournalColumn] = ''' + @JournalColumn + ''' 
							INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @InterCompany_DimensionName + ' IC ON IC.[Label] = J.[' + @JournalColumn + ']
							INNER JOIN ' + @CallistoDatabase + '..S_DS_Entity E ON E.[MemberId] = IC.[Entity_MemberId]
						WHERE
							J.ConsolidationGroup IS NULL
							' + CASE WHEN @Scenario IS NOT NULL THEN 'AND J.Scenario = ''' + @Scenario + '''' ELSE '' END + '
							' + CASE WHEN @FiscalYear IS NOT NULL THEN 'AND J.FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) ELSE '' END

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Updated = @Updated + @@ROWCOUNT

					FETCH NEXT FROM JournalColumn_Cursor INTO @InterCompany_DimensionName, @JournalColumn
				END

		CLOSE JournalColumn_Cursor
		DEALLOCATE JournalColumn_Cursor

	SET @Step = 'Drop the temp tables'
		DROP TABLE #InterCompanySelection

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
