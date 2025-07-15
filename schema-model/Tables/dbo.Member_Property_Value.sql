CREATE TABLE [dbo].[Member_Property_Value]
(
[Comment] [nvarchar] (255) NULL,
[DimensionID] [int] NOT NULL,
[MemberID] [int] NOT NULL,
[PropertyID] [int] NOT NULL,
[Value] [nvarchar] (50) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Member_Property_Value_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Member_Property_Value_Upd]
	ON [dbo].[Member_Property_Value]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE MPV
	SET
		[Version] = @Version
	FROM
		[Member_Property_Value] MPV
		INNER JOIN Inserted I ON	
			I.DimensionID = MPV.DimensionID AND
			I.MemberID = MPV.MemberID AND
			I.PropertyID = MPV.PropertyID




GO
ALTER TABLE [dbo].[Member_Property_Value] ADD CONSTRAINT [PK_Member_Property_Value] PRIMARY KEY CLUSTERED ([DimensionID], [MemberID], [PropertyID])
GO
ALTER TABLE [dbo].[Member_Property_Value] ADD CONSTRAINT [FK_Member_Property_Value_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[Member_Property_Value] ADD CONSTRAINT [FK_Member_Property_Value_Member] FOREIGN KEY ([DimensionID], [MemberID]) REFERENCES [dbo].[Member] ([DimensionID], [MemberID])
GO
ALTER TABLE [dbo].[Member_Property_Value] ADD CONSTRAINT [FK_Member_Property_Value_Property] FOREIGN KEY ([PropertyID]) REFERENCES [dbo].[@Template_Property] ([PropertyID])
GO
