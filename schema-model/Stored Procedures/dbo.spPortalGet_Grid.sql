SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Grid]

	@UserID      int,
	@InstanceID    int,
	@VersionID int = 0

--#WITH ENCRYPTION#--
                         
AS

--EXEC [spPortalGet_Grid] @UserID = 1005, @InstanceID = 356
--EXEC [spPortalGet_Grid] @UserID = 1005, @InstanceID = 357

SET NOCOUNT ON
                
SELECT 
	[GridID],
	[GridName],
	[GridDescription],
	[GetProc],
	[SetProc]
FROM
	[Grid]
WHERE
	InstanceID IN (0, @InstanceID)
GO
