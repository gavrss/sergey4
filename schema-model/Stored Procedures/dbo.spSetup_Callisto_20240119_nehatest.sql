SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Callisto_20240119_nehatest]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBM int = 31, --1=Create XT_tables, 2=Models+Dims, 4=BusinessRules, 8=Users+Security, 16=Deploy to Callisto
	@StartupWorkbook nvarchar(50) = '',
	@CallistoDeployYN bit = 0,
	@AsynchronousYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000576,
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
EXEC [spSetup_Callisto_20240119_nehatest] @UserID=-10, @InstanceID=533, @VersionID=1058, @SequenceBM = 9, @DebugBM = 3
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(MAX),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),	
	@TableCount int,
	@EnhancedStorageYN bit,

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
	@Version nvarchar(50) = '2.1.2.2193'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Callisto based on metadata in pcINTEGRATOR',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Modified NOT EXISTS filter on INSERT query to [XT_HierarchyDefinition] and [XT_HierarchyLevels].'
		IF @Version = '2.1.0.2159' SET @Description = 'Exclude wild joined dimension properties from instance specific properties.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added Step to Deploy Callisto database. Set parameter @StartupWorkbook to empty string.'
		IF @Version = '2.1.0.2163' SET @Description = 'Modified query when inserting to [XT_DimensionDefinition] table, [DefaultHierarchy] column.'
		IF @Version = '2.1.0.2165' SET @Description = 'Added SortOrder for Properties.'
		IF @Version = '2.1.0.2167' SET @Description = 'Added parameter @AsynchronousYN.'
		IF @Version = '2.1.1.2169' SET @Description = 'Exclude DimensionTypeID = 27 from FACT tables.'
		IF @Version = '2.1.2.2191' SET @Description = 'Handle Enhanced Storage.'
		IF @Version = '2.1.2.2193' SET @Description = 'Modified INSERT query to [XT_ModelDefinition] table, [TextSupport] column.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ETLDatabase = A.[ETLDatabase],
			@CallistoDatabase = A.[DestinationDatabase],
			@EnhancedStorageYN = A.[EnhancedStorageYN]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID

		IF @DebugBM & 2 > 0 
			SELECT 
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SequenceBM] = @SequenceBM,
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase,
				[@EnhancedStorageYN] = @EnhancedStorageYN,
				[@JobID] = @JobID

	SET @Step = 'Enhanced Storage'
		IF @EnhancedStorageYN <> 0
			BEGIN
				EXEC [dbo].[spSetup_EnhancedStorage]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@ETLDatabase = @ETLDatabase,
					@CallistoDatabase = @CallistoDatabase,
					@JobID = @JobID,
					@Debug = @DebugSub

				GOTO EnhancedStorage
			END

	SET @Step = '@SequenceBM = 1, Create XT_tables'
		IF @SequenceBM & 1 > 0
			BEGIN
				SET @Step = 'XT_UserDefinition'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[WinUser] [nvarchar](255) NOT NULL,
						[Active] [int] NULL,
						[Email] [nvarchar](255) NULL,
						[UserId] [int] NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_PropertyDefinition'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Dimension] [nvarchar](100) NOT NULL,
						[Label] [nvarchar](100) NOT NULL,
						[DataType] [nvarchar](20) NOT NULL,
						[Size] [int] NULL,
						[DefaultValue] [nvarchar](255) NULL,
						[MemberDimension] [nvarchar](100) NULL,
						[MemberHierarchy] [nvarchar](100) NULL
						)'
				
					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_ModelDimensions'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Model] [nvarchar](100) NOT NULL,
						[Dimension] [nvarchar](100) NOT NULL,
						[HideInExcel] [int] NULL,
						[SendToMemberId] [int] NULL
						)'
				
					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_ModelDefinition'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Label] [nvarchar](100) NOT NULL,
						[Description] [nvarchar](255) NULL,
						[ModelType] [nvarchar](50) NOT NULL,
						[TextSupport] [bit] NULL,
						[ChangeInfo] [bit] NULL,
						[EnableAuditLog] [bit] NULL,
						[StartupWorkbook] [nvarchar](512) NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_BusinessRuleRequestFilters'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Model] [nvarchar](100) NOT NULL,
						[BusinessRule] [nvarchar](255) NOT NULL,
						[Label] [nvarchar](255) NOT NULL,
						[Dimension] [nvarchar](100) NOT NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_ModelAssumptions'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Model] [nvarchar](100) NOT NULL,
						[AssumptionModel] [nvarchar](100) NOT NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_BusinessRule'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Model] [nvarchar](100) NOT NULL,
						[Label] [nvarchar](255) NOT NULL,
						[Description] [nvarchar](255) NULL,
						[Type] [nvarchar](50) NOT NULL,
						[Path] [nvarchar](255) NOT NULL,
						[Text] [nvarchar](max) NOT NULL
						)'
				
					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_BusinessRuleSteps'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Model] [nvarchar](100) NOT NULL,
						[BusinessRule] [nvarchar](255) NOT NULL,
						[Label] [nvarchar](255) NOT NULL,
						[DefinitionLabel] [nvarchar](255) NOT NULL,
						[SequenceNumber] [int] NOT NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_BusinessRuleStepRecords'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Model] [nvarchar](100) NOT NULL,
						[BusinessRule] [nvarchar](255) NOT NULL,
						[BusinessRuleStep] [nvarchar](255) NOT NULL,
						[Label] [nvarchar](255) NOT NULL,
						[SequenceNumber] [int] NOT NULL,
						[Skip] [int] NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_BusinessRuleStepRecordParameters'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Model] [nvarchar](100) NOT NULL,
						[BusinessRule] [nvarchar](255) NOT NULL,
						[BusinessRuleStep] [nvarchar](255) NOT NULL,
						[BusinessRuleStepRecord] [nvarchar](255) NOT NULL,
						[Parameter] [nvarchar](255) NOT NULL,
						[Value] [nvarchar](max) NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_MemberViewDefinition'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Dimension] [nvarchar](100) NOT NULL,
						[Label] [nvarchar](100) NOT NULL,
						[Property] [nvarchar](255) NOT NULL,
						[ViewLevel] [int] NOT NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_HierarchyLevels'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Dimension] [nvarchar](100) NOT NULL,
						[Hierarchy] [nvarchar](100) NOT NULL,
						[LevelName] [nvarchar](100) NOT NULL,
						[SequenceNumber] [int] NOT NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_HierarchyDefinition'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Dimension] [nvarchar](100) NOT NULL,
						[Label] [nvarchar](100) NOT NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_DimensionDefinition'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Label] [nvarchar](100) NOT NULL,
						[Description] [nvarchar](255) NULL,
						[Type] [nvarchar](50) NOT NULL,
						[Secured] [bit] NULL,
						[DefaultHierarchy] [nvarchar](100) NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_SecurityUser'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Role] [nvarchar](100) NOT NULL,
						[WinUser] [nvarchar](255) NULL,
						[WinGroup] [nvarchar](255) NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_SecurityActionAccess'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Role] [nvarchar](100) NOT NULL,
						[Label] [nvarchar](100) NOT NULL,
						[HideAction] [int] NOT NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_SecurityRoleDefinition'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Action] [int] NULL,
						[Label] [nvarchar](100) NOT NULL,
						[Description] [nvarchar](255) NULL,
						[LicenseUserType] [nvarchar](255) NULL,
						[AppLogon] [bit] NOT NULL DEFAULT (1)
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_SecurityMemberAccess'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Role] [nvarchar](100) NOT NULL,
						[Model] [nvarchar](100) NOT NULL,
						[Dimension] [nvarchar](100) NOT NULL,
						[Hierarchy] [nvarchar](100) NULL,
						[Member] [nvarchar](255) NULL,
						[AccessType] [int] NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)

				SET @Step = 'XT_SecurityModelRuleAccess'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''' + @Step + ''''
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT
					IF @TableCount > 0
						BEGIN
							SET @SQLStatement = 'DROP TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']'
							EXEC (@SQLStatement)
						END

					SET @SQLStatement = 'CREATE TABLE [' + @ETLDatabase + '].[dbo].[' + @Step + ']
						(
						[Role] [nvarchar](100) NOT NULL,
						[Model] [nvarchar](100) NOT NULL,
						[Rule] [nvarchar](255) NOT NULL,
						[AllRules] [int] NOT NULL
						)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
			END
/*
	SET @Step = '@SequenceBM = 2, Models+Dims'
		IF @SequenceBM & 2 > 0
			BEGIN
				SET @Step = 'Add Models'
					--XT_ModelDefinition
					SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_ModelDefinition]'
					EXEC (@SQLStatement)
					SET @Deleted = @Deleted + @@ROWCOUNT

					SET @SQLStatement = '
						INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_ModelDefinition]
							(
							[Action],
							[Label],
							[Description],
							[ModelType],
							[TextSupport],
							[ChangeInfo],
							[StartupWorkbook]
							)
						SELECT
							[Action] = NULL,
							[Label] = DC.[DataClassName],
							[Description] = DC.[DataClassDescription],
							[ModelType] = ''Generic'',
							[TextSupport] = CASE WHEN DC.[ModelBM] & 64 > 0 OR DC.[TextSupportYN] <> 0 THEN 1 ELSE 0 END,
							[ChangeInfo] = 0,
							[StartupWorkbook] = ''' + @StartupWorkbook + '''
						FROM
							[pcINTEGRATOR_Data].[dbo].[DataClass] DC
						WHERE
							DC.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							DC.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							DC.[StorageTypeBM] & 4 > 0 AND
							DC.[SelectYN] <> 0 AND
							DC.[DeletedID] IS NULL AND
							NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_ModelDefinition] MD WHERE MD.Label = DC.[DataClassName])'

					IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT
					IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_ModelDefinition'', * FROM [' + @ETLDatabase + '].[dbo].[XT_ModelDefinition] ORDER BY [Label]')

				SET @Step = 'Add dimensions'
					--XT_DimensionDefinition
					SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_DimensionDefinition]'
					EXEC (@SQLStatement)
					SET @Deleted = @Deleted + @@ROWCOUNT
			 
					SET @SQLStatement = '
						INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_DimensionDefinition]
							(
							[Action],
							[Label],
							[Description],
							[Type],
							[Secured],
							[DefaultHierarchy]
							)
						SELECT
							[Action] = NULL,
							[Label] = D.[DimensionName],
							[Description] = D.[DimensionDescription],
							[Type] = DT.[DimensionTypeName],
							[Secured] = CONVERT(nvarchar(15), CONVERT(int, DST.[ReadSecurityEnabledYN])),
							--[DefaultHierarchy] = D.[DimensionName]
							[DefaultHierarchy] = D.[DimensionName] + ''_'' + D.[DimensionName]
						FROM
							[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
							INNER JOIN [Dimension] D ON D.InstanceID IN (0, DST.[InstanceID]) AND D.[DimensionID] = DST.[DimensionID]
							INNER JOIN [DimensionType] DT ON D.InstanceID IN (0, DST.[InstanceID]) AND DT.[DimensionTypeID] = D.[DimensionTypeID]
						WHERE
							DST.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							DST.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							DST.[StorageTypeBM] & 4 > 0 AND
							NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_DimensionDefinition] XT WHERE XT.Label = D.[DimensionName])'

					IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT
					IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_DimensionDefinition'', * FROM [' + @ETLDatabase + '].[dbo].[XT_DimensionDefinition] ORDER BY [Label]')

				SET @Step = 'Add Model dimensions'
					--XT_ModelDimensions
					SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_ModelDimensions]'
					EXEC (@SQLStatement)
					SET @Deleted = @Deleted + @@ROWCOUNT

					SET @SQLStatement = '
						INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_ModelDimensions]
							(
							[Model],
							[Dimension]
							)
						SELECT DISTINCT
							[Model] = DC.[DataClassName],
							[Dimension] = D.[DimensionName]
						FROM
							[pcINTEGRATOR_Data].[dbo].[DataClass] DC
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD ON DCD.InstanceID = DC.[InstanceID] AND DCD.VersionID = DC.[VersionID] AND DCD.DataClassID = DC.DataClassID
							INNER JOIN [Dimension] D ON D.InstanceID IN (0, DCD.[InstanceID]) AND D.[DimensionID] = DCD.[DimensionID] AND D.[DimensionTypeID] <> 27
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST ON DST.InstanceID = DC.[InstanceID] AND DST.VersionID = DC.[VersionID] AND DST.[StorageTypeBM] & 4 > 0
						WHERE
							DC.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							DC.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							DC.[StorageTypeBM] & 4 > 0 AND
							DC.[SelectYN] <> 0 AND
							DC.[DeletedID] IS NULL AND
							NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_ModelDimensions] XT WHERE XT.Model = DC.[DataClassName] AND XT.Dimension = D.[DimensionName])'

					IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT
					IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_ModelDimensions'', * FROM [' + @ETLDatabase + '].[dbo].[XT_ModelDimensions] ORDER BY [Model], [Dimension]')

				SET @Step = 'Add dimension properties'
					--XT_PropertyDefinition
					SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition]'
					EXEC (@SQLStatement)
					SET @Deleted = @Deleted + @@ROWCOUNT

					SET @SQLStatement = '
						INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition]
							(
							[Action],
							[Dimension],
							[Label],
							[DataType],
							[Size],
							[DefaultValue],
							[MemberDimension],
							[MemberHierarchy]
							)
						SELECT
							[Action] = NULL,
							[Dimension],
							[Label],
							[DataType],
							[Size],
							[DefaultValue],
							[MemberDimension],
							[MemberHierarchy]
						FROM
							(
							SELECT DISTINCT
								[Action] = NULL,
								[Dimension] = sub1.[Dimension],
								[Label] = sub1.[Label],
								[DataType] = sub1.[DataType],
								[Size] = sub1.[Size],
								[DefaultValue] = sub1.[DefaultValue],
								[MemberDimension] = sub1.[MemberDimension],
								[MemberHierarchy] = sub1.[MemberHierarchy],
								[SortOrder] = sub1.[SortOrder]
							FROM
								(
								--Dimension specific properties
								SELECT DISTINCT
									[Dimension] = D.[DimensionName],
									[Label] = P.[PropertyName],
									[DataType] = DT.[DataTypeCallisto],
									[Size] = CASE WHEN DT.[SizeYN] <> 0 THEN P.[Size] ELSE ISNULL(P.[Size], 0) END,
									[DefaultValue] = CASE WHEN P.DataTypeID = 3 THEN NULL ELSE P.[DefaultValueTable] END,
									[MemberDimension] = CASE WHEN P.DataTypeID = 3 THEN ISNULL(MD.[DimensionName], D.[DimensionName]) ELSE '''' END,
									[MemberHierarchy] = CASE WHEN P.DataTypeID = 3 THEN ISNULL(MD.[DimensionName], D.[DimensionName]) ELSE '''' END,
									[SortOrder] = DP.[SortOrder]
								FROM
									[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
									INNER JOIN [Dimension] D ON D.InstanceID IN (0, DST.[InstanceID]) AND D.[DimensionID] = DST.[DimensionID] AND D.[SelectYN] <> 0
									INNER JOIN [Dimension_Property] DP ON DP.InstanceID IN (0, DST.[InstanceID]) AND DP.VersionID IN (0, DST.[VersionID]) AND DP.[DimensionID] = DST.[DimensionID] AND DP.[SelectYN] <> 0
									INNER JOIN [Property] P ON P.InstanceID IN (0, DST.[InstanceID]) AND P.[PropertyID] = DP.[PropertyID] AND P.[PropertyID] NOT IN (4, 5, 8) AND P.[SelectYN] <> 0
									INNER JOIN [DataType] DT ON DT.InstanceID IN (0, DST.[InstanceID]) AND DT.[DataTypeID] = P.[DataTypeID]
									LEFT JOIN [Dimension] MD ON MD.InstanceID IN (0, DST.[InstanceID]) AND MD.[DimensionID] = P.[DependentDimensionID] AND MD.[SelectYN] <> 0
								WHERE
									DST.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
									DST.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
									DST.[StorageTypeBM] & 4 > 0'

							SET @SQLStatement = @SQLStatement + '
								--Generic mandatory properties
								UNION SELECT DISTINCT
									[Dimension] = D.[DimensionName],
									[Label] = P.[PropertyName],
									[DataType] = DT.[DataTypeCallisto],
									[Size] = CASE WHEN DT.[SizeYN] <> 0 THEN P.[Size] ELSE ISNULL(P.[Size], 0) END,
									[DefaultValue] = P.[DefaultValueTable],
									[MemberDimension] = CASE WHEN P.DataTypeID = 3 THEN ISNULL(MD.[DimensionName], D.[DimensionName]) ELSE '''' END,
									[MemberHierarchy] = CASE WHEN P.DataTypeID = 3 THEN ISNULL(MD.[DimensionName], D.[DimensionName]) ELSE '''' END,
									[SortOrder] = P.[SortOrder]
								FROM
									[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
									INNER JOIN [Dimension] D ON D.InstanceID IN (0, DST.[InstanceID]) AND D.[DimensionID] = DST.[DimensionID] AND D.[SelectYN] <> 0
									INNER JOIN [@Template_Property] P ON P.InstanceID IN (0) AND P.[MandatoryYN] <> 0 AND P.[PropertyID] NOT IN (4, 5, 8) AND P.[SelectYN] <> 0
									INNER JOIN [DataType] DT ON DT.InstanceID IN (0, DST.[InstanceID]) AND DT.[DataTypeID] = P.[DataTypeID]
									LEFT JOIN [Dimension] MD ON MD.InstanceID IN (0, DST.[InstanceID]) AND MD.[DimensionID] = P.[DependentDimensionID] AND MD.[SelectYN] <> 0
								WHERE
									DST.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
									DST.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
									DST.[StorageTypeBM] & 4 > 0							
								) sub1
							) sub2
						WHERE
							NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition] XT WHERE XT.[Dimension] = sub2.[Dimension] AND XT.[Label] = sub2.[Label])
						ORDER BY
							sub2.[Dimension],
							sub2.[SortOrder],
							sub2.[Label]'

					IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT
					IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_PropertyDefinition'', * FROM [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition] ORDER BY [Dimension], [Label]')

				SET @Step = 'Add Hierarchies'
					--XT_HierarchyDefinition
					SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition]'
					EXEC (@SQLStatement)
					SET @Deleted = @Deleted + @@ROWCOUNT
			 
					SET @SQLStatement = '
						INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition]
							(
							[Action],
							[Dimension],
							[Label]
							)
						SELECT DISTINCT
							[Action] = NULL,
							[Dimension] = D.[DimensionName],
							[Label] = DH.[HierarchyName]
						FROM
							[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
							INNER JOIN [Dimension] D ON D.InstanceID IN (0, DST.[InstanceID]) AND D.[DimensionID] = DST.[DimensionID]
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH ON DH.InstanceID = DST.[InstanceID] AND DH.VersionID = DST.[VersionID] AND DH.[DimensionID] = DST.[DimensionID]
						WHERE
							DST.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							DST.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							DST.[StorageTypeBM] & 4 > 0 AND
							--NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] TDH WHERE TDH.[InstanceID] = 0 AND TDH.[VersionID] = 0 AND TDH.[HierarchyName] = DH.[HierarchyName] AND TDH.[HierarchyNo] = 0 AND TDH.[FixedLevelsYN] = 0) AND
							NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition] XT WHERE XT.[Dimension] = D.[DimensionName] AND XT.[Label] = DH.[HierarchyName])'

					IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT

					SET @SQLStatement = '
						INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition]
							(
							[Action],
							[Dimension],
							[Label]
							)
						SELECT DISTINCT
							[Action] = NULL,
							[Dimension] = D.[DimensionName],
							[Label] = DH.[HierarchyName]
						FROM
							[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
							INNER JOIN [Dimension] D ON D.InstanceID IN (0, DST.[InstanceID]) AND D.[DimensionID] = DST.[DimensionID]
							INNER JOIN [pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] DH ON DH.InstanceID = 0 AND DH.VersionID = 0 AND DH.[DimensionID] = DST.[DimensionID]
						WHERE
							DST.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							DST.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							DST.[StorageTypeBM] & 4 > 0 AND
							--NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] TDH WHERE TDH.[InstanceID] = 0 AND TDH.[VersionID] = 0 AND TDH.[HierarchyName] = DH.[HierarchyName] AND TDH.[HierarchyNo] = 0 AND TDH.[FixedLevelsYN] = 0) AND
							NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition] XT WHERE XT.[Dimension] = D.[DimensionName] AND XT.[Label] = DH.[HierarchyName])'

					IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT
					IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_HierarchyDefinition'', * FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition] ORDER BY [Dimension], [Label]')

				SET @Step = 'Add Hierarchy levels'
					--XT_HierarchyLevels
					SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_HierarchyLevels]'
					EXEC (@SQLStatement)
					SET @Deleted = @Deleted + @@ROWCOUNT
			 
					SET @SQLStatement = '
						INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_HierarchyLevels]
							(
							[Action], 
							[Dimension], 
							[Hierarchy], 
							[LevelName], 
							[SequenceNumber]
							)
						SELECT DISTINCT
							[Action] = NULL,
							[Dimension] = D.[DimensionName],
							[Hierarchy] = DH.[HierarchyName],
							[LevelName] = DHL.[LevelName],
							[SequenceNumber] = DHL.[LevelNo]
						FROM
							[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
							INNER JOIN [Dimension] D ON D.InstanceID IN (0, DST.[InstanceID]) AND D.[DimensionID] = DST.[DimensionID]
							INNER JOIN [DimensionHierarchy] DH ON DH.InstanceID IN (0, DST.[InstanceID]) AND DH.VersionID IN (0, DST.[VersionID]) AND DH.[DimensionID] = DST.[DimensionID]
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL ON DHL.InstanceID = DST.[InstanceID] AND DHL.VersionID = DST.[VersionID] AND DHL.[DimensionID] = DST.[DimensionID] AND DHL.[HierarchyNo] = DH.[HierarchyNo]
						WHERE
							DST.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							DST.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							DST.[StorageTypeBM] & 4 > 0 AND
							--NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] TDH WHERE TDH.[InstanceID] = 0 AND TDH.[VersionID] = 0 AND TDH.[HierarchyName] = DH.[HierarchyName] AND TDH.[HierarchyNo] = 0 AND TDH.[FixedLevelsYN] = 0) AND
							NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyLevels] XT WHERE XT.[Dimension] = D.[DimensionName] AND XT.[Hierarchy] = DH.[HierarchyName] AND XT.[SequenceNumber] = DHL.[LevelNo])'

					IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT

					SET @SQLStatement = '
						INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_HierarchyLevels]
							(
							[Action], 
							[Dimension], 
							[Hierarchy], 
							[LevelName], 
							[SequenceNumber]
							)
						SELECT DISTINCT
							[Action] = NULL,
							[Dimension] = D.[DimensionName],
							[Hierarchy] = DH.[HierarchyName],
							[LevelName] = DHL.[LevelName],
							[SequenceNumber] = DHL.[LevelNo]
						FROM
							[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
							INNER JOIN [Dimension] D ON D.InstanceID IN (0, DST.[InstanceID]) AND D.[DimensionID] = DST.[DimensionID]
							INNER JOIN [DimensionHierarchy] DH ON DH.InstanceID IN (0, DST.[InstanceID]) AND DH.VersionID IN (0, DST.[VersionID]) AND DH.[DimensionID] = DST.[DimensionID]
							INNER JOIN [pcINTEGRATOR].[dbo].[@Template_DimensionHierarchyLevel] DHL ON DHL.InstanceID = 0 AND DHL.VersionID = 0 AND DHL.[DimensionID] = DST.[DimensionID] AND DHL.[HierarchyNo] = DH.[HierarchyNo]
						WHERE
							DST.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
							DST.[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
							DST.[StorageTypeBM] & 4 > 0 AND
							--NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] TDH WHERE TDH.[InstanceID] = 0 AND TDH.[VersionID] = 0 AND TDH.[HierarchyName] = DH.[HierarchyName] AND TDH.[HierarchyNo] = 0 AND TDH.[FixedLevelsYN] = 0) AND
							NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyLevels] XT WHERE XT.[Dimension] = D.[DimensionName] AND XT.[Hierarchy] = DH.[HierarchyName] AND XT.[SequenceNumber] = DHL.[LevelNo])'

					IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + @@ROWCOUNT
					IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_HierarchyLevels'', * FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyLevels] ORDER BY [Dimension], [Hierarchy], [SequenceNumber]')
			END

	SET @Step = '@SequenceBM = 4, BusinessRules'
		IF @SequenceBM & 4 > 0
			BEGIN
				CREATE TABLE [dbo].[#BusinessRule]
					(
					[Action] [int] NULL,
					[Model] [nvarchar](100) NOT NULL,
					[Label] [nvarchar](255) NOT NULL,
					[Description] [nvarchar](255) NULL,
					[Type] [nvarchar](50) NOT NULL,
					[Path] [nvarchar](255) NOT NULL,
					[Text] [nvarchar](max) NOT NULL
					)

				CREATE TABLE [dbo].[#BusinessRuleRequestFilters]
					(
					[Action] [int] NULL,
					[Model] [nvarchar](100) NOT NULL,
					[BusinessRule] [nvarchar](255) NOT NULL,
					[Label] [nvarchar](255) NOT NULL,
					[Dimension] [nvarchar](100) NOT NULL
					)

				CREATE TABLE [dbo].[#BusinessRuleStepRecordParameters]
					(
					[Model] [nvarchar](100) NOT NULL,
					[BusinessRule] [nvarchar](255) NOT NULL,
					[BusinessRuleStep] [nvarchar](255) NOT NULL,
					[BusinessRuleStepRecord] [nvarchar](255) NOT NULL,
					[Parameter] [nvarchar](255) NOT NULL,
					[Value] [nvarchar](max) NULL
					)

				CREATE TABLE [dbo].[#BusinessRuleStepRecords]
					(
					[Model] [nvarchar](100) NOT NULL,
					[BusinessRule] [nvarchar](255) NOT NULL,
					[BusinessRuleStep] [nvarchar](255) NOT NULL,
					[Label] [nvarchar](255) NOT NULL,
					[SequenceNumber] [int] NOT NULL,
					[Skip] [int] NULL
					)

				CREATE TABLE [dbo].[#BusinessRuleSteps]
					(
					[Model] [nvarchar](100) NOT NULL,
					[BusinessRule] [nvarchar](255) NOT NULL,
					[Label] [nvarchar](255) NOT NULL,
					[DefinitionLabel] [nvarchar](255) NOT NULL,
					[SequenceNumber] [int] NOT NULL
					)

				EXEC [spGet_Callisto_BusinessRule]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@JobID = @JobID,
					@Debug = @DebugSub

				--XT_BusinessRule
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRule]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_BusinessRule] SELECT * FROM [#BusinessRule]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_BusinessRule'', * FROM [' + @ETLDatabase + '].[dbo].[XT_BusinessRule] ORDER BY [Model], [Label]')
			 
				--XT_BusinessRuleRequestFilters
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleRequestFilters]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleRequestFilters] SELECT * FROM [#BusinessRuleRequestFilters]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_BusinessRuleRequestFilters'', * FROM [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleRequestFilters] ORDER BY [Model], [BusinessRule], [Label], [Dimension]')
				
				--XT_BusinessRuleStepRecordParameters
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleStepRecordParameters]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleStepRecordParameters] SELECT * FROM [#BusinessRuleStepRecordParameters]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_BusinessRuleStepRecordParameters'', * FROM [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleStepRecordParameters] ORDER BY [Model], [BusinessRule], [BusinessRuleStep]')
				
				--XT_BusinessRuleStepRecords
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleStepRecords]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleStepRecords] SELECT * FROM [#BusinessRuleStepRecords]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_BusinessRuleStepRecords'', * FROM [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleStepRecords] ORDER BY [Model], [BusinessRule], [BusinessRuleStep], [Label]')
				
				--XT_BusinessRuleSteps
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleSteps]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleSteps] SELECT * FROM [#BusinessRuleSteps]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_BusinessRuleSteps'', * FROM [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleSteps] ORDER BY [Model], [BusinessRule], [Label]')
			END
*/
	SET @Step = '@SequenceBM = 8, Users + Security'
		IF @SequenceBM & 8 > 0
			BEGIN
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

				CREATE TABLE [#UserDefinition]
					(
					[Action] [int] NULL,
					[WinUser] [nvarchar](255) NOT NULL,
					[Active] [int] NULL,
					[Email] [nvarchar](255) NULL,
					[UserId] [int] NULL
					)

				CREATE TABLE [#SecurityUser]
					(
					[Role] [nvarchar](100) NOT NULL,
					[WinUser] [nvarchar](255) NULL,
					[WinGroup] [nvarchar](255) NULL
					)

				CREATE TABLE [#SecurityRoleDefinition]
					(
					[Action] [int] NULL,
					[Label] [nvarchar](100) NOT NULL,
					[Description] [nvarchar](255) NULL,
					[LicenseUserType] [nvarchar](255) NULL,
					[AppLogon] [bit] NOT NULL DEFAULT (1)
					)

				CREATE TABLE [#SecurityModelRuleAccess]
					(
					[Role] [nvarchar](100) NOT NULL,
					[Model] [nvarchar](100) NOT NULL,
					[Rule] [nvarchar](255) NOT NULL,
					[AllRules] [int] NOT NULL
					)

				CREATE TABLE [#SecurityMemberAccess]
					(
					[Role] [nvarchar](100) NOT NULL,
					[Model] [nvarchar](100) NOT NULL,
					[Dimension] [nvarchar](100) NOT NULL,
					[Hierarchy] [nvarchar](100) NULL,
					[Member] [nvarchar](255) NULL,
					[AccessType] [int] NULL
					)

				CREATE TABLE [#SecurityActionAccess]
					(
					[Role] [nvarchar](100) NOT NULL,
					[Label] [nvarchar](100) NOT NULL,
					[HideAction] [int] NOT NULL
					)

				EXEC [spGet_Callisto_Security_20240119_nehatest]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@DimensionYN = 0,
					@JobID = @JobID,
					@Debug = @DebugSub

				--XT_UserDefinition
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_UserDefinition]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_UserDefinition] SELECT * FROM [#UserDefinition]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_UserDefinition'', * FROM [' + @ETLDatabase + '].[dbo].[XT_UserDefinition] ORDER BY [WinUser]')

				--XT_SecurityUser
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_SecurityUser]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_SecurityUser] SELECT * FROM [#SecurityUser]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_SecurityUser'', * FROM [' + @ETLDatabase + '].[dbo].[XT_SecurityUser] ORDER BY [Role], [WinUser], [WinGroup]')

				--XT_SecurityRoleDefinition
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_SecurityRoleDefinition]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_SecurityRoleDefinition] SELECT * FROM [#SecurityRoleDefinition]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_SecurityRoleDefinition'', * FROM [' + @ETLDatabase + '].[dbo].[XT_SecurityRoleDefinition] ORDER BY [Label]')

				--XT_SecurityModelRuleAccess
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_SecurityModelRuleAccess]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_SecurityModelRuleAccess] SELECT * FROM [#SecurityModelRuleAccess]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_SecurityModelRuleAccess'', * FROM [' + @ETLDatabase + '].[dbo].[XT_SecurityModelRuleAccess] ORDER BY [Role], [Model], [Rule]')

				--XT_SecurityMemberAccess
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_SecurityMemberAccess]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_SecurityMemberAccess] SELECT * FROM [#SecurityMemberAccess]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_SecurityMemberAccess'', * FROM [' + @ETLDatabase + '].[dbo].[XT_SecurityMemberAccess] ORDER BY [Role], [Model], [Dimension]')

				--XT_SecurityActionAccess
				SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_SecurityActionAccess]'
				EXEC (@SQLStatement)
				SET @Deleted = @Deleted + @@ROWCOUNT
				SET @SQLStatement = 'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_SecurityActionAccess] SELECT * FROM [#SecurityActionAccess]'
				IF @DebugBM & 2 > 0 PRINT (@SQLStatement)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 EXEC('SELECT [Table] = ''XT_SecurityActionAccess'', * FROM [' + @ETLDatabase + '].[dbo].[XT_SecurityActionAccess] ORDER BY [Role], [Label]')
			END
/*
	SET @Step = '@SequenceBM = 16, Deploy to Callisto'
		IF @SequenceBM & 16 > 0
			BEGIN
				SET @Step = 'Create Callisto database'
					IF (SELECT COUNT(1) FROM [CallistoAppDictionary].[dbo].[Applications] WHERE [SqlDbName] = @CallistoDatabase) = 0
						BEGIN
							EXEC [spRun_Job_Callisto_Generic]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepName  = 'Create',
								@AsynchronousYN = 0,
								@MasterCommand = @ProcedureName,
								@JobID = @JobID
						END

				SET @Step = 'Import into Callisto'
					EXEC [spRun_Job_Callisto_Generic]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@StepName  = 'Import',
						@AsynchronousYN = 0,
						@MasterCommand = @ProcedureName,
						@SourceDatabase = @ETLDatabase,
						@JobID = @JobID

				SET @Step = 'Deploy Callisto database'
					IF @CallistoDeployYN <> 0
						EXEC [spRun_Job_Callisto_Generic]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepName = 'Deploy',
								@AsynchronousYN = @AsynchronousYN,
								@MasterCommand = @ProcedureName,
								@JobID = @JobID
			END
*/
		EnhancedStorage:

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
