SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_TabularConnection]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000485,
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
EXEC [spPortalGet_TabularConnection] @UserID=-10, @InstanceID=-1318, @VersionID=-1256, @DataClassID = 6320, @Debug=1
EXEC [spPortalGet_TabularConnection] @UserID=-10, @InstanceID=413, @VersionID=1008, @DataClassID = 1028, @DebugBM=1

EXEC [spPortalGet_TabularConnection] @GetVersion = 1

More info ODC https://docs.microsoft.com/sv-se/azure/analysis-services/analysis-services-odc

*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables

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
	@CreatedBy nvarchar(50) = 'BeJa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.3.2151'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return connection files, for example odc which opens in Excel, which is used to access the Tabular model in the azure cloud',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Set correct ProcedureID.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Return data'
		SELECT 
			Type = ttt.TabularToolTypeName,
			Name = t.TabularTemplateName,
			FileName = t.TabularTemplateName + N'.' + ttt.FileExtension,
			Content = t.Content,
			ContentType = ttt.ContentType
		FROM pcINTEGRATOR_Data..TabularTemplate t
		INNER JOIN TabularToolType ttt ON
			ttt.TabularToolTypeID = t.TabularToolTypeID
		WHERE t.InstanceID = @InstanceID AND t.VersionID = @VersionID
		--SELECT 
		--	Type = 'Excel',
		--	Name = 'Open in Excel',
		--	FileName = @TabularDatabase + '.odc',
		--	Content = 
		--		CONVERT(VARBINARY(MAX), '<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns="http://www.w3.org/TR/REC-html40"><head><meta http-equiv=Content-Type content="text/x-ms-odc; charset=utf-8"><meta name=ProgId content=ODC.Cube><meta name=SourceType content=OLEDB><meta name=Catalog content=aspaas5><meta name=Table content=Model>' + 
		--		'<title>' + @TabularServer + ' ' + @TabularDatabase + ' ' + @Model + '</title><xml id=docprops><o:DocumentProperties xmlns:o="urn:schemas-microsoft-com:office:office" xmlns="http://www.w3.org/TR/REC-html40"><o:Name>' + @TabularServer + ' ' + @TabularDatabase + ' ' + @Model + '</o:Name></o:DocumentProperties></xml>' +
		--		'<xml id=msodc><odc:OfficeDataConnection xmlns:odc="urn:schemas-microsoft-com:office:odc" xmlns="http://www.w3.org/TR/REC-html40"><odc:Connection odc:Type="OLEDB"><odc:ConnectionString>Provider=MSOLAP;Data Source=' + @TabularServer + ';Initial Catalog=' + @TabularDatabase + ';MDX Compatibility=1;MDX Missing Member Mode=Error;Safety Options=2;Update Isolation Level=2;Locale Identifier=' + CAST(@LocaleIdentifier as nvarchar) + '</odc:ConnectionString><odc:CommandType>Cube</odc:CommandType><odc:CommandText>' + @Model + '</odc:CommandText></odc:Connection></odc:OfficeDataConnection></xml>' +
		--		'</head></html>'),
		--	ContentType = 'application/vnd.ms-excel'
		--UNION ALL
		--SELECT 
		--	Type = 'PowerBI',
		--	Name = 'Open in Power BI Desktop',
		--	FileName = @TabularDatabase + '.pbix',
		--	Content = NULL,
		--	ContentType = 'application/vnd.ms-excel'


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
