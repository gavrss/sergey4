SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spPortalAdminPublish_DataClass]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataOriginID int = NULL,
	@DataClassID int = NULL,
	@DataClassName nvarchar(50) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000925,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminPublish_DataClass',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "-1329"},
		{"TKey" : "VersionID",  "TValue": "-1267"},
		{"TKey" : "DataOriginID",  "TValue": "1022"},
		]'

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminPublish_DataClass',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "-1329"},
		{"TKey" : "VersionID",  "TValue": "-1267"},
		{"TKey" : "DataOriginID",  "TValue": "1022"},
		{"TKey" : "DebugBM",  "TValue": "2"},
		]'

EXEC [spPortalAdminPublish_DataClass] @UserID=-10, @InstanceID=-1329, @VersionID=-1267, @Debug=1

EXEC [spPortalAdminPublish_DataClass] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataOriginName nvarchar(50),
	@DataClassDescription nvarchar(50),
	@DataClassTypeID int = -12,
	@DimensionID int,
	@DimensionName nvarchar(50),
	@DimensionDescription nvarchar(50),
	@MeasureName nvarchar(50), 
	@MeasureDescription nvarchar(50),
	@ProcessID int,
	@ProcessName nvarchar(50) = 'BAQ',
	@ProcessBM nvarchar(50) = '32768',
	@PropertyID int,
	@PropertyName nvarchar(50),
	@PropertyDescription nvarchar(50),
	@JSON_table nvarchar(MAX),

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
	@CreatedBy nvarchar(50) = 'OsVe',
	@ModifiedBy nvarchar(50) = 'AlGa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Read from DataOrigin and DataOriginColumn and Insert or Update in DataClass, Dimension, Measure and Property',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Insert or Update DataClass'
		-- POPULATE DATACLASSID FROM DATAORIGIN WHEN AVAILABLE, POPULATE DATAORIGINNAME
		SELECT @DataClassID = COALESCE(@DataClassID,DataClassID), @DataClassTypeID=DataClassTypeID,  @DataOriginName=DataOriginName
		FROM [pcIntegrator_Data].[dbo].[DataOrigin] 
		WHERE DataOriginID = @DataOriginID
			AND InstanceID=@InstanceID
			AND VersionID=@VersionID
			AND DeletedID IS NULL
		
		-- POPULATE DATACLASSNAME AND DESCRIPTION FROM DATACLASS WHEN AVAILABLE
		SELECT @DataClassName = COALESCE(@DataClassName,DataClassName),@DataClassDescription = COALESCE(DataClassDescription,@DataClassName,DataClassName) 
		FROM [pcIntegrator].[dbo].[DataClass] 
		WHERE DataClassID = @DataClassID
			AND InstanceID=@InstanceID
			AND VersionID=@VersionID
			AND DataClassTypeID = @DataClassTypeID
			AND DeletedID IS NULL
		
		IF @DataClassName IS NULL
			SET @DataClassName = @DataOriginName

		IF @DataClassDescription IS NULL 
			SET @DataClassDescription = @DataClassName
		
		IF @DebugBM & 2 > 0 SELECT @DataOriginID DataOriginID, @DataOriginName DataOriginName, @DataClassID DataClassID, @DataClassName DataClassName, @DataClassDescription DataClassDescription

		--Fill JSON and execute sp
		SET @JSON_table = (
			SELECT 
				'4' AS ResultTypeBM, 
				@DataClassID AS DataClassID,
				@DataClassName AS DataClassName,
				@DataClassDescription AS DataClassDescription,
				@DataClassTypeID AS DataClassTypeID 
			FOR JSON PATH
			)
		
		IF @DebugBM & 2 > 0 SELECT @JSON_table 
		EXEC [pcIntegrator].[dbo].[spPortalAdminSet_DataClass] @UserID = @UserID,@InstanceID = @InstanceID,@VersionID = @VersionID,@JSON_table = @JSON_table,@Debug = @DebugSub
			
	SET @Step = 'Link DataClass to DataOrigin'
		--Assign DataClassID to DataOrigin after created DataClass is created
		SELECT 
			@DataClassID=DataClassID 
		FROM 
			[pcIntegrator].[dbo].[DataClass] 
		WHERE
			InstanceID = @InstanceID 
			AND VersionID=@VersionID
			AND DataClassName = @DataClassName
			AND DeletedID IS NULL

		IF (SELECT DataClassID FROM [pcIntegrator_Data].[dbo].[DataOrigin] WHERE DataOriginID = @DataOriginID AND InstanceID=@InstanceID AND VersionID=@VersionID AND DeletedID IS NULL) IS NULL
		BEGIN
			--Fill JSON and execute sp
			SET @JSON_table = (
				SELECT 
					'1' AS ResultTypeBM,
					@DataOriginID AS DataOriginID,
					@DataClassID AS DataClassID
				FOR JSON PATH
				)

			IF @DebugBM & 2 > 0 SELECT @JSON_table  
			EXEC [pcIntegrator].[dbo].[spPortalAdminSet_DataClass] @UserID = @UserID,@InstanceID = @InstanceID,@VersionID = @VersionID,@JSON_table = @JSON_table,@Debug = @DebugSub
		END

	SET @Step = 'Create default BAQ Process if it does not exist'
	
	IF NOT EXISTS (SELECT 1 FROM [pcIntegrator_Data].[dbo].[Process] WHERE InstanceID=@InstanceID AND VersionID=@VersionID AND ProcessName = @ProcessName AND DeletedID IS NULL)
		BEGIN
			--Fill JSON and execute sp
			SET @JSON_table = (
					SELECT 
						'64' AS ResultTypeBM,
						@ProcessBM AS ProcessBM,
						@ProcessName AS ProcessName,
						@ProcessName AS ProcessDescription
					FOR JSON PATH
					)
		
			IF @DebugBM & 2 > 0 SELECT @JSON_table 
			EXEC [pcIntegrator].[dbo].[spPortalAdminSet_DataClass] @UserID = @UserID,@InstanceID = @InstanceID,@VersionID = @VersionID,@JSON_table = @JSON_table,@Debug = @DebugSub

		END

	SET @Step = 'Create DataClass_Process'
		--Create DataClass_Process with ProcessID
		SELECT 
			@ProcessID=ProcessID 
		FROM 
			[pcIntegrator].[dbo].[Process] 
		WHERE
			InstanceID = @InstanceID
			AND VersionID=@VersionID
			AND ProcessName = @ProcessName
			AND DeletedID IS NULL

		--Fill JSON and execute sp
		SET @JSON_table = (
			SELECT 
				'68' AS ResultTypeBM,
				@DataClassID AS DataClassID,
				@ProcessID AS ProcessID
			FOR JSON PATH
			)

		IF @DebugBM & 2 > 0 SELECT @JSON_table  
		EXEC [pcIntegrator].[dbo].[spPortalAdminSet_DataClass] @UserID = @UserID,@InstanceID = @InstanceID,@VersionID = @VersionID,@JSON_table = @JSON_table,@Debug = @DebugSub

	SET @Step = 'Create Temp Table #JSONFillTable'
		CREATE TABLE #JSONFillTable
			(
			[ResultTypeBM] [int],
			[DataClassID] [int],
			[DimensionID] [int],
			[DimensionName] [nvarchar](50),
			[DimensionDescription] [nvarchar](255),
			[MeasureName] [nvarchar](50),
			[MeasureDescription] [nvarchar](50),
			[ProcessID] [int],
			[PropertyID] [int],
			[PropertyName] [nvarchar](50),
			[PropertyDescription] [nvarchar](50),
			[Comment] [nvarchar](1024)
			)

	SET @Step = 'Insert into #JSONFillTable for Dimension and DataClass_Dimension (ColumnTypeID 1 and 2)'

		IF CURSOR_STATUS('local','Dimensions_Cursor') >= -1 DEALLOCATE Dimensions_Cursor
		DECLARE Dimensions_Cursor CURSOR FOR
			
			SELECT 
				--DestinationName,PropertyType
					DestinationName,
					PropertyType = CASE WHEN DOC.ColumnTypeID=4 THEN 'Generic' ELSE PropertyType END 
			FROM 
				[pcIntegrator_Data].[dbo].[DataOriginColumn] DOC
			WHERE 
				DOC.InstanceID in (@InstanceID,0) AND
				DOC.VersionID=@VersionID AND
				DOC.DataOriginID=@DataOriginID AND 
				DOC.ColumnTypeID IN (1,2,4) AND
				ISNULL(DOC.DestinationName,'') <> '' AND
				DeletedID IS NULL

			OPEN Dimensions_Cursor
			FETCH NEXT FROM Dimensions_Cursor INTO @DimensionName,@PropertyName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					-- Fill Dimension info
					SELECT 
						@DimensionID=DimensionID,
						@DimensionDescription=DimensionDescription
					FROM 
						[pcIntegrator].[dbo].[Dimension] 
					WHERE 
						InstanceID IN (@InstanceID,0) 
						AND DimensionName = @DimensionName
						AND DeletedID IS NULL
					
					IF @DimensionDescription IS NULL 
						SET @DimensionDescription = @DimensionName
					
					-- Fill Property info
					SELECT
						@PropertyID = PropertyID,
						@PropertyDescription = PropertyDescription
					FROM
						[pcIntegrator].[dbo].[Property]
					WHERE
						InstanceID IN (@InstanceID,0) 
						AND PropertyName = @PropertyName
						AND SelectYN = 1
					
					-- ResultTypeBM 8: Dimension
					INSERT INTO #JSONFillTable
					(
						ResultTypeBM,
						DimensionID,
						DimensionName,
						DimensionDescription
					)
					SELECT 
						'8' AS ResultTypeBM,
						@DimensionID AS DimensionName,
						@DimensionName AS DimensionName,
						@DimensionDescription AS DimensionDescription

					-- ResultTypeBM 12: DataClassDimension
					INSERT INTO #JSONFillTable
					(
						ResultTypeBM,
						DimensionID,
						DataClassID
					)
					SELECT 
						'12' AS ResultTypeBM,
						@DimensionID AS DimensionID,
						@DataClassID AS DataClassID

					IF @PropertyName IS NOT NULL AND @PropertyName NOT IN (SELECT PropertyName FROM pcIntegrator..Property WHERE InstanceID = 0 AND PropertyID >=0)
						BEGIN
							IF @DebugBM & 2 > 0 SELECT @PropertyName,@PropertyID,@PropertyDescription

							-- ResultTypeBM 16: Property
							INSERT INTO #JSONFillTable
							(
								ResultTypeBM,
								PropertyID,
								PropertyName,
								PropertyDescription
							)
							SELECT 
								'16' AS ResultTypeBM,
								@PropertyID AS PropertyID,
								@PropertyName AS PropertyName,
								@PropertyDescription AS PropertyDescription

							-- ResultTypeBM 24: Dimension_Property
							INSERT INTO #JSONFillTable
							(
								ResultTypeBM,
								PropertyID,
								DimensionID,
								Comment
							)
							SELECT 
								'24' AS ResultTypeBM,
								@PropertyID AS PropertyID,
								@DimensionID AS DimensionID,
								@DimensionName+', '+@PropertyName AS Comment
							WHERE @DimensionID >0
						END
					

					FETCH NEXT FROM Dimensions_Cursor INTO @DimensionName,@PropertyName
				END

		CLOSE Dimensions_Cursor
		DEALLOCATE Dimensions_Cursor

	SET @Step = 'Insert into #JSONFillTable for Measure (ColumnTypeID 3)'

		IF CURSOR_STATUS('local','Measures_Cursor') >= -1 DEALLOCATE Measures_Cursor

		DECLARE Measures_Cursor CURSOR FOR
			SELECT 
				DestinationName 
			FROM 
				[pcIntegrator_Data].[dbo].[DataOriginColumn] DOC
			WHERE 
				DOC.InstanceID=@InstanceID AND
				DOC.VersionID=@VersionID AND
				DOC.DataOriginID=@DataOriginID AND 
				DOC.ColumnTypeID = 3 AND
				ISNULL(DOC.DestinationName,'') <> '' AND
				DeletedID IS NULL

		OPEN Measures_Cursor 
			FETCH NEXT FROM Measures_Cursor INTO @MeasureName
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @MeasureDescription = @MeasureName

				INSERT INTO #JSONFillTable
				(
						ResultTypeBM,
						MeasureName,
						MeasureDescription,
						DataClassID
					)
				SELECT 
					'32' AS ResultTypeBM,
					@MeasureName AS MeasureName,
					@MeasureDescription AS MeasureDescription,
					@DataClassID AS DataClassID

				FETCH NEXT FROM Measures_Cursor INTO @MeasureName
			END

		CLOSE Measures_Cursor 
		DEALLOCATE Measures_Cursor 

	SET @Step = 'Call spPortalAdminSet_DataClass for all Dimensions, DataClass_Dimensions, Measures, Properties, Dimension_Properties'

		IF @DebugBM & 2 > 0 SELECT DISTINCT '#JSONFillTable' AS JSONFillTable,* FROM #JSONFillTable 


		SET @JSON_table = (
			SELECT DISTINCT *
			FROM #JSONFillTable A
			FOR JSON AUTO
		)

		IF @DebugBM & 2 > 0 SELECT @JSON_table
		EXEC [pcIntegrator].[dbo].[spPortalAdminSet_DataClass] @UserID = @UserID,@InstanceID = @InstanceID,@VersionID = @VersionID,@JSON_table = @JSON_table,@Debug = @DebugSub
		
	SET @Step = 'Add new members'
	IF @DebugBM & 2 > 0 SELECT 'Executing spIU_Dim_Dimension_Generic_Callisto new members'
	--EXEC [pcIntegrator].[dbo].[spPortalAdminCreate_NewDataClass] @UserID = @UserID,@InstanceID = @InstanceID,@VersionID = @VersionID, @DataOriginID = @DataOriginID, @Debug = @DebugSub, @SequenceBM=1

	IF CURSOR_STATUS('local','Dimensions_Cursor') >= -1 DEALLOCATE Dimensions_Cursor
		DECLARE Dimensions_Cursor CURSOR FOR
			
			SELECT DISTINCT 
				DestinationName
			FROM 
				[pcIntegrator_Data].[dbo].[DataOriginColumn] DOC
			WHERE 
				DOC.InstanceID in (@InstanceID,0) AND
				DOC.VersionID=@VersionID AND
				DOC.DataOriginID=@DataOriginID AND 
				DOC.ColumnTypeID IN (1) AND
				ISNULL(DOC.DestinationName,'') <> '' AND
				AutoAddYN=1 AND
				DeletedID IS NULL

			OPEN Dimensions_Cursor
			FETCH NEXT FROM Dimensions_Cursor INTO @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN

					IF @DebugBM & 2 > 0 SELECT @DimensionName as '@DimensionName'

					-- Fill Dimension info
					SELECT 
						@DimensionID=DimensionID,
						@DimensionDescription=DimensionDescription
					FROM 
						[pcIntegrator].[dbo].[Dimension] 
					WHERE 
						InstanceID IN (@InstanceID,0) 
						AND DimensionName = @DimensionName
						AND DeletedID IS NULL

						IF @DebugBM & 2 > 0 SELECT 
							[@DimensionID]=@DimensionID,
							[@InstanceID]=@InstanceID,							
							[@UserID]=@UserID,
							[@VersionID]=@VersionID,
							[@SourceTypeID]='20',
							[@Debug]=@DebugSub

					
						EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_Dimension_Generic_Callisto] 
							@DimensionID=@DimensionID,
							@InstanceID=@InstanceID,							
							@UserID=@UserID,
							@VersionID=@VersionID,
							@SourceTypeID=20,
							@Debug=@DebugSub

					FETCH NEXT FROM Dimensions_Cursor INTO @DimensionName
				END

		CLOSE Dimensions_Cursor
		DEALLOCATE Dimensions_Cursor

	SET @Step = 'Execute sp to Create View'
		IF @DebugBM & 2 > 0 SELECT 'Executing sp_PortalAdminCreate_NewDataClass'
		EXEC [pcIntegrator].[dbo].[spPortalAdminCreate_NewDataClass] @UserID = @UserID,@InstanceID = @InstanceID,@VersionID = @VersionID, @DataOriginID = @DataOriginID, @Debug = @DebugSub, @SequenceBM=1


	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
