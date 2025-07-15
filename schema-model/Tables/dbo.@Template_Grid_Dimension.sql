CREATE TABLE [dbo].[@Template_Grid_Dimension]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[GridID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[GridAxisID] [int] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Grid_Dimension_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Grid_Dimension_Upd]
	ON [dbo].[@Template_Grid_Dimension]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE GD
	SET
		[Version] = @Version
	FROM
		[@Template_Grid_Dimension] GD
		INNER JOIN Inserted I ON	
			I.GridID = GD.GridID AND
			I.DimensionID = GD.DimensionID AND
			I.GridAxisID = GD.GridAxisID
GO
ALTER TABLE [dbo].[@Template_Grid_Dimension] ADD CONSTRAINT [PK_Grid_Dimension] PRIMARY KEY CLUSTERED ([GridID], [DimensionID], [GridAxisID])
GO
