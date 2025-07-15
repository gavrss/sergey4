SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Update_ToGenericDimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000622,
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
EXEC [sp_Tool_Update_ToGenericDimension] @Debug=1

EXEC [sp_Tool_Update_ToGenericDimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@Par1 int,
	@Par2 int,

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
	@Version nvarchar(50) = '2.1.0.2158'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update old Instance specific Dimensions to generic when they have become standard.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2158' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		EXEC [spGet_Version] @Version = @Version OUT

	SET @Step = 'Create temptable #Dimension'
		SELECT
			DD.InstanceID,
			DD.DimensionID,
			DD.DimensionName,
			[GenericDimensionID] = TD.DimensionID
		INTO
			#Dimension
		FROM
			pcINTEGRATOR_Data..Dimension DD
			INNER JOIN pcINTEGRATOR..[@Template_Dimension] TD ON TD.DimensionName = DD.DimensionName AND TD.SelectYN <> 0 AND TD.Introduced <= @Version
		WHERE
			DD.SelectYN <> 0 AND
			DD.Introduced <= @Version
		ORDER BY
			GenericDimensionID,
			InstanceID

		SET @Selected = @Selected + @@ROWCOUNT

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension', * FROM #Dimension ORDER BY GenericDimensionID, InstanceID

	SET @Step = 'Create temptable #Property'
		SELECT
			DP.InstanceID,
			DP.PropertyID,
			DP.PropertyName,
			[GenericPropertyID] = TP.PropertyID
		INTO
			#Property
		FROM
			pcINTEGRATOR_Data..Property DP
			INNER JOIN pcINTEGRATOR..[@Template_Property] TP ON TP.PropertyName = DP.PropertyName AND TP.SelectYN <> 0 AND TP.Introduced <= @Version
		WHERE
			DP.SelectYN <> 0 AND
			DP.Introduced <= @Version
		ORDER BY
			GenericPropertyID,
			InstanceID

		SET @Selected = @Selected + @@ROWCOUNT

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Property', * FROM #Property ORDER BY [GenericPropertyID], InstanceID
	
	SET @Step = 'Update Dimension_Property'
		UPDATE DP
		SET
			PropertyID = P.[GenericPropertyID]
		FROM
			pcINTEGRATOR_Data..Dimension_Property DP
			INNER JOIN #Property P ON P.PropertyID = DP.PropertyID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Dimension_Property DDP WHERE DDP.DimensionID = DP.[DimensionID] AND DDP.PropertyID = P.[GenericPropertyID])

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update Dimension_StorageType'
		UPDATE DST
		SET
			DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..Dimension_StorageType DST
			INNER JOIN #Dimension D ON D.DimensionID = DST.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Dimension_StorageType DDST WHERE DDST.InstanceID = DST.InstanceID AND DDST.VersionID = DST.VersionID AND DDST.DimensionID = D.[GenericDimensionID])

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update DataClass_Dimension'
		UPDATE DCD
		SET
			DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..DataClass_Dimension DCD
			INNER JOIN #Dimension D ON D.DimensionID = DCD.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..DataClass_Dimension DDCD WHERE DDCD.DataClassID = DCD.DataClassID AND DDCD.DimensionID = D.[GenericDimensionID])

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update Dimension_Property'
		UPDATE DP
		SET
			DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..Dimension_Property DP
			INNER JOIN #Dimension D ON D.DimensionID = DP.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Dimension_Property DDP WHERE DDP.DimensionID = D.[GenericDimensionID] AND DDP.PropertyID = DP.PropertyID)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update AssignmentRow'
		UPDATE AR
		SET
			DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..AssignmentRow AR
			INNER JOIN #Dimension D ON D.DimensionID = AR.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..AssignmentRow DAR WHERE DAR.AssignmentID = AR.AssignmentID AND DAR.DimensionID = D.[GenericDimensionID] AND DAR.Dimension_MemberKey = AR.Dimension_MemberKey)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update BR05_Master'
		UPDATE BRM
		SET
			InterCompanySelection_DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..BR05_Master BRM
			INNER JOIN #Dimension D ON D.DimensionID = BRM.InterCompanySelection_DimensionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update DataClass'
		UPDATE DC
		SET
			PrimaryJoin_DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..DataClass DC
			INNER JOIN #Dimension D ON D.DimensionID = DC.PrimaryJoin_DimensionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update Dimension_Rule'
		UPDATE DR
		SET
			DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..Dimension_Rule DR
			INNER JOIN #Dimension D ON D.DimensionID = DR.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Dimension_Rule DDR WHERE DDR.InstanceID = DR.InstanceID AND DDR.Entity_MemberKey = DR.Entity_MemberKey AND DDR.DimensionID = D.[GenericDimensionID])

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update Grid_Dimension'
		UPDATE GD
		SET
			DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..Grid_Dimension GD
			INNER JOIN #Dimension D ON D.DimensionID = GD.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Grid_Dimension DGD WHERE DGD.GridID = GD.GridID AND DGD.DimensionID = D.[GenericDimensionID] AND DGD.GridAxisID = GD.GridAxisID)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update ListMaintain_UserWorkflow'
		UPDATE LMUV
		SET
			LinkedDimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..ListMaintain_UserWorkflow LMUV
			INNER JOIN #Dimension D ON D.DimensionID = LMUV.LinkedDimensionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update MappedMemberKey'
		UPDATE MMK
		SET
			DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..MappedMemberKey MMK
			INNER JOIN #Dimension D ON D.DimensionID = MMK.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..MappedMemberKey DMMK WHERE DMMK.InstanceID = MMK.InstanceID AND DMMK.VersionID = MMK.VersionID AND DMMK.DimensionID = D.[GenericDimensionID] AND DMMK.Entity_MemberKey = MMK.Entity_MemberKey AND DMMK.MemberKeyFrom = MMK.MemberKeyFrom)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update Mapping_DataClass_Filter'
		UPDATE MDCF
		SET
			DimensionID = D.[GenericDimensionID]
		FROM
			pcINTEGRATOR_Data..Mapping_DataClass_Filter MDCF
			INNER JOIN #Dimension D ON D.DimensionID = MDCF.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Mapping_DataClass_Filter DMDCF WHERE DMDCF.Mapping_DimensionGroupID = MDCF.Mapping_DimensionGroupID AND DMDCF.DataClassPosition = MDCF.DataClassPosition AND DMDCF.DimensionID = D.[GenericDimensionID] AND DMDCF.MemberKey = MDCF.MemberKey)

		SET @Updated = @Updated + @@ROWCOUNT

/*
Mapping_DataClass_Filter	DimensionID
Mapping_Dimension	DimensionID
Mapping_Dimension	Mapping_DimensionID
Mapping_DimensionMember	Mapping_DimensionID
OrganizationHierarchy	LinkedDimensionID
OrganizationPosition_Dimension	DimensionID
OrganizationPosition_DimensionMember	DimensionID
OrganizationPositionRow	DimensionID
Property	DependentDimensionID
ScenarioCopyRule	DimensionID
SqlSource_Dimension	DimensionID
SqlSource_Model_FACT	DimensionID
WorkflowRow	DimensionID
*/


/*
SELECT t.name, c.name, t.* FROM pcINTEGRATOR_Data.sys.tables t
INNER JOIN pcINTEGRATOR_Data.sys.all_columns c ON c.object_id = t.object_id and c.name LIKE '%Dimension%'
ORDER BY t.name, c.name
*/
	SET @Step = 'Delete obsolete Dimension_Property'
		DELETE DP
		FROM
			pcINTEGRATOR_Data..Dimension_Property DP
			INNER JOIN #Dimension D ON D.DimensionID = DP.DimensionID

		SET @Deleted = @Deleted + @@ROWCOUNT

		DELETE DP
		FROM
			pcINTEGRATOR_Data..Dimension_Property DP
			INNER JOIN #Property P ON P.PropertyID = DP.PropertyID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete obsolete Properties'
		DELETE P
		FROM
			pcINTEGRATOR_Data..Property P
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Dimension_Property DP WHERE DP.PropertyID = P.PropertyID)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete replaced Dimensions'
		DELETE DHL
		FROM
			pcINTEGRATOR_Data..DimensionHierarchyLevel DHL
			INNER JOIN #Dimension D ON D.DimensionID = DHL.DimensionID

		DELETE DH
		FROM
			pcINTEGRATOR_Data..DimensionHierarchy DH
			INNER JOIN #Dimension D ON D.DimensionID = DH.DimensionID

		DELETE DD
		FROM
			pcINTEGRATOR_Data..Dimension DD
			INNER JOIN #Dimension D ON D.DimensionID = DD.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Dimension_Property DP WHERE DP.DimensionID = DD.DimensionID) AND
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..Dimension_StorageType DST WHERE DST.DimensionID = DD.DimensionID) AND
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..DataClass_Dimension DCD WHERE DCD.DimensionID = DD.DimensionID)

		SET @Deleted = @Deleted + @@ROWCOUNT




/*
SELECT *
  FROM [pcINTEGRATOR].[dbo].[Dimension]
  WHERE DimensionName = 'employee'

  SELECT *
  FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
  WHERE InstanceID = -1405 AND DimensionID = -69

    SELECT *
  FROM [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
  WHERE InstanceID IN (0, -1405) AND DimensionID IN (7594, -69)

DELETE [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
  WHERE InstanceID = -1405 AND DimensionID = -69

UPDATE DataClass_Dimension SET DimensionID = -69
WHERE DimensionID IN (8072,8063,8054,8045,8036,8021,8012,8003,7994,7985,7976,7967,7958,7949,7940,7931,7922,7913,7904,7895,7886,7870,7861,7846,7837,7828,7819,7810,7801,7783,7744,7735,7708,7648,7642,7594)

UPDATE [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] SET DimensionID = -69
WHERE DimensionID IN (8072,8063,8054,8045,8036,8021,8012,8003,7994,7985,7976,7967,7958,7949,7940,7931,7922,7913,7904,7895,7886,7870,7861,7846,7837,7828,7819,7810,7801,7783,7744,7735,7708,7648,7642,7594)

    SELECT *
  FROM [pcINTEGRATOR].[dbo].[Dimension_Property]
  WHERE DimensionID IN (-69, 8072,8063,8054,8045,8036,8021,8012,8003,7994,7985,7976,7967,7958,7949,7940,7931,7922,7913,7904,7895,7886,7870,7861,7846,7837,7828,7819,7810,7801,7783,7744,7735,7708,7648,7642,7594)

    SELECT * FROM 
	--DELETE
	[pcINTEGRATOR_Data].[dbo].[Dimension_Property]
  WHERE DimensionID IN (8072,8063,8054,8045,8036,8021,8012,8003,7994,7985,7976,7967,7958,7949,7940,7931,7922,7913,7904,7895,7886,7870,7861,7846,7837,7828,7819,7810,7801,7783,7744,7735,7708,7648,7642,7594)
  AND Comment LIKE '%Type%'

 UPDATE	[pcINTEGRATOR_Data].[dbo].[Dimension_Property] SET DimensionID = -69
  WHERE DimensionID IN (8072,8063,8054,8045,8036,8021,8012,8003,7994,7985,7976,7967,7958,7949,7940,7931,7922,7913,7904,7895,7886,7870,7861,7846,7837,7828,7819,7810,7801,7783,7744,7735,7708,7648,7642,7594)

SELECT * FROM 
--DELETE P FROM [pcINTEGRATOR_Data].[dbo].[Property] P
WHERE NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP WHERE DP.PropertyID = P.PropertyID)

SELECT * FROM 
--DELETE
[pcINTEGRATOR_Data].[dbo].[Dimension]
  WHERE DimensionID IN (8072,8063,8054,8045,8036,8021,8012,8003,7994,7985,7976,7967,7958,7949,7940,7931,7922,7913,7904,7895,7886,7870,7861,7846,7837,7828,7819,7810,7801,7783,7744,7735,7708,7648,7642,7594)
*/

	SET @Step = 'Drop temp tables'
		DROP TABLE #Dimension
		DROP TABLE #Property

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
