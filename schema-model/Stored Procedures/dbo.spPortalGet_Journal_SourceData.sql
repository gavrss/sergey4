SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Journal_SourceData]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@LinkDescription nvarchar(100) = NULL,
	@SourceModule nvarchar(20) = NULL,
	@SourceModuleReference nvarchar(100) = NULL,
	@InternalLinkYN bit = NULL,
	@SourceTypeName nvarchar(50) = NULL,
	@SourceObject nvarchar(100) = NULL,
	@SourceReference nvarchar(255) = NULL,
	@Entity nvarchar(50) = NULL,
	@Param1 nvarchar(50) = NULL,
	@Param2 nvarchar(50) = NULL,
	@Param3 nvarchar(50) = NULL,
	@Param4 nvarchar(50) = NULL,
	@Param5 nvarchar(50) = NULL,
	@Param6 nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@JournalSequence nvarchar(50) = NULL,
	@JournalNo nvarchar(50) = NULL,
	@JournalLine int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000731,
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
--InvoiceAR
EXEC [spPortalGet_Journal_SourceData]
	@UserID = -10,
	@InstanceID = 515,
	@VersionID = 1040, 
	@LinkDescription = 'AR Invoice 1000032 - 10030 Brian Snedden',
	@SourceModule = 'SJ',
	@SourceModuleReference = '1000032',
	@SourceTypeName = 'P21',
	@SourceObject = 'InvoiceAR',
	@SourceReference = NULL,
	@Entity = 'REM',
	@Param1 = NULL,
	@Param2 = NULL,
	@Param3 = NULL,
	@Param4 = NULL,
	@Param5 = NULL,
	@Param6 = NULL,
	@Book = 'GL',
	@FiscalYear = 2020,
	@JournalSequence = 'SJ',
	@JournalNo = '54',
	@JournalLine = 3

--InvoiceAP
EXEC [spPortalGet_Journal_SourceData]
	@UserID = -10,
	@InstanceID = 515,
	@VersionID = 1040, 
	@LinkDescription = 'Invoice AR',
	@SourceModule = 'SJ',
	@SourceModuleReference = '1000029',
	@SourceTypeName = 'P21',
	@SourceObject = 'InvoiceAR',
	@Entity = 'REM'

--InvoiceAP
EXEC [spPortalGet_Journal_SourceData]
	@UserID = -10,
	@InstanceID = 515,
	@VersionID = 1040, 
	@LinkDescription = 'AP Invoice 1000002 - 10003 Bosch Thermotechnology Corp',
	@SourceModule = 'PJ',
	@SourceModuleReference = '1000002',
	@SourceTypeName = 'P21',
	@SourceObject = 'InvoiceAP',
	@SourceReference = NULL,
	@Entity = 'REM',
	@Param1 = NULL,
	@Param2 = NULL,
	@Param3 = NULL,
	@Param4 = NULL,
	@Param5 = NULL,
	@Param6 = NULL,
	@Book = 'GL',
	@FiscalYear = 2020,
	@JournalSequence = 'PJ',
	@JournalNo = '79',
	@JournalLine = 4

--InvoiceAP
EXEC [spPortalGet_Journal_SourceData]
	@UserID = -10,
	@InstanceID = 515,
	@VersionID = 1040, 
	@LinkDescription = 'Invoice AP',
	@SourceModule = 'PJ',
	@SourceModuleReference = '1000003',
	@SourceTypeName = 'P21',
	@SourceObject = 'InvoiceAP',
	@Entity = 'REM'

--Customer
EXEC [spPortalGet_Journal_SourceData]
	@UserID = -10,
	@InstanceID = 515,
	@VersionID = 1040, 
	@LinkDescription = 'Customer',
	@SourceModule = 'Customer',
	@SourceModuleReference = '10030',
	@SourceTypeName = 'P21',
	@SourceObject = 'Customer',
	@Entity = 'REM'

--Vendor
EXEC [spPortalGet_Journal_SourceData]
	@UserID = -10,
	@InstanceID = 515,
	@VersionID = 1040, 
	@LinkDescription = 'Vendor',
	@SourceModule = 'Vendor',
	@SourceModuleReference = '10003',
	@SourceTypeName = 'P21',
	@SourceObject = 'Vendor',
	@Entity = 'REM'

EXEC [spPortalGet_Journal_SourceData] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceTypeID int,
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
			@ProcedureDescription = 'Return information from source data based on drill parameters from Journal.',
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

		SELECT 
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@SourceTypeID = S.SourceTypeID
		FROM
			pcINTEGRATOR_Data.dbo.[Source] S
			INNER JOIN pcINTEGRATOR.dbo.[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeName = @SourceTypeName
			INNER JOIN pcINTEGRATOR_Data.dbo.[Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.[BaseModelID] = -7
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

				IF @SourceModule = 'SJ'
					BEGIN
						SET @SQLStatement = '
							SELECT
								[ResultSet] = 1,
								[InvoiceNumber] = IH.[Invoice_no],
								[CustomerID] = IH.[customer_id],
								[CustomerName] = C.[customer_name],
								IH.*,
								C.*
							FROM
								' + @SourceDatabase + '.[dbo].[invoice_hdr] IH
								LEFT JOIN ' + @SourceDatabase + '.[dbo].[customer] C ON C.[customer_id] = IH.[customer_id]
							WHERE
								IH.[Invoice_no] = ''' + @SourceModuleReference + ''''

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @SQLStatement = '
							SELECT
								[ResultSet] = 2,
								[InvoiceLine] = [oe_line_number],
								[ItemID] = [item_id],
								[ItemDescription] = [item_desc],
								IL.*
							FROM
								' + @SourceDatabase + '.[dbo].[invoice_line] IL
							WHERE
								IL.[Invoice_no] = ''' + @SourceModuleReference + '''
							ORDER BY
								[oe_line_number]'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 0,
							[PropertyType] = 'LinkDescription',
							[LinkNo] = NULL,
							[Value] = @LinkDescription
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 0,
							[PropertyType] = 'SourceObject',
							[LinkNo] = NULL,
							[Value] = @SourceObject
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '3')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '3')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 1,
							[Value] = '[CustomerID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 1,
							[Value] = '[CustomerName]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'Reference:[SourceModuleReference]',
							[LinkNo] = 1,
							[Value] = '[CustomerID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 2,
							[Value] = '[ItemID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 2,
							[Value] = '[ItemDescription]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'Reference:[SourceModuleReference]',
							[LinkNo] = 2,
							[Value] = '[ItemID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'Heading',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), 'Invoice header')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'Heading',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), 'Invoice line(s)')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'TableName',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '[invoice_hdr], [customer]')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'TableName',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '[invoice_line]')

						SELECT
							ResultSet = 'Link',
							LinkNo = 1,
							LinkDescription = 'Customer',
							SourceModule = 'Customer',
							SourceModuleReference = '[To be replaced]',
							SourceTypeName = 'P21',
							SourceObject = 'Customer',
							SourceReference = NULL,
							Entity = 'REM',
							Param1 = NULL,
							Param2 = NULL,
							Param3 = NULL,
							Param4 = NULL,
							Param5 = NULL,
							Param6 = NULL,
							Book = NULL,
							FiscalYear = NULL,
							JournalSequence = NULL,
							JournalNo = NULL,
							JournalLine = NULL
						UNION SELECT
							ResultSet = 'Link',
							LinkNo = 2,
							LinkDescription = 'Item',
							SourceModule = 'Item',
							SourceModuleReference = '[To be replaced]',
							SourceTypeName = 'P21',
							SourceObject = 'Item',
							SourceReference = NULL,
							Entity = 'REM',
							Param1 = NULL,
							Param2 = NULL,
							Param3 = NULL,
							Param4 = NULL,
							Param5 = NULL,
							Param6 = NULL,
							Book = NULL,
							FiscalYear = NULL,
							JournalSequence = NULL,
							JournalNo = NULL,
							JournalLine = NULL
 					END

				ELSE IF @SourceModule = 'PJ'
					BEGIN
						SET @SQLStatement = '
							SELECT
								[ResultSet] = 1,
								[Voucher] = AH.[voucher_no],
								[VendorID] = AH.[vendor_id],
								[VendorName] = V.[vendor_name],
								[InvoiceNo] = AH.[invoice_no],
								[InvoiceDate] = CONVERT(nvarchar(10), AH.[invoice_date], 23),
								[InvoiceAmount] = AH.[invoice_amount],
								AH.*,
								V.*
							FROM
								' + @SourceDatabase + '.[dbo].[apinv_hdr] AH
								LEFT JOIN ' + @SourceDatabase + '.[dbo].[vendor] V ON V.[vendor_id] = AH.[vendor_id]
							WHERE
								AH.[voucher_no] = ''' + @SourceModuleReference + ''''

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @SQLStatement = '
							SELECT
								[ResultSet] = 2,
								[InvoiceLine] = AL.[apinv_line_uid],
								[ItemID] = AL.[item_id],
								[Description] = AL.[description],
								[Quantity] = AL.[quantity],
								[UnitPrice] = AL.[unit_price],
								[PurchaseAmount] = AL.[purchase_amount],
								AL.*
							FROM
								' + @SourceDatabase + '.[dbo].[apinv_line] AL
							WHERE
								AL.[voucher_no] = ''' + @SourceModuleReference + '''
							ORDER BY
								AL.[apinv_line_uid]'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @SQLStatement = '
							SELECT
								[ResultSet] = 3,
								[InvoiceLine] = AL.[apinv_line_uid],
								[ItemID] = AL.[item_id],
								[Description] = AL.[description],
								AL.*
							FROM
								' + @SourceDatabase + '.[dbo].[apinv_line] AL
							WHERE
								AL.[voucher_no] = ''' + @SourceModuleReference + '''
							ORDER BY
								AL.[apinv_line_uid]'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)


						SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 0,
							[PropertyType] = 'LinkDescription',
							[LinkNo] = NULL,
							[Value] = @LinkDescription
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 0,
							[PropertyType] = 'SourceObject',
							[LinkNo] = NULL,
							[Value] = @SourceObject
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '6')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '6')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 1,
							[Value] = '[VendorID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 1,
							[Value] = '[VendorName]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'Reference:[SourceModuleReference]',
							[LinkNo] = 1,
							[Value] = '[VendorID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 2,
							[Value] = '[ItemID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'Reference:[SourceModuleReference]',
							[LinkNo] = 2,
							[Value] = '[ItemID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'Heading',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), 'Voucher header')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'Heading',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), 'Voucher line(s)')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'TableName',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '[apinv_hdr], [vendor]')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'TableName',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '[apinv_line]')

						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 3,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '3')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 3,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 2,
							[Value] = '[ItemID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 3,
							[PropertyType] = 'Reference:[SourceModuleReference]',
							[LinkNo] = 2,
							[Value] = '[ItemID]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 3,
							[PropertyType] = 'Heading',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), 'Voucher line(s)')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 3,
							[PropertyType] = 'TableName',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '[apinv_line]')


						
						SELECT
							ResultSet = 'Link',
							LinkNo = 1,
							LinkDescription = 'Vendor',
							SourceModule = 'Vendor',
							SourceModuleReference = '[To be replaced]',
							SourceTypeName = 'P21',
							SourceObject = 'Vendor',
							SourceReference = NULL,
							Entity = 'REM',
							Param1 = NULL,
							Param2 = NULL,
							Param3 = NULL,
							Param4 = NULL,
							Param5 = NULL,
							Param6 = NULL,
							Book = NULL,
							FiscalYear = NULL,
							JournalSequence = NULL,
							JournalNo = NULL,
							JournalLine = NULL
						UNION SELECT
							ResultSet = 'Link',
							LinkNo = 2,
							LinkDescription = 'Item',
							SourceModule = 'Item',
							SourceModuleReference = '[To be replaced]',
							SourceTypeName = 'P21',
							SourceObject = 'Item',
							SourceReference = NULL,
							Entity = 'REM',
							Param1 = NULL,
							Param2 = NULL,
							Param3 = NULL,
							Param4 = NULL,
							Param5 = NULL,
							Param6 = NULL,
							Book = NULL,
							FiscalYear = NULL,
							JournalSequence = NULL,
							JournalNo = NULL,
							JournalLine = NULL
					END

				ELSE IF @SourceModule = 'Customer'
					BEGIN
						SET @SQLStatement = '
							SELECT
								[ResultSet] = 1,
								[CustomerID] = C.[customer_id],
								[CustomerName] = C.[customer_name],
								C.*
							FROM
								' + @SourceDatabase + '.[dbo].[customer] C
							WHERE
								C.[customer_id] = ''' + @SourceModuleReference + ''' AND
								C.[company_id] = ''' + @Entity + ''''

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @SQLStatement = '
							SELECT TOP 50
								[ResultSet] = 2,
								[LinkDescription] = ''AR Invoices'',
								[InvoiceNumber] = AH.[invoice_no],
								AH.*
							FROM
								' + @SourceDatabase + '.[dbo].[invoice_hdr] AH
							WHERE
								AH.[customer_id] = ''' + @SourceModuleReference + '''
							ORDER BY
								AH.[invoice_date] DESC'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 0,
							[PropertyType] = 'LinkDescription',
							[LinkNo] = NULL,
							[Value] = @LinkDescription
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 0,
							[PropertyType] = 'SourceObject',
							[LinkNo] = NULL,
							[Value] = @SourceObject
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '2')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '2')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 1,
							[Value] = '[InvoiceNumber]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'Reference:[SourceModuleReference]',
							[LinkNo] = 1,
							[Value] = '[InvoiceNumber]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'Heading',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), 'Customer')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'Heading',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), 'Invoice(s)')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'TableName',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '[customer]')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'TableName',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '[invoice_hdr]')

						SELECT
							ResultSet = 'Link',
							LinkNo = 1,
							LinkDescription = 'Invoice AR',
							SourceModule = 'SJ',
							SourceModuleReference = '[To be replaced]',
							SourceTypeName = 'P21',
							SourceObject = 'InvoiceAR',
							SourceReference = NULL,
							Entity = 'REM',
							Param1 = NULL,
							Param2 = NULL,
							Param3 = NULL,
							Param4 = NULL,
							Param5 = NULL,
							Param6 = NULL,
							Book = NULL,
							FiscalYear = NULL,
							JournalSequence = NULL,
							JournalNo = NULL,
							JournalLine = NULL
					END

				ELSE IF @SourceModule = 'Vendor'
					BEGIN
						SET @SQLStatement = '
							SELECT
								[ResultSet] = 1,
								[VendorID] = V.[vendor_id],
								[VendorName] = V.[vendor_name],
								V.*
							FROM
								' + @SourceDatabase + '.[dbo].[vendor] V
							WHERE
								V.[vendor_id] = ''' + @SourceModuleReference + ''' AND
								V.[company_id] = ''' + @Entity + ''''

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @SQLStatement = '
							SELECT TOP 50
								[ResultSet] = 2,
								[LinkDescription] = ''AP Invoices'',
								[Voucher] = AH.[voucher_no],
								AH.*
							FROM
								' + @SourceDatabase + '.[dbo].[apinv_hdr] AH
							WHERE
								AH.[vendor_id] = ''' + @SourceModuleReference + '''
							ORDER BY
								AH.[invoice_date] DESC'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 0,
							[PropertyType] = 'LinkDescription',
							[LinkNo] = NULL,
							[Value] = @LinkDescription
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 0,
							[PropertyType] = 'SourceObject',
							[LinkNo] = NULL,
							[Value] = @SourceObject
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '2')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '2')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'ClickableColumn',
							[LinkNo] = 1,
							[Value] = '[Voucher]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'Reference:[SourceModuleReference]',
							[LinkNo] = 1,
							[Value] = '[Voucher]'
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'Heading',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), 'Vendor')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'Heading',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), 'Voucher(s)')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'TableName',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '[vendor]')
						UNION SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 2,
							[PropertyType] = 'TableName',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '[apinv_hdr]')

						SELECT
							ResultSet = 'Link',
							LinkNo = 1,
							LinkDescription = 'Invoice AP',
							SourceModule = 'PJ',
							SourceModuleReference = '[To be replaced]',
							SourceTypeName = 'P21',
							SourceObject = 'InvoiceAP',
							SourceReference = NULL,
							Entity = 'REM',
							Param1 = NULL,
							Param2 = NULL,
							Param3 = NULL,
							Param4 = NULL,
							Param5 = NULL,
							Param6 = NULL,
							Book = NULL,
							FiscalYear = NULL,
							JournalSequence = NULL,
							JournalNo = NULL,
							JournalLine = NULL

					END

				ELSE 
					BEGIN
						SELECT
							[ResultSet] = 1,
							[LinkDescription] = @LinkDescription,
							[Message] = 'Nothing is yet configured for SourceModule = ' + @SourceModule + '.'
					
						SELECT
							[ResultSet] = 'Property',
							[ResultSetNo] = 1,
							[PropertyType] = 'DefaultColumns',
							[LinkNo] = NULL,
							[Value] = CONVERT(nvarchar(50), '2')
					
					END


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
