SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_ScenarioCopy]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBM int = 12, --1=Selection, 2=Backup, 4=Delete (to), 8=Insert (copied information with modified Time and Scenario)
	@DataClassID int = NULL,
	@FromScenarioID int = NULL, --Mandatory
	@ToScenarioID int = NULL, --Mandatory
	@FromTime int = NULL, --Mandatory, YYYYMM, Destination Time  (YearOffset added to source time)
	@ToTime int = NULL, --Mandatory, YYYYMM, Destination Time  (YearOffset added to source time)
	@YearOffset int = 0, --Negative number use previous periods as source
	@Filter nvarchar(4000) = NULL, --Excl Time and Scenario and any simplified dimension
	@SimplifyDimensionYN bit = NULL, --Default from Scenario table
	@RefreshActualsYN BIT = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000122,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*

EXEC [spPortalAdminSet_ScenarioCopy] 
	@UserID='2151', 
	@InstanceID='413', 
	@VersionID='1008', 
	@FromScenarioID='1354',
	@ToScenarioID='1355', 
	@FromTime='201704', 
	@ToTime='201803', 
	@YearOffset='3',
	@SimplifyDimensionYN = 1,
	@SequenceBM = 3,
	@Debug = 1

EXEC [spPortalAdminSet_ScenarioCopy] 
	@UserID='2151', 
	@InstanceID='413', 
	@VersionID='1008', 
	@FromScenarioID='1354',
	@ToScenarioID='1354', 
	@FromTime='201703', 
	@ToTime='201802', 
	@YearOffset='1',
	@SimplifyDimensionYN = -1,
	@SequenceBM = 3,
	@Debug = 1

EXEC [spPortalAdminSet_ScenarioCopy] 
	@UserID=-10, 
	@InstanceID='454', 
	@VersionID='1021', 
	@DataClassID = 7736,
	@FromScenarioID='8712',
	@ToScenarioID='8727', 
	@FromTime='201703', 
	@ToTime='201802', 
	@YearOffset='1',
	@SimplifyDimensionYN = -1,
	@SequenceBM = 3,
	@Debug = 1

EXEC [spPortalAdminSet_ScenarioCopy] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@FromScenario_MemberKey nvarchar(100),
	@ToScenario_MemberKey nvarchar(100),
	@FromScenario_MemberID bigint = NULL,
	@ToScenario_MemberID bigint = NULL,
	@InitialWorkflowStateID int,
	@DestinationTimeFrom int, --Start time in ToScenario
	@DestinationTimeTo int, --End time in ToScenario
	@SourceTimeFrom int, --Start time in FromScenario
	@SourceTimeTo int, --End time in FromScenario
	@TextTableYN int,
	@FromSimplifyDimensionYN bit,

	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(MAX),
	@SQLStatement_Select nvarchar(4000),
	@SQLStatement_Insert nvarchar(4000),
	@SQLStatement_GroupBy nvarchar(4000),
	@DataClassName nvarchar(100),
	@BP_Consolidated nvarchar(4000),
	@DimensionID int,
	@DimensionName nvarchar(100),
	@Destination_MemberKey nvarchar(100),
	@TimeDimID int,
	@BPYN bit,
	@BRYN bit,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
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
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Copy Scenario for selected time frame',
			@MandatoryParameter = 'FromScenarioID|ToScenarioID|FromTime|ToTime' --Without @, separated by |

		IF @Version = '2.0.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2142' SET @Description = 'Hardcoded for CBN.'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-110: Made generic.'
		IF @Version = '2.0.2.2148' SET @Description = 'Change RefreshActuals_MemberKey to Conversion_MemberKey. DB-189: Time parameters now used in Destination side instead of Source side.'
		IF @Version = '2.1.1.2171' SET @Description = 'Get @SimplifyDimensionYN from ScenarioTable.'
		IF @Version = '2.1.1.2172' SET @Description = 'Handle LineItem.'
		IF @Version = '2.1.2.2182' SET @Description = 'Verify existance of dimension columns in the FACT tables.Added parameter @RefreshActualsYN; use [Workflow].[RefreshActualsInitialWorkflowStateID] for [spPortalAdminSet_ScenarioRefreshActuals] transactions.'
		IF @Version = '2.1.2.2191' SET @Description = 'Change comment on parameter @YearOffset int = 0, --Negative number use previous periods as source'

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		--Scenario
		SELECT
			@FromScenario_MemberKey = MemberKey,
			@FromSimplifyDimensionYN = [SimplifiedDimensionalityYN]
		FROM
			Scenario
		WHERE
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND
			ScenarioID = @FromScenarioID

		SELECT
			@ToScenario_MemberKey = [MemberKey],
			@SimplifyDimensionYN = CASE WHEN @FromSimplifyDimensionYN <> 0 THEN 0 ELSE ISNULL(@SimplifyDimensionYN, [SimplifiedDimensionalityYN]) END
		FROM
			Scenario
		WHERE
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND
			ScenarioID = @ToScenarioID

		SET @SQLStatement = '
			SELECT
				@InternalVariable = S.MemberId
			FROM
				' + @CallistoDatabase + '.dbo.S_DS_Scenario S
			WHERE
				S.Label = ''' + @FromScenario_MemberKey + ''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @FromScenario_MemberId OUT

		SET @SQLStatement = '
			SELECT
				@InternalVariable = S.MemberId
			FROM
				' + @CallistoDatabase + '.dbo.S_DS_Scenario S
			WHERE
				S.Label = ''' + @ToScenario_MemberKey + ''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @ToScenario_MemberId OUT

		--Time
		SELECT
			@DestinationTimeFrom = @FromTime,
			@DestinationTimeTo = @ToTime,

			@SourceTimeFrom = @FromTime + @YearOffset * 100, --Start time in ToScenario
			@SourceTimeTo = @ToTime + @YearOffset * 100 --End time in ToScenario

		--Workflow
		IF @Debug <> 0
			SELECT
				[Table] = 'Workflow',
				*
			FROM
				Workflow
			WHERE
				InstanceID = @InstanceID AND
				VersionID = @VersionID AND
				ScenarioID = @ToScenarioID AND 
				TimeFrom <= @DestinationTimeFrom AND
				TimeTo >= @DestinationTimeTo

		SELECT
			@InitialWorkflowStateID = ISNULL(CASE WHEN @RefreshActualsYN <> 0 THEN WF.RefreshActualsInitialWorkflowStateID ELSE WF.InitialWorkflowStateID END, -1)
		FROM
			(SELECT Dummy = 0) D
			LEFT JOIN Workflow WF ON 
				WF.InstanceID = @InstanceID AND
				WF.VersionID = @VersionID AND
				WF.ScenarioID = @ToScenarioID AND 
				WF.TimeFrom <= @DestinationTimeFrom AND
				WF.TimeTo >= @DestinationTimeTo AND
				WF.DeletedID IS NULL 

		--@BP_Consolidated
		EXEC spGet_LeafLevelFilter @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DatabaseName=@CallistoDatabase, @DimensionName='BusinessProcess', @Filter= 'Consolidated', @StorageTypeBM=4, @StorageTypeBM_DataClass=4, @LeafLevelFilter=@BP_Consolidated OUT

		IF @Debug <> 0
			SELECT
				[@UserName] = @UserName,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@FromScenario_MemberKey] = @FromScenario_MemberKey,
				[@FromScenarioID] = @FromScenarioID, 
				[@FromScenario_MemberID] = @FromScenario_MemberID, 
				[@ToScenario_MemberKey] = @ToScenario_MemberKey,
				[@ToScenarioID] = @ToScenarioID, 
				[@ToScenario_MemberID] = @ToScenario_MemberID, 
				[@InitialWorkflowStateID] = @InitialWorkflowStateID,
				[@SourceTimeFrom] = @SourceTimeFrom, --Start time in FromScenario
				[@SourceTimeTo] = @SourceTimeTo, --End time in FromScenario
				[@DestinationTimeFrom] = @DestinationTimeFrom, --Start time in ToScenario
				[@DestinationTimeTo] = @DestinationTimeTo, --End time in ToScenario
				[@BP_Consolidated] = @BP_Consolidated,
				[@SimplifyDimensionYN] = @SimplifyDimensionYN

	SET @Step = 'Check for time overlap within same Scenario'
		IF @FromScenario_MemberKey = @ToScenario_MemberKey AND ((@SourceTimeFrom <= @DestinationTimeFrom AND @SourceTimeTo >= @DestinationTimeFrom) OR (@SourceTimeFrom >= @DestinationTimeFrom AND @DestinationTimeTo >= @SourceTimeFrom))
			BEGIN
				SET @Message = 'It is not allowed to have time overlap when copying in the same scenario.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp table #DimensionList'
		CREATE TABLE #DimensionList
			(
			[DimensionID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] int,
			[Destination_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Destination_MemberID] bigint,
			[SortOrder] int
			)

	SET @Step = 'Create temp table #SysColumns'
		CREATE TABLE #SysColumns
			(
			[Column] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'SC_DataClass_Cursor'
			SELECT DISTINCT
				DCD.DataClassID,
				DC.DataClassName,
				TimeDim.TimeDimID,
				BPYN = CASE WHEN BP.DataClassID IS NULL THEN 0 ELSE 1 END,
				BRYN = CASE WHEN BR.DataClassID IS NULL THEN 0 ELSE 1 END
			INTO
				#SC_DataClass_Cursor_Table
			FROM
				DataClass_Dimension DCD
				INNER JOIN DataClass DC ON DC.DataClassID = DCD.DataClassID AND DC.SelectYN <> 0 AND DC.DeletedID IS NULL
				INNER JOIN 
				(
				SELECT DISTINCT
					DCD.DataClassID,
					TimeDimID = CASE WHEN [7].[TimeDimID] IS NOT NULL THEN -7 ELSE CASE WHEN [49].[TimeDimID] IS NOT NULL THEN -49 END END
				FROM
					DataClass_Dimension DCD
					LEFT JOIN (SELECT [TimeDimID] = -7) [7] ON [7].[TimeDimID] = DCD.[DimensionID]
					LEFT JOIN (SELECT [TimeDimID] = -49) [49] ON [49].[TimeDimID] = DCD.[DimensionID]
				WHERE
					DCD.InstanceID = @InstanceID AND
					DCD.VersionID = @VersionID AND
					(DCD.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
					DCD.DimensionID IN (-7, -49)
				) TimeDim ON TimeDim.DataClassID = DCD.DataClassID
				LEFT JOIN 
					(
					SELECT
						DCD.DataClassID
					FROM
						DataClass_Dimension DCD
					WHERE
						DCD.InstanceID = @InstanceID AND
						DCD.VersionID = @VersionID AND
						DCD.DimensionID = -2 AND
						(DCD.DataClassID = @DataClassID OR @DataClassID IS NULL)
					GROUP BY
						DCD.DataClassID
					) BP ON BP.DataClassID = DCD.DataClassID
				LEFT JOIN 
					(
					SELECT
						DCD.DataClassID
					FROM
						DataClass_Dimension DCD
					WHERE
						DCD.InstanceID = @InstanceID AND
						DCD.VersionID = @VersionID AND
						DCD.DimensionID = -55 AND
						(DCD.DataClassID = @DataClassID OR @DataClassID IS NULL)
					GROUP BY
						DCD.DataClassID
					) BR ON BR.DataClassID = DCD.DataClassID
			WHERE
				DCD.InstanceID = @InstanceID AND
				DCD.VersionID = @VersionID AND
				(DCD.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
				DCD.DimensionID = -6 --Scenario

		IF @Debug <> 0 SELECT TempTable = '#SC_DataClass_Cursor_Table', * FROM #SC_DataClass_Cursor_Table ORDER BY DataClassID

		IF CURSOR_STATUS('global','SC_DataClass_Cursor') >= -1 DEALLOCATE SC_DataClass_Cursor
		DECLARE SC_DataClass_Cursor CURSOR FOR
			
			SELECT DISTINCT
				DataClassID,
				DataClassName,
				TimeDimID,
				BPYN,
				BRYN
			FROM
				#SC_DataClass_Cursor_Table
			ORDER BY
				DataClassID

			OPEN SC_DataClass_Cursor
			FETCH NEXT FROM SC_DataClass_Cursor INTO @DataClassID, @DataClassName, @TimeDimID, @BPYN, @BRYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@DataClassID] = @DataClassID, [@DataClassName] = @DataClassName, [@TimeDimID] = @TimeDimID, [@BPYN] = @BPYN, [@BRYN] = @BRYN

					TRUNCATE TABLE #SysColumns
					
					SET @SQLStatement = '
						INSERT INTO #SysColumns
							(
							[Column]
							)
						SELECT 
							[Column] = c.[name] 
						FROM
							' + @CallistoDatabase + '.sys.tables t
							INNER JOIN ' + @CallistoDatabase + '.sys.columns c ON c.[object_id] = t.[object_id]
						WHERE
							t.[name] = ''FACT_' + @DataClassName + '_default_partition'''

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					IF @Debug <> 0 SELECT TempTable = '#SysColumns', * FROM #SysColumns ORDER BY [Column]					
					
					TRUNCATE TABLE #DimensionList
					
					INSERT INTO #DimensionList
						(
						[DimensionID],
						[DimensionName],
						[StorageTypeBM],
						[Destination_MemberKey],
						[SortOrder]
						)
					SELECT
						[DimensionID] = DCD.DimensionID,
						[DimensionName] = D.DimensionName,
						[StorageTypeBM] = DST.StorageTypeBM,
						[Destination_MemberKey] = CASE WHEN @SimplifyDimensionYN <> 0 THEN DCD.[Conversion_MemberKey] ELSE NULL END,
						[SortOrder] = CASE WHEN DCD.DimensionID = -27 THEN -10 ELSE DCD.SortOrder END
					FROM
						DataClass_Dimension DCD
						INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = DCD.DimensionID AND D.DimensionTypeID NOT IN (27, 50)
						INNER JOIN #SysColumns SC ON SC.[Column] = D.DimensionName + '_MemberId'
						LEFT JOIN Dimension_StorageType DST ON DST.InstanceID = DCD.InstanceID AND DST.VersionID = DCD.VersionID AND DST.DimensionID = DCD.DimensionID
					WHERE
						DCD.InstanceID = @InstanceID AND
						DCD.VersionID = @VersionID AND
						DCD.DataClassID = @DataClassID
					ORDER BY
						DCD.SortOrder

					IF @Debug <> 0 SELECT TempTable = '#DimensionList (Step 1)', * FROM #DimensionList

					SET @Step = 'MemberId_Cursor'
					DECLARE MemberId_Cursor CURSOR FOR
			
						SELECT 
							DimensionID,
							DimensionName,
							Destination_MemberKey
						FROM
							#DimensionList
						WHERE
							Destination_MemberKey IS NOT NULL

						OPEN MemberId_Cursor
						FETCH NEXT FROM MemberId_Cursor INTO @DimensionID, @DimensionName, @Destination_MemberKey

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @Debug <> 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@Destination_MemberKey] = @Destination_MemberKey

								SET @SQLStatement = '
									UPDATE DL
									SET
										[Destination_MemberID] = D.[MemberId]
									FROM
										#DimensionList DL
										INNER JOIN ' + @CallistoDatabase + '.dbo.S_DS_' + @DimensionName + ' D ON D.[Label] = DL.[Destination_MemberKey]'

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								FETCH NEXT FROM MemberId_Cursor INTO  @DimensionID, @DimensionName, @Destination_MemberKey
							END

					CLOSE MemberId_Cursor
					DEALLOCATE MemberId_Cursor
					
					UPDATE DL
					SET
						[Destination_MemberKey] = 'CASE WHEN F.[BusinessProcess_MemberId] = 118 THEN 118 ELSE ' + CONVERT(nvarchar(15), DL.[Destination_MemberID]) + ' END',
						[Destination_MemberID] = NULL
					FROM
						#DimensionList DL
					WHERE
						DL.[DimensionID] = -2 AND
						DL.[Destination_MemberID] IS NOT NULL

					UPDATE DL
					SET
						Destination_MemberKey = @ToScenario_MemberKey,
						Destination_MemberID = @ToScenario_MemberId
					FROM
						#DimensionList DL
					WHERE
						DimensionID = -6

					UPDATE DL
					SET
						Destination_MemberID = @InitialWorkflowStateID
					FROM
						#DimensionList DL
					WHERE
						DimensionID = -63

					UPDATE DL
					SET
						Destination_MemberKey = 'F.[Time_MemberId] + ' + CONVERT(nvarchar(15), @YearOffset * -100)
					FROM
						#DimensionList DL
					WHERE
						DimensionID = -7

					UPDATE DL
					SET
						Destination_MemberKey = 'F.[TimeDay_MemberId] + ' + CONVERT(nvarchar(15), @YearOffset * -10000)
					FROM
						#DimensionList DL
					WHERE
						DimensionID = -49

					IF @Debug <> 0 SELECT TempTable = '#DimensionList (Step 2)', * FROM #DimensionList ORDER BY SortOrder

					SET @SQLStatement = '
						SELECT @InternalVariable = COUNT(1) FROM ' + @CallistoDatabase + '.sys.tables WHERE [name] = ''FACT_' + @DataClassName + '_text'''

					EXEC sp_executesql @SQLStatement, N'@internalVariable int OUT', @InternalVariable = @TextTableYN OUT

					IF @SequenceBM & 4 > 0  --Delete
						BEGIN
							--FACT table
							SET @SQLStatement = '
								DELETE ' + @CallistoDatabase + '.dbo.FACT_' + @DataClassName + '_default_partition
								WHERE
									Scenario_MemberId = ' + CONVERT(nvarchar(20), @ToScenario_MemberID) + ' AND
									' + CASE WHEN @TimeDimID = -49 THEN 'TimeDay_MemberId' ELSE 'Time_MemberId' END + ' BETWEEN ' + CONVERT(nvarchar(20), CASE WHEN @TimeDimID = -49 THEN @DestinationTimeFrom * 100 ELSE @DestinationTimeFrom END) + ' AND ' + CONVERT(nvarchar(20), CASE WHEN @TimeDimID = -49 THEN @DestinationTimeTo * 100 + 99 ELSE @DestinationTimeTo END) 

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Deleted = @Deleted + @@ROWCOUNT

							--Text table
							IF @TextTableYN <> 0
								BEGIN
									SET @SQLStatement = '
										DELETE ' + @CallistoDatabase + '.dbo.FACT_' + @DataClassName + '_text
										WHERE
											Scenario_MemberId = ' + CONVERT(nvarchar(20), @ToScenario_MemberID) + ' AND
											' + CASE WHEN @TimeDimID = -49 THEN 'TimeDay_MemberId' ELSE 'Time_MemberId' END + ' BETWEEN ' + CONVERT(nvarchar(20), CASE WHEN @TimeDimID = -49 THEN @DestinationTimeFrom * 100 ELSE @DestinationTimeFrom END) + ' AND ' + CONVERT(nvarchar(20), CASE WHEN @TimeDimID = -49 THEN @DestinationTimeTo * 100 + 99 ELSE @DestinationTimeTo END) 

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SET @Deleted = @Deleted + @@ROWCOUNT
								END
						END

					IF @SequenceBM & 8 > 0  --Insert
						BEGIN
							SELECT @SQLStatement_Select = '', @SQLStatement_Insert = '', @SQLStatement_GroupBy = ''

							SELECT
								@SQLStatement_Insert = @SQLStatement_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + DimensionName +'_MemberId],',
								@SQLStatement_Select = @SQLStatement_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + DimensionName +'_MemberId] = ' + CASE WHEN Destination_MemberKey IS NULL AND Destination_MemberID IS NULL THEN 'F.[' + DimensionName +'_MemberId]' ELSE CASE WHEN Destination_MemberID IS NULL THEN Destination_MemberKey ELSE CONVERT(nvarchar(20), Destination_MemberID) END END + ',',
								@SQLStatement_GroupBy = @SQLStatement_GroupBy + CASE WHEN Destination_MemberKey IS NULL AND Destination_MemberID IS NULL THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'F.[' + DimensionName +'_MemberId],' ELSE CASE WHEN Destination_MemberKey IS NOT NULL AND Destination_MemberID IS NULL THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + Destination_MemberKey + ',' ELSE '' END END
							FROM
								#DimensionList

							SET @SQLStatement_GroupBy = LEFT(@SQLStatement_GroupBy, LEN(@SQLStatement_GroupBy) -1)

							IF @Debug <> 0
								SELECT
									[@SQLStatement_Insert] = @SQLStatement_Insert,
									[@SQLStatement_Select] = @SQLStatement_Select,
									[@CallistoDatabase] = @CallistoDatabase,
									[@DataClassName] = @DataClassName,
									[@TextTableYN] = @TextTableYN,
									[@FromScenario_MemberID] = @FromScenario_MemberID,
									[@BP_Consolidated] = @BP_Consolidated,
									[@SourceTimeFrom] = @SourceTimeFrom,
									[@SourceTimeTo] = @SourceTimeTo,
									[@TimeDimID] = @TimeDimID,
									[@SQLStatement_GroupBy] = @SQLStatement_GroupBy

							--SET @SQLStatement = '
							--	SELECT * FROM ' + @CallistoDatabase + '.sys.tables WHERE [name] = ''FACT_' + @DataClassName + '_text'''



							--FACT table
							SET @SQLStatement = '
								INSERT INTO ' + @CallistoDatabase + '.dbo.FACT_' + @DataClassName + '_default_partition
									(' + @SQLStatement_Insert + '
									[ChangeDateTime],
									[UserId],
									[' + @DataClassName + '_Value]
									)
								SELECT' + @SQLStatement_Select + '
									[ChangeDateTime] = GetDate(),
									[UserId] = suser_name(),
									[' + @DataClassName + '_Value] = SUM(F.[' + @DataClassName + '_Value])
								FROM'

							SET @SQLStatement = @SQLStatement + '
									' + @CallistoDatabase + '.dbo.FACT_' + @DataClassName + '_default_partition F
								WHERE
									F.Scenario_MemberId = ' + CONVERT(nvarchar(15), @FromScenario_MemberID) + ' AND
									' + CASE WHEN @BPYN <> 0 AND @SimplifyDimensionYN <> 0 THEN 'F.BusinessProcess_MemberID IN (' + @BP_Consolidated + ') AND' ELSE '' END + '
									' + CASE WHEN @BRYN <> 0 AND @SimplifyDimensionYN <> 0 THEN 'F.BusinessRule_MemberID = -1 AND' ELSE '' END + '
									F.' + CASE WHEN @TimeDimID = -49 THEN 'TimeDay_MemberId' ELSE 'Time_MemberId' END + ' BETWEEN ' + CONVERT(nvarchar(20), CASE WHEN @TimeDimID = -49 THEN @SourceTimeFrom * 100 ELSE @SourceTimeFrom END) + ' AND ' + CONVERT(nvarchar(20), CASE WHEN @TimeDimID = -49 THEN @SourceTimeTo * 100 + 99 ELSE @SourceTimeTo END) + '
								GROUP BY' + @SQLStatement_GroupBy

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Inserted = @Inserted + @@ROWCOUNT

							--Text table
							IF @TextTableYN <> 0
								BEGIN
									SET @SQLStatement = '
										INSERT INTO ' + @CallistoDatabase + '.dbo.FACT_' + @DataClassName + '_text
											(' + @SQLStatement_Insert + '
											[ChangeDateTime],
											[UserId],
											[' + @DataClassName + '_Text]
											)
										SELECT' + @SQLStatement_Select + '
											[ChangeDateTime] = GetDate(),
											[UserId] = suser_name(),
											[' + @DataClassName + '_Text] = F.[' + @DataClassName + '_Text]
										FROM'

									SET @SQLStatement = @SQLStatement + '
											' + @CallistoDatabase + '.dbo.FACT_' + @DataClassName + '_text F
										WHERE
											F.Scenario_MemberId = ' + CONVERT(nvarchar(15), @FromScenario_MemberID) + ' AND
											' + CASE WHEN @BPYN <> 0 AND @SimplifyDimensionYN <> 0 THEN 'F.BusinessProcess_MemberID IN (' + @BP_Consolidated + ') AND' ELSE '' END + '
											' + CASE WHEN @BRYN <> 0 AND @SimplifyDimensionYN <> 0 THEN 'F.BusinessRule_MemberID = -1 AND' ELSE '' END + '
											F.' + CASE WHEN @TimeDimID = -49 THEN 'TimeDay_MemberId' ELSE 'Time_MemberId' END + ' BETWEEN ' + CONVERT(nvarchar(20), CASE WHEN @TimeDimID = -49 THEN @SourceTimeFrom * 100 ELSE @SourceTimeFrom END) + ' AND ' + CONVERT(nvarchar(20), CASE WHEN @TimeDimID = -49 THEN @SourceTimeTo * 100 + 99 ELSE @SourceTimeTo END)

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SET @Inserted = @Inserted + @@ROWCOUNT
								END

						END

					--Run refresh Callisto cube
					EXEC [dbo].[spRun_Job_Callisto_Generic]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@JobName = 'Callisto_Generic',
						@StepName = 'Refresh',
						@ModelName = @DataClassName, --Mandatory for Refresh
						@JobQueueYN = 0,
						@AsynchronousYN = 1,
						@JobID = @JobID

					FETCH NEXT FROM SC_DataClass_Cursor INTO @DataClassID, @DataClassName, @TimeDimID, @BPYN, @BRYN
				END

		CLOSE SC_DataClass_Cursor
		DEALLOCATE SC_DataClass_Cursor

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
