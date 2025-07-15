SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_PropertyList]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@PropertyName nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000742,
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
EXEC [spGet_PropertyList] @PropertyName = 'DataClassType'
EXEC [spGet_PropertyList] @PropertyName = 'StorageType'
EXEC [spGet_PropertyList] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @PropertyName = 'Dimension'
EXEC [spGet_PropertyList] @PropertyName = 'Flow'
EXEC [spGet_PropertyList] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @PropertyName = 'Entity'
EXEC [spGet_PropertyList] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @PropertyName = 'ICCounterPart'
EXEC [spGet_PropertyList] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @PropertyName = 'ICCounterPart'

EXEC [spGet_PropertyList] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@JournalTable nvarchar(100),

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
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get rows from specified table',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2165' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2170' SET @Description = 'Added more PropertyNames.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added more PropertyNames.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added more rows for ICCounterpart (UNSPECIFIED).'
		IF @Version = '2.1.2.2179' SET @Description = 'Made Flow dynamic.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added Book.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		SELECT
			@CallistoDatabase = [DestinationDatabase]
		FROM
			pcINTEGRATOR_Data..[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

	SET @Step = 'DataClassType'
		IF @PropertyName = 'DataClassType'
			SELECT 
				[ID] = [DataClassTypeID],
				[Name] = [DataClassTypeName],
				[Description] = [DataClassTypeName],
				[ParentID] = NULL,
				[ValueListParameter] = NULL
			FROM
				[pcINTEGRATOR].[dbo].[DataClassType]
			ORDER BY
				[DataClassTypeName]

			SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'StorageType'
		IF @PropertyName = 'StorageType'
			SELECT
				[ID] = [StorageTypeBM],
				[Name] = [StorageTypeName],
				[Description] = [StorageTypeDescription],
				[ParentID] = NULL,
				[ValueListParameter] = NULL
			FROM
				[pcINTEGRATOR].[dbo].[StorageType]
			ORDER BY
				[StorageTypeBM]

			SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Dimension'
		IF @PropertyName = 'Dimension'
			SELECT
				[ID] = DST.[DimensionID],
				[Name] = D.[DimensionName],
				[Description] = D.[DimensionDescription],
				[ParentID] = NULL,
				[ValueListParameter] = NULL		
			FROM
				[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
				INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.DimensionID = DST.[DimensionID]
			WHERE
				DST.[InstanceID] = @InstanceID AND
				DST.[VersionID] = @VersionID
			ORDER BY
				D.[DimensionName]

			SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Entity'
		IF @PropertyName = 'Entity'
			BEGIN
				SELECT
					[ID] = E.MemberKey,
					[Name] = E.MemberKey,
					[Description] = E.[EntityName],
					[ParentID] = NULL,
					[ValueListParameter] = NULL
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity] E
				WHERE
					E.[InstanceID] = @InstanceID AND
					E.[VersionID] = @VersionID AND
					E.EntityTypeID = -1 AND
					E.[SelectYN] <> 0 AND
					E.[DeletedID] IS NULL
				ORDER BY
					E.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Book'
		IF @PropertyName = 'Book'
			BEGIN
				SELECT DISTINCT
					[ID] = EB.Book,
					[Name] = EB.Book,
					[Description] = EB.[Book],
					[ParentID] = NULL,
					[ValueListParameter] = NULL
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity] E
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.EntityID = E.EntityID AND EB.BookTypeBM & 3 = 3 AND EB.[SelectYN] <> 0
				WHERE
					E.[InstanceID] = @InstanceID AND
					E.[VersionID] = @VersionID AND
					E.EntityTypeID = -1 AND
					E.[SelectYN] <> 0 AND
					E.[DeletedID] IS NULL
				ORDER BY
					EB.[Book]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Group'
		IF @PropertyName = 'Group'
			BEGIN
				SELECT
					[ID] = E.MemberKey,
					[Name] = E.MemberKey,
					[Description] = E.[EntityName],
					[ParentID] = NULL,
					[ValueListParameter] = NULL
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity] E
				WHERE
					E.[InstanceID] = @InstanceID AND
					E.[VersionID] = @VersionID AND
					E.EntityTypeID = 0 AND
					E.[SelectYN] <> 0 AND
					E.[DeletedID] IS NULL
				ORDER BY
					E.[MemberKey]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Flow'
		IF @PropertyName = 'Flow'
			BEGIN 
				SET @SQLStatement = '
					SELECT
						[ID] = D.[Label],
						[Name] = D.[Label],
						[Description] = D.[Description],
						[ParentID] = CASE WHEN P.[Label] = ''All_'' THEN NULL ELSE P.[Label] END,
						[ValueListParameter] = NULL
					FROM
						[' + @CallistoDatabase + '].[dbo].[S_DS_Flow] D
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_HS_Flow_Flow] H ON H.[MemberId] = D.[MemberId]
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Flow] P ON P.[MemberId] = H.[ParentMemberId]
					WHERE
						D.[RNodeType] LIKE ''L%''
					ORDER BY
						D.[Label]'

				PRINT @SQLStatement

				EXEC (@SQLStatement)
			END

	SET @Step = 'FiscalYear'
		IF @PropertyName = 'FiscalYear'
			BEGIN 
				EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT

				SET @SQLStatement = '
					SELECT DISTINCT
						[ID] = J.[FiscalYear],
						[Name] = J.[FiscalYear],
						[Description] = J.[FiscalYear],
						[ParentID] = NULL,
						[ValueListParameter] = NULL
					FROM
						' + @JournalTable + ' J
					ORDER BY
						J.[FiscalYear]'

				PRINT @SQLStatement

				EXEC (@SQLStatement)
			END

	SET @Step = 'JournalSequence'
		IF @PropertyName = 'JournalSequence'
			BEGIN 
				EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT

				SET @SQLStatement = '
					SELECT DISTINCT
						[ID] = J.[JournalSequence],
						[Name] = J.[JournalSequence],
						[Description] = J.[JournalSequence],
						[ParentID] = NULL,
						[ValueListParameter] = NULL
					FROM
						' + @JournalTable + ' J
					WHERE
						TransactionTypeBM & 3 > 0
					ORDER BY
						J.[JournalSequence]'

				PRINT @SQLStatement

				EXEC (@SQLStatement)
			END

	SET @Step = 'BR05_FormulaAmount'
		IF @PropertyName = 'BR05_FormulaAmount'
			SELECT
				[ID] = [FormulaAmountID],
				[Name] = ISNULL([FormulaAmount], [FormulaAmountName]),
				[Description] = [FormulaAmountName],
				[ParentID] = NULL,
				[ValueListParameter] = NULL
			FROM
				[pcINTEGRATOR].[dbo].[BR05_FormulaAmount]
			WHERE
				[InstanceID] IN (0, @InstanceID) AND
				[VersionID] IN (0, @VersionID)
			ORDER BY
				[FormulaAmountID] DESC

			SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'BR05_FormulaFX'
		IF @PropertyName = 'BR05_FormulaFX'
			SELECT
				[ID] = [FormulaFXID],
				[Name] = ISNULL([FormulaFX], [FormulaFXName]),
				[Description] = [FormulaFXName],
				[ParentID] = NULL,
				[ValueListParameter] = NULL
			FROM
				[pcINTEGRATOR].[dbo].[BR05_FormulaFX]
			WHERE
				[InstanceID] IN (0, @InstanceID) AND
				[VersionID] IN (0, @VersionID)
			ORDER BY
				[FormulaFXID] DESC

			SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'ConsolidationMethod'
		IF @PropertyName = 'ConsolidationMethod'
			SELECT
				[ID] = [ConsolidationMethodBM],
				[Name] = [ConsolidationMethodName],
				[Description] = [ConsolidationMethodDescription],
				[ParentID] = NULL,
				[ValueListParameter] = NULL 
			FROM
				[pcINTEGRATOR].[dbo].[ConsolidationMethod]
			ORDER BY
				[ConsolidationMethodName]

			SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'ObjectGuiBehavior'
		IF @PropertyName = 'ObjectGuiBehavior'
			SELECT
				[ID] = [ObjectGuiBehaviorBM],
				[Name] = [ObjectGuiBehaviorName],
				[Description] = [ObjectGuiBehaviorName],
				[ParentID] = NULL,
				[ValueListParameter] = NULL 
			FROM
				[pcINTEGRATOR].[dbo].[ObjectGuiBehavior]
			ORDER BY
				[ObjectGuiBehaviorName]

			SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Modifier'
		IF @PropertyName = 'Modifier'
			SELECT
				[ID] = [ModifierID],
				[Name] = [ModifierName],
				[Description] = [ModifierDescription],
				[ParentID] = NULL,
				[ValueListParameter] = NULL 
			FROM
				[pcINTEGRATOR].[dbo].[BR_Modifier]
			WHERE
				[SelectYN] <> 0
			ORDER BY
				[ModifierName]

			SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'ICCounterpart'
		IF @PropertyName = 'ICCounterpart'
			BEGIN
				SELECT
					[ID] = E.MemberKey,
					[Name] = E.MemberKey,
					[Description] = E.[EntityName],
					[ParentID] = NULL,
					[ValueListParameter] = 'Fixed'
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity] E
				WHERE
					E.[InstanceID] = @InstanceID AND
					E.[VersionID] = @VersionID AND
					E.EntityTypeID = -1 AND
					E.[SelectYN] <> 0 AND
					E.[DeletedID] IS NULL
				UNION SELECT
					[ID] = 'NONE',
					[Name] = 'NONE',
					[Description] = 'NONE',
					[ParentID] = NULL,
					[ValueListParameter] = 'Fixed'

				UNION SELECT
					[ID] = 'UNSPECIFIED',
					[Name] = 'UNSPECIFIED',
					[Description] = 'Not specified Intercompany',
					[ParentID] = NULL,
					[ValueListParameter] = 'Fixed'

				UNION SELECT
					[ID] = '[' + D.[DimensionName] + '].[' + P.[PropertyName] + ']',
					[Name] = '[' + D.[DimensionName] + '].[' + P.[PropertyName] + ']',
					[Description] = '[' + D.[DimensionName] + '].[' + P.[PropertyName] + ']',
					[ParentID] = NULL,
					[ValueListParameter] = 'Property'
				FROM
					pcINTEGRATOR..Dimension_Property DP
					INNER JOIN pcINTEGRATOR..Property P ON P.PropertyID = DP.PropertyID
					INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionID = DP.DimensionID
				WHERE
					DP.InstanceID = @InstanceID AND
					DP.VersionID = @VersionID AND
					DP.PropertyID = -162 

				UNION SELECT
					[ID] = '>=50%',
					[Name] = '>=50%',
					[Description] = '>=50%',
					[ParentID] = NULL,
					[ValueListParameter] = 'Owner'

				ORDER BY
					[ValueListParameter],
					[ID]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'DataClass'
		IF @PropertyName = 'DataClass'
			SELECT
				[ID] = DC.[DataClassID],
				[Name] = DC.[DataClassName],
				[Description] = DC.[DataClassDescription],
				[ParentID] = NULL,
				[ValueListParameter] = NULL		
			FROM
				[pcINTEGRATOR_Data].[dbo].[DataClass] DC
			WHERE
				DC.[InstanceID] = @InstanceID AND
				DC.[VersionID] = @VersionID AND
				DC.SelectYN <> 0  AND
				DC.DeletedID IS NULL
			ORDER BY
				DC.[DataClassName]

			SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
