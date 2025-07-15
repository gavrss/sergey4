SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCopy_Instance_Version]
	@UserID int = NULL,
	@InstanceID int = NULL, 
	@VersionID int = NULL, 

	@FromInstanceID int = NULL,
	@FromVersionID int = NULL,
	@ToInstanceID int = NULL,
	@ToVersionID int = NULL,

	@ToDomainName varchar (100) =  '',
	@FromDomainName varchar (100) =  '',
	@SourceDatabase nvarchar(100) = '[pcINTEGRATOR_Data]',

	@DemoYN bit = 1,
	@CopyType nvarchar(10) = NULL,
	@TruncateYN bit = 1,
	@InsertYN bit = 1,
	
	@UpdateETLSourceDBYN bit = 0,
	@ETLSourceDB nvarchar(255) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000361,
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
EXEC [spCopy_Instance_Version] 
	@UserID = -10, 
	@InstanceID = 0, 
	@VersionID = 0, 
	@FromInstanceID = 621, 
	@FromVersionID = 1105, 
	@ToInstanceID = 920, 
	@ToVersionID = 1325, 
	@FromDomainName = 'live',  
	@ToDomainName = 'live', 
	@DemoYN = 0, 
	@Debug = 1

EXEC [spCopy_Instance_Version] @UserID = -10, @InstanceID = 0, @VersionID = 0, @FromInstanceID = 576, @FromVersionID = 1082, @ToInstanceID = 765, @ToVersionID = 1188, 
@FromDomainName = 'live',  @ToDomainName = 'live', @DemoYN = 0, @DebugBM = 15


EXEC [spCopy_Instance_Version] @UserID = -10, @InstanceID = 0, @VersionID = 0, @FromInstanceID = -1590, @FromVersionID = -1590, @ToInstanceID = -1728, @ToVersionID = -1728,
@FromDomainName = 'demo',  @ToDomainName = 'demo', @DemoYN = 1, @UpdateETLSourceDBYN = 1, @ETLSourceDB = NULL, @DebugBM = 15

EXEC [spCopy_Instance_Version] @UserID = -10, @InstanceID = 0, @VersionID = 0, 
@FromInstanceID = -1318, @FromVersionID = -1256, 
@ToInstanceID = -1590, @ToVersionID = -1590, @FromDomainName = 'live',  @ToDomainName = 'live', 
@DemoYN = 1, @InsertYN = 1, @TruncateYN=1, @DebugBM = 15

EXEC [spCopy_Instance_Version] 	
	@UserID = -10, 
	@FromInstanceID = -1405, 
	@FromVersionID = -1405, 
	@ToInstanceID = -1317, 
	@ToVersionID = -1255, 
	@ToDomainName = 'live',
	@FromDomainName = 'demo',
	@SourceDatabase = 'EFPDEMO01.pcINTEGRATOR_Data',
	@DemoYN = 1,
	@CopyType = 'Instance',
	@TruncateYN = 1,
	@InsertYN = 1,
	@Debug = 1

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor
		
		CLOSE Insert_Cursor
		DEALLOCATE Insert_Cursor
	
EXEC [spCopy_Instance_Version] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	@TableName NVARCHAR(100),
	@SQLStatement NVARCHAR(MAX),
	@SQL_Insert NVARCHAR(MAX),
	@SQL_Select NVARCHAR(MAX),
	@SQL_From NVARCHAR(MAX),
	@SQL_Where NVARCHAR(MAX),
	@SQL_NotExists NVARCHAR(MAX),
	@VersionIDYN BIT,
	@RowCounter INT,
	@IdentityYN BIT,
	@ToApplicationID INT,
	@DeletedIDYN BIT,
	@FromApplicationName NVARCHAR(100),
	@ToApplicationName NVARCHAR(100),

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
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Copy selected InstanceID/VersionID to new InstanceID/VersionID',
			@MandatoryParameter = 'ToInstanceID|ToVersionID' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Copy Instance between servers.'
		IF @Version = '2.0.2.2145' SET @Description = 'Modified Insert statements to include NOT EXISTS. Added dependencies on table [DataObject_ColumnJoin].'
		IF @Version = '2.0.2.2146' SET @Description = 'Modified setting of @CopyType variable. Handled DeletedID column for #Inherited temp table. Added step to Update tables with dependencies on other tables and itself. Added special handling for SecurityRoleObject table.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-139: Modified Insert statements for tables with Inherited columns [UserID] and [ObjectID]. DB-143: Added parameters @FromInstanceID and @From VersionID.'
		IF @Version = '2.0.2.2150' SET @Description = 'DB-247: Modified the INSERT statements to [User] and [User_Instance] tables.'
		IF @Version = '2.0.3.2152' SET @Description = 'Modified the INSERT statements to [User] and [*User]-related tables. Distinguish INNER or LEFT JOIN depending on Nullable InheretedFrom column, set as [#Inherited].[NulableYN]. Insert into #Columns all existing columns on both @SourceDatabase and destination database.'
		IF @Version = '2.0.3.2153' SET @Description = 'Modified query for copying [UserMember].'
		IF @Version = '2.0.3.2154' SET @Description = 'Modified dynamic query for copying [BR%] tables. DB-423: Remove GUID. Modified query for copying [UserMember] within the same server. DB-444: Modified query for #User creation.'
		IF @Version = '2.1.0.2160' SET @Description = 'Added [LoadSP] column when inserting into [Dimension] table.'
		IF @Version = '2.1.0.2161' SET @Description = 'Removed [OrganizationPosition_DataClass] from list of Tables to be special handled.'
		IF @Version = '2.1.0.2162' SET @Description = 'DB-560: Added [BR00_Step], [BusinessRuleEvent] and [BusinessRuleEvent_Parameter] in the list of Tables to be special handled. Modified INSERT query for [OrganizationPosition_User] and [UserMember] to only include valid Users from source.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added in the list of Tables to be special handled: BR05_Rule_ICmatch,BR05_Rule_Consolidation,BR05_Rule_Consolidation_Row,BR05_Rule_FX,BR05_Rule_FX_Row.'
		IF @Version = '2.1.2.2198' SET @Description = 'Added in the list of Tables to be special handled: BR03_Rule_Allocation, BR15_Component, BR15_ComponentTier.'
		IF @Version = '2.1.2.2199' SET @Description = 'FEA-9286: Deallocate Delete Cursor if existing. FDB-1842: Added parameters @UpdateETLSourceDBYN and @ETLSourceDB. Added in the list of Tables to be special handled: JobList,BR05_TranSpecFxRate,BR05_FormulaFX.'
	
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

		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ToApplicationID = ApplicationID,
			@ToApplicationName = ApplicationName
		FROM
			pcINTEGRATOR_Data.[dbo].[Application]
		WHERE
			InstanceID = @ToInstanceID AND
			VersionID = @ToVersionID
			
		SET @SQLStatement = '
			SELECT
				@FromApplicationName = LEFT(ApplicationName, 5)
			FROM
				' + @SourceDatabase + '.[dbo].[Application]
			WHERE
				InstanceID = ' + CONVERT(NVARCHAR(10), @FromInstanceID) + ' AND
				VersionID = ' + CONVERT(NVARCHAR(10), @FromVersionID) 

		EXEC sp_executesql @SQLStatement, N'@FromApplicationName nvarchar(100) OUT', @FromApplicationName = @FromApplicationName OUT
		
		SELECT @CopyType = ISNULL(@CopyType, CASE WHEN @ToInstanceID = @FromInstanceID AND CHARINDEX('.', @SourceDatabase) = 0 THEN 'Version' ELSE 'Instance' END)

		IF @Debug <> 0 SELECT [@ToApplicationID] = @ToApplicationID, [@ToApplicationName] = @ToApplicationName, [@FromApplicationName] = @FromApplicationName, [@CopyType] = @CopyType, [@ToInstanceID] = @ToInstanceID, [@ToVersionID] = @ToVersionID, [@FromDomainName] = @FromDomainName, [@ToDomainName] = @ToDomainName

	SET @Step = 'Set trigger inactive'
		UPDATE pcINTEGRATOR_Data.[dbo].Instance
		SET
			TriggerActiveYN = 0
		WHERE
			InstanceID = @ToInstanceID

	SET @Step = 'Create temp tables'
		CREATE TABLE #CursorTable
			(
			[TableName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[IdentityYN] BIT,
			[VersionIDYN] BIT,
			[SortOrder] INT
			)

		CREATE TABLE #Column
			(
			[ColumnName] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[SortOrder] INT,
            [PrimaryKeyYN] BIT
			)

		CREATE TABLE #RowCounter
			(
			RowCounter INT
			)

		CREATE TABLE #Inherited
			(
			[InheritedTable] nvarchar(100),
			[ColumnName] nvarchar(100),
			[DefaultValue] nvarchar(100),
			[SourceColumnName] nvarchar(100),
			[ShortName] nvarchar(100),
			[SortOrder] int,
			[DeletedIDYN] bit,
			[NullableYN] bit
			)

		CREATE TABLE #User
			(
			[FromUserID] int,
			[ToUserID] int,
			[UserName] nvarchar(100),
			[ExpiryDate] date
			)

	SET @Step = 'Fill #CursorTable'
		INSERT INTO #CursorTable
			(
			[TableName],
			[IdentityYN],
			[VersionIDYN],
			[SortOrder]
			)
		SELECT 
			[TableName] = DataObjectName,
			[IdentityYN],
			[VersionIDYN],
			[SortOrder]
		FROM
			[DataObject]
		WHERE
			[ObjectType] = 'Table' AND
			[DatabaseName] = 'pcINTEGRATOR_Data' AND
			[SelectYN] <> 0 AND
			[DeletedYN] = 0 AND
			[InstanceIDYN] <> 0 AND
			([VersionIDYN] <> 0 OR @CopyType = 'Instance') AND
			[DataObjectName] NOT IN ('Customer', 'Instance', 'Version', 'Application')
		ORDER BY
			[SortOrder] DESC

		IF @Debug <> 0 SELECT TempTable = '#CursorTable', * FROM #CursorTable ORDER BY [SortOrder] DESC

	SET @Step = 'Create Delete_Cursor'
		IF @TruncateYN <> 0
			BEGIN
				IF CURSOR_STATUS('global','Delete_Cursor') >= -1 DEALLOCATE Delete_Cursor
				DECLARE Delete_Cursor CURSOR FOR
					SELECT 
						[TableName],
						[VersionIDYN]
					FROM
						#CursorTable
					WHERE
						[VersionIDYN] <> 0 OR @CopyType = 'Instance'
					ORDER BY
						[SortOrder]

					OPEN Delete_Cursor
					FETCH NEXT FROM Delete_Cursor INTO @TableName, @VersionIDYN

					WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @SQLStatement = '
								DELETE [pcINTEGRATOR_Data].[dbo].[' + @TableName + ']
								WHERE
									[InstanceID] = ' + CONVERT(nvarchar(10), @ToInstanceID) + '
									' + CASE WHEN @VersionIDYN <> 0 THEN 'AND [VersionID] = ' + CONVERT(nvarchar(10), @ToVersionID) ELSE '' END

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Deleted = @Deleted + @@ROWCOUNT

							FETCH NEXT FROM Delete_Cursor INTO @TableName, @VersionIDYN
						END

				CLOSE Delete_Cursor
				DEALLOCATE Delete_Cursor
			END

	SET @Step = 'Create Insert_Cursor'
		IF @InsertYN <> 0
		BEGIN
		IF CURSOR_STATUS('global','Insert_Cursor') >= -1 DEALLOCATE Insert_Cursor
		DECLARE Insert_Cursor CURSOR FOR
			SELECT 
				[TableName],
				[IdentityYN],
				[VersionIDYN]
			FROM
				#CursorTable
			ORDER BY
				[SortOrder] DESC

			OPEN Insert_Cursor
			FETCH NEXT FROM Insert_Cursor INTO @TableName, @IdentityYN, @VersionIDYN

			WHILE @@FETCH_STATUS = 0
				BEGIN

				SET @Step = 'Tables special handled (' + @TableName + ')'
/**
TODO: 'UniqueIdentifier is (right now) excluded because UniqueIdentifier points to UserID on different InstanceID. This should be handled properly.
**/
					--IF @TableName IN ('User', 'UserMember', 'UserPropertyValue', 'UniqueIdentifier', 'EntityHierarchy', 'OrganizationPosition', 'Dimension','OrganizationPosition_DataClass')
					IF @TableName IN ('User', 'User_Instance', 'UserMember', 'UserPropertyValue', 'SecurityRoleUser', 'UniqueIdentifier', 'OrganizationPosition', 'Dimension', 'OrganizationPosition_User', 'BR00_Step', 'BusinessRuleEvent', 'BusinessRuleEvent_Parameter', 'BR05_Rule_ICmatch', 'BR05_Rule_Consolidation', 'BR05_Rule_Consolidation_Row','BR05_Rule_FX','BR05_Rule_FX_Row', 'BR03_Rule_Allocation','BR15_Component', 'BR15_ComponentTier', 'JobList','BR05_TranSpecFxRate','BR05_FormulaFX')

						BEGIN
							IF @CopyType = 'Instance'
								BEGIN	
									IF @TableName = 'JobList'
										BEGIN
											INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobList]
												(
												[InstanceID],
												[VersionID],
												[JobListName],
												[JobListDescription],
												[JobStepTypeBM],
												[JobFrequencyBM],
												[JobStepGroupBM],
												[ProcessBM],
												[JobSetupStepBM],
												[JobStep_List],
												[Entity_List],
												[DelayedStart],
												[UserID],
												[InheritedFrom],
												[SelectYN]
												)
											SELECT
												[InstanceID] = @ToInstanceID,
												[VersionID] = @ToVersionID,
												[JobListName] = [JobList].[JobListName],
												[JobListDescription] = [JobList].[JobListDescription],
												[JobStepTypeBM] = [JobList].[JobStepTypeBM],
												[JobFrequencyBM] = [JobList].[JobFrequencyBM],
												[JobStepGroupBM] = [JobList].[JobStepGroupBM],
												[ProcessBM] = [JobList].[ProcessBM],
												[JobSetupStepBM] = [JobList].[JobSetupStepBM],
												[JobStep_List] = [JobList].[JobStep_List],
												[Entity_List] = [JobList].[Entity_List],
												[DelayedStart] = [JobList].[DelayedStart],
												[UserID] = ISNULL([User].[UserID],[JobList].[UserID]),
												[InheritedFrom] = [JobList].[JobListID],
												[SelectYN] = [JobList].[SelectYN]
											FROM
												[pcINTEGRATOR_Data].[dbo].[JobList] [JobList]
												LEFT JOIN [pcINTEGRATOR].[dbo].[User] [User] ON [User].[InstanceID] IN (0, @ToInstanceID) AND [User].[InheritedFrom] = [JobList].[UserID] AND [User].[DeletedID] IS NULL
											WHERE
												[JobList].[InstanceID] = @FromInstanceID AND
												[JobList].[VersionID] = @FromVersionID

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'User'
										BEGIN
											SET @SQLStatement = '
												INSERT INTO #User
													(
													[FromUserID],
													[UserName],
													[ExpiryDate]
													)
												--SELECT
												--	[FromUserID] = U.UserID,
												--	[UserName] = U.UserName,
												--	[ExpiryDate] = NULL
												--FROM
												--	' + @SourceDatabase + '.[dbo].[User] U
												--WHERE
												--	U.[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
												--	U.[SelectYN] <> 0 AND
												--	U.[DeletedID] IS NULL
												--UNION
												SELECT
													[FromUserID] = U.UserID,
													[UserName] = U.UserName,
													[ExpiryDate] = UI.ExpiryDate
												FROM
													' + @SourceDatabase + '.[dbo].[User] U
													INNER JOIN ' + @SourceDatabase + '.[dbo].[User_Instance] UI ON UI.InstanceID = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND UI.UserID = U.UserID AND UI.[SelectYN] <> 0 AND UI.[DeletedID] IS NULL
												WHERE
													U.[SelectYN] <> 0 AND
													U.[DeletedID] IS NULL'

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											UPDATE U
											SET 
												[ToUserID] = DU.UserID
											FROM
												#User U
												INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] DU ON DU.UserName = U.UserName

											SET @SQLStatement = '
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
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[UserName] = REPLACE([UserName], ''' + @FromApplicationName + ''', ''' + @ToApplicationName + '''),
													[UserNameAD] = REPLACE([UserNameAD], ''' + @FromDomainName + '\' + @FromApplicationName + ''', ''' + @ToDomainName + '\' + @ToApplicationName + '''),
													[UserNameDisplay] = REPLACE([UserNameDisplay], ''' + @FromApplicationName + ''', ''' + @ToApplicationName + '''),
													[UserTypeID],
													[UserLicenseTypeID],
													[LocaleID],
													[LanguageID],
													[ObjectGuiBehaviorBM],
													[InheritedFrom] = [UserID]
												FROM
													' + @SourceDatabase + '.[dbo].[User] U
												WHERE
													([UserName] LIKE ''%' + @FromApplicationName + '%'' OR [UserNameAD] LIKE ''' + @FromDomainName + '\' + @FromApplicationName + '%'') AND
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[SelectYN] <> 0 AND
													[DeletedID] IS NULL AND
													NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] D WHERE D.UserName = REPLACE(U.[UserName], ''' + @FromApplicationName + ''', ''' + @ToApplicationName + ''') AND D.DeletedID IS NULL)'

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'User_Instance'
										BEGIN
											INSERT INTO [pcINTEGRATOR_Data].[dbo].[User_Instance]
												(
												[InstanceID],
												[UserID],
												[ExpiryDate],
												[Inserted],
												[InsertedBy],
												[SelectYN]
												)
											SELECT
												[InstanceID] = @ToInstanceID,
												[UserID] = UU.[ToUserID],
												[ExpiryDate] = UU.ExpiryDate,
												[Inserted] = GETDATE(),
												[InsertedBy] = @UserID,
												[SelectYN] = 1
											FROM
												[#User] UU
											WHERE
												UU.ToUserID IS NOT NULL AND 
												NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] UI WHERE UI.InstanceID = @ToInstanceID AND UI.UserID = UU.ToUserID)
												
											SET @Inserted = @Inserted + @@ROWCOUNT

											UPDATE UI
											SET 
												DeletedID = NULL
											FROM
												[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
												INNER JOIN #User U ON U.ToUserID = UI.UserID
											WHERE
												UI.InstanceID = @ToInstanceID 

											SET @Updated = @Updated + @@ROWCOUNT
										END

									IF @TableName = 'UserMember'
										BEGIN
											--SET @SQLStatement = '
											--	INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
											--		(
											--		[InstanceID],
											--		[UserID_Group],
											--		[UserID_User]
											--		)
											--	SELECT
											--		[InstanceID] = ' + CONVERT(NVARCHAR(10), @ToInstanceID) + ',
											--		[UserID_Group] = [UserG].[UserID],
											--		[UserID_User] = [UserU].[UserID]
											--	FROM
											--		' + @SourceDatabase + '.[dbo].[UserMember] [UserMember]
											--		INNER JOIN ' + @SourceDatabase + '.[dbo].[User] [UserSG] ON [UserSG].[UserID] = [UserMember].[UserID_Group]
											--		INNER JOIN ' + @SourceDatabase + '.[dbo].[User] [UserSU] ON [UserSU].[UserID] = [UserMember].[UserID_User]
											--		INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] [UserG] ON [UserG].[UserName] = [UserSG].[UserName]
											--		INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] [UserU] ON [UserU].[UserName] = [UserSU].[UserName]
											--	WHERE
											--		[UserMember].[InstanceID] =  ' + CONVERT(NVARCHAR(10), @FromInstanceID) + ' AND
											--		[UserMember].[SelectYN] <> 0'

											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
													(
													[InstanceID],
													[UserID_Group],
													[UserID_User]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[UserID_Group] = [UserG].[UserID],
													[UserID_User] = ISNULL([UserU].[UserID], TU.ToUserID)
												FROM
													' + @SourceDatabase + '.[dbo].[UserMember] [UserMember]
													INNER JOIN ' + @SourceDatabase + '.[dbo].[User] [UserSG] ON [UserSG].[UserID] = [UserMember].[UserID_Group] AND [UserSG].DeletedID IS NULL
													INNER JOIN ' + @SourceDatabase + '.[dbo].[User] [UserSU] ON [UserSU].[UserID] = [UserMember].[UserID_User] AND [UserSU].DeletedID IS NULL
													INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] [UserG] ON [UserG].[InstanceID] =  ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ' AND [UserG].[InheritedFrom] = [UserMember].[UserID_Group]
													LEFT JOIN [pcINTEGRATOR_Data].[dbo].[User] [UserU] ON [UserU].[InstanceID] =  ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ' AND [UserU].[InheritedFrom] = [UserMember].[UserID_User]
													LEFT JOIN #User TU ON TU.FromUserID = [UserMember].[UserID_User]
												WHERE
													[UserMember].[InstanceID] =  ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[UserMember].[SelectYN] <> 0'

											IF @Debug <> 0 PRINT @SQLStatement
											--EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END
                                        
									IF @TableName = 'UserPropertyValue'
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
													(
													[InstanceID],
													[UserID],
													[UserPropertyTypeID],
													[UserPropertyValue],
													[SelectYN]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[UserID] = ISNULL([User].[UserID], [UserPropertyValue].[UserID]),
													[UserPropertyTypeID] = [UserPropertyValue].[UserPropertyTypeID],
													[UserPropertyValue] = [UserPropertyValue].[UserPropertyValue],
													[SelectYN] = [UserPropertyValue].[SelectYN]
												FROM
													' + @SourceDatabase + '.[dbo].[UserPropertyValue] [UserPropertyValue]
													INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] [User] ON [User].[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ' AND [User].[InheritedFrom] = [UserPropertyValue].[UserID]
												WHERE
													[UserPropertyValue].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID)
											
											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'SecurityRoleUser'
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
													(
													[InstanceID],
													[SecurityRoleID],
													[UserID]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[SecurityRoleID] = [SecurityRole].[SecurityRoleID],
													[UserID] = ISNULL([User].[UserID], TU.ToUserID)
												FROM
													' + @SourceDatabase + '.[dbo].[SecurityRoleUser] [SecurityRoleUser]
													INNER JOIN [pcINTEGRATOR].[dbo].[SecurityRole] [SecurityRole] ON [SecurityRole].[InstanceID] IN (0,  ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [SecurityRole].[InheritedFrom] = [SecurityRoleUser].[SecurityRoleID]
													INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] [User] ON [User].[InstanceID] =  ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ' AND [User].[InheritedFrom] = [SecurityRoleUser].[UserID]
													LEFT JOIN #User TU ON TU.FromUserID = [SecurityRoleUser].[UserID]
												WHERE
													[SecurityRoleUser].[InstanceID] =  ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[SecurityRoleUser].[SelectYN] <> 0'

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END
/*
									IF @TableName = 'EntityHierarchy'
										BEGIN
											SET @SQLStatement = '
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
													[ConsolidationMethodID],
													[SortOrder]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(10), @ToInstanceID) + ',
													[VersionID] = ' + CONVERT(NVARCHAR(10), @ToVersionID) + ',
													[EntityGroupID] =  ISNULL([EntityGroup].[EntityID], [EntityHierarchy].[EntityGroupID]),
													[EntityID] = ISNULL([Entity].[EntityID], [EntityHierarchy].[EntityID]),
													[ParentID] = ISNULL([Parent].[EntityID], [EntityHierarchy].[ParentID]),
													[ValidFrom] = [EntityHierarchy].[ValidFrom],
													[OwnershipDirect] = [EntityHierarchy].[OwnershipDirect],
													[OwnershipUltimate] = [EntityHierarchy].[OwnershipUltimate],
													[OwnershipConsolidation] = [EntityHierarchy].[OwnershipConsolidation],
													[ConsolidationMethodID] = [EntityHierarchy].[ConsolidationMethodID],
													[SortOrder] = [EntityHierarchy].[SortOrder]
												FROM
													' + @SourceDatabase + '.[dbo].[EntityHierarchy] [EntityHierarchy]
													LEFT JOIN [pcINTEGRATOR_Data].[dbo].[Entity] [EntityGroup] ON [EntityGroup].[InstanceID] = ' + CONVERT(NVARCHAR(10), @ToInstanceID) + ' AND [EntityGroup].[InheritedFrom] = [EntityHierarchy].[EntityGroupID]
													LEFT JOIN [pcINTEGRATOR_Data].[dbo].[Entity] [Entity] ON [Entity].[InstanceID] = ' + CONVERT(NVARCHAR(10), @ToInstanceID) + ' AND [Entity].[InheritedFrom] = [EntityHierarchy].[EntityID]
													LEFT JOIN [pcINTEGRATOR_Data].[dbo].[Entity] [Parent] ON [Parent].[InstanceID] = ' + CONVERT(NVARCHAR(10), @ToInstanceID) + ' AND [Parent].[InheritedFrom] = [EntityHierarchy].[ParentID]
												WHERE
													[EntityHierarchy].[InstanceID] = ' + CONVERT(NVARCHAR(10), @FromInstanceID) + ' AND
													[EntityHierarchy].[VersionID] = ' + CONVERT(NVARCHAR(10), @FromVersionID)
											
											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END
*/
									IF @TableName = 'OrganizationPosition'	
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition]
													(
													[InstanceID],
													[VersionID],
													[OrganizationPositionName],
													[OrganizationPositionDescription],
													[OrganizationHierarchyID],
													[ParentOrganizationPositionID],
													[OrganizationLevelNo],
													[LinkedDimension_MemberKey],
													[InheritedFrom],
													[SortOrder]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
													[OrganizationPositionName] = [OrganizationPosition].[OrganizationPositionName],
													[OrganizationPositionDescription] = [OrganizationPosition].[OrganizationPositionDescription],
													[OrganizationHierarchyID] = ISNULL([OrganizationHierarchy].[OrganizationHierarchyID], [OrganizationPosition].[OrganizationHierarchyID]),
													[ParentOrganizationPositionID] = [OrganizationPosition].[ParentOrganizationPositionID],
													[OrganizationLevelNo] = [OrganizationPosition].[OrganizationLevelNo],
													[LinkedDimension_MemberKey] = [OrganizationPosition].[LinkedDimension_MemberKey],
													[InheritedFrom] = [OrganizationPosition].[OrganizationPositionID],
													[SortOrder] = [OrganizationPosition].[SortOrder]
												FROM
													' + @SourceDatabase + '.[dbo].[OrganizationPosition] [OrganizationPosition]
													LEFT JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy] [OrganizationHierarchy] ON [OrganizationHierarchy].[InstanceID] = ' + CONVERT(NVARCHAR(10), @ToInstanceID) + ' AND [OrganizationHierarchy].[InheritedFrom] = [OrganizationPosition].[OrganizationHierarchyID]
												WHERE
													[OrganizationPosition].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[OrganizationPosition].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID) + ' AND
													[OrganizationPosition].[DeletedID] IS NULL'

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT

											UPDATE OP
											SET
												[ParentOrganizationPositionID] = OPP.OrganizationPositionID
											FROM
												[pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OP
												INNER JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition] OPP ON OPP.InstanceID = OP.InstanceID AND OPP.VersionID = OP.VersionID AND OPP.InheritedFrom = OP.ParentOrganizationPositionID
											WHERE
												OP.InstanceID = @ToInstanceID AND 
												OP.VersionID = @ToVersionID

											SET @Updated = @Updated + @@ROWCOUNT

										END
									
									IF @TableName = 'OrganizationPosition_User'
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User]
													(
													[InstanceID],
													[VersionID],
													[OrganizationPositionID],
													[UserID],
													[DelegateYN],
													[Comment]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
													[OrganizationPositionID] = [OrganizationPosition].[OrganizationPositionID],
													[UserID] = COALESCE([User].[UserID], [TU].[ToUserID],[OrganizationPosition_User].[UserID]),
													[DelegateYN] = [OrganizationPosition_User].[DelegateYN],
													[Comment] = [OrganizationPosition_User].[Comment]
												FROM
													' + @SourceDatabase + '.[dbo].[OrganizationPosition_User] [OrganizationPosition_User]
													INNER JOIN [pcINTEGRATOR].[dbo].[OrganizationPosition] [OrganizationPosition] ON [OrganizationPosition].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [OrganizationPosition].[InheritedFrom] = [OrganizationPosition_User].[OrganizationPositionID] AND [OrganizationPosition].[DeletedID] IS NULL
													LEFT JOIN [pcINTEGRATOR].[dbo].[User] [User] ON [User].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [User].[InheritedFrom] = [OrganizationPosition_User].[UserID] AND [User].[DeletedID] IS NULL
													LEFT JOIN [#User] [TU] ON [TU].[FromUserID] = [OrganizationPosition_User].[UserID] AND [TU].ToUserID IS NOT NULL
													--INNER JOIN [#User] [TU] ON [TU].[FromUserID] = [OrganizationPosition_User].[UserID] AND [TU].ToUserID IS NOT NULL
												WHERE
													[OrganizationPosition_User].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[OrganizationPosition_User].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID) + ' AND
													[OrganizationPosition_User].[DeletedID] IS NULL AND 
													NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] [DestinationTable] WHERE [DestinationTable].OrganizationPositionID = ISNULL([OrganizationPosition].[OrganizationPositionID], [OrganizationPosition_User].[OrganizationPositionID]) AND [DestinationTable].UserID = COALESCE([User].[UserID], [TU].[ToUserID],[OrganizationPosition_User].[UserID]))'

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'Dimension'	
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
													(
													[InstanceID],
													[DimensionName],
													[DimensionDescription],
													[DimensionTypeID],
													[ObjectGuiBehaviorBM],
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
													[SelectYN],
													[LoadSP]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[DimensionName] = [Dimension].[DimensionName],
													[DimensionDescription] = [Dimension].[DimensionDescription],
													[DimensionTypeID] = [Dimension].[DimensionTypeID],
													[ObjectGuiBehaviorBM] = [Dimension].[ObjectGuiBehaviorBM],
													[GenericYN] = [Dimension].[GenericYN],
													[MultipleProcedureYN] = [Dimension].[MultipleProcedureYN],
													[AllYN] = [Dimension].[AllYN],
													[HiddenMember] = [Dimension].[HiddenMember],
													[Hierarchy] = [Dimension].[Hierarchy],
													[TranslationYN] = [Dimension].[TranslationYN],
													[DefaultSelectYN] = [Dimension].[DefaultSelectYN],
													[DefaultValue] = [Dimension].[DefaultValue],
													[DeleteJoinYN] = [Dimension].[DeleteJoinYN],
													[SourceTypeBM] = [Dimension].[SourceTypeBM],
													[MasterDimensionID] = [Dimension].[MasterDimensionID],
													[HierarchyMasterDimensionID] = [Dimension].[HierarchyMasterDimensionID],
													[InheritedFrom] = [Dimension].[DimensionID],
													[SeedMemberID] = [Dimension].[SeedMemberID],
													[ModelingStatusID] = [Dimension].[ModelingStatusID],
													[ModelingComment] = [Dimension].[ModelingComment],
													[Introduced] = [Dimension].[Introduced],
													[SelectYN] = [Dimension].[SelectYN],
													[LoadSP] = [Dimension].[LoadSP]
												FROM
													' + @SourceDatabase + '.[dbo].[Dimension] [Dimension]
												WHERE
													[Dimension].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[Dimension].[DeletedID] IS NULL'

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR00_Step'	
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR00_Step]
													(
													[Comment],
													[InstanceID],
													[VersionID],
													[BusinessRuleID],
													[BusinessRule_SubID],
													[SortOrder],
													[SelectYN]
													)
												SELECT
													[Comment] = [BR00_Step].[Comment],
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
													[BusinessRuleID] = [BusinessRule].[BusinessRuleID],
													[BusinessRule_SubID] = [BR].[BusinessRuleID],
													[SortOrder] = [BR00_Step].[SortOrder],
													[SelectYN] = [BR00_Step].[SelectYN]
												FROM
													' + @SourceDatabase + '.[dbo].[BR00_Step] [BR00_Step]
													INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BusinessRule].[InheritedFrom] = [BR00_Step].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
													INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BR] ON [BR].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BR].[InheritedFrom] = [BR00_Step].[BusinessRule_SubID] AND [BR].[DeletedID] IS NULL
												WHERE

													[BR00_Step].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[BR00_Step].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BusinessRuleEvent'	
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent]
													(
													[InstanceID],
													[VersionID],
													[BusinessRuleID],
													[EventTypeID],
													[SortOrder],
													[SelectYN]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
													[BusinessRuleID] = [BusinessRule].[BusinessRuleID],
													[EventTypeID] = ISNULL([ET_Dest].[EventTypeID], [ET_Def].[EventTypeID]),
													[SortOrder] = [BusinessRuleEvent].[SortOrder],
													[SelectYN] = [BusinessRuleEvent].[SelectYN]
												FROM
													' + @SourceDatabase + '.[dbo].[BusinessRuleEvent] [BusinessRuleEvent]
													LEFT JOIN ' + @SourceDatabase + '.[dbo].[EventType] [EventType] ON [EventType].EventTypeID = [BusinessRuleEvent].[EventTypeID]
													INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BusinessRule].[InheritedFrom] = [BusinessRuleEvent].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
													LEFT JOIN [pcINTEGRATOR_Data].[dbo].[EventType] [ET_Dest] ON [ET_Dest].[InstanceID] = [BusinessRule].[InstanceID] AND [ET_Dest].[EventTypeName] = [EventType].[EventTypeName]
													LEFT JOIN [pcINTEGRATOR].[dbo].[EventType] [ET_Def] ON [ET_Def].[InstanceID] = 0 AND [ET_Def].EventTypeID = [BusinessRuleEvent].[EventTypeID] 
												WHERE
													[BusinessRuleEvent].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[BusinessRuleEvent].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID) + ' AND
													[BusinessRuleEvent].[DeletedID] IS NULL'

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BusinessRuleEvent_Parameter'	
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent_Parameter]
													(
													[InstanceID],
													[VersionID],
													[BusinessRuleEventID],
													[ParameterName],
													[ParameterValue]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
													[BusinessRuleEventID] = [BRE_Dest].[BusinessRuleEventID],
													[ParameterName] = [BusinessRuleEvent_Parameter].[ParameterName],
													[ParameterValue] = [BusinessRuleEvent_Parameter].[ParameterValue]
												FROM
													' + @SourceDatabase + '.[dbo].[BusinessRuleEvent_Parameter] [BusinessRuleEvent_Parameter]
													INNER JOIN ' + @SourceDatabase + '.[dbo].[BusinessRuleEvent] [BusinessRuleEvent] ON [BusinessRuleEvent].[InstanceID] = [BusinessRuleEvent_Parameter].[InstanceID] AND [BusinessRuleEvent].[VersionID] = [BusinessRuleEvent_Parameter].[VersionID] AND [BusinessRuleEvent].[BusinessRuleEventID] = [BusinessRuleEvent_Parameter].[BusinessRuleEventID] AND [BusinessRuleEvent].[DeletedID] IS NULL
													LEFT JOIN ' + @SourceDatabase + '.[dbo].[EventType] [ET_Src] ON [ET_Src].[InstanceID] = [BusinessRuleEvent].[InstanceID] AND [ET_Src].[EventTypeID] = [BusinessRuleEvent].[EventTypeID]
													LEFT JOIN [pcINTEGRATOR].[dbo].[EventType] [ET_Def] ON [ET_Def].[InstanceID] = 0 AND [ET_Def].[EventTypeID] = [BusinessRuleEvent].[EventTypeID]
													INNER JOIN [pcINTEGRATOR].[dbo].[EventType] [ET_Dest] ON [ET_Dest].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND ([ET_Dest].[EventTypeName] = [ET_Src].[EventTypeName] OR [ET_Dest].[EventTypeName] = [ET_Def].[EventTypeName])
													INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ' AND [BusinessRule].[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ' AND [BusinessRule].[InheritedFrom] = [BusinessRuleEvent].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
													INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent] [BRE_Dest] ON [BRE_Dest].[InstanceID] = [BusinessRule].[InstanceID] AND [BRE_Dest].[VersionID] = [BusinessRule].[VersionID] AND [BRE_Dest].[EventTypeID] = [ET_Dest].[EventTypeID] AND [BRE_Dest].[BusinessRuleID] = [BusinessRule].[BusinessRuleID] AND [BRE_Dest].[SortOrder] = [BusinessRuleEvent].[SortOrder]
												WHERE
													[BusinessRuleEvent_Parameter].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[BusinessRuleEvent_Parameter].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID) + ' AND 
													NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[BusinessRuleEvent_Parameter] [DestinationTable] WHERE [DestinationTable].[BusinessRuleEventID] = [BRE_Dest].[BusinessRuleEventID] AND [DestinationTable].ParameterName = [BusinessRuleEvent_Parameter].[ParameterName])'

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR05_Rule_ICmatch'	
										BEGIN
											SET @SQLStatement = '
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
													[Comment] = [BR05_Rule_ICmatch].[Comment],
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
													[Rule_ICmatchName] = [BR05_Rule_ICmatch].[Rule_ICmatchName],
													[DimensionFilter] = [BR05_Rule_ICmatch].[DimensionFilter],
													[AccountInterCoDiffManual] = [BR05_Rule_ICmatch].[AccountInterCoDiffManual],
													[AccountInterCoDiffAuto] = [BR05_Rule_ICmatch].[AccountInterCoDiffAuto],
													[Source] = [BR05_Rule_ICmatch].[Source],
													[SortOrder] = [BR05_Rule_ICmatch].[SortOrder],
													[InheritedFrom] = [BR05_Rule_ICmatch].[Rule_ICmatchID],
													[SelectYN] = [BR05_Rule_ICmatch].[SelectYN]
												FROM
													' + @SourceDatabase + '.[dbo].[BR05_Rule_ICmatch] [BR05_Rule_ICmatch]
												WHERE
													[BR05_Rule_ICmatch].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[BR05_Rule_ICmatch].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR05_TranSpecFxRate'	
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR05_TranSpecFxRate]
													(
													[InstanceID],
													[VersionID],
													[Entity],
													[Book],
													[FiscalYear],
													[FiscalPeriod],
													[JournalSequence],
													[JournalNo],
													[ConsolidationGroup],
													[TranSpecFxRate],
													[Inserted],
													[InsertedBy]
													)
												SELECT
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
													[Entity] = [BR05_TranSpecFxRate].[Entity],
													[Book] = [BR05_TranSpecFxRate].[Book],
													[FiscalYear] = [BR05_TranSpecFxRate].[FiscalYear],
													[FiscalPeriod] = [BR05_TranSpecFxRate].[FiscalPeriod],
													[JournalSequence] = [BR05_TranSpecFxRate].[JournalSequence],
													[JournalNo] = [BR05_TranSpecFxRate].[JournalNo],
													[ConsolidationGroup] = [BR05_TranSpecFxRate].[ConsolidationGroup],
													[TranSpecFxRate] = [BR05_TranSpecFxRate].[TranSpecFxRate],
													[Inserted] = [BR05_TranSpecFxRate].[Inserted],
													[InsertedBy] = [BR05_TranSpecFxRate].[InsertedBy]
												FROM
													' + @SourceDatabase + '.[dbo].[BR05_TranSpecFxRate] [BR05_TranSpecFxRate]
												WHERE
													[BR05_TranSpecFxRate].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[BR05_TranSpecFxRate].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR05_FormulaFX'	
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR05_FormulaFX]
													(
													[Comment],
													[InstanceID],
													[VersionID],
													[FormulaFXName],
													[FormulaFX]
													)
												SELECT
													[Comment] = [BR05_FormulaFX].[Comment],
													[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
													[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
													[FormulaFXName] = [BR05_FormulaFX].[FormulaFXName],
													[FormulaFX] = [BR05_FormulaFX].[FormulaFX]
												FROM
													' + @SourceDatabase + '.[dbo].[BR05_FormulaFX] [BR05_FormulaFX]
												WHERE
													[BR05_FormulaFX].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
													[BR05_FormulaFX].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR05_Rule_Consolidation'	
										BEGIN
											SET @SQLStatement = '
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
	[SelectYN]
	)
SELECT
	[Comment] = [BR05_Rule_Consolidation].[Comment],
	[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
	[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
	[BusinessRuleID] = [BusinessRule].[BusinessRuleID],
	[Rule_ConsolidationName] = [BR05_Rule_Consolidation].[Rule_ConsolidationName],
	[JournalSequence] = [BR05_Rule_Consolidation].[JournalSequence],
	[DimensionFilter] = [BR05_Rule_Consolidation].[DimensionFilter],
	[ConsolidationMethodBM] = [BR05_Rule_Consolidation].[ConsolidationMethodBM],
	[ModifierID] = [BR05_Rule_Consolidation].[ModifierID],
	[OnlyInterCompanyInGroupYN] = [BR05_Rule_Consolidation].[OnlyInterCompanyInGroupYN],
	[FunctionalCurrencyYN] = [BR05_Rule_Consolidation].[FunctionalCurrencyYN],
	[UsePreviousStepYN] = [BR05_Rule_Consolidation].[UsePreviousStepYN],
	[SortOrder] = [BR05_Rule_Consolidation].[SortOrder],
	[InheritedFrom] = [BR05_Rule_Consolidation].[Rule_ConsolidationID],
	[SelectYN] = [BR05_Rule_Consolidation].[SelectYN]
FROM
	' + @SourceDatabase + '.[dbo].[BR05_Rule_Consolidation] [BR05_Rule_Consolidation]
	INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BusinessRule].[InheritedFrom] = [BR05_Rule_Consolidation].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
WHERE
	[BR05_Rule_Consolidation].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
	[BR05_Rule_Consolidation].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR05_Rule_Consolidation_Row'	
										BEGIN
											SET @SQLStatement = '
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
	[Comment] = [BR05_Rule_Consolidation_Row].[Comment],
	[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
	[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
	[BusinessRuleID] = [BusinessRule].[BusinessRuleID],
	[Rule_ConsolidationID] = [BR05_Rule_Consolidation_Dest].[Rule_ConsolidationID],
	[Rule_Consolidation_RowID] = [BR05_Rule_Consolidation_Row].[Rule_Consolidation_RowID],
	[DestinationEntity] = [BR05_Rule_Consolidation_Row].[DestinationEntity],
	[Account] = [BR05_Rule_Consolidation_Row].[Account],
	[Flow] = [BR05_Rule_Consolidation_Row].[Flow],
	[Sign] = [BR05_Rule_Consolidation_Row].[Sign],
	[FormulaAmountID] = [BR05_Rule_Consolidation_Row].[FormulaAmountID],
	[InheritedFrom] = [BR05_Rule_Consolidation_Row].[Rule_Consolidation_RowID],
	[SelectYN] = [BR05_Rule_Consolidation_Row].[SelectYN],
	[NaturalAccountOnlyYN] = [BR05_Rule_Consolidation_Row].[NaturalAccountOnlyYN],
	[SortOrder] = [BR05_Rule_Consolidation_Row].[SortOrder]
FROM
	' + @SourceDatabase + '.[dbo].[BR05_Rule_Consolidation_Row] [BR05_Rule_Consolidation_Row]
	INNER JOIN ' + @SourceDatabase + '.[dbo].[BR05_Rule_Consolidation] [BR05_Rule_Consolidation] 
		ON [BR05_Rule_Consolidation].[InstanceID] = [BR05_Rule_Consolidation_Row].[InstanceID] 
		AND [BR05_Rule_Consolidation].[VersionID] = [BR05_Rule_Consolidation_Row].[VersionID] 
		AND [BR05_Rule_Consolidation].[Rule_ConsolidationID] = [BR05_Rule_Consolidation_Row].[Rule_ConsolidationID] 
	INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BusinessRule].[InheritedFrom] = [BR05_Rule_Consolidation_Row].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
	INNER JOIN [pcINTEGRATOR_Data].[dbo].[BR05_Rule_Consolidation] [BR05_Rule_Consolidation_Dest] 
		ON [BR05_Rule_Consolidation_Dest].[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ' AND [BR05_Rule_Consolidation_Dest].[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + '
		AND [BR05_Rule_Consolidation_Dest].[InheritedFrom] = [BR05_Rule_Consolidation].[Rule_ConsolidationID]
WHERE
	[BR05_Rule_Consolidation_Row].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
	[BR05_Rule_Consolidation_Row].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR05_Rule_FX'	
										BEGIN
											SET @SQLStatement = '
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
	[Comment] = [BR05_Rule_FX].[Comment],
	[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
	[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
	[BusinessRuleID] = [BusinessRule].[BusinessRuleID],
	[Rule_FXName] = [BR05_Rule_FX].[Rule_FXName],
	[JournalSequence] = [BR05_Rule_FX].[JournalSequence],
	[DimensionFilter] = [BR05_Rule_FX].[DimensionFilter],
	[SortOrder] = [BR05_Rule_FX].[SortOrder],
	[InheritedFrom] = [BR05_Rule_FX].[Rule_FXID],
	[SelectYN] = [BR05_Rule_FX].[SelectYN]
FROM
	' + @SourceDatabase + '.[dbo].[BR05_Rule_FX] [BR05_Rule_FX]
	INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BusinessRule].[InheritedFrom] = [BR05_Rule_FX].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
WHERE
	[BR05_Rule_FX].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
	[BR05_Rule_FX].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR05_Rule_FX_Row'	
										BEGIN
											SET @SQLStatement = '
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
	[Comment] = [BR05_Rule_FX_Row].[Comment],
	[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
	[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
	[BusinessRuleID] = [BusinessRule].[BusinessRuleID],
	[Rule_FXID] = [BR05_Rule_FX_Dest].[Rule_FXID],
	[Rule_FX_RowID] = [BR05_Rule_FX_Row].[Rule_FX_RowID],
	[FlowFilter] = [BR05_Rule_FX_Row].[FlowFilter],
	[Modifier] = [BR05_Rule_FX_Row].[Modifier],
	[ResultValueFilter] = [BR05_Rule_FX_Row].[ResultValueFilter],
	[Sign] = [BR05_Rule_FX_Row].[Sign],
	[FormulaFXID] = [BR05_Rule_FX_Row].[FormulaFXID],
	[Account] = [BR05_Rule_FX_Row].[Account],
	[Flow] = [BR05_Rule_FX_Row].[Flow],
	[InheritedFrom] = [BR05_Rule_FX_Row].[Rule_FX_RowID],
	[SelectYN] = [BR05_Rule_FX_Row].[SelectYN],
	[NaturalAccountOnlyYN] = [BR05_Rule_FX_Row].[NaturalAccountOnlyYN],
	[SortOrder] = [BR05_Rule_FX_Row].[SortOrder]
FROM
	' + @SourceDatabase + '.[dbo].[BR05_Rule_FX_Row] [BR05_Rule_FX_Row]
	INNER JOIN ' + @SourceDatabase + '.[dbo].[BR05_Rule_FX] [BR05_Rule_FX]
		ON [BR05_Rule_FX].[InstanceID] = [BR05_Rule_FX_Row].[InstanceID]
		AND [BR05_Rule_FX].[VersionID] = [BR05_Rule_FX_Row].[VersionID]
		AND [BR05_Rule_FX].[Rule_FXID] = [BR05_Rule_FX_Row].[Rule_FXID]
	INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BusinessRule].[InheritedFrom] = [BR05_Rule_FX_Row].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
	INNER JOIN [pcINTEGRATOR_Data].[dbo].[BR05_Rule_FX] [BR05_Rule_FX_Dest] 
		ON [BR05_Rule_FX_Dest].[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + '
		AND [BR05_Rule_FX_Dest].[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + '
		AND [BR05_Rule_FX_Dest].[InheritedFrom] = [BR05_Rule_FX_Row].[Rule_FXID]
WHERE
	[BR05_Rule_FX_Row].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
	[BR05_Rule_FX_Row].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR03_Rule_Allocation'	
										BEGIN
											SET @SQLStatement = '
INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR03_Rule_Allocation]
	(
	[Comment],
	[InstanceID],
	[VersionID],
	[BusinessRuleID],
	[Rule_AllocationName],
	[JournalSequence],
	[Source_DataClassID],
	[Source_DimensionFilter],
	[Across_DataClassID],
	[Across_Member],
	[Across_WithinDim],
	[Across_Basis],
	[ModifierID],
	[Parameter],
	[StartTime],
	[EndTime],
	[SortOrder],
	[InheritedFrom],
	[SelectYN]
	)
SELECT
	[Comment] = [BR03_Rule_Allocation].[Comment],
	[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
	[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
	[BusinessRuleID] = [BusinessRule].[BusinessRuleID],
	[Rule_AllocationName] = [BR03_Rule_Allocation].[Rule_AllocationName],
	[JournalSequence] = [BR03_Rule_Allocation].[JournalSequence],
	[Source_DataClassID] = [Source_DataClass].[DataClassID],
	[Source_DimensionFilter] = [BR03_Rule_Allocation].[Source_DimensionFilter],
	[Across_DataClassID] = [Across_DataClass].[DataClassID],
	[Across_Member] = [BR03_Rule_Allocation].[Across_Member],
	[Across_WithinDim] = [BR03_Rule_Allocation].[Across_WithinDim],
	[Across_Basis] = [BR03_Rule_Allocation].[Across_Basis],
	[ModifierID] = [BR03_Rule_Allocation].[ModifierID],
	[Parameter] = [BR03_Rule_Allocation].[Parameter],
	[StartTime] = [BR03_Rule_Allocation].[StartTime],
	[EndTime] = [BR03_Rule_Allocation].[EndTime],
	[SortOrder] = [BR03_Rule_Allocation].[SortOrder],
	[InheritedFrom] = [BR03_Rule_Allocation].[BusinessRuleID],
	[SelectYN] = [BR03_Rule_Allocation].[SelectYN]
FROM
	' + @SourceDatabase + '.[dbo].[BR03_Rule_Allocation] [BR03_Rule_Allocation]
	INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BusinessRule].[InheritedFrom] = [BR03_Rule_Allocation].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
	LEFT JOIN ' + @SourceDatabase + '.[dbo].[DataClass] [Source_DC] ON [Source_DC].[InstanceID] = [BR03_Rule_Allocation].[InstanceID] AND [Source_DC].[VersionID] = [BR03_Rule_Allocation].[VersionID] AND [Source_DC].[DataClassID] = [BR03_Rule_Allocation].[Source_DataClassID] AND [Source_DC].[SelectYN] <> 0 AND [Source_DC].[DeletedID] IS NULL
	LEFT JOIN ' + @SourceDatabase + '.[dbo].[DataClass] [Across_DC] ON [Across_DC].[InstanceID] = [BR03_Rule_Allocation].[InstanceID] AND [Across_DC].[VersionID] = [BR03_Rule_Allocation].[VersionID] AND [Across_DC].[DataClassID] = [BR03_Rule_Allocation].[Across_DataClassID] AND [Across_DC].[SelectYN] <> 0 AND [Across_DC].[DeletedID] IS NULL
	LEFT JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] [Source_DataClass] ON [Source_DataClass].[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ' AND [Source_DataClass].[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ' AND [Source_DataClass].[InheritedFrom] = [BR03_Rule_Allocation].[Source_DataClassID]  
	LEFT JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] [Across_DataClass] ON [Across_DataClass].[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ' AND [Across_DataClass].[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ' AND [Across_DataClass].[InheritedFrom] = [BR03_Rule_Allocation].[Across_DataClassID]  
WHERE
	[BR03_Rule_Allocation].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
	[BR03_Rule_Allocation].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END									

									IF @TableName = 'BR15_Component'	
										BEGIN
											SET @SQLStatement = '
INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR15_Component]
	(
	[InstanceID],
	[VersionID],
	[BusinessRuleID],
	[ComponentName],
	[Comment],
	[UOMType],
	[TimeView],
	[ActualNumerator_MemberKey],
	[ActualNumerator_Value],
	[ActualDenominator_MemberKey],
	[ActualDenominator_Value],
	[BaseAmount_MemberKey],
	[BaseAmount_Value],
	[BaseAmountMin_MemberKey],
	[BaseAmountMin_Value],
	[SortOrder],
	[SelectYN],
	[InheritedFrom]
	)
SELECT
	[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
	[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
	[BusinessRuleID] = [BusinessRule].[BusinessRuleID],
	[ComponentName] = [BR15_Component].[ComponentName],
	[Comment] = [BR15_Component].[Comment],
	[UOMType] = [BR15_Component].[UOMType],
	[TimeView] = [BR15_Component].[TimeView],
	[ActualNumerator_MemberKey] = [BR15_Component].[ActualNumerator_MemberKey],
	[ActualNumerator_Value] = [BR15_Component].[ActualNumerator_Value],
	[ActualDenominator_MemberKey] = [BR15_Component].[ActualDenominator_MemberKey],
	[ActualDenominator_Value] = [BR15_Component].[ActualDenominator_Value],
	[BaseAmount_MemberKey] = [BR15_Component].[BaseAmount_MemberKey],
	[BaseAmount_Value] = [BR15_Component].[BaseAmount_Value],
	[BaseAmountMin_MemberKey] = [BR15_Component].[BaseAmountMin_MemberKey],
	[BaseAmountMin_Value] = [BR15_Component].[BaseAmountMin_Value],
	[SortOrder] = [BR15_Component].[SortOrder],
	[SelectYN] = [BR15_Component].[SelectYN],
	[InheritedFrom] = [BR15_Component].[ComponentID]
FROM
	' + @SourceDatabase + '.[dbo].[BR15_Component] [BR15_Component]
	INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BusinessRule].[InheritedFrom] = [BR15_Component].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
WHERE
	[BR15_Component].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
	[BR15_Component].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID) + ' AND
	[BR15_Component].[DeletedID] IS NULL'
	
												IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

									IF @TableName = 'BR15_ComponentTier'	
										BEGIN
											SET @SQLStatement = '
INSERT INTO [pcINTEGRATOR_Data].[dbo].[BR15_ComponentTier]
	(
	[InstanceID],
	[VersionID],
	[BusinessRuleID],
	[ComponentID],
	[From_MemberKey],
	[From_Value],
	[To_MemberKey],
	[To_Value],
	[Factor_MemberKey],
	[Factor_Value]
	)
SELECT
	[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ',
	[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ',
	[BusinessRuleID] = [BusinessRule].[BusinessRuleID],
	[ComponentID] = [BR15_Component].[ComponentID],
	[From_MemberKey] = [BR15_ComponentTier].[From_MemberKey],
	[From_Value] = [BR15_ComponentTier].[From_Value],
	[To_MemberKey] = [BR15_ComponentTier].[To_MemberKey],
	[To_Value] = [BR15_ComponentTier].[To_Value],
	[Factor_MemberKey] = [BR15_ComponentTier].[Factor_MemberKey],
	[Factor_Value] = [BR15_ComponentTier].[Factor_Value]
FROM
	' + @SourceDatabase + '.[dbo].[BR15_ComponentTier] [BR15_ComponentTier]
	INNER JOIN [pcINTEGRATOR].[dbo].[BusinessRule] [BusinessRule] ON [BusinessRule].[InstanceID] IN (0, ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ') AND [BusinessRule].[InheritedFrom] = [BR15_ComponentTier].[BusinessRuleID] AND [BusinessRule].[DeletedID] IS NULL
	INNER JOIN [pcINTEGRATOR_Data].[dbo].[BR15_Component] [BR15_Component] ON [BR15_Component].[InstanceID] = ' + CONVERT(NVARCHAR(15), @ToInstanceID) + ' AND [BR15_Component].[VersionID] = ' + CONVERT(NVARCHAR(15), @ToVersionID) + ' AND [BR15_Component].[InheritedFrom] = [BR15_ComponentTier].[ComponentID] AND [BR15_Component].[DeletedID] IS NULL
	
WHERE
	[BR15_ComponentTier].[InstanceID] = ' + CONVERT(NVARCHAR(15), @FromInstanceID) + ' AND
	[BR15_ComponentTier].[VersionID] = ' + CONVERT(NVARCHAR(15), @FromVersionID)

											IF @Debug <> 0 PRINT @SQLStatement
											EXEC (@SQLStatement)

											SET @Inserted = @Inserted + @@ROWCOUNT
										END

								END

							GOTO MoveNext
						END

				SET @Step = 'Reset SQL variables'
					SELECT @SQL_Insert = '', @SQL_Select = '', @SQL_From = ''

				SET @Step = 'Update table #Column (' + @TableName + ')'
					TRUNCATE TABLE #Column

					SET @SQLStatement = '
						INSERT INTO #Column
							(
							[ColumnName],
							[SortOrder],
							[PrimaryKeyYN]
							)
						SELECT 
							[ColumnName] = c.[name],
							[SortOrder] = c.[column_id],
							[PrimaryKeyYN] = CASE WHEN sub.COLUMN_NAME IS NULL THEN 0 ELSE 1 END
						FROM
							pcINTEGRATOR_Data.sys.tables t
							INNER JOIN pcINTEGRATOR_Data.sys.columns c ON c.object_id = t.object_id AND c.system_type_id <> 241
							INNER JOIN ' + @SourceDatabase + '.sys.tables st ON st.[name] = t.[name]
							INNER JOIN ' + @SourceDatabase + '.sys.columns sc ON sc.object_id = st.object_id AND sc.[name] = c.[name] AND sc.system_type_id <> 241
							LEFT JOIN 
								(
								SELECT 
									kcu.COLUMN_NAME
								FROM 
									pcINTEGRATOR_Data.INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
									INNER JOIN pcINTEGRATOR_Data.sys.key_constraints kc ON kc.name = kcu.CONSTRAINT_NAME AND kc.type = ''PK''
								WHERE 
									kcu.Table_Name = ''' + @TableName + '''
								) AS sub ON sub.COLUMN_NAME = c.[name]
						WHERE
							t.[name] = ''' + @TableName + '''
						ORDER BY
							c.column_id'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

/*
					INSERT INTO #Column
						(
						[ColumnName],
						[SortOrder]
						)
					SELECT
						[ColumnName] = c.[name],
						[SortOrder] = c.[column_id]
					FROM
						pcINTEGRATOR_Data.sys.tables t
						INNER JOIN pcINTEGRATOR_Data.sys.columns c ON c.object_id = t.object_id AND c.system_type_id <> 241
					WHERE
						t.[name] = @TableName
					ORDER BY
						c.column_id
*/

				SET @Step = 'Check validity (' + @TableName + ')'
					IF (SELECT COUNT(1) FROM #Column) > 0
						BEGIN
							TRUNCATE TABLE #RowCounter
							SET @SQLStatement = 'INSERT INTO #RowCounter (RowCounter) SELECT RowCounter = COUNT(1) FROM ' + @SourceDatabase + '.[dbo].[' + @TableName + '] WHERE InstanceID = ' + CONVERT(nvarchar(10), @FromInstanceID) + CASE WHEN @VersionIDYN <> 0 THEN ' AND VersionID = ' + CONVERT(nvarchar(10), @FromVersionID) ELSE '' END
							IF @Debug <> 0 PRINT @SQLStatement
							EXEC(@SQLStatement)
							SELECT @RowCounter = RowCounter FROM #RowCounter
IF @Debug <> 0 PRINT @RowCounter
							IF @RowCounter = 0 GOTO MoveNext
						END
					ELSE
						GOTO MoveNext

				SET @Step = 'Set extra variables (' + @TableName + ')'
					SELECT
						@DeletedIDYN = SUM(CASE WHEN ColumnName = 'DeletedID' THEN 1 ELSE 0 END)
					FROM
						#Column

					IF @Debug <> 0
						BEGIN
							SELECT
								[@TableName] = @TableName,
								[@IdentityYN] = @IdentityYN,
								[@VersionIDYN] = @VersionIDYN,
								[@RowCounter] = @RowCounter,
								[@DeletedIDYN] = @DeletedIDYN

							SELECT
								TempTable = '#Column',
								[@TableName] = @TableName,
								*
							FROM
								#Column
							ORDER BY
								[SortOrder]
						END

				SET @Step = 'Update table #Inherited (' + @TableName + ')'
					TRUNCATE TABLE #Inherited

					INSERT INTO #Inherited
						(
						[InheritedTable],
						[ColumnName],
						[DefaultValue],
						[SourceColumnName],
						[ShortName],
						[SortOrder],
						[DeletedIDYN]
						)
					SELECT DISTINCT
						[InheritedTable] = t.[name],
						[ColumnName] = t.[name] + 'ID',
						[DefaultValue] = NULL,
						[SourceColumnName] = t.[name] + 'ID',
						[ShortName] = t.[name],
						[SortOrder] = c.[column_id],
						[DeletedIDYN] = CASE WHEN cc.[name] IS NULL THEN 0 ELSE 1 END
					FROM
						pcINTEGRATOR_Data.sys.tables t
						INNER JOIN pcINTEGRATOR_Data.sys.columns c ON c.object_id = t.object_id AND c.[name] = 'InheritedFrom'
						LEFT JOIN pcINTEGRATOR_Data.sys.columns cc ON cc.object_id = t.object_id AND cc.[name] = 'DeletedID'
					WHERE
						t.[name] IN 
							(
							SELECT
								Col = LEFT([ColumnName], LEN([ColumnName]) - 2)
							FROM
								#Column
							WHERE
								ColumnName LIKE '%ID' AND
								ColumnName NOT IN ('InstanceID', 'VersionID', 'ApplicationID', 'DeletedID') AND
								ColumnName <> @TableName + 'ID'
							)

					INSERT INTO #Inherited
						(
						[InheritedTable],
						[ColumnName],
						[DefaultValue],
						[SourceColumnName],
						[ShortName],
						[SortOrder],
						[DeletedIDYN]
						)
					SELECT DISTINCT
						[InheritedTable] = DCJ.[SourceTableName],
						[ColumnName] = DCJ.[ColumnName],
						[DefaultValue] = DCJ.[DefaultValue],
						[SourceColumnName] = DCJ.[SourceColumnName],
						[ShortName] = DCJ.[SourceTableName] + '_' + DCJ.[ColumnName],
						[SortOrder] = 100,
						[DeletedIDYN] = CASE WHEN cc.[name] IS NULL THEN 0 ELSE 1 END 
					FROM
						DataObject_ColumnJoin DCJ
						LEFT JOIN pcINTEGRATOR_Data.sys.tables t ON t.[name] = DCJ.SourceTableName
						LEFT JOIN pcINTEGRATOR_Data.sys.columns cc ON cc.object_id = t.object_id AND cc.[name] = 'DeletedID'
					WHERE
						[TableName] = @TableName

					SET @Step = 'Update [#Inherited].[NullableYN]'
						UPDATE I
						SET
							[NullableYN] = CASE WHEN DCJ.DefaultValue IS NOT NULL THEN 1 ELSE cc.is_nullable END
						FROM
							#Inherited I
							INNER JOIN pcINTEGRATOR_Data.sys.tables t ON t.[name] = @TableName
							INNER JOIN pcINTEGRATOR_Data.sys.columns cc ON cc.object_id = t.object_id AND cc.[name] = I.ColumnName
							LEFT JOIN DataObject_ColumnJoin DCJ ON DCJ.TableName = @TableName AND DCJ.ColumnName = I.ColumnName
						--WHERE
						--	I.ColumnName NOT IN ('InitialWorkflowStateID', 'RefreshActualsInitialWorkflowStateID')

					IF @Debug <> 0 SELECT TempTable = '#Inherited', * FROM #Inherited ORDER BY [SortOrder]

				SET @Step = 'Set SQL variables (' + @TableName + ')'
					SELECT
						@SQL_Insert = @SQL_Insert + CHAR(13) + CHAR(10) + CHAR(9) + '[' + C.ColumnName + '],',
						@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + '[' + C.ColumnName + '] = ' +
																				CASE C.ColumnName
																					WHEN 'InstanceID' THEN CONVERT(nvarchar(10), @ToInstanceID)
																					WHEN 'VersionID' THEN CONVERT(nvarchar(10), @ToVersionID)
																					WHEN 'ApplicationID' THEN CONVERT(nvarchar(10), @ToApplicationID)
																					--WHEN 'InheritedFrom' THEN '[' + @TableName + '].[' + REPLACE(@TableName + 'ID', 'BR01_MasterID', 'BusinessRuleID') + ']'
																					WHEN 'InheritedFrom' THEN '[' + @TableName + '].[' + CASE WHEN @TableName LIKE 'BR%' THEN 'BusinessRuleID' ELSE @TableName + 'ID' END + ']'
																					WHEN 'ETLDatabase_Linked' THEN 'NULL'
																					WHEN 'UserID' THEN 'ISNULL([' + I.InheritedTable + '].[' + C.ColumnName + '],[' + @TableName + '].[' + C.ColumnName + '])' 
																					WHEN 'ObjectID' THEN 'ISNULL([' + I.InheritedTable + '].[' + C.ColumnName + '],[' + @TableName + '].[' + C.ColumnName + '])' 
																					WHEN I.ColumnName THEN CASE WHEN I.DefaultValue IS NULL THEN '[' + I.ShortName  + '].[' + I.SourceColumnName  + ']' ELSE I.DefaultValue END 
																					--WHEN I.ColumnName THEN 'COALESCE([' + I.DefaultValue + '],[' + I.ShortName  + '].[' + I.SourceColumnName  + '], [' + @TableName  + '].[' + C.ColumnName  + '])'
																					--WHEN I.InheritedTable + 'ID' THEN 'ISNULL([' + I.InheritedTable  + '].[' + C.ColumnName  + '], [' + @TableName  + '].[' + C.ColumnName  + '])'
																					ELSE '[' + @TableName + '].[' + C.ColumnName + ']' END + ','						
					FROM
						#Column C
						LEFT JOIN #Inherited I ON I.ColumnName = C.ColumnName
					WHERE
						(C.ColumnName <> @TableName + 'ID' OR @IdentityYN = 0) AND
						C.ColumnName NOT IN ('Version', 'DeletedID')
					ORDER BY
						C.[SortOrder]

					SELECT
						--@SQL_From = @SQL_From  + CHAR(13) + CHAR(10) + CHAR(9) + 'LEFT JOIN [pcINTEGRATOR_Data].[dbo].[' + [InheritedTable] + '] [' + [ShortName] + '] ON [' + [ShortName] + '].[InstanceID] = ' + CONVERT(nvarchar(10), @ToInstanceID) + ' AND [' + [ShortName] + '].[InheritedFrom] = [' + @TableName + '].[' + [ColumnName] + ']'
						@SQL_From = @SQL_From  + CHAR(13) + CHAR(10) + CHAR(9) + CASE WHEN [NullableYN] = 0 THEN 'INNER' ELSE 'LEFT' END + ' JOIN [pcINTEGRATOR].[dbo].[' + [InheritedTable] + '] [' + [ShortName] + '] ON [' + [ShortName] + '].[InstanceID] IN (0, ' + CONVERT(nvarchar(10), @ToInstanceID) + ') AND [' + [ShortName] + '].[InheritedFrom] = [' + @TableName + '].[' + [ColumnName] + ']' + CASE WHEN DeletedIDYN <> 0 THEN ' AND [' + [ShortName] + '].[DeletedID] IS NULL' ELSE '' END
					FROM
						#Inherited
					ORDER BY
						[SortOrder]			

					SELECT @SQL_Where = CHAR(13) + CHAR(10) + CHAR(9) + '[' + @TableName + '].[InstanceID] = ' + CONVERT(nvarchar(10), @FromInstanceID) + ' AND'
					SELECT @SQL_Where = @SQL_Where + CASE WHEN @VersionIDYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + '[' + @TableName + '].[VersionID] = ' + CONVERT(nvarchar(10), @FromVersionID) + ' AND' ELSE '' END
					SELECT @SQL_Where = @SQL_Where + CASE WHEN @DeletedIDYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + '[' + @TableName + '].[DeletedID] IS NULL AND' ELSE '' END

					IF @IdentityYN <> 0 
						SET @SQL_NotExists = '' 
					ELSE 
						BEGIN
							SELECT @SQL_NotExists = ' NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[' + @TableName + '] [DestinationTable] WHERE '
							SELECT 
								@SQL_NotExists =	@SQL_NotExists + '[DestinationTable].' + C.ColumnName + ' = ' +
																						CASE C.ColumnName
																							WHEN 'InstanceID' THEN CONVERT(nvarchar(10), @ToInstanceID)
																							WHEN 'VersionID' THEN CONVERT(nvarchar(10), @ToVersionID)
																							WHEN 'ApplicationID' THEN CONVERT(nvarchar(10), @ToApplicationID)
																							WHEN 'InheritedFrom' THEN '[' + @TableName + '].[' + REPLACE(@TableName + 'ID', 'BR01_MasterID', 'BusinessRuleID') + ']'
																							WHEN 'ETLDatabase_Linked' THEN 'NULL'
																							WHEN I.ColumnName THEN 'ISNULL([' + I.ShortName  + '].[' + I.SourceColumnName  + '], [' + @TableName  + '].[' + C.ColumnName  + '])' 
																							--WHEN I.InheritedTable + 'ID' THEN 'ISNULL([' + I.InheritedTable  + '].[' + C.ColumnName  + '], [' + @TableName  + '].[' + C.ColumnName  + '])'
																							ELSE '[' + @TableName + '].[' + C.ColumnName + ']' END + ' AND '
							FROM
								#Column C
								LEFT JOIN #Inherited I ON I.ColumnName = C.ColumnName
							WHERE 
								C.PrimaryKeyYN <> 0
						END

					SET @SQL_Where = @SQL_Where + @SQL_NotExists

					SELECT
						@SQL_Insert = LEFT(@SQL_Insert, LEN(@SQL_Insert) - 1),
						@SQL_Select = LEFT(@SQL_Select, LEN(@SQL_Select) - 1),
						@SQL_Where = LEFT(@SQL_Where, LEN(@SQL_Where) - 4) + CASE WHEN LEN(@SQL_NotExists) > 1 THEN ')' ELSE '' END
						--@SQL_NotExists = LEFT(@SQL_NotExists, LEN(@SQL_NotExists) - 4) + ')'

					IF @Debug <> 0 SELECT SQL_Insert = @SQL_Insert, SQL_Select = @SQL_Select, SQL_From = @SQL_From, SQL_Where = @SQL_Where, SQL_NotExists = @SQL_NotExists

				SET @Step = 'Set @SQLStatement (' + @TableName + ')'
					SET @SQLStatement = '
INSERT INTO [pcINTEGRATOR_Data].[dbo].[' + @TableName + ']
	(' + @SQL_Insert + '
	)
SELECT' + @SQL_Select + '
FROM
	' + @SourceDatabase + '.[dbo].[' + @TableName + '] [' + @TableName + ']' + @SQL_From + '
WHERE' + @SQL_Where

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Inserted = @Inserted + @@ROWCOUNT

					MoveNext:

				SET @Step = 'Update tables with dependencies on other tables and itself'
					IF (SELECT COUNT(1)
						FROM
							[DataObject_ColumnJoin]
						WHERE
							[SourceTableName] = @TableName AND
							[DefaultValue] IS NOT NULL
						) > 0
						BEGIN
/**
TODO: Make the following query dynamic..
**/

							SET @SQLStatement = '
								UPDATE W
								SET 
									RefreshActualsInitialWorkflowStateID = WFS1.WorkflowStateId,
									InitialWorkflowStateID = WFS2.WorkflowStateId
								FROM 
									[pcINTEGRATOR_Data].[dbo].[Workflow] W
									INNER JOIN ' + @SourceDatabase + '.[dbo].[Workflow] WF ON WF.InstanceID = ' + CONVERT(nvarchar(15), @FromInstanceID) + ' AND WF.WorkflowID = W.InheritedFrom 
									INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WFS1 ON WFS1.InstanceID = W.InstanceID AND WFS1.WorkflowID = W.WorkflowID AND WFS1.InheritedFrom = WF.RefreshActualsInitialWorkflowStateID
									INNER JOIN [pcINTEGRATOR_Data].[dbo].[WorkflowState] WFS2 ON WFS2.InstanceID = W.InstanceID AND WFS2.WorkflowID = W.WorkflowID AND WFS2.InheritedFrom = WF.InitialWorkflowStateID
							'

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Updated = @Updated + @@ROWCOUNT

						END
						
				SET @Step = 'Extra queries for specific tables (' + @TableName + ')'
					IF @TableName IN ('Object')
						BEGIN
							IF @CopyType = 'Instance'
								BEGIN
									IF @TableName = 'Object'
										BEGIN
											UPDATE O
											SET
												ParentObjectID = O1.ObjectID
											FROM
												[pcINTEGRATOR_Data].[dbo].[Object] O
												INNER JOIN [pcINTEGRATOR_Data].[dbo].[Object] O1 ON O1.InstanceID = O.InstanceID AND O1.InheritedFrom = O.ParentObjectID
											WHERE
												O.InstanceID = @ToInstanceID

											SET @Updated = @Updated + @@ROWCOUNT

											UPDATE O
											SET
												ObjectName = @ToApplicationName
											FROM
												[pcINTEGRATOR_Data].[dbo].[Object] O
											WHERE
												O.InstanceID = @ToInstanceID AND
--												O.ObjectName = @FromApplicationName AND
												O.ObjectTypeBM = 256

											SET @Updated = @Updated + @@ROWCOUNT
										END
								END
						END

					FETCH NEXT FROM Insert_Cursor INTO @TableName, @IdentityYN, @VersionIDYN
				END

		CLOSE Insert_Cursor
		DEALLOCATE Insert_Cursor
		END

	SET @Step = 'Set trigger active'
		UPDATE [pcINTEGRATOR_Data].[dbo].[Instance]
		SET
			TriggerActiveYN = 1
		WHERE
			InstanceID = @ToInstanceID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update SourceDatabase of copied Instance'
		IF @UpdateETLSourceDBYN <> 0 
			BEGIN	
				UPDATE S
				SET 
					[SourceDatabase] = ISNULL(@ETLSourceDB, REPLACE(S.SourceDatabase, Asrc.ApplicationName, A.ApplicationName))
				FROM 
					[pcIntegrator_Data].[dbo].[Source] S
					INNER JOIN [pcIntegrator_Data].[dbo].[Application] A on A.InstanceID = S.InstanceID AND A.VersionID = S.VersionID AND A.SelectYN <> 0
					INNER JOIN [pcIntegrator_Data].[dbo].[Source] Src on Src.InstanceID = @FromInstanceID AND Src.VersionID = @FromVersionID AND Src.SourceID =  S.InheritedFrom
					INNER JOIN [pcIntegrator_Data].[dbo].[Application] Asrc on Asrc.InstanceID = Src.InstanceID AND Asrc.VersionID = Src.VersionID AND Asrc.SelectYN <> 0
				WHERE 
					S.InstanceID = @ToInstanceID AND 
					S.VersionID = @ToVersionID AND 
					S.SelectYN <> 0

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #CursorTable
		DROP TABLE #RowCounter
		DROP TABLE #Column
		DROP TABLE #Inherited

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
