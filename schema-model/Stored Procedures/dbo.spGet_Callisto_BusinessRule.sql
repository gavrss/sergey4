SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Callisto_BusinessRule]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000578,
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
EXEC [spGet_Callisto_BusinessRule] @UserID=-10, @InstanceID=454, @VersionID=1021, @DebugBM=7

EXEC [spGet_Callisto_BusinessRule] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataClassName nvarchar(100),
	@ModelBM int,
	@DynamicBR_Text nvarchar(max) = '',
	@SQLStatement nvarchar(max),
	@ApplicationID int,
	@ETLDatabase nvarchar(100),
	@LanguageID int,

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
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get BusinessRule details for Callisto',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2154' SET @Description = 'DB-469: Implemented [spGet_Dynamic_BusinessRule] to get Dynamic BusinessRule text.'
		IF @Version = '2.1.1.2173' SET @Description = 'Set @DynamicBR_Text as OUT parameter in [spGet_Dynamic_BusinessRule] subroutine. Handle SalesBudget (@ModelBM = 16) BusinessRule.'
		
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
			@ModelBM = SUM(ModelBM)
		FROM
			(
			SELECT DISTINCT
				ModelBM
			FROM
				DataClass
			WHERE
				InstanceID = @InstanceID AND
				VersionID = @VersionID AND
				StorageTypeBM & 4 > 0 AND
				ModelBM & 1628 > 0 AND
				SelectYN <> 0 AND
				DeletedID IS NULL
			) sub

		--AccountPayable	1024
		--AccountReceivable	512
		--Financials	64
		--SalesBudget	16
		--FxRate	4
		--Sales	8

		IF @DebugBM & 2 > 0 SELECT [@ModelBM] = @ModelBM

	SET @Step = 'Create temp tables'
		IF OBJECT_ID (N'tempdb..#BusinessRule', N'U') IS NULL
			CREATE TABLE [dbo].[#BusinessRule]
				(
				[Action] [int] NULL,
				[Model] [nvarchar](100) NOT NULL,
				[Label] [nvarchar](255) NOT NULL,
				[Description] [nvarchar](255) NULL,
				[Type] [nvarchar](50) NOT NULL,
				[Path] [nvarchar](255) NOT NULL,
				[Text] [nvarchar](max) NOT NULL
				)

		IF OBJECT_ID (N'tempdb..#BusinessRuleRequestFilters', N'U') IS NULL
			CREATE TABLE [dbo].[#BusinessRuleRequestFilters]
				(
				[Action] [int] NULL,
				[Model] [nvarchar](100) NOT NULL,
				[BusinessRule] [nvarchar](255) NOT NULL,
				[Label] [nvarchar](255) NOT NULL,
				[Dimension] [nvarchar](100) NOT NULL
				)

		IF OBJECT_ID (N'tempdb..#BusinessRuleStepRecordParameters', N'U') IS NULL
			CREATE TABLE [dbo].[#BusinessRuleStepRecordParameters]
				(
				[Model] [nvarchar](100) NOT NULL,
				[BusinessRule] [nvarchar](255) NOT NULL,
				[BusinessRuleStep] [nvarchar](255) NOT NULL,
				[BusinessRuleStepRecord] [nvarchar](255) NOT NULL,
				[Parameter] [nvarchar](255) NOT NULL,
				[Value] [nvarchar](max) NULL
				)

		IF OBJECT_ID (N'tempdb..#BusinessRuleStepRecords', N'U') IS NULL
			CREATE TABLE [dbo].[#BusinessRuleStepRecords]
				(
				[Model] [nvarchar](100) NOT NULL,
				[BusinessRule] [nvarchar](255) NOT NULL,
				[BusinessRuleStep] [nvarchar](255) NOT NULL,
				[Label] [nvarchar](255) NOT NULL,
				[SequenceNumber] [int] NOT NULL,
				[Skip] [int] NULL
				)

		IF OBJECT_ID (N'tempdb..#BusinessRuleSteps', N'U') IS NULL
			CREATE TABLE [dbo].[#BusinessRuleSteps]
				(
				[Model] [nvarchar](100) NOT NULL,
				[BusinessRule] [nvarchar](255) NOT NULL,
				[Label] [nvarchar](255) NOT NULL,
				[DefinitionLabel] [nvarchar](255) NOT NULL,
				[SequenceNumber] [int] NOT NULL
				)

	SET @Step = 'Create Business Rules, FxRate'
		IF @ModelBM & 4 > 0 --FxRate
			BEGIN
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'FxRate', N'Dynamic', N'Dynamic', N'Dynamic', N'Dynamic', N'Calculate;')
			END

	SET @Step = 'Create Business Rules, Sales'	
		IF @ModelBM & 8 > 0 --Sales
			BEGIN
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Sales', N'Dynamic', N'Dynamic', N'Dynamic', N'Dynamic', N'Calculate;

//Periodic
SCOPE ([TimeDataView].[TimeDataView].[Periodic], [Measures].[Sales_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
[TimeDataView].[TimeDataView].[RAWDATA]*[Account].[Account].CurrentMember.Properties("Sign",TYPED),
([TimeDataView].[TimeDataView].[RAWDATA],ClosingPeriod([TimeDay].[TimeDay].[Day]))
*[Account].[Account].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([TimeDataView].[TimeDataView].[YTD], [Measures].[Sales_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([TimeDay].[TimeDay].[Year],[TimeDay].[TimeDay].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

// MTD
SCOPE ([TimeDataView].[TimeDataView].[MTD], [Measures].[Sales_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([TimeDay].[TimeDay].[Month],[TimeDay].[TimeDay].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

//POP
SCOPE ([TimeDataView].[TimeDataView].[POP], [Measures].[Sales_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("Sign",TYPED)=1,
([TimeDay].[TimeDay].PrevMember,[TimeDataView].[TimeDataView].[Periodic]) - ([TimeDay].[TimeDay].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]),
([TimeDay].[TimeDay].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]) - ([TimeDay].[TimeDay].PrevMember,[TimeDataView].[TimeDataView].[Periodic]));
END SCOPE;

// R12
SCOPE ([TimeDataView].[TimeDataView].[R12], [Measures].[Sales_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([TimeDay].[TimeDay].[Month],11):PARALLELPERIOD([TimeDay].[TimeDay].[Month],0)}, [TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
 END SCOPE;

 // Measures
CREATE MEMBER CURRENTCUBE.[Measures].[Actual] AS ''([Scenario].[Scenario].[Actual], [Measures].[Sales_Value])''
,ASSOCIATED_MEASURE_GROUP=''MeasureGroup''
,DISPLAY_FOLDER=''Scenario''
,SOLVE_ORDER=1
,FORMAT_STRING = ''# ### ##0'';

CREATE MEMBER CURRENTCUBE.[Measures].[Budget] AS ''([Scenario].[Scenario].[Budget], [Measures].[Sales_Value])''
,ASSOCIATED_MEASURE_GROUP=''MeasureGroup''
,DISPLAY_FOLDER=''Scenario''
,SOLVE_ORDER=1
,FORMAT_STRING = ''# ### ##0'';

')

				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Sales', N'Canvas_FxTrans', N'Canvas_FxTrans', N'SQL', N'Canvas_FxTrans', N'Execute Canvas_FxTrans')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Sales', N'Canvas_FxTrans', N'BusinessProcessMbrs', N'BusinessProcess')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Sales', N'Canvas_FxTrans', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Sales', N'Canvas_FxTrans', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Sales', N'Canvas_FxTrans', N'TimeMbrs', N'Time')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Sales', N'Refresh_Application', N'Refresh_Application', N'SQL', N'Refresh_Application', N'EXECUTE Canvas_Run_ETL ''Application''')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Sales', N'Refresh_Data', N'Refresh_Data', N'SQL', N'Refresh_Data', N'EXECUTE Canvas_Run_ETL ''Data''')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Sales', N'Refresh_Application', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Sales', N'Refresh_Data', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Sales', N'Refresh_Data', N'EntityMbrs', N'Entity')
			END

	SET @Step = 'Create Business Rules, FxRate'
		IF @ModelBM & 16 > 0 --SalesBudget
			BEGIN
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'SalesBudget', N'Dynamic', N'Dynamic', N'Dynamic', N'Dynamic', N'Calculate;

//Periodic
SCOPE ([TimeDataView].[TimeDataView].[Periodic], [Measures].[SalesBudget_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
[TimeDataView].[TimeDataView].[RAWDATA]*[Account].[Account].CurrentMember.Properties("Sign",TYPED),
([TimeDataView].[TimeDataView].[RAWDATA],ClosingPeriod([Time].[Time].[Month]))
*[Account].[Account].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([TimeDataView].[TimeDataView].[YTD], [Measures].[SalesBudget_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([Time].[Time].[Year],[Time].[Time].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

//POP
SCOPE ([TimeDataView].[TimeDataView].[POP], [Measures].[SalesBudget_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("Sign",TYPED)=1,
([Time].[Time].PrevMember,[TimeDataView].[TimeDataView].[Periodic]) - ([Time].[Time].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]),
([Time].[Time].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]) - ([Time].[Time].PrevMember,[TimeDataView].[TimeDataView].[Periodic]));
END SCOPE;

// R12
SCOPE ([TimeDataView].[TimeDataView].[R12], [Measures].[SalesBudget_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([Time].[Time].[Month],11):PARALLELPERIOD([Time].[Time].[Month],0)}, [TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

')
			END

	SET @Step = 'Create Business Rules, Financials'
		IF @ModelBM & 64 > 0 --Financials
			BEGIN
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Canvas_Asumption_Init', N'Canvas_Asumption_Init', N'SQL', N'Canvas_Asumption_Init', N'EXECUTE Canvas_Asumption 1')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'CopyCurrentVersion', N'CopyCurrentVersion', N'SQL', N'CopyCurrentVersion', N'EXECUTE Canvas_Util_WorkFlowCopyCurrentVersion')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Canvas_FxTrans', N'Canvas_FxTrans', N'SQL', N'Canvas_FxTrans', N'Execute Canvas_FxTrans')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'CopyDataForecast', N'CopyDataForecast', N'SQL', N'CopyDataForecast', N'Execute Canvas_Util_CopyDataWorkFlow ''Financials''')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'CAPEX_BR_BS', N'CAPEX_BR_BS', N'SQL', N'CAPEX_BR_BS', N'EXECUTE Canvas_Capex_BR')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'capex_Calculation', N'capex_Calculation', N'Library', N'capex_Calculation', N'')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'CashFlow_Calculation', N'CashFlow_Calculation', N'SQL', N'CashFlow_Calculation', N'EXECUTE Canvas_CashFlow_Calculation')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Automatic', N'Automatic', N'Library', N'Automatic', N'')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Refresh_Application', N'Refresh_Application', N'SQL', N'Refresh_Application', N'EXECUTE Canvas_Run_ETL ''Application''')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Refresh_Data', N'Refresh_Data', N'SQL', N'Refresh_Data', N'EXECUTE Canvas_Run_ETL ''Data''')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Profitability', N'Profitability', N'SQL', N'Profitability', N'EXECUTE Canvas_profitability')

				EXEC [spGet_Dynamic_BusinessRule] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @DynamicBR_Text=@DynamicBR_Text OUT, @ModelBM=64 --Financials
				
				IF LEN(@DynamicBR_Text) = 0 OR @DynamicBR_Text = ''
					SET @DynamicBR_Text = 'Calculate;' + CHAR(13) + CHAR(10)
				
				IF @DebugBM & 2 > 0 SELECT [@DynamicBR_Text] = @DynamicBR_Text

				INSERT INTO [#BusinessRule] 
					(
					[Action], 
					[Model], 
					[Label], 
					[Description], 
					[Type], 
					[Path], 
					[Text]
					) 
				SELECT 
					[Action] = NULL, 
					[Model] = N'Financials', 
					[Label] = N'Dynamic', 
					[Description] = N'Dynamic', 
					[Type] = N'Dynamic', 
					[Path] = N'Dynamic', 
					[Text] = @DynamicBR_Text
				
/*
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Dynamic', N'Dynamic', N'Dynamic', N'Dynamic', N'Calculate;
		
//Periodic
SCOPE ([TimeDataView].[TimeDataView].[Periodic], [Measures].[Financials_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
[TimeDataView].[TimeDataView].[RAWDATA]*[Account].[Account].CurrentMember.Properties("Sign",TYPED),
([TimeDataView].[TimeDataView].[RAWDATA],ClosingPeriod([Time].[Time].[Month]))
*[Account].[Account].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([TimeDataView].[TimeDataView].[YTD], [Measures].[Financials_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([Time].[Time].[Year],[Time].[Time].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

//POP
SCOPE ([TimeDataView].[TimeDataView].[POP], [Measures].[Financials_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("Sign",TYPED)=1,
([Time].[Time].PrevMember,[TimeDataView].[TimeDataView].[Periodic]) - ([Time].[Time].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]),
([Time].[Time].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]) - ([Time].[Time].PrevMember,[TimeDataView].[TimeDataView].[Periodic]));
END SCOPE;

// R12
SCOPE ([TimeDataView].[TimeDataView].[R12], [Measures].[Financials_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([Time].[Time].[Month],11):PARALLELPERIOD([Time].[Time].[Month],0)}, [TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

// Measures
CREATE MEMBER CURRENTCUBE.[Measures].[Actual] AS ''([Scenario].[Scenario].[Actual], [Measures].[Financials_Value])''
,ASSOCIATED_MEASURE_GROUP=''MeasureGroup''
,DISPLAY_FOLDER=''Scenario''
,SOLVE_ORDER=1
,FORMAT_STRING = ''# ### ##0'';

CREATE MEMBER CURRENTCUBE.[Measures].[Budget] AS ''([Scenario].[Scenario].[Budget], [Measures].[Financials_Value])''
,ASSOCIATED_MEASURE_GROUP=''MeasureGroup''
,DISPLAY_FOLDER=''Scenario''
,SOLVE_ORDER=1
,FORMAT_STRING = ''# ### ##0'';

')
*/
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Canvas_Asumption_Auto', N'Canvas_Asumption_Auto', N'SQL', N'Canvas_Asumption_Auto', N'EXECUTE Canvas_Asumption 2')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Asumption_Init', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Asumption_Init', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Asumption_Init', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CopyCurrentVersion', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CopyCurrentVersion', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CopyCurrentVersion', N'Driver1', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_FxTrans', N'BusinessProcessMbrs', N'BusinessProcess')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_FxTrans', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_FxTrans', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_FxTrans', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CopyDataForecast', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CAPEX_BR_BS', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CAPEX_BR_BS', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CAPEX_BR_BS', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'capex_Calculation', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'capex_Calculation', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CashFlow_Calculation', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CashFlow_Calculation', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'CashFlow_Calculation', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Automatic', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Automatic', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Automatic', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Refresh_Application', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Refresh_Data', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Refresh_Data', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Profitability', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Profitability', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Asumption_Auto', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Asumption_Auto', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Asumption_Auto', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', N'Label', N'Record 1')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', N'RuleModel', N'Financials_Detail')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', N'Rule', N'Capex_Calculation')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', N'RequestFilter1', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', N'RequestFilterMbrs1', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', N'RequestFilter2', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', N'RequestFilterMbrs2', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', N'RequestFilter3', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', N'RequestFilterMbrs3', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'Label', N'Multiply Unit By Price')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'DstTuple', N'[Account].[Account].[ProductSales]')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'DstClear', N'Yes')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'SrcModel', N'Financials')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'SrcTuple', N'[Account].[Account].[SalesUnits]')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'PropertyFilter', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'ValueFilterModel', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'ValueFilterTuple', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'ValueFilter', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'Src2Model', N'Financials')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'Src2Tuple', N'[Account].[Account].[UnitPrice],[Entity].[MgmtOrg].[NONE],[Cost_Center].[Cost_Center].[None]')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'TimeHierarchy', N'[Time].[Time]')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'ToDateOption', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'Factor', N'1')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'TimeOffset', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'OffsetLevel', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'Precision', N'2')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', N'FilterMbrs', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'Label', N'Copy Sales')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'DstTuple', N'[Account].[Account].[4000],[Product].[Product].[NONE]')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'DstClear', N'Yes')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'SrcModel', N'Financials')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'SrcTuple', N'[Account].[Account].[ProductSales]')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'PropertyFilter', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'ValueFilterModel', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'ValueFilterTuple', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'ValueFilter', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'TimeHierarchy', N'[Time].[Time]')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'ToDateOption', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'Factor', N'1')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'TimeOffset', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'OffsetLevel', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'Precision', N'2')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', N'FilterMbrs', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', N'Label', N'Assumptions')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', N'RuleModel', N'Financials')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', N'Rule', N'Canvas_Asumption_Auto')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', N'RequestFilter1', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', N'RequestFilterMbrs1', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', N'RequestFilter2', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', N'RequestFilterMbrs2', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', N'RequestFilter3', N'')
				INSERT [#BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', N'RequestFilterMbrs3', N'')
				INSERT [#BusinessRuleStepRecords] ([Model], [BusinessRule], [BusinessRuleStep], [Label], [SequenceNumber], [Skip]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'Record 1', 1, 0)
				INSERT [#BusinessRuleStepRecords] ([Model], [BusinessRule], [BusinessRuleStep], [Label], [SequenceNumber], [Skip]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply Unit By Price', 1, 0)
				INSERT [#BusinessRuleStepRecords] ([Model], [BusinessRule], [BusinessRuleStep], [Label], [SequenceNumber], [Skip]) VALUES (N'Financials', N'Automatic', N'Step 2', N'Copy Sales', 1, 0)
				INSERT [#BusinessRuleStepRecords] ([Model], [BusinessRule], [BusinessRuleStep], [Label], [SequenceNumber], [Skip]) VALUES (N'Financials', N'Automatic', N'Step 3', N'Assumptions', 1, 0)
				INSERT [#BusinessRuleSteps] ([Model], [BusinessRule], [Label], [DefinitionLabel], [SequenceNumber]) VALUES (N'Financials', N'capex_Calculation', N'Step 1', N'IncludeRule', 1)
				INSERT [#BusinessRuleSteps] ([Model], [BusinessRule], [Label], [DefinitionLabel], [SequenceNumber]) VALUES (N'Financials', N'Automatic', N'Step 1', N'Multiply', 1)
				INSERT [#BusinessRuleSteps] ([Model], [BusinessRule], [Label], [DefinitionLabel], [SequenceNumber]) VALUES (N'Financials', N'Automatic', N'Step 2', N'CopyTupleToTuple', 2)
				INSERT [#BusinessRuleSteps] ([Model], [BusinessRule], [Label], [DefinitionLabel], [SequenceNumber]) VALUES (N'Financials', N'Automatic', N'Step 3', N'IncludeRule', 3)
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Canvas_Eliminations', N'Canvas_Eliminations', N'SQL', N'Canvas_Eliminations', N'Exec Canvas_ICEliminations '''',''ScenarioMbrs'',''TimeMbrs''')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'Financials', N'Canvas_Elimination_Other', N'Canvas_Elimination_Other', N'SQL', N'Canvas_Elimination_Other', N'Exec Canvas_ICEliminationsOther '''',''ScenarioMbrs'',''TimeMbrs''')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Eliminations', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Eliminations', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Elimination_Other', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Elimination_Other', N'TimeMbrs', N'Time')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'Financials', N'Canvas_Elimination_Other', N'RoundMbrs', N'Round')
			END

	SET @Step = 'Create Business Rules, AccountReceivable'
		IF @ModelBM & 512 > 0  --AccountReceivable
			BEGIN
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountReceivable', N'calculate_Aging', N'calculate_Aging', N'SQL', N'calculate_Aging', N'EXECUTE Canvas_AR_AP_Calculate_Aging ''AR''')

				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountReceivable', N'Dynamic', N'Dynamic', N'Dynamic', N'Dynamic', N'Calculate;

//Periodic
SCOPE ([TimeDataView].[TimeDataView].[Periodic], [Measures].[AccountReceivable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
[TimeDataView].[TimeDataView].[RAWDATA]*[Account].[Account].CurrentMember.Properties("Sign",TYPED),
([TimeDataView].[TimeDataView].[RAWDATA],ClosingPeriod([TimeDay].[TimeDay].[Day]))
*[Account].[Account].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([TimeDataView].[TimeDataView].[YTD], [Measures].[AccountReceivable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([TimeDay].[TimeDay].[Year],[TimeDay].[TimeDay].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

// MTD
SCOPE ([TimeDataView].[TimeDataView].[MTD], [Measures].[AccountReceivable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([TimeDay].[TimeDay].[Month],[TimeDay].[TimeDay].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

//POP
SCOPE ([TimeDataView].[TimeDataView].[POP], [Measures].[AccountReceivable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("Sign",TYPED)=1,
([TimeDay].[TimeDay].PrevMember,[TimeDataView].[TimeDataView].[Periodic]) - ([TimeDay].[TimeDay].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]),
([TimeDay].[TimeDay].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]) - ([TimeDay].[TimeDay].PrevMember,[TimeDataView].[TimeDataView].[Periodic]));
END SCOPE;

// R12
SCOPE ([TimeDataView].[TimeDataView].[R12], [Measures].[AccountReceivable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([TimeDay].[TimeDay].[Month],11):PARALLELPERIOD([TimeDay].[TimeDay].[Month],0)}, [TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountReceivable', N'Init_receivable', N'Init_receivable', N'SQL', N'Init_receivable', N'EXECUTE Canvas_AR_AP_Runall ''AR''')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountReceivable', N'Estimated_Payment_Calculation', N'Estimated_Payment_Calculation', N'SQL', N'Estimated_Payment_Calculation', N'EXECUTE Canvas_AR_AP_Update_Forecast ''AR''')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountReceivable', N'Deploy_Reforecast_Payment', N'Deploy_Reforecast_Payment', N'SQL', N'Deploy_Reforecast_Payment', N'EXECUTE canvas_AR_AP_Deploy_Payment')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountReceivable', N'Copy_Opening', N'Copy_Opening', N'SQL', N'Copy_Opening', N'EXECUTE Canvas_AR_AP_Copy_Opening')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'calculate_Aging', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'calculate_Aging', N'TimeMbrs', N'TimeDay')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'calculate_Aging', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Init_receivable', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Init_receivable', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Estimated_Payment_Calculation', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Estimated_Payment_Calculation', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Deploy_Reforecast_Payment', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Deploy_Reforecast_Payment', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Copy_Opening', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Copy_Opening', N'TimeMbrs', N'TimeDay')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Copy_Opening', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountReceivable', N'Canvas_FxTrans', N'Canvas_FxTrans', N'SQL', N'Canvas_FxTrans', N'Execute Canvas_FxTrans')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Canvas_FxTrans', N'BusinessProcessMbrs', N'BusinessProcess')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Canvas_FxTrans', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Canvas_FxTrans', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountReceivable', N'Canvas_FxTrans', N'TimeDayMbrs', N'Time')
			END

	SET @Step = 'Create Business Rules, AccountPayable'
		IF @ModelBM & 1024 > 0 --AccountPayable
			BEGIN
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountPayable', N'Init_Payable', N'Init_Payable', N'SQL', N'Init_Payable', N'EXECUTE Canvas_AR_AP_RunAll ''AP''')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountPayable', N'Dynamic', N'Dynamic', N'Dynamic', N'Dynamic', N'Calculate;

//Periodic
SCOPE ([TimeDataView].[TimeDataView].[Periodic], [Measures].[AccountPayable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
[TimeDataView].[TimeDataView].[RAWDATA]*[Account].[Account].CurrentMember.Properties("Sign",TYPED),
([TimeDataView].[TimeDataView].[RAWDATA],ClosingPeriod([TimeDay].[TimeDay].[Day]))
*[Account].[Account].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([TimeDataView].[TimeDataView].[YTD], [Measures].[AccountPayable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([TimeDay].[TimeDay].[Year],[TimeDay].[TimeDay].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

// MTD
SCOPE ([TimeDataView].[TimeDataView].[MTD], [Measures].[AccountPayable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([TimeDay].[TimeDay].[Month],[TimeDay].[TimeDay].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

//POP
SCOPE ([TimeDataView].[TimeDataView].[POP], [Measures].[AccountPayable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("Sign",TYPED)=1,
([TimeDay].[TimeDay].PrevMember,[TimeDataView].[TimeDataView].[Periodic]) - ([TimeDay].[TimeDay].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]),
([TimeDay].[TimeDay].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]) - ([TimeDay].[TimeDay].PrevMember,[TimeDataView].[TimeDataView].[Periodic]));
END SCOPE;

// R12
SCOPE ([TimeDataView].[TimeDataView].[R12], [Measures].[AccountPayable_Value]);
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([TimeDay].[TimeDay].[Month],11):PARALLELPERIOD([TimeDay].[TimeDay].[Month],0)}, [TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
END SCOPE;

// YTD Paid
//SCOPE ([Account].[Account].[Payables_Paid_Estimation]);
//THIS = ([Account].[Account].[PayablesPaid_]);
//END SCOPE;
')

				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountPayable', N'calculate_Aging', N'calculate_Aging', N'SQL', N'calculate_Aging', N'EXECUTE Canvas_AR_AP_Calculate_Aging ''AP''')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountPayable', N'Copy_Opening', N'Copy_Opening', N'SQL', N'Copy_Opening', N'EXECUTE Canvas_AR_AP_Copy_Opening')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountPayable', N'Deploy_Reforecast_Payment', N'Deploy_Reforecast_Payment', N'SQL', N'Deploy_Reforecast_Payment', N'EXECUTE canvas_AR_AP_Deploy_Payment')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountPayable', N'Estimated_Payment_Calculation', N'Estimated_Payment_Calculation', N'SQL', N'Estimated_Payment_Calculation', N'EXECUTE Canvas_AR_AP_Update_Forecast ''AP''')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Init_Payable', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Init_Payable', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'calculate_Aging', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'calculate_Aging', N'TimeMbrs', N'TimeDay')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'calculate_Aging', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Copy_Opening', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Copy_Opening', N'TimeMbrs', N'TimeDay')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Copy_Opening', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Deploy_Reforecast_Payment', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Deploy_Reforecast_Payment', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Estimated_Payment_Calculation', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Estimated_Payment_Calculation', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N'AccountPayable', N'Canvas_FxTrans', N'Canvas_FxTrans', N'SQL', N'Canvas_FxTrans', N'Execute Canvas_FxTrans')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Canvas_FxTrans', N'BusinessProcessMbrs', N'BusinessProcess')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Canvas_FxTrans', N'EntityMbrs', N'Entity')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Canvas_FxTrans', N'ScenarioMbrs', N'Scenario')
				INSERT [#BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N'AccountPayable', N'Canvas_FxTrans', N'TimeDayMbrs', N'Time')
			END

	SET @Step = 'Calculate Selection'
		SELECT @Selected = @Selected + COUNT(1) FROM [#BusinessRule]
		SELECT @Selected = @Selected + COUNT(1) FROM [#BusinessRuleRequestFilters]
		SELECT @Selected = @Selected + COUNT(1) FROM [#BusinessRuleStepRecordParameters]
		SELECT @Selected = @Selected + COUNT(1) FROM [#BusinessRuleStepRecords]
		SELECT @Selected = @Selected + COUNT(1) FROM [#BusinessRuleSteps]

	SET @Step = 'Return rows, Debug'
		IF @DebugBM & 2 > 0
			BEGIN
				SELECT [TempTable] = '#BusinessRule', * FROM [#BusinessRule] ORDER BY [Model], [Label]
				SELECT [TempTable] = '#BusinessRuleRequestFilters', * FROM [#BusinessRuleRequestFilters] ORDER BY [Model], [BusinessRule], [Label], [Dimension]
				SELECT [TempTable] = '#BusinessRuleStepRecordParameters', * FROM [#BusinessRuleStepRecordParameters] ORDER BY [Model], [BusinessRule], [BusinessRuleStep]
				SELECT [TempTable] = '#BusinessRuleStepRecords', * FROM [#BusinessRuleStepRecords] ORDER BY [Model], [BusinessRule], [BusinessRuleStep], [Label]
				SELECT [TempTable] = '#BusinessRuleSteps', * FROM [#BusinessRuleSteps] ORDER BY [Model], [BusinessRule], [Label]
			END

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
