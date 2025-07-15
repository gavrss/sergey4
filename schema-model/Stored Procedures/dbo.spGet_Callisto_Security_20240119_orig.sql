SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create PROCEDURE [dbo].[spGet_Callisto_Security_20240119_orig]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DimensionYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000577,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spGet_Callisto_Security] @UserID=-10, @InstanceID=572, @VersionID=1080,  @DimensionYN=1, @DebugBM=15 --BRAD1

EXEC [spGet_Callisto_Security] @UserID=-10, @InstanceID=454, @VersionID=1021, @DimensionYN=1, @Debug=1 --CCM
EXEC [spGet_Callisto_Security] @UserID='3691', @InstanceID='424', @VersionID='1017', @Debug=1 --HD

EXEC [spGet_Callisto_Security] @UserID=-2060, @InstanceID=-1309, @VersionID=-1247, @Debug=1 --TT116
EXEC [spGet_Callisto_Security] @UserID=-10, @InstanceID=-1345, @VersionID=-1345, @Debug=1 --MTS05

EXEC [spGet_Callisto_Security] @UserID=-10, @InstanceID=454, @VersionID=1021, @Debug=1 --CCM

EXEC [spGet_Callisto_Security] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@OrganizationPositionID INT,
	@RowCounter INT,
	@RoleID INT,
	@ApplicationName NVARCHAR(100),
	@CallistoDatabase NVARCHAR(100),
	@SQLStatement NVARCHAR(MAX),

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2194'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get security details for Callisto',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2157' SET @Description = 'Removed drop of temp table #User.'
		IF @Version = '2.1.0.2161' SET @Description = 'Handle write access.'
		IF @Version = '2.1.1.2171' SET @Description = 'Remove all data access to the role All Users.'
		IF @Version = '2.1.2.2182' SET @Description = 'Changed all references of Callisto [Model] from [pcINTEGRATOR]..[Process] to [pcINTEGRATOR]..[DataClass].'
		IF @Version = '2.1.2.2191' SET @Description = 'Added @Step = Update #RoleMemberRow for OrganizationPosition Dimension ReadAccess from other AssignmentSource.'
		IF @Version = '2.1.2.2194' SET @Description = 'Added InstanceID filter when JOINing to [SecurityRoleUser] for [#SecurityUser] INSERT queries.'

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

		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ApplicationName = [ApplicationName],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[pcIntegrator_Data].[dbo].[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		IF @DebugBM & 2 > 0
			SELECT
				[@ApplicationName] = @ApplicationName,
				[@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'Create temp tables'
		IF OBJECT_ID (N'tempdb..#User', N'U') IS NULL
			CREATE TABLE #User
				(
				[InstanceID] [INT],
				[UserID] [INT],
				[UserName] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
				[UserNameAD] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
				[AzureUPN] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
				[UserNameDisplay] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
				[UserTypeID] [INT],
				[UserLicenseTypeID] [INT],
				[LocaleID] [INT],
				[LanguageID] [INT],
				[ObjectGuiBehaviorBM] [INT],
				[InheritedFrom] [INT] NULL,
				[SelectYN] [BIT] NOT NULL,
				[Version] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
				[DeletedID] [INT]
				)

		CREATE TABLE #RoleMemberRow
			(
			[RoleID] INT,
			[DataClassID] INT,
			[DimensionID] INT,
			[HierarchyNo] INT,
			[MemberKey] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[WriteAccessYN] BIT
			)

		CREATE TABLE #RoleOrganizationPosition
			(
			[RoleID] INT,
			[OrganizationPositionID] INT
			)

		CREATE TABLE #Object
			(
			[InstanceID] INT,
			[ObjectID] INT,
			[ObjectName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[ObjectTypeBM] INT,
			[ParentObjectID] INT,
			[SecurityLevelBM] INT,
			[InheritedFrom] INT,
			[SortOrder] NVARCHAR(1000) COLLATE DATABASE_DEFAULT,
			[Level] INT,
			[SelectYN] BIT,
			[Version] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[Children] INT
			)

		CREATE TABLE #OPDimReadAccess
			(
			[OrganizationPositionID] INT,
			[DimensionID] INT,
			[DimensionName] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[HierarchyNo] INT,
			[HierarchyName] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[MemberKey] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[ReadAccessYN] BIT,
			[WriteAccessYN] BIT,
			[InheritedYN] BIT,
			[Comment] NVARCHAR(100) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #OPDataClassReadAccess
			(
			[OrganizationPositionID] INT,
			[DataClassID] INT,
			[DataClassName] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[WriteAccessYN] BIT
			)

	SET @Step = 'Exec spGet_SecurityRoles_Dynamic'
		EXEC [pcINTEGRATOR].[dbo].[spGet_SecurityRoles_Dynamic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID

		IF @DebugBM & 2 > 0
			BEGIN
				SELECT TempTable = '#User', * FROM #User ORDER BY UserNameAD
				SELECT TempTable = '#RoleMemberRow', * FROM #RoleMemberRow
				SELECT TempTable = '#RoleOrganizationPosition', * FROM #RoleOrganizationPosition ORDER BY RoleID, OrganizationPositionID
			END

	SET @Step = 'Update #RoleMemberRow for OrganizationPosition Dimension ReadAccess from other AssignmentSource'
		INSERT INTO #OPDataClassReadAccess
			(
			[OrganizationPositionID],
			[DataClassID],
			[DataClassName],
			[WriteAccessYN]
			)
		SELECT
			sub.[OrganizationPositionID],
			sub.[DataClassID],
			sub.[DataClassName],
			sub.[WriteAccessYN]
		FROM
			(
			SELECT
				OrganizationPositionID = OP.OrganizationPositionID,
				DataClassID = DC.DataClassID,
				DataClassName = DC.DataClassName,
				WriteAccessYN = 0
			FROM
				[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.InstanceID = OP.InstanceID AND DC.VersionID = OP.VersionID AND DC.SelectYN <> 0
			WHERE
				OP.InstanceID = @InstanceID AND
				OP.VersionID = @VersionID AND
				OP.DeletedID IS NULL AND
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DataClass] OPDC WHERE OPDC.InstanceID = OP.InstanceID AND OPDC.VersionID = OP.VersionID AND OPDC.DataClassID = DC.DataClassID AND OPDC.OrganizationPositionID = OP.OrganizationPositionID)
			UNION
			SELECT
				OrganizationPositionID = OPDC.OrganizationPositionID,
				DataClassID = OPDC.DataClassID,
				DataClassName = DC.DataClassName,
				WriteAccessYN = OPDC.WriteAccessYN
			FROM
				[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DataClass] OPDC
				INNER JOIN [pcINTEGRATOR_Data].[dbo].DataClass DC ON DC.DataClassID = OPDC.DataClassID AND DC.SelectYN <> 0
			WHERE
				OPDC.InstanceID = @InstanceID AND
				OPDC.VersionID = @VersionID
			) sub
		ORDER BY sub.OrganizationPositionID, sub.DataClassID

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#OPDataClassReadAccess', * FROM #OPDataClassReadAccess

		IF CURSOR_STATUS('global','RoleOP_Cursor') >= -1 DEALLOCATE RoleOP_Cursor
		DECLARE RoleOP_Cursor CURSOR FOR
			
			SELECT 
				[RoleID],
				[OrganizationPositionID]
			FROM	
				#RoleOrganizationPosition

			OPEN RoleOP_Cursor
			FETCH NEXT FROM RoleOP_Cursor INTO @RoleID, @OrganizationPositionID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@RoleID] = @RoleID, [@OrganizationPositionID] = @OrganizationPositionID
					TRUNCATE TABLE #OPDimReadAccess	

					EXEC [pcINTEGRATOR].[dbo].[spPortalAdminGet_OrganizationPosition] @UserID=@UserID,@InstanceID=@InstanceID,@VersionID=@VersionID,@OrganizationPositionID=@OrganizationPositionID,@ResultTypeBM=8,@GetResultSetYN=0

					IF @DebugBM & 2 > 0 
						BEGIN
							SELECT [TempTable] = '#OPDimReadAccess', * FROM #OPDimReadAccess						
							SELECT [TempTable] = '#RoleMemberRow_before', * FROM #RoleMemberRow WHERE RoleID = @RoleID
						END

					INSERT INTO #RoleMemberRow
						(
						[RoleID],
						[DataClassID],
						[DimensionID],
						[HierarchyNo],
						[MemberKey],
						[WriteAccessYN]
						)
					SELECT
						[RoleID] = @RoleID,
						OPDC.[DataClassID],
						OPD.[DimensionID],
						OPD.[HierarchyNo],
						OPD.[MemberKey],
						OPD.[WriteAccessYN]
					FROM
						#OPDimReadAccess OPD
						INNER JOIN #OPDataClassReadAccess OPDC ON OPDC.OrganizationPositionID = OPD.OrganizationPositionID
						INNER JOIN [pcIntegrator_Data].[dbo].[DataClass_Dimension] DCD ON DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DataClassID = OPDC.DataClassID AND DCD.DimensionID = OPD.DimensionID AND DCD.SelectYN <> 0
					WHERE
						OPD.OrganizationPositionID = @OrganizationPositionID AND
						NOT EXISTS (SELECT 1 FROM #RoleMemberRow RMR WHERE RMR.RoleID = @RoleID AND RMR.DataClassID = OPDC.DataClassID AND RMR.DimensionID = OPD.DimensionID AND RMR.HierarchyNo = OPD.HierarchyNo AND RMR.MemberKey = OPD.MemberKey)

					IF @DebugBM & 2 > 0 SELECT [TempTable] = '#RoleMemberRow_after', * FROM #RoleMemberRow WHERE RoleID = @RoleID

					FETCH NEXT FROM RoleOP_Cursor INTO @RoleID, @OrganizationPositionID
				END

		CLOSE RoleOP_Cursor
		DEALLOCATE RoleOP_Cursor

	SET @Step = 'Check existence of temp tables for Dimension'
		IF @DimensionYN <> 0
			BEGIN
				IF OBJECT_ID (N'tempdb..#DimensionDefinition', N'U') IS NULL
					CREATE TABLE [#DimensionDefinition]
						(
						[Action] [INT] NULL,
						[Label] [NVARCHAR](100) NOT NULL,
						[Description] [NVARCHAR](255) NULL,
						[Type] [NVARCHAR](50) NOT NULL,
						[Secured] [BIT] NULL,
						[DefaultHierarchy] [NVARCHAR](100) NULL
						)

				INSERT INTO [#DimensionDefinition]
					(
					[Action],
					[Label],
					[Description],
					[Type],
					[Secured],
					[DefaultHierarchy]
					)
				SELECT DISTINCT
					[Action] = NULL,
					[Label] = D.DimensionName,
					[Description] = DimensionDescription,
					[Type] = DT.DimensionTypeName,
					[Secured] = DST.ReadSecurityEnabledYN,
					[DefaultHierarchy] = D.DimensionName + '_' + ISNULL(DHI.HierarchyName, DHD.HierarchyName)
				FROM
					[Dimension] D
					INNER JOIN [DimensionType] DT ON DT.DimensionTypeID = D.DimensionTypeID
					INNER JOIN [DataClass_Dimension] DCD ON DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DimensionID = D.DimensionID
					INNER JOIN [Dimension_StorageType] DST ON DST.InstanceID = DCD.InstanceID AND DST.VersionID = DCD.VersionID AND DST.DimensionID = DCD.DimensionID AND DST.StorageTypeBM & 4 > 0
					LEFT JOIN [DimensionHierarchy] DHI ON DHI.InstanceID = @InstanceID AND DHI.DimensionID = D.DimensionID AND DHI.HierarchyNo = 0
					LEFT JOIN [DimensionHierarchy] DHD ON DHD.InstanceID = D.InstanceID AND DHD.DimensionID = D.DimensionID AND DHD.HierarchyNo = 0
				WHERE
					D.InstanceID IN (0, @InstanceID) AND
					NOT EXISTS (SELECT 1 FROM [#DimensionDefinition] DD WHERE DD.Label = D.DimensionName)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Check existence of temp tables for Users and Security'
		IF OBJECT_ID (N'tempdb..#UserDefinition', N'U') IS NULL
			CREATE TABLE [#UserDefinition]
				(
				[Action] [INT] NULL,
				[WinUser] [NVARCHAR](255) NOT NULL,
				[Active] [INT] NULL,
				[Email] [NVARCHAR](255) NULL,
				[UserId] [INT] NULL
				)

		IF OBJECT_ID (N'tempdb..#SecurityUser', N'U') IS NULL
			CREATE TABLE [#SecurityUser]
				(
				[Role] [NVARCHAR](100) NOT NULL,
				[WinUser] [NVARCHAR](255) NULL,
				[WinGroup] [NVARCHAR](255) NULL
				)

		IF OBJECT_ID (N'tempdb..#SecurityRoleDefinition', N'U') IS NULL
			CREATE TABLE [#SecurityRoleDefinition]
				(
				[Action] [INT] NULL,
				[Label] [NVARCHAR](100) NOT NULL,
				[Description] [NVARCHAR](255) NULL,
				[LicenseUserType] [NVARCHAR](255) NULL,
				[AppLogon] [BIT] NOT NULL DEFAULT (1)
				)

		IF OBJECT_ID (N'tempdb..#SecurityModelRuleAccess', N'U') IS NULL
			CREATE TABLE [#SecurityModelRuleAccess]
				(
				[Role] [NVARCHAR](100) NOT NULL,
				[Model] [NVARCHAR](100) NOT NULL,
				[Rule] [NVARCHAR](255) NOT NULL,
				[AllRules] [INT] NOT NULL
				)

		IF OBJECT_ID (N'tempdb..#SecurityMemberAccess', N'U') IS NULL
			CREATE TABLE [#SecurityMemberAccess]
				(
				[Role] [NVARCHAR](100) NOT NULL,
				[Model] [NVARCHAR](100) NOT NULL,
				[Dimension] [NVARCHAR](100) NOT NULL,
				[Hierarchy] [NVARCHAR](100) NULL,
				[Member] [NVARCHAR](255) NULL,
				[AccessType] [INT] NULL
				)

		IF OBJECT_ID (N'tempdb..#SecurityActionAccess', N'U') IS NULL
			CREATE TABLE [#SecurityActionAccess]
				(
				[Role] [NVARCHAR](100) NOT NULL,
				[Label] [NVARCHAR](100) NOT NULL,
				[HideAction] [INT] NOT NULL
				)

	SET @Step = '[#UserDefinition]'
		INSERT INTO [#UserDefinition]
			(
			[Action],
			[WinUser],
			[Active],
			[Email],
			[UserId]
			)
		SELECT DISTINCT
			[Action] = NULL,
			[WinUser] = U.UserNameAD,
			[Active] = 1,
			[Email] = MAX(ISNULL(UPV.UserPropertyValue, CASE WHEN CHARINDEX('@',U.UserName) > 0 THEN U.UserName ELSE '' END)),
			[UserId] = MAX(U.UserID)
		FROM
			[#User] U
			LEFT JOIN UserPropertyValue UPV ON UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -3
		WHERE
			U.InstanceID = @InstanceID AND
			U.UserNameAD IS NOT NULL AND
			U.UserTypeID = -1 AND
			U.UserLicenseTypeID = 1 AND
			U.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM [#UserDefinition] #UD WHERE #UD.WinUser = U.UserNameAD)
		GROUP BY
			U.UserNameAD
		
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[#SecurityUser]'
--Users member of roles
		INSERT INTO [#SecurityUser]
			(
			[Role],
			[WinUser],
			[WinGroup]
			)
		SELECT DISTINCT
			[Role] = SR.SecurityRoleName,
			[WinUser] = U.UserNameAD,
			[WinGroup] = NULL
		FROM
			[#User] U
			INNER JOIN SecurityRoleUser SRU ON SRU.InstanceID = U.InstanceID AND SRU.UserID = U.UserID AND SRU.SelectYN <> 0
			INNER JOIN SecurityRole SR ON SR.SecurityRoleID = SRU.SecurityRoleID AND SR.SecurityRoleID NOT IN (-3, -10) AND SR.SelectYN <> 0
		WHERE
			U.UserNameAD IS NOT NULL AND
			U.UserTypeID = -1 AND
			U.SelectYN <> 0 AND
			U.DeletedID IS NULL AND
			NOT EXISTS (SELECT 1 FROM [#SecurityUser] #SU WHERE #SU.[Role] = SR.SecurityRoleName AND #SU.WinUser = U.UserNameAD)

		SET @Inserted = @Inserted + @@ROWCOUNT

--Groups member of roles
		INSERT INTO [#SecurityUser]
			(
			[Role],
			[WinUser],
			[WinGroup]
			)
		SELECT DISTINCT
			[Role] = SR.SecurityRoleName,
			[WinUser] = U.UserNameAD,
			[WinGroup] = NULL
		FROM
			[#User] U
			INNER JOIN UserMember UM ON UM.UserID_User = U.UserID AND UM.SelectYN <> 0
			INNER JOIN SecurityRoleUser SRU ON SRU.InstanceID = U.InstanceID AND SRU.UserID = UM.UserID_Group AND SRU.SelectYN <> 0
			INNER JOIN SecurityRole SR ON SR.SecurityRoleID = SRU.SecurityRoleID AND SR.SecurityRoleID NOT IN (-3, -10) AND SR.SelectYN <> 0
		WHERE
			U.UserNameAD IS NOT NULL AND
			U.UserTypeID = -1 AND
			U.SelectYN <> 0 AND
			U.DeletedID IS NULL AND
			NOT EXISTS (SELECT 1 FROM [#SecurityUser] #SU WHERE #SU.[Role] = SR.SecurityRoleName AND #SU.WinUser = U.UserNameAD)

		SET @Inserted = @Inserted + @@ROWCOUNT

--zRoles
		INSERT INTO [#SecurityUser]
			(
			[Role],
			[WinUser],
			[WinGroup]
			)
		SELECT DISTINCT
			[Role] = 'zSecurityRole_' + CASE WHEN ROP.RoleID <= 9 THEN '00' ELSE CASE WHEN ROP.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), ROP.RoleID),
			[WinUser] = U.UserNameAD,
			[WinGroup] = NULL
		FROM
			#RoleOrganizationPosition ROP
			INNER JOIN [OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = ROP.OrganizationPositionID
			INNER JOIN [#User] U ON U.UserID = OPU.UserID AND U.UserNameAD IS NOT NULL
		WHERE
			NOT EXISTS (SELECT 1 FROM [#SecurityUser] #SU WHERE #SU.[Role] = 'zSecurityRole_' + CASE WHEN ROP.RoleID <= 9 THEN '00' ELSE CASE WHEN ROP.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), ROP.RoleID) AND #SU.WinUser = U.UserNameAD)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[#SecurityRoleDefinition]'
		INSERT INTO [#SecurityRoleDefinition]
			(
			[Action],
			[Label],
			[Description],
			[LicenseUserType]
			)
		SELECT DISTINCT
			[Action] = NULL,
			[Label] = SR.SecurityRoleName,
			[Description] = SR.SecurityRoleName,
			[LicenseUserType] = CASE SR.SecurityRoleID WHEN -1 THEN 'Administrator' WHEN -2 THEN 'Unrestricted' ELSE 'Licensed' END 
		FROM
			[SecurityRole] SR
		WHERE
			SR.InstanceID IN (0, @InstanceID) AND
			SR.SelectYN <> 0 AND
			SR.SecurityRoleID NOT IN (-10) AND
			NOT EXISTS (SELECT 1 FROM [#SecurityRoleDefinition] #SRD WHERE #SRD.[Label] = SR.SecurityRoleName)

		SET @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [#SecurityRoleDefinition]
			(
			[Action],
			[Label],
			[Description],
			[LicenseUserType]
			)
		SELECT DISTINCT
			[Action] = NULL,
			[Label] = 'zSecurityRole_' + CASE WHEN ROP.RoleID <= 9 THEN '00' ELSE CASE WHEN ROP.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), ROP.RoleID), 
			[Description] = 'zSecurityRole_' + CASE WHEN ROP.RoleID <= 9 THEN '00' ELSE CASE WHEN ROP.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), ROP.RoleID), 
			[LicenseUserType] = 'Licensed'
		FROM
			#RoleOrganizationPosition ROP
		WHERE
			NOT EXISTS (SELECT 1 FROM [#SecurityRoleDefinition] #SRD WHERE #SRD.[Label] = 'zSecurityRole_' + CASE WHEN ROP.RoleID <= 9 THEN '00' ELSE CASE WHEN ROP.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), ROP.RoleID))

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[#SecurityModelRuleAccess]'
		INSERT INTO [#SecurityModelRuleAccess]
			(
			[Role],
			[Model],
			[Rule],
			[AllRules]
			)
		SELECT DISTINCT
			[Role] = SR.SecurityRoleName,
			[Model] = MO.ObjectName,
			[Rule] = '',
			[AllRules] = 1
		FROM
			[SecurityRole] SR
			INNER JOIN [SecurityRoleObject] SRO ON SRO.SecurityRoleID = SR.SecurityRoleID AND SRO.SelectYN <> 0
			INNER JOIN [Object] O ON O.InstanceID = @InstanceID AND O.ObjectID = SRO.ObjectID AND O.ObjectName = @ApplicationName AND O.ObjectTypeBM & 256 > 0 AND O.SelectYN <> 0
			INNER JOIN [SecurityRoleObject] MSRO ON MSRO.SecurityRoleID = SR.SecurityRoleID AND MSRO.SecurityLevelBM & 8 > 0 AND MSRO.SelectYN <> 0
			INNER JOIN [Object] MO ON MO.ParentObjectID = O.ObjectID AND MO.ObjectID = MSRO.ObjectID AND MO.ObjectTypeBM & 1 > 0 AND MO.SelectYN <> 0 
		WHERE
			SR.InstanceID IN (0, @InstanceID) AND
			SR.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM [#SecurityModelRuleAccess] #MRA WHERE #MRA.[Role] = SR.SecurityRoleName AND #MRA.[Model] = MO.ObjectName)

		SET @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [#SecurityModelRuleAccess]
			(
			[Role],
			[Model],
			[Rule],
			[AllRules]
			)
		SELECT DISTINCT
			[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID),
			--[Model] = ISNULL(sub.ProcessName2, P.ProcessName),
			[Model] = ISNULL(sub.DataClassName2, DC.DataClassName),
			[Rule] = '',
			[AllRules] = 1
		FROM
			#RoleMemberRow RMR
			--INNER JOIN DataClass_Process DCP ON DCP.InstanceID = @InstanceID AND DCP.VersionID = @VersionID AND DCP.DataClassID = RMR.DataClassID
			--INNER JOIN Process P ON P.InstanceID = DCP.InstanceID AND P.VersionID = DCP.VersionID AND P.ProcessID = DCP.ProcessID
			--LEFT JOIN (SELECT ProcessName = 'Financials', ProcessName2 = 'Financials' UNION SELECT ProcessName = 'Financials', ProcessName2 = 'Financials_Detail') sub ON sub.ProcessName = P.ProcessName --Temporary fix
			INNER JOIN [DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.DataClassID = RMR.DataClassID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL 
			LEFT JOIN (SELECT DataClassName = 'Financials', DataClassName2 = 'Financials' UNION SELECT DataClassName = 'Financials', DataClassName2 = 'Financials_Detail') sub ON sub.DataClassName = DC.DataClassName--Temporary fix
		WHERE
			--NOT EXISTS (SELECT 1 FROM [#SecurityModelRuleAccess] #MRA WHERE #MRA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #MRA.[Model] = P.ProcessName)
			NOT EXISTS (SELECT 1 FROM [#SecurityModelRuleAccess] #MRA WHERE #MRA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #MRA.[Model] = DC.DataClassName)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[#SecurityMemberAccess], Ordinary roles'
		INSERT INTO [#SecurityMemberAccess]
			(
			[Role],
			[Model],
			[Dimension],
			[Hierarchy],
			[Member],
			[AccessType]
			)
		SELECT
			[Role],
			[Model],
			[Dimension],
			[Hierarchy],
			[Member],
			[AccessType]
		FROM
			(
	--Model
			SELECT DISTINCT
				[Role] = SR.SecurityRoleName,
				--[Model] = ISNULL(sub.ProcessName2, P.ProcessName),
				[Model] = ISNULL(sub.DataClassName2, DC.DataClassName),
				[Dimension] = '',
				[Hierarchy] = '',
				[Member] = '',
				[AccessType] = 2
			FROM
				[SecurityRole] SR
				--INNER JOIN [Process] P ON P.InstanceID IN (@InstanceID)
				--LEFT JOIN (SELECT ProcessName = 'Financials', ProcessName2 = 'Financials' UNION SELECT ProcessName = 'Financials', ProcessName2 = 'Financials_Detail') sub ON sub.ProcessName = P.ProcessName --Temporary fix
				INNER JOIN [DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL 
				LEFT JOIN (SELECT DataClassName = 'Financials', DataClassName2 = 'Financials' UNION SELECT DataClassName = 'Financials', DataClassName2 = 'Financials_Detail') sub ON sub.DataClassName = DC.DataClassName --Temporary fix
			WHERE
				SR.InstanceID IN (0, @InstanceID) AND
				SR.UserLicenseTypeID = 1 AND
				SR.SecurityRoleName <> 'All Users' AND
				SR.SelectYN <> 0

	--Dimension
			UNION SELECT DISTINCT
				[Role] = SR.SecurityRoleName,
				[Model] = '',
				[Dimension] = D.DimensionName,
				[Hierarchy] = D.DimensionName,
				[Member] = 'All_',
				[AccessType] = 2
			FROM
				[SecurityRole] SR
				INNER JOIN [Dimension_StorageType] DST ON DST.InstanceID IN (@InstanceID) AND DST.VersionID IN (@VersionID) AND (DST.DimensionID = -6 OR DST.ReadSecurityEnabledYN <> 0)
				INNER JOIN Dimension D ON D.DimensionID = DST.DimensionID 
			WHERE
				SR.InstanceID IN (0, @InstanceID) AND
				SR.UserLicenseTypeID = 1 AND
				SR.SecurityRoleName <> 'All Users' AND
				SR.SelectYN <> 0

	--Model + Dimension
			UNION SELECT DISTINCT
				[Role] = SR.SecurityRoleName,
				--[Model] = ISNULL(sub.ProcessName2, P.ProcessName),
				[Model] = ISNULL(sub.DataClassName2, DC.DataClassName),
				[Dimension] = D.DimensionName,
				[Hierarchy] = '',
				[Member] = '',
				--[AccessType] = CASE SR.UserLicenseTypeID WHEN -2 THEN 3 WHEN -3 THEN 2 END
				[AccessType] = CASE WHEN SR.SecurityRoleID IN (-2) THEN 3 ELSE 2 END
			FROM
				[SecurityRole] SR
				--INNER JOIN [Process] P ON P.InstanceID IN (@InstanceID) AND P.VersionID = @VersionID
				--INNER JOIN DataClass_Process DCP ON DCP.ProcessID = P.ProcessID AND DCP.VersionID = P.VersionID
				--INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = DCP.DataClassID AND DCD.VersionID = DCP.VersionID
				--INNER JOIN [Dimension_StorageType] DST ON DST.InstanceID IN (@InstanceID) AND DST.VersionID IN (@VersionID) AND DST.DimensionID = DCD.DimensionID AND DST.StorageTypeBM & 4 > 0 AND (DST.DimensionID = -6 OR DST.ReadSecurityEnabledYN <> 0)
				INNER JOIN [DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL 
				INNER JOIN [DataClass_Dimension] DCD ON DCD.InstanceID = DC.InstanceID AND DCD.VersionID = DC.VersionID AND DCD.DataClassID = DC.DataClassID 
				INNER JOIN [Dimension_StorageType] DST ON DST.InstanceID = DC.InstanceID AND DST.VersionID = DC.VersionID AND DST.DimensionID = DCD.DimensionID AND DST.StorageTypeBM & 4 > 0 AND (DST.DimensionID = -6 OR DST.ReadSecurityEnabledYN <> 0)
				INNER JOIN Dimension D ON D.DimensionID = DST.DimensionID 
				--LEFT JOIN (SELECT ProcessName = 'Financials', ProcessName2 = 'Financials' UNION SELECT ProcessName = 'Financials', ProcessName2 = 'Financials_Detail') sub ON sub.ProcessName = P.ProcessName --Temporary fix
				LEFT JOIN (SELECT DataClassName = 'Financials', DataClassName2 = 'Financials' UNION SELECT DataClassName = 'Financials', DataClassName2 = 'Financials_Detail') sub ON sub.DataClassName = DC.DataClassName --Temporary fix
			WHERE
				SR.InstanceID IN (0, @InstanceID) AND
				SR.UserLicenseTypeID = 1 AND
				SR.SecurityRoleName <> 'All Users' AND
				SR.SelectYN <> 0
			) sub
		WHERE
			NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = sub.[Role] AND #SMA.[Model] = sub.[Model] AND #SMA.[Dimension] = sub.[Dimension])

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[#SecurityMemberAccess], Z-roles ReadAccess'
		--Model
		INSERT INTO [#SecurityMemberAccess]
			(
			[Role],
			[Model],
			[Dimension],
			[Hierarchy],
			[Member],
			[AccessType]
			)
		SELECT DISTINCT
			[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID),
			--[Model] = ISNULL(sub.ProcessName2, P.ProcessName),
			[Model] = ISNULL(sub.DataClassName2, DC.DataClassName),
			[Dimension] = '',
			[Hierarchy] = '',
			[Member] = '',
			[AccessType] = SL.CallistoAccessType
		FROM
			#RoleMemberRow RMR
			--INNER JOIN DataClass_Process DCP ON DCP.InstanceID = @InstanceID AND DCP.VersionID = @VersionID AND DCP.DataClassID = RMR.DataClassID
			--INNER JOIN Process P ON P.InstanceID = DCP.InstanceID AND P.VersionID = DCP.VersionID AND P.ProcessID = DCP.ProcessID
			INNER JOIN [DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.DataClassID = RMR.DataClassID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL 
			INNER JOIN [SecurityLevel] SL ON SL.SecurityLevelBM & 32 > 0 
			--LEFT JOIN (SELECT ProcessName = 'Financials', ProcessName2 = 'Financials' UNION SELECT ProcessName = 'Financials', ProcessName2 = 'Financials_Detail') sub ON sub.ProcessName = P.ProcessName --Temporary fix
			LEFT JOIN (SELECT DataClassName = 'Financials', DataClassName2 = 'Financials' UNION SELECT DataClassName = 'Financials', DataClassName2 = 'Financials_Detail') sub ON sub.DataClassName = DC.DataClassName --Temporary fix
		WHERE
			--NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #SMA.[Model] = P.ProcessName AND #SMA.[Dimension] = '' AND #SMA.[Member] = '')
			NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #SMA.[Model] = DC.DataClassName AND #SMA.[Dimension] = '' AND #SMA.[Member] = '')

		SET @Inserted = @Inserted + @@ROWCOUNT

		--Dimension
		INSERT INTO [#SecurityMemberAccess]
			(
			[Role],
			[Model],
			[Dimension],
			[Hierarchy],
			[Member],
			[AccessType]
			)
		SELECT DISTINCT
			[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID),
			[Model] = '',
			[Dimension] = D.DimensionName,
			[Hierarchy] = ISNULL(DHI.HierarchyName, DHD.HierarchyName),
			[Member] = RMR.MemberKey,
			[AccessType] = SL.CallistoAccessType
		FROM
			#RoleMemberRow RMR
			INNER JOIN [Dimension] D ON D.DimensionID = RMR.DimensionID
			INNER JOIN [SecurityLevel] SL ON SL.SecurityLevelBM & 32 > 0 
			LEFT JOIN [DimensionHierarchy] DHI ON DHI.InstanceID = @InstanceID AND DHI.DimensionID = D.DimensionID AND DHI.HierarchyNo = 0
			LEFT JOIN [DimensionHierarchy] DHD ON DHD.InstanceID = D.InstanceID AND DHD.DimensionID = D.DimensionID AND DHD.HierarchyNo = 0
		WHERE
			RMR.WriteAccessYN = 0 AND
			NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #SMA.[Model] = '' AND #SMA.[Dimension] = D.DimensionName AND #SMA.[Member] = RMR.MemberKey)

		SET @Inserted = @Inserted + @@ROWCOUNT

		--Model + Dimension
		INSERT INTO [#SecurityMemberAccess]
			(
			[Role],
			[Model],
			[Dimension],
			[Hierarchy],
			[Member],
			[AccessType]
			)
		SELECT DISTINCT
			[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID),
			--[Model] = ISNULL(sub.ProcessName2, P.ProcessName),
			[Model] = ISNULL(sub.DataClassName2, DC.DataClassName),
			[Dimension] = D.DimensionName,
			[Hierarchy] = ISNULL(DHI.HierarchyName, DHD.HierarchyName),
			[Member] = RMR.MemberKey,
			[AccessType] = SL.CallistoAccessType
		FROM
			#RoleMemberRow RMR
			--INNER JOIN DataClass_Process DCP ON DCP.InstanceID = @InstanceID AND DCP.VersionID = @VersionID AND DCP.DataClassID = RMR.DataClassID
			--INNER JOIN Process P ON P.InstanceID = DCP.InstanceID AND P.VersionID = DCP.VersionID AND P.ProcessID = DCP.ProcessID
			INNER JOIN [DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.DataClassID = RMR.DataClassID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL 
			INNER JOIN [Dimension] D ON D.DimensionID = RMR.DimensionID
			INNER JOIN [SecurityLevel] SL ON SL.SecurityLevelBM & 32 > 0 
			LEFT JOIN [DimensionHierarchy] DHI ON DHI.InstanceID = @InstanceID AND DHI.DimensionID = D.DimensionID AND DHI.HierarchyNo = 0
			LEFT JOIN [DimensionHierarchy] DHD ON DHD.InstanceID = D.InstanceID AND DHD.DimensionID = D.DimensionID AND DHD.HierarchyNo = 0
			--LEFT JOIN (SELECT ProcessName = 'Financials', ProcessName2 = 'Financials' UNION SELECT ProcessName = 'Financials', ProcessName2 = 'Financials_Detail') sub ON sub.ProcessName = P.ProcessName --Temporary fix
			LEFT JOIN (SELECT DataClassName = 'Financials', DataClassName2 = 'Financials' UNION SELECT DataClassName = 'Financials', DataClassName2 = 'Financials_Detail') sub ON sub.DataClassName = DC.DataClassName --Temporary fix
		WHERE
			RMR.WriteAccessYN = 0 AND
			--NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #SMA.[Model] = P.ProcessName AND #SMA.[Dimension] = D.DimensionName AND #SMA.[Member] = RMR.MemberKey)
			NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #SMA.[Model] = DC.DataClassName AND #SMA.[Dimension] = D.DimensionName AND #SMA.[Member] = RMR.MemberKey)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[#SecurityMemberAccess], Z-roles WriteAccess'
		--Model
		--INSERT INTO [#SecurityMemberAccess]
		--	(
		--	[Role],
		--	[Model],
		--	[Dimension],
		--	[Hierarchy],
		--	[Member],
		--	[AccessType]
		--	)
		--SELECT DISTINCT
		--	[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID),
		--	[Model] = ISNULL(sub.ProcessName2, P.ProcessName),
		--	[Dimension] = '',
		--	[Hierarchy] = '',
		--	[Member] = '',
		--	[AccessType] = SL.CallistoAccessType
		--FROM
		--	#RoleMemberRow RMR
		--	INNER JOIN DataClass_Process DCP ON DCP.InstanceID = @InstanceID AND DCP.VersionID = @VersionID AND DCP.DataClassID = RMR.DataClassID
		--	INNER JOIN Process P ON P.InstanceID = DCP.InstanceID AND P.VersionID = DCP.VersionID AND P.ProcessID = DCP.ProcessID
		--	INNER JOIN [SecurityLevel] SL ON SL.SecurityLevelBM & 16 > 0 
		--	LEFT JOIN (SELECT ProcessName = 'Financials', ProcessName2 = 'Financials' UNION SELECT ProcessName = 'Financials', ProcessName2 = 'Financials_Detail') sub ON sub.ProcessName = P.ProcessName --Temporary fix
		--WHERE
		--	RMR.WriteAccessYN <> 0 AND
		--	NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #SMA.[Model] = P.ProcessName AND #SMA.[Dimension] = '' AND #SMA.[Member] = '' AND #SMA.[AccessType] = SL.CallistoAccessType)

		--SET @Inserted = @Inserted + @@ROWCOUNT

		--Dimension
		INSERT INTO [#SecurityMemberAccess]
			(
			[Role],
			[Model],
			[Dimension],
			[Hierarchy],
			[Member],
			[AccessType]
			)
		SELECT DISTINCT
			[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID),
			[Model] = '',
			[Dimension] = D.DimensionName,
			[Hierarchy] = ISNULL(DHI.HierarchyName, DHD.HierarchyName),
			[Member] = RMR.MemberKey,
			[AccessType] = SL.CallistoAccessType
		FROM
			#RoleMemberRow RMR
			INNER JOIN Dimension D ON D.DimensionID = RMR.DimensionID
			INNER JOIN [SecurityLevel] SL ON SL.SecurityLevelBM & 16 > 0 
			LEFT JOIN [DimensionHierarchy] DHI ON DHI.InstanceID = @InstanceID AND DHI.DimensionID = D.DimensionID AND DHI.HierarchyNo = 0
			LEFT JOIN [DimensionHierarchy] DHD ON DHD.InstanceID = D.InstanceID AND DHD.DimensionID = D.DimensionID AND DHD.HierarchyNo = 0
		WHERE
			RMR.WriteAccessYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #SMA.[Model] = '' AND #SMA.[Dimension] = D.DimensionName AND #SMA.[Member] = RMR.MemberKey AND #SMA.[AccessType] = SL.CallistoAccessType)

		SET @Inserted = @Inserted + @@ROWCOUNT

		--Model + Dimension
		INSERT INTO [#SecurityMemberAccess]
			(
			[Role],
			[Model],
			[Dimension],
			[Hierarchy],
			[Member],
			[AccessType]
			)
		SELECT DISTINCT
			[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID),
			--[Model] = ISNULL(sub.ProcessName2, P.ProcessName),
			[Model] = ISNULL(sub.DataClassName2, DC.DataClassName),
			[Dimension] = D.DimensionName,
			[Hierarchy] = ISNULL(DHI.HierarchyName, DHD.HierarchyName),
			[Member] = RMR.MemberKey,
			[AccessType] = SL.CallistoAccessType
		FROM
			#RoleMemberRow RMR
			--INNER JOIN DataClass_Process DCP ON DCP.InstanceID = @InstanceID AND DCP.VersionID = @VersionID AND DCP.DataClassID = RMR.DataClassID
			--INNER JOIN Process P ON P.InstanceID = DCP.InstanceID AND P.VersionID = DCP.VersionID AND P.ProcessID = DCP.ProcessID
			INNER JOIN [DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.DataClassID = RMR.DataClassID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL 
			INNER JOIN [Dimension] D ON D.DimensionID = RMR.DimensionID
			INNER JOIN [SecurityLevel] SL ON SL.SecurityLevelBM & 16 > 0 
			LEFT JOIN [DimensionHierarchy] DHI ON DHI.InstanceID = @InstanceID AND DHI.DimensionID = D.DimensionID AND DHI.HierarchyNo = 0
			LEFT JOIN [DimensionHierarchy] DHD ON DHD.InstanceID = D.InstanceID AND DHD.DimensionID = D.DimensionID AND DHD.HierarchyNo = 0
			--LEFT JOIN (SELECT ProcessName = 'Financials', ProcessName2 = 'Financials' UNION SELECT ProcessName = 'Financials', ProcessName2 = 'Financials_Detail') sub ON sub.ProcessName = P.ProcessName --Temporary fix
			LEFT JOIN (SELECT DataClassName = 'Financials', DataClassName2 = 'Financials' UNION SELECT DataClassName = 'Financials', DataClassName2 = 'Financials_Detail') sub ON sub.DataClassName = DC.DataClassName --Temporary fix
		WHERE
			RMR.WriteAccessYN <> 0 AND
			--NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #SMA.[Model] = P.ProcessName AND #SMA.[Dimension] = D.DimensionName AND #SMA.[Member] = RMR.MemberKey AND #SMA.[AccessType] = SL.CallistoAccessType)
			NOT EXISTS (SELECT 1 FROM [#SecurityMemberAccess] #SMA WHERE #SMA.[Role] = 'zSecurityRole_' + CASE WHEN RMR.RoleID <= 9 THEN '00' ELSE CASE WHEN RMR.RoleID <= 99 THEN '0' ELSE '' END END + CONVERT(nvarchar(10), RMR.RoleID) AND #SMA.[Model] = DC.DataClassName AND #SMA.[Dimension] = D.DimensionName AND #SMA.[Member] = RMR.MemberKey AND #SMA.[AccessType] = SL.CallistoAccessType)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = '[#SecurityActionAccess]'
			EXEC [spPortalAdminGet_Object] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StartNode = -104, @ReturnRowsYN = 0, @JobID = @JobID

			IF @DebugBM & 2 > 0
				BEGIN
					SELECT TempTable = '#Object', * FROM #Object ORDER BY [ObjectID]
					SELECT TempTable = '@Template_Object', * FROM [@Template_Object]
				END

			INSERT INTO [#SecurityActionAccess]
				(
				[Role],
				[Label],
				[HideAction]
				)
			SELECT
				[Role] = SR.SecurityRoleName,
				[Label] = temp.CallistoLabel,
				[HideAction] = CASE WHEN SRO.SecurityLevelBM & 1 > 0 THEN 0 ELSE 1 END
			FROM
				#Object O 
				INNER JOIN [pcINTEGRATOR].[dbo].[@Template_Object] temp ON temp.ObjectID = O.ObjectID AND temp.CallistoLabel IS NOT NULL
				INNER JOIN [pcINTEGRATOR].[dbo].[SecurityRole] SR ON SR.InstanceID IN (0, @InstanceID) AND SR.SecurityRoleID NOT IN (-1, -10) AND SR.SelectYN <> 0
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO ON SRO.[InstanceID] = @InstanceID AND SRO.SecurityRoleID = SR.SecurityRoleID AND SRO.ObjectID = O.ObjectID AND SRO.[SelectYN] <> 0
			WHERE
				NOT EXISTS (SELECT 1 FROM [#SecurityActionAccess] #SAA WHERE #SAA.[Role] = SR.SecurityRoleName AND #SAA.[Label] = temp.CallistoLabel)				
			ORDER BY
				SR.[SecurityRoleName], O.[SortOrder]

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Debug, show result'	
		IF @DebugBM & 2 > 0
			BEGIN
				IF @DimensionYN <> 0 SELECT TableName = '#DimensionDefinition', * FROM [#DimensionDefinition]
				SELECT TableName = '#UserDefinition', * FROM [#UserDefinition]
				SELECT TableName = '#SecurityUser', * FROM [#SecurityUser]
				SELECT TableName = '#SecurityRoleDefinition', * FROM [#SecurityRoleDefinition]
				SELECT TableName = '#SecurityModelRuleAccess', * FROM [#SecurityModelRuleAccess]
				SELECT TableName = '#SecurityMemberAccess', * FROM [#SecurityMemberAccess] ORDER BY [Role], [Model], [Dimension]
				SELECT TableName = '#SecurityActionAccess', * FROM [#SecurityActionAccess]
			END

	SET @Step = 'Drop temp tables'
		--DROP TABLE #User
		DROP TABLE #RoleOrganizationPosition
		DROP TABLE #RoleMemberRow
		DROP TABLE #Object
		DROP TABLE #OPDimReadAccess
		DROP table #OPDataClassReadAccess

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
