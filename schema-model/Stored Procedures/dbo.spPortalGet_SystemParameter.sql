SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_SystemParameter]

	@UserID      nvarchar(50),
	@InstanceID    int

--#WITH ENCRYPTION#--
                         
AS

--EXEC [spPortalGet_SystemParameter] @UserID = 1005, @InstanceID = 356
--EXEC [spPortalGet_SystemParameter] @UserID = 1005, @InstanceID = 357

SET NOCOUNT ON
                
SELECT 
	[InstanceID],
	[Parameter],
	[ParameterTypeID],
	[ProcessID],
	[ParameterDescription],
	[HelpText],
	[ParameterValue],
	[UxFieldTypeID],
	[UxEditableYN],
	[UxHelpUrl],
	[UxSelectionSource],
	[Version]
FROM
	[SystemParameter]
WHERE
	InstanceID IN (0, @InstanceID)

GO
