CREATE TABLE [dbo].[CashFlow_CalculationType]
(
[CalculationTypeID] [int] NOT NULL,
[CalculationTypeName] [nvarchar] (50) NULL,
[Version] [nvarchar] (100) NULL CONSTRAINT [DF_CashFlow_CalculationType_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[CashFlow_CalculationType] ADD CONSTRAINT [PK_CashFlow_CalculationType] PRIMARY KEY CLUSTERED ([CalculationTypeID])
GO
