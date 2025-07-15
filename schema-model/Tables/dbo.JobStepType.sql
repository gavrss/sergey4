CREATE TABLE [dbo].[JobStepType]
(
[JobStepTypeBM] [int] NOT NULL,
[JobStepTypeName] [nvarchar] (50) NOT NULL,
[JobStepTypeDescription] [nvarchar] (255) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_JobStepType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[JobStepType_Upd]
	ON [dbo].[JobStepType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE JST
	SET
		[Version] = @Version
	FROM
		[JobStepType] JST
		INNER JOIN Inserted I ON	
			I.JobStepTypeBM = JST.JobStepTypeBM
GO
ALTER TABLE [dbo].[JobStepType] ADD CONSTRAINT [PK_JobStepType] PRIMARY KEY CLUSTERED ([JobStepTypeBM])
GO
