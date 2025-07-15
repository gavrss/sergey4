CREATE TABLE [dbo].[@Template_DataType]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_DataType_InstanceID] DEFAULT ((0)),
[DataTypeID] [int] NOT NULL,
[DataTypeName] [nvarchar] (50) NOT NULL,
[DataTypeDescription] [nvarchar] (255) NOT NULL,
[DataTypeCode] [nvarchar] (50) NOT NULL,
[DataTypePortal] [nvarchar] (50) NOT NULL CONSTRAINT [DF_DataType_DataTypePortal] DEFAULT (N'string'),
[DataTypeCallisto] [nvarchar] (50) NOT NULL CONSTRAINT [DF_DataType_DataTypePortal1] DEFAULT (N'Text'),
[SizeYN] [bit] NOT NULL,
[GuiObject] [nvarchar] (50) NOT NULL CONSTRAINT [DF_DataType_GuiObject] DEFAULT (N'TextBox'),
[DataTypeGroupBM] [int] NOT NULL CONSTRAINT [DF_DataType_DataTypeBM] DEFAULT ((16)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DataType_Version] DEFAULT (''),
[PropertyTypeID] [int] NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DataType_Upd]
	ON [dbo].[@Template_DataType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DT
	SET
		[Version] = @Version
	FROM
		[@Template_DataType] DT
		INNER JOIN Inserted I ON	
			I.DataTypeID = DT.DataTypeID
GO
ALTER TABLE [dbo].[@Template_DataType] ADD CONSTRAINT [PK_DataType] PRIMARY KEY CLUSTERED ([DataTypeID])
GO
ALTER TABLE [dbo].[@Template_DataType] ADD CONSTRAINT [FK_DataType_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'1 = SQL, 2 = Callisto, 4 = pcPortal, 8 = pcIntegrator, 16 = Custom', 'SCHEMA', N'dbo', 'TABLE', N'@Template_DataType', 'COLUMN', N'DataTypeGroupBM'
GO
