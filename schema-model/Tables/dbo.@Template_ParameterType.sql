CREATE TABLE [dbo].[@Template_ParameterType]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_ParameterType_InstanceID] DEFAULT ((0)),
[ParameterTypeID] [int] NOT NULL,
[ParameterTypeName] [nvarchar] (50) NOT NULL,
[ParameterTypeDescription] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ParameterType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ParameterType_Upd]
	ON [dbo].[@Template_ParameterType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE PT
	SET
		[Version] = @Version
	FROM
		[@Template_ParameterType] PT
		INNER JOIN Inserted I ON	
			I.ParameterTypeID = PT.ParameterTypeID
GO
ALTER TABLE [dbo].[@Template_ParameterType] ADD CONSTRAINT [PK_ParameterType] PRIMARY KEY CLUSTERED ([ParameterTypeID])
GO
