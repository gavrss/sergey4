SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Dynamic_BusinessRule]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ModelBM int = NULL,	--1024	AccountPayable	
							--512	AccountReceivable	
							--64	Financials
							--8		Sales
							--4		FxRate
	
	@DynamicBR_Text nvarchar(MAX) = '' OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000617,
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
EXEC [spGet_Dynamic_BusinessRule] @UserID=-10, @InstanceID=413, @VersionID=1008, @ModelBM=64, @Debug=1

EXEC [spGet_Dynamic_BusinessRule] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@StorageTypeBM int,
	@HierarchyNo int,
	@HierarchyName nvarchar(100),
	@DataClassName nvarchar(50),
	@TDV_Label nvarchar(255),
	@Accounts_All nvarchar(500) = '',
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(MAX),

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2194'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get Dynamic BusineRule Text',
			@MandatoryParameter = 'ModelBM' --Without @, separated by |

		IF @Version = '2.1.0.2157' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2171' SET @Description = 'DB-635: Added BR Text for RAWDATAYTD, Periodic-NSR, YTD-NSR TimeDataView. Added BR Text for R03.'
		IF @Version = '2.1.1.2173' SET @Description = 'Get TimeDataView members from [pcINTEGRATOR]..[Member] if Callisto table [S_DS_TimeDataView] is not existing.'
		IF @Version = '2.1.2.2194' SET @Description = 'Added BR Text for PERIODIC_R, YTD_R, PERIODIC_R_T, and YTD_R_T TimeDataView.'

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
			@CallistoDatabase = A.DestinationDatabase
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID

		SELECT 
			@StorageTypeBM = StorageTypeBM 
		FROM 
			Dimension_StorageType 
		WHERE 
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND 
			DimensionID = -8  -- TimeDataView

		SELECT DISTINCT
			@DataClassName = D.DataClassName
		FROM
			DataClass D
			INNER JOIN DataClass_Dimension DM ON DM.DataClassID = D.DataClassID AND DM.DimensionID = -8 --TimeDataView
		WHERE
			D.InstanceID = @InstanceID AND
			D.VersionID = @VersionID AND
			D.ModelBM & @ModelBM > 0 AND
			D.StorageTypeBM & 4 > 0 AND
			D.SelectYN <> 0 AND
			D.DeletedID IS NULL

		--SET @DynamicBR_Text = 'Calculate;' + CHAR(13) + CHAR(10)

		IF @DebugBM & 2 > 0 SELECT [@DataClassName] = @DataClassName, [@ModelBM] = @ModelBM, [@CallistoDatabase] = @CallistoDatabase	

	SET @Step = 'Get TimeDataView Members'
		IF @StorageTypeBM & 4 > 0
			BEGIN 
				CREATE TABLE #TimeDataView_Members
					(
						MemberID int,
						MemberKey nvarchar(255) COLLATE DATABASE_DEFAULT
					)

				INSERT INTO #TimeDataView_Members
					(
					MemberID,
					MemberKey
					)
				SELECT
					[MemberID],
					[MemberKey] = [Label]
				FROM
					pcINTEGRATOR.dbo.Member
				WHERE
					DimensionID = -8 AND
					NodeTypeBM & 1 > 0 AND
					SelectYN <> 0 AND
					[Label] NOT IN ('RAWDATA') AND
					(@ModelBM & 8 <> 0 OR [Label] NOT IN ('MTD')) 
				ORDER BY
					[MemberId]

				IF OBJECT_ID (N'' + @CallistoDatabase + '.dbo.[S_DS_TimeDataView]', N'U') IS NOT NULL
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #TimeDataView_Members
								(
								MemberID,
								MemberKey
								)
							SELECT
								[MemberID] = T.[MemberId],
								[MemberKey] = T.[Label]
							FROM
								' + @CallistoDatabase + '.dbo.S_DS_TimeDataView T
							WHERE
								T.[Label] NOT IN (''All_'', ''NONE'', ''pcPlaceHolder'', ''ToBeSet'', ''RAWDATA''' + CASE WHEN @ModelBM & 8 > 0 THEN ')' ELSE ', ''MTD'')' END + ' AND
								NOT EXISTS (SELECT 1 FROM #TimeDataView_Members TM WHERE TM.[MemberID] = T.[MemberID] AND TM.[MemberKey] = T.[Label])
							ORDER BY
								T.[MemberId]'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC(@SQLStatement)
					END

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#TimeDataView_Members', * FROM #TimeDataView_Members ORDER BY MemberID
			END

	SET @Step = 'Get Account Hierarchies'
		IF @StorageTypeBM & 4 > 0
			BEGIN 
				CREATE TABLE #AccountHierarchies
					(
					HierarchyName nvarchar(100) COLLATE DATABASE_DEFAULT,
					HierarchyNo int,
					Account_All nvarchar(150)
					)

				INSERT INTO #AccountHierarchies
					(
					HierarchyName,
					HierarchyNo,
					Account_All
					)
				SELECT DISTINCT
					DH.HierarchyName,
					DH.HierarchyNo,
					[Account_All] = '[Account].[' + DH.HierarchyName + '].[All]'
				FROM
					DimensionHierarchy DH
					INNER JOIN Dimension D ON D.DimensionID = DH.DimensionID
				WHERE
					DH.InstanceID IN (0, @InstanceID) AND
					DH.VersionID IN (0, @VersionID) AND 
					DH.DimensionID = -1 --Account
					
				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#AccountHierarchies', * FROM #AccountHierarchies ORDER BY HierarchyName, HierarchyNo
			END 

	SET @Step = 'Create Dynamic Business Rule Text'
		IF @StorageTypeBM & 4 > 0 --Callisto
			BEGIN
				SET @DynamicBR_Text = 'Calculate;' + CHAR(13) + CHAR(10)

				IF CURSOR_STATUS('global','TimeDataView_Cursor') >= -1 DEALLOCATE TimeDataView_Cursor
				DECLARE TimeDataView_Cursor CURSOR FOR
			
					SELECT 
						TDV_Label = [MemberKey]
					FROM
						#TimeDataView_Members
					ORDER BY
						MemberID

					OPEN TimeDataView_Cursor
					FETCH NEXT FROM TimeDataView_Cursor INTO @TDV_Label

					WHILE @@FETCH_STATUS = 0
						BEGIN
							--IF @DebugBM & 2 > 0 SELECT [@TDV_Label] = @TDV_Label
							SET @DynamicBR_Text = @DynamicBR_Text + 
'
//' + @TDV_Label + '
SCOPE ([TimeDataView].[TimeDataView].[' + @TDV_Label + '], [Measures].[' + @DataClassName + '_Value]);'

							IF @TDV_Label = 'PERIODIC' OR @TDV_Label = 'YTD'
								BEGIN 
									IF CURSOR_STATUS('global','AccountHierarchy_Cursor') >= -1 DEALLOCATE AccountHierarchy_Cursor
									DECLARE AccountHierarchy_Cursor CURSOR FOR
			
										SELECT 
											HierarchyName,
											HierarchyNo
										FROM
											#AccountHierarchies
										ORDER BY
											HierarchyName, HierarchyNo

										OPEN AccountHierarchy_Cursor
										FETCH NEXT FROM AccountHierarchy_Cursor INTO @HierarchyName, @HierarchyNo

										WHILE @@FETCH_STATUS = 0
											BEGIN
												SET @Accounts_All = ''
												SELECT @Accounts_All = @Accounts_All + [Account_All] + ',' + CHAR(13) + CHAR(10) FROM #AccountHierarchies WHERE HierarchyName <> @HierarchyName 
												
												--IF @DebugBM & 2 > 0 SELECT [@Accounts_All] = @Accounts_All

												SET @DynamicBR_Text = @DynamicBR_Text + 
'
SCOPE (
' + @Accounts_All + 
'[Account].[' + @HierarchyName + '].Members);
THIS = iif([Account].[' + @HierarchyName + '].CurrentMember.Properties("TimeBalance",TYPED)=0,' +
													CASE
														WHEN @TDV_Label = 'PERIODIC' THEN 
'
[TimeDataView].[TimeDataView].[RAWDATA]*[Account].[' + @HierarchyName + '].CurrentMember.Properties("Sign",TYPED),
([TimeDataView].[TimeDataView].[RAWDATA],ClosingPeriod([Time].[Time].[Month]))
*[Account].[' + @HierarchyName + '].CurrentMember.Properties("Sign",TYPED));
'
														WHEN @TDV_Label = 'YTD' THEN 
'
SUM(PeriodsToDate([Time].[Time].[Year],[Time].[Time].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
'
														ELSE ''
													END +
'END SCOPE;
' 
												FETCH NEXT FROM AccountHierarchy_Cursor INTO @HierarchyName, @HierarchyNo
											END

										CLOSE AccountHierarchy_Cursor
										DEALLOCATE AccountHierarchy_Cursor
								END
							ELSE
								BEGIN
									SET @DynamicBR_Text = @DynamicBR_Text + 
									CASE
										WHEN @TDV_Label = 'POP' THEN 
'
THIS = iif([Account].[Account].CurrentMember.Properties("Sign",TYPED)=1,
([Time].[Time].PrevMember,[TimeDataView].[TimeDataView].[Periodic]) - ([Time].[Time].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]),
([Time].[Time].CurrentMember,[TimeDataView].[TimeDataView].[Periodic]) - ([Time].[Time].PrevMember,[TimeDataView].[TimeDataView].[Periodic]));
' 
										WHEN @TDV_Label = 'R12' THEN 
'
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([Time].[Time].[Month],11):PARALLELPERIOD([Time].[Time].[Month],0)}, [TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
'
										WHEN @TDV_Label = 'MTD' AND @ModelBM & 8 > 0 THEN
'
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM(PeriodsToDate([TimeDay].[TimeDay].[Month],[TimeDay].[TimeDay].CurrentMember),[TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
'
										WHEN @TDV_Label = 'RAWDATAYTD' THEN 
'
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([Time].[Time].[Year],[Time].[Time].CurrentMember),[TimeDataView].[TimeDataView].[RAWDATA]),
[TimeDataView].[TimeDataView].[RAWDATA]);
'
										WHEN @TDV_Label = 'Periodic-NSR' THEN 
'
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
[TimeDataView].[TimeDataView].[RAWDATA],
([TimeDataView].[TimeDataView].[RAWDATA],ClosingPeriod([Time].[Time].[Month])));
'
										WHEN @TDV_Label = 'YTD-NSR' THEN 
'
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
Sum(PeriodsToDate([Time].[Time].[Year],[Time].[Time].CurrentMember),[TimeDataView].[TimeDataView].[Periodic-NSR]),
[TimeDataView].[TimeDataView].[Periodic]);
'
										WHEN @TDV_Label = 'R03' THEN 
'
THIS = iif([Account].[Account].CurrentMember.Properties("TimeBalance",TYPED)=0,
SUM({PARALLELPERIOD([Time].[Time].[Month],2):PARALLELPERIOD([Time].[Time].[Month],0)}, [TimeDataView].[TimeDataView].[Periodic]),
[TimeDataView].[TimeDataView].[Periodic]);
'
										WHEN @TDV_Label = 'PERIODIC_R' THEN 
'
THIS = INT([TimeDataView].[TimeDataView].[Periodic] + 0.5);
'
										WHEN @TDV_Label = 'YTD_R' THEN 
'
THIS = INT([TimeDataView].[TimeDataView].[YTD] + 0.5);
'
										WHEN @TDV_Label = 'PERIODIC_R_T' THEN 
'
THIS = INT(([TimeDataView].[TimeDataView].[Periodic]/1000) + 0.5);
'
										WHEN @TDV_Label = 'YTD_R_T' THEN 
'
THIS = INT(([TimeDataView].[TimeDataView].[YTD]/1000) + 0.5);
'
										ELSE ''
									END
								END
							SET @DynamicBR_Text = @DynamicBR_Text + 
'END SCOPE;
'
							FETCH NEXT FROM TimeDataView_Cursor INTO @TDV_Label
						END

				CLOSE TimeDataView_Cursor
				DEALLOCATE TimeDataView_Cursor

				IF LEN(@DynamicBR_Text) > 14
					SET @DynamicBR_Text = @DynamicBR_Text + '
// Measures
CREATE MEMBER CURRENTCUBE.[Measures].[Actual] AS ''([Scenario].[Scenario].[Actual], [Measures].[' + @DataClassName + '_Value])''
,ASSOCIATED_MEASURE_GROUP=''MeasureGroup'',DISPLAY_FOLDER=''Scenario'',SOLVE_ORDER=1,FORMAT_STRING = ''# ### ##0'';

CREATE MEMBER CURRENTCUBE.[Measures].[Budget] AS ''([Scenario].[Scenario].[Budget], [Measures].[' + @DataClassName + '_Value])''
,ASSOCIATED_MEASURE_GROUP=''MeasureGroup'',DISPLAY_FOLDER=''Scenario'',SOLVE_ORDER=1,FORMAT_STRING = ''# ### ##0'';'
			END

		IF @DebugBM & 2 > 0 PRINT @DynamicBR_Text
		
/*
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
*/

	SET @Step = 'Return Dynamic BusinessRule Text'
		IF @DebugBM & 1 > 0 SELECT @DynamicBR_Text

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
