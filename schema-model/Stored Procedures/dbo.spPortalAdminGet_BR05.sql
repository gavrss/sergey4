SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_BR05]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@ResultTypeBM int = 15, --1 = BR05_Master, 2 = Dimensionlist, 4 = Propertylist, 8 = DataClass

	@DimensionID int = NULL, --Optional, needed for @ResultTypeBM = 4

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000529,
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
EXEC [spPortalAdminGet_BR05] @UserID=-10, @InstanceID=476, @VersionID=1024, @BusinessRuleID = 3058, @DimensionID = -1

EXEC [spPortalAdminGet_BR05] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ValidYN bit,
	@TextValidation nvarchar(1024),
	@TextExplanation nvarchar(1024),

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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get data for BR05',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2151' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-427: Adding VersionID to tables DimensionHierarchy, DimensionHierarchyLevel & Dimension_Property.'

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

	SET @Step = 'Validate configuration'
		EXEC [spBR_BR05_Validate] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @BusinessRuleID = @BusinessRuleID, @ValidYN = @ValidYN OUT, @TextValidation = @TextValidation OUT, @TextExplanation = @TextExplanation OUT, @Debug=@DebugSub

	SET @Step = 'BR05_Master'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 1,
					BusinessRuleID,
					Comment,
					DataClassID,
					--GroupDimYN,
					--AccountRuleYN,
					--InterCompanySelection_DimensionID,
					--InterCompanySelection_PropertyID,
					InterCompany_BusinessRuleID,
					ValidYN = @ValidYN,
					TextValidation = @TextValidation,
					TextExplanation = @TextExplanation
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR05_Master]
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					BusinessRuleID = @BusinessRuleID AND
					DeletedID IS NULL
				ORDER BY
					BusinessRuleID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'InterCompanySelection_DimensionID'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 2,
					DimensionID,
					DimensionName
				FROM
					[pcINTEGRATOR].[dbo].[Dimension]
				WHERE
					InstanceID IN (0, @InstanceID) AND
					SelectYN <> 0
				ORDER BY
					DimensionName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'InterCompanySelection_PropertyID'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 4,
					P.PropertyID,
					P.PropertyName
				FROM
					[pcINTEGRATOR].[dbo].[Property] P
					INNER JOIN [pcINTEGRATOR].[dbo].[Dimension_Property] DP ON DP.InstanceID IN (0, @InstanceID) AND DP.VersionID IN (0, @VersionID) AND DP.DimensionID = @DimensionID AND DP.PropertyID = P.PropertyID AND DP.SelectYN <> 0
				WHERE
					P.DependentDimensionID = -4 AND
					P.SelectYN <> 0
				ORDER BY
					P.PropertyName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'DataClass'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 8,
					DataClassID,
					DataClassName
				FROM
					DataClass
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					DataClassTypeID IN (-1, -5)
				ORDER BY
					DataClassName

				SET @Selected = @Selected + @@ROWCOUNT
			END

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
