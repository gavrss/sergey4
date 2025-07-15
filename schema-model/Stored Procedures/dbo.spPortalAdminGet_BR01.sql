SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_BR01]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@ResultTypeBM int = 127, --1 = BR01_Master, 2 = BR01_Step, 4 = BR01_StepPart, 8 = BR_Modifier, 16 = DataClass, 32 = MissingDimension, 64 = Parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000359,
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
	@ProcedureName = 'spPortalAdminGet_BR01',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spRun_Procedure_KeyValuePair] @JSON='[
{"TKey":"InstanceID","TValue":"470"},{"TKey":"UserID","TValue":"7830"},
{"TKey":"BusinessRuleID","TValue":"1038"},{"TKey":"VersionID","TValue":"1025"},
{"TKey":"ResultTypeBM","TValue":"15"},{"TKey":"Debug","TValue":"1"}
]', @ProcedureName='spPortalAdminGet_BR01'

EXEC [spRun_Procedure_KeyValuePair] @JSON='[
{"TKey":"InstanceID","TValue":"-1318"},{"TKey":"UserID","TValue":"-10"},
{"TKey":"BusinessRuleID","TValue":"3015"},{"TKey":"VersionID","TValue":"-1256"},
{"TKey":"ResultTypeBM","TValue":"31"}]', @ProcedureName='spPortalAdminGet_BR01'

EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"-1078"},
{"TKey":"UserID","TValue":"-1243"},{"TKey":"BusinessRuleID","TValue":"2106"},
{"TKey":"VersionID","TValue":"-1075"},{"TKey":"ResultTypeBM","TValue":"15"}, {"TKey":"Debug","TValue":"1"}]', 
@ProcedureName='spPortalAdminGet_BR01'

EXEC [spPortalAdminGet_BR01] @UserID=-10, @InstanceID=454, @VersionID=1021, @BusinessRuleID = 1012, @Debug=1
EXEC [spPortalAdminGet_BR01] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID = 1002, @Debug=1
EXEC [spPortalAdminGet_BR01] @UserID=-10, @InstanceID=413, @VersionID=1008, @BusinessRuleID = 1031, @Debug=1

EXEC [spPortalAdminGet_BR01] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DimensionID int,
	@DimensionName nvarchar(50),
	@DimensionTable nvarchar(100),
	@StorageTypeBM int,
	@SQLStatement nvarchar(MAX),
	@DimensionSetting nvarchar(4000),

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
	@Version nvarchar(50) = '2.1.1.2170'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get data for BR01',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Added some more columns. (@ResultTypeBM 1 and 2)'
		IF @Version = '2.0.2.2146' SET @Description = 'Filter on valid modifiers. (@ResultTypeBM 8)'
		IF @Version = '2.0.3.2151' SET @Description = 'DB-265: Added MemberDescription column for ResultTypeBM = 2. Added ValidYN.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-342: Insert into #DimensionSetting if @DimensionSetting has value. DB-343: ValidYN only checks on BR01_StepPartID = 0.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-460: Checking for string <> in @DimensionSetting.'
		IF @Version = '2.1.0.2156' SET @Description = 'DB-496: Added @ResultTypeBM 64 (Parameters).'
		IF @Version = '2.1.1.2170' SET @Description = 'Added table reference to DimensionFilter column.'

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

		SELECT 
			@DimensionSetting = DimensionSetting
		FROM
			BR01_Master BRM
		WHERE
			BRM.InstanceID = @InstanceID AND 
			BRM.VersionID = @VersionID AND
			BRM.BusinessRuleID = @BusinessRuleID 

		IF @Debug <> 0 SELECT [@DimensionSetting] = @DimensionSetting

	SET @Step = 'Create temp tables #MissingDimension'
		CREATE TABLE #MissingDimension
			(
			BR01_StepID int,
			BR01_StepPartID int,
			DimensionID int
			)

		CREATE TABLE #DimensionSetting
			(
			DimensionID int,
			DimensionName nvarchar(100)
			)

	SET @Step = 'Fill temp table #DimensionSetting'
		IF @ResultTypeBM & 35 > 0
			BEGIN
				IF LEN(@DimensionSetting) > 0
				BEGIN
					INSERT INTO #DimensionSetting
						(
						DimensionID,
						DimensionName
						)		
					SELECT
						D.DimensionID,
						D.DimensionName
					FROM
						Dimension D
						INNER JOIN (SELECT DimensionName = LTRIM(RTRIM(LEFT([Value], CASE WHEN CHARINDEX('=', [Value]) = 0 THEN CHARINDEX('<>', [Value]) ELSE CHARINDEX('=', [Value]) END - 1))) FROM STRING_SPLIT(@DimensionSetting, '|')) DN ON DN.DimensionName = D.DimensionName
					WHERE
						D.InstanceID IN (0, @InstanceID)
				END

				IF @Debug <> 0 SELECT TempTable = '#DimensionSetting', * FROM #DimensionSetting ORDER BY DimensionID
			END

	SET @Step = 'Fill temp table #MissingDimension'
		IF @ResultTypeBM & 35 > 0
			BEGIN
				INSERT INTO #MissingDimension (BR01_StepID, BR01_StepPartID, DimensionID)
				SELECT DISTINCT
					BRS.BR01_StepID,
					BRS.BR01_StepPartID,
					DCD.DimensionID
				FROM
					BR01_Master BRM 
					INNER JOIN BR01_Step BRS ON BRS.InstanceID = BRM.InstanceID AND BRS.VersionID = BRM.VersionID AND BRS.BusinessRuleID = BRM.BusinessRuleID AND BRS.DataClassID <> BRM.DataClassID AND BRS.BR01_StepPartID = 0
					INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = BRM.InstanceID AND DCD.VersionID = BRM.VersionID AND DCD.DataClassID = BRM.DataClassID
					INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.ReportOnlyYN = 0
				WHERE
					BRM.InstanceID = @InstanceID AND 
					BRM.VersionID = @VersionID AND
					BRM.BusinessRuleID = @BusinessRuleID AND
					NOT EXISTS (
						SELECT 1 FROM
							(
							SELECT DISTINCT
								BRS.BR01_StepID,
								BRS.BR01_StepPartID,
								DCD.DimensionID
							FROM
								BR01_Master BRM 
								INNER JOIN BR01_Step BRS ON BRS.InstanceID = BRM.InstanceID AND BRS.VersionID = BRM.VersionID AND BRS.BusinessRuleID = BRM.BusinessRuleID AND BRS.DataClassID <> BRM.DataClassID
								INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = BRM.InstanceID AND DCD.VersionID = BRM.VersionID AND DCD.DataClassID = BRS.DataClassID
							WHERE
								BRM.InstanceID = @InstanceID AND 
								BRM.VersionID = @VersionID AND
								BRM.BusinessRuleID = @BusinessRuleID
							UNION SELECT DISTINCT
								BRS.BR01_StepID,
								BRS.BR01_StepPartID,
								DS.DimensionID
							FROM
								BR01_Master BRM 
								INNER JOIN BR01_Step BRS ON BRS.InstanceID = BRM.InstanceID AND BRS.VersionID = BRM.VersionID AND BRS.BusinessRuleID = BRM.BusinessRuleID AND BRS.DataClassID <> BRM.DataClassID
								INNER JOIN #DimensionSetting DS ON 1 = 1
							WHERE
								BRM.InstanceID = @InstanceID AND 
								BRM.VersionID = @VersionID AND
								BRM.BusinessRuleID = @BusinessRuleID
							) sub WHERE sub.BR01_StepID = BRS.BR01_StepID AND sub.BR01_StepPartID = BRS.BR01_StepPartID AND sub.DimensionID = DCD.DimensionID)

				IF @Debug <> 0 SELECT TempTable = '#MissingDimension', * FROM #MissingDimension
			END

	SET @Step = 'BR01_Master'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 1,
					BusinessRuleID,
					Comment,
					DataClassID,
					BaseObject,
					BeforeFxYN,
					DimensionSetting,
					DimensionFilter,
					ValidYN = CASE WHEN (SELECT COUNT(1) FROM #MissingDimension) > 0 THEN 0 ELSE 1 END
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Master]
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					BusinessRuleID = @BusinessRuleID AND
					DeletedID IS NULL
				ORDER BY
					BusinessRuleID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'BR01_Step'
		IF @ResultTypeBM & 2 > 0
			BEGIN
			--TODO:
			--1. Get the DimensionName

				SELECT 
					@DimensionName = BaseObject
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Master]
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					BusinessRuleID = @BusinessRuleID AND
					DeletedID IS NULL

				SELECT
					@DimensionID = DimensionID
				FROM
					Dimension
				WHERE
					InstanceID IN (0, @InstanceID) AND
					DimensionName = @DimensionName

				SELECT
					@StorageTypeBM = StorageTypeBM
				FROM
					Dimension_StorageType
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND 
					DimensionID = @DimensionID

				--TODO: Add handling of StorageTypeBM 1 and 2		
				IF @StorageTypeBM & 4 > 0
					SELECT
						@DimensionTable = DestinationDatabase + '.[dbo].[S_DS_' + @DimensionName + ']'
					FROM
						[Application]
					WHERE
						InstanceID = @InstanceID AND
						VersionID = @VersionID	

				SET @SQLStatement = '
					SELECT 
						ResultTypeBM = 2,
						BS.BusinessRuleID,
						BS.BR01_StepID,
						BS.BR01_StepPartID,
						Comment,
						MemberKey,
						MemberDescription = ISNULL(D.Description, BS.MemberKey),
						ModifierID,
						Parameter,
						DataClassID,
						[Decimal],
						BS.DimensionFilter,
						ValueFilter,
						Operator,
						MultiplyWith,
						SortOrder = ISNULL(BSSO.SortOrder, BS.BR01_StepID),
						ValidYN = CASE WHEN MR.MissingRow > 0 THEN 0 ELSE 1 END
					FROM
						[pcINTEGRATOR_Data].[dbo].[BR01_Step] BS
						LEFT JOIN [pcINTEGRATOR_Data].[dbo].[BR01_Step_SortOrder] BSSO ON BSSO.[InstanceID] = BS.InstanceID AND BSSO.[VersionID] = BS.VersionID AND BSSO.[BusinessRuleID] = BS.BusinessRuleID AND BSSO.[BR01_StepID] = BS.[BR01_StepID]
						LEFT JOIN ' + @DimensionTable + ' D ON D.Label = BS.MemberKey
						LEFT JOIN (SELECT BR01_StepID, BR01_StepPartID, MissingRow = COUNT(1) FROM #MissingDimension GROUP BY BR01_StepID, BR01_StepPartID) MR ON MR.BR01_StepID = BS.BR01_StepID AND MR.BR01_StepPartID = BS.BR01_StepPartID
					WHERE
						BS.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND
						BS.VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ' AND
						BS.BusinessRuleID = ' + CONVERT(NVARCHAR(15), @BusinessRuleID) + '
					ORDER BY
						BS.BusinessRuleID,
						ISNULL(BSSO.SortOrder, BS.BR01_StepID),
						BS.BR01_StepPartID'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'BR01_StepPart'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT 
					ResultTypeBM =4,
					BR01_StepPartID,
					BR01_StepPartName,
					LogicDescription,
					DataClassYN,
					DecimalYN,
					DimensionFilterYN,
					OperatorYN
				FROM
					BR01_StepPart
				ORDER BY
					BR01_StepPartID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'BR_Modifier'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 8,
					ModifierID,
					ModifierName,
					Parameter,
					ModifierDescription
				FROM
					BR_Modifier
				WHERE
					SelectYN <> 0
				ORDER BY
					ModifierID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'DataClass'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 16,
					DataClassID,
					DataClassName
				FROM
					DataClass
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID
				ORDER BY
					DataClassID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Missing Dimension'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 32,
					MD.DimensionID,
					D.DimensionName
				FROM
					#MissingDimension MD
					INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = MD.DimensionID
				ORDER BY
					D.DimensionName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Parameters'
		IF @ResultTypeBM & 64 > 0
			BEGIN
				SELECT DISTINCT
					[ResultTypeBM] = 64,
					[Parameter] = [par].[name],
					[DisplayName] = REPLACE([par].[name], '@', ''),
					[DataType] = MAX(ISNULL(DT.DataTypePortal, [type].[name])),
					[GuiObject] = MAX(ISNULL(DT.GuiObject, 'TextBox'))
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR01_Step] BRS
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRule] BR ON BR.[InstanceID] = BRS.[InstanceID] AND BR.[VersionID] = BRS.[VersionID] AND BR.[BusinessRuleID] = BRS.[BusinessRuleID] 
					INNER JOIN [BR_Type] BRT ON BRT.[InstanceID] IN (0, BR.[InstanceID]) AND BRT.[VersionID] IN (0, BR.[VersionID]) AND BRT.[BR_TypeID] = BR.[BR_TypeID]
					INNER JOIN sys.procedures [proc] ON [proc].[name] = 'spBR_' + BRT.[BR_TypeCode]
					INNER JOIN sys.parameters [par] ON [par].[object_id] = [proc].[object_id] AND [par].[name] NOT IN ('@BusinessRuleID')
					INNER JOIN sys.types [type] ON [type].user_type_id = [par].user_type_id
					LEFT JOIN [@Template_DataType] DT ON DT.DataTypeCode = [type].[name]
					INNER JOIN [Procedure] P ON P.[ProcedureName] = [proc].[name]
					INNER JOIN [ProcedureParameter] PP ON PP.ProcedureID = P.[ProcedureID] AND '@' + PP.[Parameter] = [par].[name]
				WHERE
					BRS.[InstanceID] = @InstanceID AND
					BRS.[VersionID] = @VersionID AND
					BRS.[BusinessRuleID] = @BusinessRuleID
				GROUP BY
					[par].[name]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #MissingDimension
		DROP TABLE #DimensionSetting

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
