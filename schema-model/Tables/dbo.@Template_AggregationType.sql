CREATE TABLE [dbo].[@Template_AggregationType]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_AggregationType_InstanceID] DEFAULT ((0)),
[AggregationTypeID] [int] NOT NULL,
[AggregationTypeName] [nvarchar] (50) NOT NULL,
[AggregationTypeDescription] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_AggregationType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[AggregationType_Upd]
	ON [dbo].[@Template_AggregationType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE AT
	SET
		[Version] = @Version
	FROM
		[@Template_AggregationType] AT
		INNER JOIN Inserted I ON	
			I.AggregationTypeID = AT.AggregationTypeID
GO
ALTER TABLE [dbo].[@Template_AggregationType] ADD CONSTRAINT [PK_AggregationType] PRIMARY KEY CLUSTERED ([AggregationTypeID])
GO
ALTER TABLE [dbo].[@Template_AggregationType] ADD CONSTRAINT [FK_AggregationType_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
