CREATE TABLE [dbo].[JobQueueStatus]
(
[JobQueueStatusID] [int] NOT NULL,
[JobQueueStatusName] [nvarchar] (20) NOT NULL,
[JobQueueStatusDescription] [nvarchar] (100) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_JobQueueStatus_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[JobQueueStatus_Upd]
	ON [dbo].[JobQueueStatus]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE JQS
	SET
		[Version] = @Version
	FROM
		[JobQueueStatus] JQS
		INNER JOIN Inserted I ON	
			I.JobQueueStatusID = JQS.JobQueueStatusID
GO
ALTER TABLE [dbo].[JobQueueStatus] ADD CONSTRAINT [PK_JobQueueStatus] PRIMARY KEY CLUSTERED ([JobQueueStatusID])
GO
