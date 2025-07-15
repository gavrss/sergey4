SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_SIE4_InsertTrans]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@Param nvarchar(50) = NULL,
	@Seq nvarchar(50) = NULL,
	@Ver nvarchar(50) = NULL,
	@Trans int = NULL, --Not from file, calculated counter per @Ver
	@Account nvarchar(50) = NULL,
	@DimCode_01 nvarchar(50) = NULL,
	@ObjectCode_01 nvarchar(50) = NULL,
	@DimCode_02 nvarchar(50) = NULL,
	@ObjectCode_02 nvarchar(50) = NULL,
	@DimCode_03 nvarchar(50) = NULL,
	@ObjectCode_03 nvarchar(50) = NULL,
	@DimCode_04 nvarchar(50) = NULL,
	@ObjectCode_04 nvarchar(50) = NULL,
	@DimCode_05 nvarchar(50) = NULL,
	@ObjectCode_05 nvarchar(50) = NULL,
	@DimCode_06 nvarchar(50) = NULL,
	@ObjectCode_06 nvarchar(50) = NULL,
	@DimCode_07 nvarchar(50) = NULL,
	@ObjectCode_07 nvarchar(50) = NULL,
	@DimCode_08 nvarchar(50) = NULL,
	@ObjectCode_08 nvarchar(50) = NULL,
	@DimCode_09 nvarchar(50) = NULL,
	@ObjectCode_09 nvarchar(50) = NULL,
	@DimCode_10 nvarchar(50) = NULL,
	@ObjectCode_10 nvarchar(50) = NULL,
	@DimCode_11 nvarchar(50) = NULL,
	@ObjectCode_11 nvarchar(50) = NULL,
	@DimCode_12 nvarchar(50) = NULL,
	@ObjectCode_12 nvarchar(50) = NULL,
	@DimCode_13 nvarchar(50) = NULL,
	@ObjectCode_13 nvarchar(50) = NULL,
	@DimCode_14 nvarchar(50) = NULL,
	@ObjectCode_14 nvarchar(50) = NULL,
	@DimCode_15 nvarchar(50) = NULL,
	@ObjectCode_15 nvarchar(50) = NULL,
	@DimCode_16 nvarchar(50) = NULL,
	@ObjectCode_16 nvarchar(50) = NULL,
	@DimCode_17 nvarchar(50) = NULL,
	@ObjectCode_17 nvarchar(50) = NULL,
	@DimCode_18 nvarchar(50) = NULL,
	@ObjectCode_18 nvarchar(50) = NULL,
	@DimCode_19 nvarchar(50) = NULL,
	@ObjectCode_19 nvarchar(50) = NULL,
	@DimCode_20 nvarchar(50) = NULL,
	@ObjectCode_20 nvarchar(50) = NULL,
	@Amount decimal(18,2) = NULL,
	@Date int = NULL, --If NULL in file, copy from #Ver
	@TransDescription nvarchar(255) = NULL,
	@RowCountYN bit = 0,

	@JSON_table nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000174,
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
--EXEC [spPortalSet_SIE4_InsertTrans] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 1, @Param = '#TRANS', @Seq = 'A', @Ver = '1', @Trans = 1, @Account = '2016', @DimCode_01 = '1', @ObjectCode_01 = '01', @Amount = -202300.00, @Date = 20160124, @Debug = 1
--EXEC [spPortalSet_SIE4_InsertTrans] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 2, @Param = '#TRANS', @Seq = 'A', @Ver = '1', @Trans = 1, @Account = '2016', @DimCode_01 = '1', @ObjectCode_01 = '01', @Amount = -202300.00, @Date = 20160124, @Debug = 1
--EXEC [spPortalSet_SIE4_InsertTrans] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 3, @Param = '#TRANS', @Seq = 'A', @Ver = '1', @Trans = 1, @Account = '2016', @DimCode_01 = '1', @ObjectCode_01 = '01', @Amount = -202300.00, @Date = 20160124, @RowCountYN = 1, @Debug = 1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalSet_SIE4_InsertTrans',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"404"},
		{"TKey":"VersionID", "TValue":"1003"},
		{"TKey":"JobID", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"Param":"#VER", "Seq":"A", "Ver":"1", "Trans":"1", "Account":"2016", "DimCode_01":"1", "ObjectCode_01":"01", "Amount":"-202300.00", "Date":"20160124", "TransDescription":"Epicor royalty report January 2016"},
		{"Param":"#VER", "Seq":"A", "Ver":"2", "Trans":"1", "Account":"2016", "DimCode_01":"1", "ObjectCode_01":"01", "Amount":"-202300.00", "Date":"20160125", "TransDescription":"Epicor royalty report January 2016"},
		{"Param":"#VER", "Seq":"A", "Ver":"3", "Trans":"1", "Account":"2016", "DimCode_01":"1", "ObjectCode_01":"01", "Amount":"-202300.00", "Date":"20160126", "TransDescription":"Epicor royalty report January 2016"},
		{"Param":"#VER", "Seq":"A", "Ver":"4", "Trans":"1", "Account":"2016", "DimCode_01":"1", "ObjectCode_01":"01", "Amount":"-202300.00", "Date":"20160127", "TransDescription":"Epicor royalty report January 2016"}
		]'

EXEC [spPortalSet_SIE4_InsertTrans] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert SIE4 transactions',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, introduced @JSON_table, changed database to [pcINTEGRATOR_Data].'

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

	SET @Step = 'Insert table or Row'
		IF @JSON_table IS NOT NULL	
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].SIE4_Trans
					(
					[InstanceID],
					[JobID],
					[Param],
					[Seq],
					[Ver],
					[Trans],
					[Account],
					[DimCode_01],
					[ObjectCode_01],
					[DimCode_02],
					[ObjectCode_02],
					[DimCode_03],
					[ObjectCode_03],
					[DimCode_04],
					[ObjectCode_04],
					[DimCode_05],
					[ObjectCode_05],
					[DimCode_06],
					[ObjectCode_06],
					[DimCode_07],
					[ObjectCode_07],
					[DimCode_08],
					[ObjectCode_08],
					[DimCode_09],
					[ObjectCode_09],
					[DimCode_10],
					[ObjectCode_10],
					[DimCode_11],
					[ObjectCode_11],
					[DimCode_12],
					[ObjectCode_12],
					[DimCode_13],
					[ObjectCode_13],
					[DimCode_14],
					[ObjectCode_14],
					[DimCode_15],
					[ObjectCode_15],
					[DimCode_16],
					[ObjectCode_16],
					[DimCode_17],
					[ObjectCode_17],
					[DimCode_18],
					[ObjectCode_18],
					[DimCode_19],
					[ObjectCode_19],
					[DimCode_20],
					[ObjectCode_20],
					[Amount],
					[Date],
					[Description],
					[InsertedBy]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[JobID] = @JobID,
					[Param] = [Param],
					[Seq] = [Seq],
					[Ver] = [Ver],
					[Trans],
					[Account],
					[DimCode_01],
					[ObjectCode_01],
					[DimCode_02],
					[ObjectCode_02],
					[DimCode_03],
					[ObjectCode_03],
					[DimCode_04],
					[ObjectCode_04],
					[DimCode_05],
					[ObjectCode_05],
					[DimCode_06],
					[ObjectCode_06],
					[DimCode_07],
					[ObjectCode_07],
					[DimCode_08],
					[ObjectCode_08],
					[DimCode_09],
					[ObjectCode_09],
					[DimCode_10],
					[ObjectCode_10],
					[DimCode_11],
					[ObjectCode_11],
					[DimCode_12],
					[ObjectCode_12],
					[DimCode_13],
					[ObjectCode_13],
					[DimCode_14],
					[ObjectCode_14],
					[DimCode_15],
					[ObjectCode_15],
					[DimCode_16],
					[ObjectCode_16],
					[DimCode_17],
					[ObjectCode_17],
					[DimCode_18],
					[ObjectCode_18],
					[DimCode_19],
					[ObjectCode_19],
					[DimCode_20],
					[ObjectCode_20],
					[Amount],
					[Date] = [Date],
					[Description] = [TransDescription],
					[InsertedBy] = @UserName
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[Param] nvarchar(50) COLLATE database_default,
					[Seq] nvarchar(50) COLLATE database_default,
					[Ver] nvarchar(50) COLLATE database_default,
					[Trans] int,
					[Account] nvarchar(50) COLLATE database_default,
					[DimCode_01] nvarchar(50) COLLATE database_default,
					[ObjectCode_01] nvarchar(50) COLLATE database_default,
					[DimCode_02] nvarchar(50) COLLATE database_default,
					[ObjectCode_02] nvarchar(50) COLLATE database_default,
					[DimCode_03] nvarchar(50) COLLATE database_default,
					[ObjectCode_03] nvarchar(50) COLLATE database_default,
					[DimCode_04] nvarchar(50) COLLATE database_default,
					[ObjectCode_04] nvarchar(50) COLLATE database_default,
					[DimCode_05] nvarchar(50) COLLATE database_default,
					[ObjectCode_05] nvarchar(50) COLLATE database_default,
					[DimCode_06] nvarchar(50) COLLATE database_default,
					[ObjectCode_06] nvarchar(50) COLLATE database_default,
					[DimCode_07] nvarchar(50) COLLATE database_default,
					[ObjectCode_07] nvarchar(50) COLLATE database_default,
					[DimCode_08] nvarchar(50) COLLATE database_default,
					[ObjectCode_08] nvarchar(50) COLLATE database_default,
					[DimCode_09] nvarchar(50) COLLATE database_default,
					[ObjectCode_09] nvarchar(50) COLLATE database_default,
					[DimCode_10] nvarchar(50) COLLATE database_default,
					[ObjectCode_10] nvarchar(50) COLLATE database_default,
					[DimCode_11] nvarchar(50) COLLATE database_default,
					[ObjectCode_11] nvarchar(50) COLLATE database_default,
					[DimCode_12] nvarchar(50) COLLATE database_default,
					[ObjectCode_12] nvarchar(50) COLLATE database_default,
					[DimCode_13] nvarchar(50) COLLATE database_default,
					[ObjectCode_13] nvarchar(50) COLLATE database_default,
					[DimCode_14] nvarchar(50) COLLATE database_default,
					[ObjectCode_14] nvarchar(50) COLLATE database_default,
					[DimCode_15] nvarchar(50) COLLATE database_default,
					[ObjectCode_15] nvarchar(50) COLLATE database_default,
					[DimCode_16] nvarchar(50) COLLATE database_default,
					[ObjectCode_16] nvarchar(50) COLLATE database_default,
					[DimCode_17] nvarchar(50) COLLATE database_default,
					[ObjectCode_17] nvarchar(50) COLLATE database_default,
					[DimCode_18] nvarchar(50) COLLATE database_default,
					[ObjectCode_18] nvarchar(50) COLLATE database_default,
					[DimCode_19] nvarchar(50) COLLATE database_default,
					[ObjectCode_19] nvarchar(50) COLLATE database_default,
					[DimCode_20] nvarchar(50) COLLATE database_default,
					[ObjectCode_20] nvarchar(50) COLLATE database_default,
					[Amount] decimal(18,2),
					[Date] int,
					[TransDescription] nvarchar(255) COLLATE database_default
					)

				SELECT @Inserted = @Inserted + @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].SIE4_Trans
					(
					[InstanceID],
					[JobID],
					[Param],
					[Seq],
					[Ver],
					[Trans],
					[Account],
					[DimCode_01],
					[ObjectCode_01],
					[DimCode_02],
					[ObjectCode_02],
					[DimCode_03],
					[ObjectCode_03],
					[DimCode_04],
					[ObjectCode_04],
					[DimCode_05],
					[ObjectCode_05],
					[DimCode_06],
					[ObjectCode_06],
					[DimCode_07],
					[ObjectCode_07],
					[DimCode_08],
					[ObjectCode_08],
					[DimCode_09],
					[ObjectCode_09],
					[DimCode_10],
					[ObjectCode_10],
					[DimCode_11],
					[ObjectCode_11],
					[DimCode_12],
					[ObjectCode_12],
					[DimCode_13],
					[ObjectCode_13],
					[DimCode_14],
					[ObjectCode_14],
					[DimCode_15],
					[ObjectCode_15],
					[DimCode_16],
					[ObjectCode_16],
					[DimCode_17],
					[ObjectCode_17],
					[DimCode_18],
					[ObjectCode_18],
					[DimCode_19],
					[ObjectCode_19],
					[DimCode_20],
					[ObjectCode_20],
					[Amount],
					[Date],
					[Description],
					[InsertedBy]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[JobID] = @JobID,
					[Param] = @Param,
					[Seq] = @Seq,
					[Ver] = @Ver,
					[Trans] = @Trans,
					[Account] = @Account,
					[DimCode_01] = @DimCode_01,
					[ObjectCode_01] = @ObjectCode_01,
					[DimCode_02] = @DimCode_02,
					[ObjectCode_02] = @ObjectCode_02,
					[DimCode_03] = @DimCode_03,
					[ObjectCode_03] = @ObjectCode_03,
					[DimCode_04] = @DimCode_04,
					[ObjectCode_04] = @ObjectCode_04,
					[DimCode_05] = @DimCode_05,
					[ObjectCode_05] = @ObjectCode_05,
					[DimCode_06] = @DimCode_06,
					[ObjectCode_06] = @ObjectCode_06,
					[DimCode_07] = @DimCode_07,
					[ObjectCode_07] = @ObjectCode_07,
					[DimCode_08] = @DimCode_08,
					[ObjectCode_08] = @ObjectCode_08,
					[DimCode_09] = @DimCode_09,
					[ObjectCode_09] = @ObjectCode_09,
					[DimCode_10] = @DimCode_10,
					[ObjectCode_10] = @ObjectCode_10,
					[DimCode_11] = @DimCode_11,
					[ObjectCode_11] = @ObjectCode_11,
					[DimCode_12] = @DimCode_12,
					[ObjectCode_12] = @ObjectCode_12,
					[DimCode_13] = @DimCode_13,
					[ObjectCode_13] = @ObjectCode_13,
					[DimCode_14] = @DimCode_14,
					[ObjectCode_14] = @ObjectCode_14,
					[DimCode_15] = @DimCode_15,
					[ObjectCode_15] = @ObjectCode_15,
					[DimCode_16] = @DimCode_16,
					[ObjectCode_16] = @ObjectCode_16,
					[DimCode_17] = @DimCode_17,
					[ObjectCode_17] = @ObjectCode_17,
					[DimCode_18] = @DimCode_18,
					[ObjectCode_18] = @ObjectCode_18,
					[DimCode_19] = @DimCode_19,
					[ObjectCode_19] = @ObjectCode_19,
					[DimCode_20] = @DimCode_20,
					[ObjectCode_20] = @ObjectCode_20,
					[Amount] = @Amount,
					[Date] = @Date,
					[Description] = @TransDescription,
					[InsertedBy] = @UserName

				SELECT @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Return Debug'
		IF @Debug <> 0
			SELECT
				*
			FROM
				[pcINTEGRATOR_Data].[dbo].[SIE4_Trans]
			WHERE
				[JobID] = @JobID

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Return Statistics'
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

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
