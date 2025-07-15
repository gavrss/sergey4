CREATE TABLE [dbo].[@Template_MemberSelection]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[DataClassID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[Label] [nvarchar] (50) NOT NULL,
[SequenceBM] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_MemberSelection_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_MemberSelection_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE TRIGGER [dbo].[MemberSelection_Upd]
	ON [dbo].[@Template_MemberSelection]

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
					
			UPDATE MS
			SET
				[Version] = @Version
			FROM
				[@Template_MemberSelection] MS
				INNER JOIN Inserted I ON
					I.InstanceID = MS.InstanceID AND
					I.VersionID = MS.VersionID AND
					I.DataClassID = MS.DataClassID AND
					I.DimensionID = MS.DimensionID AND
					I.[Label] = MS.[Label]
		END
GO
ALTER TABLE [dbo].[@Template_MemberSelection] ADD CONSTRAINT [PK_MemberSelection] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [DataClassID], [DimensionID], [Label])
GO
