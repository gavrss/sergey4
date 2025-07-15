SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Scenario]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JSON_table nvarchar(MAX) = NULL, --Initially only enabled for @ResultTypeBM = 8
	@ResultTypeBM int = 1, --1=Scenario, 8=Conversion_MemberKey

	@ScenarioID int = NULL OUT, --If NULL, add a new member
	@MemberKey NVARCHAR(100) = NULL,
	@ScenarioDescription NVARCHAR(255) = NULL,
	@ScenarioTypeID int = NULL,
	@ActualOverwriteYN bit = NULL,
	@AutoRefreshYN bit = NULL,
	@InputAllowedYN bit = NULL,
	@AutoSaveOnCloseYN bit = NULL,
	@SimplifiedDimensionalityYN bit = NULL,
	@ClosedMonth int = NULL,
	@DrillTo_MemberKey nvarchar(100) = NULL,
	@LockedDate date = NULL,
	@SelectYN bit = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000121,
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

DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "8", "DataClassID": "1028", "DimensionID": "-34", "Conversion_MemberKey": "NONE"},
	{"ResultTypeBM" : "8", "DataClassID": "1028", "DimensionID": "-55", "Conversion_MemberKey": "NONE"}
	]'

EXEC [spPortalAdminSet_Scenario]
	@UserID = -10,
	@InstanceID = 413,
	@VersionID = 1008,
	@ResultTypeBM = 8,
	@JSON_table = @JSON_table,
	@Debug = 1

NB SortOrder is set by [spPortalAdminSet_SortOrder]

--UPDATE
EXEC [spPortalAdminSet_Scenario]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@ScenarioID = 1015,
	@MemberKey = 'Budget5',
	@ScenarioDescription = 'Budget Alternative 5',
	@ScenarioTypeID = -7,
	@ActualOverwriteYN = 0,
	@AutoRefreshYN = 0,
	@InputAllowedYN = 0,
	@AutoSaveOnCloseYN = 0,
	@ClosedMonth = NULL,
	@SelectYN = 1

--DELETE
EXEC [spPortalAdminSet_Scenario]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@ScenarioID = 1015,
	@DeleteYN = 1

--INSERT
EXEC [spPortalAdminSet_Scenario]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@ScenarioID = NULL,
	@MemberKey = 'Budget6',
	@ScenarioDescription = 'Budget Alternative 6',
	@ScenarioTypeID = -7,
	@ActualOverwriteYN = 0,
	@AutoRefreshYN = 0,
	@InputAllowedYN = 0,
	@AutoSaveOnCloseYN = 0,
	@ClosedMonth = NULL,
	@SelectYN = 1

EXEC [spPortalAdminSet_Scenario] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2197'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set Scenario',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added parameter @ReturnMemberIdYN = 0 to call of sub routine [spPortalSet_DimensionMember]'
		IF @Version = '2.1.1.2171' SET @Description = 'Added parameter @SimplifiedDimensionalityYN'
		IF @Version = '2.1.1.2172' SET @Description = 'ResultTypeBM=8 added'
		IF @Version = '2.1.2.2197' SET @Description = 'Test on not inserting duplicated MemberKey.'

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

	IF @ResultTypeBM & 8 > 0 GOTO BM8

	SET @Step = 'Update existing member'
		IF @ScenarioID IS NOT NULL AND @DeleteYN = 0
			BEGIN
				IF @MemberKey IS NULL OR @ScenarioDescription IS NULL OR @ScenarioTypeID IS NULL OR @ActualOverwriteYN IS NULL OR @AutoRefreshYN IS NULL OR @InputAllowedYN IS NULL OR @AutoSaveOnCloseYN IS NULL OR @SelectYN IS NULL

					BEGIN
						SET @Message = 'To update an existing member parameter @MemberKey, @ScenarioDescription, @ScenarioTypeID, @ActualOverwriteYN, @AutoRefreshYN, @InputAllowedYN, @AutoSaveOnCloseYN AND @SelectYN must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				UPDATE S
				SET
					[ScenarioName] = @MemberKey,
					[ScenarioDescription] = @ScenarioDescription,
					[ScenarioTypeID] = @ScenarioTypeID,
					[ActualOverwriteYN] = @ActualOverwriteYN,
					[AutoRefreshYN] = @AutoRefreshYN,
					[InputAllowedYN] = @InputAllowedYN,
					[AutoSaveOnCloseYN] = @AutoSaveOnCloseYN,
					[SimplifiedDimensionalityYN] = ISNULL(@SimplifiedDimensionalityYN, S.[SimplifiedDimensionalityYN]),
					[ClosedMonth] = @ClosedMonth,
					[DrillTo_MemberKey] = @DrillTo_MemberKey,
					[LockedDate] = @LockedDate,
					[SelectYN] = @SelectYN
				FROM
					[pcINTEGRATOR_Data].[dbo].[Scenario] S
				WHERE
					S.[InstanceID] = @InstanceID AND
					S.[ScenarioID] = @ScenarioID AND
					S.[VersionID] = @VersionID AND
					S.[MemberKey] = @MemberKey

				SET @Updated = @Updated + @@ROWCOUNT

				IF @Updated > 0
					SET @Message = 'The member is updated.' 
				ELSE
					SET @Message = 'No member is updated.' 
				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'Scenario', @DeletedID = @DeletedID OUT

				UPDATE S
				SET
					[DeletedID] = @DeletedID
				FROM
					[pcINTEGRATOR_Data].[dbo].[Scenario] S
				WHERE
					S.[InstanceID] = @InstanceID AND
					S.ScenarioID = @ScenarioID AND
					S.[VersionID] = @VersionID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The member is deleted.' 
				ELSE
					SET @Message = 'No member is deleted.' 
				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @ScenarioID IS NULL
			BEGIN
				IF @MemberKey IS NULL OR @ScenarioDescription IS NULL OR @ScenarioTypeID IS NULL OR @ActualOverwriteYN IS NULL OR @AutoRefreshYN IS NULL OR @InputAllowedYN IS NULL OR @AutoSaveOnCloseYN IS NULL OR @SelectYN IS NULL

					BEGIN
						SET @Message = 'To add a new member parameter @MemberKey, @ScenarioDescription, @ScenarioTypeID, @ActualOverwriteYN, @AutoRefreshYN, @InputAllowedYN, @AutoSaveOnCloseYN AND @SelectYN must be set'
						SET @Severity = 16
						GOTO EXITPOINT
					END

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Scenario]
					(
					[InstanceID],
					[VersionID],
					[MemberKey],
					[ScenarioName],
					[ScenarioDescription],
					[ScenarioTypeID],
					[ActualOverwriteYN],
					[AutoRefreshYN],
					[InputAllowedYN],
					[AutoSaveOnCloseYN],
					[SimplifiedDimensionalityYN],
					[ClosedMonth],
					[DrillTo_MemberKey],
					[LockedDate],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[MemberKey] = @MemberKey,
					[ScenarioName] = @MemberKey,
					[ScenarioDescription] = @ScenarioDescription,
					[ScenarioTypeID] = @ScenarioTypeID,
					[ActualOverwriteYN] = @ActualOverwriteYN,
					[AutoRefreshYN] = @AutoRefreshYN,
					[InputAllowedYN] = @InputAllowedYN,
					[AutoSaveOnCloseYN] = @AutoSaveOnCloseYN,
					[SimplifiedDimensionalityYN] = ISNULL(@SimplifiedDimensionalityYN, 0),
					[ClosedMonth] = @ClosedMonth,
					[DrillTo_MemberKey] = @DrillTo_MemberKey,
					[LockedDate] = @LockedDate,
					[SelectYN] = @SelectYN
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Scenario] S WHERE S.[InstanceID] = @InstanceID AND S.[VersionID] = @VersionID AND S.[MemberKey] = @MemberKey AND S.[DeletedID] IS NULL)

				SELECT
					@ScenarioID = @@IDENTITY,
					@Inserted = @Inserted + @@ROWCOUNT

				IF @Inserted > 0
					SET @Message = 'The new member is added.' 
				ELSE
					SET @Message = 'No member is added.' 
				SET @Severity = 0
			END

		SELECT @ScenarioID = [ScenarioID] FROM [pcINTEGRATOR_Data].[dbo].[Scenario] S WHERE S.[InstanceID] = @InstanceID AND S.[VersionID] = @VersionID AND S.[MemberKey] = @MemberKey AND ((@DeleteYN = 0 AND S.[DeletedID] IS NULL) OR (@DeleteYN <> 0 AND S.[DeletedID] = @DeletedID))

	SET @Step = 'Update Scenario dimension'
		EXEC [spPortalSet_DimensionMember] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = -6, @MemberKey = @MemberKey, @MemberDescription = @ScenarioDescription, @NodeTypeBM = 1, @SBZ = 0, @Source = 'pcPortal', @Synchronized = 1, @HierarchyNo = 0, @HierarchyView = 'Parent', @Parent = 'All_', @ReturnMemberIdYN = 0

	SET @Step = 'Return ScenarioID'
		SELECT [ScenarioID] = @ScenarioID

	SET @Step = 'Create and fill #Conversion_MemberKey'
		BM8:
		CREATE TABLE #Conversion_MemberKey
			(
			[ResultTypeBM] int,
			[DataClassID] int,
			[DimensionID] int,
			[Conversion_MemberKey] nvarchar(100)  COLLATE DATABASE_DEFAULT
			)			

		IF @JSON_table IS NOT NULL	
			INSERT INTO #Conversion_MemberKey
				(
				[ResultTypeBM],
				[DataClassID],
				[DimensionID],
				[Conversion_MemberKey]
				)
			SELECT
				[ResultTypeBM],
				[DataClassID],
				[DimensionID],
				[Conversion_MemberKey]
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				[ResultTypeBM] int,
				[DataClassID] int,
				[DimensionID] int,
				[Conversion_MemberKey] nvarchar(100)  COLLATE DATABASE_DEFAULT
				)

		IF @Debug <> 0 SELECT TempTable = '#Conversion_MemberKey',  * FROM #Conversion_MemberKey

		UPDATE DCD
		SET
			[Conversion_MemberKey] = CMK.[Conversion_MemberKey]
		FROM
			pcINTEGRATOR_Data..DataClass_Dimension DCD
			INNER JOIN #Conversion_MemberKey CMK ON CMK.[DataClassID] = DCD.[DataClassID] AND CMK.[DimensionID] = DCD.[DimensionID]
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID] = @VersionID

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
