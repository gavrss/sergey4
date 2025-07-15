SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_Duration] AS
SELECT 
	[ProcedureName],
	[StartTime] = MAX([StartTime]),
	MaxDuration = MAX([Duration]),
	AvgDuration = AVG(datepart(minute, [Duration]) * 60 + datepart(second, [Duration])),
	NoOf = COUNT(1)
FROM
	[pcINTEGRATOR].[dbo].[JobLog]
WHERE
	StartTime > '2018-08-01' AND 
	Duration > '00:00:01' AND 
	Procedurename LIKE '%Portal%' AND
	ErrorNumber = 0
GROUP BY
	[ProcedureName]
ORDER BY
	COUNT(1) DESC
GO
