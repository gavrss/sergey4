SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Time]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StartYear int = NULL,
	@AddYear int = 2, --Number of years to add after current year
	@FiscalYearStartMonth int = NULL,
	@FiscalYearNaming int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000673,
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
EXEC [spIU_Dim_Time] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DebugBM = 1

EXEC [spIU_Dim_Time] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DimensionID int = -7, --Time
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
	@ToBeChanged nvarchar(255) = 'Add database stored parameters for @AddYear and @DataFirst',
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to load Members into Time Dimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Made generic to work with StorageTypeBM = 2.'
		IF @Version = '2.0.3.2152' SET @Description = 'Added @FiscalYearNaming.'
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
			@ETLDatabase = A.ETLDatabase,
			@FiscalYearStartMonth = COALESCE(@FiscalYearStartMonth, A.FiscalYearStartMonth, I.FiscalYearStartMonth),
			@FiscalYearNaming = ISNULL(@FiscalYearNaming, I.FiscalYearNaming)
		FROM
			[Application] A
			INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID 
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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT @DimensionName = DimensionName FROM Dimension WHERE InstanceID IN (0, @InstanceID) AND DimensionID = @DimensionID

		IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@ETLDatabase] = @ETLDatabase

	SET @Step = 'Create dimension table if not exists'
		EXEC [spSetup_Table_Dimension] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DimensionID = @DimensionID, @ETLDatabase = @ETLDatabase, @Debug = @DebugSub

	SET @Step = 'Create table #Time_Members'
		CREATE TABLE #Time_Members
			(
			[MemberId] int,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Level] [nvarchar](10) COLLATE DATABASE_DEFAULT,
			[PeriodStartDate] [date] NULL,
			[PeriodEndDate] [date] NULL,
			[NumberOfDays] [int] NULL,
			[SendTo] nvarchar(255) COLLATE DATABASE_DEFAULT,	
			[SendTo_MemberId] int,
			[TimeMonth] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeMonth_MemberId] int,
			[TimeQuarter] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeQuarter_MemberId] int,
			[TimeTertial] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeTertial_MemberId] int,
			[TimeSemester] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeSemester_MemberId] int,
			[TimeYear] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeYear_MemberId] int,
			[TimeFiscalPeriod] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalPeriod_MemberId] int,
			[TimeFiscalQuarter] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalQuarter_MemberId] int,
			[TimeFiscalTertial] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalTertial_MemberId] int,
			[TimeFiscalSemester] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalSemester_MemberId] int,
			[TimeFiscalYear] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalYear_MemberId] int,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[ParentMemberID] int
			)

	SET @Step = 'Get values to insert'
		EXEC [spIU_Dim_Time_Raw] @StartYear = @StartYear, @AddYear = @AddYear, @FiscalYearStartMonth = @FiscalYearStartMonth, @FiscalYearNaming = @FiscalYearNaming
		
	SET @Step = 'Update Description and dimension specific Properties where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[Time]
			SET
				[Description] = [Members].[Description],
				[Level] = [Members].[Level],
				[PeriodStartDate] = [Members].[PeriodStartDate],
				[PeriodEndDate] = [Members].[PeriodEndDate],
				[NumberOfDays] = [Members].[NumberOfDays],
				[TimeMonth_MemberId] = [Members].[TimeMonth_MemberId],
				[TimeQuarter_MemberId] = [Members].[TimeQuarter_MemberId],
				[TimeTertial_MemberId] = [Members].[TimeTertial_MemberId],
				[TimeSemester_MemberId] = [Members].[TimeSemester_MemberId],
				[TimeYear_MemberId] = [Members].[TimeYear_MemberId],
				[TimeFiscalPeriod_MemberId] = [Members].[TimeFiscalPeriod_MemberId],
				[TimeFiscalQuarter_MemberId] = [Members].[TimeFiscalQuarter_MemberId],
				[TimeFiscalTertial_MemberId] = [Members].[TimeFiscalTertial_MemberId],
				[TimeFiscalSemester_MemberId] = [Members].[TimeFiscalSemester_MemberId],
				[TimeFiscalYear_MemberId] = [Members].[TimeFiscalYear_MemberId],
				[Source] = [Members].[Source]
			FROM
				[' + @ETLDatabase + '].[dbo].[pcD_Time] [Time] 
				INNER JOIN [#Time_Members] Members ON Members.MemberKey COLLATE DATABASE_DEFAULT = [Time].MemberKey
			WHERE 
				[Time].[Synchronized] <> 0'

		IF @Debug <> 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT		
	
	SET @Step = 'Insert new members'
		SET @SQLStatement = '
			SET IDENTITY_INSERT [' + @ETLDatabase + '].[dbo].[pcD_Time] ON

			INSERT INTO [' + @ETLDatabase + '].[dbo].[pcD_Time]
				(
				[MemberID],
				[MemberKey],
				[Description],
				[HelpText],
				[NodeTypeBM],
				[Level],
				[PeriodStartDate],
				[PeriodEndDate],
				[NumberOfDays],
				[SendTo_MemberId],
				[TimeFiscalPeriod_MemberId],
				[TimeFiscalQuarter_MemberId],
				[TimeFiscalSemester_MemberId],
				[TimeFiscalTertial_MemberId],
				[TimeFiscalYear_MemberId],
				[TimeMonth_MemberId],
				[TimeQuarter_MemberId],
				[TimeSemester_MemberId],
				[TimeTertial_MemberId],
				[TimeYear_MemberId],
				[SBZ],
				[Source],
				[Synchronized],
				[ParentMemberID],
				[SortOrder],
				[UserID]
				)
			SELECT
				[MemberID],
				[MemberKey],
				[Description],
				[HelpText],
				[NodeTypeBM],
				[Level],
				[PeriodStartDate],
				[PeriodEndDate],
				[NumberOfDays],
				[SendTo_MemberId],
				[TimeFiscalPeriod_MemberId],
				[TimeFiscalQuarter_MemberId],
				[TimeFiscalSemester_MemberId],
				[TimeFiscalTertial_MemberId],
				[TimeFiscalYear_MemberId],
				[TimeMonth_MemberId],
				[TimeQuarter_MemberId],
				[TimeSemester_MemberId],
				[TimeTertial_MemberId],
				[TimeYear_MemberId],
				[SBZ],
				[Source],
				[Synchronized],
				[ParentMemberID],
				[SortOrder] = [MemberID],
				[UserID] = ' + CONVERT(nvarchar(15), @UserID) + '
			FROM   
				[#Time_Members] Members
			WHERE
				Members.[MemberId] IS NOT NULL AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_Time] [Time] WHERE Members.[MemberID] = [Time].[MemberID]) AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_Time] [Time] WHERE Members.[MemberKey] = [Time].[MemberKey])
			
			SET IDENTITY_INSERT [' + @ETLDatabase + '].[dbo].[pcD_Time] OFF'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update default hierarchy'
		SET @SQLStatement = '		
			UPDATE T1 
			SET
				[ParentMemberID] = CASE T1.MemberKey WHEN ''All_'' THEN 0 ELSE [Time].[MemberID] END
			FROM
				#Time_Members T1
				LEFT JOIN #Time_Members T2 ON T2.[MemberKey] = T1.[Parent]
				LEFT JOIN [' + @ETLDatabase + '].[dbo].[pcD_Time] [Time] ON [Time].[MemberKey] = T2.MemberKey'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE
				[Time]
			SET
				[ParentMemberID] =  [Members].[ParentMemberID]
			FROM
				[' + @ETLDatabase + '].[dbo].[pcD_Time] [Time] 
				INNER JOIN [#Time_Members] [Members] ON [Members].[MemberKey] = [Time].[MemberKey] AND [Members].[ParentMemberID] IS NOT NULL
			WHERE 
				[Time].[Synchronized] <> 0 AND
				[Time].[ParentMemberID] IS NULL'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Remove all parent members without leaf members as children.'
		SET @SQLStatement = '
			UPDATE T1
			SET
				[ParentMemberID] = NULL
			FROM
				[' + @ETLDatabase + '].[dbo].[pcD_Time] T1
			WHERE
				T1.[NodeTypeBM] & 2 > 0 AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_Time] T2 WHERE T2.[ParentMemberID] = T1.[MemberID])'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement

		SET @SQLLoop = '
			SELECT
				@InternalVariable = COUNT(1)
			FROM
				[' + @ETLDatabase + '].[dbo].[pcD_Time] T1
			WHERE
				T1.[NodeTypeBM] & 2 > 0 AND
				T1.[ParentMemberID] IS NOT NULL AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[pcD_Time] T2 WHERE T2.[ParentMemberID] = T1.MemberID)'

		IF @DebugBM & 2 > 0 PRINT @SQLLoop

		WHILE @LoopID > 0
			BEGIN
				EXEC(@SQLStatement)

				EXEC sp_executesql @SQLLoop, N'@InternalVariable int OUT', @InternalVariable = @LoopID OUT
			END

		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @ETLDatabase + '].[dbo].[pcD_Time]'', * FROM [' + @ETLDatabase + '].[dbo].[pcD_Time] ORDER BY SortOrder')

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Time_Members

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
