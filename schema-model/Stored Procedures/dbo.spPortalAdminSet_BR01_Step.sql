SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_BR01_Step]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@BR01_StepID int = NULL,
	@BR01_StepPartID int = NULL,
	@Comment nvarchar(1024) = NULL,
	@MemberKey nvarchar(100) = NULL,
	@ModifierID int = NULL,
	@Parameter float = NULL,
	@DataClassID int = NULL,
	@Decimal int = NULL,
	@DimensionFilter nvarchar(4000) = NULL,
	@Operator nchar(1) = NULL,
	@MultiplyWith float = 1,
	@DeleteYN bit = 0,

	@JSON_table nvarchar(MAX) = NULL,

	@BR_ID int = NULL, --Should be deleted, replaced by @BusinessRuleID

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000355,
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
	@ProcedureName = 'spPortalAdminSet_BR01_Step',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "0"},
		{"TKey" : "VersionID",  "TValue": "0"},
		{"TKey" : "BusinessRuleID",  "TValue": "1001"},
		{"TKey" : "BR01_StepID",  "TValue": "13"},
		{"TKey" : "Debug",  "TValue": "1"}
		]',
	@JSON_table = '
		[
		{"BR01_StepPartID" : "-1", "Comment": "Test 1", "MemberKey" : "ST_Account", "ModifierID" : "10", "Parameter": "1","DataClassID" : "1001", "Decimal": "0","DimensionFilter" : "Dim1", "Operator": "+","DeleteYN": "0"},
		{"BR01_StepPartID" : "0", "Comment": "Test 1", "MemberKey" : "ST_Account", "ModifierID" : "20", "Parameter": "1","DataClassID" : "1001", "Decimal": "0","DimensionFilter" : "Dim2", "Operator": "-","DeleteYN": "0"},
		{"BR01_StepPartID" : "1", "Comment": "Test 4", "MemberKey" : "ST_Account", "ModifierID" : "", "DataClassID" : "1001", "Decimal": "","DimensionFilter" : "Dim3", "Operator": "*"}
		]'

EXEC [spPortalAdminSet_BR01_Step] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE

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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain table BR01_Step',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Added parameter @MultiplyWith.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'

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

		SET @BusinessRuleID = ISNULL(@BusinessRuleID, @BR_ID)

	SET @Step = 'Create and fill Cursor table'
		CREATE TABLE #BR01_Step_Cursor_Table
			(
			[BR01_StepPartID] int,
			[Comment] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[ModifierID] int,
			[Parameter] float,
			[DataClassID] int,
			[Decimal] int,
			[DimensionFilter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[Operator] nchar(1) COLLATE DATABASE_DEFAULT,
			[MultiplyWith] float,
			[DeleteYN] bit
			)			

		IF @JSON_table IS NOT NULL	
			BEGIN
				INSERT INTO #BR01_Step_Cursor_Table
					(
					[BR01_StepPartID],
					[Comment],
					[MemberKey],
					[ModifierID],
					[Parameter],
					[DataClassID],
					[Decimal],
					[DimensionFilter],
					[Operator],
					[MultiplyWith],
					[DeleteYN]
					)
				SELECT
					[BR01_StepPartID],
					[Comment],
					[MemberKey],
					[ModifierID],
					[Parameter],
					[DataClassID],
					[Decimal],
					[DimensionFilter],
					[Operator],
					[MultiplyWith] = ISNULL([MultiplyWith], 1),
					[DeleteYN] = ISNULL([DeleteYN], 0)
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[BR01_StepPartID] int,
					[Comment] nvarchar(1024) COLLATE database_default,
					[MemberKey] nvarchar(100) COLLATE database_default,
					[ModifierID] int,
					[Parameter] float,
					[DataClassID] int,
					[Decimal] int,
					[DimensionFilter] nvarchar(4000) COLLATE database_default,
					[Operator] nchar(1) COLLATE database_default,
					[MultiplyWith] float,
					[DeleteYN] bit
					)
			END
		ELSE
			BEGIN
				INSERT INTO #BR01_Step_Cursor_Table
					(
					[BR01_StepPartID],
					[Comment],
					[MemberKey],
					[ModifierID],
					[Parameter],
					[DataClassID],
					[Decimal],
					[DimensionFilter],
					[Operator],
					[MultiplyWith],
					[DeleteYN]
					)
				SELECT
					[BR01_StepPartID] = @BR01_StepPartID,
					[Comment] = @Comment,
					[MemberKey] = @MemberKey,
					[ModifierID] = @ModifierID,
					[Parameter] = @Parameter,
					[DataClassID] = @DataClassID,
					[Decimal] = @Decimal,
					[DimensionFilter] = @DimensionFilter,
					[Operator] = @Operator,
					[MultiplyWith] = @MultiplyWith,
					[DeleteYN] = @DeleteYN
			END

	SET @Step = 'BR01 Step_Cursor'
		DECLARE BR01_Step_Cursor CURSOR FOR
			
			SELECT
				[BR01_StepPartID],
				[Comment],
				[MemberKey],
				[ModifierID],
				[Parameter],
				[DataClassID],
				[Decimal],
				[DimensionFilter],
				[Operator],
				[MultiplyWith],
				[DeleteYN]
			FROM
				#BR01_Step_Cursor_Table
			ORDER BY
				[BR01_StepPartID]

			OPEN BR01_Step_Cursor
			FETCH NEXT FROM BR01_Step_Cursor INTO @BR01_StepPartID, @Comment, @MemberKey, @ModifierID, @Parameter, @DataClassID, @Decimal, @DimensionFilter, @Operator, @MultiplyWith, @DeleteYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@BR01_StepPartID] = @BR01_StepPartID, [@Comment] = @Comment, [@MemberKey] = @MemberKey, [@ModifierID] = @ModifierID, [@Parameter] = @Parameter, [@DataClassID] = @DataClassID, [@Decimal] = @Decimal, [@DimensionFilter] = @DimensionFilter, [@Operator] = @Operator, [@MultiplyWith] = @MultiplyWith, [@DeleteYN] = @DeleteYN

				SET @Step = 'Update existing member'
					IF @DeleteYN = 0
						BEGIN
							IF @Comment IS NULL OR @MemberKey IS NULL
								BEGIN
									SET @Message = 'To update an existing member parameter @Comment AND @MemberKey must be set'
									SET @Severity = 16
									GOTO EXITPOINT
								END

							UPDATE BRS
							SET
								[Comment] = @Comment,
								[MemberKey] = @MemberKey,
								[ModifierID] = @ModifierID,
								[Parameter] = @Parameter,
								[DataClassID] = @DataClassID,
								[Decimal] = @Decimal,
								[DimensionFilter] = @DimensionFilter,
								[Operator] = @Operator,
								[MultiplyWith] = @MultiplyWith
							FROM
								[pcINTEGRATOR_Data].[dbo].[BR01_Step] BRS
							WHERE
								BRS.[InstanceID] = @InstanceID AND
								BRS.[VersionID] = @VersionID AND
								BRS.[BusinessRuleID] = @BusinessRuleID AND
								BRS.[BR01_StepID] = @BR01_StepID AND
								BRS.[BR01_StepPartID] = @BR01_StepPartID

							SET @Updated = @Updated + @@ROWCOUNT
/*
							IF @Updated > 0
								SET @Message = 'The member is updated.' 
							ELSE
								SET @Message = 'No member is updated.' 
*/
							SET @Severity = 0
						END

				SET @Step = 'Delete existing member'
					IF @DeleteYN <> 0
						BEGIN
			--				EXEC [dbo].[spGet_DeletedItem] @UserID = -10, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'BR01_Master', @DeletedID = @DeletedID OUT

							DELETE BRS
							FROM
								[pcINTEGRATOR_Data].[dbo].[BR01_Step] BRS
							WHERE
								BRS.[InstanceID] = @InstanceID AND
								BRS.[VersionID] = @VersionID AND
								BRS.[BusinessRuleID] = @BusinessRuleID AND
								BRS.[BR01_StepID] = @BR01_StepID AND
								BRS.[BR01_StepPartID] = @BR01_StepPartID

							SET @Deleted = @Deleted + @@ROWCOUNT
/*
							IF @Deleted > 0
								SET @Message = 'The member is deleted.' 
							ELSE
								SET @Message = 'No member is deleted.' 
*/
							SET @Severity = 0
						END

				SET @Step = 'Insert new member'
					IF @DeleteYN = 0
						BEGIN
							IF @Comment IS NULL OR @MemberKey IS NULL
								BEGIN
									SET @Message = 'To add a new member parameter @Comment AND @MemberKey must be set'
									SET @Severity = 16
									GOTO EXITPOINT
								END

							INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR01_Step]
								(
								[InstanceID],
								[VersionID],
								[BusinessRuleID],
								[BR01_StepID],
								[BR01_StepPartID],
								[Comment],
								[MemberKey],
								[ModifierID],
								[Parameter],
								[DataClassID],
								[Decimal],
								[DimensionFilter],
								[Operator],
								[MultiplyWith]
								)
							SELECT
								[InstanceID] = @InstanceID,
								[VersionID] = @VersionID,
								[BusinessRuleID] = @BusinessRuleID,
								[BR01_StepID] = @BR01_StepID,
								[BR01_StepPartID] = @BR01_StepPartID,
								[Comment] = @Comment,
								[MemberKey] = @MemberKey,
								[ModifierID] = @ModifierID,
								[Parameter] = @Parameter,
								[DataClassID] = @DataClassID,
								[Decimal] = @Decimal,
								[DimensionFilter] = @DimensionFilter,
								[Operator] = @Operator,
								[MultiplyWith] = @MultiplyWith
							WHERE
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR01_Step] D WHERE D.[InstanceID] = @InstanceID AND D.[VersionID] = @VersionID AND D.[BusinessRuleID] = @BusinessRuleID AND D.[BR01_StepID] = @BR01_StepID AND D.[BR01_StepPartID] = @BR01_StepPartID)

							SELECT
								@Inserted = @Inserted + @@ROWCOUNT
/*
							IF @Inserted > 0
								SET @Message = 'The new member is added.' 
							ELSE
								SET @Message = 'No member is added.' 
*/
							SET @Severity = 0
						END

					FETCH NEXT FROM BR01_Step_Cursor INTO @BR01_StepPartID, @Comment, @MemberKey, @ModifierID, @Parameter, @DataClassID, @Decimal, @DimensionFilter, @Operator, @MultiplyWith, @DeleteYN
				END

		CLOSE BR01_Step_Cursor
		DEALLOCATE BR01_Step_Cursor

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
