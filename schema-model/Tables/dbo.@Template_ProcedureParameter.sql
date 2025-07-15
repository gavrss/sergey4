CREATE TABLE [dbo].[@Template_ProcedureParameter]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_@Template_ProcedureParameter_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_ProcedureParameter_VersionID] DEFAULT ((0)),
[ProcedureID] [int] NOT NULL,
[Parameter] [nvarchar] (100) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ProcedureParameter_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ProcedureParameter_Upd]
	ON [dbo].[@Template_ProcedureParameter]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE PP
	SET
		[Version] = @Version
	FROM
		[@Template_ProcedureParameter] PP
		INNER JOIN [Inserted] I ON	
			I.ProcedureID = PP.ProcedureID AND
			I.Parameter = PP.Parameter
GO
ALTER TABLE [dbo].[@Template_ProcedureParameter] ADD CONSTRAINT [PK_ProcedureParameter] PRIMARY KEY CLUSTERED ([ProcedureID], [Parameter])
GO
ALTER TABLE [dbo].[@Template_ProcedureParameter] ADD CONSTRAINT [FK_ProcedureParameter_Procedure] FOREIGN KEY ([ProcedureID]) REFERENCES [dbo].[@Template_Procedure] ([ProcedureID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Mandatory parameters', 'SCHEMA', N'dbo', 'TABLE', N'@Template_ProcedureParameter', 'COLUMN', N'Parameter'
GO
