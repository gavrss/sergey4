SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCallisto_Run_BusinessRule]
	@Rule NVARCHAR(100) = NULL,
    @Application NVARCHAR(100) = NULL,
    @Model NVARCHAR(100) = NULL,
    @UserName Nvarchar(255) = NULL,

    --SP-specific parameters

    @JobID int = NULL,
    @JobLogID int = NULL,
    @Rows int = NULL,
    @ProcedureID int = 880000311,
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

  */

  SET ANSI_WARNINGS OFF

  DECLARE
    @Submission VARCHAR(MAX),

    @UserID int = NULL,
    @InstanceID int = NULL,
    @VersionID int = NULL,
    @Step nvarchar(255),
    @Message nvarchar(500) = '',
    @Severity int = 0,

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
    @CreatedBy nvarchar(50) = 'AnPo',
    @ModifiedBy nvarchar(50) = 'JaWo',
    @Version nvarchar(50) = '2.0.2.2144'

  IF @GetVersion <> 0
    BEGIN
      SELECT
          @ProcedureName = OBJECT_NAME(@@PROCID),
          @ProcedureDescription = 'Submit BusinessRule for execution into Callisto',
          @MandatoryParameter = '' --Without @, separated by |

      IF @Version = '2.0.0.2142' SET @Description = 'Procedure created.'
	  IF @Version = '2.0.2.2144' SET @Description = '@Application and @Model defaulted to NULL.'
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

    SET @Submission = '<runbusinessrule xmlns="http://www.perlielab.com/">
        <structure>
               <db>' +  @Application + '</db>
               <cube>' + @Model + '</cube>
               <dims/>
        </structure>
        <BusinessRule Label="' + @Rule +'">
               <BusinessRuleParameter Label="ScenarioMbrs" Dimension="Scenario" Values="" />
               <BusinessRuleParameter Label="TimeMbrs" Dimension="Time" Values="" />
               <BusinessRuleParameter Label="EntityMbrs" Dimension="Entity" Values="" />
        </BusinessRule>
    </runbusinessrule>'

    INSERT INTO [Callisto_Server]..[DataSubmissions]
    (
      UserID,
      Submission,
      ASDatabase,
      ASCube,
      CreateTime,
      CompletionTime
    )
    VALUES
    (   @UserName,       -- UserID - nvarchar(100)
        CAST (CAST(@Submission AS VARBINARY(MAX)) AS IMAGE),      -- Submission - image
        @Application,       -- ASDatabase - nvarchar(100)
        @Model,       -- ASCube - nvarchar(100)
        GETDATE(), -- CreateTime - datetime
        GETDATE())

    EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime,
         @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version,
         @UserName = @UserName

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
