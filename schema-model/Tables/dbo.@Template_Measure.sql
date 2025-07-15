CREATE TABLE [dbo].[@Template_Measure]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_Measure_EnvironmentLevelID] DEFAULT ((0)),
[DataClassID] [int] NOT NULL,
[MeasureID] [int] NOT NULL,
[MeasureName] [nvarchar] (50) NOT NULL,
[MeasureDescription] [nvarchar] (50) NOT NULL,
[SourceFormula] [nvarchar] (max) NULL,
[ExecutionOrder] [int] NOT NULL CONSTRAINT [DF_Measure_ExecutionOrder] DEFAULT ((0)),
[MeasureParentID] [int] NULL,
[DataTypeID] [int] NOT NULL,
[FormatString] [nvarchar] (50) NULL,
[ValidRangeFrom] [nvarchar] (100) NULL,
[ValidRangeTo] [nvarchar] (100) NULL,
[Unit] [nvarchar] (50) NOT NULL CONSTRAINT [DF_Measure_Unit] DEFAULT (''),
[AggregationTypeID] [int] NOT NULL CONSTRAINT [DF_Measure_AggregationTypeID] DEFAULT ((-1)),
[TabularYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Measure_TabularYN] DEFAULT ((0)),
[DataClassViewBM] [int] NOT NULL CONSTRAINT [DF_@Template_Measure_DataClassViewBM] DEFAULT ((1)),
[TabularFormula] [nvarchar] (max) NULL,
[TabularFolder] [nvarchar] (50) NULL,
[InheritedFrom] [int] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_Measure_SortOrder] DEFAULT ((0)),
[ModelingStatusID] [int] NOT NULL CONSTRAINT [DF_Measure_ModelingStatusID] DEFAULT ((-40)),
[ModelingComment] [nvarchar] (1024) NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Measure_SelectYN] DEFAULT ((1)),
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Measure_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Measure_Upd]
	ON [dbo].[@Template_Measure]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE M
	SET
		[Version] = @Version
	FROM
		[@Template_Measure] M
		INNER JOIN Inserted I ON	
			I.MeasureID = M.MeasureID AND
			I.VersionID = M.VersionID
GO
ALTER TABLE [dbo].[@Template_Measure] ADD CONSTRAINT [PK_Measure_1] PRIMARY KEY CLUSTERED ([MeasureID])
GO
ALTER TABLE [dbo].[@Template_Measure] ADD CONSTRAINT [FK_Measure_AggregationType] FOREIGN KEY ([AggregationTypeID]) REFERENCES [dbo].[@Template_AggregationType] ([AggregationTypeID])
GO
ALTER TABLE [dbo].[@Template_Measure] ADD CONSTRAINT [FK_Measure_DataType] FOREIGN KEY ([DataTypeID]) REFERENCES [dbo].[@Template_DataType] ([DataTypeID])
GO
ALTER TABLE [dbo].[@Template_Measure] ADD CONSTRAINT [FK_Measure_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Measure] ADD CONSTRAINT [FK_Measure_Version] FOREIGN KEY ([VersionID]) REFERENCES [dbo].[@Template_Version] ([VersionID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Used when copying, reference to MeasureID', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Measure', 'COLUMN', N'InheritedFrom'
GO
