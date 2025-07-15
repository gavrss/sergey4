SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SIE4_Job] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[UserID],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[JobID],
	[sub].[FLAGGA],
	[sub].[PROGRAM],
	[sub].[FORMAT],
	[sub].[GEN],
	[sub].[SIETYP],
	[sub].[PROSA],
	[sub].[FNR],
	[sub].[ORGNR],
	[sub].[BKOD],
	[sub].[ADRESS],
	[sub].[FNAMN],
	[sub].[RAR_0_FROM],
	[sub].[RAR_0_TO],
	[sub].[RAR_1_FROM],
	[sub].[RAR_1_TO],
	[sub].[TAXAR],
	[sub].[OMFATTN],
	[sub].[KPTYP],
	[sub].[VALUTA],
	[sub].[KSUMMA],
	[sub].[EntityID],
	[sub].[SentRows],
	[sub].[StartTime],
	[sub].[EndTime],
	[sub].[Inserted],
	[sub].[InsertedBy]
FROM
	(
	SELECT
		[UserID],
		[InstanceID],
		[VersionID],
		[JobID],
		[FLAGGA],
		[PROGRAM],
		[FORMAT],
		[GEN],
		[SIETYP],
		[PROSA],
		[FNR],
		[ORGNR],
		[BKOD],
		[ADRESS],
		[FNAMN],
		[RAR_0_FROM],
		[RAR_0_TO],
		[RAR_1_FROM],
		[RAR_1_TO],
		[TAXAR],
		[OMFATTN],
		[KPTYP],
		[VALUTA],
		[KSUMMA],
		[EntityID],
		[SentRows],
		[StartTime],
		[EndTime],
		[Inserted],
		[InsertedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SIE4_Job]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[UserID],
		[InstanceID],
		[VersionID],
		[JobID],
		[FLAGGA],
		[PROGRAM],
		[FORMAT],
		[GEN],
		[SIETYP],
		[PROSA],
		[FNR],
		[ORGNR],
		[BKOD],
		[ADRESS],
		[FNAMN],
		[RAR_0_FROM],
		[RAR_0_TO],
		[RAR_1_FROM],
		[RAR_1_TO],
		[TAXAR],
		[OMFATTN],
		[KPTYP],
		[VALUTA],
		[KSUMMA],
		[EntityID],
		[SentRows],
		[StartTime],
		[EndTime],
		[Inserted],
		[InsertedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SIE4_Job]
	) sub
GO
