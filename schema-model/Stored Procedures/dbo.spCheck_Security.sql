SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_Security]

@InstanceID int = NULL,
@UserID int = NULL,
@ObjectTypeBM int = NULL, --2048 = DrillPage
@SecurityLevelBM int = NULL, --4 = Admin, 16 = Write, 32 = Read
@ValidYN bit = 0 OUT,
@GetVersion bit = 0,
@Debug int = 0

/*
DECLARE @ValidYN bit
EXEC spCheck_Security @ApplicationID = 400, @ExtensionTypeID = 50, @ValidYN = @ValidYN OUT
SELECT ValidYN = @ValidYN

EXEC spCheck_Security @InstanceID = 400, @UserID = 1005, @ObjectTypeBM = 2048, @SecurityLevelBM = 4
*/

--#WITH ENCRYPTION#--

AS

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @InstanceID IS NULL OR @UserID IS NULL OR @ObjectTypeBM IS NULL OR @SecurityLevelBM IS NULL
	BEGIN
		PRINT 'Parameter @InstanceID, @UserID, @ObjectTypeBM and @SecurityLevelBM must be set'
		RETURN 
	END

--Set @ValidYN
	SET @ValidYN = 1

	IF (
		SELECT
			COUNT(1)
		FROM
			[User] U1
			LEFT JOIN [pcINTEGRATOR].[dbo].[UserMember] UM ON UM.UserID_User = U1.UserID AND UM.SelectYN <> 0
			LEFT JOIN [User] U2 ON U2.InstanceID = U1.InstanceID AND U2.UserID = UM.UserID_Group AND U2.UserTypeID = -2 AND U2.SelectYN <> 0
			INNER JOIN SecurityRoleUser SRU ON (SRU.UserID = U1.UserID OR SRU.UserID = U2.UserID) AND SRU.SelectYN <> 0
			INNER JOIN SecurityRole SR ON SR.InstanceID = U1.InstanceID AND SR.SecurityRoleID = SRU.SecurityRoleID AND SR.SelectYN <> 0
			INNER JOIN SecurityRoleObject SRO ON SRO.SecurityRoleID = SR.SecurityRoleID AND SRO.SecurityLevelBM & @SecurityLevelBM > 0 AND SRO.SelectYN <> 0
			INNER JOIN [Object] O ON O.InstanceID = U1.InstanceID AND O.ObjectID = SRO.ObjectID AND O.ObjectTypeBM & @ObjectTypeBM > 0 AND O.SelectYN <> 0
		WHERE
			U1.InstanceID = @InstanceID AND
			U1.UserID = @UserID AND
			U1.UserTypeID = -1 AND
			U1.SelectYN <> 0
		) = 0 SET @ValidYN = 0

--Return result
	SELECT ValidYN = @ValidYN

GO
