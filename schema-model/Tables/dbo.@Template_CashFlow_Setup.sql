CREATE TABLE [dbo].[@Template_CashFlow_Setup]
(
[InstanceID] [int] NOT NULL,
[Account_MemberKey_Destination] [nvarchar] (100) NOT NULL,
[Account_MemberKey_Source] [nvarchar] (100) NOT NULL,
[CalculationTypeID] [int] NOT NULL,
[Sign] [int] NOT NULL,
[SortOrder] [int] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_CashFlow_Setup_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_CashFlow_Setup] ADD CONSTRAINT [PK_CashFlow_Setup] PRIMARY KEY CLUSTERED ([InstanceID], [Account_MemberKey_Destination], [Account_MemberKey_Source], [CalculationTypeID])
GO
