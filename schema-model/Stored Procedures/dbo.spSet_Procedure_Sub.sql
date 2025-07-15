SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_Procedure_Sub]
(
	@UserID int = -10,
	@InstanceID int = 0,
	@VersionID int = 0,

	@CalledInstanceID int = NULL,
	@CalledVersionID int = NULL,
	@CalledProcedureID int = NULL,
	@CalledDatabaseName nvarchar(100) = NULL, 
	@CalledProcedureName nvarchar(100) = NULL,
	@ProcedureDescription nvarchar(1024) = NULL,
	@MandatoryParameter nvarchar(1000) = NULL,
	@CalledVersion nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000705,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines
)

/*
EXEC dbo.[spSet_Procedure_Sub] @Debug = 1
EXEC dbo.[spSet_Procedure_Sub] @GetVersion = 1
EXEC spSet_Procedure_Sub @CalledProcedureName = 'spIU_Journal_SIE4', @ProcedureDescription = 'Insert data to Journal during SIE4 load', @MandatoryParameter = '', @CalledVersion = '2.0.1.2143', @Debug = 1

EXEC [spSet_Procedure_Sub] @GetVersion = 1
*/	

--#WITH ENCRYPTION#--

AS

DECLARE
	@DeletedID int,
	@CharIndex int,
	@MaxID int,
	@SQLStatement nvarchar(max),
	
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
	@Description nvarchar(255),
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2169'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Register new SPs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'Extended propertylist; ProcedureDescription, MandatoryParameter and Updated.'
		IF @Version = '2.0.0.2141' SET @Description = 'Exclude all SPs with name ended by a numeric character.'
		IF @Version = '2.0.1.2143' SET @Description = 'Exclude all SPs with name ended by 3 numeric characters. Automatic reseed before insert.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.0.2162' SET @Description = 'Renamed from spInsert_Procedure to spSet_Procedure_Sub.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle multiple databases.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CalledInstanceID = ISNULL(@CalledInstanceID, 0),
			@CalledVersionID = ISNULL(@CalledVersionID, 0),
			@CalledDatabaseName = ISNULL(@CalledDatabaseName, 'pcINTEGRATOR')

		IF @DebugBM & 2 > 0
			SELECT
				[@Debug] = @Debug,
				[@DebugBM] = @DebugBM,
				[@CalledInstanceID] = @CalledInstanceID,
				[@CalledVersionID] = @CalledVersionID,
				[@CalledProcedureID] = @CalledProcedureID,
				[@CalledDatabaseName] = @CalledDatabaseName, 
				[@CalledProcedureName] = @CalledProcedureName,
				[@ProcedureDescription] = @ProcedureDescription,
				[@MandatoryParameter] = @MandatoryParameter,
				[@CalledVersion] = @CalledVersion
		
	SET @Step = 'Create #Procedure temp table'
		CREATE TABLE #Procedure
			(
			[ProcedureName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[StdParameterYN] bit
			)

		IF @CalledDatabaseName = 'pcINTEGRATOR'
			INSERT INTO #Procedure
				(
				[ProcedureName],
				[StdParameterYN]
				)
			SELECT
				[ProcedureName] = s.[name],
				[StdParameterYN] = CASE WHEN m.[object_id] IS NULL THEN 0 ELSE 1 END
			FROM
				[sys].[procedures] s
				LEFT JOIN (SELECT [object_id] FROM [sys].[all_parameters] ap WHERE name IN ('@UserID','@InstanceID', '@VersionID') GROUP BY [object_id] HAVING COUNT(1) = 3) m ON m.[object_id] = s.[object_id]
			WHERE
				[name] NOT LIKE '%_Old' AND 
				[name] NOT LIKE '%_New' AND 
				[name] NOT LIKE '%_tmp' AND 
				[name] NOT IN ('spSetDataClass_0304_SalesBudget', 'spAdvanced_Setup') AND
				[create_date] NOT BETWEEN '2017-07-26 14:57:34.100' AND '2017-07-26 14:57:34.900' AND 
				ISNUMERIC(RIGHT([name], 5)) = 0
		ELSE
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #Procedure
						(
						[ProcedureName],
						[StdParameterYN]
						)
					SELECT
						[ProcedureName] = s.[name],
						[StdParameterYN] = CASE WHEN m.[object_id] IS NULL THEN 0 ELSE 1 END
					FROM
						[' + @CalledDatabaseName + '].[sys].[procedures] s
						LEFT JOIN (SELECT [object_id] FROM [' + @CalledDatabaseName + '].[sys].[all_parameters] ap WHERE name IN (''@UserID'',''@InstanceID'', ''@VersionID'') GROUP BY [object_id] HAVING COUNT(1) = 3) m ON m.[object_id] = s.[object_id]
					WHERE
						s.[name] = ''' + @CalledProcedureName + ''''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Procedure', * FROM #Procedure ORDER BY [ProcedureName]

	SET @Step = 'Update StdParameterYN'
		IF @CalledDatabaseName = 'pcINTEGRATOR'
			BEGIN
				UPDATE P
				SET
					[StdParameterYN] = #P.[StdParameterYN]
				FROM
					[@Template_Procedure] P
					INNER JOIN [#Procedure] #P ON #P.[ProcedureName] = P.[ProcedureName]
				WHERE
					P.[DatabaseName] = @CalledDatabaseName AND
					P.[StdParameterYN] <> #P.[StdParameterYN] AND
					P.DeletedID IS NULL

				SET @Updated = @Updated + @@ROWCOUNT
			END
		ELSE
			BEGIN
				UPDATE P
				SET
					[StdParameterYN] = #P.[StdParameterYN]
				FROM
					[pcINTEGRATOR_Data].[dbo].[Procedure] P
					INNER JOIN [#Procedure] #P ON #P.[ProcedureName] = P.[ProcedureName]
				WHERE
					P.[StdParameterYN] <> #P.[StdParameterYN] AND
					P.DeletedID IS NULL

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Update DeletedID'
		IF @CalledDatabaseName = 'pcINTEGRATOR'
			BEGIN
				DECLARE Procedure_Delete_Cursor CURSOR FOR

					SELECT 
						[ProcedureName]
					FROM
						[@Template_Procedure] P
					WHERE
						P.DeletedID IS NULL AND
						NOT EXISTS (SELECT 1 FROM [#Procedure] #P WHERE #P.[ProcedureName] = P.[ProcedureName])

					OPEN Procedure_Delete_Cursor
					FETCH NEXT FROM Procedure_Delete_Cursor INTO @ProcedureName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @Debug <> 0 SELECT ProcedureName = @ProcedureName
							EXEC [dbo].[spGet_DeletedItem] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'Procedure', @DeletedID = @DeletedID OUT

							UPDATE P
							SET
								[DeletedID] = @DeletedID
							FROM
								[@Template_Procedure] P
							WHERE
								P.[ProcedureName] = @ProcedureName AND
								P.DeletedID IS NULL

							SET @Deleted = @Deleted + @@ROWCOUNT

							FETCH NEXT FROM Procedure_Delete_Cursor INTO @ProcedureName
						END

				CLOSE Procedure_Delete_Cursor
				DEALLOCATE Procedure_Delete_Cursor
			END

	SET @Step = 'Insert new SPs'
		IF @CalledDatabaseName = 'pcINTEGRATOR'
			BEGIN
				SELECT @MaxID = MAX([ProcedureID]) FROM [@Template_Procedure]
				DBCC CHECKIDENT ([@Template_Procedure], RESEED, @MaxID)

				INSERT INTO [dbo].[@Template_Procedure]
					(
					[ProcedureName],
					[StdParameterYN],
					[StdParameterMandatoryYN]
					)
				SELECT
					[ProcedureName],
					[StdParameterYN],
					[StdParameterMandatoryYN] = [StdParameterYN]
				FROM
					#Procedure #P
				WHERE
					NOT EXISTS (SELECT 1 FROM [@Template_Procedure] P WHERE P.ProcedureName = #P.ProcedureName AND P.DeletedID IS NULL)
				ORDER BY 
					[ProcedureName]

				SET @Inserted = @Inserted + @@ROWCOUNT
			END
		ELSE
			BEGIN
				SELECT @MaxID = MAX([ProcedureID]) FROM [pcINTEGRATOR_Data].[dbo].[Procedure]
				SET @MaxID = ISNULL(@MaxID, 990000000)
				SET @SQLStatement = 'DBCC CHECKIDENT ([Procedure], RESEED, ' + CONVERT(nvarchar(15), @MaxID) + ')'
				SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].[dbo].[sp_executesql] N''' + @SQLStatement + ''''
				
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Procedure]
					(
					[InstanceID],
					[VersionID],
					[DatabaseName],
					[ProcedureName],
					[StdParameterYN],
					[StdParameterMandatoryYN]
					)
				SELECT
					[InstanceID] = @CalledInstanceID,
					[VersionID] = @CalledVersionID,
					[DatabaseName] = @CalledDatabaseName,
					[ProcedureName],
					[StdParameterYN],
					[StdParameterMandatoryYN] = [StdParameterYN]
				FROM
					#Procedure #P
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Procedure] P WHERE P.[DatabaseName] = @CalledDatabaseName AND P.[ProcedureName] = #P.ProcedureName AND P.[DeletedID] IS NULL)
				ORDER BY 
					[ProcedureName]

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Update Properties for Specific SP'
		IF @CalledProcedureID IS NULL
			BEGIN
				SELECT
					@CalledProcedureID = P.[ProcedureID]
				FROM
					[Procedure] P
				WHERE
					P.[DatabaseName] = @CalledDatabaseName AND
					P.[ProcedureName] = @CalledProcedureName AND
					P.DeletedID IS NULL
			END

		IF @CalledDatabaseName = 'pcINTEGRATOR'
			BEGIN
				UPDATE P
				SET
					[ProcedureDescription] = @ProcedureDescription,
					[Version] = ISNULL(@CalledVersion, P.[Version]),
					[Updated] = GetDate()
				FROM
					[@Template_Procedure] P
				WHERE
					[ProcedureID] = @CalledProcedureID
			END
		ELSE
			BEGIN
				UPDATE P
				SET
					[ProcedureDescription] = @ProcedureDescription,
					[Version] = ISNULL(@CalledVersion, P.[Version]),
					[Updated] = GetDate()
				FROM
					[pcINTEGRATOR_Data].[dbo].[Procedure] P
				WHERE
					[ProcedureID] = @CalledProcedureID
			END

	SET @Step = 'Update mandatory parameters'
		IF @CalledDatabaseName = 'pcINTEGRATOR'
			DELETE
				[PP]
			FROM
				[@Template_ProcedureParameter] PP
			WHERE
				[PP].[ProcedureID] = @CalledProcedureID
		ELSE
			DELETE
				[PP]
			FROM
				[pcINTEGRATOR_Data].[dbo].[ProcedureParameter] PP
			WHERE
				[PP].[ProcedureID] = @CalledProcedureID

		IF LEN(@MandatoryParameter) > 0
			BEGIN
				CREATE TABLE #Parameter ([Parameter] nvarchar(50))

				WHILE CHARINDEX ('|', @MandatoryParameter) > 0
					BEGIN
						SET @CharIndex = CHARINDEX('|', @MandatoryParameter)
						INSERT INTO #Parameter ([Parameter]) SELECT [Parameter] = LTRIM(RTRIM(LEFT(@MandatoryParameter, @CharIndex - 1)))
						SET @MandatoryParameter = SUBSTRING(@MandatoryParameter, @CharIndex + 1, LEN(@MandatoryParameter) - @CharIndex)
					END
				
				INSERT INTO #Parameter ([Parameter]) SELECT [Parameter] = LTRIM(RTRIM(@MandatoryParameter))

				IF @CalledDatabaseName = 'pcINTEGRATOR'
					INSERT INTO [@Template_ProcedureParameter]
						(
						[ProcedureID], 
						[Parameter], 
						[Version]
						)
					SELECT
						[ProcedureID] = @CalledProcedureID,
						[Parameter],
						[Version] = @CalledVersion
					FROM
						#Parameter
				ELSE
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[ProcedureParameter]
						(
						[InstanceID],
						[VersionID],
						[ProcedureID], 
						[Parameter], 
						[Version]
						)
					SELECT
						[InstanceID] = @CalledInstanceID,
						[VersionID] = @CalledVersionID,
						[ProcedureID] = @CalledProcedureID,
						[Parameter],
						[Version] = @CalledVersion
					FROM
						#Parameter

				DROP TABLE #Parameter
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
