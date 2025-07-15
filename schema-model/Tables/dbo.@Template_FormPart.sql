CREATE TABLE [dbo].[@Template_FormPart]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_@Template_FormPart_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_FormPart_VersionID] DEFAULT ((0)),
[FormID] [int] NOT NULL,
[FormPartID] [int] NOT NULL,
[FormPartName] [nvarchar] (50) NOT NULL,
[DataObjectName] [nvarchar] (100) NOT NULL,
[FormPartID_Reference] [int] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_@Template_FormPart_SortOrder] DEFAULT ((0)),
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_@Template_FormPart_Inserted] DEFAULT (getdate()),
[InsertedBy] [int] NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_@Template_FormPart_Updated] DEFAULT (getdate()),
[UpdatedBy] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_FormPart_Version] DEFAULT (''),
[Filter] [nvarchar] (255) NULL
)
GO
ALTER TABLE [dbo].[@Template_FormPart] ADD CONSTRAINT [PK_@Template_FormPart] PRIMARY KEY CLUSTERED ([FormID], [FormPartID])
GO
ALTER TABLE [dbo].[@Template_FormPart] ADD CONSTRAINT [FK_@Template_FormPart_@Template_Form] FOREIGN KEY ([FormID]) REFERENCES [dbo].[@Template_Form] ([FormID])
GO
