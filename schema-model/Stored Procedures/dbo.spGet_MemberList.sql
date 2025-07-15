SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_MemberList] 
@GetVersion bit = 0,
@Debug bit = 0,
@Duration time(7) = '00:00:00' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT

--#WITH ENCRYPTION#--

--EXEC [spGet_MemberList] @Debug = 1

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@JobID int = -1,
	@SourceTypeBM int,
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@ObjectName nvarchar(100),
	@MappedObjectName nvarchar(100),
	@DimensionTypeID int,
	@Counter int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2083'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2116' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		SELECT 
			@SourceTypeBM = SUM(ST.SourceTypeBM)
		FROM
			[SourceType] ST
			INNER JOIN
				(
				SELECT DISTINCT
					S.SourceTypeID
				FROM
					[Application] A 
					INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
					INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
				WHERE
					A.ApplicationID > 0 AND
					A.SelectYN <> 0
				) sub ON sub.SourceTypeID = ST.SourceTypeID

	SET @Step = 'Create temp tables'
		CREATE TABLE #Dimensions 
			(
			ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
			MappedObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
			DimensionTypeID int
			)

		CREATE TABLE #MemberList 
			(
			DimensionID int,
			Dimension nvarchar(100) COLLATE DATABASE_DEFAULT,
			MemberID bigint,
			Label nvarchar(256) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			Parent nvarchar(100) COLLATE DATABASE_DEFAULT,
			RNodeType nvarchar(2) COLLATE DATABASE_DEFAULT,
			MandatoryYN bit,
			DefaultSelectYN bit
			)

	SET @Step = 'Create DB_Cursor'
		DECLARE DB_Cursor CURSOR FOR

		SELECT DISTINCT
			A.ETLDatabase,
			A.DestinationDatabase
		FROM
			[Application] A 
		WHERE
			A.ApplicationID > 0 AND
			A.SelectYN <> 0

			OPEN DB_Cursor
			FETCH NEXT FROM DB_Cursor INTO @ETLDatabase, @DestinationDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT ETLDatabase = @ETLDatabase

					SET @SQLStatement = @ETLDatabase + '..[spFix_ChangedLabel]'
					
					EXEC (@SQLStatement)

					SET @SQLStatement = '
						INSERT INTO #Dimensions
							(
							ObjectName,
							MappedObjectName,
							DimensionTypeID
							)
						SELECT DISTINCT
							ObjectName,
							MappedObjectName,
							DimensionTypeID
						FROM
							' + @ETLDatabase + '..MappedObject MO
						WHERE
							ObjectTypeBM & 2 > 0 AND
							SelectYN <> 0'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					INSERT INTO #MemberList
						(
						DimensionID,
						Dimension,
						MemberID,
						Label,
						[Description],
						Parent,
						RNodeType,
						MandatoryYN,
						DefaultSelectYN
						)
					SELECT DISTINCT
						M.DimensionID,
						Dimension = DL.[MappedObjectName],
						M.MemberID,
						M.Label,
						M.[Description],
						M.Parent,
						M.RNodeType,
						M.MandatoryYN,
						M.DefaultSelectYN
					FROM
						[Dimension] D
						INNER JOIN [Member] M ON M.DimensionID = D.DimensionID
						INNER JOIN #Dimensions DL ON DL.ObjectName = D.DimensionName AND DL.DimensionTypeID <> -1
					WHERE
						M.SelectYN <> 0 AND
						M.SourceTypeBM & @SourceTypeBM > 0
					ORDER BY
						DL.[MappedObjectName],
						M.MemberId

					IF @Debug <> 0 SELECT TempTable = '#MemberList', * FROM #MemberList ORDER BY Dimension, MemberId

					DECLARE Dimension_Cursor CURSOR FOR

						SELECT DISTINCT
							ObjectName,
							MappedObjectName,
							DimensionTypeID
						FROM
							#Dimensions

						OPEN Dimension_Cursor
						FETCH NEXT FROM Dimension_Cursor INTO @ObjectName, @MappedObjectName, @DimensionTypeID

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @Debug <> 0 SELECT ObjectName = @ObjectName, MappedObjectName = @MappedObjectName, DimensionTypeID = @DimensionTypeID

								IF @DimensionTypeID <> -1
									BEGIN
										SET @SQLStatement = '
											INSERT INTO #MemberList
												(
												DimensionID,
												Dimension,
												MemberID,
												Label,
												[Description],
												Parent,
												RNodeType,
												MandatoryYN,
												DefaultSelectYN
												)
											SELECT DISTINCT
												D.DimensionID,
												Dimension = ''' + @MappedObjectName + ''',
												M.MemberID,
												M.Label,
												MON.[Description],
												M.Parent,
												M.RNodeType,
												M.MandatoryYN,
												M.DefaultSelectYN
											FROM
												[Dimension] D
												INNER JOIN [Member] M ON M.DimensionID = 0 AND M.SelectYN <> 0 AND M.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM) + ' > 0
												INNER JOIN ' + @DestinationDatabase + '..S_DS_' + @MappedObjectName + ' MON ON MON.Label = M.Label
											WHERE
												D.DimensionName = ''' + @ObjectName + ''' AND
												NOT EXISTS (SELECT 1 FROM #MemberList ML WHERE ML.Dimension = ''' + @MappedObjectName + ''' AND ML.Label = M.Label)
											ORDER BY
												M.MemberId'

										IF @Debug <> 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
									END

								SET @SQLStatement = '
									INSERT INTO #MemberList
										(
										DimensionID,
										Dimension,
										MemberID,
										Label,
										[Description],
										Parent,
										RNodeType,
										MandatoryYN,
										DefaultSelectYN
										)
									SELECT DISTINCT
										DimensionID = ISNULL(D.DimensionID, 0),
										Dimension = ''' + @MappedObjectName + ''',
										DS.MemberID,
										DS.Label,
										DS.[Description],
										Parent = DS1.Label,
										DS.RNodeType,
										MandatoryYN = 1,
										DefaultSelectYN = 1
									FROM
										' + @DestinationDatabase + '..S_DS_' + @MappedObjectName + ' DS
										LEFT JOIN ' + @DestinationDatabase + '..S_HS_' + @MappedObjectName + '_' + @MappedObjectName + ' HS ON HS.MemberId = DS.MemberId
										LEFT JOIN ' + @DestinationDatabase + '..S_DS_' + @MappedObjectName + ' DS1 ON DS1.MemberId = HS.ParentMemberId
										LEFT JOIN [Dimension] D ON D.DimensionName = ''' + @ObjectName + ''' AND ' + CONVERT(nvarchar(10), @DimensionTypeID) + ' <> -1
									WHERE
										DS.MemberID <= ' + CASE WHEN @DimensionTypeID IN (7, 39) OR @ObjectName LIKE '%Year%' THEN '30000000' ELSE '1000' END + ' AND
										NOT EXISTS (SELECT 1 FROM #MemberList ML WHERE ML.Dimension = ''' + @MappedObjectName + ''' AND ML.Label = DS.Label)
									ORDER BY
										DS.MemberId'

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								FETCH NEXT FROM Dimension_Cursor INTO @ObjectName, @MappedObjectName, @DimensionTypeID
							END

					CLOSE Dimension_Cursor
					DEALLOCATE Dimension_Cursor	

					FETCH NEXT FROM DB_Cursor INTO @ETLDatabase, @DestinationDatabase
				END

		CLOSE DB_Cursor
		DEALLOCATE DB_Cursor		

	SET @Step = 'Return values'
		SELECT 
			*
		FROM
			#MemberList
		ORDER BY
			Dimension,
			MemberId

	SET @Step = 'Drop temp tables'
		DROP TABLE #Dimensions
		DROP TABLE #MemberList

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
