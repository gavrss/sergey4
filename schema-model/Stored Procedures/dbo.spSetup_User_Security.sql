SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_User_Security]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	/**
		Pre-requisite for SourceTypeID = 17 (Callisto): Do 'Export Application' from modeler. 
		Export to SQL Database [pcCALLISTO_Export] the following: 1)All Dimensions definitions; 2)All Security Roles; and 3)All Users definitions
	**/
	@SourceTypeID INT = NULL, --Mandatory
	@Email NVARCHAR(100) = NULL, --Optional
	@UserNameAD NVARCHAR(100) = NULL, --Optional
	@UserNameDisplay NVARCHAR(100) = NULL, --Optional
	@DemoYN BIT = 1,
	@LocaleID INT = -41,
	@AssignedUserID INT = NULL OUT,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000465,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spSetup_User_Security',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSetup_User_Security] @UserID=-10, @InstanceID = 673, @VersionID = 1134, @SourceTypeID = 5, @DebugBM=3

EXEC [spSetup_User_Security] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID INT = -10,
	@SourceVersionID INT = -10,
	@SQLStatement NVARCHAR(MAX),
	@InstanceShortName NVARCHAR(5),
	@ApplicationID INT,
	@ApplicationName NVARCHAR(100),
	@ETLDatabase NVARCHAR(100),
	@CallistoDatabase NVARCHAR(100),
	@FullAccessRoleID INT = -2,
	@ObjectID_pcPortal INT,
	@ObjectID_Callisto INT,
	@ObjectID_Application INT,	
	@CallistoSecurityRoleName NVARCHAR(100),
	@InstanceID_User INT,
	@SourceCustomerID INT,
	@DestinationCustomerID INT,
	@SourceTypeName NVARCHAR(50),
	@Owner NVARCHAR(10), 
	@SourceDatabase NVARCHAR(255),
	@SourceID INT,

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
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'NeHa',
	@ModifiedBy NVARCHAR(50) = 'JaWo',
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup User and SecurityRole',
			@MandatoryParameter = 'SourceTypeID' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Added @SourceTypeID = 17 (Callisto). Added UPDATE on [Username] on #CallistoUsers.'
		IF @Version = '2.0.2.2149' SET @Description = 'Added @SourceTemplateYN. When set to 1, shall use references from @Template_* objects.'
		IF @Version = '2.0.3.2151' SET @Description = 'Set [ParentObjectID] column when updating [pcINTEGRATOR]..[Object] table.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID. Added @SourceTypeID = -10.'
		IF @Version = '2.1.0.2165' SET @Description = 'Added iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2173' SET @Description = 'Set correct @AssignedUserID for @DemoYN = 0. Added @Step = Create default UserPropertyValue.'
		IF @Version = '2.1.1.2175' SET @Description = 'Handle SourceTypeID 5 (P21).'
		IF @Version = '2.1.2.2182' SET @Description = 'SourceTypeID 5 (P21) add duplicated users at least once.'
		IF @Version = '2.1.2.2199' SET @Description = 'For SourceTypeID 5 (P21), Only add users if there is an existing data from [pcINTEGRATOR_Data].[dbo].[Person]. Update PersonID in User table if exists.'

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
			@Selected = ISNULL(@Selected, 0),
			@UserID = ISNULL(@UserID, 0)

		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@InstanceShortName = ISNULL(I.[InstanceShortName], LEFT(@ApplicationName, 5)),
			@ApplicationID = A.[ApplicationID],
			@ApplicationName = A.[ApplicationName],
			@ETLDatabase = A.[ETLDatabase],
			@CallistoDatabase = A.[DestinationDatabase]
		FROM
			[Application] A
			INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		SELECT
			@UserNameAD = ISNULL(@UserNameAD, 'live\' + @InstanceShortName + '.' + LEFT(LEFT(@Email, CHARINDEX('@', @Email) - 1), 14)),
			@UserNameDisplay = ISNULL(@UserNameDisplay, @Email)

		IF @DebugBM & 2 > 0 
			SELECT 
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@Email] = @Email,
				[@UserNameAD] = @UserNameAD,
				[@UserNameDisplay] = @UserNameDisplay,
				[@ApplicationID] = @ApplicationID,
				[@ApplicationName] = @ApplicationName,
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase,
				[@InstanceShortName] = @InstanceShortName,
				[@JobID] = @JobID

	SET @Step = 'Create temp tables'
		CREATE TABLE #CallistoUsers
			(
			[InstanceID] INT,
			[UserName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[UserNameAD] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[UserNameDisplay] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[UserTypeID] INT,
			[UserLicenseTypeID] INT,
			[LocaleID] INT,
			[LanguageID] INT,
			[ObjectGuiBehaviorBM] INT,
			[Email] NVARCHAR(100) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #CallistoActionsAccess
			(
			[SecurityRoleName] NVARCHAR (100) COLLATE DATABASE_DEFAULT,
			[CallistoLabel] NVARCHAR (100) COLLATE DATABASE_DEFAULT,
			[ObjectID] INT
			)

		CREATE TABLE #SourceUsers
			(
			[InstanceID] INT,
			[UserName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[UserNameAD] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[UserNameDisplay] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[FamilyName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[GivenName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[PersonID] INT
			)

	SET @Step = 'SourceTypeID = 17, Callisto'
		IF @SourceTypeID = 17 --Callisto
			BEGIN
				SET @Step = 'Insert into #CallistoUsers'
					INSERT INTO #CallistoUsers
						(
						[InstanceID],
						[UserName],
						[UserNameAD],
						[UserNameDisplay],
						[UserTypeID],
						[UserLicenseTypeID],
						[LocaleID],
						[LanguageID],
						[ObjectGuiBehaviorBM],
						[Email]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[UserName] = CASE WHEN (XU.[Email] IS NULL OR XU.[Email] = '') THEN RIGHT(XU.[WinUser], LEN(XU.[WinUser])-CHARINDEX('\', XU.[WinUser])) ELSE XU.[Email] END,
						[UserNameAD] = XU.[WinUser],
						[UserNameDisplay] = CASE WHEN (XU.[Email] IS NULL OR XU.[Email] = '') THEN RIGHT(XU.[WinUser], LEN(XU.[WinUser])-CHARINDEX('\', XU.[WinUser])) ELSE XU.[Email] END,
						[UserTypeID] = -1,
						[UserLicenseTypeID] = 1,
						[LocaleID] = -41,
						[LanguageID] = 1,
						[ObjectGuiBehaviorBM] = 3,
						[Email] = ISNULL([XU].[Email], '')
					FROM
						[pcCALLISTO_Export].[dbo].[XT_UserDefinition] XU
					WHERE
						XU.[Active] = 1 AND
						'' <> CASE WHEN (XU.[Email] IS NULL OR XU.[Email] = '') THEN RIGHT(XU.[WinUser], LEN(XU.[WinUser])-CHARINDEX('\', XU.[WinUser])) ELSE XU.[Email] END 

					IF @Debug <> 0 SELECT [Table] = '[#CallistoUsers]', * FROM #CallistoUsers

					--Update [Username] on #CallistoUsers
					UPDATE C
					SET
						[UserName] = U.UserName
					FROM 
						#CallistoUsers C
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.InstanceID = C.InstanceID AND U.UserNameAD = C.UserNameAD AND U.DeletedID IS NULL					

				SET @Step = 'Insert into User'
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
						[InstanceID],
						[UserName],
						[UserNameAD],
						[UserNameDisplay],
						[UserTypeID],
						[UserLicenseTypeID],
						[LocaleID],
						[LanguageID],
						[ObjectGuiBehaviorBM]
					FROM 
						#CallistoUsers C
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.UserName = C.UserName AND U.DeletedID IS NULL) 

					SET @Inserted = @Inserted + @@ROWCOUNT

				SET @Step = 'Insert into UserPropertyValue'
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
						(
						[InstanceID],
						[UserID],
						[UserPropertyTypeID],
						[UserPropertyValue],
						[SelectYN]
						)
					SELECT 
						[InstanceID] = U.InstanceID,
						[UserID] = U.UserID,
						[UserPropertyTypeID] = -3,
						[UserPropertyValue] = C.[Email],
						[SelectYN] = 1
					FROM
						#CallistoUsers C
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.UserName = C.UserName AND U.DeletedID IS NULL 
					WHERE
						C.[Email] <> '' AND            
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV WHERE UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -3)

					SET @Inserted = @Inserted + @@ROWCOUNT
			
				SET @Step = 'Insert into SecurityRole'
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRole]
						(
						[InstanceID],
						[SecurityRoleName],
						[UserLicenseTypeID],
						[SelectYN]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[SecurityRoleName] = XSRD.[Label],
						[UserLicenseTypeID] = 1, -- Licensed
						[SelectYN] = 1
					FROM
						[pcCALLISTO_Export].[dbo].[XT_SecurityRoleDefinition] XSRD
					WHERE
						XSRD.[Label] NOT IN ('Administrators','FullAccess','ReportAccess') AND
						XSRD.[Label] NOT LIKE ('zSecurityRole%') AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[SecurityRole] SR WHERE SR.InstanceID = @InstanceID AND SR.SecurityRoleName = XSRD.[Label])
					
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
						[SecurityRoleID] = SR.SecurityRoleID,
						[UserID] = U.UserID
					FROM
						[pcCALLISTO_Export].[dbo].[XT_SecurityUser] XSU
						INNER JOIN [pcINTEGRATOR].[dbo].[SecurityRole] SR ON SR.SecurityRoleName = XSU.[Role]
						INNER JOIN #CallistoUsers C ON C.UserNameAD = XSU.WinUser 
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.InstanceID = @InstanceID AND U.UserName = C.UserName
					WHERE
						XSU.[Role] NOT IN ('ReportAccess') AND
						XSU.[Role] NOT LIKE ('zSecurityRole%') AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU WHERE SRU.InstanceID = @InstanceID AND SRU.SecurityRoleID = SR.SecurityRoleID AND SRU.UserID = U.UserID)

					SET @Inserted = @Inserted + @@ROWCOUNT
			
				SET @Step = 'Insert into SecurityRoleObject (Excel Access)'
					IF CURSOR_STATUS('global','CallistoActionsAccess_Cursor') >= -1 DEALLOCATE CallistoActionsAccess_Cursor
					DECLARE CallistoActionsAccess_Cursor CURSOR FOR
			
						SELECT DISTINCT 
							[@CallistoSecurityRoleName] = CASE WHEN XSAA.[Role] LIKE 'zSecurityRole%' THEN 'All Users' ELSE XSAA.[Role] END
						FROM
							[pcCALLISTO_Export].[dbo].[XT_SecurityActionAccess] XSAA

						OPEN CallistoActionsAccess_Cursor
						FETCH NEXT FROM CallistoActionsAccess_Cursor INTO @CallistoSecurityRoleName

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @Debug <> 0 SELECT [ @CallistoSecurityRoleName] =  @CallistoSecurityRoleName

								INSERT INTO #CallistoActionsAccess
									(
									[SecurityRoleName],
									[CallistoLabel],
									[ObjectID]
									)
								SELECT 
									[SecurityRoleName] = ISNULL(XTSAA.[Role], @CallistoSecurityRoleName),
									[CallistoLabel] = XTSAA.[Label],
									[ObjectID] = TempObj.ObjectID
								FROM
									[pcINTEGRATOR].[dbo].[@Template_Object] TempObj
									--LEFT JOIN [pcCALLISTO_Export].[dbo].[XT_SecurityActionAccess] XTSAA ON XTSAA.[Label] = TempObj.CallistoLabel AND XTSAA.[Role] = @CallistoSecurityRoleName
									LEFT JOIN
										(
										 SELECT DISTINCT 
											[Role] = CASE WHEN [Role] LIKE 'zSecurityRole%' THEN 'All Users' ELSE [Role] END,
											[Label],
											[HideAction]
										  FROM 
											[pcCALLISTO_Export].[dbo].[XT_SecurityActionAccess]
										) AS XTSAA ON XTSAA.[Label] = TempObj.CallistoLabel AND XTSAA.[Role] = @CallistoSecurityRoleName								
								WHERE
									TempObj.ObjectTypeBM & 1024 > 0 AND 
									TempObj.SecurityLevelBM & 3 > 0

								FETCH NEXT FROM CallistoActionsAccess_Cursor INTO @CallistoSecurityRoleName
							END
					CLOSE CallistoActionsAccess_Cursor
					DEALLOCATE CallistoActionsAccess_Cursor

					IF @Debug <> 0 SELECT * FROM #CallistoActionsAccess

					DELETE SRO
					FROM
						[pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO
						INNER JOIN [pcINTEGRATOR].[dbo].[Object] O ON O.ObjectID = SRO.ObjectID AND O.ObjectTypeBM & 1024 > 0 AND O.SecurityLevelBM & 3 > 0
					WHERE 
						SRO.InstanceID = @InstanceID

					SELECT @Deleted = @Deleted + @@ROWCOUNT
				
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
						(
						[InstanceID],
						[SecurityRoleID],
						[ObjectID],
						[SecurityLevelBM]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[SecurityRoleID] = SR.SecurityRoleID,
						[ObjectID] = C.ObjectID, 
						[SecurityLevelBM] = CASE WHEN C.CallistoLabel IS NULL THEN 1 ELSE 2 END
					FROM
						#CallistoActionsAccess C
						LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_Object] TempObj ON TempObj.CallistoLabel = C.CallistoLabel
						INNER JOIN [pcINTEGRATOR].[dbo].[SecurityRole] SR ON SR.InstanceID IN (0, @InstanceID) AND SR.SecurityRoleName = C.SecurityRoleName
					WHERE
						NOT EXISTS (SELECT 1 FROM [SecurityRoleObject] SRO WHERE SRO.[InstanceID] = @InstanceID AND SRO.[SecurityRoleID] = SR.SecurityRoleID AND SRO.[ObjectID] = C.ObjectID)

					SELECT @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'SourceTypeID = 5 P21'
		IF @SourceTypeID IN (5)
			BEGIN
				SET @Step = 'Get Users from Source (P21)'
					IF (SELECT COUNT(1) FROM [pcINTEGRATOR_Data].[dbo].[Person] WHERE InstanceID = @InstanceID) > 0
					BEGIN
					
						IF CURSOR_STATUS('global','Source_Cursor') >= -1 DEALLOCATE Source_Cursor
						DECLARE Source_Cursor CURSOR FOR
			
							SELECT DISTINCT
								[SourceTypeName] = ST.[SourceTypeName],
								[SourceID] = S.[SourceID],
								[Owner] = CASE WHEN S.[SourceTypeID] = 11 THEN 'erp' ELSE 'dbo' END,
								[SourceDatabase] = S.[SourceDatabase]
							FROM
								[pcINTEGRATOR_Data].[dbo].[Source] S
								INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
							WHERE
								S.[InstanceID] = @InstanceID AND
								S.[VersionID] = @VersionID AND
								S.[SelectYN] <> 0 AND
								S.[SourceTypeID] = @SourceTypeID

							OPEN Source_Cursor
							FETCH NEXT FROM Source_Cursor INTO @SourceTypeName, @SourceID, @Owner, @SourceDatabase

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @DebugBM & 2 > 0 SELECT [@SourceTypeName] = @SourceTypeName, [@SourceID] = @SourceID, [@Owner] = @Owner, [@SourceDatabase] = @SourceDatabase

									SET @SQLStatement = '
										INSERT INTO #SourceUsers
											(
											[InstanceID],
											[UserName],
											[UserNameAD],
											[UserNameDisplay],
											[FamilyName],
											[GivenName],
											[PersonID]
											)
										SELECT
											[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID) + ',
											[UserName] = MAX(C.[email_address]),
											[UserNameAD] = MAX(''live\' + @InstanceShortName + '.'' + LEFT(LEFT(C.[email_address], CHARINDEX(''@'', C.[email_address]) - 1), 14)),
											[UserNameDisplay] = MAX(C.[first_name] + CASE WHEN LEN(C.[mi]) > 0 THEN '' '' + C.[mi] ELSE '''' END + '' '' + C.[last_name]),
											[FamilyName] = MAX(C.[last_name]),
											[GivenName] = MAX(C.[first_name]),
											[PersonID] = MAX(P.PersonID)
										FROM
											' + @SourceDatabase + '.' + @Owner + '.[contacts_ud] cu
											INNER JOIN ' + @SourceDatabase + '.' + @Owner + '.[contacts] c ON c.id = cu.id
											INNER JOIN [pcINTEGRATOR_Data].[dbo].[Person] P ON P.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND P.SourceID = ' + CONVERT(NVARCHAR(15), @SourceID) + ' AND P.EmployeeNumber = CU.[employee_number]
										WHERE
											C.[email_address] IS NOT NULL AND 
											CU.[employee_number] IS NOT NULL AND
											NOT EXISTS (SELECT 1 FROM #SourceUsers SU WHERE SU.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND SU.UserName = C.[email_address] AND SU.PersonID = P.PersonID)
										GROUP BY
											C.[email_address]'
	--									HAVING COUNT(1) = 1'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT

									FETCH NEXT FROM Source_Cursor INTO @SourceTypeName, @SourceID, @Owner, @SourceDatabase
								END

						CLOSE Source_Cursor
						DEALLOCATE Source_Cursor

					END

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#SourceUsers', * FROM #SourceUsers ORDER BY [UserName]

				SET @Step = 'Update PersonID'
					UPDATE U
					SET
						[PersonID] = SU.[PersonID]
					FROM
						[pcINTEGRATOR_Data].[dbo].[User] U
						INNER JOIN #SourceUsers SU ON SU.[InstanceID] = @InstanceID AND SU.[UserName] = U.[UserName]
					WHERE
						U.[PersonID] IS NULL AND
						U.[DeletedID] IS NULL

				SET @Step = 'Create User (Source=P21)'
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
						[ObjectGuiBehaviorBM],
						[SelectYN],
						[PersonID]
						)
					SELECT 
						SU.[InstanceID],
						SU.[UserName],
						SU.[UserNameAD],
						SU.[UserNameDisplay],
						[UserTypeID] = -1,
						[UserLicenseTypeID] = 1,
						[LocaleID] = -41,
						[LanguageID] = 1,
						[ObjectGuiBehaviorBM] = 3,
						[SelectYN] = 1,
						[PersonID] = SU.PersonID
					FROM
						#SourceUsers SU
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.InstanceID = SU.InstanceID AND U.UserName = SU.UserName AND U.DeletedID IS NULL)
				
					SET @Inserted = @Inserted + @@ROWCOUNT
				
				SET @Step = 'Create UserPropertyType Email (Source=P21)'
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
						(
						[InstanceID],
						[UserID],
						[UserPropertyTypeID],
						[UserPropertyValue],
						[SelectYN]
						)
					SELECT 
						[InstanceID] = U.[InstanceID],
						[UserID] = U.[UserID],
						[UserPropertyTypeID] = -3,
						[UserPropertyValue] = U.[UserName],
						[SelectYN] = 1
					FROM
						#SourceUsers SU
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.InstanceID = SU.InstanceID AND U.UserName = SU.UserName AND U.SelectYN <> 0 AND U.DeletedID IS NULL
					WHERE       
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV WHERE UPV.InstanceID = U.InstanceID AND UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -3)

					SET @Inserted = @Inserted + @@ROWCOUNT

				SET @Step = 'Create UserPropertyType Family Name (Source=P21)'
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
						(
						[InstanceID],
						[UserID],
						[UserPropertyTypeID],
						[UserPropertyValue],
						[SelectYN]
						)
					SELECT 
						[InstanceID] = U.[InstanceID],
						[UserID] = U.[UserID],
						[UserPropertyTypeID] = -2,
						[UserPropertyValue] = SU.[FamilyName],
						[SelectYN] = 1
					FROM
						#SourceUsers SU
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.InstanceID = SU.InstanceID AND U.UserName = SU.UserName AND U.SelectYN <> 0 AND U.DeletedID IS NULL
					WHERE       
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV WHERE UPV.InstanceID = U.InstanceID AND UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -2)

					SET @Inserted = @Inserted + @@ROWCOUNT

				SET @Step = 'Create UserPropertyType Given Name (Source=P21)'
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
						(
						[InstanceID],
						[UserID],
						[UserPropertyTypeID],
						[UserPropertyValue],
						[SelectYN]
						)
					SELECT 
						[InstanceID] = U.[InstanceID],
						[UserID] = U.[UserID],
						[UserPropertyTypeID] = -1,
						[UserPropertyValue] = SU.[GivenName],
						[SelectYN] = 1
					FROM
						#SourceUsers SU
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.InstanceID = SU.InstanceID AND U.UserName = SU.UserName AND U.SelectYN <> 0 AND U.DeletedID IS NULL
					WHERE       
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV WHERE UPV.InstanceID = U.InstanceID AND UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -1)

					SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'SourceTypeID = -10 Default setup; SourceTypeID = 3 iScala, SourceTypeID = 11 EpicorERP, SourceTypeID = 5 P21'
		IF @SourceTypeID IN (-10, 3, 7, 11, 5) AND @Email IS NOT NULL
			BEGIN
				SET @Step = 'Create User'
					BEGIN
						--Check if UserName exists
						IF (SELECT COUNT(1) FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.[UserName] = @Email) <> 0
							BEGIN                            
								SELECT @AssignedUserID = [UserID] FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE [UserName] = @Email

								INSERT INTO [pcINTEGRATOR_Data].[dbo].[User_Instance]
									(
								    [InstanceID],
								    [UserID],
								    [InsertedBy]
									)
								SELECT 
									[InstanceID] = @InstanceID,
								    [UserID] = @AssignedUserID,
								    [InsertedBy] = @UserID
								WHERE 
									NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] UI WHERE UI.[InstanceID] = @InstanceID AND UI.[UserID] = @AssignedUserID)

								SELECT
									@SourceCustomerID = I.CustomerID
								FROM
									[pcINTEGRATOR_Data].[dbo].[User] U
									INNER JOIN [pcINTEGRATOR_Data].[dbo].[Instance] I ON I.InstanceID = U.InstanceID
								WHERE
									U.UserID = @AssignedUserID

								SELECT
									@DestinationCustomerID = I.CustomerID
								FROM
									[pcINTEGRATOR_Data].[dbo].[Instance] I
								WHERE
									I.InstanceID = @InstanceID

								IF @SourceCustomerID = @DestinationCustomerID
									UPDATE UI
									SET
										[ExpiryDate] = NULL
									FROM
										[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
									WHERE
										[InstanceID] = @InstanceID AND
										[UserID] = @AssignedUserID
							END

						ELSE IF (SELECT COUNT(1) FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[User] U WHERE U.[UserName] = @Email) <> 0
							BEGIN                            
								SELECT @InstanceID_User = InstanceID FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[User] U WHERE U.[UserName] = @Email
								EXEC [dbo].[spGet_PartnerUser] @UserID = @UserID, @InstanceID = @InstanceID_User
								
								SELECT @AssignedUserID = [UserID] FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE [UserName] = @Email

								INSERT INTO [pcINTEGRATOR_Data].[dbo].[User_Instance]
									(
								    [InstanceID],
								    [UserID],
								    [InsertedBy]
									)
								SELECT 
									[InstanceID] = @InstanceID,
								    [UserID] = @AssignedUserID,
								    [InsertedBy] = @UserID
								WHERE 
									NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] UI WHERE UI.[InstanceID] = @InstanceID AND UI.[UserID] = @AssignedUserID)
							END
						ELSE --UserName does not exists                          
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
											[ObjectGuiBehaviorBM],
											[InheritedFrom]
											)
										SELECT
											[InstanceID] = @InstanceID,
											[UserName] = @Email,
											[UserNameAD] = @UserNameAD,
											[UserNameDisplay] = @UserNameDisplay,
											[UserTypeID] = TU.[UserTypeID],
											[UserLicenseTypeID] = TU.[UserLicenseTypeID],
											[LocaleID] = ISNULL(@LocaleID, TU.[LocaleID]),
											[LanguageID] = TU.[LanguageID],
											[ObjectGuiBehaviorBM] = TU.[ObjectGuiBehaviorBM],
											[InheritedFrom] = TU.[UserID]
										FROM
											[pcINTEGRATOR].[dbo].[@Template_User] TU
										WHERE
											TU.[InstanceID] = @SourceInstanceID AND
											NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.InstanceID = @InstanceID AND U.[UserName] = @Email)

										SELECT @AssignedUserID = @@IDENTITY, @Inserted = @Inserted + @@ROWCOUNT

										IF @AssignedUserID < 10
											SELECT 
												@AssignedUserID = UserID 
											FROM 
												[pcINTEGRATOR_Data].[dbo].[User]
											WHERE
												[InstanceID] = @InstanceID AND 
												[UserName] = @Email AND 
												[UserNameAD] = @UserNameAD AND 
												[UserNameDisplay] = @UserNameDisplay

										IF @DebugBM & 2 > 0 SELECT [@AssignedUserID] = @AssignedUserID, [@DemoYN] = @DemoYN

									END
								ELSE
									BEGIN
										SELECT @AssignedUserID = MIN(UserID) - 1 FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE UserID < -1000
										SET @AssignedUserID = ISNULL(@AssignedUserID, -1001)

										SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[User] ON
		
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
											[ObjectGuiBehaviorBM],
											[InheritedFrom]
											)
										SELECT
											[InstanceID] = @InstanceID,
											[UserID] = @AssignedUserID,
											[UserName] = @Email,
											[UserNameAD] = @UserNameAD,
											[UserNameDisplay] = @UserNameDisplay,
											[UserTypeID] = TU.[UserTypeID],
											[UserLicenseTypeID] = TU.[UserLicenseTypeID],
											[LocaleID] = ISNULL(@LocaleID, TU.[LocaleID]),
											[LanguageID] = TU.[LanguageID],
											[ObjectGuiBehaviorBM] = TU.[ObjectGuiBehaviorBM],
											[InheritedFrom] = TU.[UserID]
										FROM
											[pcINTEGRATOR].[dbo].[@Template_User] TU
										WHERE
											TU.[InstanceID] = @SourceInstanceID AND
											NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] U WHERE U.InstanceID = @InstanceID AND U.[UserName] = @Email)

										SET @Inserted = @Inserted + @@ROWCOUNT
										SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[User] OFF
									END
							END
					END	

				SET @Step = 'Create default UserPropertyValue'
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
						(
						[InstanceID],
						[UserID],
						[UserPropertyTypeID],
						[UserPropertyValue],
						[SelectYN]
						)
					SELECT 
						[InstanceID] = U.[InstanceID],
						[UserID] = U.[UserID],
						[UserPropertyTypeID] = -3,
						[UserPropertyValue] = U.[UserName],
						[SelectYN] = 1
					FROM
						[pcINTEGRATOR_Data].[dbo].[User] U 
					WHERE
						U.[InstanceID] = @InstanceID AND
						U.[UserID] = @AssignedUserID AND
						(U.[UserName] = @Email AND @Email <> '') AND
						U.[SelectYN] <> 0 AND
						U.[DeletedID] IS NULL AND        
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV WHERE UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -3)

					SET @Inserted = @Inserted + @@ROWCOUNT

				SET @Step = 'Create default SecurityRoleUser'
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
						(
						[InstanceID],
						[SecurityRoleID],
						[UserID]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[SecurityRoleID] = TSR.SecurityRoleID,
						[UserID] = @AssignedUserID
					FROM
						[pcINTEGRATOR].[dbo].[@Template_SecurityRole] TSR
					WHERE
						TSR.InstanceID = 0 AND
						TSR.SecurityRoleID IN (-1, -2) AND
						TSR.SelectYN <> 0 AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU WHERE SRU.[InstanceID] = @InstanceID AND SRU.[SecurityRoleID] IN (-1, -2) AND SRU.[UserID] = @AssignedUserID)

					SET @Inserted = @Inserted + @@ROWCOUNT
									
				SET @Step = 'Create default Object'
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Object]
						(
						[InstanceID],
						[ObjectName],
						[ObjectTypeBM],
						[ParentObjectID],
						[SecurityLevelBM],
						[InheritedFrom]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[ObjectName] = REPLACE(TOBJ.ObjectName, '@ApplicationName', @ApplicationName),
						[ObjectTypeBM],
						[ParentObjectID],
						[SecurityLevelBM] = 60,
						[InheritedFrom] = TOBJ.ObjectID
					FROM
						[pcINTEGRATOR].[dbo].[@Template_Object] TOBJ
					WHERE
						TOBJ.InstanceID = @SourceInstanceID AND
						TOBJ.SelectYN <> 0 AND 
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Object] O WHERE O.[InstanceID] = @InstanceID AND O.[ObjectName] = TOBJ.ObjectName)

					SELECT @Inserted = @Inserted + @@ROWCOUNT

					UPDATE O
					SET
						[ParentObjectID] = ISNULL(O2.ObjectID, O.ParentObjectID)
					FROM
						[pcINTEGRATOR_Data].[dbo].[Object] O
						LEFT JOIN [pcINTEGRATOR_Data].[dbo].[Object] O2 ON O2.InstanceID = O.InstanceID AND O2.InheritedFrom = O.ParentObjectID 
					WHERE
						O.InstanceID = @InstanceID

					SELECT @Updated = @Updated + @@ROWCOUNT

					SELECT 
						@ObjectID_Application = ISNULL(@ObjectID_Application, O.ObjectID)
					FROM 
						[pcINTEGRATOR_Data].[dbo].[Object] O 
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

				SET @Step = 'Create default SecurityRoleObject'
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
						(
						[InstanceID],
						[SecurityRoleID],
						[ObjectID],
						[SecurityLevelBM]
						)
					SELECT
						[InstanceID] = @InstanceID,
						[SecurityRoleID] = TSRO.[SecurityRoleID],
						[ObjectID] = TSRO.[ObjectID],
						[SecurityLevelBM] = TSRO.[SecurityLevelBM]
					FROM
						[pcINTEGRATOR].[dbo].[@Template_SecurityRoleObject] TSRO
					WHERE
						TSRO.InstanceID = @SourceInstanceID AND
						TSRO.SelectYN <> 0 AND 
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO WHERE SRO.InstanceID = @InstanceID AND SRO.[SecurityRoleID] = TSRO.[SecurityRoleID] AND SRO.[ObjectID] = TSRO.ObjectID)

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

					--INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
					--	(
					--	[InstanceID],
					--	[SecurityRoleID],
					--	[ObjectID],
					--	[SecurityLevelBM]
					--	)
					--SELECT
					--	[InstanceID] = @InstanceID,
					--	[SecurityRoleID] = @FullAccessRoleID,
					--	[ObjectID] = O.[ObjectID],
					--	[SecurityLevelBM] = 1
					--FROM
					--	[Object] O
					--WHERE
					--	O.InstanceID = 0 AND
					--	O.ObjectTypeBM & 1024 > 0 AND
					--	O.ObjectID IN (-6, -7) AND
					--	NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO WHERE SRO.[InstanceID] = @InstanceID AND SRO.[SecurityRoleID] = @FullAccessRoleID AND SRO.[ObjectID] = O.[ObjectID])

					--SELECT @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Return information'
		IF @DebugBM & 1 > 0 
			BEGIN
				SELECT [@AssignedUserID] = @AssignedUserID
				SELECT [Table] = 'pcINTEGRATOR_Data..User', * FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE InstanceID IN (@InstanceID, @InstanceID_User) OR [UserName] = @Email ORDER BY [UserName]
				SELECT [Table] = 'pcINTEGRATOR_Data..UserPropertyValue', * FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] WHERE InstanceID IN (@InstanceID, @InstanceID_User)
				SELECT [Table] = 'pcINTEGRATOR..SecurityRole', * FROM [pcINTEGRATOR].[dbo].[SecurityRole] WHERE InstanceID IN (0, @InstanceID)
				SELECT [Table] = 'pcINTEGRATOR_Data..SecurityRoleUser', * FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] WHERE InstanceID = @InstanceID	
				SELECT [Table] = 'pcINTEGRATOR_Data..SecurityRoleObject', * FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] WHERE InstanceID = @InstanceID
				SELECT [Table] = 'pcINTEGRATOR_Data..Object', * FROM [pcINTEGRATOR_Data].[dbo].[Object] WHERE InstanceID = @InstanceID
			END
	
	SET @Step = 'Drop temp tables'
		DROP TABLE #CallistoUsers
		DROP TABLE #CallistoActionsAccess
		DROP TABLE #SourceUsers

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
