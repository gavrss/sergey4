SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_Metadata_From_ETL_DB]
	@UserID int = -10,
	@InstanceID int = 390,
	@VersionID int = 1011,

	@DemoYN bit = 0,
	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Copied from Callisto',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000367,
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
	@ProcedureName = 'spSet_Metadata_From_ETL_DB',
	@JSON = '
		[
		{"TKey" : "DemoYN", "TValue": "1"},
		{"TKey" : "SourceServer",  "TValue": "DSPSOURCE01"},
		{"TKey" : "SourceDatabase",  "TValue": "ERP10"}
		]'

EXEC [spSet_Metadata_From_ETL_DB] 
	@UserID = -10,
	@InstanceID = 114,
	@VersionID = 1004,
	@Debug = 1

--GetVersion
EXEC [spSet_Metadata_From_ETL_DB] @GetVersion = 1
*/
DECLARE
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@SQLStatement nvarchar(max),	
	@ApplicationID int,
	@ApplicationName nvarchar(100),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),

	@AdminGroupID int,
	@FullAccessGroupID int,

	@AdminUserID int,

	@AdminRoleID int = -1,
	@FullAccessRoleID int = -2,

	@ObjectID_pcPortal int,
	@ObjectID_Callisto int,
	@ObjectID_Application int,

	@Email nvarchar(100) = NULL,
	@UserNameAD nvarchar(100) = NULL,
	@UserNameDisplay nvarchar(100) = NULL,
	@LocaleID int = -41,

	@MaxID int,
	@ReturnVariable int,

	@SourceID_Financials int, -- = 2743, --Temporary hard coded
	@SourceTypeID int,

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
			@ProcedureDescription = 'Set metadata in pcINTEGRATOR_Data collected from pcETL 1.4',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Changed ProcedureID.'
		IF @Version = '2.0.2.2146' SET @Description = 'Added column VersionID. Added INSERT statement on [EntityPropertyValue] Table for ENT setup.'
		IF @Version = '2.0.2.2148' SET @Description = 'Renamed column name SourceFormula on INSERT query to [Measure] table. Removed columns GetProc and SetProc on INSERT query to [DataClass] table.'
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

		SELECT
			@ApplicationID = [ApplicationID],
			@ApplicationName = [ApplicationName],
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		SELECT
			@SourceID_Financials = S.[SourceID],
			@SourceTypeID = S.[SourceTypeID]
		FROM
			[Source] S
			INNER JOIN [Model] M ON M.ModelID = S.ModelID
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SourceName] = 'Financials'

/*
	SET @Step = 'Check if demo'
		IF @DemoYN = 0
			BEGIN
				SET @Message = 'This SP can only be used for demo purposes'
				SET @Severity = 16
				GOTO EXITPOINT
			END
*/
	
	SET @Step = 'Copy Entity structure from pcETL to pcINTEGRATOR_Data'
		SET @SQLStatement = '
			INSERT INTO pcINTEGRATOR_Data..Entity
				(
				InstanceID,
				VersionID,
				MemberKey,
				EntityName,
				SelectYN
				)
			SELECT
				InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ',
				MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE E.Entity END,
				EntityName = MAX(E.EntityName),
				SelectYN = MAX(CONVERT(int, E.SelectYN))
			FROM
				[' + @ETLDatabase + '].[dbo].Entity E
				INNER JOIN pcINTEGRATOR..[Source] S ON S.SourceID = E.SourceID
				INNER JOIN pcINTEGRATOR..[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
			WHERE
				NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Entity pcIE WHERE pcIE.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND pcIE.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND pcIE.MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE E.Entity END)
			GROUP BY
				CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE E.Entity END'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity', * FROM pcINTEGRATOR_Data..Entity WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Entity_Book'
		SELECT @MaxID = MAX([Entity_FiscalYearID]) FROM [pcINTEGRATOR_Data].[dbo].[Entity_FiscalYear]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Entity_FiscalYear], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''		
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			INSERT INTO pcINTEGRATOR_Data.[dbo].[Entity_Book]
				(
				[InstanceID],
				[VersionID],
				[EntityID],
				[Book],
				[Currency],
				[BookTypeBM],
				SelectYN
				)
			SELECT DISTINCT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[EntityID] = pcIE.[EntityID],
				[Book] = CASE WHEN ST.SourceTypeFamilyID IN (1) AND BM.ModelID = -7 THEN E.Par02 ELSE CASE WHEN BM.ModelID = -7 THEN ''GL'' ELSE BM.ModelName END END,
				[Currency] = E.[Currency],
				[BookTypeBM] = CASE BM.ModelID WHEN -7 THEN 1 WHEN -3 THEN 4 ELSE 8 END + CASE WHEN BM.ModelID = -7 AND ((ST.SourceTypeFamilyID IN (1) AND E.Par02 = ''MAIN'') OR ST.SourceTypeFamilyID NOT IN (1)) THEN 2 ELSE 0 END,
				SelectYN = E.SelectYN
			FROM
				[' + @ETLDatabase + '].[dbo].[Entity] E
				INNER JOIN pcINTEGRATOR..[Source] S ON S.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND S.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND S.SourceID = E.SourceID
				INNER JOIN pcINTEGRATOR..[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
				INNER JOIN pcINTEGRATOR..Entity pcIE ON pcIE.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND pcIE.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND pcIE.MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE E.Entity END
				INNER JOIN pcINTEGRATOR..Model M ON M.ModelID = S.ModelID
				INNER JOIN pcINTEGRATOR..Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & 68 > 0
			WHERE
				NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Entity_Book EB WHERE EB.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND EB.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND EB.EntityID = pcIE.EntityID AND EB.Book = CASE WHEN ST.SourceTypeFamilyID IN (1) AND BM.ModelID = -7 THEN E.Par02 ELSE CASE WHEN BM.ModelID = -7 THEN ''GL'' ELSE BM.ModelName END END)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity_Book', * FROM pcINTEGRATOR_Data..Entity_Book WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Copy from Callisto to v2, Dimension'
		SELECT @MaxID = MAX(DimensionID) FROM [pcINTEGRATOR_Data].[dbo].[Dimension]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Dimension], RESEED, ' + CONVERT(nvarchar, @MaxID) + ')'''		
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
				(
				[InstanceID],
				[DimensionName],
				[DimensionDescription],
				[DimensionTypeID],
				[GenericYN],
				[MultipleProcedureYN],
				[AllYN],
				[HiddenMember],
				[Hierarchy],
				[TranslationYN],
				[DefaultSelectYN],
				[DefaultValue],
				[DeleteJoinYN],
				[SourceTypeBM],
				[MasterDimensionID],
				[HierarchyMasterDimensionID],
				[InheritedFrom],
				[SeedMemberID],
				[ModelingStatusID],
				[ModelingComment],
				[Introduced],
				[SelectYN]
				)
			SELECT DISTINCT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[DimensionName] = DD.Label,
				[DimensionDescription] = DD.[Description],
				[DimensionTypeID] = ISNULL(DT.DimensionTypeID, 0),
				[GenericYN] = 1,
				[MultipleProcedureYN] = 0,
				[AllYN] = 1,
				[HiddenMember] = ''All'',
				[Hierarchy] = NULL,
				[TranslationYN] = 1,
				[DefaultSelectYN] = 1,
				[DefaultValue] = NULL,
				[DeleteJoinYN] = 0,
				[SourceTypeBM] = 65535,
				[MasterDimensionID] = NULL,
				[HierarchyMasterDimensionID] = NULL,
				[InheritedFrom] = NULL,
				[SeedMemberID] = 1001,
				[ModelingStatusID] = ' + CONVERT(nvarchar(10), @ModelingStatusID) + ',
				[ModelingComment] = ''' + @ModelingComment + ''',
				[Introduced] = ''' + @Version + ''',
				[SelectYN] = 1
			FROM
				' + @ETLDatabase + '.[dbo].[XT_DimensionDefinition] DD
				LEFT JOIN [DimensionType] DT ON DT.InstanceID IN (0, ' + CONVERT(nvarchar(10), @InstanceID) + ') AND DT.[DimensionTypeName] = DD.[Type]
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[Dimension] D WHERE D.InstanceID IN (0, ' + CONVERT(nvarchar(10), @InstanceID) + ') AND D.[DimensionName] = DD.Label)
			ORDER BY
				DD.Label'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Dimension', * FROM pcINTEGRATOR_Data..Dimension WHERE InstanceID = @InstanceID 

	SET @Step = 'Update Entity structure'
		EXEC [spPortalAdminSet_SegmentDimension] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID

	SET @Step = 'Fill Journal_SegmentNo'

	IF @Debug <> 0
		SELECT
			[@JobID] = @JobID,
			[@ProcedureID] = @ProcedureID,
			[@VersionID] = @VersionID,
			[@InstanceID] = @InstanceID,
			[@ETLDatabase] = @ETLDatabase,
			[@SourceID_Financials] = @SourceID_Financials

		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
				(
				[JobID],
				[VersionID],
				[InstanceID],
				[EntityID],
				[Entity],
				[Book],
				[SegmentCode],
				[SourceCode],
				[SegmentNo],
				[SegmentName],
				[DimensionID],
				[MaskPosition],
				[MaskCharacters],
				[SelectYN]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[EntityID] = E.EntityID,
				[Entity] = E.MemberKey,
				[Book] = EB.Book,
				[SegmentCode] = FS.[SegmentName],
				[SourceCode] = FS.[SegmentCode],
				[SegmentNo] = CASE WHEN DimensionTypeID = 1 THEN 0 ELSE -1 END,
				[SegmentName] = CASE WHEN DimensionTypeID = 1 THEN ''Account'' ELSE ''GL_'' + REPLACE(REPLACE(FS.[SegmentName], '' '', ''_''), ''GL_'', '''') END,
				[DimensionID] = CASE WHEN DimensionTypeID = 1 THEN -1 ELSE NULL END,
				[MaskPosition] = NULL,
				[MaskCharacters] = NULL,
				[SelectYN] = 1
			FROM
				[Entity_Book] EB
				INNER JOIN [Entity] E ON E.InstanceID = EB.InstanceID AND E.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND E.EntityID = EB.EntityID
				INNER JOIN ' + @ETLDatabase + '..[FinancialSegment] FS ON FS.SourceID = ' + CONVERT(nvarchar(10), @SourceID_Financials) + ' AND FS.[EntityCode] = E.MemberKey --+ ''_'' + EB.Book
			WHERE
				EB.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				EB.BookTypeBM & 3 > 0
				AND NOT EXISTS (SELECT 1 FROM [Journal_SegmentNo] JSN WHERE JSN.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND JSN.[EntityID] = E.EntityID AND JSN.[Book] = EB.Book AND JSN.[SegmentCode] = FS.[SegmentName])'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR..Journal_SegmentNo', JSN.* FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.EntityID = JSN.EntityID AND EB.Book = JSN.Book INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.EntityID = EB.EntityID WHERE E.InstanceID = @InstanceID AND E.VersionID = @VersionID

	SET @Step = 'Insert Groups into table User'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
			(
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserNameDisplay],
			[UserTypeID],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserName] = @ApplicationName + ' - AdminGroup',
			[UserNameAD] = NULL,
			[UserNameDisplay] = @ApplicationName + ' - Admin Group',
			[UserTypeID] = -2, --Group
			[UserLicenseTypeID] = 1 --AdminUser
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - AdminGroup')

		SELECT	@Inserted = @Inserted + @@ROWCOUNT

		SELECT @AdminGroupID = ISNULL(@AdminGroupID, U.UserID) FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - AdminGroup'

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
			(
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserNameDisplay],
			[UserTypeID],
			[UserLicenseTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserName] = @ApplicationName + ' - FullAccessGroup',
			[UserNameAD] = NULL,
			[UserNameDisplay] = @ApplicationName + ' - Full Access Group',
			[UserTypeID] = -2, --Group
			[UserLicenseTypeID] = 1 --Licensed
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - FullAccessGroup')

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		SELECT @FullAccessGroupID = ISNULL(@FullAccessGroupID, U.UserID) FROM [User] U WHERE U.[InstanceID] = @InstanceID AND U.[UserName] = @ApplicationName + ' - FullAccessGroup'

	SET @Step = 'Create User'
		IF @Debug <> 0 SELECT UserID = @UserID
		IF @UserID = -100
			BEGIN
				IF @DemoYN = 0
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
							(
							[InstanceID],
							[UserName],
							[UserNameAD],
							[UserNameDisplay],
							[UserTypeID],
							[UserLicenseTypeID],
							[LocaleID],
							[LanguageID],
							[ObjectGuiBehaviorBM]
							)
						SELECT
							[InstanceID] = @InstanceID,
							[UserName] = @Email,
							[UserNameAD] = @UserNameAD,
							[UserNameDisplay] = @UserNameDisplay,
							[UserTypeID] = -1,
							[UserLicenseTypeID] = 1,
							[LocaleID] = @LocaleID,
							[LanguageID] = 1,
							[ObjectGuiBehaviorBM] = 3
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.InstanceID = @InstanceID AND U.[UserName] = @Email)

						SET @UserID = @@IDENTITY

						IF @UserID <> (SELECT MAX(UserID) FROM [User])
							SELECT @UserID = MAX(UserID) FROM [User] 

						IF @Debug <> 0 SELECT UserID = @UserID

						IF @UserID = -100 SELECT @UserID = UserID FROM [User] U WHERE U.InstanceID = @InstanceID AND U.[UserName] = @Email
					END
				ELSE
					BEGIN
						SELECT @UserID = MIN(UserID) - 1 FROM [User] WHERE UserID < -1000
						SET @UserID = ISNULL(@UserID, -1001)

						SET IDENTITY_INSERT [User] ON
		
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
							(
							[InstanceID],
							[UserID],
							[UserName],
							[UserNameAD],
							[UserNameDisplay],
							[UserTypeID],
							[UserLicenseTypeID],
							[LocaleID],
							[LanguageID],
							[ObjectGuiBehaviorBM]
							)
						SELECT
							[InstanceID] = @InstanceID,
							[UserID] = @UserID,
							[UserName] = @Email,
							[UserNameAD] = @UserNameAD,
							[UserNameDisplay] = @UserNameDisplay,
							[UserTypeID] = -1,
							[UserLicenseTypeID] = 1,
							[LocaleID] = @LocaleID,
							[LanguageID] = 1,
							[ObjectGuiBehaviorBM] = 3

						SET @Inserted = @Inserted + @@ROWCOUNT
		
						SET IDENTITY_INSERT [User] OFF
					END
			END

		--Add email later

	SET @Step = 'Create AdminUser'
		IF @Debug <> 0 
			SELECT 
				UserID = @UserID,
				AdminGroupID = @AdminGroupID,
				FullAccessGroupID = @FullAccessGroupID

		SET @AdminUserID = @UserID

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
			(
			[InstanceID],
			[UserID_Group],
			[UserID_User]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserID_Group] = @AdminGroupID,
			[UserID_User] = @AdminUserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserMember] UM WHERE UM.[UserID_Group] = @AdminGroupID AND UM.[UserID_User] = @AdminUserID)

		SET @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
			(
			[InstanceID],
			[UserID_Group],
			[UserID_User]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[UserID_Group] = @FullAccessGroupID,
			[UserID_User] = @AdminUserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserMember] UM WHERE UM.[UserID_Group] = @FullAccessGroupID AND UM.[UserID_User] = @AdminUserID)

		SET @Inserted = @Inserted + @@ROWCOUNT
	
	SET @Step = 'Insert into SecurityRoleUser'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
			(
			[InstanceID],
			[SecurityRoleID],
			[UserID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @AdminRoleID,
			[UserID] = @AdminUserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU WHERE SRU.InstanceID = @InstanceID AND SRU.[SecurityRoleID] = @AdminRoleID AND SRU.[UserID] = @AdminUserID)

	SET @Step = 'Insert into SecurityRoleUser'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
			(
			[InstanceID],
			[SecurityRoleID],
			[UserID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @AdminRoleID,
			[UserID] = @AdminGroupID
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU WHERE SRU.InstanceID = @InstanceID AND SRU.[SecurityRoleID] = @AdminRoleID AND SRU.[UserID] = @AdminGroupID)

		SET @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
			(
			[InstanceID],
			[SecurityRoleID],
			[UserID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
			[UserID] = @FullAccessGroupID
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU WHERE SRU.InstanceID = @InstanceID AND SRU.[SecurityRoleID] = @FullAccessRoleID AND SRU.[UserID] = @FullAccessGroupID)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Object'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM] = 60
		FROM
			[Object] S
		WHERE
			S.[InstanceID] = 0 AND
			S.[ObjectID] = -1 AND --pcPortal
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = S.ObjectName AND O.[ObjectTypeBM] & S.ObjectTypeBM > 0)

		SELECT
			@ObjectID_pcPortal = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT @ObjectID_pcPortal = ISNULL(@ObjectID_pcPortal, O.ObjectID)
		FROM [Object] O INNER JOIN [Object] S ON S.[InstanceID] = 0 AND S.ObjectID = -1 AND S.[ObjectName] = O.ObjectName AND S.[ObjectTypeBM] & O.ObjectTypeBM > 0
		WHERE O.[InstanceID] = @InstanceID

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID] = @ObjectID_pcPortal,
			[SecurityLevelBM] = 60
		FROM
			[Object] S
		WHERE
			S.[InstanceID] = 0 AND
			S.[ObjectID] = -2 AND --Callisto
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = S.ObjectName AND O.[ObjectTypeBM] & S.ObjectTypeBM > 0)

		SELECT
			@ObjectID_Callisto = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT 
			@ObjectID_Callisto = ISNULL(@ObjectID_Callisto, O.ObjectID)
		FROM 
			[Object] O 
			INNER JOIN [Object] S ON S.[InstanceID] = 0 AND S.ObjectID = -2 AND S.[ObjectName] = O.ObjectName AND S.[ObjectTypeBM] & O.ObjectTypeBM > 0
		WHERE 
			O.[InstanceID] = @InstanceID

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName] = @ApplicationName, 
			[ObjectTypeBM] = 256,  --Application
			[ParentObjectID] = @ObjectID_Callisto,
			[SecurityLevelBM] = 60
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = @ApplicationName AND O.[ObjectTypeBM] & 256 > 0)

		SELECT
			@ObjectID_Application = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT 
			@ObjectID_Application = ISNULL(@ObjectID_Application, O.ObjectID)
		FROM 
			[Object] O 
		WHERE 
			O.[InstanceID] = @InstanceID AND O.[ObjectName] = @ApplicationName AND O.[ObjectTypeBM] & 256 > 0

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName] = M.ModelName, 
			[ObjectTypeBM] = 1,  --Model
			[ParentObjectID] = @ObjectID_Application,
			[SecurityLevelBM] = 60
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
		WHERE
			A.InstanceID = @InstanceID AND
			A.ApplicationName = @ApplicationName AND
			A.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = M.ModelName AND O.[ObjectTypeBM] & 1 > 0)

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName] = 'Scenario', 
			[ObjectTypeBM] = 2,  --Scenario / Application / Read
			[ParentObjectID] = @ObjectID_Application,
			[SecurityLevelBM] = 32
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = 'Scenario' AND O.[ObjectTypeBM] & 2 > 0)

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
			(
			[InstanceID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[ObjectName] = 'Scenario', 
			[ObjectTypeBM] = 2,  --Scenario / Model / Write
			[ParentObjectID] = S.ObjectID,
			[SecurityLevelBM] = 16
		FROM
			[Object] S
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[ObjectTypeBM] & 1 > 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = 'Scenario' AND O.[ObjectTypeBM] & 2 > 0 AND O.[ParentObjectID] = S.ObjectID)

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into SecurityRoleObject'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @AdminRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 60
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 448 > 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO WHERE SRO.[InstanceID] = @InstanceID AND SRO.[SecurityRoleID] = @AdminRoleID AND SRO.[ObjectID] = O.[ObjectID])

	SET @Step = 'Insert into SecurityRoleObject (Features)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
		FROM
			[pcINTEGRATOR].[dbo].[@Template_SecurityRoleObject] TEMP
		WHERE
			TEMP.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.InstanceID = @InstanceID AND SRO.[SecurityRoleID] = TEMP.SecurityRoleID AND SRO.[ObjectID] = TEMP.ObjectID)

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 40
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 449 > 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO WHERE SRO.[InstanceID] = @InstanceID AND SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 32
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 3 > 0 AND
			O.ParentObjectID = @ObjectID_Application AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO WHERE SRO.[InstanceID] = @InstanceID AND SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 16
		FROM
			[Object] O
		WHERE
			O.InstanceID = @InstanceID AND
			O.ObjectTypeBM & 2 > 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO WHERE SRO.[InstanceID] = @InstanceID AND SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[SecurityRoleID] = @FullAccessRoleID,
			[ObjectID] = O.[ObjectID],
			[SecurityLevelBM] = 1
		FROM
			[Object] O
		WHERE
			O.InstanceID = 0 AND
			O.ObjectTypeBM & 1024 > 0 AND
			O.ObjectID IN (-6, -7) AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO WHERE SRO.[InstanceID] = @InstanceID AND SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Scenario'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Scenario]
			(
			[InstanceID],
			[VersionID],
			[MemberKey],
			[ScenarioTypeID],
			[ScenarioName],
			[ScenarioDescription],
			[ActualOverwriteYN],
			[AutoRefreshYN],
			[InputAllowedYN],
			[AutoSaveOnCloseYN],
			[ClosedMonth],
			[SortOrder],
			[InheritedFrom],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[MemberKey],
			[ScenarioTypeID],
			[ScenarioName],
			[ScenarioDescription],
			[ActualOverwriteYN],
			[AutoRefreshYN],
			[InputAllowedYN],
			[AutoSaveOnCloseYN],
			[ClosedMonth],
			[SortOrder],
			[InheritedFrom] = S.ScenarioID,
			[SelectYN]
		FROM
			[Scenario] S
		WHERE
			[InstanceID] = @SourceInstanceID AND
			[VersionID] = @SourceVersionID AND
			[SelectYN] <> 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Scenario] SD WHERE SD.[InstanceID] = @InstanceID AND SD.[VersionID] = @VersionID AND SD.[MemberKey] = S.[MemberKey])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into Workflow'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow]
			(
			[InstanceID],
			[VersionID],
			[WorkflowName],
			[ProcessID],
			[ScenarioID],
			[CompareScenarioID],
			[TimeFrom],
			[TimeTo],
			[TimeOffsetFrom],
			[TimeOffsetTo],
			[InitialWorkflowStateID],
			[RefreshActualsInitialWorkflowStateID],
			[SpreadingKeyID],
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom],
			[SelectYN],
			[DeletedID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[WorkflowName] = WF.[WorkflowName],
--			[ProcessID] = P.ProcessID,
			[ProcessID] = 0,
			[ScenarioID] = S.ScenarioID,
			[CompareScenarioID] = CS.ScenarioID,
			[TimeFrom] = WF.[TimeFrom],
			[TimeTo] = WF.[TimeTo],
			[TimeOffsetFrom] = WF.[TimeOffsetFrom],
			[TimeOffsetTo] = WF.[TimeOffsetTo],
			[InitialWorkflowStateID] = WF.[InitialWorkflowStateID],
			[RefreshActualsInitialWorkflowStateID] = WF.[RefreshActualsInitialWorkflowStateID],
			[SpreadingKeyID] = WF.[SpreadingKeyID],
			[ModelingStatusID] = WF.[ModelingStatusID],
			[ModelingComment] = WF.[ModelingComment],
			[InheritedFrom] = WF.WorkflowID,
			[SelectYN] = 1,
			[DeletedID] = NULL
		FROM
			Workflow WF
--			INNER JOIN Process P ON P.InstanceID = @InstanceID AND P.VersionID = @VersionID AND P.InheritedFrom = WF.[ProcessID]
			INNER JOIN Scenario S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.InheritedFrom = WF.[ScenarioID]
			INNER JOIN Scenario CS ON CS.InstanceID = @InstanceID AND CS.VersionID = @VersionID AND CS.InheritedFrom = WF.[CompareScenarioID]
		WHERE
			WF.InstanceID = @SourceInstanceID AND
			WF.VersionID = @SourceVersionID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Workflow] WFD WHERE WFD.InstanceID = @InstanceID AND WFD.VersionID = @VersionID AND WFD.ScenarioID = S.[ScenarioID])

	SET @Step = 'Insert into WorkflowState'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowState]
			(
			[InstanceID],
			[WorkflowID],
			[WorkflowStateName],
			[InheritedFrom]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[WorkflowID] = WF.WorkflowID,
			[WorkflowStateName] = WS.[WorkflowStateName],
			[InheritedFrom] = WS.[WorkflowStateId]
		FROM
			[WorkflowState] WS
			INNER JOIN Workflow WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WS.WorkflowID
		WHERE
			WS.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[WorkflowState] WSD WHERE WSD.InstanceID = @InstanceID AND WSD.[WorkflowID] = WF.WorkflowID AND WSD.[WorkflowStateName] = WS.[WorkflowStateName])
		ORDER BY
			WS.[WorkflowStateId] DESC

	SET @Step = 'UPDATE [Workflow].[InitialWorkflowStateID]'
		UPDATE WF
		SET
			[InitialWorkflowStateID] = WS.[WorkflowStateID],
			[RefreshActualsInitialWorkflowStateID] = RAWS.[WorkflowStateID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow] WF
			INNER JOIN WorkflowState WS ON WS.InstanceID = @InstanceID AND WS.InheritedFrom = WF.[InitialWorkflowStateID]
			INNER JOIN WorkflowState RAWS ON RAWS.InstanceID = @InstanceID AND RAWS.InheritedFrom = WF.[RefreshActualsInitialWorkflowStateID]
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID

	SET @Step = 'INSERT INTO [OrganizationHierarchy]'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy]
			(
			[InstanceID],
			[VersionID],
			[OrganizationHierarchyName],
			[LinkedDimensionID],
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom],
			[DeletedID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[OrganizationHierarchyName],
			[LinkedDimensionID] = NULL,
			[ModelingStatusID],
			[ModelingComment],
			[InheritedFrom] = OH.[OrganizationHierarchyID],
			[DeletedID]
		FROM
			[OrganizationHierarchy] OH
		WHERE
			InstanceID = @SourceInstanceID AND
			VersionID = @SourceVersionID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] OHD WHERE OHD.InstanceID = @InstanceID AND OHD.VersionID = @VersionID AND OHD.[OrganizationHierarchyName] = OH.[OrganizationHierarchyName])

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into OrganizationLevel'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationLevel]
			(
			[InstanceID],
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[OrganizationLevelName]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[OrganizationLevelNo] = OL.[OrganizationLevelNo],
			[OrganizationLevelName] = OL.[OrganizationLevelName]
		FROM
			[OrganizationLevel] OL
			INNER JOIN OrganizationHierarchy OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = OL.OrganizationHierarchyID
		WHERE
			OL.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationLevel] OLD WHERE OLD.InstanceID = @InstanceID AND OLD.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND OLD.[OrganizationLevelNo] = OL.[OrganizationLevelNo])

	SET @Step = 'Insert into WorkflowStateChange'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange]
			(
			[InstanceID],
			[WorkflowID],
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[FromWorkflowStateID],
			[ToWorkflowStateID],
			[UserChangeableYN],
			[BRChangeableYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[WorkflowID] = WF.WorkflowID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[OrganizationLevelNo] = WSC.[OrganizationLevelNo],
			[FromWorkflowStateID] = FWS.WorkflowStateID,
			[ToWorkflowStateID] = TWS.WorkflowStateID,
			[UserChangeableYN] = WSC.[UserChangeableYN],
			[BRChangeableYN] = WSC.[BRChangeableYN]
		FROM
			[WorkflowStateChange] WSC
			INNER JOIN Workflow WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WSC.WorkflowID
			INNER JOIN OrganizationHierarchy OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = WSC.OrganizationHierarchyID
			INNER JOIN WorkflowState FWS ON FWS.InstanceID = @InstanceID AND FWS.InheritedFrom = WSC.FromWorkflowStateid
			INNER JOIN WorkflowState TWS ON TWS.InstanceID = @InstanceID AND TWS.InheritedFrom = WSC.ToWorkflowStateid
		WHERE
			WSC.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[WorkflowStateChange] WSCD WHERE WSCD.[InstanceID] = @InstanceID AND WSCD.[WorkflowID] = WF.WorkflowID AND WSCD.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND WSCD.[OrganizationLevelNo] = WSC.[OrganizationLevelNo] AND WSCD.[FromWorkflowStateID] = FWS.WorkflowStateID AND WSCD.[ToWorkflowStateID] = TWS.WorkflowStateID)

	SET @Step = 'Insert into Workflow_OrganizationLevel'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow_OrganizationLevel]
			(
			[InstanceID],
			[WorkflowID],
			[OrganizationLevelNo],
			[LevelInWorkflowYN],
			[ExpectedDate],
			[ActionDescription]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[WorkflowID] = WF.WorkflowID,
			[OrganizationLevelNo] = WOL.[OrganizationLevelNo],
			[LevelInWorkflowYN] = WOL.[LevelInWorkflowYN],
			[ExpectedDate] = WOL.[ExpectedDate],
			[ActionDescription] = WOL.[ActionDescription]
		FROM
			[Workflow_OrganizationLevel] WOL
			INNER JOIN Workflow WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WOL.WorkflowID
		WHERE
			WOL.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Workflow_OrganizationLevel] WOLD WHERE WOLD.[InstanceID] = @InstanceID AND WOLD.[WorkflowID] = WF.WorkflowID AND WOLD.[OrganizationLevelNo] = WOL.[OrganizationLevelNo])

	SET @Step = 'Insert into WorkflowAccessRight'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowAccessRight]
			(
			[InstanceID],
			[WorkflowID],
			[OrganizationHierarchyID],
			[OrganizationLevelNo],
			[WorkflowStateID],
			[SecurityLevelBM]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[WorkflowID] = WF.WorkflowID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[OrganizationLevelNo] = WAR.[OrganizationLevelNo],
			[WorkflowStateID] = WS.[WorkflowStateID],
			[SecurityLevelBM] = WAR.[SecurityLevelBM]
		FROM
			[WorkflowAccessRight] WAR
			INNER JOIN Workflow WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.InheritedFrom = WAR.WorkflowID
			INNER JOIN OrganizationHierarchy OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = WAR.OrganizationHierarchyID
			INNER JOIN WorkflowState WS ON WS.InstanceID = @InstanceID AND WS.InheritedFrom = WAR.WorkflowStateid
		WHERE
			WAR.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[WorkflowAccessRight] WARD WHERE WARD.[InstanceID] = @InstanceID AND WARD.[WorkflowID] = WF.WorkflowID AND WARD.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND WARD.[OrganizationLevelNo] = WAR.[OrganizationLevelNo] AND WARD.[WorkflowStateID] = WS.[WorkflowStateID])

	SET @Step = 'Insert into Workflow_LiveFcstNextFlow'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow]
			(
			[InstanceID],
			[WorkflowID],
			[LiveFcstNextFlowID],
			[WorkflowStateID]
			)
		SELECT
			WS.[InstanceID],
			WS.[WorkflowID],
			[LiveFcstNextFlowID] = CASE WS.InheritedFrom WHEN -120 THEN 1 WHEN -121 THEN 2 WHEN -125 THEN 3 END,
			WS.[WorkflowStateID]
		FROM
			WorkflowState WS
		WHERE
			WS.InstanceID = @InstanceID AND
			WS.InheritedFrom IN (-120, -121, -125) AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Workflow_LiveFcstNextFlow] WLFNC WHERE WLFNC.WorkflowID = WS.WorkflowID AND WLFNC.[LiveFcstNextFlowID] = CASE WS.InheritedFrom WHEN -120 THEN 1 WHEN -121 THEN 2 WHEN -125 THEN 3 END)

	SET @Step = 'Only for @DemoYN = 1 and SourceDB = DSPSOURCE01.ERP10. Insert into WorkflowRow and Demodata'
		IF @DemoYN <> 0 AND 
			(
			SELECT 
				MAX(S.SourceDatabase)
			FROM
				[Source] S
				INNER JOIN Model M ON M.ModelID = S.ModelID AND M.BaseModelID = -7
				INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.InstanceID = @InstanceID AND A.VersionID = @VersionID
			) = 'DSPSOURCE01.ERP10'

			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowRow]
					(
					[InstanceID],
					[WorkflowID],
					[DimensionID],
					[Dimension_MemberKey],
					[CogentYN]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[WorkflowID] = WF.[WorkflowID],
					[DimensionID] = WFR.[DimensionID],
					[Dimension_MemberKey] = WFR.[Dimension_MemberKey],
					[CogentYN] = WFR.[CogentYN]
				FROM
					[WorkflowRow] WFR
					INNER JOIN [Workflow] WF ON WF.[InstanceID] = @InstanceID AND WF.[VersionID] = @VersionID AND WF.[InheritedFrom] = WFR.[WorkflowID]
				WHERE
					WFR.[InstanceID] = @SourceInstanceID AND
					NOT EXISTS (SELECT 1 FROM [WorkflowRow] WFRD WHERE WFRD.InstanceID = @InstanceID AND WFRD.[WorkflowID] = WF.[WorkflowID] AND WFRD.[DimensionID] = WFR.[DimensionID] AND WFRD.[Dimension_MemberKey] = WFR.[Dimension_MemberKey])

				EXEC [dbo].[spCreate_DemoData] 
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID
			END

	SET @Step = 'Set Initial WorkflowState'

		SET @SQLStatement = '
			SELECT @InternalVariable = COUNT(1)
			FROM 
				' + @CallistoDatabase + '.sys.tables T
				INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.[name] = ''WorkflowState_MemberId''
			WHERE 
				T.[name] = ''FACT_Financials_default_partition'''

		IF @Debug <> 0 PRINT @SQLStatement

		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ReturnVariable OUT

		IF @Debug <> 0 
			SELECT [@ReturnVariable] = @ReturnVariable

		IF @ReturnVariable > 0
			BEGIN
				SET @SQLStatement = '
					UPDATE F
					SET
						[WorkflowState_MemberId] = W.InitialWorkflowStateID
					FROM
						' + @CallistoDatabase + '.[dbo].[FACT_Financials_default_partition] F
						INNER JOIN [Workflow] W ON
									W.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
									W.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND
									W.ScenarioID = F.[Scenario_MemberId] AND
									F.[Time_MemberId] BETWEEN W.[TimeFrom] AND W.[TimeTo]'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Copy from Callisto to v2, Process'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Process]
				(
				[InstanceID],
				[VersionID],
				[ProcessBM],
				[ProcessName],
				[ProcessDescription],
				[ModelingStatusID],
				[ModelingComment],
				[InheritedFrom],
				[SelectYN]
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[ProcessBM] = 0,
				[ProcessName] = Label,
				[ProcessDescription] = Label,
				[ModelingStatusID] = ' + CONVERT(nvarchar(10), @ModelingStatusID) + ',
				[ModelingComment] = ''' + @ModelingComment + ''',
				[InheritedFrom] = P.ProcessID,
				[SelectYN] = 1
			FROM
				' + @ETLDatabase + '.[dbo].[XT_ModelDefinition] MD
				INNER JOIN Process P ON P.InstanceID = ' + CONVERT(nvarchar(10), @SourceInstanceID) + ' AND P.VersionID = ' + CONVERT(nvarchar(10), @SourceVersionID) + ' AND P.[ProcessName] = MD.Label
			WHERE
				NOT EXISTS (SELECT 1 FROM pcINTEGRATOR.[dbo].[Process] PD WHERE PD.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND PD.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND PD.[ProcessName] = MD.Label)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'UPDATE ProcessID in Workflow'
		UPDATE WF
		SET
			[ProcessID] = P.ProcessID
		FROM
			[pcINTEGRATOR_Data].[dbo].Workflow WF
			INNER JOIN Process P ON P.InstanceID = @InstanceID AND P.VersionID = @VersionID AND P.InheritedFrom = -108
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID

	SET @Step = 'INSERT INTO OrganizationHierarchy_Process'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process]
			(
			[InstanceID],
			[OrganizationHierarchyID],
			[ProcessID]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[ProcessID] = P.ProcessID
		FROM
			[Process] P
			INNER JOIN [OrganizationHierarchy] OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = -130
		WHERE
			P.InstanceID = @InstanceID AND 
			P.VersionID = @VersionID AND
			P.InheritedFrom = -108 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process] OHP WHERE OHP.[InstanceID] = @InstanceID AND OHP.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND OHP.[ProcessID] = P.ProcessID)

	SET @Step = 'Copy from Callisto to v2, DataClass'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass]
				(
				[InstanceID],
				[VersionID],
				[DataClassName],
				[DataClassDescription],
				[DataClassTypeID],
				[ModelBM],
				[StorageTypeBM],
				--[GetProc],
				--[SetProc],
				[ActualDataClassID],
				[ModelingStatusID],
				[ModelingComment],
				[InheritedFrom],
				[SelectYN]
				)
			SELECT DISTINCT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[DataClassName] = MD.Label,
				[DataClassDescription] = MD.Label,
				[DataClassTypeID] = -1,
				[ModelBM] = M.ModelBM,
				[StorageTypeBM] = 4,
				--[GetProc] = NULL,
				--[SetProc] = NULL,
				[ActualDataClassID] = NULL,
				[ModelingStatusID] = ' + CONVERT(nvarchar(10), @ModelingStatusID) + ',
				[ModelingComment] = ''' + @ModelingComment + ''',
				[InheritedFrom] = DC.DataClassID,
				[SelectYN] = 1
			FROM
				' + @ETLDatabase + '.[dbo].[XT_ModelDefinition] MD
				INNER JOIN DataClass DC ON DC.InstanceID = ' + CONVERT(nvarchar(10), @SourceInstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(10), @SourceVersionID) + ' AND DC.[DataClassName] = MD.Label
				LEFT JOIN Model M ON M.ModelID BETWEEN -1 AND -1000 AND M.ModelName = MD.Label
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass] DC WHERE DC.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND DC.[DataClassName] = MD.Label)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Insert into Grid'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid]
			(
			[InstanceID],
			[GridName],
			[GridDescription],
			[DataClassID],
			[GridSkinID],
			[GetProc],
			[SetProc],
			[InheritedFrom]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[GridName] = G.[GridName],
			[GridDescription] = G.[GridDescription],
			[DataClassID] = DC.DataClassID,
			[GridSkinID],
			[GetProc] = G.[GetProc],
			[SetProc] = G.[SetProc],
			[InheritedFrom] = G.[GridID]
		FROM
			[Grid] G
			INNER JOIN [DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.InheritedFrom = G.DataClassID 
		WHERE
			G.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Grid] GD WHERE GD.InstanceID = @InstanceID AND GD.GridName = G.GridName)

	SET @Step = 'Copy from Callisto to v2, DataClass_Process'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Process]
			(
			[InstanceID],
			[VersionID],
			[DataClassID],
			[ProcessID]
			)
		SELECT
			P.[InstanceID],
			P.[VersionID],
			DC.[DataClassID],
			P.[ProcessID]
		FROM
			[Process] P
			INNER JOIN [DataClass] DC ON DC.InstanceID = P.InstanceID AND DC.VersionID = P.VersionID AND DC.DataClassName = P.ProcessName
		WHERE
			P.InstanceID = @InstanceID AND
			P.VersionID = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Process] DCP WHERE DCP.InstanceID = P.InstanceID AND DCP.VersionID = P.VersionID AND DCP.DataClassID = DC.DataClassID AND DCP.[ProcessID] = P.[ProcessID])

	SET @Step = 'Copy from Callisto to v2, Measure'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Measure]
			(
			[InstanceID],
			[DataClassID],
			[VersionID],
			[MeasureName],
			[MeasureDescription],
			[SourceFormula],
			[ExecutionOrder],
			[MeasureParentID],
			[DataTypeID],
			[FormatString],
			[ValidRangeFrom],
			[ValidRangeTo],
			[Unit],
			[AggregationTypeID],
			[InheritedFrom],
			[SortOrder],
			[ModelingStatusID],
			[ModelingComment],
			[SelectYN]
			)
		SELECT
			[InstanceID] = DC.[InstanceID],
			[DataClassID] = DC.[DataClassID],
			[VersionID] = DC.[VersionID],
			[MeasureName] = DC.DataClassName,
			[MeasureDescription] = 'Unified measure',
			[SourceFormula] = NULL,
			[ExecutionOrder] = 0,
			[MeasureParentID] = NULL,
			[DataTypeID] = -3,
			[FormatString] = '#,##0',
			[ValidRangeFrom] = NULL,
			[ValidRangeTo] = NULL,
			[Unit] = 'Generic',
			[AggregationTypeID] = -1,
			[InheritedFrom] = NULL,
			[SortOrder] = 1,
			[ModelingStatusID] = @ModelingStatusID,
			[ModelingComment] = @ModelingComment,
			[SelectYN] = 1
		FROM
			[DataClass] DC
		WHERE
			DC.[InstanceID] = @InstanceID AND
			DC.[VersionID] = @VersionID AND 
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Measure] M WHERE M.[InstanceID] = DC.[InstanceID] AND M.[DataClassID] = DC.[DataClassID] AND M.[VersionID] = DC.[VersionID] AND M.[MeasureName] = DC.DataClassName)

	SET @Step = 'Copy from Callisto to v2, DataClass_Dimension'
		CREATE TABLE [#DataClass_Dimension]
			(
			[InstanceID] [int] NULL,
			[VersionID] [int] NULL,
			[DataClassID] [int] NULL,
			[DimensionID] [int] NULL,
			[SortOrder] [int] IDENTITY(1010,10) NOT NULL
			)

		SET @SQLStatement = '
			INSERT INTO [#DataClass_Dimension]
				(
				[InstanceID],
				[VersionID],
				[DataClassID],
				[DimensionID]
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[DataClassID] = DC.[DataClassID],
				[DimensionID] = D.[DimensionID]
			FROM
				' + @ETLDatabase + '.[dbo].[XT_ModelDimensions] MD
				INNER JOIN DataClass DC ON DC.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND DC.DataClassName = MD.Model
				INNER JOIN Dimension D ON D.InstanceID IN (0, ' + CONVERT(nvarchar(10), @InstanceID) + ') AND D.DimensionName = MD.Dimension
			ORDER BY
				DC.[DataClassID],
				CASE WHEN D.DimensionTypeID = -1 THEN 2 ELSE 1 END,
				D.DimensionName'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

--		IF @Test = 3
--			BEGIN
--				SELECT * FROM [#DataClass_Dimension]
--				RETURN
--			END

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
			(
			[InstanceID],
			[VersionID],
			[DataClassID],
			[DimensionID],
			[SortOrder]
			)
		SELECT
			[InstanceID],
			[VersionID],
			[DataClassID],
			[DimensionID],
			[SortOrder]
		FROM
			[#DataClass_Dimension] DCD
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] PDCD WHERE PDCD.[InstanceID] = DCD.[InstanceID] AND PDCD.[VersionID] = DCD.[VersionID] AND PDCD.[DataClassID] = DCD.[DataClassID] AND PDCD.[DimensionID] = DCD.[DimensionID])

		DROP TABLE [#DataClass_Dimension]


	SET @Step = 'Copy from Callisto to v2, Dimension_StorageType'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
			(
			[InstanceID],
			[DimensionID],
			[StorageTypeBM]
			)
		SELECT DISTINCT
			[InstanceID],
			[DimensionID],
			[StorageTypeBM] = 4
		FROM
			[DataClass_Dimension] DCD
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID] = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST WHERE DST.[InstanceID] = DCD.[InstanceID] AND DST.[DimensionID] = DCD.[DimensionID])

	SET @Step = 'Copy from Callisto to v2, DimensionHierarchy'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
			(
			[Comment],
			[InstanceID],
			[DimensionID],
			[HierarchyNo],
			[HierarchyName],
			[FixedLevelsYN],
			[LockedYN]
			)
		SELECT DISTINCT
			[Comment] = D.DimensionName,
			[InstanceID] = @InstanceID,
			[DimensionID] = DCD.[DimensionID],
			[HierarchyNo] = 0,
			[HierarchyName] = D.DimensionName,
			[FixedLevelsYN] = 1,
			[LockedYN] = 0
		FROM
			[DataClass_Dimension] DCD
			INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID AND D.[InstanceID] <> 0
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID] = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH WHERE DH.[InstanceID] = DCD.[InstanceID] AND DH.[DimensionID] = DCD.[DimensionID] AND DH.[HierarchyNo] = 0)

	SET @Step = 'Copy from Callisto to v2, DimensionHierarchyLevel'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
			(
			[Comment],
			[InstanceID],
			[DimensionID],
			[HierarchyNo],
			[LevelNo],
			[LevelName]
			)
		SELECT
			sub.[Comment],
			sub.[InstanceID],
			sub.[DimensionID],
			sub.[HierarchyNo],
			sub.[LevelNo],
			sub.[LevelName]
		FROM
			(
			SELECT DISTINCT
				[Comment] = D.DimensionName,
				[InstanceID] = @InstanceID,
				[DimensionID] = DCD.[DimensionID],
				[HierarchyNo] = 0,
				[LevelNo] = 1,
				[LevelName] = 'TopNode'
			FROM
				[DataClass_Dimension] DCD
				INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID AND D.[InstanceID] <> 0
			WHERE
				DCD.[InstanceID] = @InstanceID AND
				DCD.[VersionID] = @VersionID
			UNION SELECT DISTINCT
				[Comment] = D.DimensionName,
				[InstanceID] = @InstanceID,
				[DimensionID] = DCD.[DimensionID],
				[HierarchyNo] = 0,
				[LevelNo] = 2,
				[LevelName] = REPLACE(D.DimensionName, 'GL_', '')
			FROM
				[DataClass_Dimension] DCD
				INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID AND D.[InstanceID] <> 0
			WHERE
				DCD.[InstanceID] = @InstanceID AND
				DCD.[VersionID] = @VersionID
				) sub
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = sub.[InstanceID] AND DHL.[DimensionID] = sub.[DimensionID] AND DHL.[HierarchyNo] = sub.[HierarchyNo] AND DHL.[LevelNo] = sub.[LevelNo])
		ORDER BY
			sub.[InstanceID],
			sub.[DimensionID],
			sub.[HierarchyNo],
			sub.[LevelNo]

	SET @Step = 'Copy data into EntityPropertyValue'	
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue]
				(
				[InstanceID],
				[VersionID],
				[EntityID],
				[EntityPropertyTypeID],
				[EntityPropertyValue],
				[SelectYN]
				)
			SELECT 
				[InstanceID] = PCIE.InstanceID,
				[VersionID] = PCIE.VersionID,
				[EntityID] = PCIE.EntityID,
				[EntityPropertyTypeID] = -2,
				[EntityPropertyValue] = CONVERT(nvarchar(10), PCIS.SourceTypeID),
				[SelectYN] = ETLE.SelectYN
			FROM
				' + @ETLDatabase + '.[dbo].[Entity] ETLE
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] PCIE ON PCIE.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND PCIE.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND PCIE.MemberKey = ETLE.Entity
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Source] PCIS ON PCIS.InstanceID = PCIE.InstanceID AND PCIS.VersionID = PCIE.VersionID AND PCIS.SourceID = ETLE.SourceID
			WHERE
				ETLE.SourceID = ' + CONVERT(nvarchar(10), @SourceID_Financials)
						
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
				
		SET @Inserted = @Inserted + @@ROWCOUNT
		
		IF @SourceTypeID = 12 --Valid for ENTERPRISE ONLY
			BEGIN
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue]
						(
						[InstanceID],
						[VersionID],
						[EntityID],
						[EntityPropertyTypeID],
						[EntityPropertyValue],
						[SelectYN]
						)
					SELECT 
						[InstanceID] = PCIE.InstanceID,
						[VersionID] = PCIE.VersionID,
						[EntityID] = PCIE.EntityID,
						[EntityPropertyTypeID] = -1,
						[EntityPropertyValue] = ETLE.Par01,
						[SelectYN] = ETLE.SelectYN
					FROM
						' + @ETLDatabase + '.[dbo].[Entity] ETLE
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] PCIE ON PCIE.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND PCIE.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND PCIE.MemberKey = ETLE.Entity
					WHERE
						ETLE.SourceID = ' + CONVERT(nvarchar(10), @SourceID_Financials)				
						
				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..EntityPropertyValue', * FROM pcINTEGRATOR_Data..EntityPropertyValue WHERE InstanceID = @InstanceID AND VersionID = @VersionID

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
