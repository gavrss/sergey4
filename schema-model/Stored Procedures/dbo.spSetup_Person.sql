SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Person]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SourceTypeID int = NULL,
	@SourceID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000799,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spSetup_Person',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSetup_Person] @UserID=-10, @InstanceID = 515, @VersionID = 1064, @DebugBM=3, @SourceTypeID = 5, @SourceID = 1225

EXEC [spSetup_Person] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement NVARCHAR(MAX),
	@SourceTypeName NVARCHAR(50),
	@Owner NVARCHAR(10), 
	@SourceDatabase NVARCHAR(255),

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
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
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.1.2175'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Person',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2175' SET @Description = 'Procedure created.'

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

		--SELECT
		--	@ApplicationID = A.[ApplicationID],
		--	@ApplicationName = A.[ApplicationName],
		--	@ETLDatabase = A.[ETLDatabase],
		--	@CallistoDatabase = A.[DestinationDatabase]
		--FROM
		--	[Application] A
		--	INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID
		--WHERE
		--	A.[InstanceID] = @InstanceID AND
		--	A.[VersionID] = @VersionID

		IF @DebugBM & 2 > 0 
			SELECT 
				[@JobID] = @JobID,
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceID] = @SourceID
 
	SET @Step = 'Create [Source] CursorTable'
		CREATE TABLE #Source_CursorTable
			(
			[SourceTypeID] int,
			[SourceTypeName] nvarchar(50),
			[SourceID] int,
			[Owner] nvarchar(3) COLLATE DATABASE_DEFAULT,
			[SourceDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #Source_CursorTable
			(
			[SourceTypeID],
			[SourceTypeName],
			[SourceID],
			[Owner],
			[SourceDatabase]
			)
		SELECT DISTINCT
			[SourceTypeID] = ISNULL(@SourceTypeID, S.[SourceTypeID]),
			[SourceTypeName] = ST.[SourceTypeName],
			[SourceID] = ISNULL(@SourceID, S.[SourceID]),
			[Owner] = CASE WHEN S.[SourceTypeID] = 11 THEN 'erp' ELSE 'dbo' END,
			[SourceDatabase] = S.[SourceDatabase]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Source] S
			INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SelectYN] <> 0 AND
			(S.[SourceTypeID] = @SourceTypeID OR @SourceTypeID IS NULL) AND 
			(S.[SourceID] = @SourceID OR @SourceID IS NULL)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Source_CursorTable', * FROM #Source_CursorTable ORDER BY [SourceTypeID]

	SET @Step = 'Create Person'
		IF CURSOR_STATUS('global','Source_Cursor') >= -1 DEALLOCATE Source_Cursor
		DECLARE Source_Cursor CURSOR FOR
			
			SELECT 
				[SourceTypeID],
				[SourceTypeName],
				[SourceID],
				[Owner],
				[SourceDatabase]
			FROM
				#Source_CursorTable

			OPEN Source_Cursor
			FETCH NEXT FROM Source_Cursor INTO @SourceTypeID, @SourceTypeName, @SourceID, @Owner, @SourceDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@SourceTypeID] = @SourceTypeID, [@SourceTypeName] = @SourceTypeName, [@SourceID] = @SourceID, [@Owner] = @Owner, [@SourceDatabase] = @SourceDatabase

					SET @Step = 'SourceTypeID = 5 P21'
						IF @SourceTypeID IN (5)
							BEGIN
								--IF @InstanceID = 515 SET @SourceDatabase = 'DSPSOURCE01.pcSource_PSSTP21'

								--UPDATE
								SET @SQLStatement = '

									UPDATE P
									SET
										[EmployeeNumber] = sub.[EmployeeNumber],
										[DisplayName] = sub.[DisplayName],
										[FamilyName] = sub.[FamilyName],
										[GivenName] = sub.[GivenName],
										[Email] = sub.[Email],
										[SocialSecurityNumber] = sub.[SocialSecurityNumber],
										[Source] = sub.[Source],
										[SourceID] = sub.[SourceID]
									FROM
										[pcINTEGRATOR_Data].[dbo].[Person] P
										INNER JOIN
											(
											SELECT 
												[EmployeeNumber] = CU.[employee_number],
												[DisplayName] = MAX(c.[first_name] + CASE WHEN LEN(c.[mi]) > 0 THEN '' '' + c.[mi] ELSE '''' END + '' '' + c.[last_name]),
												[FamilyName] = MAX(c.[last_name]),
												[GivenName] = MAX(c.[first_name]),
												[Email] = MAX(c.[email_address]),
												[SocialSecurityNumber] = NULL,
												[SourceSpecificKey] = CU.[employee_number],
												[Source] = ''' + @SourceTypeName + ''',
												[SourceID] = ' + CONVERT(NVARCHAR(15), @SourceID) + '
											FROM
												' + @SourceDatabase + '.' + @Owner + '.[contacts_ud] cu
												INNER JOIN ' + @SourceDatabase + '.' + @Owner + '.[contacts] c ON c.id = cu.id AND LEN(c.[email_address]) > 3
											WHERE
												CU.[employee_number] IS NOT NULL
											GROUP BY
												CU.[employee_number]
											) sub ON sub.[SourceSpecificKey] = P.[SourceSpecificKey]
										WHERE
											P.[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID)

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
								SET @Updated = @Updated + @@ROWCOUNT


								--INSERT
								SET @SQLStatement = '
									INSERT INTO [pcINTEGRATOR_Data].[dbo].[Person]
										(
										[InstanceID],
										[EmployeeNumber],
										[DisplayName],
										[FamilyName],
										[GivenName],
										[Email],
										[SocialSecurityNumber],
										[SourceSpecificKey],
										[Source],
										[SourceID]
										)
									SELECT 
										[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID) + ',
										[EmployeeNumber] = CU.[employee_number],
										[DisplayName] = MAX(c.[first_name] + CASE WHEN LEN(c.[mi]) > 0 THEN '' '' + c.[mi] ELSE '''' END + '' '' + c.[last_name]),
										[FamilyName] = MAX(c.[last_name]),
										[GivenName] = MAX(c.[first_name]),
										[Email] = MAX(c.[email_address]),
										[SocialSecurityNumber] = NULL,
										[SourceSpecificKey] = CU.[employee_number],
										[Source] = ''' + @SourceTypeName + ''',
										[SourceID] = ' + CONVERT(NVARCHAR(15), @SourceID) + '
									FROM
										' + @SourceDatabase + '.' + @Owner + '.[contacts_ud] cu
										INNER JOIN ' + @SourceDatabase + '.' + @Owner + '.[contacts] c ON c.[id] = cu.[id] AND LEN(c.[email_address]) > 3 AND c.delete_flag <> ''Y''
									WHERE
										CU.[employee_number] IS NOT NULL AND
										NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Person] P WHERE P.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND P.SourceID = ' + CONVERT(NVARCHAR(15), @SourceID) + ' AND P.SourceSpecificKey = CU.[employee_number])
									GROUP BY
										CU.[employee_number]'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
								SET @Inserted = @Inserted + @@ROWCOUNT

													
							END	

					FETCH NEXT FROM Source_Cursor INTO @SourceTypeID, @SourceTypeName, @SourceID, @Owner, @SourceDatabase
				END

		CLOSE Source_Cursor
		DEALLOCATE Source_Cursor

	SET @Step = 'Return information'
		IF @DebugBM & 1 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Person', * FROM [pcINTEGRATOR_Data].[dbo].[Person] WHERE InstanceID = @InstanceID	

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Source_CursorTable
	
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
--	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
