SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_ExtraHierarchy_Member]

	@ApplicationID int = NULL,
	@Debug bit = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--EXEC [spInsert_ExtraHierarchy_Member] @ApplicationID = 400, @Debug = true
--EXEC [spInsert_ExtraHierarchy_Member] @GetVersion = 1

--#WITH ENCRYPTION#--
AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@InstanceID int,
	@ETLDatabase nvarchar(50),
	@DestinationDatabase nvarchar(100),
	@Dimension nvarchar(100),
	@Hierarchy nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2095'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2074' SET @Description = 'Procedure created.'
		IF @Version = '1.3.2095' SET @Description = 'MandatoryYN replaced by VisibilityLevelBM.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID must be set'
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
			@InstanceID = A.InstanceID,
			@ETLDatabase = A.ETLDatabase,
			@DestinationDatabase = A.DestinationDatabase
		FROM
			[Application] A 
		WHERE
			 A.ApplicationID = @ApplicationID

		SET @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Create Temptable'
		CREATE TABLE #ExtraHierarchy
			(
			[Dimension] nvarchar(100),
			[Hierarchy] nvarchar(100)
			)

		SET @SQLStatement = '
			INSERT INTO #ExtraHierarchy
				(
				[Dimension],
				[Hierarchy]
				)
			SELECT DISTINCT
				[Dimension] = MO.MappedObjectName,
				[Hierarchy] = ISNULL(MOH.MappedObjectName, D.Hierarchy)
			FROM
				Model M  
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
				INNER JOIN Model_Dimension MD ON MD.ModelID = M.BaseModelID AND MD.VisibilityLevelBM & 9 > 0
				INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.Hierarchy IS NOT NULL AND D.SelectYN <> 0
				INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.Entity = ''-1'' AND (MO.ObjectName = D.DimensionName AND MO.DimensionTypeID <> -1) AND (MO.SelectYN <> 0 OR MD.VisibilityLevelBM & 8 > 0)
				INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
				LEFT JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MOH ON MOH.Entity = ''-1'' AND (MOH.ObjectName = D.Hierarchy AND MOH.DimensionTypeID <> -1) AND MOH.SelectYN <> 0
			WHERE
				M.SelectYN <> 0'

		EXEC (@SQLStatement)

	SET @Step = 'Create cursor'
		DECLARE ExtraHierarchy_Cursor CURSOR FOR

			SELECT
				[Dimension],
				[Hierarchy]
			FROM
				#ExtraHierarchy

			OPEN ExtraHierarchy_Cursor
			FETCH NEXT FROM ExtraHierarchy_Cursor INTO @Dimension, @Hierarchy

			WHILE @@FETCH_STATUS = 0
				BEGIN
					--Insert into hierarchy table
						SET @SQLStatement = '		
							INSERT INTO [' + @DestinationDatabase + '].[dbo].[S_HS_' + @Dimension + '_' + @Hierarchy + ']
								(
								[MemberId],
								[ParentMemberId],
								[SequenceNumber]
								)
							SELECT
								[MemberId] = D1.MemberId,
								[ParentMemberId] = ISNULL(D2.MemberId, 0),
								[SequenceNumber] = D1.MemberId  
							FROM
								[' + @DestinationDatabase + '].[dbo].[S_DS_' + @Dimension + '] D1
								LEFT JOIN [' + @DestinationDatabase + '].[dbo].[S_DS_' + @Dimension + '] D2 ON D2.Label = ''All_'' AND D1.Label = ''NONE''
							WHERE
								D1.Label IN (''All_'', ''NONE'') AND
								NOT EXISTS (SELECT 1 FROM [' + @DestinationDatabase + '].[dbo].[S_HS_' + @Dimension + '_' + @Hierarchy + '] H WHERE H.MemberId = D1.MemberId)
							ORDER BY
								D1.Label'

						EXEC (@SQLStatement)
						SET @Inserted = @Inserted + @@ROWCOUNT

					--Copy the hierarchy to all instances
						SET @SQLStatement = '
							EXEC ' + @ETLDatabase + '..spSet_HierarchyCopy @Database = ''' + @DestinationDatabase + ''', @Dimensionhierarchy = ''' + @Dimension + '_' + @Hierarchy + ''''

						EXEC (@SQLStatement)	
					FETCH NEXT FROM ExtraHierarchy_Cursor INTO @Dimension, @Hierarchy
				END

		CLOSE ExtraHierarchy_Cursor
		DEALLOCATE ExtraHierarchy_Cursor	

	SET @Step = 'Drop temp tables'
		DROP TABLE #ExtraHierarchy

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
