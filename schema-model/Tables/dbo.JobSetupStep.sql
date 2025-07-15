CREATE TABLE [dbo].[JobSetupStep]
(
[JobSetupStepBM] [int] NOT NULL,
[JobSetupStepName] [nvarchar] (50) NOT NULL,
[SysAdminYN] [bit] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_JobSetupStep_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[JobSetupStep_Upd]
	ON [dbo].[JobSetupStep]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE JSS
	SET
		[Version] = @Version
	FROM
		[JobSetupStep] JSS
		INNER JOIN Inserted I ON	
			I.JobSetupStepBM = JSS.JobSetupStepBM


GO
ALTER TABLE [dbo].[JobSetupStep] ADD CONSTRAINT [PK_JobSetupStep] PRIMARY KEY CLUSTERED ([JobSetupStepBM])
GO
