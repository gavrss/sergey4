SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Owner] 
	(
	@SourceTypeID int = NULL,
	@Owner nvarchar(50) = NULL OUTPUT,
	@GetVersion bit = 0,
	@Debug bit = 0
	)

--#WITH ENCRYPTION#--
AS

--EXEC [spGet_Owner] @SourceTypeID = 1, @Debug = 1
--EXEC [spGet_Owner] @SourceTypeID = 11, @Debug = 1

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.2.2052'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceTypeID IS NULL
	BEGIN
		PRINT 'Parameter @SourceTypeID must be set'
		RETURN 
	END
	
	SELECT @Owner = [Owner]
	FROM SourceType
	WHERE SourceTypeID = @SourceTypeID

	IF @Debug <> 0 
		BEGIN
			SELECT Owner = @Owner
			PRINT 'Owner =  ' + @Owner
		END






GO
