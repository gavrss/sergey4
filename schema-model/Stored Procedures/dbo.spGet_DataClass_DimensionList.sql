SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_DataClass_DimensionList]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,
	@MasterDataClassID int = NULL,
	@DimensionList nvarchar(1024) = NULL,
	@DimensionListExcluded nvarchar(1024) = NULL,
	@VisibleNoList nvarchar(1024) = NULL,
	@AssignmentID int = NULL, --Optional
	@OrganizationPositionID int = NULL, --Optional
	@ResultTypeBM int = 3, --1=Dimensions, 2=Measures

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000520,
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
EXEC [dbo].[spGet_DataClass_DimensionList] 
	@UserID = -10,
	@InstanceID = -1335,
	@VersionID = -1273,
	@DataClassID = 7480,
	@DimensionList = '-1|-4|-6|-7|-31|-66',
	@VisibleNoList = '-1|-31',
	@ResultTypeBM = 3,
	@Debug = 1

EXEC [dbo].[spGet_DataClass_DimensionList] 
	@UserID = 8245,
	@InstanceID = 454,
	@VersionID = 1021,
	@DataClassID = 7736,
	@ResultTypeBM = 3,
	@Debug = 1

EXEC [spGet_DataClass_DimensionList] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spGet_DataClass_DimensionList] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DimCalledYN bit = 1,
	@MeasureCalledYN bit = 1,
	@InitialWorkflowStateID int,
	@DimensionName nvarchar(50),
	@StorageTypeBM int,
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@DataClassName nvarchar(100),

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
	@Version nvarchar(50) = '2.1.2.2183'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Sub routine to fill #DimensionList and get list of dimension filters',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2149' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2153' SET @Description = 'Added parameter @DimensionList, @VisibleNoList'
		IF @Version = '2.1.0.2157' SET @Description = 'Added parameter @DimensionListExcluded.'
		IF @Version = '2.1.0.2162' SET @Description = 'Set default values.'
		IF @Version = '2.1.2.2179' SET @Description = 'Read from #FilterTable as an alternative to read from #DimensionList.'
		IF @Version = '2.1.2.2183' SET @Description = 'Handle dimension -77 (TimeView).'

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

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

		SELECT
			@DataClassName = DataClassName
		FROM
			pcINTEGRATOR_Data.dbo.DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassID = @DataClassID

		IF @OrganizationPositionID IS NULL AND @AssignmentID IS NOT NULL
			SELECT 
				@OrganizationPositionID = OrganizationPositionID
			FROM
				pcINTEGRATOR_Data..Assignment A
			WHERE
				A.InstanceID = @InstanceID AND
				A.VersionID = @VersionID AND
				A.AssignmentID = @AssignmentID AND
				A.SelectYN <> 0 AND
				A.DeletedID IS NULL

	SET @Step = 'Create temp table #Dimension'
		CREATE TABLE #Dimension (DimensionID int)

		INSERT INTO #Dimension (DimensionID) SELECT [DimensionID] = [Value] FROM STRING_SPLIT (@DimensionList, '|') 

		IF (SELECT COUNT(1) FROM #Dimension) = 0
			INSERT INTO #Dimension (DimensionID) SELECT [DimensionID] = 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension', * FROM #Dimension ORDER BY DimensionID

	SET @Step = 'Create temp table #DimensionExcluded'
		CREATE TABLE #DimensionExcluded (DimensionID int)

		INSERT INTO #DimensionExcluded (DimensionID) SELECT [DimensionID] = [Value] FROM STRING_SPLIT (@DimensionListExcluded, '|') 

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionExcluded', * FROM #DimensionExcluded ORDER BY DimensionID

	SET @Step = 'Create temp table #VisibleNo'
		CREATE TABLE #VisibleNo (DimensionID int)

		INSERT INTO #VisibleNo (DimensionID) SELECT [DimensionID] = [Value] FROM STRING_SPLIT (@VisibleNoList, '|') 

--		IF (SELECT COUNT(1) FROM #VisibleNo) = 0
--			INSERT INTO #VisibleNo (DimensionID) SELECT [DimensionID] = 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#VisibleNo', * FROM #VisibleNo ORDER BY DimensionID

	SET @Step = 'Create and fill temp table #DimensionList'
		IF OBJECT_ID(N'TempDB.dbo.#DimensionList', N'U') IS NULL
			BEGIN
				CREATE TABLE #DimensionList
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Property] nvarchar(50) COLLATE DATABASE_DEFAULT, 
					[StorageTypeBM] int,
					[SortOrder] int,
					[SelectYN] bit,
					[GroupByYN] bit,
					[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT, --Filterstring to get data back, used for ResultTypeBM = 4
					[LevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT, --Filterstring to get comments back, used for ResultTypeBM = 32
					[FilterLevel] nvarchar(2) COLLATE DATABASE_DEFAULT, --L will filter on leaf level members, P will filter on existing parent level members (mostly used for SpreadingKey dataclasses)
					[ChangeableYN] INT,
					[ReadSecurityEnabledYN] bit
					)

				IF OBJECT_ID(N'TempDB.dbo.#FilterTable', N'U') IS NULL
					BEGIN
						SET @DimCalledYN = 0

						INSERT INTO #DimensionList
							(
							[DimensionID],
							[DimensionName],
							[Property], 
							[StorageTypeBM],
							[SortOrder],
							[SelectYN],
							[GroupByYN],
							[Filter],
							[LeafLevelFilter],
							[FilterLevel],
							[ChangeableYN],
							[ReadSecurityEnabledYN]
							)
						SELECT DISTINCT
							[DimensionID] = D.DimensionID,
							[DimensionName] = D.DimensionName COLLATE DATABASE_DEFAULT,
							[Property] = CONVERT(nvarchar(50), 'MemberKey') COLLATE DATABASE_DEFAULT, 
							[StorageTypeBM] = DST.StorageTypeBM,
							[SortOrder] = CASE WHEN DCD.DimensionID = -27 THEN -10 ELSE DCD.SortOrder END,
							[SelectYN] = CASE WHEN @MasterDataClassID IS NOT NULL THEN CASE WHEN DCD.[DimensionID] = -61 THEN 1 ELSE 0 END ELSE 1 END,
							[GroupByYN] = CONVERT(bit, 0),
							[Filter] = CONVERT(nvarchar(4000), '') COLLATE DATABASE_DEFAULT,
							[LeafLevelFilter] = CONVERT(nvarchar(4000), '') COLLATE DATABASE_DEFAULT,
							[FilterLevel] = DCD.[FilterLevel],
							[ChangeableYN] = CONVERT(int, 1),
							[ReadSecurityEnabledYN] = ISNULL(DST.[ReadSecurityEnabledYN], 0)
						FROM
							#Dimension D1
							LEFT JOIN DataClass_Dimension DCD ON DCD.InstanceID IN (0, @InstanceID) AND DCD.VersionID IN (0, @VersionID) AND DCD.DataClassID IN (0, @DataClassID) AND DCD.[SelectYN] <> 0 AND (DCD.DimensionID = D1.DimensionID OR D1.DimensionID = 0)
							LEFT JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND (D.DimensionID = D1.DimensionID OR (D1.DimensionID = 0 AND D.DimensionID = DCD.DimensionID)) AND D.DimensionID <> 0
							LEFT JOIN Dimension_StorageType DST ON DST.InstanceID IN (0, DCD.InstanceID) AND DST.VersionID IN (0, DCD.VersionID) AND (DST.DimensionID = D1.DimensionID OR (D1.DimensionID = 0 AND DST.DimensionID = DCD.DimensionID))
						WHERE
							NOT EXISTS (SELECT 1 FROM #DimensionExcluded DE WHERE DE.DimensionID = D.DimensionID)
					END
				ELSE
					BEGIN
						INSERT INTO #DimensionList
							(
							[DimensionID],
							[DimensionName],
							[Property], 
							[StorageTypeBM],
							[SortOrder],
							[SelectYN],
							[GroupByYN],
							[Filter],
							[LeafLevelFilter],
							[FilterLevel],
							[ChangeableYN],
							[ReadSecurityEnabledYN]
							)
						SELECT DISTINCT
							[DimensionID] = FT.DimensionID,
							[DimensionName] = FT.DimensionName,
							[Property] = CONVERT(nvarchar(50), 'MemberKey') COLLATE DATABASE_DEFAULT, 
							[StorageTypeBM] = FT.[StorageTypeBM],
							[SortOrder] = FT.[SortOrder],
							[SelectYN] = 1,
							[GroupByYN] = CONVERT(bit, 0),
							[Filter] = FT.[Filter],
							[LeafLevelFilter] = FT.[LeafLevelFilter],
							[FilterLevel] = '', --DCD.[FilterLevel],
							[ChangeableYN] = CONVERT(int, 1),
							[ReadSecurityEnabledYN] = ISNULL(DST.[ReadSecurityEnabledYN], 0)
						FROM
							#FilterTable FT
							LEFT JOIN Dimension_StorageType DST ON DST.InstanceID IN(0, @InstanceID) AND DST.VersionID IN (0, @VersionID) AND DST.DimensionID = FT.DimensionID
						WHERE
							NOT EXISTS (SELECT 1 FROM #DimensionExcluded DE WHERE DE.DimensionID = FT.DimensionID)
					END
			END
		ELSE
			BEGIN
				UPDATE DL
				SET
					[SortOrder] = DCD.[SortOrder]
				FROM
					#DimensionList DL
					INNER JOIN DataClass_Dimension DCD ON DCD.[InstanceID] = @InstanceID AND DCD.[VersionID] = @VersionID AND DCD.[DataClassID] = @DataClassID AND DCD.[DimensionID] = DL.[DimensionID]
			END

	SET @Step = 'Create temp table #MeasureList'
		IF OBJECT_ID(N'TempDB.dbo.#MeasureList', N'U') IS NULL
			BEGIN
				SET @MeasureCalledYN = 0

				CREATE TABLE [dbo].[#MeasureList]
					(
					[ParameterType] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[ParameterName] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Default_MemberID] [bigint],
					[Default_MemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Default_MemberDescription] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Visible] [bit],
					[Changeable] [bit],
					[Parameter] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[DataType] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FormatString] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Axis] [nvarchar](50),
					[Index] [int] IDENTITY(1,1)
					)
			END

	SET @Step = 'Insert data into #DefaultMember'
		IF OBJECT_ID(N'TempDB.dbo.#DefaultMember', N'U') IS NULL
			BEGIN
				CREATE TABLE #DefaultMember
					(
					[StepID] int,
					[Source] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[OrganizationPositionID] int,
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[StorageTypeBM] int,
					[HierarchyNo] int,
					[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Dimension_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				EXEC [dbo].[spGet_DefaultMember]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@OrganizationPositionID = @OrganizationPositionID,
					@DataClassID = @DataClassID,
					@AuthenticatedUserID = @AuthenticatedUserID,
					@JobID = @JobID,
					@Debug = @DebugSub
			END

	SET @Step = 'Insert data into #DimensionList'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 1,
					ParameterType = 'Dimension',
					DimensionID = DimensionID,
					ParameterName = DimensionName,
					[StorageTypeBM],
					DefaultMemberID = CASE DimensionName WHEN 'TimeDataView' THEN 101 WHEN 'TimeView' THEN 0 ELSE NULL END, --DM.MemberCounter,
					DefaultMemberKey = CONVERT(nvarchar(100), CASE DimensionName WHEN 'TimeDataView' THEN 'RAWDATA' WHEN 'TimeView' THEN 'Periodic' ELSE NULL END), --DM.MemberKey,
					DefaultMemberDescription = CONVERT(nvarchar(255), CASE DimensionName WHEN 'TimeDataView' THEN 'The storage format for all data' WHEN 'TimeView' THEN 'Periodic' ELSE NULL END), --DM.MemberDescription, 
					DefaultHierarchyNo = 0,
					DefaultHierarchyName = CONVERT(nvarchar(50), ''),
					[Source] = CONVERT(nvarchar(100), ''),
					Visible = CASE WHEN DimensionName = 'TimeDataView' THEN 0 ELSE 1 END,
					Changeable = 0,
					Parameter = DimensionName,
					DataType = 'string',
					FormatString = CONVERT(nvarchar(50), NULL),
					Axis = 'Filter',
					[Index] = SortOrder,
					[ReadSecurityEnabledYN] = [ReadSecurityEnabledYN]
				INTO
					#DimList 
				FROM
					#DimensionList 
				WHERE
					DimensionName <> 'WorkflowState'

				IF @DebugBM & 2 > 0 SELECT TempTable = '#DimList', * FROM #DimList ORDER BY DimensionID

				IF (SELECT COUNT(1) FROM #VisibleNo) > 0
					UPDATE DL
					SET
						Visible = 0
					FROM
						#DimList DL
						INNER JOIN #VisibleNo VN ON VN.DimensionID = DL.DimensionID

/*
				IF OBJECT_ID (N'tempdb..#DefaultValue', N'U') IS NOT NULL
					UPDATE DL
					SET
						[DefaultMemberID] = DV.[DefaultMemberID],
						[DefaultMemberKey] = DV.[DefaultMemberKey],
						[DefaultMemberDescription] = DV.[DefaultMemberDescription]
					FROM
						#DimList DL
						INNER JOIN #DefaultValue DV ON DV.[DimensionID] = DL.[DimensionID]
*/
					UPDATE DL
					SET
						[DefaultMemberKey] = ISNULL(DL.[DefaultMemberKey], DM.[Dimension_MemberKey]),
						[DefaultHierarchyNo] = ISNULL(DL.[DefaultHierarchyNo], DM.[HierarchyNo]),
						[DefaultHierarchyName] = ISNULL(DL.[DefaultHierarchyName], DM.[HierarchyName]),
						[Source] = DM.[Source]
					FROM
						#DimList DL
						INNER JOIN #DefaultMember DM ON DM.DimensionID = DL.DimensionID

					IF CURSOR_STATUS('global','DefaultMember_Cursor') >= -1 DEALLOCATE DefaultMember_Cursor
					DECLARE DefaultMember_Cursor CURSOR FOR
			
						SELECT 
							DimensionName = ParameterName,
							StorageTypeBM
						FROM
							#DimList
						WHERE
							ParameterType = 'Dimension' AND
							DefaultMemberKey IS NOT NULL
						ORDER BY
							DimensionID DESC

						OPEN DefaultMember_Cursor
						FETCH NEXT FROM DefaultMember_Cursor INTO @DimensionName, @StorageTypeBM

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName, [@StorageTypeBM] = @StorageTypeBM

								IF @StorageTypeBM & 4 > 0
									BEGIN
										SET @SQLStatement = '
											UPDATE DL
											SET
												[DefaultMemberID] = D.[MemberID],
												[DefaultMemberDescription] = D.[Description]
											FROM
												#DimList DL
												INNER JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' D ON D.[Label] = DL.[DefaultMemberKey]
											WHERE
												DL.ParameterName = ''' + @DimensionName + ''''
									END

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								FETCH NEXT FROM DefaultMember_Cursor INTO @DimensionName, @StorageTypeBM
							END

					CLOSE DefaultMember_Cursor
					DEALLOCATE DefaultMember_Cursor

			END

	SET @Step = 'Insert data into #MeasureList'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				INSERT INTO [#MeasureList]
					(
					[ParameterType],
					[ParameterName],
					[Default_MemberID],
					[Default_MemberKey],
					[Default_MemberDescription],
					[Visible],
					[Changeable],
					[Parameter],
					[DataType],
					[FormatString],
					[Axis]
					)
				SELECT
					ParameterType = 'Measure',
					ParameterName = M.MeasureName,
					Default_MemberID = NULL,
					Default_MemberKey = NULL,
					Default_MemberDescription = M.MeasureDescription,
					Visible = 1,
					Changeable = 1,
					Parameter = M.MeasureName,
					DataType = DT.DataTypePortal,
					FormatString = M.FormatString,
					Axis = 'Column'
				FROM
					Measure M
					INNER JOIN DataType DT ON DT.DataTypeID = M.DataTypeID
				WHERE
					M.DataClassID = @DataClassID AND
					M.SelectYN <> 0 AND
					M.DeletedID IS NULL
				ORDER BY
					M.SortOrder
			END

	SET @Step = 'Return rows'
		SELECT 
			@InitialWorkflowStateID = W.[InitialWorkflowStateID]
		FROM
			[Assignment] A  
			INNER JOIN [Workflow] W ON W.WorkflowID = A.WorkflowID
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.AssignmentID = @AssignmentID AND
			A.SelectYN <> 0 AND
			A.DeletedID IS NULL

		IF @Debug <> 0 SELECT InstanceID = @InstanceID, AssignmentID = @AssignmentID, InitialWorkflowStateID = @InitialWorkflowStateID

		SELECT 
			ResultTypeBM,
			ParameterType,
			DimensionID,
			ParameterName,
			DefaultMemberID,
			DefaultMemberKey,
			DefaultMemberDescription,
			DefaultHierarchyNo,
			DefaultHierarchyName,
			[DefaultSource] = [Source],
			Visible,
			Changeable,
			Parameter,
			DataType,
			FormatString,
			Axis,
			[Index],
			[ReadSecurityEnabledYN]
		FROM
			#DimList 

		UNION
		SELECT 
			ResultTypeBM = 1,
			ParameterType = 'Parameter',
			DimensionID = NULL,
			ParameterName = 'WorkflowState',
			DefaultMemberID = @InitialWorkflowStateID, --DM.MemberCounter,
			DefaultMemberKey = CONVERT(nvarchar(10), @InitialWorkflowStateID), --DM.MemberKey,
			DefaultMemberDescription = [WorkflowStateName], --DM.MemberDescription,
			DefaultHierarchyNo = 0,
			DefaultHierarchyName = 'WorkflowState',
			[DefaultSource] = 'Workflow',
			Visible = 0,
			Changeable = 0,
			Parameter = 'DimensionName',
			DataType = 'string',
			FormatString = NULL,
			Axis = 'Filter',
			[Index] = 0,
			[ReadSecurityEnabledYN] = 0
		FROM
			[WorkflowState]
		WHERE
			WorkflowStateID = @InitialWorkflowStateID 

		UNION 
		SELECT
			ResultTypeBM = 2,
			ParameterType,
			DimensionID = NULL,
			ParameterName,
			Default_MemberID,
			Default_MemberKey,
			Default_MemberDescription,
			DefaultHierarchyNo = NULL,
			DefaultHierarchyName = NULL,
			[DefaultSource] = @DataClassName,
			Visible,
			Changeable,
			Parameter,
			DataType,
			FormatString,
			Axis,
			[Index],
			[ReadSecurityEnabledYN] = 0
		FROM
			[#MeasureList]
		ORDER BY
			[ParameterType],
			[Axis],
			[Index],
			[ParameterName]

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
		IF @DimCalledYN = 0 DROP TABLE #DimensionList
		IF @MeasureCalledYN = 0 DROP TABLE #MeasureList
		DROP TABLE #DimList

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
