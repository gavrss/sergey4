SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_SecurityRoleUser]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SecurityRoleID int = NULL,
	@DeleteYN bit = 0,    
	@JSON_table nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000429,
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
-- ADD single user
EXEC [spPortalAdminSet_SecurityRoleUser] 
	@UserID = -10, 
	@InstanceID = 390, 
	@VersionID = 1011, 
	@SecurityRoleID = 2404,
	@Debug = 1

-- DELETE single user
EXEC [spPortalAdminSet_SecurityRoleUser] 
	@UserID = -10, 
	@InstanceID = 390, 
	@VersionID = 1011, 
	@SecurityRoleID = 2404,
	@DeleteYN = 1, 
	@Debug = 1

-- ADD multiple users
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_SecurityRoleUser',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"Debug", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"SecurityRoleID":"2404","UserID":"2539","DeleteYN":"0"},
		{"SecurityRoleID":"2404","UserID":"2541","DeleteYN":"0"}
		]'

-- DELETE multiple users
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_SecurityRoleUser',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"Debug", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"SecurityRoleID":"2404","UserID":"2539","DeleteYN":"1"},
		{"SecurityRoleID":"2404","UserID":"2541","DeleteYN":"1"}
		]'

EXEC [spPortalAdminSet_SecurityRoleUser] @GetVersion = 1
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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Handles CREATE and DELETE of SecurityRoleUser Object',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-434: Added parameter @AssignedInstanceID; sets InstanceID to every selected member (@JSON_table).'
		IF @Version = '2.1.0.2157' SET @Description = 'DB-434: Reverted back 2.0.2.2145 version; removed @AssignedInstanceID, @UserID and InstanceID from @JSON_table.'
		IF @Version = '2.1.0.2159' SET @Description = 'DB-443: Set InstanceID when INSERTing to [SecurityRoleUser].'
		IF @Version = '2.1.0.2160' SET @Description = 'DB-443: Set InstanceID when INSERTing to [SecurityRoleUser] AND check InstanceID in NOT EXISTS.'
		IF @Version = '2.1.2.2199' SET @Description = 'Updated to latest SP template. FDB-3166: Set InstanceID = 0 (Global Instance) for SecurityRoleID = -10 (Global Administrator Role).'

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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @DebugBM & 2 > 0 SELECT [@SecurityRoleID] = @SecurityRoleID

	SET @Step = 'Create temp table #SecurityRoleUser'
		CREATE TABLE #SecurityRoleUser
			(
			InstanceID int,
			SecurityRoleID int,
			UserID int,
			DeleteYN bit
			)

	SET @Step = 'Insert data into temp table #SecurityRoleUser'
		IF @JSON_table IS NOT NULL
			INSERT INTO #SecurityRoleUser
				(
				InstanceID,
				SecurityRoleID,
				UserID,
				DeleteYN
				)
			SELECT
				InstanceID = CASE WHEN SecurityRoleID = -10 THEN 0 ELSE @InstanceID END,
				SecurityRoleID,
				UserID,
				DeleteYN
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				SecurityRoleID int,
				UserID int,
				DeleteYN bit
				)
		ELSE
			INSERT INTO #SecurityRoleUser
				(
				InstanceID,
				SecurityRoleID,
				UserID,
				DeleteYN
				)
			SELECT
				InstanceID = CASE WHEN @SecurityRoleID = -10 THEN 0 ELSE @InstanceID END,
				SecurityRoleID = @SecurityRoleID,
				UserID = @UserID,
				DeleteYN = @DeleteYN	
				
		IF @DebugBM & 2 > 0	SELECT [TempTable] = '#SecurityRoleUser', * FROM #SecurityRoleUser		

	SET @Step = 'Delete SecurityRoleUser'
		DELETE SRU
		FROM
			[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU
			INNER JOIN #SecurityRoleUser temp ON temp.InstanceID = SRU.InstanceID AND temp.SecurityRoleID = SRU.SecurityRoleID AND temp.UserID = SRU.UserID AND temp.DeleteYN <> 0
			
		SELECT @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Update SecurityRoleUser/s'
		UPDATE SRU
		SET 
			SelectYN = 1
		FROM 
			[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU
			INNER JOIN #SecurityRoleUser temp ON temp.InstanceID = SRU.InstanceID AND temp.SecurityRoleID = SRU.SecurityRoleID AND temp.UserID = SRU.UserID AND temp.DeleteYN = 0
		WHERE 
			SRU.SelectYN = 0

		SELECT @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert single or multiple SecurityRoleUser/s'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
			(
			[InstanceID],
			[SecurityRoleID],
			[UserID],
			[SelectYN]
			)
		SELECT
			[InstanceID],
			[SecurityRoleID],
			[UserID],
			[SelectYN] = 1
		FROM
			#SecurityRoleUser temp
		WHERE
			temp.DeleteYN = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU WHERE SRU.[InstanceID] = temp.[InstanceID] AND SRU.[SecurityRoleID] = temp.[SecurityRoleID] AND SRU.[UserID] = temp.[UserID])
			
		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Delete temp table'
		DROP TABLE #SecurityRoleUser

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
