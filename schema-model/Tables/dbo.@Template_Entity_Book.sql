CREATE TABLE [dbo].[@Template_Entity_Book]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[EntityID] [int] NOT NULL,
[Book] [nvarchar] (50) NOT NULL,
[Currency] [nchar] (3) NULL,
[BookTypeBM] [int] NOT NULL CONSTRAINT [DF_Entity_Book_BookTypeBM] DEFAULT ((3)),
[COA] [nvarchar] (50) NULL,
[BalanceType] [nvarchar] (10) NOT NULL CONSTRAINT [DF_@Template_Entity_Book_BalanceType] DEFAULT (N'B'),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Entity_Book_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Entity_Book_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Entity_Book_Upd]
	ON [dbo].[@Template_Entity_Book]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100),
		@FiscalYearStartMonth int
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE EB
	SET
		[Version] = @Version
	FROM
		[@Template_Entity_Book] EB
		INNER JOIN Inserted I ON	
			I.EntityID = EB.EntityID AND
			I.Book = EB.Book

	SELECT @FiscalYearStartMonth = FiscalYearStartMonth FROM Instance WHERE InstanceID = (SELECT MAX(InstanceID) FROM Inserted)
	
	INSERT INTO [@Template_Entity_FiscalYear]
		(
		InstanceID,
		EntityID,
		Book,
		StartMonth,
		EndMonth
		)
	SELECT
		InstanceID = I.InstanceID,
		EntityID = I.EntityID,
		Book = I.Book,
		StartMonth = 190000 + @FiscalYearStartMonth,
		EndMonth = 209900 + CASE WHEN @FiscalYearStartMonth = 1 THEN 12 ELSE @FiscalYearStartMonth - 1 END
	FROM
		Inserted I
	WHERE
		NOT EXISTS (SELECT 1 FROM Entity_FiscalYear EFY WHERE EFY.EntityID = I.EntityID AND EFY.Book = I.Book)
GO
ALTER TABLE [dbo].[@Template_Entity_Book] ADD CONSTRAINT [PK_Entity_Book] PRIMARY KEY CLUSTERED ([EntityID], [Book])
GO
ALTER TABLE [dbo].[@Template_Entity_Book] ADD CONSTRAINT [FK_Entity_Book_Entity] FOREIGN KEY ([EntityID]) REFERENCES [dbo].[@Template_Entity] ([EntityID])
GO
ALTER TABLE [dbo].[@Template_Entity_Book] ADD CONSTRAINT [FK_Entity_Book_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Mandatory for Epicor ERP (B, D or S)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Entity_Book', 'COLUMN', N'BalanceType'
GO
EXEC sp_addextendedproperty N'MS_Description', N'1 = Financials, 2 = Main (included in consolidation), 4 = FxRate, 8 = Other processes', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Entity_Book', 'COLUMN', N'BookTypeBM'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Code for Chart of Account', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Entity_Book', 'COLUMN', N'COA'
GO
