SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spA_Add_InstanceID]

AS

--SecurityRoleUser
UPDATE SRU
SET
	InstanceID = SR.InstanceID
FROM
	SecurityRoleUser SRU
	INNER JOIN SecurityRole SR ON SR.SecurityRoleID = SRU.SecurityRoleID
WHERE
	SRU.InstanceID IS NULL


--UserMember
UPDATE UM
SET
	InstanceID = U.InstanceID
FROM
	UserMember UM
	INNER JOIN [User] U ON U.UserID = UM.UserID_User
WHERE
	UM.InstanceID IS NULL

--UserPropertyValue
UPDATE UPV
SET
	InstanceID = U.InstanceID
FROM
	UserPropertyValue UPV
	INNER JOIN [User] U ON U.UserID = UPV.UserID
WHERE
	UPV.InstanceID IS NULL

--SqlQueryParameter
UPDATE SQP
SET
	InstanceID = SQ.InstanceID
FROM
	SqlQueryParameter SQP
	INNER JOIN SqlQuery SQ ON SQ.SqlQueryID = SQP.SqlQueryID
WHERE
	SQP.InstanceID IS NULL

--OrganizationPosition_User
UPDATE OPU
SET
	InstanceID = U.InstanceID
FROM
	OrganizationPosition_User OPU
	INNER JOIN [User] U ON U.UserID = OPU.UserID
WHERE
	OPU.InstanceID IS NULL

--SecurityRoleObject
UPDATE SRO
SET
	InstanceID = SR.InstanceID
FROM
	SecurityRoleObject SRO
	INNER JOIN SecurityRole SR ON SR.SecurityRoleID = SRO.SecurityRoleID
WHERE
	SRO.InstanceID IS NULL

--Extension
UPDATE E
SET
	InstanceID = A.InstanceID
FROM
	Extension E
	INNER JOIN [Application] A ON A.ApplicationID = E.ApplicationID
WHERE
	E.InstanceID IS NULL

--Application_Translation
UPDATE AT
SET
	InstanceID = A.InstanceID
FROM
	Application_Translation AT
	INNER JOIN [Application] A ON A.ApplicationID = AT.ApplicationID
WHERE
	AT.InstanceID IS NULL

--Model
UPDATE M
SET
	InstanceID = A.InstanceID
FROM
	Model M
	INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
WHERE
	M.InstanceID IS NULL

--Source
UPDATE S
SET
	InstanceID = M.InstanceID
FROM
	Source S
	INNER JOIN [Model] M ON M.ModelID = S.ModelID
WHERE
	S.InstanceID IS NULL

--DataClassDefinition
UPDATE DCD
SET
	InstanceID = DC.InstanceID
FROM
	pcINTEGRATOR_Data..DataClassDefinition DCD
	INNER JOIN pcINTEGRATOR_Data..DataClass DC ON DC.DataClassID = DCD.DataClassID
WHERE
	DCD.InstanceID IS NULL
GO
