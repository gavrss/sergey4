SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_CheckSumStatus]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@CheckSumID int = NULL, --Mandatory
	@CheckSumRowLogID bigint = NULL, --Optional
	@CheckSumStatusBM int = NULL, --Mandatory
	@Comment nvarchar(255) = NULL, --Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000462,
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
EXEC [spPortalSet_CheckSumStatus] @UserID=-10, @InstanceID=476, @VersionID=1029, @CheckSumID = 1103, @CheckSumStatusBM = 2, @Comment = 'Investigating, NeHa', @Debug=1
EXEC [spPortalSet_CheckSumStatus] @UserID=7828, @InstanceID=476, @VersionID=1029, @CheckSumID = 1103, @CheckSumRowLogID = 6571, @CheckSumStatusBM = 2, @Comment = 'Investigating, NeHa', @Debug=1

EXEC [spPortalSet_CheckSumStatus] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CheckSum_ProcedureID int,
	@CheckSum_JobID int,
	@spCheckSum nvarchar(100),
	@SQLStatement nvarchar(max),
	@CheckSumValue int,
	@CheckSumStatus10 int,
	@CheckSumStatus20 int,
	@CheckSumStatus30 int,
	@CheckSumStatus40 int,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2172'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set CheckSumStatus for selected CheckSumID or CheckSumRowLogID.',
			@MandatoryParameter = 'CheckSumID|CheckSumStatusBM|Comment' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added parameter @AuthenticatedUserID. Replaced parameter @CheckSumStatusID with @CheckSumStatusBM. Added @Step = Update CheckSumLog count.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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

		SELECT
			@UserName = ISNULL(@UserName, suser_name()),
			@AuthenticatedUserID = ISNULL(@AuthenticatedUserID, @UserID)

		SELECT
			@CheckSum_ProcedureID = P.ProcedureID,
			@spCheckSum = CS.spCheckSum
		FROM
			pcINTEGRATOR_Data..[CheckSum] CS
			INNER JOIN pcINTEGRATOR..[Procedure] P ON P.ProcedureName = CS.spCheckSum
		WHERE
			CS.InstanceID = @InstanceID AND
			CS.VersionID = @VersionID AND
			CS.CheckSumID = @CheckSumID
		OPTION (MAXDOP 1)

		IF @Debug <> 0 SELECT [@CheckSum_ProcedureID] = @CheckSum_ProcedureID

	SET @Step = 'Update CheckSumRowLog'
		UPDATE CSRL
		SET
			[CheckSumStatusBM] = @CheckSumStatusBM,
			[UserID] = @AuthenticatedUserID,
			[Comment] = @Comment,
			[Updated] = GETDATE()
		FROM
			pcINTEGRATOR_Log.dbo.[CheckSumRowLog] CSRL
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[ProcedureID] = @CheckSum_ProcedureID AND
			([CheckSumRowLogID] = @CheckSumRowLogID OR @CheckSumRowLogID IS NULL) AND
			[CheckSumStatusBM] & 8 = 0
		OPTION (MAXDOP 1)

		SET @Updated = @Updated + @@ROWCOUNT

		IF @Debug <> 0
			SELECT *
			FROM
				pcINTEGRATOR_Log.dbo.[CheckSumRowLog] CSRL
			WHERE
				[InstanceID] = @InstanceID AND
				[VersionID] = @VersionID AND
				[ProcedureID] = @CheckSum_ProcedureID AND
				([CheckSumRowLogID] = @CheckSumRowLogID OR @CheckSumRowLogID IS NULL) AND
				[CheckSumStatusBM] & 8 = 0
			OPTION (MAXDOP 1)

	SET @Step = 'Update CheckSumLog count'
		SELECT TOP(1)
			@CheckSum_JobID = CSL.[JobID]
		FROM
			[pcINTEGRATOR_Log].[dbo].[CheckSumLog] CSL
		WHERE
			CSL.InstanceID = @InstanceID AND
			CSL.VersionID = @VersionID
		ORDER BY
			CSL.Inserted DESC
		OPTION (MAXDOP 1)

		SET @SQLStatement = @spCheckSum + ' @UserID = ' + CONVERT(nvarchar(10), @UserID) + ', @InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ', @VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ', @CheckSumValue = @CheckSumValue OUT, @CheckSumStatus10 = @CheckSumStatus10 OUT, @CheckSumStatus20 = @CheckSumStatus20 OUT, @CheckSumStatus30 = @CheckSumStatus30 OUT, @CheckSumStatus40 = @CheckSumStatus40 OUT, @ResultTypeBM=2'
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@CheckSumValue int OUT, @CheckSumStatus10 int OUT, @CheckSumStatus20 int OUT, @CheckSumStatus30 int OUT, @CheckSumStatus40 int OUT', @CheckSumValue = @CheckSumValue OUT, @CheckSumStatus10 = @CheckSumStatus10 OUT, @CheckSumStatus20 = @CheckSumStatus20 OUT, @CheckSumStatus30 = @CheckSumStatus30 OUT, @CheckSumStatus40 = @CheckSumStatus40 OUT

		IF @Debug <> 0 SELECT [@CheckSum_JobID] = @CheckSum_JobID, [@CheckSumID] = @CheckSumID, [@spCheckSum] = @spCheckSum, [@CheckSumValue] = @CheckSumValue, [@CheckSumStatus10] = @CheckSumStatus10, [@CheckSumStatus20] = @CheckSumStatus20, [@CheckSumStatus30] = @CheckSumStatus30, [@CheckSumStatus40] = @CheckSumStatus40

		UPDATE CSL
		SET 
			[CheckSumValue] = @CheckSumValue,
			[CheckSumStatus10] = @CheckSumStatus10,
			[CheckSumStatus20] = @CheckSumStatus20,
			[CheckSumStatus30] = @CheckSumStatus30,
			[CheckSumStatus40] = @CheckSumStatus40
		FROM
			[pcINTEGRATOR_Log].[dbo].[CheckSumLog] CSL
		WHERE
			CSL.InstanceID = @InstanceID AND
			CSL.VersionID = @VersionID AND
			CSL.JobID = @CheckSum_JobID AND
            CSL.CheckSumID = @CheckSumID
		OPTION (MAXDOP 1)

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
