SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_Callisto_Parameter_20240505]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Label nvarchar(200) = NULL,
	@Operation nvarchar(100) = NULL,
	@Custom int = 0,
	@BusinessRuleID int = 0,
	@Parameter nvarchar(4000) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@LogParameter nvarchar(4000) = NULL,
	@TimeOut time(7) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000564,
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
EXEC [spBR_Callisto_Parameter] @UserID=NULL, @InstanceID=-1335, @VersionID=-1273, @Operation='Capex', @JobID=6, @DebugBM=1
EXEC [spBR_Callisto_Parameter] @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @Custom=1, @Operation='spIU_0000_Version', @JobID=4, @DebugBM=6
EXEC spBR_Callisto_Parameter @BusinessRuleID='0',@CallistoDatabase='pcDATA_EPIC',@Custom='0',@Parameter='[Parameter].[Parameter].[10010001],[Group].[Group].[G_CDHO],[BusinessRule].[Parameter].[10010001]',@Label='FxTrans',@Operation='FxTrans', @JobID=26, @DebugBM=3

EXEC [spBR_Callisto_Parameter] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@JSON nvarchar(max),
	@SQLStatement nvarchar(max),
	@UserNameAD nvarchar(100),
	@DataClassID int,
	@DataClassName nvarchar(100),
	@Filter nvarchar(4000) = 'FilterType=MemberID',
	@ParameterName nvarchar(255),
	@DimensionName nvarchar(100),
	@MemberId nvarchar(20),
	@ETLDatabase nvarchar(100),
	@spBR nvarchar(100),
	@DataClassYN bit,
	@FilterYN bit,
	@ProcedureNameRef nvarchar(100),
	@ParameterPassed nvarchar(4000) = '',

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Run BusinessRule with parameters set in Callisto',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Catching of errors removed to get it passed to Callisto UI.'
		IF @Version = '2.1.0.2162' SET @Description = 'Removed hard coded reference to Callisto database.'
		IF @Version = '2.1.1.2168' SET @Description = 'Added @TimeOut and call to [spSet_Job].'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON

SET @Step = 'Set @StartTime'
	SET @StartTime = ISNULL(@StartTime, GETDATE())

SET @Step = 'Set procedure variables'
	SELECT
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
		@InstanceID = ISNULL(@InstanceID, InstanceID),
		@VersionID = ISNULL(@VersionID, VersionID),
		@ETLDatabase = ETLDatabase
	FROM
		[pcINTEGRATOR_Data].[dbo].[Application]
	WHERE
		DestinationDatabase = @CallistoDatabase

	SET @ProcedureNameRef = @ProcedureName + ' (' + @Label + '/' + @Operation + ')'

SET @Step = 'Set @spBR'
	SELECT
		@spBR = BRT.[ProcedureName],
		@DataClassYN = CASE WHEN DC.[name] = '@DataClassID' OR PR.[name] IS NULL THEN 1 ELSE 0 END,
		@FilterYN = CASE WHEN F.[name] = '@Filter' OR PR.[name] IS NULL THEN 1 ELSE 0 END
	FROM
		BR_Type BRT
		LEFT JOIN sys.procedures PR ON PR.[name] = BRT.[ProcedureName]
		LEFT JOIN sys.parameters DC on DC.object_id = PR.object_id AND DC.[name] = '@DataClassID'
		LEFT JOIN sys.parameters F on F.object_id = PR.object_id AND F.[name] = '@Filter'
	WHERE
		BRT.[InstanceID] IN (0, @InstanceID) AND
		BRT.[VersionID] IN (0, @VersionID) AND
		BRT.[Operation] = @Operation AND
		BRT.[CallistoEnabledYN] <> 0

	IF @spBR IS NULL
		BEGIN
			SET @Message = @Operation + ' is not a valid Operation.'
			SET @Severity = 16
			GOTO EXITPOINT
		END

SET @Step = 'Capture ParameterValues'
	IF @JobID IS NULL
		BEGIN
			SET @TimeOut = ISNULL(@TimeOut, '00:30:00')

			EXEC [spSet_Job]
					@UserID=@UserID,
					@InstanceID=@InstanceID,
					@VersionID=@VersionID,
					@ActionType='Start',
					@MasterCommand=@ProcedureName,
					@CurrentCommand=@ProcedureName,
					@JobListID = NULL,
					@JobQueueYN=1,
					@TimeOut = @TimeOut,
					@CheckCount = 0,
					@JobID=@JobID OUT

			--INSERT INTO [pcINTEGRATOR_Log].[dbo].[Job]
			--	(
			--	[InstanceID],
			--	[VersionID],
			--	[MasterCommand]
			--	)
			--SELECT
			--	[InstanceID] = @InstanceID,
			--	[VersionID] = @VersionID,
			--	[MasterCommand] = @ProcedureName

			--SET @JobID = @@IDENTITY
		END

	IF OBJECT_ID (N'tempdb..#temp_parametervalues', N'U') IS NULL
		BEGIN
			SELECT
				[ParameterName],
				[MemberId],
				[StringValue]
			INTO
				#temp_parametervalues
			FROM
				pcINTEGRATOR_Log..[wrk_ParameterValues]
			WHERE
				JobID = @JobID
		END
	ELSE
		BEGIN
			INSERT INTO pcINTEGRATOR_Log..[wrk_ParameterValues]
				(
				[InstanceID],
				[VersionID],
				[JobID],
				[ParameterName],
				[MemberId],
				[StringValue]
				)
			SELECT
				[InstanceID] = @InstanceID,
				[VersionID] = @VersionID,
				[JobID] = @JobID,
				[ParameterName] = tpv.[ParameterName],
				[MemberId] = ISNULL(tpv.[MemberId], 0),
				[StringValue] = tpv.[StringValue]
			FROM
				#temp_parametervalues tpv
		END

	IF @DebugBM & 2 > 0 SELECT TempTable = '#temp_parametervalues', * FROM #temp_parametervalues

SET @Step = 'Set @UserID'
	IF @UserID IS NULL
		BEGIN
			SELECT
				@UserNameAD = StringValue
			FROM
				#temp_parametervalues
			WHERE
				ParameterName = 'Userid'

			SELECT
				@UserID = MIN(UserID)
			FROM
				pcINTEGRATOR_Data..[User]
			WHERE
				UserNameAD = @UserNameAD AND
				SelectYN <> 0 AND
				DeletedID IS NULL

			SELECT @UserID = ISNULL(@UserID, -10)
		END

SET @Step = 'Set @DataClassID'
	SELECT
		@DataClassName = StringValue
	FROM
		#temp_parametervalues
	WHERE
		ParameterName = 'Model'

	SELECT
		@DataClassID = MIN(DataClassID)
	FROM
		pcINTEGRATOR_Data..[DataClass]
	WHERE
		InstanceID = @InstanceID AND
		VersionID = @VersionID AND
		DataClassName = @DataClassName AND
		SelectYN <> 0 AND
		DeletedID IS NULL

	IF @DebugBM & 2 > 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@DataClassID] = @DataClassID, [@UserNameAD] = @UserNameAD, [@DataClassName] = @DataClassName

SET @Step = 'Set @Filter'
	IF CURSOR_STATUS('global','Filter_Cursor') >= -1 DEALLOCATE Filter_Cursor
	DECLARE Filter_Cursor CURSOR FOR
		SELECT DISTINCT
			ParameterName,
			DimensionName = REPLACE(ParameterName, 'Mbrs', '')
		FROM
			#temp_parametervalues
		WHERE
			ParameterName NOT IN ('Userid', 'Model')

		OPEN Filter_Cursor
		FETCH NEXT FROM Filter_Cursor INTO @ParameterName, @DimensionName

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@ParameterName] = @ParameterName, [@DimensionName] = @DimensionName

				SET @Filter = @Filter + '|' + @DimensionName + '='

				IF CURSOR_STATUS('global','Parameter_Cursor') >= -1 DEALLOCATE Parameter_Cursor
				DECLARE Parameter_Cursor CURSOR FOR
					SELECT DISTINCT
						MemberId
					FROM
						#temp_parametervalues
					WHERE
						ParameterName = @ParameterName

					OPEN Parameter_Cursor
					FETCH NEXT FROM Parameter_Cursor INTO @MemberId

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@MemberId] = @MemberId

							SET @Filter = @Filter + @MemberId + ','

							FETCH NEXT FROM Parameter_Cursor INTO @MemberId
						END

				CLOSE Parameter_Cursor
				DEALLOCATE Parameter_Cursor

				SET @Filter = LEFT(@Filter, LEN(@Filter) -1)

				FETCH NEXT FROM Filter_Cursor INTO @ParameterName, @DimensionName
			END

	CLOSE Filter_Cursor
	DEALLOCATE Filter_Cursor

	IF @DebugBM & 1 > 0 SELECT [@Filter] = @Filter

SET @Step = 'Get Parameters from @Parameter'
	CREATE TABLE #Parameter
		(
		ParameterString nvarchar(100) COLLATE DATABASE_DEFAULT,
		Parameter bigint,
		ParameterName nvarchar(100) COLLATE DATABASE_DEFAULT,
		ParameterValue int,
		ValidYN bit DEFAULT 0
		)
	INSERT INTO #Parameter
		(
		ParameterString
		)
	SELECT
		ParameterString = LTRIM(RTRIM([Value]))
	FROM
		STRING_SPLIT(@Parameter, ',')

	UPDATE P
	SET
		Parameter = CASE WHEN ISNUMERIC(LEFT(REPLACE(REPLACE(ParameterString, '[BusinessRule].[Parameter].[', ''), ']', ''), 8)) <> 0 THEN LEFT(REPLACE(REPLACE(ParameterString, '[BusinessRule].[Parameter].[', ''), ']', ''), 8) ELSE NULL END
	FROM
		#Parameter P
	WHERE
		ParameterString LIKE '%BusinessRule%' AND
		ParameterString LIKE '%Parameter%'

	SET @SQLStatement = '
		UPDATE P
		SET
			ParameterName = BRP.[Label],
			ParameterValue = P.Parameter % 10000
		FROM
			#Parameter P
			INNER JOIN ' + @CallistoDatabase + '..S_DS_BusinessRule BRP ON BRP.MemberID = P.Parameter / 10000
		WHERE
			P.Parameter IS NOT NULL'

	EXEC (@SQLStatement)

	--UPDATE P
	--SET
	--	ParameterName = BRP.[Label],
	--	ParameterValue = P.Parameter % 10000
	--FROM
	--	#Parameter P
	--	INNER JOIN pcDATA_EPIC..S_DS_BusinessRule BRP ON BRP.MemberID = P.Parameter / 10000
	--WHERE
	--	P.Parameter IS NOT NULL

	UPDATE P
	SET
		ValidYN = 1
	FROM
		#Parameter P
		LEFT JOIN sys.procedures PR ON PR.[name] = @spBR
		LEFT JOIN sys.parameters DC on DC.object_id = PR.object_id AND DC.[name] = '@' + P.ParameterName
	WHERE
		P.Parameter IS NOT NULL

	IF @DebugBM & 2 > 0 SELECT * FROM #Parameter P WHERE P.ValidYN <> 0

	SELECT
		@ParameterPassed = @ParameterPassed + ',@' + P.ParameterName + '=' + CONVERT(nvarchar(15), P.ParameterValue)
	FROM
		#Parameter P
	WHERE
		P.ValidYN <> 0

	IF @DebugBM & 2 > 0 SELECT [@ParameterPassed] = @ParameterPassed

SET @Step = 'Call BusinessRule'
	IF @Custom = 0
		BEGIN
			SET @SQLStatement = 'EXEC ' + @spBR + ' @UserID=' + CONVERT(nvarchar(10), @UserID) + ',@InstanceID=' + CONVERT(nvarchar(10), @InstanceID) + ',@VersionID=' + CONVERT(nvarchar(10), @VersionID) + ',@CalledBy=''Callisto'',@JobID=' + CONVERT(nvarchar(10), @JobID) + ',@Debug=' + CONVERT(nvarchar(10), @DebugSub) + @ParameterPassed
			IF @BusinessRuleID <> 0 SET @SQLStatement = @SQLStatement + ',@BusinessRuleID=' + CONVERT(nvarchar(10), @BusinessRuleID)
			IF @FilterYN <> 0 SET @SQLStatement = @SQLStatement + ',@Filter=''' + @Filter + ''''
			IF @DataClassYN <> 0 SET @SQLStatement = @SQLStatement + ',@DataClassID=' + CONVERT(nvarchar(10), @DataClassID)
			SET @SQLStatement = @SQLStatement + ',@Parameter=''' + REPLACE(@SQLStatement, '''', '''''') + ''''

			IF @DebugBM & 2 > 0 PRINT @SQLStatement
			EXEC (@SQLStatement)
		END
	ELSE
		BEGIN
			SET @SQLStatement = '[dbo].[' + @spBR + '] @UserID=' + CONVERT(nvarchar(10), @UserID) + ', @InstanceID=' + CONVERT(nvarchar(10), @InstanceID) + ', @VersionID=' + CONVERT(nvarchar(10), @VersionID) + ', @JobID=' + CONVERT(nvarchar(10), @JobID) + ', @Debug=' + CONVERT(nvarchar(10), @DebugSub) + CASE WHEN @FilterYN = 0 THEN '' ELSE ', @Filter=''' + @Filter + '' END + CASE WHEN @DataClassYN = 0 THEN '' ELSE ', @DataClassID=' + CONVERT(nvarchar(10), @DataClassID) END
			SET @SQLStatement = @SQLStatement + ',@Parameter=''' + REPLACE(@SQLStatement, '''', '''''') + ''''
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

			IF @DebugBM & 2 > 0 PRINT @SQLStatement
			EXEC (@SQLStatement)
		END

SET @Step = 'Set @Duration'
	SET @Duration = GetDate() - @StartTime

SET @Step = 'Insert into JobLog'
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureNameRef, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @Parameter = @LogParameter, @LogVersion = @Version, @UserName = @UserName

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
