CREATE TABLE [dbo].[@Template_Scenario]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Scenario_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL,
[ScenarioID] [int] NOT NULL,
[MemberKey] [nvarchar] (50) NOT NULL,
[ScenarioTypeID] [int] NOT NULL,
[ScenarioName] [nvarchar] (50) NOT NULL,
[ScenarioDescription] [nvarchar] (255) NOT NULL,
[ActualOverwriteYN] [bit] NOT NULL,
[AutoRefreshYN] [bit] NOT NULL,
[InputAllowedYN] [bit] NOT NULL,
[AutoSaveOnCloseYN] [bit] NOT NULL,
[ClosedMonth] [int] NULL,
[DrillTo_MemberKey] [nvarchar] (100) NULL,
[LockedDate] [date] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_Scenario_SortOrder] DEFAULT ((10000)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Scenario_SelectYN] DEFAULT ((1)),
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Scenario_Version] DEFAULT (''),
[SimplifiedDimensionalityYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Scenario_SimplifiedDimensionalityYN] DEFAULT ((0))
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Scenario_Upd]
	ON [dbo].[@Template_Scenario]

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
		[@Template_Scenario] R
		INNER JOIN Inserted I ON	
			I.ScenarioID = R.ScenarioID
GO
ALTER TABLE [dbo].[@Template_Scenario] ADD CONSTRAINT [PK_Scenario] PRIMARY KEY CLUSTERED ([ScenarioID])
GO
CREATE UNIQUE NONCLUSTERED INDEX [Scenario_InstanceID_MemberKey] ON [dbo].[@Template_Scenario] ([InstanceID], [VersionID], [MemberKey], [DeletedID])
GO
