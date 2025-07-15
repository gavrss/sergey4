SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spSetup_Job]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@StorageTypeBM INT = NULL,
	@SourceTypeID INT = NULL,
	@SequenceBM INT = 3, --1=JobList, 2=JobStep
	@JobStepTypeBM INT = 127, --1=Setup, 2=Preparation, 4=Dimensions, 8=Data, 16=Calculations, 32=Other, 64=CheckSums
	@ProductOptionID INT = NULL, --In combination with @SourceTypeID = -20, specific DataClass (Optional) will be included in @JobStepTypeBM = 8
	@TemplateObjectID INT = NULL, --In combination with @SourceTypeID = -20, required for SalesReport DataClass setup

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000579,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spSetup_Job] @SequenceBM = 2,@UserID = -10, @InstanceID = 695, @VersionID = 1145, @StorageTypeBM = 4, @SourceTypeID = -20, @ProductOptionID = 211, @DebugBM = 7 --Sales (includes SalesBudget)

EXEC [spSetup_Job] @UserID=-10, @InstanceID=52, @VersionID=1035, @StorageTypeBM = 4, @DebugBM=2
EXEC [spSetup_Job] @UserID = -10, @InstanceID = -1427, @VersionID = -1365, @StorageTypeBM = 4, @SourceTypeID = -20, @ProductOptionID = 211, @DebugBM = 7

EXEC [spSetup_Job] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SourceInstanceID INT = -10,
	@SourceVersionID INT = -10,
	@SumRowCount INT,
	@LoopCount INT = 0,
	@DataClassName NVARCHAR(50),

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Job',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2159' SET @Description = 'Fixed bug.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP names.'
		IF @Version = '2.1.0.2162' SET @Description = 'Changed to [JobStepGroupBM] = 3 when inserting into [JobStep] where [JobStepTypeBM] = 4.'
		IF @Version = '2.1.0.2164' SET @Description = 'Added NOT EXISTS filter when INSERTing into #DimLoad WHERE DependencyPrio >= 2.'
		IF @Version = '2.1.1.2168' SET @Description = 'Modified INSERT query to [JobStep] when setting [JobFrequencyBM] and [JobStepGroupBM].'
		IF @Version = '2.1.2.2169' SET @Description = 'Added @ProductOptionID. Handle optional DataClass setup in @JobStepTypeBM = 8.'
		IF @Version = '2.1.2.2199' SET @Description = 'Moved varialble @TemplateObjectID to parameter.'

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

		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @DebugBM & 2 > 0 
			SELECT 
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@StorageTypeBM] = @StorageTypeBM,
				[@SequenceBM] = @SequenceBM,
				[@JobID] = @JobID

	SET @Step = '@SequenceBM = 1, JobList'
		IF @SequenceBM & 1 > 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobList]
					(
					[InstanceID],
					[VersionID],
					[JobListName],
					[JobListDescription],
					[JobStepTypeBM],
					[JobFrequencyBM],
					[JobStepGroupBM],
					[ProcessBM],
					[JobSetupStepBM],
					[JobStep_List],
					[Entity_List],
					[DelayedStart],
					[InheritedFrom],
					[UserID],
					[SelectYN]
					)
				SELECT  
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[JobListName],
					[JobListDescription],
					[JobStepTypeBM],
					[JobFrequencyBM],
					[JobStepGroupBM],
					[ProcessBM],
					[JobSetupStepBM],
					[JobStep_List],
					[Entity_List],
					[DelayedStart],
					[InheritedFrom] = TJL.[JobListID],
					[UserID] = @UserID,
					[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_JobList] TJL
				WHERE
					InstanceID = @SourceInstanceID AND
					VersionID = @SourceVersionID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobList] JL WHERE JL.[InstanceID] = @InstanceID AND JL.[VersionID] = @VersionID AND JL.[JobListName] = TJL.[JobListName])
				ORDER BY
					TJL.[JobListID] DESC

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = '@SequenceBM = 2, JobStep'
		IF @SequenceBM & 2 > 0
			BEGIN
				IF @JobStepTypeBM & 1 > 0 --Setup, Setup and change configurations
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@JobStepTypeBM] = 1, [Description] = 'Setup and change configurations'

						INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobStep] 
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter],
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
							)
						SELECT
							[Comment],
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter] = dbo.f_ConvertParameter([ParameterString], [ParameterList]),
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
						FROM
							(
							SELECT
								[Comment],
								[JobStepTypeBM],
								[DatabaseName],
								[StoredProcedure],
								[ParameterString] = TJS.[Parameter],
								[ParameterList] = '@SourceTypeID=' + CONVERT(NVARCHAR(15), @SourceTypeID) + '|@StorageTypeBM=' + CONVERT(NVARCHAR(15), @StorageTypeBM),
								[SortOrder],
								[JobFrequencyBM],
								[JobStepGroupBM],
								[ProcessBM],
								[JobSetupStepBM],
								[InheritedFrom] = TJS.[JobStepID],
								[SelectYN]
							FROM
								[pcINTEGRATOR].[dbo].[@Template_JobStep] TJS
							WHERE
								[InstanceID] = @SourceInstanceID AND
								[VersionID] = @SourceVersionID AND
								[JobStepTypeBM] & 1 > 0 AND
								[SelectYN] <> 0
							) sub
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobStep] DJS WHERE DJS.[InstanceID] = @InstanceID AND DJS.[VersionID] = @VersionID AND DJS.[InheritedFrom] = sub.[InheritedFrom])

						SET @Inserted = @Inserted + @@ROWCOUNT
					END
				
				IF @JobStepTypeBM & 2 > 0 --Preparation, Load and prepare different types of metadata from source tables that is needed for correct and efficient loading of base tables and transactions
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@JobStepTypeBM] = 2
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobStep] 
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter],
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
							)
						SELECT
							[Comment],
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter] = dbo.f_ConvertParameter([ParameterString], [ParameterList]),
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
						FROM
							(
							SELECT
								[Comment],
								[JobStepTypeBM],
								[DatabaseName],
								[StoredProcedure],
								[ParameterString] = TJS.[Parameter],
								[ParameterList] = '@SourceTypeID=' + CONVERT(NVARCHAR(15), @SourceTypeID) + '|@StorageTypeBM=' + CONVERT(NVARCHAR(15), @StorageTypeBM),
								[SortOrder],
								[JobFrequencyBM],
								[JobStepGroupBM],
								[ProcessBM],
								[JobSetupStepBM],
								[InheritedFrom] = TJS.[JobStepID],
								[SelectYN]
							FROM
								[pcINTEGRATOR].[dbo].[@Template_JobStep] TJS
							WHERE
								[InstanceID] = @SourceInstanceID AND
								[VersionID] = @SourceVersionID AND
								[JobStepTypeBM] & 2 > 0 AND
								[SelectYN] <> 0
							) sub
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobStep] DJS WHERE DJS.[InstanceID] = @InstanceID AND DJS.[VersionID] = @VersionID AND DJS.[InheritedFrom] = sub.[InheritedFrom])

						SET @Inserted = @Inserted + @@ROWCOUNT
					END

				IF @JobStepTypeBM & 4 > 0 --Dimensions, Load dimension data and hierarchies
					BEGIN
						SELECT
							D.[DimensionID],
							D.[DimensionName],
							D.[LoadSP],
							[ProcessBM] = 0,
							[#Dependencies] = 0,
							[DependencyPrio] = 0
						INTO
							#Dimension
						FROM
							pcINTEGRATOR_Data..[Dimension_StorageType] DST
							INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.[InstanceID] IN (0, DST.[InstanceID]) AND D.[DimensionID] = DST.[DimensionID] AND D.[SelectYN] <> 0 AND D.[DeletedID] IS NULL
						WHERE
							DST.[InstanceID] = @InstanceID AND
							DST.[VersionID] = @VersionID AND 
							DST.[StorageTypeBM] & 4 > 0

						IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension', * FROM #Dimension ORDER BY [DimensionID] DESC

						SELECT DISTINCT
							D.DimensionID,
							P.DependentDimensionID,
							DP.DependencyPrio
						INTO
							#Dependent
						FROM
							#Dimension D
							INNER JOIN Dimension_Property DP ON DP.[InstanceID] IN (0, @InstanceID) AND DP.[VersionID] IN (0, @VersionID) AND DP.[DimensionID] = D.[DimensionID]
							INNER JOIN Property P ON P.[InstanceID] IN (0, @InstanceID) AND P.[PropertyID] = DP.[PropertyID] AND P.[DependentDimensionID] IS NOT NULL AND P.[DependentDimensionID] <> D.[DimensionID]

						IF @DebugBM & 2 > 0 SELECT TempTable = '#Dependent', * FROM #Dependent ORDER BY [DimensionID] DESC, DependentDimensionID

						UPDATE Dim
						SET
							[#Dependencies] = Dep.[#Dependencies],
							[DependencyPrio] = Dep.[DependencyPrio]
						FROM
							#Dimension Dim
							INNER JOIN 
								(
								SELECT
									[DimensionID],
									[#Dependencies] = COUNT(DependentDimensionID),
									[DependencyPrio] = MAX([DependencyPrio])
								FROM
									#Dependent
								GROUP BY
									DimensionID
								) Dep ON Dep.DimensionID = Dim.DimensionID

						UPDATE Dim
						SET
							[ProcessBM] = sub.[ProcessBM]
						FROM
							#Dimension Dim
							INNER JOIN 
								(
								SELECT
									DimensionID,
									ProcessBM = SUM(ProcessBM)
								FROM
									(
									SELECT DISTINCT
										D.DimensionID,
										P.ProcessBM
									FROM 
										#Dimension D
										INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DimensionID = D.DimensionID
										INNER JOIN DataClass_Process DCP ON DCP.InstanceID = DCD.InstanceID AND DCP.VersionID = DCD.VersionID AND DCP.DataClassID = DCD.DataClassID
										INNER JOIN Process P ON P.InstanceID = DCD.InstanceID AND P.VersionID = DCD.VersionID AND P.ProcessID = DCP.ProcessID
									) sub
								GROUP BY
									DimensionID
								) sub ON sub.DimensionID = Dim.DimensionID

						IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension', * FROM #Dimension ORDER BY [DimensionID] DESC

						CREATE TABLE #DimLoad
							(
							SortOrder INT IDENTITY(10, 10),
							DimensionID INT
							)

						INSERT INTO #DimLoad
							([DimensionID])
						SELECT
							Dim.[DimensionID]
						FROM
							#Dimension Dim
						WHERE
							[#Dependencies] = 0
						ORDER BY
							Dim.[DimensionID] DESC

						IF @DebugBM & 2 > 0 SELECT TempTable = '#DimLoad', * FROM #DimLoad ORDER BY [DimensionID] DESC

						SELECT
							@SumRowCount = SUM([RowCount])
						FROM
							(
							SELECT
								[LoadRow] = CASE WHEN LoadSP IN ('Dimension_Generic', 'Dimension_Slave') THEN CONVERT(nvarchar(15), DimensionID) + '_' ELSE '' END + LoadSP,
								[RowCount] = MAX(CASE WHEN [DependencyPrio] = 0 THEN 1 ELSE [DependencyPrio] END)
							FROM
								#Dimension
							GROUP BY
								CASE WHEN LoadSP IN ('Dimension_Generic', 'Dimension_Slave') THEN CONVERT(nvarchar(15), DimensionID) + '_' ELSE '' END + LoadSP
							) sub

						IF @DebugBM & 2 > 0 SELECT [@SumRowCount] = @SumRowCount

						WHILE @SumRowCount - (SELECT COUNT(1) FROM #DimLoad) <> 0 AND (SELECT SUM([DependencyPrio]) FROM #Dimension) <> 0 AND @LoopCount < 15
							BEGIN
								SET @LoopCount = @LoopCount + 1
								INSERT INTO #DimLoad
									([DimensionID])
								SELECT
									Dim.[DimensionID]
								FROM
									#Dimension Dim
									INNER JOIN #Dependent Dep ON Dep.DimensionID = Dim.DimensionID
									INNER JOIN #DimLoad DL ON DL.DimensionID = Dep.DependentDimensionID
								WHERE
									NOT EXISTS (SELECT 1 FROM #DimLoad DDL WHERE DDL.DimensionID = Dim.[DimensionID])
								GROUP BY
									Dim.DimensionID
								HAVING
									COUNT(DL.DimensionID) = MAX(Dim.[#Dependencies])
								ORDER BY
									Dim.[DimensionID] DESC

								SET @Inserted = @@ROWCOUNT
								IF @Inserted = 0
									BEGIN
										INSERT INTO #DimLoad
											([DimensionID])
										SELECT
											Dim.[DimensionID]
										FROM
											#Dimension Dim
										WHERE
											DependencyPrio >= 2 AND
											NOT EXISTS (SELECT 1 FROM #DimLoad DDL WHERE DDL.DimensionID = Dim.[DimensionID])
									END
							END

						IF @DebugBM & 2 > 0 SELECT TempTable = '#DimLoad', * FROM #DimLoad ORDER BY [SortOrder]

						INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobStep]
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter],
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[SelectYN]
							)
						SELECT 
							[Comment] = sub.[Comment],
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[JobStepTypeBM] = 4,
							[DatabaseName] = 'pcINTEGRATOR',
							[StoredProcedure] = 'spIU_Dim_' + sub.[LoadSP] + CASE WHEN @StorageTypeBM & 4 > 0 THEN '_Callisto' ELSE '' END,
							[Parameter] = CASE WHEN sub.[DimensionID] = 0 OR sub.[DimensionID] % 100 = 99 THEN '' ELSE '@DimensionID=' + CONVERT(nvarchar(15), sub.[DimensionID]) END,
							[SortOrder] = sub.[SortOrder],
							[JobFrequencyBM] = ISNULL(TJS.[JobFrequencyBM], 13),
							[JobStepGroupBM] = ISNULL(TJS.[JobStepGroupBM], 3),
							[ProcessBM] = sub.[ProcessBM],
							[JobSetupStepBM] = 0,
							[SelectYN] = 1
						FROM
							(
							SELECT
								[Comment] = CASE Dim.[LoadSP] WHEN 'Time_Property' THEN 'Time Properties'  WHEN 'Segment' THEN 'Financial Segments' ELSE MAX(Dim.[DimensionName]) END,
								[LoadSP] = Dim.[LoadSP],
								[DimensionID] = CASE WHEN Dim.DimensionName = Dim.[LoadSP] OR Dim.[LoadSP] IN ('Time_Property', 'Segment') THEN CASE WHEN Dim.[DependencyPrio] >= 2 THEN DL.[SortOrder] * 1000 + 99 ELSE 0 END ELSE Dim.DimensionID END,
								[SortOrder] = MAX(CASE WHEN Dim.[DependencyPrio] >= 2 THEN DL.[SortOrder] ELSE DL.[SortOrder] END),
								[ProcessBM] = MAX(Dim.[ProcessBM])
							FROM
								#DimLoad DL
								INNER JOIN #Dimension Dim ON Dim.DimensionID = DL.DimensionID
							GROUP BY
								Dim.[LoadSP],
								CASE WHEN Dim.DimensionName = Dim.[LoadSP] OR Dim.[LoadSP] IN ('Time_Property', 'Segment') THEN CASE WHEN Dim.[DependencyPrio] >= 2 THEN DL.[SortOrder] * 1000 + 99 ELSE 0 END ELSE Dim.DimensionID END
							) sub
							LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_JobStep] TJS ON TJS.[InstanceID] = @SourceInstanceID AND TJS.[VersionID] = @SourceVersionID AND TJS.[JobStepTypeBM] & 4 > 0 AND TJS.[Comment] = sub.[Comment]
						WHERE
							NOT EXISTS 
								(
								SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobStep] JS WHERE
									JS.[InstanceID]= @InstanceID AND
									JS.[VersionID] = @VersionID AND
									JS.[JobStepTypeBM] = 4 AND
									JS.[DatabaseName] = 'pcINTEGRATOR' AND
									JS.[StoredProcedure] = 'spIU_Dim_' + sub.[LoadSP] + CASE WHEN @StorageTypeBM & 4 > 0 THEN '_Callisto' ELSE '' END AND
									JS.[Parameter] = CASE WHEN sub.[DimensionID] = 0 OR sub.[DimensionID] % 100 = 99 THEN '' ELSE '@DimensionID=' + CONVERT(nvarchar(15), sub.[DimensionID]) END
								)

						DROP TABLE #Dimension
						DROP TABLE #Dependent
						DROP TABLE #DimLoad
					END

				IF @JobStepTypeBM & 8 > 0 --Data, Load Journals and FACT tables
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@JobStepTypeBM] = 8
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobStep] 
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter],
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
							)
						SELECT
							[Comment],
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter] = dbo.f_ConvertParameter([ParameterString], [ParameterList]),
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
						FROM
							(
							SELECT
								[Comment],
								[JobStepTypeBM],
								[DatabaseName],
								[StoredProcedure],
								[ParameterString] = TJS.[Parameter],
								[ParameterList] = '@SourceTypeID=' + CONVERT(nvarchar(15), @SourceTypeID) + '|@StorageTypeBM=' + CONVERT(nvarchar(15), @StorageTypeBM),
								[SortOrder],
								[JobFrequencyBM],
								[JobStepGroupBM],
								[ProcessBM],
								[JobSetupStepBM],
								[InheritedFrom] = TJS.[JobStepID],
								[SelectYN]
							FROM
								[pcINTEGRATOR].[dbo].[@Template_JobStep] TJS
							WHERE
								[InstanceID] = @SourceInstanceID AND
								[VersionID] = @SourceVersionID AND
								[JobStepTypeBM] & 8 > 0 AND
								[SelectYN] <> 0
							) sub
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobStep] DJS WHERE DJS.[InstanceID] = @InstanceID AND DJS.[VersionID] = @VersionID AND DJS.[InheritedFrom] = sub.[InheritedFrom])

						SET @Inserted = @Inserted + @@ROWCOUNT

						IF @SourceTypeID = -20 AND @ProductOptionID IS NOT NULL
							BEGIN
								SELECT 
									@TemplateObjectID = ISNULL(@TemplateObjectID, TemplateObjectID)
								FROM 
									[pcINTEGRATOR].[dbo].[ProductOption] 
								WHERE 
									ProductOptionID = @ProductOptionID

								SELECT 
									@DataClassName = DataClassName 
								FROM 
									[pcINTEGRATOR_Data].[dbo].[DataClass] 
								WHERE 
									InstanceID = @InstanceID AND 
									VersionID = @VersionID AND 
									InheritedFrom = @TemplateObjectID AND 
									SelectYN <> 0

								IF @DebugBM & 2 > 0 SELECT [@TemplateObjectID] = @TemplateObjectID, [@DataClassName] = @DataClassName

								INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobStep] 
									(
									[Comment],
									[InstanceID],
									[VersionID],
									[JobStepTypeBM],
									[DatabaseName],
									[StoredProcedure],
									[Parameter],
									[SortOrder],
									[JobFrequencyBM],
									[JobStepGroupBM],
									[ProcessBM],
									[JobSetupStepBM],
									[InheritedFrom],
									[SelectYN]
									)
								SELECT
									[Comment],
									[InstanceID] = @InstanceID,
									[VersionID] = @VersionID,
									[JobStepTypeBM],
									[DatabaseName],
									[StoredProcedure],
									[Parameter] = dbo.f_ConvertParameter([ParameterString], [ParameterList]),
									[SortOrder],
									[JobFrequencyBM],
									[JobStepGroupBM],
									[ProcessBM],
									[JobSetupStepBM],
									[InheritedFrom],
									[SelectYN]
								FROM
									(
									SELECT
										[Comment],
										[JobStepTypeBM],
										[DatabaseName],
										[StoredProcedure],
										[ParameterString] = TJS.[Parameter],
										[ParameterList] = '@SourceTypeID=' + CONVERT(nvarchar(15), @SourceTypeID) + '|@StorageTypeBM=' + CONVERT(nvarchar(15), @StorageTypeBM),
										[SortOrder],
										[JobFrequencyBM],
										[JobStepGroupBM],
										[ProcessBM],
										[JobSetupStepBM],
										[InheritedFrom] = TJS.[JobStepID],
										[SelectYN]
									FROM
										[pcINTEGRATOR].[dbo].[@Template_JobStep] TJS
									WHERE
										[InstanceID] = @SourceTypeID AND
										[VersionID] = @SourceTypeID AND
										[StoredProcedure] = 'spIU_DC_' + @DataClassName + CASE WHEN @StorageTypeBM = 4 THEN '_Callisto' ELSE '' END AND
										[JobStepTypeBM] & 8 > 0 AND
										[SelectYN] <> 0
									) sub
								WHERE
									NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobStep] DJS WHERE DJS.[InstanceID] = @InstanceID AND DJS.[VersionID] = @VersionID AND DJS.[InheritedFrom] = sub.[InheritedFrom])

								SET @Inserted = @Inserted + @@ROWCOUNT
							END
					END

				IF @JobStepTypeBM & 16 > 0 --Calculations, Run configured Business Rules
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@JobStepTypeBM] = 16
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobStep] 
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter],
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
							)
						SELECT
							[Comment],
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter] = dbo.f_ConvertParameter([ParameterString], [ParameterList]),
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
						FROM
							(
							SELECT
								[Comment],
								[JobStepTypeBM],
								[DatabaseName],
								[StoredProcedure],
								[ParameterString] = TJS.[Parameter],
								[ParameterList] = '@SourceTypeID=' + CONVERT(nvarchar(15), @SourceTypeID) + '|@StorageTypeBM=' + CONVERT(nvarchar(15), @StorageTypeBM),
								[SortOrder],
								[JobFrequencyBM],
								[JobStepGroupBM],
								[ProcessBM],
								[JobSetupStepBM],
								[InheritedFrom] = TJS.[JobStepID],
								[SelectYN]
							FROM
								[pcINTEGRATOR].[dbo].[@Template_JobStep] TJS
							WHERE
								[InstanceID] = @SourceInstanceID AND
								[VersionID] = @SourceVersionID AND
								[JobStepTypeBM] & 16 > 0 AND
								[SelectYN] <> 0
							) sub
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobStep] DJS WHERE DJS.[InstanceID] = @InstanceID AND DJS.[VersionID] = @VersionID AND DJS.[InheritedFrom] = sub.[InheritedFrom])

						SET @Inserted = @Inserted + @@ROWCOUNT
					END

				IF @JobStepTypeBM & 32 > 0 --Other, Other Business Rules that has to be run after the initial calculations
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@JobStepTypeBM] = 32
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobStep] 
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter],
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
							)
						SELECT
							[Comment],
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter] = dbo.f_ConvertParameter([ParameterString], [ParameterList]),
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
						FROM
							(
							SELECT
								[Comment],
								[JobStepTypeBM],
								[DatabaseName],
								[StoredProcedure],
								[ParameterString] = TJS.[Parameter],
								[ParameterList] = '@SourceTypeID=' + CONVERT(nvarchar(15), @SourceTypeID) + '|@StorageTypeBM=' + CONVERT(nvarchar(15), @StorageTypeBM),
								[SortOrder],
								[JobFrequencyBM],
								[JobStepGroupBM],
								[ProcessBM],
								[JobSetupStepBM],
								[InheritedFrom] = TJS.[JobStepID],
								[SelectYN]
							FROM
								[pcINTEGRATOR].[dbo].[@Template_JobStep] TJS
							WHERE
								[InstanceID] = @SourceInstanceID AND
								[VersionID] = @SourceVersionID AND
								[JobStepTypeBM] & 32 > 0 AND
								[SelectYN] <> 0
							) sub
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobStep] DJS WHERE DJS.[InstanceID] = @InstanceID AND DJS.[VersionID] = @VersionID AND DJS.[InheritedFrom] = sub.[InheritedFrom])

						SET @Inserted = @Inserted + @@ROWCOUNT
					END

				IF @JobStepTypeBM & 64 > 0 --CheckSums, Quality checks, calculated and distributed 
					BEGIN
						IF @DebugBM & 2 > 0 SELECT [@JobStepTypeBM] = 64
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobStep] 
							(
							[Comment],
							[InstanceID],
							[VersionID],
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter],
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
							)
						SELECT
							[Comment],
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[JobStepTypeBM],
							[DatabaseName],
							[StoredProcedure],
							[Parameter] = dbo.f_ConvertParameter([ParameterString], [ParameterList]),
							[SortOrder],
							[JobFrequencyBM],
							[JobStepGroupBM],
							[ProcessBM],
							[JobSetupStepBM],
							[InheritedFrom],
							[SelectYN]
						FROM
							(
							SELECT
								[Comment],
								[JobStepTypeBM],
								[DatabaseName],
								[StoredProcedure],
								[ParameterString] = TJS.[Parameter],
								[ParameterList] = '@SourceTypeID=' + CONVERT(nvarchar(15), @SourceTypeID) + '|@StorageTypeBM=' + CONVERT(nvarchar(15), @StorageTypeBM),
								[SortOrder],
								[JobFrequencyBM],
								[JobStepGroupBM],
								[ProcessBM],
								[JobSetupStepBM],
								[InheritedFrom] = TJS.[JobStepID],
								[SelectYN]
							FROM
								[pcINTEGRATOR].[dbo].[@Template_JobStep] TJS
							WHERE
								[InstanceID] = @SourceInstanceID AND
								[VersionID] = @SourceVersionID AND
								[JobStepTypeBM] & 64 > 0 AND
								[SelectYN] <> 0
							) sub
						WHERE
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobStep] DJS WHERE DJS.[InstanceID] = @InstanceID AND DJS.[VersionID] = @VersionID AND DJS.[InheritedFrom] = sub.[InheritedFrom])

						SET @Inserted = @Inserted + @@ROWCOUNT
					END
			END

	SET @Step = 'Return rows, @DebugBM & 1 > 0'
		IF @DebugBM & 1 > 0
			BEGIN
				IF @SequenceBM & 1 > 0 SELECT [Table] = '[pcINTEGRATOR_Data].[dbo].[JobList]', * FROM [pcINTEGRATOR_Data].[dbo].[JobList] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID ORDER BY JobStepGroupBM
				IF @SequenceBM & 2 > 0 SELECT [Table] = '[pcINTEGRATOR_Data].[dbo].[JobStep]', * FROM [pcINTEGRATOR_Data].[dbo].[JobStep] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [JobStepTypeBM] & @JobStepTypeBM > 0 ORDER BY JobStepTypeBM, SortOrder
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
