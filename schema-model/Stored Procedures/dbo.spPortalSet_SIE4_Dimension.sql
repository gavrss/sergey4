SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_SIE4_Dimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ApplicationID int = NULL,
	@Entity_MemberKey nvarchar(50) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000195,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalSet_SIE4_Dimension',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "404"},
		{"TKey" : "VersionID",  "TValue": "1003"},
		{"TKey" : "JobID",  "TValue": "24416"}
		]'
EXEC spPortalSet_SIE4_Dimension @UserID = -10, @InstanceID = 404, @VersionID = 1003, @JobID = 26389, @Debug = 1
EXEC spPortalSet_SIE4_Dimension @UserID = -10, @InstanceID = 533, @VersionID = 1058, @JobID = 12910, @Debug = 1

EXEC [spPortalSet_SIE4_Dimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DimensionID int,
	@DimensionName nvarchar(100),
	@DimensionTypeID int,
	@StorageTypeBM int,
	@StorageTypeBMCalc int,
	@BMCounter int,
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@SQLStatement nvarchar(MAX),
	@Entity nvarchar(100),
	@EntityID int,
	@KPTYP nvarchar(50),
	@SegmentNo int,
	@SegmentCode nvarchar(50),
	@MappingTypeID int,
	@ReplaceTextYN bit,
	@SourceTypeID int = 7,

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
	@Version nvarchar(50) = '2.1.1.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set Dimension members loaded by SIE4',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data]. Added Description for Entity.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-427: Adding Dimension_Property table and remove references to Property.Dimension.'
		IF @Version = '2.1.1.2168' SET @Description = 'Check existence of Cursor DimInsert_Cursor.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added variable @SourceTypeID.'
		IF @Version = '2.1.1.2179' SET @Description = 'Added parameter @Entity_MemberKey (mandatory to be passed to [spIU_Dim_Account_Callisto] sub-routine).'

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
			@ApplicationID = ISNULL(@ApplicationID, ApplicationID)
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

		SELECT 
			@ETLDatabase = ETLDatabase,
			@DestinationDatabase = DestinationDatabase
		FROM
			[Application] a
		WHERE
			ApplicationID = @ApplicationID

		SELECT 
			@Entity = MAX(Entity)
		FROM
			Journal
		WHERE
			JobID = @JobID AND
			InstanceID = @InstanceID AND
			Entity IS NOT NULL

		SELECT 
			@EntityID = EntityID
		FROM
			pcINTEGRATOR_Data..Entity
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			MemberKey = @Entity

		SELECT 
			@KPTYP = KPTYP
		FROM
			SIE4_Job sj
		WHERE
			JobID = @JobID AND
			InstanceID = @InstanceID

		IF @Debug <> 0
			SELECT
				[@ApplicationID] = @ApplicationID,
				[@ETLDatabase] = @ETLDatabase,
				[@DestinationDatabase] = @DestinationDatabase,
				[@Entity] = @Entity,
				[@EntityID] = @EntityID,
				[@KPTYP] = @KPTYP

	SET @Step = 'Create and fill temp table #Dimension'
		CREATE TABLE #Dimension
			(
			DimensionID int,
			DimensionName NVARCHAR(100),
			DimensionTypeID INT,
			StorageTypeBM INT,
			MappingTypeID int,
			ReplaceTextYN bit
			)

		ALTER TABLE [#Dimension] ADD CONSTRAINT [DF_#Dimension_MappingTypeID]  DEFAULT ((0)) FOR [MappingTypeID]
		ALTER TABLE [#Dimension] ADD CONSTRAINT [DF_#Dimension_ReplaceTextYN]  DEFAULT ((0)) FOR [ReplaceTextYN]

		INSERT INTO #Dimension
			(
			DimensionID,
			DimensionName,
			DimensionTypeID,
			StorageTypeBM
			)
		SELECT
			DCD.DimensionID,
			D.DimensionName,
			D.DimensionTypeID,
			DST.StorageTypeBM
		FROM
			DataClass DC
			INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = DC.DataClassID
			INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID
			INNER JOIN Dimension_StorageType DST ON DST.InstanceID = DC.InstanceID AND DST.DimensionID = DCD.DimensionID
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.SelectYN <> 0

		DECLARE Dimension_Cursor CURSOR FOR
			SELECT
				D.DimensionID,
				D.DimensionName,
				D.DimensionTypeID,
				DST.StorageTypeBM
			FROM
				Dimension D
				INNER JOIN Dimension_StorageType DST ON DST.InstanceID = D.InstanceID AND DST.DimensionID = D.DimensionID
			WHERE
				D.InstanceID = @InstanceID

			OPEN Dimension_Cursor
			FETCH NEXT FROM Dimension_Cursor INTO @DimensionID, @DimensionName, @DimensionTypeID, @StorageTypeBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT DimensionID = @DimensionID, DimensionName = @DimensionName, StorageTypeBM = @StorageTypeBM
					SET @StorageTypeBMCalc = NULL
					IF EXISTS (SELECT 1 FROM #Dimension d WHERE DimensionID = @DimensionID)
						BEGIN
							SELECT @BMCounter = 1, @StorageTypeBMCalc = 0
							WHILE @BMCounter <= 8
								BEGIN
									SET @StorageTypeBMCalc = @StorageTypeBMCalc + CASE WHEN @StorageTypeBM & @BMCounter > 0 THEN @BMCounter ELSE 0 END
									IF NOT @StorageTypeBM & @BMCounter > 0
										SELECT @StorageTypeBMCalc = @StorageTypeBMCalc + CASE WHEN StorageTypeBM & @BMCounter > 0 THEN @BMCounter ELSE 0 END FROM #Dimension d WHERE DimensionID = @DimensionID
									SET @BMCounter = @BMCounter * 2
								END

							UPDATE #Dimension
							SET StorageTypeBM = @StorageTypeBMCalc
							WHERE DimensionID = @DimensionID
						END
					ELSE
						INSERT INTO #Dimension
							(
							DimensionID,
							DimensionName,
							DimensionTypeID,
							StorageTypeBM
							)
						SELECT
							DimensionID = @DimensionID,
							DimensionName = @DimensionName,
							DimensionTypeID = @DimensionTypeID,
							StorageTypeBM = ISNULL(@StorageTypeBMCalc, @StorageTypeBM)

					FETCH NEXT FROM Dimension_Cursor INTO  @DimensionID, @DimensionName, @DimensionTypeID, @StorageTypeBM
				END

		CLOSE Dimension_Cursor
		DEALLOCATE Dimension_Cursor	

		INSERT INTO #Dimension
			(
			DimensionID,
			DimensionName,
			DimensionTypeID,
			StorageTypeBM
			)
		SELECT DISTINCT
			DimensionID = P.DependentDimensionID,
			DimensionName = DS.DimensionName,
			DimensionTypeID = DS.DimensionTypeID,
			StorageTypeBM = D.StorageTypeBM
		FROM 
			Property P 
			INNER JOIN Dimension DS ON DS.InstanceID IN (0, @InstanceID) AND DS.DimensionID = P.DependentDimensionID
			INNER JOIN Dimension_Property DP ON DP.InstanceID IN (0, @InstanceID) AND DP.VersionID IN (0, @VersionID) AND DP.PropertyID = P.PropertyID
			INNER JOIN #Dimension D ON D.DimensionID = DP.DimensionID
		WHERE
			P.InstanceID IN (0, @InstanceID) AND
			P.DataTypeID = 3 AND
			NOT EXISTS (SELECT 1 FROM #Dimension DD WHERE DD.DimensionID = P.DependentDimensionID)

		UPDATE #D
		SET
			MappingTypeID = DR.MappingTypeID,
			ReplaceTextYN = DR.ReplaceTextYN
		FROM
			#Dimension #D
			INNER JOIN Dimension_Rule DR ON DR.InstanceID = @InstanceID AND DR.Entity_MemberKey = @Entity AND DR.DimensionID = #D.DimensionID

		IF @Debug <> 0 SELECT TempTable = '#Dimension', * FROM #Dimension d ORDER BY DimensionID

	SET @Step = 'Create temp tables #Member and #Account_Members'
		CREATE TABLE [#Member]
			(
			[MemberKey] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[MemberDescription] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT
			)
/*
		CREATE TABLE [#Account_Members]
			(
			[MemberId] bigint,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[Account Type] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BP_Budget] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[BP_Budget_MemberId] bigint,
			[CTA_Account] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[CTA_Account_MemberId] bigint,
			[IC] bit,
			[IC_OTHER] bit,
			[ICELIM] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[ICELIM_MemberId] bigint,
			[ICELIM_HOLDING] bit,
			[ICMATCH] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[ICMATCH_MemberId] bigint,
			[KeyName_Account] nvarchar(30) COLLATE DATABASE_DEFAULT,
			[Rate] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Rate_MemberId] bigint,
			[Sign] int,
			[TimeBalance] bit,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

			ALTER TABLE [#Account_Members] ADD CONSTRAINT [DF_#Account_Members_Synchronized]  DEFAULT ((1)) FOR [Synchronized]
*/
	SET @Step = 'Run DimInsert_Cursor for inserting rows into all dimensions'
		IF CURSOR_STATUS('global','DimInsert_Cursor') >= -1 DEALLOCATE DimInsert_Cursor
		DECLARE DimInsert_Cursor CURSOR FOR
			SELECT 
				DimensionID = MAX(DimensionID),
				DimensionName = CASE WHEN DimensionTypeID = 25 THEN 'Time_Property' ELSE DimensionName END,
				DimensionTypeID = MAX(DimensionTypeID),
				StorageTypeBM = MAX(StorageTypeBM),
				MappingTypeID = MAX(MappingTypeID),
				ReplaceTextYN = MAX(CONVERT(int, ReplaceTextYN))
			FROM
				#Dimension
			GROUP BY
				CASE WHEN DimensionTypeID = 25 THEN 'Time_Property' ELSE DimensionName END
			ORDER BY
				DimensionTypeID,
				DimensionID DESC

			OPEN DimInsert_Cursor
			FETCH NEXT FROM DimInsert_Cursor INTO @DimensionID, @DimensionName, @DimensionTypeID, @StorageTypeBM, @MappingTypeID, @ReplaceTextYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT DimensionID = @DimensionID, DimensionName = @DimensionName, DimensionTypeID = @DimensionTypeID, StorageTypeBM = @StorageTypeBM

					IF @DimensionTypeID IN (7, 25)  --Time and Time-properties
						BEGIN
							SET @SQLStatement =
								'EXEC ' + @ETLDatabase + '..spIU_0000_' + @DimensionName + ' @JobID = ' + CONVERT(NVARCHAR(10), @JobID)

							EXEC (@SQLStatement)
						END

					ELSE IF @DimensionTypeID IN (-1, 2, 3, 4, 5, 6, 8, 39)
						BEGIN
							SET @SQLStatement =
								'TRUNCATE TABLE ' + @ETLDatabase + '.[dbo].[wrk_Dimension]'
							EXEC (@SQLStatement)

							TRUNCATE TABLE #Member

							IF @DimensionTypeID = -1  --Financial segment
								BEGIN
									SELECT 
										@SegmentNo = MAX(SegmentNo),
										@SegmentCode = MAX(SegmentCode)
									FROM
										Journal_SegmentNo
									WHERE
										InstanceID = @InstanceID AND
										EntityID = @EntityID AND
										Book = 'GL' AND
										DimensionID = @DimensionID

									SET @SQLStatement = '
										INSERT INTO #Member
											(
											MemberKey,
											MemberDescription
											)
										SELECT
											MemberKey = O.ObjectCode,
											MemberDescription = O.ObjectName
										FROM
											[SIE4_Object] O
											INNER JOIN
											(
											SELECT DISTINCT
												MemberKey = Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(NVARCHAR(10), @SegmentNo) + '
											FROM
												Journal
											WHERE
												JobID = ' + CONVERT(NVARCHAR(10), @JobID) + ' AND
												InstanceID = ' + CONVERT(NVARCHAR(10), @InstanceID) + ' AND
												Segment' + CASE WHEN @SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(NVARCHAR(10), @SegmentNo) + ' IS NOT NULL
											) K ON K.MemberKey = O.ObjectCode
										WHERE
											O.[InstanceID] = ' + CONVERT(NVARCHAR(10), @InstanceID) + ' AND
											O.[JobID] = ' + CONVERT(NVARCHAR(10), @JobID) + ' AND
											O.[Param] = ''#OBJEKT'' AND
											O.[DimCode] = ''' + @SegmentCode + ''''

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

							ELSE IF @DimensionTypeID = 2  --BusinessProcess
								INSERT INTO #Member
									(
									MemberKey,
									Parent
									)
								SELECT DISTINCT
									MemberKey = [JournalSequence],
									Parent = 'SIE4'
								FROM
									Journal
								WHERE
									JobID = @JobID AND
									InstanceID = @InstanceID AND
									[JournalSequence] IS NOT NULL
								
							ELSE IF @DimensionTypeID = 3  --Currency
								INSERT INTO #Member
									(
									MemberKey
									)
								SELECT DISTINCT
									MemberKey = Currency_Book
								FROM
									Journal
								WHERE
									JobID = @JobID AND
									InstanceID = @InstanceID AND
									Currency_Book IS NOT NULL
								UNION SELECT DISTINCT
									MemberKey = Currency_Transaction
								FROM
									Journal
								WHERE
									JobID = @JobID AND
									InstanceID = @InstanceID AND
									Currency_Transaction IS NOT NULL
							
							ELSE IF @DimensionTypeID = 4  --Entity
								INSERT INTO #Member
									(
									[MemberKey],
									[MemberDescription]
									)
								SELECT DISTINCT
									[MemberKey] = J.[Entity],
									[MemberDescription] = ISNULL(E.[EntityName], J.[Entity])
								FROM
									Journal J
									LEFT JOIN Entity E ON E.[InstanceID] = J.[InstanceID] AND E.[VersionID] = @VersionID AND E.MemberKey = J.Entity
								WHERE
									J.[JobID] = @JobID AND
									J.[InstanceID] = @InstanceID AND
									J.[Entity] IS NOT NULL

							ELSE IF @DimensionTypeID = 6  --Scenario
								INSERT INTO #Member
									(
									MemberKey
									)
								SELECT DISTINCT
									MemberKey = Scenario
								FROM
									Journal
								WHERE
									JobID = @JobID AND
									InstanceID = @InstanceID AND
									Scenario IS NOT NULL

							SET @SQLStatement = '
								INSERT INTO ' + @ETLDatabase + '.[dbo].[wrk_Dimension]
									(
									[MemberId],
									[Label],
									[Description],
									[HelpText],
									[RNodeType],
									[Parent]
									)
								SELECT
									[MemberId] = MAX(sub.[MemberId]),
									[Label] = sub.[Label],
									[Description] = MAX(sub.[Description]),
									[HelpText] = MAX(sub.[HelpText]),
									[RNodeType] = MAX([RNodeType]),
									[Parent] = MAX([Parent])
								FROM
									(
									SELECT DISTINCT
										[MemberId] = M.MemberID,
										[Label] = #M.MemberKey,
										[Description] = COALESCE(#M.MemberDescription, M.[Description], #M.MemberKey),
										[HelpText] = M.HelpText,
										[RNodeType] = ''L'',
										[Parent] = ISNULL(#M.[Parent], ''All_'')
									FROM
										#Member #M
										LEFT JOIN Member M ON M.DimensionID = ' + CONVERT(NVARCHAR(10), @DimensionID) + ' AND M.Label = #M.MemberKey AND M.SelectYN <> 0
									
									UNION SELECT DISTINCT
										[MemberId] = M.MemberID,
										[Label] = M.Label,
										[Description] = REPLACE(M.[Description], ''@All_Dimension'', ''All ' + @DimensionName + '''), 
										[HelpText] = M.HelpText,
										[RNodeType] = M.[RNodeType],
										[Parent] = M.[Parent]
									FROM
										Member M 
									WHERE
										M.DimensionID IN (0, ' + CONVERT(NVARCHAR(10), @DimensionID) + ') AND
										M.SourceTypeBM & 32 > 0 AND
										M.ModelBM & 64 > 0 AND
										M.SelectYN <> 0
									) sub
								GROUP BY
									sub.[Label]'

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @SQLStatement = '
								EXEC ' + @ETLDatabase + '..spIU_0000_Dimension_Generic @JobID = ' + CONVERT(NVARCHAR(10), @JobID) + ', @DimensionID = ' + CONVERT(NVARCHAR(10), @DimensionID) + ', @Dimension = ''' + @DimensionName + ''''
							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

					ELSE IF @DimensionTypeID IN (1)  --Natural Account
						BEGIN

							EXEC [spIU_Dim_Account_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @SourceTypeID = @SourceTypeID, @Entity_MemberKey = @Entity_MemberKey, @JobID = @JobID
						/**
							TRUNCATE TABLE [#Member]
							TRUNCATE TABLE [#Account_Members]

							INSERT INTO #Member
								(
								MemberKey,
								MemberDescription
								)
							SELECT
								MemberKey = K.MemberKey,
								MemberDescription = O.ObjectName
							FROM
								[SIE4_Object] O
								INNER JOIN
								(
								SELECT DISTINCT
									MemberKey = Account
								FROM
									Journal
								WHERE
--									JobID = @JobID AND
									InstanceID = @InstanceID AND
									Account IS NOT NULL
								) K ON K.MemberKey = CASE WHEN @MappingTypeID = 1 THEN @Entity + '_' ELSE '' END + O.ObjectCode + CASE WHEN @MappingTypeID = 2 THEN '_' + @Entity ELSE '' END
							WHERE
								O.[InstanceID] = @InstanceID AND
								O.[JobID] = @JobID AND
								O.[Param] = '#KONTO' AND
								O.[DimCode] = 'Account'
							
							INSERT INTO [#Account_Members]
								(
								[MemberId],
								[Label],
								[Description],
								[HelpText],
								[RNodeType],
								[SBZ],
								[Source],
								[Parent]
								)
							SELECT
								[MemberId] = MAX(sub.[MemberId]),
								[Label] = sub.[Label],
								[Description] = MAX(sub.[Description]),
								[HelpText] = MAX(sub.[HelpText]),
								[RNodeType] = MAX([RNodeType]),
								[SBZ] = MAX([SBZ]),
								[Source] = MAX([Source]),
								[Parent] = MAX([Parent])
							FROM
								(
								SELECT DISTINCT
									[MemberId] = M.MemberID,
									[Label] = #M.MemberKey,
									[Description] = COALESCE(#M.MemberDescription, M.[Description], #M.MemberKey),
									[HelpText] = M.HelpText,
									[RNodeType] = 'L',
									[SBZ] = 0,
									[Source] = 'SIE4',
									[Parent] = 'All_'
								FROM
									#Member #M
									LEFT JOIN Member M ON M.DimensionID = @DimensionID AND M.Label = #M.MemberKey AND M.SelectYN <> 0
									
								UNION SELECT DISTINCT
									[MemberId] = M.MemberID,
									[Label] = M.Label,
									[Description] = REPLACE(M.[Description], '@All_Dimension', 'All ' + @DimensionName), 
									[HelpText] = M.HelpText,
									[RNodeType] = M.[RNodeType],
									[SBZ] = CASE WHEN M.[RNodeType] = 'P' THEN 1 ELSE 0 END,
									[Source] = 'ETL',
									[Parent] = M.[Parent]
								FROM
									Member M 
								WHERE
									M.DimensionID IN (0, @DimensionID) AND
									M.SourceTypeBM & 32 > 0 AND
									M.ModelBM & 64 > 0 AND
									M.SelectYN <> 0
								) sub
							GROUP BY
								sub.[Label]

							CREATE TABLE #AccountType
								(
								[KTYP] [nchar](1),
								[AccountType] [nvarchar](50),
								[Sign] [int],
								[TimeBalance] [bit],
								[Rate] [nvarchar](255),
								[Rate_MemberId] [bigint],
								[Parent] [nvarchar](50)
								)
				
							INSERT INTO #AccountType
								(
								[KTYP],
								[AccountType],
								[Sign],
								[TimeBalance],
								[Rate],
								[Rate_MemberId],
								[Parent]
								)
							SELECT
								[KTYP],
								[AccountType],
								[Sign],
								[TimeBalance],
								[Rate],
								[Rate_MemberId],
								[Parent]
							FROM
								(
										SELECT [KTYP] = 'T',	[AccountType] = 'Asset',		[Sign] = 1,		[TimeBalance] = 1, [Rate] = 'EOP',		[Rate_MemberId] = 102,	[Parent] = 'Assets_'
								UNION	SELECT [KTYP] = 'S',	[AccountType] = 'Equity',		[Sign] = -1,	[TimeBalance] = 1, [Rate] = 'EOP',		[Rate_MemberId] = 102,	[Parent] = 'Equity_'
								UNION	SELECT [KTYP] = 'K',	[AccountType] = 'Expense',		[Sign] = 1,		[TimeBalance] = 0, [Rate] = 'Average',	[Rate_MemberId] = 101,	[Parent] = 'Expense_'
								UNION	SELECT [KTYP] = 'I',	[AccountType] = 'Income',		[Sign] = -1,	[TimeBalance] = 0, [Rate] = 'Average',	[Rate_MemberId] = 101,	[Parent] = 'Gross_Profit_'
								UNION	SELECT [KTYP] = '0',	[AccountType] = 'Liability',	[Sign] = -1,	[TimeBalance] = 1, [Rate] = 'EOP',		[Rate_MemberId] = 102,	[Parent] = 'Liabilities_'
								) sub

							--KTYP anges som T, S, K eller I (Tillgång, Skuld, Kostnad eller Intäkt)

							IF @KPTYP LIKE '%BAS%'
								BEGIN
									UPDATE AM
									SET 
										[Account Type] = AT.[AccountType],
										[Rate] = AT.[Rate],
										[Rate_MemberId] = AT.[Rate_MemberId],	
										[Sign] = AT.[Sign],
										[TimeBalance] = AT.[TimeBalance],
										[Parent] = AT.[Parent]
									FROM
										[#Account_Members] AM
										INNER JOIN #AccountType AT ON AT.AccountType = CASE SUBSTRING(AM.Label, 1, 1)
											WHEN '1' THEN 'Asset'
											WHEN '2' THEN CASE WHEN SUBSTRING(AM.Label, 1, 2) IN ('25', '26') THEN 'Liability' ELSE 'Equity' END
											WHEN '3' THEN 'Income'
											WHEN '4' THEN 'Expense'
											WHEN '5' THEN 'Expense'
											WHEN '6' THEN 'Expense'
											WHEN '7' THEN 'Expense'
											WHEN '8' THEN 'Expense'
											WHEN '9' THEN 'Expense'
											ELSE NULL END
								END

							ELSE
								BEGIN
									UPDATE AM
									SET 
										[Account Type] = AT.[AccountType],
										[Rate] = AT.[Rate],
										[Rate_MemberId] = AT.[Rate_MemberId],	
										[Sign] = AT.[Sign],
										[TimeBalance] = AT.[TimeBalance],
										[Parent] = AT.[Parent]
									FROM
										[#Account_Members] AM
										INNER JOIN [SIE4_Object] O ON O.InstanceID = @InstanceID AND O.[JobID] = @JobID AND O.[Param] = '#KTYP' AND O.DimCode = 'Account' AND O.ObjectCode = AM.[Label]
										INNER JOIN #AccountType AT ON AT.KTYP = O.ObjectName
								END
		
							DROP TABLE #AccountType

							UPDATE AM
							SET
								[Rate] = ISNULL(sub.[Rate], 'NONE'),
								[Rate_MemberID] = CASE sub.[Rate] WHEN 'Average' THEN 101 WHEN 'EOP' THEN 102 WHEN 'History' THEN 103 ELSE -1 END,
								[TimeBalance] = sub.[TimeBalance],
								[KeyName_Account] = sub.[KeyName_Account],
								[Account Type] = sub.[Account Type],
								[Sign] = sub.[Sign]
							FROM
								#Account_Members AM
								INNER JOIN
								(
								SELECT
									AM.[MemberID],
									[Rate] = MAX(CASE WHEN MPV.PropertyID = -5 THEN REPLACE(MPV.Value, '''', '') END),
									[TimeBalance] = MAX(CASE WHEN MPV.PropertyID = -8 THEN MPV.Value END),
									[KeyName_Account] = MAX(CASE WHEN MPV.PropertyID = -126 THEN REPLACE(MPV.Value, '''', '') END),
									[Account Type] = MAX(CASE WHEN MPV.PropertyID = -4 THEN REPLACE(MPV.Value, '''', '') END),
									[Sign] = MAX(CASE WHEN MPV.PropertyID = -7 THEN MPV.Value END)
								FROM	
									#Account_Members AM
									INNER JOIN Member_Property_Value MPV ON MPV.DimensionID = -1 AND MPV.MemberID = AM.MemberID
								GROUP BY
									AM.MemberID
								) sub ON sub.MemberID = AM.MemberID

							IF @Debug <> 0 SELECT TempTable = '#Account_Members', * FROM [#Account_Members] ORDER BY Label
							
							SET @SQLStatement = '
								EXEC ' + @ETLDatabase + '..spIU_0000_Account @JobID = ' + CONVERT(NVARCHAR(10), @JobID)
							IF @Debug <> 0 PRINT @SQLStatement
							PRINT @SQLStatement
							EXEC (@SQLStatement)
*/
						END
						
					ELSE
						SELECT
							DimensionID = @DimensionID,
							DimensionName = @DimensionName,
							DimensionTypeID = @DimensionTypeID,
							[Status] = 'Not executed'

					FETCH NEXT FROM DimInsert_Cursor INTO  @DimensionID, @DimensionName, @DimensionTypeID, @StorageTypeBM, @MappingTypeID, @ReplaceTextYN
				END

		CLOSE DimInsert_Cursor
		DEALLOCATE DimInsert_Cursor	

	SET @Step = 'Drop temp tables'
		DROP TABLE [#Dimension]
		DROP TABLE [#Member]
		--DROP TABLE [#Account_Members]

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
