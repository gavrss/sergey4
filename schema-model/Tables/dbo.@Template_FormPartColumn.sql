CREATE TABLE [dbo].[@Template_FormPartColumn]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_VersionID] DEFAULT ((0)),
[FormID] [int] NOT NULL,
[FormPartID] [int] NOT NULL,
[FormPartColumn] [nvarchar] (50) NOT NULL,
[KeyYN] [bit] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_KeyYN] DEFAULT ((0)),
[EnabledYN] [bit] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_EnabledYN] DEFAULT ((1)),
[VisibleYN] [bit] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_VisibleYN] DEFAULT ((1)),
[DataObjectColumnName] [nvarchar] (50) NULL,
[ColumnSet] [nvarchar] (50) NULL,
[HelpText] [nvarchar] (255) NULL,
[ShowNullAs] [nvarchar] (50) NULL,
[NullYN] [bit] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_NullYN] DEFAULT ((1)),
[DataTypeID] [int] NULL,
[ObjectGuiBehaviorBM] [int] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_ObjectGuiBehaviorBM] DEFAULT ((1)),
[DefaultValue] [nvarchar] (100) NULL,
[ValueListType] [nvarchar] (50) NULL,
[ValueList] [nvarchar] (1024) NULL,
[ValueListParameter] [nvarchar] (4000) NULL,
[ValidationRule] [nvarchar] (100) NULL,
[FormPartColumn_Reference] [nvarchar] (50) NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_SortOrder] DEFAULT ((0)),
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_Inserted] DEFAULT (getdate()),
[InsertedBy] [int] NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_Updated] DEFAULT (getdate()),
[UpdatedBy] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_Version] DEFAULT (''),
[IdentityYN] [bit] NOT NULL CONSTRAINT [DF_@Template_FormPartColumn_IdentityYN] DEFAULT ((0))
)
GO
ALTER TABLE [dbo].[@Template_FormPartColumn] ADD CONSTRAINT [PK_@Template_FormPartColumn] PRIMARY KEY CLUSTERED ([FormID], [FormPartID], [FormPartColumn])
GO
ALTER TABLE [dbo].[@Template_FormPartColumn] ADD CONSTRAINT [FK_@Template_FormPartColumn_@Template_FormPart] FOREIGN KEY ([FormID], [FormPartID]) REFERENCES [dbo].[@Template_FormPart] ([FormID], [FormPartID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'NULL, SP (Stored procedure), FL (Fixed list)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_FormPartColumn', 'COLUMN', N'ValueListParameter'
GO
EXEC sp_addextendedproperty N'MS_Description', N'NULL, SP (Stored procedure), FL (Fixed list)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_FormPartColumn', 'COLUMN', N'ValueListType'
GO
