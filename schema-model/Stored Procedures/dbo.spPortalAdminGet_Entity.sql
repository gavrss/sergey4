SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Entity]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 63, --1=Entity, 2=Entity tree, 4=Book, 8=FiscalYear, 16=Count enabled Legal Entities, 32=EntityType, 64=BookType, 128=Consolidation method, 256=EntityGroup, 512=Country, 1024=Book properties
	@BookTypeBM int = NULL, --1 = Financials, 2 = Main, 4 = FxRate, 8 = Other
	@ShowAllYN bit = 0, --0 = Shows enabled Entities and Books, 1 = Shows all Entities and Books
	@EntityID int = NULL,
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@EntityGroupID int = NULL,
	@EntityParentID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000286,
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
EXEC [spPortalAdminGet_Entity] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @ResultTypeBM = 1023, @Entity_MemberKey = 'BAXLEY', @DebugBM = 3
EXEC [spPortalAdminGet_Entity] @UserID = -10, @InstanceID = -1412, @VersionID = -1350, @ResultTypeBM = 1023, @Entity_MemberKey = 'BAXLEY', @ShowAllYN = 1, @DebugBM = 3
EXEC [spPortalAdminGet_Entity] @UserID = -10, @InstanceID = -1412, @VersionID = -1350, @ResultTypeBM = 1023, @ShowAllYN = 1, @DebugBM = 3

EXEC [spPortalAdminGet_Entity] @ResultTypeBM = 64 --BookTypeBM
EXEC [spPortalAdminGet_Entity] @ResultTypeBM = 512 --CountryID
EXEC [spPortalAdminGet_Entity] @InstanceID = -1335, @ResultTypeBM = 1024 --BalanceType, COA, Currency

EXEC [spPortalAdminGet_Entity] @GetVersion = 1
*/

/*
ResultTypeBM 2 returns resultset to construct Entity tree.
ResultTypeBM 1 and 4 gives Entities and Books to be placed into the tree.
ResultTypeBM 16 counts selected Entities.
*/

SET ANSI_WARNINGS OFF

DECLARE
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
	@Version nvarchar(50) = '2.1.0.2163'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Displays Entity Tree and related objects.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2141' SET @Description = 'Added ResultTypeBM = 8.'
		IF @Version = '2.0.2.2150' SET @Description = 'Code enhancement.'
		IF @Version = '2.0.3.2153' SET @Description = 'Added more result types.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added Priority and ResultTypes for tree handling.'
		IF @Version = '2.1.0.2163' SET @Description = 'DB-581 Exclude deleted Entities.'

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

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@EntityID = ISNULL(@EntityID, EntityID),
			@Entity_MemberKey = ISNULL(@Entity_MemberKey, MemberKey)
		FROM
			pcINTEGRATOR_Data..Entity
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			(EntityID = @EntityID OR MemberKey = @Entity_MemberKey)

		IF @DebugBM & 2 > 0
			SELECT
				[@EntityID] = @EntityID,
				[@Entity_MemberKey] = @Entity_MemberKey

	SET @Step = '@ResultTypeBM & 1, Entity'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT DISTINCT
					ResultTypeBM = 1,
					EntityID = E.EntityID,
					MemberKey = E.MemberKey,
					EntityName = E.EntityName,
					EntityTypeID = E.EntityTypeID,
					EntityTypeName = ET.EntityTypeName,
					LegalName = E.LegalName,
					LegalID = E.LegalID,
					[CountryID] = E.[CountryID],
					[Priority] = E.[Priority], 
					SelectYN = E.SelectYN
				FROM
					Entity E
					LEFT JOIN EntityType ET ON ET.EntityTypeID = E.EntityTypeID
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					(E.EntityID = @EntityID OR @EntityID IS NULL) AND
					(E.SelectYN <> 0 OR @ShowAllYN <> 0) AND
					E.[DeletedID] IS NULL
				ORDER BY
					E.MemberKey

				SET @Selected = @Selected + @@ROWCOUNT
			END
		
	SET @Step = '@ResultTypeBM & 2, Entity tree/Ownership'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 2,
					EntityGroupID = EH.EntityGroupID,
					EntityGroupName = EG.EntityName,
					EntityID = EH.EntityID,
					MemberKey = E.MemberKey,
					EntityName = E.EntityName,
					EntityParentID = EH.ParentID,
					EntityTypeID = E.EntityTypeID,
					EntityTypeName = ET.EntityTypeName,
					LegalName = E.LegalName,
					LegalID = E.LegalID,
					[CountryID] = E.[CountryID],
					[Priority] = E.[Priority], 
					ValidFrom = EH.ValidFrom,
					EH.OwnershipDirect,
					EH.OwnershipUltimate,
					EH.OwnershipConsolidation,
					EH.ConsolidationMethodBM,
					SortOrder = EH.SortOrder,
					SelectYN = E.SelectYN
				FROM
					EntityHierarchy EH
					INNER JOIN Entity E ON E.InstanceID = EH.InstanceID AND E.VersionID = @VersionID AND E.EntityID = EH.EntityID AND (E.SelectYN <> 0 OR @ShowAllYN <> 0) AND E.[DeletedID] IS NULL
					INNER JOIN Entity EG ON E.InstanceID = EH.InstanceID AND E.VersionID = @VersionID AND EG.EntityID = EH.EntityGroupID AND EG.[DeletedID] IS NULL
					LEFT JOIN EntityType ET ON ET.EntityTypeID = E.EntityTypeID
				WHERE
					EH.InstanceID = @InstanceID AND
					EH.VersionID = @VersionID AND
					(EH.EntityID = @EntityID OR @EntityID IS NULL) AND
					(EH.EntityGroupID = @EntityGroupID OR @EntityGroupID IS NULL) AND
					(EH.ParentID = @EntityParentID OR @EntityParentID IS NULL)
				ORDER BY
					EH.SortOrder

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 4, Books'
		IF @ResultTypeBM & 4 > 0  
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					[EntityID] = EB.[EntityID],
					[MemberKey] = E.[MemberKey],
					[EntityName] = E.[EntityName],
					[Book] = EB.[Book],
					[Currency] = EB.[Currency],
					[BookTypeBM] = EB.[BookTypeBM],
					[COA] = EB.[COA],
					[BalanceType] = EB.[BalanceType],
					[SelectYN] = EB.[SelectYN]
				FROM
					Entity_Book EB
					INNER JOIN Entity E ON E.InstanceID = EB.InstanceID AND E.VersionID = @VersionID AND E.EntityID = EB.EntityID AND (E.EntityID = @EntityID OR @EntityID IS NULL) AND (E.SelectYN <> 0 OR @ShowAllYN <> 0)
				WHERE
					EB.InstanceID = @InstanceID AND
					EB.VersionID = @VersionID AND
					(EB.BookTypeBM & @BookTypeBM > 0 OR @BookTypeBM IS NULL) AND
					(EB.Book = @Book OR @Book IS NULL) AND
					(EB.SelectYN <> 0 OR @ShowAllYN <> 0)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM = 8, FiscalYear'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					ResultTypeBM = 8,
					EFY.EntityID,
					EFY.Book,
					EFY.StartMonth,
					EFY.EndMonth,
					FYPeriods# = 12
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear] EFY
--					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.InstanceID = EFY.InstanceID AND EB.VersionID = EFY.VersionID AND EB.EntityID = EFY.EntityID AND EB.Book = EFY.Book
--					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = EB.InstanceID AND E.VersionID = @VersionID AND E.EntityID = EB.EntityID
				WHERE
					EFY.InstanceID = @InstanceID AND
					EFY.VersionID = @VersionID AND
					(EFY.EntityID = @EntityID OR @EntityID IS NULL) AND
					(EFY.Book = @Book OR @Book IS NULL)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 16, Count enabled Entities'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT 
					ResultTypeBM = 16,
					EntityLicensed# = COUNT(1),
					EntitySelected# = COUNT(CASE WHEN SelectYN <> 0 THEN 1 END)
				FROM
					Entity
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					EntityTypeID = -1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 32, Entity types'
		IF @ResultTypeBM & 32 > 0  
			BEGIN
				SELECT 
					[ResultTypeBM] = 32,
					[EntityTypeID],
					[EntityTypeName],
					[EntityTypeDescription]
				FROM
					[EntityType]
				ORDER BY
					[EntityTypeID] DESC

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 64, BookType'
		IF @ResultTypeBM & 64 > 0  
			BEGIN
				SELECT 
					[ResultTypeBM] = 64,
					[BookTypeBM],
					[BookTypeName]
				FROM
					[BookType]
				ORDER BY
					[BookTypeBM]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 128, Consolidation method'
		IF @ResultTypeBM & 128 > 0  
			BEGIN
				SELECT 
					[ResultTypeBM] = 128,
					[ConsolidationMethodBM],
					[ConsolidationMethodName],
					[ConsolidationMethodDescription]
				FROM
					[ConsolidationMethod]
				ORDER BY
					[ConsolidationMethodBM]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 256, EntityGroup'
		IF @ResultTypeBM & 256 > 0  
			BEGIN
				SELECT DISTINCT
					[ResultTypeBM] = 256,
					EH.EntityGroupID,
					GroupName = EG.EntityName
				FROM
					pcINTEGRATOR_Data..[EntityHierarchy] EH
					INNER JOIN Entity EG ON EG.EntityID = EH.EntityGroupID
				WHERE
					EH.InstanceID = @InstanceID AND
					EH.VersionID = @VersionID AND
					(EH.EntityID = @EntityID OR @EntityID IS NULL)
				ORDER BY
					EG.EntityName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM = 512, Country'
		IF @ResultTypeBM & 512 > 0
			BEGIN
				SELECT
					ResultTypeBM = 512, 
					CountryID,
					CountryCode,
					CountryName,
					ISO_Alpha_2,
					ISO_Alpha_3,
					ISO_Numeric
				FROM
					Country
				ORDER BY
					CountryName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM = 1024, Book properties'
		IF @ResultTypeBM & 1024 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 1024,
					[Property],
					[PropertyValue],
					[Description]
				FROM
					(
					SELECT DISTINCT
						[Property] = 'Currency',
						[PropertyValue] = EB.[Currency],
						[Description] = ISNULL(C.[Description], EB.[Currency])
					FROM 
						pcINTEGRATOR_Data..Entity_Book EB
						LEFT JOIN (SELECT [Currency] = [Label], [Description] = [HelpText] FROM Member WHERE DimensionID = -3) C ON C.[Currency] = EB.[Currency]
					WHERE
						EB.[InstanceID] = @InstanceID AND
						EB.[Currency] IS NOT NULL

					UNION SELECT DISTINCT
						[Property] = 'COA',
						[PropertyValue] = EB.[COA],
						[Description] = 'Chart of Account: ' + EB.[COA]
					FROM 
						pcINTEGRATOR_Data..Entity_Book EB
					WHERE
						EB.[InstanceID] = @InstanceID AND
						EB.[COA] IS NOT NULL

					UNION SELECT DISTINCT
						[Property] = 'BalanceType',
						[PropertyValue] = EB.[BalanceType],
						[Description] = 'BalanceType: ' + EB.[BalanceType]
					FROM 
						pcINTEGRATOR_Data..Entity_Book EB
					WHERE
						EB.[InstanceID] = @InstanceID AND
						EB.[BalanceType] IS NOT NULL AND
						EB.[SelectYN] <> 0
					) sub
				ORDER BY
					[Property],
					[PropertyValue]
		END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
