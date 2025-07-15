SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Option]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@OptionID int = NULL, --401=Advanced Consolidation

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000836,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spSetup_Option] @UserID=-10, @InstanceID=-1590, @VersionID=-1590, @OptionID = 401, @DebugBM=7

EXEC [spSetup_Option] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@BusinessRuleID_5 int,
	@BusinessRuleID_14 int,

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
	@Version nvarchar(50) = '2.1.2.2181'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Template for creating SPs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2181' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1


	SET @Step = 'Advanced consolidation'	
		IF @OptionID = 401
			BEGIN
				--BusinessRule
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BusinessRule]
					(
					[InstanceID],
					[VersionID],
					[BR_Name],
					[BR_Description],
					[BR_TypeID],
					[InheritedFrom],
					[SortOrder],
					[SelectYN]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[BR_Name],
					[BR_Description],
					[BR_TypeID],
					[InheritedFrom] = BR.[BusinessRuleID],
					[SortOrder],
					[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_BusinessRule] BR
				WHERE
					[InstanceID] = -20 AND
					[VersionID] = -20 AND
					[BusinessRuleID] IN (5, 14) AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BusinessRule] DBR WHERE DBR.[InstanceID] = @InstanceID AND DBR.[VersionID] = @VersionID AND DBR.[InheritedFrom] = BR.[BusinessRuleID] AND DBR.[BR_TypeID] = BR.[BR_TypeID] AND DBR.[DeletedID] IS NULL)
		
				SET @Inserted = @Inserted + @@ROWCOUNT

				SELECT 
					@BusinessRuleID_5 = MAX(CASE WHEN BR.[BR_TypeID] = 5 THEN BusinessRuleID ELSE 0 END),
					@BusinessRuleID_14 = MAX(CASE WHEN BR.[BR_TypeID] = 14 THEN BusinessRuleID ELSE 0 END)
				FROM
					[pcINTEGRATOR_Data].[dbo].[BusinessRule] BR
				WHERE
					BR.[InstanceID] = @InstanceID AND
					BR.[VersionID] = @VersionID AND
					BR.[InheritedFrom] IN (5,14) AND 
					BR.[BR_TypeID] IN (5,14) AND
					BR.[DeletedID] IS NULL

				IF @DebugBM & 2 > 0 SELECT [@BusinessRuleID_5] = @BusinessRuleID_5, [@BusinessRuleID_14] = @BusinessRuleID_14

				--BR05_Master
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR05_Master]
					(
					[InstanceID],
					[VersionID],
					[BusinessRuleID],
					[Comment],
					[DataClassID],
					[InterCompany_BusinessRuleID],
					[InheritedFrom]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[BusinessRuleID] = @BusinessRuleID_5,
					[Comment] = BR.[Comment],
					[DataClassID] = DC.[DataClassID],
					[InterCompany_BusinessRuleID] = @BusinessRuleID_14,
					[InheritedFrom] = BR.[BusinessRuleID]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_BR05_Master] BR
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = @InstanceID AND DC.[VersionID] = @VersionID AND [DataClassTypeID] = -5
				WHERE
					BR.[InstanceID] = -20 AND
					BR.[VersionID] = -20 AND
					BR.[BusinessRuleID] = 5 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR05_Master] DM WHERE DM.[InstanceID] = @InstanceID AND DM.[VersionID] = @VersionID AND DM.[InheritedFrom] = BR.[BusinessRuleID] AND DM.[DeletedID] IS NULL)
		
				SET @Inserted = @Inserted + @@ROWCOUNT

				--BR05_Rule_Consolidation					
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation]
					(
					[Comment],
					[InstanceID],
					[VersionID],
					[BusinessRuleID],
					[Rule_ConsolidationName],
					[JournalSequence],
					[DimensionFilter],
					[ConsolidationMethodBM],
					[ModifierID],
					[OnlyInterCompanyInGroupYN],
					[FunctionalCurrencyYN],
					[UsePreviousStepYN],
					[SortOrder],
					[InheritedFrom],
					[SelectYN],
					[MovementYN]
					)
				SELECT 
					[Comment],
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[BusinessRuleID] = @BusinessRuleID_5,
					[Rule_ConsolidationName],
					[JournalSequence],
					[DimensionFilter],
					[ConsolidationMethodBM],
					[ModifierID],
					[OnlyInterCompanyInGroupYN],
					[FunctionalCurrencyYN],
					[UsePreviousStepYN],
					[SortOrder],
					[InheritedFrom] = C.[Rule_ConsolidationID],
					[SelectYN],
					[MovementYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_BR05_Rule_Consolidation] C
				WHERE
					C.[InstanceID] = -20 AND
					C.[VersionID] = -20 AND
					C.[BusinessRuleID] = 5 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation] DC WHERE DC.[InstanceID] = @InstanceID AND DC.[VersionID] = @VersionID AND DC.[BusinessRuleID] = @BusinessRuleID_5 AND DC.[InheritedFrom] = C.[Rule_ConsolidationID])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--BR05_Rule_Consolidation_Row
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation_Row]
					(
					[Comment],
					[InstanceID],
					[VersionID],
					[BusinessRuleID],
					[Rule_ConsolidationID],
					[Rule_Consolidation_RowID],
					[DestinationEntity],
					[Account],
					[Flow],
					[Sign],
					[FormulaAmountID],
					[InheritedFrom],
					[SelectYN],
					[NaturalAccountOnlyYN],
					[SortOrder]
					)
				SELECT 
					[Comment] = CR.[Comment],
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[BusinessRuleID] = @BusinessRuleID_5,
					[Rule_ConsolidationID] = C.[Rule_ConsolidationID],
					[Rule_Consolidation_RowID] = CR.[Rule_Consolidation_RowID],
					[DestinationEntity] = CR.[DestinationEntity],
					[Account] = CR.[Account],
					[Flow] = CR.[Flow],
					[Sign] = CR.[Sign],
					[FormulaAmountID] = CR.[FormulaAmountID],
					[InheritedFrom] = CR.[Rule_ConsolidationID],
					[SelectYN] = CR.[SelectYN],
					[NaturalAccountOnlyYN],
					[SortOrder] = CR.[SortOrder]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_BR05_Rule_Consolidation_Row] CR
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation] C ON C.[InstanceID] = @InstanceID AND C.[VersionID] = @VersionID AND C.[BusinessRuleID] = @BusinessRuleID_5 AND C.[InheritedFrom] = CR.[Rule_ConsolidationID]
				WHERE
					CR.[InstanceID] = -20 AND
					CR.[VersionID] = -20 AND
					CR.[BusinessRuleID] = 5 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation_Row] DCR WHERE DCR.[InstanceID] = @InstanceID AND DCR.[VersionID] = @VersionID AND DCR.[BusinessRuleID] = @BusinessRuleID_5 AND DCR.[Rule_ConsolidationID] = C.[Rule_ConsolidationID] AND DCR.[Rule_Consolidation_RowID] = CR.[Rule_Consolidation_RowID] AND DCR.[InheritedFrom] = CR.[Rule_ConsolidationID])

				SET @Inserted = @Inserted + @@ROWCOUNT

				 --BR05_Rule_FX
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX]
					(
					[Comment],
					[InstanceID],
					[VersionID],
					[BusinessRuleID],
					[Rule_FXName],
					[JournalSequence],
					[DimensionFilter],
					[SortOrder],
					[InheritedFrom],
					[SelectYN]
					)
				SELECT 
					[Comment],
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[BusinessRuleID] = @BusinessRuleID_5,
					[Rule_FXName],
					[JournalSequence],
					[DimensionFilter],
					[SortOrder],
					[InheritedFrom] = FX.[Rule_FXID],
					[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_BR05_Rule_FX] FX
				WHERE
					FX.[InstanceID] = -20 AND
					FX.[VersionID] = -20 AND
					FX.[BusinessRuleID] = 5 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX] DFX WHERE DFX.[InstanceID] = @InstanceID AND DFX.[VersionID] = @VersionID AND DFX.[BusinessRuleID] = @BusinessRuleID_5 AND DFX.[InheritedFrom] = FX.[Rule_FXID])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--BR05_Rule_FX_Row
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX_Row]
					(
					[Comment],
					[InstanceID],
					[VersionID],
					[BusinessRuleID],
					[Rule_FXID],
					[Rule_FX_RowID],
					[FlowFilter],
					[Modifier],
					[ResultValueFilter],
					[Sign],
					[FormulaFXID],
					[Account],
					[Flow],
					[InheritedFrom],
					[SelectYN],
					[NaturalAccountOnlyYN],
					[SortOrder]
					)
				SELECT 
					[Comment] = FXR.[Comment],
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[BusinessRuleID] = @BusinessRuleID_5,
					[Rule_FXID] = FX.[Rule_FXID],
					[Rule_FX_RowID] = FXR.[Rule_FX_RowID],
					[FlowFilter] = FXR.[FlowFilter],
					[Modifier] = FXR.[Modifier],
					[ResultValueFilter] = FXR.[ResultValueFilter],
					[Sign] = FXR.[Sign],
					[FormulaFXID] = FXR.[FormulaFXID],
					[Account] = FXR.[Account],
					[Flow] = FXR.[Flow],
					[InheritedFrom] = FXR.[Rule_FXID],
					[SelectYN] = FXR.[SelectYN],
					[NaturalAccountOnlyYN] = FXR.[NaturalAccountOnlyYN],
					[SortOrder] = FXR.[SortOrder]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_BR05_Rule_FX_Row] FXR
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX] FX ON FX.[InstanceID] = @InstanceID AND FX.[VersionID] = @VersionID AND FX.[BusinessRuleID] = @BusinessRuleID_5 AND FX.[InheritedFrom] = FXR.[Rule_FXID]
				WHERE
					FXR.[InstanceID] = -20 AND
					FXR.[VersionID] = -20 AND
					FXR.[BusinessRuleID] = 5 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX_Row] DFXR WHERE DFXR.[InstanceID] = @InstanceID AND DFXR.[VersionID] = @VersionID AND DFXR.[BusinessRuleID] = @BusinessRuleID_5 AND DFXR.[Rule_FXID] = FX.[Rule_FXID] AND DFXR.[Rule_FX_RowID] = FXR.[Rule_FX_RowID] AND DFXR.[InheritedFrom] = FXR.[Rule_FXID])

				SET @Inserted = @Inserted + @@ROWCOUNT


				--BR05_Rule_ICmatch
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR05_Rule_ICmatch]
					(
					[Comment],
					[InstanceID],
					[VersionID],
					[Rule_ICmatchName],
					[DimensionFilter],
					[AccountInterCoDiffManual],
					[AccountInterCoDiffAuto],
					[Source],
					[SortOrder],
					[InheritedFrom],
					[SelectYN]
					)
				SELECT 
					[Comment],
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[Rule_ICmatchName],
					[DimensionFilter],
					[AccountInterCoDiffManual],
					[AccountInterCoDiffAuto],
					[Source],
					[SortOrder],
					[InheritedFrom] = ICM.[Rule_ICmatchID],
					[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_BR05_Rule_ICmatch] ICM
				WHERE
					ICM.[InstanceID] = -20 AND
					ICM.[VersionID] = -20 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BR05_Rule_ICmatch] DICM WHERE DICM.[InstanceID] = @InstanceID AND DICM.[VersionID] = @VersionID AND DICM.[InheritedFrom] = ICM.[Rule_ICmatchID])

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
