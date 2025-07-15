SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Search_Procedure]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 1, --1=ChangeDate, 2=SearchString
	@SearchString nvarchar(50) = NULL,
	@CheckDate nvarchar(50) = '2018-10-15 07:00',
	@DatabaseName nvarchar(100) = 'pcINTEGRATOR',
	@ExcludeBackupObjectYN bit = 1,
	@OrderBy nvarchar(50) = '[Updated] DESC',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = 50,
	@ProcedureID int = 880000478,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC [sp_Tool_Search_Procedure] @ResultTypeBM = 2, @SearchString = 'XXX', @DatabaseName = 'pcINTEGRATOR', @OrderBy = '[Procedure]'

EXEC [sp_Tool_Search_Procedure] @ResultTypeBM = 1, @Rows = 400 --, @Debug = 1
EXEC [sp_Tool_Search_Procedure] @ResultTypeBM = 2, @SearchString = 'tmp_User_Instance', @DatabaseName = 'pcINTEGRATOR_Data'
EXEC [sp_Tool_Search_Procedure] @ResultTypeBM = 2, @SearchString = '[@ErrorNumber]', @DatabaseName = 'pcINTEGRATOR', @OrderBy = '[Procedure]', @Rows=200, @Debug=0
EXEC [sp_Tool_Search_Procedure] @ResultTypeBM = 2, @SearchString = 'GUID', @DatabaseName = 'pcINTEGRATOR', @OrderBy = '[Procedure]'
EXEC [sp_Tool_Search_Procedure] @ResultTypeBM = 2, @SearchString = 'DimensionHierarchy', @DatabaseName = 'pcINTEGRATOR', @OrderBy = '[Procedure]'
EXEC [sp_Tool_Search_Procedure] @ResultTypeBM = 2, @SearchString = 'DimensionHierarchyLevel', @DatabaseName = 'pcINTEGRATOR', @OrderBy = '[Procedure]'
EXEC [sp_Tool_Search_Procedure] @ResultTypeBM = 2, @SearchString = 'Dimension_Property', @DatabaseName = 'pcINTEGRATOR', @OrderBy = '[Procedure]'
EXEC [sp_Tool_Search_Procedure] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@ProcName nvarchar(100),
	@StepNo int = 1,
	@RetryYN bit,
	@CreateDate datetime,
	@ModifyDate datetime,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
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
	@Version nvarchar(50) = '2.1.1.2177'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Search for SPs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.3' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Enhanced structure. Renamed to [sp_Tool_Check_ProceduresChanged].'
		IF @Version = '2.0.2.2148' SET @Description = 'Added @SearchString. Renamed to [sp_Tool_Search_Procedure]. Added @DatabaseName for @ResultTypeBM = 2.'
		IF @Version = '2.0.3.2151' SET @Description = 'SET ANSI_WARNINGS ON.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added parameter @OrderBy.'
		IF @Version = '2.1.0.2159' SET @Description = 'Added ProcedureDescription in return recordset.'
		IF @Version = '2.1.1.2177' SET @Description = 'Added ESCAPE character to @SearchString.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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
			@UserID = ISNULL(@UserID, -10),
			@InstanceID = ISNULL(@InstanceID, 0),
			@VersionID = ISNULL(@VersionID, 0)

	SET @Step = 'Create temp tables'
		CREATE TABLE #Procedures
			(
			[ProcedureName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Version] nvarchar(100) COLLATE DATABASE_DEFAULT, 
			[modify_date] datetime,
			[create_date] datetime
			)

		CREATE Table #Version
			(
			[ProcedureID] int,
			[ProcedureName] nvarchar(100),
			[ProcedureDescription] nvarchar(255),
			[Version] nvarchar(100),
			[VersionDescription] nvarchar(255),
			[CreatedBy] nvarchar(100),
			[ModifiedBy] nvarchar(100)
			)

		CREATE TABLE #ProcVer
			(
			[ProcedureID] int,
			[Procedure] nvarchar(100),
			[ProcedureDescription] nvarchar(255),
			[Version] nvarchar(100),
			[VersionDescription] nvarchar(255),
			[Created] datetime,
			[Updated] datetime
			)

	SET @Step = 'Date search'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #Procedures
						(
						[ProcedureName],
						[modify_date],
						[create_date]
						)
					SELECT TOP ' + CONVERT(nvarchar(50), @Rows) + '
						[ProcedureName] = P.[name],
						[modify_date] = P.[modify_date],
						[create_date] = P.[create_date]
					FROM
						[' + @DatabaseName + '].[sys].[procedures] P
					WHERE
						modify_date >= ''' + @CheckDate + '''' +
						CASE WHEN @ExcludeBackupObjectYN <> 0 THEN ' AND ISNUMERIC(RIGHT(P.[name], 8)) = 0 AND RIGHT(P.[name], 3) NOT IN (''New'', ''Old'', ''Org'') AND P.[name] NOT LIKE ''spA_%'''  ELSE '' END + '
					ORDER BY
						P.[modify_date] DESC'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Search string'
		IF @ResultTypeBM & 2 > 0 AND @SearchString IS NOT NULL
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #Procedures
						(
						[ProcedureName],
						[modify_date],
						[create_date]
						)
					SELECT TOP ' + CONVERT(nvarchar(50), @Rows) + '
						[ProcedureName] = P.[name],
						[modify_date] = P.[modify_date],
						[create_date] = P.[create_date]
					FROM
						[' + @DatabaseName + '].sys.sql_modules M
						INNER JOIN [' + @DatabaseName + '].sys.procedures P ON P.object_id = M.object_id
					WHERE
						M.[definition] LIKE ''%' + REPLACE(REPLACE(REPLACE(REPLACE(@SearchString, '[', '½['), ']', '½]'), '_', '½_'), '%', '½%') + '%'' ESCAPE ''½''' +
						CASE WHEN @ExcludeBackupObjectYN <> 0 THEN ' AND ISNUMERIC(RIGHT(P.[name], 8)) = 0 AND RIGHT(P.[name], 3) NOT IN (''New'', ''Old'', ''Org'') AND P.[name] NOT LIKE ''spA_%'''  ELSE '' END + '
					ORDER BY
						P.[modify_date] DESC'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Run Version_Cursor'
		SELECT
			[ProcName] = Pr.[name],
			[GetVersionYN] = CASE WHEN Pa1.object_id IS NOT NULL THEN 1 ELSE 0 END,
			[ProcedureIDYN] = CASE WHEN Pa2.object_id IS NOT NULL THEN 1 ELSE 0 END,
			P.[modify_date],
			P.[create_date]
		INTO
			#Version_Cursor_Table
		FROM
			#Procedures P
			INNER JOIN pcINTEGRATOR.sys.Procedures Pr ON Pr.[name] = P.ProcedureName
			LEFT JOIN pcINTEGRATOR.sys.Parameters Pa1 ON Pa1.object_id = Pr.object_id AND Pa1.name = '@GetVersion'
			LEFT JOIN pcINTEGRATOR.sys.Parameters Pa2 ON Pa2.object_id = Pr.object_id AND Pa2.name = '@ProcedureID'
		WHERE
			Pr.[name] NOT LIKE '%_New' AND
			Pr.[name] NOT LIKE '%_Old' AND 
			Pr.[name] NOT LIKE '%_tmp' AND 
			Pr.[create_date] NOT BETWEEN '2017-07-26 14:57:34.100' AND '2017-07-26 14:57:34.900' AND 
			ISNUMERIC(RIGHT(Pr.[name], 3)) = 0 AND
			Pr.[name] NOT IN ('spAdvanced_Setup', 'sp_alterdiagram', 'sp_creatediagram', 'sp_dropdiagram', 'sp_helpdiagramdefinition', 'sp_helpdiagrams', 'sp_renamediagram', 'sp_upgraddiagrams')
		ORDER BY
			Pr.[name]

		IF @Debug <> 0 SELECT TempTable = '#Version_Cursor_Table', * FROM #Version_Cursor_Table ORDER BY [ProcName]

		IF CURSOR_STATUS('global','Version_Cursor') >= -1 DEALLOCATE Version_Cursor
		DECLARE Version_Cursor CURSOR FOR

		SELECT
			PVC.[ProcName],
			[create_date],
			[modify_date]
		FROM
			#Version_Cursor_Table PVC
		WHERE
			[GetVersionYN] <> 0 AND
			[ProcedureIDYN] <> 0
		ORDER BY
			PVC.[ProcName]

		OPEN Version_Cursor

		FETCH NEXT FROM Version_Cursor INTO @ProcName, @CreateDate, @ModifyDate

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @Debug <> 0 SELECT [@StepNo] = @StepNo, [@ProcName] = @ProcName

				TRUNCATE TABLE #Version
				
				SELECT @StepNo = 1, @RetryYN = 1
				WHILE (@RetryYN <> 0)
				BEGIN
					BEGIN TRY
						IF @StepNo = 1 
							BEGIN                 
								SET @SQLStatement = '
									INSERT INTO #Version ([ProcedureID], [ProcedureName], [ProcedureDescription], [Version], [VersionDescription], [CreatedBy], [ModifiedBy]) EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
								EXEC (@SQLStatement)
								SET @RetryYN = 0
							END
						ELSE IF @StepNo = 2
							BEGIN
								SET @SQLStatement = '
									INSERT INTO #Version ([Version], [VersionDescription], [ProcedureID]) EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
								EXEC (@SQLStatement)
								SET @RetryYN = 0
							END
						ELSE IF @StepNo = 3
							BEGIN                 
								SET @SQLStatement = '
									INSERT INTO #Version ([ProcedureID], [ProcedureName], [ProcedureDescription], [Version], [VersionDescription]) EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
								EXEC (@SQLStatement)
								SET @RetryYN = 0
							END
						ELSE IF @StepNo = 4
							BEGIN
								SET @SQLStatement = '
									INSERT INTO #Version ([Version], [VersionDescription]) EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
								EXEC (@SQLStatement)
								SET @RetryYN = 0
							END
						ELSE IF @StepNo = 5
							BEGIN
								IF @Debug <> 0 SELECT [@ProcName] = @ProcName
								SET @SQLStatement = '
									EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
								EXEC (@SQLStatement)
								SET @RetryYN = 0
							END
						ELSE
							SET @RetryYN = 0
					END TRY 

					BEGIN CATCH
						IF @Debug <> 0 SELECT [@StepNo] = @StepNo, [@ErrorNumber] = ERROR_NUMBER(), [@ErrorSeverity] = ERROR_SEVERITY(), [@ErrorState] = ERROR_STATE(), [@ErrorProcedure] = ERROR_PROCEDURE(), [@ErrorLine] = ERROR_LINE(), [@ErrorMessage] = ERROR_MESSAGE()
						SET @StepNo = @StepNo + 1
					END CATCH 
				END 

				INSERT INTO #ProcVer 
					(
					[ProcedureID],
					[Procedure],
					[ProcedureDescription],
					[Version],
					[VersionDescription],
					[Created],
					[Updated]
					)
				SELECT
					[ProcedureID],
					[Procedure] = @ProcName,
					[ProcedureDescription],
					[Version],
					[VersionDescription],
					[Created] = @CreateDate,
					[Updated] = @ModifyDate
				FROM
					#Version

				FETCH NEXT FROM Version_Cursor INTO @ProcName, @CreateDate, @ModifyDate
			END

		CLOSE Version_Cursor
		DEALLOCATE Version_Cursor

		INSERT INTO #ProcVer
			(
			[Procedure],
			[Created],
			[Updated]
			)
		SELECT
			[Procedure] = P.[ProcedureName],
			[Created] = P.[create_date],
			[Updated] = P.[modify_date]
		FROM
			#Procedures P
		WHERE
			NOT EXISTS (SELECT 1 FROM #ProcVer D WHERE D.[Procedure] = P.[ProcedureName])

	SET @Step = 'Return Rows'
		SET @SQLStatement = '
			SELECT
				*
			FROM
				#ProcVer
			ORDER BY
				' + @OrderBy

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Drop temp table'
		DROP TABLE #Procedures
		DROP TABLE #ProcVer
		DROP TABLE #Version
		DROP TABLE #Version_Cursor_Table

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
