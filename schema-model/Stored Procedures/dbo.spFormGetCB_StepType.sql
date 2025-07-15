SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spFormGetCB_StepType] 

	@GetVersion bit = 0

--#WITH ENCRYPTION#--

AS

DECLARE
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.1.2124'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.1.2124' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

	SELECT
		[StepTypeBM],
		[StepTypeName]
	FROM
		[StepType] ST
	WHERE
		NOT EXISTS (SELECT 1 FROM [StepType] STC WHERE [StepTypeBM] & 1025 > 0 AND STC.StepTypeBM = ST.StepTypeBM) AND
		(SysAdminYN = 0 OR IS_SRVROLEMEMBER('sysadmin') = 1)
	ORDER BY
		[StepTypeBM]


GO
