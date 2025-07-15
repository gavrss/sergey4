CREATE TABLE [dbo].[CheckSumStatus]
(
[CheckSumStatusID] [int] NOT NULL,
[CheckSumStatusName] [nvarchar] (50) NOT NULL,
[CheckSumStatusDescription] [nvarchar] (50) NOT NULL,
[CheckSumStatusBM] [int] NOT NULL CONSTRAINT [DF_CheckSumStatus_CheckSumStatusBM] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_CheckSumStatus_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[CheckSumStatus_Upd]
	ON [dbo].[CheckSumStatus]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE CSS
	SET
		[Version] = @Version
	FROM
		[CheckSumStatus] CSS
		INNER JOIN Inserted I ON	
			I.CheckSumStatusID = CSS.CheckSumStatusID
GO
ALTER TABLE [dbo].[CheckSumStatus] ADD CONSTRAINT [PK_CheckSumStatus] PRIMARY KEY CLUSTERED ([CheckSumStatusID])
GO
