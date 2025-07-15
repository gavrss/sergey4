CREATE TABLE [dbo].[Report]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Report_InstanceID] DEFAULT ((0)),
[ReportID] [int] NOT NULL IDENTITY(1001, 1),
[LanguageID] [int] NOT NULL CONSTRAINT [DF_Report_LanguageID] DEFAULT ((1)),
[ModelBM] [int] NOT NULL CONSTRAINT [DF_Report_ModelBM] DEFAULT ((192)),
[AuthorType] [nchar] (1) NOT NULL CONSTRAINT [DF_Report_AuthorType] DEFAULT (N'T'),
[Label] [nvarchar] (255) NOT NULL,
[Contents] [image] NOT NULL,
[ChangeDatetime] [datetime] NOT NULL CONSTRAINT [DF_Report_ChangeDatetime] DEFAULT (getdate()),
[Userid] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Report_Userid] DEFAULT (suser_sname()),
[Sec] [nvarchar] (max) NOT NULL CONSTRAINT [DF_Report_Sec] DEFAULT (''),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Report_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Report_Upd]
	ON [dbo].[Report]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE R
	SET
		[Version] = @Version
	FROM
		[Report] R
		INNER JOIN Inserted I ON	
			I.ReportID = R.ReportID

GO
ALTER TABLE [dbo].[Report] ADD CONSTRAINT [PK_Report] PRIMARY KEY CLUSTERED ([ReportID])
GO
