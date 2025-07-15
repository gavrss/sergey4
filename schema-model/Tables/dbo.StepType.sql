CREATE TABLE [dbo].[StepType]
(
[StepTypeBM] [int] NOT NULL,
[StepTypeName] [nvarchar] (50) NOT NULL,
[SysAdminYN] [bit] NOT NULL CONSTRAINT [DF_StepType_SysAdminYN] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_StepType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[StepType_Upd]
	ON [dbo].[StepType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE ST
	SET
		[Version] = @Version
	FROM
		[StepType] ST
		INNER JOIN Inserted I ON	
			I.StepTypeBM = ST.StepTypeBM



GO
ALTER TABLE [dbo].[StepType] ADD CONSTRAINT [PK_StepType] PRIMARY KEY CLUSTERED ([StepTypeBM])
GO
