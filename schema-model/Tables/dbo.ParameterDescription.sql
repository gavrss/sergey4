CREATE TABLE [dbo].[ParameterDescription]
(
[SourceTypeFamilyID] [int] NOT NULL,
[ParameterType] [nvarchar] (50) NOT NULL CONSTRAINT [DF_ParameterDescription_ParameterType] DEFAULT (N'Entity'),
[Parameter] [nvarchar] (10) NOT NULL,
[Description] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ParameterDescription_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ParameterDescription_Upd]
	ON [dbo].[ParameterDescription]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE PD
	SET
		[Version] = @Version
	FROM
		[ParameterDescription] PD
		INNER JOIN Inserted I ON	
			I.SourceTypeFamilyID = PD.SourceTypeFamilyID AND
			I.ParameterType = PD.ParameterType AND
			I.Parameter = PD.Parameter



GO
ALTER TABLE [dbo].[ParameterDescription] ADD CONSTRAINT [PK_ParameterDescription_1] PRIMARY KEY CLUSTERED ([SourceTypeFamilyID], [ParameterType], [Parameter])
GO
ALTER TABLE [dbo].[ParameterDescription] ADD CONSTRAINT [FK_ParameterDescription_SourceTypeFamily] FOREIGN KEY ([SourceTypeFamilyID]) REFERENCES [dbo].[SourceTypeFamily] ([SourceTypeFamilyID])
GO
