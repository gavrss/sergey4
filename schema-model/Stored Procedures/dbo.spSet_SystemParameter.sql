SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_SystemParameter]

--@UserID int,
@InstanceID int,
@Parameter nvarchar(50),
@ParameterValue nvarchar(50)

--#WITH ENCRYPTION#--

AS

--EXEC [spSet_SystemParameter] @InstanceID = 400, @Parameter = '@LatestSopFcstCommit', @ParameterValue = '201704'

SET NOCOUNT ON

--UPDATE                
UPDATE SP
SET 
	[ParameterValue] = @ParameterValue
FROM
	[SystemParameter] SP
WHERE
	[InstanceID] = @InstanceID AND
	[Parameter] = @Parameter

GO
