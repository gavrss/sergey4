SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Linked]
	(
	@SourceID int = NULL,
	@LinkedYN bit = NULL OUT,
	@LinkedBM int = NULL OUT,
	@LinkedETL nvarchar(100) = NULL OUT,
	@GetVersion bit = 0,
	@Debug bit = 0
	)

--#WITH ENCRYPTION#--

AS

/*
DECLARE @LinkedYN bit, @LinkedETL nvarchar(100)
EXEC spGet_Linked @SourceID = 103, @LinkedYN = @LinkedYN OUT, @LinkedETL = @LinkedETL OUT
SELECT LinkedYN = @LinkedYN, LinkedETL = @LinkedETL

DECLARE @LinkedYN bit, @LinkedETL nvarchar(100)
EXEC spGet_Linked @SourceID = 127, @LinkedYN = @LinkedYN OUT, @LinkedETL = @LinkedETL OUT
SELECT LinkedYN = @LinkedYN, LinkedETL = @LinkedETL

DECLARE @LinkedBM int
EXEC spGet_Linked @SourceID = 127, @LinkedBM = @LinkedBM OUT
SELECT LinkedBM = @LinkedBM

EXEC spGet_Linked @SourceID = 127, @Debug = 1

EXEC spGet_Linked @GetVersion = 1
*/

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2075'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2070' SET @Description = 'Procedure created.'
		IF @Version = '1.3.2073' SET @Description = 'Parameter @LinkedETL added.'
		IF @Version = '1.3.2075' SET @Description = 'Parameter @LinkedBM added.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID IS NULL
	BEGIN
		PRINT 'Parameter @SourceID must be set'
		RETURN 
	END

SET @LinkedETL = ''

IF (SELECT COUNT(1) FROM pcINTEGRATOR..[Source] S WHERE S.SourceID = @SourceID AND S.SourceDatabase LIKE '%.%') > 0
	BEGIN
		SET @LinkedYN = 1
		SET @LinkedBM = 2
	END
ELSE
	BEGIN
		SET @LinkedYN = 0
		SET @LinkedBM = 1
	END

IF  @LinkedYN <> 0
	SELECT
		@LinkedETL = '[' + SUBSTRING(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), 1, CHARINDEX('.', REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', '')) - 1) + '].[' + REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', '') + '].[dbo].'
	FROM
		pcINTEGRATOR..[Source] S
		INNER JOIN pcINTEGRATOR..[Model] M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
		INNER JOIN pcINTEGRATOR..[Application] A ON A.ApplicationID = M.ApplicationID AND S.SelectYN <> 0
	WHERE
		S.SourceID = @SourceID AND
		S.SelectYN <> 0

IF @Debug <> 0 
	BEGIN
		SELECT
			LinkedYN = @LinkedYN,
			LinkedETL = @LinkedETL
		PRINT 'LinkedYN = ' + CONVERT(nvarchar(10), @LinkedYN) + ', LinkedETL = ' + @LinkedETL
	END






GO
