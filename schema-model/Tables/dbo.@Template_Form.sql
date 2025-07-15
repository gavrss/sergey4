CREATE TABLE [dbo].[@Template_Form]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Form_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL CONSTRAINT [DF_Form_VersionID] DEFAULT ((0)),
[FormID] [int] NOT NULL,
[FormName] [nvarchar] (50) NOT NULL,
[Menu] [nvarchar] (50) NULL,
[ObjectGuiBehaviorBM] [int] NOT NULL CONSTRAINT [DF_Form_ObjectGuiBehaviorBM] DEFAULT ((1)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Form_SelectYN] DEFAULT ((1)),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_@Template_Form_SortOrder] DEFAULT ((0)),
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_@Template_Form_Inserted] DEFAULT (getdate()),
[InsertedBy] [int] NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_@Template_Form_Updated] DEFAULT (getdate()),
[UpdatedBy] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Form_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_Form] ADD CONSTRAINT [PK_Form] PRIMARY KEY CLUSTERED ([FormID])
GO
