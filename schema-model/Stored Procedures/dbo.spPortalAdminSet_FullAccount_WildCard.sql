SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_FullAccount_WildCard]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ConversionID int = NULL,
    
	@JSON_table nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000477,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@DebugBM int = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_FullAccount_WildCard',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"454"},
		{"TKey":"VersionID", "TValue":"1021"},
		{"TKey":"ConversionID", "TValue":"6332"},
		{"TKey":"Debug", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"SortOrder":"1","AccountType":"*","AccountCategory":"*","SourceCol01":"R560","SourceCol02":"AC_ACC_LIAB","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"NONE","DestCol05":"NONE","DestCol06":"*"},
		{"SortOrder":"2","AccountType":"*","AccountCategory":"*","SourceCol01":"R520","SourceCol02":"AC_ACC_LIAB","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"NONE","DestCol05":"*","DestCol06":"*"},
		{"SortOrder":"3","AccountType":"*","AccountCategory":"*","SourceCol01":"R560","SourceCol02":"AC_ACC_PAYROL","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"*","DestCol05":"NONE","DestCol06":"NONE"},
		{"SortOrder":"4","AccountType":"*","AccountCategory":"*","SourceCol01":"C010","SourceCol02":"AC_ACC_PAYROL","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"*","DestCol04":"*","DestCol05":"NONE","DestCol06":"NONE"},
		{"SortOrder":"5","AccountType":"*","AccountCategory":"*","SourceCol01":"R350","SourceCol02":"AC_ACC_PAYROL","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"*","DestCol05":"NONE","DestCol06":"NONE"},
		{"SortOrder":"6","AccountType":"*","AccountCategory":"*","SourceCol01":"R510","SourceCol02":"AC_ADDCAPITAL","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"NONE","DestCol05":"NONE","DestCol06":"NONE"},
		{"SortOrder":"7","AccountType":"*","AccountCategory":"*","SourceCol01":"R510","SourceCol02":"AC_AP_GROUP","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"NONE","DestCol05":"NONE","DestCol06":"*"},
		{"SortOrder":"8","AccountType":"*","AccountCategory":"*","SourceCol01":"C010","SourceCol02":"AC_AP_GROUP","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"NONE","DestCol05":"NONE","DestCol06":"*"},
		{"SortOrder":"9","AccountType":"*","AccountCategory":"*","SourceCol01":"R350","SourceCol02":"AC_AP_GROUP","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"NONE","DestCol05":"NONE","DestCol06":"*"},
		{"SortOrder":"10","AccountType":"*","AccountCategory":"*","SourceCol01":"R430","SourceCol02":"AC_AP_GROUP","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"NONE","DestCol05":"NONE","DestCol06":"*"},
		{"SortOrder":"11","AccountType":"*","AccountCategory":"*","SourceCol01":"R560","SourceCol02":"AC_AP_GROUP","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"NONE","DestCol05":"NONE","DestCol06":"*"},
		{"SortOrder":"12","AccountType":"*","AccountCategory":"*","SourceCol01":"R520","SourceCol02":"AC_AP_GROUP","SourceCol03":"*","SourceCol04":"*","SourceCol05":"*","SourceCol06":"*","DestCol01":"*","DestCol02":"*","DestCol03":"NONE","DestCol04":"NONE","DestCol05":"NONE","DestCol06":"*"}
		]'

EXEC spPortalAdminSet_FullAccount_WildCard @UserID = -10, @InstanceID = 454, @VersionID = 1021, @ConversionID = 6332, @Debug=1

	SortOrder		AccountType	AccountCategory	SourceCol01	SourceCol02	SourceCol03	SourceCol04	SourceCol05	SourceCol06		DestCol01	DestCol02	DestCol03	DestCol04	DestCol05	DestCol06
1		*	*	R560	AC_ACC_LIAB		*	*	*	*			*	*	NONE	NONE	NONE	*
2		*	*	R520	AC_ACC_LIAB		*	*	*	*			*	*	NONE	NONE	*		*
3		*	*	R560	AC_ACC_PAYROL	*	*	*	*			*	*	NONE	*		NONE	NONE
4		*	*	C010	AC_ACC_PAYROL	*	*	*	*			*	*	*		*		NONE	NONE
5		*	*	R350	AC_ACC_PAYROL	*	*	*	*			*	*	NONE	*		NONE	NONE
6		*	*	R510	AC_ADDCAPITAL	*	*	*	*			*	*	NONE	NONE	NONE	NONE
7		*	*	R510	AC_AP_GROUP		*	*	*	*			*	*	NONE	NONE	NONE	*
8		*	*	C010	AC_AP_GROUP		*	*	*	*			*	*	NONE	NONE	NONE	*
9		*	*	R350	AC_AP_GROUP		*	*	*	*			*	*	NONE	NONE	NONE	*
10		*	*	R430	AC_AP_GROUP		*	*	*	*			*	*	NONE	NONE	NONE	*
11		*	*	R560	AC_AP_GROUP		*	*	*	*			*	*	NONE	NONE	NONE	*
12		*	*	R520	AC_AP_GROUP		*	*	*	*			*	*	NONE	NONE	NONE	*

EXEC [spPortalAdminSet_FullAccount_WildCard] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SortOrder int,
	@VerifiedByUserID int,
	@SQLStatement nvarchar(max),
	@SQLStatement_Set nvarchar(max),
	@SQLStatement_Where nvarchar(max),
	@DebugSub bit = 0,
	@SourceColumn nvarchar(50),
	@DestinationColumn nvarchar(50),
	@Source nvarchar(50),
	@Destination nvarchar(50),
	@DimensionID int,
	@StorageTypeBM int,
	@LeafLevelFilter nvarchar(max),

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2165'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set wildcards for FullAccount.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2147' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Made generic.'
		IF @Version = '2.1.0.2165' SET @Description = 'Obsolete. Replaced with another method for FullAccount.'

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

		IF @Debug <> 0 SELECT [@ConversionID] = @ConversionID

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Define current columns'
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

		EXEC spGet_FullAccount_DimensionList @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ConversionID=@ConversionID, @AdvancedMappingYN=1

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FADimensionList', * FROM #FADimensionList ORDER BY SortOrder

	SET @Step = 'CREATE TABLE #FullAccount_WildCard'
		CREATE TABLE #FullAccount_WildCard
			(
			SortOrder int,
			AccountType nvarchar(50) COLLATE DATABASE_DEFAULT,
			AccountCategory nvarchar(50) COLLATE DATABASE_DEFAULT,
			SourceCol01 nvarchar(100) COLLATE DATABASE_DEFAULT,
			SourceCol02 nvarchar(100) COLLATE DATABASE_DEFAULT,
			SourceCol03 nvarchar(100) COLLATE DATABASE_DEFAULT,
			SourceCol04 nvarchar(100) COLLATE DATABASE_DEFAULT,
			SourceCol05 nvarchar(100) COLLATE DATABASE_DEFAULT,
			SourceCol06 nvarchar(100) COLLATE DATABASE_DEFAULT,
			DestCol01 nvarchar(100) COLLATE DATABASE_DEFAULT,
			DestCol02 nvarchar(100) COLLATE DATABASE_DEFAULT,
			DestCol03 nvarchar(100) COLLATE DATABASE_DEFAULT,
			DestCol04 nvarchar(100) COLLATE DATABASE_DEFAULT,
			DestCol05 nvarchar(100) COLLATE DATABASE_DEFAULT,
			DestCol06 nvarchar(100) COLLATE DATABASE_DEFAULT,
			VerifiedByUserID int
			)

	SET @Step = 'Insert data into temp table #FullAccount_WildCard'
		IF @JSON_table IS NOT NULL
			BEGIN
				INSERT INTO #FullAccount_WildCard
					(
					SortOrder,
					AccountType,
					AccountCategory,
					SourceCol01,
					SourceCol02,
					SourceCol03,
					SourceCol04,
					SourceCol05,
					SourceCol06,
					DestCol01,
					DestCol02,
					DestCol03,
					DestCol04,
					DestCol05,
					DestCol06,
					VerifiedByUserID
					)
				SELECT
					SortOrder,
					AccountType,
					AccountCategory,
					SourceCol01,
					SourceCol02,
					SourceCol03,
					SourceCol04,
					SourceCol05,
					SourceCol06,
					DestCol01,
					DestCol02,
					DestCol03,
					DestCol04,
					DestCol05,
					DestCol06,
					VerifiedByUserID = @UserID
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					SortOrder int,
					AccountType nvarchar(50),
					AccountCategory nvarchar(50),
					SourceCol01 nvarchar(100),
					SourceCol02 nvarchar(100),
					SourceCol03 nvarchar(100),
					SourceCol04 nvarchar(100),
					SourceCol05 nvarchar(100),
					SourceCol06 nvarchar(100),
					DestCol01 nvarchar(100),
					DestCol02 nvarchar(100),
					DestCol03 nvarchar(100),
					DestCol04 nvarchar(100),
					DestCol05 nvarchar(100),
					DestCol06 nvarchar(100)
					)
				
				IF @Debug <> 0
					SELECT [TempTable] = '#FullAccount_WildCard', * FROM #FullAccount_WildCard

				DELETE FA
				FROM
					pcINTEGRATOR_Data..FullAccount FA
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					DataClassID = @ConversionID AND
					WildCardYN <> 0

				SET @Deleted = @Deleted + @@ROWCOUNT

				INSERT INTO pcINTEGRATOR_Data..FullAccount
					(
					InstanceID,
					VersionID,
					DataClassID,
					SourceString,
					WildcardYN, 
					SortOrder,
					AccountType,
					AccountCategory,
					SourceCol01,
					SourceCol02,
					SourceCol03,
					SourceCol04,
					SourceCol05,
					SourceCol06,
					DestCol01,
					DestCol02,
					DestCol03,
					DestCol04,
					DestCol05,
					DestCol06,
					Verified,
					VerifiedByUserID
					)
				SELECT
					InstanceID = @InstanceID,
					VersionID = @VersionID,
					DataClassID = @ConversionID,
					SourceString = '',
					WildcardYN = 1, 
					SortOrder,
					AccountType,
					AccountCategory,
					SourceCol01,
					SourceCol02,
					SourceCol03,
					SourceCol04,
					SourceCol05,
					SourceCol06,
					DestCol01,
					DestCol02,
					DestCol03,
					DestCol04,
					DestCol05,
					DestCol06,
					Verified = GetDate(),
					VerifiedByUserID
				FROM
					#FullAccount_WildCard

				SET @Inserted = @Inserted + @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO #FullAccount_WildCard
					(
					SortOrder,
					AccountType,
					AccountCategory,
					SourceCol01,
					SourceCol02,
					SourceCol03,
					SourceCol04,
					SourceCol05,
					SourceCol06,
					DestCol01,
					DestCol02,
					DestCol03,
					DestCol04,
					DestCol05,
					DestCol06,
					VerifiedByUserID
					)
				SELECT
					SortOrder,
					AccountType,
					AccountCategory,
					SourceCol01,
					SourceCol02,
					SourceCol03,
					SourceCol04,
					SourceCol05,
					SourceCol06,
					DestCol01,
					DestCol02,
					DestCol03,
					DestCol04,
					DestCol05,
					DestCol06,
					VerifiedByUserID
				FROM
					pcINTEGRATOR_Data..FullAccount
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					DataClassID = @ConversionID AND
					SourceString = '' AND
					WildcardYN = 1
			END

	SET @Step = 'WildCard_Cursor'
		IF CURSOR_STATUS('global','WildCard_Cursor') >= -1 DEALLOCATE WildCard_Cursor
		DECLARE WildCard_Cursor CURSOR FOR
			
			SELECT 
				SortOrder,
				VerifiedByUserID
			FROM
				#FullAccount_WildCard
			ORDER BY
				SortOrder DESC

			OPEN WildCard_Cursor
			FETCH NEXT FROM WildCard_Cursor INTO @SortOrder, @VerifiedByUserID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@SortOrder] = @SortOrder, [@VerifiedByUserID] = @VerifiedByUserID

					SELECT @SQLStatement_Set = '', @SQLStatement_Where = ''

					IF CURSOR_STATUS('global','Column_Cursor') >= -1 DEALLOCATE Column_Cursor
					DECLARE Column_Cursor CURSOR FOR
			
						SELECT 
							[DimensionID],
							[StorageTypeBM],
							[Source],
							[Destination]
						FROM
							#FADimensionList
						ORDER BY
							SortOrder

						OPEN Column_Cursor
						FETCH NEXT FROM Column_Cursor INTO @DimensionID, @StorageTypeBM, @SourceColumn, @DestinationColumn

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @Debug <> 0 SELECT [@DimensionID] = @DimensionID, [@StorageTypeBM] = @StorageTypeBM, [@SourceColumn] = @SourceColumn, [@DestinationColumn] = @DestinationColumn

								SET @SQLStatement = '
									SELECT
										@Source = ' + ISNULL(@SourceColumn, 'NULL') + ',
										@Destination = ' + ISNULL(@DestinationColumn, 'NULL') + '
									FROM
										#FullAccount_WildCard
									WHERE
										SortOrder = ' + CONVERT(nvarchar(15), @SortOrder)


								EXEC sp_executesql @SQLStatement, N'@Source nvarchar(50) OUTPUT, @Destination nvarchar(50) OUTPUT', @Source OUTPUT, @Destination OUTPUT

								IF @DebugBM & 2 > 0 SELECT [@Source] = @Source, [@Destination] = @Destination

								IF @Destination IS NOT NULL
									SELECT @SQLStatement_Set = @SQLStatement_Set + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN @Destination  = '*' THEN '[' + @DestinationColumn + '] = FA.[' + @DestinationColumn + ']' ELSE '[' + @DestinationColumn + '] = ''' + @Destination + '''' END + ','

								IF ISNULL(@Source, '*') <> '*'
									BEGIN
										EXEC spGet_LeafLevelFilter @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DatabaseName='pcDATA_CCM', @DimensionID=@DimensionID, @Filter=@Source, @StorageTypeBM=@StorageTypeBM, @LeafLevelFilter=@LeafLevelFilter OUT, @Debug = @DebugSub
										SELECT @SQLStatement_Where = @SQLStatement_Where + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @SourceColumn + '] IN (' + @LeafLevelFilter + ') AND'
									END

								FETCH NEXT FROM Column_Cursor INTO @DimensionID, @StorageTypeBM, @SourceColumn, @DestinationColumn
							END

					CLOSE Column_Cursor
					DEALLOCATE Column_Cursor

					IF @DebugBM & 2 > 0 
						BEGIN
							PRINT @SQLStatement_Set
							PRINT @SQLStatement_Where
						END

					SET @SQLStatement = '
						UPDATE FA
						SET' + @SQLStatement_Set + '
							Verified = GetDate(),
							VerifiedByUserID = ' + CONVERT(nvarchar(15), @VerifiedByUserID) + '
						FROM
							pcINTEGRATOR_Data..FullAccount FA
						WHERE' + @SQLStatement_Where + '
							InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							DataClassID = ' + CONVERT(nvarchar(15), @ConversionID) + ' AND
							WildCardYN = 0'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Updated = @Updated + @@ROWCOUNT

					FETCH NEXT FROM WildCard_Cursor INTO @SortOrder, @VerifiedByUserID
				END

		CLOSE WildCard_Cursor
		DEALLOCATE WildCard_Cursor

	SET @Step = 'Delete temp table'
		DROP TABLE #FullAccount_WildCard
		DROP TABLE #FADimensionList

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
