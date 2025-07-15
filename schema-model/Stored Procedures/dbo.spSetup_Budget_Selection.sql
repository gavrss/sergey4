SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Budget_Selection]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,	--Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000592,
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
EXEC [spSetup_Budget_Selection] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @SourceTypeID = 11, @DebugBM=2
EXEC [spSetup_Budget_Selection] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @SourceTypeID = 8, @DebugBM=2

EXEC [spSetup_Budget_Selection] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@BudgetCodeIDExistsYN bit,
	@BudgetScenario nvarchar(100),

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Budget Selection',
			@MandatoryParameter = 'SourceTypeID' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle old releases of Epicor ERP where column [BudgetCodeID] does not exists in source table [GLBudgetDtl].'
		IF @Version = '2.1.1.2170' SET @Description = 'Read from Instance specific version of TransactionType_iScala.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added COLLATE DATABASE DEFAULT when setting @BudgetScenario.'
		IF @Version = '2.1.1.2174' SET @Description = 'Handle multiple source databases'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-2142: Enable loading of Budget data on initial setup. Updated to latest SP template.'

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

		-- commented next block and added the CURSOR after: 
/*
		SELECT
			@SourceDatabase = S.[SourceDatabase]
		FROM
			pcINTEGRATOR_Data.dbo.[Source] S
			INNER JOIN Model M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.[BaseModelID] = -7 AND M.[SelectYN] <> 0
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SelectYN] <> 0
*/

	SET @Step = 'Get data from Source system'

		IF CURSOR_STATUS('global','CUR1') >= -1 DEALLOCATE CUR1
		DECLARE CUR1 CURSOR
		KEYSET
		FOR 
				SELECT
					 S.[SourceDatabase]
					,S.SourceTypeID
				FROM
					pcINTEGRATOR_Data.dbo.[Source] S
					INNER JOIN Model M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.[BaseModelID] = -7 AND M.[SelectYN] <> 0
				WHERE
					S.[InstanceID] = @InstanceID AND
					S.[VersionID] = @VersionID AND
					S.[SelectYN] <> 0 AND
					(	@SourceTypeID = S.SourceTypeID 
					 OR @SourceTypeID IS NULL
					)	

		OPEN CUR1

		FETCH NEXT FROM CUR1 INTO @SourceDatabase, @SourceTypeID 

		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@SourceDatabase] = @SourceDatabase, [@SourceTypeID] = @SourceTypeID

				IF @SourceTypeID = 1 --Epicor ERP
					BEGIN SELECT @Message = 'Budget Selection is not enabled for Epicor 9', @Severity = 0 GOTO EXITPOINT END

				ELSE IF @SourceTypeID = 3 --iScala
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue]
							(
							[InstanceID],
							[VersionID],
							[EntityID],
							[EntityPropertyTypeID],
							[EntityPropertyValue],
							[SelectYN]
							)
						SELECT DISTINCT
							[InstanceID] = E.[InstanceID],
							[VersionID] = E.[VersionID],
							[EntityID] = E.[EntityID],
							[EntityPropertyTypeID] = -7,
							[EntityPropertyValue] = TTiS.[Scenario],
							[SelectYN] = 1
						FROM
							pcINTEGRATOR_Data..Entity E
							INNER JOIN pcINTEGRATOR_Data..TransactionType_iScala TTiS ON TTiS.[Group] = 'Budget' AND TTiS.SelectYN <> 0
						WHERE
							E.[InstanceID] = @InstanceID AND
							E.[VersionID] = @VersionID AND
							E.[SelectYN] <> 0 AND
							E.[DeletedID] IS NULL AND
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPVD WHERE
								EPVD.[InstanceID] = E.[InstanceID] AND
								EPVD.[VersionID] = E.[VersionID] AND
								EPVD.[EntityID] = E.[EntityID] AND
								EPVD.[EntityPropertyTypeID] = -7 AND
								EPVD.[EntityPropertyValue] = TTiS.[Scenario])
						
						SET @Inserted = @Inserted + @@ROWCOUNT
					END
					
				ELSE IF @SourceTypeID = 7 --SIE4
					BEGIN SELECT @Message = 'Budget Selection is not enabled for SIE4', @Severity = 0 GOTO EXITPOINT END

				ELSE IF @SourceTypeID = 8 --Navision
					BEGIN SELECT @Message = 'Budget Selection is not enabled for Navision', @Severity = 0 GOTO EXITPOINT END

				ELSE IF @SourceTypeID = 11 --Epicor ERP
					BEGIN
						EXEC [spGet_ColumnExistsYN] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @SourceDatabase, @TableName = '[Erp].[GLBudgetDtl]', @ColumnName = 'BudgetCodeID', @ExistsYN = @BudgetCodeIDExistsYN OUT, @JobID = @JobID, @Debug = @DebugSub
						IF @DebugBM & 2 > 0 SELECT [@BudgetCodeIDExistsYN] = @BudgetCodeIDExistsYN

						IF @BudgetCodeIDExistsYN = 0
							SET @BudgetScenario = '''BUDGET_ERP'''
						ELSE
							SET @BudgetScenario = 'BD.[BudgetCodeID] COLLATE DATABASE_DEFAULT'	

						SET @SQLStatement = '
							INSERT INTO [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue]
								(
								[InstanceID],
								[VersionID],
								[EntityID],
								[EntityPropertyTypeID],
								[EntityPropertyValue],
								[SelectYN]
								)
							SELECT DISTINCT
								[InstanceID] = E.[InstanceID],
								[VersionID] = E.[VersionID],
								[EntityID] = E.[EntityID],
								[EntityPropertyTypeID] = -7,
								[EntityPropertyValue] = ' + @BudgetScenario + ',
								[SelectYN] = 1
							FROM
								' + @SourceDatabase + '.[Erp].[GLBudgetDtl] BD
								INNER JOIN pcINTEGRATOR_Data.dbo.Entity E ON E.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.[MemberKey] = BD.[Company] COLLATE DATABASE_DEFAULT
							WHERE
								NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV WHERE
											EPV.[InstanceID] = E.[InstanceID] AND
											EPV.[VersionID] = E.[VersionID] AND
											EPV.[EntityID] = E.[EntityID] AND
											EPV.[EntityPropertyTypeID] = -7 AND
											EPV.[EntityPropertyValue] = ' + @BudgetScenario + ')'
			
						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
						SET @Inserted = @Inserted + @@ROWCOUNT
					END

				ELSE IF @SourceTypeID = 12 --Enterprise
					BEGIN SELECT @Message = 'Budget Selection is not enabled for Enterprise', @Severity = 0 GOTO EXITPOINT END

				ELSE
					BEGIN SELECT @Message = 'Budget Selection is not enabled for selected SourceType (' + CONVERT(nvarchar(15), @SourceTypeID) + ')', @Severity = 0 GOTO EXITPOINT END
			
			END
			FETCH NEXT FROM CUR1 INTO @SourceDatabase, @SourceTypeID
		END

		CLOSE CUR1
		DEALLOCATE CUR1

	SET @Step = 'Show rows'
		IF @DebugBM & 2 > 0
			SELECT [Table] = 'pcINTEGRATOR_Data..EntityPropertyValue', EPV.* 
			FROM [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV
			WHERE EPV.[InstanceID] = @InstanceID AND EPV.[VersionID] = @VersionID AND EPV.EntityPropertyTypeID = -7

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
