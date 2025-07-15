SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_ScanString]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@TableName nvarchar(100) = NULL,
	@FieldName_1 nvarchar(100) = NULL,
	@StringTypeBM_1 int = 1, --1 = Code, 2 = Text
	@FieldName_2 nvarchar(100) = '',
	@StringTypeBM_2 int = 1, --1 = Code, 2 = Text
	@FieldName_3 nvarchar(100) = '',
	@StringTypeBM_3 int = 1, --1 = Code, 2 = Text
	@FieldName_4 nvarchar(100) = '',
	@StringTypeBM_4 int = 1, --1 = Code, 2 = Text
	@FieldName_5 nvarchar(100) = '',
	@StringTypeBM_5 int = 1, --1 = Code, 2 = Text
	@FieldName_6 nvarchar(100) = '',
	@StringTypeBM_6 int = 1, --1 = Code, 2 = Text

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000614,
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
EXEC [sp_Tool_ScanString] @UserID=-10, @InstanceID=529, @VersionID=1001, @TableName = 'pcDATA_TECA..S_DS_GL_Project', @FieldName_1 = 'Label', @Debug=1

EXEC [sp_Tool_ScanString] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max) = '',

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
	@Version nvarchar(50) = '2.1.1.2169'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Scan for defined characters.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Made generic.'
		IF @Version = '2.1.1.2169' SET @Description = 'Fixed bug in initial queryc.'

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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'SP-Specific check'
		SET @SQLStatement = '

		INSERT INTO [pcINTEGRATOR_Log].[dbo].[ScanStringLog]
			(
			[InstanceID],
			[VersionID],
			[TableName],
			[FieldName],
			[ErrorMessage]
			)
		SELECT
			[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
			[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
			[TableName],
			[FieldName],
			[ErrorMessage]
		FROM
			(
			SELECT
				TableName = ''' + @TableName + ''',
				FieldName = ''' + @FieldName_1 + ''',
				ErrorMessage = [pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_1 + ', ' + CONVERT(nvarchar, @StringTypeBM_1) + ')
			FROM
				' + @TableName + '
			WHERE
				[pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_1 + ', ' + CONVERT(nvarchar, @StringTypeBM_1) + ') <> '''''

			IF @FieldName_2 <> '' SET @SQLStatement = @SQLStatement + '

			UNION SELECT
				TableName = ''' + @TableName + ''',
				FieldName = ''' + @FieldName_2 + ''',
				ErrorMessage = [pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_2 + ', ' + CONVERT(nvarchar, @StringTypeBM_2) + ')
			FROM
				' + @TableName + '
			WHERE
				[pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_2 + ', ' + CONVERT(nvarchar, @StringTypeBM_2) + ') <> '''''

			IF @FieldName_3 <> '' SET @SQLStatement = @SQLStatement + '

			UNION SELECT
				TableName = ''' + @TableName + ''',
				FieldName = ''' + @FieldName_3 + ''',
				ErrorMessage = [pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_3 + ', ' + CONVERT(nvarchar, @StringTypeBM_3) + ')
			FROM
				' + @TableName + '
			WHERE
				[pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_3 + ', ' + CONVERT(nvarchar, @StringTypeBM_3) + ') <> '''''

			IF @FieldName_4 <> '' SET @SQLStatement = @SQLStatement + '

			UNION SELECT
				TableName = ''' + @TableName + ''',
				FieldName = ''' + @FieldName_4 + ''',
				ErrorMessage = [pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_4 + ', ' + CONVERT(nvarchar, @StringTypeBM_4) + ')
			FROM
				' + @TableName + '
			WHERE
				[pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_4 + ', ' + CONVERT(nvarchar, @StringTypeBM_4) + ') <> '''''

			IF @FieldName_5 <> '' SET @SQLStatement = @SQLStatement + '

			UNION SELECT
				TableName = ''' + @TableName + ''',
				FieldName = ''' + @FieldName_5 + ''',
				ErrorMessage = [pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_5 + ', ' + CONVERT(nvarchar, @StringTypeBM_5) + ')
			FROM
				' + @TableName + '
			WHERE
				[pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_5 + ', ' + CONVERT(nvarchar, @StringTypeBM_5) + ') <> '''''

			IF @FieldName_6 <> '' SET @SQLStatement = @SQLStatement + '

			UNION SELECT
				TableName = ''' + @TableName + ''',
				FieldName = ''' + @FieldName_6 + ''',
				ErrorMessage = [pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_6 + ', ' + CONVERT(nvarchar, @StringTypeBM_6) + ')
			FROM
				' + @TableName + '
			WHERE
				[pcINTEGRATOR].[dbo].[f_ScanString](' + CONVERT(nvarchar(15), @InstanceID) + ',' + CONVERT(nvarchar(15), @VersionID) + ',' + @FieldName_6 + ', ' + CONVERT(nvarchar, @StringTypeBM_6) + ') <> '''''

		SET @SQLStatement = @SQLStatement + '
			) sub'

		IF @Debug <> 0 PRINT @SQLStatement

		EXEC (@SQLStatement)
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
