SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Source]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL, --Mandatory
	@DemoYN bit = 1,
	@SourceServer nvarchar(100) = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@FiscalYearStartMonth int = 1,
	@StartYear int = NULL,
	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Default Setup',
	@ProductOptionID int = NULL, --In combination with SourceTypeID = -20, specific Model (Optional) will be setup

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000467,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spSetup_Source',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSetup_Source] @UserID=-10, @InstanceID = 476, @VersionID = 1024, @SourceTypeID = 18, @SourceDatabase = 'pcINTEGRATOR_Data_Source_AAS', @ModelingComment = 'Copied from pcIDS', @Debug=1
EXEC [spSetup_Source] @UserID = -1174, @InstanceID = -1001, @VersionID = -1001, @DemoYN = 1, @Debug = 1
EXEC [spSetup_Source] @UserID = -10, @InstanceID = -1427, @VersionID = -1365, @SourceTypeID = -20, @ProductOptionID = 211, @SourceServer = 'DSPSOURCE01', @SourceDatabase = 'ERP10', @Debug = 1

EXEC [spSetup_Source] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID int = -10,
	@SourceVersionID int =-10,
	@SQLStatement nvarchar(max),	
	@ApplicationID int,
	@ApplicationName nvarchar(100),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@ModelID_Financials int,
	@ModelID_Financials_Detail int,
	@ModelID_FxRate int,
	@SourceID_Financials int,
	@SourceID_FxRate int,
	@SourceTypeID_Financials int,
	@TemplateObjectID int = NULL,

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'DoSa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Source, Model, Process',
			@MandatoryParameter = 'SourceTypeID' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Added mandatory parameter @SourceTypeID. Handle ETL, Callisto & pcIDS SourceType.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID. Added @SourceTypeID = -10 for Default Setup.'
		IF @Version = '2.1.0.2165' SET @Description = 'Added @SourceTypeID = 3 for iScala.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle @SourceTypeID = -20; Added parameter @ProductOptionID.'
		IF @Version = '2.1.1.2173' SET @Description = 'Added ObjectTypeBM filter when retrieving [TemplateObjectID] from [dbo].[ProductOption].'
		IF @Version = '2.1.2.2199' SET @Description = 'Added @SourceTypeID = 5 for P21.'

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
		SET @SourceServer = ISNULL(@SourceServer, @@SERVERNAME)

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ApplicationID = [ApplicationID],
			@ApplicationName = [ApplicationName],
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		SET @StartYear = ISNULL(@StartYear, YEAR(GetDate()) - 8)

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceTypeID] = @SourceTypeID,
				[@DemoYN] = @DemoYN,
				[@SourceServer] = @SourceServer,
				[@SourceDatabase] = @SourceDatabase,
				[@FiscalYearStartMonth] = @FiscalYearStartMonth,
				[@StartYear] = @StartYear,
				[@ModelingStatusID] = @ModelingStatusID,
				[@ModelingComment] = @ModelingComment,
				[@JobID] = @JobID

	SET @Step = 'SourceTypeID = -10 (Default setup); SourceTypeID = 3 (iScala); SourceTypeID = 5 (P21); SourceTypeID = 11 (EpicorERP)'
		IF @SourceTypeID IN (-10, 3, 5, 11)
			BEGIN
				--Process
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Process]
					(
					[InstanceID],
					[VersionID],
					[ProcessBM],
					[ProcessName],
					[ProcessDescription],
					[ModelingStatusID],
					[ModelingComment],
					[InheritedFrom],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ProcessBM] = P.[ProcessBM],
					[ProcessName] = P.[ProcessName],
					[ProcessDescription] = P.[ProcessDescription],
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[InheritedFrom] = P.[ProcessID],
					[SelectYN] = P.[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Process] P
				WHERE
					P.[InstanceID] = @SourceInstanceID AND
					P.[VersionID] = @SourceVersionID AND
					P.[SelectYN] <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Process] PD WHERE PD.InstanceID = @InstanceID AND PD.VersionID = @VersionID AND PD.[ProcessName] = P.[ProcessName])

				SET @Inserted = @Inserted + @@ROWCOUNT
				
				--Model
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Model]
					(
					[InstanceID],
					[VersionID],
					[ModelName],
					[ModelDescription],
					[ApplicationID],
					[BaseModelID],
					[ModelBM],
					[ProcessID],
					[ListSetBM],
					[TimeLevelID],
					[TimeTypeBM],
					[OptFinanceDimYN],
					[FinanceAccountYN],
					[TextSupportYN],
					[VirtualYN],
					[DynamicRule],
					[StartupWorkbook],
					[Introduced],
					[InheritedFrom],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ModelName],
					[ModelDescription],
					[ApplicationID] = @ApplicationID,
					[BaseModelID],
					[ModelBM],
					[ProcessID] = 0,
					[ListSetBM],
					[TimeLevelID],
					[TimeTypeBM],
					[OptFinanceDimYN],
					[FinanceAccountYN],
					[TextSupportYN],
					[VirtualYN],
					[DynamicRule],
					[StartupWorkbook],
					[Introduced],
					[InheritedFrom] = M.ModelID,
					[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Model] M
				WHERE
					M.InstanceID = @SourceInstanceID AND
					M.VersionID = @SourceVersionID AND
                    M.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Model] MD WHERE MD.[InstanceID] = @InstanceID AND MD.[VersionID] = @VersionID AND MD.[BaseModelID] IN (-3, -7))
												
				SET @Inserted = @Inserted + @@ROWCOUNT
			
				--Source
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Source]
					(
					[InstanceID],
					[VersionID],
					[SourceName],
					[SourceDescription],
					[BusinessProcess],
					[ModelID],
					[SourceTypeID],
					[SourceDatabase],
					[StartYear],
					[InheritedFrom],
					[SelectYN]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[SourceName] = S.[SourceName],
					[SourceDescription] = S.[SourceDescription],
					[BusinessProcess] = S.[BusinessProcess],
					[ModelID] = M.[ModelID],
					[SourceTypeID] = @SourceTypeID,
					[SourceDatabase] = CASE WHEN @SourceServer = @@SERVERNAME THEN '' ELSE @SourceServer + '.' END + @SourceDatabase,
					[StartYear] = @StartYear,
					[InheritedFrom] = S.SourceID,
					[SelectYN] = S.[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Source] S
					INNER JOIN [pcINTEGRATOR].[dbo].[@Template_Model] TM ON TM.InstanceID = S.InstanceID AND TM.VersionID = S.VersionID AND TM.ModelID = S.ModelID 
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.InstanceID = @InstanceID AND M.VersionID = @VersionID AND M.InheritedFrom = TM.ModelID AND M.ModelName = TM.ModelName
				WHERE
					S.InstanceID = @SourceInstanceID AND
					S.VersionID = @SourceVersionID AND
                    S.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Source] SD WHERE SD.[InstanceID] = @InstanceID AND SD.[VersionID] = @VersionID AND SD.[SourceName] = S.[SourceName])
				
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'SourceTypeID = -20 Optional setup'
		IF @SourceTypeID = -20 AND @ProductOptionID IS NOT NULL
			BEGIN
				SELECT 
					@SourceInstanceID = -20, 
					@SourceVersionID = -20,
					@ModelingComment = 'Optional setup',
					@TemplateObjectID = TemplateObjectID 
				FROM 
					[pcINTEGRATOR].[dbo].[ProductOption] 
				WHERE 
					ProductOptionID = @ProductOptionID AND
					ObjectTypeBM & 1 > 0

				SELECT
					@SourceTypeID_Financials = S.SourceTypeID 
				FROM 
					[pcINTEGRATOR_Data].[dbo].[Source] S
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.InstanceID = S.InstanceID AND M.VersionID = S.VersionID AND M.ModelID = S.ModelID
				WHERE
					S.InstanceID = @InstanceID AND 
					S.VersionID = @VersionID AND
					S.SourceName = 'Financials' AND
					S.SelectYN <> 0

				IF @DebugBM & 2 > 0 SELECT [@SourceInstanceID] = @SourceInstanceID, [@SourceVersionID] = @SourceVersionID, [@TemplateObjectID] = @TemplateObjectID, [@ModelingComment] = @ModelingComment, [@SourceTypeID_Financials] = @SourceTypeID_Financials

				--Process
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Process]
					(
					[InstanceID],
					[VersionID],
					[ProcessBM],
					[ProcessName],
					[ProcessDescription],
					[ModelingStatusID],
					[ModelingComment],
					[InheritedFrom],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ProcessBM] = P.[ProcessBM],
					[ProcessName] = P.[ProcessName],
					[ProcessDescription] = P.[ProcessDescription],
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[InheritedFrom] = P.[ProcessID],
					[SelectYN] = P.[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Process] P
				WHERE
					P.[InstanceID] = @SourceInstanceID AND
					P.[VersionID] = @SourceVersionID AND
					P.[ProcessID] = @TemplateObjectID AND
					P.[SelectYN] <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Process] PD WHERE PD.InstanceID = @InstanceID AND PD.VersionID = @VersionID AND PD.[ProcessName] =  P.[ProcessName])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--Model
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Model]
					(
					[InstanceID],
					[VersionID],
					[ModelName],
					[ModelDescription],
					[ApplicationID],
					[BaseModelID],
					[ModelBM],
					[ProcessID],
					[ListSetBM],
					[TimeLevelID],
					[TimeTypeBM],
					[OptFinanceDimYN],
					[FinanceAccountYN],
					[TextSupportYN],
					[VirtualYN],
					[DynamicRule],
					[StartupWorkbook],
					[Introduced],
					[InheritedFrom],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ModelName],
					[ModelDescription],
					[ApplicationID] = @ApplicationID,
					[BaseModelID],
					[ModelBM],
					[ProcessID] = 0,
					[ListSetBM],
					[TimeLevelID],
					[TimeTypeBM],
					[OptFinanceDimYN],
					[FinanceAccountYN],
					[TextSupportYN],
					[VirtualYN],
					[DynamicRule],
					[StartupWorkbook],
					[Introduced],
					[InheritedFrom] = M.ModelID,
					[SelectYN] = M.SelectYN
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Model] M
					INNER JOIN [pcINTEGRATOR].[dbo].[@Template_Process] P ON P.InstanceID = M.InstanceID AND P.VersionID = M.VersionID AND P.ProcessID = M.ProcessID 
				WHERE
					M.InstanceID = @SourceInstanceID AND
					M.VersionID = @SourceInstanceID AND
					M.ProcessID = @TemplateObjectID AND
                    M.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Model] MD WHERE MD.[InstanceID] = @InstanceID AND MD.[VersionID] = @VersionID AND MD.[ModelName] = P.[ProcessName])
												
				SET @Inserted = @Inserted + @@ROWCOUNT

				--Source
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Source]
					(
					[InstanceID],
					[VersionID],
					[SourceName],
					[SourceDescription],
					[BusinessProcess],
					[ModelID],
					[SourceTypeID],
					[SourceDatabase],
					[StartYear],
					[InheritedFrom],
					[SelectYN]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[SourceName] = S.[SourceName],
					[SourceDescription] = S.[SourceDescription],
					[BusinessProcess] = S.[BusinessProcess],
					[ModelID] = M.[ModelID],
					[SourceTypeID] = @SourceTypeID_Financials,
					[SourceDatabase] = CASE WHEN @SourceServer = @@SERVERNAME THEN '' ELSE @SourceServer + '.' END + @SourceDatabase,
					[StartYear] = @StartYear,
					[InheritedFrom] = S.SourceID,
					[SelectYN] = S.[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Source] S
					INNER JOIN [pcINTEGRATOR].[dbo].[@Template_Model] TM ON TM.InstanceID = S.InstanceID AND TM.VersionID = S.VersionID AND TM.ModelID = S.ModelID 
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.InstanceID = @InstanceID AND M.VersionID = @VersionID AND M.InheritedFrom = TM.ModelID AND M.ModelName = TM.ModelName
				WHERE
					S.InstanceID = @SourceInstanceID AND
					S.VersionID = @SourceVersionID AND
					S.SourceID = @TemplateObjectID AND
                    S.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Source] SD WHERE SD.[InstanceID] = @InstanceID AND SD.[VersionID] = @VersionID AND SD.[SourceName] = S.[SourceName])
				
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'SourceTypeID = 16, pcETL'
		IF @SourceTypeID = 16 --ETL
			BEGIN
				--Model
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Model]
						(
						[InstanceID],
						[VersionID],
						[ModelName],
						[ModelDescription],
						[ApplicationID],
						[BaseModelID],
						[ModelBM],
						[ProcessID],
						[ListSetBM],
						[TimeLevelID],
						[TimeTypeBM],
						[OptFinanceDimYN],
						[FinanceAccountYN],
						[TextSupportYN],
						[VirtualYN],
						[DynamicRule],
						[StartupWorkbook],
						[Introduced],
						[InheritedFrom]
						)
					SELECT
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[ModelName] = XMD.Label,
						[ModelDescription] = XMD.Description,
						[ApplicationID] = ' + CONVERT(nvarchar(15), @ApplicationID) + ',
						[BaseModelID] = ISNULL(TM.BaseModelID, 0),
						[ModelBM] = ISNULL(TM.ModelBM, 0),
						[ProcessID] = 0,
						[ListSetBM] = ISNULL(TM.ListSetBM, 0),
						[TimeLevelID] = ISNULL(TM.TimeLevelID, 0),
						[TimeTypeBM] = ISNULL(TM.TimeTypeBM, 0),
						[OptFinanceDimYN] = ISNULL(TM.OptFinanceDimYN, 0),
						[FinanceAccountYN] = ISNULL(TM.FinanceAccountYN, 0),
						[TextSupportYN] = ISNULL(XMD.TextSupport, 0),
						[VirtualYN] = ISNULL(TM.VirtualYN, 0),
						[DynamicRule] = TM.DynamicRule,
						[StartupWorkbook] = TM.StartupWorkbook,
						[Introduced] = ISNULL(TM.Introduced, 1.2),
						[InheritedFrom] = TM.ModelID
					FROM
						' + @ETLDatabase + '.[dbo].[XT_ModelDefinition] XMD
						LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_Model] TM ON TM.InstanceID = 0 AND TM.VersionID = 0 AND TM.[ModelName] = XMD.Label
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Model] MD WHERE MD.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND MD.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND MD.[ModelName] = XMD.Label)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				--Source
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Source]
						(
						[InstanceID],
						[VersionID],
						[SourceName],
						[SourceDescription],
						[ModelID],
						[SourceTypeID],
						[SourceDatabase],
						[ETLDatabase_Linked],
						[StartYear]
						)
					SELECT
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[SourceName] = XMD.Label,
						[SourceDescription] = XMD.Description,
						[ModelID] = M.ModelID,
						[SourceTypeID] = 11,
						[SourceDatabase] = ''' + CASE WHEN @SourceServer = @@SERVERNAME THEN '' ELSE @SourceServer + '.' END + @SourceDatabase + ''',
						[ETLDatabase_Linked] = ''' + CASE WHEN @SourceServer = @@SERVERNAME THEN '' ELSE @SourceServer + '.' END + 'pcETL_LINKED_' + @ApplicationName + ''',
						[StartYear] = ' + CONVERT(nvarchar(15), @StartYear) + '
					FROM
						' + @ETLDatabase + '.[dbo].[XT_ModelDefinition] XMD
						INNER JOIN [Model] M ON M.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND M.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND M.[ModelName] = XMD.Label
					WHERE
						XMD.Label <> ''Financials_Detail'' AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Source] S WHERE S.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND S.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND S.[SourceName] = XMD.Label)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				--Process
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Process]
						(
						[InstanceID],
						[VersionID],
						[ProcessBM],
						[ProcessName],
						[ProcessDescription],
						[ModelingStatusID],
						[ModelingComment],
						[InheritedFrom]
						)
					SELECT DISTINCT 
						[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15),@VersionID) + ',
						[ProcessBM] = ISNULL(TP.ProcessBM, 0),
						[ProcessName] = XMD.Label,
						[ProcessDescription] = XMD.Description,
						[ModelingStatusID] = ' + CONVERT(nvarchar(15), @ModelingStatusID) + ',
						[ModelingComment] = ''' + @ModelingComment + ''',
						[InheritedFrom] = TP.ProcessID
					FROM 
						' + @ETLDatabase + '.[dbo].[XT_ModelDefinition] XMD
						LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_Process] TP ON TP.InstanceID = ' + CONVERT(nvarchar(15), @SourceInstanceID) + ' AND TP.VersionID = ' + CONVERT(nvarchar(15), @SourceVersionID) + ' AND TP.[ProcessName] = XMD.Label
					WHERE 
						XMD.Label <> ''Financials_Detail'' AND
						NOT EXISTS (SELECT 1 FROM Process P WHERE P.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND P.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND P.ProcessName = XMD.Label)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'SourceTypeID = 17, Callisto'
		IF @SourceTypeID = 17 --Callisto
			BEGIN
				--Model
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Model]
						(
						[InstanceID],
						[VersionID],
						[ModelName],
						[ModelDescription],
						[ApplicationID],
						[BaseModelID],
						[ModelBM],
						[ProcessID],
						[ListSetBM],
						[TimeLevelID],
						[TimeTypeBM],
						[OptFinanceDimYN],
						[FinanceAccountYN],
						[TextSupportYN],
						[VirtualYN],
						[DynamicRule],
						[StartupWorkbook],
						[Introduced],
						[InheritedFrom]
						)
					SELECT
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[ModelName] = M.Label,
						[ModelDescription] = M.Description,
						[ApplicationID] = ' + CONVERT(nvarchar(15), @ApplicationID) + ',
						[BaseModelID] = ISNULL(TM.BaseModelID, 0),
						[ModelBM] = ISNULL(TM.ModelBM, 0),
						[ProcessID] = 0,
						[ListSetBM] = ISNULL(TM.ListSetBM, 0),
						[TimeLevelID] = ISNULL(TM.TimeLevelID, 0),
						[TimeTypeBM] = ISNULL(TM.TimeTypeBM, 0),
						[OptFinanceDimYN] = ISNULL(TM.OptFinanceDimYN, 0),
						[FinanceAccountYN] = ISNULL(TM.FinanceAccountYN, 0),
						[TextSupportYN] = ISNULL(TM.TextSupportYN, 0),
						[VirtualYN] = ISNULL(TM.VirtualYN, 0),
						[DynamicRule] = TM.DynamicRule,
						[StartupWorkbook] = TM.StartupWorkbook,
						[Introduced] = ISNULL(TM.Introduced, 1.2),
						[InheritedFrom] = TM.ModelID
					FROM 
						' + @CallistoDatabase + '.[dbo].[Models] M
						LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_Model] TM ON TM.InstanceID = 0 AND TM.VersionID = 0 AND TM.[ModelName] = M.Label
					WHERE 
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Model] MD WHERE MD.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND MD.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND MD.[ModelName] = M.Label)'
				
				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				--Source
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Source]
						(
						[InstanceID],
						[VersionID],
						[SourceName],
						[SourceDescription],
						[ModelID],
						[SourceTypeID],
						[SourceDatabase],
						[ETLDatabase_Linked],
						[StartYear]
						)
					SELECT
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[SourceName] = MS.Label,
						[SourceDescription] = MS.Description,
						[ModelID] = M.ModelID,
						[SourceTypeID] = 11,
						[SourceDatabase] = ''' + CASE WHEN @SourceServer = @@SERVERNAME THEN '' ELSE @SourceServer + '.' END + @SourceDatabase + ''',
						[ETLDatabase_Linked] = ''' + CASE WHEN @SourceServer = @@SERVERNAME THEN '' ELSE @SourceServer + '.' END + 'pcETL_LINKED_' + @ApplicationName + ''',
						[StartYear] = ' + CONVERT(nvarchar(15), @StartYear) + '
					FROM
						' + @CallistoDatabase + '.[dbo].[Models] MS
						INNER JOIN [Model] M ON M.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND M.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND M.[ModelName] = MS.Label
					WHERE
						MS.Label <> ''Financials_Detail'' AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Source] S WHERE S.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND S.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND S.[SourceName] = MS.Label)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				--Process
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Process]
						(
						[InstanceID],
						[VersionID],
						[ProcessBM],
						[ProcessName],
						[ProcessDescription],
						[ModelingStatusID],
						[ModelingComment],
						[InheritedFrom]
						)
					SELECT DISTINCT 
						[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15),@VersionID) + ',
						[ProcessBM] = ISNULL(TP.ProcessBM, 0),
						[ProcessName] = M.Label,
						[ProcessDescription] = M.Description,
						[ModelingStatusID] = ' + CONVERT(nvarchar(15), @ModelingStatusID) + ',
						[ModelingComment] = ''' + @ModelingComment + ''',
						[InheritedFrom] = TP.ProcessID
					FROM 
						' + @CallistoDatabase + '.[dbo].[Models] M
						LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_Process] TP ON TP.InstanceID = ' + CONVERT(nvarchar(15), @SourceInstanceID) + ' AND TP.VersionID = ' + CONVERT(nvarchar(15), @SourceVersionID) + ' AND TP.[ProcessName] = M.Label
					WHERE 
						M.Label <> ''Financials_Detail'' AND
						NOT EXISTS (SELECT 1 FROM Process P WHERE P.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND P.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND P.ProcessName = M.Label)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'SourceTypeID = 18, pcINTEGRATOR_Data_Source'
		IF @SourceTypeID = 18 --pcINTEGRATOR_Data_Source_*
			BEGIN
				--Model
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Model]
						(
						[InstanceID],
						[VersionID],
						[ModelName],
						[ModelDescription],
						[ApplicationID],
						[BaseModelID],
						[ModelBM],
						[ProcessID],
						[ListSetBM],
						[TimeLevelID],
						[TimeTypeBM],
						[OptFinanceDimYN],
						[FinanceAccountYN],
						[TextSupportYN],
						[VirtualYN],
						[DynamicRule],
						[StartupWorkbook],
						[Introduced],
						[InheritedFrom]
						)
					SELECT
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[ModelName] = SDM.ModelName,
						[ModelDescription] = ISNULL(SDM.ModelDescription, SDM.ModelName),
						[ApplicationID] = ' + CONVERT(nvarchar(15), @ApplicationID) + ',
						[BaseModelID] = SDM.BaseModelID,
						[ModelBM] = SDM.ModelBM,
						[ProcessID] = 0,
						[ListSetBM] = SDM.ListSetBM,
						[TimeLevelID] = SDM.TimeLevelID,
						[TimeTypeBM] = SDM.TimeTypeBM,
						[OptFinanceDimYN] = SDM.OptFinanceDimYN,
						[FinanceAccountYN] = SDM.FinanceAccountYN,
						[TextSupportYN] = SDM.TextSupportYN,
						[VirtualYN] = SDM.VirtualYN,
						[DynamicRule] = SDM.DynamicRule,
						[StartupWorkbook] = SDM.StartupWorkbook,
						[Introduced] = SDM.Introduced,
						[InheritedFrom] = SDM.ModelID
					FROM 
						' + @SourceDatabase + '.[dbo].[Model] SDM
					WHERE 
						SDM.ModelID > 0 AND
						SDM.SelectYN <> 0 AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Model] M WHERE M.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND M.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND M.ModelName = SDM.ModelName)'
				
				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				--Source
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Source]
						(
						[InstanceID],
						[VersionID],
						[SourceName],
						[SourceDescription],
						[ModelID],
						[SourceTypeID],
						[SourceDatabase],
						[ETLDatabase_Linked],
						[StartYear],
						[InheritedFrom]
						)
					SELECT
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[SourceName] = SDB.SourceName,
						[SourceDescription] = ISNULL(SDB.SourceDescription, SDB.SourceName),
						[ModelID] = M.ModelID,
						[SourceTypeID] = SDB.SourceTypeID,
						[SourceDatabase] = SDB.SourceDatabase,
						[ETLDatabase_Linked] = SDB.ETLDatabase_Linked,
						[StartYear] = SDB.StartYear,
						[InheritedFrom] = SDB.SourceID
					FROM
						' + @SourceDatabase + '.[dbo].[Source] SDB
						INNER JOIN [dbo].[SourceType] ST ON ST.SourceTypeID = SDB.SourceTypeID
						INNER JOIN [Model] M ON M.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND M.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND (M.ModelName = SDB.SourceName OR (ST.SourceTypeName + '' - '' + M.ModelName) = SDB.SourceName)
					WHERE
						SDB.SelectYN <> 0 AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Source] S WHERE S.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND S.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND S.[SourceName] = SDB.SourceName)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				--Process
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Process]
						(
						[InstanceID],
						[VersionID],
						[ProcessBM],
						[ProcessName],
						[ProcessDescription],
						[ModelingStatusID],
						[ModelingComment],
						[InheritedFrom]
						)
					SELECT DISTINCT 
						[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15),@VersionID) + ',
						[ProcessBM] = SDP.ProcessBM,
						[ProcessName] = SDP.ProcessName,
						[ProcessDescription] = SDP.ProcessDescription,
						[ModelingStatusID] = ' + CONVERT(nvarchar(15), @ModelingStatusID) + ',
						[ModelingComment] = ''' + @ModelingComment + ''',
						[InheritedFrom] = SDP.ProcessID
					FROM 
						' + @SourceDatabase + '.[dbo].[Process] SDP
					WHERE 
						SDP.ProcessID > 0 AND
						SDP.SelectYN <> 0 AND
						NOT EXISTS (SELECT 1 FROM Process P WHERE P.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND P.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND P.ProcessName = SDP.ProcessName)'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Update Source'
		UPDATE S
		SET 
			[BusinessProcess] = ST.SourceTypeName + '_' + CONVERT(nvarchar(15), S.SourceID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Source] S
			INNER JOIN [dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			S.InstanceID = @InstanceID AND
			S.VersionID = @VersionID AND
			LEN(S.BusinessProcess) = 0

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update ProcessID column for Model'
		UPDATE M									
		SET									
			[ProcessID] = P.ProcessID								
		FROM 									
			[pcINTEGRATOR_Data].[dbo].[Model] M								
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P ON P.InstanceID = M.InstanceID AND P.VersionID = M.VersionID AND P.ProcessName = M.ModelName							
		WHERE 
			M.InstanceID = @InstanceID AND
			M.VersionID = @VersionID AND 
			M.ProcessID = 0	

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Return rows'
		IF @DebugBM & 2 > 0 
			BEGIN
				SELECT [Table] = 'pcINTEGRATOR_Data..Model', * FROM [pcINTEGRATOR_Data].[dbo].[Model] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..Source', * FROM [pcINTEGRATOR_Data].[dbo].[Source] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..Process', * FROM [pcINTEGRATOR_Data].[dbo].[Process] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
			END

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
