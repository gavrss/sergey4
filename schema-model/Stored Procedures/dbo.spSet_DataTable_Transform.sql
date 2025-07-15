SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_DataTable_Transform]

	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = 0,

	@DataClassID int = NULL,
	@ApplicationID int = NULL,
	@StorageTypeBM int = NULL,

	@JobID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000225,
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
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1009, @StorageTypeBM = 0, @Debug = 1
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1009, @StorageTypeBM = 2, @Debug = 1
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1015, @StorageTypeBM = 0, @Debug = 1
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1009, @StorageTypeBM = 4, @Debug = 1

EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1009, @StorageTypeBM = 2
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1010, @StorageTypeBM = 2
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1011, @StorageTypeBM = 2
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1012, @StorageTypeBM = 2
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1013, @StorageTypeBM = 2
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1014, @StorageTypeBM = 2
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1015, @StorageTypeBM = 2
EXEC [spSet_DataTable_Transform] @UserID = -10, @InstanceID = 357, @VersionID = 1006, @DataClassID = 1016, @StorageTypeBM = 2

EXEC [spSet_DataTable_Transform] @GetVersion = 1
*/

DECLARE
	@DataClassName nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLStatement_Select nvarchar(max),
	@DataTablePrefix nvarchar(20) = 'pcDC_',
	@InstanceID_String nvarchar(10),
	@DestinationDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@TableName nvarchar(100),
	@StorageTypeBM_DataClass int,

	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'

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
		
		SELECT
			@DataClassName = [DataClassName],
			@StorageTypeBM_DataClass = [StorageTypeBM],
			@InstanceID_String = CASE LEN(@InstanceID) WHEN 1 THEN '000' WHEN 2 THEN '00' WHEN 3 THEN '0' ELSE '' END + CONVERT(nvarchar(10), @InstanceID)
		FROM
			DataClass DC
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.DataClassID = @DataClassID AND
			DC.VersionID = @VersionID

		SELECT
			@ApplicationID = ISNULL(@ApplicationID , MAX(ApplicationID))
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			SelectYN <> 0

		SELECT
			@DestinationDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID
		IF @Debug <> 0 SELECT ApplicationID = @ApplicationID, DestinationDatabase = @DestinationDatabase, ETLDatabase = @ETLDatabase

	SET @Step = 'Check StorageTypeBM'
		IF NOT @StorageTypeBM_DataClass & 1 > 0
			BEGIN
				SET @Message = 'This routine is only valid for internal stored DataClasses (StorageTypeBM = 1)'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp tables'
		SELECT 
			DC.InstanceID,
			DC.[DataClassID],
			DC.[DataClassName],
			DC.[DataClassDescription],
			DCD.DimensionID,
			D.DimensionName,
			D.DimensionDescription,
			DCD.SortOrder
		INTO
			#DC_Dim
		FROM
			[DataClass] DC
			INNER JOIN [DataClass_Dimension] DCD ON DCD.DataClassID = DC.DataClassID --AND DCD.VersionID = DC.VersionID
			INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.DataClassID = @DataClassID AND
			DC.VersionID = @VersionID

		SELECT 
			DC.[DataClassID],
			DC.[DataClassName],
			DC.[DataClassDescription],
			M.[MeasureID],
			M.[MeasureName],
			M.[MeasureDescription],
			M.DataTypeID,
			DT.DataTypeCode,
			SortOrder = M.SortOrder
		INTO
			#DC_Measure
		FROM
			[DataClass] DC
			INNER JOIN [Measure] M ON M.DataClassID = DC.DataClassID AND M.VersionID = DC.VersionID
			INNER JOIN [DataType] DT ON DT.DataTypeID = M.DataTypeID
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.DataClassID = @DataClassID AND
			DC.VersionID = @VersionID

		IF @Debug <> 0
			BEGIN
				SELECT DataClassName = @DataClassName
				SELECT TempTable = '#DC_Dim', * FROM #DC_Dim ORDER BY SortOrder
				SELECT TempTable = '#DC_Measure', *, MeasureLen = LEN(MeasureName) FROM #DC_Measure
			END

	SET @Step = 'Create SQL Statement'
		--Create SELECT statement
		SET @SQLStatement_Select = '
	SELECT
		VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ',
		DataRowID = DR.DataRowID,
		'

		SELECT
			@SQLStatement_Select = @SQLStatement_Select + DimensionName + '_MemberKey = ISNULL(MAX(CASE WHEN DM.DimensionID = ' + CONVERT(nvarchar(10), DimensionID) + ' THEN DM.MemberKey END), ''NONE''),' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
		FROM
			#DC_Dim
		ORDER BY
			SortOrder

		SELECT
			@SQLStatement_Select = @SQLStatement_Select + MeasureName + '_Value = MAX(CASE WHEN DV.MeasureID = ' + CONVERT(nvarchar(10), MeasureID) + ' THEN DV.DataValue END),' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
		FROM
			#DC_Measure
		ORDER BY
			SortOrder

	SELECT
		@SQLStatement_Select = @SQLStatement_Select + 'InsertedBy = MAX(DR.InsertedBy),
		Inserted = MAX(DR.Inserted)
	FROM
		DataRow DR
		INNER JOIN DataValue DV ON DV.DataRowID = DR.DataRowID
		LEFT JOIN [DataClass_Dimension] DCD ON DCD.InstanceID = DR.InstanceID AND DCD.DataClassID =  DR.DataClassID --AND DCD.VersionID = DV.VersionID
		LEFT JOIN Data_DimensionMember DDM ON DDM.InstanceID = DR.InstanceID AND DDM.DataRowID = DR.DataRowID AND DDM.DimensionID = DCD.DimensionID --AND DDM.VersionID = DCD.VersionID
		LEFT JOIN DimensionMember DM ON DM.InstanceID = DDM.InstanceID AND DM.DimensionID = DDM.DimensionID AND DM.MemberKey = DDM.MemberKey
	WHERE
		DV.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
		DV.DataClassID = ' + CONVERT(nvarchar(10), @DataClassID) + ' AND
		DV.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + '
	GROUP BY
		DR.DataRowID'

	IF @Debug <> 0 PRINT @SQLStatement_Select
	IF @StorageTypeBM = 0 EXEC (@SQLStatement_Select)

	SET @Step = 'Create and fill wrk_table'
		IF @StorageTypeBM & 2 > 0
			BEGIN
				SET @TableName = 'wrk_' + @DataTablePrefix + @InstanceID_String + '_' + @DataClassName
				CREATE TABLE #Count ([Counter] int)
				SET @SQLStatement = '
					INSERT INTO #Count ([Counter])
					SELECT 1 FROM ' + @ETLDatabase + '.sys.tables WHERE name = ''' + @TableName + ''''
				EXEC (@SQLStatement)
				IF (SELECT [Counter] FROM #Count) > 0
				EXEC('DROP TABLE ' + @ETLDatabase + '..' + @TableName)

				SET @SQLStatement = '
	CREATE TABLE ' + @ETLDatabase + '..' + @TableName + '
		(
		VersionID int,
		DataRowID bigint,
		'
				SELECT
					@SQLStatement = @SQLStatement + DimensionName + '_MemberKey nvarchar(100),' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
				FROM
					#DC_Dim
				ORDER BY
					SortOrder

				SELECT
					@SQLStatement = @SQLStatement + MeasureName + '_Value ' + DataTypeCode + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
				FROM
					#DC_Measure
				ORDER BY
					SortOrder

				SELECT
					@SQLStatement = @SQLStatement + 'InsertedBy nvarchar(100),' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'Inserted datetime' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ')'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @SQLStatement = '
	INSERT INTO ' + @ETLDatabase + '..' + @TableName +  + '
		(
		VersionID,
		DataRowID,
		'
				SELECT
					@SQLStatement = @SQLStatement + DimensionName + '_MemberKey,' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
				FROM
					#DC_Dim
				ORDER BY
					SortOrder

				SELECT
					@SQLStatement = @SQLStatement + MeasureName + '_Value,' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
				FROM
					#DC_Measure
				ORDER BY
					SortOrder

				SELECT
					@SQLStatement = @SQLStatement + 'InsertedBy,' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'Inserted' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ')' + CHAR(13) + CHAR(10) + CHAR(9) + @SQLStatement_Select

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @Debug <> 0 EXEC('SELECT * FROM ' + @DataTablePrefix + @DataClassName)
				
				DROP TABLE #Count
			END

	SET @Step = 'Update Callisto'
		IF @StorageTypeBM & 4 > 0
			BEGIN
				SET @Message = 'Deployment to Callisto not yet implemented'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #DC_Dim
		DROP TABLE #DC_Measure

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
