SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_MemberInfo]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL, 
	@MemberKey nvarchar(100) = NULL OUT,
	@MemberID bigint = NULL OUT,
	@PropertyName nvarchar(100) = NULL,
	@PropertyValue nvarchar(100) = NULL OUT,
	@PropertyValue_MemberID bigint = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000736,
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
EXEC [spGet_MemberInfo] @InstanceID = -1335, @VersionID = -1273, @DimensionID = -1, @MemberKey = '202002', @PropertyName = 'ICCounterpart'

DECLARE @MemberId bigint
EXEC [spGet_MemberInfo] @InstanceID = 454, @VersionID = 1021, @DimensionID = -63, @MemberKey = '6810_Input/Adjust Budget', @MemberId = @MemberId OUT, @Debug = 1
SELECT [@MemberId] = @MemberId

EXEC [spGet_MemberInfo] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@DimensionName nvarchar(100),
	@StorageTypeBM int,
	@DataTypeID int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get MemberKey, MemberId or any Property translated from MemberId/MemberKey. Replaces spGet_MemberKey and spGet_MemberID.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2163' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2168' SET @Description = 'Enhanced debugging.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@StorageTypeBM = StorageTypeBM
		FROM
			pcINTEGRATOR_Data..Dimension_StorageType DST
		WHERE
			DST.[InstanceID] = @InstanceID AND
			DST.[VersionID] = @VersionID AND
			DST.DimensionID = @DimensionID

		SELECT
			@CallistoDatabase = A.DestinationDatabase
		FROM
			pcINTEGRATOR_Data.dbo.[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		SELECT
			@DimensionName = D.DimensionName
		FROM
			[Dimension] D
		WHERE
			D.[DimensionID] = @DimensionID
	
	SET @Step = 'Callisto'
		IF @StorageTypeBM & 4 > 0
			BEGIN
				SET @Step = 'Callisto: Calculate @MemberID'
					IF @MemberKey IS NOT NULL AND @MemberId IS NULL
						BEGIN
							SET @SQLStatement = '
								SELECT
									 @InternalVariable = [MemberId]
								FROM
									' + @CallistoDatabase + '.dbo.S_DS_' + @DimensionName + '
								WHERE
									[Label] = ''' + @MemberKey + ''''

							EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @MemberId OUT
						END

				SET @Step = 'Callisto: Calculate @MemberKey'
					IF @MemberKey IS NULL AND @MemberId IS NOT NULL
						BEGIN
							SET @SQLStatement = '
								SELECT
									 @InternalVariable = [Label]
								FROM
									' + @CallistoDatabase + '.dbo.S_DS_' + @DimensionName + '
								WHERE
									[MemberId] = ' + CONVERT(nvarchar(20), @MemberID)

							EXEC sp_executesql @SQLStatement, N'@InternalVariable nvarchar(100) OUT', @InternalVariable = @MemberKey OUT
						END

				SET @Step = 'Callisto: Calculate @PropertyValue AND @PropertyValue_MemberKey'
					IF @PropertyName IS NOT NULL
						BEGIN
							SELECT
								@DataTypeID = DataTypeID
							FROM
								Property
							WHERE
								[InstanceID] IN (0, @InstanceID) AND
								[PropertyName] = @PropertyName

							IF @DataTypeID = 3
								BEGIN
									SET @SQLStatement = '
										SELECT
											@InternalVariable1 = [' + @PropertyName + '],
											@InternalVariable2 = [' + @PropertyName + '_MemberId]
										FROM
											' + @CallistoDatabase + '.dbo.S_DS_' + @DimensionName + '
										WHERE
											[MemberId] = ' + CONVERT(nvarchar(20), @MemberID)

									EXEC sp_executesql @SQLStatement, N'@InternalVariable1 nvarchar(100) OUT, @InternalVariable2 bigint OUT', @InternalVariable1 = @PropertyValue OUT, @InternalVariable2 = @PropertyValue_MemberID OUT
								END
							ELSE
								BEGIN
									SET @SQLStatement = '
										SELECT
											 @InternalVariable = [' + @PropertyName + ']
										FROM
											' + @CallistoDatabase + '.dbo.S_DS_' + @DimensionName + '
										WHERE
											[MemberId] = ' + CONVERT(nvarchar(20), @MemberID)

									EXEC sp_executesql @SQLStatement, N'@InternalVariable nvarchar(100) OUT', @InternalVariable = @PropertyValue OUT
								END
						END

			END

	SET @Step = 'Return parameters'
		IF @DebugBM & 1 > 0
			SELECT
				[@MemberId] = @MemberId,
				[@MemberKey] = @MemberKey,
				[@PropertyName] = @PropertyName,
				[@PropertyValue] = @PropertyValue,
				[@PropertyValue_MemberID] = @PropertyValue_MemberID

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
--		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
