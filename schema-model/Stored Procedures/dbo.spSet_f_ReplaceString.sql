SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_f_ReplaceString]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000612,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spSet_f_ReplaceString',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSet_f_ReplaceString] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spSet_f_ReplaceString] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@SQLRow nvarchar(max) = '',

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
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update function f_ReplaceString',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Made generic.'
		IF @Version = '2.1.0.2161' SET @Description = 'Set INLINE = OFF if SQL 2019 or above.'

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
		IF @InstanceID <> @VersionID
			BEGIN
				SET @Message = 'This is just an example.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Set first generic part'
		SET @SQLStatement = 'ALTER FUNCTION [dbo].[f_ReplaceString]
(
	@InstanceID int,
	@VersionID int,
    @InputText nvarchar(max),
	@StringTypeBM int --1 = Code, 2 = Text
)
RETURNS nvarchar(max)
' + CASE WHEN SERVERPROPERTY('productversion') > '15' THEN 'WITH INLINE = OFF' ELSE '' END + '
AS
BEGIN'

	SET @Step = 'Set Instance specific part'
		IF CURSOR_STATUS('global','Instance_Cursor') >= -1 DEALLOCATE Instance_Cursor
		DECLARE Instance_Cursor CURSOR FOR
			
			SELECT DISTINCT
				[InstanceID],
				[VersionID]
			FROM
				[pcINTEGRATOR_Data].[dbo].[CheckString]
			ORDER BY
				[InstanceID],
				[VersionID]

			OPEN Instance_Cursor
			FETCH NEXT FROM Instance_Cursor INTO @InstanceID, @VersionID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@InstanceID] = @InstanceID, [@VersionID] = @VersionID
						SET @SQLStatement = @SQLStatement + '
	IF @InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND @VersionID = ' + CONVERT(nvarchar(15), @VersionID) + '
		BEGIN
			IF @StringTypeBM & 1 > 0 --Code
				BEGIN'
					SET @SQLRow = ''

					SELECT 
						@SQLRow = @SQLRow + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'SET @InputText = REPLACE(@InputText, char(' + CONVERT(nvarchar, CS.Input) + '), ' + CS.[Output] + ')' + CASE WHEN CS.Comment IS NULL THEN '' ELSE ' --' + CS.Comment END
					FROM
						[pcINTEGRATOR_Data].[dbo].[CheckString] CS
					WHERE
						CS.[InstanceID] = @InstanceID AND
						CS.[VersionID] = @VersionID AND
						CS.[StringTypeBM] & 1 > 0 AND
						CS.[ReplaceYN] <> 0
					ORDER BY
						CS.[Input]

					--SET @SQLRow = REPLACE(@SQLRow, '''', '''''''')
					IF @SQLRow = '' SET @SQLRow = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'SET @InputText = @InputText'

					SET @SQLStatement = @SQLStatement + @SQLRow + '
				END

			ELSE IF @StringTypeBM & 2 > 0 --Text
				BEGIN'
					SET @SQLRow = ''

					SELECT 
						@SQLRow = @SQLRow + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'SET @InputText = REPLACE(@InputText, char(' + CONVERT(nvarchar, CS.Input) + '), ' + CS.[Output] + ')' + CASE WHEN CS.Comment IS NULL THEN '' ELSE ' --' + CS.Comment END
					FROM
						[pcINTEGRATOR_Data].[dbo].[CheckString] CS
					WHERE
						CS.[InstanceID] = @InstanceID AND
						CS.[VersionID] = @VersionID AND
						CS.[StringTypeBM] & 2 > 0 AND
						CS.[ReplaceYN] <> 0
					ORDER BY
						CS.Input

					--SET @SQLRow = REPLACE(@SQLRow, '''', '''''''')
					IF @SQLRow = '' SET @SQLRow = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'SET @InputText = @InputText'

					SET @SQLStatement = @SQLStatement + @SQLRow + '
				END
		END'
					FETCH NEXT FROM Instance_Cursor INTO @InstanceID, @VersionID
				END

		CLOSE Instance_Cursor
		DEALLOCATE Instance_Cursor

	SET @Step = 'Set last generic part'
		SET @SQLStatement = @SQLStatement + '
	IF @StringTypeBM & 1 > 0 --Code
		BEGIN'
			SET @SQLRow = ''

			SELECT 
				@SQLRow = @SQLRow + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'SET @InputText = REPLACE(@InputText, char(' + CONVERT(nvarchar, CS.Input) + '), ' + CS.[Output] + ')' + CASE WHEN CS.Comment IS NULL THEN '' ELSE ' --' + CS.Comment END
			FROM
				[pcINTEGRATOR].[dbo].[@Template_CheckString] CS
			WHERE
				CS.[InstanceID] = 0 AND
				CS.[VersionID] = 0 AND
				CS.[StringTypeBM] & 1 > 0 AND
				CS.[ReplaceYN] <> 0
			ORDER BY
				CS.[Input]

			--SET @SQLRow = REPLACE(@SQLRow, '''', '''''''')
			IF @SQLRow = '' SET @SQLRow = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'SET @InputText = @InputText'

			SET @SQLStatement = @SQLStatement + @SQLRow + '
		END

	ELSE IF @StringTypeBM & 2 > 0 --Text
		BEGIN'
			SET @SQLRow = ''

			SELECT 
				@SQLRow = @SQLRow + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'SET @InputText = REPLACE(@InputText, char(' + CONVERT(nvarchar, CS.Input) + '), ' + CS.[Output] + ')' + CASE WHEN CS.Comment IS NULL THEN '' ELSE ' --' + CS.Comment END
			FROM
				[pcINTEGRATOR].[dbo].[@Template_CheckString] CS
			WHERE
				CS.[InstanceID] = 0 AND
				CS.[VersionID] = 0 AND
				CS.[StringTypeBM] & 2 > 0 AND
				CS.[ReplaceYN] <> 0
			ORDER BY
				CS.[Input]

			--SET @SQLRow = REPLACE(@SQLRow, '''', '''''''')
			IF @SQLRow = '' SET @SQLRow = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'SET @InputText = @InputText'

			SET @SQLStatement = @SQLStatement + @SQLRow + '
		END

	RETURN @InputText       
END'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement

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
