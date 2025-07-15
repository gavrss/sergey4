SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_FullAccount]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ConversionID int = NULL, --Valid for @ResultTypeBM (1,2,4,8, 16)

	@ResultTypeBM int = 3,
		 --  1 = List of FullAccount Definition
		 --  2 = List of Dimension members
		 --  4 = List of FullAccount settings
		 --  8 = List of Wildcard settings
		 -- 16 = List of Static settings for selected ConversionID/DataClassID
		 -- 32 = List of all conversion options defined
		 -- 64 = List of relevant DataClasses
		 --128 = List of all dimensions for selected DataClass

	@VerifiedBM int = 3,
		-- 1 = List of Not verified
		-- 2 = List of Verified

	@AdvancedMappingYN bit = 1,

	@DimensionList nvarchar(1024) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000474,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM = 3 (include high and low prio, exclude sub routines)
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC spPortalAdminGet_FullAccount @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6332, @AdvancedMappingYN  = 0, @ResultTypeBM=255, @VerifiedBM = 3
EXEC spPortalAdminGet_FullAccount @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6332, @AdvancedMappingYN  = 1, @ResultTypeBM=255, @VerifiedBM = 3
EXEC spPortalAdminGet_FullAccount @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6333, @AdvancedMappingYN  = 1, @ResultTypeBM=255, @VerifiedBM = 3
EXEC spPortalAdminGet_FullAccount @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6334, @AdvancedMappingYN  = 0, @ResultTypeBM=255, @VerifiedBM = 3
EXEC spPortalAdminGet_FullAccount @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6334, @AdvancedMappingYN  = 1, @ResultTypeBM=255, @VerifiedBM = 3

EXEC [spPortalAdminGet_FullAccount] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@AccountColumnNo nvarchar(20),
	@DebugSub bit = 0,
	@SQLStatement nvarchar(max),
	@SQLStatement_Select nvarchar(1000) = '',
	@DataClassID int, --Valid for @ResultTypeBM (16, 128)
	@DataClassTypeID int,

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
	@Version nvarchar(50) = '2.0.3.2151'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns data for FullAccount settings',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2147' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Made generic.'
		IF @Version = '2.0.3.2151' SET @Description = 'Changed SP-call for ResultTypeBM = 2.'

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
			@DataClassTypeID = DataClassTypeID,
			@DataClassID = FullAccountDataClassID
		FROM
			DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassID = @ConversionID

		SELECT
			@AccountColumnNo = CASE WHEN SortOrder <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), SortOrder)
		FROM
			DataClass_Dimension
		WHERE
			DataClassID = @ConversionID AND
			DimensionID = -1

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create and fill table #FADimensionList'
		IF @DataClassTypeID = -7
			BEGIN
				CREATE TABLE #FADimensionList
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[StorageTypeBM] int,
					[SortOrder] int,
					[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Destination] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[SelectYN] bit,
					[ReadSecurityEnabledYN] bit
					)

				EXEC spGet_FullAccount_DimensionList @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ConversionID=@ConversionID, @AdvancedMappingYN=@AdvancedMappingYN

				IF @DebugBM & 2 > 0 SELECT TempTable = '#FADimensionList', * FROM #FADimensionList ORDER BY SortOrder
			END

	SET @Step = 'FullAccount definition'
		IF @ResultTypeBM & 1 > 0 AND @DataClassTypeID = -7
			BEGIN
				SELECT 
					[ResultTypeBM] = 1,
					[Source],
					[Destination],
					[DimensionID],
					[DimensionName]
				FROM 
					#FADimensionList DL
				ORDER BY
					SortOrder

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0 AND @ConversionID NOT IN (0) AND @DataClassTypeID = -7
			BEGIN
				EXEC [spGet_DataClass_DimensionMember] @UserID = @UserID,  @InstanceID = @InstanceID, @VersionID = @VersionID, @DataClassID = @ConversionID, @DimensionList = @DimensionList, @Debug = @DebugSub --, @PropertyList = @PropertyList, @AssignmentID = @AssignmentID, @OnlySecuredDimYN = @OnlySecuredDimYN, @Selected = @Selected OUT
			END

	SET @Step = 'Set @SQLStatement_Select'
		IF @ResultTypeBM & 12 > 0 AND @DataClassTypeID = -7
			SELECT
				@SQLStatement_Select = @SQLStatement_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [Column] + '],'
			FROM
				(
				SELECT
					[Column] = [Source],
					[SortOrder] = DL.[SortOrder] * 100 + 1
				FROM 
					#FADimensionList DL

				UNION SELECT
					[Column] = [Destination],
					[SortOrder] = DL.[SortOrder] * 100 + 2
				FROM 
					#FADimensionList DL
				WHERE
					DL.SortOrder >= 0 AND
					@AdvancedMappingYN <> 0
				) sub
			ORDER BY
				[SortOrder]

	SET @Step = 'List of FullAccount settings'
		IF @ResultTypeBM & 4 > 0 AND @DataClassTypeID = -7
			BEGIN
				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 4,
						[SourceString],' + @SQLStatement_Select + '
						[Inserted],
						[Verified],
						[VerifiedByUserID],
						[VerifiedByUserName] = U.[UserNameDisplay]
					FROM
						[pcINTEGRATOR_Data].[dbo].[FullAccount] FA
						LEFT JOIN pcINTEGRATOR..[User] U ON U.UserID = FA.[VerifiedByUserID]
					WHERE
						FA.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						FA.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
						FA.[DataClassID] = ' + CONVERT(nvarchar(15), @ConversionID) + ' AND
						FA.[WildCardYN] = 0 AND
						((FA.[Verified] IS NULL AND ' + CONVERT(nvarchar(15), @VerifiedBM) + ' & 1 > 0) OR
						(FA.[Verified] IS NOT NULL AND ' + CONVERT(nvarchar(15), @VerifiedBM) + ' & 2 > 0))'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of Wildcard settings'
		IF @ResultTypeBM & 8 > 0 AND @AdvancedMappingYN <> 0 AND @DataClassTypeID = -7
			BEGIN
				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 8,
						[SortOrder],' + @SQLStatement_Select + '
						[Inserted],
						[Verified],
						[VerifiedByUserID],
						[VerifiedByUserName] = U.[UserNameDisplay]
					FROM
						[pcINTEGRATOR_Data].[dbo].[FullAccount] FA
						LEFT JOIN pcINTEGRATOR..[User] U ON U.UserID = FA.[VerifiedByUserID]
					WHERE
						FA.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						FA.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
						FA.[DataClassID] = ' + CONVERT(nvarchar(15), @ConversionID) + ' AND
						FA.[WildCardYN] <> 0 AND
						((FA.[Verified] IS NULL AND ' + CONVERT(nvarchar(15), @VerifiedBM) + ' & 1 > 0) OR
						(FA.[Verified] IS NOT NULL AND ' + CONVERT(nvarchar(15), @VerifiedBM) + ' & 2 > 0))
					ORDER BY
						[SortOrder]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of Static settings for selected ConversionID/DataClassID'
		IF @ResultTypeBM & 16 > 0 AND @DataClassID IS NOT NULL AND @ConversionID IS NOT NULL
			BEGIN
				IF @ConversionID = 0
					BEGIN
						SELECT
							ResultTypeBM = 16,
							DimensionID = NULL,
							DimensionName = NULL,
							Conversion_MemberKey = NULL
						FROM
							[@Template_DataClass_Dimension] DCD
						WHERE
							DCD.DataClassID = -999

						SET @Selected = @Selected + @@ROWCOUNT
					END

				ELSE IF @DataClassTypeID = -7 --FullAccount
					BEGIN 
						SELECT
							ResultTypeBM = 16,
							DCD.DimensionID,
							D.DimensionName,
							Conversion_MemberKey = ISNULL(FADCD.Conversion_MemberKey, '*')
						FROM
							DataClass DC
							INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = DC.DataClassID AND DCD.DimensionID NOT IN (-8)
							INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID
							LEFT JOIN DataClass_Dimension FADCD ON FADCD.DataClassID = @ConversionID AND FADCD.DimensionID = DCD.DimensionID AND FADCD.SortOrder = 0
						WHERE
							DC.InstanceID = @InstanceID AND
							DC.VersionID = @VersionID AND
							DC.DataClassID = @DataClassID AND
							DC.DataClassTypeID = -1 AND
							NOT EXISTS (SELECT 1 FROM #FADimensionList DL WHERE DL.DimensionID = DCD.DimensionID)
						ORDER BY
							D.DimensionName

						SET @Selected = @Selected + @@ROWCOUNT
					END

				ELSE
					BEGIN 
						SELECT
							ResultTypeBM = 16,
							DCD.DimensionID,
							D.DimensionName,
							Conversion_MemberKey = ISNULL(FADCD.Conversion_MemberKey, '*')
						FROM
							DataClass DC
							INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = DC.DataClassID AND DCD.DimensionID NOT IN (-8)
							INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID
							LEFT JOIN DataClass_Dimension FADCD ON FADCD.DataClassID = @ConversionID AND FADCD.DimensionID = DCD.DimensionID AND FADCD.SortOrder = 0
						WHERE
							DC.InstanceID = @InstanceID AND
							DC.VersionID = @VersionID AND
							DC.DataClassID = @DataClassID AND
							DC.DataClassTypeID = -1
						ORDER BY
							D.DimensionName

						SET @Selected = @Selected + @@ROWCOUNT
					END
			END

	SET @Step = 'All conversion options defined'
		IF @ResultTypeBM & 32 > 0 
			BEGIN
				SELECT 
					[ResultTypeBM] = 32,
					[ConversionID] = sub.[ConversionID],
					[ConversionName] = sub.[FADataClassName],
					[ConversionDescription] = sub.[FADataClassDescription],
					[ConversionType] = sub.[DataClassType],
					[DataClassName] = sub.[DataClassName]
				FROM
					(
					SELECT
						[ConversionID] = 0,
						[FADataClassName] = 'No dimension conversion',
						[FADataClassDescription] = 'No dimension conversion',
						[DataClassType] = 'No conversion',
						[DataClassName] = '*',
						SortOrder = 1

					UNION SELECT 
						[ConversionID] = FADC.[DataClassID],
						[FADataClassName] = FADC.[DataClassName],
						[FADataClassDescription] = FADC.[DataClassDescription],
						[DataClassType] = DCT.[DataClassTypeName],
						[DataClassName] = DC.DataClassName,
						SortOrder = 3
					FROM 
						[pcINTEGRATOR_Data].[dbo].[DataClass] FADC
						INNER JOIN [pcINTEGRATOR].[dbo].[DataClassType] DCT ON DCT.DataClassTypeID = FADC.DataClassTypeID
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = @InstanceID AND DC.[VersionID] = @VersionID AND DC.DataClassID = FADC.FullAccountDataClassID AND DC.[DataClassTypeID] IN (-1) AND DC.[SelectYN] <> 0 AND DC.DeletedID IS NULL
					WHERE 
						FADC.[InstanceID] = @InstanceID AND
						FADC.[VersionID] = @VersionID AND
						FADC.[DataClassTypeID] IN (-7, -8) AND
						FADC.[SelectYN] <> 0 AND
						FADC.[DeletedID] IS NULL
					) sub
				ORDER BY
					SortOrder,
					DataClassName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of all DataClasses of DataClassTypeID = -1'
		IF @ResultTypeBM & 64 > 0 
			BEGIN
				SELECT
					ResultTypeBM = 64,
					DC.DataClassID,
					DC.DataClassName,
					DC.DataClassDescription
				FROM
					DataClass DC
				WHERE
					DC.InstanceID = @InstanceID AND
					DC.VersionID = @VersionID AND
					DC.DataClassTypeID = -1
				ORDER BY
					DC.DataClassName
			END

	SET @Step = 'List of all dimensions för selected DataClassID'
		IF @ResultTypeBM & 128 > 0 AND @DataClassID IS NOT NULL AND @ConversionID IS NOT NULL
			BEGIN
				SELECT
					ResultTypeBM = 128,
					DCD.DimensionID,
					D.DimensionName,
					D.DimensionDescription
				FROM
					DataClass DC
					INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = DC.DataClassID AND DCD.DimensionID NOT IN (-8)
					INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID
				WHERE
					DC.InstanceID = @InstanceID AND
					DC.VersionID = @VersionID AND
					DC.DataClassID = @DataClassID AND
					DC.DataClassTypeID = -1
				ORDER BY
					D.DimensionName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp table'
		IF @DataClassTypeID = -7 DROP TABLE #FADimensionList

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

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
