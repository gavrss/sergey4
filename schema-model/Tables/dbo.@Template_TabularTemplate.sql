CREATE TABLE [dbo].[@Template_TabularTemplate]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[TabularTemplateID] [int] NOT NULL IDENTITY(1001, 1),
[DataClassID] [int] NOT NULL,
[TabularToolTypeID] [int] NOT NULL,
[TabularTemplateName] [nvarchar] (50) NOT NULL,
[Content] [varbinary] (max) NOT NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_@Template_TabularTemplate_Inserted] DEFAULT (getdate()),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_TabularTemplate_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE TRIGGER [dbo].[@Template_TabularTemplate_Upd]
	ON [dbo].[@Template_TabularTemplate]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE TT
	SET
		[Version] = @Version
	FROM
		[@Template_TabularTemplate] TT
		INNER JOIN Inserted I ON	
			I.TabularTemplateID = TT.TabularTemplateID
GO
ALTER TABLE [dbo].[@Template_TabularTemplate] ADD CONSTRAINT [PK_@Template_TabularTemplate] PRIMARY KEY CLUSTERED ([TabularTemplateID])
GO
