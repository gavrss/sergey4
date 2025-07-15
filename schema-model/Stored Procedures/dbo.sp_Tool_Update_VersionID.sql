SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Update_VersionID]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@pcINTEGRATOR_Data_Destination nvarchar(100) = 'pcINTEGRATOR_Data',
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000610,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'sp_Tool_Update_VersionID',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [sp_Tool_Update_VersionID] @pcINTEGRATOR_Data_Destination = 'pcINTEGRATOR_Data', @Debug=1

EXEC [sp_Tool_Update_VersionID] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	@SQLStatement nvarchar(max),

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Updates VersionID column',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Additional tables to update.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added [OrganizationPosition_DataClass].'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		SELECT 
			@UserID = ISNULL(@UserID, -10),
			@InstanceID = ISNULL(@InstanceID, 0),
			@VersionID = ISNULL(@VersionID, 0)

	SET @Step = 'Create and Insert data into temp table #Version'
		CREATE TABLE #Version
			(
			InstanceID INT,
			VersionID INT
			)

		INSERT INTO #Version
		(
		InstanceID,
		VersionID
		)
		SELECT
			V.InstanceID,
			VersionID = MAX(V.VersionID)
		FROM 
			[pcINTEGRATOR_Data].[dbo].[Version] V
			INNER JOIN (
				SELECT 
					InstanceID,
					EnvironmentLevelID = MAX(EnvironmentLevelID)
				FROM 
					[pcINTEGRATOR_Data].[dbo].[Version]
				WHERE 
					SelectYN <> 0
				GROUP BY
					InstanceID
			) sub ON sub.InstanceID = V.InstanceID
		WHERE
			V.SelectYN <> 0
		GROUP BY
			V.InstanceID
	
		INSERT INTO #Version
		(
		InstanceID,
		VersionID
		)
		SELECT
			V.InstanceID,
			VersionID = MAX(V.VersionID)
		FROM 
			[pcINTEGRATOR_Data].[dbo].[Version] V
			INNER JOIN (
				SELECT 
					InstanceID,
					EnvironmentLevelID = MAX(EnvironmentLevelID)
				FROM 
					[pcINTEGRATOR_Data].[dbo].[Version]
				GROUP BY
					InstanceID
			) sub ON sub.InstanceID = V.InstanceID
		WHERE 
			NOT EXISTS (SELECT 1 FROM #Version TV WHERE TV.InstanceID = V.InstanceID)
		GROUP BY
			V.InstanceID

		IF @Debug <> 0 SELECT [TempTable] = '#Version', * FROM #Version

	SET @Step = 'UPDATE VersionID column'
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Assignment_OrganizationLevel] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Assignment] A ON A.[AssignmentID] = B.[AssignmentID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[AssignmentRow] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Assignment] A ON A.[AssignmentID] = B.[AssignmentID]'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationPositionRow] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationPosition] A ON A.[OrganizationPositionID] = B.[OrganizationPositionID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Workflow_OrganizationLevel] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Workflow] A ON A.[WorkflowID] = B.[WorkflowID]'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[WorkflowRow] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Workflow] A ON A.[WorkflowID] = B.[WorkflowID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationLevel] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationHierarchy] A ON A.[OrganizationHierarchyID] = B.[OrganizationHierarchyID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[WorkflowAccessRight] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Workflow] A ON A.[WorkflowID] = B.[WorkflowID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[WorkflowStateChange] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Workflow] A ON A.[WorkflowID] = B.[WorkflowID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationHierarchy_Process] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationHierarchy] A ON A.[OrganizationHierarchyID] = B.[OrganizationHierarchyID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
							
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[EntityPropertyValue] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Entity] A ON A.[EntityID] = B.[EntityID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Entity_Book] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Entity] A ON A.[EntityID] = B.[EntityID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Entity_FiscalYear] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Entity] A ON A.[EntityID] = B.[EntityID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Workflow_LiveFcstNextFlow] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Workflow] A ON A.[WorkflowID] = B.[WorkflowID]'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[WorkflowState] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Workflow] A ON A.[WorkflowID] = B.[WorkflowID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Journal_SegmentNo] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Entity] A ON A.[EntityID] = B.[EntityID]'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[EntityHierarchy] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Entity] A ON A.[EntityID] = B.[EntityID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationPosition_DimensionMember] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationPosition] A ON A.[OrganizationPositionID] = B.[OrganizationPositionID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationPosition_DataClass] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationPosition] A ON A.[OrganizationPositionID] = B.[OrganizationPositionID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)
				
		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationPosition_User] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[OrganizationPosition] A ON A.[OrganizationPositionID] = B.[OrganizationPositionID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Extension] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Application] A ON A.[InstanceID] = B.[InstanceID] AND A.[ApplicationID] = B.[ApplicationID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[MailMessage] B
				INNER JOIN #Version A ON A.[InstanceID] = B.[InstanceID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Dimension_Property] B
				INNER JOIN #Version A ON A.[InstanceID] = B.[InstanceID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[JobStep] B
				INNER JOIN #Version A ON A.[InstanceID] = B.[InstanceID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[JobStepGroup] B
				INNER JOIN #Version A ON A.[InstanceID] = B.[InstanceID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[JobList] B
				INNER JOIN #Version A ON A.[InstanceID] = B.[InstanceID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Grid] B
				INNER JOIN #Version A ON A.[InstanceID] = B.[InstanceID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Grid_Dimension] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Grid] A ON A.[InstanceID] = B.[InstanceID] AND A.[GridID] = B.[GridID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[DimensionHierarchy] B
				INNER JOIN #Version A ON A.[InstanceID] = B.[InstanceID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[DimensionHierarchyLevel] B
				INNER JOIN ' + @pcINTEGRATOR_Data_Destination + '.[dbo].[DimensionHierarchy] A ON A.[InstanceID] = B.[InstanceID] AND A.[DimensionID] = B.[DimensionID] AND A.[HierarchyNo] = B.[HierarchyNo]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Dimension_StorageType] B
				INNER JOIN #Version A ON A.[InstanceID] = B.[InstanceID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE B 
			SET 
				[VersionID] = A.[VersionID]
			FROM
				' + @pcINTEGRATOR_Data_Destination + '.[dbo].[Process] B
				INNER JOIN #Version A ON A.[InstanceID] = B.[InstanceID]
			WHERE
				B.VersionID = 0 OR
				B.VersionID IS NULL'
		EXEC (@SQLStatement)	

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
		UPDATE J
		SET
			EndTime = GetDate(),
			ClosedYN = 1
		FROM
			[pcINTEGRATOR_Log].[dbo].[Job] J
		WHERE
			JobID = @JobID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage

		UPDATE J
		SET
			EndTime = GetDate(),
			ErrorTime = GetDate(),
			ClosedYN = 1
		FROM
			[pcINTEGRATOR_Log].[dbo].[Job] J
		WHERE
			JobID = @JobID

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
