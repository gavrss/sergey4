SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_SecurityRoles_Dynamic]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DataClassID int = NULL, --Optional

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000481,
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
EXEC [spGet_SecurityRoles_Dynamic] @UserID=-10, @InstanceID=413, @VersionID=1008, @Debug=1 --CBN
EXEC [spGet_SecurityRoles_Dynamic] @UserID=-10, @InstanceID=454, @VersionID=1021, @Debug=1 --CCM

EXEC [spGet_SecurityRoles_Dynamic] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@OrganizationPositionID int,
	@RowCounter int,
	@RoleID int,
	@CalledYN bit = 1,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2172'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Sub routine used when creating dynamic security roles for Callisto and Tabular',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added VersionID to [OrganizationPosition_DataClass]. Enhanced debugging. Handle WriteAccess.'
		IF @Version = '2.1.1.2172' SET @Description = 'Filter on U.[UserLicenseTypeID] <> 0 when filling table #User.'

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

		IF @DebugBM & 2 > 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create temp tables if not exists' --For debugging purposes
		IF OBJECT_ID (N'tempdb..#User', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #User
					(
					[InstanceID] [INT],
					[UserID] [INT],
					[UserName] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
					[UserNameAD] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
					[AzureUPN] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
					[UserNameDisplay] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
					[UserTypeID] [INT],
					[UserLicenseTypeID] [INT],
					[LocaleID] [INT],
					[LanguageID] [INT],
					[ObjectGuiBehaviorBM] [INT],
					[InheritedFrom] [INT] NULL,
					[SelectYN] [BIT] NOT NULL,
					[Version] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
					[DeletedID] [INT]
					)

				CREATE TABLE #RoleMemberRow
					(
					[RoleID] int,
					[DataClassID] int,
					[DimensionID] int,
					[HierarchyNo] int,
					[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[WriteAccessYN] bit
					)

				CREATE TABLE #RoleOrganizationPosition
					(
					RoleID int,
					OrganizationPositionID int
					)
			END

	SET @Step = 'Create temp tables'
		CREATE TABLE #DimNo
			(
			DataClassID int,
			LDDimNo int,
			OPDimNo int
			)

		CREATE TABLE #MemberRow
			(
			DataClassID int,
			DimensionID int,
			HierarchyNo int,
			MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT,
			WriteAccessYN bit
			)

		CREATE TABLE #RoleCounter
			(
			RoleID int IDENTITY(1,1),
			OrganizationPositionID int
			)

	SET @Step = 'Insert values to #User'
		INSERT INTO #User
			(
			[InstanceID],
			[UserID],
			[UserName],
			[UserNameAD],
			[AzureUPN],
			[UserNameDisplay],
			[UserTypeID],
			[UserLicenseTypeID],
			[LocaleID],
			[LanguageID],
			[ObjectGuiBehaviorBM],
			[InheritedFrom],
			[SelectYN],
			[Version],
			[DeletedID]
			)
		SELECT
			sub.[InstanceID],
			sub.[UserID],
			[UserName],
			[UserNameAD],
			[AzureUPN] = UPV.UserPropertyValue,
			[UserNameDisplay],
			[UserTypeID],
			[UserLicenseTypeID],
			[LocaleID],
			[LanguageID],
			[ObjectGuiBehaviorBM],
			[InheritedFrom],
			sub.[SelectYN],
			sub.[Version],
			[DeletedID]
		FROM
			(
			SELECT DISTINCT
				[InstanceID],
				[UserID],
				[UserName],
				[UserNameAD],
				[UserNameDisplay],
				[UserTypeID],
				[UserLicenseTypeID] = CASE WHEN  U.UserLicenseTypeID = 0 THEN 0 ELSE 1 END,
				[LocaleID],
				[LanguageID],
				[ObjectGuiBehaviorBM],
				[InheritedFrom],
				[SelectYN],
				[Version],
				[DeletedID]
			FROM
				[pcINTEGRATOR_Data].[dbo].[User] U
			WHERE
				U.InstanceID = @InstanceID AND
				U.UserNameAD IS NOT NULL AND
				U.UserTypeID = -1 AND
				U.[UserLicenseTypeID] <> 0 AND
				U.SelectYN <> 0 AND
				U.DeletedID IS NULL
			UNION
			SELECT DISTINCT
				[InstanceID] = UI.InstanceID,
				[UserID] = U.UserID,
				[UserName],
				[UserNameAD],
				[UserNameDisplay],
				[UserTypeID],
				[UserLicenseTypeID] = CASE WHEN  U.UserLicenseTypeID = 0 THEN 0 ELSE 1 END,
				[LocaleID],
				[LanguageID],
				[ObjectGuiBehaviorBM],
				[InheritedFrom],
				[SelectYN] = U.SelectYN,
				[Version] = U.[Version],
				[DeletedID] = U.DeletedID
			FROM
				[pcINTEGRATOR_Data].[dbo].[User] U 
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[User_Instance] UI ON UI.InstanceID = @InstanceID AND UI.UserID = U.UserID AND UI.SelectYN <> 0 AND UI.DeletedID IS NULL AND (UI.ExpiryDate IS NULL OR UI.ExpiryDate >= GETDATE())
			WHERE
				U.UserNameAD IS NOT NULL AND
				U.UserTypeID = -1 AND
				U.[UserLicenseTypeID] <> 0 AND
				U.SelectYN <> 0 AND
				U.DeletedID IS NULL
			) sub
			LEFT JOIN [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV ON UPV.UserID = sub.UserID AND UPV.UserPropertyTypeID = -10 AND UPV.SelectYN <> 0

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#User', * FROM #User

	SET @Step = 'Create Roles'
		SELECT DISTINCT
			DC.DataClassID,
			DCD.DimensionID
		INTO
			#LockedDimension
		FROM
			DataClass DC 
			INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = DC.InstanceID AND DCD.VersionID = DC.VersionID AND DCD.DataClassID = DC.DataClassID 
			INNER JOIN Dimension_StorageType DST ON DST.InstanceID = DC.InstanceID AND DST.VersionID = DC.VersionID AND DST.DimensionID = DCD.DimensionID AND DST.StorageTypeBM & 4 > 0 AND DST.ReadSecurityEnabledYN <> 0
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.VersionID = @VersionID AND
			DC.StorageTypeBM & 4 > 0 AND
			(DC.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
			DC.SelectYN <> 0 
		ORDER BY
			DC.DataClassID,
			DCD.DimensionID

		SELECT DISTINCT
			OP.OrganizationPositionID,
			DC.DataClassID,
			OPDM.DimensionID,
			OPDM.HierarchyNo,
			OPDM.MemberKey,
			OPDM.WriteAccessYN
		INTO
			#OrganizationPosition
		FROM
			OrganizationPosition OP
			INNER JOIN OrganizationPosition_DimensionMember OPDM ON OPDM.OrganizationPositionID = OP.OrganizationPositionID AND (OPDM.ReadAccessYN <> 0 OR OPDM.WriteAccessYN <> 0)
			INNER JOIN DataClass DC ON DC.InstanceID = OP.InstanceID AND DC.VersionID = OP.VersionID AND DC.StorageTypeBM & 4 > 0 AND (DC.DataClassID = @DataClassID OR @DataClassID IS NULL) AND DC.SelectYN <> 0 
			INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = DC.InstanceID AND DCD.VersionID = DC.VersionID AND DCD.DataClassID = DC.DataClassID AND DCD.DimensionID = OPDM.DimensionID
			INNER JOIN Dimension_StorageType DST ON DST.InstanceID = DCD.InstanceID AND DST.VersionID = DCD.VersionID AND DST.DimensionID = DCD.DimensionID AND DST.StorageTypeBM & 4 > 0 AND DST.ReadSecurityEnabledYN <> 0
		WHERE
			OP.InstanceID = @InstanceID AND
			OP.VersionID = @VersionID AND
			NOT EXISTS (SELECT 1 FROM OrganizationPosition_DataClass OPDC WHERE OPDC.InstanceID = DC.InstanceID AND OPDC.VersionID = DC.VersionID AND OPDC.OrganizationPositionID = OP.OrganizationPositionID AND OPDC.DataClassID = DC.DataClassID AND OPDC.ReadAccessYN = 0)
		ORDER BY
			OP.OrganizationPositionID,
			DC.DataClassID,
			OPDM.DimensionID,
			OPDM.MemberKey

		INSERT INTO #OrganizationPosition
			(
			OrganizationPositionID,
			DataClassID,
			DimensionID,
			HierarchyNo,
			MemberKey,
			WriteAccessYN
			)
		SELECT DISTINCT
			OrganizationPositionID = OP.OrganizationPositionID,
			DataClassID = DC.DataClassID,
			DimensionID = OH.LinkedDimensionID,
			HierarchyNo = 0,
			MemberKey = OP.LinkedDimension_MemberKey,
			WriteAccessYN = 0
		FROM
			OrganizationPosition OP
			INNER JOIN OrganizationHierarchy OH ON OH.InstanceID = OP.InstanceID AND OH.VersionID = OP.VersionID AND OH.OrganizationHierarchyID = OP.OrganizationHierarchyID
			INNER JOIN Dimension_StorageType DST ON DST.InstanceID = OP.InstanceID AND DST.VersionID = OP.VersionID AND DST.DimensionID = OH.LinkedDimensionID AND DST.StorageTypeBM & 4 > 0 AND DST.ReadSecurityEnabledYN <> 0
			INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = OP.InstanceID AND DCD.VersionID = OP.VersionID AND DCD.DimensionID = OH.LinkedDimensionID
			INNER JOIN DataClass DC ON DC.InstanceID = OP.InstanceID AND DC.VersionID = OP.VersionID AND DC.DataClassID = DCD.DataClassID AND DC.StorageTypeBM & 4 > 0 AND (DC.DataClassID = @DataClassID OR @DataClassID IS NULL) AND DC.SelectYN <> 0 
		WHERE
			OP.InstanceID = @InstanceID AND
			OP.VersionID = @VersionID AND
			ISNULL(OP.LinkedDimension_MemberKey, '') <> '' AND
			NOT EXISTS (SELECT 1 FROM OrganizationPosition_DataClass OPDC WHERE OPDC.InstanceID = OP.InstanceID AND OPDC.VersionID = OP.VersionID AND OPDC.OrganizationPositionID = OP.OrganizationPositionID AND OPDC.DataClassID = DC.DataClassID AND OPDC.ReadAccessYN = 0) AND
			NOT EXISTS (SELECT 1 FROM #OrganizationPosition OPD WHERE OPD.OrganizationPositionID = OP.OrganizationPositionID AND OPD.DataClassID = DC.DataClassID AND OPD.DimensionID = OH.LinkedDimensionID AND OPD.HierarchyNo = 0 AND OPD.MemberKey = OP.LinkedDimension_MemberKey)
		ORDER BY
			OP.OrganizationPositionID,
			DC.DataClassID,
			OH.LinkedDimensionID,
			OP.LinkedDimension_MemberKey

		IF @DebugBM & 2 > 0 SELECT TempTable = '#OrganizationPosition', * FROM #OrganizationPosition ORDER BY OrganizationPositionID, DataClassID, DimensionID, MemberKey

	SET @Step = 'OP Cursor'
		DECLARE OP_Cursor CURSOR FOR
			
			SELECT DISTINCT
				OP.OrganizationPositionID
			FROM
				#OrganizationPosition OP
				INNER JOIN OrganizationPosition_User OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID
			ORDER BY
				OP.OrganizationPositionID

			OPEN OP_Cursor
			FETCH NEXT FROM OP_Cursor INTO @OrganizationPositionID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0
						BEGIN
							SELECT OrganizationPositionID = @OrganizationPositionID
						END

					TRUNCATE TABLE #MemberRow
					TRUNCATE TABLE #DimNo
					
					INSERT INTO #DimNo
						(
						DataClassID,
						LDDimNo
						)
					SELECT
						DataClassID = LD.DataClassID,
						LDDimNo = COUNT(LD.DimensionID)
					FROM 
						(
						SELECT DISTINCT
							DataClassID,
							DimensionID
						FROM
							#LockedDimension
						) LD 
					GROUP BY
						LD.DataClassID

					UPDATE DN
					SET
						OPDimNo = OP.OPDimNo
					FROM
						#DimNo DN
						INNER JOIN 
							(
							SELECT
								OP.DataClassID,
								OPDimNo = COUNT(OP.DimensionID)
							FROM 
								(					
								SELECT DISTINCT
									DataClassID,
									DimensionID
								FROM
									#OrganizationPosition
								WHERE
									OrganizationPositionID = @OrganizationPositionID
								) OP
							GROUP BY
								OP.DataClassID
							) OP ON OP.DataClassID = DN.DataClassID

					IF @DebugBM & 2 > 0 SELECT TempTable = '#DimNo', * FROM #DimNo

					INSERT INTO #MemberRow
						(
						DataClassID,
						DimensionID,
						HierarchyNo,
						MemberKey,
						WriteAccessYN
						)
					SELECT 
						OP.DataClassID,
						OP.DimensionID,
						OP.HierarchyNo,
						OP.MemberKey,
						OP.WriteAccessYN
					FROM
						#OrganizationPosition OP
						INNER JOIN #DimNo DN ON DN.DataClassID = OP.DataClassID AND DN.LDDimNo = DN.OPDimNo
					WHERE
						OP.OrganizationPositionID = @OrganizationPositionID

					SET @RowCounter = @@ROWCOUNT

					IF @DebugBM & 2 > 0 SELECT [@RowCounter] = @RowCounter

					IF @RowCounter > 0
						BEGIN
							SET @RoleID = NULL

							SELECT
								@RoleID = RoleID
							FROM
								(
								SELECT
									RMR.RoleID,
									MR.DataClassID,
									MR.DimensionID,
									MR.MemberKey
								FROM
									#RoleMemberRow RMR
									LEFT JOIN #MemberRow MR ON MR.DataClassID = RMR.DataClassID AND MR.DimensionID = RMR.DimensionID AND MR.HierarchyNo = RMR.HierarchyNo AND MR.MemberKey = RMR.MemberKey AND MR.WriteAccessYN = RMR.WriteAccessYN
								) sub
							WHERE
								DataClassID IS NOT NULL AND
								DimensionID IS NOT NULL AND
								MemberKey IS NOT NULL
							GROUP BY
								RoleID
							HAVING
								COUNT(1) = @RowCounter

							IF @DebugBM & 2 > 0 SELECT RoleID = @RoleID

							IF @RoleID IS NULL
								BEGIN
									INSERT INTO #RoleCounter
										(
										OrganizationPositionID
										)
									SELECT
										OrganizationPositionID = @OrganizationPositionID

									SET @RoleID = @@IDENTITY

									INSERT INTO #RoleMemberRow
										(
										RoleID,
										DataClassID,
										DimensionID,
										HierarchyNo,
										MemberKey,
										WriteAccessYN
										)
									SELECT
										RoleID = @RoleID,
										DataClassID,
										DimensionID,
										HierarchyNo,
										MemberKey,
										WriteAccessYN
									FROM
										#MemberRow
								END

							INSERT INTO #RoleOrganizationPosition
								(
								RoleID,
								OrganizationPositionID
								)
							SELECT
								RoleID = @RoleID,
								OrganizationPositionID = @OrganizationPositionID
						END

					FETCH NEXT FROM OP_Cursor INTO @OrganizationPositionID
				END

		CLOSE OP_Cursor
		DEALLOCATE OP_Cursor

	SET @Step = 'Return rows' --debugging purpose
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = '#User', * FROM #User
				SELECT TempTable = '#RoleOrganizationPosition', * FROM #RoleOrganizationPosition ORDER BY RoleID, OrganizationPositionID
				SELECT TempTable = '#RoleMemberRow', * FROM #RoleMemberRow
			END

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #User
				DROP TABLE #RoleOrganizationPosition
				DROP TABLE #RoleMemberRow
			END

		DROP TABLE #MemberRow
		DROP TABLE #LockedDimension
		DROP TABLE #OrganizationPosition
		DROP TABLE #RoleCounter
		DROP TABLE #DimNo

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
