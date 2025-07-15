SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Application_BusinessRules]

	@JobID int = 0,
	@ApplicationID int = NULL,
	@ETLDatabase nvarchar(50) = NULL,
	@BaseModelID int = NULL, -- -3=FxRate, -4=Sales, -7=Financials, -8=Financials_Detail, -10=AccountReceivable, -11=AccountPayable, -14=Voucher
	@LanguageID int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_Application_BusinessRules] @ApplicationID = 400, @ETLDatabase = 'pcETL_DevTest64', @BaseModelID = -3, @LanguageID = 1, @Debug = true
--EXEC [spCreate_Application_BusinessRules] @ApplicationID = 400, @ETLDatabase = 'pcETL_DevTest64', @BaseModelID = -4, @LanguageID = 1, @Debug = true
--EXEC [spCreate_Application_BusinessRules] @ApplicationID = 400, @ETLDatabase = 'pcETL_DevTest64', @BaseModelID = -7, @LanguageID = 1, @Debug = true
--EXEC [spCreate_Application_BusinessRules] @ApplicationID = 400, @ETLDatabase = 'pcETL_DevTest64', @BaseModelID = -8, @LanguageID = 1, @Debug = true
--EXEC [spCreate_Application_BusinessRules] @ApplicationID = 400, @ETLDatabase = 'pcETL_DevTest64', @BaseModelID = -10, @LanguageID = 1, @Debug = true
--EXEC [spCreate_Application_BusinessRules] @ApplicationID = 400, @ETLDatabase = 'pcETL_DevTest64', @BaseModelID = -11, @LanguageID = 1, @Debug = true
--EXEC [spCreate_Application_BusinessRules] @ApplicationID = 400, @ETLDatabase = 'pcETL_DevTest64', @BaseModelID = -14, @LanguageID = 1, @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@InstanceID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2136'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2053' SET @Description = 'BR for AR/AP changed.'
		IF @Version = '1.2.2056' SET @Description = 'BR for Financials/AR/AP changed.'
		IF @Version = '1.2.2057' SET @Description = 'BR for AR/AP changed.'
		IF @Version = '1.2.2058' SET @Description = 'BR for Financials/AR/AP changed.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.2073' SET @Description = 'Profitability added.'
		IF @Version = '1.3.2101' SET @Description = 'Sales added. Dynamic BRs modified.'
		IF @Version = '1.3.2106' SET @Description = 'Voucher added. MTD added.'
		IF @Version = '1.3.2112' SET @Description = 'New version of Canvas_FxTrans added. Object renaming handled.'
		IF @Version = '1.3.0.2118' SET @Description = 'Refresh_Application and Refresh_Data added.'
		IF @Version = '1.3.1.2121' SET @Description = 'Comments removed from BR.'
		IF @Version = '1.3.1.2124' SET @Description = 'Count Inserted rows.'
		IF @Version = '1.4.0.2129' SET @Description = 'Dynamic rule R12 updated. New version of Canvas_FxTrans removed.'
		IF @Version = '1.4.0.2130' SET @Description = 'Dynamic measures added for Financials and Sales.'
		IF @Version = '1.4.0.2134' SET @Description = 'Parameters are removed for FxTrans.'
		IF @Version = '1.4.0.2136' SET @Description = 'Parameters added for FxTrans.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL OR @ETLDatabase IS NULL OR @BaseModelID IS NULL OR @LanguageID IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID, @ETLDatabase, @BaseModelID and @LanguageID must be set.'
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

		SELECT
			@InstanceID = A.InstanceID
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID AND
			A.SelectYN <> 0

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Create Business Rules'
		IF @BaseModelID = -3 --FxRate
			BEGIN
				SET @Step = 'Create Business Rules, FxRate'
				SET @SQLStatement = '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£FxRate£€'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Calculate;'')
'
				EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'BusinessProcesses for FxRate', [SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

		ELSE IF @BaseModelID = -4 --Sales
			BEGIN
				SET @Step = 'Create Business Rules, Sales'
				SET @SQLStatement = '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Sales£€'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Calculate;

//Periodic
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[Periodic], [Measures].[€£Sales£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
[€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA]*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED),
([€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA],ClosingPeriod([€£TimeDay£€].[€£TimeDay£€].[Day]))
*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[YTD], [Measures].[€£Sales£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£TimeDay£€].[€£TimeDay£€].[Year],[€£TimeDay£€].[€£TimeDay£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

// MTD
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[MTD], [Measures].[€£Sales£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£TimeDay£€].[€£TimeDay£€].[Month],[€£TimeDay£€].[€£TimeDay£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

//POP
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[POP], [Measures].[€£Sales£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED)=1,
([€£TimeDay£€].[€£TimeDay£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£TimeDay£€].[€£TimeDay£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
([€£TimeDay£€].[€£TimeDay£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£TimeDay£€].[€£TimeDay£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]));
END SCOPE;

// R12
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[R12], [Measures].[€£Sales£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([€£TimeDay£€].[€£TimeDay£€].[Month],11):PARALLELPERIOD([€£TimeDay£€].[€£TimeDay£€].[Month],0)}, [€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
 END SCOPE;

 // Measures
CREATE MEMBER CURRENTCUBE.[Measures].[Actual] AS ''''([€£Scenario£€].[€£Scenario£€].[Actual], [Measures].[€£Sales£€_Value])''''
,ASSOCIATED_MEASURE_GROUP=''''MeasureGroup''''
,DISPLAY_FOLDER=''''€£Scenario£€''''
,SOLVE_ORDER=1
,FORMAT_STRING = ''''# ### ##0'''';

CREATE MEMBER CURRENTCUBE.[Measures].[Budget] AS ''''([€£Scenario£€].[€£Scenario£€].[Budget], [Measures].[€£Sales£€_Value])''''
,ASSOCIATED_MEASURE_GROUP=''''MeasureGroup''''
,DISPLAY_FOLDER=''''€£Scenario£€''''
,SOLVE_ORDER=1
,FORMAT_STRING = ''''# ### ##0'''';

'')'
SET @SQLStatement = @SQLStatement + '

INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Sales£€'', N''Canvas_FxTrans'', N''Canvas_FxTrans'', N''SQL'', N''Canvas_FxTrans'', N''Execute Canvas_FxTrans'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Sales£€'', N''Canvas_FxTrans'', N''€£BusinessProcess£€Mbrs'', N''€£BusinessProcess£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Sales£€'', N''Canvas_FxTrans'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Sales£€'', N''Canvas_FxTrans'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Sales£€'', N''Canvas_FxTrans'', N''€£Time£€Mbrs'', N''€£Time£€'')
'
/*
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Sales£€'', N''Canvas_FxTrans'', N''€£Simulation£€Mbrs'', N''€£Simulation£€'')
*/

SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Sales£€'', N''Refresh_Application'', N''Refresh_Application'', N''SQL'', N''Refresh_Application'', N''EXECUTE Canvas_Run_ETL ''''Application'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Sales£€'', N''Refresh_Data'', N''Refresh_Data'', N''SQL'', N''Refresh_Data'', N''EXECUTE Canvas_Run_ETL ''''Data'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Sales£€'', N''Refresh_Application'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Sales£€'', N''Refresh_Data'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Sales£€'', N''Refresh_Data'', N''€£Entity£€Mbrs'', N''€£Entity£€'')'

				EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'BusinessProcesses for Sales', [SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

		ELSE IF @BaseModelID = -7 --Financials
			BEGIN
				SET @Step = 'Create Business Rules, Financials'
				SET @SQLStatement = '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Asumption_Init'', N''Canvas_Asumption_Init'', N''SQL'', N''Canvas_Asumption_Init'', N''EXECUTE Canvas_Asumption 1'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''CopyCurrentVersion'', N''CopyCurrentVersion'', N''SQL'', N''CopyCurrentVersion'', N''EXECUTE Canvas_Util_WorkFlowCopyCurrentVersion'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Canvas_FxTrans'', N''Canvas_FxTrans'', N''SQL'', N''Canvas_FxTrans'', N''Execute Canvas_FxTrans'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''CopyDataForecast'', N''CopyDataForecast'', N''SQL'', N''CopyDataForecast'', N''Execute Canvas_Util_CopyDataWorkFlow ''''€£Financials£€'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''CAPEX_BR_BS'', N''CAPEX_BR_BS'', N''SQL'', N''CAPEX_BR_BS'', N''EXECUTE Canvas_Capex_BR'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''capex_Calculation'', N''capex_Calculation'', N''Library'', N''capex_Calculation'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''CashFlow_Calculation'', N''CashFlow_Calculation'', N''SQL'', N''CashFlow_Calculation'', N''EXECUTE Canvas_CashFlow_Calculation'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Automatic'', N''Automatic'', N''Library'', N''Automatic'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Application'', N''Refresh_Application'', N''SQL'', N''Refresh_Application'', N''EXECUTE Canvas_Run_ETL ''''Application'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Data'', N''Refresh_Data'', N''SQL'', N''Refresh_Data'', N''EXECUTE Canvas_Run_ETL ''''Data'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Profitability'', N''Profitability'', N''SQL'', N''Profitability'', N''EXECUTE Canvas_profitability'')'

SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Calculate;

//Periodic
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[Periodic], [Measures].[€£Financials£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
[€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA]*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED),
([€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA],ClosingPeriod([€£Time£€].[€£Time£€].[Month]))
*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[Periodic], [Measures].[€£Financials_Detail£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
[€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA]*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED),
([€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA],ClosingPeriod([€£Time£€].[€£Time£€].[Month]))
*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[YTD], [Measures].[€£Financials£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£Time£€].[€£Time£€].[Year],[€£Time£€].[€£Time£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[YTD], [Measures].[€£Financials_Detail£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£Time£€].[€£Time£€].[Year],[€£Time£€].[€£Time£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

//POP
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[POP], [Measures].[€£Financials£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED)=1,
([€£Time£€].[€£Time£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£Time£€].[€£Time£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
([€£Time£€].[€£Time£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£Time£€].[€£Time£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]));
END SCOPE;

SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[POP], [Measures].[€£Financials_Detail£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED)=1,
([€£Time£€].[€£Time£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£Time£€].[€£Time£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
([€£Time£€].[€£Time£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£Time£€].[€£Time£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]));
END SCOPE;

// R12
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[R12], [Measures].[€£Financials£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([€£Time£€].[€£Time£€].[Month],11):PARALLELPERIOD([€£Time£€].[€£Time£€].[Month],0)}, [€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[R12], [Measures].[€£Financials_Detail£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([€£Time£€].[€£Time£€].[Month],11):PARALLELPERIOD([€£Time£€].[€£Time£€].[Month],0)}, [€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;'

SET @SQLStatement = @SQLStatement + '

// Measures
CREATE MEMBER CURRENTCUBE.[Measures].[Actual] AS ''''([€£Scenario£€].[€£Scenario£€].[Actual], [Measures].[€£Financials£€_Value])''''
,ASSOCIATED_MEASURE_GROUP=''''MeasureGroup''''
,DISPLAY_FOLDER=''''€£Scenario£€''''
,SOLVE_ORDER=1
,FORMAT_STRING = ''''# ### ##0'''';

CREATE MEMBER CURRENTCUBE.[Measures].[Budget] AS ''''([€£Scenario£€].[€£Scenario£€].[Budget], [Measures].[€£Financials£€_Value])''''
,ASSOCIATED_MEASURE_GROUP=''''MeasureGroup''''
,DISPLAY_FOLDER=''''€£Scenario£€''''
,SOLVE_ORDER=1
,FORMAT_STRING = ''''# ### ##0'''';

'')'

SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Asumption_Auto'', N''Canvas_Asumption_Auto'', N''SQL'', N''Canvas_Asumption_Auto'', N''EXECUTE Canvas_Asumption 2'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Asumption_Init'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Asumption_Init'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Asumption_Init'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CopyCurrentVersion'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CopyCurrentVersion'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CopyCurrentVersion'', N''Driver1'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_FxTrans'', N''€£BusinessProcess£€Mbrs'', N''€£BusinessProcess£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_FxTrans'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_FxTrans'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_FxTrans'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CopyDataForecast'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CAPEX_BR_BS'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CAPEX_BR_BS'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CAPEX_BR_BS'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''capex_Calculation'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
'
SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''capex_Calculation'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CashFlow_Calculation'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CashFlow_Calculation'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''CashFlow_Calculation'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Automatic'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Automatic'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Automatic'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Application'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Data'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Data'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Profitability'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Profitability'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Asumption_Auto'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Asumption_Auto'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Asumption_Auto'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
'
SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', N''Label'', N''Record 1'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', N''RuleModel'', N''€£Financials_Detail£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', N''Rule'', N''Capex_Calculation'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', N''RequestFilter1'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', N''RequestFilterMbrs1'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', N''RequestFilter2'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', N''RequestFilterMbrs2'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', N''RequestFilter3'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', N''RequestFilterMbrs3'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''Label'', N''Multiply Unit By Price'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''DstTuple'', N''[€£Account£€].[€£Account£€].[Product€£Sales£€]'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''DstClear'', N''Yes'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''SrcModel'', N''€£Financials£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''SrcTuple'', N''[€£Account£€].[€£Account£€].[€£Sales£€Units]'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''PropertyFilter'', N'''')
'
SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''ValueFilterModel'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''ValueFilterTuple'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''ValueFilter'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''Src2Model'', N''€£Financials£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''Src2Tuple'', N''[€£Account£€].[€£Account£€].[UnitPrice],[€£Entity£€].[MgmtOrg].[NONE],[Cost_Center].[Cost_Center].[None]'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''TimeHierarchy'', N''[€£Time£€].[€£Time£€]'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''ToDateOption'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''Factor'', N''1'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''TimeOffset'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''OffsetLevel'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''Precision'', N''2'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', N''FilterMbrs'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''Label'', N''Copy €£Sales£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''DstTuple'', N''[€£Account£€].[€£Account£€].[4000],[Product].[Product].[NONE]'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''DstClear'', N''Yes'')
'
SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''SrcModel'', N''€£Financials£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''SrcTuple'', N''[€£Account£€].[€£Account£€].[Product€£Sales£€]'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''PropertyFilter'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''ValueFilterModel'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''ValueFilterTuple'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''ValueFilter'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''TimeHierarchy'', N''[€£Time£€].[€£Time£€]'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''ToDateOption'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''Factor'', N''1'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''TimeOffset'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''OffsetLevel'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''Precision'', N''2'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', N''FilterMbrs'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', N''Label'', N''Assumptions'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', N''RuleModel'', N''€£Financials£€'')
'
SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', N''Rule'', N''Canvas_Asumption_Auto'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', N''RequestFilter1'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', N''RequestFilterMbrs1'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', N''RequestFilter2'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', N''RequestFilterMbrs2'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', N''RequestFilter3'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters] ([Model], [BusinessRule], [BusinessRuleStep], [BusinessRuleStepRecord], [Parameter], [Value]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', N''RequestFilterMbrs3'', N'''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecords] ([Model], [BusinessRule], [BusinessRuleStep], [Label], [SequenceNumber], [Skip]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''Record 1'', 1, 0)
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecords] ([Model], [BusinessRule], [BusinessRuleStep], [Label], [SequenceNumber], [Skip]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply Unit By Price'', 1, 0)
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecords] ([Model], [BusinessRule], [BusinessRuleStep], [Label], [SequenceNumber], [Skip]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''Copy €£Sales£€'', 1, 0)
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecords] ([Model], [BusinessRule], [BusinessRuleStep], [Label], [SequenceNumber], [Skip]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''Assumptions'', 1, 0)
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleSteps] ([Model], [BusinessRule], [Label], [DefinitionLabel], [SequenceNumber]) VALUES (N''€£Financials£€'', N''capex_Calculation'', N''Step 1'', N''IncludeRule'', 1)
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleSteps] ([Model], [BusinessRule], [Label], [DefinitionLabel], [SequenceNumber]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 1'', N''Multiply'', 1)
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleSteps] ([Model], [BusinessRule], [Label], [DefinitionLabel], [SequenceNumber]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 2'', N''CopyTupleToTuple'', 2)
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleSteps] ([Model], [BusinessRule], [Label], [DefinitionLabel], [SequenceNumber]) VALUES (N''€£Financials£€'', N''Automatic'', N''Step 3'', N''IncludeRule'', 3)
'
SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Eliminations'', N''Canvas_Eliminations'', N''SQL'', N''Canvas_Eliminations'', N''Exec Canvas_ICEliminations '''''''',''''ScenarioMbrs'''',''''TimeMbrs'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Elimination_Other'', N''Canvas_Elimination_Other'', N''SQL'', N''Canvas_Elimination_Other'', N''Exec Canvas_ICEliminationsOther '''''''',''''ScenarioMbrs'''',''''TimeMbrs'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Eliminations'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Eliminations'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Elimination_Other'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Elimination_Other'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_Elimination_Other'', N''€£Round£€Mbrs'', N''€£Round£€'')
'

/*
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Canvas_FxTrans'', N''€£Simulation£€Mbrs'', N''€£Simulation£€'')
*/
/*
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Application'', N''Refresh_Application'', N''SQL'', N''Refresh_Application'', N''EXECUTE Canvas_Run_ETL ''''Application'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Data'', N''Refresh_Data'', N''SQL'', N''Refresh_Data'', N''EXECUTE Canvas_Run_ETL ''''Data'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Application'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Data'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials£€'', N''Refresh_Data'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
*/

				EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'BusinessProcesses for Financials', [SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

		ELSE IF @BaseModelID = -8 --Financials_Detail
			BEGIN
				SET @Step = 'Create Business Rules, Financials_Detail'
				SET @SQLStatement = '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials_Detail£€'', N''Capex_Calculation'', N''Capex_Calculation'', N''SQL'', N''Capex_Calculation'', N''EXECUTE [Canvas_Capex_Calculation2] '')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials_Detail£€'', N''Capex_Calculation'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Financials_Detail£€'', N''Capex_Calculation'', N''€£Entity£€mbrs'', N''€£Entity£€'')
'
SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Financials_Detail£€'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Calculate;

//Periodic
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[Periodic], [Measures].[€£Financials_Detail£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
[€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA]*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED),
([€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA],ClosingPeriod([€£Time£€].[€£Time£€].[Month]))
*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[YTD], [Measures].[€£Financials_Detail£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£Time£€].[€£Time£€].[Year],[€£Time£€].[€£Time£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

//POP
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[POP], [Measures].[€£Financials_Detail£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED)=1,
([€£Time£€].[€£Time£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£Time£€].[€£Time£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
([€£Time£€].[€£Time£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£Time£€].[€£Time£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]));
END SCOPE;

// R12
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[R12], [Measures].[€£Financials_Detail£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([€£Time£€].[€£Time£€].[Month],11):PARALLELPERIOD([€£Time£€].[€£Time£€].[Month],0)}, [€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

'')'

				EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'BusinessProcesses for Financials_Detail', [SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

		ELSE IF @BaseModelID = -10 --AccountReceivable
			BEGIN
				SET @Step = 'Create Business Rules, AccountReceivable'
				SET @SQLStatement = '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountReceivable£€'', N''calculate_Aging'', N''calculate_Aging'', N''SQL'', N''calculate_Aging'', N''EXECUTE Canvas_AR_AP_Calculate_Aging ''''AR''''
'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountReceivable£€'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Calculate;

//Periodic
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[Periodic], [Measures].[€£AccountReceivable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
[€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA]*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED),
([€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA],ClosingPeriod([€£TimeDay£€].[€£TimeDay£€].[Day]))
*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[YTD], [Measures].[€£AccountReceivable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£TimeDay£€].[€£TimeDay£€].[Year],[€£TimeDay£€].[€£TimeDay£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

// MTD
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[MTD], [Measures].[€£AccountReceivable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£TimeDay£€].[€£TimeDay£€].[Month],[€£TimeDay£€].[€£TimeDay£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

//POP
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[POP], [Measures].[€£AccountReceivable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED)=1,
([€£TimeDay£€].[€£TimeDay£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£TimeDay£€].[€£TimeDay£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
([€£TimeDay£€].[€£TimeDay£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£TimeDay£€].[€£TimeDay£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]));
END SCOPE;

// R12
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[R12], [Measures].[€£AccountReceivable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([€£TimeDay£€].[€£TimeDay£€].[Month],11):PARALLELPERIOD([€£TimeDay£€].[€£TimeDay£€].[Month],0)}, [€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountReceivable£€'', N''Init_receivable'', N''Init_receivable'', N''SQL'', N''Init_receivable'', N''EXECUTE Canvas_AR_AP_Runall ''''AR'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountReceivable£€'', N''Estimated_Payment_Calculation'', N''Estimated_Payment_Calculation'', N''SQL'', N''Estimated_Payment_Calculation'', N''EXECUTE Canvas_AR_AP_Update_Forecast ''''AR'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountReceivable£€'', N''Deploy_Reforecast_Payment'', N''Deploy_Reforecast_Payment'', N''SQL'', N''Deploy_Reforecast_Payment'', N''EXECUTE canvas_AR_AP_Deploy_Payment'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountReceivable£€'', N''Copy_Opening'', N''Copy_Opening'', N''SQL'', N''Copy_Opening'', N''EXECUTE Canvas_AR_AP_Copy_Opening'')
'
SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''calculate_Aging'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''calculate_Aging'', N''€£Time£€Mbrs'', N''€£TimeDay£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''calculate_Aging'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Init_receivable'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Init_receivable'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Estimated_Payment_Calculation'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Estimated_Payment_Calculation'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Deploy_Reforecast_Payment'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Deploy_Reforecast_Payment'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Copy_Opening'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Copy_Opening'', N''€£Time£€Mbrs'', N''€£TimeDay£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Copy_Opening'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
'

SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountReceivable£€'', N''Canvas_FxTrans'', N''Canvas_FxTrans'', N''SQL'', N''Canvas_FxTrans'', N''Execute Canvas_FxTrans'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Canvas_FxTrans'', N''€£BusinessProcess£€Mbrs'', N''€£BusinessProcess£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Canvas_FxTrans'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Canvas_FxTrans'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Canvas_FxTrans'', N''€£TimeDay£€Mbrs'', N''€£Time£€'')
'
/*
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountReceivable£€'', N''Canvas_FxTrans'', N''€£Simulation£€Mbrs'', N''€£Simulation£€'')
*/

				EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'BusinessProcesses for AccountReceivable', [SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

		ELSE IF @BaseModelID = -11 --AccountPayable
			BEGIN
				SET @Step = 'Create Business Rules, AccountPayable'
				SET @SQLStatement = '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountPayable£€'', N''Init_Payable'', N''Init_Payable'', N''SQL'', N''Init_Payable'', N''EXECUTE Canvas_AR_AP_RunAll ''''AP'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountPayable£€'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Calculate;

//Periodic
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[Periodic], [Measures].[€£AccountPayable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
[€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA]*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED),
([€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA],ClosingPeriod([€£TimeDay£€].[€£TimeDay£€].[Day]))
*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[YTD], [Measures].[€£AccountPayable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£TimeDay£€].[€£TimeDay£€].[Year],[€£TimeDay£€].[€£TimeDay£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

// MTD
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[MTD], [Measures].[€£AccountPayable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£TimeDay£€].[€£TimeDay£€].[Month],[€£TimeDay£€].[€£TimeDay£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

//POP
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[POP], [Measures].[€£AccountPayable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED)=1,
([€£TimeDay£€].[€£TimeDay£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£TimeDay£€].[€£TimeDay£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
([€£TimeDay£€].[€£TimeDay£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£TimeDay£€].[€£TimeDay£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]));
END SCOPE;

// R12
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[R12], [Measures].[€£AccountPayable£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([€£TimeDay£€].[€£TimeDay£€].[Month],11):PARALLELPERIOD([€£TimeDay£€].[€£TimeDay£€].[Month],0)}, [€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

// YTD Paid
//SCOPE ([€£Account£€].[€£Account£€].[Payables_Paid_Estimation]);
//THIS = ([€£Account£€].[€£Account£€].[PayablesPaid_]);
//END SCOPE;
'')'

SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountPayable£€'', N''calculate_Aging'', N''calculate_Aging'', N''SQL'', N''calculate_Aging'', N''EXECUTE Canvas_AR_AP_Calculate_Aging ''''AP'''''')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountPayable£€'', N''Copy_Opening'', N''Copy_Opening'', N''SQL'', N''Copy_Opening'', N''EXECUTE Canvas_AR_AP_Copy_Opening'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountPayable£€'', N''Deploy_Reforecast_Payment'', N''Deploy_Reforecast_Payment'', N''SQL'', N''Deploy_Reforecast_Payment'', N''EXECUTE canvas_AR_AP_Deploy_Payment'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountPayable£€'', N''Estimated_Payment_Calculation'', N''Estimated_Payment_Calculation'', N''SQL'', N''Estimated_Payment_Calculation'', N''EXECUTE Canvas_AR_AP_Update_Forecast ''''AP'''''')
'

SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Init_Payable'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Init_Payable'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''calculate_Aging'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''calculate_Aging'', N''€£Time£€Mbrs'', N''€£TimeDay£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''calculate_Aging'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Copy_Opening'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Copy_Opening'', N''€£Time£€Mbrs'', N''€£TimeDay£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Copy_Opening'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Deploy_Reforecast_Payment'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Deploy_Reforecast_Payment'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Estimated_Payment_Calculation'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Estimated_Payment_Calculation'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
'

SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£AccountPayable£€'', N''Canvas_FxTrans'', N''Canvas_FxTrans'', N''SQL'', N''Canvas_FxTrans'', N''Execute Canvas_FxTrans'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Canvas_FxTrans'', N''€£BusinessProcess£€Mbrs'', N''€£BusinessProcess£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Canvas_FxTrans'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Canvas_FxTrans'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Canvas_FxTrans'', N''€£TimeDay£€Mbrs'', N''€£Time£€'')
'
/*
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£AccountPayable£€'', N''Canvas_FxTrans'', N''€£Simulation£€Mbrs'', N''€£Simulation£€'')
*/

				EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'BusinessProcesses for AccountPayable', [SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

		ELSE IF @BaseModelID = -14 --Voucher
			BEGIN
				SET @Step = 'Create Business Rules, Voucher'
				SET @SQLStatement = '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Voucher£€'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Dynamic'', N''Calculate;

//Periodic
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[Periodic], [Measures].[€£Voucher£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
[€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA]*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED),
([€£TimeDataView£€].[€£TimeDataView£€].[RAWDATA],ClosingPeriod([€£Time£€].[€£Time£€].[Month]))
*[€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED));
END SCOPE;

// YTD
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[YTD], [Measures].[€£Voucher£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([€£Time£€].[€£Time£€].[Year],[€£Time£€].[€£Time£€].CurrentMember),[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;

//POP
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[POP], [Measures].[€£Voucher£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("Sign",TYPED)=1,
([€£Time£€].[€£Time£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£Time£€].[€£Time£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
([€£Time£€].[€£Time£€].CurrentMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]) - ([€£Time£€].[€£Time£€].PrevMember,[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]));
END SCOPE;

// R12
SCOPE ([€£TimeDataView£€].[€£TimeDataView£€].[R12], [Measures].[€£Voucher£€_Value]);
THIS = iif([€£Account£€].[€£Account£€].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([€£Time£€].[€£Time£€].[Month],11):PARALLELPERIOD([€£Time£€].[€£Time£€].[Month],0)}, [€£TimeDataView£€].[€£TimeDataView£€].[Periodic]),
[€£TimeDataView£€].[€£TimeDataView£€].[Periodic]);
END SCOPE;
'')

INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_Copy_Voucher'', N''Canvas_Copy_Voucher'', N''SQL'', N''Canvas_Copy_Voucher'', N''EXEC Canvas_Copy_Voucher'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_Copy_Voucher'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_Copy_Voucher'', N''€£Time£€Mbrs'', N''€£Time£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_Copy_Voucher'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
'

SET @SQLStatement = @SQLStatement + '
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRule] ([Action], [Model], [Label], [Description], [Type], [Path], [Text]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_FxTrans'', N''Canvas_FxTrans'', N''SQL'', N''Canvas_FxTrans'', N''Execute Canvas_FxTrans'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_FxTrans'', N''€£BusinessProcess£€Mbrs'', N''€£BusinessProcess£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_FxTrans'', N''€£Entity£€Mbrs'', N''€£Entity£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_FxTrans'', N''€£Scenario£€Mbrs'', N''€£Scenario£€'')
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_FxTrans'', N''€£Time£€Mbrs'', N''€£Time£€'')
'
/*
INSERT ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters] ([Action], [Model], [BusinessRule], [Label], [Dimension]) VALUES (NULL, N''€£Voucher£€'', N''Canvas_FxTrans'', N''€£Simulation£€Mbrs'', N''€£Simulation£€'')
*/
				EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'BusinessProcesses for Voucher', [SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version

	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH


GO
