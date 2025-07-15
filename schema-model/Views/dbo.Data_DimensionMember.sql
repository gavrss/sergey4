SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Data_DimensionMember] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[DataClassID],
	[sub].[DataRowID],
	[sub].[DimensionID],
	[sub].[MemberKey],
	[sub].[Inserted],
	[sub].[InsertedBy]
FROM
	(
	SELECT
		[InstanceID],
		[DataClassID],
		[DataRowID],
		[DimensionID],
		[MemberKey],
		[Inserted],
		[InsertedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Data_DimensionMember]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[DataClassID],
		[DataRowID],
		[DimensionID],
		[MemberKey],
		[Inserted],
		[InsertedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Data_DimensionMember]
	) sub
GO
