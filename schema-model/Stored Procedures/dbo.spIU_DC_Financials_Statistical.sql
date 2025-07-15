SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Financials_Statistical]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StartFiscalYear int = NULL, 
	@Entity_MemberKey nvarchar(50) = NULL,
	@SourceID int = NULL,	
	@FiscalYear int = NULL,	
	@SpeedRunYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000991,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_Financials_Statistical',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "850"},
		{"TKey" : "VersionID",  "TValue": "1260"}
		]'

EXEC [spIU_DC_Financials_Statistical] 
@UserID=-10, @InstanceID=850, @VersionID=1260, @DebugBM=3

EXEC [spIU_DC_Financials_Statistical] @GetVersion = 1

*/

--SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@EntityID int,
	@Book nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@DataClass_StorageTypeBM int,
	@SQLStatement nvarchar(MAX),
	@SourceDB  nvarchar(255),

	@CreateTable_Fact nvarchar(max) = '',
	@SegmentGL nvarchar(max) = '',
	@SegmentGL_ADD nvarchar(max) = '',
	@AccountSegment nvarchar(100),
	@SegmentSQL nvarchar(MAX) = '',
	@SourceCodeSQL nvarchar(MAX),
    @SegmentNames nvarchar(max) = '',
    @SegmentMemberIDs nvarchar(MAX) = '', 
    @SegmentMemberIDSelect nvarchar(max) = '',
    @SegmentDBNames nvarchar(max) = '',
    @SegmentMemberCriteria nvarchar(max) = '',
	@ETLDatabase nvarchar(100),
	@ApplicationID int,
	@SourceTypeID int,


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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'DoSa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Load Statistical accounts data into FACT_Financials table',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

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

		SELECT 
			@DataClass_StorageTypeBM = StorageTypeBM
		FROM
			[pcINTEGRATOR_Data].[dbo].DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassTypeID = -6

		SELECT
			@ApplicationID = ISNULL(@ApplicationID, MAX(ApplicationID))
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

		SELECT
			@SourceDB = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@SourceID = S.SourceID
		FROM
			[pcINTEGRATOR_Data].[dbo].[Source] S
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.ModelBM & 64 > 0 AND M.[SelectYN] <> 0
		WHERE
			S.[InstanceID] = @InstanceID  AND
			S.[VersionID] = @VersionID  AND
			S.[SelectYN] <> 0 AND
			S.[SourceTypeID] = 11


		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.ApplicationID = @ApplicationID AND
			A.SelectYN <> 0

		IF @DebugBM & 2 > 0 
			SELECT
				[@DataClass_StorageTypeBM] = @DataClass_StorageTypeBM,
				[@CallistoDatabase] = @CallistoDatabase

		SELECT 
			@StartFiscalYear = I.StartYear
		FROM	
			[pcINTEGRATOR_Data].[dbo].[Instance] I
		WHERE
			I.InstanceID = @InstanceID 
		

	SET @Step = 'Check if SourceID is 11 or Kinetic'
		IF @SourceTypeID <> 11
			BEGIN
				SET @Message = 'Loading of Statistical Data is valid only for SourceID 11 or Kinetic'
				SET @Severity = 16
				GOTO EXITPOINT
			END


	SET @Step = 'Create and insert into temp table #Entity'

	IF OBJECT_ID('tempdb..#Entity') IS NOT NULL
		DROP TABLE #Entity
		SELECT 
			E.EntityID,
			E.MemberKey,
			EB.Book,
			EB.COA,
			EB.Currency
		INTO
			#Entity
		FROM
			[pcINTEGRATOR].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR].[dbo].[Entity_Book] EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTYpeBM & 3 > 0 AND EB.SelectYN <> 0

		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.SourceID = @SourceID AND
--			E.MemberKey = @Entity_MemberKey AND
			E.SelectYN <> 0

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Entity', * FROM #Entity

	
/*
		SELECT 
			@EntityID = EntityID,
			@Book = Book
		FROM 
			#Entity
*/
	
	SET @Step = 'Create insert into temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			[FiscalYear] int,
			[FiscalPeriod] int,
			[YearMonth] int
			)

    SET @Step = 'Create insert into temp table #FACT_Update'
		CREATE TABLE #FACT_Update
			(
			[BusinessProcess_MemberId] bigint,
			[BusinessRule_MemberId] bigint,
			[Entity_MemberId] bigint,
			[Scenario_MemberId] bigint,
			[Time_MemberId] bigint
			)
  

	SET @Step = 'Entity_Cursor'
		IF CURSOR_STATUS('global','Entity_Cursor') >= -1 DEALLOCATE Entity_Cursor

		DECLARE Entity_Cursor CURSOR FOR
			
			SELECT 
				EntityID,
				Book
			FROM 
				#Entity

			OPEN Entity_Cursor
			FETCH NEXT FROM Entity_Cursor INTO @EntityID, @Book;

			WHILE @@FETCH_STATUS = 0
				BEGIN
--						INSERT INTO #FiscalPeriod
						EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @FiscalYear = @FiscalYear, @StartFiscalYear = @StartFiscalYear, @FiscalPeriod13YN=1, @JobID = @JobID

					FETCH NEXT FROM Entity_Cursor INTO @EntityID, @Book;
				END

		CLOSE Entity_Cursor;
		DEALLOCATE Entity_Cursor;


--		EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @FiscalYear = @FiscalYear, @StartFiscalYear = @StartFiscalYear, @FiscalPeriod13YN=1, @JobID = @JobID

		
		IF @DebugBM & 2 > 0 SELECT * FROM #FiscalPeriod


	SET @Step = 'Stat_Load'
	IF OBJECT_ID('tempdb..#FACT_Financials_Statistical_Raw') IS NOT NULL
	DROP TABLE #FACT_Financials_Statistical_Raw	

		
		SELECT 
			@StartFiscalYear = I.StartYear
		FROM	
			[pcINTEGRATOR_Data].[dbo].[Instance] I
		WHERE 1=1
			AND I.InstanceID = @InstanceID 
			AND I.SelectYN = 1;

		-- Get the Account Segment name
		SELECT DISTINCT @AccountSegment =  SegmentName
		FROM pcINTEGRATOR.dbo.Journal_SegmentNo
		WHERE InstanceID = @InstanceID AND SourceCode = 'SegValue1'

		-- Get the Create GL Segment part
		SELECT DISTINCT @SegmentGL = STUFF( (SELECT ',' + cast('[' + SegmentName + '] nvarchar(200)' as varchar(max)) 
		FROM (
			SELECT DISTINCT SegmentName
			FROM pcINTEGRATOR.dbo.Journal_SegmentNo
			WHERE InstanceID = @InstanceID
			AND VersionID = @VersionID
			AND SelectYN <> 0
		) DS for xml path (''), TYPE).value('.', 'varchar(MAX)'), 1, 1, '');

		
		SELECT DISTINCT @SegmentNames = STUFF( (SELECT ', ' + CAST(SegmentName AS VARCHAR(MAX)) 
		FROM (
   			SELECT DISTINCT SegmentName
   			FROM pcINTEGRATOR.dbo.Journal_SegmentNo
   			WHERE InstanceID = @InstanceID
			AND VersionID = @VersionID
   			AND SourceCode <> 'SegValue1'
			AND SelectYN <> 0
		) DSN FOR XML PATH(''), TYPE).value('.', 'varchar(MAX)'), 1, 2, '');


		-- Get the Create GL Segment MemberIDs
		SELECT DISTINCT @SegmentMemberIDs = STUFF( (SELECT ', ' + CAST(SegmentName + '_MemberId' AS VARCHAR(MAX)) 
		FROM (
   			SELECT DISTINCT SegmentName
   			FROM pcINTEGRATOR.dbo.Journal_SegmentNo
   			WHERE InstanceID = @InstanceID
			AND VersionID = @VersionID
			AND SelectYN <> 0
		) DSMI FOR XML PATH(''), TYPE).value('.', 'varchar(MAX)'), 1, 2, '');

 		
        -- Get the Create GL Segment MemberID Select
		SELECT DISTINCT @SegmentMemberIDSelect = STUFF( (SELECT ', ' + CAST('[' + SegmentName + '_MemberId] = ISNULL([' + SegmentName + '].[MemberId], -1)' as varchar(max)) 
		FROM (
			SELECT DISTINCT SegmentName
			FROM pcINTEGRATOR.dbo.Journal_SegmentNo
			WHERE InstanceID = @InstanceID
			AND VersionID = @VersionID
			AND SelectYN <> 0
		) DSMIS for xml path (''), TYPE).value('.', 'varchar(MAX)'), 1, 2, '');


		-- Get the Segment part
		SELECT DISTINCT @SegmentSQL = STUFF( (SELECT ', ' + CAST('[' + SegmentName + '] = F.' + SourceCode as varchar(max)) 
		FROM (
			SELECT DISTINCT SegmentName, SourceCode
			FROM pcINTEGRATOR.dbo.Journal_SegmentNo
			WHERE InstanceID = @InstanceID AND SourceCode <> 'SegValue1'
			AND VersionID = @VersionID
			AND SelectYN <> 0
		) DSQL for xml path (''), TYPE).value('.', 'varchar(MAX)'), 1, 2, '');


		-- Get the SegValue part
		SELECT DISTINCT @SourceCodeSQL = STUFF( (SELECT ', ' + CAST('F.' + SourceCode as varchar(max)) 
		FROM (
			SELECT DISTINCT SegmentName, SourceCode
			FROM pcINTEGRATOR.dbo.Journal_SegmentNo
			WHERE InstanceID = @InstanceID AND SourceCode <> 'SegValue1'
			AND VersionID = @VersionID
			AND SelectYN <> 0
		)  DSCSQL for xml path (''), TYPE).value('.', 'varchar(MAX)'), 1, 2, '');


		-- Get the Create GL Segment Criteria		
		SELECT DISTINCT @SegmentMemberCriteria = STUFF( (SELECT ' ' + cast('LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' +SegmentName+'] [' +SegmentName +'] ON [' + SegmentName + '].Label COLLATE DATABASE_DEFAULT = [Raw].[' +SegmentName +']' + char(13) as varchar(max)) 
		FROM (
			SELECT DISTINCT SegmentName, SourceCode
			FROM pcINTEGRATOR.dbo.Journal_SegmentNo
			WHERE InstanceID = @InstanceID 
			AND VersionID = @VersionID
			AND SelectYN <> 0
		) DS for xml path (''), TYPE).value('.', 'varchar(MAX)'), 1, 1, '');

   		
		
		CREATE TABLE #FACT_Financials_Statistical_Raw
			(
			[BusinessProcess] nvarchar(255),
			[BusinessRule] nvarchar(255),
			[Currency] nvarchar(255),
			[Entity] nvarchar(255),
			[Flow] nvarchar(255),
			[LineItem] nvarchar(255),
			[Scenario] nvarchar(255),
			[Time] nvarchar(255),
			[TimeDataView] nvarchar(255),
			[Version] nvarchar(255),
			[WorkflowState] nvarchar(255),
			[Financials_Value] nvarchar(255)	
			);

	IF @DebugBM & 2 > 0 SELECT [TempTable] = '#FACT_Financials_Statistical_Raw', * FROM #FACT_Financials_Statistical_Raw

	SET @SegmentGL_ADD = 'ALTER TABLE #FACT_Financials_Statistical_Raw ADD ' + @SegmentGL 

	EXEC sp_executesql @SegmentGL_ADD


		SET @SQLStatement = '
			INSERT INTO #FACT_Financials_Statistical_Raw (' + @AccountSegment + ', BusinessProcess, BusinessRule, Currency, Entity, Flow, ' + @SegmentNames + ', LineItem, Scenario, Time, TimeDataView, Version, WorkflowState, Financials_Value)           
			SELECT
				' + @AccountSegment + ' =''ST_'' + F.SegValue1, 
				[BusinessProcess] = ''E10_Stat'',
				[BusinessRule] = ''NONE'',
				[Currency] = E.Currency,
				[Entity] = E.MemberKey, 
				[Flow] = ''NONE'', 
				' + @SegmentSQL + ',
				[LineItem] = ''NONE'',
				[Scenario] = ''ACTUAL'',
				[Time] = CONVERT(nvarchar, FP.Yearmonth),
				[TimeDataView] = ''RAWDATA'',
				[Version] = ''NONE'',
				[WorkflowState] = ''NONE'',
				[Financials_Value] = SUM(F.StatAmount)			
			FROM ' + @SourceDB  +'.[Erp].[GLJrnDtl] F			
			INNER JOIN #Entity E ON E.MemberKey = F.Company COLLATE DATABASE_DEFAULT AND E.Book = F.BookID COLLATE DATABASE_DEFAULT			
			INNER JOIN #FiscalPeriod FP ON FP.FiscalYear = F.FiscalYear	AND FP.FiscalPeriod = F.FiscalPeriod
			INNER JOIN (
					SELECT
						Company = Company COLLATE DATABASE_DEFAULT,
						COACode = COACode COLLATE DATABASE_DEFAULT
					FROM
						' + @SourceDB  +'.[Erp].[COASegment]
					GROUP BY
						Company,
						COACode
						) COA ON COA.Company = F.Company AND COA.COACode COLLATE DATABASE_DEFAULT = E.COA
			WHERE F.FiscalYear >=  ' + CAST(@StartFiscalYear  AS NVARCHAR) +'			
			GROUP BY F.SegValue1, E.Currency, E.MemberKey, ' + @SourceCodeSQL + ',
				CONVERT(NVARCHAR, FP.YearMonth)			
			HAVING SUM(F.StatAmount) <> 0' 	

	EXEC sp_executesql @SQLStatement

	IF @DebugBM & 2 > 0 SELECT [TempTable] = '#FACT_Financials_Statistical_Raw', '['+ Entity +']' as Entity, '['+ Time +']' as Time, * FROM #FACT_Financials_Statistical_Raw   
	
	SET @Step = 'Create #FACT_Update'
	
	SET @SQLStatement = '
		INSERT INTO #FACT_Update ([BusinessProcess_MemberId],[BusinessRule_MemberId],[Entity_MemberId],[Scenario_MemberId],[Time_MemberId])
        SELECT DISTINCT
			[BusinessProcess_MemberId] = [BusinessProcess].[MemberId],
			[BusinessRule_MemberId] = [BusinessRule].[MemberId],
			[Entity_MemberId] = [Entity].[MemberId],
			[Scenario_MemberId] = [Scenario].[MemberId],
			[Time_MemberId] = [Time].[MemberId]		
		FROM
			#FACT_Financials_Statistical_Raw [Raw]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessProcess] [BusinessProcess] ON [BusinessProcess].[Label] COLLATE DATABASE_DEFAULT = [Raw].[BusinessProcess]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessRule] [BusinessRule] ON [BusinessRule].[Label] COLLATE DATABASE_DEFAULT = [Raw].[BusinessRule]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Entity] [Entity] ON [Entity].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Entity]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Scenario] [Scenario] ON [Scenario].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Scenario]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Time] [Time] ON [Time].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Time]'
        
		EXEC sp_executesql @SQLStatement

		IF @DebugBM & 2 > 0 
		BEGIN
	   	  SET @SQLStatement = '
			SELECT 
				[TempTable] = ''#FACT_Update'', 
				F.[BusinessProcess_MemberId],
				[BusinessProcess].[Label],
				F.[BusinessRule_MemberId],
				[BusinessRule].[Label],
				F.[Entity_MemberId],
				[Entity].[Label],
				F.[Scenario_MemberId],
				[Scenario].[Label],
				F.[Time_MemberId],
				[Time].[Label]
			FROM 
				#FACT_Update F
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessProcess] [BusinessProcess] ON [BusinessProcess].[MemberId] = F.[BusinessProcess_MemberId]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessRule] [BusinessRule] ON [BusinessRule].[MemberId] = F.[BusinessRule_MemberId]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Entity] [Entity] ON [Entity].[MemberId] = F.[Entity_MemberId]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Scenario] [Scenario] ON [Scenario].[MemberId] = F.[Scenario_MemberId]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Time] [Time] ON [Time].[MemberId] = F.[Time_MemberId]
			ORDER BY
				F.[Time_MemberId]'

		  EXEC sp_executesql @SQLStatement

		END
/*

		SET @Step = 'Set all existing rows that should be inserted to 0'
		IF @DataClass_StorageTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					UPDATE
						F
					SET
						[Financials_Value] = 0
					FROM
						' + @CallistoDatabase + '.[dbo].[FACT_Financials_default_partition] F
						INNER JOIN [#FACT_Update] V ON
										V.[BusinessProcess_MemberId] = F.[BusinessProcess_MemberId] AND
										V.[BusinessRule_MemberId] = F.[BusinessRule_MemberId] AND
										V.[Entity_MemberId] = F.[Entity_MemberId] AND
										V.[Scenario_MemberId] = F.[Scenario_MemberId] AND
										V.[Time_MemberId] = F.[Time_MemberId]'
			
				
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Updated = @Updated + @@ROWCOUNT
			END        

		SET @Step = 'Insert Statistical transactions into FACT_Financials table'


        SET @SQLStatement = '
		INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_Financials_default_partition]
			(
			[BusinessProcess_MemberId],
			[BusinessRule_MemberId],
			[Currency_MemberId],
			[Entity_MemberId],
			[Flow_MemberId],
			[LineItem_MemberId],
			[Scenario_MemberId],
			[Time_MemberId],
			[TimeDataView_MemberId],
			[Version_MemberId],
			[WorkflowState_MemberId],
            ' + @SegmentMemberIDs + ',
			[Financials_Value],
			[ChangeDatetime],
			[Userid]
			)
		SELECT
			[BusinessProcess_MemberId] = ISNULL([BusinessProcess].[MemberId], -1),
			[BusinessRule_MemberId] = ISNULL([BusinessRule].[MemberId], -1),
			[Currency_MemberId] = ISNULL([Currency].[MemberId], -1),
			[Entity_MemberId] = ISNULL([Entity].[MemberId], -1),
			[Flow_MemberId] = ISNULL([Flow].[MemberId], -1),
			[LineItem_MemberId] = ISNULL([LineItem].[MemberId], -1),
			[Scenario_MemberId] = ISNULL([Scenario].[MemberId], -1),
			[Time_MemberId] = ISNULL([Time].[MemberId], -1),
			[TimeDataView_MemberId] = ISNULL([TimeDataView].[MemberId], -1),
			[Version_MemberId] = ISNULL([Version].[MemberId], -1),
			[WorkflowState_MemberId] = ISNULL([WorkflowState].[MemberId], -1),
            ' + @SegmentMemberIDSelect + ',
			[Financials_Value] = [Raw].[Financials_Value],
			[ChangeDatetime] = GETDATE(),
			[Userid] = ''' + @UserName + '''	
		FROM
			[#FACT_Financials_Statistical_Raw] [Raw]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessProcess] [BusinessProcess] ON [BusinessProcess].Label COLLATE DATABASE_DEFAULT = [Raw].[BusinessProcess]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessRule] [BusinessRule] ON [BusinessRule].Label COLLATE DATABASE_DEFAULT = [Raw].[BusinessRule]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Currency] [Currency] ON [Currency].Label COLLATE DATABASE_DEFAULT = [Raw].[Currency]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Entity] [Entity] ON [Entity].Label COLLATE DATABASE_DEFAULT = [Raw].[Entity]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Flow] [Flow] ON [Flow].Label COLLATE DATABASE_DEFAULT = [Raw].[Flow]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_LineItem] [LineItem] ON [LineItem].Label COLLATE DATABASE_DEFAULT = [Raw].[LineItem]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Scenario] [Scenario] ON [Scenario].Label COLLATE DATABASE_DEFAULT = [Raw].[Scenario]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Time] [Time] ON [Time].Label COLLATE DATABASE_DEFAULT = [Raw].[Time]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_TimeDataView] [TimeDataView] ON [TimeDataView].Label COLLATE DATABASE_DEFAULT = [Raw].[TimeDataView]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Version] [Version] ON [Version].Label COLLATE DATABASE_DEFAULT = [Raw].[Version]
			LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_WorkflowState] [WorkflowState] ON [WorkflowState].Label COLLATE DATABASE_DEFAULT = [Raw].[WorkflowState]
            ' +  @SegmentMemberCriteria + ''

		EXEC sp_executesql @SQLStatement
   

	SET @Step = 'Clean up'
		IF (SELECT DATEPART(WEEKDAY, GETDATE())) IN (6, 7) OR @SpeedRunYN = 0 --Saturday, Sunday or not SpeedRun
			BEGIN
				IF @DataClass_StorageTypeBM & 4 > 0
					BEGIN
						SET @SQLStatement = '
							DELETE
								F
							FROM
								' + @CallistoDatabase + '.[dbo].[FACT_Financials_default_partition] F
							WHERE
								[Financials_Value] = 0'
					END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Deleted = @Deleted + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #FACT_Financials_Statistical_Raw
		DROP TABLE #FACT_Update
		DROP TABLE #Entity
*/
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
