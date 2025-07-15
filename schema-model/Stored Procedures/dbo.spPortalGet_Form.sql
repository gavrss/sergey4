SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Form]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@FormID int = NULL, --Mandatory
	@FormPartID int = NULL,
	@ResultTypeBM int = 31, --1=Main form, 2=Sub forms, 4=Columns, 8=Data, 16=Property lists
	@Menu nvarchar(50) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000743,
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
EXEC [spPortalGet_Form] @ResultTypeBM=1, @DebugBM=3
EXEC [spPortalGet_Form] @UserID=-10, @InstanceID=0, @VersionID=0, @FormID = 0, @DebugBM=3 --Form Setup
EXEC [spPortalGet_Form] @UserID=-10, @InstanceID=527, @VersionID=1055, @FormID = -2, @DebugBM=0 --Consolidation rules
EXEC [spPortalGet_Form] @UserID=-10, @InstanceID=527, @VersionID=1055, @FormID = -3, @DebugBM=0 --FX rules
EXEC [spPortalGet_Form] @UserID=-10, @InstanceID=527, @VersionID=1055, @FormID = -4, @DebugBM=3 --BR14 Counterpart identification
EXEC [spPortalGet_Form] @UserID=-10, @InstanceID=527, @VersionID=1055, @FormID = -5, @DebugBM=0 --IC Matching Rules

EXEC [spPortalGet_Form] @UserID=-2060, @InstanceID=-1335, @VersionID=-1273, @FormID = NULL, @DebugBM=0 --IC Matching Rules

EXEC [spPortalGet_Form] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@SQLSelect nvarchar(max),
	@FormPartName nvarchar(50),
	@DataObjectName nvarchar(100),
	@FormPartColumn nvarchar(50),
	@ValueListType nvarchar(50),
	@ValueList nvarchar(1024),
	@Filter nvarchar(255),

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2171'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get generic form',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2170' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2171' SET @Description = 'Removed @FormID from mandatory parameters.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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
				
		IF @FormID IS NOT NULL
			SELECT
				@Menu = ISNULL(@Menu, [Menu])
			FROM
				pcINTEGRATOR..[Form]
			WHERE
				[InstanceID] IN (0, @InstanceID) AND
				[VersionID] IN (0, @VersionID) AND
				[FormID] = @FormID

		IF @DebugBM & 2 > 0
			SELECT 
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@Menu] = @Menu,
				[@FormID] = @FormID,
				[@FormPartID] = @FormPartID,
				[@ResultTypeBM] = @ResultTypeBM

	SET @Step = 'Create temp tables'
		CREATE TABLE #FormTable
			(
--			[FormID] int,
			[FormName] nvarchar(50) COLLATE DATABASE_DEFAULT,
--			[Menu] nvarchar(50) COLLATE DATABASE_DEFAULT,
--			[Form_ObjectGUIBehaviorBM] int,
			[FormPartID] int,
			[FormPartName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DataObjectName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Filter] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Link] int,
			[FormPart_SortOrder] int,
			[FormPartColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DataObjectColumnName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[KeyYN] bit,
--			[ColumnSet] nvarchar(50) COLLATE DATABASE_DEFAULT,
--			[HelpText] nvarchar(255) COLLATE DATABASE_DEFAULT,
--			[DataTypeID] int,
--			[ObjectGUIBehaviorBM] int,
			[ColumnLink] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[ValueListType] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[ValueList] nvarchar(1024) COLLATE DATABASE_DEFAULT,
--			[VisibleYN] bit,
			[SortOrder] int
			)

		CREATE TABLE #PropertyTable
			(
			[ID] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Name] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[ParentID] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[ValueListParameter] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = '@ResultTypeBM = 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					[ResultTypeBM]=1,
					[FormID],
					[FormName] = [FormName],
					[Menu],
					[ObjectGUIBehaviorBM],
					[SortOrder]
				FROM
					pcINTEGRATOR..[Form]
				WHERE
					[InstanceID] IN (0, @InstanceID) AND
					[VersionID] IN (0, @VersionID) AND
					[SelectYN] <> 0 AND
					([Menu] = @Menu OR @Menu IS NULL)
				ORDER BY
					[Menu],
					[SortOrder]
			END 

	SET @Step = '@ResultTypeBM = 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					[ResultTypeBM]=2,
					[FormID],
					[FormPartID],
					[FormPartName],
					[Link] = [FormPartID_Reference],
					[SortOrder]
				FROM
					pcINTEGRATOR..[FormPart]
				WHERE
					InstanceID IN (0, @InstanceID) AND
					VersionID IN (0, @VersionID) AND				
					FormID = @FormID AND
					([FormPartID] = @FormPartID OR @FormPartID IS NULL)
				ORDER BY
					[SortOrder]
			END 

	SET @Step = '@ResultTypeBM = 4'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM]=4,
					FPC.[FormPartID],
					FPC.[FormPartColumn],
					FPC.[KeyYN],
					FPC.[EnabledYN],
					FPC.[VisibleYN],
					FPC.[ColumnSet],
					FPC.[HelpText],
					FPC.[ShowNullAs],
					FPC.[NullYN],
					DT.[DataTypePortal],
					DT.[GuiObject],
					FPC.[DefaultValue],
					[ColumnLink] = FPC.[FormPartColumn_Reference],
					FPC.[ValueListParameter],
					FPC.[SortOrder]
				FROM
					pcINTEGRATOR..[FormPartColumn] FPC
				INNER JOIN [pcINTEGRATOR].[dbo].[DataType] DT ON DT.[InstanceID] IN (0, FPC.[InstanceID]) AND DT.[DataTypeID] = FPC.[DataTypeID]
				WHERE
					FPC.[InstanceID] IN (0, @InstanceID) AND
					FPC.[VersionID] IN (0, @VersionID) AND				
					FPC.[FormID] = @FormID AND
					(FPC.[FormPartID] = @FormPartID OR @FormPartID IS NULL)
				ORDER BY
					FPC.[FormPartID],
					FPC.[SortOrder]
			END 

SET @Step = 'Fill #FormTable'
		IF @ResultTypeBM & 24 > 0
			BEGIN
				INSERT INTO #FormTable
					(
					[FormName],
					[FormPartID],
					[FormPartName],
					[DataObjectName],
					[Filter],
					[Link],
					[FormPart_SortOrder],
					[FormPartColumn],
					[DataObjectColumnName],
					[KeyYN],
					[ColumnLink],
					[ValueListType],
					[ValueList],
					[SortOrder]
					)
				SELECT
					F.[FormName],
					FP.[FormPartID],
					FP.[FormPartName],
					FP.[DataObjectName],
					FP.[Filter],
					[Link] = [FormPartID_Reference],
					[FormPart_SortOrder] = FP.SortOrder,
					FPC.[FormPartColumn],
					FPC.[DataObjectColumnName],
					FPC.[KeyYN],
					[ColumnLink] = [FormPartColumn_Reference],
					FPC.[ValueListType],
					FPC.[ValueList],
					FPC.[SortOrder]
				FROM
					pcINTEGRATOR..[Form] F
					INNER JOIN pcINTEGRATOR..[FormPart] FP ON
						FP.InstanceID IN (0, @InstanceID) AND
						FP.VersionID IN (0, @VersionID) AND				
						FP.FormID = @FormID AND
						(FP.[FormPartID] = @FormPartID OR @FormPartID IS NULL)
					INNER JOIN pcINTEGRATOR..[FormPartColumn] FPC ON
						FPC.[InstanceID] IN (0, @InstanceID) AND
						FPC.[VersionID] IN (0, @VersionID) AND				
						FPC.[FormID] = FP.[FormID] AND
						FPC.[FormPartID] = FP.[FormPartID]
				WHERE
					F.InstanceID IN (0, @InstanceID) AND
					F.VersionID IN (0, @VersionID) AND
					F.FormID = @FormID

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#FormTable', * FROM #FormTable ORDER BY [FormPart_SortOrder], [SortOrder]
			END

	SET @Step = '@ResultTypeBM = 8'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				IF CURSOR_STATUS('global','FormPart_Cursor') >= -1 DEALLOCATE FormPart_Cursor
				DECLARE FormPart_Cursor CURSOR FOR
			
					SELECT
						[FormPartID],
						[FormPartName],
						[DataObjectName],
						[Filter]
					FROM
						(
						SELECT DISTINCT
							[FormPartID],
							[FormPartName],
							[DataObjectName],
							[Filter],
							[FormPart_SortOrder]
						FROM
							#FormTable
						) sub
					ORDER BY
						[FormPart_SortOrder]


					OPEN FormPart_Cursor
					FETCH NEXT FROM FormPart_Cursor INTO @FormPartID, @FormPartName, @DataObjectName, @Filter

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@FormPartID] = @FormPartID, [@FormPartName] = @FormPartName, [@DataObjectName] = @DataObjectName, [@Filter] = @Filter

							SET @SQLSelect = ''
								
							SELECT
								@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + '[' + [FormPartColumn] + '] = S.[' + [DataObjectColumnName] + '],'
							FROM
								#FormTable
							WHERE
								[FormPartID] = @FormPartID
							ORDER BY
								[SortOrder]

							SET @SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) -1)

							SET @SQLStatement = '
SELECT
[ResultTypeBM] = 8,
[FormPartID] = ' + CONVERT(nvarchar(15), @FormPartID) + ',' + @SQLSelect + '
FROM
' + @DataObjectName + ' S
WHERE
[InstanceID] IN (0, ' + CONVERT(nvarchar(15), @InstanceID) + ') AND
[VersionID] IN (0, ' + CONVERT(nvarchar(15), @VersionID) + ')' + 
CASE WHEN @Filter IS NOT NULL THEN 'AND ' + @Filter ELSE '' END

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC(@SQLStatement)

							FETCH NEXT FROM FormPart_Cursor INTO @FormPartID, @FormPartName, @DataObjectName, @Filter
						END

				CLOSE FormPart_Cursor
				DEALLOCATE FormPart_Cursor
			END 

	SET @Step = '@ResultTypeBM = 16'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				IF CURSOR_STATUS('global','FormPartProperty_Cursor') >= -1 DEALLOCATE FormPartProperty_Cursor
				DECLARE FormPartProperty_Cursor CURSOR FOR
			
					SELECT
						[FormPartID],
						[FormPartColumn],
						[ValueListType],
						[ValueList]
					FROM
						(
						SELECT DISTINCT
							[FormPartID],
							[FormPartColumn],
							[ValueListType],
							[ValueList],
							[FormPart_SortOrder],
							[SortOrder]
						FROM
							#FormTable
						WHERE
							[ValueListType] IS NOT NULL
						) sub
					ORDER BY
						[FormPart_SortOrder],
						[SortOrder]

					OPEN FormPartProperty_Cursor
					FETCH NEXT FROM FormPartProperty_Cursor INTO @FormPartID, @FormPartColumn, @ValueListType, @ValueList

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@FormPartID] = @FormPartID, [@FormPartColumn] = @FormPartColumn, [@ValueListType] = @ValueListType, [@ValueList] = @ValueList

							TRUNCATE TABLE #PropertyTable
							
							IF @ValueListType = 'SP'
								BEGIN
									SET @ValueList = @ValueList + ', @UserID = ' + CONVERT(nvarchar(15), @UserID) + ', @InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ', @VersionID = ' + CONVERT(nvarchar(15), @VersionID)

									SET @SQLStatement = 'INSERT INTO #PropertyTable ([ID], [Name], [Description], [ParentID], [ValueListParameter]) EXEC ' + @ValueList

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SELECT
										[ResultTypeBM] = 16,
										[FormPartID] = @FormPartID,
										[FormPartColumn] = @FormPartColumn,
										[ID],
										[Name],
										[Description],
										[ParentID],
										[ValueListParameter]
									FROM
										#PropertyTable
									ORDER BY
										[Name]
								END

							IF @ValueListType = 'LIMIT'
								BEGIN
									SELECT
										[ResultTypeBM] = 16,
										[FormPartID] = @FormPartID,
										[FormPartColumn] = @FormPartColumn,
										[ID] = [Value] ,
										[Name] = [Value],
										[Description] = [Value],
										[ParentID] = NULL,
										[ValueListParameter] = NULL
									FROM
										STRING_SPLIT (@ValueList, ',')
								END

							FETCH NEXT FROM FormPartProperty_Cursor INTO @FormPartID, @FormPartColumn, @ValueListType, @ValueList
						END

				CLOSE FormPartProperty_Cursor
				DEALLOCATE FormPartProperty_Cursor
			END 

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
