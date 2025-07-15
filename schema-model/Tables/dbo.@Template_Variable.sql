CREATE TABLE [dbo].[@Template_Variable]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[MemberKey] [nvarchar] (50) NOT NULL,
[Description] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_Variable_Description] DEFAULT (''),
[Variable_Value] [float] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_Variable_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[@Template_Variable_Upd]
	ON [dbo].[@Template_Variable]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN BIT,
		@Version NVARCHAR(100),
		@DatabaseName NVARCHAR(100)
					
	SET @DatabaseName = DB_NAME()
	
	IF @DatabaseName = 'pcINTEGRATOR_Data'
		BEGIN
			EXEC [pcINTEGRATOR].dbo.[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

			IF @DevYN = 0
				SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(NVARCHAR(10), GETDATE(), 112)
					
			UPDATE V
			SET
				[Version] = @Version
			FROM
				[@Template_Variable] V
				INNER JOIN Inserted I ON	
					I.InstanceID = V.InstanceID AND
					I.VersionID = V.VersionID AND
					I.MemberKey = V.MemberKey
		END
GO
ALTER TABLE [dbo].[@Template_Variable] ADD CONSTRAINT [PK_@Template_Variable] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [MemberKey])
GO
