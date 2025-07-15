CREATE TABLE [dbo].[JobFrequency]
(
[JobFrequencyBM] [int] NOT NULL,
[JobFrequencyName] [nvarchar] (50) NOT NULL,
[JobFrequencyDescription] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[JobFrequency_Upd]
	ON [dbo].[JobFrequency]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE JF
	SET
		[Version] = @Version
	FROM
		[JobFrequency] JF
		INNER JOIN Inserted I ON	
			I.[JobFrequencyBM] = JF.[JobFrequencyBM]
GO
ALTER TABLE [dbo].[JobFrequency] ADD CONSTRAINT [PK_JobFrequency] PRIMARY KEY CLUSTERED ([JobFrequencyBM])
GO
