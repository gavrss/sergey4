SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_BR11]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@DataClassID int = NULL,
	@ResultTypeBM int = 31, --1 = Dimension List, 2 = Dimension members, 4 = Selected Values, 8 = DataClasses, 16=InterCompanySelection

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000756,
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
EXEC [spPortalAdminGet_BR11] @UserID=-10, @InstanceID=454, @VersionID=1021, @BusinessRuleID = 12183

EXEC [spPortalAdminGet_BR11] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ValidYN bit,
	@TextValidation nvarchar(1024),
	@TextExplanation nvarchar(1024),
	@DimensionList nvarchar(100) = '-2|-3|-6',

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2170'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get data for BR11',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2168' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2170' SET @Description = 'Added sortorder on ResultTypeBM = 16.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT 
			@DataClassID = ISNULL(@DataClassID, DataClassID)
		FROM
			pcINTEGRATOR_Data..BR11_Master BR11
			INNER JOIN pcINTEGRATOR_Data..BusinessRule BR ON BR.InstanceID = BR11.InstanceID AND BR.VersionID = BR11.VersionID AND BR.BusinessRuleID = BR11.BusinessRuleID AND BR.SelectYN <> 0 AND BR.DeletedID IS NULL
		WHERE
			BR11.InstanceID = @InstanceID AND
			BR11.VersionID = @VersionID AND
			BR11.BusinessRuleID = @BusinessRuleID AND
			BR11.DeletedID IS NULL

	SET @Step = 'Validate configuration'
--		EXEC [spBR_BR11_Validate] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @BusinessRuleID = @BusinessRuleID, @ValidYN = @ValidYN OUT, @TextValidation = @TextValidation OUT, @TextExplanation = @TextExplanation OUT, @Debug=@DebugSub

	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				EXEC [dbo].[spGet_DataClass_DimensionList] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @DimensionList=@DimensionList, @ResultTypeBM=1, @JobID=@JobID, @Debug=@DebugSub
			END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@UserID]=@UserID, [@InstanceID]=@InstanceID, [@VersionID]=@VersionID, [@DataClassID]=@DataClassID, [@PropertyList]=NULL, [@DimensionList]=@DimensionList, [@ShowAllMembersYN]=1, [@OnlyDataClassDimMembersYN]=0, [@Selected]=@Selected, [@JobID]=@JobID, [@Debug]=@DebugSub
				EXEC [spGet_DataClass_DimensionMember] @UserID=@UserID,  @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @PropertyList=NULL, @DimensionList=@DimensionList, @ShowAllMembersYN=1, @OnlyDataClassDimMembersYN=0, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub
			END

	SET @Step = 'BR11_Master'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 4,
					BusinessRuleID,
					Comment,
					DataClassID,
					InterCompanySelection,
					DimensionFilter,
					ValidYN = @ValidYN,
					TextValidation = @TextValidation,
					TextExplanation = @TextExplanation
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR11_Master]
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					BusinessRuleID = @BusinessRuleID AND
					DeletedID IS NULL
				ORDER BY
					BusinessRuleID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of Data classes'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 8,
					DC.DataClassID,
					DC.DataClassName
				FROM
					[pcINTEGRATOR_Data].[dbo].[DataClass] DC
				WHERE
					DC.InstanceID = @InstanceID AND
					DC.VersionID = @VersionID AND
					DC.ModelBM & 64 > 0
				ORDER BY
					DC.DataClassID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of valid InterCompanySelections'
		IF @ResultTypeBM & 16 > 0
			SELECT DISTINCT
				[ResultTypeBM] = 16,
				[InterCompanySelection] = '[' + D.[DimensionName] + '].[' + P.[PropertyName] + ']',
				[Dimension] = D.[DimensionName],
				[Property] = P.[PropertyName]
			FROM
				Property P
				INNER JOIN Dimension_Property DP ON DP.InstanceID IN (0, @InstanceID) AND DP.VersionID IN (0, @VersionID) AND DP.PropertyID = P.PropertyID
				INNER JOIN pcINTEGRATOR_Data..DataClass_Dimension DCD ON DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DataClassID = @DataClassID AND DCD.DimensionID = DP.DimensionID
				INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = DP.DimensionID
			WHERE
				P.InstanceID IN (0, @InstanceID) AND
				P.DataTypeID = 3 AND
				P.DependentDimensionID = -4
			ORDER BY
				D.[DimensionName],
				P.[PropertyName]

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
