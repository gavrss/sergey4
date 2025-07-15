SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Table_Dimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@ETLDatabase nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000507,
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
	@ProcedureName = 'spSetup_Table_Dimension',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSetup_Table_Dimension] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DimensionID = -2, @ETLDatabase = 'pcETL_MAS04', @DebugBM = 3
EXEC [spSetup_Table_Dimension] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DimensionID = -65, @ETLDatabase = 'pcETL_MAS04', @DebugBM = 3

EXEC [spSetup_Table_Dimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DimensionName nvarchar(100),
	@TableName nvarchar(100),
	@SQLStatement nvarchar(max),
	@Property nvarchar(100),
	@DataType nvarchar(100),
	@DefaultValue nvarchar(255),
	@SeedMemberID int,

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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create dimension table and/or properties if not already exists.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-427: Adding VersionID to table Dimension_Property.'

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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT @DimensionName = [DimensionName], @SeedMemberID = SeedMemberID FROM [Dimension] WHERE [DimensionID] = @DimensionID
		SET @TableName = '[' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + ']'

		IF @DebugBM & 2 > 0 SELECT [@ETLDatabase] = @ETLDatabase, [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@TableName] = @TableName, [@SeedMemberID] = @SeedMemberID

	SET @Step = 'SP-Specific check'
		IF OBJECT_ID (@TableName, N'U') IS NULL
			SET @Message = 'The table ' + @TableName + ' will be created.'
		ELSE
			GOTO EXITPOINT

	SET @Step = 'Create table'
		SET @SQLStatement = '
			CREATE TABLE ' + @TableName + '(
				[MemberId] [int] IDENTITY(' + CONVERT(nvarchar(15), @SeedMemberID) + ',1) NOT NULL,
				[MemberKey] [nvarchar](100) NOT NULL,
				[Description] [nvarchar](255) NOT NULL,
				[HelpText] [nvarchar](1024) NULL,
				[NodeTypeBM] [int] NOT NULL,
			 CONSTRAINT [PK_pcD_' + @DimensionName + '] PRIMARY KEY CLUSTERED 
			(
				[MemberId] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			CREATE UNIQUE NONCLUSTERED INDEX [pcD_' + @DimensionName + '_MemberKey] ON ' + @TableName + '
			(
				[MemberKey] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Add dimension specific properties'
		IF CURSOR_STATUS('global','AddDimProperty_Cursor') >= -1 DEALLOCATE AddDimProperty_Cursor
		DECLARE AddDimProperty_Cursor CURSOR FOR
			SELECT 
				Property = P.PropertyName + CASE P.DataTypeID WHEN 3 THEN '_MemberID' ELSE '' END,
				DataType = CASE P.DataTypeID WHEN 3 THEN 'int' ELSE DT.DataTypeCode + CASE WHEN DT.SizeYN <> 0 AND P.Size IS NOT NULL THEN '(' + CONVERT(nvarchar(15), P.Size) + ') COLLATE DATABASE_DEFAULT' ELSE '' END END,
				DefaultValue = CASE P.DataTypeID WHEN 3 THEN '-1' ELSE CASE WHEN ISNUMERIC(P.DefaultValueTable) <> 0 THEN P.DefaultValueTable ELSE '''' + P.DefaultValueTable + '''' END END
			FROM
				Property P
				INNER JOIN Dimension_Property DP ON DP.InstanceID IN(0, @InstanceID) AND DP.VersionID IN(0, @VersionID) AND DP.DimensionID IN (@DimensionID) AND DP.PropertyID = P.PropertyID AND DP.SelectYN <> 0
				INNER JOIN DataType DT ON DT.DataTypeID = P.DataTypeID
			WHERE
				P.InstanceID IN(0, @InstanceID) AND 
				P.SelectYN <> 0
			ORDER BY
				P.SortOrder,
				P.PropertyName
				
			OPEN AddDimProperty_Cursor
			FETCH NEXT FROM AddDimProperty_Cursor INTO @Property, @DataType, @DefaultValue

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@Property] = @Property, [@DataType] = @DataType
					SET @SQLStatement = 'ALTER TABLE ' + @TableName + ' ADD [' + @Property + '] ' + @DataType

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DefaultValue IS NOT NULL
						BEGIN
							SET @SQLStatement = 'ALTER TABLE ' + @TableName + ' ADD  CONSTRAINT [DF_pcD_' + @DimensionName + '_' + @Property + '] DEFAULT (' + @DefaultValue + ') FOR [' + @Property + ']'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

					FETCH NEXT FROM AddDimProperty_Cursor INTO @Property, @DataType, @DefaultValue
				END

		CLOSE AddDimProperty_Cursor
		DEALLOCATE AddDimProperty_Cursor	

	SET @Step = 'Add standard properties'
		SET @SQLStatement = '
			ALTER TABLE ' + @TableName + ' ADD [ParentMemberId] int NULL
			ALTER TABLE ' + @TableName + ' ADD [SortOrder] int NOT NULL
			ALTER TABLE ' + @TableName + ' ADD [SBZ] bit NOT NULL
			ALTER TABLE ' + @TableName + ' ADD [Source] nvarchar(50) COLLATE DATABASE_DEFAULT NOT NULL
			ALTER TABLE ' + @TableName + ' ADD [Synchronized] bit NOT NULL
			ALTER TABLE ' + @TableName + ' ADD [Inserted] datetime NOT NULL
			ALTER TABLE ' + @TableName + ' ADD [Updated] datetime NOT NULL
			ALTER TABLE ' + @TableName + ' ADD [UserID] int NOT NULL'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			ALTER TABLE ' + @TableName + ' ADD  CONSTRAINT [DF_pcD_' + @DimensionName + '_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
			ALTER TABLE ' + @TableName + ' ADD  CONSTRAINT [DF_pcD_' + @DimensionName + '_Synchronized]  DEFAULT ((1)) FOR [Synchronized]
			ALTER TABLE ' + @TableName + ' ADD  CONSTRAINT [DF_pcD_' + @DimensionName + '_Inserted]  DEFAULT (getdate()) FOR [Inserted]
			ALTER TABLE ' + @TableName + ' ADD  CONSTRAINT [DF_pcD_' + @DimensionName + '_Updated]  DEFAULT (getdate()) FOR [Updated]
			ALTER TABLE ' + @TableName + ' ADD  CONSTRAINT [DF_pcD_' + @DimensionName + '_UserID]  DEFAULT ((0)) FOR [UserID]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

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
