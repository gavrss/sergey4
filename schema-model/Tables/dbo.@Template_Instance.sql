CREATE TABLE [dbo].[@Template_Instance]
(
[InstanceID] [int] NOT NULL,
[InstanceName] [nvarchar] (50) NOT NULL,
[InstanceDescription] [nvarchar] (255) NOT NULL,
[InstanceShortName] [nvarchar] (5) NULL,
[CustomerID] [int] NOT NULL,
[StartYear] [int] NOT NULL CONSTRAINT [DF_@Template_Instance_StartYear] DEFAULT (datepart(year,getdate())-(5)),
[AddYear] [int] NOT NULL CONSTRAINT [DF_@Template_Instance_AddYear] DEFAULT ((2)),
[FiscalYearStartMonthSetYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Instance_FiscalYearStartMonthSetYN] DEFAULT ((0)),
[FiscalYearStartMonth] [int] NOT NULL CONSTRAINT [DF_Instance_FiscalYearStartMonth] DEFAULT ((1)),
[FiscalYearNamingSetYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Instance_FiscalYearNamingSetYN] DEFAULT ((0)),
[FiscalYearNaming] [int] NOT NULL CONSTRAINT [DF_Instance_FiscalYearNaming] DEFAULT ((0)),
[MultiplyYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Instance_MultiplyYN] DEFAULT ((1)),
[ProductKey] [nvarchar] (17) NULL,
[pcPortal_URL] [nvarchar] (255) NULL,
[Mail_ProfileName] [nvarchar] (128) NULL,
[Rows] [int] NOT NULL CONSTRAINT [DF_Instance_Rows] DEFAULT ((10000)),
[Nyc] [int] NOT NULL CONSTRAINT [DF_Instance_Nyc] DEFAULT ((0)),
[Nyu] [nvarchar] (50) NULL,
[StepXML] [xml] NULL,
[BrandID] [int] NOT NULL CONSTRAINT [DF_Instance_BrandID] DEFAULT ((2)),
[TriggerActiveYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Instance_TriggerActiveYN] DEFAULT ((1)),
[AllowExternalAccessYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Instance_AllowExternalAccessYN] DEFAULT ((1)),
[LastLogin] [datetime] NULL,
[LastLoginByUserID] [int] NULL,
[InheritedFrom] [int] NULL,
[CommercialUseYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Instance_CommercialUseYN] DEFAULT ((1)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Instance_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Instance_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Instance_Upd]
	ON [dbo].[@Template_Instance]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE Inst
	SET
		[Version] = @Version
	FROM
		[@Template_Instance] Inst
		INNER JOIN Inserted I ON	
			I.InstanceID = Inst.InstanceID

/*
	UPDATE A
	SET
		SelectYN = I.SelectYN
	FROM
		[@Template_Application] A 
		INNER JOIN [Inserted] I ON I.InstanceID = A.InstanceID
		INNER JOIN [Deleted] D ON D.InstanceID = I.InstanceID AND D.SelectYN <> I.SelectYN
*/
GO
ALTER TABLE [dbo].[@Template_Instance] ADD CONSTRAINT [PK_Instance] PRIMARY KEY CLUSTERED ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Instance] ADD CONSTRAINT [FK_Instance_Customer] FOREIGN KEY ([CustomerID]) REFERENCES [dbo].[@Template_Customer] ([CustomerID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'FiscalYear = YEAR(FiscalYearStartMonth) + FiscalYearNaming Example 1: FiscalYear starts 201707, FiscalYearNaming set to 0 ==> FiscalYear = 2017 Example 2: FiscalYear starts 201707, FiscalYearNaming set to 1 ==> FiscalYear = 2018 Example 3: FiscalYear starts 201701, FiscalYearNaming set to 0 ==> FiscalYear = 2017', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Instance', 'COLUMN', N'FiscalYearNaming'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Default value for all Applications and Entities', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Instance', 'COLUMN', N'FiscalYearStartMonth'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Used for domain naming in AD', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Instance', 'COLUMN', N'InstanceShortName'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Calculation method for FxTrans (1=Multiply, 0=Divide)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Instance', 'COLUMN', N'MultiplyYN'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Number of rows to insert into each table during initial load', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Instance', 'COLUMN', N'Rows'
GO
