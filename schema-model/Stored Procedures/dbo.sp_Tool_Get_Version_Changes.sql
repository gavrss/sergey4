SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Get_Version_Changes] 
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ShowAll bit = 0,
	@ShowVersion nvarchar(50) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000419,
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
EXEC [sp_Tool_Get_Version_Changes] @Debug = 1
EXEC [sp_Tool_Get_Version_Changes] @ShowAll = 0, @ShowVersion = NULL
EXEC [sp_Tool_Get_Version_Changes] @ShowAll = 0, @ShowVersion = '1.2.2053'
EXEC [sp_Tool_Get_Version_Changes] @ShowAll = 0, @ShowVersion = '1.3.2088'
EXEC [sp_Tool_Get_Version_Changes] @ShowAll = 0, @ShowVersion = '1.3.210'
EXEC [sp_Tool_Get_Version_Changes] @ShowAll = 0, @ShowVersion = '2.0.3.2152'
EXEC [sp_Tool_Get_Version_Changes] @ShowAll = 0, @ShowVersion = '2.0.3.2153'
EXEC [sp_Tool_Get_Version_Changes] @ShowAll = 0, @ShowVersion = '2.1.0.2158'
EXEC [sp_Tool_Get_Version_Changes] @ShowAll = 0, @ShowVersion = 'CUSTOM'
EXEC [sp_Tool_Get_Version_Changes] @ShowAll = 1, @Debug = 1

EXEC [sp_Tool_Get_Version_Changes] @GetVersion = 1
*/

SET NOCOUNT ON

DECLARE
	@ProcName nvarchar(100),
	@ProcVersion nvarchar(50),
	@TableName nvarchar(100),
	@SQLStatement nvarchar(max),
	@StepNo int,
	@RetryYN bit,
	@ParameterName nvarchar(50),
	@SortOrder int = 0,
	@Parameters int,

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Show all changes for a specific version.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.2.2053' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Enhanced structure. Renamed to [sp_Tool_Get_Version_Changes] from [spGet_Version_Changes].'
		IF @Version = '2.0.2.2145' SET @Description = 'Show dates in list of changed SPs.'
		IF @Version = '2.0.2.2147' SET @Description = 'Exclude SPs from cursor that are excluded from registration in table Procedure.'
		IF @Version = '2.0.3.2154' SET @Description = 'Show CreatedBy and ModifiedBy.'
		IF @Version = '2.1.1.2171' SET @Description = 'Show invalid SPs.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set Procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @ShowVersion IS NULL EXEC [spGet_Version] @GetVersion = 0, @Version = @ShowVersion OUTPUT

		IF @Debug <> 0 SELECT [@ShowVersion] = @ShowVersion

	SET @Step = 'Create temp tables'
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
			[Procedure] nvarchar(100),
			[Version] nvarchar(100),
			[Description] nvarchar(255),
			[ProcedureID] int,
			[CreatedBy] nvarchar(100),
			[Created] datetime,
			[ModifiedBy] nvarchar(100),
			[Updated] datetime
			)

	SET @Step = 'Run Proc_Ver_Cursor'
		SELECT
			[ProcName] = Pr.[name],
			[GetVersionYN] = CASE WHEN Pa1.object_id IS NOT NULL THEN 1 ELSE 0 END,
			[ProcedureIDYN] = CASE WHEN Pa2.object_id IS NOT NULL THEN 1 ELSE 0 END
		INTO
			#Proc_Ver_Cursor_Table
		FROM
			pcINTEGRATOR.sys.Procedures Pr
			LEFT JOIN pcINTEGRATOR.sys.Parameters Pa1 ON Pa1.object_id = Pr.object_id AND Pa1.name = '@GetVersion'
			LEFT JOIN pcINTEGRATOR.sys.Parameters Pa2 ON Pa2.object_id = Pr.object_id AND Pa2.name = '@ProcedureID'
		WHERE
			Pr.[name] NOT LIKE '%_New' AND
			Pr.[name] NOT LIKE '%_Old' AND 
			Pr.[name] NOT LIKE '%_tmp' AND
			Pr.[name] NOT LIKE '%_HC' AND 
			Pr.[create_date] NOT BETWEEN '2017-07-26 14:57:34.100' AND '2017-07-26 14:57:34.900' AND 
			ISNUMERIC(RIGHT(Pr.[name], 3)) = 0 AND
			Pr.[name] NOT IN ('spAdvanced_Setup', 'sp_alterdiagram', 'sp_creatediagram', 'sp_dropdiagram', 'sp_helpdiagramdefinition', 'sp_helpdiagrams', 'sp_renamediagram', 'sp_upgraddiagrams')
		ORDER BY
			Pr.[name]

		IF @Debug <> 0 SELECT TempTable = '#Proc_Ver_Cursor_Table', * FROM #Proc_Ver_Cursor_Table ORDER BY [ProcName]

		IF CURSOR_STATUS('global','Proc_Ver_Cursor') >= -1 DEALLOCATE Proc_Ver_Cursor
		DECLARE Proc_Ver_Cursor CURSOR FOR
		SELECT
			PVC.[ProcName]
		FROM
			#Proc_Ver_Cursor_Table PVC
		WHERE
			[GetVersionYN] <> 0 AND
			[ProcedureIDYN] <> 0
		ORDER BY
			PVC.[ProcName]

		OPEN Proc_Ver_Cursor

		FETCH NEXT FROM Proc_Ver_Cursor INTO @ProcName

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @Debug <> 0 SELECT [@StepNo] = @StepNo
				IF @Debug <> 0 SELECT [@ProcName] = @ProcName
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
									INSERT INTO #Version ([ProcedureName], [Version]) SELECT [ProcedureName] = ''' + @ProcName + ''', [Version] = ''' + @ShowVersion + ''''
								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
								SET @RetryYN = 0
							END
						ELSE IF @StepNo = 6
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
					[Procedure],
					[Version],
					[Description],
					[ProcedureID],
					[CreatedBy],
					[ModifiedBy]
					)
				SELECT
					[Procedure] = @ProcName,
					[Version],
					[Description] = VersionDescription,
					[ProcedureID],
					[CreatedBy],
					[ModifiedBy]
				FROM
					#Version

				FETCH NEXT FROM Proc_Ver_Cursor INTO @ProcName
			END

		CLOSE Proc_Ver_Cursor
		DEALLOCATE Proc_Ver_Cursor

BEGIN TRY
	SET @Step = 'Update #ProcVer'
		UPDATE PV
		SET
			[Created] = P.create_date,
			[Updated] = P.modify_date
		FROM
			#ProcVer PV
			INNER JOIN sys.procedures P ON P.[name] = PV.[Procedure]

	SET @Step = 'Show changed procedures'
		SELECT
			[Procedure] = CONVERT(nvarchar(50), [Procedure]),
			[Version] = CONVERT(nvarchar(10), [Version]),
			[Description] = CONVERT(nvarchar(100), [Description]),
			[ProcedureID],
			[CreatedBy],
			[Created],
			[ModifiedBy],
			[Modified] = [Updated]
		FROM
			#ProcVer 
		WHERE
			@ShowAll <> 0 OR
			[Version] LIKE '%' + @ShowVersion + '%'
		ORDER BY
			[Updated] DESC,
			[Procedure]

	SET @Step = 'Show changed metadata'
		CREATE TABLE #RowCount ([RowCount] int)

		DECLARE Table_Ver_Cursor CURSOR FOR

		SELECT
			T.[name]
		FROM
			pcINTEGRATOR.sys.tables T
			INNER JOIN pcINTEGRATOR.sys.columns C ON C.object_id = T.object_id AND C.name = 'Version' AND C.user_type_id = 231
		WHERE
			T.[name] NOT IN ('JobLog', 'Procedure', 'ProcedureParameter')
		ORDER BY
			T.[name]

		OPEN Table_Ver_Cursor

		FETCH NEXT FROM Table_Ver_Cursor INTO @TableName

		WHILE @@FETCH_STATUS = 0
			BEGIN
				TRUNCATE TABLE #RowCount
				SET @SQLStatement = '
				SELECT [RowCount] = COUNT(1) FROM pcINTEGRATOR..[' + @TableName + '] WHERE [Version] LIKE ''%' + @ShowVersion + '%'''
				IF @Debug <> 0 PRINT @SQLStatement
				INSERT INTO #RowCount EXEC (@SQLStatement)
				IF (SELECT [RowCount] FROM #RowCount) > 0
					BEGIN
						SET @SQLStatement = '
						SELECT TableName = ''' + @TableName + ''', * FROM pcINTEGRATOR..[' + @TableName + '] WHERE [Version] LIKE ''%' + @ShowVersion + '%'''
						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END

				FETCH NEXT FROM Table_Ver_Cursor INTO @TableName
			END

		CLOSE Table_Ver_Cursor
		DEALLOCATE Table_Ver_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE #Version
		DROP TABLE #ProcVer
		DROP TABLE #RowCount
		DROP TABLE #Proc_Ver_Cursor_Table

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
