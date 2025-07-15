CREATE TABLE [dbo].[@Template_Model]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_Model_VersionID] DEFAULT ((0)),
[ModelID] [int] NOT NULL,
[ModelName] [nvarchar] (50) NOT NULL,
[ModelDescription] [nvarchar] (255) NOT NULL,
[ApplicationID] [int] NOT NULL,
[BaseModelID] [int] NOT NULL,
[ModelBM] [int] NOT NULL CONSTRAINT [DF_Model_ModelBM] DEFAULT ((0)),
[ProcessID] [int] NOT NULL CONSTRAINT [DF_Model_ProcessID] DEFAULT ((0)),
[ListSetBM] [int] NOT NULL CONSTRAINT [DF_Model_ListSetBM] DEFAULT ((0)),
[TimeLevelID] [int] NULL,
[TimeTypeBM] [int] NOT NULL CONSTRAINT [DF_Model_TimeTypeBM] DEFAULT ((1)),
[OptFinanceDimYN] [bit] NOT NULL CONSTRAINT [DF_Model_OptFinanceDimYN] DEFAULT ((0)),
[FinanceAccountYN] [bit] NOT NULL CONSTRAINT [DF_Model_FinanceAccountYN] DEFAULT ((0)),
[TextSupportYN] [bit] NOT NULL CONSTRAINT [DF_Model_TextSupportYN] DEFAULT ((0)),
[VirtualYN] [bit] NOT NULL CONSTRAINT [DF_Model_VirtualYN] DEFAULT ((0)),
[DynamicRule] [nvarchar] (4000) NULL,
[StartupWorkbook] [nvarchar] (50) NULL,
[Introduced] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Model_Introduced] DEFAULT ((1.2)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Model_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Model_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Model_Upd]
	ON [dbo].[@Template_Model]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE M
	SET
		[Version] = @Version
	FROM
		[@Template_Model] M
		INNER JOIN Inserted I ON	
			I.ModelID = M.ModelID

	UPDATE S
	SET
		SelectYN = I.SelectYN
	FROM
		[@Template_Source] S 
		INNER JOIN [Inserted] I ON I.ModelID = S.ModelID
		INNER JOIN [Deleted] D ON D.ModelID = I.ModelID AND D.SelectYN <> I.SelectYN
GO
ALTER TABLE [dbo].[@Template_Model] ADD CONSTRAINT [PK_Model] PRIMARY KEY CLUSTERED ([ModelID])
GO
ALTER TABLE [dbo].[@Template_Model] ADD CONSTRAINT [FK_Model_Application] FOREIGN KEY ([ApplicationID]) REFERENCES [dbo].[@Template_Application] ([ApplicationID])
GO
ALTER TABLE [dbo].[@Template_Model] ADD CONSTRAINT [FK_Model_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Model] ADD CONSTRAINT [FK_Model_Process] FOREIGN KEY ([ProcessID]) REFERENCES [dbo].[@Template_Process] ([ProcessID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Based on ApplicationID. Used when upgrading.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Model', 'COLUMN', N'InheritedFrom'
GO
