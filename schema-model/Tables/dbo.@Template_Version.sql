CREATE TABLE [dbo].[@Template_Version]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[VersionName] [nvarchar] (50) NOT NULL,
[VersionDescription] [nvarchar] (100) NOT NULL,
[EnvironmentLevelID] [int] NOT NULL,
[ModelingLockedYN] [bit] NOT NULL CONSTRAINT [DF_Version_ModellingLockedYN] DEFAULT ((0)),
[DataLockedYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Version_DataLockedYN] DEFAULT ((0)),
[ErasableYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Version_ErasableYN] DEFAULT ((0)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Version_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Version_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Version_Upd]
	ON [dbo].[@Template_Version]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE V
	SET
		[Version] = @Version
	FROM
		[@Template_Version] V
		INNER JOIN Inserted I ON	
			I.VersionID = V.VersionID
GO
ALTER TABLE [dbo].[@Template_Version] ADD CONSTRAINT [PK_Version] PRIMARY KEY CLUSTERED ([VersionID])
GO
ALTER TABLE [dbo].[@Template_Version] ADD CONSTRAINT [FK_Version_EnvironmentLevel] FOREIGN KEY ([EnvironmentLevelID]) REFERENCES [dbo].[@Template_EnvironmentLevel] ([EnvironmentLevelID])
GO
ALTER TABLE [dbo].[@Template_Version] ADD CONSTRAINT [FK_Version_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'If DataLockedYN=1, all set SPs that change information on FACT and Dimension tables is disabled.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Version', 'COLUMN', N'DataLockedYN'
GO
EXEC sp_addextendedproperty N'MS_Description', N'If ErasableYN=1, the Instance/Version can be deleted. If 0, can not be deleted.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Version', 'COLUMN', N'ErasableYN'
GO
EXEC sp_addextendedproperty N'MS_Description', N'All set SPs that change the structure is disabled.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Version', 'COLUMN', N'ModelingLockedYN'
GO
