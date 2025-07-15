CREATE TABLE [dbo].[@Template_DataClassView]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[DataClassID] [int] NOT NULL,
[DataClassViewBM] [int] NOT NULL,
[DataClassViewName] [nvarchar] (100) NOT NULL,
[SourceDataClassID] [int] NULL,
[FilterString] [nvarchar] (4000) NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_DataClassView_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DataClassView_Version] DEFAULT (''),
[DeletedID] [int] NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DataClassView_Upd]
	ON [dbo].[@Template_DataClassView]

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
					
			UPDATE DCV
			SET
				[Version] = @Version
			FROM
				[@Template_DataClassView] DCV
				INNER JOIN Inserted I ON	
					I.DataClassID = DCV.DataClassID AND
					I.DataClassViewBM = DCV.DataClassViewBM
		END
GO
ALTER TABLE [dbo].[@Template_DataClassView] ADD CONSTRAINT [PK_DataClassView] PRIMARY KEY CLUSTERED ([DataClassID], [DataClassViewBM])
GO
