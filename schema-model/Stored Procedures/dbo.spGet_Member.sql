SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Member]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SourceID int = NULL,
	@DimensionID int = NULL,
	@Dimension nvarchar(50) = NULL,
	@SQLStatement3_01 nvarchar(max) = NULL OUT,
	@SQLStatement3_02 nvarchar(max) = NULL OUT,
	@SQLStatement3_03 nvarchar(max) = NULL OUT,
	@SQLStatement3_04 nvarchar(max) = NULL OUT,
	@SQLStatement3_05 nvarchar(max) = NULL OUT,
	@SQLStatement3_06 nvarchar(max) = NULL OUT,
	@SQLStatement3_07 nvarchar(max) = NULL OUT,
	@SQLStatement3_08 nvarchar(max) = NULL OUT,
	@SQLStatement3_09 nvarchar(max) = NULL OUT,
	@SQLStatement3_10 nvarchar(max) = NULL OUT,
	@SQLStatement3_11 nvarchar(max) = NULL OUT,
	@SQLStatement3_12 nvarchar(max) = NULL OUT,
	@SQLStatement3_13 nvarchar(max) = NULL OUT,
	@SQLStatement3_14 nvarchar(max) = NULL OUT,
	@SQLStatement3_15 nvarchar(max) = NULL OUT,
	@SQLStatement3_16 nvarchar(max) = NULL OUT,
	@SQLStatement3_17 nvarchar(max) = NULL OUT,
	@SQLStatement3_18 nvarchar(max) = NULL OUT,
	@SQLStatement3_19 nvarchar(max) = NULL OUT,
	@SQLStatement3_20 nvarchar(max) = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000077,
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
EXEC spGet_Member @SourceID = -1605 , @DimensionID = 0, @Dimension = 'GL_Cost_Center', @Debug = 1
EXEC spGet_Member @SourceID = 2018 , @DimensionID = -65, @Debug = 1

DECLARE	@SQLStatement3_01 nvarchar(max) = '', @SQLStatement3_02 nvarchar(max) = '', @SQLStatement3_03 nvarchar(max) = '', @SQLStatement3_04 nvarchar(max) = '', @SQLStatement3_05 nvarchar(max) = '',
		@SQLStatement3_06 nvarchar(max) = '', @SQLStatement3_07 nvarchar(max) = '', @SQLStatement3_08 nvarchar(max) = '', @SQLStatement3_09 nvarchar(max) = '', @SQLStatement3_10 nvarchar(max) = '',
		@SQLStatement3_11 nvarchar(max) = '', @SQLStatement3_12 nvarchar(max) = '', @SQLStatement3_13 nvarchar(max) = '', @SQLStatement3_14 nvarchar(max) = '', @SQLStatement3_15 nvarchar(max) = '',
		@SQLStatement3_16 nvarchar(max) = '', @SQLStatement3_17 nvarchar(max) = '', @SQLStatement3_18 nvarchar(max) = '', @SQLStatement3_19 nvarchar(max) = '', @SQLStatement3_20 nvarchar(max) = ''

EXEC spGet_Member @SourceID = -1605, @DimensionID = -63, 
		@SQLStatement3_01 = @SQLStatement3_01 OUT, @SQLStatement3_02 = @SQLStatement3_02 OUT, @SQLStatement3_03 = @SQLStatement3_03 OUT, @SQLStatement3_04 = @SQLStatement3_04 OUT, @SQLStatement3_05 = @SQLStatement3_05 OUT,
		@SQLStatement3_06 = @SQLStatement3_06 OUT, @SQLStatement3_07 = @SQLStatement3_07 OUT, @SQLStatement3_08 = @SQLStatement3_08 OUT, @SQLStatement3_09 = @SQLStatement3_09 OUT, @SQLStatement3_10 = @SQLStatement3_10 OUT,
		@SQLStatement3_11 = @SQLStatement3_11 OUT, @SQLStatement3_12 = @SQLStatement3_12 OUT, @SQLStatement3_13 = @SQLStatement3_13 OUT, @SQLStatement3_14 = @SQLStatement3_14 OUT, @SQLStatement3_15 = @SQLStatement3_15 OUT, 
		@SQLStatement3_16 = @SQLStatement3_16 OUT, @SQLStatement3_17 = @SQLStatement3_17 OUT, @SQLStatement3_18 = @SQLStatement3_18 OUT, @SQLStatement3_19 = @SQLStatement3_19 OUT, @SQLStatement3_20 = @SQLStatement3_20 OUT, @Debug = 1

		PRINT @SQLStatement3_01 PRINT @SQLStatement3_02 PRINT @SQLStatement3_03 PRINT @SQLStatement3_04 PRINT @SQLStatement3_05
		PRINT @SQLStatement3_06 PRINT @SQLStatement3_07 PRINT @SQLStatement3_08 PRINT @SQLStatement3_09 PRINT @SQLStatement3_10
		PRINT @SQLStatement3_11 PRINT @SQLStatement3_12 PRINT @SQLStatement3_13 PRINT @SQLStatement3_14 PRINT @SQLStatement3_15
		PRINT @SQLStatement3_16 PRINT @SQLStatement3_17 PRINT @SQLStatement3_18 PRINT @SQLStatement3_19 PRINT @SQLStatement3_20

EXEC [spGet_Member] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@Union nvarchar(50),
	@DimensionName nvarchar(50),
	@ModelBM int,
	@ModelBMString nvarchar(100),
	@SourceTypeBM int,
	@SourceTypeBMString nvarchar(100),
	@SourceTypeBM_All int,
	@Label nvarchar(100),
	@RNodeType nvarchar(10),
	@HelpText nvarchar(1024),
	@Parent nvarchar(100),
	@Member nvarchar(max),
	@AllYN bit,
	@All_Dimension nvarchar(100),
	@ApplicationID int,
	@ETLDatabase nvarchar(100),
	@MemberID int,
	@SourceType nvarchar(50) = 'ETL',
	@GenericYN bit,
	@Counter int = 0,
	@CharCounter int,
	@CharCounterResidual int,
	@SQLStatement nvarchar(max) = '',
	@StorageTypeBM int = 4,  -- Should be dynamic or pass as parameter

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.3.2152'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return static rows',
			@MandatoryParameter = '@SourceID|DimensionID|SQLStatement3_01|SQLStatement3_02|SQLStatement3_03|SQLStatement3_04|SQLStatement3_05|SQLStatement3_06|SQLStatement3_07|SQLStatement3_08|SQLStatement3_09|SQLStatement3_10|SQLStatement3_11|SQLStatement3_12|SQLStatement3_13|SQLStatement3_14|SQLStatement3_15|SQLStatement3_16|SQLStatement3_17|SQLStatement3_18|SQLStatement3_19|SQLStatement3_20' --Without @, separated by |

		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2067' SET @Description = 'Returned SQL-string is splitted into 15 pieces.'
		IF @Version = '1.3.2071' SET @Description = 'Filter PropertyID NOT BETWEEN 100 AND 1000. Handle @SourceID = 0'
		IF @Version = '1.3.2083' SET @Description = 'Get Base value; left join to Source'
		IF @Version = '1.3.2092' SET @Description = 'Change filter to be dependent on SourceID'
		IF @Version = '1.3.2094' SET @Description = 'Check on Introduced'
		IF @Version = '1.3.2095' SET @Description = 'Added RNodeType'
		IF @Version = '1.3.2101' SET @Description = 'Check on AllYN'
		IF @Version = '1.3.2109' SET @Description = 'Fixed MemberIDs for all Static Members. Increased number of parameters from 15 to 20.'
		IF @Version = '1.3.2116' SET @Description = 'Handle HelpText. Handle unicode for strings.'
		IF @Version = '1.3.1.2121' SET @Description = 'Check for duplicates in Label.'
		IF @Version = '1.4.0.2139' SET @Description = 'Exclude NodeTypeBM.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2147' SET @Description = 'Include properties defined in table Dimension_Property.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-300: Removed reference to Property.DimensionID.'

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
			@UserID = ISNULL(@UserID, -10),
			@InstanceID = ISNULL(@InstanceID, A.InstanceID),
			@VersionID = ISNULL(@VersionID, A.VersionID)
		FROM
			[Application] A
			INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SourceID = @SourceID AND S.SelectYN <> 0
		WHERE
			 A.SelectYN <> 0

		SELECT 
			@AllYN = AllYN
		FROM
			Dimension
		WHERE
			DimensionID = @DimensionID

		IF @SourceID = 0
			SELECT DISTINCT
				@ApplicationID = M.ApplicationID
			FROM
				Model_Dimension MD 
				INNER JOIN Model BM ON BM.ModelID = MD.ModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
				INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.SelectYN <> 0
			WHERE
				MD.DimensionID = @DimensionID AND
				MD.Introduced < @Version AND
				MD.SelectYN <> 0
		ELSE
			SELECT
				@ApplicationID = M.ApplicationID
			FROM
				Model M
				INNER JOIN Source S ON S.SourceID = @SourceID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
			WHERE
				M.SelectYN <> 0

		SELECT
			@DimensionName = MAX(CASE WHEN @DimensionID = 0 THEN ISNULL(@Dimension, D.DimensionName) ELSE D.DimensionName END),
			@ModelBM = SUM(BM.ModelBM),
			@SourceTypeBM = ISNULL(SUM(ST.SourceTypeBM), 2048),
			@ETLDatabase = MAX(A.ETLDatabase),
			@GenericYN = MAX(CONVERT(int, D.GenericYN))
		FROM
			[Application] A 
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.Introduced < @Version AND MD.SelectYN <> 0
			INNER JOIN Dimension D ON (D.DimensionID = @DimensionID AND D.DimensionID = MD.DimensionID AND D.SelectYN <> 0) OR (@DimensionID = 0 AND D.DimensionID = 0)
			INNER JOIN [Language] L ON L.LanguageID = A.LanguageID
			INNER JOIN [Source] S ON S.SourceID = CASE WHEN D.GenericYN <> 0 THEN 0 ELSE @SourceID END AND (S.ModelID = M.ModelID OR D.GenericYN <> 0)
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			A.ApplicationID = @ApplicationID

		SELECT
			@SourceTypeBM_All = SUM(sub.SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				ST.SourceTypeBM
			FROM
				SourceType ST
				INNER JOIN [Source] S ON S.SourceTypeID = ST.SourceTypeID AND S.SelectYN <> 0
				INNER JOIN Model M ON M.ModelID = S.ModelID AND M.Introduced < @Version AND M.SelectYN <> 0 AND M.ApplicationID = @ApplicationID
			WHERE
				ST.SelectYN <> 0 AND
				ST.Introduced < @Version
			) sub

		SELECT
			@StorageTypeBM = StorageTypeBM
		FROM
			Dimension_StorageType
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @Debug <> 0
			SELECT
				ApplicationID = @ApplicationID,
				DimensionName = @DimensionName,
				ModelBM = @ModelBM,
				SourceTypeBM = @SourceTypeBM,
				ETLDatabase = @ETLDatabase,
				[Version] = @Version,
				DimensionID = @DimensionID,
				SourceID = @SourceID,
				Dimension = @Dimension,
				AllYN = @AllYN,
				StorageTypeBM = @StorageTypeBM

	SET @Step = 'Set other variables'
		IF @GenericYN <> 0 AND @SourceID <> 0 --RESET @ModelBM & @SourceTypeBM
			BEGIN
				SELECT
					@ModelBMString = CASE WHEN @ModelBMString IS NULL THEN '' ELSE @ModelBMString + '|' END + CONVERT(nvarchar, BM.ModelBM),
					@SourceTypeBMString = CASE WHEN @SourceTypeBMString IS NULL THEN '' ELSE @SourceTypeBMString + '|' END + CONVERT(nvarchar, ST.SourceTypeBM)
				FROM
					Model M 
					INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0	
					INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.Introduced < @Version AND MD.SelectYN <> 0
					INNER JOIN Dimension D ON (D.DimensionID = @DimensionID AND D.DimensionID = MD.DimensionID AND D.Introduced < @Version AND D.SelectYN <> 0) OR (@DimensionID = 0 AND D.DimensionID = 0)
					INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0	
					INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0	
				WHERE
					M.ApplicationID = @ApplicationID AND
					M.SelectYN <> 0

				SET @SQLStatement = @SQLStatement + 'SELECT @InternalVariable = ' + @ModelBMString	
				EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ModelBM OUT

				SET @SQLStatement = CONVERT(nvarchar(max), '')
				SET @SQLStatement = @SQLStatement + 'SELECT @InternalVariable = ' + @SourceTypeBMString	
				EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @SourceTypeBM OUT
			END

		IF @Debug <> 0
			SELECT
				ApplicationID = @ApplicationID,
				DimensionName = @DimensionName,
				ModelBM = @ModelBM,
				SourceTypeBM = @SourceTypeBM,
				ETLDatabase = @ETLDatabase

	SET @Step = 'Create return values'
		CREATE TABLE [dbo].[#Property](
			[DimensionID] int NOT NULL,
			[PropertyID] int NOT NULL,
			[PropertyName] [nvarchar](100) NOT NULL,
			[DataTypeID] int NULL,
			[DefaultValueView] [nvarchar](255) NULL,
			[SortOrder] int NULL
		)
	
		SET @SQLStatement = CONVERT(nvarchar(max), '')
		SET @SQLStatement = @SQLStatement + '
			INSERT INTO #Property
			(
				[DimensionID],
				[PropertyID],
				[PropertyName],
				[DataTypeID],
				[DefaultValueView],
				[SortOrder]
			)
			SELECT DISTINCT
				[DimensionID] = ISNULL(DP.DimensionID, P.[DimensionID]),
				P.PropertyID,
				PropertyName = ISNULL(MO.[MappedObjectName], P.PropertyName),
				P.[DataTypeID],
				[DefaultValueView] = P.[DefaultValueView],
				[SortOrder] = P.SortOrder
			FROM
				Property P
				INNER JOIN Dimension_Property DP ON DP.PropertyID = P.PropertyID
				INNER JOIN SqlSource_Dimension SSD ON (SSD.DimensionID = P.DimensionID AND SSD.SourceTypeBM & ' + CONVERT(nvarchar, @SourceTypeBM) + ' > 0 AND SSD.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND SSD.PropertyID = P.PropertyID AND SSD.SequenceBM > 0) 
														--OR P.DimensionID = 0
														OR [dbo].[GetDefaultPropertyYN]	(P.DimensionID, P.PropertyID, ' + CONVERT(nvarchar, @SourceTypeBM) + ', ' + CONVERT(nvarchar, @ModelBM) + ') = 0
				LEFT JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.ObjectName = P.PropertyName AND MO.ObjectTypeBM & 4 > 0 AND MO.SelectYN <> 0 AND MO.Entity = ''-1''
			WHERE
				P.PropertyID NOT BETWEEN 100 AND 1000 AND
				P.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM_All) + ' > 0 AND
				P.StorageTypeBM & ' + CONVERT(nvarchar(10), @StorageTypeBM) + ' > 0 AND
				P.Introduced < ''' + @Version + ''' AND
				P.SelectYN <> 0 AND
				(
				--(P.DimensionID = ' + CONVERT(nvarchar, @DimensionID) + ' AND P.DimensionID <> 0)
				--OR
				(DP.DimensionID = ' + CONVERT(nvarchar, @DimensionID) + ' AND DP.DimensionID <> 0)
				OR
				(P.DimensionID = 0 AND P.DynamicYN <> 0)
				)' 

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#Property', * FROM #Property ORDER BY SortOrder, PropertyName

		IF @Debug <> 0
		  BEGIN
			SELECT
				DimensionName = @DimensionName,
				ModelBM = @ModelBM,
				SourceTypeBM = @SourceTypeBM,
				Member = @Member

			SELECT
				[Table] = 'Member',
				[MemberID],
				[Label],
				[Description],
				[HelpText],
				[RNodeType],
				[Parent]
			FROM
				Member M
			WHERE
				(M.DimensionID = @DimensionID OR M.DimensionID = 0) AND
				M.ModelBM & @ModelBM > 0 AND 
				M.SourceTypeBM & @SourceTypeBM > 0 AND
				M.SelectYN <> 0
			ORDER BY
				M.MemberID DESC
		  END

		SET @SQLStatement = CONVERT(nvarchar(max), '')

		DECLARE Member_Cursor CURSOR FOR

		SELECT
			MemberID = MAX(M.[MemberID]),
			Label = N'''' + M.Label + '''',
			[Description] = N'''' + MAX(M.[Description]) + '''',
			[HelpText] = N'''' + MAX(M.[HelpText]) + '''',
			[RNodeType] = N'''' + MAX(M.[RNodeType]) + '''',
			[Parent] = CASE WHEN MAX(M.[Parent]) IS NULL THEN 'NULL' ELSE N'''' + MAX(M.[Parent]) + '''' END
		FROM
			Member M
		WHERE
			(DimensionID = @DimensionID OR DimensionID = 0) AND
			ModelBM & @ModelBM > 0 AND 
			SourceTypeBM & @SourceTypeBM > 0 AND
			((DimensionID = 0 AND MemberID = 0 AND @AllYN <> 0) OR (DimensionID <> 0 OR MemberID <> 0)) AND
			M.SelectYN <> 0
		GROUP BY
			M.Label
		ORDER BY
			MemberID DESC
	
		OPEN Member_Cursor
		FETCH NEXT FROM Member_Cursor INTO @MemberID, @Label, @Description, @HelpText, @RNodeType, @Parent

		WHILE @@FETCH_STATUS = 0
		  BEGIN
			IF @SQLStatement = '' 
				BEGIN
					SET @Union = '' 
				END
			ELSE
				BEGIN
					SET @Union = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'UNION '
				END

			SET @Member = NULL

			IF @Debug <> 0 
			  BEGIN
				SELECT MemberID = @MemberID, Label = @Label, [Description] = @Description, [HelpText] = @HelpText, RNodeType = @RNodeType, Parent = @Parent
--				SELECT TempTable = '#Property', * FROM #Property ORDER BY SortOrder, PropertyName
				SELECT
					[PropertyName], [Value] = CASE P.PropertyID WHEN 9 THEN ISNULL(@HelpText, '''''') WHEN 8 THEN CONVERT(nvarchar(10), @MemberID) WHEN 5 THEN @Label WHEN 4 THEN @Description WHEN 6 THEN @RNodeType WHEN 3 THEN @Parent ELSE ISNULL(MPV.Value, ISNULL(P.DefaultValueView, 'NULL')) END
				FROM
					#Property P
					LEFT JOIN Member_Property_Value MPV ON MPV.DimensionID = P.DimensionID AND MPV.MemberID = @MemberID AND MPV.PropertyID = P.PropertyID
				ORDER BY
					SortOrder, PropertyName
			  END

			SELECT
				@Member = COALESCE(@Member + ', ', '') + ISNULL('[' + P.[PropertyName] + '] = ' + CASE P.PropertyID WHEN 9 THEN ISNULL(@HelpText, '''''') WHEN 8 THEN CONVERT(nvarchar(10), @MemberID) WHEN 5 THEN @Label WHEN 4 THEN N'' + @Description + '' WHEN 6 THEN @RNodeType WHEN 3 THEN @Parent ELSE ISNULL(MPV.Value, ISNULL(P.DefaultValueView, 'NULL')) END, 'N/A')
			FROM
				#Property P
				LEFT JOIN Member_Property_Value MPV ON MPV.DimensionID = P.DimensionID AND MPV.MemberID = @MemberID AND MPV.PropertyID = P.PropertyID
			ORDER BY
				SortOrder,
				PropertyName

			IF RIGHT(RTRIM(@Member), 1) = ','
				SET @Member = LEFT(RTRIM(@Member), LEN(RTRIM(@Member)) - 1)
				SET @Member = 'SELECT ' + @Member

			SET @SQLStatement = @SQLStatement + @Union + ISNULL(@Member, '')

			IF @Debug <> 0
				BEGIN
					SET @Counter = @Counter + 1
					INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = 'spGet_Member', [Comment] = 'Member list 1 ' + CONVERT(nvarchar(10), @Counter) + ', Len: ' + CONVERT(nvarchar(10), LEN(@SQLStatement)), [SQLStatement] = SUBSTRING(@SQLStatement, 1, 40000)
					INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = 'spGet_Member', [Comment] = 'Member list 2 ' + CONVERT(nvarchar(10), @Counter) + ', Len: ' + CONVERT(nvarchar(10), LEN(@SQLStatement)), [SQLStatement] = SUBSTRING(@SQLStatement, 40001, 80000)
					INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = 'spGet_Member', [Comment] = 'Member list 3 ' + CONVERT(nvarchar(10), @Counter) + ', Len: ' + CONVERT(nvarchar(10), LEN(@SQLStatement)), [SQLStatement] = SUBSTRING(@SQLStatement, 80001, 120000)
				END
					
			FETCH NEXT FROM Member_Cursor INTO @MemberID, @Label, @Description, @HelpText, @RNodeType, @Parent
		  END

		CLOSE Member_Cursor
		DEALLOCATE Member_Cursor

		SET @All_Dimension = N'All ' + N'' + CASE RIGHT(@DimensionName, 1) WHEN 'y' THEN LEFT(@DimensionName, LEN(@DimensionName) - 1) + 'ie' WHEN 's' THEN @DimensionName + 'e' ELSE @DimensionName END + 's'

		IF @Debug <> 0 SELECT All_Dimension = @All_Dimension

		SET @SQLStatement = REPLACE (@SQLStatement, '''@All_Dimension''', 'N' + '''' + @All_Dimension + '''')
		SET @SQLStatement = REPLACE (@SQLStatement, '@SourceType', @SourceType)

--		IF @AllYN = 0 SET @SQLStatement = REPLACE (@SQLStatement, '''All_''', '''NULL''')

		IF @Debug <> 0 SELECT SQLStatement = @SQLStatement

		SET @Counter = 0
		SET @CharCounter = LEN(@SQLStatement)
		SET @CharCounterResidual = @CharCounter
				
		WHILE @CharCounterResidual > 0
			BEGIN
				SET @Counter = @Counter + 1
				SET @CharCounterResidual = @CharCounter - ((@Counter - 1) * 4000)

				IF @CharCounterResidual > 0
					BEGIN
						IF @Counter = 1
							SET @SQLStatement3_01 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 2
							SET @SQLStatement3_02 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 3
							SET @SQLStatement3_03 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 4
							SET @SQLStatement3_04 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 5
							SET @SQLStatement3_05 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 6
							SET @SQLStatement3_06 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 7
							SET @SQLStatement3_07 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 8
							SET @SQLStatement3_08 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 9
							SET @SQLStatement3_09 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 10
							SET @SQLStatement3_10 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 11
							SET @SQLStatement3_11 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 12
							SET @SQLStatement3_12 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 13
							SET @SQLStatement3_13 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 14
							SET @SQLStatement3_14 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 15
							SET @SQLStatement3_15 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 16
							SET @SQLStatement3_16 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 17
							SET @SQLStatement3_17 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 18
							SET @SQLStatement3_18 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 19
							SET @SQLStatement3_19 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
						ELSE IF @Counter = 20
							SET @SQLStatement3_20 = ISNULL(SUBSTRING(@SQLStatement, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END), '')
					END
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #Property

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

--	SET @Step = 'Insert into JobLog'
--		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
