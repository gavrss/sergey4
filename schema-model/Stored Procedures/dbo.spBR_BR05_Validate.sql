SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_Validate]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@ValidYN bit = NULL OUT,
	@TextValidation nvarchar(1024) = NULL OUT,
	@TextExplanation nvarchar(1024) = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000530,
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
DECLARE @ValidYN bit, @TextValidation nvarchar(1024), @TextExplanation nvarchar(1024)
EXEC [spBR_BR05_Validate] @UserID=-10, @InstanceID=476, @VersionID=1024, @BusinessRuleID = 3058, @ValidYN = @ValidYN OUT, @TextValidation = @TextValidation OUT, @TextExplanation = @TextExplanation OUT, @DebugBM=2
SELECT [@ValidYN] = @ValidYN, [@TextValidation] = @TextValidation, [@TextExplanation] = @TextExplanation

EXEC [spBR_BR05_Validate] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataClassID int,
	--@GroupDimYN bit,
	--@AccountRuleYN bit,
	--@InterCompanySelection_DimensionID int,
	--@InterCompanySelection_PropertyID int,
	--@InterCompanySelection nvarchar(100),
	@DataClassTypeID int,

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
			@ProcedureDescription = 'Validate settings for selected Businessrule of type BR05',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2151' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Made generic.'
		IF @Version = '2.1.1.2170' SET @Description = 'Remove test of @InterCompanySelection.'

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
			@DataClassID = DataClassID--,
			--@GroupDimYN = GroupDimYN,
			--@AccountRuleYN = AccountRuleYN,
			--@InterCompanySelection_DimensionID = InterCompanySelection_DimensionID,
			--@InterCompanySelection_PropertyID = InterCompanySelection_PropertyID
			--@InterCompanySelection = InterCompanySelection
		FROM
			pcINTEGRATOR_Data..BR05_Master
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			BusinessRuleID = @BusinessRuleID

		SELECT @DataClassTypeID = DataClassTypeID FROM DataClass WHERE DataClassID = @DataClassID

		SELECT
			@ValidYN = 1,
			@TextValidation = '',
			@TextExplanation = ''

		IF @DebugBM & 2 > 0
			SELECT
				[@DataClassID] = @DataClassID,
				[@DataClassTypeID] = @DataClassTypeID--,
				--[@GroupDimYN] = @GroupDimYN,
				--[@AccountRuleYN] = @AccountRuleYN,
				--[@InterCompanySelection_DimensionID] = @InterCompanySelection_DimensionID,
				--[@InterCompanySelection_PropertyID] = @InterCompanySelection_PropertyID
				--[@InterCompanySelection] = @InterCompanySelection

	SET @Step = 'Create temp table #DimensionExist'
		SELECT DimensionID INTO #DimensionExist FROM DataClass_Dimension WHERE DataClassID = @DataClassID

	SET @Step = 'Validate dimension existence'
		IF @DataClassTypeID <> -5
			BEGIN
				IF (SELECT COUNT(1) FROM #DimensionExist WHERE DimensionID = -1) = 0
					SELECT @ValidYN = 0, @TextValidation = @TextValidation + 'Account Dimension must exist in DataClass' + CHAR(13) + CHAR(10)

				IF (SELECT COUNT(1) FROM #DimensionExist WHERE DimensionID = -4) = 0
					SELECT @ValidYN = 0, @TextValidation = @TextValidation + 'Entity Dimension must exist in DataClass' + CHAR(13) + CHAR(10)

				IF (SELECT COUNT(1) FROM #DimensionExist WHERE DimensionID = -6) = 0
					SELECT @ValidYN = 0, @TextValidation = @TextValidation + 'Scenario Dimension must exist in DataClass' + CHAR(13) + CHAR(10)

				IF (SELECT COUNT(1) FROM #DimensionExist WHERE DimensionID = -55) = 0
					SELECT @ValidYN = 0, @TextValidation = @TextValidation + 'BusinessRule Dimension must exist in DataClass' + CHAR(13) + CHAR(10)

				IF (SELECT COUNT(1) FROM #DimensionExist WHERE DimensionID = -2) = 0
					SELECT @ValidYN = 0, @TextValidation = @TextValidation + 'BusinessProcess Dimension must exist in DataClass' + CHAR(13) + CHAR(10)

				IF (SELECT COUNT(1) FROM #DimensionExist WHERE DimensionID = -3) = 0
					SELECT @ValidYN = 0, @TextValidation = @TextValidation + 'Currency Dimension must exist in DataClass' + CHAR(13) + CHAR(10)
			END

	SET @Step = 'Validate property existence'
/*

			@ValidYN=0
			CONCAT(@TextValidation, ‘Currency dimension property must be properly set for each Entity’, CHR(13) & CHR(10))
	WHEN 1 / Validate if BusinessProcess dimension has a NaAutoElim property, If it doesn’t do /
		THEN 
			@ValidYN=0
			CONCAT(@TextValidation, ‘BusinessProcess dimension must have a NoAutoElim property’, CHR(13) & CHR(10))
*/
	
	SET @Step = 'GroupDimYN <> 0 AND AccountRuleYN <> 0'
--		IF @GroupDimYN <> 0 AND @AccountRuleYN <> 0
		IF 1 = 1
			BEGIN
				SET @TextExplanation = @TextExplanation + 'Consolidation calculations will be based on Journal and proceeded by Currency calculations. Consolidation Rules need to be set up on next tab . Output will be stored on Group Dimension members.' + CHAR(13) + CHAR(10)
/*
			CASE
				WHEN 1 / Validate if Group Dimension exists in DC, If it doesn’t do /
					THEN 
						@ValidYN=0
						CONCAT(@TextValidation, ‘Group Dimension must exist in DataClass’, CHR(13) & CHR(10))
				WHEN 1 / Validate if Flow Dimension exists in DC, If it doesn’t do /
					THEN 
						@ValidYN=0
						CONCAT(@TextValidation, ‘Flow Dimension must exist in DataClass’, CHR(13) & CHR(10))
				WHEN 1 / Validate existing valid Group entries in Group Setup, If it doesn’t do /
					THEN 
						@ValidYN=0
						CONCAT(@TextValidation, ‘Groups needs to be set up in Entity setup’, CHR(13) & CHR(10))
				WHEN 1 / Validate that Account property RULE_CONSOLIDATION exists in Account dimension, If it doesn’t do /
					THEN 
						@ValidYN=0
						CONCAT(@TextValidation, ‘Account dimension needs to have a RULE_CONSOLIDATION property’, CHR(13) & CHR(10))
				WHEN 1 / Validate that all RULE_CONSOLIDATION properties are set to valid rules, If it doesn’t do /
					THEN 
						@ValidYN=0
						CONCAT(@TextValidation, ‘Some Accounts have invalid RULE_CONSOLIDATION settings’, CHR(13) & CHR(10))
*/
			END

--	SET @Step = 'GroupDimYN <> 0 AND AccountRuleYN = 0'
--		IF @GroupDimYN <> 0 AND @AccountRuleYN = 0
--			BEGIN
--				SET @TextExplanation = @TextExplanation + 'Elimination calculations will be based on Journal and proceeded by Currency calculations. IC and ICElim Properties need to be set on all Accounts. Output will be stored on Group Dimension members.' + CHAR(13) + CHAR(10)
--/*
--		@ValidYN=0
--		CONCAT(‘Elim and , CHR(13) & CHR(10))
--*/
--			END

--	SET @Step = 'GroupDimYN = 0 AND AccountRuleYN = 0'
--		IF @GroupDimYN = 0 AND @AccountRuleYN = 0
--			BEGIN
--				SET @TextExplanation = @TextExplanation + 'Elimination calculations will be based on Aggregated Fact data. Any currency calculation needs to be applied in advance. IC and ICElim Properties need to be set on all Accounts. Output will be stored on Group Dimension members.' + CHAR(13) + CHAR(10)
--/*
--		@ValidYN=0
--		CONCAT(‘This is not a valid configuration option in your configuration, CHR(13) & CHR(10))
--*/
--			END

--	SET @Step = 'GroupDimYN = 0 AND AccountRuleYN <> 0'
--		IF @GroupDimYN = 0 AND @AccountRuleYN <> 0
--			SELECT @ValidYN = 0, @TextValidation = @TextValidation + 'Rule based consolidation can only be Journal based with Group dimension.' + CHAR(13) + CHAR(10)

	SET @Step = 'Set @Duration'
		DROP TABLE #DimensionExist

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
