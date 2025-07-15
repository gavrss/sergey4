CREATE TABLE [dbo].[@Template_BR01_Step_SortOrder]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[BR01_StepID] [int] NOT NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_BR01_Step_SortOrder_SortOrder] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR01_Step_SortOrder_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[@Template_BR01_Step_SortOrder_Upd]
	ON [dbo].[@Template_BR01_Step_SortOrder]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE S
	SET
		[Version] = @Version
	FROM
		[@Template_BR01_Step_SortOrder] S
		INNER JOIN Inserted I ON	
			I.BusinessRuleID = S.BusinessRuleID AND
			I.BR01_StepID = S.BR01_StepID
GO
ALTER TABLE [dbo].[@Template_BR01_Step_SortOrder] ADD CONSTRAINT [PK_@Template_BR01_Step_SortOrder] PRIMARY KEY CLUSTERED ([BusinessRuleID], [BR01_StepID])
GO
