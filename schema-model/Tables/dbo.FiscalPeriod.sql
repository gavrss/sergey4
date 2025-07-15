CREATE TABLE [dbo].[FiscalPeriod]
(
[FiscalPeriod] [int] NOT NULL,
[Description] [nvarchar] (50) NOT NULL
)
GO
ALTER TABLE [dbo].[FiscalPeriod] ADD CONSTRAINT [PK_FiscalPeriod] PRIMARY KEY CLUSTERED ([FiscalPeriod])
GO
