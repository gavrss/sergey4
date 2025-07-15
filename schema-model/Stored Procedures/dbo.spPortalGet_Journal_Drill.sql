SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Journal_Drill]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@JournalSequence nvarchar(50) = NULL,
	@JournalNo nvarchar(50) = NULL,
	@JournalLine int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000730,
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
--EXEC [spPortalGet_Journal_Drill] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @Entity = 'EPIC03', @Book = 'MAIN', @FiscalYear = 2012, @JournalSequence = 'CD', @DebugBM = 2
--EXEC [spPortalGet_Journal_Drill] @Entity = 'EPIC03', @Book = 'MAIN', @FiscalYear = 2012, @JournalSequence = 'IJ', @JournalNo = 1, @JournalLine = 1
--EXEC [spPortalGet_Journal_Drill] @Entity = 'EPIC03', @Book = 'MAIN', @FiscalYear = 2014, @JournalSequence = 'IJ', @JournalNo = 1, @JournalLine = 3
EXEC [spPortalGet_Journal_Drill] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @Entity = 'REM', @Book = 'GL', @FiscalYear = 2020, @JournalSequence = 'SJ', @JournalNo = '54', @JournalLine = 3, @DebugBM = 2
EXEC [spPortalGet_Journal_Drill] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @Entity = 'REM', @Book = 'GL', @FiscalYear = 2019, @JournalSequence = 'SJ', @JournalNo = '1000000', @JournalLine = 1, @DebugBM = 2
--EXEC [spPortalGet_Journal_Drill] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @Entity = 'REM', @Book = 'GL', @FiscalYear = 2019, @JournalSequence = 'IR', @JournalNo = '116784', @JournalLine = 2
EXEC [spPortalGet_Journal_Drill] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @Entity = 'REM', @Book = 'GL', @FiscalYear = 2020, @JournalSequence = 'PJ', @JournalNo = '79', @JournalLine = 4, @DebugBM = 2

EXEC [spPortalGet_Journal_Drill] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceTypeID int,
	@SourceTypeName nvarchar(50),
	@SourceModuleReference nvarchar(100),
	@SourceModule nvarchar(20),
	@JournalTable nvarchar(100),
	@SourceDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@Owner nvarchar(5),

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
	@Version nvarchar(50) = '2.1.1.2176'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get links for drilling from Journal into source system.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2163' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2176' SET @Description = 'Converted to dynamic queries.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @JournalTable = @JournalTable OUT

	SET @Step = 'Create temp table #LinkTable'
		CREATE TABLE #LinkTable
			(
			LinkDescription nvarchar(100) COLLATE DATABASE_DEFAULT,
			SourceModule nvarchar(20) COLLATE DATABASE_DEFAULT,
			SourceModuleReference nvarchar(100) COLLATE DATABASE_DEFAULT,
			[InternalLinkYN] bit,
			SourceTypeName nvarchar(50) COLLATE DATABASE_DEFAULT,
			SourceObject nvarchar(100) COLLATE DATABASE_DEFAULT,
			SourceReference nvarchar(255) COLLATE DATABASE_DEFAULT,
			Entity nvarchar(50) COLLATE DATABASE_DEFAULT,
			Param1 nvarchar(50) COLLATE DATABASE_DEFAULT,
			Param2 nvarchar(50) COLLATE DATABASE_DEFAULT,
			Param3 nvarchar(50) COLLATE DATABASE_DEFAULT,
			Param4 nvarchar(50) COLLATE DATABASE_DEFAULT,
			Param5 nvarchar(50) COLLATE DATABASE_DEFAULT,
			Param6 nvarchar(50) COLLATE DATABASE_DEFAULT,
			Book nvarchar(50) COLLATE DATABASE_DEFAULT,
			FiscalYear int,
			JournalSequence nvarchar(50) COLLATE DATABASE_DEFAULT,
			JournalNo nvarchar(50) COLLATE DATABASE_DEFAULT,
			JournalLine int
			)

	SET @Step = 'Create temp table #SourceModule'
		CREATE TABLE #SourceModule
			(
			SourceTypeID int,
			SourceModule nvarchar(20) COLLATE DATABASE_DEFAULT,
			SourceModuleName nvarchar(50) COLLATE DATABASE_DEFAULT,
			)

		INSERT INTO #SourceModule
			(
			SourceTypeID,
			SourceModule,
			SourceModuleName
			)
		SELECT
			SourceTypeID = 5,
			SourceModule = 'SJ',
			SourceModuleName = 'AR Invoice'
		UNION SELECT
			SourceTypeID = 5,
			SourceModule = 'PJ',
			SourceModuleName = 'AP Invoice'

	SET @Step = 'Initial filling of temp table #LinkTable'
		SET @SQLStatement = '
		
			INSERT INTO #LinkTable
				(
				[LinkDescription],
				[SourceModule],
				[SourceModuleReference],
				[InternalLinkYN],
				[SourceTypeName],
				[Entity],
				[Book],
				[FiscalYear],
				[JournalSequence],
				[JournalNo],
				[JournalLine]
				)
			SELECT DISTINCT
				[LinkDescription] = CASE WHEN SM.[SourceModuleName] IS NULL THEN J.[SourceModule] ELSE SM.[SourceModuleName] END + '' - '' + J.[SourceModuleReference],
				[SourceModule] = J.[SourceModule],
				[SourceModuleReference],
				[InternalLinkYN] = 1,
				[SourceTypeName] = J.[Source],
				[Entity] = J.[Entity],
				[Book] = J.[Book],
				[FiscalYear] = J.[FiscalYear],
				[JournalSequence] = J.[JournalSequence],
				[JournalNo] = J.[JournalNo],
				[JournalLine] = J.[JournalLine]
			FROM
				' + @JournalTable + ' J
				LEFT JOIN #SourceModule SM ON SM.[SourceTypeID] = 5 AND SM.[SourceModule] = J.[SourceModule]
			WHERE
				J.[Entity] = ''' + @Entity + ''' AND
				J.[Book] = ''' + @Book + ''' AND
				J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
				J.[JournalSequence] = ''' + @JournalSequence + ''''
				+ CASE WHEN @JournalNo IS NULL THEN '' ELSE ' AND J.[JournalNo] = ''' + @JournalNo + '''' END
				+ CASE WHEN @JournalLine IS NULL THEN '' ELSE ' AND J.[JournalLine] = ' + CONVERT(nvarchar(15), @JournalLine) END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

--				INNER JOIN #SourceModule SM ON SM.[SourceTypeID] = ' + CONVERT(nvarchar(15), @SourceTypeID) + ' AND SM.[SourceModule] = J.[SourceModule]


		IF @DebugBM & 2 > 0 SELECT TempTable = '#LinkTable', * FROM #LinkTable

	SET @Step = 'Get source information'
		SELECT
			@SourceTypeName = MAX([SourceTypeName])
		FROM
			#LinkTable

		SELECT 
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@SourceTypeID = S.SourceTypeID,
			@Owner = ST.SourceTypeName
		FROM
			pcINTEGRATOR_Data.dbo.[Source] S
			INNER JOIN pcINTEGRATOR.dbo.[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeName = @SourceTypeName
			INNER JOIN pcINTEGRATOR_Data.dbo.[Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.[ModelBM] & 64 > 0
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID

		IF @DebugBM & 2 > 0
			SELECT
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName,
				[@SourceDatabase] = @SourceDatabase

	SET @Step = 'SourceType dependent selectors'
		IF @SourceTypeID = 5 --P21
			BEGIN

	SET @Step = '@SourceTypeID = 5 - P21'
				IF CURSOR_STATUS('global','SourceModule_Cursor') >= -1 DEALLOCATE SourceModule_Cursor
				DECLARE SourceModule_Cursor CURSOR FOR
			
					SELECT DISTINCT	SourceModule FROM #LinkTable

					OPEN SourceModule_Cursor
					FETCH NEXT FROM SourceModule_Cursor INTO @SourceModule

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@SourceModule] = @SourceModule

							IF @SourceModule = 'SJ'
								BEGIN
									SET @SQLStatement = '
										UPDATE LT
										SET
											[LinkDescription] = ISNULL(''AR Invoice '' + IH.[Invoice_no] + '' - '' + IH.[customer_id] + '' '' + C.[customer_name], LT.[LinkDescription]),
											[SourceObject] = ''InvoiceAR'',
											[InternalLinkYN] = CASE WHEN IH.[Invoice_no] IS NULL THEN 0 ELSE 1 END
										FROM
											#LinkTable LT
											LEFT JOIN ' + @SourceDatabase + '.[dbo].[invoice_hdr] IH ON IH.[invoice_no] = LT.[SourceModuleReference]
											LEFT JOIN ' + @SourceDatabase + '.[dbo].[customer] C ON C.[customer_id] = IH.[customer_id]'
								END

							ELSE IF @SourceModule = 'PJ'
								BEGIN
									SET @SQLStatement = '
										UPDATE LT
										SET
											[LinkDescription] = ISNULL(''AP Invoice '' + AH.[voucher_no] + '' - '' + CONVERT(nvarchar(50), AH.[vendor_id]) + '' '' + V.[vendor_name], LT.[LinkDescription]),
											[SourceObject] = ''InvoiceAP'',
											[InternalLinkYN] = CASE WHEN AH.[voucher_no] IS NULL THEN 0 ELSE 1 END
										FROM
											#LinkTable LT
											LEFT JOIN ' + @SourceDatabase + '.[dbo].[apinv_hdr] AH ON AH.[voucher_no] = LT.[SourceModuleReference]
											LEFT JOIN ' + @SourceDatabase + '.[dbo].[vendor] V ON V.[vendor_id] = AH.[vendor_id]'
								END

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							FETCH NEXT FROM SourceModule_Cursor INTO @SourceModule
						END

				CLOSE SourceModule_Cursor
				DEALLOCATE SourceModule_Cursor

				--SELECT * FROM DSPSOURCE04.[REMichel_P21Stage].[dbo].[gl]
				--SELECT * FROM DSPSOURCE04.[REMichel_P21Stage].[dbo].[invoice_line]
				--SELECT * FROM DSPSOURCE04.[REMichel_P21Stage].[dbo].[invoice_hdr]

			END

		ELSE IF @SourceTypeID IN (1, 2, 11) --Epicor ERP
			BEGIN

	SET @Step = ' @SourceTypeID = 11 - E10, Epicor ERP'	
		
		SET @SQLStatement = '
				SELECT 
					Company,
					BookID,
					FiscalYear,
					JournalCode,
					JournalNum,
					JournalLine,
					RelatedToFile,
					GLAcctContext,
					Debit = SUM(BookDebitAmount),
					Credit = SUM(BookCreditAmount),
					[Rows] = COUNT(1)
				FROM
					' + @SourceDatabase + '.' + @Owner + '.[TranGLC]
				WHERE
					RecordType = ''R'' AND
					Company = ' + @Entity + ' AND
					BookID = ' + @Book + ' AND
					FiscalYear = ' +  @FiscalYear  + ' AND
					JournalCode = ' +  @JournalSequence  + ' AND
					JournalNum = ' +  @JournalNo  + ' AND
					JournalLine = ' + @JournalLine + ' AND
					1 = 1
				GROUP BY
					RelatedToFile,
					Company,
					BookID,
					FiscalYear,
					JournalCode,
					JournalNum,
					JournalLine,
					GLAcctContext

				SELECT 
					RelatedToFile,
					Company,
					Key1,
					Key2,
					Key3,
					Key4,
					Key5,
					Key6,
					BookID,
					FiscalYear,
					JournalCode,
					JournalNum,
					JournalLine,
					RelatedToFile,
					GLAcctContext,
					BookDebitAmount,
					BookCreditAmount
				FROM
					' + @SourceDatabase + '.' + @Owner + '.[TranGLC]
				WHERE
					RecordType = ''R'' AND
					Company = ' + @Entity + ' AND
					BookID = ' + @Book + ' AND
					FiscalYear = ' +  @FiscalYear  + ' AND
					JournalCode = ' +  @JournalSequence  + ' AND
					JournalNum = ' +  @JournalNo  + ' AND
					JournalLine = ' + @JournalLine + ' AND
					1 = 1'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				--APTran
				/*
					SELECT  *
				  FROM DSPSOURCE01.[ERP10].[Erp].[APTran]
				  WHERE
				  HeadNum = 267 AND
				  APTranNo = 301 AND
				  InvoiceNum = 'INV232' AND
					1 = 1
				*/

				--PartTran
				SET @SQLStatement = '
					SELECT *
					FROM 
						' + @SourceDatabase + '.' + @Owner + '.[PartTran]' + '
					WHERE
						Company = ' + @Entity + ' AND
						1=1'
				
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
			END





	SET @Step = 'Return rows'
		SELECT * FROM #LinkTable

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
