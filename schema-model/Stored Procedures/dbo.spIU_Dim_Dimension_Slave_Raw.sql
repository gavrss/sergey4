SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Dimension_Slave_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@DimensionName nvarchar(100) = NULL,
	@StorageTypeBM int = 4,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000659,
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
EXEC [spIU_Dim_Dimension_Slave_Raw] @UserID = -10, @InstanceID = 476, @VersionID = 1025, @DimensionID = -31, @Debug = 1
EXEC [spIU_Dim_Dimension_Slave_Raw] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @DimensionID = -31, @Debug = 1

EXEC [spIU_Dim_Dimension_Slave_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF
--SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceTypeBM int,
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@MasterDimensionID int,
	@MasterDimensionName nvarchar(100),

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get a list of dimension members for selected slave dimension, copied from defined master dimension.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2151' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2153' SET @Description = 'Made generic for Callisto.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

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
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = ETLDatabase
		FROM
			pcINTEGRATOR_Data.dbo.[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @DimensionName IS NULL
			SELECT @DimensionName = DimensionName FROM [Dimension] WHERE DimensionID = @DimensionID
		ELSE IF @DimensionID IS NULL
			SELECT @DimensionID = DimensionID FROM [Dimension] WHERE DimensionName = @DimensionName	AND InstanceID IN (0, @InstanceID)	

		SELECT @MasterDimensionID = MasterDimensionID FROM [Dimension] WHERE DimensionID = @DimensionID
		SELECT @MasterDimensionName = DimensionName FROM [Dimension] WHERE DimensionID = @MasterDimensionID

		SELECT
			@SourceTypeBM = SUM(SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				SourceTypeBM
			FROM
				SourceType ST
				INNER JOIN [Source] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.SourceTypeID = ST.SourceTypeID
			) sub

		IF OBJECT_ID (N'tempdb..#Dimension_Slave_Members', N'U') IS NULL SET @CalledYN = 0

		IF @Debug <> 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@CalledYN] = @CalledYN, [@SourceTypeBM] = @SourceTypeBM

	SET @Step = 'Create temp table #Dimension_Slave_Members_Raw'
	--ToDo add common properties
		CREATE TABLE [#Dimension_Slave_Members_Raw]
			(
			[MemberId] bigint,
			[MemberKey] nvarchar (100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar (512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar (1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[SBZ] bit,
			[Source] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,
			[Parent] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

	SET @Step = 'Fill table #Dimension_Slave_Members_Raw'
		IF @StorageTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO [#Dimension_Slave_Members_Raw]
						(
						[MemberId],
						[MemberKey],
						[Description],
						[HelpText],
						[NodeTypeBM],
						[SBZ],
						[Source],
						[Synchronized],
						[Parent],
						[SortOrder]
						)
					SELECT 
						[MemberId] = D.[MemberId],
						[MemberKey] = D.[Label],
						[Description] = D.[Description],
						[HelpText] = D.[HelpText],
						[NodeTypeBM] = CASE D.RNodeType WHEN ''L'' THEN 1 WHEN ''P'' THEN 18 WHEN ''LC'' THEN 9 WHEN ''PC'' THEN 10 ELSE 1 END,
						[SBZ] = D.[SBZ],
						[Source] = D.[Source],
						[Synchronized] = D.[Synchronized],
						[Parent] = P.[Label],
						[SortOrder] = H.SequenceNumber
					FROM
						' + @CallistoDatabase + '..S_DS_' + @MasterDimensionName + ' D
						LEFT JOIN ' + @CallistoDatabase + '..S_HS_' + @MasterDimensionName + '_' + @MasterDimensionName + ' H ON H.MemberId = D.MemberId
						LEFT JOIN ' + @CallistoDatabase + '..S_DS_' + @MasterDimensionName + ' P ON P.MemberID = H.ParentMemberID'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Dimension_Slave_Members_Raw',
					*
				FROM
					#Dimension_Slave_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END,
					[SortOrder]

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [#Dimension_Slave_Members]
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[SBZ],
					[Source],
					[Synchronized],
					[Parent]
					)
				SELECT TOP 1000000
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[SBZ],
					[Source],
					[Synchronized],
					[Parent]
				FROM
					#Dimension_Slave_Members_Raw

				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Dimension_Slave_Members_Raw

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		SET @ProcedureName = @ProcedureName + ' (' + @DimensionName + ')'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	SET @ProcedureName = @ProcedureName + ' (' + @DimensionName + ')'
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
