CREATE TABLE [dbo].[@Template_Dimension_Rule]
(
[InstanceID] [int] NOT NULL,
[Entity_MemberKey] [nvarchar] (50) NOT NULL,
[DimensionID] [int] NOT NULL,
[MappingTypeID] [int] NOT NULL CONSTRAINT [DF_Dimension_Rule_MappingTypeID] DEFAULT ((0)),
[ReplaceTextYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_Rule_ReplaceTextYN] DEFAULT ((0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_Rule_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Dimension_Rule_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Dimension_Rule_Upd]
	ON [dbo].[@Template_Dimension_Rule]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DR
	SET
		[Version] = @Version
	FROM
		[@Template_Dimension_Rule] DR
		INNER JOIN Inserted I ON	
			I.InstanceID = DR.InstanceID AND
			I.Entity_MemberKey = DR.Entity_MemberKey AND
			I.DimensionID = DR.DimensionID
GO
ALTER TABLE [dbo].[@Template_Dimension_Rule] ADD CONSTRAINT [PK_Dimension_Rule] PRIMARY KEY CLUSTERED ([InstanceID], [Entity_MemberKey], [DimensionID])
GO
