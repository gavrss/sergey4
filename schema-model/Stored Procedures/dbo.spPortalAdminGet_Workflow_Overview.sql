SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Workflow_Overview] AS

SELECT 
	GL_Säljarnr = [GL_Säljarnr_MemberKey],
	Säljare = MAX(S.[Description]),
	Currency = [Currency_MemberKey],
	OrderState = MAX(OS.[Description]),
	SB.[WorkflowStateID],
	WorkflowState = MAX(WS.WorkflowStateName),
	SalesAmount = ROUND(SUM(CONVERT(FLOAT, [SalesAmount_Budget_Value])), 0),
	SalesCost = ROUND(SUM(CONVERT(FLOAT, [SalesMargin_Budget_Value])), 0) - ROUND(SUM(CONVERT(FLOAT, [SalesAmount_Budget_Value])), 0),
	SalesMargin = ROUND(SUM(CONVERT(FLOAT, [SalesMargin_Budget_Value])), 0),
	SalesProvison = ROUND(SUM(CONVERT(FLOAT, [SalesProvisionsPrice_Value])), 0)

FROM
	[pcETL_Christian_14].[dbo].[pcDC_0304_SalesBudget] SB
	INNER JOIN pcDATA_Christian_14..S_DS_GL_Säljarnr S ON S.Label = SB.GL_Säljarnr_MemberKey
	INNER JOIN pcDATA_Christian_14..S_DS_OrderState OS ON OS.Label = SB.OrderState_MemberKey
	INNER JOIN pcINTEGRATOR..WorkflowState WS ON WS.WorkflowStateId = SB.WorkflowStateID
WHERE
	SB.[Scenario_MemberKey] = 'FORECAST2' AND
	SB.[TimeYear_MemberKey] = '2017' AND
	SB.[WorkflowStateID] NOT IN (1018)
GROUP BY
	[Currency_MemberKey],
	[GL_Säljarnr_MemberKey],
	SB.OrderState_MemberKey,
	SB.[WorkflowStateID]
ORDER BY
	[GL_Säljarnr_MemberKey],
	[Currency_MemberKey],
	SB.OrderState_MemberKey,
	SB.[WorkflowStateID]
GO
