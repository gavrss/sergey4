CREATE TABLE [dbo].[Job]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Job_InstanceID] DEFAULT ((0)),
[JobID] [int] NOT NULL IDENTITY(1, 1),
[MasterCommand] [nvarchar] (1024) NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_Job_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Job_InsertedBy] DEFAULT (suser_name()),
[TimeOut] [time] NOT NULL CONSTRAINT [DF_Job_TimeOut] DEFAULT ('3:00:00'),
[StartTime] [datetime] NULL,
[CurrentCommand] [nvarchar] (255) NULL,
[CurrentCommand_StartTime] [datetime] NULL,
[EndTime] [datetime] NULL,
[ErrorTime] [datetime] NULL,
[ClosedYN] [bit] NOT NULL CONSTRAINT [DF_Job_Closed] DEFAULT ((0))
)
GO
ALTER TABLE [dbo].[Job] ADD CONSTRAINT [PK_Job] PRIMARY KEY CLUSTERED ([JobID] DESC)
GO
