CREATE TABLE [dbo].[ObjectGuiBehavior]
(
[ObjectGuiBehaviorBM] [int] NOT NULL,
[ObjectGuiBehaviorName] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ObjectGuiBehavior_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ObjectGuiBehavior_Upd]
	ON [dbo].[ObjectGuiBehavior]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE JST
	SET
		[Version] = @Version
	FROM
		[ObjectGuiBehavior] JST
		INNER JOIN Inserted I ON	
			I.ObjectGuiBehaviorBM = JST.ObjectGuiBehaviorBM


GO
ALTER TABLE [dbo].[ObjectGuiBehavior] ADD CONSTRAINT [PK_ObjectGuiBehavior] PRIMARY KEY CLUSTERED ([ObjectGuiBehaviorBM])
GO
