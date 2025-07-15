SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Revision]
	(
	@SourceID int = NULL,
	@RevisionBM int = NULL OUT,
	@GetVersion bit = 0,
	@Debug bit = 0
	)

--#WITH ENCRYPTION#--

AS

/*
DECLARE @RevisionBM int
EXEC [spGet_Revision] @SourceID = 1147, @RevisionBM = @RevisionBM OUT
SELECT RevisionBM = @RevisionBM

DECLARE @RevisionBM int
EXEC [spGet_Revision] @SourceID = 127, @RevisionBM = @RevisionBM OUT
SELECT RevisionBM = @RevisionBM

EXEC [spGet_Revision] @SourceID = -1077, @Debug = 1

EXEC [spGet_Revision] @GetVersion = 1
*/

DECLARE
	@SourceDatabase nvarchar(100),
	@SourceTypeID int,
	@SQLStatement nvarchar(max),
	@Version nvarchar(50) = '1.4.0.2139',
	@Description nvarchar(255)

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2073' SET @Description = 'Procedure created.'
		IF @Version = '1.3.2075' SET @Description = 'Fixed bug, hardcoded reference to SourceDatabase.'
		IF @Version = '1.3.2108' SET @Description = 'Add brackets around @SourceDatabase.'
		IF @Version = '1.4.0.2139' SET @Description = 'Handle negative SourceID.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID IS NULL
	BEGIN
		PRINT 'Parameter @SourceID must be set'
		RETURN 
	END


SELECT
	@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
	@SourceTypeID = S.SourceTypeID
FROM
	[Source] S
WHERE
	S.SourceID = @SourceID

IF @Debug <> 0 SELECT SourceDatabase = @SourceDatabase, SourceTypeID = @SourceTypeID

IF @SourceTypeID = 11
	BEGIN
		CREATE TABLE #Number (Number int)
		SET @SQLStatement = '
			SELECT Number =
			(SELECT COUNT(1) FROM ' + @SourceDatabase + '.sys.tables WHERE [name] = ''BudgetCode'') +
			(SELECT COUNT(1) FROM
				' + @SourceDatabase + '.sys.all_columns ac
				INNER JOIN ' + @SourceDatabase + '.sys.tables t ON t.object_id = ac.object_id AND t.name = ''GLBudgetDtl''
			WHERE
				ac.name = ''BudgetCodeID'')'

		IF @Debug <> 0 PRINT @SQLStatement

		INSERT INTO #Number (Number) EXEC(@SQLStatement)

		IF (SELECT Number FROM #Number) = 2
			SET @RevisionBM = 2
		ELSE
			SET @RevisionBM = 1

		DROP TABLE #Number
	END
ELSE
	SET @RevisionBM = 1

IF @Debug <> 0 
	BEGIN
		SELECT
			RevisionBM = @RevisionBM
		PRINT 'RevisionBM = ' + CONVERT(nvarchar(10), @RevisionBM)
	END






GO
