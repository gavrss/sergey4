CREATE TABLE [dbo].[@Template_JobStep]
(
[Comment] [nvarchar] (100) NULL,
[InstanceID] [int] NOT NULL CONSTRAINT [DF_JobStep_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_JobStep_InstanceID1] DEFAULT ((0)),
[JobStepID] [int] NOT NULL,
[JobStepTypeBM] [int] NOT NULL,
[DatabaseName] [nvarchar] (100) NULL,
[StoredProcedure] [nvarchar] (100) NOT NULL,
[Parameter] [nvarchar] (255) NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_JobStep_SortOrder] DEFAULT ((0)),
[JobFrequencyBM] [int] NOT NULL CONSTRAINT [DF_JobStep_RegularYN] DEFAULT ((2)),
[JobStepGroupBM] [int] NOT NULL CONSTRAINT [DF_JobStep_JobStepGroupBM] DEFAULT ((0)),
[ProcessBM] [int] NOT NULL CONSTRAINT [DF_JobStep_ProcessBM] DEFAULT ((0)),
[JobSetupStepBM] [int] NOT NULL CONSTRAINT [DF_JobStep_JobStepGroupBM1] DEFAULT ((0)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_JobStep_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_JobStep_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[JobStep_Upd]
	ON [dbo].[@Template_JobStep]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE JS
	SET
		[Version] = @Version
	FROM
		[@Template_JobStep] JS
		INNER JOIN Inserted I ON	
			I.JobStepID = JS.JobStepID
GO
ALTER TABLE [dbo].[@Template_JobStep] ADD CONSTRAINT [PK_JobStep] PRIMARY KEY CLUSTERED ([JobStepID])
GO
