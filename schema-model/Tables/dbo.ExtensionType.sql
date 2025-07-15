CREATE TABLE [dbo].[ExtensionType]
(
[ExtensionTypeID] [int] NOT NULL,
[ExtensionTypeName] [nvarchar] (100) NOT NULL,
[Description] [nvarchar] (255) NOT NULL,
[Command] [nvarchar] (500) NOT NULL,
[FeatureBM] [int] NOT NULL CONSTRAINT [DF_DatabaseSelection_Feature] DEFAULT ((0)),
[DatabaseBM] [int] NOT NULL CONSTRAINT [DF_ExtensionType_DatabaseBM] DEFAULT ((0)),
[FixedDbNameYN] [bit] NOT NULL CONSTRAINT [DF_ExtensionType_FixedDbNameYN] DEFAULT ((0)),
[ExtensionName] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ExtensionType_ExtensionName] DEFAULT (''),
[Introduced] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ExtensionType_Introduced] DEFAULT ((1.2)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_DatabaseSelection_SelectYN] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DatabaseSelection_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ExtensionType_Upd]
	ON [dbo].[ExtensionType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE C
	SET
		[Version] = @Version
	FROM
		[ExtensionType] C
		INNER JOIN Inserted I ON	
			I.ExtensionTypeID = C.ExtensionTypeID


GO
ALTER TABLE [dbo].[ExtensionType] ADD CONSTRAINT [PK_DatabaseSelection] PRIMARY KEY CLUSTERED ([ExtensionTypeID])
GO
