CREATE TABLE [dbo].[@Template_TransactionType_iScala]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[Hex] [nchar] (4) NOT NULL,
[Group] [nvarchar] (50) NULL,
[Period] [nvarchar] (2) NULL,
[Scenario] [nvarchar] (50) NULL,
[Symbol] [nchar] (1) NULL,
[Description] [nvarchar] (100) NULL,
[BusinessProcess] [nvarchar] (50) NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_TransactionType_iScala_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_TransactionType_iScala_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE TRIGGER [dbo].[TransactionType_iScala_Upd]
	ON [dbo].[@Template_TransactionType_iScala]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100),
		@DatabaseName nvarchar(100)
					
	SET @DatabaseName = DB_NAME()
	
	IF @DatabaseName = 'pcINTEGRATOR'
		BEGIN
			EXEC [pcINTEGRATOR].dbo.[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

			IF @DevYN = 0
				SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
			UPDATE TTiS
			SET
				[Version] = @Version
			FROM
				[@Template_TransactionType_iScala] TTiS
				INNER JOIN Inserted I ON
					I.InstanceID = TTiS.InstanceID AND
					I.VersionID = TTiS.VersionID AND
					I.Hex = TTiS.Hex
		END
GO
ALTER TABLE [dbo].[@Template_TransactionType_iScala] ADD CONSTRAINT [PK_TransactionType_iScala] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [Hex])
GO
