SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spA_ConvertUsers] AS

INSERT INTO pcINTEGRATOR_Data..User_Instance
(
InstanceID,
	UserID,
	[InsertedBy]
)

SELECT 
	U.InstanceID,
	S2.UserID,
	[InsertedBy] = -101
FROM
	pcINTEGRATOR_Data..[User] U
	INNER JOIN (

SELECT
	U.InstanceID,
	S1.UserID,
	S1.UserName
FROM
	pcINTEGRATOR_Data..[User] U
	INNER JOIN (
SELECT 
      [UserName],
	  UserID = CASE WHEN MAX(UserID) < -1000 THEN MAX(UserID) ELSE MIN(UserID) END

  FROM [pcINTEGRATOR_Data].[dbo].[User]
  WHERE UserTypeID = -1
  GROUP BY UserName
  HAVING COUNT(1) > 1
) S1 ON S1.UserID = U.UserID
) S2 ON S2.UserName = U.UserName AND S2.InstanceID <> U.instanceID
ORDER BY U.UserID



UPDATE UM
SET
	UserID_User = sub.ToUserID
FROM
	UserMember UM
	INNER JOIN (

SELECT
	ToUserID = S2.UserID,
	FromUserID = U.UserID
FROM
	[User] U
	INNER JOIN (
SELECT 
      [UserName],
	  UserID = CASE WHEN MAX(UserID) < -1000 THEN MAX(UserID) ELSE MIN(UserID) END

  FROM [pcINTEGRATOR_Data].[dbo].[User]
  WHERE UserTypeID = -1
  GROUP BY UserName
  HAVING COUNT(1) > 1) S2 ON S2.UserName = U.UserName AND S2.UserID <> U.UserID
  ) sub ON sub.FromUserID = UM.UserID_User


UPDATE OPU
SET
	UserID = sub.ToUserID
FROM
	OrganizationPosition_User OPU
	INNER JOIN (

SELECT
	ToUserID = S2.UserID,
	FromUserID = U.UserID
FROM
	[User] U
	INNER JOIN (
SELECT 
      [UserName],
	  UserID = CASE WHEN MAX(UserID) < -1000 THEN MAX(UserID) ELSE MIN(UserID) END

  FROM [pcINTEGRATOR_Data].[dbo].[User]
  WHERE UserTypeID = -1
  GROUP BY UserName
  HAVING COUNT(1) > 1) S2 ON S2.UserName = U.UserName AND S2.UserID <> U.UserID
  ) sub ON sub.FromUserID = OPU.UserID


UPDATE SRU
SET
	UserID = sub.ToUserID
FROM
	SecurityRoleUser SRU
	INNER JOIN (

SELECT
	ToUserID = S2.UserID,
	FromUserID = U.UserID
FROM
	[User] U
	INNER JOIN (
SELECT 
      [UserName],
	  UserID = CASE WHEN MAX(UserID) < -1000 THEN MAX(UserID) ELSE MIN(UserID) END

  FROM [pcINTEGRATOR_Data].[dbo].[User]
  WHERE UserTypeID = -1
  GROUP BY UserName
  HAVING COUNT(1) > 1) S2 ON S2.UserName = U.UserName AND S2.UserID <> U.UserID
  ) sub ON sub.FromUserID = SRU.UserID


DELETE UPV
FROM
	[UserPropertyValue] UPV
	INNER JOIN (

SELECT
	ToUserID = S2.UserID,
	FromUserID = U.UserID
FROM
	[User] U
	INNER JOIN (
SELECT 
      [UserName],
	  UserID = CASE WHEN MAX(UserID) < -1000 THEN MAX(UserID) ELSE MIN(UserID) END

  FROM [pcINTEGRATOR_Data].[dbo].[User]
  WHERE UserTypeID = -1
  GROUP BY UserName
  HAVING COUNT(1) > 1) S2 ON S2.UserName = U.UserName AND S2.UserID <> U.UserID
  ) sub ON sub.FromUserID = UPV.UserID





DELETE U
FROM
	[User] U
	INNER JOIN (

SELECT 
      [UserName],
	  UserID = CASE WHEN MAX(UserID) < -1000 THEN MAX(UserID) ELSE MIN(UserID) END

  FROM [pcINTEGRATOR_Data].[dbo].[User]
  WHERE UserTypeID = -1
  GROUP BY UserName
  HAVING COUNT(1) > 1) S2 ON S2.UserName = U.UserName AND S2.UserID <> U.UserID
GO
