SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Canvas_Table] 

	@ApplicationID int = NULL,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_Canvas_Table] @ApplicationID = 400, @Debug = 1
--EXEC [spCreate_Canvas_Table] @ApplicationID = 600, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@DestinationDatabase nvarchar(100),
--	@SourceDatabase_pcEXCHANGE nvarchar(100),
	@TableID int,
	@TableName nvarchar(50),
	@ObjectName nvarchar(50),
	@Action nvarchar(500),
	@LabelYN bit,
	@SortOrderYN bit,
	@PropertyColumns nvarchar(max),
	@ModelID int,
	@ValidYN bit,
	@ModelBM int,
	@SumModelBM int = 0,
	@BrandID int,
	@InstanceID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.0.2118'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.2070' SET @Description = 'Handle Models defined in pcEXCHANGE.'
		IF @Version = '1.3.2104' SET @Description = 'Delete not licensed Menuitems.'
		IF @Version = '1.3.2107' SET @Description = 'Delete not licensed rows, generic.'
		IF @Version = '1.3.0.2118' SET @Description = 'Check ModelBM and BrandID for inserted rows.'
		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

/*
	SET @Step = 'Check if the tables are needed or not'
		IF (SELECT COUNT(1) FROM Model WHERE BaseModelID IN (-7, -8) AND ApplicationID = @ApplicationID) = 0
		RETURN
*/
	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @BrandID = @BrandID OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		DECLARE Nyc_Cursor CURSOR FOR
			SELECT
				ModelID = MAX(M.ModelID),
				BM.ModelBM
			FROM
				Model M
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			WHERE
				M.ApplicationID = @ApplicationID AND
				M.SelectYN <> 0
			GROUP BY
				BM.ModelBM

			OPEN Nyc_Cursor
			FETCH NEXT FROM Nyc_Cursor INTO @ModelID, @ModelBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					EXEC spCheck_Feature @ModelID = @ModelID, @ValidYN = @ValidYN OUT, @Debug = @Debug
					SET @SumModelBM = @SumModelBM + @ModelBM * @ValidYN

					FETCH NEXT FROM Nyc_Cursor INTO @ModelID, @ModelBM
				END
		CLOSE Nyc_Cursor
		DEALLOCATE Nyc_Cursor	

		SELECT
			@InstanceID = A.InstanceID,
			@DestinationDatabase = A.DestinationDatabase
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END
/*
		SELECT
			@SourceDatabase_pcEXCHANGE = [SourceDatabase]
		FROM
			Source S
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
		WHERE
			S.SourceTypeID = 6 AND
			S.SelectYN <> 0
*/

		IF @Debug <> 0 SELECT SumModelBM = @SumModelBM, DestinationDatabase = @DestinationDatabase

	SET @Step = 'CREATE TABLE #Object'
		CREATE TABLE #Object
			(
			ObjectType nvarchar(100) COLLATE DATABASE_DEFAULT,
			ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = 'SELECT ObjectType = ''Table'', ObjectName = st.name FROM ' + @DestinationDatabase + '.sys.tables st'
		INSERT INTO #Object (ObjectType, ObjectName) EXEC (@SQLStatement)

	SET @Step = 'CREATE TABLE #Table_Cursor'
		CREATE TABLE #Table_Cursor
			(
			TableID int,
			TableName nvarchar(100) COLLATE DATABASE_DEFAULT,
			LabelYN bit,
			SortOrderYN bit
			)

		INSERT INTO #Table_Cursor
			(
			TableID,
			TableName,
			LabelYN,
			SortOrderYN
			)
		SELECT DISTINCT 
			T.TableID,
			T.TableName,
			T.LabelYN,
			T.SortOrderYN
		FROM 
			Model M 
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & @SumModelBM > 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN [Table] T ON T.ModelBM & BM.ModelBM > 0 AND BM.ModelBM & @SumModelBM > 0 AND T.SelectYN <> 0
		WHERE
			M.SelectYN <> 0 AND
			M.ApplicationID = @ApplicationID

/*
		IF @SourceDatabase_pcEXCHANGE IS NOT NULL
			BEGIN
				SET @SQLStatement = '
				INSERT INTO #Table_Cursor
					(
					TableID,
					TableName,
					LabelYN,
					SortOrderYN
					)
				SELECT DISTINCT 
					T.TableID,
					T.TableName,
					T.LabelYN,
					T.SortOrderYN
				FROM 
					' + @SourceDatabase_pcEXCHANGE + '.dbo.Model M 
					INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.SelectYN <> 0
					INNER JOIN [Table] T ON T.ModelBM & BM.ModelBM > 0 AND T.SelectYN <> 0
				WHERE
					NOT EXISTS (SELECT 1 FROM #Table_Cursor TC WHERE TC.TableID = T.TableID)'

				EXEC (@SQLStatement)
			END
*/
	SET @Step = 'Create_Table_Cursor'
		DECLARE Create_Table_Cursor CURSOR FOR

		SELECT DISTINCT 
			TableID,
			TableName,
			LabelYN,
			SortOrderYN
		FROM 
			#Table_Cursor

 			OPEN Create_Table_Cursor
			FETCH NEXT FROM Create_Table_Cursor INTO @TableID, @ObjectName, @LabelYN, @SortOrderYN

			WHILE @@FETCH_STATUS = 0
			  BEGIN
		
				IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = @ObjectName) = 0
					SET @Action = 'CREATE'
				ELSE
					SET @Action = 'DROP TABLE [' + @DestinationDatabase + '].[dbo].[' + @ObjectName + ']' + CHAR(13) + CHAR(10) + 'CREATE'

				SET @SQLStatement = ' 
				' + @Action + ' TABLE [' + @DestinationDatabase + '].[dbo].[' + @ObjectName + '](
					[RecordId] [bigint] IDENTITY(1,1) NOT NULL'
	
				IF @LabelYN <> 0
					SET @SQLStatement = @SQLStatement + ',
					[Label] [nvarchar](255) NOT NULL'

				IF @SortOrderYN <> 0
					SET @SQLStatement = @SQLStatement + ',
					[SortOrder] [bigint] NOT NULL'

				SET @PropertyColumns = ''
	
				SELECT @PropertyColumns = ISNULL(@PropertyColumns, '') + 
					CASE P.DataTypeID	WHEN 1 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '] [int] NULL'
										WHEN 2 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '] [nvarchar] (' + CONVERT(nvarchar, P.Size) + ') NULL'
										WHEN 3 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '_MemberId] [bigint] NULL,' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '] [nvarchar] (255) NULL'
										WHEN 4 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '] [bit] NULL'
										WHEN 5 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '] [double] NULL'
										WHEN 7 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '_RecordId] [bigint] NULL,' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '] [nvarchar] (255) NULL'
										WHEN 8 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '] [bigint] NULL'
										WHEN 9 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + '[' + P.PropertyName + '] [smalldatetime] NULL'
										ELSE '' END
				FROM
				 Table_Property TP 
				 INNER JOIN Property P ON P.PropertyID = TP.PropertyID --AND P.DimensionID = 1000
				WHERE
				 TP.TableID = @TableID

				SET @SQLStatement = @SQLStatement + ISNULL(@PropertyColumns, '') + ',
				 CONSTRAINT [PK_' + @ObjectName + '] PRIMARY KEY CLUSTERED 
				(
					[RecordId] ASC
				)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
				) ON [PRIMARY]'
		
				IF @SortOrderYN <> 0
					SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) +
					'ALTER TABLE [' + @DestinationDatabase + '].[dbo].[' + @ObjectName + '] ADD  CONSTRAINT [DF_' + @ObjectName + '_SortOrder]  DEFAULT ((0)) FOR [SortOrder]'

				SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				--Create Object or Debug
				IF @Debug <> 0
				  BEGIN
					PRINT @SQLStatement
				  END
				ELSE
				  BEGIN
					EXEC (@SQLStatement)
				  END

				DECLARE Insert_Rows_Cursor CURSOR FOR

					SELECT Script FROM Table_Row WHERE TableID = @TableID AND ModelBM & @SumModelBM > 0 AND (BrandID = @BrandID OR BrandID = 0)

					OPEN Insert_Rows_Cursor
					FETCH NEXT FROM Insert_Rows_Cursor INTO @SQLStatement

					WHILE @@FETCH_STATUS = 0
					  BEGIN

						SET @SQLStatement = REPLACE (@SQLStatement , '''' , '''''' )
						SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + 
											' SET IDENTITY_INSERT [' + @DestinationDatabase + '].[dbo].[' + @ObjectName + '] ON ' + CHAR(13) + CHAR(10) +
											@SQLStatement + CHAR(13) + CHAR(10) +
											' SET IDENTITY_INSERT [' + @DestinationDatabase + '].[dbo].[' + @ObjectName + '] OFF'''

						--Create Object or Debug
						IF @Debug <> 0
						  BEGIN
							PRINT @SQLStatement
						  END
						ELSE
						  BEGIN
							EXEC (@SQLStatement)
						  END

						FETCH NEXT FROM Insert_Rows_Cursor INTO @SQLStatement
					  END

					CLOSE Insert_Rows_Cursor
					DEALLOCATE Insert_Rows_Cursor

				FETCH NEXT FROM Create_Table_Cursor INTO @TableID, @ObjectName, @LabelYN, @SortOrderYN
			END

		CLOSE Create_Table_Cursor
		DEALLOCATE Create_Table_Cursor

	SET @Step = 'Delete not licensed Menu items'
		DECLARE Canvas_Table_Cursor CURSOR FOR
			SELECT
				T.TableName
			FROM
				[Table] T
				INNER JOIN Table_Property TP ON TP.TableID = T.TableID AND TP.PropertyID = -175

			OPEN Canvas_Table_Cursor
			FETCH NEXT FROM Canvas_Table_Cursor INTO @TableName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = 'DELETE CMD FROM ' + @DestinationDatabase + '.dbo.' + @TableName + ' CMD WHERE ModelBM & ' + CONVERT(nvarchar(10), @SumModelBM) + ' <= 0'
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Canvas_Table_Cursor INTO @TableName
				END
		CLOSE Canvas_Table_Cursor
		DEALLOCATE Canvas_Table_Cursor	

	SET @Step = 'Drop temp tables'	
		DROP TABLE #Object
		DROP TABLE #Table_Cursor

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH






GO
