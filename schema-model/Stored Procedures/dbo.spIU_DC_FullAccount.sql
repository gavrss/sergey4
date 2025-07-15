SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_FullAccount]

AS

DECLARE
	@UserID int = -10,
	@InstanceID int = 454,
	@VersionID int = 1021,
	@DataClassID int = 6332

DELETE FA
FROM
	pcINTEGRATOR_DATA.dbo.FullAccount FA
WHERE
	[InstanceID] = @InstanceID AND
	[VersionID] = @VersionID AND
	[DataClassID] = @DataClassID AND
	[WildcardYN] = 0

INSERT INTO pcINTEGRATOR_DATA.dbo.FullAccount
	(
	[InstanceID],
	[VersionID],
	[DataClassID],
	[SourceString],
	[SortOrder],
	[WildcardYN],
	[AccountType],
--	[AccountCategory],
	[SourceCol01],
	[SourceCol02],
	[SourceCol03],
	[SourceCol04],
	[SourceCol05],
	[SourceCol06],
	[DestCol01],
	[DestCol02],
	[DestCol03],
	[DestCol04],
	[DestCol05],
	[DestCol06]
	)
SELECT DISTINCT
	[InstanceID] = @InstanceID,
	[VersionID] = @VersionID,
	[DataClassID] = @DataClassID,
	[SourceString] = [Entity] + '|' + [Account] + '|' + [GL_Cost_Center] + '|' + [GL_Product_Category] + '|' + [GL_Project]  + '|' + [GL_Trading_Partner],
	[SortOrder] = 0,
	[WildcardYN] = 0,
	[AccountType] = A.[AccountType],
--	[AccountCategory] = A.[AccountCategory],
	[SourceCol01] = [Entity],
	[SourceCol02] = [Account],
	[SourceCol03] = [GL_Cost_Center],
	[SourceCol04] = [GL_Product_Category],
	[SourceCol05] = [GL_Project],
	[SourceCol06] = [GL_Trading_Partner],
	[DestCol01] = [Entity],
	[DestCol02] = [Account],
	[DestCol03] = [GL_Cost_Center],
	[DestCol04] = [GL_Product_Category],
	[DestCol05] = [GL_Project],
	[DestCol06] = [GL_Trading_Partner]
FROM
	[pcDATA_CCM].[dbo].[FACT_Financials_View] V
	INNER JOIN [pcDATA_CCM].[dbo].[S_DS_Account] A ON A.[Label] = V.Account
WHERE
	NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_DATA.dbo.FullAccount D WHERE D.[InstanceID] = @InstanceID AND D.[VersionID] = @VersionID AND D.[DataClassID] = @DataClassID AND D.[SourceString] = [Entity] + '|' + [Account] + '|' + [GL_Cost_Center] + '|' + [GL_Product_Category] + '|' + [GL_Project]  + '|' + [GL_Trading_Partner])
ORDER BY
	[Entity],
	[Account],
	[GL_Cost_Center],
	[GL_Product_Category],
	[GL_Project],
	[GL_Trading_Partner]

EXEC [spPortalAdminSet_FullAccount_WildCard]
	@UserID = @UserID,
	@InstanceID = @InstanceID,
	@VersionID = @VersionID,
	@DataClassID = @DataClassID
GO
