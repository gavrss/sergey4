CREATE TABLE [dbo].[@Template_BR04_Master]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Comment] [nvarchar] (1024) NULL,
[DataClassID] [int] NOT NULL,
[DimensionFilter] [nvarchar] (max) NULL,
[MultiplyYN] [bit] NOT NULL CONSTRAINT [DF_BR04_Master_MultiplyYN] DEFAULT ((1)),
[BaseCurrency] [int] NULL,
[Parameter] [nvarchar] (4000) NULL,
[Duration] [time] NULL,
[InheritedFrom] [int] NULL,
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR04_Master_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR04_Master_Upd]
	ON [dbo].[@Template_BR04_Master]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE M
	SET
		[Version] = @Version
	FROM
		[@Template_BR04_Master] M
		INNER JOIN Inserted I ON	
			I.BusinessRuleID = M.BusinessRuleID
GO
ALTER TABLE [dbo].[@Template_BR04_Master] ADD CONSTRAINT [PK_BR04_Master] PRIMARY KEY CLUSTERED ([BusinessRuleID])
GO
