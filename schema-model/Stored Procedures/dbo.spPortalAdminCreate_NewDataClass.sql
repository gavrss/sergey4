SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE  PROCEDURE [dbo].[spPortalAdminCreate_NewDataClass]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataOriginID int=NULL,
	@SequenceBM int = 255, --1. Create & fill View and Fact Table, 2. Update the Information of the Fact ,4,8,16,32,64,128,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000926,
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

EXEC pcIntegrator..[spPortalAdminCreate_NewDataClass] @UserID=-10, @InstanceID='-1329', @VersionID='-1267', @DataOriginID='1173', @SequenceBM=1,@Debug=3
EXEC pcIntegrator..[spPortalAdminCreate_NewDataClass] @UserID=-10, @InstanceID='-1329', @VersionID='-1267', @DataOriginID='1173', @SequenceBM=2,@Debug=3

EXEC [spPortalAdminCreate_NewDataClass] @GetVersion = 1
*/

SET ANSI_WARNINGS ON
SET ANSI_NULLS ON


DECLARE
	--SP-specific variables
	--@DataClassDatabase nvarchar(100)='pcDATA_BAQDB',
	@StepReference nvarchar(20),
	@StorageTypeBM int,
	@SQLStatement nvarchar(max),
	@SQLStatement2 nvarchar(max),
	@SQL_Where nvarchar(max) = '',
	@SQL_Join nvarchar(4000) = '',
	@SQL_Join_PropertyFilter nvarchar(4000) = '',
	@SQL_Select nvarchar(4000) = '',
	@DimensionName nvarchar(50),
	@DataOriginName nvarchar(100),
	@DataClassName nvarchar(100) ='',
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@DataClassTypeID int,
	@DataClassID int,

	@ExistCheck bit = 0,
	--Validation
	--@ValidationCheck bit = 0,
	--@SQL_ValidationStatement nvarchar(max)='',
	--@SQL_Validation_Where nvarchar(max) = '',
	--@SQL_Validation_Join nvarchar(4000) = '',
	--@SQL_Validation_Join_PropertyFilter nvarchar(4000) = '',
	--@SQL_Validation_Select nvarchar(4000) = '',


	@DebugSub  bit = 0,
	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'AlGa',
	@ModifiedBy nvarchar(50) = 'AlGa',
	@Version nvarchar(50) = '2.1.2.2199'


IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create and fill table FACT and View based from @DataOriginID',
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
				@CallistoDatabase = [DestinationDatabase],
				@ETLDatabase = [ETLDatabase]
			FROM
				pcINTEGRATOR_Data..[Application] A
			WHERE
				A.InstanceID = @InstanceID AND
				A.VersionID = @VersionID AND
				A.SelectYN <> 0

		SELECT @DataOriginName=DataOriginName,
				@DataClassID=DataClassID
			FROM pcIntegrator_Data..DataOrigin
				WHERE DataOriginID=@DataOriginID


		SELECT @DataClassName = DataClassName
			FROM [pcIntegrator].[dbo].[DataClass] 
			WHERE DataClassID = @DataClassID
				AND InstanceID=@InstanceID
				AND VersionID=@VersionID
				AND DeletedID IS NULL

		SELECT @DataOriginName=@DataClassName

				   

		IF @SequenceBM & 1 >0
		BEGIN   
		SET @Step = 'Check if the View Exist'

				
			SET @SQLStatement = 'SELECT @OutValue=COUNT(1) FROM ' + @CallistoDatabase +'.sys.views WHERE [name] = ''FACT_' + @DataOriginName + '_Dynamic'''
			IF @Debug <> 0 PRINT @SQLStatement
			EXEC sp_executesql @SQLStatement, N'@OutValue int out', @ExistCheck out
			IF @Debug <> 0 PRINT @ExistCheck

				IF (@ExistCheck) <> 0
						BEGIN
							SET @SQLStatement = 'N'+'''DROP VIEW dbo.[FACT_' + @DataOriginName + '_Dynamic]'''

							IF @Debug <> 0 PRINT @SQLStatement
							SET @SQLStatement2 = 'EXEC ' + @CallistoDatabase +'..sp_executesql  '+ @SQLStatement

							IF @Debug <> 0 PRINT @SQLStatement2 
							EXEC sp_executesql @SQLStatement2

							SET @Deleted = @Deleted + @@ROWCOUNT

						END


			SET @Step = 'Check if the Table Exist'
			SET @SQLStatement = 'SELECT @OutValue=COUNT(1) FROM ' + @CallistoDatabase +'.sys.tables WHERE [name] = ''FACT_' + @DataOriginName + '_default_partition'''
			IF @Debug <> 0 PRINT @SQLStatement
			EXEC sp_executesql @SQLStatement, N'@OutValue int out', @ExistCheck out
			IF @Debug <> 0 PRINT @ExistCheck


				IF (@ExistCheck) > 0
						BEGIN
							SET @SQLStatement = 'N'+'''DROP TABLE dbo.[FACT_' + @DataOriginName + '_default_partition]'''

							IF @Debug <> 0 PRINT @SQLStatement
							SET @SQLStatement2 = 'EXEC ' + @CallistoDatabase +'.sys.sp_executesql '+ @SQLStatement

							IF @Debug <> 0 PRINT @SQLStatement2
							EXEC sp_executesql  @SQLStatement2

							SET @Deleted = @Deleted + @@ROWCOUNT

						END

		SET @Step = 'Create Temp Table'		
			IF OBJECT_ID('tempdb.dbo.#SysColumns', 'U') IS NOT NULL
			 DROP TABLE #SysColumns; 

			CREATE TABLE #SysColumns (
				[DataOriginName] nvarchar(100),
				[name] nvarchar(100), 
				[column_id] int, 
				[column_typeid] int,
				PropertyType Nvarchar(100),
				ConnectionName Nvarchar(100),
				StagingPosition Nvarchar(255),
				DestinationName Nvarchar(100),
				DimensionName Nvarchar(100),
				MeasureName Nvarchar(100)
				)

				INSERT INTO #SysColumns
					(
					[DataOriginName],
					[name],
					[column_id],
					[column_typeid],
					PropertyType,
					ConnectionName,
					StagingPosition,
					DestinationName,
					DimensionName,
					MeasureName
					)
				SELECT 
					--DO.[InstanceID]
					--,DO.[VersionID]
					--,DO.[DataOriginID]
					DO.[DataOriginName]
					--,DO.[DataClassID]
					,DOC.[ColumnName]
					,DOC.[ColumnOrder]
					,DOC.[ColumnTypeID]
					,DOC.PropertyType
					,DO.[ConnectionName]
					,DO.[StagingPosition]
					--,C.[ColumnTypeName]
					--,C.[ColumnTypeValue]
					,DOC.[DestinationName]
					--,DOC.[DataType]
					--,DC.[DataClassName]
					--,DC.[DataClassDescription]
					--,D.DimensionID
					,D.DimensionName
					--,DCD.DataClassID
					--,DCD.DimensionID
					--,M.MeasureID
					,M.MeasureName
					FROM pcIntegrator_Data..DataOrigin	DO
						INNER JOIN pcIntegrator_Data..DataOriginColumn DOC
							ON DOC.DataOriginID=DO.DataOriginID
						INNER JOIN [pcIntegrator]..[ColumnType] C
							ON C.ColumnTypeID = doc.ColumnTypeID
								INNER JOIN pcIntegrator..DataClass DC
									ON DC.DataClassID=DO.DataClassID
									LEFT JOIN [pcINTEGRATOR].[dbo].[Dimension] D
										ON D.DimensionName = DOC.DestinationName
											AND D.InstanceID in (0, @InstanceID)
											AND C.ColumnTypeID!=0
										LEFT JOIN [pcINTEGRATOR].[dbo].[DataClass_Dimension] DCD
											ON DCD.DataClassID=DC.DataClassID
												AND DCD.DimensionID=D.DimensionID
												AND C.ColumnTypeID!=0
											LEFT JOIN pcINTEGRATOR_Data..Measure  M
												ON M.DataClassID=DO.DataClassID
													AND M.MeasureDescription = DOC.DestinationName
						WHERE DO.DataOriginID=@DataOriginID
							AND DO.[DeletedID] IS NULL
							AND DOC.DeletedID IS NULL
							AND DC.DeletedID IS NULL
							AND D.DeletedID IS NULL
							AND M.DeletedID IS NULL
						ORDER BY DOC.ColumnOrder

				IF @DebugBM & 2 > 0 
					SELECT [TempTable] = '#SysColumns', * FROM #SysColumns

		SET @Step = 'Validate Dimension'	
		
--		set @SQL_Validation_Where=' WHERE '
		
--		SELECT @SQL_Validation_Where =  @SQL_Validation_Where + 
--					CASE WHEN [column_typeid] =0
--						THEN ''
--					WHEN [column_typeid] =2 
--						THEN 							
--								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'ISDATE(CONVERT(nvarchar(50), [' + [Name] + ']))=0 AND'
--					ELSE
--						''
--					END  
--				FROM #SysColumns
--					ORDER BY column_id
----+ 

--		SELECT [TempTable] = '@SQL_Validation_Where', SUBSTRING(@SQL_Validation_Where, 1, LEN(@SQL_Validation_Where) - 3)  


--		SET @SQL_ValidationStatement = @SQL_ValidationStatement + 'SELECT @OutValue = COUNT(*) FROM '

--		--SELECT TOP 1 @SQL_ValidationStatement = @SQL_ValidationStatement + StagingPosition +' DC ' + SUBSTRING(@SQL_Validation_Where, 1, LEN(@SQL_Validation_Where) - 3) 
--		--	FROM #SysColumns
--		--	order by column_id

--		SELECT TOP 1 @SQL_ValidationStatement = @SQL_ValidationStatement + StagingPosition +' DC ' + SUBSTRING(@SQL_Validation_Where, 1, LEN(@SQL_Validation_Where) - 3) 
--			FROM #SysColumns
--			order by column_id

--		--SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
--		IF @DebugBM & 2 > 0 
--		SELECT [TempTable] = '@SQLStatement_validate', @SQL_ValidationStatement 

--		SELECT '@ValidationCheck1', @ValidationCheck

--		EXEC sp_executesql @SQL_ValidationStatement, N'@OutValue int OUTPUT', @OutValue = @ValidationCheck OUTPUT

--		SELECT '@ValidationCheck2', @ValidationCheck


		SET @Step = 'Create Fact View'		

			SELECT
				@SQL_Select = @SQL_Select + 
					CASE WHEN [column_typeid] =0
						THEN ''
					WHEN [column_typeid] =1  
						THEN CASE WHEN PropertyType='MemberKey'			
							THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  [DimensionName] + '_MemberId = CONVERT(BIGINT,[' + [DimensionName] + '].[MemberId]), '
							ELSE '' END
					WHEN [column_typeid] =2 
						THEN 
							CASE WHEN [DimensionName]='Time' THEN 
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN [DimensionName]<>'Time' THEN + 'Time' ELSE [DimensionName] END + '_MemberId = CASE WHEN TRY_CONVERT(DATE, [DC].[' + [Name] + '], 120) IS NOT NULL THEN ISNULL(CONVERT(BIGINT,' + 'year([DC].[' + [Name] + '])*100 +MONTH([DC].['+ [Name] + '])),-1) ELSE -1 END, '
							ELSE
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN [DimensionName]<>'Time' THEN + 'Time' ELSE [DimensionName] END + '_MemberId = CASE WHEN TRY_CONVERT(DATE, [DC].[' + [Name] + '], 120) IS NOT NULL THEN ISNULL(CONVERT(BIGINT,' + 'year([DC].[' + [Name] + '])*100 +MONTH([DC].['+ [Name] + '])),-1) ELSE -1 END, '
							END
					WHEN [column_typeid] =3
						THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +  ISNULL(DestinationName,[Name]) + '_Value = CONVERT(FLOAT,[DC].[' + [Name] + ']) , '
					WHEN [column_typeid] =4
						--THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + SUBSTRING(ISNULL(DestinationName,[Name]), CHARINDEX('_', ISNULL(DestinationName,[Name])) + 1, LEN(ISNULL(DestinationName,[Name]))) + '_MemberId = CONVERT(BIGINT, [' + SUBSTRING(ISNULL(DestinationName,[Name]), CHARINDEX('_', ISNULL(DestinationName,[Name])) + 1, LEN(ISNULL(DestinationName,[Name])))  + '].[MemberId]), ' --ISNULL(DestinationName,[Name]) + ' = '''' '+ PropertyType + ' '''', '
						THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ISNULL(DestinationName,[Name]) + '_MemberId = CONVERT(BIGINT, [' + ISNULL(DestinationName,[Name]) + '].[MemberId]), ' 

					ELSE
						CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ISNULL(DestinationName,[Name]) + ' = [DC].[' + [Name] + '], '
					END  
				FROM #SysColumns
					ORDER BY column_id

			IF @DebugBM & 2 > 0 
				SELECT [TempTable] = '@SQL_Select ', @SQL_Select 

			SELECT
				@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ' DataOriginID= ' + CONVERT(nvarchar, (@DataOriginID)) + ' , ChangeDatetime	=GETDATE() , Userid = SUSER_NAME()'

				IF CURSOR_STATUS('local','Dimensions_Cursor') >= -1 DEALLOCATE Dimensions_Cursor
					DECLARE Dimensions_Cursor CURSOR FOR
			
						SELECT DISTINCT DimensionName--ISNULL(DimensionName, SUBSTRING(ISNULL(DimensionName,[Name]), CHARINDEX('_', ISNULL(DimensionName,[Name])) + 1, LEN(ISNULL(DimensionName,[Name]))))
							FROM #SysColumns
								WHERE column_typeid<>0
									AND DimensionName IS NOT NULL

						OPEN Dimensions_Cursor
						FETCH NEXT FROM Dimensions_Cursor INTO @DimensionName

						WHILE @@FETCH_STATUS = 0
							BEGIN

								SELECT TOP 1 @SQL_Join = @SQL_Join + 
									CASE WHEN [column_typeid] =0
										THEN ''
									WHEN [column_typeid] =1 
										THEN CASE WHEN PropertyType='MemberKey'			
											--THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN '+  ' [pcDATA_BAQDB].[dbo].[S_DS_' + [DimensionName] + '] [' + [DimensionName]  + '] '
												THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN ['+  @CallistoDatabase + '].[dbo].[S_DS_' + [DimensionName] + '] [' + [DimensionName]  + '] '
												+ 'ON 1 = 1 '
											ELSE ''	END
									WHEN [column_typeid] =4 
										--THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN ['+  @CallistoDatabase + '].[dbo].[S_DS_' + SUBSTRING(ISNULL(DestinationName,[Name]), CHARINDEX('_', ISNULL(DestinationName,[Name])) + 1, LEN(ISNULL(DestinationName,[Name]))) + '] [' + SUBSTRING(ISNULL(DestinationName,[Name]), CHARINDEX('_', ISNULL(DestinationName,[Name])) + 1, LEN(ISNULL(DestinationName,[Name])))  + '] '
										THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN ['+  @CallistoDatabase + '].[dbo].[S_DS_' + ISNULL(DestinationName,[Name]) + '] [' + ISNULL(DestinationName,[Name]) + '] '
										+ 'ON 1 = 1 '
									ELSE
										--CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)+ name + ' , '
										''
									END  
									FROM #SysColumns							
										WHERE [DimensionName]=@DimensionName
									ORDER BY CASE WHEN LTRIM(RTRIM(PropertyType)) = 'MemberKey' THEN 0 ELSE 1 END ,column_id



								SELECT @SQL_Join = @SQL_Join + 
									CASE WHEN [column_typeid] =0
										THEN ''
									WHEN [column_typeid] =1
										THEN CASE WHEN PropertyType='MemberKey'
											THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ' AND [' + [DimensionName] + '].[LABEL] = CONVERT(NVARCHAR(255),[DC].[' + [Name] + '])' 
											ELSE '' END
									WHEN [column_typeid] =4
										--THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ' AND [' + SUBSTRING(ISNULL(DestinationName,[Name]), CHARINDEX('_', ISNULL(DestinationName,[Name])) + 1, LEN(ISNULL(DestinationName,[Name]))) + '].[LABEL] = '''''+ RTRIM(LTRIM(PropertyType))  + '''''' 
										THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ' AND [' + ISNULL(DestinationName,[Name]) + '].[LABEL] = '''''+ RTRIM(LTRIM(PropertyType))  + '''''' 
									ELSE
										--CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)+ name + ' , '
										''
									END  
									FROM #SysColumns
										WHERE [DimensionName]=@DimensionName
									ORDER BY column_id
					
								FETCH NEXT FROM Dimensions_Cursor INTO @DimensionName
							END

					CLOSE Dimensions_Cursor
					DEALLOCATE Dimensions_Cursor

			IF @DebugBM & 2 > 0 
				SELECT [TempTable] = '@SQL_Join ', @SQL_Join 

			SET @SQLStatement = 'CREATE VIEW [FACT_' + @DataOriginName + '_Dynamic] AS
					-- Current Version: ' + @Version + '
					-- Created: ' + CONVERT(nvarchar(100),GETDATE()) + CHAR(13) + CHAR(10)

			SET @SQLStatement = @SQLStatement + 'SELECT ' + @SQL_Select + '
					FROM '

				SELECT TOP 1 @SQLStatement = @SQLStatement + StagingPosition +' DC '
					FROM #SysColumns
					order by column_id

				SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10)+ @SQL_Join

			SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
	
			IF @DebugBM & 2 > 0 
			SELECT [TempTable] = '@SQLStatement', @SQLStatement 
			
			EXECUTE (@SQLStatement)

			SELECT [DataClassID] = @DataClassID

			--SELECT DataClassTypeID FROM pcIntegrator..DataClass
			--		WHERE DataClassID=@DataClassID

			IF (SELECT DataClassTypeID FROM pcIntegrator..DataClass
					WHERE DataClassID=@DataClassID)='-12'
			BEGIN

				SET @SQLStatement = 'SELECT *
					INTO ' +  @CallistoDatabase + '.dbo.[FACT_' + @DataOriginName + '_default_partition] 
					FROM ' + @CallistoDatabase +'.dbo.[FACT_' + @DataOriginName + '_Dynamic] '

				IF @DebugBM & 2 > 0 
					SELECT [TempTable] = '@SQLStatement', @SQLStatement 
		
				EXEC (@SQLStatement)

				EXEC [spSetup_Index] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID,@DataClassID=@DataClassID

			END
		END


		IF @SequenceBM & 2 >0
		BEGIN

			SET @Step = 'Update Fact View '		


			SET @SQLStatement = 'DELETE 
				FROM ' + @CallistoDatabase +'.dbo.[FACT_' + @DataOriginName + '_default_partition] 
				WHERE DataOriginID = ' + CONVERT(nvarchar, (@DataOriginID)) 

			IF @DebugBM & 2 > 0 
			SELECT [TempTable] = '@SQLStatement', @SQLStatement 
		
			EXEC (@SQLStatement)

			SET @SQLStatement = 'INSERT INTO ' +  @CallistoDatabase + '.dbo.[FACT_' + @DataOriginName + '_default_partition] 
				 SELECT * FROM ' + @CallistoDatabase +'.dbo.[FACT_' + @DataOriginName + '_Dynamic] '

			IF @DebugBM & 2 > 0 
				SELECT [TempTable] = '@SQLStatement', @SQLStatement 
		
			EXEC (@SQLStatement)

		END

		SET @Step = 'CountofChanged Fact View '		
		
		IF (SELECT COUNT(1) FROM #SysColumns
				WHERE column_typeid=2)>0
		BEGIN

			SET @SQLStatement = 'SELECT [DataClassID] = ' + Convert(nvarchar(20), @DataClassID) + ', '

			SELECT  @SQLStatement = @SQLStatement +
					CASE WHEN [column_typeid] =2 THEN 
									CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[ColumnName] = ''''' + [Name] +''''''
							ELSE '' END
					FROM #SysColumns 
						ORDER BY column_id


			SET @SQLStatement = @SQLStatement + ' , [NumberOfRowsChanged] = COUNT(1) ' + '
					FROM '

			SELECT TOP 1 @SQLStatement = @SQLStatement + StagingPosition +' DC '
				FROM #SysColumns
				order by column_id

			SET @SQL_Where = 'WHERE TRY_CONVERT(DATE, '
			SELECT  @SQL_Where = @SQL_Where +
					CASE WHEN [column_typeid] =2 THEN 
									CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[DC].[' + [Name] + '] ) IS NULL;'
							ELSE '' END
					FROM #SysColumns
						ORDER BY column_id

			SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + @SQL_Where

			SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
	
			IF @DebugBM & 2 > 0 
			SELECT [TempTable] = '@SQLStatement', @SQLStatement 
			
			EXECUTE (@SQLStatement)

		END

		IF OBJECT_ID('tempdb.dbo.#SysColumns', 'U') IS NOT NULL
		 DROP TABLE #SysColumns; 


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
