SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_MissedItems]
	@UserID INT = -10,
	@InstanceID INT = 0,
	@VersionID INT = 0,

	--SP-specific parameters
	@SqlQuery NVARCHAR(max) = '',
	@DataClassID INT = 0,
    @MissingItems_OUT NVARCHAR(1000) = NULL OUT,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000952,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*


declare @SqlQuery nvarchar(max) = N'
                        SELECT
                            [LineItem_MemberId] = DC.[LineItem_MemberId],
                            [Time_MemberId] = DC.[Time_MemberId],
                            [Scenario_MemberID] = DC.[Scenario_MemberID],
                            [Financials_Value] = SUM(DC.[Financials_Value]),
                            [WorkflowStateID] = MAX(CONVERT(int, DC.[WorkFlowState_MemberId])),
                            [Workflow_UpdatedBy_UserID] = 0
                        INTO
                            [##DC_3488582B-2444-4FE3-9D93-C1A1D791183B]
                        FROM
                            [pcDATA_AGLTI].[dbo].[FACT_Assumption_default_partition] DC WITH (NOLOCK, INDEX([NCCSI_Assumption]))
                            INNER JOIN #Time T ON T.[MemberId] = DC.[Time_MemberId]
                        WHERE
                            DC.[Account_MemberID] IN (1954) AND DC.[Scenario_MemberID] IN (130) AND DC.[Time_MemberID] IN (202301,202302,202303,202304,202305,202306,202307,202308,202309,202310,202311,202312) AND
                            1 = 1
                        GROUP BY
                            DC.[LineItem_MemberId],
                            DC.[Time_MemberId],
                            DC.[Scenario_MemberID]
                        OPTION (RECOMPILE)';

declare @MissingItems_OUT NVARCHAR(1000) = NULL;

EXEC [spPortalGet_MissedItems] @UserID=-10, @InstanceID = 619, @VersionID = 1104, @DataClassID='5870', @Debug = 1, @MissingItems_OUT = @MissingItems_OUT OUTPUT
select @MissingItems_OUT

EXEC [spPortalGet_MissedItems] @GetVersion = 1
*/

 SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables

	@SQL1 NVARCHAR(MAX),

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
	@CreatedBy NVARCHAR(50) = 'SeGa',
	@ModifiedBy NVARCHAR(50) = 'SeGa',
	@Version NVARCHAR(50) = '2.1.2.2198'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get missed Dimensions for DataClass from input SqlQuery',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2198' SET @Description = 'Procedure created.'

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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create and fill temporal tables'

/*
    DROP TABLE IF EXISTS #DimensionInfo;
    CREATE TABLE #DimensionInfo
        (
        [ResultTypeBM] int,
        [InstanceID] int,
        [DimensionID] int,
        [DimensionName] nvarchar (50),
        [DimensionDescription] nvarchar (255),
        [DimensionTypeID] int,
        [DimensionTypeName] nvarchar (50),
        [ReportOnlyYN] bit,
        [SourceTypeBM] int,
        [MasterDimensionID] int,
        [InheritedFrom] int,
        [SeedMemberID] int,
        [LoadSP] nvarchar (50),
        [DimensionFilter] nvarchar(4000),
        [StorageTypeBM] int,
        [ObjectGuiBehaviorBM] int,
        [ReadSecurityEnabledYN] bit,
        [MappingTypeID] int,
        [ReplaceStringYN] bit,
        [DefaultSetMemberKey] nvarchar (100),
        [DefaultSetMemberDescription] nvarchar (255),
        [DefaultGetMemberKey] nvarchar(100),
        [DefaultGetMemberDescription] nvarchar (255),
        [DefaultGetHierarchyNo] int,
        [DefaultGetHierarchyName] nvarchar (100),
        [ModelingStatusID] int,
        [ModelingComment] nvarchar (1024),
        [Introduced] nvarchar (100),
        [SelectYN] bit
        )


    insert into #DimensionInfo
    EXEC [pcINTEGRATOR].[dbo].[spPortalAdminGet_Dimension] @DataClassID = @DataClassID, @InstanceID = @InstanceID, @VersionID = @VersionID,
            @ObjectGuiBehaviorBM = '3', @ResultTypeBM = '1', @UserID = @UserID
*/

	SET @Step = 'Parse @SqlQuery to fill @TableItems by XXX values from "DC.[XXX_MemberID]" patterns'
	-- Parse @SqlQuery to fill @TableItems by XXX values from "DC.[XXX_MemberID]" patterns
    DECLARE
        @OldDelim   nvarchar(32) = N'DC.[',
        @NewDelim   nchar(1)     = NCHAR(9999); -- pencil (✏)

    Declare @TableItems table ([Item] nvarchar(255));

	if @Debug <> 0
	    begin
	        select [@SqlQuery] = @SqlQuery, Repl = REPLACE(@SqlQuery, @OldDelim, @NewDelim)
	        SELECT row_number() over (order by [value]) as RowN, *
                FROM STRING_SPLIT(REPLACE(@SqlQuery, @OldDelim, @NewDelim), @NewDelim)
        end

    insert into @TableItems
    select [item] = replace([value], N'_MemberID', '')
    from (select distinct left([value], charindex(N']', [value]) - 1) as [value]
          from (SELECT row_number() over (order by [value]) as RowN, *
                FROM STRING_SPLIT(REPLACE(@SqlQuery, @OldDelim, @NewDelim), @NewDelim)) as A
          where A.RowN > 1) as B
    where B.[value] like N'%_MemberID'

	SET @Step = 'Get missed Items'

	set @MissingItems_OUT = '';
    select @MissingItems_OUT = @MissingItems_OUT  + [Item] + N', '
    from @TableItems TI
 --   left join #DimensionInfo DI on DI.DimensionName = TI.[Item]
    left join (
                SELECT D.DimensionName
                FROM [pcINTEGRATOR]..[DataClass_Dimension] DCD
                JOIN [pcINTEGRATOR]..[Dimension] D ON   D.[DimensionID] = DCD.[DimensionID]
                                                    and D.SelectYN <> 0
                WHERE DCD.[InstanceID] = @InstanceID
                  AND DCD.[VersionID] = @VersionID
                  AND DCD.[DataClassID] = @DataClassID
                  AND DCD.SelectYN <> 0
                ) DI on DI.DimensionName = TI.[Item]
    where DI.DimensionName is null

	if @Debug <> 0
        select [@MissingItems_OUT] = @MissingItems_OUT, [Len] = Len(@MissingItems_OUT)

    if Len(@MissingItems_OUT) > 1
        set @MissingItems_OUT = left(@MissingItems_OUT, Len(@MissingItems_OUT) - 1)

    select @MissingItems_OUT = iif(LTRIM(RTRIM(@MissingItems_OUT)) <> '', @MissingItems_OUT, NULL)

	SET @Step = 'Set @Duration'
		SET @Duration = GETDATE() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
