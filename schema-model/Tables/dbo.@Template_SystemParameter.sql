CREATE TABLE [dbo].[@Template_SystemParameter]
(
[InstanceID] [int] NOT NULL,
[Parameter] [nvarchar] (50) NOT NULL,
[ParameterTypeID] [int] NOT NULL,
[ProcessID] [int] NOT NULL CONSTRAINT [DF_SystemParameter_ProcessID] DEFAULT ((0)),
[ParameterDescription] [nvarchar] (255) NOT NULL,
[HelpText] [nvarchar] (1024) NOT NULL CONSTRAINT [DF_SystemParameter_HelpText] DEFAULT (''),
[ParameterValue] [nvarchar] (50) NOT NULL,
[UxFieldTypeID] [int] NOT NULL,
[UxEditableYN] [bit] NOT NULL CONSTRAINT [DF_SystemParameter_UxEditableYN] DEFAULT ((0)),
[UxHelpUrl] [nvarchar] (255) NULL,
[UxSelectionSource] [nvarchar] (max) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SystemParameter_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SystemParameter_Upd]
	ON [dbo].[@Template_SystemParameter]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SP
	SET
		[Version] = @Version
	FROM
		[@Template_SystemParameter] SP
		INNER JOIN Inserted I ON	
			I.InstanceID = SP.InstanceID AND
			I.Parameter = SP.Parameter

GO
ALTER TABLE [dbo].[@Template_SystemParameter] ADD CONSTRAINT [PK_SystemParameter] PRIMARY KEY CLUSTERED ([InstanceID], [Parameter])
GO
ALTER TABLE [dbo].[@Template_SystemParameter] ADD CONSTRAINT [FK_SystemParameter_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_SystemParameter] ADD CONSTRAINT [FK_SystemParameter_ParameterType] FOREIGN KEY ([ParameterTypeID]) REFERENCES [dbo].[@Template_ParameterType] ([ParameterTypeID])
GO
ALTER TABLE [dbo].[@Template_SystemParameter] ADD CONSTRAINT [FK_SystemParameter_Process] FOREIGN KEY ([ProcessID]) REFERENCES [dbo].[@Template_Process] ([ProcessID])
GO
ALTER TABLE [dbo].[@Template_SystemParameter] ADD CONSTRAINT [FK_SystemParameter_UxFieldType] FOREIGN KEY ([UxFieldTypeID]) REFERENCES [dbo].[@Template_UxFieldType] ([UxFieldTypeID])
GO
