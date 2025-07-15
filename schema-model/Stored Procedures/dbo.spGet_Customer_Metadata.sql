SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Customer_Metadata]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@CustomerID int = NULL,
	@CreateXmlYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000068,
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
EXEC spGet_Customer_Metadata @CustomerID = 400, @CreateXmlYN = 1, @Debug = 1
EXEC spGet_Customer_Metadata @CustomerID = 393, @CreateXmlYN = 0, @Debug = 1
EXEC spGet_Customer_Metadata @CustomerID = 400, @CreateXmlYN = 0 --Shows your current settings

EXEC [spGet_Customer_Metadata] @GetVersion = 1
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return Customer metadata.',
			@MandatoryParameter = 'CustomerID' --Without @, separated by |

		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.2071' SET @Description = 'Filter on only selected and introduced stuff.'
		IF @Version = '1.3.2107' SET @Description = 'Added @Nyc.'
		IF @Version = '1.3.2110' SET @Description = 'Test on Application.SelectYN.'
		IF @Version = '1.3.1.2120' SET @Description = 'Return InheritedFrom.'
		IF @Version = '1.3.1.2124' SET @Description = 'Added @Nyu.'
		IF @Version = '2.0.2.2148' SET @Description = 'Removed references to [Customer].[XML_Export].'
		IF @Version = '2.0.3.2154' SET @Description = 'Update template.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT @InstanceID = ISNULL(@InstanceID, (SELECT MAX(InstanceID) FROM Instance WHERE CustomerID = @CustomerID))

	SET @Step = 'Return base values'
		SELECT
			IntegratorVersion = @Version,
			CustomerID,
			CustomerName,
			CustomerDescription, 
			InstanceID,
			InstanceName,
			InstanceDescription,
			ProductKey,
			Nyc,
			Nyu,
			ApplicationID,
			ApplicationName,
			ApplicationDescription,
			ApplicationServer,
			LanguageID,
			ETLDatabase,
			DestinationDatabase,
			AdminUser,
			Application_InheritedFrom,
			ModelID,
			ModelName,
			ModelDescription,
			BaseModelID,
			BaseModelName,
			Model_InheritedFrom,
			Model_SelectYN,
			LanguageCode,
			LanguageName,
			SourceID,
			SourceName,
			SourceDescription,
			SourceTypeID,
			SourceTypeName,
			SourceDatabase,
			ETLDatabase_Linked,
			StartYear,
			Source_InheritedFrom,
			Source_SelectYN
		INTO
			#CustomerInfo
		FROM
			(
	--Ordinary sources
			SELECT
				C.CustomerID,
				C.CustomerName,
				C.CustomerDescription, 
				I.InstanceID,
				I.InstanceName,
				I.InstanceDescription,
				I.ProductKey,
				I.Nyc,
				I.Nyu,
				A.ApplicationID,
				A.ApplicationName,
				A.ApplicationDescription,
				A.ApplicationServer,
				A.LanguageID,
				A.ETLDatabase,
				A.DestinationDatabase,
				A.AdminUser,
				Application_InheritedFrom = A.InheritedFrom,
				M.ModelID,
				M.ModelName,
				M.ModelDescription,
				M.BaseModelID,
				BaseModelName = BM.ModelName,
				Model_InheritedFrom = M.InheritedFrom,
				Model_SelectYN = M.SelectYN,
				L.LanguageCode,
				L.LanguageName,
				S.SourceID,
				S.SourceName,
				S.SourceDescription,
				S.SourceTypeID,
				ST.SourceTypeName,
				S.SourceDatabase,
				S.ETLDatabase_Linked,
				S.StartYear,
				Source_InheritedFrom = S.InheritedFrom,
				Source_SelectYN = S.SelectYN
			FROM
				Customer C
				INNER JOIN Instance I ON I.CustomerID = C.CustomerID
				INNER JOIN [Application] A ON A.InstanceID = I.InstanceID AND A.SelectYN <> 0
				INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
				LEFT JOIN [Source] S ON S.ModelID = M.ModelID AND (S.SelectYN <> 0 OR S.SourceID IS NULL)
				LEFT JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
				LEFT JOIN [Language] L ON L.LanguageID = A.LanguageID
			WHERE
				C.CustomerID = @CustomerID
			) sub

		IF @CreateXmlYN = 0
			SELECT * FROM #CustomerInfo
		ELSE
			BEGIN
				SELECT
				CustomerID,
				CustomerName,
				CustomerDescription, 
				InstanceID,
				InstanceName,
				InstanceDescription,
				ProductKey,
				Nyc,
				Nyu,
				ApplicationID,
				ApplicationName,
				ApplicationDescription,
				ApplicationServer,
				LanguageID,
				ETLDatabase,
				DestinationDatabase,
				AdminUser,
				ModelID,
				ModelName,
				ModelDescription,
				BaseModelID,
				Model_SelectYN,
				SourceID,
				SourceName,
				SourceDescription,
				SourceTypeID,
				SourceDatabase,
				ETLDatabase_Linked,
				StartYear,
				Source_SelectYN
			INTO
				#CustomerXML
			FROM
				#CustomerInfo

			--UPDATE
			--	Customer
			--SET
			--	XML_Export = (SELECT * FROM #CustomerXML FOR XML RAW, ROOT('table'))
			--WHERE
			--	CustomerID = @CustomerID 

		END

	SET @Step = 'Drop temp tables'			
		DROP TABLE #CustomerInfo
		IF @CreateXmlYN <> 0 DROP TABLE #CustomerXML

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
