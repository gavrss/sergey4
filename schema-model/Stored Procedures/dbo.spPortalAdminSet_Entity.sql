SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Entity]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JSON_table nvarchar(MAX) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000727,
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
--1=Entity, 2=Entity tree, 4=Book, 8=FiscalYear
DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "1", "EntityID": "24041", "CountryID": "840"},
	{"ResultTypeBM" : "2", "EntityGroupID": "24053", "EntityID": "24041", "EntityParentID": "24053", "ValidFrom": "2018-01-01", "SortOrder": "100"},
	{"ResultTypeBM" : "2", "EntityGroupID": "24047", "EntityID": "24041", "EntityParentID": "24047", "ValidFrom": "2018-07-01", "SortOrder": "200"},
	{"ResultTypeBM" : "4", "EntityID": "24041", "Book": "MAIN", "COA": "ARNE"},
	{"ResultTypeBM" : "4", "EntityID": "24041", "Book": "FxRate", "COA": "NONE"},
	{"ResultTypeBM" : "8", "EntityID": "24041", "Book": "MAIN", "StartMonth": "190001", "EndMonth": "209912"}
	]'

EXEC [dbo].[spPortalAdminSet_Entity] 
	@UserID = -10,
	@InstanceID = -1412,
	@VersionID = -1350,
	@DebugBM = 7,
	@JSON_table = @JSON_table

EXEC [spPortalAdminSet_Entity] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@EntityID int,
	@DeletedID int,

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
			@ProcedureDescription = 'Maintain Entities and Books',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2163' SET @Description = 'Enable possibility to add Entity and Book in one step.'

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create and fill #EntityTable'
		CREATE TABLE #EntityTable
			(
			[ResultTypeBM] int,
			[EntityID] int,
			[MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[EntityName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[EntityTypeID] int,
			[LegalID] int,
			[LegalName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[CountryID] int,
			[Priority] int,
			[EntityGroupID] [int],
			[EntityParentID] [int],
			[ValidFrom] [date],
			[OwnershipDirect] [float],
			[OwnershipUltimate] [float],
			[OwnershipConsolidation] [float],
			[ConsolidationMethodBM] [int],
			[SortOrder] [int],
			[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Currency] [nchar](3) COLLATE DATABASE_DEFAULT,
			[BookTypeBM] [int],
			[COA] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[BalanceType] [nvarchar](10) COLLATE DATABASE_DEFAULT,
			[Entity_FiscalYearID] [int],
			[StartMonth] [int],
			[EndMonth] [int],
			[SelectYN] bit,
			[DeleteYN] bit DEFAULT 0
			)			

		IF @JSON_table IS NOT NULL	
			INSERT INTO #EntityTable
				(
				[ResultTypeBM],
				[EntityID],
				[MemberKey],
				[EntityName],
				[EntityTypeID],
				[LegalID],
				[LegalName],
				[CountryID],
				[Priority],
				[EntityGroupID],
				[EntityParentID],
				[ValidFrom],
				[OwnershipDirect],
				[OwnershipUltimate],
				[OwnershipConsolidation],
				[ConsolidationMethodBM],
				[SortOrder],
				[Book],
				[Currency],
				[BookTypeBM],
				[COA],
				[BalanceType],
				[Entity_FiscalYearID],
				[StartMonth],
				[EndMonth],
				[SelectYN],
				[DeleteYN]
				)
			SELECT
				[ResultTypeBM],
				[EntityID],
				[MemberKey],
				[EntityName],
				[EntityTypeID],
				[LegalID],
				[LegalName],
				[CountryID],
				[Priority],
				[EntityGroupID],
				[EntityParentID],
				[ValidFrom],
				[OwnershipDirect],
				[OwnershipUltimate],
				[OwnershipConsolidation],
				[ConsolidationMethodBM],
				[SortOrder],
				[Book],
				[Currency],
				[BookTypeBM],
				[COA],
				[BalanceType],
				[Entity_FiscalYearID],
				[StartMonth],
				[EndMonth],
				[SelectYN],
				[DeleteYN] = ISNULL([DeleteYN], 0)
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				[ResultTypeBM] int,
				[EntityID] int,
				[MemberKey] nvarchar(50),
				[EntityName] nvarchar(100),
				[EntityTypeID] int,
				[LegalID] int,
				[LegalName] nvarchar(100),
				[CountryID] int,
				[Priority] int,
				[EntityGroupID] [int],
				[EntityParentID] [int],
				[ValidFrom] [smalldatetime],
				[OwnershipDirect] [float],
				[OwnershipUltimate] [float],
				[OwnershipConsolidation] [float],
				[ConsolidationMethodBM] [int],
				[SortOrder] [int],
				[Book] [nvarchar](50),
				[Currency] [nchar](3),
				[BookTypeBM] [int],
				[COA] [nvarchar](50),
				[BalanceType] [nvarchar](10),
				[Entity_FiscalYearID] [int],
				[StartMonth] [int],
				[EndMonth] [int],
				[SelectYN] bit,
				[DeleteYN] bit
				)
		ELSE
			GOTO EXITPOINT

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#EntityTable', * FROM #EntityTable

		--Set EntityID if missing
		UPDATE ET
		SET
			EntityID = E.EntityID
		FROM
			#EntityTable ET
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.[InstanceID] = @InstanceID AND E.[VersionID] = @VersionID AND E.[MemberKey] = ET.[MemberKey] AND E.[DeletedID] IS NULL
		WHERE
			ET.EntityID IS NULL

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#EntityTable', * FROM #EntityTable

	SET @Step = 'ResultTypeBM = 1, Entities' 
		--Update
		UPDATE
			E
		SET
			[MemberKey] = ISNULL(ET.[MemberKey], E.[MemberKey]),
			[EntityName] = ISNULL(ET.[EntityName], E.[EntityName]),
			[EntityTypeID] = ISNULL(ET.[EntityTypeID], E.[EntityTypeID]),
			[LegalID] = ISNULL(ET.[LegalID], E.[LegalID]),
			[LegalName] = ISNULL(ET.[LegalName], E.[LegalName]),
			[CountryID] = ISNULL(ET.[CountryID], E.[CountryID]),
			[Priority] = ISNULL(ET.[Priority], E.[Priority]),
			[SelectYN] = ISNULL(ET.[SelectYN], E.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN #EntityTable ET ON ET.[ResultTypeBM] & 1 > 0 AND ET.[EntityID] = E.[EntityID]
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[DeletedID] IS NULL
			
		SET @Updated = @Updated + @@ROWCOUNT

		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity]
			(
			[InstanceID],
			[VersionID],
			[MemberKey],
			[EntityName],
			[EntityTypeID],
			[LegalID],
			[LegalName],
			[CountryID],
			[Priority],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[MemberKey],
			[EntityName],
			[EntityTypeID],
			[LegalID],
			[LegalName],
			[CountryID] = ISNULL([CountryID], -1),
			[Priority],
			[SelectYN] = ISNULL([SelectYN], 1)
		FROM
			#EntityTable ET
		WHERE	
			ET.[ResultTypeBM] & 1 > 0 AND
			ET.[DeleteYN] = 0 AND
			ET.[EntityID] IS NULL AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Entity] ED WHERE ED.[InstanceID] = @InstanceID AND ED.[VersionID] = @VersionID AND ED.[MemberKey] = ET.[MemberKey] AND ED.[DeletedID] IS NULL)
			
		SET @Inserted = @Inserted + @@ROWCOUNT

		--Set EntityID if added
		UPDATE ET
		SET
			EntityID = E.EntityID
		FROM
			#EntityTable ET
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.[InstanceID] = @InstanceID AND E.[VersionID] = @VersionID AND E.[MemberKey] = ET.[MemberKey] AND E.[DeletedID] IS NULL
		WHERE
			ET.EntityID IS NULL

		--Delete
		IF CURSOR_STATUS('global','Delete_Cursor') >= -1 DEALLOCATE Delete_Cursor
		DECLARE Delete_Cursor CURSOR FOR
			
			SELECT
				ET.EntityID
			FROM	
				#EntityTable ET
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON
					E.[InstanceID] = @InstanceID AND
					E.[VersionID] = @VersionID AND
					E.[EntityID] = ET.EntityID AND
					E.[DeletedID] IS NULL
			WHERE
				ET.[ResultTypeBM] & 1 > 0 AND
				ET.[DeleteYN] <> 0

			OPEN Delete_Cursor
			FETCH NEXT FROM Delete_Cursor INTO @EntityID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@EntityID] = @EntityID

					EXEC [dbo].[spGet_DeletedItem]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@TableName = 'Entity',
						@DeletedID = @DeletedID OUT,
						@JobID = @JobID

					UPDATE
						E
					SET
						[DeletedID] = @DeletedID
					FROM
						[pcINTEGRATOR_Data].[dbo].[Entity] E
					WHERE
						E.[InstanceID] = @InstanceID AND
						E.[VersionID] = @VersionID AND
						E.[EntityID] = @EntityID AND
						E.[DeletedID] IS NULL
			
					SET @Deleted = @Deleted + @@ROWCOUNT

					FETCH NEXT FROM Delete_Cursor INTO @EntityID
				END

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor

	SET @Step = 'ResultTypeBM = 2, Entity hierarchy'
		--Update
		UPDATE
			EH
		SET
			[OwnershipDirect] = ISNULL(ET.[OwnershipDirect], EH.[OwnershipDirect]),
			[OwnershipUltimate] = ISNULL(ET.[OwnershipUltimate], EH.[OwnershipUltimate]),
			[OwnershipConsolidation] = ISNULL(ET.[OwnershipConsolidation], EH.[OwnershipConsolidation]),
			[ConsolidationMethodBM] = ISNULL(ET.[ConsolidationMethodBM], EH.[ConsolidationMethodBM]),
			[SortOrder] = ISNULL(ET.[SortOrder], EH.[SortOrder])
		FROM
			[pcINTEGRATOR_Data].[dbo].[EntityHierarchy] EH
			INNER JOIN #EntityTable ET ON ET.[ResultTypeBM] & 2 > 0 AND ET.[EntityGroupID] = EH.[EntityGroupID] AND ET.[EntityID] = EH.[EntityID] AND ET.[EntityParentID] = EH.[ParentID] AND ET.[ValidFrom] = EH.[ValidFrom]
		WHERE
			EH.[InstanceID] = @InstanceID AND
			EH.[VersionID] = @VersionID
			
		SET @Updated = @Updated + @@ROWCOUNT

		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[EntityHierarchy]
			(
			[InstanceID],
			[VersionID],
			[EntityGroupID],
			[EntityID],
			[ParentID],
			[ValidFrom],
			[OwnershipDirect],
			[OwnershipUltimate],
			[OwnershipConsolidation],
			[ConsolidationMethodBM],
			[SortOrder] 
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[EntityGroupID],
			[EntityID],
			[EntityParentID],
			[ValidFrom],
			[OwnershipDirect],
			[OwnershipUltimate],
			[OwnershipConsolidation],
			[ConsolidationMethodBM],
			[SortOrder] = ISNULL([SortOrder], 0) 
		FROM
			#EntityTable ET
		WHERE	
			ET.[ResultTypeBM] & 2 > 0 AND
			ET.[DeleteYN] = 0 AND
			ET.[EntityGroupID] IS NOT NULL AND
			ET.[EntityID] IS NOT NULL AND
			ET.[EntityParentID] IS NOT NULL AND
			ET.[ValidFrom] IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[EntityHierarchy] EH WHERE EH.[InstanceID] = @InstanceID AND EH.[VersionID] = @VersionID AND EH.[EntityGroupID] = ET.[EntityGroupID] AND EH.[EntityID] = ET.[EntityID] AND EH.[ParentID] = ET.[EntityParentID] AND EH.[ValidFrom] = ET.[ValidFrom])
			
		SET @Inserted = @Inserted + @@ROWCOUNT

		--Delete
		DELETE EH
		FROM
			[pcINTEGRATOR_Data].[dbo].[EntityHierarchy] EH
			INNER JOIN #EntityTable ET ON ET.[ResultTypeBM] & 2 > 0 AND ET.[DeleteYN] <> 0 AND ET.[EntityGroupID] = EH.[EntityGroupID] AND ET.[EntityID] = EH.[EntityID] AND ET.[EntityParentID] = EH.[ParentID] AND ET.[ValidFrom] = EH.[ValidFrom]
		WHERE
			EH.[InstanceID] = @InstanceID AND
			EH.[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT


	SET @Step = 'ResultTypeBM = 4, Books'
		--Update
		UPDATE EB
		SET
			[Currency] = ISNULL(ET.[Currency], EB.[Currency]),
			[BookTypeBM] = ISNULL(ET.[BookTypeBM], EB.[BookTypeBM]),
			[COA] = ISNULL(ET.[COA], EB.[COA]),
			[BalanceType] = ISNULL(ET.[BalanceType], EB.[BalanceType]),
			[SelectYN] = ISNULL(ET.[SelectYN], EB.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity_Book] EB
			INNER JOIN #EntityTable ET ON ET.[ResultTypeBM] & 4 > 0 AND ET.[EntityID] = EB.[EntityID] AND ET.[Book] = EB.[Book]
		WHERE
			EB.[InstanceID] = @InstanceID AND
			EB.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_Book]
			(
			[InstanceID],
			[VersionID],
			[EntityID],
			[Book],
			[Currency],
			[BookTypeBM],
			[COA],
			[BalanceType],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[EntityID],
			[Book],
			[Currency],
			[BookTypeBM],
			[COA],
			[BalanceType],
			[SelectYN] = ISNULL([SelectYN], 1)
		FROM
			#EntityTable ET
		WHERE	
			ET.[ResultTypeBM] & 4 > 0 AND
			ET.[DeleteYN] = 0 AND
			ET.[EntityID] IS NOT NULL AND
			ET.[Book] IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB WHERE EB.[InstanceID] = @InstanceID AND EB.[VersionID] = @VersionID AND EB.[EntityID] = ET.[EntityID] AND EB.[Book] = ET.[Book])
			
		SET @Inserted = @Inserted + @@ROWCOUNT

		--Delete
		DELETE EB
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity_Book] EB
			INNER JOIN #EntityTable ET ON ET.[ResultTypeBM] & 4 > 0 AND ET.[DeleteYN] <> 0 AND ET.[EntityID] = EB.[EntityID] AND ET.[Book] = EB.[Book]
		WHERE
			EB.[InstanceID] = @InstanceID AND
			EB.[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'ResultTypeBM = 8, Entity_FiscalYear'
		--Update
		UPDATE EFY
		SET
			[EndMonth] = ISNULL(ET.[EndMonth], EFY.[EndMonth])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear] EFY
			INNER JOIN #EntityTable ET ON ET.[ResultTypeBM] & 8 > 0 AND ET.[Entity_FiscalYearID] = EFY.[Entity_FiscalYearID] AND ET.[EntityID] = EFY.[EntityID] AND ET.[Book] = EFY.[Book] AND ET.[StartMonth] = EFY.[StartMonth]
		WHERE
			EFY.[InstanceID] = @InstanceID AND
			EFY.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

		--Insert
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear]
			(
			[InstanceID],
			[VersionID],
			[EntityID],
			[Book],
			[StartMonth],
			[EndMonth]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[EntityID],
			[Book],
			[StartMonth],
			[EndMonth]
		FROM
			#EntityTable ET
		WHERE	
			ET.[ResultTypeBM] & 8 > 0 AND
			ET.[DeleteYN] = 0 AND
			ET.[EntityID] IS NOT NULL AND
			ET.[Book] IS NOT NULL AND
			ET.[StartMonth] IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear] EFY WHERE EFY.[InstanceID] = @InstanceID AND EFY.[VersionID] = @VersionID AND EFY.[EntityID] = ET.[EntityID] AND EFY.[Book] = ET.[Book] AND EFY.[StartMonth] = ET.[StartMonth])
			
		SET @Inserted = @Inserted + @@ROWCOUNT

		--Delete
		DELETE EFY
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear] EFY
			INNER JOIN #EntityTable ET ON ET.[ResultTypeBM] & 8 > 0 AND ET.[DeleteYN] <> 0 AND ET.[Entity_FiscalYearID] = EFY.[Entity_FiscalYearID] AND ET.[EntityID] = EFY.[EntityID] AND ET.[Book] = EFY.[Book] AND ET.[StartMonth] = EFY.[StartMonth]
		WHERE
			EFY.[InstanceID] = @InstanceID AND
			EFY.[VersionID] = @VersionID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Return EntityID'
		SELECT DISTINCT
			[ResultTypeBM] = 1,
			[EntityID],
			[MemberKey]
		FROM
			#EntityTable
		WHERE
			[ResultTypeBM] & 1 > 0

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
