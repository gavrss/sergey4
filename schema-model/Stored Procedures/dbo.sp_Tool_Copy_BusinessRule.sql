SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Copy_BusinessRule]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@InstanceID_From int = NULL,
	@InstanceID_To int = NULL,
	@VersionID_From int = NULL,
	@VersionID_To int = NULL,
	@BusinessRuleID_From int = NULL,
	@BusinessRuleID_To int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000623,
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
EXEC [sp_Tool_Copy_BusinessRule]
	@InstanceID_From = -1405,
	@InstanceID_To = -1406,
	@VersionID_From = -1405,
	@VersionID_To = -1406,
	@BusinessRuleID_From = 5588,
	@Debug=1

EXEC [sp_Tool_Copy_BusinessRule] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@BR_Name nvarchar(50),
	@BR_TypeID int,

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
	@Version nvarchar(50) = '2.1.0.2158'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Copy BusinessRule',
			@MandatoryParameter = 'InstanceID_From|InstanceID_To|VersionID_From|VersionID_To|BusinessRuleID_From' --Without @, separated by |

		IF @Version = '2.1.0.2158' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT 
			@BR_Name = BR_Name,
			@BR_TypeID = BR_TypeID
		FROM
			[pcINTEGRATOR_Data].[dbo].[BusinessRule]
		WHERE
			InstanceID = @InstanceID_From AND
			VersionID = @VersionID_From AND
			BusinessRuleID = @BusinessRuleID_From

	SET @Step = 'Create and fill temp table #BusinessRule'
		CREATE TABLE #BusinessRule
			(
			BusinessRuleID int
			)

		INSERT INTO #BusinessRule
			(
			BusinessRuleID
			)
		SELECT 
			BusinessRuleID
		FROM
			[pcINTEGRATOR_Data].[dbo].[BusinessRule]
		WHERE
			InstanceID = @InstanceID_To AND
			VersionID = @VersionID_To AND
			BR_Name = @BR_Name AND
			BR_TypeID = @BR_TypeID

	SET @Step = 'BR01'
		IF @BR_TypeID = 1
			BEGIN
				--Delete existing BusinessRules with same name and type

				DELETE BRSSO
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Step_SortOrder] BRSSO
					INNER JOIN #BusinessRule BR ON BR.BusinessRuleID = BRSSO.BusinessRuleID
				WHERE
					BRSSO.InstanceID = @InstanceID_To AND
					BRSSO.VersionID = @VersionID_To

				SET @Deleted = @Deleted + @@ROWCOUNT

				DELETE BRS
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Step] BRS
					INNER JOIN #BusinessRule BR ON BR.BusinessRuleID = BRS.BusinessRuleID
				WHERE
					BRS.InstanceID = @InstanceID_To AND
					BRS.VersionID = @VersionID_To

				SET @Deleted = @Deleted + @@ROWCOUNT

				DELETE BRM
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Master] BRM
					INNER JOIN #BusinessRule BR ON BR.BusinessRuleID = BRM.BusinessRuleID
				WHERE
					BRM.InstanceID = @InstanceID_To AND
					BRM.VersionID = @VersionID_To

				SET @Deleted = @Deleted + @@ROWCOUNT

				DELETE B
				FROM
					[pcINTEGRATOR_Data].[dbo].[BusinessRule] B
					INNER JOIN #BusinessRule BR ON BR.BusinessRuleID = B.BusinessRuleID
				WHERE
					B.InstanceID = @InstanceID_To AND
					B.VersionID = @VersionID_To

				SET @Deleted = @Deleted + @@ROWCOUNT

				--[BusinessRule]
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BusinessRule]
					(
					[InstanceID],
					[VersionID],
					[BR_Name],
					[BR_Description],
					[BR_TypeID],
					[InheritedFrom],
					[SelectYN],
					[DeletedID],
					[SortOrder]
					)
				SELECT
					[InstanceID] = @InstanceID_To,
					[VersionID]= @VersionID_To,
					[BR_Name],
					[BR_Description],
					[BR_TypeID],
					[InheritedFrom] = @BusinessRuleID_From,
					[SelectYN],
					[DeletedID],
					[SortOrder]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BusinessRule]
				WHERE
					InstanceID = @InstanceID_From AND
					VersionID = @VersionID_From AND
					BusinessRuleID = @BusinessRuleID_From

				SET @Inserted = @Inserted + @@ROWCOUNT

				SELECT
					@BusinessRuleID_To = MAX(BusinessRuleID)
				FROM 
					[pcINTEGRATOR_Data].[dbo].[BusinessRule]
				WHERE
					InstanceID = @InstanceID_To AND
					VersionID = @VersionID_To

				IF @DebugBM & 2 > 0 SELECT [@BusinessRuleID_To] = @BusinessRuleID_To

				--[BR01_Master]
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR01_Master]
					(
					[InstanceID],
					[VersionID],
					[BusinessRuleID],
					[Comment],
					[DataClassID],
					[BaseObject],
					[BeforeFxYN],
					[DimensionSetting],
					[DimensionFilter],
					[PreExec],
					[PostExec],
					[InheritedFrom],
					[DeletedID]
					)
				SELECT
					[InstanceID] = @InstanceID_To,
					[VersionID]= @VersionID_To,
					[BusinessRuleID] = @BusinessRuleID_To,
					[Comment],
					[DataClassID] = [dbo].[f_GetDataClassID] (@InstanceID_To, @VersionID_To, BRM.[DataClassID]),
					[BaseObject],
					[BeforeFxYN],
					[DimensionSetting],
					[DimensionFilter],
					[PreExec],
					[PostExec],
					[InheritedFrom] = @BusinessRuleID_From,
					[DeletedID]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Master] BRM
				WHERE
					InstanceID = @InstanceID_From AND
					VersionID = @VersionID_From AND
					BusinessRuleID = @BusinessRuleID_From

				SET @Inserted = @Inserted + @@ROWCOUNT

				--[BR01_Step]
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
					[ValueFilter],
					[Operator],
					[MultiplyWith]
					)
				SELECT
					[InstanceID] = @InstanceID_To,
					[VersionID]= @VersionID_To,
					[BusinessRuleID] = @BusinessRuleID_To,
					[BR01_StepID],
					[BR01_StepPartID],
					[Comment],
					[MemberKey],
					[ModifierID],
					[Parameter],
					[DataClassID] = [dbo].[f_GetDataClassID] (@InstanceID_To, @VersionID_To, BRS.[DataClassID]),
					[Decimal],
					[DimensionFilter],
					[ValueFilter],
					[Operator],
					[MultiplyWith]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Step] BRS
				WHERE
					InstanceID = @InstanceID_From AND
					VersionID = @VersionID_From AND
					BusinessRuleID = @BusinessRuleID_From

				SET @Inserted = @Inserted + @@ROWCOUNT

				--[BR01_Step_SortOrder]
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR01_Step_SortOrder]
					(
					[InstanceID],
					[VersionID],
					[BusinessRuleID],
					[BR01_StepID],
					[SortOrder]
					)
				SELECT
					[InstanceID] = @InstanceID_To,
					[VersionID]= @VersionID_To,
					[BusinessRuleID] = @BusinessRuleID_To,
					[BR01_StepID],
					[SortOrder]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Step_SortOrder]
				WHERE
					InstanceID = @InstanceID_From AND
					VersionID = @VersionID_From AND
					BusinessRuleID = @BusinessRuleID_From

				SET @Inserted = @Inserted + @@ROWCOUNT

			END
		ELSE
			BEGIN
				SET @Message = 'BR_TypeID ' + CONVERT(nvarchar(15), @BR_TypeID) + ' is not handled.'
				SET @Severity = 16
				GOTO EXITPOINT
			END
	
	SET @Step = 'Drop temp tables'
		DROP TABLE #BusinessRule

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
