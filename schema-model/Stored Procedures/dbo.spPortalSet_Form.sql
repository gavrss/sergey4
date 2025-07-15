SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_Form]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@FormID int = NULL, --Mandatory
	@FormPartID int = NULL, --Mandatory
	@JSON_table nvarchar(MAX) = NULL, --Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000765,
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

EXEC spPortalSet_Form @FormID='-4',@FormPartID='1',@InstanceID='515',@UserID='9632',@VersionID='1040', @DebugBM=15,
@JSON_table='[{"BusinessRuleID":"12295","Name":"New BR Test77","Description":"New BR Test77","BR_TypeID":"14","SortOrder":"0","Active":"true"}]'

EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"DebugBM","TValue":"0"},
{"TKey":"InstanceID","TValue":"515"},{"TKey":"UserID","TValue":"-10"},
{"TKey":"FormID","TValue":"-4"},{"TKey":"VersionID","TValue":"1040"},
{"TKey":"FormPartID","TValue":"1"}
]', @JSON_table='[{"SortOrder":"20","Name":"New BR Test6","Description":"New BR Test6","Active":"true"}]',
@ProcedureName='spPortalSet_Form', @XML=null

-- create  ic matching
EXEC [spRun_Procedure_KeyValuePair] 
@JSON='[{"TKey":"InstanceID","TValue":"515"},{"TKey":"UserID","TValue":"9632"},{"TKey":"FormID","TValue":"-5"},
	{"TKey":"VersionID","TValue":"1040"},{"TKey":"FormPartID","TValue":"1"},{"TKey":"DebugBM","TValue":"15"}]', 
	@JSON_table='[{"Name":"Test IC","Source":"Journal","Filter":"Account=NONE","Rule_ICmatchID":"1019",
	"Account for auto difference":"AccountCategory=NONE","Account for manual difference":"AccountCategory=NONE"}]', 
@ProcedureName='spPortalSet_Form', @XML=null  

-- create IC Counterpart Identification - Rule
EXEC [spRun_Procedure_KeyValuePair] 
@JSON='[{"TKey":"InstanceID","TValue":"515"},{"TKey":"UserID","TValue":"9632"},	{"TKey":"FormID","TValue":"-4"},
	{"TKey":"VersionID","TValue":"1040"},{"TKey":"FormPartID","TValue":"2"},{"TKey":"DebugBM","TValue":"15"}]', 
	@JSON_table='[{"BR14_StepID":"1004","BusinessRuleID":"12188","Method":"Fixed","IC Counterpart set to":"[Account].[Entity]","Comment":"test update.."}]', 
@ProcedureName='spPortalSet_Form', @XML=null

DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"Comment" : "Testing1", "Conso ID": "1002", "DeleteYN": "0"}
	]'

EXEC [dbo].[spPortalSet_Form] 
	@UserID = -10,
	@InstanceID = 527,
	@VersionID = 1055,
	@FormID = -2,
	@FormPartID = 1,
	@JSON_table = @JSON_table,
	@DebugBM = 3

EXEC [spPortalSet_Form] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(max),
	@FormPartColumn nvarchar(100),
	@DataType nvarchar(20),
	@SQLSelect nvarchar(4000) = '',
	@SQLSelectDataType nvarchar(4000) = '',
	@TableName nvarchar(100),
	@SQLUpdateJoin nvarchar(4000) = '',
	@SQLUpdateSet nvarchar(4000) = '',
	@SQLInsert nvarchar(4000) = '',
	@SQLKey nvarchar(1000) = '',
	@SQLKeyColumnName nvarchar(100),	
	@InsertedID int = NULL,
	@SQLNotExist nvarchar(4000) = '',

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
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain selected Form',
			@MandatoryParameter = 'FormID|FormPartID' --Without @, separated by |

		IF @Version = '2.1.1.2170' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2171' SET @Description = 'Minor bug fixes.'

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
			@TableName = [DataObjectName]
		FROM
			[pcINTEGRATOR].[dbo].[FormPart]
		WHERE
			[InstanceID] IN (0, @InstanceID) AND
			[VersionID] IN (0, @VersionID) AND
			[FormID] = @FormID AND
			[FormPartID] = @FormPartID

		IF @DebugBM & 2 > 0
			SELECT
				[@TableName] = @TableName

	SET @Step = 'Create and fill temp table #ColumnList'
		SELECT
			FPC.[FormPartColumn],
			FPC.[DataObjectColumnName],
			FPC.[KeyYN],
			FPC.[EnabledYN],
			FPC.[IdentityYN],
			FPC.[NullYN],
			FPC.[DataTypeID],
			FPC.[DefaultValue],
			[DataType] = CASE WHEN DT.[DataTypeCode] = 'nvarchar' THEN 'nvarchar(100)' ELSE DT.[DataTypeCode] END,
			FPC.[SortOrder]
		INTO
			#ColumnList
		FROM
			pcINTEGRATOR..[FormPartColumn] FPC
			INNER JOIN [pcINTEGRATOR].[dbo].[DataType] DT ON DT.[InstanceID] IN (0, FPC.InstanceID) AND DT.DataTypeID = FPC.DataTypeID
		WHERE
			FPC.[InstanceID] IN (0, @InstanceID) AND
			FPC.[VersionID] IN (0, @VersionID) AND				
			FPC.[FormID] = @FormID AND
			FPC.[FormPartID] = @FormPartID
		ORDER BY
			FPC.[SortOrder]	

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ColumnList', * FROM #ColumnList ORDER BY SortOrder

	SET @Step = 'Create temp table #FormTable'
		CREATE TABLE #FormTable
			(
			[FormID] int,
			[FormPartID] int
			)	

		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT
				[FormPartColumn],
				[DataType]
			FROM
				#ColumnList
			ORDER BY
				[SortOrder]		

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @FormPartColumn, @DataType

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						ALTER TABLE #FormTable ADD [' + @FormPartColumn + '] ' + @DataType

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					FETCH NEXT FROM AddColumn_Cursor INTO  @FormPartColumn, @DataType
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

		ALTER TABLE #FormTable ADD [DeleteYN] bit

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FormTable', * FROM #FormTable

	SET @Step = 'Insert into temp table #FormTable'
		SELECT 
			@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + '[' + [FormPartColumn] + '],',
			@SQLSelectDataType = @SQLSelectDataType + CHAR(13) + CHAR(10) + CHAR(9) + '[' + [FormPartColumn] + '] ' + [DataType] + ',' 
		FROM
			#ColumnList
		ORDER BY
			[SortOrder]

		IF @JSON_table IS NOT NULL
			BEGIN
				SET @SQLStatement = '
INSERT INTO #FormTable
	(
	[FormID],
	[FormPartID],' + @SQLSelect + '
	[DeleteYN]
	)
SELECT
	[FormID] = ' + CONVERT(nvarchar(15), @FormID) + ',
	[FormPartID] = ' + CONVERT(nvarchar(15), @FormPartID) + ',' + @SQLSelect + '
	[DeleteYN] = ISNULL([DeleteYN], 0)
FROM
	OPENJSON(''' + @JSON_table + ''')
WITH
	(' + @SQLSelectDataType + '
	[DeleteYN] bit
	)'
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END
		ELSE
			GOTO EXITPOINT

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FormTable', * FROM #FormTable

	SET @Step = 'Update'
		SELECT
			@SQLUpdateJoin = @SQLUpdateJoin + ' AND FT.[' + [FormPartColumn] + '] = TN.[' + [DataObjectColumnName] + ']'
		FROM
			#ColumnList
		WHERE
			KeyYN <> 0
		ORDER BY
			SortOrder

		SELECT
			@SQLUpdateSet = @SQLUpdateSet + CHAR(13) + CHAR(10) + CHAR(9) + '[' + [DataObjectColumnName] + '] = ISNULL(FT.[' + [FormPartColumn] + '], TN.[' + [DataObjectColumnName] + ']),'
		FROM
			#ColumnList
		WHERE
			KeyYN = 0
		ORDER BY
			SortOrder

		IF LEN(@SQLUpdateSet) > 0
			SET @SQLUpdateSet = LEFT(@SQLUpdateSet, LEN(@SQLUpdateSet) - 1)

		SET @SQLStatement = '
UPDATE
	TN
SET' + @SQLUpdateSet + '
FROM
	' + @TableName + ' TN
	INNER JOIN #FormTable FT ON FT.[DeleteYN] = 0' + @SQLUpdateJoin + '
WHERE
	TN.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
	TN.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID)
			
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert'
		SELECT @SQLInsert = '', @SQLSelect = '', @SQLKey = ''
		
		SELECT
			@SQLInsert = @SQLInsert +  CHAR(13) + CHAR(10) + CHAR(9) + '[' + [DataObjectColumnName] + '],',
			@SQLSelect = @SQLSelect +  CHAR(13) + CHAR(10) + CHAR(9) + '[' + [DataObjectColumnName] + '] = ' + CASE WHEN [DefaultValue] IS NULL THEN 'FT.[' + [FormPartColumn] + ']' ELSE 'ISNULL(FT.[' + [FormPartColumn] + '],''' + [DefaultValue] + ''')' END + ','
		FROM
			#ColumnList
		WHERE
			EnabledYN <> 0 AND
			IdentityYN = 0
		ORDER BY
			SortOrder

		SELECT
			@SQLNotExist = @SQLNotExist + ' AND D.[' + [DataObjectColumnName] + '] = FT.[' + [FormPartColumn] + ']'
		FROM
			#ColumnList
		WHERE
			KeyYN <> 0
		ORDER BY
			SortOrder

		SELECT
			@SQLInsert = LEFT(@SQLInsert, LEN(@SQLInsert) - 1),
			@SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) - 1)

		SELECT
			@SQLKey = @SQLKey + 'FT.[' + [FormPartColumn] + '] IS NULL AND ',
			@SQLKeyColumnName = [DataObjectColumnName]
		FROM
			#ColumnList
		WHERE
			KeyYN <> 0 AND
			EnabledYN = 0
		ORDER BY
			SortOrder

		IF @DebugBM & 2 > 0 SELECT [@SQLKeyColumnName] = @SQLKeyColumnName

		SET @SQLStatement = '
INSERT INTO ' + @TableName + '
	(
	[InstanceID],
	[VersionID],' + @SQLInsert + '
	)
SELECT
	[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
	[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',' + @SQLSelect + '
FROM
	#FormTable FT
WHERE
	' + @SQLKey + '
    FT.[DeleteYN] = 0 AND
	NOT EXISTS (SELECT 1 FROM ' + @TableName + ' D WHERE D.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND D.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + @SQLNotExist + ')'
			
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		SELECT @InsertedID = IDENT_CURRENT(@TableName), @Inserted = @Inserted + @@ROWCOUNT
		
		IF @DebugBM & 2 > 0 SELECT [@InsertedID] = @InsertedID, [@Inserted] = @Inserted

	SET @Step = 'Delete'
		SET @SQLStatement = '
DELETE
	TN
FROM
	' + @TableName + ' TN
	INNER JOIN #FormTable FT ON FT.[DeleteYN] <> 0' + @SQLUpdateJoin + '
WHERE
	TN.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
	TN.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID)
			
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Return Inserted row'		
		IF @InsertedID IS NOT NULL AND @Inserted > 0
			BEGIN
				SET @SQLStatement = '
					SELECT * FROM ' + @TableName + ' 
					WHERE 
						InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND
						VersionID = ' + CONVERT(NVARCHAR(15), @VersionID) + ' AND
						' + @SQLKeyColumnName + ' = ' + CONVERT(NVARCHAR(15), @InsertedID)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
