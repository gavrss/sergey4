CREATE TABLE [dbo].[@Template_DataClass]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_DataClass_EnvironmentLevelID] DEFAULT ((0)),
[DataClassID] [int] NOT NULL,
[DataClassName] [nvarchar] (50) NOT NULL,
[DataClassDescription] [nvarchar] (50) NOT NULL,
[DataClassTypeID] [int] NOT NULL CONSTRAINT [DF_DataClass_DataClassTypeID] DEFAULT ((-1)),
[ModelBM] [int] NULL,
[StorageTypeBM] [int] NOT NULL CONSTRAINT [DF_DataClass_StorageTypeBM] DEFAULT ((1)),
[ReadAccessDefaultYN] [bit] NOT NULL CONSTRAINT [DF_DataClass_ReadAccessDefaultYN] DEFAULT ((1)),
[ActualDataClassID] [int] NULL,
[FullAccountDataClassID] [int] NULL,
[TabularYN] [bit] NOT NULL CONSTRAINT [DF_@Template_DataClass_TabularYN] DEFAULT ((0)),
[PrimaryJoin_DimensionID] [int] NULL,
[ModelingStatusID] [int] NOT NULL CONSTRAINT [DF_DataClass_ModelingStatusID] DEFAULT ((-40)),
[ModelingComment] [nvarchar] (1024) NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_DataClass_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DataClass_Version] DEFAULT (''),
[DeletedID] [int] NULL,
[TextSupportYN] [bit] NOT NULL CONSTRAINT [DF_@Template_DataClass_TextSupportYN] DEFAULT ((0))
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DataClass_Upd]
	ON [dbo].[@Template_DataClass]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DC
	SET
		[Version] = @Version
	FROM
		[@Template_DataClass] DC
		INNER JOIN Inserted I ON	
			I.DataClassID = DC.DataClassID
GO
ALTER TABLE [dbo].[@Template_DataClass] ADD CONSTRAINT [PK_DataGroup] PRIMARY KEY CLUSTERED ([DataClassID])
GO
ALTER TABLE [dbo].[@Template_DataClass] ADD CONSTRAINT [FK_DataClass_DataClassType] FOREIGN KEY ([DataClassTypeID]) REFERENCES [dbo].[DataClassType] ([DataClassTypeID])
GO
ALTER TABLE [dbo].[@Template_DataClass] ADD CONSTRAINT [FK_DataClass_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_DataClass] ADD CONSTRAINT [FK_DataClass_StorageType] FOREIGN KEY ([StorageTypeBM]) REFERENCES [dbo].[StorageType] ([StorageTypeBM])
GO
ALTER TABLE [dbo].[@Template_DataClass] ADD CONSTRAINT [FK_DataClass_Version] FOREIGN KEY ([VersionID]) REFERENCES [dbo].[@Template_Version] ([VersionID])
GO
ALTER TABLE [dbo].[@Template_DataClass] ADD CONSTRAINT [FK_DataGroup_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_DataClass] NOCHECK CONSTRAINT [FK_DataClass_StorageType]
GO
EXEC sp_addextendedproperty N'MS_Description', N'Mandatory for DataClassTypeID = -7. Each dataclass of type FullAccount is related to a dataclass of DataClassTypeID = -1', 'SCHEMA', N'dbo', 'TABLE', N'@Template_DataClass', 'COLUMN', N'FullAccountDataClassID'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Dimension to join between multiple fact tables in Tabular', 'SCHEMA', N'dbo', 'TABLE', N'@Template_DataClass', 'COLUMN', N'PrimaryJoin_DimensionID'
GO
