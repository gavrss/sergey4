SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spAdvanced_Setup] AS

--Make sure you have all databases installed/linked/created on the server:
--Source databases; Epicor AFR, ERP (9-10.1), Enterprise, iScala, P21 or Microsoft Dynamics NAV

--Make sure you have correct values in the Metadata tables.
--Customer; Name of the company that owns the data.
--Instance; Name of the installations, i.e. = Location. At least one Instance is needed.
--Application; Some properties for each set of databases like database names and language. At least one Application is needed.
--Model; Name of the cubes that shall be created and type (Finance, Sales, Budgeting...). At least one Model is needed.
--Source; Name of the ERP sources and source databases. At least one Source is needed.

--Run the listed procedures one by one and follow the instructions.

EXEC [spGet_Customer_Metadata] @CustomerID = 333, @CreateXmlYN = 0         --Step  900, Shows your current settings
--If needed change in the above listed metadata tables

EXEC [spCreate_Linked_ETL_Script] @ApplicationID = 1317, @ManuallyYN = 1  --Step 131701100, If you have your source database on a Linked Server, you need to run this query from your source database to create a linked pcETL database

EXEC [spCreate_ETL_Object_Initial] @ApplicationID = 1317, @DataBaseBM = 1 --Step 131701200, Create the ETL database and all Tables, Procedures and Functions

EXEC [spInsert_ETL_Entity] @ApplicationID = 1317                          --Step 131701300, All Entities (Companies) will be loaded from the source database(s) into the ETL database.

--Investigate the members in the ETL Entity table.
--Change SelectYN from False (0) to True (1) for all Entities you want to integrate in your solution.
--Change to false if you want to exclude them.

EXEC [spInsert_ETL_FinancialSegment] @ApplicationID = 1317                --Step 131701500, Fill the ETL FinancialSegment table

EXEC [spInsert_ETL_MappedObject] @ApplicationID = 1317                    --Step 131701600, Records are now added to the MappedObject table.

--Optional: Investigate and make changes to the ETL MappedObject table
--The listed MappedObjectNames will during the process be added as Models, Dimensions and Properties to the planning model.
--Select the wanted objects. By default they are selected as most common.

EXEC [spInsert_SqlQuery] @ApplicationID = 1317                            --Step 131702090, Default SqlQueries will be added.
EXEC [spInsert_ETL_CheckSum] @ApplicationID = 1317                        --Step 131702100, Default CheckSums will be added.

EXEC [spCreate_Application] @ApplicationID = 1317                         --Step 131702200, Objects for the destination database will now be prepared

EXEC [spCreate_Job_Agent] @ApplicationID = 1317, @JobType = 'Create'            --Step 131702300, A SQL Server Agent job for creation of the destination database and importing objects will now be created

EXEC [spStart_Job_Agent] @ApplicationID = 1317, @StepName = 'Create'            --Step 131702400, SQL Server Agent will now create the destination database.
EXEC [spSet_User] @ApplicationID = 1317                                   --Step 131702420, Sets the default admin user
EXEC [spStart_Job_Agent] @ApplicationID = 1317, @StepName = 'Import'            --Step 131702440, SQL Server Agent will now import the new Models and Dimensions.

EXEC [spCreate_Canvas_Table] @ApplicationID = 1317                        --Step 131702500, All needed Canvas tables will now be created in the destination database.
EXEC [spCreate_Canvas_Procedure] @ApplicationID = 1317                    --Step 131702600, All needed Canvas procedures will now be created in the destination database.
EXEC [spCreate_Canvas_Report] @ApplicationID = 1317                       --Step 131702700, All standard reports will now be created in the destination database.

EXEC [spCreate_ETL_Object_Final] @ApplicationID = 1317                    --Step 131702800, All views and procedures that are used for selecting data from the source database(s) and inserts it to the destination database will now be created.

EXEC [pcETL_CBN].[dbo].[spIU_Load_All] @LoadTypeBM = 1, @FrequencyBM = 3, @Rows = 10000      --Step 131702900, All ETL tables will now be filled with data.

--Investigate the AccountType_Translate table and edit manually so that all CategoryIDs are correct translated into AccountTypes.
--This is an important step. It is possible to come back and redo it later.

EXEC [pcETL_CBN].[dbo].[spIU_Load_All] @LoadTypeBM = 2, @FrequencyBM = 3, @Rows = 10000      --Step 131703200, All dimension tables will be loaded. If the dimension tables are big, this will take a while the first time it is loading.

EXEC [spInsert_ExtraHierarchy_Member] @ApplicationID = 1317               --Step 131703300, Loads initial members to Extra hierarchies
EXEC [spCheck_HierarchyTables] @ApplicationID = 1317                      --Step 131703350, Check for empty hierarchies in all dimensions

EXEC [spCreate_Job_Agent] @ApplicationID = 1317, @JobType = 'Load'              --Step 131703400, A SQL Server Agent job for loading data into the destination database and deploying the cube(s) will now be created
EXEC [spStart_Job_Agent] @ApplicationID = 1317, @StepName = 'Deploy'            --Step 131703500, The Fact tables will be created and all the dimensions will now be deployed into the cube.

EXEC [spAlter_ChangeDatetime] @ApplicationID = 1317                       --Step 131703550, The ChangeDatetime field on all Fact tables will be changed to nvarchar(100)
EXEC [spCreate_ETL_Object_Initial] @ApplicationID = 1317, @DataBaseBM = 2 --Step 131703600, All ETL Objects in the Destination database will now be created.

EXEC [pcETL_CBN].[dbo].[spIU_Load_All] @LoadTypeBM = 28, @FrequencyBM = 3, @Rows = 10000     --Step 131703700, All FACT tables will now be loaded and the CheckSums will run.

EXEC [spStart_Job_Agent] @ApplicationID = 1317, @StepName = 'Deploy'            --Step 131703800, All the data will now be deployed into the cube.

EXEC [spInsert_Extension] @ApplicationID = 1317                           --Step 131705000, All licensed possible extension databases are added to the selection list.

--Investigate the Extension table and check the extra databases you want to create (set SelectYN = true).

EXEC [spCreate_pcEXTENSION] @ApplicationID = 1317                         --Step 131705100, All selected databases are created.

EXEC [spRun_pcOBJECT] @ApplicationID = 1317                               --Step 131705200, Runs any SPs defined in the pcOBJECT database

EXEC [spCreate_Linked_ETL_Script] @ApplicationID = 1322, @ManuallyYN = 1  --Step 132201100, If you have your source database on a Linked Server, you need to run this query from your source database to create a linked pcETL database

EXEC [spCreate_ETL_Object_Initial] @ApplicationID = 1322, @DataBaseBM = 1 --Step 132201200, Create the ETL database and all Tables, Procedures and Functions

EXEC [spInsert_ETL_Entity] @ApplicationID = 1322                          --Step 132201300, All Entities (Companies) will be loaded from the source database(s) into the ETL database.

--Investigate the members in the ETL Entity table.
--Change SelectYN from False (0) to True (1) for all Entities you want to integrate in your solution.
--Change to false if you want to exclude them.

EXEC [spInsert_ETL_FinancialSegment] @ApplicationID = 1322                --Step 132201500, Fill the ETL FinancialSegment table

EXEC [spInsert_ETL_MappedObject] @ApplicationID = 1322                    --Step 132201600, Records are now added to the MappedObject table.

--Optional: Investigate and make changes to the ETL MappedObject table
--The listed MappedObjectNames will during the process be added as Models, Dimensions and Properties to the planning model.
--Select the wanted objects. By default they are selected as most common.

EXEC [spInsert_SqlQuery] @ApplicationID = 1322                            --Step 132202090, Default SqlQueries will be added.
EXEC [spInsert_ETL_CheckSum] @ApplicationID = 1322                        --Step 132202100, Default CheckSums will be added.

EXEC [spCreate_Application] @ApplicationID = 1322                         --Step 132202200, Objects for the destination database will now be prepared

EXEC [spCreate_Job_Agent] @ApplicationID = 1322, @JobType = 'Create'            --Step 132202300, A SQL Server Agent job for creation of the destination database and importing objects will now be created

EXEC [spStart_Job_Agent] @ApplicationID = 1322, @StepName = 'Create'            --Step 132202400, SQL Server Agent will now create the destination database.
EXEC [spSet_User] @ApplicationID = 1322                                   --Step 132202420, Sets the default admin user
EXEC [spStart_Job_Agent] @ApplicationID = 1322, @StepName = 'Import'            --Step 132202440, SQL Server Agent will now import the new Models and Dimensions.

EXEC [spCreate_Canvas_Table] @ApplicationID = 1322                        --Step 132202500, All needed Canvas tables will now be created in the destination database.
EXEC [spCreate_Canvas_Procedure] @ApplicationID = 1322                    --Step 132202600, All needed Canvas procedures will now be created in the destination database.
EXEC [spCreate_Canvas_Report] @ApplicationID = 1322                       --Step 132202700, All standard reports will now be created in the destination database.

EXEC [spCreate_ETL_Object_Final] @ApplicationID = 1322                    --Step 132202800, All views and procedures that are used for selecting data from the source database(s) and inserts it to the destination database will now be created.

EXEC [pcETL_CBN_Pilot].[dbo].[spIU_Load_All] @LoadTypeBM = 1, @FrequencyBM = 3, @Rows = 10000      --Step 132202900, All ETL tables will now be filled with data.

--Investigate the AccountType_Translate table and edit manually so that all CategoryIDs are correct translated into AccountTypes.
--This is an important step. It is possible to come back and redo it later.

EXEC [pcETL_CBN_Pilot].[dbo].[spIU_Load_All] @LoadTypeBM = 2, @FrequencyBM = 3, @Rows = 10000      --Step 132203200, All dimension tables will be loaded. If the dimension tables are big, this will take a while the first time it is loading.

EXEC [spInsert_ExtraHierarchy_Member] @ApplicationID = 1322               --Step 132203300, Loads initial members to Extra hierarchies
EXEC [spCheck_HierarchyTables] @ApplicationID = 1322                      --Step 132203350, Check for empty hierarchies in all dimensions

EXEC [spCreate_Job_Agent] @ApplicationID = 1322, @JobType = 'Load'              --Step 132203400, A SQL Server Agent job for loading data into the destination database and deploying the cube(s) will now be created
EXEC [spStart_Job_Agent] @ApplicationID = 1322, @StepName = 'Deploy'            --Step 132203500, The Fact tables will be created and all the dimensions will now be deployed into the cube.

EXEC [spAlter_ChangeDatetime] @ApplicationID = 1322                       --Step 132203550, The ChangeDatetime field on all Fact tables will be changed to nvarchar(100)
EXEC [spCreate_ETL_Object_Initial] @ApplicationID = 1322, @DataBaseBM = 2 --Step 132203600, All ETL Objects in the Destination database will now be created.

EXEC [pcETL_CBN_Pilot].[dbo].[spIU_Load_All] @LoadTypeBM = 28, @FrequencyBM = 3, @Rows = 10000     --Step 132203700, All FACT tables will now be loaded and the CheckSums will run.

EXEC [spStart_Job_Agent] @ApplicationID = 1322, @StepName = 'Deploy'            --Step 132203800, All the data will now be deployed into the cube.

EXEC [spInsert_Extension] @ApplicationID = 1322                           --Step 132205000, All licensed possible extension databases are added to the selection list.

--Investigate the Extension table and check the extra databases you want to create (set SelectYN = true).

EXEC [spCreate_pcEXTENSION] @ApplicationID = 1322                         --Step 132205100, All selected databases are created.

EXEC [spRun_pcOBJECT] @ApplicationID = 1322                               --Step 132205200, Runs any SPs defined in the pcOBJECT database

EXEC [spCheck_Setup] @InstanceID = 413                                    --Step 132209000, Summary of the messages during setup.

--Use the Modeler and investigate the modified Application.
--As long as you dont run any spCREATE PROCEDUREs it is now possible to make manual adjustments to the Views and Procedures that are
--used for loading data from AFR/E9 into EPM Planning.

--It is also possible to use the Modeler for manual adjustments. It is needed to make correct hierarchies for the dimensions.
--Changes of the hierarchies done by the Modeler will not be overwritten.

--Check the data quality. A common problem is the signs for different accounts.
--Go back to the AccountType_Translate table and check the translations.
--If you make changes, you need to run spIU_Load_All and Deploy the Application for the changes to take effect.
GO
