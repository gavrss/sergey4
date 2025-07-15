SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Create_Advanced_Setup]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@CustomerID int = NULL,
	@StepTypeBM int = 1, --1 = Setup, 1024 = Upgrade

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000414,
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
EXEC [sp_Tool_Create_Advanced_Setup] @CustomerID = 6, @Debug = true
EXEC [sp_Tool_Create_Advanced_Setup] @CustomerID = 6, @StepTypeBM = 1024, @Debug = true
EXEC [sp_Tool_Create_Advanced_Setup] @CustomerID = 400, @Debug = true
EXEC [sp_Tool_Create_Advanced_Setup] @CustomerID = -1017, @Debug = 1
EXEC [sp_Tool_Create_Advanced_Setup] @CustomerID = 192, @Debug = 1
EXEC [sp_Tool_Create_Advanced_Setup] @CustomerID = 361, @Debug = 1 --Stoiximan
EXEC [sp_Tool_Create_Advanced_Setup] @CustomerID = 333, @Debug = 1 --CBN

EXEC [sp_Tool_Create_Advanced_Setup] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@ETLDatabase nvarchar(100),
	@ApplicationID int,
	@CustomerID_nvarchar nvarchar(50),
	@InstanceID_nvarchar nvarchar(50),
	@ApplicationID_nvarchar nvarchar(50),
	@Counter int,
	@StepCalc int = 0,
	@Action nvarchar(10),

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
			@ProcedureDescription = 'Create spAdvanced_Setup',
			@MandatoryParameter = 'CustomerID' --Without @, separated by |

		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2053' SET @Description = 'Included job steps changed.'
		IF @Version = '1.2.2061' SET @Description = 'ALTER handling'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.2071' SET @Description = 'Added new LoadType.'
		IF @Version = '1.3.2073' SET @Description = 'Sync with XML-file.'
		IF @Version = '1.3.2074' SET @Description = 'Added step 3300 (extra hierarchies).'
		IF @Version = '1.3.2075' SET @Description = 'Added step 1100 (pcETL_LINKED script).'
		IF @Version = '1.3.2078' SET @Description = 'Handle multiple Applications.'
		IF @Version = '1.3.2084' SET @Description = 'Splitted the CREATE-job.'
		IF @Version = '1.3.2098' SET @Description = 'Implemented FinancialSegment ETL table.'
		IF @Version = '1.3.2107' SET @Description = 'Changed inparameter for spCreate_ETL_Object_Initial from @InstanceID to @ApplicationID.'
		IF @Version = '1.3.2109' SET @Description = 'Brackets added around @ETLDatabase.'
		IF @Version = '1.3.2112' SET @Description = 'Added spAlter_ChangeDatetime.'
		IF @Version = '1.3.2116' SET @Description = 'Cosmetic change of descriptions.'
		IF @Version = '1.3.1.2121' SET @Description = 'Added Upgrade.'
		IF @Version = '1.3.1.2124' SET @Description = 'Added step 3350 (Check for empty hierarchies).'
		IF @Version = '1.4.0.2136' SET @Description = 'Check SelectYN on Instance'
		IF @Version = '2.0.2.2144' SET @Description = 'Renamed to [sp_Tool_Create_Advanced_Setup]'
		IF @Version = '2.0.3.2154' SET @Description = 'Updated template.'

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

		SELECT
			@InstanceID = ISNULL(@InstanceID, MAX(I.InstanceID)),
			@Rows = ISNULL(@Rows, MAX(I.[Rows]))
		FROM
			Instance I 
		WHERE
			I.CustomerID = @CustomerID AND
			I.SelectYN <> 0

		SELECT
			@CustomerID_nvarchar = CONVERT(nvarchar(50), @CustomerID),
			@InstanceID_nvarchar = CONVERT(nvarchar(50), @InstanceID)

		SELECT 
			@Counter = COUNT(1)
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			(A.VersionID = @VersionID OR @VersionID IS NULL) AND
			A.ApplicationID > 0 AND
			A.SelectYN <> 0

	SET @Step = 'Determine CREATE or ALTER'
		IF (SELECT COUNT(1) FROM sys.procedures WHERE type = 'P' AND name = 'spAdvanced_Setup') = 0
			SET @Action = 'CREATE'
		ELSE
			SET @Action = 'ALTER'

	SET @Step = 'Set SQL Statement'
		SET @SQLStatement = @Action + ' PROCEDURE [dbo].[spAdvanced_Setup] AS

--Make sure you have all databases installed/linked/created on the server:
--Source databases; Epicor AFR, ERP (9-10.1), Enterprise, iScala, P21 or Microsoft Dynamics NAV

--Make sure you have correct values in the Metadata tables.
--Customer; Name of the company that owns the data.
--Instance; Name of the installations, i.e. = Location. At least one Instance is needed.
--Application; Some properties for each set of databases like database names and language. At least one Application is needed.
--Model; Name of the cubes that shall be created and type (Finance, Sales, Budgeting...). At least one Model is needed.
--Source; Name of the ERP sources and source databases. At least one Source is needed.

--Run the listed procedures one by one and follow the instructions.'

IF @StepTypeBM & 1024 > 0 SET @SQLStatement = @SQLStatement + '

EXEC [spCreate_pcINTEGRATOR_BU]                                          --Step  ' + CONVERT(nvarchar(20), @StepCalc + 100) + ', Create a backup of the old pcINTEGRATOR'

IF @StepTypeBM & 1 > 0 SET @SQLStatement = @SQLStatement + '

EXEC [spGet_Customer_Metadata] @CustomerID = ' + @CustomerID_nvarchar + ', @CreateXmlYN = 0         --Step  ' + CONVERT(nvarchar(20), @StepCalc + 900) + ', Shows your current settings
--If needed change in the above listed metadata tables'

		IF @Debug <> 0 SELECT [Action] = @Action, [InstanceID] = @InstanceID, [Rows] = @Rows
		IF @Debug <> 0 PRINT @SQLStatement

	SET @Step = 'Create Advanced_Setup_Application_Cursor'
		DECLARE Advanced_Setup_Application_Cursor CURSOR FOR

			SELECT 
				ApplicationID = A.ApplicationID,
				ApplicationID_nvarchar = CONVERT(nvarchar(50), A.ApplicationID),
				ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']',
				StepCalc = CASE WHEN @Counter > 1 THEN A.ApplicationID * 100000 ELSE 0 END
			FROM
				[Application] A
			WHERE
				A.InstanceID = @InstanceID AND
				A.ApplicationID <> 0 AND
				A.SelectYN <> 0
			ORDER BY
				A.ApplicationID

			OPEN Advanced_Setup_Application_Cursor
			FETCH NEXT FROM Advanced_Setup_Application_Cursor INTO @ApplicationID, @ApplicationID_nvarchar, @ETLDatabase, @StepCalc

			WHILE @@FETCH_STATUS = 0
				BEGIN

IF @StepTypeBM & 1024 > 0 SET @SQLStatement = @SQLStatement + '

EXEC [spFetch_pcINTEGRATOR_BU]                                           --Step ' + CONVERT(nvarchar(20), @StepCalc + 1010) + ', ' + [dbo].[GetStepDescription] (1010) + '

EXEC [spCreate_pcEXCHANGE] @pcExchangeType = ''''Upgrade''''                   --Step ' + CONVERT(nvarchar(20), @StepCalc + 1020) + ', ' + [dbo].[GetStepDescription] (1020) + '

EXEC [spGet_Customer_Metadata] @CustomerID = ' + @CustomerID_nvarchar + ', @CreateXmlYN = 0       --Step ' + CONVERT(nvarchar(20), @StepCalc + 1080) + ', Shows your current settings
--If needed change in the above listed metadata tables'

IF @StepTypeBM & 1025 > 0 SET @SQLStatement = @SQLStatement + '

EXEC [spCreate_Linked_ETL_Script] @ApplicationID = ' + @ApplicationID_nvarchar + ', @ManuallyYN = 1  --Step ' + CONVERT(nvarchar(20), @StepCalc + 1100) + ', ' + [dbo].[GetStepDescription] (1100) + '

EXEC [spCreate_ETL_Object_Initial] @ApplicationID = ' + @ApplicationID_nvarchar + ', @DataBaseBM = 1 --Step ' + CONVERT(nvarchar(20), @StepCalc + 1200) + ', ' + [dbo].[GetStepDescription] (1200) + '

EXEC [spInsert_ETL_Entity] @ApplicationID = ' + @ApplicationID_nvarchar + '                          --Step ' + CONVERT(nvarchar(20), @StepCalc + 1300) + ', ' + [dbo].[GetStepDescription] (1300) + '

--Investigate the members in the ETL Entity table.
--Change SelectYN from False (0) to True (1) for all Entities you want to integrate in your solution.
--Change to false if you want to exclude them.

EXEC [spInsert_ETL_FinancialSegment] @ApplicationID = ' + @ApplicationID_nvarchar + '                --Step ' + CONVERT(nvarchar(20), @StepCalc + 1500) + ', ' + [dbo].[GetStepDescription] (1500) + '

EXEC [spInsert_ETL_MappedObject] @ApplicationID = ' + @ApplicationID_nvarchar + '                    --Step ' + CONVERT(nvarchar(20), @StepCalc + 1600) + ', ' + [dbo].[GetStepDescription] (1600) + '

--Optional: Investigate and make changes to the ETL MappedObject table
--The listed MappedObjectNames will during the process be added as Models, Dimensions and Properties to the planning model.
--Select the wanted objects. By default they are selected as most common.

EXEC [spInsert_SqlQuery] @ApplicationID = ' + @ApplicationID_nvarchar + '                            --Step ' + CONVERT(nvarchar(20), @StepCalc + 2090) + ', ' + [dbo].[GetStepDescription] (2090) + '
EXEC [spInsert_ETL_CheckSum] @ApplicationID = ' + @ApplicationID_nvarchar + '                        --Step ' + CONVERT(nvarchar(20), @StepCalc + 2100) + ', ' + [dbo].[GetStepDescription] (2100) + '

EXEC [spCreate_Application] @ApplicationID = ' + @ApplicationID_nvarchar + '                         --Step ' + CONVERT(nvarchar(20), @StepCalc + 2200) + ', ' + [dbo].[GetStepDescription] (2200) + '

EXEC [spCreate_Job_Agent] @ApplicationID = ' + @ApplicationID_nvarchar + ', @JobType = ''''Create''''            --Step ' + CONVERT(nvarchar(20), @StepCalc + 2300) + ', ' + [dbo].[GetStepDescription] (2300) + '
'
IF @StepTypeBM & 1025 > 0 SET @SQLStatement = @SQLStatement + '
EXEC [spStart_Job_Agent] @ApplicationID = ' + @ApplicationID_nvarchar + ', @StepName = ''''Create''''            --Step ' + CONVERT(nvarchar(20), @StepCalc + 2400) + ', ' + [dbo].[GetStepDescription] (2400) + '
EXEC [spSet_User] @ApplicationID = ' + @ApplicationID_nvarchar + '                                   --Step ' + CONVERT(nvarchar(20), @StepCalc + 2420) + ', ' + [dbo].[GetStepDescription] (2420) + '
EXEC [spStart_Job_Agent] @ApplicationID = ' + @ApplicationID_nvarchar + ', @StepName = ''''Import''''            --Step ' + CONVERT(nvarchar(20), @StepCalc + 2440) + ', ' + [dbo].[GetStepDescription] (2440) + '

EXEC [spCreate_Canvas_Table] @ApplicationID = ' + @ApplicationID_nvarchar + '                        --Step ' + CONVERT(nvarchar(20), @StepCalc + 2500) + ', ' + [dbo].[GetStepDescription] (2500) + '
EXEC [spCreate_Canvas_Procedure] @ApplicationID = ' + @ApplicationID_nvarchar + '                    --Step ' + CONVERT(nvarchar(20), @StepCalc + 2600) + ', ' + [dbo].[GetStepDescription] (2600) + '
EXEC [spCreate_Canvas_Report] @ApplicationID = ' + @ApplicationID_nvarchar + '                       --Step ' + CONVERT(nvarchar(20), @StepCalc + 2700) + ', ' + [dbo].[GetStepDescription] (2700) + '

EXEC [spCreate_ETL_Object_Final] @ApplicationID = ' + @ApplicationID_nvarchar + '                    --Step ' + CONVERT(nvarchar(20), @StepCalc + 2800) + ', ' + [dbo].[GetStepDescription] (2800)

IF @StepTypeBM & 1024 > 0 SET @SQLStatement = @SQLStatement + '

EXEC [spFetch_UpgradeManualObjects]                                      --Step ' + CONVERT(nvarchar(20), @StepCalc + 2850) + ', ' + [dbo].[GetStepDescription] (2850)

IF @StepTypeBM & 1025 > 0 SET @SQLStatement = @SQLStatement + '

EXEC ' + @ETLDatabase + '.[dbo].[spIU_Load_All] @LoadTypeBM = 1, @FrequencyBM = 3, @Rows = ' + CONVERT(nvarchar(10), @Rows) + '      --Step ' + CONVERT(nvarchar(20), @StepCalc + 2900) + ', ' + [dbo].[GetStepDescription] (2900) + '

--Investigate the AccountType_Translate table and edit manually so that all CategoryIDs are correct translated into AccountTypes.
--This is an important step. It is possible to come back and redo it later.

EXEC ' + @ETLDatabase + '.[dbo].[spIU_Load_All] @LoadTypeBM = 2, @FrequencyBM = 3, @Rows = ' + CONVERT(nvarchar(10), @Rows) + '      --Step ' + CONVERT(nvarchar(20), @StepCalc + 3200) + ', ' + [dbo].[GetStepDescription] (3200) + '

EXEC [spInsert_ExtraHierarchy_Member] @ApplicationID = ' + @ApplicationID_nvarchar + '               --Step ' + CONVERT(nvarchar(20), @StepCalc + 3300) + ', ' + [dbo].[GetStepDescription] (3300) + '
EXEC [spCheck_HierarchyTables] @ApplicationID = ' + @ApplicationID_nvarchar + '                      --Step ' + CONVERT(nvarchar(20), @StepCalc + 3350) + ', ' + [dbo].[GetStepDescription] (3350) + '

EXEC [spCreate_Job_Agent] @ApplicationID = ' + @ApplicationID_nvarchar + ', @JobType = ''''Load''''              --Step ' + CONVERT(nvarchar(20), @StepCalc + 3400) + ', ' + [dbo].[GetStepDescription] (3400) + '
EXEC [spStart_Job_Agent] @ApplicationID = ' + @ApplicationID_nvarchar + ', @StepName = ''''Deploy''''            --Step ' + CONVERT(nvarchar(20), @StepCalc + 3500) + ', ' + [dbo].[GetStepDescription] (3500) + '

EXEC [spAlter_ChangeDatetime] @ApplicationID = ' + @ApplicationID_nvarchar + '                       --Step ' + CONVERT(nvarchar(20), @StepCalc + 3550) + ', ' + [dbo].[GetStepDescription] (3550) + '
EXEC [spCreate_ETL_Object_Initial] @ApplicationID = ' + @ApplicationID_nvarchar + ', @DataBaseBM = 2 --Step ' + CONVERT(nvarchar(20), @StepCalc + 3600) + ', ' + [dbo].[GetStepDescription] (3600) + '

EXEC ' + @ETLDatabase + '.[dbo].[spIU_Load_All] @LoadTypeBM = 28, @FrequencyBM = 3, @Rows = ' + CONVERT(nvarchar(10), @Rows) + '     --Step ' + CONVERT(nvarchar(20), @StepCalc + 3700) + ', ' + [dbo].[GetStepDescription] (3700) + '

EXEC [spStart_Job_Agent] @ApplicationID = ' + @ApplicationID_nvarchar + ', @StepName = ''''Deploy''''            --Step ' + CONVERT(nvarchar(20), @StepCalc + 3800) + ', ' + [dbo].[GetStepDescription] (3800) + '

EXEC [spInsert_Extension] @ApplicationID = ' + @ApplicationID_nvarchar + '                           --Step ' + CONVERT(nvarchar(20), @StepCalc + 5000) + ', ' + [dbo].[GetStepDescription] (5000) + '

--Investigate the Extension table and check the extra databases you want to create (set SelectYN = true).

EXEC [spCreate_pcEXTENSION] @ApplicationID = ' + @ApplicationID_nvarchar + '                         --Step ' + CONVERT(nvarchar(20), @StepCalc + 5100) + ', ' + [dbo].[GetStepDescription] (5100) + '

EXEC [spRun_pcOBJECT] @ApplicationID = ' + @ApplicationID_nvarchar + '                               --Step ' + CONVERT(nvarchar(20), @StepCalc + 5200) + ', ' + [dbo].[GetStepDescription] (5200)

					FETCH NEXT FROM Advanced_Setup_Application_Cursor INTO @ApplicationID, @ApplicationID_nvarchar, @ETLDatabase, @StepCalc
				END

		CLOSE Advanced_Setup_Application_Cursor
		DEALLOCATE Advanced_Setup_Application_Cursor		

IF @StepTypeBM & 1025 > 0 SET @SQLStatement = @SQLStatement + '

EXEC [spCheck_Setup] @InstanceID = ' + @InstanceID_nvarchar + '                                    --Step ' + CONVERT(nvarchar(20), @StepCalc + 9000) + ', ' + [dbo].[GetStepDescription] (9000) + '

--Use the Modeler and investigate the modified Application.
--As long as you dont run any spCREATE PROCEDUREs it is now possible to make manual adjustments to the Views and Procedures that are
--used for loading data from AFR/E9 into EPM Planning.

--It is also possible to use the Modeler for manual adjustments. It is needed to make correct hierarchies for the dimensions.
--Changes of the hierarchies done by the Modeler will not be overwritten.

--Check the data quality. A common problem is the signs for different accounts.
--Go back to the AccountType_Translate table and check the translations.
--If you make changes, you need to run spIU_Load_All and Deploy the Application for the changes to take effect.'

		IF @Debug <> 0 PRINT @SQLStatement 

	SET @Step = 'CREATE PROCEDURE'			
		SET @SQLStatement = 'EXEC sp_executesql N''' + @SQLStatement + ''''
		EXEC (@SQLStatement)

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
