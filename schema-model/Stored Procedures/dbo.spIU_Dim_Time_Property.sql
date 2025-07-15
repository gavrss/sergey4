SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Time_Property]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StartYear int = NULL,
	@AddYear int = 2, --Number of years to add after current year
	@FiscalYearStartMonth int = NULL,
	@DimensionID int = NULL, --When NULL, run all Time Property Dimensions; When set, run the specified
	@DimensionName nvarchar(100) = NULL, --When NULL, run all Time Property Dimensions; When set, run the specified

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000676,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM = 3 (include high and low prio, exclude sub routines)
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_Time_Property] @UserID=-10, @InstanceID = -1318, @VersionID = -1256, @DebugBM=1
EXEC [spIU_Dim_Time_Property] @UserID=-10, @InstanceID=452, @VersionID=1020, @DimensionID=-11, @DebugBM=1 --ReSales
EXEC [spIU_Dim_Time_Property] @UserID=-10, @InstanceID=452, @VersionID=1020, @DimensionName='TimeFiscalYear', @DebugBM=1 --ReSales

EXEC [spIU_Dim_Time_Property] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ETLDatabase nvarchar(100),
	@Dimensionhierarchy nvarchar(100),
	@SQLStatement nvarchar(max),
	@ProcedureName_Step nvarchar(100),
	@SQLLoop nvarchar(1000),
	@LoopID int = 1,
	@StartTime_Step datetime,
	@Duration_Step time(7),
	@Deleted_Step int = 0,
	@Inserted_Step int = 0,
	@Updated_Step int = 0,
	@Selected_Step int = 0,

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
	@ToBeChanged nvarchar(255) = 'Add database stored parameters for @AddYear and @DataFirst',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to load Members into Dimension Tables',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Enhanced debugging.'
		IF @Version = '2.0.3.2154' SET @Description = 'Updated VersionDescription.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

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

		SELECT
			@ETLDatabase = A.ETLDatabase,
			@FiscalYearStartMonth = ISNULL(@FiscalYearStartMonth, A.FiscalYearStartMonth)
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		SELECT
			@StartYear = ISNULL(@StartYear, MIN(StartYear))
		FROM
			[Source] S
		WHERE
			S.InstanceID = @InstanceID AND
			S.VersionID = @VersionID

		SELECT
			@AddYear = ISNULL(@AddYear, 2) --Number of years to add after current year

	SET @Step = 'Create table #Time_Property'
		CREATE TABLE #Time_Property
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[ParentMemberID] int
			)

	SET @Step = 'Time_Property_Cursor'
		CREATE TABLE #Time_Property_Cursor
			(
			DimensionID int,
			DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #Time_Property_Cursor
			(
			DimensionID,
			DimensionName
			)
		SELECT
			DimensionID,
			DimensionName
		FROM
			Dimension
		WHERE
			InstanceID = 0 AND
			DimensionTypeID = 25

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Time_Property_Cursor', * FROM #Time_Property_Cursor ORDER BY DimensionID

		IF CURSOR_STATUS('global','Time_Property_Cursor') >= -1 DEALLOCATE Time_Property_Cursor
		DECLARE Time_Property_Cursor CURSOR FOR
			SELECT 
				DimensionID,
				DimensionName
			FROM
				#Time_Property_Cursor
			ORDER BY
				DimensionID

			OPEN Time_Property_Cursor
			FETCH NEXT FROM Time_Property_Cursor INTO @DimensionID, @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @StartTime_Step = GETDATE()
					IF @DebugBM & 2 > 0 SELECT DimensionID = @DimensionID, DimensionName = @DimensionName

					SET @Step = 'Create dimension table if not exists'
						EXEC [spSetup_Table_Dimension] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = @DimensionID, @ETLDatabase = @ETLDatabase, @Debug = @DebugSub

					SET @Step = 'Get values to insert'
						TRUNCATE TABLE #Time_Property
						EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = @DimensionID, @StartYear = @StartYear, @AddYear = @AddYear, @FiscalYearStartMonth = @FiscalYearStartMonth, @Debug = @DebugSub
						SELECT @Selected_Step = COUNT(1) FROM #Time_Property

					SET @Step = 'Update Description where Synchronized is set to true.'
						SET @SQLStatement = '
							UPDATE
								[' + @DimensionName + ']
							SET
								[Description] = [Members].[Description], 
								[HelpText] = [Members].[HelpText], 
								[Source] = [Members].[Source],
								[Updated] = GetDate(),
								[UserID] = ' + CONVERT(nvarchar(15), @UserID) + '
							FROM
								[' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] [' + @DimensionName + '] 
								INNER JOIN [#Time_Property] [Members] ON [Members].[MemberKey] = [' + @DimensionName + '].[MemberKey] 
							WHERE 
								[' + @DimensionName + '].[Synchronized] <> 0 AND
								(
								[' + @DimensionName + '].[Description] <> [Members].[Description] OR
								[' + @DimensionName + '].[HelpText] <> [Members].[HelpText] OR
								[' + @DimensionName + '].[Source] <> [Members].[Source]
								)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Updated_Step = @@ROWCOUNT
		
					SET @Step = 'Insert new members'
						SET @SQLStatement = '
							SET IDENTITY_INSERT [' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] ON

							INSERT INTO [' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + ']
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[NodeTypeBM],
								[SBZ],
								[Source],
								[Synchronized],
								[ParentMemberID],
								[SortOrder],
								[UserID]
								)
							SELECT
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[NodeTypeBM],
								[SBZ],
								[Source],
								[Synchronized],
								[ParentMemberID],
								[SortOrder] = [MemberId],
								[UserID] = ' + CONVERT(nvarchar(15), @UserID) + '
							FROM   
								[#Time_Property] Members
							WHERE
								Members.[MemberId] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] [' + @DimensionName + '] WHERE Members.[MemberID] = [' + @DimensionName + '].[MemberID]) AND
								NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] [' + @DimensionName + '] WHERE Members.[MemberKey] = [' + @DimensionName + '].[MemberKey])
			
							SET IDENTITY_INSERT [' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] OFF'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Inserted = @Inserted + @@ROWCOUNT

					SET @Step = 'Update default hierarchy'
						SET @SQLStatement = '		
							UPDATE T1 
							SET
								[ParentMemberID] = CASE T1.MemberKey WHEN ''All_'' THEN 0 ELSE [' + @DimensionName + '].[MemberID] END
							FROM
								#Time_Property T1
								LEFT JOIN #Time_Property T2 ON T2.[MemberKey] = T1.[Parent]
								LEFT JOIN [' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] [' + @DimensionName + '] ON [' + @DimensionName + '].[MemberKey] = T2.MemberKey'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @SQLStatement = '
							UPDATE
								[' + @DimensionName + ']
							SET
								[ParentMemberID] =  [Members].[ParentMemberID]
							FROM
								[' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] [' + @DimensionName + '] 
								INNER JOIN [#Time_Property] [Members] ON [Members].[MemberKey] = [' + @DimensionName + '].[MemberKey] AND [Members].[ParentMemberID] IS NOT NULL
							WHERE 
								[' + @DimensionName + '].[Synchronized] <> 0 AND
								[' + @DimensionName + '].[ParentMemberID] IS NULL'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					SET @Step = 'Remove all parent members without leaf members as children.'
						SET @SQLStatement = '
							UPDATE T1
							SET
								[ParentMemberID] = NULL
							FROM
								[' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] T1
							WHERE
								T1.[NodeTypeBM] & 2 > 0 AND
								NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] T2 WHERE T2.[ParentMemberID] = T1.[MemberID])'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement

						SET @SQLLoop = '
							SELECT
								@InternalVariable = COUNT(1)
							FROM
								[' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] T1
							WHERE
								T1.[NodeTypeBM] & 2 > 0 AND
								T1.[ParentMemberID] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] T2 WHERE T2.[ParentMemberID] = T1.MemberID)'

						IF @DebugBM & 2 > 0 PRINT @SQLLoop

						WHILE @LoopID > 0
							BEGIN
								EXEC(@SQLStatement)

								EXEC sp_executesql @SQLLoop, N'@InternalVariable int OUT', @InternalVariable = @LoopID OUT
							END

					SET @Step = 'Return rows'
						IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + ']'', * FROM [' + @ETLDatabase + '].[dbo].[pcD_' + @DimensionName + '] ORDER BY SortOrder')

					SET @Step = 'Log Property steps'
						SELECT
							@ProcedureName_Step = @ProcedureName + '; ' + @DimensionName,
							@Duration_Step = GetDate() - @StartTime_Step
						EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime_Step, @ProcedureName = @ProcedureName_Step, @Duration = @Duration_Step, @Deleted = @Deleted_Step, @Inserted = @Inserted_Step, @Updated = @Updated_Step, @Selected = @Selected_Step, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

						SELECT
							@Deleted = @Deleted + ISNULL(@Deleted_Step, 0),
							@Inserted = @Inserted + ISNULL(@Inserted_Step, 0),
							@Updated = @Updated + ISNULL(@Updated_Step, 0),
							@Selected = @Selected + ISNULL(@Selected_Step, 0)
					
					FETCH NEXT FROM Time_Property_Cursor INTO @DimensionID, @DimensionName
				END

		CLOSE Time_Property_Cursor
		DEALLOCATE Time_Property_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE #Time_Property
		DROP TABLE #Time_Property_Cursor

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
