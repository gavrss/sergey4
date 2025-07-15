SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheckSum_Financials_Currency]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 1, --1=generate new CheckSumStatus count, 2=get CheckSumStatus count, 4=Details (of @CheckSumStatusBM) 
	@CheckSumValue int = NULL OUT,
	@CheckSumStatus10 int = NULL OUT,
	@CheckSumStatus20 int = NULL OUT,
	@CheckSumStatus30 int = NULL OUT,
	@CheckSumStatus40 int = NULL OUT,
	@CheckSumStatusBM int = 7, -- 1=Open, 2=Investigating, 4=Ignored, 8=Solved

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000380,
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
DECLARE @CheckSumValue int, @CheckSumStatus10 int, @CheckSumStatus20 int, @CheckSumStatus30 int, @CheckSumStatus40 int
EXEC [spCheckSum_Financials_Currency] @UserID=-10, @InstanceID=476, @VersionID=1029, @Debug=0,
@CheckSumValue=@CheckSumValue OUT, @CheckSumStatus10=@CheckSumStatus10 OUT, @CheckSumStatus20 =@CheckSumStatus20 OUT,
@CheckSumStatus30=@CheckSumStatus30 OUT, @CheckSumStatus40=@CheckSumStatus40 OUT
SELECT [@CheckSumValue] = @CheckSumValue, [@CheckSumStatus10] = @CheckSumStatus10, [@CheckSumStatus20] = @CheckSumStatus20, 
[@CheckSumStatus30] = @CheckSumStatus30, [@CheckSumStatus40] = @CheckSumStatus40

DECLARE @CheckSumValue int
EXEC [spCheckSum_Financials_Currency] @UserID=-10, @InstanceID=390, @VersionID=1011, @CheckSumValue = @CheckSumValue OUT, @Debug=1
SELECT CheckSumValue = @CheckSumValue

EXEC [spCheckSum_Financials_Currency] @UserID=-10, @InstanceID=413, @VersionID=1008, @ResultTypeBM = 3, @Debug=1
EXEC [spCheckSum_Financials_Currency] @UserID=-10, @InstanceID=476, @VersionID=1029, @ResultTypeBM = 4, @CheckSumStatusBM=8

EXEC [spCheckSum_Financials_Currency] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@CalledYN bit = 1,
	@StorageTypeBM int,
	@LeafLevelFilter nvarchar(MAX),

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
	@ToBeChanged nvarchar(255) = 'Now only support Callisto storage',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get CheckSum for Financials rows where Currency is not set',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-106: Implemented CheckSumRowLogID.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added parameters @CheckSumStatus10, @CheckSumStatus20, @CheckSumStatus30, @CheckSumStatus40, @CheckSumStatusBM.'
		IF @Version = '2.1.1.2173' SET @Description = 'Removed filters for @Step = Insert into JobLog.'
		IF @Version = '2.1.1.2174' SET @Description = 'Added [CheckSumStatusBM] in @ResultTypeBM = 4.'

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
			@ETLDatabase = ETLDatabase,
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT 
			@StorageTypeBM = [StorageTypeBM]
		FROM
			[Dimension_StorageType]
  		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DimensionID] = -1

	SET @Step = 'Check @StorageTypeBM'
		IF @StorageTypeBM & 4 = 0
			BEGIN
				SET @Message = 'This Checksum is only implemented for Callisto storage.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp table #Financials_Currency'
		CREATE TABLE #Financials_Currency
			(
			[Table] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Account] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[BusinessProcess] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[BusinessRule] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Currency] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Scenario] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Time] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Occurrences] int,
			[Inserted] datetime,
			[CheckSumRowLogID] bigint
			)

		EXEC [spGet_LeafLevelFilter]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DatabaseName = @CallistoDatabase,
			@DimensionName = 'Account',
			@MemberId = 290, --Financials_
			@StorageTypeBM_DataClass = 3, --3 returns _MemberKey, 4 returns _MemberId
			@StorageTypeBM = 4, --Mandatory
			@LeafLevelFilter = @LeafLevelFilter OUT --Mandatory

		SET @SQLStatement = '
			INSERT INTO #Financials_Currency
				(
				[Table],
				[Account],
				[BusinessProcess],
				[BusinessRule],
				[Currency],
				[Entity],
				[Scenario],
				[Time],
				[Occurrences],
				[Inserted]
				)
			SELECT
				[Table] = ''' + @CallistoDatabase + '..FACT_Financials_default_partition'',
				[Account],
				[BusinessProcess],
				[BusinessRule],
				[Currency],
				[Entity],
				[Scenario],
				[Time],
				[Occurrences] = COUNT(1),
				[Inserted] = GetDate()
			FROM
				' + @CallistoDatabase + '..FACT_Financials_View
			WHERE
				Currency = ''NONE'' AND
				Account IN (' + @LeafLevelFilter + ')
			GROUP BY
				[Account],
				[BusinessProcess],
				[BusinessRule],
				[Currency],
				[Entity],
				[Scenario],
				[Time]
			OPTION (MAXDOP 1)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
	SET @Step = 'Set CheckSumRowLogID'
		INSERT INTO [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog]
			(
			[CheckSumRowKey],
			[InstanceID],
			[VersionID],
			[ProcedureID]
			)
		SELECT
			[CheckSumRowKey] = FC.[Table] + '_' + FC.[Account] + '_' + FC.[BusinessProcess] + '_' + FC.[BusinessRule] + '_' + FC.[Currency] + '_' + FC.[Entity] + '_' + FC.[Scenario] + '_' + FC.[Time],
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[ProcedureID] = @ProcedureID
		FROM
			[#Financials_Currency] FC
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL WHERE CSRL.[CheckSumRowKey] = FC.[Table] + '_' + FC.[Account] + '_' + FC.[BusinessProcess] + '_' + FC.[BusinessRule] + '_' + FC.[Currency] + '_' + FC.[Entity] + '_' + FC.[Scenario] + '_' + FC.[Time] AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = @InstanceID AND CSRL.[VersionID] = @VersionID AND CSRL.[CheckSumStatusBM] & 8 = 0)
		OPTION (MAXDOP 1)

		UPDATE FC
		SET
			CheckSumRowLogID = CSRL.CheckSumRowLogID
		FROM
			[#Financials_Currency] FC
			INNER JOIN [pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL ON CSRL.[CheckSumRowKey] = FC.[Table] + '_' + FC.[Account] + '_' + FC.[BusinessProcess] + '_' + FC.[BusinessRule] + '_' + FC.[Currency] + '_' + FC.[Entity] + '_' + FC.[Scenario] + '_' + FC.[Time] AND CSRL.[ProcedureID] = @ProcedureID AND CSRL.[InstanceID] = @InstanceID AND CSRL.[VersionID] = @VersionID
		OPTION (MAXDOP 1)

		UPDATE CSRL
		SET
			--[Solved] = GetDate(),
			--[CheckSumStatusID] = 40
			[CheckSumStatusBM] = 8,
			[UserID] = @UserID,
			[Comment] = 'Resolved automatically.',
			[Updated] = GetDate()
		FROM
			[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
		WHERE
			CSRL.[InstanceID] = @InstanceID AND
			CSRL.[VersionID] = @VersionID AND
			CSRL.[ProcedureID] = @ProcedureID AND
			--CSRL.[Solved] IS NULL AND
			--CSRL.[CheckSumStatusID] <> 40 AND
			CSRL.[CheckSumStatusBM] & 8 = 0 AND
			NOT EXISTS (SELECT 1 FROM [#Financials_Currency] FC WHERE FC.[CheckSumRowLogID] = CSRL.[CheckSumRowLogID])
		OPTION (MAXDOP 1)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Get CheckSumValue'
		IF @ResultTypeBM & 3 > 0
			BEGIN
				--INSERT INTO #CheckSumValue
				--	(CheckSumValue)
				--SELECT
				--	CheckSumValue = SUM(Occurrences)
				--FROM
				--	#Financials_Currency

				SELECT
					@CheckSumValue = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 3 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus10 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 1 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus20 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 2 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus30 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 4 > 0 THEN 1 ELSE 0 END), 0),
					@CheckSumStatus40 = ISNULL(SUM(CASE WHEN CSRL.CheckSumStatusBM & 8 > 0 THEN 1 ELSE 0 END), 0)
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
					LEFT JOIN #Financials_Currency wrk ON wrk.CheckSumRowLogID = CSRL.CheckSumRowLogID
				WHERE
					CSRL.[InstanceID] = @InstanceID AND
					CSRL.[VersionID] = @VersionID AND 
                    CSRL.[ProcedureID] = @ProcedureID

				IF @Debug <> 0 
					SELECT 
						[@CheckSumValue] = @CheckSumValue, 
						[@CheckSumStatus10] = @CheckSumStatus10, 
						[@CheckSumStatus20] = @CheckSumStatus20,
						[@CheckSumStatus30] = @CheckSumStatus30,
						[@CheckSumStatus40] = @CheckSumStatus40
			END

	SET @Step = 'Get detailed info'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					[CheckSumRowLogID] = CSRL.[CheckSumRowLogID],
					[FirstOccurrence] = CSRL.[Inserted],
					[CheckSumStatusBM] = CSS.[CheckSumStatusBM],
					[CurrentStatus] = CSS.[CheckSumStatusName],
					[Comment] = CSRL.[Comment],
					[Table],
					[Account],
					[BusinessProcess],
					[BusinessRule],
					[Currency],
					[Entity],
					[Scenario],
					[Time],
					[Occurrences],
					[LastCheck] = FC.[Inserted],
					[AuthenticatedUserID] = CSRL.UserID,
					[AuthenticatedUserName] = U.UserNameDisplay,
					[AuthenticatedUserOrganization] = I.InstanceName,
					[Updated] = CSRL.[Updated]
				FROM
					[pcINTEGRATOR_Log].[dbo].[CheckSumRowLog] CSRL
					LEFT JOIN [#Financials_Currency] FC ON FC.CheckSumRowLogID = CSRL.CheckSumRowLogID
					INNER JOIN CheckSumStatus CSS ON CSS.CheckSumStatusBM = CSRL.CheckSumStatusBM
					LEFT JOIN [pcINTEGRATOR].[dbo].[User] U ON U.UserID = CSRL.UserID
					LEFT JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID 
				WHERE
					CSRL.InstanceID = @InstanceID AND
					CSRL.VersionID = @VersionID AND   
                    CSRL.ProcedureID = @ProcedureID AND 
					CSRL.CheckSumStatusBM & @CheckSumStatusBM > 0
				OPTION (MAXDOP 1)
				
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Drop Temp table'
		DROP TABLE #Financials_Currency

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
