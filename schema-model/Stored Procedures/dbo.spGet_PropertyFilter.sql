SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_PropertyFilter]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DatabaseName nvarchar(100) = NULL, --Mandatory
	@DimensionID int = NULL,
	@DimensionName nvarchar(100) = NULL, --Mandatory
	@PropertyName nvarchar(100) = NULL, --Mandatory
	@Filter nvarchar(4000) = NULL OUT,
	@StorageTypeBM_DataClass int = 4, --3 returns _PropertyKey, 4 returns _MemberId
	@StorageTypeBM int = NULL, --Mandatory
	@EqualityString nvarchar(10) = NULL, --Mandatory
	@JournalColumn nvarchar(50) = NULL,
	@PropertyFilter nvarchar(max) = NULL OUT, --Mandatory
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000440,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spGet_PropertyFilter',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

DECLARE @PropertyFilter nvarchar(4000)
EXEC spGet_PropertyFilter @UserID=-10, @InstanceID=-1001, @VersionID=-1001, @DatabaseName='pcDATA_TUF', @DimensionName='Employees', @PropertyName = 'Other', @Filter= 'Weekend', @StorageTypeBM=4, @PropertyFilter=@PropertyFilter OUT, @Debug = 1
SELECT LeafLevelFilter = @PropertyFilter

EXEC [spGet_PropertyFilter] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@PropertyKey nvarchar(4000), 
	@CharIndex int,
	@CheckID int = 0,
	@HasChild bit = 0,
	@SQLStatement nvarchar(max),
	@MappingTypeID int,

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
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return correct where clause for selected filter',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added parameter DimensionID.'
		IF @Version = '2.1.2.2191' SET @Description = 'Handle @JournalColumn. Handle MappingTypeID.'

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

		IF @DimensionID IS NULL
			SELECT @DimensionID = DimensionID FROM Dimension WHERE InstanceID IN (0, @InstanceID) AND DimensionName = @DimensionName

		IF @DimensionName IS NULL
			SELECT @DimensionName = DimensionName FROM Dimension WHERE InstanceID IN (0, @InstanceID) AND DimensionID = @DimensionID

		SELECT
			@MappingTypeID = [MappingTypeID]
		FROM
			pcINTEGRATOR_Data..Dimension_StorageType
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

	SET @Step = 'Check @StorageTypeBM'
		IF @StorageTypeBM & 2 > 0
			BEGIN
				SET @PropertyFilter = @Filter
				SET @Message = '@StorageTypeBM = ' + CONVERT(nvarchar(10), @StorageTypeBM) + ', not yet implemented'
				SET @Severity = 16
				GOTO EXITPOINT
			END

 	SET @Step = 'Get @PropertyFilter' 
		SET @PropertyFilter = ''

		CREATE TABLE #PropertyKey
			(
			[PropertyKey] nvarchar(100) COLLATE DATABASE_DEFAULT NOT NULL
			)

		IF LEN(@Filter) > 0
			BEGIN
				SET @PropertyKey = @Filter
	
				WHILE CHARINDEX (',', @PropertyKey) > 0
					BEGIN
						SET @CharIndex = CHARINDEX(',', @PropertyKey)
						IF @Debug <> 0 SELECT [CharIndex] = @CharIndex
						IF @Debug <> 0 SELECT PropertyKey = LTRIM(RTRIM(LEFT(@PropertyKey, @CharIndex - 1)))
						IF CHARINDEX('%', LTRIM(RTRIM(LEFT(@PropertyKey, @CharIndex - 1)))) > 0
							BEGIN
								SET @SQLStatement = '
									INSERT INTO #PropertyKey
										(
										[PropertyKey]
										)
									SELECT DISTINCT
										[PropertyKey] = D.[' + @PropertyName + ']
									FROM
										' + @DatabaseName + '..S_DS_' + @DimensionName + ' D
									WHERE
										D.[' + @PropertyName + '] LIKE ''' + LTRIM(RTRIM(LEFT(@PropertyKey, @CharIndex - 1))) + ''''

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
							END
						ELSE
							INSERT INTO #PropertyKey ([PropertyKey]) SELECT LTRIM(RTRIM(LEFT(@PropertyKey, @CharIndex - 1)))
						
						SET @PropertyKey = SUBSTRING(@PropertyKey, @CharIndex + 1, LEN(@PropertyKey) - @CharIndex)
					END

				IF CHARINDEX('%', LTRIM(RTRIM(@PropertyKey))) > 0
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #PropertyKey
								(
								[PropertyKey]
								)
							SELECT
								[PropertyKey] = D.[Label
							FROM
								' + @DatabaseName + '..S_DS_' + @DimensionName + ' D
							WHERE
								D.Label LIKE ''' + LTRIM(RTRIM(@PropertyKey)) + ''''

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
					END
				ELSE
					INSERT INTO #PropertyKey ([PropertyKey]) SELECT LTRIM(RTRIM(@PropertyKey)) WHERE LTRIM(RTRIM(@PropertyKey)) <> 'All_'
			END

		IF @Debug <> 0 SELECT TempTable = '#PropertyKey', * FROM #PropertyKey

		SET @PropertyFilter = ISNULL(@PropertyFilter, '')

		IF @StorageTypeBM_DataClass & 4 > 0
			SELECT 
				@PropertyFilter = @PropertyFilter + '''' + PropertyKey + '''' + ','
			FROM
				#PropertyKey

		SET @PropertyFilter = LEFT(@PropertyFilter, LEN(@PropertyFilter) - 1)

		SET @PropertyFilter = 'INNER JOIN [' + @DatabaseName + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] ON [' + @DimensionName + '].[' + CASE WHEN @MappingTypeID = 0 THEN 'Label' ELSE 'MemberKeyBase' END + '] = ' + CASE WHEN @JournalColumn IS NOT NULL THEN 'J.[' + @JournalColumn + ']' ELSE 'V.[' + @DimensionName + ']' END + ' AND [' + @DimensionName + '].[' + @PropertyName + '] ' + @EqualityString + ' (' + @PropertyFilter + ')'

		IF @Debug <> 0 SELECT [@PropertyFilter] = @PropertyFilter

	SET @Step = 'Drop temp tables'
		DROP TABLE #PropertyKey

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
--		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
