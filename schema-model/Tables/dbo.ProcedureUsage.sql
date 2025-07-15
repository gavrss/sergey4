CREATE TABLE [dbo].[ProcedureUsage]
(
[ProcedureUsageID] [int] NOT NULL IDENTITY(1001, 1),
[ProcedureID] [int] NOT NULL,
[Module] [nvarchar] (50) NULL,
[Section] [nvarchar] (50) NULL,
[Page] [nvarchar] (50) NULL,
[Comment] [nvarchar] (1024) NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_ProcedureUsage_Inserted] DEFAULT (getdate()),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ProcedureUsage_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ProcedureUsage_Upd]
	ON [dbo].[ProcedureUsage]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE PU
	SET
		[Version] = @Version
	FROM
		[ProcedureUsage] PU
		INNER JOIN Inserted I ON	
			I.ProcedureUsageID = PU.ProcedureUsageID
GO
ALTER TABLE [dbo].[ProcedureUsage] ADD CONSTRAINT [PK_ProcedureUsage] PRIMARY KEY CLUSTERED ([ProcedureUsageID])
GO
CREATE NONCLUSTERED INDEX [ProcedureUsage_ProcedureID] ON [dbo].[ProcedureUsage] ([ProcedureID])
GO
