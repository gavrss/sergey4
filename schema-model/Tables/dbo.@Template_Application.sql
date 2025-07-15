CREATE TABLE [dbo].[@Template_Application]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_Application_VersionID] DEFAULT ((0)),
[ApplicationID] [int] NOT NULL,
[ApplicationName] [nvarchar] (100) NOT NULL,
[ApplicationDescription] [nvarchar] (255) NOT NULL,
[ApplicationServer] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Application_ApplicationServer] DEFAULT (N'localhost'),
[StorageTypeBM] [int] NOT NULL CONSTRAINT [DF_@Template_Application_StorageTypeBM] DEFAULT ((4)),
[ETLDatabase] [nvarchar] (100) NOT NULL,
[DestinationDatabase] [nvarchar] (100) NOT NULL,
[TabularServer] [nvarchar] (100) NULL,
[AdminUser] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Application_AdminUser] DEFAULT (suser_name()),
[FiscalYearStartMonth] [int] NOT NULL CONSTRAINT [DF_Application_FiscalYearStartMonth] DEFAULT ((1)),
[MasterClosedMonth] [int] NULL,
[FinancialsClosedMonth] [int] NULL,
[LanguageID] [int] NOT NULL CONSTRAINT [DF_Application_LanguageID] DEFAULT ((0)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Application_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Application_Version] DEFAULT (''),
[ReadSecurityByOpYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Application_ReadSecurityByOpYN] DEFAULT ((0)),
[EnhancedStorageYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Application_EnhancedStorageYN] DEFAULT ((0)),
[UseCachedSourceDatabaseYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Application_UseCachedSourceDatabaseYN] DEFAULT ((0)),
[CallistoDeployAndRefreshYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Application_CallistoDeployAndRefreshYN] DEFAULT ((-1))
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Application_Upd]
	ON [dbo].[@Template_Application]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
	
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)

	UPDATE A
	SET
		[ETLDatabase] = 'pcETL_' + I.[ApplicationName],
		[DestinationDatabase] = 'pcDATA_' + I.[ApplicationName],
		[Version] = @Version
	FROM
		[@Template_Application] A
		INNER JOIN Inserted I ON I.ApplicationID = A.ApplicationID

	UPDATE M
	SET
		SelectYN = I.SelectYN
	FROM
		[@Template_Model] M 
		INNER JOIN [Inserted] I ON I.ApplicationID = M.ApplicationID
		INNER JOIN [Deleted] D ON D.ApplicationID = I.ApplicationID AND D.SelectYN <> I.SelectYN
GO
ALTER TABLE [dbo].[@Template_Application] ADD CONSTRAINT [PK_Application] PRIMARY KEY CLUSTERED ([ApplicationID])
GO
CREATE UNIQUE NONCLUSTERED INDEX [ApplicationName] ON [dbo].[@Template_Application] ([ApplicationName])
GO
CREATE UNIQUE NONCLUSTERED INDEX [InstanceID_VersionID] ON [dbo].[@Template_Application] ([InstanceID], [VersionID])
GO
ALTER TABLE [dbo].[@Template_Application] ADD CONSTRAINT [FK_Application_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Application] ADD CONSTRAINT [FK_Application_Language] FOREIGN KEY ([LanguageID]) REFERENCES [dbo].[Language] ([LanguageID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Should be latest month in a FiscalYear. This month and all prior months are locked and can not be changed.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Application', 'COLUMN', N'FinancialsClosedMonth'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Based on ApplicationID. Used when upgrading.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Application', 'COLUMN', N'InheritedFrom'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Should be latest month in a FiscalYear. This month and all prior months are locked and can not be changed.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Application', 'COLUMN', N'MasterClosedMonth'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Read security evaluated by Acting as OP instead of default behavior by user', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Application', 'COLUMN', N'ReadSecurityByOpYN'
GO
