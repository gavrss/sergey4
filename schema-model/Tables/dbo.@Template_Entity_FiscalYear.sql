CREATE TABLE [dbo].[@Template_Entity_FiscalYear]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[Entity_FiscalYearID] [int] NOT NULL,
[EntityID] [int] NOT NULL,
[Book] [nvarchar] (50) NOT NULL,
[StartMonth] [int] NOT NULL CONSTRAINT [DF_Entity_FiscalYear_StartMonth] DEFAULT ((190001)),
[EndMonth] [int] NOT NULL CONSTRAINT [DF_Entity_FiscalYear_EndMonth] DEFAULT ((209912)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Entity_FiscalYear_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Entity_FiscalYear_Upd]
	ON [dbo].[@Template_Entity_FiscalYear]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE EFY
	SET
		[Version] = @Version
	FROM
		[@Template_Entity_FiscalYear] EFY
		INNER JOIN Inserted I ON	
			I.EntityID = EFY.EntityID AND
			I.Book = EFY.Book AND
			I.StartMonth = EFY.StartMonth
GO
ALTER TABLE [dbo].[@Template_Entity_FiscalYear] ADD CONSTRAINT [PK_Entity_FiscalYear] PRIMARY KEY CLUSTERED ([EntityID], [Book], [StartMonth])
GO
ALTER TABLE [dbo].[@Template_Entity_FiscalYear] ADD CONSTRAINT [FK_Entity_FiscalYear_Entity_Book] FOREIGN KEY ([EntityID], [Book]) REFERENCES [dbo].[@Template_Entity_Book] ([EntityID], [Book])
GO
ALTER TABLE [dbo].[@Template_Entity_FiscalYear] ADD CONSTRAINT [FK_Entity_FiscalYear_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
