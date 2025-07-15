SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_GLJrnDtl_SysRevID]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceID int  = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000785,
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
EXEC [spGet_GLJrnDtl_SysRevID] @UserID=-10, @InstanceID=478, @VersionID=1030 --Angling Direct
EXEC [spGet_GLJrnDtl_SysRevID] @UserID=-10, @InstanceID=476, @VersionID=1029 --Allied Aviation
EXEC [spGet_GLJrnDtl_SysRevID] @UserID=-10, @InstanceID=454, @VersionID=1021 --CCM
EXEC [spGet_GLJrnDtl_SysRevID] @UserID=-10, @InstanceID=413, @VersionID=1008 --CBN

EXEC [spGet_GLJrnDtl_SysRevID] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@SourceTable nvarchar(100),
	@SysRevID bigint,

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
	@Version nvarchar(50) = '2.1.1.2172'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get Max of correct SysRevID.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2172' SET @Description = 'Procedure created.'

--		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @DebugBM & 2 > 0
			SELECT
				[InstanceID] = @InstanceID,
				[VersionID] = @VersionID

	SET @Step = 'Create #Source_Cursor_Table'
		SELECT
			[SourceID] = S.[SourceID],
			[SourceTable] = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + '].[Erp].[GLJrnDtl]',
			[SysRevID] = CONVERT(bigint, 0)
		INTO
			#Source_Cursor_Table
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND  S.SourceTypeID = 11 AND (S.SourceID = @SourceID OR @SourceID IS NULL) AND S.SelectYN <> 0
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0 

		IF @DebugBM & 2 > 0 SELECT [TempTable]='#Source_Cursor_Table', * FROM #Source_Cursor_Table

	SET @Step = 'Source_Cursor'
		IF CURSOR_STATUS('global','Source_Cursor') >= -1 DEALLOCATE Source_Cursor
		DECLARE Source_Cursor CURSOR FOR
			
			SELECT
				[SourceID],
				[SourceTable]
			FROM
				#Source_Cursor_Table
			ORDER BY
				[SourceID]

			OPEN Source_Cursor
			FETCH NEXT FROM Source_Cursor INTO @SourceID, @SourceTable

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@SourceID] = @SourceID, [@SourceTable] = @SourceTable

					SET @SQLStatement = '
						SELECT @InternalVariable = MAX(SysRevID) FROM ' + @SourceTable

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @SysRevID OUT

					SET @SysRevID = ISNULL(@SysRevID, 0)
					
					IF @DebugBM & 2 > 0 SELECT [@SysRevID_Base] = @SysRevID

					SELECT TOP 1
						@JobID = [JobID]
					FROM
						[pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance]
					WHERE
						[InstanceID] = @InstanceID AND
						[VersionID] = @VersionID AND
						[SourceID] = @SourceID
					ORDER BY
						Inserted DESC

					SELECT
						@SysRevID = CASE WHEN MIN([MinSysRevID] - [MinJournalLine]) < @SysRevID THEN MIN([MinSysRevID] - [MinJournalLine]) ELSE @SysRevID END
					FROM
						[pcINTEGRATOR_Log].[dbo].[wrk_GLJrnDtl_NotBalance]
					WHERE
						[JobID] = @JobID AND
						[InstanceID] = @InstanceID AND
						[VersionID] = @VersionID AND
						[SourceID] = @SourceID AND
						[Amount] <> 0.0

					IF @DebugBM & 2 > 0 SELECT [@SysRevID_Adjusted] = @SysRevID

					UPDATE SCT
					SET
						[SysRevID] = @SysRevID
					FROM
						#Source_Cursor_Table SCT
					WHERE
						[SourceID] = @SourceID

					FETCH NEXT FROM Source_Cursor INTO @SourceID, @SourceTable
				END

		CLOSE Source_Cursor
		DEALLOCATE Source_Cursor

	SET @Step = 'Return rows'	
		SELECT
			*
		FROM
			#Source_Cursor_Table
		ORDER BY
			SourceID

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Source_Cursor_Table

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
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
