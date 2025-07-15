CREATE TABLE [dbo].[@Template_EnvironmentLevel]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_EnvironmentLevel_InstanceID] DEFAULT ((0)),
[EnvironmentLevelID] [int] NOT NULL,
[EnvironmentLevelName] [nvarchar] (50) NOT NULL,
[EnvironmentLevelDescription] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_EnvironmentLevel_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[EnvironmentLevel_Upd]
	ON [dbo].[@Template_EnvironmentLevel]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE EL
	SET
		[Version] = @Version
	FROM
		[@Template_EnvironmentLevel] EL
		INNER JOIN Inserted I ON	
			I.EnvironmentLevelID = EL.EnvironmentLevelID
GO
ALTER TABLE [dbo].[@Template_EnvironmentLevel] ADD CONSTRAINT [PK_EnvironmentLevel] PRIMARY KEY CLUSTERED ([EnvironmentLevelID])
GO
