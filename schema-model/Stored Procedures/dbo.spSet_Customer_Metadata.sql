SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_Customer_Metadata] 

	@JobID int = 0,
	@XML xml = NULL,
	@AdvancedYN bit = NULL, --If <> 0 (True), the integration steps will not run.
	@SetXmlYN bit = 1,
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

-- @SetXmlYN = 0, @Debug = 0  --Nothing happen
-- @SetXmlYN = 0, @Debug = 1  --Only view the XML
-- @SetXmlYN = 1, @Debug = 1  --Set XML (update metadata tables) and view the content
-- @SetXmlYN = 1, @Debug = 0  --Only set XML (update metadata tables)

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@CustomerID int,
	@InstanceID int,
	@ApplicationID int,
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.1.2124'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.3.2107' SET @Description = '@Nyc added. Procedure candidate to be removed.'
		IF @Version = '1.3.1.2124' SET @Description = '@Nyu added.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @XML IS NULL OR @AdvancedYN IS NULL
	BEGIN
		PRINT 'Parameter @XML and parameter @AdvancedYN must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

	SET @Step = 'Read XML'
		SELECT
			Tab.Col.value('@CustomerID','int') AS CustomerID,
			Tab.Col.value('@CustomerName', 'nvarchar(100)') AS CustomerName,
			Tab.Col.value('@CustomerDescription', 'nvarchar(255)') AS CustomerDescription, 
			Tab.Col.value('@InstanceID','int') AS InstanceID,
			Tab.Col.value('@InstanceName', 'nvarchar(100)') AS InstanceName,
			Tab.Col.value('@InstanceDescription', 'nvarchar(255)') AS InstanceDescription,
			Tab.Col.value('@ProductKey', 'nvarchar(17)') AS ProductKey,
			Tab.Col.value('@Nyc', 'int') AS Nyc,
			Tab.Col.value('@Nyu', 'nvarchar(50)') AS Nyu,
			Tab.Col.value('@ApplicationID','int') AS ApplicationID,
			Tab.Col.value('@ApplicationName', 'nvarchar(100)') AS ApplicationName,
			Tab.Col.value('@ApplicationDescription', 'nvarchar(255)') AS ApplicationDescription,
			Tab.Col.value('@ApplicationServer','nvarchar(100)') AS ApplicationServer,
			Tab.Col.value('@LanguageID','int') AS LanguageID,
			Tab.Col.value('@ETLDatabase', 'nvarchar(100)') AS ETLDatabase,
			Tab.Col.value('@DestinationDatabase', 'nvarchar(100)') AS DestinationDatabase,
			Tab.Col.value('@AdminUser', 'nvarchar(100)') AS AdminUser,
			Tab.Col.value('@ModelID','int') AS ModelID,
			Tab.Col.value('@ModelName', 'nvarchar(100)') AS ModelName,
			Tab.Col.value('@ModelDescription', 'nvarchar(255)') AS ModelDescription,
			Tab.Col.value('@BaseModelID','int') AS BaseModelID,
			Tab.Col.value('@Model_SelectYN','bit') AS Model_SelectYN,
			Tab.Col.value('@SourceID','int') AS SourceID,
			Tab.Col.value('@SourceName', 'nvarchar(100)') AS SourceName,
			Tab.Col.value('@SourceDescription', 'nvarchar(100)') AS SourceDescription,
			Tab.Col.value('@SourceTypeID','int') AS SourceTypeID,
			Tab.Col.value('@SourceDatabase', 'nvarchar(100)') AS SourceDatabase,
			Tab.Col.value('@StartYear','int') AS StartYear,
			Tab.Col.value('@Source_SelectYN','bit') AS Source_SelectYN
		INTO
			#CustomerInfo
		FROM
			@XML.nodes('table/row') Tab(Col)

	SET @Step = 'Create temp tables'
		SELECT DISTINCT CustomerID, CustomerName, CustomerDescription INTO #Customer FROM #CustomerInfo WHERE CustomerID IS NOT NULL
		SELECT DISTINCT InstanceID, InstanceName, InstanceDescription, CustomerID, ProductKey, Nyc, Nyu INTO #Instance FROM #CustomerInfo WHERE InstanceID IS NOT NULL
		SELECT DISTINCT ApplicationID, ApplicationName, ApplicationDescription, ApplicationServer, InstanceID, LanguageID, ETLDatabase, DestinationDatabase, AdminUser = ISNULL(AdminUser, 'DOMAIN\Administrator') INTO #Application FROM #CustomerInfo  WHERE ApplicationID IS NOT NULL
		SELECT DISTINCT ModelID, ModelName, ModelDescription, ApplicationID, BaseModelID, SelectYN = Model_SelectYN INTO #Model FROM #CustomerInfo WHERE ModelID IS NOT NULL
		SELECT DISTINCT SourceID, SourceName, SourceDescription, ModelID, SourceTypeID, SourceDatabase, StartYear, SelectYN = Source_SelectYN INTO #Source FROM #CustomerInfo WHERE SourceID IS NOT NULL

		IF @Debug <> 0 
			BEGIN
				Select * FROM #CustomerInfo
				Select * FROM #Customer
				Select * FROM #Instance
				Select * FROM #Application
				Select * FROM #Model
				Select * FROM #Source
			END

	SET @Step = 'Set values from XML'
		IF @SetXmlYN = 1
			BEGIN
	SET @Step = 'Insert into Customer'
				SET IDENTITY_INSERT Customer ON
					INSERT INTO Customer
						(
						CustomerID,
						CustomerName,
						CustomerDescription,
						XML_Import
						)
					SELECT
						CustomerID,
						CustomerName,
						CustomerDescription,
						@XML
					FROM
						#Customer T
					WHERE
						NOT EXISTS (SELECT 1 FROM Customer D WHERE D.CustomerID = T.CustomerID)

				SET @Inserted = @Inserted + @@ROWCOUNT
				SET IDENTITY_INSERT Customer OFF

	SET @Step = 'Update Customer'
				UPDATE D
				SET
					CustomerName = T.CustomerName,
					CustomerDescription = T.CustomerDescription,
					XML_Import = @XML
				FROM
					Customer D
					INNER JOIN #Customer T ON T.CustomerID = D.CustomerID

				SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert into Instance'
				SET IDENTITY_INSERT Instance ON
					INSERT INTO Instance
						(
						InstanceID,
						InstanceName,
						InstanceDescription,
						CustomerID,
						ProductKey,
						Nyc,
						Nyu
						)
					SELECT
						InstanceID,
						InstanceName,
						InstanceDescription,
						CustomerID,
						ProductKey,
						Nyc,
						Nyu
					FROM
						#Instance T
					WHERE
						NOT EXISTS (SELECT 1 FROM Instance D WHERE D.InstanceID = T.InstanceID)

				SET @Inserted = @Inserted + @@ROWCOUNT
				SET IDENTITY_INSERT Instance OFF

	SET @Step = 'Update Instance'
				UPDATE D
				SET
					InstanceName = T.InstanceName,
					InstanceDescription = T.InstanceDescription,
					ProductKey = T.ProductKey,
					Nyc = T.Nyc,
					Nyu = T.Nyu
				FROM
					Instance D
					INNER JOIN #Instance T ON T.InstanceID = D.InstanceID AND T.CustomerID = D.CustomerID

				SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert into Application'
				SET IDENTITY_INSERT [Application] ON
					INSERT INTO [Application]
						(
						ApplicationID,
						ApplicationName,
						ApplicationDescription,
						ApplicationServer,
						InstanceID,
						LanguageID,
						ETLDatabase,
						DestinationDatabase,
						AdminUser
						)
					SELECT
						ApplicationID,
						ApplicationName,
						ApplicationDescription,
						ApplicationServer,
						InstanceID,
						LanguageID,
						ETLDatabase,
						DestinationDatabase,
						AdminUser
					FROM
						#Application T
					WHERE
						NOT EXISTS (SELECT 1 FROM [Application] D WHERE D.ApplicationID = T.ApplicationID)

				SET @Inserted = @Inserted + @@ROWCOUNT
				SET IDENTITY_INSERT [Application] OFF

	SET @Step = 'Update Application'
				UPDATE D
				SET
					ApplicationName = T.ApplicationName,
					ApplicationDescription = T.ApplicationDescription,
					ApplicationServer = T.ApplicationServer,
					LanguageID = T.LanguageID,
					ETLDatabase = T.ETLDatabase,
					DestinationDatabase = T.DestinationDatabase--,
--					AdminUser = T.AdminUser
				FROM
					[Application] D
					INNER JOIN #Application T ON T.ApplicationID = D.ApplicationID AND T.InstanceID = D.InstanceID

				SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert into Model'
				SET IDENTITY_INSERT Model ON
					INSERT INTO Model
						(
						ModelID,
						ModelName,
						ModelDescription,
						ApplicationID,
						BaseModelID,
						SelectYN
						)
					SELECT
						ModelID,
						ModelName,
						ModelDescription,
						ApplicationID,
						BaseModelID,
						SelectYN
					FROM
						#Model T
					WHERE
						NOT EXISTS (SELECT 1 FROM Model D WHERE D.ModelID = T.ModelID)

				SET @Inserted = @Inserted + @@ROWCOUNT
				SET IDENTITY_INSERT Model OFF

	SET @Step = 'Update Model'
				UPDATE D
				SET
					ModelName = T.ModelName,
					ModelDescription = T.ModelDescription,
					BaseModelID = T.BaseModelID,
					SelectYN = T.SelectYN
				FROM
					Model D
					INNER JOIN #Model T ON T.ModelID = D.ModelID AND D.ApplicationID = T.ApplicationID

				SET @Updated = @Updated + @@ROWCOUNT
				
	SET @Step = 'Insert into Source'
				SET IDENTITY_INSERT Source ON
					INSERT INTO Source
						(
						SourceID,
						SourceName,
						SourceDescription,
						ModelID,
						SourceTypeID,
						SourceDatabase,
						StartYear,
						SelectYN
						)
					SELECT
						SourceID,
						SourceName,
						SourceDescription,
						ModelID,
						SourceTypeID,
						SourceDatabase,
						StartYear,
						SelectYN
					FROM
						#Source T
					WHERE
						NOT EXISTS (SELECT 1 FROM Source D WHERE D.SourceID = T.SourceID)

				SET @Inserted = @Inserted + @@ROWCOUNT
				SET IDENTITY_INSERT Source OFF

	SET @Step = 'Update Source'
				UPDATE D
				SET
					SourceName = T.SourceName,
					SourceDescription = T.SourceDescription,
					SourceTypeID = T.SourceTypeID,
					SourceDatabase = T.SourceDatabase,
					StartYear = T.StartYear,
					SelectYN = T.SelectYN
				FROM
					Source D
					INNER JOIN #Source T ON T.SourceID = D.SourceID AND D.ModelID = T.ModelID

				SET @Updated = @Updated + @@ROWCOUNT
				
	SET @Step = 'Create spAdvanced_Setup procedure'
				SELECT @CustomerID = CustomerID FROM #Customer
				EXEC spCreate_Advanced_Setup @CustomerID

	SET @Step = 'Run all integration steps'
				IF @AdvancedYN <> 0
					BEGIN
						RAISERROR ('Use SQL Server Management Studio and run the procedure spAdvanced_Setup step by step', 0, 1) WITH NOWAIT
					END
				ELSE
					BEGIN
						RAISERROR ('Old functionality replaced by GUI.', 0, 1) WITH NOWAIT
/*						 
						SELECT @InstanceID = InstanceID FROM #Instance
						SELECT @ApplicationID = ApplicationID, @ETLDatabase = ETLDatabase FROM #Application

						RAISERROR ('The ETL database and its initially needed objects will now be created.', 0, 1) WITH NOWAIT
						EXEC [spCreate_ETL_Object_Initial] @InstanceID = @InstanceID 
						RAISERROR ('The ETL database and its initially needed objects are now created.', 0, 1) WITH NOWAIT

						RAISERROR ('Records will now be added to the ETL Entity table.', 0, 1) WITH NOWAIT
						EXEC [spInsert_ETL_Entity] @ApplicationID = @ApplicationID
						RAISERROR ('Records are now added to the ETL Entity table.', 0, 1) WITH NOWAIT
						--Investigate the members in the ETL Entity table.
						--Change SelectYN from False (0) to True (1) for all Entities you want to integrate in your solution.
						--Change to false if you want to exclude them.

						RAISERROR ('Views for Finance segments will now be created.', 0, 1) WITH NOWAIT
						EXEC [spCreate_Dimension_View_Finance_Metadata] @ApplicationID = @ApplicationID
						RAISERROR ('Views for Finance segments are now created.', 0, 1) WITH NOWAIT

						RAISERROR ('Records will now be added to the ETL MappedObject table.', 0, 1) WITH NOWAIT
						EXEC [spInsert_ETL_MappedObject] @ApplicationID = @ApplicationID
						RAISERROR ('Records are now added to the ETL MappedObject table.', 0, 1) WITH NOWAIT
						--Optional: Investigate and make changes to the ETL MappedObject table
						--The listed ObjectNames will during the process be added as Models, Dimensions and Properties to the planning model.
						--Select the wanted objects. By default they are all selected.

						RAISERROR ('Default CheckSums will now be added.', 0, 1) WITH NOWAIT
						EXEC [spInsert_ETL_CheckSum] @ApplicationID = @ApplicationID
						RAISERROR ('Default CheckSums are now added.', 0, 1) WITH NOWAIT

						RAISERROR ('Objects for the destination database will now be prepared.', 0, 1) WITH NOWAIT
						EXEC [spCreate_Application] @ApplicationID = @ApplicationID
						RAISERROR ('Objects for the destination database are now prepared.', 0, 1) WITH NOWAIT

						RAISERROR ('A SQL Server Agent job for Create and Import will now be created.', 0, 1) WITH NOWAIT
						EXEC spCreate_Job @ApplicationID = @ApplicationID, @JobType = 'Create'
						RAISERROR ('A SQL Server Agent job for Create and Import is now created.', 0, 1) WITH NOWAIT
						
						RAISERROR ('SQL Server Agent will now create the destination database and import the new Models and Dimensions.', 0, 1) WITH NOWAIT
						EXEC spStart_Job @ApplicationID = @ApplicationID, @StepName = 'Create'
						RAISERROR ('SQL Server Agent has now created the destination database and imported the new Models and Dimensions.', 0, 1) WITH NOWAIT
						
						RAISERROR ('All needed Canvas tables will now be created in the destination database.', 0, 1) WITH NOWAIT
						EXEC [spCreate_Canvas_Table] @ApplicationID = @ApplicationID
						RAISERROR ('All needed Canvas tables are now created in the destination database.', 0, 1) WITH NOWAIT

						RAISERROR ('All needed Canvas procedures will now be created in the destination database.', 0, 1) WITH NOWAIT
						EXEC [spCreate_Canvas_Procedure] @ApplicationID = @ApplicationID
						RAISERROR ('All needed Canvas procedures are now created in the destination database.', 0, 1) WITH NOWAIT

						RAISERROR ('All standard reports will now be added into the destination database.', 0, 1) WITH NOWAIT
						EXEC [spCreate_Canvas_Report] @ApplicationID = @ApplicationID
						RAISERROR ('All standard reports are now added into the destination database.', 0, 1) WITH NOWAIT

						RAISERROR ('All views and procedures that are used for selecting data from the source database(s) and inserts it to the destination database will now be created.', 0, 1) WITH NOWAIT
						EXEC spCreate_ETL_Object_Final @ApplicationID = @ApplicationID
						RAISERROR ('All views and procedures are now created.', 0, 1) WITH NOWAIT

						RAISERROR ('All ETL tables will now be filled with data', 0, 1) WITH NOWAIT
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.[spIU_Load_All] @LoadTypeBM = 1' 
						EXEC (@SQLStatement)
						RAISERROR ('All ETL tables are now filled with data', 0, 1) WITH NOWAIT
						--Investigate the AccountType_Translate table and edit manually so that all CategoryIDs are correct translated into AccountTypes.
						--This is an important step. It is possible to come back and redo it later.

						RAISERROR ('All dimension tables will now be loaded.', 0, 1) WITH NOWAIT
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.[spIU_Load_All] @LoadTypeBM = 2'
						EXEC (@SQLStatement)
						RAISERROR ('All dimension tables are now loaded.', 0, 1) WITH NOWAIT

						RAISERROR ('A SQL Server Agent job for Load and Deploy will now be created.', 0, 1) WITH NOWAIT
						EXEC spCreate_Job @ApplicationID = @ApplicationID, @JobType = 'Load'
						RAISERROR ('A SQL Server Agent job for Load and Deploy is now created. It is by default scheduled to run at 02.00 AM every night.', 0, 1) WITH NOWAIT

						RAISERROR ('All the dimensions will now be deployed into the cube.', 0, 1) WITH NOWAIT
						EXEC spStart_Job @ApplicationID = @ApplicationID, @StepName = 'Deploy'
						RAISERROR ('All the dimensions are now deployed into the cube.', 0, 1) WITH NOWAIT

						RAISERROR ('All FACT tables will now be loaded and the CheckSums will run.', 0, 1) WITH NOWAIT
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.[spIU_Load_All] @LoadTypeBM = 12'
						EXEC (@SQLStatement)
						RAISERROR ('All FACT tables are now loaded and the CheckSums have run.', 0, 1) WITH NOWAIT
						
						RAISERROR ('All data will now be deployed into the cube.', 0, 1) WITH NOWAIT
						EXEC spStart_Job @ApplicationID = @ApplicationID, @StepName = 'Deploy'
						RAISERROR ('All data is now deployed into the cube. It is time to take a first look and make needed adjustments.', 0, 1) WITH NOWAIT
*/						
					END

	END

	SET @Step = 'Drop all temp tables'
		DROP TABLE #CustomerInfo
		DROP TABLE #Customer
		DROP TABLE #Instance
		DROP TABLE #Application
		DROP TABLE #Model
		DROP TABLE #Source

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH






GO
