SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_BusinessProcess]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000649,
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
EXEC [spIU_Dim_BusinessProcess] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DebugBM = 1

EXEC [spIU_Dim_BusinessProcess] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@DimensionID int = -2, --BusinessProcess
	@DimensionName nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLLoop nvarchar(1000),
	@ETLDatabase nvarchar(100),
	@LoopID int = 1,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into BusinessProcess dimension tables.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
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

		SELECT
			@ETLDatabase = [ETLDatabase]
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT @DimensionName = DimensionName FROM Dimension WHERE InstanceID IN (0, @InstanceID) AND DimensionID = @DimensionID

		IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@ETLDatabase] = @ETLDatabase

	SET @Step = 'Create dimension table if not exists'
		EXEC [spSetup_Table_Dimension] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = @DimensionID, @ETLDatabase = @ETLDatabase, @Debug = @DebugSub

	SET @Step = 'Create temp tables'
		CREATE TABLE #BusinessProcess_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Conversion] bit,
			[Manual] bit,
			[NoAutoElim] bit,
			[NoAutoFx] bit,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[ParentMemberID] int
			)

	SET @Step = 'Fetch members'
		EXEC [spIU_Dim_BusinessProcess_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @Debug = @DebugSub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#BusinessProcess_Members', * FROM #BusinessProcess_Members

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[BusinessProcess]
			SET
				[Description] = [Members].[Description], 
				[HelpText] = [Members].[HelpText], 
				[Source] = [Members].[Source],
				[Updated] = GetDate(),
				[UserID] = ' + CONVERT(nvarchar(15), @UserID) + '
			FROM
				[' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] [BusinessProcess] 
				INNER JOIN [#BusinessProcess_Members] [Members] ON [Members].[MemberKey] = [BusinessProcess].[MemberKey] 
			WHERE 
				[BusinessProcess].[Synchronized] <> 0 AND
				(
				[BusinessProcess].[Description] <> [Members].[Description] OR
				[BusinessProcess].[HelpText] <> [Members].[HelpText] OR
				[BusinessProcess].[Source] <> [Members].[Source]
				)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert new members from source system'
		SET @SQLStatement = '
			SET IDENTITY_INSERT [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] ON

			INSERT INTO [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess]
				(
				[MemberId],
				[MemberKey],
				[Description],
				[HelpText],
				[NodeTypeBM],
				[Conversion],
				[Manual],
				[NoAutoElim],
				[NoAutoFx],
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
				[Conversion],
				[Manual],
				[NoAutoElim],
				[NoAutoFx],
				[SBZ],
				[Source],
				[Synchronized],
				[ParentMemberID],
				[SortOrder] = ROW_NUMBER() OVER (ORDER BY MemberKey) * 100,
				[UserID] = ' + CONVERT(nvarchar(15), @UserID) + '
			FROM   
				[#BusinessProcess_Members] Members
			WHERE
				Members.[MemberId] IS NOT NULL AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] [BusinessProcess] WHERE Members.[MemberID] = [BusinessProcess].[MemberID]) AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] [BusinessProcess] WHERE Members.[MemberKey] = [BusinessProcess].[MemberKey])
			
			SET IDENTITY_INSERT [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] OFF'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		SET @SQLStatement = '
			INSERT INTO [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess]
				(
				[MemberKey],
				[Description],
				[HelpText],
				[NodeTypeBM],
				[Conversion],
				[Manual],
				[NoAutoElim],
				[NoAutoFx],
				[SBZ],
				[Source],
				[Synchronized],
				[ParentMemberID],
				[SortOrder],
				[UserID]
				)
			SELECT
				[MemberKey],
				[Description],
				[HelpText],
				[NodeTypeBM],
				[Conversion],
				[Manual],
				[NoAutoElim],
				[NoAutoFx],
				[SBZ],
				[Source],
				[Synchronized],
				[ParentMemberID],
				[SortOrder] = ROW_NUMBER() OVER (ORDER BY MemberKey) * 100,
				[UserID] = ' + CONVERT(nvarchar(15), @UserID) + '
			FROM   
				[#BusinessProcess_Members] Members
			WHERE
				Members.[MemberId] IS NULL AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] [BusinessProcess] WHERE Members.[MemberKey] = [BusinessProcess].[MemberKey])'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update default hierarchy'
		SET @SQLStatement = '		
			UPDATE T1 
			SET
				[ParentMemberID] = CASE T1.MemberKey WHEN ''All_'' THEN 0 ELSE [BusinessProcess].[MemberID] END
			FROM
				#BusinessProcess_Members T1
				LEFT JOIN #BusinessProcess_Members T2 ON T2.[MemberKey] = T1.[Parent]
				LEFT JOIN [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] [BusinessProcess] ON [BusinessProcess].[MemberKey] = T2.MemberKey'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE
				[BusinessProcess]
			SET
				[ParentMemberID] =  [Members].[ParentMemberID]
			FROM
				[' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] [BusinessProcess] 
				INNER JOIN [#BusinessProcess_Members] [Members] ON [Members].[MemberKey] = [BusinessProcess].[MemberKey] AND [Members].[ParentMemberID] IS NOT NULL
			WHERE 
				[BusinessProcess].[Synchronized] <> 0 AND
				[BusinessProcess].[ParentMemberID] IS NULL'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Remove all parent members without leaf members as children.'
		SET @SQLStatement = '
			UPDATE T1
			SET
				[ParentMemberID] = NULL
			FROM
				[' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] T1
			WHERE
				T1.[NodeTypeBM] & 2 > 0 AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] T2 WHERE T2.[ParentMemberID] = T1.[MemberID])'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement

		SET @SQLLoop = '
			SELECT
				@InternalVariable = COUNT(1)
			FROM
				[' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] T1
			WHERE
				T1.[NodeTypeBM] & 2 > 0 AND
				T1.[ParentMemberID] IS NOT NULL AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] T2 WHERE T2.[ParentMemberID] = T1.MemberID)'

		IF @DebugBM & 2 > 0 PRINT @SQLLoop

		WHILE @LoopID > 0
			BEGIN
				EXEC(@SQLStatement)

				EXEC sp_executesql @SQLLoop, N'@InternalVariable int OUT', @InternalVariable = @LoopID OUT
			END

		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess]'', * FROM [' + @ETLDatabase + '].[dbo].[pcD_BusinessProcess] ORDER BY SortOrder')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#BusinessProcess_Members]

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
